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
---@type CellIndicatorFuncs
local I = Cell.iFuncs

local pcall, ipairs, pairs, next, tinsert = pcall, ipairs, pairs, next, tinsert
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local issecretvalue = issecretvalue or function() return false end

-- UnitIsUnit answers with a SECRET boolean as soon as the pairing involves a unit you are
-- not allowed to identify -- "boss1" vs "party4" is the one that shows up in the vehicle
-- watcher -- and comparing a secret boolean is an instant Lua error, not a false.
-- Tri-state on purpose: true/false only when the engine actually told us, nil for
-- "not allowed to know", so every caller has to say out loud what it does with doubt.
local function SameUnit(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    if a == b then return true end
    local ok, same = pcall(UnitIsUnit, a, b)
    if not ok or issecretvalue(same) then return nil end
    return same == true
end

-- How many single-spell effect slots one indicator may declare before it collapses back to
-- a single shared slot. Each slot is an AuraButton on EVERY unit button, so this is a real
-- per-frame cost, not a config nicety.
local EFFECT_PER_SPELL_CAP = 8

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

-- Lifecycle counters -> /cab stats. A build is not free and, worse, is not reclaimable:
-- WoW frames cannot be destroyed, so every container we discard stays resident until
-- /reload. `discards` is therefore a running leak count, not just a work count -- if it
-- climbs while nothing but the roster is changing, something is rebuilding that should be
-- re-pointing (see Handle:SetUnit).
-- `parks`/`reuses` are the same counters seen from the other side: a park is a container
-- kept instead of leaked, a reuse is one taken back instead of created. builds+reuses is
-- the total demand; builds alone is what the client actually had to allocate.
AD.stats = {builds = 0, discards = 0, repoints = 0, parks = 0, reuses = 0}

local function BuildRecordsRaw(opts)
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
        -- PER-AURA COLOUR (the border effect): the colour belongs to the SPELL, and which
        -- spell matched is exactly what a container will not tell us. So ask a different
        -- question -- declare one slot PER spell, each filtered to that single ID and tinted
        -- at style time. The engine shows whichever one is actually present, and the colour
        -- is right because the slot could only ever have been that spell.
        -- Capped: each slot is a real AuraButton on every unit button, and past a handful the
        -- indicator is really a list, not a highlight. Over the cap it collapses to one slot
        -- in the first spell's colour rather than refusing to render.
        local perSpell = opts.effectSpellColors
        if type(perSpell) == "table" then
            local recs = {}
            for id in pairs(ids) do
                if type(id) == "number" then
                    recs[#recs + 1] = {
                        key = "eff" .. id, filter = f,
                        candidateFilters = { includeSpellIDs = { [id] = true } },
                        effColor = perSpell[id],
                    }
                end
            end
            if #recs > 0 and #recs <= EFFECT_PER_SPELL_CAP then
                -- stable order so a park key built from these records does not churn
                table.sort(recs, function(a, b) return a.key < b.key end)
                return recs
            end
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

-- ============================================================
-- CANONICAL FILTER STRINGS
--
-- The engine batches aura parsing per container BY THE FILTER STRING, and two of them share
-- one parse only when the strings are byte-identical. Everything above builds these by
-- concatenation, in whatever order each branch happens to append -- so
-- "HARMFUL|RAID|!CROWD_CONTROL" and "HARMFUL|!CROWD_CONTROL|RAID" mean exactly the same
-- thing and get scanned twice, once per spelling.
--
-- One canonical order fixes that for free: polarity first (the engine wants it there), then
-- everything else alphabetically, with a negation sorted directly after its bare token so
-- "!RAID" never drifts away from "RAID".
--
-- ⚠ Applied AFTER ValidFilter, deliberately. Validation runs on the string each branch
-- actually composed, so a rejected token is still reported against the spelling that was
-- written -- and reordering a token set never changes whether it is valid.
-- ============================================================
local filterCanonCache = {}

local function CanonFilter(f)
    if type(f) ~= "string" or f == "" then return f end
    local cached = filterCanonCache[f]
    if cached then return cached end

    local base, rest = nil, {}
    for token in f:gmatch("[^|]+") do
        if token == "HELPFUL" or token == "HARMFUL" then
            base = token
        else
            rest[#rest + 1] = token
        end
    end
    table.sort(rest, function(a, b)
        local ka = a:sub(1, 1) == "!" and (a:sub(2) .. "!") or a
        local kb = b:sub(1, 1) == "!" and (b:sub(2) .. "!") or b
        return ka < kb
    end)

    local out
    if base and #rest > 0 then
        out = base .. "|" .. table.concat(rest, "|")
    elseif base then
        out = base
    else
        out = table.concat(rest, "|")
    end
    filterCanonCache[f] = out
    return out
end
AD.CanonFilter = CanonFilter

local function BuildRecords(opts)
    local records = BuildRecordsRaw(opts)
    for i = 1, #records do
        records[i].filter = CanonFilter(records[i].filter)
    end
    return records
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
-- HARMFUL pools have their own ID gate (UnitCanAttack, and ID filtering on a friendly
-- unit's debuffs is banned outright anyway -- see the debuff mode above), so they never
-- lose a whitelist the way a buff row does. They are NOT exempt from the fallout, though:
-- when the engine refuses to resolve a unit's identity AT ALL it drops the entire
-- candidateFilters payload, booleans included, and the HARMFUL rows lean on those just as
-- hard (see RecordUsesCandidateFilters). Offline proved that; a cross-faction party member
-- is handled the same way here -- user call: an empty row beats a wrong one.
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

-- A record whose CORRECTNESS rests on candidateFilters, whatever the pool. The two
-- predicates above are about the HELPFUL identity gate; this one exists for the OFFLINE
-- case, where the engine drops candidateFilters wholesale for a unit it can no longer
-- resolve -- and Cell's HARMFUL rows lean on them just as hard as the buff rows do:
--   * the debuff row's blacklist rides on excludeSpellIDs (Ghost / Resurrecting /
--     Exhaustion -- exactly what a disconnected, usually dead player is wearing), and
--   * every "already claimed by the row above" subtraction is a candidateFilter boolean
--     (isBossOrRoleAura = false, isPriorityAura = false), so losing them double-draws the
--     same debuff in the central row AND the debuff row.
-- Pure filter-string records (the dispel icons, the health-bar overlay) have nothing to
-- lose here and are deliberately NOT flagged -- they keep working while a member is offline.
local function RecordUsesCandidateFilters(rec)
    local cf = rec.candidateFilters
    return (type(cf) == "table" and next(cf) ~= nil) and true or false
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

-- ============================================================
-- EFFECT SLOTS  (the answer to "presence is secret")
--
-- An effect indicator (colour tint, frame border, rect, texture) renders aura PRESENCE
-- rather than an icon, and presence is exactly what 12.1 took away -- which is why these
-- froze on the manual scan path for a whole encounter.
--
-- The way out is to stop asking. Declare an AddAuraSlot, let the engine own the slot
-- button's visibility, and BUILD THE EFFECT ONTO THAT BUTTON: the tint/border/texture is
-- a child of the button, so it appears and disappears with the aura and nothing on our
-- side ever reads whether the aura is there. The whole chain
-- (handle.frame -> host -> AuraContainer -> slot button) is SetAllPoints, so anchoring
-- handle.frame at the health bar puts the effect on the health bar.
--
-- Usually that is one slot. Where the colour belongs to the SPELL rather than to the
-- indicator (border), it is one slot PER spell instead -- see BuildRecords: the slot could
-- only ever have been that one spell, so its colour is knowable without reading anything.
--
-- Three rules, all learned the hard way (and all of them fail SILENTLY):
--   1. Every region is created in the initializeFrame window (StyleButton's first pass on
--      a button). Outside it the engine denies calls on the button subtree and the pcall
--      swallows the denial, so "create it in the apply pass" builds nothing, ever.
--   2. Nothing is READ back from the button afterwards -- not a level, not a rect. Set it
--      at creation and leave it.
--   3. No Lua-driven animation: OnUpdate / AnimationGroup attach inside the subtree but
--      never tick (onUpdateMode is disabled and inherits). Effects are static. Anything
--      time-based must come from the engine (SetDurationCooldown / SetDurationBar) or not
--      at all -- "fade out as it expires" is gone with the remaining duration.
-- ============================================================
local EFFECT_SLOT_STYLES = {
    color   = true,   -- health-bar / unit-button tint
    border  = true,   -- ring around the unit button
    rect    = true,   -- filled rectangle with a border
    texture = true,   -- arbitrary texture / atlas
}
AD.EFFECT_SLOT_STYLES = EFFECT_SLOT_STYLES

-- Single-slot containers: one AddAuraSlot filling the handle frame, no flow layout.
-- The dispel health-bar highlight (mode "overlay") was the first of these; the effect
-- styles are the same shape with a different visual.
local function IsSlotMode(cfg)
    if not cfg then return false end
    return cfg.mode == "overlay" or (cfg.customStyle ~= nil and EFFECT_SLOT_STYLES[cfg.customStyle] == true)
end
AD.IsSlotMode = IsSlotMode

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

-- ============================================================
-- EFFECT SLOT RENDERING
--
-- One slot button, one static visual built onto it. Read the EFFECT SLOTS note above
-- before touching anything here -- especially rule 1 (create in the window) and rule 3
-- (nothing animates).
--
-- Every region hangs off a holder frame we create on the button rather than off the button
-- itself: a holder is ours, so its colours can still be written later (the class-colour
-- refresh does exactly that), while the button's own methods are denied outside the window.
-- ============================================================

-- Resolve a {r,g,b,a} array, with a fallback for a malformed/absent entry.
local function ColorOr(c, fr, fg, fb, fa)
    if type(c) == "table" and type(c[1]) == "number" then
        return c[1], c[2] or 0, c[3] or 0, c[4] or 1
    end
    return fr, fg, fb, fa
end

-- The colour a `color` indicator settles on. Its time-varying modes cannot survive here --
-- change-over-time reads the remaining duration, which is secret -- so each collapses onto
-- the shade it would show at full duration. class-color is resolved live (see
-- Handle:RefreshEffectTint); everything else is baked at style time.
local function EffectColorFor(handle, cfg)
    local colors = cfg.effectColors
    local kind = type(colors) == "table" and colors[1] or "solid"
    if kind == "class-color" then
        -- Resolved from the UNIT, so it changes with no config change at all: SetContainerUnit
        -- stamps handle._effClassColor and Handle:RefreshEffectTint repaints the live texture.
        -- ⚠ Deliberately NOT in config -- ParkKey hashes config, so a class colour in there
        -- would give every class its own park bucket and destroy reuse for the one style that
        -- does not need a rebuild to change colour.
        return ColorOr(handle._effClassColor, 0.5, 0.5, 0.5, 1)
    end
    if kind == "change-over-time" then
        -- colors[4] is the "plenty of time left" colour; [5]/[6] are the percent/seconds
        -- bands, and neither can fire without a readable countdown.
        return ColorOr(colors[4], 0, 1, 0, 1)
    end
    return ColorOr(colors and colors[2], 0, 1, 0, 1)
end

local function BuildEffectColor(handle, button, cfg)
    local holder = button.dfEffHolder
    if not holder then
        holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button)
        button.dfEffHolder = holder
        button.dfEffTex = holder:CreateTexture(nil, "ARTWORK")
        button.dfEffTex:SetAllPoints(holder)
        button.dfEffGrad = holder:CreateTexture(nil, "ARTWORK")
        button.dfEffGrad:SetAllPoints(holder)
    end

    local colors = cfg.effectColors
    local kind = type(colors) == "table" and colors[1] or "solid"
    local tex, grad = button.dfEffTex, button.dfEffGrad

    if kind == "gradient-vertical" or kind == "gradient-horizontal" then
        tex:Hide()
        grad:SetTexture(Cell.vars.whiteTexture)
        local r1, g1, b1, a1 = ColorOr(colors[2], 0, 1, 0, 1)
        local r2, g2, b2, a2 = ColorOr(colors[3], 0, 1, 0, 0)
        grad:SetGradient(kind == "gradient-vertical" and "VERTICAL" or "HORIZONTAL",
            CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
        grad:Show()
    else
        grad:Hide()
        -- The player's own statusbar texture, matching what the manual path drew. Read here
        -- (style time) rather than on an OnShow hook: script handlers are forbidden on this
        -- subtree, and an appearance change rebuilds the container anyway.
        tex:SetTexture(Cell.vars.texture)
        local r, g, b, a = EffectColorFor(handle, cfg)
        tex:SetVertexColor(r, g, b, a)
        tex:Show()
    end
end

local function BuildEffectBorder(handle, button, cfg)
    -- Cell's border ring is a full-rect texture with a mask punched out of the middle,
    -- plus a second, larger-masked black texture underneath for the outline. Masks are
    -- pure rendering, so the whole thing survives the forbidden subtree untouched.
    local thickness = cfg.effectThickness or 2
    local holder = button.dfEffHolder
    if not holder then
        holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button)
        button.dfEffHolder = holder

        local mask = holder:CreateMaskTexture()
        mask:SetTexture(Cell.vars.emptyTexture, "CLAMPTOWHITE", "CLAMPTOWHITE")
        button.dfEffMask = mask
        local tex = holder:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints(holder)
        tex:SetTexture(Cell.vars.whiteTexture)
        tex:AddMaskTexture(mask)
        button.dfEffTex = tex

        local mask2 = holder:CreateMaskTexture()
        mask2:SetTexture(Cell.vars.emptyTexture, "CLAMPTOWHITE", "CLAMPTOWHITE")
        button.dfEffMask2 = mask2
        local tex2 = holder:CreateTexture(nil, "ARTWORK", nil, -1)
        tex2:SetAllPoints(holder)
        tex2:SetColorTexture(0, 0, 0)
        tex2:AddMaskTexture(mask2)
    end

    local m, m2 = button.dfEffMask, button.dfEffMask2
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", holder, "TOPLEFT", thickness, -thickness)
    m:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -thickness, thickness)
    m2:ClearAllPoints()
    m2:SetPoint("TOPLEFT", holder, "TOPLEFT", thickness + CELL_BORDER_SIZE, -thickness - CELL_BORDER_SIZE)
    m2:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -thickness - CELL_BORDER_SIZE, thickness + CELL_BORDER_SIZE)

    -- per-spell slot colour first (see BuildRecords), then the indicator-level fallback
    local r, g, b, a = ColorOr(button._adEffColor or cfg.effectColors, 1, 0, 0, 1)
    button.dfEffTex:SetVertexColor(r, g, b, a)
end

local function BuildEffectRect(handle, button, cfg)
    local holder = button.dfEffHolder
    if not holder then
        holder = CreateFrame("Frame", nil, button, "BackdropTemplate")
        holder:SetAllPoints(button)
        holder:SetBackdrop({ edgeFile = Cell.vars.whiteTexture, edgeSize = CELL_BORDER_SIZE })
        button.dfEffHolder = holder
        button.dfEffTex = holder:CreateTexture(nil, "BORDER", nil, -7)
        button.dfEffTex:SetAllPoints(holder)
    end
    local colors = cfg.effectColors
    local fr, fg, fb, fa = ColorOr(colors and colors[1], 0, 1, 0, 1)
    button.dfEffTex:SetColorTexture(fr, fg, fb, fa)
    local br, bg, bb, ba = ColorOr(colors and colors[4], 0, 0, 0, 1)
    holder:SetBackdropBorderColor(br, bg, bb, ba)
end

local function BuildEffectTexture(handle, button, cfg)
    local holder = button.dfEffHolder
    if not holder then
        holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button)
        button.dfEffHolder = holder
        button.dfEffTex = holder:CreateTexture(nil, "OVERLAY")
        button.dfEffTex:SetAllPoints(holder)
    end
    local spec = cfg.effectTexture
    local path = type(spec) == "table" and spec[1] or nil
    local tex = button.dfEffTex
    if type(path) == "string" and path ~= "" then
        if path:lower():find("^interface") then
            tex:SetTexture(path)
        else
            tex:SetAtlas(path)
        end
    end
    tex:SetRotation(((type(spec) == "table" and spec[2]) or 0) * math.pi / 180)
    local r, g, b, a = ColorOr(type(spec) == "table" and spec[3] or nil, 1, 1, 1, 1)
    tex:SetVertexColor(r, g, b, a)
end

local EFFECT_BUILDERS = {
    color   = BuildEffectColor,
    border  = BuildEffectBorder,
    rect    = BuildEffectRect,
    texture = BuildEffectTexture,
}

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

    -- EFFECT SLOT styles (buff-only): colour / border / rect / texture. Same cure as
    -- block/text -- the container owns the button's visibility, so aura PRESENCE needs no
    -- read -- but these fill their whole anchor rather than sitting in a row, so the slot
    -- button IS the effect. See the EFFECT SLOTS note at the top of the file.
    -- ⚠ No time-based behaviour of any kind: the old fade-out / colour-by-remaining and the
    -- percent-and-seconds threshold bands all needed a countdown we can no longer read.
    local effBuild = cfg.customStyle and EFFECT_BUILDERS[cfg.customStyle]
    if effBuild then
        effBuild(handle, button, cfg)
        -- rect is the one effect with room for text, and Blizzard renders both blind, so it
        -- keeps its countdown and stack -- more than the manual path could show in an
        -- instance. The others are pure fills with nowhere sensible to put a number.
        if cfg.customStyle == "rect" then
            BindDurStack(button, cfg, button:GetFrameLevel(), BuildDurColorOpt(cfg))
            if button.dfDur then
                local colors = cfg.effectColors
                local nb = (cfg.durationColors and cfg.durationColors.base)
                    or (type(colors) == "table" and colors[4])
                local r, g, b, a = ColorOr(nb, 1, 1, 1, 1)
                button.dfDur:SetTextColor(r, g, b, a)
            end
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
        -- top band equals this, so they agree; if the curve was refused this is the whole colour).
        -- text: durationColors.base (the unified widget's Normal), falling back to borderColor.
        if button.dfDur then
            if cfg.customStyle == "block" then
                button.dfDur:SetTextColor(1, 1, 1, 1)
            else
                -- text: the option's base colour when it's on; plain WHITE when off (no more
                -- falling back to the old green/red colours the option is meant to replace).
                local nb = cfg.durationColors and cfg.durationColors.base
                if type(nb) == "table" and type(nb[1]) == "number" then
                    button.dfDur:SetTextColor(nb[1], nb[2] or 1, nb[3] or 1, nb[4] or 1)
                else
                    button.dfDur:SetTextColor(1, 1, 1, 1)
                end
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
    -- Three mutually exclusive looks, picked per indicator by animationStyle:
    --
    --   "border"    the default, and what Cell has always drawn. A Cooldown covering the
    --               WHOLE button, UNDER the icon frame -- so only the ring shows it, and
    --               SetReverse(true) makes the swipe cover the ELAPSED arc: black grows,
    --               the coloured arc shrinks clockwise. Two layers, only the border moves.
    --   "clock"     the same Cooldown moved ABOVE the icon and made translucent, i.e.
    --               Blizzard's own spell-cooldown look, sweeping over the art itself.
    --   "vertical"  a StatusBar over the ICON, filling downward from the top: Cell's old
    --               CELL_COOLDOWN_STYLE = "VERTICAL" shadow, driven by Blizzard through
    --               SetDurationBar instead of by a ticker we cannot run on secret auras.
    --               VERTICAL + SetReverseFill(true) is what makes it fall downward --
    --               verified in game on the pre-Cell AuraContainer bridge.
    --   "none"      none of them.
    --
    -- animationStyle is not in COSMETIC_KEYS/LAYOUT_KEYS, so SetOptions treats a change as
    -- structural and rebuilds -- which is what this needs, since the binds only happen while
    -- the button is being styled. Absent falls back to the old showAnimation boolean.
    local animStyle = I.ResolveAnimationStyle(cfg)
    local ringSweep = animStyle == "border"
    local iconSweep = animStyle == "clock"
    local swipeOn = ringSweep or iconSweep
    local maskOn = animStyle == "vertical"

    if swipeOn and not button.dfCD then
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
    if button.dfCD then
        if swipeOn then
            button.dfCD:ClearAllPoints()
            if iconSweep then
                -- over the icon, translucent: the point of this style is seeing the art
                button.dfCD:SetAllPoints(button.dfIconFrame)
                button.dfCD:SetFrameLevel(base + 4)
                button.dfCD:SetSwipeColor(SPENT_COLOR[1], SPENT_COLOR[2], SPENT_COLOR[3], 0.77)
            else
                -- under the icon: only the ring is left to show it, opaque so it fully
                -- replaces the ring colour as it grows
                button.dfCD:SetAllPoints(button)
                button.dfCD:SetFrameLevel(base + 1)
                button.dfCD:SetSwipeColor(SPENT_COLOR[1], SPENT_COLOR[2], SPENT_COLOR[3], 1)
            end
            button.dfCD:Show()
        else
            -- A recycled button may already carry a bound swipe. Unbind before hiding, or
            -- Blizzard keeps driving a frame the user asked to be rid of.
            if button._boundCD and button.ClearDurationCooldown then
                button:ClearDurationCooldown()
                button._boundCD = nil
            end
            button.dfCD:Hide()
        end
    end

    if maskOn and not button.dfMask then
        -- ⚠ Parented to the button, anchored to the icon frame: it has to sit ABOVE the
        -- icon (base + 3) or the mask would be hidden behind it, and it deliberately does
        -- NOT cover the ring so the dispel colour stays readable while the shadow falls.
        button.dfMask = CreateFrame("StatusBar", nil, button)
        button.dfMask:SetOrientation("VERTICAL")
        button.dfMask:SetReverseFill(true)
        button.dfMask:SetStatusBarTexture(ACC.WHITE)
        button.dfMask:GetStatusBarTexture():SetVertexColor(0, 0, 0, 0.65)
    end
    if button.dfMask then
        if maskOn then
            button.dfMask:ClearAllPoints()
            button.dfMask:SetAllPoints(button.dfIconFrame)
            button.dfMask:SetFrameLevel(base + 3)
            button.dfMask:Show()
        else
            if button._boundMask and button.ClearDurationBar then
                button:ClearDurationBar()
                button._boundMask = nil
            end
            button.dfMask:Hide()
        end
    end

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
    if swipeOn and button.dfCD and button.SetDurationCooldown and not button._boundCD then
        button:SetDurationCooldown(button.dfCD)
        button._boundCD = true
    end
    if maskOn and button.dfMask and button.SetDurationBar and not button._boundMask then
        button:SetDurationBar(button.dfMask)
        button._boundMask = true
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

-- How many icons ONE group may show, given its position in the declaration order.
--
-- ⚠ There is no cross-group total anywhere in the API: maxFrameCount is per GROUP, and
-- SetFlowLayoutMaximumLineSize is a line-WRAP budget (overflow starts a second row, it is
-- never clipped). So the total is whatever we hand out here, and handing it out badly is
-- silent in one direction and ugly in the other.
--
-- Splitting `num` evenly across the groups was worse than it looks. The important display
-- declares five categories and defaults to num=3, so every group got ceil(3/5) = 1:
--   * the common case UNDER-fills -- three boss debuffs and nothing else is one populated
--     group and four idle ones, so two of the three icons the user asked for silently
--     never appear;
--   * and the worst case still overshoots anyway (five populated groups = 5 > 3), so the
--     even split did not even buy the cap it was paying for.
--
-- Declaration order already IS the priority order (BuildRecords declares important-first),
-- so the budget follows it: the first group gets the whole `num`, everyone below gets one
-- slot to prove they have something. num=3 over five categories is 3,1,1,1,1 -- worst case
-- 7 instead of 15, and the case that actually happens is correct.
--
-- Index is the position among groups that were ADDED SUCCESSFULLY (handle._groupKeys),
-- not among records: if the top record's filter string is rejected, the next one becomes
-- the first real group and inherits the full budget. Keep Build and Handle:SetNum both
-- calling this -- they used to carry the same formula twice.
local function GroupBudget(index, total, wanted)
    if total <= 1 then return wanted end
    return index == 1 and wanted or 1
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

-- ============================================================
-- CONTAINER PARK
--
-- WoW frames cannot be destroyed, so every container a rebuild throws away stays resident
-- until /reload. Re-pointing already killed the roster-churn rebuilds (Handle:SetUnit), but
-- the ones that remain are the expensive kind: an automatic LAYOUT SWITCH rebuilds every
-- container on every unit button at once, and people switch layouts every time they zone.
--
-- So a torn-down host is parked under its build key instead of orphaned, and the next build
-- asking for that exact key takes it back. Dungeon -> raid -> dungeon then costs one set of
-- containers, not three.
--
-- ⚠ WHAT THE KEY MUST COVER: everything baked into the container at build time -- the group
-- topology AND the per-button styling. Styling is in there because an existing AuraButton
-- can only be styled from initializeFrame: once auras are secret, Restyle cannot touch it
-- and rebuilds instead (see Handle:Restyle) -- which is exactly the situation inside the
-- instance where the layout just switched. A container is therefore only ever handed to a
-- handle that would have styled its buttons identically.
-- Live-settable state (unit, frame level, layout geometry, maxFrameCount) is deliberately
-- NOT in the key -- Build re-sends all of it.
-- ============================================================

-- Kill switch. If a reused container ever comes back showing the wrong unit's auras or a
-- blank row, turn it off and /reload: every build then creates fresh, as it did before.
--   /run Cell.AuraDisplay.PARK_ENABLED=false
AD.PARK_ENABLED = true
local PARK_CAP = 240        -- parked hosts held at once; past this, teardown orphans as before
local park, parkCount = {}, 0
local parkHolder
local NO_RECORDS = {}

local function ParkHolder()
    if not parkHolder then
        parkHolder = CreateFrame("Frame", nil, UIParent)
        parkHolder:Hide()   -- parked hosts must not render or lay out while stored
    end
    return parkHolder
end

local function ParkKey(handle, records, slotMode)
    local parts = {slotMode and "ov" or "flow", handle._testMinimal and "min" or ""}
    for _, rec in ipairs(records) do
        parts[#parts + 1] = rec.key .. "~" .. rec.filter .. "~" .. (TableSig(rec.candidateFilters) or "")
    end
    parts[#parts + 1] = "cfg:" .. (TableSig(handle.config) or "")
    -- StyleButton reads the dispel palette straight out of CellDB rather than from config,
    -- so it belongs to the key as well: a container styled with the old colours must not be
    -- handed to a handle expecting the new ones.
    parts[#parts + 1] = "pal:" .. (TableSig(CellDB and CellDB["debuffTypeColor"]) or "")
    return table.concat(parts, "|")
end

-- Quiesce the handle's host and stash it (its container, buttons and group keys ride along),
-- or orphan it exactly the way this used to when parking is off/full/unsafe.
local function ParkOrDiscard(handle)
    local host, c = handle.host, handle.container
    handle.host, handle.container = nil, nil

    -- ⚠ Nothing beyond SetEnabled/Hide is ever called ON the container: it carries Forbidden
    -- Aspects, a refused SetParent would be swallowed by the pcall, and the container would
    -- keep rendering under its replacement. The host is ours -- moving that moves it.
    if c then
        pcall(function() c:SetEnabled(false) end)
        if not host then
            pcall(function() c:Hide() end)
            AD.stats.discards = AD.stats.discards + 1
            return
        end
    end
    if not host then return end

    host._adOwner = nil     -- a late initializeFrame must not append to a handle that let go
    host:Hide()
    host:ClearAllPoints()

    local key = handle._parkKey
    if AD.PARK_ENABLED and c and key and parkCount < PARK_CAP then
        host._adGroupsAdded = handle._groupsAdded
        host:SetParent(ParkHolder())
        -- verify the host actually went quiet; a host that still shows would draw its icons
        -- on top of whatever replaced it, and parking it would spread that to the next user
        if not host:IsShown() then
            local stack = park[key]
            if not stack then stack = {}; park[key] = stack end
            stack[#stack + 1] = host
            parkCount = parkCount + 1
            AD.stats.parks = AD.stats.parks + 1
            return
        end
    end

    host:SetParent(nil)
    -- verify the disposal actually took. If this ever trips, the ghost icons are NOT a
    -- teardown-order problem and AD.Ghosts() will say so instead of us guessing.
    if host:IsShown() or host:GetParent() then
        handle._disposeFailed = (handle._disposeFailed or 0) + 1
    end
    AD.stats.discards = AD.stats.discards + 1
end

local function AcquireParked(key)
    if not AD.PARK_ENABLED then return nil end
    local stack = park[key]
    if not stack or #stack == 0 then return nil end
    local host = table.remove(stack)
    if #stack == 0 then park[key] = nil end
    parkCount = parkCount - 1
    if not host._adContainer then return nil end -- can't happen; never hand back a bare host
    return host
end

-- /cab park  -- what is being held, and under how many distinct keys
function AD.ParkStats()
    local keys = 0
    for _ in pairs(park) do keys = keys + 1 end
    return parkCount, keys
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
    -- Parked under the key it was BUILT with, not the one about to be computed (the config
    -- may have just changed -- that is why we are rebuilding). See the PARK section.
    ParkOrDiscard(handle)
    -- ⚠ REPLACED, not wiped: the old list belongs to the parked host now. Those buttons are
    -- still its buttons, they keep their styling, and they come back together or not at all.
    handle.buttons = {}
    handle._groupKeys = nil
    -- Identity-gate state is re-derived from THIS build's records below. Clearing it here
    -- is what lets a handle rebuilt onto non-vulnerable filters drop a stale hidden flag
    -- instead of staying hidden forever; the assist verdict resets too, because a fresh
    -- parse has no fail-open history to recover from.
    handle._gateVulnerable, handle._gateSourceRelative, handle._gateCFDependent = nil, nil, nil
    handle._gateAssist, handle._gateVisible, handle._gateConnected = nil, nil, nil
    handle._gateFaction = nil

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
        if RecordUsesCandidateFilters(rec) then handle._gateCFDependent = true end
    end

    -- ⚠ declared here, not further down: ParkKey reads it, and a `local` declared after the
    -- read would silently resolve to a nil global there (every overlay keyed as flow).
    -- Slot mode = ONE AddAuraSlot filling the frame: the dispel health-bar highlight and
    -- every effect style (colour/border/rect/texture). Flow mode = a row of icons.
    local slotMode = IsSlotMode(handle.config)

    local key = ParkKey(handle, records, slotMode)
    handle._parkKey = key

    local host, c = AcquireParked(key)
    local reused = host ~= nil
    if reused then
        c = host._adContainer
        host:SetParent(handle.frame)
        host:ClearAllPoints()
        host:SetAllPoints(handle.frame)
        host._adOwner = handle
        host:Show()
        -- its buttons come back with it, already initialised and styled for exactly this key
        handle.buttons = host._adButtons
        handle._groupKeys = host._adGroupKeys
        AD.stats.reuses = AD.stats.reuses + 1
    else
        host = CreateFrame("Frame", nil, handle.frame)
        host:SetAllPoints(handle.frame)

        local ok
        ok, c = pcall(CreateFrame, "AuraContainer", nil, host, "CustomAuraContainerTemplate")
        if not ok or not c then
            host:Hide()
            host:SetParent(nil)
            return
        end
        host._adContainer = c
        host._adButtons = handle.buttons
        host._adGroupKeys = {}
        host._adOwner = handle
        handle._groupKeys = host._adGroupKeys
        AD.stats.builds = AD.stats.builds + 1
    end
    handle.host = host
    handle.container = c
    -- honour the indicator's frameLevel: the AuraButtons inherit their level from THIS chain
    -- (handle.frame -> host -> AuraContainer -> buttons), so set it BEFORE AddAuraGroup or the
    -- buttons keep the default level and the name text (indicatorFrame + level) covers them no
    -- matter what the frameLevel option is set to.
    if handle._hostLevel then
        pcall(function() host:SetFrameLevel(handle._hostLevel) end)
        pcall(function() c:SetFrameLevel(handle._hostLevel) end)
    end
    handle._errors = {}          -- diagnostics: per-step failures (see AD.Debug)
    -- how many buttons Blizzard asked us to style: a reused container already asked, once
    handle._initCount = reused and #handle.buttons or 0
    handle._groupsAdded = reused and (host._adGroupsAdded or #handle._groupKeys) or 0
    handle._enabledWhileVisible = false

    if slotMode then
        -- the slot covers its anchor frame (health bar, unit button, wherever the indicator
        -- put it); no flow layout
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
    -- batch of 10 buttons PER GROUP (50 for three visible icons). The budget is handed out
    -- per group by GroupBudget -- read the note above it before changing the shape.
    local wanted = handle.config.num or 3

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

    -- ⚠ A REUSED container already carries exactly these groups -- they are part of the park
    -- key -- with their buttons created, initialised and styled. AddAuraGroup here would
    -- declare every one of them a second time, so the loop is fed nothing instead.
    for _, rec in ipairs(reused and NO_RECORDS or records) do
        local initFn = function(button)
            -- ⚠ Resolve the owner through the HOST, never through the captured `handle`.
            -- Blizzard keeps this closure inside the group for the container's whole life,
            -- and a parked container comes back owned by a different handle -- a captured
            -- one would append the button to a list nobody reads and style it from a config
            -- nobody is showing.
            local h = host._adOwner
            if not h then return end
            h._initCount = (h._initCount or 0) + 1
            if slotMode then pcall(function() button:SetAllPoints(c) end) end
            -- Per-spell effect slots: stamp the record's colour BEFORE StyleButton so the
            -- builder can read it. Stamped once, at creation, and never re-read from the
            -- engine -- the park key covers the record set, so a returning button always
            -- carries the colour its record was built with.
            if rec.effColor ~= nil then button._adEffColor = rec.effColor end
            -- ⚠ Tracked HERE and nowhere else. This is the only place a genuinely new
            -- button arrives; StyleButton must never append, because Restyle iterates this
            -- very list and calls StyleButton on each entry -- appending from there grew
            -- the list exactly as fast as the iterator advanced, so the loop never ended
            -- and the client froze on every option change that triggers a restyle.
            tinsert(h.buttons, button)
            local okS, errS = pcall(StyleButton, h, button)
            if not okS and h._errors and #h._errors < 6 then -- cap: 50 identical lines helps nobody
                h._errors[#h._errors + 1] = "style: " .. tostring(errS)
            end
        end
        local okG, errG
        if slotMode then
            -- single slot covering the frame (AddAuraGroup eagerly batches; AddAuraSlot
            -- is the genuine single-icon/overlay primitive)
            okG, errG = pcall(c.AddAuraSlot, c, rec.key, rec.filter, {
                initializeFrame = initFn,
                candidateFilters = rec.candidateFilters,
            })
        else
            okG, errG = pcall(c.AddAuraGroup, c, rec.key, rec.filter, {
                -- position among groups added so far (+1 = the one we are adding now)
                maxFrameCount = GroupBudget(#handle._groupKeys + 1, #records, wanted),
                initializeFrame = initFn,
                layout = groupLayout,
                candidateFilters = rec.candidateFilters,
            })
        end
        if okG then
            handle._groupsAdded = handle._groupsAdded + 1
            -- remembered so SetNum can drive maxFrameCount live (slots are always 1)
            if not slotMode then handle._groupKeys[#handle._groupKeys + 1] = rec.key end
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
    if reused then
        -- ⚠ A container that has already parsed does NOT re-parse just because SetUnit
        -- changed underneath it -- same trap as Handle:SetUnit and GateRefresh. Without the
        -- Hide/Show bounce that crosses the partition, the row keeps showing the auras of
        -- whichever unit this container was parked from.
        handle._enabledWhileVisible = false
        handle:ReassertEnable()
        if not handle._enabledWhileVisible then handle:GateRefresh() end
    elseif handle.frame:IsVisible() then
        handle._enabledWhileVisible = true
    end
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

-- Match the container chain's frame level to the indicator's frameLevel so its AuraButtons
-- render above/below siblings as configured. Existing buttons were levelled by Blizzard at
-- build time, so a rebuild is needed to re-level them (frameLevel is an editbox, changes rarely).
function Handle:SetContainerLevel(lvl)
    if type(lvl) ~= "number" or self._hostLevel == lvl then return end
    self._hostLevel = lvl
    -- not built yet -> Build() applies _hostLevel itself, no rebuild needed. Already built ->
    -- set the levels now and rebuild so the existing (Blizzard-levelled) buttons re-inherit.
    if self.host then
        pcall(function() self.host:SetFrameLevel(lvl) end)
        if self.container then pcall(function() self.container:SetFrameLevel(lvl) end) end
        self:Rebuild()
    end
end
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
        -- same allocation Build uses -- one shared GroupBudget so the two cannot drift
        local total = #self._groupKeys
        local allOK = true
        for i, key in ipairs(self._groupKeys) do
            local per = GroupBudget(i, total, n)
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
local COSMETIC_KEYS = {
    stackFont = true, durationFont = true, borderColor = true,
    -- effect-slot visuals: pure styling, so a colour/thickness/texture tweak restyles the
    -- existing slot instead of tearing the container down and rebuilding it
    effectColors = true, effectThickness = true, effectTexture = true,
}

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

-- (TableSig moved above Build -- both SetOptions and the container park need it.)

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

-- Repaint the effect slot's tint WITHOUT a restyle.
--
-- The texture is ours (created on a holder frame we own), and writing to our own regions
-- stays legal outside the initializeFrame window -- it is the BUTTON's own methods and any
-- read-back that the engine denies. That is what makes a live class-colour possible: a
-- roster shuffle re-points the container at a new unit, and this repaints the tint in the
-- same breath. Routing it through SetOptions instead would mark the config dirty and
-- rebuild the container on every roster update, which is the cost SetUnit exists to avoid.
function Handle:SetEffectClassColor(color)
    self._effClassColor = color
    self:RefreshEffectTint()
end

function Handle:RefreshEffectTint()
    local cfg = self.config
    if cfg.customStyle ~= "color" then return end
    local colors = cfg.effectColors
    if type(colors) ~= "table" or colors[1] ~= "class-color" then return end
    local r, g, b, a = ColorOr(self._effClassColor, 0.5, 0.5, 0.5, 1)
    for _, button in ipairs(self.buttons) do
        local tex = button.dfEffTex
        if tex then pcall(tex.SetVertexColor, tex, r, g, b, a) end
    end
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

-- ⚠ Re-point the LIVE container; do not rebuild.
--
-- This used to call Rebuild(), and it was the single biggest cost Cell paid on
-- GROUP_ROSTER_UPDATE. The secure group header re-sorts, a large slice of the buttons get a
-- new unit token, and each of those tore down and recreated EVERY container it owns -- host
-- Frame + AuraContainer + a batch of AuraButtons, each styled with its own Cooldown and
-- holder frames. All in one frame, out of combat (which is when people join and leave), with
-- nothing throttling it. And because WoW frames cannot be destroyed, Build only hides and
-- orphans the old ones: every roster change leaked a batch of frames that only /reload
-- reclaimed. That is the "gets laggier the longer the raid runs" report.
--
-- Nothing structural depends on the unit -- BuildRecords reads config alone -- so the group
-- topology is already correct for the new binding. Re-pointing is the same recipe used by
-- MiliUI_UnitFrames for vehicle swaps (Elements/Auras.lua) and by Platynator for nameplate
-- recycling: SetUnit, then a bounce, because the container does NOT re-parse on its own when
-- the token changes underneath it (UpdateAllAuras from addon context only sets dirty flags --
-- see GateRefresh).
function Handle:SetUnit(unit)
    if issecretvalue(unit) then return end
    if self.unit == unit then return end
    self.unit = unit

    -- Nothing built yet, disabled, or unbinding entirely: those are Build's paths (a nil
    -- unit is how a container gets torn down, and there is nothing to re-point without one).
    if not self.container or not unit then
        self:Rebuild()
        return
    end

    -- Refused: fall back to the old behaviour rather than leave the container rendering the
    -- PREVIOUS unit's auras, which is the one failure mode worse than the cost of a rebuild.
    if not pcall(function() self.container:SetUnit(unit) end) then
        self:Rebuild()
        return
    end
    AD.stats.repoints = AD.stats.repoints + 1

    -- Both gate verdicts belong to the old unit. Clear them exactly as Build does, so the
    -- re-probe below records a fresh baseline instead of firing a bogus recovery edge.
    self._gateAssist, self._gateVisible, self._gateConnected = nil, nil, nil
    self._gateFaction = nil
    -- Runs first: bouncing a row the gate wants hidden does nothing (Show() on a frame whose
    -- parent chain is hidden never fires OnShow), so visibility has to settle before the kick.
    self:ApplyIdentityGate()

    -- Re-parse. ReassertEnable is the fuller kick (SetEnabled + Hide/Show) but only fires out
    -- of combat on a visible frame, and it is one-shot per binding -- this IS a new binding,
    -- so clear the latch and let it run. When it declines, GateRefresh covers the rest: it is
    -- the one that marks the container dirty in combat and replays the real bounce on regen.
    self._enabledWhileVisible = false
    self:ReassertEnable()
    if not self._enabledWhileVisible then self:GateRefresh() end
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
    -- partition kick -> force a fresh scan. Host first, for the same reason as GateRefresh:
    -- a Hide() on the container itself can be refused and the pcall would eat the refusal.
    local host = self.host
    if host then
        pcall(function() host:Hide(); host:Show() end)
    else
        pcall(function() c:Hide(); c:Show() end)
    end
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
    -- ⚠ bounce the HOST, not the container. The container carries Forbidden Aspects, so
    -- Hide()/Show() ON IT can be refused for a tainted caller -- and the pcall swallows the
    -- refusal, so the re-parse silently never happens and the row keeps rendering whatever
    -- it last parsed (a buff that has long since fallen off, or the previous occupant's).
    -- The host is a plain frame we created, hiding it can never be refused, and it takes the
    -- container's visibility with it -- which is what fires the intrinsic OnShow that IS the
    -- re-parse. Same reasoning as the park path, which stopped touching the container for
    -- exactly this reason. The container bounce stays as a fallback for handles built before
    -- the host existed.
    local host = self.host
    if host then
        pcall(function() host:Hide(); host:Show() end)
    else
        pcall(function() c:Hide(); c:Show() end)
    end
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

    if self._gateVulnerable or self._gateSourceRelative or self._gateCFDependent then
        local unit = self.unit
        if type(unit) == "string" and UnitExists(unit) then
            local isOwn = unit == "player"
            if not isOwn then
                -- "raid5" can be you. Doubt counts as own, per the note above: that is
                -- the answer that leaves the row visible in SHOW mode.
                isOwn = SameUnit(unit, "player") ~= false
            end

            -- (1) OFFLINE. UnitCanAssist stays TRUE for a disconnected member -- faction did
            --     not change -- so the assist check below never fires, while the engine can no
            --     longer resolve the unit well enough to apply includeSpellIDs: the curated
            --     rows fill with every buff the player was carrying when they dropped. This is
            --     the fail-open people actually hit (someone disconnects mid-dungeon), and it
            --     is checked first because it is the cheapest definite answer of the three.
            --     ⚠ The event matters as much as the check: UNIT_CONNECTION is the only thing
            --     that fires at the moment of the drop. Without it the row stays wrong until
            --     some unrelated watched event happens to sweep.
            --     ⚠ Unlike (2)/(3) this one is NOT limited to the HELPFUL pools: offline drops
            --     candidateFilters wholesale, so every row that depends on them is affected --
            --     see RecordUsesCandidateFilters. No inner flag test: reaching here already
            --     means at least one of the three dependencies holds.
            do
                local okC, conn = pcall(UnitIsConnected, unit)
                if okC and not issecretvalue(conn) then
                    local was = self._gateConnected
                    self._gateConnected = conn and true or false
                    if was == false and self._gateConnected then recovered = true end
                    if not conn and (not isOwn or GATE_FAIL_CLOSED) then hide = true end
                end
            end

            -- (2) non-assistable (cross-faction, duel, cinematic): includeSpellIDs is
            --     skipped and every helpful aura passes. Signal: UnitCanAssist.
            --     ⚠ Scope is every cf-DEPENDENT row, not just the HELPFUL whitelists -- the
            --     same widening (1) needed. A unit the engine will not resolve loses the
            --     whole candidateFilters payload, so the debuff row's excludeSpellIDs
            --     blacklist and the "already claimed above" booleans go with it.
            if self._gateVulnerable or self._gateCFDependent then
                local ok, can = pcall(UnitCanAssist, "player", unit)
                if ok then
                    if issecretvalue(can) then can = true end
                    -- ⚠ OR, never plain assignment: the offline check above may already
                    -- have set it, and an assignment here would wipe that recovery edge
                    -- (reconnect while assist never moved = no bounce = row stays stale).
                    if self:_NoteGateRecovery(can) then recovered = true end
                    if not can and (not isOwn or GATE_FAIL_CLOSED) then hide = true end
                end
            end

            -- (2b) CROSS-FACTION IN THE OPEN WORLD -- a Horde player with an Alliance
            --      party member. (2) is meant to cover it (assist is documented to go false
            --      for a cross-faction member outside instanced content) but it only fires
            --      if UnitCanAssist actually says false, and a group member you are allowed
            --      to heal answers true. The faction mismatch itself is a definite,
            --      never-secret answer, so it stands as its own signal.
            --      ⚠ INSTANCED CONTENT IS EXEMPT. Cross-faction dungeon/raid groups are a
            --      supported feature; blanking every curated row for a whole cross-faction
            --      key would be a worse bug than the one being fixed. Open world only.
            --      Neutral (an undecided pandaren) is not a mismatch -- it is "no answer".
            if (self._gateVulnerable or self._gateCFDependent) and not isOwn then
                local same -- nil = no answer (instanced, neutral, secret, no faction yet)
                local okF, mine = pcall(UnitFactionGroup, "player")
                local okU, theirs = pcall(UnitFactionGroup, unit)
                if okF and okU and not IsInInstance()
                    and not issecretvalue(mine) and not issecretvalue(theirs)
                    and type(mine) == "string" and type(theirs) == "string"
                    and mine ~= "Neutral" and theirs ~= "Neutral" then
                    same = mine == theirs
                end
                local was = self._gateFaction
                self._gateFaction = same
                -- ⚠ the recovery edge is "stopped being a mismatch", which includes
                -- BECOMING UNANSWERABLE: zoning into a dungeon takes this whole branch
                -- away, and the container is still holding the open-world fail-open parse.
                -- Nothing else bounces it -- entering an instance is not an aura change.
                if was == false and same ~= false then recovered = true end
                if same == false then hide = true end
            end

            -- (3) not in your visible world -- a different shard/phase, or simply too far
            --     away (an LFG member idling in another city shard is the everyday case):
            --     the engine cannot attribute a caster, so "mine" passes everyone's auras.
            --     Signal: UnitIsVisible. Same fail-safe -- only a definite, non-secret
            --     false hides. Probed even when (1)/(2) already hid us, so the recovery
            --     edge is recorded: this pool goes stale-open exactly like the assist one,
            --     and coming back into view is not an aura change either.
            --     ⚠ Scope is every cf-DEPENDENT row too, the same widening (1) and (2)
            --     needed: a unit the engine will not resolve loses the whole
            --     candidateFilters payload. Field fingerprint (out-of-shard party member,
            --     connected and assistable): the SAME debuff drawn twice in the central row
            --     (boss/role and priority both degrade to bare HARMFUL), again in the
            --     debuff row (the "already claimed above" booleans are gone), and the buff
            --     whitelists fill with everything.
            if self._gateSourceRelative or self._gateVulnerable or self._gateCFDependent then
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
    -- Same disposal as a rebuild: park it if it is still worth something, orphan it if not.
    -- An indicator that gets deleted and re-added (or a preview button) hands its container
    -- straight back to the next one asking for that key.
    ParkOrDiscard(self)
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
-- roster and member-data settling, zoning, target/focus swaps -- and vehicle transitions,
-- which get their own handling further down. Event bursts coalesce onto
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
        "UNIT_CONNECTION", -- the drop/reconnect edge; nothing else fires at that moment
        "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "CINEMATIC_START", "CINEMATIC_STOP", "PLAY_MOVIE", "STOP_MOVIE",
        "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UNIT_PET",
    }) do
        watcher:RegisterEvent(e)
    end

    local queued
    local function Sweep()
        queued = nil
        for h in pairs(AD._instances or {}) do
            if not h._destroyed and (h._gateVulnerable or h._gateSourceRelative or h._gateCFDependent) then
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

    -- ── VEHICLE TRANSITIONS ───────────────────────────────────
    -- Boarding or leaving a vehicle re-parses the pools while the unit is mid-transition,
    -- when the assist check cannot be answered -- the same fail-open a cinematic causes,
    -- announced by events nothing in the list above was listening to. It sticks HARDER
    -- than the cinematic one: the engine re-parses on an aura CHANGE, and a taxi or
    -- mount-style vehicle ride has no aura churn at all, so the unfiltered pool survives
    -- the entire ride. That is the "I got on the boat and the whitelist row filled up with
    -- everything" report -- /cab gate clears it, which is exactly what the settle pass
    -- below now does by itself.
    --
    -- Both halves are needed:
    --   1. probe + latch on the way IN, so the fail-open parse is never SEEN, and so the
    --      assist false -> true EDGE ends up on record. Without a probe DURING the
    --      transition there is no edge later, and ApplyIdentityGate never bounces.
    --   2. a FORCED bounce once it settles. If assist never actually dropped, (1) records
    --      nothing at all and only an unconditional re-parse can clear the stale pool.
    --      This half also covers the button whose unit was swapped to the vehicle token,
    --      which (1) cannot match against the event's unit.
    -- ⚠ Latch OUT OF COMBAT only: in combat GateRefresh can only mark dirty, so a latched
    -- row would stay blank until regen -- and in combat the aura churn re-parses it anyway.
    -- UNIT_PET is watched because THAT, not UNIT_ENTERED_VEHICLE, is when the vehicle
    -- actually lands; the enter event fires at the start of the transition, before data.
    local vehQueued
    local function VehicleSettle(final)
        if final then vehQueued = nil end
        for h in pairs(AD._instances or {}) do
            if not h._destroyed and h.container
                and (h._gateVulnerable or h._gateSourceRelative or h._gateCFDependent) then
                -- un-latch BEFORE the bounce: Show() on a hidden parent chain never fires
                -- OnShow, and OnShow IS the re-parse (same trap as ApplyIdentityGate)
                if h._cineLatched then SetLatch(h, nil) end
                pcall(function() h:ApplyIdentityGate() end)
                h:GateRefresh()
            end
        end
    end

    local function VehicleTransition(event, unit)
        local okA, canA = pcall(UnitCanAssist, "player", unit)
        AD._gateVehicleLog = ("%s unit=%s assist=%s t=%.1f"):format(
            tostring(event), tostring(unit),
            okA and (issecretvalue(canA) and "secret" or tostring(canA)) or "err",
            GetTime())

        local latch = not InCombatLockdown()
        for h in pairs(AD._instances or {}) do
            -- SameUnit nil (unknown -- a boss/arena row against a group token) is falsy
            -- and skips: latching a row that has nothing to do with this transition would
            -- blank it for a second, and the forced settle bounce below covers it anyway.
            if not h._destroyed and h._gateVulnerable and SameUnit(h.unit, unit) then
                pcall(function() h:ApplyIdentityGate() end)
                if latch then SetLatch(h, true) end
            end
        end

        -- one pair of passes per burst (a raid boarding together is still one burst):
        -- 1s covers the normal case, 3s the slow landing.
        if not vehQueued then
            vehQueued = true
            C_Timer.After(1, function() VehicleSettle(false) end)
            C_Timer.After(3, function() VehicleSettle(true) end)
        end
    end

    watcher:SetScript("OnEvent", function(_, event, unit)
        if event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
            LatchAll()
            return
        end

        if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE"
            or event == "UNIT_PET" then
            -- UNIT_PET fires for every pet summon in the group; only a landing matters
            if event == "UNIT_PET" then
                local okV, inv = pcall(UnitInVehicle, unit)
                if not okV or issecretvalue(inv) or inv ~= true then return end
            end
            VehicleTransition(event, unit)
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
        for k, v in pairs(cf) do
            -- set-valued candidateFilters (includeDispelTypes, include/excludeSpellIDs) would
            -- otherwise print as "table: 0x..." and tell the tester nothing
            if type(v) == "table" then
                local inner = {}
                for ik in pairs(v) do inner[#inner + 1] = tostring(ik) end
                table.sort(inner)
                v = "{" .. table.concat(inner, ",") .. "}"
            end
            keys[#keys + 1] = k .. "=" .. tostring(v)
        end
        cfDesc = " cf{" .. table.concat(keys, ",") .. "}"
    end
    print("|cff33ff99[Cell 光環]|r central containers -> " .. (filter and (filter .. cfDesc) or "(restored to normal records)") .. " (" .. n .. " rebuilt; OOC only)")
end

-- The player's own dispel schools, i.e. the candidateFilter spelling of what the
-- RAID_PLAYER_DISPELLABLE token says. Computed at press time because it follows the spec.
local function MyDispelTypes()
    local I = Cell.iFuncs
    if not (I and I.CanDispel) then return nil end
    local t = {}
    for dispelType in pairs(ALL_DISPEL_TYPES) do
        if I.CanDispel(dispelType) then t[dispelType] = true end
    end
    if not next(t) then return nil end -- nothing dispellable on this spec
    return t
end

-- One-button stepper: /cab test
-- Each press advances to the next bisect case and prints what to look for.
--
-- ⚠ Steps 3 and 6 are a PAIR, and they only answer their question IN COMBAT. NeeRgY's fork
-- claims RAID_PLAYER_DISPELLABLE stops matching once you are in combat and moved every
-- "dispellable by me" row onto includeDispelTypes because of it; we still ship the token in
-- three places (debuff mode, dispel mode, the important row's dispel record). AD.Test cannot
-- switch filters in combat (Rebuild is OOC-only), so the probe is: set step 3, pull, watch --
-- then set step 6, pull again. Same debuffs, one filter each. Whichever survives combat wins.
local TEST_STEPS = {
    { f = "HARMFUL", minimal = true,                desc = "第1步 最小渲染(只綁icon):任何減益都該亮" },
    { f = "HARMFUL",                                desc = "第2步 完整樣式:第1亮這步不亮=樣式綁定壞" },
    { f = "HARMFUL|RAID_PLAYER_DISPELLABLE",        desc = "第3步 可驅散token:可驅散減益該亮。設好後開打,看戰鬥中會不會整排消失(跟第6步對照)" },
    { f = "HARMFUL", cf = { isBossOrRoleAura = false },
                                                    desc = "第4步 布林false旗標:跟第2步同,不亮=布林false壞" },
    { f = "HARMFUL|RAID_PLAYER_DISPELLABLE|!RAID",  desc = "第5步 !RAID抵銷:第3步亮這步不亮=RAID抵銷確認" },
    { f = "HARMFUL", cfFn = MyDispelTypes, cfKey = "includeDispelTypes",
                                                    desc = "第6步 驅散學派cf(第3步的對照組):同樣開打,第3步戰鬥中掉、這步還在=token在戰鬥中失效" },
    { f = nil,                                      desc = "已恢復正常5組filter(再按一次回到第1步)" },
}
local testStep = 0
local function StepTest()
    testStep = testStep % #TEST_STEPS + 1
    local s = TEST_STEPS[testStep]
    local cf = s.cf
    if s.cfFn then
        local v = s.cfFn()
        -- ⚠ never fall through to a bare HARMFUL: that shows EVERY debuff and reads as
        -- "the candidateFilter works", which is the exact opposite of what happened.
        if not v then
            print("|cffff5555[Cell 光環 測試]|r 這個專精沒有可驅散學派,第" .. testStep .. "步跳過(不改動容器)")
            return
        end
        cf = { [s.cfKey] = v }
    end
    AD.Test(s.f, cf, s.minimal)
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
    -- assist=false here is the whole answer to "why did my whitelist row fill up after I
    -- got on that boat"; assist=true means the fail-open came from somewhere else
    if AD._gateVehicleLog then p("最近一次載具轉場：" .. AD._gateVehicleLog) end
    local n = 0
    for h in pairs(AD._instances or {}) do
        if h.unit == unitToken then
            n = n + 1
            local cfg = h.config or {}
            local ids = cfg.spellIDs
            local idCount = 0
            if type(ids) == "table" then for _ in pairs(ids) do idCount = idCount + 1 end end

            p(("--- handle #%d mode=%s%s shown=%s built=%s buttons=%d")
                :format(n, tostring(cfg.mode or "important"),
                    cfg.customStyle and ("/" .. cfg.customStyle .. (IsSlotMode(cfg) and " slot" or "")) or "",
                    tostring(h.frame:IsShown()),
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
            if h._gateVulnerable or h._gateSourceRelative or h._gateCFDependent then
                p(("    身分閘：白名單依賴=%s 來源依賴=%s cf依賴=%s assist=%s visible=%s connected=%s 同陣營=%s 隱藏=%s 失效方向=%s")
                    :format(tostring(h._gateVulnerable or false), tostring(h._gateSourceRelative or false),
                        tostring(h._gateCFDependent or false),
                        tostring(h._gateAssist), tostring(h._gateVisible), tostring(h._gateConnected),
                        tostring(h._gateFaction),
                        tostring(h._gateHidden or false),
                        GATE_FAIL_CLOSED and "隱藏(fail-closed)" or "顯示(fail-open)"))
            end
            -- flow-layout ground truth: what orientation asked for, what the container
            -- ACTUALLY resolved to, and whether each setter took (see ACC.ApplyFlowLayout).
            -- If Get* disagrees with the orientation, the setters are not applying; if they
            -- agree yet growth still looks wrong, it is the container pin / SetSize instead.
            if h.container and h.container.GetFlowLayoutAnchorPoint and not IsSlotMode(cfg) then
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
            if not h._destroyed and h.container
                and (h._gateVulnerable or h._gateSourceRelative or h._gateCFDependent) then
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
    elseif cmd == "stats" then
        -- The measurement behind the roster-stutter fix. Zero it, make people join/leave the
        -- group, read it again: `repoints` should climb and `builds`/`discards` should not.
        -- Every discard is a container orphaned until /reload, so a discard count that tracks
        -- roster churn means something is still rebuilding when it should be re-pointing.
        if arg and strtrim(arg):lower() == "reset" then
            AD.stats.builds, AD.stats.discards, AD.stats.repoints = 0, 0, 0
            AD.stats.parks, AD.stats.reuses = 0, 0
            p("計數歸零")
            return
        end
        local live = 0
        for h in pairs(AD._instances or {}) do
            if h.container then live = live + 1 end
        end
        local parked, parkKeys = AD.ParkStats()
        p(("容器建立 %d ／ 丟棄 %d（= 洩漏，只有 /reload 收得回）／ 換單位重指 %d ／ 目前存活 %d")
            :format(AD.stats.builds, AD.stats.discards, AD.stats.repoints, live))
        p(("寄存 %d ／ 取回 %d ／ 目前寄存中 %d（%d 種簽章）%s")
            :format(AD.stats.parks, AD.stats.reuses, parked, parkKeys,
                AD.PARK_ENABLED and "" or " ｜寄存已關閉"))
        p("進出隊伍時 repoints 該漲、builds/discards 不該漲。歸零：/cab stats reset")
        p("換版面（副本↔團隊↔野外）來回一次：第二次該是 reuses 漲、builds 不漲。")

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
        p("其他：/cab list | stats | ghosts | inspect [unit] | overdraw [unit] | spell <id> | gate | test")
    end
end

return AD
