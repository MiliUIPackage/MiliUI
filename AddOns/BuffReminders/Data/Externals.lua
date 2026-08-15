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
-- take their label from the spell itself and localize for free. `labelSpellID` names
-- an entry after the ability that grants the aura, for auras whose own name misleads
-- (228050 resolves to "Divine Shield"); it localizes for free like the default.

---Display groupings, in the order the options page renders them.
BR.EXTERNAL_SECTIONS = {
    { key = "defensives", titleKey = "Externals.Defensives" },
    { key = "groupBuffs", titleKey = "Externals.GroupBuffs" },
    { key = "movement", titleKey = "Externals.Movement" },
    { key = "aggro", titleKey = "Externals.Aggro" },
    { key = "augmentation", titleKey = "Externals.Augmentation" },
}

-- Within a section, entries are ordered by the class that provides the buff
-- (classes alphabetical, then buff name). Multi-class Bloodlust sorts as Shaman.
BR.EXTERNALS = {
    { key = "antiMagicZone", section = "defensives", spellIDs = { 145629 } }, -- Death Knight
    { key = "darkness", section = "defensives", spellIDs = { 209426 } }, -- Demon Hunter
    { key = "ironbark", section = "defensives", spellIDs = { 102342 } }, -- Druid
    { key = "timeDilation", section = "defensives", spellIDs = { 357170 } }, -- Evoker
    { key = "zephyr", section = "defensives", spellIDs = { 374227 } }, -- Evoker
    {
        key = "massBarrier", -- Mage
        section = "defensives",
        labelKey = "Externals.MassBarrier",
        spellIDs = {
            414661, -- Ice Barrier
            414662, -- Blazing Barrier
            414663, -- Prismatic Barrier
        },
    },
    { key = "lifeCocoon", section = "defensives", spellIDs = { 116849 } }, -- Monk
    { key = "auraMastery", section = "defensives", spellIDs = { 31821 } }, -- Paladin
    { key = "blessingOfProtection", section = "defensives", spellIDs = { 1022 } }, -- Paladin
    { key = "blessingOfSacrifice", section = "defensives", spellIDs = { 6940 } }, -- Paladin
    { key = "blessingOfSpellwarding", section = "defensives", spellIDs = { 204018 } }, -- Paladin
    { key = "forgottenQueen", section = "defensives", spellIDs = { 228050 }, labelSpellID = 228049 }, -- Paladin
    { key = "guardianSpirit", section = "defensives", spellIDs = { 47788 } }, -- Priest
    { key = "luminousBarrier", section = "defensives", spellIDs = { 271466 } }, -- Priest
    { key = "painSuppression", section = "defensives", spellIDs = { 33206 } }, -- Priest
    { key = "powerWordBarrier", section = "defensives", spellIDs = { 81782 } }, -- Priest
    { key = "ancestralProtection", section = "defensives", spellIDs = { 207498 } }, -- Shaman
    { key = "earthenWall", section = "defensives", spellIDs = { 201633 } }, -- Shaman
    { key = "intervene", section = "defensives", spellIDs = { 147833 } }, -- Warrior

    { key = "innervate", section = "groupBuffs", spellIDs = { 29166 } }, -- Druid
    { key = "spatialParadox", section = "groupBuffs", spellIDs = { 406789 } }, -- Evoker
    {
        key = "blessingOfSeasons", -- Paladin
        section = "groupBuffs",
        labelKey = "Externals.BlessingOfSeasons",
        spellIDs = {
            388007, -- Blessing of Summer
            388010, -- Blessing of Autumn
            388011, -- Blessing of Winter
            388013, -- Blessing of Spring
        },
    },
    { key = "powerInfusion", section = "groupBuffs", spellIDs = { 10060 } }, -- Priest
    {
        key = "bloodlust", -- Shaman + the cross-class variants
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
    { key = "rallyingCry", section = "groupBuffs", spellIDs = { 97463 } }, -- Warrior

    { key = "stampedingRoar", section = "movement", spellIDs = { 106898, 77761, 77764 } }, -- Druid
    {
        key = "timeSpiral", -- Evoker
        section = "movement",
        spellIDs = {
            375234, -- Time Spiral itself; the rest are its per-class movement buffs
            375226,
            375229,
            375230,
            375238,
            375240,
            375252,
            375253,
            375254,
            375255,
            375256,
            375257,
            375258,
        },
    },
    { key = "tigersLust", section = "movement", spellIDs = { 116841 } }, -- Monk
    { key = "blessingOfFreedom", section = "movement", spellIDs = { 1044 } }, -- Paladin
    { key = "windRushTotem", section = "movement", spellIDs = { 192082 } }, -- Shaman

    { key = "misdirection", section = "aggro", spellIDs = { 34477 } }, -- Hunter
    { key = "tricksOfTheTrade", section = "aggro", spellIDs = { 57934 } }, -- Rogue

    -- De-whitelisted in 12.1 (#3.7), so the reminder pipeline can no longer see
    -- these in combat - a container still can.
    { key = "blisteringScales", section = "augmentation", spellIDs = { 360827 } }, -- Evoker
    { key = "ebonMight", section = "augmentation", spellIDs = { 395152, 395296 } }, -- Evoker
    { key = "prescience", section = "augmentation", spellIDs = { 410089 } }, -- Evoker
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

local floor = math.floor

-- Appearance keys that follow the global `defaults` table while
-- externals.useCustomAppearance is off. durationSize and growDirection are
-- absent on purpose: `defaults` has no countdown text, and its growDirection
-- values (CENTER/UP/DOWN) do not exist in the flow layout.
local INHERITED_KEYS = {
    iconSize = true,
    iconWidth = true,
    iconZoom = true,
    borderSize = true,
    iconAlpha = true,
    spacing = true,
}

---Effective value for one externals setting, with inheritance from the global
---defaults - the externals counterpart of BR.Config.GetCategorySetting.
---@param key string
---@return any
function BR.GetExternalSetting(key)
    local settings = BR.GetExternalSettings()
    if not INHERITED_KEYS[key] or settings.useCustomAppearance then
        return settings[key]
    end
    local defaults = BR.profile and BR.profile.defaults or BR.defaults.defaults
    if key == "spacing" then
        -- defaults.spacing is a size multiplier; the flow layout wants absolute px.
        -- Same math as the reminder rows' horizontal gap: floor(mainAxisWidth * spacing).
        local width = defaults.iconWidth or defaults.iconSize or 64
        return floor((defaults.spacing or 0) * width)
    end
    return defaults[key]
end

---Display label for an entry: explicit key when it spans differently-named spells,
---otherwise the (already localized) name of labelSpellID or the spell itself.
---@param entry table
---@return string
function BR.GetExternalLabel(entry)
    if entry.labelKey then
        return BR.L[entry.labelKey] or entry.key
    end
    local spellID = entry.labelSpellID or entry.spellIDs[1]
    return BR.GetSpellName(spellID) or tostring(spellID)
end
