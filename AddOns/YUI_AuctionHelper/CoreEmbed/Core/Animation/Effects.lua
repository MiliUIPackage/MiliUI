do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
local Animation = YUI.Animation
if not Animation then return end

local function CopyOptions(options)
    local result = {}
    if type(options) == "number" then
        result.duration = options
        return result
    end
    if type(options) == "table" then
        for key, value in pairs(options) do
            result[key] = value
        end
    end
    return result
end

local function SafeFinishedCallback(callback, callbackLabel, ...)
    if type(callback) ~= "function" then
        return
    end

    local ok, err = pcall(callback, ...)
    if not ok and YUI and YUI.Debug then
        YUI:Debug("Animation finished callback error:", callbackLabel, err)
    end
end

local function WithFinished(options, callback)
    local previous = options.onFinished
    options.onFinished = function(handle, reason, finished)
        SafeFinishedCallback(callback, "effect", handle, reason, finished)
        SafeFinishedCallback(previous, "caller", handle, reason, finished)
    end
end

local function DirectionOffset(direction, distance)
    distance = distance or 18
    direction = tostring(direction or "up"):lower()
    if direction == "down" or direction == "bottom" then
        return 0, -distance
    elseif direction == "left" then
        return -distance, 0
    elseif direction == "right" then
        return distance, 0
    end
    return 0, distance
end

local function ResolveAnimationTarget(target, options)
    if type(options) == "table" and options.animationTarget then
        return options.animationTarget
    end
    return target
end

function Animation:ResolveDriver(target, spec)
    local nativeDriver = self.NativeDriver
    local tweenDriver = self.TweenDriver

    if spec and spec.driver == "native" and nativeDriver and nativeDriver:CanPlay(target, spec) then
        return nativeDriver
    end
    if spec and spec.driver == "tween" then
        return tweenDriver
    end
    if nativeDriver and nativeDriver:CanPlay(target, spec) and spec.preferTween ~= true then
        return nativeDriver
    end
    return tweenDriver
end

function Animation:Play(target, spec)
    spec = type(spec) == "table" and spec or {}

    local ok, reason = self:CanAnimateTarget(target, spec)
    if not ok then
        return self:Noop(reason, target, spec)
    end

    if type(spec.effects) ~= "table" or #spec.effects == 0 then
        return self:Noop("missing-effects", target, spec)
    end

    local mode = self:GetDefaultMode(spec)
    if mode == "replace" then
        self:StopTarget(target, self:_TargetKey(spec.key), spec.finishExisting)
    end

    local driver = self:ResolveDriver(target, spec)
    if not driver then
        return self:Noop("missing-driver", target, spec)
    end

    return self:CreateHandle(driver, target, spec):Play()
end

function Animation:Tween(spec)
    spec = type(spec) == "table" and spec or {}
    local target = spec.target

    if target then
        local ok, reason = self:CanAnimateTarget(target, spec)
        if not ok then
            return self:Noop(reason, target, spec)
        end
        if self:GetDefaultMode(spec) == "replace" then
            self:StopTarget(target, self:_TargetKey(spec.key), spec.finishExisting)
        end
    end

    return self:CreateHandle(self.TweenDriver, target, spec):Play()
end

function Animation:Fade(target, fromAlpha, toAlpha, options)
    options = CopyOptions(options)
    options.driver = options.driver or "tween"
    options.key = options.key or "alpha"
    options.effects = {
        { type = "alpha", from = fromAlpha, to = toAlpha },
    }
    return self:Play(target, options)
end

function Animation:FadeIn(target, options)
    options = CopyOptions(options)
    if target and target.Show then
        target:Show()
    end
    return self:Fade(target, options.from or 0, options.to or 1, options)
end

function Animation:FadeOut(target, options)
    options = CopyOptions(options)
    local hideOnFinish = options.hide ~= false
    WithFinished(options, function(_, _, finished)
        if finished and hideOnFinish and target and target.Hide then
            target:Hide()
        end
    end)
    return self:Fade(target, options.from or (target and target.GetAlpha and target:GetAlpha()) or 1, options.to or 0, options)
end

function Animation:SlideIn(target, options)
    options = CopyOptions(options)
    local slideFrom = options.from or options.direction
    local fromX, fromY = DirectionOffset(slideFrom, options.distance)
    if target and target.Show then
        target:Show()
    end
    options.from = nil
    options.to = nil
    options.driver = options.driver or "tween"
    options.key = options.key or "slide"
    options.effects = {
        { type = "alpha", from = options.fromAlpha or 0, to = options.toAlpha or 1 },
        { type = "translation", fromX = options.fromX or fromX, fromY = options.fromY or fromY, toX = options.toX or 0, toY = options.toY or 0 },
    }
    return self:Play(target, options)
end

function Animation:SlideOut(target, options)
    options = CopyOptions(options)
    local slideTo = options.to or options.direction
    local toX, toY = DirectionOffset(slideTo, options.distance)
    local hideOnFinish = options.hide ~= false
    WithFinished(options, function(_, _, finished)
        if finished and hideOnFinish and target and target.Hide then
            target:Hide()
        end
    end)
    options.from = nil
    options.to = nil
    options.driver = options.driver or "tween"
    options.key = options.key or "slide"
    options.effects = {
        { type = "alpha", from = options.fromAlpha or (target and target.GetAlpha and target:GetAlpha()) or 1, to = options.toAlpha or 0 },
        { type = "translation", fromX = options.fromX or 0, fromY = options.fromY or 0, toX = options.toX or toX, toY = options.toY or toY },
    }
    return self:Play(target, options)
end

function Animation:Pop(target, options)
    options = CopyOptions(options)
    local animationTarget = ResolveAnimationTarget(target, options)
    if target and target.Show then
        target:Show()
    end
    options.sourceTarget = target
    options.driver = options.driver or "tween"
    options.key = options.key or "pop"
    options.easing = options.easing or "outBack"
    options.effects = {
        { type = "alpha", from = options.fromAlpha or 0.2, to = options.toAlpha or 1 },
        { type = "scale", from = options.fromScale or 0.86, to = options.toScale or 1 },
    }
    return self:Play(animationTarget, options)
end

function Animation:Pulse(target, options)
    options = CopyOptions(options)
    local animationTarget = ResolveAnimationTarget(target, options)
    local baseScale = options.baseScale or (animationTarget and animationTarget.GetScale and animationTarget:GetScale()) or 1
    local amount = options.amount or 0.08
    options.target = animationTarget
    options.sourceTarget = target
    options.key = options.key or "pulse"
    options.from = 0
    options.to = 1
    options.easing = options.easing or "sineInOut"
    options.onUpdate = function(value)
        if animationTarget and animationTarget.SetScale then
            animationTarget:SetScale(baseScale + (math.sin(value * math.pi) * amount))
        end
    end
    WithFinished(options, function()
        if animationTarget and animationTarget.SetScale then
            animationTarget:SetScale(baseScale)
        end
    end)
    return self:Tween(options)
end

function Animation:Scale(target, fromScale, toScale, options)
    options = CopyOptions(options)
    local animationTarget = ResolveAnimationTarget(target, options)
    options.sourceTarget = target
    options.driver = options.driver or "tween"
    options.key = options.key or "scale"
    options.effects = {
        { type = "scale", from = fromScale, to = toScale },
    }
    return self:Play(animationTarget, options)
end

function Animation:FloatText(target, options)
    options = CopyOptions(options)
    options.direction = options.direction or "up"
    options.distance = options.distance or 42
    options.duration = options.duration or 0.85
    options.key = options.key or "float-text"
    options.hide = options.hide ~= false
    return self:SlideOut(target, options)
end
