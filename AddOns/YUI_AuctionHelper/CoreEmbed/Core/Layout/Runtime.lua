do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - runtime
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local Layout = YUI.Layout
local P = Layout._private
local Event = P.Event
local MODULE_ID = P.MODULE_ID
local C_Timer = P.C_Timer
local InCombat = P.InCombat
local Print = P.Print
local L = P.L
local SafeCall = P.SafeCall
local ResolveSpecValue = P.ResolveSpecValue
local ResolveDefaultPlacement = P.ResolveDefaultPlacement
local ResolveEntryFrame = P.ResolveEntryFrame
local ResolveBuiltinAnchorTarget = P.ResolveBuiltinAnchorTarget
local IsAnchorTargetAvailable = P.IsAnchorTargetAvailable
local GetSavedPlacement = P.GetSavedPlacement
local ApplyPlacement = P.ApplyPlacement
local HideAnchorLine = P.HideAnchorLine
local NativeClearSnapPreview = P.NativeClearSnapPreview
local HideBuiltinAnchorPlaceholders = P.HideBuiltinAnchorPlaceholders
local PLACEMENT_PENDING = P.PLACEMENT_PENDING
local PLACEMENT_FALLBACK = P.PLACEMENT_FALLBACK
local PLACEMENT_SIMULATED = P.PLACEMENT_SIMULATED
local PLACEMENT_READY = P.PLACEMENT_READY
local pairs = P.pairs
local ipairs = P.ipairs
local type = P.type
local tostring = P.tostring
local next = next
local BUILTIN_ANCHOR_TARGETS = P.BUILTIN_ANCHOR_TARGETS or {}
local PARTY_ANCHOR_TARGET = BUILTIN_ANCHOR_TARGETS.PARTY or "@YUI.PartyFrame"
local RAID_ANCHOR_TARGET = BUILTIN_ANCHOR_TARGETS.RAID or "@YUI.RaidFrame"

local function IsEditEntryEligible(entry)
    if not entry or entry.placementState == PLACEMENT_PENDING then return false end
    local frame = ResolveEntryFrame(entry)
    if not frame
        or ResolveSpecValue(entry, "isEnabled", true) == false
        or (IsAnchorTargetAvailable
            and IsAnchorTargetAvailable(entry) == false) then
        return false, frame
    end
    return true, frame
end

local function HideEntryOverlay(entry)
    local overlay = entry and entry.overlay
    if not overlay then return end
    if overlay.IsShown and overlay:IsShown() then overlay:Hide() end
    overlay:SetScript("OnUpdate", nil)
    overlay.yuiLayoutDragging = false
end

function Layout:ActivateEditSessionEntry(entry)
    if not self.editing or not entry then return false end
    self.editSessionEntrySet = self.editSessionEntrySet or {}
    if self.editSessionEntrySet[entry.id] == entry then return true end

    local eligible, frame = IsEditEntryEligible(entry)
    if not eligible then return false end

    self.editSessionEntries = self.editSessionEntries or {}
    self.editSessionKnownEntries = self.editSessionKnownEntries or {}
    if self.editSessionKnownEntries[entry.id] ~= entry then
        self.editSessionEntries[#self.editSessionEntries + 1] = entry
        self.editSessionKnownEntries[entry.id] = entry
    end
    self.editSessionEntrySet[entry.id] = entry

    if ResolveSpecValue(entry, "showOnlyInEditMode", false) == true then
        frame:Show()
    end
    if type(entry.spec.onEnterEditMode) == "function" then
        SafeCall(
            "Layout:onEnter:" .. tostring(entry.id),
            entry.spec.onEnterEditMode,
            frame,
            entry,
            self
        )
    end
    return true
end

function Layout:DeactivateEditSessionEntry(entry)
    if not entry or not self.editSessionEntrySet
        or self.editSessionEntrySet[entry.id] ~= entry then
        return false
    end
    self.editSessionEntrySet[entry.id] = nil
    HideEntryOverlay(entry)
    local frame = ResolveEntryFrame(entry)
    if type(entry.spec.onExitEditMode) == "function" then
        SafeCall(
            "Layout:onExit:" .. tostring(entry.id),
            entry.spec.onExitEditMode,
            frame,
            entry,
            self
        )
    end
    if frame and ResolveSpecValue(entry, "showOnlyInEditMode", false) == true then
        frame:Hide()
    end
    return true
end

function Layout:RefreshEditSessionEntry(entry)
    if type(entry) == "string" then entry = self.frames[entry] end
    if not self.editing or not entry then return false end
    local eligible = IsEditEntryEligible(entry)
    if eligible then
        self:ActivateEditSessionEntry(entry)
        self:UpdateOverlay(entry)
        return true
    end
    self:DeactivateEditSessionEntry(entry)
    return false
end

local PENDING_ANCHOR_RETRY_DELAYS = { 0.2, 1, 3, 5 }
local OFFSCREEN_RECHECK_EVENTS = {
    DISPLAY_SIZE_CHANGED = true,
    UI_SCALE_CHANGED = true,
    PLAYER_LOGIN = true,
    PLAYER_ENTERING_WORLD = true,
    PLAYER_REGEN_ENABLED = true,
    YUI_DB_READY = true,
}

local function HasPendingAnchors()
    for id in pairs(Layout.pendingAnchors or {}) do
        local entry = Layout.frames[id]
        if entry and (entry.placementState == PLACEMENT_PENDING or entry.placementState == PLACEMENT_FALLBACK or entry.placementState == PLACEMENT_SIMULATED) then
            return true
        end
        if Layout.pendingAnchors then Layout.pendingAnchors[id] = nil end
    end
    return false
end

local function ApplyCombatDeferredPlacements()
    local deferred = Layout.combatDeferredPlacements
    if type(deferred) ~= "table" or type(Layout.RefreshFrame) ~= "function" then
        return 0
    end
    local applied = 0
    for id in pairs(deferred) do
        local entry = Layout.frames[id]
        if entry and entry.combatDeferredPlacement then
            if Layout:RefreshFrame(id) then applied = applied + 1 end
        else
            deferred[id] = nil
        end
    end
    return applied
end

local function SchedulePendingAnchorRetry(reset)
    if reset then Layout.pendingAnchorRetryStep = 0 end
    if Layout.pendingAnchorRetryScheduled or not C_Timer or not C_Timer.After then return end
    if not HasPendingAnchors() then return end

    local step = (Layout.pendingAnchorRetryStep or 0) + 1
    local delay = PENDING_ANCHOR_RETRY_DELAYS[step]
    if not delay then return end

    Layout.pendingAnchorRetryStep = step
    Layout.pendingAnchorRetryScheduled = true
    C_Timer.After(delay, function()
        Layout.pendingAnchorRetryScheduled = nil
        local allowFallback = step >= #PENDING_ANCHOR_RETRY_DELAYS
        local stillPending = Layout:RetryPendingAnchors(allowFallback)
        if stillPending and not allowFallback then
            SchedulePendingAnchorRetry(false)
        end
    end)
end
P.QueuePendingAnchorRetry = function(_, reset)
    SchedulePendingAnchorRetry(reset)
end

local function CaptureSettingsRestoreState()
    local Settings = YUI.Settings
    if not Settings or not Settings.IsOpen or not Settings:IsOpen() then
        return nil
    end
    if Settings.GetOpenState then
        return Settings:GetOpenState()
    end
    return {
        productId = Settings.ActiveProductId,
        scope = Settings.ActiveScope,
    }
end

local function CloseSettingsForEditMode()
    local Settings = YUI.Settings
    local state = CaptureSettingsRestoreState()
    Layout.settingsRestoreState = state
    if state and Settings and Settings.Close then
        Settings:Close({ immediate = true })
    end
end

local function RestoreSettingsAfterEditMode(source)
    local state = Layout.settingsRestoreState
    Layout.settingsRestoreState = nil
    if not state or source == "combat" then
        return
    end
    local Settings = YUI.Settings
    if Settings and Settings.IsOpen and Settings:IsOpen() then
        if Settings.RefreshEditModeButton then
            Settings:RefreshEditModeButton()
        end
        return
    end
    if Settings and Settings.Open then
        Settings:Open(state)
    end
end

local EDIT_PROFILE_FIELDS = {
    "openCount",
    "closeCount",
    "openTotalMS",
    "closeTotalMS",
    "settingsMS",
    "entryEnterMS",
    "entryExitMS",
    "overlayMS",
    "chromeMS",
    "eventMS",
}

local function ProfileNow()
    if not Layout.editProfilingEnabled
        or type(debugprofilestop) ~= "function" then
        return nil
    end
    local ok, value = pcall(debugprofilestop)
    return ok and type(value) == "number" and value or nil
end

local function AddProfileTime(field, startedAt)
    if not startedAt then return end
    local finishedAt = ProfileNow()
    if not finishedAt then return end
    local stats = Layout.editModeStats
    stats[field] = (stats[field] or 0) + math.max(0, finishedAt - startedAt)
end

function Layout:SetEditModeProfiling(enabled)
    self.editProfilingEnabled = enabled == true
end

function Layout:ResetEditModeStats()
    self.editModeStats = self.editModeStats or {}
    for index = 1, #EDIT_PROFILE_FIELDS do
        self.editModeStats[EDIT_PROFILE_FIELDS[index]] = 0
    end
    self.editModeStats.lastActiveEntries = 0
    return true
end

function Layout:GetEditModeStats(target)
    target = target or {}
    local stats = self.editModeStats or {}
    for index = 1, #EDIT_PROFILE_FIELDS do
        local field = EDIT_PROFILE_FIELDS[index]
        target[field] = stats[field] or 0
    end
    target.lastActiveEntries = stats.lastActiveEntries or 0
    return target
end

Layout:ResetEditModeStats()

function Layout:OpenEditMode(source)
    local totalStartedAt = ProfileNow()
    if InCombat() then
        Print(L("layout.message.combat_blocked"))
        return false
    end
    if self.editing then
        self:RefreshOverlays()
        self:ShowControlPanel()
        return true
    end

    local stageStartedAt = ProfileNow()
    CloseSettingsForEditMode()
    AddProfileTime("settingsMS", stageStartedAt)
    self.editing = true
    self.editSource = source or "yui"
    self.hiddenMoverOverlayIds = nil
    self.editSessionEntries = {}
    self.editSessionEntrySet = {}
    self.editSessionKnownEntries = {}
    stageStartedAt = ProfileNow()
    for _, id in ipairs(self.order) do
        local entry = self.frames[id]
        if entry then self:ActivateEditSessionEntry(entry) end
    end
    if not self.selectedId or not self.editSessionEntrySet[self.selectedId] then
        local first = self.editSessionEntries[1]
        self.selectedId = first and first.id or nil
    end
    self.editModeStats.lastActiveEntries = #self.editSessionEntries
    AddProfileTime("entryEnterMS", stageStartedAt)
    stageStartedAt = ProfileNow()
    self:RefreshOverlays()
    AddProfileTime("overlayMS", stageStartedAt)
    stageStartedAt = ProfileNow()
    self:ShowControlPanel()
    self:UpdateGrid()
    AddProfileTime("chromeMS", stageStartedAt)
    stageStartedAt = ProfileNow()
    if Event and Event.Emit then Event:Emit("YUI_LAYOUT_EDIT_MODE_OPENED", source or "yui") end
    AddProfileTime("eventMS", stageStartedAt)
    if totalStartedAt then
        self.editModeStats.openCount = (self.editModeStats.openCount or 0) + 1
        AddProfileTime("openTotalMS", totalStartedAt)
    end
    return true
end

function Layout:CloseEditMode(source)
    if not self.editing then return true end
    local totalStartedAt = ProfileNow()
    self.editing = false
    self.editSource = nil
    self.hiddenMoverOverlayIds = nil
    if HideBuiltinAnchorPlaceholders then HideBuiltinAnchorPlaceholders() end
    local stageStartedAt = ProfileNow()
    for _, entry in ipairs(self.editSessionEntries or {}) do
        self:DeactivateEditSessionEntry(entry)
    end
    AddProfileTime("entryExitMS", stageStartedAt)
    self.editSessionEntries = nil
    self.editSessionEntrySet = nil
    self.editSessionKnownEntries = nil
    stageStartedAt = ProfileNow()
    self:HideControlPanel()
    self:HideMoverPanel()
    self:HideGrid()
    HideAnchorLine()
    NativeClearSnapPreview()
    AddProfileTime("chromeMS", stageStartedAt)
    stageStartedAt = ProfileNow()
    if Event and Event.Emit then Event:Emit("YUI_LAYOUT_EDIT_MODE_CLOSED", source or "yui") end
    RestoreSettingsAfterEditMode(source)
    AddProfileTime("eventMS", stageStartedAt)
    if totalStartedAt then
        self.editModeStats.closeCount = (self.editModeStats.closeCount or 0) + 1
        AddProfileTime("closeTotalMS", totalStartedAt)
    end
    return true
end

function Layout:ApplyAllPlacements(options)
    local deferOverlay = type(options) == "table" and options.deferOverlay == true
    for _, id in ipairs(self.order) do
        local entry = self.frames[id]
        if entry then
            ApplyPlacement(entry, GetSavedPlacement(id) or ResolveDefaultPlacement(entry), true, {
                preserveFallback = entry.placementState == PLACEMENT_FALLBACK,
                deferOverlay = deferOverlay,
            })
        end
    end
end

function Layout:RetryPendingAnchors(allowFallback, useResolvedGroupTargets)
    local anyPending = false
    for id in pairs(self.pendingAnchors or {}) do
        local entry = self.frames[id]
        if not entry then
            self.pendingAnchors[id] = nil
        elseif entry.placementState == PLACEMENT_PENDING or entry.placementState == PLACEMENT_FALLBACK or entry.placementState == PLACEMENT_SIMULATED then
            local placement = entry.pendingPlacement or GetSavedPlacement(id) or ResolveDefaultPlacement(entry)
            local options = {
                allowFallback = allowFallback and entry.placementState == PLACEMENT_PENDING,
                preserveFallback = entry.placementState == PLACEMENT_FALLBACK,
            }
            local groupState = useResolvedGroupTargets
                and self.editing ~= true
                and entry.groupAnchorKind
                and self.groupAnchorTargetState[entry.groupAnchorKind]
            local relative = placement and placement.anchor and placement.anchor.relative
            if groupState and (relative == PARTY_ANCHOR_TARGET or relative == RAID_ANCHOR_TARGET) then
                options.resolvedAnchorProvided = true
                options.resolvedAnchorName = relative
                options.resolvedAnchorFrame = groupState.frame
                options.resolvedAnchorStatus = groupState.frame and PLACEMENT_READY or PLACEMENT_PENDING
            end
            ApplyPlacement(entry, placement, true, options)
            if entry.placementState == PLACEMENT_PENDING or entry.placementState == PLACEMENT_FALLBACK or entry.placementState == PLACEMENT_SIMULATED then
                anyPending = true
            else
                self.pendingAnchors[id] = nil
            end
        else
            self.pendingAnchors[id] = nil
        end
    end
    if anyPending then
        self:RefreshOverlays()
        self:RefreshMovementWidgets()
    else
        self.pendingAnchorRetryStep = 0
    end
    return anyPending
end

local GROUP_ROSTER_THROTTLE_SECONDS = 0.1
local ROSTER_LISTENER_PROBE_ID = "event.listener.GROUP_ROSTER_UPDATE.Layout:GROUP_ROSTER_UPDATE"
local cpuWatchdog = YUI.CPUWatchdog
local GROUP_ANCHOR_KINDS = {
    { "party", PARTY_ANCHOR_TARGET },
    { "raid", RAID_ANCHOR_TARGET },
}

Layout.groupAnchorEntries = Layout.groupAnchorEntries or {}
Layout.groupAnchorKindCounts = Layout.groupAnchorKindCounts or { party = 0, raid = 0 }
Layout.groupAnchorTargetState = Layout.groupAnchorTargetState or {}

local function BeginRosterStage()
    if not (cpuWatchdog and cpuWatchdog.timingActive == true) then return nil end
    return cpuWatchdog:BeginProbeTiming()
end

local function EndRosterStage(id, label, startedAt, parentId)
    if not startedAt then return end
    cpuWatchdog:EndProbeTiming(
        id,
        startedAt,
        label,
        parentId or ROSTER_LISTENER_PROBE_ID
    )
end

local function GeometryChanged(state, frame, left, bottom, width, height)
    return state.frame ~= frame
        or state.left ~= left
        or state.bottom ~= bottom
        or state.width ~= width
        or state.height ~= height
end

local function ResolveGroupAnchorState(kind, relative)
    local startedAt = BeginRosterStage()
    local frame, resolvedName, left, bottom, width, height
    if ResolveBuiltinAnchorTarget then
        frame, resolvedName, left, bottom, width, height =
            ResolveBuiltinAnchorTarget(relative)
    end
    EndRosterStage(
        "layout.group-roster.resolve",
        "Layout roster resolve",
        startedAt,
        "layout.group-roster.scan"
    )
    local state = Layout.groupAnchorTargetState[kind]
    if not state then
        state = {}
        Layout.groupAnchorTargetState[kind] = state
    end
    local initialized = state.initialized == true
    local identityChanged = initialized and state.frame ~= frame
    local geometryChanged = initialized and GeometryChanged(
        state,
        frame,
        left,
        bottom,
        width,
        height
    )
    state.initialized = true
    state.frame = frame
    state.left = left
    state.bottom = bottom
    state.width = width
    state.height = height
    return state, not initialized or identityChanged, geometryChanged and not identityChanged
end

-- Roster changes only invalidate dynamic group anchor providers. Entries already
-- waiting for an anchor stay on the shared pending retry path below.
local function RefreshReadyGroupAnchorPlacements()
    local counts = Layout.groupAnchorKindCounts
    if (counts.party or 0) <= 0 and (counts.raid or 0) <= 0 then
        return 0
    end

    local scanStartedAt = BeginRosterStage()
    local writes = 0
    for index = 1, #GROUP_ANCHOR_KINDS do
        local kind = GROUP_ANCHOR_KINDS[index][1]
        if (counts[kind] or 0) > 0 then
            local relative = GROUP_ANCHOR_KINDS[index][2]
            local state, mustReconcile, geometryChanged = ResolveGroupAnchorState(kind, relative)
            if mustReconcile or geometryChanged then
                for id, entry in pairs(Layout.groupAnchorEntries) do
                    if entry.groupAnchorKind == kind then
                        if entry.placementState ~= PLACEMENT_PENDING
                            and entry.placementState ~= PLACEMENT_FALLBACK
                            and entry.placementState ~= PLACEMENT_SIMULATED then
                            if entry.resolvedPlacementAnchorFrame ~= state.frame then
                                if entry.combatDeferredPlacement == nil then
                                    local placement = GetSavedPlacement(id)
                                        or ResolveDefaultPlacement(entry)
                                    local applyStartedAt = BeginRosterStage()
                                    if ApplyPlacement(entry, placement, true, {
                                        resolvedAnchorProvided = Layout.editing ~= true,
                                        resolvedAnchorName = relative,
                                        resolvedAnchorFrame = state.frame,
                                        resolvedAnchorStatus = state.frame and PLACEMENT_READY
                                            or PLACEMENT_PENDING,
                                    }) then
                                        writes = writes + 1
                                    end
                                    EndRosterStage(
                                        "layout.group-roster.apply",
                                        "Layout roster apply",
                                        applyStartedAt,
                                        "layout.group-roster.scan"
                                    )
                                end
                            elseif geometryChanged
                                and ResolveSpecValue(entry, "pixelAlignOrigin", false) == true
                                and Layout.RefreshPixelAlignedFrameIfNeeded then
                                local pixelStartedAt = BeginRosterStage()
                                Layout:RefreshPixelAlignedFrameIfNeeded(id)
                                EndRosterStage(
                                    "layout.group-roster.pixel",
                                    "Layout roster pixel alignment",
                                    pixelStartedAt,
                                    "layout.group-roster.scan"
                                )
                            end
                        end
                    end
                end
            end
        end
    end
    EndRosterStage("layout.group-roster.scan", "Layout roster indexed scan", scanStartedAt)
    return writes
end

function Layout:RegisterSettingsModule()
    self.settingsRegistered = true
    return false
end

local function OnLayoutRuntimeEvent(event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        if Layout:IsEditing() then
            Layout:CloseEditMode("combat")
        end
    elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Blizzard_EditMode" then
            Layout:TryHookNative()
        end
        Layout:RetryPendingAnchors(false)
    elseif event == "GROUP_ROSTER_UPDATE" then
        local pendingAnchors = Layout.pendingAnchors
        local hadPendingAnchors = pendingAnchors and next(pendingAnchors) ~= nil
        RefreshReadyGroupAnchorPlacements()
        if hadPendingAnchors then
            local pendingStartedAt = BeginRosterStage()
            Layout:RetryPendingAnchors(false, true)
            EndRosterStage(
                "layout.group-roster.pending",
                "Layout roster pending anchors",
                pendingStartedAt
            )
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        Layout:TryHookNative()
        if Layout.offscreenRecoveryPending and Layout.RecoverOffscreenPlacements then
            Layout:RecoverOffscreenPlacements(event)
            Layout.offscreenRecoveryPending = nil
        end
        ApplyCombatDeferredPlacements()
        Layout:RetryPendingAnchors(false)
    else
        Layout:TryHookNative()
        if OFFSCREEN_RECHECK_EVENTS[event] and Layout.RecoverOffscreenPlacements then
            if InCombat() then Layout.offscreenRecoveryPending = true end
            Layout:RecoverOffscreenPlacements(event)
        end
        Layout:ApplyAllPlacements()
        Layout:RetryPendingAnchors(false)
    end
end

Layout:TryHookNative()
Layout:RegisterMoveCommands()
if Event and Event.On then
    local function RegisterRuntimeEvent(event, throttle)
        Event:On(event, OnLayoutRuntimeEvent, Layout, {
            moduleId = MODULE_ID,
            traceName = "Layout:" .. event,
            throttle = throttle,
        })
    end
    RegisterRuntimeEvent("PLAYER_REGEN_DISABLED")
    RegisterRuntimeEvent("ADDON_LOADED")
    RegisterRuntimeEvent("PLAYER_LOGIN")
    RegisterRuntimeEvent("PLAYER_ENTERING_WORLD")
    RegisterRuntimeEvent("DISPLAY_SIZE_CHANGED")
    RegisterRuntimeEvent("UI_SCALE_CHANGED")
    RegisterRuntimeEvent("GROUP_ROSTER_UPDATE", GROUP_ROSTER_THROTTLE_SECONDS)
    RegisterRuntimeEvent("PLAYER_REGEN_ENABLED")
    RegisterRuntimeEvent("YUI_DB_READY")
end
SchedulePendingAnchorRetry(false)
