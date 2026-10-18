------------------------------------------------------------
-- Panel/Patterns.lua 的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Patterns_test.lua
--
-- 覆蓋：FromGlobal 對 %d／%s／%.2g／%%／位置參數／|4 單複數／全形括號／magic 字元；
-- Match 的 capture 順序；語意表 Find（三語）；耗能 key 掃描與排除清單；PowerOf；
-- 屬性分類；ColorNumbers 的跳脫碼保護；Strip。
-- 三語的 _G 實值抄自 Interface/tmp/GlobalStrings/gs_{enUS,zhTW,zhCN}.csv（12.1.5）。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq = H.check, H.eq

------------------------------------------------------------
-- 三語 GlobalStrings（實值）
------------------------------------------------------------
local GS = {
    enUS = {
        MANA_COST = "%s Mana", MANA_COST_PER_TIME = "%s Mana, plus %s per sec",
        MANA_COST_PER_TIME_NO_BASE = "%s Mana per sec", MANA_COST_LARGE = "%s Mana",
        RAGE_COST = "%s Rage", HOLY_POWER_COST = "%s Holy Power", HOLY_POWER_COST_PER_TIME_NO_BASE = "%s Holy Power per sec",
        RUNE_COST = "%s |4Rune:Runes;", BLUE_ESSENCE_COST = "%s Essence", ESSENCE_COST = "%s Essence",
        INSANITY_COST_LARGE = "%s Insanity", HEALTH_COST_PCT = "%s%% of Maximum Health",
        SOUL_SHARDS_COST = "%s Soul |4Shard:Shards;",
        TRAINER_MANA_COST = "Mana cost: |cffffffff%d|r", SEND_MAIL_COST = "Postage:", REPAIR_COST = "Repair Cost:",
        BUYOUT_COST = "Buyout", SKILL_LEARNING_COST = "Learning Cost", BONUS_ROLL_COST = "%d", RESEARCH_COST = "%s",
        HOUSING_NEIGHBORHOOD_SETTINGS_COST = "%s", CONFIRM_HIGH_COST_ITEM = "%s", BALANCE_POSITIVE_ENERGY_COST = "%s",
        POWER_DISPLAY_COST = "%s %s", REAGENT_COST_CONSUME_ITEMS = "%s",
        SPELL_CAST_TIME_SEC = "%.2g sec cast", SPELL_CAST_TIME_MIN = "%.2g min cast", SPELL_CAST_TIME_INSTANT = "Instant",
        SPELL_CAST_CHANNELED = "Channeled",
        SPELL_RECAST_TIME_SEC = "%.2g sec cooldown", SPELL_RECAST_TIME_MIN = "%.2g min cooldown",
        SPELL_RECAST_TIME_CHARGES_SEC = "%.2g sec recharge",
        ITEM_COOLDOWN_TOTAL = "(%s Cooldown)", ITEM_COOLDOWN_TOTAL_SEC = "(%d Sec Cooldown)",
        ITEM_COOLDOWN_TIME = "Cooldown remaining: %s",
        SPELL_RANGE = "%s yd range", SPELL_RANGE_DUAL = "%1$s: %2$s yd range", SPELL_RANGE_AREA = "Area around caster",
        SPELL_PASSIVE = "Passive", TOOLTIP_TALENT_RANK = "Rank %d/%d",
        ITEM_MIN_LEVEL = "Requires Level %d", ITEM_LEVEL_RANGE = "Requires level %d to %d",
        ITEM_MIN_SKILL = "Requires %s (%d)", ITEM_REQ_SKILL = "Requires %s",
        ARMOR_TEMPLATE = "%s Armor", DAMAGE_TEMPLATE = "%s - %s Damage", DPS_TEMPLATE = "(%s damage per second)",
        DURABILITY_TEMPLATE = "Durability %d / %d", ITEM_SET_NAME = "%s (%d/%d)", ITEM_SET_BONUS = "Set: %s",
        ITEM_SET_BONUS_GRAY = "(%d) Set: %s",
        ITEM_SPELL_TRIGGER_ONUSE = "Use:", ITEM_CREATED_BY = "|cff00ff00<Made by %s>|r",
        ITEM_MOD_STRENGTH_SHORT = "Strength", ITEM_MOD_AGILITY_SHORT = "Agility", ITEM_MOD_INTELLECT_SHORT = "Intellect",
        ITEM_MOD_AGILITY_OR_INTELLECT_SHORT = "Agility or Intellect",
        ITEM_MOD_CRIT_RATING_SHORT = "Critical Strike", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "Critical Strike",
        ITEM_MOD_HASTE_RATING_SHORT = "Haste", ITEM_MOD_VERSATILITY = "Versatility",
        ITEM_MOD_CR_AVOIDANCE_SHORT = "Avoidance", ITEM_MOD_SPIRIT_SHORT = "Spirit",
    },
    zhTW = {
        MANA_COST = "%s法力", MANA_COST_PER_TIME = "%s點法力，外加每秒%s點", HOLY_POWER_COST = "%s道聖能",
        RUNE_COST = "%s個符文", HEALTH_COST_PCT = "生命力上限的%s%%",
        SPELL_CAST_TIME_SEC = "施法時間%.2g秒", SPELL_CAST_TIME_INSTANT = "立即施法", SPELL_CAST_CHANNELED = "需引導",
        SPELL_RECAST_TIME_SEC = "冷卻時間%.2g秒", SPELL_RECAST_TIME_CHARGES_SEC = "恢復時間%.2g秒",
        ITEM_COOLDOWN_TOTAL = "（%s冷卻時間）", ITEM_COOLDOWN_TIME_SEC = "冷卻時間尚有：%d秒",
        SPELL_RANGE = "%s碼距離", SPELL_RANGE_DUAL = "%1$s:%2$s碼距離", SPELL_PASSIVE = "被動",
        TOOLTIP_TALENT_RANK = "等級%d/%d", ITEM_MIN_LEVEL = "需要等級%d", ITEM_MIN_SKILL = "需要%s（%d）",
        ITEM_REQ_SKILL = "需要%s", ARMOR_TEMPLATE = "%s點護甲", DAMAGE_TEMPLATE = "%s-%s點傷害",
        DPS_TEMPLATE = "（每秒%s點傷害）", DURABILITY_TEMPLATE = "耐久度 %d / %d", ITEM_SET_NAME = "%s（%d/%d）",
        ITEM_SET_BONUS_GRAY = "（%d）套裝：%s",
        ITEM_MOD_STRENGTH_SHORT = "力量", ITEM_MOD_CRIT_RATING_SHORT = "致命一擊", ITEM_MOD_VERSATILITY = "臨機應變",
        ITEM_MOD_CR_AVOIDANCE_SHORT = "迴避",
    },
    zhCN = {
        MANA_COST = "%s法力值", HOLY_POWER_COST = "%s层神圣能量", RUNE_COST = "%s个符文",
        SPELL_CAST_TIME_SEC = "%.2g秒施法时间", SPELL_CAST_TIME_INSTANT = "瞬发",
        SPELL_RECAST_TIME_SEC = "%.2g秒冷却时间", SPELL_RECAST_TIME_CHARGES_SEC = "%.2g秒充能时间",
        ITEM_COOLDOWN_TOTAL_SEC = "(%d秒冷却时间)", ITEM_COOLDOWN_TOTAL = "（%s冷却）",
        SPELL_RANGE = "%s码射程", SPELL_RANGE_DUAL = "%1$s：%2$s码范围", SPELL_PASSIVE = "被动",
        TOOLTIP_TALENT_RANK = "等级 %d/%d", ITEM_MIN_LEVEL = "需要等级 %d", ITEM_MIN_SKILL = "需要%s（%d）",
        ITEM_REQ_SKILL = "需要%s", ARMOR_TEMPLATE = "%s点护甲", DAMAGE_TEMPLATE = "%s - %s点伤害",
        DPS_TEMPLATE = "（每秒伤害%s点）", ITEM_SET_NAME = "%s（%d/%d）",
        ITEM_MOD_STRENGTH_SHORT = "力量", ITEM_MOD_CRIT_RATING_SHORT = "爆击", ITEM_MOD_VERSATILITY = "全能",
    },
}

local function Fresh(locale, extra)
    local env = H.Env(GS[locale])
    for k, v in pairs(extra or {}) do env[k] = v end
    local ns = {}
    H.Load(env, ns, "Panel/Patterns.lua")
    return ns.Patterns, env
end

------------------------------------------------------------
-- 1. FromGlobal
------------------------------------------------------------
do
    local P = Fresh("enUS")
    local pats, order = P.FromGlobal("%s Mana")
    eq("%s：一條 pattern", #pats, 1)
    eq("%s：形狀", pats[1], "^%s*(.-) Mana%s*$")
    eq("%s：capture 順序", order[1], 1)

    pats = P.FromGlobal("Requires Level %d")
    eq("%d：數字 capture", pats[1], "^%s*Requires Level ([%d,%.]+)%s*$")
    check("%d：吃千分位", ("Requires Level 1,234"):match(pats[1]) == "1,234")

    pats = P.FromGlobal("%.2g sec cast")
    eq("%.2g：數字 capture", ("1.5 sec cast"):match(pats[1]), "1.5")
    pats = P.FromGlobal("冷卻時間%.2g秒")
    eq("%.2g：不吞非數字（剩餘冷卻那行）", ("冷卻時間尚有：12秒"):match(pats[1]), nil)

    pats = P.FromGlobal("%s%% of Maximum Health")
    eq("%%：字面百分號", ("10% of Maximum Health"):match(pats[1]), "10")

    pats = P.FromGlobal("(%s damage per second)")
    eq("magic 字元被跳脫", ("(25.6 damage per second)"):match(pats[1]), "25.6")
    check("magic 字元：不吃沒括號的", ("25.6 damage per second"):match(pats[1]) == nil)

    pats = P.FromGlobal("%s |4Rune:Runes;")
    eq("|4：三條（單／複／原跳脫碼）", #pats, 3)
    eq("|4：單數", ("1 Rune"):match(pats[1]), "1")
    eq("|4：複數", ("2 Runes"):match(pats[2]), "2")
    eq("|4：原跳脫碼", ("2 |4Rune:Runes;"):match(pats[3]), "2")

    pats = P.FromGlobal("%s（%d/%d）")
    local a, b, c = ("暗影套裝（2/5）"):match(pats[1])
    check("全形括號", a == "暗影套裝" and b == "2" and c == "5", tostring(a) .. tostring(b) .. tostring(c))

    pats = P.FromGlobal("  Use: %s  ")
    check("兩端允許空白", ("Use: x"):match(pats[1]) == "x")

    local list = P.FromGlobal(nil)
    eq("非字串回空陣列", #list, 0)
end

------------------------------------------------------------
-- 2. Match：位置參數重排、沒有 capture 的格式
------------------------------------------------------------
do
    local P = Fresh("enUS", { SWAPPED = "%2$s的%1$s", NOCAP = "Instant" })
    local first, second = P.Match("SPELL_RANGE_DUAL", "Melee: 5 yd range")
    check("位置參數：順序", first == "Melee" and second == "5")
    first, second = P.Match("SWAPPED", "B的A")
    check("位置參數：反序也照參數編號排回", first == "A" and second == "B", tostring(first) .. "," .. tostring(second))
    eq("沒有 capture 的格式回 true", P.Match("NOCAP", "Instant"), true)
    eq("不符回 nil", P.Match("NOCAP", "Channeled"), nil)
    eq("_G 沒有的 key 回 nil", P.Match("NO_SUCH_KEY", "x"), nil)
    eq("Prefix：拆掉標籤", P.Prefix("ITEM_SPELL_TRIGGER_ONUSE", "Use: Heals you."), "Heals you.")
    eq("Prefix：不是開頭回 nil", P.Prefix("ITEM_SPELL_TRIGGER_ONUSE", "Equip: x"), nil)
end

------------------------------------------------------------
-- 3. 語意表 Find：三語
------------------------------------------------------------
local CASES = {
    enUS = {
        { "cast", "1.5 sec cast", "SPELL_CAST_TIME_SEC", "1.5" },
        { "cast", "Instant", "SPELL_CAST_TIME_INSTANT" },
        { "cooldown", "8 sec cooldown", "SPELL_RECAST_TIME_SEC", "8" },
        { "cooldown", "20 sec recharge", "SPELL_RECAST_TIME_CHARGES_SEC", "20" },
        { "cooldown", "(30 Sec Cooldown)", "ITEM_COOLDOWN_TOTAL_SEC", "30" },
        { "cooldownLeft", "Cooldown remaining: 2 min", "ITEM_COOLDOWN_TIME", "2 min" },
        { "range", "40 yd range", "SPELL_RANGE", "40" },
        { "range", "Area around caster", "SPELL_RANGE_AREA" },
        { "passive", "Passive", "SPELL_PASSIVE" },
        { "talent", "Rank 2/3", "TOOLTIP_TALENT_RANK", "2" },
        { "level", "Requires Level 80", "ITEM_MIN_LEVEL", "80" },
        { "level", "Requires level 10 to 80", "ITEM_LEVEL_RANGE", "10" },
        { "skill", "Requires Tailoring (75)", "ITEM_MIN_SKILL", "Tailoring" },
        { "armor", "1027 Armor", "ARMOR_TEMPLATE", "1027" },
        { "damage", "65 - 99 Damage", "DAMAGE_TEMPLATE", "65" },
        { "dps", "(25.6 damage per second)", "DPS_TEMPLATE", "25.6" },
        { "durability", "Durability 165 / 165", "DURABILITY_TEMPLATE", "165" },
        { "setName", "Shadowcraft (2/5)", "ITEM_SET_NAME", "Shadowcraft" },
        { "setBonus", "(2) Set: Increases damage.", "ITEM_SET_BONUS_GRAY", "2" },
        { "maker", "|cff00ff00<Made by Mili>|r", "ITEM_CREATED_BY", "Mili" },
        -- MANA_COST 與 MANA_COST_LARGE 格式一模一樣：後綴長的先試（兩者 PowerOf 都是 MANA）
        { "cost", "50 Mana", "MANA_COST_LARGE", "50" },
        { "cost", "3 Holy Power per sec", "HOLY_POWER_COST_PER_TIME_NO_BASE", "3" },
        { "cost", "2 Runes", "RUNE_COST", "2" },
        { "cost", "1 Rune", "RUNE_COST", "1" },
        { "cost", "10% of Maximum Health", "HEALTH_COST_PCT", "10" },
    },
    zhTW = {
        { "cast", "施法時間1.7秒", "SPELL_CAST_TIME_SEC", "1.7" },
        { "cast", "立即施法", "SPELL_CAST_TIME_INSTANT" },
        { "cast", "需引導", "SPELL_CAST_CHANNELED" },
        { "cooldown", "冷卻時間8秒", "SPELL_RECAST_TIME_SEC", "8" },
        { "cooldown", "恢復時間20秒", "SPELL_RECAST_TIME_CHARGES_SEC", "20" },
        { "cooldown", "（2分鐘冷卻時間）", "ITEM_COOLDOWN_TOTAL", "2分鐘" },
        { "cooldownLeft", "冷卻時間尚有：12秒", "ITEM_COOLDOWN_TIME_SEC", "12" },
        { "range", "30碼距離", "SPELL_RANGE", "30" },
        { "range", "近戰:5碼距離", "SPELL_RANGE_DUAL", "近戰" },
        { "passive", "被動", "SPELL_PASSIVE" },
        { "talent", "等級1/2", "TOOLTIP_TALENT_RANK", "1" },
        { "level", "需要等級80", "ITEM_MIN_LEVEL", "80" },
        { "skill", "需要裁縫（75）", "ITEM_MIN_SKILL", "裁縫" },
        { "armor", "1027點護甲", "ARMOR_TEMPLATE", "1027" },
        { "damage", "65-99點傷害", "DAMAGE_TEMPLATE", "65" },
        { "dps", "（每秒25.6點傷害）", "DPS_TEMPLATE", "25.6" },
        { "durability", "耐久度 165 / 165", "DURABILITY_TEMPLATE", "165" },
        { "setName", "暗影套裝（2/5）", "ITEM_SET_NAME", "暗影套裝" },
        { "setBonus", "（2）套裝：提高傷害。", "ITEM_SET_BONUS_GRAY", "2" },
        { "cost", "50法力", "MANA_COST", "50" },
        { "cost", "1,200點法力，外加每秒30點", "MANA_COST_PER_TIME", "1,200" },
        { "cost", "3道聖能", "HOLY_POWER_COST", "3" },
        { "cost", "2個符文", "RUNE_COST", "2" },
        { "cost", "生命力上限的10%", "HEALTH_COST_PCT", "10" },
    },
    zhCN = {
        { "cast", "1.5秒施法时间", "SPELL_CAST_TIME_SEC", "1.5" },
        { "cast", "瞬发", "SPELL_CAST_TIME_INSTANT" },
        { "cooldown", "8秒冷却时间", "SPELL_RECAST_TIME_SEC", "8" },
        { "cooldown", "20秒充能时间", "SPELL_RECAST_TIME_CHARGES_SEC", "20" },
        { "cooldown", "(30秒冷却时间)", "ITEM_COOLDOWN_TOTAL_SEC", "30" },
        { "range", "30码射程", "SPELL_RANGE", "30" },
        { "range", "近战：5码范围", "SPELL_RANGE_DUAL", "近战" },
        { "passive", "被动", "SPELL_PASSIVE" },
        { "talent", "等级 1/2", "TOOLTIP_TALENT_RANK", "1" },
        { "level", "需要等级 80", "ITEM_MIN_LEVEL", "80" },
        { "skill", "需要裁缝（75）", "ITEM_MIN_SKILL", "裁缝" },
        { "armor", "1027点护甲", "ARMOR_TEMPLATE", "1027" },
        { "damage", "65 - 99点伤害", "DAMAGE_TEMPLATE", "65" },
        { "dps", "（每秒伤害25.6点）", "DPS_TEMPLATE", "25.6" },
        { "setName", "暗影套装（2/5）", "ITEM_SET_NAME", "暗影套装" },
        { "cost", "50法力值", "MANA_COST", "50" },
        { "cost", "3层神圣能量", "HOLY_POWER_COST", "3" },
        { "cost", "2个符文", "RUNE_COST", "2" },
    },
}

for _, locale in ipairs({ "enUS", "zhTW", "zhCN" }) do
    local P = Fresh(locale)
    for _, c in ipairs(CASES[locale]) do
        local field, text, wantKey, wantCap = c[1], c[2], c[3], c[4]
        local key, cap = P.Find(field, text)
        eq(locale .. " " .. field .. "「" .. text .. "」key", key, wantKey)
        if wantCap then eq(locale .. " " .. field .. "「" .. text .. "」值", cap, wantCap) end
    end
    eq(locale .. " 不相干的行不認", (P.Find("cast", "Heals a friendly target.")), nil)
end

------------------------------------------------------------
-- 4. 耗能 key 掃描：排除清單與順序
------------------------------------------------------------
do
    local P = Fresh("enUS")
    local keys = P.Keys("cost")
    local has = {}
    for i, k in ipairs(keys) do has[k] = i end
    for _, k in ipairs({ "MANA_COST", "MANA_COST_PER_TIME", "MANA_COST_PER_TIME_NO_BASE", "MANA_COST_LARGE",
        "RAGE_COST", "HOLY_POWER_COST", "RUNE_COST", "INSANITY_COST_LARGE", "HEALTH_COST_PCT" }) do
        check("耗能掃描收：" .. k, has[k] ~= nil)
    end
    for _, k in ipairs({ "TRAINER_MANA_COST", "SEND_MAIL_COST", "REPAIR_COST", "BUYOUT_COST", "SKILL_LEARNING_COST",
        "BONUS_ROLL_COST", "RESEARCH_COST", "HOUSING_NEIGHBORHOOD_SETTINGS_COST", "CONFIRM_HIGH_COST_ITEM",
        "BALANCE_POSITIVE_ENERGY_COST", "POWER_DISPLAY_COST", "REAGENT_COST_CONSUME_ITEMS" }) do
        check("耗能掃描排除：" .. k, has[k] == nil)
    end
    check("後綴長的先試：NO_BASE 在 MANA_COST 前", has.MANA_COST_PER_TIME_NO_BASE < has.MANA_COST)
    check("後綴長的先試：PER_TIME 在 MANA_COST 前", has.MANA_COST_PER_TIME < has.MANA_COST)
    eq("IsCostKey：小寫不收", P.IsCostKey("mana_cost"), false)
    eq("掃描結果有快取（同一張表）", P.Keys("cost"), keys)
end

do
    local P = Fresh("enUS", { PowerBarColor = { MANA = {}, HOLY_POWER = {}, ESSENCE = {}, RUNES = {} } })
    eq("PowerOf：MANA", P.PowerOf("MANA_COST_LARGE_PER_TIME"), "MANA")
    eq("PowerOf：HOLY_POWER", P.PowerOf("HOLY_POWER_COST_PER_TIME_NO_BASE"), "HOLY_POWER")
    eq("PowerOf：BLUE_ESSENCE 剝成 ESSENCE", P.PowerOf("BLUE_ESSENCE_COST"), "ESSENCE")
    eq("PowerOf：查不到回 nil", P.PowerOf("RUNE_COST"), nil)
    eq("PowerOf：不是耗能 key", P.PowerOf("SPELL_RANGE"), nil)
end

------------------------------------------------------------
-- 5. 屬性
------------------------------------------------------------
do
    local P = Fresh("enUS")
    local v, key, cat = P.Stat("+150 Strength")
    check("屬性：力量", v == "150" and key == "ITEM_MOD_STRENGTH_SHORT" and cat == "primary")
    v, key, cat = P.Stat("|cffffffff+1,234 Agility or Intellect|r")
    check("屬性：組合主屬性、去色碼、千分位", v == "1,234" and cat == "primary", tostring(key))
    v, key, cat = P.Stat("+80 Critical Strike")
    check("屬性：撞名時分類前面的贏", key == "ITEM_MOD_CRIT_RATING_SHORT" and cat == "secondary", tostring(key))
    v, key, cat = P.Stat("+5 Versatility")
    check("屬性：臨機應變（沒有 _SHORT）", key == "ITEM_MOD_VERSATILITY" and cat == "secondary", tostring(key))
    v, key, cat = P.Stat("+20 Avoidance")
    eq("屬性：三屬性", cat, "tertiary")
    v, key, cat = P.Stat("+3 Spirit")
    eq("屬性：其他", cat, "other")
    eq("屬性：不認得的名字", (P.Stat("+3 Charisma")), nil)
    eq("屬性：沒有正號", (P.Stat("150 Strength")), nil)
end
do
    local P = Fresh("zhTW")
    local v, key, cat = P.Stat("+150 力量")
    check("zhTW 屬性：力量", v == "150" and cat == "primary")
    v, key, cat = P.Stat("+5 臨機應變")
    eq("zhTW 屬性：臨機應變", cat, "secondary")
    v, key, cat = P.Stat("+20 迴避")
    eq("zhTW 屬性：迴避", cat, "tertiary")
end
do
    local P = Fresh("zhCN")
    local _, _, cat = P.Stat("+80 爆击")
    eq("zhCN 屬性：爆击", cat, "secondary")
    _, _, cat = P.Stat("+5 全能")
    eq("zhCN 屬性：全能", cat, "secondary")
end

------------------------------------------------------------
-- 6. ColorNumbers／Strip
------------------------------------------------------------
do
    local P = Fresh("enUS")
    local C = function(t) return P.ColorNumbers(t, "abcdef") end
    eq("上色：一般數字", C("Deals 150 damage"), "Deals |cffabcdef150|r damage")
    eq("上色：緊接 % 一起", C("by 10%."), "by |cffabcdef10%|r.")
    eq("上色：句尾句點留在外面", C("lasts 6."), "lasts |cffabcdef6|r.")
    eq("上色：小數", C("1.5 sec"), "|cffabcdef1.5|r sec")
    eq("上色：詞中不動（x2）", C("x2"), "x2")
    eq("上色：色碼不動", C("|cffff0000red|r"), "|cffff0000red|r")
    eq("上色：圖示尺寸不動", C("|T123:14|t 5"), "|T123:14|t |cffabcdef5|r")
    eq("上色：超連結不動", C("|Hitem:123|h[A]|h"), "|Hitem:123|h[A]|h")
    eq("上色：具名色不動", C("|cnRED_FONT_COLOR:3|r"), "|cnRED_FONT_COLOR:|cffabcdef3|r|r")
    eq("上色：|n 保護", C("a|n2"), "a|n|cffabcdef2|r")
    eq("上色：|4 單數先挑好", C("1 |4hour:hours;"), "|cffabcdef1|r hour")
    eq("上色：|4 複數先挑好", C("3 |4hour:hours;"), "|cffabcdef3|r hours")
    eq("上色：中文", C("造成150點傷害"), "造成|cffabcdef150|r點傷害")
    eq("上色：hex 空字串不動", P.ColorNumbers("5", ""), "5")
    eq("上色：hex nil 不動", P.ColorNumbers("5", nil), "5")

    eq("StripTextures", P.StripTextures("|T123:16:16|t Hearthstone"), "Hearthstone")
    eq("StripTextures：atlas", P.StripTextures("|A:foo:16:16|a Name"), "Name")
    eq("StripColors", P.StripColors("|cffff0000A|r|cnRED_FONT_COLOR:B|r"), "AB")
end

H.finish("Patterns_test")
