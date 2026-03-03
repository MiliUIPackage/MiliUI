
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip

local function GetItemInfoFromLink(linkOrId)
    local name, link, quality, _, _, _, _, stackCount, _, texture = GetItemInfo(linkOrId)
    if (not name) then return nil end
    return {
        itemLink = link,
        itemQuality = quality,
        itemStackCount = stackCount,
        itemTexture = texture,
    }
end

local function GetTooltipTitleColor(tip)
    if (not tip or not tip.GetName) then return end
    local left = _G[tip:GetName() .. "TextLeft1"]
    if (not left or not left.GetTextColor) then return end
    local ok, r, g, b = pcall(left.GetTextColor, left)
    if (not ok) then return end
    if (type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number") then
        return
    end
    return r, g, b
end

local function ColorBorder(tip, r, g, b)
    if (addon.db.item.coloredItemBorder) then
        LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
    else
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
    end
end

local function ItemIcon(tip, itemInfo)
    if (addon.db.item.showItemIcon) then
        local texture = itemInfo and itemInfo.itemTexture
        local text = addon:GetLine(tip,1):GetText()
        if (texture and not strfind(text, "^|T")) then
            addon:GetLine(tip,1):SetFormattedText("|T%s:16:16:0:0:32:32:2:30:2:30|t %s", texture, text)
        end
    end
end

local function ItemStackCount(tip, itemInfo)
    if (addon.db.item.showStackCount) then
        local stackCount = itemInfo and itemInfo.itemStackCount
        if (stackCount and stackCount > 1) then
            local text = addon:GetLine(tip,1):GetText() .. format(" |cff00eeee/%s|r", stackCount)
            addon:GetLine(tip,1):SetText(text)
        end
    end
end

LibEvent:attachTrigger("tooltip:item", function(self, tip, link)
    if (addon.db and addon.db.general) then
        LibEvent:trigger("tooltip.style.bgfile", tip, addon.db.general.bgfile)
        if (addon.db.general.background) then
            LibEvent:trigger("tooltip.style.background", tip, unpack(addon.db.general.background))
        end
        LibEvent:trigger("tooltip.style.border.corner", tip, addon.db.general.borderCorner)
        if (addon.db.general.borderCorner == "angular") then
            LibEvent:trigger("tooltip.style.border.size", tip, addon.db.general.borderSize)
        end
    end
    local itemInfo = GetItemInfoFromLink(link)
    local quality = (itemInfo and itemInfo.itemQuality) or 0
    local r, g, b = GetItemQualityColor(quality)
    local tr, tg, tb = GetTooltipTitleColor(tip)
    if (tr and tg and tb) then
        r, g, b = tr, tg, tb
    end
    ColorBorder(tip, r, g, b)
    ItemStackCount(tip, itemInfo)
    ItemIcon(tip, itemInfo)
end)
