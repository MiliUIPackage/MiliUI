--[[

	The MIT License (MIT)

	Copyright (c) 2023 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
local Addon, Private =  ...
if (Private.Incompatible) then
	print("|cffff1111"..Addon.." was auto-disabled.")
	return
end

local Module = Bagnon:NewModule(Addon, Private)

-- Speed!
local _G = _G
local ipairs = ipairs
local string_match = string.match
local tonumber = tonumber

local retail = Private.IsRetail
local cache = Private.cache
local tooltip = Private.tooltip
local tooltipName = Private.tooltipName
local battlepetclass = Enum.ItemClass.Battlepet

-- Font object
local font_object = NumberFont_Outline_Med or NumberFontNormal

-- Search patterns
local s_item_level = "^" .. string.gsub(ITEM_LEVEL, "%%d", "(%%d+)")
local s_num_slots = "^" .. (string.gsub(string.gsub(CONTAINER_SLOTS, "%%([%d%$]-)d", "(%%d+)"), "%%([%d%$]-)s", "%.+"))

-- Custom color cache
-- Allows us control, gives us speed.
local colors = {
	[0] = { 157/255, 157/255, 157/255 }, -- Poor
	[1] = { 240/255, 240/255, 240/255 }, -- Common
	[2] = { 30/255, 178/255, 0/255 }, -- Uncommon
	[3] = { 0/255, 112/255, 221/255 }, -- Rare
	[4] = { 163/255, 53/255, 238/255 }, -- Epic
	[5] = { 225/255, 96/255, 0/255 }, -- Legendary
	[6] = { 229/255, 204/255, 127/255 }, -- Artifact
	[7] = { 79/255, 196/255, 225/255 }, -- Heirloom
	[8] = { 79/255, 196/255, 225/255 } -- Blizzard
}
for i = 0, (retail and Enum.ItemQualityMeta.NumValues or NUM_LE_ITEM_QUALITYS) - 1 do
	if (not colors[i]) then
		local r, g, b = GetItemQualityColor(i)
		colors[i] = { r, g, b }
	end
end


Module:AddUpdater(function(self)

	local message, color, _

	if (self.hasItem) then

		-- https://wowpedia.fandom.com/wiki/Enum.InventoryType
		local class, equip, level, quality = self.info.class, self.info.equip, self.info.level, self.info.quality
		if (not equip) then
			_,_,_,equip = GetItemInfoInstant(self.info.hyperlink)
		end
		local noequip = not equip or not _G[equip] or quip == "INVTYPE_BAG" or equip == "INVTYPE_NON_EQUIP" or equip == "INVTYPE_TABARD" or equip == "INVTYPE_AMMO" or equip == "INVTYPE_QUIVER" or equip == "INVTYPE_BODY"
		local isbag = equip == "INVTYPE_BAG"
		local isgear = quality and quality > 0 and not noequip
		local ispet = battlepetclass and class == battlepetclass

		-- We only want quality coloring on item- and pet levels, not bag slots.
		if (isgear or ispet) and (BagnonItemLevel_DB.enableRarityColoring) then
			color = quality and colors[quality]
			message = level
		end

		-- Only retail tooltips contain iteminfo for gear,
		-- but only retail tooltips need it.
		if (isgear and retail) or (isbag) then

			if (retail) then

				local tooltipData = C_TooltipInfo.GetBagItem(self:GetBag(), self:GetID())

				-- Assign data to 'type' and 'guid' fields.
				TooltipUtil.SurfaceArgs(tooltipData)

				-- Assign data to 'leftText' fields.
				for _, line in ipairs(tooltipData.lines) do
					TooltipUtil.SurfaceArgs(line)
				end

				if (isgear) then
					for i = 2,3 do
						local msg = tooltipData.lines[i] and tooltipData.lines[i].leftText
						if (not msg) then break end

						local itemlevel = string_match(msg, s_item_level)
						if (itemlevel) then
							itemlevel = tonumber(itemlevel)
							if (itemlevel > 0) then
								message = itemlevel
							end
							break
						end
					end
				end

				if (isbag) then
					for i = 3,4 do
						local msg = tooltipData.lines[i] and tooltipData.lines[i].leftText
						if (not msg) then break end

						local numslots = string_match(msg, s_num_slots)
						if (numslots) then
							numslots = tonumber(numslots)
							if (numslots > 0) then
								message = numslots
							end
							break
						end
					end
				end

			else

				if (not tooltip.owner or not tooltip.bag or not tooltip.slot) then
					tooltip.owner, tooltip.bag,tooltip.slot = self, self:GetBag(), self:GetID()
					tooltip:SetOwner(tooltip.owner, "ANCHOR_NONE")
					tooltip:SetBagItem(tooltip.bag, tooltip.slot)
				end

				if (isbag) then
					for i = 3,4 do
						local line = _G[tooltipName.."TextLeft"..i]
						if (not line) then
							break
						end

						local numslots = string_match(line:GetText() or "", s_num_slots)
						if (numslots) then
							numslots = tonumber(numslots)
							if (numslots > 0) then
								message = numslots
							end
							break
						end
					end
				end

			end
		end
	end

	if (message) then

		local label = cache[self]
		if (not label) then

			-- Only one container per item.
			local name = self:GetName().."ExtraInfoFrame"
			local container = _G[name]
			if (not container) then
				container = CreateFrame("Frame", name, self)
				container:SetAllPoints()
			end

			-- Always move this to the same place.
			local upgrade = self.UpgradeIcon
			if (upgrade) then
				upgrade:ClearAllPoints()
				upgrade:SetPoint("BOTTOMRIGHT", 2, 0)
			end

			-- This is specific to this plugin.
			label = container:CreateFontString()
			label:SetDrawLayer("ARTWORK", 1)
			label:SetPoint("TOP", 2, -3)
			label:SetFontObject(font_object)
			label:SetShadowOffset(1, -1)
			label:SetShadowColor(0, 0, 0, 1)
			label:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
			
			cache[self] = label
		end

		label:SetText(message)

		if (color) then
			label:SetTextColor(color[1], color[2], color[3])
		else
			label:SetTextColor(.94, .94, .94)
		end

	elseif (cache[self]) then
		cache[self]:SetText("")
	end

end)
