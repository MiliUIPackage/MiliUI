-- Config/CastBar.lua - Cast Bar Settings Tab
-- Controls for player cast bar dimensions, text, textures, colors, and positioning

local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function CreateCastBarTab(page, tabId)
    local scrollChild = UI.CreateScrollableTab(page, "AyijeCDM_CastBarScrollFrame", 700, 370)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    -- =====================================================================
    --  ENABLE
    -- =====================================================================
    local enabled = CDM.db.castBarEnabled
    if enabled == nil then enabled = true end
    page.controls.castBarEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Cast Bar"],
        enabled,
        function(checked)
            CDM.db.castBarEnabled = checked
            API:RefreshConfig()
        end
    )
    page.controls.castBarEnabled:SetPoint("TOPLEFT", -34, NextY(0))

    local blizzHidden = CDM.db.hideBlizzardCastBar or false
    page.controls.hideBlizzardCastBar = UI.CreateModernCheckbox(
        scrollChild,
        L["Hide Blizzard Cast Bar"],
        blizzHidden,
        function(checked)
            CDM.db.hideBlizzardCastBar = checked
            API:RefreshConfig()
        end
    )
    page.controls.hideBlizzardCastBar:SetPoint("LEFT", page.controls.castBarEnabled, "RIGHT", 0, 0)
    NextY(35)

    -- =====================================================================
    --  DIMENSIONS
    -- =====================================================================
    local dimHeader = UI.CreateHeader(scrollChild, L["Dimensions"])
    dimHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    -- Width Slider (0 = auto-size to Essential row 1)
    page.controls.castBarWidthSlider = UI.CreateModernSlider(
        scrollChild,
        L["Width (0 = Auto)"],
        0, 600,
        CDM.db.castBarWidth or 300,
        function(v)
            local value = UI.RoundToInt(v)
            -- Enforce minimum of 60 when not 0
            if value > 0 and value < 60 then
                value = 60
                page.controls.castBarWidthSlider.Slider:SetValue(60)
            end
            CDM.db.castBarWidth = value
            API:RefreshConfig()
        end
    )
    page.controls.castBarWidthSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    -- Height Slider
    page.controls.castBarHeightSlider = UI.CreateModernSlider(
        scrollChild,
        L["Height"],
        8, 40,
        CDM.db.castBarHeight or 20,
        function(v)
            CDM.db.castBarHeight = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarHeightSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    -- =====================================================================
    --  SPELL ICON
    -- =====================================================================
    local iconHeader = UI.CreateHeader(scrollChild, L["Spell Icon"])
    iconHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    -- Show Spell Icon Checkbox
    local showIcon = CDM.db.castBarShowIcon or false
    page.controls.castBarShowIcon = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Spell Icon"],
        showIcon,
        function(checked)
            CDM.db.castBarShowIcon = checked
            API:RefreshConfig()
        end
    )
    page.controls.castBarShowIcon:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(35)

    -- Icon Position Dropdown
    local iconPosLabel = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    iconPosLabel:SetText(L["Icon Position:"])
    iconPosLabel:SetPoint("TOPLEFT", 0, NextY(0))

    local ddIconPos = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddIconPos:SetPoint("TOPLEFT", 0, NextY(20))
    ddIconPos:SetWidth(150)
    ddIconPos:SetDefaultText(CDM.db.castBarIconPosition or "LEFT")
    page.controls.castBarIconPositionDropdown = ddIconPos

    local iconPosOptions = {
        { value = "LEFT", label = L["Left"] },
        { value = "RIGHT", label = L["Right"] },
    }

    UI.SetupValueDropdown(
        ddIconPos,
        iconPosOptions,
        function() return CDM.db.castBarIconPosition or "LEFT" end,
        function(value)
            CDM.db.castBarIconPosition = value
            ddIconPos:SetDefaultText(value)
            API:RefreshConfig()
        end
    )
    NextY(50)

    -- Icon-Bar Gap Slider
    page.controls.castBarIconGapSlider = UI.CreateModernSlider(
        scrollChild,
        L["Icon-Bar Gap"],
        -1, 20,
        CDM.db.castBarIconGap or 1,
        function(v)
            CDM.db.castBarIconGap = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarIconGapSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    -- =====================================================================
    --  BAR TEXTURE
    -- =====================================================================
    local texHeader = UI.CreateHeader(scrollChild, L["Bar Texture"])
    texHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    -- Use Blizzard Atlas Textures Checkbox
    local useAtlas = CDM.db.castBarUseAtlasTextures
    if useAtlas == nil then useAtlas = true end
    page.controls.castBarUseAtlas = UI.CreateModernCheckbox(
        scrollChild,
        L["Use Blizzard Atlas Textures"],
        useAtlas,
        function(checked)
            CDM.db.castBarUseAtlasTextures = checked
            -- Show/hide LSM controls and reposition elements below
            local showLSM = not checked
            if page.castBarLSMGroup then
                page.castBarLSMGroup:SetShown(showLSM)
            end
            if page.castBarPositionHeader then
                page.castBarPositionHeader:ClearAllPoints()
                if showLSM then
                    page.castBarPositionHeader:SetPoint("TOPLEFT", page.castBarLSMGroup, "BOTTOMLEFT", 0, -10)
                else
                    page.castBarPositionHeader:SetPoint("TOPLEFT", page.controls.castBarUseAtlas, "BOTTOMLEFT", 0, -15)
                end
            end
            API:RefreshConfig()
        end
    )
    page.controls.castBarUseAtlas:SetPoint("TOPLEFT", 0, NextY(0))

    -- LSM controls group (shown when atlas is disabled)
    local lsmGroup = CreateFrame("Frame", nil, scrollChild)
    lsmGroup:SetSize(600, 310)
    lsmGroup:SetPoint("TOPLEFT", page.controls.castBarUseAtlas, "BOTTOMLEFT", 0, -10)
    page.castBarLSMGroup = lsmGroup

    local lsmUseAtlas = CDM.db.castBarUseAtlasTextures
    if lsmUseAtlas == nil then lsmUseAtlas = true end
    lsmGroup:SetShown(not lsmUseAtlas)

    local lsmLayout = UI.CreateVerticalLayout(0)
    local function LsmNextY(spacing) return lsmLayout:Next(spacing) end

    -- Bar Texture Dropdown
    local textureLabel = lsmGroup:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    textureLabel:SetText(L["Bar Texture:"])
    textureLabel:SetPoint("TOPLEFT", 0, LsmNextY(0))

    local ddTexture = CreateFrame("DropdownButton", nil, lsmGroup, "WowStyle1DropdownTemplate")
    ddTexture:SetPoint("TOPLEFT", 0, LsmNextY(20))
    ddTexture:SetWidth(220)
    ddTexture:SetDefaultText(CDM.db.castBarTexture or "Blizzard")
    page.controls.castBarTextureDropdown = ddTexture

    UI.SetupMediaDropdown(
        ddTexture,
        "statusbar",
        function() return CDM.db.castBarTexture or "Blizzard" end,
        function(name)
            CDM.db.castBarTexture = name
            API:RefreshConfig()
        end,
        function(name)
            ddTexture:SetDefaultText(name or "Blizzard")
        end
    )

    -- Background Texture Dropdown
    local bgTextureLabel = lsmGroup:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    bgTextureLabel:SetText(L["Background Texture:"])
    bgTextureLabel:SetPoint("TOPLEFT", 0, LsmNextY(50))

    local ddBgTexture = CreateFrame("DropdownButton", nil, lsmGroup, "WowStyle1DropdownTemplate")
    ddBgTexture:SetPoint("TOPLEFT", 0, LsmNextY(20))
    ddBgTexture:SetWidth(220)
    ddBgTexture:SetDefaultText(CDM.db.castBarBackgroundTexture or "Blizzard")
    page.controls.castBarBgTextureDropdown = ddBgTexture

    UI.SetupMediaDropdown(
        ddBgTexture,
        "statusbar",
        function() return CDM.db.castBarBackgroundTexture or "Blizzard" end,
        function(name)
            CDM.db.castBarBackgroundTexture = name
            API:RefreshConfig()
        end,
        function(name)
            ddBgTexture:SetDefaultText(name or "Blizzard")
        end
    )

    -- Background Color Swatch
    page.controls.castBarBackgroundColor = UI.CreateColorSwatch(lsmGroup, L["Background Color"], "castBarBackgroundColor")
    page.controls.castBarBackgroundColor:SetPoint("TOPLEFT", 0, LsmNextY(50))

    -- Cast Color Swatch
    page.controls.castBarCastColor = UI.CreateColorSwatch(lsmGroup, L["Cast Color"], "castBarCastColor")
    page.controls.castBarCastColor:SetPoint("TOPLEFT", 0, LsmNextY(40))

    -- Channel Color Swatch
    page.controls.castBarChannelColor = UI.CreateColorSwatch(lsmGroup, L["Channel Color"], "castBarChannelColor")
    page.controls.castBarChannelColor:SetPoint("TOPLEFT", 0, LsmNextY(40))

    -- Uninterruptible Color Swatch
    page.controls.castBarUninterruptibleColor = UI.CreateColorSwatch(lsmGroup, L["Uninterruptible Color"], "castBarUninterruptibleColor")
    page.controls.castBarUninterruptibleColor:SetPoint("TOPLEFT", 0, LsmNextY(40))

    -- =====================================================================
    --  POSITION (anchored dynamically based on LSM group visibility)
    -- =====================================================================
    local posHeader = UI.CreateHeader(scrollChild, L["Position"])
    page.castBarPositionHeader = posHeader
    if not lsmUseAtlas then
        posHeader:SetPoint("TOPLEFT", lsmGroup, "BOTTOMLEFT", 0, -10)
    else
        posHeader:SetPoint("TOPLEFT", page.controls.castBarUseAtlas, "BOTTOMLEFT", 0, -15)
    end

    -- Anchor to Resource Bars Checkbox
    local anchorToRes = CDM.db.castBarAnchorToResources or false
    page.controls.castBarAnchorToResources = UI.CreateModernCheckbox(
        scrollChild,
        L["Anchor to Resource Bars"],
        anchorToRes,
        function(checked)
            CDM.db.castBarAnchorToResources = checked
            if checked then
                CDM.db.castBarContainerLocked = true
                if page.controls.castBarLocked and page.controls.castBarLocked.SetChecked then
                    page.controls.castBarLocked:SetChecked(true)
                end
            end
            page.UpdatePositionControls()
            API:RefreshConfig()
        end
    )
    page.controls.castBarAnchorToResources:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -15)

    local function UpdateAnchorToResourcesCheckboxState()
        local resourcesEnabled = CDM.db.resourcesEnabled ~= false
        if page.controls.castBarAnchorToResources and page.controls.castBarAnchorToResources.SetChecked then
            page.controls.castBarAnchorToResources:SetChecked(CDM.db.castBarAnchorToResources == true)
        end
        if page.controls.castBarAnchorToResources and page.controls.castBarAnchorToResources.checkbox then
            page.controls.castBarAnchorToResources.checkbox:SetEnabled(resourcesEnabled)
        end
        if page.controls.castBarAnchorToResources then
            page.controls.castBarAnchorToResources:SetAlpha(resourcesEnabled and 1 or 0.5)
        end
    end

    -- Resources Spacing Slider (shown when anchor-to-resources is ON)
    page.controls.castBarResourcesSpacingSlider = UI.CreateModernSlider(
        scrollChild,
        L["Y Spacing"],
        -1, 20,
        CDM.db.castBarResourcesSpacing or 2,
        function(v)
            CDM.db.castBarResourcesSpacing = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarResourcesSpacingSlider:SetPoint("TOPLEFT", page.controls.castBarAnchorToResources, "BOTTOMLEFT", 0, -10)

    -- Lock Position Checkbox (shown when anchor-to-resources is OFF)
    local locked = CDM.db.castBarContainerLocked
    if locked == nil then locked = true end
    page.controls.castBarLocked = UI.CreateModernCheckbox(
        scrollChild,
        L["Lock Position"],
        locked,
        function(checked)
            CDM.db.castBarContainerLocked = checked
            API:RefreshConfig()
        end
    )
    page.controls.castBarLocked:SetPoint("TOPLEFT", page.controls.castBarAnchorToResources, "BOTTOMLEFT", 0, -10)

    -- X Offset Slider (shown when anchor-to-resources is OFF)
    page.controls.castBarOffsetXSlider = UI.CreateModernSlider(
        scrollChild,
        L["X Offset"],
        -800, 800,
        CDM.db.castBarOffsetX or 0,
        function(v)
            CDM.db.castBarOffsetX = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarOffsetXSlider:SetPoint("TOPLEFT", page.controls.castBarLocked, "BOTTOMLEFT", 0, -10)

    -- Y Offset Slider (shown when anchor-to-resources is OFF)
    page.controls.castBarOffsetYSlider = UI.CreateModernSlider(
        scrollChild,
        L["Y Offset"],
        -600, 600,
        CDM.db.castBarOffsetY or -200,
        function(v)
            CDM.db.castBarOffsetY = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarOffsetYSlider:SetPoint("TOPLEFT", page.controls.castBarOffsetXSlider, "BOTTOMLEFT", 0, -10)

    API:RegisterCastBarSliderUpdater(function(offsetX, offsetY)
        if page.controls.castBarOffsetXSlider and page.controls.castBarOffsetXSlider.UpdateUIValue then
            page.controls.castBarOffsetXSlider:UpdateUIValue(offsetX)
        end
        if page.controls.castBarOffsetYSlider and page.controls.castBarOffsetYSlider.UpdateUIValue then
            page.controls.castBarOffsetYSlider:UpdateUIValue(offsetY)
        end
    end)

    -- =====================================================================
    --  TEXT (anchored relative to position section)
    -- =====================================================================
    local textHeader = UI.CreateHeader(scrollChild, L["Text"])
    page.castBarTextHeader = textHeader

    -- Toggle position controls based on anchor-to-resources state
    function page.UpdatePositionControls()
        local anchored = CDM.db.castBarAnchorToResources == true and CDM.db.resourcesEnabled ~= false
        page.controls.castBarResourcesSpacingSlider:SetShown(anchored)
        page.controls.castBarLocked:SetShown(not anchored)
        page.controls.castBarOffsetXSlider:SetShown(not anchored)
        page.controls.castBarOffsetYSlider:SetShown(not anchored)

        page.castBarTextHeader:ClearAllPoints()
        if anchored then
            page.castBarTextHeader:SetPoint("TOPLEFT", page.controls.castBarResourcesSpacingSlider, "BOTTOMLEFT", 0, -15)
        else
            page.castBarTextHeader:SetPoint("TOPLEFT", page.controls.castBarOffsetYSlider, "BOTTOMLEFT", 0, -15)
        end
    end

    page:SetScript("OnShow", function()
        UpdateAnchorToResourcesCheckboxState()
        page.UpdatePositionControls()
    end)

    UpdateAnchorToResourcesCheckboxState()
    page.UpdatePositionControls()

    -- Font Size Slider
    page.controls.castBarFontSizeSlider = UI.CreateModernSlider(
        scrollChild,
        L["Font Size"],
        8, 24,
        CDM.db.castBarFontSize or 15,
        function(v)
            CDM.db.castBarFontSize = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarFontSizeSlider:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -15)

    -- Show Spell Name Checkbox
    local showName = CDM.db.castBarShowSpellName
    if showName == nil then showName = true end
    page.controls.castBarShowSpellName = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Spell Name"],
        showName,
        function(checked)
            CDM.db.castBarShowSpellName = checked
            API:RefreshConfig()
        end
    )
    page.controls.castBarShowSpellName:SetPoint("TOPLEFT", page.controls.castBarFontSizeSlider, "BOTTOMLEFT", 0, -10)

    -- Spell Name X Offset
    page.controls.castBarNameOffsetX = UI.CreateModernSlider(
        scrollChild,
        L["Name X Offset"],
        -50, 50,
        CDM.db.castBarNameOffsetX or 4,
        function(v)
            CDM.db.castBarNameOffsetX = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarNameOffsetX:SetPoint("TOPLEFT", page.controls.castBarShowSpellName, "BOTTOMLEFT", 0, -10)

    -- Spell Name Y Offset
    page.controls.castBarNameOffsetY = UI.CreateModernSlider(
        scrollChild,
        L["Name Y Offset"],
        -20, 20,
        CDM.db.castBarNameOffsetY or 0,
        function(v)
            CDM.db.castBarNameOffsetY = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarNameOffsetY:SetPoint("TOPLEFT", page.controls.castBarNameOffsetX, "BOTTOMLEFT", 0, -10)

    -- Show Timer Checkbox
    local showTimer = CDM.db.castBarShowTimer
    if showTimer == nil then showTimer = true end
    page.controls.castBarShowTimer = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Timer"],
        showTimer,
        function(checked)
            CDM.db.castBarShowTimer = checked
            API:RefreshConfig()
        end
    )
    page.controls.castBarShowTimer:SetPoint("TOPLEFT", page.controls.castBarNameOffsetY, "BOTTOMLEFT", 0, -10)

    -- Timer X Offset
    page.controls.castBarTimerOffsetX = UI.CreateModernSlider(
        scrollChild,
        L["Timer X Offset"],
        -50, 50,
        CDM.db.castBarTimerOffsetX or -4,
        function(v)
            CDM.db.castBarTimerOffsetX = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarTimerOffsetX:SetPoint("TOPLEFT", page.controls.castBarShowTimer, "BOTTOMLEFT", 0, -10)

    -- Timer Y Offset
    page.controls.castBarTimerOffsetY = UI.CreateModernSlider(
        scrollChild,
        L["Timer Y Offset"],
        -20, 20,
        CDM.db.castBarTimerOffsetY or 0,
        function(v)
            CDM.db.castBarTimerOffsetY = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.castBarTimerOffsetY:SetPoint("TOPLEFT", page.controls.castBarTimerOffsetX, "BOTTOMLEFT", 0, -10)

    -- Show Spark Checkbox
    local showSpark = CDM.db.castBarShowSpark
    if showSpark == nil then showSpark = true end
    page.controls.castBarShowSpark = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Spark"],
        showSpark,
        function(checked)
            CDM.db.castBarShowSpark = checked
            API:RefreshConfig()
        end
    )
    page.controls.castBarShowSpark:SetPoint("TOPLEFT", page.controls.castBarTimerOffsetY, "BOTTOMLEFT", 0, -10)

    -- =====================================================================
    --  EMPOWERED STAGES
    -- =====================================================================
    local _, playerClass = UnitClass("player")
    local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID()
    local hasEmpoweredCasts = (playerClass == "EVOKER") or (specID == 250) or (specID == 269)
    if hasEmpoweredCasts then
        local empHeader = UI.CreateHeader(scrollChild, L["Empowered Stages"])
        empHeader:SetPoint("TOPLEFT", page.controls.castBarShowSpark, "BOTTOMLEFT", 0, -15)

        page.controls.castBarEmpowerWindUpColor = UI.CreateColorSwatch(scrollChild, L["Wind Up Color"], "castBarEmpowerWindUpColor")
        page.controls.castBarEmpowerWindUpColor:SetPoint("TOPLEFT", empHeader, "BOTTOMLEFT", 0, -15)

        page.controls.castBarEmpowerStage1Color = UI.CreateColorSwatch(scrollChild, L["Stage 1 Color"], "castBarEmpowerStage1Color")
        page.controls.castBarEmpowerStage1Color:SetPoint("TOPLEFT", page.controls.castBarEmpowerWindUpColor, "BOTTOMLEFT", 0, -10)

        page.controls.castBarEmpowerStage2Color = UI.CreateColorSwatch(scrollChild, L["Stage 2 Color"], "castBarEmpowerStage2Color")
        page.controls.castBarEmpowerStage2Color:SetPoint("TOPLEFT", page.controls.castBarEmpowerStage1Color, "BOTTOMLEFT", 0, -10)

        -- Font of Magic talent: Preservation 375783, Devastation 411212, Augmentation 408083
        local hasFontOfMagic = IsPlayerSpell(375783) or IsPlayerSpell(411212) or IsPlayerSpell(408083)
        local lastAnchor = page.controls.castBarEmpowerStage2Color

        if hasFontOfMagic then
            page.controls.castBarEmpowerStage3Color = UI.CreateColorSwatch(scrollChild, L["Stage 3 Color"], "castBarEmpowerStage3Color")
            page.controls.castBarEmpowerStage3Color:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
            lastAnchor = page.controls.castBarEmpowerStage3Color
        end

        -- Always visible: labeled "Stage 4" with Font of Magic, "Stage 3" without (hold-at-max color)
        local stage4Label = hasFontOfMagic and L["Stage 4 Color"] or L["Stage 3 Color"]
        page.controls.castBarEmpowerStage4Color = UI.CreateColorSwatch(scrollChild, stage4Label, "castBarEmpowerStage4Color")
        page.controls.castBarEmpowerStage4Color:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
    end
end

API:RegisterConfigTab("castbar", L["Cast Bar"], CreateCastBarTab, 11.2)
