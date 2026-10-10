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
-- 「增益不在時」三態（收合／留空位／暗圖示；條層 layout.emptyMode ＋ 逐法術 emptyMode，判準 Layout.BarEmptyMode／
-- SpellEmptyMode，條層生效值 B.BarEmptyMode、單格 B.EmptyMode）：光環格／可點擊的條上「收合」不成立（上面那個理由）。
-- 例外：條上**只有**光環格（Catalog.BarAuraFlow）時收合照選，選了走引擎補位（B.AuraFlow）：持有框不各自放，
-- 整條交給一顆 AuraContainer 的 flow layout（Modules/Custom.lua 的「引擎補位」），條容器照「全部都在」的尺寸、戰鬥中不動。
--
-- 代畫（Modules/Custom.lua 的 Custom.Proxy）：清單上有、暴雪沒給框的**裝備欄冷卻格**（Catalog.ProxySlotOf：
-- 暴雪的 id、資料帶裝備欄位、來源是核心／輔助）改放我們的飾品欄框（一格 crec entry，跟自訂項目同一條路）。
-- 暴雪恢復給框的那一輪照舊放暴雪的 item，代畫格沒被放 ⇒ Custom.EndBar 收起來。代畫中的不算 missing（B.IsProxied）。
--
-- 沒有物品時隱藏／被動飾品不顯示（判準 Catalog.HideReason，排法 Layout.HiddenSlot）：自訂物品、飾品欄、代畫格被收掉時
-- **在決定 entries 這一層讓位**（不放進 entries ⇒ Custom.EndBar 收起來、後面的往前補；Occupancy 同一個判準 ⇒ 不算顆數、
-- 溢出跟著重算），不是 alpha 0。固定格位的條（光環格／飾品疊增益／可點擊強制、或玩家自己開）只留空格（blank entry：
-- 佔一格、什麼都不放），位置不動 ⇒ 戰鬥中也不會移動保護框。被收掉的框都是普通框（自訂物品／飾品欄的圖示框），
-- 戰鬥中 Hide 照做；飾品欄的增益疊層持有框（保護框）照舊走 ns.Write 記帳。
-- 會變的訊號：包包數量（BAG_UPDATE_DELAYED）、物品資料到了（GET_ITEM_INFO_RECEIVED）——只在有條需要時註冊
-- （hideWatch，每輪 Relayout 重建；SyncHideEvents）；事件只標記、下一幀重算，結果變了才 RequestAll。
-- 換裝備由 Catalog 的 PLAYER_EQUIPMENT_CHANGED 全部重排，不另外聽。
--
-- 可點擊的自訂圖示群組（Core/Clickable.lua）：每格上面蓋一顆 secure 鈕（parent／錨點都是容器），
-- 一樣強制固定格位；鈕的寫入走 ns.Write＋簽章去重。不可點擊的條每輪 Release（沒鈕就是 no-op）。
--
-- 圓環條（DB.BarIsRings：圖示類＋layout.style ＝ "rings"；幾何 Layout.Compute 的同心圓、外觀 Decorate 的「圓環顯示」）：
--   * 每格的 rect 多帶 ring／tex 兩欄，放格時整個 rect 交給 Decorate.Apply（圈數決定 overlay 層級與貼圖）
--   * **只收增益**（2026-10-08）：暴雪增益檢視器的 item（ns.Viewers.AURA_KIND）＋自訂光環格（含飾品欄增益；Custom.Place
--     收到的 rect 帶 ring／tex，光環格的按鈕在 initializeFrame 裡烘成一圈，見 Modules/Custom.lua 的「光環格畫成圓環」）。
--     暴雪的冷卻格（核心／輔助）、自訂法術／物品／飾品欄冷卻、代畫的裝備欄格**不放**（RingRefuses）：不進 entries、不認領
--     （暴雪的 item 照原本的停放／歸屬走）。跳過幾筆記在 state[key].ringSkipped（/mcdm debug 印），設定頁的挑選器也擋著不讓加。
--     核心／輔助本身沒有圓環（DB.BarIsRings；存著 rings 的照圖示排，BarSize）
--   * 不可點擊（同心圓的格子是一層套一層的正方形，secure 鈕會互相蓋住）
--   * 「增益不在時：暗圖示」的占位只畫那一圈的軌道（Decorate.ApplyRingPlaceholder）
--
-- 檢視器本體釘在容器上（TOPLEFT／BOTTOMRIGHT 對齊），被暴雪（編輯模式、底部管理框）
-- 拉走就釘回來；_pinGuard 擋自己觸發自己。
--
-- 以增益取代（spells[spec].overrides[A].replaceWith = B，判準在 Catalog.Replacements）：A 那一格在 B
-- 生效期間（B 的 item 在（B.AuraPresent）、整條看得到、B.ItemActive 明文 true）改放 B 的 item，A 的 item 不認領（Flush 結尾停放）；
-- 讀不到生效狀態一律放 A。兩種情況格子數一樣，版面不變。格位快取（slotOf）記的是**實際放進去的那個 id**，
-- 暴雪排版後的同步放回（Reapply）才不會把 B 停走、把 A 放回來。B 生效／結束的訊號照舊走
-- RequestSource("buffs")，Catalog.GroupTargets 把 A 所在的條算進去。
--
-- 天空騎術（面板 skyriding，Modules/Skyriding.lua）的接力模式（placement ＝ relay，預設）：跟資源條輪流出現在同一個位置。
--   * 錨定不看自己存的 anchor／pos：貼資源條容器的固定邊（資源條的錨點，預設 BOTTOM；SR.RelayPlace）；資源條關掉或收合（enabled／StackSkip，
--     不讀框的幾何）時改用資源條自己的錨定設定（同樣的 to／point／relPoint／x／y），資源條也沒錨定就用資源條的 pos。
--   * 不參與排開：不進 StackKeys、AnchorCfg 把它當不存在（別人不能把它當排開目標，錨在它身上的改用自己的 pos）。
--   * 資源條的結構一套完（ApplyOne）就跟著重貼它（開關會換錨定目標）。
--   獨立擺放（standalone）時就是一般的面板。
--
-- 面板（資源條、自訂格子、施法條、下一招圖示、天空騎術；ns.Bars.RegisterPanel）：容器同樣是 MiliUICDM_Bar_<key>、
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
local replacedNow = {}         -- A 的 cooldownID → { b = B 的 cooldownID, key = 條 }（以增益取代：現在放的是 B）
local firstRowW = {}           -- key → 第一列寬（長條寬 0 ＝ 跟核心技能第一列同寬）
local scheduled, lastRun = false, -1
local ArmStructurePending          -- 前置宣告（定義在 Relayout 前面）
local viewerShown = {}             -- 來源條 → 檢視器上一次看到是不是顯示中（稽核用）
local missing, missingSig = {}, {} -- 條 → { [id] = true }：清單上有、暴雪沒有給框的（稽核用，預覽讀）
local proxied, proxiedSig = {}, {} -- 條 → { [id] = 裝備欄位 }：暴雪沒給框、由我們代畫的（稽核用，預覽讀）
-- 條 → { ids = { id… }, n, wsig, hsig, bag, info }：這條上要聽事件才知道會不會收掉的格（沒有物品時隱藏／被動飾品不顯示）。
--   ids／n  watch 不是 nil 的那幾格（Catalog.HideReason 的第二個回傳）
--   wsig    那幾格的「理由:watch」串（事件來時重算比對，變了才重排）
--   hsig    這條被收掉的格（理由）串：變了就通知設定頁預覽（MissingChanged）
local hideWatch = {}
local pinGuard, parkGuard = false, false
local pinned = {}                  -- 釘過的檢視器（ReleaseAll 只解這些，沒碰過的不動）
B.ready = false
B.flushes = 0
-- /mcdm perf 的計數（Api.lua；只 +1，不配置）。requestSourceHit 是 RequestSource 快取命中，快取還沒做之前一直是 0
B.requestSource, B.requestSourceHit = 0, 0
B.reapplyItems, B.relayoutBars = 0, 0
-- 這一輪排版之後「認領中的 item／放好的自訂法術」可能變了 ⇒ Flush 結尾重建法術索引（Core/SpellIndex.lua）。
-- 設的地方：Relayout 的認領序列跟上一輪不同、Custom.Place 回報換了框／條、自訂項目收起來（Custom 的 HideRec）、
-- 停放掃描收走了認領中的 item、拖曳中的條這一輪不排、某條 Relayout 拋錯。Flush 重建後清掉
B.claimsChanged = true
-- RequestSource 的目標快取：sourceKey → { gen = B.flushes, keys = { [條] = true } }。見 RequestSource
local sourceTargets = {}
local flushing = false           -- Flush 執行中不寫快取（認領正在改，算出來的是過渡狀態）

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
-- 天空騎術的接力模式（Modules/Skyriding.lua）
local SKY = "skyriding"
local function SkyRelay()
    local SR = ns.Skyriding
    return SR and SR.RelayMode and SR.RelayMode() or false
end
B.SkyRelay = SkyRelay

local function AnchorCfg(key)
    if ns.Cursor and ns.Cursor.Configured(key) then return nil end
    -- 接力中的天空騎術不是任何人的錨定／排開目標
    if key == SKY and SkyRelay() then return nil end
    return BarCfg(key)
end

-- 錨定：anchor（錨在別條上）優先，形成環或目標不存在就退回 pos
local function AnchorTarget(key)
    return ns.Layout.AnchorOf(key, AnchorCfg)
end

-- 排開：跟著同一個目標、同一邊的照這個順序往外排（小的靠近目標），規則在 Core/Layout.lua。
-- 自訂群組排在內建的後面，彼此照左欄順序；下一招圖示排在所有東西的最後面（最外圈）。
-- 天空騎術（只有獨立擺放時參與排開）緊貼在資源條外面
local STACK_RANK = { resources = 1, skyriding = 1.5, pips = 2, utility = 3, castbar = 4, buffs = 5, buffbars = 6, essential = 7,
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
    local relay = SkyRelay()
    for _, k in ipairs(ns.DB.PANEL_ORDER) do
        -- 接力中的天空騎術不參與排開（不然會把輔助技能、施法條往外推）
        if BarCfg(k) and not (k == SKY and relay) then keys[#keys + 1] = k end
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

-- ── 半像素補正 ──────────────────────────────────────────────────────
-- 容器的錨點多半是置中的（CENTER、TOP→BOTTOM）：自己跟錨定對象的寬（或高）換成實體像素後奇偶不同，
-- 左緣（上緣）就落在半個像素上。裡面每條 1px 的邊、格距被引擎各自四捨五入成 0／1／2px，
-- 玩家看到的是「資源條的間隔粗細不一」（2026-10-04 回報：術士靈魂裂片）。
-- 補法：偏移量多給半個像素，讓邊緣落回整數像素。只看尺寸、不讀位置 ⇒ 每個容器自己對齊、錨定對象也對齊，
-- 整條鏈就都在格線上（UIParent 的左緣是 0，寬是整數像素）。
-- 尺寸的奇偶一變（圖示增減、面板改高）就要重貼：自己、和直接貼在它身上的條（PixelRefix）。
-- 補正量不進存檔：存的 pos／anchor 偏移照舊，st.place 記「補正前」的那一組。
local function HFactor(p)
    if p:find("LEFT") then return 0 elseif p:find("RIGHT") then return 1 end
    return 0.5
end
local function VFactor(p)
    if p:find("TOP") then return 1 elseif p:find("BOTTOM") then return 0 end
    return 0.5
end
local function PixelCount(v, px)
    return math.floor((tonumber(v) or 0) / px + 0.5)
end
-- 回傳 dx, dy（0 或半個像素，UI 單位）
local function HalfPixelFix(f, point, rel, relPoint)
    local P = ns.P
    local px = P and P.Scale and P.Scale(1)
    if not (px and px > 0 and rel and rel.GetSize) then return 0, 0 end
    local w, h = f:GetSize()
    local rw, rh = rel:GetSize()
    local fx = (PixelCount(rw, px) * HFactor(relPoint) - PixelCount(w, px) * HFactor(point)) % 1
    local fy = (PixelCount(rh, px) * VFactor(relPoint) - PixelCount(h, px) * VFactor(point)) % 1
    return (fx ~= 0) and px / 2 or 0, (fy ~= 0) and px / 2 or 0
end
B.HalfPixelFix = HalfPixelFix                     -- 測試用

local function SetPlace(f, st, point, rel, relPoint, x, y)
    local dx, dy = HalfPixelFix(f, point, rel, relPoint)
    st.place = { point, rel, relPoint, x, y }
    st.placeFix = dx .. "," .. dy
    f:SetPoint(point, rel, relPoint, x + dx, y + dy)
end

-- 容器貼到位置（錨在別條上優先、否則 pos）；已經在 ns.Write 裡
local function PlaceContainer(f, key, bar, st)
    -- 跟著游標（編輯模式中、設定視窗開著時不跟：照下面貼回存檔位置）
    if ns.Cursor and ns.Cursor.Following(key) then
        st.stackTo = nil
        st.place = nil
        ns.Cursor.Place(f, key)
        return
    end
    local snap = ns.Layout.Snap
    if key == SKY and SkyRelay() then
        -- 接力：跟資源條同一個位置（規則見檔頭與 Modules/Skyriding.lua 的 SR.RelayPlace）
        f:ClearAllPoints()
        local res = AnchorCfg("resources")
        local usable = res ~= nil and res.enabled ~= false and not StackSkip("resources")
        local kind, t = ns.Skyriding.RelayPlace(res, usable, B.AnchorPoint("resources"))
        if kind == "anchor" and AnchorCfg(t.to) then
            EnsureContainer(t.to)
            SetPlace(f, st, t.point, containers[t.to], t.relPoint, snap(t.x), snap(t.y))
            st.stackTo = t.to
            return
        end
        -- 沒有可錨的目標：資源條自己的 pos，貼在資源條的錨點那一邊
        if kind ~= "pos" then
            local p = type(res) == "table" and type(res.pos) == "table" and res.pos or {}
            t = { point = p.point or "CENTER", x = tonumber(p.x) or 0, y = tonumber(p.y) or 0 }
        end
        st.stackTo = nil
        SetPlace(f, st, B.AnchorPoint("resources"), UIParent, t.point, snap(t.x), snap(t.y))
        return
    end
    local a = AnchorTarget(key)
    f:ClearAllPoints()
    if a then
        -- 貼在「排開」算出來的那一條上（同一邊已經有別人就貼在它外面），邊與偏移照自己的設定
        local to = StackTarget(key) or a.to
        EnsureContainer(to)
        local y = snap(tonumber(a.y) or 0)
        if st.collapsed and VerticalAnchor(a) then y = 0 end
        SetPlace(f, st, a.point or "TOP", containers[to], a.relPoint or "BOTTOM", snap(tonumber(a.x) or 0), y)
        st.stackTo = to
    else
        st.stackTo = nil
        local pos = type(bar.pos) == "table" and bar.pos or {}
        -- 容器用版面算出來的錨點（圖示增減時那一邊不動），貼在 UIParent 的 pos.point 上
        SetPlace(f, st, st.anchorPoint or "CENTER", UIParent, pos.point or "CENTER", snap(tonumber(pos.x) or 0), snap(tonumber(pos.y) or 0))
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
        -- 資源條關掉：接力中的天空騎術改用資源條自己的錨定（見下面 Show 那條路的同一段）
        if key == "resources" and containers[SKY] and SkyRelay() then ApplyOne(SKY) end
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
    -- 資源條的結構變了（開關、位置）：接力中的天空騎術跟著重貼（沒有人錨在它身上，直接貼不會成環）
    if key == "resources" and containers[SKY] and SkyRelay() then ApplyOne(SKY) end
end

-- 尺寸變了以後：補正量不一樣了就照同一組錨點重貼（不重算排開 ⇒ 不會撞上錨定循環）
local function RefixOne(k)
    local c, st = containers[k], state[k]
    if not (c and st and st.place) or k == ns.dragging then return end
    local p = st.place
    local dx, dy = HalfPixelFix(c, p[1], p[2], p[3])
    if st.placeFix == dx .. "," .. dy then return end
    ns.Write(c, function(f)
        local q = st.place
        if not q then return end
        f:ClearAllPoints()
        SetPlace(f, st, q[1], q[2], q[3], q[4], q[5])
    end, "pixfix")
end
-- 自己、和直接貼在它身上的條（再往外的只看自己跟直接對象的尺寸，不受影響）
local function PixelRefix(key)
    RefixOne(key)
    for k, st in pairs(state) do
        if k ~= key and st.stackTo == key then RefixOne(k) end
    end
end
B.PixelRefix = PixelRefix

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

-- 天空騎術切換接力／獨立擺放（設定頁叫）：錨定關係整個換了一套。先把天空騎術與「現在貼在它身上」的條全部拆錨，
-- 那些條先照新規則貼回去、天空騎術最後貼——不然資源條還貼著天空騎術時，天空騎術改貼資源條會撞上
-- 「錨在依賴自己的框上」。之後整疊再對一次（結構級）
function B.SkyPlacementChanged()
    local sky = containers[SKY]
    if not sky then return end
    if InCombatLockdown() then
        B.RequestAll("structure")
        return
    end
    local list = {}
    for k, st in pairs(state) do
        local onSky = st.stackTo == SKY or (type(st.place) == "table" and st.place[2] == sky)
        if k ~= SKY and containers[k] and onSky then list[#list + 1] = k end
    end
    ns.Write(sky, function(f) f:ClearAllPoints() end, "point")
    for i = 1, #list do
        ns.Write(containers[list[i]], function(f) f:ClearAllPoints() end, "point")
    end
    restacking = true
    for i = 1, #list do
        local ok, err = xpcall(ApplyOne, ns.ReportError, list[i])
        if not ok then B.lastError = err end
    end
    local ok, err = xpcall(ApplyOne, ns.ReportError, SKY)
    if not ok then B.lastError = err end
    restacking = false
    B.RequestAll("structure")
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
        rec.replacing = nil
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

-- 生效狀態：暴雪 item 自己的 IsActive()（欄位 isActive；Glow 的生效發光讀的是同一個）。
-- **不能用 IsShown**：暴雪「未作用時隱藏」沒勾時，增益不在 item 照樣顯示（暗條／暗圖示）——
-- 判在不在一律看這個（EllesmereUI 的追蹤長條同一招）。讀不到（秘密／沒有這支）回 nil ＝ 當作在（fail-open，
-- 跟 SafeShown 同方向：寧可多畫一格，不要把真的在的增益收掉）。
local function ItemActive(item)
    local fn = item.IsActive
    if type(fn) == "function" then
        local ok, v = pcall(fn, item)
        if ok and not ns.IsSecret(v) and v ~= nil then return v and true or false end
    end
    local v = rawget(item, "isActive")
    if ns.IsSecret(v) or v == nil then return nil end
    return v and true or false
end
B.ItemActive = ItemActive

-- 增益 item 這一刻算不算「在」：顯示中、而且不是暴雪畫的未作用暗格。
-- 編輯模式例外：暴雪在編輯模式把全部 item 顯示出來給人拖，這裡也照舊全部排（不看生效）
local function AuraPresent(item)
    if not SafeShown(item) then return false end
    if ns.EditMode and ns.EditMode.active then return true end
    return ItemActive(item) ~= false
end
B.AuraPresent = AuraPresent

-- 「增益不在時」的條層生效值（Layout.BarEmptyMode）：forced（收合不成立）＝ 條上有光環格而且走不了引擎補位
-- （Catalog.BarAuraFlow 不成立：混排、圓環、溢出…），或可點擊。只有光環格的條（BarAuraFlow 成立）收合照選，
-- 選了就走引擎補位（B.AuraFlow、Modules/Custom.lua 的「引擎補位」）。
-- 回 mode, forced。Relayout、Occupancy、設定頁共用
function B.BarEmptyMode(barKey)
    local bar = BarCfg(barKey)
    local layout = bar and type(bar.layout) == "table" and bar.layout or {}
    local C = ns.Catalog
    local aura = C.BarHasAuraSlot(barKey) and not (C.BarAuraFlow and C.BarAuraFlow(barKey))
    local forced = (aura or (ns.Clickable and ns.Clickable.Enabled(barKey))) and true or false
    return ns.Layout.BarEmptyMode(layout.emptyMode, forced, bar and bar.kind == "bars", layout.emptyStyle), forced
end

-- 這條現在走引擎補位嗎：只有光環格（BarAuraFlow 成立）而且條層生效的「增益不在時」是收合
function B.AuraFlow(barKey)
    local C = ns.Catalog
    if not (C.BarAuraFlow and C.BarHasAuraSlot(barKey)) then return false end
    if not C.BarAuraFlow(barKey) then return false end
    return (B.BarEmptyMode(barKey)) == "collapse"
end

-- 逐法術那一列的 forced：條層 forced 之外，光環格的條**沒在補位**（條層選了留空位／暗圖示）時單格也不能收合
-- （固定格位的持有框戰鬥中不能動）。補位中單格選收合＝跟著條，選留空位／暗圖示會讓整條退回固定格位（BarAuraFlow 的 "spell"）。
-- 回 barMode, forced
function B.SpellEmptyForced(barKey)
    local barMode, forced = B.BarEmptyMode(barKey)
    if not forced and barMode ~= "collapse" and ns.Catalog.BarHasAuraSlot(barKey) then forced = true end
    return barMode, forced
end

-- 這一格生效的「增益不在時」（逐法術覆寫 emptyMode ＞ 條層）：回 mode, own（own ＝ 這一格自己設的）
function B.EmptyMode(barKey, id)
    local barMode, forced = B.SpellEmptyForced(barKey)
    return ns.Layout.SpellEmptyMode(ns.SpellSetting(barKey, id, "emptyMode"), barMode, forced)
end

-- 溢出的佔位判斷（Catalog.SetOccupancy；每輪 Flush 建好索引後換一支）：這一顆在來源條上佔不佔一格。
-- 跟 Relayout 放格同一個判準：暴雪沒給框的不佔；增益類不在、而且這一格生效的「增益不在時」是收合的不佔
-- （留空位／暗圖示都佔）。自訂項目一律佔（光環格會讓收合不成立；自訂法術／物品一直都有框）
-- 圓環條（只收增益）放不下這一格嗎：自訂項目只收光環格（含飾品欄增益；rec.kind ＝ "aura"），
-- 暴雪的格子只收增益類檢視器的 item（ns.Viewers.AURA_KIND）。代畫格（暴雪沒給框的裝備欄冷卻格）一律不收。
-- 暴雪沒給框、也不是代畫的：不放什麼，不算跳過
local function RingRefuses(id, item, crec)
    if crec then return crec.kind ~= "aura" end
    if item then
        local rec = ns.Viewers.frames[item]
        return not (rec and ns.Viewers.AURA_KIND[rec.barKey])
    end
    return ns.Catalog.ProxySlotOf and ns.Catalog.ProxySlotOf(id) ~= nil or false
end
B.RingRefuses = RingRefuses           -- 測試用

function B.Occupancy(index)
    local modeOf, forcedOf = {}, {}
    local function BarMode(barKey)
        local mode = modeOf[barKey]
        if mode == nil then
            mode, forcedOf[barKey] = B.BarEmptyMode(barKey)
            modeOf[barKey] = mode
        end
        return mode, forcedOf[barKey]
    end
    local function Fixed(barKey) return BarMode(barKey) ~= "collapse" end
    -- 沒有物品時隱藏／被動飾品不顯示：讓位的（Layout.HiddenSlot ＝ "skip"）不佔；固定格位留空格的照佔
    local function Skipped(barKey, id)
        local why = ns.Catalog.HideReason and ns.Catalog.HideReason(barKey, id)
        return why ~= nil and ns.Layout.HiddenSlot(why, Fixed(barKey)) == "skip"
    end
    -- 圓環條只收增益：放不上去的不佔格（跟 Relayout 的 RingRefuses 同一個判準）
    local ringOf = {}
    local function RingBar(barKey)
        local v = ringOf[barKey]
        if v == nil then
            v = ns.DB.BarIsRings(barKey)
            ringOf[barKey] = v
        end
        return v
    end
    return function(barKey, id)
        if RingBar(barKey) and RingRefuses(id, index[id], ns.Custom and ns.Custom.Get(id)) then return false end
        if type(id) ~= "number" then return not Skipped(barKey, id) end
        local item = index[id]
        -- 暴雪沒給框：代畫的裝備欄冷卻格照樣佔一格（Relayout 會放它；被收掉讓位的不佔），其餘不佔
        if not item then return ns.Catalog.ProxySlotOf(id) ~= nil and not Skipped(barKey, id) end
        local rec = ns.Viewers.frames[item]
        if not (rec and ns.Viewers.AURA_KIND[rec.barKey]) then return true end
        if AuraPresent(item) then return true end
        -- 這一格生效的「增益不在時」不是收合 ⇒ 格子照留、照樣佔一格（跟 Relayout 同一支判準 Layout.AuraSlot）
        local barMode, forced = BarMode(barKey)
        local mode = ns.Layout.SpellEmptyMode(ns.SpellSetting(barKey, id, "emptyMode"), barMode, forced)
        return ns.Layout.AuraSlot(false, mode) ~= nil
    end
end

-- 以增益取代用：B 的 item 真的看得到（自己顯示＋整條增益檢視器沒被暴雪藏起來，例如編輯模式的
-- 「可見：只在戰鬥中」）。看不到還換過去會變成一格空的。讀不到當看得到（同 SafeShown）
local function SafeVisible(item)
    local ok, v = pcall(item.IsVisible, item)
    if not ok or ns.IsSecret(v) then return true end
    return v and true or false
end

-- 占位格是自己的框，畫在容器上；item 出現時蓋在它上面
--   圖示類：圖示貼圖（去飽和、半透明）＋跟真實格一樣的邊框
--   長條類：一條空的長條（照 EllesmereUI「未作用時隱藏」關掉時的樣子）——灰圖示＋底色＋灰名字，填充 0、
--           沒有倒數與層數（跟自訂光環長條的占位同一個樣子）。結構跟設定頁預覽的假長條一樣，外觀走同一支
--           Decorate.ApplyPreview
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

local function BarPlaceholder(key, idx)
    local ph = state[key].placeholders
    ph.barPool = ph.barPool or {}
    local f = ph.barPool[idx]
    if not f then
        local c = containers[key]
        f = CreateFrame("Frame", nil, c)
        f:SetFrameLevel(c:GetFrameLevel())
        local icon = CreateFrame("Frame", nil, f)
        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
        icon.Icon:SetAllPoints()
        icon.Applications = icon:CreateFontString(nil, "OVERLAY")
        icon.Applications:SetFontObject(GameFontHighlightSmall)   -- 先有字型才能 SetText（樣式由 ApplyPreview 蓋）
        f.Icon = icon
        local bar = CreateFrame("StatusBar", nil, f)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar.BarBG = bar:CreateTexture(nil, "BACKGROUND")
        bar.Name = bar:CreateFontString(nil, "OVERLAY")
        bar.Name:SetFontObject(GameFontHighlightSmall)
        bar.Name:SetWordWrap(false)
        bar.Duration = bar:CreateFontString(nil, "OVERLAY")
        bar.Duration:SetFontObject(GameFontHighlightSmall)
        f.Bar = bar
        local ov = CreateFrame("Frame", nil, f)
        ov:SetAllPoints()
        ov:SetFrameLevel(f:GetFrameLevel() + 5)
        f.overlay = ov
        f.aura = true
        ph.barPool[idx] = f
    end
    return f
end

local function ReleasePlaceholders(key, from, barFrom)
    local ph = state[key].placeholders
    for i = from, #ph.pool do ph.pool[i]:Hide() end
    ph.used = from - 1
    local bp = ph.barPool
    if bp then for i = barFrom or 1, #bp do bp[i]:Hide() end end
end

local QUESTION = 134400   -- INV_Misc_QuestionMark

------------------------------------------------------------
-- 一條的重排
------------------------------------------------------------
-- 這條的 alpha：Relayout 用 Refresh（同時套容器、寫 current，不跑 item 迴圈：放格時每個 item 各自套）
local function VisRefresh(key, s)
    local V = ns.Visibility
    if V and V.Refresh then return V.Refresh(key, s) end
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
    if bar.kind ~= "bars" then
        -- 圓環：基準直徑沿用 size.w；環寬／間距／方向在條的 ring 子表（Layout.Compute 讀 layout.ring）
        if ns.Layout.IsRings(layout, bar.kind, bar.source) then
            return { style = "rings", size = layout.size, ring = bar.ring }
        end
        -- 核心／輔助存著 rings（圓環條只收增益，見檔頭）：照圖示排
        if layout.style == "rings" then return ns.Layout.AsIcons(layout) end
        return layout
    end
    local cfg = type(bar.bar) == "table" and bar.bar or {}
    local w = tonumber(cfg.width) or 0
    if w <= 0 then
        w = firstRowW.essential or 0
        if w <= 0 then w = (type(layout.size) == "table" and tonumber(layout.size.w)) or 200 end
    end
    local h = tonumber(cfg.height) or (type(layout.size) == "table" and tonumber(layout.size.h)) or 20
    -- 直向（F8c）：「寬」是條長、「高」是粗細 ⇒ 格子轉 90 度，條並排（Layout.Compute 看 vertical）
    local vertical = cfg.vertical and true or false
    w, h = ns.Layout.BarCellSize(w, h, vertical)
    return { maxPerRow = 1, spacing = layout.spacing, grow = layout.grow, size = { w = w, h = h }, vertical = vertical }
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

------------------------------------------------------------
-- 沒有物品時隱藏／被動飾品不顯示：每輪的記帳與事件（見檔頭與 hideWatch）
------------------------------------------------------------
-- 這一格要不要收、怎麼收（Layout.HiddenSlot：nil 照常｜"blank" 空格｜"skip" 讓位）；順手記 hideWatch
local function HiddenMode(key, id, hw, fixed)
    local why, watch = ns.Catalog.HideReason(key, id)
    if watch then
        local n = hw.n + 1
        hw.n = n
        hw.ids[n] = id
        if watch == "bag" then hw.bag = true else hw.info = true end
        hw.wnext = hw.wnext .. tostring(id) .. ":" .. tostring(why) .. ":" .. watch .. ","
    end
    if why then hw.hnext = hw.hnext .. tostring(id) .. "=" .. why .. "," end
    return ns.Layout.HiddenSlot(why, fixed)
end

local function EndHideWatch(key, hw)
    for i = #hw.ids, hw.n + 1, -1 do hw.ids[i] = nil end
    hw.wsig = hw.wnext
    if hw.hsig ~= hw.hnext then
        hw.hsig = hw.hnext
        if ns.Fire then ns.Fire("MissingChanged", key) end       -- 設定頁預覽：被收掉的格畫暗＋提示
    end
    hw.wnext, hw.hnext = nil, nil
end

-- 事件來了（下一幀）：要聽的那幾格重算一次，「理由:watch」變了才整套重排（溢出可能跟著變，所以不只排這一條）
local hideArmed = false
local function HideRecheck()
    hideArmed = false
    for key, hw in pairs(hideWatch) do
        if hw.n > 0 and BarCfg(key) then
            local sig = ""
            for i = 1, hw.n do
                local id = hw.ids[i]
                local why, watch = ns.Catalog.HideReason(key, id)
                if watch then sig = sig .. tostring(id) .. ":" .. tostring(why) .. ":" .. watch .. "," end
            end
            if sig ~= hw.wsig then
                -- 每一條都排（不含面板）：收掉的格可能是溢過來的，來源條的清單也跟著變
                local p = Profile()
                for k in pairs(type(p) == "table" and type(p.bars) == "table" and p.bars or {}) do
                    B.Request(k, "membership")
                end
                return
            end
        end
    end
end
B.HideRecheck = HideRecheck           -- 測試用

local function OnHideEvent()
    if hideArmed then return end
    hideArmed = true
    ns.Defer(HideRecheck)
end

-- 有條需要才註冊（Flush 結尾叫；照 Custom.SyncEvents 的模式）
local hideEvOn = {}
B.hideEvOn = hideEvOn                 -- 測試、/mcdm debug 用
local function SetHideEvent(ev, want, E)
    if want and not hideEvOn[ev] then
        hideEvOn[ev] = true
        E.Register(ev, "bars_hide", OnHideEvent)
    elseif not want and hideEvOn[ev] then
        hideEvOn[ev] = nil
        E.Unregister(ev, "bars_hide")
    end
end
local function SyncHideEvents()
    local E = ns.Events
    if not (E and E.Register and E.Unregister) then return end
    local bag, info = false, false
    for key, hw in pairs(hideWatch) do
        if BarCfg(key) then
            if hw.bag then bag = true end
            if hw.info then info = true end
        end
    end
    SetHideEvent("BAG_UPDATE_DELAYED", bag, E)
    SetHideEvent("GET_ITEM_INFO_RECEIVED", info, E)
end
B.SyncHideEvents = SyncHideEvents     -- 測試用

local SeqPut, SeqTrim                -- ns.Layout 的（Relayout 第一次用到才取：Layout.lua 載入順序在後面也沒關係）

local function Relayout(key, level, index, gen, s)
    if panels[key] then return RelayoutPanel(key, level) end
    B.relayoutBars = B.relayoutBars + 1
    local c = EnsureContainer(key)
    local bar = BarCfg(key)
    local st = state[key]
    if not bar then
        ReleasePlaceholders(key, 1)
        if ns.Clickable then ns.Clickable.Release(key) end      -- 群組被刪：secure 鈕收起來、脫離錨點
        st.count = 0
        proxied[key], proxiedSig[key] = nil, nil                -- 代畫格由 Custom.EndFlush 收（條不在了）
        hideWatch[key] = nil
        -- 認領序列清空（之前有認領 ⇒ 法術索引要重建）
        if st.claimSeq and #st.claimSeq > 0 then
            for i = #st.claimSeq, 1, -1 do st.claimSeq[i] = nil end
            B.claimsChanged = true
        end
        if InCombatLockdown() then structurePending[key] = true else ApplyStructure(key) end
        return
    end

    local ids = ns.Catalog.Bar(key)
    -- 稽核：清單上有、暴雪卻沒有給框的（只看核心／輔助這兩類：它們的 item 一直都在；增益類不在時本來就可能沒有框）。
    -- 裝備欄冷卻格由我們代畫（proxyOf，下面放格用；記 [proxy]），其餘畫不出來（圖示是暴雪的框），設定頁的預覽
    -- 會把這幾格標暗並說明；變了才記一筆、才通知預覽
    local proxyOf = nil
    do
        local gone, sig = nil, ""
        local pSig = ""
        for _, id in ipairs(ids) do
            if type(id) == "number" and index[id] == nil then
                local src = ns.Catalog.SourceOf(id)
                if src and not ns.Viewers.AURA_KIND[src] then
                    local slot = ns.Custom and ns.Custom.Proxy and ns.Catalog.ProxySlotOf(id)
                    if slot then
                        proxyOf = proxyOf or {}
                        proxyOf[id] = slot
                        pSig = pSig .. id .. ":" .. slot .. ","
                    else
                        gone = gone or {}
                        gone[id] = true
                        sig = sig .. id .. ","
                    end
                end
            end
        end
        if (proxiedSig[key] or "") ~= pSig then
            proxiedSig[key] = pSig
            proxied[key] = proxyOf
            if pSig ~= "" and ns.Diag then
                local parts = {}
                for id, slot in pairs(proxyOf) do parts[#parts + 1] = ("%d（槽%d）"):format(id, slot) end
                table.sort(parts)
                ns.Diag.Note("proxy", ("%s：代畫 %s"):format(key, table.concat(parts, "、")))
            end
            if sig == (missingSig[key] or "") and ns.Fire then ns.Fire("MissingChanged", key) end
        end
        if (missingSig[key] or "") ~= sig then
            missingSig[key] = sig
            missing[key] = gone
            if sig ~= "" and ns.Diag then
                ns.Diag.Note("missing", ("%s：清單上有、暴雪沒有給框：%s"):format(key, sig))
                -- 每一格暴雪自己怎麼看（API 與暴雪快取的 isKnown、裝備欄那一格的物品）：「有時候」的那一刻記下來
                if ns.Catalog.KnownProbe then
                    for id in pairs(gone) do
                        ns.Diag.Note("missing", "  " .. ns.Catalog.KnownProbe(id))
                    end
                end
            end
            if ns.Fire then ns.Fire("MissingChanged", key) end
        end
    end
    -- 增益不在時（條層）：條上有光環格、或這條可點擊 ⇒ 收合不成立（光環格的持有框與可點擊的 secure 鈕戰鬥中都不能移）。
    -- fixed ＝ 條層不收合：沒有物品時隱藏／被動飾品不顯示的格留空格（Layout.HiddenSlot）
    local ring = ns.Layout.IsRings(bar.layout, bar.kind, bar.source)
    -- 圓環條不可點擊（見檔頭）
    local clickable = not ring and ns.Clickable and ns.Clickable.Enabled(key) or false
    local ringSkipped = 0
    local barMode, forced = B.BarEmptyMode(key)
    local fixed = barMode ~= "collapse"
    -- 引擎補位（B.AuraFlow；只有光環格、條層收合）：光環格不各自放持有框，整條交給一顆 AuraContainer 排
    -- （Custom.PlaceFlow）。收合成立而條上有光環格 ⇔ BarAuraFlow 成立（不成立時 forced 會擋掉收合）
    local flow = (not ring) and (not forced) and barMode == "collapse" and ns.Catalog.BarHasAuraSlot(key) or false
    local flowRecs = flow and {} or nil
    local entries = {}
    -- 沒有物品時隱藏／被動飾品不顯示：這一輪重記要聽的格（就地改寫，見 hideWatch）
    local hw = hideWatch[key]
    if not hw then hw = { ids = {}, n = 0, wsig = "", hsig = "" }; hideWatch[key] = hw end
    hw.n, hw.bag, hw.info, hw.wnext, hw.hnext = 0, false, false, "", ""
    -- 以增益取代：A → B（只有成立的才在表裡）
    local replaceOf = ns.Catalog.Replacements and ns.Catalog.Replacements() or {}
    for _, id in ipairs(ids) do
        local item = index[id]
        local crec = ns.Custom and ns.Custom.Get(id)
        local bID = (not crec) and item and replaceOf[id] or nil
        -- 圓環條只收增益（見檔頭）：暴雪的冷卻格、自訂法術／物品／飾品欄冷卻、代畫格不放
        local ringNo = ring and RingRefuses(id, item, crec) or false
        local bItem = bID and index[bID] or nil
        local bRec = bItem and ns.Viewers.frames[bItem] or nil
        -- B 在不在跟增益條同一個判準（AuraPresent：顯示中＋不是未作用暗格），再加整條增益檢視器看得到；
        -- 生效只認 ItemActive 的明文 true（讀不到回 nil ⇒ ReplaceNow 當沒生效、放 A）。
        -- 編輯模式下 AuraPresent 一律算在，但 active 仍要真的生效才換
        if ringNo then
            -- 不進 entries、不認領 ⇒ 自訂框由 Custom.EndBar 收起來、暴雪的 item 照原本的停放／歸屬走
            ringSkipped = ringSkipped + 1
        elseif bRec and ns.Catalog.ReplaceNow({
                item = true, free = not claimedBy[bItem], shown = AuraPresent(bItem) and SafeVisible(bItem),
                active = ItemActive(bItem) }) then
            -- B 生效中：這一格放 B 的 item（樣式照這一條、發光／層數／音效照 B 自己的逐法術覆寫）。
            -- A 的 item 不認領 ⇒ Flush 結尾停放
            entries[#entries + 1] = { id = bID, item = bItem, rec = bRec, replaces = id }
            claimedBy[bItem] = key
            replacedNow[id] = { b = bID, key = key }
        elseif crec then
            -- 自訂物品／飾品欄：沒有物品時隱藏／被動飾品不顯示（讓位 ⇒ 不放；固定格位 ⇒ 空格）
            local hm = (crec.kind == "item" or crec.kind == "slot" or crec.slotBuff) and HiddenMode(key, id, hw, fixed) or nil
            if hm == nil then
                entries[#entries + 1] = { id = id, crec = crec }
            elseif hm == "blank" then
                entries[#entries + 1] = { id = id, blank = true }
            end
        elseif not item and proxyOf and proxyOf[id] then
            -- 暴雪沒給框的裝備欄冷卻格：我們的飾品欄框代畫（Custom.Proxy；放格、疊層、按鍵文字、可點擊都走自訂那條）。
            -- 被動飾品不顯示同上（收掉時不拿代畫 rec ⇒ 上一輪放過的由 EndBar 收）
            local hm = HiddenMode(key, id, hw, fixed)
            if hm == nil then
                entries[#entries + 1] = { id = id, crec = ns.Custom.Proxy(id, proxyOf[id], key) }
            elseif hm == "blank" then
                entries[#entries + 1] = { id = id, blank = true }
            end
        elseif item and not claimedBy[item] then
            local rec = ns.Viewers.frames[item]
            local aura = rec and ns.Viewers.AURA_KIND[rec.barKey]
            local mode = "item"
            if aura then
                -- 不在時照這一格生效的「增益不在時」（逐法術 ＞ 條層；收合／留空位／暗圖示）
                local present = AuraPresent(item)
                local em, own
                if not present then
                    em, own = ns.Layout.SpellEmptyMode(ns.SpellSetting(key, id, "emptyMode"), barMode, forced)
                    -- 暴雪的飾品增益格（EquipSlotTracked：資料帶裝備欄位）跟隨條的暗圖示時只留空位、不畫暗圖示
                    --（被動飾品的增益格平常整格收著，條一被光環格／可點擊逼成固定格位就冒出一顆暗的飾品圖示；
                    -- 玩家 2026-10-05 回報）。逐法術自己選了暗圖示的照舊畫
                    if em == "dim" and not own then
                        local inf = ns.Catalog.Info(id)
                        if inf and type(inf.equipSlot) == "number" then em = "blank" end
                    end
                end
                mode = ns.Layout.AuraSlot(present, em)
            end
            if mode == "item" then
                entries[#entries + 1] = { id = id, item = item, rec = rec }
            elseif mode == "placeholder" then
                entries[#entries + 1] = { id = id, item = item, rec = rec, placeholder = true }
            elseif mode == "blank" then
                entries[#entries + 1] = { id = id, blank = true }
            end
            -- 收合的增益：不認領 ⇒ 最後的停放掃描會把它收走（留空位的也不認領：item 要停放）
            if mode and mode ~= "blank" then claimedBy[item] = key end
        end
    end

    EndHideWatch(key, hw)
    if (st.ringSkipped or 0) ~= ringSkipped then
        if ringSkipped > 0 and ns.Diag then
            ns.Diag.Note("ring", ("%s：圓環條只收增益，跳過 %d 筆（技能冷卻、自訂法術／物品）"):format(key, ringSkipped))
        end
        st.ringSkipped = ringSkipped
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
        ns.Write(c, function(f) f:SetSize(cw, ch); PixelRefix(key) end, "size")
    end
    st.count = #entries

    -- item 放進格子。容器的 alpha 在這裡套（Vis.Refresh），item 的在放格時各自套
    local alpha = VisRefresh(key, s)
    local phUsed, barUsed = 0, 0
    for i, e in ipairs(entries) do
        local r = rects[i]
        local item, rec = e.item, e.rec
        if e.blank then
            -- 收掉、留空格（固定格位）：什麼都不放。原本放在這裡的自訂框沒被 Place ⇒ 下面的 Custom.EndBar 收起來
        elseif e.crec and flowRecs and e.crec.kind == "aura" then
            -- 引擎補位：記帳（音效、探針照做），持有框收起來；位置交給 Custom.PlaceFlow（下面，一條一次）
            ns.Custom.Place(e.crec, c, r, key, gen, true)
            flowRecs[#flowRecs + 1] = { rec = e.crec, r = r }
        elseif e.crec then
            -- 回 true ＝ 換了框／換了條／從收起來放回來（法術索引記的是框與條）
            if ns.Custom.Place(e.crec, c, r, key, gen) then B.claimsChanged = true end
        elseif e.placeholder and SafeShown(item) then
            -- 增益不在、暴雪卻還顯示著（「未作用時隱藏」沒勾的暗格）：收走，不能蓋在占位上。
            -- 增益回來時 OnActiveStateChanged 會再排一次，那時才放進格子。
            -- 不記 slotOf：暴雪格線重排後的同步放回（Reapply）沒格子 ⇒ 照樣收著。
            -- （暴雪自己藏著的 item 照舊走下面那條預先放進格子：一出現就在原位）
            Park(item, rec)
        else
            ns.Viewers.EnsureScale(item, rec, key)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)
            item:SetSize(r.w, r.h)
            if rec then
                rec.parked = false
                rec.claimGen = gen
                rec.claimKey = key
                rec.replacing = e.replaces       -- 以增益取代：這顆 B 現在頂著 A 的格（按鍵文字不畫、/mcdm debug 標記）
                -- 圓環條：整個 rect 交過去（ring ＝ 第幾圈、tex ＝ 第幾張環形貼圖）
                ns.Decorate.Apply(item, rec, key, r.w, r.h, ring and r or nil)
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
        -- 占位格只有「暗圖示」會來（留空位是 e.blank）：長條類畫空長條
        if e.placeholder and bar.kind == "bars" then
            barUsed = barUsed + 1
            local f = BarPlaceholder(key, barUsed)
            local info = ns.Catalog.Info(e.id)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)
            f:SetSize(r.w, r.h)
            f.Icon.Icon:SetTexture((info and info.icon) or QUESTION)
            ns.Decorate.ApplyPreview(f, key, e.id, r.w, r.h)
            local spellID = info and (info.overrideSpellID or info.spellID)
            local name = type(spellID) == "number" and C_Spell.GetSpellName(spellID) or nil
            -- 跟自訂光環長條的占位同一個樣子（Modules/Custom.lua UpdateBarPlaceholder）：灰圖示、灰名字
            f.Icon.Icon:SetDesaturated(true)
            f.Icon.Icon:SetAlpha(0.35)
            f.Bar.Name:SetText(name or "")
            f.Bar.Name:SetTextColor(0.6, 0.6, 0.6, 1)
            f.Bar.Duration:SetText("")
            f.Icon.Applications:SetText("")
            f.Bar:SetValue(0)
            f:SetAlpha(alpha)
            f:Show()
        elseif e.placeholder then
            phUsed = phUsed + 1
            local f = Placeholder(key, phUsed)
            local info = ns.Catalog.Info(e.id)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", c, "TOPLEFT", r.x, -r.y)
            f:SetSize(r.w, r.h)
            if ring then
                -- 圓環條：只畫這一圈的軌道（暗圖示放在同心圓裡沒意義）
                ns.Decorate.ApplyRingPlaceholder(f.ph, key, r)
            else
                f.tex:SetTexture((info and info.icon) or QUESTION)
                f.tex:SetDesaturated(true)
                f.tex:SetAlpha(0.35)                      -- 只有圖示暗，邊框照真實格的顏色
                ns.Decorate.ApplyPlaceholder(f.ph, key, e.id, r.w, r.h)
            end
            f:Show()
        end
        -- 可點擊：這一格上面蓋 secure 鈕（簽章去重、走 ns.Write；沒有動作的格收起來）
        if clickable then ns.Clickable.Place(key, c, i, r, e) end
    end
    ReleasePlaceholders(key, phUsed + 1, barUsed + 1)
    if ns.Clickable then
        if clickable then ns.Clickable.EndBar(key, #entries) else ns.Clickable.Release(key) end
    end
    -- 引擎補位：一條一顆 AuraContainer（每格一個 group）。條容器的尺寸照「全部都在」算（上面的 Compute），
    -- 光環出現／消失時條本身不動；沒在補位的條，上一輪的補位持有框由 Custom.EndBar 收
    if flowRecs then ns.Custom.PlaceFlow(key, c, flowRecs, ns.Layout.FlowParams(sizing, bar.kind), gen) end
    if ns.Custom then ns.Custom.EndBar(key, gen) end

    -- 認領序列：每格三欄（id、哪一顆框／哪一筆自訂、停放了沒），跟上一輪就地比較。
    -- 法術索引（SpellIndex.Rebuild）讀的就是「這條認領中、沒停放的 item 與它的 cooldownID」＋放好的自訂法術，
    -- 序列沒變 ⇒ 這條對索引的貢獻沒變。只比較，不配置（st.claimSeq 就地改寫）
    if not SeqPut then SeqPut, SeqTrim = ns.Layout.SeqPut, ns.Layout.SeqTrim end
    local seq = st.claimSeq
    if not seq then seq = {}; st.claimSeq = seq end
    local changed, n = false, 0
    for i = 1, #entries do
        local e = entries[i]
        local rec = e.rec
        changed = SeqPut(seq, n + 1, e.id, changed)
        changed = SeqPut(seq, n + 2, e.item or e.crec, changed)
        changed = SeqPut(seq, n + 3, rec and rec.parked and true or false, changed)
        n = n + 3
    end
    changed = SeqTrim(seq, n, changed)
    if changed then B.claimsChanged = true end
end
B.Relayout = Relayout                 -- 測試用

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
        flushing = true
        local ok, err = xpcall(Flush, ns.ReportError)
        flushing = false
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
--
-- 快取（增益檢視器一次 RefreshLayout 有 N 顆 item 就打 2N+2 次，每次都走全部認領＋GroupTargets）：
--   sourceTargets[sourceKey] = { gen = B.flushes, keys }；命中條件 gen == B.flushes。
--   * 認領（claimedBy）只在 Flush 裡改 ⇒ 兩輪 Flush 之間不變；Flush 執行中不寫快取（flushing），
--     下一輪 Flush 開始 gen 就換了。
--   * bars[*].source、groupOf、overrides.replaceWith、目錄（C.info／C.placed）的寫入之後一定跟著 RequestAll
--     （設定頁 Options.ApplyEngine、RestyleAll、換設定檔、CatalogChanged）：RequestAll 把每一條都標髒、
--     並且清掉這張快取（B.InvalidateSources）——就算有一筆漏算的目標，它也已經是髒的，到下一輪 Flush 為止
--     不會被漏排；設定頁另外在寫入當下（0.2 秒合併之前）就清。
--   * 命中時照樣檢查 p.bars[key]（條被刪、換設定檔）。等級不進快取鍵：目標集合跟等級無關，
--     B.Request 本身有「已髒且等級不低於就不寫」。
function B.InvalidateSources()
    for k in pairs(sourceTargets) do sourceTargets[k] = nil end
end

function B.RequestSource(sourceKey, level)
    B.requestSource = B.requestSource + 1
    local p = Profile()
    if not sourceKey or type(p) ~= "table" or type(p.bars) ~= "table" then
        return B.RequestAll(level)
    end
    local hit = sourceTargets[sourceKey]
    if hit and hit.gen == B.flushes then
        B.requestSourceHit = B.requestSourceHit + 1
        for key in pairs(hit.keys) do
            if p.bars[key] then B.Request(key, level) end
        end
        return
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
    if not flushing then sourceTargets[sourceKey] = { gen = B.flushes, keys = targets } end
    for key in pairs(targets) do
        if p.bars[key] then B.Request(key, level) end
    end
end

function B.RequestAll(level)
    B.InvalidateSources()
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
    -- 拖曳中的條這一輪不動，留到下一輪（它的認領沒重算 ⇒ 法術索引照舊每輪重建，跟改之前一樣）
    if ns.dragging and work[ns.dragging] then
        dirty[ns.dragging] = work[ns.dragging]
        work[ns.dragging] = nil
        B.claimsChanged = true
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

    -- 格數上限＋溢出（Core/Overflow.lua）：這一輪的佔位判斷交給 Catalog（溢出結果每輪算一次，見 Catalog.Overflow）。
    -- 來源條要排 ⇒ 接收條也排（溢出去的那幾顆跟著來源條的清單變；認領只放掉這一輪要排的條）
    ns.Catalog.SetOccupancy(B.Occupancy(index), index)
    local ovPairs = ns.Catalog.OverflowPairs and ns.Catalog.OverflowPairs()
    if ovPairs then
        for _, pr in ipairs(ovPairs) do
            if work[pr.src] and pr.dst ~= ns.dragging and (work[pr.dst] or 0) < work[pr.src] then
                work[pr.dst] = work[pr.src]
            end
        end
    end

    -- 這一輪要排的條先放掉舊的認領
    for item, key in pairs(claimedBy) do
        if work[key] then claimedBy[item] = nil end
    end
    for id, slot in pairs(slotOf) do
        if work[slot.key] then slotOf[id] = nil end
    end
    for a, r in pairs(replacedNow) do
        if work[r.key] then replacedNow[a] = nil end
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
    -- 顯示條件的判斷快照：這一輪共用一份（每條的 Vis.Refresh、結尾的面板）
    local snap = ns.Visibility and ns.Visibility.Snapshot and ns.Visibility.Snapshot() or nil
    for _, key in ipairs(order) do
        local ok, err = xpcall(Relayout, ns.ReportError, key, work[key], index, gen, snap)
        if not ok then
            B.lastError = err
            B.claimsChanged = true          -- 排到一半：認領序列沒對完，索引照舊重建
            -- 也可能沒走到 Vis.Refresh：照改之前（結尾 ApplyAll）補套這一條
            if not panels[key] and ns.Visibility and ns.Visibility.Apply then
                xpcall(ns.Visibility.Apply, ns.ReportError, key, snap)
            end
        end
    end

    -- 沒被任何條認領的 item 停到畫面外
    ns.Viewers.EnumerateItems(function(item, rec)
        local key = claimedBy[item]
        if not key or not BarCfg(key) then
            if key then B.claimsChanged = true end     -- 收走了認領中的（條不在了）
            claimedBy[item] = nil
            rec.claimKey = nil
            Park(item, rec)
        end
    end)
    if ns.Custom then ns.Custom.EndFlush() end
    SyncHideEvents()

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

    -- 法術 → 格子的索引（SPELL_UPDATE_COOLDOWN 帶 ID 時只重算那幾格，Core/SpellIndex.lua）。
    -- 認領沒變（B.claimsChanged）而且目錄沒重建／自訂法術的覆寫沒換（SI.dirty）⇒ 索引跟上一輪一模一樣，不重建
    local SI = ns.SpellIndex
    if SI and (B.claimsChanged or SI.dirty) then SI.Rebuild() end
    B.claimsChanged = false
    -- 戰鬥輔助的下一招醒目標示照新的索引重接（格子換了、搬了條、換專精：舊的熄、新的亮）
    if ns.Assist and ns.Assist.Reapply then ns.Assist.Reapply() end

    if not B.ready then
        B.ready = true
        if ns.Fire then ns.Fire("BarsReady") end
    end
    -- 顯示條件：這一輪排過的條在 Relayout 裡已經 Refresh 過容器、放格時每個 item 各自套過，
    -- 這裡只剩面板（資源條／自訂格子讀核心技能剛寫好的 current.essential）。
    -- ⚠ 前提：沒在這一輪 work 裡的條，顯示條件沒變 —— Snapshot 的任何一個輸入（戰鬥、目標、騎乘、副本、
    --   隊伍、飛行騎乘、房屋）變了都走 Visibility 自己的 Later → 完整 ApplyAll；條的顯示／淡出設定變了走設定頁的
    --   ApplyEngine（RequestAll ＋ ApplyAll）；進出編輯模式也是 ApplyAll。所以不必每輪再掃一次所有條的所有 item
    if ns.Visibility and ns.Visibility.ApplyPanels then ns.Visibility.ApplyPanels(snap) end
end

------------------------------------------------------------
-- 同步放回：暴雪的格狀排版剛跑完（每次都會把 item 拉回它自己的格線）
------------------------------------------------------------
function B.Reapply(sourceKey)
    if B.released or not ns.Viewers.ready then return end
    -- alpha 用這條上次套的（Vis.Current）：條件一變 Visibility 自己會重套，這裡在暴雪 Layout 的同步堆疊上，
    -- 不再每顆 item 建一次 Snapshot。還沒套過（nil）才現算，Snapshot 整輪只建一次
    local V = ns.Visibility
    local snap
    ns.Viewers.EnumerateItems(function(item, rec)
        local id = rec.cooldownID
        local slot = id ~= nil and slotOf[id]
        local c = slot and containers[slot.key]
        if c then
            -- 這個 id 上次排在哪就放回哪（暴雪整條重取出時可能換了一顆框，完整重排馬上會來）
            B.reapplyItems = B.reapplyItems + 1
            ns.Viewers.EnsureScale(item, rec, slot.key)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", c, "TOPLEFT", slot.x, -slot.y)
            item:SetSize(slot.w, slot.h)
            local alpha = V and V.Current and V.Current(slot.key)
            if alpha == nil then
                if V and V.Alpha then
                    snap = snap or (V.Snapshot and V.Snapshot()) or nil
                    alpha = V.Alpha(slot.key, snap)
                else
                    alpha = 1
                end
            end
            ns.Decorate.ApplyItemAlpha(item, rec, alpha)
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
    B.InvalidateSources()
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
        -- 圓環：swipe 貼圖、reverse、圖示、軌道還原（Core/Decorate.lua 的 RestoreRing）
        if rec.ring and ns.Decorate and ns.Decorate.RestoreRing then pcall(ns.Decorate.RestoreRing, item, rec) end
        local alert = item.SpellActivationAlert
        if alert and alert.SetAlpha then pcall(alert.SetAlpha, alert, 1) end
        pcall(item.SetAlpha, item, 1)
        pcall(item.ClearAllPoints, item)
        if rec.origW and rec.origH then pcall(item.SetSize, item, rec.origW, rec.origH) end
    end
    for id in pairs(slotOf) do slotOf[id] = nil end
    for a in pairs(replacedNow) do replacedNow[a] = nil end
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

-- 以增益取代：A 那一格現在放的是不是 B（是的話回 B 的 cooldownID；/mcdm debug 用）
function B.ReplacedBy(a)
    local r = a ~= nil and replacedNow[a]
    return r and r.b or nil
end

-- 圓環條這一輪跳過幾筆自訂項目（/mcdm debug）
function B.RingSkipped(key)
    local st = state[key]
    return st and st.ringSkipped or 0
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
    -- 重貼放在同一筆寫入裡：戰鬥中記帳的話，脫戰時先換尺寸再對齊
    ns.Write(c, function(f) f:SetSize(w, fh); PixelRefix(key) end, "size")
    if (st.collapsed or false) ~= collapsed then
        st.collapsed = collapsed
        -- 錨定的 y 偏移跟著收／放：結構級（戰鬥中記帳到脫戰）
        if InCombatLockdown() then structurePending[key] = true; ArmStructurePending() else ApplyStructure(key) end
    end
end

-- 這個 id 在這條上是不是「清單有、暴雪沒給框」（畫不出來）。代畫中的不算（B.IsProxied）
function B.IsMissing(key, id)
    local m = missing[key]
    return m ~= nil and m[id] == true
end

-- 這個 id 在這條上是不是暴雪沒給框、由我們代畫（回裝備欄位；不是 ⇒ nil）
function B.IsProxied(key, id)
    local m = proxied[key]
    return m and m[id] or nil
end

-- 每條的代畫現況（/mcdm debug）：{ [條] = { [id] = 裝備欄位 } }，呼叫端只讀
function B.Proxied() return proxied end

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
    for a in pairs(replacedNow) do replacedNow[a] = nil end
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
