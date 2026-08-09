local _, BR = ...

-- ============================================================================
-- TARGET MEMORY
-- ============================================================================
-- Remembers who the player's cast-on-others buffs are on (buffKey -> name/class)
-- so click macros can re-target the same person and tooltips can show them.
-- Runtime-only (not saved): the aura itself is the source of truth and the
-- memory is rebuilt from a live scan whenever the aura API allows querying.
--
-- Three detection paths feed into this module (all in State.lua's refresh):
--
-- 1. casterBuffId buffs (Symbiotic Relationship, Weyrnstone) - the caster-side
--    aura confirms the link is active, then a group scan finds the recipient.
-- 2. Targeted buffs (Earth Shield, Blistering Scales, ...) - the group scan
--    for the player's own cast doubles as target detection.
-- 3. Presence castOnOthers buffs (Soulstone) - the presence scan filtered to
--    player-cast auras finds the stoned group member.
--
-- All three apply the same tri-state rule via Observe():
-- - buff active on another group member -> remember them
-- - buff active but not on others (e.g. only on the player) -> forget
-- - buff not active at all -> keep the old memory, so the click macro can
--   re-target the same person after the buff falls off

-- Runtime store: buffKey -> { name, class }. Entries are mutated in place to
-- avoid per-refresh allocations.
---@type table<string, {name: string, class: string?}>
local memory = {}

---Apply one observation of a buff's state to the memory (see tri-state rule above).
---@param buffKey string
---@param isActive boolean? Whether the buff is currently active anywhere
---@param name string? Character name (with realm) of the non-player target carrying it
---@param class string? English class token of the target (e.g. "PALADIN")
local function Observe(buffKey, isActive, name, class)
    if not isActive then
        return -- keep old memory while the buff is missing
    end
    if name then
        local existing = memory[buffKey]
        if existing then
            existing.name = name
            existing.class = class
        else
            memory[buffKey] = { name = name, class = class }
        end
    else
        memory[buffKey] = nil
    end
end

---Get the remembered target for a buff.
---@param buffKey string
---@return string? name Character name (with realm) of the last known target
---@return string? class English class token (e.g. "PALADIN")
local function Get(buffKey)
    local entry = memory[buffKey]
    if entry then
        return entry.name, entry.class
    end
    return nil, nil
end

---Forget targets that are no longer in the group.
---@param activeNames table<string, true> Set of names currently in the group
local function PruneToRoster(activeNames)
    for buffKey, entry in pairs(memory) do
        if not activeNames[entry.name] then
            memory[buffKey] = nil
        end
    end
end

-- ============================================================================
-- EXPORT
-- ============================================================================

BR.TargetMemory = {
    Observe = Observe,
    Get = Get,
    PruneToRoster = PruneToRoster,
}
