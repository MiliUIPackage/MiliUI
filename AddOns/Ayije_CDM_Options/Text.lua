local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local L = Runtime.L
local UI = ns.ConfigUI

local TEXT_REFRESH_SCOPES = { "text_visuals", "trackers_layout", "viewers" }

local function RefreshTextConfig()
    if API.RefreshScopes then
        API:RefreshScopes(TEXT_REFRESH_SCOPES)
        return
    end
    API:RefreshConfig()
end

local function CreateTextTab(page, tabId)
    local textScrollChild = UI.CreateScrollableTab(page, "AyijeCDM_TextScrollFrame", 580, 1280)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    local function SetDB(key)
        return function(v) CDM.db[key] = v; RefreshTextConfig() end
    end

    local globalHeader = UI.CreateHeader(textScrollChild, L["Global Settings"])
    globalHeader:SetPoint("TOPLEFT", 0, NextY(0))

    local lblFont = textScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblFont:SetText(L["Font"])
    lblFont:SetPoint("TOPLEFT", 0, NextY(30))

    local ddFont = CreateFrame("DropdownButton", nil, textScrollChild, "WowStyle1DropdownTemplate")
    ddFont:SetPoint("TOPLEFT", lblFont, "BOTTOMLEFT", 0, -10)
    ddFont:SetWidth(220)
    ddFont:SetDefaultText(CDM.db.textFont or "Friz Quadrata TT")
    page.fontDropdown = ddFont
    NextY(45)

    UI.SetupMediaDropdown(
        ddFont,
        "font",
        function() return CDM.db.textFont end,
        function(name)
            CDM.db.textFont = name
            RefreshTextConfig()
        end,
        function(name)
            ddFont:SetDefaultText(name)
        end
    )

    local lblOutline = textScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblOutline:SetText(L["Font Outline"])
    lblOutline:SetPoint("TOPLEFT", 0, NextY(15))

    local ddOutline = CreateFrame("DropdownButton", nil, textScrollChild, "WowStyle1DropdownTemplate")
    ddOutline:SetPoint("TOPLEFT", lblOutline, "BOTTOMLEFT", 0, -10)
    ddOutline:SetWidth(220)
    local outlineLabels = {NONE = L["None"], OUTLINE = L["Outline"], THICKOUTLINE = L["Thick Outline"]}
    ddOutline:SetDefaultText(outlineLabels[CDM.db.textFontOutline] or L["Outline"])
    page.outlineDropdown = ddOutline
    NextY(45)

    UI.SetupValueDropdown(
        ddOutline,
        {
            {value = "NONE", label = L["None"]},
            {value = "OUTLINE", label = L["Outline"]},
            {value = "THICKOUTLINE", label = L["Thick Outline"]},
        },
        function() return CDM.db.textFontOutline end,
        function(value, label)
            CDM.db.textFontOutline = value
            ddOutline:SetDefaultText(label)
            RefreshTextConfig()
        end
    )

    local cooldownHeader = UI.CreateHeader(textScrollChild, L["Cooldown Timer"])
    cooldownHeader:SetPoint("TOPLEFT", 0, NextY(15))

    page.controls.cooldownFontSize = UI.CreateModernSlider(textScrollChild, L["Font Size"], 8, 32, CDM.db.cooldownFontSize, SetDB("cooldownFontSize"))
    page.controls.cooldownFontSize:SetPoint("TOPLEFT", 0, NextY(30))

    page.cooldownColorPicker = UI.CreateColorSwatch(textScrollChild, L["Color"], "cooldownColor", TEXT_REFRESH_SCOPES)
    page.cooldownColorPicker:SetPoint("TOPLEFT", 0, NextY(60))
    NextY(30)

    -- Essential Row 2 Cooldown Timer
    local essRow2Header = UI.CreateHeader(textScrollChild, L["Essential Row 2 - Cooldown Timer"])
    essRow2Header:SetPoint("TOPLEFT", 0, NextY(15))

    page.controls.essRow2CooldownFontSize = UI.CreateModernSlider(textScrollChild, L["Font Size"], 8, 32, CDM.db.essRow2CooldownFontSize, SetDB("essRow2CooldownFontSize"))
    page.controls.essRow2CooldownFontSize:SetPoint("TOPLEFT", 0, NextY(30))
    NextY(60)

    -- Utility Cooldown Timer
    local utilityHeader = UI.CreateHeader(textScrollChild, L["Utility - Cooldown Timer"])
    utilityHeader:SetPoint("TOPLEFT", 0, NextY(15))

    page.controls.utilityCooldownFontSize = UI.CreateModernSlider(textScrollChild, L["Font Size"], 8, 32, CDM.db.utilityCooldownFontSize, SetDB("utilityCooldownFontSize"))
    page.controls.utilityCooldownFontSize:SetPoint("TOPLEFT", 0, NextY(30))
    NextY(60)

    local chargeHeader = UI.CreateHeader(textScrollChild, L["Cooldown Stacks (Charges)"])
    chargeHeader:SetPoint("TOPLEFT", 0, NextY(15))

    page.controls.chargeFontSize = UI.CreateModernSlider(textScrollChild, L["Font Size"], 8, 32, CDM.db.chargeFontSize, SetDB("chargeFontSize"))
    page.controls.chargeFontSize:SetPoint("TOPLEFT", 0, NextY(30))

    -- Utility Charge Text
    local utilityChargeHeader = UI.CreateHeader(textScrollChild, L["Utility - Cooldown Stacks (Charges)"])
    utilityChargeHeader:SetPoint("TOPLEFT", 0, NextY(30))

    page.controls.utilityChargeFontSize = UI.CreateModernSlider(textScrollChild, L["Font Size"], 8, 32, CDM.db.utilityChargeFontSize, SetDB("utilityChargeFontSize"))
    page.controls.utilityChargeFontSize:SetPoint("TOPLEFT", 0, NextY(30))
    NextY(60)

    page.chargeColorPicker = UI.CreateColorSwatch(textScrollChild, L["Color"], "chargeColor", TEXT_REFRESH_SCOPES)
    page.chargeColorPicker:SetPoint("TOPLEFT", 0, NextY(60))

    local lblChargePos = textScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblChargePos:SetText(L["Position"])
    lblChargePos:SetPoint("TOPLEFT", 0, NextY(60))

    local ddChargePos = CreateFrame("DropdownButton", nil, textScrollChild, "WowStyle1DropdownTemplate")
    ddChargePos:SetPoint("TOPLEFT", lblChargePos, "BOTTOMLEFT", 0, -10)
    ddChargePos:SetWidth(180)
    ddChargePos:SetDefaultText(CDM.db.chargePosition or "BOTTOMRIGHT")
    page.chargePosDropdown = ddChargePos
    NextY(45)

    UI.SetupPositionDropdown(
        ddChargePos,
        function() return CDM.db.chargePosition end,
        function(pos)
            CDM.db.chargePosition = pos
            ddChargePos:SetDefaultText(pos)
            RefreshTextConfig()
        end
    )

    page.controls.chargeOffsetX = UI.CreateModernSlider(textScrollChild, L["X Offset"], -50, 50, CDM.db.chargeOffsetX, SetDB("chargeOffsetX"))
    page.controls.chargeOffsetX:SetPoint("TOPLEFT", 0, NextY(10))

    page.controls.chargeOffsetY = UI.CreateModernSlider(textScrollChild, L["Y Offset"], -50, 50, CDM.db.chargeOffsetY, SetDB("chargeOffsetY"))
    page.controls.chargeOffsetY:SetPoint("TOPLEFT", 0, NextY(60))
    NextY(60)

    local function CreateBarTextSection(headerText, fontSizeKey, colorKey, offsetXKey, offsetXDefault, offsetYKey, offsetYDefault)
        local hdr = UI.CreateHeader(textScrollChild, headerText)
        hdr:SetPoint("TOPLEFT", 0, NextY(15))

        page.controls[fontSizeKey] = UI.CreateModernSlider(textScrollChild, L["Font Size"], 8, 24,
            CDM.db[fontSizeKey] or CDM.defaults[fontSizeKey] or 15, SetDB(fontSizeKey))
        page.controls[fontSizeKey]:SetPoint("TOPLEFT", 0, NextY(30))

        local colorPicker = UI.CreateColorSwatch(textScrollChild, L["Color"], colorKey, TEXT_REFRESH_SCOPES)
        colorPicker:SetPoint("TOPLEFT", 0, NextY(60))

        page.controls[offsetXKey] = UI.CreateModernSlider(textScrollChild, L["X Offset"], -50, 50,
            CDM.db[offsetXKey] or CDM.defaults[offsetXKey] or offsetXDefault, SetDB(offsetXKey))
        page.controls[offsetXKey]:SetPoint("TOPLEFT", 0, NextY(60))

        page.controls[offsetYKey] = UI.CreateModernSlider(textScrollChild, L["Y Offset"], -20, 20,
            CDM.db[offsetYKey] or offsetYDefault, SetDB(offsetYKey))
        page.controls[offsetYKey]:SetPoint("TOPLEFT", 0, NextY(60))
        NextY(60)

        return colorPicker
    end

    page.buffBarNameColorPicker = CreateBarTextSection(
        L["Buff Bars - Name Text"],
        "buffBarNameFontSize", "buffBarNameColor",
        "buffBarNameOffsetX", 2, "buffBarNameOffsetY", 0
    )

    page.buffBarDurationColorPicker = CreateBarTextSection(
        L["Buff Bars - Duration Text"],
        "buffBarDurationFontSize", "buffBarDurationColor",
        "buffBarDurationOffsetX", -2, "buffBarDurationOffsetY", 0
    )

    local buffBarAppHeader = UI.CreateHeader(textScrollChild, L["Buff Bars - Stack Count Text"])
    buffBarAppHeader:SetPoint("TOPLEFT", 0, NextY(15))

    page.controls.buffBarAppFontSize = UI.CreateModernSlider(textScrollChild, L["Font Size"], 8, 24,
        CDM.db.buffBarApplicationsFontSize or CDM.defaults.buffBarApplicationsFontSize or 15, SetDB("buffBarApplicationsFontSize"))
    page.controls.buffBarAppFontSize:SetPoint("TOPLEFT", 0, NextY(30))

    page.buffBarAppColorPicker = UI.CreateColorSwatch(textScrollChild, L["Color"], "buffBarApplicationsColor", TEXT_REFRESH_SCOPES)
    page.buffBarAppColorPicker:SetPoint("TOPLEFT", 0, NextY(60))

    local lblBarAppPos = textScrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblBarAppPos:SetText(L["Anchor"])
    lblBarAppPos:SetPoint("TOPLEFT", 0, NextY(60))

    local ddBarAppPos = CreateFrame("DropdownButton", nil, textScrollChild, "WowStyle1DropdownTemplate")
    ddBarAppPos:SetPoint("TOPLEFT", lblBarAppPos, "BOTTOMLEFT", 0, -10)
    ddBarAppPos:SetWidth(180)
    ddBarAppPos:SetDefaultText(CDM.db.buffBarApplicationsPosition or "CENTER")
    page.barAppPosDropdown = ddBarAppPos
    NextY(45)

    UI.SetupPositionDropdown(
        ddBarAppPos,
        function() return CDM.db.buffBarApplicationsPosition end,
        function(pos)
            CDM.db.buffBarApplicationsPosition = pos
            ddBarAppPos:SetDefaultText(pos)
            RefreshTextConfig()
        end
    )

    page.controls.buffBarAppOffsetX = UI.CreateModernSlider(textScrollChild, L["X Offset"], -50, 50,
        CDM.db.buffBarApplicationsOffsetX or CDM.defaults.buffBarApplicationsOffsetX or 0, SetDB("buffBarApplicationsOffsetX"))
    page.controls.buffBarAppOffsetX:SetPoint("TOPLEFT", 0, NextY(10))

    page.controls.buffBarAppOffsetY = UI.CreateModernSlider(textScrollChild, L["Y Offset"], -50, 50,
        CDM.db.buffBarApplicationsOffsetY or 0, SetDB("buffBarApplicationsOffsetY"))
    page.controls.buffBarAppOffsetY:SetPoint("TOPLEFT", 0, NextY(60))
end

API:RegisterConfigTab("text", L["Text"], CreateTextTab, 5)
