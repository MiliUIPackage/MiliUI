------------------------------------------------------------
-- Panel/ReadItem.lua＋ViewItem.lua 的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/ReadItem_test.lua
--
-- fixture 是手拼的：每一行用 fixtures/GlobalStrings.lua（＋檔內幾條主屬性格式）的實值 format 出來。
-- ⚠ 真實物品的行佈局（尤其配方的「製造／材料」兩段）要靠 /mtip record 的資料再驗。
-- 覆蓋（三語）：護甲件（物品等級、提升等級、綁定、唯一、部位／護甲類、護甲、主／次／三屬性分類與排序、
-- 套裝名／物件／加成、耐久、職業限定、售價）、武器（傷害＋速度＋每秒傷害）、飾品（使用效果＋冷卻）、
-- 配方（技能需求、成品、材料擁有／需要）、消耗品（沒有部位）、比價框第一行「目前裝備」→ 標籤、
-- 別人加的行進 extras、秘密 → nil、Try 整合（物品 reader 登記後真的被用到）。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq = H.check, H.eq
local GS = dofile(here .. "/fixtures/GlobalStrings.lua")

-- 主屬性的完整格式（%c 是正負號）與部位名，三語實值
local EXTRA = {
    enUS = { ITEM_MOD_AGILITY = "%c%s Agility", ITEM_MOD_STAMINA = "%c%s Stamina", INVTYPE_HEAD = "Head",
        INVTYPE_2HWEAPON = "Two-Hand" },
    zhTW = { ITEM_MOD_AGILITY = "%c%s敏捷", ITEM_MOD_STAMINA = "%c%s耐力", INVTYPE_HEAD = "頭部",
        INVTYPE_2HWEAPON = "雙手" },
    zhCN = { ITEM_MOD_AGILITY = "%c%s 敏捷", ITEM_MOD_STAMINA = "%c%s 耐力", INVTYPE_HEAD = "头部",
        INVTYPE_2HWEAPON = "双手" },
}

local LT = H.Env().Enum.TooltipDataLineType
local WHITE = { 1, 1, 1 }
local GREEN = { 0, 1, 0 }
local GRAY = { 0.5, 0.5, 0.5 }
local RED = { 1, 0.125, 0.125 }
local GOLD = { 1, 0.82, 0 }
local EPIC = { 0.64, 0.21, 0.93 }

local function Setup(locale)
    local strings = {}
    for k, v in pairs(GS[locale]) do strings[k] = v end
    for k, v in pairs(EXTRA[locale]) do strings[k] = v end
    local env = H.Env(strings)
    env.C_Spell = { GetSpellTexture = function(id) return 1000 + id end }
    env.C_Item = { GetItemIconByID = function(x) return type(x) == "number" and 5000 + x or 7777 end,
        GetItemCount = function(name) return name == "Silk" and 5 or 1 end }
    env.C_CurrencyInfo = { GetCoinTextureString = function(c) return c .. "c" end }
    env.UnitLevel = function() return 80 end
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        Media = { WHITE8X8 = "white", NoSnap = function(t) return t end, Font = function() return "default.ttf" end, BarTexture = function() return "satin.png" end },
        playerClass = "MAGE",
        db = { general = { scale = 1, background = { r = 0.133, g = 0.133, b = 0.133, a = 1 },
            borderColor = { r = 0.18, g = 0.18, b = 0.18, a = 1 } },
            item = { panel = true }, spell = { panel = true },
            panel = { separators = true, strip = true, statMarkers = true, levelBadge = true, numberColor = "class" } },
        Skin = { State = {}, Poll = function() end, Unpoll = function() end, Each = function() end },
    }
    for _, f in ipairs({ "Libs/MiliUIWidgets/Secret.lua", "Panel/Patterns.lua", "Panel/Frame.lua", "Panel/Render.lua",
        "Panel/Native.lua", "Panel/ReadFallback.lua", "Panel/Try.lua", "Panel/ReadSpell.lua", "Panel/ViewSpell.lua",
        "Panel/ReadItem.lua", "Panel/ViewItem.lua" }) do
        H.Load(env, ns, f)
    end
    local function F(key, ...) return string.format(strings[key], ...) end
    return ns.Panel, F, strings, env, ns
end

local function Row(i, left, right, opts)
    local r = { left = left, right = right, lineIndex = i, color = WHITE }
    for k, v in pairs(opts or {}) do r[k] = v end
    return r
end
local function Blank(i) return Row(i, " ", nil, { type = LT.Blank }) end

local GAME = {
    itemIcon = function(x) return type(x) == "number" and 5000 + x or 7777 end,
    itemCount = function(name) return name == "Silk" and 5 or 1 end,
    playerLevel = function() return 80 end,
}

-- 屬性行：數字跟名字之間 zhTW 沒有空白、enUS／zhCN 有（照 ITEM_MOD_X 的格式）
local function StatLine(locale, value, shortName)
    return "+" .. value .. (locale == "zhTW" and "" or " ") .. shortName
end

------------------------------------------------------------
-- 1. 三語：護甲件（含套裝）
------------------------------------------------------------
for _, locale in ipairs({ "enUS", "zhTW", "zhCN" }) do
    local P, F, G = Setup(locale)
    local tag = locale .. " "
    local rows = {
        Row(1, "Shadowcraft Cap", nil, { type = LT.ItemName, color = EPIC }),
        Row(2, F("ITEM_LEVEL", 639), nil, { type = LT.ItemLevel, color = GOLD }),
        Row(3, F("ITEM_UPGRADE_TOOLTIP_FORMAT_STRING", "Hero", 4, 8), nil, { type = LT.ItemUpgradeLevel }),
        Row(4, G.ITEM_SOULBOUND, nil, { type = LT.ItemBinding }),
        Row(5, G.ITEM_UNIQUE_EQUIPPABLE),
        Row(6, G.INVTYPE_HEAD, "Leather", { type = LT.EquipSlot }),
        Row(7, F("ARMOR_TEMPLATE", "1,027")),
        Row(8, F("ITEM_MOD_AGILITY", 43, "150")),
        Row(9, F("ITEM_MOD_STAMINA", 43, "900")),
        Row(10, StatLine(locale, "80", G.ITEM_MOD_CRIT_RATING_SHORT), nil, { color = GREEN }),
        Row(11, StatLine(locale, "20", G.ITEM_MOD_CR_AVOIDANCE_SHORT), nil, { color = GREEN }),
        Row(12, StatLine(locale, "60", G.ITEM_MOD_HASTE_RATING_SHORT), nil, { color = GREEN }),
        Blank(13),
        Row(14, F("ITEM_SET_NAME", "Shadowcraft", 2, 5), nil, { color = GOLD }),
        Row(15, "  Shadowcraft Cap", nil, { color = GOLD }),
        Row(16, "  Shadowcraft Boots", nil, { color = GRAY }),
        Blank(17),
        Row(18, F("ITEM_SET_BONUS_GRAY", 2, "Increases damage."), nil, { color = GREEN }),
        Row(19, F("ITEM_SET_BONUS_GRAY", 4, "Even more."), nil, { color = GRAY }),
        Blank(20),
        Row(21, F("DURABILITY_TEMPLATE", 120, 165)),
        Row(22, F("ITEM_CLASSES_ALLOWED", "Rogue"), nil, { color = RED }),
        Row(23, F("ITEM_MIN_LEVEL", 80), nil, { type = LT.UsageRequirement }),
        Row(24, G.SELL_PRICE, nil, { type = LT.SellPrice, price = 123456 }),
        { left = "Item ID: 1234", lineIndex = 25, appended = true, color = GOLD },
    }
    local m = P.ReadItemRows(rows, GAME, { id = 1234 })
    eq(tag .. "名字", m.name, "Shadowcraft Cap")
    eq(tag .. "名字品質色", m.nameColor, EPIC)
    eq(tag .. "圖示", m.icon, 5000 + 1234)
    eq(tag .. "物品等級", m.itemLevel and m.itemLevel.value, 639)
    check(tag .. "提升等級", m.upgrade ~= nil)
    eq(tag .. "綁定", m.binding, G.ITEM_SOULBOUND)
    eq(tag .. "唯一", m.unique[1], G.ITEM_UNIQUE_EQUIPPABLE)
    eq(tag .. "部位", m.slot, G.INVTYPE_HEAD)
    eq(tag .. "護甲類", m.armorType, "Leather")
    eq(tag .. "護甲值", m.armor and m.armor.value, "1,027")
    eq(tag .. "屬性數", #m.stats, 5)
    eq(tag .. "敏捷＝主屬性", m.stats[1].category, "primary")
    eq(tag .. "耐力＝主屬性", m.stats[2].category, "primary")
    eq(tag .. "致命一擊＝次屬性", m.stats[3].category, "secondary")
    eq(tag .. "迴避＝三屬性", m.stats[4].category, "tertiary")
    eq(tag .. "套裝名", m.set and m.set.name, "Shadowcraft")
    eq(tag .. "套裝 2/5", m.set and (m.set.owned .. "/" .. m.set.total), "2/5")
    eq(tag .. "套裝物件數", m.set and #m.set.items, 2)
    eq(tag .. "套裝物件：擁有", m.set and m.set.items[1].owned, true)
    eq(tag .. "套裝物件：未擁有（灰）", m.set and m.set.items[2].owned, false)
    eq(tag .. "套裝加成：啟用", m.set and m.set.bonuses[1] and m.set.bonuses[1].active, true)
    eq(tag .. "套裝加成：未啟用", m.set and m.set.bonuses[2] and m.set.bonuses[2].active, false)
    eq(tag .. "耐久", m.durability and m.durability.cur, 120)
    eq(tag .. "職業限定（紅＝未達成）", m.restrictions[1] and m.restrictions[1].unmet, true)
    eq(tag .. "等級需求達成", m.levelReq and m.levelReq.unmet, false)
    eq(tag .. "售價", m.price, 123456)
    eq(tag .. "別人加的行進附屬框那一桶", m.appended[1] and m.appended[1].left, "Item ID: 1234")
    eq(tag .. "附屬框只有那一行", #m.appended, 1)
    eq(tag .. "主面板的「其他」沒有東西", #m.extras, 0)

    local view = P.ViewItem(m)
    eq(tag .. "等級徽章", view.badge, "639")
    eq(tag .. "標題第二行：護甲類 · 部位", view.header[2].badges[1][1], "Leather")
    eq(tag .. "第一段前是 ◆ 分隔", view.sections[1].separator and view.sections[1].separator.divider, true)
    check(tag .. "頁尾帶", view.footer ~= nil)
end

------------------------------------------------------------
-- 2. 武器、飾品、消耗品、比價框
------------------------------------------------------------
for _, locale in ipairs({ "enUS", "zhTW", "zhCN" }) do
    local P, F, G = Setup(locale)
    local tag = locale .. " "
    local m = P.ReadItemRows({
        Row(1, "Thunderfury", nil, { type = LT.ItemName }),
        Row(2, G.INVTYPE_2HWEAPON, "Sword", { type = LT.EquipSlot }),
        Row(3, F("DAMAGE_TEMPLATE", "65", "99"), G.SPEED .. " 3.60"),
        Row(4, F("DPS_TEMPLATE", "25.6")),
    }, GAME, { id = 19019 })
    eq(tag .. "武器：傷害", m.weapon and m.weapon.damage and m.weapon.damage.min, "65")
    eq(tag .. "武器：速度", m.weapon and m.weapon.speed and m.weapon.speed.value, "3.60")
    eq(tag .. "武器：每秒傷害", m.weapon and m.weapon.dps and m.weapon.dps.value, "25.6")
    eq(tag .. "武器：沒有 extras", #m.extras, 0)

    m = P.ReadItemRows({
        Row(1, "Trinket", nil, { type = LT.ItemName }),
        Row(2, G.ITEM_SPELL_TRIGGER_ONUSE .. "Heal yourself.", nil, { type = LT.ItemSpellTriggerOnUse, color = GREEN }),
        Row(3, F("ITEM_COOLDOWN_TOTAL_MIN", 2)),
    }, GAME, { id = 1 })
    eq(tag .. "飾品：使用效果", m.effects[1] and m.effects[1].kind, "use")
    eq(tag .. "飾品：前綴拆掉", m.effects[1] and m.effects[1].text, "Heal yourself.")
    eq(tag .. "飾品：標籤去冒號", m.effects[1] and m.effects[1].label, P.TriggerLabel("ITEM_SPELL_TRIGGER_ONUSE"))
    check(tag .. "飾品：標籤沒有冒號", not m.effects[1].label:find("[:：]$"))
    eq(tag .. "飾品：冷卻進細節", m.details[1] and m.details[1].left, F("ITEM_COOLDOWN_TOTAL_MIN", 2))

    m = P.ReadItemRows({
        Row(1, "Bread", nil, { type = LT.ItemName }),
        Row(2, G.ITEM_SPELL_TRIGGER_ONUSE .. "Eat.", nil, { type = LT.ItemSpellTriggerOnUse }),
    }, GAME, { id = 2 })
    eq(tag .. "消耗品：沒有部位", m.slot, nil)
    local view = P.ViewItem(m)
    eq(tag .. "消耗品：標題只有名字", #view.header, 1)

    m = P.ReadItemRows({
        Row(1, G.CURRENTLY_EQUIPPED),
        Row(2, "Old Sword", nil, { type = LT.ItemName }),
    }, GAME, { id = 3 })
    eq(tag .. "比價框：名字不是「目前裝備」", m.name, "Old Sword")
    eq(tag .. "比價框：data 裡的「目前裝備」行當標籤（舊式）", m.tag, G.CURRENTLY_EQUIPPED)
    eq(tag .. "比價框：沒有 extras", #m.extras, 0)
    -- K1：標籤照抄原生 CompareHeader 的字（第二顆「同時裝備」）
    m = P.ReadItemRows({ Row(1, "Blade", nil, { type = LT.ItemName }) }, GAME, { id = 4, compareHeader = G.IF_EQUIPPED_TOGETHER })
    eq(tag .. "K1：第二顆比價框的標籤是「同時裝備」", m.tag, G.IF_EQUIPPED_TOGETHER)
    m = P.ReadItemRows({ Row(1, "Blade", nil, { type = LT.ItemName }) }, GAME, { id = 4 })
    eq(tag .. "K1：沒有標頭就沒有標籤", m.tag, nil)
end

------------------------------------------------------------
-- 3. 配方（⚠ 推定的佈局）
------------------------------------------------------------
for _, locale in ipairs({ "enUS", "zhTW", "zhCN" }) do
    local P, F, G = Setup(locale)
    local tag = locale .. " "
    local m = P.ReadItemRows({
        Row(1, "Pattern: Silk Robe", nil, { type = LT.ItemName }),
        Row(2, G.ITEM_BIND_ON_PICKUP, nil, { type = LT.ItemBinding }),
        Row(3, F("ITEM_MIN_SKILL", "Tailoring", 75), nil, { color = RED }),
        Row(4, G.ITEM_SPELL_TRIGGER_ONUSE .. "Teaches you how to sew.", nil, { type = LT.ItemSpellTriggerLearn }),
        Blank(5),
        Row(6, "Silk Robe", nil, { type = LT.ItemName, color = { 0.12, 1, 0 } }),
        Row(7, "Chest", "Cloth", { type = LT.EquipSlot }),
        Row(8, F("ARMOR_TEMPLATE", "50")),
        Row(9, F("ITEM_MOD_STAMINA", 43, "10")),
        Blank(10),
        Row(11, G.SPELL_REAGENTS .. "Silk (3), Thread (2)"),
        Row(12, G.SELL_PRICE, nil, { type = LT.SellPrice, price = 500 }),
    }, GAME, { id = 4 })
    eq(tag .. "配方：名字", m.name, "Pattern: Silk Robe")
    eq(tag .. "配方：技能需求（紅）", m.skill and m.skill.unmet, true)
    eq(tag .. "配方：學習效果", m.effects[1] and m.effects[1].text, "Teaches you how to sew.")
    eq(tag .. "配方：成品名字", m.created and m.created.name, "Silk Robe")
    eq(tag .. "配方：成品護甲類", m.created and m.created.armorType, "Cloth")
    eq(tag .. "配方：成品屬性", m.created and #m.created.stats, 1)
    eq(tag .. "配方：外層沒有成品的屬性", #m.stats, 0)
    eq(tag .. "配方：材料數", m.reagents and #m.reagents, 2)
    eq(tag .. "配方：材料 1", m.reagents and m.reagents[1].name, "Silk")
    eq(tag .. "配方：材料 1 需要", m.reagents and m.reagents[1].count, 3)
    eq(tag .. "配方：材料 1 擁有", m.reagents and m.reagents[1].have, 5)
    eq(tag .. "配方：材料 2 擁有", m.reagents and m.reagents[2].have, 1)
    eq(tag .. "配方：售價記在外層", m.price, 500)

    local view = P.ViewItem(m)
    local captions = {}
    for _, s in ipairs(view.sections) do
        if s.separator and s.separator.caption then captions[#captions + 1] = s end
    end
    eq(tag .. "配方：兩個 Caption", #captions, 2)
    eq(tag .. "配方：製造", captions[1] and captions[1].separator.caption, "Creates")
    eq(tag .. "配方：材料", captions[2] and captions[2].separator.caption, "Reagents")
    local reagents = captions[2] and captions[2].rows
    eq(tag .. "配方：擁有 / 需要", reagents and reagents[1].right, "5 / 3")
    check(tag .. "配方：不足紅（1 < 2）", reagents and reagents[2].rightColor[1] == 1 and reagents[2].rightColor[2] == 0.34)
    check(tag .. "配方：材料圖示", reagents and reagents[1].left:find("|T7777:14|t", 1, true) ~= nil)
end

-- 材料標籤自己一行、材料逐行
do
    local P, F, G = Setup("zhTW")
    local m = P.ReadItemRows({
        Row(1, "圖樣：絲質長袍", nil, { type = LT.ItemName }),
        Row(2, G.SPELL_REAGENTS),
        Row(3, "Silk（3）"),
        Row(4, "線"),
        Blank(5),
        Row(6, "後面不是材料"),
    }, GAME, { id = 5 })
    eq("材料逐行：數量", m.reagents and #m.reagents, 2)
    eq("材料逐行：全形括號", m.reagents and m.reagents[1].count, 3)
    eq("材料逐行：沒寫數量＝1", m.reagents and m.reagents[2].count, 1)
    eq("材料逐行：空行之後不算", m.extras[1] and m.extras[1].left, "後面不是材料")
end

------------------------------------------------------------
-- 4. 秘密 → nil；Try 整合；屬性 ◆ 與徽章開關
------------------------------------------------------------
do
    local P, F, G, env, ns = Setup("enUS")
    local tip = H.Tip(env, "GameTooltip", {
        { left = "Shadowcraft Cap", color = EPIC }, { left = F("ITEM_LEVEL", 639) },
        { left = F("ITEM_MOD_AGILITY", 43, "150") }, { left = "Item ID: 1234" },
    })
    local data = { id = 1234, lines = {
        { type = LT.ItemName, lineIndex = 1, leftText = "Shadowcraft Cap", leftColor = { r = EPIC[1], g = EPIC[2], b = EPIC[3] } },
        { type = LT.ItemLevel, lineIndex = 2, leftText = F("ITEM_LEVEL", 639) },
        { type = 0, lineIndex = 3, leftText = F("ITEM_MOD_AGILITY", 43, "150") },
    } }
    local m = P.readers.item(tip, data)
    eq("reader：名字", m and m.name, "Shadowcraft Cap")
    eq("reader：後加的行", m and m.appended[1] and m.appended[1].left, "Item ID: 1234")
    data.lines[3].leftText = H.SECRET
    eq("秘密行 → nil", P.readers.item(tip, data), nil)
    data.lines[3].leftText = F("ITEM_MOD_AGILITY", 43, "150")

    -- Try 整合：登記的 reader／view 真的被用到（徽章就是證據；最簡 reader 沒有徽章）
    local state = {}
    ns.Skin.State[tip] = state
    P.Try(tip, state, 0, data)
    check("Try：panel 顯示", state.panel and state.panel.shown)
    check("Try：物品等級徽章", state.panel.badge.shown and state.panel.badgeText.text == "639")
    local diamonds = 0
    for i = 1, state.panel.texturesUsed do
        local t = state.panel.textures[i]
        if t.shown and t.rotation and t.rotation ~= 0 then diamonds = diamonds + 1 end
    end
    eq("Try：◆ 一顆分隔＋一顆屬性", diamonds, 2)

    ns.db.panel.levelBadge = false
    ns.db.panel.statMarkers = false
    P.settingsVersion = P.settingsVersion + 1
    P.Try(tip, state, 0, data)           -- 同一件：下一幀 Reconcile 才照新設定重畫
    env.FlushTimers()
    check("徽章關：沒有徽章", not state.panel.badge.shown)
    diamonds = 0
    for i = 1, state.panel.texturesUsed do
        local t = state.panel.textures[i]
        if t.shown and t.rotation and t.rotation ~= 0 then diamonds = diamonds + 1 end
    end
    eq("屬性 ◆ 關：只剩分隔那顆", diamonds, 1)
    local hasLevelText
    for i = 1, state.panel.textsUsed do
        if state.panel.texts[i].shown and state.panel.texts[i].text:find(F("ITEM_LEVEL", 639), 1, true) then hasLevelText = true end
    end
    check("徽章關：物品等級改寫在標題", hasLevelText)
end

------------------------------------------------------------
-- 4b. DisabledLine 看情境（2026-10-18 實機：被畫成紅字需求）、ErrorLine 仍紅；塑形／難度行進細節
------------------------------------------------------------
for _, locale in ipairs({ "enUS", "zhTW", "zhCN" }) do
    local P, F, G = Setup(locale)
    local tag = locale .. " "
    local m = P.ReadItemRows({
        Row(1, "Gauntlets", nil, { type = LT.ItemName }),
        Row(2, F("ITEM_MOD_AGILITY", 43, "150")),
        Row(3, StatLine(locale, "125", G.ITEM_MOD_INTELLECT_SHORT), nil, { type = LT.DisabledLine, color = GRAY }),
        Row(4, "You can't do that", nil, { type = LT.ErrorLine, color = RED }),
        Row(5, "Something greyed out", nil, { type = LT.DisabledLine, color = GRAY }),
        Blank(6),
        Row(7, F("ITEM_SET_NAME", "Flamewrath", 1, 5), nil, { color = GOLD }),
        Row(8, "  Flamewrath Gauntlets", nil, { color = GOLD }),
        Row(9, "  Flamewrath Shoulders", nil, { type = LT.DisabledLine, color = GRAY }),
        Blank(10),
        Row(11, G.ENCOUNTER_JOURNAL_SECTION_FLAG12, nil, { color = GREEN }),
        Row(12, G.TRANSMOGRIFIED_HEADER, nil, { color = { 1, 0.5, 1 } }),
        Row(13, "Pretty Gloves", nil, { color = { 1, 0.5, 1 } }),
        Row(14, F("TRANSMOGRIFIED_ENCHANT", "Mongoose"), nil, { color = { 1, 0.5, 1 } }),
    }, GAME, { id = 7 })
    local int
    for _, s in ipairs(m.stats) do if s.disabled then int = s end end
    check(tag .. "DisabledLine 屬性進 stats 且 disabled", int ~= nil)
    eq(tag .. "DisabledLine 屬性照分類（主屬性）", int and int.category, "primary")
    eq(tag .. "套裝裡的 DisabledLine 進 set.items", m.set and #m.set.items, 2)
    eq(tag .. "套裝裡的 DisabledLine：未擁有", m.set and m.set.items[2].owned, false)
    eq(tag .. "ErrorLine 仍是紅字需求", #m.requirements, 1)
    eq(tag .. "ErrorLine unmet", m.requirements[1] and m.requirements[1].unmet, true)
    local details = {}
    for _, d in ipairs(m.details) do details[d.left] = d end
    check(tag .. "其他 DisabledLine 進細節灰字", details["Something greyed out"] and details["Something greyed out"].color[1] == 0.45)
    check(tag .. "難度行進細節、保留原色", details[G.ENCOUNTER_JOURNAL_SECTION_FLAG12] and details[G.ENCOUNTER_JOURNAL_SECTION_FLAG12].color == GREEN)
    check(tag .. "塑形標籤進細節", details[G.TRANSMOGRIFIED_HEADER] ~= nil)
    check(tag .. "塑形標籤下一行（物品名）進細節", details["Pretty Gloves"] ~= nil)
    check(tag .. "幻象進細節", details[F("TRANSMOGRIFIED_ENCHANT", "Mongoose")] ~= nil)
    eq(tag .. "沒有東西掉進「其他」", #m.extras, 0)
end

-- 畫出來：灰的屬性與它的 ◆ 都是灰，不是職業色
do
    local P, F, G, env = Setup("zhTW")
    local m = P.ReadItemRows({
        Row(1, "護手", nil, { type = LT.ItemName }),
        Row(2, StatLine("zhTW", "125", G.ITEM_MOD_INTELLECT_SHORT), nil, { type = LT.DisabledLine, color = GRAY }),
    }, GAME, { id = 8 })
    local tip = H.Tip(env, "GameTooltip", {})
    local state = {}
    local panel = P.Get(tip, state)
    P.RenderView(panel, tip, P.ViewItem(m), state)
    local text, diamonds = nil, {}
    for i = 1, panel.textsUsed do if panel.texts[i].text == StatLine("zhTW", "125", G.ITEM_MOD_INTELLECT_SHORT) then text = panel.texts[i] end end
    for i = 1, panel.texturesUsed do
        local t = panel.textures[i]
        if t.shown and t.rotation and t.rotation ~= 0 then diamonds[#diamonds + 1] = t end
    end
    eq("灰屬性：文字 DIM", text and text.textColor[1], 0.45)
    local statDiamond = diamonds[#diamonds]
    eq("灰屬性：◆ 也 DIM", statDiamond and statDiamond.color[1], 0.45)
end

do
    -- N3：三屬性（速度）跟次屬性（加速）同一個綠，◆ 同一色；灰的（DisabledLine）照樣灰
    local P, F, G, env = Setup("zhTW")
    local speed = StatLine("zhTW", "59", G.ITEM_MOD_CR_SPEED_SHORT)
    local haste = StatLine("zhTW", "120", G.ITEM_MOD_HASTE_RATING_SHORT)
    local m = P.ReadItemRows({
        Row(1, "護腕", nil, { type = LT.ItemName }),
        Row(2, haste, nil, { color = GREEN }),
        Row(3, speed, nil, { color = GREEN }),
    }, GAME, { id = 10 })
    local cats = {}
    for _, st in ipairs(m.stats) do cats[st.text] = st.category end
    eq("N3 前提：速度是三屬性", cats[speed], "tertiary")
    eq("N3 前提：加速是次屬性", cats[haste], "secondary")
    local tip = H.Tip(env, "GameTooltip", {})
    local state = {}
    local panel = P.Get(tip, state)
    P.RenderView(panel, tip, P.ViewItem(m), state)
    local byText, diamonds = {}, {}
    for i = 1, panel.textsUsed do byText[panel.texts[i].text] = panel.texts[i] end
    for i = 1, panel.texturesUsed do
        local t = panel.textures[i]
        if t.shown and t.rotation and t.rotation ~= 0 then diamonds[#diamonds + 1] = t end
    end
    local function rgb(c) return c and table.concat({ c[1], c[2], c[3] }, ",") end
    eq("N3：速度跟加速同一個綠", rgb(byText[speed] and byText[speed].textColor), rgb(byText[haste] and byText[haste].textColor))
    eq("N3：那個綠就是效果綠", rgb(byText[speed] and byText[speed].textColor), rgb(P.LOOK.EFFECT))
    check("N3 前提：兩顆 ◆", #diamonds >= 2, #diamonds)
    eq("N3：◆ 同色", rgb(diamonds[#diamonds] and diamonds[#diamonds].color), rgb(diamonds[#diamonds - 1] and diamonds[#diamonds - 1].color))
end

------------------------------------------------------------
-- 5. 整份畫一次：每條自訂段落（大數字、屬性、效果、套裝、成品標題、頁尾耐久條）都真的跑過
------------------------------------------------------------
do
    local P, F, G, env = Setup("zhTW")
    local tip = H.Tip(env, "GameTooltip", {})
    local state = {}
    local panel = P.Get(tip, state)
    local function texts()
        local out = {}
        for i = 1, panel.textsUsed do if panel.texts[i].shown then out[panel.texts[i].text] = panel.texts[i] end end
        return out
    end

    local armor = P.ReadItemRows({
        Row(1, "暗影帽", nil, { type = LT.ItemName, color = EPIC }),
        Row(2, F("ITEM_LEVEL", 639), nil, { type = LT.ItemLevel }),
        Row(3, G.INVTYPE_HEAD, "皮甲", { type = LT.EquipSlot }),
        Row(4, F("ARMOR_TEMPLATE", "1,027")),
        Row(5, F("ITEM_MOD_AGILITY", 43, "150")),
        Row(6, StatLine("zhTW", "80", G.ITEM_MOD_CRIT_RATING_SHORT)),
        Row(7, G.ITEM_SPELL_TRIGGER_ONUSE .. "治療你自己150點。", nil, { type = LT.ItemSpellTriggerOnUse }),
        Row(8, F("ITEM_SET_NAME", "暗影", 1, 5), nil, { color = GOLD }),
        Row(9, "  暗影帽", nil, { color = GOLD }),
        Row(10, "「一段風味文字」", nil, { type = LT.FlavorText }),
        Row(11, F("DURABILITY_TEMPLATE", 120, 165)),
        Row(12, F("ITEM_CLASSES_ALLOWED", "盜賊"), nil, { color = RED }),
        Row(13, G.SELL_PRICE, nil, { type = LT.SellPrice, price = 123456 }),
    }, GAME, { id = 1 })
    check("整份畫：成功", P.RenderView(panel, tip, P.ViewItem(armor), state))
    local t = texts()
    check("整份畫：護甲大數字", t["1,027"] and t["1,027"].size == 15)
    check("整份畫：護甲標籤", t[G.ARMOR] ~= nil)
    check("整份畫：效果綠字", t["治療你自己150點。"] and t["治療你自己150點。"].textColor[2] == 0.88)
    check("整份畫：效果小標籤", t[P.TriggerLabel("ITEM_SPELL_TRIGGER_ONUSE")] ~= nil)
    check("整份畫：套裝 1/5", t["1/5"] ~= nil)
    check("整份畫：套裝物件前加 -", t["- 暗影帽"] ~= nil)
    check("整份畫：風味文字金", t["「一段風味文字」"] and t["「一段風味文字」"].textColor[1] == 0.86)
    check("整份畫：耐久數字", t["120 / 165"] ~= nil)
    check("整份畫：售價", t["123456c"] ~= nil)
    check("整份畫：職業限定紅", t[F("ITEM_CLASSES_ALLOWED", "盜賊")] and t[F("ITEM_CLASSES_ALLOWED", "盜賊")].textColor[2] == 0.34)
    check("整份畫：頁尾帶", panel.footer.shown)
    local bar
    for i = 1, panel.texturesUsed do if panel.textures[i].shown and panel.textures[i].texture == "satin.png" then bar = panel.textures[i] end end
    check("整份畫：耐久條是 satin、職業色", bar and bar.color[1] == 0.25)
    check("整份畫：耐久條長度照比例", bar and math.abs(bar.w - 54 * 120 / 165) <= 1)

    local recipe = P.ReadItemRows({
        Row(1, "圖樣：絲質長袍", nil, { type = LT.ItemName }),
        Row(2, F("ITEM_MIN_SKILL", "裁縫", 75)),
        Blank(3),
        Row(4, "絲質長袍", nil, { type = LT.ItemName }),
        Row(5, "胸部", "布甲", { type = LT.EquipSlot }),
        Row(6, F("ITEM_MOD_STAMINA", 43, "10")),
        Blank(7),
        Row(8, G.SPELL_REAGENTS .. "Silk（3），線（2）"),
    }, GAME, { id = 2 })
    recipe.created.icon = 4242
    check("配方畫：成功", P.RenderView(panel, tip, P.ViewItem(recipe), state))
    t = texts()
    check("配方畫：成品名字（小一號標題）", t["絲質長袍"] and t["絲質長袍"].size == 12)
    check("配方畫：成品灰字行", t["布甲 · 胸部"] ~= nil)
    check("配方畫：材料（圖示拆出去，文字只剩名字）", t["Silk"] and t["5 / 3"])
    local reagentIcon
    for i = 1, panel.texturesUsed do
        local x = panel.textures[i]
        if x.shown and x.texture == 7777 and x.w == 14 then reagentIcon = x end
    end
    check("配方畫：材料圖示另外畫（14）", reagentIcon ~= nil)
    local icon
    for i = 1, panel.texturesUsed do if panel.textures[i].shown and panel.textures[i].texture == 4242 then icon = panel.textures[i] end end
    check("配方畫：成品小圖示 24", icon and icon.w == 24)

    local weapon = P.ReadItemRows({
        Row(1, "雷霆之怒", nil, { type = LT.ItemName }),
        Row(2, F("DAMAGE_TEMPLATE", "65", "99"), G.SPEED .. " 3.60"),
        Row(3, F("DPS_TEMPLATE", "25.6")),
    }, GAME, { id = 3 })
    check("武器畫：成功", P.RenderView(panel, tip, P.ViewItem(weapon), state))
    t = texts()
    check("武器畫：每秒傷害大數字", t["25.6"] ~= nil)
    check("武器畫：傷害 · 速度", t[F("DAMAGE_TEMPLATE", "65", "99") .. " · " .. G.SPEED .. " 3.60"] ~= nil)
end

------------------------------------------------------------
-- M2：堆疊物品的頁尾售價「單價 ×數量 = 總價」；M1 的重複售價行也認單價
------------------------------------------------------------
do
    local P, F, G, env = Setup("zhTW")
    local function Game(unit, stack)
        local g = {}
        for k, v in pairs(GAME) do g[k] = v end
        g.itemSellPrice = function(x) return unit end
        g.stackCount = function(guid) return guid == "Item-1" and stack or nil end
        return g
    end
    local function Read(total, game, guid, extra)
        local rows = {
            Row(1, "絲綢", nil, { type = LT.ItemName }),
            Row(2, G.SELL_PRICE, nil, { type = LT.SellPrice, price = total }),
        }
        for _, r in ipairs(extra or {}) do rows[#rows + 1] = r end
        return P.ReadItemRows(rows, game, { id = 4306, guid = guid })
    end
    local function Drawn(m)
        local tip = H.Tip(env, "GameTooltip", {})
        local state = {}
        local panel = P.Get(tip, state)
        P.RenderView(panel, tip, P.ViewItem(m), state)
        local found
        for i = 1, panel.textsUsed do
            local t = panel.texts[i]
            if t.shown ~= false and t.text and t.text:find("c", 1, true) and t.text:match("^%d") then found = t.text end
        end
        return found, panel
    end

    local m = Read(6000, Game(3000, 2), "Item-1")
    eq("M2：堆疊數從 guid 拿", m.stackCount, 2)
    eq("M2：單價", m.unitPrice, 3000)
    local text, panel = Drawn(m)
    eq("M2：頁尾畫「單價 ×數量 = 總價」", text, "3000c ×2 = 6000c")
    check("M2：寬度量測算進整串", panel.width >= P.Measure("3000c ×2 = 6000c", { size = 13 }), panel.width)

    m = Read(9000, Game(3000, nil), nil)
    eq("M2：沒有 guid ⇒ 總價／單價整除", m.stackCount, 3)
    eq("M2：整除的畫法", (Drawn(m)), "3000c ×3 = 9000c")

    m = Read(7000, Game(3000, nil), nil)
    eq("M2：除不盡又沒有堆疊數 ⇒ 只畫總價", m.stackCount, nil)
    eq("M2：除不盡的畫法", (Drawn(m)), "7000c")

    m = Read(3000, Game(3000, 1), "Item-1")
    eq("M2：一個 ⇒ 只畫總價", m.stackCount, nil)
    eq("M2：一個的畫法", (Drawn(m)), "3000c")

    m = Read(6000, Game(nil, 2), "Item-1")
    eq("M2：單價拿不到 ⇒ 只畫總價", (Drawn(m)), "6000c")
    m = Read(6000, Game(0, 2), "Item-1")
    eq("M2：單價 0 ⇒ 只畫總價", (Drawn(m)), "6000c")

    -- M1 認單價：別家印單價的行也藏
    local Gold = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t"
    m = Read(6000, Game(3000, 2), "Item-1", {
        Row(3, "商人", "30 " .. Gold, { appended = true }),
        Row(4, "售價: 60 " .. Gold, nil, { appended = true }),
        Row(5, "拍賣", "45 " .. Gold, { appended = true }),
    })
    local lefts = {}
    for _, e in ipairs(m.appended) do lefts[#lefts + 1] = e.left end
    eq("M1＋M2：單價行與總價行都藏、別的金額留著", table.concat(lefts, "|"), "拍賣")
end

do
    -- 售價 1 銅（低等物品很常見）：純數字 1 的行不能被當成售價（2026-10-19 實機誤殺）
    local P, F, G = Setup("zhTW")
    local Copper = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t"
    local m = P.ReadItemRows({
        Row(1, "混亂能量爐缸", nil, { type = LT.ItemName }),
        Row(2, G.SELL_PRICE, nil, { type = LT.SellPrice, price = 1 }),
        Row(3, "庫存", "|cff66bbff總計：|cffffffff1|r|r", { appended = true }),
        Row(4, "  角色1", "|cff66bbff背包：|cffffffff1|r|r", { appended = true }),
        Row(5, "分解", "x1", { appended = true }),
        Row(6, "商人 x1", "|cffffffff1 " .. Copper .. "|r", { appended = true }),
        Row(7, "售價: 1|A:coin-copper:14:14:2:0|a", nil, { appended = true }),
    }, GAME, { id = 9 })
    local lefts = {}
    for _, e in ipairs(m.appended) do lefts[#lefts + 1] = e.left end
    eq("price=1：純數字 1 的行全留、帶銅幣圖示的兩行藏", table.concat(lefts, "|"), "庫存|  角色1|分解")
end

H.finish("ReadItem_test")
