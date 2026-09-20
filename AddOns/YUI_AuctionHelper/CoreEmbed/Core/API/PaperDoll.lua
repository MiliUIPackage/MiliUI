do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local PaperDoll = YUI.API.PaperDoll or {}
YUI.API.PaperDoll = PaperDoll

local Item = YUI.API.Item
local Security = YUI.API.Security

local ITEM_SECONDARY_STAT_RULES = {
    { id = "haste", key = "ITEM_MOD_HASTE_RATING_SHORT", priority = 1 },
    { id = "crit", key = "ITEM_MOD_CRIT_RATING_SHORT", priority = 2 },
    { id = "versatility", key = "ITEM_MOD_VERSATILITY", priority = 3 },
    { id = "mastery", key = "ITEM_MOD_MASTERY_RATING_SHORT", priority = 4 },
}
local EQUIPMENT_SECONDARY_STAT_IDS = { "crit", "haste", "mastery", "versatility" }

local ENCHANTABLE_SLOT_KEYS = {
    head = true,
    shoulder = true,
    chest = true,
    legs = true,
    feet = true,
    finger1 = true,
    finger2 = true,
    mainhand = true,
    offhand = true,
}

local WEAPON_SLOT_KEYS = {
    mainhand = true,
    offhand = true,
}

local SOCKET_ADDABLE_SLOT_KEYS = {
    head = true,
    wrist = true,
    waist = true,
}

-- Midnight Season 2 starts at Adventurer 1/6 (item level 266). Keep the
-- seasonal threshold beside the slot rule so a future season only updates
-- one value instead of spreading item-level checks through the scanner.
local SOCKET_ADDABLE_MIN_ITEM_LEVEL = 266
local SOCKET_ADDABLE_MIN_CRAFTED_ITEM_LEVEL = 299

local EMPTY_SOCKET_PREFIX = "EMPTY_SOCKET_"
local CRAFTED_QUALITY_ATLAS_PREFIX = "|A:Professions-ChatIcon-Quality-Tier"

local function IsSecretValue(value)
    local security = (YUI.API and YUI.API.Security) or Security
    if security and type(security.IsSecretValue) == "function" then
        local ok, secret = pcall(security.IsSecretValue, value)
        if ok then return secret == true end
    end

    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if ok then return secret == true end
    end

    return false
end

local function ContainsSecretValue(value)
    if IsSecretValue(value) then return true end
    if type(value) ~= "table" then return false end

    for _, nested in pairs(value) do
        if IsSecretValue(nested) then return true end
    end

    return false
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then return nil, false end
    local ok, value, second, third, fourth = pcall(func, ...)
    if not ok then return nil, false end
    return value, true, second, third, fourth
end

local function ClearRecord(record)
    if type(record) ~= "table" then return end
    for key in pairs(record) do
        record[key] = nil
    end
end

local function ResetRecordArray(records)
    records = records or {}
    local pool = records._pool
    if type(pool) ~= "table" then
        pool = {}
        records._pool = pool
    end
    for index = #records, 1, -1 do
        records[index] = nil
    end
    for index = 1, #pool do
        ClearRecord(pool[index])
    end
    return records, pool
end

local function AcquireRecord(records, pool, index)
    local record = pool[index]
    if type(record) ~= "table" then
        record = {}
        pool[index] = record
    else
        ClearRecord(record)
    end
    records[index] = record
    return record
end

local function ResolveSlot(slotName, fallbackID, fallbackTexture)
    local slotID, texture
    if type(GetInventorySlotInfo) == "function" then
        local resolvedID, ok, resolvedTexture = SafeCall(GetInventorySlotInfo, slotName)
        if ok then
            slotID = resolvedID
            texture = resolvedTexture
        end
    end

    return {
        name = slotName,
        slotID = slotID or fallbackID,
        texture = texture or fallbackTexture,
    }
end

local SLOT_DEFINITIONS = {
    { key = "head", labelKey = "slot.head", slot = ResolveSlot("HeadSlot", 1) },
    { key = "neck", labelKey = "slot.neck", slot = ResolveSlot("NeckSlot", 2) },
    { key = "shoulder", labelKey = "slot.shoulder", slot = ResolveSlot("ShoulderSlot", 3) },
    { key = "back", labelKey = "slot.back", slot = ResolveSlot("BackSlot", 15) },
    { key = "chest", labelKey = "slot.chest", slot = ResolveSlot("ChestSlot", 5) },
    { key = "wrist", labelKey = "slot.wrist", slot = ResolveSlot("WristSlot", 9) },
    { key = "hands", labelKey = "slot.hands", slot = ResolveSlot("HandsSlot", 10) },
    { key = "waist", labelKey = "slot.waist", slot = ResolveSlot("WaistSlot", 6) },
    { key = "legs", labelKey = "slot.legs", slot = ResolveSlot("LegsSlot", 7) },
    { key = "feet", labelKey = "slot.feet", slot = ResolveSlot("FeetSlot", 8) },
    { key = "finger1", labelKey = "slot.finger1", slot = ResolveSlot("Finger0Slot", 11) },
    { key = "finger2", labelKey = "slot.finger2", slot = ResolveSlot("Finger1Slot", 12) },
    { key = "trinket1", labelKey = "slot.trinket1", slot = ResolveSlot("Trinket0Slot", 13) },
    { key = "trinket2", labelKey = "slot.trinket2", slot = ResolveSlot("Trinket1Slot", 14) },
    { key = "mainhand", labelKey = "slot.mainhand", slot = ResolveSlot("MainHandSlot", 16) },
    { key = "offhand", labelKey = "slot.offhand", slot = ResolveSlot("SecondaryHandSlot", 17) },
}

local SLOT_BY_KEY = {}
for _, definition in ipairs(SLOT_DEFINITIONS) do
    SLOT_BY_KEY[definition.key] = definition
end

function PaperDoll.GetSlotDefinitions()
    return SLOT_DEFINITIONS
end

function PaperDoll.GetSlotDefinition(key)
    return SLOT_BY_KEY[key]
end

local function NormalizeItemInfo(link)
    if not link or not Item or type(Item.GetInfo) ~= "function" then
        return nil
    end

    local info = Item.GetInfo(link)
    if type(info) ~= "table" then return nil end

    local normalized = {
        name = info.name,
        icon = info.texture,
        quality = info.quality,
        level = info.level,
        itemID = info.itemID,
        classID = info.classID,
        equipLoc = info.equipLoc,
        expansionID = info.expansionID,
    }

    for key, value in pairs(normalized) do
        if IsSecretValue(value) then
            normalized[key] = nil
        end
    end

    return normalized
end

local function GetQualityID(name, fallback)
    local itemQuality = _G.Enum and _G.Enum.ItemQuality
    if itemQuality and itemQuality[name] ~= nil then
        return itemQuality[name]
    end
    return fallback
end

local TRACK_QUALITY = {
    myth = GetQualityID("Legendary", 5),
    hero = GetQualityID("Epic", 4),
    champion = GetQualityID("Rare", 3),
    veteran = GetQualityID("Uncommon", 2),
    adventurer = GetQualityID("Common", 1),
    explorer = GetQualityID("Poor", 0),
}

local SOCKET_ADDABLE_MIN_TRACK_MAX_LEVEL = {
    [TRACK_QUALITY.adventurer] = 282,
    [TRACK_QUALITY.veteran] = 295,
    [TRACK_QUALITY.champion] = 308,
    [TRACK_QUALITY.hero] = 321,
    [TRACK_QUALITY.myth] = 334,
}

local TRACK_QUALITY_BY_STRING_ID = {
    [972] = TRACK_QUALITY.veteran,
    [973] = TRACK_QUALITY.champion,
    [974] = TRACK_QUALITY.hero,
    [975] = TRACK_QUALITY.myth,
}

local TRACK_QUALITY_RULES = {
    { quality = TRACK_QUALITY.myth, names = { "mythic", "myth", "神话", "神話" } },
    { quality = TRACK_QUALITY.hero, names = { "hero", "英雄" } },
    { quality = TRACK_QUALITY.champion, names = { "champion", "勇士" } },
    { quality = TRACK_QUALITY.veteran, names = { "veteran", "老兵", "精兵" } },
    { quality = TRACK_QUALITY.adventurer, names = { "adventurer", "冒险者", "冒險者" } },
    { quality = TRACK_QUALITY.explorer, names = { "explorer", "探险者", "探險者" } },
}

local function ResolveTrackQuality(trackString, trackStringID)
    if type(trackStringID) == "number" and not IsSecretValue(trackStringID) then
        local quality = TRACK_QUALITY_BY_STRING_ID[trackStringID]
        if quality ~= nil then return quality end
    end
    if type(trackString) ~= "string" or IsSecretValue(trackString) then return nil end

    local normalized = string.lower(trackString)
    for _, rule in ipairs(TRACK_QUALITY_RULES) do
        for _, name in ipairs(rule.names) do
            if string.find(normalized, name, 1, true) then
                return rule.quality
            end
        end
    end
end

local function NormalizeItemUpgradeInfo(itemInfo)
    local cItem = _G.C_Item
    if not cItem or type(cItem.GetItemUpgradeInfo) ~= "function" then
        return nil
    end

    local info, ok = SafeCall(cItem.GetItemUpgradeInfo, itemInfo)
    if not ok or type(info) ~= "table" then return nil end

    local normalized = {
        currentLevel = info.currentLevel,
        maxLevel = info.maxLevel,
        maxItemLevel = info.maxItemLevel,
        trackString = info.trackString,
        trackStringID = info.trackStringID,
    }
    local secret = ContainsSecretValue(normalized)
    for key, value in pairs(normalized) do
        if IsSecretValue(value) then normalized[key] = nil end
    end

    if type(normalized.currentLevel) ~= "number"
        or normalized.currentLevel <= 0
        or type(normalized.maxLevel) ~= "number"
        or normalized.maxLevel <= 0
    then
        return nil
    end

    normalized.available = true
    normalized.secret = secret
    normalized.quality = ResolveTrackQuality(normalized.trackString, normalized.trackStringID)
    return normalized
end

local function ReadRawItemStats(link)
    local cItem = _G.C_Item
    if not cItem or type(cItem.GetItemStats) ~= "function" or not link then
        return nil, "unsupported"
    end

    local stats, ok = SafeCall(cItem.GetItemStats, link)
    if not ok or stats == nil then return nil, "pending" end
    if IsSecretValue(stats) then return nil, "secret" end
    if type(stats) ~= "table" then return nil, "unsupported" end
    return stats, "ready"
end

local function ReadTooltipData(unit, slotID, link)
    local tooltipInfo = _G.C_TooltipInfo
    if not tooltipInfo then return nil, "unsupported" end

    local data, ok
    if unit and slotID and type(tooltipInfo.GetInventoryItem) == "function" then
        data, ok = SafeCall(tooltipInfo.GetInventoryItem, unit, slotID)
    elseif link and type(tooltipInfo.GetHyperlink) == "function" then
        data, ok = SafeCall(tooltipInfo.GetHyperlink, link)
    else
        return nil, "unsupported"
    end
    if not ok or data == nil then return nil, "pending" end
    if IsSecretValue(data) then return nil, "secret" end
    if type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil, "pending"
    end

    local tooltipUtil = _G.TooltipUtil
    if tooltipUtil and type(tooltipUtil.SurfaceArgs) == "function" then
        pcall(tooltipUtil.SurfaceArgs, data)
    end
    return data, "ready"
end

local function ReadTooltipItemStats(data, rawStats)
    if type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil, "pending"
    end

    local stats = {}
    for lineIndex = 1, #data.lines do
        local line = data.lines[lineIndex]
        local text = type(line) == "table" and line.leftText or nil
        if IsSecretValue(text) then return nil, "secret" end
        if type(text) == "string" then
            local compact = string.gsub(text, "[,%s]", "")
            for ruleIndex = 1, #ITEM_SECONDARY_STAT_RULES do
                local rule = ITEM_SECONDARY_STAT_RULES[ruleIndex]
                local label = _G[rule.key]
                if type(label) == "string" and label ~= "" then
                    label = string.gsub(label, "%s", "")
                    local labelStart = string.find(compact, label, 1, true)
                    local prefix = labelStart and string.sub(compact, 1, labelStart - 1) or nil
                    local value = prefix and string.match(prefix, "%+(%d+)$") or nil
                    value = value and tonumber(value) or nil
                    if value and value > 0 then
                        stats[rule.key] = (stats[rule.key] or 0) + value
                    end
                end
            end
        end
    end

    if type(rawStats) == "table" then
        for key, value in pairs(rawStats) do
            if type(key) == "string" and string.find(key, EMPTY_SOCKET_PREFIX, 1, true) == 1 then
                stats[key] = value
            end
        end
    end
    return stats, "ready"
end

local function ReadItemStats(unit, slotID, link)
    local tooltipData, tooltipState = ReadTooltipData(unit, slotID, link)
    if tooltipState ~= "ready" then return nil, tooltipState, tooltipData end

    local rawStats, rawState = ReadRawItemStats(link)
    if rawState == "secret" then return nil, "secret", tooltipData end
    local stats, state = ReadTooltipItemStats(tooltipData, rawStats)
    return stats, state, tooltipData
end

local function ReadCraftedQuality(link)
    local tradeSkill = _G.C_TradeSkillUI
    if not tradeSkill
        or type(tradeSkill.GetItemCraftedQualityByItemInfo) ~= "function"
        or type(link) ~= "string"
        or not string.find(link, CRAFTED_QUALITY_ATLAS_PREFIX, 1, true)
    then
        return nil
    end

    local quality, ok = SafeCall(tradeSkill.GetItemCraftedQualityByItemInfo, link)
    if not ok or IsSecretValue(quality) or type(quality) ~= "number" or quality <= 0 then
        return nil
    end
    return quality
end

local function ReadSecondaryStats(stats, target)
    local records, pool = ResetRecordArray(target)
    if type(stats) ~= "table" then return records end

    local count = 0
    for index = 1, #ITEM_SECONDARY_STAT_RULES do
        local rule = ITEM_SECONDARY_STAT_RULES[index]
        local value = stats[rule.key]
        if type(value) == "number" and not IsSecretValue(value) and value > 0 then
            count = count + 1
            local record = AcquireRecord(records, pool, count)
            record.id = rule.id
            record.value = value
            record.priority = rule.priority
        end
    end

    for index = 2, count do
        local record = records[index]
        local insertAt = index
        while insertAt > 1 do
            local previous = records[insertAt - 1]
            if previous.value > record.value
                or (previous.value == record.value and previous.priority < record.priority)
            then
                break
            end
            records[insertAt] = previous
            insertAt = insertAt - 1
        end
        records[insertAt] = record
    end

    for index = count, 5, -1 do
        records[index] = nil
    end
    return records
end

local function ParseEnchantID(link)
    if type(link) ~= "string" or IsSecretValue(link) then return nil end
    local raw = string.match(link, "item:%-?%d+:([^:]*):")
    if raw == nil or raw == "" then return nil end
    local enchantID = tonumber(raw)
    if not enchantID or enchantID < 0 then return nil end
    return enchantID
end

local function IsEnchantableSlot(definition, itemInfo)
    local key = definition and definition.key
    if not ENCHANTABLE_SLOT_KEYS[key] then return false end

    local itemQuality = _G.Enum and _G.Enum.ItemQuality
    local artifactQuality = itemQuality and itemQuality.Artifact or 6
    if itemInfo and itemInfo.quality == artifactQuality and WEAPON_SLOT_KEYS[key] then
        return false
    end

    if key == "offhand" then
        local itemClass = _G.Enum and _G.Enum.ItemClass
        local weaponClass = itemClass and itemClass.Weapon or 2
        return itemInfo and itemInfo.classID == weaponClass or false
    end

    return true
end

local function ReadPermanentEnchantState(unit, slotID, link, data)
    if not data then data = select(1, ReadTooltipData(unit, slotID, link)) end
    if not data then return nil end

    local lines = data.lines
    if type(lines) ~= "table" or #lines == 0 then return nil end
    local lineTypes = _G.Enum and _G.Enum.TooltipDataLineType
    local permanentEnchantType = lineTypes and (
        lineTypes.ItemEnchantmentPermanent or lineTypes.ItemEnchant
    ) or 15
    for index = 1, #lines do
        local line = lines[index]
        local lineType = type(line) == "table" and line.type or nil
        if not IsSecretValue(lineType) and lineType == permanentEnchantType then
            return true
        end
    end
    return false
end

local function ReadSocketCounts(link, stats)
    local cItem = _G.C_Item
    local totalSockets, totalKnown = 0, false
    if cItem and type(cItem.GetItemNumSockets) == "function" then
        local value, ok = SafeCall(cItem.GetItemNumSockets, link)
        if ok and type(value) == "number" and not IsSecretValue(value) and value >= 0 then
            totalSockets = math.floor(value + 0.5)
            totalKnown = true
        end
    end

    if not totalKnown and type(stats) == "table" then
        for key, value in pairs(stats) do
            if type(key) == "string"
                and string.find(key, EMPTY_SOCKET_PREFIX, 1, true) == 1
                and type(value) == "number"
                and not IsSecretValue(value)
                and value > 0
            then
                totalSockets = totalSockets + math.floor(value + 0.5)
            end
        end
        totalKnown = true
    end

    if totalSockets == 0 then return 0, 0, 0, totalKnown end
    if not cItem then
        return totalSockets, 0, 0, false
    end

    local filledSockets = 0
    if type(cItem.GetItemGemID) == "function" then
        for index = 1, totalSockets do
            local gemID, ok = SafeCall(cItem.GetItemGemID, link, index)
            if not ok or IsSecretValue(gemID) then
                return totalSockets, filledSockets, 0, false
            end
            if type(gemID) == "number" and gemID > 0 then
                filledSockets = filledSockets + 1
            end
        end
    elseif type(cItem.GetItemGem) == "function" then
        for index = 1, totalSockets do
            local gemName, ok, gemLink = SafeCall(cItem.GetItemGem, link, index)
            if not ok then return totalSockets, filledSockets, 0, false end
            if not IsSecretValue(gemName)
                and not IsSecretValue(gemLink)
                and (gemName ~= nil or gemLink ~= nil)
            then
                filledSockets = filledSockets + 1
            end
        end
    else
        return totalSockets, 0, 0, false
    end
    return totalSockets, filledSockets, math.max(0, totalSockets - filledSockets), true
end

local function ReadAddedSocketCount(link)
    local cItem = _G.C_Item
    if not cItem or type(cItem.GetItemNumAddedSockets) ~= "function" then return nil end
    local value, ok = SafeCall(cItem.GetItemNumAddedSockets, link)
    if not ok or type(value) ~= "number" or IsSecretValue(value) or value < 0 then
        return nil
    end
    return math.floor(value + 0.5)
end

local function IsCurrentSeasonSocketCandidate(itemInfo, upgrade, craftedQuality)
    if type(itemInfo) ~= "table"
        or type(itemInfo.level) ~= "number"
        or itemInfo.level < SOCKET_ADDABLE_MIN_ITEM_LEVEL
    then
        return false
    end

    if type(upgrade) == "table" then
        local minimumMaxLevel = SOCKET_ADDABLE_MIN_TRACK_MAX_LEVEL[upgrade.quality]
        if type(minimumMaxLevel) == "number" then
            return type(upgrade.maxItemLevel) == "number"
                and upgrade.maxItemLevel >= minimumMaxLevel
        end
    end

    return type(craftedQuality) == "number"
        and craftedQuality > 0
        and itemInfo.level >= SOCKET_ADDABLE_MIN_CRAFTED_ITEM_LEVEL
end

local function ReadAddableSocketCount(
    definition,
    itemInfo,
    upgrade,
    craftedQuality,
    totalSockets,
    addedSockets,
    socketKnown
)
    local key = definition and definition.key
    if not YUI.IsRetail
        or not SOCKET_ADDABLE_SLOT_KEYS[key]
        or type(itemInfo) ~= "table"
        or type(itemInfo.expansionID) ~= "number"
        or not IsCurrentSeasonSocketCandidate(itemInfo, upgrade, craftedQuality)
        or socketKnown ~= true
        or totalSockets > 0
        or (type(addedSockets) == "number" and addedSockets > 0)
    then
        return 0
    end

    local currentExpansion
    if type(GetExpansionLevel) == "function" then
        local value, ok = SafeCall(GetExpansionLevel)
        if ok and type(value) == "number" and not IsSecretValue(value) then
            currentExpansion = value
        end
    end
    currentExpansion = currentExpansion or _G.LE_EXPANSION_LEVEL_CURRENT
    if type(currentExpansion) ~= "number" or itemInfo.expansionID ~= currentExpansion then
        return 0
    end
    return 1
end

local function ReadEnhancementStatus(
    unit,
    slotID,
    link,
    definition,
    itemInfo,
    stats,
    upgrade,
    craftedQuality,
    tooltipData,
    target
)
    target = target or {}
    ClearRecord(target)

    if not link or IsSecretValue(link) then return target end

    local enchantID = ParseEnchantID(link)
    local enchantable = IsEnchantableSlot(definition, itemInfo)
    local hasEnchant
    if enchantable then
        hasEnchant = ReadPermanentEnchantState(unit, slotID, link, tooltipData)
        if hasEnchant == nil and enchantID ~= nil then
            hasEnchant = enchantID > 0
        end
    end
    target.enchantable = enchantable
    target.enchantKnown = hasEnchant ~= nil
    target.enchantID = enchantID
    target.hasEnchant = hasEnchant
    target.missingEnchant = enchantable and hasEnchant == false or false

    local totalSockets, filledSockets, emptySockets, socketKnown = ReadSocketCounts(link, stats)
    local addedSockets = ReadAddedSocketCount(link)
    local addableSockets = ReadAddableSocketCount(
        definition,
        itemInfo,
        upgrade,
        craftedQuality,
        totalSockets,
        addedSockets,
        socketKnown
    )
    target.totalSockets = totalSockets
    target.filledSockets = filledSockets
    target.emptySockets = emptySockets
    target.addedSockets = addedSockets
    target.addableSockets = addableSockets
    target.socketKnown = socketKnown
    target.missing = target.missingEnchant or emptySockets > 0 or addableSockets > 0
    target.available = target.enchantKnown or socketKnown or type(stats) == "table"
    return target
end

function PaperDoll.ReadEquipmentSlot(unit, definition, target)
    target = target or {}
    definition = definition or {}
    local slot = definition.slot or definition
    local slotID = slot.slotID or definition.slotID

    target.key = definition.key or target.key
    target.slotID = slotID
    target.link = nil
    target.itemID = nil
    target.icon = slot.texture
    target.quality = nil
    target.name = nil
    target.level = nil
    target.upgrade = nil
    target.secondaryStats = ResetRecordArray(target.secondaryStats)
    target.craftedQuality = nil
    target.statsKnown = false
    target.statsUnavailable = false
    target.statsSecret = false
    target.enhancement = ReadEnhancementStatus(
        nil,
        nil,
        nil,
        definition,
        nil,
        nil,
        nil,
        nil,
        nil,
        target.enhancement
    )
    target.available = false
    target.pending = false
    target.secret = false

    if not YUI.IsRetail or not unit or not slotID then
        return target
    end

    local link
    if Item and type(Item.GetInventoryItemLink) == "function" then
        link = Item.GetInventoryItemLink(unit, slotID)
    elseif type(GetInventoryItemLink) == "function" then
        link = GetInventoryItemLink(unit, slotID)
    end

    if IsSecretValue(link) then
        target.secret = true
        return target
    end

    target.link = link
    if not link then
        return target
    end

    local itemID
    if Item and type(Item.GetInventoryItemID) == "function" then
        itemID = Item.GetInventoryItemID(unit, slotID)
    elseif type(GetInventoryItemID) == "function" then
        itemID = GetInventoryItemID(unit, slotID)
    end
    if not IsSecretValue(itemID) then
        target.itemID = itemID
    end

    local icon
    if Item and type(Item.GetInventoryItemTexture) == "function" then
        icon = Item.GetInventoryItemTexture(unit, slotID)
    elseif type(GetInventoryItemTexture) == "function" then
        icon = GetInventoryItemTexture(unit, slotID)
    end
    if not IsSecretValue(icon) then
        target.icon = icon or target.icon
    end

    local quality
    if Item and type(Item.GetInventoryItemQuality) == "function" then
        quality = Item.GetInventoryItemQuality(unit, slotID)
    elseif type(GetInventoryItemQuality) == "function" then
        quality = GetInventoryItemQuality(unit, slotID)
    end
    if not IsSecretValue(quality) then
        target.quality = quality
    end

    local info = NormalizeItemInfo(link)
    if info then
        target.name = info.name
        target.icon = info.icon or target.icon
        target.quality = target.quality or info.quality
        target.level = info.level
        target.itemID = target.itemID or info.itemID
    end

    target.upgrade = NormalizeItemUpgradeInfo(link)
    if not target.upgrade or target.upgrade.quality == nil then
        target.craftedQuality = ReadCraftedQuality(link)
    end

    target.available = true
    target.pending = target.name == nil or not target.level or target.level <= 0
    if not target.pending then
        local itemStats, itemStatsState, tooltipData = ReadItemStats(unit, slotID, link)
        target.statsKnown = itemStatsState == "ready"
        target.statsUnavailable = itemStatsState == "unsupported"
        target.statsSecret = itemStatsState == "secret"
        target.pending = itemStatsState == "pending"
        if target.statsKnown then
            target.secondaryStats = ReadSecondaryStats(itemStats, target.secondaryStats)
            target.enhancement = ReadEnhancementStatus(
                unit,
                slotID,
                link,
                definition,
                info,
                itemStats,
                target.upgrade,
                target.craftedQuality,
                tooltipData,
                target.enhancement
            )
        end
    end
    target.secret = target.statsSecret or ContainsSecretValue(target)
    return target
end

function PaperDoll.ReadEquipment(unit, target)
    target = target or {}
    target.unit = unit
    target.available = YUI.IsRetail == true and type(unit) == "string"
    target.slots = target.slots or {}

    if not target.available then
        for index, definition in ipairs(SLOT_DEFINITIONS) do
            target.slots[index] = target.slots[index] or {}
            target.slots[index].key = definition.key
            target.slots[index].available = false
            target.slots[index].pending = false
            target.slots[index].secret = false
        end
        return target
    end

    for index, definition in ipairs(SLOT_DEFINITIONS) do
        target.slots[index] = PaperDoll.ReadEquipmentSlot(
            unit,
            definition,
            target.slots[index]
        )
    end

    return target
end

function PaperDoll.ReadEquipmentSecondaryTotals(equipment, target)
    target = target or {}
    target.values = target.values or {}
    for index = 1, #EQUIPMENT_SECONDARY_STAT_IDS do
        target.values[EQUIPMENT_SECONDARY_STAT_IDS[index]] = nil
    end
    target.available = false
    target.complete = false
    target.pending = false
    target.secret = false

    if not YUI.IsRetail or type(equipment) ~= "table"
        or equipment.available ~= true or type(equipment.slots) ~= "table"
    then
        return target
    end

    local crit, haste, mastery, versatility = 0, 0, 0, 0
    local unavailable = false
    for index = 1, #SLOT_DEFINITIONS do
        local slot = equipment.slots[index]
        if type(slot) == "table" and (slot.secret == true or slot.statsSecret == true) then
            target.secret = true
        elseif type(slot) == "table" and slot.available == true then
            if slot.pending == true or slot.statsKnown ~= true then
                if slot.statsUnavailable == true then
                    unavailable = true
                else
                    target.pending = true
                end
            else
                for statIndex = 1, #(slot.secondaryStats or {}) do
                    local record = slot.secondaryStats[statIndex]
                    local value = type(record) == "table" and record.value or nil
                    if type(value) == "number" and not IsSecretValue(value) then
                        if record.id == "crit" then
                            crit = crit + value
                        elseif record.id == "haste" then
                            haste = haste + value
                        elseif record.id == "mastery" then
                            mastery = mastery + value
                        elseif record.id == "versatility" then
                            versatility = versatility + value
                        end
                    elseif IsSecretValue(value) then
                        target.secret = true
                    end
                end
            end
        end
    end

    target.available = not unavailable and not target.secret
    target.complete = target.available and not target.pending
    if target.complete then
        target.values.crit = crit
        target.values.haste = haste
        target.values.mastery = mastery
        target.values.versatility = versatility
    end
    return target
end

function PaperDoll.RequestItemData(itemID)
    if not YUI.IsRetail or not itemID or not Item then return false end
    if type(Item.RequestLoadDataByID) ~= "function" then return false end
    local ok = pcall(Item.RequestLoadDataByID, itemID)
    return ok == true
end

function PaperDoll.ReadAverageItemLevel(unit)
    unit = unit or "player"
    if unit == "player" and type(GetAverageItemLevel) == "function" then
        local ok, overall, equipped, pvp = pcall(GetAverageItemLevel)
        if ok then
            local overallSecret = IsSecretValue(overall)
            local equippedSecret = IsSecretValue(equipped)
            return {
                available = overallSecret or equippedSecret or overall ~= nil or equipped ~= nil,
                overall = overall,
                equipped = equipped,
                pvp = pvp,
                secret = overallSecret or equippedSecret or IsSecretValue(pvp),
            }
        end
    end

    local paperDollInfo = _G.C_PaperDollInfo
    if paperDollInfo and type(paperDollInfo.GetInspectItemLevel) == "function" then
        local value, ok = SafeCall(paperDollInfo.GetInspectItemLevel, unit)
        if ok then
            local secret = IsSecretValue(value)
            return {
                available = secret or value ~= nil,
                equipped = value,
                secret = secret,
            }
        end
    end

    return { available = false, reason = "unavailable" }
end

local CR_VERSATILITY = 29
local STAT_DEFINITIONS = {
    { id = "ilvl", category = "summary", percent = false },
    { id = "str", category = "primary", percent = false },
    { id = "agi", category = "primary", percent = false },
    { id = "int", category = "primary", percent = false },
    { id = "sta", category = "primary", percent = false },
    { id = "crit", category = "secondary", percent = true },
    { id = "haste", category = "secondary", percent = true },
    { id = "mastery", category = "secondary", percent = true },
    { id = "versatility", category = "secondary", percent = true },
    { id = "armor", category = "defense", percent = false },
    { id = "dodge", category = "defense", percent = true },
    { id = "parry", category = "defense", percent = true },
    { id = "block", category = "defense", percent = true },
    { id = "stagger", category = "defense", percent = true },
}

local STAT_BY_ID = {}
for _, definition in ipairs(STAT_DEFINITIONS) do
    STAT_BY_ID[definition.id] = definition
end

function PaperDoll.GetStatDefinitions()
    return STAT_DEFINITIONS
end

local function ReadUnitStat(index, unit)
    if type(UnitStat) ~= "function" then return nil end
    local _, value = UnitStat(unit or "player", index)
    return value
end

local function ReadVersatility(unit)
    unit = unit or "player"
    if unit ~= "player" then return nil end

    local hasReader = type(GetCombatRatingBonus) == "function"
        or type(GetVersatilityBonus) == "function"
    if not hasReader then return nil end

    local bonus = type(GetCombatRatingBonus) == "function"
        and GetCombatRatingBonus(CR_VERSATILITY) or 0
    local bonusAgainst = type(GetVersatilityBonus) == "function"
        and GetVersatilityBonus(CR_VERSATILITY) or 0
    if IsSecretValue(bonus) or IsSecretValue(bonusAgainst) then
        return {
            isSecretCombo = true,
            v1 = bonus,
            v2 = bonusAgainst,
        }
    end
    if type(bonus) ~= "number" or type(bonusAgainst) ~= "number" then
        return nil
    end
    return bonus + bonusAgainst
end

local function ReadStagger(unit)
    unit = unit or "player"
    if type(UnitClass) == "function" then
        local _, classToken = UnitClass(unit)
        if classToken ~= "MONK" then return 0 end
    end

    local paperDollInfo = _G.C_PaperDollInfo
    if paperDollInfo and type(paperDollInfo.GetStaggerPercentage) == "function" then
        local value, ok = SafeCall(paperDollInfo.GetStaggerPercentage, unit)
        if ok and value ~= nil then return value end
    end

    if type(UnitStagger) == "function" and type(UnitHealthMax) == "function" then
        local stagger = UnitStagger(unit)
        local maximum = UnitHealthMax(unit)
        if stagger == nil or maximum == nil then return nil end
        if IsSecretValue(stagger) or IsSecretValue(maximum) then
            return stagger
        end
        if maximum > 0 then
            return stagger / maximum * 100
        end
    end

    return unit == "player" and 0 or nil
end

local STAT_READERS = {
    ilvl = function(unit)
        local info = PaperDoll.ReadAverageItemLevel(unit or "player")
        return info and info.available and (info.equipped or info.overall) or nil
    end,
    str = function(unit) return ReadUnitStat(1, unit) end,
    agi = function(unit) return ReadUnitStat(2, unit) end,
    int = function(unit) return ReadUnitStat(4, unit) end,
    sta = function(unit) return ReadUnitStat(3, unit) end,
    crit = function(unit)
        if unit ~= "player" then return nil end
        if type(GetCritChance) == "function" then return GetCritChance() end
        return nil
    end,
    haste = function(unit)
        if unit ~= "player" then return nil end
        if type(GetHaste) == "function" then return GetHaste() end
        return nil
    end,
    mastery = function(unit)
        if unit ~= "player" then return nil end
        if type(GetMasteryEffect) == "function" then return GetMasteryEffect() end
        return nil
    end,
    versatility = ReadVersatility,
    armor = function(unit)
        if type(UnitArmor) == "function" then
            local _, effective = UnitArmor(unit or "player")
            return effective
        end
        return nil
    end,
    dodge = function(unit)
        if unit == "player" and type(GetDodgeChance) == "function" then
            return GetDodgeChance()
        end
        if type(UnitDodgeChance) == "function" then return UnitDodgeChance(unit) end
        return nil
    end,
    parry = function(unit)
        if unit == "player" and type(GetParryChance) == "function" then
            return GetParryChance()
        end
        if type(UnitParryChance) == "function" then return UnitParryChance(unit) end
        return nil
    end,
    block = function(unit)
        if unit == "player" and type(GetBlockChance) == "function" then
            return GetBlockChance()
        end
        if type(UnitBlockChance) == "function" then return UnitBlockChance(unit) end
        return nil
    end,
    stagger = ReadStagger,
}

function PaperDoll.ReadStatRecord(id, unit, target)
    if not YUI.IsRetail or type(unit) ~= "string" then
        return nil
    end

    local definition = STAT_BY_ID[id]
    local reader = STAT_READERS[id]
    if not definition or not reader then return nil end

    local value, ok = SafeCall(reader, unit)
    if not ok or value == nil then return nil end

    target = target or {}
    target.id = id
    target.value = value
    target.percent = definition.percent == true
    target.category = definition.category
    target.secret = ContainsSecretValue(value)
    return target
end

function PaperDoll.ReadStat(id, unit)
    unit = unit or "player"
    if not YUI.IsRetail or type(unit) ~= "string" then
        return nil
    end

    local reader = STAT_READERS[id]
    if not STAT_BY_ID[id] or not reader then return nil end
    local value, ok = SafeCall(reader, unit)
    return ok and value or nil
end

function PaperDoll.ReadCurrentStats(unit, target)
    target = target or {}
    target.unit = unit or "player"
    target.values = target.values or {}

    if not YUI.IsRetail or type(target.unit) ~= "string" then
        target.available = false
        target.reason = "unsupported"
        return target
    end

    local available = false
    for _, definition in ipairs(STAT_DEFINITIONS) do
        local record = PaperDoll.ReadStatRecord(
            definition.id,
            target.unit,
            target.values[definition.id]
        )
        target.values[definition.id] = record
        if record and definition.category ~= "summary" then
            available = true
        end
    end
    target.available = available
    target.reason = available and nil or "unavailable"
    return target
end

YUI.WOW_API.GetPaperDollSlotDefinitions = PaperDoll.GetSlotDefinitions
YUI.WOW_API.ReadPaperDollEquipment = PaperDoll.ReadEquipment
YUI.WOW_API.ReadPaperDollStats = PaperDoll.ReadCurrentStats
