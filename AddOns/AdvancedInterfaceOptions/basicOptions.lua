local addonName, addon = ...
local E = addon:Eve()
local _G = _G
local _SetCVar = SetCVar -- Keep a local copy of SetCVar so we don't call the hooked version
local SetCVar = function(...) -- Suppress errors trying to set read-only cvars
	-- Not ideal, but the api doesn't give us this information
	local status, err = pcall(function(...) return _SetCVar(...) end, ...)
	return status
end

local function IsClassic()
    return WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
end

local function IsBCC()
  return WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
end

local function IsRetail()
  return WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
end

local function BlizzardOptionsPanel_UpdateCombatText()
	-- Hack to call CombatText_UpdateDisplayedMessages which only exists if the Blizzard_CombatText AddOn is loaded
	if CombatText_UpdateDisplayedMessages then
		CombatText_UpdateDisplayedMessages()
	end
end

AdvancedInterfaceOptionsSaved = {}
local DBVersion = 3

local CVarBlacklist = {
	-- Lowercase list of cvars to never record the value for, even if the user manually sets them
	['playintromovie'] = true,
}

-- Saved settings
local DefaultSettings = {
	AccountVars = {}, -- account-wide cvars to be re-applied on login, [cvar] = value
	CharVars = {}, -- (todo) character-specific cvar settings? [charName-realm] = { [cvar] = value }
	EnforceSettings = false, -- true to load cvars from our saved variables every time we log in
	-- this will override anything that sets a cvar outside of this addon
	CustomVars = {}, -- custom options for missing/removed cvars
	ModifiedCVars = {}, -- [cvar:lower()] = 'last addon to modify it'
	DBVersion = DBVersion, -- Database version for wiping out incompatible data
}

local AlwaysCharacterSpecificCVars = {
	-- list of cvars that should never be account-wide
	-- [cvar] = true
	-- stopAutoAttackOnTargetChange
}

local AddonLoaded, VariablesLoaded = false, false
function E:VARIABLES_LOADED()
	VariablesLoaded = true
	if AddonLoaded then
		self:ADDON_LOADED(addonName)
	end
end

local statusTextOptions
function E:ADDON_LOADED(addon_name)
	if addon_name == addonName then
		E:UnregisterEvent('ADDON_LOADED')
		AddonLoaded = true
		if VariablesLoaded then
			E('Init')
		end
	end
end

local function MergeTable(a, b) -- Non-destructively merges table b into table a
	for k,v in pairs(b) do
		if a[k] == nil or type(a[k]) ~= type(b[k]) then
			a[k] = v
			-- print('replacing key', k, v)
		elseif type(v) == 'table' then
			a[k] = MergeTable(a[k], b[k])
		end
	end
	return a
end

function E:Init() -- Runs after our saved variables are loaded and cvars have been loaded
	if AdvancedInterfaceOptionsSaved.DBVersion ~= DBVersion then
		-- Wipe out previous settings if database versions don't match
		AdvancedInterfaceOptionsSaved['DBVersion'] = DBVersion
		AdvancedInterfaceOptionsSaved['AccountVars'] = {}
	end
	MergeTable(AdvancedInterfaceOptionsSaved, DefaultSettings) -- Repair database if keys are missing

	--[[
	for k, v in pairs(AdvancedInterfaceOptionsSaved.CustomVars) do
		if statusTextOptions[k] then
			statusTextOptions[k](v and "statusText")
		end
	end
	--]]

	if AdvancedInterfaceOptionsSaved.EnforceSettings then
		if not AdvancedInterfaceOptionsSaved.AccountVars then
			AdvancedInterfaceOptionsSaved['AccountVars'] = {}
		end
		for cvar, value in pairs(AdvancedInterfaceOptionsSaved.AccountVars) do
			if addon.hiddenOptions[cvar] and addon:CVarExists(cvar) and not CVarBlacklist[cvar:lower()] then -- confirm we still use this cvar
				if GetCVar(cvar) ~= value then
					if not InCombatLockdown() or not addon.combatProtected[cvar] then
						SetCVar(cvar, value)
						-- print('Loading cvar', cvar, value)
					end
				end
			else -- remove if cvar is no longer supported
				AdvancedInterfaceOptionsSaved.AccountVars[cvar] = nil
			end
		end
	end
end

function addon:RecordCVar(cvar, value) -- Save cvar to DB for loading later
	if not AlwaysCharacterSpecificCVars[cvar] then
		-- We either need to normalize all cvars being entered into this table or verify that
		-- the case matches the case in our database or we risk duplicating entries.
		-- eg. MouseSpeed = 1, and mouseSpeed = 2 could exist in the table simultaneously,
		-- which would lead to an indeterminate value being loaded on startup
		local found = rawget(addon.hiddenOptions, cvar)
		if not found then
			local mk = cvar:lower()
			for k,v in pairs(addon.hiddenOptions) do
				if k:lower() == mk then
					cvar = k
					found = true
					break
				end
			end
		end
		if found and not CVarBlacklist[cvar:lower()] then -- only record cvars that exist in our database
			-- If we don't save the value if it's set to the default, and something else changes it from the default, we won't know to set it back
			--if GetCVar(cvar) == GetCVarDefault(cvar) then -- don't bother recording if default value
			--	AdvancedInterfaceOptionsSaved.AccountVars[cvar] = nil
			--else
				AdvancedInterfaceOptionsSaved.AccountVars[cvar] = GetCVar(cvar) -- not necessarily the same as "value"
			--end
		end
	end
end

function addon:DontRecordCVar(cvar, value) -- Wipe out saved variable if another addon modifies it
	if not AlwaysCharacterSpecificCVars[cvar] then
		local found = rawget(addon.hiddenOptions, cvar)
		if not found then
			local mk = cvar:lower()
			for k,v in pairs(addon.hiddenOptions) do
				if k:lower() == mk then
					cvar = k
					found = true
					break
				end
			end
		end
		if found then
			AdvancedInterfaceOptionsSaved.AccountVars[cvar] = nil
		end
	end
end

function addon:SetCVar(cvar, value, ...) -- save our cvar to the db
	if not InCombatLockdown() then
		SetCVar(cvar, value, ...)
		addon:RecordCVar(cvar, value)
		-- Clear entry from ModifiedCVars if we're modifying it directly
		-- Enforced settings don't use this function, so shouldn't wipe them out
		if AdvancedInterfaceOptionsSaved.ModifiedCVars[cvar:lower()] then
			AdvancedInterfaceOptionsSaved.ModifiedCVars[cvar:lower()] = nil
		end
	else
		--print("Can't modify interface options in combat")
	end
end

local AIO = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
AIO:Hide()
AIO:SetAllPoints()
local addonNameLoc = "進階介面選項"
AIO.name = addonNameLoc

-- Register all of our widgets here so we can iterate over them
-- luacheck: ignore
local Widgets = {} -- [frame] = cvar


-------------
-- Checkbox widget
-------------
local function checkboxGetCVar(self) return GetCVarBool(self.cvar) end
local function checkboxSetChecked(self) self:SetChecked(self:GetValue()) end
local function checkboxSetCVar(self, checked) addon:SetCVar(self.cvar, checked) end
local function checkboxOnClick(self)
	local checked = self:GetChecked()
    PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	self:SetValue(checked)
end

local function checkboxDisable(self)
	self.label:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
end

local function checkboxEnable(self)
	self.label:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
end

local function newCheckbox(parent, cvar, getValue, setValue, label, description)
	local cvarTable = addon.hiddenOptions[cvar]
	if cvarTable then
		label = cvarTable['prettyName'] or cvar
		description = _G[cvarTable['description']] or cvarTable['description'] or '沒有說明'
	else
		label = label or '[PH] Label'
		description = description or '[PH] Description'
	end
	local check = CreateFrame("CheckButton", "AIOCheck" .. label, parent, "InterfaceOptionsCheckButtonTemplate")

	check.cvar = cvar
	check.GetValue = getValue or checkboxGetCVar
	check.SetValue = setValue or checkboxSetCVar
	check:SetScript('OnShow', checkboxSetChecked)
	check:SetScript("OnClick", checkboxOnClick)
	check.label = _G[check:GetName() .. "Text"]
	check.label:SetText(label)
	check.tooltipText = label
	check.tooltipRequirement = description

	check:HookScript('OnDisable', checkboxDisable)
	check:HookScript('OnEnable', checkboxEnable)

	Widgets[check] = cvar
	return check
end

-----------
-- Slider widget
-----------
local function sliderGetCVar(self) return GetCVar(self.cvar) end
local function sliderRefresh(self) self:SetValue(self:GetCVarValue()) end
local function sliderSetCVar(self, value, userInput)
	if userInput then -- only record value if user manually changed it
		addon:SetCVar(self.cvar, value)
	end
end

local function sliderDisable(self)
	self.text:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	self.minText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	self.maxText:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	self.valueBox:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	self.valueBox:SetEnabled(false)
end

local function sliderEnable(self)
	self.text:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	self.minText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	self.maxText:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	self.valueBox:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	self.valueBox:SetEnabled(true)
end

local function newSlider(parent, cvar, minRange, maxRange, stepSize, getValue, setValue)
	local cvarTable = addon.hiddenOptions[cvar] or {}
	local label = cvarTable['prettyName'] or cvar
	local description = cvarTable['description'] or ''

	local _, defaultValue = GetCVarInfo(cvar)
	description = description .. '\n\n預設值: ' .. (defaultValue or '')
	local slider = CreateFrame('Slider', 'AIOSlider' .. cvar, parent, 'OptionsSliderTemplate')

	slider.cvar = cvar
	slider.GetCVarValue = getValue or sliderGetCVar
	slider.SetCVarValue = setValue or sliderSetCVar
	slider:SetScript('OnShow', sliderRefresh)
	stepSize = stepSize or 1
	slider:SetValueStep(stepSize)
	slider:SetObeyStepOnDrag(true)

	slider:SetMinMaxValues(minRange, maxRange)
	slider.minText = _G[slider:GetName() .. 'Low']
	slider.maxText = _G[slider:GetName() .. 'High']
	slider.text = _G[slider:GetName() .. 'Text']
	slider.minText:SetText(minRange)
	slider.maxText:SetText(maxRange)
	slider.text:SetText(label)

	local valueBox = CreateFrame('editbox', nil, slider, BackdropTemplateMixin and "BackdropTemplate")
	valueBox:SetPoint('TOP', slider, 'BOTTOM', 0, 0)
	valueBox:SetSize(60, 14)
	valueBox:SetFontObject(GameFontHighlightSmall)
	valueBox:SetAutoFocus(false)
	valueBox:SetJustifyH('CENTER')
	valueBox:SetScript('OnEscapePressed', function(self)
		-- ignore input, reset value to current cvar
		local current, default = GetCVarInfo(slider.cvar)
		self:SetText(current or default)
		self:ClearFocus()
	end)
	valueBox:SetScript('OnEnterPressed', function(self)
		local current, default = GetCVarInfo(slider.cvar)
		local value = tonumber(self:GetText()) or current or default
		local factor = 1 / stepSize
		value = floor(value * factor + 0.5) / factor
		value = max(minRange, min(maxRange, value))
		slider:SetValue(value, true)
		self:SetText(value)
		self:ClearFocus()
	end)
	slider:HookScript('OnValueChanged', function(self, value)
		local factor = 1 / stepSize
		value = floor(value * factor + 0.5) / factor
		valueBox:SetText(value)
	end)
	valueBox:SetScript('OnChar', function(self) -- filter input to decimal values
		self:SetText(self:GetText():gsub('[^%.0-9]+', ''):gsub('(%..*)%.', '%1'))
	end)
	valueBox:SetMaxLetters(5)

	valueBox:SetBackdrop({
		bgFile = 'Interface/ChatFrame/ChatFrameBackground',
		edgeFile = 'Interface/ChatFrame/ChatFrameBackground',
		tile = true, edgeSize = 1, tileSize = 5,
	})
	valueBox:SetBackdropColor(0, 0, 0, 0.5)
	valueBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)

	slider.valueBox = valueBox

	slider:HookScript('OnValueChanged', slider.SetCVarValue)

	slider:HookScript('OnDisable', sliderDisable)
	slider:HookScript('OnEnable', sliderEnable)

	slider.tooltipText = label
	slider.tooltipRequirement = description

	Widgets[slider] = cvar
	return slider
end

-------------
-- Custom vars
-------------

local function getCustomVar(self)
	return AdvancedInterfaceOptionsSaved.CustomVars[self.cvar]
end

local function setCustomVar(self, value)
	AdvancedInterfaceOptionsSaved.CustomVars[self.cvar] = value
end

-----------
-- Main options
-----------
local title = AIO:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(AIO.name)

local subText = AIO:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
subText:SetMaxLines(3)
subText:SetNonSpaceWrap(true)
subText:SetJustifyV('TOP')
subText:SetJustifyH('LEFT')
subText:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
subText:SetPoint('RIGHT', -32, 0)
subText:SetText('這些選項可以調整軍臨天下改版後被移除的各種遊戲設定。')

local playerTitles = newCheckbox(AIO, 'UnitNamePlayerPVPTitle')
local playerGuilds = newCheckbox(AIO, 'UnitNamePlayerGuild')
local playerGuildTitles = newCheckbox(AIO, 'UnitNameGuildTitle')
local fadeMap = not IsClassic() and newCheckbox(AIO, 'mapFade')
local secureToggle = newCheckbox(AIO, 'secureAbilityToggle')
local luaErrors = newCheckbox(AIO, 'scriptErrors')
local targetDebuffFilter = newCheckbox(AIO, 'noBuffDebuffFilterOnTarget')
local enableWoWMouse = newCheckbox(AIO, 'enableWoWMouse')

local questSortingLabel = AIO:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
questSortingLabel:SetPoint('TOPLEFT', enableWoWMouse, 'BOTTOMLEFT', 0, -10)
questSortingLabel:SetText('任務排序方式:')

local questSortingDropdown = CreateFrame("Frame", "AIOQuestSorting", AIO, "UIDropDownMenuTemplate")
questSortingDropdown:SetPoint("TOPLEFT", questSortingLabel, "BOTTOMLEFT", -16, -10)
questSortingDropdown.initialize = function(dropdown)
	local sortMode = { "top", "proximity" }
	local sortModeLoc = { "上方", "距離最近" }
	for i, mode in next, sortMode do
		local info = UIDropDownMenu_CreateInfo()
		info.text = sortModeLoc[i]
		info.value = sortMode[i]
		info.func = function(self)
			addon:SetCVar("trackQuestSorting", self.value)
			UIDropDownMenu_SetSelectedValue(dropdown, self.value)
		end
		UIDropDownMenu_AddButton(info)
	end
	UIDropDownMenu_SetSelectedValue(dropdown, (GetCVarInfo("trackQuestSorting")))
end
questSortingDropdown:HookScript("OnShow", questSortingDropdown.initialize)
questSortingDropdown:HookScript("OnEnter", function(self)
	if not self.isDisabled then
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
		GameTooltip:SetText(_G["OPTION_TOOLTIP_TRACK_QUEST_"..strupper(self.selectedValue)], nil, nil, nil, nil, true)
	end
end)
questSortingDropdown:HookScript("OnLeave", GameTooltip_Hide)
Widgets[ questSortingDropdown ] = 'trackQuestSorting'
--[[ 9.0 已不支援動感鏡頭模式
local actionCamModeLabel = AIO:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
actionCamModeLabel:SetPoint('TOPLEFT', questSortingDropdown, 'BOTTOMLEFT', 16, 0)
actionCamModeLabel:SetText('動感鏡頭模式:')

local actionCamModeDropdown = CreateFrame("Frame", "AIOActionCamMode", AIO, "UIDropDownMenuTemplate")
actionCamModeDropdown:SetPoint("TOPLEFT", actionCamModeLabel, "BOTTOMLEFT", -16, -10)
actionCamModeDropdown.initialize = function(dropdown)
	local sortMode = { "basic", "full", "off", "default" }
	local sortModeLoc = { "基本", "完整", "關閉", "預設" }
	for i, mode in next, sortMode do
		local info = UIDropDownMenu_CreateInfo()
		info.text = sortModeLoc[i]
		info.value = sortMode[i]
		info.func = function(self)
			ConsoleExec("actioncam "..self.value)
			UIDropDownMenu_SetSelectedValue(dropdown, self.value)
		end
		UIDropDownMenu_AddButton(info)
	end
	UIDropDownMenu_SetSelectedValue(dropdown, "off") -- TODO: This is wrong, obviously
end
actionCamModeDropdown:HookScript("OnShow", actionCamModeDropdown.initialize)
--]]
local function cameraFactor_SetValue(self, value, userInput)
	if userInput then
		addon:SetCVar(self.cvar, value)
		if not IsRetail() then
			setCustomVar(InterfaceOptionsCameraPanelMaxDistanceSlider, value)
		end
	end
end

local cameraFactor = newSlider(AIO, 'cameraDistanceMaxZoomFactor', 1, not IsRetail() and 3.4 or 2.6, 0.1, nil, cameraFactor_SetValue)
cameraFactor:SetPoint('TOPLEFT', questSortingDropdown, 'BOTTOMLEFT', 20, -20)

if not IsRetail() then
	-- blizzard options overwrites this cvar at start and is capped to 2.0
	hooksecurefunc("BlizzardOptionsPanel_SetupControl", function(control)
		if control == InterfaceOptionsCameraPanelMaxDistanceSlider then
			SetCVar("cameraDistanceMaxZoomFactor", getCustomVar(control))
			control:SetMinMaxValues(1, 3.4)
			local text = control.Text
			text:SetText(text:GetText().." |cffffffff(15-50)|r")
		end
	end)

	-- also update from the blizzard slider otherwise it can lead to confusing behavior where it gets overwritten
	InterfaceOptionsCameraPanelMaxDistanceSlider:HookScript("OnValueChanged", function(self, value, userInput)
		if userInput then
			setCustomVar(InterfaceOptionsCameraPanelMaxDistanceSlider, value)
		end
	end)
end
playerTitles:SetPoint("TOPLEFT", subText, "BOTTOMLEFT", 0, -8)
playerGuilds:SetPoint("TOPLEFT", playerTitles, "BOTTOMLEFT", 0, -4)
playerGuildTitles:SetPoint("TOPLEFT", playerGuilds, "BOTTOMLEFT", 0, -4)
if not IsClassic() then
	fadeMap:SetPoint("TOPLEFT", playerGuildTitles, "BOTTOMLEFT", 0, -4)
end
secureToggle:SetPoint("TOPLEFT", IsClassic() and playerGuildTitles or fadeMap, "BOTTOMLEFT", 0, -4)
luaErrors:SetPoint("TOPLEFT", secureToggle, "BOTTOMLEFT", 0, -4)
targetDebuffFilter:SetPoint("TOPLEFT", luaErrors, "BOTTOMLEFT", 0, -4)

-- Insert functions exist as globals in Classic, and under C_Container on Retail 10.0.2
local GetInsertItemsLeftToRight = GetInsertItemsLeftToRight or C_Container and C_Container.GetInsertItemsLeftToRight
local SetInsertItemsLeftToRight = SetInsertItemsLeftToRight or C_Container and C_Container.SetInsertItemsLeftToRight

-- Sorting functions do not exist in Classic, exist as globals up to 10.0.2, and are under C_Container in 10.0.2
local GetSortBagsRightToLeft = GetSortBagsRightToLeft or C_Container and C_Container.GetSortBagsRightToLeft
local SetSortBagsRightToLeft = SetSortBagsRightToLeft or C_Container and C_Container.SetSortBagsRightToLeft

local reverseCleanupBags = GetSortBagsRightToLeft and SetSortBagsRightToLeft and newCheckbox(AIO, 'reverseCleanupBags',
	function(self)
		return GetSortBagsRightToLeft()
	end,
	function(self, checked)
		SetSortBagsRightToLeft(checked)
	end
)

local lootLeftmostBag = GetInsertItemsLeftToRight and SetInsertItemsLeftToRight and newCheckbox(AIO, 'lootLeftmostBag',
	function(self)
		return GetInsertItemsLeftToRight()
	end,
	function(self, checked)
		SetInsertItemsLeftToRight(checked)
	end
)

if reverseCleanupBags and lootLeftmostBag then
    reverseCleanupBags:SetPoint("TOPLEFT", targetDebuffFilter, "BOTTOMLEFT", 0, -4)
    lootLeftmostBag:SetPoint("TOPLEFT", reverseCleanupBags, "BOTTOMLEFT", 0, -4)
    enableWoWMouse:SetPoint("TOPLEFT", lootLeftmostBag, "BOTTOMLEFT", 0, -4)
elseif lootLeftmostBag then
    lootLeftmostBag:SetPoint("TOPLEFT", targetDebuffFilter, "BOTTOMLEFT", 0, -4)
    enableWoWMouse:SetPoint("TOPLEFT", lootLeftmostBag, "BOTTOMLEFT", 0, -4)
else
    enableWoWMouse:SetPoint("TOPLEFT", targetDebuffFilter, "BOTTOMLEFT", 0, -4)
end

-- Checkbox to enforce all settings through reloads
local enforceBox = newCheckbox(AIO, nil,
	function(self) -- getter
		 return not not AdvancedInterfaceOptionsSaved.EnforceSettings
	end,
	function(self, checked) -- setter
		AdvancedInterfaceOptionsSaved.EnforceSettings = checked
		--[[
		if checked then
			AdvancedInterfaceOptionsSaved.AccountVars = {}
			--for widget, cvar in pairs(Widgets) do
			for cvar in pairs(addon.hiddenOptions) do
				local current, default = GetCVarInfo(cvar)
				if not AlwaysCharacterSpecificCVars[cvar] and current ~= default then
					AdvancedInterfaceOptionsSaved.AccountVars[cvar] = current
					-- print('Saving', cvar, 'as', current)
				end
			end
		end
		--]]
	end,
	'啟動時強制套用設定',
	"登入遊戲或切換角色時重新套用所有設定。\n\n若每次登入時設定沒有被儲存，請勾選此項。")
enforceBox:SetPoint("LEFT", title, "RIGHT", 5, 0)

-- Button to reset all of our settings back to their defaults
StaticPopupDialogs['AIO_RESET_EVERYTHING'] = {
	text = '請輸入 "IRREVERSIBLE" 來將所有 CVars 遊戲參數重置成預設設定',
	button1 = '確認',
	button2 = '取消',
	hasEditBox = true,
	OnShow = function(self)
		self.button1:SetEnabled(false)
	end,
	EditBoxOnTextChanged = function(self, data)
		self:GetParent().button1:SetEnabled(self:GetText():lower() == 'irreversible')
	end,
	OnAccept = function()
		for _, info in ipairs(addon:GetCVars()) do
			local cvar = info.command
			local current, default = GetCVarInfo(cvar)
			if current ~= default then
				print(format('|cffaaaaff%s|r 的值從 |cffffaaaa%s|r 變成 |cffaaffaa%s|r', tostring(cvar), tostring(current), tostring(default)))
				addon:SetCVar(cvar, default)
			end
		end
		wipe(AdvancedInterfaceOptionsSaved.CustomVars)
		AIO:Hide()
		AIO:Show()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
	showAlert = true,
}

local resetButton = CreateFrame('button', nil, AIO, 'UIPanelButtonTemplate')
resetButton:SetSize(120, 22)
resetButton:SetText("載入預設值")
resetButton:SetPoint('BOTTOMRIGHT', -10, 10)
resetButton:SetScript('OnClick', function(self)
	StaticPopup_Show('AIO_RESET_EVERYTHING')
end)

-- Backup Settings
local function BackupSettings()
	--[[
		FIXME: We probably don't actually want to back up every CVar
		Some CVars use bitfields to track progress that the player likely isn't expecting to be undone by a restore
		We may need to manually create a list of CVars to ignore, I don't know if there's a way to automate this
	--]]
	local cvarBackup = {}
	local settingCount = 0
	for _, info in ipairs(addon:GetCVars()) do
		-- Only record CVars that don't match their default value
		-- NOTE: Defaults can potentially change, should we store every cvar?
		local currentValue, defaultValue = GetCVarInfo(info.command)
		if currentValue ~= defaultValue then
			-- Normalize casing to simplify lookups
			local cvar = info.command:lower()
			cvarBackup[cvar] = currentValue
			settingCount = settingCount + 1
		end
	end

	-- TODO: Support multiple backups (save & restore named cvar profiles)
	if not AdvancedInterfaceOptionsSaved.Backups then
		AdvancedInterfaceOptionsSaved.Backups = {}
	end
	AdvancedInterfaceOptionsSaved.Backups[1] = {
		timestamp = GetServerTime(),
		cvars = cvarBackup,
	}

	print(format("進階介面選項: 已備份 %d 個自訂的 CVar 遊戲參數設定!", settingCount))
end

StaticPopupDialogs["AIO_BACKUP_SETTINGS"] = {
	text = "是否要儲存目前的 CVar 遊戲參數設定，以便日後能夠還原設定?",
	button1 = "備份設定",
	button2 = "取消",
	OnAccept = BackupSettings,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local backupButton = CreateFrame("button", nil, AIO, "UIPanelButtonTemplate")
backupButton:SetSize(120, 22)
backupButton:SetText("備份設定")
backupButton:SetPoint("BOTTOMLEFT", resetButton, "TOPLEFT", 0, 50)
backupButton:SetScript("OnClick", function(self)
	StaticPopup_Show("AIO_BACKUP_SETTINGS")
end)

-- Restore Settings
local function RestoreSettings()
	local backup = AdvancedInterfaceOptionsSaved.Backups and AdvancedInterfaceOptionsSaved.Backups[1]
	if backup then
		for _, info in ipairs(addon:GetCVars()) do
			local cvar = info.command
			local backupValue = backup.cvars[cvar:lower()] -- Always lowercase cvar names
			local currentValue, defaultValue = GetCVarInfo(cvar)
			if backupValue then
				-- Restore value from backup
				if currentValue ~= backupValue then
					print(format('|cffaaaaff%s|r 的值從 |cffffaaaa%s|r 變成 |cffaaffaa%s|r', cvar, tostring(currentValue), tostring(backupValue)))
					addon:SetCVar(cvar, backupValue)
				end
			else
				-- CHECKME: If CVar isn't in backup and isn't set to default value, should we reset to default or ignore it?
				if currentValue ~= defaultValue then
					print(format('|cffaaaaff%s|r 的值從 |cffffaaaa%s|r 變成 |cffaaffaa%s|r', cvar, tostring(currentValue), tostring(defaultValue)))
					addon:SetCVar(cvar, defaultValue)
				end
			end
		end
	end
end

StaticPopupDialogs["AIO_RESTORE_SETTINGS"] = {
	text = "是否要從備份還原 CVar 遊戲參數設定?\n注意: 此動作無法復原!",
	button1 = "還原設定",
	button2 = "取消",
	OnAccept = RestoreSettings,
	OnShow = function(self)
		-- Disable accept button if we don't have any backups
		self.button1:SetEnabled(AdvancedInterfaceOptionsSaved.Backups and AdvancedInterfaceOptionsSaved.Backups[1])
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
	showAlert = true,
}

local restoreButton = CreateFrame("button", nil, AIO, "UIPanelButtonTemplate")
restoreButton:SetSize(120, 22)
restoreButton:SetText("還原設定")
restoreButton:SetPoint("TOPLEFT", backupButton, "BOTTOMLEFT", 0, -2)
restoreButton:SetScript("OnClick", function(self)
	StaticPopup_Show("AIO_RESTORE_SETTINGS")
end)


-- Chat section
local AIO_Chat = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
AIO_Chat:Hide()
AIO_Chat:SetAllPoints()
AIO_Chat.name = "聊天"
AIO_Chat.parent = addonNameLoc

local Title_Chat = AIO_Chat:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
Title_Chat:SetJustifyV('TOP')
Title_Chat:SetJustifyH('LEFT')
Title_Chat:SetPoint('TOPLEFT', 16, -16)
Title_Chat:SetText(AIO_Chat.name)

local SubText_Chat = AIO_Chat:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
SubText_Chat:SetMaxLines(3)
SubText_Chat:SetNonSpaceWrap(true)
SubText_Chat:SetJustifyV('TOP')
SubText_Chat:SetJustifyH('LEFT')
SubText_Chat:SetPoint('TOPLEFT', Title_Chat, 'BOTTOMLEFT', 0, -8)
SubText_Chat:SetPoint('RIGHT', -32, 0)
SubText_Chat:SetText('這些選項可以調整不在預設介面中的聊天設定。')

local chatMouseScroll = newCheckbox(AIO_Chat, 'chatMouseScroll')
local chatDelay = newCheckbox(AIO_Chat, 'removeChatDelay')
chatDelay:SetPoint('TOPLEFT', SubText_Chat, 'BOTTOMLEFT', 0, -8)
chatMouseScroll:SetPoint('TOPLEFT', chatDelay, 'BOTTOMLEFT', 0, -4)

if IsClassic() then
    local classColors = newCheckbox(AIO_Chat, 'chatClassColorOverride')
    classColors:SetPoint('TOPLEFT', chatMouseScroll, 'BOTTOMLEFT', 0, -4)
end

-- Floating Combat Text section
local AIO_FCT = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
AIO_FCT:Hide()
AIO_FCT:SetAllPoints()
AIO_FCT.name = FLOATING_COMBATTEXT_LABEL
AIO_FCT.parent = addonNameLoc

local Title_FCT = AIO_FCT:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
Title_FCT:SetJustifyV('TOP')
Title_FCT:SetJustifyH('LEFT')
Title_FCT:SetPoint('TOPLEFT', 16, -16)
Title_FCT:SetText(AIO_FCT.name)

local SubText_FCT = AIO_FCT:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
SubText_FCT:SetMaxLines(3)
SubText_FCT:SetNonSpaceWrap(true)
SubText_FCT:SetJustifyV('TOP')
SubText_FCT:SetJustifyH('LEFT')
SubText_FCT:SetPoint('TOPLEFT', Title_FCT, 'BOTTOMLEFT', 0, -8)
SubText_FCT:SetPoint('RIGHT', -32, 0)
SubText_FCT:SetText(COMBATTEXT_SUBTEXT)

local fctfloatmodeDropdown = CreateFrame("Frame", "AIOfctFloatMode", AIO_FCT, "UIDropDownMenuTemplate")
fctfloatmodeDropdown.initialize = function(dropdown)
	local floatMode = { COMBAT_TEXT_SCROLL_UP, COMBAT_TEXT_SCROLL_DOWN, COMBAT_TEXT_SCROLL_ARC }
	for i, mode in next, floatMode do
		local info = UIDropDownMenu_CreateInfo()
		info.text = floatMode[i]
		info.value = tostring(i)
		info.func = function(self)
			addon:SetCVar("floatingCombatTextFloatMode", self.value)
			UIDropDownMenu_SetSelectedValue(dropdown, self.value)
			COMBAT_TEXT_FLOAT_MODE = self.value
			BlizzardOptionsPanel_UpdateCombatText()
		end
		UIDropDownMenu_AddButton(info)
	end
	UIDropDownMenu_SetSelectedValue(dropdown, GetCVar("floatingCombatTextFloatMode"))
end
fctfloatmodeDropdown:HookScript("OnShow", fctfloatmodeDropdown.initialize)
fctfloatmodeDropdown:HookScript("OnEnter", function(self)
	if not self.isDisabled then
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
		GameTooltip:SetText(OPTION_TOOLTIP_COMBAT_TEXT_MODE, nil, nil, nil, nil, true)
	end
end)
fctfloatmodeDropdown:HookScript("OnLeave", GameTooltip_Hide)
Widgets[ fctfloatmodeDropdown ] = 'floatingCombatTextFloatMode'

-- UVARINFO was made local in patch 8.2.0
local uvars = {
	removeChatDelay = "REMOVE_CHAT_DELAY",
	lockActionBars = "LOCK_ACTIONBAR",
	buffDurations = "SHOW_BUFF_DURATIONS",
	alwaysShowActionBars = "ALWAYS_SHOW_MULTIBARS",
	showPartyPets = "SHOW_PARTY_PETS",
	showPartyBackground = "SHOW_PARTY_BACKGROUND",
	showTargetOfTarget = "SHOW_TARGET_OF_TARGET",
	autoQuestWatch = "AUTO_QUEST_WATCH",
	lootUnderMouse = "LOOT_UNDER_MOUSE",
	autoLootDefault = "AUTO_LOOT_DEFAULT",
	enableFloatingCombatText = "SHOW_COMBAT_TEXT",
	floatingCombatTextLowManaHealth = "COMBAT_TEXT_SHOW_LOW_HEALTH_MANA",
	floatingCombatTextAuras = "COMBAT_TEXT_SHOW_AURAS",
	floatingCombatTextAuraFade = "COMBAT_TEXT_SHOW_AURA_FADE",
	floatingCombatTextCombatState = "COMBAT_TEXT_SHOW_COMBAT_STATE",
	floatingCombatTextDodgeParryMiss = "COMBAT_TEXT_SHOW_DODGE_PARRY_MISS",
	floatingCombatTextDamageReduction = "COMBAT_TEXT_SHOW_RESISTANCES",
	floatingCombatTextRepChanges = "COMBAT_TEXT_SHOW_REPUTATION",
	floatingCombatTextReactives = "COMBAT_TEXT_SHOW_REACTIVES",
	floatingCombatTextFriendlyHealers = "COMBAT_TEXT_SHOW_FRIENDLY_NAMES",
	floatingCombatTextComboPoints = "COMBAT_TEXT_SHOW_COMBO_POINTS",
	floatingCombatTextEnergyGains = "COMBAT_TEXT_SHOW_ENERGIZE",
	floatingCombatTextPeriodicEnergyGains = "COMBAT_TEXT_SHOW_PERIODIC_ENERGIZE",
	floatingCombatTextFloatMode = "COMBAT_TEXT_FLOAT_MODE",
	floatingCombatTextHonorGains = "COMBAT_TEXT_SHOW_HONOR_GAINED",
	showCastableBuffs = "SHOW_CASTABLE_BUFFS",
	showDispelDebuffs = "SHOW_DISPELLABLE_DEBUFFS",
	showArenaEnemyFrames = "SHOW_ARENA_ENEMY_FRAMES",
	showArenaEnemyCastbar = "SHOW_ARENA_ENEMY_CASTBAR",
	showArenaEnemyPets = "SHOW_ARENA_ENEMY_PETS",
}

local function FCT_SetValue(self, checked)
	addon:SetCVar(self.cvar, checked)
	_G[uvars[self.cvar]] = checked and "1" or "0"
	BlizzardOptionsPanel_UpdateCombatText()
end

local fctAbsorbTarget = newCheckbox(AIO_FCT, 'floatingCombatTextCombatHealingAbsorbTarget')
local fctDamage = newCheckbox(AIO_FCT, 'floatingCombatTextCombatDamage')
local fctDirectionalScale = newCheckbox(AIO_FCT, 'floatingCombatTextCombatDamageDirectionalScale')
local fctHealing = newCheckbox(AIO_FCT, 'floatingCombatTextCombatHealing')
local fctPeriodicSpells = newCheckbox(AIO_FCT, 'floatingCombatTextCombatLogPeriodicSpells')
local fctPetMeleeDamage = newCheckbox(AIO_FCT, 'floatingCombatTextPetMeleeDamage', nil, function(self, checked)
	checkboxSetCVar(self, checked)
	addon:SetCVar('floatingCombatTextPetSpellDamage', checked)
end)
local fctSpellMechanics = newCheckbox(AIO_FCT, 'floatingCombatTextSpellMechanics')
local fctSpellMechanicsOther = newCheckbox(AIO_FCT, 'floatingCombatTextSpellMechanicsOther')
local worldTextScale = newSlider(AIO_FCT, 'WorldTextScale', 0.5, 2.5, 0.1)

local enablefct = newCheckbox(AIO_FCT, 'enableFloatingCombatText', nil, FCT_SetValue)
local fctAbsorbSelf = newCheckbox(AIO_FCT, 'floatingCombatTextCombatHealingAbsorbSelf')
local fctAuras = newCheckbox(AIO_FCT, 'floatingCombatTextAuras', nil, FCT_SetValue)
local fctCombatState = newCheckbox(AIO_FCT, 'floatingCombatTextCombatState', nil, FCT_SetValue)
local fctComboPoints = newCheckbox(AIO_FCT, 'floatingCombatTextComboPoints', nil, FCT_SetValue)
local fctDamageReduction = newCheckbox(AIO_FCT, 'floatingCombatTextDamageReduction', nil, FCT_SetValue)
local fctDodgeParryMiss = newCheckbox(AIO_FCT, 'floatingCombatTextDodgeParryMiss', nil, FCT_SetValue)
local fctEnergyGains = newCheckbox(AIO_FCT, 'floatingCombatTextEnergyGains', nil, FCT_SetValue)
local fctFriendlyHealer = newCheckbox(AIO_FCT, 'floatingCombatTextFriendlyHealers', nil, FCT_SetValue)
local fctHonorGains = newCheckbox(AIO_FCT, 'floatingCombatTextHonorGains', nil, FCT_SetValue)
local fctLowHPMana = newCheckbox(AIO_FCT, 'floatingCombatTextLowManaHealth', nil, FCT_SetValue)
local fctPeriodicEnergyGains = newCheckbox(AIO_FCT, 'floatingCombatTextPeriodicEnergyGains', nil, FCT_SetValue)
local fctReactives = newCheckbox(AIO_FCT, 'floatingCombatTextReactives', nil, FCT_SetValue)
local fctRepChanges = newCheckbox(AIO_FCT, 'floatingCombatTextRepChanges', nil, FCT_SetValue)

local fctTargetLabel = AIO_FCT:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
fctTargetLabel:SetText(FLOATING_COMBAT_TARGET_LABEL)
fctTargetLabel:SetPoint('TOPLEFT', SubText_FCT, 'BOTTOMLEFT', 0, -25)

fctDamage:SetPoint("TOPLEFT", fctTargetLabel, "BOTTOMLEFT", 0, -6)
fctPeriodicSpells:SetPoint("TOPLEFT", fctDamage, "BOTTOMLEFT", 10, 0)
fctPetMeleeDamage:SetPoint("TOPLEFT", fctPeriodicSpells, "BOTTOMLEFT", 0, 0)
fctDirectionalScale:SetPoint("TOPLEFT", fctPetMeleeDamage, "BOTTOMLEFT", 0, 0)
fctHealing:SetPoint("TOPLEFT", fctDirectionalScale, "BOTTOMLEFT", -10, -6)
fctAbsorbTarget:SetPoint("TOPLEFT", fctHealing, "BOTTOMLEFT", 10, 0)

fctSpellMechanics:SetPoint("TOPLEFT", fctDamage, "TOPRIGHT", 260, 0)
fctSpellMechanicsOther:SetPoint("TOPLEFT", fctSpellMechanics, "BOTTOMLEFT", 10, -4)
worldTextScale:SetPoint("TOPLEFT", fctSpellMechanicsOther, "BOTTOMLEFT", -6, -40)

local fctSelfLabel = AIO_FCT:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
fctSelfLabel:SetText(FLOATING_COMBAT_SELF_LABEL)
fctSelfLabel:SetPoint('TOPLEFT', fctAbsorbTarget, 'BOTTOMLEFT', -10, -25)

enablefct:SetPoint("TOPLEFT", fctSelfLabel, "BOTTOMLEFT", 0, -4)
fctfloatmodeDropdown:SetPoint("TOPLEFT", enablefct, "BOTTOMLEFT", -4, 0)
fctDodgeParryMiss:SetPoint("TOPLEFT", enablefct, "BOTTOMLEFT", 10, -32)
fctDamageReduction:SetPoint("TOPLEFT", fctDodgeParryMiss, "BOTTOMLEFT", 0, -4)
fctRepChanges:SetPoint("TOPLEFT", fctDamageReduction, "BOTTOMLEFT", 0, -4)
fctReactives:SetPoint("TOPLEFT", fctRepChanges, "BOTTOMLEFT", 0, -4)
fctFriendlyHealer:SetPoint("TOPLEFT", fctReactives, "BOTTOMLEFT", 0, -4)
fctCombatState:SetPoint("TOPLEFT", fctFriendlyHealer, "BOTTOMLEFT", 0, -4)
fctAbsorbSelf:SetPoint("TOPLEFT", fctDodgeParryMiss, "TOPRIGHT", 260, 0)
fctLowHPMana:SetPoint("TOPLEFT", fctAbsorbSelf, "BOTTOMLEFT", 0, -4)
fctEnergyGains:SetPoint("TOPLEFT", fctLowHPMana, "BOTTOMLEFT", 0, -4)
fctPeriodicEnergyGains:SetPoint("TOPLEFT", fctEnergyGains, "BOTTOMLEFT", 0, -4)
fctHonorGains:SetPoint("TOPLEFT", fctPeriodicEnergyGains, "BOTTOMLEFT", 0, -4)
fctAuras:SetPoint("TOPLEFT", fctHonorGains, "BOTTOMLEFT", 0, -4)

-- Status Text section
local AIO_ST = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
AIO_ST:Hide()
AIO_ST:SetAllPoints()
AIO_ST.name = STATUSTEXT_LABEL
AIO_ST.parent = addonNameLoc

local Title_ST = AIO_ST:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
Title_ST:SetJustifyV('TOP')
Title_ST:SetJustifyH('LEFT')
Title_ST:SetPoint('TOPLEFT', 16, -16)
Title_ST:SetText(AIO_ST.name)

local SubText_ST = AIO_ST:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
SubText_ST:SetMaxLines(3)
SubText_ST:SetNonSpaceWrap(true)
SubText_ST:SetJustifyV('TOP')
SubText_ST:SetJustifyH('LEFT')
SubText_ST:SetPoint('TOPLEFT', Title_ST, 'BOTTOMLEFT', 0, -8)
SubText_ST:SetPoint('RIGHT', -32, 0)
SubText_ST:SetText(STATUSTEXT_SUBTEXT)

local function setStatusTextBars(frame, value)
	frame.healthbar.cvar = value
	frame.manabar.cvar = value
	TextStatusBar_UpdateTextString(frame.healthbar)
	TextStatusBar_UpdateTextString(frame.manabar)
end

statusTextOptions = {
	playerStatusText = function(value)
		setStatusTextBars(PlayerFrame, value)
	end,
	petStatusText = function(value)
		setStatusTextBars(PetFrame, value)
	end,
	partyStatusText = function(value)
		for i = 1, MAX_PARTY_MEMBERS do
			setStatusTextBars(_G["PartyMemberFrame"..i], value)
		end
	end,
	targetStatusText = function(value)
		setStatusTextBars(TargetFrame, value)
	end,
	alternateResourceText = function(value)
		PlayerFrameAlternateManaBar.cvar = value
		TextStatusBar_UpdateTextString(PlayerFrameAlternateManaBar)
	end,
}

local function setStatusText(self, value)
	setCustomVar(self, value)
	statusTextOptions[self.cvar](value and "statusText")
end

local stPlayer = newCheckbox(AIO_ST, 'playerStatusText', getCustomVar, setStatusText)
local stPet = newCheckbox(AIO_ST, 'petStatusText', getCustomVar, setStatusText)
local stParty = newCheckbox(AIO_ST, 'partyStatusText', getCustomVar, setStatusText)
local stTarget = newCheckbox(AIO_ST, 'targetStatusText', getCustomVar, setStatusText)
local stAltResource = newCheckbox(AIO_ST, 'alternateResourceText', getCustomVar, setStatusText)
local stXpBar = newCheckbox(AIO_ST, 'xpBarText', nil, function(self, checked)
	checkboxSetCVar(self, checked)
	TextStatusBar_UpdateTextString(MainMenuExpBar)
end)

local stToggleStatusText = newCheckbox(AIO_ST, 'statusText',
	function(self) -- getter
		local value = checkboxGetCVar(self)
		stPlayer:SetEnabled(value)
		stPet:SetEnabled(value)
		stParty:SetEnabled(value)
		stTarget:SetEnabled(value)
		stAltResource:SetEnabled(value)
		stXpBar:SetEnabled(value)
		return value
	end,
	function(self, value) -- setter
		addon:SetCVar('statusText', value, 'STATUS_TEXT_DISPLAY') -- forces text on status bars to update
		stPlayer:SetEnabled(value)
		stPet:SetEnabled(value)
		stParty:SetEnabled(value)
		stTarget:SetEnabled(value)
		stAltResource:SetEnabled(value)
		stXpBar:SetEnabled(value)
	end
)

stToggleStatusText:SetPoint("TOPLEFT", SubText_ST, "BOTTOMLEFT", 0, -8)
stPlayer:SetPoint("TOPLEFT", stToggleStatusText, "BOTTOMLEFT", 10, -4)
stPet:SetPoint("TOPLEFT", stPlayer, "BOTTOMLEFT", 0, -4)
stParty:SetPoint("TOPLEFT", stPet, "BOTTOMLEFT", 0, -4)
stTarget:SetPoint("TOPLEFT", stParty, "BOTTOMLEFT", 0, -4)
stAltResource:SetPoint("TOPLEFT", stTarget, "BOTTOMLEFT", 0, -4)
stXpBar:SetPoint("TOPLEFT", stAltResource, "BOTTOMLEFT", 0, -4)

local function stTextDisplaySetValue(self)
	addon:SetCVar('statusTextDisplay', self.value, 'STATUS_TEXT_DISPLAY')
end

-- TODO: figure out why the built-in tooltipTitle and tooltipText attributes don't work
local stTextDisplay = addon:CreateDropdown(AIO_ST, 130, {
	{text = STATUS_TEXT_VALUE, value = 'NUMERIC', func = stTextDisplaySetValue},
	{text = STATUS_TEXT_PERCENT, value = 'PERCENT', func = stTextDisplaySetValue},
	{text = STATUS_TEXT_BOTH, value = 'BOTH', func = stTextDisplaySetValue},
})
stTextDisplay:SetPoint('LEFT', stToggleStatusText, 'RIGHT', 100, -2)
stTextDisplay:HookScript('OnShow', function(self) self:SetValue(GetCVar('statusTextDisplay')) end)
stTextDisplay:HookScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
	GameTooltip:SetText(OPTION_TOOLTIP_STATUS_TEXT_DISPLAY, nil, nil, nil, nil, true)
end)
stTextDisplay:HookScript("OnLeave", GameTooltip_Hide)

-- Nameplate section
local AIO_NP = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
AIO_NP:Hide()
AIO_NP:SetAllPoints()
AIO_NP.name = "名條"
AIO_NP.parent = addonNameLoc

local Title_NP = AIO_NP:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
Title_NP:SetJustifyV('TOP')
Title_NP:SetJustifyH('LEFT')
Title_NP:SetPoint('TOPLEFT', 16, -16)
Title_NP:SetText(AIO_NP.name)

local SubText_NP = AIO_NP:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
SubText_NP:SetMaxLines(3)
SubText_NP:SetNonSpaceWrap(true)
SubText_NP:SetJustifyV('TOP')
SubText_NP:SetJustifyH('LEFT')
SubText_NP:SetPoint('TOPLEFT', Title_NP, 'BOTTOMLEFT', 0, -8)
SubText_NP:SetPoint('RIGHT', -32, 0)
SubText_NP:SetText('這些選項可以調整名條/血條設定。')

local nameplateAtBase = newCheckbox(AIO_NP, 'nameplateOtherAtBase')
nameplateAtBase:SetPoint("TOPLEFT", SubText_NP, "BOTTOMLEFT", 0, -20)
nameplateAtBase:SetScript('OnClick', function(self)
	local checked = self:GetChecked()
	PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	self:SetValue(checked and 2 or 0)
end)

local nameplateColorFriendly = newCheckbox(AIO_NP, 'ShowClassColorInFriendlyNameplate')
nameplateColorFriendly:SetPoint("TOPLEFT", nameplateAtBase, "BOTTOMLEFT", 0, -8)

-- Combat section
local AIO_C = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
AIO_C:Hide()
AIO_C:SetAllPoints()
AIO_C.name = "戰鬥"
AIO_C.parent = addonNameLoc

local Title_C = AIO_C:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
Title_C:SetJustifyV('TOP')
Title_C:SetJustifyH('LEFT')
Title_C:SetPoint('TOPLEFT', 16, -16)
Title_C:SetText(AIO_C.name)

local SubText_C = AIO_C:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
SubText_C:SetMaxLines(3)
SubText_C:SetNonSpaceWrap(true)
SubText_C:SetJustifyV('TOP')
SubText_C:SetJustifyH('LEFT')
SubText_C:SetPoint('TOPLEFT', Title_C, 'BOTTOMLEFT', 0, -8)
SubText_C:SetPoint('RIGHT', -32, 0)
SubText_C:SetText('這些選項可以調整戰鬥相關設定。')

local stopAutoAttack = newCheckbox(AIO_C, 'stopAutoAttackOnTargetChange')
stopAutoAttack:SetPoint("TOPLEFT", SubText_C, "BOTTOMLEFT", 0, -8)

local attackOnAssist = newCheckbox(AIO_C, 'assistAttack')
attackOnAssist:SetPoint("TOPLEFT", stopAutoAttack, "BOTTOMLEFT", 0, -4)

local castOnKeyDown = newCheckbox(AIO_C, 'ActionButtonUseKeyDown')
castOnKeyDown:SetPoint("TOPLEFT", attackOnAssist, "BOTTOMLEFT", 0, -4)

local spellStartRecovery = newSlider(AIO_C, 'SpellQueueWindow', 0, 400)
spellStartRecovery:SetPoint('TOPLEFT', castOnKeyDown, 'BOTTOMLEFT', 24, -12)
spellStartRecovery.minMaxValues = {spellStartRecovery:GetMinMaxValues()}
spellStartRecovery.minText:SetFormattedText("%d %s", spellStartRecovery.minMaxValues[1], MILLISECONDS_ABBR)
spellStartRecovery.maxText:SetFormattedText("%d %s", spellStartRecovery.minMaxValues[2], MILLISECONDS_ABBR)

-- Hook up options to addon panel
InterfaceOptions_AddCategory(AIO, addonName)
InterfaceOptions_AddCategory(AIO_Chat, addonName)
InterfaceOptions_AddCategory(AIO_C, addonName)
InterfaceOptions_AddCategory(AIO_FCT, addonName)
-- InterfaceOptions_AddCategory(AIO_ST, addonName)
InterfaceOptions_AddCategory(AIO_NP, addonName)

-- Slash handler
SlashCmdList.AIO = function(msg)
	msg = msg:lower()
	if not InCombatLockdown() then
		InterfaceOptionsFrame_OpenToCategory(addonNameLoc)
		InterfaceOptionsFrame_OpenToCategory(addonNameLoc)
	else
		DEFAULT_CHAT_FRAME:AddMessage("進階介面選項：戰鬥中無法調整介面設定")
	end
end
SLASH_AIO1 = "/aio"
