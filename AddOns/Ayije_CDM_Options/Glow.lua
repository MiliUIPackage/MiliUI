local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


local glowTypeOptions = {
    { value = "pixel", label = L["Pixel Glow"] },
    { value = "autocast", label = L["Autocast Glow"] },
    { value = "button", label = L["Button Glow"] },
    { value = "proc", label = L["Proc Glow"] },
}

local typeSections = {}

local function UpdateTypeSections(selectedType)
    for typeId, section in pairs(typeSections) do
        section:SetShown(typeId == selectedType)
    end
end

local function SliderValueToAutocastScale(sliderValue)
    return 1 + ((sliderValue - 1) * 0.25)
end

local function AutocastScaleToSliderValue(scale)
    local normalized = ((scale or 1) - 1) / 0.25
    local sliderValue = math.floor(normalized + 0.5) + 1
    return math.max(1, math.min(9, sliderValue))
end

local function CreateGlowTab(page, tabId)
    local scrollChild = page

    local mainHeader = UI.CreateHeader(scrollChild, L["Glow Settings"])
    mainHeader:SetPoint("TOPLEFT", 35, -40)

    local lblType = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblType:SetText(L["Glow Type"])
    lblType:SetPoint("TOPLEFT", mainHeader, "BOTTOMLEFT", 0, -15)

    local ddType = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddType:SetPoint("TOPLEFT", lblType, "BOTTOMLEFT", 0, -10)
    ddType:SetWidth(200)

    local function GetTypeLabel(value)
        for _, opt in ipairs(glowTypeOptions) do
            if opt.value == value then return opt.label end
        end
        return L["Proc Glow"]
    end
    ddType:SetDefaultText(GetTypeLabel(CDM.db.glowType or "proc"))

    UI.SetupValueDropdown(
        ddType,
        glowTypeOptions,
        function() return CDM.db.glowType or "proc" end,
        function(value, label)
            CDM.db.glowType = value
            ddType:SetDefaultText(label)
            UpdateTypeSections(value)
            API:Refresh()
        end
    )
    page.typeDropdown = ddType

    page.useColorCheckbox = UI.CreateModernCheckbox(
        scrollChild,
        L["Use Custom Color"],
        CDM.db.glowUseCustomColor or false,
        function(checked)
            CDM.db.glowUseCustomColor = checked
            API:Refresh()
        end
    )
    page.useColorCheckbox:SetPoint("TOPLEFT", ddType, "BOTTOMLEFT", 0, -15)

    local colorPicker = UI.CreateColorSwatch(scrollChild, L["Glow Color"], "glowColor")
    colorPicker:SetPoint("TOPLEFT", page.useColorCheckbox, "BOTTOMLEFT", 0, -10)
    page.colorPicker = colorPicker

    local sectionAnchor = colorPicker

    local pixelSection = CreateFrame("Frame", nil, scrollChild)
    pixelSection:SetPoint("TOPLEFT", sectionAnchor, "BOTTOMLEFT", 0, -15)
    pixelSection:SetSize(460, 300)
    typeSections["pixel"] = pixelSection

    local pixelHeader = UI.CreateSubHeader(pixelSection, L["Pixel Glow Settings"])
    pixelHeader:SetPoint("TOPLEFT", 0, 0)

    page.controls.pixelLines = UI.CreateModernSlider(
        pixelSection, L["Lines"], 1, 20, CDM.db.glowPixelLines or 8,
        function(v) CDM.db.glowPixelLines = v; API:Refresh() end
    )
    page.controls.pixelLines:SetPoint("TOPLEFT", pixelHeader, "BOTTOMLEFT", 0, -15)

    page.controls.pixelFrequency = UI.CreateModernSliderPrecise(
        pixelSection, L["Frequency"], -2, 2, CDM.db.glowPixelFrequency or 0.2, 0.05, 2,
        function(v) CDM.db.glowPixelFrequency = v; API:Refresh() end
    )
    page.controls.pixelFrequency:SetPoint("TOPLEFT", page.controls.pixelLines, "BOTTOMLEFT", 0, -10)

    page.controls.pixelLength = UI.CreateModernSlider(
        pixelSection, L["Length (0=auto)"], 0, 20, CDM.db.glowPixelLength or 0,
        function(v) CDM.db.glowPixelLength = v; API:Refresh() end
    )
    page.controls.pixelLength:SetPoint("TOPLEFT", page.controls.pixelFrequency, "BOTTOMLEFT", 0, -10)

    page.controls.pixelThickness = UI.CreateModernSlider(
        pixelSection, L["Thickness"], 1, 10, CDM.db.glowPixelThickness or 2,
        function(v) CDM.db.glowPixelThickness = v; API:Refresh() end
    )
    page.controls.pixelThickness:SetPoint("TOPLEFT", page.controls.pixelLength, "BOTTOMLEFT", 0, -10)

    page.controls.pixelXOffset = UI.CreateModernSlider(
        pixelSection, L["X Offset"], -20, 20, CDM.db.glowPixelXOffset or 0,
        function(v) CDM.db.glowPixelXOffset = v; API:Refresh() end
    )
    page.controls.pixelXOffset:SetPoint("TOPLEFT", page.controls.pixelThickness, "BOTTOMLEFT", 0, -10)

    page.controls.pixelYOffset = UI.CreateModernSlider(
        pixelSection, L["Y Offset"], -20, 20, CDM.db.glowPixelYOffset or 0,
        function(v) CDM.db.glowPixelYOffset = v; API:Refresh() end
    )
    page.controls.pixelYOffset:SetPoint("TOPLEFT", page.controls.pixelXOffset, "BOTTOMLEFT", 0, -10)

    local autocastSection = CreateFrame("Frame", nil, scrollChild)
    autocastSection:SetPoint("TOPLEFT", sectionAnchor, "BOTTOMLEFT", 0, -15)
    autocastSection:SetSize(460, 250)
    autocastSection:Hide()
    typeSections["autocast"] = autocastSection

    local autocastHeader = UI.CreateSubHeader(autocastSection, L["Autocast Glow Settings"])
    autocastHeader:SetPoint("TOPLEFT", 0, 0)

    page.controls.autocastParticles = UI.CreateModernSlider(
        autocastSection, L["Particles"], 1, 16, CDM.db.glowAutocastParticles or 4,
        function(v) CDM.db.glowAutocastParticles = v; API:Refresh() end
    )
    page.controls.autocastParticles:SetPoint("TOPLEFT", autocastHeader, "BOTTOMLEFT", 0, -15)

    page.controls.autocastFrequency = UI.CreateModernSliderPrecise(
        autocastSection, L["Frequency"], -2, 2, CDM.db.glowAutocastFrequency or 0.2, 0.05, 2,
        function(v) CDM.db.glowAutocastFrequency = v; API:Refresh() end
    )
    page.controls.autocastFrequency:SetPoint("TOPLEFT", page.controls.autocastParticles, "BOTTOMLEFT", 0, -10)

    page.controls.autocastScale = UI.CreateModernSlider(
        autocastSection, L["Scale"], 1, 9, AutocastScaleToSliderValue(CDM.db.glowAutocastScale or 1),
        function(v)
            CDM.db.glowAutocastScale = SliderValueToAutocastScale(v)
            API:Refresh()
        end
    )
    page.controls.autocastScale:SetPoint("TOPLEFT", page.controls.autocastFrequency, "BOTTOMLEFT", 0, -10)

    page.controls.autocastXOffset = UI.CreateModernSlider(
        autocastSection, L["X Offset"], -20, 20, CDM.db.glowAutocastXOffset or 0,
        function(v) CDM.db.glowAutocastXOffset = v; API:Refresh() end
    )
    page.controls.autocastXOffset:SetPoint("TOPLEFT", page.controls.autocastScale, "BOTTOMLEFT", 0, -10)

    page.controls.autocastYOffset = UI.CreateModernSlider(
        autocastSection, L["Y Offset"], -20, 20, CDM.db.glowAutocastYOffset or 0,
        function(v) CDM.db.glowAutocastYOffset = v; API:Refresh() end
    )
    page.controls.autocastYOffset:SetPoint("TOPLEFT", page.controls.autocastXOffset, "BOTTOMLEFT", 0, -10)

    local buttonSection = CreateFrame("Frame", nil, scrollChild)
    buttonSection:SetPoint("TOPLEFT", sectionAnchor, "BOTTOMLEFT", 0, -15)
    buttonSection:SetSize(460, 100)
    buttonSection:Hide()
    typeSections["button"] = buttonSection

    local buttonHeader = UI.CreateSubHeader(buttonSection, L["Button Glow Settings"])
    buttonHeader:SetPoint("TOPLEFT", 0, 0)

    page.controls.buttonFrequency = UI.CreateModernSlider(
        buttonSection, L["Frequency (0=default)"], 0, 100, math.floor((CDM.db.glowButtonFrequency or 0) * 100),
        function(v) CDM.db.glowButtonFrequency = v / 100; API:Refresh() end
    )
    page.controls.buttonFrequency:SetPoint("TOPLEFT", buttonHeader, "BOTTOMLEFT", 0, -15)

    local procSection = CreateFrame("Frame", nil, scrollChild)
    procSection:SetPoint("TOPLEFT", sectionAnchor, "BOTTOMLEFT", 0, -15)
    procSection:SetSize(460, 200)
    procSection:Hide()
    typeSections["proc"] = procSection

    local procHeader = UI.CreateSubHeader(procSection, L["Proc Glow Settings"])
    procHeader:SetPoint("TOPLEFT", 0, 0)

    page.controls.procDuration = UI.CreateModernSlider(
        procSection, L["Duration (x10)"], 1, 50, math.floor((CDM.db.glowProcDuration or 1) * 10),
        function(v) CDM.db.glowProcDuration = v / 10; API:Refresh() end
    )
    page.controls.procDuration:SetPoint("TOPLEFT", procHeader, "BOTTOMLEFT", 0, -15)

    page.controls.procXOffset = UI.CreateModernSlider(
        procSection, L["X Offset"], -20, 20, CDM.db.glowProcXOffset or 0,
        function(v) CDM.db.glowProcXOffset = v; API:Refresh() end
    )
    page.controls.procXOffset:SetPoint("TOPLEFT", page.controls.procDuration, "BOTTOMLEFT", 0, -10)

    page.controls.procYOffset = UI.CreateModernSlider(
        procSection, L["Y Offset"], -20, 20, CDM.db.glowProcYOffset or 0,
        function(v) CDM.db.glowProcYOffset = v; API:Refresh() end
    )
    page.controls.procYOffset:SetPoint("TOPLEFT", page.controls.procXOffset, "BOTTOMLEFT", 0, -10)

    UpdateTypeSections(CDM.db.glowType or "proc")
end

API:RegisterConfigTab("glow", L["Glow"], CreateGlowTab, 6)
