do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
if not YUI then return end

YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local Animation = YUI.Animation

local CONTROL_MOTION_PROFILES = {
    low = {
        quick = 0.07,
        duration = 0.10,
        medium = 0.14,
        distance = 4,
        amount = 0.035,
        pressScale = 0.985,
        hoverScale = 1.015,
        popScale = 0.92,
    },
    standard = {
        quick = 0.09,
        duration = 0.12,
        medium = 0.18,
        distance = 7,
        amount = 0.055,
        pressScale = 0.97,
        hoverScale = 1.025,
        popScale = 0.88,
    },
    high = {
        quick = 0.11,
        duration = 0.16,
        medium = 0.24,
        distance = 10,
        amount = 0.075,
        pressScale = 0.955,
        hoverScale = 1.04,
        popScale = 0.84,
    },
}

local function NormalizeOptions(options)
    if type(options) == "number" then
        return { duration = options }
    end
    return type(options) == "table" and options or {}
end

local function CopyTable(source)
    local result = {}
    if type(source) == "table" then
        for key, value in pairs(source) do
            result[key] = value
        end
    end
    return result
end

local function ReadMotionStrengthFromDB()
    local appearance = GUI2.Appearance
    if appearance and appearance.PeekDB then
        local db = appearance:PeekDB()
        if type(db) == "table" and type(db.userOptions) == "table" then
            return db.userOptions.motionStrength
        end
    end

    if YUI.DB and YUI.DB.GetProfile then
        local profile = YUI.DB:GetProfile(YUI.ProductId or "suite")
        local db = type(profile) == "table" and profile.Appearance
        if type(db) == "table" and type(db.userOptions) == "table" then
            return db.userOptions.motionStrength
        end
    end

    return nil
end

function GUI2:GetMotionStrength()
    local strength = ReadMotionStrengthFromDB()
    if strength == "off" or strength == "low" or strength == "standard" or strength == "high" then
        return strength
    end
    return "standard"
end

function GUI2:GetControlMotionProfile()
    local strength = self:GetMotionStrength()
    if strength == "off" then
        return nil, strength
    end
    return CONTROL_MOTION_PROFILES[strength] or CONTROL_MOTION_PROFILES.standard, strength
end

function GUI2:ShouldAnimateControl(target, options)
    if not Animation then
        return false
    end
    if target and target.gui2Animate == false then
        return false
    end
    if type(options) == "table" and (options.animate == false or options.motion == false) then
        return false
    end
    if self:GetMotionStrength() == "off" then
        return false
    end
    return true
end

function GUI2:GetControlMotionDuration(profile, options)
    options = type(options) == "table" and options or {}
    if type(options.duration) == "number" then
        return options.duration
    end
    profile = profile or CONTROL_MOTION_PROFILES.standard
    local key = options.durationKey or "duration"
    return profile[key] or profile.duration or Animation.defaults.duration
end

function GUI2:PlayControlMotion(target, key, spec)
    if not target or not Animation or not Animation.Play then
        return nil
    end
    spec = CopyTable(spec)
    if not self:ShouldAnimateControl(target, spec) then
        return nil
    end

    local profile = self:GetControlMotionProfile()
    if not profile then
        return nil
    end

    spec.owner = spec.owner or target.gui2MotionOwner or target
    spec.key = spec.key or ("control-" .. tostring(key or "motion"))
    spec.duration = self:GetControlMotionDuration(profile, spec)
    spec.easing = spec.easing or "sineOut"
    spec.driver = spec.driver or "tween"

    if spec.effects then
        return Animation:Play(target, spec)
    end
    if spec.from ~= nil or spec.to ~= nil or spec.onUpdate then
        spec.target = spec.target or target
        return Animation:Tween(spec)
    end
    return nil
end

function GUI2:PlayControlScale(target, key, toScale, options)
    if not target or not Animation or not Animation.Scale then
        return nil
    end
    options = CopyTable(options)
    if not self:ShouldAnimateControl(target, options) then
        return nil
    end

    local profile = self:GetControlMotionProfile()
    if not profile then
        return nil
    end

    local fromScale = options.fromScale
    if fromScale == nil and target.GetScale then
        fromScale = target:GetScale()
    end
    options.owner = options.owner or target.gui2MotionOwner or target
    options.key = options.key or ("control-" .. tostring(key or "scale"))
    options.duration = self:GetControlMotionDuration(profile, options)
    options.easing = options.easing or "sineOut"
    return Animation:Scale(target, fromScale or 1, toScale or 1, options)
end

function GUI2:PlayControlPop(target, key, options)
    if not target or not Animation or not Animation.Pop then
        return nil
    end
    options = CopyTable(options)
    if not self:ShouldAnimateControl(target, options) then
        return nil
    end

    local profile = self:GetControlMotionProfile()
    if not profile then
        return nil
    end

    options.owner = options.owner or target.gui2MotionOwner or target
    options.key = options.key or ("control-" .. tostring(key or "pop"))
    options.duration = self:GetControlMotionDuration(profile, options)
    options.fromScale = options.fromScale or profile.popScale
    options.toScale = options.toScale or 1
    return Animation:Pop(target, options)
end

function GUI2:PlayControlPulse(target, key, options)
    if not target or not Animation or not Animation.Pulse then
        return nil
    end
    options = CopyTable(options)
    if not self:ShouldAnimateControl(target, options) then
        return nil
    end

    local profile = self:GetControlMotionProfile()
    if not profile then
        return nil
    end

    options.owner = options.owner or target.gui2MotionOwner or target
    options.key = options.key or ("control-" .. tostring(key or "pulse"))
    options.duration = self:GetControlMotionDuration(profile, options)
    options.amount = options.amount or profile.amount
    return Animation:Pulse(target, options)
end

function GUI2:Animate(target, spec)
    if not Animation or not Animation.Play then
        return nil
    end
    return Animation:Play(target, spec)
end

function GUI2:FadeIn(target, options)
    if not Animation or not Animation.FadeIn then
        return nil
    end
    options = NormalizeOptions(options)
    options.owner = options.owner or self
    return Animation:FadeIn(target, options)
end

function GUI2:FadeOut(target, options)
    if not Animation or not Animation.FadeOut then
        return nil
    end
    options = NormalizeOptions(options)
    options.owner = options.owner or self
    return Animation:FadeOut(target, options)
end

function GUI2:SlideIn(target, options)
    if not Animation or not Animation.SlideIn then
        return nil
    end
    options = NormalizeOptions(options)
    options.owner = options.owner or self
    return Animation:SlideIn(target, options)
end

function GUI2:SlideOut(target, options)
    if not Animation or not Animation.SlideOut then
        return nil
    end
    options = NormalizeOptions(options)
    options.owner = options.owner or self
    return Animation:SlideOut(target, options)
end

function GUI2:Pop(target, options)
    if not Animation or not Animation.Pop then
        return nil
    end
    options = NormalizeOptions(options)
    options.owner = options.owner or self
    return Animation:Pop(target, options)
end

function GUI2:Pulse(target, options)
    if not Animation or not Animation.Pulse then
        return nil
    end
    options = NormalizeOptions(options)
    options.owner = options.owner or self
    return Animation:Pulse(target, options)
end
