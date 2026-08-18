local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...
local Animation = YUI.Animation
if not Animation then return end

local math_cos = math.cos
local math_pi = math.pi
local math_pow = math.pow
local math_sin = math.sin

local Easing = Animation.Easing or {}
Animation.Easing = Easing

local function Clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

Easing.linear = function(t)
    return Clamp01(t)
end

Easing["in"] = function(t)
    t = Clamp01(t)
    return t * t
end

Easing.out = function(t)
    t = Clamp01(t)
    return 1 - ((1 - t) * (1 - t))
end

Easing.inOut = function(t)
    t = Clamp01(t)
    if t < 0.5 then
        return 2 * t * t
    end
    return 1 - math_pow(-2 * t + 2, 2) / 2
end

Easing.sineOut = function(t)
    return math_sin((Clamp01(t) * math_pi) / 2)
end

Easing.sineInOut = function(t)
    return -(math_cos(math_pi * Clamp01(t)) - 1) / 2
end

Easing.outBack = function(t)
    t = Clamp01(t)
    local c1 = 1.70158
    local c3 = c1 + 1
    return 1 + c3 * math_pow(t - 1, 3) + c1 * math_pow(t - 1, 2)
end

local ALIASES = {
    none = "linear",
    ["in-out"] = "inOut",
    inout = "inOut",
    ease = "out",
    easein = "in",
    easeout = "out",
    easeinout = "inOut",
    ["sine-out"] = "sineOut",
    sineout = "sineOut",
    ["sine-in-out"] = "sineInOut",
    sineinout = "sineInOut",
    pop = "outBack",
    back = "outBack",
}

function Animation:GetEasing(name)
    if type(name) == "function" then
        return name
    end
    name = tostring(name or self.defaults.easing or "out")
    local key = ALIASES[name] or ALIASES[string.lower(name)] or name
    return Easing[key] or Easing.out
end

function Animation:GetNativeSmoothing(name)
    name = tostring(name or self.defaults.easing or "out"):lower()
    if name == "linear" or name == "none" then
        return "NONE"
    elseif name == "in" or name == "easein" then
        return "IN"
    elseif name == "inout" or name == "in-out" or name == "easeinout" then
        return "IN_OUT"
    end
    return "OUT"
end
