local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local Formatter = {}
CDM.CooldownFormatter = Formatter

local instance = nil

local function CloneBreakpoint(bp, newThreshold)
    local copy = {
        threshold = newThreshold or bp.threshold,
        format = bp.format,
        rounding = bp.rounding,
        step = bp.step,
        min = bp.min,
        max = bp.max,
    }
    if bp.components then
        local c = {}
        for i = 1, #bp.components do
            local src = bp.components[i]
            c[i] = { div = src.div, mod = src.mod, step = src.step, rounding = src.rounding }
        end
        copy.components = c
    end
    return copy
end

local function BuildBreakpoints(cache)
    local NEAREST = Enum.NumericRuleFormatRounding.Nearest
    local UP = Enum.NumericRuleFormatRounding.Up

    local decThreshold = cache.cooldownDecimalThreshold
    local points = {}

    if decThreshold > 0 then
        points[#points + 1] = { threshold = 0, format = "%.1f", rounding = NEAREST }
        points[#points + 1] = { threshold = decThreshold, format = "%d", rounding = UP, step = 1 }
    else
        points[#points + 1] = { threshold = 0, format = "%d", rounding = UP, step = 1 }
    end

    -- Thresholds are offset above the integer boundary (59, 3599, 86399) so UP-rounded
    -- input in (N, N+1] routes into the larger-unit breakpoint, avoiding a "60" flash
    -- before mm:ss takes over at the minute boundary (same logic for hours and days).
    points[#points + 1] = {
        threshold = 59.0001, format = "%d:%02d", rounding = UP, step = 1,
        components = { { div = 60 }, { mod = 60 } },
    }
    points[#points + 1] = {
        threshold = 3599.0001, format = "%dh", rounding = UP, step = 1,
        components = { { div = 3600 } },
    }
    points[#points + 1] = {
        threshold = 86399.0001, format = "%dd", rounding = UP, step = 1,
        components = { { div = 86400 } },
    }

    local colorEnabled = cache.cooldownColorThresholdEnabled
    local colorThreshold = cache.cooldownColorThreshold
    local colorCfg = cache.cooldownColorThresholdColor

    if colorEnabled and colorThreshold > 0 and colorCfg then
        local color = CreateColor(colorCfg.r, colorCfg.g, colorCfg.b, colorCfg.a or 1)

        local activeIdx = 1
        for i = 1, #points do
            if points[i].threshold <= colorThreshold then
                activeIdx = i
            else
                break
            end
        end

        if points[activeIdx].threshold < colorThreshold then
            points[#points + 1] = CloneBreakpoint(points[activeIdx], colorThreshold)
        end

        for i = 1, #points do
            if points[i].threshold < colorThreshold then
                points[i].format = color:WrapTextInColorCode(points[i].format)
            end
        end
    end

    table.sort(points, function(a, b) return a.threshold < b.threshold end)
    return points
end

function Formatter.Rebuild(styleCache)
    if styleCache.cooldownDecimalThreshold <= 0 and not styleCache.cooldownColorThresholdEnabled then
        instance = nil
        return
    end

    local breakpoints = BuildBreakpoints(styleCache)

    if not instance then
        instance = C_StringUtil.CreateNumericRuleFormatter()
    end
    instance:SetBreakpoints(breakpoints)
end

function Formatter.Get()
    return instance
end
