local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...
local Animation = YUI.Animation
if not Animation then return end

local Driver = Animation.NativeDriver or {}
Animation.NativeDriver = Driver

Driver.active = Driver.active or {}

local NATIVE_TYPES = {
    alpha = "Alpha",
    translation = "Translation",
    translate = "Translation",
    move = "Translation",
    scale = "Scale",
    rotation = "Rotation",
    rotate = "Rotation",
}

local function SafeCall(method, object, ...)
    if type(method) ~= "function" then
        return false
    end
    local ok = pcall(method, object, ...)
    return ok
end

local function EffectType(effect)
    return string.lower(tostring(effect and (effect.type or effect.kind) or ""))
end

function Driver:CanPlay(target, spec)
    if not target or type(target.CreateAnimationGroup) ~= "function" or type(spec) ~= "table" then
        return false
    end

    local effects = spec.effects
    if type(effects) ~= "table" or #effects == 0 then
        return false
    end

    for _, effect in ipairs(effects) do
        if not NATIVE_TYPES[EffectType(effect)] then
            return false
        end
    end

    return true
end

local function ApplyFinalValue(handle)
    local target = handle and handle.target
    local spec = handle and handle.spec
    if not target or type(spec) ~= "table" or type(spec.effects) ~= "table" then
        return
    end

    for _, effect in ipairs(spec.effects) do
        local effectType = EffectType(effect)
        if effectType == "alpha" and effect.to ~= nil then
            SafeCall(target.SetAlpha, target, effect.to)
        elseif effectType == "scale" then
            local toScale = effect.to or effect.scale or effect.toScale
            if toScale then
                SafeCall(target.SetScale, target, toScale)
            end
        elseif (effectType == "rotation" or effectType == "rotate") and target.SetRotation then
            local value = effect.radians or effect.toRadians
            if not value and (effect.degrees or effect.toDegrees or effect.to) then
                value = ((effect.degrees or effect.toDegrees or effect.to) * math.pi) / 180
            end
            if value then
                SafeCall(target.SetRotation, target, value)
            end
        end
    end
end

function Driver:Play(handle)
    local target = handle and handle.target
    local spec = handle and handle.spec or {}
    if not target or type(target.CreateAnimationGroup) ~= "function" then
        handle:_Complete("unsupported", false)
        return
    end

    local group = target:CreateAnimationGroup()
    handle.group = group
    self.active[handle] = true

    if group.SetToFinalAlpha then
        SafeCall(group.SetToFinalAlpha, group, true)
    end

    local duration = Animation:GetDefaultDuration(spec)
    local smoothing = Animation:GetNativeSmoothing(spec.easing)
    local created = 0

    for _, effect in ipairs(spec.effects or {}) do
        local nativeType = NATIVE_TYPES[EffectType(effect)]
        if nativeType then
            local anim = group:CreateAnimation(nativeType)
            created = created + 1
            SafeCall(anim.SetOrder, anim, effect.order or 1)
            SafeCall(anim.SetDuration, anim, effect.duration or duration)
            SafeCall(anim.SetStartDelay, anim, effect.delay or 0)
            SafeCall(anim.SetSmoothing, anim, effect.smoothing or smoothing)

            if nativeType == "Alpha" then
                local fromAlpha = effect.from
                if fromAlpha == nil and target.GetAlpha then
                    fromAlpha = target:GetAlpha()
                end
                SafeCall(anim.SetFromAlpha, anim, fromAlpha == nil and 1 or fromAlpha)
                SafeCall(anim.SetToAlpha, anim, effect.to == nil and 1 or effect.to)
            elseif nativeType == "Translation" then
                local x = (effect.toX or effect.x or 0) - (effect.fromX or 0)
                local y = (effect.toY or effect.y or 0) - (effect.fromY or 0)
                SafeCall(anim.SetOffset, anim, x, y)
            elseif nativeType == "Scale" then
                local fromScale = effect.from or effect.fromScale or 1
                local toScale = effect.to or effect.scale or effect.toScale or 1
                local scale = fromScale ~= 0 and (toScale / fromScale) or toScale
                SafeCall(anim.SetScale, anim, scale, scale)
                if effect.origin then
                    SafeCall(anim.SetOrigin, anim, effect.origin, effect.originX or 0, effect.originY or 0)
                end
            elseif nativeType == "Rotation" then
                if effect.radians or effect.toRadians then
                    SafeCall(anim.SetRadians, anim, effect.radians or effect.toRadians)
                else
                    SafeCall(anim.SetDegrees, anim, effect.degrees or effect.toDegrees or effect.to or 0)
                end
                if effect.origin then
                    SafeCall(anim.SetOrigin, anim, effect.origin, effect.originX or 0, effect.originY or 0)
                end
            end
        end
    end

    if created == 0 then
        self.active[handle] = nil
        handle:_Complete("unsupported", false)
        return
    end

    group:SetScript("OnFinished", function()
        Driver.active[handle] = nil
        ApplyFinalValue(handle)
        handle:_Complete("finished", true)
    end)
    group:SetScript("OnStop", function()
        Driver.active[handle] = nil
    end)
    group:Play()
end

function Driver:Stop(handle)
    local group = handle and handle.group
    self.active[handle] = nil
    if group and group.Stop then
        group:Stop()
    end
end

function Driver:Finish(handle)
    local group = handle and handle.group
    self.active[handle] = nil
    if group and group.Finish then
        group:Finish()
    elseif group and group.Stop then
        group:Stop()
    end
    ApplyFinalValue(handle)
end

function Driver:Pause(handle)
    local group = handle and handle.group
    if group and group.Pause then
        group:Pause()
    end
end

function Driver:Resume(handle)
    local group = handle and handle.group
    if group and group.Play then
        group:Play()
    end
end

function Driver:GetActiveCount()
    local count = 0
    for _ in pairs(self.active or {}) do
        count = count + 1
    end
    return count
end
