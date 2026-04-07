local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


function ns._CreateExternalsPanel(page, parentPage)
    local divider = page:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", page, "TOP", 0, 0)

    local content = CreateFrame("Frame", nil, page)
    content:SetPoint("TOPLEFT", 35, -40)
    content:SetPoint("BOTTOMRIGHT", -25, 20)

    local layout = UI.CreateVerticalLayout(0)
    local function NextY(spacing) return layout:Next(spacing) end

    local enabled = CDM.db.externalsEnabled
    if enabled == nil then enabled = true end
    local setControlsEnabled
    page.controls.externalsEnabled = UI.CreateModernCheckbox(
        content,
        L["Enable Externals"] or "Enable Externals",
        enabled,
        function(checked)
            CDM.db.externalsEnabled = checked
            if setControlsEnabled then setControlsEnabled(checked) end
            API:Refresh()
        end
    )
    page.controls.externalsEnabled:SetPoint("TOPLEFT", -34, NextY(0))
    NextY(35)

    local iconSizeHeader = UI.CreateHeader(content, L["Icon Size"] or "Icon Size")
    iconSizeHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(15)

    page.controls.externalsIconWidthSlider = UI.CreateModernSlider(
        content,
        L["Icon Width"] or "Icon Width",
        20, 100,
        CDM.db.externalsIconWidth or 30,
        function(v)
            CDM.db.externalsIconWidth = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.controls.externalsIconWidthSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    page.controls.externalsIconHeightSlider = UI.CreateModernSlider(
        content,
        L["Icon Height"] or "Icon Height",
        20, 100,
        CDM.db.externalsIconHeight or 30,
        function(v)
            CDM.db.externalsIconHeight = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.controls.externalsIconHeightSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    local cooldownHeader = UI.CreateHeader(content, L["Cooldown"] or "Cooldown")
    cooldownHeader:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(15)

    page.controls.externalsCooldownFontSizeSlider = UI.CreateModernSlider(
        content,
        L["Font Size"] or "Font Size",
        8, 32,
        CDM.db.externalsCooldownFontSize or 15,
        function(v)
            CDM.db.externalsCooldownFontSize = UI.RoundToInt(v)
            API:Refresh()
        end
    )
    page.controls.externalsCooldownFontSizeSlider:SetPoint("TOPLEFT", 0, NextY(0))
    NextY(60)

    local blinkDefault = CDM.db.externalsDisableBlink
    if blinkDefault == nil then blinkDefault = true end
    page.controls.externalsDisableBlinkCheckbox = UI.CreateModernCheckbox(
        content,
        L["Disable Blink"] or "Disable Blink",
        blinkDefault,
        function(checked)
            CDM.db.externalsDisableBlink = checked
            API:Refresh()
        end
    )
    page.controls.externalsDisableBlinkCheckbox:SetPoint("TOPLEFT", 0, NextY(0))

    setControlsEnabled = UI.SetupModuleToggle(page, page.controls.externalsEnabled)
    setControlsEnabled(enabled)
end
