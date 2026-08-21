do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}

local External = YUI.API.External or {}
YUI.API.External = External

local System = YUI.API.System
local CACHE_TTL = 0.5

local definitions = {
    chattynator = {
        label = "Chattynator",
        addons = { "Chattynator" },
        loadedMeansActive = true,
    },
    prat = {
        label = "Prat 3.0",
        addons = { "Prat-3.0", "Prat" },
        loadedMeansActive = true,
    },
    ellesmere_chat = {
        label = "EllesmereUI Chat",
        addons = { "EllesmereUIChat" },
        loadedMeansActive = true,
    },
    elvui = {
        label = "ElvUI",
        addons = { "ElvUI" },
        modules = {},
    },
    ndui = {
        label = "NDui",
        addons = { "NDui", "NDUI" },
        modules = {},
    },
    enhanceqol = {
        label = "EnhanceQoL",
        addons = { "EnhanceQoL" },
        modules = {},
    },
    elvui_windtools = {
        label = "ElvUI WindTools",
        addons = { "ElvUI_WindTools" },
        modules = {},
    },
    pig = {
        label = "!Pig",
        addons = { "!Pig" },
        modules = {},
        loadedMeansActive = true,
    },
    extended_vendor_yui = {
        label = "ExtendedVendorFrame_YUI",
        addons = { "ExtendedVendorFrame_YUI" },
        loadedMeansActive = true,
    },
    details = {
        label = "Details",
        addons = { "Details" },
        loadedMeansActive = true,
    },
    hdskada = {
        label = "HDSkada",
        addons = { "hdskada", "HDSkada" },
        loadedMeansActive = true,
    },
    lightdamage = {
        label = "LightDamage",
        addons = { "LightDamage" },
        loadedMeansActive = true,
    },
    ellesmere_actionbars = {
        label = "EllesmereUI Action Bars",
        addons = { "EllesmereUIActionBars" },
        loadedMeansActive = true,
        retailOnly = true,
    },
    ellesmere_cooldown = {
        label = "EllesmereUI Cooldown Manager",
        addons = { "EllesmereUICooldownManager" },
        loadedMeansActive = true,
        retailOnly = true,
    },
    ellesmere_minimap = {
        label = "EllesmereUI Minimap",
        addons = { "EllesmereUIMinimap" },
        loadedMeansActive = true,
        retailOnly = true,
    },
}

local capabilities = {
    ["ui.chat.controller"] = {
        { addon = "chattynator" },
        { addon = "prat" },
        { addon = "ellesmere_chat" },
        { addon = "elvui", module = "chat" },
        { addon = "ndui", module = "chat" },
    },
    ["ui.actionbar.controller"] = {
        { addon = "ellesmere_actionbars" },
        { addon = "elvui", module = "actionbar" },
        { addon = "ndui", module = "actionbar" },
    },
    ["ui.cooldown.controller"] = {
        { addon = "ellesmere_cooldown" },
    },
    ["ui.minimap.controller"] = {
        { addon = "ellesmere_minimap" },
    },
    ["ui.minimap.collector"] = {
        { addon = "enhanceqol", module = "minimapCollector" },
        { addon = "ndui", module = "minimapCollector" },
        { addon = "elvui_windtools", module = "minimapCollector" },
    },
    ["ui.talent.controller"] = {
        { addon = "pig" },
        { addon = "extended_vendor_yui" },
    },
    ["ui.damage_meter.controller"] = {
        { addon = "details" },
        { addon = "hdskada" },
        { addon = "lightdamage" },
    },
}

local aliases = {}
for key, definition in pairs(definitions) do
    aliases[string.lower(key)] = key
    for _, addonName in ipairs(definition.addons) do
        aliases[string.lower(addonName)] = key
    end
end

local loadedCache = {}
local enabledCache = {}
local moduleCache = {}
local capabilityCache = {}
local loadGeneration = 0
local resolving = {}
local stats = {
    hits = 0,
    misses = 0,
    errors = 0,
    invalidations = 0,
}

local function SafeField(object, key)
    if type(object) ~= "table" then return nil, false end
    local ok, value = pcall(function() return object[key] end)
    if not ok then return nil, false end
    return value, true
end

local function SafePath(root, ...)
    local value = root
    for index = 1, select("#", ...) do
        local ok
        value, ok = SafeField(value, select(index, ...))
        if not ok or value == nil then return nil, ok end
    end
    return value, true
end

local function BooleanValue(value)
    if type(value) == "boolean" then return value end
    if type(value) == "number" then return value ~= 0 end
    return nil
end

local function ValidateBoolean(value)
    local boolean = BooleanValue(value)
    if boolean == nil then return nil, "INVALID_RESULT" end
    return boolean
end

local function ProbeElvUI(moduleKey)
    local engine, ok = SafeField(_G, "ElvUI")
    if not ok then return nil, "EXTERNAL_READ_ERROR" end
    local core = SafePath(engine, 1)
    if type(core) ~= "table" then return nil, "MODULE_STATE_UNAVAILABLE" end
    local private = SafePath(core, "private", moduleKey)
    local value, read = SafeField(private, "enable")
    if read and value ~= nil then return ValidateBoolean(value) end
    if moduleKey == "actionbar" then
        local db = SafePath(core, "db", "actionbar")
        value, read = SafeField(db, "enable")
        if read and value ~= nil then return ValidateBoolean(value) end
    end
    return nil, "MODULE_STATE_UNAVAILABLE"
end

local function ProbeNDui(moduleKey)
    local db, ok = SafeField(_G, "NDuiDB")
    if not ok then return nil, "EXTERNAL_READ_ERROR" end
    if type(db) ~= "table" then return nil, "MODULE_STATE_UNAVAILABLE" end
    local candidateKeys = moduleKey == "actionbar" and { "Actionbar", "ActionBar", "actionbar" } or { "Chat", "chat" }
    for _, key in ipairs(candidateKeys) do
        local module, read = SafeField(db, key)
        if not read then return nil, "EXTERNAL_READ_ERROR" end
        if type(module) == "table" then
            if moduleKey == "chat" then
                local disabled
                disabled, read = SafeField(module, "Disable")
                if not read then return nil, "EXTERNAL_READ_ERROR" end
                if disabled ~= nil then
                    local boolean, reason = ValidateBoolean(disabled)
                    if boolean == nil then return nil, reason end
                    return not boolean
                end
            else
                local enabled
                enabled, read = SafeField(module, "Enable")
                if not read then return nil, "EXTERNAL_READ_ERROR" end
                if enabled == nil then enabled, read = SafeField(module, "enable") end
                if not read then return nil, "EXTERNAL_READ_ERROR" end
                if enabled ~= nil then return ValidateBoolean(enabled) end
            end
        end
    end
    if moduleKey == "actionbar" then
        local addon, addonRead = SafeField(_G, "NDui")
        local actionbar, actionbarRead = SafeField(addon, "Actionbar")
        if not addonRead or not actionbarRead then return nil, "EXTERNAL_READ_ERROR" end
        local enabled, enabledRead = SafeField(actionbar, "Enable")
        if enabled == nil then enabled, enabledRead = SafeField(actionbar, "enable") end
        if not enabledRead then return nil, "EXTERNAL_READ_ERROR" end
        if enabled ~= nil then return ValidateBoolean(enabled) end
    end
    return nil, "MODULE_STATE_UNAVAILABLE"
end

local function ProbeEnhanceQoLCollector()
    local addon, ok = SafeField(_G, "EnhanceQoL")
    if not ok then return nil, "EXTERNAL_READ_ERROR" end
    local value, read = SafePath(addon, "db", "enableMinimapButtonBin")
    if not read then return nil, "MODULE_STATE_UNAVAILABLE" end
    return ValidateBoolean(value)
end

local function ProbeNDuiCollector()
    local frame, frameRead = SafeField(_G, "RecycleBinFrame")
    local button, buttonRead = SafeField(_G, "RecycleBinToggleButton")
    if not frameRead or not buttonRead then return nil, "EXTERNAL_READ_ERROR" end
    return frame ~= nil or button ~= nil
end

local function ProbeWindToolsCollector()
    local engine, ok = SafeField(_G, "ElvUI")
    if not ok then return nil, "EXTERNAL_READ_ERROR" end
    local value, read = SafePath(engine, 1, "private", "WT", "maps", "minimapButtons", "enable")
    if not read then return nil, "MODULE_STATE_UNAVAILABLE" end
    return ValidateBoolean(value)
end

local function ProbePigTalent()
    local marker, ok = SafeField(_G, "PIGA")
    if not ok then return nil, "EXTERNAL_READ_ERROR" end
    return marker ~= nil
end

definitions.elvui.modules.chat = function() return ProbeElvUI("chat") end
definitions.elvui.modules.actionbar = function() return ProbeElvUI("actionbar") end
definitions.ndui.modules.chat = function() return ProbeNDui("chat") end
definitions.ndui.modules.actionbar = function() return ProbeNDui("actionbar") end
definitions.ndui.modules.minimapCollector = ProbeNDuiCollector
definitions.enhanceqol.modules.minimapCollector = ProbeEnhanceQoLCollector
definitions.elvui_windtools.modules.minimapCollector = ProbeWindToolsCollector
definitions.pig.loadedProbe = ProbePigTalent

local function Now()
    if System and type(System.GetTime) == "function" then
        local ok, value = pcall(System.GetTime)
        if ok and type(value) == "number" then return value end
    end
    return nil
end

local function ResolveKey(addonKey)
    if type(addonKey) ~= "string" or addonKey == "" then return nil end
    local ok, lowered = pcall(string.lower, addonKey)
    return ok and aliases[lowered] or nil
end

local function ReadTimedCache(cache, key, force)
    if force then return nil end
    local entry = cache[key]
    local now = Now()
    if entry and now and entry.expiresAt and now < entry.expiresAt then
        stats.hits = stats.hits + 1
        return entry
    end
    return nil
end

local function WriteTimedCache(cache, key, value, reason)
    local now = Now()
    if now then
        cache[key] = { value = value, reason = reason, expiresAt = now + CACHE_TTL }
    end
end

local function ProbeDefinitionState(definition, method)
    local sawUnknown, unknownReason
    for _, addonName in ipairs(definition.addons) do
        local state, reason = method(addonName)
        if state == true then return true end
        if state == nil then
            sawUnknown = true
            unknownReason = unknownReason or reason
        end
    end
    if method == System.GetAddOnLoadedState and type(definition.loadedProbe) == "function" then
        local ok, state, reason = pcall(definition.loadedProbe)
        if not ok then
            sawUnknown = true
            unknownReason = unknownReason or "PROBE_ERROR"
        elseif state == true then
            return true
        elseif state == nil then
            sawUnknown = true
            unknownReason = unknownReason or reason
        end
    end
    if sawUnknown then return nil, unknownReason or "UNKNOWN" end
    return false
end

function External.IsLoaded(selfOrAddonKey, addonKeyOrOptions, maybeOptions)
    local addonKey, options
    if selfOrAddonKey == External then
        addonKey, options = addonKeyOrOptions, maybeOptions
    else
        addonKey, options = selfOrAddonKey, addonKeyOrOptions
    end
    local key = ResolveKey(addonKey)
    if not key then return nil, "UNKNOWN_ADDON" end
    options = type(options) == "table" and options or nil
    local cached = not (options and options.force) and loadedCache[key]
    if cached and (cached.value == true or cached.generation == loadGeneration) then
        stats.hits = stats.hits + 1
        return cached.value, cached.reason
    end

    stats.misses = stats.misses + 1
    local definition = definitions[key]
    local method = System and System.GetAddOnLoadedState
    if type(method) ~= "function" then
        stats.errors = stats.errors + 1
        return nil, "MISSING_API"
    end
    local ok, value, reason = pcall(ProbeDefinitionState, definition, method)
    if not ok then
        stats.errors = stats.errors + 1
        value, reason = nil, "PROBE_ERROR"
    elseif value == nil then
        stats.errors = stats.errors + 1
    end
    loadedCache[key] = { value = value, reason = reason, generation = loadGeneration }
    return value, reason
end

function External.IsEnabled(selfOrAddonKey, addonKeyOrOptions, maybeOptions)
    local addonKey, options
    if selfOrAddonKey == External then
        addonKey, options = addonKeyOrOptions, maybeOptions
    else
        addonKey, options = selfOrAddonKey, addonKeyOrOptions
    end
    local key = ResolveKey(addonKey)
    if not key then return nil, "UNKNOWN_ADDON" end
    options = type(options) == "table" and options or nil
    local cached = ReadTimedCache(enabledCache, key, options and options.force)
    if cached then return cached.value, cached.reason end

    stats.misses = stats.misses + 1
    local method = System and System.GetAddOnEnabledState
    if type(method) ~= "function" then
        stats.errors = stats.errors + 1
        return nil, "MISSING_API"
    end
    local ok, value, reason = pcall(ProbeDefinitionState, definitions[key], method)
    if not ok then
        stats.errors = stats.errors + 1
        value, reason = nil, "PROBE_ERROR"
    elseif value == nil then
        stats.errors = stats.errors + 1
    end
    WriteTimedCache(enabledCache, key, value, reason)
    return value, reason
end

function External.GetModuleState(selfOrAddonKey, addonKeyOrModuleKey, moduleKeyOrOptions, maybeOptions)
    local addonKey, moduleKey, options
    if selfOrAddonKey == External then
        addonKey, moduleKey, options = addonKeyOrModuleKey, moduleKeyOrOptions, maybeOptions
    else
        addonKey, moduleKey, options = selfOrAddonKey, addonKeyOrModuleKey, moduleKeyOrOptions
    end
    local key = ResolveKey(addonKey)
    if not key or type(moduleKey) ~= "string" or moduleKey == "" then
        return nil, "UNKNOWN_MODULE"
    end
    options = type(options) == "table" and options or nil
    local cacheKey = key .. ":" .. moduleKey
    local cached = ReadTimedCache(moduleCache, cacheKey, options and options.force)
    if cached then return cached.value, cached.reason end
    if resolving[cacheKey] then return nil, "RECURSIVE_PROBE" end

    stats.misses = stats.misses + 1
    resolving[cacheKey] = true
    local loaded, loadedReason = External:IsLoaded(key, options)
    local value, reason
    if loaded == false then
        value, reason = false, "NOT_LOADED"
    elseif loaded == nil then
        value, reason = nil, loadedReason
    else
        local probe = definitions[key].modules and definitions[key].modules[moduleKey]
        if type(probe) ~= "function" then
            value, reason = nil, "MODULE_STATE_UNAVAILABLE"
        else
            local ok, probeValue, probeReason = pcall(probe)
            if not ok then
                stats.errors = stats.errors + 1
                value, reason = nil, "PROBE_ERROR"
            elseif type(probeValue) ~= "boolean" then
                stats.errors = stats.errors + 1
                value, reason = nil, probeReason or "INVALID_RESULT"
            else
                value, reason = probeValue, probeReason
            end
        end
    end
    resolving[cacheKey] = nil
    WriteTimedCache(moduleCache, cacheKey, value, reason)
    return value, reason
end

local function CopyMatches(matches)
    local copy = {}
    for index, match in ipairs(matches or {}) do
        copy[index] = {
            addon = match.addon,
            controller = match.controller,
            status = match.status,
        }
    end
    return copy
end

local function CopySnapshot(snapshot)
    return {
        status = snapshot.status,
        active = snapshot.active,
        controller = snapshot.controller,
        matches = CopyMatches(snapshot.matches),
        degraded = snapshot.degraded and true or false,
    }
end

function External.ResolveCapability(selfOrCapabilityKey, capabilityKeyOrOptions, maybeOptions)
    local capabilityKey, options
    if selfOrCapabilityKey == External then
        capabilityKey, options = capabilityKeyOrOptions, maybeOptions
    else
        capabilityKey, options = selfOrCapabilityKey, capabilityKeyOrOptions
    end
    if type(capabilityKey) ~= "string" or not capabilities[capabilityKey] then
        return { status = "unknown", active = nil, controller = nil, matches = {}, degraded = true }
    end
    options = type(options) == "table" and options or nil
    local cached = ReadTimedCache(capabilityCache, capabilityKey, options and options.force)
    if cached then return CopySnapshot(cached.value) end
    if resolving[capabilityKey] then
        return { status = "unknown", active = nil, controller = nil, matches = {}, degraded = true }
    end

    stats.misses = stats.misses + 1
    resolving[capabilityKey] = true
    local activeMatches, unknownMatches = {}, {}
    for _, candidate in ipairs(capabilities[capabilityKey]) do
        local definition = definitions[candidate.addon]
        local value
        if definition.retailOnly and YUI.IsRetail ~= true then
            value = false
        elseif candidate.module then
            value = External:GetModuleState(candidate.addon, candidate.module, options)
        elseif definition.loadedMeansActive then
            value = External:IsLoaded(candidate.addon, options)
        else
            value = nil
        end
        local match = {
            addon = candidate.addon,
            controller = definition.label,
            status = value == true and "active" or value == false and "inactive" or "unknown",
        }
        if value == true then
            activeMatches[#activeMatches + 1] = match
        elseif value == nil then
            unknownMatches[#unknownMatches + 1] = match
        end
    end
    resolving[capabilityKey] = nil

    local snapshot
    if #activeMatches > 0 then
        local names = {}
        for index, match in ipairs(activeMatches) do names[index] = match.controller end
        snapshot = {
            status = "active",
            active = true,
            controller = table.concat(names, ", "),
            matches = activeMatches,
            degraded = #unknownMatches > 0,
        }
    elseif #unknownMatches > 0 then
        snapshot = {
            status = "unknown",
            active = nil,
            controller = nil,
            matches = unknownMatches,
            degraded = true,
        }
    else
        snapshot = { status = "inactive", active = false, controller = nil, matches = {}, degraded = false }
    end
    WriteTimedCache(capabilityCache, capabilityKey, snapshot)
    return CopySnapshot(snapshot)
end

function External.Invalidate(selfOrAddonKey, addonKeyOrModuleKey, moduleKeyOrReason, maybeReason)
    local addonKey, moduleKey, reason
    if selfOrAddonKey == External then
        addonKey, moduleKey, reason = addonKeyOrModuleKey, moduleKeyOrReason, maybeReason
    else
        addonKey, moduleKey, reason = selfOrAddonKey, addonKeyOrModuleKey, moduleKeyOrReason
    end
    local key = addonKey and ResolveKey(addonKey) or nil
    stats.invalidations = stats.invalidations + 1
    loadGeneration = loadGeneration + 1

    if key then
        local loaded = loadedCache[key]
        if loaded and loaded.value ~= true then loadedCache[key] = nil end
        enabledCache[key] = nil
        if moduleKey then
            moduleCache[key .. ":" .. tostring(moduleKey)] = nil
        else
            for cacheKey in pairs(moduleCache) do
                if string.sub(cacheKey, 1, #key + 1) == key .. ":" then moduleCache[cacheKey] = nil end
            end
        end
    else
        for cacheKey, entry in pairs(loadedCache) do
            if entry.value ~= true then loadedCache[cacheKey] = nil end
        end
        for cacheKey in pairs(enabledCache) do enabledCache[cacheKey] = nil end
        for cacheKey in pairs(moduleCache) do moduleCache[cacheKey] = nil end
    end
    for cacheKey in pairs(capabilityCache) do capabilityCache[cacheKey] = nil end

    if YUI.Event and type(YUI.Event.Emit) == "function" then
        pcall(YUI.Event.Emit, YUI.Event, "YUI_EXTERNAL_STATE_CHANGED", key, moduleKey, reason)
    end
end

function External.GetStats()
    return {
        hits = stats.hits,
        misses = stats.misses,
        errors = stats.errors,
        invalidations = stats.invalidations,
    }
end

if YUI.Event and type(YUI.Event.On) == "function" and not External._addonLoadedHandle then
    External._addonLoadedHandle = YUI.Event:On("ADDON_LOADED", function(_, addonName)
        External:Invalidate(addonName, nil, "ADDON_LOADED")
        if C_Timer and type(C_Timer.After) == "function" then
            pcall(C_Timer.After, 0, function()
                External:Invalidate(addonName, nil, "ADDON_LOADED_POST")
            end)
        end
    end, External, { priority = 9000 })
end
