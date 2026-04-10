local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


local function CreateAssistTab(page, tabId)
    local scrollChild = UI.CreateScrollableTab(page, "AyijeCDM_AssistScrollFrame", 700, 370)

    local poHeader = UI.CreateHeader(scrollChild, L["Press Overlay"])
    poHeader:SetPoint("TOPLEFT", 0, 0)

    local setPOControlsEnabled
    page.controls.pressOverlayEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Press Overlay"],
        CDM.db.pressOverlayEnabled or false,
        function(checked)
            CDM.db.pressOverlayEnabled = checked
            if setPOControlsEnabled then setPOControlsEnabled(checked) end
            API:Refresh("STYLE")
        end
    )
    page.controls.pressOverlayEnabled:SetPoint("TOPLEFT", poHeader, "BOTTOMLEFT", 0, -15)

    local settingExclusive = false
    local function SetExclusiveStyle(activeKey)
        if settingExclusive then return end
        settingExclusive = true
        local keys = { "pressOverlayTint", "pressOverlayHighlight", "pressOverlayBorder" }
        for _, key in ipairs(keys) do
            CDM.db[key] = (key == activeKey)
        end
        if page.controls.pressOverlayTint then
            page.controls.pressOverlayTint:SetChecked(activeKey == "pressOverlayTint")
        end
        if page.controls.pressOverlayHighlight then
            page.controls.pressOverlayHighlight:SetChecked(activeKey == "pressOverlayHighlight")
        end
        if page.controls.pressOverlayBorder then
            page.controls.pressOverlayBorder:SetChecked(activeKey == "pressOverlayBorder")
        end
        settingExclusive = false
        API:Refresh("STYLE")
    end

    page.controls.pressOverlayTint = UI.CreateModernCheckbox(
        scrollChild,
        L["Color Tint"],
        CDM.db.pressOverlayTint or false,
        function(checked)
            if checked then SetExclusiveStyle("pressOverlayTint") end
        end
    )
    page.controls.pressOverlayTint:SetPoint("TOPLEFT", page.controls.pressOverlayEnabled, "BOTTOMLEFT", 0, -10)

    page.pressOverlayTintColorPicker = UI.CreateColorSwatch(scrollChild, L["Tint Color"], "pressOverlayTintColor", "STYLE")
    page.pressOverlayTintColorPicker:SetPoint("TOPLEFT", page.controls.pressOverlayTint, "BOTTOMLEFT", 0, -10)

    page.controls.pressOverlayHighlight = UI.CreateModernCheckbox(
        scrollChild,
        L["Highlight"],
        CDM.db.pressOverlayHighlight or false,
        function(checked)
            if checked then SetExclusiveStyle("pressOverlayHighlight") end
        end
    )
    page.controls.pressOverlayHighlight:SetPoint("TOPLEFT", page.pressOverlayTintColorPicker, "BOTTOMLEFT", 0, -10)

    page.controls.pressOverlayBorder = UI.CreateModernCheckbox(
        scrollChild,
        L["Border"],
        CDM.db.pressOverlayBorder or false,
        function(checked)
            if checked then SetExclusiveStyle("pressOverlayBorder") end
        end
    )
    page.controls.pressOverlayBorder:SetPoint("TOPLEFT", page.controls.pressOverlayHighlight, "BOTTOMLEFT", 0, -10)

    for _, ctrl in ipairs({ page.controls.pressOverlayTint, page.controls.pressOverlayHighlight, page.controls.pressOverlayBorder }) do
        local cb = ctrl.checkbox
        local origScript = cb:GetScript("OnClick")
        cb:SetScript("OnClick", function(self)
            if not self:GetChecked() then
                self:SetChecked(true)
                return
            end
            origScript(self)
        end)
    end

    page.pressOverlayBorderColorPicker = UI.CreateColorSwatch(scrollChild, L["Border Color"], "pressOverlayBorderColor", "STYLE")
    page.pressOverlayBorderColorPicker:SetPoint("TOPLEFT", page.controls.pressOverlayBorder, "BOTTOMLEFT", 0, -10)

    local poControls = {
        page.controls.pressOverlayTint, page.pressOverlayTintColorPicker,
        page.controls.pressOverlayHighlight,
        page.controls.pressOverlayBorder, page.pressOverlayBorderColorPicker,
    }

    local poOverlay = CreateFrame("Frame", nil, scrollChild)
    poOverlay:SetPoint("TOPLEFT", page.controls.pressOverlayTint, "TOPLEFT")
    poOverlay:SetPoint("BOTTOMRIGHT", page.pressOverlayBorderColorPicker, "BOTTOMRIGHT")
    local poMaxLevel = 0
    for _, ctrl in ipairs(poControls) do
        local lvl = ctrl:GetFrameLevel()
        if lvl > poMaxLevel then poMaxLevel = lvl end
    end
    poOverlay:SetFrameLevel(poMaxLevel + 10)
    poOverlay:EnableMouse(true)
    poOverlay:Hide()

    setPOControlsEnabled = function(en)
        local alpha = en and 1 or 0.35
        for _, ctrl in ipairs(poControls) do
            ctrl:SetAlpha(alpha)
        end
        poOverlay:SetShown(not en)
    end
    setPOControlsEnabled(CDM.db.pressOverlayEnabled or false)
    
    local raHeader = UI.CreateHeader(scrollChild, L["Rotation Assist"])
    raHeader:SetPoint("TOPLEFT", page.pressOverlayBorderColorPicker, "BOTTOMLEFT", 0, -20)

    local setRAControlsEnabled
    page.controls.rotationAssistEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Rotation Assist"],
        CDM.db.rotationAssistEnabled or false,
        function(checked)
            CDM.db.rotationAssistEnabled = checked
            if setRAControlsEnabled then setRAControlsEnabled(checked) end
            API:Refresh("STYLE")
        end
    )
    page.controls.rotationAssistEnabled:SetPoint("TOPLEFT", raHeader, "BOTTOMLEFT", 0, -15)

    page.controls.rotationAssistGlowRatio = UI.CreateModernSliderPrecise(
        scrollChild, L["Highlight Size"], 0.2, 0.4, CDM.db.rotationAssistGlowRatio or 0.33, 0.01, 2,
        function(v)
            CDM.db.rotationAssistGlowRatio = v
            API:Refresh("STYLE")
        end
    )
    page.controls.rotationAssistGlowRatio:SetPoint("TOPLEFT", page.controls.rotationAssistEnabled, "BOTTOMLEFT", 0, -15)

    local raOverlay = CreateFrame("Frame", nil, scrollChild)
    raOverlay:SetPoint("TOPLEFT", page.controls.rotationAssistGlowRatio, "TOPLEFT")
    raOverlay:SetPoint("BOTTOMRIGHT", page.controls.rotationAssistGlowRatio, "BOTTOMRIGHT")
    raOverlay:SetFrameLevel(page.controls.rotationAssistGlowRatio:GetFrameLevel() + 10)
    raOverlay:EnableMouse(true)
    raOverlay:Hide()

    setRAControlsEnabled = function(en)
        page.controls.rotationAssistGlowRatio:SetAlpha(en and 1 or 0.35)
        raOverlay:SetShown(not en)
    end
    setRAControlsEnabled(CDM.db.rotationAssistEnabled or false)

    local mainHeader = UI.CreateHeader(scrollChild, L["Keybindings"])
    mainHeader:SetPoint("TOPLEFT", page.controls.rotationAssistGlowRatio, "BOTTOMLEFT", 0, -20)

    local setKBControlsEnabled
    page.controls.assistEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Keybind Text"],
        CDM.db.assistEnabled or false,
        function(checked)
            CDM.db.assistEnabled = checked
            if setKBControlsEnabled then setKBControlsEnabled(checked) end
            API:Refresh("STYLE")
        end
    )
    page.controls.assistEnabled:SetPoint("TOPLEFT", mainHeader, "BOTTOMLEFT", 0, -15)

    page.controls.assistFontSize = UI.CreateModernSlider(
        scrollChild, L["Font Size"], 1, 30, CDM.db.assistFontSize or 15,
        function(v)
            CDM.db.assistFontSize = v
            API:Refresh("STYLE")
        end
    )
    page.controls.assistFontSize:SetPoint("TOPLEFT", page.controls.assistEnabled, "BOTTOMLEFT", 0, -15)

    page.assistColorPicker = UI.CreateColorSwatch(scrollChild, L["Color"], "assistColor", "STYLE")
    page.assistColorPicker:SetPoint("TOPLEFT", page.controls.assistFontSize, "BOTTOMLEFT", 0, -15)

    local lblPos = scrollChild:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    lblPos:SetText(L["Position"])
    lblPos:SetPoint("TOPLEFT", page.assistColorPicker, "BOTTOMLEFT", 0, -15)

    local ddPos = CreateFrame("DropdownButton", nil, scrollChild, "WowStyle1DropdownTemplate")
    ddPos:SetPoint("TOPLEFT", lblPos, "BOTTOMLEFT", 0, -10)
    ddPos:SetWidth(180)
    ddPos:SetDefaultText(CDM.db.assistPosition or "TOPRIGHT")
    page.assistPosDropdown = ddPos

    UI.SetupPositionDropdown(
        ddPos,
        function() return CDM.db.assistPosition end,
        function(pos)
            CDM.db.assistPosition = pos
            ddPos:SetDefaultText(pos)
            API:Refresh("STYLE")
        end
    )

    page.controls.assistOffsetX = UI.CreateModernSlider(
        scrollChild, L["X Offset"], -20, 20, CDM.db.assistOffsetX or 0,
        function(v)
            CDM.db.assistOffsetX = v
            API:Refresh("STYLE")
        end
    )
    page.controls.assistOffsetX:SetPoint("TOPLEFT", ddPos, "BOTTOMLEFT", 0, -15)

    page.controls.assistOffsetY = UI.CreateModernSlider(
        scrollChild, L["Y Offset"], -20, 20, CDM.db.assistOffsetY or 0,
        function(v)
            CDM.db.assistOffsetY = v
            API:Refresh("STYLE")
        end
    )
    page.controls.assistOffsetY:SetPoint("TOPLEFT", page.controls.assistOffsetX, "BOTTOMLEFT", 0, -15)

    local kbControls = {
        page.controls.assistFontSize, page.assistColorPicker,
        ddPos, page.controls.assistOffsetX, page.controls.assistOffsetY,
    }
    local kbRegions = { lblPos }

    local kbOverlay = CreateFrame("Frame", nil, scrollChild)
    kbOverlay:SetPoint("TOPLEFT", page.controls.assistFontSize, "TOPLEFT")
    kbOverlay:SetPoint("BOTTOMRIGHT", page.controls.assistOffsetY, "BOTTOMRIGHT")
    local maxLevel = 0
    for _, ctrl in ipairs(kbControls) do
        local lvl = ctrl:GetFrameLevel()
        if lvl > maxLevel then maxLevel = lvl end
    end
    kbOverlay:SetFrameLevel(maxLevel + 10)
    kbOverlay:EnableMouse(true)
    kbOverlay:Hide()

    setKBControlsEnabled = function(en)
        local alpha = en and 1 or 0.35
        for _, ctrl in ipairs(kbControls) do
            ctrl:SetAlpha(alpha)
        end
        for _, region in ipairs(kbRegions) do
            region:SetAlpha(alpha)
        end
        kbOverlay:SetShown(not en)
    end
    setKBControlsEnabled(CDM.db.assistEnabled or false)
end

API:RegisterConfigTab("assist", L["Assist"], CreateAssistTab, 7.5)
