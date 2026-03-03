-- Config/Bars.lua - Buff Bars Settings Tab
-- Controls for BuffBarCooldownViewer styling and positioning

local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function CreateBarsTab(page, tabId)
    -- Create scroll frame container
    local barsScrollChild = UI.CreateScrollableTab(page, "AyijeCDM_BarsScrollFrame", 900, 370)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    -- =========================================================================
    -- DIMENSIONS
    -- =========================================================================
    local dimensionsHeader = UI.CreateHeader(barsScrollChild, L["Dimensions"])
    dimensionsHeader:SetPoint("TOPLEFT", 0, NextY(0))

    -- Bar Width Slider (0 = auto)
    page.controls.buffBarWidthSlider = UI.CreateModernSlider(
        barsScrollChild,
        L["Bar Width (0 = Auto)"],
        0,
        600,
        CDM.db.buffBarWidth or 0,
        function(v)
            local value = UI.RoundToInt(v)
            -- Enforce minimum of 60 when not 0
            if value > 0 and value < 60 then
                value = 60
                page.controls.buffBarWidthSlider.Slider:SetValue(60)
            end
            CDM.db.buffBarWidth = value
            API:RefreshConfig()
        end
    )
    page.controls.buffBarWidthSlider:SetPoint("TOPLEFT", 0, NextY(30))

    -- Bar Height Slider
    page.controls.buffBarHeightSlider = UI.CreateModernSlider(
        barsScrollChild,
        L["Bar Height"],
        4,
        40,
        CDM.db.buffBarHeight or 20,
        function(v)
            CDM.db.buffBarHeight = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.buffBarHeightSlider:SetPoint("TOPLEFT", 0, NextY(60))

    -- Spacing Slider
    page.controls.buffBarSpacingSlider = UI.CreateModernSlider(
        barsScrollChild,
        L["Bar Spacing"],
        -1,
        20,
        CDM.db.buffBarSpacing or 2,
        function(v)
            CDM.db.buffBarSpacing = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.buffBarSpacingSlider:SetPoint("TOPLEFT", 0, NextY(60))

    -- =========================================================================
    -- APPEARANCE
    -- =========================================================================
    local appearanceHeader = UI.CreateHeader(barsScrollChild, L["Appearance"])
    appearanceHeader:SetPoint("TOPLEFT", 0, NextY(70))

    -- Bar Texture Dropdown
    local textureLabel = barsScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    textureLabel:SetText(L["Bar Texture:"])
    textureLabel:SetPoint("TOPLEFT", 0, NextY(30))

    local ddBarTexture = CreateFrame("DropdownButton", nil, barsScrollChild, "WowStyle1DropdownTemplate")
    ddBarTexture:SetPoint("TOPLEFT", 0, NextY(20))
    ddBarTexture:SetWidth(220)
    ddBarTexture:SetDefaultText(CDM.db.buffBarTexture or "Blizzard")
    page.barTextureDropdown = ddBarTexture

    UI.SetupMediaDropdown(
        ddBarTexture,
        "statusbar",
        function() return CDM.db.buffBarTexture or "Blizzard" end,
        function(name)
            CDM.db.buffBarTexture = name
            API:RefreshConfig()
        end,
        function(name)
            ddBarTexture:SetDefaultText(name or "Blizzard")
        end
    )

    -- Bar Color Picker
    page.controls.buffBarColorPicker = UI.CreateColorSwatch(barsScrollChild, L["Bar Color"], "buffBarColor")
    page.controls.buffBarColorPicker:SetPoint("TOPLEFT", 0, NextY(50))

    -- Background Color Picker
    page.controls.buffBarBgColorPicker = UI.CreateColorSwatch(barsScrollChild, L["Background Color"], "buffBarBackgroundColor")
    page.controls.buffBarBgColorPicker:SetPoint("TOPLEFT", 0, NextY(50))

    -- =========================================================================
    -- LAYOUT
    -- =========================================================================
    local layoutHeader = UI.CreateHeader(barsScrollChild, L["Layout"])
    layoutHeader:SetPoint("TOPLEFT", 0, NextY(60))

    -- Growth Direction Dropdown
    local growLabel = barsScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    growLabel:SetText(L["Growth Direction:"])
    growLabel:SetPoint("TOPLEFT", 0, NextY(30))

    local ddGrowDirection = CreateFrame("DropdownButton", nil, barsScrollChild, "WowStyle1DropdownTemplate")
    ddGrowDirection:SetPoint("TOPLEFT", 0, NextY(20))
    ddGrowDirection:SetWidth(150)
    ddGrowDirection:SetDefaultText(CDM.db.buffBarGrowDirection or "DOWN")
    page.growDirectionDropdown = ddGrowDirection

    local growOptions = {
        { value = "DOWN", label = L["Down"] },
        { value = "UP", label = L["Up"] },
    }

    UI.SetupValueDropdown(
        ddGrowDirection,
        growOptions,
        function() return CDM.db.buffBarGrowDirection or "DOWN" end,
        function(value)
            CDM.db.buffBarGrowDirection = value
            ddGrowDirection:SetDefaultText(value)
            API:RefreshConfig()
        end
    )

    -- Icon Position Dropdown
    local iconPosLabel = barsScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    iconPosLabel:SetText(L["Icon Position:"])
    iconPosLabel:SetPoint("TOPLEFT", 0, NextY(50))

    local ddIconPosition = CreateFrame("DropdownButton", nil, barsScrollChild, "WowStyle1DropdownTemplate")
    ddIconPosition:SetPoint("TOPLEFT", 0, NextY(20))
    ddIconPosition:SetWidth(150)
    ddIconPosition:SetDefaultText(CDM.db.buffBarIconPosition or "LEFT")
    page.iconPositionDropdown = ddIconPosition

    local iconOptions = {
        { value = "LEFT", label = L["Left"] },
        { value = "RIGHT", label = L["Right"] },
        { value = "HIDDEN", label = L["Hidden"] },
    }

    UI.SetupValueDropdown(
        ddIconPosition,
        iconOptions,
        function() return CDM.db.buffBarIconPosition or "LEFT" end,
        function(value)
            CDM.db.buffBarIconPosition = value
            ddIconPosition:SetDefaultText(value)
            API:RefreshConfig()
        end
    )

    -- Icon-Bar Gap Slider
    page.controls.buffBarIconGapSlider = UI.CreateModernSlider(
        barsScrollChild,
        L["Icon-Bar Gap"],
        -1,
        20,
        CDM.db.buffBarIconGap or 2,
        function(v)
            CDM.db.buffBarIconGap = UI.RoundToInt(v)
            API:RefreshConfig()
        end
    )
    page.controls.buffBarIconGapSlider:SetPoint("TOPLEFT", 0, NextY(50))

    -- Dual Mode Checkbox
    page.controls.buffBarDualModeCheck = UI.CreateModernCheckbox(
        barsScrollChild,
        L["Dual Bar Mode (2 bars per row)"],
        CDM.db.buffBarDualMode or false,
        function(checked)
            CDM.db.buffBarDualMode = checked
            API:RefreshConfig()
        end
    )
    page.controls.buffBarDualModeCheck:SetPoint("TOPLEFT", 0, NextY(60))

    -- =========================================================================
    -- TEXT
    -- =========================================================================
    local textHeader = UI.CreateHeader(barsScrollChild, L["Text"])
    textHeader:SetPoint("TOPLEFT", 0, NextY(50))

    -- Show Name Checkbox
    page.controls.buffBarShowNameCheck = UI.CreateModernCheckbox(
        barsScrollChild,
        L["Show Buff Name"],
        CDM.db.buffBarShowName ~= false,
        function(checked)
            CDM.db.buffBarShowName = checked
            API:RefreshConfig()
        end
    )
    page.controls.buffBarShowNameCheck:SetPoint("TOPLEFT", 0, NextY(30))

    -- Show Duration Checkbox
    page.controls.buffBarShowDurationCheck = UI.CreateModernCheckbox(
        barsScrollChild,
        L["Show Duration Text"],
        CDM.db.buffBarShowDuration ~= false,
        function(checked)
            CDM.db.buffBarShowDuration = checked
            API:RefreshConfig()
        end
    )
    page.controls.buffBarShowDurationCheck:SetPoint("TOPLEFT", 0, NextY(30))

    -- Show Applications (Stacks) Checkbox
    page.controls.buffBarShowApplicationsCheck = UI.CreateModernCheckbox(
        barsScrollChild,
        L["Show Stack Count"],
        CDM.db.buffBarShowApplications ~= false,
        function(checked)
            CDM.db.buffBarShowApplications = checked
            API:RefreshConfig()
        end
    )
    page.controls.buffBarShowApplicationsCheck:SetPoint("TOPLEFT", 0, NextY(30))

    -- =========================================================================
    -- NOTES
    -- =========================================================================
    local notesHeader = UI.CreateHeader(barsScrollChild, L["Notes"])
    notesHeader:SetPoint("TOPLEFT", 0, NextY(50))

    local borderNote = barsScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    borderNote:SetText(L["Border settings: see Borders tab"])
    UI.SetTextMuted(borderNote)
    borderNote:SetPoint("TOPLEFT", 0, NextY(30))

    local textNote = barsScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    textNote:SetText(L["Text styling (font size, color, offsets): see Text tab"])
    UI.SetTextMuted(textNote)
    textNote:SetPoint("TOPLEFT", 0, NextY(20))

    local posNote = barsScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    posNote:SetText(L["Position lock and X/Y controls: see Positions tab"])
    UI.SetTextMuted(posNote)
    posNote:SetPoint("TOPLEFT", 0, NextY(20))
end

-- Register this tab (navOrder 8 places it between Icons=7 and Racials=9)
API:RegisterConfigTab("bars", L["Bars"], CreateBarsTab, 8)
