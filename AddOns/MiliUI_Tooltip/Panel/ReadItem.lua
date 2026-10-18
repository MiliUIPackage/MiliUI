------------------------------------------------------------
-- 物品 reader：CollectLines 的 rows → model（含配方的「製造」成品與「材料」）
--
-- 純邏輯（Panel.ReadItemRows 吃 rows＋game 介面，可離線測）。認法：
--   * 型別優先：ItemName、ItemLevel、ItemUpgradeLevel、ItemQuality、ProfessionCraftingQuality、ItemBinding、
--     EquipSlot（左部位、右護甲類）、FlavorText、SellPrice、ItemSpellTrigger*、GemSocket*、
--     ItemEnchantmentPermanent、UsageRequirement、TradeTimeRemaining、ErrorLine／DisabledLine、NestedBlock
--   * 沒型別的行丟 Patterns：屬性（分類）、護甲、傷害＋速度、每秒傷害、耐久、套裝名／套裝物件／套裝加成、
--     等級需求、技能需求、製造者、職業／種族／聲望／專精限定、冷卻、附魔、唯一、綁定
--   * 別人後加的行（appended）一律進 extras；認不得的進 extras。**不許少行**
--
-- 配方（⚠ 12.1 的真實行結構還沒有 /mtip record 的資料，以下是照 GlobalStrings 與舊版佈局推定、待實機）：
--   第二個 ItemName（或 Item 型的 NestedBlock）之後的行屬於 created 子 model（成品）；
--   ITEM_MIN_SKILL → model.skill；SPELL_REAGENTS 開頭的行（或它之後到空行為止的行）→ model.reagents。
--   技能需求、材料、售價一律記在外層（配方本身），不管目前在讀哪一段。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local Panel = ns.Panel
local Patterns = ns.Patterns

local LT = Enum and Enum.TooltipDataLineType or {}
local ITEM_TYPE = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
Panel.readers = Panel.readers or {}

local Trim, Num = Panel.Trim, Panel.Num
local LOOK_DIM = Panel.LOOK.DIM
local LOOK_SECONDARY = Panel.LOOK.SECONDARY

-- 去掉 \r（暴雪的多段文字用 \r\n 接）
local function NoCR(s) return (s:gsub("\r", "")) end

-- 標題補充區裡還允許出現的型別（ItemName 之後、ItemBinding／EquipSlot／第一行本體之前）
local HEADER_TYPES = { ItemLevel = true, ItemUpgradeLevel = true, ItemQuality = true, ProfessionCraftingQuality = true }
local LT_NAME = {}
for name, value in pairs(LT) do LT_NAME[value] = name end

-- 標題補充區裡認得出用途的行照常分流，不收進補充行：本體（屬性、護甲、傷害…）與有固定位置的欄位。
-- 難度、虛無鍛造、已塑形為…這些（認不出、或本來就屬於標題的）才是補充行
local KNOWN_FIELDS = { "armor", "damage", "dps", "block", "durability", "setName", "setBonus", "level", "skill",
    "restriction", "binding", "unique", "equipped", "itemLevel", "upgrade", "craftQuality", "maker", "enchantTemp" }
local function Recognized(plain)
    if Patterns.Stat(plain) then return true end
    for _, field in ipairs(KNOWN_FIELDS) do
        if Patterns.Find(field, plain) then return true end
    end
    if Patterns.Prefix("SPELL_REAGENTS", plain) then return true end
    for _, key in ipairs({ "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONEQUIP", "ITEM_SPELL_TRIGGER_ONPROC" }) do
        if Patterns.Prefix(key, plain) then return true end
    end
    return false
end

local function Typed(row, name)
    return row.type ~= nil and LT[name] ~= nil and row.type == LT[name]
end

-- 灰字（未擁有的套裝件、未啟用的套裝加成）
local function IsGray(c)
    if not c then return false end
    return c[1] < 0.65 and math.abs(c[1] - c[2]) < 0.08 and math.abs(c[2] - c[3]) < 0.08
end
Panel.IsGray = IsGray

local function Plain(text)
    return Trim(Patterns.StripColors(text or ""))
end

local function NewItem()
    return {
        kind = "item", stats = {}, effects = {}, sockets = {}, enchants = {}, requirements = {},
        restrictions = {}, flavor = {}, details = {}, extras = {}, unique = {},
        appended = {},     -- 別人後加的行（附屬框）
    }
end

local TRIGGERS = {
    { key = "ITEM_SPELL_TRIGGER_ONUSE", type = "ItemSpellTriggerOnUse", kind = "use" },
    { key = "ITEM_SPELL_TRIGGER_ONEQUIP", type = "ItemSpellTriggerOnEquip", kind = "equip" },
    { key = "ITEM_SPELL_TRIGGER_ONPROC", type = "ItemSpellTriggerOnProc", kind = "proc" },
}

-- 「使用：」→「使用」：標籤去掉結尾的冒號（半形、全形）與空白
local function TriggerLabel(key)
    local label = _G[key]
    if type(label) ~= "string" then return nil end
    label = label:gsub("%s+$", "")
    label = label:gsub(":$", ""):gsub("：$", "")
    return label
end
Panel.TriggerLabel = TriggerLabel

local function AddEffect(part, row, text)
    for _, t in ipairs(TRIGGERS) do
        local rest = Patterns.Prefix(t.key, text)
        if rest or Typed(row, t.type) then
            part.effects[#part.effects + 1] = { kind = t.kind, label = TriggerLabel(t.key), text = NoCR(rest or text) }
            return true
        end
    end
    if Typed(row, "ItemSpellTriggerLearn") then
        part.effects[#part.effects + 1] = {
            kind = "use", label = TriggerLabel("ITEM_SPELL_TRIGGER_ONUSE"),
            text = Patterns.Prefix("ITEM_SPELL_TRIGGER_ONUSE", text) or text,
        }
        return true
    end
end

-- 材料：「材料：|n絲綢布 (3), 線 (1)」或標籤自己一行、材料逐行
local function ParseReagents(model, text, game)
    for piece in (text:gsub("|n", "\n"):gsub("，", ","):gsub("、", ",") .. "\n"):gmatch("([^\n,]+)") do
        -- ⚠ 全形括號是多位元組字，不能放進 [] 字元類（會變成逐位元組比對）⇒ 先換成半形
        local item = Trim(Patterns.StripColors(piece)):gsub("（", "("):gsub("）", ")")
        if item ~= "" then
            local name, count = item:match("^(.-)%s*%(%s*(%d+)%s*%)$")
            name = Trim(name or item)
            count = Num(count) or 1
            local reagent = { name = name, count = count }
            if game then
                reagent.have = game.itemCount and game.itemCount(name) or nil
                reagent.icon = game.itemIcon and game.itemIcon(name) or nil
            end
            model.reagents = model.reagents or {}
            model.reagents[#model.reagents + 1] = reagent
        end
    end
end

-- 沒型別的一段文字；回 true＝認走了
local function ClassifyText(part, model, row, text, game)
    local plain = Plain(text)
    if plain == "" then return true end
    local key, a, b

    if Patterns.Find("equipped", plain) then
        model.tag = plain
        return true
    end
    key, a = Patterns.Find("itemLevel", plain)
    if key then part.itemLevel = { text = plain, value = Num(a) } return true end
    key = Patterns.Find("upgrade", plain)
    if key then part.upgrade = text return true end
    key = Patterns.Find("craftQuality", plain)
    if key then part.craftQuality = text return true end
    if Patterns.Find("binding", plain) then part.binding = plain return true end
    if Patterns.Find("unique", plain) then part.unique[#part.unique + 1] = plain return true end

    if AddEffect(part, row, text) then return true end

    key, a = Patterns.Find("armor", plain)
    if key then part.armor = { text = plain, value = a } return true end
    key, a, b = Patterns.Find("damage", plain)
    if key then
        part.weapon = part.weapon or {}
        part.weapon.damage = { text = plain, min = a, max = b }
        return true
    end
    key, a = Patterns.Find("dps", plain)
    if key then
        part.weapon = part.weapon or {}
        part.weapon.dps = { text = plain, value = a }
        return true
    end
    local value, statKey, category = Patterns.Stat(plain)
    if value then
        part.stats[#part.stats + 1] = { text = plain, value = value, key = statKey, category = category, color = row.color }
        return true
    end
    key, a = Patterns.Find("block", plain)
    if key then part.block = { text = plain, value = a } return true end
    if Patterns.Find("enchantTemp", plain) then
        part.enchants[#part.enchants + 1] = { left = text, color = row.color }
        part.lastEnchant = true
        return true
    end
    if Patterns.Find("socketable", plain) then
        part.details[#part.details + 1] = { left = plain, color = LOOK_SECONDARY }
        return true
    end
    key, a, b = Patterns.Find("durability", plain)
    if key then part.durability = { text = plain, cur = Num(a), max = Num(b) } return true end

    local c
    key, a, b, c = Patterns.Find("setName", plain)
    if key and a ~= true and Num(b) and Num(c) then
        part.set = { name = Trim(a), text = plain, owned = Num(b), total = Num(c), items = {}, bonuses = {} }
        part.inSet = true
        return true
    end
    key = Patterns.Find("setBonus", plain)
    if key then
        local holder = part.set or part
        holder.bonuses = holder.bonuses or {}
        holder.bonuses[#holder.bonuses + 1] = { text = plain, active = not IsGray(row.color) }
        return true
    end

    key = Patterns.Find("level", plain)
    if key then
        part.levelReq = { text = plain, unmet = Panel.Unmet(row, plain, game) }
        return true
    end
    key = Patterns.Match("ITEM_MIN_SKILL", plain)
    if key then
        model.skill = { text = plain, unmet = Panel.IsRed(row.color) }
        return true
    end
    key = Patterns.Find("restriction", plain)
    if key then
        part.restrictions[#part.restrictions + 1] = { text = plain, unmet = Panel.IsRed(row.color) }
        return true
    end
    if Patterns.Find("maker", text) or Patterns.Find("maker", plain) then
        part.maker = text
        return true
    end
    local rest = Patterns.Prefix("SPELL_REAGENTS", plain)
    if rest then
        -- 材料寫在同一行就到此為止；標籤自己一行的話，之後到空行為止的行都是材料
        if rest ~= "" then
            ParseReagents(model, rest, game)
        else
            model.inReagents = true
        end
        return true
    end
    if Patterns.Find("enchant", plain) then
        part.enchants[#part.enchants + 1] = { left = text, color = row.color }
        return true
    end
    key = Patterns.Find("cooldown", plain)
    if key then
        part.details[#part.details + 1] = { left = plain }
        return true
    end
    key = Patterns.Find("cooldownLeft", plain)
    if key then
        part.details[#part.details + 1] = { left = plain, remaining = true }
        return true
    end
    if Patterns.Match("ITEM_SOCKET_BONUS", plain) then
        part.sockets[#part.sockets + 1] = { left = text, color = row.color }
        return true
    end
    if Patterns.Match("ITEM_REQ_SKILL", plain) then
        part.requirements[#part.requirements + 1] = { left = plain, unmet = Panel.IsRed(row.color) }
        return true
    end
    -- 塑形與難度：暴雪自己的資訊行，放細節區、保留原色
    key = Patterns.Find("transmog", plain)
    if key then
        part.details[#part.details + 1] = { left = text, color = row.color }
        -- 只有標籤的那一行：下一行是塑形成的物品名
        if key == "TRANSMOGRIFIED_HEADER" then part.transmogNext = true end
        return true
    end
    if Patterns.Find("difficulty", plain) then
        part.details[#part.details + 1] = { left = text, color = row.color }
        return true
    end
    if part.inSet then
        part.set.items[#part.set.items + 1] = { text = plain, owned = not IsGray(row.color) }
        return true
    end
    return false
end

-- 認不得的行：暴雪 data 的進主面板「其他」區；別人後加的（appended）進附屬框那一桶
local function Extra(part, row, left, right, model)
    local list = row.appended and model and model.appended or part.extras
    list[#list + 1] = { left = left or "", right = right, color = row.color, rightColor = row.rightColor }
end

local function IsBreak(row)
    if Typed(row, "Blank") or Typed(row, "Separator") then return true end
    return Plain(row.left) == "" and not row.right
end

-- 速度：右欄「速度 3.60」（WEAPON_SPEED 或 SPEED 開頭＋數字）
local function Speed(text)
    local plain = Plain(text)
    for _, key in ipairs({ "WEAPON_SPEED", "SPEED" }) do
        local rest = Patterns.Prefix(key, plain)
        if rest and rest:match("^[%d%.,]+$") then return plain, rest end
    end
end

-- rows：CollectLines 的結果；game：{ itemIcon(x), itemCount(x), playerLevel() }；opts：{ id, compareHeader }
function Panel.ReadItemRows(rows, game, opts)
    opts = opts or {}
    local model = NewItem()
    local part = model

    for _, row in ipairs(rows) do
        local left, right = row.left or "", row.right
        local transmogNext = part.transmogNext
        part.transmogNext = nil
        local lastEnchant = part.lastEnchant
        part.lastEnchant = nil
        -- 標題補充區：ItemName 之後、到 ItemBinding／EquipSlot／效果這類型別行為止
        if part.inHeader and row.type ~= nil and row.type ~= LT.None then
            if not HEADER_TYPES[LT_NAME[row.type]] then part.inHeader = nil end
        end
        if row.appended then
            if Plain(left) ~= "" or (right and Plain(right) ~= "") then Extra(model, row, left, right, model) end
        elseif Typed(row, "SellPrice") then
            -- 售價那行的文字是空的（錢幣是另外的框）：要在「空行＝分段」之前認走
            model.price = row.price
        elseif IsBreak(row) then
            part.inSet = false
            model.inReagents = false
        elseif Typed(row, "ItemName") or (not part.name and row.lineIndex == 1 and not Patterns.Find("equipped", Plain(left))) then
            if not part.name then
                part.name = Trim(Patterns.StripTextures(left))
                part.nameColor = row.color
                part.inHeader = true
                if right and Plain(right) ~= "" then part.subtitle = right end
            else
                -- 第二個名字：配方的成品從這裡開始
                local created = NewItem()
                created.name = Trim(Patterns.StripTextures(left))
                created.nameColor = row.color
                created.inHeader = true
                model.created = created
                part = created
            end
        elseif Typed(row, "NestedBlock") then
            if row.tooltipType == nil or row.tooltipType == ITEM_TYPE then
                local created = NewItem()
                created.id = S.PlainNumber(row.tooltipID)
                model.created = created
                part = created
            end
        elseif model.inReagents and (row.type == nil or row.type == LT.None) then
            ParseReagents(model, left .. (right and ("," .. right) or ""), game)
        elseif Typed(row, "ItemLevel") then
            local _, v = Patterns.Find("itemLevel", Plain(left))
            part.itemLevel = { text = Plain(left), value = Num(v) }
        elseif Typed(row, "ItemUpgradeLevel") then
            part.upgrade = left
        elseif Typed(row, "ItemQuality") then
            part.quality = left
        elseif Typed(row, "ProfessionCraftingQuality") then
            part.craftQuality = left
        elseif Typed(row, "ItemBinding") then
            part.binding = Plain(left)
            if right then Extra(part, row, "", right) end
        elseif Typed(row, "EquipSlot") then
            part.slot = Plain(left) ~= "" and Plain(left) or nil
            part.armorType = right and Plain(right) ~= "" and Plain(right) or nil
        elseif Typed(row, "FlavorText") then
            part.flavor[#part.flavor + 1] = NoCR(left)
        elseif Typed(row, "GemSocket") then
            part.sockets[#part.sockets + 1] = { left = left, right = right, color = row.color,
                gemIcon = row.gemIcon, socketType = row.socketType }
            part.lastEnchant = true
        elseif Typed(row, "GemSocketEnchantment") or Typed(row, "ItemEnchantmentPermanent") then
            part.enchants[#part.enchants + 1] = { left = left, right = right, color = row.color }
            part.lastEnchant = true
        elseif part.inHeader and (row.type == nil or row.type == LT.None) and not right
            and not Recognized(Plain(left)) then
            -- 標題補充行（難度、虛無鍛造、已塑形為…）：保留原字串與色碼，照 \n 拆列
            part.headerRows = part.headerRows or {}
            for piece in (NoCR(left) .. "\n"):gmatch("(.-)\n") do
                if Plain(piece) ~= "" then
                    part.headerRows[#part.headerRows + 1] = { left = piece, color = row.color }
                end
            end
        elseif Typed(row, "TradeTimeRemaining") then
            part.details[#part.details + 1] = { left = left }
        elseif Typed(row, "ErrorLine") then
            part.requirements[#part.requirements + 1] = { left = left, unmet = true }
        elseif Typed(row, "DisabledLine") then
            -- 灰字的「不適用」行，原版就是灰字，不是需求未達成：先看情境
            local plain = Plain(left)
            local value, statKey, category = Patterns.Stat(plain)
            if part.inSet and part.set then
                -- 套裝清單裡沒擁有的那一件
                part.set.items[#part.set.items + 1] = { text = plain, owned = false }
            elseif value then
                -- 同職業其他專精用的主屬性：照分類排，畫灰
                part.stats[#part.stats + 1] = { text = plain, value = value, key = statKey, category = category,
                    color = row.color, disabled = true }
            else
                part.details[#part.details + 1] = { left = left, color = LOOK_DIM }
            end
        elseif Typed(row, "UsageRequirement") then
            local plain = Plain(left)
            if Patterns.Find("level", plain) then
                part.levelReq = { text = plain, unmet = Panel.Unmet(row, plain, game) }
            elseif Patterns.Match("ITEM_MIN_SKILL", plain) then
                model.skill = { text = plain, unmet = Panel.Unmet(row, plain, game) }
            elseif Patterns.Find("restriction", plain) then
                part.restrictions[#part.restrictions + 1] = { text = plain, unmet = Panel.Unmet(row, plain, game) }
            else
                part.requirements[#part.requirements + 1] = { left = plain, unmet = Panel.Unmet(row, plain, game) }
            end
        else
            part.inHeader = nil          -- 認得出用途的無型別行一出現，標題補充區就結束
            local okLeft = ClassifyText(part, model, row, left, game)
            local okRight = true
            if right and Plain(right) ~= "" then
                local speedText, speed = Speed(right)
                if speedText then
                    part.weapon = part.weapon or {}
                    part.weapon.speed = { text = speedText, value = speed }
                else
                    okRight = false
                end
            end
            if not okLeft and transmogNext and not right then
                part.details[#part.details + 1] = { left = left, color = row.color }
            elseif not okLeft and lastEnchant and not right then
                -- 緊接在附魔／寶石行之後、同一段：臨時附魔（pattern 認不出時的鄰接規則）
                part.enchants[#part.enchants + 1] = { left = left, color = row.color }
                part.lastEnchant = true
            elseif not okLeft or not okRight then
                Extra(part, row, okLeft and "" or left, (not okRight) and right or nil)
            end
        end
    end

    model.inReagents, model.inSet = nil, nil
    if model.created then model.created.inSet = nil end
    if not model.name or model.name == "" then return end
    model.id = S.PlainNumber(opts.id)
    if game and game.itemIcon and model.id then model.icon = game.itemIcon(model.id) end
    local created = model.created
    if created and game and game.itemIcon and created.id then created.icon = game.itemIcon(created.id) end
    -- 比價框：標籤照抄原生 CompareHeader 的字（「已裝備」／「同時裝備」），沒有標頭就不畫
    if opts.compareHeader then model.tag = opts.compareHeader end
    return model
end

------------------------------------------------------------
-- 遊戲端介面（測試換成假的）
------------------------------------------------------------
local Game = Panel.Game

function Game.itemIcon(x)
    if not (C_Item and C_Item.GetItemIconByID) then return end
    local ok, icon = pcall(C_Item.GetItemIconByID, x)
    return ok and S.PlainNumber(icon) or nil
end

function Game.itemCount(x)
    if not (C_Item and C_Item.GetItemCount) then return end
    local ok, n = pcall(C_Item.GetItemCount, x, true)    -- 含銀行
    return ok and S.PlainNumber(n) or nil
end

Panel.readers.item = function(tip, data, _, rows, n)
    if not rows then rows, n = Panel.CollectLines(tip, data) end
    if not rows then return end
    local model = Panel.ReadItemRows(rows, Panel.Game, {
        id = data.id,
        compareHeader = Panel.CompareHeaderText(tip),
    })
    if not model then return end
    model.rows, model.numLines = rows, n
    return model
end
