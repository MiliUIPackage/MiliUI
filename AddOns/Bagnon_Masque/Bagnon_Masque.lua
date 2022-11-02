--[[
Copyright 2011-2022 João Cardoso
Bagnon Masque is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Bagnon Masque.

Bagnon Masque is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Bagnon Masque is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Bagnon Masque. If not, see <http://www.gnu.org/licenses/>.
--]]

local Masque = LibStub('Masque')
local Addon = Bagnon or Bagnonium
if not Addon then return end

for i, frameID in ipairs {'inventory', 'bank', 'guildbank', 'voidstorage'} do
	Masque:Group(Addon.Name, frameID .. ' - items')
	Masque:Group(Addon.Name, frameID .. ' - bags')
end


--[[ Overrides ]]--

local Item, Bag = Addon.Item, Addon.Bag
local NewItem, ReleaseItem = Item.New, Item.Release
local NewBag = Bag.New

function Item:New(...)
	local b = NewItem(self, ...)
	local name = b:GetName()

	Masque:Group(Addon.Name, b:GetFrameID() .. ' - items'):AddButton(b, {
		Count = b.Count or _G[name .. 'Count'],
		Icon = b.icon or _G[name .. 'IconTexture'],
		Normal = b:GetNormalTexture(),
		Pushed = b:GetPushedTexture(),
		Highlight = b:GetHighlightTexture(),
		Cooldown = b.Cooldown,
		Border = b.IconGlow,
	})

	b.IconBorder:SetAlpha(0)
	return b
end

function Item:Release()
	if self:GetFrameID() then
		Masque:Group(Addon.Name, self:GetFrameID() .. ' - items'):RemoveButton(self)
	end

	ReleaseItem(self)
end

function Bag:New(...)
	local b = NewBag(self, ...)

	Masque:Group(Addon.Name, b:GetFrameID() .. ' - bags'):AddButton(b, {
		Count = b.Count,
		Icon = b.Icon,

		Normal = b:GetNormalTexture(),
		Highlight = b:GetHighlightTexture(),
		Pushed = b:GetPushedTexture(),
		Checked = b:GetCheckedTexture(),
	})

	return b
end
