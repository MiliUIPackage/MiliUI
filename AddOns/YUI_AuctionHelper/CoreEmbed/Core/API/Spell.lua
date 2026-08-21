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

local Spell = YUI.API.Spell or {}
YUI.API.Spell = Spell

local Legacy = YUI.WOW_API
local DEFAULT_ACTION_SLOT_SCAN_MAX = 180
local GCD_SPELL_ID = 61304
local SPELL_NAME_CACHE_VERSION = 2
local SPELL_NAME_CACHE_MAX_MISSES = 80000
local SPELL_NAME_CACHE_MAX_NAMES = 250000
local SPELL_NAME_CACHE_MAX_RECORDS = 600000
local SPELL_NAME_CACHE_GEAR_ICON = 136243
local SPELL_NAME_CACHE_OVERFLOW_ERROR = "cache-overflow-guard"
local SPELL_NAME_CACHE_ESTIMATED_MAX_ID = 1213133
local SPELL_NAME_CACHE_TICK_INTERVAL = 0.05
local SPELL_NAME_CACHE_BACKGROUND_BUDGET_MS = 1
local SPELL_NAME_CACHE_INTERACTIVE_BUDGET_MS = 2
local SPELL_NAME_CACHE_BACKGROUND_IDS_PER_FRAME = 80
local SPELL_NAME_CACHE_INTERACTIVE_IDS_PER_FRAME = 160
local SPELL_NAME_CACHE_BACKGROUND_MIN_CHECK_IDS = 20
local SPELL_NAME_CACHE_INTERACTIVE_MIN_CHECK_IDS = 40
local SPELL_NAME_CACHE_PRIORITY_BACKGROUND = "background"
local SPELL_NAME_CACHE_PRIORITY_INTERACTIVE = "interactive"
local SPELL_NAME_CACHE_DEFAULT_RELEASE_DELAY = 60
local SPELL_NAME_CACHE_RETAIL_HOLES = {
    [474771] = 556604,
    [556606] = 936050,
    [936051] = 1049295,
    [1049296] = 1213133,
}
local SPELL_NAME_CACHE_CLASSIC_HOLES = {
    [63707] = 81743,
    [81748] = 219002,
    [219004] = 285223,
    [285224] = 301088,
    [301101] = 324269,
    [474742] = 1213143,
}
local cooldownProbeHost
local cooldownProbes = {}
local nameCacheRuntime = {
    batches = 0,
    scannedIDs = 0,
    totalMs = 0,
    maxBatchMs = 0,
    eventOwner = {},
}

local function IsSecretValue(value)
    local security = YUI.API and YUI.API.Security
    if security and security.IsSecretValue then
        return security.IsSecretValue(value) == true
    end

    if not issecretvalue then
        return false
    end

    local ok, isSecret = pcall(issecretvalue, value)
    return ok and isSecret == true
end

local function SafeRawValue(value)
    if IsSecretValue(value) or value == nil then
        return nil
    end
    return value
end

local function SafeNumberValue(value)
    if IsSecretValue(value) or value == nil then
        return nil
    end

    local ok, numberValue = pcall(tonumber, value)
    if ok and not IsSecretValue(numberValue) and numberValue ~= nil then
        return numberValue
    end
    return nil
end

local function SafeBooleanValue(value, fallback)
    if IsSecretValue(value) or value == nil then
        return fallback
    end
    if value == false or value == 0 then
        return false
    end
    if value == true or value == 1 then
        return true
    end
    return value and true or false
end

local function FirstSafeRawValue(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if not IsSecretValue(value) and value ~= nil then
            return value
        end
    end
    return nil
end

local function FirstSafeNumberValue(...)
    for i = 1, select("#", ...) do
        local numberValue = SafeNumberValue(select(i, ...))
        if numberValue ~= nil then
            return numberValue
        end
    end
    return nil
end

local function FirstSafeBooleanValue(fallback, ...)
    for i = 1, select("#", ...) do
        local rawValue = select(i, ...)
        local boolValue = SafeBooleanValue(rawValue, nil)
        if boolValue ~= nil then
            return boolValue
        end
    end
    return fallback
end

local function NormalizeInfo(name, iconID, originalIconID, castTime, minRange, maxRange, spellID)
    if not name then return nil end

    return {
        name = name,
        iconID = iconID,
        originalIconID = originalIconID,
        castTime = castTime,
        minRange = minRange,
        maxRange = maxRange,
        spellID = spellID,
    }
end

local function GetInfoFromCSpell(spellID)
    if not C_Spell or not C_Spell.GetSpellInfo then return nil end

    local info = C_Spell.GetSpellInfo(spellID)
    if type(info) == "table" then
        return NormalizeInfo(
            info.name,
            info.iconID,
            info.originalIconID,
            info.castTime,
            info.minRange,
            info.maxRange,
            info.spellID
        )
    end

    return nil
end

local function GetInfoFromGlobal(spellID)
    if not GetSpellInfo then return nil end

    local name, _, iconID, castTime, minRange, maxRange, resolvedSpellID = GetSpellInfo(spellID)
    return NormalizeInfo(name, iconID, iconID, castTime, minRange, maxRange, resolvedSpellID or spellID)
end

function Spell.GetInfo(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        return GetInfoFromCSpell(spellID) or GetInfoFromGlobal(spellID)
    end

    if YUI.IsMists then
        return GetInfoFromGlobal(spellID) or GetInfoFromCSpell(spellID)
    end

    if YUI.IsWrath then
        return GetInfoFromGlobal(spellID) or GetInfoFromCSpell(spellID)
    end

    return GetInfoFromGlobal(spellID) or GetInfoFromCSpell(spellID)
end

local function GetTextureFromCSpell(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(spellID)
        if texture then return texture end
    end
    return nil
end

local function GetTextureFromGlobal(spellID)
    if GetSpellTexture then
        local texture = GetSpellTexture(spellID)
        if texture then return texture end
    end

    local info = GetInfoFromGlobal(spellID)
    return info and info.iconID or nil
end

function Spell.GetName(spellID)
    local info = Spell.GetInfo(spellID)
    return info and info.name or nil
end

function Spell.GetTexture(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        return GetTextureFromCSpell(spellID) or GetTextureFromGlobal(spellID)
    end

    if YUI.IsMists then
        return GetTextureFromGlobal(spellID) or GetTextureFromCSpell(spellID)
    end

    if YUI.IsWrath then
        return GetTextureFromGlobal(spellID) or GetTextureFromCSpell(spellID)
    end

    return GetTextureFromGlobal(spellID) or GetTextureFromCSpell(spellID)
end

function Spell.ReadMaxCumulativeAuraApplications(spellID)
    spellID = SafeNumberValue(spellID)
    if not spellID or spellID <= 0 then return nil, "invalid-spell" end
    local api = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications
    if type(api) ~= "function" then return nil, "api-unavailable" end

    local ok, value = pcall(api, spellID)
    if not ok then return nil, "api-error" end
    if IsSecretValue(value) then return nil, "restricted" end

    value = SafeNumberValue(value)
    if not value then return nil, "unavailable" end
    value = math.floor(value + 0.5)
    if value < 1 or value > 100 then return nil, "invalid-max" end
    return value, nil
end

local function GetSpellNameCacheBuild()
    if GetBuildInfo then
        local _, build = GetBuildInfo()
        if build ~= nil then
            return tostring(build)
        end
    end
    return "unknown"
end

local function GetSpellNameCacheLocale()
    if GetLocale then
        local locale = GetLocale()
        if locale ~= nil then
            return tostring(locale)
        end
    end
    return "unknown"
end

local function GetSpellNameCacheTime()
    if time then
        return time()
    end
    if GetTime then
        return math.floor(GetTime())
    end
    return 0
end

local function GetSpellNameCacheHoles()
    if YUI.IsRetail then
        return SPELL_NAME_CACHE_RETAIL_HOLES
    end
    if YUI.IsWrath then
        return SPELL_NAME_CACHE_CLASSIC_HOLES
    end
    return nil
end

local function NormalizeSpellNameCachePriority(priority)
    if priority == SPELL_NAME_CACHE_PRIORITY_INTERACTIVE then
        return SPELL_NAME_CACHE_PRIORITY_INTERACTIVE
    end
    return SPELL_NAME_CACHE_PRIORITY_BACKGROUND
end

local function SetSpellNameCachePriority(priority)
    nameCacheRuntime.priority = NormalizeSpellNameCachePriority(priority)
end

local function CountSpellNameCacheOwners()
    local owners = nameCacheRuntime.owners
    if type(owners) ~= "table" then
        return 0
    end

    local count = 0
    for _ in pairs(owners) do
        count = count + 1
    end
    return count
end

local function GetSpellNameCacheState(cache)
    if type(cache) ~= "table" then
        return "idle"
    end
    if cache.error then
        return "error"
    end
    if cache.complete then
        return "complete"
    end
    if nameCacheRuntime.paused then
        return "paused"
    end
    if cache.building or nameCacheRuntime.running then
        return "building"
    end
    return "idle"
end

local function GetSpellNameCacheMemoryKB()
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        pcall(UpdateAddOnMemoryUsage)
        local addonName = YUI and YUI.AddonName
        if addonName then
            local ok, usage = pcall(GetAddOnMemoryUsage, addonName)
            if ok and type(usage) == "number" then
                return math.floor(usage + 0.5)
            end
        end
    end

    if collectgarbage then
        local ok, usage = pcall(collectgarbage, "count")
        if ok and type(usage) == "number" then
            return math.floor(usage + 0.5)
        end
    end
    return nil
end

local function DebugSpellNameCache(message)
    if not (YUI and YUI.IsDev and type(YUI.Debug) == "function") then
        return
    end
    pcall(YUI.Debug, YUI, message)
end

local function FormatSpellNameCacheDebugSuffix(cache)
    local ownerCount = CountSpellNameCacheOwners()
    local names = cache and cache.nameCount or 0
    local records = cache and cache.recordCount or 0
    local lastID = cache and cache.lastID or 0
    local memoryKB = GetSpellNameCacheMemoryKB()
    local suffix = string.format(" names=%s records=%s lastID=%s ownerCount=%s", tostring(names), tostring(records), tostring(lastID), tostring(ownerCount))
    if memoryKB then
        suffix = suffix .. string.format(" mem=%dKB", memoryKB)
    end
    return suffix
end

local function GetSpellNameCacheBudget()
    if NormalizeSpellNameCachePriority(nameCacheRuntime.priority) == SPELL_NAME_CACHE_PRIORITY_INTERACTIVE then
        return SPELL_NAME_CACHE_INTERACTIVE_BUDGET_MS, SPELL_NAME_CACHE_INTERACTIVE_IDS_PER_FRAME, SPELL_NAME_CACHE_INTERACTIVE_MIN_CHECK_IDS
    end
    return SPELL_NAME_CACHE_BACKGROUND_BUDGET_MS, SPELL_NAME_CACHE_BACKGROUND_IDS_PER_FRAME, SPELL_NAME_CACHE_BACKGROUND_MIN_CHECK_IDS
end

local function CleanupPersistentSpellNameCache()
    if nameCacheRuntime.persistentCleanupDone then
        return
    end
    if not (YUI.DB and YUI.DB.IsReady and YUI.DB.GetGlobal and YUI.DB:IsReady()) then
        return
    end

    local global = YUI.DB:GetGlobal("suite")
    if type(global) == "table" then
        if global.spellNameCache ~= nil then
            rawset(global, "spellNameCache", nil)
        end
    end
    nameCacheRuntime.persistentCleanupDone = true
end

local function IsSpellNameCacheValid(cache, build, locale)
    return type(cache) == "table"
        and cache.cacheVersion == SPELL_NAME_CACHE_VERSION
        and cache.build == build
        and cache.locale == locale
        and type(cache.spells) == "table"
end

local function CreateSpellNameCache(build, locale)
    return {
        cacheVersion = SPELL_NAME_CACHE_VERSION,
        build = build,
        locale = locale,
        spells = {},
        lastID = 0,
        misses = 0,
        nameCount = 0,
        recordCount = 0,
        complete = false,
        building = false,
        createdAt = GetSpellNameCacheTime(),
        updatedAt = GetSpellNameCacheTime(),
    }
end

local function EnsureSpellNameCacheStorage(createIfMissing)
    CleanupPersistentSpellNameCache()

    local build = GetSpellNameCacheBuild()
    local locale = GetSpellNameCacheLocale()
    local cache = nameCacheRuntime.cache
    if not IsSpellNameCacheValid(cache, build, locale) then
        if createIfMissing == false then
            return nil, "not-started"
        end
        cache = CreateSpellNameCache(build, locale)
        nameCacheRuntime.cache = cache
        nameCacheRuntime.lowerIndex = nil
        nameCacheRuntime.lowerIndexSource = nil
    end

    if cache.error then
        cache.building = false
    elseif cache.complete then
        cache.building = false
    elseif not nameCacheRuntime.running then
        cache.building = false
    end

    return cache, nil
end

local function NormalizeSpellNameCacheLookup(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("|T.-|t%s*", "")
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if strtrim then
        value = strtrim(value)
    else
        value = value:gsub("^%s+", ""):gsub("%s+$", "")
    end
    if value == "" then
        return nil
    end
    if strlower then
        return strlower(value)
    end
    return string.lower(value)
end

local function GetSpellNameCacheLowerIndex(cache)
    if nameCacheRuntime.lowerIndexSource == cache and type(nameCacheRuntime.lowerIndex) == "table" then
        return nameCacheRuntime.lowerIndex
    end

    local index = {}
    for name in pairs(cache.spells or {}) do
        local normalized = NormalizeSpellNameCacheLookup(name)
        if normalized and index[normalized] == nil then
            index[normalized] = name
        end
    end
    nameCacheRuntime.lowerIndex = index
    nameCacheRuntime.lowerIndexSource = cache
    return index
end

local function HasSpellNameCacheRecord(records, spellID)
    if not records or not spellID then
        return false
    end
    return ("," .. tostring(records) .. ","):find("," .. tostring(spellID) .. "=", 1, true) ~= nil
end

local function AddSpellNameCacheRecord(cache, name, spellID, icon)
    if type(cache) ~= "table" or cache.error or type(name) ~= "string" or name == "" then
        return false
    end

    spellID = SafeNumberValue(spellID)
    if not spellID or spellID <= 0 then
        return false
    end

    local spells = cache.spells
    if type(spells) ~= "table" then
        spells = {}
        cache.spells = spells
    end

    local record = tostring(math.floor(spellID)) .. "=" .. tostring(icon or "")
    local current = spells[name]
    if current == nil or current == "" then
        spells[name] = record
        cache.nameCount = (cache.nameCount or 0) + 1
        cache.recordCount = (cache.recordCount or 0) + 1
        if cache.nameCount > SPELL_NAME_CACHE_MAX_NAMES or cache.recordCount > SPELL_NAME_CACHE_MAX_RECORDS then
            cache.error = SPELL_NAME_CACHE_OVERFLOW_ERROR
            cache.building = false
            cache.complete = false
        end
        nameCacheRuntime.lowerIndex = nil
        nameCacheRuntime.lowerIndexSource = nil
        return cache.error == nil
    end

    if not HasSpellNameCacheRecord(current, spellID) then
        spells[name] = tostring(current) .. "," .. record
        cache.recordCount = (cache.recordCount or 0) + 1
        if cache.nameCount > SPELL_NAME_CACHE_MAX_NAMES or cache.recordCount > SPELL_NAME_CACHE_MAX_RECORDS then
            cache.error = SPELL_NAME_CACHE_OVERFLOW_ERROR
            cache.building = false
            cache.complete = false
        end
        return cache.error == nil
    end

    return false
end

local function ReadSpellNameCacheRecord(records)
    if type(records) == "number" then
        return SafeNumberValue(records), nil
    end
    if type(records) ~= "string" then
        return nil, nil
    end

    for record in records:gmatch("[^,]+") do
        local idText, iconText = record:match("^(%d+)=(.*)$")
        local spellID = SafeNumberValue(idText)
        if spellID then
            local icon = SafeNumberValue(iconText) or (type(iconText) == "string" and iconText ~= "" and iconText or nil)
            return spellID, icon
        end
    end

    return nil, nil
end

local function IsSpellNameCachePaused()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        return true
    end
    return false
end

local function StopSpellNameCacheScan(keepBuilding)
    nameCacheRuntime.running = false
    local ticker = nameCacheRuntime.ticker
    nameCacheRuntime.ticker = nil
    if ticker and ticker.Cancel then
        pcall(ticker.Cancel, ticker)
    end
    local cache = nameCacheRuntime.cache
    if cache and keepBuilding ~= true then
        cache.building = false
    end
end

local function FinishSpellNameCache(cache)
    cache.complete = true
    cache.building = false
    cache.finishedAt = GetSpellNameCacheTime()
    cache.updatedAt = cache.finishedAt
    StopSpellNameCacheScan()
    DebugSpellNameCache("SpellNameCache | complete" .. FormatSpellNameCacheDebugSuffix(cache))
end

local function ProcessSpellNameCache(cache)
    if not cache or cache.complete or cache.error then
        StopSpellNameCacheScan()
        return
    end

    local budgetMS, fallbackIDsPerFrame, minCheckIDs = GetSpellNameCacheBudget()
    local holes = GetSpellNameCacheHoles()
    local startTime = debugprofilestop and debugprofilestop() or nil
    local processed = 0
    local lastID = SafeNumberValue(cache.lastID) or 0
    local misses = SafeNumberValue(cache.misses) or 0
    local spellGetInfo = Spell.GetInfo
    local spellGetTexture = Spell.GetTexture
    local pcallFunc = pcall

    while misses < SPELL_NAME_CACHE_MAX_MISSES do
        local spellID = lastID + 1
        local jumpID = holes and holes[spellID]
        if jumpID and jumpID > spellID then
            spellID = jumpID
        end

        local ok, info = pcallFunc(spellGetInfo, spellID)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            local icon = info.originalIconID or info.iconID
            if not icon and spellGetTexture then
                local iconOK, iconValue = pcallFunc(spellGetTexture, spellID)
                icon = iconOK and iconValue or nil
            end
            local iconID = SafeNumberValue(icon)
            if iconID == SPELL_NAME_CACHE_GEAR_ICON then
                misses = 0
            elseif (iconID and iconID > 0) or (iconID == nil and type(icon) == "string" and icon ~= "") then
                AddSpellNameCacheRecord(cache, info.name, spellID, icon)
                misses = 0
            else
                misses = misses + 1
            end
        else
            misses = misses + 1
        end

        lastID = spellID
        processed = processed + 1

        if cache.error then
            break
        end

        if startTime then
            if processed >= minCheckIDs and (debugprofilestop() - startTime) >= budgetMS then
                break
            end
        elseif processed >= fallbackIDsPerFrame then
            break
        end
    end

    cache.lastID = lastID
    cache.misses = misses
    cache.building = cache.error == nil
    cache.updatedAt = GetSpellNameCacheTime()
    local elapsedMS = startTime and math.max(0, debugprofilestop() - startTime) or 0
    nameCacheRuntime.batches = (nameCacheRuntime.batches or 0) + 1
    nameCacheRuntime.scannedIDs = (nameCacheRuntime.scannedIDs or 0) + processed
    nameCacheRuntime.totalMs = (nameCacheRuntime.totalMs or 0) + elapsedMS
    nameCacheRuntime.maxBatchMs = math.max(nameCacheRuntime.maxBatchMs or 0, elapsedMS)

    if cache.error then
        StopSpellNameCacheScan()
    elseif misses >= SPELL_NAME_CACHE_MAX_MISSES then
        FinishSpellNameCache(cache)
    end
end

local StartSpellNameCacheScan

local function SpellNameCacheTickerCallback()
    local cache = EnsureSpellNameCacheStorage(false)
    if not cache or CountSpellNameCacheOwners() <= 0 then
        StopSpellNameCacheScan()
        return
    end
    if IsSpellNameCachePaused() then
        nameCacheRuntime.paused = true
        StopSpellNameCacheScan(true)
        return
    end
    local cpuWatchdog = YUI.CPUWatchdog
    local cpuStartedAt = cpuWatchdog and cpuWatchdog.timingActive and cpuWatchdog:BeginProbeTiming()
    ProcessSpellNameCache(cache)
    if cpuStartedAt then cpuWatchdog:EndProbeTiming("core.spell-name-cache", cpuStartedAt) end
end

local function OnSpellNameCacheCombatEvent(eventOrOwner, maybeEvent)
    local event = type(eventOrOwner) == "string" and eventOrOwner or maybeEvent
    if event == "PLAYER_REGEN_DISABLED" then
        nameCacheRuntime.paused = CountSpellNameCacheOwners() > 0
        StopSpellNameCacheScan(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        nameCacheRuntime.paused = false
        local cache = EnsureSpellNameCacheStorage(false)
        if cache and CountSpellNameCacheOwners() > 0 and not cache.complete and not cache.error then
            StartSpellNameCacheScan(cache)
        end
    end
end

local function EnsureSpellNameCacheCombatEvents()
    if nameCacheRuntime.eventsRegistered or not (YUI.Event and YUI.Event.On) then return end
    YUI.Event:On("PLAYER_REGEN_DISABLED", OnSpellNameCacheCombatEvent, nameCacheRuntime.eventOwner)
    YUI.Event:On("PLAYER_REGEN_ENABLED", OnSpellNameCacheCombatEvent, nameCacheRuntime.eventOwner)
    nameCacheRuntime.eventsRegistered = true
end

local function ReleaseSpellNameCacheCombatEvents()
    if nameCacheRuntime.eventsRegistered and YUI.Event and YUI.Event.OffOwner then
        YUI.Event:OffOwner(nameCacheRuntime.eventOwner)
    end
    nameCacheRuntime.eventsRegistered = false
    nameCacheRuntime.paused = false
end

StartSpellNameCacheScan = function(cache)
    if not cache or cache.complete then
        return cache ~= nil
    end
    if CountSpellNameCacheOwners() <= 0 then
        return false, "no-owner"
    end
    if IsSpellNameCachePaused() then
        cache.building = true
        nameCacheRuntime.paused = true
        EnsureSpellNameCacheCombatEvents()
        return true, "paused"
    end
    if nameCacheRuntime.running and nameCacheRuntime.ticker then
        cache.building = true
        return true, "running"
    end
    if not (C_Timer and C_Timer.NewTicker) then
        return false, "no-timer"
    end
    EnsureSpellNameCacheCombatEvents()
    nameCacheRuntime.paused = false
    cache.building = true
    nameCacheRuntime.running = true
    local ok, ticker = pcall(C_Timer.NewTicker, SPELL_NAME_CACHE_TICK_INTERVAL, SpellNameCacheTickerCallback)
    if not ok or not ticker then
        nameCacheRuntime.running = false
        cache.building = false
        return false, "timer-failed"
    end
    nameCacheRuntime.ticker = ticker
    return true, nil
end

local function CancelSpellNameCacheReleaseTimer()
    local timer = nameCacheRuntime.releaseTimer
    if timer and timer.Cancel then
        pcall(timer.Cancel, timer)
    end
    nameCacheRuntime.releaseTimer = nil
    nameCacheRuntime.releasePending = false
    nameCacheRuntime.releaseReason = nil
    nameCacheRuntime.releaseAt = nil
end

local function ScheduleSpellNameCacheRelease(delay, reason)
    if CountSpellNameCacheOwners() > 0 then
        CancelSpellNameCacheReleaseTimer()
        return false, "has-owner"
    end

    CancelSpellNameCacheReleaseTimer()
    delay = tonumber(delay) or SPELL_NAME_CACHE_DEFAULT_RELEASE_DELAY
    if delay < 0 then delay = 0 end

    nameCacheRuntime.releaseReason = reason or "release"
    if delay <= 0 or not (C_Timer and C_Timer.NewTimer) then
        Spell.ReleaseNameCache(nameCacheRuntime.releaseReason)
        return true, "immediate"
    end

    nameCacheRuntime.releasePending = true
    nameCacheRuntime.releaseAt = GetSpellNameCacheTime() + delay
    nameCacheRuntime.releaseTimer = C_Timer.NewTimer(delay, function()
        nameCacheRuntime.releaseTimer = nil
        if CountSpellNameCacheOwners() > 0 then
            nameCacheRuntime.releasePending = false
            nameCacheRuntime.releaseReason = nil
            nameCacheRuntime.releaseAt = nil
            return
        end
        Spell.ReleaseNameCache(nameCacheRuntime.releaseReason or reason or "release-timer")
    end)
    return true, "scheduled"
end

function Spell.SetNameCachePriority(priority)
    SetSpellNameCachePriority(priority)
    return true
end

function Spell.AcquireNameCacheOwner(owner, opts)
    owner = tostring(owner or "unknown")
    opts = type(opts) == "table" and opts or {}
    nameCacheRuntime.owners = nameCacheRuntime.owners or {}
    nameCacheRuntime.owners[owner] = true
    EnsureSpellNameCacheCombatEvents()
    CancelSpellNameCacheReleaseTimer()
    if opts.priority ~= nil then
        SetSpellNameCachePriority(opts.priority)
    end

    local status = Spell.GetNameCacheStatus()
    return status
end

function Spell.ReleaseNameCacheOwner(owner, opts)
    owner = tostring(owner or "unknown")
    opts = type(opts) == "table" and opts or {}
    local owners = nameCacheRuntime.owners
    if type(owners) == "table" then
        owners[owner] = nil
    end

    local delay = opts.delay
    if delay == nil then delay = SPELL_NAME_CACHE_DEFAULT_RELEASE_DELAY end
    local release = opts.release ~= false
    if CountSpellNameCacheOwners() <= 0 then
        StopSpellNameCacheScan()
        ReleaseSpellNameCacheCombatEvents()
        if release then
            ScheduleSpellNameCacheRelease(delay, opts.reason or owner or "owner-release")
        end
    end
    return Spell.GetNameCacheStatus()
end

function Spell.ReleaseNameCache(reason, opts)
    opts = type(opts) == "table" and opts or {}
    if CountSpellNameCacheOwners() > 0 and opts.force ~= true then
        return nil, "has-owner"
    end

    local cache = nameCacheRuntime.cache
    local nameCount = cache and cache.nameCount or 0
    local recordCount = cache and cache.recordCount or 0
    local lastID = cache and cache.lastID or 0
    local timer = nameCacheRuntime.releaseTimer
    if timer and timer.Cancel then
        pcall(timer.Cancel, timer)
    end
    StopSpellNameCacheScan()
    ReleaseSpellNameCacheCombatEvents()
    nameCacheRuntime.cache = nil
    nameCacheRuntime.lowerIndex = nil
    nameCacheRuntime.lowerIndexSource = nil
    nameCacheRuntime.ticker = nil
    nameCacheRuntime.releaseTimer = nil
    nameCacheRuntime.releasePending = false
    nameCacheRuntime.releaseReason = nil
    nameCacheRuntime.releaseAt = nil
    nameCacheRuntime.priority = SPELL_NAME_CACHE_PRIORITY_BACKGROUND

    local memoryKB = GetSpellNameCacheMemoryKB()
    local message = string.format(
        "SpellNameCache | released reason=%s names=%s records=%s lastID=%s ownerCount=%d",
        tostring(reason or "release"),
        tostring(nameCount),
        tostring(recordCount),
        tostring(lastID),
        CountSpellNameCacheOwners()
    )
    if memoryKB then
        message = message .. string.format(" mem=%dKB", memoryKB)
    end
    DebugSpellNameCache(message)
    return {
        released = true,
        reason = reason,
        nameCount = nameCount,
        recordCount = recordCount,
        lastID = lastID,
        memoryKB = memoryKB,
    }
end

function Spell.EnsureNameCache(options)
    if type(options) == "table" and options.priority ~= nil then
        SetSpellNameCachePriority(options.priority)
    end

    if CountSpellNameCacheOwners() <= 0 then
        return nil, "no-owner"
    end

    local cache, reason = EnsureSpellNameCacheStorage()
    if not cache then
        return nil, reason
    end

    if cache.complete or cache.error then
        DebugSpellNameCache("SpellNameCache | reuse status=" .. GetSpellNameCacheState(cache) .. FormatSpellNameCacheDebugSuffix(cache))
        return Spell.GetNameCacheStatus()
    end

    local started, startReason = StartSpellNameCacheScan(cache)
    if not started then
        return nil, startReason
    end
    if startReason == "running" then
        DebugSpellNameCache("SpellNameCache | reuse status=building" .. FormatSpellNameCacheDebugSuffix(cache))
    else
        DebugSpellNameCache(string.format(
            "SpellNameCache | start reason=%s locale=%s build=%s",
            tostring(type(options) == "table" and options.reason or "ensure"),
            tostring(cache.locale),
            tostring(cache.build)
        ))
    end
    return Spell.GetNameCacheStatus()
end

function Spell.GetNameCacheStatus()
    local cache, reason = EnsureSpellNameCacheStorage(false)
    if not cache then
        return {
            available = false,
            reason = reason,
            complete = false,
            building = false,
            state = "idle",
            progress = 0,
            currentID = 0,
            estimatedMaxID = SPELL_NAME_CACHE_ESTIMATED_MAX_ID,
            nameCount = 0,
            recordCount = 0,
            priority = NormalizeSpellNameCachePriority(nameCacheRuntime.priority),
            ownerCount = CountSpellNameCacheOwners(),
            releasePending = nameCacheRuntime.releasePending == true,
            releaseAt = nameCacheRuntime.releaseAt,
            running = false,
            paused = false,
            batches = nameCacheRuntime.batches or 0,
            scannedIDs = nameCacheRuntime.scannedIDs or 0,
            totalMs = nameCacheRuntime.totalMs or 0,
            maxBatchMs = nameCacheRuntime.maxBatchMs or 0,
        }
    end

    local currentID = SafeNumberValue(cache.lastID) or 0
    local progress = currentID / SPELL_NAME_CACHE_ESTIMATED_MAX_ID
    if progress < 0 then progress = 0 end
    if progress > 0.99 and not cache.complete then progress = 0.99 end
    if cache.complete then progress = 1 end

    return {
        available = true,
        reason = nil,
        complete = cache.complete == true,
        building = cache.building == true,
        state = GetSpellNameCacheState(cache),
        running = nameCacheRuntime.running == true,
        paused = nameCacheRuntime.paused == true,
        progress = progress,
        currentID = currentID,
        estimatedMaxID = SPELL_NAME_CACHE_ESTIMATED_MAX_ID,
        misses = cache.misses or 0,
        nameCount = cache.nameCount or 0,
        recordCount = cache.recordCount or 0,
        build = cache.build,
        locale = cache.locale,
        cacheVersion = cache.cacheVersion,
        error = cache.error,
        priority = NormalizeSpellNameCachePriority(nameCacheRuntime.priority),
        ownerCount = CountSpellNameCacheOwners(),
        releasePending = nameCacheRuntime.releasePending == true,
        releaseAt = nameCacheRuntime.releaseAt,
        batches = nameCacheRuntime.batches or 0,
        scannedIDs = nameCacheRuntime.scannedIDs or 0,
        totalMs = nameCacheRuntime.totalMs or 0,
        maxBatchMs = nameCacheRuntime.maxBatchMs or 0,
    }
end

local cpuWatchdog = YUI.CPUWatchdog
if cpuWatchdog and cpuWatchdog.RegisterProbe then
    cpuWatchdog:RegisterProbe("core.spell-name-cache", {
        localeKey = "cpu_watch.probe.spell_cache",
        kind = "function",
        target = SpellNameCacheTickerCallback,
        snapshot = Spell.GetNameCacheStatus,
        activityFields = { "batches", "scannedIDs" },
        minCPU = 1,
    })
end

function Spell.ResolveNameFromCache(name)
    local normalized = NormalizeSpellNameCacheLookup(name)
    if not normalized then
        return nil, nil, nil
    end

    local cache = EnsureSpellNameCacheStorage()
    if not cache or type(cache.spells) ~= "table" then
        return nil, nil, nil
    end

    local cacheName = name
    local records = cache.spells[name]
    if not records then
        local lowerIndex = GetSpellNameCacheLowerIndex(cache)
        cacheName = lowerIndex and lowerIndex[normalized] or nil
        records = cacheName and cache.spells[cacheName] or nil
    end
    if not records then
        return nil, nil, nil
    end

    local spellID, icon = ReadSpellNameCacheRecord(records)
    return spellID, icon, cacheName
end

function Spell.SearchNameCache(query, opts)
    opts = type(opts) == "table" and opts or {}
    local result = {
        available = false,
        complete = false,
        building = false,
        total = 0,
        truncated = false,
    }
    local normalized = NormalizeSpellNameCacheLookup(query)
    if not normalized then
        return result
    end

    if opts.priority ~= nil and nameCacheRuntime.running then
        SetSpellNameCachePriority(opts.priority)
    end

    local cache = EnsureSpellNameCacheStorage()
    local status = Spell.GetNameCacheStatus()
    result.available = status and status.available == true
    result.complete = status and status.complete == true
    result.building = status and status.building == true
    result.progress = status and status.progress or 0
    result.status = status

    if not cache or type(cache.spells) ~= "table" then
        return result
    end

    local limit = math.min(math.max(tonumber(opts.limit) or 40, 1), 200)
    local exact = opts.exact == true
    for name, records in pairs(cache.spells) do
        local normalizedName = NormalizeSpellNameCacheLookup(name)
        if normalizedName and (normalizedName == normalized or (not exact and normalizedName:find(normalized, 1, true))) then
            local spellID, icon = ReadSpellNameCacheRecord(records)
            result.total = result.total + 1
            if spellID and #result < limit then
                result[#result + 1] = {
                    spellID = spellID,
                    icon = icon,
                    name = name,
                }
            end
            if opts.stopAfterLimit == true and result.total > limit then
                result.truncated = true
                break
            end
        end
    end
    result.truncated = result.total > #result
    return result
end

function Spell.CreateNameCacheSearchJob(query, opts)
    opts = type(opts) == "table" and opts or {}
    if opts.priority ~= nil and nameCacheRuntime.running then
        SetSpellNameCachePriority(opts.priority)
    end

    local normalized = NormalizeSpellNameCacheLookup(query)
    local cache = EnsureSpellNameCacheStorage()
    local status = Spell.GetNameCacheStatus()
    local result = {
        available = status and status.available == true,
        complete = status and status.complete == true,
        building = status and status.building == true,
        progress = status and status.progress or 0,
        status = status,
        total = 0,
        truncated = false,
        searchComplete = true,
        scanned = 0,
    }
    if not normalized or not cache or type(cache.spells) ~= "table" then
        return {
            complete = true,
            result = result,
            Step = function(self)
                return true, self.result
            end,
        }
    end

    local limit = math.min(math.max(tonumber(opts.limit) or 40, 1), 200)
    local exact = opts.exact == true
    local stopAfterLimit = opts.stopAfterLimit ~= false
    local cursorKey = nil
    local done = false
    result.searchComplete = false

    local job = {
        complete = false,
        result = result,
    }

    function job:Step(stepOpts)
        if done then
            self.complete = true
            result.searchComplete = true
            return true, result
        end
        stepOpts = type(stepOpts) == "table" and stepOpts or {}
        local budgetMS = tonumber(stepOpts.budgetMS)
        local minEntries = tonumber(stepOpts.minEntries) or 64
        local maxEntries = tonumber(stepOpts.maxEntries)
        local startTime = budgetMS and debugprofilestop and debugprofilestop() or nil
        local processed = 0

        while true do
            local name, records = next(cache.spells, cursorKey)
            cursorKey = name
            if name == nil then
                done = true
                break
            end
            processed = processed + 1
            local normalizedName = NormalizeSpellNameCacheLookup(name)
            if normalizedName and (normalizedName == normalized or (not exact and normalizedName:find(normalized, 1, true))) then
                local spellID, icon = ReadSpellNameCacheRecord(records)
                result.total = result.total + 1
                if spellID and #result < limit then
                    result[#result + 1] = {
                        spellID = spellID,
                        icon = icon,
                        name = name,
                    }
                end
                if stopAfterLimit and result.total > limit then
                    result.truncated = true
                    done = true
                    break
                end
            end

            if maxEntries and processed >= maxEntries then
                break
            end
            if startTime and processed >= minEntries and (debugprofilestop() - startTime) >= budgetMS then
                break
            end
        end

        result.scanned = (result.scanned or 0) + processed
        result.searchComplete = done
        self.complete = done
        if not stopAfterLimit then
            result.truncated = result.total > #result
        end
        return done, result
    end

    return job
end

if YUI.Event and YUI.Event.On then
    YUI.Event:On("YUI_DB_READY", CleanupPersistentSpellNameCache, Spell, { priority = 7900 })
end
if YUI.Lifecycle and YUI.Lifecycle.IsReady and YUI.Lifecycle:IsReady("YUI_DB_READY") then
    CleanupPersistentSpellNameCache()
end

local function HasRangeFromCSpell(spellID)
    if C_Spell and C_Spell.SpellHasRange then
        local ok, result = pcall(C_Spell.SpellHasRange, spellID)
        if ok then
            return SafeBooleanValue(result, nil)
        end
    end
    return nil
end

local function HasRangeFromGlobal(spellID)
    if SpellHasRange then
        local ok, result = pcall(SpellHasRange, spellID)
        if ok then
            local normalized = SafeBooleanValue(result, nil)
            if normalized ~= nil then
                return normalized
            end
        end

        local name = Spell.GetName and Spell.GetName(spellID)
        if name then
            ok, result = pcall(SpellHasRange, name)
            if ok then
                return SafeBooleanValue(result, nil)
            end
        end
    end
    return nil
end

function Spell.HasRange(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        local result = HasRangeFromCSpell(spellID)
        if result ~= nil then return result end
        return HasRangeFromGlobal(spellID)
    end

    local result = HasRangeFromGlobal(spellID)
    if result ~= nil then return result end
    return HasRangeFromCSpell(spellID)
end

local function IsInRangeFromCSpell(spellID, unit)
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, result = pcall(C_Spell.IsSpellInRange, spellID, unit)
        if ok then
            return SafeBooleanValue(result, nil)
        end
    end
    return nil
end

local function IsInRangeFromGlobal(spellID, unit)
    if IsSpellInRange then
        local ok, result = pcall(IsSpellInRange, spellID, unit)
        if ok then
            local normalized = SafeBooleanValue(result, nil)
            if normalized ~= nil then
                return normalized
            end
        end

        local name = Spell.GetName and Spell.GetName(spellID)
        if name then
            ok, result = pcall(IsSpellInRange, name, unit)
            if ok then
                return SafeBooleanValue(result, nil)
            end
        end
    end
    return nil
end

function Spell.IsInRange(spellID, unit)
    if not spellID then return nil end
    unit = unit or "target"

    if YUI.IsRetail then
        local result = IsInRangeFromCSpell(spellID, unit)
        if result ~= nil then return result end
        return IsInRangeFromGlobal(spellID, unit)
    end

    local result = IsInRangeFromGlobal(spellID, unit)
    if result ~= nil then return result end
    return IsInRangeFromCSpell(spellID, unit)
end

local function NormalizeCooldown(startTime, duration, isEnabled, modRate)
    if IsSecretValue(startTime) then
        return nil
    end

    if type(startTime) == "table" then
        local info = startTime
        local safeStart = FirstSafeNumberValue(info.startTime, info.startTimeSeconds)
        local safeDuration = FirstSafeNumberValue(info.duration, info.durationSeconds)
        if safeStart == nil or safeDuration == nil then
            return nil
        end

        return {
            startTime = safeStart,
            duration = safeDuration,
            isEnabled = FirstSafeBooleanValue(true, info.isEnabled, info.enable, info.enableCooldownTimer),
            modRate = FirstSafeNumberValue(info.modRate) or 1,
        }
    end

    if IsSecretValue(duration) then
        return nil
    end

    if FirstSafeRawValue(startTime, duration, isEnabled, modRate) == nil then
        return nil
    end

    return {
        startTime = SafeNumberValue(startTime) or 0,
        duration = SafeNumberValue(duration) or 0,
        isEnabled = SafeBooleanValue(isEnabled, true),
        modRate = SafeNumberValue(modRate) or 1,
    }
end

local function GetCooldownFromCSpell(spellID)
    if not C_Spell or not C_Spell.GetSpellCooldown then return nil end
    local ok, startTime, duration, isEnabled, modRate = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok then
        return NormalizeCooldown(startTime, duration, isEnabled, modRate)
    end
    return nil
end

local function GetCooldownFromGlobal(spellID)
    if not GetSpellCooldown then return nil end
    local ok, startTime, duration, isEnabled, modRate = pcall(GetSpellCooldown, spellID)
    if ok then
        return NormalizeCooldown(startTime, duration, isEnabled, modRate)
    end
    return nil
end

function Spell.GetCooldown(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        return GetCooldownFromCSpell(spellID) or GetCooldownFromGlobal(spellID)
    end

    if YUI.IsMists then
        return GetCooldownFromGlobal(spellID) or GetCooldownFromCSpell(spellID)
    end

    if YUI.IsWrath then
        return GetCooldownFromGlobal(spellID) or GetCooldownFromCSpell(spellID)
    end

    return GetCooldownFromGlobal(spellID) or GetCooldownFromCSpell(spellID)
end

function Spell.GetCooldownDurationObject(spellID, ignoreGCD)
    spellID = SafeNumberValue(spellID)
    if not (spellID and C_Spell and C_Spell.GetSpellCooldownDuration) then
        return nil
    end

    local ok, durationObject
    if ignoreGCD ~= nil then
        ok, durationObject = pcall(
            C_Spell.GetSpellCooldownDuration,
            spellID,
            ignoreGCD == true
        )
        if not ok then
            ok, durationObject = pcall(C_Spell.GetSpellCooldownDuration, spellID)
        end
    else
        ok, durationObject = pcall(C_Spell.GetSpellCooldownDuration, spellID)
    end
    if ok then
        return durationObject
    end
    return nil
end

function Spell.GetChargeDurationObject(spellID)
    spellID = SafeNumberValue(spellID)
    if not (spellID and C_Spell and C_Spell.GetSpellChargeDuration) then
        return nil
    end

    local ok, durationObject = pcall(C_Spell.GetSpellChargeDuration, spellID)
    if ok then
        return durationObject
    end
    return nil
end

local function ReadDurationObjectMethod(durationObject, methodName)
    if durationObject == nil or type(methodName) ~= "string" then
        return nil, false
    end
    local ok, value = pcall(function()
        local method = durationObject[methodName]
        if type(method) ~= "function" then
            return nil
        end
        return method(durationObject)
    end)
    if ok then
        return value, true
    end
    return nil, false
end

function Spell.GetCooldownDurationState(spellID)
    spellID = SafeNumberValue(spellID)
    if not spellID then
        return {
            ready = nil,
            remainingSeconds = nil,
            durationObject = nil,
            readyRaw = nil,
            reason = "no-spell",
            source = "duration-object",
        }
    end

    local durationObject = Spell.GetCooldownDurationObject(spellID)
    if not durationObject then
        return {
            ready = nil,
            remainingSeconds = nil,
            durationObject = nil,
            readyRaw = nil,
            reason = "no-duration-object",
            source = "duration-object",
        }
    end

    local readyRaw, readyRawOK = ReadDurationObjectMethod(durationObject, "IsZero")
    local ready = readyRawOK and SafeBooleanValue(readyRaw, nil) or nil
    local remainingRaw, remainingOK = ReadDurationObjectMethod(durationObject, "GetRemainingDuration")
    local remaining = remainingOK and SafeNumberValue(remainingRaw) or nil

    local reason = "unknown"
    if ready == true then
        remaining = 0
        reason = "ready"
    elseif ready == false then
        reason = "cooldown"
    elseif remaining ~= nil then
        if remaining > 0 then
            ready = false
            reason = "cooldown"
        else
            ready = true
            remaining = 0
            reason = "ready"
        end
    elseif readyRawOK == false then
        reason = "no-iszero"
    elseif remainingOK == false then
        reason = "no-remaining"
    end

    return {
        ready = ready,
        remainingSeconds = remaining,
        durationObject = durationObject,
        readyRaw = readyRaw,
        readyRawOK = readyRawOK,
        remainingRaw = remainingRaw,
        remainingRawOK = remainingOK,
        reason = reason,
        source = "duration-object",
    }
end

local function EnsureCooldownProbe(spellID)
    if not UIParent or not CreateFrame then
        return nil, "no-ui"
    end

    if not cooldownProbeHost then
        cooldownProbeHost = CreateFrame("Frame", nil, UIParent)
        cooldownProbeHost:SetSize(1, 1)
        cooldownProbeHost:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -8, -8)
        cooldownProbeHost:SetAlpha(0)
        cooldownProbeHost:EnableMouse(false)
        cooldownProbeHost:Show()
    end

    local probe = cooldownProbes[spellID]
    if probe then
        cooldownProbeHost:Show()
        return probe
    end

    local cooldown = CreateFrame("Cooldown", nil, cooldownProbeHost, "CooldownFrameTemplate")
    cooldown:SetAllPoints(cooldownProbeHost)
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(false) end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
    cooldown:SetAlpha(0)
    cooldown:EnableMouse(false)
    probe = {
        spellID = spellID,
        cooldown = cooldown,
    }
    cooldownProbes[spellID] = probe
    return probe
end

local function ReadRetailCooldownInfo(spellID)
    if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and type(info) == "table" then
        return info
    end
    return nil
end

function Spell.ReadCooldownRuleState(spellID)
    spellID = SafeNumberValue(spellID)
    if not (spellID and YUI.IsRetail) then return false, false end

    local info = ReadRetailCooldownInfo(spellID)
    if not info then return false, false end

    local isActive = info.isActive
    if IsSecretValue(isActive) or type(isActive) ~= "boolean" then
        return false, false
    end

    local isOnGCD = info.isOnGCD
    if IsSecretValue(isOnGCD)
        or (isOnGCD ~= nil and type(isOnGCD) ~= "boolean") then
        return false, false
    end

    return isActive and isOnGCD ~= true, true
end

local function ReadRetailChargeInfo(spellID)
    if not (C_Spell and C_Spell.GetSpellCharges) then return nil end
    local ok, info = pcall(C_Spell.GetSpellCharges, spellID)
    if ok and type(info) == "table" then
        return info
    end
    return nil
end

local function AddChargeSpellCandidate(candidates, count, spellID)
    spellID = SafeNumberValue(spellID)
    if not spellID or spellID <= 0 then return count end
    for index = 1, count do
        if candidates[index] == spellID then return count end
    end
    count = count + 1
    candidates[count] = spellID
    return count
end

function Spell.GetOverrideSpellID(spellID, specID, onlyKnown)
    spellID = SafeNumberValue(spellID)
    if not spellID or spellID <= 0 then return nil end
    if YUI.IsRetail == false then return spellID end

    specID = SafeNumberValue(specID) or 0
    if C_Spell and C_Spell.GetOverrideSpell then
        local ok, overrideSpellID = pcall(
            C_Spell.GetOverrideSpell,
            spellID,
            specID,
            onlyKnown ~= false
        )
        overrideSpellID = ok and SafeNumberValue(overrideSpellID) or nil
        if overrideSpellID and overrideSpellID > 0 then
            return overrideSpellID
        end
    end
    if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
        local ok, overrideSpellID = pcall(
            C_SpellBook.FindSpellOverrideByID,
            spellID
        )
        overrideSpellID = ok and SafeNumberValue(overrideSpellID) or nil
        if overrideSpellID and overrideSpellID > 0 then
            return overrideSpellID
        end
    end
    return spellID
end

local function BuildRetailChargeSpellCandidates(spellID, candidates)
    candidates = candidates or {}
    local count = 0
    if spellID and C_SpellBook and C_SpellBook.FindSpellOverrideByID then
        local ok, overrideSpellID = pcall(
            C_SpellBook.FindSpellOverrideByID,
            spellID
        )
        if ok then
            count = AddChargeSpellCandidate(
                candidates,
                count,
                overrideSpellID
            )
        end
    end
    count = AddChargeSpellCandidate(
        candidates,
        count,
        Spell.GetOverrideSpellID(spellID)
    )
    count = AddChargeSpellCandidate(candidates, count, spellID)
    for index = count + 1, #candidates do
        candidates[index] = nil
    end
    return candidates, count
end

function Spell.ReadChargeResourceDisplay(spellID, target)
    target = type(target) == "table" and target or {}
    spellID = SafeNumberValue(spellID)
    if not spellID then return target, false, "invalid-spell" end

    local candidates, candidateCount = BuildRetailChargeSpellCandidates(
        spellID,
        target.chargeSpellCandidates
    )
    target.chargeSpellCandidates = candidates
    local chargeSpellID = spellID
    local chargeInfo
    for index = 1, candidateCount do
        local candidate = candidates[index]
        local info = ReadRetailChargeInfo(candidate)
        if info ~= nil then
            chargeSpellID = candidate
            chargeInfo = info
            break
        end
    end
    local rechargeDurationRaw
    if chargeInfo ~= nil then
        rechargeDurationRaw = Spell.GetChargeDurationObject(chargeSpellID)
        if not rechargeDurationRaw then
            for index = 1, candidateCount do
                local candidate = candidates[index]
                if candidate ~= chargeSpellID then
                    rechargeDurationRaw =
                        Spell.GetChargeDurationObject(candidate)
                    if rechargeDurationRaw then break end
                end
            end
        end
    end
    local rechargeActive = rechargeDurationRaw and true or false
    local rawCurrentCharges = chargeInfo and chargeInfo.currentCharges
    local rawMaxCharges = chargeInfo and chargeInfo.maxCharges
    local currentSecret = IsSecretValue(rawCurrentCharges)
    local maxSecret = IsSecretValue(rawMaxCharges)
    local currentCharges = not currentSecret
        and SafeNumberValue(rawCurrentCharges) or nil
    local maxCharges = not maxSecret and SafeNumberValue(rawMaxCharges) or nil
    if maxCharges then
        maxCharges = math.floor(maxCharges + 0.5)
        if maxCharges < 1 or maxCharges > 20 then maxCharges = nil end
    end
    local structuralMax = maxCharges
        or SafeNumberValue(target.structuralMax)
        or SafeNumberValue(target.segmentCountFallback)
    if structuralMax then
        structuralMax = math.floor(structuralMax + 0.5)
        if structuralMax < 1 or structuralMax > 20 then structuralMax = nil end
    end
    local currentPresent = currentSecret or currentCharges ~= nil
    local available = chargeInfo ~= nil
        and currentPresent
        and structuralMax ~= nil
    local changed = target.sourceKind ~= "resource"
        or target.providerKind ~= "spell-charges"
        or target.spellID ~= spellID
        or target.chargeSpellID ~= chargeSpellID
        or target.available ~= available
        or target.rechargeActive ~= rechargeActive
        or target.secret ~= currentSecret
        or target.value ~= currentCharges
        or target.maxValue ~= structuralMax
        or target.structuralMax ~= structuralMax

    target.sourceKind = "resource"
    target.providerKind = "spell-charges"
    target.spellID = spellID
    target.chargeSpellID = chargeSpellID
    target.available = available
    target.rechargeActive = available and rechargeActive or false
    target.rechargeDurationRaw = available and rechargeDurationRaw or nil
    target.secret = currentSecret
    target.value = available and not currentSecret and currentCharges or nil
    target.maxValue = available and structuralMax or nil
    target.structuralMax = structuralMax
    target.valueRaw = nil
    if available then target.valueRaw = rawCurrentCharges end
    target.maxValueRaw = available and structuralMax or nil
    target.rawValuesAvailable = available
    if currentSecret then
        target.opaqueRevision = (target.opaqueRevision or 0) + 1
        changed = true
    end
    if available then return target, changed, nil end
    return target, changed, "charge-unavailable"
end

local function ReadRetailCastCount(spellID)
    if not (C_Spell and C_Spell.GetSpellCastCount) then return nil end
    local ok, count = pcall(C_Spell.GetSpellCastCount, spellID)
    if not ok then return nil end
    return SafeNumberValue(count), IsSecretValue(count), count
end

local singleUseCountCurve
local singleUseCountCurveUnavailable
local function FilterSingleUseCountRaw(value)
    if value == nil then return nil end
    if singleUseCountCurveUnavailable then return nil end
    if not singleUseCountCurve then
        if not (C_CurveUtil and C_CurveUtil.CreateCurve) then
            singleUseCountCurveUnavailable = true
            return nil
        end
        local ok, curve = pcall(C_CurveUtil.CreateCurve)
        if not ok or not curve or not curve.AddPoint or not curve.Evaluate then
            singleUseCountCurveUnavailable = true
            return nil
        end
        if curve.SetType and Enum and Enum.LuaCurveType then
            pcall(curve.SetType, curve, Enum.LuaCurveType.Linear)
        end
        local pointsOK = pcall(curve.AddPoint, curve, 0, 0)
            and pcall(curve.AddPoint, curve, 1, 0)
            and pcall(curve.AddPoint, curve, 2, 2)
            and pcall(curve.AddPoint, curve, 9999, 9999)
        if not pointsOK then
            singleUseCountCurveUnavailable = true
            return nil
        end
        singleUseCountCurve = curve
    end
    local ok, filtered = pcall(
        singleUseCountCurve.Evaluate,
        singleUseCountCurve,
        value
    )
    return ok and filtered or nil
end

function Spell.ReadCastCountResourceDisplay(spellID, target)
    target = type(target) == "table" and target or {}
    spellID = SafeNumberValue(spellID)
    if not spellID then return target, false, "invalid-spell" end

    local value, secret, valueRaw = ReadRetailCastCount(spellID)
    local available = valueRaw ~= nil
    local changed = target.sourceKind ~= "resource"
        or target.providerKind ~= "spell-count"
        or target.spellID ~= spellID
        or target.available ~= available
        or target.secret ~= (secret == true)
        or target.value ~= value

    target.sourceKind = "resource"
    target.providerKind = "spell-count"
    target.spellID = spellID
    target.available = available
    target.secret = secret == true
    target.value = available and value or nil
    target.valueRaw = available and valueRaw or nil
    target.rawValuesAvailable = available
    if secret then
        target.opaqueRevision = (target.opaqueRevision or 0) + 1
        changed = true
    end
    if available then return target, changed, nil end
    return target, changed, "cast-count-unavailable"
end

local function ReadRetailActivationOverlay(spellID)
    local overlay = _G.C_SpellActivationOverlay
    if not (overlay and overlay.IsSpellOverlayed) then return false end
    local ok, active = pcall(overlay.IsSpellOverlayed, spellID)
    if not ok then return false end
    return SafeBooleanValue(active, false) == true
end

function Spell.ReadActivationOverlay(spellID, target)
    target = type(target) == "table" and target or {}
    spellID = SafeNumberValue(spellID)
    if not spellID then return target, false, "invalid-spell" end
    local activationOverlay = ReadRetailActivationOverlay(spellID)
    local changed = target.activationOverlay ~= activationOverlay
    target.activationOverlay = activationOverlay
    return target, changed
end

local function FinishCooldownDisplayRead(target, changed, durationObject, forceOpaque)
    target.opaqueRevision = target.opaqueRevision or 0
    if changed or durationObject ~= nil or forceOpaque == true then
        target.opaqueRevision = target.opaqueRevision + 1
        target.durationObject = durationObject
        return target, true
    end

    target.durationObject = nil
    target.displayCountRaw = nil
    return target, false
end

local function ReadCooldownDisplayCooldown(spellID, chargeSpellID, target)
    local cooldownInfo = ReadRetailCooldownInfo(spellID)
    local cooldownStateSecret = cooldownInfo
        and IsSecretValue(cooldownInfo.isActive)
        or false
    local isEnabled = cooldownInfo
        and SafeBooleanValue(cooldownInfo.isEnabled, true)
        or true
    local isOnGCD = cooldownInfo
        and SafeBooleanValue(cooldownInfo.isOnGCD, false)
        or false
    local cooldownActive = cooldownInfo
        and SafeBooleanValue(cooldownInfo.isActive, false)
        or false
    if isOnGCD then cooldownActive = false end

    local durationMode = "none"
    local durationObject
    local useChargeDuration = target.hasCharges == true
        and (target.chargeStateSecret == true
            or target.chargeActive == true)
    if useChargeDuration then
        durationObject = Spell.GetChargeDurationObject(chargeSpellID)
        if durationObject ~= nil then durationMode = "charge" end
    end
    if durationObject == nil and (cooldownActive or cooldownStateSecret) then
        durationObject = Spell.GetCooldownDurationObject(spellID, true)
        if durationObject ~= nil then durationMode = "cooldown" end
    end

    local changed = target.isEnabled ~= isEnabled
        or target.cooldownActive ~= cooldownActive
        or target.cooldownStateSecret ~= cooldownStateSecret
        or target.durationMode ~= durationMode
    target.isEnabled = isEnabled
    target.cooldownActive = cooldownActive
    target.cooldownStateSecret = cooldownStateSecret
    target.durationMode = durationMode
    target.displayCountRaw = nil
    return FinishCooldownDisplayRead(
        target,
        changed,
        durationObject,
        cooldownStateSecret
    )
end

local function ReadCooldownDisplayCharges(spellID, chargeSpellID, target)
    local chargeInfo = ReadRetailChargeInfo(chargeSpellID)
    if not chargeInfo then
        target.durationObject = nil
        target.displayCountRaw = nil
        return target, false
    end
    local rawMaxCharges = chargeInfo and chargeInfo.maxCharges
    local rawCurrentCharges = chargeInfo and chargeInfo.currentCharges
    local maxCharges = chargeInfo and SafeNumberValue(rawMaxCharges) or nil
    local currentCharges = chargeInfo and SafeNumberValue(rawCurrentCharges) or nil
    local hasCharges
    if maxCharges ~= nil then
        hasCharges = maxCharges > 1
    else
        hasCharges = target.hasChargesHint == true
            or target.hasCharges == true
    end
    if not hasCharges then
        if target.hasCharges ~= true then
            target.durationObject = nil
            target.displayCountRaw = nil
            return target, false
        end
        local displayCount = target.castCount
            and target.castCount > 1 and target.castCount or nil
        local durationMode = target.durationMode == "charge"
            and "none" or target.durationMode
        local changed = target.hasCharges ~= false
            or target.chargeActive ~= false
            or target.chargeStateSecret ~= false
            or target.chargeCountSecret ~= false
            or target.chargeMetadataSecret ~= false
            or target.currentCharges ~= nil
            or target.maxCharges ~= nil
            or target.displayCount ~= displayCount
            or target.countSecret ~= false
            or target.durationMode ~= durationMode
        target.hasCharges = false
        target.chargeActive = false
        target.chargeStateSecret = false
        target.chargeCountSecret = false
        target.chargeMetadataSecret = false
        target.currentCharges = nil
        target.maxCharges = nil
        target.displayCount = displayCount
        target.displayCountRaw = nil
        target.countSecret = false
        target.durationMode = durationMode
        return FinishCooldownDisplayRead(target, changed, nil, false)
    end

    local rawChargeActive = chargeInfo.isActive
    local chargeStateAvailable = rawChargeActive ~= nil
    local chargeActive = chargeStateAvailable
        and SafeBooleanValue(rawChargeActive, false)
        or target.chargeActive == true
    local chargeStateSecret
    if chargeStateAvailable then
        chargeStateSecret = IsSecretValue(rawChargeActive)
    else
        chargeStateSecret = target.chargeStateSecret == true
    end
    local countAvailable = rawCurrentCharges ~= nil
    local chargeCountSecret
    if countAvailable then
        chargeCountSecret = IsSecretValue(rawCurrentCharges)
    else
        chargeCountSecret = target.chargeCountSecret == true
    end
    local chargeMetadataSecret = IsSecretValue(rawMaxCharges)
    local nextCurrentCharges = countAvailable
        and currentCharges or target.currentCharges
    local nextMaxCharges = maxCharges or target.maxCharges
    local displayCount = target.displayCount
    local displayCountRaw
    if countAvailable then
        if chargeCountSecret then
            nextCurrentCharges = nil
            displayCount = nil
            displayCountRaw = rawCurrentCharges
        else
            displayCount = currentCharges
        end
    end
    local countSecret = chargeCountSecret

    local durationMode = target.durationMode or "none"
    local durationObject
    local useChargeDuration = chargeStateSecret or chargeActive
    if useChargeDuration then
        durationObject = Spell.GetChargeDurationObject(chargeSpellID)
        durationMode = durationObject ~= nil and "charge" or "none"
    elseif durationMode == "charge" then
        durationMode = "none"
    end

    local changed = target.hasCharges ~= true
        or target.chargeActive ~= chargeActive
        or target.chargeStateSecret ~= chargeStateSecret
        or target.chargeCountSecret ~= chargeCountSecret
        or target.chargeMetadataSecret ~= chargeMetadataSecret
        or target.currentCharges ~= nextCurrentCharges
        or target.maxCharges ~= nextMaxCharges
        or target.displayCount ~= displayCount
        or target.countSecret ~= countSecret
        or target.durationMode ~= durationMode
    target.hasCharges = true
    target.chargeActive = chargeActive
    target.chargeStateSecret = chargeStateSecret
    target.chargeCountSecret = chargeCountSecret
    target.chargeMetadataSecret = chargeMetadataSecret
    target.currentCharges = nextCurrentCharges
    target.maxCharges = nextMaxCharges
    target.displayCount = displayCount
    target.displayCountRaw = displayCountRaw
    target.countSecret = countSecret
    target.durationMode = durationMode
    return FinishCooldownDisplayRead(
        target,
        changed,
        durationObject,
        chargeStateSecret or chargeCountSecret or chargeMetadataSecret
    )
end

local function ReadCooldownDisplayUses(spellID, target)
    local castCount, castCountSecret, rawCastCount = ReadRetailCastCount(spellID)
    local displayCount
    local displayCountRaw
    if target.hasCharges == true then
        displayCount = target.displayCount
    elseif castCountSecret then
        displayCountRaw = FilterSingleUseCountRaw(rawCastCount)
    elseif castCount and castCount > 1 then
        displayCount = castCount
    end
    local countSecret
    if target.hasCharges == true then
        countSecret = target.chargeCountSecret == true
    else
        countSecret = castCountSecret
    end
    local changed = target.castCount ~= castCount
        or target.castCountSecret ~= castCountSecret
        or target.displayCount ~= displayCount
        or target.countSecret ~= countSecret
    target.castCount = castCount
    target.castCountSecret = castCountSecret
    target.displayCount = displayCount
    target.displayCountRaw = displayCountRaw
    target.countSecret = countSecret
    return FinishCooldownDisplayRead(target, changed, nil, castCountSecret)
end

local function ReadCooldownDisplayFull(
    spellID,
    chargeSpellID,
    target,
    hasCharges
)
    local info = Spell.GetInfo(spellID)
    local icon = Spell.GetTexture(spellID)
    local available = info ~= nil or icon ~= nil
    local cooldownInfo = ReadRetailCooldownInfo(spellID)
    local chargeInfo = ReadRetailChargeInfo(chargeSpellID)

    local cooldownStateSecret = cooldownInfo
        and IsSecretValue(cooldownInfo.isActive)
        or false
    local isEnabled = cooldownInfo
        and SafeBooleanValue(cooldownInfo.isEnabled, true)
        or true
    local isOnGCD = cooldownInfo
        and SafeBooleanValue(cooldownInfo.isOnGCD, false)
        or false
    local cooldownActive = cooldownInfo
        and SafeBooleanValue(cooldownInfo.isActive, false)
        or false
    if isOnGCD then cooldownActive = false end

    local rawMaxCharges = chargeInfo and chargeInfo.maxCharges
    local rawCurrentCharges = chargeInfo and chargeInfo.currentCharges
    local maxCharges = chargeInfo and SafeNumberValue(rawMaxCharges) or nil
    local currentCharges = chargeInfo and SafeNumberValue(rawCurrentCharges) or nil
    local hasChargesHint = hasCharges == true
    if maxCharges ~= nil then
        hasCharges = maxCharges > 1
    else
        hasCharges = hasChargesHint
    end
    local chargeActive = hasCharges and chargeInfo
        and SafeBooleanValue(chargeInfo.isActive, false)
        or false
    local chargeStateSecret = hasCharges and chargeInfo
        and IsSecretValue(chargeInfo.isActive)
        or false
    local chargeCountSecret = hasCharges
        and IsSecretValue(rawCurrentCharges) or false
    local chargeMetadataSecret = hasCharges
        and IsSecretValue(rawMaxCharges) or false
    if not hasCharges then
        maxCharges = nil
        currentCharges = nil
    end
    local castCount
    local castCountSecret = false
    local displayCount
    local displayCountRaw
    if hasCharges and chargeCountSecret then
        displayCountRaw = rawCurrentCharges
    elseif hasCharges then
        displayCount = currentCharges
    else
        local rawCastCount
        castCount, castCountSecret, rawCastCount = ReadRetailCastCount(spellID)
        if castCountSecret then
            displayCountRaw = FilterSingleUseCountRaw(rawCastCount)
        elseif castCount and castCount > 1 then
            displayCount = castCount
        end
    end
    local countSecret = chargeCountSecret or castCountSecret
    local activationOverlay = ReadRetailActivationOverlay(spellID)

    local durationMode = "none"
    local durationObject
    local useChargeDuration = hasCharges
        and (chargeStateSecret or chargeActive)
    if useChargeDuration then
        durationObject = Spell.GetChargeDurationObject(chargeSpellID)
        if durationObject ~= nil then durationMode = "charge" end
    end
    if durationObject == nil and (cooldownActive or cooldownStateSecret) then
        durationObject = Spell.GetCooldownDurationObject(spellID, true)
        if durationObject ~= nil then durationMode = "cooldown" end
    end

    local changed = target.cooldownDisplayInitialized ~= true
        or target.spellID ~= spellID
        or target.chargeSpellID ~= chargeSpellID
        or target.hasChargesHint ~= hasChargesHint
        or target.hasCharges ~= hasCharges
        or target.icon ~= icon
        or target.available ~= available
        or target.isEnabled ~= isEnabled
        or target.cooldownActive ~= cooldownActive
        or target.cooldownStateSecret ~= cooldownStateSecret
        or target.chargeActive ~= chargeActive
        or target.chargeStateSecret ~= chargeStateSecret
        or target.chargeCountSecret ~= chargeCountSecret
        or target.chargeMetadataSecret ~= chargeMetadataSecret
        or target.currentCharges ~= currentCharges
        or target.maxCharges ~= maxCharges
        or target.castCount ~= castCount
        or target.castCountSecret ~= castCountSecret
        or target.displayCount ~= displayCount
        or target.countSecret ~= countSecret
        or target.activationOverlay ~= activationOverlay
        or target.durationMode ~= durationMode

    target.sourceKind = "spell"
    target.spellID = spellID
    target.chargeSpellID = chargeSpellID
    target.hasChargesHint = hasChargesHint
    target.hasCharges = hasCharges
    target.icon = icon
    target.available = available
    target.isEnabled = isEnabled
    target.cooldownActive = cooldownActive
    target.cooldownStateSecret = cooldownStateSecret
    target.chargeActive = chargeActive
    target.chargeStateSecret = chargeStateSecret
    target.chargeCountSecret = chargeCountSecret
    target.chargeMetadataSecret = chargeMetadataSecret
    target.currentCharges = currentCharges
    target.maxCharges = maxCharges
    target.castCount = castCount
    target.castCountSecret = castCountSecret
    target.displayCount = displayCount
    target.displayCountRaw = displayCountRaw
    target.countSecret = countSecret
    target.activationOverlay = activationOverlay
    target.durationMode = durationMode
    target.secret = false
    target.cooldownDisplayInitialized = true
    return FinishCooldownDisplayRead(
        target,
        changed,
        durationObject,
        cooldownStateSecret or chargeStateSecret or chargeMetadataSecret
            or countSecret
    )
end

function Spell.ReadCooldownDisplay(
    spellID,
    target,
    reason,
    chargeSpellID,
    hasCharges
)
    target = type(target) == "table" and target or {}
    spellID = SafeNumberValue(spellID)
    if not spellID then
        target.durationObject = nil
        target.displayCountRaw = nil
        return target, false, "invalid-spell"
    end
    chargeSpellID = SafeNumberValue(chargeSpellID) or spellID
    hasCharges = hasCharges == true

    if target.cooldownDisplayInitialized == true
        and target.spellID == spellID
        and target.chargeSpellID == chargeSpellID
        and (hasCharges ~= true or target.hasChargesHint == true) then
        if reason == "spell-update"
            or reason == "spell-all"
            or reason == "spell-global" then
            return ReadCooldownDisplayCooldown(spellID, chargeSpellID, target)
        elseif reason == "spell-charge-all" then
            if target.hasChargesHint == true
                and target.hasCharges == false
                and target.chargeMetadataSecret ~= true then
                return ReadCooldownDisplayFull(
                    spellID,
                    chargeSpellID,
                    target,
                    hasCharges
                )
            end
            return ReadCooldownDisplayCharges(spellID, chargeSpellID, target)
        elseif reason == "spell-uses" then
            return ReadCooldownDisplayUses(spellID, target)
        end
    end
    return ReadCooldownDisplayFull(
        spellID,
        chargeSpellID,
        target,
        hasCharges
    )
end

local function IsGCDOnly(spellID)
    local info = ReadRetailCooldownInfo(spellID)
    if info and SafeBooleanValue(info.isOnGCD, nil) == true then
        return true
    end

    if spellID == GCD_SPELL_ID then
        return true
    end
    return false
end

function Spell.GetCooldownProbeState(spellID)
    spellID = SafeNumberValue(spellID)
    if not spellID then
        return {
            ready = nil,
            state = "unknown",
            reason = "no-spell",
            source = "native-cooldown-probe",
        }
    end

    if not YUI.IsRetail then
        local cd = Spell.GetCooldown(spellID)
        if type(cd) ~= "table" then
            return {
                ready = nil,
                state = "unknown",
                reason = "no-cooldown-api",
                source = "spell-api",
                spellID = spellID,
            }
        end
        local startTime = SafeNumberValue(cd.startTime)
        local duration = SafeNumberValue(cd.duration)
        local enabled = SafeBooleanValue(cd.isEnabled, true)
        if enabled == false or startTime == nil or duration == nil then
            return {
                ready = nil,
                state = "unknown",
                reason = enabled == false and "disabled" or "unsafe-values",
                source = "spell-api",
                spellID = spellID,
            }
        end
        if startTime <= 0 or duration <= 1.5 then
            return {
                ready = true,
                state = "ready",
                reason = "ready",
                source = "spell-api",
                spellID = spellID,
            }
        end
        local remaining = startTime + duration - GetTime()
        if remaining > 0 then
            return {
                ready = false,
                state = "cooldown",
                reason = "cooldown",
                source = "spell-api",
                spellID = spellID,
                remainingSeconds = remaining,
            }
        end
        return {
            ready = true,
            state = "ready",
            reason = "expired",
            source = "spell-api",
            spellID = spellID,
        }
    end

    local probe, probeReason = EnsureCooldownProbe(spellID)
    if not (probe and probe.cooldown) then
        return {
            ready = nil,
            state = "unknown",
            reason = probeReason or "no-probe",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end

    local cooldown = probe.cooldown
    if cooldown.Clear then
        pcall(cooldown.Clear, cooldown)
    end

    local cooldownInfo = ReadRetailCooldownInfo(spellID)
    if cooldownInfo and SafeBooleanValue(cooldownInfo.isOnGCD, nil) == true then
        probe.lastState = "ready"
        return {
            ready = true,
            state = "ready",
            reason = "gcd-only",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end
    if cooldownInfo and SafeBooleanValue(cooldownInfo.isActive, true) == false then
        probe.lastState = "ready"
        return {
            ready = true,
            state = "ready",
            reason = "inactive",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end
    if IsGCDOnly(spellID) then
        probe.lastState = "ready"
        return {
            ready = true,
            state = "ready",
            reason = "gcd-only",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end

    local durationObject = Spell.GetCooldownDurationObject(spellID)
    if not durationObject then
        return {
            ready = nil,
            state = "unknown",
            reason = "no-duration-object",
            source = "native-cooldown-probe",
            spellID = spellID,
        }
    end

    local setOK = false
    if cooldown.SetCooldownFromDurationObject then
        setOK = pcall(cooldown.SetCooldownFromDurationObject, cooldown, durationObject, true) == true
    end
    if not setOK then
        return {
            ready = nil,
            state = "unknown",
            reason = "set-failed",
            source = "native-cooldown-probe",
            spellID = spellID,
            durationObject = durationObject,
        }
    end

    local shown = cooldown.IsShown and cooldown:IsShown() == true
    local state = shown and "cooldown" or "ready"
    probe.lastState = state
    return {
        ready = not shown,
        state = state,
        reason = state,
        source = "native-cooldown-probe",
        spellID = spellID,
        durationObject = durationObject,
    }
end

function Spell.ClearCooldownProbe(spellID)
    spellID = SafeNumberValue(spellID)
    local probe = spellID and cooldownProbes[spellID] or nil
    if probe and probe.cooldown and probe.cooldown.Clear then
        pcall(probe.cooldown.Clear, probe.cooldown)
    end
    if probe then
        probe.lastState = nil
    end
end

local function GetMacroSpellID(macroID)
    macroID = SafeNumberValue(macroID)
    if not (macroID and GetMacroSpell) then return nil end

    local ok, _, _, spellID = pcall(GetMacroSpell, macroID)
    if ok then
        return SafeNumberValue(spellID)
    end
    return nil
end

function Spell.FindActionSlotForSpell(spellID, maxSlots)
    spellID = SafeNumberValue(spellID)
    if not (spellID and GetActionInfo) then
        return nil, "no-api"
    end

    maxSlots = SafeNumberValue(maxSlots) or DEFAULT_ACTION_SLOT_SCAN_MAX
    if maxSlots < 1 then maxSlots = DEFAULT_ACTION_SLOT_SCAN_MAX end

    for slot = 1, maxSlots do
        local shouldRead = true
        if HasAction then
            local ok, hasAction = pcall(HasAction, slot)
            hasAction = ok and SafeBooleanValue(hasAction, nil) or nil
            if hasAction == false then
                shouldRead = false
            end
        end

        if shouldRead then
            local ok, actionType, actionID = pcall(GetActionInfo, slot)
            if ok and not IsSecretValue(actionType) and not IsSecretValue(actionID) then
                local actionSpellID = SafeNumberValue(actionID)
                if actionType == "spell" and actionSpellID == spellID then
                    return slot, "spell-slot"
                elseif actionType == "macro" and GetMacroSpellID(actionID) == spellID then
                    return slot, "macro-slot"
                end
            end
        end
    end

    return nil, "no-slot"
end

function Spell.GetActionCooldown(spellID, actionSlot)
    actionSlot = SafeNumberValue(actionSlot)
    if not actionSlot then
        actionSlot = Spell.FindActionSlotForSpell(spellID)
    end
    if not actionSlot then
        return nil, "no-slot"
    end
    if not GetActionCooldown then
        return nil, "no-api", actionSlot
    end

    local ok, startTime, duration, isEnabled, modRate = pcall(GetActionCooldown, actionSlot)
    if not ok then
        return nil, "call-failed", actionSlot
    end

    local cooldown = NormalizeCooldown(startTime, duration, isEnabled, modRate)
    if cooldown then
        cooldown.actionSlot = actionSlot
        return cooldown, "ok", actionSlot
    end

    return nil, "unsafe", actionSlot
end

local function NormalizeCharges(currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate)
    if IsSecretValue(currentCharges) then
        return nil
    end

    if type(currentCharges) == "table" then
        local info = currentCharges
        currentCharges = FirstSafeNumberValue(info.currentCharges, info.charges)
        maxCharges = FirstSafeNumberValue(info.maxCharges, info.maxCharge)
        cooldownStartTime = FirstSafeNumberValue(info.cooldownStartTime, info.cooldownStart, info.startTime, info.startTimeSeconds)
        cooldownDuration = FirstSafeNumberValue(info.cooldownDuration, info.duration, info.durationSeconds)
        chargeModRate = FirstSafeNumberValue(info.chargeModRate, info.modRate)
    else
        currentCharges = SafeNumberValue(currentCharges)
        maxCharges = SafeNumberValue(maxCharges)
        cooldownStartTime = SafeNumberValue(cooldownStartTime)
        cooldownDuration = SafeNumberValue(cooldownDuration)
        chargeModRate = SafeNumberValue(chargeModRate)
    end

    if not currentCharges or not maxCharges or maxCharges <= 0 then
        return nil
    end

    cooldownStartTime = cooldownStartTime or 0
    cooldownDuration = cooldownDuration or 0
    chargeModRate = chargeModRate or 1

    return {
        currentCharges = currentCharges,
        maxCharges = maxCharges,
        cooldownStartTime = cooldownStartTime,
        cooldownDuration = cooldownDuration,
        chargeModRate = chargeModRate,
        isActive = currentCharges < maxCharges and cooldownStartTime > 0 and cooldownDuration > 0,
    }
end

local function GetChargesFromCSpell(spellID)
    if not C_Spell or not C_Spell.GetSpellCharges then return nil end
    local ok, currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = pcall(C_Spell.GetSpellCharges, spellID)
    if ok then
        return NormalizeCharges(currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate)
    end
    return nil
end

local function GetChargesFromGlobal(spellID)
    if not GetSpellCharges then return nil end
    local ok, currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate = pcall(GetSpellCharges, spellID)
    if ok then
        return NormalizeCharges(currentCharges, maxCharges, cooldownStartTime, cooldownDuration, chargeModRate)
    end
    return nil
end

function Spell.GetCharges(spellID)
    if not spellID then return nil end

    if YUI.IsRetail then
        return GetChargesFromCSpell(spellID) or GetChargesFromGlobal(spellID)
    end

    if YUI.IsMists then
        return GetChargesFromGlobal(spellID) or GetChargesFromCSpell(spellID)
    end

    if YUI.IsWrath then
        return GetChargesFromGlobal(spellID) or GetChargesFromCSpell(spellID)
    end

    return GetChargesFromGlobal(spellID) or GetChargesFromCSpell(spellID)
end

local function IsKnownFromCSpellBook(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, result = pcall(C_SpellBook.IsSpellKnown, spellID)
        if ok then
            return SafeBooleanValue(result, nil)
        end
    end
    return nil
end

local function IsKnownFromGlobal(spellID)
    if IsSpellKnown then
        local ok, result = pcall(IsSpellKnown, spellID)
        if ok then
            return SafeBooleanValue(result, nil)
        end
    end
    return nil
end

local function QuerySpellBookBankBoolean(funcName, spellID, extraArg)
    if not (C_SpellBook and C_SpellBook[funcName]) then
        return nil
    end

    local func = C_SpellBook[funcName]
    local spellBanks = Enum and Enum.SpellBookSpellBank
    local sawFalse = false

    if spellBanks then
        local playerBank = spellBanks.Player
        local petBank = spellBanks.Pet
        for index = 1, 2 do
            local bank = index == 1 and playerBank or petBank
            if bank ~= nil then
                local ok, result
                if extraArg ~= nil then
                    ok, result = pcall(func, spellID, bank, extraArg)
                else
                    ok, result = pcall(func, spellID, bank)
                end
                if ok then
                    result = SafeBooleanValue(result, nil)
                    if result == true then
                        return true
                    elseif result == false then
                        sawFalse = true
                    end
                end
            end
        end
        if sawFalse then
            return false
        end
        return nil
    end

    local ok, result = pcall(func, spellID)
    if ok then
        return SafeBooleanValue(result, nil)
    end
    return nil
end

local function IsKnownOrInSpellBookFromCSpellBook(spellID)
    if not C_SpellBook then return nil end

    local sawFalse = false
    local result = QuerySpellBookBankBoolean("IsSpellInSpellBook", spellID)
    if result == true then return true end
    if result == false then sawFalse = true end

    if C_SpellBook.IsSpellKnownOrInSpellBook then
        result = QuerySpellBookBankBoolean("IsSpellKnownOrInSpellBook", spellID, true)
        if result == true then return true end
        if result == false then sawFalse = true end
    end

    result = IsKnownFromCSpellBook(spellID)
    if result == true then return true end
    if result == false then sawFalse = true end

    if C_SpellBook.FindSpellBookSlotForSpell then
        local ok, slotIndex = pcall(C_SpellBook.FindSpellBookSlotForSpell, spellID, true, true, false, false)
        if ok and SafeNumberValue(slotIndex) then
            return true
        end
    end

    return sawFalse and false or nil
end

function Spell.IsKnown(spellID)
    if not spellID then return false end

    local result
    if YUI.IsRetail then
        result = IsKnownFromCSpellBook(spellID)
        if result ~= nil then return result end
        return IsKnownFromGlobal(spellID) or false
    end

    if YUI.IsMists then
        result = IsKnownFromGlobal(spellID)
        if result ~= nil then return result end
        return IsKnownFromCSpellBook(spellID) or false
    end

    if YUI.IsWrath then
        result = IsKnownFromGlobal(spellID)
        if result ~= nil then return result end
        return IsKnownFromCSpellBook(spellID) or false
    end

    result = IsKnownFromGlobal(spellID)
    if result ~= nil then return result end
    return IsKnownFromCSpellBook(spellID) or false
end

function Spell.IsKnownOrInSpellBook(spellID)
    if not spellID then return false end

    local result
    if YUI.IsRetail then
        result = IsKnownOrInSpellBookFromCSpellBook(spellID)
        if result == true then return true end
        local globalResult = IsKnownFromGlobal(spellID)
        if globalResult == true then return true end
        return false
    end

    if YUI.IsMists or YUI.IsWrath then
        result = IsKnownFromGlobal(spellID)
        if result ~= nil then return result end
        result = IsKnownFromCSpellBook(spellID)
        if result ~= nil then return result end
        return IsKnownOrInSpellBookFromCSpellBook(spellID) or false
    end

    result = IsKnownFromGlobal(spellID)
    if result ~= nil then return result end
    result = IsKnownFromCSpellBook(spellID)
    if result ~= nil then return result end
    return IsKnownOrInSpellBookFromCSpellBook(spellID) or false
end

Legacy.GetSpellName = Spell.GetName
Legacy.GetSpellIcon = Spell.GetTexture
Legacy.SpellHasRange = Spell.HasRange
Legacy.IsSpellInRange = Spell.IsInRange
Legacy.GetSpellCooldownInfo = Spell.GetCooldown
Legacy.GetSpellCooldownDurationObject = Spell.GetCooldownDurationObject
Legacy.GetSpellChargeDurationObject = Spell.GetChargeDurationObject
Legacy.ReadSpellCooldownDisplay = Spell.ReadCooldownDisplay
Legacy.ReadSpellChargeResourceDisplay = Spell.ReadChargeResourceDisplay
Legacy.ReadSpellCastCountResourceDisplay = Spell.ReadCastCountResourceDisplay
Legacy.ReadSpellActivationOverlay = Spell.ReadActivationOverlay
Legacy.GetSpellCooldownDurationState = Spell.GetCooldownDurationState
Legacy.GetSpellCooldownProbeState = Spell.GetCooldownProbeState
Legacy.ClearSpellCooldownProbe = Spell.ClearCooldownProbe
Legacy.FindActionSlotForSpell = Spell.FindActionSlotForSpell
Legacy.GetSpellActionCooldownInfo = Spell.GetActionCooldown
Legacy.GetSpellChargesInfo = Spell.GetCharges
Legacy.IsSpellKnown = Spell.IsKnown
Legacy.IsSpellKnownOrInSpellBook = Spell.IsKnownOrInSpellBook
