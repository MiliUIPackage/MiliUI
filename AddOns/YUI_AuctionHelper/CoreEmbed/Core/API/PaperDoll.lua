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

local TRACK_QUALITY_RULES = {
    { quality = GetQualityID("Legendary", 5), names = { "mythic", "myth", "神话" } },
    { quality = GetQualityID("Epic", 4), names = { "hero", "英雄" } },
    { quality = GetQualityID("Rare", 3), names = { "champion", "勇士" } },
    { quality = GetQualityID("Uncommon", 2), names = { "veteran", "老兵" } },
    { quality = GetQualityID("Common", 1), names = { "adventurer", "冒险者" } },
    { quality = GetQualityID("Poor", 0), names = { "explorer", "探险者" } },
}

local function ResolveTrackQuality(trackString)
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

    normalized.available = true
    normalized.secret = secret
    normalized.quality = ResolveTrackQuality(normalized.trackString)
    return normalized
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

    target.available = true
    target.pending = target.name == nil or not target.level or target.level <= 0
    target.secret = ContainsSecretValue(target)
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

function PaperDoll.RequestItemData(itemID)
    if not YUI.IsRetail or not itemID or not Item then return false end
    if type(Item.RequestLoadDataByID) ~= "function" then return false end
    local ok = pcall(Item.RequestLoadDataByID, itemID)
    return ok == true
end

function PaperDoll.ReadAverageItemLevel(unit)
    unit = unit or "player"
    if not YUI.IsRetail then
        return { available = false, reason = "unsupported" }
    end

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
    if unit ~= "player" then
        if type(UnitVersatility) == "function" then
            local value, ok = SafeCall(UnitVersatility, unit)
            if ok then return value end
        end
        return nil
    end

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
        if unit == "player" and type(GetCritChance) == "function" then
            return GetCritChance()
        end
        if type(UnitCritChance) == "function" then
            return UnitCritChance(unit)
        end
        return nil
    end,
    haste = function(unit)
        if unit == "player" and type(GetHaste) == "function" then
            return GetHaste()
        end
        if type(UnitSpellHaste) == "function" then return UnitSpellHaste(unit) end
        return nil
    end,
    mastery = function(unit)
        if unit == "player" and type(GetMasteryEffect) == "function" then
            return GetMasteryEffect()
        end
        if type(UnitMastery) == "function" then return UnitMastery(unit) end
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
