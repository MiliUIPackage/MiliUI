local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
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

Legacy.GetItemIcon = Item.GetIcon
Legacy.GetItemName = Item.GetName
Legacy.GetItemNameByID = Item.GetNameByID
Legacy.GetItemLevel = Item.GetLevel
Legacy.GetItemCount = Item.GetCount
Legacy.GetItemCooldownInfo = Item.GetCooldown
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
