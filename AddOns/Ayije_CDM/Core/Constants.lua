local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local _locale = GetLocale()
local _isCJK = (_locale == "zhTW" or _locale == "zhCN" or _locale == "koKR")

CDM.CONST = {
    FONT_PATH = _isCJK and STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
    FONT_OUTLINE = "OUTLINE",

    SHADOW_OFFSET = {
        x = 1,
        y = -1,
    },

    SHADOW_COLOR = {
        r = 0,
        g = 0,
        b = 0,
        a = 1,
    },

    WHITE = {
        r = 1,
        g = 1,
        b = 1,
        a = 1,
    },

    GOLD = {
        r = 1,
        g = 0.82,
        b = 0,
        a = 1,
    },

    SWIPE_COLOR = {
        r = 0,
        g = 0,
        b = 0,
        a = 0.6,
    },

    TEX_WHITE8X8 = "Interface\\Buttons\\WHITE8X8",

    STRATA_MAIN = "MEDIUM",
    STRATA_OVERLAY = "HIGH",

    ICON_TEXCOORD_MIN = 0.08,
    ICON_TEXCOORD_MAX = 0.92,

    VIEWERS = {
        ESSENTIAL = "EssentialCooldownViewer",
        UTILITY = "UtilityCooldownViewer",
        BUFF = "BuffIconCooldownViewer",
        BUFF_BAR = "BuffBarCooldownViewer",
    },

    SOUL_CLEAVE_SPELL_ID = 228477,
    MAELSTROM_WEAPON_SPELL_ID = 344179,
    DEVOURER_VOID_METAMORPHOSIS_SPELL_ID = 1217607,
    DEVOURER_RESOURCE_AURA_SPELL_ID = 1225789,
    DEVOURER_COLLAPSING_STAR_SPELL_ID = 1227702,
    DEVOURER_SOUL_GLUTTON_TALENT_SPELL_ID = 1247534,
    FERAL_OVERFLOWING_POWER_SPELL_ID = 405189,
    TIP_OF_THE_SPEAR_SPELL_ID = 260286,
    GCD_SPELL_ID = 61304,
}

local VIEWERS = CDM.CONST.VIEWERS
CDM.CONST.COOLDOWN_VIEWER_NAMES = { VIEWERS.ESSENTIAL, VIEWERS.UTILITY }

CDM.CONST.VIEWERS_WITH_OVERRIDE = {
    [VIEWERS.ESSENTIAL] = true,
    [VIEWERS.UTILITY] = true,
}


CDM.CONST.DOT_OVERRIDE_SPELLS = {
    -- Druid
    [8921]   = true, -- Moonfire                  -- Balance
    [155625] = true, -- Moonfire                  -- Feral
    [33763]  = true, -- Lifebloom                 -- Restoration
    [93402]  = true, -- Sunfire
    [1822]   = true, -- Rake
    [1079]   = true, -- Rip
    [155722] = true, -- Rake (Stealthed)          -- Feral

    -- Priest
    [589]    = true, -- Shadow Word: Pain         -- Shadow
    [34914]  = true, -- Vampiric Touch            -- Shadow
    [335467] = true, -- Shadow Word: Madness      -- Shadow
    [204197] = true, -- Purge the Wicked          -- Discipline

    -- Warlock
    [980]    = true, -- Agony                     -- Affliction
    [172]    = true, -- Corruption                -- Affliction
    [1259790] = true, -- Unstable Affliction       -- Affliction
    [348]    = true, -- Immolate                  -- Destruction
    [445468]  = true, -- Wither                   -- Destruction

    -- Rogue
    [1943]   = true, -- Rupture                   -- Assassination
    [121411] = true, -- Crimson Tempest           -- Assassination
}

function CDM.CONST.IsEmptyTable(t)
    return type(t) == "table" and next(t) == nil
end

function CDM.CONST.ApplyShadow(fontString)
    local c = CDM.CONST.SHADOW_COLOR
    local o = CDM.CONST.SHADOW_OFFSET
    fontString:SetShadowColor(c.r, c.g, c.b, c.a)
    fontString:SetShadowOffset(o.x, o.y)
end

function CDM.CONST.GetConfigValue(key, defaultValue)
    local db = CDM.db
    if db then
        local v = db[key]
        if v ~= nil then return v end
    end
    local df = CDM.defaults
    if df then
        local v = df[key]
        if v ~= nil then return v end
    end
    return defaultValue
end


local baseFontCache = {
    fontPath = nil,
    fontOutline = nil,
}

local cachedLSM = nil
local function GetLSM()
    if cachedLSM then return cachedLSM end
    cachedLSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    return cachedLSM
end

function CDM.CONST.RefreshBaseFontCache()
    local db = CDM.db
    local defaults = CDM.defaults or {}
    local textFontName = (db and db.textFont) or defaults.textFont or "Friz Quadrata TT"
    local LSM = GetLSM()
    baseFontCache.fontPath = (LSM and LSM:Fetch("font", textFontName)) or CDM.CONST.FONT_PATH
    local rawOutline = (db and db.textFontOutline) or defaults.textFontOutline or "OUTLINE"
    baseFontCache.fontOutline = (rawOutline == "NONE") and "" or rawOutline
end

function CDM.CONST.GetBaseFontPath()
    if not baseFontCache.fontPath then
        CDM.CONST.RefreshBaseFontCache()
    end
    return baseFontCache.fontPath
end

function CDM.CONST.GetBaseFontOutline()
    if baseFontCache.fontOutline == nil then
        CDM.CONST.RefreshBaseFontCache()
    end
    return baseFontCache.fontOutline
end

CDM.CONST.DEFENSIVE_SPELLS = {
    WARRIOR = {
        class = {
            23920,    -- Spell Reflection
            97462,    -- Rallying Cry
        },
        [71] = {              -- Arms
            118038,   -- Die by the Sword
        },
        [72] = {              -- Fury
            184364,   -- Enraged Regeneration
        },
        [73] = {              -- Protection
            871,      -- Shield Wall
        },
    },
    PALADIN = {
        class = {
            642,      -- Divine Shield
        },
        [65] = {              -- Holy
            498,      -- Divine Protection
        },
        [66] = {              -- Protection
            31850,    -- Ardent Defender
            86659,    -- Guardian of Ancient Kings
        },
        [70] = {              -- Retribution
            498,      -- Divine Protection
        },
    },
    HUNTER = {
        class = {
            109304,   -- Exhilaration
            186265,   -- Aspect of the Turtle
            264735,   -- Survival of the Fittest
        },
    },
    ROGUE = {
        class = {
            1966,     -- Feint
            5277,     -- Evasion
            31224,    -- Cloak of Shadows
            185311,   -- Crimson Vial
        },
    },
    PRIEST = {
        class = {
            586,      -- Fade
            19236,    -- Desperate Prayer
        },
        [258] = {             -- Shadow
            47585,    -- Dispersion
        },
    },
    DEATHKNIGHT = {
        class = {
            48707,    -- Anti-Magic Shell
            48792,    -- Icebound Fortitude
            49039,    -- Lichborne
            51052,    -- Anti-Magic Zone
        },
        [250] = {             -- Blood
            55233,    -- Vampiric Blood
        },
    },
    SHAMAN = {
        class = {
            108271,   -- Astral Shift
        },
    },
    MAGE = {
        class = {
            45438,    -- Ice Block
            342245,   -- Alter Time
        },
        [62] = {              -- Arcane
            235450,   -- Prismatic Barrier
        },
        [63] = {              -- Fire
            235313,   -- Blazing Barrier
        },
        [64] = {              -- Frost
            11426,    -- Ice Barrier
        },
    },
    WARLOCK = {
        class = {
            104773,   -- Unending Resolve
            108416,   -- Dark Pact
        },
    },
    MONK = {
        class = {
            115203,   -- Fortifying Brew
        },
    },
    DRUID = {
        class = {
            22812,    -- Barkskin
        },
        [103] = {             -- Feral
            61336,    -- Survival Instincts
        },
        [104] = {             -- Guardian
            61336,    -- Survival Instincts
        },
        [105] = {             -- Restoration
            102342,   -- Ironbark
        },
    },
    DEMONHUNTER = {
        class = {
            196718,   -- Darkness
        },
        [577] = {             -- Havoc
            198589,   -- Blur
        },
        [581] = {             -- Vengeance
            204021,   -- Fiery Brand
        },
        [1480] = {            -- Devourer
            198589,   -- Blur
        },
    },
    EVOKER = {
        class = {
            363916,   -- Obsidian Scales
        },
    },
}

CDM.CONST.DEFENSIVE_SPELLS_SET = {}
for _, classData in pairs(CDM.CONST.DEFENSIVE_SPELLS) do
    for _, spells in pairs(classData) do
        for _, id in ipairs(spells) do
            CDM.CONST.DEFENSIVE_SPELLS_SET[id] = true
        end
    end
end

CDM.CONST.DesaturationCurve = C_CurveUtil.CreateCurve()
CDM.CONST.DesaturationCurve:SetType(Enum.LuaCurveType.Step)
CDM.CONST.DesaturationCurve:AddPoint(0, 0)
CDM.CONST.DesaturationCurve:AddPoint(0.001, 1)

