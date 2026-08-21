do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - init
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI then return end

local Layout = YUI.Layout or {}
YUI.Layout = Layout
Layout._private = Layout._private or {}
local P = Layout._private

local GUI2 = YUI.GUI2
local Assets = YUI.Assets
local LC = YUI.Locale and YUI.Locale:Get("Core") or {}
local Event = YUI.Event
local Security = YUI.API and YUI.API.Security

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown
local IsShiftKeyDown = IsShiftKeyDown
local IsMouseButtonDown = IsMouseButtonDown
local GetMouseFocus = GetMouseFocus
local GetMouseFoci = GetMouseFoci
local GetTime = GetTime
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local tonumber = tonumber
local tinsert = table.insert
local tremove = table.remove
local math_abs = math.abs
local math_floor = math.floor
local math_ceil = math.ceil
local math_min = math.min
local math_max = math.max
local math_pi = math.pi
local math_sqrt = math.sqrt
local string_find = string.find
local string_gsub = string.gsub

local MODULE_ID = "core.layout"
local DB_VERSION = 2
local GRID_SPACING = 64
local DEFAULT_GRID_DENSITY = "medium"
local GRID_DENSITY_SPACING = { veryLow = 128, low = 96, medium = 64, high = 48, veryHigh = 32 }
local SNAP_RANGE = 8
local MIN_OVERLAY_SIZE = 24
local MOVER_REFRESH_INTERVAL = 0.05
local OFFSET_MIN = -2000
local OFFSET_MAX = 2000
local OVERLAY_STRATA = "HIGH"
local MOVER_PANEL_STRATA = "HIGH"
local OVERLAY_FRAME_LEVEL = 40
local SELECTED_OVERLAY_FRAME_LEVEL = 60
local ANCHOR_OVERLAY_FRAME_LEVEL = 55
local ANCHOR_LINE_FRAME_LEVEL = 50
local ANCHOR_DOT_FRAME_LEVEL = 65
local MOVER_PANEL_FRAME_LEVEL = 80
local OVERLAY_BORDER = "color.border.accent"
local SELECTED_BORDER = "color.border.focus"
local ARROW_TEXTURE = Assets and Assets.Core and Assets:Core("gui2\\glyphs\\nudge-arrow-up-16.tga") or "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up"
local PRODUCT_ID = YUI.ProductId or "suite"
local MOVER_COLOR_NORMAL = { 0.10, 0.62, 1.00, 0.95 }
local MOVER_COLOR_SELECTED = { 1.00, 0.82, 0.00, 1.00 }
local MOVER_COLOR_ANCHOR = { 0.20, 0.86, 0.42, 1.00 }
local MOVER_COLOR_SIMULATED = { 1.00, 0.30, 0.22, 1.00 }
local MOVER_COLOR_PLACEHOLDER = { 0.08, 0.78, 1.00, 0.95 }
local MOVER_BG_NORMAL = { 0.01, 0.025, 0.045, 0.38 }
local MOVER_BG_SELECTED = { 0.06, 0.045, 0.005, 0.42 }
local MOVER_BG_ANCHOR = { 0.01, 0.05, 0.02, 0.40 }
local MOVER_BG_SIMULATED = { 0.06, 0.01, 0.01, 0.42 }
local MOVER_BG_PLACEHOLDER = { 0.08, 0.62, 1.00, 0.18 }
local PLACEMENT_READY = "ready"
local PLACEMENT_PENDING = "pending"
local PLACEMENT_FALLBACK = "fallback"
local PLACEMENT_SIMULATED = "simulated"
local ANCHOR_GUIDE_DOT_SIZE = 2
local ANCHOR_GUIDE_DOT_SPACING = 8
local ANCHOR_LINE_MIN_DISTANCE = 18
local ANCHOR_DOT_SIZE = 8
local ANCHOR_DOT_ALPHA = 0.50
local ANCHOR_DOT_TEXTURE = Assets and Assets.Core and Assets:Core("gui2\\glyphs\\layout-anchor-dot-16.tga") or "Interface\\COMMON\\Indicator-Gray"
local ANCHOR_POINTS = {
    "TOPLEFT", "TOP", "TOPRIGHT",
    "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT",
}
local ANCHOR_POINT_LABEL_KEYS = {
    TOPLEFT = "layout.anchor_point.top_left",
    TOP = "layout.anchor_point.top",
    TOPRIGHT = "layout.anchor_point.top_right",
    LEFT = "layout.anchor_point.left",
    CENTER = "layout.anchor_point.center",
    RIGHT = "layout.anchor_point.right",
    BOTTOMLEFT = "layout.anchor_point.bottom_left",
    BOTTOM = "layout.anchor_point.bottom",
    BOTTOMRIGHT = "layout.anchor_point.bottom_right",
}

Layout.frames = Layout.frames or {}
Layout.order = Layout.order or {}
Layout.editing = Layout.editing == true
Layout.selectedId = Layout.selectedId
Layout.native = Layout.native or {}
if Layout.native.bridgeEnabled == nil then Layout.native.bridgeEnabled = false end
Layout.native.bridgeMode = Layout.native.bridgeMode or "separate"
Layout.settingsWidgets = Layout.settingsWidgets or {}
P.GUI2 = GUI2
P.Assets = Assets
P.LC = LC
P.Event = Event
P.Security = Security
P.CreateFrame = CreateFrame
P.UIParent = UIParent
P.C_Timer = C_Timer
P.InCombatLockdown = InCombatLockdown
P.IsShiftKeyDown = IsShiftKeyDown
P.IsMouseButtonDown = IsMouseButtonDown
P.GetMouseFocus = GetMouseFocus
P.GetMouseFoci = GetMouseFoci
P.GetTime = GetTime
P.pairs = pairs
P.ipairs = ipairs
P.type = type
P.tostring = tostring
P.tonumber = tonumber
P.tinsert = tinsert
P.tremove = tremove
P.math_abs = math_abs
P.math_floor = math_floor
P.math_ceil = math_ceil
P.math_min = math_min
P.math_max = math_max
P.math_pi = math_pi
P.math_sqrt = math_sqrt
P.string_find = string_find
P.string_gsub = string_gsub
P.MODULE_ID = MODULE_ID
P.DB_VERSION = DB_VERSION
P.GRID_SPACING = GRID_SPACING
P.DEFAULT_GRID_DENSITY = DEFAULT_GRID_DENSITY
P.GRID_DENSITY_SPACING = GRID_DENSITY_SPACING
P.SNAP_RANGE = SNAP_RANGE
P.MIN_OVERLAY_SIZE = MIN_OVERLAY_SIZE
P.MOVER_REFRESH_INTERVAL = MOVER_REFRESH_INTERVAL
P.OFFSET_MIN = OFFSET_MIN
P.OFFSET_MAX = OFFSET_MAX
P.OVERLAY_STRATA = OVERLAY_STRATA
P.MOVER_PANEL_STRATA = MOVER_PANEL_STRATA
P.OVERLAY_FRAME_LEVEL = OVERLAY_FRAME_LEVEL
P.SELECTED_OVERLAY_FRAME_LEVEL = SELECTED_OVERLAY_FRAME_LEVEL
P.ANCHOR_OVERLAY_FRAME_LEVEL = ANCHOR_OVERLAY_FRAME_LEVEL
P.ANCHOR_LINE_FRAME_LEVEL = ANCHOR_LINE_FRAME_LEVEL
P.ANCHOR_DOT_FRAME_LEVEL = ANCHOR_DOT_FRAME_LEVEL
P.MOVER_PANEL_FRAME_LEVEL = MOVER_PANEL_FRAME_LEVEL
P.OVERLAY_BORDER = OVERLAY_BORDER
P.SELECTED_BORDER = SELECTED_BORDER
P.ARROW_TEXTURE = ARROW_TEXTURE
P.PRODUCT_ID = PRODUCT_ID
P.MOVER_COLOR_NORMAL = MOVER_COLOR_NORMAL
P.MOVER_COLOR_SELECTED = MOVER_COLOR_SELECTED
P.MOVER_COLOR_ANCHOR = MOVER_COLOR_ANCHOR
P.MOVER_COLOR_SIMULATED = MOVER_COLOR_SIMULATED
P.MOVER_COLOR_PLACEHOLDER = MOVER_COLOR_PLACEHOLDER
P.MOVER_BG_NORMAL = MOVER_BG_NORMAL
P.MOVER_BG_SELECTED = MOVER_BG_SELECTED
P.MOVER_BG_ANCHOR = MOVER_BG_ANCHOR
P.MOVER_BG_SIMULATED = MOVER_BG_SIMULATED
P.MOVER_BG_PLACEHOLDER = MOVER_BG_PLACEHOLDER
P.PLACEMENT_READY = PLACEMENT_READY
P.PLACEMENT_PENDING = PLACEMENT_PENDING
P.PLACEMENT_FALLBACK = PLACEMENT_FALLBACK
P.PLACEMENT_SIMULATED = PLACEMENT_SIMULATED
P.ANCHOR_GUIDE_DOT_SIZE = ANCHOR_GUIDE_DOT_SIZE
P.ANCHOR_GUIDE_DOT_SPACING = ANCHOR_GUIDE_DOT_SPACING
P.ANCHOR_LINE_MIN_DISTANCE = ANCHOR_LINE_MIN_DISTANCE
P.ANCHOR_DOT_SIZE = ANCHOR_DOT_SIZE
P.ANCHOR_DOT_ALPHA = ANCHOR_DOT_ALPHA
P.ANCHOR_DOT_TEXTURE = ANCHOR_DOT_TEXTURE
P.ANCHOR_POINTS = ANCHOR_POINTS

Layout.frames = Layout.frames or {}
Layout.order = Layout.order or {}
Layout.editing = Layout.editing == true
Layout.selectedId = Layout.selectedId
Layout.native = Layout.native or {}
if Layout.native.bridgeEnabled == nil then Layout.native.bridgeEnabled = false end
Layout.native.bridgeMode = Layout.native.bridgeMode or "separate"
Layout.settingsWidgets = Layout.settingsWidgets or {}
Layout.pendingOptions = Layout.pendingOptions or {}
Layout.pendingAnchors = Layout.pendingAnchors or {}
Layout.combatDeferredPlacements = Layout.combatDeferredPlacements or {}
Layout.groupAnchorEntries = Layout.groupAnchorEntries or {}
Layout.groupAnchorKindCounts = Layout.groupAnchorKindCounts or { party = 0, raid = 0 }
Layout.groupAnchorTargetState = Layout.groupAnchorTargetState or {}

function P.L(key)
    return LC[key] or key
end

function P.AnchorPointDisplayText(point)
    local key = ANCHOR_POINT_LABEL_KEYS[point]
    return key and P.L(key) or tostring(point or "")
end

function P.Round(value)
    value = tonumber(value) or 0
    if value >= 0 then
        return math_floor(value + 0.5)
    end
    return math_ceil(value - 0.5)
end

function P.SafeCall(label, func, ...)
    if type(func) ~= "function" then
        return false, "not a function"
    end
    if Security and Security.SafeCall then
        return Security.SafeCall(label, func, ...)
    end
    return pcall(func, ...)
end

function P.InCombat()
    if Security and Security.InCombatLockdown then
        return Security.InCombatLockdown() == true
    end
    if InCombatLockdown then
        return InCombatLockdown() == true
    end
    return false
end

function P.Print(message)
    if YUI.Print then
        YUI:Print(message)
    else
        print(message)
    end
end

function P.FrameName(frame)
    if frame == UIParent then return "UIParent" end
    if frame and frame.GetName then
        local name = frame:GetName()
        if name and name ~= "" then return name end
    end
    return "UIParent"
end

function P.ResolveFrameRef(ref)
    if ref == nil or ref == "" or ref == "UIParent" then return UIParent end
    if type(ref) == "string" then return _G[ref] or UIParent end
    if type(ref) == "table" then return ref end
    return UIParent
end
