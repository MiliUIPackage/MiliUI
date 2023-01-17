
local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local clientVer, clientBuild, clientDate, clientToc = GetBuildInfo()

-- load only on classic wotlk
if (clientToc == 30400) then
  local LibInspect = LibStub("LibClassicInspector")
  local LibDetours = LibStub("LibDetours-1.0")
  local TinyTooltipGS = TTR_GS
end

local addon = TinyTooltipReforged

local function FindLine(tooltip, keyword)
    local line, text
    for i = 2, tooltip:NumLines() do
        line = _G[tooltip:GetName() .. "TextLeft" .. i]
        text = line:GetText() or ""
        if (string.find(text, keyword)) then
            return line, i, _G[tooltip:GetName() .. "TextRight" .. i]
        end
    end
end

local function ColorBorder(tip, r, g, b)
    if (addon.db.item.coloredItemBorder) then
        LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
    else
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
    end
end

local function ItemIcon(tip, link)
    if (addon.db.item.showItemIcon) then
        local texture = select(10, GetItemInfo(link))
        local text = addon:GetLine(tip,1):GetText()
        if (texture and not strfind(text, "^|T")) then
            addon:GetLine(tip,1):SetFormattedText("|T%s:16:16:0:0:32:32:2:30:2:30|t %s", texture, text)
        end
    end
end

local function ItemStackCount(tip, link)
    if (addon.db.item.showStackCount) then
        local stackCount = select(8, GetItemInfo(link))
        if (stackCount and stackCount > 1) then
            local text = addon:GetLine(tip,1):GetText() .. format(" |cff00eeee/%s|r", stackCount)
            addon:GetLine(tip,1):SetText(text)
        end
    end
end

LibEvent:attachTrigger("tooltip:item", function(self, tip, link)
    local quality = select(3, GetItemInfo(link)) or 0
    -- before legion 7.1.0 client
    if (clientToc <= 70100) then
      if (not self) then return end
      local iName, iLink, iRare, ilvl = GetItemInfo(link)
      local ilvlLine, _, lineRight = FindLine(tip, "Item Level")
      local ilvlText = format("%s |cffffffff%d|r", "Item Level", tonumber(ilvl))
      if (ilvl and tonumber(ilvl)>1) then 
          if (not ilvlLine) then
              tip:AddDoubleLine(ilvlText, "")
          else
              ilvlLine:SetText(ilvlText)
          end 
      end
    else
      local effectiveILvl, isPreview, baseILvl = GetDetailedItemLevelInfo(link)
      if (effectiveILvl and tonumber(effectiveILvl)>1) then
          -- Not needed generally as already on blizz tooltip
          --tip:AddLine(format("Item Level %d", tonumber(effectiveILvl)))
      end
    end
    local r, g, b = GetItemQualityColor(quality)
    ColorBorder(tip, r, g, b)
    ItemStackCount(tip, link)
    ItemIcon(tip, link)
end)


local function EmbeddedItemTooltip_OnTooltipSetItem(self, data)
    if (not self or self:GetObjectType() ~= "GameTooltip") then return end
    --local r, g, b = self.IconBorder:GetVertexColor()
    ColorBorder(self, r, g, b)
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, EmbeddedItemTooltip_OnTooltipSetItem)








