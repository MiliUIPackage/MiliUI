local _, BR = ...

-- ============================================================================
-- BUFF PAGE SECTION: Externals Appearance
-- ============================================================================
-- The whole body of the Externals tab on the Categories page. Externals are not a
-- real category (no categorySettings entry, no State entries), so they get this
-- standalone section instead of the _Template composition - none of the shared
-- sections apply: visibility is Blizzard's call, click-to-cast is impossible on a
-- forbidden button, and growth direction is a private mixin method.
--
-- Like CustomAppearance, this section is terminal: it owns the tab frame's height.

local L = BR.L
local Components = BR.Components

local LayoutSectionHeader = BR.Options.Helpers.LayoutSectionHeader
local LayoutSectionNote = BR.Options.Helpers.LayoutSectionNote

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local abs = math.abs

BR.Options.BuffSections = BR.Options.BuffSections or {}

local SLIDERS = {
    { key = "iconSize", labelKey = "Appearance.Width", min = 16, max = 128, suffix = "px", default = 40 },
    { key = "iconZoom", labelKey = "Appearance.Zoom", min = 0, max = 40, suffix = "%", default = 0 },
    { key = "borderSize", labelKey = "Appearance.Border", min = 0, max = 8, suffix = "px", default = 2 },
    { key = "spacing", labelKey = "Appearance.Spacing", min = 0, max = 32, suffix = "px", default = 4 },
    { key = "durationSize", labelKey = "Externals.DurationSize", min = 8, max = 32, suffix = "px", default = 16 },
}

local Settings = BR.GetExternalSettings
local IsEnabled = BR.AreExternalsEnabled

local function Build(ctx, layout)
    local parent = ctx.content

    LayoutSectionHeader(layout, parent, L["Externals.Appearance"])
    LayoutSectionNote(layout, parent, L["Externals.AppearanceNote"])

    -- One shared label column so the tracks line up: "Countdown size" is far wider
    -- than "Zoom", and each slider would otherwise size its own label to fit.
    local labels = {}
    for i, spec in ipairs(SLIDERS) do
        labels[i] = L[spec.labelKey]
    end
    local labelWidth = Components.MeasureSharedLabelWidth(labels)

    for _, spec in ipairs(SLIDERS) do
        local key, default = spec.key, spec.default
        local slider = Components.Slider(parent, {
            label = L[spec.labelKey],
            labelWidth = labelWidth,
            min = spec.min,
            max = spec.max,
            step = 1,
            suffix = spec.suffix,
            enabled = IsEnabled,
            disabledReason = L["Externals.EnableElsewhere"],
            get = function()
                return Settings()[key] or default
            end,
            onChange = function(value)
                BR.Config.Set("externals." .. key, value)
            end,
        })
        layout:Add(slider, nil, COMPONENT_GAP)
    end

    LayoutSectionNote(layout, parent, L["Externals.MasqueNote"])

    parent:SetHeight(abs(layout:GetY()) + (ctx.appearancePadding or 30))
    if ctx.onAppearanceResize then
        ctx.onAppearanceResize()
    end
end

BR.Options.BuffSections.ExternalsAppearance = Build
