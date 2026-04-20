local _, BR = ...

-- Namespace scaffold for Options/ modules. Must load before any Options/Modals/* or
-- Options/Tabs/* file so they can populate their slots.
BR.Options = BR.Options or {}
BR.Options.Modals = BR.Options.Modals or {}
BR.Options.Tabs = BR.Options.Tabs or {}
BR.Options.Helpers = BR.Options.Helpers or {}

-- ============================================================================
-- SHARED CONSTANTS
-- ============================================================================

BR.Options.Constants = {
    PANEL_WIDTH = 540,
    COL_PADDING = 20,
    SECTION_SPACING = 12,
    ITEM_HEIGHT = 22,
    SCROLLBAR_WIDTH = 24,
    TAB_HEIGHT = 22,
    COMPONENT_GAP = 4, -- standard gap between components
    SECTION_GAP = 8, -- gap before/after section boundaries
    DROPDOWN_EXTRA = 8, -- extra clearance after dropdowns (menu overlay space)
}

-- ============================================================================
-- SHARED HELPERS
-- ============================================================================

local tinsert = table.insert
local Helpers = BR.Options.Helpers
local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP
local GetBuffTexture = BR.Helpers.GetBuffTexture

-- Layout-aware section header (uses VerticalLayout instead of manual Y tracking)
function Helpers.LayoutSectionHeader(layout, parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetText("|cffffcc00" .. text .. "|r")
    layout:AddText(header, 14, COMPONENT_GAP)
    return header
end

-- Resolve icon textures from displayIcon texture IDs or spell IDs (deduplicated).
function Helpers.ResolveBuffIcons(displayIcon, spellIDs)
    if displayIcon then
        if type(displayIcon) == "table" then
            return displayIcon
        else
            return { displayIcon }
        end
    elseif spellIDs then
        local icons = {}
        local seenTextures = {}
        local spellList = type(spellIDs) == "table" and spellIDs or { spellIDs }
        for _, spellID in ipairs(spellList) do
            local texture = GetBuffTexture(spellID)
            if texture and not seenTextures[texture] then
                seenTextures[texture] = true
                tinsert(icons, texture)
            end
        end
        return #icons > 0 and icons or nil
    end
    return nil
end

-- ============================================================================
-- PANEL CONTEXT
-- ============================================================================

-- Creates the shared context object passed to every Tab.<Name>.Build(ctx).
-- Bundles frame refs, constants, and container-registration helpers so that
-- each tab file only closes over this single upvalue.
function BR.Options.CreateContext(panel, opts)
    local constants = BR.Options.Constants
    local SCROLLBAR_WIDTH = constants.SCROLLBAR_WIDTH
    local PANEL_WIDTH = constants.PANEL_WIDTH

    local ctx = {
        panel = panel,
        constants = constants,
        contentContainers = opts.contentContainers,
        CONTENT_TOP = opts.CONTENT_TOP,
        IsMasqueActive = opts.IsMasqueActive,
        categoryOrder = { "raid", "presence", "targeted", "self", "pet", "consumable", "custom" },
    }

    -- Built at runtime: L isn't guaranteed stable at Context.lua load time if the
    -- context is created before Options.lua runs, but ctx is always built inside
    -- CreateOptionsPanel() so BR.L is populated.
    local L = BR.L
    ctx.categoryLabels = {
        raid = L["Category.RaidBuffs"],
        presence = L["Category.PresenceBuffs"],
        targeted = L["Category.TargetedBuffs"],
        self = L["Category.SelfBuffs"],
        pet = L["Category.PetReminders"],
        consumable = L["Category.Consumables"],
        custom = L["Category.CustomBuffs"],
    }

    -- Creates a scrollable content frame, registers it as a tab container, and
    -- returns the inner content frame plus the outer scroll frame.
    function ctx:CreateScrollableContent(name)
        local scrollFrame, content = BR.Components.ScrollableContainer(self.panel, {
            contentHeight = 600,
            scrollbarWidth = SCROLLBAR_WIDTH,
        })
        scrollFrame:SetPoint("TOPLEFT", 0, self.CONTENT_TOP)
        scrollFrame:SetPoint("BOTTOMRIGHT", 0, 46)
        scrollFrame:Hide()
        self.contentContainers[name] = scrollFrame
        return content, scrollFrame
    end

    -- Creates a simple (non-scrolling) content frame, registers it, returns it.
    function ctx:CreateSimpleContent(name, height)
        local content = CreateFrame("Frame", nil, self.panel)
        content:SetPoint("TOPLEFT", 0, self.CONTENT_TOP)
        content:SetSize(PANEL_WIDTH, height or 500)
        content:Hide()
        self.contentContainers[name] = content
        return content
    end

    return ctx
end
