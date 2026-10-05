------------------------------------------------------------
-- 顯示條件與淡出：一律 SetAlpha，不 Hide
--
--   ns.Visibility.Alpha(key, s)       這條現在該是多少透明度（0 ＝ 條件不成立）；s ＝ Snapshot()，可省
--   ns.Visibility.Refresh(key, s)     只套容器（寫 current、容器 SetAlpha、跟著游標的開關），不跑 item；回傳 alpha
--   ns.Visibility.Apply(key, s)       統一出口：Refresh ＋ 這條認領中的每個 item
--   ns.Visibility.ApplyAll(s)         全部條＋面板（Snapshot 只建一次）
--   ns.Visibility.ApplyPanels(s)      只套面板（Bars.Flush 結尾：條在 Relayout 裡已經 Refresh 過）
--   ns.Visibility.Current(key)        上次套的 alpha（還沒套過回 nil）
--
-- Snapshot（約 12 支 C API＋一張新表）一輪只建一次往下傳：s 沒給才自己建。
--
-- 模型（照單位框架的「時機 OR、限制優先」，bars[key].visibility）
--   時機  showCombat／showTarget／showEnemy（有目標而且能攻擊它）：都沒勾 ＝ 一直顯示；
--         勾了任一個 ＝ 任一成立才顯示
--   限制  hideMounted（騎乘或坐載具）、hideSkyriding（騎著能飛行騎乘的坐騎，地面上也算）、
--         hideHousing（在房屋或房屋地塊裡）、hideResting（休息中：旅館／主城）、hideVehicle（只看載具，
--         騎馬不算——跟 hideMounted 不同）、onlyInstances（不在副本）、group（solo／party／raid
--         不符）——任一成立就不顯示，蓋過時機
--   三個 2026-10-03 加的欄位（showEnemy／hideSkyriding／hideHousing）與兩個 2026-10-04 加的
--  （hideResting／hideVehicle）舊存檔沒有 ＝ false，不遷移。
--   判斷：敵對 ＝ UnitCanAttack("player", "target")，秘密值當成立（寧可多顯示）；
--         飛行騎乘 ＝ C_PlayerInfo.GetGlidingInfo() 第二個回傳 canGlide，明文 true 才算；
--         房屋 ＝ C_Housing.IsInsideHouseOrPlot()，明文 true 才算；
--         休息中 ＝ IsResting()；載具 ＝ UnitHasVehicleUI("player") 或 UnitInVehicle("player")；
--         兩者都是明文 true 才算。API 不在／pcall 失敗 ＝ false
--   顯示時再套淡出（fade：enabled／alpha；keepInCombat／keepWithTarget 任一成立不淡；whenMounted 一律淡），
--   同時成立取最低
--
-- 為什麼不用 secure 狀態驅動：容器不是 secure 框，而且暴雪的 item 不是容器的子框
-- （它們的 parent 仍是暴雪檢視器，我們不 SetParent），容器的 alpha 管不到它們 ——
-- 所以每個認領中的 item 也要各自 SetAlpha（走 Decorate.ApplyItemAlpha：冷卻狀態效果疊在條的 alpha 上，相乘）。
--
-- 面板（資源條、自訂格子、施法條、下一招圖示）不走上面的模型，各自一條（Vis.PanelAlpha）：
--   資源條  enabled ＝ false → 0；載入條件 loadConditions（騎乘或坐載具／只在戰鬥中）任一不符 → 0；
--           fadeWithEssential 開著時取核心技能條現在的 alpha（它的顯示條件與淡出一起帶過來）
--   自訂格子  enabled ＝ false → 0；載入條件與 fadeWithEssential 同資源條，但讀的是 profile.pips
--             自己的那一份（資源條的不帶過來）
--   施法條  enabled ＝ false → 0；hideWhenNotCasting 且沒在施法（ns.Castbar.IsActive）→ 0
--   下一招圖示  enabled ＝ false → 0；onlyCombat 且不在戰鬥 → 0；戰鬥輔助沒有建議（ns.Assist.Current）→ 0
--   天空騎術  enabled ＝ false → 0；Snapshot.skyridingPanel（ns.Skyriding.Shown ＝ 上次 Active 的結果：在天空騎術、不在德比賽跑、
--             沒有「地面上而且充能全滿」…，見 Modules/Skyriding.lua）→ 1，否則 0
--   編輯模式中一律全亮（同條）。面板的框都是容器的子框，容器的 alpha 就管得到。
--   例外：舊的獨立天空騎術插件這次登入還載著（ns.falconBlocked）時，天空騎術面板編輯模式中也是 0。
--
-- 天空騎術的「藏起冷卻管理器」（profile.skyriding.hideCdm）：面板顯示中（Snapshot.skyridingHideCdm）時，
-- 每一條（Vis.Alpha）與天空騎術以外的每個面板（PanelAlpha）都是 0。加在既有的限制前面，不寫進每條的
-- visibility 表、不改存檔；編輯模式中不套用（編輯模式的全亮在它前面判斷）。
--
-- 事件處理器只標髒、下一幀套（PLAYER_TARGET_CHANGED 會在按 Tab 的 secure 流程裡同步派送，
-- 見 wow-121-addon-code-in-secure-stack）。脫戰多等 0.1 秒：戰鬥結束那一瞬間常常緊跟著
-- 目標消失、上坐騎，一起算完再變，不要閃兩次。
------------------------------------------------------------
local _, ns = ...

ns.Visibility = {}
local Vis = ns.Visibility

local inCombat = false
local armed = false
local current = {}          -- key → 上次套的 alpha（debug 用）

local function Bar(key)
    local p = ns.profile
    local b = p and type(p.bars) == "table" and p.bars[key]
    return type(b) == "table" and b or nil
end

local function Mounted()
    if IsMounted and IsMounted() then return true end
    if UnitInVehicle and UnitInVehicle("player") then return true end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return true end
    return false
end

local function HasTarget()
    return UnitExists and UnitExists("target") and true or false
end

-- 有目標而且能攻擊它（秘密值當成立：讀不到時寧可顯示）
local function HasEnemyTarget()
    if not HasTarget() then return false end
    if not UnitCanAttack then return false end
    local ok, v = pcall(UnitCanAttack, "player", "target")
    if not ok then return false end
    if ns.IsSecret(v) then return true end
    return v and true or false
end

-- 騎著能飛行騎乘的坐騎（GetGlidingInfo → isGliding, canGlide, forwardSpeed；canGlide 在地面上也是真）
local function Skyriding()
    local P = C_PlayerInfo
    local fn = P and P.GetGlidingInfo
    if not fn then return false end
    local ok, _, canGlide = pcall(fn)
    if not ok or ns.IsSecret(canGlide) then return false end
    return canGlide == true
end

-- 在房屋或房屋地塊裡
local function InHousing()
    local H = C_Housing
    local fn = H and H.IsInsideHouseOrPlot
    if not fn then return false end
    local ok, v = pcall(fn)
    if not ok or ns.IsSecret(v) then return false end
    return v == true
end

-- 一支「回傳明文 true 才算」的 API 呼叫（秘密／拋錯／API 不在 ＝ false）
local function PlainTrue(fn, ...)
    if not fn then return false end
    local ok, v = pcall(fn, ...)
    if not ok or ns.IsSecret(v) then return false end
    return v == true
end

-- 休息中（旅館／主城）
local function Resting()
    return PlainTrue(IsResting)
end

-- 坐載具（只看載具，騎馬不算；「騎乘時隱藏」的 Mounted() 兩者都算）
local function InVehicle()
    return PlainTrue(UnitHasVehicleUI, "player") or PlainTrue(UnitInVehicle, "player")
end

local function InInstance()
    if not IsInInstance then return false end
    local inside, kind = IsInInstance()
    return inside and kind ~= "none" and true or false
end

local function GroupState()
    if IsInRaid and IsInRaid() then return "raid" end
    if IsInGroup and IsInGroup() then return "party" end
    return "solo"
end

-- rule：any | solo | party | raid；state：solo | party | raid
local function GroupOK(rule, state)
    if rule == nil or rule == "any" then return true end
    return rule == state
end
Vis.GroupOK = GroupOK

-- 條件本身（純邏輯，狀態由呼叫端給；離線也能驗）
function Vis.Evaluate(vis, fade, s)
    vis = type(vis) == "table" and vis or {}
    -- 限制優先
    if vis.hideMounted and s.mounted then return 0 end
    if vis.hideSkyriding and s.skyriding then return 0 end
    if vis.hideHousing and s.housing then return 0 end
    if vis.hideResting and s.resting then return 0 end
    if vis.hideVehicle and s.vehicle then return 0 end
    if vis.onlyInstances and not s.instance then return 0 end
    if not GroupOK(vis.group, s.group) then return 0 end
    -- 時機 OR
    if vis.showCombat or vis.showTarget or vis.showEnemy then
        local ok = (vis.showCombat and s.combat) or (vis.showTarget and s.target) or (vis.showEnemy and s.enemy)
        if not ok then return 0 end
    end
    -- 淡出：一個透明度。「不淡出的時機」（戰鬥中／有目標）任一成立就完整顯示；
    -- 騎乘勾了就不看時機一律淡；都沒勾＝只要啟用就一直淡
    fade = type(fade) == "table" and fade or {}
    if not fade.enabled then return 1 end
    local a = tonumber(fade.alpha)
    if not a then return 1 end
    if a < 0 then a = 0 elseif a > 1 then a = 1 end
    if fade.whenMounted and s.mounted then return a end
    if (fade.keepInCombat and s.combat) or (fade.keepWithTarget and s.target) then return 1 end
    return a
end

Vis.snapshots = 0          -- /mcdm perf：Snapshot 建了幾次
local function Snapshot()
    Vis.snapshots = Vis.snapshots + 1
    local SR = ns.Skyriding
    local sky = SR and SR.Shown and SR.Shown() or false     -- 上次判斷的結果，不重讀 API
    return {
        combat   = inCombat,
        target   = HasTarget(),
        mounted  = Mounted(),
        instance = InInstance(),
        group    = GroupState(),
        enemy    = HasEnemyTarget(),
        skyriding = Skyriding(),
        housing  = InHousing(),
        resting  = Resting(),
        vehicle  = InVehicle(),
        skyridingPanel = sky,
        skyridingHideCdm = SR and SR.HidesCdm and SR.HidesCdm(sky) or false,
    }
end
Vis.Snapshot = Snapshot

-- /mcdm debug：顯示條件用的判斷快照（alpha 全是 0 時第一個要看的東西）
function Vis.DebugLine()
    local s = Snapshot()
    return ("  顯示條件快照：戰鬥 %s  目標 %s  敵對目標 %s  騎乘 %s  飛行騎乘 %s  房屋 %s  休息中 %s  載具 %s  副本 %s  隊伍 %s"):format(
        tostring(s.combat), tostring(s.target), tostring(s.enemy), tostring(s.mounted), tostring(s.skyriding),
        tostring(s.housing), tostring(s.resting), tostring(s.vehicle), tostring(s.instance), tostring(s.group))
end

-- s：Snapshot() 的形狀（同一輪排版／套用共用一份）；沒給才自己建
function Vis.Alpha(key, s)
    local bar = Bar(key)
    if not bar then return 0 end
    -- 編輯模式裡每條都全亮：玩家是來擺位置的，條件不成立（沒目標、騎乘中）的條也要看得到
    if ns.EditMode and ns.EditMode.active then return 1 end
    s = s or Snapshot()
    -- 天空騎術面板顯示中、藏起冷卻管理器：蓋過一切（不寫進 visibility 表）
    if s.skyridingHideCdm then return 0 end
    local fade = ns.Setting(key, "fade")
    return Vis.Evaluate(bar.visibility, fade, s)
end

-- 面板的 alpha（純邏輯；s 是 Snapshot 的形狀，essentialAlpha／casting／suggestion 由呼叫端給）
-- suggestion：戰鬥輔助目前建議的法術（明文 spellID 或 nil），只有下一招圖示看
function Vis.EvaluatePanel(key, cfg, s, essentialAlpha, casting, suggestion)
    if type(cfg) ~= "table" or cfg.enabled == false then return 0 end
    if key == "resources" then
        local lc = type(cfg.loadConditions) == "table" and cfg.loadConditions or {}
        if lc.hideMounted and s.mounted then return 0 end
        if lc.onlyCombat and not s.combat then return 0 end
        if cfg.fadeWithEssential ~= false then
            local a = tonumber(essentialAlpha) or 1
            if a < 0 then a = 0 elseif a > 1 then a = 1 end
            return a
        end
        return 1
    elseif key == "pips" then
        -- 載入條件是自訂格子自己的那一份（profile.pips.loadConditions），資源條的不帶過來
        local lc = type(cfg.loadConditions) == "table" and cfg.loadConditions or {}
        if lc.hideMounted and s.mounted then return 0 end
        if lc.onlyCombat and not s.combat then return 0 end
        if cfg.fadeWithEssential ~= false then
            local a = tonumber(essentialAlpha) or 1
            if a < 0 then a = 0 elseif a > 1 then a = 1 end
            return a
        end
        return 1
    elseif key == "castbar" then
        if cfg.hideWhenNotCasting ~= false and not casting then return 0 end
        return 1
    elseif key == "assistIcon" then
        -- onlyCombat 沒存（nil）照預設當開
        if cfg.onlyCombat ~= false and not s.combat then return 0 end
        if suggestion == nil then return 0 end
        return 1
    elseif key == "skyriding" then
        return s.skyridingPanel and 1 or 0
    end
    return 1
end

-- s：同 Vis.Alpha。essAlpha：核心技能條的 alpha（資源條／自訂格子的 fadeWithEssential 用）；
-- 沒給就用核心技能上次套的（current.essential：條件一變就會走 Later → ApplyAll 重套，所以它就是現況），
-- 還沒套過才現算
function Vis.PanelAlpha(key, s, essAlpha)
    local cfg = ns.DB.ConfigTable(key)
    if not cfg or cfg.enabled == false then return 0 end
    -- 舊的獨立插件還載著：這次登入的天空騎術面板不啟動（編輯模式也不亮，免得兩條疊在一起）
    if key == "skyriding" and ns.falconBlocked then return 0 end
    if ns.EditMode and ns.EditMode.active then return 1 end
    s = s or Snapshot()
    if key ~= "skyriding" and s.skyridingHideCdm then return 0 end
    local ess = 1
    if (key == "resources" or key == "pips") and cfg.fadeWithEssential ~= false then
        ess = essAlpha or current.essential
        if ess == nil then ess = Vis.Alpha("essential", s) end
    end
    local casting = ns.Castbar and ns.Castbar.IsActive and ns.Castbar.IsActive() or false
    local suggestion = key == "assistIcon" and ns.Assist and ns.Assist.Current and ns.Assist.Current() or nil
    return Vis.EvaluatePanel(key, cfg, s, ess, casting, suggestion)
end

-- 只套容器：算 alpha、寫 current、容器 SetAlpha、（條）跟著游標的開關。**不跑 item 迴圈**
--（Bars.Relayout 用：那一輪放格時每個 item 已經各自 ApplyItemAlpha 過）。回傳 alpha
function Vis.Refresh(key, s)
    if ns.DB.IsPanel(key) then
        local alpha = Vis.PanelAlpha(key, s)
        current[key] = alpha
        local c = ns.Bars and ns.Bars.Get(key)
        if c then c:SetAlpha(alpha) end
        return alpha
    end
    local alpha = Vis.Alpha(key, s)
    current[key] = alpha
    local c = ns.Bars and ns.Bars.Get(key)
    if c then c:SetAlpha(alpha) end
    -- 跟著游標的條：看不到（alpha 0）時卸掉 OnUpdate、看得到再掛（Core/Cursor.lua；其他條立刻走）
    if ns.Cursor and ns.Cursor.OnAlpha then ns.Cursor.OnAlpha(key) end
    return alpha
end

function Vis.Apply(key, s)
    local alpha = Vis.Refresh(key, s)
    if ns.DB.IsPanel(key) then return end
    if ns.Bars and ns.Bars.ForEachClaimed then
        -- 每個 item：條的 alpha × 冷卻狀態（Decorate.ApplyItemAlpha 是唯一出口）
        local D = ns.Decorate
        ns.Bars.ForEachClaimed(key, function(item, rec)
            if D and D.ApplyItemAlpha then D.ApplyItemAlpha(item, rec, alpha) else item:SetAlpha(alpha) end
        end)
    end
end

-- 面板排在條後面：資源條、自訂格子讀核心技能剛算好的 alpha（current.essential）
function Vis.ApplyPanels(s)
    s = s or Snapshot()
    for _, key in ipairs(ns.DB.PANEL_ORDER) do
        local ok, err = xpcall(Vis.Apply, ns.ReportError, key, s)
        if not ok then Vis.lastError = err end
    end
end

function Vis.ApplyAll(s)
    local p = ns.profile
    if not (p and type(p.bars) == "table") then return end
    s = s or Snapshot()
    for key in pairs(p.bars) do
        local ok, err = xpcall(Vis.Apply, ns.ReportError, key, s)
        if not ok then Vis.lastError = err end
    end
    Vis.ApplyPanels(s)
end

function Vis.Current(key) return current[key] end

local function Later()
    if armed then return end
    armed = true
    ns.Defer(function()
        armed = false
        Vis.ApplyAll()
    end)
end
Vis.Later = Later

-- 這個客戶端認不認得這個事件名（RegisterEvent 對不認得的名字會拋錯）。查不到 API 就當認得，
-- 交給 ns.Events 的 pcall 接住
function Vis.EventExists(ev)
    local U = C_EventUtils
    if U and U.IsEventValid then
        local ok, v = pcall(U.IsEventValid, ev)
        if ok and not ns.IsSecret(v) then return v and true or false end
    end
    return true
end

local initialized = false
function Vis.Init()
    if initialized then return end
    initialized = true
    inCombat = InCombatLockdown() and true or false
    local E = ns.Events
    E.Register("PLAYER_REGEN_DISABLED", "visibility", function()
        inCombat = true
        Later()
    end)
    E.Register("PLAYER_REGEN_ENABLED", "visibility", function()
        -- 脫戰緩衝：0.1 秒後才算（期間又進戰鬥就作廢）
        C_Timer.After(0.1, function()
            if InCombatLockdown() then return end
            inCombat = false
            Later()
        end)
    end)
    E.Register("PLAYER_TARGET_CHANGED", "visibility", Later)
    E.Register("PLAYER_MOUNT_DISPLAY_CHANGED", "visibility", Later)
    E.Register("ZONE_CHANGED_NEW_AREA", "visibility", Later)
    E.Register("PLAYER_ENTERING_WORLD", "visibility", Later)
    E.Register("GROUP_ROSTER_UPDATE", "visibility", Later)
    -- 進出休息區（旅館／主城）
    E.Register("PLAYER_UPDATE_RESTING", "visibility", Later)
    E.Register("UNIT_ENTERED_VEHICLE", "visibility", Later, "player")
    E.Register("UNIT_EXITED_VEHICLE", "visibility", Later, "player")
    -- 目標的敵我關係變了（中立怪被打成敵對、決鬥開始）
    E.Register("UNIT_FACTION", "visibility", Later, "target")
    -- 飛行騎乘與房屋：客戶端有這個事件才註冊（舊版本沒有）；房屋查不到事件時靠上面的
    -- PLAYER_ENTERING_WORLD／ZONE_CHANGED_NEW_AREA 重判
    for _, ev in ipairs({ "PLAYER_CAN_GLIDE_CHANGED", "HOUSE_PLOT_ENTERED", "HOUSE_PLOT_EXITED" }) do
        if Vis.EventExists(ev) then E.Register(ev, "visibility", Later) end
    end
    Vis.ApplyAll()
end
