--[[
Copyright 2009-2015 João Cardoso
Blitz Progress is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Blitz Progress.

Blitz Progress is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Blitz Progress is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Blitz Progress. If not, see <http://www.gnu.org/licenses/>.
--]]

AchievementShield_OnLoad = AchievementShield_OnLoad or function() end --it's to only way to use this template

local name = 'BlitzProgress'
local Progress = CreateFrame('Button', name, UIParent, 'AchievementAlertFrameTemplate')
local ItemIcon, ItemCount, Portrait, Title, ArrowFill, ArrowSpark = BlitzProgressIconTexture


--[[ Frame ]]--

function Progress:Startup()
	-- Tweaks
	local BackPatch = self:CreateTexture(name..'BackgroundPatch', 'BORDER')
	BackPatch:SetTexture('Interface\\Addons\\Blitz\\Media\\Background Patch') 
	BackPatch:SetPoint('CENTER', _G[name..'Background'], 104, -20)
	
	_G[name..'Glow']:Hide()
	_G[name..'Shine']:Hide()
	_G[name..'Shield']:Hide()
	_G[name..'Name']:Hide()
	
	-- NPC Portrait
	local PortraitBorder = self:CreateTexture(name..'PortraitBorder', 'OVERLAY', 7)
	PortraitBorder:SetTexture('Interface/AchievementFrame/UI-Achievement-IconFrame')
	PortraitBorder:SetTexCoord(0.5625, 0, 0, 0.5625)
	PortraitBorder:SetPoint('TOPRIGHT', 0, -7)
	PortraitBorder:SetSize(73, 73)
	
	Portrait = self:CreateTexture(name..'Portrait', 'ARTWORK')
	Portrait:SetPoint('CENTER', PortraitBorder)
	Portrait:SetSize(55, 55)
	
	-- Quest Title
	local TitleBack = self:CreateTexture(name..'TitleBackground', 'ARTWORK')
	TitleBack:SetTexture('Interface/AchievementFrame/UI-Achievement-Reward-Background')
	TitleBack:SetWidth(250) TitleBack:SetHeight(21)
	TitleBack:SetVertexColor(.5, .5, .5)
	TitleBack:SetPoint('TOP', 40, -15)
	TitleBack:SetTexCoord(0, 1, 1, 0)
	
	Title = _G[name .. 'Unlocked']
	Title:SetTextColor(.8, .8, .8)
	Title:SetDrawLayer('OVERLAY')
	Title:SetPoint('TOP', 1, -24)
	Title:SetWidth(110)
	
	-- Required Items
	ItemCount = _G[name .. 'Icon']:CreateFontString(name ..'ItemCount', 'OVERLAY', 'NumberFontNormal')
	ItemCount:SetPoint('BOTTOMRIGHT', _G[name .. 'IconTexture'], -4, 4)
	
	-- Progress Arrow
	local Arrow = self:CreateTexture(name..'Arrow', 'ARTWORK')
	Arrow:SetTexture('Interface\\Addons\\Blitz\\Media\\Arrow')
	Arrow:SetPoint('CENTER', 1, -2)
	Arrow:SetSize(190, 50)
	
	ArrowFill = self:CreateTexture(name..'ArrowFill', 'OVERLAY', 5)
	ArrowFill:SetTexture('Interface\\Addons\\Blitz\\Media\\Arrow Fill')
	ArrowFill:SetPoint('LEFT', Arrow) ArrowFill:SetHeight(50)
	
	ArrowSpark = self:CreateTexture(name..'ArrowSpark', 'OVERLAY', 6)
	ArrowSpark:SetTexture('Interface/CastingBar/UI-CastingBar-Spark')
	ArrowSpark:SetBlendMode('ADD') ArrowSpark:SetSize(14, 14)
	ArrowSpark:SetPoint('RIGHT', ArrowFill, 8, 0)
	
	-- The End
	hooksecurefunc('AlertFrame_FixAnchors', function()
		self:UpdatePosition()
	end)
	
	self.waitAndAnimOut.animOut:SetDuration(.7)
	self:RegisterForClicks(nil)
	self.Startup = nil
end


--[[ Update ]]--

function Progress:ShowQuest(quest, data, numDelivers)
	if not self:IsShown() or Title:GetText() ~= quest then
		local numStacks = 2^10000
		for item, required in gmatch(data, '(%d+):(%d+)') do
			local stacks = floor(GetItemCount(item) / tonumber(required))
			if stacks < numStacks then
				numStacks = stacks
				self.stack = required
				self.item = item
			end
		end
		
		self.totalDelivers = numDelivers
		ItemIcon:SetTexture(GetItemIcon(self.item))
		SetPortraitTexture(Portrait, 'NPC')
		Title:SetText(quest)
	end

	local color = numDelivers > 1 and 1 or 0.4
	local progress = min(max(numDelivers / self.totalDelivers, 0), 1) * 0.93
	
	ItemCount:SetText(format('%s/%s', GetItemCount(self.item) or '?', self.stack or '?'))
	ItemIcon:SetVertexColor(color, color, color)
	ArrowFill:SetTexCoord(0, progress, 0, 1)
	ArrowFill:SetWidth(190 * progress)
	
	AlertFrame_AnimateIn(self)
	AlertFrame_StopOutAnimation(self)
	AlertFrame_ResumeOutAnimation(self)
end

function Progress:UpdatePosition()
	if self:IsShown() then
		DungeonCompletionAlertFrame1:SetPoint('BOTTOM', self, 'TOP', 0, 10)

		for i= 2, 1, -1 do
			local frame = _G['AchievementAlertFrame'..i]
			if frame and frame:IsShown() then
				return self:SetPoint('BOTTOM', frame, 'TOP', 0, -10)
			end
		end
			
		for i = NUM_GROUP_LOOT_FRAMES, 1, -1 do
			local frame = _G['GroupLootFrame'..i]
			if frame and frame:IsShown() then
				return self:SetPoint('BOTTOM', frame, 'TOP', 0, 10)
			end
		end
		
		self:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 128)
	end
end

Progress:Startup()