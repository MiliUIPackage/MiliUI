local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local System = YUI.API.System or {}
YUI.API.System = System

local Legacy = YUI.WOW_API

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

function System.IsAddOnLoaded(nameOrIndex)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(nameOrIndex)
    end

    if IsAddOnLoaded then
        return IsAddOnLoaded(nameOrIndex)
    end

    return false
end

function System.IsAddOnLoadedSafe(nameOrIndex)
    if not nameOrIndex then return false end

    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, nameOrIndex)
        if ok then return loaded and true or false end
    end

    if IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, nameOrIndex)
        if ok then return loaded and true or false end
    end

    return false
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
    if UnitGUID then
        return UnitGUID("player")
    end
    return nil
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
Legacy.GetNumAddOns = System.GetNumAddOns
Legacy.GetAddOnInfo = System.GetAddOnInfo
Legacy.IsAddOnLoaded = System.IsAddOnLoaded
Legacy.IsAddOnLoadedSafe = System.IsAddOnLoadedSafe
Legacy.LoadAddOn = System.LoadAddOn
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
Legacy.GetAudioOutputDeviceOptions = System.GetAudioOutputDeviceOptions
Legacy.GetAudioOutputDeviceIndex = System.GetAudioOutputDeviceIndex
Legacy.SetAudioOutputDeviceIndex = System.SetAudioOutputDeviceIndex
Legacy.CanOpenAudioSettings = System.CanOpenAudioSettings
Legacy.OpenAudioSettings = System.OpenAudioSettings
