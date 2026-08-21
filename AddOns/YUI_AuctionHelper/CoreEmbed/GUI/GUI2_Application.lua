do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local Assets = YUI.Assets
local CreateFrame = CreateFrame
local GetTime = GetTime
local GameTooltip = GameTooltip
local ipairs = ipairs
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local pairs = pairs
local pcall = pcall
local string_format = string.format
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local table_concat = table.concat
local table_insert = table.insert
local table_remove = table.remove
local tonumber = tonumber
local tostring = tostring
local type = type

GUI2.Application = GUI2.Application or {}
local App = GUI2.Application
local STATUS_BAR_INTERPOLATION = _G.Enum
    and _G.Enum.StatusBarInterpolation
local STATUS_BAR_INTERPOLATION_IMMEDIATE = STATUS_BAR_INTERPOLATION
    and (STATUS_BAR_INTERPOLATION.Immediate
        or STATUS_BAR_INTERPOLATION.None) or 0
local STATUS_BAR_INTERPOLATION_SMOOTH = STATUS_BAR_INTERPOLATION
    and STATUS_BAR_INTERPOLATION.ExponentialEaseOut
    or STATUS_BAR_INTERPOLATION_IMMEDIATE
local DEFAULT_CAST_BAR_TEXTURE = "Interface\\Buttons\\WHITE8x8"
local MAX_RESOURCE_CELLS = 25
local RESOURCE_CIRCLE_MASK = Assets and Assets.Core
    and Assets:Core("gui2\\shapes\\circle-mask.tga")
    or "Interface\\AddOns\\YUI_AuctionHelper\\CoreEmbed\\Media\\Core\\gui2\\shapes\\circle-mask.tga"
local RESOURCE_CIRCLE_BORDERS = {
    Assets and Assets.Core and Assets:Core("gui2\\shapes\\circle-border-1.tga"),
    Assets and Assets.Core and Assets:Core("gui2\\shapes\\circle-border-2.tga"),
    Assets and Assets.Core and Assets:Core("gui2\\shapes\\circle-border-3.tga"),
    Assets and Assets.Core and Assets:Core("gui2\\shapes\\circle-border-4.tga"),
}
local DEFAULT_ICON_PICKER_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ICON_PICKER_RECENT_LIMIT = 24
local ICON_PICKER_SEARCH_LIMIT = 360
local ICON_PICKER_SPELL_LIMIT = 80
local ICON_PICKER_SEARCH_DEBOUNCE = 0.18
local ICON_PICKER_FAST_DEBOUNCE = 0.03
local ICON_PICKER_CACHE_REFRESH_INTERVAL = 0.35
local ICON_PICKER_SEARCH_BUDGET_MS = 3
local ICON_PICKER_SEARCH_MAX_ENTRIES = 1200
local ICON_PICKER_COLUMNS = 8
local ICON_PICKER_ROWS = 6
local ICON_PICKER_PAGE_SIZE = ICON_PICKER_COLUMNS * ICON_PICKER_ROWS
local ICON_PICKER_CACHE_OWNER = "gui2.icon-picker"
local ICON_PICKER_CACHE_RELEASE_DELAY = 60
local DURATION_RING_MATERIALS = {
    { thickness = 4, sourceStroke = 12 },
    { thickness = 8, sourceStroke = 20 },
    { thickness = 14, sourceStroke = 30 },
    { thickness = 22, sourceStroke = 42 },
}
local DURATION_RING_SOURCE_SIZE = 256
local DURATION_RING_OUTER_RADIUS = 126.5
local DURATION_RING_INNER_MASK_RADIUS = 96 / 256

local function NormalizeDurationRingThickness(value)
    value = tonumber(value) or 8
    if value <= 6 then return 4 end
    if value <= 11 then return 8 end
    if value <= 18 then return 14 end
    return 22
end

local function ResolveDurationRingMaterialMetrics(
    requestedThickness,
    size,
    referenceSize,
    forcedThickness
)
    requestedThickness = NormalizeDurationRingThickness(
        requestedThickness
    )
    size = math_max(1, tonumber(size) or 1)
    referenceSize = math_max(1, tonumber(referenceSize) or size)
    local requestedStroke = DURATION_RING_MATERIALS[2].sourceStroke
    for index = 1, #DURATION_RING_MATERIALS do
        local material = DURATION_RING_MATERIALS[index]
        if material.thickness == requestedThickness then
            requestedStroke = material.sourceStroke
            break
        end
    end
    local target = requestedStroke * referenceSize
    local bestThickness = requestedThickness
    local bestStroke = requestedStroke
    local bestDelta
    for index = 1, #DURATION_RING_MATERIALS do
        local material = DURATION_RING_MATERIALS[index]
        local eligible = forcedThickness == nil
            or material.thickness == forcedThickness
        local delta = math_abs((material.sourceStroke * size) - target)
        if eligible and (bestDelta == nil or delta < bestDelta) then
            bestDelta = delta
            bestThickness = material.thickness
            bestStroke = material.sourceStroke
        end
    end
    return bestThickness,
        (bestStroke * size) / DURATION_RING_SOURCE_SIZE,
        target / DURATION_RING_SOURCE_SIZE,
        (DURATION_RING_OUTER_RADIUS * size)
            / DURATION_RING_SOURCE_SIZE
end

local function ResolveConcentricDurationRingMetrics(
    previousOuterRadius,
    gap,
    requestedThickness,
    referenceSize
)
    previousOuterRadius = math_max(
        0,
        tonumber(previousOuterRadius) or 0
    )
    gap = math_max(0, tonumber(gap) or 0)
    referenceSize = math_max(1, tonumber(referenceSize) or 1)
    requestedThickness = NormalizeDurationRingThickness(
        requestedThickness
    )
    local requestedStroke = DURATION_RING_MATERIALS[2].sourceStroke
    for index = 1, #DURATION_RING_MATERIALS do
        local material = DURATION_RING_MATERIALS[index]
        if material.thickness == requestedThickness then
            requestedStroke = material.sourceStroke
            break
        end
    end
    local targetThickness = requestedStroke * referenceSize
        / DURATION_RING_SOURCE_SIZE
    local targetInnerRadius = previousOuterRadius + gap
    local bestMaterial
    local bestDiameter
    local bestThickness
    local bestDelta
    for index = 1, #DURATION_RING_MATERIALS do
        local material = DURATION_RING_MATERIALS[index]
        local innerSourceRadius = DURATION_RING_OUTER_RADIUS
            - material.sourceStroke
        if innerSourceRadius > 0 then
            local diameter = targetInnerRadius
                * DURATION_RING_SOURCE_SIZE / innerSourceRadius
            local actualThickness = material.sourceStroke * diameter
                / DURATION_RING_SOURCE_SIZE
            local delta = math_abs(actualThickness - targetThickness)
            if bestDelta == nil or delta < bestDelta then
                bestDelta = delta
                bestMaterial = material.thickness
                bestDiameter = diameter
                bestThickness = actualThickness
            end
        end
    end
    if bestMaterial == nil then return nil end
    return bestMaterial,
        bestDiameter,
        bestThickness,
        DURATION_RING_OUTER_RADIUS * bestDiameter
            / DURATION_RING_SOURCE_SIZE,
        targetThickness
end

local function IsSecretValue(value)
    local Security = YUI.API and YUI.API.Security
    if Security and Security.IsSecretValue then
        return Security.IsSecretValue(value) == true
    end
    if issecretvalue then
        local ok, result = pcall(issecretvalue, value)
        return ok and result == true
    end
    return false
end

local function BindConfigItem(item)
    if not item or not item.key then return end

    if not item.get then
        item.get = function()
            if YUI and YUI.getConfigByKey then
                return YUI:getConfigByKey(item.key, item.default)
            end
            return item.default
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

    if type(setOptions) == "table" then
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

    return silent, animate
end

local CreateSurface

local function CreateCenteredMotionOverlay(parent, width, height)
    if not parent then return nil end
    local overlay = CreateSurface(parent, {
        width = width,
        height = height,
        surface = "color.control.active",
        border = "color.border.accent",
    }, "Frame")
    overlay:SetPoint("CENTER", parent, "CENTER", 0, 0)
    overlay:SetAlpha(0)
    overlay:Hide()
    if overlay.EnableMouse then overlay:EnableMouse(false) end
    if overlay.SetFrameLevel and parent.GetFrameLevel then
        overlay:SetFrameLevel(parent:GetFrameLevel() + 8)
    end
    overlay.gui2MotionWidth = width
    overlay.gui2MotionHeight = height
    return overlay
end

local function PlayCenteredMotionOverlay(parent, key)
    local overlay = parent and parent.motionOverlay
    if not overlay or not GUI2.PlayControlMotion then
        return
    end

    local width = overlay.gui2MotionWidth or (parent.GetWidth and parent:GetWidth()) or 1
    local height = overlay.gui2MotionHeight or (parent.GetHeight and parent:GetHeight()) or 1
    overlay:SetSize(width, height)
    overlay:SetAlpha(0.12)
    overlay:Show()

    local handle = GUI2:PlayControlMotion(overlay, key or "centered-overlay", {
        owner = parent,
        durationKey = "quick",
        easing = "sineOut",
        effects = {
            { type = "alpha", from = 0.12, to = 0 },
            { type = "size", fromWidth = width * 0.985, fromHeight = height * 0.985, toWidth = width * 1.015, toHeight = height * 1.015 },
        },
        onFinished = function()
            overlay:SetSize(width, height)
            overlay:SetAlpha(0)
            overlay:Hide()
        end,
    })
    if not handle then
        overlay:SetSize(width, height)
        overlay:SetAlpha(0)
        overlay:Hide()
    end
end

local function ApplySurface(frame, surfaceKey)
    if frame.SetBackdropColor then
        frame:SetBackdropColor(GUI2:GetColor(surfaceKey))
    elseif frame.gui2Bg then
        frame.gui2Bg:SetColorTexture(GUI2:GetColor(surfaceKey))
    end
    frame.gui2Surface = surfaceKey
end

local function ToneColorKey(tone, fallback)
    if tone == "success" then
        return "color.state.success"
    elseif tone == "warning" then
        return "color.state.warning"
    elseif tone == "danger" or tone == "error" then
        return "color.state.error"
    elseif tone == "info" then
        return "color.state.info"
    elseif tone == "accent" then
        return "color.text.accent"
    end
    return fallback or "color.text.primary"
end

local function ResolveThemeToken(key, fallback)
    if key and GUI2.GetToken and GUI2:GetToken(key) then
        return key
    end
    return fallback
end

function CreateSurface(parent, opts, frameType)
    opts = opts or {}
    local frame = CreateFrame(frameType or "Frame", opts.name, parent, "BackdropTemplate")
    if opts.width and opts.height then
        frame:SetSize(opts.width, opts.height)
    end
    frame.gui2RadiusKey = opts.radiusKey or "layout.radius.panel"
    GUI2:ApplyBackdrop(frame, opts.surface or "color.surface.panel")
    GUI2:CreateBorder(frame, opts.border or "color.border.default")
    frame.gui2Surface = opts.surface or "color.surface.panel"
    return frame
end

function App:CreateIconSlot(parent, opts)
    return GUI2:CreateIconSlot(parent, opts)
end

function App:CreateIconGrid(parent, opts)
    return GUI2:CreateIconGrid(parent, opts)
end

function App:CreateStatusText(parent, opts)
    opts = opts or {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(opts.width or 260, opts.height or 26)
    frame.gui2Component = "StatusText"
    frame.gui2Variant = opts.variant or (opts.single and "single" or "inline")
    frame.gui2LabelColorKey = opts.labelColorKey or "color.text.secondary"
    frame.gui2ValueColorKey = opts.colorKey or "color.text.primary"
    frame.gui2ValueColorFallback = opts.colorFallback

    if frame.gui2Variant ~= "single" then
        local label = GUI2:CreateText(frame, opts.label or "Status", opts.labelFontSizeKey or "font.size.sm", frame.gui2LabelColorKey)
        label:SetPoint("LEFT", 0, 0)
        frame.label = label
    end

    local value = GUI2:CreateText(frame, opts.value or opts.text or "Ready", opts.valueFontSizeKey or opts.fontSizeKey or "font.size.md", ToneColorKey(opts.tone, frame.gui2ValueColorKey), opts.justifyH or (frame.label and "RIGHT" or "CENTER"))
    if frame.label then
        value:SetPoint("RIGHT", 0, 0)
    else
        value:SetPoint("LEFT", opts.leftPadding or 0, 0)
        value:SetPoint("RIGHT", -(opts.rightPadding or 0), 0)
    end
    frame.value = value

    frame.SetLabel = function(self, nextLabel)
        if self.label then
            self.label:SetText(nextLabel or "")
        end
    end
    frame.SetValue = function(self, nextValue, tone)
        self.value:SetText(nextValue or "")
        self:SetTone(tone or self.gui2Tone)
    end
    frame.SetTone = function(self, tone)
        self.gui2Tone = tone
        self.value:SetTextColor(GUI2:GetColor(ToneColorKey(tone, self.gui2ValueColorKey or "color.text.primary"), self.gui2ValueColorFallback))
    end
    frame.RefreshTheme = function(self)
        if self.label then
            self.label:SetTextColor(GUI2:GetColor(self.gui2LabelColorKey or "color.text.secondary"))
        end
        if self.value then
            self.value:SetTextColor(GUI2:GetColor(ToneColorKey(self.gui2Tone, self.gui2ValueColorKey or "color.text.primary"), self.gui2ValueColorFallback))
        end
    end
    frame:SetTone(opts.tone)
    return frame
end

function App:CreateCooldownIcon(parent, opts)
    opts = opts or {}
    local slot = GUI2:CreateIconSlot(parent, {
        size = opts.size or 42,
        icon = opts.icon,
        shape = opts.shape or "rounded",
        border = opts.border or "thin",
        variant = opts.variant,
        count = opts.count,
        countSink = opts.countSink,
        selected = opts.selected,
    })
    slot.gui2Component = "CooldownIcon"

    local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    cooldown:SetAllPoints(slot.icon or slot)
    cooldown:SetDrawEdge(false)
    if cooldown.SetSwipeColor then
        cooldown:SetSwipeColor(0, 0, 0, 0.55)
    end
    slot.cooldown = cooldown
    if slot.count then
        slot.count:Hide()
        local countOverlay = CreateFrame("Frame", nil, slot)
        countOverlay:SetAllPoints(slot)
        if countOverlay.SetFrameLevel and cooldown.GetFrameLevel then
            countOverlay:SetFrameLevel((cooldown:GetFrameLevel() or 0) + 1)
        end
        if countOverlay.EnableMouse then countOverlay:EnableMouse(false) end
        local countText = GUI2:CreateText(
            countOverlay,
            opts.count ~= nil and tostring(opts.count) or "",
            "font.size.sm",
            "color.text.primary",
            "RIGHT"
        )
        countText:SetPoint("BOTTOMRIGHT", -2, 1)
        slot.countOverlay = countOverlay
        slot.count = countText
    end
    slot:SetIconAppearance({
        size = opts.size or 42,
        shape = opts.shape or "rounded",
        border = opts.border or "thin",
    })
    slot:SetCooldownTextAppearance(opts.cooldownText or {
        enabled = true,
        font = "default",
        size = 14,
        outline = "outline",
        position = "center",
    })

    slot.SetCooldown = function(self, start, duration, modRate)
        if self.cooldown and type(start) == "number"
            and type(duration) == "number" and duration > 0 then
            self.cooldown:SetCooldown(start, duration, modRate or 1)
        elseif self.cooldown then
            self.cooldown:Clear()
        end
    end

    slot.SetCooldownDurationObject = function(self, durationObject)
        if not self.cooldown then return false end
        if durationObject ~= nil and self.cooldown.SetCooldownFromDurationObject then
            local ok = pcall(
                self.cooldown.SetCooldownFromDurationObject,
                self.cooldown,
                durationObject,
                true
            )
            if ok then return true end
        end
        self.cooldown:Clear()
        return durationObject == nil
    end

    if opts.start or opts.duration then
        slot:SetCooldown(opts.start or ((GetTime and GetTime()) or 0), opts.duration or 30)
    end
    return slot
end

local function ClampUnit(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function GetStatusBarImmediateInterpolation()
    return STATUS_BAR_INTERPOLATION_IMMEDIATE
end

local function GetStatusBarSmoothInterpolation()
    return STATUS_BAR_INTERPOLATION_SMOOTH
end

local function GetStatusBarProgressInterpolation(
    enabled,
    bound,
    forceImmediate
)
    if forceImmediate == true or enabled ~= true or bound ~= true then
        return STATUS_BAR_INTERPOLATION_IMMEDIATE
    end
    return STATUS_BAR_INTERPOLATION_SMOOTH
end

local function StopStatusBarInterpolation(statusBar)
    if not (statusBar and statusBar.SetToTargetValue) then return false end
    return pcall(statusBar.SetToTargetValue, statusBar) == true
end

local function GetCastTimerDirection(isChannel)
    if Enum and Enum.StatusBarTimerDirection then
        if isChannel then
            return Enum.StatusBarTimerDirection.RemainingTime or 1
        end
        return Enum.StatusBarTimerDirection.ElapsedTime or 0
    end
    return isChannel and 1 or 0
end

local function GetFrameNativeStatusBarStyle(frame)
    local style = frame and frame.gui2NativeStatusBarStyle
    if not style and frame then
        style = {
            texture = DEFAULT_CAST_BAR_TEXTURE,
            textureU0 = 0,
            textureU1 = 1,
            textureV0 = 0,
            textureV1 = 1,
        }
        frame.gui2NativeStatusBarStyle = style
    end
    return style
end

local function GetFrameNativeStatusBarDirection(frame)
    if frame.gui2ResourceFillDirection then
        return frame.gui2ResourceFillDirection
    end
    if frame.gui2DurationReverse ~= nil then
        return frame.gui2DurationReverse and "reverse" or "forward"
    end
    return (frame.fillDirection == "right" or frame.fillDirection == "down")
        and "reverse" or "forward"
end

local function GetVisibleNativeStatusBar(statusBar)
    return statusBar and statusBar.gui2ProjectedVisibleStatusBar
        or statusBar
end

local function ApplyFrameNativeStatusBarStyle(frame, force)
    local statusBar = GetVisibleNativeStatusBar(
        frame and frame.castStatusBar
    )
    local style = GetFrameNativeStatusBarStyle(frame)
    if not (statusBar and style and GUI2.ApplyNativeStatusBarStyle) then
        return 0
    end
    return GUI2:ApplyNativeStatusBarStyle(
        statusBar,
        style,
        frame.gui2ResourceOrientation or frame.orientation,
        GetFrameNativeStatusBarDirection(frame),
        force == true
    )
end

local function RestoreFrameNativeStatusBarColor(frame)
    local statusBar = GetVisibleNativeStatusBar(
        frame and frame.castStatusBar
    )
    local style = GetFrameNativeStatusBarStyle(frame)
    if not (statusBar and style and GUI2.RestoreNativeStatusBarColor) then
        return 0
    end
    return GUI2:RestoreNativeStatusBarColor(statusBar, style)
end

local function RefreshFrameProjectedDriver(frame)
    if frame and frame.RefreshProjectedDriverStyle then
        return frame:RefreshProjectedDriverStyle(true)
    end
    return false
end

local function ApplyCastStatusBarTexture(frame, texture)
    local statusBar = GetVisibleNativeStatusBar(
        frame and frame.castStatusBar
    )
    if not (statusBar and statusBar.SetStatusBarTexture) then return end
    local nextTexture = texture
    if type(nextTexture) ~= "string" or nextTexture == "" then
        nextTexture = DEFAULT_CAST_BAR_TEXTURE
    end
    local style = GetFrameNativeStatusBarStyle(frame)
    style.texture = nextTexture
    return ApplyFrameNativeStatusBarStyle(frame, false)
end

local function ApplyCastStatusBarColor(frame, r, g, b, a)
    local statusBar = GetVisibleNativeStatusBar(
        frame and frame.castStatusBar
    )
    if not (statusBar and statusBar.SetStatusBarColor) then return end
    local style = GetFrameNativeStatusBarStyle(frame)
    local color = style.fillColor
    if type(color) ~= "table" then
        color = {}
        style.fillColor = color
    end
    if type(r) == "string" then
        color[1], color[2], color[3], color[4] = GUI2:GetColor(r)
    elseif type(r) == "table" then
        color[1] = r[1] or r.r or 1
        color[2] = r[2] or r.g or 1
        color[3] = r[3] or r.b or 1
        color[4] = (r[4] or r.a) == nil and 1 or (r[4] or r.a)
    elseif type(r) == "number" then
        color[1], color[2], color[3], color[4] =
            r, g or 1, b or 1, a == nil and 1 or a
    else
        color[1], color[2], color[3], color[4] = 1, 1, 1, 1
    end
    return ApplyFrameNativeStatusBarStyle(frame, false)
end

local function ResolvePreviewColor(color)
    if type(color) == "string" then
        return GUI2:GetColor(color)
    end
    color = type(color) == "table" and color or {}
    return color[1] or color.r or 1,
        color[2] or color.g or 1,
        color[3] or color.b or 1,
        (color[4] or color.a) == nil and 1
            or (color[4] or color.a)
end

local function PreviewStatusBarColor(statusBar, color)
    if not GUI2.ApplyNativeStatusBarColor then return false end
    statusBar = GetVisibleNativeStatusBar(statusBar)
    local r, g, b, a = ResolvePreviewColor(color)
    return GUI2:ApplyNativeStatusBarColor(
        statusBar,
        r,
        g,
        b,
        a
    ) > 0
end

local function PreviewPanelColor(panel, color)
    if not panel then return false end
    local r, g, b, a = ResolvePreviewColor(color)
    if panel.SetBackdropColor then
        panel:SetBackdropColor(r, g, b, a)
        return true
    end
    local background = panel.gui2Bg or panel.background
    if background and background.SetColorTexture then
        background:SetColorTexture(r, g, b, a)
        return true
    end
    return false
end

local function CreateCastColor(r, g, b, a)
    r = r or 1
    g = g or 1
    b = b or 1
    a = a == nil and 1 or a
    if CreateColor then
        return CreateColor(r, g, b, a)
    end
    return {
        r = r,
        g = g,
        b = b,
        a = a,
        GetRGBA = function(self)
            return self.r, self.g, self.b, self.a
        end,
    }
end

local function ResolveCastColorObject(color, fallback)
    local source = color or fallback
    if type(source) == "string" then
        local r, g, b, a = GUI2:GetColor(source)
        return CreateCastColor(r, g, b, a)
    end
    if type(source) == "table" then
        if source.GetRGBA then
            return source
        end
        return CreateCastColor(source[1] or source.r, source[2] or source.g, source[3] or source.b, source[4] or source.a)
    end
    return CreateCastColor(1, 1, 1, 1)
end

local function GetVisibleStatusBarTexture(statusBar)
    statusBar = GetVisibleNativeStatusBar(statusBar)
    return statusBar and statusBar.GetStatusBarTexture
        and statusBar:GetStatusBarTexture() or nil
end

local function ApplyCastStatusBarConditionalColor(frame, value, trueColor, falseColor)
    local statusBar = GetVisibleNativeStatusBar(
        frame and frame.castStatusBar
    )
    local texture = GetVisibleStatusBarTexture(statusBar)
    if not texture then
        return false
    end
    if GUI2.InvalidateNativeStatusBarColor then
        GUI2:InvalidateNativeStatusBarColor(statusBar)
    end

    local trueObject = ResolveCastColorObject(trueColor, "color.state.danger")
    local falseObject = ResolveCastColorObject(falseColor, frame.gui2CastBarColor or "color.accent.primary")

    local Security = YUI.API and YUI.API.Security
    if Security and Security.ApplyVertexColorFromBoolean then
        local ok, applied = pcall(Security.ApplyVertexColorFromBoolean, texture, value, trueObject, falseObject)
        if ok and applied then
            return true
        end
    end

    if texture.SetVertexColorFromBoolean then
        local ok = pcall(texture.SetVertexColorFromBoolean, texture, value, trueObject, falseObject)
        if ok then
            return true
        end
    end

    if C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean then
        local ok, color = pcall(C_CurveUtil.EvaluateColorFromBoolean, value, trueObject, falseObject)
        if ok and color and color.GetRGBA then
            texture:SetVertexColor(color:GetRGBA())
            return true
        end
    end

    if not IsSecretValue(value) and type(value) == "boolean" then
        local color = value and trueObject or falseObject
        if color and color.GetRGBA then
            texture:SetVertexColor(color:GetRGBA())
            return true
        end
    end

    return false
end

local function ApplyCastColorObjectToTexture(texture, color)
    if not (texture and color and color.GetRGBA) then
        return false
    end
    texture:SetVertexColor(color:GetRGBA())
    return true
end

local function ApplyCastStatusBarCooldownColor(frame, readyValue, readyColor, cooldownColor, notInterruptibleValue, uninterruptibleColor)
    local statusBar = GetVisibleNativeStatusBar(
        frame and frame.castStatusBar
    )
    local texture = GetVisibleStatusBarTexture(statusBar)
    if not texture then
        return false
    end
    if GUI2.InvalidateNativeStatusBarColor then
        GUI2:InvalidateNativeStatusBarColor(statusBar)
    end
    if readyValue == nil and not IsSecretValue(readyValue) then
        return false
    end

    local readyObject = ResolveCastColorObject(readyColor, "color.accent.primary")
    local cooldownObject = ResolveCastColorObject(cooldownColor, "color.state.danger")
    local steelObject = ResolveCastColorObject(uninterruptibleColor, cooldownObject)
    local Security = YUI.API and YUI.API.Security
    local color = cooldownObject
    local valueCount = 0
    if type(readyValue) == "table" and not readyValue.GetRGBA then
        for _, value in ipairs(readyValue) do
            if value ~= nil or IsSecretValue(value) then
                valueCount = valueCount + 1
                local evaluatedColor
                if Security and Security.EvaluateColorFromBoolean then
                    local ok, evaluated = pcall(Security.EvaluateColorFromBoolean, value, readyObject, color)
                    if ok then
                        evaluatedColor = evaluated
                    end
                end
                if not evaluatedColor and not IsSecretValue(value) and type(value) == "boolean" then
                    evaluatedColor = value and readyObject or color
                end
                if evaluatedColor then
                    color = evaluatedColor
                end
            end
        end
    else
        valueCount = 1
        if Security and Security.EvaluateColorFromBoolean then
            local ok, evaluated = pcall(Security.EvaluateColorFromBoolean, readyValue, readyObject, cooldownObject)
            if ok then
                color = evaluated
            end
        end
        if color == cooldownObject and not IsSecretValue(readyValue) and type(readyValue) == "boolean" then
            color = readyValue and readyObject or cooldownObject
        end
    end
    if valueCount <= 0 then
        return false
    end

    if notInterruptibleValue ~= nil or IsSecretValue(notInterruptibleValue) then
        local steelColor
        if Security and Security.EvaluateColorFromBoolean then
            local ok, evaluated = pcall(Security.EvaluateColorFromBoolean, notInterruptibleValue, steelObject, color)
            if ok then
                steelColor = evaluated
            end
        end
        if not steelColor and not IsSecretValue(notInterruptibleValue) and type(notInterruptibleValue) == "boolean" then
            steelColor = notInterruptibleValue and steelObject or color
        end
        if steelColor then
            color = steelColor
        end
    end

    return ApplyCastColorObjectToTexture(texture, color)
end

local function ReadDurationObjectValue(durationObject, methodName)
    if durationObject == nil or type(methodName) ~= "string" then
        return nil, false
    end
    local ok, value = pcall(function()
        local method = durationObject[methodName]
        if type(method) ~= "function" then
            return nil
        end
        return method(durationObject)
    end)
    if ok then
        return value, true
    end
    return nil, false
end

local function SetStatusBarDurationValue(statusBar, totalDurationObject, valueDurationObject, valueMethodName)
    if not (statusBar and totalDurationObject and valueDurationObject) then
        return false
    end
    local totalValue, totalOK = ReadDurationObjectValue(totalDurationObject, "GetTotalDuration")
    local markerValue, valueOK = ReadDurationObjectValue(valueDurationObject, valueMethodName)
    if not (totalOK and valueOK) then
        return false
    end
    local okMin = statusBar.SetMinMaxValues and pcall(statusBar.SetMinMaxValues, statusBar, 0, totalValue)
    local okValue = statusBar.SetValue and pcall(statusBar.SetValue, statusBar, markerValue)
    return okMin == true and okValue == true
end

local function SetStatusBarFillStyle(statusBar, reverse)
    if statusBar and statusBar.SetReverseFill then
        pcall(statusBar.SetReverseFill, statusBar, reverse == true)
    end
    if statusBar and statusBar.SetFillStyle and Enum and Enum.StatusBarFillStyle then
        local style = (reverse and Enum.StatusBarFillStyle.Reverse) or Enum.StatusBarFillStyle.Standard or 0
        pcall(statusBar.SetFillStyle, statusBar, style)
    end
end

local function ApplyAlphaFromBoolean(target, value, trueAlpha, falseAlpha)
    local Security = YUI.API and YUI.API.Security
    if Security and Security.ApplyAlphaFromBoolean then
        local ok, applied = pcall(Security.ApplyAlphaFromBoolean, target, value, trueAlpha, falseAlpha)
        return ok and applied == true
    end
    return false
end

local function NormalizeCastBarTextOutlineMode(mode)
    if mode == "none" then return "none" end
    if mode == "outline" then return "outline" end
    if mode == "thick" then return "thick" end
    if mode == "shadow" then return "shadow" end
    if mode == "outline_shadow" or mode == "outlineShadow" then
        return "outlineShadow"
    end
    return "shadow"
end

local function ApplyCastBarTextShadow(fontString, mode)
    if not (fontString and fontString.SetShadowColor) then return end
    mode = NormalizeCastBarTextOutlineMode(mode)
    if mode == "shadow" or mode == "outlineShadow" then
        fontString:SetShadowColor(0, 0, 0, 0.9)
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
end

local function ApplyCastBarFontSize(fontString, size, outlineMode)
    if not (fontString and fontString.SetFont) then return end
    size = tonumber(size) or GUI2:GetMetric("font.size.sm", 11)
    if size < 6 then size = 6 end
    outlineMode = NormalizeCastBarTextOutlineMode(outlineMode)
    local flags = ""
    if outlineMode == "outline" or outlineMode == "outlineShadow" then
        flags = "OUTLINE"
    elseif outlineMode == "thick" then
        flags = "THICKOUTLINE"
    end
    fontString:SetFont(GUI2:GetFont("font.family.body"), size, flags)
    ApplyCastBarTextShadow(fontString, outlineMode)
end

local function ConfigureCastBarLabel(fontString)
    if not fontString then return end
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(false)
    end
    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end
end

local function GetCastBarTimeRegionWidth(frame)
    return frame and frame.gui2TimeRegionWidth or math_max(44, (frame and frame.barWidth or 1) * 0.18)
end

local function ConfigureCastBarCountdownText(frame)
    local countdown = frame and frame.countdown
    if not countdown then return end
    if not countdown.GetRegions then return end
    local width = GetCastBarTimeRegionWidth(frame)
    local regionCount = select("#", countdown:GetRegions())
    for index = 1, regionCount do
        local region = select(index, countdown:GetRegions())
        if region and region.GetObjectType and region:GetObjectType() == "FontString" then
            region:ClearAllPoints()
            region:SetPoint("RIGHT", countdown, "RIGHT", 0, 0)
            region:SetWidth(width)
            region:SetJustifyH("RIGHT")
            region:SetJustifyV("MIDDLE")
            ConfigureCastBarLabel(region)
            ApplyCastBarFontSize(region, frame.gui2TimeFontSize, frame.gui2TextOutlineMode)
        end
    end
end

local function LayoutCastBarTextRegions(frame)
    if not frame then return end
    local width = frame.barWidth or 1
    local leftPadding = frame.gui2NameLeftPadding or 5
    local rightPadding = frame.gui2TimeRightPadding or 5
    local gap = frame.gui2TextRegionGap or 6
    local targetWidth = math_max(24, math_min(width * 0.34, width - 92))
    local targetLeft = (width - targetWidth) * 0.5
    local targetRight = targetLeft + targetWidth
    local spellWidth = math_max(24, targetLeft - leftPadding - gap)
    local timeMaxWidth = math_max(32, width - targetRight - rightPadding - gap)
    local timeWidth = math_max(32, math_min(math_max(44, width * 0.18), timeMaxWidth))
    frame.gui2TimeRegionWidth = timeWidth
    if frame.timeText then
        frame.timeText:ClearAllPoints()
        frame.timeText:SetPoint("RIGHT", frame.track, "RIGHT", -rightPadding, 0)
        frame.timeText:SetWidth(timeWidth)
    end
    if frame.spellNameText then
        frame.spellNameText:ClearAllPoints()
        frame.spellNameText:SetPoint("LEFT", frame.track, "LEFT", leftPadding, 0)
        frame.spellNameText:SetWidth(spellWidth)
    end
    if frame.targetNameText then
        frame.targetNameText:ClearAllPoints()
        frame.targetNameText:SetPoint("CENTER", frame.track, "CENTER", 0, 0)
        frame.targetNameText:SetWidth(targetWidth)
    end
    if frame.countdownHolder then
        frame.countdownHolder:ClearAllPoints()
        frame.countdownHolder:SetPoint("RIGHT", frame.track, "RIGHT", -rightPadding, 0)
        frame.countdownHolder:SetSize(timeWidth, frame.barHeight or 1)
    end
    if frame.countdown and frame.countdownHolder then
        frame.countdown:ClearAllPoints()
        frame.countdown:SetAllPoints(frame.countdownHolder)
        ConfigureCastBarCountdownText(frame)
    end
end

function App:CreateCastBar(parent, opts)
    opts = opts or {}
    if not (GUI2.Data and GUI2.Data.CreateProgressBar) then
        return nil
    end

    local height = opts.height or 20
    local barWidth = opts.barWidth or opts.width or 240
    local iconSize = opts.iconSize or height
    local frame = GUI2.Data:CreateProgressBar(parent, {
        width = barWidth + iconSize,
        height = height,
        value = opts.value or 0,
        iconPosition = "left",
        iconGap = 0,
        iconSize = iconSize,
        roundedIcon = opts.roundedIcon,
        icon = opts.icon or opts.fallbackIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
        iconPadding = opts.iconPadding or 0,
        fillTexture = opts.fillTexture or opts.statusBarTexture,
        fillColor = opts.fillColor or opts.barColor or "color.accent.primary",
        fillDirection = opts.fillDirection or "left",
        projectedFill = true,
        collapseAdjacentBorder = true,
        animate = false,
        motion = false,
    })
    if not frame then return nil end

    frame.gui2Component = "CastBar"
    frame.progressBar = frame
    frame.statusBar = frame
    frame.background = frame.track
    frame.iconSlot = frame.icon
    frame.iconTexture = frame.icon and frame.icon.icon
    frame.gui2NameLeftPadding = opts.nameLeftPadding or 5
    frame.gui2TimeRightPadding = opts.timeRightPadding or 5
    frame.gui2TextRegionGap = opts.textRegionGap or 6

    local castStatusBar = frame.nativeStatusBar
        or CreateFrame("StatusBar", nil, frame.track)
    if not frame.nativeStatusBar then
        castStatusBar:SetAllPoints(frame.track)
    end
    castStatusBar:SetMinMaxValues(0, 1)
    castStatusBar:SetValue(opts.value or 0)
    castStatusBar:Show()
    frame.castStatusBar = castStatusBar
    frame.statusBar = GetVisibleNativeStatusBar(castStatusBar)
    frame.gui2NativeStatusBarStyle = frame.gui2NativeFillStyle
    ApplyCastStatusBarTexture(frame, opts.fillTexture or opts.statusBarTexture)
    ApplyCastStatusBarColor(frame, opts.fillColor or opts.barColor or "color.accent.primary")

    local overlayParent = CreateFrame("Frame", nil, frame.track)
    overlayParent:SetAllPoints(frame.track)
    if overlayParent.SetFrameLevel and frame.track.GetFrameLevel then
        overlayParent:SetFrameLevel((frame.track:GetFrameLevel() or 0) + 4)
    end
    frame.textOverlay = overlayParent

    local timeText = GUI2:CreateText(overlayParent, opts.remainingText or "", opts.timeFontSizeKey or "font.size.sm", opts.timeColorKey or "color.text.primary", "RIGHT")
    timeText:SetPoint("RIGHT", frame.track, "RIGHT", -frame.gui2TimeRightPadding, 0)
    timeText:SetJustifyH("RIGHT")
    timeText:SetJustifyV("MIDDLE")
    ConfigureCastBarLabel(timeText)
    if timeText.SetShadowColor then
        timeText:SetShadowColor(0, 0, 0, 0.9)
        timeText:SetShadowOffset(1, -1)
    end
    frame.timeText = timeText
    ApplyCastBarFontSize(timeText, opts.timeFontSize)

    local countdownHolder = CreateFrame("Frame", nil, overlayParent)
    countdownHolder:SetPoint("RIGHT", frame.track, "RIGHT", -frame.gui2TimeRightPadding, 0)
    countdownHolder:SetSize(math_max(44, barWidth * 0.18), height)
    if countdownHolder.SetFrameLevel and overlayParent.GetFrameLevel then
        countdownHolder:SetFrameLevel((overlayParent:GetFrameLevel() or 0) + 2)
    end
    frame.countdownHolder = countdownHolder

    local countdown = CreateFrame("Cooldown", nil, countdownHolder, "CooldownFrameTemplate")
    countdown:SetAllPoints(countdownHolder)
    if countdown.SetDrawSwipe then
        countdown:SetDrawSwipe(false)
    end
    if countdown.SetDrawEdge then
        countdown:SetDrawEdge(false)
    end
    if countdown.SetDrawBling then
        countdown:SetDrawBling(false)
    end
    if countdown.SetHideCountdownNumbers then
        countdown:SetHideCountdownNumbers(false)
    end
    if countdown.SetMinimumCountdownDuration then
        countdown:SetMinimumCountdownDuration(0)
    end
    if countdown.SetCountdownMillisecondsThreshold then
        countdown:SetCountdownMillisecondsThreshold(10)
    end
    countdown:Hide()
    frame.countdown = countdown

    local spellNameText = GUI2:CreateText(overlayParent, "", opts.nameFontSizeKey or "font.size.sm", opts.nameColorKey or "color.text.primary", "LEFT")
    spellNameText:SetPoint("LEFT", frame.track, "LEFT", frame.gui2NameLeftPadding, 0)
    spellNameText:SetJustifyH("LEFT")
    spellNameText:SetJustifyV("MIDDLE")
    ConfigureCastBarLabel(spellNameText)
    if spellNameText.SetShadowColor then
        spellNameText:SetShadowColor(0, 0, 0, 0.9)
        spellNameText:SetShadowOffset(1, -1)
    end
    spellNameText:Hide()
    frame.spellNameText = spellNameText
    ApplyCastBarFontSize(spellNameText, opts.nameFontSize)

    local targetNameText = GUI2:CreateText(overlayParent, "", opts.targetFontSizeKey or "font.size.sm", opts.targetColorKey or "color.text.primary", "CENTER")
    targetNameText:SetPoint("CENTER", frame.track, "CENTER", 0, 0)
    targetNameText:SetJustifyH("CENTER")
    targetNameText:SetJustifyV("MIDDLE")
    ConfigureCastBarLabel(targetNameText)
    if targetNameText.SetShadowColor then
        targetNameText:SetShadowColor(0, 0, 0, 0.9)
        targetNameText:SetShadowOffset(1, -1)
    end
    targetNameText:Hide()
    frame.targetNameText = targetNameText
    ApplyCastBarFontSize(targetNameText, opts.targetFontSize)

    local markerClip = CreateFrame("Frame", nil, overlayParent)
    markerClip:SetPoint("CENTER", frame.track, "CENTER", 0, 0)
    markerClip:SetSize(barWidth, height + (opts.markerOvershoot or 4))
    if markerClip.SetClipsChildren then
        markerClip:SetClipsChildren(true)
    end
    frame.markerClip = markerClip

    local marker = markerClip:CreateTexture(nil, "OVERLAY")
    marker:SetTexture(opts.markerTexture or "Interface\\Buttons\\WHITE8x8")
    marker:SetWidth(opts.markerWidth or 2)
    marker:SetHeight(height + (opts.markerOvershoot or 4))
    marker:Hide()
    frame.marker = marker
    frame.markerWidth = opts.markerWidth or 2
    frame.markerOvershoot = opts.markerOvershoot or 4

    local function CreateNativeMarkerStatusBar()
        local statusBar = CreateFrame("StatusBar", nil, markerClip)
        statusBar:SetAllPoints(frame.track)
        statusBar:SetMinMaxValues(0, 1)
        statusBar:SetValue(0)
        statusBar:SetAlpha(0)
        statusBar:EnableMouse(false)
        if statusBar.SetStatusBarTexture then
            statusBar:SetStatusBarTexture(DEFAULT_CAST_BAR_TEXTURE)
        end
        if statusBar.SetStatusBarColor then
            statusBar:SetStatusBarColor(1, 1, 1, 0)
        end
        statusBar:Hide()
        return statusBar
    end

    frame.nativeMarkerPositioner = CreateNativeMarkerStatusBar()
    frame.nativeMarkerOffsetBar = CreateNativeMarkerStatusBar()

    local baseRefreshTheme = frame.RefreshTheme
    frame.SetCastBarSize = function(self, nextBarWidth, nextHeight)
        local width = math_max(1, tonumber(nextBarWidth) or self.barWidth or barWidth)
        local nextBarHeight = math_max(1, tonumber(nextHeight) or self.barHeight or height)
        if self.SetBarSize then
            self:SetBarSize(
                width + nextBarHeight,
                nextBarHeight,
                nextBarHeight
            )
        end
        if self.marker then
            self.marker:SetHeight(nextBarHeight + (self.markerOvershoot or 4))
        end
        if self.markerClip then
            self.markerClip:SetSize(width, nextBarHeight + (self.markerOvershoot or 4))
        end
        LayoutCastBarTextRegions(self)
    end
    frame.SetBarTexture = function(self, texture)
        self.gui2CastBarTexture = texture
        if self.SetFillTexture then
            self:SetFillTexture(texture)
        end
        ApplyCastStatusBarTexture(self, texture)
    end
    frame.SetBarColor = function(self, r, g, b, a)
        self.gui2CastBarColor = (type(r) == "table" or type(r) == "string") and r or { r or 1, g or 1, b or 1, a == nil and 1 or a }
        self.gui2CastBarConditionalActive = false
        self.gui2CastBarConditionalMode = nil
        if self.SetFillColor then
            self:SetFillColor(r, g, b, a)
        end
        ApplyCastStatusBarColor(self, r, g, b, a)
    end
    frame.SetBarColorFromBoolean = function(self, value, trueColor, falseColor)
        if not IsSecretValue(value) and value == nil then
            self.gui2CastBarConditionalActive = false
            return false
        end
        self.gui2CastBarConditionalActive = true
        self.gui2CastBarConditionalValue = value
        self.gui2CastBarConditionalTrueColor = trueColor
        self.gui2CastBarConditionalFalseColor = falseColor
        self.gui2CastBarConditionalMode = "boolean"
        return ApplyCastStatusBarConditionalColor(self, value, trueColor, falseColor)
    end
    frame.SetBarColorFromCooldownState = function(self, readyValue, readyColor, cooldownColor, notInterruptibleValue, uninterruptibleColor)
        if readyValue == nil and not IsSecretValue(readyValue) then
            self.gui2CastBarConditionalActive = false
            self.gui2CastBarConditionalMode = nil
            return false
        end
        self.gui2CastBarConditionalActive = true
        self.gui2CastBarConditionalMode = "cooldown"
        self.gui2CastBarConditionalReadyValue = readyValue
        self.gui2CastBarConditionalReadyColor = readyColor
        self.gui2CastBarConditionalCooldownColor = cooldownColor
        self.gui2CastBarConditionalNotInterruptibleValue = notInterruptibleValue
        self.gui2CastBarConditionalUninterruptibleColor = uninterruptibleColor
        local applied = ApplyCastStatusBarCooldownColor(self, readyValue, readyColor, cooldownColor, notInterruptibleValue, uninterruptibleColor)
        if not applied then
            self.gui2CastBarConditionalActive = false
            self.gui2CastBarConditionalMode = nil
        end
        return applied
    end
    frame.ClearBarColorCondition = function(self)
        self.gui2CastBarConditionalActive = false
        self.gui2CastBarConditionalMode = nil
        self.gui2CastBarConditionalValue = nil
        self.gui2CastBarConditionalTrueColor = nil
        self.gui2CastBarConditionalFalseColor = nil
        self.gui2CastBarConditionalReadyValue = nil
        self.gui2CastBarConditionalReadyColor = nil
        self.gui2CastBarConditionalCooldownColor = nil
        self.gui2CastBarConditionalNotInterruptibleValue = nil
        self.gui2CastBarConditionalUninterruptibleColor = nil
        ApplyCastStatusBarColor(self, self.gui2CastBarColor or "color.accent.primary")
    end
    frame.SetSpellIcon = function(self, texture)
        if self.SetIcon then
            self:SetIcon(texture)
        end
    end
    frame.SetRemainingText = function(self, text)
        if self.gui2UsingNativeCountdown then
            return
        end
        if self.timeText then
            if text == nil then text = "" end
            self.timeText:SetText(text)
            self.timeText:Show()
        end
    end
    frame.SetTimeTextSize = function(self, size)
        self.gui2TimeFontSize = tonumber(size)
        ApplyCastBarFontSize(self.timeText, self.gui2TimeFontSize, self.gui2TextOutlineMode)
        ConfigureCastBarCountdownText(self)
    end
    frame.SetSpellNameTextSize = function(self, size)
        self.gui2SpellNameFontSize = tonumber(size)
        ApplyCastBarFontSize(self.spellNameText, self.gui2SpellNameFontSize, self.gui2TextOutlineMode)
    end
    frame.SetTargetNameTextSize = function(self, size)
        self.gui2TargetNameFontSize = tonumber(size)
        ApplyCastBarFontSize(self.targetNameText, self.gui2TargetNameFontSize, self.gui2TextOutlineMode)
    end
    frame.SetTextOutlineMode = function(self, mode)
        self.gui2TextOutlineMode = NormalizeCastBarTextOutlineMode(mode)
        ApplyCastBarFontSize(self.timeText, self.gui2TimeFontSize, self.gui2TextOutlineMode)
        ApplyCastBarFontSize(self.spellNameText, self.gui2SpellNameFontSize, self.gui2TextOutlineMode)
        ApplyCastBarFontSize(self.targetNameText, self.gui2TargetNameFontSize, self.gui2TextOutlineMode)
        ConfigureCastBarCountdownText(self)
    end
    frame.SetSpellNameText = function(self, text)
        if self.spellNameText then
            if text == nil then text = "" end
            self.spellNameText:SetText(text)
        end
    end
    frame.SetTargetNameText = function(self, text)
        if self.targetNameText then
            if text == nil then text = "" end
            self.targetNameText:SetText(text)
        end
    end
    frame.SetTargetNameColor = function(self, r, g, b, a)
        self.gui2TargetNameColor = (type(r) == "table" or type(r) == "string") and r or { r or 1, g or 1, b or 1, a == nil and 1 or a }
        if not self.targetNameText then return end
        self.targetNameText.gui2ColorKey = nil
        if type(self.gui2TargetNameColor) == "string" then
            self.targetNameText:SetTextColor(GUI2:GetColor(self.gui2TargetNameColor))
        else
            local color = self.gui2TargetNameColor
            self.targetNameText:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4])
        end
    end
    frame.SetCastLabelsVisible = function(self, visible)
        if self.spellNameText then
            if visible then self.spellNameText:Show() else self.spellNameText:Hide() end
        end
        if self.targetNameText then
            if visible then self.targetNameText:Show() else self.targetNameText:Hide() end
        end
    end
    frame.SetMarkerColor = function(self, r, g, b, a)
        self.gui2MarkerColor = (type(r) == "table" or type(r) == "string") and r or { r or 1, g or 1, b or 1, a == nil and 1 or a }
        if not self.marker then return end
        if type(self.gui2MarkerColor) == "string" then
            self.marker:SetVertexColor(GUI2:GetColor(self.gui2MarkerColor))
        else
            local color = self.gui2MarkerColor
            self.marker:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4])
        end
    end
    frame.ClearNativeMarker = function(self)
        self.gui2NativeMarkerActive = false
        self.gui2NativeMarkerStatic = false
        if self.nativeMarkerPositioner then
            self.nativeMarkerPositioner:Hide()
        end
        if self.nativeMarkerOffsetBar then
            self.nativeMarkerOffsetBar:Hide()
        end
        if self.marker then
            self.marker:SetAlpha(1)
            self.marker:Hide()
        end
    end
    frame.RefreshNativeMarkerVisibility = function(self, notInterruptibleRaw, cooldownReadyRaw)
        if not (self.gui2NativeMarkerActive and self.marker) then
            return false
        end
        self.marker:SetAlpha(1)
        if cooldownReadyRaw ~= nil and ApplyAlphaFromBoolean(self.marker, cooldownReadyRaw, 0, 1) then
            self.marker:Show()
            return true
        end
        if not ApplyAlphaFromBoolean(self.marker, notInterruptibleRaw, 0, 1) then
            self.marker:SetAlpha(1)
        end
        self.marker:Show()
        return true
    end
    frame.SetNativeMarkerFromDurations = function(self, castDurationObject, interruptDurationObject, isChannel, notInterruptibleRaw, cooldownReadyRaw)
        local positioner = self.nativeMarkerPositioner
        local offsetBar = self.nativeMarkerOffsetBar
        local markerTexture = self.marker
        if not (self.track and positioner and offsetBar and markerTexture and castDurationObject and interruptDurationObject) then
            if self.ClearNativeMarker then self:ClearNativeMarker() end
            return false
        end

        local width = self.track:GetWidth() or self.barWidth or 1
        local heightValue = self.barHeight or 1
        positioner:SetAllPoints(self.track)
        offsetBar:ClearAllPoints()
        offsetBar:SetSize(width, heightValue)
        SetStatusBarFillStyle(positioner, isChannel == true)
        SetStatusBarFillStyle(offsetBar, isChannel == true)

        local positionOK = SetStatusBarDurationValue(positioner, castDurationObject, castDurationObject, "GetElapsedDuration")
        local offsetOK = SetStatusBarDurationValue(offsetBar, castDurationObject, interruptDurationObject, "GetRemainingDuration")
        if not (positionOK and offsetOK) then
            if self.ClearNativeMarker then self:ClearNativeMarker() end
            return false
        end

        local positionTexture = positioner.GetStatusBarTexture and positioner:GetStatusBarTexture()
        local offsetTexture = offsetBar.GetStatusBarTexture and offsetBar:GetStatusBarTexture()
        if not (positionTexture and offsetTexture) then
            if self.ClearNativeMarker then self:ClearNativeMarker() end
            return false
        end

        positioner:Show()
        offsetBar:Show()
        markerTexture:ClearAllPoints()
        if isChannel == true then
            offsetBar:SetPoint("RIGHT", positionTexture, "LEFT", 0, 0)
            markerTexture:SetPoint("CENTER", offsetTexture, "LEFT", 0, 0)
        else
            offsetBar:SetPoint("LEFT", positionTexture, "RIGHT", 0, 0)
            markerTexture:SetPoint("CENTER", offsetTexture, "RIGHT", 0, 0)
        end
        markerTexture:SetAlpha(1)
        if cooldownReadyRaw ~= nil and ApplyAlphaFromBoolean(markerTexture, cooldownReadyRaw, 0, 1) then
            markerTexture:Show()
            self.gui2NativeMarkerActive = true
            self.gui2NativeMarkerStatic = true
            return true
        end
        if not ApplyAlphaFromBoolean(markerTexture, notInterruptibleRaw, 0, 1) then
            markerTexture:SetAlpha(1)
        end
        markerTexture:Show()
        self.gui2NativeMarkerActive = true
        self.gui2NativeMarkerStatic = true
        return true
    end
    frame.SetMarkerPercent = function(self, percent)
        if not (self.marker and self.track) then return end
        if self.ClearNativeMarker then
            self:ClearNativeMarker()
        end
        percent = tonumber(percent)
        if not percent or percent <= 0 or percent >= 1 then
            self.marker:Hide()
            return
        end
        local width = self.track:GetWidth() or self.barWidth or 0
        self.marker:ClearAllPoints()
        self.marker:SetPoint("CENTER", self.track, "LEFT", width * ClampUnit(percent), 0)
        self.marker:Show()
    end
    frame.HideMarker = function(self)
        if self.ClearNativeMarker then
            self:ClearNativeMarker()
        elseif self.marker then
            self.marker:Hide()
        end
    end
    frame.ClearCastDuration = function(self)
        self.gui2CastDurationObject = nil
        self.gui2UsingNativeCastDuration = false
        self.gui2UsingNativeCountdown = false
        if self.ClearNativeMarker then
            self:ClearNativeMarker()
        end
        if self.castStatusBar then
            if self.castStatusBar.SetMinMaxValues then
                self.castStatusBar:SetMinMaxValues(0, 1)
            end
            if self.castStatusBar.SetValue then
                self.castStatusBar:SetValue(0)
            end
        end
        if self.SetNativeFillShown then
            self:SetNativeFillShown(false)
        end
        if self.countdown then
            if self.countdown.Clear then
                self.countdown:Clear()
            else
                self.countdown:SetCooldown(0, 0)
            end
            self.countdown:Hide()
        end
        if self.countdownHolder then
            self.countdownHolder:Hide()
        end
        if self.timeText then
            self.timeText:Show()
        end
    end
    frame.SetCastDuration = function(self, durationObject, isChannel)
        self.gui2CastDurationObject = durationObject
        self.gui2CastDurationIsChannel = isChannel == true
        if self.ClearNativeMarker then
            self:ClearNativeMarker()
        end
        local statusBar = self.castStatusBar
        if not (durationObject and statusBar and statusBar.SetTimerDuration) then
            self.gui2UsingNativeCastDuration = false
            return false
        end
        RefreshFrameProjectedDriver(self)
        ApplyFrameNativeStatusBarStyle(self, false)
        local ok = pcall(statusBar.SetTimerDuration, statusBar, durationObject, GetStatusBarImmediateInterpolation(), GetCastTimerDirection(isChannel == true))
        if ok then
            RestoreFrameNativeStatusBarColor(self)
            if self.SetNativeFillShown then
                self:SetNativeFillShown(true)
            end
        end
        self.gui2UsingNativeCastDuration = ok == true
        local countdownOK = false
        if self.countdown and self.countdown.SetCooldownFromDurationObject then
            countdownOK = pcall(self.countdown.SetCooldownFromDurationObject, self.countdown, durationObject, true) == true
        end
        self.gui2UsingNativeCountdown = countdownOK == true
        if self.countdown then
            if countdownOK then
                if self.countdownHolder then self.countdownHolder:Show() end
                self.countdown:Show()
                ConfigureCastBarCountdownText(self)
            else
                self.countdown:Hide()
                if self.countdownHolder then self.countdownHolder:Hide() end
            end
        end
        if self.timeText then
            if countdownOK then
                self.timeText:SetText("")
                self.timeText:Hide()
            else
                self.timeText:Show()
            end
        end
        return self.gui2UsingNativeCastDuration
    end
    frame.SetCastProgress = function(self, elapsedSeconds, totalSeconds, isChannel)
        local total = tonumber(totalSeconds) or 0
        local statusBar = self.castStatusBar
        if self.ClearNativeMarker then
            self:ClearNativeMarker()
        end
        self.gui2UsingNativeCastDuration = false
        self.gui2UsingNativeCountdown = false
        if self.countdown then
            if self.countdown.Clear then
                self.countdown:Clear()
            else
                self.countdown:SetCooldown(0, 0)
            end
            self.countdown:Hide()
        end
        if self.countdownHolder then
            self.countdownHolder:Hide()
        end
        if self.timeText then
            self.timeText:Show()
        end
        if total <= 0 then
            local value = isChannel and 1 or 0
            if statusBar then
                statusBar:SetMinMaxValues(0, 1)
                statusBar:SetValue(value)
            end
            self:SetValue(value, { silent = true, motion = false })
            return
        end
        local elapsed = tonumber(elapsedSeconds) or 0
        if self.fillDirection ~= "left" and self.SetFillDirection then
            self:SetFillDirection("left")
        end
        local progress = ClampUnit(elapsed / total)
        local value = isChannel and (1 - progress) or progress
        if statusBar then
            statusBar:SetMinMaxValues(0, 1)
            statusBar:SetValue(value)
        end
        self:SetValue(value, { silent = true, motion = false })
    end
    frame.RefreshTheme = function(self)
        if baseRefreshTheme then
            baseRefreshTheme(self)
        end
        ApplyCastStatusBarTexture(self, self.gui2CastBarTexture)
        if self.gui2CastBarConditionalActive then
            if self.gui2CastBarConditionalMode == "cooldown" then
                ApplyCastStatusBarCooldownColor(self,
                    self.gui2CastBarConditionalReadyValue,
                    self.gui2CastBarConditionalReadyColor,
                    self.gui2CastBarConditionalCooldownColor,
                    self.gui2CastBarConditionalNotInterruptibleValue,
                    self.gui2CastBarConditionalUninterruptibleColor)
            else
                ApplyCastStatusBarConditionalColor(self, self.gui2CastBarConditionalValue, self.gui2CastBarConditionalTrueColor, self.gui2CastBarConditionalFalseColor)
            end
        else
            ApplyCastStatusBarColor(self, self.gui2CastBarColor or "color.accent.primary")
        end
        self:SetTimeTextSize(self.gui2TimeFontSize)
        self:SetSpellNameTextSize(self.gui2SpellNameFontSize)
        self:SetTargetNameTextSize(self.gui2TargetNameFontSize)
        self:SetTextOutlineMode(self.gui2TextOutlineMode)
        if self.gui2MarkerColor then
            self:SetMarkerColor(self.gui2MarkerColor)
        end
        if self.gui2TargetNameColor then
            self:SetTargetNameColor(self.gui2TargetNameColor)
        end
    end

    frame:SetTextOutlineMode(opts.textOutlineMode or opts.outlineMode or "shadow")
    frame:SetTimeTextSize(opts.timeFontSize)
    frame:SetSpellNameTextSize(opts.nameFontSize)
    frame:SetTargetNameTextSize(opts.targetFontSize)
    frame:SetMarkerColor(opts.markerColor or { 0.1, 1, 0.2, 1 })
    frame:SetCastBarSize(barWidth, height)
    return frame
end

do
    local function ClearCooldown(cooldown)
        if not cooldown then return end
        if cooldown.Clear then
            cooldown:Clear()
        elseif cooldown.SetCooldown then
            cooldown:SetCooldown(0, 0)
        end
    end

    local function CreateDurationObject()
        local api = _G.C_DurationUtil
        if not (api and type(api.CreateDuration) == "function") then
            return nil
        end
        local ok, durationObject = pcall(api.CreateDuration)
        if ok then return durationObject end
        return nil
    end

    local function SetDurationObjectTimes(
        durationObject,
        startTime,
        duration,
        modRate
    )
        if not durationObject then return false end
        startTime = tonumber(startTime) or 0
        duration = tonumber(duration) or 0
        modRate = tonumber(modRate) or 1
        if duration <= 0 then
            if durationObject.Reset then
                pcall(durationObject.Reset, durationObject)
            end
            return false
        end
        if type(durationObject.SetTimeFromStart) ~= "function" then
            return false
        end
        return pcall(
            durationObject.SetTimeFromStart,
            durationObject,
            startTime,
            duration,
            modRate
        ) == true
    end

    local function GetCooldownFontString(cooldown)
        if not (cooldown and cooldown.GetCountdownFontString) then return nil end
        local ok, fontString = pcall(
            cooldown.GetCountdownFontString,
            cooldown
        )
        return ok and fontString or nil
    end

    local function PositionDurationText(frame, fontString, appearance, kind)
        if not (frame and fontString and GUI2.PositionStatusBarText) then
            return false
        end
        local positioned, anchor = GUI2:PositionStatusBarText(
            fontString,
            appearance,
            frame.orientation,
            frame.track,
            frame.icon,
            frame.gui2DurationShowIcon,
            kind
        )
        if positioned and anchor then
            frame["gui2DurationResolved" .. kind .. "Anchor"] = anchor
        end
        return positioned
    end

    local function ApplyDurationTextAppearance(frame, opts)
        if not (frame and frame.countdown) then return end
        opts = type(opts) == "table" and opts or {}
        frame.gui2DurationTextAppearance = opts
        GUI2:ApplyCooldownTextAppearance({
            cooldown = frame.countdown,
        }, opts)
        PositionDurationText(
            frame,
            GetCooldownFontString(frame.countdown),
            opts,
            "time"
        )
    end

    local function PositionDurationNameText(frame)
        local text = frame and frame.durationNameText
        if not text then return end
        local owner = frame.durationNameOverlay
            or frame.durationOverlay
            or frame
        local position = frame.gui2DurationNamePosition or "center"
        local anchor = "CENTER"
        local x = 0
        local y = 0
        local justify = "CENTER"
        if position == "top" then
            anchor = "TOP"
            y = -2
        elseif position == "bottom" then
            anchor = "BOTTOM"
            y = 2
        elseif position == "left" then
            anchor = "LEFT"
            x = 4
            justify = "LEFT"
        elseif position == "right" then
            anchor = "RIGHT"
            x = -4
            justify = "RIGHT"
        elseif position == "top-left" then
            anchor = "TOPLEFT"
            x = 2
            y = -2
            justify = "LEFT"
        elseif position == "bottom-left" then
            anchor = "BOTTOMLEFT"
            x = 2
            y = 2
            justify = "LEFT"
        elseif position == "top-right" then
            anchor = "TOPRIGHT"
            x = -2
            y = -2
            justify = "RIGHT"
        elseif position == "bottom-right" then
            anchor = "BOTTOMRIGHT"
            x = -2
            y = 2
            justify = "RIGHT"
        end
        local appearance = frame.gui2DurationNameAppearance or {}
        if appearance.anchor then
            PositionDurationText(frame, text, appearance, "name")
            return
        end
        x = x + (tonumber(appearance.offsetX) or 0)
        y = y + (tonumber(appearance.offsetY) or 0)
        text:ClearAllPoints()
        text:SetPoint(anchor, owner, anchor, x, y)
        if text.SetJustifyH then text:SetJustifyH(justify) end
        if text.SetWidth and owner.GetWidth then
            text:SetWidth(math_max(1, (owner:GetWidth() or 1) - 8))
        end
    end

    local function SetNativeDuration(
        frame,
        durationObject,
        reverse,
        forceImmediate
    )
        local statusBar = frame and frame.durationStatusBar
        if not (durationObject and statusBar and statusBar.SetTimerDuration) then
            return false
        end
        reverse = reverse == true
        frame.gui2DurationReverse = reverse
        if frame.gui2ProjectedFill and frame.SetFillDirection then
            frame:SetFillDirection(
                frame.orientation == "vertical"
                    and (reverse and "down" or "up")
                    or (reverse and "right" or "left")
            )
        end
        RefreshFrameProjectedDriver(frame)
        ApplyFrameNativeStatusBarStyle(frame, false)
        local interpolation = GetStatusBarProgressInterpolation(
            frame.gui2DurationSmoothProgress,
            frame.gui2DurationTimerBound,
            forceImmediate
        )
        local statusOK = pcall(
            statusBar.SetTimerDuration,
            statusBar,
            durationObject,
            interpolation,
            GetCastTimerDirection(true)
        ) == true
        local countdownOK = false
        if frame.countdown
            and frame.countdown.SetCooldownFromDurationObject then
            countdownOK = pcall(
                frame.countdown.SetCooldownFromDurationObject,
                frame.countdown,
                durationObject,
                true
            ) == true
        end
        if frame.countdown then
            if countdownOK then
                frame.countdown:Show()
            else
                frame.countdown:Hide()
            end
        end
        if statusOK then
            frame.gui2DurationTimerBound = true
            -- The hidden native timer owns only the moving boundary. The
            -- visible full-track StatusBar keeps material projection fixed;
            -- only its final color is restored after binding.
            RestoreFrameNativeStatusBarColor(frame)
            if frame.SetNativeFillShown then
                frame:SetNativeFillShown(true)
            else
                statusBar:Show()
            end
        end
        return statusOK
    end

    function App:CreateDurationBar(parent, opts)
        opts = type(opts) == "table" and opts or {}
        if not (GUI2.Data and GUI2.Data.CreateProgressBar) then
            return nil
        end

        local orientation = opts.orientation == "vertical"
            and "vertical" or "horizontal"
        local width = tonumber(opts.width)
            or (orientation == "vertical" and 28 or 244)
        local height = tonumber(opts.height)
            or (orientation == "vertical" and 148 or 24)
        local iconPosition = opts.iconPosition or (
            orientation == "vertical" and "bottom" or "left"
        )
        local iconSize = tonumber(opts.iconSize)
            or (orientation == "vertical" and width or height)
        local frame = GUI2.Data:CreateProgressBar(parent, {
            orientation = orientation,
            width = width,
            height = height,
            value = 0,
            iconPosition = iconPosition,
            iconGap = tonumber(opts.iconGap) or 0,
            iconSize = iconSize,
            icon = opts.icon
                or opts.fallbackIcon
                or "Interface\\Icons\\INV_Misc_QuestionMark",
            fillTexture = opts.fillTexture or opts.statusBarTexture,
            fillColor = opts.fillColor or opts.barColor
                or "color.accent.primary",
            fillDirection = orientation == "vertical" and "up" or "left",
            projectedFill = true,
            collapseAdjacentBorder = true,
            iconVariant = "bare",
            countSink = opts.countSink,
            animate = false,
            motion = false,
        })
        if not frame then return nil end

        frame.gui2Component = "DurationBar"
        frame.gui2DurationReverse = opts.reverse == true
        frame.gui2DurationSmoothProgress = opts.smoothProgress == true
        frame.gui2DurationTimerBound = false
        frame.gui2DurationWidth = width
        frame.gui2DurationHeight = height
        frame.gui2DurationIconSize = iconSize
        frame.gui2DurationIconPosition = iconPosition
        frame.gui2DurationIconGap = tonumber(opts.iconGap) or 0
        frame.gui2DurationShowIcon = opts.showIcon ~= false
        frame.gui2DurationFillTexture =
            opts.fillTexture or opts.statusBarTexture
        frame.gui2DurationFillColor =
            opts.fillColor or opts.barColor or "color.accent.primary"

        if frame.icon and frame.icon.SetIconAppearance then
            frame.icon:SetIconAppearance({
                size = iconSize,
                shape = opts.iconShape or opts.shape or "roundedSquare",
                border = opts.iconBorder or opts.border or "thin",
            })
        end

        local statusBar = frame.nativeStatusBar
            or CreateFrame("StatusBar", nil, frame.track)
        if not frame.nativeStatusBar then
            statusBar:SetAllPoints(frame.track)
        end
        statusBar:SetMinMaxValues(0, 1)
        statusBar:SetValue(0)
        statusBar:Show()
        frame.durationStatusBar = statusBar
        frame.castStatusBar = statusBar
        frame.gui2NativeStatusBarStyle = frame.gui2NativeFillStyle
        ApplyCastStatusBarTexture(frame, frame.gui2DurationFillTexture)
        ApplyCastStatusBarColor(frame, frame.gui2DurationFillColor)

        local borderOverlay = frame.nativeBorderOverlay
            or CreateFrame("Frame", nil, frame.track)
        borderOverlay:SetAllPoints(frame.track)
        if borderOverlay.SetFrameLevel and frame.track.GetFrameLevel then
            borderOverlay:SetFrameLevel(
                (frame.track:GetFrameLevel() or 0)
                    + (frame.nativeVisibleStatusBar and 4 or 2)
            )
        end
        frame.durationBorderOverlay = borderOverlay

        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        if overlay.SetFrameLevel and frame.track.GetFrameLevel then
            overlay:SetFrameLevel((frame.track:GetFrameLevel() or 0) + 4)
        end
        frame.durationOverlay = overlay

        local countText = GUI2:CreateText(
            overlay,
            "",
            "font.size.sm",
            "color.text.primary",
            "RIGHT"
        )
        frame.durationCountText = countText
        if frame.icon and frame.icon.count then frame.icon.count:Hide() end

        local nameText = GUI2:CreateText(
            overlay,
            opts.name or "",
            opts.nameFontSizeKey or "font.size.sm",
            opts.nameColorKey or "color.text.primary",
            orientation == "vertical" and "CENTER" or "LEFT"
        )
        if orientation == "vertical" then
            nameText:SetPoint("CENTER", overlay, "CENTER", 0, 0)
            nameText:SetWidth(height)
        else
            nameText:SetPoint("LEFT", overlay, "LEFT", 5, 0)
            nameText:SetPoint("RIGHT", overlay, "RIGHT", -48, 0)
        end
        nameText:SetWordWrap(false)
        frame.durationNameText = nameText

        local countdownHolder = CreateFrame("Frame", nil, overlay)
        countdownHolder:SetAllPoints(overlay)
        frame.durationCountdownHolder = countdownHolder

        local countdown = CreateFrame(
            "Cooldown",
            nil,
            countdownHolder,
            "CooldownFrameTemplate"
        )
        countdown:SetAllPoints(countdownHolder)
        if countdown.SetDrawSwipe then countdown:SetDrawSwipe(false) end
        if countdown.SetDrawEdge then countdown:SetDrawEdge(false) end
        if countdown.SetDrawBling then countdown:SetDrawBling(false) end
        if countdown.SetMinimumCountdownDuration then
            countdown:SetMinimumCountdownDuration(0)
        end
        frame.countdown = countdown
        ApplyDurationTextAppearance(frame, opts.cooldownText or {
            enabled = true,
            font = "default",
            size = 13,
            outline = "outline",
            position = "center",
        })

        local baseRefreshTheme = frame.RefreshTheme
        frame.SetDurationName = function(self, name)
            if self.durationNameText then
                self.durationNameText:SetText(name or "")
            end
        end
        frame.SetDurationIcon = function(self, texture)
            if self.SetIcon then self:SetIcon(texture) end
        end
        frame.SetDurationIconAppearance = function(self, appearance)
            if self.icon and self.icon.SetIconAppearance then
                self.icon:SetIconAppearance(appearance or {})
            end
        end
        frame.SetDurationIconShown = function(self, shown)
            shown = shown ~= false
            self.gui2DurationShowIcon = shown
            if self.icon and self.icon.SetShown then
                self.icon:SetShown(shown)
            end
            self.iconPosition = shown
                and self.gui2DurationIconPosition or nil
            self:SetBarSize(
                self.gui2DurationWidth,
                self.gui2DurationHeight,
                self.gui2DurationIconSize
            )
            PositionDurationText(
                self,
                GetCooldownFontString(self.countdown),
                self.gui2DurationTextAppearance,
                "time"
            )
            PositionDurationText(
                self,
                self.durationCountText,
                self.gui2DurationCountAppearance,
                "count"
            )
            PositionDurationNameText(self)
        end
        frame.SetCount = function(self, count)
            if self.durationCountText then
                self.durationCountText:SetText(count and tostring(count) or "")
            end
        end
        frame.SetRawCount = function(self, count)
            if self.durationCountText then
                return pcall(
                    self.durationCountText.SetText,
                    self.durationCountText,
                    count
                ) == true
            end
            return false
        end
        frame.SetDurationTextAppearance = function(self, appearance)
            ApplyDurationTextAppearance(self, appearance)
        end
        frame.PositionDurationTextAnchor = function(
            self,
            fontString,
            appearance,
            kind
        )
            return PositionDurationText(
                self,
                fontString,
                appearance,
                kind
            )
        end
        frame.SetDurationCountAppearance = function(self, appearance)
            appearance = type(appearance) == "table" and appearance or {}
            self.gui2DurationCountAppearance = appearance
            if self.durationCountText then
                if GUI2.ApplyFontAppearance then
                    GUI2:ApplyFontAppearance(
                        self.durationCountText,
                        appearance
                    )
                end
                local color = type(appearance.color) == "table"
                    and appearance.color or { 1, 1, 1, 1 }
                self.durationCountText:SetTextColor(
                    color.r or color[1] or 1,
                    color.g or color[2] or 1,
                    color.b or color[3] or 1,
                    (color.a or color[4]) == nil and 1
                        or (color.a or color[4])
                )
                self.durationCountText:SetShown(appearance.enabled ~= false)
                PositionDurationText(
                    self,
                    self.durationCountText,
                    appearance,
                    "count"
                )
            end
        end
        frame.SetDurationNameAppearance = function(self, appearance)
            appearance = type(appearance) == "table"
                and appearance or {}
            self.gui2DurationNameAppearance = appearance
            self.gui2DurationNamePosition =
                appearance.position or "center"
            if self.durationNameText then
                self.durationNameText:SetShown(
                    self.orientation ~= "vertical"
                        and appearance.enabled ~= false
                )
                if GUI2.ApplyFontAppearance then
                    GUI2:ApplyFontAppearance(
                        self.durationNameText,
                        appearance
                    )
                end
                PositionDurationNameText(self)
            end
        end
        frame.SetDurationFillColor = function(self, color)
            self.gui2DurationFillColor = color or "color.accent.primary"
            self.gui2FillColor = self.gui2DurationFillColor
            ApplyCastStatusBarColor(self, self.gui2DurationFillColor)
        end
        frame.PreviewDurationFillColor = function(self, color)
            self.gui2DurationFillColor = color or "color.accent.primary"
            self.gui2FillColor = self.gui2DurationFillColor
            local writes = ApplyCastStatusBarColor(
                self,
                self.gui2DurationFillColor
            )
            return (tonumber(writes) or 0) > 0
        end
        frame.PreviewDurationTrackColor = function(self, color)
            return PreviewPanelColor(self.track, color)
        end
        frame.SetDurationFillTexture = function(
            self,
            texture,
            u0,
            u1,
            v0,
            v1
        )
            self.gui2DurationFillTexture = texture
            self.gui2FillTexture = texture
            local style = GetFrameNativeStatusBarStyle(self)
            style.textureU0 = tonumber(u0) or 0
            style.textureU1 = tonumber(u1) or 1
            style.textureV0 = tonumber(v0) or 0
            style.textureV1 = tonumber(v1) or 1
            ApplyCastStatusBarTexture(self, texture)
        end
        frame.SetDurationSmoothProgress = function(self, enabled)
            enabled = enabled == true
            if self.gui2DurationSmoothProgress == enabled then return false end
            self.gui2DurationSmoothProgress = enabled
            if not enabled and self.gui2DurationTimerBound == true then
                if not StopStatusBarInterpolation(self.durationStatusBar)
                    and self.gui2DurationObjectSource then
                    SetNativeDuration(
                        self,
                        self.gui2DurationObjectSource,
                        self.gui2DurationReverse,
                        true
                    )
                end
            end
            return true
        end
        frame.SetDurationObject = function(self, durationObject, reverse)
            self.gui2DurationObjectSource = durationObject
            self.gui2DurationReverse = reverse == true
            if not durationObject then
                self:ClearDuration()
                return true
            end
            return SetNativeDuration(
                self,
                durationObject,
                self.gui2DurationReverse
            )
        end
        frame.SetDurationFromTimes = function(
            self,
            startTime,
            duration,
            modRate,
            reverse
        )
            duration = tonumber(duration) or 0
            if duration <= 0 then
                self:ClearDuration()
                return true
            end
            local durationObject = self.gui2OwnedDurationObject
                or CreateDurationObject()
            self.gui2OwnedDurationObject = durationObject
            if SetDurationObjectTimes(
                durationObject,
                startTime,
                duration,
                modRate
            ) then
                return self:SetDurationObject(durationObject, reverse)
            end
            self.gui2DurationObjectSource = nil
            if self.countdown and self.countdown.SetCooldown then
                self.countdown:SetCooldown(
                    tonumber(startTime) or 0,
                    duration,
                    tonumber(modRate) or 1
                )
                self.countdown:Show()
            end
            return false
        end
        frame.ClearDuration = function(self)
            self.gui2DurationObjectSource = nil
            self.gui2DurationTimerBound = false
            if self.gui2OwnedDurationObject
                and self.gui2OwnedDurationObject.Reset then
                pcall(
                    self.gui2OwnedDurationObject.Reset,
                    self.gui2OwnedDurationObject
                )
            end
            if self.durationStatusBar then
                self.durationStatusBar:SetMinMaxValues(
                    0,
                    1,
                    GetStatusBarImmediateInterpolation()
                )
                self.durationStatusBar:SetValue(
                    0,
                    GetStatusBarImmediateInterpolation()
                )
            end
            if self.SetNativeFillShown then
                self:SetNativeFillShown(false)
            end
            ClearCooldown(self.countdown)
            if self.countdown then self.countdown:Hide() end
        end
        frame.SetDurationBarSize = function(
            self,
            nextWidth,
            nextHeight,
            nextIconSize
        )
            self.gui2DurationWidth = math_max(
                1,
                tonumber(nextWidth) or self.gui2DurationWidth
            )
            self.gui2DurationHeight = math_max(
                1,
                tonumber(nextHeight) or self.gui2DurationHeight
            )
            self.gui2DurationIconSize = math_max(
                1,
                tonumber(nextIconSize) or self.gui2DurationIconSize
            )
            self:SetBarSize(
                self.gui2DurationWidth,
                self.gui2DurationHeight,
                self.gui2DurationIconSize
            )
            PositionDurationText(
                self,
                GetCooldownFontString(self.countdown),
                self.gui2DurationTextAppearance,
                "time"
            )
            PositionDurationText(
                self,
                self.durationCountText,
                self.gui2DurationCountAppearance,
                "count"
            )
            PositionDurationNameText(self)
        end
        frame.SetDurationBarLayout = function(
            self,
            nextOrientation,
            nextIconPosition,
            nextIconGap
        )
            nextOrientation = nextOrientation == "vertical"
                and "vertical" or "horizontal"
            nextIconPosition = nextIconPosition
                or (nextOrientation == "vertical" and "bottom" or "left")
            self.orientation = nextOrientation
            self.gui2DurationIconPosition = nextIconPosition
            self.iconPosition = self.gui2DurationShowIcon == false
                and nil or nextIconPosition
            self.iconGap = math_max(0, tonumber(nextIconGap) or 0)
            self.gui2DurationIconGap = self.iconGap
            ApplyFrameNativeStatusBarStyle(self, false)
            PositionDurationNameText(self)
            if self.durationNameText then
                local appearance = self.gui2DurationNameAppearance or {}
                self.durationNameText:SetShown(
                    nextOrientation ~= "vertical"
                        and appearance.enabled ~= false
                )
            end
            if self.durationCountdownHolder then
                self.durationCountdownHolder:ClearAllPoints()
                self.durationCountdownHolder:SetAllPoints(
                    self.durationOverlay
                )
            end
            if self.SetFillDirection then
                self:SetFillDirection(
                    nextOrientation == "vertical" and "up" or "left"
                )
            end
            self:SetDurationBarSize(
                self.gui2DurationWidth,
                self.gui2DurationHeight,
                self.gui2DurationIconSize
            )
            PositionDurationText(
                self,
                GetCooldownFontString(self.countdown),
                self.gui2DurationTextAppearance,
                "time"
            )
            PositionDurationText(
                self,
                self.durationCountText,
                self.gui2DurationCountAppearance,
                "count"
            )
            if self.gui2DurationObjectSource then
                SetNativeDuration(
                    self,
                    self.gui2DurationObjectSource,
                    self.gui2DurationReverse,
                    true
                )
            end
        end
        frame.RefreshTheme = function(self)
            if baseRefreshTheme then baseRefreshTheme(self) end
            ApplyCastStatusBarTexture(self, self.gui2DurationFillTexture)
            ApplyCastStatusBarColor(self, self.gui2DurationFillColor)
            ApplyDurationTextAppearance(
                self,
                self.gui2DurationTextAppearance
            )
            self:SetDurationCountAppearance(
                self.gui2DurationCountAppearance
            )
            self:SetDurationNameAppearance(
                self.gui2DurationNameAppearance
            )
        end
        frame:SetDurationNameAppearance(opts.nameText or {
            enabled = true,
            font = "default",
            size = 12,
            outline = "outline",
        })
        frame:SetDurationCountAppearance(opts.countText or {
            enabled = true,
            font = "default",
            size = 12,
            outline = "outline",
            anchor = "icon-bottom-right",
        })
        return frame
    end

    local function ApplyResourceBorder(frame, border)
        local track = frame and frame.track
        local trackBorders = track and track.gui2Borders
        if trackBorders then
            trackBorders.top:Hide()
            trackBorders.bottom:Hide()
            trackBorders.left:Hide()
            trackBorders.right:Hide()
        end
        local borders = frame and frame.resourceBorderEdges
        if not (track and borders) then return end
        local thickness = tonumber(border)
        if not thickness then
            thickness = GUI2.GetIconBorderThickness
                and GUI2:GetIconBorderThickness(border or "thin") or 1
        end
        thickness = math_max(0, math_min(12, thickness))
        local shown = thickness > 0
        local edges = {
            borders.top,
            borders.bottom,
            borders.left,
            borders.right,
        }
        for index = 1, #edges do
            edges[index]:SetShown(shown)
        end
        if shown then
            if GUI2.LayoutPixelBorder then
                GUI2:LayoutPixelBorder(
                    borders,
                    track,
                    thickness,
                    0,
                    0
                )
            else
                local size = math_max(1, thickness * (GUI2.mult or 1))
                borders.top:SetHeight(size)
                borders.bottom:SetHeight(size)
                borders.left:SetWidth(size)
                borders.right:SetWidth(size)
            end
            local color = frame.gui2ResourceBorderColor
            local r, g, b, a
            if type(color) == "string" and GUI2.GetColor then
                r, g, b, a = GUI2:GetColor(color)
            else
                color = type(color) == "table" and color or {}
                r = color.r or color[1] or 0
                g = color.g or color[2] or 0
                b = color.b or color[3] or 0
                a = color.a or color[4]
                if a == nil then a = 1 end
            end
            for index = 1, #edges do
                edges[index]:SetVertexColor(r, g, b, a)
            end
        end
    end

    local function PositionResourceText(frame)
        if not frame or not frame.resourceOverlay then return end
        local vertical = frame.gui2ResourceOrientation == "vertical"
        local nameText = frame.resourceNameText
        local valueText = frame.resourceValueText
        if nameText then
            nameText:ClearAllPoints()
            if vertical then
                nameText:SetPoint(
                    "BOTTOM",
                    frame.resourceOverlay,
                    "BOTTOM",
                    0,
                    4
                )
                nameText:SetWidth(math_max(
                    1,
                    frame.gui2ResourceHeight - 8
                ))
            else
                nameText:SetPoint(
                    "LEFT",
                    frame.resourceOverlay,
                    "LEFT",
                    5,
                    0
                )
                nameText:SetPoint(
                    "RIGHT",
                    frame.resourceOverlay,
                    "RIGHT",
                    -54,
                    0
                )
            end
        end
        if valueText then
            local appearance = frame.gui2ResourceTextAppearance or {}
            local position = appearance.position
            if position ~= "start" and position ~= "end" then
                position = "center"
            end
            local offsetX = tonumber(appearance.offsetX) or 0
            local offsetY = tonumber(appearance.offsetY) or 0
            valueText:ClearAllPoints()
            if vertical then
                local point = position == "start" and "BOTTOM"
                    or (position == "end" and "TOP" or "CENTER")
                local inset = position == "start" and 4
                    or (position == "end" and -4 or 0)
                valueText:SetPoint(
                    point,
                    frame.resourceOverlay,
                    point,
                    offsetX,
                    offsetY + inset
                )
                valueText:SetWidth(math_max(
                    1,
                    frame.gui2ResourceHeight - 8
                ))
            else
                -- FontString 会保留之前由方向写入的显式宽度。每次都重写
                -- 横向可用宽度和唯一锚点，避免连续切换左/中/右时旧状态
                -- 继续参与布局计算。
                valueText:SetWidth(math_max(
                    1,
                    frame.gui2ResourceWidth - 10
                ))
                local point = position == "start" and "LEFT"
                    or (position == "end" and "RIGHT" or "CENTER")
                local inset = position == "start" and 5
                    or (position == "end" and -5 or 0)
                valueText:SetPoint(
                    point,
                    frame.resourceOverlay,
                    point,
                    offsetX + inset,
                    offsetY
                )
                if valueText.SetJustifyH then
                    valueText:SetJustifyH(
                        position == "start" and "LEFT"
                            or (position == "end" and "RIGHT" or "CENTER")
                    )
                end
            end
        end
    end

    local function FormatResourceValue(value, maxValue, valueFormat)
        local roundedValue = math_floor(value + 0.5)
        local valueText = tostring(roundedValue)
        if math_abs(value - roundedValue) >= 0.05 then
            valueText = string_format("%.1f", value)
        end
        if valueFormat == "value" then return valueText end
        local percent = maxValue > 0 and (value / maxValue) * 100 or 0
        percent = math_max(0, math_min(100, math_floor(percent + 0.5)))
        local percentNumberText = tostring(percent)
        local percentText = percentNumberText .. "%"
        if valueFormat == "percent" then return percentNumberText end
        if valueFormat == "percentSign" then return percentText end
        if valueFormat == "valuePercent" then
            return valueText .. " | " .. percentText
        elseif valueFormat == "percentValue" then
            return percentText .. " | " .. valueText
        elseif valueFormat == "valuePercentParen" then
            return valueText .. " (" .. percentText .. ")"
        end
        return percentNumberText
    end

    local function ClearResourceValueText(fontString)
        if not fontString then return end
        if fontString.ClearText then
            fontString:ClearText()
        else
            fontString:SetText("")
        end
    end

    local function SetSecretResourceValueText(
        fontString,
        valueRaw,
        percentRaw,
        valueFormat
    )
        if not (fontString and fontString.SetFormattedText) then
            ClearResourceValueText(fontString)
            return false
        end
        local ok
        if valueFormat == "value" then
            ok = pcall(fontString.SetFormattedText, fontString, "%d", valueRaw)
        elseif valueFormat == "percentSign" then
            ok = pcall(fontString.SetFormattedText, fontString, "%d%%", percentRaw)
        elseif valueFormat == "valuePercent" then
            ok = pcall(
                fontString.SetFormattedText,
                fontString,
                "%d | %d%%",
                valueRaw,
                percentRaw
            )
        elseif valueFormat == "percentValue" then
            ok = pcall(
                fontString.SetFormattedText,
                fontString,
                "%d%% | %d",
                percentRaw,
                valueRaw
            )
        elseif valueFormat == "valuePercentParen" then
            ok = pcall(
                fontString.SetFormattedText,
                fontString,
                "%d (%d%%)",
                valueRaw,
                percentRaw
            )
        else
            ok = pcall(
                fontString.SetFormattedText,
                fontString,
                "%d",
                percentRaw
            )
        end
        if not ok then ClearResourceValueText(fontString) end
        return ok == true
    end

    local function ResourceColorComponents(color, fallback)
        if type(color) == "string" then
            return GUI2:GetColor(color)
        end
        color = type(color) == "table" and color or fallback
        color = type(color) == "table" and color or {}
        return color.r or color[1] or 1,
            color.g or color[2] or 1,
            color.b or color[3] or 1,
            (color.a or color[4]) == nil and 1 or (color.a or color[4])
    end

    local function ForEachResourceStatusBar(frame, callback, ...)
        if frame.resourceStatusBar and frame.resourceStatusBar:IsShown() then
            callback(frame.resourceStatusBar, ...)
        end
        local cells = frame.resourceCells
        for index = 1, frame.gui2ResourceActiveCellCount or 0 do
            local cell = cells and cells[index]
            if cell and cell.statusBar and cell.host:IsShown() then
                callback(cell.statusBar, ...)
            end
        end
    end

    local function ApplyResourceStatusBarTexturePixelPolicy(statusBar)
        statusBar = GetVisibleNativeStatusBar(statusBar)
        return GUI2.RefreshNativeStatusBarTexturePolicy
            and GUI2:RefreshNativeStatusBarTexturePolicy(statusBar) > 0
            or false
    end

    local function GetResourceNativeStatusBarStyle(frame)
        local style = frame.gui2ResourceNativeFillStyle or {}
        frame.gui2ResourceNativeFillStyle = style
        style.texture = frame.gui2ResourceFillTexture
            or DEFAULT_CAST_BAR_TEXTURE
        style.textureU0 = frame.gui2ResourceFillTextureU0 or 0
        style.textureU1 = frame.gui2ResourceFillTextureU1 or 1
        style.textureV0 = frame.gui2ResourceFillTextureV0 or 0
        style.textureV1 = frame.gui2ResourceFillTextureV1 or 1
        -- Each layer may have a distinct threshold/recharge color. The native
        -- renderer keeps the last color per StatusBar and restores it after
        -- any material, orientation, rotation or fill-style write.
        style.fillColor = nil
        return style
    end

    local function EnsureResourceStatusBarFillStyle(frame, statusBar, force)
        if not (frame and statusBar and GUI2.ApplyNativeStatusBarStyle) then
            return false
        end
        if statusBar.gui2ProjectedOwner
            and statusBar.gui2ProjectedOwner.RefreshProjectedDriverStyle then
            statusBar.gui2ProjectedOwner:RefreshProjectedDriverStyle()
        end
        statusBar = GetVisibleNativeStatusBar(statusBar)
        return GUI2:ApplyNativeStatusBarStyle(
            statusBar,
            GetResourceNativeStatusBarStyle(frame),
            frame.gui2ResourceOrientation,
            frame.gui2ResourceFillDirection,
            force == true
        ) > 0
    end

    local function SetResourceStatusBarColor(statusBar, r, g, b, a)
        statusBar = GetVisibleNativeStatusBar(statusBar)
        if GUI2.ApplyNativeStatusBarColor then
            return GUI2:ApplyNativeStatusBarColor(
                statusBar,
                r,
                g,
                b,
                a
            ) > 0
        end
        return false
    end

    local function SetResourceStatusBarTransientColor(
        statusBar,
        r,
        g,
        b,
        a
    )
        statusBar = GetVisibleNativeStatusBar(statusBar)
        if GUI2.ApplyNativeStatusBarTransientColor then
            return GUI2:ApplyNativeStatusBarTransientColor(
                statusBar,
                r,
                g,
                b,
                a
            ) > 0
        end
        return false
    end

    local function RestoreResourceStatusBarColor(statusBar)
        statusBar = GetVisibleNativeStatusBar(statusBar)
        return GUI2.RestoreNativeStatusBarColor
            and GUI2:RestoreNativeStatusBarColor(statusBar) > 0
            or false
    end

    local function SetResourceStatusBarValue(
        frame,
        statusBar,
        value,
        forceImmediate
    )
        if not (statusBar and statusBar.SetValue) then return false end
        local interpolation = GetStatusBarProgressInterpolation(
            frame.gui2ResourceSmoothProgress,
            frame.gui2ResourceProgressBound,
            forceImmediate
        )
        local applied = pcall(
            statusBar.SetValue,
            statusBar,
            value,
            interpolation
        ) == true
        if applied then frame.gui2ResourceProgressBound = true end
        return applied
    end

    local function RememberResourceFillColor(frame, r, g, b, a)
        frame.gui2ResourceEffectiveFillR = r
        frame.gui2ResourceEffectiveFillG = g
        frame.gui2ResourceEffectiveFillB = b
        frame.gui2ResourceEffectiveFillA = a
    end

    local function CreateResourceLayerStatusBar(host, frameLevel)
        local statusBar = CreateFrame("StatusBar", nil, host)
        statusBar:SetAllPoints(host)
        statusBar:SetMinMaxValues(0, 1)
        statusBar:SetValue(0)
        statusBar.gui2ResourceBounds = host
        if statusBar.SetFrameLevel then
            statusBar:SetFrameLevel(frameLevel)
        end
        statusBar:Hide()
        return statusBar
    end

    local function CreateResourceRechargeLayers(host, frameLevel)
        local gateBar = CreateResourceLayerStatusBar(host, frameLevel)
        gateBar.gui2ResourceGeometryOnly = true
        gateBar:SetAlpha(0)
        gateBar:Show()
        local clip = CreateFrame("Frame", nil, host)
        if clip.SetClipsChildren then clip:SetClipsChildren(true) end
        if clip.SetFrameLevel then clip:SetFrameLevel(frameLevel + 1) end
        local rechargeBar = CreateResourceLayerStatusBar(
            clip,
            frameLevel + 1
        )
        rechargeBar:ClearAllPoints()
        rechargeBar:SetAllPoints(host)
        clip:Hide()
        return gateBar, clip, rechargeBar
    end

    local function ApplyResourceBaseColor(frame)
        local r, g, b, a = ResourceColorComponents(
            frame.gui2ResourceFillColor,
            { 1, 1, 1, 1 }
        )
        ForEachResourceStatusBar(
            frame,
            SetResourceStatusBarColor,
            r,
            g,
            b,
            a
        )
        RememberResourceFillColor(frame, r, g, b, a)
    end

    local function ApplyResourcePublicThresholdColor(
        frame,
        value,
        maxValue,
        rechargeActive
    )
        local config = frame.gui2ResourceDisplayConfig or {}
        if config.thresholdColorEnabled ~= true then
            ApplyResourceBaseColor(frame)
            return true
        end
        local thresholdValue = value
        if config.valueKind ~= "discrete" then
            thresholdValue = maxValue > 0 and ((value / maxValue) * 100) or 0
        end
        local thresholds = config.thresholds or {}
        local low = thresholds.low
        local high = thresholds.high
        local color = frame.gui2ResourceFillColor
        if type(high) == "table" and high.enabled == true
            and thresholdValue >= (tonumber(high.value) or 0) then
            color = high.color or color
        elseif type(low) == "table" and low.enabled == true
            and (
                rechargeActive == true and config.valueKind == "discrete"
                    and thresholdValue < (tonumber(low.value) or 0)
                or rechargeActive ~= true
                    and thresholdValue <= (tonumber(low.value) or 0)
            ) then
            color = low.color or color
        end
        local r, g, b, a = ResourceColorComponents(
            color,
            { 1, 1, 1, 1 }
        )
        ForEachResourceStatusBar(
            frame,
            SetResourceStatusBarColor,
            r,
            g,
            b,
            a
        )
        RememberResourceFillColor(frame, r, g, b, a)
        return true
    end

    local function ApplyResourcePublicValues(frame)
        local config = frame.gui2ResourceDisplayConfig or {}
        if config.independentCells == true then return false end
        if frame.gui2ResourceHasPublicValues ~= true then return false end
        local value = frame.gui2ResourcePublicValue or 0
        local maxValue = frame.gui2ResourcePublicMaxValue or 0
        local cellsMode = config.mode == "cells" or config.mode == "dots"
        if cellsMode then
            for index = 1, frame.gui2ResourceActiveCellCount or 0 do
                local cell = frame.resourceCells[index]
                local cellValue = math_max(
                    0,
                    math_min(1, value - (index - 1))
                )
                cell.statusBar:SetMinMaxValues(0, 1)
                cell.statusBar:SetValue(
                    cellValue,
                    GetStatusBarImmediateInterpolation()
                )
            end
        else
            frame.resourceStatusBar:SetMinMaxValues(
                0,
                maxValue > 0 and maxValue or 1,
                GetStatusBarImmediateInterpolation()
            )
            local applied = SetResourceStatusBarValue(
                frame,
                frame.resourceStatusBar,
                value
            )
            if applied and frame.SetNativeFillShown then
                frame:SetNativeFillShown(true)
            end
        end
        ApplyResourcePublicThresholdColor(
            frame,
            value,
            maxValue,
            frame.gui2ResourceRechargeActive
        )
        return true
    end

    local ResourceRuntimeOnUpdate

    local function UpdateResourceRuntimeDriver(frame)
        local active = frame.gui2ResourcePartialRechargeActive == true
        frame:SetScript("OnUpdate", active and ResourceRuntimeOnUpdate or nil)
    end

    local function ResetResourcePartialVisual(frame)
        local previousIndex = frame.gui2ResourcePartialCellIndex
        local previousCell = previousIndex and frame.resourceCells
            and frame.resourceCells[previousIndex]
        if previousCell and previousCell.statusBar then
            local publicValue = tonumber(frame.gui2ResourcePublicValue) or 0
            previousCell.statusBar:SetValue(
                previousIndex <= math_floor(publicValue) and 1 or 0
            )
            SetResourceStatusBarColor(
                previousCell.statusBar,
                frame.gui2ResourceEffectiveFillR or 1,
                frame.gui2ResourceEffectiveFillG or 1,
                frame.gui2ResourceEffectiveFillB or 1,
                frame.gui2ResourceEffectiveFillA or 1
            )
        end
        frame.gui2ResourcePartialCellIndex = nil
        if frame.resourcePartialBar then
            frame.resourcePartialBar:SetValue(0)
        end
        if frame.resourcePartialHost then
            frame.resourcePartialHost:Hide()
        end
    end

    local function StopResourcePartialRecharge(frame)
        ResetResourcePartialVisual(frame)
        if frame.gui2ResourcePartialRechargeActive == true then
            frame.gui2ResourcePartialRechargeActive = false
            UpdateResourceRuntimeDriver(frame)
        end
    end

    local function RefreshResourcePartialRecharge(frame)
        local config = frame.gui2ResourceDisplayConfig or {}
        local value = frame.gui2ResourcePublicValue
        local maxValue = frame.gui2ResourcePublicMaxValue
        local reader = config.partialProgressReader
        if config.partialRecharge ~= true
            or frame.gui2ResourceHasPublicValues ~= true
            or type(value) ~= "number" or type(maxValue) ~= "number"
            or value >= maxValue or type(reader) ~= "function" then
            StopResourcePartialRecharge(frame)
            return false
        end
        local partial = reader(
            config.partialUnit,
            config.partialPowerType,
            config.partialScale,
            config.partialSource
        )
        if type(partial) ~= "number" then
            StopResourcePartialRecharge(frame)
            return false
        end
        partial = math_max(0, math_min(1, partial))
        frame.gui2ResourcePartialFraction = partial
        frame.gui2ResourceDisplayValue = value + partial
        local cellsMode = config.mode == "cells" or config.mode == "dots"
        if cellsMode then
            local nextIndex = math_floor(value) + 1
            local cell = frame.resourceCells
                and frame.resourceCells[nextIndex]
            if cell and cell.statusBar then
                local previousIndex = frame.gui2ResourcePartialCellIndex
                if previousIndex and previousIndex ~= nextIndex then
                    local previousCell = frame.resourceCells[previousIndex]
                    if previousCell and previousCell.statusBar then
                        SetResourceStatusBarColor(
                            previousCell.statusBar,
                            frame.gui2ResourceEffectiveFillR or 1,
                            frame.gui2ResourceEffectiveFillG or 1,
                            frame.gui2ResourceEffectiveFillB or 1,
                            frame.gui2ResourceEffectiveFillA or 1
                        )
                    end
                end
                frame.gui2ResourcePartialCellIndex = nextIndex
                cell.statusBar:SetMinMaxValues(0, 1)
                cell.statusBar:SetValue(partial)
                SetResourceStatusBarColor(
                    cell.statusBar,
                    frame.gui2ResourceEffectiveFillR or 1,
                    frame.gui2ResourceEffectiveFillG or 1,
                    frame.gui2ResourceEffectiveFillB or 1,
                    (frame.gui2ResourceEffectiveFillA or 1) * 0.5
                )
            end
        elseif frame.resourcePartialHost and frame.resourcePartialBar
            and maxValue > 0 then
            local vertical = frame.gui2ResourceOrientation == "vertical"
            local reverse = frame.gui2ResourceFillDirection == "reverse"
            local trackWidth = frame.track:GetWidth()
            local trackHeight = frame.track:GetHeight()
            local mainSize = vertical and trackHeight or trackWidth
            local crossSize = vertical and trackWidth or trackHeight
            local segmentSize = mainSize / maxValue
            local offset = value * segmentSize
            if reverse then offset = mainSize - ((value + 1) * segmentSize) end
            local host = frame.resourcePartialHost
            host:ClearAllPoints()
            host:SetPoint(
                "BOTTOMLEFT",
                frame.track,
                "BOTTOMLEFT",
                vertical and 0 or offset,
                vertical and offset or 0
            )
            if vertical then
                host:SetSize(crossSize, segmentSize)
            else
                host:SetSize(segmentSize, crossSize)
            end
            frame.resourcePartialBar:SetMinMaxValues(0, 1)
            frame.resourcePartialBar:SetValue(partial)
            SetResourceStatusBarColor(
                frame.resourcePartialBar,
                frame.gui2ResourceEffectiveFillR or 1,
                frame.gui2ResourceEffectiveFillG or 1,
                frame.gui2ResourceEffectiveFillB or 1,
                (frame.gui2ResourceEffectiveFillA or 1) * 0.5
            )
            host:Show()
        end
        if frame.resourceValueText then
            frame.resourceValueText:SetText(FormatResourceValue(
                frame.gui2ResourceDisplayValue,
                maxValue,
                frame.gui2ResourceValueFormat
            ))
        end
        return true
    end

    local function StartResourcePartialRecharge(frame)
        local config = frame.gui2ResourceDisplayConfig or {}
        if config.partialRecharge ~= true
            or frame.gui2ResourceHasPublicValues ~= true
            or type(frame.gui2ResourcePublicValue) ~= "number"
            or type(frame.gui2ResourcePublicMaxValue) ~= "number"
            or frame.gui2ResourcePublicValue >= frame.gui2ResourcePublicMaxValue
            or type(config.partialProgressReader) ~= "function" then
            StopResourcePartialRecharge(frame)
            return false
        end
        if frame.gui2ResourcePartialRechargeActive ~= true then
            frame.gui2ResourcePartialRechargeActive = true
            UpdateResourceRuntimeDriver(frame)
        end
        return RefreshResourcePartialRecharge(frame)
    end

    local function EnsureResourceTimerMarkers(frame, count)
        frame.resourceTimerMarkers = frame.resourceTimerMarkers or {}
        local parent = frame.resourceDecorationOverlay
        if not parent then return false end
        for index = #frame.resourceTimerMarkers + 1, count do
            local marker = parent:CreateTexture(nil, "OVERLAY", nil, 2)
            marker:SetTexture(DEFAULT_CAST_BAR_TEXTURE)
            marker:SetVertexColor(1, 1, 1, 1)
            if GUI2.ApplyTexturePixelPolicy then
                GUI2:ApplyTexturePixelPolicy(marker)
            end
            if marker.CreateAnimationGroup then
                local group = marker:CreateAnimationGroup()
                local translation = group:CreateAnimation("Translation")
                translation:SetOrder(1)
                if translation.SetSmoothing then
                    translation:SetSmoothing("NONE")
                end
                group:SetScript("OnFinished", function()
                    marker:Hide()
                end)
                marker.gui2TimerMarkerGroup = group
                marker.gui2TimerMarkerTranslation = translation
            end
            marker:Hide()
            frame.resourceTimerMarkers[index] = marker
        end
        return true
    end

    local function StopResourceTimerMarker(marker)
        local group = marker and marker.gui2TimerMarkerGroup
        if group and group.Stop then group:Stop() end
        if marker then marker:Hide() end
    end

    local function HideResourceTimerMarkers(frame, firstIndex)
        for index = firstIndex or 1, #(frame.resourceTimerMarkers or {}) do
            StopResourceTimerMarker(frame.resourceTimerMarkers[index])
        end
    end

    local function StopResourceTimerMarkers(frame)
        frame.gui2ResourceTimerMarkerCount = 0
        HideResourceTimerMarkers(frame)
    end

    local function StartResourceTimerMarker(frame, marker, entry, now)
        local duration = entry and entry.duration
        local expiresAt = entry and entry.expiresAt
        local group = marker and marker.gui2TimerMarkerGroup
        local translation = marker and marker.gui2TimerMarkerTranslation
        if type(duration) ~= "number" or duration <= 0
            or type(expiresAt) ~= "number" or expiresAt <= now
            or not (marker and group and translation) then
            StopResourceTimerMarker(marker)
            return false
        end
        group:Stop()
        local vertical = frame.gui2ResourceOrientation == "vertical"
        local reverse = frame.gui2ResourceFillDirection == "reverse"
        local mainSize = vertical and frame.track:GetHeight()
            or frame.track:GetWidth()
        local pixelSize = GUI2.GetPixelSize
            and GUI2:GetPixelSize(frame.track, 1, 1)
            or (GUI2.mult or 1)
        local totalPixels = math_max(1, math_floor((mainSize / pixelSize) + 0.5))
        local markerPixels = math_min(3, totalPixels)
        local travelPixels = math_max(0, totalPixels - markerPixels)
        local startProgress = math_max(
            0,
            math_min(1, (expiresAt - now) / duration)
        )
        local endProgress = 0
        if reverse then
            startProgress = 1 - startProgress
            endProgress = 1
        end
        local startOffset = startProgress * travelPixels * pixelSize
        local endOffset = endProgress * travelPixels * pixelSize
        marker:ClearAllPoints()
        marker:SetPoint(
            "BOTTOMLEFT",
            frame.track,
            "BOTTOMLEFT",
            vertical and 0 or startOffset,
            vertical and startOffset or 0
        )
        if vertical then
            marker:SetSize(frame.track:GetWidth(), markerPixels * pixelSize)
        else
            marker:SetSize(markerPixels * pixelSize, frame.track:GetHeight())
        end
        translation:SetOffset(
            vertical and 0 or (endOffset - startOffset),
            vertical and (endOffset - startOffset) or 0
        )
        translation:SetDuration(expiresAt - now)
        marker:Show()
        group:Play()
        return true
    end

    local function StartResourceTimerMarkers(frame, sourceEntries)
        local config = frame.gui2ResourceDisplayConfig or {}
        if config.timerMarkers ~= true or type(sourceEntries) ~= "table"
            or #sourceEntries < 1 then
            StopResourceTimerMarkers(frame)
            return false
        end
        local count = #sourceEntries
        if not EnsureResourceTimerMarkers(frame, count) then return false end
        frame.gui2ResourceTimerEntries = frame.gui2ResourceTimerEntries or {}
        local target = frame.gui2ResourceTimerEntries
        for index = 1, count do
            local source = sourceEntries[index]
            local entry = target[index]
            if not entry then
                entry = {}
                target[index] = entry
            end
            entry.duration = source and source.duration
            entry.expiresAt = source and source.expiresAt
        end
        for index = count + 1, #target do
            target[index] = nil
        end
        frame.gui2ResourceTimerMarkerCount = count
        HideResourceTimerMarkers(frame, count + 1)
        local now = GetTime and GetTime() or 0
        local active = false
        for index = 1, count do
            active = StartResourceTimerMarker(
                frame,
                frame.resourceTimerMarkers[index],
                target[index],
                now
            ) or active
        end
        if not active then StopResourceTimerMarkers(frame) end
        return active
    end

    ResourceRuntimeOnUpdate = function(frame, elapsed)
        elapsed = type(elapsed) == "number" and elapsed or 0
        if frame.gui2ResourcePartialRechargeActive == true then
            local accumulated = (frame.gui2ResourcePartialElapsed or 0) + elapsed
            local config = frame.gui2ResourceDisplayConfig or {}
            local interval = math_max(
                0.05,
                math_min(0.50, tonumber(config.partialPollInterval) or 0.05)
            )
            if accumulated >= interval then
                frame.gui2ResourcePartialElapsed = accumulated % interval
                RefreshResourcePartialRecharge(frame)
                if frame.RefreshResourceFillStyle then
                    frame:RefreshResourceFillStyle(false)
                end
            else
                frame.gui2ResourcePartialElapsed = accumulated
            end
        else
            frame.gui2ResourcePartialElapsed = 0
        end
    end

    local function GetResourceRawColorComponents(colorRaw)
        return colorRaw:GetRGBA()
    end

    local function VerifyResourceRawColorFillStyle(statusBar, frame)
        EnsureResourceStatusBarFillStyle(frame, statusBar, false)
    end

    local function ApplyResourceRawColor(frame, colorRaw)
        -- Verify material identity before the opaque write. A style refresh
        -- after the write would intentionally restore the authored color and
        -- erase the transient threshold result.
        ForEachResourceStatusBar(
            frame,
            VerifyResourceRawColorFillStyle,
            frame
        )
        local ok, r, g, b, a = pcall(
            GetResourceRawColorComponents,
            colorRaw
        )
        if not ok then return false, true end
        local applied = false
        local statusBar = frame.resourceStatusBar
        if statusBar and statusBar:IsShown() then
            applied = SetResourceStatusBarTransientColor(
                statusBar,
                r,
                g,
                b,
                a
            ) or applied
        end
        local cells = frame.resourceCells
        for index = 1, frame.gui2ResourceActiveCellCount or 0 do
            local cell = cells and cells[index]
            statusBar = cell and cell.statusBar
            if cell and cell.host:IsShown() and statusBar then
                applied = SetResourceStatusBarTransientColor(
                    statusBar,
                    r,
                    g,
                    b,
                    a
                ) or applied
            end
        end
        return applied, true
    end

    local function ApplyResourceCellCooldownAppearance(frame, cell)
        local cooldown = cell and cell.cooldown
        if not (cooldown and cooldown.GetCountdownFontString) then return false end
        local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
        if not ok or not text then return false end
        local appearance = frame.gui2ResourceTextAppearance or {}
        if GUI2.ApplyFontAppearance then
            GUI2:ApplyFontAppearance(text, {
                font = appearance.font,
                size = appearance.runeCooldownTextSize or appearance.size or 12,
                outline = appearance.outline,
                color = appearance.color,
            })
        end
        return true
    end

    local function CreateResourceCell(frame)
        local host = CreateFrame("Frame", nil, frame.track)
        if host.SetFrameLevel and frame.track.GetFrameLevel then
            host:SetFrameLevel((frame.track:GetFrameLevel() or 0) + 1)
        end
        local background = host:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(host)
        background:SetTexture(DEFAULT_CAST_BAR_TEXTURE)
        local hostLevel = host.GetFrameLevel and host:GetFrameLevel() or 0
        local rechargeGate, rechargeClip, rechargeBar =
            CreateResourceRechargeLayers(host, hostLevel + 1)
        local statusBar = CreateResourceLayerStatusBar(host, hostLevel + 3)
        statusBar:SetAllPoints(host)
        statusBar:SetMinMaxValues(0, 1)
        statusBar:SetValue(0)
        statusBar:Show()
        local thresholdLow = CreateResourceLayerStatusBar(host, hostLevel + 4)
        local thresholdReset = CreateResourceLayerStatusBar(host, hostLevel + 5)
        local thresholdHigh = CreateResourceLayerStatusBar(host, hostLevel + 6)
        local borderOverlay = CreateFrame("Frame", nil, host)
        borderOverlay:SetAllPoints(host)
        if borderOverlay.SetFrameLevel then
            borderOverlay:SetFrameLevel(hostLevel + 7)
        end
        local border = borderOverlay:CreateTexture(nil, "OVERLAY", nil, 1)
        border:SetAllPoints(host)
        if GUI2.ApplyTexturePixelPolicy then
            GUI2:ApplyTexturePixelPolicy(border)
        end
        local edges = {}
        for index = 1, 4 do
            local edge = borderOverlay:CreateTexture(nil, "OVERLAY", nil, 1)
            edge:SetTexture(DEFAULT_CAST_BAR_TEXTURE)
            if GUI2.ApplyTexturePixelPolicy then
                GUI2:ApplyTexturePixelPolicy(edge)
            end
            edges[index] = edge
        end
        local borderEdges = {
            top = edges[1],
            bottom = edges[2],
            left = edges[3],
            right = edges[4],
        }
        local cooldown = CreateFrame(
            "Cooldown",
            nil,
            host,
            "CooldownFrameTemplate"
        )
        cooldown:SetAllPoints(host)
        if cooldown.SetFrameLevel then cooldown:SetFrameLevel(hostLevel + 8) end
        if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(false) end
        if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
        if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
        if cooldown.SetHideCountdownNumbers then
            cooldown:SetHideCountdownNumbers(false)
        end
        if cooldown.SetMinimumCountdownDuration then
            cooldown:SetMinimumCountdownDuration(0)
        end
        if cooldown.SetCountdownMillisecondsThreshold then
            cooldown:SetCountdownMillisecondsThreshold(10)
        end
        cooldown:Hide()
        local mask
        if host.CreateMaskTexture then
            local ok, created = pcall(
                host.CreateMaskTexture,
                host,
                nil,
                "BACKGROUND"
            )
            if ok then
                mask = created
                mask:SetAllPoints(host)
                mask:SetTexture(RESOURCE_CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            end
        end
        host:Hide()
        local cell = {
            host = host,
            background = background,
            rechargeGate = rechargeGate,
            rechargeClip = rechargeClip,
            rechargeBar = rechargeBar,
            statusBar = statusBar,
            thresholdLow = thresholdLow,
            thresholdReset = thresholdReset,
            thresholdHigh = thresholdHigh,
            borderOverlay = borderOverlay,
            border = border,
            edges = edges,
            borderEdges = borderEdges,
            cooldown = cooldown,
            mask = mask,
            maskTargets = {},
        }
        ApplyResourceCellCooldownAppearance(frame, cell)
        return cell
    end

    local function DetachResourceCellMask(cell)
        local mask = cell and cell.mask
        if not mask then return end
        local targets = cell.maskTargets or {}
        for index = 1, #targets do
            local target = targets[index]
            if target and target.RemoveMaskTexture then
                pcall(target.RemoveMaskTexture, target, mask)
            end
            targets[index] = nil
        end
        if cell.background and cell.background.RemoveMaskTexture then
            pcall(cell.background.RemoveMaskTexture, cell.background, mask)
        end
        cell.maskTargets = targets
    end

    local function ApplyResourceCellMask(cell, enabled)
        DetachResourceCellMask(cell)
        if not enabled or not cell.mask then return end
        local statusBars = {
            cell.rechargeBar,
            cell.statusBar,
            cell.thresholdLow,
            cell.thresholdReset,
            cell.thresholdHigh,
        }
        local targets = cell.maskTargets or {}
        for index = 1, #statusBars do
            local statusBar = statusBars[index]
            local fill = statusBar and statusBar.GetStatusBarTexture
                and statusBar:GetStatusBarTexture() or nil
            if fill and fill.AddMaskTexture then
                pcall(fill.AddMaskTexture, fill, cell.mask)
                targets[#targets + 1] = fill
            end
        end
        cell.maskTargets = targets
        if cell.background and cell.background.AddMaskTexture then
            pcall(cell.background.AddMaskTexture, cell.background, cell.mask)
        end
    end

    local function LayoutResourceCellBorder(frame, cell, dots)
        local thickness = math_max(
            0,
            math_min(12, tonumber(frame.gui2ResourceBorder) or 0)
        )
        local r, g, b, a = ResourceColorComponents(
            frame.gui2ResourceBorderColor,
            { 0, 0, 0, 1 }
        )
        if dots then
            for index = 1, 4 do cell.edges[index]:Hide() end
            local materialThickness = math_max(
                1,
                math_min(4, math_floor(thickness + 0.5))
            )
            local path = RESOURCE_CIRCLE_BORDERS[materialThickness]
                or string.format(
                    "Interface\\AddOns\\YUI_AuctionHelper\\CoreEmbed\\Media\\Core\\gui2\\shapes\\circle-border-%d.tga",
                    materialThickness
                )
            cell.border:SetTexture(path)
            cell.border:SetVertexColor(r, g, b, a)
            cell.border:SetShown(thickness > 0)
            return
        end
        cell.border:Hide()
        local top, bottom, left, right =
            cell.edges[1], cell.edges[2], cell.edges[3], cell.edges[4]
        local borderPixels = math_max(1, thickness)
        if GUI2.LayoutPixelBorder then
            GUI2:LayoutPixelBorder(
                cell.borderEdges,
                cell.host,
                borderPixels,
                0,
                0
            )
        else
            local size = GUI2.GetPixelSize
                and GUI2:GetPixelSize(cell.host, borderPixels, borderPixels)
                or (borderPixels * (GUI2.mult or 1))
            top:ClearAllPoints(); top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(size)
            bottom:ClearAllPoints(); bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(size)
            left:ClearAllPoints(); left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(size)
            right:ClearAllPoints(); right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(size)
        end
        for index = 1, 4 do
            cell.edges[index]:SetVertexColor(r, g, b, a)
            cell.edges[index]:SetShown(thickness > 0)
        end
    end

    local function EnsureResourceCells(frame, count)
        frame.resourceCells = frame.resourceCells or {}
        for index = #frame.resourceCells + 1, count do
            frame.resourceCells[index] = CreateResourceCell(frame)
        end
    end

    local function CreateResourceSecretOverlayCell(frame)
        local host = CreateFrame("Frame", nil, frame.track)
        local baseLevel = frame.track.GetFrameLevel
            and (frame.track:GetFrameLevel() or 0) + 4 or 4
        if host.SetFrameLevel then host:SetFrameLevel(baseLevel) end
        local low = CreateResourceLayerStatusBar(host, baseLevel + 1)
        local reset = CreateResourceLayerStatusBar(host, baseLevel + 2)
        local high = CreateResourceLayerStatusBar(host, baseLevel + 3)
        host:Hide()
        return {
            host = host,
            thresholdLow = low,
            thresholdReset = reset,
            thresholdHigh = high,
        }
    end

    local function EnsureResourceSecretOverlayCells(frame, count)
        frame.resourceSecretOverlayCells =
            frame.resourceSecretOverlayCells or {}
        for index = #frame.resourceSecretOverlayCells + 1, count do
            frame.resourceSecretOverlayCells[index] =
                CreateResourceSecretOverlayCell(frame)
        end
    end

    local function CreateResourceRechargeCell(frame)
        local host = CreateFrame("Frame", nil, frame.track)
        local baseLevel = frame.track.GetFrameLevel
            and (frame.track:GetFrameLevel() or 0) + 1 or 1
        if host.SetFrameLevel then host:SetFrameLevel(baseLevel) end
        local rechargeGate, rechargeClip, rechargeBar =
            CreateResourceRechargeLayers(host, baseLevel)
        host:Hide()
        return {
            host = host,
            rechargeGate = rechargeGate,
            rechargeClip = rechargeClip,
            rechargeBar = rechargeBar,
        }
    end

    local function EnsureResourceRechargeCells(frame, count)
        frame.resourceRechargeCells = frame.resourceRechargeCells or {}
        for index = #frame.resourceRechargeCells + 1, count do
            frame.resourceRechargeCells[index] =
                CreateResourceRechargeCell(frame)
        end
    end

    local function HideResourceCellThresholdLayers(cell)
        if not cell then return end
        cell.thresholdLow:Hide()
        cell.thresholdReset:Hide()
        cell.thresholdHigh:Hide()
    end

    local function HideResourceSecretThresholdLayers(frame)
        for index = 1, #(frame.resourceCells or {}) do
            HideResourceCellThresholdLayers(frame.resourceCells[index])
        end
        for index = 1, #(frame.resourceSecretOverlayCells or {}) do
            HideResourceCellThresholdLayers(
                frame.resourceSecretOverlayCells[index]
            )
        end
    end

    local function SetResourceThresholdLayer(
        statusBar,
        minimum,
        maximum,
        valueRaw,
        color
    )
        local minOK = pcall(
            statusBar.SetMinMaxValues,
            statusBar,
            minimum,
            maximum
        )
        local valueOK = pcall(
            statusBar.SetValue,
            statusBar,
            valueRaw
        )
        local r, g, b, a = ResourceColorComponents(
            color,
            { 1, 1, 1, 1 }
        )
        SetResourceStatusBarColor(statusBar, r, g, b, a)
        statusBar:SetShown(minOK and valueOK)
        return minOK and valueOK
    end

    local function ApplyResourceChargedPointColors(frame, value, mask)
        mask = tonumber(mask)
        if not mask or mask <= 0 then return false end
        local config = frame.gui2ResourceDisplayConfig or {}
        local cellsMode = config.mode == "cells" or config.mode == "dots"
        local cells = cellsMode and frame.resourceCells
            or frame.resourceSecretOverlayCells
        local count = cellsMode and (frame.gui2ResourceActiveCellCount or 0)
            or math_max(1, math_min(
                MAX_RESOURCE_CELLS,
                tonumber(config.segmentCount) or 1
            ))
        local r, g, b, a = ResourceColorComponents(
            config.chargedPointColor,
            { 0.44, 0.77, 1.00, 1 }
        )
        local applied = false
        for index = 1, count do
            local cell = cells and cells[index]
            local layer = cell and cell.thresholdHigh
            local weight = 2 ^ (index - 1)
            local charged = math_floor(mask / weight) % 2 == 1
            if layer and charged then
                layer:SetMinMaxValues(0, 1)
                layer:SetValue(1)
                SetResourceStatusBarColor(
                    layer,
                    r,
                    g,
                    b,
                    a * (index <= value and 1 or 0.45)
                )
                layer:Show()
                applied = true
            elseif layer then
                layer:Hide()
            end
        end
        return applied
    end

    local function ApplyResourceSecretThresholdCell(
        frame,
        cell,
        cellIndex,
        valueRaw,
        thresholdColorEnabled,
        rechargeActive
    )
        local config = frame.gui2ResourceDisplayConfig or {}
        local thresholds = config.thresholds or {}
        local low = thresholds.low
        local high = thresholds.high
        local applied = false
        if thresholdColorEnabled ~= true then
            cell.thresholdLow:Hide()
            cell.thresholdReset:Hide()
            cell.thresholdHigh:Hide()
            return applied
        end
        if type(low) == "table" and low.enabled == true then
            local lowValue = tonumber(low.value) or 0
            applied = SetResourceThresholdLayer(
                cell.thresholdLow,
                cellIndex - 1,
                cellIndex,
                valueRaw,
                low.color
            ) or applied
            local resetAt = math_max(
                cellIndex,
                lowValue + (rechargeActive == true and 0 or 1)
            )
            applied = SetResourceThresholdLayer(
                cell.thresholdReset,
                resetAt - 1,
                resetAt,
                valueRaw,
                frame.gui2ResourceFillColor
            ) or applied
        else
            cell.thresholdLow:Hide()
            cell.thresholdReset:Hide()
        end
        if type(high) == "table" and high.enabled == true then
            local highAt = math_max(
                cellIndex,
                tonumber(high.value) or 0
            )
            applied = SetResourceThresholdLayer(
                cell.thresholdHigh,
                highAt - 1,
                highAt,
                valueRaw,
                high.color
            ) or applied
        else
            cell.thresholdHigh:Hide()
        end
        return applied
    end

    local function ApplyResourceSecretThresholds(
        frame,
        valueRaw,
        rechargeActive
    )
        local config = frame.gui2ResourceDisplayConfig or {}
        if config.valueKind ~= "discrete" then
            HideResourceSecretThresholdLayers(frame)
            return false
        end
        local cellsMode = config.mode == "cells" or config.mode == "dots"
        if not cellsMode and config.thresholdColorEnabled ~= true then
            -- The continuous/divided StatusBar accepts secret values natively.
            -- Do not replace its one continuous fill with N per-cell copies.
            HideResourceSecretThresholdLayers(frame)
            return false
        end
        local cells = cellsMode and frame.resourceCells
            or frame.resourceSecretOverlayCells
        local count = math_max(1, tonumber(config.segmentCount) or 1)
        local applied = false
        for index = 1, count do
            applied = ApplyResourceSecretThresholdCell(
                frame,
                cells[index],
                index,
                valueRaw,
                config.thresholdColorEnabled,
                rechargeActive
            ) or applied
        end
        return applied
    end

    local function EnsureResourceLine(frame, index)
        frame.resourceLines = frame.resourceLines or {}
        local line = frame.resourceLines[index]
        if not line then
            line = frame.resourceDecorationOverlay:CreateTexture(nil, "OVERLAY")
            line:SetTexture(DEFAULT_CAST_BAR_TEXTURE)
            frame.resourceLines[index] = line
        end
        return line
    end

    local function HideResourceLines(frame)
        for index = 1, #(frame.resourceLines or {}) do
            frame.resourceLines[index]:Hide()
        end
    end

    local function BuildResourceLogicalMetrics(frame, count, totalMainPixels)
        count = math_max(1, math_min(MAX_RESOURCE_CELLS, tonumber(count) or 1))
        totalMainPixels = math_max(
            count,
            math_floor((tonumber(totalMainPixels) or count) + 0.5)
        )
        local reverse = frame.gui2ResourceFillDirection == "reverse"
        local cache = frame.gui2ResourceLogicalMetrics
        if cache and cache.count == count
            and cache.totalMainPixels == totalMainPixels
            and cache.reverse == reverse then
            return cache
        end
        cache = cache or { cells = {} }
        cache.count = count
        cache.totalMainPixels = totalMainPixels
        cache.reverse = reverse
        local cells = cache.cells
        for index = 1, count do
            local positionIndex = reverse and (count - index + 1) or index
            local startPixels = math_floor(
                ((totalMainPixels * (positionIndex - 1)) / count) + 0.5
            )
            local endPixels = math_floor(
                ((totalMainPixels * positionIndex) / count) + 0.5
            )
            local cell = cells[index] or {}
            cell.positionIndex = positionIndex
            cell.offsetPixels = startPixels
            cell.mainPixels = math_max(1, endPixels - startPixels)
            cells[index] = cell
        end
        for index = count + 1, #cells do cells[index] = nil end
        frame.gui2ResourceLogicalMetrics = cache
        return cache
    end

    local function GetResourceLogicalBoundaryPixels(frame, logicalIndex)
        local metrics = frame.gui2ResourceLogicalMetrics
        logicalIndex = tonumber(logicalIndex)
        if not metrics or not logicalIndex then return nil end
        if logicalIndex <= 0 then
            return metrics.reverse and metrics.totalMainPixels or 0
        end
        if logicalIndex >= metrics.count then
            return metrics.reverse and 0 or metrics.totalMainPixels
        end
        local cell = metrics and metrics.cells[logicalIndex]
        if not cell then return nil end
        if metrics.reverse then return cell.offsetPixels end
        return cell.offsetPixels + cell.mainPixels
    end

    local function PlaceResourceLine(
        frame,
        line,
        ratio,
        thickness,
        color,
        boundaryPixels,
        kind
    )
        ratio = math_max(0, math_min(1, tonumber(ratio) or 0))
        local offset
        if type(boundaryPixels) == "number" then
            offset = boundaryPixels
                * (frame.gui2ResourceSegmentPixelSize or (GUI2.mult or 1))
        else
            if frame.gui2ResourceFillDirection == "reverse" then
                ratio = 1 - ratio
            end
            offset = (frame.gui2ResourceOrientation == "vertical"
                and frame.gui2ResourceHeight or frame.gui2ResourceWidth) * ratio
        end
        local r, g, b, a = ResourceColorComponents(color, { 0, 0, 0, 1 })
        local size = math_max(1, (tonumber(thickness) or 1) * (GUI2.mult or 1))
        local vertical = frame.gui2ResourceOrientation == "vertical"
        local axisSize = vertical
            and (frame.track.GetHeight and frame.track:GetHeight()
                or frame.gui2ResourceHeight)
            or (frame.track.GetWidth and frame.track:GetWidth()
                or frame.gui2ResourceWidth)
        axisSize = tonumber(axisSize) or 0
        local atStart = offset - (size * 0.5) <= 0
        local atEnd = axisSize > 0 and offset + (size * 0.5) >= axisSize
        line:ClearAllPoints()
        if vertical then
            if atStart then
                line:SetPoint("BOTTOMLEFT", frame.track, "BOTTOMLEFT", 0, 0)
                line:SetPoint("BOTTOMRIGHT", frame.track, "BOTTOMRIGHT", 0, 0)
            elseif atEnd then
                line:SetPoint("TOPLEFT", frame.track, "TOPLEFT", 0, 0)
                line:SetPoint("TOPRIGHT", frame.track, "TOPRIGHT", 0, 0)
            else
                line:SetPoint("LEFT", frame.track, "BOTTOMLEFT", 0, offset)
                line:SetPoint("RIGHT", frame.track, "BOTTOMRIGHT", 0, offset)
            end
            line:SetHeight(size)
        else
            if atStart then
                line:SetPoint("TOPLEFT", frame.track, "TOPLEFT", 0, 0)
                line:SetPoint("BOTTOMLEFT", frame.track, "BOTTOMLEFT", 0, 0)
            elseif atEnd then
                line:SetPoint("TOPRIGHT", frame.track, "TOPRIGHT", 0, 0)
                line:SetPoint("BOTTOMRIGHT", frame.track, "BOTTOMRIGHT", 0, 0)
            else
                line:SetPoint("BOTTOM", frame.track, "BOTTOMLEFT", offset, 0)
                line:SetPoint("TOP", frame.track, "TOPLEFT", offset, 0)
            end
            line:SetWidth(size)
        end
        line.gui2ResourceLineKind = kind
        line:SetVertexColor(r, g, b, a)
        line:Show()
    end

    local function LayoutResourceDecorations(frame)
        HideResourceLines(frame)
        local config = frame.gui2ResourceDisplayConfig or {}
        local count = math_max(1, tonumber(config.segmentCount) or 1)
        local writeIndex = 0
        if config.mode == "divided" and count > 1 then
            for index = 1, count - 1 do
                writeIndex = writeIndex + 1
                PlaceResourceLine(
                    frame,
                    EnsureResourceLine(frame, writeIndex),
                    index / count,
                    config.dividerThickness,
                    config.dividerColor,
                    GetResourceLogicalBoundaryPixels(frame, index),
                    "divider"
                )
            end
        end
        if config.thresholdMarkerEnabled == true
            and config.mode ~= "cells" and config.mode ~= "dots" then
            local thresholds = config.thresholds or {}
            local function AddThreshold(threshold)
                if type(threshold) ~= "table" or threshold.enabled ~= true then return end
                local divisor = config.valueKind == "discrete" and count or 100
                if divisor <= 0 then return end
                writeIndex = writeIndex + 1
                PlaceResourceLine(
                    frame,
                    EnsureResourceLine(frame, writeIndex),
                    (tonumber(threshold.value) or 0) / divisor,
                    config.thresholdMarkerThickness,
                    config.thresholdMarkerColor,
                    config.valueKind == "discrete"
                        and GetResourceLogicalBoundaryPixels(
                            frame,
                            math_max(
                                0,
                                math_min(
                                    count,
                                    math_floor(
                                        (tonumber(threshold.value) or 0) + 0.5
                                    )
                                )
                            )
                        ) or nil,
                    "threshold"
                )
            end
            AddThreshold(thresholds.low)
            AddThreshold(thresholds.high)
        end
        frame.gui2ResourceActiveLineCount = writeIndex
    end

    local function ConfigureResourceLayerBar(frame, statusBar, vertical)
        EnsureResourceStatusBarFillStyle(frame, statusBar, false)
    end

    local RESOURCE_SOLID_OVERLAY_STYLE = {
        texture = DEFAULT_CAST_BAR_TEXTURE,
        textureU0 = 0,
        textureU1 = 1,
        textureV0 = 0,
        textureV1 = 1,
    }
    local RESOURCE_RECHARGE_ALPHA = 0.5

    local function ConfigureResourceSolidOverlay(frame, statusBar, force)
        if not (statusBar and GUI2.ApplyNativeStatusBarStyle) then
            return false
        end
        return GUI2:ApplyNativeStatusBarStyle(
            statusBar,
            RESOURCE_SOLID_OVERLAY_STYLE,
            frame.gui2ResourceOrientation,
            frame.gui2ResourceFillDirection,
            force == true
        ) > 0
    end

    local function ConfigureResourceCellLayers(frame, cell, vertical)
        ConfigureResourceLayerBar(frame, cell.rechargeGate, vertical)
        ConfigureResourceLayerBar(frame, cell.rechargeBar, vertical)
        ConfigureResourceLayerBar(frame, cell.statusBar, vertical)
        ConfigureResourceLayerBar(frame, cell.thresholdLow, vertical)
        ConfigureResourceLayerBar(frame, cell.thresholdReset, vertical)
        ConfigureResourceLayerBar(frame, cell.thresholdHigh, vertical)
        local fr, fg, fb, fa = ResourceColorComponents(
            frame.gui2ResourceFillColor,
            { 1, 1, 1, 1 }
        )
        SetResourceStatusBarColor(
            cell.rechargeBar,
            fr,
            fg,
            fb,
            fa * RESOURCE_RECHARGE_ALPHA
        )
    end

    local function ResourceRechargeColor(frame, cellIndex)
        local config = frame.gui2ResourceDisplayConfig or {}
        if config.thresholdColorEnabled == true then
            local thresholds = config.thresholds or {}
            local low = thresholds.low
            local high = thresholds.high
            if type(low) == "table" and low.enabled == true
                and cellIndex <= (tonumber(low.value) or 0) then
                return low.color
            end
            if type(high) == "table" and high.enabled == true
                and cellIndex > (tonumber(high.value) or 0) then
                return high.color
            end
        end
        return frame.gui2ResourceFillColor
    end

    local function ApplyResourceRechargeColor(frame, cell, cellIndex)
        if not (cell and cell.rechargeBar) then return end
        local r, g, b, a = ResourceColorComponents(
            ResourceRechargeColor(frame, cellIndex),
            { 1, 1, 1, 1 }
        )
        SetResourceStatusBarColor(
            cell.rechargeBar,
            r,
            g,
            b,
            a * RESOURCE_RECHARGE_ALPHA
        )
    end

    local function LayoutResourceRechargeGate(frame, cell, cellIndex, vertical)
        local gate = cell and cell.rechargeGate
        local clip = cell and cell.rechargeClip
        local rechargeBar = cell and cell.rechargeBar
        if not (gate and clip and rechargeBar and cell.host) then return false end
        ConfigureResourceLayerBar(frame, gate, vertical)
        ConfigureResourceLayerBar(frame, rechargeBar, vertical)
        gate:ClearAllPoints()
        gate:SetAllPoints(cell.host)
        if cellIndex == 1 then
            gate:SetMinMaxValues(0, 1)
            gate:SetValue(1)
        else
            gate:SetMinMaxValues(cellIndex - 2, cellIndex - 1)
            gate:SetValue(0)
        end
        gate:SetAlpha(0)
        gate:Show()

        rechargeBar:ClearAllPoints()
        rechargeBar:SetAllPoints(cell.host)
        local fill = gate.GetStatusBarTexture and gate:GetStatusBarTexture()
        clip:ClearAllPoints()
        if not fill then
            clip:Hide()
            return false
        end
        local reverse = frame.gui2ResourceFillDirection == "reverse"
        if vertical then
            if reverse then
                clip:SetPoint("TOPLEFT", cell.host, "TOPLEFT", 0, 0)
                clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
            else
                clip:SetPoint("BOTTOMLEFT", cell.host, "BOTTOMLEFT", 0, 0)
                clip:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
            end
        elseif reverse then
            clip:SetPoint("TOPRIGHT", cell.host, "TOPRIGHT", 0, 0)
            clip:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
        else
            clip:SetPoint("TOPLEFT", cell.host, "TOPLEFT", 0, 0)
            clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
        end
        ApplyResourceRechargeColor(frame, cell, cellIndex)
        return true
    end

    local function LayoutResourceRechargeCells(
        frame,
        count,
        vertical,
        pixelSize,
        logicalMetrics,
        crossPixels
    )
        if count < 1 then
            for index = 1, #(frame.resourceRechargeCells or {}) do
                local cell = frame.resourceRechargeCells[index]
                cell.rechargeBar:Hide()
                cell.rechargeClip:Hide()
                cell.host:Hide()
            end
            return
        end
        EnsureResourceRechargeCells(frame, count)
        for index = 1, #(frame.resourceRechargeCells or {}) do
            local cell = frame.resourceRechargeCells[index]
            if index <= count then
                local metric = logicalMetrics
                    and logicalMetrics.cells[index]
                local mainPixels = metric and metric.mainPixels or 1
                local offsetPixels = metric and metric.offsetPixels or 0
                cell.host:ClearAllPoints()
                cell.host:SetPoint("BOTTOMLEFT", frame.track, "BOTTOMLEFT",
                    vertical and 0 or (offsetPixels * pixelSize),
                    vertical and (offsetPixels * pixelSize) or 0)
                local width = (vertical and crossPixels or mainPixels) * pixelSize
                local height = (vertical and mainPixels or crossPixels) * pixelSize
                if not (GUI2.SetPixelSnappedSize
                    and GUI2:SetPixelSnappedSize(
                        cell.host,
                        width,
                        height,
                        1,
                        1
                    )) then
                    cell.host:SetSize(width, height)
                end
                LayoutResourceRechargeGate(frame, cell, index, vertical)
                cell.host:Show()
            else
                cell.rechargeBar:Hide()
                cell.rechargeClip:Hide()
                cell.host:Hide()
            end
        end
    end

    local function LayoutResourceSecretOverlayCells(
        frame,
        count,
        vertical,
        pixelSize,
        logicalMetrics,
        crossPixels
    )
        if count < 1 then
            for index = 1, #(frame.resourceSecretOverlayCells or {}) do
                local cell = frame.resourceSecretOverlayCells[index]
                HideResourceCellThresholdLayers(cell)
                cell.host:Hide()
            end
            return
        end
        EnsureResourceSecretOverlayCells(frame, count)
        for index = 1, #(frame.resourceSecretOverlayCells or {}) do
            local cell = frame.resourceSecretOverlayCells[index]
            if index <= count then
                local metric = logicalMetrics
                    and logicalMetrics.cells[index]
                local mainPixels = metric and metric.mainPixels or 1
                local offsetPixels = metric and metric.offsetPixels or 0
                cell.host:ClearAllPoints()
                cell.host:SetPoint("BOTTOMLEFT", frame.track, "BOTTOMLEFT",
                    vertical and 0 or (offsetPixels * pixelSize),
                    vertical and (offsetPixels * pixelSize) or 0)
                local width = (vertical and crossPixels or mainPixels) * pixelSize
                local height = (vertical and mainPixels or crossPixels) * pixelSize
                if not (GUI2.SetPixelSnappedSize
                    and GUI2:SetPixelSnappedSize(
                        cell.host,
                        width,
                        height,
                        1,
                        1
                    )) then
                    cell.host:SetSize(width, height)
                end
                ConfigureResourceSolidOverlay(frame, cell.thresholdLow)
                ConfigureResourceSolidOverlay(frame, cell.thresholdReset)
                ConfigureResourceSolidOverlay(frame, cell.thresholdHigh)
                cell.host:Show()
            else
                HideResourceCellThresholdLayers(cell)
                cell.host:Hide()
            end
        end
    end

    local function LayoutResourceCells(frame)
        local config = frame.gui2ResourceDisplayConfig or {}
        local mode = config.mode
        local cellsMode = mode == "cells" or mode == "dots"
        local count = cellsMode and math_max(
            1,
            math_min(MAX_RESOURCE_CELLS, tonumber(config.segmentCount) or 1)
        ) or 0
        EnsureResourceCells(frame, count)
        frame.gui2ResourceActiveCellCount = count
        if frame.SetNativeFillShown then
            frame:SetNativeFillShown(not cellsMode)
        else
            frame.resourceStatusBar:SetShown(not cellsMode)
        end
        local vertical = frame.gui2ResourceOrientation == "vertical"
        local logicalCount = math_max(
            1,
            math_min(MAX_RESOURCE_CELLS, tonumber(config.segmentCount) or 1)
        )
        local trackWidth = frame.track.GetWidth and frame.track:GetWidth()
        local trackHeight = frame.track.GetHeight and frame.track:GetHeight()
        if type(trackWidth) ~= "number" or trackWidth <= 0 then
            trackWidth = frame.gui2ResourceWidth
        end
        if type(trackHeight) ~= "number" or trackHeight <= 0 then
            trackHeight = frame.gui2ResourceHeight
        end
        local pixelSize = GUI2.GetPixelSize
            and GUI2:GetPixelSize(frame.track, 1, 1)
            or (GUI2.mult or 1)
        local totalMain = vertical and trackHeight or trackWidth
        local cross = vertical and trackWidth or trackHeight
        local totalMainPixels = math_max(
            math_max(count, logicalCount),
            math_floor((totalMain / pixelSize) + 0.5)
        )
        local crossPixels = math_max(
            1,
            math_floor((cross / pixelSize) + 0.5)
        )
        local logicalMetrics = BuildResourceLogicalMetrics(
            frame,
            logicalCount,
            totalMainPixels
        )
        frame.gui2ResourceSegmentPixelSize = pixelSize
        frame.resourceRechargeBar:Hide()
        LayoutResourceSecretOverlayCells(
            frame,
            cellsMode and 0 or logicalCount,
            vertical,
            pixelSize,
            logicalMetrics,
            crossPixels
        )
        LayoutResourceRechargeCells(
            frame,
            cellsMode and 0 or logicalCount,
            vertical,
            pixelSize,
            logicalMetrics,
            crossPixels
        )
        local spacingPixels = math_floor(
            (tonumber(config.segmentSpacing) or 0) + 0.5
        )
        if mode ~= "cells" then
            spacingPixels = math_max(0, spacingPixels)
        end
        local actualSpacingPixels = spacingPixels
        if count > 1 and spacingPixels > 0 then
            local maximumSpacingPixels = math_max(
                0,
                math_floor((totalMainPixels - count) / (count - 1))
            )
            actualSpacingPixels = math_min(
                spacingPixels,
                maximumSpacingPixels
            )
        end
        local availableMainPixels = math_max(
            count,
            totalMainPixels
                - (actualSpacingPixels * math_max(0, count - 1))
        )
        local baseCellPixels = count > 0
            and math_floor(availableMainPixels / count)
            or availableMainPixels
        local dots = mode == "dots"
        local dotPixels = dots and math_min(baseCellPixels, crossPixels) or 0
        for index = 1, #(frame.resourceCells or {}) do
            local cell = frame.resourceCells[index]
            if index <= count then
                local positionIndex = frame.gui2ResourceFillDirection == "reverse"
                    and (count - index + 1) or index
                local mainSizePixels
                local mainOffsetPixels
                if dots then
                    mainSizePixels = dotPixels
                    mainOffsetPixels = count > 1
                        and math_floor(
                            (((positionIndex - 1)
                                * (totalMainPixels - dotPixels))
                                / (count - 1)) + 0.5
                        )
                        or math_floor((totalMainPixels - dotPixels) * 0.5)
                else
                    local startPixels = math_floor(
                        ((availableMainPixels * (positionIndex - 1)) / count)
                            + 0.5
                    )
                    local endPixels = math_floor(
                        ((availableMainPixels * positionIndex) / count) + 0.5
                    )
                    mainSizePixels = math_max(1, endPixels - startPixels)
                    mainOffsetPixels = startPixels
                        + ((positionIndex - 1) * actualSpacingPixels)
                end
                local crossSizePixels = dots and mainSizePixels or crossPixels
                local crossOffsetPixels = math_floor(
                    ((crossPixels - crossSizePixels) * 0.5) + 0.5
                )
                local mainSize = mainSizePixels * pixelSize
                local crossSize = crossSizePixels * pixelSize
                local mainOffset = mainOffsetPixels * pixelSize
                local crossOffset = crossOffsetPixels * pixelSize
                cell.gui2ResourceMainOffsetPixels = mainOffsetPixels
                cell.gui2ResourceMainPixels = mainSizePixels
                cell.gui2ResourceCrossOffsetPixels = crossOffsetPixels
                cell.gui2ResourceCrossPixels = crossSizePixels
                cell.host:ClearAllPoints()
                if vertical then
                    cell.host:SetPoint(
                        "BOTTOMLEFT",
                        frame.track,
                        "BOTTOMLEFT",
                        crossOffset,
                        mainOffset
                    )
                    if not (GUI2.SetPixelSnappedSize
                        and GUI2:SetPixelSnappedSize(
                            cell.host,
                            crossSize,
                            mainSize,
                            1,
                            1
                        )) then
                        cell.host:SetSize(crossSize, mainSize)
                    end
                else
                    cell.host:SetPoint(
                        "BOTTOMLEFT",
                        frame.track,
                        "BOTTOMLEFT",
                        mainOffset,
                        crossOffset
                    )
                    if not (GUI2.SetPixelSnappedSize
                        and GUI2:SetPixelSnappedSize(
                            cell.host,
                            mainSize,
                            crossSize,
                            1,
                            1
                        )) then
                        cell.host:SetSize(mainSize, crossSize)
                    end
                end
                if config.independentCells == true then
                    cell.statusBar:SetMinMaxValues(0, 1)
                else
                    cell.statusBar:SetMinMaxValues(index - 1, index)
                end
                local br, bg, bb, ba = ResourceColorComponents(
                    frame.gui2ResourceBackgroundColor,
                    { 0, 0, 0, 0.92 }
                )
                cell.background:SetVertexColor(br, bg, bb, ba)
                ConfigureResourceCellLayers(frame, cell, vertical)
                if config.independentCells ~= true then
                    LayoutResourceRechargeGate(frame, cell, index, vertical)
                end
                ApplyResourceCellMask(cell, dots)
                LayoutResourceCellBorder(frame, cell, dots)
                cell.statusBar:Show()
                cell.host:Show()
            else
                DetachResourceCellMask(cell)
                cell.rechargeBar:Hide()
                cell.rechargeClip:Hide()
                HideResourceCellThresholdLayers(cell)
                cell.host:Hide()
            end
        end
        ApplyResourceBorder(frame, cellsMode and 0 or frame.gui2ResourceBorder)
        if frame.track and frame.track.SetBackdropColor then
            if cellsMode then
                frame.track:SetBackdropColor(0, 0, 0, 0)
            else
                local r, g, b, a = ResourceColorComponents(
                    frame.gui2ResourceBackgroundColor,
                    { 0, 0, 0, 0.92 }
                )
                frame.track:SetBackdropColor(r, g, b, a)
            end
        end
        if not ApplyResourcePublicValues(frame) then
            ApplyResourceBaseColor(frame)
        end
        LayoutResourceDecorations(frame)
        if config.timerMarkers == true
            and frame.gui2ResourceTimerMarkerCount
            and frame.gui2ResourceTimerMarkerCount > 0 then
            StartResourceTimerMarkers(
                frame,
                frame.gui2ResourceTimerEntries
            )
        end
        if frame.gui2ResourcePartialRechargeActive == true then
            RefreshResourcePartialRecharge(frame)
        end
    end

    local function HideResourceRecharge(frame)
        if frame.resourceRechargeBar then
            frame.resourceRechargeBar:Hide()
        end
        for index = 1, #(frame.resourceRechargeCells or {}) do
            local cell = frame.resourceRechargeCells[index]
            cell.rechargeBar:Hide()
            cell.rechargeClip:Hide()
        end
        for index = 1, #(frame.resourceCells or {}) do
            local cell = frame.resourceCells[index]
            cell.rechargeBar:Hide()
            cell.rechargeClip:Hide()
        end
        frame.gui2ResourceRechargeTimerBound = false
    end

    local function SetResourceRechargeTimer(frame, statusBar, durationObject)
        if not (statusBar and durationObject and statusBar.SetTimerDuration) then
            return false
        end
        if statusBar.gui2ProjectedOwner
            and statusBar.gui2ProjectedOwner.RefreshProjectedDriverStyle then
            statusBar.gui2ProjectedOwner:RefreshProjectedDriverStyle(true)
        end
        EnsureResourceStatusBarFillStyle(frame, statusBar, false)
        local ok = pcall(
            statusBar.SetTimerDuration,
            statusBar,
            durationObject,
            GetStatusBarImmediateInterpolation(),
            GetCastTimerDirection(false)
        ) == true
        if not ok then return false end
        RestoreResourceStatusBarColor(statusBar)
        return ok
    end

    local function ApplyIndependentResourceCells(
        frame,
        value,
        maxValue,
        readyCells,
        durationCells
    )
        local count = frame.gui2ResourceActiveCellCount or 0
        if count <= 0 or type(readyCells) ~= "table"
            or type(durationCells) ~= "table" then
            return false
        end
        HideResourceRecharge(frame)
        HideResourceSecretThresholdLayers(frame)
        frame.gui2ResourceHasPublicValues = false
        frame.gui2ResourcePublicValue = nil
        frame.gui2ResourcePublicMaxValue = nil
        ApplyResourceBaseColor(frame)
        for index = 1, count do
            local cell = frame.resourceCells[index]
            local statusBar = cell and cell.statusBar
            if not statusBar then return false end
            statusBar:SetMinMaxValues(0, 1)
            if readyCells[index] == true then
                cell.rechargeBar:Hide()
                cell.rechargeClip:Hide()
                statusBar:SetValue(1)
                if cell.cooldown then
                    if cell.cooldown.Clear then
                        cell.cooldown:Clear()
                    elseif cell.cooldown.SetCooldown then
                        cell.cooldown:SetCooldown(0, 0)
                    end
                    cell.cooldown:Hide()
                end
            else
                statusBar:SetValue(0)
                local timerState = durationCells[index]
                local durationObject = timerState
                if type(timerState) == "table"
                    and timerState.durationObject ~= nil then
                    durationObject = timerState.durationObject
                end
                local rechargeBound = false
                if durationObject then
                    cell.rechargeClip:ClearAllPoints()
                    cell.rechargeClip:SetAllPoints(cell.host)
                    cell.rechargeBar:ClearAllPoints()
                    cell.rechargeBar:SetAllPoints(cell.host)
                    rechargeBound = SetResourceRechargeTimer(
                        frame,
                        cell.rechargeBar,
                        durationObject
                    )
                end
                cell.rechargeBar:SetShown(rechargeBound == true)
                cell.rechargeClip:SetShown(rechargeBound == true)
                if not rechargeBound and cell.cooldown and cell.cooldown.Clear then
                    cell.cooldown:Clear()
                end
                local startTime = type(timerState) == "table"
                    and tonumber(
                        timerState.countdownStartTime
                            or timerState.startTime
                    ) or nil
                local duration = type(timerState) == "table"
                    and tonumber(
                        timerState.countdownDuration
                            or timerState.duration
                    ) or nil
                local cooldownBound = startTime ~= nil
                    and duration ~= nil
                    and duration > 0
                    and cell.cooldown
                    and cell.cooldown.SetCooldown
                    and pcall(
                        cell.cooldown.SetCooldown,
                        cell.cooldown,
                        startTime,
                        duration
                    ) == true
                if not cooldownBound then
                    cooldownBound = durationObject ~= nil
                        and cell.cooldown
                        and cell.cooldown.SetCooldownFromDurationObject
                        and pcall(
                            cell.cooldown.SetCooldownFromDurationObject,
                            cell.cooldown,
                            durationObject,
                            true
                        ) == true
                end
                if cell.cooldown then
                    cell.cooldown:SetShown(cooldownBound == true)
                end
            end
        end
        ApplyResourcePublicThresholdColor(
            frame,
            type(value) == "number" and value or 0,
            type(maxValue) == "number" and maxValue or count,
            false
        )
        return true
    end

    local function ApplyResourceDuration(frame, durationObject)
        local statusBar = frame.resourceStatusBar
        if not (durationObject and statusBar and statusBar.SetTimerDuration) then
            if frame.resourceDurationCountdown then
                frame.resourceDurationCountdown:Hide()
            end
            return false
        end
        if statusBar.gui2ProjectedOwner
            and statusBar.gui2ProjectedOwner.RefreshProjectedDriverStyle then
            statusBar.gui2ProjectedOwner:RefreshProjectedDriverStyle(true)
        end
        EnsureResourceStatusBarFillStyle(frame, statusBar, false)
        local interpolation = GetStatusBarProgressInterpolation(
            frame.gui2ResourceSmoothProgress,
            frame.gui2ResourceDurationBound
        )
        local ok = pcall(
            statusBar.SetTimerDuration,
            statusBar,
            durationObject,
            interpolation,
            GetCastTimerDirection(true)
        ) == true
        if ok then
            frame.gui2ResourceDurationBound = true
            RestoreResourceStatusBarColor(statusBar)
            if frame.SetNativeFillShown then
                frame:SetNativeFillShown(true)
            end
        end
        local countdown = frame.resourceDurationCountdown
        local countdownOK = countdown
            and countdown.SetCooldownFromDurationObject
            and pcall(
                countdown.SetCooldownFromDurationObject,
                countdown,
                durationObject,
                true
            ) == true
        if countdown then countdown:SetShown(countdownOK == true) end
        return ok
    end

    local function ApplyResourceRecharge(
        frame,
        durationObject,
        rechargeActive,
        secret,
        valueRaw,
        value
    )
        local config = frame.gui2ResourceDisplayConfig or {}
        if config.rechargeProgress ~= true or rechargeActive ~= true
            or not durationObject then
            HideResourceRecharge(frame)
            frame.gui2ResourceRechargeFailure = nil
            frame.gui2ResourceRechargeNeedsRetry = false
            frame.gui2ResourceRechargeRetryAttempted = false
            return false
        end
        local cellsMode = config.mode == "cells" or config.mode == "dots"
        local cells = cellsMode and frame.resourceCells
            or frame.resourceRechargeCells
        local count = math_max(
            1,
            math_min(MAX_RESOURCE_CELLS, tonumber(config.segmentCount) or 1)
        )
        if frame.resourceRechargeBar then frame.resourceRechargeBar:Hide() end
        local gateValue
        if secret == true then
            gateValue = valueRaw
        else
            gateValue = tonumber(value) or 0
        end
        local allBound = count > 0
        for index = 1, count do
            local cell = cells and cells[index]
            local gate = cell and cell.rechargeGate
            local gateOK = gate ~= nil and pcall(
                gate.SetValue,
                gate,
                index == 1 and 1 or gateValue
            ) == true
            local timerOK = gateOK
                and SetResourceRechargeTimer(
                    frame,
                    cell.rechargeBar,
                    durationObject
                )
            if cell then
                if timerOK then
                    ApplyResourceRechargeColor(frame, cell, index)
                end
                cell.rechargeBar:SetShown(timerOK)
                cell.rechargeClip:SetShown(timerOK)
            end
            allBound = allBound and timerOK == true
        end
        frame.gui2ResourceRechargeTimerBound = allBound
        if allBound then
            frame.gui2ResourceRechargeFailure = nil
            frame.gui2ResourceRechargeNeedsRetry = false
            frame.gui2ResourceRechargeRetryAttempted = false
        else
            frame.gui2ResourceRechargeFailure = "timer-unbound"
            if frame.gui2ResourceRechargeRetryAttempted ~= true then
                frame.gui2ResourceRechargeRetryAttempted = true
                frame.gui2ResourceRechargeNeedsRetry = true
            end
            HideResourceRecharge(frame)
        end
        return allBound
    end

    function App:CreateResourceBar(parent, opts)
        opts = type(opts) == "table" and opts or {}
        if not (GUI2.Data and GUI2.Data.CreateProgressBar) then
            return nil
        end

        local orientation = opts.orientation == "vertical"
            and "vertical" or "horizontal"
        local width = tonumber(opts.width)
            or (orientation == "vertical" and 16 or 290)
        local height = tonumber(opts.height)
            or (orientation == "vertical" and 120 or 16)
        local reverse = opts.fillDirection == "reverse"
        local frame = GUI2.Data:CreateProgressBar(parent, {
            orientation = orientation,
            width = width,
            height = height,
            value = 0,
            fillTexture = opts.fillTexture or opts.statusBarTexture,
            fillColor = opts.fillColor or "color.accent.primary",
            fillDirection = orientation == "vertical"
                and (reverse and "down" or "up")
                or (reverse and "right" or "left"),
            projectedFill = true,
            nativeBorder = false,
            animate = false,
            motion = false,
        })
        if not frame then return nil end

        frame.gui2Component = "ResourceBar"
        frame.gui2ResourceWidth = width
        frame.gui2ResourceHeight = height
        frame.gui2ResourceOrientation = orientation
        frame.gui2ResourceFillDirection =
            reverse and "reverse" or "forward"
        frame.gui2ResourceFillTexture =
            opts.fillTexture or opts.statusBarTexture
        frame.gui2ResourceFillTextureU0 = 0
        frame.gui2ResourceFillTextureU1 = 1
        frame.gui2ResourceFillTextureV0 = 0
        frame.gui2ResourceFillTextureV1 = 1
        frame.gui2ResourceFillStyleRevision = 1
        frame.gui2ResourceFillColor =
            opts.fillColor or "color.accent.primary"
        frame.gui2ResourceBorder = opts.border or "thin"
        frame.gui2ResourceBorderColor = opts.borderColor
            or { r = 0, g = 0, b = 0, a = 1 }
        frame.gui2ResourceBackgroundColor = opts.backgroundColor
            or { r = 0.04, g = 0.06, b = 0.08, a = 0.92 }
        frame.gui2ResourceTextAppearance =
            type(opts.text) == "table" and opts.text or {}
        frame.gui2ResourceSmoothProgress = opts.smoothProgress == true
        frame.gui2ResourceProgressBound = false
        frame.gui2ResourceDurationBound = false

        local trackLevel = frame.track.GetFrameLevel
            and frame.track:GetFrameLevel() or 0
        local statusBar = frame.nativeStatusBar
            or CreateFrame("StatusBar", nil, frame.track)
        local visibleStatusBar = GetVisibleNativeStatusBar(statusBar)
        if statusBar.SetFrameLevel then
            statusBar:SetFrameLevel(
                frame.nativeVisibleStatusBar and trackLevel + 1
                    or trackLevel + 3
            )
        end
        if visibleStatusBar and visibleStatusBar.SetFrameLevel then
            visibleStatusBar:SetFrameLevel(trackLevel + 3)
        end
        if not frame.nativeStatusBar then
            statusBar:SetAllPoints(frame.track)
        end
        statusBar:SetMinMaxValues(0, 1)
        statusBar:SetValue(0)
        statusBar:Show()
        frame.resourceStatusBar = statusBar
        frame.castStatusBar = statusBar
        frame.statusBar = visibleStatusBar
        statusBar.gui2ResourceBounds = frame.track
        frame.gui2NativeFillStyle = GetResourceNativeStatusBarStyle(frame)
        EnsureResourceStatusBarFillStyle(frame, statusBar, true)
        ApplyResourceBaseColor(frame)

        local partialHost = CreateFrame("Frame", nil, frame.track)
        if partialHost.SetClipsChildren then
            partialHost:SetClipsChildren(true)
        end
        if partialHost.SetFrameLevel then
            partialHost:SetFrameLevel(trackLevel + 4)
        end
        local partialBar = CreateResourceLayerStatusBar(
            partialHost,
            trackLevel + 4
        )
        partialBar:Show()
        partialHost:Hide()
        frame.resourcePartialHost = partialHost
        frame.resourcePartialBar = partialBar
        ConfigureResourceLayerBar(
            frame,
            partialBar,
            orientation == "vertical"
        )

        local rechargeClip = CreateFrame("Frame", nil, frame.track)
        rechargeClip:SetAllPoints(frame.track)
        if rechargeClip.SetClipsChildren then
            rechargeClip:SetClipsChildren(true)
        end
        if rechargeClip.SetFrameLevel then
            rechargeClip:SetFrameLevel(trackLevel + 1)
        end
        local rechargeBar = CreateResourceLayerStatusBar(
            rechargeClip,
            trackLevel + 2
        )
        frame.resourceRechargeClip = rechargeClip
        frame.resourceRechargeBar = rechargeBar

        local decorationOverlay = CreateFrame("Frame", nil, frame.track)
        decorationOverlay:SetAllPoints(frame.track)
        if decorationOverlay.SetFrameLevel and frame.track.GetFrameLevel then
            decorationOverlay:SetFrameLevel((frame.track:GetFrameLevel() or 0) + 10)
        end
        frame.resourceDecorationOverlay = decorationOverlay

        local borderOverlay = CreateFrame("Frame", nil, frame.track)
        borderOverlay:SetAllPoints(frame.track)
        if borderOverlay.SetFrameLevel then
            borderOverlay:SetFrameLevel(trackLevel + 11)
        end
        local borderEdges = {}
        for index = 1, 4 do
            local edge = borderOverlay:CreateTexture(nil, "OVERLAY", nil, 1)
            edge:SetTexture(DEFAULT_CAST_BAR_TEXTURE)
            if GUI2.ApplyTexturePixelPolicy then
                GUI2:ApplyTexturePixelPolicy(edge)
            end
            borderEdges[index] = edge
        end
        frame.resourceBorderOverlay = borderOverlay
        frame.resourceBorderEdges = {
            top = borderEdges[1],
            bottom = borderEdges[2],
            left = borderEdges[3],
            right = borderEdges[4],
        }

        local overlay = CreateFrame("Frame", nil, frame.track)
        overlay:SetAllPoints(frame.track)
        if overlay.SetFrameLevel and frame.track.GetFrameLevel then
            overlay:SetFrameLevel((frame.track:GetFrameLevel() or 0) + 12)
        end
        frame.resourceOverlay = overlay

        local nameText = GUI2:CreateText(
            overlay,
            opts.name or "",
            "font.size.sm",
            "color.text.primary",
            orientation == "vertical" and "CENTER" or "LEFT"
        )
        nameText:SetWordWrap(false)
        frame.resourceNameText = nameText

        local valueText = GUI2:CreateText(
            overlay,
            "",
            "font.size.sm",
            "color.text.primary",
            orientation == "vertical" and "CENTER" or "RIGHT"
        )
        valueText:SetWordWrap(false)
        frame.resourceValueText = valueText

        local durationCountdown = CreateFrame(
            "Cooldown",
            nil,
            overlay,
            "CooldownFrameTemplate"
        )
        durationCountdown:SetAllPoints(overlay)
        if durationCountdown.SetDrawSwipe then
            durationCountdown:SetDrawSwipe(false)
        end
        if durationCountdown.SetDrawEdge then
            durationCountdown:SetDrawEdge(false)
        end
        if durationCountdown.SetDrawBling then
            durationCountdown:SetDrawBling(false)
        end
        if durationCountdown.SetHideCountdownNumbers then
            durationCountdown:SetHideCountdownNumbers(false)
        end
        if durationCountdown.SetMinimumCountdownDuration then
            durationCountdown:SetMinimumCountdownDuration(0)
        end
        if durationCountdown.SetCountdownMillisecondsThreshold then
            durationCountdown:SetCountdownMillisecondsThreshold(10)
        end
        durationCountdown:Hide()
        frame.resourceDurationCountdown = durationCountdown

        local baseRefreshTheme = frame.RefreshTheme
        frame.SetResourceName = function(self, name)
            if self.resourceNameText then
                self.resourceNameText:SetText(name or "")
            end
        end
        local EnsureFilteredAuraApplicationDisplay

        frame.SetResourceBarSize = function(
            self,
            nextWidth,
            nextHeight,
            nextOrientation
        )
            local resolvedWidth = math_max(
                1,
                tonumber(nextWidth) or self.gui2ResourceWidth
            )
            local resolvedHeight = math_max(
                1,
                tonumber(nextHeight) or self.gui2ResourceHeight
            )
            local resolvedOrientation =
                nextOrientation == "vertical"
                    and "vertical" or "horizontal"
            local geometryChanged = resolvedWidth ~= self.gui2ResourceWidth
                or resolvedHeight ~= self.gui2ResourceHeight
                or resolvedOrientation ~= self.gui2ResourceOrientation
            self.gui2ResourceWidth = resolvedWidth
            self.gui2ResourceHeight = resolvedHeight
            self.gui2ResourceOrientation = resolvedOrientation
            self.orientation = self.gui2ResourceOrientation
            EnsureResourceStatusBarFillStyle(
                self,
                self.resourceStatusBar,
                false
            )
            ConfigureResourceLayerBar(
                self,
                self.resourcePartialBar,
                self.gui2ResourceOrientation == "vertical"
            )
            self:SetBarSize(
                self.gui2ResourceWidth,
                self.gui2ResourceHeight
            )
            PositionResourceText(self)
            LayoutResourceCells(self)
            if geometryChanged
                and self.gui2FilteredAuraApplicationDisplay
                and EnsureFilteredAuraApplicationDisplay
                and self.gui2ResourceDisplayConfig then
                EnsureFilteredAuraApplicationDisplay(
                    self,
                    self.gui2ResourceDisplayConfig
                )
            end
        end
        frame.SetResourceFillDirection = function(self, direction)
            local resolvedDirection =
                direction == "reverse" and "reverse" or "forward"
            local directionChanged = resolvedDirection
                ~= self.gui2ResourceFillDirection
            self.gui2ResourceFillDirection = resolvedDirection
            local isReverse =
                self.gui2ResourceFillDirection == "reverse"
            self.fillDirection = self.gui2ResourceOrientation == "vertical"
                and (isReverse and "down" or "up")
                or (isReverse and "right" or "left")
            EnsureResourceStatusBarFillStyle(
                self,
                self.resourceStatusBar,
                false
            )
            LayoutResourceCells(self)
            if directionChanged
                and self.gui2FilteredAuraApplicationDisplay
                and EnsureFilteredAuraApplicationDisplay
                and self.gui2ResourceDisplayConfig then
                EnsureFilteredAuraApplicationDisplay(
                    self,
                    self.gui2ResourceDisplayConfig
                )
            end
        end

        local function FilteredAuraColorSignature(value, fallback)
            local r, g, b, a = ResourceColorComponents(value, fallback)
            return string_format("%.4f,%.4f,%.4f,%.4f", r, g, b, a)
        end

        local function ConfigureFilteredAuraBoundText(
            self,
            auraFrame,
            appearance
        )
            if not (self.resourceValueText and auraFrame.CreateFontString) then
                return nil
            end
            appearance = type(appearance) == "table" and appearance or {}
            local textCarrier = CreateFrame("Frame", nil, auraFrame)
            textCarrier:SetAllPoints(self.track)
            if textCarrier.SetFrameLevel then
                local overlayLevel = self.resourceOverlay
                    and self.resourceOverlay.GetFrameLevel
                    and self.resourceOverlay:GetFrameLevel()
                local auraLevel = auraFrame.GetFrameLevel
                    and auraFrame:GetFrameLevel() or 0
                textCarrier:SetFrameLevel(
                    type(overlayLevel) == "number"
                        and overlayLevel + 1 or auraLevel + 4
                )
            end
            if textCarrier.EnableMouse then textCarrier:EnableMouse(false) end
            local text = textCarrier:CreateFontString(nil, "OVERLAY")
            local font, size, flags = self.resourceValueText:GetFont()
            local r, g, b, a = self.resourceValueText:GetTextColor()
            local position = appearance.position or "center"
            local vertical = self.gui2ResourceOrientation == "vertical"
            local point = vertical
                and (position == "start" and "BOTTOM"
                    or (position == "end" and "TOP" or "CENTER"))
                or (position == "start" and "LEFT"
                    or (position == "end" and "RIGHT" or "CENTER"))
            local offsetX = tonumber(appearance.offsetX) or 0
            local offsetY = tonumber(appearance.offsetY) or 0
            if vertical then
                offsetY = offsetY + (point == "BOTTOM" and 5
                    or (point == "TOP" and -5 or 0))
            else
                offsetX = offsetX + (point == "LEFT" and 5
                    or (point == "RIGHT" and -5 or 0))
            end
            text:SetPoint(point, self.track, point, offsetX, offsetY)
            text:SetJustifyH(vertical and "CENTER" or point)
            text:SetJustifyV("MIDDLE")
            text:SetFont(font, size, flags)
            text:SetTextColor(r, g, b, a)
            local shadow = appearance.outline == "shadow"
                or appearance.outline == "outlineShadow"
            if text.SetShadowColor then
                text:SetShadowColor(0, 0, 0, shadow and 1 or 0)
            end
            if text.SetShadowOffset then
                text:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
            end
            return text
        end

        local function IsPlayerHelpfulFilteredAuraHandle(handle)
            return type(handle) == "table"
                and handle.unit == "player"
                and handle.hasHelpfulFilter == true
                and handle.active == true
                and handle.released ~= true
        end

        local function ShowFilteredAuraHandle(self, handle)
            if type(handle) ~= "table"
                or handle.active ~= true
                or handle.released == true
                or not (handle.proxy and handle.proxy.Show) then
                return false
            end
            if self.gui2FilteredAuraIdentitySuppressed == true
                and IsPlayerHelpfulFilteredAuraHandle(handle) then
                return false
            end
            local shown = handle.proxy.IsShown
                and handle.proxy:IsShown() == true
            if shown then return false end
            handle.proxy:Show()
            return true
        end

        local function ApplyFilteredAuraIdentitySuppression(self, handle)
            if self.gui2FilteredAuraIdentitySuppressed ~= true
                or not IsPlayerHelpfulFilteredAuraHandle(handle) then
                return false, 0
            end
            local unitAPI = YUI.API and YUI.API.Unit
            if not (unitAPI
                and unitAPI.SetFilteredAuraDisplayIdentitySuppressed) then
                return false, 0
            end
            return unitAPI.SetFilteredAuraDisplayIdentitySuppressed(
                handle,
                true
            )
        end

        local function EnsureFilteredAuraDurationDisplay(self, config)
            local spellID = tonumber(config.auraDurationSpellID)
            local existing = self.gui2FilteredAuraDurationDisplay
            if not spellID then
                local unitAPI = YUI.API and YUI.API.Unit
                if existing and unitAPI
                    and unitAPI.ReleaseFilteredAuraDisplay then
                    unitAPI.ReleaseFilteredAuraDisplay(existing)
                elseif existing and existing.proxy then
                    existing.proxy:Hide()
                end
                self.gui2FilteredAuraDurationDisplay = nil
                self.gui2FilteredAuraDurationSpellID = nil
                self.gui2FilteredAuraDurationSignature = nil
                return false
            end
            local textAppearance = type(config.auraDurationTextAppearance) == "table"
                and config.auraDurationTextAppearance or {}
            if self.resourceValueText and GUI2.ApplyFontAppearance then
                GUI2:ApplyFontAppearance(
                    self.resourceValueText,
                    textAppearance
                )
            end
            local font, fontSize, fontFlags = self.resourceValueText:GetFont()
            local textR, textG, textB, textA =
                self.resourceValueText:GetTextColor()
            local fillR, fillG, fillB, fillA = ResourceColorComponents(
                config.auraDurationFillColor,
                { 1, 1, 1, 1 }
            )
            local backgroundR, backgroundG, backgroundB, backgroundA =
                ResourceColorComponents(
                    self.gui2ResourceBackgroundColor,
                    { 0, 0, 0, 0.92 }
                )
            local borderR, borderG, borderB, borderA =
                ResourceColorComponents(
                    self.gui2ResourceBorderColor,
                    { 0, 0, 0, 1 }
                )
            local textPosition = textAppearance.position or "center"
            local vertical = self.gui2ResourceOrientation == "vertical"
            local textPoint = vertical
                and (textPosition == "start" and "BOTTOM"
                    or (textPosition == "end" and "TOP" or "CENTER"))
                or (textPosition == "start" and "LEFT"
                    or (textPosition == "end" and "RIGHT" or "CENTER"))
            local textJustifyH = vertical and "CENTER" or textPoint
            local textOffsetX = tonumber(textAppearance.offsetX) or 0
            local textOffsetY = tonumber(textAppearance.offsetY) or 0
            if vertical then
                textOffsetY = textOffsetY + (textPoint == "BOTTOM" and 5
                    or (textPoint == "TOP" and -5 or 0))
            else
                textOffsetX = textOffsetX + (textPoint == "LEFT" and 5
                    or (textPoint == "RIGHT" and -5 or 0))
            end
            local signature = table.concat({
                tostring(spellID),
                tostring(config.smoothProgress == true),
                tostring(self.gui2ResourceFillTexture),
                string_format("%.4f,%.4f,%.4f,%.4f", fillR, fillG, fillB, fillA),
                tostring(font), tostring(fontSize), tostring(fontFlags),
                string_format("%.4f,%.4f,%.4f,%.4f", textR, textG, textB, textA),
                tostring(textAppearance.valueText ~= false),
                tostring(textAppearance.outline), textPoint,
                tostring(textOffsetX), tostring(textOffsetY),
                tostring(self.gui2ResourceBorder),
                string_format(
                    "%.4f,%.4f,%.4f,%.4f",
                    backgroundR,
                    backgroundG,
                    backgroundB,
                    backgroundA
                ),
                string_format(
                    "%.4f,%.4f,%.4f,%.4f",
                    borderR,
                    borderG,
                    borderB,
                    borderA
                ),
            }, ":")
            if existing and self.gui2FilteredAuraDurationSignature == signature then
                ShowFilteredAuraHandle(self, existing)
            else
                local unitAPI = YUI.API and YUI.API.Unit
                if existing and unitAPI
                    and unitAPI.ReleaseFilteredAuraDisplay then
                    unitAPI.ReleaseFilteredAuraDisplay(existing)
                elseif existing and existing.proxy then
                    existing.proxy:Hide()
                end
                local handle = unitAPI
                    and unitAPI.CreateFilteredAuraDisplay
                    and unitAPI.CreateFilteredAuraDisplay(self.track, {
                        unit = config.auraDurationUnit or "player",
                        spellID = spellID,
                        filter = "HELPFUL",
                        key = "yhud-resource-duration",
                        initializeFrame = function(auraFrame, _, displayHandle)
                            auraFrame:SetAllPoints(displayHandle.container)
                            local trackLevel = self.track.GetFrameLevel
                                and self.track:GetFrameLevel() or 0
                            if auraFrame.SetFrameLevel then
                                auraFrame:SetFrameLevel(trackLevel + 4)
                            end
                            local statusBar = CreateFrame(
                                "StatusBar",
                                nil,
                                auraFrame
                            )
                            statusBar:SetAllPoints(auraFrame)
                            if statusBar.SetFrameLevel then
                                statusBar:SetFrameLevel(trackLevel + 5)
                            end
                            EnsureResourceStatusBarFillStyle(
                                self,
                                statusBar,
                                false
                            )
                            SetResourceStatusBarColor(
                                statusBar,
                                fillR,
                                fillG,
                                fillB,
                                fillA
                            )
                            local bindings = {
                                durationBar = {
                                    target = statusBar,
                                    options = {
                                        interpolation = config.smoothProgress == true
                                            and GetStatusBarSmoothInterpolation()
                                            or GetStatusBarImmediateInterpolation(),
                                        direction = Enum
                                            and Enum.StatusBarTimerDirection
                                            and Enum.StatusBarTimerDirection
                                                .RemainingTime or 1,
                                    },
                                },
                            }
                            if textAppearance.valueText ~= false then
                                bindings.durationText =
                                    ConfigureFilteredAuraBoundText(
                                        self,
                                        auraFrame,
                                        textAppearance
                                    )
                            end
                            return bindings
                        end,
                    })
                if not handle then return false end
                self.gui2FilteredAuraDurationDisplay = handle
                self.gui2FilteredAuraDurationSpellID = spellID
                self.gui2FilteredAuraDurationSignature = signature
                existing = handle
                ApplyFilteredAuraIdentitySuppression(self, existing)
            end
            if self.SetNativeFillShown then self:SetNativeFillShown(false) end
            if self.resourceValueText then self.resourceValueText:Hide() end
            if self.resourceDurationCountdown then
                self.resourceDurationCountdown:Hide()
            end
            return true
        end

        local function FilteredAuraSpellIDs(value)
            if type(value) == "number" then value = { value } end
            if type(value) ~= "table" then return nil end
            local seen = {}
            local result = {}
            for _, candidate in pairs(value) do
                local spellID = tonumber(candidate)
                if spellID and spellID > 0 and not seen[spellID] then
                    seen[spellID] = true
                    result[#result + 1] = spellID
                end
            end
            table.sort(result)
            return #result > 0 and result or nil
        end

        local function FilteredAuraApplicationVariants(config, fallbackMax)
            local variants = {}
            local configured = type(config.auraApplicationVariants) == "table"
                and config.auraApplicationVariants or nil
            for index = 1, #(configured or {}) do
                local candidate = configured[index]
                local spellIDs = type(candidate) == "table"
                    and FilteredAuraSpellIDs(candidate.spellIDs) or nil
                local maximum = type(candidate) == "table"
                    and tonumber(candidate.maxApplications) or nil
                if spellIDs and maximum and maximum >= 1 then
                    variants[#variants + 1] = {
                        spellIDs = spellIDs,
                        maxApplications = maximum,
                    }
                end
            end
            if #variants == 0 then
                local spellIDs = FilteredAuraSpellIDs(
                    config.auraApplicationSpellIDs
                )
                if spellIDs then
                    variants[1] = {
                        spellIDs = spellIDs,
                        maxApplications = math_max(
                            1,
                            tonumber(config.auraApplicationMax) or fallbackMax
                        ),
                    }
                end
            end
            return #variants > 0 and variants or nil
        end

        local function ConfigureFilteredAuraApplicationText(
            self,
            auraFrame,
            appearance
        )
            return ConfigureFilteredAuraBoundText(
                self,
                auraFrame,
                appearance
            )
        end

        local function FilteredAuraApplicationOptions(maximum, smooth)
            return {
                maxApplications = maximum,
                interpolation = smooth == true
                    and GetStatusBarSmoothInterpolation()
                    or GetStatusBarImmediateInterpolation(),
            }
        end

        local function ApplyFilteredAuraApplicationMask(
            auraFrame,
            statusBar,
            dots
        )
            if not (dots and auraFrame.CreateMaskTexture
                and statusBar.GetStatusBarTexture) then
                return
            end
            local mask = auraFrame:CreateMaskTexture(nil, "ARTWORK")
            mask:SetAllPoints(auraFrame)
            mask:SetTexture(
                RESOURCE_CIRCLE_MASK,
                "CLAMPTOBLACKADDITIVE",
                "CLAMPTOBLACKADDITIVE"
            )
            local texture = statusBar:GetStatusBarTexture()
            if texture and texture.AddMaskTexture then
                texture:AddMaskTexture(mask)
            end
        end

        local function ConfigureFilteredAuraApplicationFrame(
            self,
            auraFrame,
            container,
            layerOffset
        )
            local containerLevel = container and container.GetFrameLevel
                and container:GetFrameLevel() or 0
            if auraFrame.SetFrameLevel then
                auraFrame:SetFrameLevel(
                    containerLevel + 1 + (tonumber(layerOffset) or 0)
                )
            end
            return auraFrame.GetFrameLevel and auraFrame:GetFrameLevel()
                or containerLevel
        end

        local function ConfigureFilteredAuraApplicationStatusBar(
            self,
            statusBar,
            color,
            solid
        )
            local texture = solid == true and DEFAULT_CAST_BAR_TEXTURE
                or self.gui2ResourceFillTexture or DEFAULT_CAST_BAR_TEXTURE
            statusBar:SetStatusBarTexture(texture)
            local textureObject = statusBar.GetStatusBarTexture
                and statusBar:GetStatusBarTexture() or nil
            if textureObject and textureObject.SetTexCoord then
                textureObject:SetTexCoord(
                    solid == true and 0 or self.gui2ResourceFillTextureU0 or 0,
                    solid == true and 1 or self.gui2ResourceFillTextureU1 or 1,
                    solid == true and 0 or self.gui2ResourceFillTextureV0 or 0,
                    solid == true and 1 or self.gui2ResourceFillTextureV1 or 1
                )
            end
            if textureObject and GUI2.ApplyTexturePixelPolicy then
                GUI2:ApplyTexturePixelPolicy(textureObject)
            end
            if textureObject and textureObject.SetHorizTile then
                textureObject:SetHorizTile(false)
            end
            if textureObject and textureObject.SetVertTile then
                textureObject:SetVertTile(false)
            end
            local nativeOrientation, rotatesTexture, reverseFill =
                GUI2:ResolveNativeStatusBarDirection(
                    self.gui2ResourceOrientation,
                    self.gui2ResourceFillDirection
                )
            if statusBar.SetOrientation then
                statusBar:SetOrientation(nativeOrientation)
            end
            if statusBar.SetRotatesTexture then
                statusBar:SetRotatesTexture(rotatesTexture)
            end
            local styles = Enum and Enum.StatusBarFillStyle
            if statusBar.SetFillStyle and styles then
                statusBar:SetFillStyle(
                    reverseFill and styles.Reverse or styles.Standard
                )
            elseif statusBar.SetReverseFill then
                statusBar:SetReverseFill(reverseFill)
            end
            local r, g, b, a = ResourceColorComponents(
                color,
                { 1, 1, 1, 1 }
            )
            statusBar:SetStatusBarColor(r, g, b, a)
        end

        local function ConfigureFilteredAuraApplicationBar(
            self,
            auraFrame,
            container,
            color,
            layerOffset
        )
            auraFrame:ClearAllPoints()
            auraFrame:SetAllPoints(container or self.track)
            ConfigureFilteredAuraApplicationFrame(
                self,
                auraFrame,
                container,
                layerOffset
            )
            local statusBar = CreateFrame("StatusBar", nil, auraFrame)
            statusBar:SetAllPoints(auraFrame)
            ConfigureFilteredAuraApplicationStatusBar(
                self,
                statusBar,
                color,
                false
            )
            statusBar:Show()
            return statusBar
        end

        local function FilteredAuraApplicationGeometry(self)
            local vertical = self.gui2ResourceOrientation == "vertical"
            local pixelSize = self.gui2ResourceSegmentPixelSize
                or (GUI2.GetPixelSize
                    and GUI2:GetPixelSize(self.track, 1, 1))
                or (GUI2.mult or 1)
            local mainSize = vertical
                and self.track:GetHeight() or self.track:GetWidth()
            local crossSize = vertical
                and self.track:GetWidth() or self.track:GetHeight()
            local totalPixels = math_max(
                1,
                math_floor((mainSize / pixelSize) + 0.5)
            )
            return vertical, pixelSize, totalPixels, crossSize
        end

        local function FilteredAuraApplicationLogicalRange(
            self,
            maximum,
            firstApplication,
            lastApplication
        )
            maximum = math_max(1, tonumber(maximum) or 1)
            local _, _, totalPixels = FilteredAuraApplicationGeometry(self)
            totalPixels = math_max(maximum, totalPixels)
            firstApplication = math_max(
                0,
                math_min(maximum, tonumber(firstApplication) or 0)
            )
            lastApplication = math_max(
                firstApplication,
                math_min(maximum, tonumber(lastApplication) or maximum)
            )
            local reverse = self.gui2ResourceFillDirection == "reverse"
            local firstPosition = reverse
                and (maximum - firstApplication) or firstApplication
            local lastPosition = reverse
                and (maximum - lastApplication) or lastApplication
            local firstPixels = math_floor(
                ((totalPixels * firstPosition) / maximum) + 0.5
            )
            local lastPixels = math_floor(
                ((totalPixels * lastPosition) / maximum) + 0.5
            )
            local offsetPixels = math_min(firstPixels, lastPixels)
            return offsetPixels, math_max(
                0,
                math_max(firstPixels, lastPixels) - offsetPixels
            )
        end

        local function ConfigureFilteredAuraApplicationFixedClip(
            self,
            auraFrame,
            offsetPixels,
            mainPixels,
            crossOffsetPixels,
            crossPixels
        )
            local vertical, pixelSize = FilteredAuraApplicationGeometry(self)
            local clipFrame = CreateFrame("Frame", nil, auraFrame)
            local offset = math_max(0, tonumber(offsetPixels) or 0) * pixelSize
            local mainSize = math_max(1, tonumber(mainPixels) or 1) * pixelSize
            local crossOffset = math_max(
                0,
                tonumber(crossOffsetPixels) or 0
            ) * pixelSize
            local crossSize = tonumber(crossPixels)
            crossSize = crossSize and math_max(1, crossSize) * pixelSize or nil
            if vertical then
                clipFrame:SetPoint(
                    "BOTTOMLEFT",
                    auraFrame,
                    "BOTTOMLEFT",
                    crossOffset,
                    offset
                )
                if crossSize then
                    clipFrame:SetSize(crossSize, mainSize)
                else
                    clipFrame:SetPoint(
                        "BOTTOMRIGHT",
                        auraFrame,
                        "BOTTOMRIGHT",
                        0,
                        offset
                    )
                    clipFrame:SetHeight(mainSize)
                end
            else
                clipFrame:SetPoint(
                    "BOTTOMLEFT",
                    auraFrame,
                    "BOTTOMLEFT",
                    offset,
                    crossOffset
                )
                if crossSize then
                    clipFrame:SetSize(mainSize, crossSize)
                else
                    clipFrame:SetPoint(
                        "TOPLEFT",
                        auraFrame,
                        "TOPLEFT",
                        offset,
                        0
                    )
                    clipFrame:SetWidth(mainSize)
                end
            end
            if clipFrame.SetClipsChildren then
                clipFrame:SetClipsChildren(true)
            end
            return clipFrame
        end

        local function ConfigureFilteredAuraApplicationGate(
            self,
            auraFrame,
            container,
            cell,
            clipOffsetPixels,
            clipMainPixels,
            trigger,
            color,
            layerOffset,
            dots,
            solid
        )
            auraFrame:ClearAllPoints()
            auraFrame:SetAllPoints(container or self.track)
            local clipCrossOffsetPixels
            local clipCrossPixels
            if cell then
                clipOffsetPixels = cell.gui2ResourceMainOffsetPixels
                clipMainPixels = cell.gui2ResourceMainPixels
                clipCrossOffsetPixels = cell.gui2ResourceCrossOffsetPixels
                clipCrossPixels = cell.gui2ResourceCrossPixels
            end
            local clipFrame = ConfigureFilteredAuraApplicationFixedClip(
                self,
                auraFrame,
                clipOffsetPixels,
                clipMainPixels,
                clipCrossOffsetPixels,
                clipCrossPixels
            )
            if clipFrame.SetClipsChildren then
                clipFrame:SetClipsChildren(true)
            end
            ConfigureFilteredAuraApplicationFrame(
                self,
                auraFrame,
                container,
                layerOffset
            )
            local statusBar = CreateFrame("StatusBar", nil, clipFrame)
            trigger = math_max(1, tonumber(trigger) or 1)
            local vertical, pixelSize = FilteredAuraApplicationGeometry(self)
            local targetMain = math_max(
                pixelSize,
                (tonumber(clipMainPixels) or 1) * pixelSize
            )
            local driverMain = targetMain * trigger
            local reverse = self.gui2ResourceFillDirection == "reverse"
            if vertical then
                statusBar:SetPoint("LEFT", clipFrame, "LEFT", 0, 0)
                statusBar:SetPoint("RIGHT", clipFrame, "RIGHT", 0, 0)
                statusBar:SetHeight(driverMain)
                statusBar:SetPoint(
                    reverse and "BOTTOM" or "TOP",
                    clipFrame,
                    reverse and "BOTTOM" or "TOP",
                    0,
                    0
                )
            else
                statusBar:SetPoint("TOP", clipFrame, "TOP", 0, 0)
                statusBar:SetPoint("BOTTOM", clipFrame, "BOTTOM", 0, 0)
                statusBar:SetWidth(driverMain)
                statusBar:SetPoint(
                    reverse and "LEFT" or "RIGHT",
                    clipFrame,
                    reverse and "LEFT" or "RIGHT",
                    0,
                    0
                )
            end
            ConfigureFilteredAuraApplicationStatusBar(
                self,
                statusBar,
                color,
                solid ~= false
            )
            ApplyFilteredAuraApplicationMask(clipFrame, statusBar, dots)
            statusBar:Show()
            return statusBar
        end

        local function AppendFilteredAuraApplicationGateSlot(
            slots,
            self,
            variant,
            key,
            cell,
            clipOffsetPixels,
            clipMainPixels,
            trigger,
            color,
            layerOffset,
            dots,
            solid
        )
            slots[#slots + 1] = {
                key = key,
                spellIDs = variant.spellIDs,
                initializeFrame = function(auraFrame, _, displayHandle)
                    local statusBar = ConfigureFilteredAuraApplicationGate(
                        self,
                        auraFrame,
                        displayHandle and displayHandle.container,
                        cell,
                        clipOffsetPixels,
                        clipMainPixels,
                        trigger,
                        color,
                        layerOffset,
                        dots,
                        solid
                    )
                    auraFrame:SetApplicationBar(
                        statusBar,
                        FilteredAuraApplicationOptions(
                            trigger,
                            self.gui2ResourceSmoothProgress
                        )
                    )
                end,
            }
        end

        local function HideNativeApplicationFills(self, cellsMode)
            if self.SetNativeFillShown then self:SetNativeFillShown(false) end
            if cellsMode then
                for index = 1, self.gui2ResourceActiveCellCount or 0 do
                    local cell = self.resourceCells[index]
                    if cell and cell.statusBar then cell.statusBar:Hide() end
                end
            end
            HideResourceSecretThresholdLayers(self)
        end

        local function SetFilteredAuraApplicationPublicPreview(
            self,
            enabled,
            cellsMode
        )
            local handle = self.gui2FilteredAuraApplicationDisplay
            if not (handle and handle.proxy) then
                self.gui2FilteredAuraApplicationPublicPreview = nil
                return false
            end
            enabled = enabled == true
            self.gui2FilteredAuraApplicationPublicPreview = enabled
            HideResourceSecretThresholdLayers(self)
            if enabled then
                handle.proxy:Hide()
                if self.SetNativeFillShown then
                    self:SetNativeFillShown(not cellsMode)
                end
                if cellsMode then
                    for index = 1, self.gui2ResourceActiveCellCount or 0 do
                        local cell = self.resourceCells[index]
                        if cell and cell.statusBar then cell.statusBar:Show() end
                    end
                end
                if self.resourceValueText then
                    local config = self.gui2ResourceDisplayConfig or {}
                    local appearance = config.auraApplicationTextAppearance
                        or self.gui2ResourceTextAppearance or {}
                    self.resourceValueText:SetShown(
                        appearance.valueText ~= false
                    )
                end
            else
                HideNativeApplicationFills(self, cellsMode)
                ShowFilteredAuraHandle(self, handle)
                if self.resourceValueText then self.resourceValueText:Hide() end
            end
            return true
        end

        EnsureFilteredAuraApplicationDisplay = function(self, config)
            local existing = self.gui2FilteredAuraApplicationDisplay
            local unitAPI = YUI.API and YUI.API.Unit
            local mode = config.mode
            local cellsMode = mode == "cells" or mode == "dots"
            local cellCount = cellsMode
                and (self.gui2ResourceActiveCellCount or 0) or 1
            local variants = FilteredAuraApplicationVariants(config, cellCount)
            if not variants then
                if existing and unitAPI
                    and unitAPI.ReleaseFilteredAuraDisplay then
                    unitAPI.ReleaseFilteredAuraDisplay(existing)
                elseif existing and existing.proxy then
                    existing.proxy:Hide()
                end
                self.gui2FilteredAuraApplicationDisplay = nil
                self.gui2FilteredAuraApplicationSignature = nil
                self.gui2FilteredAuraApplicationPublicPreview = nil
                return false
            end
            local fillR, fillG, fillB, fillA = ResourceColorComponents(
                config.auraApplicationFillColor,
                { 1, 1, 1, 1 }
            )
            local textAppearance = type(config.auraApplicationTextAppearance)
                == "table" and config.auraApplicationTextAppearance or {}
            local textFont, textSize, textFlags =
                self.resourceValueText:GetFont()
            local textR, textG, textB, textA =
                self.resourceValueText:GetTextColor()
            local variantSignature = {}
            for index = 1, #variants do
                local variant = variants[index]
                variantSignature[index] = table.concat(
                    variant.spellIDs,
                    ","
                ) .. "@" .. tostring(variant.maxApplications)
            end
            local thresholds = type(config.thresholds) == "table"
                and config.thresholds or {}
            local lowThreshold = type(thresholds.low) == "table"
                and thresholds.low or {}
            local highThreshold = type(thresholds.high) == "table"
                and thresholds.high or {}
            local thresholdColorEnabled =
                config.thresholdColorEnabled == true
            local lowEnabled = thresholdColorEnabled
                and lowThreshold.enabled == true
            local highEnabled = thresholdColorEnabled
                and highThreshold.enabled == true
            local lowColor = lowThreshold.color
                or config.auraApplicationFillColor
            local highColor = highThreshold.color
                or config.auraApplicationFillColor
            local _, geometryPixelSize, geometryMainPixels,
                geometryCrossSize = FilteredAuraApplicationGeometry(self)
            local signature = table.concat({
                table.concat(variantSignature, ";"),
                tostring(config.auraApplicationUnit or "player"),
                tostring(config.auraApplicationFilter or "HELPFUL"),
                tostring(config.auraApplicationRequirePlayerSource == true),
                tostring(mode),
                tostring(config.smoothProgress == true),
                tostring(cellCount),
                tostring(self.gui2ResourceOrientation),
                tostring(self.gui2ResourceFillDirection),
                string_format("%.6f", geometryPixelSize),
                tostring(geometryMainPixels),
                string_format("%.4f", geometryCrossSize),
                tostring(self.gui2ResourceFillTexture),
                string_format(
                    "%.4f,%.4f,%.4f,%.4f",
                    fillR,
                    fillG,
                    fillB,
                    fillA
                ),
                tostring(textAppearance.valueText ~= false),
                tostring(textAppearance.position),
                tostring(textAppearance.offsetX),
                tostring(textAppearance.offsetY),
                tostring(textAppearance.outline),
                tostring(textFont),
                tostring(textSize),
                tostring(textFlags),
                string_format(
                    "%.4f,%.4f,%.4f,%.4f",
                    textR,
                    textG,
                    textB,
                    textA
                ),
                tostring(self.gui2ResourceBorder),
                FilteredAuraColorSignature(
                    self.gui2ResourceBackgroundColor,
                    { 0, 0, 0, 0.92 }
                ),
                FilteredAuraColorSignature(
                    self.gui2ResourceBorderColor,
                    { 0, 0, 0, 1 }
                ),
                tostring(config.segmentCount),
                tostring(config.dividerThickness),
                FilteredAuraColorSignature(
                    config.dividerColor,
                    { 0, 0, 0, 1 }
                ),
                tostring(config.thresholdMarkerEnabled == true),
                tostring(config.thresholdMarkerThickness),
                FilteredAuraColorSignature(
                    config.thresholdMarkerColor,
                    { 0, 0, 0, 1 }
                ),
                tostring(thresholdColorEnabled),
                tostring(lowEnabled),
                tostring(lowThreshold.value),
                FilteredAuraColorSignature(
                    lowColor,
                    { 1, 1, 1, 1 }
                ),
                tostring(highEnabled),
                tostring(highThreshold.value),
                FilteredAuraColorSignature(
                    highColor,
                    { 1, 1, 1, 1 }
                ),
            }, ":")
            if existing
                and self.gui2FilteredAuraApplicationSignature == signature then
                SetFilteredAuraApplicationPublicPreview(
                    self,
                    false,
                    cellsMode
                )
                return true
            end
            if existing and unitAPI
                and unitAPI.ReleaseFilteredAuraDisplay then
                unitAPI.ReleaseFilteredAuraDisplay(existing)
            elseif existing and existing.proxy then
                existing.proxy:Hide()
            end
            if not (unitAPI and unitAPI.CreateFilteredAuraDisplay) then
                return false
            end

            local slots = {}
            for variantIndex = 1, #variants do
                local variant = variants[variantIndex]
                local maximum = variant.maxApplications
                local variantOrder = variantIndex
                local layerBase = 0
                local lowValue = math_max(
                    0,
                    tonumber(lowThreshold.value) or 0
                )
                local highValue = math_max(
                    0,
                    tonumber(highThreshold.value) or 0
                )
                local visibleLowEnabled = lowEnabled and lowValue > 0
                local highAlwaysEnabled = highEnabled and highValue <= 0
                local baseColor = config.auraApplicationFillColor
                if visibleLowEnabled then
                    baseColor = lowColor
                end
                if highAlwaysEnabled then
                    baseColor = highColor
                end
                for index = 1, cellCount do
                    local cell = cellsMode and self.resourceCells[index] or nil
                    local cellIndex = index
                    slots[#slots + 1] = {
                        key = "yhud-application-" .. tostring(variantOrder)
                            .. "-" .. tostring(cellIndex),
                        spellIDs = variant.spellIDs,
                        initializeFrame = function(auraFrame, _, displayHandle)
                            local applicationBar
                            local bindingMaximum
                            if cellsMode then
                                applicationBar =
                                    ConfigureFilteredAuraApplicationGate(
                                        self,
                                        auraFrame,
                                        displayHandle and displayHandle.container,
                                        cell,
                                        nil,
                                        nil,
                                        cellIndex,
                                        baseColor,
                                        layerBase,
                                        mode == "dots",
                                        false
                                    )
                                bindingMaximum = cellIndex
                            else
                                applicationBar =
                                    ConfigureFilteredAuraApplicationBar(
                                        self,
                                        auraFrame,
                                        displayHandle and displayHandle.container,
                                        baseColor,
                                        layerBase
                                    )
                                bindingMaximum = maximum
                            end
                            auraFrame:SetApplicationBar(
                                applicationBar,
                                FilteredAuraApplicationOptions(
                                    bindingMaximum,
                                    self.gui2ResourceSmoothProgress
                                )
                            )
                            local bindings
                            if not cellsMode and cellIndex == 1
                                and config.auraApplicationTextAppearance
                                and config.auraApplicationTextAppearance.valueText
                                    ~= false then
                                bindings = {
                                    applicationCount =
                                    ConfigureFilteredAuraApplicationText(
                                        self,
                                        auraFrame,
                                        config.auraApplicationTextAppearance
                                    ),
                                }
                            end
                            return bindings
                        end,
                    }
                end
                if cellsMode then
                    if not highAlwaysEnabled and visibleLowEnabled
                        and lowValue < maximum then
                        for index = 1, cellCount do
                            local resetAt = math_max(index, lowValue + 1)
                            if resetAt <= maximum then
                                AppendFilteredAuraApplicationGateSlot(
                                    slots,
                                    self,
                                    variant,
                                    "yhud-application-reset-"
                                        .. tostring(variantOrder) .. "-"
                                        .. tostring(index),
                                    self.resourceCells[index],
                                    nil,
                                    nil,
                                    resetAt,
                                    config.auraApplicationFillColor,
                                    layerBase + 1,
                                    mode == "dots"
                                )
                            end
                        end
                    end
                    if not highAlwaysEnabled and highEnabled and highValue > 0
                        and highValue <= maximum then
                        for index = 1, cellCount do
                            local highAt = math_max(index, highValue)
                            if highAt <= maximum then
                                AppendFilteredAuraApplicationGateSlot(
                                    slots,
                                    self,
                                    variant,
                                    "yhud-application-high-"
                                        .. tostring(variantOrder) .. "-"
                                        .. tostring(index),
                                    self.resourceCells[index],
                                    nil,
                                    nil,
                                    highAt,
                                    highColor,
                                    layerBase + 2,
                                    mode == "dots"
                                )
                            end
                        end
                    end
                else
                    if not highAlwaysEnabled and visibleLowEnabled
                        and lowValue < maximum then
                        for index = 1, maximum do
                            local resetAt = math_max(index, lowValue + 1)
                            if resetAt <= maximum then
                                local offsetPixels, mainPixels =
                                    FilteredAuraApplicationLogicalRange(
                                        self,
                                        maximum,
                                        index - 1,
                                        index
                                    )
                                AppendFilteredAuraApplicationGateSlot(
                                    slots,
                                    self,
                                    variant,
                                    "yhud-application-reset-"
                                        .. tostring(variantOrder) .. "-"
                                        .. tostring(index),
                                    nil,
                                    offsetPixels,
                                    mainPixels,
                                    resetAt,
                                    config.auraApplicationFillColor,
                                    layerBase + 1,
                                    false
                                )
                            end
                        end
                    end
                    if not highAlwaysEnabled and highEnabled
                        and highValue > 0 and highValue <= maximum then
                        for index = 1, maximum do
                            local highAt = math_max(index, highValue)
                            if highAt <= maximum then
                                local offsetPixels, mainPixels =
                                    FilteredAuraApplicationLogicalRange(
                                        self,
                                        maximum,
                                        index - 1,
                                        index
                                    )
                                AppendFilteredAuraApplicationGateSlot(
                                    slots,
                                    self,
                                    variant,
                                    "yhud-application-high-"
                                        .. tostring(variantOrder) .. "-"
                                        .. tostring(index),
                                    nil,
                                    offsetPixels,
                                    mainPixels,
                                    highAt,
                                    highColor,
                                    layerBase + 2,
                                    false
                                )
                            end
                        end
                    end
                end
                if cellsMode and config.auraApplicationTextAppearance
                    and config.auraApplicationTextAppearance.valueText ~= false then
                    slots[#slots + 1] = {
                        key = "yhud-application-text-" .. tostring(variantOrder),
                        spellIDs = variant.spellIDs,
                        initializeFrame = function(auraFrame, _, displayHandle)
                            local container = displayHandle
                                and displayHandle.container
                            auraFrame:SetAllPoints(container or self.track)
                            ConfigureFilteredAuraApplicationFrame(
                                self,
                                auraFrame,
                                container,
                                layerBase + 3
                            )
                            return {
                                applicationCount =
                                    ConfigureFilteredAuraApplicationText(
                                        self,
                                        auraFrame,
                                        config.auraApplicationTextAppearance
                                    ),
                            }
                        end,
                    }
                end
            end
            local handle = unitAPI.CreateFilteredAuraDisplay(self.track, {
                unit = config.auraApplicationUnit or "player",
                filter = config.auraApplicationFilter or "HELPFUL",
                requirePlayerSource =
                    config.auraApplicationRequirePlayerSource == true,
                slots = slots,
            })
            if not handle then return false end
            self.gui2FilteredAuraApplicationDisplay = handle
            self.gui2FilteredAuraApplicationSignature = signature
            SetFilteredAuraApplicationPublicPreview(self, false, cellsMode)
            ApplyFilteredAuraIdentitySuppression(self, handle)
            return true
        end

        frame.SetResourceFillColor = function(self, color)
            self.gui2ResourceFillColor =
                color or "color.accent.primary"
            self.gui2FillColor = self.gui2ResourceFillColor
            ApplyResourceBaseColor(self)
            local r, g, b, a = ResourceColorComponents(
                self.gui2ResourceFillColor,
                { 1, 1, 1, 1 }
            )
            SetResourceStatusBarColor(
                self.resourceRechargeBar,
                r,
                g,
                b,
                a
            )
            for index = 1, #(self.resourceRechargeCells or {}) do
                SetResourceStatusBarColor(
                    self.resourceRechargeCells[index].rechargeBar,
                    r,
                    g,
                    b,
                    a
                )
            end
            for index = 1, #(self.resourceCells or {}) do
                SetResourceStatusBarColor(
                    self.resourceCells[index].rechargeBar,
                    r,
                    g,
                    b,
                    a
                )
            end
            LayoutResourceCells(self)
        end
        frame.PreviewResourceColor = function(self, field, color)
            local r, g, b, a = ResolvePreviewColor(color)
            if field == "fill" then
                ForEachResourceStatusBar(
                    self,
                    SetResourceStatusBarColor,
                    r,
                    g,
                    b,
                    a
                )
                return true
            elseif field == "background" then
                local config = self.gui2ResourceDisplayConfig or {}
                local cellsMode = config.mode == "cells"
                    or config.mode == "dots"
                if not cellsMode then
                    PreviewPanelColor(self.track, color)
                end
                for index = 1, self.gui2ResourceActiveCellCount or 0 do
                    local cell = self.resourceCells[index]
                    if cell and cell.background then
                        cell.background:SetVertexColor(r, g, b, a)
                    end
                end
                return true
            elseif field == "border" then
                local borders = self.resourceBorderEdges
                if borders then
                    borders.top:SetVertexColor(r, g, b, a)
                    borders.bottom:SetVertexColor(r, g, b, a)
                    borders.left:SetVertexColor(r, g, b, a)
                    borders.right:SetVertexColor(r, g, b, a)
                end
                for index = 1, self.gui2ResourceActiveCellCount or 0 do
                    local cell = self.resourceCells[index]
                    if cell then
                        if cell.border then
                            cell.border:SetVertexColor(r, g, b, a)
                        end
                        for edgeIndex = 1, 4 do
                            cell.edges[edgeIndex]:SetVertexColor(r, g, b, a)
                        end
                    end
                end
                return true
            elseif field == "text" then
                if self.resourceNameText then
                    self.resourceNameText:SetTextColor(r, g, b, a)
                end
                if self.resourceValueText then
                    self.resourceValueText:SetTextColor(r, g, b, a)
                end
                return true
            elseif field == "divider" or field == "thresholdMarker" then
                local kind = field == "divider"
                    and "divider" or "threshold"
                for index = 1, #(self.resourceLines or {}) do
                    local line = self.resourceLines[index]
                    if line.gui2ResourceLineKind == kind
                        and (not line.IsShown or line:IsShown()) then
                        line:SetVertexColor(r, g, b, a)
                    end
                end
                return true
            elseif field == "thresholdLow"
                or field == "thresholdHigh" then
                local key = field == "thresholdLow"
                    and "thresholdLow" or "thresholdHigh"
                for index = 1, #(self.resourceSecretOverlayCells or {}) do
                    local bar = self.resourceSecretOverlayCells[index][key]
                    if bar and bar:IsShown() then
                        SetResourceStatusBarColor(bar, r, g, b, a)
                    end
                end
                for index = 1, self.gui2ResourceActiveCellCount or 0 do
                    local cell = self.resourceCells[index]
                    local bar = cell and cell[key]
                    if bar and bar:IsShown() then
                        SetResourceStatusBarColor(bar, r, g, b, a)
                    end
                end
                return true
            end
            return false
        end
        frame.RefreshResourceFillStyle = function(self, force)
            local changed = EnsureResourceStatusBarFillStyle(
                self,
                self.resourceStatusBar,
                force
            )
            changed = EnsureResourceStatusBarFillStyle(
                self,
                self.resourcePartialBar,
                force
            ) or changed
            changed = EnsureResourceStatusBarFillStyle(
                self,
                self.resourceRechargeBar,
                force
            ) or changed
            for index = 1, #(self.resourceRechargeCells or {}) do
                local cell = self.resourceRechargeCells[index]
                changed = EnsureResourceStatusBarFillStyle(
                    self,
                    cell.rechargeBar,
                    force
                ) or changed
                changed = EnsureResourceStatusBarFillStyle(
                    self,
                    cell.rechargeGate,
                    force
                ) or changed
            end
            for index = 1, #(self.resourceSecretOverlayCells or {}) do
                local cell = self.resourceSecretOverlayCells[index]
                changed = ConfigureResourceSolidOverlay(
                    self,
                    cell.thresholdLow,
                    force
                ) or changed
                changed = ConfigureResourceSolidOverlay(
                    self,
                    cell.thresholdReset,
                    force
                ) or changed
                changed = ConfigureResourceSolidOverlay(
                    self,
                    cell.thresholdHigh,
                    force
                ) or changed
            end
            for index = 1, self.gui2ResourceActiveCellCount or 0 do
                local cell = self.resourceCells and self.resourceCells[index]
                if cell then
                    changed = EnsureResourceStatusBarFillStyle(
                        self,
                        cell.statusBar,
                        force
                    ) or changed
                    changed = EnsureResourceStatusBarFillStyle(
                        self,
                        cell.rechargeBar,
                        force
                    ) or changed
                    changed = EnsureResourceStatusBarFillStyle(
                        self,
                        cell.rechargeGate,
                        force
                    ) or changed
                    changed = EnsureResourceStatusBarFillStyle(
                        self,
                        cell.thresholdLow,
                        force
                    ) or changed
                    changed = EnsureResourceStatusBarFillStyle(
                        self,
                        cell.thresholdReset,
                        force
                    ) or changed
                    changed = EnsureResourceStatusBarFillStyle(
                        self,
                        cell.thresholdHigh,
                        force
                    ) or changed
                end
            end
            return changed
        end
        frame.SetResourceFillStyle = function(self, snapshot)
            snapshot = type(snapshot) == "table" and snapshot or {}
            local texture = snapshot.texture or self.gui2ResourceFillTexture
            local u0 = tonumber(snapshot.textureU0) or 0
            local u1 = tonumber(snapshot.textureU1) or 1
            local v0 = tonumber(snapshot.textureV0) or 0
            local v1 = tonumber(snapshot.textureV1) or 1
            local changed = self.gui2ResourceFillTexture ~= texture
                or self.gui2ResourceFillTextureU0 ~= u0
                or self.gui2ResourceFillTextureU1 ~= u1
                or self.gui2ResourceFillTextureV0 ~= v0
                or self.gui2ResourceFillTextureV1 ~= v1
            self.gui2ResourceFillTexture = texture
            self.gui2FillTexture = texture
            self.gui2ResourceFillTextureU0 = u0
            self.gui2ResourceFillTextureU1 = u1
            self.gui2ResourceFillTextureV0 = v0
            self.gui2ResourceFillTextureV1 = v1
            if changed then
                self.gui2ResourceFillStyleRevision =
                    (self.gui2ResourceFillStyleRevision or 0) + 1
            end
            return self:RefreshResourceFillStyle(changed)
        end
        frame.SetResourceFillTexture = function(self, texture)
            return self:SetResourceFillStyle({
                texture = texture,
                textureU0 = 0,
                textureU1 = 1,
                textureV0 = 0,
                textureV1 = 1,
            })
        end
        frame.RefreshResourceTexturePixelPolicy = function(self)
            self:RefreshResourceFillStyle(false)
            ApplyResourceStatusBarTexturePixelPolicy(
                self.resourceStatusBar
            )
            ApplyResourceStatusBarTexturePixelPolicy(
                self.resourcePartialBar
            )
            ApplyResourceStatusBarTexturePixelPolicy(
                self.resourceRechargeBar
            )
            for index = 1, #(self.resourceRechargeCells or {}) do
                local cell = self.resourceRechargeCells[index]
                ApplyResourceStatusBarTexturePixelPolicy(cell.rechargeBar)
                ApplyResourceStatusBarTexturePixelPolicy(cell.rechargeGate)
            end
            for index = 1, #(self.resourceSecretOverlayCells or {}) do
                local cell = self.resourceSecretOverlayCells[index]
                ApplyResourceStatusBarTexturePixelPolicy(cell.thresholdLow)
                ApplyResourceStatusBarTexturePixelPolicy(cell.thresholdReset)
                ApplyResourceStatusBarTexturePixelPolicy(cell.thresholdHigh)
            end
            for index = 1, self.gui2ResourceActiveCellCount or 0 do
                local cell = self.resourceCells and self.resourceCells[index]
                if cell then
                    ApplyResourceStatusBarTexturePixelPolicy(
                        cell.statusBar
                    )
                    ApplyResourceStatusBarTexturePixelPolicy(cell.rechargeBar)
                    ApplyResourceStatusBarTexturePixelPolicy(cell.rechargeGate)
                    ApplyResourceStatusBarTexturePixelPolicy(cell.thresholdLow)
                    ApplyResourceStatusBarTexturePixelPolicy(cell.thresholdReset)
                    ApplyResourceStatusBarTexturePixelPolicy(cell.thresholdHigh)
                end
            end
        end
        frame.SetResourceBorder = function(self, border)
            self.gui2ResourceBorder = border == nil and 1 or border
            LayoutResourceCells(self)
        end
        frame.SetResourceBorderColor = function(self, color)
            self.gui2ResourceBorderColor = color
                or { r = 0, g = 0, b = 0, a = 1 }
            LayoutResourceCells(self)
        end
        frame.SetResourceBackgroundColor = function(self, color)
            self.gui2ResourceBackgroundColor = color
            LayoutResourceCells(self)
        end
        frame.SetResourceDisplayConfig = function(self, config)
            config = type(config) == "table" and config or {}
            ResetResourcePartialVisual(self)
            local valueKind = config.valueKind == "discrete"
                and "discrete" or "continuous"
            local mode = config.mode
            if mode ~= "divided" and mode ~= "cells" and mode ~= "dots" then
                mode = "bar"
            end
            local segmentCount = tonumber(config.segmentCount)
            local validSegmentCount = segmentCount
                and segmentCount >= 1
                and segmentCount <= 100
                and segmentCount % 1 == 0
            if valueKind ~= "discrete"
                or (mode ~= "bar" and not validSegmentCount) then
                mode = "bar"
            end
            segmentCount = validSegmentCount and segmentCount or 1
            StopStatusBarInterpolation(self.resourceStatusBar)
            self.gui2ResourceProgressBound = false
            self.gui2ResourceDurationBound = false
            self.gui2ResourceSmoothProgress = config.smoothProgress == true
                and mode == "bar"
            self.gui2ResourceDisplayConfig = {
                mode = mode,
                smoothProgress = self.gui2ResourceSmoothProgress,
                valueKind = valueKind,
                segmentCount = segmentCount,
                segmentSpacing = math_max(
                    -5,
                    math_min(32, tonumber(config.segmentSpacing) or 2)
                ),
                dividerThickness = math_max(
                    1,
                    math_min(4, tonumber(config.dividerThickness) or 1)
                ),
                dividerColor = config.dividerColor,
                thresholdColorEnabled = config.thresholdColorEnabled == true,
                thresholdMarkerEnabled = config.thresholdMarkerEnabled == true
                    and mode ~= "cells" and mode ~= "dots",
                thresholds = config.thresholds,
                thresholdMarkerColor = config.thresholdMarkerColor,
                thresholdMarkerThickness = math_max(
                    1,
                    math_min(4, tonumber(config.thresholdMarkerThickness) or 1)
                ),
                rechargeProgress = config.rechargeProgress == true,
                independentCells = config.independentCells == true,
                durationProgress = config.durationProgress == true,
                timerMarkers = config.timerMarkers == true,
                partialRecharge = config.partialRecharge == true,
                partialUnit = config.partialUnit or "player",
                partialPowerType = config.partialPowerType,
                partialScale = tonumber(config.partialScale) or 1000,
                partialSource = config.partialSource,
                partialPollInterval = tonumber(config.partialPollInterval),
                partialProgressReader = config.partialProgressReader,
                chargedPointColor = config.chargedPointColor,
                auraDurationSpellID = config.auraDurationSpellID,
                auraDurationUnit = config.auraDurationUnit,
                auraDurationFillColor = config.auraDurationFillColor,
                auraDurationTextAppearance = config.auraDurationTextAppearance,
                auraApplicationSpellIDs = config.auraApplicationSpellIDs,
                auraApplicationVariants = config.auraApplicationVariants,
                auraApplicationUnit = config.auraApplicationUnit,
                auraApplicationFilter = config.auraApplicationFilter,
                auraApplicationRequirePlayerSource =
                    config.auraApplicationRequirePlayerSource == true,
                auraApplicationMax = tonumber(config.auraApplicationMax),
                auraApplicationFillColor = config.auraApplicationFillColor,
                auraApplicationTextAppearance =
                    config.auraApplicationTextAppearance,
            }
            LayoutResourceCells(self)
            EnsureFilteredAuraDurationDisplay(
                self,
                self.gui2ResourceDisplayConfig
            )
            EnsureFilteredAuraApplicationDisplay(
                self,
                self.gui2ResourceDisplayConfig
            )
            if self.gui2ResourceDisplayConfig.timerMarkers ~= true then
                StopResourceTimerMarkers(self)
            end
            StartResourcePartialRecharge(self)
        end
        frame.ReleaseFilteredAuraDisplays = function(self)
            local unitAPI = YUI.API and YUI.API.Unit
            for _, field in ipairs({
                "gui2FilteredAuraDurationDisplay",
                "gui2FilteredAuraApplicationDisplay",
            }) do
                local handle = self[field]
                if handle and unitAPI
                    and unitAPI.ReleaseFilteredAuraDisplay then
                    unitAPI.ReleaseFilteredAuraDisplay(handle)
                elseif handle and handle.proxy then
                    handle.proxy:Hide()
                end
                self[field] = nil
            end
            self.gui2FilteredAuraDurationSpellID = nil
            self.gui2FilteredAuraDurationSignature = nil
            self.gui2FilteredAuraApplicationSignature = nil
            self.gui2FilteredAuraApplicationPublicPreview = nil
            self.gui2FilteredAuraIdentitySuppressed = nil
            return true
        end
        frame.SetFilteredAuraIdentitySuppressed = function(self, suppressed)
            suppressed = suppressed == true
            local unitAPI = YUI.API and YUI.API.Unit
            local setter = unitAPI
                and unitAPI.SetFilteredAuraDisplayIdentitySuppressed
            if not setter then return false, 0, 0 end

            local eligible = 0
            local changed = false
            local restored = 0
            local durationHandle = self.gui2FilteredAuraDurationDisplay
            local applicationHandle = self.gui2FilteredAuraApplicationDisplay
            if IsPlayerHelpfulFilteredAuraHandle(durationHandle) then
                eligible = eligible + 1
            end
            if IsPlayerHelpfulFilteredAuraHandle(applicationHandle) then
                eligible = eligible + 1
            end
            self.gui2FilteredAuraIdentitySuppressed =
                suppressed and true or nil
            if eligible == 0 then
                return false, 0, 0
            end

            local handleChanged, handleRestored
            if IsPlayerHelpfulFilteredAuraHandle(durationHandle) then
                handleChanged, handleRestored = setter(
                    durationHandle,
                    suppressed
                )
                changed = handleChanged == true or changed
                restored = restored + (tonumber(handleRestored) or 0)
            end
            if IsPlayerHelpfulFilteredAuraHandle(applicationHandle) then
                handleChanged, handleRestored = setter(
                    applicationHandle,
                    suppressed
                )
                changed = handleChanged == true or changed
                restored = restored + (tonumber(handleRestored) or 0)
            end
            if not suppressed
                and self.gui2FilteredAuraApplicationPublicPreview == true
                and IsPlayerHelpfulFilteredAuraHandle(applicationHandle)
                and applicationHandle.proxy.IsShown
                and applicationHandle.proxy:IsShown() == true then
                applicationHandle.proxy:Hide()
            end
            return changed, restored, eligible
        end
        frame.SetResourceStructuralMax = function(self, structuralMax)
            structuralMax = tonumber(structuralMax)
            if not structuralMax or structuralMax < 1
                or structuralMax > 100 or structuralMax % 1 ~= 0 then
                return false
            end
            local config = self.gui2ResourceDisplayConfig
            if not config or config.segmentCount == structuralMax then return false end
            config.segmentCount = structuralMax
            if config.auraApplicationSpellIDs then
                config.auraApplicationMax = structuralMax
            end
            if type(config.auraApplicationVariants) == "table"
                and type(config.auraApplicationVariants[1]) == "table" then
                config.auraApplicationVariants[1].maxApplications = structuralMax
            end
            LayoutResourceCells(self)
            EnsureFilteredAuraApplicationDisplay(self, config)
            return true
        end
        frame.SetResourceTextAppearance = function(self, appearance)
            appearance = type(appearance) == "table"
                and appearance or {}
            self.gui2ResourceTextAppearance = appearance
            if self.resourceNameText then
                self.resourceNameText:SetShown(
                    appearance.nameText ~= false
                )
                if GUI2.ApplyFontAppearance then
                    GUI2:ApplyFontAppearance(
                        self.resourceNameText,
                        appearance
                    )
                end
            end
            if self.resourceValueText then
                self.resourceValueText:SetShown(
                    appearance.valueText ~= false
                )
                if GUI2.ApplyFontAppearance then
                    GUI2:ApplyFontAppearance(
                        self.resourceValueText,
                        appearance
                    )
                end
            end
            if self.resourceDurationCountdown
                and GUI2.ApplyCooldownTextAppearance then
                GUI2:ApplyCooldownTextAppearance({
                    cooldown = self.resourceDurationCountdown,
                }, appearance)
            end
            self.gui2ResourceValueFormat = appearance.valueFormat == "value"
                and "value" or appearance.valueFormat
            for index = 1, #(self.resourceCells or {}) do
                ApplyResourceCellCooldownAppearance(self, self.resourceCells[index])
            end
            if self.gui2FilteredAuraDurationDisplay
                or self.gui2FilteredAuraApplicationDisplay
                    and self.gui2FilteredAuraApplicationPublicPreview ~= true then
                if self.resourceValueText then self.resourceValueText:Hide() end
            end
            PositionResourceText(self)
        end
        local function FinishResourceValueUpdate(
            self,
            applied,
            fillStyleVerified
        )
            if fillStyleVerified ~= true and self.RefreshResourceFillStyle then
                self:RefreshResourceFillStyle(false)
            end
            return applied
        end
        frame.SetResourceValues = function(
            self,
            valueRaw,
            maxValueRaw,
            secret,
            value,
            maxValue,
            colorRaw,
            rechargeDurationRaw,
            rechargeActive,
            cellReadyRaw,
            cellDurationsRaw,
            durationResourceRaw,
            timerEntriesRaw,
            forcePublicValues,
            percentRaw,
            partialFraction,
            displayValue,
            chargedPointMask
        )
            local config = self.gui2ResourceDisplayConfig or {}
            local cellsMode = config.mode == "cells" or config.mode == "dots"
            self.gui2ResourceRechargeActive = rechargeActive == true
            if self.gui2FilteredAuraApplicationDisplay
                and (forcePublicValues == true
                    or self.gui2FilteredAuraApplicationPublicPreview == true) then
                SetFilteredAuraApplicationPublicPreview(
                    self,
                    forcePublicValues == true,
                    cellsMode
                )
            end
            if self.gui2FilteredAuraApplicationDisplay
                and forcePublicValues ~= true
                and self.gui2FilteredAuraApplicationPublicPreview ~= true then
                HideNativeApplicationFills(self, cellsMode)
                return FinishResourceValueUpdate(self, true, true)
            end
            if config.independentCells == true then
                local applied = ApplyIndependentResourceCells(
                    self,
                    value,
                    maxValue,
                    cellReadyRaw,
                    cellDurationsRaw
                )
                if applied and self.resourceValueText then
                    self.resourceValueText:SetText(FormatResourceValue(
                        value,
                        maxValue,
                        self.gui2ResourceValueFormat
                    ))
                end
                return FinishResourceValueUpdate(self, applied)
            end
            if config.durationProgress == true and forcePublicValues ~= true then
                HideResourceRecharge(self)
                HideResourceSecretThresholdLayers(self)
                ApplyResourceBaseColor(self)
                local applied = ApplyResourceDuration(
                    self,
                    durationResourceRaw
                )
                StartResourceTimerMarkers(self, timerEntriesRaw)
                ClearResourceValueText(self.resourceValueText)
                return FinishResourceValueUpdate(self, applied)
            end
            if config.durationProgress == true then
                StopResourceTimerMarkers(self)
            end
            if secret == true then
                self.gui2ResourceHasPublicValues = false
                self.gui2ResourcePublicValue = nil
                self.gui2ResourcePublicMaxValue = nil
                local minOK = true
                local valueOK = true
                local rawColorApplied = false
                local rawColorStyleVerified = false
                if cellsMode then
                    for index = 1, self.gui2ResourceActiveCellCount or 0 do
                        local cell = self.resourceCells[index]
                        if not pcall(
                            cell.statusBar.SetMinMaxValues,
                            cell.statusBar,
                            index - 1,
                            index,
                            GetStatusBarImmediateInterpolation()
                        ) then
                            minOK = false
                        end
                        if not pcall(
                            cell.statusBar.SetValue,
                            cell.statusBar,
                            valueRaw,
                            GetStatusBarImmediateInterpolation()
                        ) then
                            valueOK = false
                        end
                    end
                else
                    minOK = self.resourceStatusBar
                        and self.resourceStatusBar.SetMinMaxValues
                        and pcall(
                            self.resourceStatusBar.SetMinMaxValues,
                            self.resourceStatusBar,
                            0,
                            maxValueRaw,
                            GetStatusBarImmediateInterpolation()
                        ) == true
                    valueOK = SetResourceStatusBarValue(
                        self,
                        self.resourceStatusBar,
                        valueRaw
                    )
                    if self.SetNativeFillShown then
                        self:SetNativeFillShown(valueOK == true)
                    end
                end
                if config.valueKind == "discrete" then
                    ApplyResourceBaseColor(self)
                    ApplyResourceSecretThresholds(
                        self,
                        valueRaw,
                        rechargeActive
                    )
                else
                    HideResourceSecretThresholdLayers(self)
                    if config.thresholdColorEnabled == true then
                        rawColorApplied, rawColorStyleVerified =
                            ApplyResourceRawColor(
                                self,
                                colorRaw
                            )
                        if not rawColorApplied then
                            ApplyResourceBaseColor(self)
                        end
                    end
                end
                ApplyResourceRecharge(
                    self,
                    rechargeDurationRaw,
                    rechargeActive,
                    true,
                    valueRaw,
                    nil
                )
                if self.resourceValueText then
                    SetSecretResourceValueText(
                        self.resourceValueText,
                        valueRaw,
                        percentRaw,
                        self.gui2ResourceValueFormat
                    )
                end
                return FinishResourceValueUpdate(
                    self,
                    minOK and valueOK,
                    rawColorStyleVerified
                )
            end

            value = type(value) == "number" and value or 0
            maxValue = type(maxValue) == "number" and maxValue or 0
            partialFraction = type(partialFraction) == "number"
                and math_max(0, math_min(1, partialFraction)) or 0
            displayValue = type(displayValue) == "number"
                and displayValue or (value + partialFraction)
            self.gui2ResourceHasPublicValues = true
            self.gui2ResourcePublicValue = value
            self.gui2ResourcePublicMaxValue = maxValue
            self.gui2ResourcePartialFraction = partialFraction
            self.gui2ResourceDisplayValue = displayValue
            self.gui2ResourceChargedPointMask = tonumber(chargedPointMask)
            HideResourceSecretThresholdLayers(self)
            ApplyResourcePublicValues(self)
            local rawColorApplied = false
            local rawColorStyleVerified = false
            if config.thresholdColorEnabled == true then
                rawColorApplied, rawColorStyleVerified =
                    ApplyResourceRawColor(self, colorRaw)
                if not rawColorApplied then
                    ApplyResourcePublicThresholdColor(
                        self,
                        value,
                        maxValue,
                        rechargeActive
                    )
                end
            end
            ApplyResourceRecharge(
                self,
                rechargeDurationRaw,
                rechargeActive,
                false,
                nil,
                value
            )
            StartResourcePartialRecharge(self)
            ApplyResourceChargedPointColors(
                self,
                displayValue,
                self.gui2ResourceChargedPointMask
            )
            if self.resourceValueText then
                self.resourceValueText:SetText(FormatResourceValue(
                    displayValue,
                    maxValue,
                    self.gui2ResourceValueFormat
                ))
            end
            return FinishResourceValueUpdate(
                self,
                true,
                rawColorStyleVerified
            )
        end
        frame.ClearResourceValues = function(self)
            StopResourcePartialRecharge(self)
            StopResourceTimerMarkers(self)
            self.gui2ResourceRechargeActive = false
            self.gui2ResourceHasPublicValues = false
            self.gui2ResourcePublicValue = nil
            self.gui2ResourcePublicMaxValue = nil
            self.gui2ResourcePartialFraction = nil
            self.gui2ResourceDisplayValue = nil
            self.gui2ResourceChargedPointMask = nil
            self.gui2ResourceProgressBound = false
            self.gui2ResourceDurationBound = false
            if self.resourceDurationCountdown then
                self.resourceDurationCountdown:Hide()
            end
            if self.resourceStatusBar then
                self.resourceStatusBar:SetMinMaxValues(
                    0,
                    1,
                    GetStatusBarImmediateInterpolation()
                )
                self.resourceStatusBar:SetValue(
                    0,
                    GetStatusBarImmediateInterpolation()
                )
            end
            if self.SetNativeFillShown then
                self:SetNativeFillShown(false)
            end
            for index = 1, self.gui2ResourceActiveCellCount or 0 do
                self.resourceCells[index].statusBar:SetValue(0)
            end
            HideResourceSecretThresholdLayers(self)
            HideResourceRecharge(self)
            self.gui2ResourceRechargeFailure = nil
            self.gui2ResourceRechargeNeedsRetry = false
            self.gui2ResourceRechargeRetryAttempted = false
            ApplyResourceBaseColor(self)
            self:RefreshResourceFillStyle(false)
            ClearResourceValueText(self.resourceValueText)
            if self.gui2FilteredAuraApplicationDisplay then
                local config = self.gui2ResourceDisplayConfig or {}
                SetFilteredAuraApplicationPublicPreview(
                    self,
                    false,
                    config.mode == "cells" or config.mode == "dots"
                )
            end
        end
        frame.ConsumeResourceRechargeRetry = function(self)
            if self.gui2ResourceRechargeNeedsRetry ~= true then return false end
            self.gui2ResourceRechargeNeedsRetry = false
            return true
        end
        frame.RefreshTheme = function(self)
            if baseRefreshTheme then baseRefreshTheme(self) end
            self:RefreshResourceFillStyle(true)
            ApplyResourceBaseColor(self)
            LayoutResourceCells(self)
            self:SetResourceTextAppearance(
                self.gui2ResourceTextAppearance
            )
        end

        frame:SetResourceBarSize(width, height, orientation)
        frame:SetResourceFillDirection(
            reverse and "reverse" or "forward"
        )
        frame:SetResourceBorder(frame.gui2ResourceBorder)
        frame:SetResourceBorderColor(frame.gui2ResourceBorderColor)
        frame:SetResourceBackgroundColor(opts.backgroundColor)
        frame:SetResourceDisplayConfig(opts.display)
        frame:SetResourceTextAppearance(
            frame.gui2ResourceTextAppearance
        )
        return frame
    end

    local function RestoreDurationRingCountdownChrome(frame)
        local textCooldown = frame and frame.durationRingCountdown
        if not textCooldown then return false end
        if textCooldown.SetDrawSwipe then
            textCooldown:SetDrawSwipe(false)
        end
        if textCooldown.SetDrawEdge then
            textCooldown:SetDrawEdge(false)
        end
        if textCooldown.SetDrawBling then
            textCooldown:SetDrawBling(false)
        end
        if textCooldown.SetSwipeColor then
            textCooldown:SetSwipeColor(0, 0, 0, 0)
        end
        return true
    end

    function App:CreateDurationRing(parent, opts)
        opts = type(opts) == "table" and opts or {}
        local size = tonumber(opts.size or opts.diameter) or 52
        local ring = self:CreateCooldownIcon(parent, {
            size = size,
            icon = opts.icon,
            shape = "circle",
            border = "none",
            variant = opts.variant or "bare",
            cooldownText = opts.cooldownText,
            countSink = opts.countSink,
        })
        if not ring then return nil end
        ring.gui2Component = "DurationRing"
        local progressCooldown = ring.cooldown
        ring.durationRingProgress = progressCooldown
        if progressCooldown
            and progressCooldown.SetHideCountdownNumbers then
            progressCooldown:SetHideCountdownNumbers(true)
        end
        ring.gui2DurationReverse = opts.reverse ~= false
        ring.gui2DurationFillColor = opts.fillColor
            or "color.accent.primary"
        ring.gui2DurationTrackColor = opts.trackColor
            or "color.control.track"
        ring.gui2DurationCenterColor = opts.centerColor
            or "color.surface.sunken"
        if progressCooldown and progressCooldown.SetDrawSwipe then
            progressCooldown:SetDrawSwipe(true)
        end
        if progressCooldown and progressCooldown.SetDrawEdge then
            progressCooldown:SetDrawEdge(false)
        end
        if progressCooldown and progressCooldown.SetDrawBling then
            progressCooldown:SetDrawBling(false)
        end
        if ring.icon and ring.icon.Hide then ring.icon:Hide() end
        local track = ring:CreateTexture(nil, "ARTWORK")
        track:SetAllPoints(ring)
        ring.durationRingTrack = track
        ring.durationRingTracks = { track }
        ring.durationRingProgresses = { progressCooldown }

        local function ResolveRingTexture(thickness)
            local paths = GUI2.DurationRingTextures or {}
            thickness = NormalizeDurationRingThickness(thickness)
            if thickness == 4 then return paths.thin end
            if thickness == 8 then return paths.standard end
            if thickness == 14 then return paths.thick end
            return paths.heavy
        end

        local function ConfigureRingProgress(progress, texture)
            if not progress then return end
            if progress.SetDrawSwipe then progress:SetDrawSwipe(true) end
            if progress.SetDrawEdge then progress:SetDrawEdge(false) end
            if progress.SetDrawBling then progress:SetDrawBling(false) end
            if progress.SetHideCountdownNumbers then
                progress:SetHideCountdownNumbers(true)
            end
            if progress.SetSwipeTexture and texture then
                local ok = pcall(
                    progress.SetSwipeTexture,
                    progress,
                    texture,
                    1,
                    1,
                    1,
                    1
                )
                if not ok then
                    pcall(progress.SetSwipeTexture, progress, texture)
                end
            end
        end

        local function RingTextureMatches(region, texture)
            if not (region and region.GetTexture and region.AddMaskTexture) then
                return false
            end
            local ok, current = pcall(region.GetTexture, region)
            if not ok then return false end
            if current == texture then return true end
            if type(current) ~= "string" or type(texture) ~= "string" then
                return false
            end
            current = string.lower((current:gsub("/", "\\")))
            texture = string.lower((texture:gsub("/", "\\")))
            return current == texture
        end

        local function FindRingSwipeTexture(progress, texture)
            if not (progress and progress.GetRegions) then return nil end
            local regions = { pcall(progress.GetRegions, progress) }
            if regions[1] ~= true then return nil end
            for index = 2, #regions do
                if RingTextureMatches(regions[index], texture) then
                    return regions[index]
                end
            end
            return nil
        end

        local function ApplyDynamicRingMaskGeometry(mask, diameter, thickness)
            if not (mask and mask.SetTexCoord) then return false end
            diameter = math_max(1, tonumber(diameter) or 1)
            thickness = math_min(
                NormalizeDurationRingThickness(thickness),
                math_max(0, (diameter * 0.5) - 1)
            )
            local holeRadius = math_max(
                1 / diameter,
                0.5 - (thickness / diameter)
            )
            local uvScale = DURATION_RING_INNER_MASK_RADIUS / holeRadius
            local low = 0.5 - (uvScale * 0.5)
            local high = 0.5 + (uvScale * 0.5)
            local ok = pcall(mask.SetTexCoord, mask, low, high, low, high)
            return ok, thickness
        end

        local function DetachDynamicRingMasks(frame)
            local track = frame.durationRingTrack
            local trackMask = frame.durationRingTrackMask
            if frame.durationRingTrackMaskAttached
                and track and track.RemoveMaskTexture and trackMask then
                pcall(track.RemoveMaskTexture, track, trackMask)
            end
            local swipe = frame.durationRingSwipeTexture
            local swipeMask = frame.durationRingSwipeMask
            if frame.durationRingSwipeMaskAttached
                and swipe and swipe.RemoveMaskTexture and swipeMask then
                pcall(swipe.RemoveMaskTexture, swipe, swipeMask)
            end
            frame.durationRingTrackMaskAttached = false
            frame.durationRingSwipeMaskAttached = false
            frame.durationRingSwipeTexture = nil
            frame.gui2DurationRingMaskActive = false
        end

        local function ConfigureDynamicRingMask(frame)
            local paths = GUI2.DurationRingTextures or {}
            local disc = paths.disc
            local innerMaskTexture = paths.innerMask
            local progress = frame.durationRingProgress
            local track = frame.durationRingTrack
            if not (disc and innerMaskTexture and progress and track
                and frame.CreateMaskTexture
                and progress.CreateMaskTexture
                and track.AddMaskTexture) then
                return false
            end

            ConfigureRingProgress(progress, disc)
            local swipe = FindRingSwipeTexture(progress, disc)
            if not swipe then return false end

            local trackMask = frame.durationRingTrackMask
            if not trackMask then
                trackMask = frame:CreateMaskTexture(nil, "ARTWORK")
                trackMask:SetAllPoints(frame)
                frame.durationRingTrackMask = trackMask
            end
            local swipeMask = frame.durationRingSwipeMask
            if not swipeMask then
                swipeMask = progress:CreateMaskTexture(nil, "ARTWORK")
                swipeMask:SetAllPoints(progress)
                frame.durationRingSwipeMask = swipeMask
            end
            if not (trackMask and swipeMask
                and trackMask.SetTexture and swipeMask.SetTexture) then
                return false
            end
            trackMask:SetTexture(innerMaskTexture)
            swipeMask:SetTexture(innerMaskTexture)

            if frame.durationRingSwipeTexture ~= swipe then
                local oldSwipe = frame.durationRingSwipeTexture
                if frame.durationRingSwipeMaskAttached and oldSwipe
                    and oldSwipe.RemoveMaskTexture then
                    pcall(oldSwipe.RemoveMaskTexture, oldSwipe, swipeMask)
                end
                frame.durationRingSwipeTexture = swipe
                frame.durationRingSwipeMaskAttached = false
            end
            if not frame.durationRingTrackMaskAttached then
                frame.durationRingTrackMaskAttached = pcall(
                    track.AddMaskTexture,
                    track,
                    trackMask
                )
            end
            if not frame.durationRingSwipeMaskAttached then
                frame.durationRingSwipeMaskAttached = pcall(
                    swipe.AddMaskTexture,
                    swipe,
                    swipeMask
                )
            end
            if not (frame.durationRingTrackMaskAttached
                and frame.durationRingSwipeMaskAttached) then
                DetachDynamicRingMasks(frame)
                return false
            end

            local trackOK, resolvedThickness = ApplyDynamicRingMaskGeometry(
                trackMask,
                frame.gui2DurationRingSize,
                frame.gui2DurationRingRequestedThickness
            )
            local swipeOK = ApplyDynamicRingMaskGeometry(
                swipeMask,
                frame.gui2DurationRingSize,
                frame.gui2DurationRingRequestedThickness
            )
            if not (trackOK and swipeOK) then
                DetachDynamicRingMasks(frame)
                return false
            end
            track:SetTexture(disc)
            frame.gui2DurationRingResolvedThickness = resolvedThickness
            frame.gui2DurationRingMaskActive = true
            return true
        end

        local function ForEachRingProgress(frame, callback)
            local progresses = frame.durationRingProgresses or {}
            for index = 1, #progresses do
                callback(progresses[index])
            end
        end

        local function RestoreDurationRingProgress(frame)
            local durationObject = frame.gui2DurationObjectSource
            local duration = tonumber(frame.gui2DurationScalarDuration) or 0
            local hasScalarDuration = durationObject == nil and duration > 0
            local progressOK = durationObject == nil and not hasScalarDuration
            ForEachRingProgress(frame, function(progress)
                if durationObject ~= nil
                    and progress
                    and progress.SetCooldownFromDurationObject then
                    progressOK = pcall(
                        progress.SetCooldownFromDurationObject,
                        progress,
                        durationObject,
                        true
                    ) == true or progressOK
                elseif hasScalarDuration
                    and progress
                    and progress.SetCooldown then
                    progressOK = pcall(
                        progress.SetCooldown,
                        progress,
                        tonumber(frame.gui2DurationScalarStart) or 0,
                        duration,
                        tonumber(frame.gui2DurationScalarModRate) or 1
                    ) == true or progressOK
                elseif progress and progress.Clear then
                    progress:Clear()
                end
            end)
            return progressOK
        end

        ring.RefreshDurationRingTexture = function(self)
            DetachDynamicRingMasks(self)
            local texture = ResolveRingTexture(
                self.gui2DurationRingThickness
            )
            if not texture then return false end
            if self.icon and self.icon.Hide then self.icon:Hide() end
            self.durationRingTrack:SetTexture(texture)
            ConfigureRingProgress(self.durationRingProgress, texture)
            RestoreDurationRingProgress(self)
            if self.RefreshDurationRingColors then
                self:RefreshDurationRingColors()
            end
            return true
        end
        local countdownOverlay = CreateFrame("Frame", nil, ring)
        countdownOverlay:SetAllPoints(ring)
        if countdownOverlay.SetFrameLevel and ring.GetFrameLevel then
            countdownOverlay:SetFrameLevel((ring:GetFrameLevel() or 0) + 5)
        end
        local countdown = CreateFrame(
            "Cooldown",
            nil,
            countdownOverlay,
            "CooldownFrameTemplate"
        )
        countdown:SetAllPoints(countdownOverlay)
        if countdown.SetDrawSwipe then countdown:SetDrawSwipe(false) end
        if countdown.SetDrawEdge then countdown:SetDrawEdge(false) end
        if countdown.SetDrawBling then countdown:SetDrawBling(false) end
        if countdown.SetHideCountdownNumbers then
            countdown:SetHideCountdownNumbers(false)
        end
        ring.durationRingCountdownOverlay = countdownOverlay
        ring.durationRingCountdown = countdown
        ring.cooldown = countdown
        RestoreDurationRingCountdownChrome(ring)
        ring:SetCooldownTextAppearance(opts.cooldownText or {
            enabled = true,
            font = "default",
            size = 14,
            outline = "outline",
            position = "center",
        })
        local function ResolveRingColor(color, fallbackKey)
            if type(color) == "table" then
                return color.r or color[1] or 1,
                    color.g or color[2] or 1,
                    color.b or color[3] or 1,
                    color.a or color[4] or 1
            end
            return GUI2:GetColor(
                type(color) == "string" and color or fallbackKey
            )
        end
        local nameOverlay = CreateFrame("Frame", nil, ring)
        nameOverlay:SetAllPoints(ring)
        if nameOverlay.SetFrameLevel and ring.GetFrameLevel then
            nameOverlay:SetFrameLevel((ring:GetFrameLevel() or 0) + 4)
        end
        local nameText = GUI2:CreateText(
            nameOverlay,
            opts.name or "",
            opts.nameFontSizeKey or "font.size.sm",
            opts.nameColorKey or "color.text.primary",
            "CENTER"
        )
        nameText:SetWordWrap(false)
        ring.durationNameOverlay = nameOverlay
        ring.durationNameText = nameText
        local baseRefreshTheme = ring.RefreshTheme
        ring.SetDurationName = function(self, name)
            self.gui2DurationName = name or ""
            if self.durationNameText then
                self.durationNameText:SetText(self.gui2DurationName)
            end
        end
        ring.SetDurationIcon = function(self)
            -- 圆环是径向进度，不把来源图标重新绘制成圆形图标。
        end
        ring.SetDurationIconAppearance = function(self, appearance)
            -- Duration rings have their own material geometry and no icon
            -- border or mask appearance.
        end
        ring.SetDurationTextAppearance = function(self, appearance)
            if self.SetCooldownTextAppearance then
                self:SetCooldownTextAppearance(appearance or {})
            end
        end
        ring.SetDurationNameAppearance = function(self, appearance)
            appearance = type(appearance) == "table"
                and appearance or {}
            self.gui2DurationNameAppearance = appearance
            self.gui2DurationNamePosition =
                appearance.position or "center"
            if self.durationNameText then
                self.durationNameText:SetShown(appearance.enabled ~= false)
                if GUI2.ApplyFontAppearance then
                    GUI2:ApplyFontAppearance(
                        self.durationNameText,
                        appearance
                    )
                end
                PositionDurationNameText(self)
            end
        end
        ring.SetDurationFillColor = function(self, color)
            self.gui2DurationFillColor = color or "color.accent.primary"
            ForEachRingProgress(self, function(progress)
                if progress and progress.SetSwipeColor then
                    progress:SetSwipeColor(
                        ResolveRingColor(
                            self.gui2DurationFillColor,
                            "color.accent.primary"
                        )
                    )
                end
            end)
        end
        ring.PreviewDurationFillColor = function(self, color)
            self.gui2DurationFillColor = color or "color.accent.primary"
            local r, g, b, a = ResolveRingColor(
                self.gui2DurationFillColor,
                "color.accent.primary"
            )
            local progresses = self.durationRingProgresses or {}
            for index = 1, #progresses do
                local progress = progresses[index]
                if progress and progress.SetSwipeColor then
                    progress:SetSwipeColor(r, g, b, a)
                end
            end
            return true
        end
        ring.PreviewDurationTrackColor = function(self, color)
            self.gui2DurationTrackColor = color or "color.control.track"
            local r, g, b, a = ResolveRingColor(
                self.gui2DurationTrackColor,
                "color.control.track"
            )
            local tracks = self.durationRingTracks or {}
            for index = 1, #tracks do
                local track = tracks[index]
                if track and track.SetVertexColor then
                    track:SetVertexColor(r, g, b, a)
                end
            end
            return true
        end
        ring.RefreshDurationRingColors = function(self)
            local tracks = self.durationRingTracks or {}
            for index = 1, #tracks do
                local bandTrack = tracks[index]
                if bandTrack and bandTrack.SetVertexColor then
                    bandTrack:SetVertexColor(
                        ResolveRingColor(
                            self.gui2DurationTrackColor,
                            "color.control.track"
                        )
                    )
                end
                if bandTrack and bandTrack.SetDesaturated then
                    bandTrack:SetDesaturated(
                        self.gui2DurationDesaturated == true
                    )
                end
            end
            self:SetDurationFillColor(self.gui2DurationFillColor)
        end
        ring.SetDurationDesaturated = function(self, desaturated)
            desaturated = desaturated == true
            if self.gui2DurationDesaturated == desaturated then
                return false
            end
            self.gui2DurationDesaturated = desaturated
            self:RefreshDurationRingColors()
            return true
        end
        ring.SetDurationObject = function(self, durationObject, reverse)
            self.gui2DurationReverse = reverse ~= false
            self.gui2DurationObjectSource = durationObject
            self.gui2DurationScalarStart = nil
            self.gui2DurationScalarDuration = nil
            self.gui2DurationScalarModRate = nil
            local progressOK = RestoreDurationRingProgress(self)
            if progressOK then
                self:RefreshDurationRingColors()
            end
            local textOK = self:SetCooldownDurationObject(durationObject)
            RestoreDurationRingCountdownChrome(self)
            return progressOK or textOK
        end
        ring.SetDurationFromTimes = function(
            self,
            startTime,
            duration,
            modRate
        )
            duration = tonumber(duration) or 0
            if duration <= 0 then
                self:ClearDuration()
                return true
            end
            self.gui2DurationObjectSource = nil
            self.gui2DurationScalarStart = tonumber(startTime) or 0
            self.gui2DurationScalarDuration = duration
            self.gui2DurationScalarModRate = tonumber(modRate) or 1
            RestoreDurationRingProgress(self)
            self:RefreshDurationRingColors()
            self:SetCooldown(
                self.gui2DurationScalarStart,
                duration,
                self.gui2DurationScalarModRate
            )
            RestoreDurationRingCountdownChrome(self)
            return true
        end
        ring.ClearDuration = function(self)
            self.gui2DurationObjectSource = nil
            self.gui2DurationScalarStart = nil
            self.gui2DurationScalarDuration = nil
            self.gui2DurationScalarModRate = nil
            ForEachRingProgress(self, function(progress)
                if progress and progress.Clear then progress:Clear() end
            end)
            self:SetCooldownDurationObject(nil)
            self:SetCooldown(0, 0)
            RestoreDurationRingCountdownChrome(self)
        end
        ring.ResolveDurationRingMetrics = function(
            self,
            nextSize,
            thickness,
            referenceSize,
            forcedThickness
        )
            return ResolveDurationRingMaterialMetrics(
                thickness
                    or self.gui2DurationRingRequestedThickness
                    or 8,
                nextSize or self.gui2DurationRingSize or size,
                referenceSize
                    or self.gui2DurationRingReferenceSize
                    or nextSize
                    or self.gui2DurationRingSize
                    or size,
                forcedThickness
            )
        end
        ring.ResolveConcentricDurationRingMetrics = function(
            self,
            previousOuterRadius,
            gap,
            thickness,
            referenceSize
        )
            return ResolveConcentricDurationRingMetrics(
                previousOuterRadius,
                gap,
                thickness
                    or self.gui2DurationRingRequestedThickness
                    or 8,
                referenceSize
                    or self.gui2DurationRingReferenceSize
                    or self.gui2DurationRingSize
                    or size
            )
        end
        ring.SetDurationRingSize = function(
            self,
            nextSize,
            border,
            thickness,
            referenceSize,
            forcedThickness
        )
            local resolvedSize = tonumber(nextSize) or size
            self.gui2DurationRingSize = resolvedSize
            self.gui2DurationRingRequestedThickness =
                NormalizeDurationRingThickness(
                    thickness
                        or self.gui2DurationRingRequestedThickness
                        or 8
                )
            self.gui2DurationRingReferenceSize =
                tonumber(referenceSize) or resolvedSize
            self.gui2DurationRingThickness,
                self.gui2DurationRingResolvedThickness,
                self.gui2DurationRingTargetThickness,
                self.gui2DurationRingOuterRadius =
                    self:ResolveDurationRingMetrics(
                        resolvedSize,
                        self.gui2DurationRingRequestedThickness,
                        self.gui2DurationRingReferenceSize,
                        forcedThickness
                    )
            if self.SetIconAppearance then
                self:SetIconAppearance({
                    size = resolvedSize,
                    shape = "circle",
                    border = "none",
                })
            end
            self:RefreshDurationRingTexture()
            PositionDurationNameText(self)
        end
        ring.SetDurationRingStyle = function(self, style)
            style = type(style) == "table" and style or {}
            self.gui2DurationTrackColor =
                style.trackColor or self.gui2DurationTrackColor
            self.gui2DurationCenterColor =
                style.centerColor or self.gui2DurationCenterColor
            self.gui2DurationRingDirection =
                style.direction == "counterclockwise"
                    and "counterclockwise" or "clockwise"
            self.gui2DurationRingStart = style.start or "top"
            self:SetDurationRingSize(
                self.gui2DurationRingSize or size,
                style.border or self.gui2IconBorder,
                style.thickness,
                self.gui2DurationRingReferenceSize
                    or self.gui2DurationRingSize
                    or size
            )
            local rotations = {
                top = 0,
                right = math.pi * 0.5,
                bottom = math.pi,
                left = math.pi * 1.5,
            }
            ForEachRingProgress(self, function(progress)
                if progress and progress.SetReverse then
                    progress:SetReverse(
                        self.gui2DurationRingDirection
                            == "counterclockwise"
                    )
                end
                if progress and progress.SetRotation then
                    progress:SetRotation(
                        rotations[self.gui2DurationRingStart] or 0
                    )
                end
            end)
            self:RefreshDurationRingTexture()
            RestoreDurationRingCountdownChrome(self)
        end
        ring.RefreshTheme = function(self)
            if baseRefreshTheme then baseRefreshTheme(self) end
            self:RefreshDurationRingTexture()
            RestoreDurationRingCountdownChrome(self)
            self:SetDurationNameAppearance(
                self.gui2DurationNameAppearance
            )
        end
        ring:SetDurationNameAppearance(opts.nameText or {
            enabled = true,
            font = "default",
            size = 12,
            outline = "outline",
            position = "center",
        })
        ring:SetDurationRingStyle({
            border = opts.border or opts.iconBorder,
            thickness = opts.thickness or opts.ringThickness,
            direction = opts.direction or opts.ringDirection,
            start = opts.start or opts.ringStart,
            trackColor = opts.trackColor,
            centerColor = opts.centerColor,
        })
        return ring
    end
end

local function CreateActionTag(parent, text, tone)
    local tag = GUI2:CreatePanel(parent, {
        width = tone == "secure" and 62 or 54,
        height = 18,
        surface = tone == "secure" and "color.accent.soft" or "color.surface.sunken",
        border = tone == "secure" and "color.border.accent" or "color.border.subtle",
    })
    local label = GUI2:CreateText(tag, text, "font.size.sm", tone == "secure" and "color.text.accent" or "color.text.secondary")
    label:SetPoint("CENTER")
    tag.text = label
    return tag
end

function App:CreateActionList(parent, opts)
    opts = opts or {}
    local items = opts.items or {}
    local width = opts.width or 300
    local rowHeight = opts.rowHeight or 30
    local height = opts.height or ((#items * rowHeight) + 18)
    local frame = GUI2:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    frame.gui2Component = "ActionList"
    frame.rows = {}

    for i, item in ipairs(items) do
        local row = GUI2:CreatePanel(frame, {
            width = width - 16,
            height = rowHeight - 4,
            surface = item.selected and "color.control.active" or "color.surface.raised",
            border = item.selected and "color.border.accent" or "color.border.subtle",
        })
        row:SetPoint("TOPLEFT", 8, -8 - ((i - 1) * rowHeight))

        local iconSize = item.iconSize or opts.iconSize or 18
        local icon = GUI2:CreateIconSlot(row, {
            size = iconSize,
            icon = item.icon,
            shape = "rounded",
            disabled = item.disabled,
        })
        icon:SetPoint("LEFT", 4, 0)

        local text = GUI2:CreateText(row, item.text or "Action", "font.size.sm", item.disabled and "color.text.disabled" or "color.text.primary")
        text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        text:SetPoint("RIGHT", -74, 0)
        text:SetWordWrap(false)

        local action = item.action or {}
        local secure = action.kind and action.kind ~= "custom"
        local tag = CreateActionTag(row, secure and "安全" or "普通", secure and "secure" or "custom")
        tag:SetPoint("RIGHT", -6, 0)

        row.icon = icon
        row.text = text
        row.tag = tag
        frame.rows[i] = row
    end

    return frame
end

function App:CreateBarItem(parent, opts)
    opts = opts or {}
    local width = opts.width or 250
    local height = opts.height or 38
    local clickable = opts.clickable or opts.onClick ~= nil
    local hoverable = opts.hoverable ~= false
    local variant = opts.variant or "surface"
    local button

    if variant == "bare" then
        button = CreateFrame(clickable and "Button" or "Frame", opts.name, parent)
        button:SetSize(width, height)
    else
        button = CreateSurface(parent, {
            width = width,
            height = height,
            surface = "color.surface.raised",
            border = opts.selected and "color.border.accent" or "color.border.default",
        }, clickable and "Button" or "Frame")
    end

    button.gui2Component = "BarItem"
    button.gui2Variant = variant
    ConfigureMotion(button, opts)
    button.gui2TextColorKey = opts.textColorKey or "color.text.primary"
    button.gui2ValueColorKey = ToneColorKey(opts.tone, opts.valueColorKey or "color.text.secondary")
    button.gui2HoverSurfaceToken = opts.hoverSurface or "color.baritem.hover"
    button.gui2HoverBorderToken = opts.hoverBorder or "color.baritem.hoverBorder"
    button.gui2HoverTextColorKey = opts.hoverTextColorKey or "color.baritem.hoverText"
    button.gui2HoverIcon = opts.hoverIcon ~= false
    button.gui2Selected = opts.selected and true or false

    local showIcon = opts.showIcon
    if showIcon == nil then
        showIcon = opts.icon ~= false and opts.iconSize ~= 0
    end

    local icon
    if showIcon then
        icon = GUI2:CreateIconSlot(button, {
            size = opts.iconSize or 28,
            icon = opts.icon,
            shape = opts.iconShape or "rounded",
            variant = opts.iconVariant,
            padding = opts.iconPadding,
            selected = opts.selected,
        })
        icon:SetPoint("LEFT", opts.iconLeftPadding or 6, 0)
        button.iconSlot = icon
        InheritMotion(icon, button)
        if icon.icon then InheritMotion(icon.icon, button) end
    end

    if opts.text ~= false then
        local text = GUI2:CreateText(button, opts.text or "YBar item", opts.textFontSizeKey or "font.size.md", button.gui2TextColorKey)
        if icon then
            text:SetPoint("LEFT", icon, "RIGHT", opts.gap or 8, 0)
        else
            text:SetPoint("LEFT", opts.textLeftPadding or 0, 0)
        end
        text:SetPoint("RIGHT", opts.value ~= false and -64 or -(opts.textRightPadding or 0), 0)
        text:SetWordWrap(false)
        button.text = text
        button.gui2OwnText = true
    end

    if opts.value ~= false then
        local value = GUI2:CreateText(button, opts.value or "", opts.valueFontSizeKey or "font.size.sm", button.gui2ValueColorKey, "RIGHT")
        value:SetPoint("RIGHT", -(opts.valueRightPadding or 8), 0)
        button.value = value
        button.gui2OwnValue = true
    end

    button.SetState = function(self, state)
        state = state or "normal"
        self.gui2State = state
        if state ~= "hover" then
            self.gui2Selected = state == "selected"
        end

        local surface = "color.surface.raised"
        local border = "color.border.default"
        local textColor = self.gui2TextColorKey or "color.text.primary"
        local valueColor = self.gui2ValueColorKey or "color.text.secondary"
        local iconState = "normal"

        if state == "hover" then
            surface = self.gui2HoverSurfaceToken or "color.baritem.hover"
            border = self.gui2HoverBorderToken or "color.baritem.hoverBorder"
            textColor = self.gui2HoverTextColorKey or "color.baritem.hoverText"
            valueColor = self.gui2HoverTextColorKey or "color.baritem.hoverText"
            iconState = "hover"
        elseif state == "selected" then
            surface = "color.control.active"
            border = "color.border.accent"
            textColor = "color.text.accent"
            iconState = "selected"
        end

        if self.gui2Variant ~= "bare" then
            ApplySurface(self, surface)
            GUI2:SetBorderColor(self, border)
        end
        if self.gui2OwnText and self.text then
            self.text:SetTextColor(GUI2:GetColor(textColor))
        end
        if self.gui2OwnValue and self.value then
            self.value:SetTextColor(GUI2:GetColor(valueColor))
        end
        if self.iconSlot and self.iconSlot.SetState and self.gui2HoverIcon then
            self.iconSlot:SetState(iconState)
            if state == "hover" and self.iconSlot.gui2Variant ~= "bare" then
                ApplySurface(self.iconSlot, surface)
                GUI2:SetBorderColor(self.iconSlot, border)
            end
        end
    end

    button.RefreshTheme = function(self)
        self:SetState(self.gui2State or (self.gui2Selected and "selected" or "normal"))
    end

    if opts.onClick then
        button:RegisterForClicks(opts.clicks or "AnyUp")
        button:SetScript("OnClick", opts.onClick)
    end
    if hoverable and button.EnableMouse then
        button:EnableMouse(true)
        button:SetScript("OnEnter", function(frame)
            frame:SetState("hover")
        end)
        button:SetScript("OnLeave", function(frame)
            frame:SetState(frame.gui2Selected and "selected" or "normal")
        end)
    end

    button:SetState(opts.selected and "selected" or (opts.state or "normal"))
    return button
end

local function NormalizeModSwitchEffectiveState(value, reason, tone)
    if type(value) == "table" then
        if value.effective == false then
            return {
                effective = false,
                reason = value.reason or value.message or reason or "该组件当前未生效。",
                tone = value.tone or tone or "warning",
            }
        end
        return { effective = true }
    end
    if value == false then
        return {
            effective = false,
            reason = reason or "该组件当前未生效。",
            tone = tone or "warning",
        }
    end
    return { effective = true }
end

local function ResolveModSwitchEffectiveState(item)
    if type(item.getEffectiveState) ~= "function" then
        return { effective = true }
    end
    local ok, value, reason, tone = pcall(item.getEffectiveState)
    if not ok then
        return {
            effective = false,
            reason = "状态检查失败：" .. tostring(value),
            tone = "danger",
        }
    end
    return NormalizeModSwitchEffectiveState(value, reason, tone)
end

local function ModSwitchStateColor(tone)
    return "color.state.warning"
end

local function ApplyModSwitchImageTextShadow(region)
    if not region or not region.SetShadowColor then
        return
    end
    region:SetShadowColor(0, 0, 0, 0.86)
    region:SetShadowOffset(1, -1)
end

function App:CreateModSwitch(parent, item)
    if not parent or not item then return end
    BindConfigItem(item)

    local width = item.width or 150
    local height = item.height or 80
    local container = CreateSurface(parent, {
        width = width,
        height = height,
        surface = "color.surface.raised",
        border = "color.border.default",
    }, "Button")
    container.gui2Component = "ModSwitch"
    ConfigureMotion(container, item)
    if container.EnableMouse then container:EnableMouse(true) end
    if container.RegisterForClicks then container:RegisterForClicks("AnyUp") end
    container.motionOverlay = CreateCenteredMotionOverlay(container, width, height)
    InheritMotion(container.motionOverlay, container)

    local imageSource = item.image or item.texture
    if imageSource then
        local image = GUI2:CreateTexture(container, {
            layer = item.imageLayer or "BORDER",
            subLevel = item.imageSubLevel or -8,
            texture = imageSource,
        })
        local imageInset = item.imageInset or item.imagePadding or 0
        image:SetPoint("TOPLEFT", imageInset, -imageInset)
        image:SetPoint("BOTTOMRIGHT", -imageInset, imageInset)
        if item.imageTexCoords or item.texCoords then
            image:SetTexCoord(unpack(item.imageTexCoords or item.texCoords))
        elseif item.imageCrop ~= false and item.crop ~= false then
            image:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        container.image = image
        InheritMotion(image, container)

        local imageShade = container:CreateTexture(nil, item.imageShadeLayer or "ARTWORK", nil, item.imageShadeSubLevel or -8)
        imageShade:SetAllPoints(image)
        imageShade:SetColorTexture(0, 0, 0, 0.12)
        container.imageShade = imageShade
        InheritMotion(imageShade, container)
    end

    local title = GUI2:CreateText(container, item.label or item.name or "", "font.size.md", "color.text.heading")
    title:SetPoint("TOP", 0, -6)
    title:SetPoint("LEFT", 8, 0)
    title:SetPoint("RIGHT", -8, 0)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    if imageSource then
        ApplyModSwitchImageTextShadow(title)
    end
    container.title = title

    local descTop = -27
    if item.showTags == true and type(item.tags) == "table" and #item.tags > 0 then
        local visibleTags = {}
        for i = 1, math.min(#item.tags, 3) do
            visibleTags[#visibleTags + 1] = item.tags[i]
        end
        local tagLine = GUI2:CreateText(container, table.concat(visibleTags, " / "), "font.size.xs", "color.text.muted")
        tagLine:SetPoint("TOPLEFT", 10, -25)
        tagLine:SetPoint("RIGHT", -10, 0)
        tagLine:SetJustifyH("CENTER")
        tagLine:SetWordWrap(false)
        if imageSource then
            ApplyModSwitchImageTextShadow(tagLine)
        end
        container.tagLine = tagLine
        descTop = -43
    end

    if item.text and item.text ~= "" then
        local desc = GUI2:CreateText(container, item.text, "font.size.sm", "color.text.secondary")
        desc:SetPoint("TOPLEFT", 10, descTop)
        desc:SetPoint("RIGHT", -10, 0)
        desc:SetHeight(math.max(height + descTop - 30, 18))
        desc:SetWordWrap(true)
        desc:SetJustifyH("CENTER")
        if imageSource then
            ApplyModSwitchImageTextShadow(desc)
        end
        container.desc = desc
    end

    if item.isBeta == true then
        local betaText = GUI2:CreateText(container, item.betaLabel or "测试版", item.betaFontSize or 22, item.betaColorKey or "color.state.error")
        betaText:SetPoint("CENTER", 0, item.betaOffsetY or -1)
        betaText:SetWidth(math.max(width - 16, 40))
        betaText:SetJustifyH("CENTER")
        betaText:SetWordWrap(false)
        if betaText.SetFont and GUI2.GetFont then
            betaText:SetFont(GUI2:GetFont("font.family.heading"), item.betaFontSize or 22, "OUTLINE")
        end
        ApplyModSwitchImageTextShadow(betaText)
        container.betaText = betaText
        InheritMotion(betaText, container)
    end

    local status = GUI2:CreateText(container, "", "font.size.sm", "color.state.success")
    status:SetPoint("BOTTOM", 0, 7)
    status:SetJustifyH("CENTER")
    status:SetWordWrap(false)
    if status.SetShadowColor then
        status:SetShadowColor(0, 0, 0, 0.75)
        status:SetShadowOffset(1, -1)
    end
    container.statusLabel = status
    InheritMotion(status, container)

    if item.settingsClick then
        local settingsOptions = {
            size = item.settingsButtonSize or 22,
            tooltip = item.settingsTooltip or "设置",
            onClick = function()
                item.settingsClick()
            end,
        }
        local hasExplicitTexture = item.settingsButtonAtlas or item.settingsButtonTexture or item.settingsButtonIcon
        local settingsButton
        if hasExplicitTexture then
            settingsOptions.atlas = item.settingsButtonAtlas
            settingsOptions.texture = item.settingsButtonTexture or item.settingsButtonIcon
            settingsOptions.texCoords = item.settingsButtonTexCoords or item.settingsButtonTexCoord
            settingsOptions.crop = item.settingsButtonCrop
            settingsButton = GUI2:CreateBlizzardIconButton(container, settingsOptions)
        else
            settingsOptions.size = item.settingsButtonSize or 22
            settingsOptions.component = "ModSwitchSettingsButton"
            settingsOptions.iconName = item.settingsButtonMicroIcon or "settings"
            settingsOptions.microIconSize = item.settingsButtonMicroIconSize or 20
            settingsOptions.padding = item.settingsButtonPadding or 1
            settingsOptions.iconPixelPolicy = item.settingsButtonIconPixelPolicy
            settingsButton = GUI2:CreateBareMicroIconButton(container, settingsOptions)
        end
        settingsButton:SetPoint("BOTTOMRIGHT", -4, 4)
        settingsButton:SetFrameLevel(container:GetFrameLevel() + 4)
        container.settingsButton = settingsButton
    end

    function container:RefreshState()
        local enabled = self.gui2Value == true
        local effectiveState = enabled and ResolveModSwitchEffectiveState(item) or { effective = true }
        local ineffective = enabled and effectiveState and effectiveState.effective == false
        self.gui2EffectiveState = effectiveState
        self.gui2Ineffective = ineffective
        local hasImage = self.image ~= nil

        local surface
        if hasImage then
            surface = "color.surface.raised"
        elseif ineffective then
            surface = self.gui2Hover and "color.surface.raised" or "color.surface.sunken"
        else
            surface = enabled and ResolveThemeToken("color.modswitch.active", "color.control.active") or "color.surface.sunken"
            if self.gui2Hover then
                surface = enabled and ResolveThemeToken("color.modswitch.activeHover", "color.control.hover") or "color.surface.raised"
            end
        end
        ApplySurface(self, surface)
        GUI2:SetBorderColor(self, ineffective and ModSwitchStateColor(effectiveState.tone) or (enabled and "color.border.accent" or (self.gui2Hover and "color.border.default" or "color.border.subtle")))
        if self.title then
            GUI2:SetTextColorKey(self.title, enabled and "color.text.heading" or "color.text.secondary")
        end
        if self.desc then
            GUI2:SetTextColorKey(self.desc, enabled and "color.text.secondary" or "color.text.muted")
        end
        if self.tagLine then
            GUI2:SetTextColorKey(self.tagLine, ineffective and ModSwitchStateColor(effectiveState.tone) or (enabled and "color.text.accent" or "color.text.muted"))
        end
        if self.betaText then
            GUI2:SetTextColorKey(self.betaText, item.betaColorKey or "color.state.error")
            self.betaText:SetAlpha(item.betaAlpha or 0.95)
        end
        if self.statusLabel then
            self.statusLabel:SetText(ineffective and (item.ineffectiveLabel or "未生效") or (enabled and (item.onLabel or "已开启") or (item.offLabel or "已禁用")))
            GUI2:SetTextColorKey(self.statusLabel, ineffective and ModSwitchStateColor(effectiveState.tone) or (enabled and "color.state.success" or "color.text.muted"))
        end
        if self.image then
            self.image:SetAlpha(ineffective and (item.ineffectiveImageAlpha or 0.56) or (enabled and (item.imageAlpha or 1) or (item.disabledImageAlpha or 0.26)))
            if self.image.SetDesaturated then
                self.image:SetDesaturated(not enabled or ineffective)
            end
        end
        if self.imageShade then
            self.imageShade:SetAlpha(ineffective and 0.38 or (enabled and 0.10 or 0.62))
        end
    end

    function container:SetValue(value, silent)
        local isSilent, animate = ParseSetOptions(silent)
        local previous = self.gui2Value
        self.gui2Value = value == true
        if not isSilent then
            if item.set then item.set(self.gui2Value) end
            if item.onChange then item.onChange(self, self.gui2Value) end
        end
        self:RefreshState()
        if animate and previous ~= nil and previous ~= self.gui2Value then
            PlayCenteredMotionOverlay(self, "modswitch-toggle")
            if self.statusLabel and GUI2.PlayControlMotion then
                GUI2:PlayControlMotion(self.statusLabel, "modswitch-status", {
                    owner = self,
                    durationKey = "quick",
                    effects = {
                        { type = "alpha", from = 0.2, to = 1 },
                    },
                })
            end
        end
    end

    container.RefreshTheme = function(frame)
        frame:RefreshState()
    end

    container:SetScript("OnClick", function(frame)
        local nextValue = not frame.gui2Value
        if nextValue == true and type(item.confirmEnable) == "function" then
            local committed
            local function commit()
                if committed then return end
                committed = true
                if frame and frame.SetValue then
                    frame:SetValue(true)
                end
            end
            local ok, handled = pcall(item.confirmEnable, frame, commit)
            if not ok then
                print("|cffff0000YUI Component Error:|r " .. tostring(handled))
                return
            end
            if handled ~= false then
                return
            end
        end
        frame:SetValue(nextValue)
    end)

    container:SetScript("OnEnter", function(frame)
        frame.gui2Hover = true
        frame:RefreshState()
        if item.tooltip then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(item.label or item.name or "")
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(item.tooltip, 1, 1, 1, true)
            if frame.gui2Ineffective and frame.gui2EffectiveState and frame.gui2EffectiveState.reason then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("未生效：" .. tostring(frame.gui2EffectiveState.reason), 1, 0.82, 0, true)
            end
            GameTooltip:Show()
        end
    end)
    container:SetScript("OnLeave", function(frame)
        frame.gui2Hover = false
        frame:RefreshState()
        YUI.HideGameTooltip()
    end)

    local currentValue = item.default
    if item.get then currentValue = item.get() end
    container.gui2Value = currentValue == true
    container:RefreshState()
    GUI2:RegisterThemeObject(container)
    return container
end

local function IconPickerTrim(value)
    value = tostring(value or "")
    return (string_gsub(value, "^%s+", ""):gsub("%s+$", ""))
end

local function IconPickerNormalizeQuery(value)
    local valueType = type(value)
    if value == nil then
        return ""
    end
    if valueType == "string" or valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end
    if (valueType == "table" or valueType == "userdata") and value.GetText then
        local ok, text = pcall(value.GetText, value)
        if ok then
            return tostring(text or "")
        end
    end
    return ""
end

local function IconPickerShortLabel(value, maxLen)
    value = tostring(value or "")
    maxLen = maxLen or 32
    if #value <= maxLen then return value end
    local tail = string_match(value, "([^\\/:]+)$") or value
    if #tail <= maxLen then return tail end
    return tail:sub(1, math_max(maxLen - 3, 1)) .. "..."
end

local function IconPickerLooksLikeIconPath(value)
    return type(value) == "string"
        and (value:find("\\", 1, true) or value:find("/", 1, true) or value:find("^Interface") or value:find("%.") or value:find("^atlas:"))
end

local function IconPickerSetText(fontString, text)
    if fontString and fontString.SetText then
        fontString:SetText(text or "")
    end
end

local function IconPickerJoinMessage(primary, secondary)
    if primary and primary ~= "" and secondary and secondary ~= "" then
        return primary .. " / " .. secondary
    end
    return primary or secondary
end

local function IconPickerAddCandidate(rows, seen, group, label, value, icon, source, extra)
    if value == nil or value == "" then return end
    group = group or "其他"
    local key = group .. ":" .. type(value) .. ":" .. tostring(value)
    if seen[key] then return end
    seen[key] = true
    local row = {
        group = group,
        label = label or tostring(value),
        value = value,
        icon = icon or value,
        source = source or group,
    }
    if type(extra) == "table" then
        for extraKey, extraValue in pairs(extra) do
            row[extraKey] = extraValue
        end
    end
    rows[#rows + 1] = row
end

local function IconPickerSpellAPI()
    return YUI.API and YUI.API.Spell or YUI.WOW_API
end

local function IconPickerItemAPI()
    return YUI.API and YUI.API.Item or YUI.WOW_API
end

local function IconPickerIconAPI()
    return YUI.API and YUI.API.Icons or YUI.WOW_API and YUI.WOW_API.Icons
end

local function IconPickerGetSpellInfo(value)
    local spellAPI = IconPickerSpellAPI()
    if spellAPI and spellAPI.GetInfo then
        local ok, info = pcall(spellAPI.GetInfo, value)
        if ok and type(info) == "table" and info.name then
            local texture = info.originalIconID or info.iconID
            if spellAPI.GetTexture then
                local okTexture, result = pcall(spellAPI.GetTexture, value)
                if okTexture and result then texture = result end
            end
            return info.name, texture, info.spellID or value
        end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, value)
        if ok and type(info) == "table" and info.name then
            local texture = info.iconID
            if C_Spell.GetSpellTexture then
                local okTexture, result = pcall(C_Spell.GetSpellTexture, value)
                if okTexture and result then texture = result end
            end
            return info.name, texture, info.spellID or value
        end
    end
    if GetSpellInfo then
        local ok, name, _, icon, _, _, spellID = pcall(GetSpellInfo, value)
        if ok and name then return name, icon, spellID or value end
    end
    return nil
end

local function IconPickerGetItemInfo(itemID)
    local itemAPI = IconPickerItemAPI()
    local icon, name
    if itemAPI and itemAPI.GetIcon then
        local okIcon, result = pcall(itemAPI.GetIcon, itemID)
        if okIcon then icon = result end
    end
    if itemAPI and itemAPI.GetNameByID then
        local okName, result = pcall(itemAPI.GetNameByID, itemID)
        if okName then name = result end
    elseif itemAPI and itemAPI.GetName then
        local okName, result = pcall(itemAPI.GetName, itemID)
        if okName then name = result end
    end
    if not icon and C_Item and C_Item.GetItemIconByID then
        local okIcon, result = pcall(C_Item.GetItemIconByID, itemID)
        if okIcon then icon = result end
    end
    if not name and C_Item and C_Item.GetItemNameByID then
        local okName, result = pcall(C_Item.GetItemNameByID, itemID)
        if okName then name = result end
    end
    if not name and itemAPI and itemAPI.RequestLoadDataByID then
        pcall(itemAPI.RequestLoadDataByID, itemID)
    end
    return name, icon, itemID
end

local function IconPickerGetNameCacheStatus()
    local spellAPI = IconPickerSpellAPI()
    if spellAPI and spellAPI.GetNameCacheStatus then
        local ok, status = pcall(spellAPI.GetNameCacheStatus)
        if ok and type(status) == "table" then return status end
    end
    return nil
end

local function IconPickerDebug(message)
    if not (YUI and YUI.IsDev and type(YUI.Debug) == "function") then
        return
    end
    pcall(YUI.Debug, YUI, message)
end

local function IconPickerMemorySuffix()
    if not (YUI and YUI.IsDev) then
        return ""
    end
    local memoryKB
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        pcall(UpdateAddOnMemoryUsage)
        local addonName = YUI.AddonName
        if addonName then
            local ok, usage = pcall(GetAddOnMemoryUsage, addonName)
            if ok and type(usage) == "number" then
                memoryKB = math_floor(usage + 0.5)
            end
        end
    end
    if not memoryKB and collectgarbage then
        local ok, usage = pcall(collectgarbage, "count")
        if ok and type(usage) == "number" then
            memoryKB = math_floor(usage + 0.5)
        end
    end
    return memoryKB and string_format(" mem=%dKB", memoryKB) or ""
end

local function IconPickerCacheState(status)
    if type(status) ~= "table" then
        return "idle"
    end
    if status.state then
        return tostring(status.state)
    end
    if status.error then
        return "error"
    end
    if status.complete then
        return "complete"
    end
    if status.building then
        return "building"
    end
    return "idle"
end

local function IconPickerFormatCacheStatus(status)
    if not status or not status.available then return nil end
    if status.complete then return nil end
    if status.building then
        local progress = math_min(math_max(tonumber(status.progress) or 0, 0), 1)
        return string_format("技能名索引构建中 %d%%，可搜索已缓存结果。", math_floor(progress * 100))
    end
    return "技能名索引尚未完成。"
end

local function IconPickerEnsureNameCacheStarted()
    local spellAPI = IconPickerSpellAPI()
    if not spellAPI then return nil, false end
    local status, acquired
    if spellAPI.AcquireNameCacheOwner then
        local ok, result = pcall(spellAPI.AcquireNameCacheOwner, ICON_PICKER_CACHE_OWNER, { priority = "background" })
        if ok and type(result) == "table" then
            status = result
            acquired = true
        end
    end
    if spellAPI.GetNameCacheStatus then
        local ok, result = pcall(spellAPI.GetNameCacheStatus)
        if ok and type(result) == "table" then status = result end
    end
    IconPickerDebug(string_format(
        "IconPickerCache | open owner=%s status=%s ownerCount=%s%s",
        ICON_PICKER_CACHE_OWNER,
        IconPickerCacheState(status),
        tostring(status and status.ownerCount or (acquired and 1 or 0)),
        IconPickerMemorySuffix()
    ))
    if status and (status.complete or status.building or status.error) then
        return status, acquired
    end
    if spellAPI.EnsureNameCache then
        local ok, result = pcall(spellAPI.EnsureNameCache, { reason = "icon-picker-open", priority = "background" })
        if ok and type(result) == "table" then
            return result, acquired
        end
    end
    return status, acquired
end

local function IconPickerReleaseNameCacheOwner()
    local spellAPI = IconPickerSpellAPI()
    if not spellAPI or not spellAPI.ReleaseNameCacheOwner then
        return nil
    end

    local ok, status = pcall(spellAPI.ReleaseNameCacheOwner, ICON_PICKER_CACHE_OWNER, {
        delay = ICON_PICKER_CACHE_RELEASE_DELAY,
        reason = "icon-picker-close",
    })
    if not ok or type(status) ~= "table" then
        status = IconPickerGetNameCacheStatus()
    end

    IconPickerDebug(string_format(
        "IconPickerCache | release scheduled delay=%ds ownerCount=%s names=%s records=%s%s",
        ICON_PICKER_CACHE_RELEASE_DELAY,
        tostring(status and status.ownerCount or 0),
        tostring(status and status.nameCount or 0),
        tostring(status and status.recordCount or 0),
        IconPickerMemorySuffix()
    ))
    return status
end

local function IconPickerIsAsciiSingleChar(query)
    query = IconPickerTrim(query or "")
    if #query ~= 1 then return false end
    local byte = query:byte(1)
    return byte ~= nil and byte < 128 and tonumber(query) == nil
end

local function IconPickerBuildCandidates(query, currentValue, recent, seen)
    local rows = {}
    seen = seen or {}
    local meta = {
        hasIndex = false,
        indexTotal = 0,
        truncated = false,
        message = nil,
        cacheStatus = IconPickerGetNameCacheStatus(),
        needsIconSearch = false,
        needsSpellSearch = false,
        heavySearchSkipped = false,
    }
    query = IconPickerTrim(query or "")

    local icons = IconPickerIconAPI()
    if icons and icons.HasTextureIndex then
        local ok, hasIndex = pcall(icons.HasTextureIndex)
        meta.hasIndex = ok and hasIndex == true
    end

    if query == "" then
        IconPickerAddCandidate(rows, seen, "当前/最近", "当前图标", currentValue or DEFAULT_ICON_PICKER_ICON, currentValue or DEFAULT_ICON_PICKER_ICON, "当前值")
        IconPickerAddCandidate(rows, seen, "当前/最近", "默认问号", DEFAULT_ICON_PICKER_ICON, DEFAULT_ICON_PICKER_ICON, "默认值")
        if type(recent) == "table" then
            for _, value in ipairs(recent) do
                IconPickerAddCandidate(rows, seen, "当前/最近", "最近：" .. IconPickerShortLabel(value, 26), value, value, "最近选择")
            end
        end
        meta.message = IconPickerFormatCacheStatus(meta.cacheStatus)
            or (meta.hasIndex and "输入关键词、技能/物品 ID、贴图路径、atlas:名称或 tex:贴图ID。"
                or "当前包未包含图标库数据；仍可使用最近选择、技能/物品 ID 和直接值。")
        return rows, meta
    end

    local lowerQuery = string_lower(query)
    local textureID = string_match(lowerQuery, "^tex:(%d+)$") or string_match(lowerQuery, "^texture:(%d+)$")
    if textureID then
        local numberValue = tonumber(textureID)
        IconPickerAddCandidate(rows, seen, "直接值", "贴图 ID " .. tostring(numberValue), numberValue, numberValue, "显式贴图 ID")
        meta.message = "直接使用贴图 ID；普通数字会同时搜索技能、物品和图标库。"
        return rows, meta
    end

    if IconPickerLooksLikeIconPath(query) then
        IconPickerAddCandidate(rows, seen, "直接值", IconPickerShortLabel(query, 34), query, query, string_match(lowerQuery, "^atlas:") and "Atlas 名称" or "Interface 路径")
        meta.message = "直接值可保存；应用前请确认右侧预览显示正确。"
        return rows, meta
    end

    local numberValue = tonumber(query)
    if numberValue then
        local spellName, spellTexture, spellID = IconPickerGetSpellInfo(numberValue)
        if spellTexture then
            IconPickerAddCandidate(rows, seen, "技能", string_format("%s %s", tostring(spellID or numberValue), tostring(spellName or "")), spellTexture, spellTexture, "技能 ID", {
                spellID = spellID or numberValue,
                spellName = spellName,
            })
        end

        local itemName, itemTexture, itemID = IconPickerGetItemInfo(numberValue)
        if itemTexture then
            IconPickerAddCandidate(rows, seen, "物品", string_format("%s %s", tostring(itemID or numberValue), tostring(itemName or ("物品 " .. tostring(numberValue)))), itemTexture, itemTexture, "物品 ID", {
                itemID = itemID or numberValue,
                itemName = itemName,
            })
        end
        meta.needsIconSearch = true
    else
        local spellName, spellTexture, spellID = IconPickerGetSpellInfo(query)
        if spellTexture then
            IconPickerAddCandidate(rows, seen, "技能", string_format("%s %s", tostring(spellID or ""), tostring(spellName or query)), spellTexture, spellTexture, "精确技能名", {
                spellID = spellID,
                spellName = spellName,
            })
        end
        if IconPickerIsAsciiSingleChar(query) then
            meta.heavySearchSkipped = true
        else
            meta.needsSpellSearch = true
            meta.needsIconSearch = true
        end
    end

    local cacheMessage = IconPickerFormatCacheStatus(meta.cacheStatus)
    if not meta.hasIndex then
        meta.message = cacheMessage or (#rows > 0 and "当前包未包含图标库数据；仅显示可直接解析的结果。" or "当前包未包含图标库数据，且没有解析到结果。")
    elseif meta.heavySearchSkipped then
        meta.message = "继续输入更多关键词后开始搜索。"
    elseif meta.needsIconSearch or meta.needsSpellSearch then
        meta.message = cacheMessage or "正在搜索..."
    elseif #rows == 0 then
        meta.message = cacheMessage or "没有匹配结果。可尝试更短关键词、普通数字 ID、tex:贴图ID 或 Interface 路径。"
    elseif meta.truncated then
        meta.message = string_format("已显示 %d+ 个结果；可继续缩小关键词。", #rows)
    else
        meta.message = cacheMessage or "单击选择，双击应用；滚轮翻页。"
    end

    return rows, meta
end

local function IconPickerFindSelected(picker)
    if not picker or picker.selectedValue == nil or type(picker.candidates) ~= "table" then return nil end
    local selected = tostring(picker.selectedValue)
    for _, item in ipairs(picker.candidates) do
        if tostring(item.value) == selected and item.group == picker.selectedGroup then
            return item
        end
    end
    for _, item in ipairs(picker.candidates) do
        if tostring(item.value) == selected then
            return item
        end
    end
    return nil
end

local function IconPickerTooltipName(item)
    return item.spellName
        or item.itemName
        or item.iconName
        or item.name
        or item.label
        or tostring(item.value or "")
end

local function IconPickerTooltipID(item)
    return item.spellID
        or item.itemID
        or item.fileID
        or (type(item.value) == "number" and item.value or nil)
end

local function IconPickerShowTooltip(owner, item)
    if not (GameTooltip and owner and item) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(IconPickerTooltipName(item), 1, 1, 1, 1, true)
    local id = IconPickerTooltipID(item)
    if id ~= nil then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffff4040ID:|r |cffffd100" .. tostring(id) .. "|r", 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function IconPickerOnUpdate(frame, elapsed)
    if frame.ProcessSearchUpdate then
        frame:ProcessSearchUpdate(elapsed or 0)
    end
end

function App:CreateIconPicker(parent, opts)
    if not parent then return nil end
    opts = opts or {}

    local width = opts.width or 820
    local height = opts.height or 560
    local picker = GUI2:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.popup",
        border = "color.border.default",
        shadow = true,
        shadowKey = "shadow.popup.size",
    })
    picker.gui2Component = "IconPicker"
    picker:SetPoint("CENTER", parent, "CENTER", 0, -4)
    picker:SetFrameStrata(opts.strata or "DIALOG")
    if picker.SetFrameLevel and parent.GetFrameLevel then
        picker:SetFrameLevel((parent:GetFrameLevel() or 0) + 80)
    end
    if picker.EnableMouse then picker:EnableMouse(true) end
    if picker.SetClampedToScreen then picker:SetClampedToScreen(true) end
    picker:Hide()

    picker.recent = opts.recent or {}
    picker.page = 1
    picker.columns = opts.columns or ICON_PICKER_COLUMNS
    picker.rows = opts.rows or ICON_PICKER_ROWS
    picker.pageSize = picker.columns * picker.rows
    picker.currentValue = opts.value or DEFAULT_ICON_PICKER_ICON
    picker.selectedValue = picker.currentValue
    picker.slots = {}

    local title = GUI2:CreateText(picker, opts.title or "选择图标", "font.size.lg", "color.text.heading")
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetSize(280, 24)
    picker.title = title

    local close = GUI2.Form:CreateButton(picker, {
        text = "关闭",
        width = 72,
        height = 28,
        onClick = function()
            picker:Close()
        end,
    })
    close:SetPoint("TOPRIGHT", -16, -14)

    local searchLabel = GUI2:CreateText(picker, "搜索", "font.size.md", "color.text.secondary")
    searchLabel:SetPoint("TOPLEFT", 20, -58)
    searchLabel:SetSize(48, 24)

    local search = GUI2.Form:CreateEditBox(picker, {
        width = 470,
        height = 28,
        text = "",
        autoFocus = false,
        tooltip = "支持关键词、中文别名、技能/物品 ID、Interface 路径、atlas:名称、tex:贴图ID。",
        onChange = function(_, value)
            picker:ScheduleSearch(value)
        end,
    })
    search:SetPoint("TOPLEFT", 76, -56)
    picker.searchBox = search
    if search.SetScript then
        local previousEnter = search.GetScript and search:GetScript("OnEnterPressed")
        search:SetScript("OnEnterPressed", function(box)
            if previousEnter then previousEnter(box) end
            picker.query = box:GetText()
            picker:RunSearch(false)
            picker:ApplySelection()
        end)
        search:SetScript("OnEscapePressed", function(box)
            box:ClearFocus()
            picker:Close()
        end)
    end

    picker.statusLabel = GUI2:CreateText(picker, "", "font.size.md", "color.text.secondary")
    picker.statusLabel:SetPoint("TOPLEFT", 76, -88)
    picker.statusLabel:SetSize(510, 24)

    picker.resultsPanel = GUI2:CreatePanel(picker, {
        width = 540,
        height = 390,
        surface = "color.surface.sunken",
        border = "color.border.subtle",
    })
    picker.resultsPanel:SetPoint("TOPLEFT", 20, -122)
    if picker.resultsPanel.EnableMouseWheel then picker.resultsPanel:EnableMouseWheel(true) end
    picker.resultsPanel:SetScript("OnMouseWheel", function(_, delta)
        picker:Page(delta and delta > 0 and -1 or 1)
    end)

    local slotSize, gap, startX, startY = 48, 10, 18, -18
    for slotIndex = 1, picker.pageSize do
        local row = math_floor((slotIndex - 1) / picker.columns)
        local col = (slotIndex - 1) % picker.columns
        local slot = GUI2:CreateIconSlot(picker.resultsPanel, {
            size = slotSize,
            icon = DEFAULT_ICON_PICKER_ICON,
            fallbackIcon = DEFAULT_ICON_PICKER_ICON,
            padding = 0,
            onClick = function(frame)
                if frame.item then picker:SelectItem(frame.item) end
            end,
        })
        slot:SetPoint("TOPLEFT", startX + col * (slotSize + gap), startY - row * (slotSize + gap))
        if slot.EnableMouseWheel then slot:EnableMouseWheel(true) end
        slot:SetScript("OnMouseWheel", function(_, delta)
            picker:Page(delta and delta > 0 and -1 or 1)
        end)
        slot:HookScript("OnEnter", function(frame)
            IconPickerShowTooltip(frame, frame.item)
        end)
        slot:HookScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        picker.slots[slotIndex] = slot
    end

    picker.emptyLabel = GUI2:CreateText(picker.resultsPanel, "", "font.size.md", "color.text.secondary", "CENTER")
    picker.emptyLabel:SetPoint("CENTER", picker.resultsPanel, "CENTER", 0, 0)
    picker.emptyLabel:SetSize(480, 56)

    picker.countLabel = GUI2:CreateText(picker, "", "font.size.md", "color.text.secondary")
    picker.countLabel:SetPoint("TOPLEFT", 20, -520)
    picker.countLabel:SetSize(330, 24)
    picker.pageLabel = GUI2:CreateText(picker, "", "font.size.md", "color.text.primary", "CENTER")
    picker.pageLabel:SetPoint("TOPLEFT", 360, -520)
    picker.pageLabel:SetSize(90, 24)
    picker.groupLabel = GUI2:CreateText(picker, "", "font.size.md", "color.text.secondary")
    picker.groupLabel:SetPoint("TOPLEFT", 20, -542)
    picker.groupLabel:SetSize(540, 20)

    picker.preview = GUI2:CreateIconSlot(picker, {
        size = 126,
        icon = picker.currentValue,
        fallbackIcon = DEFAULT_ICON_PICKER_ICON,
        padding = 0,
    })
    picker.preview:SetPoint("TOPLEFT", 610, -62)
    picker.previewTitle = GUI2:CreateText(picker, "", "font.size.md", "color.text.primary")
    picker.previewTitle:SetPoint("TOPLEFT", 590, -202)
    picker.previewTitle:SetSize(210, 26)
    picker.previewSource = GUI2:CreateText(picker, "", "font.size.md", "color.text.secondary")
    picker.previewSource:SetPoint("TOPLEFT", 590, -234)
    picker.previewSource:SetSize(210, 24)
    picker.modeHint = GUI2:CreateText(picker, "", "font.size.md", "color.text.secondary")
    picker.modeHint:SetPoint("TOPLEFT", 590, -262)
    picker.modeHint:SetSize(210, 24)
    picker.previewValue = GUI2:CreateText(picker, "", "font.size.md", "color.text.secondary")
    picker.previewValue:SetPoint("TOPLEFT", 590, -294)
    picker.previewValue:SetSize(210, 86)

    picker.previewValueHitbox = GUI2:CreateFrame(picker, { width = 210, height = 90 })
    picker.previewValueHitbox:SetPoint("TOPLEFT", picker.previewValue, "TOPLEFT", 0, 0)
    if picker.previewValueHitbox.EnableMouse then picker.previewValueHitbox:EnableMouse(true) end
    picker.previewValueHitbox:SetScript("OnEnter", function(frame)
        local item = IconPickerFindSelected(picker) or { value = picker.selectedValue or picker.currentValue, label = picker.previewTitle:GetText(), source = picker.previewSource:GetText() }
        IconPickerShowTooltip(frame, item)
    end)
    picker.previewValueHitbox:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    local cancel = GUI2.Form:CreateButton(picker, {
        text = "取消",
        width = 86,
        height = 30,
        onClick = function()
            picker:Close()
        end,
    })
    cancel:SetPoint("BOTTOMRIGHT", -20, 18)
    picker.cancelButton = cancel

    local apply = GUI2.Form:CreateButton(picker, {
        text = "应用",
        width = 86,
        height = 30,
        onClick = function()
            picker:ApplySelection()
        end,
    })
    apply:SetPoint("RIGHT", cancel, "LEFT", -10, 0)
    picker.applyButton = apply

    function picker:ReleaseSearchCache()
        self:CancelSearchJobs()
        self.candidates = nil
        self.meta = nil
        self.candidateSeen = nil
        self.query = nil
        self.pendingSearchQuery = nil
        self.pendingSearchDelay = nil
        self.cacheRefreshElapsed = nil
        self.cacheRefreshActive = false
        self.lastClickValue = nil
        self.lastClickGroup = nil
        self.lastClickTime = nil
        for _, slot in ipairs(self.slots or {}) do
            slot.item = nil
            slot:Hide()
        end
    end

    function picker:CancelSearchJobs()
        self.searchJobs = nil
        self.searching = false
        if self.SetScript then
            self:SetScript("OnUpdate", nil)
        end
    end

    function picker:AddSearchCandidate(group, label, value, icon, source, extra)
        self.candidates = self.candidates or {}
        self.candidateSeen = self.candidateSeen or {}
        IconPickerAddCandidate(self.candidates, self.candidateSeen, group, label, value, icon, source, extra)
    end

    function picker:MergeJobResult(jobInfo, result)
        if not result or not self.meta then return end
        jobInfo.added = jobInfo.added or 0
        if jobInfo.kind == "spell" then
            self.meta.cacheStatus = result.status or self.meta.cacheStatus
            for index = jobInfo.added + 1, #result do
                local item = result[index]
                if item and item.icon then
                    self:AddSearchCandidate("技能", string_format("%s %s", tostring(item.spellID or ""), tostring(item.name or self.query or "")), item.icon, item.icon, "技能名缓存", {
                        spellID = item.spellID,
                        spellName = item.name,
                    })
                end
            end
            jobInfo.added = #result
            if result.truncated then self.meta.truncated = true end
        elseif jobInfo.kind == "icon" then
            self.meta.hasIndex = result.hasIndex == true
            self.meta.indexTotal = tonumber(result.total) or self.meta.indexTotal or 0
            if result.truncated then self.meta.truncated = true end
            for index = jobInfo.added + 1, #result do
                local item = result[index]
                if item then
                    self:AddSearchCandidate("图标库", item.label or item.name or tostring(item.value), item.value, item.icon or item.value, item.source or "图标库", {
                        fileID = item.fileID,
                        iconName = item.name,
                    })
                end
            end
            jobInfo.added = #result
        end
    end

    function picker:BuildSearchMessage(done)
        local cacheMessage = IconPickerFormatCacheStatus(self.meta and self.meta.cacheStatus)
        if self.searching and not done then
            return IconPickerJoinMessage("正在搜索...", cacheMessage)
        end
        if self.pendingSearchQuery ~= nil then
            return IconPickerJoinMessage("正在输入...", cacheMessage)
        end
        local count = #(self.candidates or {})
        if self.meta and self.meta.heavySearchSkipped then
            return "继续输入更多关键词后开始搜索。"
        end
        if count == 0 then
            if self.meta and self.meta.hasIndex == false then
                return cacheMessage or "当前包未包含图标库数据，且没有解析到结果。"
            end
            return cacheMessage or "没有匹配结果。可尝试更短关键词、普通数字 ID、tex:贴图ID 或 Interface 路径。"
        end
        if self.meta and self.meta.truncated then
            return string_format("已显示 %d+ 个结果；可继续缩小关键词。", count)
        end
        return cacheMessage or "单击选择，双击应用；滚轮翻页。"
    end

    function picker:RefreshCacheStatus(force, updateUI)
        if self.IsShown and not self:IsShown() then
            self.cacheRefreshActive = false
            return false
        end
        if not force and (self.cacheRefreshElapsed or 0) > 0 then
            return self.cacheRefreshActive == true
        end

        self.cacheRefreshElapsed = ICON_PICKER_CACHE_REFRESH_INTERVAL
        local status = IconPickerGetNameCacheStatus()
        self.nameCacheStatus = status or self.nameCacheStatus
        self.cacheRefreshActive = status and status.building == true or false

        if self.meta then
            self.meta.cacheStatus = status or self.meta.cacheStatus
            self.meta.message = self:BuildSearchMessage(not self.searching)
            if updateUI then
                IconPickerSetText(self.statusLabel, self.meta.message or "")
                if self.emptyLabel and self.emptyLabel.IsShown and self.emptyLabel:IsShown() then
                    self.emptyLabel:SetText(self.meta.message or "没有结果。")
                end
            end
        end

        return self.cacheRefreshActive == true
    end

    function picker:StartSearchJobs(serial)
        local query = IconPickerTrim(self.query or "")
        if query == "" or not self.meta then return end
        local jobs = {}
        local spellAPI = IconPickerSpellAPI()
        if self.meta.needsSpellSearch and spellAPI and spellAPI.CreateNameCacheSearchJob then
            local priority
            if self.meta.cacheStatus and self.meta.cacheStatus.building and spellAPI.SetNameCachePriority then
                priority = "interactive"
            end
            local ok, job = pcall(spellAPI.CreateNameCacheSearchJob, query, {
                limit = ICON_PICKER_SPELL_LIMIT,
                priority = priority,
                stopAfterLimit = true,
            })
            if ok and job then
                jobs[#jobs + 1] = { kind = "spell", job = job, serial = serial, added = 0 }
            end
        end

        local icons = IconPickerIconAPI()
        if self.meta.needsIconSearch and icons and icons.CreateTextureIndexSearchJob then
            local ok, job = pcall(icons.CreateTextureIndexSearchJob, query, {
                limit = ICON_PICKER_SEARCH_LIMIT,
                stopAfterLimit = true,
            })
            if ok and job then
                jobs[#jobs + 1] = { kind = "icon", job = job, serial = serial, added = 0 }
            end
        end

        if #jobs == 0 then
            self.searchJobs = nil
            self.searching = false
            if self.meta then self.meta.message = self:BuildSearchMessage(true) end
            return
        end
        self.searchJobs = jobs
        self.searching = true
        if self.meta then self.meta.message = self:BuildSearchMessage(false) end
        if self.SetScript then
            self:SetScript("OnUpdate", IconPickerOnUpdate)
        end
    end

    function picker:StepSearchJobs()
        local jobs = self.searchJobs
        if not jobs then return false end
        local serial = self.searchSerial
        local anyActive = false
        for _, jobInfo in ipairs(jobs) do
            if jobInfo.serial == serial and not jobInfo.done and jobInfo.job and jobInfo.job.Step then
                local ok, done, result = pcall(jobInfo.job.Step, jobInfo.job, {
                    budgetMS = ICON_PICKER_SEARCH_BUDGET_MS,
                    maxEntries = ICON_PICKER_SEARCH_MAX_ENTRIES,
                    minEntries = 64,
                })
                if ok then
                    jobInfo.done = done == true
                    self:MergeJobResult(jobInfo, result)
                else
                    jobInfo.done = true
                end
            end
            if jobInfo.serial == serial and not jobInfo.done then
                anyActive = true
            end
        end
        self.searching = anyActive
        if self.meta then self.meta.message = self:BuildSearchMessage(not anyActive) end
        self:RenderPage()
        if not anyActive then
            self.searchJobs = nil
        end
        return anyActive
    end

    function picker:UpdatePreview()
        local item = IconPickerFindSelected(self)
        local value = self.selectedValue or self.currentValue or DEFAULT_ICON_PICKER_ICON
        if self.preview and self.preview.SetIcon then
            self.preview:SetIcon(item and (item.icon or item.value) or value)
        end
        IconPickerSetText(self.previewTitle, IconPickerShortLabel(item and item.label or value, 28))
        IconPickerSetText(self.previewSource, item and tostring(item.source or item.group or "") or "当前值")
        IconPickerSetText(self.previewValue, IconPickerShortLabel(value, 44))
    end

    function picker:RenderPage()
        local candidates = self.candidates or {}
        local total = #candidates
        local totalPages = math_max(1, math_ceil(total / self.pageSize))
        self.page = math_min(math_max(tonumber(self.page) or 1, 1), totalPages)
        local startIndex = ((self.page - 1) * self.pageSize) + 1
        local endIndex = math_min(startIndex + self.pageSize - 1, total)
        local visibleGroups, seenGroups = {}, {}

        for slotIndex = 1, self.pageSize do
            local item = candidates[startIndex + slotIndex - 1]
            local slot = self.slots[slotIndex]
            if item then
                if item.group and not seenGroups[item.group] then
                    seenGroups[item.group] = true
                    visibleGroups[#visibleGroups + 1] = item.group
                end
                slot.item = item
                slot:Show()
                if slot.SetIcon then slot:SetIcon(item.icon or item.value or DEFAULT_ICON_PICKER_ICON) end
                if slot.SetSelected then
                    slot:SetSelected(tostring(item.value) == tostring(self.selectedValue) and item.group == self.selectedGroup)
                end
            else
                slot.item = nil
                slot:Hide()
            end
        end

        if total == 0 then
            self.emptyLabel:SetText(self.meta and self.meta.message or "没有结果。")
            self.emptyLabel:Show()
            IconPickerSetText(self.countLabel, "0 / 0")
        else
            self.emptyLabel:Hide()
            local extra = ""
            if self.meta and self.meta.hasIndex and self.query ~= "" and (self.meta.indexTotal or 0) > 0 then
                extra = string_format("；图标库 %d%s", self.meta.indexTotal or 0, self.meta.truncated and "+" or "")
            end
            IconPickerSetText(self.countLabel, string_format("%d-%d / %d%s", startIndex, endIndex, total, extra))
        end
        IconPickerSetText(self.statusLabel, self.meta and self.meta.message or "")
        IconPickerSetText(self.pageLabel, string_format("%d / %d", self.page, totalPages))
        IconPickerSetText(self.groupLabel, #visibleGroups > 0 and ("当前页：" .. table_concat(visibleGroups, " / ")) or "")
        self:UpdatePreview()
    end

    function picker:RunSearch(resetPage)
        self.searchSerial = (self.searchSerial or 0) + 1
        local serial = self.searchSerial
        self.pendingSearchQuery = nil
        self.pendingSearchDelay = nil
        self:CancelSearchJobs()
        self.query = IconPickerNormalizeQuery(self.query)
        self.candidateSeen = {}
        self.candidates, self.meta = IconPickerBuildCandidates(self.query or "", self.currentValue, self.recent, self.candidateSeen)
        if resetPage ~= false then self.page = 1 end
        self:StartSearchJobs(serial)
        local cacheActive = self:RefreshCacheStatus(true, false)
        self:RenderPage()
        if cacheActive and not self.searchJobs and self.SetScript then
            self:SetScript("OnUpdate", IconPickerOnUpdate)
        end
    end

    function picker:GetSearchDelay(query)
        query = IconPickerTrim(query or "")
        if query == "" or tonumber(query) or IconPickerLooksLikeIconPath(query) then
            return ICON_PICKER_FAST_DEBOUNCE
        end
        local lowerQuery = string_lower(query)
        if string_match(lowerQuery, "^tex:%d+$") or string_match(lowerQuery, "^texture:%d+$") then
            return ICON_PICKER_FAST_DEBOUNCE
        end
        return ICON_PICKER_SEARCH_DEBOUNCE
    end

    function picker:ScheduleSearch(query)
        self.searchSerial = (self.searchSerial or 0) + 1
        self:CancelSearchJobs()
        self.query = IconPickerNormalizeQuery(query)
        self.pendingSearchQuery = self.query
        self.pendingSearchDelay = self:GetSearchDelay(self.query)
        if self.meta then
            local phase = self.pendingSearchDelay > 0 and "正在输入..." or "正在搜索..."
            self.meta.message = IconPickerJoinMessage(phase, IconPickerFormatCacheStatus(self.meta.cacheStatus))
            self:RenderPage()
        end
        if self.SetScript then
            self:SetScript("OnUpdate", IconPickerOnUpdate)
        end
    end

    function picker:ProcessSearchUpdate(elapsed)
        elapsed = elapsed or 0
        if self.cacheRefreshElapsed then
            self.cacheRefreshElapsed = math_max(self.cacheRefreshElapsed - elapsed, 0)
        end

        local keepRunning = false
        if self.pendingSearchQuery ~= nil then
            self.pendingSearchDelay = (self.pendingSearchDelay or 0) - (elapsed or 0)
            if self.pendingSearchDelay <= 0 then
                self.query = self.pendingSearchQuery
                self.pendingSearchQuery = nil
                self.pendingSearchDelay = nil
                self:RunSearch(true)
            else
                keepRunning = true
            end
        end
        if self.searchJobs then
            keepRunning = self:StepSearchJobs() or keepRunning
        end
        keepRunning = self:RefreshCacheStatus(false, true) or keepRunning
        if not keepRunning and self.SetScript then
            self:SetScript("OnUpdate", nil)
        end
    end

    function picker:Page(delta)
        local candidates = self.candidates or {}
        local totalPages = math_max(1, math_ceil(#candidates / self.pageSize))
        local nextPage = math_min(math_max((tonumber(self.page) or 1) + (delta or 0), 1), totalPages)
        if nextPage ~= self.page then
            self.page = nextPage
            self:RenderPage()
        end
    end

    function picker:SelectItem(item)
        if not item then return end
        local now = GetTime and GetTime() or 0
        local valueText = tostring(item.value)
        local doubleClick = self.lastClickValue == valueText and self.lastClickGroup == item.group and now > 0 and (now - (self.lastClickTime or 0)) <= 0.35
        self.selectedValue = item.value
        self.selectedGroup = item.group
        self.selectedLabel = item.label
        self.lastClickValue = valueText
        self.lastClickGroup = item.group
        self.lastClickTime = now
        self:RenderPage()
        if doubleClick then
            self:ApplySelection()
        end
    end

    function picker:ApplySelection()
        if self.selectedValue == nil then return end
        local selectedItem = IconPickerFindSelected(self)
        self.recent = self.recent or {}
        for index = #self.recent, 1, -1 do
            if tostring(self.recent[index]) == tostring(self.selectedValue) then
                table_remove(self.recent, index)
            end
        end
        table_insert(self.recent, 1, self.selectedValue)
        while #self.recent > ICON_PICKER_RECENT_LIMIT do
            table_remove(self.recent)
        end
        if self.onApply then
            self.onApply(self.selectedValue, selectedItem)
        end
        self:Close()
    end

    function picker:Open(openOpts)
        openOpts = openOpts or {}
        self.currentValue = openOpts.value or opts.value or DEFAULT_ICON_PICKER_ICON
        self.selectedValue = self.currentValue
        self.selectedGroup = nil
        self.selectedLabel = nil
        self.onApply = openOpts.onApply or opts.onApply
        self.query = ""
        self.page = 1
        self.recent = openOpts.recent or self.recent or {}
        self.modeHintText = openOpts.modeHint or opts.modeHint or ""
        self.cacheRefreshElapsed = 0
        self.cacheRefreshActive = false
        if openOpts.title then
            self.title:SetText(openOpts.title)
        else
            self.title:SetText(opts.title or "选择图标")
        end
        self.nameCacheStatus, self.nameCacheOwnerAcquired = IconPickerEnsureNameCacheStarted()
        IconPickerSetText(self.modeHint, self.modeHintText)
        if self.searchBox.SetValue then
            self.searchBox:SetValue("", true)
        else
            self.searchBox:SetText("")
        end
        self:Show()
        self:RunSearch(true)
        if self.searchBox.SetFocus then self.searchBox:SetFocus() end
    end

    function picker:Close()
        if GameTooltip then GameTooltip:Hide() end
        self:ReleaseSearchCache()
        if self.nameCacheOwnerAcquired then
            self.nameCacheStatus = IconPickerReleaseNameCacheOwner()
            self.nameCacheOwnerAcquired = false
        end
        self:Hide()
    end

    return picker
end

function App:CreatePopIconMenu(parent, opts)
    opts = opts or {}
    local width = opts.width or 260
    local items = opts.items or {}
    local columns = opts.columns or 4
    local itemSize = opts.itemSize or 34
    local rows = math_ceil(#items / columns)
    if rows < 1 then rows = 1 end
    local minHeight = 52 + (rows * itemSize) + ((rows - 1) * 8) + 20
    local height = opts.height or minHeight
    if height < minHeight then height = minHeight end
    local frame = GUI2:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.popup",
        border = "color.popup.border",
        shadow = true,
        shadowKey = "shadow.popup.size",
    })
    frame.gui2Component = "PopIconMenu"

    local title = GUI2:CreateText(frame, opts.title or "PopIconMenu", "font.size.lg", "color.text.heading")
    title:SetPoint("TOPLEFT", 12, -10)
    frame.title = title

    local grid = GUI2:CreateIconGrid(frame, {
        columns = columns,
        itemSize = itemSize,
        spacing = 8,
        width = width - 24,
        items = items,
    })
    grid:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    frame.grid = grid

    local hint = GUI2:CreateText(frame, opts.hint or "用于业务模块的图标选择", "font.size.sm", "color.text.secondary")
    hint:SetPoint("BOTTOMLEFT", 12, 10)
    frame.hint = hint
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

function App:RenderLab(parent, lab)
    local width = parent:GetWidth() > 100 and parent:GetWidth() or 920
    lab:RenderHeader(parent, "业务组件（Application）", "用于业务模块直接复用的组合组件，重点检查图标、状态、动作列表和弹出图标菜单。")
    lab:RenderComponentList(parent, "组件清单（Component List）", {
        "状态文本（StatusText）", "冷却图标（CooldownIcon）", "动作列表（ActionList）",
        "信息条项目（BarItem）", "模块开关（ModSwitch）", "弹出图标菜单（PopIconMenu）",
    })

    local top = CreateSection(parent, "状态、冷却与模块开关（StatusText / BarItem / CooldownIcon / ModSwitch）", 18, -88, width - 36, 190)
    local status1 = self:CreateStatusText(top, { width = 240, label = "时钟", value = "服务器时间", tone = "accent" })
    status1:SetPoint("TOPLEFT", 14, -44)
    local status2 = self:CreateStatusText(top, { width = 240, label = "耐久", value = "需要修理", tone = "warning" })
    status2:SetPoint("TOPLEFT", status1, "BOTTOMLEFT", 0, -8)
    local bar = self:CreateBarItem(top, {
        width = 260,
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        text = "时间信息条",
        value = "24小时",
        tone = "accent",
    })
    bar:SetPoint("TOPLEFT", 300, -50)
    local cooldown = self:CreateCooldownIcon(top, {
        size = 46,
        icon = "Interface\\Icons\\Spell_Nature_TimeStop",
        duration = 45,
        start = GetTime and (GetTime() - 18) or 0,
        count = 2,
    })
    cooldown:SetPoint("LEFT", bar, "RIGHT", 14, 0)
    local modSwitch = self:CreateModSwitch(top, {
        width = 154,
        height = 78,
        label = "模块开关",
        image = Assets:Core("images\\YUI-LOGO-300.png"),
        default = true,
        settingsClick = function() end,
    })
    modSwitch:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -12)

    local bottom = CreateSection(parent, "动作与菜单（ActionList / PopIconMenu）", 18, -296, width - 36, 200)
    local actionList = self:CreateActionList(bottom, {
        width = 350,
        rowHeight = 26,
        items = {
            { text = "打开设置", icon = "Interface\\Icons\\INV_Misc_Gear_01", action = { kind = "custom" } },
            { text = "施放辅助技能", icon = "Interface\\Icons\\Spell_Holy_FlashHeal", action = { kind = "spell", spellID = 6603 }, selected = true },
            { text = "使用物品", icon = "Interface\\Icons\\INV_Misc_Rune_01", action = { kind = "item", item = "item:6948" } },
            { text = "禁用动作", icon = "Interface\\Icons\\INV_Misc_QuestionMark", action = { kind = "macro" }, disabled = true },
        },
    })
    actionList:SetPoint("TOPLEFT", 14, -36)

    local menu = self:CreatePopIconMenu(bottom, {
        width = 286,
        height = 146,
        itemSize = 26,
        title = "图标弹出菜单",
        hint = "用于业务模块的图标选择",
        items = {
            { icon = "Interface\\Icons\\INV_Misc_QuestionMark", selected = true, shape = "rounded" },
            { icon = "Interface\\Icons\\INV_Misc_Coin_01", shape = "rounded" },
            { icon = "Interface\\Icons\\INV_Misc_Bag_10", shape = "rounded" },
            { icon = "Interface\\Icons\\Spell_Holy_BorrowedTime", shape = "rounded" },
            { icon = "Interface\\Icons\\Ability_Rogue_Sprint", disabled = true },
            { icon = "Interface\\Icons\\INV_Misc_EngGizmos_30", count = 5 },
        },
    })
    menu:SetPoint("TOPLEFT", actionList, "TOPRIGHT", 22, 0)

    local note = GUI2:CreateText(bottom, "业务组件只关心数据、动作和状态；视觉、主题和未来安全组合由 GUI2.0 统一承接。", "font.size.sm", "color.text.secondary")
    note:SetPoint("TOPLEFT", menu, "TOPRIGHT", 22, -4)
    note:SetWidth(width - 722)
    note:SetWordWrap(true)
end
