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

local SLIDER_DIAGNOSTIC_DEFAULT_SAMPLE_LIMIT = 12
local SLIDER_DIAGNOSTIC_MAX_SAMPLE_LIMIT = 40
local SLIDER_STEP_ROUND_EPSILON = 0.000000001
local SLIDER_DIAGNOSTIC_PHASE_LABELS = {
    config = "配置同步/入队",
    preview = "预览刷新",
    autosave = "ConfigSet 保存",
}
local SliderDiagnostics = GUI2.Form.SliderDiagnostics or {
    enabled = false,
    sampleLimit = SLIDER_DIAGNOSTIC_DEFAULT_SAMPLE_LIMIT,
    sequence = 0,
}
GUI2.Form.SliderDiagnostics = SliderDiagnostics

local function SliderDiagnosticTimeMs()
    local profiler = _G.debugprofilestop
    if type(profiler) == "function" then
        return profiler()
    end
    local precise = _G.GetTimePreciseSec
    if type(precise) == "function" then
        return precise() * 1000
    end
    local clock = _G.GetTime
    if type(clock) == "function" then
        return clock() * 1000
    end
    return nil
end

local function SliderDiagnosticWrite(message)
    local chat = _G.DEFAULT_CHAT_FRAME
    if chat and type(chat.AddMessage) == "function" then
        chat:AddMessage(message)
    elseif type(_G.print) == "function" then
        _G.print(message)
    end
end

function GUI2.Form:SetSliderDiagnosticsEnabled(enabled, sampleLimit)
    SliderDiagnostics.enabled = enabled == true
    sampleLimit = math_floor(tonumber(sampleLimit) or SliderDiagnostics.sampleLimit)
    sampleLimit = math_max(0, math_min(SLIDER_DIAGNOSTIC_MAX_SAMPLE_LIMIT, sampleLimit))
    SliderDiagnostics.sampleLimit = sampleLimit
    SliderDiagnosticWrite(string_format(
        "|cff33ccffYUI GUI2 Slider|r 诊断%s，事件样本上限：%d。",
        SliderDiagnostics.enabled and "已启用" or "已关闭",
        sampleLimit
    ))
    return SliderDiagnostics.enabled, sampleLimit
end

function GUI2.Form:GetSliderDiagnosticsEnabled()
    return SliderDiagnostics.enabled == true, SliderDiagnostics.sampleLimit
end

function GUI2.Form:BeginSliderDiagnosticPhase(name)
    if SliderDiagnostics.enabled ~= true then return nil end
    local diagnostic = SliderDiagnostics.active
    if type(diagnostic) ~= "table" then return nil end
    local now = SliderDiagnosticTimeMs()
    if type(now) ~= "number" then return nil end
    return {
        diagnostic = diagnostic,
        name = tostring(name or "other"),
        startedMs = now,
    }
end

function GUI2.Form:EndSliderDiagnosticPhase(token)
    if type(token) ~= "table" then return false end
    local diagnostic = token.diagnostic
    if diagnostic ~= SliderDiagnostics.active then return false end
    local now = SliderDiagnosticTimeMs()
    if type(now) ~= "number" or type(token.startedMs) ~= "number" then
        return false
    end
    local elapsed = now - token.startedMs
    if elapsed < 0 then return false end

    local name = token.name
    local phase = diagnostic.phases[name]
    if not phase then
        phase = {
            count = 0,
            totalMs = 0,
            maxMs = 0,
        }
        diagnostic.phases[name] = phase
        diagnostic.phaseOrder[#diagnostic.phaseOrder + 1] = name
    end
    phase.count = phase.count + 1
    phase.totalMs = phase.totalMs + elapsed
    phase.maxMs = math_max(phase.maxMs, elapsed)
    return true, elapsed
end

local function BeginSliderDiagnostic(container, opts, normalizedValue, normalizedStepKey)
    if SliderDiagnostics.enabled ~= true then return end
    local now = SliderDiagnosticTimeMs()
    if type(now) ~= "number" then
        SliderDiagnosticWrite("|cffff5555YUI GUI2 Slider|r 无可用的毫秒计时 API。")
        return
    end
    SliderDiagnostics.sequence = SliderDiagnostics.sequence + 1
    local label = opts.diagnosticLabel or opts.label or opts.key or opts.name or "Slider"
    container.gui2SliderDiagnostic = {
        id = SliderDiagnostics.sequence,
        label = tostring(label),
        startedMs = now,
        lastEventMs = nil,
        lastNormalized = normalizedValue,
        lastNormalizedStepKey = normalizedStepKey,
        lastCommitted = normalizedValue,
        lastCommittedStepKey = normalizedStepKey,
        rawEvents = 0,
        normalizedChanges = 0,
        repeatedValues = 0,
        commits = 0,
        effectiveCommits = 0,
        repeatedCommits = 0,
        intervalCount = 0,
        intervalTotalMs = 0,
        intervalMinMs = nil,
        intervalMaxMs = 0,
        commitTotalMs = 0,
        commitMaxMs = 0,
        phases = {},
        phaseOrder = {},
        samples = {},
        sampleLimit = SliderDiagnostics.sampleLimit,
    }
    SliderDiagnostics.active = container.gui2SliderDiagnostic
end

local function RecordSliderDiagnosticEvent(
    container,
    rawValue,
    normalizedValue,
    normalizedStepKey
)
    local diagnostic = container.gui2SliderDiagnostic
    if not diagnostic then return end
    local now = SliderDiagnosticTimeMs()
    if type(now) ~= "number" then return end

    diagnostic.rawEvents = diagnostic.rawEvents + 1
    local changed = diagnostic.lastNormalizedStepKey ~= normalizedStepKey
    if changed then
        diagnostic.normalizedChanges = diagnostic.normalizedChanges + 1
    else
        diagnostic.repeatedValues = diagnostic.repeatedValues + 1
    end
    diagnostic.lastNormalized = normalizedValue
    diagnostic.lastNormalizedStepKey = normalizedStepKey

    if diagnostic.lastEventMs then
        local interval = now - diagnostic.lastEventMs
        if interval >= 0 then
            diagnostic.intervalCount = diagnostic.intervalCount + 1
            diagnostic.intervalTotalMs = diagnostic.intervalTotalMs + interval
            diagnostic.intervalMinMs = diagnostic.intervalMinMs
                and math_min(diagnostic.intervalMinMs, interval)
                or interval
            diagnostic.intervalMaxMs = math_max(diagnostic.intervalMaxMs, interval)
        end
    end
    diagnostic.lastEventMs = now

    local samples = diagnostic.samples
    if #samples < diagnostic.sampleLimit then
        samples[#samples + 1] = string_format(
            "#%d at=%.3fms +%.3fms raw=%s value=%s %s",
            diagnostic.rawEvents,
            now,
            now - diagnostic.startedMs,
            tostring(rawValue),
            tostring(normalizedValue),
            changed and "changed" or "repeat"
        )
    end
end

local function RecordSliderDiagnosticCommit(container, value, stepKey, startedMs)
    local diagnostic = container.gui2SliderDiagnostic
    if not diagnostic then return end
    diagnostic.commits = diagnostic.commits + 1
    if diagnostic.lastCommittedStepKey == stepKey then
        diagnostic.repeatedCommits = diagnostic.repeatedCommits + 1
    else
        diagnostic.effectiveCommits = diagnostic.effectiveCommits + 1
    end
    diagnostic.lastCommitted = value
    diagnostic.lastCommittedStepKey = stepKey

    local now = SliderDiagnosticTimeMs()
    if type(startedMs) == "number" and type(now) == "number" then
        local elapsed = now - startedMs
        if elapsed >= 0 then
            diagnostic.commitTotalMs = diagnostic.commitTotalMs + elapsed
            diagnostic.commitMaxMs = math_max(diagnostic.commitMaxMs, elapsed)
        end
    end
end

local function FinishSliderDiagnostic(container)
    local diagnostic = container.gui2SliderDiagnostic
    if not diagnostic then return end
    container.gui2SliderDiagnostic = nil
    if SliderDiagnostics.active == diagnostic then
        SliderDiagnostics.active = nil
    end

    local now = SliderDiagnosticTimeMs()
    local duration = type(now) == "number" and math_max(0, now - diagnostic.startedMs) or 0
    local eventRate = duration > 0 and (diagnostic.rawEvents * 1000 / duration) or 0
    local averageInterval = diagnostic.intervalCount > 0
        and (diagnostic.intervalTotalMs / diagnostic.intervalCount)
        or 0
    local averageCommit = diagnostic.commits > 0
        and (diagnostic.commitTotalMs / diagnostic.commits)
        or 0

    SliderDiagnosticWrite(string_format(
        "|cff33ccffYUI GUI2 Slider #%d|r [%s] 拖动 %.3fms，原始事件 %d（%.1f/s）。",
        diagnostic.id,
        diagnostic.label,
        duration,
        diagnostic.rawEvents,
        eventRate
    ))
    SliderDiagnosticWrite(string_format(
        "数值变化 %d，重复数值 %d；业务提交 %d（有效 %d，重复 %d）。",
        diagnostic.normalizedChanges,
        diagnostic.repeatedValues,
        diagnostic.commits,
        diagnostic.effectiveCommits,
        diagnostic.repeatedCommits
    ))
    SliderDiagnosticWrite(string_format(
        "事件间隔 min/avg/max：%.3f / %.3f / %.3fms；同步提交 total/avg/max：%.3f / %.3f / %.3fms。",
        diagnostic.intervalMinMs or 0,
        averageInterval,
        diagnostic.intervalMaxMs,
        diagnostic.commitTotalMs,
        averageCommit,
        diagnostic.commitMaxMs
    ))
    local attributedTotalMs = 0
    for index = 1, #diagnostic.phaseOrder do
        local name = diagnostic.phaseOrder[index]
        local phase = diagnostic.phases[name]
        if phase and phase.count > 0 then
            local average = phase.totalMs / phase.count
            attributedTotalMs = attributedTotalMs + phase.totalMs
            SliderDiagnosticWrite(string_format(
                "分段 %s：%d 次，total/avg/max：%.3f / %.3f / %.3fms。",
                SLIDER_DIAGNOSTIC_PHASE_LABELS[name] or name,
                phase.count,
                phase.totalMs,
                average,
                phase.maxMs
            ))
        end
    end
    if attributedTotalMs > 0 then
        SliderDiagnosticWrite(string_format(
            "已归因 %.3fms；其余同步开销 %.3fms。",
            attributedTotalMs,
            math_max(0, diagnostic.commitTotalMs - attributedTotalMs)
        ))
    end
    for index = 1, #diagnostic.samples do
        SliderDiagnosticWrite("  " .. diagnostic.samples[index])
    end
    if diagnostic.rawEvents > #diagnostic.samples then
        SliderDiagnosticWrite(string_format(
            "  ……其余 %d 个原始事件已省略。",
            diagnostic.rawEvents - #diagnostic.samples
        ))
    end
end

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

local function ValuesEqual(left, right)
    if left == right then return true end
    if type(left) ~= type(right) or type(left) ~= "table" then return false end
    for key, value in pairs(left) do
        if not ValuesEqual(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
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
        local heading = opts.label
        if heading == nil or heading == "" then heading = opts.text end
        if heading ~= nil and heading ~= "" then
            GameTooltip:SetText(heading)
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
    elseif tone == "success" then
        border = "color.state.success"
        text = "color.state.success"
    elseif tone == "warning" then
        border = "color.state.warning"
        text = "color.state.warning"
    elseif tone == "danger" or tone == "error" then
        border = "color.state.danger"
        text = "color.state.danger"
    end

    if state == "hover" then
        surface = "color.control.hover"
        border = tone == "success" and "color.state.success" or tone == "warning" and "color.state.warning" or tone == "danger" and "color.state.danger" or "color.border.accent"
    elseif state == "pressed" then
        surface = "color.control.pressed"
        border = tone == "success" and "color.state.success" or "color.border.strong"
    elseif state == "selected" or state == "active" then
        surface = "color.control.active"
        border = tone == "success" and "color.state.success" or "color.border.accent"
        text = tone == "success" and "color.state.success" or tone == "danger" and "color.state.danger" or "color.text.accent"
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

    if state ~= "disabled" then
        if state == "hover" then
            surface = frame.gui2HoverSurfaceToken or surface
            border = frame.gui2HoverBorderToken or border
            text = frame.gui2HoverTextColorKey or text
        elseif state == "pressed" then
            surface = frame.gui2PressedSurfaceToken or surface
            border = frame.gui2PressedBorderToken or border
            text = frame.gui2PressedTextColorKey or text
        elseif state == "normal" then
            surface = frame.gui2SurfaceToken or surface
            border = frame.gui2BorderToken or border
            text = frame.gui2TextColorKey or text
        end
    end

    return surface, border, text
end

local function GetControlStateColor(value)
    if type(value) == "table" then
        local color = value.type == "solid" and value.value or value
        return color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4]
    end
    return GUI2:GetColor(value)
end

local function LayoutButtonHairlineRelief(frame)
    local edges = frame and frame.gui2HairlineEdges
    if not edges then return end
    local pixel = GUI2.GetPixelSize and GUI2:GetPixelSize(frame, 1, 1) or 1

    edges.top:ClearAllPoints()
    edges.top:SetPoint("TOPLEFT", frame, "TOPLEFT", pixel, -pixel)
    edges.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pixel, -pixel)
    edges.top:SetHeight(pixel)

    edges.bottom:ClearAllPoints()
    edges.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pixel, pixel)
    edges.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pixel, pixel)
    edges.bottom:SetHeight(pixel)

    edges.left:ClearAllPoints()
    edges.left:SetPoint("TOPLEFT", frame, "TOPLEFT", pixel, -pixel)
    edges.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", pixel, pixel)
    edges.left:SetWidth(pixel)

    edges.right:ClearAllPoints()
    edges.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pixel, -pixel)
    edges.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pixel, pixel)
    edges.right:SetWidth(pixel)
end

local function PaintButtonHairlineRelief(frame, state)
    local edges = frame and frame.gui2HairlineEdges
    if not edges then return end

    local highlightKey = "color.badge.text"
    local shadowKey = "color.surface.sunken"
    local highlightAlpha, shadowAlpha = 0.28, 0.55
    if state == "hover" then
        highlightAlpha, shadowAlpha = 0.42, 0.48
    elseif state == "pressed" then
        highlightKey, shadowKey = shadowKey, highlightKey
        highlightAlpha, shadowAlpha = 0.65, 0.12
    elseif state == "disabled" then
        highlightAlpha, shadowAlpha = 0.08, 0.15
    end

    GUI2:SetTexturePaintKey(edges.top, highlightKey)
    GUI2:SetTexturePaintKey(edges.left, highlightKey)
    GUI2:SetTexturePaintKey(edges.bottom, shadowKey)
    GUI2:SetTexturePaintKey(edges.right, shadowKey)
    edges.top:SetAlpha(highlightAlpha)
    edges.left:SetAlpha(highlightAlpha)
    edges.bottom:SetAlpha(shadowAlpha)
    edges.right:SetAlpha(shadowAlpha)
end

local function EnsureButtonHairlineRelief(frame)
    if not frame or frame.gui2HairlineEdges then return end
    local function CreateEdge()
        return GUI2:CreateTexture(frame, {
            paint = "color.badge.text",
            layer = "OVERLAY",
            subLevel = 7,
        })
    end
    frame.gui2HairlineEdges = {
        top = CreateEdge(),
        bottom = CreateEdge(),
        left = CreateEdge(),
        right = CreateEdge(),
    }
    frame.UpdateGUI2PixelLayout = LayoutButtonHairlineRelief
    LayoutButtonHairlineRelief(frame)
end

local function ApplyControlState(frame, state)
    if not frame then return end
    state = state or frame.gui2State or "normal"
    frame.gui2State = state

    local surface, border, text = StateTokens(frame, state)
    frame.gui2Surface = surface
    if frame.SetBackdropColor then
        frame:SetBackdropColor(GetControlStateColor(surface))
    end
    GUI2:SetBorderColor(frame, border)
    if frame.text then
        if frame.gui2CustomTextColor and state == "normal" then
            frame.text:SetTextColor(unpack(frame.gui2CustomTextColor))
        elseif type(text) == "table" then
            frame.text.gui2ColorKey = nil
            frame.text:SetTextColor(GetControlStateColor(text))
        else
            GUI2:SetTextColorKey(frame.text, text)
        end
    end
    if frame.icon and frame.icon.SetVertexColor and not frame.gui2PreserveIconColor then
        frame.icon:SetVertexColor(GetControlStateColor(text))
    end
    PaintButtonHairlineRelief(frame, state)
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
    local disabled = not enabled
    if button.gui2DisabledInitialized and button.gui2Disabled == disabled then
        return false
    end
    button.gui2Disabled = disabled
    if enabled then
        if button.Enable then button:Enable() end
        local state = GetButtonRestingState(button)
        if state == "disabled" then state = "normal" end
        ApplyControlState(button, state)
    else
        if button.Disable then button:Disable() end
        ApplyControlState(button, "disabled")
    end
    button.gui2DisabledInitialized = true
    return true
end

local function LayoutButtonContent(button, offsetX, offsetY)
    if not button then return end
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    local text = button.text
    local icon = button.icon
    if text then text:ClearAllPoints() end
    if icon and button.gui2ButtonOwnsIcon then icon:ClearAllPoints() end

    if icon and button.gui2ButtonOwnsIcon then
        local leftPadding = button.gui2IconLeftPadding or 8
        local gap = button.gui2IconGap or 5
        local iconYOffset = button.gui2IconYOffset or 0
        if text and button.gui2ContentAlign == "center" then
            local contentOffset = ((icon:GetWidth() or 0) + gap) * 0.5
            text:SetPoint("CENTER", button, "CENTER", contentOffset + offsetX, offsetY)
            text:SetJustifyH("CENTER")
            icon:SetPoint("RIGHT", text, "LEFT", -gap, iconYOffset)
        else
            icon:SetPoint("LEFT", button, "LEFT", leftPadding + offsetX, offsetY + iconYOffset)
        end
        if text and button.gui2ContentAlign ~= "center" then
            text:SetPoint("LEFT", icon, "RIGHT", gap, offsetY)
            text:SetPoint("RIGHT", button, "RIGHT", -(button.gui2TextRightPadding or 8) + offsetX, offsetY)
            text:SetJustifyH(button.gui2JustifyH or "LEFT")
        end
    elseif text then
        text:SetPoint("CENTER", offsetX, offsetY)
        text:SetJustifyH(button.gui2JustifyH or "CENTER")
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
        LayoutButtonContent(self)
        ApplyControlState(self, GetButtonRestingState(self))
    end)
    button:SetScript("OnMouseDown", function(self)
        if self.gui2Disabled then return end
        ApplyControlState(self, "pressed")
        LayoutButtonContent(self, 1, -1)
    end)
    button:SetScript("OnMouseUp", function(self)
        if self.gui2Disabled then return end
        LayoutButtonContent(self)
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
    button.gui2Relief = opts.relief
    GUI2:ApplyBackdrop(button, "color.control.bg")
    GUI2:CreateBorder(button, "color.border.default")
    if opts.relief == "hairline" then
        EnsureButtonHairlineRelief(button)
    end

    local microIconName = opts.microIcon or opts.microIconName
    local iconSource = opts.icon or opts.texture or opts.source
    local hasIcon = microIconName ~= nil or iconSource ~= nil or opts.atlas ~= nil
    local label = GUI2:CreateText(button, opts.text or opts.label or "", opts.fontSizeKey or "font.size.md", "color.text.accent")
    label:SetWordWrap(false)
    button.text = label

    if hasIcon then
        local iconCrop = opts.iconCrop
        if iconCrop == nil then iconCrop = opts.crop end
        local iconSize = opts.iconSize or math_max(math_min((opts.height or GetControlHeight(26)) - 10, 16), 12)
        local icon
        if microIconName then
            icon = GUI2:CreateMicroIcon(button, {
                iconName = microIconName,
                size = iconSize,
                maxSize = iconSize,
                minPhysicalPixels = opts.iconMinPhysicalPixels,
                pixelPolicy = opts.iconPixelPolicy,
            })
        else
            icon = GUI2:CreateIcon(button, {
                icon = iconSource,
                atlas = opts.atlas,
                size = iconSize,
                texCoords = opts.iconTexCoords or opts.texCoords,
                crop = iconCrop,
                pixelPolicy = opts.iconPixelPolicy,
            })
        end
        button.icon = icon
        button.gui2ButtonOwnsIcon = true
        button.gui2PreserveIconColor = opts.preserveIconColor == true
        button.gui2ContentAlign = opts.contentAlign or "left"
        button.gui2IconLeftPadding = opts.iconLeftPadding or 8
        button.gui2IconGap = opts.iconGap or 5
        button.gui2IconYOffset = opts.iconYOffset or 0
        button.gui2TextRightPadding = opts.textRightPadding or 8
        button.gui2JustifyH = opts.justifyH or "LEFT"
        InheritMotion(icon, button)
    else
        button.gui2JustifyH = opts.justifyH or "CENTER"
    end
    LayoutButtonContent(button)

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
    function button:SetDisabled(disabled, force)
        disabled = disabled and true or false
        if force == true then self.gui2DisabledInitialized = nil end
        SetButtonEnabled(self, not disabled)
    end
    function button:SetText(value)
        if self.text then self.text:SetText(value or "") end
        LayoutButtonContent(self)
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
    function button:SetRelief(relief)
        self.gui2Relief = relief
        if relief == "hairline" then
            EnsureButtonHairlineRelief(self)
            for _, edge in pairs(self.gui2HairlineEdges) do edge:Show() end
            LayoutButtonHairlineRelief(self)
            PaintButtonHairlineRelief(self, self.gui2State or "normal")
        elseif self.gui2HairlineEdges then
            for _, edge in pairs(self.gui2HairlineEdges) do edge:Hide() end
        end
    end

    WireButtonStates(button)
    if opts.onClick then button:SetScript("OnClick", opts.onClick) end
    AddTooltip(button, opts)
    button:SetState(opts.state or "normal")
    button:SetDisabled(opts.disabled or opts.state == "disabled")
    GUI2:RegisterThemeObject(button)
    return button
end

function GUI2.Form:SetButtonRelief(button, relief)
    if not button then return false end
    if button.SetRelief then
        button:SetRelief(relief)
        return true
    end
    return false
end

function GUI2.Form:CreateTextLink(parent, opts)
    opts = opts or {}
    local width = ResolveFormWidth(opts, "compact", 92)
    local height = opts.height or GetControlHeight(22)
    local normalColor = opts.colorKey or "color.text.accent"
    local hoverColor = opts.hoverColorKey or "color.text.heading"
    local disabledColor = opts.disabledColorKey or "color.text.disabled"

    local button = GUI2:CreateButtonFrame(parent, {
        name = opts.name,
        width = width,
        height = height,
        onClick = opts.onClick,
    })
    button.gui2Disabled = opts.disabled and true or false

    local label = GUI2:CreateText(button, opts.text or opts.label or "", opts.fontSizeKey or "font.size.md", normalColor, opts.justifyH or "CENTER")
    label:SetPoint("CENTER", 0, 1)
    label:SetWordWrap(false)
    button.text = label

    local underline = GUI2:CreateTexture(button, normalColor, "ARTWORK")
    underline:SetHeight(opts.underlineHeight or 1)
    underline:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -1)
    underline:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -1)
    button.underline = underline

    local function Refresh(frame, hovered)
        local colorKey = frame.gui2Disabled and disabledColor or (hovered and hoverColor or normalColor)
        GUI2:SetTextColorKey(frame.text, colorKey)
        GUI2:SetTexturePaintKey(frame.underline, colorKey)
        frame:SetAlpha(frame.gui2Disabled and 0.55 or 1)
    end

    function button:SetText(value)
        if self.text then self.text:SetText(value or "") end
    end
    function button:SetDisabled(disabled)
        disabled = disabled and true or false
        if self.gui2DisabledInitialized and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        if self.EnableMouse then self:EnableMouse(not self.gui2Disabled) end
        Refresh(self, false)
        self.gui2DisabledInitialized = true
        return true
    end
    function button:RefreshTheme()
        Refresh(self, self:IsMouseOver() and not self.gui2Disabled)
    end

    button:SetScript("OnEnter", function(self)
        Refresh(self, true)
        if opts.onEnter then opts.onEnter(self) end
    end)
    button:SetScript("OnLeave", function(self)
        Refresh(self, false)
        if opts.onLeave then opts.onLeave(self) end
    end)
    AddTooltip(button, opts)
    button:SetDisabled(button.gui2Disabled)
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
        icon = opts.icon or opts.texture or opts.source,
        atlas = opts.atlas,
        fallbackIcon = opts.fallbackIcon,
        texCoords = opts.texCoords,
        crop = opts.crop,
        pixelPolicy = opts.iconPixelPolicy,
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
        local isSilent, animate, setOptions = ParseSetOptions(silent)
        checked = checked and true or false
        if self.gui2ValueInitialized
            and self.gui2Checked == checked
            and not (setOptions and setOptions.force == true) then
            if not isSilent then CommitValue(opts, self, checked) end
            return false
        end
        local previous = self.gui2Checked
        self.gui2Checked = checked
        self.box.gui2Surface = self.gui2Disabled and "color.control.disabled" or (self.gui2Checked and "color.accent.fill" or "color.control.bg")
        GUI2:RefreshPrimitive(self.box)
        GUI2:SetBorderColor(self.box, self.gui2Disabled and "color.border.subtle" or (self.gui2Checked and "color.border.accent" or "color.border.default"))
        if animate and previous ~= nil and previous ~= self.gui2Checked and not self.gui2Disabled then
            PlayMotionOverlay(self.boxMotion, self, "checkbox-check")
        end
        self.gui2ValueInitialized = true
        if not isSilent then CommitValue(opts, self, self.gui2Checked) end
        return true
    end
    function frame:SetValue(value, silent)
        return self:SetChecked(value, silent)
    end
    function frame:SetDisabled(disabled, force)
        disabled = disabled and true or false
        if force ~= true
            and self.gui2DisabledInitialized
            and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        if self.gui2Disabled then
            GUI2:SetTextColorKey(self.text, "color.text.disabled")
            if self.Disable then self:Disable() end
        else
            GUI2:SetTextColorKey(self.text, "color.text.primary")
            if self.Enable then self:Enable() end
        end
        self:SetChecked(self.gui2Checked, { silent = true, force = true })
        self.gui2DisabledInitialized = true
        return true
    end
    function frame:RefreshTheme()
        self:SetDisabled(self.gui2Disabled, true)
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
        local isSilent, animate, setOptions = ParseSetOptions(silent)
        local previousChecked = self.gui2Checked
        local checked = value == onValue or value == true and onValue == true
        local normalizedValue = checked and onValue or offValue
        if self.gui2ValueInitialized
            and self.gui2Value == normalizedValue
            and not (setOptions and setOptions.force == true) then
            if not isSilent then CommitValue(opts, self, normalizedValue) end
            return false
        end
        local oldLeft = previousChecked and (self.width - thumbWidth - 3) or 3
        local newLeft = checked and (self.width - thumbWidth - 3) or 3
        self.gui2Value = normalizedValue
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
        self.gui2ValueInitialized = true
        if not isSilent then CommitValue(opts, self, self.gui2Value) end
        return true
    end
    function frame:SetChecked(checked, silent)
        if checked then
            return self:SetValue(onValue, silent)
        else
            return self:SetValue(offValue, silent)
        end
    end
    function frame:SetDisabled(disabled, force)
        disabled = disabled and true or false
        if force ~= true
            and self.gui2DisabledInitialized
            and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        if self.gui2Disabled then
            if self.Disable then self:Disable() end
        else
            if self.Enable then self:Enable() end
        end
        self:SetValue(self.gui2Value, { silent = true, force = true })
        self.gui2DisabledInitialized = true
        return true
    end
    function frame:RefreshTheme()
        GUI2:ApplyBackdrop(self, self.gui2Surface or "color.control.track")
        self:SetDisabled(self.gui2Disabled, true)
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
        self:SetValue(self.gui2Value, { silent = true, force = true })
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
        local isSilent, animate, setOptions = ParseSetOptions(silent)
        if self.gui2ValueInitialized
            and self.value == value
            and not (setOptions and setOptions.force == true) then
            if not isSilent then CommitValue(opts, self, value) end
            return false
        end
        local oldIndex = self.selectedIndex
        local newIndex
        for i, data in ipairs(values) do
            if data.value == value and data.disabled ~= true then
                newIndex = i
                break
            end
        end
        if not newIndex then return false end
        self.value = value
        for i, button in ipairs(self.buttons) do
            local selected = i == newIndex
            button:SetSelected(selected)
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
        self.gui2ValueInitialized = true
        if not isSilent then CommitValue(opts, self, value) end
        return true
    end

    function frame:SetItemDisabled(value, disabled)
        disabled = disabled == true
        for i, data in ipairs(values) do
            if data.value == value then
                if data.disabled == disabled then return false end
                data.disabled = disabled
                local button = self.buttons[i]
                if button and button.SetDisabled then
                    button:SetDisabled(disabled)
                end
                if disabled and self.selectedIndex == i then
                    for fallbackIndex, fallback in ipairs(values) do
                        if fallback.disabled ~= true then
                            self.gui2ValueInitialized = nil
                            self:SetValue(fallback.value)
                            break
                        end
                    end
                end
                return true
            end
        end
        return false
    end

    for i, data in ipairs(values) do
        local button = self:CreateButton(frame, { text = data.text, width = eachWidth, height = height, tone = "default" })
        button:SetPoint("LEFT", (i - 1) * eachWidth, 0)
        button:SetScript("OnClick", function()
            if data.disabled == true then return end
            frame:SetValue(data.value)
        end)
        if data.disabled == true and button.SetDisabled then
            button:SetDisabled(true)
        end
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
    local initialValue = GetValue(opts) or values[1].value
    if not frame:SetValue(initialValue, true) then
        for _, data in ipairs(values) do
            if data.disabled ~= true then
                frame:SetValue(data.value, true)
                break
            end
        end
    end
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
            disabled = type(item) == "table"
                and item.disabled == true or false,
        }
    end
    opts.values = values
    return self:CreateBinaryChoice(parent, opts)
end

function GUI2.Form:CreateUnderlineTabs(parent, opts)
    opts = opts or {}
    local sourceItems = opts.items or { "One", "Two", "Three" }
    local items = {}
    for i, item in ipairs(sourceItems) do
        items[i] = {
            text = type(item) == "table" and item.text or item,
            value = type(item) == "table" and item.value or item,
            disabled = type(item) == "table" and item.disabled == true or false,
        }
    end

    local height = opts.height or math_max(GetControlHeight(30), 30)
    local scrollable = opts.overflow == "scroll"
    local explicitWidth = tonumber(opts.width)
    local contentAlignment = opts.contentAlignment == "CENTER" and "CENTER" or "LEFT"
    local itemPaddingX = opts.itemPaddingX or GUI2:GetMetric("layout.gap.inline", 8)
    local gap = opts.gap or (GUI2:GetMetric("layout.gap.inline", 8) * 3)
    local minItemWidth = opts.minItemWidth or 44
    local scrollButtonWidth = opts.scrollButtonWidth or 28
    local scrollButtonGap = opts.scrollButtonGap or 2
    local scrollEpsilon = 2
    local indicatorOverhang = opts.indicatorOverhang or 4
    local indicatorOffsetY = opts.indicatorOffsetY or -4
    local indicatorHeight = opts.indicatorHeight or 2
    local baselineHeight = opts.baselineHeight or 1
    local showBaseline = opts.showBaseline == true
    local fontSizeKey = opts.fontSizeKey or "font.size.md"
    local fontSize = GUI2:GetMetric(fontSizeKey, 13)
    local labelOffsetY = opts.labelOffsetY or 1
    local lineOffsetY = opts.lineOffsetY
    if lineOffsetY == nil then
        lineOffsetY = math_max(
            0,
            math_floor(((height - fontSize) / 2) + labelOffsetY + indicatorOffsetY + 0.5)
        )
    end
    local normalColor = opts.colorKey or "color.text.secondary"
    local selectedColor = opts.selectedColorKey or "color.text.primary"
    local hoverColor = opts.hoverColorKey or "color.text.accent"
    local disabledColor = opts.disabledColorKey or "color.text.disabled"
    local indicatorColor = opts.indicatorColorKey or "color.border.accent"
    local baselineColor = opts.baselineColorKey or "color.border.subtle"
    local literalIndicatorColor = type(opts.indicatorColor) == "table" and opts.indicatorColor or nil
    local literalSelectedColor = type(opts.selectedColor) == "table" and opts.selectedColor or nil
    local literalHoverColor = type(opts.hoverColor) == "table" and opts.hoverColor or nil
    local literalArrowColor = type(opts.arrowColor) == "table" and opts.arrowColor or nil
    local literalArrowHoverColor = type(opts.arrowHoverColor) == "table" and opts.arrowHoverColor or nil
    local literalArrowDisabledColor = type(opts.arrowDisabledColor) == "table" and opts.arrowDisabledColor or nil

    local frame = GUI2:CreateFrame(parent, {
        name = opts.name,
        width = opts.width or 1,
        height = height,
    })
    frame.buttons = {}
    frame.items = items
    frame.gui2Disabled = opts.disabled == true
    frame.gui2UnderlineTabsScrollable = scrollable
    frame.gui2UnderlineTabStarts = {}
    frame.gui2UnderlineTabEnds = {}
    frame.gui2UnderlineTabsScrollOffset = 0
    frame.gui2UnderlineTabsScrollTarget = 0
    ConfigureMotion(frame, opts)

    local tabParent = frame
    if scrollable then
        local viewport = GUI2:CreateScrollFrame(frame, {
            template = false,
            child = true,
            width = explicitWidth or 1,
            height = height,
            childWidth = 1,
            childHeight = height,
        })
        viewport:SetPoint("LEFT", frame, "LEFT", 0, 0)
        viewport:SetHeight(height)
        if viewport.EnableMouseWheel then viewport:EnableMouseWheel(false) end
        frame.scrollViewport = viewport
        frame.scrollChild = viewport.child
        tabParent = viewport.child

        local function PaintScrollIcon(icon, state)
            local literalColor
            local colorKey
            if state == "hover" then
                literalColor = literalArrowHoverColor
                colorKey = "color.text.accent"
            elseif state == "disabled" then
                literalColor = literalArrowDisabledColor
                colorKey = "color.text.disabled"
            else
                literalColor = literalArrowColor
                colorKey = "color.text.secondary"
            end
            if literalColor then
                icon:SetVertexColor(unpack(literalColor))
            else
                -- Atlas icons must keep their texture source across state changes.
                -- Applying a paint token would replace the atlas with a solid color texture.
                icon:SetVertexColor(GUI2:GetColor(colorKey))
            end
        end

        local function CreateScrollButton(point, atlas, direction)
            local button = GUI2:CreateButtonFrame(frame, {
                width = scrollButtonWidth,
                height = height,
            })
            button:SetPoint(point, frame, point, 0, 0)
            local icon = GUI2:CreateIcon(button, {
                atlas = atlas,
                size = 14,
                crop = false,
            })
            icon:SetPoint("CENTER")
            PaintScrollIcon(icon, "normal")
            button.icon = icon
            button.gui2ScrollDirection = direction
            button:SetScript("OnEnter", function(selfButton)
                if not selfButton.gui2ScrollDisabled then
                    PaintScrollIcon(selfButton.icon, "hover")
                end
            end)
            button:SetScript("OnLeave", function(selfButton)
                PaintScrollIcon(
                    selfButton.icon,
                    selfButton.gui2ScrollDisabled and "disabled" or "normal"
                )
            end)
            button:Hide()
            return button
        end

        frame.previousButton = CreateScrollButton(
            "LEFT",
            "common-icon-backarrow",
            -1
        )
        frame.nextButton = CreateScrollButton(
            "RIGHT",
            "common-icon-forwardarrow",
            1
        )
    end

    if showBaseline then
        local baseline = GUI2:CreateTexture(frame, nil, "ARTWORK")
        GUI2:SetTexturePaintKey(baseline, baselineColor)
        baseline:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, lineOffsetY)
        baseline:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, lineOffsetY)
        baseline:SetHeight(
            GUI2.GetPixelSize
                and GUI2:GetPixelSize(baseline, baselineHeight, 1)
                or baselineHeight
        )
        frame.baseline = baseline
    end
    frame.indicators = {}

    local function ItemIsDisabled(button)
        return frame.gui2Disabled or button.gui2ItemDisabled == true
    end

    local function RefreshIndicator(button)
        local indicator = button and button.indicator
        if not indicator then return end
        if not button.gui2Selected or not button.text then
            indicator:Hide()
            return
        end
        indicator:ClearAllPoints()
        local textWidth = button.text:GetStringWidth()
        indicator:SetWidth(math_max(1, math_ceil(textWidth + (indicatorOverhang * 2))))
        indicator:SetPoint("BOTTOM", button, "BOTTOM", 0, lineOffsetY)
        local heightPixels = GUI2.GetPixelSize
            and GUI2:GetPixelSize(indicator, indicatorHeight, 1)
            or indicatorHeight
        indicator:SetHeight(heightPixels)
        indicator:SetAlpha(frame.gui2Disabled and 0.55 or 1)
        indicator:Show()
        frame.indicator = indicator
    end

    local function RefreshButton(button)
        local disabled = ItemIsDisabled(button)
        local colorKey
        if disabled then
            colorKey = disabledColor
        elseif button.gui2Selected then
            colorKey = selectedColor
        elseif button.gui2Hovered then
            colorKey = hoverColor
        else
            colorKey = normalColor
        end
        local literalColor
        if button.gui2Selected then
            literalColor = literalSelectedColor
        elseif button.gui2Hovered then
            literalColor = literalHoverColor
        end
        if literalColor then
            button.text:SetTextColor(unpack(literalColor))
        else
            GUI2:SetTextColorKey(button.text, colorKey)
        end
        if button.EnableMouse then button:EnableMouse(not disabled) end
        button:SetAlpha(disabled and 0.55 or 1)
        RefreshIndicator(button)
    end

    local function RefreshIndicators()
        frame.indicator = nil
        for _, button in ipairs(frame.buttons) do
            RefreshIndicator(button)
        end
    end

    local function FindEnabledIndex(value)
        local firstEnabled
        for i, button in ipairs(frame.buttons) do
            if button.gui2ItemDisabled ~= true then
                firstEnabled = firstEnabled or i
                if items[i].value == value then return i end
            end
        end
        return firstEnabled
    end

    local function SetScrollButtonState(button, enabled)
        if not button then return end
        button.gui2ScrollDisabled = not enabled
        button:SetAlpha(enabled and 1 or 0.35)
        if enabled then
            if button.Enable then button:Enable() end
            if literalArrowColor then
                button.icon:SetVertexColor(unpack(literalArrowColor))
            else
                button.icon:SetVertexColor(GUI2:GetColor("color.text.secondary"))
            end
        else
            if button.Disable then button:Disable() end
            if literalArrowDisabledColor then
                button.icon:SetVertexColor(unpack(literalArrowDisabledColor))
            else
                button.icon:SetVertexColor(GUI2:GetColor("color.text.disabled"))
            end
        end
    end

    local function StopScrollAnimation(owner, finish)
        local animation = YUI.Animation
        if animation and type(animation.StopOwner) == "function" then
            animation:StopOwner(owner, finish == true)
        end
    end

    function frame:SetScrollOffset(offset)
        offset = math_max(0, math_min(tonumber(offset) or 0, self.maxScrollOffset or 0))
        self.gui2UnderlineTabsScrollOffset = offset
        if self.scrollViewport and self.scrollViewport.SetHorizontalScroll then
            self.scrollViewport:SetHorizontalScroll(offset)
        end
        return offset
    end

    function frame:RefreshOverflow()
        if not self.gui2UnderlineTabsScrollable then return false end
        local width = explicitWidth or self:GetWidth() or 1
        local hasOverflow = (self.contentWidth or 0) > width
        local viewportWidth = width
        if hasOverflow then
            viewportWidth = math_max(1, width - ((scrollButtonWidth + scrollButtonGap) * 2))
            self.previousButton:Show()
            self.nextButton:Show()
            self.scrollViewport:ClearAllPoints()
            self.scrollViewport:SetPoint(
                "LEFT",
                self.previousButton,
                "RIGHT",
                scrollButtonGap,
                0
            )
        else
            self.previousButton:Hide()
            self.nextButton:Hide()
            self.scrollViewport:ClearAllPoints()
            if contentAlignment == "CENTER" then
                viewportWidth = math_max(1, math_min(width, self.contentWidth or width))
                self.scrollViewport:SetPoint("CENTER", self, "CENTER", 0, 0)
            else
                self.scrollViewport:SetPoint("LEFT", self, "LEFT", 0, 0)
            end
        end
        self.scrollViewport:SetWidth(viewportWidth)
        self.viewportWidth = viewportWidth
        self.maxScrollOffset = math_max(0, (self.contentWidth or 0) - viewportWidth)
        local offset = self:SetScrollOffset(self.gui2UnderlineTabsScrollTarget or 0)
        self.gui2UnderlineTabsScrollTarget = offset
        SetScrollButtonState(self.previousButton, offset > scrollEpsilon)
        SetScrollButtonState(self.nextButton, offset < (self.maxScrollOffset - scrollEpsilon))
        self.overflowActive = hasOverflow
        return hasOverflow
    end

    function frame:AnimateScrollTo(offset, animate)
        offset = math_max(0, math_min(tonumber(offset) or 0, self.maxScrollOffset or 0))
        self.gui2UnderlineTabsScrollTarget = offset
        local current = self.gui2UnderlineTabsScrollOffset or 0
        if not animate or not GUI2.PlayControlMotion then
            StopScrollAnimation(self, false)
            self:SetScrollOffset(offset)
            self:RefreshOverflow()
            return false
        end
        local handle = GUI2:PlayControlMotion(self, "underline-tabs-scroll", {
            from = current,
            to = offset,
            duration = opts.scrollDuration or 0.16,
            easing = "sineOut",
            owner = self,
            onUpdate = function(value)
                self:SetScrollOffset(value)
            end,
            onFinished = function(_, _, finished)
                if finished then
                    self:SetScrollOffset(offset)
                    self:RefreshOverflow()
                end
            end,
        })
        if not handle then
            self:SetScrollOffset(offset)
            self:RefreshOverflow()
            return false
        end
        SetScrollButtonState(self.previousButton, offset > scrollEpsilon)
        SetScrollButtonState(self.nextButton, offset < (self.maxScrollOffset - scrollEpsilon))
        return true
    end

    function frame:ScrollByTab(direction, animate)
        if not self.overflowActive then return false end
        direction = tonumber(direction) or 0
        if direction == 0 then return false end
        local base = self.gui2UnderlineTabsScrollTarget or 0
        local target = direction > 0 and self.maxScrollOffset or 0
        if direction > 0 then
            for _, startOffset in ipairs(self.gui2UnderlineTabStarts) do
                if startOffset > base + scrollEpsilon then
                    target = startOffset
                    break
                end
            end
        else
            for i = #self.gui2UnderlineTabStarts, 1, -1 do
                local startOffset = self.gui2UnderlineTabStarts[i]
                if startOffset < base - scrollEpsilon then
                    target = startOffset
                    break
                end
            end
        end
        target = math_max(0, math_min(target, self.maxScrollOffset or 0))
        if (self.maxScrollOffset or 0) - target <= scrollEpsilon then
            target = self.maxScrollOffset or 0
        end
        if math.abs(target - base) <= scrollEpsilon then return false end
        self:AnimateScrollTo(target, animate ~= false)
        return true
    end

    function frame:EnsureValueVisible(value, animate)
        if not self.overflowActive then return false end
        local index
        for i, item in ipairs(items) do
            if item.value == value then index = i break end
        end
        if not index then return false end
        local startOffset = self.gui2UnderlineTabStarts[index] or 0
        local endOffset = self.gui2UnderlineTabEnds[index] or startOffset
        local current = self.gui2UnderlineTabsScrollTarget or 0
        local viewportWidth = self.viewportWidth or explicitWidth or 1
        local target = current
        if startOffset < current then
            target = startOffset
        elseif endOffset > current + viewportWidth then
            target = endOffset - viewportWidth
        end
        target = math_max(0, math_min(target, self.maxScrollOffset or 0))
        if math.abs(target - current) < 0.5 then return false end
        self:AnimateScrollTo(target, animate == true)
        return true
    end

    function frame:Relayout()
        local x = 0
        for i, button in ipairs(self.buttons) do
            local textWidth = button.text and button.text:GetStringWidth() or 0
            local itemWidth = math_max(minItemWidth, math_ceil(textWidth + (itemPaddingX * 2)))
            button:SetSize(itemWidth, height)
            button:ClearAllPoints()
            button:SetPoint("LEFT", tabParent, "LEFT", x, 0)
            button.gui2UnderlineTabWidth = itemWidth
            self.gui2UnderlineTabStarts[i] = x
            self.gui2UnderlineTabEnds[i] = x + itemWidth
            x = x + itemWidth
            if i < #self.buttons then x = x + gap end
        end
        self.contentWidth = math_max(x, 1)
        if self.scrollChild then
            self.scrollChild:SetSize(self.contentWidth, height)
            self:SetSize(explicitWidth or self.contentWidth, height)
            self:RefreshOverflow()
        else
            self:SetSize(explicitWidth or self.contentWidth, height)
        end
        RefreshIndicators()
        return x
    end

    function frame:GetValue()
        return self.value
    end

    function frame:SetValue(value, setOptions)
        local silent, _, options = ParseSetOptions(setOptions)
        local index = FindEnabledIndex(value)
        if not index then return false end
        local resolvedValue = items[index].value
        if self.gui2ValueInitialized
            and self.value == resolvedValue
            and not (options and options.force == true) then
            return false
        end

        self.value = resolvedValue
        self.selectedIndex = index
        self.indicator = nil
        for i, button in ipairs(self.buttons) do
            button.gui2Selected = i == index
            RefreshButton(button)
        end
        self.gui2ValueInitialized = true
        self:EnsureValueVisible(resolvedValue, options and options.animate == true)
        if not silent then CommitValue(opts, self, resolvedValue) end
        return true
    end

    function frame:SetDisabled(disabled)
        disabled = disabled == true
        if self.gui2DisabledInitialized and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        for _, button in ipairs(self.buttons) do
            RefreshButton(button)
        end
        if self.baseline then
            self.baseline:SetAlpha(disabled and 0.55 or 1)
        end
        self.gui2DisabledInitialized = true
        return true
    end

    function frame:SetItemDisabled(value, disabled)
        for i, button in ipairs(self.buttons) do
            if items[i].value == value then
                disabled = disabled == true
                if button.gui2ItemDisabled == disabled then return false end
                button.gui2ItemDisabled = disabled
                items[i].disabled = disabled
                if disabled and self.selectedIndex == i then
                    self.gui2ValueInitialized = nil
                    local fallbackIndex = FindEnabledIndex(nil)
                    if fallbackIndex then
                        self:SetValue(items[fallbackIndex].value)
                    else
                        self.value = nil
                        self.selectedIndex = nil
                        RefreshIndicators()
                    end
                else
                    RefreshButton(button)
                end
                return true
            end
        end
        return false
    end

    function frame:SetItemText(value, text)
        for i, button in ipairs(self.buttons) do
            if items[i].value == value then
                items[i].text = text or ""
                button.text:SetText(items[i].text)
                self:Relayout()
                return true
            end
        end
        return false
    end

    function frame:RefreshTheme()
        if self.baseline then
            GUI2:SetTexturePaintKey(self.baseline, baselineColor)
        end
        for _, button in ipairs(self.buttons) do
            if literalIndicatorColor then
                button.indicator:SetColorTexture(unpack(literalIndicatorColor))
            else
                GUI2:SetTexturePaintKey(button.indicator, indicatorColor)
            end
            RefreshButton(button)
        end
        if self.gui2UnderlineTabsScrollable then
            self:RefreshOverflow()
        end
    end

    for i, data in ipairs(items) do
        local button = GUI2:CreateButtonFrame(tabParent, {
            width = minItemWidth,
            height = height,
        })
        local label = GUI2:CreateText(
            button,
            data.text or "",
            fontSizeKey,
            normalColor,
            "CENTER"
        )
        label:SetPoint("CENTER", 0, labelOffsetY)
        label:SetWordWrap(false)
        button.text = label
        local indicator = GUI2:CreateTexture(button, nil, "OVERLAY")
        if literalIndicatorColor then
            indicator:SetColorTexture(unpack(literalIndicatorColor))
        else
            GUI2:SetTexturePaintKey(indicator, indicatorColor)
        end
        indicator:Hide()
        button.indicator = indicator
        frame.indicators[i] = indicator
        InheritMotion(indicator, button)
        button.gui2ItemDisabled = data.disabled == true
        button.gui2TabValue = data.value
        button:SetScript("OnClick", function(selfButton)
            if not ItemIsDisabled(selfButton) then
                frame:SetValue(selfButton.gui2TabValue)
            end
        end)
        button:SetScript("OnEnter", function(selfButton)
            if ItemIsDisabled(selfButton) then return end
            selfButton.gui2Hovered = true
            RefreshButton(selfButton)
        end)
        button:SetScript("OnLeave", function(selfButton)
            selfButton.gui2Hovered = false
            RefreshButton(selfButton)
        end)
        frame.buttons[i] = button
    end

    if frame.previousButton then
        frame.previousButton:SetScript("OnClick", function()
            frame:ScrollByTab(-1, true)
        end)
        frame.nextButton:SetScript("OnClick", function()
            frame:ScrollByTab(1, true)
        end)
        frame:SetScript("OnHide", function(self)
            StopScrollAnimation(self, false)
        end)
    end

    frame:Relayout()
    local initialValue = GetValue(opts)
    if initialValue == nil and items[1] then initialValue = items[1].value end
    frame:SetValue(initialValue, true)
    frame:SetDisabled(frame.gui2Disabled)
    GUI2:RegisterThemeObject(frame)
    return frame
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
    local labelFontSizeKey = opts.labelFontSizeKey or "font.size.md"
    local labelColorKey = opts.labelColorKey or "color.text.primary"
    if opts.label and opts.inline then
        local label = GUI2:CreateText(container, opts.label, labelFontSizeKey, labelColorKey)
        label:SetPoint("LEFT", 0, 0)
        labelWidth = opts.labelWidth or math_max(label:GetStringWidth() + 10, 30)
        label:SetWidth(labelWidth)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        container.label = label
    elseif opts.label then
        local label = GUI2:CreateText(container, opts.label, labelFontSizeKey, labelColorKey)
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
    local interactionStartValue
    local interactionStartStepKey
    local precision = opts.precision or 2
    local step = tonumber(opts.step)
    if step and step <= 0 then step = nil end
    if step and step % 1 == 0 then precision = 0 end
    local fmt = "%." .. precision .. "f"

    local function Normalize(value)
        value = tonumber(value) or minValue
        value = math_max(minValue, math_min(maxValue, value))
        if step then
            local stepKey = math_floor(
                ((value - minValue) / step) + 0.5 + SLIDER_STEP_ROUND_EPSILON
            )
            value = minValue + (stepKey * step)
            value = math_max(minValue, math_min(maxValue, value))
            return value, stepKey
        end
        return value, value
    end

    local function Update(value, source, silent, forceCommit, diagnosticTrigger)
        local rawValue = value
        local stepKey
        value, stepKey = Normalize(value)
        if diagnosticTrigger == "value" and container.gui2SliderDiagnostic then
            RecordSliderDiagnosticEvent(container, rawValue, value, stepKey)
        end
        local valueChanged = not container.gui2ValueInitialized
            or container.gui2SliderStepKey ~= stepKey
        local commitNeeded = container.gui2CommittedSliderStepKey ~= stepKey
        if not valueChanged
            and not (forceCommit == true and commitNeeded) then
            if silent then
                container.gui2CommittedSliderStepKey = stepKey
                container.gui2CommittedSliderValue = value
                container.gui2FinalizedSliderStepKey = stepKey
                container.gui2FinalizedSliderValue = value
            end
            return false
        end
        if valueChanged then
            container.value = value
            container.gui2SliderStepKey = stepKey
            if source ~= "slider" then
                slider.gui2Updating = true
                slider:SetValue(value)
                slider.gui2Updating = false
            end
            if source ~= "input" then input:SetText(string_format(fmt, value)) end
        end
        local leftButtonDown = false
        if type(_G.IsMouseButtonDown) == "function" then
            local mouseOK, mouseDown = pcall(_G.IsMouseButtonDown, "LeftButton")
            leftButtonDown = mouseOK and mouseDown == true
        end
        if silent
            or (
                forceCommit ~= true
                and opts.instantUpdate == false
                and (dragging or leftButtonDown)
            )
        then
            container.gui2ValueInitialized = true
            if silent then
                container.gui2CommittedSliderStepKey = stepKey
                container.gui2CommittedSliderValue = value
                container.gui2FinalizedSliderStepKey = stepKey
                container.gui2FinalizedSliderValue = value
            end
            return true
        end
        if not commitNeeded then
            container.gui2ValueInitialized = true
            return valueChanged
        end
        if container.gui2SliderDiagnostic then
            local commitStarted = SliderDiagnosticTimeMs()
            CommitValue(opts, container, value)
            RecordSliderDiagnosticCommit(container, value, stepKey, commitStarted)
        else
            CommitValue(opts, container, value)
        end
        container.gui2CommittedSliderStepKey = stepKey
        container.gui2CommittedSliderValue = value
        container.gui2ValueInitialized = true
        return true
    end

    local function Finalize(value, source, startStepKey)
        local stepKey
        value, stepKey = Normalize(value)
        if startStepKey == nil then
            startStepKey = container.gui2FinalizedSliderStepKey
        end
        local changed = startStepKey ~= stepKey
        container.gui2FinalizedSliderStepKey = stepKey
        container.gui2FinalizedSliderValue = value
        if changed and type(opts.onCommit) == "function" then
            opts.onCommit(container, value, source)
        end
        return changed
    end

    function container:GetValue()
        return self.value
    end
    function container:SetValue(value, silent)
        Update(value, nil, silent)
    end
    function container:SetDisabled(disabled)
        disabled = disabled and true or false
        if self.gui2DisabledInitialized and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
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
        self.gui2DisabledInitialized = true
        return true
    end
    function container:RefreshTheme()
        if self.slider and self.slider.RefreshTheme then self.slider:RefreshTheme() end
        if self.inputBox and self.inputBox.RefreshTheme then self.inputBox:RefreshTheme() end
        if self.label then GUI2:SetTextColorKey(self.label, self.gui2Disabled and "color.text.disabled" or "color.text.primary") end
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if slider.gui2Updating then return end
        slider.gui2Updating = true
        Update(value, "slider", false, false, "value")
        slider.gui2Updating = false
    end)
    slider:SetScript("OnMouseDown", function()
        dragging = true
        interactionStartValue, interactionStartStepKey = Normalize(slider:GetValue())
        BeginSliderDiagnostic(
            container,
            opts,
            interactionStartValue,
            interactionStartStepKey
        )
    end)
    slider:SetScript("OnMouseUp", function()
        dragging = false
        Update(slider:GetValue(), "slider", false, true, "release")
        Finalize(
            slider:GetValue(),
            "release",
            interactionStartStepKey
        )
        interactionStartValue = nil
        interactionStartStepKey = nil
        FinishSliderDiagnostic(container)
    end)
    input:SetScript("OnEnterPressed", function(editbox)
        local startStepKey = container.gui2FinalizedSliderStepKey
        Update(editbox:GetText(), "input")
        Finalize(container.value, "input", startStepKey)
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
        local text = tostring(value or "")
        if self.gui2ValueInitialized
            and self:GetText() == text
            and silent == true then
            return false
        end
        self.gui2SettingText = true
        self:SetText(text)
        self.gui2SettingText = nil
        self.gui2ValueInitialized = true
        if not silent then CommitValue(opts, self, self:GetText()) end
        return true
    end
    function edit:SetDisabled(disabled)
        disabled = disabled and true or false
        if self.gui2DisabledInitialized and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        if self.gui2Disabled then
            if self.Disable then self:Disable() end
            self:SetTextColor(GUI2:GetColor("color.text.disabled"))
            self.gui2Bg.gui2Surface = "color.control.disabled"
        else
            if self.Enable then self:Enable() end
            self.gui2Bg.gui2Surface = "color.control.bg"
        end
        self:RefreshTheme()
        self.gui2DisabledInitialized = true
        return true
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

function GUI2.Form:CreateSpellIDInput(parent, opts)
    opts = opts or {}
    BindItem(opts)

    local width = ResolveFormWidth(opts, "wide", opts.width or 300)
    local height = opts.height or GetControlHeight(26)
    local inputWidth = opts.inputWidth or 104
    local iconSize = opts.iconSize or math_max(height - 4, 18)
    local gap = opts.gap or GetFormMetric("gap", 10)
    local fallbackIcon = opts.fallbackIcon or "Interface\\Icons\\INV_Misc_QuestionMark"

    local frame = CreateFrame("Frame", opts.name, parent)
    frame:SetSize(width, height)
    frame.gui2Disabled = opts.disabled and true or false
    ConfigureMotion(frame, opts)

    local input = self:CreateEditBox(frame, {
        width = inputWidth,
        height = height,
        autoFocus = opts.autoFocus == true,
        text = opts.value or opts.text or GetValue(opts) or "",
        tooltip = opts.tooltip,
    })
    input:SetPoint("LEFT", frame, "LEFT", 0, 0)
    if input.SetNumeric then input:SetNumeric(true) end
    if input.SetMaxLetters then input:SetMaxLetters(opts.maxLetters or 10) end
    frame.input = input

    local icon = GUI2:CreateIcon(frame, {
        icon = fallbackIcon,
        size = iconSize,
        crop = false,
    })
    icon:SetPoint("LEFT", input, "RIGHT", gap, 0)
    frame.icon = icon

    local status = GUI2:CreateText(frame, "", "font.size.sm", "color.text.secondary", "LEFT")
    status:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    status:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    status:SetHeight(height)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)
    frame.statusText = status

    local function SetInputBorder(colorKey)
        if input.gui2Bg then
            GUI2:SetBorderColor(input.gui2Bg, colorKey or "color.border.default")
        end
    end

    local function SetStatus(text, colorKey, borderKey)
        status:SetText(text or "")
        GUI2:SetTextColorKey(status, colorKey or "color.text.secondary")
        SetInputBorder(borderKey)
    end

    local function SetIcon(texture)
        if icon.SetTexture then
            icon:SetTexture(texture or fallbackIcon)
        elseif GUI2.SetIconTexture then
            GUI2:SetIconTexture(icon, texture or fallbackIcon)
        end
        if icon.SetVertexColor then icon:SetVertexColor(1, 1, 1, 1) end
        icon:Show()
    end

    local function ResolveSpell(spellID)
        local Spell = YUI.API and YUI.API.Spell or YUI.WOW_API
        local info
        if Spell and Spell.GetInfo then
            local ok, result = pcall(Spell.GetInfo, spellID)
            if ok then info = result end
        end
        local texture = info and (info.iconID or info.originalIconID)
        if Spell and Spell.GetTexture then
            local ok, result = pcall(Spell.GetTexture, spellID)
            if ok and result then texture = result end
        elseif Spell and Spell.GetSpellIcon then
            local ok, result = pcall(Spell.GetSpellIcon, spellID)
            if ok and result then texture = result end
        end
        if not (info and info.name) and GetSpellInfo then
            local ok, name, _, iconID, castTime, minRange, maxRange, resolvedSpellID = pcall(GetSpellInfo, spellID)
            if ok and name then
                info = info or {}
                info.name = name
                info.iconID = iconID
                info.castTime = castTime
                info.minRange = minRange
                info.maxRange = maxRange
                info.spellID = resolvedSpellID or spellID
                texture = texture or iconID
            end
        end
        return info, texture
    end

    local function CommitSpellValue(rawText, silent)
        local text = tostring(rawText or "")
        local value = tonumber(text)
        local info, texture
        if text == "" then
            SetIcon(fallbackIcon)
            SetStatus(opts.placeholder or "输入法术 ID", "color.text.secondary", "color.border.default")
        elseif not value or value <= 0 then
            SetIcon(fallbackIcon)
            SetStatus("请输入有效法术 ID", "color.state.warning", "color.state.warning")
        else
            info, texture = ResolveSpell(value)
            if info and info.name then
                SetIcon(texture or fallbackIcon)
                SetStatus(tostring(info.name), "color.text.primary", "color.border.accent")
            else
                SetIcon(fallbackIcon)
                SetStatus("未找到法术 ID " .. tostring(value), "color.state.error", "color.state.error")
            end
        end

        frame.value = value
        frame.spellInfo = info
        if not silent then
            if opts.set then opts.set(value) end
            if opts.onChange then opts.onChange(value, info, frame) end
        end
    end

    function frame:GetValue()
        return self.value
    end
    function frame:SetValue(value, silent)
        local text = value ~= nil and tostring(value) or ""
        if self.gui2ValueInitialized
            and input:GetText() == text
            and silent == true then
            return false
        end
        self.gui2SettingText = true
        input:SetText(text)
        self.gui2SettingText = nil
        CommitSpellValue(input:GetText(), silent)
        self.gui2ValueInitialized = true
        return true
    end
    function frame:SetDisabled(disabled)
        disabled = disabled and true or false
        if self.gui2DisabledInitialized and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        if input.SetDisabled then input:SetDisabled(disabled) end
        if self.gui2Disabled then
            GUI2:SetTextColorKey(status, "color.text.disabled")
        else
            CommitSpellValue(input:GetText(), true)
        end
        self.gui2DisabledInitialized = true
        return true
    end
    function frame:RefreshTheme()
        if input.RefreshTheme then input:RefreshTheme() end
        CommitSpellValue(input:GetText(), true)
    end

    local previousOnTextChanged = input.GetScript and input:GetScript("OnTextChanged")
    input:SetScript("OnTextChanged", function(box, userInput)
        if previousOnTextChanged then previousOnTextChanged(box, userInput) end
        if frame.gui2SettingText or box.gui2SettingText then return end
        CommitSpellValue(box:GetText())
    end)
    input:SetScript("OnEnterPressed", function(box)
        CommitSpellValue(box:GetText())
        box:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(box)
        box:SetText(frame.value ~= nil and tostring(frame.value) or "")
        CommitSpellValue(box:GetText(), true)
        box:ClearFocus()
    end)

    AddTooltip(frame, opts)
    frame:SetValue(opts.value or opts.text or GetValue(opts), true)
    frame:SetDisabled(opts.disabled)
    GUI2:RegisterThemeObject(frame)
    return frame
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

        local function ApplyIconColor()
            local color = option.iconColor
            if type(color) == "table" then
                texture:SetVertexColor(
                    color.r or color[1] or 1,
                    color.g or color[2] or 1,
                    color.b or color[3] or 1,
                    color.a or color[4] or 1
                )
            else
                texture:SetVertexColor(1, 1, 1, 1)
            end
        end

        local iconData = option.iconData
        local icons = YUI.API and YUI.API.Icons
        if type(iconData) == "table" and icons and icons.ApplyIcon and icons.ApplyIcon(texture, iconData) then
            local texCoord = option.texCoord or option.texCoords
            if texCoord then
                texture:SetTexCoord(unpack(texCoord))
            end
            ApplyIconColor()
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
        ApplyIconColor()
        texture:SetAlpha(1)
        texture:SetBlendMode(option.blendMode or "BLEND")
        texture:Show()
        return true
    end

    local function FindOption(value, resolvedOptions)
        for _, option in ipairs(resolvedOptions or ResolveOptions()) do
            local optionTable = NormalizeOption(option)
            if optionTable.value == value then
                return optionTable
            end
        end
        return nil
    end

    local function OptionText(value, option)
        if type(opts.getLabel) == "function" then
            local label = opts.getLabel(value)
            if label ~= nil then return tostring(label) end
        end
        option = option or FindOption(value)
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
        local isSilent, _, setOptions = ParseSetOptions(silent)
        if self.gui2ValueInitialized
            and self.value == value
            and not (setOptions and setOptions.force == true) then
            if not isSilent then CommitValue(opts, self, value) end
            return false
        end
        self.value = value
        local option = FindOption(value)
        self.gui2FullText = OptionText(value, option) or ""
        ApplySelectionIcon(self, option)
        if self.text then self.text:SetText((self.gui2HasSelectionIcon and "" or " ") .. self.gui2FullText) end
        self.gui2ValueInitialized = true
        if not isSilent then CommitValue(opts, self, value) end
        return true
    end
    function frame:RefreshOptions()
        return self:SetValue(self.value, {
            silent = true,
            animate = false,
            force = true,
        })
    end
    function frame:SetDisabled(disabled)
        disabled = disabled and true or false
        if self.gui2DisabledInitialized and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        if self.gui2Disabled then
            if self.Disable then self:Disable() end
        else
            if self.Enable then self:Enable() end
        end
        self:RefreshTheme()
        self.gui2DisabledInitialized = true
        return true
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
        local resolvedOptions = ResolveOptions()
        if type(opts.getLabel) ~= "function" then
            local selected = FindOption(self.value, resolvedOptions)
            self.gui2FullText = OptionText(self.value, selected) or ""
            ApplySelectionIcon(self, selected)
            if self.text then
                self.text:SetText(
                    (self.gui2HasSelectionIcon and "" or " ")
                        .. self.gui2FullText
                )
            end
        end
        local menuOptions = {}
        for _, option in ipairs(resolvedOptions) do
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
                iconColor = opt.iconColor,
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

local function ResolveLSMFontPath(value)
    if value == "chat" and _G.ChatFontNormal
        and _G.ChatFontNormal.GetFont then
        local path = _G.ChatFontNormal:GetFont()
        if type(path) == "string" and path ~= "" then return path end
    elseif value == "damage" and _G.DAMAGE_TEXT_FONT then
        return _G.DAMAGE_TEXT_FONT
    elseif value == "default" or value == nil or value == "" then
        return GUI2:GetFont("font.family.body")
    end
    if LSM and LSM.Fetch then
        local path = LSM:Fetch("font", value, true)
        if type(path) == "string" and path ~= "" then return path end
    end
    return GUI2:GetFont("font.family.body")
end

local function BuildLSMFontOptions(opts)
    local options = {}
    local seen = {}
    local fontSize = GUI2.Fonts and GUI2.Fonts.size_normal
        or GUI2:GetMetric("font.size.md", 13)

    local function AddOption(source)
        local option = {}
        if type(source) == "table" then
            for key, value in pairs(source) do option[key] = value end
        else
            option.text = tostring(source)
            option.value = source
        end
        option.value = option.value or option.text
        if option.value == nil or seen[option.value] then return end
        option.text = option.text or tostring(option.value)
        seen[option.value] = true

        local baseRender = option.render
        local fontPath = option.fontPath or ResolveLSMFontPath(option.value)
        option.render = function(button)
            if baseRender then baseRender(button) end
            if button and button.text and fontPath then
                button.text:SetFont(fontPath, fontSize)
            end
        end
        options[#options + 1] = option
    end

    local prepend = opts.prependOptions
    if type(prepend) == "function" then prepend = prepend() end
    for _, option in ipairs(type(prepend) == "table" and prepend or {}) do
        AddOption(option)
    end

    local names = LSM and LSM.List and LSM:List("font")
    if type(names) ~= "table" then
        names = {}
        local mediaTable = LSM and LSM.HashTable
            and LSM:HashTable("font") or nil
        for name in pairs(type(mediaTable) == "table" and mediaTable or {}) do
            names[#names + 1] = name
        end
        table_sort(names)
    end
    for _, name in ipairs(names) do AddOption(name) end
    return options
end

function GUI2.Form:BuildLSMFontOptions(opts)
    return BuildLSMFontOptions(opts or {})
end

function GUI2.Form:CreateLSMFontDropdown(parent, opts)
    opts = opts or {}
    local dropdownOpts = {}
    for key, value in pairs(opts) do dropdownOpts[key] = value end
    dropdownOpts.options = function()
        return BuildLSMFontOptions(opts)
    end

    local dropdown = self:CreateDropdown(parent, dropdownOpts)
    local baseSetValue = dropdown.SetValue
    local baseRefreshTheme = dropdown.RefreshTheme

    local function ApplySelectedFont(control, value)
        if opts.previewSelectedFont == false then return end
        if not (control and control.text and control.text.SetFont) then return end
        local path = ResolveLSMFontPath(value)
        if not path then return end
        local _, size, flags
        if control.text.GetFont then
            _, size, flags = control.text:GetFont()
        end
        local ok, applied = pcall(
            control.text.SetFont,
            control.text,
            path,
            size or GUI2:GetMetric("font.size.md", 13),
            flags or ""
        )
        if not ok or applied == false then
            pcall(
                control.text.SetFont,
                control.text,
                GUI2:GetFont("font.family.body"),
                size or GUI2:GetMetric("font.size.md", 13),
                flags or ""
            )
        end
    end

    function dropdown:SetValue(value, silent)
        local changed = baseSetValue(self, value, silent)
        ApplySelectedFont(self, value)
        return changed
    end
    function dropdown:RefreshTheme(...)
        if baseRefreshTheme then baseRefreshTheme(self, ...) end
        ApplySelectedFont(self, self.value)
    end
    dropdown:SetValue(dropdown.value, {
        silent = true,
        animate = false,
        force = true,
    })
    return dropdown
end

function GUI2.Form:BuildFontOutlineOptions(opts)
    opts = type(opts) == "table" and opts or {}
    local options = {}
    local prepend = opts.prependOptions
    local values = type(opts.values) == "table" and opts.values or {}
    if type(prepend) == "function" then prepend = prepend() end
    for _, option in ipairs(type(prepend) == "table" and prepend or {}) do
        options[#options + 1] = option
    end
    options[#options + 1] = {
        text = opts.noneText or GetCoreText("font_outline.none", "None"),
        value = values.none or "none",
    }
    options[#options + 1] = {
        text = opts.outlineText or GetCoreText("font_outline.outline", "Outline"),
        value = values.outline or "outline",
    }
    options[#options + 1] = {
        text = opts.thickText or GetCoreText("font_outline.thick", "Thick Outline"),
        value = values.thick or "thick",
    }
    options[#options + 1] = {
        text = opts.shadowText or GetCoreText("font_outline.shadow", "Shadow"),
        value = values.shadow or "shadow",
    }
    options[#options + 1] = {
        text = opts.outlineShadowText
            or GetCoreText("font_outline.outline_shadow", "Outline + Shadow"),
        value = values.outlineShadow or "outlineShadow",
    }
    return options
end

local SOUND_PREVIEW_BUTTON_SIZE = 26
local SOUND_PREVIEW_BUTTON_GAP = 8
local SOUND_PREVIEW_PLAY_ICON = "play"
local SOUND_PREVIEW_STOP_ICON = "square"
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
            local icon = active and SOUND_PREVIEW_STOP_ICON or SOUND_PREVIEW_PLAY_ICON
            if GUI2.ApplyMicroIcon then
                GUI2:ApplyMicroIcon(button.soundPreviewIcon, icon, button.soundPreviewIconSize or 16)
            else
                GUI2:SetIconTexture(button.soundPreviewIcon, GUI2.GetSettingsIcon and GUI2:GetSettingsIcon(icon) or nil)
                if button.soundPreviewIcon.SetTexCoord then
                    button.soundPreviewIcon:SetTexCoord(0, 1, 0, 1)
                end
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
    local iconPadding = opts.iconPadding or 5
    local iconSize = opts.iconSize or 16
    local icon = GUI2:CreateMicroIcon(button, {
        iconName = SOUND_PREVIEW_PLAY_ICON,
        size = iconSize,
        maxSize = math_max(size - iconPadding * 2, 1),
        minPhysicalPixels = opts.iconMinPhysicalPixels or 11,
    })
    button.soundPreviewIconSize = iconSize
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
            if not copy.actionAtlas and not copy.actionIconAtlas and not copy.actionIcon and not copy.actionTexture and not copy.actionMicroIcon then
                copy.actionMicroIcon = SOUND_PREVIEW_PLAY_ICON
                copy.actionMicroIconSize = copy.actionMicroIconSize or 16
                copy.actionIconPadding = copy.actionIconPadding or 5
            end
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
        local nextValue = value or opts.default or "None"
        if frame.gui2ValueInitialized
            and frame.value == nextValue
            and silent == true then
            return false
        end
        frame.value = nextValue
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
        frame.gui2ValueInitialized = true
        return true
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
        disabled = disabled and true or false
        if self.gui2DisabledInitialized and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        if self.dropdown and self.dropdown.SetDisabled then
            self.dropdown:SetDisabled(self.gui2Disabled)
        end
        if self.previewButton and self.previewButton.SetDisabled then
            self.previewButton:SetDisabled(self.gui2Disabled)
        end
        self.gui2DisabledInitialized = true
        return true
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
                    local name = spec.displayName or spec.name or spec.text or tostring(value)
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

function GUI2.Form:CreateRaceDropdown(parent, opts)
    opts = opts or {}

    local function ResolveRaces()
        local races = opts.races or opts.options
        if type(races) == "function" then races = races() end
        return type(races) == "table" and races or {}
    end

    local function BuildOptions()
        local options = {}
        local Icons = YUI.API and YUI.API.Icons

        for _, race in ipairs(ResolveRaces()) do
            if type(race) == "table" then
                local raceID = tonumber(race.raceID)
                local raceFile = race.raceFile
                    or race.clientFileString
                    or race.file
                local value = race.value
                if value == nil then value = raceFile or raceID end

                if value ~= nil then
                    local name = race.displayName
                        or race.name
                        or race.text
                        or tostring(value)
                    local iconData = race.iconData
                    if not iconData and Icons and Icons.GetRaceIcon
                        and raceFile then
                        iconData = Icons.GetRaceIcon(
                            raceFile,
                            race.gender or opts.gender
                        )
                    end

                    options[#options + 1] = {
                        text = name,
                        selectionText = race.selectionText or name,
                        value = value,
                        raceID = raceID,
                        raceFile = raceFile,
                        gender = race.gender,
                        icon = race.icon,
                        texture = race.texture,
                        atlas = race.atlas,
                        texCoord = race.texCoord,
                        texCoords = race.texCoords,
                        iconData = iconData,
                        iconSize = race.iconSize or opts.iconSize or 18,
                        blendMode = race.blendMode,
                        render = race.render,
                        func = race.func,
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

local activeColorPickerControl
local colorPickerHideHookInstalled = false

local function FinishActiveColorPicker(cancelled)
    local control = activeColorPickerControl
    if not control then return false end
    activeColorPickerControl = nil
    if control.FinishColorPreview then
        return control:FinishColorPreview(cancelled == true)
    end
    return false
end

local function EnsureColorPickerHideHook()
    if colorPickerHideHookInstalled or not ColorPickerFrame then
        return colorPickerHideHookInstalled
    end
    if ColorPickerFrame.HookScript then
        ColorPickerFrame:HookScript("OnHide", function()
            FinishActiveColorPicker(false)
        end)
        colorPickerHideHookInstalled = true
    end
    return colorPickerHideHookInstalled
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
    function frame:SetColorLifecycle(preview, commit, cancel)
        self.gui2ColorPreview = type(preview) == "function"
            and preview or nil
        self.gui2ColorCommit = type(commit) == "function"
            and commit or nil
        self.gui2ColorCancel = type(cancel) == "function"
            and cancel or nil
        return self
    end
    function frame:PreviewColorValue(r, g, b, a)
        local pending = self.gui2ColorPendingValue
        if not pending then
            pending = {}
            self.gui2ColorPendingValue = pending
        end
        a = a == nil and 1 or a
        if pending[1] == r and pending[2] == g
            and pending[3] == b and pending[4] == a then
            return false
        end
        pending[1], pending[2], pending[3], pending[4] = r, g, b, a
        self.value = pending
        opts.value = pending
        UpdateChip()
        if self.gui2ColorPreview then
            self.gui2ColorPreview(pending, self)
        end
        return true
    end
    function frame:FinishColorPreview(cancelled)
        if self.gui2ColorPreviewActive ~= true then return false end
        self.gui2ColorPreviewActive = false
        local value = cancelled
            and self.gui2ColorOriginalValue
            or self.gui2ColorPendingValue
        if not value then return false end
        self.value = value
        opts.value = value
        UpdateChip()
        if cancelled then
            if self.gui2ColorCancel then
                self.gui2ColorCancel(value, self)
            elseif self.gui2ColorPreview then
                self.gui2ColorPreview(value, self)
            end
        elseif self.gui2ColorCommit then
            self.gui2ColorCommit(value, self)
        else
            CommitValue(opts, self, value)
        end
        return true
    end
    function frame:GetValue()
        local r, g, b, a = CurrentColor()
        return { r, g, b, a }
    end
    function frame:SetValue(value, silent)
        if value == nil then return end
        local isSilent, animate, setOptions = ParseSetOptions(silent)
        if self.gui2ValueInitialized
            and ValuesEqual(self.value, value)
            and not (setOptions and setOptions.force == true) then
            if not isSilent then CommitValue(opts, self, value) end
            return false
        end
        self.value = value
        opts.value = value
        if not isSilent then CommitValue(opts, self, value) end
        UpdateChip()
        if animate and not self.gui2Disabled then
            PlayMotionOverlay(self.chipMotion, self, "color-chip")
        end
        self.gui2ValueInitialized = true
        return true
    end
    function frame:SetDisabled(disabled)
        disabled = disabled and true or false
        if self.gui2DisabledInitialized and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        if self.gui2Disabled then
            if self.Disable then self:Disable() end
        else
            if self.Enable then self:Enable() end
        end
        self:RefreshTheme()
        self.gui2DisabledInitialized = true
        return true
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
        local enhanced = self.gui2ColorPreview ~= nil
        if enhanced then
            if activeColorPickerControl
                and activeColorPickerControl ~= self then
                FinishActiveColorPicker(false)
            end
            local original = self.gui2ColorOriginalValue or {}
            local pending = self.gui2ColorPendingValue or {}
            self.gui2ColorOriginalValue = original
            self.gui2ColorPendingValue = pending
            original[1], original[2], original[3], original[4] = r, g, b, a
            pending[1], pending[2], pending[3], pending[4] = r, g, b, a
            self.gui2ColorPreviewActive = true
            activeColorPickerControl = self
            EnsureColorPickerHideHook()
        end
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
                if enhanced then
                    self:PreviewColorValue(nr, ng, nb, na or 1)
                else
                    local value = { nr, ng, nb, na or 1 }
                    self:SetValue(value)
                end
            end,
            opacityFunc = function()
                if info.swatchFunc then info.swatchFunc() end
            end,
            cancelFunc = function()
                if enhanced then
                    if activeColorPickerControl == self then
                        activeColorPickerControl = nil
                    end
                    self:FinishColorPreview(true)
                else
                    local value = { r, g, b, a }
                    self:SetValue(value)
                end
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
        if ColorPickerFrame.SetFrameStrata then
            ColorPickerFrame:SetFrameStrata("TOOLTIP")
        end
        if ColorPickerFrame.SetFrameLevel then
            ColorPickerFrame:SetFrameLevel(9800)
        end
        if ColorPickerFrame.SetToplevel then
            ColorPickerFrame:SetToplevel(true)
        end
        if ColorPickerFrame.Raise then ColorPickerFrame:Raise() end
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
    frame:SetColorLifecycle(opts.preview, opts.commit, opts.cancel)
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
    local defaultLines = style == "pixel" and 6 or 4
    local defaultThickness = style == "pixel" and 2 or 1
    return {
        style = style,
        size = NormalizeGlowSizeOption(value.size, fallback.size),
        lines = tonumber(value.lines) or tonumber(fallback.lines) or defaultLines,
        thickness = tonumber(value.thickness) or tonumber(fallback.thickness) or defaultThickness,
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
                { key = "speed", label = labels.speed or "速度", min = 0, max = 3, step = 0.05, precision = 2 },
                { key = "alpha", label = labels.alpha or "透明", min = 0.1, max = 1, step = 0.05, precision = 2 },
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
            parts[#parts + 1] = (labels.summarySpeed or "速") .. " " .. FormatGlowSummaryNumber(current.speed, 2)
        elseif current.style == "soft" then
            parts[#parts + 1] = (labels.summarySize or "尺寸") .. " " .. FormatGlowSummaryNumber(current.size, 2)
        else
            parts[#parts + 1] = (labels.summarySize or "尺寸") .. " " .. FormatGlowSummaryNumber(current.size, 2)
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
        icon = opts.settingsIcon or (GUI2.GetSettingsIcon and GUI2:GetSettingsIcon("settings")) or "Interface\\Icons\\INV_Misc_Gear_01",
        atlas = opts.settingsAtlas,
        texCoords = opts.settingsTexCoords or opts.settingsTexCoord,
        crop = opts.settingsCrop ~= nil and opts.settingsCrop or false,
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
            icon = (GUI2.GetSettingsIcon and GUI2:GetSettingsIcon("rotate-ccw")) or nil,
            iconSize = 14,
            iconCrop = false,
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
        local normalized = NormalizeGlowOptionsValue(nextValue, opts.default)
        local isSilent, _, setOptions = ParseSetOptions(silent)
        if self.gui2ValueInitialized
            and ValuesEqual(value, normalized)
            and not (setOptions and setOptions.force == true) then
            if not isSilent then CommitValue(opts, self, value) end
            return false
        end
        value = normalized
        self.value = normalized
        if self.dropdown and self.dropdown.SetValue then
            self.dropdown:SetValue(value.style, true)
        end
        RefreshSettingsTooltip()
        if not isSilent then
            CommitValue(opts, self, value)
        end
        self.gui2ValueInitialized = true
        return true
    end
    function frame:SetDisabled(disabled)
        disabled = disabled and true or false
        if self.gui2DisabledInitialized and self.gui2Disabled == disabled then
            return false
        end
        self.gui2Disabled = disabled
        for _, control in ipairs(self.controls) do
            if control.SetDisabled then
                control:SetDisabled(self.gui2Disabled)
            elseif self.gui2Disabled and control.Disable then
                control:Disable()
            elseif control.Enable then
                control:Enable()
            end
        end
        self.gui2DisabledInitialized = true
        return true
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
        "分段选择（SegmentedControl）", "下划线页签（UnderlineTabs）", "滑条（Slider）",
        "输入框（EditBox）", "下拉框（Dropdown）", "颜色选择（ColorPicker）",
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
    local underlineTabs = self:CreateUnderlineTabs(choicePanel, {
        value = "minimap",
        items = {
            { text = "小地图", value = "minimap" },
            { text = "世界地图设置", value = "world" },
            { text = "禁用页签", value = "disabled", disabled = true },
        },
    })
    underlineTabs:SetPoint("TOPLEFT", 12, -158)

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
