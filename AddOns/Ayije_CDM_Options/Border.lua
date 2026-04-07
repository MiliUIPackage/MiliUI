local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


local function CreateBorderTab(page, tabId)
    local borderHeader = UI.CreateHeader(page, L["Border Settings"])
    borderHeader:SetPoint("TOPLEFT", 35, -40)

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
            API:Refresh()
        end,
        function(name)
            ddBorder:SetDefaultText(name)
        end
    )

    local colorPicker = UI.CreateColorSwatch(page, L["Border Color"], "borderColor")
    colorPicker:SetPoint("TOPLEFT", ddBorder, "BOTTOMLEFT", 0, -15)
    page.colorPicker = colorPicker

    page.controls.b0 = UI.CreateModernSlider(page, L["Border Size"], 1, 50, CDM.db.borderSize, function(v) CDM.db.borderSize = v; API:Refresh() end)
    page.controls.b0:SetPoint("TOPLEFT", colorPicker, "BOTTOMLEFT", 0, -10)

    page.controls.b1 = UI.CreateModernSlider(page, L["Border Offset X"], -50, 50, CDM.db.borderOffsetX, function(v) CDM.db.borderOffsetX = v; API:Refresh() end)
    page.controls.b1:SetPoint("TOPLEFT", page.controls.b0, "BOTTOMLEFT", 0, -10)

    page.controls.b2 = UI.CreateModernSlider(page, L["Border Offset Y"], -50, 50, CDM.db.borderOffsetY, function(v) CDM.db.borderOffsetY = v; API:Refresh() end)
    page.controls.b2:SetPoint("TOPLEFT", page.controls.b1, "BOTTOMLEFT", 0, -10)

    local function UpdateZoomLayout(showSlider)
        if showSlider then
            page.zoomSlider:Show()
            page.hideOverlayCheckbox:SetPoint("TOPLEFT", page.zoomSlider, "BOTTOMLEFT", -20, -10)
        else
            page.zoomSlider:Hide()
            page.hideOverlayCheckbox:SetPoint("TOPLEFT", page.zoomCheckbox, "BOTTOMLEFT", 0, -5)
        end
    end

    page.zoomCheckbox = UI.CreateModernCheckbox(
        page,
        L["Zoom Icons"],
        CDM.db.zoomIcons,
        function(checked)
            CDM.db.zoomIcons = checked
            UpdateZoomLayout(checked)
            API:Refresh()
        end
    )
    page.zoomCheckbox:SetPoint("TOPLEFT", page.controls.b2, "BOTTOMLEFT", 0, -10)

    page.zoomSlider = UI.CreateModernSliderPrecise(page, L["Zoom Amount"], 0, 0.3, CDM.db.zoomAmount or 0.08, 0.01, 2, function(v)
        CDM.db.zoomAmount = v
        API:Refresh()
    end)
    page.zoomSlider:SetPoint("TOPLEFT", page.zoomCheckbox, "BOTTOMLEFT", 20, -5)

    page.hideOverlayCheckbox = UI.CreateModernCheckbox(
        page,
        L["Remove Shadow Overlay"],
        CDM.db.hideIconOverlay ~= false,
        function(checked)
            CDM.db.hideIconOverlay = checked
            API:Refresh()
        end
    )

    UpdateZoomLayout(CDM.db.zoomIcons)

    page.hideOverlayTextureCheckbox = UI.CreateModernCheckbox(
        page,
        L["Remove Default Icon Mask"],
        CDM.db.hideIconOverlayTexture ~= false,
        function(checked)
            CDM.db.hideIconOverlayTexture = checked
            API:Refresh()
        end
    )
    page.hideOverlayTextureCheckbox:SetPoint("TOPLEFT", page.hideOverlayCheckbox, "BOTTOMLEFT", 0, -5)

    local visualHeader = UI.CreateHeader(page, L["Visual Elements"])
    visualHeader:SetPoint("TOPLEFT", page.hideOverlayTextureCheckbox, "BOTTOMLEFT", 0, -15)

    local reloadWarning = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    reloadWarning:SetPoint("LEFT", visualHeader, "RIGHT", 10, 0)
    reloadWarning:SetText(L["* These options require /reload to take effect"])
    UI.SetTextMuted(reloadWarning)

    page.hideDebuffBorderCheckbox = UI.CreateModernCheckbox(
        page,
        L["Hide Debuff Border (red outline on harmful effects)"],
        CDM.db.hideDebuffBorder or false,
        function(checked)
            CDM.db.hideDebuffBorder = checked
        end
    )
    page.hideDebuffBorderCheckbox:SetPoint("TOPLEFT", visualHeader, "BOTTOMLEFT", 0, -15)

    page.hidePandemicCheckbox = UI.CreateModernCheckbox(
        page,
        L["Hide Pandemic Indicator (animated refresh window border)"],
        CDM.db.hidePandemicIndicator or false,
        function(checked)
            CDM.db.hidePandemicIndicator = checked
        end
    )
    page.hidePandemicCheckbox:SetPoint("TOPLEFT", page.hideDebuffBorderCheckbox, "BOTTOMLEFT", 0, -10)

    page.hideCooldownBlingCheckbox = UI.CreateModernCheckbox(
        page,
        L["Hide Cooldown Bling (flash animation on cooldown completion)"],
        CDM.db.hideCooldownBling or false,
        function(checked)
            CDM.db.hideCooldownBling = checked
        end
    )
    page.hideCooldownBlingCheckbox:SetPoint("TOPLEFT", page.hidePandemicCheckbox, "BOTTOMLEFT", 0, -10)
end

API:RegisterConfigTab("border", L["Borders"], CreateBorderTab, 4)
