local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
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
local GetSavedPlacement = P.GetSavedPlacement
local ApplyPlacement = P.ApplyPlacement
local HideAnchorLine = P.HideAnchorLine
local NativeClearSnapPreview = P.NativeClearSnapPreview
local HideBuiltinAnchorPlaceholders = P.HideBuiltinAnchorPlaceholders
local PLACEMENT_PENDING = P.PLACEMENT_PENDING
local PLACEMENT_FALLBACK = P.PLACEMENT_FALLBACK
local PLACEMENT_SIMULATED = P.PLACEMENT_SIMULATED
local pairs = P.pairs
local ipairs = P.ipairs
local type = P.type
local tostring = P.tostring

local PENDING_ANCHOR_RETRY_DELAYS = { 0.2, 1, 3, 5 }

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
        Settings:Close()
    end
end

local function RestoreSettingsAfterEditMode(source)
    local state = Layout.settingsRestoreState
    Layout.settingsRestoreState = nil
    if not state or source == "combat" then
        return
    end
    local Settings = YUI.Settings
    if Settings and Settings.Open then
        Settings:Open(state)
    end
end

function Layout:OpenEditMode(source)
    if InCombat() then
        Print(L("layout.message.combat_blocked"))
        return false
    end
    if self.editing then
        self:RefreshOverlays()
        self:RefreshOverlayVisuals()
        self:ShowControlPanel()
        return true
    end

    CloseSettingsForEditMode()
    self.editing = true
    self.editSource = source or "yui"
    self.hiddenMoverOverlayIds = nil
    if not self.selectedId then self.selectedId = self.order[1] end
    self:ApplyAllPlacements()
    for _, id in ipairs(self.order) do
        local entry = self.frames[id]
        if entry and ResolveSpecValue(entry, "showOnlyInEditMode", false) == true then
            local frame = ResolveEntryFrame(entry)
            if frame and entry.placementState ~= PLACEMENT_PENDING and ResolveSpecValue(entry, "isEnabled", true) ~= false then frame:Show() end
        end
        if entry and type(entry.spec.onEnterEditMode) == "function" then
            SafeCall("Layout:onEnter:" .. tostring(id), entry.spec.onEnterEditMode, ResolveEntryFrame(entry), entry, self)
        end
    end
    self:RefreshOverlays()
    self:RefreshOverlayVisuals()
    self:ShowControlPanel()
    self:UpdateGrid()
    if Event and Event.Emit then Event:Emit("YUI_LAYOUT_EDIT_MODE_OPENED", source or "yui") end
    return true
end

function Layout:CloseEditMode(source)
    if not self.editing then return true end
    self.editing = false
    self.editSource = nil
    self.hiddenMoverOverlayIds = nil
    if HideBuiltinAnchorPlaceholders then HideBuiltinAnchorPlaceholders() end
    self:ApplyAllPlacements()
    for _, id in ipairs(self.order) do
        local entry = self.frames[id]
        if entry and entry.overlay then
            entry.overlay:Hide()
            entry.overlay:SetScript("OnUpdate", nil)
        end
        if entry and type(entry.spec.onExitEditMode) == "function" then
            SafeCall("Layout:onExit:" .. tostring(id), entry.spec.onExitEditMode, ResolveEntryFrame(entry), entry, self)
        end
        if entry and ResolveSpecValue(entry, "showOnlyInEditMode", false) == true then
            local frame = ResolveEntryFrame(entry)
            if frame then frame:Hide() end
        end
    end
    self:HideControlPanel()
    self:HideMoverPanel()
    self:HideGrid()
    HideAnchorLine()
    NativeClearSnapPreview()
    if Event and Event.Emit then Event:Emit("YUI_LAYOUT_EDIT_MODE_CLOSED", source or "yui") end
    RestoreSettingsAfterEditMode(source)
    return true
end

function Layout:ApplyAllPlacements()
    for _, id in ipairs(self.order) do
        local entry = self.frames[id]
        if entry then
            ApplyPlacement(entry, GetSavedPlacement(id) or ResolveDefaultPlacement(entry), true, {
                preserveFallback = entry.placementState == PLACEMENT_FALLBACK,
            })
        end
    end
end

function Layout:RetryPendingAnchors(allowFallback)
    local anyPending = false
    for id in pairs(self.pendingAnchors or {}) do
        local entry = self.frames[id]
        if not entry then
            self.pendingAnchors[id] = nil
        elseif entry.placementState == PLACEMENT_PENDING or entry.placementState == PLACEMENT_FALLBACK or entry.placementState == PLACEMENT_SIMULATED then
            ApplyPlacement(entry, entry.pendingPlacement or GetSavedPlacement(id) or ResolveDefaultPlacement(entry), true, {
                allowFallback = allowFallback and entry.placementState == PLACEMENT_PENDING,
                preserveFallback = entry.placementState == PLACEMENT_FALLBACK,
            })
            if entry.placementState == PLACEMENT_PENDING or entry.placementState == PLACEMENT_FALLBACK or entry.placementState == PLACEMENT_SIMULATED then
                anyPending = true
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
    else
        Layout:TryHookNative()
        Layout:ApplyAllPlacements()
        Layout:RetryPendingAnchors(false)
    end
end

Layout:TryHookNative()
if Event and Event.On then
    Event:On("PLAYER_REGEN_DISABLED", OnLayoutRuntimeEvent, Layout, { moduleId = MODULE_ID })
    Event:On("ADDON_LOADED", OnLayoutRuntimeEvent, Layout, { moduleId = MODULE_ID })
    Event:On("PLAYER_LOGIN", OnLayoutRuntimeEvent, Layout, { moduleId = MODULE_ID })
    Event:On("PLAYER_ENTERING_WORLD", OnLayoutRuntimeEvent, Layout, { moduleId = MODULE_ID })
    Event:On("GROUP_ROSTER_UPDATE", OnLayoutRuntimeEvent, Layout, { moduleId = MODULE_ID })
    Event:On("PLAYER_REGEN_ENABLED", OnLayoutRuntimeEvent, Layout, { moduleId = MODULE_ID })
    Event:On("YUI_DB_READY", OnLayoutRuntimeEvent, Layout, { moduleId = MODULE_ID })
end
SchedulePendingAnchorRetry(false)
