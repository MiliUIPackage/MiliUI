local _, Cell = ...

-- ============================================================
-- AURA DISPLAY  (Cell, 12.1 "Route A")
--
-- The Blizzard-driven AuraContainer / AuraButton backing for every aura-icon
-- display on a Cell unit button: the central Raid Debuffs indicator, the debuff
-- row, the dispel icons and health-bar highlight, the three cooldown rows, and
-- custom buff-icon indicators.
--
-- In 12.1 an aura's spellId / name / duration / dispel school on a teammate are
-- secret, so classification MUST happen Blizzard-side. We register one AuraGroup
-- per category with a filter string + candidateFilters; Blizzard fills and drives
-- the buttons and calls our initializeFrame to style each one. We never read
-- spellId / expirationTime / dispelName / presence -- membership IS the predicate,
-- and the widgets we hand over are driven by the engine, not by us.
--
-- Mirrors the mechanism validated in-game by Coolinator and DandersFrames v5.
-- Everything is gated behind IsSupported(); when unsupported (Classic, or the
-- widget missing) each caller keeps its legacy path. Every state change is
-- pcall-wrapped and OOC-only so a raid frame is never broken.
--
-- Was RaidDebuffContainer.lua / Cell.RaidDebuffContainer -- renamed once it stopped
-- being about raid debuffs. The Blizzard-API adapters it sits on (capability probe,
-- duration formatter, flow layout, dispel binding, fonts) live in
-- AuraContainerCore.lua; this file is the Cell policy and the lifecycle.
-- ============================================================

local AD = {}
Cell.AuraDisplay = AD

local ACC = Cell.AuraContainerCore
---@type CellFuncs
local F = Cell.funcs

local pcall, ipairs, pairs, next, tinsert = pcall, ipairs, pairs, next, tinsert
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local issecretvalue = issecretvalue or function() return false end

-- Blizzard filter tokens (defensive: names differ slightly across PTR builds).
local TOKEN_CC   = "CROWD_CONTROL"
local TOKEN_DISP = "RAID_PLAYER_DISPELLABLE"

-- ============================================================
-- SUPPORT GATE  (see AuraContainerCore.lua for the probe itself)
-- ============================================================

function AD.IsSupported()
    return ACC.IsSupported()
end

-- ============================================================
-- CATEGORY RECORDS
-- One record -> one AuraGroup. Order = display priority (groups render in
-- declaration order and do NOT dedupe against each other, so records must be
-- mutually exclusive to avoid showing an aura twice). "Important-first": the
-- boss/role and priority records claim their auras first with NO negation, and
-- the token records (cc, raid, dispel) subtract them via candidateFilter false
-- flags. This matches DandersFrames v5's IMPORTANT-FIRST precedence.
--
-- opts (from the indicator's ["filters"] table) -- all boolean, default true:
--   filterBossRole, filterPriority, filterCrowdControl, filterRaid, filterDispellable
-- Boss and Role are ONE toggle: isBossOrRoleAura covers both, and no UI ever split them.
-- ============================================================

-- all dispel schools, named explicitly so Blizzard never consults the player's spec
-- (DandersFrames Features/Dispel.lua: "All Dispellable must NOT depend on what the
-- player can dispel" -- processedAuraType is secretly player-relative, includeDispelTypes
-- is not).
local ALL_DISPEL_TYPES = ACC.ALL_DISPEL_TYPES

-- ⚠ A rejected filter string used to just make the record vanish. A display whose records
-- all vanish builds no container and renders NOTHING -- silently, with no error, looking
-- exactly like "the addon is broken". Record every rejection so /cab can name it.
AD.rejectedFilters = {}
local function ValidFilter(f)
    if AuraUtil.IsValidFilterString(f) then return true end
    AD.rejectedFilters[f] = (AD.rejectedFilters[f] or 0) + 1
    return false
end

local function BuildRecords(opts)
    opts = opts or {}

    -- Dispel indicator mode: a single slot/record. dispelByMe (Cell's dispellableByMe):
    --   true  -> only debuffs THIS character can dispel  -> HARMFUL|RAID_PLAYER_DISPELLABLE
    --   false -> ALL dispellable debuffs                 -> HARMFUL + includeDispelTypes
    -- "overlay" = the health-bar highlight, same filter, rendered as a tint (see StyleButton).
    if opts.mode == "dispel" or opts.mode == "overlay" then
        local rec
        if opts.dispelByMe then
            rec = { key = "dispel", filter = "HARMFUL|" .. TOKEN_DISP }
        else
            rec = { key = "dispel", filter = "HARMFUL",
                    candidateFilters = { includeDispelTypes = opts.dispelTypes or ALL_DISPEL_TYPES } }
        end
        if ValidFilter(rec.filter) then return { rec } end
        return {}
    end

    -- Plain debuff indicator mode (Cell's "Debuffs"): every harmful aura, optionally only
    -- the ones this character can dispel.
    --
    -- ⚠ The blacklist rides on excludeSpellIDs, which the client only honours for spells
    -- flagged NeverSecret (CanApplyIdentityCandidateFilters bans ID filtering for harmful
    -- auras on assistable units -- anti-automation). That still covers what the blacklist
    -- is actually for: the noisy always-on debuffs (Exhaustion/Sated and friends), which is
    -- the exact case Blizzard carved the exemption for. Encounter debuffs cannot be
    -- excluded by ID at all -- use maxDuration / excludeDispelTypes for those.
    if opts.mode == "debuff" then
        local base = "HARMFUL"
        if opts.dispelByMe then base = base .. "|" .. TOKEN_DISP end

        -- excludeImportant: subtract whatever the Important Debuffs display is CURRENTLY
        -- claiming, so the same aura is never drawn in both places. It arrives as the five
        -- category booleans read off that indicator (nil/false = nothing to subtract).
        --
        -- Every subtraction here is the exact inverse of the record that display builds, and
        -- all five forms are already load-bearing inside the important mode below: the token
        -- negations in its raid/dispel records, the boolean falses in its notImportant().
        local neg = ""
        local ex = opts.excludeImportant
        if type(ex) == "table" then
            if ex.crowdControl then neg = neg .. "|!" .. TOKEN_CC end
            if ex.raid then neg = neg .. "|!RAID" end
            -- ⚠ Skipped when dispelByMe is on. "Only what I can dispel" plus "none of what I
            -- can dispel" composes to a filter that matches NOTHING, with no error and no
            -- visible reason -- so the explicit "only" wins and the subtraction is dropped.
            if ex.dispellable and not opts.dispelByMe then neg = neg .. "|!" .. TOKEN_DISP end
        end

        -- Fall back toward LESS subtraction, never toward an empty row: an over-full row is
        -- visible and fixable, an empty one reads as "the addon is broken".
        local f
        if ValidFilter(base .. neg) then
            f = base .. neg
        elseif ValidFilter(base) then
            f = base
        elseif ValidFilter("HARMFUL") then
            f = "HARMFUL"
        else
            return {}
        end

        local cf
        local function need() cf = cf or {}; return cf end
        if type(ex) == "table" then
            -- these two have no filter-string token; they are candidateFilter booleans
            if ex.bossRole then need().isBossOrRoleAura = false end
            if ex.priority then need().isPriorityAura = false end
        end
        if type(opts.excludeSpellIDs) == "table" and next(opts.excludeSpellIDs) then
            need().excludeSpellIDs = opts.excludeSpellIDs
        end
        if type(opts.excludeDispelTypes) == "table" and next(opts.excludeDispelTypes) then
            need().excludeDispelTypes = opts.excludeDispelTypes
        end
        if type(opts.maxDuration) == "number" and opts.maxDuration > 0 then
            need().maxDuration = opts.maxDuration
        end
        return { { key = "debuff", filter = f, candidateFilters = cf } }
    end

    -- Buff indicator mode (defensives / externals / custom buff indicators). Friendly-unit
    -- BUFFS may be filtered by spell ID -- the 12.1 ban applies only to debuffs on friendly
    -- units -- so Cell's curated + custom spell lists carry straight over.
    --   onlyMine -> restrict to auras cast by the player ("HELPFUL|PLAYER")
    if opts.mode == "buff" then
        local ids = opts.spellIDs
        -- empty list = match nothing. A bare HELPFUL record would show EVERY buff.
        if type(ids) ~= "table" or next(ids) == nil then return {} end
        -- ⚠ NEVER return nothing when only the refinement is rejected. "Only auras I cast"
        -- (castBy = "me") is the ONLY thing in Cell that asks for HELPFUL|PLAYER, so if this
        -- build does not accept that token, the one display using it -- the Healers row --
        -- goes completely blank while every other buff row keeps working. Showing unfiltered
        -- buffs from the curated spell list is wrong; showing nothing is worse AND invisible.
        local f = opts.onlyMine and "HELPFUL|PLAYER" or "HELPFUL"
        if not ValidFilter(f) then
            f = "HELPFUL"
            if not ValidFilter(f) then return {} end
        end
        return { { key = "buff", filter = f, candidateFilters = { includeSpellIDs = ids } } }
    end

    local function on(k) local v = opts[k]; return v == nil or v end -- default true

    local bossRole = on("filterBossRole")
    local priority = on("filterPriority")
    local cc   = on("filterCrowdControl")
    local raid = on("filterRaid")
    local disp = on("filterDispellable")

    local records = {}

    -- set when the boss/role record was declared, so the lower records can subtract it
    local importantFlag
    if bossRole then
        importantFlag = "isBossOrRoleAura"
        records[#records + 1] = {
            key = "bossrole", filter = "HARMFUL",
            candidateFilters = { isBossOrRoleAura = true },
        }
    end

    local priorityDeclared = false
    if priority then
        priorityDeclared = true
        local cf = { isPriorityAura = true }
        if importantFlag then cf[importantFlag] = false end
        records[#records + 1] = { key = "priority", filter = "HARMFUL", candidateFilters = cf }
    end

    -- subtract whichever important records were declared (fresh table each call)
    local function notImportant(extra)
        extra = extra or {}
        if importantFlag then extra[importantFlag] = false end
        if priorityDeclared then extra.isPriorityAura = false end
        return extra
    end

    if cc then
        records[#records + 1] = {
            key = "cc", filter = "HARMFUL|" .. TOKEN_CC,
            candidateFilters = notImportant(),
        }
    end
    if raid then
        -- exclude cc so a CC that also carries RAID stays in the cc record
        local f = "HARMFUL|RAID" .. (cc and ("|!" .. TOKEN_CC) or "")
        records[#records + 1] = { key = "raid", filter = f, candidateFilters = notImportant() }
    end
    if disp then
        local f = "HARMFUL|" .. TOKEN_DISP
            .. (cc and ("|!" .. TOKEN_CC) or "")
            .. (raid and "|!RAID" or "")
        records[#records + 1] = { key = "dispel", filter = f, candidateFilters = notImportant() }
    end

    -- prune records whose filter string the client rejects (unknown token)
    local out = {}
    for _, rec in ipairs(records) do
        if ValidFilter(rec.filter) then
            out[#out + 1] = rec
        end
    end
    return out
end
AD.BuildRecords = BuildRecords

-- ============================================================
-- IDENTITY GATE  (12.1 -- why a whitelist row silently shows EVERY buff)
--
-- include/excludeSpellIDs are only consulted inside Blizzard's
-- CanApplyIdentityCandidateFilters, and for a HELPFUL pool that check requires
-- UnitCanAssist("player", unit). A FAILED check does not reject the aura -- it skips the
-- ID filters WHOLESALE, so the pool fails OPEN and every buff renders. Nothing errors,
-- the filter string is still right, and /cab inspect still prints +cf{includeSpellIDs}:
-- the row just fills with food buffs.
--
-- Assist flips false for a cross-faction group member outside instanced content, for a
-- duel partner, and -- the one everybody hits -- for the duration of a CINEMATIC, which
-- fires UNIT_FACTION. 12.1 forces a cinematic on first login, which is why "it was fine
-- on the PTR, it's broken on live" and why the three curated rows all broke at once.
-- (Mechanism found and documented by DandersFrames v5; same finding, same fix.)
--
-- ⚠ THE ENGINE DOES NOT RE-PARSE WHEN ASSIST COMES BACK. It re-parses when an aura
-- CHANGES, so the unfiltered pool simply stays -- which is why /reload is the only thing
-- that ever "fixed" it. Recovery needs an explicit bounce (Handle:GateRefresh), not just
-- a visibility flip.
--
-- "Only mine" pools (HELPFUL|PLAYER, our castBy = "me") have a SECOND fail-open
-- condition: for a unit outside your visible world (a different instance/phase) the
-- engine cannot attribute a caster, so "mine" passes every caster's auras while
-- UnitCanAssist stays true. Signal for that one is UnitIsVisible.
--
-- HARMFUL pools are out of scope: their gate is UnitCanAttack, and ID filtering on a
-- friendly unit's debuffs is banned outright anyway (see the debuff mode above).
--
-- FAIL DIRECTION when a vulnerable row is caught in the gate (cinematic / loading /
-- cross-faction / phase):
--   SHOW  (false) -- keep the row up and eat a moment of unfiltered icons. The original
--                    12.1 default: a wrongly-hidden row was judged worse than garbage.
--   HIDE  (true)  -- render nothing until the whitelist is trustworthy again. User
--                    preference: an empty row beats a food-buff-filled one.
-- Recovery is the same GateRefresh bounce either way, so HIDE self-corrects the instant
-- assist/visibility comes back; the only cost is a legit row can blink out for the length
-- of one confirmed-false probe. Only CONFIRMED fail-open is flipped (definite non-secret
-- false, plus the cinematic latch) -- genuine doubt (secret value, pcall failure, no unit)
-- still falls to SHOW, so normal secret-aura combat never blanks a row.
local GATE_FAIL_CLOSED = true
-- ============================================================

local function RecordVulnerableToIdentityGate(rec)
    local f = rec.filter
    if type(f) ~= "string" or not f:find("HELPFUL", 1, true) then return false end
    local cf = rec.candidateFilters
    -- ⚠ "HELPFUL|PLAYER" is NOT immune. The PLAYER token narrows the query, but the
    -- spell-ID whitelist is still skipped -- a "my buffs" row degrades to "anything I
    -- cast", which is exactly what the Healers row did.
    return (cf and (cf.includeSpellIDs or cf.excludeSpellIDs)) and true or false
end

local function RecordSourceRelative(rec)
    local f = rec.filter
    if type(f) == "string" then
        for token in f:gmatch("[^|%s]+") do
            if (token:gsub("^!", "")) == "PLAYER" then return true end
        end
    end
    local cf = rec.candidateFilters
    return (cf and cf.isFromPlayerOrPlayerPet ~= nil) and true or false
end

-- ============================================================
-- BUTTON STYLING  (initializeFrame)
-- Build FRESH regions as children of the button (never reparent an existing
-- scripted widget -- forbidden-aspect inheritance blocks it). Then hand each
-- region to Blizzard's inbound setters. Never read spellId/duration/count.
-- ============================================================

-- The duration formatter, the dispel-texture binding and the font applier all live in
-- AuraContainerCore.lua now -- they used to exist twice, once here and once in the
-- bridge, and the two copies had already drifted (different countdown format, and the
-- bridge never read CellDB.debuffTypeColor at all).
local ApplyFont = ACC.ApplyFont
local BindDispelTexture = ACC.BindDispelTexture

-- ============================================================
-- ICON RENDERING -- one look, everywhere
--
-- Cell's I.CreateAura_BorderIcon shape: the Cooldown covers the WHOLE button and the
-- icon sits in an inset child frame ABOVE it, so only the outer ring shows and the
-- countdown reads as a border draining clockwise. Every icon display uses it -- the
-- central raid debuffs, the debuff row, the cooldown rows and custom buff icons.
--
-- ⚠ The colour is on the STATIC ring and the swipe is what EATS it, not the other way
-- round. That inversion is forced, not stylistic: SetSwipeColor takes a literal RGB and
-- an AuraButton never tells us the dispel school, so a coloured swipe could not be
-- school-coloured. A static texture can -- Blizzard vertex-tints it for us, blind.
--
-- So the ring colour is:
--   dispel school present -> the user's own palette colour (CellDB.debuffTypeColor)
--   no school, HARMFUL    -> plain debuff red, also from the palette ("none")
--   no school, HELPFUL    -> green
-- cfg.borderColor overrides the last two (custom indicators with their own 顏色 setting),
-- and the swipe grows over whatever it is in SPENT_COLOR as the aura runs out.
-- ============================================================

-- Deliberately dark. This started at {0, 0.9, 0.2} and was dialled down because a bright
-- green ring visually swamps the icon inside it at 12-20px.
local BUFF_GREEN  = { 0, 0.55, 0.15, 1 }
-- what the ring turns into as it drains -- black, i.e. Cell's ordinary icon border
local SPENT_COLOR = { 0, 0, 0, 1 }

-- Seconds-based colour curve for a countdown: hard bands built from a base colour + a list of
-- { sec, color } thresholds. The C side samples it against the SECRET remaining duration, so
-- we never read the time. Bands are made with close-point pairs (a 0.01s gap) so the colour
-- SWITCHES at each threshold instead of gradient-ramping (matching Cell's native behaviour).
local function BuildCountdownColorCurve(base, thresholds)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    if not thresholds or #thresholds == 0 then return nil end
    table.sort(thresholds, function(a, b) return a.sec < b.sec end)
    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve then return nil end
    local function col(c) return CreateColor(c[1], c[2] or 1, c[3] or 1, c[4] or 1) end
    local baseC = (type(base) == "table" and type(base[1]) == "number") and col(base) or CreateColor(1, 1, 1, 1)
    local added = pcall(function()
        -- [0,t1]=c1  (t1,t2]=c2  ...  (tN, inf)=base ; smallest threshold is the most urgent
        local prev = 0
        for _, th in ipairs(thresholds) do
            local c = col(th.color)
            curve:AddPoint(prev, c)
            curve:AddPoint(th.sec, c)
            prev = th.sec + 0.01
        end
        curve:AddPoint(prev, baseC)
        curve:AddPoint(prev + 86400, baseC)
    end)
    if not added then return nil end
    return curve
end

-- Build the SetDurationText textColor { curve, property } from the indicator's colours config.
-- cfg.durationColors is a NORMALISED { base = {r,g,b,a}, sec = {en, secThr, {r,g,b,a}} } spec
-- (AttachBuffContainer flattens text's vs block's differing raw layouts into this). baseOverride
-- lets the block use a readable number colour instead of its fill. nil when the seconds band is
-- disabled/absent.
local function BuildDurColorOpt(cfg, baseOverride)
    if not (Enum and Enum.DurationTextBindingProperty) then return nil end
    local dc = cfg.durationColors
    if type(dc) ~= "table" or type(dc.thresholds) ~= "table" or #dc.thresholds == 0 then return nil end
    local curve = BuildCountdownColorCurve(baseOverride or dc.base, dc.thresholds)
    if not curve then return nil end
    return { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration }
end

-- Blizzard-rendered countdown number (centre) + stack count (corner), handed off blind.
-- Shared by the block/text custom styles; the default icon branch keeps its OWN inline copy
-- because there it interleaves with icon/cooldown frame-level assignment.
-- durColorOpt (optional): SetDurationText textColor { curve, property } for colour-by-time.
local function BindDurStack(button, cfg, base, durColorOpt)
    if not button.dfDur then
        button.dfDurHolder = CreateFrame("Frame", nil, button)
        button.dfDurHolder:SetAllPoints(button)
        button.dfDur = button.dfDurHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
        button.dfDur:SetPoint("CENTER")
    end
    button.dfDurHolder:SetFrameLevel(base + 6)
    ApplyFont(button.dfDur, button.dfDurHolder, cfg.durationFont, true)

    if not button.dfStack then
        button.dfStackHolder = CreateFrame("Frame", nil, button)
        button.dfStackHolder:SetAllPoints(button)
        button.dfStack = button.dfStackHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
        button.dfStack:SetPoint("BOTTOMRIGHT", 2, -1)
    end
    button.dfStackHolder:SetFrameLevel(base + 7)
    ApplyFont(button.dfStack, button.dfStackHolder, cfg.stackFont)

    -- ⚠ SetApplicationCount with EMPTY opts, NEVER a formatter: Blizzard runs
    -- formatter:FormatNumber on the SECRET stack in Lua and bricks the container.
    if button.dfStack and button.SetApplicationCount and not button._boundStack
        and cfg.showStack ~= false then
        button:SetApplicationCount(button.dfStack, {})
        button._boundStack = true
    end
    if button.dfDur and button.SetDurationText and not button._boundDur then
        local fmt = ACC.GetDurationFormatter(cfg.showDuration)
        if fmt then
            local opts = { textFormatter = fmt }
            if durColorOpt then opts.textColor = durColorOpt end
            -- textColor {curve,property} is only honoured on build 68914+; an older client may
            -- refuse the option table, so fall back to plain text rather than drop the number.
            if not pcall(button.SetDurationText, button, button.dfDur, opts) then
                pcall(button.SetDurationText, button, button.dfDur, { textFormatter = fmt })
            end
            button._boundDur = true
        end
    end
end

local function StyleButton(handle, button)
    local cfg = handle.config
    local size = cfg.size or 22
    local sizeH = cfg.sizeH or size -- cooldown indicators are 12x20, not square
    local border = cfg.border or 1

    -- click-through; tooltip opt-in
    if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
    if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
    if button.SetCollapsesLayout then button:SetCollapsesLayout(true) end
    button:SetSize(size, sizeH)

    -- BISECT: minimal styling (icon bind only, Coolinator-proven). Isolates "does the
    -- container render at this anchor at all" from the full styling/bind path.
    -- ⚠ its OWN texture field, never button.dfIcon: sharing it would leave the real icon
    -- anchored to the whole button afterwards, covering the ring -- a rendering artefact
    -- introduced by the tool that exists to diagnose rendering artefacts.
    if handle._testMinimal then
        if not button.dfTestIcon then
            button.dfTestIcon = button:CreateTexture(nil, "OVERLAY")
            button.dfTestIcon:SetAllPoints(button)
        end
        if button.SetIcon and not button._boundTestIcon then
            button._boundTestIcon = true
            button:SetIcon(button.dfTestIcon)
        end
        return
    end

    -- OVERLAY MODE: a tint texture covering the button (positioned over the health bar),
    -- vertex-tinted by dispel type BLIND ("Color"/PreserveAsset style). This is Cell's
    -- dispel HIGHLIGHT, done the DandersFrames way -- our art, Blizzard's colour. The
    -- gradient shape comes from the texture's own alpha (SetGradient would fight the
    -- vertex tint), so a gradient look needs a gradient texture file; v1 uses a flat tint.
    if cfg.mode == "overlay" then
        local style = cfg.highlightStyle or "gradient"
        -- Cell/Media/gradient.tga = white RGB + vertical alpha ramp (opaque bottom -> fade
        -- up). Blizzard vertex-tints the RGB by school; the file's alpha is the gradient,
        -- so we never SetGradient (which would fight the tint). Solid styles use WHITE8x8.
        local isSolid = (style == "entire" or style == "current" or style == "current+")
        local tex = isSolid and "Interface\\Buttons\\WHITE8x8" or "Interface\\AddOns\\Cell\\Media\\gradient"
        if not button.dfTint then
            button.dfTint = button:CreateTexture(nil, "ARTWORK")
        end
        button.dfTint:SetTexture(tex)
        button.dfTint:SetAlpha(cfg.tintAlpha or 0.5)
        button.dfTint:ClearAllPoints()
        if style == "gradient-half" then
            -- bottom half of the bar, matching Cell's original gradient-half geometry
            button.dfTint:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
            button.dfTint:SetPoint("TOPRIGHT", button, "RIGHT")
        else
            button.dfTint:SetAllPoints(button)
        end
        if not button._boundTint then
            button._boundTint = true
            BindDispelTexture(button, button.dfTint, "Color")
        end
        return
    end

    -- DISPEL-ICON MODE: show ONLY the Blizzard dispel-type icon (Magic/Curse/Disease/
    -- Poison/Bleed art -- the same RaidFrame-Icon-Debuff* set Cell's "blizzard" style uses),
    -- rendered BLIND via the "Icon" texture style. No debuff spell icon / cooldown / stack.
    if cfg.dispelIcon then
        if not button.dfDispelIcon then
            button.dfDispelIcon = button:CreateTexture(nil, "ARTWORK")
            button.dfDispelIcon:SetAllPoints(button)
        end
        if not button._boundDispelIcon then
            button._boundDispelIcon = true
            BindDispelTexture(button, button.dfDispelIcon, "Icon")
        end
        return
    end

    -- BLOCK / TEXT custom styles (buff-only). These effect types used to freeze on the manual
    -- path because they render aura PRESENCE, and presence is secret. Here the container owns
    -- the button's visibility, so presence needs no read: draw a fixed-colour rect (block) or
    -- nothing (text), and let Blizzard blind-render the countdown number + stack onto our
    -- fontstrings. ⚠ No time-based recolour (剩X秒變紅/到期閃光): remaining duration is secret.
    if cfg.customStyle == "block" or cfg.customStyle == "text" then
        local base = button:GetFrameLevel()
        local col = cfg.borderColor
        local hasCol = type(col) == "table" and type(col[1]) == "number"
        local durationOn = cfg.showDuration and cfg.showDuration ~= false

        if cfg.customStyle == "block" then
            -- the colour fill (presence = Blizzard shows/hides the button)
            if not button.dfBlock then
                button.dfBlock = button:CreateTexture(nil, "BACKGROUND")
                button.dfBlock:SetAllPoints(button)
            end
            local c = hasCol and col or BUFF_GREEN
            button.dfBlock:SetColorTexture(c[1], c[2] or 0, c[3] or 0, c[4] or 1)

            -- draining swipe over the fill: a BLIND visual timer (Blizzard drives it from the
            -- aura's duration; we never read the remaining time). We can't recolour the fill
            -- by time (that value is secret), but the sweep restores the "how much is left"
            -- read that the old time-based recolour gave.
            if durationOn then
                if not button.dfCD then
                    button.dfCD = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                    button.dfCD:SetSwipeTexture(ACC.WHITE)
                    button.dfCD:SetSwipeColor(SPENT_COLOR[1], SPENT_COLOR[2], SPENT_COLOR[3])
                    button.dfCD:SetReverse(true)           -- swipe covers the ELAPSED arc
                    button.dfCD:SetDrawSwipe(true)
                    button.dfCD:SetHideCountdownNumbers(true)
                    button.dfCD:SetDrawEdge(false)
                    button.dfCD:SetDrawBling(false)
                    button.dfCD.noCooldownCount = true     -- keep OmniCC off our numbers
                end
                button.dfCD:ClearAllPoints()
                button.dfCD:SetAllPoints(button)
                button.dfCD:SetFrameLevel(base + 1)
                if button.SetDurationCooldown and not button._boundCD then
                    button:SetDurationCooldown(button.dfCD)
                    button._boundCD = true
                end
            end
        end

        -- countdown colour-by-time from the indicator's own colours (base + seconds thresholds).
        -- text: the number's base is the indicator colour (col). block: keep the number a
        -- readable WHITE over the coloured fill -- only the threshold bands recolour it.
        local durColorOpt = BuildDurColorOpt(cfg, cfg.customStyle == "block" and { 1, 1, 1, 1 } or nil)
        BindDurStack(button, cfg, base, durColorOpt)

        -- static baseline colour for the number (the curve, if bound, drives the bands and its
        -- top band equals this, so they agree; if the curve was refused this is the whole colour)
        if button.dfDur then
            if cfg.customStyle == "block" then
                button.dfDur:SetTextColor(1, 1, 1, 1)
            elseif hasCol then
                button.dfDur:SetTextColor(col[1], col[2] or 1, col[3] or 1, col[4] or 1)
            end
        end
        return
    end

    -- Levels are RE-APPLIED every pass, never set once at creation: SetFrameLevel stores an
    -- ABSOLUTE level, and the container re-levels its AuraButtons as groups grow, so a region
    -- left on the old number sinks below the button and disappears. That was the
    -- "文字被擋在後面" ghost.
    local base = button:GetFrameLevel()

    -- ring colour when the aura has no dispel school: green for buffs, debuff red otherwise
    local ring = cfg.borderColor
    if type(ring) ~= "table" or type(ring[1]) ~= "number" then
        ring = (cfg.mode == "buff") and BUFF_GREEN or ACC.GetNoDispelColor()
    end

    -- ---- the ring ------------------------------------------------------------
    -- Two layers with strictly separate jobs. ⚠ They must NOT both carry the fallback
    -- colour: Blizzard's school tint arrives as a vertex colour, and a red tint over a
    -- dark-green base multiplies down to near-black.
    --   dfBG            BACKGROUND, OUR colour, always drawn -> the no-school ring
    --   dfDispelBorder  BORDER, plain WHITE, handed to Blizzard -> shown and tinted only
    --                   when the aura has a school, covering dfBG when it is
    if not button.dfBG then
        button.dfBG = button:CreateTexture(nil, "BACKGROUND")
    end
    button.dfBG:SetAllPoints(button)
    button.dfBG:SetColorTexture(ring[1], ring[2] or 0, ring[3] or 0, ring[4] or 1)

    -- Skipped for buff containers: the binding is showWhenHarmful-only, so on a HELPFUL
    -- container it is a texture and a bind per button that can never draw anything.
    if cfg.mode ~= "buff" then
        if not button.dfDispelBorder then
            button.dfDispelBorder = button:CreateTexture(nil, "BORDER")
            button.dfDispelBorder:SetColorTexture(1, 1, 1, 1) -- white: the tint IS the colour
        end
        button.dfDispelBorder:SetAllPoints(button)
        if not button._boundDispelBorder then
            button._boundDispelBorder = true
            BindDispelTexture(button, button.dfDispelBorder, "Color")
        end
    end

    -- ---- the icon, inset, ABOVE the swipe so only the ring shows --------------
    if not button.dfIconFrame then
        button.dfIconFrame = CreateFrame("Frame", nil, button)
        button.dfIcon = button.dfIconFrame:CreateTexture(nil, "ARTWORK")
        button.dfIcon:SetAllPoints(button.dfIconFrame)
        button.dfIcon:SetTexCoord(0.12, 0.88, 0.12, 0.88) -- match Cell's crop
    end
    button.dfIconFrame:ClearAllPoints()
    button.dfIconFrame:SetPoint("TOPLEFT", button, "TOPLEFT", border, -border)
    button.dfIconFrame:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -border, border)
    button.dfIconFrame:SetFrameLevel(base + 2)

    -- ---- the drain -----------------------------------------------------------
    -- Covers the WHOLE button, under the icon frame. SetReverse(true) makes the swipe
    -- cover the ELAPSED arc, so black grows and the coloured arc shrinks clockwise.
    if not button.dfCD then
        button.dfCD = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.dfCD:SetSwipeTexture(ACC.WHITE)
        button.dfCD:SetSwipeColor(SPENT_COLOR[1], SPENT_COLOR[2], SPENT_COLOR[3])
        button.dfCD:SetReverse(true)
        button.dfCD:SetDrawSwipe(true)
        button.dfCD:SetHideCountdownNumbers(true)
        button.dfCD:SetDrawEdge(false)
        button.dfCD:SetDrawBling(false)
        button.dfCD.noCooldownCount = true -- keep OmniCC off our numbers
    end
    button.dfCD:ClearAllPoints()
    button.dfCD:SetAllPoints(button)
    button.dfCD:SetFrameLevel(base + 1)

    -- ---- text -----------------------------------------------------------------
    -- ⚠ The holders MUST be anchored: a frame with no points/size is rect-less, and a
    -- fontstring anchored to a rect-less frame never renders.
    if not button.dfDur then
        button.dfDurHolder = CreateFrame("Frame", nil, button)
        button.dfDurHolder:SetAllPoints(button)
        button.dfDur = button.dfDurHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
        button.dfDur:SetPoint("CENTER")
    end
    button.dfDurHolder:SetFrameLevel(base + 6)
    -- re-applied every pass (not create-once) so font sliders are live
    ApplyFont(button.dfDur, button.dfDurHolder, cfg.durationFont, true)

    if not button.dfStack then
        button.dfStackHolder = CreateFrame("Frame", nil, button)
        button.dfStackHolder:SetAllPoints(button)
        button.dfStack = button.dfStackHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
        button.dfStack:SetPoint("BOTTOMRIGHT", 2, -1)
    end
    button.dfStackHolder:SetFrameLevel(base + 7)
    ApplyFont(button.dfStack, button.dfStackHolder, cfg.stackFont)

    -- ---- native binds (bind-once via flags) ----
    -- Direct calls, NOT pcall'd: StyleButton's caller captures errors into
    -- handle._errors so /cab and /cab test can surface the real failure
    -- instead of silently swallowing it.
    -- ⚠ Each flag is set only AFTER its call returns. StyleButton runs under pcall from
    -- Restyle, and an AuraButton that has gone forbidden throws on the first restricted
    -- call -- flagging first would permanently skip that bind, leaving a half-styled button
    -- (fontstrings created, icon never bound) that no later pass can repair.
    if button.dfIcon and button.SetIcon and not button._boundIcon then
        button:SetIcon(button.dfIcon)
        button._boundIcon = true
    end
    if button.dfCD and button.SetDurationCooldown and not button._boundCD then
        button:SetDurationCooldown(button.dfCD)
        button._boundCD = true
    end
    if button.dfStack and button.SetApplicationCount and not button._boundStack
        and cfg.showStack ~= false then
        -- ⚠ EMPTY opts, NEVER a formatter: Blizzard runs formatter:FormatNumber in
        -- Lua on the SECRET stack count -> throws inside ProcessDirtyFlags and
        -- bricks the container for the session.
        button:SetApplicationCount(button.dfStack, {})
        button._boundStack = true
    end
    if button.dfDur and button.SetDurationText and not button._boundDur then
        local fmt = ACC.GetDurationFormatter(cfg.showDuration)
        -- ⚠ only flag it when a bind actually happened. Flagging on the disabled path too
        -- meant an indicator created with showDuration off could never get its text back.
        if fmt then
            -- unified countdown colour-by-time (icon/defensive types): base + seconds thresholds
            local durColorOpt = BuildDurColorOpt(cfg)
            local opts = { textFormatter = fmt }
            if durColorOpt then opts.textColor = durColorOpt end
            if not pcall(button.SetDurationText, button, button.dfDur, opts) then
                pcall(button.SetDurationText, button, button.dfDur, { textFormatter = fmt })
            end
            button._boundDur = true
        end
    end

    -- dispel-type SYMBOL letter (config-driven). Blizzard writes the school glyph into
    -- our fontstring, blind.
    if cfg.showDispelSymbol and not button._boundDispelSym then
        button._boundDispelSym = true
        if not button.dfSymbol then
            button.dfSymbolHolder = CreateFrame("Frame", nil, button)
            button.dfSymbolHolder:SetAllPoints(button)
            button.dfSymbol = button.dfSymbolHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
            button.dfSymbol:SetPoint("CENTER")
        end
        button.dfSymbolHolder:SetFrameLevel(base + 8)
        ACC.BindDispelText(button, button.dfSymbol)
    end

end

-- ============================================================
-- FLOW LAYOUT
-- ============================================================

-- Honour the indicator's orientation. The anchor frame is one icon big and sits at the
-- configured position; the row must flow OUT of that point in the configured direction,
-- or a TOPRIGHT/right-to-left indicator (Healers) spills icons rightward off the frame.
local function ApplyLayout(handle)
    local c = handle.container
    if not c then return end
    local cfg = handle.config

    local point = ACC.ApplyFlowLayout(c, {
        orientation = cfg.orientation,
        num = cfg.num or 3,
        width = cfg.size or 22,
        height = cfg.sizeH or cfg.size or 22,
        spacing = cfg.spacing or 2,
    })

    -- pin the container to the SAME side of the anchor frame the row flows from
    pcall(function()
        c:ClearAllPoints()
        c:SetPoint(point, handle.frame, point, 0, 0)
    end)
end

-- per-group cell size passed to AddAuraGroup
local function GroupLayout(cfg)
    local size = cfg.size or 22
    local spacing = cfg.spacing or 2
    return {
        elementWidth = size, elementHeight = cfg.sizeH or size,
        elementSpacing = spacing, lineSpacing = spacing, groupSpacing = 0,
    }
end

-- ============================================================
-- BUILD  (create -> SetUnit -> AddAuraGroup* -> SetEnabled LAST)
-- ============================================================

local function Build(handle)
    if handle._destroyed then return end
    if InCombatLockdown() then
        handle._pendingBuild = true
        if AD._defer then AD._defer(handle) end
        return
    end
    handle._pendingBuild = nil

    -- Tear down the previous native container (add-only topology -> recreate on change).
    -- ⚠ The AuraContainer carries Forbidden Aspects, so Hide()/SetParent() ON IT can be
    -- refused for a tainted caller -- and the pcall then swallows the refusal, leaving the
    -- old container rendering *underneath* the new one (the duplicated stack counts that
    -- only /reload cleared). So every build gets its own plain host frame that WE own:
    -- hiding and orphaning that is never forbidden, and it takes the container with it.
    if handle.container then
        pcall(function() handle.container:SetEnabled(false) end)
        pcall(function() handle.container:Hide() end)
        handle.container = nil
    end
    if handle.host then
        local old = handle.host
        old:Hide()
        old:SetParent(nil)
        -- verify the disposal actually took. If this ever trips, the ghost icons are NOT a
        -- teardown-order problem and AD.Ghosts() will say so instead of us guessing.
        if old:IsShown() or old:GetParent() then
            handle._disposeFailed = (handle._disposeFailed or 0) + 1
        end
        handle.host = nil
    end
    wipe(handle.buttons)
    handle._groupKeys = nil
    -- Identity-gate state is re-derived from THIS build's records below. Clearing it here
    -- is what lets a handle rebuilt onto non-vulnerable filters drop a stale hidden flag
    -- instead of staying hidden forever; the assist verdict resets too, because a fresh
    -- parse has no fail-open history to recover from.
    handle._gateVulnerable, handle._gateSourceRelative = nil, nil
    handle._gateAssist, handle._gateVisible = nil, nil

    if not handle.enabled or not handle.unit then return end

    -- Compute the records FIRST. A container with no groups renders nothing, yet still costs
    -- a Frame + an AuraContainer + a batch of AuraButtons on every unit button -- that is
    -- exactly what the three cooldown indicators were doing with empty curated lists.
    -- Nothing to show => build nothing.
    local records = handle.records or BuildRecords(handle.config)
    if #records == 0 then return end

    for _, rec in ipairs(records) do
        if RecordVulnerableToIdentityGate(rec) then handle._gateVulnerable = true end
        if RecordSourceRelative(rec) then handle._gateSourceRelative = true end
    end

    local host = CreateFrame("Frame", nil, handle.frame)
    host:SetAllPoints(handle.frame)

    local ok, c = pcall(CreateFrame, "AuraContainer", nil, host, "CustomAuraContainerTemplate")
    if not ok or not c then
        host:Hide()
        host:SetParent(nil)
        return
    end
    handle.host = host
    handle.container = c
    handle._groupKeys = {}
    handle._errors = {}          -- diagnostics: per-step failures (see AD.Debug)
    handle._initCount = 0        -- how many buttons Blizzard asked us to style
    handle._groupsAdded = 0
    handle._enabledWhileVisible = false

    local overlay = handle.config.mode == "overlay"
    if overlay then
        -- overlay covers its anchor frame (the health bar); no flow layout
        pcall(function() c:SetAllPoints(handle.frame) end)
    else
        ApplyLayout(handle)
    end

    -- SetUnit BEFORE groups/slots
    local okU, errU = pcall(function() c:SetUnit(handle.unit) end)
    if not okU then handle._errors[#handle._errors + 1] = "SetUnit: " .. tostring(errU) end

    local groupLayout = GroupLayout(handle.config)
    -- ⚠ maxFrameCount is PER GROUP, not per container. The important display declares five
    -- category groups, so num=3 meant "up to 15 icons" and made Blizzard pre-allocate a
    -- batch of 10 buttons PER GROUP (50 for three visible icons). Split the budget instead:
    -- the row then holds at most `num` rounded up to the group count.
    local wanted = handle.config.num or 3
    local maxCount = wanted
    if #records > 1 then
        maxCount = math.max(1, math.ceil(wanted / #records))
    end

    -- diagnostics: what filters/cf this container actually built with
    handle._recordInfo = {}
    for _, rec in ipairs(records) do
        local cfDesc = ""
        if rec.candidateFilters then
            local keys = {}
            for k in pairs(rec.candidateFilters) do keys[#keys + 1] = k end
            cfDesc = " +cf{" .. table.concat(keys, ",") .. "}"
        end
        handle._recordInfo[#handle._recordInfo + 1] = rec.key .. "=" .. rec.filter .. cfDesc
    end
    handle._modeDbg = handle.config.mode or "important"

    for _, rec in ipairs(records) do
        local initFn = function(button)
            handle._initCount = (handle._initCount or 0) + 1
            if overlay then pcall(function() button:SetAllPoints(c) end) end
            -- ⚠ Tracked HERE and nowhere else. This is the only place a genuinely new
            -- button arrives; StyleButton must never append, because Restyle iterates this
            -- very list and calls StyleButton on each entry -- appending from there grew
            -- the list exactly as fast as the iterator advanced, so the loop never ended
            -- and the client froze on every option change that triggers a restyle.
            tinsert(handle.buttons, button)
            local okS, errS = pcall(StyleButton, handle, button)
            if not okS and #handle._errors < 6 then -- cap: 50 identical lines helps nobody
                handle._errors[#handle._errors + 1] = "style: " .. tostring(errS)
            end
        end
        local okG, errG
        if overlay then
            -- single slot covering the frame (AddAuraGroup eagerly batches; AddAuraSlot
            -- is the genuine single-icon/overlay primitive)
            okG, errG = pcall(c.AddAuraSlot, c, rec.key, rec.filter, {
                initializeFrame = initFn,
                candidateFilters = rec.candidateFilters,
            })
        else
            okG, errG = pcall(c.AddAuraGroup, c, rec.key, rec.filter, {
                maxFrameCount = maxCount,
                initializeFrame = initFn,
                layout = groupLayout,
                candidateFilters = rec.candidateFilters,
            })
        end
        if okG then
            handle._groupsAdded = handle._groupsAdded + 1
            -- remembered so SetNum can drive maxFrameCount live (slots are always 1)
            if not overlay then handle._groupKeys[#handle._groupKeys + 1] = rec.key end
        else
            handle._errors[#handle._errors + 1] = "Add[" .. rec.key .. "] (" .. rec.filter .. "): " .. tostring(errG)
        end
    end

    -- SetEnabled LAST (gates aura-event registration). Only "counts" if the frame is
    -- visible right now; otherwise ReassertEnable() re-runs it when the button shows.
    local okE, errE = pcall(function() c:SetEnabled(true) end)
    if not okE then handle._errors[#handle._errors + 1] = "SetEnabled: " .. tostring(errE) end
    handle:_ApplyVisibility()
    -- Whatever the gate says right now is this parse's baseline (_gateAssist was cleared
    -- above, so this probe records rather than recovers).
    handle:ApplyIdentityGate()
    if handle.frame:IsVisible() then handle._enabledWhileVisible = true end
end

-- regen flush
do
    local regen = CreateFrame("Frame")
    regen:RegisterEvent("PLAYER_REGEN_ENABLED")
    AD._pending = {}
    regen:SetScript("OnEvent", function()
        for h in pairs(AD._pending) do
            AD._pending[h] = nil
            if h._pendingBuild then
                Build(h)
            elseif h._pendingGateKick then
                -- an identity-gate recovery that landed mid-combat only got to mark the
                -- container dirty; the bounce that actually re-parses is OOC-only
                h._pendingGateKick = nil
                h:GateRefresh()
            end
        end
        -- a Restyle refused during combat has to be replayed, or the buttons keep whatever
        -- state they had when the option was changed
        for h in pairs(AD._instances or {}) do
            if h._restylePending then h:Restyle() end
        end
    end)
    function AD._defer(h) AD._pending[h] = true end
end

-- ============================================================
-- PUBLIC HANDLE
-- ============================================================

local Handle = {}
Handle.__index = Handle

function Handle:GetFrame() return self.frame end
function Handle:SetPoint(...) self.frame:ClearAllPoints(); self.frame:SetPoint(...) end
function Handle:ClearAllPoints() self.frame:ClearAllPoints() end

function Handle:SetSize(w, h)
    self.config.size = w or self.config.size
    self.frame:SetSize(w or self.config.size, h or w or self.config.size)
end

function Handle:SetNum(n)
    if self.config.num == n then return end
    self.config.num = n

    -- maxFrameCount is a LIVE setter, so the icon count never needs a rebuild -- and a
    -- rebuild is exactly what left the old icons stacked under the new ones. Layout depends
    -- on num too (the flow line budget is a pixel budget derived from it).
    local c = self.container
    if c and c.SetAuraGroupMaxFrameCount and self._groupKeys and #self._groupKeys > 0 then
        -- same per-group split Build uses: maxFrameCount is per GROUP, not per container
        local per = n
        if #self._groupKeys > 1 then
            per = math.max(1, math.ceil(n / #self._groupKeys))
        end
        local allOK = true
        for _, key in ipairs(self._groupKeys) do
            if not pcall(c.SetAuraGroupMaxFrameCount, c, key, per) then allOK = false end
        end
        if allOK then
            ApplyLayout(self)
            return
        end
    end

    self.records = nil
    self:Rebuild()
end

-- keys that only affect per-button cosmetics: restyle the cached buttons instead of
-- recreating the container (a rebuild re-creates ~10 buttons per group -- far too heavy
-- for a font slider drag)
local COSMETIC_KEYS = { stackFont = true, durationFont = true, borderColor = true }

-- geometry keys: 12.1 has SetAuraGroupLayout as a LIVE setter and StyleButton already
-- re-applies per-button size/border, so these never need a rebuild either. Keeping them
-- off the rebuild path is what stops a size/border tweak from leaving a stale container.
local LAYOUT_KEYS = { size = true, sizeH = true, border = true, spacing = true, orientation = true }

function Handle:Restyle()
    -- ⚠ Combat used to `return` outright, with no flag -- the restyle was simply lost, and
    -- the option looked like it had never been applied. Flag it; the regen handler replays.
    if InCombatLockdown() then
        self._restylePending = true
        return
    end

    -- Styling an EXISTING AuraButton is only legal from initializeFrame; once auras are
    -- secret the button is forbidden and every restricted call throws, half-applying the
    -- pass (fonts land, binds don't) -- the "text with no icon" state.
    --
    -- ⚠ But this used to defer to PLAYER_REGEN_ENABLED, and that is not the same condition:
    -- auras stay secret for a whole dungeon/encounter, not just while you are in combat. So
    -- an option changed while standing still in an instance waited for a combat-end that
    -- might never come. Rebuilding IS legal here -- it makes fresh buttons and styles them
    -- from initializeFrame -- and out of combat it costs one rebuild and applies NOW.
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then
        self._restylePending = nil
        self:Rebuild()
        return
    end

    self._restylePending = nil
    -- snapshot the length: a numeric loop over a fixed bound cannot be walked off the end
    -- by anything that touches self.buttons mid-pass
    local n = #self.buttons
    for i = 1, n do
        local b = self.buttons[i]
        if b then pcall(StyleButton, self, b) end
    end
end

-- Table-valued options need a CONTENT signature, and the config must remember the
-- signature rather than the table. Both halves matter, and each one was a bug:
--
--   * Some tables arrive fresh every call (spellIDs is rebuilt per push), so comparing by
--     reference reports "changed" every time and rebuilds the container on every touch.
--   * Others are mutated IN PLACE by the options panel -- Cell's font widget edits
--     indicatorTable["font"][2] directly and then fires with the same table. There the
--     reference is stable AND self.config[k] points at that very table, so the stored
--     "old" value moves with the new one: identity says unchanged, and so does any content
--     compare against it. That is why dragging the Healers duration font size did nothing.
--
-- Snapshotting the signature at the moment we accept a value is the only comparison that
-- survives both. Keys AND values: font tables are arrays whose keys never change, so a
-- keys-only signature reports "identical" no matter what the user drags.
local function TableSig(t)
    if type(t) ~= "table" then return nil end
    local parts = {}
    for k, v in pairs(t) do
        parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and TableSig(v) or tostring(v))
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

-- push the current geometry onto the live container; false = caller must rebuild
function Handle:ApplyLiveLayout()
    local c = self.container
    if not c then return true end -- nothing built yet; Build will read the new config
    if not c.SetAuraGroupLayout or not self._groupKeys or #self._groupKeys == 0 then
        return false -- overlay/slot mode has no groups to relayout
    end
    local gl = GroupLayout(self.config)
    for _, key in ipairs(self._groupKeys) do
        if not pcall(c.SetAuraGroupLayout, c, key, gl) then return false end
    end
    ApplyLayout(self)
    return true
end

function Handle:SetOptions(opts)
    if not opts then return end
    -- `num` is handled by SetNum, which drives maxFrameCount live instead of rebuilding
    local newNum = opts.num
    local structural, cosmetic, layout = false, false, false
    self._sigs = self._sigs or {}
    for k, v in pairs(opts) do
        if k ~= "num" then
            local changed
            if type(v) == "table" then
                -- compare against the SNAPSHOT, never against self.config[k] -- see TableSig
                local sig = TableSig(v)
                changed = sig ~= self._sigs[k]
                self._sigs[k] = sig
            elseif self._sigs[k] ~= nil then
                self._sigs[k] = nil -- was a table, now is not
                changed = true
            else
                changed = self.config[k] ~= v
            end
            if changed then
                if COSMETIC_KEYS[k] then
                    cosmetic = true
                elseif LAYOUT_KEYS[k] then
                    layout = true
                else
                    structural = true
                end
            end
            self.config[k] = v
        end
    end
    -- ConfigureContainer re-sends the WHOLE option set on every panel touch, so most calls
    -- carry no change at all (dragging a position slider, say). Restyling regardless walked
    -- every cached AuraButton on every unit button per drag tick -- that was the freeze.
    if structural then
        if newNum ~= nil then self.config.num = newNum end -- fold into the rebuild
        self.records = nil
        self:Rebuild()
        return
    end
    if newNum ~= nil then self:SetNum(newNum) end
    if layout and not self:ApplyLiveLayout() then
        self.records = nil
        self:Rebuild()
        return
    end
    if cosmetic or layout then self:Restyle() end
end

function Handle:SetUnit(unit)
    if issecretvalue(unit) then return end
    if self.unit == unit then return end
    self.unit = unit
    self:Rebuild()
end

function Handle:SetShown(shown)
    self.shown = shown and true or false
    self:_ApplyVisibility()
end

-- Consumer intent (SetShown) composed with the two render-side latches: the identity gate
-- and the cinematic latch. Plain-frame ops only -- the secure enabled state is never
-- touched here -- so it stays combat-safe.
function Handle:_ApplyVisibility()
    local want = (self.shown ~= false) and not self._gateHidden and not self._cineLatched
    self.frame:SetShown(want)
    if self.container then pcall(function() self.container:SetShown(want) end) end
end

function Handle:SetEnabled(enabled)
    enabled = enabled and true or false
    -- ConfigureContainer calls this on EVERY option touch. A blind Rebuild tore down and
    -- recreated the entire AuraContainer (CreateFrame + SetUnit + N AddAuraGroup + ~10
    -- AuraButtons) per unit button per slider tick. `container` is nil until the first
    -- Build, so the initial creation still goes through.
    if self.enabled == enabled and self.container then return end
    self.enabled = enabled
    self:Rebuild()
end

function Handle:Rebuild()
    if InCombatLockdown() then
        self._pendingBuild = true
        AD._defer(self)
        return
    end
    Build(self)
end

-- Re-assert enable while the frame is actually VISIBLE. SetEnabled gates aura-event
-- registration on IsVisible(); if Build ran while the button was hidden, the container
-- enabled-but-never-registered and stays empty. Call this when the button becomes shown.
function Handle:ReassertEnable()
    if InCombatLockdown() then return end
    local c = self.container
    if not c then return end
    if not self.frame:IsVisible() then return end
    if self._enabledWhileVisible then return end
    self._enabledWhileVisible = true
    pcall(function() c:SetEnabled(true) end)
    pcall(function() c:Hide(); c:Show() end) -- partition kick -> force a fresh scan
end

-- ============================================================
-- IDENTITY GATE, handle half  (see the big header above BuildRecords)
-- ============================================================

-- Force a re-parse of the whole container. UpdateAllAuras() from ADDON context only sets
-- the dirty flags -- it cannot arm the private-side processor -- so out of combat the
-- Hide/Show bounce is what actually crosses the partition (the intrinsic OnShow runs
-- secure-side and re-parses from in there). In combat: mark, and replay the real bounce
-- on regen.
function Handle:GateRefresh()
    local c = self.container
    if not c then return end
    if InCombatLockdown() then
        self._pendingGateKick = true
        AD._defer(self)
        if type(c.UpdateAllAuras) == "function" then pcall(function() c:UpdateAllAuras() end) end
        return
    end
    pcall(function() c:Hide(); c:Show() end)
end

-- assist false -> true is the moment the pool stops being fail-open, and the only moment a
-- bounce is needed. nil (the first probe after a build) is not an edge -- that parse was
-- born with whatever verdict it recorded.
function Handle:_NoteGateRecovery(can)
    local was = self._gateAssist
    self._gateAssist = can and true or false
    return was == false and self._gateAssist
end

-- Genuine doubt (no unit, pcall failure, secret value) always leaves the row visible --
-- that is uncertainty, not a confirmed fail-open, and blanking a row mid-combat is worse.
-- A CONFIRMED non-secret false is the fail-open signal; whether that hides the player's
-- OWN row too is GATE_FAIL_CLOSED (SHOW kept own visible -- a wrongly-hidden own row was
-- judged worse than unfiltered icons; HIDE blanks it like everyone else, per user pref).
function Handle:ApplyIdentityGate()
    local hide, recovered = false, false

    if self._gateVulnerable or self._gateSourceRelative then
        local unit = self.unit
        if type(unit) == "string" and UnitExists(unit) then
            local isOwn = unit == "player"
            if not isOwn then
                local okU, same = pcall(UnitIsUnit, unit, "player") -- "raid5" can be you
                isOwn = okU and same == true
            end

            -- (1) non-assistable (cross-faction, duel, cinematic): includeSpellIDs is
            --     skipped and every helpful aura passes. Signal: UnitCanAssist.
            if self._gateVulnerable then
                local ok, can = pcall(UnitCanAssist, "player", unit)
                if ok then
                    if issecretvalue(can) then can = true end
                    recovered = self:_NoteGateRecovery(can)
                    if not can and (not isOwn or GATE_FAIL_CLOSED) then hide = true end
                end
            end

            -- (2) not in your visible world (different instance/phase): the engine cannot
            --     attribute a caster, so "mine" passes everyone's auras. Signal:
            --     UnitIsVisible. Same fail-safe -- only a definite, non-secret false hides.
            --     Probed even when (1) already hid us, so the recovery edge is recorded:
            --     this pool goes stale-open exactly like the assist one, and coming back
            --     into view is not an aura change either.
            if self._gateSourceRelative then
                local okV, vis = pcall(UnitIsVisible, unit)
                if okV and not issecretvalue(vis) then
                    local was = self._gateVisible
                    self._gateVisible = vis and true or false
                    if was == false and self._gateVisible then recovered = true end
                    if not vis and (not isOwn or GATE_FAIL_CLOSED) then hide = true end
                end
            end
        end
    end

    local newHidden = hide or nil
    if self._gateHidden ~= newHidden then
        self._gateHidden = newHidden
        self:_ApplyVisibility()
    end

    if recovered then
        -- ⚠ Un-latch BEFORE the bounce. Show() on a frame whose parent chain is hidden
        -- never fires OnShow, and OnShow is the entire mechanism of the bounce -- bouncing
        -- while still hidden would silently do nothing, which is the bug we are fixing.
        if self._cineLatched then
            self._cineLatched = nil
            self:_ApplyVisibility()
        end
        self:GateRefresh()
    end
end

function Handle:Destroy()
    self._destroyed = true -- Build/Rebuild must not resurrect it
    self._pendingBuild = nil
    AD._pending[self] = nil
    if AD._instances then AD._instances[self] = nil end
    if self.container then
        pcall(function() self.container:SetEnabled(false) end)
        pcall(function() self.container:Hide() end)
        self.container = nil
    end
    -- orphan the host we own: Hide() on the container itself may be refused (see Build)
    if self.host then
        self.host:Hide()
        self.host:SetParent(nil)
        self.host = nil
    end
    self.frame:Hide()
end

-- ============================================================
-- FACTORY
-- config: { size, sizeH, border, spacing, num, orientation, showDuration, showStack,
--           stackFont, durationFont, borderColor, mode, and the five category toggles
--           filterBossRole / filterPriority / filterCrowdControl / filterRaid /
--           filterDispellable }
-- returns a handle, or nil when unsupported (caller keeps its fallback path).
-- ============================================================

-- The dispel palette is COPIED into each AuraButton when AddDispelTypeTexture binds it, so
-- a colour change cannot be pushed onto live buttons -- they have to be rebuilt. Debounced,
-- because a colour picker fires continuously while the user drags it and a rebuild touches
-- every container on every unit button.
local paletteTimer
function AD.RefreshDispelPalette()
    if paletteTimer then return end
    paletteTimer = true
    C_Timer.After(0.3, function()
        paletteTimer = nil
        if InCombatLockdown() then return end -- Rebuild would just defer each one anyway
        for h in pairs(AD._instances or {}) do
            h:Rebuild()
        end
    end)
end

function AD.Create(parent, config)
    if not AD.IsSupported() then return nil end
    config = config or {}
    config.num = config.num or 3
    config.size = config.size or 22
    config.border = config.border or 1
    config.spacing = config.spacing or 2

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(config.size, config.size)

    local handle = setmetatable({
        frame = frame,
        config = config,
        buttons = {},
        enabled = true,
        shown = true,
    }, Handle)

    AD._instances = AD._instances or {}
    AD._instances[handle] = true

    return handle
end

-- ============================================================
-- IDENTITY-GATE WATCHER
--
-- Re-probe every vulnerable handle whenever assistability can flip: faction changes
-- (cross-faction membership, duels -- and cinematics, which fire UNIT_FACTION), phasing,
-- roster and member-data settling, zoning, target/focus swaps. Event bursts coalesce onto
-- one 50ms timer and the per-handle probe is two API calls, so a raid-wide sweep is cheap.
--
-- PLAYER_ENTERING_WORLD parks two delayed sweeps as well: straight after a loading screen
-- UnitCanAssist can still answer with the pre-load value, and once it settles no watched
-- event necessarily fires again.
--
-- The cinematic pair latches vulnerable rows hidden for the duration, so the fail-open
-- parse a cinematic leaves behind is never SEEN -- the rows come back only once the
-- recovery bounce has re-parsed them (ApplyIdentityGate clears each latch as it bounces).
-- The 3s fallback then resolves whatever is still latched -- force-shown in SHOW mode
-- (never below the old behaviour), or re-probed in HIDE mode (stays hidden until assist
-- actually recovers). See GATE_FAIL_CLOSED.
-- ============================================================
do
    local watcher = CreateFrame("Frame")
    for _, e in ipairs({
        "UNIT_FACTION", "UNIT_PHASE", "UNIT_NAME_UPDATE",
        "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE", "GROUP_ROSTER_UPDATE",
        "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "CINEMATIC_START", "CINEMATIC_STOP", "PLAY_MOVIE", "STOP_MOVIE",
    }) do
        watcher:RegisterEvent(e)
    end

    local queued
    local function Sweep()
        queued = nil
        for h in pairs(AD._instances or {}) do
            if not h._destroyed and (h._gateVulnerable or h._gateSourceRelative) then
                pcall(function() h:ApplyIdentityGate() end)
            end
        end
    end
    AD.GateSweep = Sweep

    local function SetLatch(h, on)
        on = on or nil
        if h._cineLatched == on then return end
        h._cineLatched = on
        pcall(function() h:_ApplyVisibility() end)
    end

    local function LatchAll()
        for h in pairs(AD._instances or {}) do
            if not h._destroyed and h._gateVulnerable then SetLatch(h, true) end
        end
    end

    -- clear = every latch still standing; assistOnly = only the handles whose assist never
    -- dropped (they were never fail-open, so there is nothing to wait for)
    local function UnlatchAll(assistOnly)
        for h in pairs(AD._instances or {}) do
            if h._cineLatched and (not assistOnly or h._gateAssist ~= false) then
                SetLatch(h, nil)
            end
        end
    end

    watcher:SetScript("OnEvent", function(_, event)
        if event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
            LatchAll()
            return
        end

        if not queued then
            queued = true
            C_Timer.After(0.05, Sweep)
        end

        if event == "CINEMATIC_STOP" or event == "STOP_MOVIE" then
            Sweep()             -- assist may already be back; bounce now, not in 50ms
            UnlatchAll(true)
            -- SHOW mode force-shows whatever is still latched after 3s (never below old
            -- behaviour). HIDE mode instead re-probes: recovered rows un-latch via their
            -- bounce, rows whose assist is still down stay hidden (fail-closed).
            if GATE_FAIL_CLOSED then
                C_Timer.After(3, Sweep)
            else
                C_Timer.After(3, function() UnlatchAll(false) end)
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(2, Sweep)
            C_Timer.After(6, Sweep)
        end
    end)
end

-- ============================================================
-- FILTER BISECT TOOL  ->  /cab test  (or Cell.AuraDisplay.Test("HARMFUL") by hand)
--
-- Whether an aura MATCHES a group is secret -- only eyes can judge -- so this
-- swaps every CENTRAL (important-mode) container onto ONE test record live,
-- letting the user bisect which filter/candidateFilter combination actually
-- matches in the current build. Out of combat only (rebuild defers otherwise).
--   Test("HARMFUL")                          -> every debuff should show (rendering check)
--   Test("HARMFUL|RAID_PLAYER_DISPELLABLE")  -> dispellable-by-me only
--   Test("HARMFUL", {isBossOrRoleAura=false}) -> tests boolean-false cf mechanics
--   Test(nil)                                -> restore the normal 5 records
-- ============================================================

function AD.Test(filter, cf, minimal)
    if filter and AuraUtil and AuraUtil.IsValidFilterString and not AuraUtil.IsValidFilterString(filter) then
        print("|cff33ff99[Cell 光環]|r invalid filter string:", filter)
        return
    end
    local n = 0
    for h in pairs(AD._instances or {}) do
        if not h.config.mode then -- central/important containers only
            h._testMinimal = (filter and minimal) or nil
            if filter then
                h.records = { { key = "test", filter = filter, candidateFilters = cf } }
            else
                h.records = nil -- restore: BuildRecords runs again on rebuild
            end
            h:Rebuild()
            n = n + 1
        end
    end
    local cfDesc = ""
    if cf then
        local keys = {}
        for k, v in pairs(cf) do keys[#keys + 1] = k .. "=" .. tostring(v) end
        cfDesc = " cf{" .. table.concat(keys, ",") .. "}"
    end
    print("|cff33ff99[Cell 光環]|r central containers -> " .. (filter and (filter .. cfDesc) or "(restored to normal records)") .. " (" .. n .. " rebuilt; OOC only)")
end

-- One-button stepper: /cab test
-- Each press advances to the next bisect case and prints what to look for.
local TEST_STEPS = {
    { f = "HARMFUL", minimal = true,                desc = "第1步 最小渲染(只綁icon):任何減益都該亮" },
    { f = "HARMFUL",                                desc = "第2步 完整樣式:第1亮這步不亮=樣式綁定壞" },
    { f = "HARMFUL|RAID_PLAYER_DISPELLABLE",        desc = "第3步 可驅散token:可驅散減益該亮" },
    { f = "HARMFUL", cf = { isBossOrRoleAura = false },
                                                    desc = "第4步 布林false旗標:跟第2步同,不亮=布林false壞" },
    { f = "HARMFUL|RAID_PLAYER_DISPELLABLE|!RAID",  desc = "第5步 !RAID抵銷:第3步亮這步不亮=RAID抵銷確認" },
    { f = nil,                                      desc = "已恢復正常5組filter(再按一次回到第1步)" },
}
local testStep = 0
local function StepTest()
    testStep = testStep % #TEST_STEPS + 1
    local s = TEST_STEPS[testStep]
    AD.Test(s.f, s.cf, s.minimal)
    print("|cffffcc00[Cell 光環 測試 " .. testStep .. "/" .. #TEST_STEPS .. "]|r " .. s.desc)
    -- auto-surface any styling/bind errors captured during the rebuild
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function()
            for h in pairs(AD._instances or {}) do
                if not h.config.mode and h._errors and #h._errors > 0 then
                    for _, e in ipairs(h._errors) do print("|cffff5555[Cell 光環 錯誤]|r " .. e) end
                    return -- one instance's errors are representative
                end
            end
        end)
    end
end

-- ============================================================
-- DIAGNOSTICS  ->  /cab
-- ============================================================

local function p(...) print("|cff33ff99[Cell 光環]|r", ...) end

function AD.Debug()
    p("Cell.isMidnight =", tostring(Cell.isMidnight))
    p("IsSupported() =", tostring(AD.IsSupported()))

    -- raw probe detail
    local toc = select(4, GetBuildInfo())
    p("TOC build =", tostring(toc))
    p("AuraUtil.IsValidFilterString =", tostring(AuraUtil and AuraUtil.IsValidFilterString ~= nil))
    local okF, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    p("CreateFrame(AuraContainer, CustomAuraContainerTemplate) ok =", tostring(okF),
        "AddAuraGroup fn =", tostring(okF and frame and type(frame.AddAuraGroup) == "function"))

    -- filter string validity for each category record
    if AuraUtil and AuraUtil.IsValidFilterString then
        for _, rec in ipairs(BuildRecords({})) do
            -- ⚠ escape the pipes: the chat frame eats "|R" as a colour reset, so
            -- "HARMFUL|RAID" prints as "HARMFULAID" and reads like a broken filter
            p("filter valid?", rec.key, (rec.filter:gsub("|", "||")), "->",
                tostring(AuraUtil.IsValidFilterString(rec.filter)))
        end
        -- the buff row's optional refinement, which is what castBy = "me" asks for
        p("filter valid?", "HELPFUL||PLAYER", "->", tostring(AuraUtil.IsValidFilterString("HELPFUL|PLAYER")))
    end

    -- anything the client refused. A display whose records all got refused renders nothing
    -- at all, so this is the first place to look when one row is blank and the rest are fine.
    local anyRejected = false
    for f, n in pairs(AD.rejectedFilters) do
        anyRejected = true
        p(("|cffff5555REJECTED FILTER|r %s (x%d) -- any display relying on it fell back or went empty")
            :format((f:gsub("|", "||")), n))
    end
    if not anyRejected then p("rejected filters: none") end

    -- live instances (the actual per-button containers) -- prioritise VISIBLE ones,
    -- those are the units actually on screen with debuffs.
    local total, built, visible, shown = 0, 0, 0, 0
    local samples = 0
    for h in pairs(AD._instances or {}) do
        total = total + 1
        if h.container then built = built + 1 end
        local vis = h.frame:IsVisible()
        if vis then visible = visible + 1 end
        if h.container and h.container:IsVisible() then shown = shown + 1 end
        -- ⚠ EVERY visible container-backed instance gets a line. The old cap of 5 was a
        -- silent coverage hole: whichever display is actually broken has no reason to be in
        -- the first five, and a capture that omits it looks like a clean bill of health.
        -- A visible unit button carries under a dozen of these, so printing them all is free.
        if vis and h.container then
            samples = samples + 1
            -- NOTE: AuraButton IsShown/geometry are SECRET (branching on them errors), so we
            -- CANNOT read whether a button is rendering -- only the user's eyes can confirm that.
            p(("VISIBLE unit=%s mode=%s enabled=%s groupsAdded=%s initCount=%s ewv=%s buttons=%d")
                :format(tostring(h.unit), tostring(h._modeDbg), tostring(h.enabled), tostring(h._groupsAdded),
                    tostring(h._initCount), tostring(h._enabledWhileVisible), #h.buttons))
            -- our own anchor frame: rect is readable (not secret). A 0x0/nil rect means
            -- children can't resolve -> container renders nothing despite being visible.
            local fw, fh = h.frame:GetSize()
            local fx, fy = h.frame:GetCenter()
            p(("   anchorFrame size=%.1fx%.1f center=%s,%s")
                :format(tonumber(fw) or -1, tonumber(fh) or -1,
                    fx and string.format("%.0f", fx) or "nil", fy and string.format("%.0f", fy) or "nil"))
            if h._recordInfo then
                for _, ri in ipairs(h._recordInfo) do p("   filter:", (ri:gsub("|", "||"))) end
            end
            if h._errors and #h._errors > 0 then
                for _, e in ipairs(h._errors) do p("   ERR:", e) end
            end
        end
    end
    p(("totals: instances=%d built=%d frameVisible=%d containerVisible=%d"):format(total, built, visible, shown))
    if samples == 0 then p("!! no VISIBLE container-backed instance found -- stand in a group with debuffs and retry") end
end

-- ============================================================
-- GHOST CHECK  ->  /cab ghosts
--
-- Answers "is this icon rendered twice?". Every live handle should still be owned by an
-- indicator registered on its button. One that isn't is an orphan: its frame is parented
-- to the button and its container is still bound to the unit, so it keeps drawing an icon
-- at whatever position it last had -- on top of whatever legitimately replaced it.
-- AuraButton IsShown/geometry are SECRET, so this is the only readable way to detect it.
-- ============================================================

-- The handle's frame is parented to the INDICATOR frame (raidDebuffs/dispels) or to the
-- HEALTH BAR (overlay mode) -- never directly to the unit button, which is where
-- _containerIndicators lives. Walk up to find it.
local function FindOwnerButton(frame)
    local f = frame
    for _ = 1, 8 do
        if not f then return nil end
        if rawget(f, "_containerIndicators") ~= nil or f._containerIndicators then return f end
        f = f:GetParent()
    end
    return nil
end

function AD.Ghosts()
    local total, orphans, disposeFails, unowned = 0, 0, 0, 0
    for h in pairs(AD._instances or {}) do
        total = total + 1
        local mode = tostring(h.config and h.config.mode or "important")

        if h._disposeFailed then
            disposeFails = disposeFails + 1
            p(("DISPOSE-FAILED x%d unit=%s mode=%s -- host survived Hide()/SetParent(nil)")
                :format(h._disposeFailed, tostring(h.unit), mode))
        end
        if h._pendingBuild then
            p(("PENDING-BUILD unit=%s mode=%s -- config change is queued until combat ends")
                :format(tostring(h.unit), mode))
        end

        local btn = FindOwnerButton(h.frame)
        if not btn then
            -- can't attribute it: report only if it is actually rendering something
            if h.container and h.frame:IsShown() then
                unowned = unowned + 1
                p(("UNATTRIBUTED unit=%s mode=%s parent=%s -- no owning button found")
                    :format(tostring(h.unit), mode, tostring(h.frame:GetParent() and h.frame:GetParent():GetName() or "?")))
            end
        else
            local owned = false
            for _, ind in ipairs(btn._containerIndicators or {}) do
                -- dispels registers TWO handles: the icon container and the highlight one
                if ind.container == h or ind.highlightContainer == h then owned = true break end
            end
            -- a torn-down handle keeps no container; only a LIVE one can draw a ghost
            if not owned and h.container then
                orphans = orphans + 1
                p(("ORPHAN unit=%s mode=%s shown=%s button=%s")
                    :format(tostring(h.unit), mode, tostring(h.frame:IsShown()), tostring(btn:GetName() or "?")))
            end
        end
    end
    p(("ghost check: %d live orphans, %d unattributed, %d dispose-failed, %d handles total")
        :format(orphans, unowned, disposeFails, total))
end

-- ============================================================
-- INSPECT  ->  /cab inspect [unit]
--
-- Dumps every container on one unit's button: what filter/candidateFilters it actually
-- built with, how many spell IDs its include map holds, and its duration-text state.
-- A buff container with no include map (or one that fell back to a bare HELPFUL record)
-- shows EVERY buff -- that is the difference between "filtered" and "everything".
-- ============================================================

function AD.Inspect(unitToken)
    unitToken = unitToken or "player"
    local n = 0
    for h in pairs(AD._instances or {}) do
        if h.unit == unitToken then
            n = n + 1
            local cfg = h.config or {}
            local ids = cfg.spellIDs
            local idCount = 0
            if type(ids) == "table" then for _ in pairs(ids) do idCount = idCount + 1 end end

            p(("--- handle #%d mode=%s shown=%s built=%s buttons=%d")
                :format(n, tostring(cfg.mode or "important"), tostring(h.frame:IsShown()),
                    tostring(h.container ~= nil), #h.buttons))
            p(("    parent=%s size=%s num=%s onlyMine=%s")
                :format(tostring(h.frame:GetParent() and h.frame:GetParent():GetName() or "?"),
                    tostring(cfg.size), tostring(cfg.num), tostring(cfg.onlyMine)))
            p(("    spellIDs=%d  showDuration=%s  durFmt=%s")
                :format(idCount, tostring(cfg.showDuration),
                    tostring(ACC.GetDurationFormatter(cfg.showDuration) and true or false)))
            -- escape the pipes: the chat frame eats "|R" (colour reset) and prints
            -- "HARMFUL|RAID" as "HARMFULAID", which reads like a broken filter string
            for _, ri in ipairs(h._recordInfo or {}) do p("    record:", (ri:gsub("|", "||"))) end
            if h._recordInfo and #h._recordInfo == 0 then p("    record: (none -- container shows nothing)") end
            -- the fail-open state: "assist=false" IS the "why is my whitelist showing
            -- every buff" answer, and it is invisible from anywhere else
            if h._gateVulnerable or h._gateSourceRelative then
                p(("    身分閘：白名單依賴=%s 來源依賴=%s assist=%s visible=%s 隱藏=%s 失效方向=%s")
                    :format(tostring(h._gateVulnerable or false), tostring(h._gateSourceRelative or false),
                        tostring(h._gateAssist), tostring(h._gateVisible), tostring(h._gateHidden or false),
                        GATE_FAIL_CLOSED and "隱藏(fail-closed)" or "顯示(fail-open)"))
            end
            -- flow-layout ground truth: what orientation asked for, what the container
            -- ACTUALLY resolved to, and whether each setter took (see ACC.ApplyFlowLayout).
            -- If Get* disagrees with the orientation, the setters are not applying; if they
            -- agree yet growth still looks wrong, it is the container pin / SetSize instead.
            if h.container and h.container.GetFlowLayoutAnchorPoint and cfg.mode ~= "overlay" then
                local c = h.container
                local function g(fn) local ok, a, b = pcall(fn, c); if not ok then return "?" end
                    return b ~= nil and (tostring(a) .. "," .. tostring(b)) or tostring(a) end
                local d = c._acFlowDbg or {}
                p(("    flow：orient=%s → anchor=%s axis=%s growth=%s maxline=%s")
                    :format(tostring(d.orientation),
                        g(c.GetFlowLayoutAnchorPoint), g(c.GetFlowLayoutAxis),
                        g(c.GetFlowLayoutGrowthDirection), g(c.GetFlowLayoutMaximumLineSize)))
                p(("        set{axis=%s growth=%s anchor=%s maxline=%s} AnchorUtil.FlowDirection=%s")
                    :format(tostring(d.axis), tostring(d.growth), tostring(d.anchor), tostring(d.maxline),
                        tostring(AnchorUtil and AnchorUtil.FlowDirection ~= nil)))
            end
            for _, e in ipairs(h._errors or {}) do p("    ERR:", e) end
        end
    end
    if n == 0 then p("no container handles bound to unit " .. tostring(unitToken)) end
end

-- ============================================================
-- OVERDRAW REPORT  ->  /cab overdraw [unit]
--
-- Answers "what is drawing twice, and what is wasted". AuraButton visibility is secret,
-- but a container's own RECT is not -- two containers sharing a rect ARE overlapping,
-- and that is what a doubled icon looks like. Also totals the buttons Blizzard allocated
-- (it batches 10 at a time, per GROUP) so the real cost is visible.
-- ============================================================

local function RectKey(f)
    local l, b = f:GetLeft(), f:GetBottom()
    local w, h = f:GetWidth(), f:GetHeight()
    if not (l and b and w and h) then return nil end
    return ("%d,%d %dx%d"):format(l + 0.5, b + 0.5, w + 0.5, h + 0.5)
end

function AD.Overdraw(unitToken)
    unitToken = unitToken or "player"
    local byRect, rows = {}, {}
    local buttons, empties, live = 0, 0, 0

    for h in pairs(AD._instances or {}) do
        if h.unit == unitToken then
            local cfg = h.config or {}
            local mode = tostring(cfg.mode or "important")
            local recs = h._recordInfo and #h._recordInfo or 0
            buttons = buttons + #h.buttons
            if h.container then live = live + 1 end
            if h.container and recs == 0 then empties = empties + 1 end

            local key = h.frame and RectKey(h.frame) or nil
            if key then
                byRect[key] = byRect[key] or {}
                tinsert(byRect[key], mode)
            end
            tinsert(rows, ("  %-10s rect=%-18s groups=%d buttons=%d init=%s num=%s")
                :format(mode, tostring(key), recs, #h.buttons, tostring(h._initCount), tostring(cfg.num)))
        end
    end

    p("=== containers on " .. tostring(unitToken) .. " ===")
    for _, r in ipairs(rows) do p(r) end

    local collisions = 0
    for key, modes in pairs(byRect) do
        if #modes > 1 then
            collisions = collisions + 1
            p(("|cffff5555OVERLAP|r rect=%s <- %s"):format(key, table.concat(modes, " + ")))
        end
    end

    p(("totals: %d live containers, %d with NO groups (pure waste), %d AuraButtons allocated, %d overlapping rects")
        :format(live, empties, buttons, collisions))

    -- global waste tally: recordless containers exist on every button in every header
    local gLive, gEmpty, gButtons = 0, 0, 0
    for h in pairs(AD._instances or {}) do
        if h.container then
            gLive = gLive + 1
            gButtons = gButtons + #h.buttons
            if not h._recordInfo or #h._recordInfo == 0 then gEmpty = gEmpty + 1 end
        end
    end
    p(("ACCOUNT-WIDE: %d live containers, %d recordless, %d AuraButtons"):format(gLive, gEmpty, gButtons))
end

-- ============================================================
-- /cab -- one entry point for all of the above
-- (inherited from the old bridge; the sub-commands that only made sense for its
-- scrape-and-poll model -- test / reset / where -- are gone with it.)
-- ============================================================

SLASH_CELLAURACONTAINER1 = "/cab"
SlashCmdList["CELLAURACONTAINER"] = function(msg)
    local cmd, arg = strsplit(" ", strtrim(msg or ""), 2)
    cmd = (cmd or ""):lower()

    if cmd == "test" then
        StepTest()
    elseif cmd == "ghosts" then
        AD.Ghosts()
    elseif cmd == "inspect" then
        AD.Inspect(arg and strtrim(arg) ~= "" and strtrim(arg) or "player")
    elseif cmd == "overdraw" then
        AD.Overdraw(arg and strtrim(arg) ~= "" and strtrim(arg) or "player")
    elseif cmd == "gate" then
        -- manual unstick: re-probe every vulnerable handle and force the re-parse the
        -- engine will not do on its own. This is the /reload workaround, without /reload.
        local n = 0
        if AD.GateSweep then AD.GateSweep() end
        for h in pairs(AD._instances or {}) do
            if not h._destroyed and h.container and (h._gateVulnerable or h._gateSourceRelative) then
                n = n + 1
                h:GateRefresh()
            end
        end
        p(("身分閘：已重新掃描並強制重讀 %d 個容器%s"):format(n,
            InCombatLockdown() and "（戰鬥中只能標記，離開戰鬥後補跑）" or ""))
    elseif cmd == "spell" then
        -- "will this spell go secret in combat?" ShouldSpellAuraBeSecret answers for the
        -- SPELL, not for anyone currently carrying it, so it is safe to ask mid-combat.
        local spellID = tonumber(arg)
        if not spellID then
            p("用法：/cab spell <spellID>")
            return
        end
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        p(("法術 %d %s"):format(spellID, name and ("（" .. name .. "）") or ""))
        if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
            local isSecret = C_Secrets.ShouldSpellAuraBeSecret(spellID)
            p(("戰鬥中是否 secret：%s%s"):format(tostring(isSecret),
                isSecret and " —— 讀不到它，只有容器的 includeSpellIDs 看得見（且僅限增益）" or ""))
        else
            p("C_Secrets.ShouldSpellAuraBeSecret 不存在")
        end
    elseif cmd == "list" then
        -- which indicators are container-backed on a real unit button
        local shown = false
        F.IterateAllUnitButtons(function(b)
            if shown or not b.indicators then return end
            shown = true
            p("=== " .. tostring(b:GetName() or "?") .. " ===")
            for name, ind in pairs(b.indicators) do
                if type(ind) == "table" and (ind.container or ind.highlightContainer) then
                    local c = ind.container
                    p(("  %-22s mode=%s num=%s built=%s"):format(name,
                        tostring(c and c.config and c.config.mode or "important"),
                        tostring(c and c.config and c.config.num or "?"),
                        tostring(c ~= nil and c.container ~= nil)))
                end
            end
        end, true)
        if not shown then p("找不到任何 unit button") end
    else
        p("supported =", tostring(AD.IsSupported()), "|", tostring(ACC.Failure() or "OK"))
        AD.Debug()
        p("其他：/cab list | ghosts | inspect [unit] | overdraw [unit] | spell <id> | gate | test")
    end
end

return AD
