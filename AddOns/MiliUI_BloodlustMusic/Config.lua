local addonName, ns = ...

----------------------------------------------------------------------
-- Localization (shared across all files)
----------------------------------------------------------------------
ns.L = LibStub("AceLocale-3.0"):GetLocale("MiliUI_BloodlustMusic")

----------------------------------------------------------------------
-- Lust spell ID lists
----------------------------------------------------------------------

-- BUFF IDs: the actual haste effect (~40s duration)
ns.LUST_BUFFS = {
    2825,    -- Bloodlust            (Shaman)
    32182,   -- Heroism              (Shaman)
    80353,   -- Time Warp            (Mage)
    264667,  -- Primal Rage          (Hunter pet)
    390386,  -- Fury of the Aspects  (Evoker)
    466904,  -- Harrier's Cry        (Hunter - Marksmanship)
    -- Drums (Leatherworking consumables, 15% haste)
    1243972, -- Void Touched Drums        (MidNight)
    444257,  -- Thunderous Drums          (TWW)
    381301,  -- Feral Hide Drums          (Dragonflight)
    309658,  -- Drums of Deathly Ferocity (Shadowlands)
    292686,  -- Mallet of Thunderous Skins(BfA)
}

-- DEBUFF IDs: exhaustion lockout (~10 min)
ns.LUST_DEBUFFS = {
    57723,   -- Exhaustion             (Heroism / Drums)
    57724,   -- Sated                  (Bloodlust)
    80354,   -- Temporal Displacement  (Time Warp)
    95809,   -- Insanity               (Hunter pet / Ancient Hysteria)
    390435,  -- Exhaustion             (Fury of the Aspects – Evoker)
    264689,  -- Fatigued               (Primal Rage / Drums)
}

-- Class → lust-caster mapping (used by Reminder to resolve player spell)
ns.LUST_CLASS_SPELLS = {
    { classID = "SHAMAN", spellID = 2825,   altSpellID = 32182 },  -- Bloodlust / Heroism
    { classID = "MAGE",   spellID = 80353  },                       -- Time Warp
    { classID = "EVOKER", spellID = 390386 },                       -- Fury of the Aspects
    { classID = "HUNTER", spellID = 264667, altSpellID = 466904 },  -- Primal Rage / Harrier's Cry
}

-- Debuff lasts 600s; remaining > this means the cast is recent enough to
-- still be inside the 40s buff window (login/reload-safe replay suppression).
ns.LUST_DEBUFF_FRESH_THRESHOLD = 540

----------------------------------------------------------------------
-- Music configuration
----------------------------------------------------------------------
ns.MUSIC_FILES = {
    { name = "Power of the Horde", path = "Interface\\AddOns\\MiliUI_BloodlustMusic\\Media\\power_of_the_horde.mp3" },
}
ns.MUSIC_DURATION     = 40
ns.MUSIC_MEDIA_PREFIX = "Interface\\AddOns\\MiliUI_BloodlustMusic\\Media\\"
ns.DEFAULT_CHANNEL    = "SFX"
ns.CHANNELS           = { "Master", "SFX", "Dialog" }

-- Sound engine boost values applied while lust music plays
ns.BOOST_NUM_CHANNELS = 128
ns.BOOST_CACHE_SIZE   = 134217728  -- 128 MB

----------------------------------------------------------------------
-- SavedVariables defaults
----------------------------------------------------------------------
ns.DB_DEFAULTS = {
    musicEnabled          = true,
    barEnabled            = true,
    playMode              = "random",   -- "random" | "sequential"
    channel               = ns.DEFAULT_CHANNEL,
    trackEnabled          = {},         -- [index] = true/false per built-in track
    customTracks          = {},         -- array of { name, filename, enabled }
    lastTrackIndex        = 0,
    barWidth              = 185,
    barHeight             = 10,
    barX                  = 0,
    barY                  = 300,
    reminderEnabled       = true,
    reminderSoundEnabled  = true,
    reminderSound         = 8457,
    reminderLustClassOnly = true,
    reminderDungeonPull   = true,
    reminderDebuffExpiry  = true,
    reminderDuration      = 5,
    reminderX             = 0,
    reminderY             = 360,
}

----------------------------------------------------------------------
-- Locale-aware font (used by both Music bar and Reminder text)
----------------------------------------------------------------------
if LOCALE_koKR then
    ns.LOCALE_FONT = "Fonts\\2002.TTF"
elseif LOCALE_zhCN then
    ns.LOCALE_FONT = "Fonts\\ARKai_T.ttf"
elseif LOCALE_zhTW then
    ns.LOCALE_FONT = "Fonts\\blei00d.TTF"
else
    ns.LOCALE_FONT = "Fonts\\FRIZQT__.TTF"
end

----------------------------------------------------------------------
-- Bar texture resolution: SharedMedia → DBM → fallback
----------------------------------------------------------------------
function ns.GetBarTexture()
    if C_AddOns.IsAddOnLoaded("SharedMedia") then
        return "Interface\\AddOns\\SharedMedia\\statusbar\\normTex"
    elseif C_AddOns.IsAddOnLoaded("DBM-StatusBarTimers") then
        return "Interface\\AddOns\\DBM-StatusBarTimers\\textures\\default.blp"
    end
    return "Interface\\Buttons\\WHITE8X8"
end

----------------------------------------------------------------------
-- Faction-based default lust name + icon (Alliance→Heroism, else Bloodlust)
----------------------------------------------------------------------
do
    local faction = UnitFactionGroup("player")
    if faction == "Alliance" then
        ns.DEFAULT_LUST_NAME = C_Spell.GetSpellName(32182) or "Heroism"
        ns.DEFAULT_LUST_ICON = "Interface\\Icons\\Ability_Shaman_Heroism"
    else
        ns.DEFAULT_LUST_NAME = C_Spell.GetSpellName(2825) or "Bloodlust"
        ns.DEFAULT_LUST_ICON = "Interface\\Icons\\Spell_Nature_Bloodlust"
    end
end
