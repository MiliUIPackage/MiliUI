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

    local enabled = CDM.db.castBarEnabled ~= false
    page.controls.castBarEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Cast Bar"],
        enabled,
        function(checked)
            CDM.db.castBarEnabled = checked
            API:Refresh("STYLE")
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
            if checked and API.DisableBlizzardPlayerCastBar then
                API:DisableBlizzardPlayerCastBar()
            end
        end
    )
    page.controls.hideBlizzardCastBar:SetPoint("LEFT", page.controls.castBarEnabled, "RIGHT", 0, 0)
    NextY(35)

    local dimHeader = UI.CreateHeader(scrollChild, L["Dimensions"])
    dimHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    page.controls.castBarWidthSlider = UI.CreateModernSlider(
        scrollChild,
        L["Width (0 = Auto)"],
        0, 600,
        CDM.db.castBarWidth or 300,
        function(v)
            local value = UI.RoundToInt(v)
            if value > 0 and value < 60 then
                value = 60
                page.controls.castBarWidthSlider.Slider:SetValue(60)
            end
            CDM.db.castBarWidth = value
            page.UpdateAutoWidthLayout()
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarWidthSlider:SetPoint("TOPLEFT", 0, NextY(0))

    local autoSourceChecked = (CDM.db.castBarAutoWidthSource == "utility")
    page.controls.castBarAutoWidthSource = UI.CreateModernCheckbox(
        scrollChild,
        L["Match Utility Width"],
        autoSourceChecked,
        function(checked)
            CDM.db.castBarAutoWidthSource = checked and "utility" or "essential"
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarAutoWidthSource:SetPoint("TOPLEFT", page.controls.castBarWidthSlider, "BOTTOMLEFT", 0, -5)
    NextY(60)

    page.controls.castBarHeightSlider = UI.CreateModernSlider(
        scrollChild,
        L["Height"],
        8, 40,
        CDM.db.castBarHeight or 20,
        function(v)
            CDM.db.castBarHeight = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarHeightSlider:SetPoint("TOPLEFT", 0, NextY(0))

    function page.UpdateAutoWidthLayout()
        local isAuto = (CDM.db.castBarWidth or 300) == 0
        page.controls.castBarAutoWidthSource:SetShown(isAuto)
        page.controls.castBarHeightSlider:ClearAllPoints()
        if isAuto then
            page.controls.castBarHeightSlider:SetPoint("TOPLEFT", page.controls.castBarAutoWidthSource, "BOTTOMLEFT", 0, -10)
        else
            page.controls.castBarHeightSlider:SetPoint("TOPLEFT", page.controls.castBarWidthSlider, "BOTTOMLEFT", 0, -10)
        end
    end
    page.UpdateAutoWidthLayout()
    NextY(60)

    local iconHeader = UI.CreateHeader(scrollChild, L["Spell Icon"])
    iconHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    local showIcon = CDM.db.castBarShowIcon or false
    page.controls.castBarShowIcon = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Spell Icon"],
        showIcon,
        function(checked)
            CDM.db.castBarShowIcon = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarShowIcon:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(35)

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
            API:Refresh("STYLE")
        end
    )
    NextY(50)

    page.controls.castBarIconGapSlider = UI.CreateModernSlider(
        scrollChild,
        L["Icon-Bar Gap"],
        -1, 20,
        CDM.db.castBarIconGap or 1,
        function(v)
            CDM.db.castBarIconGap = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarIconGapSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    local texHeader = UI.CreateHeader(scrollChild, L["Bar Texture"])
    texHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(30)

    local useAtlas = CDM.db.castBarUseAtlasTextures ~= false
    page.controls.castBarUseAtlas = UI.CreateModernCheckbox(
        scrollChild,
        L["Use Blizzard Atlas Textures"],
        useAtlas,
        function(checked)
            CDM.db.castBarUseAtlasTextures = checked
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
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarUseAtlas:SetPoint("TOPLEFT", 0, NextY(0))

    local lsmGroup = CreateFrame("Frame", nil, scrollChild)
    lsmGroup:SetSize(600, 310)
    lsmGroup:SetPoint("TOPLEFT", page.controls.castBarUseAtlas, "BOTTOMLEFT", 0, -10)
    page.castBarLSMGroup = lsmGroup

    lsmGroup:SetShown(not useAtlas)

    local lsmLayout = UI.CreateVerticalLayout(0)
    local function LsmNextY(spacing) return lsmLayout:Next(spacing) end

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
            API:Refresh("STYLE")
        end,
        function(name)
            ddTexture:SetDefaultText(name or "Blizzard")
        end
    )

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
            API:Refresh("STYLE")
        end,
        function(name)
            ddBgTexture:SetDefaultText(name or "Blizzard")
        end
    )

    page.controls.castBarBackgroundColor = UI.CreateColorSwatch(lsmGroup, L["Background Color"], "castBarBackgroundColor", "STYLE")
    page.controls.castBarBackgroundColor:SetPoint("TOPLEFT", 0, LsmNextY(50))

    page.controls.castBarCastColor = UI.CreateColorSwatch(lsmGroup, L["Cast Color"], "castBarCastColor", "STYLE")
    page.controls.castBarCastColor:SetPoint("TOPLEFT", 0, LsmNextY(40))

    local useClassColor = CDM.db.castBarUseClassColor == true
    page.controls.castBarUseClassColor = UI.CreateModernCheckbox(
        lsmGroup,
        L["Class Color"],
        useClassColor,
        function(checked)
            CDM.db.castBarUseClassColor = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarUseClassColor:SetPoint("LEFT", page.controls.castBarCastColor, "RIGHT", 20, 0)

    page.controls.castBarChannelColor = UI.CreateColorSwatch(lsmGroup, L["Channel Color"], "castBarChannelColor", "STYLE")
    page.controls.castBarChannelColor:SetPoint("TOPLEFT", 0, LsmNextY(40))

    page.controls.castBarUninterruptibleColor = UI.CreateColorSwatch(lsmGroup, L["Uninterruptible Color"], "castBarUninterruptibleColor", "STYLE")
    page.controls.castBarUninterruptibleColor:SetPoint("TOPLEFT", 0, LsmNextY(40))

    local posHeader = UI.CreateHeader(scrollChild, L["Position"])
    page.castBarPositionHeader = posHeader
    if not useAtlas then
        posHeader:SetPoint("TOPLEFT", lsmGroup, "BOTTOMLEFT", 0, -10)
    else
        posHeader:SetPoint("TOPLEFT", page.controls.castBarUseAtlas, "BOTTOMLEFT", 0, -15)
    end

    local POINT_OPTIONS = {
        { value = "TOPLEFT",     label = L["Top Left"] or "Top Left" },
        { value = "TOP",         label = L["Top"] or "Top" },
        { value = "TOPRIGHT",    label = L["Top Right"] or "Top Right" },
        { value = "LEFT",        label = L["Left"] or "Left" },
        { value = "CENTER",      label = L["Center"] or "Center" },
        { value = "RIGHT",       label = L["Right"] or "Right" },
        { value = "BOTTOMLEFT",  label = L["Bottom Left"] or "Bottom Left" },
        { value = "BOTTOM",      label = L["Bottom"] or "Bottom" },
        { value = "BOTTOMRIGHT", label = L["Bottom Right"] or "Bottom Right" },
    }

    local function BuildAnchorOptions()
        local resourcesEnabled = CDM.db.resourcesEnabled ~= false
        local opts = {
            { value = "screen",      label = L["Screen"] or "Screen" },
            { value = "playerFrame", label = L["Player Frame"] or "Player Frame" },
            { value = "essential",   label = L["Essential Viewer"] or "Essential Viewer" },
            { value = "utility",     label = L["Utility Viewer"] or "Utility Viewer" },
        }
        if resourcesEnabled then
            opts[#opts + 1] = { value = "resources", label = L["Resources"] or "Resources" }
        end
        return opts
    end

    local anchorLabel = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    anchorLabel:SetText(L["Anchor To:"] or "Anchor To:")
    anchorLabel:SetPoint("TOPLEFT", posHeader, "BOTTOMLEFT", 0, -15)

    local ddAnchor = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddAnchor:SetPoint("TOPLEFT", anchorLabel, "BOTTOMLEFT", 0, -5)
    ddAnchor:SetWidth(200)
    page.controls.castBarAnchor = ddAnchor

    local function GetAnchorLabel(value)
        for _, opt in ipairs(BuildAnchorOptions()) do
            if opt.value == value then return opt.label end
        end
        return value or ""
    end

    local currentAnchor = CDM.db.castBarAnchor or "resources"
    ddAnchor:SetDefaultText(GetAnchorLabel(currentAnchor))

    UI.SetupValueDropdown(
        ddAnchor,
        BuildAnchorOptions,
        function() return CDM.db.castBarAnchor or "resources" end,
        function(value)
            CDM.db.castBarAnchor = value
            ddAnchor:SetDefaultText(GetAnchorLabel(value))
            API:Refresh("STYLE")
        end
    )

    local anchorPointLabel = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    anchorPointLabel:SetText(L["Anchor Point:"] or "Anchor Point:")
    anchorPointLabel:SetPoint("TOPLEFT", ddAnchor, "BOTTOMLEFT", 0, -10)

    local ddAnchorPoint = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddAnchorPoint:SetPoint("TOPLEFT", anchorPointLabel, "BOTTOMLEFT", 0, -5)
    ddAnchorPoint:SetWidth(200)
    page.controls.castBarAnchorPoint = ddAnchorPoint

    local function GetPointLabel(value)
        for _, opt in ipairs(POINT_OPTIONS) do
            if opt.value == value then return opt.label end
        end
        return value or ""
    end

    ddAnchorPoint:SetDefaultText(GetPointLabel(CDM.db.castBarAnchorPoint or "BOTTOM"))
    UI.SetupValueDropdown(
        ddAnchorPoint,
        POINT_OPTIONS,
        function() return CDM.db.castBarAnchorPoint or "BOTTOM" end,
        function(value)
            CDM.db.castBarAnchorPoint = value
            ddAnchorPoint:SetDefaultText(GetPointLabel(value))
            API:Refresh("STYLE")
        end
    )

    local targetPointLabel = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    targetPointLabel:SetText(L["Target Point:"] or "Target Point:")
    targetPointLabel:SetPoint("TOPLEFT", ddAnchorPoint, "BOTTOMLEFT", 0, -10)

    local ddTargetPoint = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddTargetPoint:SetPoint("TOPLEFT", targetPointLabel, "BOTTOMLEFT", 0, -5)
    ddTargetPoint:SetWidth(200)
    page.controls.castBarTargetPoint = ddTargetPoint

    ddTargetPoint:SetDefaultText(GetPointLabel(CDM.db.castBarTargetPoint or "TOP"))
    UI.SetupValueDropdown(
        ddTargetPoint,
        POINT_OPTIONS,
        function() return CDM.db.castBarTargetPoint or "TOP" end,
        function(value)
            CDM.db.castBarTargetPoint = value
            ddTargetPoint:SetDefaultText(GetPointLabel(value))
            API:Refresh("STYLE")
        end
    )

    page.controls.castBarOffsetXSlider = UI.CreateModernSlider(
        scrollChild,
        L["X Offset"],
        -800, 800,
        CDM.db.castBarOffsetX or 0,
        function(v)
            CDM.db.castBarOffsetX = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarOffsetXSlider:SetPoint("TOPLEFT", ddTargetPoint, "BOTTOMLEFT", 0, -15)

    page.controls.castBarOffsetYSlider = UI.CreateModernSlider(
        scrollChild,
        L["Y Offset"],
        -600, 600,
        CDM.db.castBarOffsetY or -166,
        function(v)
            CDM.db.castBarOffsetY = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarOffsetYSlider:SetPoint("TOPLEFT", page.controls.castBarOffsetXSlider, "BOTTOMLEFT", 0, -10)

    local previewEnabled = CDM.db.castBarPreviewEnabled == true
    page.controls.castBarPreviewEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Preview"] or "Show Preview",
        previewEnabled,
        function(checked)
            CDM.db.castBarPreviewEnabled = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarPreviewEnabled:SetPoint("TOPLEFT", page.controls.castBarOffsetYSlider, "BOTTOMLEFT", 0, -15)

    local textHeader = UI.CreateHeader(scrollChild, L["Text"])
    page.castBarTextHeader = textHeader
    textHeader:SetPoint("TOPLEFT", page.controls.castBarPreviewEnabled, "BOTTOMLEFT", 0, -15)

    page.controls.castBarFontSizeSlider = UI.CreateModernSlider(
        scrollChild,
        L["Font Size"],
        8, 24,
        CDM.db.castBarFontSize or 15,
        function(v)
            CDM.db.castBarFontSize = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarFontSizeSlider:SetPoint("TOPLEFT", textHeader, "BOTTOMLEFT", 0, -15)

    local showName = CDM.db.castBarShowSpellName
    if showName == nil then showName = true end
    page.controls.castBarShowSpellName = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Spell Name"],
        showName,
        function(checked)
            CDM.db.castBarShowSpellName = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarShowSpellName:SetPoint("TOPLEFT", page.controls.castBarFontSizeSlider, "BOTTOMLEFT", 0, -10)

    page.controls.castBarNameMaxCharsSlider = UI.CreateModernSlider(
        scrollChild,
        L["Max Name Length (0 = Full)"],
        0, 30,
        CDM.db.castBarNameMaxChars or 0,
        function(v)
            CDM.db.castBarNameMaxChars = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarNameMaxCharsSlider:SetPoint("TOPLEFT", page.controls.castBarShowSpellName, "BOTTOMLEFT", 0, -10)

    page.controls.castBarNameOffsetX = UI.CreateModernSlider(
        scrollChild,
        L["Name X Offset"],
        -50, 50,
        CDM.db.castBarNameOffsetX or 4,
        function(v)
            CDM.db.castBarNameOffsetX = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarNameOffsetX:SetPoint("TOPLEFT", page.controls.castBarNameMaxCharsSlider, "BOTTOMLEFT", 0, -10)

    page.controls.castBarNameOffsetY = UI.CreateModernSlider(
        scrollChild,
        L["Name Y Offset"],
        -20, 20,
        CDM.db.castBarNameOffsetY or 0,
        function(v)
            CDM.db.castBarNameOffsetY = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarNameOffsetY:SetPoint("TOPLEFT", page.controls.castBarNameOffsetX, "BOTTOMLEFT", 0, -10)

    local showTimer = CDM.db.castBarShowTimer
    if showTimer == nil then showTimer = true end
    page.controls.castBarShowTimer = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Timer"],
        showTimer,
        function(checked)
            CDM.db.castBarShowTimer = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarShowTimer:SetPoint("TOPLEFT", page.controls.castBarNameOffsetY, "BOTTOMLEFT", 0, -10)

    page.controls.castBarTimerOffsetX = UI.CreateModernSlider(
        scrollChild,
        L["Timer X Offset"],
        -50, 50,
        CDM.db.castBarTimerOffsetX or -4,
        function(v)
            CDM.db.castBarTimerOffsetX = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarTimerOffsetX:SetPoint("TOPLEFT", page.controls.castBarShowTimer, "BOTTOMLEFT", 0, -10)

    page.controls.castBarTimerOffsetY = UI.CreateModernSlider(
        scrollChild,
        L["Timer Y Offset"],
        -20, 20,
        CDM.db.castBarTimerOffsetY or 0,
        function(v)
            CDM.db.castBarTimerOffsetY = UI.RoundToInt(v)
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarTimerOffsetY:SetPoint("TOPLEFT", page.controls.castBarTimerOffsetX, "BOTTOMLEFT", 0, -10)

    local showSpark = CDM.db.castBarShowSpark
    if showSpark == nil then showSpark = true end
    page.controls.castBarShowSpark = UI.CreateModernCheckbox(
        scrollChild,
        L["Show Spark"],
        showSpark,
        function(checked)
            CDM.db.castBarShowSpark = checked
            API:Refresh("STYLE")
        end
    )
    page.controls.castBarShowSpark:SetPoint("TOPLEFT", page.controls.castBarTimerOffsetY, "BOTTOMLEFT", 0, -10)

    local _, playerClass = UnitClass("player")
    local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID()
    local hasEmpoweredCasts = (playerClass == "EVOKER") or (specID == 250) or (specID == 269)
    if hasEmpoweredCasts then
        local empHeader = UI.CreateHeader(scrollChild, L["Empowered Stages"])
        empHeader:SetPoint("TOPLEFT", page.controls.castBarShowSpark, "BOTTOMLEFT", 0, -15)

        page.controls.castBarEmpowerWindUpColor = UI.CreateColorSwatch(scrollChild, L["Wind Up Color"], "castBarEmpowerWindUpColor", "STYLE")
        page.controls.castBarEmpowerWindUpColor:SetPoint("TOPLEFT", empHeader, "BOTTOMLEFT", 0, -15)

        page.controls.castBarEmpowerStage1Color = UI.CreateColorSwatch(scrollChild, L["Stage 1 Color"], "castBarEmpowerStage1Color", "STYLE")
        page.controls.castBarEmpowerStage1Color:SetPoint("TOPLEFT", page.controls.castBarEmpowerWindUpColor, "BOTTOMLEFT", 0, -10)

        page.controls.castBarEmpowerStage2Color = UI.CreateColorSwatch(scrollChild, L["Stage 2 Color"], "castBarEmpowerStage2Color", "STYLE")
        page.controls.castBarEmpowerStage2Color:SetPoint("TOPLEFT", page.controls.castBarEmpowerStage1Color, "BOTTOMLEFT", 0, -10)

        -- Font of Magic talent: Preservation 375783, Devastation 411212, Augmentation 408083
        local hasFontOfMagic = IsPlayerSpell(375783) or IsPlayerSpell(411212) or IsPlayerSpell(408083)
        local lastAnchor = page.controls.castBarEmpowerStage2Color

        if hasFontOfMagic then
            page.controls.castBarEmpowerStage3Color = UI.CreateColorSwatch(scrollChild, L["Stage 3 Color"], "castBarEmpowerStage3Color", "STYLE")
            page.controls.castBarEmpowerStage3Color:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
            lastAnchor = page.controls.castBarEmpowerStage3Color
        end

        page.controls.castBarEmpowerStage4Color = UI.CreateColorSwatch(scrollChild, L["Hold At Max Color"], "castBarEmpowerStage4Color", "STYLE")
        page.controls.castBarEmpowerStage4Color:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -10)
    end
end

API:RegisterConfigTab("castbar", L["Cast Bar"], CreateCastBarTab, 11.2)
