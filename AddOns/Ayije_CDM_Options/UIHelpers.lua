local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local CDM_C = CDM and CDM.CONST or {}
local LSM = LibStub("LibSharedMedia-3.0")

ns.ConfigUI = ns.ConfigUI or {}
local UI = ns.ConfigUI

local GOLD = CDM_C.GOLD or { r = 1, g = 0.82, b = 0, a = 1 }
local WHITE = CDM_C.WHITE or { r = 1, g = 1, b = 1, a = 1 }

local colorSwatchesByKey = {}

local function BroadcastSwatchColor(key, r, g, b, a)
    local swatches = colorSwatchesByKey[key]
    if not swatches then return end
    for swatchFrame in pairs(swatches) do
        swatchFrame:UpdateColor(r, g, b, a)
    end
end

function UI.CreateColorSwatch(parent, label, key)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(250, 30)

    local text = frame:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    text:SetPoint("LEFT", 0, 0)
    text:SetText(label)

    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetSize(20, 20)
    button:SetPoint("LEFT", 140, 0)
    button:SetBackdrop({
        edgeFile = CDM_C.TEX_WHITE8X8, edgeSize = 1,
        bgFile = CDM_C.TEX_WHITE8X8,
    })

    local color = CDM.db[key] or CDM.defaults[key] or CDM.defaults.borderColor
    button:SetBackdropColor(color.r, color.g, color.b, color.a)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    if not colorSwatchesByKey[key] then
        colorSwatchesByKey[key] = setmetatable({}, { __mode = "k" })
    end
    colorSwatchesByKey[key][frame] = true

    function frame:UpdateColor(r, g, b, a)
        button:SetBackdropColor(r, g, b, a)
        if frame.OnChange then
            frame.OnChange(r, g, b, a)
        end
    end

    button:SetScript("OnClick", function()
        local color = CDM.db[key] or CDM.defaults[key] or CDM.defaults.borderColor
        local function ApplyPickedColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = ColorPickerFrame:GetColorAlpha()
            CDM.db[key] = { r = r, g = g, b = b, a = a }
            BroadcastSwatchColor(key, r, g, b, a)
            API:RefreshConfig()
        end

        local info = {
            swatchFunc = ApplyPickedColor,
            opacityFunc = ApplyPickedColor,
            cancelFunc = function(prev)
                CDM.db[key] = prev
                BroadcastSwatchColor(key, prev.r, prev.g, prev.b, prev.a)
                API:RefreshConfig()
            end,
            r = color.r, g = color.g, b = color.b, opacity = color.a,
            hasOpacity = true,
            previousValues = { r = color.r, g = color.g, b = color.b, a = color.a }
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    return frame
end

local function CreateSectionHeader(parent, text, anchorFrame, yOffset, fontObject, anchoredOffset, topOffset)
    local header = parent:CreateFontString(nil, "ARTWORK", fontObject)
    if anchorFrame then
        header:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, yOffset or anchoredOffset)
    else
        header:SetPoint("TOPLEFT", 0, yOffset or topOffset)
    end
    header:SetText(text)
    header:SetTextColor(GOLD.r, GOLD.g, GOLD.b, GOLD.a or 1)
    return header
end

function UI.CreateSimpleColorPicker(parent, initialColor, onChange)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(20, 20)
    button:SetBackdrop({
        edgeFile = CDM_C.TEX_WHITE8X8, edgeSize = 1,
        bgFile = CDM_C.TEX_WHITE8X8,
    })

    local color = initialColor or {r = 1, g = 1, b = 1}
    button:SetBackdropColor(color.r, color.g, color.b, 1)
    button:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    function button:UpdateColor(r, g, b)
        button:SetBackdropColor(r, g, b, 1)
        color.r, color.g, color.b = r, g, b
    end

    button:SetScript("OnClick", function()
        local prevR, prevG, prevB = color.r, color.g, color.b
        local info = {
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                button:UpdateColor(r, g, b)
                if onChange then
                    onChange(r, g, b)
                end
            end,
            cancelFunc = function()
                button:UpdateColor(prevR, prevG, prevB)
                if onChange then
                    onChange(prevR, prevG, prevB)
                end
            end,
            r = color.r, g = color.g, b = color.b,
            hasOpacity = false,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    return button
end

function UI.CreateModernSlider(parent, label, minVal, maxVal, currentVal, onValueChanged)
    local function toInt(v)
        if v >= 0 then return math.floor(v) else return math.ceil(v) end
    end

    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(400, 40)

    panel.Label = panel:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    panel.Label:SetPoint("LEFT", 0, 0)
    panel.Label:SetText(label)
    panel.Label:SetWidth(200)
    panel.Label:SetJustifyH("LEFT")

    local initVal = toInt(currentVal)

    panel.Slider = CreateFrame("Slider", nil, panel, "MinimalSliderWithSteppersTemplate")
    panel.Slider:SetPoint("LEFT", panel.Label, "RIGHT", 4, 0)
    panel.Slider:SetWidth(240)
    panel.Slider:Init(initVal, minVal, maxVal, (maxVal - minVal), {
        [MinimalSliderWithSteppersMixin.Label.Top] = nil,
        [MinimalSliderWithSteppersMixin.Label.Right] = nil
    })

    local eb = CreateFrame("EditBox", nil, panel)
    eb:SetSize(50, 18)
    eb:SetPoint("BOTTOM", panel.Slider, "TOP", 0, -8)
    eb:SetFontObject("AyijeCDM_Font14")
    eb:SetJustifyH("CENTER")
    eb:SetTextInsets(0, 0, 0, 0)
    eb:SetAutoFocus(false)
    panel.Input = eb

    panel.Slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        local numVal = tonumber(value)
        if not numVal then numVal = minVal end
        local val = toInt(numVal)
---@diagnostic disable-next-line: param-type-mismatch
        if not panel.Input:HasFocus() then panel.Input:SetText(val) end
        onValueChanged(val)
    end)

    panel.Input:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val then
            val = math.max(minVal, math.min(maxVal, val))
            self:SetText(val)
            panel.Slider:SetValue(val)
        end
        self:ClearFocus()
    end)

    panel.Input:SetScript("OnEscapePressed", function(self)
        self:SetText(toInt(panel.Slider:GetValue()))
        self:ClearFocus()
    end)

    panel.Input:SetText(initVal)

    function panel:UpdateUIValue(value)
        local clamped = math.max(minVal, math.min(maxVal, toInt(value)))
        panel.Slider:SetValue(clamped)
        panel.Input:SetText(clamped)
    end

    return panel
end

function UI.CreateModernSliderPrecise(parent, label, minVal, maxVal, currentVal, step, decimals, onValueChanged)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(400, 40)

    local valueStep = tonumber(step) or 0.05
    if valueStep <= 0 then
        valueStep = 0.05
    end

    local valueDecimals = tonumber(decimals) or 2
    if valueDecimals < 0 then
        valueDecimals = 0
    end

    local factor = 10 ^ valueDecimals
    local function RoundNearest(value)
        if value >= 0 then
            return math.floor(value + 0.5)
        end
        return math.ceil(value - 0.5)
    end

    local minScaled = RoundNearest(minVal * factor)
    local maxScaled = RoundNearest(maxVal * factor)
    local stepScaled = math.max(1, RoundNearest(valueStep * factor))

    local function ClampAndQuantize(value)
        local numVal = tonumber(value)
        if not numVal then
            numVal = minVal
        end

        local scaled = RoundNearest(numVal * factor)
        scaled = math.max(minScaled, math.min(maxScaled, scaled))
        local stepsFromMin = (scaled - minScaled) / stepScaled
        local snappedSteps = RoundNearest(stepsFromMin)
        local quantizedScaled = minScaled + (snappedSteps * stepScaled)
        quantizedScaled = math.max(minScaled, math.min(maxScaled, quantizedScaled))
        return quantizedScaled / factor
    end

    local function ToScaled(value)
        return RoundNearest(ClampAndQuantize(value) * factor)
    end

    local function FormatValue(value)
        local asString = string.format("%." .. valueDecimals .. "f", value)
        asString = asString:gsub("(%..-)0+$", "%1")
        asString = asString:gsub("%.$", "")
        return asString
    end

    panel.Label = panel:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    panel.Label:SetPoint("LEFT", 0, 0)
    panel.Label:SetText(label)
    panel.Label:SetWidth(200)
    panel.Label:SetJustifyH("LEFT")

    panel.Slider = CreateFrame("Slider", nil, panel, "MinimalSliderWithSteppersTemplate")
    panel.Slider:SetPoint("LEFT", panel.Label, "RIGHT", 4, 0)
    panel.Slider:SetWidth(240)
    local numSteps = math.max(1, RoundNearest((maxScaled - minScaled) / stepScaled))
    panel.Slider:Init(ToScaled(currentVal), minScaled, maxScaled, numSteps, {
        [MinimalSliderWithSteppersMixin.Label.Top] = nil,
        [MinimalSliderWithSteppersMixin.Label.Right] = nil
    })

    local eb = CreateFrame("EditBox", nil, panel)
    eb:SetSize(50, 18)
    eb:SetPoint("BOTTOM", panel.Slider, "TOP", 0, -8)
    eb:SetFontObject("AyijeCDM_Font14")
    eb:SetJustifyH("CENTER")
    eb:SetTextInsets(0, 0, 0, 0)
    eb:SetAutoFocus(false)
    panel.Input = eb

    panel.Slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        local quantized = ClampAndQuantize((tonumber(value) or minScaled) / factor)
---@diagnostic disable-next-line: param-type-mismatch
        if not panel.Input:HasFocus() then panel.Input:SetText(FormatValue(quantized)) end
        onValueChanged(quantized)
    end)

    panel.Input:SetScript("OnEnterPressed", function(self)
        local quantized = ClampAndQuantize(self:GetText())
        self:SetText(FormatValue(quantized))
        panel.Slider:SetValue(ToScaled(quantized))
        self:ClearFocus()
    end)

    panel.Input:SetScript("OnEscapePressed", function(self)
        self:SetText(FormatValue(ClampAndQuantize((panel.Slider:GetValue() or minScaled) / factor)))
        self:ClearFocus()
    end)

    panel.Input:SetText(FormatValue(ClampAndQuantize(currentVal)))

    function panel:UpdateUIValue(value)
        local quantized = ClampAndQuantize(value)
        panel.Slider:SetValue(ToScaled(quantized))
        panel.Input:SetText(FormatValue(quantized))
    end

    return panel
end

function UI.RoundToInt(value)
    local num = tonumber(value)
    if not num then return 0 end
    return math.floor(num + 0.5)
end

function UI.CreateModernCheckbox(parent, label, initialValue, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(400, 26)

    local checkbox = CreateFrame("CheckButton", nil, frame)
    checkbox:SetSize(26, 26)
    checkbox:SetPoint("LEFT", 0, 0)

    checkbox:SetNormalAtlas("checkbox-minimal")
    checkbox:SetPushedAtlas("checkbox-minimal")
    checkbox:SetCheckedTexture("checkmark-minimal")
    checkbox:GetCheckedTexture():SetAtlas("checkmark-minimal")

    local highlight = checkbox:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetAtlas("checkbox-minimal")
    highlight:SetAlpha(0.3)

    local text = frame:CreateFontString(nil, "ARTWORK", "AyijeCDM_Font14")
    text:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
    text:SetText(label)

    checkbox:SetChecked(initialValue or false)

    checkbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if onChange then
            onChange(checked)
        end
    end)

    frame.checkbox = checkbox
    frame.label = text

    function frame:SetChecked(checked)
        checkbox:SetChecked(checked)
    end

    function frame:GetChecked()
        return checkbox:GetChecked()
    end

    return frame
end

function UI.CreateHeader(parent, text, anchorFrame, yOffset)
    return CreateSectionHeader(parent, text, anchorFrame, yOffset, "AyijeCDM_Font18", -15, -10)
end

function UI.CreateSubHeader(parent, text, anchorFrame, yOffset)
    return CreateSectionHeader(parent, text, anchorFrame, yOffset, "AyijeCDM_Font14", -12, -10)
end

UI.TextColors = UI.TextColors or {
    white = { r = WHITE.r, g = WHITE.g, b = WHITE.b, a = WHITE.a or 1 },
    muted = { r = 0.7, g = 0.7, b = 0.7, a = 1 },
    dim = { r = 0.6, g = 0.6, b = 0.6, a = 1 },
    subtle = { r = 0.8, g = 0.8, b = 0.8, a = 1 },
    faint = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
    placeholder = { r = 0.55, g = 0.55, b = 0.55, a = 1 },
    inactive = { r = 0.82, g = 0.82, b = 0.82, a = 1 },
    success = { r = 0.5, g = 1, b = 0.5, a = 1 },
    error = { r = 1, g = 0.3, b = 0.3, a = 1 },
}

function UI.SetTextColor(fontString, color)
    if not fontString or not color then return end
    fontString:SetTextColor(color.r, color.g, color.b, color.a or 1)
end

function UI.SetTextMuted(fontString)
    UI.SetTextColor(fontString, UI.TextColors.muted)
end

function UI.SetTextDim(fontString)
    UI.SetTextColor(fontString, UI.TextColors.dim)
end

function UI.SetTextSubtle(fontString)
    UI.SetTextColor(fontString, UI.TextColors.subtle)
end

function UI.SetTextFaint(fontString)
    UI.SetTextColor(fontString, UI.TextColors.faint)
end

function UI.SetTextPlaceholder(fontString)
    UI.SetTextColor(fontString, UI.TextColors.placeholder)
end

function UI.SetTextInactive(fontString)
    UI.SetTextColor(fontString, UI.TextColors.inactive)
end

function UI.SetTextWhite(fontString)
    UI.SetTextColor(fontString, UI.TextColors.white)
end

function UI.SetTextSuccess(fontString)
    UI.SetTextColor(fontString, UI.TextColors.success)
end

function UI.SetTextError(fontString)
    UI.SetTextColor(fontString, UI.TextColors.error)
end

function UI.CreateScrollableTab(page, frameName, contentHeight, contentWidth)
    local scrollFrame = CreateFrame("ScrollFrame", frameName, page, "ScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -20)
    scrollFrame:SetPoint("BOTTOMRIGHT", -10, 20)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(contentWidth or 460, contentHeight or 800)
    scrollFrame:SetScrollChild(scrollChild)

    -- Offset to match non-scrollable tab positioning: page+(35,-40) → scroll+(35,-20)
    local contentContainer = CreateFrame("Frame", nil, scrollChild)
    contentContainer:SetPoint("TOPLEFT", 35, -20)
    contentContainer:SetPoint("TOPRIGHT", -25, -20)
    contentContainer:SetHeight(contentHeight or 800)

    return contentContainer, scrollFrame
end

function UI.CreateVerticalLayout(startY)
    local layout = { y = startY or 0 }
    function layout:Next(spacing)
        self.y = self.y - spacing
        return self.y
    end
    return layout
end

UI.PositionOptions = {
    "CENTER", "TOP", "BOTTOM", "LEFT", "RIGHT",
    "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
}

function UI.SetupValueDropdown(dropdown, options, getValue, setValue)
    dropdown:SetupMenu(function(_, rootDescription)
        for _, opt in ipairs(options) do
            rootDescription:CreateRadio(opt.label, function() return getValue() == opt.value end, function()
                setValue(opt.value, opt.label)
            end)
        end
    end)
end

function UI.SetupPositionDropdown(dropdown, getValue, setValue, positions)
    local options = positions or UI.PositionOptions
    dropdown:SetupMenu(function(_, rootDescription)
        for _, pos in ipairs(options) do
            rootDescription:CreateRadio(pos, function() return getValue() == pos end, function()
                setValue(pos)
            end)
        end
    end)
end

function UI.SetupMediaDropdown(dropdown, mediaType, getValue, setValue, setText)
    dropdown:SetupMenu(function(_, rootDescription)
        rootDescription:SetScrollMode(500)
        local mediaList = LSM:List(mediaType) or {}
        table.sort(mediaList)
        local seenPaths = {}
        for _, name in ipairs(mediaList) do
            local path = LSM:Fetch(mediaType, name)
            if not path or not seenPaths[path] then
                if path then seenPaths[path] = true end
                rootDescription:CreateRadio(name, function() return getValue() == name end, function()
                    setValue(name)
                    if setText then
                        setText(name)
                    end
                end)
            end
        end
    end)
end

function UI.ClearChildren(frame)
    for _, child in ipairs({frame:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
end

function UI.CreateScrollableEditBox(parent, width, height, editWidth)
    local boxFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    boxFrame:SetSize(width, height)
    boxFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    boxFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    boxFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local scrollFrame = CreateFrame("ScrollFrame", nil, boxFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 8)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject("AyijeCDM_Font14")
    editBox:SetWidth(editWidth or (width - 40))
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)

    return boxFrame, editBox
end

function UI.SetupModuleToggle(parent, enableCheckbox)
    local overlayLevel = parent:GetFrameLevel() + 100
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(overlayLevel)
    overlay:EnableMouse(true)
    overlay:Hide()

    enableCheckbox:SetFrameLevel(overlayLevel + 10)

    local function SetEnabled(en)
        local alpha = 0.35
        if en then
            alpha = 1
        end

        for _, child in ipairs({ parent:GetChildren() }) do
            if child ~= enableCheckbox and child ~= overlay then
                child:SetAlpha(alpha)
            end
        end
        for _, region in ipairs({ parent:GetRegions() }) do
            region:SetAlpha(alpha)
        end
        overlay:SetShown(not en)
    end

    return SetEnabled
end

function UI.CreateModalOverlay()
    local overlay = CreateFrame("Frame", nil, ns.ConfigFrame, "BackdropTemplate")
    overlay:SetPoint("TOPLEFT", ns.ConfigFrame, "TOPLEFT", 19, -66)
    overlay:SetPoint("BOTTOMRIGHT", ns.ConfigFrame, "BOTTOMRIGHT", -19, 41)
    overlay:SetFrameStrata("DIALOG")
    overlay:SetFrameLevel(ns.ConfigFrame:GetFrameLevel() + 50)
    overlay:EnableMouse(true)
    overlay:Hide()

    local overlayBg = overlay:CreateTexture(nil, "BACKGROUND")
    overlayBg:SetAllPoints()
    overlayBg:SetColorTexture(0, 0, 0, 0.4)

    local window = CreateFrame("Frame", nil, overlay, "SettingsFrameTemplate")
    window:EnableMouse(true)
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(overlay:GetFrameLevel() + 5)
    window:SetPoint("CENTER", ns.ConfigFrame, "CENTER")
    window:SetScript("OnMouseDown", function() end)

    if window.TitleText then
        window.TitleText:SetText("")
        window.TitleText:Hide()
    end

    local closeButton = window.CloseButton
    if closeButton then
        closeButton:HookScript("OnClick", function() overlay:Hide() end)
    end

    overlay:SetScript("OnMouseDown", function() overlay:Hide() end)
    overlay:SetScript("OnShow", function() window:Show() end)
    window:HookScript("OnHide", function() overlay:Hide() end)

    overlay.window = window
    return overlay
end
