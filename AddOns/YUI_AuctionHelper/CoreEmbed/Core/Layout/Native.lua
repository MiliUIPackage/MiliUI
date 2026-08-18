local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - native bridge
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local Layout = YUI.Layout
local P = Layout._private
local SafeCall = P.SafeCall

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
    -- Keep Blizzard Edit Mode separate for now; retain capability flags for a future bridge.
    local manager = _G.EditModeManagerFrame
    self.native.available = (_G.C_EditMode ~= nil and manager ~= nil)
    self.native.hasSelectionTemplate = _G.EditModeSystemSelectionTemplate ~= nil
    self.native.hasMagnetism = _G.EditModeMagnetismManager ~= nil
    self.native.managerDetected = manager ~= nil
    self.native.bridgeMode = "separate"
    self.native.bridgeEnabled = false
    self.native.hooked = false
    return self.native.available
end
