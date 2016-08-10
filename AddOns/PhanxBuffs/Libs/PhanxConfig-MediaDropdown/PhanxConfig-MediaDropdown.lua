--[[--------------------------------------------------------------------
	PhanxConfig-MediaDropdown
	Dropdown media selectors for LibSharedMedia-3.0
	https://github.com/Phanx/PhanxConfig-Dropdown
	Copyright (c) 2015 Phanx <addons@phanx.net>. All rights reserved.
	Feel free to include copies of this file WITHOUT CHANGES inside World of
	Warcraft addons that make use of it as a library, and feel free to use code
	from this file in other projects as long as you DO NOT use my name or the
	original name of this file anywhere in your project outside of an optional
	credits line -- any modified versions must be renamed to avoid conflicts.
----------------------------------------------------------------------]]

local MINOR_VERSION = 20150129

local lib, oldminor = LibStub:NewLibrary("PhanxConfig-MediaDropdown", MINOR_VERSION)
if not lib then return end

local Dropdown = LibStub("PhanxConfig-Dropdown")
local SharedMedia = LibStub("LibSharedMedia-3.0")

local mediaTypes = {}

--------------------------------------------------------------------------------

local function font_SetText(self, value)
	local font = SharedMedia:Fetch("font", value)
	local _, height, flags = self:GetFont()
	self:SetFont(font, height, flags)
end

local function font_OnListButtonChanged(self, button, value, selected)
	if button:IsShown() then
		button:GetFontString():SetFont(SharedMedia:Fetch("font", value), UIDROPDOWNMENU_DEFAULT_TEXT_HEIGHT)
	end
end

local function font_SetValue(self, value)
	local font = SharedMedia:Fetch("font", value)
	local _, height, flags = self.valueText:GetFont()
	self.valueText:SetFont(font, height, flags)
	self:__SetValue(value)
end

mediaTypes["font"] = function(dropdown)
	dropdown.OnListButtonChanged = font_OnListButtonChanged
	hooksecurefunc(dropdown.valueText, "SetText", font_SetText)
	dropdown.__SetValue = dropdown.SetValue
	dropdown.SetValue = font_SetValue
end

--------------------------------------------------------------------------------

local function PlayButton_OnClick(self)
	PlaySoundFile(self.sound, "Master")
end

local function CreatePlayButton(parent)
	local play = CreateFrame("Button", nil, parent)
	play:SetSize(16, 16)
	play:SetScript("OnClick", PlayButton_OnClick)

	local bg = play:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Common\\VoiceChat-Speaker")
	bg:SetAllPoints(true)
	play.bg = bg

	local hl = play:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture("Interface\\Common\\VoiceChat-On")
	hl:SetAllPoints(true)
	play.highlight = hl

	parent.playButton = play
	return play
end

local function sound_OnListButtonChanged(dropdown, button, value, selected)
	if not button.playButton then
		local play = CreatePlayButton(button)
		play:SetPoint("RIGHT", button, -2, 0)
	end
	button.playButton.sound = SharedMedia:Fetch("sound", value)
end

local function sound_SetText(valueText, text)
	valueText:GetParent().playButton.sound = SharedMedia:Fetch("sound", text)
end

mediaTypes["sound"] = function(dropdown)
	local play = CreatePlayButton(dropdown)
	play:SetPoint("LEFT", dropdown.bgLeft, 26, 1)
	dropdown.valueText:SetPoint("LEFT", play, "RIGHT", 1, 0)
	hooksecurefunc(dropdown.valueText, "SetText", sound_SetText)

	dropdown.button:SetPoint("TOPLEFT", dropdown.bgLeft, 36, -18) -- origx 16 + playwidth 16 + 4

	dropdown.OnListButtonChanged = sound_OnListButtonChanged
end

--------------------------------------------------------------------------------

local function statusbar_SetValueText(valueText, text)
	local dropdown = valueText:GetParent()
	local file = SharedMedia:Fetch("statusbar", text)
	dropdown.valueBG:SetTexture(file)
end

local function statusbar_GetButtonBackground(button)
	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", -3, 0)
	bg:SetPoint("BOTTOMRIGHT", 3, 0)
	bg:SetVertexColor(0.5, 0.5, 0.5)
	button.bg = bg
	return bg
end

local function statusbar_SetButtonBackgroundTextures(list)
	if not list.buttons then
		-- list.scrollFrame was provided, get list
		list = list:GetParent()
	end

	local numButtons = 0
	local buttons = list.buttons
	for i = 1, #buttons do
		local button = buttons[i]
		if i > 1 then
			button:SetPoint("TOPLEFT", buttons[i - 1], "BOTTOMLEFT", 0, -1)
		end
		if button.value and button:IsShown() then
			local bg = button.bg or statusbar_GetButtonBackground(button)
			bg:SetTexture(SharedMedia:Fetch("statusbar", button.value))
			local file, size = button.label:GetFont()
			button.label:SetFont(file, size, "OUTLINE")
			numButtons = numButtons + 1
		end
	end
	list:SetHeight(list:GetHeight() + (numButtons * 1))
end

local function statusbar_ButtonClick(button)
	local dropdown = button:GetParent()
	button:__OnClick() -- show
	dropdown.list:Hide() -- hide
	dropdown.list:HookScript("OnShow", statusbar_SetButtonBackgroundTextures)
	dropdown.list.scrollFrame:HookScript("OnVerticalScroll", statusbar_SetButtonBackgroundTextures)
	button:__OnClick() -- show again
	button:SetScript("OnClick", button.__OnClick) -- unhook
	button.__OnClick = nil -- cleanup
end

mediaTypes["statusbar"] = function(dropdown)
	local valueBG = dropdown:CreateTexture(nil, "OVERLAY")
	valueBG:SetPoint("LEFT", dropdown.valueText, -2, 1)
	valueBG:SetPoint("RIGHT", dropdown.valueText, 5, 1)
	valueBG:SetHeight(15)
	valueBG:SetVertexColor(0.35, 0.35, 0.35)
	dropdown.valueBG = valueBG

	hooksecurefunc(dropdown.valueText, "SetText", statusbar_SetValueText)

	dropdown.button.__OnClick = dropdown.button:GetScript("OnClick")
	dropdown.button:SetScript("OnClick", statusbar_ButtonClick)
end

--------------------------------------------------------------------------------

function lib:New(parent, label, tooltip, mediaType)
	local list = SharedMedia:List(mediaType)
	local dropdown = Dropdown:New(parent, label, tooltip, list)
	mediaTypes[mediaType](dropdown)
	return dropdown
end

function lib.CreateMediaDropdown(...) return lib:New(...) end