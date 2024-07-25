--[[---------------------------------------------------------------------------
    File:   CursorTrailConfig.lua
    Desc:   Functions and variables for showing this addon's configuration options.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
 BUGS & TODOs:
    TODO? Add sliders for each editbox.  (Too much visual clutter?)
-----------------------------------------------------------------------------]]

local kAddonFolderName, private = ...

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Saved (Persistent) Variables                      ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

CursorTrail_Config = CursorTrail_Config or {}
CursorTrail_PlayerConfig = CursorTrail_PlayerConfig or {}

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
local assert = _G.assert
local ColorPickerFrame = _G.ColorPickerFrame
local CopyTable = _G.CopyTable
local CreateFrame = _G.CreateFrame
local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME
local error = _G.error
local GetAddOnMetadata = _G.GetAddOnMetadata
local IsAltKeyDown = _G.IsAltKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsShiftKeyDown = _G.IsShiftKeyDown
local math = _G.math
local pairs = _G.pairs
local OpacitySliderFrame = _G.OpacitySliderFrame
local PlaySound = _G.PlaySound
local print = _G.print
local SOUNDKIT = _G.SOUNDKIT
local string = _G.string
local table = _G.table
local tonumber = _G.tonumber
local tostring = _G.tostring
local UIParent = _G.UIParent
local UnitAffectingCombat = _G.UnitAffectingCombat

--~ local GameMenuFrame = _G.GameMenuFrame
--~ local HideUIPanel = _G.HideUIPanel
local InterfaceOptions_AddCategory = _G.InterfaceOptions_AddCategory
--~ local InterfaceOptionsFrame_OpenToCategory = _G.InterfaceOptionsFrame_OpenToCategory
--~ local InterfaceOptionsFrameCancel_OnClick = _G.InterfaceOptionsFrameCancel_OnClick
--~ local InterfaceOptionsFrame = _G.InterfaceOptionsFrame
--~ local Settings = _G.Settings

--~ local CloseDropDownMenus = _G.CloseDropDownMenus
--~ local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
--~ local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
--~ local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
--~ local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
--~ local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
--~ local UIDropDownMenu_SetButtonWidth = _G.UIDropDownMenu_SetButtonWidth
--~ local UIDropDownMenu_JustifyText = _G.UIDropDownMenu_JustifyText

--~ local UIDropDownMenu_GetText = _G.UIDropDownMenu_GetText
--~ local UIDropDownMenuButton_GetChecked = _G.UIDropDownMenuButton_GetChecked
--~ local UIDropDownMenu_EnableDropDown = _G.UIDropDownMenu_EnableDropDown
--~ local UIDropDownMenu_DisableDropDown = _G.UIDropDownMenu_DisableDropDown

local OKAY, CANCEL, YES, NO, SAVE, DELETE, DEFAULT, DEFAULTS, RESET, CONTINUE, NEW, UNKNOWN
    = OKAY, CANCEL, YES, NO, SAVE, DELETE, DEFAULT, DEFAULTS, RESET, CONTINUE, NEW, UNKNOWN
assert(OKAY and CANCEL) -- Check some of these vars that are crucial (used to set closeReason).

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Declare Namespace                                 ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local CursorTrail = _G.CursorTrail or {}
if (not _G.CursorTrail) then _G.CursorTrail = CursorTrail end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Remap Global Environment                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

setfenv(1, _G.CursorTrail)  -- Everything after this uses our namespace rather than _G.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Switches                                          ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

----kTraceConfig = false  -- Set to true to trace entry/exit of functions in this file.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Constants                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

kButtonTemplate = ((kGameTocVersion >= 100000) and "UIPanelButtonTemplate") or "OptionsButtonTemplate"

kFrameHeaderWidth = 350
kFrameHeaderHeight = 58
kFrameMargin = 18
kTopMargin = 26
kRowHeight = 16
kRowSpacing = 16
kBtnWidth = 104
kBtnHeight = 22
kButtonSpacing = 4
kDropdownListboxScale = 0.95

kFrameWidth = 459
kColumnWidth1 = 100  -- Width of the labels column.
kColumnWidth2 = kFrameWidth-(kFrameMargin*2)-kColumnWidth1-kBtnWidth-25  -- Width of values column.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Helper Function                                   ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function getAddonConfig()  -- Returns the addon's persistent "SavedVariables" config data.
    ----assert(self == nil)  -- Fails if function called using ':' instead of '.'.
    return Globals.CursorTrail_Config
end

-------------------------------------------------------------------------------
function getPlayerConfig()  -- Returns the addon's persistent "SavedVariablesPerCharacter" config data.
    ----assert(self == nil)  -- Fails if function called using ':' instead of '.'.
    return Globals.CursorTrail_PlayerConfig
end

-------------------------------------------------------------------------------
local gbUI_Locked = false  -- For verifying there isn't concurrent access to UI values.
function LOCK_UI() assert(not gbUI_Locked); gbUI_Locked = true; end
function UNLOCK_UI() gbUI_Locked = false; end

-------------------------------------------------------------------------------
function UI_SetValues(config)  -- Copies config data into UI widgets.  If 'config'
                               -- is nil, copies last saved data into the UI widgets.
    ----print("Called UI_SetValues().", config)
    ----if config and config.TABLE_ID then -- Verify config parameter is data, not ProfilesUI's 'self' table!
    ----    assert(nil, "UI_SetValues() was called by "..config.TABLE_ID.." using ':' instead of '.' syntax!")
    ----end
    LOCK_UI()
    OptionsFrame.ShapeColor:CloseColorPicker(false)  -- Make sure color picker is closed.  (Cancel color changes.)

    ----vdt_dump(config, "config (1) in UI_SetValues()")
    config = config or PlayerConfig  -- Use local copy of "SavedVariables" data if config is nil.
    ----vdt_dump(config, "config (2) in UI_SetValues()")
    validateSettings(config)  -- Ensure all config fields exist, and have valid values.
    ----vdt_dump(config, "config (3) in UI_SetValues()")

    -- Close any popup menus that are open.
    OptionsFrame.ModelDropDown:HideSelections()
    OptionsFrame.ShapeDropDown:HideSelections()
    OptionsFrame.StrataDropDown:HideSelections()

    -- Copy config data into UI widgets.  (Convert nil values to false/"" so OptionsFrame_Value() works right.)
    OptionsFrame_Value("shape", config.ShapeFileName or "")
    OptionsFrame.ShapeColor:SetColor( config.ShapeColorR, config.ShapeColorG, config.ShapeColorB) ---, 0.75) --Uncomment to test opacity slider.
    OptionsFrame_Value("sparkle", config.ShapeSparkle or false)
    OptionsFrame_Value("model", config.ModelID)

    OptionsFrame_Value("shadow", config.UserShadowAlpha or 0)
    OptionsFrame_Value("scale", config.UserScale)
    OptionsFrame_Value("alpha", config.UserAlpha)
    OptionsFrame_Value("Strata", config.Strata)
    OptionsFrame_Value("OfsX", config.UserOfsX)
    OptionsFrame_Value("OfsY", config.UserOfsY)

    if config.FadeOut == true or config.FadeOut == false then  -- If nil, leave as-is.
        OptionsFrame_Value("fade", config.FadeOut)
    end
    if config.UserShowOnlyInCombat == true or config.UserShowOnlyInCombat == false then  -- If nil, leave as-is.
        OptionsFrame_Value("combat", config.UserShowOnlyInCombat)
    end
    if config.UserShowMouseLook == true or config.UserShowMouseLook == false then  -- If nil, leave as-is.
        OptionsFrame_Value("MouseLook", config.UserShowMouseLook)
    end

    OptionsFrame_UpdateButtonStates()
    OptionsFrame_ClearFocus()

    -- Apply changes.  (Necessary when loading a profile.)
    staticCopyTable(config, PlayerConfig)  -- Update PlayerConfig in case the values came from a saved profile.
    OptionsFrame_SetModified(true)
    CursorTrail_Load(PlayerConfig)  -- Apply changes to model and texture FX variables.

    ----if OptionsFrame:IsShown() then OptionsFrame:UpdatePreview() end
    if OptionsFrame:IsShown() or not PlayerConfig.UserShowOnlyInCombat or UnitAffectingCombat("player") then
        CursorTrail_Show()
    end
    UNLOCK_UI()
end

-------------------------------------------------------------------------------
function UI_GetValues(config)  -- Copies UI values into 'config'.  If 'config' is nil, copies
                               -- UI values to the addon's "SavedVariables" config data.
    ----print("Called UI_GetValues().", config)
    ----if config and config.TABLE_ID then -- Verify config parameter is data, not ProfilesUI's 'self' table!
    ----    assert(nil, "UI_GetValues() was called by "..config.TABLE_ID.." using ':' instead of '.' syntax!")
    ----end
    LOCK_UI()
    config = config or PlayerConfig  -- Use local copy of "SavedVariablesPerCharacter" data if config is nil.

    -- Copy UI values into the config parameter.
    config.ShapeFileName = OptionsFrame_Value("shape")
    config.ModelID    = OptionsFrame_Value("model")
    OptionsFrame.ShapeColor:CloseColorPicker(true)  -- Save any color changes.
    config.ShapeColorR, config.ShapeColorG, config.ShapeColorB = OptionsFrame.ShapeColor:GetColor()
    config.ShapeSparkle = OptionsFrame_Value("sparkle")

    config.UserShadowAlpha = OptionsFrame_Value("shadow")
    config.UserScale  = OptionsFrame_Value("scale")
    config.UserAlpha  = OptionsFrame_Value("alpha")
    config.Strata     = OptionsFrame_Value("strata")
    config.UserOfsX   = OptionsFrame_Value("OfsX")
    config.UserOfsY   = OptionsFrame_Value("OfsY")

    config.FadeOut    = OptionsFrame_Value("fade")
    config.UserShowOnlyInCombat = OptionsFrame_Value("combat")
    config.UserShowMouseLook = OptionsFrame_Value("MouseLook")

    -- Extra Validation.
    -- (Prevent 1% scale because it causes many models to fill screen and stop moving.)
    local minScale = 0.02  -- 2%
    if (config.UserScale < minScale) then config.UserScale = minScale end
    ----vdt_dump(config, "UI_GetValues()")
    UNLOCK_UI()
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                     StandardPanel Functions                             ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function traceCfg(msg)
    ----if kTraceConfig then
        print("|c0080ff80"..msg)
    ----end
end

-------------------------------------------------------------------------------
function StandardPanel_Create(buttonText, buttonW, buttonH)
    --|traceCfg("IN StandardPanel_Create().")
    --|if StandardPanel then traceCfg("OUT StandardPanel_Create(), early 1."); return; end  -- Return now if it already exists.

    assert(buttonText)
    buttonW = buttonW or 150
    buttonH = buttonH or 28
    local ofs = 8

    -- Create a simple frame with a single button that opens the addon's options.
    -- Use this frame in the standard WoW UI.
    StandardPanel = CreateFrame("frame", kAddonFolderName.."StandardPanel", UIParent)
    StandardPanel.name = kAddonFolderName  -- The addon name that appears in the standard WoW UI.

    local headingText = StandardPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    headingText:SetPoint("TOPLEFT", 16, -16)
    headingText:SetText(kAddonFolderName.."  "..kAddonVersion)

    local descText = StandardPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    descText:SetPoint("TOPLEFT", headingText, "BOTTOMLEFT", ofs, -ofs)
    local description = GetAddOnMetadata(kAddonFolderName, "Notes") or ""
    descText:SetText(description)

    local optionsBtn = CreateFrame("Button", nil, StandardPanel, kButtonTemplate)
    optionsBtn:SetPoint("LEFT", headingText, "LEFT", 0, 0)
    optionsBtn:SetPoint("TOP", descText, "BOTTOM", 0, -ofs)
    optionsBtn:SetSize(buttonW, buttonH)
    optionsBtn:SetText(buttonText)

    optionsBtn:SetScript("OnClick", function(self)
        ------ Close the standard WoW addons UI.
        ----if Globals.Settings then  -- WoW 10.0 or later?
        ----    Globals.SettingsPanel.ClosePanelButton:Click()    ILLEGAL CALL!
        ----else
        ----    InterfaceOptionsFrameCancel_OnClick()
        ----end
        ----
        ------ Close the main WoW menu.
        ----HideUIPanel(GameMenuFrame)

        -- Show/hide this addon's config UI.
        if OptionsFrame:IsShown() then OptionsFrame:Hide() else OptionsFrame:Show() end
    end)

    -- Adds this top level panel to the Interface Options.
    ----if Settings then
    ----    StandardPanel.OnCommit = function() end
    ----    StandardPanel.OnDefault = function() end
    ----    StandardPanel.OnRefresh = function() end
    ----    local category, layout = Settings.RegisterCanvasLayoutCategory(StandardPanel, StandardPanel.name, StandardPanel.name)
    ----    category.ID = StandardPanel.name
    ----    Settings.RegisterAddOnCategory(category)
    ----else
        InterfaceOptions_AddCategory(StandardPanel)
    ----end
    --|traceCfg("OUT StandardPanel_Create().")
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                     OptionsFrame Functions                              ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function OptionsFrame_Create()
    --|traceCfg("IN OptionsFrame_Create().")
    --|if OptionsFrame then traceCfg("OUT OptionsFrame_Create(), early 1."); return; end  -- Return now if it already exists.
    assert(not OptionsFrame)  -- Fails if function is called more than once.

    local frameName = kAddonFolderName.."OptionsFrame"
    OptionsFrame = CreateFrame("frame", frameName, UIParent, "BackdropTemplate")

    ---->>> Removed to ensure pressing ESC triggers CANCEL button (for prompting user to save profile changes).
    ----Globals.tinsert(Globals.UISpecialFrames, frameName) -- Allow options frame to close via ESCAPE key.
    ----                                                    -- NOTE: Causes options to close whenever Blizz options UI is closed.  :(

    -----------------------------
    -- - - - Frame Setup - - - --
    -----------------------------
    OptionsFrame:Hide()
    ----OptionsFrame:SetScale(0.9)
    OptionsFrame:SetFrameStrata("DIALOG")
    OptionsFrame:SetToplevel(true)
    OptionsFrame:SetPoint("CENTER")
    OptionsFrame:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 7, right = 8, top = 8, bottom = 7 }
    })
    OptionsFrame:SetBackdropColor(0,0,0, 1)
    OptionsFrame:EnableKeyboard(true)
    OptionsFrame_SetModified(false)

    -- Dark background (for making the window less transparent).
    OptionsFrame.BackdropOverlay = OptionsFrame:CreateTexture(nil, "BACKGROUND")
    OptionsFrame.BackdropOverlay:SetColorTexture(0.03, 0.03, 0.03,  0.5)
    OptionsFrame.BackdropOverlay:SetPoint("TOPLEFT", 8, -8)
    OptionsFrame.BackdropOverlay:SetPoint("BOTTOMRIGHT", -8, 8)

    -- TOOLTIP:
    OptionsFrame.WarnTooltip = CreateFrame("GameTooltip", kAddonFolderName.."WarnTooltip", OptionsFrame, "GameTooltipTemplate")
    OptionsFrame.WarnTooltip:SetFrameStrata("DIALOG")  -- So popup menus don't get obscured by a tooltip.

    -- WINDOW HEADER BOX:
    OptionsFrame.HeaderTexture = OptionsFrame:CreateTexture(nil, "ARTWORK")
    OptionsFrame.HeaderTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    OptionsFrame.HeaderTexture:SetWidth(kFrameHeaderWidth)
    OptionsFrame.HeaderTexture:SetHeight(kFrameHeaderHeight)
    OptionsFrame.HeaderTexture:SetPoint("TOP", OptionsFrame, "TOP", 0, 13)

    OptionsFrame.HeaderText = OptionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    OptionsFrame.HeaderText:SetPoint("TOP", OptionsFrame.HeaderTexture, "TOP", 0, -13)
    OptionsFrame.HeaderText:SetText(kAddonFolderName.."  "..kAddonVersion)

    -- Allow moving the options window.
    OptionsFrame:EnableMouse(true)
    OptionsFrame:SetMovable(true)
    OptionsFrame:SetClampedToScreen(true)
    OptionsFrame:SetClampRectInsets(250, -250, -350, 350)
    OptionsFrame:RegisterForDrag("LeftButton")

    ------------------------
    -- - - - EVENTS - - - --
    ------------------------
    OptionsFrame:SetScript("OnShow", OptionsFrame_OnShow)
    OptionsFrame:SetScript("OnHide", OptionsFrame_OnHide)
    OptionsFrame:SetScript("OnDragStart", function() OptionsFrame:StartMoving() end)
    OptionsFrame:SetScript("OnDragStop", function() OptionsFrame:StopMovingOrSizing() end)
    OptionsFrame:SetScript("OnKeyDown", OptionsFrame_OnKeyDown)
    OptionsFrame:SetScript("OnMouseUp", OptionsFrame_ClearFocus)
    ----OptionsFrame:SetScript("OnEnter", OptionsFrame_RaiseEffectsStrata)
    ----OptionsFrame:SetScript("OnLeave", OptionsFrame_RestoreEffectsStrata)

    -------------------------
    -- - - - WIDGETS - - - --
    -------------------------
    local topPos = -kFrameMargin - kTopMargin
    local xPos = kFrameMargin
    local yPos = topPos

    -- PROFILES --
    yPos = yPos + 8  -- Tweak position.
    OptionsFrame.ProfilesUI = private.UDProfiles_CreateUI({
                        parent = OptionsFrame,
                        xPos = kFrameMargin,
                        yPos = yPos,
                        getAddonConfig = getAddonConfig,
                        UI_SetValues = UI_SetValues,
                        UI_GetValues = UI_GetValues,
                        defaults = kDefaultConfig,
                        defaultKeyName = kDefaultConfigKey,
                    })
    ----OptionsFrame.ProfilesUI.bMouseWheelTips = false -- Optional customization.
    OptionsFrame.ProfilesUI:setBackColor(0.5, 0.5, 0.9,  0.15)
    OptionsFrame.ProfilesUI:setListBoxLinesPerPage(20, 17)  -- #lines, lineHeight
    ----OptionsFrame.ProfilesUI:setListBoxLinesPerPage(5)  -- For testing.
    ----OptionsFrame.ProfilesUI.mainFrame.profilesListBox.sliderFrame:SetValueStep(3)
    ----OptionsFrame.ProfilesUI:SetPoint("RIGHT", -kFrameMargin, 0)
    OptionsFrame.ProfilesUI:setWidthOfBox( kColumnWidth1 + kColumnWidth2 + 16 )

    ----local profilesLB = OptionsFrame.ProfilesUI.mainFrame.profilesListBox
    ----profilesLB:HookScript("OnShow", function()
    ----            ----vdt_dump(profilesLB, "profilesLB in OnShow hook")
    ----            if profilesLB:containsDefaults() then  -- Defaults listbox?
    ----                OptionsFrame.ProfilesUI:setListBoxBackColor(1,1,1, 0.6) -- Transparent.
    ----            else
    ----                OptionsFrame.ProfilesUI:setListBoxBackColor() -- Solid.
    ----            end
    ----        end)

    yPos = yPos - OptionsFrame.ProfilesUI:GetHeight() - kRowSpacing - 4
    topPos = yPos

    -- DIVIDER LINE --
    OptionsFrame_CreateDividerLine(xPos, yPos+14)

    -- DEFAULTS BUTTON --
    OptionsFrame.DefaultsBtn = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn:SetText( Globals.DEFAULTS .." ..." )
    local fontName, fontSize = OptionsFrame.DefaultsBtn.Text:GetFont()
    OptionsFrame.DefaultsBtn.Text:SetFont(fontName, fontSize-2)
    OptionsFrame.DefaultsBtn:SetSize(kBtnWidth, kBtnHeight-2)
    OptionsFrame.DefaultsBtn:SetAlpha(0.95)
    OptionsFrame.DefaultsBtn:SetPoint("TOPRIGHT", OptionsFrame, "TOPRIGHT", -kFrameMargin, -kFrameMargin-kTopMargin-3)
    OptionsFrame.DefaultsBtn:SetScript("OnClick", function(self)
                local defaultsLB = OptionsFrame.ProfilesUI.menu.defaults()
                defaultsLB:ClearAllPoints()
                defaultsLB:SetPoint("TOPLEFT", OptionsFrame.DefaultsBtn,
                                    "TOPRIGHT", kFrameMargin-7, defaultsLB.titleBox:GetHeight())
            end)

--~     -- TEST BUTTON --
--~     OptionsFrame.TestBtn = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
--~     OptionsFrame.TestBtn:SetText("TEST")
--~     OptionsFrame.TestBtn:SetPoint("TOP", OptionsFrame.DefaultsBtn, "BOTTOM", 0, -kButtonSpacing)
--~     OptionsFrame.TestBtn:SetSize(kBtnWidth, kBtnHeight-4)
--~     ----OptionsFrame.TestBtn:SetScript("OnClick", displayAllFonts)  -- DISPLAY ALL FONTS
--~     OptionsFrame.TestBtn:SetScript("OnClick", function()
--~                 -- Create a scrollable changelog window.
--~                 if (OptionsFrame.TestBtn.tsf ~= nil) then OptionsFrame.TestBtn.tsf = nil end  -- Destroy old window first.
--~                 OptionsFrame.TestBtn.tsf = createTextScrollFrame(OptionsFrame, "*** "..kAddonFolderName.." Changelog ***", 500)
--~                 ----OptionsFrame.TestBtn.tsf = createTextScrollFrame(OptionsFrame, nil, 333)
--~
--~                 local tsf = OptionsFrame.TestBtn.tsf
--~                 local dy = 6
--~
--~                 tsf:addText(ORANGE..kAddonFolderName.." 10.0.7.2", 0, 0, "GameFontNormalHuge") --"OptionsFontLarge") --"GameFontNormalLarge")
--~                 tsf:addText(BLUE.."New Features:", 0, dy, "GameTooltipHeader")
--~                 tsf:addText("* Some new feature.\n* "..RED2.."Another|r new feature.",
--~                             0, dy, "GameTooltipText")
--~                 tsf:addText(BLUE.."Changes:", 0, dy, "GameTooltipHeader")
--~                 tsf:addText("* Some change that was made.\n* Another change that was made.\n* Yet another change.",
--~                             0, dy, "GameTooltipText")
--~
--~                 tsf:addText("ISSUE - Memory still in use after scroll window is closed!\nMight take up lots of memory as your changelog history grows.\n ", 0, dy)
--~
--~                 local indent = 16 -- pixels
--~                 tsf:addText("Section 1:", 0, 8, "GameFontNormalLarge")
--~                 tsf:addText("This is the first line.\n  (Scroll way down to see the last!)", indent)
--~                 tsf:addText("|cffEE5500Line #2 is orange.|r", indent)
--~                 tsf:addText("This is line #3.  It is a very long line in order to test the .:.:.:. word wrap feature of the scroll frame.\n ")
--~                 tsf:addText("This is 5000 pixels below the top, so scrollChild automatically adjusts its height.", 0, 5000)
--~             end)

    -- CANCEL BUTTON --
    OptionsFrame.CancelBtn = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.CancelBtn:SetText(CANCEL)
    OptionsFrame.CancelBtn:SetPoint("BOTTOMRIGHT", OptionsFrame, "BOTTOMRIGHT", -kFrameMargin, kFrameMargin)
    OptionsFrame.CancelBtn:SetSize(kBtnWidth, kBtnHeight+2)
    OptionsFrame.CancelBtn:SetScript("OnClick", OptionsFrame_OnCancel)

    -- OKAY BUTTON --
    OptionsFrame.OkayBtn = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.OkayBtn:SetText(OKAY)
    OptionsFrame.OkayBtn:SetPoint("RIGHT", OptionsFrame.CancelBtn, "LEFT", -kButtonSpacing, 0)
    OptionsFrame.OkayBtn:SetSize(kBtnWidth, kBtnHeight+2)
    OptionsFrame.OkayBtn:SetScript("OnClick", OptionsFrame_OnOkay)

    -- HELP BUTTON --
    local function createHelpTexture(parent, alpha)
        local tex = parent:CreateTexture(nil, "ARTWORK")
        ----tex:SetTexture("Interface\\HELPFRAME\\HelpIcon-KnowledgeBase")
        ----tex:SetTexCoord(0.20, 0.8, 0.2, 0.8)
        ----tex:SetSize(20, 20)
        tex:SetTexture("Interface\\MINIMAP\\TRACKING\\Profession")
        tex:SetSize(32, 32)
        if alpha then tex:SetAlpha(alpha) end
        return tex
    end

    local normalTex, highlightTex, pushedTex
    normalTex    = createHelpTexture(OptionsFrame, 0.7)
    highlightTex = createHelpTexture(OptionsFrame, 0.4)
    pushedTex    = createHelpTexture(OptionsFrame, 0.4)
    OptionsFrame.HelpBtn = private.UDControls.CreateTextureButton(OptionsFrame, normalTex, highlightTex, pushedTex)

    OptionsFrame.HelpBtn:SetPoint("BOTTOMLEFT", OptionsFrame, "BOTTOMLEFT", kFrameMargin-2, kFrameMargin-3)
    OptionsFrame.HelpBtn:SetTooltip("Help", "ANCHOR_TOP")
    OptionsFrame.HelpBtn:SetScript("OnClick", function(self)
            PlaySound(private.kSound.ActionQuiet)
            CursorTrail_ShowHelp(OptionsFrame)
        end)

    -- CHANGELOG BUTTON (ICON) --
    local function createChangelogTexture(parent, alpha)
        local tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetTexture("Interface\\COMMON\\help-i")
        tex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        tex:SetSize(20, 20)
        if alpha then tex:SetAlpha(alpha) end
        return tex
    end

    normalTex    = createChangelogTexture(OptionsFrame, 0.7)
    highlightTex = createChangelogTexture(OptionsFrame, 0.4)
    pushedTex    = createChangelogTexture(OptionsFrame, 0.4)
    OptionsFrame.ChangelogBtn = private.UDControls.CreateTextureButton(OptionsFrame, normalTex, highlightTex, pushedTex)

    OptionsFrame.ChangelogBtn:SetPoint("LEFT", OptionsFrame.HelpBtn, "RIGHT", 7, -0.5)
    OptionsFrame.ChangelogBtn:SetTooltip("Changelog", "ANCHOR_TOP")
    OptionsFrame.ChangelogBtn:SetScript("OnClick", function(self)
            PlaySound(private.kSound.ActionQuiet)
            CursorTrail_ShowChangelog(OptionsFrame)
        end)

    -- SHAPE --
    yPos = topPos
    yPos = yPos + 2  -- Tweak position slightly.
    OptionsFrame.ShapeLabel = OptionsFrame_CreateLabel("Shape:", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.ShapeDropDown = OptionsFrame_CreateShapeDropDown(xPos, yPos, 140)

    ------ Temporarily increase the cursor FX strata levels when mouse hovers over this dropdown menu.
    ----OptionsFrame.ShapeDropDown:SetScript("OnEnter", OptionsFrame_RaiseEffectsStrata)
    ----OptionsFrame.ShapeDropDown:SetScript("OnLeave", OptionsFrame_RestoreEffectsStrata)
    ----OptionsFrame.ShapeDropDown.buttonFrame:SetScript("OnEnter", OptionsFrame_RaiseEffectsStrata)
    ----OptionsFrame.ShapeDropDown.buttonFrame:SetScript("OnLeave", OptionsFrame_RestoreEffectsStrata)

    -- SHAPE COLOR SWATCH --
    OptionsFrame.ShapeColor = private.UDControls.CreateColorSwatch( OptionsFrame, 22 )
    OptionsFrame.ShapeColor:SetPoint("LEFT", OptionsFrame.ShapeDropDown, "RIGHT", 8, -1)
    OptionsFrame.ShapeColor:SetTooltip("Click to change shape color.")
    OptionsFrame.ShapeColor:SetColorChangedHandler(function(self)
                Shape_SetColor(self.r, self.g, self.b, self.a)
                OptionsFrame.ProfilesUI:OnValueChanged()
                OptionsFrame_SetModified(true)
                ----OptionsFrame:UpdatePreview()
            end)

    OptionsFrame.ShapeColor:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    OptionsFrame.ShapeColor:SetScript("OnMouseUp", function(self, mouseButton)
                PlaySound(private.kSound.ActionQuiet)

                if mouseButton == "RightButton" then
                    -- Right-clicks set the control's default value.
                    if ColorPickerFrame:IsShown() then
                        ColorPickerFrame:Hide()
                    end
                    self:SetColor(1,1,1)
                    self:colorChangedHandler()
                end
            end)

    -- SHAPE SPARKLE --
    OptionsFrame.SparkleCheckbox = OptionsFrame_CreateCheckBox("Sparkle", xPos, yPos)
    OptionsFrame.SparkleCheckbox:ClearAllPoints()
    OptionsFrame.SparkleCheckbox:SetPoint("LEFT", OptionsFrame.ShapeColor, "RIGHT", 4, 0)
    OptionsFrame.SparkleCheckbox:SetScript('PostClick', function(self, button)
        local isChecked = self:GetChecked()
        if isChecked and ColorPickerFrame:IsShown() then
            ColorPickerFrame:Hide()
        end
        CursorTrail_SetShapeSparkle(isChecked)
        OptionsFrame_UpdateButtonStates()
    end)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- MODEL --
    OptionsFrame.ModelLabel = OptionsFrame_CreateLabel("Model:", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.ModelDropDown = OptionsFrame_CreateModelDropDown(xPos, yPos, kColumnWidth2+16)

    ------ Temporarily increase the cursor FX strata levels when mouse hovers over this dropdown menu.
    ----OptionsFrame.ModelDropDown:SetScript("OnEnter", OptionsFrame_RaiseEffectsStrata)
    ----OptionsFrame.ModelDropDown:SetScript("OnLeave", OptionsFrame_RestoreEffectsStrata)
    ----OptionsFrame.ModelDropDown.buttonFrame:SetScript("OnEnter", OptionsFrame_RaiseEffectsStrata)
    ----OptionsFrame.ModelDropDown.buttonFrame:SetScript("OnLeave", OptionsFrame_RestoreEffectsStrata)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- SHADOW (%) --
    OptionsFrame.ShadowLabel = OptionsFrame_CreateLabel("Shadow (%):", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.ShadowEditBox = OptionsFrame_CreateEditBox(xPos, yPos, nil, 3, true, 0)
    OptionsFrame.ShadowEditBox:SetScript("OnTextChanged", OptionsFrame_OnShadowChanged)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- DIVIDER LINE --
    OptionsFrame_CreateDividerLine( xPos, yPos+(kRowSpacing/2)+2 ) ----, kFrameMargin+kColumnWidth1+kColumnWidth2 )
    yPos = yPos - 2  -- Tweak position slightly.

    -- SCALE (%) --
    OptionsFrame.ScaleLabel = OptionsFrame_CreateLabel("Scale (%):", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.ScaleEditBox = OptionsFrame_CreateEditBox(xPos, yPos, nil, 3, true, 100)
    OptionsFrame.ScaleEditBox:SetScript("OnTextChanged", OptionsFrame_OnValueChanged)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- OPACITY --
    OptionsFrame.AlphaLabel = OptionsFrame_CreateLabel("Opacity (%):", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.AlphaEditBox = OptionsFrame_CreateEditBox(xPos, yPos, nil, 3, true, 100)
    OptionsFrame.AlphaEditBox:SetScript("OnTextChanged", OptionsFrame_OnAlphaChanged)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- STRATA LEVEL --
    OptionsFrame.StrataLabel = OptionsFrame_CreateLabel("Layer (Strata):", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.StrataDropDown = OptionsFrame_CreateStrataDropDown(xPos, yPos, 138)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- MODEL OFFSETS --
    ----yPos = yPos + 4  -- Move offset values a little closer to the model dropdown.
    OptionsFrame.OffsetLabel = OptionsFrame_CreateLabel("Model Offsets:", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    -- X
    OptionsFrame.OfsXEditBox = OptionsFrame_CreateEditBox(xPos, yPos, 42, nil, nil, 0)
    OptionsFrame.OfsXEditBox.scrollDelta = 0.25
    OptionsFrame.OfsXEditBox:SetScript("OnTextChanged", OptionsFrame_OnValueChanged)
    xPos = xPos + OptionsFrame.OfsXEditBox:GetWidth() + 12  -- Next column.
    -- Y
    OptionsFrame.OfsYEditBox = OptionsFrame_CreateEditBox(xPos, yPos, 42, nil, nil, 0)
    OptionsFrame.OfsYEditBox.scrollDelta = OptionsFrame.OfsXEditBox.scrollDelta
    OptionsFrame.OfsYEditBox:SetScript("OnTextChanged", OptionsFrame_OnValueChanged)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- TAB ORDER --
    OptionsFrame_TabOrder={ OptionsFrame.ShadowEditBox,
                            OptionsFrame.ScaleEditBox,
                            OptionsFrame.AlphaEditBox,
                            OptionsFrame.OfsXEditBox, OptionsFrame.OfsYEditBox }

    -- DIVIDER LINE --
    OptionsFrame_CreateDividerLine( xPos, yPos+(kRowSpacing/2) ) ----, kFrameMargin+kColumnWidth1+kColumnWidth2 )

    -- FADE OUT --
    yPos = yPos - 3  -- Tweak position slightly.
    OptionsFrame.FadeCheckbox = OptionsFrame_CreateCheckBox("Fade out when idle.", xPos, yPos)
	OptionsFrame.FadeCheckbox:SetScript('PostClick', function(self, button)
        --|traceCfg("IN FadeCheckbox:PostClick().")
        CursorTrail_SetFadeOut( self:GetChecked() )
        --|traceCfg("OUT FadeCheckbox:PostClick().")
    end)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- SHOW ONLY IN COMBAT --
    OptionsFrame.CombatCheckbox = OptionsFrame_CreateCheckBox("Show only in combat.", xPos, yPos)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- SHOW DURING MOUSELOOK --
    OptionsFrame.MouseLookCheckbox = OptionsFrame_CreateCheckBox("Show during Mouse Look.", xPos, yPos)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- DIVIDER LINE --
    OptionsFrame_CreateDividerLine( xPos, yPos+(kRowSpacing/2)+2 )

    ------ HORIZONTAL DIVIDER LINE --
    ----OptionsFrame.DividerHoriz = OptionsFrame_CreateDividerLine(kFrameWidth-kFrameMargin-kBtnWidth-8, -30, 1, 257)

    -- TIP --
    OptionsFrame.TipText = OptionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    OptionsFrame.TipText:ClearAllPoints()
    OptionsFrame.TipText:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", xPos-2, yPos)
    OptionsFrame.TipText:SetPoint("RIGHT", -kFrameMargin, 0)
    OptionsFrame.TipText:SetText("* TIP: You can use the mouse wheel or Up/Down keys to change values.")
    OptionsFrame.TipText:SetJustifyH("LEFT")

    --------------------------------
    -- Set size of options window.
    --------------------------------
    OptionsFrame:SetHeight(-yPos + kBtnHeight + (2 * kFrameMargin) + 4)
    OptionsFrame:SetWidth(kFrameWidth)

    -------------------------------------------------------
    -- Buttons for changing base steps. (Developers only!)
    -------------------------------------------------------
    if (kEditBaseValues == true) then
        OptionsFrame:SetPoint("CENTER", UIParent, "CENTER", kFrameWidth/2+100, 0)  -- Move it right.
        local develWarning = OptionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        develWarning:SetPoint("BOTTOMLEFT", OptionsFrame, "TOPLEFT", 9, 10)
        develWarning:SetText("|cff00FFFF***** WARNING - BASE VALUE EDITING KEYS ARE ENABLED! *****")

        centerFrame = CreateFrame("Frame", nil, OptionsFrame)
        centerFrame:SetPoint("CENTER", UIParent, "CENTER")
        centerFrame.updateSize = function(self)  -- [ Keywords: centerFrame:updateSize() ]
                    local boxSize = 22 / ScreenScale
                    centerFrame:SetSize(boxSize, boxSize)
                end
        centerFrame:updateSize()
        centerFrame:SetAlpha(0.5)
        local lineW = 2
        local topLine = centerFrame:CreateTexture(nil, "BACKGROUND")
        topLine:SetColorTexture(0, 0, 0, 1) -- Black
        topLine:SetPoint("TOPLEFT", centerFrame, "TOPLEFT", 0, lineW)
        topLine:SetPoint("BOTTOMRIGHT", centerFrame, "TOPRIGHT", 0, 0)

        local bottomLine = centerFrame:CreateTexture(nil, "BACKGROUND")
        bottomLine:SetColorTexture(0, 0, 0, 1) -- Black
        bottomLine:SetPoint("TOPLEFT", centerFrame, "BOTTOMLEFT", 0, -lineW)
        bottomLine:SetPoint("BOTTOMRIGHT", centerFrame, "BOTTOMRIGHT", 0, 0)

        local leftLine = centerFrame:CreateTexture(nil, "BACKGROUND")
        leftLine:SetColorTexture(0, 0, 0, 1) -- Black
        leftLine:SetPoint("TOPLEFT", centerFrame, "TOPLEFT", -lineW, lineW)
        leftLine:SetPoint("BOTTOMRIGHT", centerFrame, "BOTTOMLEFT", 0, -lineW)

        local rightLine = centerFrame:CreateTexture(nil, "BACKGROUND")
        rightLine:SetColorTexture(0, 0, 0, 1) -- Black
        rightLine:SetPoint("TOPLEFT", centerFrame, "TOPRIGHT", 0, lineW)
        rightLine:SetPoint("BOTTOMRIGHT", centerFrame, "BOTTOMRIGHT", lineW, -lineW)

        local centerPoint = centerFrame:CreateTexture(nil, "BACKGROUND")
        centerPoint:SetColorTexture(0, 0, 0, 1) -- Black
        centerPoint:SetPoint("CENTER", centerFrame, "CENTER")
        centerPoint:SetSize(3, 3)

        local function onKeyDown_ChangeBaseVals(self, key)
            --|traceCfg("IN onKeyDown_ChangeBaseVals("..(self:GetName() or "nil")..", "..(key or "nil")..")")
            local bPassKeyToParent = false

            if key == "ESCAPE" then
                OptionsFrame_OnOkay()
                ----CursorModel_Dump()
            elseif key == "NUMPADPLUS" then
                OptionsFrame_IncrDecrModel(-1)
            elseif key == "NUMPADMINUS" then
                OptionsFrame_IncrDecrModel(1)
            elseif IsShiftKeyDown() and key == "/" then  -- Pressed '?' key.
                local color = "|cff9999ff"
                print(color.."Base values for '"..(CursorModel.Constants.Name or "NIL").."' ...|r\n"
                    .. "        BaseScale = " .. CursorModel.Constants.BaseScale
                          .. ", BaseFacing = " .. CursorModel.Constants.BaseFacing .. ",\n"
                    .. "        BaseOfsX = " .. CursorModel.Constants.BaseOfsX
                          .. ", BaseOfsY = ".. CursorModel.Constants.BaseOfsY .. ",\n"
                    .. "        BaseStepX = " .. CursorModel.Constants.BaseStepX
                          .. ", BaseStepY = " .. CursorModel.Constants.BaseStepY .. "," )
            elseif IsAltKeyDown() then
                -- Change base step sizes.
                local delta = 10
                if IsControlKeyDown() then delta=delta*10 elseif IsShiftKeyDown() then delta=delta/10 end
                if IsControlKeyDown() then delta=100 elseif IsShiftKeyDown() then delta=1 else delta=10 end
                if key == "UP"        then HandleToolSwitches("bsy++"..delta)
                elseif key == "DOWN"  then HandleToolSwitches("bsy--"..delta)
                elseif key == "LEFT"  then HandleToolSwitches("bsx--"..delta)
                elseif key == "RIGHT" then HandleToolSwitches("bsx++"..delta)
                else bPassKeyToParent = true
                end
            else
                -- Change base offsets.
                local delta = 0.25
                if IsControlKeyDown() then delta=delta*10 elseif IsShiftKeyDown() then delta=delta/10 end
                if key == "UP"        then HandleToolSwitches("boy++"..delta)
                elseif key == "DOWN"  then HandleToolSwitches("boy--"..delta)
                elseif key == "LEFT"  then HandleToolSwitches("box--"..delta)
                elseif key == "RIGHT" then HandleToolSwitches("box++"..delta)
                else bPassKeyToParent = true
                end
            end

            -- If the key wasn't processed above, pass it to our parent frame.
            if bPassKeyToParent then OptionsFrame_OnKeyDown(self, key)
            else propagateKeyboardInput(OptionsFrame, false) end

            --|traceCfg("OUT onKeyDown_ChangeBaseVals("..(self:GetName() or "nil")..", "..(key or "nil")..")")
        end
        OptionsFrame:SetScript("OnKeyDown", onKeyDown_ChangeBaseVals)
    end

    --|traceCfg("OUT OptionsFrame_Create().")
end

-----------------------------------------------------------------------------------
----function OptionsFrame_RaiseEffectsStrata()
----    local level = "TOOLTIP"
----    CursorModel:SetFrameStrata(level)
----    ShapeFrame:SetFrameStrata(level)
----end
----
-----------------------------------------------------------------------------------
----function OptionsFrame_RestoreEffectsStrata()
----    local level = OptionsFrame_Value("strata")
----    CursorModel:SetFrameStrata(level)
----    ShapeFrame:SetFrameStrata(level)
----end

-------------------------------------------------------------------------------
function OptionsFrame_HandleNewFeatures()
    local newFeatureIndicator = GREEN.."::::("..NEW..")::::|r"
    local bNewFeaturesShown = false

    -- Loop through all new features and for each one the user has not yet seen, change
    -- the variable label to indicate it is a new feature.
    for _, pt in pairs(kNewFeatures) do
        local newFeatureName = pt.relativeTo
        ----print("OptionsFrame_HandleNewFeatures(), newFeatureName:", newFeatureName)
        ----print("CursorTrail_Config.NewFeaturesSeen["..newFeatureName.."] =", Globals.CursorTrail_Config.NewFeaturesSeen[newFeatureName])
        if not Globals.CursorTrail_Config.NewFeaturesSeen[newFeatureName] then
            local widget
            name1, name2, name3 = string.split(".", newFeatureName)
            if name3 then
                widget = OptionsFrame[name1][name2][name3]
            elseif name2 then
                widget = OptionsFrame[name1][name2]
            else
                widget = OptionsFrame[name1]
            end

            if not widget then
                print(kAddonErrorHeading.."Invalid widget name in kNewFeatures variable!  ("
                        ..RED2..newFeatureName..WHITE..")")
            else
                -- Show a "new feature" indicator by the widget named [newFeatureName].
                ----print("OptionsFrame_HandleNewFeatures(), widget:GetText():", widget:GetText())
                local dx = 0
                if widget:IsObjectType("FontString") then
                    local textWidth = widget:GetStringWidth()
                    local justify = widget:GetJustifyH()
                    if (justify == "RIGHT") then
                        dx = dx + widget:GetWidth() - textWidth
                    elseif (justify == "CENTER") then
                        dx = dx + widget:GetWidth() - (textWidth/2)
                    elseif (justify == "LEFT") then
                        dx = dx - widget:GetWidth() + textWidth
                    end
                end

                local newStr = OptionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                newStr:SetText(newFeatureIndicator)
                --newStr:SetPoint("RIGHT", widget, "LEFT", dx, 0)
                newStr:SetPoint(pt.anchor, widget, pt.relativeAnchor, pt.x + dx, pt.y)

                -- Clear the "new feature" flag so this only happens once.
                Globals.CursorTrail_Config.NewFeaturesSeen[newFeatureName] = true  -- No more nagging after this.
                bNewFeaturesShown = true
            end
        end
    end

    if (bNewFeaturesShown == true) then
        print(kAddonAlertHeading.."New features have "..newFeatureIndicator.." near their name.  (Cleared at next reload.)")
        PlaySound(1440) -- 1440=LevelUp, 171006=ReputationLevelUp
    end
end

-------------------------------------------------------------------------------
function OptionsFrame_OnShow()
    --|traceCfg("IN OptionsFrame_OnShow().")
    assert(PlayerConfig == getPlayerConfig())  -- Verify address has not changed from incorrectly using CopyTable().
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    EventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    OptionsFrame_HandleNewFeatures()  -- Flag any new features.

    OptionsFrame.OriginalConfig = CopyTable(PlayerConfig)
    UI_SetValues(PlayerConfig)
    ------OptionsFrame_RaiseEffectsStrata()
    CursorTrail_Show()  -- Show the cursor model while the options window is open.
    ----OptionsFrame:UpdatePreview()
    OptionsFrame_SetModified(false)
    OptionsFrame.closeReason = nil
    --|traceCfg("OUT OptionsFrame_OnShow().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnHide()
    --|traceCfg("IN OptionsFrame_OnHide().")
    assert(PlayerConfig == getPlayerConfig())  -- Verify address has not changed from incorrectly using CopyTable().
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    ------OptionsFrame_RestoreEffectsStrata()
    OptionsFrame.ShapeColor:CloseColorPicker(false)  -- Make sure color picker is closed.  (Cancel color changes.)
    ----if not OptionsFrame.closeReason then  -- UI closed by slash command instead of button click?
    ----    OptionsFrame_OnOkay()
    ----end

    if PlayerConfig.UserShowOnlyInCombat and not UnitAffectingCombat("player") then
        CursorTrail_Hide()  -- Not in combat so hide the cursor effects.
    end
    CursorTrail_HideHelp()
    CursorTrail_HideChangelog()
    OptionsFrame.OriginalConfig = nil  -- Free memory.
    EventFrame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    --|traceCfg("OUT OptionsFrame_OnHide().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnOkay()
    --|traceCfg("IN OptionsFrame_OnOkay().")
    OptionsFrame.closeReason = OKAY
    if not OptionsFrame.OkayBtn:IsEnabled() then
        -- Bail out.  Prevents accepting bad settings when pressing ENTER.
        return PlaySound(8959)  -- 8959=RaidWarning
    end

    if OptionsFrame_IsModified() then
        -- Copy values of UI widgets into persistent config data.
        UI_GetValues(PlayerConfig)  -- Store changes into persistent "SavedVariablesPerCharacter" variable.
        PlayerConfig_Save()
        CursorTrail_SetFadeOut(PlayerConfig.FadeOut) --TODO:Remove?
        CursorTrail_Load(PlayerConfig)  -- Apply changes to model and texture FX variables.
        OptionsFrame_SetModified(false)
    end

    OptionsFrame.ProfilesUI:OnOkay()  -- Updates the current profile's data.
    OptionsFrame:Hide()
    --|traceCfg("OUT OptionsFrame_OnOkay().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnCancel()
    --|traceCfg("IN OptionsFrame_OnCancel().")
    OptionsFrame.closeReason = CANCEL

    -- Revert to previous config.
    staticCopyTable( OptionsFrame.OriginalConfig, PlayerConfig )  -- Set PlayerConfig to original values.
    CursorTrail_Load(PlayerConfig)  -- Update FX variables.
    UI_SetValues(PlayerConfig)  -- Update UI widgets so slash commands will work properly.
    OptionsFrame.ProfilesUI:OnCancel()  -- Reverts to original profile (name and data).
    OptionsFrame_SetModified(false)
    OptionsFrame:Hide()
    --|traceCfg("OUT OptionsFrame_OnCancel().")
end

-------------------------------------------------------------------------------
function OptionsFrame_UpdateButtonStates()  -- UpdateOkayButton()
    -- If everything has been turned off, disable the OK button.
    local modelID = OptionsFrame_Value("model")
    local shadowAlpha = OptionsFrame_Value("shadow")
    local shapeFileName = OptionsFrame_Value("shape")
    if (modelID == 0
        and shadowAlpha == 0.0
        and (shapeFileName == nil or shapeFileName == ""))
      then
        OptionsFrame.OkayBtn:SetEnabled(false)
        ----print(kAddonFolderName..": OK button DISABLED.")

        -- Show warning message in tooltip.
        local tt = OptionsFrame.WarnTooltip
        ----tt:SetText("Tooltip test message.", 1, .82, 0, 1, true)  -- R, G, B, A, line wrap.
        tt:SetOwner(OptionsFrame, "ANCHOR_BOTTOM", 0, 12)
        tt:ClearLines()
        tt:AddLine("*** PROBLEM ***", 1, 0.2, 0.2, true)  -- R, G, B, line wrap.
        tt:AddLine("Model, Shape, and Shadow (%) are all off!  (One must be on.)", 1, 1, 1, false)
        tt:Show()
    elseif (OptionsFrame.OkayBtn:IsEnabled() ~= true) then
        OptionsFrame.OkayBtn:SetEnabled(true)
        OptionsFrame.WarnTooltip:Hide()  -- Clear any warning message.
        ----print(kAddonFolderName..": OK button enabled.")
    end

    -- Enable/disable the shape's color picker button based on the selected shape.
    if (shapeFileName == nil or shapeFileName == "" or OptionsFrame.SparkleCheckbox:GetChecked()) then
        OptionsFrame.ShapeColor:Disable()
    else
        OptionsFrame.ShapeColor:Enable()
    end

    -- Enable/disable the sparkle checkbox based on the selected shape.
    if (shapeFileName == nil or shapeFileName == "") then
        OptionsFrame.SparkleCheckbox:Disable()
    else
        OptionsFrame.SparkleCheckbox:Enable()
    end
end

-------------------------------------------------------------------------------
function OptionsFrame_OnKeyDown(self, key)
    --|traceCfg("IN OptionsFrame_OnKeyDown("..(self:GetName() or "nil")..", "..(key or "nil")..").")
    --|if not OptionsFrame:IsShown() then traceCfg("OUT OptionsFrame_OnKeyDown(), early 1."); return; end
    local bPassKeyToParent = false

    if key == "TAB" then
        OptionsFrame_FocusNext()
    elseif key == "ESCAPE" then
        if not OptionsFrame.ProfilesUI:hideOptions()
          and not CursorTrail_HideChangelog()
          and not CursorTrail_HideHelp()
          then
            OptionsFrame_OnCancel()
        end
    else bPassKeyToParent = true
    end

    propagateKeyboardInput(OptionsFrame, bPassKeyToParent)
    --|traceCfg("OUT OptionsFrame_OnKeyDown("..(self:GetName() or "nil")..", "..(key or "nil")..").")
end

-------------------------------------------------------------------------------
function OptionsFrame_EditBox_OnKeyDown(self, key)
    --|traceCfg("IN OptionsFrame_EditBox_OnKeyDown("..(self:GetName() or "nil")..", "..(key or "nil")..").")
    if key == "/" or key == "`" then
        propagateKeyboardInput(self, true) -- Pass this key to parent.
    else
        propagateKeyboardInput(self, false) -- Don't pass this key to parent.

        if key == "TAB" then OptionsFrame_FocusNext()
        ----elseif key == "ESCAPE" then OptionsFrame:Hide()
        ----elseif key == "ENTER" then OptionsFrame_ClearFocus()
        elseif key == "UP" then OptionsFrame_IncrDecrValue(self, 1)
        elseif key == "DOWN" then OptionsFrame_IncrDecrValue(self, -1)
        end
    end
    --|traceCfg("OUT OptionsFrame_EditBox_OnKeyDown("..(self:GetName() or "nil")..", "..(key or "nil")..").")
end

-------------------------------------------------------------------------------
function OptionsFrame_DropDown_OnButtonUp(self, mouseButton)
    PlaySound(private.kSound.ActionQuiet)

    if mouseButton == "RightButton" then
        -- Right-clicks toggle between default value and previous selection.
        local dropdown = self:GetParent()
        dropdown:HideSelections()
        local current = dropdown:GetSelectedText()
        if current == kStr_None then
            if dropdown.previousSelection then
                dropdown:SelectText(dropdown.previousSelection, true)
            end
        else
            dropdown:SelectText(kStr_None, true)
        end
        dropdown.previousSelection = current
    end
end

-------------------------------------------------------------------------------
function OptionsFrame_FocusNext()
    --|traceCfg("IN OptionsFrame_FocusNext().")
    local count = #OptionsFrame_TabOrder

    if IsShiftKeyDown() then  -- Previous control.
        for i = 2, count do
            if OptionsFrame_TabOrder[i]:HasFocus() then
                --|traceCfg("OUT OptionsFrame_FocusNext(), early 1.")
                return OptionsFrame_TabOrder[i-1]:SetFocus()
            end
        end
        OptionsFrame_TabOrder[count]:SetFocus()
    else  -- Next control.
        for i = 1, count-1 do
            if OptionsFrame_TabOrder[i]:HasFocus() then
                --|traceCfg("OUT OptionsFrame_FocusNext(), early 2.")
                return OptionsFrame_TabOrder[i+1]:SetFocus()
            end
        end
        OptionsFrame_TabOrder[1]:SetFocus()
    end
    --|traceCfg("OUT OptionsFrame_FocusNext().")
end

-------------------------------------------------------------------------------
function OptionsFrame_ClearFocus()
    --|traceCfg("IN OptionsFrame_ClearFocus().")
    if not OptionsFrame:IsShown() then return end
    local count = #OptionsFrame_TabOrder
    for i = 1, count do
        if OptionsFrame_TabOrder[i]:HasFocus() then
            --|traceCfg("OUT OptionsFrame_ClearFocus(), early 1.")
            return OptionsFrame_TabOrder[i]:ClearFocus()
        end
    end
    --|traceCfg("OUT OptionsFrame_ClearFocus().")
end

-------------------------------------------------------------------------------
function OptionsFrame_IncrDecrValue(self, delta)
    --|traceCfg("IN OptionsFrame_IncrDecrValue("..(self:GetName() or "nil")..").")
    if self.scrollDelta then delta = delta * self.scrollDelta end
    local num = tonumber(self:GetText()) or 0
    num = num + delta
    local r = (num*100) % (delta*100)
    num = num - r*0.01  -- Ensure changes snap to nearest delta step.

    self:SetFocus()
    self:SetText(num)
    local handler = self:GetScript("OnTextChanged")
    if handler then handler(num, true) end
    self:HighlightText()
    ----self:SetCursorPosition(99)
    --|traceCfg("OUT OptionsFrame_IncrDecrValue("..(self:GetName() or "nil")..").")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnValueChanged(self, isUserInput)
    --|traceCfg("IN OptionsFrame_OnValueChanged().")
    ----print("OptionsFrame_OnValueChanged:  self:GetText() =", self:GetText())
    if (isUserInput == true) then
        local config = {}
        config.UserScale = OptionsFrame_Value("scale")
        config.UserAlpha = OptionsFrame_Value("alpha")
        config.UserOfsX = OptionsFrame_Value("OfsX")
        config.UserOfsY = OptionsFrame_Value("OfsY")

        CursorTrail_ApplyModelSettings(config)
        OptionsFrame.ProfilesUI:OnValueChanged()
        OptionsFrame_SetModified(true)
        ----OptionsFrame:UpdatePreview()
    end
    --|traceCfg("OUT OptionsFrame_OnValueChanged().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnAlphaChanged(self, isUserInput)
    --|traceCfg("IN OptionsFrame_OnAlphaChanged().")
    ----print("OptionsFrame_OnAlphaChanged:  self:GetText() =", self:GetText())
    if (isUserInput == true) then
        local alpha = OptionsFrame_Value("alpha")
        CursorModel:SetAlpha( alpha )
        if ShapeTexture then
            ShapeTexture:SetAlpha( alpha )
        end
        PlayerConfig.UserAlpha = alpha  -- Required so changes are seen when motion fading is on.
        OptionsFrame.ProfilesUI:OnValueChanged()
        OptionsFrame_SetModified(true)
        ----OptionsFrame:UpdatePreview()
    end
    --|traceCfg("OUT OptionsFrame_OnAlphaChanged().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnShadowChanged(self, isUserInput)
    --|traceCfg("IN OptionsFrame_OnShadowChanged().")
    ----print("OptionsFrame_OnShadowChanged:  self:GetText() =", self:GetText())
    if (isUserInput == true) then
        local shadowAlpha = OptionsFrame_Value("shadow")
        ShadowTexture:SetAlpha( shadowAlpha )
        PlayerConfig.UserShadowAlpha = shadowAlpha  -- Required so changes are seen when motion fading is on.
        OptionsFrame.ProfilesUI:OnValueChanged()
        OptionsFrame_SetModified(true)
        ----OptionsFrame:UpdatePreview()
    end
    OptionsFrame_UpdateButtonStates()
    --|traceCfg("OUT OptionsFrame_OnShadowChanged().")
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                OptionsFrame Helper Functions                            ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function OptionsFrame_Value(valName, newVal)  -- [ Keywords: OptionsFrame_Value() ]
-- Gets or sets a value in the options frame UI.
-- If only 'valName' is passed in, the specified value is returned.
-- If 'valName' and 'newVal' are both passed in, the specified value is set.
-- NOTE: This function can't be used to set a value to nil!
    --|traceCfg("IN OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil")..").")
    local retVal, editbox, minVal, maxVal, currVal, defaultNum
    local multiplier = 1

    valName = string.lower(valName)
    if (newVal ~= nil) then  -- SET
        OptionsFrame_SetModified(true)
    end

    ----------------------------------
    -- CHECKBOXES ...
    -- - - - - - - - - - - - - - - - -
    if (valName == "combat") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.CombatCheckbox:GetChecked()
        else -- SET
            OptionsFrame.CombatCheckbox:SetChecked(newVal)
        end
        --|traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early.")
        return retVal
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "mouselook") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.MouseLookCheckbox:GetChecked()
        else -- SET
            OptionsFrame.MouseLookCheckbox:SetChecked(newVal)
        end
        --|traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early.")
        return retVal
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "fade") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.FadeCheckbox:GetChecked()
        else -- SET
            OptionsFrame.FadeCheckbox:SetChecked(newVal)
        end
        --|traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early.")
        return retVal
    elseif (valName == "sparkle") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.SparkleCheckbox:GetChecked()
        else -- SET
            OptionsFrame.SparkleCheckbox:SetChecked(newVal)
        end
        --|traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early.")
        return retVal
    -- - - - - - - - - - - - - - - - -

    ----------------------------------
    -- DROPDOWN MENUS ...
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "model") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.ModelDropDown:GetSelectedID()
        else -- SET
            if (kModelConstants[newVal] == nil) then
                newVal = kDefaultModelID
            end
            OptionsFrame.ModelDropDown:SelectID( newVal )
        end
        --|traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early.")
        return retVal
    elseif (valName == "strata") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.StrataDropDown:GetSelectedID()
        else -- SET
            OptionsFrame.StrataDropDown:SelectID( newVal )
        end
        --|traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early.")
        return retVal
    elseif (valName == "shape") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.ShapeDropDown:GetSelectedID()
        else -- SET
            OptionsFrame.ShapeDropDown:SelectID( newVal )
        end
        --|traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early.")
        return retVal

    ----------------------------------
    -- EDITBOXES (must be last) ...
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "scale") then
        editbox = OptionsFrame.ScaleEditBox
        minVal, maxVal = 0.01, 9.98  -- (1% to 998%)
        multiplier = 100
        defaultNum = 100  -- 100%
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "ofsx") then
        editbox = OptionsFrame.OfsXEditBox
        multiplier = 10
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "ofsy") then
        editbox = OptionsFrame.OfsYEditBox
        multiplier = 10
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "alpha") then  -- Opacity
        editbox = OptionsFrame.AlphaEditBox
        minVal, maxVal = 0.01, 1.00  -- (1% to 100%)
        multiplier = 100
        defaultNum = 100  -- 100%
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "shadow") then  -- Shadow Opacity
        if not OptionsFrame.ShadowEditBox then return end  -- For when shadow feature is disabled.
        editbox = OptionsFrame.ShadowEditBox
        minVal, maxVal = 0.00, 0.99  -- (0% to 99%)  NOTE: At 100% a solid black square appears.
        multiplier = 100
    -- - - - - - - - - - - - - - - - -
    else assert(nil, 'Invalid parameter!  (valName: "'..(valName or "NIL")..'")') end

    -- GET/SET the EditBox value. --
    if (newVal == nil) then  -- GET
        currVal = (tonumber(editbox:GetText()) or defaultNum or 0) / multiplier
        retVal = currVal
        if (minVal ~= nil and retVal < minVal) then retVal = minVal end
        if (maxVal ~= nil and retVal > maxVal) then retVal = maxVal end
        if (retVal ~= currVal and tonumber(editbox:GetText())) then
            editbox:SetText( (tonumber(retVal) or 0) * multiplier )  -- Display the changed value.
        end
        ----print( 'OptionsFrame_Value("'..valName..'") returned: '..(retVal or "NIL") )
    else -- SET
        if (minVal ~= nil and newVal < minVal) then newVal = minVal end
        if (maxVal ~= nil and newVal > maxVal) then newVal = maxVal end
        editbox:ClearFocus()
        editbox:SetText( (tonumber(newVal) or 0) * multiplier )
        ----print( 'OptionsFrame_Value("'..valName..'") set to: '..newVal )
    end

    --|traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil")..").")
    return retVal
end

-------------------------------------------------------------------------------
function OptionsFrame_CreateSolidRect(x, y, width, height, r, g, b, a)
    --|traceCfg("IN OptionsFrame_CreateSolidRect().")
    local rectFrame = CreateFrame("Frame", nil, OptionsFrame)
    rectFrame:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x, y)
    rectFrame:SetSize(width, height)
    rectFrame.texture = rectFrame:CreateTexture(nil, "BACKGROUND")
    rectFrame.texture:SetAllPoints()
    rectFrame.texture:SetColorTexture((r or 0), (g or 0), (b or 0), (a or 1))
    --|traceCfg("OUT OptionsFrame_CreateSolidRect().")
    return rectFrame
end

-------------------------------------------------------------------------------
function OptionsFrame_CreateDividerLine(x, y, width, height)
    width = width or kFrameWidth-(kFrameMargin*2)
    height = height or 1
    return OptionsFrame_CreateSolidRect(x, y, width, height, 0.5, 0.5, 0.5, 0.5)
end

-------------------------------------------------------------------------------
function OptionsFrame_CreateLabel(labelText, x, y, fontName)
    --|traceCfg("IN OptionsFrame_CreateLabel("..labelText..").")
    local labelFrame = OptionsFrame:CreateFontString(nil, "ARTWORK", fontName or "GameFontNormal")
    labelFrame:ClearAllPoints()
    ----labelFrame:SetPoint("TOPRIGHT", OptionsFrame, "TOPLEFT", kFrameMargin+kColumnWidth1, y)
    ----labelFrame:SetPoint("LEFT", OptionsFrame, "LEFT", kFrameMargin, 0)
    labelFrame:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x, y)
    labelFrame:SetPoint("RIGHT", OptionsFrame, "LEFT", kFrameMargin+kColumnWidth1, 0)
    labelFrame:SetJustifyH("RIGHT")
    labelFrame:SetWordWrap(false)
    labelFrame:SetText(labelText)
    --|traceCfg("OUT OptionsFrame_CreateLabel("..labelText..").")
    return labelFrame
end

-------------------------------------------------------------------------------
function OptionsFrame_CreateEditBox(x, y, width, maxChars, bNumeric, defaultVal)
    --|traceCfg("IN OptionsFrame_CreateEditBox().")
    local editboxFrame = CreateFrame("EditBox", nil, OptionsFrame, "InputBoxTemplate")
    editboxFrame:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x+9, y+10)
    editboxFrame:SetAutoFocus(false)
    editboxFrame:SetSize(32, 32)
    if maxChars then
        editboxFrame:SetMaxLetters(maxChars)
        editboxFrame:SetWidth(maxChars*10)
    end
    if width then
        editboxFrame:SetWidth(width)
    end
    if (bNumeric == true) then
        editboxFrame:SetNumeric(true)  -- Allows characters 0-9 only. (No negative or float #s!!)
    end
    editboxFrame:SetScript("OnEnterPressed", OptionsFrame_ClearFocus)
    ----editboxFrame:SetScript("OnTabPressed", OptionsFrame_FocusNext)
    editboxFrame:SetScript("OnKeyDown", OptionsFrame_EditBox_OnKeyDown)
    editboxFrame:SetScript("OnEditFocusGained", function(self) self:HighlightText(); self:SetCursorPosition(99) end)
    editboxFrame:SetScript("OnMouseWheel", OptionsFrame_IncrDecrValue)

    -- Make right-clicks set the control's default value (or revert to previous selection).
    if defaultVal then
        editboxFrame:HookScript("OnMouseUp", function(self, mouseButton)
                    if mouseButton == "RightButton" then
                        editboxFrame:SetText(defaultVal)
                        editboxFrame:HighlightText()
                        editboxFrame:GetScript("OnTextChanged")(editboxFrame, true)
                        PlaySound(private.kSound.ActionQuiet)
                    end
                end)
    end

    --|traceCfg("OUT OptionsFrame_CreateEditBox().")
    return editboxFrame
end

-------------------------------------------------------------------------------
function OptionsFrame_CreateCheckBox(labelText, x, y)
    --|traceCfg("IN OptionsFrame_CreateCheckBox().")
	local checkbox = CreateFrame("CheckButton", nil, OptionsFrame, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x+kFrameMargin+kColumnWidth1-17, y+7)
	checkbox:SetScript('OnClick', function(self)
                    --|traceCfg("IN checkbox:OnClick("..(self:GetName() or "nil")..").")
                    if self:GetChecked() then PlaySound(856) else PlaySound(857) end -- IG_MAINMENU_OPTION_CHECKBOX_ON/OFF.

                    OptionsFrame.ProfilesUI:OnValueChanged()
                    OptionsFrame_SetModified(true)
                    OptionsFrame_ClearFocus()
                    --|traceCfg("OUT checkbox:OnClick("..(self:GetName() or "nil")..").")
                end)

    -- Set label text.
    checkbox.Text:SetText(labelText)
    checkbox.Text:SetFontObject("GameFontNormal")
    checkbox.Text:SetJustifyH("LEFT")
    checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
    checkbox.Text:SetPoint("RIGHT", OptionsFrame, "RIGHT", -kFrameMargin, 0)  -- Required for wordwrap.

    -- Handle enabling/disabling the checkbox.
    checkbox:HookScript("OnDisable", function(self)
                local GRAY_FONT_COLOR = Globals.GRAY_FONT_COLOR
                self.Text:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
            end)
    checkbox:HookScript("OnEnable", function(self)
                local NORMAL_FONT_COLOR = Globals.NORMAL_FONT_COLOR
                self.Text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
            end)

    ---->>> Removed because users could accidentally change a checkbox while trying to move the window.
    ------ Make clicking the text toggle the checkbox.
    ----checkbox.Text:SetScript("OnMouseUp", function(self) self:GetParent():Click() end)

    --|traceCfg("OUT OptionsFrame_CreateCheckBox().")
    return checkbox
end

--------------------------------------------------------------------------------
function OptionsFrame_CreateModelDropDown(x, y, width)
    --|traceCfg("IN OptionsFrame_CreateModelDropDown().")
    local dropdown = private.UDControls.CreateDropDown(OptionsFrame)
    dropdown:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x, y+7)
    dropdown:Configure(width / kDropdownListboxScale)
    dropdown:SetDynamicWheelSpeed(true)
    dropdown:SetListBoxHeight(ScreenH / kDropdownListboxScale)
    dropdown:GetListBoxFrame():SetScale( kDropdownListboxScale )
    ----dropdown.tooltip = "Testing  1  2  3"  -- For testing.

    dropdown:SetChangeHandler(
        function(self, selectedID)
            --|traceCfg("IN dropdown:changeHandler("..(selectedID or "nil")..").")
            OptionsFrame_Value("model", selectedID)
            OptionsFrame.ProfilesUI:OnValueChanged()

            -- Display the new model immediately.  (Use current UI values for all settings.)
            local tmpConfig = CopyTable(PlayerConfig)
            tmpConfig.UserShowOnlyInCombat = false -- Always show while Options Window is open.
            tmpConfig.ModelID   = selectedID
            tmpConfig.ShapeFileName = OptionsFrame_Value("shape")
            tmpConfig.UserScale = OptionsFrame_Value("scale")
            tmpConfig.UserAlpha = OptionsFrame_Value("alpha")
            tmpConfig.Strata    = OptionsFrame_Value("strata")
            tmpConfig.UserShadowAlpha = OptionsFrame_Value("shadow")
            tmpConfig.UserOfsX  = OptionsFrame_Value("OfsX")
            tmpConfig.UserOfsY  = OptionsFrame_Value("OfsY")
            tmpConfig.FadeOut   = OptionsFrame_Value("fade")
            tmpConfig.ShapeColorR, tmpConfig.ShapeColorG, tmpConfig.ShapeColorB = OptionsFrame.ShapeColor:GetColor()

            CursorTrail_Load(tmpConfig)
            CursorTrail_Show()
            OptionsFrame_UpdateButtonStates()
            ----OptionsFrame_RaiseEffectsStrata()
            ----OptionsFrame:UpdatePreview()

            if kNewModels[selectedID] then
                Globals.CursorTrail_Config.NewFeaturesSeen[selectedID] = true  -- Only mark new models until they are selected once.
            end
            --|traceCfg("OUT dropdown:changeHandler("..(selectedID or "nil")..").")
        end
    )

    -- Add the items.
    local newFeaturesSeen = Globals.CursorTrail_Config.NewFeaturesSeen
    local newModelIndicator = GREEN.."("..NEW..")|r "
    for _, modelData in pairs(kSortedModelChoices) do
        local name = modelData.Name
        local ID = modelData.sortedID
        if kNewModels[ID] and not newFeaturesSeen[ID] then
            ----name = newModelIndicator .. name  -- Mark new models.
            for key, cat in pairs(kCategory) do
                local catLen = #cat
                if cat == name:sub(1,catLen) then
                    name = cat .. newModelIndicator .. name:sub(catLen+1)
                end
            end
        end
        dropdown:AddItem(name, ID)
    end

    -- Set dropdown's text to the selected model name.
    dropdown:SelectID( PlayerConfig.ModelID )

    -- Make mouse wheel over the collapsed dropdown change its selection.
    dropdown:SetScript("OnMouseWheel", function(self, delta)
                --|traceCfg("IN ModelDropDown:OnMouseWheel().")
                self:HideSelections()  -- i.e. CloseDropDownMenus()
                OptionsFrame_IncrDecrModel(delta)
                --|traceCfg("OUT ModelDropDown:OnMouseWheel().")
            end)

    -- Make right-clicks set the control's default value (or revert to previous selection).
    dropdown.buttonFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    dropdown.buttonFrame:SetScript("OnMouseUp", OptionsFrame_DropDown_OnButtonUp)

    ----vdt_dump(dropdown, "dropdown in CreateModelDropDown")
    --|traceCfg("OUT OptionsFrame_CreateModelDropDown().")
    return dropdown
end

--------------------------------------------------------------------------------
function OptionsFrame_CreateShapeDropDown(x, y, width)
    --|traceCfg("IN OptionsFrame_CreateShapeDropDown().")
    local dropdown = private.UDControls.CreateDropDown(OptionsFrame)
    dropdown:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x, y+7)
    dropdown:Configure(width / kDropdownListboxScale)
    ----dropdown:SetDynamicWheelSpeed(true)
    dropdown:SetListBoxHeight(ScreenH / kDropdownListboxScale)
    dropdown:GetListBoxFrame():SetScale( kDropdownListboxScale )

    dropdown:SetChangeHandler(
        function(self, selectedID)
            --|traceCfg("IN dropdown:changeHandler("..(selectedID or "nil")..").")
            OptionsFrame_Value("shape", selectedID)
            OptionsFrame.ProfilesUI:OnValueChanged()

            -- Display the new shape immediately.  (Use current UI values for all settings.)
            local tmpConfig = CopyTable(PlayerConfig)
            tmpConfig.UserShowOnlyInCombat = false -- Always show while Options Window is open.
            tmpConfig.ModelID   = OptionsFrame_Value("model")
            tmpConfig.ShapeFileName = selectedID
            tmpConfig.UserScale = OptionsFrame_Value("scale")
            tmpConfig.UserAlpha = OptionsFrame_Value("alpha")
            tmpConfig.Strata    = OptionsFrame_Value("strata")
            tmpConfig.UserShadowAlpha = OptionsFrame_Value("shadow")
            tmpConfig.UserOfsX  = OptionsFrame_Value("OfsX")
            tmpConfig.UserOfsY  = OptionsFrame_Value("OfsY")
            tmpConfig.FadeOut   = OptionsFrame_Value("fade")
            tmpConfig.ShapeColorR, tmpConfig.ShapeColorG, tmpConfig.ShapeColorB = OptionsFrame.ShapeColor:GetColor()

            CursorTrail_Load(tmpConfig)
            CursorTrail_Show()
            OptionsFrame_UpdateButtonStates()
            ----OptionsFrame_RaiseEffectsStrata()
            ----OptionsFrame:UpdatePreview()
            --|traceCfg("OUT dropdown:changeHandler("..(selectedID or "nil")..").")
        end
    )

    -- Add the items.
    ShapeDropDown_AddLines(dropdown)

    -- Set dropdown's text to the selected shape.
    if (PlayerConfig.ShapeFileName == nil or PlayerConfig.ShapeFileName == "") then
        dropdown:SelectIndex(1)  -- Select first item in the dropdown.
    else
        dropdown:SelectID( PlayerConfig.ShapeFileName )
        if (dropdown:GetSelectedID() == nil) then
            -- The previously selected texture no longer exists!  Clear it.
            ShapeTexture:SetTexture(nil)  -- Clear current (invalid) texture.
            dropdown:SelectIndex(1)  -- Select first item in the dropdown.
        end
    end

    -- Make mouse wheel over the collapsed dropdown change its selection.
    dropdown:SetScript("OnMouseWheel", function(self, delta)
                --|traceCfg("IN ShapeDropDown:OnMouseWheel().")
                self:HideSelections()  -- i.e. CloseDropDownMenus()
                OptionsFrame_IncrDecrShape(delta)
                --|traceCfg("OUT ShapeDropDown:OnMouseWheel().")
            end)

    -- Make right-clicks set the control's default value (or revert to previous selection).
    dropdown.buttonFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    dropdown.buttonFrame:SetScript("OnMouseUp", OptionsFrame_DropDown_OnButtonUp)

    --|traceCfg("OUT OptionsFrame_CreateShapeDropDown().")
    return dropdown
end

--------------------------------------------------------------------------------
function OptionsFrame_CreateStrataDropDown(x, y, width)
    --|traceCfg("IN OptionsFrame_CreateStrataDropDown().")
    local dropdown = private.UDControls.CreateDropDown(OptionsFrame)
    dropdown:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x, y+7)
    dropdown:Configure(width / kDropdownListboxScale)
    ----dropdown:SetDynamicWheelSpeed(true)
    dropdown:SetListBoxHeight(ScreenH / kDropdownListboxScale)
    dropdown:GetListBoxFrame():SetScale( kDropdownListboxScale )
    dropdown:SetChangeHandler(
        function(self, selectedID)
            OptionsFrame_Value("strata", selectedID)
            OptionsFrame.ProfilesUI:OnValueChanged()

            CursorModel:SetFrameStrata(selectedID)
            if (ShadowTexture and kShadowStrataMatchesMain == true) then
                ShadowFrame:SetFrameStrata(selectedID)
            end
            if ShapeTexture then
                ShapeFrame:SetFrameStrata(selectedID)
            end
            ----print("Cursor model frame strata set to:", selectedID)
        end
    )
    dropdown:AddItem("Background", "BACKGROUND")
    dropdown:AddItem("Low", "LOW")
    dropdown:AddItem("Medium", "MEDIUM")
    dropdown:AddItem("High  (Default)", "HIGH")
    dropdown:AddItem("Dialog", "DIALOG")
    dropdown:AddItem("Fullscreen", "FULLSCREEN")
    dropdown:AddItem("Fullscreen Dialog", "FULLSCREEN_DIALOG")
    dropdown:AddItem("ToolTip  (Topmost)", "TOOLTIP")

    dropdown:SelectID( PlayerConfig.Strata )

    -- Make mouse wheel over the collapsed dropdown change its selection.
    dropdown:SetScript("OnMouseWheel", function(self, delta)
                --|traceCfg("IN StrataDropDown:OnMouseWheel().")
                self:HideSelections()  -- i.e. CloseDropDownMenus()
                OptionsFrame_IncrDecrStrata(delta)
                --|traceCfg("OUT StrataDropDown:OnMouseWheel().")
            end)

    ------ Make right-clicks set the control's default value (or revert to previous selection).
    ----dropdown.buttonFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ----dropdown.buttonFrame:SetScript("OnMouseUp", OptionsFrame_DropDown_OnButtonUp)
    dropdown.buttonFrame:SetScript("OnMouseUp", function(self, mouseButton)
                PlaySound(private.kSound.ActionQuiet)
            end)

    --|traceCfg("OUT OptionsFrame_CreateStrataDropDown().")
    return dropdown
end

-------------------------------------------------------------------------------
function OptionsFrame_IncrDecrModel(delta)
    --|traceCfg("IN OptionsFrame_IncrDecrModel().")
    local dropdown = OptionsFrame.ModelDropDown
    local selectedModelID = dropdown:GetSelectedID()
    local prevID = nil
    local bUseNextID = false

    for index, modelData in pairs(kSortedModelChoices) do
        if (bUseNextID == true) then
            dropdown:SelectID(modelData.sortedID)
            dropdown:changeHandler(modelData.sortedID)
            PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)  -- Click sound.
            --|traceCfg("OUT OptionsFrame_IncrDecrModel(), early 1.")
            return  -- Done.
        elseif (modelData.sortedID == selectedModelID) then
            if (delta < 0) then -- Increment selection.
                bUseNextID = true
            else -- Decrement selection.
                if prevID then
                    dropdown:SelectID(prevID)
                    dropdown:changeHandler(prevID)
                    PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)  -- Click sound.
                end
                --|traceCfg("OUT OptionsFrame_IncrDecrModel(), early 2.")
                return  -- Done.
            end
        else
            prevID = modelData.sortedID
        end
    end

    --|traceCfg("OUT OptionsFrame_IncrDecrModel().")
end

-------------------------------------------------------------------------------
function OptionsFrame_IncrDecrShape(delta)
    --|traceCfg("IN OptionsFrame_IncrDecrShape().")
    local dropdown = OptionsFrame.ShapeDropDown
    local selectedIndex = dropdown:GetSelectedIndex()

    if (delta < 0) then -- Increment selection.
        if (selectedIndex < dropdown:GetNumItems()) then
            selectedIndex = selectedIndex + 1
        else
            --|traceCfg("OUT OptionsFrame_IncrDecrShape(), early 1.")
            return  -- Done.
        end
    else -- Decrement selection.
        if (selectedIndex > 1) then
            selectedIndex = selectedIndex - 1
        else
            --|traceCfg("OUT OptionsFrame_IncrDecrShape(), early 2.")
            return  -- Done.
        end
    end

    dropdown:SelectIndex(selectedIndex)
    dropdown:changeHandler( dropdown.itemIDs[selectedIndex] )
    PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)  -- Click sound.
    --|traceCfg("OUT OptionsFrame_IncrDecrShape().")
end

-------------------------------------------------------------------------------
function OptionsFrame_IncrDecrStrata(delta)
    --|traceCfg("IN OptionsFrame_IncrDecrStrata().")
    local dropdown = OptionsFrame.StrataDropDown
    local selectedIndex = dropdown:GetSelectedIndex()

    if (delta < 0) then -- Increment selection.
        if (selectedIndex < dropdown:GetNumItems()) then
            selectedIndex = selectedIndex + 1
        else
            --|traceCfg("OUT OptionsFrame_IncrDecrStrata(), early 1.")
            return  -- Done.
        end
    else -- Decrement selection.
        if (selectedIndex > 1) then
            selectedIndex = selectedIndex - 1
        else
            --|traceCfg("OUT OptionsFrame_IncrDecrStrata(), early 2.")
            return  -- Done.
        end
    end

    dropdown:SelectIndex(selectedIndex)
    dropdown:changeHandler( dropdown.itemIDs[selectedIndex] )
    PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)  -- Click sound.
    --|traceCfg("OUT OptionsFrame_IncrDecrStrata().")
end

-------------------------------------------------------------------------------
function OptionsFrame_SetModified(bModified) OptionsFrame.modified = bModified end
function OptionsFrame_IsModified() return OptionsFrame.modified end

--- End of File ---