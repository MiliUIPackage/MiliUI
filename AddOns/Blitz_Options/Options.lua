--[[
Copyright 2009-2015 João Cardoso
Blitz is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Blitz.

Blitz is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Blitz is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Blitz. If not, see <http://www.gnu.org/licenses/>.
--]]

local Options = SushiMagicGroup(BlitzOptions)
local Tutorials = LibStub('CustomTutorials-2.1')
local L = Blitz_Locals


--[[ Options ]]--

Options:SetFooter('Copyright 2009-2015 João Cardoso')
Options:SetAddon('Blitz')
Options:SetChildren(function(self)
	self:Create('CheckButton', 'Accept')
	self:Create('CheckButton', 'Deliver')
	self:Create('CheckButton', 'SelectReward', nil, not Blitz_Deliver, true)
	self:Create('CheckButton', 'Manual')
	
	local Dropdown = self:Create('Dropdown', Blitz_Manual and 'AutomateKey' or 'ManualKey', 'Key')
	Dropdown:AddLine('Alt', ALT_KEY)
	Dropdown:AddLine('Control', CTRL_KEY)
	Dropdown:AddLine('Shift', SHIFT_KEY)
	Dropdown:AddLine(false, NONE_KEY)
	Dropdown:SetWidth(135)
end)



--[[ Tutorials ]]--

Tutorials.RegisterTutorials('Blitz', {
	savedvariable = 'Blitz_Tutorials',
	title = L.Welcome,
	
	{
		text = L.Tutorial1,
		image = 'Interface\\Addons\\Blitz\\Media\\Tutorial',
		shineTop = 4, shineBottom = -4, shineLeft = -6,
		shineRight = BlitzText:GetWidth() + 10,
		shine = Blitz,
		point = 'TOPRIGHT',
		x = -25, y = -180,
	},
	{
		text = L.Tutorial2,
		shine = MainMenuMicroButton,
		shineTop = -21, shineBottom = 1,
		shineLeft = -2, shineRight = 2,
		point = 'TOPRIGHT',
		x = -25, y = -180,
	},
})