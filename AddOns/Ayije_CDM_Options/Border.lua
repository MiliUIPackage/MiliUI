-- Config/TabBorder.lua - Border Settings Tab
-- Controls for border texture, color, size, and offsets

local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function CreateBorderTab(page, tabId)
    -- Border Settings Header
    local borderHeader = UI.CreateHeader(page, L["Border Settings"])
    borderHeader:SetPoint("TOPLEFT", 35, -40)

    -- Border Texture Dropdown
    local lblDropdown = page:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblDropdown:SetText(L["Border Texture"])
    lblDropdown:SetPoint("TOPLEFT", borderHeader, "BOTTOMLEFT", 0, -15)

    local ddBorder = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    ddBorder:SetPoint("TOPLEFT", lblDropdown, "BOTTOMLEFT", 0, -10)
    ddBorder:SetWidth(220)
    ddBorder:SetDefaultText(CDM.db.borderFile or L["Select Border..."])
    page.dropdown = ddBorder

    UI.SetupMediaDropdown(
        ddBorder,
        "border",
        function() return CDM.db.borderFile end,
        function(name)
            CDM.db.borderFile = name
            API:RefreshConfig()
        end,
        function(name)
            ddBorder:SetDefaultText(name)
        end
    )

    -- Border Color
    local colorPicker = UI.CreateColorSwatch(page, L["Border Color"], "borderColor")
    colorPicker:SetPoint("TOPLEFT", ddBorder, "BOTTOMLEFT", 0, -15)
    page.colorPicker = colorPicker

    -- Border Size and Offsets
    page.controls.b0 = UI.CreateModernSlider(page, L["Border Size"], 1, 50, CDM.db.borderSize, function(v) CDM.db.borderSize = v; API:RefreshConfig() end)
    page.controls.b0:SetPoint("TOPLEFT", colorPicker, "BOTTOMLEFT", 0, -10)

    page.controls.b1 = UI.CreateModernSlider(page, L["Border Offset X"], -50, 50, CDM.db.borderOffsetX, function(v) CDM.db.borderOffsetX = v; API:RefreshConfig() end)
    page.controls.b1:SetPoint("TOPLEFT", page.controls.b0, "BOTTOMLEFT", 0, -10)

    page.controls.b2 = UI.CreateModernSlider(page, L["Border Offset Y"], -50, 50, CDM.db.borderOffsetY, function(v) CDM.db.borderOffsetY = v; API:RefreshConfig() end)
    page.controls.b2:SetPoint("TOPLEFT", page.controls.b1, "BOTTOMLEFT", 0, -10)

    -- Zoom Icons Toggle
    page.zoomCheckbox = UI.CreateModernCheckbox(
        page,
        L["Zoom Icons (Remove Borders & Overlay)"],
        CDM.db.zoomIcons,
        function(checked)
            CDM.db.zoomIcons = checked
            API:RefreshConfig()
        end
    )
    page.zoomCheckbox:SetPoint("TOPLEFT", page.controls.b2, "BOTTOMLEFT", 0, -10)

    -- Visual Elements Header
    local visualHeader = UI.CreateHeader(page, L["Visual Elements"])
    visualHeader:SetPoint("TOPLEFT", page.zoomCheckbox, "BOTTOMLEFT", 0, -15)

    -- Hide Debuff Border
    page.hideDebuffBorderCheckbox = UI.CreateModernCheckbox(
        page,
        L["Hide Debuff Border (red outline on harmful effects)"],
        CDM.db.hideDebuffBorder or false,
        function(checked)
            CDM.db.hideDebuffBorder = checked
        end
    )
    page.hideDebuffBorderCheckbox:SetPoint("TOPLEFT", visualHeader, "BOTTOMLEFT", 0, -15)

    -- Hide Pandemic Indicator
    page.hidePandemicCheckbox = UI.CreateModernCheckbox(
        page,
        L["Hide Pandemic Indicator (animated refresh window border)"],
        CDM.db.hidePandemicIndicator or false,
        function(checked)
            CDM.db.hidePandemicIndicator = checked
        end
    )
    page.hidePandemicCheckbox:SetPoint("TOPLEFT", page.hideDebuffBorderCheckbox, "BOTTOMLEFT", 0, -10)

    -- Hide Cooldown Bling
    page.hideCooldownBlingCheckbox = UI.CreateModernCheckbox(
        page,
        L["Hide Cooldown Bling (flash animation on cooldown completion)"],
        CDM.db.hideCooldownBling or false,
        function(checked)
            CDM.db.hideCooldownBling = checked
        end
    )
    page.hideCooldownBlingCheckbox:SetPoint("TOPLEFT", page.hidePandemicCheckbox, "BOTTOMLEFT", 0, -10)

    -- Reload warning
    local reloadWarning = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    reloadWarning:SetPoint("TOPLEFT", page.hideCooldownBlingCheckbox, "BOTTOMLEFT", 20, -15)
    reloadWarning:SetText(L["* These options require /reload to take effect"])
    UI.SetTextMuted(reloadWarning)
end

-- Register this tab
API:RegisterConfigTab("border", L["Borders"], CreateBorderTab, 4)
