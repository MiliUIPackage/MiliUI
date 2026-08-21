do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - native bridge
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local Layout = YUI.Layout
local P = Layout._private
local SafeCall = P.SafeCall
local InCombat = P.InCombat
local L = P.L

local native = Layout.native
native.editModeClaims = native.editModeClaims or setmetatable({}, { __mode = "k" })
native.editModeClaimRefreshPending = native.editModeClaimRefreshPending == true
native.moveCommand = native.moveCommand or "/ymove"

local function HasOwners(state)
    return state and state.owners and next(state.owners) ~= nil
end

local function IsClaimed(systemFrame)
    return HasOwners(systemFrame and native.editModeClaims[systemFrame])
end

local function SetMouseInput(frame, enabled)
    if not frame then return true end
    local ok = true
    if type(frame.EnableMouse) == "function" then
        local readOK, current = true, nil
        if type(frame.IsMouseEnabled) == "function" then
            readOK, current = SafeCall("Layout:nativeEditModeReadMouse", frame.IsMouseEnabled, frame)
        end
        if not readOK or current ~= enabled then
            ok = SafeCall("Layout:nativeEditModeMouse", frame.EnableMouse, frame, enabled) and ok
        end
    end
    if type(frame.SetMouseClickEnabled) == "function" then
        local readOK, current = true, nil
        if type(frame.IsMouseClickEnabled) == "function" then
            readOK, current = SafeCall("Layout:nativeEditModeReadMouseClicks", frame.IsMouseClickEnabled, frame)
        end
        if not readOK or current ~= enabled then
            ok = SafeCall("Layout:nativeEditModeMouseClicks", frame.SetMouseClickEnabled, frame, enabled) and ok
        end
    end
    if type(frame.SetMouseMotionEnabled) == "function" then
        local readOK, current = true, nil
        if type(frame.IsMouseMotionEnabled) == "function" then
            readOK, current = SafeCall("Layout:nativeEditModeReadMouseMotion", frame.IsMouseMotionEnabled, frame)
        end
        if not readOK or current ~= enabled then
            ok = SafeCall("Layout:nativeEditModeMouseMotion", frame.SetMouseMotionEnabled, frame, enabled) and ok
        end
    end
    return ok
end

local function CaptureMouseInput(frame)
    if not frame then return nil end
    local state = {}
    if type(frame.IsMouseEnabled) == "function" then
        local ok, value = SafeCall("Layout:nativeEditModeReadMouse", frame.IsMouseEnabled, frame)
        if ok then state.mouse = value == true end
    end
    if type(frame.IsMouseClickEnabled) == "function" then
        local ok, value = SafeCall("Layout:nativeEditModeReadMouseClicks", frame.IsMouseClickEnabled, frame)
        if ok then state.mouseClicks = value == true end
    end
    if type(frame.IsMouseMotionEnabled) == "function" then
        local ok, value = SafeCall("Layout:nativeEditModeReadMouseMotion", frame.IsMouseMotionEnabled, frame)
        if ok then state.mouseMotion = value == true end
    end
    return state
end

local function RestoreMouseInput(frame, state)
    if not (frame and state) then return true end
    local ok = true
    if state.mouse ~= nil and type(frame.EnableMouse) == "function" then
        ok = SafeCall("Layout:nativeEditModeRestoreMouse", frame.EnableMouse, frame, state.mouse) and ok
    end
    if state.mouseClicks ~= nil and type(frame.SetMouseClickEnabled) == "function" then
        ok = SafeCall("Layout:nativeEditModeRestoreMouseClicks", frame.SetMouseClickEnabled, frame, state.mouseClicks) and ok
    end
    if state.mouseMotion ~= nil and type(frame.SetMouseMotionEnabled) == "function" then
        ok = SafeCall("Layout:nativeEditModeRestoreMouseMotion", frame.SetMouseMotionEnabled, frame, state.mouseMotion) and ok
    end
    return ok
end

local function GetMoveHint()
    local template = L("layout.native_edit_mode.move_hint")
    local ok, text = pcall(string.format, template, native.moveCommand or "/ymove")
    return ok and text or ("Use " .. tostring(native.moveCommand or "/ymove") .. " to move")
end

local function EnsureClaimOverlay(state, systemFrame, selection)
    if state.selection ~= selection then
        if state.selection and state.selectionState then
            RestoreMouseInput(state.selection, state.selectionState)
        end
        if state.overlay then state.overlay:Hide() end
        state.selection = selection
        state.selectionState = CaptureMouseInput(selection)
        state.overlay = nil
        state.label = nil
    end
    if state.selectionState == nil then
        state.selectionState = CaptureMouseInput(selection)
    end
    if state.overlay then return state.overlay end
    if type(CreateFrame) ~= "function" then return nil end

    local overlay = CreateFrame("Frame", nil, selection)
    if type(overlay.SetIgnoreParentAlpha) == "function" then overlay:SetIgnoreParentAlpha(true) end
    if type(overlay.SetIgnoreParentScale) == "function" then overlay:SetIgnoreParentScale(true) end
    if type(overlay.SetSize) == "function" then overlay:SetSize(220, 24) end
    if type(overlay.SetPoint) == "function" then
        overlay:SetPoint("CENTER", systemFrame, "CENTER", 0, 0)
    end
    if type(selection.GetFrameStrata) == "function" and type(overlay.SetFrameStrata) == "function" then
        local ok, strata = SafeCall("Layout:nativeEditModeReadStrata", selection.GetFrameStrata, selection)
        if ok and strata then overlay:SetFrameStrata(strata) end
    end
    if type(selection.GetFrameLevel) == "function" and type(overlay.SetFrameLevel) == "function" then
        local ok, level = SafeCall("Layout:nativeEditModeReadLevel", selection.GetFrameLevel, selection)
        if ok and type(level) == "number" then overlay:SetFrameLevel(level + 10) end
    end
    SetMouseInput(overlay, false)

    local label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    label:SetWidth(220)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    if type(label.SetIgnoreParentScale) == "function" then label:SetIgnoreParentScale(true) end
    label:SetTextColor(1, 0.22, 0.08, 1)
    label:SetText(GetMoveHint())

    state.overlay = overlay
    state.label = label
    return overlay
end

local function RestoreClaimState(state)
    local ok = true
    if state.overlay then state.overlay:Hide() end
    if state.selection and state.selectionState then
        ok = RestoreMouseInput(state.selection, state.selectionState) and ok
    end
    if state.resizeFrame and state.resizeState then
        ok = RestoreMouseInput(state.resizeFrame, state.resizeState) and ok
    end
    state.selectionState = nil
    state.resizeFrame = nil
    state.resizeState = nil
    state.applied = false
    return ok
end

local ClearClaimedSystemSelection

local function ApplyClaimState(systemFrame, state)
    local selection = systemFrame and systemFrame.Selection
    if not selection then
        native.editModeClaimRefreshPending = true
        return false, "native-edit-mode-selection-unavailable"
    end
    if InCombat and InCombat() then
        native.editModeClaimRefreshPending = true
        return false, "combat-deferred"
    end

    local overlay = EnsureClaimOverlay(state, systemFrame, selection)
    if not overlay then return false, "native-edit-mode-overlay-unavailable" end
    if state.label then state.label:SetText(GetMoveHint()) end
    local selectionOK = SetMouseInput(selection, false)
    overlay:Show()

    local resizeFrame = systemFrame.EditModeResizeButton
    if state.resizeFrame ~= resizeFrame then
        if state.resizeFrame and state.resizeState then
            RestoreMouseInput(state.resizeFrame, state.resizeState)
        end
        state.resizeFrame = resizeFrame
        state.resizeState = CaptureMouseInput(resizeFrame)
    end
    local resizeOK = not resizeFrame or SetMouseInput(resizeFrame, false)
    state.applied = selectionOK and resizeOK
    if not state.applied then
        RestoreClaimState(state)
        return false, "native-edit-mode-input-lock-failed"
    end
    if ClearClaimedSystemSelection then
        ClearClaimedSystemSelection(_G.EditModeManagerFrame, systemFrame)
    end
    return true
end

function Layout:RefreshNativeEditModeClaims()
    if InCombat and InCombat() then
        native.editModeClaimRefreshPending = true
        return false, "combat-deferred"
    end
    native.editModeClaimRefreshPending = false
    local ok = true
    for systemFrame, state in pairs(native.editModeClaims) do
        if HasOwners(state) then
            local applied = ApplyClaimState(systemFrame, state)
            ok = applied and ok
        elseif state.applied or state.selectionState or state.resizeState then
            ok = RestoreClaimState(state) and ok
        end
    end
    return ok
end

function Layout:SetNativeEditModeClaim(owner, systemFrame, claimed)
    if owner == nil then return false, "owner-required" end
    if systemFrame == nil then return false, "system-frame-required" end

    local state = native.editModeClaims[systemFrame]
    if not state then
        if claimed ~= true then return true end
        state = { owners = setmetatable({}, { __mode = "k" }) }
        native.editModeClaims[systemFrame] = state
    end
    if claimed == true then
        if state.owners[owner] == true then
            if state.applied == true and state.selection == systemFrame.Selection then return true end
            local applied, reason = ApplyClaimState(systemFrame, state)
            return true, applied and nil or (reason or "native-edit-mode-claim-pending")
        end
        state.owners[owner] = true
        self:TryHookNative()
        local applied, reason = ApplyClaimState(systemFrame, state)
        return true, applied and nil or (reason or "native-edit-mode-claim-pending")
    end

    if state.owners[owner] == nil then return true end
    state.owners[owner] = nil
    if HasOwners(state) then return true end
    if InCombat and InCombat() then
        native.editModeClaimRefreshPending = true
        return false, "combat-deferred"
    end
    return RestoreClaimState(state)
end

function Layout:ReleaseNativeEditModeOwner(owner)
    if owner == nil then return false, "owner-required" end
    local ok = true
    for _, state in pairs(native.editModeClaims) do
        if state.owners and state.owners[owner] ~= nil then
            state.owners[owner] = nil
            if not HasOwners(state) then
                if InCombat and InCombat() then
                    native.editModeClaimRefreshPending = true
                    ok = false
                else
                    ok = RestoreClaimState(state) and ok
                end
            end
        end
    end
    return ok, ok and nil or "combat-deferred"
end

ClearClaimedSystemSelection = function(manager, systemFrame)
    if not IsClaimed(systemFrame) then return end
    if systemFrame.isSelected == true and manager and type(manager.ClearSelectedSystem) == "function" then
        SafeCall("Layout:nativeEditModeClearSelection", manager.ClearSelectedSystem, manager)
    end
    local dialog = _G.EditModeSystemSettingsDialog
    if dialog and dialog.attachedToSystem == systemFrame and type(dialog.Hide) == "function" then
        SafeCall("Layout:nativeEditModeHideSettings", dialog.Hide, dialog)
    end
end

local function HideClaimedSystemSettings(dialog, systemFrame)
    if IsClaimed(systemFrame) and dialog and type(dialog.Hide) == "function" then
        SafeCall("Layout:nativeEditModeHideAttachedSettings", dialog.Hide, dialog)
    end
end

local function RefreshClaimsOnNativeEditModeEnter()
    Layout:RefreshNativeEditModeClaims()
end

local function OnNativeUnsavedDialogHidden()
    if native.moveOpenPending ~= true then return end
    local manager = _G.EditModeManagerFrame
    if manager and type(manager.IsEditModeActive) == "function" then
        local ok, active = SafeCall("Layout:nativeEditModeReadActive", manager.IsEditModeActive, manager)
        if ok and active == true then native.moveOpenPending = false end
    end
end

local function OpenMoveModeNow()
    Layout:OpenEditMode("ymove")
end

local function OpenMoveModeAfterNativeExit()
    if native.moveOpenPending ~= true then return end
    native.moveOpenPending = false
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, OpenMoveModeNow)
    else
        OpenMoveModeNow()
    end
end

local function CancelMoveModeTransition()
    native.moveOpenPending = false
end

local function EnsureNativeEditModeHooks()
    local hook = _G.hooksecurefunc
    local manager = _G.EditModeManagerFrame
    if type(hook) == "function"
        and manager
        and type(manager.SelectSystem) == "function"
        and native.selectSystemHooked ~= true
    then
        native.selectSystemHooked = pcall(hook, manager, "SelectSystem", ClearClaimedSystemSelection) == true
    end
    local dialog = _G.EditModeSystemSettingsDialog
    if type(hook) == "function"
        and dialog
        and type(dialog.AttachToSystemFrame) == "function"
        and native.settingsDialogHooked ~= true
    then
        native.settingsDialogHooked = pcall(hook, dialog, "AttachToSystemFrame", HideClaimedSystemSettings) == true
    end
    local unsaved = _G.EditModeUnsavedChangesDialog
    if unsaved and type(unsaved.HookScript) == "function" and native.unsavedDialogHooked ~= true then
        native.unsavedDialogHooked = SafeCall(
            "Layout:nativeEditModeUnsavedDialogHook",
            unsaved.HookScript,
            unsaved,
            "OnHide",
            OnNativeUnsavedDialogHidden
        ) == true
    end
    local registry = _G.EventRegistry
    if registry and type(registry.RegisterCallback) == "function" then
        if native.enterClaimCallbackRegistered ~= true then
            native.enterClaimCallbackRegistered = SafeCall(
                "Layout:nativeEditModeEnterClaimCallback",
                registry.RegisterCallback,
                registry,
                "EditMode.Enter",
                RefreshClaimsOnNativeEditModeEnter,
                Layout
            ) == true
        end
        if native.exitCallbackRegistered ~= true then
            native.exitCallbackRegistered = SafeCall(
                "Layout:nativeEditModeExitCallback",
                registry.RegisterCallback,
                registry,
                "EditMode.Exit",
                OpenMoveModeAfterNativeExit,
                Layout
            ) == true
        end
        if native.cancelCallbackRegistered ~= true then
            native.cancelCallbackRegistered = SafeCall(
                "Layout:nativeEditModeCancelCallback",
                registry.RegisterCallback,
                registry,
                "EditMode.NewLayoutCancel",
                CancelMoveModeTransition,
                Layout
            ) == true
        end
    end
    return native.selectSystemHooked == true
        or native.settingsDialogHooked == true
        or native.enterClaimCallbackRegistered == true
end

function Layout:RequestMoveMode(source)
    native.moveOpenPending = native.moveOpenPending == true
    if InCombat and InCombat() then
        native.moveOpenPending = false
        return self:OpenEditMode(source or "ymove")
    end
    if self.editing == true then
        return self:OpenEditMode(source or "ymove")
    end

    local manager = _G.EditModeManagerFrame
    local active = false
    if manager and type(manager.IsEditModeActive) == "function" then
        local ok, value = SafeCall("Layout:nativeEditModeRequestReadActive", manager.IsEditModeActive, manager)
        active = ok and value == true
    elseif manager and type(manager.IsShown) == "function" then
        local ok, value = SafeCall("Layout:nativeEditModeRequestReadShown", manager.IsShown, manager)
        active = ok and value == true
    end
    if not active then return self:OpenEditMode(source or "ymove") end
    if native.moveOpenPending then
        return false, "native-edit-mode-exit-pending"
    end

    EnsureNativeEditModeHooks()
    if native.exitCallbackRegistered ~= true then
        return false, "native-edit-mode-exit-callback-unavailable"
    end
    if type(manager.HasActiveChanges) == "function" then
        local ok, hasChanges = SafeCall(
            "Layout:nativeEditModeRequestReadChanges",
            manager.HasActiveChanges,
            manager
        )
        if ok and hasChanges == true and native.unsavedDialogHooked ~= true then
            return false, "native-edit-mode-cancel-hook-unavailable"
        end
    end
    if type(manager.onCloseCallback) ~= "function" then
        native.moveOpenPending = false
        return false, "native-edit-mode-close-unavailable"
    end
    native.moveOpenPending = true
    local ok = SafeCall("Layout:nativeEditModeRequestClose", manager.onCloseCallback)
    if not ok then native.moveOpenPending = false end
    return ok, ok and "native-edit-mode-exit-pending" or "native-edit-mode-close-failed"
end

function Layout:RegisterMoveCommands()
    if native.moveCommandsRegistered == true then return true end
    native.moveCommandsRegistered = true

    local previousSlashHandler = YUI.HandleSlashCommand
    function YUI:HandleSlashCommand(message)
        local command = tostring(message or ""):lower():match("^%s*(.-)%s*$") or ""
        if command == "move" then
            Layout:RequestMoveMode("yui-move")
            return true
        end
        if previousSlashHandler then return previousSlashHandler(self, message) end
        return false
    end

    local registered = false
    if YUI.Commands and type(YUI.Commands.Register) == "function" then
        registered = YUI.Commands:Register({
            id = "layout-move",
            productId = YUI.CoreMode == "suite" and "suite" or YUI.ProductId,
            aliases = { "/ymove" },
            handler = function()
                Layout:RequestMoveMode("ymove")
            end,
        }) == true
    end
    native.moveCommand = registered and "/ymove" or "/yui move"
    for _, state in pairs(native.editModeClaims) do
        if state.label then state.label:SetText(GetMoveHint()) end
    end
    return registered
end

local function NativeBridgeEnabled()
    return Layout.native and Layout.native.bridgeEnabled == true
end
P.NativeBridgeEnabled = NativeBridgeEnabled

local function NativeSetSnapPreview(frame)
    if not NativeBridgeEnabled() then return end
    local manager = _G.EditModeManagerFrame
    if manager and manager.SetSnapPreviewFrame then
        SafeCall("Layout:nativeSetSnapPreview", manager.SetSnapPreviewFrame, manager, frame)
    end
end
P.NativeSetSnapPreview = NativeSetSnapPreview

local function NativeClearSnapPreview()
    if not NativeBridgeEnabled() then return end
    local manager = _G.EditModeManagerFrame
    if manager and manager.ClearSnapPreviewFrame then
        SafeCall("Layout:nativeClearSnapPreview", manager.ClearSnapPreviewFrame, manager)
    end
end
P.NativeClearSnapPreview = NativeClearSnapPreview

local function NativeApplyMagnetism(frame)
    if not NativeBridgeEnabled() then return end
    local magnetism = _G.EditModeMagnetismManager
    if magnetism and magnetism.ApplyMagnetism then
        SafeCall("Layout:nativeApplyMagnetism", magnetism.ApplyMagnetism, magnetism, frame)
    end
end
P.NativeApplyMagnetism = NativeApplyMagnetism

function Layout:TryHookNative()
    local manager = _G.EditModeManagerFrame
    self.native.available = (_G.C_EditMode ~= nil and manager ~= nil)
    self.native.hasSelectionTemplate = _G.EditModeSystemSelectionTemplate ~= nil
    self.native.hasMagnetism = _G.EditModeMagnetismManager ~= nil
    self.native.managerDetected = manager ~= nil
    self.native.bridgeMode = "separate"
    self.native.bridgeEnabled = false
    self.native.hooked = EnsureNativeEditModeHooks()
    if self.native.editModeClaimRefreshPending and not (InCombat and InCombat()) then
        self:RefreshNativeEditModeClaims()
    end
    if self.native.editModeLoadContinuationRegistered ~= true
        and _G.EventUtil
        and type(_G.EventUtil.ContinueOnAddOnLoaded) == "function"
    then
        self.native.editModeLoadContinuationRegistered = true
        _G.EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", function()
            Layout:TryHookNative()
        end)
    end
    return self.native.available
end
