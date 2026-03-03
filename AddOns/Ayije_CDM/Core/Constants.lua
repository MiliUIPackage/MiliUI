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
    TEX_SEPARATOR = "Interface\\AddOns\\Ayije_CDM\\Media\\Textures\\Separator",

    STRATA_MAIN = "MEDIUM",
    STRATA_OVERLAY = "HIGH",
    FRAME_LEVEL_BORDER = 2,
    FRAME_LEVEL_TEXT = 4,
    FRAME_LEVEL_OVERLAY = 10,

    ICON_TEXCOORD_MIN = 0.08,
    ICON_TEXCOORD_MAX = 0.92,

    PIP_SEPARATOR_WIDTH = 1,

    VIEWERS = {
        ESSENTIAL = "EssentialCooldownViewer",
        UTILITY = "UtilityCooldownViewer",
        BUFF = "BuffIconCooldownViewer",
        BUFF_SEC = "BuffIconCooldownViewer_Secondary",
        BUFF_TERT = "BuffIconCooldownViewer_Tertiary",
        BUFF_BAR = "BuffBarCooldownViewer",
    },

    SOUL_CLEAVE_SPELL_ID = 228477,
    MAELSTROM_WEAPON_SPELL_ID = 344179,
    GCD_SPELL_ID = 61304,
}

CDM.CONST.VIEWERS_WITH_OVERRIDE = {
    [CDM.CONST.VIEWERS.ESSENTIAL] = true,
    [CDM.CONST.VIEWERS.UTILITY] = true,
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

local _SHADOW_COLOR = CDM.CONST.SHADOW_COLOR
local _SHADOW_OFFSET = CDM.CONST.SHADOW_OFFSET

function CDM.CONST.ApplyShadow(fontString)
    fontString:SetShadowColor(_SHADOW_COLOR.r, _SHADOW_COLOR.g, _SHADOW_COLOR.b, _SHADOW_COLOR.a)
    fontString:SetShadowOffset(_SHADOW_OFFSET.x, _SHADOW_OFFSET.y)
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

function CDM.CONST.GetPixelFontSize(desiredPixels)
    return desiredPixels * PixelUtil.GetPixelToUIUnitFactor()
end

local math_floor = math.floor
local math_ceil = math.ceil

function CDM.CONST.PixelPerfect(value)
    if value >= 0 then
        return math_floor(value + 0.5)
    else
        return math_ceil(value - 0.5)
    end
end

local function GetPixelSizeForRegion(region)
    local regionType = type(region)
    local isRegionObject = (regionType == "table" or regionType == "userdata")

    if PixelUtil and PixelUtil.ConvertPixelsToUIForRegion and isRegionObject then
        local ok, px = pcall(PixelUtil.ConvertPixelsToUIForRegion, 1, region)
        if ok and type(px) == "number" and px > 0 then
            return px
        end
    end

    local pixel = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()) or 1
    local scale = (isRegionObject and region.GetEffectiveScale and region:GetEffectiveScale())
        or (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale())
        or 1

    if scale and scale > 0 then
        pixel = pixel / scale
    end
    if not pixel or pixel <= 0 then
        return 1
    end
    return pixel
end

CDM.CONST.GetPixelSizeForRegion = GetPixelSizeForRegion

local function NormalizeRegionNumberArgs(a, b)
    if type(a) ~= "number" and type(b) == "number" then
        return b, a
    end
    return a, b
end

local function ResolvePointPixelRegion(frame, relativeTo, pixelRegion)
    return pixelRegion or relativeTo or frame or UIParent
end

function CDM.CONST.ToPixelCountForRegion(value, region, minPixels)
    -- Backward compatible with older callsites that passed (region, value, minPixels).
    value, region = NormalizeRegionNumberArgs(value, region)
    local pixel = GetPixelSizeForRegion(region)
    local count = CDM.CONST.PixelPerfect((value or 0) / pixel)
    if minPixels ~= nil and count < minPixels then
        count = minPixels
    end
    return count
end

function CDM.CONST.PixelsToUIForRegion(pixels, region)
    pixels, region = NormalizeRegionNumberArgs(pixels, region)
    return (pixels or 0) * GetPixelSizeForRegion(region)
end

function CDM.CONST.SnapOffsetToPixel(value, region)
    local pixel = GetPixelSizeForRegion(region)
    return CDM.CONST.PixelPerfect((value or 0) / pixel) * pixel
end

function CDM.CONST.SnapContainerWidth(width, region)
    local pixel = GetPixelSizeForRegion(region)
    if not pixel or pixel <= 0 then return width end
    local wPx = CDM.CONST.PixelPerfect(width / pixel)
    if wPx % 2 ~= 0 then wPx = wPx + 1 end
    return wPx * pixel
end

function CDM.CONST.SetPixelPerfectPoint(frame, point, relativeTo, relativePoint, x, y, pixelRegion)
    if not frame then return end
    local region = ResolvePointPixelRegion(frame, relativeTo, pixelRegion)
    frame:SetPoint(
        point,
        relativeTo,
        relativePoint,
        CDM.CONST.SnapOffsetToPixel(x or 0, region),
        CDM.CONST.SnapOffsetToPixel(y or 0, region)
    )
end

function CDM.CONST.SetPointPixels(frame, point, relativeTo, relativePoint, xPx, yPx, pixelRegion)
    if not frame then return end
    local region = ResolvePointPixelRegion(frame, relativeTo, pixelRegion)
    frame:SetPoint(
        point,
        relativeTo,
        relativePoint,
        CDM.CONST.PixelsToUIForRegion(xPx or 0, region),
        CDM.CONST.PixelsToUIForRegion(yPx or 0, region)
    )
end

function CDM.CONST.IsPixelIconBorderMode()
    local borderFile = CDM.CONST.GetConfigValue("borderFile", "Ayije_Thin")
    if borderFile == "None" then
        return false
    end
    if borderFile == "1 Pixel" then
        return true
    end

    local borderSize = CDM.CONST.GetConfigValue("borderSize", 16)
    return math.max(0, CDM.CONST.ToPixelCountForRegion(borderSize, UIParent, 0)) <= 1
end

function CDM.CONST.GetCooldownIconGapPixels(spacing, region)
    return CDM.CONST.ToPixelCountForRegion(spacing or 0, region or UIParent, 0)
end

do
    local snapGenerations = setmetatable({}, { __mode = "k" })
    function CDM.SchedulePixelSnap(container)
        if not container then return end
        local gen = (snapGenerations[container] or 0) + 1
        snapGenerations[container] = gen
        C_Timer.After(0, function()
            if snapGenerations[container] ~= gen then return end
            C_Timer.After(0, function()
                if snapGenerations[container] ~= gen then return end
                local cl = container:GetLeft()
                local ct = container:GetTop()
                if not (cl and ct) then return end
                local onePixel = GetPixelSizeForRegion(UIParent) or 1
                local snappedLeft = CDM.CONST.PixelPerfect(cl / onePixel) * onePixel
                local snappedTop = CDM.CONST.PixelPerfect(ct / onePixel) * onePixel
                if math.abs(cl - snappedLeft) < onePixel * 0.05
                    and math.abs(ct - snappedTop) < onePixel * 0.05 then
                    return
                end
                container:ClearAllPoints()
                container:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", snappedLeft, snappedTop)
            end)
        end)
    end
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

CDM.CONST.IsActiveCurve = C_CurveUtil.CreateCurve()
CDM.CONST.IsActiveCurve:SetType(Enum.LuaCurveType.Step)
CDM.CONST.IsActiveCurve:AddPoint(0, 0)
CDM.CONST.IsActiveCurve:AddPoint(0.0001, 1)

CDM.CONST.DesaturationCurve = C_CurveUtil.CreateCurve()
CDM.CONST.DesaturationCurve:SetType(Enum.LuaCurveType.Step)
CDM.CONST.DesaturationCurve:AddPoint(0, 0)
CDM.CONST.DesaturationCurve:AddPoint(0.001, 1)

CDM.CONST.GCDFilterCurve = C_CurveUtil.CreateCurve()
CDM.CONST.GCDFilterCurve:SetType(Enum.LuaCurveType.Step)
CDM.CONST.GCDFilterCurve:AddPoint(0, 0)
CDM.CONST.GCDFilterCurve:AddPoint(1.6, 1)

