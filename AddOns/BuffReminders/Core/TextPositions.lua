local _, BR = ...

-- ============================================================================
-- TEXT POSITIONS
-- ============================================================================
-- Resolves per-text-item placement on buff icons. A "zone" is one of fifteen
-- semantic positions (3 vertical bands x 3 horizontal columns + INSIDE_C),
-- plus an optional pixel nudge. Display sites call Apply() instead of writing
-- raw SetPoint anchors so users can re-arrange overlapping text via Options.
--
-- Storage is global only: defaults.textPositions[item] where item is one of
-- count, stackCount, statLabel, badge, buffReminder. Per-category storage was
-- considered but dropped - each item has exactly one realistic consumer.

BR.TextPositions = {}

-- Each zone holds the SetPoint args + a baseline nudge so text doesn't kiss
-- the icon edge. Users add their own fine offset on top.
local ZONES = {
    -- INSIDE: anchored to a point of the icon itself (inset by a few pixels)
    INSIDE_TL = { point = "TOPLEFT", relPoint = "TOPLEFT", dx = 2, dy = -2 },
    INSIDE_T = { point = "TOP", relPoint = "TOP", dx = 0, dy = -2 },
    INSIDE_TR = { point = "TOPRIGHT", relPoint = "TOPRIGHT", dx = -2, dy = -2 },
    INSIDE_L = { point = "LEFT", relPoint = "LEFT", dx = 2, dy = 0 },
    INSIDE_C = { point = "CENTER", relPoint = "CENTER", dx = 0, dy = 0 },
    INSIDE_R = { point = "RIGHT", relPoint = "RIGHT", dx = -2, dy = 0 },
    INSIDE_BL = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", dx = 2, dy = 2 },
    INSIDE_B = { point = "BOTTOM", relPoint = "BOTTOM", dx = 0, dy = 2 },
    INSIDE_BR = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", dx = -2, dy = 2 },
    -- ABOVE: text's bottom edge anchored to icon's top
    ABOVE_L = { point = "BOTTOMLEFT", relPoint = "TOPLEFT", dx = 0, dy = 4 },
    ABOVE_C = { point = "BOTTOM", relPoint = "TOP", dx = 0, dy = 4 },
    ABOVE_R = { point = "BOTTOMRIGHT", relPoint = "TOPRIGHT", dx = 0, dy = 4 },
    -- BELOW: text's top edge anchored to icon's bottom
    BELOW_L = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", dx = 0, dy = -4 },
    BELOW_C = { point = "TOP", relPoint = "BOTTOM", dx = 0, dy = -4 },
    BELOW_R = { point = "TOPRIGHT", relPoint = "BOTTOMRIGHT", dx = 0, dy = -4 },
}
BR.TextPositions.Zones = ZONES

-- Repositionable text items the UI exposes, in display order. `count` is
-- intentionally absent: its position is fixed at INSIDE_C with no offset by
-- default, and the rare nudge case is served by the data model directly (see
-- defaults.textPositions.count) rather than by panel UI.
BR.TextPositions.Items = {
    "buffReminder", -- raid page (Sections/RaidIcons)
    "statLabel", -- consumable page (Sections/ItemDisplay)
    "badge",
    "stackCount",
    "petLabel", -- pet page (Sections/PetDisplay); anchors pet name, family/extra stack below
}

-- Two-axis decomposition of zone names so the UI can present "Vertical" +
-- "Align" dropdowns instead of a custom 5x3 picker widget. Two dropdowns map
-- to the same 15 zones, cost zero custom code, and shrink each row from ~90px
-- to ~26px. The naming asymmetry in zone strings ("INSIDE_T" = top-center,
-- "INSIDE_TL" = top-left) is handled here so callers only see the clean axes.

BR.TextPositions.VERTICAL_OPTIONS = {
    { value = "ABOVE", labelKey = "Options.TextPositions.Vertical.Above" },
    { value = "INSIDE_T", labelKey = "Options.TextPositions.Vertical.InsideTop" },
    { value = "INSIDE_M", labelKey = "Options.TextPositions.Vertical.InsideMiddle" },
    { value = "INSIDE_B", labelKey = "Options.TextPositions.Vertical.InsideBottom" },
    { value = "BELOW", labelKey = "Options.TextPositions.Vertical.Below" },
}

BR.TextPositions.ALIGN_OPTIONS = {
    { value = "L", labelKey = "Options.TextPositions.Align.Left" },
    { value = "C", labelKey = "Options.TextPositions.Align.Center" },
    { value = "R", labelKey = "Options.TextPositions.Align.Right" },
}

local ZONE_FROM_VA = {
    ABOVE = { L = "ABOVE_L", C = "ABOVE_C", R = "ABOVE_R" },
    INSIDE_T = { L = "INSIDE_TL", C = "INSIDE_T", R = "INSIDE_TR" },
    INSIDE_M = { L = "INSIDE_L", C = "INSIDE_C", R = "INSIDE_R" },
    INSIDE_B = { L = "INSIDE_BL", C = "INSIDE_B", R = "INSIDE_BR" },
    BELOW = { L = "BELOW_L", C = "BELOW_C", R = "BELOW_R" },
}

local VA_FROM_ZONE = {}
for v, row in pairs(ZONE_FROM_VA) do
    for a, z in pairs(row) do
        VA_FROM_ZONE[z] = { vertical = v, align = a }
    end
end

---Decompose a zone string into (vertical, align). Falls back to INSIDE_C
---components for unknown zones.
---@param zone string?
---@return string vertical
---@return string align
function BR.TextPositions.ToVA(zone)
    local va = VA_FROM_ZONE[zone] or VA_FROM_ZONE.INSIDE_C
    return va.vertical, va.align
end

---Recompose a zone string from (vertical, align). Falls back to INSIDE_C on
---missing/unknown axis values.
---@param vertical string
---@param align string
---@return string zone
function BR.TextPositions.FromVA(vertical, align)
    local row = ZONE_FROM_VA[vertical] or ZONE_FROM_VA.INSIDE_M
    return row[align] or row.C or "INSIDE_C"
end

-- Defaults preserve current hard-coded behavior so the upgrade is invisible
-- until users change something. statLabel/badge/stackCount weren't user-
-- positionable before; their defaults match the prior anchor points.
local DEFAULT_ZONES = {
    count = "INSIDE_C",
    stackCount = "INSIDE_BR",
    statLabel = "INSIDE_TL",
    badge = "INSIDE_L",
    buffReminder = "BELOW_C",
    petLabel = "BELOW_C",
}
BR.TextPositions.DefaultZones = DEFAULT_ZONES

---Resolve a zone name to its SetPoint descriptor. Falls back to INSIDE_C.
---@param zone string?
---@return table {point, relPoint, dx, dy}
function BR.TextPositions.Resolve(zone)
    return ZONES[zone] or ZONES.INSIDE_C
end

---Look up the effective text-position config for an item. Resolves from
---defaults.textPositions only (per-category overrides were considered but
---dropped: each repositionable item has exactly one realistic consumer).
---@param item string One of count, stackCount, statLabel, badge, buffReminder
---@return string zone
---@return number offsetX
---@return number offsetY
function BR.TextPositions.Get(item)
    local db = BR.profile
    if not db then
        return DEFAULT_ZONES[item] or "INSIDE_C", 0, 0
    end

    local defaults = db.defaults
    if defaults and defaults.textPositions and defaults.textPositions[item] then
        local cfg = defaults.textPositions[item]
        return cfg.zone or DEFAULT_ZONES[item] or "INSIDE_C", cfg.offsetX or 0, cfg.offsetY or 0
    end

    return DEFAULT_ZONES[item] or "INSIDE_C", 0, 0
end

---Anchor a FontString (or texture) using a zone + user nudge.
---@param region table The Region (FontString/Texture) to anchor
---@param frame table The parent icon frame
---@param zone string Zone name (see ZONES)
---@param offsetX number?
---@param offsetY number?
function BR.TextPositions.Apply(region, frame, zone, offsetX, offsetY)
    local z = ZONES[zone] or ZONES.INSIDE_C
    region:ClearAllPoints()
    region:SetPoint(z.point, frame, z.relPoint, z.dx + (offsetX or 0), z.dy + (offsetY or 0))
end
