------------------------------------------------------------
-- Panel/ReadSpell.lua＋ViewSpell.lua 的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/ReadSpell_test.lua
--
-- fixture 是手拼的：每一行都用 fixtures/GlobalStrings.lua 的實值 string.format 出來，
-- 所以三個語系的行長得跟遊戲裡格式一致（真實行佈局要靠 /mtip record 的資料再驗）。
-- 覆蓋：每個欄位的落點（耗能＋資源、施法、冷卻、充能恢復、距離、最大充能、被動、天賦等級、
-- 下一等級、需求未達成、剩餘冷卻、材料、巢狀法術、描述、認不得的半列進 extras）、
-- 名字去圖示、天賦面板的名字在 data 之外、秘密行 → nil、原生右欄補位、四格的值與缺格、
-- 四格關掉改兩欄、描述數字上色設定。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq = H.check, H.eq
local GS = dofile(here .. "/fixtures/GlobalStrings.lua")

local LT = H.Env().Enum.TooltipDataLineType
local GOLD = { 1, 0.82, 0 }
local WHITE = { 1, 1, 1 }
local RED = { 1, 0.125, 0.125 }

local function Setup(locale)
    local env = H.Env(GS[locale])
    env.PowerBarColor = { MANA = { r = 0, g = 0, b = 1 }, RUNES = { r = 0.5, g = 0.5, b = 0.5 }, RAGE = { r = 1, g = 0, b = 0 } }
    env.C_Spell = { GetSpellTexture = function(id) return 1000 + id end }
    env.UnitLevel = function() return 80 end
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        Media = { WHITE8X8 = "white", NoSnap = function(t) return t end, Font = function() return "default.ttf" end },
        playerClass = "MAGE",
        db = { general = { scale = 1, background = { r = 0.133, g = 0.133, b = 0.133, a = 1 },
            borderColor = { r = 0.18, g = 0.18, b = 0.18, a = 1 } },
            item = { panel = true }, spell = { panel = true }, panel = { separators = true, strip = true, numberColor = "class" } },
        Skin = { State = {}, Poll = function() end, Unpoll = function() end, Each = function() end },
    }
    for _, f in ipairs({ "Libs/MiliUIWidgets/Secret.lua", "Core/Colors.lua", "Panel/Patterns.lua", "Panel/Frame.lua", "Panel/Render.lua",
        "Panel/Native.lua", "Panel/ReadFallback.lua", "Panel/Try.lua", "Panel/ReadSpell.lua", "Panel/ViewSpell.lua" }) do
        H.Load(env, ns, f)
    end
    local G = GS[locale]
    local function F(key, ...) return string.format(G[key], ...) end
    return ns.Panel, F, G, env, ns
end

local function Row(i, left, right, opts)
    local r = { left = left, right = right, lineIndex = i, color = WHITE }
    for k, v in pairs(opts or {}) do r[k] = v end
    return r
end

local GAME = {
    spellIcon = function(id) return 1000 + id end,
    playerLevel = function() return 80 end,
}

------------------------------------------------------------
-- 1. 三語：施法法術（耗能＋距離、施法時間、描述、別人加的行）
------------------------------------------------------------
for _, locale in ipairs({ "enUS", "zhTW", "zhCN" }) do
    local P, F, G = Setup(locale)
    local tag = locale .. " "
    local rows = {
        Row(1, "|T135812:16:16:0:0:32:32:2:30:2:30|t Fireball", nil, { type = LT.SpellName }),
        Row(2, F("MANA_COST", "2,000"), F("SPELL_RANGE", "40")),
        Row(3, F("SPELL_CAST_TIME_SEC", 2.25)),
        Row(4, "Hurls a fiery ball that causes 150 Fire damage.", nil, { type = LT.SpellDescription, color = GOLD }),
        { left = "Spell ID: 133", lineIndex = 5, appended = true, color = GOLD },
    }
    local m = P.ReadSpellRows(rows, GAME, 133)
    eq(tag .. "名字去圖示", m.name, "Fireball")
    eq(tag .. "圖示", m.icon, 1133)
    eq(tag .. "耗能", m.cost and m.cost.text, F("MANA_COST", "2,000"))
    eq(tag .. "耗能資源", m.cost and m.cost.power, "MANA")
    eq(tag .. "距離", m.range and m.range.text, F("SPELL_RANGE", "40"))
    eq(tag .. "施法值", m.cast and m.cast.value, "2.2")
    eq(tag .. "描述", m.description[1], "Hurls a fiery ball that causes 150 Fire damage.")
    eq(tag .. "別人加的行進附屬框那一桶", m.appended[1] and m.appended[1].left, "Spell ID: 133")
    eq(tag .. "附屬框的行保留顏色", m.appended[1] and m.appended[1].color, GOLD)
    eq(tag .. "主面板「其他」沒有東西", #m.extras, 0)

    local view = P.ViewSpell(m)
    local strip = view.sections[1]
    check(tag .. "第一段是四格", strip.kind == "custom")
    local desc
    for _, s in ipairs(view.sections) do if s.kind == "prose" then desc = s end end
    -- 法師 0.25, 0.78, 0.92 → c·0.5＋0.5
    check(tag .. "描述：數字上色（職業色亮化）", desc and desc.numbers == "9fe3f5", desc and desc.numbers)
    eq(tag .. "標題白字", view.header[1].color[1], 1)
    eq(tag .. "法術圖示 36", view.iconSize, 36)
end

------------------------------------------------------------
-- 2. 三語：瞬發＋冷卻、DK 符文、近戰範圍；充能；被動；每秒耗能
------------------------------------------------------------
for _, locale in ipairs({ "enUS", "zhTW", "zhCN" }) do
    local P, F, G = Setup(locale)
    local tag = locale .. " "
    local m = P.ReadSpellRows({
        Row(1, "Death Strike", nil, { type = LT.SpellName }),
        Row(2, F("RUNE_COST", 1), G.MELEE_RANGE),
        Row(3, G.SPELL_CAST_TIME_INSTANT, F("SPELL_RECAST_TIME_SEC", 8)),
    }, GAME, 49998)
    check(tag .. "符文耗能（|4 跳脫碼原樣）", m.cost and m.cost.key == "RUNE_COST", m.cost and m.cost.key)
    eq(tag .. "近戰範圍", m.range and m.range.key, "MELEE_RANGE")
    eq(tag .. "瞬發", m.cast and m.cast.key, "SPELL_CAST_TIME_INSTANT")
    eq(tag .. "冷卻值", m.cooldown and m.cooldown.value, "8")
    eq(tag .. "沒有 extras", #m.extras, 0)
    eq(tag .. "冷卻精簡寫法", P.ShortTime(m.cooldown), F("INT_SPELL_DURATION_SEC", 8))
    eq(tag .. "瞬發原樣", P.ShortTime(m.cast), G.SPELL_CAST_TIME_INSTANT)

    m = P.ReadSpellRows({
        Row(1, "Fire Blast", nil, { type = LT.SpellName }),
        Row(2, F("MANA_COST", "500"), F("SPELL_RANGE", "40")),
        Row(3, G.SPELL_CAST_TIME_INSTANT, F("SPELL_RECAST_TIME_CHARGES_SEC", 12)),
        Row(4, F("SPELL_MAX_CHARGES", 2)),
    }, GAME, 108853)
    check(tag .. "充能恢復", m.cooldown and m.cooldown.recharge == true)
    eq(tag .. "最大充能", m.charges and m.charges.count, 2)
    local view = P.ViewSpell(m)
    eq(tag .. "最大充能進徽章", view.header[2] and view.header[2].badges[1][1], F("SPELL_MAX_CHARGES", 2))

    m = P.ReadSpellRows({
        Row(1, "Mastery", nil, { type = LT.SpellName }),
        Row(2, G.SPELL_PASSIVE, nil, { type = LT.SpellPassive }),
        Row(3, "Increases damage by 10%.", nil, { type = LT.SpellDescription }),
    }, GAME, 1)
    eq(tag .. "被動", m.passive, G.SPELL_PASSIVE)
    view = P.ViewSpell(m)
    eq(tag .. "被動：沒有四格", view.sections[1].kind, "prose")
    eq(tag .. "被動進徽章", view.header[2].badges[1][1], G.SPELL_PASSIVE)

    m = P.ReadSpellRows({
        Row(1, "Drain", nil, { type = LT.SpellName }),
        Row(2, F("MANA_COST_PER_TIME", "1,200", "30")),
        Row(3, G.SPELL_CAST_CHANNELED),
    }, GAME, 1)
    -- MANA_COST_PER_TIME 與 _LARGE_PER_TIME 有的語系格式一樣，哪一支都對：看資源
    check(tag .. "每秒耗能", m.cost and m.cost.key:find("PER_TIME$") and m.cost.power == "MANA", m.cost and m.cost.key)
    eq(tag .. "引導", m.cast and m.cast.key, "SPELL_CAST_CHANNELED")
end

------------------------------------------------------------
-- 3. 需求、剩餘冷卻、材料、認不得的半列、巢狀法術
------------------------------------------------------------
do
    local P, F, G = Setup("zhTW")
    local m = P.ReadSpellRows({
        Row(1, "背刺", nil, { type = LT.SpellName }),
        Row(2, "35能量", "神祕的右欄"),
        Row(3, F("SPELL_EQUIPPED_ITEM", "匕首"), nil, { color = RED }),
        Row(4, "需要潛行", nil, { type = LT.UsageRequirement, usable = false }),
        Row(5, F("ITEM_MIN_LEVEL", 90), nil, { type = LT.UsageRequirement }),
        Row(6, F("ITEM_COOLDOWN_TIME_SEC", 12)),
        Row(7, G.SPELL_REAGENTS .. "毒藥"),
        Row(8, "一段沒有型別的金字描述", nil, { color = GOLD }),
        Row(9, "一行完全認不得的白字"),
    }, GAME, 53)
    -- 35能量：zhTW ENERGY_COST 是「%s能量」
    eq("耗能：能量", m.cost and m.cost.key, "ENERGY_COST")
    eq("認不得的右欄進 extras（左欄已認走）", m.extras[1] and m.extras[1].right, "神祕的右欄")
    eq("認不得的右欄：左欄不重複", m.extras[1] and m.extras[1].left, "")
    eq("需求：裝備匕首（紅字＝未達成）", m.requirements[1] and m.requirements[1].unmet, true)
    eq("需求：usable false", m.requirements[2] and m.requirements[2].unmet, true)
    eq("需求：等級 90 > 自己 80", m.requirements[3] and m.requirements[3].unmet, true)
    eq("剩餘冷卻進 details（橘）", m.details[1] and m.details[1].remaining, true)
    eq("材料進 details", m.details[2] and m.details[2].left, G.SPELL_REAGENTS .. "毒藥")
    eq("金字當描述", m.description[1], "一段沒有型別的金字描述")
    eq("認不得的白字進 extras", m.extras[2] and m.extras[2].left, "一行完全認不得的白字")

    m = P.ReadSpellRows({
        Row(1, "熊形態", nil, { type = LT.SpellName }),
        Row(2, G.SPELL_CAST_TIME_INSTANT),
        Row(3, "變成熊。", nil, { type = LT.SpellDescription }),
        Row(4, "", nil, { type = LT.NestedBlock, tooltipID = 77758 }),
        Row(5, "痛擊", nil, { type = LT.SpellName }),
        Row(6, F("RAGE_COST", 15)),
        Row(7, "造成20點傷害。", nil, { type = LT.SpellDescription }),
    }, GAME, 5487)
    eq("巢狀：外層名字", m.name, "熊形態")
    eq("巢狀：子法術名字", m.nested and m.nested.name, "痛擊")
    eq("巢狀：子法術圖示", m.nested and m.nested.icon, 1000 + 77758)
    eq("巢狀：子法術耗能", m.nested and m.nested.cost and m.nested.cost.key, "RAGE_COST")
    eq("巢狀：描述各歸各的", #m.description, 1)
    local view = P.ViewSpell(m)
    local heading
    for _, s in ipairs(view.sections) do if s.style == "heading" then heading = s end end
    eq("巢狀：小一號標題", heading and heading.rows[1].left, "痛擊")
    local _, _, _, env = Setup("zhTW")
    local tip = H.Tip(env, "GameTooltip", {})
    local st = {}
    check("巢狀：整份畫得出來", P.RenderView(P.Get(tip, st), tip, view, st))
end

------------------------------------------------------------
-- 4. 天賦面板：名字與等級在 data 之外、下一等級、我們的 ID 行不被吞
------------------------------------------------------------
do
    local P, F, G = Setup("zhTW")
    local m = P.ReadSpellRows({
        Row(2, "提高暴擊10%。", nil, { type = LT.SpellDescription }),
        { left = "烈焰之觸", lineIndex = 1, appended = true, color = WHITE },
        { left = F("TOOLTIP_TALENT_RANK", 1, 2), lineIndex = 3, appended = true, color = WHITE },
        { left = G.TOOLTIP_TALENT_NEXT_RANK, lineIndex = 4, appended = true, color = WHITE },
        { left = "提高暴擊20%。", lineIndex = 5, appended = true, color = GOLD },
        { left = "法術ID: |cffffffff123|r", lineIndex = 6, appended = true, color = GOLD },
    }, GAME, 123)
    eq("天賦：名字是後加的第 1 行", m.name, "烈焰之觸")
    eq("天賦：等級", m.talent and m.talent.rank, 1)
    eq("天賦：最高等級", m.talent and m.talent.max, 2)
    eq("天賦：描述沒被當名字", m.description[1], "提高暴擊10%。")
    eq("天賦：下一等級標籤", m.nextRank and m.nextRank.label, G.TOOLTIP_TALENT_NEXT_RANK)
    eq("天賦：下一等級內容", m.nextRank and m.nextRank.rows[1].left, "提高暴擊20%。")
    eq("天賦：帶色碼的 ID 行歸附屬框", m.appended[1] and m.appended[1].left, "法術ID: |cffffffff123|r")
    local view = P.ViewSpell(m)
    local cap
    for _, s in ipairs(view.sections) do if s.separator and s.separator.caption then cap = s end end
    eq("天賦：下一等級畫成 Caption", cap and cap.separator.caption, G.TOOLTIP_TALENT_NEXT_RANK)
    local _, _, _, env = Setup("zhTW")
    local tip = H.Tip(env, "GameTooltip", {})
    local st = {}
    check("天賦：整份畫得出來", P.RenderView(P.Get(tip, st), tip, view, st))
end

------------------------------------------------------------
-- 5. 四格：缺格與開關；數字色設定
------------------------------------------------------------
do
    local P, F, G, env, ns = Setup("zhTW")
    local m = P.ReadSpellRows({
        Row(1, "治療之觸", nil, { type = LT.SpellName }),
        Row(2, F("MANA_COST", "1,000")),
    }, GAME, 1)
    local view = P.ViewSpell(m)
    -- 量四格：把 Strip 畫到假 panel 上看文字
    local tip = H.Tip(env, "GameTooltip", {})
    local state = {}
    local panel = P.Get(tip, state)
    P.RenderView(panel, tip, view, state)
    local texts = {}
    for i = 1, panel.textsUsed do texts[panel.texts[i].text] = panel.texts[i] end
    check("四格：耗能值", texts[F("MANA_COST", "1,000")] ~= nil)
    check("四格：耗能值用資源色亮化", texts[F("MANA_COST", "1,000")].textColor[3] == 1 and texts[F("MANA_COST", "1,000")].textColor[1] == 0.5)
    check("四格：缺施法 → 立即施法、0.45 灰", texts[G.SPELL_CAST_TIME_INSTANT] and texts[G.SPELL_CAST_TIME_INSTANT].textColor[1] == 0.45)
    check("四格：缺冷卻 → 無", texts[G.NONE] ~= nil)
    check("四格：缺距離 → 自身", texts["Self"] ~= nil)
    check("四格：格標題", texts["Cost"] and texts["Cast"] and texts["Cooldown"] and texts["Range"])

    ns.db.panel.strip = false
    view = P.ViewSpell(m)
    eq("四格關：改成兩欄", view.sections[1].kind, "rows")
    eq("四格關：耗能在左欄", view.sections[1].rows[1].left, F("MANA_COST", "1,000"))

    ns.db.panel.numberColor = "none"
    eq("數字色 none", P.NumberHex(), nil)
    ns.db.panel.numberColor = "ff8800"
    eq("數字色 hex", P.NumberHex(), "ff8800")
    ns.db.panel.numberColor = "custom"
    ns.db.panel.numberCustom = { r = 1, g = 0.5, b = 0, a = 1 }
    eq("數字色 custom：用色票", P.NumberHex(), "ff8000")
    ns.db.panel.numberCustom = nil
    eq("數字色 custom 沒色票：退職業色", P.NumberHex(), "9fe3f5")
end

------------------------------------------------------------
-- 6. reader 入口：秘密行 → nil；原生右欄補位
------------------------------------------------------------
do
    local P, F, G, env = Setup("enUS")
    local tip = H.Tip(env, "GameTooltip", {
        { left = "Frostbolt" }, { left = G.SPELL_CAST_TIME_INSTANT, right = F("SPELL_RECAST_TIME_SEC", 6) },
    })
    local data = { id = 116, lines = {
        { type = LT.SpellName, lineIndex = 1, leftText = "Frostbolt" },
        { type = 0, lineIndex = 2, leftText = G.SPELL_CAST_TIME_INSTANT },   -- 右欄只在原生 FontString 上
    } }
    local m = P.readers.spell(tip, data)
    eq("原生右欄補位：冷卻", m and m.cooldown and m.cooldown.value, "6")
    eq("reader：行數", m and m.numLines, 2)

    data.lines[2].leftText = H.SECRET
    eq("秘密行 → nil", P.readers.spell(tip, data), nil)

    data.lines[2].leftText = G.SPELL_CAST_TIME_INSTANT
    env.GameTooltipTextRight2.text = H.SECRET
    eq("秘密的原生右欄 → nil", P.readers.spell(tip, data), nil)

    eq("沒有名字 → nil", P.ReadSpellRows({ Row(1, "") }, GAME, 1), nil)
end

H.finish("ReadSpell_test")
