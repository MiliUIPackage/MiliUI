------------------------------------------------------------
-- 資源條與施法條的純邏輯（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Resources_test.lua
--
-- 覆蓋：
--   1. 條件規則求值（Modules/ResourceConditions.lua）：六種比較、布林變數、and 巢狀、深度上限、
--      壞資料不報錯、target 與格子索引、第一條成立的勝出、FillState、表單簽章
--   2. 資源清單依專精（Modules/Resources.lua 的 RawList／Candidates）：每個專精的清單、法力排最下面、
--      德魯伊看型態、天賦閘（上限 0 隱藏、秘密上限照列、光環型看被動或層數）、玩家關掉的列
--   3. 法力縮寫、顏色解析（玩家的 → 預設、充能色退回主色）
--   4. 面板的 DB：預設值完整、ConfigTable、錨定成環、刪條清面板錨定、DefaultFor
--   5. 面板的顯示條件（Core/Visibility.lua 的 EvaluatePanel）
--   6. 施法條：時間文字、截字、刻度查表
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
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local env = setmetatable({}, { __index = _G })
env._G = env
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.InCombatLockdown = function() return false end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.UnitClass = function() return "聖騎士", "PALADIN", 2 end
env.GetLocale = function() return "zhTW" end
env.CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript() end
    return f
end
env.Enum = {
    CompressionMethod = { Deflate = 1 },
    PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6,
                  SoulShards = 7, LunarPower = 8, HolyPower = 9, Maelstrom = 11, Chi = 12, Insanity = 13,
                  ArcaneCharges = 16, Fury = 17, Essence = 19 },
    StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 },
}
env.MANA, env.RAGE, env.HOLY_POWER = "法力", "怒氣", "聖能"
env.SOUL_SHARDS = "靈魂|4裂片:裂片;"
local powerMax, powerCur = {}, {}
env.UnitPower = function(_, pt) return powerCur[pt] or 0 end
env.UnitPowerMax = function(_, pt) return powerMax[pt] or 0 end
local known = {}
env.C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
local auras = {}
env.C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return auras[id] end }
env.C_Spell = { GetSpellCastCount = function() return 0 end, GetSpellName = function(id) return "S" .. id end }
local form = nil
env.GetShapeshiftFormID = function() return form end
env.IsPlayerSpell = function(id) return known[id] == true end

local ns = {
    playerClass = "PALADIN",
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = function(v) return v == SECRET end,
    RegisterCallback = function() end,
    Fire = function() end,
    Events = { Register = function() end },
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
}
ns.Secret = { BarInterp = function() return nil end }

local function Load(rel, extra)
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

Load("Core/DB.lua")
Load("Modules/ResourceConditions.lua")
local RC = ns.ResCond

------------------------------------------------------------
-- 1. 條件規則求值
------------------------------------------------------------
local st = RC.NewState()
RC.FillState(st, 30, 100, 65)
eq("FillState 百分比", st.powerPercent, 30)
eq("FillState 未滿", st.powerFull, false)
eq("FillState spec", st.spec, 65)
RC.FillState(st, 5, 5, 65)
eq("FillState 滿", st.powerFull, true)
RC.FillState(st, 0, 0, nil)
eq("上限 0 → 百分比 0", st.powerPercent, 0)
eq("上限 0 → 不算滿", st.powerFull, false)

RC.FillState(st, 3, 5, 70)
local function leaf(var, cmp, value) return { var = var, cmp = cmp, value = value } end
check(">= 成立", RC.EvalLeaf(leaf("powerValue", ">=", 3), st))
check("> 不成立", not RC.EvalLeaf(leaf("powerValue", ">", 3), st))
check("<= 成立", RC.EvalLeaf(leaf("powerValue", "<=", 3), st))
check("< 不成立", not RC.EvalLeaf(leaf("powerValue", "<", 3), st))
check("== 成立", RC.EvalLeaf(leaf("powerValue", "==", 3), st))
check("~= 不成立", not RC.EvalLeaf(leaf("powerValue", "~=", 3), st))
check("百分比 60", RC.EvalLeaf(leaf("powerPercent", "==", 60), st))
check("spec == 70", RC.EvalLeaf(leaf("spec", "==", 70), st))
check("always", RC.EvalLeaf({ var = "always" }, st))
check("未知比較符不成立", not RC.EvalLeaf(leaf("powerValue", "=>", 1), st))
check("數值是字串不成立", not RC.EvalLeaf(leaf("powerValue", ">=", "1"), st))
check("未知變數不成立", not RC.EvalLeaf(leaf("health", ">=", 1), st))
check("powerFull = false 成立", RC.EvalLeaf({ var = "powerFull", value = false }, st))
check("powerFull 值不是布林不成立", not RC.EvalLeaf({ var = "powerFull", value = 1 }, st))
st.pipRecharging = true
check("pipRecharging", RC.EvalLeaf({ var = "pipRecharging", value = true }, st))
st.pipRecharging = false

local andNode = { op = "and", children = { leaf("powerValue", ">=", 2), leaf("powerValue", "<=", 4) } }
check("and 成立", RC.EvalCheck(andNode, st, 1))
andNode.children[2] = leaf("powerValue", "<", 3)
check("and 一條不成立就不成立", not RC.EvalCheck(andNode, st, 1))
check("空 children 成立", RC.EvalCheck({ op = "and", children = {} }, st, 1))
check("children 不是表不成立", not RC.EvalCheck({ op = "and", children = 5 }, st, 1))
check("check 不是表不成立", not RC.EvalCheck("x", st, 1))
-- 深度上限：自我參照不會無限遞迴
local loop = { op = "and" }
loop.children = { loop }
check("自我參照 → 不成立、不爆棧", not RC.EvalCheck(loop, st, 1))

local red, blue, green = { r = 1, g = 0, b = 0 }, { r = 0, g = 0, b = 1 }, { r = 0, g = 1, b = 0 }
local conds = {
    { check = leaf("powerValue", ">=", 5), overrides = { color = red } },
    { target = 2, check = { var = "always" }, overrides = { color = blue } },
    { check = leaf("powerValue", ">=", 3), overrides = { color = green, alpha = 0.5 } },
    "壞掉的規則",
    { check = leaf("powerValue", ">=", 0) },                      -- 沒有 overrides：跳過
}
RC.FillState(st, 3, 5, 70)
local ov, idx = RC.FirstMatch(conds, st, nil)
eq("整條：跳過 target 規則、第 3 條勝出", idx, 3)
eq("整條：覆寫色", ov and ov.color, green)
ov, idx = RC.FirstMatch(conds, st, 2)
eq("第 2 格：target 規則勝出", idx, 2)
ov, idx = RC.FirstMatch(conds, st, 1)
eq("第 1 格：target 不符，落到第 3 條", idx, 3)
RC.FillState(st, 5, 5, 70)
ov, idx = RC.FirstMatch(conds, st, 2)
eq("第一條成立的勝出（即使後面有 target 相符的）", idx, 1)
eq("非表的 conds → nil", RC.FirstMatch("x", st, nil), nil)
eq("target 是字串的規則永遠跳過", RC.FirstMatch({ { target = "2", check = { var = "always" }, overrides = {} } }, st, 2), nil)

check("ValidColor", RC.ValidColor(red) == red and RC.ValidColor({ r = 1 }) == nil and RC.ValidColor(5) == nil)
eq("Resolve 空表 → nil", RC.Resolve({ conditions = { HolyPower = {} } }, "HolyPower"), nil)
eq("Resolve 沒這個 key → nil", RC.Resolve({ conditions = {} }, "HolyPower"), nil)
eq("Resolve 設定不是表 → nil", RC.Resolve(nil, "HolyPower"), nil)
local cfgC = { conditions = { HolyPower = conds } }
eq("Resolve 回原表", RC.Resolve(cfgC, "HolyPower"), conds)

-- 檢查陣列的讀寫
local rule = { check = leaf("powerValue", ">=", 1) }
eq("單一 leaf 算 1 個檢查", RC.CheckCount(rule), 1)
RC.SetChecks(rule, { leaf("powerValue", ">=", 1), leaf("powerValue", "<=", 3) })
eq("兩個檢查包成 and", rule.check.op, "and")
eq("CheckCount 2", RC.CheckCount(rule), 2)
eq("CheckAt 2", RC.CheckAt(rule, 2).value, 3)
local arr = RC.ChecksArray(rule)
table.remove(arr, 1)
RC.SetChecks(rule, arr)
eq("剩一個就不包 and", rule.check.op, nil)
eq("剩下的是第二個", rule.check.value, 3)
eq("簽章：沒有規則", RC.Signature({ conditions = {} }, "X"), "0")
eq("簽章：三條規則", RC.Signature({ conditions = { X = { rule, { target = 2, check = { var = "always" } }, {} } } }, "X"), "3.1.1t2.0")

------------------------------------------------------------
-- 2. 資源清單依專精
------------------------------------------------------------
ns.Bars = { FirstRowWidth = function() return 0 end }
Load("Modules/Resources.lua")
local R = ns.Resources

eqList("防騎：聖能", R.RawList("PALADIN", 66, nil), { "HolyPower" })
eqList("神聖聖騎：聖能＋法力（法力排最下面）", R.RawList("PALADIN", 65, nil), { "HolyPower", "Mana" })
eqList("暗牧：狂亂值＋法力", R.RawList("PRIEST", 258, nil), { "Insanity", "Mana" })
eqList("戒律：只有法力", R.RawList("PRIEST", 256, nil), { "Mana" })
eqList("秘法：秘法充能＋法力", R.RawList("MAGE", 62, nil), { "ArcaneCharges", "Mana" })
eqList("刺殺：能量＋連擊點", R.RawList("ROGUE", 259, nil), { "Energy", "ComboPoints" })
eqList("血魄：符能＋符文", R.RawList("DEATHKNIGHT", 250, nil), { "RunicPower", "Runes" })
eqList("增強：漩渦之武＋法力", R.RawList("SHAMAN", 263, nil), { "MaelstromWeapon", "Mana" })
eqList("元素：元能＋法力", R.RawList("SHAMAN", 262, nil), { "Maelstrom", "Mana" })
eqList("生存：集中值＋矛尖", R.RawList("HUNTER", 255, nil), { "Focus", "TipOfTheSpear" })
eqList("復仇：魔怒＋靈魂碎片", R.RawList("DEMONHUNTER", 581, nil), { "Fury", "SoulFragments" })
eqList("防戰：怒氣（無視苦痛不做）", R.RawList("WARRIOR", 73, nil), { "Rage" })
eqList("釀酒：能量（醉仙緩勁不做）", R.RawList("MONK", 268, nil), { "Energy" })
eqList("織霧：法力", R.RawList("MONK", 270, nil), { "Mana" })
eqList("喚能師：精華＋法力", R.RawList("EVOKER", 1467, nil), { "Essence", "Mana" })
eqList("恢復德魯伊人形：法力", R.RawList("DRUID", 105, nil), { "Mana" })
eqList("恢復德魯伊貓形：能量＋連擊點＋法力", R.RawList("DRUID", 105, 1), { "Energy", "ComboPoints", "Mana" })
eqList("野性德魯伊熊形：怒氣", R.RawList("DRUID", 103, 5), { "Rage" })
eqList("野性德魯伊人形：沒有", R.RawList("DRUID", 103, nil), {})
eqList("平衡德魯伊：星能＋法力", R.RawList("DRUID", 102, nil), { "LunarPower", "Mana" })
eqList("沒有專精：空", R.RawList("PALADIN", nil, nil), {})
eqList("未知專精：空", R.RawList("PALADIN", 99999, nil), {})

-- 所有專精列到的 key 都有定義、有預設色
local allKeys = {}
for spec, keys in pairs(R.SPEC_RESOURCES) do for _, k in ipairs(keys) do allKeys[k] = spec end end
allKeys.Mana = 0
for k, spec in pairs(allKeys) do
    check("資源有定義：" .. k, R.RESOURCES[k] ~= nil, spec)
    check("資源有預設色：" .. k, ns.DB.RESOURCE_COLORS[k] ~= nil)
end
for k in pairs(ns.DB.RESOURCE_COLORS) do check("預設色都有對應的資源：" .. k, R.RESOURCES[k] ~= nil) end
eq("暴雪字串的複數轉義取單數", R.RESOURCES.SoulShards.name, "靈魂裂片")
eq("名稱用暴雪全域字串", R.RESOURCES.HolyPower.name, "聖能")
eq("全域不存在退回英文", R.RESOURCES.Chi.name, "Chi")

-- 天賦閘（Candidates 看 ns.specID 與 ns.playerClass；ns.playerClass 在載入時已固定成 PALADIN）
ns.specID = 65
powerMax[9], powerMax[0] = 5, 100000
R.Invalidate()
eqList("神聖聖騎：兩列都有上限", (R.Candidates()), { "HolyPower", "Mana" })
powerMax[9] = 0
R.Invalidate()
eqList("上限 0 → 那一列隱藏", (R.Candidates()), { "Mana" })
powerMax[9] = SECRET
R.Invalidate()
eqList("上限是秘密值 → 照列", (R.Candidates()), { "HolyPower", "Mana" })
check("gateLog 有記原因", type(R.gateLog.HolyPower) == "string")
powerMax[9] = 5
local _, spec = R.Candidates()
eq("快取：沒 Invalidate 不重算", spec, 65)

-- 格數：上限讀不到時沿用上次的明文值
powerMax[9] = 5
eq("聖能 5 格", R.SegmentsFor("HolyPower"), 5)
powerMax[9] = SECRET
eq("上限秘密 → 沿用上次的 5", R.SegmentsFor("HolyPower"), 5)
powerMax[9] = 12
eq("格數上限 10", R.SegmentsFor("HolyPower"), 10)
eq("連續條 0 格", R.SegmentsFor("Mana"), 0)
eq("光環型用定義的格數", R.SegmentsFor("MaelstromWeapon"), 10)

-- 取值：原始值原樣回傳（秘密值不在這裡洗）
powerCur[9] = SECRET
local cur = R.GetValue("HolyPower")
eq("GetValue 回原始值", cur, SECRET)
eq("Plain 洗掉秘密值", R.Plain(cur), nil)
auras[344179] = { applications = 7 }
eq("光環層數", (R.GetValue("MaelstromWeapon")), 7)
auras[344179] = nil
eq("沒有光環 → 0", (R.GetValue("MaelstromWeapon")), 0)

------------------------------------------------------------
-- 3. 法力縮寫、顏色
------------------------------------------------------------
eq("none", R.FormatMana(123456, 200000, { manaAbbrev = "none" }), "123456")
eq("k：百萬", R.FormatMana(1250000, 2e6, { manaAbbrev = "k" }), "1.2M")
eq("k：萬以上取整 K", R.FormatMana(250000, 2e6, { manaAbbrev = "k" }), "250K")
eq("k：千", R.FormatMana(1500, 2e6, { manaAbbrev = "k" }), "1.5K")
eq("k：小數字", R.FormatMana(999, 2e6, { manaAbbrev = "k" }), "999")
eq("wan：萬", R.FormatMana(250000, 2e6, { manaAbbrev = "wan" }), "25.0wan")
eq("wan：億", R.FormatMana(250000000, 3e8, { manaAbbrev = "wan" }), "2.50yi")
eq("wan：小於一萬", R.FormatMana(9999, 2e6, { manaAbbrev = "wan" }), "9999")
eq("百分比", R.FormatMana(50000, 200000, { manaPercent = true }), "25%")
eq("百分比：上限 0 → 空", R.FormatMana(5, 0, { manaPercent = true }), "")
eq("不是數字 → 空", R.FormatMana(nil, 1, {}), "")

local myRed = { r = 0.5, g = 0, b = 0 }
local cfgColors = { colors = { HolyPower = { color = myRed }, ComboPoints = {} } }
eq("玩家調的顏色優先", R.ResolveColor(cfgColors, "HolyPower", "color"), myRed)
eq("沒調 → DB 預設", R.ResolveColor(cfgColors, "Chi", "color"), ns.DB.RESOURCE_COLORS.Chi.color)
eq("充能色預設", R.ResolveColor(cfgColors, "ComboPoints", "chargedColor"), ns.DB.RESOURCE_COLORS.ComboPoints.chargedColor)
eq("沒有充能色的資源退回主色", R.ResolveColor(cfgColors, "HolyPower", "chargedColor"), ns.DB.RESOURCE_COLORS.HolyPower.color)
eq("沒定義的資源 → 白", R.ResolveColor(nil, "Nope", "color").r, 1)

------------------------------------------------------------
-- 4. 面板的 DB
------------------------------------------------------------
ns.RefreshSpec = function() ns.specIndex = 1; ns.specID = 61 end
ns.RefreshSpec()
ns.DB.Init()
local p = ns.profile
local res, cb = p.resources, p.castbar
check("資源條預設：錨在核心技能上方", type(res.anchor) == "table" and res.anchor.to == "essential" and res.anchor.point == "BOTTOM")
eq("資源條預設：寬 0", res.width, 0)
eq("資源條預設：zhTW 用萬／億", res.manaAbbrev, "wan")
check("資源條預設：每種資源都有自己的顏色表", type(res.colors.ComboPoints.chargedEmptyColor) == "table" and type(res.colors.Mana.color) == "table")
check("資源條預設：顏色表不共用預設那張", res.colors.Chi.color ~= ns.DB.RESOURCE_COLORS.Chi.color)
check("資源條預設：條件與開關列是空表", next(res.conditions) == nil and next(res.rows) == nil)
eq("資源條預設：跟核心技能一起淡", res.fadeWithEssential, true)
check("資源條預設：載入條件", res.loadConditions.hideMounted == false and res.loadConditions.onlyCombat == false)
eq("施法條預設：貼在資源條上方", type(cb.anchor) == "table" and cb.anchor.to, "resources")
check("施法條預設：刻度與延遲開", cb.ticks == true and cb.latency == true)
check("施法條預設：蓄力四階都有色", type(cb.colors.empowerStage4) == "table")
eq("施法條預設：隱藏暴雪施法條", cb.hideBlizzard, true)
eq("ConfigTable 資源條", ns.DB.ConfigTable("resources"), res)
eq("ConfigTable 施法條", ns.DB.ConfigTable("castbar"), cb)
eq("ConfigTable 條", ns.DB.ConfigTable("essential"), p.bars.essential)
eq("ConfigTable 沒這條", ns.DB.ConfigTable("nope"), nil)
check("IsPanel", ns.DB.IsPanel("resources") and ns.DB.IsPanel("castbar") and not ns.DB.IsPanel("essential"))
-- 錨定成環：資源條錨在核心技能上 ⇒ 核心技能不能錨到資源條
check("核心技能 → 資源條會成環", ns.DB.AnchorWouldCycle("essential", "resources"))
check("施法條 → 資源條不會成環", not ns.DB.AnchorWouldCycle("castbar", "resources"))
cb.anchor = { to = "resources", point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 }
check("資源條 → 施法條（施法條錨在資源條上）會成環", ns.DB.AnchorWouldCycle("resources", "castbar"))
-- 刪自訂群組：錨在它身上的面板一併放開
local g = ns.DB.CreateBar("icons", "防禦")
cb.anchor = { to = g, point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 }
ns.DB.DeleteBar(g)
eq("刪條：錨在它身上的施法條放開", cb.anchor, false)
-- 右鍵重設為預設
local d = ns.DB.DefaultFor("bar", "resources", "anchor")
check("DefaultFor 面板：錨定預設", type(d) == "table" and d.to == "essential" and d ~= res.anchor)
eq("DefaultFor 面板：數值", ns.DB.DefaultFor("bar", "castbar", "height"), 20)
check("DefaultFor 面板：顏色是複本", ns.DB.DefaultFor("bar", "resources", "colors.Chi.color") ~= res.colors.Chi.color)

------------------------------------------------------------
-- 5. 面板的顯示條件
------------------------------------------------------------
Load("Core/Visibility.lua")
local Vis = ns.Visibility
local s = { combat = false, target = false, mounted = false, instance = false, group = "solo" }
eq("資源條：關著 → 0", Vis.EvaluatePanel("resources", { enabled = false }, s, 1, false), 0)
eq("資源條：沒條件 → 1", Vis.EvaluatePanel("resources", { fadeWithEssential = false }, s, 0.3, false), 1)
eq("資源條：跟核心技能一起淡", Vis.EvaluatePanel("resources", { fadeWithEssential = true }, s, 0.3, false), 0.3)
eq("資源條：騎乘隱藏", Vis.EvaluatePanel("resources", { loadConditions = { hideMounted = true } },
    { mounted = true, combat = true }, 1, false), 0)
eq("資源條：只在戰鬥中（脫戰）", Vis.EvaluatePanel("resources", { loadConditions = { onlyCombat = true } }, s, 1, false), 0)
eq("資源條：只在戰鬥中（戰鬥中）", Vis.EvaluatePanel("resources", { loadConditions = { onlyCombat = true }, fadeWithEssential = false },
    { combat = true }, 1, false), 1)
eq("資源條：載入條件蓋過淡出", Vis.EvaluatePanel("resources", { loadConditions = { onlyCombat = true } }, s, 1, false), 0)
eq("施法條：沒在施法 → 0", Vis.EvaluatePanel("castbar", { hideWhenNotCasting = true }, s, 1, false), 0)
eq("施法條：施法中 → 1", Vis.EvaluatePanel("castbar", { hideWhenNotCasting = true }, s, 1, true), 1)
eq("施法條：不隱藏 → 1", Vis.EvaluatePanel("castbar", { hideWhenNotCasting = false }, s, 1, false), 1)
eq("施法條：關著 → 0", Vis.EvaluatePanel("castbar", { enabled = false, hideWhenNotCasting = false }, s, 1, true), 0)

------------------------------------------------------------
-- 6. 施法條的純函式
------------------------------------------------------------
env.C_CurveUtil = nil
Load("Modules/Castbar.lua")
local CB = ns.Castbar
eq("剩餘/總", CB.FormatTime("remainTotal", 1.2, 1.5), "0.3/1.5")
eq("已唱/總", CB.FormatTime("elapsedTotal", 1.2, 1.5), "1.2/1.5")
eq("剩餘", CB.FormatTime("remain", 1.2, 1.5), "0.3")
eq("已唱", CB.FormatTime("elapsed", 1.2, 1.5), "1.2")
eq("超過總長夾住", CB.FormatTime("remainTotal", 9, 1.5), "0.0/1.5")
eq("沒有總長：剩餘類留白", CB.FormatTime("remainTotal", 1.2, 0), "")
eq("沒有總長：已唱照印", CB.FormatTime("elapsedTotal", 1.2, 0), "1.2")
eq("負的已唱當 0", CB.FormatTime("elapsed", -1, 2), "0.0")
eq("截字：0 不截", CB.Truncate("Fireball", 0), "Fireball")
eq("截字：英文", CB.Truncate("Fireball", 4), "Fire…")
eq("截字：中文照字元算", CB.Truncate("炎爆術測試", 3), "炎爆術…")
eq("截字：剛好不截", CB.Truncate("炎爆術", 3), "炎爆術")
eq("截字：秘密字串原樣", CB.Truncate(SECRET, 3), SECRET)
CB.RebuildTicks()
eq("刻度：精神鞭笞 6 跳", CB.TickCount(15407, nil), 6)
eq("刻度：用名字查", CB.TickCount(nil, "S15407"), 6)
eq("刻度：不認得 0", CB.TickCount(1, "nope"), 0)
eq("刻度：秘密 ID 用名字", CB.TickCount(SECRET, "S740"), 4)

print(("Resources_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
