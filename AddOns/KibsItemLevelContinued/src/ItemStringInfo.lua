local addonName, addonNamespace = ...

local ItemStringInfo = {}
ItemStringInfo.__index = ItemStringInfo

addonNamespace.ItemStringInfo = ItemStringInfo

function ItemStringInfo:new(itemString)
    local _type, itemId, enchantId, jewelId1, jewelId2, jewelId3, jewelId4, suffixId, uniqueId, linkLevel, specializationID, reforgeId, unknown1, unknown2, unknown3, unknown4

    if type(itemString) == "string" then
        itemString = string.match(itemString,"^|%x%x%x%x%x%x%x%x%x|H([^|]+)|h") or itemString
        _type, itemId, enchantId, jewelId1, jewelId2, jewelId3, jewelId4, suffixId, uniqueId, linkLevel, specializationID, reforgeId, unknown1, unknown2, unknown3, unknown4 = strsplit(
            ":",
            itemString
        )
    end

    return setmetatable({
        itemString = itemString,
        type = _type,
        itemId = tonumber(itemId) or 0,
        enchantId = tonumber(enchantId) or 0,
        jewelId1 = tonumber(jewelId1) or 0,
        jewelId2 = tonumber(jewelId2) or 0,
        jewelId3 = tonumber(jewelId3) or 0,
        jewelId4 = tonumber(jewelId4) or 0,
        suffixId = tonumber(suffixId) or 0,
        uniqueId = tonumber(uniqueId) or 0,
        linkLevel = tonumber(linkLevel) or 0,
        specializationID = tonumber(specializationID) or 0,
        reforgeId = tonumber(reforgeId) or 0,
        unknown1 = tonumber(unknown1) or 0,
        unknown2 = tonumber(unknown2) or 0,
        unknown3 = tonumber(unknown3) or 0,
        unknown4 = tonumber(unknown4) or 0,
        itemLevel = false,
        upgrades = nil,
    }, self)
end

function ItemStringInfo:getItemString()
    return self.itemString
end

function ItemStringInfo:getStrippedInfo()
    return ItemStringInfo:new(
        self.type
        ..":"..self.itemId
        ..":"..0
        ..":"..0
        ..":"..0
        ..":"..0
        ..":"..0
        ..":"..self.suffixId
        ..":"..self.uniqueId
        ..":"..self.linkLevel
        ..":"..self.specializationID
        ..":"..self.reforgeId
        ..":"..self.unknown1
        ..":"..self.unknown2
        ..":"..self.unknown3
        ..":"..self.unknown4
    )
end

function ItemStringInfo:getLink()
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(self.itemString)
    return itemLink
end

function ItemStringInfo:getEnchantInfo()
    return self.enchantId ~= 0 and addonNamespace.ItemEnchantInfo:new(self.enchantId) or nil
end

function ItemStringInfo:getTextureName()
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(self.itemString)
    return itemTexture
end

function ItemStringInfo:isTwoHandedWeapon()
    local _, _, _, _, _, _, _, _, itemEquipLoc, _, _, _, _ = GetItemInfo(self.itemString)
    return itemEquipLoc == 'INVTYPE_2HWEAPON' or itemEquipLoc == 'INVTYPE_RANGED'
end

function ItemStringInfo:getQualityColor()
    local quality = select(3, GetItemInfo(self.itemString));

    if quality then
        return select(4, GetItemQualityColor(quality))
    end

    return nil
end

local InvisibleTooltip = CreateFrame("GameTooltip", addonName.."InvisibleTooltip", nil, "GameTooltipTemplate")

function ItemStringInfo:getSockets(parent)
    -- Based on Bimbo add-on code

    local result = {}
    local link = self:getStrippedInfo():getLink()

    if link then
        local n = 30

        for i = 1, n do
            local texture = _G[InvisibleTooltip:GetName().."Texture"..i]
            if texture then
                texture:SetTexture(nil)
            end
        end

        InvisibleTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
        InvisibleTooltip:SetHyperlink(link)

        for i = 1, n do
            local texture = _G[InvisibleTooltip:GetName().."Texture"..i]
            local textureName = texture and texture:GetTexture()

            if textureName then
                local map = {
                    ["INTERFACE/ITEMSOCKETINGFRAME/UI-EMPTYSOCKET-PRISMATIC"] = addonNamespace.SocketInfo.TYPE.PRISMATIC,
                    ["INTERFACE/ITEMSOCKETINGFRAME/UI-EMPTYSOCKET-RED"] = addonNamespace.SocketInfo.TYPE.RED,
                    ["INTERFACE/ITEMSOCKETINGFRAME/UI-EMPTYSOCKET-BLUE"] = addonNamespace.SocketInfo.TYPE.BLUE,
                    ["INTERFACE/ITEMSOCKETINGFRAME/UI-EMPTYSOCKET-YELLOW"] = addonNamespace.SocketInfo.TYPE.YELLOW,
                    ["INTERFACE/ITEMSOCKETINGFRAME/UI-EMPTYSOCKET-META"] = addonNamespace.SocketInfo.TYPE.META,
                }

                local canonicalTextureName = string.gsub(string.upper(textureName), "\\", "/")
                local socketTypeId = map[canonicalTextureName] or addonNamespace.SocketInfo.TYPE.UNKNOWN
                local _, gemItemLink = GetItemGem(self:getLink(), i)

                table.insert(result, addonNamespace.SocketInfo:new(socketTypeId, gemItemLink and ItemStringInfo:new(gemItemLink) or nil))
            end
        end
    end

    return result
end

function ItemStringInfo:IsArtifact()
    local quality = select(3, GetItemInfo(self.itemString))
    return quality == 6
end

function ItemStringInfo:getItemLevel()
    if self.itemLevel == false then
        self.itemLevel = nil

        local link = self:getLink()

        if link then
            InvisibleTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
            InvisibleTooltip:SetHyperlink(self:getLink())

            for i = 1, 5 do
                local text = _G[InvisibleTooltip:GetName().."TextLeft"..i]

                if text then
                    local result = tonumber((text:GetText() or ""):match("%d+$") or "0")
                    if result > 0 then
                        self.itemLevel = result
                        break
                    end
                end
            end
        end
    end

    return self.itemLevel
end

function ItemStringInfo:GetUpgrades()
    if not self.upgrades then
        self.upgrades = {nil, nil}

        local link = self:getLink()

        if link then
            InvisibleTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
            InvisibleTooltip:SetHyperlink(self:getLink())

            for i = 1, 5 do
                local text = _G[InvisibleTooltip:GetName().."TextLeft"..i]

                if text then
                    local current, max = (text:GetText() or ""):match("(%d+)/(%d+)$")
                    if current and max then
                        self.upgrades = {current, max}
                        break
                    end
                end
            end
        end
    end

    return unpack(self.upgrades)
end