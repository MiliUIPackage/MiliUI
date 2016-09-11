local addonName, addonNamespace = ...

local Tooltip = {}
Tooltip.__index = Tooltip

addonNamespace.Tooltip = Tooltip

local TYPE_HYPERLINK = 1
local TYPE_TEXT = 2

local FIELD_TYPE = 1
local FIELD_CONTENT = 2

function Tooltip:new()
    return setmetatable({
        items = {},
        link = nil,
    }, self)
end

function Tooltip:AddHyperlink(link)
    if link then
        table.insert(self.items, {
            TYPE_HYPERLINK,
            link,
        })
    end
    return self
end

function Tooltip:AddText(text)
    table.insert(self.items, {
        TYPE_TEXT,
        text,
    })
    return self
end

local Tooltips = {}

function Tooltip:_HideTooltips()
    for _, tooltip in pairs(Tooltips) do
        tooltip:Hide()
    end
end

function Tooltip:_ShowTooltips(parent, items)
    self:_HideTooltips()

    local i = 1
    local maxSize = 0

    self.link = nil

    for _, item in pairs(items) do
        if item then
            if not Tooltips[i] then
                Tooltips[i] = CreateFrame("GameTooltip", addonName .. "Tooltip" .. i, GameTooltip:GetParent(), "GameTooltipTemplate")
                Tooltips[i]:SetScale(GameTooltip:GetScale())
            end

            if i == 1 then
                Tooltips[i]:SetOwner(parent, "ANCHOR_RIGHT")
            else
                Tooltips[i]:SetOwner(Tooltips[i - 1], "ANCHOR_NONE")
                Tooltips[i]:SetPoint("TOPLEFT", Tooltips[i - 1], "TOPRIGHT")
            end

            if item[FIELD_TYPE] == TYPE_HYPERLINK then
                Tooltips[i]:SetHyperlink(item[FIELD_CONTENT])
                self.link = item[FIELD_CONTENT]
            elseif item[FIELD_TYPE] == TYPE_TEXT then
                Tooltips[i]:SetText(item[FIELD_CONTENT])
            end

            maxSize = max(Tooltips[i]:GetHeight(), maxSize)
        end

        i = i + 1
    end

    --    for j = 1, i - 1 do
    --        Tooltips[j]:SetHeight(maxSize)
    --    end
end

function Tooltip:HasLink()
    return not not self.link
end

function Tooltip:GetLink()
    return self.link
end

function Tooltip:Show(parent)
    self:_ShowTooltips(parent, self.items)
end

function Tooltip:Hide()
    self:_HideTooltips()
end