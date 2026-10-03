------------------------------------------------------------
-- 容器與重排：一條一個自己的 Frame，暴雪的 item 錨到上面
--
--   ns.Bars.Get(key)                 容器框（MiliUICDM_Bar_<key>，parent UIParent）
--   ns.Bars.Request(key, level)      丟重排訊號；level = "membership" | "layout" | "structure"
--   ns.Bars.RequestSource(src, lvl)  暴雪某條檢視器有動靜（Viewers 叫）
--   ns.Bars.RelayoutAll(reason)      全部重排（設定檔、專精、設定值變了）
--   ns.Bars.Reapply(src)             同步：用上次算好的格子把 item 放回去（Viewers 的 Layout 後掛勾）
--   ns.Bars.ForEachClaimed(key, fn)  對這條認領中的每個 item 呼叫 fn(item, rec)（Visibility 用）
--   ns.Bars.ReleaseAll(reason)       把暴雪的 item 與檢視器還給暴雪（/mcdm release、引擎啟動失敗）
--
-- 訊號流
--   暴雪（取出 item／RefreshLayout／Layout／SetCooldownID／光環上下）
--     → Viewers 的後掛勾 → Bars.RequestSource → dirty[key] 記最高等級
--     → 排程：同一幀合併成一次 C_Timer.After(0)，兩次重排之間至少隔 0.1 秒
--     → Flush：Catalog.Bar(key) 的有序清單 ∩ 目前作用中的 item → Layout.Compute
--       → 每個 item ClearAllPoints＋SetPoint(TOPLEFT, 容器, x, -y)＋SetSize → Decorate.Apply
--     → 沒被任何條認領的 item（hidden、身分是空的、收合中的增益）停到畫面外
--
-- 髒標記三級（計畫 §2）
--   membership  哪些 item 在哪條          → 重取清單、重算、重放
--   layout      格位座標（設定值變了）    → 同上（清單取法一樣便宜，沒必要分開）
--   structure   容器的錨點／strata／顯示   → 上面兩級＋容器本身；**戰鬥中只做前兩級**，
--               結構級記帳到 PLAYER_REGEN_ENABLED
--   item 不是保護框，戰鬥中照樣 SetPoint／SetSize；容器的 SetPoint／SetSize／Show／Hide
--   一律走 ns.Write（容器被光環格持有框的保護連坐時會記帳）。
--
-- 停放：alpha 0 ＋ 錨到 UIParent 的 (-10000, 10000)。不 Hide（Hide 池子裡的框會讓暴雪重建
-- 整條檢視器）、不 SetParent。
--
-- 自訂項目（Modules/Custom.lua，id "c:<index>"）也是一格 entry：光環格的持有框、自訂法術／物品的
-- 圖示框。它們是**容器的子框**（條的淡出由容器的 alpha 帶），持有框的 SetPoint／SetSize／Show
-- 走 ns.Write（持有框整條鏈是保護框）。條上有光環格時固定格位強制打開：光環格放在哪一格都一樣，
-- 其他 item 收合也不會讓它的 x 變，戰鬥中不必動持有框。
--
-- 可點擊的自訂圖示群組（Core/Clickable.lua）：每格上面蓋一顆 secure 鈕（parent／錨點都是容器），
-- 一樣強制固定格位；鈕的寫入走 ns.Write＋簽章去重。不可點擊的條每輪 Release（沒鈕就是 no-op）。
--
-- 檢視器本體釘在容器上（TOPLEFT／BOTTOMRIGHT 對齊），被暴雪（編輯模式、底部管理框）
-- 拉走就釘回來；_pinGuard 擋自己觸發自己。
--
-- 面板（資源條、自訂格子、施法條、下一招圖示；ns.Bars.RegisterPanel）：容器同樣是 MiliUICDM_Bar_<key>、
-- 同一套 ApplyStructure（pos／anchor、strata、enabled＝false 就 Hide）與編輯模式／磁吸，
-- 但裡面畫什麼、多大由模組自己管（B.SetPanelSize）。重排排程對面板只做結構級，
-- 其餘交給模組的 relayout 回呼。核心技能第一列寬度變了廣播 "FirstRowWidthChanged"。
--
-- 可收合的面板（collapsible，自訂格子）：沒有內容時是「收合」（state.collapsed；框本身留 1 的高度）。
-- **收合的面板不佔位**：排開時別人跳過它、接到它的上一層（Layout.StackTarget 的 skip）。
-- ⚠ 一開始的做法是把框設成高度 0、讓後面的照樣貼在它身上：高度 0 的框在遊戲裡沒有有效的矩形，
--   貼在它身上的整條都畫不出來（沒有自訂格子的專精，輔助技能整條消失）。不要再讓任何東西貼在收合的框上。
-- 它自己上下向的錨定（TOP↔BOTTOM）**y 偏移一起收掉** —— 它夾在一疊中間（核心 → 自訂格子 → 輔助），
-- 空的時候不能讓兩邊的間距疊成兩倍。收合狀態一變就重套結構（錨點換了）。
------------------------------------------------------------
local _, ns = ...

ns.Bars = {}
local B = ns.Bars

local LEVEL = { membership = 1, layout = 2, structure = 3 }
B.LEVEL = LEVEL
local THROTTLE = 0.1
local PARK_X, PARK_Y = -10000, 10000

local containers = {}          -- key → 容器框
local state = {}               -- key → { anchorPoint, w, h, count, placeholders = {used, pool} }
local dirty = {}               -- key → 最高等級
local structurePending = {}    -- 戰鬥中延後的結構級
local slotOf = {}              -- cooldownID → { key, x, y, w, h }（Reapply 的快取）
local claimedBy = setmetatable({}, { __mode = "k" })   -- item → key
local firstRowW = {}           -- key → 第一列寬（長條寬 0 ＝ 跟核心技能第一列同寬）
local scheduled, lastRun = false, -1
local ArmStructurePending          -- 前置宣告（定義在 Relayout 前面）
local viewerShown = {}             -- 來源條 → 檢視器上一次看到是不是顯示中（稽核用）
local missing, missingSig = {}, {} -- 條 → { [id] = true }：清單上有、暴雪沒有給框的（稽核用，預覽讀）
local pinGuard, parkGuard = false, false
local pinned = {}                  -- 釘過的檢視器（ReleaseAll 只解這些，沒碰過的不動）
B.ready = false
B.flushes = 0

local function Now() return GetTime and GetTime() or 0 end

local panels = {}             -- key → { anchorPoint, minSize = fn → w, h, relayout = fn(level) }

local function Profile() return ns.profile end
-- 條或面板的設定表（面板在 profile[key]，見 Core/DB.lua 的 ConfigTable）
local function BarCfg(key)
    return ns.DB.ConfigTable(key)
end

function B.Get(key) return containers[key] end
function B.Containers() return containers end

------------------------------------------------------------
-- 容器
------------------------------------------------------------
-- 四條檢視器的容器**開檔就建**（只建框、不套樣式）：舊版本在暴雪的編輯模式版面裡留下了
-- relativeTo = "MiliUICDM_Bar_<key>"（成因見 PinViewer 的 B.PinViewerSoon），登入時暴雪套版面
-- （EDIT_MODE_LAYOUTS_UPDATED）可能早於我們的 PLAYER_LOGIN，容器還沒建就報
-- 「Couldn't find region named …」、檢視器沒有錨點。名字先佔著，EnsureContainer 再接手。
-- 暴雪的版面表我們不能寫（污染），只能讓舊名字一直解得到。
local early = {}
for _, key in ipairs({ "essential", "utility", "buffs", "buffbars" }) do
    local f = CreateFrame("Frame", "MiliUICDM_Bar_" .. key, UIParent, "BackdropTemplate")
    f:SetSize(1, 1)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:EnableMouse(false)
    early[key] = f
end

local function EnsureContainer(key)
    local c = containers[key]
    if c then return c end
    c = early[key] or CreateFrame("Frame", "MiliUICDM_Bar_" .. key, UIParent, "BackdropTemplate")
    early[key] = nil
    ns.Style.ApplyPanel(c)
    -- 底與邊都先透明：容器只是錨點，之後設定頁可以開底色
    c:SetBackdropColor(0, 0, 0, 0)
    c:SetBackdropBorderColor(0, 0, 0, 0)
    c:SetSize(1, 1)
    c:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    c:SetClampedToScreen(false)
    c:EnableMouse(false)
    containers[key] = c
    state[key] = state[key] or { placeholders = { used = 0, pool = {} } }
    -- 編輯模式的覆蓋層、自訂條的選取框、磁吸註冊：容器一建好就一起建（不等進了編輯模式才建）
    if ns.EditMode and ns.EditMode.OnContainer then
        xpcall(ns.EditMode.OnContainer, ns.ReportError, key, c)
    end
    return c
end

-- 容器目前用的錨點（版面算出來的那一邊；編輯模式放手時照它換算回 pos）
function B.AnchorPoint(key)
    local st = state[key]
    return st and (st.anchorPoint or st.appliedAnchor) or "CENTER"
end

-- 排開與錨定看的設定表：設了「跟著游標」的條（Core/Cursor.lua）當作不存在 ——
-- 它自己不錨定、不參與排開，已經錨著它的條當作目標不存在（改用自己的位置）。
-- 判準是 Configured（跟編輯模式／設定視窗無關），所以進出編輯模式時別條的排開不會跟著變
local function AnchorCfg(key)
    if ns.Cursor and ns.Cursor.Configured(key) then return nil end
    return BarCfg(key)
end

-- 錨定：anchor（錨在別條上）優先，形成環或目標不存在就退回 pos
local function AnchorTarget(key)
    return ns.Layout.AnchorOf(key, AnchorCfg)
end

-- 排開：跟著同一個目標、同一邊的照這個順序往外排（小的靠近目標），規則在 Core/Layout.lua。
-- 自訂群組排在內建的後面，彼此照左欄順序；下一招圖示排在所有東西的最後面（最外圈）。
local STACK_RANK = { resources = 1, pips = 2, utility = 3, castbar = 4, buffs = 5, buffbars = 6, essential = 7,
                     assistIcon = 900 }
local function StackRank(key)
    if STACK_RANK[key] then return STACK_RANK[key] end
    local p = Profile()
    local order = type(p) == "table" and type(p.barOrder) == "table" and p.barOrder or {}
    for i = 1, #order do
        if order[i] == key then return 100 + i end
    end
    return 1000
end
local function StackKeys()
    local keys = {}
    local p = Profile()
    if type(p) == "table" and type(p.bars) == "table" then
        for k in pairs(p.bars) do keys[#keys + 1] = k end
    end
    for _, k in ipairs(ns.DB.PANEL_ORDER) do
        if BarCfg(k) then keys[#keys + 1] = k end
    end
    return keys
end
-- 這條實際該貼在誰身上（沒有錨定回 nil）。keys 可省（一次算很多條時由呼叫端傳同一份）
-- 收合中的面板（沒有內容）不佔位：別人不能貼在它身上（高度 0 的框沒有有效的矩形）
local function StackSkip(key)
    local st = state[key]
    return st and st.collapsed and true or false
end
local function StackTarget(key, keys)
    return ns.Layout.StackTarget(key, AnchorCfg, keys or StackKeys(), StackRank, StackSkip)
end
B.StackTarget = StackTarget

-- 上下向的錨定（本條的 TOP 貼目標的 BOTTOM、或反過來）：收合時 y 偏移不算
local function VerticalAnchor(a)
    local p, r = tostring(a.point or "TOP"), tostring(a.relPoint or "BOTTOM")
    return (p:find("^TOP") and r:find("^BOTTOM")) or (p:find("^BOTTOM") and r:find("^TOP"))
end

-- 容器貼到位置（錨在別條上優先、否則 pos）；已經在 ns.Write 裡
local function PlaceContainer(f, key, bar, st)
    -- 跟著游標（編輯模式中、設定視窗開著時不跟：照下面貼回存檔位置）
    if ns.Cursor and ns.Cursor.Following(key) then
        st.stackTo = nil
        ns.Cursor.Place(f, key)
        return
    end
    local a = AnchorTarget(key)
    local snap = ns.Layout.Snap
    f:ClearAllPoints()
    if a then
        -- 貼在「排開」算出來的那一條上（同一邊已經有別人就貼在它外面），邊與偏移照自己的設定
        local to = StackTarget(key) or a.to
        EnsureContainer(to)
        local y = snap(tonumber(a.y) or 0)
        if st.collapsed and VerticalAnchor(a) then y = 0 end
        f:SetPoint(a.point or "TOP", containers[to], a.relPoint or "BOTTOM", snap(tonumber(a.x) or 0), y)
        st.stackTo = to
    else
        st.stackTo = nil
        local pos = type(bar.pos) == "table" and bar.pos or {}
        -- 容器用版面算出來的錨點（圖示增減時那一邊不動），貼在 UIParent 的 pos.point 上
        f:SetPoint(st.anchorPoint or "CENTER", UIParent, pos.point or "CENTER", snap(tonumber(pos.x) or 0), snap(tonumber(pos.y) or 0))
    end
end

local function ApplyOne(key)
    local c = EnsureContainer(key)
    local bar = BarCfg(key)
    local st = state[key]
    -- enabled ＝ false 只有面板會有（條沒有這個欄位）
    if not bar or bar.enabled == false then
        -- 條被刪（自訂群組、換設定檔少了這條）或面板關掉：容器收起來，編輯模式的覆蓋層／選取框也收
        --（frame 刪不掉；同一個 key 之後再建回來會重用，ApplyBarNow 看 BarCfg 決定要不要再顯示）
        -- 關掉的面板位置照樣對好：照字面錨在它身上的東西要有個位置，而且容器身上不能留著舊的錨
        --（舊錨指向的那條之後可能反過來要貼在它的下游，SetPoint 會撞上「錨在依賴自己的框上」）
        ns.Write(c, function(f)
            if bar then PlaceContainer(f, key, bar, st) end
            f:Hide()
            if ns.EditMode and ns.EditMode.ApplyBarNow then ns.EditMode.ApplyBarNow(key) end
        end, "shown")
        if ns.Cursor and ns.Cursor.Refresh then ns.Cursor.Refresh() end
        return
    end
    local anchorPoint = st.anchorPoint or "CENTER"
    ns.Write(c, function(f)
        f:SetFrameStrata(bar.strata or "MEDIUM")
        PlaceContainer(f, key, bar, st)
        f:Show()
        -- 編輯模式：覆蓋層跟著新的尺寸／錨點重排，磁吸的 Restore 接點
        if ns.EditMode and ns.EditMode.AfterApply then ns.EditMode.AfterApply(key) end
    end, "point")
    st.appliedAnchor = anchorPoint
    -- 跟著游標：結構一變（開關、可點擊、光環格、刪條）重判要不要掛 OnUpdate
    if ns.Cursor and ns.Cursor.Refresh then ns.Cursor.Refresh() end
end

-- 「實際貼在誰身上」跟現況不一樣的條（排開的結果變了：同一疊裡有人加入、離開、開關）
local function StackChanged(except)
    local out
    local keys = StackKeys()
    for i = 1, #keys do
        local k = keys[i]
        local st = state[k]
        if k ~= except and k ~= ns.dragging and containers[k] and st then
            local want = StackTarget(k, keys)
            if want ~= st.stackTo and (want or st.stackTo) then
                out = out or {}
                out[#out + 1] = k
            end
        end
    end
    return out
end

-- 一條的結構一變，同一疊的其他條可能要改貼別人。**兩段式**：先把要動的全部拆錨、再各自貼回去。
-- 逐條直接 SetPoint 的話，過渡狀態會出現「甲還貼著乙、乙卻要改貼甲」，SetPoint 當場報錯。
local restacking = false
local function ApplyStructure(key)
    if restacking then return ApplyOne(key) end
    local others = StackChanged(key)
    if not others then return ApplyOne(key) end
    if InCombatLockdown() then
        -- 戰鬥中不重排（容器可能是保護框，而且只動其中一條會留下過渡狀態）：整疊記帳，脫戰再套
        structurePending[key] = true
        for i = 1, #others do structurePending[others[i]] = true end
        ArmStructurePending()
        return
    end
    restacking = true
    local function Clear(k)
        local c = containers[k]
        if c and BarCfg(k) then ns.Write(c, function(f) f:ClearAllPoints() end, "point") end
    end
    Clear(key)
    for i = 1, #others do Clear(others[i]) end
    local ok, err = xpcall(ApplyOne, ns.ReportError, key)
    if not ok then B.lastError = err end
    for i = 1, #others do
        ok, err = xpcall(ApplyOne, ns.ReportError, others[i])
        if not ok then B.lastError = err end
    end
    restacking = false
end
-- 編輯模式在進戰鬥的鬆手窗口（PLAYER_REGEN_DISABLED，鎖定還沒生效）要當場把容器放回去
B.ApplyStructure = ApplyStructure

-- 設定變了但沒有哪一條要重套結構的時候用（編輯模式開始拖曳：那條脫離錨定，疊在它外面的要補位）
function B.Restack()
    if InCombatLockdown() then return end
    local changed = StackChanged(nil)
    if not changed then return end
    ApplyStructure(changed[1])
end

------------------------------------------------------------
-- 檢視器釘在容器上
------------------------------------------------------------
function B.PinViewer(sourceKey)
    if pinGuard or not sourceKey or B.released then return end
    if ns.dragging == sourceKey then return end
    local viewer = ns.Viewers.Get(sourceKey)
    local c = containers[sourceKey]
    if not (viewer and c) then return end
    pinned[sourceKey] = true
    ns.Write(viewer, function(v)
        pinGuard = true
        local ok, err = pcall(function()
            v:ClearAllPoints()
            v:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
            v:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
        end)
        pinGuard = false
        if not ok then error(err, 0) end
    end, "pin")
end

-- 暴雪自己 SetPoint 了檢視器（SetPoint 後掛勾）：**延一幀**才釘回來，不在暴雪那一次執行裡釘。
-- ⚠ 暴雪的 BreakFrameSnap（編輯模式選中後按方向鍵、別的框脫離吸附、套版面前的整理）是
--   「SetPoint 到 UIParent → OnSystemPositionChange → GetPoint(1) 存進版面」。同步釘回的話它讀到的
--   是我們的容器，"MiliUICDM_Bar_<key>" 就被存進玩家的編輯模式版面：之後每次登入暴雪套版面
--   找不到這個名字（我們還沒建、或插件停用了）就報 LUA_WARNING、檢視器沒有錨點。
--   同步釘回也是讓我們的 Lua 跑在暴雪的 secureexecuterange 裡（UpdateSystems 套錨點）。
local pinSoon = {}
function B.PinViewerSoon(sourceKey)
    if not sourceKey or pinGuard or B.released or pinSoon[sourceKey] then return end
    pinSoon[sourceKey] = true
    ns.Defer(function()
        pinSoon[sourceKey] = nil
        B.PinViewer(sourceKey)
    end)
end

------------------------------------------------------------
-- 停放與占位
------------------------------------------------------------
local function Park(item, rec)
    if parkGuard or B.released then return end
    parkGuard = true
    local ok = pcall(function()
        item:SetAlpha(0)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", UIParent, "TOPLEFT", PARK_X, PARK_Y)
    end)
    parkGuard = false
    if rec then
        rec.parked = ok
        if ok and ns.Glow then ns.Glow.OnParked(rec) end
    end
end
B.Park = Park

local function SafeShown(item)
    local ok, shown = pcall(item.IsShown, item)
    if not ok then return true end
    if ns.IsSecret(shown) then return true end       -- 讀不到就當顯示（不收合、不畫占位）
    return shown and true or false
end
B.SafeShown = SafeShown

-- 占位格是自己的框（圖示貼圖＋跟真實格一樣的邊框），畫在容器上；item 出現時蓋在它上面
local function Placeholder(key, idx)
    local ph = state[key].placeholders
    local f = ph.pool[idx]
    if not f then
        local c = containers[key]
        f = CreateFrame("Frame", nil, c)
        f:SetFrameLevel(c:GetFrameLevel())          -- 不高於容器：item 是檢視器的子框，層級在上面
        f.tex = f:CreateTexture(nil, "BACKGROUND")
        f.tex:SetAllPoints(f)
        f.ph = { frame = f, tex = f.tex }
        ph.pool[idx] = f
    end
    return f
end

local function ReleasePlaceholders(key, from)
    local ph = state[key].placeholders
    for i = from, #ph.pool do ph.pool[i]:Hide() end
    ph.used = from - 1
end

local QUESTION = 134400   -- INV_Misc_QuestionMark

------------------------------------------------------------
-- 一條的重排
------------------------------------------------------------
local function VisAlpha(key)
    if ns.Visibility and ns.Visibility.Alpha then return ns.Visibility.Alpha(key) end
    return 1
end

-- index[id] = item；live[來源條] = { id, … }（暴雪的順序：item 的 layoutIndex），給 Catalog.Adopt 對帳
local function BuildIndex()
    local index, dupes, slots = {}, {}, {}
    ns.Viewers.EnumerateItems(function(item, rec)
        -- 身分以 item 現在的為準（SetCooldownID 的後掛勾是主路；這裡是稽核：掛勾漏接的那一次救回來並記一筆）
        local live = ns.Viewers.ReadItemID(item)
        if live ~= rec.cooldownID then
            if ns.Diag then
                ns.Diag.Note("identity", ("%s：item 的身分 %s → %s（後掛勾沒接到）")
                    :format(tostring(rec.barKey), tostring(rec.cooldownID), tostring(live)))
            end
            rec.cooldownID = live
            rec.decorated = nil
        end
        local id = rec.cooldownID
        if id ~= nil then
            if index[id] == nil then
                index[id] = item
                local idx = rawget(item, "layoutIndex")
                if ns.IsSecret(idx) or type(idx) ~= "number" then idx = 1000 end
                local list = slots[rec.barKey]
                if not list then list = {}; slots[rec.barKey] = list end
                list[#list + 1] = { id = id, idx = idx }
            else
                dupes[#dupes + 1] = item
            end
        end
    end)
    local live = {}
    for key, list in pairs(slots) do
        table.sort(list, function(a, b)
            if a.idx ~= b.idx then return a.idx < b.idx end
            return a.id < b.id
        end)
        local ids = {}
        for i = 1, #list do ids[i] = list[i].id end
        live[key] = ids
    end
    return index, dupes, live
end

local function BarSize(key, bar)
    local layout = type(bar.layout) == "table" and bar.layout or {}
    if bar.kind ~= "bars" then return layout end
    local cfg = type(bar.bar) == "table" and bar.bar or {}
    local w = tonumber(cfg.width) or 0
    if w <= 0 then
        w = firstRowW.essential or 0
        if w <= 0 then w = (type(layout.size) == "table" and tonumber(layout.size.w)) or 200 end
    end
    local h = tonumber(cfg.height) or (type(layout.size) == "table" and tonumber(layout.size.h)) or 20
    return { maxPerRow = 1, spacing = layout.spacing, grow = layout.grow, size = { w = w, h = h } }
end

-- 戰鬥中延後的結構級：脫戰補做。面板直接套（不經排程：排程要等檢視器就緒）
ArmStructurePending = function()
    ns.Events.Register("PLAYER_REGEN_ENABLED", "bars_structure", function()
        ns.Events.Unregister("PLAYER_REGEN_ENABLED", "bars_structure")
        local keys = structurePending
        structurePending = {}
        for key in pairs(keys) do
            if panels[key] then ApplyStructure(key) else B.Request(key, "structure") end
        end
    end)
end

-- 面板：只管結構（錨點、strata、顯示），內容與尺寸交給模組
local function RelayoutPanel(key, level)
    local st = state[key]
    if level >= LEVEL.structure or st.anchorPoint ~= st.appliedAnchor then
        if InCombatLockdown() then structurePending[key] = true; ArmStructurePending() else ApplyStructure(key) end
    end
    local pd = panels[key]
    if pd and pd.relayout then pd.relayout(level) end
end

local function Relayout(key, level, index, gen)
    if panels[key] then return RelayoutPanel(key, level) end
    local c = EnsureContainer(key)
    local bar = BarCfg(key)
    local st = state[key]
    if not bar then
        ReleasePlaceholders(key, 1)
        if ns.Clickable then ns.Clickable.Release(key) end      -- 群組被刪：secure 鈕收起來、脫離錨點
        st.count = 0
        if InCombatLockdown() then structurePending[key] = true else ApplyStructure(key) end
        return
    end

    local ids = ns.Catalog.Bar(key)
    -- 稽核：清單上有、暴雪卻沒有給框的（只看核心／輔助這兩類：它們的 item 一直都在；增益類不在時本來就可能沒有框）。
    -- 我們畫不出來（圖示是暴雪的框），設定頁的預覽會把這幾格標暗並說明；變了才記一筆、才通知預覽
    do
        local gone, sig = nil, ""
        for _, id in ipairs(ids) do
            if type(id) == "number" and index[id] == nil then
                local src = ns.Catalog.SourceOf(id)
                if src and not ns.Viewers.AURA_KIND[src] then
                    gone = gone or {}
                    gone[id] = true
                    sig = sig .. id .. ","
                end
            end
        end
        if (missingSig[key] or "") ~= sig then
            missingSig[key] = sig
            missing[key] = gone
            if sig ~= "" and ns.Diag then
                ns.Diag.Note("missing", ("%s：清單上有、暴雪沒有給框：%s"):format(key, sig))
            end
            if ns.Fire then ns.Fire("MissingChanged", key) end
        end
    end
    local layout = type(bar.layout) == "table" and bar.layout or {}
    -- 條上有光環格、或這條可點擊 ⇒ 固定格位強制打開（值不動；光環格的持有框與可點擊的 secure 鈕戰鬥中都不能移）
    local clickable = ns.Clickable and ns.Clickable.Enabled(key) or false
    local fixed = (layout.fixedSlots or ns.Catalog.BarHasAuraSlot(key) or clickable) and true or false
    local entries = {}
    for _, id in ipairs(ids) do
        local item = index[id]
        local crec = ns.Custom and ns.Custom.Get(id)
        if crec then
            entries[#entries + 1] = { id = id, crec = crec }
        elseif item and not claimedBy[item] then
            local rec = ns.Viewers.frames[item]
            local aura = rec and ns.Viewers.AURA_KIND[rec.barKey]
            local shown = true
            if aura then shown = SafeShown(item) end
            if shown then
                entries[#entries + 1] = { id = id, item = item, rec = rec }
            elseif fixed then
                entries[#entries + 1] = { id = id, item = item, rec = rec, placeholder = true }
            end
            -- 收合模式下沒顯示的增益：不認領 ⇒ 最後的停放掃描會把它收走
            if shown or fixed then claimedBy[item] = key end
        end
    end

    local sizing = BarSize(key, bar)
    local rects, totalW, totalH, anchorPoint = ns.Layout.Compute(entries, sizing, bar.kind)
    if key == "essential" then
        local old = firstRowW.essential
        firstRowW.essential = ns.Layout.FirstRowWidth(#entries, sizing)
        if old ~= firstRowW.essential then
            -- 寬 0 的長條跟著核心技能第一列走
            for k in pairs(containers) do
                local b = BarCfg(k)
                if b and b.kind == "bars" and type(b.bar) == "table" and (tonumber(b.bar.width) or 0) <= 0 then
                    B.Request(k, "layout")
                end
            end
            -- 面板（資源條、施法條）的寬 0 也是這個語意
            if ns.Fire then ns.Fire("FirstRowWidthChanged", "essential", firstRowW.essential) end
        end
    end

    -- 容器：錨點換了是結構級（戰鬥中延後）；大小每次照算
    if anchorPoint ~= st.appliedAnchor then
        st.anchorPoint = anchorPoint
        if InCombatLockdown() then
            structurePending[key] = true
        else
            ApplyStructure(key)
        end
    elseif level >= LEVEL.structure then
        if InCombatLockdown() then structurePending[key] = true else ApplyStructure(key) end
    end
    local cw, ch = totalW > 0 and totalW or 1, totalH > 0 and totalH or 1
    if st.w ~= cw or st.h ~= ch then
        st.w, st.h = cw, ch
        ns.Write(c, function(f) f:SetSize(cw, ch) end, "size")
    end
    st.count = #entries

    -- item 放進格子
    local alpha = VisAlpha(key)
    local phUsed = 0
    for i, e in ipairs(entries) do
        local r = rects[i]
        local item, rec = e.item, e.rec
        if e.crec then
            ns.Custom.Place(e.crec, c, r, key, gen)
        else
            ns.Viewers.EnsureScale(item, rec, key)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)
            item:SetSize(r.w, r.h)
            if rec then
                rec.parked = false
                rec.claimGen = gen
                rec.claimKey = key
                ns.Decorate.Apply(item, rec, key, r.w, r.h)
                -- alpha：條的淡出 × 冷卻狀態（唯一出口；樣式快取在 Apply 裡寫，所以排在它後面）
                ns.Decorate.ApplyItemAlpha(item, rec, alpha)
                -- 層數門檻：停放後重新放格的接回＋餵一次目前層數。排在 Glow.Sync 前面：
                -- 接回時把暴雪條調回透明，無損刷新（Sync 裡的 ApplyPandemic）才蓋得上去
                if ns.StackGate then ns.StackGate.Feed(item, rec) end
                if ns.Glow then ns.Glow.Sync(item, rec, key) end
                if ns.Keybinds then ns.Keybinds.Apply(item, rec, key) end
            else
                item:SetAlpha(alpha)
            end
            slotOf[e.id] = { key = key, x = r.x, y = r.y, w = r.w, h = r.h }
        end
        if e.placeholder then
            phUsed = phUsed + 1
            local f = Placeholder(key, phUsed)
            local info = ns.Catalog.Info(e.id)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)
            f:SetSize(r.w, r.h)
            f.tex:SetTexture((info and info.icon) or QUESTION)
            f.tex:SetDesaturated(true)
            f.tex:SetAlpha(0.35)                      -- 只有圖示暗，邊框照真實格的顏色
            ns.Decorate.ApplyPlaceholder(f.ph, key, e.id, r.w, r.h)
            f:Show()
        end
        -- 可點擊：這一格上面蓋 secure 鈕（簽章去重、走 ns.Write；沒有動作的格收起來）
        if clickable then ns.Clickable.Place(key, c, i, r, e) end
    end
    ReleasePlaceholders(key, phUsed + 1)
    if ns.Clickable then
        if clickable then ns.Clickable.EndBar(key, #entries) else ns.Clickable.Release(key) end
    end
    if ns.Custom then ns.Custom.EndBar(key, gen) end
end

------------------------------------------------------------
-- 排程
------------------------------------------------------------
local Flush

local function Schedule()
    if scheduled then return end
    scheduled = true
    local wait = lastRun + THROTTLE - Now()
    if wait < 0 then wait = 0 end
    C_Timer.After(wait, function()
        scheduled = false
        local ok, err = xpcall(Flush, ns.ReportError)
        if not ok then B.lastError = err end
    end)
end

function B.Request(key, level)
    if not key then return end
    local lv = rawget(LEVEL, level or "membership") or LEVEL.membership
    if (dirty[key] or 0) < lv then dirty[key] = lv end
    Schedule()
end

-- 暴雪某條檢視器有動靜：只標會受影響的條
--   * 來源條自己（source 是這條檢視器的條）
--   * 目前認領著這條檢視器 item 的條：池化的框不會換檢視器，只有這些條手上的認領可能過期
--     （Flush 只放掉「這一輪要排的條」的認領，漏標就會卡住一顆框）
--   * 從它拉法術的條（groupOf 指到的群組，Catalog.GroupTargets）：新出現的 id 可能要進那裡
-- 增益上下每幾十毫秒一次，全部條重排是浪費；設定變了走 RequestAll。
function B.RequestSource(sourceKey, level)
    local p = Profile()
    if not sourceKey or type(p) ~= "table" or type(p.bars) ~= "table" then
        return B.RequestAll(level)
    end
    local targets = { [sourceKey] = true }
    for key, bar in pairs(p.bars) do
        if type(bar) == "table" and bar.source == sourceKey then targets[key] = true end
    end
    for item, key in pairs(claimedBy) do
        local rec = ns.Viewers.frames[item]
        if rec and rec.barKey == sourceKey then targets[key] = true end
    end
    if ns.Catalog and ns.Catalog.GroupTargets then ns.Catalog.GroupTargets(sourceKey, targets) end
    for key in pairs(targets) do
        if p.bars[key] then B.Request(key, level) end
    end
end

function B.RequestAll(level)
    local p = Profile()
    if type(p) ~= "table" or type(p.bars) ~= "table" then return end
    for key in pairs(p.bars) do B.Request(key, level) end
    for key in pairs(panels) do B.Request(key, level) end
    for key in pairs(containers) do
        if not p.bars[key] and not panels[key] then B.Request(key, "structure") end
    end
end

function B.RelayoutAll(_reason)
    B.RequestAll("structure")
end

-- 整套重來（幾輪）：見 B.Init 的事件註解。同一波事件合併成一組計時器（新的一波把舊的作廢）。
local RESYNC_DELAYS = { 0, 0.5, 1.5, 3 }
local resyncToken = 0
B.resyncs = 0
local function ResyncPass(reason, pass)
    if B.released or not ns.Viewers.ready then return end
    B.resyncs = B.resyncs + 1
    if ns.Decorate and ns.Decorate.InvalidateAll then ns.Decorate.InvalidateAll() end
    if ns.Catalog and ns.Catalog.MarkDirty then ns.Catalog.MarkDirty() end
    B.RequestAll("structure")
    if ns.Visibility and ns.Visibility.ApplyAll then ns.Visibility.ApplyAll() end
    if pass == 1 and ns.Diag then ns.Diag.Note("resync", tostring(reason)) end
end
function B.Resync(reason)
    resyncToken = resyncToken + 1
    local token = resyncToken
    for pass, delay in ipairs(RESYNC_DELAYS) do
        C_Timer.After(delay, function()
            if token ~= resyncToken then return end
            local ok, err = xpcall(ResyncPass, ns.ReportError, reason, pass)
            if not ok then B.lastError = err end
        end)
    end
end

Flush = function()
    if B.released then
        -- 還給暴雪之後：條不再排，面板（資源條、施法條）是自己的框，照常
        local work = dirty
        dirty = {}
        for key, lv in pairs(work) do
            if panels[key] then
                local ok, err = xpcall(RelayoutPanel, ns.ReportError, key, lv)
                if not ok then B.lastError = err end
            end
        end
        return
    end
    if not ns.Viewers.ready then return end
    if ns.Catalog.IsPaused() then return end          -- 暴雪設定面板開著：等它關掉（CatalogResumed）
    lastRun = Now()
    B.flushes = B.flushes + 1
    local gen = B.flushes

    local work = dirty
    dirty = {}
    -- 拖曳中的條這一輪不動，留到下一輪
    if ns.dragging and work[ns.dragging] then
        dirty[ns.dragging] = work[ns.dragging]
        work[ns.dragging] = nil
    end

    -- 暴雪可能剛在它自己的下一幀換了版面／專精：清單先對一次
    ns.Catalog.CheckFresh()
    -- 自訂項目：照目前專精的清單對上框（換專精、刪項目的在這裡收起來）
    if ns.Custom then ns.Custom.Sync() end
    local index, _, live = BuildIndex()
    -- 對帳：暴雪正在顯示、我們的清單卻漏掉的 id 收進來（見 Catalog.Adopt）。有收養 ⇒ 每一條都可能受影響，全部重排
    if ns.Catalog.Adopt and ns.Catalog.Adopt(live) > 0 then
        local prof = Profile()
        for key in pairs(type(prof) == "table" and type(prof.bars) == "table" and prof.bars or {}) do
            if key ~= ns.dragging and not work[key] then work[key] = LEVEL.membership end
        end
    end

    -- 這一輪要排的條先放掉舊的認領
    for item, key in pairs(claimedBy) do
        if work[key] then claimedBy[item] = nil end
    end
    for id, slot in pairs(slotOf) do
        if work[slot.key] then slotOf[id] = nil end
    end
    -- 依左欄順序排（被錨的條通常在後面；核心技能先排，長條才知道第一列多寬）
    local order, seen = {}, {}
    local p = Profile() or {}
    for _, key in ipairs(type(p.barOrder) == "table" and p.barOrder or {}) do
        if work[key] and not seen[key] then seen[key] = true; order[#order + 1] = key end
    end
    for key in pairs(work) do
        if not seen[key] then seen[key] = true; order[#order + 1] = key end
    end
    for _, key in ipairs(order) do
        local ok, err = xpcall(Relayout, ns.ReportError, key, work[key], index, gen)
        if not ok then B.lastError = err end
    end

    -- 沒被任何條認領的 item 停到畫面外
    ns.Viewers.EnumerateItems(function(item, rec)
        local key = claimedBy[item]
        if not key or not BarCfg(key) then
            claimedBy[item] = nil
            rec.claimKey = nil
            Park(item, rec)
        end
    end)
    if ns.Custom then ns.Custom.EndFlush() end

    -- 檢視器確保釘在容器上
    for _, src in ipairs(ns.Viewers.ORDER) do
        if work[src] and work[src] >= LEVEL.structure then B.PinViewer(src) end
    end

    if next(structurePending) then ArmStructurePending() end

    -- 稽核（只記不修）：暴雪把整條檢視器藏起來時，上面的 item 跟著看不到，我們這邊一切正常也沒用。
    -- 狀態變了才記一筆（編輯模式的「可見」設定、冷卻管理器在這個情境不可用…）
    if ns.Diag then
        for _, src in ipairs(ns.Viewers.ORDER) do
            local viewer = ns.Viewers.Get(src)
            if viewer then
                local ok, shown = pcall(viewer.IsShown, viewer)
                if ok and not ns.IsSecret(shown) then
                    shown = shown and true or false
                    if viewerShown[src] ~= nil and viewerShown[src] ~= shown then
                        ns.Diag.Note("viewer", ("%s 檢視器被暴雪%s（清單 %d、戰鬥中 %s）")
                            :format(src, shown and "顯示回來" or "藏起來", #ns.Catalog.Bar(src), tostring(InCombatLockdown())))
                    end
                    viewerShown[src] = shown
                end
            end
        end
    end

    -- 法術 → 格子的索引（SPELL_UPDATE_COOLDOWN 帶 ID 時只重算那幾格，Core/SpellIndex.lua）
    if ns.SpellIndex then ns.SpellIndex.Rebuild() end
    -- 戰鬥輔助的下一招醒目標示照新的索引重接（格子換了、搬了條、換專精：舊的熄、新的亮）
    if ns.Assist and ns.Assist.Reapply then ns.Assist.Reapply() end

    if not B.ready then
        B.ready = true
        if ns.Fire then ns.Fire("BarsReady") end
    end
    if ns.Visibility and ns.Visibility.ApplyAll then ns.Visibility.ApplyAll() end
end

------------------------------------------------------------
-- 同步放回：暴雪的格狀排版剛跑完（每次都會把 item 拉回它自己的格線）
------------------------------------------------------------
function B.Reapply(sourceKey)
    if B.released or not ns.Viewers.ready then return end
    ns.Viewers.EnumerateItems(function(item, rec)
        local id = rec.cooldownID
        local slot = id ~= nil and slotOf[id]
        local c = slot and containers[slot.key]
        if c then
            -- 這個 id 上次排在哪就放回哪（暴雪整條重取出時可能換了一顆框，完整重排馬上會來）
            ns.Viewers.EnsureScale(item, rec, slot.key)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", c, "TOPLEFT", slot.x, -slot.y)
            item:SetSize(slot.w, slot.h)
            ns.Decorate.ApplyItemAlpha(item, rec, VisAlpha(slot.key))
        elseif not ns.Catalog.IsPaused() then
            -- 沒有格子（新出現的、隱藏的、收合中的）：先藏起來，不要在暴雪的格線上閃一下。
            -- 暴雪設定面板開著時不藏：玩家正在那邊拖，新拉進來的要看得到（面板關掉會完整重排）
            Park(item, rec)
        end
    end, sourceKey)
end

------------------------------------------------------------
-- 還給暴雪：停放／認領過的 item 全部放掉、檢視器解開
--
-- 除錯用（/mcdm release），以及引擎啟動失敗時自動叫（ns.StartEngine）：半套的引擎會把
-- item 停在畫面外（alpha 0、錨 UIParent (-10000, 10000)）卻沒有任何路徑放回來。
--   * 每個追蹤過的 item：alpha 1、ClearAllPoints、尺寸還原成第一次看到時的（讀得到才有）
--     ⇒ 暴雪下一次 Layout／RefreshLayout 會把它們排回它自己的格線
--   * 檢視器 ClearAllPoints＋SetPoint 回 UIParent CENTER（走 ns.Write）
--   * 發光停掉、暴雪的觸發發光 alpha 還回 1、按鍵文字與 overlay 藏起來
--   * 之後 Flush／Reapply／PinViewer／Park、縮放鎖、樣式後掛勾全部停手（B.released）
-- 回不去：要重新接管就 /reload。圖示遮罩、轉圈材質、字型這些改過的樣式不還原。
------------------------------------------------------------
function B.ReleaseAll(reason)
    B.released = true
    B.releaseReason = reason or "manual"
    ns.released = true
    for key in pairs(dirty) do
        if not panels[key] then dirty[key] = nil end
    end
    if ns.Glow then ns.Glow.ownsProcAlert = false end
    for item, rec in pairs(ns.Viewers.frames) do
        claimedBy[item] = nil
        rec.claimKey = nil
        rec.parked = true                -- Glow 的 Hidden：之後的掛勾不再畫發光
        if ns.Glow then pcall(ns.Glow.OnParked, rec) end
        if rec.keyFS then
            pcall(rec.keyFS.SetText, rec.keyFS, "")
            pcall(rec.keyFS.Hide, rec.keyFS)
            rec.keySig = "off"
        end
        if rec.overlay then pcall(rec.overlay.Hide, rec.overlay) end
        local alert = item.SpellActivationAlert
        if alert and alert.SetAlpha then pcall(alert.SetAlpha, alert, 1) end
        pcall(item.SetAlpha, item, 1)
        pcall(item.ClearAllPoints, item)
        if rec.origW and rec.origH then pcall(item.SetSize, item, rec.origW, rec.origH) end
    end
    for id in pairs(slotOf) do slotOf[id] = nil end
    -- 可點擊群組的 secure 鈕：item 已經不在格子上了，鈕跟著收
    if ns.Clickable then xpcall(ns.Clickable.ReleaseAll, ns.ReportError) end
    for key, st in pairs(state) do
        if not panels[key] then st.count = 0 end
    end
    for _, src in ipairs(ns.Viewers.ORDER) do
        local viewer = pinned[src] and ns.Viewers.Get(src)
        if viewer then
            pinned[src] = nil
            ns.Write(viewer, function(v)
                pinGuard = true
                local ok, err = pcall(function()
                    v:ClearAllPoints()
                    v:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end)
                pinGuard = false
                if not ok then error(err, 0) end
            end, "pin")
        end
    end
    if ns.EditMode and ns.EditMode.RestoreDialog then pcall(ns.EditMode.RestoreDialog) end
    if ns.Fire then ns.Fire("Released", B.releaseReason) end
end

function B.ForEachClaimed(key, fn)
    for item, k in pairs(claimedBy) do
        if k == key then
            local rec = ns.Viewers.frames[item]
            if rec and not rec.parked then fn(item, rec) end
        end
    end
end

function B.Count(key)
    local st = state[key]
    return st and st.count or 0
end

-- 某條第一列的寬（目前只有核心技能有記）；還沒排過回 0
function B.FirstRowWidth(key)
    return firstRowW[key or "essential"] or 0
end

------------------------------------------------------------
-- 面板（資源條、施法條）
--
--   B.RegisterPanel(key, def)  def = { anchorPoint, minSize = fn → w, h, relayout = fn(level), collapsible }
--                              建容器（EditMode.OnContainer 一併建好覆蓋層／選取框／磁吸）、
--                              照存檔貼位置。回傳容器。
--   B.SetPanelSize(key, w, h)  容器大小（變了才寫，走 ns.Write）。collapsible 的面板 h 可以是 0
--                              （＝收合：框留 1 的高度、排開時不佔位；收合狀態一變就重套結構，整疊重貼）
--   B.IsPanel(key) / B.Panels()
------------------------------------------------------------
function B.RegisterPanel(key, def)
    panels[key] = def or {}
    state[key] = state[key] or { placeholders = { used = 0, pool = {} } }
    state[key].anchorPoint = panels[key].anchorPoint or "CENTER"
    local c = EnsureContainer(key)
    if InCombatLockdown() then structurePending[key] = true; ArmStructurePending() else ApplyStructure(key) end
    return c
end

function B.IsPanel(key) return panels[key] ~= nil end
function B.Panels() return panels end

function B.PanelMinSize(key)
    local pd = panels[key]
    if pd and pd.minSize then return pd.minSize() end
    return nil
end

function B.SetPanelSize(key, w, h)
    local c, st = containers[key], state[key]
    if not (c and st) then return end
    local pd = panels[key]
    local collapsible = pd and pd.collapsible
    w = (w and w > 0) and w or 1
    if collapsible and h == 0 then
        h = 0
    else
        h = (h and h > 0) and h or 1
    end
    local collapsed = (collapsible and h == 0) and true or false
    if st.w == w and st.h == h and (st.collapsed or false) == collapsed then return end
    st.w, st.h = w, h
    -- 框本身永遠留 1 的高度：高度 0 的框沒有有效的矩形，照字面錨在它身上的東西會整個畫不出來。
    -- 收合是邏輯狀態（st.h == 0、st.collapsed），排開時別人會跳過它。
    local fh = h > 0 and h or 1
    ns.Write(c, function(f) f:SetSize(w, fh) end, "size")
    if (st.collapsed or false) ~= collapsed then
        st.collapsed = collapsed
        -- 錨定的 y 偏移跟著收／放：結構級（戰鬥中記帳到脫戰）
        if InCombatLockdown() then structurePending[key] = true; ArmStructurePending() else ApplyStructure(key) end
    end
end

-- 這個 id 在這條上是不是「清單有、暴雪沒給框」（畫不出來）
function B.IsMissing(key, id)
    local m = missing[key]
    return m ~= nil and m[id] == true
end

function B.IsCollapsed(key)
    local st = state[key]
    return st and st.collapsed or false
end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
local initialized = false
function B.Init()
    if initialized then return end
    initialized = true
    local p = Profile()
    if type(p) == "table" and type(p.bars) == "table" then
        for key in pairs(p.bars) do EnsureContainer(key) end
        for key in pairs(p.bars) do ApplyStructure(key) end
    end

    -- 進場（每次讀取畫面結束）與天賦／專精切換之後：整套重來幾輪。
    -- 暴雪在這些時候會在它自己之後的幾幀重建檢視器的框（換專精會重套編輯模式版面、整條重取出），
    -- 那幾幀裡有的訊號我們接得到、有的接不到；與其賭事件順序，不如過一會兒再整套對一次
    -- （樣式簽章清掉、清單重讀、容器重貼、每顆 item 重放重套）。事件處理器只排計時器，不同步做事。
    local E = ns.Events
    E.Register("PLAYER_ENTERING_WORLD", "bars_resync", function() B.Resync("world") end)
    E.Register("LOADING_SCREEN_DISABLED", "bars_resync", function() B.Resync("loading") end)
    E.Register("ACTIVE_TALENT_GROUP_CHANGED", "bars_resync", function() B.Resync("talentgroup") end)
    E.Register("PLAYER_TALENT_UPDATE", "bars_resync", function() B.Resync("talents") end)
    E.Register("TRAIT_CONFIG_UPDATED", "bars_resync", function() B.Resync("talents") end)
    E.Register("EDIT_MODE_LAYOUTS_UPDATED", "bars_resync", function() B.Resync("editlayout") end)
    ns.RegisterCallback("SpecChanged", "bars_resync", function() B.Resync("spec") end)

    ns.RegisterCallback("CatalogChanged", "bars", function()
        -- 覆寫法術可能換了：索引先照現況重建一次（排版那輪結尾會再建）
        if ns.SpellIndex then ns.SpellIndex.Rebuild() end
        if ns.Assist and ns.Assist.Reapply then ns.Assist.Reapply() end
        B.RequestAll("membership")
    end)
    ns.RegisterCallback("CatalogResumed", "bars", function() B.RequestAll("membership") end)
    ns.RegisterCallback("ViewersReady", "bars", function()
        for _, src in ipairs(ns.Viewers.ORDER) do B.PinViewer(src) end
        B.RequestAll("structure")
    end)
    if ns.Viewers.ready then
        for _, src in ipairs(ns.Viewers.ORDER) do B.PinViewer(src) end
        B.RequestAll("structure")
    end
end

-- 設定檔換了：新的條要有容器，舊的收起來
function B.OnProfileChanged()
    local p = Profile()
    if type(p) == "table" and type(p.bars) == "table" then
        for key in pairs(p.bars) do EnsureContainer(key) end
    end
    for id in pairs(slotOf) do slotOf[id] = nil end
    B.RequestAll("structure")
end

-- 除錯用
function B.PendingCount()
    local n = 0
    for _ in pairs(dirty) do n = n + 1 end
    return n
end
function B.SlotCount()
    local n = 0
    for _ in pairs(slotOf) do n = n + 1 end
    return n
end
