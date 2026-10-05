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
--   4. 面板的 DB：預設值完整、ConfigTable、錨定成環、刪條清面板錨定、DefaultFor；
--      自訂格子的面板（pips 錨在核心下方、輔助錨在 pips 下方）
--   5. 面板的顯示條件（Core/Visibility.lua 的 EvaluatePanel；含自訂格子）
--   6. 施法條：時間文字、截字、刻度查表
--   7. 自訂格子（Modules/Pips.lua）：清單依專精、增刪、PlanCustomRows（充能上限的退路、層數上限、
--      enabled = false、未學會的充能法術、壞資料、顯示時機）、容器高度（沒有列 ＝ 0）、預設值、
--      閘門／填色的 min／max、充能列的顯示時機（ChargeAlpha）
--   8. 補齊的職業資源：專精對照、取值函式（醉仙緩勁、吸收盾、噬靈魂碎片）、醉仙緩勁段落、
--      auraBar 的格數與條件規則、AuraBar 的幾何與簽章（Modules/AuraBar.lua）
--   9. 光環剩餘時間條（auraTimer：黯黑力量、秘法靈魂）：專精對照、定義與預設色、畫法規劃（DrawMode）、
--      天賦閘（被動／英雄天賦樹）、Lua 不讀值、空條底色、duration 簽章
--  10. 符文排序與秒數
--  11. 列的順序（ApplyOrder／MergeOrder、候選套 order）、血量列（候選、預設關、不支援條件、秘密值轉手、
--      門檻曲線的點與簽章）、施法條的暴雪材質
--  12. 2026-10-02 補齊：毀滅術碎片零頭（ShardPer／ShardSplit）、精華回充（EssenceFrac）、
--      無視苦痛百分比條（auraPct：畫法、退路、層數文字簽章）、氣漩武器摺疊（Folded／FoldRange／格數）、
--      醉仙緩勁 4 段（StaggerBand／StaggerTiers／StaggerCeiling／標籤）、秘法靈魂剩幾個 GCD（GcdLength／ReadGcd／
--      GcdFormatter 的分段）、分專精開關（SetRow／SpecCandidates／MigrateFlatRows／設定遷移 v3）
--  13. 每種資源自己的外觀（R.StyleFor 代理表：跟／不跟、退回全域、非外觀欄位照讀、唯讀、不可遍歷、
--      快取在 R.Apply 後作廢）、預設 style 空表、DefaultFor 回 nil
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
Load("Modules/Pips.lua")
local PI = ns.Pips

eqList("防騎：聖能", R.RawList("PALADIN", 66, nil), { "HolyPower" })
eqList("神聖聖騎：聖能＋法力（法力排最下面）", R.RawList("PALADIN", 65, nil), { "HolyPower", "Mana" })
eqList("暗牧：狂亂值＋法力", R.RawList("PRIEST", 258, nil), { "Insanity", "Mana" })
eqList("戒律：只有法力", R.RawList("PRIEST", 256, nil), { "Mana" })
eqList("增強薩：氣旋武器＋法力（候選還在）", R.RawList("SHAMAN", 263, nil), { "MaelstromWeapon", "Mana" })
check("增強薩：法力預設不顯示", R.DefaultOn(263, "Mana") == false and R.DefaultOn(263, "MaelstromWeapon") == true)
check("神聖聖騎：法力預設顯示", R.DefaultOn(65, "Mana") == true)
check("輸出專精：法力預設不顯示", R.DefaultOn(258, "Mana") == false and R.DefaultOn(262, "Mana") == false
    and R.DefaultOn(265, "Mana") == false and R.DefaultOn(266, "Mana") == false and R.DefaultOn(267, "Mana") == false
    and R.DefaultOn(102, "Mana") == false and R.DefaultOn(1467, "Mana") == false and R.DefaultOn(1473, "Mana") == false)
check("治療與法師：法力預設顯示", R.DefaultOn(256, "Mana") and R.DefaultOn(257, "Mana") and R.DefaultOn(264, "Mana")
    and R.DefaultOn(62, "Mana") and R.DefaultOn(63, "Mana") and R.DefaultOn(64, "Mana") and R.DefaultOn(105, "Mana")
    and R.DefaultOn(270, "Mana") and R.DefaultOn(1468, "Mana"))
check("開關：nil 照預設", R.RowOn({ rows = {} }, 263, "Mana") == false and R.RowOn({ rows = {} }, 65, "Mana") == true)
check("開關：true 強制開、false 強制關", R.RowOn({ rows = { [263] = { Mana = true } } }, 263, "Mana") == true
    and R.RowOn({ rows = { [65] = { Mana = false } } }, 65, "Mana") == false)
check("開關：分專精（別的專精的值不影響）", R.RowOn({ rows = { [263] = { Mana = true } } }, 262, "Mana") == false
    and R.RowOn({ rows = { [65] = { Mana = false } } }, 256, "Mana") == true)
check("開關：舊的平面鍵不認（遷移前的殘留不會被當成這個專精的值）", R.RowOn({ rows = { Mana = true } }, 263, "Mana") == false)
check("開關：沒有專精照預設", R.RowOn({ rows = { [65] = { Mana = false } } }, nil, "Mana") == true)
check("開關：沒有 rows 表也不炸", R.RowOn(nil, 263, "Mana") == false and R.RowOn({}, 65, "Mana") == true)
eqList("秘法：秘法充能＋秘法靈魂＋法力", R.RawList("MAGE", 62, nil), { "ArcaneCharges", "ArcaneSoul", "Mana" })
eqList("刺殺：能量＋連擊點", R.RawList("ROGUE", 259, nil), { "Energy", "ComboPoints" })
eqList("血魄：符能＋符文", R.RawList("DEATHKNIGHT", 250, nil), { "RunicPower", "Runes" })
eqList("增強：漩渦之武＋法力", R.RawList("SHAMAN", 263, nil), { "MaelstromWeapon", "Mana" })
eqList("元素：元能＋法力", R.RawList("SHAMAN", 262, nil), { "Maelstrom", "Mana" })
eqList("生存：集中值＋矛尖", R.RawList("HUNTER", 255, nil), { "Focus", "TipOfTheSpear" })
eqList("復仇：魔怒＋靈魂碎片", R.RawList("DEMONHUNTER", 581, nil), { "Fury", "SoulFragments" })
eqList("防戰：怒氣＋無視苦痛", R.RawList("WARRIOR", 73, nil), { "Rage", "IgnorePain" })
eqList("武器戰：怒氣＋橫掃攻擊", R.RawList("WARRIOR", 71, nil), { "Rage", "SweepingStrikes" })
eqList("狂怒戰：怒氣＋旋風斬", R.RawList("WARRIOR", 72, nil), { "Rage", "WhirlwindStacks" })
eqList("釀酒：能量＋醉仙緩勁", R.RawList("MONK", 268, nil), { "Energy", "Stagger" })
eqList("冰法：冰刺＋法力", R.RawList("MAGE", 64, nil), { "Icicles", "Mana" })
eqList("火法：只有法力", R.RawList("MAGE", 63, nil), { "Mana" })
eqList("噬魂者：魔怒＋靈魂碎片", R.RawList("DEMONHUNTER", 1480, nil), { "Fury", "DevourerFragments" })
eqList("守護德魯伊熊形：怒氣＋鐵鬃", R.RawList("DRUID", 104, 5), { "Rage", "Ironfur" })
eqList("野性德魯伊人形：法力", R.RawList("DRUID", 103, nil), { "Mana" })
eqList("守護德魯伊人形：法力", R.RawList("DRUID", 104, nil), { "Mana" })
eqList("野性德魯伊貓形：沒有法力", R.RawList("DRUID", 103, 1), { "Energy", "ComboPoints" })
check("野性／守護：人形法力預設顯示、是候選", R.DefaultOn(103, "Mana") and R.DefaultOn(104, "Mana")
    and R.SpecCandidates(103).Mana and R.SpecCandidates(104).Mana)
eqList("守護德魯伊貓形：沒有鐵鬃", R.RawList("DRUID", 104, 1), { "Energy", "ComboPoints" })
eqList("織霧：法力", R.RawList("MONK", 270, nil), { "Mana" })
eqList("喚能師：精華＋法力", R.RawList("EVOKER", 1467, nil), { "Essence", "Mana" })
eqList("恢復德魯伊人形：法力", R.RawList("DRUID", 105, nil), { "Mana" })
eqList("恢復德魯伊貓形：能量＋連擊點＋法力", R.RawList("DRUID", 105, 1), { "Energy", "ComboPoints", "Mana" })
eqList("野性德魯伊熊形：怒氣", R.RawList("DRUID", 103, 5), { "Rage" })
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
eqList("神聖聖騎：兩列都有上限", (R.Candidates()), { "HolyPower", "Mana", "Health" })
powerMax[9] = 0
R.Invalidate()
eqList("上限 0 → 那一列隱藏", (R.Candidates()), { "Mana", "Health" })
powerMax[9] = SECRET
R.Invalidate()
eqList("上限是秘密值 → 照列", (R.Candidates()), { "HolyPower", "Mana", "Health" })
check("gateLog 有記原因", type(R.gateLog.HolyPower) == "string")
powerMax[9] = 5
local _, spec = R.Candidates()
eq("快取：沒 Invalidate 不重算", spec, 65)

-- 格數：上限讀不到時沿用上次的明文值
powerMax[9] = 5
eq("聖能 5 格", R.SegmentsFor("HolyPower"), 5)
powerMax[9] = SECRET
eq("上限秘密 → 沿用上次的 5", R.SegmentsFor("HolyPower"), 5)
powerMax[9] = 40
eq("格數上限 30", R.SegmentsFor("HolyPower"), 30)
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

-- 秘密值：不能先過 Plain（12.1 的法力永遠是秘密值），縮寫與百分比交給 C 端
do
    local fs = { t = nil }
    function fs:SetText(t) self.t = t end
    function fs:SetFormattedText(f, ...) self.t = { f, ... } end
    env.CreateAbbreviateConfig = function(o) return o end
    env.AbbreviateNumbers = function(v, c) return { "abbrev", v, c } end
    env.CurveConstants = { ScaleTo100 = "S100" }
    env.UnitPowerPercent = function(u, pt, unmod, curve) return { "pct", u, pt, unmod, curve } end
    R.SetNumberText(fs, 1500, 2e6, { manaAbbrev = "k" })
    eq("明文照 FormatMana", fs.t, "1.5K")
    R.SetNumberText(fs, SECRET, SECRET, { manaAbbrev = "wan" })
    eq("秘密值 → AbbreviateNumbers", fs.t[1], "abbrev")
    eq("秘密值原樣傳下去", fs.t[2], SECRET)
    eq("萬／億的分段", fs.t[3].config[2].abbreviation, "wan")
    R.SetNumberText(fs, SECRET, SECRET, { manaPercent = true }, 0)
    eq("秘密值百分比 → UnitPowerPercent", fs.t[1], "%d%%")
    eq("百分比走 ScaleTo100", fs.t[2][5], "S100")
    R.SetNumberText(fs, nil, 1, {})
    eq("不是數字 → 空（秘密路徑）", fs.t, "")
end

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
check("資源條預設：開關列是空表", next(res.rows) == nil)
check("資源條預設：聖能兩段換色（5、3）", #res.conditions.HolyPower == 2 and res.conditions.HolyPower[1].check.value == 5
    and res.conditions.HolyPower[2].check.value == 3 and res.conditions.HolyPower[1].overrides.color.r == 0.914)
check("資源條預設：氣旋武器兩段換色（10、9）", #res.conditions.MaelstromWeapon == 2
    and res.conditions.MaelstromWeapon[1].check.value == 10 and res.conditions.MaelstromWeapon[2].check.value == 9)
check("資源條預設：列高 14、格距 0", res.rowHeight == 14 and res.segmentSpacing == 0)
do
    -- 上色規則是「整張表」的預設：設定檔裡已經有 conditions（含空表）就不合併
    local d = ns.DB.BuildDefaults().profile.resources
    local empty = { conditions = {} }
    ns.DB.MergeDefaults(empty, d)
    check("上色規則：已有的空表不被灌預設", next(empty.conditions) == nil)
    local mine = { conditions = { HolyPower = { { check = { var = "always" }, overrides = { alpha = 0.5 } } } } }
    ns.DB.MergeDefaults(mine, ns.DB.BuildDefaults().profile.resources)
    local hp = mine.conditions.HolyPower
    check("上色規則：自己的規則不被併進預設的欄位", #hp == 1 and hp[1].overrides.color == nil and hp[1].check.value == nil)
    check("上色規則：已有的表不多出氣旋武器", mine.conditions.MaelstromWeapon == nil)
    local fresh = {}
    ns.DB.MergeDefaults(fresh, ns.DB.BuildDefaults().profile.resources)
    check("上色規則：沒有 conditions 的設定檔拿到預設", #fresh.conditions.HolyPower == 2)
    check("上色規則：給出去的是複本", fresh.conditions.HolyPower ~= res.conditions.HolyPower)
end
eq("資源條預設：跟核心技能一起淡", res.fadeWithEssential, true)
check("資源條預設：條上顯示數值、14 號字", res.showText == true and res.textSize == 14)
check("資源條預設：載入條件", res.loadConditions.hideMounted == false and res.loadConditions.onlyCombat == false)
check("施法條預設：跟著核心技能上方（跟資源條同一邊，排在它外面）", type(cb.anchor) == "table" and cb.anchor.to == "essential"
    and cb.anchor.point == "BOTTOM" and cb.anchor.relPoint == "TOP")
check("施法條預設：刻度與延遲開", cb.ticks == true and cb.latency == true)
check("施法條預設：蓄力四階都有色", type(cb.colors.empowerStage4) == "table")
eq("施法條預設：隱藏暴雪施法條", cb.hideBlizzard, true)
eq("ConfigTable 資源條", ns.DB.ConfigTable("resources"), res)
eq("ConfigTable 施法條", ns.DB.ConfigTable("castbar"), cb)
eq("ConfigTable 條", ns.DB.ConfigTable("essential"), p.bars.essential)
eq("ConfigTable 沒這條", ns.DB.ConfigTable("nope"), nil)
check("IsPanel", ns.DB.IsPanel("resources") and ns.DB.IsPanel("castbar") and not ns.DB.IsPanel("essential"))
-- 自訂格子的面板：跟輔助技能一樣跟著核心技能下方，排開之後是 核心 → 自訂格子 → 輔助
local pips = p.pips
check("自訂格子預設：錨在核心技能下方", type(pips) == "table" and type(pips.anchor) == "table" and pips.anchor.to == "essential"
    and pips.anchor.point == "TOP" and pips.anchor.relPoint == "BOTTOM" and pips.anchor.x == 0 and pips.anchor.y == -1)
check("自訂格子預設：開、跟核心技能一起淡、自己的 pos", pips.enabled == true and pips.fadeWithEssential == true
    and pips.pos.point == "CENTER" and pips.pos.y == -250)
local ua = p.bars.utility.anchor
check("輔助預設：跟著核心技能下方", type(ua) == "table" and ua.to == "essential" and ua.point == "TOP" and ua.relPoint == "BOTTOM" and ua.y == -1)
eq("ConfigTable 自訂格子", ns.DB.ConfigTable("pips"), pips)
check("IsPanel 自訂格子", ns.DB.IsPanel("pips"))
-- 下一招圖示（P2）排在最後：前三個的順序不變
eq("面板順序：資源條、自訂格子、施法條、下一招圖示", table.concat(ns.DB.PANEL_ORDER, ","), "resources,pips,castbar,assistIcon")
check("核心技能 → 自訂格子會成環", ns.DB.AnchorWouldCycle("essential", "pips"))
check("自訂格子 → 輔助不會成環（輔助跟的是核心）", not ns.DB.AnchorWouldCycle("pips", "utility"))
check("施法條 → 自訂格子不會成環", not ns.DB.AnchorWouldCycle("castbar", "pips"))
local dp = ns.DB.DefaultFor("bar", "pips", "anchor")
check("DefaultFor 自訂格子：錨定預設是複本", type(dp) == "table" and dp.to == "essential" and dp ~= pips.anchor)
eq("DefaultFor 輔助：跟著核心", ns.DB.DefaultFor("bar", "utility", "anchor.to"), "essential")
-- 刪自訂群組：錨在它身上的自訂格子一併放開
local g2 = ns.DB.CreateBar("icons", "臨時")
pips.anchor = { to = g2, point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 }
ns.DB.DeleteBar(g2)
eq("刪條：錨在它身上的自訂格子放開", pips.anchor, false)
pips.anchor = ns.DB.DefaultFor("bar", "pips", "anchor")
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
eq("自訂格子：關著 → 0", Vis.EvaluatePanel("pips", { enabled = false }, s, 1, false), 0)
eq("自訂格子：跟核心技能一起淡", Vis.EvaluatePanel("pips", { fadeWithEssential = true }, s, 0.3, false), 0.3)
eq("自訂格子：不跟 → 1", Vis.EvaluatePanel("pips", { fadeWithEssential = false }, s, 0.3, false), 1)
eq("自訂格子：自己的載入條件（只在戰鬥中、脫戰）", Vis.EvaluatePanel("pips", { loadConditions = { onlyCombat = true } }, s, 1, false), 0)
eq("自訂格子：自己的載入條件（只在戰鬥中、戰鬥中）", Vis.EvaluatePanel("pips", { loadConditions = { onlyCombat = true }, fadeWithEssential = false },
    { combat = true }, 1, false), 1)
eq("自訂格子：騎乘隱藏", Vis.EvaluatePanel("pips", { loadConditions = { hideMounted = true } }, { mounted = true, combat = true }, 1, false), 0)
eq("自訂格子：沒有 loadConditions 照常", Vis.EvaluatePanel("pips", { fadeWithEssential = false }, s, 1, false), 1)
check("自訂格子預設：載入條件兩個都關", type(ns.DB.BuildDefaults().profile.pips.loadConditions) == "table"
    and ns.DB.BuildDefaults().profile.pips.loadConditions.onlyCombat == false)

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

------------------------------------------------------------
-- 7. 自訂格子（Modules/Pips.lua）
------------------------------------------------------------
-- 容器高度：沒有列 ＝ 0（輔助技能貼回核心下方）
eq("容器高度：0 列 → 0", PI.PanelHeight({}, 1), 0)
eq("容器高度：nil → 0", PI.PanelHeight(nil, 1), 0)
eq("容器高度：1 列 → 列高", PI.PanelHeight({ 8 }, 1), 8)
eq("容器高度：3 列 → 各列高加總＋2 個列距", PI.PanelHeight({ 8, 10, 6 }, 2), 28)
eq("列高：沒存 → 預設 8", PI.CustomHeight({ kind = "charges", spellID = 1 }), 8)
eq("列高：存的值", PI.CustomHeight({ height = 16 }), 16)
eq("列高：壞資料 → 預設", PI.CustomHeight({ height = "x" }), 8)
eq("列高：太小夾到下限", PI.CustomHeight({ height = 0 }), PI.HEIGHT_MIN)
eq("列高：太大夾到上限", PI.CustomHeight({ height = 99 }), PI.HEIGHT_MAX)
eq("列高：nil 項目 → 預設", PI.CustomHeight(nil), 8)
-- 每一列自己的數字（entry.text）
do
    local show, size, font, outline = PI.TextStyle({ kind = "charges", spellID = 1 }, 8)
    check("數字：充能列沒存 → 開（舊欄位 showTime 預設開）", show == true)
    eq("數字：大小沒存 → 照列高（8 → 8，下限 8）", size, 8)
    eq("數字：字型沒存 → INHERIT", font, "INHERIT")
    eq("數字：描邊沒存 → INHERIT", outline, "INHERIT")
    show = PI.TextStyle({ kind = "charges", showTime = false }, 8)
    check("數字：充能列舊欄位 showTime=false → 關", show == false)
    show = PI.TextStyle({ kind = "stacks" }, 8)
    check("數字：層數列沒存 → 關", show == false)
    show, size = PI.TextStyle({ kind = "stacks", showTime = false, text = { show = true, size = 14 } }, 8)
    check("數字：text.show 蓋過 showTime", show == true)
    eq("數字：存的大小", size, 14)
    local _, s2 = PI.TextStyle({ kind = "charges", text = { size = 0 } }, 20)
    eq("數字：大小 0 → 照列高（20−4）", s2, 16)
    local _, s3 = PI.TextStyle({ kind = "charges", text = { size = 99 } }, 8)
    eq("數字：太大夾到上限", s3, PI.TEXT_SIZE_MAX)
    local _, s4 = PI.TextStyle({ kind = "charges", text = { size = 1 } }, 8)
    eq("數字：太小夾到下限", s4, PI.TEXT_SIZE_MIN)
    local _, _, f2, o2 = PI.TextStyle({ kind = "charges", text = { font = "Arial", outline = "THICKOUTLINE" } }, 8)
    eq("數字：存的字型", f2, "Arial")
    eq("數字：存的描邊", o2, "THICKOUTLINE")
    local _, _, f3, o3 = PI.TextStyle({ kind = "charges", text = { font = "", outline = "INHERIT" } }, 8)
    eq("數字：空字型 → INHERIT", f3, "INHERIT")
    eq("數字：描邊 INHERIT 原樣", o3, "INHERIT")
    local s5 = PI.TextStyle({ kind = "charges", text = "x" }, 8)
    check("數字：text 不是表 → 當沒存", s5 == true)
    local s6 = PI.TextStyle(nil, 8)
    check("數字：nil 項目不炸", s6 == false)
end
eq("資源條不再有自訂格子的函式", R.PlanCustomRows, nil)
check("資源條預設：自訂格子是空表", type(res.customRows) == "table" and next(res.customRows) == nil)
local ccfg = { customRows = {} }
eq("沒有清單 → nil", PI.CustomRowList(ccfg, 65), nil)
eq("沒有專精 → nil", PI.CustomRowList(ccfg, nil, true), nil)
eq("設定不是表 → nil", PI.CustomRowList(nil, 65, true), nil)
eq("新增回位置", PI.AddCustomRow(ccfg, 65, { kind = "charges", spellID = 1001 }), 1)
eq("壞種類不收", PI.AddCustomRow(ccfg, 65, { kind = "cooldown", spellID = 1 }), nil)
PI.AddCustomRow(ccfg, 65, { kind = "stacks", spellID = 2002, max = 3 })
PI.AddCustomRow(ccfg, 66, { kind = "stacks", spellID = 3003 })
eq("清單依專精：神聖 2 筆", #PI.CustomRowList(ccfg, 65), 2)
eq("清單依專精：防騎 1 筆", #PI.CustomRowList(ccfg, 66), 1)
eq("清單依專精：懲戒沒有", PI.CustomRowList(ccfg, 70), nil)
eq("找重複：同種類同法術", PI.FindCustomRow(ccfg, 65, "stacks", 2002), 2)
eq("找重複：別的專精不算", PI.FindCustomRow(ccfg, 66, "stacks", 2002), nil)
eq("找重複：種類不同不算", PI.FindCustomRow(ccfg, 65, "charges", 2002), nil)

-- 規劃（probe 注入：學了沒、充能上限）
local knownC, maxC = { [1001] = true, [1002] = true }, { [1001] = 3 }
local probe = {
    known = function(id) return knownC[id] == true end,
    maxCharges = function(id) return maxC[id] end,
}
local function plan(spec) return PI.PlanCustomRows(ccfg, spec, probe) end
local pl = plan(65)
eq("神聖：兩列", #pl, 2)
eq("第一列：充能", pl[1].kind, "charges")
eq("充能上限讀得到 → 用 API 的 3", pl[1].numSeg, 3)
eq("規劃帶列高：沒存 → 預設 8", pl[1].height, 8)
eq("第二列：層數、上限 3", pl[2].numSeg, 3)
eq("規劃帶著清單位置", pl[2].index, 2)
eq("規劃帶著 entry 參照", pl[2].entry, PI.CustomRowList(ccfg, 65)[2])
eq("防騎：層數沒給上限 → 5", plan(66)[1].numSeg, 5)
eq("懲戒：沒有清單 → 空", #plan(70), 0)
-- 充能上限的退路：API 讀不到 → 存檔的 max → 2
maxC[1001] = nil
PI.CustomRowList(ccfg, 65)[1].max = 4
eq("充能上限讀不到 → 退回存檔的 max", plan(65)[1].numSeg, 4)
PI.CustomRowList(ccfg, 65)[1].max = nil
eq("兩邊都沒有 → 2", plan(65)[1].numSeg, 2)
maxC[1001] = 40
eq("充能上限夾到 30", plan(65)[1].numSeg, 30)
maxC[1001] = 0
PI.CustomRowList(ccfg, 65)[1].max = 2
eq("API 回 0 當讀不到 → 存檔的 max", plan(65)[1].numSeg, 2)
maxC[1001] = 3
-- 層數上限
local st2 = PI.CustomRowList(ccfg, 65)[2]
st2.max = 0
eq("層數上限 0 → 預設 5", plan(65)[2].numSeg, 5)
st2.max = 45
eq("層數上限夾到 30", plan(65)[2].numSeg, 30)
st2.max = 2.7
eq("層數上限取整", plan(65)[2].numSeg, 2)
st2.max = "x"
eq("層數上限不是數字 → 5", plan(65)[2].numSeg, 5)
st2.max = 3
-- enabled = false 不建列、未學會的充能法術不建列、層數列不看學了沒
PI.CustomRowList(ccfg, 65)[1].enabled = false
pl = plan(65)
eq("enabled = false：不建那一列", #pl, 1)
eq("enabled = false：剩下的是層數列、位置照舊", pl[1].index, 2)
PI.CustomRowList(ccfg, 65)[1].enabled = true
knownC[1001] = false
eq("充能法術未學會：不建", #plan(65), 1)
knownC[2002] = false
eq("層數列不看學了沒", plan(65)[1].kind, "stacks")
knownC[1001] = true
-- 壞資料：跳過、不報錯
local bad = { customRows = { [65] = { "x", { kind = "charges" }, { kind = "nope", spellID = 1 }, { kind = "stacks", spellID = 9 } } } }
pl = PI.PlanCustomRows(bad, 65, probe)
eq("壞資料跳過，剩一列", #pl, 1)
eq("壞資料跳過：位置照清單", pl[1].index, 4)
eq("customRows 不是表 → 空", #PI.PlanCustomRows({ customRows = 5 }, 65, probe), 0)
eq("不給 probe：充能照建（當學了）、上限退回存檔的 max", PI.PlanCustomRows(ccfg, 65, nil)[1].numSeg, 2)
-- 推薦清單：職業／專精過濾、已加過的跳過、用不了的靜默跳過
do
    local rcfg = {}
    local has = { [190784] = true }
    local rp = {
        exists = function(id) return id ~= 296553 end,
        known = function(id) return id ~= 358267 end,
        hasCharges = function(id) return has[id] == true end,
    }
    local function recs(cls, spec, kind) return PI.CustomRecommendations(rcfg, cls, spec, kind, rp) end
    eq("推薦：聖騎任何專精都有神性戰馬", recs("PALADIN", 65, "charges")[1].spellID, 190784)
    eq("推薦：種類不同不給", #recs("PALADIN", 65, "stacks"), 0)
    eq("推薦：沒列的職業 → 空", #recs("MAGE", 62, "charges"), 0)
    eq("推薦：術士專屬專精，痛苦 → 空", #recs("WARLOCK", 265, "stacks"), 0)
    local demo = recs("WARLOCK", 266, "stacks")
    eq("推薦：惡魔學只剩存在的那一筆", #demo, 1)
    eq("推薦：帶上限", demo[1].max, 4)
    eq("推薦：沒學會的充能法術靜默跳過", #recs("EVOKER", 1467, "charges"), 0)
    has[190784] = nil
    eq("推薦：換天賦後沒有充能 → 跳過", #recs("PALADIN", 70, "charges"), 0)
    has[190784] = true
    PI.AddCustomRow(rcfg, 70, { kind = "charges", spellID = 190784 })
    eq("推薦：這個專精已經加過 → 跳過", #recs("PALADIN", 70, "charges"), 0)
    eq("推薦：別的專精照給", #recs("PALADIN", 66, "charges"), 1)
    eq("推薦：沒有專精 → 空", #recs("PALADIN", nil, "charges"), 0)
    has[444347] = true
    eq("推薦：死亡戰騎沒給 talent 查詢 → 照給", #recs("DEATHKNIGHT", 251, "charges"), 1)
    rp.talent = function(id) return id == 444010 end
    eq("推薦：學了死亡戰騎天賦 → 給", recs("DEATHKNIGHT", 251, "charges")[1].spellID, 444347)
    rp.talent = function() return false end
    eq("推薦：沒學死亡戰騎天賦 → 不給", #recs("DEATHKNIGHT", 251, "charges"), 0)
    rp.talent = nil
    has[444347] = nil
    has[49576], has[48265] = true, true
    eq("推薦：死亡之握任何專精都給", recs("DEATHKNIGHT", 250, "charges")[1].spellID, 49576)
    eq("推薦：死神逼近只給冰霜（血魄只有死握）", #recs("DEATHKNIGHT", 250, "charges"), 1)
    local frost = recs("DEATHKNIGHT", 251, "charges")
    eq("推薦：冰霜有死握＋死神逼近", #frost, 2)
    eq("推薦：冰霜第二筆是死神逼近", frost[2].spellID, 48265)
end
-- 刪除
check("刪第 1 筆", PI.RemoveCustomRow(ccfg, 65, 1))
eq("刪掉之後剩層數列", PI.CustomRowList(ccfg, 65)[1].spellID, 2002)
check("刪不存在的位置 → false", not PI.RemoveCustomRow(ccfg, 65, 5))
PI.RemoveCustomRow(ccfg, 65, 1)
eq("清單空了就拿掉整個鍵", ccfg.customRows[65], nil)
check("防騎那份不受影響", #PI.CustomRowList(ccfg, 66) == 1)
-- 顏色：存檔的 → 職業色
ns.Style = { Accent = function() return 0.1, 0.2, 0.3, 1 end }
local cr, cg, cb2 = PI.CustomColor({ color = { r = 1, g = 0.5, b = 0 } })
check("自訂列的顏色：存檔的", cr == 1 and cg == 0.5 and cb2 == 0)
cr, cg, cb2 = PI.CustomColor({})
check("自訂列的顏色：沒存 → 職業色", cr == 0.1 and cg == 0.2 and cb2 == 0.3)
-- 取值：層數直接轉手、沒有光環 0；充能讀不到 → nil
auras[2002] = { applications = SECRET }
eq("層數：秘密值原樣轉手", (PI.CustomValue({ kind = "stacks", spellID = 2002 })), SECRET)
auras[2002] = nil
eq("層數：沒有光環 → 0", (PI.CustomValue({ kind = "stacks", spellID = 2002 })), 0)
eq("充能：API 回 nil → nil", (PI.CustomValue({ kind = "charges", spellID = 1001 })), nil)

-- 顯示時機
eq("顯示時機：沒存 → always", PI.ShowWhen({ kind = "charges", spellID = 1 }), "always")
eq("顯示時機：充能 active", PI.ShowWhen({ kind = "charges", showWhen = "active" }), "active")
eq("顯示時機：充能 activeOrCombat", PI.ShowWhen({ kind = "charges", showWhen = "activeOrCombat" }), "activeOrCombat")
eq("顯示時機：層數 active", PI.ShowWhen({ kind = "stacks", showWhen = "active" }), "active")
eq("顯示時機：層數不開放 activeOrCombat → always", PI.ShowWhen({ kind = "stacks", showWhen = "activeOrCombat" }), "always")
eq("顯示時機：壞值 → always", PI.ShowWhen({ kind = "charges", showWhen = 5 }), "always")
eq("顯示時機：不是表 → always", PI.ShowWhen(nil), "always")
local swc = { customRows = { [70] = { { kind = "charges", spellID = 1001, showWhen = "activeOrCombat" },
                                       { kind = "stacks", spellID = 2002, showWhen = "active" } } } }
local swp = PI.PlanCustomRows(swc, 70, probe)
eq("規劃帶著顯示時機（充能）", swp[1].showWhen, "activeOrCombat")
eq("規劃帶著顯示時機（層數）", swp[2].showWhen, "active")
eq("不是 always 的列照樣佔位：兩列高", PI.PanelHeight({ swp[1].height, swp[2].height }, 1), 17)
-- 充能列的透明度
eq("always：一律 base", PI.ChargeAlpha("always", false, false, 1), 1)
eq("always：讀不到值的 base 0.5", PI.ChargeAlpha("always", nil, false, 0.5), 0.5)
eq("active：回充中 → base", PI.ChargeAlpha("active", true, false, 1), 1)
eq("active：滿了 → 0", PI.ChargeAlpha("active", false, false, 1), 0)
eq("active：讀不到 isActive → nil（交給引擎）", PI.ChargeAlpha("active", nil, false, 1), nil)
eq("activeOrCombat：戰鬥中 → base", PI.ChargeAlpha("activeOrCombat", false, true, 1), 1)
eq("activeOrCombat：脫戰且滿了 → 0", PI.ChargeAlpha("activeOrCombat", false, false, 1), 0)
eq("activeOrCombat：脫戰、讀不到 → nil", PI.ChargeAlpha("activeOrCombat", nil, false, 1), nil)
-- 閘門與填色的 min／max：第 i 格「是下一格或已滿」＝ 充能數 ≥ i-1
local function fillFrac(lo, hi, v) if v <= lo then return 0 elseif v >= hi then return 1 end return (v - lo) / (hi - lo) end
for i = 1, 4 do
    local glo, ghi = PI.GateRange(i)
    local flo, fhi = PI.FillRange(i)
    eq("閘門 " .. i .. " min", glo, i - 2)
    eq("閘門 " .. i .. " max", ghi, i - 1)
    eq("填色 " .. i .. " min", flo, i - 1)
    eq("填色 " .. i .. " max", fhi, i)
    for cur = 0, 4 do
        local gate, fill = fillFrac(glo, ghi, cur), fillFrac(flo, fhi, cur)
        -- 回充看得到 ⇔ 閘門滿且這格沒被填滿 ⇔ 這格正好是下一格
        local visible = gate == 1 and fill < 1
        check(("第 %d 格、充能 %d：回充%s"):format(i, cur, visible and "看得到" or "看不到"), visible == (cur == i - 1))
    end
end
-- 充能的取值多回 isActive（明文布林）
env.C_Spell.GetSpellCharges = function(id) return { currentCharges = 1, maxCharges = 2, isActive = true } end
local _, _, act = PI.CustomValue({ kind = "charges", spellID = 1001 })
eq("充能：isActive 明文照收", act, true)
env.C_Spell.GetSpellCharges = function(id) return { currentCharges = SECRET, maxCharges = 2, isActive = SECRET } end
local cv, _, act2 = PI.CustomValue({ kind = "charges", spellID = 1001 })
eq("充能：秘密的 isActive 不收", act2, nil)
eq("充能：秘密的充能數照樣轉手", cv, SECRET)
env.C_Spell.GetSpellCharges = nil

------------------------------------------------------------
-- 8. 補齊的職業資源
------------------------------------------------------------
-- 每個新資源：有定義、有預設色、專精對照
for _, k in ipairs({ "Icicles", "DevourerFragments", "Stagger", "IgnorePain", "WhirlwindStacks", "SweepingStrikes", "Ironfur" }) do
    check("新資源有定義：" .. k, R.RESOURCES[k] ~= nil)
    check("新資源有預設色：" .. k, ns.DB.RESOURCE_COLORS[k] ~= nil and type(res.colors[k]) == "table")
    check("新資源有名字：" .. k, type(R.Name(k)) == "string" and R.Name(k) ~= "")
end
eq("法術名當資源名（C_Spell.GetSpellName）", R.Name("IgnorePain"), "S190456")
eq("醉仙緩勁用暴雪全域字串（沒有就退法術名）", R.RESOURCES.Stagger.name, "S115069")
check("醉仙緩勁三段色", type(res.colors.Stagger.moderateColor) == "table" and type(res.colors.Stagger.heavyColor) == "table")
check("醉仙緩勁門檻預設", res.staggerModerateAt == 30 and res.staggerHeavyAt == 60 and res.staggerCeiling == 100)
eq("鐵鬃沒有中度色 → 退回預設主色", R.ResolveColor(res, "Ironfur", "moderateColor"), ns.DB.RESOURCE_COLORS.Ironfur.color)
-- 段落
eq("段落：29% 輕度", R.StaggerBand(29, 30, 60), "light")
eq("段落：30% 中度", R.StaggerBand(30, 30, 60), "moderate")
eq("段落：60% 重度", R.StaggerBand(60, 30, 60), "heavy")
eq("段落：讀不到 → nil", R.StaggerBand(nil, 30, 60), nil)
eq("段落：門檻壞資料用預設", R.StaggerBand(45, "x", nil), "moderate")
-- 取值：醉仙緩勁、吸收盾 → 原始值轉手
env.UnitStagger = function() return SECRET end
env.UnitHealthMax = function() return 100000 end
env.UnitGetTotalAbsorbs = function() return 12345 end
local sc, sm = R.GetValue("Stagger")
check("醉仙緩勁：秘密值原樣轉手、上限是最大生命", sc == SECRET and sm == 100000)
local ac2, am = R.GetValue("IgnorePain")
check("吸收盾：總吸收量、上限是最大生命（不乘三成）", ac2 == 12345 and am == 100000)
env.UnitStagger, env.UnitGetTotalAbsorbs = nil, nil
eq("API 不在 → 0", (R.GetValue("Stagger")), 0)
-- 噬靈魂碎片：化身中看另一個光環、上限 40；平常 50（有天賦 35）
auras[1225789] = { applications = 17 }
local dc, dm = R.GetValue("DevourerFragments")
check("噬靈魂碎片：平常 50", dc == 17 and dm == 50)
known[1247534] = true
check("噬靈魂碎片：點了天賦 35", select(2, R.GetValue("DevourerFragments")) == 35)
known[1247534] = nil
auras[1217607] = {}
auras[1227702] = { applications = 9 }
dc, dm = R.GetValue("DevourerFragments")
check("噬靈魂碎片：化身中 40", dc == 9 and dm == 40)
auras[1217607], auras[1227702], auras[1225789] = nil, nil, nil
-- auraBar：格數（不受點數型 10 格限制）、條件規則不適用
eq("旋風斬 4 格", R.SegmentsFor("WhirlwindStacks"), 4)
eq("橫掃攻擊：沒天賦 12 格", R.SegmentsFor("SweepingStrikes"), 12)
known[1261049] = true
eq("橫掃攻擊：點了天賦 18 格", R.SegmentsFor("SweepingStrikes"), 18)
known[1261049] = nil
eq("鐵鬃 5 格", R.SegmentsFor("Ironfur"), 5)
eq("冰刺 5 格", R.SegmentsFor("Icicles"), 5)
eq("醉仙緩勁是連續條", R.SegmentsFor("Stagger"), 0)
check("條件規則：引擎寫的列不適用", not R.SupportsConditions("WhirlwindStacks") and not R.SupportsConditions("Ironfur"))
check("條件規則：醉仙緩勁、冰刺適用", R.SupportsConditions("Stagger") and R.SupportsConditions("Icicles"))
check("條件規則：無視苦痛改引擎寫 ⇒ 不適用", not R.SupportsConditions("IgnorePain") and R.EngineDriven("IgnorePain"))
eq("auraBar 的明文退路：讀第一個光環的層數", (R.GetValue("WhirlwindStacks")), 0)
auras[85739] = { applications = 3 }
eq("auraBar 的明文退路：有層數", (R.GetValue("WhirlwindStacks")), 3)
auras[85739] = nil
-- 天賦閘：光環／取值型看被動；醉仙緩勁沒學 → 隱藏
check("鐵鬃看被動 192081", R.RESOURCES.Ironfur.passive == 192081 and R.RESOURCES.Ironfur.instances == true)

-- AuraBar 的純函式（Modules/AuraBar.lua）
ns.Events = ns.Events or { Register = function() end }
Load("Modules/AuraBar.lua")
local AB = ns.AuraBar
local g = AB.Geometry(100, 4, 2)
eq("幾何：4 格", #g.cells, 4)
eq("幾何：格寬", g.cells[1].w, 23.5)
eq("幾何：第 2 格 x", g.cells[2].x, 25.5)
eq("幾何：3 個分隔", #g.gaps, 3)
eq("幾何：分隔在格子右邊", g.gaps[1].x, 23.5)
eq("幾何：格距 0 沒有分隔", #AB.Geometry(100, 4, 0).gaps, 0)
do
    -- 一格一框的分段：格距 0 ⇒ 相鄰兩格重疊 1px 共用一條邊，總寬不變
    local savedP = ns.P
    ns.P = { Scale = function(v) return v end }      -- 1 單位 ＝ 1 實體像素
    -- 每一格：左緣、寬都是整數像素；第一格從 0 起、最後一格右緣剛好落在 W；相鄰兩格的距離＝格距
    local function cells(W, n, sp)
        local ok, prevRight = true, nil
        local x1, w1 = R.SegCell(W, n, sp, 1)
        local xn, wn = R.SegCell(W, n, sp, n)
        for i = 1, n do
            local x, w = R.SegCell(W, n, sp, i)
            if x % 1 ~= 0 or w % 1 ~= 0 or w <= 0 then ok = false end
            local want = (sp or 1) <= 0 and -1 or sp
            if prevRight and x - prevRight ~= want then ok = false end
            prevRight = x + w
        end
        return ok, x1, xn + wn
    end
    -- 玩家回報那一幕：335px、6 格、格距 0（原本每格 57 ⇒ 總寬 337）
    local ok, left, right = cells(335, 6, 0)
    check("分段：335/6 格距 0 每格整數像素、相鄰共用 1px", ok)
    eq("分段：335/6 從 0 起", left, 0)
    eq("分段：335/6 右緣剛好 335", right, 335)
    for _, c in ipairs({ { 100, 4, 0 }, { 100, 4, 2 }, { 200, 5, 1 }, { 214, 6, 0 }, { 199, 7, 3 }, { 120, 3, 0 } }) do
        local ok2, l2, r2 = cells(c[1], c[2], c[3])
        check(("分段：%d/%d 格距 %d 間距一致"):format(c[1], c[2], c[3]), ok2)
        eq(("分段：%d/%d 格距 %d 右緣"):format(c[1], c[2], c[3]), r2, c[1])
        eq(("分段：%d/%d 格距 %d 左緣"):format(c[1], c[2], c[3]), l2, 0)
    end
    -- 格寬最多差 1px（零頭平均分）
    local minW, maxW = math.huge, 0
    for i = 1, 6 do local _, w = R.SegCell(335, 6, 0, i); minW = math.min(minW, w); maxW = math.max(maxW, w) end
    check("分段：格寬最多差 1px", maxW - minW <= 1, minW .. "～" .. maxW)
    ns.P = savedP
end
-- 整列寬的填色，第 k 層的終點落在第 k 個分隔裡（被分隔蓋住，看起來還是一格一格）
for k = 1, 3 do
    local fillEnd = 100 * k / 4
    local gp = g.gaps[k]
    check(("第 %d 層的填色終點落在第 %d 個分隔裡"):format(k, k), fillEnd >= gp.x and fillEnd <= gp.x + gp.w)
end
local base = { spellIDs = { 2, 1 }, max = 4, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1 }
local sigA = AB.Signature(base)
eq("簽章：法術順序不影響", AB.Signature({ spellIDs = { 1, 2 }, max = 4, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1 }), sigA)
check("簽章：換色就換", AB.Signature({ spellIDs = { 1, 2 }, max = 4, texture = "t", color = { r = 0, g = 1, b = 0 }, alpha = 1 }) ~= sigA)
check("簽章：上限進簽章", AB.Signature({ spellIDs = { 1, 2 }, max = 5, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1 }) ~= sigA)
check("簽章：有光環才顯示（裝飾在子樹裡）進簽章", AB.Signature({ spellIDs = { 1, 2 }, max = 4, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1,
    inside = { W = 100, H = 8, n = 4, gap = 1, segW = 24, segments = true, dim = { 0, 0, 0, 1 }, px = 1 } }) ~= sigA)
check("簽章：instances 與 applications 不同", AB.Signature({ kind = "instances", spellIDs = { 1, 2 }, max = 4, texture = "t",
    color = { r = 1, g = 0, b = 0 }, alpha = 1, cell = { segW = 24, H = 8, gap = 1 } }) ~= sigA)

------------------------------------------------------------
-- 9. 光環剩餘時間條（auraTimer）
------------------------------------------------------------
-- 專精對照
eqList("增輝：精華＋黯黑力量＋法力", R.RawList("EVOKER", 1473, nil), { "Essence", "EbonMight", "Mana" })
eqList("湮滅：沒有黯黑力量", R.RawList("EVOKER", 1467, nil), { "Essence", "Mana" })
eqList("火法：沒有秘法靈魂", R.RawList("MAGE", 63, nil), { "Mana" })
-- 定義、預設色、名字（光環的法術名）
for _, k in ipairs({ "EbonMight", "ArcaneSoul" }) do
    check("剩餘時間條有定義：" .. k, R.RESOURCES[k] ~= nil and R.RESOURCES[k].mode == "auraTimer")
    check("剩餘時間條有預設色：" .. k, ns.DB.RESOURCE_COLORS[k] ~= nil and type(res.colors[k]) == "table")
    check("剩餘時間條是引擎寫的：" .. k, R.EngineDriven(k))
    check("剩餘時間條不支援條件規則：" .. k, not R.SupportsConditions(k))
    eq("剩餘時間條不是格子：" .. k, R.SegmentsFor(k), 0)
end
eq("黯黑力量的名字＝光環 395296 的法術名", R.Name("EbonMight"), "S395296")
eq("秘法靈魂的名字＝光環 451038 的法術名", R.Name("ArcaneSoul"), "S451038")
eqList("黯黑力量追蹤身上的增益 395296", R.RESOURCES.EbonMight.auras, { 395296 })
eqList("秘法靈魂追蹤 451038（＋11.1 的同名 ID）", R.RESOURCES.ArcaneSoul.auras, { 451038, 1223522 })
check("條件規則候選不含剩餘時間條", not R.SupportsConditions("EbonMight") and R.SupportsConditions("Essence"))
-- Lua 不讀值：光環在身上也回 0, 0（剩餘時間只在引擎那邊）
auras[395296] = { applications = 1, expirationTime = 123 }
local tc, tm = R.GetValue("EbonMight")
check("剩餘時間條 GetValue 不讀光環", tc == 0 and tm == 0)
auras[395296] = nil
-- 畫法規劃
eq("auraTimer 容器就緒 → engine", R.DrawMode("auraTimer", true), "engine")
eq("auraTimer 容器沒好 → 空條", R.DrawMode("auraTimer", false), "timerIdle")
eq("auraBar 容器就緒 → engine", R.DrawMode("auraBar", true), "engine")
eq("auraBar 容器沒好 → 明文點數", R.DrawMode("auraBar", false), "pip")
eq("連續條不變", R.DrawMode("bar", false), "bar")
eq("點數型不變", R.DrawMode("pip", true), "pip")
-- 空條底色：主色 × 0.25、alpha 0.8；給 out 就填進去（不配新表）
local out = {}
local d = R.TimerDim({ r = 0.8, g = 0.4, b = 1 }, out)
check("空條底色", d == out and d[1] == 0.2 and d[2] == 0.1 and d[3] == 0.25 and d[4] == 0.8)
-- 天賦閘：黯黑力量看 395152；秘法靈魂看歐爾的記憶 449619 或英雄樹 39（Sunfury）
ns.specID = 1473
powerMax[19], powerMax[0] = 5, 100000
known[395152] = nil
R.Invalidate()
eqList("增輝：沒學黯黑力量 → 不列", (R.Candidates()), { "Essence", "Mana", "Health" })
known[395152] = true
R.Invalidate()
eqList("增輝：學了 → 列", (R.Candidates()), { "Essence", "EbonMight", "Mana", "Health" })
known[395152] = nil
ns.specID = 62
powerMax[16] = 4
R.Invalidate()
eqList("秘法：沒點 Sunfury → 不列", (R.Candidates()), { "ArcaneCharges", "Mana", "Health" })
check("秘法靈魂沒列的原因有記", type(R.gateLog.ArcaneSoul) == "string")
known[449619] = true
R.Invalidate()
eqList("秘法：點了歐爾的記憶 → 列", (R.Candidates()), { "ArcaneCharges", "ArcaneSoul", "Mana", "Health" })
known[449619] = nil
local hero = 40
env.C_ClassTalents = { GetActiveHeroTalentSpec = function() return hero end }
R.Invalidate()
eqList("秘法：英雄樹是別棵 → 不列", (R.Candidates()), { "ArcaneCharges", "Mana", "Health" })
hero = 39
R.Invalidate()
eqList("秘法：英雄樹是 Sunfury → 列", (R.Candidates()), { "ArcaneCharges", "ArcaneSoul", "Mana", "Health" })
hero = SECRET
R.Invalidate()
eqList("秘法：英雄樹讀不到 → 不列（不比較秘密值）", (R.Candidates()), { "ArcaneCharges", "Mana", "Health" })
env.C_ClassTalents = nil
R.Invalidate()
-- duration 簽章（Modules/AuraBar.lua）
local dur = { kind = "duration", spellIDs = { 395296 }, max = 1, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1 }
local sigD = AB.Signature(dur)
check("簽章：duration 與 applications 不同", sigD ~= AB.Signature({ spellIDs = { 395296 }, max = 1, texture = "t",
    color = { r = 1, g = 0, b = 0 }, alpha = 1 }))
local withText = { kind = "duration", spellIDs = { 395296 }, max = 1, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1,
    text = { font = "f", size = 10, decimals = 5 } }
check("簽章：秒數文字開關進簽章", AB.Signature(withText) ~= sigD)
withText.text.size = 12
local sig12 = AB.Signature(withText)
withText.text.size = 10
check("簽章：字級進簽章", sig12 ~= AB.Signature(withText))
check("簽章：填充方向進簽章", AB.Signature({ kind = "duration", spellIDs = { 395296 }, max = 1, texture = "t",
    color = { r = 1, g = 0, b = 0 }, alpha = 1, reversed = true }) ~= sigD)
check("簽章：文字只算在 duration 上", AB.Signature({ spellIDs = { 1 }, max = 4, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1,
    text = { font = "f", size = 10, decimals = 5 } }) == AB.Signature({ spellIDs = { 1 }, max = 4, texture = "t",
    color = { r = 1, g = 0, b = 0 }, alpha = 1 }))

-- ⚠ 放最後：ResetProfile 會原地清空整份設定檔，前面的測試抓著它的子表
do
    -- 恢復預設（設定檔頁）：自己加的規則清掉、刪掉的預設規則回來
    local r0 = ns.profile.resources
    r0.conditions.ComboPoints = { { check = { var = "powerValue", cmp = ">=", value = 4 }, overrides = { color = { r = 1, g = 0, b = 0, a = 1 } } } }
    r0.conditions.HolyPower = nil
    ns.DB.ResetProfile()
    local c = ns.profile.resources.conditions
    check("設定檔恢復預設：自己加的連擊點規則清掉", c.ComboPoints == nil)
    check("設定檔恢復預設：聖能預設規則回來", type(c.HolyPower) == "table" and #c.HolyPower == 2)
    check("設定檔恢復預設：氣旋武器預設規則回來", type(c.MaelstromWeapon) == "table" and #c.MaelstromWeapon == 2)
    -- 資源條頁的恢復預設（Options/Tab_Resources.lua 的 ResetAll：原地清空再 MergeDefaults）
    local cfg = ns.DB.ConfigTable("resources")
    cfg.conditions = { ComboPoints = { { check = { var = "always" }, overrides = { alpha = 0.5 } } } }
    for k in pairs(cfg) do cfg[k] = nil end
    ns.DB.MergeDefaults(cfg, ns.DB.BuildDefaults().profile.resources)
    check("資源條頁恢復預設：自己加的規則清掉", cfg.conditions.ComboPoints == nil)
    check("資源條頁恢復預設：預設規則回來", #cfg.conditions.HolyPower == 2 and #cfg.conditions.MaelstromWeapon == 2)
end

------------------------------------------------------------
-- 10. 符文排序與秒數（R.RuneOrder／R.RuneSeconds）
------------------------------------------------------------
do
    -- 截圖那一幕：3、6 在轉，其餘轉好 ⇒ 轉好的照編號靠左，在轉的依剩餘時間
    local ready = { true, true, false, true, true, false }
    local remain = { nil, nil, 7.2, nil, nil, 2.1 }
    eqList("符文：轉好靠左、在轉依剩餘時間", R.RuneOrder(ready, remain, 6), { 1, 2, 4, 5, 6, 3 })
    -- 全部在轉：短的先；讀不到剩餘的排最後；同分照編號
    ready = { false, false, false, false, false, false }
    remain = { 9, nil, 3, 9, 1, 3 }
    eqList("符文：全部在轉、讀不到的墊底、同分照編號", R.RuneOrder(ready, remain, 6), { 5, 3, 6, 1, 4, 2 })
    -- 全部轉好：照編號
    ready = { true, true, true, true, true, true }
    eqList("符文：全部轉好", R.RuneOrder(ready, {}, 6), { 1, 2, 3, 4, 5, 6 })
    -- 重用 order 表：格數變少時尾巴清掉
    local order = { 9, 9, 9, 9, 9, 9, 9 }
    eqList("符文：重用表、尾巴清掉", R.RuneOrder({ false, true }, { 4 }, 2, order), { 2, 1 })
    eq("秒數：無條件進位", R.RuneSeconds(2.1, false, true), 3)
    eq("秒數：剛好整數", R.RuneSeconds(4, false, false), 4)
    eq("秒數：排隊中、開＝印總等待時間", R.RuneSeconds(17.3, true, true), 18)
    eq("秒數：排隊中、關＝不印", R.RuneSeconds(17.3, true, false), nil)
    eq("秒數：讀不到不印", R.RuneSeconds(nil, false, true), nil)
    eq("秒數：轉完不印", R.RuneSeconds(0, false, true), nil)
    -- 填充：冷卻 8 秒；第 100 秒花掉，排在前一顆後面、第 104 秒才開始轉 ⇒ 第 112 秒轉好
    eq("填充：關、排隊中＝0", R.RuneProgress(102, 104, 8, 100, false), 0)
    eq("填充：關、在轉照自己那段", R.RuneProgress(108, 104, 8, 100, false), 0.5)
    eq("填充：開、排隊中照整段等待", R.RuneProgress(102, 104, 8, 100, true), 2 / 12)
    eq("填充：開、轉起來接著走不跳回 0", R.RuneProgress(106, 104, 8, 100, true), 0.5)
    eq("填充：開、花掉就開始轉＝跟關一樣", R.RuneProgress(106, 104, 8, 104.02, true), 0.25)
    eq("填充：開、沒記到花掉時間退回自己那段", R.RuneProgress(106, 104, 8, nil, true), 0.25)
    eq("填充：超過上限夾 1", R.RuneProgress(200, 104, 8, 100, true), 1)
    eq("預設：排隊中的符文也算", ns.DB.BuildDefaults().profile.resources.runeQueued, true)
    eq("預設：符文列印秒數", ns.DB.BuildDefaults().profile.resources.runeText, "countdown")
    eq("符文數字：沒設＝秒數", R.RuneText({}), "countdown")
    eq("符文數字：壞值＝秒數", R.RuneText({ runeText = "bogus" }), "countdown")
    eq("符文數字：顆數", R.RuneText({ runeText = "count" }), "count")
    eq("符文數字：舊的 none 退回秒數", R.RuneText({ runeText = "none" }), "countdown")
end

------------------------------------------------------------
-- 11. 列的順序（R.ApplyOrder／R.MergeOrder）、血量列（Health）、施法條的暴雪材質
------------------------------------------------------------
do
    -- 排序：在 order 裡的照位置；不在的維持原順序、排在後面
    eqList("排序：沒有 order 照原樣", R.ApplyOrder({ "A", "B", "C" }, nil), { "A", "B", "C" })
    eqList("排序：空 order 照原樣", R.ApplyOrder({ "A", "B", "C" }, {}), { "A", "B", "C" })
    eqList("排序：全部排過", R.ApplyOrder({ "A", "B", "C" }, { "C", "A", "B" }), { "C", "A", "B" })
    eqList("排序：沒排過的接在後面、維持原順序", R.ApplyOrder({ "A", "B", "C", "D" }, { "C" }), { "C", "A", "B", "D" })
    eqList("排序：order 裡別的專精的 key 不影響", R.ApplyOrder({ "A", "B" }, { "X", "B", "Y" }), { "B", "A" })
    eqList("排序：order 裡重複的只認第一次", R.ApplyOrder({ "A", "B" }, { "B", "A", "B" }), { "B", "A" })
    local src = { "A", "B" }
    local out = R.ApplyOrder(src, { "B" })
    check("排序：回新表、原表不動", out ~= src and list(src) == "A,B")
    eqList("排序：清單是空的", R.ApplyOrder({}, { "A" }), {})
    -- 寫回：這個專精的完整順序在前、舊的別專精 key 照原相對位置接在後面
    eqList("寫回：沒有舊的", R.MergeOrder(nil, { "B", "A" }), { "B", "A" })
    eqList("寫回：保留別的專精的 key", R.MergeOrder({ "X", "A", "Y", "B" }, { "B", "A" }), { "B", "A", "X", "Y" })
    eqList("寫回：壞資料跳過", R.MergeOrder({ 3, "X", false }, { "A" }), { "A", "X" })
    -- 往返：寫回之後再排一次，跟玩家看到的一樣
    local merged = R.MergeOrder({ "Energy", "Rage" }, { "Mana", "HolyPower", "Health" })
    eqList("往返：排出來跟寫回的一樣", R.ApplyOrder({ "HolyPower", "Mana", "Health" }, merged), { "Mana", "HolyPower", "Health" })

    -- 血量：每個專精都是候選、預設關、不支援條件規則
    check("血量：有定義", R.RESOURCES.Health ~= nil and R.RESOURCES.Health.mode == "bar" and R.RESOURCES.Health.health == true)
    check("血量：有預設色（綠）", ns.DB.RESOURCE_COLORS.Health and ns.DB.RESOURCE_COLORS.Health.color.g == 0.8)
    check("血量：每個專精都預設關", R.DefaultOn(65, "Health") == false and R.DefaultOn(263, "Health") == false
        and R.DefaultOn(nil, "Health") == false)
    check("血量：玩家勾了就開", R.RowOn({ rows = { [65] = { Health = true } } }, 65, "Health") == true)
    check("血量：條件規則不適用", R.SupportsConditions("Health") == false and R.SupportsConditions("Mana") == true)
    check("血量：不在 RawList", not list(R.RawList("PALADIN", 65, nil)):find("Health"))
    -- 取值：原始值原樣轉手（秘密值）
    env.UnitHealth = function() return SECRET end
    env.UnitHealthMax = function() return SECRET end
    local c, m = R.GetValue("Health")
    check("血量：取值轉手秘密值", c == SECRET and m == SECRET)
    env.UnitHealth, env.UnitHealthMax = nil, nil

    -- Candidates 套 order（設定檔在第 4 節已建好）
    local res = ns.profile.resources
    check("預設：order 是空表", type(ns.DB.BuildDefaults().profile.resources.order) == "table"
        and next(ns.DB.BuildDefaults().profile.resources.order) == nil)
    local d = ns.DB.BuildDefaults().profile.resources
    check("預設：血量用職業色、不印百分比、門檻關、門檻空", d.healthClassColor == true and d.healthPercent == false
        and d.healthThresholdEnabled == false and type(d.healthThresholds) == "table" and #d.healthThresholds == 0)
    ns.specID = 65
    powerMax[9], powerMax[0] = 5, 100000
    res.order = { "Health", "Mana" }
    R.Invalidate()
    eqList("候選：照 order 排", (R.Candidates()), { "Health", "Mana", "HolyPower" })
    res.order = {}
    R.Invalidate()
    eqList("候選：order 空 ＝ 法力、血量在最下面", (R.Candidates()), { "HolyPower", "Mana", "Health" })
    ns.specID = nil
    R.Invalidate()
    eqList("候選：沒有專精不列血量", (R.Candidates()), {})
    ns.specID = 65
    R.Invalidate()

    -- 門檻曲線的點：由低到高、0 吃最低門檻的色、最高門檻吃底色；x 是 0～1
    local base = { r = 0.1, g = 0.2, b = 0.3 }
    local red, orange = { r = 1, g = 0, b = 0 }, { r = 1, g = 0.5, b = 0 }
    local pts = R.HealthCurvePoints({ { pct = 50, color = orange }, { pct = 20, color = red } }, base)
    eq("曲線：點數 ＝ 門檻數 + 1", pts and #pts, 3)
    check("曲線：0 吃最低門檻（紅）", pts[1][1] == 0 and pts[1][2] == 1 and pts[1][3] == 0)
    check("曲線：20% 的點吃下一個門檻（橘）", pts[2][1] == 0.2 and pts[2][3] == 0.5)
    check("曲線：50% 的點吃底色", pts[3][1] == 0.5 and pts[3][2] == 0.1 and pts[3][4] == 0.3)
    local cfgList = { { pct = 50, color = orange }, { pct = 20, color = red } }
    R.HealthCurvePoints(cfgList, base)
    check("曲線：設定表的順序不動", cfgList[1].pct == 50)
    eq("曲線：沒有門檻 ＝ nil", R.HealthCurvePoints({}, base), nil)
    eq("曲線：門檻不是表 ＝ nil", R.HealthCurvePoints(nil, base), nil)
    eq("曲線：底色壞了 ＝ nil", R.HealthCurvePoints(cfgList, nil), nil)
    pts = R.HealthCurvePoints({ { pct = 0, color = red }, { pct = 150, color = orange }, { pct = 30 }, "bad" }, base)
    check("曲線：百分比夾在 1～99、壞資料跳過", pts and #pts == 3 and pts[2][1] == 0.01 and pts[3][1] == 0.99)
    local many = {}
    for i = 1, 9 do many[i] = { pct = i * 10, color = red } end
    eq("曲線：最多 6 個門檻", #R.HealthCurvePoints(many, base), R.HEALTH_MAX_THRESHOLDS + 1)
    check("曲線簽章：同內容同簽章、不同內容不同",
        R.HealthCurveSig(R.HealthCurvePoints(cfgList, base)) == R.HealthCurveSig(R.HealthCurvePoints(cfgList, base))
        and R.HealthCurveSig(R.HealthCurvePoints(cfgList, base)) ~= R.HealthCurveSig(R.HealthCurvePoints(cfgList, red)))

    -- 施法條：暴雪材質走圖集、其他走路徑
    local path, atlas = CB.FillTexture("blizzard")
    check("施法條：暴雪材質是圖集", path == nil and atlas == "UI-CastingBar-Filling-Standard")
    eq("施法條：暴雪材質的 token", CB.BLIZZARD_TEXTURE, "blizzard")
end

------------------------------------------------------------
-- 12. 2026-10-02 補齊
------------------------------------------------------------
do
    -- 1. 毀滅術碎片零頭
    eq("碎片：只有毀滅術讀零頭", R.RESOURCES.SoulShards.fractionalSpec, 267)
    eq("碎片：每顆單位 ＝ 原始上限 ／ 整顆上限", R.ShardPer(50, 5), 10)
    eq("碎片：其他比例照算", R.ShardPer(30, 5), 6)
    eq("碎片：秘密值 ⇒ 10", R.ShardPer(SECRET, 5), 10)
    eq("碎片：上限 0 ⇒ 10", R.ShardPer(0, 0), 10)
    local w, part, v = R.ShardSplit(37, 10, 5)
    check("碎片 3.7：整顆 3、第 4 格在累積", w == 3 and part == 4 and math.abs(v - 3.7) < 1e-9)
    eq("碎片 3.7：文字一位小數", ("%.1f"):format(v), "3.7")
    w, part = R.ShardSplit(30, 10, 5)
    check("碎片剛好整顆：沒有累積中的格", w == 3 and part == nil)
    w, part = R.ShardSplit(50, 10, 5)
    check("碎片滿了：沒有累積中的格", w == 5 and part == nil)
    w, part = R.ShardSplit(3, 10, 5)
    check("碎片不到一顆：第 1 格在累積", w == 0 and part == 1)
    eq("碎片：讀不到 ⇒ nil", R.ShardSplit(nil, 10, 5), nil)
    -- 第 i 格的 min／max ＝ (i-1)·per ～ i·per：原始值 37 ⇒ 1～3 格滿、第 4 格七成、第 5 格空
    local function frac(lo, hi, x) if x <= lo then return 0 elseif x >= hi then return 1 end return (x - lo) / (hi - lo) end
    check("碎片：分格的填充", frac(0, 10, 37) == 1 and frac(20, 30, 37) == 1 and math.abs(frac(30, 40, 37) - 0.7) < 1e-9
        and frac(40, 50, 37) == 0)

    -- 2. 精華回充
    eq("精華：特殊填充", R.RESOURCES.Essence.fill, "essence")
    eq("精華：UnitPartialPower 500 ⇒ 0.5", R.EssenceFrac(500, nil, nil), 0.5)
    eq("精華：partial 優先於速度", R.EssenceFrac(250, 0.2, 4), 0.25)
    eq("精華：partial 0 ⇒ 改用速度 × 秒數", R.EssenceFrac(0, 0.2, 2.5), 0.5)
    eq("精華：超過 1 夾在 0.999", R.EssenceFrac(nil, 0.2, 10), 0.999)
    eq("精華：兩者都沒有 ⇒ 不畫", R.EssenceFrac(nil, nil, 1), nil)
    eq("精華：速度 0 ⇒ 不畫", R.EssenceFrac(0, 0, 1), nil)
    eq("精華：秒數是負的 ⇒ 不畫", R.EssenceFrac(nil, 0.2, -1), nil)
    -- 2 顆 ＋ 0.5 ⇒ 第 3 格（min 2、max 3）填一半、第 1～2 格滿
    check("精華：值 ＝ 顆數 ＋ 進度", frac(2, 3, 2.5) == 0.5 and frac(1, 2, 2.5) == 1 and frac(3, 4, 2.5) == 0)

    -- 3. 無視苦痛：引擎寫百分比、退路是吸收盾總量
    local ip = R.RESOURCES.IgnorePain
    check("無視苦痛：auraPct、追蹤 190456、上限 100", ip.mode == "auraPct" and ip.auras[1] == 190456 and #ip.auras == 1 and ip.appMax == 100)
    eq("無視苦痛：容器就緒 ⇒ engine", R.DrawMode("auraPct", true), "engine")
    eq("無視苦痛：容器沒好 ⇒ 吸收盾總量", R.DrawMode("auraPct", false), "absorbBar")
    eq("無視苦痛：不是格子", R.SegmentsFor("IgnorePain"), 0)
    env.UnitGetTotalAbsorbs = function() return 777 end
    env.UnitHealthMax = function() return 1000 end
    local a1, a2 = R.GetValue("IgnorePain")
    check("無視苦痛：退路的取值照舊（總吸收量、最大生命）", a1 == 777 and a2 == 1000)
    env.UnitGetTotalAbsorbs, env.UnitHealthMax = nil, nil
    local apps = { spellIDs = { 190456 }, max = 100, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1 }
    local sigNo = AB.Signature(apps)
    apps.count = { font = "f", size = 10, suffix = "%" }
    local sigCnt = AB.Signature(apps)
    check("簽章：層數文字進簽章", sigCnt ~= sigNo)
    apps.count.size = 12
    check("簽章：層數文字的字級進簽章", AB.Signature(apps) ~= sigCnt)
    check("簽章：層數文字只算在 applications 上", AB.Signature({ kind = "duration", spellIDs = { 1 }, max = 1, texture = "t",
        color = { r = 1, g = 0, b = 0 }, alpha = 1, count = { font = "f", size = 10, suffix = "%" } })
        == AB.Signature({ kind = "duration", spellIDs = { 1 }, max = 1, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1 }))

    -- 4a. 氣漩武器摺疊
    local cfgR = ns.DB.ConfigTable("resources")
    eq("摺疊預設關", cfgR.maelstromFold, false)
    check("摺疊：只有可摺的列", R.Folded({ maelstromFold = true }, "MaelstromWeapon") and not R.Folded({ maelstromFold = true }, "HolyPower")
        and not R.Folded({ maelstromFold = false }, "MaelstromWeapon") and not R.Folded(nil, "MaelstromWeapon"))
    eq("摺疊關：10 格", R.SegmentsFor("MaelstromWeapon"), 10)
    cfgR.maelstromFold = true
    eq("摺疊開：5 格", R.SegmentsFor("MaelstromWeapon"), 5)
    cfgR.maelstromFold = false
    local lo, hi = R.FoldRange(1, 1)
    check("摺疊：第 1 格底層 0～1", lo == 0 and hi == 1)
    lo, hi = R.FoldRange(1, 2)
    check("摺疊：第 1 格上層 5～6", lo == 5 and hi == 6)
    lo, hi = R.FoldRange(5, 2)
    check("摺疊：第 5 格上層 9～10", lo == 9 and hi == 10)
    -- 7 層：底層 5 格全滿、上層第 1、2 格滿、第 3 格空
    local ok7 = true
    for i = 1, 5 do
        local bl, bh = R.FoldRange(i, 1)
        local tl, th = R.FoldRange(i, 2)
        if frac(bl, bh, 7) ~= 1 then ok7 = false end
        if frac(tl, th, 7) ~= ((i <= 2) and 1 or 0) then ok7 = false end
    end
    check("摺疊：7 層 ＝ 底層全滿＋上層兩格", ok7)
    local oc = ns.DB.RESOURCE_COLORS.MaelstromWeapon
    check("摺疊：溢出色有預設、跟主色不同", type(oc.overflowColor) == "table" and (oc.overflowColor.r ~= oc.color.r or oc.overflowColor.b ~= oc.color.b))
    check("摺疊：設定檔帶著溢出色", type(cfgR.colors.MaelstromWeapon.overflowColor) == "table")

    -- 4b. 醉仙緩勁 4 段
    eq("4 段：95% 第 3 段", R.StaggerBand(95, 30, 60, 90, 150), "tier3")
    eq("4 段：160% 第 4 段", R.StaggerBand(160, 30, 60, 90, 150), "tier4")
    eq("4 段：關著 ⇒ 重度", R.StaggerBand(160, 30, 60, nil, nil), "heavy")
    eq("4 段：只開第 4 段、100% ⇒ 重度", R.StaggerBand(100, 30, 60, nil, 150), "heavy")
    eq("4 段：只開第 4 段、155% ⇒ 第 4 段", R.StaggerBand(155, 30, 60, nil, 150), "tier4")
    eq("4 段：中度照舊", R.StaggerBand(45, 30, 60, 90, 150), "moderate")
    local t3, t4 = R.StaggerTiers({})
    check("4 段：預設關", t3 == nil and t4 == nil)
    t3, t4 = R.StaggerTiers({ staggerTier3Enabled = true })
    check("4 段：開第 3 段、門檻沒存 ⇒ 90", t3 == 90 and t4 == nil)
    t3, t4 = R.StaggerTiers({ staggerTier4Enabled = true, staggerTier4At = 200 })
    check("4 段：開第 4 段", t3 == nil and t4 == 200)
    eq("4 段：顏色欄位", R.STAGGER_FIELD.tier3 .. "/" .. R.STAGGER_FIELD.tier4, "tier3Color/tier4Color")
    local sc = ns.DB.RESOURCE_COLORS.Stagger
    check("4 段：預設色", sc.tier3Color.r == 1 and sc.tier3Color.g == 0.2 and sc.tier3Color.b == 0.8
        and sc.tier4Color.r == 0.75 and sc.tier4Color.b == 1)
    check("4 段：預設門檻與開關", cfgR.staggerTier3At == 90 and cfgR.staggerTier4At == 150
        and cfgR.staggerTier3Enabled == false and cfgR.staggerTier4Enabled == false)
    eq("滿條上限：可以超過 100", R.StaggerCeiling({ staggerCeiling = 250 }), 250)
    eq("滿條上限：最多 300", R.StaggerCeiling({ staggerCeiling = 999 }), 300)
    eq("滿條上限：最少 1", R.StaggerCeiling({ staggerCeiling = 0 }), 1)
    eq("滿條上限：沒存 100", R.StaggerCeiling({}), 100)
    eq("4 段：標籤寫門檻", R.StaggerLabel("tier3", { staggerTier3At = 95 }), "At least 95%")
    eq("4 段：標籤門檻沒存用預設", R.StaggerLabel("tier4", {}), "At least 150%")
    eq("中度標籤照舊用減益名", R.StaggerLabel("moderate"), "S124274")

    -- 4c. 秘法靈魂剩幾個 GCD
    check("秘法靈魂：可以印 GCD", R.RESOURCES.ArcaneSoul.gcdText == true)
    eq("秘法靈魂文字：預設秒數", R.ArcaneSoulText({}), "seconds")
    eq("秘法靈魂文字：gcd", R.ArcaneSoulText({ arcaneSoulText = "gcd" }), "gcd")
    eq("秘法靈魂文字：壞值 ⇒ 秒數", R.ArcaneSoulText({ arcaneSoulText = "x" }), "seconds")
    eq("預設：秘法靈魂印秒數", cfgR.arcaneSoulText, "seconds")
    local function near(a, b) return math.abs(a - b) < 1e-9 end
    check("GCD：正在 GCD 用 duration", near(R.GcdLength(1.2, nil, nil), 1.2))
    check("GCD：不在 GCD ⇒ 加速 20% ⇒ 1.25", near(R.GcdLength(0, 20, nil), 1.25))
    check("GCD：都讀不到 ⇒ 1.5", near(R.GcdLength(nil, nil, nil), 1.5))
    check("GCD：都讀不到 ⇒ 上次的", near(R.GcdLength(nil, nil, 1.1), 1.1))
    check("GCD：下限 0.75", near(R.GcdLength(nil, 200, nil), 0.75))
    check("GCD：四捨五入到 0.05", near(R.GcdLength(0.93, nil, nil), 0.95))
    env.C_Spell.GetSpellCooldown = function(id) return id == 61304 and { duration = SECRET } or nil end
    env.UnitSpellHaste = function() return 50 end
    check("ReadGcd：duration 秘密 ⇒ 用加速", near(R.ReadGcd(), 1.0))
    env.UnitSpellHaste = function() return SECRET end
    check("ReadGcd：加速也秘密 ⇒ 上次的", near(R.ReadGcd(), 1.0))
    env.C_Spell.GetSpellCooldown = function() return { duration = 1.3 } end
    check("ReadGcd：正在 GCD", near(R.ReadGcd(), 1.3))
    env.C_Spell.GetSpellCooldown, env.UnitSpellHaste = nil, nil
    -- 格式器：一個 GCD 一段（Core/Text.lua）。暴雪的格式器 stub 成「把規則記下來」，再照文件的語意求值
    env.C_StringUtil = { CreateNumericRuleFormatter = function()
        local f = { rules = {} }
        function f:AddBreakpoint(rule) self.rules[#self.rules + 1] = rule end
        return f
    end }
    env.Enum.NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 }
    Load("Core/Text.lua")
    local fmt = ns.Text.GcdFormatter(1.5, "Last")
    check("格式器：建得起來", type(fmt) == "table" and #fmt.rules == 2)
    local function show(f, x)
        local rule
        for _, r in ipairs(f.rules) do if x >= r.threshold then rule = r end end
        if not rule.components then return rule.format end
        local c = rule.components[1]
        return rule.format:format(math.ceil(x / c.div / c.step) * c.step)
    end
    eq("格式器：剩 4 秒、GCD 1.5 ⇒ 3", show(fmt, 4), "3")
    eq("格式器：剩 3.1 秒 ⇒ 3", show(fmt, 3.1), "3")
    eq("格式器：剩 3.0 秒 ⇒ 2", show(fmt, 3.0), "2")
    eq("格式器：剩 1.6 秒 ⇒ 2", show(fmt, 1.6), "2")
    eq("格式器：最後一個 GCD ⇒ 最後", show(fmt, 1.2), "Last")
    eq("格式器：同一個 GCD 共用一顆", ns.Text.GcdFormatter(1.5, "Last"), fmt)
    check("格式器：GCD 不同另建", ns.Text.GcdFormatter(1.25, "Last") ~= fmt)
    eq("格式器：GCD 壞值 ⇒ nil", ns.Text.GcdFormatter(0, "Last"), nil)
    eq("格式器：標籤裡的 % 要跳脫", ns.Text.GcdFormatter(1.0, "5%").rules[1].format, "5%%")
    local durT = { kind = "duration", spellIDs = { 451038 }, max = 1, texture = "t", color = { r = 1, g = 0, b = 0 }, alpha = 1,
        text = { font = "f", size = 10, decimals = 5 } }
    local sSec = AB.Signature(durT)
    durT.text.gcd, durT.text.last = 1.5, "Last"
    local sG15 = AB.Signature(durT)
    durT.text.gcd = 1.25
    check("簽章：GCD 模式與 GCD 長度進簽章", sSec ~= sG15 and AB.Signature(durT) ~= sG15)
    env.C_StringUtil = nil

    -- 5. 分專精開關
    local c = { rows = {} }
    R.SetRow(c, 263, "Mana", true)
    eq("SetRow：增強開法力（預設關）⇒ 存 true", c.rows[263] and c.rows[263].Mana, true)
    R.SetRow(c, 263, "Mana", false)
    eq("SetRow：改回預設 ⇒ 清掉、空子表也拿掉", c.rows[263], nil)
    R.SetRow(c, 65, "Mana", false)
    eq("SetRow：神聖聖騎關法力 ⇒ 存 false", c.rows[65].Mana, false)
    check("SetRow：只影響那個專精", R.RowOn(c, 65, "Mana") == false and R.RowOn(c, 256, "Mana") == true)
    R.SetRow(c, nil, "Mana", false)
    R.SetRow({}, 65, "Mana", false)
    local noRows = {}
    R.SetRow(noRows, 65, "Mana", false)
    eq("SetRow：沒有 rows 表會建", noRows.rows[65].Mana, false)
    local function keys(set) local o = {} for k in pairs(set) do o[#o + 1] = k end table.sort(o) return table.concat(o, ",") end
    eq("候選：守護德魯伊（三種型態併起來）", keys(R.SpecCandidates(104)), "ComboPoints,Energy,Health,Ironfur,Mana,Rage")
    eq("候選：恢復德魯伊", keys(R.SpecCandidates(105)), "ComboPoints,Energy,Health,Mana,Rage")
    eq("候選：神聖聖騎", keys(R.SpecCandidates(65)), "Health,HolyPower,Mana")
    eq("候選：未知專精", keys(R.SpecCandidates(99999)), "")
    local covered = true
    for spec in pairs(R.SPEC_RESOURCES) do if not R.SPEC_CLASS[spec] then covered = false end end
    for spec in pairs(R.MANA_SPECS) do if not R.SPEC_CLASS[spec] then covered = false end end
    check("職業 → 專精涵蓋每個專精", covered)
    eq("所有專精", #R.AllSpecIDs(), 40)
    -- 遷移：平面的開關攤到每個候選專精（跟預設不同才寫）
    local rows = { Mana = true, Fury = false, Health = false, HolyPower = true, Junk = 5 }
    local n = R.MigrateFlatRows(rows)
    eq("遷移：法力在預設關的專精寫 true（暗牧）", rows[258] and rows[258].Mana, true)
    eq("遷移：法力在預設開的專精不寫（神聖聖騎）", rows[65], nil)
    eq("遷移：魔怒關 ⇒ 三個惡魔獵人專精", (rows[577] and rows[577].Fury == false and rows[581].Fury == false and rows[1480].Fury == false) and "ok", "ok")
    eq("遷移：血量關＝預設 ⇒ 不寫", rows[71], nil)
    check("遷移：平面的布林鍵拿掉、其他壞資料不碰", rows.Mana == nil and rows.Fury == nil and rows.Health == nil and rows.HolyPower == nil and rows.Junk == 5)
    eq("遷移：寫了幾筆（法力 9 個輸出專精＋魔怒 3）", n, 12)
    eq("遷移：再跑一次不變", R.MigrateFlatRows(rows), 0)
    local mixed = { [258] = { Mana = false }, Mana = true }
    R.MigrateFlatRows(mixed)
    eq("遷移：新形狀已有的值不蓋", mixed[258].Mana, false)
    eq("遷移：其他專精照寫", mixed[262].Mana, true)
    -- 設定遷移 v3（Core/DB.lua；這支測試有載資源模組）
    eq("DB_VERSION 5（資源列的遷移是 v3）", ns.DB_VERSION, 5)
    local prof = { resources = { rows = { Mana = true } } }
    ns.DB.MigrateProfile(prof, 2)
    check("v3：平面 → 分專精", prof.resources.rows.Mana == nil and prof.resources.rows[267].Mana == true)
    ns.DB.MigrateProfile(prof, 2)
    check("v3：冪等", prof.resources.rows[267].Mana == true)
end

-- 征戰聖擊列（懲戒）：在聖能上方、預設顯示、自己的高度／填充／底色（預設照德莫的征戰聖擊助手）
do
    eqList("懲戒：征戰聖擊＋聖能", R.RawList("PALADIN", 70, nil), { "CrusadingStrikes", "HolyPower" })
    check("懲戒：征戰聖擊預設顯示", R.DefaultOn(70, "CrusadingStrikes") == true)
    check("征戰聖擊是鏡射列（條件規則不適用）", R.EngineDriven("CrusadingStrikes")
        and not R.SupportsConditions("CrusadingStrikes"))
    local d = ns.DB.BuildDefaults().profile.resources
    eq("征戰聖擊預設高 4", R.KeyRowHeight(d, "CrusadingStrikes"), 4)
    eq("其他列照 rowHeight", R.KeyRowHeight(d, "HolyPower"), 14)
    -- 每列自己的高（heights[key]，所有專精共用）：沒設退回舊的共用值；設了照它、夾 1～30
    local hc = { rowHeight = 12, crusadingHeight = 5, heights = {} }
    eq("沒設 → rowHeight", R.KeyRowHeight(hc, "HolyPower"), 12)
    eq("沒設 → 征戰聖擊用 crusadingHeight", R.KeyRowHeight(hc, "CrusadingStrikes"), 5)
    R.SetKeyHeight(hc, "HolyPower", 20.4)
    eq("設了照它（取整）", R.KeyRowHeight(hc, "HolyPower"), 20)
    R.SetKeyHeight(hc, "Health", 99)
    eq("夾上限 30", hc.heights.Health, 30)
    R.SetKeyHeight(hc, "Health", 0)
    eq("夾下限 1", hc.heights.Health, 1)
    eq("別的列不受影響", R.KeyRowHeight(hc, "Mana"), 12)
    eq("征戰聖擊預設：已揮的時間", R.CrusadingFill(d), "elapsed")
    eq("征戰聖擊：remaining", R.CrusadingFill({ crusadingFill = "remaining" }), "remaining")
    local c = d.colors.CrusadingStrikes
    check("征戰聖擊預設色：聖騎職業色", math.abs(c.color.r - 0.9568) < 1e-6 and c.color.a == 1)
    local back = R.TimerBack(d, "CrusadingStrikes", c.color)
    check("征戰聖擊底色：黑 60%（帶 alpha）", back[1] == 0 and back[2] == 0 and back[3] == 0 and back[4] == 0.6)
    local dim = R.TimerBack(d, "EbonMight", { r = 1, g = 1, b = 1 })
    check("沒有 backColor 的列照主色推", dim[1] == 0.25 and dim[4] == 0.8)

    -- 背景設定（bgAlpha 乘在最後、bgCustom＋bgColor 換掉自動推的色、規則 bgColor 優先）
    local function near(a, b) return math.abs(a - b) < 1e-9 end
    local dc, da = R.DimColor(nil, d)
    check("預設：暗灰 0.6", dc == R.DIM and near(da, 0.6))
    local half = { bgAlpha = 0.5 }
    dc, da = R.DimColor(nil, half)
    check("bgAlpha 0.5：0.3", near(da, 0.3))
    eq("bgAlpha 夾到 0", R.BgAlpha({ bgAlpha = -1 }), 0)
    local cust = { bgAlpha = 0.5, bgCustom = true, bgColor = { r = 1, g = 0, b = 0 } }
    dc, da = R.DimColor(nil, cust)
    check("自訂背景色", dc.r == 1 and dc.g == 0 and near(da, 0.3))
    eq("沒勾自訂：不換色", R.BgCustom({ bgColor = { r = 1, g = 0, b = 0 } }), nil)
    dc, da = R.DimColor({ bgColor = { r = 0, g = 1, b = 0, a = 0.4 } }, cust)
    check("規則 bgColor 優先、照乘", dc.g == 1 and near(da, 0.2))
    local arr = R.DimArray(cust)
    check("DimArray", arr[1] == 1 and near(arr[4], 0.3))
    local tb = R.TimerBg(cust, "EbonMight", { r = 1, g = 1, b = 1 })
    check("剩餘時間條：自訂色＋乘", tb[1] == 1 and tb[2] == 0 and near(tb[4], 0.4))
    local dc2 = { colors = d.colors, bgAlpha = 0.5, bgCustom = true, bgColor = { r = 1, g = 0, b = 0 } }
    local tb2 = R.TimerBg(dc2, "CrusadingStrikes", c.color)
    check("自己有 backColor：顏色照它、只乘", tb2[1] == 0 and near(tb2[4], 0.3))
    local raw = R.TimerBack(dc2, "CrusadingStrikes", c.color)
    check("TimerBack 不受背景設定影響（經過時間模式拿它當填充）", near(raw[4], 0.6))
end

-- 征戰聖擊：鏡射暴雪追蹤量條（找 item、原封轉手、沒亮時畫底色）
do
    local fakeBar = { GetMinMaxValues = function() return 0, 2.6 end, GetValue = function() return 1.3 end }
    local visible = true
    local item = { Bar = fakeBar, IsVisible = function() return visible end }
    local other = { Bar = fakeBar, IsVisible = function() return true end }
    local recs = { [item] = { cooldownID = 148597 }, [other] = { cooldownID = 555 } }
    local saveV, saveCV, saveGT = ns.Viewers, env.C_CooldownViewer, env.GetTime
    ns.Viewers = { frames = recs, EnumerateItems = function(fn, key)
        assert(key == "buffbars"); fn(other, recs[other]); fn(item, recs[item]) end }
    env.C_CooldownViewer = { GetCooldownViewerCooldownInfo = function(id)
        if id == 148597 then return { spellID = 404542 } end
        return { spellID = 1 } end }
    local t = 100
    env.GetTime = function() t = t + 1; return t end
    eq("找到征戰聖擊那個 item", R.MirrorSource(), item)
    local got = {}
    local row = { bar = { SetMinMaxValues = function(_, a, b) got.min, got.max = a, b end,
                          SetValue = function(_, v, extra) got.v, got.extra = v, extra end } }
    R.MirrorRow(row)
    check("原封轉手（不帶第二個參數）", got.min == 0 and got.max == 2.6 and got.v == 1.3 and got.extra == nil)
    visible = false
    row.mirrorElapsed = true
    R.MirrorRow(row)
    check("沒亮＋已揮的時間：整條底色（1/1）", got.max == 1 and got.v == 1)
    row.mirrorElapsed = false
    R.MirrorRow(row)
    check("沒亮＋剩餘時間：0", got.v == 0)
    -- 有 mirror 列 → 增益長條上那條拿掉；選項關掉就不拿
    local saveTimer = env.C_Timer
    local timers = 0
    env.C_Timer = { After = function() timers = timers + 1 end }
    local called = 0
    ns.Bars = ns.Bars or {}
    local saveRA = ns.Bars.RequestAll
    ns.Bars.RequestAll = function() called = called + 1 end
    local mrow = { mode = "mirror" }
    R.SetMirrorDriver({ mrow }, 1, {})
    check("mirror 列顯示：拿掉征戰聖擊那條、其他不動", R.HidesTrackedBar(148597) and not R.HidesTrackedBar(555) and called == 1)
    R.SetMirrorDriver({ mrow }, 1, { crusadingHideBar = false })
    check("選項關掉：不拿", not R.HidesTrackedBar(148597) and called == 2)
    R.SetMirrorDriver({}, 0, {})
    check("沒有 mirror 列：不拿、沒變就不重排", not R.HidesTrackedBar(148597) and called == 2)
    ns.Bars.RequestAll = saveRA
    check("有 mirror 列 → 排一次「在不在追蹤量條」的檢查（合併）", timers == 1)
    env.C_Timer = saveTimer
    recs[item].cooldownID = 777       -- 池子把框發給別人
    eq("換人了就放掉", R.MirrorSource(), nil)
    -- 在不在暴雪的追蹤量條（目錄的 buffbars 清單）
    local saveC = ns.Catalog
    ns.Catalog = { sig = nil, lists = {} }
    eq("目錄還沒建好 → unknown", R.CrusadingTracked(), "unknown")
    ns.Catalog = { sig = "x", lists = { buffbars = { 555 } } }
    eq("清單裡沒有 → no", R.CrusadingTracked(), "no")
    ns.Catalog = { sig = "x", lists = { buffbars = { 555, 148597 } } }
    eq("清單裡有 → yes", R.CrusadingTracked(), "yes")
    ns.Catalog = saveC
    ns.Viewers, env.C_CooldownViewer, env.GetTime = saveV, saveCV, saveGT
end

-- 背景材質：沒挑／跟填充相同 → 填充那張；挑了 → 那張
do
    local saveMedia = ns.Media
    ns.Media = { INHERIT = "INHERIT", Texture = function(t) return "TEX:" .. tostring(t) end }
    eq("背景沒挑 → 跟填充", R.BgTexture({ texture = "a" }), "TEX:a")
    eq("背景跟填充相同 → 跟填充", R.BgTexture({ texture = "a", bgTexture = "INHERIT" }), "TEX:a")
    eq("背景挑了 → 那張", R.BgTexture({ texture = "a", bgTexture = "b" }), "TEX:b")
    eq("資源條預設：背景跟填充", ns.DB.BuildDefaults().profile.resources.bgTexture, "INHERIT")
    ns.Media = saveMedia
end

-- 每種資源自己的外觀（R.StyleFor：resources.style[key]，P6）
do
    local d = ns.DB.BuildDefaults().profile.resources
    check("預設：style 是空表", type(d.style) == "table" and next(d.style) == nil)
    eq("DefaultFor 外觀欄位 → nil（右鍵重設＝回到跟隨）", ns.DB.DefaultFor("bar", "resources", "style.Mana.texture"), nil)
    eq("DefaultFor 跟隨 → nil", ns.DB.DefaultFor("bar", "resources", "style.Mana.follow"), nil)

    local cfg = { texture = "g", bgTexture = "INHERIT", barAlpha = 1, smooth = true, showText = true,
                  textFont = "INHERIT", textSize = 14, manaAbbrev = "wan", fillDirection = "rtl",
                  colors = { Mana = { color = { r = 0, g = 0, b = 1 } } } }
    eq("style 整張沒有：回原表", R.StyleFor(cfg, "Mana"), cfg)
    check("style 整張沒有：跟", R.StyleFollows(cfg, "Mana"))
    eq("不是表：原樣回", R.StyleFor(nil, "Mana"), nil)
    cfg.style = {}
    eq("這一種沒存：回原表", R.StyleFor(cfg, "Mana"), cfg)
    cfg.style.Mana = { texture = "own" }
    eq("follow 沒存＝跟：回原表（存了別的欄位也不讀）", R.StyleFor(cfg, "Mana"), cfg)
    -- 「長條上顯示數值」不看 follow：存了就用自己的（其餘外觀照跟全域）
    cfg.showText = true
    cfg.style.Mana = { texture = "own", showText = false }
    do
        local p = R.StyleFor(cfg, "Mana")
        check("跟著但存了 showText：代理表", p ~= cfg and type(p) == "table")
        eq("跟著：showText 用自己的", p.showText, false)
        eq("跟著：材質照跟全域", p.texture, cfg.texture)
        check("跟著：StyleFollows 仍是跟", R.StyleFollows(cfg, "Mana"))
    end
    cfg.style.Mana = { texture = "own" }
    cfg.style.Mana.follow = true
    eq("follow true：回原表", R.StyleFor(cfg, "Mana"), cfg)
    check("follow true：跟", R.StyleFollows(cfg, "Mana"))

    cfg.style.Mana = { follow = false, texture = "own", showText = false, textSize = 9, manaAbbrev = "none", colors = {} }
    check("follow false：不跟", not R.StyleFollows(cfg, "Mana"))
    local px = R.StyleFor(cfg, "Mana")
    check("follow false：代理表（不是原表）", px ~= cfg and type(px) == "table")
    eq("自己的欄位優先", px.texture, "own")
    eq("自己存的 false 不會退回全域", px.showText, false)
    eq("自己的字級", px.textSize, 9)
    eq("沒存的外觀欄位退回全域", px.barAlpha, 1)
    eq("沒存的外觀欄位退回全域（布林）", px.smooth, true)
    eq("非外觀欄位照讀原表（style 裡同名的不算）", px.manaAbbrev, "wan")
    eq("非外觀欄位：colors 是原表那張", px.colors, cfg.colors)
    eq("非外觀欄位：填充方向", ns.FillReversed(px), true)
    eq("follow 欄位本身不外漏", px.follow, nil)
    eq("其他資源照舊回原表", R.StyleFor(cfg, "Rage"), cfg)
    eq("同一種資源：快取同一張", R.StyleFor(cfg, "Mana"), px)
    -- 讀值是即時的：之後改 style 的欄位照樣讀得到（同一張 style[key] 不必重建）
    cfg.style.Mana.barAlpha = 0.5
    eq("即時讀 style", px.barAlpha, 0.5)
    cfg.style.Mana.barAlpha = nil
    eq("清掉退回全域", px.barAlpha, 1)

    -- 唯讀、不能被當設定表遍歷
    local ok = pcall(function() px.texture = "x" end)
    check("代理表寫入會報錯", not ok)
    eq("寫入失敗沒有落地", rawget(px, "texture"), nil)
    local n = 0
    for _ in pairs(px) do n = n + 1 end
    eq("pairs 遍歷不到任何欄位（不是設定表）", n, 0)

    -- 背景材質走代理表：自己的填充、全域的「跟填充相同」
    local saveMedia = ns.Media
    ns.Media = { INHERIT = "INHERIT", Texture = function(t) return "TEX:" .. tostring(t) end }
    eq("背景跟填充：用自己的填充材質", R.BgTexture(px), "TEX:own")
    cfg.style.Mana.bgTexture = "bgOwn"
    eq("自己挑了背景", R.BgTexture(px), "TEX:bgOwn")
    ns.Media = saveMedia

    -- 數字格式（manaAbbrev）不搬家：代理表照讀全域的
    local fs = { SetText = function(self, t) self.t = t end }
    R.SetNumberText(fs, 25000, 50000, px)
    eq("法力格式照全域（萬）", fs.t, "2.5wan")

    -- 作廢：R.Apply 之後換一張；cfg／style[key] 換了表也換一張
    R.Apply()
    local px2 = R.StyleFor(cfg, "Mana")
    check("R.Apply 後快取作廢（新的一張）", px2 ~= px and px2.texture == "own")
    cfg.style.Mana = { follow = false, texture = "other" }
    local px3 = R.StyleFor(cfg, "Mana")
    check("style[key] 換了表：新的一張", px3 ~= px2 and px3.texture == "other")
    local cfg2 = { texture = "g2", style = { Mana = cfg.style.Mana } }
    local px4 = R.StyleFor(cfg2, "Mana")
    check("設定檔換了（另一張 cfg）：新的一張、退回的是新 cfg", px4 ~= px3 and px4.barAlpha == nil and px4.texture == "other")
    cfg.style.Mana.follow = nil
    eq("切回跟隨：立刻回原表", R.StyleFor(cfg, "Mana"), cfg)
end
------------------------------------------------------------
-- 效能修整 E3 #16a：光環／生命事件依列動態註冊（R.WantedEvents 純函式）
------------------------------------------------------------
do
    local function Set(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
    eq("沒有列 ⇒ 一個都不聽", Set(R.WantedEvents({}, "SHAMAN")), 0)
    eq("只有能量列 ⇒ 一個都不聽", Set(R.WantedEvents({ "Mana", "Maelstrom" }, "SHAMAN")), 0)
    local w = R.WantedEvents({ "Maelstrom", "MaelstromWeapon" }, "SHAMAN")
    eq("漩渦之武（層數型）⇒ UNIT_AURA", w.UNIT_AURA, true)
    eq("漩渦之武 ⇒ 不聽生命", w.UNIT_HEALTH, nil)
    eq("矛尖 ⇒ UNIT_AURA", R.WantedEvents({ "TipOfTheSpear" }, "HUNTER").UNIT_AURA, true)
    eq("靈魂碎片（施放次數）⇒ UNIT_AURA", R.WantedEvents({ "SoulFragments" }, "DEMONHUNTER").UNIT_AURA, true)
    eq("噬靈魂碎片（讀光環層數）⇒ UNIT_AURA", R.WantedEvents({ "DevourerFragments" }, "DEMONHUNTER").UNIT_AURA, true)
    eq("冰刺 ⇒ UNIT_AURA", R.WantedEvents({ "Icicles" }, "MAGE").UNIT_AURA, true)
    eq("秘法靈魂（auraTimer）⇒ UNIT_AURA", R.WantedEvents({ "ArcaneSoul" }, "MAGE").UNIT_AURA, true)
    eq("秘法充能（能量）⇒ 不聽", R.WantedEvents({ "ArcaneCharges" }, "MAGE").UNIT_AURA, nil)
    eq("鐵鬃 ⇒ UNIT_AURA", R.WantedEvents({ "Rage", "Ironfur" }, "DRUID").UNIT_AURA, true)
    eq("野德連擊點（滿溢之力）⇒ UNIT_AURA", R.WantedEvents({ "Energy", "ComboPoints" }, "DRUID").UNIT_AURA, true)
    eq("盜賊連擊點 ⇒ 不聽 UNIT_AURA（不是光環職業）", R.WantedEvents({ "ComboPoints" }, "ROGUE").UNIT_AURA, nil)
    eq("貓以外的德魯伊列（星能）⇒ 不聽", R.WantedEvents({ "LunarPower", "Mana" }, "DRUID").UNIT_AURA, nil)
    -- 以前就沒註冊 UNIT_AURA 的職業：光環列走引擎，照舊不聽
    eq("戰士橫掃（auraBar）⇒ 不聽 UNIT_AURA", R.WantedEvents({ "SweepingStrikes" }, "WARRIOR").UNIT_AURA, nil)
    eq("增輝黯黑力量 ⇒ 不聽 UNIT_AURA", R.WantedEvents({ "EbonMight" }, "EVOKER").UNIT_AURA, nil)
    -- 醉仙緩勁：光環＋生命
    w = R.WantedEvents({ "Energy", "Stagger" }, "MONK")
    eq("醉仙緩勁 ⇒ UNIT_AURA", w.UNIT_AURA, true)
    eq("醉仙緩勁 ⇒ UNIT_HEALTH", w.UNIT_HEALTH, true)
    eq("醉仙緩勁 ⇒ UNIT_MAXHEALTH", w.UNIT_MAXHEALTH, true)
    eq("醉仙緩勁 ⇒ 不聽吸收", w.UNIT_ABSORB_AMOUNT_CHANGED, nil)
    eq("風行武僧（真氣）⇒ 一個都不聽", Set(R.WantedEvents({ "Energy", "Chi" }, "MONK")), 0)
    -- 血量列：任何職業
    w = R.WantedEvents({ "HolyPower", "Health" }, "PALADIN")
    eq("血量列 ⇒ UNIT_HEALTH", w.UNIT_HEALTH, true)
    eq("血量列 ⇒ UNIT_MAXHEALTH", w.UNIT_MAXHEALTH, true)
    eq("血量列 ⇒ 不聽 UNIT_AURA", w.UNIT_AURA, nil)
    -- 無視苦痛：吸收量＋最大生命
    w = R.WantedEvents({ "Rage", "IgnorePain" }, "WARRIOR")
    eq("無視苦痛 ⇒ UNIT_ABSORB_AMOUNT_CHANGED", w.UNIT_ABSORB_AMOUNT_CHANGED, true)
    eq("無視苦痛 ⇒ UNIT_MAXHEALTH", w.UNIT_MAXHEALTH, true)
    eq("無視苦痛 ⇒ 不聽 UNIT_HEALTH", w.UNIT_HEALTH, nil)
    eq("無視苦痛 ⇒ 不聽 UNIT_AURA（戰士）", w.UNIT_AURA, nil)
    -- 不認得的 key 不報錯；out 重複用
    local out = { STALE = true }
    local w2 = R.WantedEvents({ "NoSuchKey" }, "SHAMAN", out)
    check("out 重複用、清乾淨、壞 key 略過", w2 == out and Set(out) == 0)
    eq("keys 是 nil 不報錯", Set(R.WantedEvents(nil, "MONK")), 0)
end
print(("Resources_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
