do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
local Watchdog = YUI and YUI.CPUWatchdog
if not Watchdog then return end

local Event = YUI.Event
local System = YUI.API and YUI.API.System
local unpack = unpack or table.unpack
local sceneOwner, noticeOwner = {}, {}
local MAX_SAMPLES, MAX_SLOW, MAX_MARKERS = 720, 200, 200
local function L(key)
    local values = YUI.Locale and YUI.Locale:Get("Core")
    return values and values["cpu_scene." .. key] or key
end
local function Now() return debugprofilestop() / 1000 end
local function Combat() return InCombatLockdown and InCombatLockdown() == true end
local function Cancel(timer) if timer and timer.Cancel then timer:Cancel() end end
local function Pack(...) return { n = select("#", ...), ... } end
local MAX_FRAME_WINDOWS, MAX_FRAME_INTERVALS = 2400, 4096
local function ReadFPS()
    if not GetFramerate then return nil end
    local ok, value = pcall(GetFramerate)
    if ok and not (issecretvalue and issecretvalue(value))
        and type(value) == "number" and value == value and value > 0 then return value end
end
local function FrameMetric(method, ...)
    local fn = System and System[method]
    if not fn then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not (issecretvalue and issecretvalue(value))
        and type(value) == "number" and value == value then return value end
end

-- Observation windows end at our OnUpdate, not at an engine-defined frame boundary.
-- Keep raw profiler readings alongside adjacent windows; do not subtract them.
function Watchdog:SampleSceneFrame(elapsed, terminal)
    local state = self.sceneCapture
    if not state or not state.frameWindows then return end
    local finished = debugprofilestop()
    local intervals = state.frameIntervals
    table.sort(intervals, function(a, b)
        if a.first == b.first then return a.last > b.last end
        return a.first < b.first
    end)
    local covered, right = 0, state.frameBoundary
    local outer = {}
    for _, item in ipairs(intervals) do
        local first = math.max(item.first, state.frameBoundary)
        if item.last > right then
            covered = covered + item.last - math.max(first, right)
            right = item.last
            outer[#outer + 1] = item
        end
    end
    table.sort(outer, function(a,b) return a.last-a.first > b.last-b.first end)
    local top = {}
    for i = 1, math.min(8, #outer) do top[i] = outer[i] end
    local windows = state.frameWindows
    if #windows < MAX_FRAME_WINDOWS then
        windows[#windows + 1] = {
            first = state.frameBoundary, last = finished, phase = state.phase,
            frameMS = elapsed and elapsed * 1000, terminal = terminal,
            gapMS = finished - state.frameBoundary, fps = ReadFPS(),
            visible = state.loadingHidden == true,
            sinceScreenMS = state.screenHiddenAt and finished - state.screenHiddenAt,
            yuiMS = FrameMetric("GetAddOnCPULastTime", YUI.AddonName or "YUI"),
            overallMS = FrameMetric("GetOverallCPULastTime"),
            applicationMS = FrameMetric("GetApplicationCPULastTime"),
            coveredMS = covered, calls = #intervals, dropped = state.frameIntervalDrops,
            top = top,
        }
    else
        state.frameWindowDrops = state.frameWindowDrops + 1
        -- A bounded driver must not keep allocating once its storage is full.
        if self.sceneFrame then self.sceneFrame:SetScript("OnUpdate", nil) end
        state.frameRecording = false
    end
    state.frameIntervals, state.frameIntervalDrops, state.frameBoundary = {}, 0, finished
end

local function AppendFrameCoverage(lines, state)
    local windows = state.frameWindows or {}
    lines[#lines + 1] = string.format("frame-coverage/1 windows=%d droppedWindows=%d available=%s",
        #windows, state.frameWindowDrops or 0, tostring(state.frameWindows ~= nil))
    lines[#lines + 1] = "Windows end at diagnostic OnUpdate; lastCPU may describe an adjacent frame. No aligned residual is calculated. coveredMS is interval union, NOT sum of nested probes."
    lines[#lines + 1] = "Blind spots: pre-capture Lua loading, uninstrumented native scripts/hooks/timers, engine work and diagnostic overhead. Window gaps are NOT CPU."
    -- First windows include login before the first OnUpdate. Also show the five
    -- largest native CPU readings and their neighbours to expose phase lag.
    local ranked, selected = {}, {}
    for i, row in ipairs(windows) do
        if i <= 3 then selected[i] = true end
        if not row.terminal and row.yuiMS then ranked[#ranked + 1] = i end
    end
    table.sort(ranked, function(a,b) return windows[a].yuiMS > windows[b].yuiMS end)
    for i = 1, math.min(5, #ranked) do
        for j = math.max(1, ranked[i]-2), math.min(#windows, ranked[i]+2) do selected[j] = true end
    end
    -- Rank client stalls independently of addon CPU; a low-CPU stall must not
    -- disappear from the report. Keep neighbourhoods for both clock domains.
    local stalls, fpsRows = {}, {}
    local framePeak, gapPeak, minimumFPS, over50 = 0, 0, nil, 0
    for i, row in ipairs(windows) do
        if row.visible and not row.terminal then
            stalls[#stalls + 1] = i
            framePeak = math.max(framePeak, row.frameMS or 0)
            gapPeak = math.max(gapPeak, row.gapMS or 0)
            if (row.frameMS or 0) >= 50 then over50 = over50 + 1 end
            if row.fps then
                fpsRows[#fpsRows + 1] = i
                minimumFPS = math.min(minimumFPS or row.fps, row.fps)
            end
        end
    end
    table.sort(stalls, function(a,b)
        local x, y = windows[a], windows[b]
        return math.max(x.frameMS or 0, x.gapMS or 0) > math.max(y.frameMS or 0, y.gapMS or 0)
    end)
    table.sort(fpsRows, function(a,b) return windows[a].fps < windows[b].fps end)
    local function Neighbours(index)
        for j = math.max(1, index-3), math.min(#windows, index+3) do selected[j] = true end
    end
    for i = 1, math.min(8, #stalls) do Neighbours(stalls[i]) end
    for i = 1, math.min(3, #fpsRows) do Neighbours(fpsRows[i]) end
    lines[#lines + 1] = string.format("visible-stall/1 screenMarker=%s windows=%d framePeakMS=%.3f gapPeakMS=%.3f framesOver50=%d minimumDisplayedFPS=%s",
        tostring(state.screenHiddenAt ~= nil), #stalls, framePeak, gapPeak, over50,
        minimumFPS and string.format("%.1f", minimumFPS) or "unavailable")
    lines[#lines + 1] = "Visible means after LOADING_SCREEN_DISABLED, not proof of actual presentation; first long frame may cross loading. FPS is the client display metric, not 1000/frameMS. Gap is not CPU."
    local function Number(value) return value and string.format("%.3f", value) or "unavailable" end
    for i, row in ipairs(windows) do
        if selected[i] then
            lines[#lines + 1] = string.format("  visible=%s sinceScreenMS=%s gapMS=%s displayedFPS=%s",
                tostring(row.visible == true), Number(row.sinceScreenMS), Number(row.gapMS), Number(row.fps))
            lines[#lines + 1] = string.format("window=%d [%.3f,%.3f]ms phase=%s terminal=%s frameMS=%s lastCPU YUI=%s all=%s app=%s coveredMS=%.3f intervals=%d dropped=%d",
                i, row.first-state.clockStart, row.last-state.clockStart, row.phase,
                tostring(row.terminal == true), Number(row.frameMS), Number(row.yuiMS),
                Number(row.overallMS), Number(row.applicationMS), row.coveredMS, row.calls, row.dropped)
            for _, item in ipairs(row.top) do
                lines[#lines + 1] = string.format("  interval [%.3f,%.3f]ms %s %.3fms (inclusive)",
                    item.first-state.clockStart, item.last-state.clockStart, item.id, item.last-item.first)
            end
        end
    end
end
local function Metric(method, ...)
    local callback = System and System[method]
    return callback and callback(...) or 0
end
local function Counters()
    local name = YUI.AddonName or "YUI"
    return {
        Metric("GetAddOnCPUThresholdCount", name, 10),
        Metric("GetAddOnCPUThresholdCount", name, 50),
        Metric("GetAddOnCPUThresholdCount", name, 100),
    }
end

local LAYOUT_PERF_KEYS = {
    "providerResolves", "providerCacheHits", "providerInvalidations", "providerCreated", "providerReused", "providerErrors", "providerWrites",
    "indexHits", "indexUpdates", "lookupCalls", "lookupScanned", "lookupMisses", "cycleChecks", "chainSteps", "chainMax",
    "applyAttempts", "positionApplied", "clearCalls", "pointCalls", "retryCalls", "waitingVisited",
    "resolved", "fallbackApplied", "combatDeferred", "overlayBatches", "overlayVisited", "eventCalls",
}
local LAYOUT_PERF_STAGES = {
    "layout.anchor-providers", "layout.apply-all", "layout.pending-anchors", "layout.offscreen-recovery" }
local function LayoutSize(key)
    local map = YUI.Layout and YUI.Layout[key]
    if type(map) ~= "table" then return nil end
    local count = 0
    for _ in pairs(map) do count = count + 1 end
    return count
end
local function NewLayoutPerformance()
    local result = { startRegistered = LayoutSize("frames"), startWaiting = LayoutSize("pendingAnchors") }
    for _, key in ipairs(LAYOUT_PERF_KEYS) do result[key] = 0 end
    return result
end

-- Explicit callback boundaries only; no global timer or function replacement.
function Watchdog:MeasureSceneTask(id, callback, ...)
    if not self.sceneCapture or not self.timingActive then return callback(...) end
    local state = self.sceneCapture
    local scheduledAt = state.pendingTasks[id]
    if scheduledAt then
        local wait = state.waits[id] or { calls = 0, totalMs = 0, maxMs = 0 }
        state.waits[id] = wait
        local elapsed = math.max(0, debugprofilestop() - scheduledAt)
        wait.calls, wait.totalMs = wait.calls + 1, wait.totalMs + elapsed
        wait.maxMs = math.max(wait.maxMs, elapsed)
        state.pendingTasks[id] = nil
    end
    local startedAt = self:BeginProbeTiming()
    local result = Pack(pcall(callback, ...))
    self:EndDynamicProbeTiming(id, id, nil, startedAt)
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
end

function Watchdog:SceneTaskScheduled(id)
    local state = self.sceneCapture
    if state then state.pendingTasks[id] = debugprofilestop() end
end

function Watchdog:RecordSceneTiming(id, elapsed, label, parentId, finishedAt)
    local state = self.sceneCapture
    if not state then return end
    if state.frameRecording then
        if #state.frameIntervals < MAX_FRAME_INTERVALS then
            state.frameIntervals[#state.frameIntervals + 1] = {
                id = id, first = finishedAt - elapsed, last = finishedAt,
            }
        else state.frameIntervalDrops = state.frameIntervalDrops + 1 end
    end
    local record = self.timingResults and self.timingResults[id]
    if record and (not record.sceneMaxMs or elapsed > record.sceneMaxMs) then
        record.sceneMaxMs = elapsed
        record.scenePhase = state.phase
        record.sceneAt = math.max(0, finishedAt - state.clockStart) / 1000
    end
    if elapsed < 10 then return end
    local slot = #state.slow + 1
    if slot > MAX_SLOW then
        state.truncated = true
        slot = 1
        for index = 2, MAX_SLOW do
            if state.slow[index].ms < state.slow[slot].ms then slot = index end
        end
        if elapsed <= state.slow[slot].ms then return end
    end
    state.slow[slot] = {
        id = id, ms = elapsed, phase = state.phase,
        at = math.max(0, finishedAt - state.clockStart) / 1000,
    }
end

function Watchdog:MarkScene(event)
    local state = self.sceneCapture
    if not state then return end
    state.phase = event
    if event == "LOADING_SCREEN_DISABLED" then
        state.loadingHidden, state.screenHiddenAt = true, debugprofilestop()
    elseif event == "LOADING_SCREEN_ENABLED" then
        state.loadingHidden = false
    end
    if #state.markers >= MAX_MARKERS then state.truncated = true; return end
    state.markers[#state.markers + 1] = { at = Now() - state.startedAt, event = event, counters = Counters() }
end

function Watchdog:SampleScene()
    local state = self.sceneCapture
    if not state then return end
    if #state.samples < MAX_SAMPLES then
        local addon = YUI.AddonName or "YUI"
        local last = Metric("GetAddOnCPULastTime", addon)
        local recent = Metric("GetAddOnCPURecentAverage", addon)
        state.samples[#state.samples + 1] = {
            at = Now() - state.startedAt, phase = state.phase, ms = last, recent = recent,
        }
    else
        state.truncated = true
    end
    local second = math.floor(Now())
    if state.lastPanelSecond ~= second then
        state.lastPanelSecond = second
        self:RefreshPanel()
    end
end

function Watchdog:StopSceneListeners(clearNotice)
    if self.sceneFrame then self.sceneFrame:SetScript("OnUpdate", nil) end
    if Event then Event:OffOwner(sceneOwner) end
    if clearNotice and Event then
        Event:OffOwner(noticeOwner)
        self.sceneNoticePending = nil
    end
end

local function SceneEvent(event)
    local state = Watchdog.sceneCapture
    if not state then return end
    Watchdog:MarkScene(event)
    if event == "PLAYER_ENTERING_WORLD" and state.mode ~= "current" and not state.worldSeen then
        state.worldSeen = true
        state.deadline = math.min(state.startedAt + 180, Now() + 10)
        Cancel(Watchdog.captureTimer)
        local ok, timer = pcall(C_Timer.NewTimer, math.max(0, state.deadline - Now()), function()
            Watchdog:FinishCapture("complete")
        end)
        if ok and timer then Watchdog.captureTimer = timer
        else Watchdog:FinishCapture("error") end
    end
end

function Watchdog:StartSceneCapture(mode)
    if mode ~= "current" and mode ~= "scene" and mode ~= "login" then return false end
    if self.capturing then
        self.panelNotice = L("busy"); self:RefreshPanel(); return false
    end
    if not self:IsAvailable() or type(debugprofilestop) ~= "function" or Combat() then
        self.panelNotice = L("unavailable"); self:RefreshPanel(); return false
    end
    local duration = mode == "current" and 10 or 180
    local state = {
        mode = mode, startedAt = Now(), clockStart = debugprofilestop(), deadline = Now() + duration,
        phase = mode == "login" and "ADDON_LOADED" or mode == "current" and "sampling" or "waiting",
        samples = {}, markers = {}, slow = {}, before = Counters(), pendingTasks = {}, waits = {},
        layoutPerf = NewLayoutPerformance(),
    }
    self.sceneCapture = state
    if not self:StartCapture("scene", nil, duration) then
        self.sceneCapture = nil
        self.panelNotice = L("unavailable")
        self:RefreshPanel()
        return false
    end
    if CreateFrame then
        state.frameWindows, state.frameIntervals = {}, {}
        state.frameBoundary, state.frameIntervalDrops, state.frameWindowDrops = state.clockStart, 0, 0
        state.frameRecording = true
        self.sceneFrame = self.sceneFrame or CreateFrame("Frame")
        self.sceneFrame:SetScript("OnUpdate", function(_, elapsed) self:SampleSceneFrame(elapsed) end)
    end
    self.panelNotice = nil
    self.aboveThreshold = 0
    if Event and Event.On then
        for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
            "LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED" }) do
            Event:On(event, SceneEvent, sceneOwner, { priority = 20000, traceName = "CPU scene marker" })
        end
    end
    self:MarkScene(state.phase)
    self:RefreshPanel()
    return true
end

function Watchdog:ArmSceneLogin()
    if self.capturing then self.panelNotice = L("busy")
    elseif not self:IsAvailable() or Combat() or (YUI.AddonName or "YUI") ~= "YUI" then
        self.panelNotice = L("unavailable")
    else
        _G.YUI_CPUDiagnostics = _G.YUI_CPUDiagnostics or {}
        _G.YUI_CPUDiagnostics.login = true
        self.panelNotice = nil
    end
    self:RefreshPanel()
end

function Watchdog:StopSceneCapture()
    if type(_G.YUI_CPUDiagnostics) == "table" then
        _G.YUI_CPUDiagnostics.login = nil
        if not next(_G.YUI_CPUDiagnostics) then _G.YUI_CPUDiagnostics = nil end
    end
    if self.sceneCapture or self.autoCapture then self:FinishCapture("stopped")
    else self.panelNotice = L("cancelled"); self:RefreshPanel() end
end

local QUICK_FOCUS_COUNTS = {
    "requests", "merged", "executions", "cacheHits", "scans", "candidates", "candidateMax",
    "globalsVisited", "bindingChecks", "bindingWrites", "restores", "scopeSkips", "combatDeferred",
}
local QUICK_FOCUS_REASONS = { "roster", "world", "addon", "created", "sorted", "enable", "settings", "postCombat", "preCapture" }
local QUICK_FOCUS_STAGES = { "scan-candidates", "global-scan", "reconcile-bindings", "ensure-macros", "global-binding",
    "collect.1", "collect.2", "collect.3", "collect.4", "collect.5", "collect.6", "collect.7" }
local function AppendAttribution(lines, state, timings)
    local perf = state.quickFocus or {}
    local counts = { "quick-focus/1" }
    for _, key in ipairs(QUICK_FOCUS_COUNTS) do counts[#counts + 1] = key .. "=" .. tostring(perf[key] or 0) end
    lines[#lines + 1] = table.concat(counts, " ")
    for _, reason in ipairs(QUICK_FOCUS_REASONS) do
        lines[#lines + 1] = string.format("quick-focus reason=%s requested=%d merged=%d executed=%d", reason,
            perf.reasons and perf.reasons[reason] or 0, perf.mergedReasons and perf.mergedReasons[reason] or 0, perf.executedReasons and perf.executedReasons[reason] or 0)
    end
    lines[#lines + 1] = string.format("quick-focus scheduling wait (NOT CPU): n=%d total=%.3fms max=%.3fms; preCapture=queued before capture",
        perf.waitCalls or 0, perf.waitMs or 0, perf.waitMaxMs or 0)
    local function Timing(id)
        local record = timings and timings[id] or {}
        lines[#lines + 1] = string.format("%s n=%d total=%.3fms max=%.3fms", id,
            record.calls or 0, record.totalMs or 0, record.maxMs or 0)
    end
    for _, stage in ipairs(QUICK_FOCUS_STAGES) do Timing("quick-focus." .. stage) end
    for _, adapter in ipairs({ "elvui", "eqol", "ndui" }) do
        local prefix = "appearance-summary." .. adapter
        local direct = timings and timings[prefix .. ".hook"] or {}
        local delayed = timings and timings[prefix .. ".delayed"] or {}
        lines[#lines + 1] = string.format("%s n=%d total=%.3fms max=%.3fms", prefix,
            (direct.calls or 0) + (delayed.calls or 0), (direct.totalMs or 0) + (delayed.totalMs or 0),
            math.max(direct.maxMs or 0, delayed.maxMs or 0))
        Timing("appearance-summary." .. adapter .. ".hook")
        Timing("appearance-summary." .. adapter .. ".delayed")
    end
end

function Watchdog:FinishSceneReport(base, timings, ending)
    local state = self.sceneCapture
    if state.frameRecording then self:SampleSceneFrame(nil, true) end
    local reason = ending or (state.mode == "current" and "complete" or "timeout")
    local lines = { L("title") .. " (cpu-scene/3)", L("mode." .. state.mode) .. " / " .. L("end." .. reason) }
    lines[#lines + 1] = L("boundary")
    if base then
        lines[#lines + 1] = base.lines[2]
        lines[#lines + 1] = base.lines[4]
    end
    local after = Counters()
    lines[#lines + 1] = string.format(L("counts"), Now() - state.startedAt,
        math.max(0, after[1] - state.before[1]), math.max(0, after[2] - state.before[2]),
        math.max(0, after[3] - state.before[3]))
    lines[#lines + 1] = L("inclusive")
    AppendFrameCoverage(lines, state)
    lines[#lines + 1] = string.format("Layout: visited=%d writes=%d", state.layoutVisited or 0, state.layoutWrites or 0)
    local perf = state.layoutPerf
    if perf then
        lines[#lines + 1] = string.format("layout-perf/1 implementation=%s duration=%.3fs ending=%s registered=%s/%s waiting=%s/%s",
            YUI.Layout and YUI.Layout._private and YUI.Layout._private.NameIndexImplementation
                or YUI.Layout and YUI.Layout.RegisterAnchorProvider
                and (YUI.Components and YUI.Components.GetConfiguredEnableState and "target-disabled-1" or "target-lifecycle-1")
                or "baseline-1",
            Now() - state.startedAt, tostring(reason), tostring(perf.startRegistered or "-"),
            tostring(LayoutSize("frames") or "-"), tostring(perf.startWaiting or "-"), tostring(LayoutSize("pendingAnchors") or "-"))
        local values = {}
        for _, key in ipairs(LAYOUT_PERF_KEYS) do values[#values + 1] = key .. "=" .. tostring(perf[key]) end
        lines[#lines + 1] = "layout counters: " .. table.concat(values, " ")
        for _, id in ipairs(LAYOUT_PERF_STAGES) do
            local record = timings and timings[id]
            local calls = record and record.calls or 0
            local total = record and record.totalMs or 0
            lines[#lines + 1] = string.format("layout stage=%s n=%d total=%.3fms avg=%.3fms max=%.3fms",
                id, calls, total, total / math.max(1, calls), record and record.maxMs or 0)
        end
    end
    AppendAttribution(lines, state, timings)
    local ranked = {}
    for id, record in pairs(timings or {}) do
        ranked[#ranked + 1] = { id = id, record = record }
    end
    table.sort(ranked, function(a, b) return a.record.totalMs > b.record.totalMs end)
    for index = 1, math.min(10, #ranked) do
        local item, record = ranked[index], ranked[index].record
        lines[#lines + 1] = string.format("%s | n=%d total=%.3fms avg=%.3fms max=%.3fms | %s @%.2fs",
            record.label or item.id, record.calls, record.totalMs, record.totalMs / math.max(1, record.calls),
            record.maxMs, record.scenePhase or "-", record.sceneAt or 0)
    end
    if #ranked == 0 then lines[#lines + 1] = L("unknown") end
    if base then lines[#lines + 1] = base.lines[3] end
    for id, wait in pairs(state.waits) do
        lines[#lines + 1] = string.format("%s | scheduling wait (NOT CPU): n=%d total=%.3fms max=%.3fms",
            id, wait.calls, wait.totalMs, wait.maxMs)
    end
    lines[#lines + 1] = L("stages")
    for index, marker in ipairs(state.markers) do
        local previous = index > 1 and state.markers[index - 1].counters or state.before
        lines[#lines + 1] = string.format("%.2fs %s | >10/50/100ms +%d/%d/%d", marker.at, marker.event,
            math.max(0, marker.counters[1] - previous[1]), math.max(0, marker.counters[2] - previous[2]),
            math.max(0, marker.counters[3] - previous[3]))
    end
    local previous = state.markers[#state.markers]
    previous = previous and previous.counters or state.before
    lines[#lines + 1] = string.format("%.2fs END | >10/50/100ms +%d/%d/%d", Now() - state.startedAt,
        math.max(0, after[1] - previous[1]), math.max(0, after[2] - previous[2]), math.max(0, after[3] - previous[3]))
    local phases = {}
    for _, sample in ipairs(state.samples) do
        local phase = phases[sample.phase] or { count = 0, sum = 0, peak = 0 }
        phases[sample.phase] = phase
        phase.count, phase.sum = phase.count + 1, phase.sum + sample.ms
        phase.peak = math.max(phase.peak, sample.ms)
    end
    for phase, data in pairs(phases) do
        lines[#lines + 1] = string.format("%s | sampled n=%d mean=%.3fms max=%.3fms", phase,
            data.count, data.sum / data.count, data.peak)
    end
    lines[#lines + 1] = L("samples")
    for _, sample in ipairs(state.samples) do
        lines[#lines + 1] = string.format("%.2fs %s | last=%.3fms recent=%.3fms", sample.at, sample.phase, sample.ms, sample.recent)
    end
    lines[#lines + 1] = L("slow")
    for _, item in ipairs(state.slow) do
        lines[#lines + 1] = string.format("%.2fs %s | %s %.3fms", item.at, item.phase, item.id, item.ms)
    end
    if state.truncated or self.dynamicProbeCount >= 128 then lines[#lines + 1] = L("truncated") end
    return { scene = true, lines = lines, text = table.concat(lines, "\n"), ending = reason }
end

local function PresentAfterCombat()
    Watchdog.sceneNoticePending = nil
    Watchdog:PresentSceneReport()
end

function Watchdog:PresentSceneReport()
    if Combat() then
        if not self.sceneNoticePending and Event then
            self.sceneNoticePending = Event:Once("PLAYER_REGEN_ENABLED", PresentAfterCombat, noticeOwner)
        end
        return
    end
    self.panelNotice = L("finished")
    if YUI.Print then YUI:Print(L("finished")) end
    self:RefreshPanel()
end

function Watchdog:RefreshPanel()
    local panel = self.scenePanel
    if not panel or not panel:IsShown() then return end
    local state = self.sceneCapture
    local armed = _G.YUI_CPUDiagnostics and _G.YUI_CPUDiagnostics.login == true
    local status = state and string.format(L("running"), L("mode." .. state.mode), L("phase." .. state.phase),
        math.max(0, math.ceil(state.deadline - Now()))) or (self.capturing and L("busy") or armed and L("armed") or self.panelNotice or L("idle"))
    panel.status:SetText(status)
    for _, button in ipairs(panel.startButtons) do button:SetDisabled(self.capturing) end
    panel.stop:SetDisabled(not self.capturing and armed ~= true)
    local report = self.lastReport
    if report ~= panel.report or not panel.reportText then
        panel.report = report
        panel.reportText = report and (report.text or table.concat(report.lines, "\n")) or L("empty")
        panel.edit:SetText(panel.reportText)
        panel.edit:SetCursorPosition(0)
        panel.scroll:SetVerticalScroll(0)
    end
    panel.copy:SetDisabled(report == nil)
end

function Watchdog:OpenPanel()
    if Combat() then if YUI.Print then YUI:Print(L("unavailable")) end; return false end
    local GUI = YUI.GUI
    if not GUI or not GUI.CreateFrame or not GUI.CreateEditBox then return false end
    local panel = self.scenePanel
    if not panel then
        panel = GUI:CreateFrame(UIParent, { name = "YUICPUScenePanel", width = 740, height = 510,
            template = "BackdropTemplate",
            frameStrata = "DIALOG", mouse = true, movable = true, drag = "LeftButton",
            surface = "color.surface.window", border = "color.border.default", shadow = true })
        panel:SetPoint("CENTER")
        self.scenePanel = panel
        local title = GUI:CreateText(panel, L("title"), "font.size.title", "color.text.heading")
        title:SetPoint("TOPLEFT", 16, -16)
        local close = GUI:CreateButton(panel, L("close"), 70, 26)
        close:SetPoint("TOPRIGHT", -16, -12)
        close:SetScript("OnClick", function() panel:Hide() end)
        panel.startButtons = {}
        for index, mode in ipairs({ "current", "login", "scene" }) do
            local button = GUI:CreateButton(panel, L("mode." .. mode), 150, 28)
            button:SetPoint("TOPLEFT", 16 + (index - 1) * 162, -52)
            button:SetScript("OnClick", function()
                if mode == "login" then Watchdog:ArmSceneLogin() else Watchdog:StartSceneCapture(mode) end
            end)
            panel.startButtons[index] = button
        end
        panel.stop = GUI:CreateButton(panel, L("stop"), 150, 28)
        panel.stop:SetPoint("TOPRIGHT", -16, -52)
        panel.stop:SetScript("OnClick", function() Watchdog:StopSceneCapture() end)
        panel.status = GUI:CreateText(panel, "", "font.size.sm", "color.text.secondary")
        panel.status:SetPoint("TOPLEFT", 16, -91)
        panel.status:SetWidth(700)
        panel.status:SetJustifyH("LEFT")
        panel.scroll = GUI:CreateScrollFrame(panel, {})
        panel.scroll:SetPoint("TOPLEFT", 16, -130)
        panel.scroll:SetPoint("BOTTOMRIGHT", -36, 55)
        panel.edit = GUI:CreateEditBox(panel.scroll, { width = 680, height = 320, autoFocus = false })
        panel.edit:SetMultiLine(true)
        panel.edit:SetMaxLetters(0)
        panel.edit:SetScript("OnTextChanged", function(edit, userInput)
            if userInput then edit:SetText(panel.reportText or L("empty")) end
        end)
        panel.edit:SetScript("OnEscapePressed", function(edit) edit:ClearFocus() end)
        panel.scroll:SetScrollChild(panel.edit)
        panel.copy = GUI:CreateButton(panel, L("copy"), 200, 28)
        panel.copy:SetPoint("BOTTOMLEFT", 16, 14)
        panel.copy:SetScript("OnClick", function() panel.edit:SetFocus(); panel.edit:HighlightText() end)
        panel:SetScript("OnHide", function() panel.edit:ClearFocus() end)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "YUICPUScenePanel" end
    end
    panel:Show()
    self:RefreshPanel()
    return true
end

if YUI.IsRetail == true and Event and Event.On then
    local bootOwner = {}
    Event:On("ADDON_LOADED", function(_, name)
        if name ~= (YUI.AddonName or "YUI") then return end
        Event:OffOwner(bootOwner)
        if name ~= "YUI" then return end
        local armed = _G.YUI_CPUDiagnostics
        if type(armed) == "table" then
            local login = armed.login
            armed.login = nil
            if not next(armed) then _G.YUI_CPUDiagnostics = nil end
            if login == true then Watchdog:StartSceneCapture("login") end
        end
    end, bootOwner, { priority = 30000, traceName = "CPU login capture" })
end
