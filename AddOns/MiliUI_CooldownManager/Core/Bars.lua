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
-- 走 ns.Write（持有框整條鏈是保護框）。條上有光環格時固定格位強制打開：光環格排在最前面、
-- 其他 item 收合也不會讓它們的 x 變，戰鬥中不必動持有框。
--
-- 檢視器本體釘在容器上（TOPLEFT／BOTTOMRIGHT 對齊），被暴雪（編輯模式、底部管理框）
-- 拉走就釘回來；_pinGuard 擋自己觸發自己。
--
-- 面板（資源條、施法條；ns.Bars.RegisterPanel）：容器同樣是 MiliUICDM_Bar_<key>、
-- 同一套 ApplyStructure（pos／anchor、strata、enabled＝false 就 Hide）與編輯模式／磁吸，
-- 但裡面畫什麼、多大由模組自己管（B.SetPanelSize）。重排排程對面板只做結構級，
-- 其餘交給模組的 relayout 回呼。核心技能第一列寬度變了廣播 "FirstRowWidthChanged"。
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
local function EnsureContainer(key)
    local c = containers[key]
    if c then return c end
    c = CreateFrame("Frame", "MiliUICDM_Bar_" .. key, UIParent, "BackdropTemplate")
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

-- 錨定：anchor（錨在別條上）優先，形成環或目標不存在就退回 pos
local function AnchorTarget(key)
    local bar = BarCfg(key)
    local a = bar and bar.anchor
    if type(a) ~= "table" or type(a.to) ~= "string" or not BarCfg(a.to) then return nil end
    -- 環檢查：沿著 to 走，走回自己就是環
    local seen, cur = { [key] = true }, a.to
    while cur do
        if seen[cur] then return nil end
        seen[cur] = true
        local nb = BarCfg(cur)
        local na = nb and nb.anchor
        cur = (type(na) == "table" and type(na.to) == "string" and BarCfg(na.to)) and na.to or nil
    end
    return a
end

local function ApplyStructure(key)
    local c = EnsureContainer(key)
    local bar = BarCfg(key)
    -- enabled ＝ false 只有面板會有（條沒有這個欄位）
    if not bar or bar.enabled == false then
        -- 條被刪（自訂群組、換設定檔少了這條）或面板關掉：容器收起來，編輯模式的覆蓋層／選取框也收
        --（frame 刪不掉；同一個 key 之後再建回來會重用，ApplyBarNow 看 BarCfg 決定要不要再顯示）
        ns.Write(c, function(f)
            f:Hide()
            if ns.EditMode and ns.EditMode.ApplyBarNow then ns.EditMode.ApplyBarNow(key) end
        end, "shown")
        return
    end
    local st = state[key]
    local anchorPoint = st.anchorPoint or "CENTER"
    local a = AnchorTarget(key)
    local snap = ns.Layout.Snap
    ns.Write(c, function(f)
        f:SetFrameStrata(bar.strata or "MEDIUM")
        f:ClearAllPoints()
        if a then
            EnsureContainer(a.to)
            f:SetPoint(a.point or "TOP", containers[a.to], a.relPoint or "BOTTOM", snap(tonumber(a.x) or 0), snap(tonumber(a.y) or 0))
        else
            local pos = type(bar.pos) == "table" and bar.pos or {}
            -- 容器用版面算出來的錨點（圖示增減時那一邊不動），貼在 UIParent 的 pos.point 上
            f:SetPoint(anchorPoint, UIParent, pos.point or "CENTER", snap(tonumber(pos.x) or 0), snap(tonumber(pos.y) or 0))
        end
        f:Show()
        -- 編輯模式：覆蓋層跟著新的尺寸／錨點重排，磁吸的 Restore 接點
        if ns.EditMode and ns.EditMode.AfterApply then ns.EditMode.AfterApply(key) end
    end, "point")
    st.appliedAnchor = anchorPoint
end
-- 編輯模式在進戰鬥的鬆手窗口（PLAYER_REGEN_DISABLED，鎖定還沒生效）要當場把容器放回去
B.ApplyStructure = ApplyStructure

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

local function Placeholder(key, idx)
    local ph = state[key].placeholders
    local t = ph.pool[idx]
    if not t then
        t = containers[key]:CreateTexture(nil, "BACKGROUND")
        ph.pool[idx] = t
    end
    return t
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

local function BuildIndex()
    local index, dupes = {}, {}
    ns.Viewers.EnumerateItems(function(item, rec)
        local id = rec.cooldownID
        if id ~= nil then
            if index[id] == nil then index[id] = item else dupes[#dupes + 1] = item end
        end
    end)
    return index, dupes
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
        st.count = 0
        if InCombatLockdown() then structurePending[key] = true else ApplyStructure(key) end
        return
    end

    local ids = ns.Catalog.Bar(key)
    local layout = type(bar.layout) == "table" and bar.layout or {}
    -- 條上有光環格 ⇒ 固定格位強制打開（值不動；光環格的持有框戰鬥中不能移）
    local fixed = (layout.fixedSlots or ns.Catalog.BarHasAuraSlot(key)) and true or false
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
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)
            item:SetSize(r.w, r.h)
            item:SetAlpha(alpha)
            if rec then
                rec.parked = false
                rec.claimGen = gen
                rec.claimKey = key
                ns.Decorate.Apply(item, rec, key, r.w, r.h)
                if ns.Glow then ns.Glow.Sync(item, rec, key) end
                if ns.Keybinds then ns.Keybinds.Apply(item, rec, key) end
            end
            slotOf[e.id] = { key = key, x = r.x, y = r.y, w = r.w, h = r.h }
        end
        if e.placeholder then
            phUsed = phUsed + 1
            local t = Placeholder(key, phUsed)
            local info = ns.Catalog.Info(e.id)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)
            t:SetSize(r.w, r.h)
            t:SetTexture((info and info.icon) or QUESTION)
            local z = tonumber(ns.Setting(key, "icon.zoom")) or 0
            t:SetTexCoord(z, 1 - z, z, 1 - z)
            t:SetDesaturated(true)
            t:SetAlpha(0.35)
            t:Show()
        end
    end
    ReleasePlaceholders(key, phUsed + 1)
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

    -- 這一輪要排的條先放掉舊的認領
    for item, key in pairs(claimedBy) do
        if work[key] then claimedBy[item] = nil end
    end
    for id, slot in pairs(slotOf) do
        if work[slot.key] then slotOf[id] = nil end
    end

    -- 暴雪可能剛在它自己的下一幀換了版面／專精：清單先對一次
    ns.Catalog.CheckFresh()
    -- 自訂項目：照目前專精的清單對上框（換專精、刪項目的在這裡收起來）
    if ns.Custom then ns.Custom.Sync() end
    local index = BuildIndex()
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
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", c, "TOPLEFT", slot.x, -slot.y)
            item:SetSize(slot.w, slot.h)
            item:SetAlpha(VisAlpha(slot.key))
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
--   B.RegisterPanel(key, def)  def = { anchorPoint, minSize = fn → w, h, relayout = fn(level) }
--                              建容器（EditMode.OnContainer 一併建好覆蓋層／選取框／磁吸）、
--                              照存檔貼位置。回傳容器。
--   B.SetPanelSize(key, w, h)  容器大小（變了才寫，走 ns.Write）
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
    w = (w and w > 0) and w or 1
    h = (h and h > 0) and h or 1
    if st.w == w and st.h == h then return end
    st.w, st.h = w, h
    ns.Write(c, function(f) f:SetSize(w, h) end, "size")
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

    ns.RegisterCallback("CatalogChanged", "bars", function() B.RequestAll("membership") end)
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
