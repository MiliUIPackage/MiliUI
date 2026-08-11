local _, BR = ...

-- The external defensives and buffs shown by Display/AuraTracker.lua, plus the two
-- accessors every consumer of that feature needs. Loads before Display and Options,
-- so both can alias the accessors at file scope.
--
-- Every entry is a HELPFUL aura on the player, which is the only shape Blizzard
-- permits spell-ID filtering for - "spell ID matching is only permitted for helpful
-- buffs on assistable units". A harmful aura on yourself can never be tracked, so
-- this list is buffs-you-receive by construction. See docs/SecretValues.md #3.9.
--
-- `section` buckets an entry under a heading in the options list; `labelKey` is only
-- needed when one entry spans spells with different names, since single-name entries
-- take their label from the spell itself and localize for free.

---Display groupings, in the order the options page renders them.
BR.EXTERNAL_SECTIONS = {
    { key = "defensives", titleKey = "Externals.Defensives" },
    { key = "groupBuffs", titleKey = "Externals.GroupBuffs" },
    { key = "augmentation", titleKey = "Externals.Augmentation" },
}

BR.EXTERNALS = {
    { key = "blessingOfSacrifice", section = "defensives", spellIDs = { 6940 } },
    { key = "blessingOfProtection", section = "defensives", spellIDs = { 1022 } },
    { key = "painSuppression", section = "defensives", spellIDs = { 33206 } },
    { key = "guardianSpirit", section = "defensives", spellIDs = { 47788 } },
    { key = "ironbark", section = "defensives", spellIDs = { 102342 } },
    { key = "lifeCocoon", section = "defensives", spellIDs = { 116849 } },
    { key = "timeDilation", section = "defensives", spellIDs = { 357170 } },

    {
        key = "bloodlust",
        section = "groupBuffs",
        labelKey = "Externals.Bloodlust",
        spellIDs = {
            2825, -- Bloodlust
            32182, -- Heroism
            80353, -- Time Warp
            90355, -- Ancient Hysteria
            264667, -- Primal Rage
            390386, -- Fury of the Aspects
        },
    },
    { key = "powerInfusion", section = "groupBuffs", spellIDs = { 10060 } },
    { key = "innervate", section = "groupBuffs", spellIDs = { 29166 } },
    { key = "rallyingCry", section = "groupBuffs", spellIDs = { 97463 } },

    -- De-whitelisted in 12.1 (#3.7), so the reminder pipeline can no longer see
    -- these in combat - a container still can.
    { key = "ebonMight", section = "augmentation", spellIDs = { 395152, 395296 } },
    { key = "prescience", section = "augmentation", spellIDs = { 410089 } },
    { key = "blisteringScales", section = "augmentation", spellIDs = { 360827 } },
}

---The live externals settings table. Single accessor for every consumer, so the
---pre-seeding fallback can never diverge between the engine and the options pages.
---@return table
function BR.GetExternalSettings()
    return BR.profile and BR.profile.externals or BR.defaults.externals
end

---@return boolean
function BR.AreExternalsEnabled()
    return BR.GetExternalSettings().enabled == true
end

---Display label for an entry: explicit key when it spans differently-named spells,
---otherwise the spell's own (already localized) name.
---@param entry table
---@return string
function BR.GetExternalLabel(entry)
    if entry.labelKey then
        return BR.L[entry.labelKey] or entry.key
    end
    return BR.GetSpellName(entry.spellIDs[1]) or tostring(entry.spellIDs[1])
end
