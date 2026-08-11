local _, BR = ...

-- Blizzard whitelists specific spell IDs for C_UnitAuras.GetUnitAuraBySpellID() during
-- restricted contexts: combat lockdown, boss encounters, and M+ keystones.
-- Non-whitelisted spells silently return nil, indistinguishable from "buff missing."
-- This is the single source of truth: any spell ID NOT here is assumed unsafe to query.
--
-- IMPORTANT: Boss encounters (ENCOUNTER_START) restrict the aura API BEFORE the player
-- enters combat (InCombatLockdown). A spell that returns nil during an encounter but
-- before combat will cause a brief false "buff missing" flash if not handled correctly.
-- State.lua uses inCombat (set by Display, covers encounters too) + M+ difficulty to gate queries.
--
-- Source: Blizzard's restricted-context aura whitelist (confirmed via in-game testing).
BR.AURA_WHITELIST = {
    -- ========================================================================
    -- LONG-TERM RAID BUFFS
    -- ========================================================================
    [1126] = true, -- Mark of the Wild
    [1459] = true, -- Arcane Intellect
    [6673] = true, -- Battle Shout
    [21562] = true, -- Power Word: Fortitude
    [369459] = true, -- Source of Magic
    [462854] = true, -- Skyfury
    [474754] = true, -- Symbiotic Relationship

    -- Blessing of the Bronze (per-class aura variants)
    [381732] = true, -- Death Knight
    [381741] = true, -- Demon Hunter
    [381746] = true, -- Druid
    [381748] = true, -- Evoker
    [381749] = true, -- Hunter
    [381750] = true, -- Mage
    [381751] = true, -- Monk
    [381752] = true, -- Paladin
    [381753] = true, -- Priest
    [381754] = true, -- Rogue
    [381756] = true, -- Shaman
    [381757] = true, -- Warlock
    [381758] = true, -- Warrior

    -- ========================================================================
    -- LONG-TERM SELF BUFFS
    -- ========================================================================
    -- Note: Rite spell IDs (433568, 433583) are whitelisted by Blizzard, but the addon checks
    -- buffIdOverride (433550, 433584) which are NOT whitelisted - so Rites are correctly
    -- blocked in restricted contexts via IsAuraTrackable regardless.
    [433568] = true, -- Rite of Sanctification
    [433583] = true, -- Rite of Adjuration

    -- Rogue Poisons
    [2823] = true, -- Deadly Poison
    [3408] = true, -- Crippling Poison
    [5761] = true, -- Numbing Poison
    [8679] = true, -- Wound Poison
    [315584] = true, -- Instant Poison
    [381637] = true, -- Atrophic Poison
    [381664] = true, -- Amplifying Poison

    -- Shaman Imbuements
    [319773] = true, -- Windfury Weapon
    [319778] = true, -- Flametongue Weapon
    [382021] = true, -- Earthliving Weapon
    [382022] = true, -- Earthliving Weapon
    [457481] = true, -- Tidecaller's Guard
    [457496] = true, -- Tidecaller's Guard
    [462742] = true, -- Thunderstrike Ward
    [462757] = true, -- Thunderstrike Ward
}
