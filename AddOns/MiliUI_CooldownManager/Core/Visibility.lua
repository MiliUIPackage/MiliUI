------------------------------------------------------------
-- 顯示條件與淡出：一律 SetAlpha，不 Hide
--
--   ns.Visibility.Alpha(key)    這條現在該是多少透明度（0 ＝ 條件不成立）
--   ns.Visibility.Apply(key)    統一出口：容器與這條認領中的每個 item 一起套
--   ns.Visibility.ApplyAll()
--
-- 模型（照單位框架的「時機 OR、限制優先」，bars[key].visibility）
--   時機  showCombat／showTarget：都沒勾 ＝ 一直顯示；勾了任一個 ＝ 任一成立才顯示
--   限制  hideMounted（騎乘或坐載具）、onlyInstances（不在副本）、group（solo／party／raid
--         不符）——任一成立就不顯示，蓋過時機
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
--   編輯模式中一律全亮（同條）。面板的框都是容器的子框，容器的 alpha 就管得到。
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
    if vis.onlyInstances and not s.instance then return 0 end
    if not GroupOK(vis.group, s.group) then return 0 end
    -- 時機 OR
    if vis.showCombat or vis.showTarget then
        local ok = (vis.showCombat and s.combat) or (vis.showTarget and s.target)
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

local function Snapshot()
    return {
        combat   = inCombat,
        target   = HasTarget(),
        mounted  = Mounted(),
        instance = InInstance(),
        group    = GroupState(),
    }
end

-- /mcdm debug：顯示條件用的判斷快照（alpha 全是 0 時第一個要看的東西）
function Vis.DebugLine()
    local s = Snapshot()
    return ("  顯示條件快照：戰鬥 %s  目標 %s  騎乘 %s  副本 %s  隊伍 %s"):format(
        tostring(s.combat), tostring(s.target), tostring(s.mounted), tostring(s.instance), tostring(s.group))
end

function Vis.Alpha(key)
    local bar = Bar(key)
    if not bar then return 0 end
    -- 編輯模式裡每條都全亮：玩家是來擺位置的，條件不成立（沒目標、騎乘中）的條也要看得到
    if ns.EditMode and ns.EditMode.active then return 1 end
    local fade = ns.Setting(key, "fade")
    return Vis.Evaluate(bar.visibility, fade, Snapshot())
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
    end
    return 1
end

function Vis.PanelAlpha(key)
    local cfg = ns.DB.ConfigTable(key)
    if not cfg or cfg.enabled == false then return 0 end
    if ns.EditMode and ns.EditMode.active then return 1 end
    local ess = 1
    if (key == "resources" or key == "pips") and cfg.fadeWithEssential ~= false then ess = Vis.Alpha("essential") end
    local casting = ns.Castbar and ns.Castbar.IsActive and ns.Castbar.IsActive() or false
    local suggestion = key == "assistIcon" and ns.Assist and ns.Assist.Current and ns.Assist.Current() or nil
    return Vis.EvaluatePanel(key, cfg, Snapshot(), ess, casting, suggestion)
end

function Vis.Apply(key)
    if ns.DB.IsPanel(key) then
        local alpha = Vis.PanelAlpha(key)
        current[key] = alpha
        local c = ns.Bars and ns.Bars.Get(key)
        if c then c:SetAlpha(alpha) end
        return
    end
    local alpha = Vis.Alpha(key)
    current[key] = alpha
    local c = ns.Bars and ns.Bars.Get(key)
    if c then c:SetAlpha(alpha) end
    if ns.Bars and ns.Bars.ForEachClaimed then
        -- 每個 item：條的 alpha × 冷卻狀態（Decorate.ApplyItemAlpha 是唯一出口）
        local D = ns.Decorate
        ns.Bars.ForEachClaimed(key, function(item, rec)
            if D and D.ApplyItemAlpha then D.ApplyItemAlpha(item, rec, alpha) else item:SetAlpha(alpha) end
        end)
    end
end

function Vis.ApplyAll()
    local p = ns.profile
    if not (p and type(p.bars) == "table") then return end
    for key in pairs(p.bars) do
        local ok, err = xpcall(Vis.Apply, ns.ReportError, key)
        if not ok then Vis.lastError = err end
    end
    -- 面板排在條後面：資源條、自訂格子要讀核心技能剛算好的 alpha
    for _, key in ipairs(ns.DB.PANEL_ORDER) do
        local ok, err = xpcall(Vis.Apply, ns.ReportError, key)
        if not ok then Vis.lastError = err end
    end
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
    E.Register("UNIT_ENTERED_VEHICLE", "visibility", Later, "player")
    E.Register("UNIT_EXITED_VEHICLE", "visibility", Later, "player")
    Vis.ApplyAll()
end
