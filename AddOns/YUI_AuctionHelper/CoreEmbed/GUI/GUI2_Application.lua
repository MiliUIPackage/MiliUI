local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local Assets = YUI.Assets
local CreateFrame = CreateFrame
local GetTime = GetTime
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min

GUI2.Application = GUI2.Application or {}
local App = GUI2.Application
local DEFAULT_CAST_BAR_TEXTURE = "Interface\\Buttons\\WHITE8x8"

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
        count = opts.count,
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

    slot.SetCooldown = function(self, start, duration)
        if self.cooldown and start and duration and duration > 0 then
            self.cooldown:SetCooldown(start, duration)
        elseif self.cooldown then
            self.cooldown:Clear()
        end
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
    if Enum and Enum.StatusBarInterpolation then
        return Enum.StatusBarInterpolation.Immediate or Enum.StatusBarInterpolation.None or 0
    end
    return 0
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

local function ApplyCastStatusBarTexture(frame, texture)
    local statusBar = frame and frame.castStatusBar
    if not (statusBar and statusBar.SetStatusBarTexture) then return end
    local nextTexture = texture
    if type(nextTexture) ~= "string" or nextTexture == "" then
        nextTexture = DEFAULT_CAST_BAR_TEXTURE
    end
    statusBar:SetStatusBarTexture(nextTexture)
end

local function ApplyCastStatusBarColor(frame, r, g, b, a)
    local statusBar = frame and frame.castStatusBar
    if not (statusBar and statusBar.SetStatusBarColor) then return end
    if type(r) == "string" then
        statusBar:SetStatusBarColor(GUI2:GetColor(r))
    elseif type(r) == "table" then
        statusBar:SetStatusBarColor(r[1] or 1, r[2] or 1, r[3] or 1, r[4] == nil and 1 or r[4])
    elseif type(r) == "number" then
        statusBar:SetStatusBarColor(r, g or 1, b or 1, a == nil and 1 or a)
    else
        statusBar:SetStatusBarColor(1, 1, 1, 1)
    end
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

local function ApplyCastStatusBarConditionalColor(frame, value, trueColor, falseColor)
    local statusBar = frame and frame.castStatusBar
    local texture = statusBar and statusBar.GetStatusBarTexture and statusBar:GetStatusBarTexture()
    if not texture then
        return false
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
    local statusBar = frame and frame.castStatusBar
    local texture = statusBar and statusBar.GetStatusBarTexture and statusBar:GetStatusBarTexture()
    if not texture then
        return false
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
    if mode == "outline_shadow" or mode == "outlineShadow" then return "outline_shadow" end
    return "shadow"
end

local function ApplyCastBarTextShadow(fontString, mode)
    if not (fontString and fontString.SetShadowColor) then return end
    mode = NormalizeCastBarTextOutlineMode(mode)
    if mode == "shadow" or mode == "outline_shadow" then
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
    fontString:SetFont(GUI2:GetFont("font.family.body"), size, outlineMode == "outline_shadow" and "OUTLINE" or "")
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
        width = barWidth,
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

    if frame.fill then
        frame.fill:Hide()
    end

    local castStatusBar = CreateFrame("StatusBar", nil, frame.track)
    castStatusBar:SetAllPoints(frame.track)
    castStatusBar:SetMinMaxValues(0, 1)
    castStatusBar:SetValue(opts.value or 0)
    castStatusBar:Show()
    frame.castStatusBar = castStatusBar
    frame.statusBar = castStatusBar
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
            self:SetBarSize(width, nextBarHeight, nextBarHeight)
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
        local ok = pcall(statusBar.SetTimerDuration, statusBar, durationObject, GetStatusBarImmediateInterpolation(), GetCastTimerDirection(isChannel == true))
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
        if self.fill then
            self.fill:Hide()
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
            size = item.settingsButtonSize or 24,
            tooltip = item.settingsTooltip or "设置",
            onClick = function()
                item.settingsClick()
            end,
        }
        local hasExplicitTexture = item.settingsButtonAtlas or item.settingsButtonTexture or item.settingsButtonIcon
        local settingsButton
        if hasExplicitTexture or YUI.IsRetail or YUI.IsWrath then
            settingsOptions.atlas = item.settingsButtonAtlas or (YUI.IsWrath and "glues-characterSelect-icon-notify-inProgress-hover" or nil)
            settingsOptions.texture = item.settingsButtonTexture or item.settingsButtonIcon
            settingsOptions.texCoords = item.settingsButtonTexCoords or item.settingsButtonTexCoord
            settingsOptions.crop = item.settingsButtonCrop
            settingsButton = GUI2:CreateBlizzardIconButton(container, settingsOptions)
        else
            settingsOptions.size = item.settingsButtonSize or 22
            settingsOptions.icon = "Interface\\Icons\\INV_Misc_Gear_01"
            settingsOptions.texCoords = item.settingsButtonTexCoords or item.settingsButtonTexCoord or { 0.12, 0.88, 0.12, 0.88 }
            settingsOptions.padding = 0
            settingsOptions.surface = "color.control.bg"
            settingsOptions.border = "color.border.subtle"
            settingsButton = GUI2:CreateIconButton(container, settingsOptions)
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
