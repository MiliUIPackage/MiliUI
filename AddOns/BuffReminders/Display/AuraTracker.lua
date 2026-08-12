local _, BR = ...

-- ============================================================================
-- EXTERNALS
-- ============================================================================
-- A present-based display: shows the defensives and buffs you RECEIVE (Power
-- Infusion, Bloodlust, Prescience, ...) while they are active. This is the inverse of
-- the reminder pipeline and shares nothing with State.lua - Blizzard's AuraContainer
-- does the filtering and rendering, so it works for auras the addon cannot read.
--
-- The constraints this module is shaped around (all verified; docs/SecretValues.md #3.9):
--
--   * Decoration is CREATION-WINDOW ONLY. The whole button subtree - our own
--     textures included - becomes forbidden while auras are secret. So every
--     restyle is attempted, and on denial queued for the next restriction lift.
--   * Never read geometry off a button. Its dimensions come back as secret numbers
--     and any arithmetic on them throws. All sizes come from config.
--   * Per-button state lives in a weak-keyed table here, never on the button.
--   * Groups cannot be removed (ClearAuraGroups is deliberately unexposed), so the
--     entry set is changed by reconfiguring the group's filters, never by rebuilding.
--
-- One AuraGroup holds every enabled spell ID. Blizzard packs the visible buttons,
-- which is why enabling five buffs and having one active shows a tight row of one
-- rather than four gaps.

local min = math.min
local ipairs = ipairs
local pairs = pairs
local pcall = pcall

local L = BR.L
local TEXCOORD_INSET = BR.TEXCOORD_INSET

local Settings = BR.GetExternalSettings

local GROUP_KEY = "externals"
-- Blizzard allocates aura frames in batches of 10; this caps how many can be
-- visible at once, not how many can be enabled.
local MAX_FRAMES = 20
-- Matches the category movers' label size in Movers.lua.
local MOVER_LABEL_SIZE = 11

local anchorFrame, container
-- Regions we created, per button. Weak keys: Blizzard owns the buttons' lifetime.
local buttonRegions = setmetatable({}, { __mode = "k" })
-- Set when a reconfigure or restyle was denied, so the lift watcher retries.
local applyPending = false

---Union of every enabled entry's spell IDs.
---
---The second return is the ENTRY count, not the spell-ID count: it sizes the frame
---pool, and an entry can carry several IDs that are mutually exclusive in practice
---(one Bloodlust variant at a time), so IDs would over-allocate.
---@return table<number, boolean> map
---@return number entryCount
local function BuildSpellIDMap()
    local enabled = Settings().entries
    local map, entryCount = {}, 0
    if not enabled then
        return map, entryCount
    end

    for _, entry in ipairs(BR.EXTERNALS) do
        if enabled[entry.key] then
            entryCount = entryCount + 1
            for _, spellID in ipairs(entry.spellIDs) do
                map[spellID] = true
            end
        end
    end

    return map, entryCount
end

---A suffix-free countdown formatter, built once and handed to SetDurationText.
---
---Blizzard's DefaultAuraDurationFormatter is a SecondsFormatter, which always names
---its unit - its "abbreviation" setting only picks how ("13 Seconds" / "13 sec" /
---"13 s"), never nothing. A NumericRuleFormatter takes raw format strings instead,
---so this renders a bare number under a minute and m:ss above it.
local function BuildDurationFormatter()
    local ok, formatter = pcall(function()
        local f = C_StringUtil.CreateNumericRuleFormatter()
        f:SetBreakpoints({
            {
                threshold = 0,
                format = "%d",
                step = 1,
                -- Round up, so a buff with 0.4s left reads "1" rather than "0".
                rounding = Enum.NumericRuleFormatRounding.Up,
            },
            {
                threshold = 60,
                format = "%d:%02d",
                components = {
                    { div = 60, step = 1, rounding = Enum.NumericRuleFormatRounding.Down },
                    { mod = 60, step = 1, rounding = Enum.NumericRuleFormatRounding.Down },
                },
            },
        })
        return f
    end)
    return ok and formatter or nil
end

local durationFormatter

---Apply the configured look to one button. Called from initializeFrame (always
---legal) and from reconfigures (denied while auras are secret - callers pcall it).
local function StyleButton(button)
    local regions = buttonRegions[button]
    if not regions then
        return
    end

    local settings = Settings()
    local size = settings.iconSize or 40
    local borderSize = settings.borderSize or 0

    -- Size comes from config, never from button:GetWidth() - that returns a secret.
    button:SetSize(size, size)

    -- Base crop hides texture edge artifacts; iconZoom adds on top. Blizzard's
    -- per-aura update only calls SetTexture, so this survives every icon swap.
    local inset = TEXCOORD_INSET + (settings.iconZoom or 0) / 100
    regions.icon:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
    regions.icon:SetAlpha(settings.iconAlpha or 1)

    -- Duration text: ours to place and font, Blizzard's to write. Uses the addon's
    -- configured font face and outline, so it matches every other icon's text.
    --
    -- Memoized like SetFontCached (SetFont forces a full fontstring re-layout, and
    -- VisualsRefresh lands here on every step of any appearance slider drag) but with
    -- the signature kept in OUR side table and written only AFTER the call returns.
    -- SetFontCached does neither: it stores _br_font_* on the fontstring, which is
    -- per-button state on a subtree that goes forbidden, and it records the cache
    -- before calling SetFont - so a denial in combat would leave the cache claiming a
    -- font that never landed and the post-combat retry would skip it.
    local fontPath = BR.Display.GetFontPath()
    local outline = BR.Display.GetOutline()
    local durationSize = settings.durationSize or 16
    local fontSig = fontPath .. "|" .. durationSize .. "|" .. outline
    if regions.fontSig ~= fontSig then
        regions.duration:SetFont(fontPath, durationSize, outline)
        regions.fontSig = fontSig
    end

    -- Border protrudes past the button's bounds, same as the reminder icons.
    -- Regions may extend outside a button; only their parentage is constrained.
    if borderSize > 0 then
        regions.border:ClearAllPoints()
        regions.border:SetPoint("TOPLEFT", -borderSize, borderSize)
        regions.border:SetPoint("BOTTOMRIGHT", borderSize, -borderSize)
        regions.border:Show()
    else
        regions.border:Hide()
    end
end

---The one window where addon code may decorate a button: the frame provider calls
---this before applying the access restriction that forbids the subtree.
local function InitializeButton(button)
    local regions = {}
    buttonRegions[button] = regions

    button:EnableMouse(false)

    regions.border = button:CreateTexture(nil, "BACKGROUND")
    regions.border:SetColorTexture(0, 0, 0, 1)

    regions.icon = button:CreateTexture(nil, "ARTWORK")
    regions.icon:SetAllPoints(button)
    button:SetIcon(regions.icon)

    -- SetDurationText stamps SecretAspect.Text/Alpha/VertexColor on this
    -- fontstring: Blizzard writes and counts it down, we must never read it back.
    -- That timer is the one piece of data we could not obtain ourselves in a
    -- restricted context, which is why it is not optional.
    --
    -- Placement and font are ours; only the string is Blizzard's, and the
    -- `textFormatter` option decides how it is rendered. Falls back to the stock
    -- "42 s" formatter if the formatter or the option is rejected.
    regions.duration = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    regions.duration:SetPoint("CENTER", button, "CENTER", 0, 0)
    regions.duration:SetJustifyH("CENTER")

    if durationFormatter == nil then
        durationFormatter = BuildDurationFormatter() or false
    end
    if
        not (
            durationFormatter
            and pcall(button.SetDurationText, button, regions.duration, {
                textFormatter = durationFormatter,
            })
        )
    then
        button:SetDurationText(regions.duration)
    end

    regions.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    regions.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button:SetApplicationCount(regions.count)

    StyleButton(button)
end

local function SavePosition()
    local settings = Settings()
    local point, _, _, x, y = anchorFrame:GetPoint()
    settings.position = { point = point or "CENTER", x = x or 0, y = y or 0 }
end

local function ApplyPosition()
    local position = Settings().position or BR.defaults.externals.position
    anchorFrame:ClearAllPoints()
    anchorFrame:SetPoint(
        position.point or "CENTER",
        UIParent,
        position.point or "CENTER",
        position.x or 0,
        position.y or 0
    )
end

---Push the current config into the container. Every button-touching call here can
---be denied while auras are secret; on denial we flag and retry on the next lift.
local function ApplyConfig()
    if not container then
        return
    end

    local settings = Settings()
    local map, entryCount = BuildSpellIDMap()

    local ok = pcall(function()
        container:SetAuraGroupCandidateFilters(GROUP_KEY, { includeSpellIDs = map })
        container:SetAuraGroupMaxFrameCount(GROUP_KEY, min(entryCount > 0 and entryCount or 1, MAX_FRAMES))
        container:SetAuraGroupLayout(GROUP_KEY, {
            elementSpacing = settings.spacing or 0,
            elementWidth = settings.iconSize or 40,
            elementHeight = settings.iconSize or 40,
        })
    end)

    for button in pairs(buttonRegions) do
        if not pcall(StyleButton, button) then
            ok = false
        end
    end

    applyPending = not ok
end

---The green drag box, matching the category movers in Movers.lua. A frame of its own
---rather than a texture on the anchor: it needs HIGH strata to sit above the icons,
---and setting that on the anchor would drag the container's whole subtree up with it.
local function CreateMover()
    local mover = CreateFrame("Frame", nil, anchorFrame)
    mover:SetAllPoints()
    mover:SetFrameStrata("HIGH")
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")

    local bg = mover:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0.7, 0, 0.6)

    local label = mover:CreateFontString(nil, "OVERLAY")
    label:SetPoint("BOTTOM", mover, "TOP", 0, 4)
    mover.label = label

    -- The mover is built once, so it would otherwise keep the font it was created
    -- with - same reason Movers.lua re-applies this from UpdateSize(). SetFontCached
    -- is safe here: this is our own frame, not a forbidden button subtree.
    function mover:UpdateFont()
        BR.Display.SetFontCached(self.label, MOVER_LABEL_SIZE)
    end
    -- Must run before SetText: the FontString inherits no font, and setting text on
    -- a font-less FontString raises an error (hence the same order in Movers.lua).
    mover:UpdateFont()

    label:SetTextColor(0.4, 1, 0.4, 1)
    label:SetText(L["Externals.Title"])

    BR.SetupTooltip(mover, L["Externals.Title"], L["Externals.MoverTooltip"])

    mover:SetScript("OnDragStart", function()
        GameTooltip:Hide()
        anchorFrame:StartMoving()
    end)
    mover:SetScript("OnDragStop", function()
        anchorFrame:StopMovingOrSizing()
        SavePosition()
    end)

    mover:Hide()
    return mover
end

local function EnsureFrames()
    if container then
        return true
    end

    -- Guarded separately from the container: if the container ever fails to build,
    -- this is retried from the lift watcher and from VisualsRefresh, and re-creating
    -- the anchor would orphan the previous one under the same global name (WoW frames
    -- are never collected) along with its textures and fontstring.
    if not anchorFrame then
        -- The container's parent is a plain frame we own: the mover and any future
        -- animated chrome must live OUTSIDE the button subtree, and a frame anchored
        -- *to* a container inherits its layout restrictions.
        anchorFrame = CreateFrame("Frame", "BuffRemindersExternals", UIParent)
        anchorFrame:SetSize(Settings().iconSize or 40, Settings().iconSize or 40)
        anchorFrame:SetMovable(true)
        anchorFrame:SetClampedToScreen(true)
        ApplyPosition()
    end

    -- Its own step, so a mover that failed to build is retried on the next refresh
    -- instead of leaving the anchor permanently moverless (every later refresh would
    -- then fault on it, and the display would be undraggable for the session).
    if not anchorFrame.mover then
        anchorFrame.mover = CreateMover()
    end

    local ok = pcall(function()
        container = CreateFrame("AuraContainer", nil, anchorFrame, "CustomAuraContainerTemplate")
        container:SetSize(1, 1)
        container:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT")
        container:SetUnit("player")
        container:AddAuraGroup(GROUP_KEY, "HELPFUL", {
            maxFrameCount = MAX_FRAMES,
            candidateFilters = { includeSpellIDs = BuildSpellIDMap() },
            initializeFrame = InitializeButton,
            layout = { elementSpacing = Settings().spacing or 0 },
        })
    end)

    if not ok then
        container = nil
        applyPending = true
    end
    return container ~= nil
end

---Show the mover with the global frame lock. Hidden, it takes no mouse input, so
---the display never eats clicks while locked.
local function SetUnlocked(unlocked)
    -- Called from the global frame lock, so it must not fault when the display has
    -- not been built (or its mover failed to build) - the lock owns every category.
    local mover = anchorFrame and anchorFrame.mover
    if not mover then
        return
    end
    mover:SetShown(unlocked and Settings().enabled)
end

local function Refresh()
    local settings = Settings()

    if not settings.enabled then
        if anchorFrame then
            anchorFrame:Hide()
        end
        return
    end

    if not EnsureFrames() then
        return
    end

    ApplyPosition()
    anchorFrame:SetSize(settings.iconSize or 40, settings.iconSize or 40)
    anchorFrame.mover:UpdateFont()
    ApplyConfig()
    anchorFrame:Show()
    -- Re-sync the handle: the display can be created or enabled while the frames
    -- are already unlocked, in which case SetFrameLocked has long since fired.
    SetUnlocked(not BR.Display.IsFrameLocked())
end

-- Retry anything the restricted context denied. These are the events that end a
-- restricted context; a denied restyle otherwise stays stale until the next change.
local liftWatcher = CreateFrame("Frame")
liftWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
liftWatcher:RegisterEvent("ENCOUNTER_END")
liftWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
liftWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
liftWatcher:SetScript("OnEvent", function(_, event)
    -- PLAYER_ENTERING_WORLD doubles as first-run creation: the profile is seeded by
    -- then, and creating out of combat keeps the initial styling out of the deferred path.
    if event == "PLAYER_ENTERING_WORLD" or (applyPending and Settings().enabled) then
        Refresh()
    end
end)

BR.CallbackRegistry:RegisterCallback("ExternalsRefresh", Refresh)
-- The duration text uses the addon's global font face and outline, which live under
-- `defaults` and fire VisualsRefresh - so changing them has to restyle these buttons
-- too. Refresh no-ops while the display is disabled.
BR.CallbackRegistry:RegisterCallback("VisualsRefresh", Refresh)

BR.AuraTracker = {
    Refresh = Refresh,
    SetUnlocked = SetUnlocked,
    BuildSpellIDMap = BuildSpellIDMap,
    ---True when a reconfigure was denied and is waiting on a restriction lift.
    IsApplyPending = function()
        return applyPending
    end,
}
