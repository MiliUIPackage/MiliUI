--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

-- Variables for config
if not DriftOptions then DriftOptions = {} end
local DriftOptionsPanel = {}
DriftOptionsPanel.config = {}

-- Variables for WoW version 
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local isBCC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
local isWC = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)

-- Variables for slash commands
local DRIFT = "DRIFT"
SLASH_DRIFT1 = "/drift"

local DRIFTRESET = "DRIFTRESET"
SLASH_DRIFTRESET1 = "/driftreset"


--------------------------------------------------------------------------------
-- Interface Options
--------------------------------------------------------------------------------

-- Local functions
local function createCheckbox(name, point, relativeFrame, relativePoint, xOffset, yOffset, text, tooltipText)
	local checkbox = CreateFrame("CheckButton", name, relativeFrame, "ChatConfigCheckButtonTemplate")
	checkbox:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset)
	getglobal(checkbox:GetName() .. "Text"):SetText(text)
	checkbox.tooltip = tooltipText
	return checkbox
end

local function createButton(name, point, relativeFrame, relativePoint, xOffset, yOffset, width, height, text, tooltipText, onClickFunction)
	local button = CreateFrame("Button", name, relativeFrame, "GameMenuButtonTemplate")
	button:SetPoint(point, relativeFrame, relativePoint, xOffset, yOffset)
	button:SetSize(width, height)
	button:SetText(text)
	button:SetNormalFontObject("GameFontNormal")
	button:SetHighlightFontObject("GameFontHighlight")

	-- Configure tooltip
	button.tooltipText = tooltipText
	button:SetScript(
		"OnEnter",
		function()
			GameTooltip:SetOwner(button, "ANCHOR_TOPRIGHT")
			GameTooltip:SetText(button.tooltipText, nil, nil, nil, nil, true)
		end
	)

	-- Configure click function
	button:SetScript("OnClick", onClickFunction)

	return button
end

-- Global functions
function DriftHelpers:SetupConfig()
	-- Initialize config options
	if DriftOptions.frameDragIsLocked == nil then
		DriftOptions.frameDragIsLocked = DriftOptions.framesAreLocked
	end
	if DriftOptions.frameScaleIsLocked == nil then
		DriftOptions.frameScaleIsLocked = DriftOptions.framesAreLocked
	end
	if DriftOptions.windowsDisabled == nil then
		DriftOptions.windowsDisabled = false
	end
	if DriftOptions.buttonsDisabled == nil then
		DriftOptions.buttonsDisabled = true
	end
	if DriftOptions.miscellaneousDisabled == nil then
		DriftOptions.miscellaneousDisabled = true
	end

	-- Options panel
	DriftOptionsPanel.optionspanel = CreateFrame("Frame", "DriftOptionsPanel", UIParent)
	DriftOptionsPanel.optionspanel.name = "移動視窗"
	local driftOptionsTitle = DriftOptionsPanel.optionspanel:CreateFontString(nil, "BACKGROUND")
	driftOptionsTitle:SetFontObject("GameFontNormalLarge")
	driftOptionsTitle:SetText("移動和縮放視窗")
	driftOptionsTitle:SetPoint("TOPLEFT", DriftOptionsPanel.optionspanel, "TOPLEFT", 15, -15)
	InterfaceOptions_AddCategory(DriftOptionsPanel.optionspanel)

	-- Frame Dragging
	local lockMoveTitle = DriftOptionsPanel.optionspanel:CreateFontString(nil, "BACKGROUND")
	lockMoveTitle:SetFontObject("GameFontNormal")
	lockMoveTitle:SetText("拖曳視窗")
	lockMoveTitle:SetPoint("TOPLEFT", DriftOptionsPanel.optionspanel, "TOPLEFT", 190, -90)

	local yOffset = -110

	DriftOptionsPanel.config.frameMoveLockedCheckbox = createCheckbox(
		"FrameMoveLockedCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		190,
		yOffset,
		" 鎖定拖曳視窗",
        "鎖定拖曳視窗時，必須按住指定的按鍵才能拖曳移動視窗。"
	)
	DriftOptionsPanel.config.frameMoveLockedCheckbox:SetChecked(DriftOptions.frameDragIsLocked)
	yOffset = yOffset - 30

	DriftOptionsPanel.config.dragAltKeyEnabledCheckbox = createCheckbox(
		"DragAltKeyEnabledCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		205,
		yOffset,
		" 按住 ALT 拖曳",
        "鎖定拖曳視窗時，必須按住 ALT 鍵才能拖曳移動視窗。"
	)
	DriftOptionsPanel.config.dragAltKeyEnabledCheckbox:SetChecked(DriftOptions.dragAltKeyEnabled)
	yOffset = yOffset - 30

	DriftOptionsPanel.config.dragCtrlKeyEnabledCheckbox = createCheckbox(
		"DragCtrlKeyEnabledCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		205,
		yOffset,
		" 按住 CTRL 拖曳",
        "鎖定拖曳視窗時，必須按住 CTRL 鍵才能拖曳移動視窗。"
	)
	DriftOptionsPanel.config.dragCtrlKeyEnabledCheckbox:SetChecked(DriftOptions.dragCtrlKeyEnabled)
	yOffset = yOffset - 30

	DriftOptionsPanel.config.dragShiftKeyEnabledCheckbox = createCheckbox(
		"DragShiftKeyEnabledCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		205,
		yOffset,
		" 按住 SHIFT 拖曳",
        "鎖定拖曳視窗時，必須按住 SHIFT 鍵才能拖曳移動視窗。"
	)
	DriftOptionsPanel.config.dragShiftKeyEnabledCheckbox:SetChecked(DriftOptions.dragShiftKeyEnabled)
	yOffset = yOffset - 40

	-- Frame Scaling
	local lockScaleTitle = DriftOptionsPanel.optionspanel:CreateFontString(nil, "BACKGROUND")
	lockScaleTitle:SetFontObject("GameFontNormal")
	lockScaleTitle:SetText("縮放視窗")
	lockScaleTitle:SetPoint("TOPLEFT", DriftOptionsPanel.optionspanel, "TOPLEFT", 190, yOffset)
	yOffset = yOffset - 20

	DriftOptionsPanel.config.frameScaleLockedCheckbox = createCheckbox(
		"FrameScaleLockedCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		190,
		yOffset,
		" 鎖定縮放視窗",
        "鎖定縮放視窗時，必須按住指定的按鍵才能縮放視窗大小。"
	)
	DriftOptionsPanel.config.frameScaleLockedCheckbox:SetChecked(DriftOptions.frameScaleIsLocked)
	yOffset = yOffset - 30

	DriftOptionsPanel.config.scaleAltKeyEnabledCheckbox = createCheckbox(
		"ScaleAltKeyEnabledCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		205,
		yOffset,
		" 按住 ALT 縮放",
        "鎖定縮放視窗時，必須按住 ALT 鍵才能縮放視窗大小。"
	)
	DriftOptionsPanel.config.scaleAltKeyEnabledCheckbox:SetChecked(DriftOptions.scaleAltKeyEnabled)
	yOffset = yOffset - 30

	DriftOptionsPanel.config.scaleCtrlKeyEnabledCheckbox = createCheckbox(
		"ScaleCtrlKeyEnabledCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		205,
		yOffset,
		" 按住 CTRL 縮放",
        "鎖定縮放視窗時，必須按住 CTRL 鍵才能縮放視窗大小。"
	)
	DriftOptionsPanel.config.scaleCtrlKeyEnabledCheckbox:SetChecked(DriftOptions.scaleCtrlKeyEnabled)
	yOffset = yOffset - 30

	DriftOptionsPanel.config.scaleShiftKeyEnabledCheckbox = createCheckbox(
		"ScaleShiftKeyEnabledCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		205,
		yOffset,
		" 按住 SHIFT 縮放",
        "鎖定縮放視窗時，必須按住 SHIFT 鍵才能縮放視窗大小。"
	)
	DriftOptionsPanel.config.scaleShiftKeyEnabledCheckbox:SetChecked(DriftOptions.scaleShiftKeyEnabled)

	-- Enabled Frames
	local frameToggleTitle = DriftOptionsPanel.optionspanel:CreateFontString(nil, "BACKGROUND")
	frameToggleTitle:SetFontObject("GameFontNormal")
	frameToggleTitle:SetText("啟用的框架")
	frameToggleTitle:SetPoint("TOPLEFT", DriftOptionsPanel.optionspanel, "TOPLEFT", 15, -90)

	yOffset = -110

	DriftOptionsPanel.config.windowsEnabledCheckbox = createCheckbox(
		"WindowsEnabledCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		15,
		yOffset,
		" 視窗",
        "是否需要移動或縮放遊戲內建的視窗和框架 (例如: 天賦視窗)。"
	)
	DriftOptionsPanel.config.windowsEnabledCheckbox:SetChecked(not DriftOptions.windowsDisabled)
	yOffset = yOffset - 30

	DriftOptionsPanel.config.buttonsEnabledCheckbox = createCheckbox(
		"ButtonsEnabledCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		15,
		yOffset,
		" 按鈕",
        "是否要移動或縮放按鈕 (例如: 打開回報單)。"
	)
	DriftOptionsPanel.config.buttonsEnabledCheckbox:SetChecked(not DriftOptions.buttonsDisabled)
	yOffset = yOffset - 30

	DriftOptionsPanel.config.miscellaneousEnabledCheckbox = createCheckbox(
		"MiscellaneousEnabledCheckbox",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		15,
		yOffset,
		" 其他",
        "是否需要移動或縮放其他框架 (例如: 戰網通知)。"
	)
	DriftOptionsPanel.config.miscellaneousEnabledCheckbox:SetChecked(not DriftOptions.miscellaneousDisabled)

	-- Reset button
	StaticPopupDialogs["DRIFT_RESET_POSITIONS"] = {
		text = "是否確定要將所有視窗都重置\n恢復成預設的位置和大小?",
        button1 = "是",
        button2 = "否",
		OnAccept = DriftHelpers.DeleteDriftState,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3, -- avoid UI taint
	}
	DriftOptionsPanel.config.resetButton = createButton(
		"ResetButton",
		"TOPLEFT",
		DriftOptionsPanel.optionspanel,
		"TOPLEFT",
		15,
		-47,
		132,
		25,
		"重置視窗",
        "重置所有視窗的位置與大小。",
		function (self, button, down)
			StaticPopup_Show("DRIFT_RESET_POSITIONS")
		end
	)

	-- Version and author
	local driftOptionsVersionLabel = DriftOptionsPanel.optionspanel:CreateFontString(nil, "BACKGROUND")
	driftOptionsVersionLabel:SetFontObject("GameFontNormal")
	driftOptionsVersionLabel:SetText("版本:")
	driftOptionsVersionLabel:SetJustifyH("LEFT")
	driftOptionsVersionLabel:SetPoint("BOTTOMLEFT", DriftOptionsPanel.optionspanel, "BOTTOMLEFT", 15, 30)

	local driftOptionsVersionContent = DriftOptionsPanel.optionspanel:CreateFontString(nil, "BACKGROUND")
	driftOptionsVersionContent:SetFontObject("GameFontHighlight")
	driftOptionsVersionContent:SetText(GetAddOnMetadata("Drift", "Version"))
	driftOptionsVersionContent:SetJustifyH("LEFT")
	driftOptionsVersionContent:SetPoint("BOTTOMLEFT", DriftOptionsPanel.optionspanel, "BOTTOMLEFT", 70, 30)

	local driftOptionsAuthorLabel = DriftOptionsPanel.optionspanel:CreateFontString(nil, "BACKGROUND")
	driftOptionsAuthorLabel:SetFontObject("GameFontNormal")
	driftOptionsAuthorLabel:SetText("作者:")
	driftOptionsAuthorLabel:SetJustifyH("LEFT")
	driftOptionsAuthorLabel:SetPoint("BOTTOMLEFT", DriftOptionsPanel.optionspanel, "BOTTOMLEFT", 15, 15)

	local driftOptionsAuthorContent = DriftOptionsPanel.optionspanel:CreateFontString(nil, "BACKGROUND")
	driftOptionsAuthorContent:SetFontObject("GameFontHighlight")
	driftOptionsAuthorContent:SetText("Jared Wasserman")
	driftOptionsAuthorContent:SetJustifyH("LEFT")
	driftOptionsAuthorContent:SetPoint("BOTTOMLEFT", DriftOptionsPanel.optionspanel, "BOTTOMLEFT", 70, 15)

	-- Update logic
	DriftOptionsPanel.optionspanel:SetScript("OnHide", function()
		local shouldReloadUI = false

		-- Dragging
		DriftOptions.frameDragIsLocked = DriftOptionsPanel.config.frameMoveLockedCheckbox:GetChecked()
		DriftOptions.dragAltKeyEnabled = DriftOptionsPanel.config.dragAltKeyEnabledCheckbox:GetChecked()
		DriftOptions.dragCtrlKeyEnabled = DriftOptionsPanel.config.dragCtrlKeyEnabledCheckbox:GetChecked()
		DriftOptions.dragShiftKeyEnabled = DriftOptionsPanel.config.dragShiftKeyEnabledCheckbox:GetChecked()

		-- Scaling
		DriftOptions.frameScaleIsLocked = DriftOptionsPanel.config.frameScaleLockedCheckbox:GetChecked()
		DriftOptions.scaleAltKeyEnabled = DriftOptionsPanel.config.scaleAltKeyEnabledCheckbox:GetChecked()
		DriftOptions.scaleCtrlKeyEnabled = DriftOptionsPanel.config.scaleCtrlKeyEnabledCheckbox:GetChecked()
		DriftOptions.scaleShiftKeyEnabled = DriftOptionsPanel.config.scaleShiftKeyEnabledCheckbox:GetChecked()

		-- Optional Frames
		local oldWindowsDisabled = DriftOptions.windowsDisabled
		DriftOptions.windowsDisabled = not DriftOptionsPanel.config.windowsEnabledCheckbox:GetChecked()
		if oldWindowsDisabled ~= DriftOptions.windowsDisabled then
			shouldReloadUI = true
		end

		local oldButtonsDisabled = DriftOptions.buttonsDisabled
		DriftOptions.buttonsDisabled = not DriftOptionsPanel.config.buttonsEnabledCheckbox:GetChecked()
		if oldButtonsDisabled ~= DriftOptions.buttonsDisabled then
			shouldReloadUI = true
		end

		local oldMiscellaneousDisabled = DriftOptions.miscellaneousDisabled
		DriftOptions.miscellaneousDisabled = not DriftOptionsPanel.config.miscellaneousEnabledCheckbox:GetChecked()
		if oldMiscellaneousDisabled ~= DriftOptions.miscellaneousDisabled then
			shouldReloadUI = true
		end

		-- Reload if needed
		if shouldReloadUI then
			ReloadUI()
		end
	end)
end


--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------

SlashCmdList[DRIFT] = function(msg, editBox)
	DriftHelpers:HandleSlashCommands(msg, editBox)
end

SlashCmdList[DRIFTRESET] = DriftHelpers.DeleteDriftState
