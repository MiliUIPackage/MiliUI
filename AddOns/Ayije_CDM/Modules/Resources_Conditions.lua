local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local res = CDM._Res
local CDM_C = CDM.CONST

local UnitPowerMax = UnitPowerMax
local UnitPowerPercent = UnitPowerPercent
local IsSafeNumber = CDM.IsSafeNumber
local GetFrameData = CDM.GetFrameData

local POWER_TYPES = res.POWER_TYPES

local type = type

local THRESHOLD_EPS = 0.0001

local function CreateCurveSet()
    local function sc()
        local c = C_CurveUtil.CreateCurve()
        c:SetType(Enum.LuaCurveType.Step)
        return c
    end
    return {
        r = sc(), g = sc(), b = sc(), a = sc(), aColor = sc(),
        bgR = sc(), bgG = sc(), bgB = sc(), bgA = sc(),
        tagR = sc(), tagG = sc(), tagB = sc(), tagA = sc(),
    }
end

local COMPARE_OPS = {
    [">="] = function(a, b) return a >= b end,
    [">"]  = function(a, b) return a > b end,
    ["<="] = function(a, b) return a <= b end,
    ["<"]  = function(a, b) return a < b end,
    ["=="] = function(a, b) return a == b end,
    ["~="] = function(a, b) return a ~= b end,
}

local function EvalCheckAtFrac(check, fracVal, powerMax, currentSpec)
    if not check then return false end

    if check.op then
        local children = check.children
        if not children or #children == 0 then return true end
        for i = 1, #children do
            if not EvalCheckAtFrac(children[i], fracVal, powerMax, currentSpec) then return false end
        end
        return true
    end

    local var = check.var
    if var == "always" then return true end
    if var == "spec" then
        local fn = COMPARE_OPS[check.cmp]
        return fn and fn(currentSpec, check.value) or false
    end
    if var == "powerFull" then
        if check.value == true then return fracVal >= 1.0 end
        return fracVal < 1.0
    end
    if var == "powerValue" then
        if type(check.value) ~= "number" then return false end
        if not powerMax or powerMax <= 0 then return false end
        local fn = COMPARE_OPS[check.cmp]
        return fn and fn(fracVal, check.value / powerMax) or false
    end
    if var == "powerPercent" then
        if type(check.value) ~= "number" then return false end
        local fn = COMPARE_OPS[check.cmp]
        return fn and fn(fracVal, check.value / 100) or false
    end
    return false
end

local function CheckUsesPowerValue(check)
    if not check then return false end
    if check.op then
        local children = check.children
        if children then
            for i = 1, #children do
                if CheckUsesPowerValue(children[i]) then return true end
            end
        end
        return false
    end
    return check.var == "powerValue"
end

local function CollectValidRules(conditions, rulesOut)
    local n = 0
    for i = 1, #conditions do
        local rule = conditions[i]
        if not rule.target and rule.overrides and rule.check then
            n = n + 1
            rulesOut[n] = rule
        end
    end
    return n
end

local function CollectThresholds(check, powerMax, out)
    if not check then return end
    if check.op then
        local children = check.children
        if children then
            for i = 1, #children do
                CollectThresholds(children[i], powerMax, out)
            end
        end
        return
    end
    local var = check.var
    if var == "powerPercent" then
        if type(check.value) == "number" then
            local frac = check.value / 100
            if frac > 0 and frac <= 1 then out[frac] = true end
        end
    elseif var == "powerValue" then
        if type(check.value) == "number" and powerMax and powerMax > 0 then
            local frac = check.value / powerMax
            if frac > 0 and frac <= 1 then out[frac] = true end
        end
    elseif var == "powerFull" then
        out[1] = true
    end
end

local function BuildEvalPoints(nValid, validRules, powerMax)
    local thresholds = {}
    for ri = 1, nValid do
        CollectThresholds(validRules[ri].check, powerMax, thresholds)
    end
    local points = { 0 }
    local seen = { [0] = true }
    for t in pairs(thresholds) do
        if not seen[t] then points[#points + 1] = t; seen[t] = true end
        local below = t - THRESHOLD_EPS
        if below > 0 and not seen[below] then points[#points + 1] = below; seen[below] = true end
        local above = t + THRESHOLD_EPS
        if above <= 1 and not seen[above] then points[#points + 1] = above; seen[above] = true end
    end
    table.sort(points)
    return points
end

local function BuildChannelCurve(curve, evalPoints, nValid, baseVal, getOverrideVal, validRules, powerMax, currentSpec)
    local anyOverride = false
    for ri = 1, nValid do
        if getOverrideVal(validRules[ri].overrides) then anyOverride = true; break end
    end
    if not anyOverride then return false end

    curve:ClearPoints()
    local prevVal = nil
    local hasOverride = false
    for i = 1, #evalPoints do
        local frac = evalPoints[i]
        local val = baseVal
        for ri = 1, nValid do
            if EvalCheckAtFrac(validRules[ri].check, frac, powerMax, currentSpec) then
                local ov = getOverrideVal(validRules[ri].overrides)
                if ov then val = ov; hasOverride = true; break end
            end
        end
        if val ~= prevVal then
            curve:AddPoint(frac, val)
            prevVal = val
        end
    end
    return hasOverride
end

local GetPowerColor = res.GetPowerColor

local function GetOverrideColorR(ov) return ov.color and ov.color.r end
local function GetOverrideColorG(ov) return ov.color and ov.color.g end
local function GetOverrideColorB(ov) return ov.color and ov.color.b end
local function GetOverrideBgR(ov) return ov.bgColor and ov.bgColor.r end
local function GetOverrideBgG(ov) return ov.bgColor and ov.bgColor.g end
local function GetOverrideBgB(ov) return ov.bgColor and ov.bgColor.b end
local function GetOverrideAlpha(ov) return ov.alpha end
local function GetOverrideColorA(ov) return ov.color and (ov.color.a or 1) end
local function GetOverrideBgA(ov) return ov.bgColor and (ov.bgColor.a or 1) end
local function GetOverrideTagR(ov) return ov.tagColor and ov.tagColor.r end
local function GetOverrideTagG(ov) return ov.tagColor and ov.tagColor.g end
local function GetOverrideTagB(ov) return ov.tagColor and ov.tagColor.b end
local function GetOverrideTagA(ov) return ov.tagColor and (ov.tagColor.a or 1) end

local function GetConditions(barKey)
    local conditions = CDM:GetBarSetting(barKey, "conditions")
    if not conditions or #conditions == 0 then return nil end
    return conditions
end

local function StoreAppliedColor(slot, r, g, b, a)
    if not slot then slot = {} end
    slot.r, slot.g, slot.b, slot.a = r, g, b, a
    return slot
end

local function ApplyTagColorOverride(bar, powerType, overrideColor, condState)
    local textFrame = CDM.TAGS and CDM.TAGS.textFrames and CDM.TAGS.textFrames[powerType]
    if not textFrame or not textFrame.text then return end

    if overrideColor then
        textFrame.text:SetTextColor(
            overrideColor.r, overrideColor.g, overrideColor.b, overrideColor.a or 1)
        condState.tagColor = StoreAppliedColor(condState.tagColor,
            overrideColor.r, overrideColor.g, overrideColor.b, overrideColor.a or 1)
    elseif condState.tagColor then
        local base = CDM:GetBarSetting(bar.barKey, "tagColor")
            or CDM_C.WHITE
        textFrame.text:SetTextColor(base.r, base.g, base.b, base.a or 1)
        condState.tagColor = nil
    end
end

local function ClearCondState(bar, powerType, condState, base, baseBg)
    if condState.color then
        bar:SetStatusBarColor(base.r or 1, base.g or 1, base.b or 1, base.a or 1)
        condState.color = nil
    end
    if condState.bg and bar.bg then
        bar.bg:SetVertexColor(baseBg.r or 0.2, baseBg.g or 0.2, baseBg.b or 0.2, baseBg.a or 0.5)
        condState.bg = nil
    end
    if condState.alpha then
        bar:SetAlpha(1)
        condState.alpha = nil
    end
    if condState.tagColor then
        ApplyTagColorOverride(bar, powerType, nil, condState)
    end
end

local function ApplyBarConditions(bar, powerType, current, max)
    local frameData = GetFrameData(bar)
    local versionNow = CDM._conditionsVersion or 0

    local cache = frameData.condCache
    if cache and cache.version == versionNow and cache.noConditions then return end

    local conditions = GetConditions(bar.barKey)
    local condState = frameData.condState

    if not conditions then
        if not cache then cache = { rules = {} }; frameData.condCache = cache end
        cache.version = versionNow
        cache.noConditions = true
        cache.curvesValid = false
        if cache.curves then
            for _, c in pairs(cache.curves) do
                if c.SetToDefaults then c:SetToDefaults() end
            end
            cache.curves = nil
        end
        if condState then
            local base = GetPowerColor(powerType) or bar.color or CDM_C.WHITE
            local baseBg = CDM:GetBarSetting(bar.barKey, "bgColor") or res.DEFAULT_BG_COLOR
            ClearCondState(bar, powerType, condState, base, baseBg)
        end
        return
    end

    local powerMax = max or UnitPowerMax("player", powerType)
    local currentSpec = res.GetCurrentSpecID() or 0

    if not cache then
        cache = { rules = {} }
        frameData.condCache = cache
    end

    local nValid
    local curvesValid = false

    if cache.version == versionNow
        and cache.conditions == conditions
        and (not cache.hasPowerValue or cache.powerMax == powerMax)
        and cache.spec == currentSpec
    then
        nValid = cache.nValid
        curvesValid = cache.curvesValid
    else
        nValid = CollectValidRules(conditions, cache.rules)
        local hasPV = false
        for i = 1, nValid do
            if CheckUsesPowerValue(cache.rules[i].check) then hasPV = true; break end
        end
        cache.version = versionNow
        cache.conditions = conditions
        cache.powerMax = powerMax
        cache.spec = currentSpec
        cache.nValid = nValid
        cache.hasPowerValue = hasPV
        cache.noConditions = false
        cache.curvesValid = false
    end

    if not condState then
        condState = {}
        frameData.condState = condState
    end

    if nValid == 0 then
        local base = GetPowerColor(powerType) or bar.color or CDM_C.WHITE
        local baseBg = CDM:GetBarSetting(bar.barKey, "bgColor") or res.DEFAULT_BG_COLOR
        ClearCondState(bar, powerType, condState, base, baseBg)
        cache.curvesValid = true
        return
    end

    local validRules = cache.rules

    if not curvesValid then
        if not cache.curves then cache.curves = CreateCurveSet() end
        local c = cache.curves
        local evalPoints = BuildEvalPoints(nValid, validRules, powerMax)

        local base = GetPowerColor(powerType) or bar.color or CDM_C.WHITE
        local baseBg = CDM:GetBarSetting(bar.barKey, "bgColor") or res.DEFAULT_BG_COLOR
        local tagSetting = CDM:GetBarSetting(bar.barKey, "tagColor")
            or CDM_C.WHITE

        cache.hasColor = BuildChannelCurve(c.r, evalPoints, nValid, base.r or 1, GetOverrideColorR, validRules, powerMax, currentSpec)
        if cache.hasColor then
            BuildChannelCurve(c.g, evalPoints, nValid, base.g or 1, GetOverrideColorG, validRules, powerMax, currentSpec)
            BuildChannelCurve(c.b, evalPoints, nValid, base.b or 1, GetOverrideColorB, validRules, powerMax, currentSpec)
            cache.hasColorA = BuildChannelCurve(c.aColor, evalPoints, nValid, base.a or 1, GetOverrideColorA, validRules, powerMax, currentSpec)
        end
        cache.baseA = base.a or 1

        if bar.bg then
            cache.hasBg = BuildChannelCurve(c.bgR, evalPoints, nValid, baseBg.r or 0.2, GetOverrideBgR, validRules, powerMax, currentSpec)
            if cache.hasBg then
                BuildChannelCurve(c.bgG, evalPoints, nValid, baseBg.g or 0.2, GetOverrideBgG, validRules, powerMax, currentSpec)
                BuildChannelCurve(c.bgB, evalPoints, nValid, baseBg.b or 0.2, GetOverrideBgB, validRules, powerMax, currentSpec)
                cache.hasBgA = BuildChannelCurve(c.bgA, evalPoints, nValid, baseBg.a or 0.5, GetOverrideBgA, validRules, powerMax, currentSpec)
            end
        else
            cache.hasBg = false
        end
        cache.baseBgA = baseBg.a or 0.5

        cache.hasAlpha = BuildChannelCurve(c.a, evalPoints, nValid, 1, GetOverrideAlpha, validRules, powerMax, currentSpec)

        cache.hasTag = BuildChannelCurve(c.tagR, evalPoints, nValid, tagSetting.r or 1, GetOverrideTagR, validRules, powerMax, currentSpec)
        if cache.hasTag then
            BuildChannelCurve(c.tagG, evalPoints, nValid, tagSetting.g or 1, GetOverrideTagG, validRules, powerMax, currentSpec)
            BuildChannelCurve(c.tagB, evalPoints, nValid, tagSetting.b or 1, GetOverrideTagB, validRules, powerMax, currentSpec)
            cache.hasTagA = BuildChannelCurve(c.tagA, evalPoints, nValid, tagSetting.a or 1, GetOverrideTagA, validRules, powerMax, currentSpec)
        end
        cache.baseTagA = tagSetting.a or 1

        cache.base = base
        cache.baseBg = baseBg

        cache.curvesValid = true
    end

    local c = cache.curves

    if cache.hasColor then
        local sr = UnitPowerPercent("player", powerType, false, c.r)
        local sg = UnitPowerPercent("player", powerType, false, c.g)
        local sb = UnitPowerPercent("player", powerType, false, c.b)
        local sa = cache.hasColorA and UnitPowerPercent("player", powerType, false, c.aColor) or cache.baseA
        bar:SetStatusBarColor(sr, sg, sb, sa)
        condState.color = true
    elseif condState.color then
        local base = cache.base or GetPowerColor(powerType) or CDM_C.WHITE
        bar:SetStatusBarColor(base.r or 1, base.g or 1, base.b or 1, base.a or 1)
        condState.color = nil
    end

    if bar.bg then
        if cache.hasBg then
            local sr = UnitPowerPercent("player", powerType, false, c.bgR)
            local sg = UnitPowerPercent("player", powerType, false, c.bgG)
            local sb = UnitPowerPercent("player", powerType, false, c.bgB)
            local sa = cache.hasBgA and UnitPowerPercent("player", powerType, false, c.bgA) or cache.baseBgA
            bar.bg:SetVertexColor(sr, sg, sb, sa)
            condState.bg = true
        elseif condState.bg then
            local baseBg = cache.baseBg or res.DEFAULT_BG_COLOR
            bar.bg:SetVertexColor(baseBg.r or 0.2, baseBg.g or 0.2, baseBg.b or 0.2, baseBg.a or 0.5)
            condState.bg = nil
        end
    end

    if cache.hasAlpha then
        bar:SetAlpha(UnitPowerPercent("player", powerType, false, c.a))
        condState.alpha = true
    elseif condState.alpha then
        bar:SetAlpha(1)
        condState.alpha = nil
    end

    if cache.hasTag then
        local sr = UnitPowerPercent("player", powerType, false, c.tagR)
        local sg = UnitPowerPercent("player", powerType, false, c.tagG)
        local sb = UnitPowerPercent("player", powerType, false, c.tagB)
        local sa = cache.hasTagA and UnitPowerPercent("player", powerType, false, c.tagA) or cache.baseTagA
        local textFrame = CDM.TAGS and CDM.TAGS.textFrames and CDM.TAGS.textFrames[powerType]
        if textFrame and textFrame.text then
            textFrame.text:SetTextColor(sr, sg, sb, sa)
        end
        condState.tagColor = true
    elseif condState.tagColor then
        ApplyTagColorOverride(bar, powerType, nil, condState)
    end
end

local function GetPipRecharging(bar, powerType, pipIndex)
    if powerType == POWER_TYPES.Runes then
        return res.IsRuneRecharging and res.IsRuneRecharging(pipIndex) or false
    elseif powerType == POWER_TYPES.Essence then
        return res.IsEssenceRecharging and res.IsEssenceRecharging(pipIndex) or false
    end
    return false
end

local scratchState = {}

local function BuildBarState(powerType, current, max)
    local safe = IsSafeNumber(current)
    scratchState.powerValue = safe and current or nil
    scratchState.powerFull = safe and max and max > 0 and current >= max or false
    scratchState.powerPercent = safe and max and max > 0 and (current / max * 100) or 0
    scratchState.spec = res.GetCurrentSpecID() or 0
    scratchState.pipRecharging = false
    return scratchState
end

local function EvalLeaf(node, state)
    local var = node.var
    if var == "always" then return true end
    if var == "powerValue" then
        if not state.powerValue then return false end
        local fn = COMPARE_OPS[node.cmp]
        return fn and fn(state.powerValue, node.value) or false
    elseif var == "powerPercent" then
        if not state.powerValue then return false end
        local fn = COMPARE_OPS[node.cmp]
        return fn and fn(state.powerPercent, node.value) or false
    elseif var == "powerFull" then
        if not state.powerValue then return false end
        return state.powerFull == node.value
    elseif var == "spec" then
        local fn = COMPARE_OPS[node.cmp]
        return fn and fn(state.spec, node.value) or false
    elseif var == "pipRecharging" then
        return state.pipRecharging == node.value
    end
    return false
end

local function EvalCheck(node, state)
    if node.op then
        local children = node.children
        if not children or #children == 0 then return true end
        for i = 1, #children do
            if not EvalCheck(children[i], state) then return false end
        end
        return true
    end
    return EvalLeaf(node, state)
end

local SetStatusBarColorIfChanged = res.SetStatusBarColorIfChanged
local SetVertexColorIfChanged = res.SetVertexColorIfChanged

local function ApplyPipConditions(bar, powerType, current, max)
    local frameData = GetFrameData(bar)
    local versionNow = CDM._conditionsVersion or 0

    local cache = frameData.condCache
    if cache and cache.version == versionNow and cache.noConditions then return end

    local conditions = GetConditions(bar.barKey)
    if not conditions then
        if not cache then cache = {}; frameData.condCache = cache end
        cache.version = versionNow
        cache.noConditions = true
        local condState = frameData.condState
        if condState then
            if condState.pipColorApplied and bar.pips then
                local baseColors = bar._pipBaseColors
                for i = 1, #bar.pips do
                    if condState.pipColorApplied[i] then
                        local baseColor = (baseColors and baseColors[i]) or bar.color
                        SetStatusBarColorIfChanged(bar.pips[i], baseColor)
                        condState.pipColorApplied[i] = nil
                    end
                end
                condState.pipColorApplied = nil
            end
            if condState.pipBgApplied and bar.bgTexture then
                local baseBg = CDM:GetBarSetting(bar.barKey, "bgColor") or res.DEFAULT_BG_COLOR
                SetVertexColorIfChanged(bar.bgTexture, baseBg)
                condState.pipBgApplied = nil
            end
            if condState.pipAlpha then
                bar:SetAlpha(1)
                condState.pipAlpha = nil
            end
            ApplyTagColorOverride(bar, powerType, nil, condState)
        end
        return
    end

    local condState = frameData.condState
    if not condState then
        condState = {}
        frameData.condState = condState
    end

    local state = BuildBarState(powerType, current, max)

    local pips = bar.pips
    if pips then
        local pipColorApplied = condState.pipColorApplied
        local baseColors = bar._pipBaseColors
        for i = 1, #pips do
            local pip = pips[i]
            state.pipRecharging = GetPipRecharging(bar, powerType, i)
            local matched
            for j = 1, #conditions do
                local rule = conditions[j]
                if not rule.target or rule.target == i then
                    if rule.overrides and rule.check and EvalCheck(rule.check, state) then
                        matched = rule.overrides
                        break
                    end
                end
            end
            if matched and matched.color then
                SetStatusBarColorIfChanged(pip, matched.color)
                if not pipColorApplied then
                    pipColorApplied = {}
                    condState.pipColorApplied = pipColorApplied
                end
                pipColorApplied[i] = true
            elseif pipColorApplied and pipColorApplied[i] then
                local baseColor = (baseColors and baseColors[i]) or bar.color
                SetStatusBarColorIfChanged(pip, baseColor)
                pipColorApplied[i] = nil
            end
        end
        if pipColorApplied and not next(pipColorApplied) then
            condState.pipColorApplied = nil
        end
    end

    state.pipRecharging = false

    local barMatched
    for i = 1, #conditions do
        local rule = conditions[i]
        if not rule.target and rule.overrides and rule.check and EvalCheck(rule.check, state) then
            barMatched = rule.overrides
            break
        end
    end

    if barMatched then
        if barMatched.bgColor and bar.bgTexture then
            SetVertexColorIfChanged(bar.bgTexture, barMatched.bgColor)
            condState.pipBgApplied = true
        elseif condState.pipBgApplied and bar.bgTexture then
            local baseBg = CDM:GetBarSetting(bar.barKey, "bgColor") or res.DEFAULT_BG_COLOR
            SetVertexColorIfChanged(bar.bgTexture, baseBg)
            condState.pipBgApplied = nil
        end
        local newAlpha = barMatched.alpha or 1
        if condState.pipAlpha ~= newAlpha then
            bar:SetAlpha(newAlpha)
            condState.pipAlpha = newAlpha
        end
        ApplyTagColorOverride(bar, powerType, barMatched.tagColor, condState)
    else
        if condState.pipBgApplied and bar.bgTexture then
            local baseBg = CDM:GetBarSetting(bar.barKey, "bgColor") or res.DEFAULT_BG_COLOR
            SetVertexColorIfChanged(bar.bgTexture, baseBg)
            condState.pipBgApplied = nil
        end
        if condState.pipAlpha then
            bar:SetAlpha(1)
            condState.pipAlpha = nil
        end
        ApplyTagColorOverride(bar, powerType, nil, condState)
    end
end

res.ApplyBarConditions = ApplyBarConditions
res.ApplyPipConditions = ApplyPipConditions
