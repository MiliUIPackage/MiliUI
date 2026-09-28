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

-- MiliUI: 光環格（AuraButton 的 SetDurationText）專用。
-- 圖示上的 Cooldown 在 Get() 回 nil 時退回暴雪的倒數格式，那一套是純數字；
-- 但 AuraButton 沒給 formatter 會走暴雪的 SecondsFormatter，中文會印出「秒」。
-- 所以這裡保證一定有一顆：有自訂門檻就用同一顆，沒有就用同一套斷點（無小數、無變色）
-- 另建一顆。只在正常插件路徑（容器建立前）呼叫，不能在 initializeFrame 裡建。
local plainInstance = nil

function Formatter.GetForAuraText()
    if instance then return instance end
    if plainInstance then return plainInstance end
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
    local ok, f = pcall(function()
        local fmt = C_StringUtil.CreateNumericRuleFormatter()
        fmt:SetBreakpoints(BuildBreakpoints({
            cooldownDecimalThreshold = 0,
            cooldownColorThresholdEnabled = false,
        }))
        return fmt
    end)
    if ok and f then plainInstance = f end
    return plainInstance
end
