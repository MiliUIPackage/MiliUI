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
--   顯示時再套淡出（fade：outOfCombat／noTarget／mounted 各自的透明度，false ＝ 不淡），
--   同時成立取最低
--
-- 為什麼不用 secure 狀態驅動：容器不是 secure 框，而且暴雪的 item 不是容器的子框
-- （它們的 parent 仍是暴雪檢視器，我們不 SetParent），容器的 alpha 管不到它們 ——
-- 所以每個認領中的 item 也要各自 SetAlpha。
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
    -- 淡出：同時成立取最低
    local alpha = 1
    fade = type(fade) == "table" and fade or {}
    local function Take(v)
        v = tonumber(v)
        if v and v < alpha then alpha = v < 0 and 0 or v end
    end
    if fade.outOfCombat ~= false and fade.outOfCombat ~= nil and not s.combat then Take(fade.outOfCombat) end
    if fade.noTarget ~= false and fade.noTarget ~= nil and not s.target then Take(fade.noTarget) end
    if fade.mounted ~= false and fade.mounted ~= nil and s.mounted then Take(fade.mounted) end
    return alpha
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

function Vis.Alpha(key)
    local bar = Bar(key)
    if not bar then return 0 end
    local fade = ns.Setting(key, "fade")
    return Vis.Evaluate(bar.visibility, fade, Snapshot())
end

function Vis.Apply(key)
    local alpha = Vis.Alpha(key)
    current[key] = alpha
    local c = ns.Bars and ns.Bars.Get(key)
    if c then c:SetAlpha(alpha) end
    if ns.Bars and ns.Bars.ForEachClaimed then
        ns.Bars.ForEachClaimed(key, function(item) item:SetAlpha(alpha) end)
    end
end

function Vis.ApplyAll()
    local p = ns.profile
    if not (p and type(p.bars) == "table") then return end
    for key in pairs(p.bars) do
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
