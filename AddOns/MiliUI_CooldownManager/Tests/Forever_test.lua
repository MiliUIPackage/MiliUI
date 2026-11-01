------------------------------------------------------------
-- 永恆版（WoW Forever，遊戲型別 camelot）的分流（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Forever_test.lua
--
-- 覆蓋：
--   1. ns.IS_FOREVER 的偵測（WOW_PROJECT_CAMELOT／WOW_PROJECT_FOREVER；正式服沒有這兩個常數）
--   2. ns.RefreshSpec：永恆 specIndex ＝ 主天賦樹（沒點天賦 nil）、specID ＝ 職業層的固定 key（負的 classID）；
--      正式服照舊（GetSpecialization／GetSpecializationInfo）
--   3. 面板清單拿掉天空騎術／坐騎特效按鈕／下一招圖示（ConfigTable nil、存檔的表照補）
--   4. 換主天賦樹也走換專精（SpecChanged、設定檔綁專精），只多聽 TRAIT_CONFIG_UPDATED
--   5. 四個模組不初始化（天空騎術、坐騎特效按鈕、下一招圖示、戰鬥藥水視窗）、戰鬥輔助當沒有
--   6. 資源清單照職業（Vanilla：法力／怒氣／能量／連擊點；德魯伊照型態），正式服 specID 照舊走專精表
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

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
local function list(t) return table.concat(t or {}, ",") end
local function eqList(name, got, want) eq(name, list(got), list(want)) end

------------------------------------------------------------
-- 環境
------------------------------------------------------------
local function NewFrame()
    local f = { events = {}, scripts = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:HookScript() end
    function f:SetAllPoints() end
    return f
end

local state = { tree = nil, class = { "戰士", "WARRIOR", 1 }, retailSpec = 1 }

local function NewEnv(forever)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    if forever then
        env.WOW_PROJECT_ID, env.WOW_PROJECT_CAMELOT = 18, 18
    else
        env.WOW_PROJECT_ID = 1                      -- 正式服：WOW_PROJECT_CAMELOT 不存在
    end
    env.UnitName = function() return "米利" end
    env.GetRealmName = function() return "世界之樹" end
    env.InCombatLockdown = function() return false end
    env.UnitClass = function() return state.class[1], state.class[2], state.class[3] end
    env.GetLocale = function() return "zhTW" end
    env.CreateFrame = function() return NewFrame() end
    env.C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end }
    env.C_AddOns = { GetAddOnMetadata = function() return "test" end, IsAddOnLoaded = function() return false end }
    env.C_SpecializationInfo = { GetSpecialization = function() return state.tree end }
    -- 永恆不載 Blizzard_DeprecatedSpecialization：全域不存在（正式服才有）
    if not forever then
        env.GetSpecialization = function() return state.retailSpec end
        env.GetSpecializationInfo = function(i) return 60 + i end
    end
    return env
end

local function NewNS(fired)
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        Secret = { IsSecret = function() return false end, BarInterp = function() return nil end },
        Errors = { Install = function() end },
        RegisterCallback = function() end,
        Fire = function(event, ...) fired[#fired + 1] = { event = event, ... } end,
        Defer = function(fn, ...) fn(...) end,
        ReportError = function(e) print("ReportError: " .. tostring(e)) end,
        Write = function(frame, fn) fn(frame) return true end,
        P = { Scale = function(v) return v end, Pixel = function(v) return v end },
    }
    return ns
end

local function Loader(env, ns)
    return function(rel)
        local path = here .. "/../" .. rel
        local chunk, err
        if setfenv then
            chunk, err = loadfile(path)
            if chunk then setfenv(chunk, env) end
        else
            chunk, err = loadfile(path, "t", env)
        end
        assert(chunk, err)
        chunk("MiliUI_CooldownManager", ns)
    end
end

------------------------------------------------------------
-- 1／2. 正式服對照：偵測是 false、RefreshSpec 照舊
------------------------------------------------------------
do
    local fired = {}
    local env, ns = NewEnv(false), NewNS(fired)
    Loader(env, ns)("Core/Init.lua")
    eq("正式服：IS_FOREVER 是 false", ns.IS_FOREVER, false)
    state.retailSpec = 2
    ns.RefreshSpec()
    eq("正式服：specIndex 照 GetSpecialization", ns.specIndex, 2)
    eq("正式服：specID 照 GetSpecializationInfo", ns.specID, 62)
    state.retailSpec = nil
    ns.RefreshSpec()
    eq("正式服：沒有專精 ⇒ specID nil", ns.specID, nil)
    state.retailSpec = 1
end

do
    local env, ns = NewEnv(false), NewNS({})
    env.WOW_PROJECT_ID, env.WOW_PROJECT_FOREVER = 18, 18      -- 暴雪說上市前可能改名 forever
    Loader(env, ns)("Core/Init.lua")
    eq("WOW_PROJECT_FOREVER 也認", ns.IS_FOREVER, true)
end

do
    local env, ns = NewEnv(false), NewNS({})
    env.WOW_PROJECT_ID, env.WOW_PROJECT_CAMELOT = 1, 18      -- 常數在、但專案不是它
    Loader(env, ns)("Core/Init.lua")
    eq("常數在但 WOW_PROJECT_ID 不同 ⇒ false", ns.IS_FOREVER, false)
end

------------------------------------------------------------
-- 永恆版：Init → DB → 模組
------------------------------------------------------------
local fired = {}
local env, ns = NewEnv(true), NewNS(fired)
local Load = Loader(env, ns)
Load("Core/Init.lua")
eq("永恆：IS_FOREVER 是 true", ns.IS_FOREVER, true)

state.tree = nil
ns.RefreshSpec()
eq("沒點天賦：specIndex nil", ns.specIndex, nil)
eq("沒點天賦：specID ＝ 負的 classID", ns.specID, -1)
state.tree = 2
ns.RefreshSpec()
eq("主天賦樹 2：specIndex 2", ns.specIndex, 2)
eq("主天賦樹換了：specID 不變", ns.specID, -1)
state.tree = 0
ns.RefreshSpec()
eq("索引 0 當沒有", ns.specIndex, nil)
state.tree = nil

-- DB.lua 的事件登記：包一層記下來（照常交給 Init 的 Events）
local captured = {}
local realRegister = ns.Events.Register
ns.Events.Register = function(ev, key, fn, unit)
    captured[ev .. "/" .. key] = fn
    return realRegister(ev, key, fn, unit)
end

Load("Core/DB.lua")
Load("Core/DB_Custom.lua")
local DB = ns.DB

------------------------------------------------------------
-- 3. 面板清單
------------------------------------------------------------
eqList("面板清單沒有天空騎術／坐騎特效／下一招圖示", DB.PANEL_ORDER,
    { "resources", "pips", "custombars", "procdeck", "castbar", "focuscast" })
check("IsPanel(skyriding) false", not DB.IsPanel("skyriding"))
check("IsPanel(mountspecial) false", not DB.IsPanel("mountspecial"))
check("IsPanel(assistIcon) false", not DB.IsPanel("assistIcon"))
check("IsPanel(resources) 照舊", DB.IsPanel("resources"))

ns.RefreshSpec()
DB.Init()
local p = ns.profile
check("存檔的天空騎術表照補（匯出到正式服照常）", type(p.skyriding) == "table" and type(p.mountspecial) == "table"
    and type(p.assistIcon) == "table")
eq("ConfigTable(skyriding) nil", DB.ConfigTable("skyriding"), nil)
eq("ConfigTable(mountspecial) nil", DB.ConfigTable("mountspecial"), nil)
eq("ConfigTable(assistIcon) nil", DB.ConfigTable("assistIcon"), nil)
eq("ConfigTable(resources) 照舊", DB.ConfigTable("resources"), p.resources)

-- 專精表的 key 是職業層的固定 key（沒點天賦也寫得進去）
local sp = DB.SpecSpells(true)
check("沒點天賦也有專精表", type(sp) == "table" and p.spells[-1] == sp)

------------------------------------------------------------
-- 4. 換主天賦樹 ＝ 換專精
------------------------------------------------------------
local onSpec = captured["PLAYER_SPECIALIZATION_CHANGED/db_spec"]
check("聽 PLAYER_SPECIALIZATION_CHANGED", type(onSpec) == "function")
check("永恆多聽 TRAIT_CONFIG_UPDATED", captured["TRAIT_CONFIG_UPDATED/db_spec"] == onSpec)

local function Count(event)
    local n = 0
    for _, f in ipairs(fired) do if f.event == event then n = n + 1 end end
    return n
end

DB.CreateProfile("Arms")
DB.SetSpecProfilesEnabled(true)
DB.SetSpecProfile(1, "Arms")
eq("還沒點天賦：照原本的設定檔", ns.profileName, DB.DEFAULT_PROFILE)
local before = Count("SpecChanged")
onSpec()
eq("沒變：不發 SpecChanged", Count("SpecChanged"), before)
state.tree = 1
onSpec()
eq("主天賦樹 nil → 1：發 SpecChanged", Count("SpecChanged"), before + 1)
eq("specID 還是職業層的 key", ns.specID, -1)
eq("綁定的設定檔跟著換", ns.profileName, "Arms")
onSpec()
eq("同一棵再問一次：不再發", Count("SpecChanged"), before + 1)
state.tree = 2
onSpec()
eq("換成第 2 棵：再發一次", Count("SpecChanged"), before + 2)
state.tree = nil

------------------------------------------------------------
-- 5. 閘掉的模組
------------------------------------------------------------
local registered = {}
ns.Bars = {
    RegisterPanel = function(key) registered[key] = true return NewFrame() end,
    SetPanelSize = function() end, ApplyPanelStructure = function() end,
}
env.C_AssistedCombat = { GetNextCastSpell = function() return 12345 end }
Load("Core/Assist.lua")
eq("戰鬥輔助：API 在也當沒有", ns.Assist.Available(), false)
check("戰鬥輔助：不輪詢", not ns.Assist.ShouldPoll({ api = ns.Assist.Available(), highlight = true, combat = true }))

Load("Modules/Skyriding.lua")
Load("Modules/MountSpecial.lua")
Load("Modules/AssistIcon.lua")
ns.Skyriding.Init()
ns.MountSpecial.Init()
ns.AssistIcon.Init()
check("天空騎術：不登記面板", not registered.skyriding)
check("坐騎特效按鈕：不登記面板", not registered.mountspecial)
check("下一招圖示：不登記面板", not registered.assistIcon)
eq("天空騎術：沒在顯示", ns.Skyriding.Shown(), false)
eq("天空騎術：不是接力（Bars 不把核心技能當它的位置）", ns.Skyriding.RelayTo(), nil)
eq("坐騎特效按鈕：沒在顯示", ns.MountSpecial.Visible(), false)
eq("坐騎特效按鈕：不跟天空騎術條", ns.MountSpecial.FollowingSky(), false)

local potionEvents = {}
local keepRegister = ns.Events.Register
ns.Events.Register = function(ev, key, fn, unit)
    if key == "potion_window" then potionEvents[#potionEvents + 1] = ev end
    return keepRegister(ev, key, fn, unit)
end
ns.Presets = { ITEMS = { { key = "zealotry", items = { 245900 } } }, AURAS = { { key = "zealotry", ids = { 1238443 } } } }
Load("Modules/PotionWindow.lua")
ns.PotionWindow.Init()
eq("戰鬥藥水視窗：不聽施放事件", #potionEvents, 0)
eq("戰鬥藥水視窗：沒有視窗", ns.PotionWindow.Active(0), false)
ns.Events.Register = keepRegister

------------------------------------------------------------
-- 6. 資源清單
------------------------------------------------------------
env.Enum = {
    PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6,
                  SoulShards = 7, LunarPower = 8, HolyPower = 9, Maelstrom = 11, Chi = 12, Insanity = 13,
                  ArcaneCharges = 16, Fury = 17, Essence = 19 },
    StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
}
local powerMax = { [1] = 100 }
env.UnitPower = function() return 0 end
env.UnitPowerMax = function(_, pt) return powerMax[pt] or 0 end
env.C_SpellBook = { IsSpellKnown = function() return false end }
env.C_UnitAuras = { GetPlayerAuraBySpellID = function() return nil end }
env.C_Spell = { GetSpellCastCount = function() return 0 end, GetSpellName = function(id) return "S" .. id end }
env.UnitHealth = function() return 1 end
env.UnitHealthMax = function() return 1 end
ns.playerClass = "WARRIOR"
Load("Modules/ResourceConditions.lua")
Load("Modules/Resources.lua")
Load("Modules/Resources_Defs.lua")
local R = ns.Resources

eqList("戰士：怒氣", R.RawList("WARRIOR", -1), { "Rage" })
eqList("盜賊：能量＋連擊點", R.RawList("ROGUE", -4), { "Energy", "ComboPoints" })
for _, c in ipairs({ { "PALADIN", -2 }, { "HUNTER", -3 }, { "PRIEST", -5 }, { "SHAMAN", -7 }, { "MAGE", -8 }, { "WARLOCK", -9 } }) do
    eqList(c[1] .. "：法力", R.RawList(c[1], c[2]), { "Mana" })
end
eqList("德魯伊人形：法力", R.RawList("DRUID", -11, nil), { "Mana" })
eqList("德魯伊熊：怒氣＋法力", R.RawList("DRUID", -11, 5), { "Rage", "Mana" })
eqList("德魯伊貓：能量＋連擊點＋法力", R.RawList("DRUID", -11, 1), { "Energy", "ComboPoints", "Mana" })
eqList("德魯伊梟獸（其他型態）：法力", R.RawList("DRUID", -11, 31), { "Mana" })
eqList("沒有專精 key 也照職業給", R.RawList("WARRIOR", nil), { "Rage" })
eqList("正式服的 specID 照舊走專精表（匯入／遷移用）", R.RawList("WARRIOR", 71), { "Rage", "SweepingStrikes" })
eq("正式服專精的候選照舊", R.SpecCandidates(73).IgnorePain, true)
check("職業層 key 不是任何專精的候選（遷移／匯入不碰）", next(R.SpecCandidates(-1)) == nil)
check("職業層 key：法力預設開", R.DefaultOn(-8, "Mana"))
check("職業層 key：血量預設關", not R.DefaultOn(-1, "Health"))

ns.RefreshSpec()
R.Invalidate()
local cand = R.Candidates()
eqList("戰士的候選（套天賦閘：怒氣上限 100）＋血量", cand, { "Rage", "Health" })
powerMax[1] = 0
R.Invalidate()
eqList("怒氣上限 0 ⇒ 不列", (R.Candidates()), { "Health" })

------------------------------------------------------------
-- 7. 連擊點綁在目標身上（targetBound）：取值走 GetComboPoints("player", "target")、上限照舊
------------------------------------------------------------
eq("永恆：連擊點的定義帶 targetBound", R.RESOURCES.ComboPoints.targetBound, true)
check("其他資源不帶", not R.RESOURCES.Energy.targetBound and not R.RESOURCES.Rage.targetBound)
local combo = { n = 3, throw = false, unit = nil, target = nil }
env.GetComboPoints = function(unit, target)
    combo.unit, combo.target = unit, target
    if combo.throw then error("boom") end
    return combo.n
end
powerMax[4] = 5
local c, m = R.GetValue("ComboPoints")
eq("連擊點：讀目標身上的", c, 3)
eq("連擊點：上限照 UnitPowerMax", m, 5)
check("連擊點：問的是 (player, target)", combo.unit == "player" and combo.target == "target")
combo.n = nil
eq("讀到 nil ⇒ 0", (R.GetValue("ComboPoints")), 0)
combo.throw = true
eq("拋錯 ⇒ 0", (R.GetValue("ComboPoints")), 0)
combo.throw = false
local SECRET = setmetatable({}, {
    __eq = function() error("compared a secret") end, __lt = function() error("compared a secret") end,
    __le = function() error("compared a secret") end,
})
local realIsSecret = ns.IsSecret
ns.IsSecret = function(v) return rawequal(v, SECRET) end
combo.n = SECRET
local okSecret, sv = pcall(R.GetValue, "ComboPoints")
check("秘密值原樣轉手、不比較", okSecret and rawequal(sv, SECRET), tostring(sv))
ns.IsSecret = realIsSecret
combo.n = 3
local pc = env.UnitPower
env.UnitPower = function() return 5 end
eq("能量照舊讀 UnitPower（只有連擊點換來源）", (R.GetValue("Energy")), 5)
env.UnitPower = pc

------------------------------------------------------------
-- 8. 盜賊／德魯伊：換目標、點數轉到新目標只重畫值（Resources 自己的事件框；R.Init 跑一次真的排版）
--    正式服對照：不註冊這兩個事件、連擊點照舊讀 UnitPower
------------------------------------------------------------
local function LooseFrame(made)
    local f = { events = {}, scripts = {} }
    made[#made + 1] = f
    return setmetatable(f, { __index = function(_, k)
        if k == "RegisterEvent" or k == "RegisterUnitEvent" then return function(self, e) self.events[e] = true end end
        if k == "UnregisterEvent" then return function(self, e) self.events[e] = nil end end
        if k == "SetScript" then return function(self, n, fn) self.scripts[n] = fn end end
        if k == "GetWidth" or k == "GetHeight" then return function() return 100 end end
        if k == "GetStringWidth" or k == "GetStringHeight" then return function() return 10 end end
        if k == "GetEffectiveScale" or k == "GetScale" then return function() return 1 end end
        if k:match("^Create") then return function() return LooseFrame(made) end end
        if k:match("^%u") then return function() return nil end end      -- 其他方法一律空操作；小寫欄位照常是 nil
        return nil
    end })
end
local function Anything() return setmetatable({}, { __index = function() return function() return nil end end }) end

local function RogueResources(forever)
    state.class = { "盜賊", "ROGUE", 4 }
    local made, queue = {}, {}
    local renv, rns = NewEnv(forever), NewNS({})
    renv.CreateFrame = function() return LooseFrame(made) end
    renv.UIParent = LooseFrame({})
    renv.Enum = env.Enum
    local rmax = { [3] = 100, [4] = 5 }
    renv.UnitPower = function(_, pt) return pt == 4 and 1 or 0 end
    renv.UnitPowerMax = function(_, pt) return rmax[pt] or 0 end
    renv.GetComboPoints = function() return 4 end
    renv.UnitHealth, renv.UnitHealthMax = function() return 1 end, function() return 1 end
    renv.C_SpellBook = { IsSpellKnown = function() return false end }
    renv.C_UnitAuras = { GetPlayerAuraBySpellID = function() return nil end }
    renv.C_Spell = { GetSpellName = function(id) return "S" .. id end }
    local L2 = Loader(renv, rns)
    L2("Core/Init.lua")
    rns.Defer = function(fn) queue[#queue + 1] = fn end         -- Init.lua 的 Defer 走 C_Timer：換成手動
    L2("Core/DB.lua")
    L2("Core/DB_Custom.lua")
    rns.RefreshSpec()
    rns.DB.Init()
    rns.Media, rns.AuraBar, rns.Shape, rns.Visibility, rns.Style = Anything(), Anything(), Anything(), Anything(), Anything()
    rns.Bars = Anything()
    rns.Bars.RegisterPanel = function() return LooseFrame(made) end
    L2("Modules/ResourceConditions.lua")
    L2("Modules/Resources.lua")
    L2("Modules/Resources_Defs.lua")
    L2("Modules/Resources_Rows.lua")
    local RR = rns.Resources
    local okInit, errInit = pcall(RR.Init)
    local evf
    for _, f in ipairs(made) do
        if f.events.UNIT_POWER_FREQUENT then evf = f end
    end
    local function Run()
        local list = queue
        queue = {}
        for _, fn in ipairs(list) do fn() end
    end
    state.class = { "戰士", "WARRIOR", 1 }
    return RR, rns, evf, Run, okInit, errInit
end

do
    local RR, rns, evf, Run, okInit, errInit = RogueResources(true)
    check("永恆盜賊：R.Init 跑得完", okInit, errInit)
    check("永恆盜賊：找得到資源條的事件框", evf ~= nil)
    if evf then
        check("永恆盜賊：聽 PLAYER_TARGET_CHANGED", evf.events.PLAYER_TARGET_CHANGED == true)
        check("永恆盜賊：聽 COMBO_TARGET_CHANGED", evf.events.COMBO_TARGET_CHANGED == true)
        eqList("永恆盜賊：畫面上的列", RR.Candidates(), { "Energy", "ComboPoints", "Health" })
        eq("永恆盜賊：連擊點讀目標身上的", (RR.GetValue("ComboPoints")), 4)
        Run()
        local reevals = 0
        local realReeval = RR.Reevaluate
        RR.Reevaluate = function() reevals = reevals + 1 return realReeval() end
        local v0 = RR.valueFlushes
        evf.scripts.OnEvent(evf, "COMBO_TARGET_CHANGED")
        Run()
        eq("點數轉到新目標：重畫值一次", RR.valueFlushes, v0 + 1)
        evf.scripts.OnEvent(evf, "PLAYER_TARGET_CHANGED")
        Run()
        eq("換目標：重畫值一次", RR.valueFlushes, v0 + 2)
        eq("兩個事件都不重推候選清單", reevals, 0)
        -- 連擊點那一列關掉：換目標不重畫
        RR.SetRow(rns.DB.ConfigTable("resources"), rns.specID, "ComboPoints", false)
        RR.Reevaluate()
        Run()
        reevals = 0
        local v1 = RR.valueFlushes
        evf.scripts.OnEvent(evf, "COMBO_TARGET_CHANGED")
        evf.scripts.OnEvent(evf, "PLAYER_TARGET_CHANGED")
        Run()
        eq("連擊點列關掉：換目標不重畫", RR.valueFlushes, v1)
        eq("連擊點列關掉：也不重推", reevals, 0)
        RR.Reevaluate = realReeval
    end
end

do
    local RR, _, evf, _, okInit, errInit = RogueResources(false)
    check("正式服盜賊：R.Init 跑得完", okInit, errInit)
    check("正式服盜賊：不聽 PLAYER_TARGET_CHANGED／COMBO_TARGET_CHANGED",
        evf ~= nil and not evf.events.PLAYER_TARGET_CHANGED and not evf.events.COMBO_TARGET_CHANGED)
    check("正式服：連擊點定義不帶 targetBound", RR.RESOURCES.ComboPoints.targetBound == nil)
    eq("正式服：連擊點照舊讀 UnitPower", (RR.GetValue("ComboPoints")), 1)
end

print(("Forever_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
