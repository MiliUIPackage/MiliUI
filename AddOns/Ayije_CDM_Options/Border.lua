local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function BuildBorders(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "AyijeCDM_Border_BordersScrollFrame")
    local yOff = 0

    local borderHeader = UI.CreateHeader(rc, L["Border Settings"])
    borderHeader:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 30

    local lblDropdown = rc:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblDropdown:SetText(L["Border Texture"])
    lblDropdown:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 25

    local ddBorder = CreateFrame("DropdownButton", nil, rc, "WowStyle1DropdownTemplate")
    ddBorder:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 40
    ddBorder:SetWidth(220)
    ddBorder:SetDefaultText(CDM.db.borderFile or L["Select Border..."])
    page.dropdown = ddBorder

    UI.SetupMediaDropdown(
        ddBorder,
        "border",
        function() return CDM.db.borderFile end,
        function(name)
            CDM.db.borderFile = name
            API:Refresh("STYLE")
        end,
        function(name)
            ddBorder:SetDefaultText(name)
        end
    )

    local colorPicker = UI.CreateColorSwatch(rc, L["Border Color"], "borderColor", "STYLE")
    colorPicker:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 45
    page.colorPicker = colorPicker

    page.controls.b0 = UI.CreateModernSlider(rc, L["Border Size"], 1, 50, CDM.db.borderSize, function(v) CDM.db.borderSize = v; API:Refresh("STYLE") end)
    page.controls.b0:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60

    page.controls.b1 = UI.CreateModernSlider(rc, L["Border Offset X"], -50, 50, CDM.db.borderOffsetX, function(v) CDM.db.borderOffsetX = v; API:Refresh("STYLE") end)
    page.controls.b1:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60

    page.controls.b2 = UI.CreateModernSlider(rc, L["Border Offset Y"], -50, 50, CDM.db.borderOffsetY, function(v) CDM.db.borderOffsetY = v; API:Refresh("STYLE") end)
    page.controls.b2:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 60

    local function UpdateZoomLayout(showSlider)
        if showSlider then
            page.zoomSlider:Show()
            page.hideOverlayCheckbox:ClearAllPoints()
            page.hideOverlayCheckbox:SetPoint("TOPLEFT", page.zoomSlider, "BOTTOMLEFT", -20, -10)
        else
            page.zoomSlider:Hide()
            page.hideOverlayCheckbox:ClearAllPoints()
            page.hideOverlayCheckbox:SetPoint("TOPLEFT", page.zoomCheckbox, "BOTTOMLEFT", 0, -5)
        end
    end

    page.zoomCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Zoom Icons"],
        CDM.db.zoomIcons,
        function(checked)
            CDM.db.zoomIcons = checked
            UpdateZoomLayout(checked)
            API:Refresh("STYLE")
        end
    )
    page.zoomCheckbox:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 35

    page.zoomSlider = UI.CreateModernSliderPrecise(rc, L["Zoom Amount"], 0, 0.3, CDM.db.zoomAmount or 0.08, 0.01, 2, function(v)
        CDM.db.zoomAmount = v
        API:Refresh("STYLE")
    end)
    page.zoomSlider:SetPoint("TOPLEFT", page.zoomCheckbox, "BOTTOMLEFT", 20, -5)
    if CDM.db.zoomIcons then yOff = yOff - 60 end

    page.hideOverlayCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Remove Shadow Overlay"],
        CDM.db.hideIconOverlay ~= false,
        function(checked)
            CDM.db.hideIconOverlay = checked
            API:Refresh("STYLE")
        end
    )
    yOff = yOff - 30

    page.hideOverlayTextureCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Remove Default Icon Mask"],
        CDM.db.hideIconOverlayTexture ~= false,
        function(checked)
            CDM.db.hideIconOverlayTexture = checked
            API:Refresh("STYLE")
        end
    )
    page.hideOverlayTextureCheckbox:SetPoint("TOPLEFT", page.hideOverlayCheckbox, "BOTTOMLEFT", 0, -5)
    yOff = yOff - 35

    UpdateZoomLayout(CDM.db.zoomIcons)

    local visualHeader = UI.CreateHeader(rc, L["Visual Elements"])
    visualHeader:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 30

    local reloadWarning = rc:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    reloadWarning:SetPoint("LEFT", visualHeader, "RIGHT", 10, 0)
    reloadWarning:SetText(L["* These options require /reload to take effect"])
    UI.SetTextMuted(reloadWarning)

    page.hideDebuffBorderCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Hide Debuff Border (red outline on harmful effects)"],
        CDM.db.hideDebuffBorder or false,
        function(checked)
            CDM.db.hideDebuffBorder = checked
        end
    )
    page.hideDebuffBorderCheckbox:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 30

    page.hideCooldownBlingCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Hide Cooldown Bling (flash animation on cooldown completion)"],
        CDM.db.hideCooldownBling or false,
        function(checked)
            CDM.db.hideCooldownBling = checked
        end
    )
    page.hideCooldownBlingCheckbox:SetPoint("TOPLEFT", 0, yOff); yOff = yOff - 30

    UI.FinalizeScroll(sc, rc, yOff)
end

local function BuildLook(subPage, page)
    local rc, sc = UI.MakeSubPageScroll(subPage, "AyijeCDM_Border_LookScrollFrame")
    local yOff = 0

    local pandemicHeader = UI.CreateHeader(rc, L["Pandemic Display"])
    pandemicHeader:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    local hidePandemicCheckbox
    local enableCustomizationCheckbox
    local pandemicBorderCheckbox
    local pandemicBorderColor

    local function UpdatePandemicEnableState()
        local hideEnabled = CDM.db.hidePandemicIndicator == true
        local customizationEnabled = hideEnabled and (CDM.db.pandemicCustomizationEnabled == true)

        enableCustomizationCheckbox:SetEnabled(hideEnabled)
        pandemicBorderCheckbox:SetEnabled(customizationEnabled)

        local borderColorEnabled = customizationEnabled and (CDM.db.pandemicBorderEnabled == true)
        pandemicBorderColor:SetEnabled(borderColorEnabled)
    end

    hidePandemicCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Hide Blizzard's Pandemic Indicator (animated refresh window border)"],
        CDM.db.hidePandemicIndicator or false,
        function(checked)
            CDM.db.hidePandemicIndicator = checked
            UpdatePandemicEnableState()
            API:Refresh("STYLE")
        end
    )
    hidePandemicCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    enableCustomizationCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Enable Pandemic Customization"],
        CDM.db.pandemicCustomizationEnabled or false,
        function(checked)
            CDM.db.pandemicCustomizationEnabled = checked
            UpdatePandemicEnableState()
            API:Refresh("STYLE")
        end
    )
    enableCustomizationCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 40

    pandemicBorderCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Custom Pandemic Border"],
        CDM.db.pandemicBorderEnabled or false,
        function(checked)
            CDM.db.pandemicBorderEnabled = checked
            UpdatePandemicEnableState()
            API:Refresh("STYLE")
        end
    )
    pandemicBorderCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    pandemicBorderColor = UI.CreateColorSwatch(rc, L["Color"], "pandemicBorderColor", "STYLE")
    pandemicBorderColor:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 50

    UpdatePandemicEnableState()

    local chargeHeader = UI.CreateHeader(rc, L["Charge Cooldowns"])
    chargeHeader:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    local showEdgeCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Show Edge"],
        CDM.db.chargeShowEdge or false,
        function(checked)
            CDM.db.chargeShowEdge = checked
            API:Refresh("STYLE")
        end
    )
    showEdgeCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    local hideSwipeCheckbox = UI.CreateModernCheckbox(
        rc,
        L["Hide Swipe"],
        CDM.db.chargeHideSwipe or false,
        function(checked)
            CDM.db.chargeHideSwipe = checked
            API:Refresh("STYLE")
        end
    )
    hideSwipeCheckbox:SetPoint("TOPLEFT", 0, yOff)
    yOff = yOff - 30

    UI.FinalizeScroll(sc, rc, yOff)
end

local SUB_TAB_IDS = { "borders", "look" }

local function CreateBorderTab(page, tabId)
    local subTabs = UI.CreateSubTabBar(page, {
        { id = "borders", label = L["Borders"] },
        { id = "look",    label = L["Look"] },
    }, "borders")

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

    BuildBorders(subTabs.subPages.borders, page)
    BuildLook(subTabs.subPages.look, page)
end

API:RegisterConfigTab("border", L["Borders & Look"], CreateBorderTab, 4)
