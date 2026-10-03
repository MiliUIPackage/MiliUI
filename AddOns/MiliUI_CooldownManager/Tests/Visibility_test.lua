------------------------------------------------------------
-- Core/Visibility.lua 的條顯示條件（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Visibility_test.lua
--
-- 覆蓋：
--   1. Vis.Evaluate：既有的時機（戰鬥／目標）與限制（騎乘、副本、隊伍）、淡出；
--      2026-10-03 補的三個欄位——showEnemy（時機，跟另外兩個 OR）、hideSkyriding／hideHousing
--      （限制，蓋過時機）——每一個的成立／不成立、跟時機的組合；舊存檔沒有這三欄 ＝ 行為不變
--   2. Snapshot 的三個新判斷：敵對目標（秘密值當成立、沒目標不算、API 不在／拋錯不算）、
--      飛行騎乘（GetGlidingInfo 第二個回傳、明文 true 才算、秘密不算、API 不在不算）、
--      房屋（IsInsideHouseOrPlot、明文 true 才算）
--   3. 事件：PLAYER_CAN_GLIDE_CHANGED／HOUSE_PLOT_ENTERED／HOUSE_PLOT_EXITED 只在客戶端認得時註冊、
--      UNIT_FACTION 只看 target；DebugLine 印三個新欄位
--   4. 效能（2026-10-04 E1）：Alpha／PanelAlpha 給 s 就不建 Snapshot、Refresh 不跑 item、
--      ApplyPanels 讀 current.essential、ApplyAll 一輪只建一次 Snapshot
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Core/Visibility.lua"

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

------------------------------------------------------------
-- 環境
------------------------------------------------------------
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local env = setmetatable({}, { __index = _G })
env._G = env
local hasTarget, canAttack = false, false
local gliding = nil          -- nil ＝ API 不在；否則 { isGliding, canGlide }
local housing = nil          -- nil ＝ API 不在；否則回傳值（可以是 "error"）
local validEvents = nil      -- nil ＝ C_EventUtils 不在；否則 { [事件] = true }
env.UnitExists = function(u) return u == "target" and hasTarget end
env.UnitCanAttack = function(a, b)
    assert(a == "player" and b == "target", "要問 player 對 target")
    if canAttack == "error" then error("boom") end
    return canAttack
end
env.IsMounted = function() return false end
env.UnitInVehicle = function() return false end
env.UnitHasVehicleUI = function() return false end
env.IsInInstance = function() return false, "none" end
env.IsInRaid = function() return false end
env.IsInGroup = function() return false end
env.InCombatLockdown = function() return false end
env.C_Timer = { After = function(_, fn) fn() end }
local function Install()
    if gliding == nil then
        env.C_PlayerInfo = nil
    else
        env.C_PlayerInfo = { GetGlidingInfo = function()
            if gliding == "error" then error("boom") end
            return gliding[1], gliding[2], 65
        end }
    end
    if housing == nil then
        env.C_Housing = nil
    else
        env.C_Housing = { IsInsideHouseOrPlot = function()
            if housing == "error" then error("boom") end
            return housing
        end }
    end
    if validEvents == nil then
        env.C_EventUtils = nil
    else
        env.C_EventUtils = { IsEventValid = function(ev) return validEvents[ev] == true end }
    end
end
Install()

local registered = {}        -- event → unit 或 true
local ns = {
    IsSecret = function(v) return v == SECRET end,
    Events = { Register = function(ev, _, _, unit) registered[ev] = unit or true end },
    Defer = function(fn) fn() end,
    DB = { PANEL_ORDER = {}, IsPanel = function() return false end, ConfigTable = function() return nil end },
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
}

local chunk, err
if setfenv then
    chunk, err = loadfile(PATH)
    if chunk then setfenv(chunk, env) end
else
    chunk, err = loadfile(PATH, "t", env)
end
assert(chunk, err)
chunk("MiliUI_CooldownManager", ns)
local Vis = ns.Visibility

------------------------------------------------------------
-- 1. Evaluate
------------------------------------------------------------
local function S(t)
    local s = { combat = false, target = false, mounted = false, instance = false, group = "solo",
                enemy = false, skyriding = false, housing = false }
    for k, v in pairs(t or {}) do s[k] = v end
    return s
end
local E = Vis.Evaluate

-- 既有行為（舊存檔：沒有三個新欄位）
eq("沒條件 → 1", E({}, nil, S()), 1)
eq("只在戰鬥中：脫戰 → 0", E({ showCombat = true }, nil, S()), 0)
eq("只在戰鬥中：戰鬥中 → 1", E({ showCombat = true }, nil, S{ combat = true }), 1)
eq("戰鬥或目標：有目標 → 1", E({ showCombat = true, showTarget = true }, nil, S{ target = true }), 1)
eq("騎乘隱藏蓋過時機", E({ hideMounted = true, showCombat = true }, nil, S{ mounted = true, combat = true }), 0)
eq("只在副本：不在 → 0", E({ onlyInstances = true }, nil, S()), 0)
eq("隊伍不符 → 0", E({ group = "raid" }, nil, S()), 0)
eq("淡出：沒目標脫戰 → 透明度", E({}, { enabled = true, alpha = 0.3, keepWithTarget = true }, S()), 0.3)
eq("舊存檔：飛行騎乘中照常顯示", E({ hideMounted = false }, nil, S{ skyriding = true }), 1)
eq("舊存檔：房屋裡照常顯示", E({}, nil, S{ housing = true }), 1)
eq("舊存檔：有敵對目標但只勾戰鬥、脫戰 → 0", E({ showCombat = true }, nil, S{ target = true, enemy = true }), 0)

-- showEnemy（時機）
eq("有敵對目標：沒目標 → 0", E({ showEnemy = true }, nil, S()), 0)
eq("有敵對目標：友方目標 → 0", E({ showEnemy = true }, nil, S{ target = true }), 0)
eq("有敵對目標：敵對 → 1", E({ showEnemy = true }, nil, S{ target = true, enemy = true }), 1)
eq("有敵對目標 OR 戰鬥：戰鬥中、友方目標 → 1", E({ showEnemy = true, showCombat = true }, nil, S{ combat = true, target = true }), 1)
eq("有敵對目標 OR 戰鬥：脫戰、敵對 → 1", E({ showEnemy = true, showCombat = true }, nil, S{ target = true, enemy = true }), 1)
eq("有敵對目標 OR 戰鬥：都不成立 → 0", E({ showEnemy = true, showCombat = true }, nil, S{ target = true }), 0)
eq("有目標 OR 有敵對目標：友方目標 → 1（有目標成立）", E({ showEnemy = true, showTarget = true }, nil, S{ target = true }), 1)
eq("沒勾 showEnemy：敵對目標不影響", E({ showTarget = false, showEnemy = false }, nil, S{ enemy = true, target = true }), 1)
eq("有敵對目標：騎乘隱藏照樣蓋過", E({ showEnemy = true, hideMounted = true }, nil, S{ target = true, enemy = true, mounted = true }), 0)

-- hideSkyriding（限制）
eq("飛行騎乘隱藏：沒在飛行騎乘 → 1", E({ hideSkyriding = true }, nil, S()), 1)
eq("飛行騎乘隱藏：飛行騎乘中 → 0", E({ hideSkyriding = true }, nil, S{ skyriding = true }), 0)
eq("飛行騎乘隱藏：蓋過戰鬥時機", E({ hideSkyriding = true, showCombat = true }, nil, S{ skyriding = true, combat = true }), 0)
eq("飛行騎乘隱藏：蓋過敵對目標", E({ hideSkyriding = true, showEnemy = true }, nil, S{ skyriding = true, target = true, enemy = true }), 0)
eq("飛行騎乘隱藏：只騎一般坐騎不算（那是騎乘隱藏的事）", E({ hideSkyriding = true }, nil, S{ mounted = true }), 1)
eq("飛行騎乘隱藏＋淡出：不成立時照淡出", E({ hideSkyriding = true }, { enabled = true, alpha = 0.5 }, S()), 0.5)

-- hideHousing（限制）
eq("房屋隱藏：不在房屋 → 1", E({ hideHousing = true }, nil, S()), 1)
eq("房屋隱藏：在房屋 → 0", E({ hideHousing = true }, nil, S{ housing = true }), 0)
eq("房屋隱藏：蓋過時機", E({ hideHousing = true, showTarget = true }, nil, S{ housing = true, target = true }), 0)
eq("房屋隱藏：跟只在副本一起（不在副本、不在房屋）→ 0（副本限制）", E({ hideHousing = true, onlyInstances = true }, nil, S()), 0)
eq("房屋隱藏：時機不成立照樣 0", E({ hideHousing = true, showCombat = true }, nil, S()), 0)
eq("房屋隱藏：時機成立、不在房屋 → 1", E({ hideHousing = true, showCombat = true }, nil, S{ combat = true }), 1)

------------------------------------------------------------
-- 2. Snapshot 的三個新判斷
------------------------------------------------------------
local snap = Vis.Snapshot
check("Snapshot 對外", type(snap) == "function")
hasTarget, canAttack = false, true
eq("敵對：沒目標不算（就算 UnitCanAttack 是真）", snap().enemy, false)
hasTarget = true
eq("敵對：可攻擊 → 真", snap().enemy, true)
canAttack = false
eq("敵對：不可攻擊 → 假", snap().enemy, false)
canAttack = SECRET
eq("敵對：秘密值當成立", snap().enemy, true)
canAttack = "error"
eq("敵對：拋錯不算", snap().enemy, false)
canAttack = nil
eq("敵對：nil 不算", snap().enemy, false)
do
    local saved = env.UnitCanAttack
    env.UnitCanAttack = nil
    eq("敵對：API 不在不算", snap().enemy, false)
    env.UnitCanAttack = saved
end
hasTarget = false

gliding = nil; Install()
eq("飛行騎乘：API 不在 ＝ false", snap().skyriding, false)
gliding = { false, true }; Install()
eq("飛行騎乘：第二個回傳 canGlide 真（地面上也算）", snap().skyriding, true)
gliding = { true, false }; Install()
eq("飛行騎乘：看的是第二個回傳，不是第一個", snap().skyriding, false)
gliding = { false, SECRET }; Install()
eq("飛行騎乘：秘密值不算", snap().skyriding, false)
gliding = "error"; Install()
eq("飛行騎乘：拋錯不算", snap().skyriding, false)
gliding = { false, 1 }; Install()
eq("飛行騎乘：不是明文 true 不算", snap().skyriding, false)
gliding = nil

housing = nil; Install()
eq("房屋：API 不在 ＝ false", snap().housing, false)
housing = true; Install()
eq("房屋：在裡面 → 真", snap().housing, true)
housing = false; Install()
eq("房屋：不在 → 假", snap().housing, false)
housing = SECRET; Install()
eq("房屋：秘密值不算", snap().housing, false)
housing = "error"; Install()
eq("房屋：拋錯不算", snap().housing, false)
housing = nil; Install()

------------------------------------------------------------
-- 3. 事件與 debug
------------------------------------------------------------
validEvents = { PLAYER_CAN_GLIDE_CHANGED = true }; Install()
eq("事件存在檢查：認得", Vis.EventExists("PLAYER_CAN_GLIDE_CHANGED"), true)
eq("事件存在檢查：不認得", Vis.EventExists("HOUSE_PLOT_ENTERED"), false)
Vis.Init()
eq("PLAYER_CAN_GLIDE_CHANGED 註冊了", registered.PLAYER_CAN_GLIDE_CHANGED, true)
eq("不認得的 HOUSE_PLOT_ENTERED 不註冊", registered.HOUSE_PLOT_ENTERED, nil)
eq("不認得的 HOUSE_PLOT_EXITED 不註冊", registered.HOUSE_PLOT_EXITED, nil)
eq("UNIT_FACTION 只看 target", registered.UNIT_FACTION, "target")
eq("既有：PLAYER_TARGET_CHANGED", registered.PLAYER_TARGET_CHANGED, true)
eq("既有：ZONE_CHANGED_NEW_AREA（房屋查不到事件時的退路）", registered.ZONE_CHANGED_NEW_AREA, true)
validEvents = nil; Install()
eq("沒有 C_EventUtils ＝ 當認得（交給 ns.Events 的 pcall）", Vis.EventExists("HOUSE_PLOT_ENTERED"), true)
do
    local line = Vis.DebugLine()
    check("DebugLine 印敵對目標", line:find("敵對目標", 1, true) ~= nil, line)
    check("DebugLine 印飛行騎乘", line:find("飛行騎乘", 1, true) ~= nil, line)
    check("DebugLine 印房屋", line:find("房屋", 1, true) ~= nil, line)
end

------------------------------------------------------------
-- 4. 效能 #1／#7：Snapshot 一輪只建一次、Refresh 不跑 item、面板讀 current.essential
------------------------------------------------------------
do
    hasTarget, canAttack, gliding, housing = false, false, nil, nil
    Install()
    local containerAlpha, itemCalls, cursorCalls = {}, 0, 0
    local function Container(key)
        return { SetAlpha = function(_, a) containerAlpha[key] = a end }
    end
    local conts = { essential = Container("essential"), utility = Container("utility"), resources = Container("resources") }
    ns.profile = { bars = { essential = { visibility = {} }, utility = { visibility = { showTarget = true } } } }
    local fades = {}
    ns.Setting = function(key, field) return field == "fade" and fades[key] or nil end
    local panelCfg = { resources = { enabled = true, fadeWithEssential = true, loadConditions = {} } }
    ns.DB = {
        PANEL_ORDER = { "resources" },
        IsPanel = function(k) return panelCfg[k] ~= nil end,
        ConfigTable = function(k) return panelCfg[k] or (ns.profile.bars[k]) end,
    }
    ns.Bars = {
        Get = function(k) return conts[k] end,
        ForEachClaimed = function(_, fn) fn({}, {}) end,
    }
    ns.Decorate = { ApplyItemAlpha = function() itemCalls = itemCalls + 1 end }
    ns.Cursor = { OnAlpha = function() cursorCalls = cursorCalls + 1 end }

    -- Alpha：給 s 就不建 Snapshot；沒給才建
    local s = Vis.Snapshot()
    local n0 = Vis.snapshots
    eq("Alpha 給 s：值", Vis.Alpha("utility", s), 0)
    eq("Alpha 給 s：不建 Snapshot", Vis.snapshots, n0)
    Vis.Alpha("utility")
    eq("Alpha 沒給 s：建一次", Vis.snapshots, n0 + 1)

    -- Refresh：容器、current、跟著游標；不跑 item
    n0 = Vis.snapshots
    eq("Refresh 回傳 alpha", Vis.Refresh("essential", s), 1)
    eq("Refresh：容器套了", containerAlpha.essential, 1)
    eq("Refresh：current 寫了", Vis.Current("essential"), 1)
    eq("Refresh：跟著游標的開關叫了", cursorCalls, 1)
    eq("Refresh：不跑 item", itemCalls, 0)
    eq("Refresh 給 s：不建 Snapshot", Vis.snapshots, n0)
    -- Apply ＝ Refresh ＋ item
    Vis.Apply("utility", s)
    eq("Apply：跑 item", itemCalls, 1)
    eq("Apply：容器套了（沒目標 ⇒ 0）", containerAlpha.utility, 0)

    -- PanelAlpha：沒給 essAlpha 用 current.essential，給了用給的
    fades.essential = { enabled = true, alpha = 0.3 }
    Vis.Refresh("essential", s)
    eq("核心技能淡出 0.3", Vis.Current("essential"), 0.3)
    n0 = Vis.snapshots
    eq("PanelAlpha：讀 current.essential", Vis.PanelAlpha("resources", s), 0.3)
    eq("PanelAlpha：給 essAlpha 用給的", Vis.PanelAlpha("resources", s, 0.8), 0.8)
    eq("PanelAlpha 給 s：不建 Snapshot", Vis.snapshots, n0)

    -- ApplyPanels：只套面板、用 current.essential、不碰條
    containerAlpha.essential, containerAlpha.utility = nil, nil
    Vis.ApplyPanels(s)
    eq("ApplyPanels：面板用 current.essential", containerAlpha.resources, 0.3)
    eq("ApplyPanels：不碰條", containerAlpha.essential, nil)
    eq("ApplyPanels 給 s：不建 Snapshot", Vis.snapshots, n0)

    -- ApplyAll：整輪只建一次 Snapshot，面板讀的是同一輪剛算好的核心技能
    fades.essential = { enabled = true, alpha = 0.6 }
    n0 = Vis.snapshots
    Vis.ApplyAll()
    eq("ApplyAll：Snapshot 只建一次", Vis.snapshots, n0 + 1)
    eq("ApplyAll：核心技能", containerAlpha.essential, 0.6)
    eq("ApplyAll：面板跟著這一輪的核心技能", containerAlpha.resources, 0.6)
end

print(("Visibility_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
