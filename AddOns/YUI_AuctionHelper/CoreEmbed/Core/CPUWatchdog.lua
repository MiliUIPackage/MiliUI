do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

if not YUI then return end

local Watchdog = YUI.CPUWatchdog or {}
YUI.CPUWatchdog = Watchdog

if Watchdog.initialized then return end
Watchdog.initialized = true

local System = YUI.API and YUI.API.System
local WOW_API = YUI.WOW_API
local Event = YUI.Event
local previousSlashHandler = YUI.HandleSlashCommand

local START_DELAY_SECONDS = 30
local CHECK_INTERVAL_SECONDS = 5
local CAPTURE_SECONDS = 10
local AUTO_THRESHOLD_PERCENT = 20
local AUTO_THRESHOLD_HITS = 3
local YAB_SAMPLE_EVERY = 1
local MIN_CANDIDATE_TOTAL_MS = 100
local MIN_CANDIDATE_MAX_MS = 10
local MAX_DYNAMIC_PROBES = 128
local CAPTURE_PEAK_INTERVAL_SECONDS = 0.25
local TIMING_GROUP_WINDOW_MS = 250
local DEVELOPMENT_HARNESS_ADDON = "YUI_FrameBenchmark"
local DEVELOPMENT_PROBE_ID = "development.cpu-watchdog-load"
local ROSTER_TRANSACTION_GROUP_ID = "event.transaction.GROUP_ROSTER_UPDATE"
local ROSTER_TRANSACTION_LABEL = "GROUP_ROSTER_UPDATE transaction"

local SCENE_TYPE_KEYS = {
    none = "cpu_watch.scene.world",
    party = "cpu_watch.scene.party",
    raid = "cpu_watch.scene.raid",
    pvp = "cpu_watch.scene.pvp",
    arena = "cpu_watch.scene.arena",
    scenario = "cpu_watch.scene.scenario",
}

Watchdog.aboveThreshold = 0
Watchdog.capturing = false
Watchdog.autoCaptureUsed = false
Watchdog.lastReport = nil
Watchdog.probes = Watchdog.probes or {}
Watchdog.timingActive = false
Watchdog.timingResults = nil
Watchdog.timingGroupWindows = nil
Watchdog.dynamicProbeCount = 0
Watchdog.ROSTER_TRANSACTION_GROUP_ID = ROSTER_TRANSACTION_GROUP_ID
Watchdog.ROSTER_TRANSACTION_LABEL = ROSTER_TRANSACTION_LABEL
local IsInCombat, L, CancelTimer

local function ResolveProfileClock()
    local callback = _G.debugprofilestop
    if type(callback) ~= "function" then return nil end
    local ok, value = pcall(callback)
    return ok and type(value) == "number" and callback or nil
end

function Watchdog:BeginProbeTiming()
    local clock = self.profileClock
    if self.timingActive ~= true or type(clock) ~= "function" then return nil end
    return clock()
end

local function RecordTiming(results, id, elapsed, label, parentId)
    local record = results[id]
    if not record then
        record = { totalMs = 0, calls = 0, maxMs = 0, label = label, parentId = parentId }
        results[id] = record
    end
    record.totalMs = record.totalMs + elapsed
    record.calls = record.calls + 1
    if elapsed > record.maxMs then record.maxMs = elapsed end
    return record
end

function Watchdog:RecordTimingGroup(groupId, groupLabel, elapsed, finishedAt)
    if type(groupId) ~= "string" or groupId == "" then return end
    local results = self.timingResults
    local windows = self.timingGroupWindows
    if type(results) ~= "table" or type(windows) ~= "table" then return end

    local record = results[groupId]
    if not record then
        record = { totalMs = 0, calls = 0, maxMs = 0, label = groupLabel }
        results[groupId] = record
    end
    record.totalMs = record.totalMs + elapsed
    record.calls = record.calls + 1

    local window = windows[groupId]
    if not window then
        window = { totalMs = 0, lastFinishedAt = finishedAt }
        windows[groupId] = window
    elseif finishedAt - (window.lastFinishedAt or finishedAt) > TIMING_GROUP_WINDOW_MS then
        window.totalMs = 0
    end
    window.totalMs = window.totalMs + elapsed
    window.lastFinishedAt = finishedAt
    if window.totalMs > record.maxMs then record.maxMs = window.totalMs end
end

function Watchdog:EndProbeTiming(id, startedAt, label, parentId, groupId, groupLabel)
    if self.timingActive ~= true or type(id) ~= "string" or type(startedAt) ~= "number" then return end
    local clock = self.profileClock
    if type(clock) ~= "function" then return end
    local finishedAt = clock()
    if not finishedAt then return end
    local elapsed = finishedAt - startedAt
    if elapsed < 0 then return end
    local results = self.timingResults
    if type(results) ~= "table" then return end
    RecordTiming(results, id, elapsed, label, parentId)
    if groupId ~= id then
        self:RecordTimingGroup(groupId, groupLabel or groupId, elapsed, finishedAt)
    end
    return elapsed
end

function Watchdog:EndDynamicProbeTiming(id, label, parentId, startedAt, groupId, groupLabel)
    if self.timingActive ~= true or type(startedAt) ~= "number" then return end
    local results = self.timingResults
    if type(results) ~= "table" then return end
    if results[id] == nil then
        if self.dynamicProbeCount >= MAX_DYNAMIC_PROBES then
            id, label, parentId = "event.other", L and L("cpu_watch.probe.event_other") or "EventBus other", "core.eventbus"
        else
            self.dynamicProbeCount = self.dynamicProbeCount + 1
        end
    end
    self:EndProbeTiming(id, startedAt, label, parentId, groupId, groupLabel)
end

function Watchdog:RegisterProbe(id, spec)
    if type(id) ~= "string" or id == "" or type(spec) ~= "table" then return false end
    self.probes[id] = spec
    return true
end

function Watchdog:UnregisterProbe(id)
    if type(id) ~= "string" or self.probes[id] == nil then return false end
    self.probes[id] = nil
    return true
end

local function IsDevelopmentHarnessLoaded()
    local addons = _G.C_AddOns
    if type(addons) ~= "table" or type(addons.IsAddOnLoaded) ~= "function" then return false end
    local ok, loaded = pcall(addons.IsAddOnLoaded, DEVELOPMENT_HARNESS_ADDON)
    return ok and loaded == true
end

local developmentLoadSink = 0
local function RunDevelopmentLoadSlice(callback, budgetMs, batchSize)
    if not IsDevelopmentHarnessLoaded() or type(callback) ~= "function"
        or type(_G.debugprofilestop) ~= "function" then
        return nil
    end

    budgetMs = math.max(1, math.min(25, tonumber(budgetMs) or 1))
    batchSize = math.max(1, math.min(64, math.floor(tonumber(batchSize) or 1)))
    local startedAt = _G.debugprofilestop()
    local deadline = startedAt + budgetMs
    local calls = 0
    local sink = developmentLoadSink
    repeat
        for index = 1, batchSize do
            callback()
            sink = (sink + index * 17) % 2147483647
        end
        calls = calls + batchSize
    until _G.debugprofilestop() >= deadline
    developmentLoadSink = sink
    return calls, _G.debugprofilestop() - startedAt
end

function Watchdog:EnableDevelopmentLoadProbe()
    if YUI.IsRetail ~= true or not IsDevelopmentHarnessLoaded() then return nil end
    self.developmentProbeCleanupPending = false
    self:RegisterProbe(DEVELOPMENT_PROBE_ID, {
        localeKey = "cpu_watch.probe.development_load",
        kind = "function",
        target = RunDevelopmentLoadSlice,
        minCPU = 1,
    })
    return RunDevelopmentLoadSlice, DEVELOPMENT_PROBE_ID
end

function Watchdog:DisableDevelopmentLoadProbe()
    if self.probes[DEVELOPMENT_PROBE_ID] == nil then return false end
    if self.capturing then
        self.developmentProbeCleanupPending = true
        return true
    end
    self.developmentProbeCleanupPending = false
    return self:UnregisterProbe(DEVELOPMENT_PROBE_ID)
end

local function DevelopmentNow()
    return type(_G.GetTime) == "function" and _G.GetTime() or 0
end

local function DevelopmentLoadTickerCallback()
    local state = Watchdog.developmentLoadState
    if not state or state.running ~= true then return end
    if IsInCombat and IsInCombat() then
        state.error = "combat"
        Watchdog:StopDevelopmentLoad()
        return
    end
    local timingStartedAt = Watchdog:BeginProbeTiming()
    local calls, elapsed = RunDevelopmentLoadSlice(state.target, state.budgetMs, state.batchSize)
    Watchdog:EndProbeTiming(DEVELOPMENT_PROBE_ID, timingStartedAt)
    if type(calls) ~= "number" or type(elapsed) ~= "number" then
        state.error = "development load slice unavailable"
        Watchdog:StopDevelopmentLoad()
        return
    end
    state.totalCalls = state.totalCalls + calls
    state.totalSlices = state.totalSlices + 1
    if elapsed > state.maxSliceMs then state.maxSliceMs = elapsed end
    if DevelopmentNow() - state.startedAt >= state.durationSeconds then
        state.completed = true
        Watchdog:StopDevelopmentLoad()
    end
end

function Watchdog:RequestDevelopmentLoad(target, durationSeconds, intervalSeconds, budgetMs, batchSize)
    if self.developmentLoadRequest or self.developmentLoadState and self.developmentLoadState.running == true then
        return nil
    end
    if type(target) ~= "function" or not IsDevelopmentHarnessLoaded() then return nil end
    self.developmentLoadRequest = {
        target = target,
        durationSeconds = durationSeconds,
        intervalSeconds = intervalSeconds,
        budgetMs = budgetMs,
        batchSize = batchSize,
    }
    return self.developmentLoadRequest
end

function Watchdog:ConsumeDevelopmentLoadRequest()
    local request = self.developmentLoadRequest
    if not request then return nil end
    self.developmentLoadRequest = nil
    return self:StartDevelopmentLoad(
        request.target,
        request.durationSeconds,
        request.intervalSeconds,
        request.budgetMs,
        request.batchSize
    )
end

function Watchdog:StartDevelopmentLoad(target, durationSeconds, intervalSeconds, budgetMs, batchSize)
    if self.developmentLoadState and self.developmentLoadState.running == true then return nil end
    if type(target) ~= "function" or not IsDevelopmentHarnessLoaded() then return nil end
    local timerAPI = _G.C_Timer
    if type(timerAPI) ~= "table" or type(timerAPI.NewTicker) ~= "function" then return nil end

    local _, probeID = self:EnableDevelopmentLoadProbe()
    if not probeID then return nil end
    local state = {
        running = true,
        completed = false,
        target = target,
        durationSeconds = math.max(5, math.min(60, tonumber(durationSeconds) or 40)),
        intervalSeconds = math.max(0.02, math.min(1, tonumber(intervalSeconds) or 0.05)),
        budgetMs = math.max(1, math.min(25, tonumber(budgetMs) or 20)),
        batchSize = math.max(1, math.min(64, math.floor(tonumber(batchSize) or 32))),
        startedAt = DevelopmentNow(),
        totalCalls = 0,
        totalSlices = 0,
        maxSliceMs = 0,
    }
    self.developmentLoadState = state
    local ok, ticker = pcall(timerAPI.NewTicker, state.intervalSeconds, DevelopmentLoadTickerCallback)
    if not ok or not ticker then
        state.running = false
        state.error = "development load ticker unavailable"
        self:DisableDevelopmentLoadProbe()
        return nil
    end
    state.ticker = ticker
    return state, probeID
end

function Watchdog:ResetAutomaticCaptureForDevelopment()
    if not IsDevelopmentHarnessLoaded() then return false end
    self.autoCaptureUsed = false
    self.aboveThreshold = 0
    if not self.watchTicker then self:StartWatching() end
    return true
end

function Watchdog:StopDevelopmentLoad()
    self.developmentLoadRequest = nil
    local state = self.developmentLoadState
    if not state then return false end
    local ticker = state.ticker
    if ticker and type(ticker.Cancel) == "function" then pcall(ticker.Cancel, ticker) end
    state.ticker = nil
    state.running = false
    self:DisableDevelopmentLoadProbe()
    return true
end

local function Number(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return 0
    end
    return value
end

local function Delta(before, after, key)
    local value = Number(after and after[key]) - Number(before and before[key])
    return value > 0 and value or 0
end

L = function(key)
    local locale = YUI.Locale
    if locale and locale.Get then
        local values = locale:Get("Core")
        local value = values and values[key]
        if type(value) == "string" and value ~= "" then
            return value
        end
    end
    return key
end

local function Print(message)
    if YUI.Print then
        YUI:Print(message)
    elseif _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage(message)
    end
end

local function SafeStats(owner)
    if type(owner) ~= "table" or type(owner.GetStats) ~= "function" then
        return nil
    end
    local ok, result = pcall(owner.GetStats, owner, {})
    return ok and type(result) == "table" and result or nil
end

local function SafeDiagnosticsSnapshot(diagnostics)
    if type(diagnostics) ~= "table" or type(diagnostics.GetSnapshot) ~= "function" then
        return nil
    end
    local ok, result = pcall(diagnostics.GetSnapshot, diagnostics)
    return ok and type(result) == "table" and result or nil
end

Watchdog:RegisterProbe("core.eventbus", {
    localeKey = "cpu_watch.probe.eventbus",
    kind = "frame",
    getTarget = function() return YUI.f end,
})
Watchdog:RegisterProbe("core.monitor", {
    localeKey = "cpu_watch.probe.monitor",
    kind = "frame",
    getTarget = function() return YUI.Monitor and YUI.Monitor._tickerFrame end,
    snapshot = function() return SafeStats(YUI.Monitor) end,
    activityFields = { "tickerTicks", "wakeRuns", "sourceRuns" },
})
Watchdog:RegisterProbe("core.animation", {
    localeKey = "cpu_watch.probe.animation",
    kind = "frame",
    getTarget = function()
        return YUI.Animation and YUI.Animation.TweenDriver and YUI.Animation.TweenDriver.frame
    end,
    snapshot = function()
        local animation = YUI.Animation
        return animation and animation.GetStats and animation:GetStats() or nil
    end,
    activityFields = { "active", "tweens" },
})
Watchdog:RegisterProbe("core.visibility", {
    localeKey = "cpu_watch.probe.visibility",
    kind = "state",
    snapshot = function() return SafeStats(YUI.Visibility) end,
    activityFields = { "evaluations", "updates", "listenerCalls" },
    minActivity = 100,
})

local function ReadCPUPercent()
    if not System then return nil end
    local addon = System.GetAddOnCPURecentAverage and System.GetAddOnCPURecentAverage(YUI.AddonName or "YUI")
    local overall = System.GetOverallCPURecentAverage and System.GetOverallCPURecentAverage()
    local application = System.GetApplicationCPURecentAverage and System.GetApplicationCPURecentAverage()
    if addon == nil or overall == nil or application == nil then return nil end

    local relativeTotal = application - overall + addon
    if relativeTotal <= 0 then return nil end
    return (addon / relativeTotal) * 100
end

local function ReadProfilerCounters()
    if not System then return 0, 0 end
    local addonName = YUI.AddonName or "YUI"
    local slow = System.GetAddOnCPUThresholdCount and System.GetAddOnCPUThresholdCount(addonName, 10) or 0
    local peak = System.GetAddOnCPUPeakTime and System.GetAddOnCPUPeakTime(addonName) or 0
    return Number(slow), Number(peak)
end

local function ResolveProbeTarget(spec)
    if type(spec.getTarget) == "function" then
        local ok, target = pcall(spec.getTarget)
        return ok and target or nil
    end
    return spec.target
end

local function ReadProbe(spec)
    local result = {}
    local target = ResolveProbeTarget(spec)
    local cpuMs, calls
    if target ~= nil and spec.kind == "frame" and System.GetFrameCPUUsage then
        cpuMs, calls = System.GetFrameCPUUsage(target, spec.includeChildren == true)
    elseif type(target) == "function" and spec.kind == "function" and System.GetFunctionCPUUsage then
        cpuMs, calls = System.GetFunctionCPUUsage(target, spec.includeSubroutines ~= false)
    end
    result.cpuMs = cpuMs
    result.calls = calls
    if type(spec.snapshot) == "function" then
        local ok, state = pcall(spec.snapshot)
        if ok and type(state) == "table" then result.state = state end
    end
    return result
end

local function CaptureProbes()
    local result = {}
    for id, spec in pairs(Watchdog.probes) do
        local ok, value = pcall(ReadProbe, spec)
        if ok and type(value) == "table" then result[id] = value end
    end
    return result
end

local function CaptureSnapshot()
    local slow, peak = ReadProfilerCounters()
    local eventStats = nil
    if Event and type(Event.GetStats) == "function" then
        local ok, result = pcall(Event.GetStats, Event)
        if ok and type(result) == "table" then eventStats = result end
    end

    local yab = YUI.YActionBar
    local diagnostics = yab and yab.HotDiagnostics
    return {
        cpuPercent = ReadCPUPercent() or 0,
        slowFrames = slow,
        peakMs = peak,
        yab = SafeStats(yab),
        yabDiagnostics = SafeDiagnosticsSnapshot(diagnostics),
        yhud = SafeStats(YUI.YHUD),
        ymap = SafeStats(YUI.YMap),
        ychat = SafeStats(YUI.YChat),
        monitor = SafeStats(YUI.Monitor),
        events = eventStats,
        probes = CaptureProbes(),
    }
end

local function AddCandidate(candidates, totalMs, maxMs, text, id, parentId)
    if type(text) ~= "string" then return end
    totalMs = Number(totalMs)
    maxMs = Number(maxMs)
    if totalMs < MIN_CANDIDATE_TOTAL_MS and maxMs < MIN_CANDIDATE_MAX_MS then return end
    candidates[#candidates + 1] = {
        score = totalMs * 1000 + maxMs,
        totalMs = totalMs,
        maxMs = maxMs,
        text = text,
        id = id,
        parentId = parentId,
    }
end

local function AddYActionBarCandidate(candidates, before, after)
    local beforeDomains = before.yabDiagnostics and before.yabDiagnostics.domains or {}
    local afterDomains = after.yabDiagnostics and after.yabDiagnostics.domains or {}
    local bestName, bestEvents, bestSamples, bestSampleMs, bestMaxMs, bestScore

    for name, domainAfter in pairs(afterDomains) do
        local domainBefore = beforeDomains[name]
        local events = Delta(domainBefore, domainAfter, "events")
        local samples = Delta(domainBefore, domainAfter, "samples")
        local sampleMs = Delta(domainBefore, domainAfter, "sampleMs")
        local maxMs = Number(domainAfter.maxMs)
        if domainBefore and maxMs <= Number(domainBefore.maxMs) then maxMs = 0 end
        local score = sampleMs
        if not bestScore or score > bestScore then
            bestName, bestEvents, bestSamples = name, events, samples
            bestSampleMs, bestMaxMs, bestScore = sampleMs, maxMs, score
        end
    end

    if bestName then
        AddCandidate(candidates, bestSampleMs, bestMaxMs, string.format(
            L("cpu_watch.cause.yactionbar"), bestName, bestSampleMs, bestSamples, bestMaxMs
        ), "yactionbar." .. bestName)
    end
end

local function AddYHUDCandidate(candidates, before, after)
    before = before.yhud or {}
    after = after.yhud or {}
    local contextMs = Delta(before, after, "yhud_context_elapsedMS")
    AddCandidate(candidates, contextMs, 0, string.format(
        L("cpu_watch.cause.probe"), L("cpu_watch.probe.yhud_context"), contextMs,
        Delta(before, after, "yhud_context_executions"), 0
    ), "product.yhud-context")

    local nativeGroups = {
        { "itemFrameAcquire", "cpu_watch.probe.yhud_item_acquire" },
        { "staticCooldown", "cpu_watch.probe.yhud_static_cooldown" },
        { "staticPosition", "cpu_watch.probe.yhud_static_position" },
        { "categorySync", "cpu_watch.probe.yhud_category_sync" },
    }
    for index = 1, #nativeGroups do
        local prefix, labelKey = nativeGroups[index][1], nativeGroups[index][2]
        local totalMs = Delta(before, after, "yhud_native_" .. prefix .. "ElapsedMS")
        local maxBefore = Number(before["yhud_native_" .. prefix .. "MaxMS"])
        local maxAfter = Number(after["yhud_native_" .. prefix .. "MaxMS"])
        local maxMs = maxAfter > maxBefore and maxAfter or 0
        AddCandidate(candidates, totalMs, maxMs, string.format(
            L("cpu_watch.cause.probe"), L(labelKey), totalMs, 0, maxMs
        ), "product.yhud-" .. prefix)
    end
end

local function AddTimingCandidates(candidates, timings)
    local childTotals = {}
    for _, record in pairs(timings or {}) do
        if record.parentId then
            childTotals[record.parentId] = Number(childTotals[record.parentId]) + Number(record.totalMs)
        end
    end
    for id, record in pairs(timings or {}) do
        local childTotal = Number(childTotals[id])
        local totalMs = math.max(0, Number(record.totalMs) - childTotal)
        local maxMs = childTotal > 0 and 0 or Number(record.maxMs)
        local spec = Watchdog.probes[id]
        local label = record.label or L(spec and spec.localeKey or id)
        AddCandidate(candidates, totalMs, maxMs, string.format(
            L("cpu_watch.cause.probe"), label, totalMs, Number(record.calls), maxMs
        ), id, record.parentId)
    end
end

local function AddProbeCandidates(candidates, before, after)
    before = before or {}
    after = after or {}
    for id, probeAfter in pairs(after) do
        local probeBefore = before[id] or {}
        local spec = Watchdog.probes[id] or {}
        local cpuMs = math.max(0, Number(probeAfter.cpuMs) - Number(probeBefore.cpuMs))
        local calls = math.max(0, Number(probeAfter.calls) - Number(probeBefore.calls))
        local stateBefore = probeBefore.state or {}
        local stateAfter = probeAfter.state or {}

        if id == "core.spell-name-cache" then
            local batches = Delta(stateBefore, stateAfter, "batches")
            local scanned = Delta(stateBefore, stateAfter, "scannedIDs")
            local measured = math.max(cpuMs, Delta(stateBefore, stateAfter, "totalMs"))
            local maxBefore = Number(stateBefore.maxBatchMs)
            local maxAfter = Number(stateAfter.maxBatchMs)
            local maxMs = maxAfter > maxBefore and maxAfter or 0
            if measured >= MIN_CANDIDATE_TOTAL_MS or maxMs >= MIN_CANDIDATE_MAX_MS then
                local state = stateAfter.paused and L("cpu_watch.state.paused")
                    or (stateAfter.running and L("cpu_watch.state.running") or L("cpu_watch.state.stopped"))
                AddCandidate(candidates, measured, maxMs, string.format(
                    L("cpu_watch.cause.spell_cache"), measured, batches, scanned, state,
                    Number(stateAfter.ownerCount)
                ), id)
            end
        elseif cpuMs >= MIN_CANDIDATE_TOTAL_MS then
            local label = L(spec.localeKey or id)
            AddCandidate(candidates, cpuMs, 0, string.format(
                L("cpu_watch.cause.probe"), label, cpuMs, calls, 0
            ), id, spec.parentId)
        end
    end
end

local function IsSecretContextValue(value)
    local security = YUI.API and YUI.API.Security
    if security and type(security.IsSecretValue) == "function" then
        local ok, secret = pcall(security.IsSecretValue, value)
        if ok then return secret == true end
    end
    local checker = _G.issecretvalue
    if type(checker) ~= "function" then return false end
    local ok, secret = pcall(checker, value)
    return ok and secret == true
end

local function SafeContextString(value)
    if IsSecretContextValue(value) then return nil end
    local ok, normalized = pcall(function()
        return type(value) == "string" and value ~= "" and value or nil
    end)
    return ok and normalized or nil
end

local function ReadPlayerContext()
    local unknown = L("cpu_watch.context.unknown")
    local version = unknown
    local className = unknown
    local specializationName = unknown
    local zoneName = unknown
    local instanceType = "none"
    local mapID

    if System and type(System.GetAddOnMetadata) == "function" then
        local ok, value = pcall(System.GetAddOnMetadata, YUI.AddonName or "YUI", "Version")
        value = ok and SafeContextString(value) or nil
        if value then version = value end
    end

    local unitAPI = YUI.API and YUI.API.Unit
    local getUnitClass = unitAPI and unitAPI.UnitClass or _G.UnitClass
    if type(getUnitClass) == "function" then
        local ok, value = pcall(getUnitClass, "player")
        value = ok and SafeContextString(value) or nil
        if value then className = value end
    end

    if WOW_API and type(WOW_API.GetSpecialization) == "function"
        and type(WOW_API.GetSpecializationInfo) == "function" then
        local indexOK, specializationIndex = pcall(WOW_API.GetSpecialization)
        if indexOK and specializationIndex then
            local infoOK, _, value = pcall(WOW_API.GetSpecializationInfo, specializationIndex)
            value = infoOK and SafeContextString(value) or nil
            if value then specializationName = value end
        end
    end

    if WOW_API and type(WOW_API.GetRealZoneText) == "function" then
        local ok, value = pcall(WOW_API.GetRealZoneText)
        value = ok and SafeContextString(value) or nil
        if value then zoneName = value end
    end

    if type(_G.GetInstanceInfo) == "function" then
        local ok, instanceName, value = pcall(_G.GetInstanceInfo)
        if ok then
            value = SafeContextString(value)
            instanceName = SafeContextString(instanceName)
            if value then instanceType = value end
            if instanceType ~= "none" and instanceName then
                zoneName = instanceName
            end
        end
    end

    local mapAPI = _G.C_Map
    if type(mapAPI) == "table" and type(mapAPI.GetBestMapForUnit) == "function" then
        local ok, value = pcall(mapAPI.GetBestMapForUnit, "player")
        if ok and not IsSecretContextValue(value) then
            local numberOK, normalized = pcall(tonumber, value)
            if numberOK and type(normalized) == "number" then mapID = normalized end
        end
    end

    local visibility = YUI.API and YUI.API.Visibility
    local function ReadVisibility(key)
        if not visibility or type(visibility.Read) ~= "function" then return nil end
        local ok, value = pcall(visibility.Read, key)
        return ok and value or nil
    end
    local taxi = ReadVisibility("taxi")
    local skyriding = ReadVisibility("skyriding")
    local mounted = ReadVisibility("mounted")
    local movementKey = "cpu_watch.movement.unmounted"
    if taxi == true then
        movementKey = "cpu_watch.movement.taxi"
    elseif skyriding == true then
        movementKey = "cpu_watch.movement.skyriding"
    elseif mounted == true then
        movementKey = "cpu_watch.movement.mounted"
    elseif taxi == nil and skyriding == nil and mounted == nil then
        movementKey = "cpu_watch.movement.unknown"
    end
    local raid = ReadVisibility("raid")
    local grouped = ReadVisibility("group")
    local groupKey = "cpu_watch.group.solo"
    if raid == true then
        groupKey = "cpu_watch.group.raid"
    elseif grouped == true then
        groupKey = "cpu_watch.group.party"
    elseif raid == nil and grouped == nil then
        groupKey = "cpu_watch.group.unknown"
    end

    local sceneTypeKey = SCENE_TYPE_KEYS[instanceType] or "cpu_watch.scene.unknown"
    return version, className, specializationName, zoneName, L(sceneTypeKey),
        mapID and tostring(mapID) or "-", L(movementKey), L(groupKey)
end

local function BuildReport(reason, triggerPercent, before, after, timings, capturePeakMs)
    local candidates = {}
    AddYActionBarCandidate(candidates, before, after)
    AddYHUDCandidate(candidates, before, after)
    AddTimingCandidates(candidates, timings)
    AddProbeCandidates(candidates, before.probes, after.probes)
    local bestByID = {}
    local compact = {}
    for index = 1, #candidates do
        local candidate = candidates[index]
        local id = candidate.id
        local previous = id and bestByID[id]
        if not previous then
            compact[#compact + 1] = candidate
            if id then bestByID[id] = candidate end
        elseif candidate.score > previous.score then
            previous.score = candidate.score
            previous.totalMs = candidate.totalMs
            previous.maxMs = candidate.maxMs
            previous.text = candidate.text
        end
    end
    candidates = compact
    table.sort(candidates, function(left, right) return left.score > right.score end)

    local causes = {}
    for index = 1, math.min(3, #candidates) do
        causes[index] = candidates[index].text
    end
    if #causes == 0 then causes[1] = L("cpu_watch.unresolved") end

    local beginPercent = Number(before.cpuPercent)
    local endPercent = Number(after.cpuPercent)
    local maxPercent = math.max(Number(triggerPercent), beginPercent, endPercent)
    local slowFrames = math.max(0, Number(after.slowFrames) - Number(before.slowFrames))
    local peakMs = math.max(Number(before.peakMs), Number(after.peakMs))
    local modeKey = reason == "auto" and "cpu_watch.header.auto" or "cpu_watch.header.manual"
    local version, className, specializationName, zoneName, sceneType, mapID, movement, group = ReadPlayerContext()

    return {
        reason = reason,
        candidates = candidates,
        lines = {
            L(modeKey),
            string.format(L("cpu_watch.metrics"), beginPercent, endPercent, maxPercent, slowFrames,
                Number(capturePeakMs), peakMs),
            string.format(L("cpu_watch.causes"), table.concat(causes, " | ")),
            string.format(L("cpu_watch.context"), version, className, specializationName, zoneName,
                sceneType, mapID, movement, group),
            L("cpu_watch.contact_author"),
        },
    }
end

IsInCombat = function()
    if type(_G.InCombatLockdown) ~= "function" then return false end
    local ok, result = pcall(_G.InCombatLockdown)
    return ok and result == true
end

function Watchdog:PrintReport(report)
    if not report or type(report.lines) ~= "table" then return end
    for index = 1, #report.lines do Print(report.lines[index]) end
end

local function OnCombatEnded()
    Watchdog.pendingCombatListener = nil
    Watchdog.combatSkipActive = false
    if Watchdog.combatNoticePending then
        Watchdog.combatNoticePending = false
        Print(L(Watchdog.combatNoticeKey or "cpu_watch.combat_skipped"))
        Watchdog.combatNoticeKey = nil
    end
end

function Watchdog:ScheduleCombatNotice(localeKey)
    self.combatNoticePending = true
    self.combatSkipActive = true
    self.combatNoticeKey = localeKey or self.combatNoticeKey or "cpu_watch.combat_skipped"
    if not self.pendingCombatListener and Event and type(Event.Once) == "function" then
        self.pendingCombatListener = Event:Once("PLAYER_REGEN_ENABLED", OnCombatEnded, self)
    end
end

function Watchdog:QueueReport(report)
    if IsInCombat() then
        self:ScheduleCombatNotice()
        return false
    end
    self.lastReport = report
    self:PrintReport(report)
    return true
end

function Watchdog:PrepareYActionBarDiagnostics()
    local yab = YUI.YActionBar
    local diagnostics = yab and yab.HotDiagnostics
    self.yabDiagnostics = diagnostics
    self.ownsYABDiagnostics = false
    if type(diagnostics) ~= "table" or type(diagnostics.Start) ~= "function" then return end
    if diagnostics.enabled == true then return end

    self.yabDiagnosticState = {
        sampleEvery = diagnostics.sampleEvery,
        mode = diagnostics.mode,
        detailEnabled = diagnostics.detailEnabled,
    }
    local ok = pcall(diagnostics.Start, diagnostics, YAB_SAMPLE_EVERY, "time")
    self.ownsYABDiagnostics = ok and diagnostics.enabled == true
end

function Watchdog:RestoreYActionBarDiagnostics()
    local diagnostics = self.yabDiagnostics
    if self.ownsYABDiagnostics and type(diagnostics) == "table"
        and diagnostics.enabled == true and diagnostics.sampleEvery == YAB_SAMPLE_EVERY
        and diagnostics.mode == "time" then
        if type(diagnostics.Stop) == "function" then pcall(diagnostics.Stop, diagnostics) end
        local state = self.yabDiagnosticState or {}
        diagnostics.sampleEvery = state.sampleEvery
        diagnostics.mode = state.mode
        diagnostics.detailEnabled = state.detailEnabled == true
    end
    self.yabDiagnostics = nil
    self.yabDiagnosticState = nil
    self.ownsYABDiagnostics = false
end

function Watchdog:PrepareYHUDDiagnostics()
    local yhud = YUI.YHUD
    self.yhudDiagnostics = yhud
    self.yhudDiagnosticsWasEnabled = yhud and yhud.performanceDiagnosticsEnabled == true or false
    if yhud and type(yhud.SetPerformanceDiagnosticsEnabled) == "function"
        and not self.yhudDiagnosticsWasEnabled then
        pcall(yhud.SetPerformanceDiagnosticsEnabled, yhud, true)
        self.ownsYHUDDiagnostics = yhud.performanceDiagnosticsEnabled == true
    end
end

function Watchdog:RestoreYHUDDiagnostics()
    local yhud = self.yhudDiagnostics
    if self.ownsYHUDDiagnostics and yhud and type(yhud.SetPerformanceDiagnosticsEnabled) == "function" then
        pcall(yhud.SetPerformanceDiagnosticsEnabled, yhud, false)
    end
    self.yhudDiagnostics = nil
    self.yhudDiagnosticsWasEnabled = nil
    self.ownsYHUDDiagnostics = false
end

local function CapturePeakTickerCallback()
    if not Watchdog.capturing or not System or type(System.GetAddOnCPULastTime) ~= "function" then return end
    local value = Number(System.GetAddOnCPULastTime(YUI.AddonName or "YUI"))
    if value > Number(Watchdog.capturePeakMs) then Watchdog.capturePeakMs = value end
end

function Watchdog:StartCapturePeakSampler()
    local timerAPI = _G.C_Timer
    if not timerAPI or type(timerAPI.NewTicker) ~= "function" then return end
    local ok, ticker = pcall(timerAPI.NewTicker, CAPTURE_PEAK_INTERVAL_SECONDS, CapturePeakTickerCallback)
    if ok then self.capturePeakTicker = ticker end
end

function Watchdog:StopCapturePeakSampler()
    CancelTimer(self.capturePeakTicker)
    self.capturePeakTicker = nil
end

function Watchdog:StartTiming()
    self.timingResults = {}
    self.timingGroupWindows = {}
    self.dynamicProbeCount = 0
    self.profileClock = ResolveProfileClock()
    self.timingActive = self.profileClock ~= nil and not IsInCombat()
    if not self.timingActive then self.profileClock = nil end
    if Event then Event.cpuTimingWatchdog = self.timingActive and self or nil end
end

function Watchdog:StopTiming()
    self.timingActive = false
    self.profileClock = nil
    if Event and Event.cpuTimingWatchdog == self then Event.cpuTimingWatchdog = nil end
    local results = self.timingResults or {}
    self.timingResults = nil
    self.timingGroupWindows = nil
    self.dynamicProbeCount = 0
    return results
end

local function CombatStartedDuringCapture()
    Watchdog.captureCombatListener = nil
    Watchdog:AbortCaptureForCombat()
end

local function CaptureTimerCallback()
    Watchdog.captureTimer = nil
    Watchdog:FinishCapture()
end

function Watchdog:StartCapture(reason, triggerPercent)
    if self.capturing then
        if reason == "manual" then Print(L("cpu_watch.busy")) end
        return false
    end
    if not self:IsAvailable() then
        if reason == "manual" then Print(L("cpu_watch.unavailable")) end
        return false
    end
    if IsInCombat() then
        if reason == "manual" then Print(L("cpu_watch.combat_manual")) end
        return false
    end

    self.capturing = true
    self.captureReason = reason or "manual"
    self.triggerPercent = triggerPercent or ReadCPUPercent() or 0
    self:PrepareYActionBarDiagnostics()
    self:PrepareYHUDDiagnostics()
    self:StartTiming()
    self.capturePeakMs = 0
    self:StartCapturePeakSampler()
    local snapshotOK, snapshot = pcall(CaptureSnapshot)
    if not snapshotOK then
        self.capturing = false
        self.captureReason = nil
        self.triggerPercent = nil
        self.capturePeakMs = nil
        self:StopCapturePeakSampler()
        self:StopTiming()
        self:RestoreYActionBarDiagnostics()
        self:RestoreYHUDDiagnostics()
        if reason == "manual" then Print(L("cpu_watch.unavailable")) end
        return false
    end
    self.captureBefore = snapshot

    local timerAPI = _G.C_Timer
    if not timerAPI or type(timerAPI.NewTimer) ~= "function" then
        self.capturing = false
        self.captureBefore = nil
        self.captureReason = nil
        self.triggerPercent = nil
        self.capturePeakMs = nil
        self:StopCapturePeakSampler()
        self:StopTiming()
        self:RestoreYActionBarDiagnostics()
        self:RestoreYHUDDiagnostics()
        if reason == "manual" then Print(L("cpu_watch.unavailable")) end
        return false
    end

    local timerOK, timer = pcall(timerAPI.NewTimer, CAPTURE_SECONDS, CaptureTimerCallback)
    if not timerOK or not timer then
        self.capturing = false
        self.captureBefore = nil
        self.captureReason = nil
        self.triggerPercent = nil
        self.capturePeakMs = nil
        self:StopCapturePeakSampler()
        self:StopTiming()
        self:RestoreYActionBarDiagnostics()
        self:RestoreYHUDDiagnostics()
        if reason == "manual" then Print(L("cpu_watch.unavailable")) end
        return false
    end
    self.captureTimer = timer
    if Event and type(Event.Once) == "function" then
        self.captureCombatListener = Event:Once("PLAYER_REGEN_DISABLED", CombatStartedDuringCapture, self)
    end
    if self.captureReason == "auto" then
        self.autoCaptureUsed = true
        CancelTimer(self.watchTicker)
        self.watchTicker = nil
    end
    if self.captureReason == "manual" then Print(L("cpu_watch.manual_started")) end
    return true
end

function Watchdog:FinishCapture()
    if not self.capturing then return false end
    if IsInCombat() then return self:AbortCaptureForCombat() end
    self:StopCapturePeakSampler()
    local timings = self:StopTiming()
    local snapshotOK, after = pcall(CaptureSnapshot)
    local reportOK, report = false, nil
    if snapshotOK then
        reportOK, report = pcall(
            BuildReport, self.captureReason, self.triggerPercent, self.captureBefore or {}, after,
            timings, self.capturePeakMs
        )
    end
    self.capturing = false
    self.captureBefore = nil
    self.captureReason = nil
    self.triggerPercent = nil
    self.capturePeakMs = nil
    if self.captureCombatListener and Event and type(Event.Off) == "function" then
        pcall(Event.Off, Event, self.captureCombatListener)
    end
    self.captureCombatListener = nil
    self:RestoreYActionBarDiagnostics()
    self:RestoreYHUDDiagnostics()
    if self.developmentProbeCleanupPending then
        self.developmentProbeCleanupPending = false
        self:UnregisterProbe(DEVELOPMENT_PROBE_ID)
    end
    if not reportOK then
        Print(L("cpu_watch.unavailable"))
        return false
    end
    self:QueueReport(report)
    return true
end

function Watchdog:AbortCaptureForCombat()
    if not self.capturing then return false end
    local reason = self.captureReason
    CancelTimer(self.captureTimer)
    self.captureTimer = nil
    self:StopCapturePeakSampler()
    self:StopTiming()
    self.capturing = false
    self.captureBefore = nil
    self.captureReason = nil
    self.triggerPercent = nil
    self.capturePeakMs = nil
    self.captureCombatListener = nil
    self:RestoreYActionBarDiagnostics()
    self:RestoreYHUDDiagnostics()
    if self.developmentProbeCleanupPending then
        self.developmentProbeCleanupPending = false
        self:UnregisterProbe(DEVELOPMENT_PROBE_ID)
    end
    self:ScheduleCombatNotice(reason == "auto"
        and "cpu_watch.combat_aborted_auto"
        or "cpu_watch.combat_aborted_manual")
    return true
end

function Watchdog:IsAvailable()
    return YUI.IsRetail == true and System
        and type(System.CanReadRecentAddOnCPUUsage) == "function"
        and System.CanReadRecentAddOnCPUUsage() == true
end

function Watchdog:Check()
    if self.developmentLoadRequest then self:ConsumeDevelopmentLoadRequest() end
    if self.autoCaptureUsed then
        CancelTimer(self.watchTicker)
        self.watchTicker = nil
        return
    end
    local percent = ReadCPUPercent()
    if percent == nil then
        self.aboveThreshold = 0
        return
    end
    if self.combatSkipActive and IsInCombat() then
        self.aboveThreshold = 0
        return
    end
    if percent <= AUTO_THRESHOLD_PERCENT then
        self.aboveThreshold = 0
        return
    end

    self.aboveThreshold = self.aboveThreshold + 1
    if self.aboveThreshold < AUTO_THRESHOLD_HITS then return end
    self.aboveThreshold = 0
    if self.capturing then return end
    if IsInCombat() then
        self:ScheduleCombatNotice()
        return
    end
    self:StartCapture("auto", percent)
end

local function WatchTickerCallback()
    Watchdog:Check()
end

function Watchdog:StartWatching()
    self.startupTimer = nil
    if self.watchTicker or self.autoCaptureUsed or not self:IsAvailable() then return false end
    local timerAPI = _G.C_Timer
    if not timerAPI or type(timerAPI.NewTicker) ~= "function" then return false end
    local ok, ticker = pcall(timerAPI.NewTicker, CHECK_INTERVAL_SECONDS, WatchTickerCallback)
    if not ok then return false end
    self.watchTicker = ticker
    return self.watchTicker ~= nil
end

local function StartupTimerCallback()
    Watchdog:StartWatching()
end

function Watchdog:OnWorldReady()
    if self.startupTimer or self.watchTicker or not self:IsAvailable() then return end
    local timerAPI = _G.C_Timer
    if timerAPI and type(timerAPI.NewTimer) == "function" then
        local ok, timer = pcall(timerAPI.NewTimer, START_DELAY_SECONDS, StartupTimerCallback)
        if ok then self.startupTimer = timer end
    end
end

CancelTimer = function(timer)
    if timer and type(timer.Cancel) == "function" then pcall(timer.Cancel, timer) end
end

function Watchdog:Stop()
    self:StopDevelopmentLoad()
    CancelTimer(self.startupTimer)
    CancelTimer(self.watchTicker)
    CancelTimer(self.captureTimer)
    CancelTimer(self.capturePeakTicker)
    self.startupTimer = nil
    self.watchTicker = nil
    self.captureTimer = nil
    self.capturePeakTicker = nil
    self.aboveThreshold = 0
    self.capturing = false
    self.captureBefore = nil
    self.captureReason = nil
    self.triggerPercent = nil
    self.capturePeakMs = nil
    self.combatNoticePending = false
    self.combatSkipActive = false
    self.combatNoticeKey = nil
    self:StopTiming()
    self.developmentProbeCleanupPending = false
    self:UnregisterProbe(DEVELOPMENT_PROBE_ID)
    self:RestoreYActionBarDiagnostics()
    self:RestoreYHUDDiagnostics()
    if Event and type(Event.OffOwner) == "function" then Event:OffOwner(self) end
    self.pendingCombatListener = nil
    self.captureCombatListener = nil
end

function YUI:HandleSlashCommand(message)
    local command = type(message) == "string" and message:match("^%s*(.-)%s*$") or ""
    if command:lower() == "cpu" then
        Watchdog:StartCapture("manual")
        return true
    end
    if previousSlashHandler then return previousSlashHandler(self, message) end
    return false
end

local function WorldReadyCallback()
    Watchdog:OnWorldReady()
end

if YUI.IsRetail == true then
    local lifecycle = YUI.Lifecycle
    if lifecycle and type(lifecycle.IsReady) == "function"
        and lifecycle:IsReady("YUI_WORLD_READY") == true then
        Watchdog:OnWorldReady()
    elseif Event and type(Event.Once) == "function" then
        Event:Once("YUI_WORLD_READY", WorldReadyCallback, Watchdog)
    end
end
