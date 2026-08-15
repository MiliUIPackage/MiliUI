local _, BR = ...

-- ============================================================================
-- EXTERNALS PAGE (selection)
-- ============================================================================
-- "Which received buffs do I want to see" - the mirror of the Reminders page, and
-- laid out the same way: two columns of grouped sections, one fixed-height row per
-- entry. Appearance lives on the Externals tab of the Categories page, matching
-- every other category.
--
-- The tracked set is curated in Data/Externals.lua rather than freeform, because
-- spell-ID filtering only works for helpful auras on the player and the useful set
-- of those is small.

local L = BR.L
local Components = BR.Components

local COL_PADDING = BR.Options.Constants.COL_PADDING
local PAGE_TOP_PADDING = BR.Options.Constants.PAGE_TOP_PADDING
local ITEM_HEIGHT = BR.Options.Constants.ITEM_HEIGHT

local TEXCOORD_INSET = BR.TEXCOORD_INSET

local floor = math.floor
local max = math.max
local abs = math.abs
local tinsert = table.insert

-- Section header gold, as RGB so it can be dimmed (see SetChromeDimmed).
local GOLD = { 1, 0.8, 0 }

-- Section rhythm, matched to the Reminders page so the two read as one system.
-- That page clears a note between header and rows; there is none here, so this is
-- its header-to-note gap plus enough for the header's own descenders.
local HEADER_TO_ROWS_GAP = 22
local ROW_INDENT = 6
local INTER_SECTION_GAP = 10

local ICON_SIZE = 16
local FALLBACK_ICON = 134400

-- Left column takes the longest section on its own; the right column stacks the
-- four shorter ones, which roughly balances the page at 16-18 rows a side.
local LEFT_SECTIONS = { "defensives" }
local RIGHT_SECTIONS = { "groupBuffs", "movement", "aggro", "augmentation" }

local Settings = BR.GetExternalSettings
local IsEnabled = BR.AreExternalsEnabled

---@type table<string, table[]> entries bucketed by section key, built once
local entriesBySection = {}
for _, entry in ipairs(BR.EXTERNALS) do
    local bucket = entriesBySection[entry.section]
    if not bucket then
        bucket = {}
        entriesBySection[entry.section] = bucket
    end
    bucket[#bucket + 1] = entry
end

local SECTION_BY_KEY = {}
for _, section in ipairs(BR.EXTERNAL_SECTIONS) do
    SECTION_BY_KEY[section.key] = section
end

---Chrome that greys out with the master toggle. The checkboxes and sliders handle
---themselves via their `enabled` callbacks; these are the plain regions around them,
---which nothing would otherwise dim.
---@param chrome table { headers = FontString[], labels = FontString[], icons = Texture[] }
local function SetChromeDimmed(chrome, dimmed)
    local factor = dimmed and 0.5 or 1
    for _, header in ipairs(chrome.headers) do
        header:SetTextColor(GOLD[1] * factor, GOLD[2] * factor, GOLD[3] * factor)
    end
    -- Matches the 0.5 grey every component factory uses for a disabled label.
    for _, label in ipairs(chrome.labels) do
        label:SetTextColor(factor, factor, factor)
    end
    for _, icon in ipairs(chrome.icons) do
        icon:SetDesaturated(dimmed)
        icon:SetAlpha(dimmed and 0.4 or 1)
    end
end

---One row: enable checkbox, spell icon, name.
local function RenderRow(parent, x, y, entry, rowWidth, chrome)
    local key = entry.key
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", x, y)
    row:SetSize(rowWidth, ITEM_HEIGHT)

    -- holderWidth 18: the label is drawn separately, so the checkbox holder only
    -- needs to cover the box itself or it would push the icon far to the right.
    local checkbox = Components.Checkbox(row, {
        label = "",
        holderWidth = 18,
        enabled = IsEnabled,
        disabledReason = L["Externals.DisabledReason"],
        get = function()
            local enabled = Settings().entries
            return enabled ~= nil and enabled[key] == true
        end,
        onChange = function(checked)
            local settings = Settings()
            settings.entries = settings.entries or {}
            -- nil rather than false: keeps SavedVariables free of dead keys.
            settings.entries[key] = checked or nil
            BR.CallbackRegistry:TriggerEvent("ExternalsRefresh")
        end,
    })
    checkbox:SetPoint("LEFT", 0, 0)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    icon:SetTexture(C_Spell.GetSpellTexture(entry.spellIDs[1]) or FALLBACK_ICON)
    icon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    label:SetPoint("RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(BR.GetExternalLabel(entry))

    chrome.labels[#chrome.labels + 1] = label
    chrome.icons[#chrome.icons + 1] = icon

    return y - ITEM_HEIGHT
end

local function RenderColumn(parent, x, y, sectionKeys, colWidth, chrome)
    local rowsX = x + ROW_INDENT
    local rowWidth = colWidth - ROW_INDENT

    for i, sectionKey in ipairs(sectionKeys) do
        local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", x, y)
        -- Colored via SetTextColor, not an embedded |cff code: an embedded code
        -- wins over SetTextColor, which would make the header undimmable.
        header:SetText(L[SECTION_BY_KEY[sectionKey].titleKey])
        chrome.headers[#chrome.headers + 1] = header

        y = y - HEADER_TO_ROWS_GAP

        for _, entry in ipairs(entriesBySection[sectionKey] or {}) do
            y = RenderRow(parent, rowsX, y, entry, rowWidth, chrome)
        end

        if i < #sectionKeys then
            y = y - INTER_SECTION_GAP
        end
    end

    return y
end

local function Build(content, scrollFrame)
    local contentWidth = scrollFrame:GetContentWidth()
    local layout = Components.VerticalLayout(content, { x = COL_PADDING, y = PAGE_TOP_PADDING })

    BR.Options.Helpers.LayoutSectionNote(layout, content, L["Externals.PageNote"])

    local enableHolder = Components.Checkbox(content, {
        label = L["Externals.Enable"],
        tooltip = { title = L["Externals.Enable"], desc = L["Externals.EnableTooltip"] },
        get = IsEnabled,
        onChange = function(checked)
            BR.Config.Set("externals.enabled", checked)
            Components.RefreshAll()
        end,
    })
    layout:Add(enableHolder, nil, 14)

    local chrome = { headers = {}, labels = {}, icons = {} }

    local colWidth = floor((contentWidth - COL_PADDING * 3) / 2)
    local startY = layout:GetY()
    local leftEndY = RenderColumn(content, COL_PADDING, startY, LEFT_SECTIONS, colWidth, chrome)
    local rightX = COL_PADDING + colWidth + COL_PADDING
    local rightEndY = RenderColumn(content, rightX, startY, RIGHT_SECTIONS, colWidth, chrome)

    content:SetHeight(max(abs(leftEndY), abs(rightEndY)) + 16)

    -- Persistent hook rather than per-widget `enabled`: these are plain FontStrings
    -- and Textures, not component holders, so RefreshAll would never reach them.
    -- Fires on the master toggle's onChange and on every page activation.
    tinsert(BR.RefreshableComponents, {
        Refresh = function()
            SetChromeDimmed(chrome, not IsEnabled())
        end,
    })
    SetChromeDimmed(chrome, not IsEnabled())
end

BR.Options.Pages.externals = {
    title = L["Externals.Title"],
    Build = Build,
}

-- The whole page is new, so it lights a notification dot on its sidebar button and
-- bubbles up to the Buffs group header until the panel is closed. Static Register
-- (not a provider) because there is nothing here that finishes populating later.
BR.Options.WhatsNew.Register({ cohort = "6.4.0", pageId = "externals" })
