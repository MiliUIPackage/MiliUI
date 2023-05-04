--[[---------------------------------------------------------------------------
    Addon:  CursorTrail
    File:   CursorTrailConfig.lua
    Desc:   Functions and variables for showing this addon's configuration options.
-----------------------------------------------------------------------------]]
                   
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Saved (Persistent) Variables                      ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

CursorTrail_PlayerConfig = CursorTrail_PlayerConfig or {}

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Aliases to Globals                                ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

local Globals = _G
local _  -- Prevent tainting global _ .
local assert = _G.assert
local CopyTable = _G.CopyTable
local CreateFrame = _G.CreateFrame
local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME
local IsAltKeyDown = _G.IsAltKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsShiftKeyDown = _G.IsShiftKeyDown
local pairs = _G.pairs
local PlaySound = _G.PlaySound
local print = _G.print
local SOUNDKIT = _G.SOUNDKIT
local string = _G.string
local table = _G.table
local tonumber = _G.tonumber
local tostring = _G.tostring
local UIParent = _G.UIParent
local UnitAffectingCombat = _G.UnitAffectingCombat

local GameMenuFrame = _G.GameMenuFrame
local HideUIPanel = _G.HideUIPanel
local InterfaceOptions_AddCategory = _G.InterfaceOptions_AddCategory
local InterfaceOptionsFrame_OpenToCategory = _G.InterfaceOptionsFrame_OpenToCategory
local InterfaceOptionsFrameCancel_OnClick = _G.InterfaceOptionsFrameCancel_OnClick
local InterfaceOptionsFrame = _G.InterfaceOptionsFrame

--~ local WorldFrame = _G.WorldFrame
local CloseDropDownMenus = _G.CloseDropDownMenus
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_SetButtonWidth = _G.UIDropDownMenu_SetButtonWidth
local UIDropDownMenu_JustifyText = _G.UIDropDownMenu_JustifyText

----local UIDropDownMenu_GetText = _G.UIDropDownMenu_GetText
----local UIDropDownMenuButton_GetChecked = _G.UIDropDownMenuButton_GetChecked
----local UIDropDownMenu_EnableDropDown = _G.UIDropDownMenu_EnableDropDown
----local UIDropDownMenu_DisableDropDown = _G.UIDropDownMenu_DisableDropDown

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

kTraceConfig = false  -- Set to true to trace entry/exit of functions in this file.

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                       Constants                                         ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

kButtonTemplate = ((kGameTocVersion >= 100000) and "UIPanelButtonTemplate") or "OptionsButtonTemplate"

kFrameWidth = 440
kFrameHeaderWidth = 350
kFrameHeaderHeight = 56
kFrameMargin = 18
kTopMargin = 26
kRowHeight = 16
kRowSpacing = 16
kBtnWidth = 96
kBtnHeight = 22
kButtonSpacing = 4
kColumnWidth1 = 76  -- Width of the labels column.
kColumnWidth2 = kFrameWidth-(kFrameMargin*2)-kColumnWidth1-kBtnWidth-30  -- Width of values column.
kDropdownListboxScale = 0.95

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                     StandardPanel Functions                             ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function traceCfg(msg)
    if (kTraceConfig == true) then print("|c0080ff80"..msg) end
end

-- THIS FUNCTION IS NOT WORKING RIGHT IN DRAGONFLIGHT!
--~ -------------------------------------------------------------------------------
--~ function StandardPanel_Create(buttonText, buttonW, buttonH)
--~     traceCfg("IN StandardPanel_Create().")
--~     if StandardPanel then traceCfg("OUT StandardPanel_Create(), early 1."); return; end  -- Return now if it already exists.

--~     assert(buttonText)
--~     buttonW = buttonW or 150
--~     buttonH = buttonH or 28

--~     -- Create a simple frame with a single button that opens the addon's options.
--~     -- Use this frame in the standard WoW UI.
--~     -- NOTE: This addon's options were not implemented in the standard UI because
--~     --       Blizzard has some bugs preventing editboxes from showing their values
--~     --       the first time.
--~     StandardPanel = CreateFrame("frame", kAddonName.."StandardPanel", UIParent)
--~     StandardPanel.name = kAddonName  -- The addon name that appears in the standard WoW UI.

--~     local headingText = StandardPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
--~     headingText:SetPoint("TOPLEFT", 16, -16)
--~     headingText:SetText(kAddonName.."  "..kAddonVersion)

--~     local optionsBtn = CreateFrame("Button", nil, StandardPanel, "UIPanelButtonTemplate")
--~     optionsBtn:SetPoint("CENTER")
--~     optionsBtn:SetSize(buttonW, buttonH)
--~     optionsBtn:SetText(buttonText)

--~     optionsBtn:SetScript("OnClick", function(self)
--~         InterfaceOptionsFrameCancel_OnClick()  -- Close the standard WoW addons UI.
--~         HideUIPanel(GameMenuFrame)  -- Close the main WoW menu.
--~         OptionsFrame:Show()  -- Show this addon's config UI.
--~     end)

--~     -- Adds this top level panel to the Interface Options.
--~     InterfaceOptions_AddCategory(StandardPanel)
--~     traceCfg("OUT StandardPanel_Create().")
--~ end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                     OptionsFrame Functions                              ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function OptionsFrame_Create()
    traceCfg("IN OptionsFrame_Create().")
    if OptionsFrame then traceCfg("OUT OptionsFrame_Create(), early 1."); return; end  -- Return now if it already exists.

    local frameName = kAddonName.."OptionsFrame"
    OptionsFrame = CreateFrame("frame", frameName, UIParent, "BackdropTemplate")
    Globals.tinsert(Globals.UISpecialFrames, frameName) -- Allow options frame to close via ESCAPE key.

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
    OptionsFrame.modified = false
    OptionsFrame.OriginalConfig = nil

    -- WINDOW HEADER BOX:
    OptionsFrame.HeaderTexture = OptionsFrame:CreateTexture(nil, "ARTWORK")
    OptionsFrame.HeaderTexture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    OptionsFrame.HeaderTexture:SetWidth(kFrameHeaderWidth)
    OptionsFrame.HeaderTexture:SetHeight(kFrameHeaderHeight)
    OptionsFrame.HeaderTexture:SetPoint("TOP", OptionsFrame, "TOP", 0, 12)

    OptionsFrame.HeaderText = OptionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    OptionsFrame.HeaderText:SetPoint("TOP", OptionsFrame.HeaderTexture, "TOP", 0, -11)
    OptionsFrame.HeaderText:SetText(kAddonName.."  "..kAddonVersion)

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

    -------------------------
    -- - - - WIDGETS - - - --
    -------------------------
    local xPos = kFrameMargin
    local yPos = -kFrameMargin - kTopMargin

    -- DEFAULT BUTTON 1 --
    local defaultsBtnHeight = kBtnHeight - 4
    OptionsFrame.DefaultsBtn1 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn1:SetText("預設 1")
    OptionsFrame.DefaultsBtn1:SetPoint("TOPRIGHT", OptionsFrame, "TOPRIGHT", -kFrameMargin, -kTopMargin-kButtonSpacing+2)
    OptionsFrame.DefaultsBtn1:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn1:SetScript("OnClick", OptionsFrame_OnDefaults)

    -- DEFAULT BUTTON 2 --
    OptionsFrame.DefaultsBtn2 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn2:SetText("預設 2")
    OptionsFrame.DefaultsBtn2:SetPoint("TOP", OptionsFrame.DefaultsBtn1, "BOTTOM", 0, -kButtonSpacing)
    OptionsFrame.DefaultsBtn2:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn2:SetScript("OnClick", OptionsFrame_OnDefaults)

    -- DEFAULT BUTTON 3 --
    OptionsFrame.DefaultsBtn3 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn3:SetText("預設 3")
    OptionsFrame.DefaultsBtn3:SetPoint("TOP", OptionsFrame.DefaultsBtn2, "BOTTOM", 0, -kButtonSpacing)
    OptionsFrame.DefaultsBtn3:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn3:SetScript("OnClick", OptionsFrame_OnDefaults)

    -- DEFAULT BUTTON 4 --
    OptionsFrame.DefaultsBtn4 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn4:SetText("預設 4")
    OptionsFrame.DefaultsBtn4:SetPoint("TOP", OptionsFrame.DefaultsBtn3, "BOTTOM", 0, -kButtonSpacing)
    OptionsFrame.DefaultsBtn4:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn4:SetScript("OnClick", OptionsFrame_OnDefaults)
    
    -- DEFAULT BUTTON 5 --
    OptionsFrame.DefaultsBtn5 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn5:SetText("預設 5")
    OptionsFrame.DefaultsBtn5:SetPoint("TOP", OptionsFrame.DefaultsBtn4, "BOTTOM", 0, -kButtonSpacing)
    OptionsFrame.DefaultsBtn5:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn5:SetScript("OnClick", OptionsFrame_OnDefaults)

    -- DEFAULT BUTTON 6 --
    OptionsFrame.DefaultsBtn6 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn6:SetText("預設 6")
    OptionsFrame.DefaultsBtn6:SetPoint("TOP", OptionsFrame.DefaultsBtn5, "BOTTOM", 0, -kButtonSpacing)
    OptionsFrame.DefaultsBtn6:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn6:SetScript("OnClick", OptionsFrame_OnDefaults)
    
    -- DEFAULT BUTTON 7 --
    OptionsFrame.DefaultsBtn7 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn7:SetText("預設 7")
    OptionsFrame.DefaultsBtn7:SetPoint("TOP", OptionsFrame.DefaultsBtn6, "BOTTOM", 0, -kButtonSpacing)
    OptionsFrame.DefaultsBtn7:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn7:SetScript("OnClick", OptionsFrame_OnDefaults)

    -- DEFAULT BUTTON 8 --
    OptionsFrame.DefaultsBtn8 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn8:SetText("預設 8")
    OptionsFrame.DefaultsBtn8:SetPoint("TOP", OptionsFrame.DefaultsBtn7, "BOTTOM", 0, -kButtonSpacing)
    OptionsFrame.DefaultsBtn8:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn8:SetScript("OnClick", OptionsFrame_OnDefaults)
    
    -- DEFAULT BUTTON 9 --
    OptionsFrame.DefaultsBtn9 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn9:SetText("預設 9")
    OptionsFrame.DefaultsBtn9:SetPoint("TOP", OptionsFrame.DefaultsBtn8, "BOTTOM", 0, -kButtonSpacing)
    OptionsFrame.DefaultsBtn9:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn9:SetScript("OnClick", OptionsFrame_OnDefaults)
    
    -- DEFAULT BUTTON 10 --
    OptionsFrame.DefaultsBtn10 = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.DefaultsBtn10:SetText("預設 10")
    OptionsFrame.DefaultsBtn10:SetPoint("TOP", OptionsFrame.DefaultsBtn9, "BOTTOM", 0, -kButtonSpacing)
    OptionsFrame.DefaultsBtn10:SetSize(kBtnWidth, defaultsBtnHeight)
    OptionsFrame.DefaultsBtn10:SetScript("OnClick", OptionsFrame_OnDefaults)
    
    -- CANCEL BUTTON --
    OptionsFrame.CancelBtn = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.CancelBtn:SetText("取消")
    OptionsFrame.CancelBtn:SetPoint("BOTTOMRIGHT", OptionsFrame, "BOTTOMRIGHT", -kFrameMargin, kFrameMargin)
    OptionsFrame.CancelBtn:SetSize(kBtnWidth, kBtnHeight+2)
    OptionsFrame.CancelBtn:SetScript("OnClick", OptionsFrame_OnCancel)

    -- OKAY BUTTON --
    OptionsFrame.OkayBtn = CreateFrame("Button", nil, OptionsFrame, kButtonTemplate)
    OptionsFrame.OkayBtn:SetText("Okay")
    OptionsFrame.OkayBtn:SetPoint("RIGHT", OptionsFrame.CancelBtn, "LEFT", -kButtonSpacing, 0)
    OptionsFrame.OkayBtn:SetSize(kBtnWidth, kBtnHeight+2)
    OptionsFrame.OkayBtn:SetScript("OnClick", OptionsFrame_OnOK)

    -- MODEL --
    OptionsFrame.ModelLabel = OptionsFrame_CreateLabel("模組:", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.ModelDropDown = OptionsFrame_CreateModelDropDown(xPos, yPos, kColumnWidth2)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- SCALE --
    OptionsFrame.ScaleLabel = OptionsFrame_CreateLabel("縮放 (%):", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.ScaleEditBox = OptionsFrame_CreateEditBox(xPos, yPos, nil, 3, true)
    OptionsFrame.ScaleEditBox:SetScript("OnTextChanged", OptionsFrame_OnValueChanged)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- OFFSETS --
    OptionsFrame.OffsetLabel = OptionsFrame_CreateLabel("偏移:", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    -- X
    OptionsFrame.OfsXEditBox = OptionsFrame_CreateEditBox(xPos, yPos, 42)
    OptionsFrame.OfsXEditBox:SetScript("OnTextChanged", OptionsFrame_OnValueChanged)
    xPos = xPos + OptionsFrame.OfsXEditBox:GetWidth() + 12  -- Next column.
    -- Y
    OptionsFrame.OfsYEditBox = OptionsFrame_CreateEditBox(xPos, yPos, 42)
    OptionsFrame.OfsYEditBox:SetScript("OnTextChanged", OptionsFrame_OnValueChanged)
    
    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing
    
    -- OPACITY --
    OptionsFrame.AlphaLabel = OptionsFrame_CreateLabel("透明度 (%):", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.AlphaEditBox = OptionsFrame_CreateEditBox(xPos, yPos, nil, 3, true)
    OptionsFrame.AlphaEditBox:SetScript("OnTextChanged", OptionsFrame_OnAlphaChanged)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- TAB ORDER --
    OptionsFrame_TabOrder = { OptionsFrame.ScaleEditBox, OptionsFrame.OfsXEditBox,
                              OptionsFrame.OfsYEditBox, OptionsFrame.AlphaEditBox }
    
    -- STRATA LEVEL --
    OptionsFrame.StrataLabel = OptionsFrame_CreateLabel("Strata:", xPos, yPos)
    xPos = xPos + kColumnWidth1  -- Next column.
    OptionsFrame.StrataDropDown = OptionsFrame_CreateStrataDropDown(xPos, yPos, kColumnWidth2*0.8)
      
    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- SHADOW --
    if ShadowFrame then
        OptionsFrame.ShadowLabel = OptionsFrame_CreateLabel("陰影 (%):", xPos, yPos)
        xPos = xPos + kColumnWidth1  -- Next column.
        OptionsFrame.ShadowEditBox = OptionsFrame_CreateEditBox(xPos, yPos, nil, 3, true)
        OptionsFrame.ShadowEditBox:SetScript("OnTextChanged", OptionsFrame_OnShadowChanged)
    
        -- Next row.
        xPos = kFrameMargin
        yPos = yPos - kRowHeight - kRowSpacing

        -- TAB ORDER --
        OptionsFrame_TabOrder = { OptionsFrame.ScaleEditBox, OptionsFrame.OfsXEditBox,
                                  OptionsFrame.OfsYEditBox, OptionsFrame.AlphaEditBox,
                                  OptionsFrame.ShadowEditBox }
    end
    
    -- FADE OUT --
    OptionsFrame.FadeCheckbox = OptionsFrame_CreateCheckBox("閒置時淡出.", xPos, yPos, "FadeCheckbox")
	OptionsFrame.FadeCheckbox:SetScript('PostClick', function(self, button)
        traceCfg("IN FadeCheckbox:PostClick().")
        CursorModel_SetFadeOut( self:GetChecked() )
        traceCfg("OUT FadeCheckbox:PostClick().")
    end)

    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing
    
    -- SHOW ONLY IN COMBAT --
    OptionsFrame.CombatCheckbox = OptionsFrame_CreateCheckBox("只在戰鬥中顯示.", xPos, yPos, "CombatCheckbox")
    
    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- SHOW DURING MOUSELOOK --
    OptionsFrame.MouseLookCheckbox = OptionsFrame_CreateCheckBox("在滑鼠查找期間顯示。", xPos, yPos, "MouseLookCheckbox")
    
    -- Next row.
    xPos = kFrameMargin
    yPos = yPos - kRowHeight - kRowSpacing

    -- TIP --
    OptionsFrame.TipText = OptionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    OptionsFrame.TipText:ClearAllPoints()
    OptionsFrame.TipText:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", xPos-2, yPos)
    OptionsFrame.TipText:SetPoint("RIGHT", -kFrameMargin, 0)
    OptionsFrame.TipText:SetText("* 提示: 你可以使用滑鼠滾輪或上/下鍵來改變數值。")

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
        develWarning:SetText("***** WARNING - BASE VALUE EDITING KEYS ARE ENABLED! *****")
        
        centerFrame = CreateFrame("Frame", nil, OptionsFrame) 
        centerFrame:SetPoint("CENTER", UIParent, "CENTER")
        centerFrame:SetSize(32, 32)
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
        centerPoint:SetSize(4, 4)
        
        local function onKeyDown_ChangeBaseVals(self, key)
            traceCfg("IN onKeyDown_ChangeBaseVals("..(self:GetName() or "nil")..", "..(key or "nil")..")")
            local bPassKeyToParent = false
            
            if key == "ESCAPE" then 
                OptionsFrame_OnOK()
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
            else OptionsFrame:SetPropagateKeyboardInput(false) end
            
            traceCfg("OUT onKeyDown_ChangeBaseVals("..(self:GetName() or "nil")..", "..(key or "nil")..")")
        end
        OptionsFrame:SetScript("OnKeyDown", onKeyDown_ChangeBaseVals)
    end
    
--~     -- Make clicking anywhere outside a dropdown menu close it.
--~     if not bWorldFrame_OnMouseDown_CloseDropDownMenus then
--~         WorldFrame:HookScript("OnMouseDown", function() CloseDropDownMenus() end)      
--~         bWorldFrame_OnMouseDown_CloseDropDownMenus = true
--~     end

    traceCfg("OUT OptionsFrame_Create().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnShow()
    traceCfg("IN OptionsFrame_OnShow().")
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    OptionsFrame.OriginalConfig = CopyTable(PlayerConfig)
    OptionsFrame_UpdateUI( OptionsFrame.OriginalConfig )
    OptionsFrame.modified = false

    CursorModel_Show()  -- Show the cursor model while the options window is open.
    traceCfg("OUT OptionsFrame_OnShow().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnHide()
    traceCfg("IN OptionsFrame_OnHide().")
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    if (OptionsFrame.modified == true) then
        -- Revert to previous config.
        PlayerConfig = CopyTable( OptionsFrame.OriginalConfig )
        CursorModel_Load( PlayerConfig )
        OptionsFrame.modified = false
    end

    OptionsFrame.OriginalConfig = table.wipe(OptionsFrame.OriginalConfig)  -- Free memory.
    if (PlayerConfig.UserShowOnlyInCombat == true and not UnitAffectingCombat("player")) then
        -- Not in combat so hide the cursor model.
        CursorModel_Hide()
    end
    traceCfg("OUT OptionsFrame_OnHide().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnKeyDown(self, key)
    traceCfg("IN OptionsFrame_OnKeyDown("..(self:GetName() or "nil")..", "..(key or "nil")..").")
    if not OptionsFrame:IsShown() then traceCfg("OUT OptionsFrame_OnKeyDown(), early 1."); return; end
    local bPassKeyToParent = false
    
    if key == "TAB" then OptionsFrame_FocusNext()
    else bPassKeyToParent = true
    end
    
    OptionsFrame:SetPropagateKeyboardInput(bPassKeyToParent)
    traceCfg("OUT OptionsFrame_OnKeyDown("..(self:GetName() or "nil")..", "..(key or "nil")..").")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnOK()
    traceCfg("IN OptionsFrame_OnOK().")
    if (OptionsFrame.modified == true) then
        -- Store changes into PlayerConfig and save them.
        PlayerConfig.ModelID    = OptionsFrame_Value("model")
        PlayerConfig.Strata     = OptionsFrame_Value("strata")
        PlayerConfig.UserScale  = OptionsFrame_Value("scale")
        PlayerConfig.UserOfsX   = OptionsFrame_Value("OfsX")
        PlayerConfig.UserOfsY   = OptionsFrame_Value("OfsY")
        PlayerConfig.UserAlpha  = OptionsFrame_Value("alpha")
        PlayerConfig.UserShadowAlpha = OptionsFrame_Value("shadow")
        PlayerConfig.UserShowOnlyInCombat = OptionsFrame_Value("combat")
        PlayerConfig.UserShowMouseLook = OptionsFrame_Value("MouseLook")
        PlayerConfig.FadeOut    = OptionsFrame_Value("fade")
        CursorModel_SetFadeOut(PlayerConfig.FadeOut)
        PlayerConfig_Save()

        CursorModel_Load(PlayerConfig)
        OptionsFrame.modified = false
    end

    OptionsFrame:Hide()
    traceCfg("OUT OptionsFrame_OnOK().")    
end

-------------------------------------------------------------------------------
function OptionsFrame_OnCancel()
    traceCfg("IN OptionsFrame_OnCancel().")
    OptionsFrame:Hide()
    traceCfg("OUT OptionsFrame_OnCancel().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnDefaults(self)
    traceCfg("IN OptionsFrame_OnDefaults("..(self:GetName() or "nil")..").")
    local btnName = self:GetText()
    local bShowCombat = OptionsFrame_Value("combat")  -- Preserve this setting.
    local bShowMouseLook = OptionsFrame_Value("MouseLook")  -- Preserve this setting.
    
    PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
    if btnName:find("10") then
        PlayerConfig = CopyTable(kDefaultConfig10)
    elseif btnName:find("9") then
        PlayerConfig = CopyTable(kDefaultConfig9)
    elseif btnName:find("8") then
        PlayerConfig = CopyTable(kDefaultConfig8)
    elseif btnName:find("7") then
        PlayerConfig = CopyTable(kDefaultConfig7)
    elseif btnName:find("6") then
        PlayerConfig = CopyTable(kDefaultConfig6)
    elseif btnName:find("5") then
        PlayerConfig = CopyTable(kDefaultConfig5)
    elseif btnName:find("4") then
        PlayerConfig = CopyTable(kDefaultConfig4)
    elseif btnName:find("3") then
        PlayerConfig = CopyTable(kDefaultConfig3)
    elseif btnName:find("2") then
        PlayerConfig = CopyTable(kDefaultConfig2)
    else -- 1
        PlayerConfig = CopyTable(kDefaultConfig)
    end
    
    PlayerConfig.UserShowOnlyInCombat = bShowCombat
    PlayerConfig.UserShowMouseLook = bShowMouseLook
    PlayerConfig_Save()
    
    CursorModel_Load(PlayerConfig)
    CursorModel_Show()
    OptionsFrame_UpdateUI(PlayerConfig)
    OptionsFrame.modified = true
    OptionsFrame_ClearFocus()
    traceCfg("OUT OptionsFrame_OnDefaults("..(self:GetName() or "nil")..").")
end

-------------------------------------------------------------------------------
function OptionsFrame_EditBox_OnKeyDown(self, key)
    traceCfg("IN OptionsFrame_EditBox_OnKeyDown("..(self:GetName() or "nil")..", "..(key or "nil")..").")
    if key == "/" or key == "`" then
        self:SetPropagateKeyboardInput(true) -- Pass this key to parent.
    else
        self:SetPropagateKeyboardInput(false) -- Don't pass this key to parent.
        
        if key == "TAB" then OptionsFrame_FocusNext()
        ----elseif key == "ESCAPE" then OptionsFrame:Hide()
        ----elseif key == "ENTER" then OptionsFrame_ClearFocus()
        elseif key == "UP" then OptionsFrame_IncrDecrValue(self, 1)
        elseif key == "DOWN" then OptionsFrame_IncrDecrValue(self, -1)
        end
    end
    traceCfg("OUT OptionsFrame_EditBox_OnKeyDown("..(self:GetName() or "nil")..", "..(key or "nil")..").")
end

-------------------------------------------------------------------------------
function OptionsFrame_FocusNext()
    traceCfg("IN OptionsFrame_FocusNext().")
    local count = #OptionsFrame_TabOrder
    if IsShiftKeyDown() then  -- Previous control.
        for i = 2, count do 
            if OptionsFrame_TabOrder[i]:HasFocus() then
                traceCfg("OUT OptionsFrame_FocusNext(), early 1.")
                return OptionsFrame_TabOrder[i-1]:SetFocus()
            end
        end
        OptionsFrame_TabOrder[count]:SetFocus()
    else  -- Next control.
        for i = 1, count-1 do 
            if OptionsFrame_TabOrder[i]:HasFocus() then
                traceCfg("OUT OptionsFrame_FocusNext(), early 2.")
                return OptionsFrame_TabOrder[i+1]:SetFocus()
            end
        end
        OptionsFrame_TabOrder[1]:SetFocus()
    end
    traceCfg("OUT OptionsFrame_FocusNext().")
end

-------------------------------------------------------------------------------
function OptionsFrame_ClearFocus()
    traceCfg("IN OptionsFrame_ClearFocus().")
    if not OptionsFrame:IsShown() then return end
    local count = #OptionsFrame_TabOrder
    for i = 1, count do 
        if OptionsFrame_TabOrder[i]:HasFocus() then
            traceCfg("OUT OptionsFrame_ClearFocus(), early 1.")
            return OptionsFrame_TabOrder[i]:ClearFocus()
        end
    end
    traceCfg("OUT OptionsFrame_ClearFocus().")
end

-------------------------------------------------------------------------------
function OptionsFrame_IncrDecrValue(self, delta)
    traceCfg("IN OptionsFrame_IncrDecrValue("..(self:GetName() or "nil")..").")
    local num = tonumber(self:GetText()) or 0
    num = num + delta
    self:SetFocus()
    self:SetText(num)
    local handler = self:GetScript("OnTextChanged")
    if handler then handler(num, true) end
    self:HighlightText()
    ----self:SetCursorPosition(99)
    traceCfg("OUT OptionsFrame_IncrDecrValue("..(self:GetName() or "nil")..").")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnValueChanged(frame, isUserInput)
    traceCfg("IN OptionsFrame_OnValueChanged().")
    ----local self, editbox = frame.obj, frame.obj.editbox
    if (isUserInput == true) then
        CursorModel_ApplyUserSettings( 
                    OptionsFrame_Value("scale"),
                    OptionsFrame_Value("OfsX"),
                    OptionsFrame_Value("OfsY"),
                    OptionsFrame_Value("alpha"),
                    OptionsFrame_Value("shadow") )
        OptionsFrame.modified = true
    end
    traceCfg("OUT OptionsFrame_OnValueChanged().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnAlphaChanged(frame, isUserInput)
    traceCfg("IN OptionsFrame_OnAlphaChanged().")
    ----local self, editbox = frame.obj, frame.obj.editbox
    if (isUserInput == true) then
        local alpha = OptionsFrame_Value("alpha")
        CursorModel:SetAlpha( alpha )
        PlayerConfig.UserAlpha = alpha  -- Required so changes are seen when motion fading is on.
        OptionsFrame.modified = true
    end
    traceCfg("OUT OptionsFrame_OnAlphaChanged().")
end

-------------------------------------------------------------------------------
function OptionsFrame_OnShadowChanged(frame, isUserInput)
    traceCfg("IN OptionsFrame_OnShadowChanged().")
    ----local self, editbox = frame.obj, frame.obj.editbox
    if (isUserInput == true) then
        local shadowAlpha = OptionsFrame_Value("shadow")
        ShadowTexture:SetAlpha( shadowAlpha )
        PlayerConfig.UserShadowAlpha = shadowAlpha  -- Required so changes are seen when motion fading is on.
        OptionsFrame.modified = true
    end
    traceCfg("OUT OptionsFrame_OnShadowChanged().")
end

-------------------------------------------------------------------------------
function OptionsFrame_UpdateUI(config)
    traceCfg("IN OptionsFrame_UpdateUI().")
    assert(config)
    
    -- Close any popup menus that are open.
    OptionsFrame.ModelDropDown:HideSelections()  
    OptionsFrame.StrataDropDown:HideSelections()
    
    -- Set UI.
    OptionsFrame_Value("model", config.ModelID)
    OptionsFrame_Value("Strata", config.Strata)
    OptionsFrame_Value("scale", config.UserScale)
    OptionsFrame_Value("OfsX", config.UserOfsX)
    OptionsFrame_Value("OfsY", config.UserOfsY)
    OptionsFrame_Value("alpha", config.UserAlpha)
    OptionsFrame_Value("shadow", config.UserShadowAlpha or 0)
    OptionsFrame_Value("combat", config.UserShowOnlyInCombat or false)
    OptionsFrame_Value("MouseLook", config.UserShowMouseLook or false)
    OptionsFrame_Value("fade", config.FadeOut or false)
    traceCfg("OUT OptionsFrame_UpdateUI().")
end

--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
--[[                OptionsFrame Helper Functions                            ]]
--:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

-------------------------------------------------------------------------------
function OptionsFrame_Value(valName, newVal)
-- Gets or sets a value in the options frame UI.
-- If only 'valName' is passed in, the specified value is returned.
-- If 'valName' and 'newVal' are both passed in, the specified value is set.
-- NOTE: This function can't be used to set a value to nil!
    traceCfg("IN OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil")..").")
    local retVal, editbox, minVal, maxVal, currVal
    local multiplier = 1

    valName = string.lower(valName)
    if (newVal ~= nil) then  -- SET
        OptionsFrame.modified = true
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
        traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early 1.")
        return retVal
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "mouselook") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.MouseLookCheckbox:GetChecked()
        else -- SET
            OptionsFrame.MouseLookCheckbox:SetChecked(newVal)
        end
        traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early 1.")
        return retVal
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "fade") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.FadeCheckbox:GetChecked()
        else -- SET
            OptionsFrame.FadeCheckbox:SetChecked(newVal)
        end
        traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early 2.")
        return retVal

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
            OptionsFrame.ModelDropDown:SetSelectedID( newVal )
        end
        traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early 3.")
        return retVal
    elseif (valName == "strata") then
        if (newVal == nil) then  -- GET
            retVal = OptionsFrame.StrataDropDown:GetSelectedID()
        else -- SET
            OptionsFrame.StrataDropDown:SetSelectedID( newVal )
        end
        traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil").."), early 4.")
        return retVal

    ----------------------------------
    -- EDITBOXES (must be last) ...
    -- - - - - - - - - - - - - - - - -
    elseif (valName == "scale") then
        editbox = OptionsFrame.ScaleEditBox
        minVal, maxVal = 0.01, 9.99  -- (1% to 999%)
        multiplier = 100
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
        currVal = (tonumber(editbox:GetText()) or 0) / multiplier 
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

    traceCfg("OUT OptionsFrame_Value("..valName..", "..(tostring(newVal) or "nil")..").")
    return retVal
end

-------------------------------------------------------------------------------
function OptionsFrame_CreateLabel(labelText, x, y, fontName)
    traceCfg("IN OptionsFrame_CreateLabel("..labelText..").")
    local labelFrame = OptionsFrame:CreateFontString(nil, "ARTWORK", fontName or "GameFontNormal")
    labelFrame:ClearAllPoints()
    labelFrame:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x, y)
    labelFrame:SetPoint("RIGHT", OptionsFrame, "LEFT", kFrameMargin+kColumnWidth1, 0)
    labelFrame:SetJustifyH("RIGHT")
    labelFrame:SetWordWrap(false)
    labelFrame:SetText(labelText)
    traceCfg("OUT OptionsFrame_CreateLabel("..labelText..").")
    return labelFrame
end

-------------------------------------------------------------------------------
function OptionsFrame_CreateEditBox(x, y, width, maxChars, bNumeric)
    traceCfg("IN OptionsFrame_CreateEditBox().")
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
        editboxFrame:SetNumeric(true)  -- Allows characters 0-9 only!
    end
    editboxFrame:SetScript("OnEnterPressed", OptionsFrame_OnOK)
    ----editboxFrame:SetScript("OnTabPressed", OptionsFrame_FocusNext)
    editboxFrame:SetScript("OnKeyDown", OptionsFrame_EditBox_OnKeyDown)
    editboxFrame:SetScript("OnEditFocusGained", function(self) self:HighlightText(); self:SetCursorPosition(99) end)
    editboxFrame:SetScript("OnMouseWheel", OptionsFrame_IncrDecrValue)
    
    traceCfg("OUT OptionsFrame_CreateEditBox().")
    return editboxFrame
end

-------------------------------------------------------------------------------
function OptionsFrame_CreateCheckBox(labelText, x, y, refName)
    traceCfg("IN OptionsFrame_CreateCheckBox("..refName..").")
    refName = kAddonName.."OptionsFrame"..refName
	local checkbox = CreateFrame("CheckButton", refName, OptionsFrame, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x+kFrameMargin+kColumnWidth1-17, y+7)
	checkbox:SetScript('OnClick', function(self) 
                    traceCfg("IN checkbox:OnClick("..(self:GetName() or "nil")..").")
                    OptionsFrame.modified = true
                    OptionsFrame_ClearFocus()
                    traceCfg("OUT checkbox:OnClick("..(self:GetName() or "nil")..").")
                end)

    ----Globals[refName.."Text"]:SetText( labelText )
    checkbox.label = OptionsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    checkbox.label:SetPoint("TOP", OptionsFrame, "TOP", 0, y)
    checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
    checkbox.label:SetPoint("RIGHT", OptionsFrame, "RIGHT", -kFrameMargin, 0)
    checkbox.label:SetJustifyH("LEFT")
    checkbox.label:SetWordWrap(false)
    checkbox.label:SetText(labelText)

    traceCfg("OUT OptionsFrame_CreateCheckBox("..refName..").")
    return checkbox
end

--------------------------------------------------------------------------------
function OptionsFrame_CreateModelDropDown(x, y, width)
    traceCfg("IN OptionsFrame_CreateModelDropDown().")
    local dropdown = Globals.CursorTrailControls.CreateDropdown(OptionsFrame)
    dropdown:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x, y+7)
    dropdown:Configure(width / kDropdownListboxScale)
    dropdown:SetListboxHeight(ScreenH / kDropdownListboxScale)
    dropdown.listbox:SetScale( kDropdownListboxScale )
    
    dropdown:SetChangeHandler( 
        function(self, selectedID)
            traceCfg("IN dropdown:changeHandler("..(selectedID or "nil")..").")
            OptionsFrame_Value("model", selectedID)
            
            -- Display the new model immediately.
            local tmpConfig = CopyTable( OptionsFrame.OriginalConfig )
            tmpConfig.UserShowOnlyInCombat = false -- Always show while Options Window is open.
            tmpConfig.ModelID   = selectedID
            tmpConfig.UserScale = OptionsFrame_Value("scale")
            tmpConfig.UserAlpha = OptionsFrame_Value("alpha")
            tmpConfig.Strata    = OptionsFrame_Value("strata")
            tmpConfig.UserShadowAlpha = OptionsFrame_Value("shadow")
            tmpConfig.UserOfsX  = OptionsFrame_Value("OfsX")
            tmpConfig.UserOfsY  = OptionsFrame_Value("OfsY")
            tmpConfig.FadeOut   = OptionsFrame_Value("fade")
            CursorModel_Load(tmpConfig)
            CursorModel_Show()
            traceCfg("OUT dropdown:changeHandler("..(selectedID or "nil")..").")
        end
    )
    
    -- Add the items.
    for _, modelData in pairs(kSortedModelChoices) do
        dropdown:AddItem(modelData.Name, modelData.sortedID)
    end

    -- Set dropdown's text to the selected model name.
    dropdown:SetSelectedID( PlayerConfig.ModelID )
    
    -- Make mouse wheel over the collapsed dropdown change its selection.
    dropdown:SetScript("OnMouseWheel", function(self, delta)
                traceCfg("IN ModelDropDown:OnMouseWheel().")
                OptionsFrame_IncrDecrModel(delta)
                traceCfg("OUT ModelDropDown:OnMouseWheel().")
            end)

    traceCfg("OUT OptionsFrame_CreateModelDropDown().")
    return dropdown
end

--------------------------------------------------------------------------------
function OptionsFrame_CreateStrataDropDown(x, y, width)
    traceCfg("IN OptionsFrame_CreateStrataDropDown().")
    local dropdown = Globals.CursorTrailControls.CreateDropdown(OptionsFrame)
    dropdown:SetPoint("TOPLEFT", OptionsFrame, "TOPLEFT", x, y+7)
    dropdown:Configure(width / kDropdownListboxScale)
    dropdown:SetListboxHeight(ScreenH / kDropdownListboxScale)
    dropdown.listbox:SetScale( kDropdownListboxScale )
    dropdown:SetChangeHandler( 
        function(self, selectedID)
            OptionsFrame_Value("strata", selectedID)
            CursorModel:SetFrameStrata(selectedID)
            if (kShadowStrataMatchesMain == true) then
                ShadowFrame:SetFrameStrata(selectedID)
            end
            ----print("Cursor model frame strata set to:", selectedID)
        end
    )
    dropdown:AddItem("Background", "BACKGROUND")
    dropdown:AddItem("Low", "LOW")
    dropdown:AddItem("Medium", "MEDIUM")
    dropdown:AddItem("High", "HIGH")
    dropdown:AddItem("Dialog", "DIALOG")
    dropdown:AddItem("Fullscreen", "FULLSCREEN")
    dropdown:AddItem("Fullscreen Dialog", "FULLSCREEN_DIALOG")
    dropdown:AddItem("ToolTip  (Topmost)", "TOOLTIP")
    
    dropdown:SetSelectedID( PlayerConfig.Strata )
    
    -- Make mouse wheel over the collapsed dropdown change its selection.
    dropdown:SetScript("OnMouseWheel", function(self, delta)
                traceCfg("IN StrataDropDown:OnMouseWheel().")
                OptionsFrame_IncrDecrStrata(delta)
                traceCfg("OUT StrataDropDown:OnMouseWheel().")
            end)
    
    traceCfg("OUT OptionsFrame_CreateStrataDropDown().")
    return dropdown
end

-------------------------------------------------------------------------------
function OptionsFrame_IncrDecrModel(delta)
    traceCfg("IN OptionsFrame_IncrDecrModel().")
    local dropdown = OptionsFrame.ModelDropDown
    local selectedModelID = dropdown:GetSelectedID()
    local prevID = nil
    local bUseNextID = false
    
    for index, modelData in pairs(kSortedModelChoices) do
        if (bUseNextID == true) then
            dropdown:SetSelectedID(modelData.sortedID)
            dropdown:changeHandler(modelData.sortedID)
            PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)  -- Click sound.
            traceCfg("OUT OptionsFrame_IncrDecrModel(), early 1.")
            return  -- Done.
        elseif (modelData.sortedID == selectedModelID) then
            if (delta < 0) then -- Increment selection.
                bUseNextID = true
            else -- Decrement selection.
                if prevID then 
                    dropdown:SetSelectedID(prevID) 
                    dropdown:changeHandler(prevID)
                    PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)  -- Click sound.
                end
                traceCfg("OUT OptionsFrame_IncrDecrModel(), early 2.")
                return  -- Done.
            end
        else
            prevID = modelData.sortedID
        end
    end
    
    traceCfg("OUT OptionsFrame_IncrDecrModel().")
end

-------------------------------------------------------------------------------
function OptionsFrame_IncrDecrStrata(delta)
    traceCfg("IN OptionsFrame_IncrDecrStrata().")
    local dropdown = OptionsFrame.StrataDropDown
    local selectedIndex = dropdown:GetSelectedIndex()

    if (delta < 0) then -- Increment selection.
        if (selectedIndex < dropdown:GetNumItems()) then 
            selectedIndex = selectedIndex + 1
        else 
            traceCfg("OUT OptionsFrame_IncrDecrStrata(), early 1.")
            return  -- Done.
        end
    else -- Decrement selection.
        if (selectedIndex > 1) then 
            selectedIndex = selectedIndex - 1
        else 
            traceCfg("OUT OptionsFrame_IncrDecrStrata(), early 2.")
            return  -- Done.
        end
    end

    dropdown:SetSelectedIndex(selectedIndex)
    dropdown:changeHandler( dropdown.itemIDs[selectedIndex] )
    PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)  -- Click sound.
    traceCfg("OUT OptionsFrame_IncrDecrStrata().")
end

--- End of File ---