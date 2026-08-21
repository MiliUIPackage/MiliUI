do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Security = YUI.API.Security or {}
YUI.API.Security = Security

local Legacy = YUI.WOW_API
local alphaProbeHost
local alphaProbes = {}
local checkProbeHost
local checkProbes = {}

local function DebugSafeFailure(label, err)
    if not YUI or type(YUI.Debug) ~= "function" then return end

    local message = "Security | SafeCall failed"
    if label ~= nil and label ~= "" then
        message = message .. " | " .. tostring(label)
    end
    if err ~= nil then
        message = message .. " | " .. tostring(err)
    end

    pcall(YUI.Debug, YUI, message)
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

local Unpack = unpack or table.unpack

function Security.InCombatLockdown()
    if InCombatLockdown then
        return InCombatLockdown()
    end

    return false
end

function Security.SecureCallFunction(func, ...)
    if not func then return nil end

    if type(securecallfunction) == "function" then
        return securecallfunction(func, ...)
    end

    return func(...)
end

function Security.SecureCallMethod(object, method, ...)
    if not object or not method then return nil end

    if type(securecallmethod) == "function" then
        return securecallmethod(object, method, ...)
    end

    local func = object[method]
    if func then
        return func(object, ...)
    end

    return nil
end

function Security.SafeCall(label, func, ...)
    if type(func) ~= "function" then
        local err = "target is not a function"
        DebugSafeFailure(label, err)
        return false, err
    end

    local results = Pack(pcall(func, ...))
    local ok = results[1]
    if not ok then
        DebugSafeFailure(label, results[2])
        return false, results[2]
    end

    return true, Unpack(results, 2, results.n)
end

function Security.SafeMethod(label, object, method, ...)
    if not object then
        local err = "object is nil"
        DebugSafeFailure(label, err)
        return false, err
    end
    if type(method) ~= "string" then
        local err = "method name is not a string"
        DebugSafeFailure(label, err)
        return false, err
    end

    local ok, func = pcall(function()
        return object[method]
    end)
    if not ok then
        DebugSafeFailure(label, func)
        return false, func
    end
    if type(func) ~= "function" then
        local err = "method is not a function: " .. method
        DebugSafeFailure(label, err)
        return false, err
    end

    return Security.SafeCall(label, func, object, ...)
end

function Security.SafeHook(label, object, method, callback)
    if type(hooksecurefunc) ~= "function" then
        local err = "hooksecurefunc is unavailable"
        DebugSafeFailure(label, err)
        return false, err
    end
    if not object then
        local err = "object is nil"
        DebugSafeFailure(label, err)
        return false, err
    end
    if type(method) ~= "string" then
        local err = "method name is not a string"
        DebugSafeFailure(label, err)
        return false, err
    end
    if type(callback) ~= "function" then
        local err = "callback is not a function"
        DebugSafeFailure(label, err)
        return false, err
    end

    local ok, func = pcall(function()
        return object[method]
    end)
    if not ok then
        DebugSafeFailure(label, func)
        return false, func
    end
    if type(func) ~= "function" then
        local err = "method is not a function: " .. method
        DebugSafeFailure(label, err)
        return false, err
    end

    local hookOk, err = pcall(hooksecurefunc, object, method, function(...)
        Security.SafeCall(label, callback, ...)
    end)
    if not hookOk then
        DebugSafeFailure(label, err)
        return false, err
    end

    return true
end

function Security.HideTooltip(tooltip)
    if not tooltip then
        return false, "tooltip is nil"
    end

    if type(securecallmethod) == "function" then
        local ok, result = pcall(securecallmethod, tooltip, "Hide")
        if ok then
            return true, result
        end
        DebugSafeFailure("HideTooltip", result)
    end

    return Security.SafeMethod("HideTooltip", tooltip, "Hide")
end

function Security.HideGameTooltip()
    local blizzardHide = _G.GameTooltip_Hide
    if type(blizzardHide) == "function" and securecallfunction then
        local ok, result = pcall(securecallfunction, blizzardHide)
        if ok then
            return true, result
        end
        DebugSafeFailure("HideGameTooltip", result)
    end

    return Security.HideTooltip(_G.GameTooltip)
end

function Security.IsSecretValue(value)
    if not issecretvalue then return false end

    local ok, result = pcall(issecretvalue, value)
    if ok then
        return result and true or false
    end

    return false
end

function Security.ClassifyValue(value)
    if value == nil then
        return "nil"
    end
    if Security.IsSecretValue(value) then
        return "secret"
    end
    return type(value)
end

function Security.DescribeValue(value)
    if value == nil then
        return "nil"
    end
    if Security.IsSecretValue(value) then
        return "secret:" .. type(value)
    end

    local valueType = type(value)
    if valueType == "string" then
        return "string(len=" .. tostring(#value) .. ")"
    end
    if valueType == "number" then
        return "number"
    end
    if valueType == "boolean" then
        return value and "true" or "false"
    end
    return valueType
end

function Security.SafeNumber(value)
    if value == nil or Security.IsSecretValue(value) then
        return nil
    end

    local ok, numberValue = pcall(tonumber, value)
    if ok and numberValue ~= nil and not Security.IsSecretValue(numberValue) then
        return numberValue
    end
    return nil
end

function Security.SafeString(value)
    if value == nil or Security.IsSecretValue(value) then
        return nil
    end
    if type(value) == "string" then
        return value
    end
    return nil
end

function Security.SafeBoolean(value)
    if value == nil or Security.IsSecretValue(value) then
        return nil
    end
    if type(value) == "boolean" then
        return value
    end
    return nil
end

local function ResolveColorObject(color)
    if type(color) == "table" then
        if color.GetRGBA then
            return color
        end
        local r = color.r or color[1] or 1
        local g = color.g or color[2] or 1
        local b = color.b or color[3] or 1
        local a = color.a or color[4]
        if CreateColor then
            return CreateColor(r, g, b, a == nil and 1 or a)
        end
        return {
            r = r,
            g = g,
            b = b,
            a = a == nil and 1 or a,
            GetRGBA = function(self)
                return self.r, self.g, self.b, self.a
            end,
        }
    end
    if CreateColor then
        return CreateColor(1, 1, 1, 1)
    end
    return {
        r = 1,
        g = 1,
        b = 1,
        a = 1,
        GetRGBA = function(self)
            return self.r, self.g, self.b, self.a
        end,
    }
end

local function ApplyColorObject(target, color)
    if not (target and color) then return false end
    if color.GetRGBA and target.SetVertexColor then
        target:SetVertexColor(color:GetRGBA())
        return true
    end
    if target.SetVertexColor and type(color) == "table" then
        target:SetVertexColor(color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1, color.a or color[4] or 1)
        return true
    end
    return false
end

function Security.EvaluateColorFromBoolean(value, trueColor, falseColor)
    local trueObject = ResolveColorObject(trueColor)
    local falseObject = ResolveColorObject(falseColor)

    if C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean then
        local ok, color = pcall(C_CurveUtil.EvaluateColorFromBoolean, value, trueObject, falseObject)
        if ok and color then
            return color
        end
    end
    if C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local ok, color = pcall(C_CurveUtil.EvaluateColorValueFromBoolean, value, trueObject, falseObject)
        if ok and color then
            return color
        end
    end

    local bool = Security.SafeBoolean(value)
    if bool == nil then
        return nil
    end
    return bool and trueObject or falseObject
end

function Security.ApplyVertexColorFromBoolean(texture, value, trueColor, falseColor)
    if not texture then return false end

    local trueObject = ResolveColorObject(trueColor)
    local falseObject = ResolveColorObject(falseColor)

    if texture.SetVertexColorFromBoolean then
        local ok = pcall(texture.SetVertexColorFromBoolean, texture, value, trueObject, falseObject)
        if ok then
            return true
        end
    end

    local color = Security.EvaluateColorFromBoolean(value, trueObject, falseObject)
    if color then
        return ApplyColorObject(texture, color)
    end
    return false
end

function Security.ApplyAlphaFromBoolean(target, value, trueAlpha, falseAlpha)
    if not target then return false end
    trueAlpha = trueAlpha == nil and 1 or trueAlpha
    falseAlpha = falseAlpha == nil and 0 or falseAlpha

    if target.SetAlphaFromBoolean then
        local ok = pcall(target.SetAlphaFromBoolean, target, value, trueAlpha, falseAlpha)
        if ok then
            return true
        end
    end

    local bool = Security.SafeBoolean(value)
    if bool == nil or not target.SetAlpha then
        return false
    end
    target:SetAlpha(bool and trueAlpha or falseAlpha)
    return true
end

local function EnsureAlphaProbe(key)
    if not (UIParent and CreateFrame) then
        return nil, "no-ui"
    end

    if not alphaProbeHost then
        alphaProbeHost = CreateFrame("Frame", nil, UIParent)
        alphaProbeHost:SetSize(1, 1)
        alphaProbeHost:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -16, -16)
        alphaProbeHost:EnableMouse(false)
        alphaProbeHost:Show()
    end

    key = tostring(key or "default")
    local probe = alphaProbes[key]
    if probe then
        alphaProbeHost:Show()
        probe:Show()
        return probe
    end

    probe = CreateFrame("Frame", nil, alphaProbeHost)
    probe:SetSize(1, 1)
    probe:SetPoint("TOPLEFT", alphaProbeHost, "TOPLEFT", 0, 0)
    probe:EnableMouse(false)
    probe:Show()
    alphaProbes[key] = probe
    return probe
end

function Security.ReadBooleanViaAlphaProbe(value, key)
    local safeValue = Security.SafeBoolean(value)
    if safeValue ~= nil then
        return {
            known = true,
            value = safeValue,
            source = "safe",
            reason = safeValue and "true" or "false",
        }
    end

    if value == nil then
        return {
            known = false,
            value = nil,
            source = "alpha-probe",
            reason = "nil",
        }
    end

    if not Security.IsSecretValue(value) then
        return {
            known = false,
            value = nil,
            source = "alpha-probe",
            reason = "not-boolean",
        }
    end

    local probe, probeReason = EnsureAlphaProbe(key)
    if not (probe and probe.SetAlpha and probe.SetAlphaFromBoolean and probe.GetAlpha) then
        return {
            known = false,
            value = nil,
            source = "alpha-probe",
            reason = probeReason or "no-probe-api",
        }
    end

    local sentinel = 0.5
    local resetOK = pcall(probe.SetAlpha, probe, sentinel)
    if not resetOK then
        return {
            known = false,
            value = nil,
            source = "alpha-probe",
            reason = "reset-failed",
        }
    end

    local setOK = pcall(probe.SetAlphaFromBoolean, probe, value, 1, 0)
    if not setOK then
        return {
            known = false,
            value = nil,
            source = "alpha-probe",
            reason = "set-failed",
        }
    end

    local readOK, alpha = pcall(probe.GetAlpha, probe)
    alpha = Security.SafeNumber(alpha)
    if not readOK or alpha == nil then
        return {
            known = false,
            value = nil,
            source = "alpha-probe",
            reason = "read-failed",
        }
    end

    if alpha >= 0.95 then
        return {
            known = true,
            value = true,
            source = "alpha-probe",
            reason = "true",
            alpha = alpha,
        }
    end
    if alpha <= 0.05 then
        return {
            known = true,
            value = false,
            source = "alpha-probe",
            reason = "false",
            alpha = alpha,
        }
    end

    return {
        known = false,
        value = nil,
        source = "alpha-probe",
        reason = "sentinel",
        alpha = alpha,
    }
end

local function EnsureCheckProbe(key)
    if not (UIParent and CreateFrame) then
        return nil, "no-ui"
    end

    if not checkProbeHost then
        checkProbeHost = CreateFrame("Frame", nil, UIParent)
        checkProbeHost:SetSize(1, 1)
        checkProbeHost:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20, -20)
        checkProbeHost:EnableMouse(false)
        checkProbeHost:Show()
    end

    key = tostring(key or "default")
    local probe = checkProbes[key]
    if probe then
        checkProbeHost:Show()
        probe:Show()
        return probe
    end

    probe = CreateFrame("CheckButton", nil, checkProbeHost)
    probe:SetSize(1, 1)
    probe:SetPoint("TOPLEFT", checkProbeHost, "TOPLEFT", 0, 0)
    probe:EnableMouse(false)
    probe:Show()
    checkProbes[key] = probe
    return probe
end

function Security.ReadBooleanViaCheckProbe(value, key)
    local safeValue = Security.SafeBoolean(value)
    if safeValue ~= nil then
        return {
            known = true,
            value = safeValue,
            source = "safe",
            reason = safeValue and "true" or "false",
        }
    end

    if value == nil then
        return {
            known = false,
            value = nil,
            source = "check-probe",
            reason = "nil",
        }
    end

    if not Security.IsSecretValue(value) then
        return {
            known = false,
            value = nil,
            source = "check-probe",
            reason = "not-boolean",
        }
    end

    local probe, probeReason = EnsureCheckProbe(key)
    if not (probe and probe.SetChecked and probe.GetChecked) then
        return {
            known = false,
            value = nil,
            source = "check-probe",
            reason = probeReason or "no-probe-api",
        }
    end

    local resetOK = pcall(probe.SetChecked, probe, false)
    if not resetOK then
        return {
            known = false,
            value = nil,
            source = "check-probe",
            reason = "reset-failed",
        }
    end

    local setOK = pcall(probe.SetChecked, probe, value)
    if not setOK then
        return {
            known = false,
            value = nil,
            source = "check-probe",
            reason = "set-failed",
        }
    end

    local readOK, checked = pcall(probe.GetChecked, probe)
    if not readOK then
        return {
            known = false,
            value = nil,
            source = "check-probe",
            reason = "read-failed",
        }
    end

    local checkedValue = Security.SafeBoolean(checked)
    if checkedValue ~= nil then
        return {
            known = true,
            value = checkedValue,
            source = "check-probe",
            reason = checkedValue and "true" or "false",
        }
    end

    return {
        known = false,
        value = nil,
        source = "check-probe",
        reason = Security.IsSecretValue(checked) and "read-secret" or "read-failed",
    }
end

function Security.CanAccessSecrets()
    if not canaccesssecrets then return nil end

    local ok, result = pcall(canaccesssecrets)
    if ok then
        return result and true or false
    end

    return nil
end

function Security.CanAccessTable(tbl)
    if not canaccesstable then return nil end

    local ok, result = pcall(canaccesstable, tbl)
    if ok then
        return result and true or false
    end

    return nil
end

Legacy.InCombatLockdown = Security.InCombatLockdown
Legacy.SecureCallFunction = Security.SecureCallFunction
Legacy.SecureCallMethod = Security.SecureCallMethod
Legacy.SafeCall = Security.SafeCall
Legacy.SafeMethod = Security.SafeMethod
Legacy.SafeHook = Security.SafeHook
Legacy.HideTooltip = Security.HideTooltip
Legacy.HideGameTooltip = Security.HideGameTooltip
Legacy.IsSecretValue = Security.IsSecretValue
Legacy.ClassifySecretValue = Security.ClassifyValue
Legacy.DescribeSecretValue = Security.DescribeValue
Legacy.SafeNumberValue = Security.SafeNumber
Legacy.SafeStringValue = Security.SafeString
Legacy.SafeBooleanValue = Security.SafeBoolean
Legacy.ApplyAlphaFromBoolean = Security.ApplyAlphaFromBoolean
Legacy.ApplyVertexColorFromBoolean = Security.ApplyVertexColorFromBoolean
Legacy.EvaluateColorFromBoolean = Security.EvaluateColorFromBoolean
Legacy.ReadBooleanViaAlphaProbe = Security.ReadBooleanViaAlphaProbe
Legacy.ReadBooleanViaCheckProbe = Security.ReadBooleanViaCheckProbe
Legacy.CanAccessSecrets = Security.CanAccessSecrets
Legacy.CanAccessTable = Security.CanAccessTable

YUI.HideTooltip = Security.HideTooltip
YUI.HideGameTooltip = Security.HideGameTooltip
