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

local Item = YUI.API.Item or {}
YUI.API.Item = Item

local Legacy = YUI.WOW_API

local function FirstNonNil(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function NormalizeInfo(itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, setID, isCraftingReagent, itemDescription)
    if not itemName then return nil end

    return {
        name = itemName,
        link = itemLink,
        quality = itemQuality,
        level = itemLevel,
        minLevel = itemMinLevel,
        type = itemType,
        subType = itemSubType,
        stackCount = itemStackCount,
        equipLoc = itemEquipLoc,
        texture = itemTexture,
        sellPrice = sellPrice,
        classID = classID,
        subclassID = subclassID,
        bindType = bindType,
        expansionID = expansionID,
        setID = setID,
        isCraftingReagent = isCraftingReagent,
        description = itemDescription,
    }
end

local function GetInfoFromCItem(itemInfo)
    if not C_Item or not C_Item.GetItemInfo then return nil end
    return NormalizeInfo(C_Item.GetItemInfo(itemInfo))
end

local function GetInfoFromGlobal(itemInfo)
    if not GetItemInfo then return nil end
    return NormalizeInfo(GetItemInfo(itemInfo))
end

function Item.GetInfo(itemInfo)
    if not itemInfo then return nil end

    if YUI.IsRetail then
        return GetInfoFromCItem(itemInfo) or GetInfoFromGlobal(itemInfo)
    end

    if YUI.IsMists then
        return GetInfoFromGlobal(itemInfo) or GetInfoFromCItem(itemInfo)
    end

    if YUI.IsWrath then
        return GetInfoFromGlobal(itemInfo) or GetInfoFromCItem(itemInfo)
    end

    return GetInfoFromGlobal(itemInfo) or GetInfoFromCItem(itemInfo)
end

local function NormalizeStackSize(stackSize)
    stackSize = tonumber(stackSize)
    if stackSize and stackSize > 0 then
        return math.floor(stackSize + 0.5)
    end
    return nil
end

local function GetMaxStackSizeFromCItemByID(itemInfo)
    if not C_Item or not C_Item.GetItemMaxStackSizeByID then return nil end
    local ok, stackSize = pcall(C_Item.GetItemMaxStackSizeByID, itemInfo)
    if ok then
        return NormalizeStackSize(stackSize)
    end
    return nil
end

local function GetMaxStackSizeFromGlobalInfo(itemInfo)
    if not GetItemInfo then return nil end
    local ok, itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount = pcall(GetItemInfo, itemInfo)
    if ok and itemName then
        return NormalizeStackSize(itemStackCount)
    end
    return nil
end

function Item.GetMaxStackSize(itemInfo)
    if not itemInfo then return nil end

    local stackSize = GetMaxStackSizeFromCItemByID(itemInfo)
    if stackSize then return stackSize end

    local info = Item.GetInfo(itemInfo)
    stackSize = info and NormalizeStackSize(info.stackCount)
    if stackSize then return stackSize end

    return GetMaxStackSizeFromGlobalInfo(itemInfo)
end

local function GetInfoInstantFromCItem(itemInfo)
    if not C_Item or not C_Item.GetItemInfoInstant then return nil end
    return C_Item.GetItemInfoInstant(itemInfo)
end

local function GetInfoInstantFromGlobal(itemInfo)
    if not GetItemInfoInstant then return nil end
    return GetItemInfoInstant(itemInfo)
end

function Item.GetInfoInstant(itemInfo)
    if not itemInfo then return nil end

    if YUI.IsRetail then
        local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = GetInfoInstantFromCItem(itemInfo)
        if itemID then
            return itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
        end
        return GetInfoInstantFromGlobal(itemInfo)
    end

    if YUI.IsMists then
        local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = GetInfoInstantFromGlobal(itemInfo)
        if itemID then
            return itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
        end
        return GetInfoInstantFromCItem(itemInfo)
    end

    if YUI.IsWrath then
        local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = GetInfoInstantFromGlobal(itemInfo)
        if itemID then
            return itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
        end
        return GetInfoInstantFromCItem(itemInfo)
    end

    local itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID = GetInfoInstantFromGlobal(itemInfo)
    if itemID then
        return itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
    end
    return GetInfoInstantFromCItem(itemInfo)
end

function Item.GetName(itemInfo)
    local info = Item.GetInfo(itemInfo)
    return info and info.name or nil
end

function Item.GetNameByID(itemInfo)
    if not itemInfo then return nil end

    if C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(itemInfo)
        if name then return name end
    end

    return Item.GetName(itemInfo)
end

local function GetSpellFromCItem(itemInfo)
    if not C_Item or not C_Item.GetItemSpell then return nil end
    return C_Item.GetItemSpell(itemInfo)
end

local function GetSpellFromGlobal(itemInfo)
    if not GetItemSpell then return nil end
    return GetItemSpell(itemInfo)
end

function Item.GetSpell(itemInfo)
    if not itemInfo then return nil end

    if YUI.IsRetail then
        local name, spellID = GetSpellFromCItem(itemInfo)
        if spellID then return name, spellID end
        return GetSpellFromGlobal(itemInfo)
    end

    local name, spellID = GetSpellFromGlobal(itemInfo)
    if spellID then return name, spellID end
    return GetSpellFromCItem(itemInfo)
end

local useEffectDurationCache = Item.useEffectDurationCache or {}
Item.useEffectDurationCache = useEffectDurationCache

local function IsSecretValue(value)
    local Security = YUI.API and YUI.API.Security
    return Security and Security.IsSecretValue
        and Security.IsSecretValue(value) == true
end

local ITEM_CLASS = Enum and Enum.ItemClass or {}
local KNOWABLE_ITEM_CLASSES = {
    [ITEM_CLASS.Consumable or 0] = true,
    [ITEM_CLASS.Weapon or 2] = true,
    [ITEM_CLASS.Armor or 4] = true,
    [ITEM_CLASS.ItemEnhancement or 8] = true,
    [ITEM_CLASS.Recipe or 9] = true,
    [ITEM_CLASS.Miscellaneous or 15] = true,
    [ITEM_CLASS.Battlepet or 17] = true,
}
local PET_KNOWN_PREFIX = type(ITEM_PET_KNOWN) == "string"
    and ITEM_PET_KNOWN:match("^[^%(（]+") or nil

local function IsPetSpeciesCollected(speciesID)
    local petJournal = C_PetJournal
    if not speciesID or not petJournal or type(petJournal.GetNumCollectedInfo) ~= "function" then
        return false, false
    end

    local numCollected = petJournal.GetNumCollectedInfo(speciesID)
    if numCollected == nil then
        return false, false
    end
    return numCollected > 0, true
end

local function GetPetSpeciesFromItem(itemID)
    local petJournal = C_PetJournal
    if not petJournal or type(petJournal.GetPetInfoByItemID) ~= "function" then
        return nil
    end
    return select(13, petJournal.GetPetInfoByItemID(itemID))
end

local function GetKnownMountState(itemID)
    local mountJournal = C_MountJournal
    if not mountJournal
        or type(mountJournal.GetMountFromItem) ~= "function"
        or type(mountJournal.GetMountInfoByID) ~= "function"
    then
        return nil
    end

    local mountID = mountJournal.GetMountFromItem(itemID)
    if not mountID then
        return nil
    end

    local name, _, _, _, _, _, _, _, _, _, isCollected = mountJournal.GetMountInfoByID(mountID)
    if not name then
        return false, false
    end
    return isCollected == true, true
end

local function GetKnownToyState(itemID)
    if not C_ToyBox or type(C_ToyBox.GetToyInfo) ~= "function" or type(PlayerHasToy) ~= "function" then
        return nil
    end
    if not C_ToyBox.GetToyInfo(itemID) then
        return nil
    end
    return PlayerHasToy(itemID) == true, true
end

local function GetKnownHeirloomState(itemID)
    if not C_Heirloom
        or type(C_Heirloom.IsItemHeirloom) ~= "function"
        or type(C_Heirloom.PlayerHasHeirloom) ~= "function"
    then
        return nil
    end
    if not C_Heirloom.IsItemHeirloom(itemID) then
        return nil
    end
    return C_Heirloom.PlayerHasHeirloom(itemID) == true, true
end

local function GetKnownTransmogSetState(itemInfo)
    if not C_Item or type(C_Item.GetItemLearnTransmogSet) ~= "function" then
        return nil
    end

    local setID = C_Item.GetItemLearnTransmogSet(itemInfo)
    if not setID then
        return nil
    end
    if not C_TransmogSets or type(C_TransmogSets.GetSetInfo) ~= "function" then
        return false, false
    end

    local setInfo = C_TransmogSets.GetSetInfo(setID)
    if not setInfo then
        return false, false
    end
    if setInfo.collected == true then
        return true, true
    end
    local collection = C_TransmogCollection
    local hasByAppearance = collection
        and type(collection.PlayerHasTransmogItemModifiedAppearance) == "function"
    local hasByItem = collection and type(collection.PlayerHasTransmogByItemInfo) == "function"
    if not C_Transmog or type(C_Transmog.GetAllSetAppearancesByID) ~= "function"
        or not hasByAppearance and not hasByItem
    then
        return false, true
    end

    local appearances = C_Transmog.GetAllSetAppearancesByID(setID)
    if not appearances then
        return false, false
    end
    for i = 1, #appearances do
        local appearance = appearances[i]
        local isCollected
        if appearance and appearance.itemModifiedAppearanceID and hasByAppearance then
            isCollected = collection.PlayerHasTransmogItemModifiedAppearance(appearance.itemModifiedAppearanceID)
        elseif appearance and appearance.itemID and hasByItem then
            isCollected = collection.PlayerHasTransmogByItemInfo(appearance.itemID)
        end
        if isCollected ~= true then
            return false, true
        end
    end
    return #appearances > 0, true
end

local function GetKnownAppearanceState(itemInfo, classID)
    local isEquipment = classID == (ITEM_CLASS.Weapon or 2)
        or classID == (ITEM_CLASS.Armor or 4)
    local isCosmetic = C_Item and type(C_Item.IsCosmeticItem) == "function"
        and C_Item.IsCosmeticItem(itemInfo) == true
    if not isEquipment and not isCosmetic then
        return nil
    end
    if not C_TransmogCollection
        or type(C_TransmogCollection.PlayerHasTransmogByItemInfo) ~= "function"
    then
        return nil
    end
    return C_TransmogCollection.PlayerHasTransmogByItemInfo(itemInfo) == true, true
end

local function TooltipShowsKnown(itemInfo)
    if not C_TooltipInfo or type(C_TooltipInfo.GetHyperlink) ~= "function" then
        return false, true
    end

    local data = C_TooltipInfo.GetHyperlink(itemInfo)
    if not data or type(data.lines) ~= "table" then
        return false, false
    end

    for i = 1, #data.lines do
        local line = data.lines[i]
        local text = line and line.leftText
        if type(text) == "string" then
            if type(COLLECTED) == "string" and text == COLLECTED then
                return true, true
            end
            if type(ITEM_SPELL_KNOWN) == "string" and text == ITEM_SPELL_KNOWN then
                return true, true
            end
            if PET_KNOWN_PREFIX and PET_KNOWN_PREFIX ~= "" and text:find(PET_KNOWN_PREFIX, 1, true) then
                return true, true
            end
        end
    end
    return false, true
end

-- Returns known, resolved without allocating a result table. `resolved == false`
-- means item or collection data is not ready and callers should not cache it.
function Item.IsKnownCollectible(itemInfo)
    if itemInfo == nil or IsSecretValue(itemInfo) then
        return false, false
    end

    local linkType, linkID
    if type(itemInfo) == "string" then
        linkType, linkID = itemInfo:match("|H(%a+):(%d+)")
        linkID = tonumber(linkID)
    elseif type(itemInfo) == "number" then
        linkType, linkID = "item", itemInfo
    end

    if linkType == "battlepet" then
        return IsPetSpeciesCollected(linkID)
    end
    if linkType ~= "item" or not linkID then
        return false, true
    end

    local itemID, _, _, _, _, classID = Item.GetInfoInstant(itemInfo)
    if not itemID or classID == nil then
        return false, false
    end

    local known, resolved = GetKnownMountState(itemID)
    if known ~= nil then return known, resolved end

    known, resolved = GetKnownToyState(itemID)
    if known ~= nil then return known, resolved end

    local speciesID = GetPetSpeciesFromItem(itemID)
    if speciesID then
        return IsPetSpeciesCollected(speciesID)
    end

    known, resolved = GetKnownHeirloomState(itemID)
    if known ~= nil then return known, resolved end

    known, resolved = GetKnownTransmogSetState(itemInfo)
    if known ~= nil then return known, resolved end

    known, resolved = GetKnownAppearanceState(itemInfo, classID)
    if known ~= nil then return known, resolved end

    if not KNOWABLE_ITEM_CLASSES[classID] then
        return false, true
    end
    return TooltipShowsKnown(itemInfo)
end

local DURATION_PATTERNS = {
    { "([%d%.]+)%s*秒", 1 },
    { "([%d%.]+)%s*seconds?", 1 },
    { "([%d%.]+)%s*secs?", 1 },
    { "([%d%.]+)%s*分钟", 60 },
    { "([%d%.]+)%s*分鐘", 60 },
    { "([%d%.]+)%s*minutes?", 60 },
    { "([%d%.]+)%s*mins?", 60 },
}

local function ParseUseEffectDuration(text)
    if IsSecretValue(text) or type(text) ~= "string" or text == "" then
        return nil
    end
    text = string.lower(text)
    for index = 1, #DURATION_PATTERNS do
        local pattern = DURATION_PATTERNS[index]
        local value = tonumber(string.match(text, pattern[1]))
        if value and value > 0 then return value * pattern[2] end
    end
    return nil
end

local function ReadTooltipDuration(data)
    local lines = type(data) == "table" and data.lines or nil
    for index = 1, #(type(lines) == "table" and lines or {}) do
        local line = lines[index]
        local duration = ParseUseEffectDuration(
            type(line) == "table" and line.leftText or nil
        )
        if duration then return duration end
    end
    return nil
end

function Item.GetUseEffectDurationSeconds(itemID, spellID, unit, slot)
    if IsSecretValue(itemID) or IsSecretValue(spellID) then return nil end
    itemID = tonumber(itemID)
    spellID = tonumber(spellID)
    if not itemID or itemID <= 0 or not spellID or spellID <= 0 then
        return nil
    end

    slot = tonumber(slot)
    local cacheSlot = (slot == 13 or slot == 14) and slot or nil
    local cached = cacheSlot and useEffectDurationCache[cacheSlot]
    if cached and cached.itemID == itemID and cached.spellID == spellID then
        return cached.duration
    end

    local duration
    if C_Spell and C_Spell.GetSpellDescription then
        duration = ParseUseEffectDuration(C_Spell.GetSpellDescription(spellID))
    end
    if not duration and C_TooltipInfo and C_TooltipInfo.GetSpellByID then
        duration = ReadTooltipDuration(C_TooltipInfo.GetSpellByID(spellID))
    end
    if not duration and C_TooltipInfo then
        if unit and slot and C_TooltipInfo.GetInventoryItem then
            duration = ReadTooltipDuration(
                C_TooltipInfo.GetInventoryItem(unit, slot)
            )
        elseif C_TooltipInfo.GetItemByID then
            duration = ReadTooltipDuration(C_TooltipInfo.GetItemByID(itemID))
        end
    end
    if duration and cacheSlot then
        useEffectDurationCache[cacheSlot] = {
            itemID = itemID,
            spellID = spellID,
            duration = duration,
        }
    end
    return duration
end

function Item.IsDataCachedByID(itemInfo)
    if not itemInfo then return false end

    if C_Item and C_Item.IsItemDataCachedByID then
        return C_Item.IsItemDataCachedByID(itemInfo) == true
    end

    return Item.GetInfo(itemInfo) ~= nil
end

local function GetIconFromCItem(itemInfo)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemInfo)
    end
    return nil
end

local function GetIconFromGlobal(itemInfo)
    if GetItemIcon then
        local icon = GetItemIcon(itemInfo)
        if icon then return icon end
    end

    local icon = select(5, Item.GetInfoInstant(itemInfo))
    if icon then return icon end

    local info = GetInfoFromGlobal(itemInfo)
    return info and info.texture or nil
end

function Item.GetIcon(itemInfo)
    if not itemInfo then return nil end

    if YUI.IsRetail then
        return GetIconFromCItem(itemInfo) or GetIconFromGlobal(itemInfo)
    end

    if YUI.IsMists then
        return GetIconFromGlobal(itemInfo) or GetIconFromCItem(itemInfo)
    end

    if YUI.IsWrath then
        return GetIconFromGlobal(itemInfo) or GetIconFromCItem(itemInfo)
    end

    return GetIconFromGlobal(itemInfo) or GetIconFromCItem(itemInfo)
end

local function GetDetailedLevelFromCItem(itemInfo)
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        return C_Item.GetDetailedItemLevelInfo(itemInfo)
    end
    return nil
end

local function GetDetailedLevelFromGlobal(itemInfo)
    if GetDetailedItemLevelInfo then
        return GetDetailedItemLevelInfo(itemInfo)
    end
    return nil
end

function Item.GetLevel(itemInfo)
    if not itemInfo then return 0 end

    local detailedLevel
    if YUI.IsRetail then
        detailedLevel = GetDetailedLevelFromCItem(itemInfo) or GetDetailedLevelFromGlobal(itemInfo)
    elseif YUI.IsMists then
        detailedLevel = GetDetailedLevelFromGlobal(itemInfo) or GetDetailedLevelFromCItem(itemInfo)
    elseif YUI.IsWrath then
        detailedLevel = GetDetailedLevelFromGlobal(itemInfo) or GetDetailedLevelFromCItem(itemInfo)
    else
        detailedLevel = GetDetailedLevelFromGlobal(itemInfo) or GetDetailedLevelFromCItem(itemInfo)
    end

    if detailedLevel then return detailedLevel end

    local info = Item.GetInfo(itemInfo)
    return info and info.level or 0
end

function Item.GetEquipLoc(itemInfo)
    local info = Item.GetInfo(itemInfo)
    return info and info.equipLoc or nil
end

function Item.GetCount(itemInfo, includeBank, includeUses, includeReagentBank, includeAccountBank)
    if not itemInfo then return 0 end

    if YUI.IsRetail then
        if C_Item and C_Item.GetItemCount then
            return C_Item.GetItemCount(itemInfo, includeBank, includeUses, includeReagentBank, includeAccountBank)
        end
        if GetItemCount then
            return GetItemCount(itemInfo, includeBank, includeUses, includeReagentBank, includeAccountBank)
        end
        return 0
    end

    if YUI.IsMists or YUI.IsWrath then
        if GetItemCount then
            return GetItemCount(itemInfo, includeBank, includeUses, includeReagentBank)
        end
        if C_Item and C_Item.GetItemCount then
            return C_Item.GetItemCount(itemInfo, includeBank, includeUses, includeReagentBank)
        end
        return 0
    end

    if GetItemCount then
        return GetItemCount(itemInfo, includeBank, includeUses, includeReagentBank)
    end
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemInfo, includeBank, includeUses, includeReagentBank)
    end
    return 0
end

local function NormalizeCooldown(startTime, duration, isEnabled)
    if startTime == nil and duration == nil and isEnabled == nil then
        return nil
    end

    return {
        startTime = startTime or 0,
        duration = duration or 0,
        isEnabled = FirstNonNil(isEnabled, true),
    }
end

local function GetCooldownFromCItem(itemInfo)
    if C_Item and C_Item.GetItemCooldown then
        return NormalizeCooldown(C_Item.GetItemCooldown(itemInfo))
    end
    return nil
end

local function GetCooldownFromContainer(itemInfo)
    if type(itemInfo) == "number" and C_Container and C_Container.GetItemCooldown then
        return NormalizeCooldown(C_Container.GetItemCooldown(itemInfo))
    end
    return nil
end

local function GetCooldownFromGlobal(itemInfo)
    if GetItemCooldown then
        return NormalizeCooldown(GetItemCooldown(itemInfo))
    end
    return nil
end

function Item.GetCooldown(itemInfo)
    if not itemInfo then return nil end

    if YUI.IsRetail then
        return GetCooldownFromCItem(itemInfo) or GetCooldownFromContainer(itemInfo) or GetCooldownFromGlobal(itemInfo)
    end

    if YUI.IsMists then
        return GetCooldownFromContainer(itemInfo) or GetCooldownFromGlobal(itemInfo) or GetCooldownFromCItem(itemInfo)
    end

    if YUI.IsWrath then
        return GetCooldownFromContainer(itemInfo) or GetCooldownFromGlobal(itemInfo) or GetCooldownFromCItem(itemInfo)
    end

    return GetCooldownFromGlobal(itemInfo) or GetCooldownFromContainer(itemInfo) or GetCooldownFromCItem(itemInfo)
end

function Item.ReadItemCooldown(itemInfo, target)
    target = target or {}
    itemInfo = tonumber(itemInfo)
    if not itemInfo or itemInfo <= 0 or itemInfo ~= math.floor(itemInfo) then
        return target, false, "invalid-item"
    end

    local Security = YUI.API and YUI.API.Security
    local IsSecretValue = Security and Security.IsSecretValue
    local icon = Item.GetIcon(itemInfo)
    local cooldown = Item.GetCooldown(itemInfo)
    local startTime = cooldown and cooldown.startTime
    local duration = cooldown and cooldown.duration
    local isEnabled = cooldown and cooldown.isEnabled
    local secret = false
    if IsSecretValue then
        secret = IsSecretValue(icon)
            or IsSecretValue(startTime)
            or IsSecretValue(duration)
            or IsSecretValue(isEnabled)
    end

    if secret then
        local changed = target.itemID ~= itemInfo
            or target.icon ~= nil
            or target.startTime ~= 0
            or target.duration ~= 0
            or target.isEnabled ~= false
            or target.available ~= true
            or target.secret ~= true
        target.itemID = itemInfo
        target.icon = nil
        target.startTime = 0
        target.duration = 0
        target.isEnabled = false
        target.available = true
        target.secret = true
        return target, changed
    end

    startTime = startTime or 0
    duration = duration or 0
    if isEnabled == nil then isEnabled = true end
    local available = icon ~= nil
    local changed = target.itemID ~= itemInfo
        or target.icon ~= icon
        or target.startTime ~= startTime
        or target.duration ~= duration
        or target.isEnabled ~= isEnabled
        or target.available ~= available
        or target.secret ~= false

    target.itemID = itemInfo
    target.icon = icon
    target.startTime = startTime
    target.duration = duration
    target.isEnabled = isEnabled
    target.available = available
    target.secret = false
    return target, changed
end

function Item.GetQualityColor(quality)
    if not quality then return 1, 1, 1, "ffffffff" end

    if C_Item and C_Item.GetItemQualityColor then
        return C_Item.GetItemQualityColor(quality)
    end

    if GetItemQualityColor then
        return GetItemQualityColor(quality)
    end

    return 1, 1, 1, "ffffffff"
end

function Item.IsUsable(itemInfo)
    if not itemInfo then return false, false end

    if YUI.IsRetail then
        if C_Item and C_Item.IsUsableItem then
            return C_Item.IsUsableItem(itemInfo)
        end
        if IsUsableItem then
            return IsUsableItem(itemInfo)
        end
        return false, false
    end

    if YUI.IsMists or YUI.IsWrath then
        if IsUsableItem then
            return IsUsableItem(itemInfo)
        end
        if C_Item and C_Item.IsUsableItem then
            return C_Item.IsUsableItem(itemInfo)
        end
        return false, false
    end

    if IsUsableItem then
        return IsUsableItem(itemInfo)
    end
    if C_Item and C_Item.IsUsableItem then
        return C_Item.IsUsableItem(itemInfo)
    end
    return false, false
end

function Item.IsEquippable(itemInfo)
    if not itemInfo then return false end

    if C_Item and C_Item.IsEquippableItem then
        return C_Item.IsEquippableItem(itemInfo)
    end

    if IsEquippableItem then
        return IsEquippableItem(itemInfo)
    end

    return false
end

function Item.IsEquipped(itemInfo)
    if not itemInfo then return false end

    if C_Item and C_Item.IsEquippedItem then
        return C_Item.IsEquippedItem(itemInfo)
    end

    if IsEquippedItem then
        return IsEquippedItem(itemInfo)
    end

    return false
end

function Item.IsKeystoneByID(itemInfo)
    if not itemInfo then return false end

    if C_Item and C_Item.IsItemKeystoneByID then
        return C_Item.IsItemKeystoneByID(itemInfo)
    end

    return false
end

function Item.EquipByName(itemInfo, target)
    if not itemInfo then return nil end

    if C_Item and C_Item.EquipItemByName then
        return C_Item.EquipItemByName(itemInfo, target)
    end

    if EquipItemByName then
        return EquipItemByName(itemInfo, target)
    end

    return nil
end

function Item.RequestLoadDataByID(itemInfo)
    if not itemInfo then return nil end

    if C_Item and C_Item.RequestLoadItemDataByID then
        return C_Item.RequestLoadItemDataByID(itemInfo)
    end

    return nil
end

function Item.GetInventoryItemLink(unit, slot)
    if GetInventoryItemLink then
        return GetInventoryItemLink(unit, slot)
    end
    return nil
end

function Item.GetInventoryItemTexture(unit, slot)
    if GetInventoryItemTexture then
        return GetInventoryItemTexture(unit, slot)
    end
    return nil
end

function Item.GetInventoryItemQuality(unit, slot)
    if GetInventoryItemQuality then
        return GetInventoryItemQuality(unit, slot)
    end
    return nil
end

function Item.GetInventoryItemDurability(slot)
    if GetInventoryItemDurability then
        return GetInventoryItemDurability(slot)
    end
    return nil, nil
end

function Item.GetInventoryItemID(unit, slot)
    if GetInventoryItemID then
        return GetInventoryItemID(unit, slot)
    end
    return nil
end

function Item.GetInventoryCooldown(unit, slot)
    if not GetInventoryItemCooldown then return nil end
    return NormalizeCooldown(GetInventoryItemCooldown(unit, slot))
end

local function ReadInventorySlotCooldown(
    unit,
    slot,
    target,
    activeOnly,
    refreshItemData
)
    target = target or {}
    local Security = YUI.API and YUI.API.Security
    local IsSecretValue = Security and Security.IsSecretValue

    local itemID = GetInventoryItemID and GetInventoryItemID(unit, slot)
    local icon = GetInventoryItemTexture and GetInventoryItemTexture(unit, slot)
    local startTime, duration, isEnabled
    if GetInventoryItemCooldown then
        startTime, duration, isEnabled = GetInventoryItemCooldown(unit, slot)
    end

    local secret = false
    if IsSecretValue then
        secret = IsSecretValue(itemID)
            or IsSecretValue(icon)
            or IsSecretValue(startTime)
            or IsSecretValue(duration)
            or IsSecretValue(isEnabled)
    end

    if secret then
        local changed = target.secret ~= true or target.available ~= false
        if activeOnly then
            changed = changed
                or target.equipped ~= false
                or target.isOnUse ~= false
                or target.itemDataPending ~= false
        end
        target.itemID = nil
        target.icon = nil
        target.startTime = 0
        target.duration = 0
        target.isEnabled = false
        target.available = false
        target.secret = true
        if activeOnly then
            target.equipped = false
            target.isOnUse = false
            target.itemDataPending = false
            target.requestedItemID = nil
        end
        return target, changed
    end

    startTime = startTime or 0
    duration = duration or 0
    if isEnabled == nil then isEnabled = true end
    local equipped = itemID ~= nil
    local isOnUse = false
    local itemDataPending = false
    if activeOnly and equipped then
        local classify = target.itemID ~= itemID
            or target.isOnUse == nil
            or refreshItemData == true
        if classify then
            local _, spellID = Item.GetSpell(itemID)
            isOnUse = type(spellID) == "number" and spellID > 0
            if not isOnUse and not Item.IsDataCachedByID(itemID) then
                itemDataPending = true
                if target.requestedItemID ~= itemID then
                    target.requestedItemID = itemID
                    Item.RequestLoadDataByID(itemID)
                end
            else
                target.requestedItemID = nil
            end
        else
            isOnUse = target.isOnUse == true
            itemDataPending = target.itemDataPending == true
        end
    elseif activeOnly then
        target.requestedItemID = nil
    end
    local available = equipped and (not activeOnly or isOnUse)
    local changed = target.itemID ~= itemID
        or target.icon ~= icon
        or target.startTime ~= startTime
        or target.duration ~= duration
        or target.isEnabled ~= isEnabled
        or target.available ~= available
        or target.secret ~= false
    if activeOnly then
        changed = changed
            or target.equipped ~= equipped
            or target.isOnUse ~= isOnUse
            or target.itemDataPending ~= itemDataPending
    end

    target.itemID = itemID
    target.icon = icon
    target.startTime = startTime
    target.duration = duration
    target.isEnabled = isEnabled
    target.available = available
    target.secret = false
    if activeOnly then
        target.equipped = equipped
        target.isOnUse = isOnUse
        target.itemDataPending = itemDataPending
    end
    return target, changed
end

function Item.ReadInventorySlotCooldown(unit, slot, target)
    return ReadInventorySlotCooldown(unit, slot, target, false, false)
end

function Item.ReadActiveInventorySlotCooldown(unit, slot, target, refreshItemData)
    return ReadInventorySlotCooldown(
        unit,
        slot,
        target,
        true,
        refreshItemData == true
    )
end

Legacy.GetItemIcon = Item.GetIcon
Legacy.GetItemName = Item.GetName
Legacy.GetItemNameByID = Item.GetNameByID
Legacy.GetItemSpell = Item.GetSpell
Legacy.GetItemUseEffectDurationSeconds = Item.GetUseEffectDurationSeconds
Legacy.GetItemMaxStackSize = Item.GetMaxStackSize
Legacy.GetItemLevel = Item.GetLevel
Legacy.GetItemCount = Item.GetCount
Legacy.GetItemCooldownInfo = Item.GetCooldown
Legacy.ReadItemCooldown = Item.ReadItemCooldown
Legacy.GetItemQualityColor = Item.GetQualityColor
Legacy.IsUsableItem = Item.IsUsable
Legacy.IsEquippableItem = Item.IsEquippable
Legacy.IsEquippedItem = Item.IsEquipped
Legacy.IsItemKeystoneByID = Item.IsKeystoneByID
Legacy.EquipItemByName = Item.EquipByName
Legacy.GetInventoryItemLink = Item.GetInventoryItemLink
Legacy.GetInventoryItemTexture = Item.GetInventoryItemTexture
Legacy.GetInventoryItemQuality = Item.GetInventoryItemQuality
Legacy.GetInventoryItemDurability = Item.GetInventoryItemDurability
Legacy.GetInventoryItemID = Item.GetInventoryItemID
Legacy.GetInventoryCooldown = Item.GetInventoryCooldown
Legacy.ReadInventorySlotCooldown = Item.ReadInventorySlotCooldown
