--[[
SharedMedia_ButtonHighlight - Additional information about player spells.
(c) 2014 Adirelle (adirelle@gmail.com)

This file is part of SharedMedia_ButtonHighlight.

SharedMedia_ButtonHighlight is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

SharedMedia_ButtonHighlight is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with SharedMedia_ButtonHighlight.  If not, see <http://www.gnu.org/licenses/>.
--]]

local MAJOR, MINOR, lib = "SharedMedia_ButtonHighlight", 1
if LibStub then
	lib = LibStub:NewLibrary(MAJOR, MINOR)
	if not lib then return end
else
	lib = {}
end

local LSM = LibStub('LibSharedMedia-3.0')
local BUTTON_HIGHLIGHT_MEDIATYPE = "button_highlight"

local L = setmetatable({}, { __index = function(t, k) return k end })

LSM.MediaType.BUTTON_HIGHLIGHT = BUTTON_HIGHLIGHT_MEDIATYPE

-- Register alternative highlights
local texturePath = [[Interface\AddOns\]]..strmatch(debugstack(1, 1, 1), [[^.-AddOns\(.-\)SMBH%.lua]])..[[media\]]
for file, label in pairs {
	["blank"]                    = L["No border"],
	["bottom-top-gradient"]      = L["Bottom to top gradient"],
	["corners"]                  = L["Square corners"],
	["default-border"]           = L["Default border"],
	["left-right-gradient"]      = L["Left to right gradient"],
	["right-left-gradient"]      = L["Right to left gradient"],
	["thin-border"]              = L["Thin border"],
	["top-bottom-gradient"]      = L["Top to bottom gradient"],
	["top-left-gradient"]        = L["Top left corner gradient"],
	["top-left-half-gradient"]   = L["Top left half gradient"],
	["x"]                        = L["X-shaped border"],
	["y"]                        = L["Y-shaped border"],
} do
	LSM:Register(BUTTON_HIGHLIGHT_MEDIATYPE, label, texturePath..file)
end
LSM:SetDefault(BUTTON_HIGHLIGHT_MEDIATYPE, L["Default border"])
