local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local L = Runtime.L
local UI = ns.ConfigUI

local SLIDER_LABEL_W = 130
local SLIDER_W = 220

local OUTLINE_OPTIONS = {
    { value = "",             label = L["None"] },
    { value = "OUTLINE",      label = L["Outline"] },
    { value = "THICKOUTLINE", label = L["Thick Outline"] },
    { value = "SLUG",         label = L["Slug"] },
}

local function OutlineLabel(value)
    return UI.GetOptionLabel(OUTLINE_OPTIONS, value, L["Outline"])
end

local function SetDB(key, scope)
    return function(v)
        CDM.db[key] = v
        API:Refresh(scope or "STYLE")
    end
end

local function SectionHeader(rc, text, yOff)
    local hdr = UI.CreateHeader(rc, text)
    hdr:SetPoint("TOPLEFT", 0, yOff)
    return hdr
end

local function Slider(page, rc, label, minV, maxV, key, yOff, defaultVal, scope)
    local initial = CDM.db[key]
    if initial == nil then initial = CDM.defaults[key] end
    if initial == nil then initial = defaultVal or 0 end
    local slider = UI.CreateModernSlider(rc, label, minV, maxV, initial, SetDB(key, scope),
        SLIDER_LABEL_W, SLIDER_W)
    slider:SetPoint("TOPLEFT", 0, yOff)
    page.controls[key] = slider
    return slider
end

local function ColorSwatch(rc, label, key, yOff, scope)
    local swatch = UI.CreateColorSwatch(rc, label, key, scope or "STYLE")
    swatch:SetPoint("TOPLEFT", 0, yOff)
    return swatch
end

local function FontDropdown(rc, yOff, page)
    local lbl = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lbl:SetText(L["Font"])
    lbl:SetPoint("TOPLEFT", 0, yOff)

    local dd = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -10)
    dd:SetWidth(220)
    dd:SetDefaultText(CDM.db.textFont or "Friz Quadrata TT")
    UI.SetupMediaDropdown(dd, "font",
        function() return CDM.db.textFont end,
        function(name) CDM.db.textFont = name; API:Refresh("STYLE") end,
        function(name) dd:SetDefaultText(name) end)
    page.fontDropdown = dd
end

local function OutlineDropdown(rc, yOff, page)
    local lbl = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lbl:SetText(L["Font Outline"])
    lbl:SetPoint("TOPLEFT", 0, yOff)

    local dd = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -10)
    dd:SetWidth(220)
    dd:SetDefaultText(OutlineLabel(CDM.db.textFontOutline))
    UI.SetupValueDropdown(dd, OUTLINE_OPTIONS,
        function() return CDM.db.textFontOutline end,
        function(value, label)
            CDM.db.textFontOutline = value
            dd:SetDefaultText(label)
            API:Refresh("STYLE")
        end)
    page.outlineDropdown = dd
end

local function PositionDropdown(rc, label, key, yOff)
    local lbl = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lbl:SetText(label)
    lbl:SetPoint("TOPLEFT", 0, yOff)

    local dd = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -10)
    dd:SetWidth(180)
    dd:SetDefaultText(CDM.db[key] or CDM.defaults[key] or "CENTER")
    UI.SetupPositionDropdown(dd,
        function() return CDM.db[key] end,
        function(pos)
            CDM.db[key] = pos
            dd:SetDefaultText(pos)
            API:Refresh("STYLE")
        end)
    return dd
end

local SCROLL_BOTTOM_PAD = 20

local function MakeSubPageScroll(subPage, frameName)
    local sf = CreateFrame("ScrollFrame", frameName, subPage, "ScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", -10, 0)
    UI.AttachCloseMenusOnScroll(sf)

    local sc = CreateFrame("Frame", nil, sf)
    sc:SetWidth(540)
    sf:SetScrollChild(sc)

    local rc = CreateFrame("Frame", nil, sc)
    rc:SetPoint("TOPLEFT", 30, 0)
    rc:SetPoint("TOPRIGHT", -20, 0)
    return rc, sc
end

local function FinalizeScroll(sc, rc, yOff)
    local h = math.abs(yOff) + SCROLL_BOTTOM_PAD
    sc:SetHeight(h)
    rc:SetHeight(h)
end

local function BuildGlobal(subPage, page)
    local rc, sc = MakeSubPageScroll(subPage, "AyijeCDM_Text_GlobalScrollFrame")
    local yOff = 0

    FontDropdown(rc, yOff, page); yOff = yOff - 55
    OutlineDropdown(rc, yOff, page); yOff = yOff - 65

    SectionHeader(rc, L["Cooldown Timer"], yOff); yOff = yOff - 30
    ColorSwatch(rc, L["Color"], "cooldownColor", yOff); yOff = yOff - 45

    SectionHeader(rc, L["Cooldown Countdown Format"], yOff); yOff = yOff - 30

    local decSlider = UI.CreateModernSliderPrecise(rc,
        L["Show decimals below (seconds, 0 = off)"], 0, 10,
        CDM.db.cooldownDecimalThreshold, 0.5, 1,
        function(v)
            CDM.db.cooldownDecimalThreshold = v
            API:Refresh("STYLE")
        end)
    decSlider:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60

    SectionHeader(rc, L["Threshold Color"], yOff); yOff = yOff - 30

    local chk = UI.CreateModernCheckbox(rc, L["Color countdown below threshold"],
        CDM.db.cooldownColorThresholdEnabled,
        function(checked)
            CDM.db.cooldownColorThresholdEnabled = checked
            API:Refresh("STYLE")
        end)
    chk:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 35

    local thrSlider = UI.CreateModernSliderPrecise(rc,
        L["Threshold (seconds)"], 1, 30,
        CDM.db.cooldownColorThreshold, 0.5, 1,
        function(v)
            CDM.db.cooldownColorThreshold = v
            API:Refresh("STYLE")
        end)
    thrSlider:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60

    ColorSwatch(rc, L["Color"], "cooldownColorThresholdColor", yOff); yOff = yOff - 45
    FinalizeScroll(sc, rc, yOff)
end

local function BuildEssential(subPage, page)
    local rc, sc = MakeSubPageScroll(subPage, "AyijeCDM_Text_EssentialScrollFrame")
    local yOff = 0

    SectionHeader(rc, L["Cooldown Timer"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Row 1 Font Size"], 8, 32, "cooldownFontSize", yOff, 12); yOff = yOff - 60
    Slider(page, rc, L["Row 2 Font Size"], 8, 32, "essRow2CooldownFontSize", yOff, 12); yOff = yOff - 60

    SectionHeader(rc, L["Row 1 - Stacks (Charges)"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Font Size"], 8, 32, "chargeFontSize", yOff, 12); yOff = yOff - 60
    ColorSwatch(rc, L["Color"], "chargeColor", yOff); yOff = yOff - 45
    PositionDropdown(rc, L["Position"], "chargePosition", yOff); yOff = yOff - 60
    Slider(page, rc, L["X Offset"], -50, 50, "chargeOffsetX", yOff, 0); yOff = yOff - 50
    Slider(page, rc, L["Y Offset"], -50, 50, "chargeOffsetY", yOff, 0); yOff = yOff - 70

    SectionHeader(rc, L["Row 2 - Stacks (Charges)"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Font Size"], 8, 32, "essRow2ChargeFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(rc, L["Color"], "essRow2ChargeColor", yOff); yOff = yOff - 45
    PositionDropdown(rc, L["Position"], "essRow2ChargePosition", yOff); yOff = yOff - 60
    Slider(page, rc, L["X Offset"], -50, 50, "essRow2ChargeOffsetX", yOff, 0); yOff = yOff - 50
    Slider(page, rc, L["Y Offset"], -50, 50, "essRow2ChargeOffsetY", yOff, 0); yOff = yOff - 50
    FinalizeScroll(sc, rc, yOff)
end

local function BuildUtility(subPage, page)
    local rc, sc = MakeSubPageScroll(subPage, "AyijeCDM_Text_UtilityScrollFrame")
    local yOff = 0

    SectionHeader(rc, L["Cooldown Timer"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Font Size"], 8, 32, "utilityCooldownFontSize", yOff, 12); yOff = yOff - 60

    SectionHeader(rc, L["Stacks (Charges)"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Font Size"], 8, 32, "utilityChargeFontSize", yOff, 12); yOff = yOff - 60
    ColorSwatch(rc, L["Color"], "utilityChargeColor", yOff); yOff = yOff - 45
    PositionDropdown(rc, L["Position"], "utilityChargePosition", yOff); yOff = yOff - 60
    Slider(page, rc, L["X Offset"], -50, 50, "utilityChargeOffsetX", yOff, 0); yOff = yOff - 50
    Slider(page, rc, L["Y Offset"], -50, 50, "utilityChargeOffsetY", yOff, 0); yOff = yOff - 50
    FinalizeScroll(sc, rc, yOff)
end

local function BuildBuffIcons(subPage, page)
    local rc, sc = MakeSubPageScroll(subPage, "AyijeCDM_Text_BuffIconsScrollFrame")
    local yOff = 0

    SectionHeader(rc, L["Cooldown Timer"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Font Size"], 8, 32, "buffCooldownFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(rc, L["Color"], "buffCooldownColor", yOff); yOff = yOff - 45

    SectionHeader(rc, L["Stacks (Charges)"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Font Size"], 8, 32, "countFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(rc, L["Color"], "countColor", yOff); yOff = yOff - 45
    PositionDropdown(rc, L["Position"], "countPositionMain", yOff); yOff = yOff - 60
    Slider(page, rc, L["X Offset"], -20, 20, "countOffsetXMain", yOff, 0); yOff = yOff - 50
    Slider(page, rc, L["Y Offset"], -20, 20, "countOffsetYMain", yOff, 4); yOff = yOff - 50
    FinalizeScroll(sc, rc, yOff)
end

local function BuildBuffBars(subPage, page)
    local rc, sc = MakeSubPageScroll(subPage, "AyijeCDM_Text_BuffBarsScrollFrame")
    local yOff = 0

    SectionHeader(rc, L["Name Text"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Font Size"], 8, 24, "buffBarNameFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(rc, L["Color"], "buffBarNameColor", yOff); yOff = yOff - 45
    Slider(page, rc, L["X Offset"], -50, 50, "buffBarNameOffsetX", yOff, 2); yOff = yOff - 50
    Slider(page, rc, L["Y Offset"], -20, 20, "buffBarNameOffsetY", yOff, 0); yOff = yOff - 50

    SectionHeader(rc, L["Duration Text"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Font Size"], 8, 24, "buffBarDurationFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(rc, L["Color"], "buffBarDurationColor", yOff); yOff = yOff - 45
    Slider(page, rc, L["X Offset"], -50, 50, "buffBarDurationOffsetX", yOff, -2); yOff = yOff - 50
    Slider(page, rc, L["Y Offset"], -20, 20, "buffBarDurationOffsetY", yOff, 0); yOff = yOff - 50

    SectionHeader(rc, L["Stack Count Text"], yOff); yOff = yOff - 30
    Slider(page, rc, L["Font Size"], 8, 24, "buffBarApplicationsFontSize", yOff, 15); yOff = yOff - 60
    ColorSwatch(rc, L["Color"], "buffBarApplicationsColor", yOff); yOff = yOff - 45
    PositionDropdown(rc, L["Anchor"], "buffBarApplicationsPosition", yOff); yOff = yOff - 60
    Slider(page, rc, L["X Offset"], -50, 50, "buffBarApplicationsOffsetX", yOff, 0); yOff = yOff - 50
    Slider(page, rc, L["Y Offset"], -50, 50, "buffBarApplicationsOffsetY", yOff, 0); yOff = yOff - 50
    FinalizeScroll(sc, rc, yOff)
end

local SUB_TAB_IDS = { "global", "essential", "utility", "bufficons", "buffbars" }

local function CreateTextTab(page, tabId)
    local subTabs = UI.CreateSubTabBar(page, {
        { id = "global",    label = L["Global"] },
        { id = "essential", label = L["Essential"] },
        { id = "utility",   label = L["Utility"] },
        { id = "bufficons", label = L["Buff Icons"] },
        { id = "buffbars",  label = L["Buff Bars"] },
    }, "global")

    local divider = page:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    local dividerH = divider:GetHeight()
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", subTabs.barFrame, "BOTTOMLEFT", -30, 0)
    divider:SetPoint("TOPRIGHT", subTabs.barFrame, "BOTTOMRIGHT", 30, 0)
    divider:SetHeight(dividerH)

    for _, id in ipairs(SUB_TAB_IDS) do
        local pg = subTabs.subPages[id]
        pg:ClearAllPoints()
        pg:SetPoint("TOPLEFT", subTabs.barFrame, "BOTTOMLEFT", -30, -15)
        pg:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 20)
    end

    BuildGlobal(subTabs.subPages.global, page)
    BuildEssential(subTabs.subPages.essential, page)
    BuildUtility(subTabs.subPages.utility, page)
    BuildBuffIcons(subTabs.subPages.bufficons, page)
    BuildBuffBars(subTabs.subPages.buffbars, page)
end

API:RegisterConfigTab("text", L["Text"], CreateTextTab, 5)
