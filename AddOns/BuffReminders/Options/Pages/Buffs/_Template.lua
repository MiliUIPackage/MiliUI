local _, BR = ...

-- ============================================================================
-- BUFF PAGE TEMPLATE (orchestrator)
-- ============================================================================
-- Builds a per-category page by composing display sections in a fixed order.
-- This is the only builder for a category tab, so every tab gets the same top
-- padding and the same section rhythm. The caller declares a category and
-- optional resize hooks; the template decides which sections that category gets.
-- Per-category branches inside a section (raid-only / pet-only / consumable-only
-- widgets) live in that section file, not here.
--
-- The template renders only "how this category displays". Per-buff toggling
-- lives on the All Buffs page.
--
-- Each section is a separate file because Lua 5.1 caps a closure at 60 upvalues.
-- One combined builder crosses that ceiling.

local Components = BR.Components

local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING

local Template = {}

---@param content table Frame the sections render into (the tab frame)
---@param scrollFrame table Owning scroll container (for content width)
---@param category string Category key driving the section set
---@param opts? table { appearancePadding?: number, onAppearanceResize?: fun() }
---        Threaded into ctx so CustomAppearance (the last section) can size the
---        tab frame and notify the page to resize.
function Template.Build(content, scrollFrame, category, opts)
    opts = opts or {}
    local ctx = {
        category = category,
        content = content,
        scrollFrame = scrollFrame,
        contentWidth = scrollFrame:GetContentWidth(),
        appearancePadding = opts.appearancePadding,
        onAppearanceResize = opts.onAppearanceResize,
    }
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    local Sections = BR.Options.BuffSections

    -- The user-authored categories carry styling only. Their entry lists and
    -- per-entry config live on their own sidebar pages and dialogs.
    if category == "custom" or category == "loadout" then
        Sections.Layout(ctx, layout)
        Sections.CustomAppearance(ctx, layout)
        return
    end

    -- Standalone category-specific sections lead the tab, so the controls unique
    -- to this category sit above the shared backbone. A section that continues a
    -- shared section stays next to its parent below.
    if category == "pet" then
        Sections.PetDisplay(ctx, layout)
    end
    if category == "consumable" then
        Sections.ItemDisplay(ctx, layout)
    end

    Sections.Visibility(ctx, layout)
    if category == "consumable" then
        Sections.FreeConsumables(ctx, layout)
    end
    Sections.Icons(ctx, layout)
    if category == "raid" then
        Sections.RaidIcons(ctx, layout)
    end
    Sections.ClickToCast(ctx, layout)
    -- Pet and utility reminders have no expiration. A pet is present or missing,
    -- and a utility item is a chore, not an aura. Timing does not apply to them.
    if category ~= "pet" and category ~= "utility" then
        Sections.Timing(ctx, layout)
    end
    Sections.Layout(ctx, layout)
    -- CustomAppearance (Appearance + Glow override sections) MUST be last:
    -- it owns the final content:SetHeight for the page.
    Sections.CustomAppearance(ctx, layout)
end

BR.Options.Pages.BuffTemplate = Template
