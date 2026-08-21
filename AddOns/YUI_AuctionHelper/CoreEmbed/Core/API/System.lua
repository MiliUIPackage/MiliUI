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

local System = YUI.API.System or {}
YUI.API.System = System

local Legacy = YUI.WOW_API

function System.GetServerTime()
    if type(GetServerTime) ~= "function" then return nil end
    local ok, value = pcall(GetServerTime)
    value = ok and tonumber(value) or nil
    return value and value >= 0 and value or nil
end

function System.GetTime()
    if type(GetTime) ~= "function" then return nil end
    local ok, value = pcall(GetTime)
    value = ok and tonumber(value) or nil
    return value and value >= 0 and value or nil
end

function System.FormatDate(pattern, epoch)
    if type(date) ~= "function" or type(pattern) ~= "string" then return nil end
    epoch = tonumber(epoch)
    if not epoch then return nil end
    local ok, value = pcall(date, pattern, epoch)
    return ok and type(value) == "string" and value or nil
end

function System.GetAddOnMetadata(name, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(name, field)
    end

    if GetAddOnMetadata then
        return GetAddOnMetadata(name, field)
    end

    return nil
end

function System.GetNumAddOns()
    if C_AddOns and C_AddOns.GetNumAddOns then
        return C_AddOns.GetNumAddOns()
    end

    if GetNumAddOns then
        return GetNumAddOns()
    end

    return 0
end

function System.GetAddOnInfo(index)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        return C_AddOns.GetAddOnInfo(index)
    end

    if GetAddOnInfo then
        return GetAddOnInfo(index)
    end

    return nil
end

function System.DoesAddOnExist(name)
    if type(name) ~= "string" or name == "" then return false end

    if C_AddOns and type(C_AddOns.DoesAddOnExist) == "function" then
        local ok, exists = pcall(C_AddOns.DoesAddOnExist, name)
        return ok and exists == true
    end

    local getter = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if type(getter) ~= "function" then return false end

    local ok, installedName, _, _, _, reason = pcall(getter, name)
    return ok and type(installedName) == "string" and reason ~= "MISSING"
end

function System.IsAddOnLoaded(nameOrIndex)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(nameOrIndex)
    end

    if IsAddOnLoaded then
        return IsAddOnLoaded(nameOrIndex)
    end

    return false
end

function System.GetAddOnLoadedState(nameOrIndex)
    if nameOrIndex == nil then
        return nil, "INVALID_ADDON"
    end

    local loader
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        loader = C_AddOns.IsAddOnLoaded
    elseif type(IsAddOnLoaded) == "function" then
        loader = IsAddOnLoaded
    else
        return nil, "MISSING_API"
    end

    local ok, loaded = pcall(loader, nameOrIndex)
    if not ok then
        return nil, "API_ERROR"
    end
    if type(loaded) ~= "boolean" then
        return nil, "INVALID_RESULT"
    end
    return loaded
end

function System.IsAddOnLoadedSafe(nameOrIndex)
    return System.GetAddOnLoadedState(nameOrIndex) == true
end

function System.LoadAddOn(name)
    if C_AddOns and C_AddOns.LoadAddOn then
        return C_AddOns.LoadAddOn(name)
    end

    if LoadAddOn then
        return LoadAddOn(name)
    end

    return false, "MISSING_API"
end

function System.IsGreatVaultAvailable()
    local weeklyRewards = _G.C_WeeklyRewards
    local getActivities = weeklyRewards and weeklyRewards.GetActivities
    if type(getActivities) ~= "function" then return false end

    local ok, activities = pcall(getActivities)
    return ok and type(activities) == "table" and next(activities) ~= nil
end

function System.OpenGreatVault()
    if not System.IsGreatVaultAvailable() then
        return false, "UNAVAILABLE"
    end
    local show = _G.WeeklyRewards_ShowUI
    if type(show) ~= "function" then
        return false, "MISSING_API"
    end
    local ok, result = pcall(show)
    if not ok then return false, "API_ERROR" end
    return result ~= false
end

function System.IsAddonVersionCheckEnabled()
    if C_AddOns and C_AddOns.IsAddonVersionCheckEnabled then
        local ok, value = pcall(C_AddOns.IsAddonVersionCheckEnabled)
        if ok then return value and true or false end
    end

    local value = System.GetCVar("checkAddonVersion")
    return value == true or value == 1 or value == "1" or value == "true"
end

function System.SetAddonVersionCheck(enabled)
    enabled = enabled and true or false

    if C_AddOns and C_AddOns.SetAddonVersionCheck then
        local ok, result = pcall(C_AddOns.SetAddonVersionCheck, enabled)
        if ok then return result ~= false end
    end

    return System.SetCVar("checkAddonVersion", enabled and 1 or 0)
end

function System.SaveAddOns()
    if C_AddOns and C_AddOns.SaveAddOns then
        local ok, result = pcall(C_AddOns.SaveAddOns)
        if ok then return result ~= false end
    end

    if SaveAddOns then
        local ok, result = pcall(SaveAddOns)
        if ok then return result ~= false end
    end

    return false
end

local function GetCurrentCharacter()
    if type(UnitGUID) == "function" then
        local ok, character = pcall(UnitGUID, "player")
        if ok then return character end
    end
    return nil
end

function System.GetAddOnEnabledState(nameOrIndex)
    if nameOrIndex == nil then
        return nil, "INVALID_ADDON"
    end

    if C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function" then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, nameOrIndex, GetCurrentCharacter())
        if not ok then
            return nil, "API_ERROR"
        end
        if type(state) ~= "number" then
            return nil, "INVALID_RESULT"
        end
        local disabledState = Enum and Enum.AddOnEnableState and Enum.AddOnEnableState.None or 0
        if type(disabledState) ~= "number" then
            disabledState = 0
        end
        return state > disabledState
    end

    if type(GetAddOnInfo) == "function" then
        local ok, _, _, _, enabled = pcall(GetAddOnInfo, nameOrIndex)
        if not ok then
            return nil, "API_ERROR"
        end
        if type(enabled) == "boolean" then
            return enabled
        end
        if type(enabled) == "number" then
            return enabled ~= 0
        end
        return nil, "INVALID_RESULT"
    end

    return nil, "MISSING_API"
end

local function IsModernAddOnEnabled(index)
    if not (C_AddOns and C_AddOns.GetAddOnEnableState) then
        return false
    end

    local ok, state = pcall(C_AddOns.GetAddOnEnableState, index, GetCurrentCharacter())
    if not ok or state == nil then
        return false
    end

    local disabledState = Enum and Enum.AddOnEnableState and Enum.AddOnEnableState.None or 0
    return state > disabledState
end

function System.HasEnabledOutOfDateAddOns()
    if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
        for index = 1, C_AddOns.GetNumAddOns() do
            local ok, _, _, _, loadable, reason = pcall(C_AddOns.GetAddOnInfo, index)
            if ok and IsModernAddOnEnabled(index) and not loadable and reason == "INTERFACE_VERSION" then
                return true
            end
        end
        return false
    end

    if GetNumAddOns and GetAddOnInfo then
        for index = 1, GetNumAddOns() do
            local _, _, _, enabled, loadable, reason = GetAddOnInfo(index)
            if enabled and not loadable and reason == "INTERFACE_VERSION" then
                return true
            end
        end
    end

    return false
end

function System.GetCVar(name)
    if not name then return nil end

    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end

    if GetCVar then
        return GetCVar(name)
    end

    return nil
end

function System.GetCVarSafe(name)
    if not name then return nil end

    if C_CVar and C_CVar.GetCVar then
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok then
            return value
        end
    end

    if GetCVar then
        local ok, value = pcall(GetCVar, name)
        if ok then
            return value
        end
    end

    return nil
end

local CVAR_WRITE_STATE_WRITABLE = "WRITABLE"
local CVAR_WRITE_STATE_SECURE = "SECURE"
local CVAR_WRITE_STATE_READ_ONLY = "READ_ONLY"
local CVAR_WRITE_STATE_MISSING = "MISSING"
local CVAR_WRITE_STATE_UNKNOWN = "UNKNOWN"

function System.GetCVarWriteState(name)
    if not name then return CVAR_WRITE_STATE_MISSING end

    if C_CVar and C_CVar.GetCVarInfo then
        local ok, value, _, _, _, _, isSecure, isReadOnly = pcall(C_CVar.GetCVarInfo, name)
        if not ok or value == nil then
            return CVAR_WRITE_STATE_MISSING
        end

        if isReadOnly then
            return CVAR_WRITE_STATE_READ_ONLY
        end
        if isSecure then
            return CVAR_WRITE_STATE_SECURE
        end

        return CVAR_WRITE_STATE_WRITABLE
    end

    if System.GetCVarSafe(name) == nil then
        return CVAR_WRITE_STATE_MISSING
    end

    return CVAR_WRITE_STATE_UNKNOWN
end

function System.SetCVar(name, value)
    if not name then return false end

    if C_CVar and C_CVar.SetCVar then
        local ok, result = pcall(C_CVar.SetCVar, name, tostring(value))
        if ok then return result ~= false end
    end

    if SetCVar then
        local ok, result = pcall(SetCVar, name, value)
        if ok then return result ~= false end
    end

    return false
end

function System.SetCVarSafe(name, value)
    if not name then return false end

    local state = System.GetCVarWriteState(name)
    if state ~= CVAR_WRITE_STATE_WRITABLE and state ~= CVAR_WRITE_STATE_UNKNOWN then
        return false
    end

    if C_CVar and C_CVar.SetCVar then
        local ok, result = pcall(C_CVar.SetCVar, name, tostring(value))
        return ok and result ~= false
    end

    if SetCVar then
        local ok, result = pcall(SetCVar, name, value)
        if ok then return result ~= false end
    end

    return false
end

function System.SetCVarIfExists(name, value)
    if System.GetCVarSafe(name) == nil then
        return false
    end

    return System.SetCVarSafe(name, value)
end

function System.GetCVarBool(name)
    if not name then return false end

    if C_CVar and C_CVar.GetCVarBool then
        local ok, value = pcall(C_CVar.GetCVarBool, name)
        if ok and value ~= nil then return value and true or false end
    end

    if GetCVarBool then
        local ok, value = pcall(GetCVarBool, name)
        if ok and value ~= nil then return value and true or false end
    end

    local value = System.GetCVar(name)
    return value == true or value == 1 or value == "1" or value == "true"
end

function System.GetCVarNumber(name)
    local value = System.GetCVar(name)
    return tonumber(value)
end

function System.CanResetCPUUsage()
    return type(ResetCPUUsage) == "function"
end

local function NormalizeLegacyCPUUsage(ok, callTime, callCount)
    if not ok then return nil end
    if type(issecretvalue) == "function" then
        local timeOK, timeSecret = pcall(issecretvalue, callTime)
        local countOK, countSecret = pcall(issecretvalue, callCount)
        if (timeOK and timeSecret == true) or (countOK and countSecret == true) then
            return nil
        end
    end
    local timeOK, normalizedTime = pcall(tonumber, callTime)
    local countOK, normalizedCount = pcall(tonumber, callCount)
    if not timeOK or not countOK then return nil end
    callTime = normalizedTime
    callCount = normalizedCount
    if not callTime or not callCount
        or callTime ~= callTime or callCount ~= callCount
        or callTime == math.huge or callCount == math.huge
        or callTime == -math.huge or callCount == -math.huge
        or callTime < 0 or callCount < 0
    then
        return nil
    end
    return callTime, callCount
end

-- 诊断专用累计读数。调用方只能计算前后差值，不能重置共享 profiler。
function System.GetFrameCPUUsage(frame, includeChildren)
    if frame == nil or type(GetFrameCPUUsage) ~= "function" then return nil end
    return NormalizeLegacyCPUUsage(pcall(GetFrameCPUUsage, frame, includeChildren == true))
end

function System.GetFunctionCPUUsage(callback, includeSubroutines)
    if type(callback) ~= "function" or type(GetFunctionCPUUsage) ~= "function" then return nil end
    return NormalizeLegacyCPUUsage(pcall(GetFunctionCPUUsage, callback, includeSubroutines ~= false))
end

local PROFILER_THRESHOLD_METRICS = {
    [1] = "CountTimeOver1Ms",
    [5] = "CountTimeOver5Ms",
    [10] = "CountTimeOver10Ms",
    [50] = "CountTimeOver50Ms",
}

local function GetProfilerMetric(metricName)
    local metrics = Enum and Enum.AddOnProfilerMetric
    local metric = metrics and metrics[metricName]
    if metric == nil then return nil end
    return metric
end

local function GetRecentProfilerMetric()
    return GetProfilerMetric("RecentAverageTime")
end

local function IsProfilerEnabled(profiler)
    if type(profiler) ~= "table" then return false end
    if type(profiler.IsEnabled) ~= "function" then return true end
    local ok, enabled = pcall(profiler.IsEnabled)
    return ok and enabled == true
end

function System.CanReadRecentAddOnCPUUsage()
    local profiler = C_AddOnProfiler
    local metric = GetRecentProfilerMetric()
    if type(profiler) ~= "table"
        or type(profiler.GetAddOnMetric) ~= "function"
        or type(profiler.GetApplicationMetric) ~= "function"
        or type(profiler.GetOverallMetric) ~= "function"
        or metric == nil
    then
        return false
    end
    return IsProfilerEnabled(profiler)
end

local function NormalizeProfilerTime(ok, value)
    value = ok and tonumber(value) or nil
    if not value
        or value < 0
        or value ~= value
        or value == math.huge
    then
        return nil
    end
    return value
end

local function GetAddOnProfilerMetric(name, metricName)
    local profiler = C_AddOnProfiler
    local metric = GetProfilerMetric(metricName)
    if type(name) ~= "string"
        or name == ""
        or type(profiler) ~= "table"
        or type(profiler.GetAddOnMetric) ~= "function"
        or metric == nil
        or not IsProfilerEnabled(profiler)
    then
        return nil
    end
    local ok, value = pcall(profiler.GetAddOnMetric, name, metric)
    return NormalizeProfilerTime(ok, value)
end

local function GetOverallProfilerMetric(metricName)
    local profiler = C_AddOnProfiler
    local metric = GetProfilerMetric(metricName)
    if type(profiler) ~= "table"
        or type(profiler.GetOverallMetric) ~= "function"
        or metric == nil
        or not IsProfilerEnabled(profiler)
    then
        return nil
    end
    local ok, value = pcall(profiler.GetOverallMetric, metric)
    return NormalizeProfilerTime(ok, value)
end

local function GetApplicationProfilerMetric(metricName)
    local profiler = C_AddOnProfiler
    local metric = GetProfilerMetric(metricName)
    if type(profiler) ~= "table"
        or type(profiler.GetApplicationMetric) ~= "function"
        or metric == nil
        or not IsProfilerEnabled(profiler)
    then
        return nil
    end
    local ok, value = pcall(profiler.GetApplicationMetric, metric)
    return NormalizeProfilerTime(ok, value)
end

function System.GetAddOnCPURecentAverage(name)
    return GetAddOnProfilerMetric(name, "RecentAverageTime")
end

function System.GetOverallCPURecentAverage()
    return GetOverallProfilerMetric("RecentAverageTime")
end

function System.GetApplicationCPURecentAverage()
    return GetApplicationProfilerMetric("RecentAverageTime")
end

function System.GetAddOnCPULastTime(name)
    return GetAddOnProfilerMetric(name, "LastTime")
end

function System.GetOverallCPULastTime()
    return GetOverallProfilerMetric("LastTime")
end

function System.GetApplicationCPULastTime()
    return GetApplicationProfilerMetric("LastTime")
end

function System.GetTopAddOnsByLastTime(limit, target)
    local profiler = C_AddOnProfiler
    local metric = GetProfilerMetric("LastTime")
    limit = math.floor(tonumber(limit) or 0)
    if limit < 1 or limit > 20
        or type(profiler) ~= "table"
        or type(profiler.GetTopKAddOnsForMetric) ~= "function"
        or metric == nil
        or not IsProfilerEnabled(profiler)
    then
        return nil
    end

    local ok, results = pcall(profiler.GetTopKAddOnsForMetric, metric, limit)
    if not ok or type(results) ~= "table" then return nil end

    target = type(target) == "table" and target or {}
    for index = #target, 1, -1 do target[index] = nil end
    for index = 1, math.min(limit, #results) do
        local result = results[index]
        local name = result and result.addOnName
        local value = result and NormalizeProfilerTime(true, result.metricValue)
        if type(name) == "string" and name ~= "" and value ~= nil then
            target[#target + 1] = {
                addOnName = name,
                milliseconds = value,
            }
        end
    end
    return target
end

local function NormalizeMeasuredCallResult(result)
    if type(result) ~= "table" then return nil end
    local elapsed = NormalizeProfilerTime(true, result.elapsedMilliseconds)
    local allocated = NormalizeProfilerTime(true, result.allocatedBytes)
    local deallocated = NormalizeProfilerTime(true, result.deallocatedBytes)
    if elapsed == nil or allocated == nil or deallocated == nil then return nil end
    return {
        elapsedMilliseconds = elapsed,
        allocatedBytes = allocated,
        deallocatedBytes = deallocated,
    }
end

function System.CanMeasureAddOnCalls()
    local profiler = C_AddOnProfiler
    return type(profiler) == "table"
        and type(profiler.MeasureCall) == "function"
        and IsProfilerEnabled(profiler)
end

-- Diagnostic-only wrapper. Callback return values are intentionally discarded.
-- The second return value reports whether the native profiler invoked the call.
function System.MeasureAddOnCall(callback, ...)
    local profiler = C_AddOnProfiler
    if type(callback) ~= "function"
        or type(profiler) ~= "table"
        or type(profiler.MeasureCall) ~= "function"
        or not IsProfilerEnabled(profiler)
    then
        return nil, false
    end
    local ok, result = pcall(profiler.MeasureCall, callback, ...)
    if not ok then return nil, false end
    return NormalizeMeasuredCallResult(result), true
end

function System.GetAddOnCPUPeakTime(name)
    return GetAddOnProfilerMetric(name, "PeakTime")
end

function System.GetOverallCPUPeakTime()
    return GetOverallProfilerMetric("PeakTime")
end

function System.GetAddOnCPUThresholdCount(name, thresholdMs)
    local metricName = PROFILER_THRESHOLD_METRICS[tonumber(thresholdMs)]
    if not metricName then return nil end
    local value = GetAddOnProfilerMetric(name, metricName)
    return value and math.floor(value) or nil
end

function System.GetOverallCPUThresholdCount(thresholdMs)
    local metricName = PROFILER_THRESHOLD_METRICS[tonumber(thresholdMs)]
    if not metricName then return nil end
    local value = GetOverallProfilerMetric(metricName)
    return value and math.floor(value) or nil
end

function System.ResetCPUUsage()
    if not System.CanResetCPUUsage() then
        return false
    end

    local ok = pcall(ResetCPUUsage)
    return ok and true or false
end

function System.GetAudioOutputDeviceOptions()
    local options = {}

    if not Sound_GameSystem_GetNumOutputDrivers or
        not Sound_GameSystem_GetOutputDriverNameByIndex then
        return options
    end

    local ok, count = pcall(Sound_GameSystem_GetNumOutputDrivers)
    count = ok and tonumber(count) or 0

    for index = 0, count - 1 do
        local nameOK, name = pcall(Sound_GameSystem_GetOutputDriverNameByIndex, index)
        options[#options + 1] = {
            text = (nameOK and name and name ~= "") and name or tostring(index),
            value = index,
        }
    end

    return options
end

function System.GetAudioOutputDeviceIndex()
    return System.GetCVarNumber("Sound_OutputDriverIndex") or 0
end

function System.SetAudioOutputDeviceIndex(index)
    index = tonumber(index) or 0
    local ok = System.SetCVar("Sound_OutputDriverIndex", index)
    if ok and Sound_GameSystem_RestartSoundSystem then
        pcall(Sound_GameSystem_RestartSoundSystem)
    end
    return ok
end

function System.SyncAudioOutputToSystemDefault()
    if type(Sound_GameSystem_RestartSoundSystem) ~= "function" then
        return false
    end

    if not System.SetCVar("Sound_OutputDriverIndex", 0) then
        return false
    end

    local ok = pcall(Sound_GameSystem_RestartSoundSystem)
    return ok and true or false
end

local SETTINGS_ADDONS = {
    "Blizzard_Settings",
    "Blizzard_Settings_Shared",
    "Blizzard_SettingsDefinitions_Shared",
    "Blizzard_SettingsDefinitions_Frame",
}

local function EnsureSettingsAudioCategory()
    if Settings and Settings.OpenToCategory and Settings.AUDIO_CATEGORY_ID then
        return true
    end

    if System.LoadAddOn then
        for _, addonName in ipairs(SETTINGS_ADDONS) do
            pcall(System.LoadAddOn, addonName)
        end
    end

    return Settings and Settings.OpenToCategory and Settings.AUDIO_CATEGORY_ID
end

function System.CanOpenAudioSettings()
    return EnsureSettingsAudioCategory() and true or false
end

function System.OpenAudioSettings()
    if not EnsureSettingsAudioCategory() then
        return false
    end

    local ok, opened = pcall(Settings.OpenToCategory, Settings.AUDIO_CATEGORY_ID)
    return ok and opened ~= false
end

Legacy.GetAddOnMetadata = System.GetAddOnMetadata
Legacy.GetServerTime = System.GetServerTime
Legacy.GetTime = System.GetTime
Legacy.FormatDate = System.FormatDate
Legacy.GetNumAddOns = System.GetNumAddOns
Legacy.GetAddOnInfo = System.GetAddOnInfo
Legacy.IsAddOnLoaded = System.IsAddOnLoaded
Legacy.IsAddOnLoadedSafe = System.IsAddOnLoadedSafe
Legacy.LoadAddOn = System.LoadAddOn
Legacy.IsGreatVaultAvailable = System.IsGreatVaultAvailable
Legacy.OpenGreatVault = System.OpenGreatVault
Legacy.IsAddonVersionCheckEnabled = System.IsAddonVersionCheckEnabled
Legacy.SetAddonVersionCheck = System.SetAddonVersionCheck
Legacy.SaveAddOns = System.SaveAddOns
Legacy.HasEnabledOutOfDateAddOns = System.HasEnabledOutOfDateAddOns
Legacy.GetCVar = System.GetCVar
Legacy.GetCVarSafe = System.GetCVarSafe
Legacy.SetCVar = System.SetCVar
Legacy.SetCVarSafe = System.SetCVarSafe
Legacy.SetCVarIfExists = System.SetCVarIfExists
Legacy.GetCVarBool = System.GetCVarBool
Legacy.GetCVarNumber = System.GetCVarNumber
Legacy.CanResetCPUUsage = System.CanResetCPUUsage
Legacy.ResetCPUUsage = System.ResetCPUUsage
Legacy.GetAudioOutputDeviceOptions = System.GetAudioOutputDeviceOptions
Legacy.GetAudioOutputDeviceIndex = System.GetAudioOutputDeviceIndex
Legacy.SetAudioOutputDeviceIndex = System.SetAudioOutputDeviceIndex
Legacy.CanOpenAudioSettings = System.CanOpenAudioSettings
Legacy.OpenAudioSettings = System.OpenAudioSettings
