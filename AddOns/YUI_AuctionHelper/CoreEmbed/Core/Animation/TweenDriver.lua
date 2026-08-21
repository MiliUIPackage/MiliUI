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

local Driver = Animation.TweenDriver or {}
Animation.TweenDriver = Driver

Driver.active = Driver.active or {}
Driver.activeMap = Driver.activeMap or {}

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local table_insert = table.insert
local table_remove = table.remove

local function Lerp(fromValue, toValue, progress)
    return (fromValue or 0) + ((toValue or 0) - (fromValue or 0)) * progress
end

local function ResolveTweenValues(spec)
    local fromValue = tonumber(spec.from)
    local toValue = tonumber(spec.to)
    local hasNumericValue = fromValue ~= nil or toValue ~= nil
    local hasUpdateCallback = type(spec.onUpdate) == "function"

    if not hasNumericValue and not hasUpdateCallback then
        return nil, nil, false
    end

    return fromValue or 0, toValue == nil and 1 or toValue, true
end

local function SafeCall(method, object, ...)
    if type(method) ~= "function" then
        return false
    end
    local ok = pcall(method, object, ...)
    return ok
end

local function SafeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok and YUI and YUI.Debug then
        YUI:Debug("Animation tween callback error:", err)
    end
end

local function EffectType(effect)
    return string.lower(tostring(effect and (effect.type or effect.kind) or ""))
end

local function CaptureAnchor(target, effect)
    if not target or type(target.GetPoint) ~= "function" or type(target.SetPoint) ~= "function" or type(target.ClearAllPoints) ~= "function" then
        return nil
    end
    if type(target.GetNumPoints) == "function" and target:GetNumPoints() > 1 and not effect.allowMultiPoint then
        return nil
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = target:GetPoint(1)
    if not point then
        return nil
    end

    return {
        point = point,
        relativeTo = relativeTo or (target.GetParent and target:GetParent()) or UIParent,
        relativePoint = relativePoint or point,
        x = xOfs or 0,
        y = yOfs or 0,
    }
end

local function ApplyAnchor(target, anchor, x, y)
    if not target or not anchor then
        return
    end

    target:ClearAllPoints()
    if anchor.relativeTo then
        target:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x + x, anchor.y + y)
    else
        target:SetPoint(anchor.point, anchor.x + x, anchor.y + y)
    end
end

local function PrepareEffect(target, effect)
    local effectType = EffectType(effect)
    if effectType == "alpha" then
        local fromAlpha = effect.from
        if fromAlpha == nil and target and target.GetAlpha then
            fromAlpha = target:GetAlpha()
        end
        return {
            type = "alpha",
            from = fromAlpha == nil and 1 or fromAlpha,
            to = effect.to == nil and 1 or effect.to,
        }
    elseif effectType == "translation" or effectType == "translate" or effectType == "move" then
        local anchor = CaptureAnchor(target, effect)
        if not anchor then
            return nil
        end
        return {
            type = "translation",
            anchor = anchor,
            fromX = effect.fromX or 0,
            fromY = effect.fromY or 0,
            toX = effect.toX or effect.x or 0,
            toY = effect.toY or effect.y or 0,
        }
    elseif effectType == "scale" then
        local fromScale = effect.from or effect.fromScale
        if fromScale == nil and target and target.GetScale then
            fromScale = target:GetScale()
        end
        return {
            type = "scale",
            from = fromScale or 1,
            to = effect.to or effect.scale or effect.toScale or 1,
        }
    elseif effectType == "rotation" or effectType == "rotate" then
        if not target or type(target.SetRotation) ~= "function" then
            return nil
        end
        local fromValue = effect.fromRadians or effect.from
        local toValue = effect.toRadians or effect.radians
        if fromValue == nil and effect.fromDegrees then
            fromValue = effect.fromDegrees * math_pi / 180
        end
        if toValue == nil and (effect.toDegrees or effect.degrees or effect.to) then
            toValue = (effect.toDegrees or effect.degrees or effect.to) * math_pi / 180
        end
        return {
            type = "rotation",
            from = fromValue or 0,
            to = toValue or 0,
        }
    elseif effectType == "size" then
        if not target or type(target.SetSize) ~= "function" then
            return nil
        end
        local fromWidth = effect.fromWidth or (target.GetWidth and target:GetWidth()) or 0
        local fromHeight = effect.fromHeight or (target.GetHeight and target:GetHeight()) or 0
        return {
            type = "size",
            fromWidth = fromWidth,
            fromHeight = fromHeight,
            toWidth = effect.toWidth or effect.width or fromWidth,
            toHeight = effect.toHeight or effect.height or fromHeight,
        }
    end

    return nil
end

local function ApplyPreparedEffect(target, prepared, progress)
    if not prepared then
        return
    end

    if prepared.type == "alpha" then
        SafeCall(target.SetAlpha, target, Lerp(prepared.from, prepared.to, progress))
    elseif prepared.type == "translation" then
        ApplyAnchor(target, prepared.anchor, Lerp(prepared.fromX, prepared.toX, progress), Lerp(prepared.fromY, prepared.toY, progress))
    elseif prepared.type == "scale" then
        SafeCall(target.SetScale, target, Lerp(prepared.from, prepared.to, progress))
    elseif prepared.type == "rotation" then
        SafeCall(target.SetRotation, target, Lerp(prepared.from, prepared.to, progress))
    elseif prepared.type == "size" then
        local width = math_max(1, math_floor(Lerp(prepared.fromWidth, prepared.toWidth, progress) + 0.5))
        local height = math_max(1, math_floor(Lerp(prepared.fromHeight, prepared.toHeight, progress) + 0.5))
        SafeCall(target.SetSize, target, width, height)
    end
end

local function ApplyHandle(handle, rawProgress)
    local spec = handle.spec or {}
    local eased = handle.easing(rawProgress)

    if handle.valueTween then
        local value = Lerp(handle.fromValue, handle.toValue, eased)
        SafeCallback(spec.onUpdate, value, eased, rawProgress, handle)
    end

    for _, prepared in ipairs(handle.preparedEffects or {}) do
        ApplyPreparedEffect(handle.target, prepared, eased)
    end

    SafeCallback(spec.onStep, eased, rawProgress, handle)
end

local function RemoveHandle(handle)
    if not Driver.activeMap[handle] then
        return
    end

    Driver.activeMap[handle] = nil
    for index = #Driver.active, 1, -1 do
        if Driver.active[index] == handle then
            table_remove(Driver.active, index)
            break
        end
    end

    if #Driver.active == 0 and Driver.frame then
        Driver.frame:SetScript("OnUpdate", nil)
    end
end

local function OnUpdate(_, elapsed)
    if #Driver.active == 0 then
        if Driver.frame then
            Driver.frame:SetScript("OnUpdate", nil)
        end
        return
    end

    local cpuWatchdog = YUI.CPUWatchdog
    local cpuStartedAt = cpuWatchdog and cpuWatchdog.timingActive and cpuWatchdog:BeginProbeTiming()
    for index = #Driver.active, 1, -1 do
        local handle = Driver.active[index]
        if not handle or handle._completed then
            table_remove(Driver.active, index)
        elseif handle.state == "playing" then
            handle.elapsed = (handle.elapsed or 0) + (elapsed or 0)
            local duration = handle.duration or 0
            local rawProgress = duration <= 0 and 1 or math_min(1, handle.elapsed / duration)
            ApplyHandle(handle, rawProgress)
            if rawProgress >= 1 then
                RemoveHandle(handle)
                handle:_Complete("finished", true)
            end
        end
    end
    if cpuStartedAt then cpuWatchdog:EndProbeTiming("core.animation", cpuStartedAt) end
end

local function EnsureTicker()
    if not Driver.frame then
        Driver.frame = CreateFrame("Frame")
    end
    Driver.frame:SetScript("OnUpdate", OnUpdate)
end

function Driver:Play(handle)
    local spec = handle and handle.spec or {}
    handle.duration = Animation:GetDefaultDuration(spec)
    handle.elapsed = 0
    handle.easing = Animation:GetEasing(Animation:GetDefaultEasing(spec))
    handle.preparedEffects = {}

    if type(spec.effects) == "table" then
        for _, effect in ipairs(spec.effects) do
            local prepared = PrepareEffect(handle.target, effect)
            if prepared then
                table_insert(handle.preparedEffects, prepared)
            end
        end
    end

    local fromValue, toValue, hasValueTween = ResolveTweenValues(spec)
    if hasValueTween then
        handle.valueTween = true
        handle.fromValue = fromValue
        handle.toValue = toValue
    end

    if not handle.valueTween and #handle.preparedEffects == 0 then
        handle:_Complete("unsupported", false)
        return
    end

    self.activeMap[handle] = true
    table_insert(self.active, handle)
    EnsureTicker()
    SafeCallback(spec.onStart, handle)
    ApplyHandle(handle, 0)
end

function Driver:Stop(handle, finish)
    if finish then
        self:Finish(handle)
        return
    end
    RemoveHandle(handle)
end

function Driver:Finish(handle)
    if not handle then
        return
    end
    ApplyHandle(handle, 1)
    RemoveHandle(handle)
end

function Driver:GetActiveCount()
    return #self.active
end
