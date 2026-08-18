local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local CreateFrame = CreateFrame
local ColorPickerFrame = ColorPickerFrame
local GameTooltip = GameTooltip
local UIParent = UIParent
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local PlaySoundFile = PlaySoundFile
local StopSound = StopSound
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack
local string_format = string.format
local pcall = pcall
local setmetatable = setmetatable
local table_sort = table.sort

GUI2.Form = GUI2.Form or {}

local function GetCoreText(key, fallback)
    local locale = YUI.Locale
    if locale and locale.Get then
        local core = locale:Get("Core")
        local value = core and core[key]
        if value and value ~= key then
            return value
        end
    end
    return fallback
end

local function BindItem(item)
    if not item or not item.key then return end

    if not item.get then
        item.get = function()
            if YUI and YUI.getConfigByKey then
                return YUI:getConfigByKey(item.key, item.default or item.defaultValue)
            end
            return item.default or item.defaultValue
        end
    end
    if not item.set then
        item.set = function(value)
            if YUI and YUI.setConfigByKey then
                YUI:setConfigByKey(item.key, value)
            end
        end
    end
end

local function GetValue(opts)
    BindItem(opts)
    if opts and opts.get then
        local value = opts.get()
        if value ~= nil then return value end
    end
    if opts and opts.value ~= nil then return opts.value end
    if opts and opts.checked ~= nil then return opts.checked end
    if opts and opts.defaultValue ~= nil then return opts.defaultValue end
    if opts and opts.default ~= nil then return opts.default end
    return nil
end

local function GetControlHeight(fallback)
    return GUI2:GetMetric("layout.height.control", fallback or 26)
end

local function GetFormMetric(name, fallback)
    return GUI2:GetMetric("layout.form." .. name, fallback)
end

local function ResolveFormWidth(opts, defaultSize, fallback)
    opts = opts or {}
    if opts.width then
        return opts.width
    end

    local size = opts.size or defaultSize
    if type(size) == "number" then
        return size
    end

    if size == "fill" then
        local availableWidth = opts.availableWidth or opts.fillWidth
        if availableWidth then
            return availableWidth
        end
        size = defaultSize == "fill" and "wide" or defaultSize
    end

    if size == "compact" or size == "normal" or size == "wide" then
        return GetFormMetric("width." .. size, fallback)
    end

    return fallback
end

local function GetSliderWidth(opts, inputWidth, gap)
    opts = opts or {}
    if opts.width then
        return opts.width
    end
    if opts.size == "fill" then
        local availableWidth = opts.availableWidth or opts.fillWidth
        if availableWidth then
            return availableWidth
        end
    end
    if opts.size then
        return ResolveFormWidth(opts, "wide", GetFormMetric("controlWidth", 220)) + gap + inputWidth
    end
    return GetFormMetric("controlWidth", 220) + gap + inputWidth
end

local function CommitValue(opts, widget, value)
    if not opts then return end
    opts.value = value
    if opts.set then opts.set(value) end
    if opts.onChange then opts.onChange(widget, value) end
end

local function NormalizeColorValue(value)
    if type(value) == "table" and type(value[1]) == "table" then
        value = value[1]
    end
    if type(value) ~= "table" then
        return 1, 1, 1, 1
    end
    return value[1] or value.r or 1,
        value[2] or value.g or 1,
        value[3] or value.b or 1,
        value[4] or value.a or 1
end

local function AddTooltip(frame, opts)
    if not frame or not opts or not opts.tooltip then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if opts.label or opts.text then
            GameTooltip:SetText(opts.label or opts.text)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(opts.tooltip, 1, 1, 1, true)
        else
            GameTooltip:SetText(opts.tooltip, 1, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        YUI.HideGameTooltip()
    end)
end

local function ConfigureMotion(frame, opts, owner)
    if not frame then return end
    opts = opts or {}
    frame.gui2Animate = opts.animate ~= false and opts.motion ~= false
    frame.gui2MotionOwner = owner or frame
end

local function InheritMotion(child, owner)
    if not child or not owner then return end
    child.gui2Animate = owner.gui2Animate
    child.gui2MotionOwner = owner
end

local function ParseSetOptions(setOptions)
    local silent = setOptions == true
    local animate = not silent
    local options = nil

    if type(setOptions) == "table" then
        options = setOptions
        silent = setOptions.silent == true
        if setOptions.animate ~= nil then
            animate = setOptions.animate == true
        else
            animate = not silent
        end
        if setOptions.motion == false then
            animate = false
        end
    end

    return silent, animate, options
end

local function GetHairlineInset(region)
    local desiredPixels = GUI2:GetMetric("border.width.hairline", 1)
    if GUI2.GetPixelSize then
        return GUI2:GetPixelSize(region, desiredPixels, 1)
    end
    return desiredPixels
end

local function SetRegionInsideBorder(region, parent, inset)
    if not (region and parent and region.SetPoint) then return end
    inset = math_max(tonumber(inset) or 0, 0)
    if region.ClearAllPoints then
        region:ClearAllPoints()
    end
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    region:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
end

local function CreateMotionOverlay(parent, colorKey, opts)
    if not parent then return nil end
    opts = type(opts) == "table" and opts or {}
    local overlay = CreateFrame("Frame", nil, parent)
    if opts.inset == true then
        SetRegionInsideBorder(overlay, parent, GetHairlineInset(parent))
        overlay.gui2InsetParent = parent
    else
        overlay:SetAllPoints(parent)
    end
    overlay.gui2MotionScale = opts.scale ~= false
    overlay:SetAlpha(0)
    overlay:Hide()
    if overlay.EnableMouse then overlay:EnableMouse(false) end
    if overlay.SetFrameLevel and parent.GetFrameLevel then
        overlay:SetFrameLevel(parent:GetFrameLevel() + 4)
    end

    local texture = GUI2:CreateTexture(overlay, colorKey or "color.accent.primary", "OVERLAY")
    texture:SetAllPoints(overlay)
    overlay.texture = texture
    return overlay
end

local function PlayMotionOverlay(overlay, owner, key)
    if not overlay or not GUI2.PlayControlMotion then return end
    overlay:SetAlpha(0.18)
    overlay:Show()
    local effects = {
        { type = "alpha", from = 0.18, to = 0 },
    }
    if overlay.gui2MotionScale ~= false then
        effects[#effects + 1] = { type = "scale", from = 0.96, to = 1.04 }
    end
    local handle = GUI2:PlayControlMotion(overlay, key or "control-overlay", {
        owner = owner or overlay,
        durationKey = "quick",
        easing = "sineOut",
        effects = effects,
        onFinished = function()
            overlay:Hide()
            overlay:SetAlpha(0)
            if overlay.SetScale then overlay:SetScale(1) end
        end,
    })
    if not handle then
        overlay:Hide()
        overlay:SetAlpha(0)
        if overlay.SetScale then overlay:SetScale(1) end
    end
end

local function StateTokens(frame, state)
    local tone = frame.gui2Tone or "default"
    local surface = "color.control.bg"
    local border = "color.border.default"
    local text = "color.text.primary"

    if tone == "accent" then
        text = "color.text.accent"
    elseif tone == "warning" then
        border = "color.state.warning"
        text = "color.state.warning"
    elseif tone == "danger" or tone == "error" then
        border = "color.state.danger"
        text = "color.state.danger"
    end

    if state == "hover" then
        surface = "color.control.hover"
        border = tone == "warning" and "color.state.warning" or tone == "danger" and "color.state.danger" or "color.border.accent"
    elseif state == "pressed" then
        surface = "color.control.pressed"
        border = "color.border.strong"
    elseif state == "selected" or state == "active" then
        surface = "color.control.active"
        border = "color.border.accent"
        text = tone == "danger" and "color.state.danger" or "color.text.accent"
    elseif state == "locked" then
        surface = "color.control.locked"
        border = "color.border.locked"
        text = "color.text.locked"
    elseif state == "focus" then
        border = "color.border.focus"
    elseif state == "disabled" then
        surface = "color.control.disabled"
        border = "color.border.subtle"
        text = "color.text.disabled"
    end

    return surface, border, text
end

local function ApplyControlState(frame, state)
    if not frame then return end
    state = state or frame.gui2State or "normal"
    frame.gui2State = state

    local surface, border, text = StateTokens(frame, state)
    frame.gui2Surface = surface
    if frame.SetBackdropColor then
        frame:SetBackdropColor(GUI2:GetColor(surface))
    end
    GUI2:SetBorderColor(frame, border)
    if frame.text then
        if frame.gui2CustomTextColor and state == "normal" then
            frame.text:SetTextColor(unpack(frame.gui2CustomTextColor))
        else
            GUI2:SetTextColorKey(frame.text, text)
        end
    end
    if frame.icon and frame.icon.SetVertexColor then
        frame.icon:SetVertexColor(GUI2:GetColor(text))
    end
end

local function GetButtonRestingState(button)
    if button.gui2Locked then
        return "locked"
    end
    if button.gui2Selected then
        return "selected"
    end
    return "normal"
end

local function SetButtonEnabled(button, enabled)
    button.gui2Disabled = not enabled
    if enabled then
        if button.Enable then button:Enable() end
        local state = GetButtonRestingState(button)
        if state == "disabled" then state = "normal" end
        ApplyControlState(button, state)
    else
        if button.Disable then button:Disable() end
        ApplyControlState(button, "disabled")
    end
end

local function WireButtonStates(button)
    button:SetScript("OnEnter", function(self)
        if self.gui2Disabled then return end
        if self.gui2Locked then
            ApplyControlState(self, "locked")
            return
        end
        ApplyControlState(self, "hover")
    end)
    button:SetScript("OnLeave", function(self)
        if self.gui2Disabled then return end
        if self.text then self.text:SetPoint("CENTER", 0, 0) end
        ApplyControlState(self, GetButtonRestingState(self))
    end)
    button:SetScript("OnMouseDown", function(self)
        if self.gui2Disabled then return end
        ApplyControlState(self, "pressed")
        if self.text then self.text:SetPoint("CENTER", 1, -1) end
    end)
    button:SetScript("OnMouseUp", function(self)
        if self.gui2Disabled then return end
        if self.text then self.text:SetPoint("CENTER", 0, 0) end
        ApplyControlState(self, (self:IsMouseOver() and not self.gui2Locked) and "hover" or GetButtonRestingState(self))
    end)
end

function GUI2.Form:CreateButton(parent, opts)
    opts = opts or {}
    local button = CreateFrame("Button", opts.name, parent, "BackdropTemplate")
    button:SetSize(ResolveFormWidth(opts, "compact", 112), opts.height or GetControlHeight(26))
    button.gui2RadiusKey = opts.radiusKey or "layout.radius.control"
    if button.EnableMouse then button:EnableMouse(true) end
    if button.RegisterForClicks then button:RegisterForClicks("AnyUp") end
    ConfigureMotion(button, opts)
    button.gui2Tone = opts.tone or "accent"
    GUI2:ApplyBackdrop(button, "color.control.bg")
    GUI2:CreateBorder(button, "color.border.default")

    local label = GUI2:CreateText(button, opts.text or opts.label or "", opts.fontSizeKey or "font.size.md", "color.text.accent")
    label:SetPoint("CENTER")
    button.text = label

    function button:SetState(state)
        self.gui2Locked = state == "locked"
        self.gui2Selected = not self.gui2Locked and (state == "selected" or state == "active")
        ApplyControlState(self, state)
    end
    function button:SetSelected(selected)
        self.gui2Locked = false
        self.gui2Selected = selected and true or false
        ApplyControlState(self, self.gui2Selected and "selected" or "normal")
    end
    function button:SetDisabled(disabled)
        SetButtonEnabled(self, not disabled)
    end
    function button:SetText(value)
        if self.text then self.text:SetText(value or "") end
    end
    function button:GetFontString()
        return self.text
    end
    function button:SetTextColor(r, g, b, a)
        self.gui2CustomTextColor = { r, g, b, a == nil and 1 or a }
        if self.text then self.text:SetTextColor(r, g, b, a == nil and 1 or a) end
    end
    function button:RefreshTheme()
        ApplyControlState(self, self.gui2Disabled and "disabled" or GetButtonRestingState(self))
    end

    WireButtonStates(button)
    if opts.onClick then button:SetScript("OnClick", opts.onClick) end
    AddTooltip(button, opts)
    button:SetState(opts.state or "normal")
    button:SetDisabled(opts.disabled or opts.state == "disabled")
    GUI2:RegisterThemeObject(button)
    return button
end

function GUI2.Form:CreateIconButton(parent, opts)
    opts = opts or {}
    local size = math_max(opts.size or GUI2:GetMetric("layout.size.iconButton", 28), 20)
    local button = self:CreateButton(parent, {
        width = size,
        height = size,
        text = "",
        tone = opts.tone or "default",
        state = opts.state,
        disabled = opts.disabled,
        tooltip = opts.tooltip,
        onClick = opts.onClick,
    })
    local icon = GUI2:CreateIcon(button, {
        icon = opts.icon,
        atlas = opts.atlas,
        size = math_max(size - 10, 12),
    })
    icon:SetPoint("CENTER")
    button.icon = icon
    InheritMotion(icon, button)
    button:RefreshTheme()
    return button
end

function GUI2.Form:CreateCheckbox(parent, opts)
    opts = opts or {}
    BindItem(opts)
    local frame = CreateFrame("Button", opts.name, parent)
    local width = ResolveFormWidth(opts, "normal", 180)
    local height = opts.height or GetFormMetric("rowHeight", 32)
    frame:SetSize(width, height)
    if frame.EnableMouse then frame:EnableMouse(true) end
    if frame.RegisterForClicks then frame:RegisterForClicks("AnyUp") end
    frame.width = width
    frame.height = height
    frame.gui2Disabled = opts.disabled and true or false
    ConfigureMotion(frame, opts)

    local box = GUI2:CreatePanel(frame, { width = 18, height = 18, surface = "color.control.bg", border = "color.border.default" })
    box:SetPoint("LEFT", 0, 0)
    frame.box = box
    InheritMotion(box, frame)
    frame.boxMotion = CreateMotionOverlay(box, "color.accent.primary")
    InheritMotion(frame.boxMotion, frame)

    frame.fill = box
    frame.mark = box

    local label = GUI2:CreateText(frame, opts.text or opts.label or "", "font.size.md", "color.text.primary")
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetWidth(math_max(width - 26, 0))
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    frame.text = label

    function frame:GetChecked()
        return self.gui2Checked
    end
    function frame:GetValue()
        return self.gui2Checked
    end
    function frame:SetChecked(checked, silent)
        local isSilent, animate = ParseSetOptions(silent)
        local previous = self.gui2Checked
        self.gui2Checked = checked and true or false
        self.box.gui2Surface = self.gui2Disabled and "color.control.disabled" or (self.gui2Checked and "color.accent.fill" or "color.control.bg")
        GUI2:RefreshPrimitive(self.box)
        GUI2:SetBorderColor(self.box, self.gui2Disabled and "color.border.subtle" or (self.gui2Checked and "color.border.accent" or "color.border.default"))
        if animate and previous ~= nil and previous ~= self.gui2Checked and not self.gui2Disabled then
            PlayMotionOverlay(self.boxMotion, self, "checkbox-check")
        end
        if not isSilent then CommitValue(opts, self, self.gui2Checked) end
    end
    function frame:SetValue(value, silent)
        self:SetChecked(value, silent)
    end
    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled and true or false
        if self.gui2Disabled then
            GUI2:SetTextColorKey(self.text, "color.text.disabled")
            if self.Disable then self:Disable() end
        else
            GUI2:SetTextColorKey(self.text, "color.text.primary")
            if self.Enable then self:Enable() end
        end
        self:SetChecked(self.gui2Checked, true)
    end
    function frame:RefreshTheme()
        self:SetDisabled(self.gui2Disabled)
        self:SetChecked(self.gui2Checked, true)
    end

    frame:SetScript("OnClick", function(self)
        if self.gui2Disabled then return end
        self:SetChecked(not self.gui2Checked)
        if opts.onClick then opts.onClick(self, self.gui2Checked) end
    end)
    frame:SetScript("OnEnter", function(self)
        if self.gui2Disabled then return end
        GUI2:SetBorderColor(self.box, "color.border.accent")
    end)
    frame:SetScript("OnLeave", function(self)
        GUI2:SetBorderColor(self.box, self.gui2Checked and "color.border.accent" or "color.border.default")
    end)

    AddTooltip(frame, opts)
    frame:SetChecked(GetValue(opts), true)
    frame:SetDisabled(opts.disabled)
    if opts.autoWidth and not opts.width and frame.text then
        frame.width = 26 + frame.text:GetStringWidth()
        frame:SetWidth(frame.width)
        frame.text:SetWidth(math_max(frame.width - 26, 0))
    end
    GUI2:RegisterThemeObject(frame)
    return frame
end

function GUI2.Form:CreateSwitch(parent, opts)
    opts = opts or {}
    BindItem(opts)

    local offValue = opts.offValue
    if offValue == nil then offValue = opts.leftValue end
    if offValue == nil then offValue = false end
    local onValue = opts.onValue
    if onValue == nil then onValue = opts.rightValue end
    if onValue == nil then onValue = true end
    local offText = opts.offText or opts.leftText or GetCoreText("common.off", "OFF")
    local onText = opts.onText or opts.rightText or GetCoreText("common.on", "ON")
    local variant = opts.variant or opts.switchVariant
    local isChoiceVariant = variant == "choice"

    local frame = CreateFrame("Button", opts.name, parent, "BackdropTemplate")
    local width = opts.width or 64
    local height = opts.height or GetControlHeight(26)
    frame:SetSize(width, height)
    frame.gui2RadiusKey = opts.radiusKey or "layout.radius.control"
    if frame.EnableMouse then frame:EnableMouse(true) end
    if frame.RegisterForClicks then frame:RegisterForClicks("AnyUp") end
    frame.width = width
    frame.height = height
    frame.gui2Disabled = opts.disabled and true or false
    frame.gui2SwitchVariant = variant
    frame.gui2OffValue = offValue
    frame.gui2OnValue = onValue
    frame.gui2OffColor = opts.offColor or opts.leftColor
    frame.gui2OnColor = opts.onColor or opts.rightColor
    frame.gui2OffColorKey = opts.offColorKey or opts.leftColorKey
    frame.gui2OnColorKey = opts.onColorKey or opts.rightColorKey
    frame.gui2ChoiceLeftColorKey = opts.choiceLeftColorKey or "color.control.choice.left"
    frame.gui2ChoiceRightColorKey = opts.choiceRightColorKey or "color.control.choice.right"
    ConfigureMotion(frame, opts)
    GUI2:ApplyBackdrop(frame, "color.control.track")
    GUI2:CreateBorder(frame, "color.border.default")

    local thumbWidth = opts.thumbWidth or 20
    local thumb = GUI2:CreatePanel(frame, { width = thumbWidth, height = height - 6, surface = "color.control.thumb", border = "color.border.subtle" })
    frame.thumb = thumb
    if thumb.EnableMouse then thumb:EnableMouse(false) end
    InheritMotion(thumb, frame)
    local label = GUI2:CreateText(frame, "", "font.size.md", "color.text.secondary")
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    frame.text = label

    function frame:GetValue()
        return self.gui2Value
    end
    function frame:GetChecked()
        return self.gui2Checked
    end
    function frame:SetValue(value, silent)
        local isSilent, animate = ParseSetOptions(silent)
        local previousChecked = self.gui2Checked
        local checked = value == onValue or value == true and onValue == true
        local oldLeft = previousChecked and (self.width - thumbWidth - 3) or 3
        local newLeft = checked and (self.width - thumbWidth - 3) or 3
        if checked then
            self.gui2Value = onValue
        else
            self.gui2Value = offValue
        end
        self.gui2Checked = checked
        self.thumb:ClearAllPoints()
        self.text:ClearAllPoints()
        if checked then
            self.gui2Surface = isChoiceVariant and self.gui2ChoiceRightColorKey or "color.control.active"
            self.thumb:SetPoint("RIGHT", -3, 0)
            self.text:SetPoint("LEFT", self, "LEFT", 3, 0)
            self.text:SetPoint("RIGHT", self.thumb, "LEFT", -2, 0)
            self.text:SetText(onText)
            if opts.onTextColorKey or opts.rightTextColorKey then
                GUI2:SetTextColorKey(self.text, opts.onTextColorKey or opts.rightTextColorKey)
            elseif opts.onTextColor or opts.rightTextColor then
                self.text:SetTextColor(unpack(opts.onTextColor or opts.rightTextColor))
            else
                GUI2:SetTextColorKey(self.text, "color.text.primary")
            end
            GUI2:SetBorderColor(self, isChoiceVariant and "color.border.default" or "color.border.accent")
        else
            self.gui2Surface = isChoiceVariant and self.gui2ChoiceLeftColorKey or "color.control.track"
            self.thumb:SetPoint("LEFT", 3, 0)
            self.text:SetPoint("LEFT", self.thumb, "RIGHT", 2, 0)
            self.text:SetPoint("RIGHT", self, "RIGHT", -3, 0)
            self.text:SetText(offText)
            if opts.offTextColorKey or opts.leftTextColorKey then
                GUI2:SetTextColorKey(self.text, opts.offTextColorKey or opts.leftTextColorKey)
            elseif opts.offTextColor or opts.leftTextColor then
                self.text:SetTextColor(unpack(opts.offTextColor or opts.leftTextColor))
            else
                GUI2:SetTextColorKey(self.text, isChoiceVariant and "color.text.primary" or "color.text.secondary")
            end
            GUI2:SetBorderColor(self, "color.border.default")
        end
        if self.gui2Disabled then
            self.gui2Surface = "color.control.disabled"
            GUI2:SetTextColorKey(self.text, "color.text.disabled")
            GUI2:SetBorderColor(self, "color.border.subtle")
        end
        local colorKey = checked and self.gui2OnColorKey or self.gui2OffColorKey
        local color = checked and self.gui2OnColor or self.gui2OffColor
        if isChoiceVariant and not colorKey and not color then
            colorKey = checked and self.gui2ChoiceRightColorKey or self.gui2ChoiceLeftColorKey
        end
        if colorKey and not self.gui2Disabled then
            self:SetBackdropColor(GUI2:GetColor(colorKey))
        elseif color and not self.gui2Disabled then
            self:SetBackdropColor(unpack(color))
        else
            self:SetBackdropColor(GUI2:GetColor(self.gui2Surface))
        end
        if animate and previousChecked ~= nil and previousChecked ~= checked and not self.gui2Disabled and GUI2.PlayControlMotion then
            GUI2:PlayControlMotion(self.thumb, "switch-thumb", {
                owner = self,
                durationKey = "medium",
                easing = "sineOut",
                effects = {
                    { type = "translation", fromX = oldLeft - newLeft, fromY = 0, toX = 0, toY = 0 },
                },
            })
        end
        if not isSilent then CommitValue(opts, self, self.gui2Value) end
    end
    function frame:SetChecked(checked, silent)
        if checked then
            self:SetValue(onValue, silent)
        else
            self:SetValue(offValue, silent)
        end
    end
    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled and true or false
        if self.gui2Disabled then
            if self.Disable then self:Disable() end
        else
            if self.Enable then self:Enable() end
        end
        self:SetValue(self.gui2Value, true)
    end
    function frame:RefreshTheme()
        GUI2:ApplyBackdrop(self, self.gui2Surface or "color.control.track")
        self:SetValue(self.gui2Value, true)
        if self.thumb then GUI2:RefreshPrimitive(self.thumb) end
    end
    function frame:Toggle()
        if self.gui2Disabled then return end
        local current = GetValue(opts)
        if current ~= onValue and current ~= offValue then current = self.gui2Value end
        if current == onValue then
            self:SetValue(offValue)
        else
            self:SetValue(onValue)
        end
    end

    frame:SetScript("OnClick", function(self)
        self:Toggle()
    end)
    frame:SetScript("OnEnter", function(self)
        if self.gui2Disabled then return end
        GUI2:SetBorderColor(self, isChoiceVariant and "color.border.default" or "color.border.accent")
    end)
    frame:SetScript("OnLeave", function(self)
        self:SetValue(self.gui2Value, true)
    end)

    AddTooltip(frame, opts)
    local value = GetValue(opts)
    if value ~= onValue and value ~= offValue then value = offValue end
    frame:SetValue(value, true)
    frame:SetDisabled(opts.disabled)
    GUI2:RegisterThemeObject(frame)
    return frame
end

function GUI2.Form:CreateBinaryChoice(parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", opts.name, parent)
    local values = opts.values or {
        { text = "Left", value = false },
        { text = "Right", value = true },
    }
    local width = opts.width or 174
    local height = opts.height or 28
    frame:SetSize(width, height)
    frame.buttons = {}
    ConfigureMotion(frame, opts)

    local eachWidth = math_floor(width / math_max(#values, 1))
    local indicator = CreateFrame("Frame", nil, frame)
    indicator:SetSize(math_max(eachWidth - 8, 1), 2)
    indicator:SetPoint("BOTTOMLEFT", 4, 1)
    if indicator.SetFrameLevel and frame.GetFrameLevel then
        indicator:SetFrameLevel(frame:GetFrameLevel() + 8)
    end
    local indicatorTexture = GUI2:CreateTexture(indicator, "color.border.accent", "ARTWORK")
    indicatorTexture:SetAllPoints(indicator)
    indicator.texture = indicatorTexture
    frame.indicator = indicator
    InheritMotion(indicator, frame)

    function frame:SetValue(value, silent)
        local isSilent, animate = ParseSetOptions(silent)
        local oldIndex = self.selectedIndex
        local newIndex = 1
        self.value = value
        for i, button in ipairs(self.buttons) do
            local selected = values[i].value == value
            button:SetSelected(selected)
            if selected then newIndex = i end
        end
        self.selectedIndex = newIndex
        if self.indicator then
            self.indicator:ClearAllPoints()
            self.indicator:SetPoint("BOTTOMLEFT", 4 + ((newIndex - 1) * eachWidth), 1)
            if animate and oldIndex and oldIndex ~= newIndex and GUI2.PlayControlMotion then
                GUI2:PlayControlMotion(self.indicator, "segmented-indicator", {
                    owner = self,
                    durationKey = "medium",
                    easing = "sineOut",
                    effects = {
                        { type = "translation", fromX = (oldIndex - newIndex) * eachWidth, fromY = 0, toX = 0, toY = 0 },
                    },
                })
            end
        end
        if not isSilent then CommitValue(opts, self, value) end
    end

    for i, data in ipairs(values) do
        local button = self:CreateButton(frame, { text = data.text, width = eachWidth, height = height, tone = "default" })
        button:SetPoint("LEFT", (i - 1) * eachWidth, 0)
        button:SetScript("OnClick", function()
            frame:SetValue(data.value)
        end)
        frame.buttons[i] = button
    end
    if indicator.SetFrameLevel then
        local level = frame.GetFrameLevel and frame:GetFrameLevel() or 0
        for _, button in ipairs(frame.buttons) do
            if button.GetFrameLevel then
                level = math_max(level, button:GetFrameLevel())
            end
        end
        indicator:SetFrameLevel(level + 4)
    end
    frame:SetValue(GetValue(opts) or values[1].value, true)
    return frame
end

function GUI2.Form:CreateSegmentedControl(parent, opts)
    opts = opts or {}
    local items = opts.items or { "One", "Two", "Three" }
    local values = {}
    for i, item in ipairs(items) do
        values[i] = {
            text = type(item) == "table" and item.text or item,
            value = type(item) == "table" and item.value or item,
        }
    end
    opts.values = values
    return self:CreateBinaryChoice(parent, opts)
end

function GUI2.Form:CreateSlider(parent, opts)
    opts = opts or {}
    BindItem(opts)

    local gap = GetFormMetric("gap", 10)
    local inputWidth = opts.inputWidth or GetFormMetric("valueWidth", 56)
    local width = GetSliderWidth(opts, inputWidth, gap)
    local height = opts.inline and 24 or 48
    local minValue = opts.min or 0
    local maxValue = opts.max or 100
    local container = CreateFrame("Frame", opts.name, parent)
    container:SetSize(width, height)
    ConfigureMotion(container, opts)

    local labelWidth = 0
    if opts.label and opts.inline then
        local label = GUI2:CreateText(container, opts.label, "font.size.md", "color.text.primary")
        label:SetPoint("LEFT", 0, 0)
        labelWidth = opts.labelWidth or math_max(label:GetStringWidth() + 10, 30)
        label:SetWidth(labelWidth)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        container.label = label
    elseif opts.label then
        local label = GUI2:CreateText(container, opts.label, "font.size.md", "color.text.primary")
        label:SetPoint("TOPLEFT", 0, 0)
        container.label = label
    end

    local sliderWidth = width - inputWidth - gap - labelWidth
    if sliderWidth < 60 then sliderWidth = 60 end
    local slider = CreateFrame("Slider", nil, container)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetHeight(20)
    slider:SetWidth(sliderWidth)
    if opts.inline then
        slider:SetPoint("LEFT", container, "LEFT", labelWidth, 0)
    else
        slider:SetPoint("TOPLEFT", 0, opts.label and -22 or -2)
    end
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(8, 14)
    slider:SetThumbTexture(thumb)
    GUI2:SkinSlider(slider)
    InheritMotion(slider, container)
    InheritMotion(thumb, container)
    if slider.gui2Thumb then InheritMotion(slider.gui2Thumb, container) end

    local input = self:CreateEditBox(container, { width = inputWidth, height = 18, text = "" })
    input:SetJustifyH("CENTER")
    InheritMotion(input, container)
    if input.gui2Bg then InheritMotion(input.gui2Bg, container) end
    if opts.inline then
        input:SetPoint("LEFT", slider, "RIGHT", gap, 0)
    else
        input:SetPoint("TOP", slider, "BOTTOM", 0, 0)
    end

    container.slider = slider
    container.inputBox = input
    local dragging = false
    local precision = opts.precision or 2
    if opts.step and opts.step % 1 == 0 then precision = 0 end
    local fmt = "%." .. precision .. "f"

    local function Normalize(value)
        value = tonumber(value) or minValue
        value = math_max(minValue, math_min(maxValue, value))
        if opts.step then
            value = math_floor(value / opts.step + 0.5) * opts.step
        end
        return value
    end

    local function Update(value, source, silent)
        value = Normalize(value)
        container.value = value
        if source ~= "slider" then
            slider.gui2Updating = true
            slider:SetValue(value)
            slider.gui2Updating = false
        end
        if source ~= "input" then input:SetText(string_format(fmt, value)) end
        if silent or (dragging and opts.instantUpdate == false) then return end
        CommitValue(opts, container, value)
    end

    function container:GetValue()
        return self.value
    end
    function container:SetValue(value, silent)
        Update(value, nil, silent)
    end
    function container:SetDisabled(disabled)
        self.gui2Disabled = disabled and true or false
        if self.gui2Disabled then
            if slider.Disable then slider:Disable() end
            if input.SetDisabled then input:SetDisabled(true) end
            if self.label then GUI2:SetTextColorKey(self.label, "color.text.disabled") end
        else
            if slider.Enable then slider:Enable() end
            if input.SetDisabled then input:SetDisabled(false) end
            if self.label then GUI2:SetTextColorKey(self.label, "color.text.primary") end
        end
        if self.slider and self.slider.gui2Bg then
            self.slider.gui2Bg.gui2Surface = self.gui2Disabled and "color.control.disabled" or "color.control.track"
            GUI2:RefreshPrimitive(self.slider.gui2Bg)
        end
    end
    function container:RefreshTheme()
        if self.slider and self.slider.RefreshTheme then self.slider:RefreshTheme() end
        if self.inputBox and self.inputBox.RefreshTheme then self.inputBox:RefreshTheme() end
        if self.label then GUI2:SetTextColorKey(self.label, self.gui2Disabled and "color.text.disabled" or "color.text.primary") end
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if slider.gui2Updating then return end
        slider.gui2Updating = true
        Update(value, "slider")
        slider.gui2Updating = false
    end)
    slider:SetScript("OnMouseDown", function()
        dragging = true
    end)
    slider:SetScript("OnMouseUp", function()
        dragging = false
        Update(slider:GetValue(), "slider")
    end)
    input:SetScript("OnEnterPressed", function(editbox)
        Update(editbox:GetText(), "input")
        editbox:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(editbox)
        editbox:SetText(string_format(fmt, container.value or minValue))
        editbox:ClearFocus()
    end)

    AddTooltip(container, opts)
    Update(GetValue(opts) or minValue, nil, true)
    container:SetDisabled(opts.disabled)
    GUI2:RegisterThemeObject(container)
    return container
end

function GUI2.Form:CreateEditBox(parent, opts)
    opts = opts or {}
    BindItem(opts)

    local edit = CreateFrame("EditBox", opts.name, parent)
    edit:SetSize(ResolveFormWidth(opts, "wide", 220), opts.height or GetControlHeight(26))
    edit:SetAutoFocus(opts.autoFocus and true or false)
    edit:SetFont(GUI2:GetFont("font.family.body"), GUI2:GetMetric("font.size.md", 13), "")
    edit:SetTextColor(GUI2:GetColor("color.text.primary"))
    edit:SetTextInsets(8, 8, 0, 0)
    edit:SetText(tostring(GetValue(opts) or opts.text or ""))
    ConfigureMotion(edit, opts)

    local bg = GUI2:CreatePanel(edit, { surface = "color.control.bg", border = opts.focus and "color.border.focus" or "color.border.default" })
    bg:SetPoint("TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", 0, 0)
    bg:SetFrameLevel(edit:GetFrameLevel() > 0 and edit:GetFrameLevel() - 1 or 0)
    edit.gui2Bg = bg
    InheritMotion(bg, edit)

    function edit:RefreshTheme()
        if self.gui2Bg then GUI2:RefreshPrimitive(self.gui2Bg) end
        self:SetTextColor(GUI2:GetColor(self.gui2Disabled and "color.text.disabled" or "color.text.primary"))
    end
    function edit:GetValue()
        return self:GetText()
    end
    function edit:SetValue(value, silent)
        self.gui2SettingText = true
        self:SetText(tostring(value or ""))
        self.gui2SettingText = nil
        if not silent then CommitValue(opts, self, self:GetText()) end
    end
    function edit:SetDisabled(disabled)
        self.gui2Disabled = disabled and true or false
        if self.gui2Disabled then
            if self.Disable then self:Disable() end
            self:SetTextColor(GUI2:GetColor("color.text.disabled"))
            self.gui2Bg.gui2Surface = "color.control.disabled"
        else
            if self.Enable then self:Enable() end
            self.gui2Bg.gui2Surface = "color.control.bg"
        end
        self:RefreshTheme()
    end

    edit:SetScript("OnEditFocusGained", function(self)
        if self.gui2Bg then GUI2:SetBorderColor(self.gui2Bg, "color.border.focus") end
        if opts.onFocusGained then opts.onFocusGained(self) end
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        if self.gui2Bg then GUI2:SetBorderColor(self.gui2Bg, opts.focus and "color.border.focus" or "color.border.default") end
        if opts.onFocusLost then opts.onFocusLost(self) end
    end)
    edit:SetScript("OnTextChanged", function(self)
        if self.gui2SettingText then return end
        if opts.set or opts.onChange then
            CommitValue(opts, self, self:GetText())
        end
    end)

    AddTooltip(edit, opts)
    edit:SetDisabled(opts.disabled)
    GUI2:RegisterThemeObject(edit)
    return edit
end

function GUI2.Form:CreateDropdown(parent, opts)
    opts = opts or {}
    BindItem(opts)

    local width = ResolveFormWidth(opts, "wide", 220)
    local height = opts.height or GetControlHeight(26)
    local frame = GUI2:CreateButtonFrame(parent, { template = "BackdropTemplate", width = width, height = height })
    frame.width = width
    frame.height = height
    ConfigureMotion(frame, opts)
    GUI2:SkinDropdownButton(frame)
    if frame.arrow then InheritMotion(frame.arrow, frame) end

    local function ResolveOptions()
        local options = opts.options
        if type(options) == "function" then options = options() end
        return options or {}
    end

    local function NormalizeOption(option)
        if type(option) == "table" then return option end
        return { text = tostring(option), value = option }
    end

    local function HasOptionIcon(option)
        return type(option) == "table" and (option.iconData ~= nil or option.icon ~= nil or option.texture ~= nil or option.atlas ~= nil)
    end

    local function ApplyOptionIcon(texture, option)
        if not texture or not HasOptionIcon(option) then return false end

        local iconData = option.iconData
        local icons = YUI.API and YUI.API.Icons
        if type(iconData) == "table" and icons and icons.ApplyIcon and icons.ApplyIcon(texture, iconData) then
            local texCoord = option.texCoord or option.texCoords
            if texCoord then
                texture:SetTexCoord(unpack(texCoord))
            end
            texture:SetAlpha(1)
            texture:Show()
            return true
        end

        if option.atlas and texture.SetAtlas then
            texture:SetTexture(nil)
            texture:SetAtlas(option.atlas, false)
        else
            local source = option.icon or option.texture
            if source == nil then return false end
            texture:SetTexture(source)
        end
        local texCoord = option.texCoord or option.texCoords
        if texCoord then
            texture:SetTexCoord(unpack(texCoord))
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
        texture:SetVertexColor(1, 1, 1, 1)
        texture:SetAlpha(1)
        texture:SetBlendMode(option.blendMode or "BLEND")
        texture:Show()
        return true
    end

    local function FindOption(value)
        for _, option in ipairs(ResolveOptions()) do
            local optionTable = NormalizeOption(option)
            if optionTable.value == value then
                return optionTable
            end
        end
        return nil
    end

    local function OptionText(value)
        local option = FindOption(value)
        if option then
            return option.selectionText or option.text or tostring(option.value)
        end
        return opts.placeholder or ""
    end

    local function ApplySelectionIcon(dropdown, option)
        if not dropdown or not dropdown.text then return end
        dropdown.text:ClearAllPoints()
        if HasOptionIcon(option) then
            if not dropdown.selectionIcon then
                dropdown.selectionIcon = GUI2:CreateTexture(dropdown, { layer = "ARTWORK" })
            end
            dropdown.selectionIcon:SetSize(option.iconSize or 18, option.iconSize or 18)
            dropdown.selectionIcon:ClearAllPoints()
            dropdown.selectionIcon:SetPoint("LEFT", 8, 0)
            if ApplyOptionIcon(dropdown.selectionIcon, option) then
                dropdown.gui2HasSelectionIcon = true
                dropdown.text:SetPoint("LEFT", dropdown.selectionIcon, "RIGHT", 6, 0)
                dropdown.text:SetPoint("RIGHT", -24, 0)
                return
            end
        end

        if dropdown.selectionIcon then
            dropdown.selectionIcon:Hide()
            dropdown.selectionIcon:SetTexture(nil)
        end
        dropdown.gui2HasSelectionIcon = false
        dropdown.text:SetPoint("LEFT", 8, 0)
        dropdown.text:SetPoint("RIGHT", -24, 0)
    end

    function frame:GetValue()
        return self.value
    end
    function frame:SetValue(value, silent)
        self.value = value
        local option = FindOption(value)
        self.gui2FullText = OptionText(value) or ""
        ApplySelectionIcon(self, option)
        if self.text then self.text:SetText((self.gui2HasSelectionIcon and "" or " ") .. self.gui2FullText) end
        if not silent then CommitValue(opts, self, value) end
    end
    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled and true or false
        if self.gui2Disabled then
            if self.Disable then self:Disable() end
        else
            if self.Enable then self:Enable() end
        end
        self:RefreshTheme()
    end
    function frame:RefreshTheme()
        if self.bg then
            self.bg.gui2Surface = self.gui2Disabled and "color.control.disabled" or "color.control.bg"
            GUI2:RefreshPrimitive(self.bg)
            GUI2:SetBorderColor(self.bg, self.gui2Disabled and "color.border.subtle" or "color.border.default")
        end
        if self.text then GUI2:SetTextColorKey(self.text, self.gui2Disabled and "color.text.disabled" or "color.text.primary") end
        if self.selectionIcon then self.selectionIcon:SetAlpha(self.gui2Disabled and 0.35 or 1) end
        if self.arrow then GUI2:SetDropdownGlyphColor(self.arrow, self.gui2Disabled and "color.text.disabled" or "color.accent.primary") end
    end

    frame:SetScript("OnMouseUp", function(self)
        if self.gui2Disabled then return end
        if type(opts.options) == "function" then
            self:SetValue(self.value, true)
        end
        local menuOptions = {}
        for _, option in ipairs(ResolveOptions()) do
            local optionTable = NormalizeOption(option)
            local opt = optionTable
            menuOptions[#menuOptions + 1] = {
                text = opt.text or tostring(opt.value),
                value = opt.value,
                checked = self.value == opt.value,
                render = opt.render,
                icon = opt.icon or opt.texture,
                texture = opt.texture,
                atlas = opt.atlas,
                texCoord = opt.texCoord,
                texCoords = opt.texCoords,
                iconData = opt.iconData,
                iconSize = opt.iconSize,
                blendMode = opt.blendMode,
                actionFunc = opt.actionFunc,
                actionTooltip = opt.actionTooltip,
                actionIcon = opt.actionIcon,
                actionTexture = opt.actionTexture,
                actionAtlas = opt.actionAtlas,
                actionIconAtlas = opt.actionIconAtlas,
                actionSize = opt.actionSize,
                actionIconPadding = opt.actionIconPadding,
                func = function()
                    self:SetValue(opt.value)
                    if opt.func then opt.func() end
                end,
            }
        end
        local menuWidth = opts.menuWidth or self:GetWidth()
        menuWidth = math_max(menuWidth, self:GetWidth())
        GUI2:OpenDropdown(self, menuOptions, nil, self.value, menuWidth)
    end)
    frame:SetScript("OnEnter", function(self)
        if self.gui2Disabled then return end
        if self.bg then GUI2:SetBorderColor(self.bg, "color.border.accent") end
        if self.arrow then GUI2:SetDropdownGlyphColor(self.arrow, "color.accent.primary") end
        if GameTooltip and self.text and self.gui2FullText and self.gui2FullText ~= "" then
            local textWidth = self.text:GetStringWidth() or 0
            local availableWidth = self.text:GetWidth() or 0
            if availableWidth > 0 and textWidth > availableWidth + 1 then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.gui2FullText, 1, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end
    end)
    frame:SetScript("OnLeave", function(self)
        self:RefreshTheme()
        if GameTooltip and GameTooltip:IsOwned(self) then
            YUI.HideGameTooltip()
        end
    end)

    AddTooltip(frame, opts)
    frame:SetValue(GetValue(opts), true)
    frame:SetDisabled(opts.disabled)
    GUI2:RegisterThemeObject(frame)
    return frame
end

local SOUND_PREVIEW_BUTTON_SIZE = 26
local SOUND_PREVIEW_BUTTON_GAP = 8
local SOUND_PREVIEW_PLAY_ATLAS = "common-dropdown-icon-next"
local SOUND_PREVIEW_STOP_ATLAS = "common-dropdown-icon-stop"
local soundPreviewHandle
local soundPreviewToken
local soundPreviewButtons = setmetatable({}, { __mode = "k" })

local function ResolvePreviewChannel(channel)
    if type(channel) == "function" then
        channel = channel()
    end
    if type(channel) ~= "string" or channel == "" then
        return "Master"
    end
    return channel
end

local function RefreshSoundPreviewButtons()
    for button in pairs(soundPreviewButtons) do
        if button and button.soundPreviewIcon then
            local active = soundPreviewHandle ~= nil and soundPreviewToken ~= nil and button.gui2SoundPreviewToken == soundPreviewToken
            local atlas = active and SOUND_PREVIEW_STOP_ATLAS or SOUND_PREVIEW_PLAY_ATLAS
            if button.soundPreviewIcon.SetAtlas then
                button.soundPreviewIcon:SetTexture(nil)
                button.soundPreviewIcon:SetAtlas(atlas, false)
            else
                button.soundPreviewIcon:SetTexture(nil)
            end
            if button.soundPreviewIcon.SetVertexColor and GUI2.GetColor then
                button.soundPreviewIcon:SetVertexColor(GUI2:GetColor("color.text.accent"))
            end
        end
    end
end

function GUI2.Form:StopSoundPreview()
    if soundPreviewHandle and StopSound then
        pcall(StopSound, soundPreviewHandle)
    end
    soundPreviewHandle = nil
    soundPreviewToken = nil
    RefreshSoundPreviewButtons()
end

function GUI2.Form:PlaySoundPreview(path, channel, token, opts)
    opts = opts or {}
    if type(path) ~= "string" or path == "" or type(PlaySoundFile) ~= "function" then
        if opts.onPreviewFailed then opts.onPreviewFailed(path, "invalid-path") end
        return false, "invalid-path"
    end

    token = token or path
    if soundPreviewHandle and soundPreviewToken == token then
        self:StopSoundPreview()
        return false, "stopped"
    end

    self:StopSoundPreview()
    channel = ResolvePreviewChannel(channel)

    local ok, willPlay, handle = pcall(PlaySoundFile, path, channel)
    if (not ok or willPlay == false) and channel ~= "Master" then
        ok, willPlay, handle = pcall(PlaySoundFile, path, "Master")
    end

    if ok and willPlay ~= false then
        if handle then
            soundPreviewHandle = handle
            soundPreviewToken = token
        end
        RefreshSoundPreviewButtons()
        return true, "ok"
    end

    if opts.onPreviewFailed then opts.onPreviewFailed(path, "play-failed") end
    RefreshSoundPreviewButtons()
    return false, "play-failed"
end

function GUI2.Form:CreateSoundPreviewButton(parent, opts)
    opts = opts or {}
    local size = opts.size or SOUND_PREVIEW_BUTTON_SIZE
    local button = self:CreateButton(parent, {
        text = "",
        width = size,
        height = size,
        tone = opts.tone or "default",
        tooltip = opts.tooltip or GetCoreText("common.preview_sound", "Preview sound"),
        disabled = opts.disabled,
        onClick = function(selfButton)
            local path = opts.path
            if opts.getPath then
                path = opts.getPath(selfButton)
            end
            local channel = opts.channel
            if opts.getChannel then
                channel = opts.getChannel(selfButton)
            end
            local token = opts.token
            if opts.getToken then
                token = opts.getToken(selfButton, path)
            end
            selfButton.gui2SoundPreviewToken = token or path
            GUI2.Form:PlaySoundPreview(path, channel, selfButton.gui2SoundPreviewToken, {
                onPreviewFailed = opts.onPreviewFailed,
            })
        end,
    })
    button.gui2SoundPreviewToken = opts.token
    local icon = GUI2:CreateIcon(button, {
        atlas = SOUND_PREVIEW_PLAY_ATLAS,
        fillParent = true,
        padding = opts.iconPadding or 6,
    })
    if icon and icon.SetVertexColor and GUI2.GetColor then
        icon:SetVertexColor(GUI2:GetColor("color.text.accent"))
    end
    button.soundPreviewIcon = icon
    soundPreviewButtons[button] = true
    RefreshSoundPreviewButtons()
    return button
end

local function FetchLSMSoundPath(value)
    if value == nil or value == "None" or value == "" then
        return nil
    end
    if not (LSM and LSM.Fetch) then
        return nil
    end
    local path = LSM:Fetch("sound", value, true)
    if type(path) == "string" and path ~= "" then
        return path
    end
    return nil
end

local function BuildDefaultLSMSoundOptions(opts)
    local options = {}
    local seen = {}
    if opts.includeNone ~= false then
        local noneText = opts.noneText or GetCoreText("common.none", "None")
        options[#options + 1] = { text = noneText, value = "None" }
        seen.None = true
    end

    local list = LSM and LSM.List and LSM:List("sound")
    if type(list) == "table" then
        for _, name in ipairs(list) do
            if type(name) == "string" and name ~= "" and not seen[name] then
                options[#options + 1] = { text = name, value = name }
                seen[name] = true
            end
        end
    elseif LSM and LSM.HashTable then
        local mediaTable = LSM:HashTable("sound")
        if type(mediaTable) == "table" then
            local names = {}
            for name in pairs(mediaTable) do
                if type(name) == "string" and name ~= "" and not seen[name] then
                    names[#names + 1] = name
                end
            end
            table_sort(names)
            for _, name in ipairs(names) do
                options[#options + 1] = { text = name, value = name }
                seen[name] = true
            end
        end
    end

    if #options == 0 then
        options[1] = { text = opts.noneText or GetCoreText("common.none", "None"), value = "None" }
    end
    return options
end

local function BuildLSMSoundOptions(opts)
    local source = opts.options
    if type(source) == "function" then
        source = source()
    end
    if type(source) ~= "table" then
        source = BuildDefaultLSMSoundOptions(opts)
    end

    local options = {}
    for _, option in ipairs(source) do
        local copy
        if type(option) == "table" then
            copy = {}
            for key, value in pairs(option) do
                copy[key] = value
            end
        else
            copy = { text = tostring(option), value = option }
        end

        if copy.value == nil then
            copy.value = copy.text
        end
        if copy.text == nil then
            copy.text = tostring(copy.value or "")
        end

        if copy.value ~= "None" and type(copy.actionFunc) ~= "function" then
            local optionValue = copy.value
            local optionSoundPath = copy.soundPath
            copy.actionAtlas = copy.actionAtlas or SOUND_PREVIEW_PLAY_ATLAS
            copy.actionTooltip = copy.actionTooltip or opts.previewTooltip or GetCoreText("common.preview_sound", "Preview sound")
            copy.actionFunc = function()
                local path = optionSoundPath or FetchLSMSoundPath(optionValue)
                GUI2.Form:PlaySoundPreview(path, opts.getChannel and opts.getChannel() or opts.channel, "lsm:sound:" .. tostring(optionValue), {
                    onPreviewFailed = opts.onPreviewFailed,
                })
            end
        end
        options[#options + 1] = copy
    end
    return options
end

function GUI2.Form:CreateLSMSoundDropdown(parent, opts)
    opts = opts or {}
    BindItem(opts)

    local width = ResolveFormWidth(opts, "wide", 220)
    local height = opts.height or GetControlHeight(26)
    local buttonSize = opts.previewButtonSize or opts.buttonSize or height
    local buttonGap = opts.previewButtonGap or SOUND_PREVIEW_BUTTON_GAP
    local hasPreviewButton = opts.previewButton ~= false
    local dropdownWidth = hasPreviewButton and math_max(width - buttonSize - buttonGap, 1) or width

    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(width, height)
    frame.width = width
    frame.height = height
    ConfigureMotion(frame, opts)

    local dropdown
    local previewButton

    local function CurrentValue()
        return frame.value or GetValue(opts) or opts.default or "None"
    end

    local function PreviewToken(value)
        return "lsm:sound:" .. tostring(value or CurrentValue())
    end

    local function PreviewChannel()
        if opts.getChannel then
            return opts.getChannel()
        end
        return opts.channel
    end

    local function Commit(value, silent)
        frame.value = value or opts.default or "None"
        if dropdown and dropdown.SetValue then
            dropdown:SetValue(frame.value, true)
        end
        if previewButton then
            previewButton.gui2SoundPreviewToken = PreviewToken(frame.value)
            RefreshSoundPreviewButtons()
        end
        if not silent then
            CommitValue(opts, frame, frame.value)
        end
    end

    dropdown = self:CreateDropdown(frame, {
        width = dropdownWidth,
        height = height,
        menuWidth = opts.menuWidth or math_max(width, 240),
        placeholder = opts.placeholder,
        default = opts.default or "None",
        options = function()
            return BuildLSMSoundOptions(opts)
        end,
        get = CurrentValue,
        set = function(value)
            Commit(value, false)
        end,
    })
    dropdown:SetPoint("LEFT", frame, "LEFT", 0, 0)
    frame.dropdown = dropdown

    if hasPreviewButton then
        previewButton = self:CreateSoundPreviewButton(frame, {
            size = buttonSize,
            tooltip = opts.previewTooltip or GetCoreText("common.preview_sound", "Preview sound"),
            getPath = function()
                return FetchLSMSoundPath(CurrentValue())
            end,
            getChannel = PreviewChannel,
            getToken = function()
                return PreviewToken(CurrentValue())
            end,
            onPreviewFailed = opts.onPreviewFailed,
        })
        previewButton:SetPoint("LEFT", dropdown, "RIGHT", buttonGap, 0)
        frame.previewButton = previewButton
    end

    function frame:GetValue()
        return self.value
    end
    function frame:SetValue(value, silent)
        Commit(value, silent == true)
    end
    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled and true or false
        if self.dropdown and self.dropdown.SetDisabled then
            self.dropdown:SetDisabled(self.gui2Disabled)
        end
        if self.previewButton and self.previewButton.SetDisabled then
            self.previewButton:SetDisabled(self.gui2Disabled)
        end
    end
    function frame:RefreshTheme()
        if self.dropdown and self.dropdown.RefreshTheme then
            self.dropdown:RefreshTheme()
        end
        if self.previewButton and self.previewButton.RefreshTheme then
            self.previewButton:RefreshTheme()
        end
    end

    frame:SetValue(CurrentValue(), true)
    frame:SetDisabled(opts.disabled)
    GUI2:RegisterThemeObject(frame)
    return frame
end

function GUI2.Form:CreateSpecDropdown(parent, opts)
    opts = opts or {}

    local function ResolveSpecs()
        local specs = opts.specs or opts.options
        if type(specs) == "function" then specs = specs() end
        return type(specs) == "table" and specs or {}
    end

    local function BuildOptions()
        local options = {}
        local Icons = YUI.API and YUI.API.Icons
        local scopeID = opts.iconScopeID or opts.scopeID or "settings"

        for _, spec in ipairs(ResolveSpecs()) do
            if type(spec) == "table" then
                local specID = tonumber(spec.specID or spec.value)
                local value = spec.value
                if value == nil then value = specID end

                if value ~= nil then
                    local name = spec.name or spec.text or tostring(value)
                    local iconData = spec.iconData
                    if not iconData and Icons and Icons.GetScopedSpecIcon and specID then
                        iconData = Icons.GetScopedSpecIcon(specID, spec.icon, scopeID, opts.iconSetID)
                    end

                    options[#options + 1] = {
                        text = name,
                        selectionText = spec.selectionText or name,
                        value = value,
                        specID = specID,
                        specIndex = spec.specIndex,
                        classID = spec.classID,
                        classFile = spec.classFile,
                        icon = spec.icon,
                        texture = spec.texture,
                        atlas = spec.atlas,
                        texCoord = spec.texCoord,
                        texCoords = spec.texCoords,
                        iconData = iconData,
                        iconSize = spec.iconSize or opts.iconSize or 18,
                        blendMode = spec.blendMode,
                        render = spec.render,
                        func = spec.func,
                    }
                end
            end
        end

        return options
    end

    local dropdownOpts = {}
    for key, value in pairs(opts) do
        dropdownOpts[key] = value
    end
    dropdownOpts.options = BuildOptions
    dropdownOpts.placeholder = opts.placeholder or opts.emptyText or ""

    local dropdown = self:CreateDropdown(parent, dropdownOpts)
    local baseRefreshTheme = dropdown.RefreshTheme
    function dropdown:RefreshTheme(...)
        if self.SetValue then
            self:SetValue(self.value, true)
        end
        if baseRefreshTheme then baseRefreshTheme(self, ...) end
    end
    return dropdown
end

function GUI2.Form:CreateColorPicker(parent, opts)
    opts = opts or {}
    BindItem(opts)

    local height = opts.height or GetControlHeight(26)
    local chipSize = height - 4
    local labelWidth = tonumber(opts.labelWidth)
    local controlWidth = tonumber(opts.controlWidth)
    local gap = opts.gap or GetFormMetric("gap", 10)
    local useFormLane = opts.label and (opts.inlineLabel == true or opts.labelPosition == "left" or opts.formLabel ~= nil or labelWidth or controlWidth)
    local width = ResolveFormWidth(opts, "wide", 220)
    if useFormLane then
        labelWidth = labelWidth or GetFormMetric("labelWidth", 120)
        controlWidth = controlWidth or math_max(chipSize, width - labelWidth - gap)
        if not opts.width and not opts.size then
            width = labelWidth + gap + controlWidth
        end
    end
    local useField = opts.field == true or opts.fullWidth == true or opts.fillControl == true
    local fieldWidth = useField and (controlWidth or width) or chipSize
    local frame = GUI2:CreateButtonFrame(parent, { width = width, height = height })
    frame.width = width
    frame.height = height
    ConfigureMotion(frame, opts)

    local chipBg = GUI2:CreatePanel(frame, { width = fieldWidth, height = height - 6, surface = "color.control.bg", border = "color.border.default" })
    frame.chipBg = chipBg
    if chipBg.EnableMouse then chipBg:EnableMouse(false) end
    InheritMotion(chipBg, frame)
    local chip = chipBg:CreateTexture(nil, "ARTWORK")
    frame.chip = chip
    InheritMotion(chip, frame)
    frame.chipMotion = CreateMotionOverlay(chipBg, "color.accent.primary", { inset = true, scale = false })
    InheritMotion(frame.chipMotion, frame)

    local function RefreshColorChipPixelLayout()
        local inset = GetHairlineInset(chipBg)
        SetRegionInsideBorder(chip, chipBg, inset)
        if frame.chipMotion then
            SetRegionInsideBorder(frame.chipMotion, chipBg, inset)
            if frame.chipMotion.texture then
                frame.chipMotion.texture:ClearAllPoints()
                frame.chipMotion.texture:SetAllPoints(frame.chipMotion)
            end
        end
    end
    chipBg.UpdateGUI2PixelLayout = RefreshColorChipPixelLayout
    RefreshColorChipPixelLayout()

    if opts.label then
        local label = GUI2:CreateText(frame, opts.label, "font.size.md", "color.text.primary")
        if useFormLane then
            label:SetPoint("LEFT", frame, "LEFT", 0, 0)
            label:SetWidth(labelWidth)
            if useField then
                chipBg:SetWidth(controlWidth)
            end
            chipBg:SetPoint("LEFT", frame, "LEFT", labelWidth + gap, 0)
        else
            chipBg:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            label:SetPoint("LEFT", frame, "LEFT", 0, 0)
            label:SetPoint("RIGHT", chipBg, "LEFT", -8, 0)
        end
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        frame.text = label
    else
        chipBg:SetPoint("LEFT", 0, 0)
    end

    local function CurrentColor()
        return NormalizeColorValue(frame.value or GetValue(opts) or { 1, 1, 1, 1 })
    end
    local function UpdateChip()
        local r, g, b, a = CurrentColor()
        chip:SetColorTexture(r, g, b, a)
    end
    function frame:GetValue()
        local r, g, b, a = CurrentColor()
        return { r, g, b, a }
    end
    function frame:SetValue(value, silent)
        if value == nil then return end
        local isSilent, animate = ParseSetOptions(silent)
        self.value = value
        opts.value = value
        if not isSilent then CommitValue(opts, self, value) end
        UpdateChip()
        if animate and not self.gui2Disabled then
            PlayMotionOverlay(self.chipMotion, self, "color-chip")
        end
    end
    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled and true or false
        if self.gui2Disabled then
            if self.Disable then self:Disable() end
        else
            if self.Enable then self:Enable() end
        end
        self:RefreshTheme()
    end
    function frame:RefreshTheme()
        if self.chipBg then GUI2:RefreshPrimitive(self.chipBg) end
        if self.text then GUI2:SetTextColorKey(self.text, self.gui2Disabled and "color.text.disabled" or "color.text.primary") end
        if self.chipBg then GUI2:SetBorderColor(self.chipBg, self.gui2Disabled and "color.border.subtle" or "color.border.default") end
        UpdateChip()
    end

    frame:SetScript("OnClick", function(self)
        if self.gui2Disabled then return end
        local r, g, b, a = CurrentColor()
        local info
        info = {
            r = r,
            g = g,
            b = b,
            opacity = a,
            hasOpacity = opts.hasAlpha ~= false,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = a
                if opts.hasAlpha ~= false then
                    if ColorPickerFrame.GetColorAlpha then
                        na = ColorPickerFrame:GetColorAlpha()
                    elseif ColorPickerFrame.GetOpacity then
                        na = ColorPickerFrame:GetOpacity()
                    elseif ColorPickerFrame.opacity then
                        na = ColorPickerFrame.opacity
                    end
                end
                local value = { nr, ng, nb, na or 1 }
                self:SetValue(value)
            end,
            opacityFunc = function()
                if info.swatchFunc then info.swatchFunc() end
            end,
            cancelFunc = function()
                local value = { r, g, b, a }
                self:SetValue(value)
            end,
        }
        if opts.default then
            local def = opts.default
            if type(def) == "table" and type(def[1]) == "table" then def = def[1] end
            if type(def) == "table" then
                local dR, dG, dB, dA = NormalizeColorValue(def)
                info.defaultColor = { r = dR, g = dG, b = dB, a = dA }
            end
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func = info.swatchFunc
            ColorPickerFrame.opacityFunc = info.opacityFunc
            ColorPickerFrame.cancelFunc = info.cancelFunc
            ColorPickerFrame.hasOpacity = info.hasOpacity
            ColorPickerFrame:SetColorRGB(r, g, b)
            if ColorPickerFrame.SetOpacity then ColorPickerFrame:SetOpacity(a) end
            ColorPickerFrame.previousValues = { r, g, b, a }
            ColorPickerFrame:Show()
        end
    end)
    frame:SetScript("OnEnter", function(self)
        if self.gui2Disabled then return end
        if self.chipBg then GUI2:SetBorderColor(self.chipBg, "color.border.accent") end
        if self.text then GUI2:SetTextColorKey(self.text, "color.text.accent") end
    end)
    frame:SetScript("OnLeave", function(self)
        self:RefreshTheme()
    end)

    AddTooltip(frame, opts)
    frame:SetValue(GetValue(opts) or opts.default or { 1, 1, 1, 1 }, true)
    frame:SetDisabled(opts.disabled)
    GUI2:RegisterThemeObject(frame)
    return frame
end

local function NormalizeGlowSizeOption(value, fallback)
    value = tonumber(value)
    if value == nil then value = tonumber(fallback) or 1 end
    if value > 5 then
        value = value / 10
    end
    if value < 0.25 then return 0.25 end
    if value > 5 then return 5 end
    return value
end

local function NormalizeGlowExpandOption(value, fallback)
    value = tonumber(value)
    if value == nil then value = tonumber(fallback) or 0 end
    if value > 1 or value < -1 then
        value = value / 24
    end
    if value < -1 then return -1 end
    if value > 1 then return 1 end
    return value
end

local function NormalizeGlowColorOption(value, fallback)
    local source = value
    if source == nil then source = fallback end
    local r, g, b, a = NormalizeColorValue(source or { 1, 0.82, 0.12, 1 })
    return {
        math_max(0, math_min(1, tonumber(r) or 1)),
        math_max(0, math_min(1, tonumber(g) or 1)),
        math_max(0, math_min(1, tonumber(b) or 1)),
        math_max(0, math_min(1, tonumber(a) or 1)),
    }
end

local function NormalizeGlowOptionsValue(value, fallback)
    value = type(value) == "table" and value or {}
    fallback = type(fallback) == "table" and fallback or {}
    local style = value.style or fallback.style or "soft"
    if style ~= "none" and style ~= "pixel" and style ~= "soft" and style ~= "button" and style ~= "autocast" and style ~= "proc" and style ~= "pulse" then
        style = "soft"
    end
    return {
        style = style,
        size = NormalizeGlowSizeOption(value.size, fallback.size),
        lines = tonumber(value.lines) or tonumber(fallback.lines) or 4,
        thickness = tonumber(value.thickness) or tonumber(fallback.thickness) or 1,
        length = tonumber(value.length) or tonumber(fallback.length) or 20,
        speed = tonumber(value.speed) or tonumber(fallback.speed) or 0.25,
        alpha = tonumber(value.alpha) or tonumber(fallback.alpha) or 0.9,
        falloff = tonumber(value.falloff) or tonumber(fallback.falloff) or 0.3,
        offsetX = NormalizeGlowExpandOption(value.offsetX ~= nil and value.offsetX or value.xOffset, fallback.offsetX ~= nil and fallback.offsetX or fallback.xOffset),
        offsetY = NormalizeGlowExpandOption(value.offsetY ~= nil and value.offsetY or value.yOffset, fallback.offsetY ~= nil and fallback.offsetY or fallback.yOffset),
        color = NormalizeGlowColorOption(value.color, fallback.color),
    }
end

local function FormatGlowSummaryNumber(value, decimals)
    value = tonumber(value) or 0
    if decimals == 0 then
        return string_format("%d", math_floor(value + 0.5))
    end
    return string_format("%." .. (decimals or 2) .. "f", value)
end

local function FormatGlowColorSummary(value)
    local r, g, b = NormalizeColorValue(value)
    r = math_floor(math_max(0, math_min(1, tonumber(r) or 1)) * 255 + 0.5)
    g = math_floor(math_max(0, math_min(1, tonumber(g) or 1)) * 255 + 0.5)
    b = math_floor(math_max(0, math_min(1, tonumber(b) or 1)) * 255 + 0.5)
    return string_format("#%02X%02X%02X", r, g, b)
end

function GUI2.Form:CreateGlowOptions(parent, opts)
    opts = opts or {}
    BindItem(opts)

    local labels = opts.labels or {}
    local width = ResolveFormWidth(opts, "wide", 360)
    local expanded = opts.expanded == true
    if opts.getExpanded then
        expanded = opts.getExpanded() == true
    end
    local controlHeight = opts.controlHeight or GetControlHeight(26)
    local buttonSize = opts.settingsButtonSize or opts.buttonSize or controlHeight
    local buttonGap = opts.buttonGap or 10
    local topRowHeight = math_max(opts.rowHeight or GetFormMetric("rowHeight", 32), controlHeight, buttonSize)
    local panelGap = opts.panelGap or 8
    local panelInset = opts.panelInset or 10
    local rowHeight = 26
    local rowGap = 8
    local fieldGap = opts.fieldGap or 12
    local valueWidth = opts.inputWidth or GetFormMetric("valueWidth", 56)
    local panelWidth = opts.panelWidth or opts.expandedWidth or width
    local maxDropdownWidth = math_max(width - buttonGap - buttonSize, 1)
    local dropdownWidth = math_min(opts.dropdownWidth or maxDropdownWidth, maxDropdownWidth)
    local availablePanelWidth = math_max(panelWidth - (panelInset * 2), 1)
    local sliderMinWidth = opts.sliderMinWidth or 180
    local fieldColumns = availablePanelWidth >= (sliderMinWidth * 2 + fieldGap) and 2 or 1
    local sliderWidth = fieldColumns == 2 and math_floor((availablePanelWidth - fieldGap) / 2) or availablePanelWidth
    local fieldLabelWidth = opts.fieldLabelWidth or opts.paramLabelWidth or 84
    local fieldLabelGap = opts.fieldLabelGap or opts.paramLabelGap or GetFormMetric("gap", 10)

    local function WithColorField(fields)
        table.insert(fields, 1, { key = "color", type = "color", label = labels.color or "发光颜色" })
        return fields
    end

    local function GetExpandedFields(style)
        if style == "none" then
            return {}
        end
        if style == "pixel" then
            return WithColorField({
                { key = "lines", label = labels.lines or "线段数量", min = 1, max = 20, step = 1, precision = 0 },
                { key = "thickness", label = labels.thickness or "线段粗细", min = 1, max = 20, step = 1, precision = 0 },
                { key = "length", label = labels.length or "长度", min = 4, max = 80, step = 1, precision = 0 },
                { key = "speed", label = labels.speed or "速度", min = 0, max = 3, step = 0.05, precision = 2 },
                { key = "alpha", label = labels.alpha or "透明", min = 0.1, max = 1, step = 0.05, precision = 2 },
                { key = "falloff", label = labels.falloff or "衰减", min = 0, max = 0.8, step = 0.05, precision = 2 },
                { key = "offsetX", label = labels.offsetX or "X 扩展", min = -1, max = 1, step = 0.05, precision = 2 },
                { key = "offsetY", label = labels.offsetY or "Y 扩展", min = -1, max = 1, step = 0.05, precision = 2 },
            })
        end
        if style == "soft" then
            return WithColorField({
                { key = "size", label = labels.size or "发光尺寸", min = 0.25, max = 5, step = 0.05, precision = 2 },
                { key = "alpha", label = labels.alpha or "透明", min = 0.1, max = 1, step = 0.05, precision = 2 },
                { key = "offsetX", label = labels.offsetX or "X 扩展", min = -1, max = 1, step = 0.05, precision = 2 },
                { key = "offsetY", label = labels.offsetY or "Y 扩展", min = -1, max = 1, step = 0.05, precision = 2 },
            })
        end
        local fields = {
            { key = "size", label = labels.size or "发光尺寸", min = 0.25, max = 5, step = 0.05, precision = 2 },
            { key = "speed", label = labels.speed or "速度", min = 0, max = 3, step = 0.05, precision = 2 },
            { key = "alpha", label = labels.alpha or "透明", min = 0.1, max = 1, step = 0.05, precision = 2 },
            { key = "offsetX", label = labels.offsetX or "X 扩展", min = -1, max = 1, step = 0.05, precision = 2 },
            { key = "offsetY", label = labels.offsetY or "Y 扩展", min = -1, max = 1, step = 0.05, precision = 2 },
        }
        if style == "autocast" then
            table.insert(fields, 2, { key = "lines", label = labels.lines or "线段数量", min = 1, max = 20, step = 1, precision = 0 })
        end
        return WithColorField(fields)
    end

    local value = NormalizeGlowOptionsValue(GetValue(opts), opts.default)
    local currentFields = GetExpandedFields(value.style)
    local hasParameters = #currentFields > 0
    expanded = expanded and hasParameters
    local frameWidth = expanded and math_max(width, panelWidth) or width
    local fields = expanded and currentFields or {}
    local fieldRows = expanded and math_ceil(#fields / fieldColumns) or 0
    local resetRows = expanded and hasParameters and 1 or 0
    local panelHeight = 0
    if expanded then
        local totalRows = fieldRows + resetRows
        local fieldsHeight = totalRows * rowHeight + math_max(totalRows - 1, 0) * rowGap
        panelHeight = panelInset * 2 + fieldsHeight
    end
    local height = topRowHeight + (expanded and (panelGap + panelHeight) or 0)
    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(frameWidth, height)
    frame.width = frameWidth
    frame.height = height
    frame.gui2TopRowHeight = topRowHeight
    frame.controls = {}
    ConfigureMotion(frame, opts)

    local function Commit(nextValue, refresh)
        value = NormalizeGlowOptionsValue(nextValue, opts.default)
        frame.value = value
        CommitValue(opts, frame, value)
        if refresh and opts.onRequestRefresh then
            opts.onRequestRefresh(frame, value)
        end
    end

    local function BuildSummary(current)
        current = NormalizeGlowOptionsValue(current, opts.default)
        if current.style == "none" then
            return labels.noneSummary or labels.none or "无"
        end
        local parts = {}
        if current.style == "pixel" then
            parts[#parts + 1] = (labels.summaryLines or "线") .. " " .. FormatGlowSummaryNumber(current.lines, 0)
            parts[#parts + 1] = (labels.summaryThickness or "宽") .. " " .. FormatGlowSummaryNumber(current.thickness, 0)
            parts[#parts + 1] = (labels.summaryLength or "长") .. " " .. FormatGlowSummaryNumber(current.length, 0)
            parts[#parts + 1] = (labels.summarySpeed or "速") .. " " .. FormatGlowSummaryNumber(current.speed, 2)
        elseif current.style == "soft" then
            parts[#parts + 1] = (labels.summarySize or "尺寸") .. " " .. FormatGlowSummaryNumber(current.size, 2)
        else
            parts[#parts + 1] = (labels.summarySize or "尺寸") .. " " .. FormatGlowSummaryNumber(current.size, 2)
            if current.style == "autocast" then
                parts[#parts + 1] = (labels.summaryLines or "线") .. " " .. FormatGlowSummaryNumber(current.lines, 0)
            end
            parts[#parts + 1] = (labels.summarySpeed or "速") .. " " .. FormatGlowSummaryNumber(current.speed, 2)
        end
        parts[#parts + 1] = (labels.summaryAlpha or "透明") .. " " .. FormatGlowSummaryNumber(current.alpha, 2)
        if current.offsetX ~= 0 or current.offsetY ~= 0 then
            parts[#parts + 1] = (labels.summaryOffset or "扩展") .. " " .. FormatGlowSummaryNumber(current.offsetX, 2) .. "/" .. FormatGlowSummaryNumber(current.offsetY, 2)
        end
        parts[#parts + 1] = (labels.summaryColor or "色") .. " " .. FormatGlowColorSummary(current.color)
        return table.concat(parts, " · ")
    end

    local function ResolveStyleDefaults(style)
        local defaultsByStyle = opts.defaultsByStyle
        if type(defaultsByStyle) == "function" then
            defaultsByStyle = defaultsByStyle()
        end
        local defaults = type(defaultsByStyle) == "table" and defaultsByStyle[style] or nil
        if type(defaults) == "function" then
            defaults = defaults(style, value)
        end
        defaults = NormalizeGlowOptionsValue(defaults, opts.default)
        defaults.style = style
        return defaults
    end

    local function BuildResetValue()
        local nextValue = NormalizeGlowOptionsValue(value, opts.default)
        local defaults = ResolveStyleDefaults(nextValue.style)
        for _, field in ipairs(GetExpandedFields(nextValue.style)) do
            nextValue[field.key] = defaults[field.key]
        end
        return nextValue
    end

    local function ResolveStyleOptions()
        local options = opts.styleOptions or opts.options
        if type(options) == "function" then
            options = options()
        end
        return options or {}
    end

    local function GetStyleText(style)
        for _, option in ipairs(ResolveStyleOptions()) do
            if type(option) == "table" then
                if option.value == style then
                    return option.selectionText or option.text or tostring(option.value)
                end
            elseif option == style then
                return tostring(option)
            end
        end
        return tostring(style or "")
    end

    local function ShowSettingsTooltip(owner)
        if not (owner and GameTooltip) then return end
        GameTooltip:SetOwner(owner, opts.tooltipAnchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(labels.paramsDetail or labels.params or labels.expand or "参数详情")
        GameTooltip:AddLine((labels.type or "类型") .. ": " .. GetStyleText(value.style), 1, 0.82, 0, true)
        GameTooltip:AddLine(value.style == "none" and (labels.noParams or "无可设置参数") or BuildSummary(value), 1, 1, 1, true)
        GameTooltip:Show()
    end

    local function RefreshSettingsTooltip()
        if frame.settingsButton and frame.settingsButton.IsMouseOver and frame.settingsButton:IsMouseOver() then
            ShowSettingsTooltip(frame.settingsButton)
        end
    end

    local dropdown = self:CreateDropdown(frame, {
        width = dropdownWidth,
        height = controlHeight,
        options = opts.styleOptions or opts.options,
        get = function() return value.style end,
        set = function(style)
            local nextValue = NormalizeGlowOptionsValue(value, opts.default)
            local previousStyle = nextValue.style
            nextValue.style = style
            if opts.applyStyleDefaultsOnChange and style ~= previousStyle then
                local defaults = ResolveStyleDefaults(style)
                for _, field in ipairs(GetExpandedFields(style)) do
                    if field.key ~= "alpha" and field.key ~= "offsetX" and field.key ~= "offsetY" and field.key ~= "color" then
                        nextValue[field.key] = defaults[field.key]
                    end
                end
            end
            if style == "none" and opts.setExpanded then
                opts.setExpanded(false)
            end
            Commit(nextValue, true)
        end,
    })
    dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -math_floor((topRowHeight - controlHeight) / 2))
    frame.dropdown = dropdown
    frame.controls[#frame.controls + 1] = dropdown

    local settingsButton = self:CreateIconButton(frame, {
        size = buttonSize,
        icon = opts.settingsIcon or "Interface\\Icons\\INV_Misc_Gear_01",
        atlas = opts.settingsAtlas,
        tone = "default",
        state = expanded and "selected" or "normal",
        onClick = function()
            if GameTooltip then YUI.HideGameTooltip() end
            if not hasParameters then
                if opts.setExpanded then
                    opts.setExpanded(false)
                end
                return
            end
            local nextExpanded = not expanded
            if opts.setExpanded then
                opts.setExpanded(nextExpanded)
            end
            if opts.onRequestRefresh then
                opts.onRequestRefresh(frame, value)
            end
        end,
    })
    settingsButton:SetPoint("TOPLEFT", frame, "TOPLEFT", dropdownWidth + buttonGap, -math_floor((topRowHeight - buttonSize) / 2))
    settingsButton:HookScript("OnEnter", ShowSettingsTooltip)
    settingsButton:HookScript("OnLeave", function()
        if GameTooltip then YUI.HideGameTooltip() end
    end)
    frame.settingsButton = settingsButton
    frame.controls[#frame.controls + 1] = settingsButton

    local fieldParent = frame
    if expanded then
        local panel = GUI2:CreatePanel(frame, {
            width = panelWidth,
            height = panelHeight,
            surface = "color.surface.sunken",
            border = "color.border.subtle",
        })
        panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(topRowHeight + panelGap))
        frame.panel = panel
        fieldParent = panel
    end

    for index, field in ipairs(fields) do
        local row = math.floor((index - 1) / fieldColumns)
        local col = (index - 1) % fieldColumns
        local control
        if field.type == "color" then
            control = self:CreateColorPicker(fieldParent, {
                label = field.label,
                width = sliderWidth,
                labelWidth = fieldLabelWidth,
                controlWidth = math_max(26, sliderWidth - fieldLabelWidth - fieldLabelGap),
                gap = fieldLabelGap,
                fillControl = true,
                hasAlpha = true,
                get = function() return value[field.key] end,
                set = function(nextFieldValue)
                    local nextValue = NormalizeGlowOptionsValue(value, opts.default)
                    nextValue[field.key] = NormalizeGlowColorOption(nextFieldValue, value[field.key])
                    Commit(nextValue, false)
                    RefreshSettingsTooltip()
                end,
            })
        else
            control = self:CreateSlider(fieldParent, {
                label = field.label,
                inline = true,
                width = sliderWidth,
                inputWidth = valueWidth,
                labelWidth = fieldLabelWidth,
                min = field.min,
                max = field.max,
                step = field.step,
                precision = field.precision,
                get = function() return value[field.key] end,
                set = function(nextFieldValue)
                    local nextValue = NormalizeGlowOptionsValue(value, opts.default)
                    nextValue[field.key] = nextFieldValue
                    Commit(nextValue, false)
                    RefreshSettingsTooltip()
                end,
            })
        end
        control:SetPoint("TOPLEFT", fieldParent, "TOPLEFT", panelInset + col * (sliderWidth + fieldGap), -(panelInset + row * (rowHeight + rowGap)))
        frame.controls[#frame.controls + 1] = control
    end

    if expanded and hasParameters then
        local resetButtonWidth = opts.resetButtonWidth or 76
        local resetButton = self:CreateButton(fieldParent, {
            text = labels.reset or "重置",
            width = resetButtonWidth,
            height = rowHeight,
            onClick = function()
                Commit(BuildResetValue(), true)
                RefreshSettingsTooltip()
            end,
        })
        resetButton:SetPoint("TOPRIGHT", fieldParent, "TOPRIGHT", -panelInset, -(panelInset + fieldRows * (rowHeight + rowGap)))
        frame.resetButton = resetButton
        frame.controls[#frame.controls + 1] = resetButton
    end

    function frame:GetValue()
        return value
    end
    function frame:SetValue(nextValue, silent)
        value = NormalizeGlowOptionsValue(nextValue, opts.default)
        self.value = value
        if self.dropdown and self.dropdown.SetValue then
            self.dropdown:SetValue(value.style, true)
        end
        RefreshSettingsTooltip()
        if not silent then
            CommitValue(opts, self, value)
        end
    end
    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled and true or false
        for _, control in ipairs(self.controls) do
            if control.SetDisabled then
                control:SetDisabled(self.gui2Disabled)
            elseif self.gui2Disabled and control.Disable then
                control:Disable()
            elseif control.Enable then
                control:Enable()
            end
        end
    end
    function frame:RefreshTheme()
        if self.panel and self.panel.RefreshTheme then self.panel:RefreshTheme() end
        for _, control in ipairs(self.controls) do
            if control.RefreshTheme then
                control:RefreshTheme()
            end
        end
    end

    AddTooltip(frame, opts)
    frame:SetDisabled(opts.disabled)
    GUI2:RegisterThemeObject(frame)
    return frame
end

local function CreateSection(parent, title, x, y, width, height)
    local panel = GUI2:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    panel:SetPoint("TOPLEFT", x, y)
    local label = GUI2:CreateText(panel, title, "font.size.lg", "color.text.heading")
    label:SetPoint("TOPLEFT", 12, -10)
    return panel
end

function GUI2.Form:RenderLab(parent, lab)
    local width = parent:GetWidth() > 100 and parent:GetWidth() or 920
    lab:RenderHeader(parent, "表单控件（Form）", "用于设置页和配置面板的输入控件，重点检查点击、选择、禁用、展开和输入状态。")
    lab:RenderComponentList(parent, "组件清单（Component List）", {
        "按钮（Button）", "复选框（Checkbox）", "开关（Switch）", "二选一（BinaryChoice）",
        "分段选择（SegmentedControl）", "滑条（Slider）", "输入框（EditBox）", "下拉框（Dropdown）", "颜色选择（ColorPicker）",
    })

    local statePanel = CreateSection(parent, "按钮状态（Button States）", 18, -88, width - 36, 84)
    local states = {
        { text = "默认", state = "normal", tone = "default" },
        { text = "悬停", state = "hover", tone = "default" },
        { text = "按下", state = "pressed", tone = "default" },
        { text = "选中", state = "selected", tone = "accent" },
        { text = "警告", state = "normal", tone = "warning" },
        { text = "危险", state = "normal", tone = "danger" },
        { text = "禁用", state = "disabled", tone = "default", disabled = true },
    }
    for i, state in ipairs(states) do
        local btn = self:CreateButton(statePanel, { text = state.text, width = 104, height = 26, tone = state.tone, state = state.state, disabled = state.disabled })
        btn:SetPoint("TOPLEFT", 12 + ((i - 1) * 114), -42)
        btn:SetState(state.state)
    end

    local choicePanel = CreateSection(parent, "选择控件（Choices）", 18, -184, 420, 304)
    local checkbox = self:CreateCheckbox(choicePanel, { text = "启用鼠标提示", checked = true, width = 230 })
    checkbox:SetPoint("TOPLEFT", 12, -44)
    local disabledCheck = self:CreateCheckbox(choicePanel, { text = "禁用的复选框", disabled = true, width = 230 })
    disabledCheck:SetPoint("TOPLEFT", 12, -78)
    local switchState
    local switch = self:CreateSwitch(choicePanel, {
        checked = true,
        width = 70,
        onText = "开",
        offText = "关",
        onChange = function(_, value)
            if switchState then switchState:SetText(value and "开关：已启用" or "开关：已关闭") end
        end,
    })
    switch:SetPoint("TOPLEFT", 248, -44)
    switchState = GUI2:CreateText(choicePanel, "开关：已启用", "font.size.sm", "color.text.secondary")
    switchState:SetPoint("LEFT", switch, "RIGHT", 10, 0)
    local offSwitch = self:CreateSwitch(choicePanel, { checked = false, width = 70, onText = "开", offText = "关" })
    offSwitch:SetPoint("TOPLEFT", 248, -78)
    local disabledSwitch = self:CreateSwitch(choicePanel, { checked = true, width = 70, onText = "开", offText = "关", disabled = true })
    disabledSwitch:SetPoint("TOPLEFT", 328, -78)
    local binary = self:CreateBinaryChoice(choicePanel, {
        width = 210,
        value = "server",
        values = {
            { text = "服务器", value = "server" },
            { text = "本地", value = "local" },
        },
    })
    binary:SetPoint("TOPLEFT", 12, -116)
    local segmented = self:CreateSegmentedControl(choicePanel, {
        width = 170,
        value = "raid",
        items = {
            { text = "单人", value = "solo" },
            { text = "小队", value = "party" },
            { text = "团队", value = "raid" },
        },
    })
    segmented:SetPoint("TOPLEFT", 238, -116)

    local inputPanel = CreateSection(parent, "输入控件（Inputs）", 456, -184, width - 474, 304)
    local slider = self:CreateSlider(inputPanel, { width = 320, value = 64, min = 0, max = 100, step = 1, inline = true, label = "缩放" })
    slider:SetPoint("TOPLEFT", 16, -46)
    local slider2 = self:CreateSlider(inputPanel, { width = 220, value = 35, min = 0, max = 100, step = 5, label = "透明度" })
    slider2:SetPoint("TOPLEFT", 16, -82)
    local edit = self:CreateEditBox(inputPanel, { width = 210, text = "可编辑内容" })
    edit:SetPoint("TOPLEFT", 250, -78)
    local disabledEdit = self:CreateEditBox(inputPanel, { width = 210, text = "禁用输入框", disabled = true })
    disabledEdit:SetPoint("TOPLEFT", 250, -112)
    local dropdown = self:CreateDropdown(inputPanel, {
        width = 210,
        value = "midnight",
        options = {
            { text = "午夜黑", value = "midnight" },
            { text = "原生黑金", value = "gilded" },
        },
    })
    dropdown:SetPoint("TOPLEFT", 16, -142)
    local disabledDropdown = self:CreateDropdown(inputPanel, {
        width = 210,
        value = "lock",
        disabled = true,
        options = {
            { text = "锁定", value = "lock" },
            { text = "解锁", value = "unlock" },
        },
    })
    disabledDropdown:SetPoint("TOPLEFT", 250, -146)
    local color = self:CreateColorPicker(inputPanel, { label = "强调色", width = 150, default = { 1, 0.82, 0, 1 } })
    color:SetPoint("TOPLEFT", 16, -172)
    local colorNoAlpha = self:CreateColorPicker(inputPanel, { label = "无透明度", width = 150, hasAlpha = false, default = { 0.24, 0.78, 0.95, 1 } })
    colorNoAlpha:SetPoint("LEFT", color, "RIGHT", 14, 0)
end
