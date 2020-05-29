local ADDON_NAME, Addon = ...
local ThreatPlates = Addon.ThreatPlates

---------------------------------------------------------------------------------------------------
-- Stuff for handling the configuration of Threat Plates - ThreatPlatesDB
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local RAID_CLASS_COLORS, CLASS_SORT_ORDER = RAID_CLASS_COLORS, CLASS_SORT_ORDER

local L = ThreatPlates.L
local RGB, RGB_P, RGB_WITH_HEX = ThreatPlates.RGB, ThreatPlates.RGB_P, ThreatPlates.RGB_WITH_HEX
local HEX2RGB = ThreatPlates.HEX2RGB

---------------------------------------------------------------------------------------------------
-- Global contstants
---------------------------------------------------------------------------------------------------

ThreatPlates.ADDON_NAME = L["Threat Plates"]

Addon.ADDON_DIRECTORY = "Interface\\AddOns\\TidyPlates_ThreatPlates\\"

-- Define names for keybindings
_G["BINDING_HEADER_" .. "THREATPLATES"] = ThreatPlates.ADDON_NAME
_G["BINDING_NAME_" .. "THREATPLATES_NAMEPLATE_MODE_FOR_FRIENDLY_UNITS"] = L["Toggle Friendly Headline View"]
_G["BINDING_NAME_" .. "THREATPLATES_NAMEPLATE_MODE_FOR_NEUTRAL_UNITS"] = L["Toggle Neutral Headline View"]
_G["BINDING_NAME_" .. "THREATPLATES_NAMEPLATE_MODE_FOR_ENEMY_UNITS"] = L["Toggle Enemy Headline View"]

Addon.CLASSIC = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)

---------------------------------------------------------------------------------------------------
-- Color and font definitions
---------------------------------------------------------------------------------------------------
Addon.DEFAULT_FONT = "Cabin"
Addon.DEFAULT_SMALL_FONT = "Arial Narrow"

local locale = GetLocale()
local MAP_FONT = {
  koKR = { -- Korrean
    DefaultFont = "기본 글꼴",      -- "2002"
    DefaultSmallFont = "기본 글꼴", -- "2002"
  },
  zhCN = { -- Simplified Chinese
    DefaultFont = "默认",      -- "AR ZhongkaiGBK Medium"
    DefaultSmallFont = "默认", -- "AR ZhongkaiGBK Medium"
  },
  zhTW = { -- Traditional Chinese
    DefaultFont = "預設",       -- "AR Kaiti Medium B5"
    DefaultSmallFont = "預設",  -- "AR Kaiti Medium B5"
  },
  ruRU = { -- Russian
    DefaultFont = "Friz Quadrata TT", -- "FrizQuadrataCTT"
    DefaultSmallFont = "Arial Narrow",
  }
}

if MAP_FONT[locale] then
  Addon.DEFAULT_FONT = MAP_FONT[locale].DefaultFont
  Addon.DEFAULT_SMALL_FONT = MAP_FONT[locale].DefaultSmallFont
end

local function GetDefaultColorsForClasses()
  local class_colors = {}

  for i, class_name in ipairs(CLASS_SORT_ORDER) do
    -- Do not use GetRGBAsBytes to fix a error created by addons that change the entries of RAID_CLASS_COLORS from ColorMixin to a
    -- simple r/g/b array
    -- Perfered solution here would be:
    -- class_colors[class_name] = RGB_WITH_HEX(RAID_CLASS_COLORS[class_name]:GetRGBAsBytes())

    -- RAID_CLASS_COLORS[class_name] is not null even in Classic for unknown classes like MONK
    local color = RAID_CLASS_COLORS[class_name]
    class_colors[class_name] = RGB_WITH_HEX(color.r * 255, color.g * 255, color.b * 255)
  end

  return class_colors
end

---------------------------------------------------------------------------------------------------
-- Global contstants for various stuff
---------------------------------------------------------------------------------------------------
Addon.ON_UPDATE_PER_FRAME = 1 / GetFramerate()
Addon.ON_UPDATE_INTERVAL = 0.25 -- minimum number of seconds between each update of a frame for OnUpdate handlers
Addon.PLATE_FADE_IN_TIME = 0.5
Addon.CASTBAR_INTERRUPT_HOLD_TIME = 1

Addon.UIScale = 1

Addon.TotemInformation = {} -- basic totem information
Addon.TOTEMS = {} -- mapping table for fast access to totem settings

Addon.ANCHOR_POINT = {
  TOPLEFT = L["Top Left"],
  TOP = L["Top"],
  TOPRIGHT = L["Top Right"],
  LEFT = L["Left"],
  CENTER = L["Center"],
  RIGHT = L["Right"],
  BOTTOMLEFT = L["Bottom Left"],
  BOTTOM = L["Bottom"],
  BOTTOMRIGHT = L["Bottom Right"],
}

Addon.ANCHOR_POINT_SETPOINT = {
  TOPLEFT = {"TOPLEFT", "BOTTOMLEFT"},
  TOP = {"TOP", "BOTTOM"},
  TOPRIGHT = {"TOPRIGHT", "BOTTOMRIGHT"},
  LEFT = {"LEFT", "RIGHT"},
  CENTER = {"CENTER", "CENTER"},
  RIGHT = {"RIGHT", "LEFT"},
  BOTTOMLEFT = {"BOTTOMLEFT", "TOPLEFT"},
  BOTTOM = {"BOTTOM", "TOP"},
  BOTTOMRIGHT = {"BOTTOMRIGHT", "TOPRIGHT"}
}

Addon.ANCHOR_POINT_TEXT = {
  TOPLEFT = {"TOPLEFT", "BOTTOMRIGHT"},
  TOP = {"TOP", "BOTTOM"},
  TOPRIGHT = {"TOPRIGHT", "BOTTOMLEFT"},
  LEFT = {"LEFT", "RIGHT"},
  CENTER = {"CENTER", "CENTER"},
  RIGHT = {"RIGHT", "LEFT"},
  BOTTOMLEFT = {"BOTTOMLEFT", "TOPRIGHT"},
  BOTTOM = {"BOTTOM", "TOP"},
  BOTTOMRIGHT = {"BOTTOMRIGHT", "TOPLEFT"}
}

ThreatPlates.AlignH = {LEFT = L["Left"], CENTER = L["Center"], RIGHT = L["Right"]}
ThreatPlates.AlignV = {BOTTOM = L["Bottom"], CENTER = L["Center"], TOP = L["Top"]}

ThreatPlates.AUTOMATION = {
  NONE = L["No Automation"],
  SHOW_COMBAT = L["Show during Combat, Hide when Combat ends"],
  HIDE_COMBAT = L["Hide when Combat starts, Show when Combat ends"],
}

Addon.GLOW_TYPES = {
  Button = L["Button"],
  Pixel = L["Pixel"],
  AutoCast = L["Auto-Cast"],
}

Addon.CUSTOM_GLOW_FUNCTIONS = {
  Button = { "ButtonGlow_Start", "ButtonGlow_Stop", 8 },
  Pixel = { "PixelGlow_Start", "PixelGlow_Stop", 3 },
  AutoCast = { "AutoCastGlow_Start", "AutoCastGlow_Stop", 4 },
}

Addon.CUSTOM_PLATES_GLOW_FRAMES = {
  None = L["None"],
  Healthbar = L["Healthbar"],
  Castbar = L["Castbar"],
  Icon = L["Icon"],
}

Addon.TARGET_TEXTURES = {
  default = L["Default"],
  squarethin = L["Thin Square"],
  arrows = L["Arrow"],
  arrow_down = L["Down Arrow"],
  arrow_less_than = L["Less-Than Arrow"],
  glow = L["Glow"],
  threat_glow = L["Threat Glow"],
  crescent = L["Crescent"],
  bubble = L["Bubble"],
  arrows_legacy = L["Arrow (Legacy)"],
}

----------------------------------------------------------------------------------------------------
-- Paths
---------------------------------------------------------------------------------------------------

ThreatPlates.Widgets = "Interface\\Addons\\TidyPlates_ThreatPlates\\Artwork\\Widgets\\"

---------------------------------------------------------------------------------------------------
-- Global contstants for options dialog
---------------------------------------------------------------------------------------------------

Addon.AurasFilterMode = {
  ["whitelist"] = L["White List"],
  ["blacklist"] = L["Black List"],
  ["all"] = L["All Auras"],
}

ThreatPlates.SPEC_ROLES = {
  DEATHKNIGHT = { true, false, false },
  DEMONHUNTER = { false, true },
  DRUID 			= { false, false, true, false },
  HUNTER			= { false, false, false },
  MAGE				= { false, false, false },
  MONK 				= { true, false, false },
  PALADIN 		= { false, true, false },
  PRIEST			= { false, false, false },
  ROGUE				= { false, false, false },
  SHAMAN			= { false, false, false },
  WARLOCK			= { false, false, false },
  WARRIOR			= { false, false, true },
}

ThreatPlates.FontStyle = {
  NONE = L["None"],
  OUTLINE = L["Outline"],
  THICKOUTLINE = L["Thick Outline"],
  ["NONE, MONOCHROME"] = L["No Outline, Monochrome"],
  ["OUTLINE, MONOCHROME"] = L["Outline, Monochrome"],
  ["THICKOUTLINE, MONOCHROME"] = L["Thick Outline, Monochrome"]
}

-- "By Threat", "By Level Color", "By Normal/Elite/Boss"
ThreatPlates.ENEMY_TEXT_COLOR = {
  CLASS = L["By Class"],
  CUSTOM = L["By Custom Color"],
  REACTION = L["By Reaction"],
  HEALTH = L["By Health"],
}

ThreatPlates.FRIENDLY_TEXT_COLOR = {
  CLASS = L["By Class"],
  CUSTOM = L["By Custom Color"],
  REACTION = L["By Reaction"],
  HEALTH = L["By Health"],
}

-- NPC Role, Guild, or Quest", "Quest",
ThreatPlates.ENEMY_SUBTEXT = {
  NONE = L["None"],
  HEALTH = L["Health"],
  ROLE = L["NPC Role"],
  ROLE_GUILD = L["NPC Role, Guild"],
  ROLE_GUILD_LEVEL = L["NPC Role, Guild, or Level"],
  LEVEL = L["Level"],
  ALL = L["Everything"],
}

-- "NPC Role, Guild, or Quest", "Quest"
ThreatPlates.FRIENDLY_SUBTEXT = {
  NONE = L["None"],
  HEALTH = L["Health"],
  ROLE = L["NPC Role"],
  ROLE_GUILD = L["NPC Role, Guild"],
  ROLE_GUILD_LEVEL = L["NPC Role, Guild, or Level"],
  LEVEL = L["Level"],
  ALL = L["Everything"],
}

-------------------------------------------------------------------------------
-- Totem data - define it one time for the whole addon
-------------------------------------------------------------------------------

local TOTEM_DATA = {
  -- Baseline Totems
  { SpellID = 192058, ID = "B1", GroupColor = "8A2BE2"},		-- Capacitor Totem (ex-Lightning Surge Totem, baseline since 8.0.1)

  -- Fire totems
  { SpellID = 192222, ID = "F1", GroupColor = "ff8f8f"}, 	  -- Liquid Magma Totem

  -- Earth Totems
  { SpellID = 8143,   ID = "E1", GroupColor = "8B4513"},	  -- Tremor Totem (added in pacth 8.0.1, TP v9.0.9)

  -- Totems from spezialization
  { SpellID = 98008,  ID = "S1", GroupColor = "ffb31f"},		-- Spirit Link Totem
  { SpellID = 5394,	  ID = "S2", GroupColor = "ffb31f"},		-- Healing Stream Totem
  { SpellID = 108280, ID = "S3", GroupColor = "ffb31f"},		-- Healing Tide Totem
  { SpellID = 160161, ID = "S4", GroupColor = "ffb31f"}, 	  -- Earthquake Totem
  { SpellID = 2484,   ID = "S5",	GroupColor = "ffb31f"},   -- Earthbind Totem (added patch 7.2, TP v8.4.0)

  -- Totems from Totem Mastery
  { SpellID = 202188, ID = "M1", GroupColor = "b8d1ff"}, 	  -- Resonance Totem
  { SpellID = 210651, ID = "M2", GroupColor = "b8d1ff"},		-- Storm Totem
  { SpellID = 210657, ID = "M3", GroupColor = "b8d1ff"},		-- Ember Totem
  { SpellID = 210660, ID = "M4", GroupColor = "b8d1ff"},		-- Tailwind Totem

  -- Totems from talents
  { SpellID = 157153, ID = "N1", GroupColor = "4c9900"},		-- Cloudburst Totem
  { SpellID = 51485,  ID = "N2", GroupColor = "4c9900"},		-- Earthgrab Totem
  { SpellID = 207399, ID = "N4", GroupColor = "4c9900"},		-- Ancestral Protection Totem
  { SpellID = 192077, ID = "N5", GroupColor = "4c9900"},		-- Wind Rush Totem
  { SpellID = 198838, ID = "N7", GroupColor = "4c9900"},		-- Earthen Wall Totem

  -- Totems from PVP talents
  { SpellID = 204331, ID = "P1", GroupColor = "2b76ff"},	  -- Counterstrike Totem
  { SpellID = 204330, ID = "P2", GroupColor = "2b76ff"},	  -- Skyfury Totem
  { SpellID = 204336, ID = "P4", GroupColor = "2b76ff"},	  -- Grounding Totem

  --{ SpellID = 204332, ID = "P3", GroupColor = "2b76ff"},	  -- Windfury Totem (removed in patch 8.0.1)p
  --{ SpellID = 196932, ID = "N6", GroupColor = "4c9900"},		-- Voodoo Totem (removed in patch 8.0.1)
  --{ SpellID = 192058, ID = "N3", GroupColor = "4c9900"},		-- Lightning  Surge Totem (renamed to Capacitator Totem in patch 8.0.1)
}

function Addon:InitializeTotemInformation()
  for i, totem_data in ipairs(TOTEM_DATA) do
    local name = GetSpellInfo(totem_data.SpellID) or UNKNOWNOBJECT

    totem_data.Name = name
    totem_data.Color = RGB(HEX2RGB(totem_data.GroupColor))
    totem_data.SortKey = totem_data.ID:sub(1, 1) .. name
    totem_data.Style = "normal"
    totem_data.ShowNameplate = true
    totem_data.ShowHPColor = true
    totem_data.ShowIcon = true

    Addon.TotemInformation[name] = totem_data
    Addon.TOTEMS[name] = totem_data.ID
  end

--  local test_name = "Hochexarch Turalyon"
--  local id = "P4"
--  Addon.TotemInformation[test_name] = {
--    Name = test_name,
--    SpellID = 204336,
--    Icon = id,
--    ID = id,
--    SortKey = id:sub(1, 1) .. test_name,
--    Style = "normal",
--    Color = RGB(HEX2RGB("2b76ff")),
--    GroupColor = "2b76ff",
--    ShowNameplate = true,
--    ShowHPColor = true,
--    ShowIcon = true,
--  }
--  Addon.TOTEMS[test_name] = id
end

local function GetDefaultTotemSettings()
  Addon:InitializeTotemInformation()

  local settings = {
    hideHealthbar = false
  }

  for _, data in pairs(Addon.TotemInformation) do
    settings[data.ID] = data
  end

  return settings
end

---------------------------------------------------------------------------------------------------
-- Default settings for ThreatPlates
---------------------------------------------------------------------------------------------------

ThreatPlates.DEFAULT_SETTINGS = {
  global = {
    version = "",
    DefaultsVersion = "SMOOTH",
    CustomNameplatesVersion = 1,
  },
  char = {
    welcome = false,
    specInfo = {
      [1] = {
        name = "",
        role = "",
      },
      [2] = {
        name = "",
        role = "",
      },
    },
    spec = {
      [1] = false,
      [2] = false,
    },
  },
  profile = {
    cache = {},
    -- OldSetting = true, - removed in 8.7.0
    verbose = false,
    -- blizzFadeA = { -- removed in 8.5.1
    --   toggle  = true,
    --   amount = 0.7
    -- },
    blizzFadeS = {
      toggle  = true,
      amount = -0.3
    },
    tidyplatesFade = false,
    healthColorChange = false,
    customColor =  false,
    allowClass = true, -- old default: false,
    friendlyClass = true, -- old default: false,
    friendlyClassIcon = false,
    HostileClassIcon = true,
    cacheClass = false,
    optionRoleDetectionAutomatic = true, -- old default: false,
    ShowThreatGlowOnAttackedUnitsOnly = false,
    ShowThreatGlowOffTank = true,
    NamePlateEnemyClickThrough = false,
    NamePlateFriendlyClickThrough = true,
    ShowFriendlyBlizzardNameplates = false,
    ShowEnemyBlizzardNameplates = false,
    Automation = {
      FriendlyUnits = "NONE",
      EnemyUnits = "NONE",
      SmallPlatesInInstances = false,
      HideFriendlyUnitsInInstances = true,
    },
    Scale = {
      IgnoreUIScale = true,
      PixelPerfectUI = false,
    },
    HeadlineView = {
      -- ON = false, -- removed in 9.1.0
      name = {
        size = 11,
        -- width = 140, -- same as for healthbar view -- old default: 116,
        -- height = 14, -- same as for healthbar view
        x = 0,
        y = 4,
        align = "CENTER",
        vertical = "CENTER",
      },
      customtext = {
        size = 8,
        -- shadow = true,  -- never used
        -- flags = "NONE", -- never used
        -- width = 140,    -- never used, same as for healthbar view
        -- height = 14,    -- never used, same as for healthbar view
        x = 0,
        y = -6,
        align = "CENTER",
        vertical = "CENTER",
      },
      useAlpha = true,
      -- blizzFading = true, -- removed in 8.5.1
      -- blizzFadingAlpha = 1, -- removed in 8.5.1
      useScaling = true,
      ShowTargetHighlight = true,
      ShowFocusHighlight = true,
      ShowMouseoverHighlight = true,
      ForceHealthbarOnTarget = false,
      ForceOutOfCombat = true,
      ForceNonAttackableUnits = true,
      ForceFriendlyInCombat = "NONE",
      --
      EnemyTextColorMode = "CLASS",
      EnemyTextColor = RGB(0, 255, 0),
      FriendlyTextColorMode = "CLASS",
      FriendlyTextColor = RGB(0, 255, 0),
      UseRaidMarkColoring = false,
      SubtextColorUseHeadline = false,
      SubtextColorUseSpecific = true,
      SubtextColor =  RGB(255, 255, 255, 1),
      --
      EnemySubtext = "ROLE_GUILD",
      FriendlySubtext = "ROLE_GUILD",
    },
    Visibility = {
      --				showNameplates = true,
      --				showHostileUnits = true,
      --				showFriendlyUnits = false,
      FriendlyPlayer = { Show = true, UseHeadlineView = true },
      FriendlyNPC = { Show = "nameplateShowFriendlyNPCs", UseHeadlineView = true },
      FriendlyTotem = { Show = "nameplateShowFriendlyTotems", UseHeadlineView = true },
      FriendlyGuardian = { Show = "nameplateShowFriendlyGuardians", UseHeadlineView = true },
      FriendlyPet = { Show = "nameplateShowFriendlyPets", UseHeadlineView = true },
      FriendlyMinus = { Show = true, UseHeadlineView = true },
      EnemyPlayer = { Show = true, UseHeadlineView = false },
      EnemyNPC = { Show = true, UseHeadlineView = false },
      EnemyTotem = { Show = "nameplateShowEnemyTotems", UseHeadlineView = false },
      EnemyGuardian = { Show = "nameplateShowEnemyGuardians", UseHeadlineView = false },
      EnemyPet = { Show = "nameplateShowEnemyPets", UseHeadlineView = false },
      EnemyMinus = { Show = "nameplateShowEnemyMinus", UseHeadlineView = false },
      NeutralNPC = { Show = true, UseHeadlineView = false },
      --        NeutralGuardian = { Show = true, UseHeadlineView = false },
      NeutralMinus = { Show = true, UseHeadlineView = false },
      -- special units
      HideNormal = false,
      HideBoss = false,
      HideElite = false,
      HideTapped = false,
      HideFriendlyInCombat = false,
    },
    castbarColor = {
      -- toggle = true, -- removed in 8.7.0
      r = 1,
      g = 0.56,
      b = 0.06,
      a = 1
    },
    castbarColorShield = {
      --toggle = true,  -- removed in 8.7.0
      r = 1,
      g = 0,
      b = 0,
      a = 1
    },
    castbarColorInterrupted = RGB(255, 0, 255, 1),
    aHPbarColor = RGB_P(0, 1, 0),
    bHPbarColor = RGB_P(1, 1, 0),
--    cHPbarColor = {
--      r = 1,
--      g = 0,
--      b = 0
--    },
--    fHPbarColor = RGB(0, 255, 0),
--    nHPbarColor = RGB(255, 255, 0),
--    tapHPbarColor = RGB(100, 100, 100),
--    HPbarColor = RGB(255, 0, 0),
--    tHPbarColor = {
--      r = 0,
--      g = 0.5,
--      b = 1,
--    },
    ColorByReaction = {
      FriendlyPlayer = RGB(0, 0, 255),           -- blue
      FriendlyNPC = RGB(0, 255, 0),              -- green
      HostileNPC = RGB(255, 0, 0),               -- red
      HostilePlayer = RGB(255, 0, 0),            -- red
      NeutralUnit = RGB(255, 255, 0),            -- yellow
      TappedUnit = RGB(110, 110, 110, 1),	       -- grey
      DisconnectedUnit = RGB(128, 128, 128, 1),  -- dray, darker than tapped color
      UnfriendlyFaction = RGB(255, 153, 51, 1),  -- brown/orange for unfriendly, hostile, non-attackable units (unit reaction = 3)
    },
    Colors = {
      Classes = GetDefaultColorsForClasses()
    },
    text = {
      amount = false, -- old default: true,
      percent = true,
      full = false,
      max = false,
      deficit = false,
      truncate = true,
      LocalizedUnitSymbol = true,
      -- Absorbs
      AbsorbsAmount = false,
      AbsorbsShorten = true,
      AbsorbsPercentage = false,
    },
    totemWidget = {
      ON = true,
      scale = 35,
      x = 0,
      y = 35,
      level = 1,
      anchor = "CENTER"
    },
    arenaWidget = {
      ON = false, --old default: true,
      scale = 16,
      x = 36,
      y = -6,
      anchor = "CENTER",
      ShowOrb = true,
      ShowNumber = true,
      HideName = false,
      colors = {
        [1] = RGB_P(1, 0, 0, 1),
        [2] = RGB_P(1, 1, 0, 1),
        [3] = RGB_P(0, 1, 0, 1),
        [4] = RGB_P(0, 1, 1, 1),
        [5] = RGB_P(0, 0, 1, 1),
      },
      numColors = {
        [1] = RGB_P(1, 1, 1, 1),
        [2] = RGB_P(1, 1, 1, 1),
        [3] = RGB_P(1, 1, 1, 1),
        [4] = RGB_P(1, 1, 1, 1),
        [5] = RGB_P(1, 1, 1, 1),
      },
      NumberText = {
        Anchor = "CENTER",
        InsideAnchor = true,
        HorizontalOffset = 1,
        VerticalOffset = 0,
        Font = {
          Typeface = Addon.DEFAULT_FONT,
          Size = 12,
          flags = "OUTLINE",
          Shadow = true,
          HorizontalAlignment = "CENTER",
          VerticalAlignment = "CENTER",
        },
      },
    },
    healerTracker = {
      ON = false,
      scale = 22,
      x = 0,
      y = 35,
      level = 1,
      alpha = 1,
      anchor = "RIGHT",
      ShowInHeadlineView = false
    },
    AuraWidget = {
      ON = true,
      x = 0,
      y = 16,
      x_hv = 0,
      y_hv = 16,
      scale = 1, -- Removed in 8.8.0
      FrameOrder = "HEALTHBAR_AURAS",
      anchor = "TOP",
      ShowInHeadlineView = false,
      -- ShowEnemy = true, -- Removed in 8.8.0
      -- ShowFriendly = true, -- Removed in 8.8.0
      -- FilterMode = "blacklistMine", -- Moved to Debuffs in 8.8.0
      -- ShowDebuffsOnFriendly = false, -- Moved to Debuffs in 8.8.0
      -- FilterBySpell = {}, -- Moved to Debuffs in 8.8.0
      ShowTargetOnly = false,
      ShowCooldownSpiral = false,
      ShowDuration = true,
      ShowOmnicCC = false,
      ShowStackCount = true,
      ShowTooltips = false,
      ShowAuraType = true,
      DefaultBuffColor = RGB(102, 0, 51, 1),
      DefaultDebuffColor = 	RGB(204, 0, 0, 1),
      Highlight = {
        Enabled = true,
        Type = "Button",
        CustomColor = false,
        Color = RGB_P(0.95, 0.95, 0.32, 1),
      },
      SortOrder = "TimeLeft",
      SortReverse = false,
      AlignmentH = "LEFT",
      AlignmentV = "BOTTOM",
      CenterAuras = true,
      SwitchScaleByReaction = true,
      FlashWhenExpiring = true,
      FlashTime = 5,
      Debuffs = {
        ShowFriendly = false,
        ShowAllFriendly = false,
        ShowBlizzardForFriendly = true,
        ShowDispellable = true,
        ShowBoss = true,
        ShowEnemy = true,
        ShowAllEnemy = false,
        ShowOnlyMine = true,
        ShowBlizzardForEnemy = false,
        Scale = 1.0,
        FilterMode = "blacklist",
        FilterBySpell = {},
        FilterByType = {
          --[1] = true, -- Removed in 8.8.0
          [1] = false,  -- Moved to Debuffs and negated meaning in 8.8.0
          [2] = false,  -- Moved to Debuffs and negated meaning in 8.8.0
          [3] = false,  -- Moved to Debuffs and negated meaning in 8.8.0
          [4] = false,  -- Moved to Debuffs and negated meaning in 8.8.0
          --[6] = true, -- Removed in 8.8.0
        },
      },
      Buffs = {
        ShowFriendly = false,
        ShowAllFriendly = false,
        ShowOnFriendlyNPCs = true,
        ShowOnlyMine = false,
        ShowPlayerCanApply = false,
        ShowEnemy = true,
        ShowAllEnemy = false,
        ShowOnEnemyNPCs = true,
        ShowDispellable = true,
        ShowMagic = false,
        ShowUnlimitedAlways = false,
        ShowUnlimitedInCombat = true,
        ShowUnlimitedInInstances = false,
        ShowUnlimitedOnBosses = true,
        HideUnlimitedDuration = false,
        Scale = 1.2,
        FilterMode = "blacklist",
        FilterBySpell = {},
      },
      CrowdControl = {
        ShowFriendly = true,
        ShowAllFriendly = false,
        ShowBlizzardForFriendly = true,
        ShowDispellable = true,
        ShowBoss = true,
        ShowEnemy = true,
        ShowAllEnemy = false,
        ShowBlizzardForEnemy = true,
        Scale = 1.5,
        FilterMode = "blacklist",
        FilterBySpell = {},
      },
      ModeIcon = {
        Style = "wide",
        IconWidth = 26.5,
        IconHeight = 14.5,
        ShowBorder = true,
        Columns = 5,
        Rows = 3,
        ColumnSpacing = 5,
        RowSpacing = 8,
        Duration = {
          Anchor = "RIGHT",
          InsideAnchor = true,
          HorizontalOffset = 0,
          VerticalOffset = 8,
          Font = {
            Typeface = Addon.DEFAULT_SMALL_FONT,
            Size = 10,
            Transparency = 1,
            Color = RGB(255, 255, 255),
            flags = "OUTLINE",
            Shadow = true,
            HorizontalAlignment = "RIGHT",
            VerticalAlignment = "CENTER",
          }
        },
        StackCount = {
          Anchor = "RIGHT",
          InsideAnchor = true,
          HorizontalOffset = 0,
          VerticalOffset = -6,
          Font = {
            Typeface = Addon.DEFAULT_SMALL_FONT,
            Size = 10,
            Transparency = 1,
            Color = RGB(255, 255, 255),
            flags = "OUTLINE",
            Shadow = true,
            HorizontalAlignment = "RIGHT",
            VerticalAlignment = "CENTER",
          }
        },
      },
      ModeBar = {
        Enabled = false,
        BarHeight = 14,
        BarWidth = 100,
        BarSpacing = 2,
        MaxBars = 10,
        Texture = "Smooth", -- old default: "Aluminium",
        Font = Addon.DEFAULT_SMALL_FONT,
        FontSize = 10,
        FontColor = RGB(255, 255, 255),
        LabelTextIndent = 4,
        TimeTextIndent = 4,
        BackgroundTexture = "Smooth",
        BackgroundColor = RGB(0, 0, 0, 0.3),
        -- BackgroundBorder = "ThreatPlatesBorder", -- not used
        -- BackgroundBorderEdgeSize = 1, -- not used
        -- BackgroundBorderInset = 1, -- not used
        -- BackgroundBorderColor = RGB(0, 0, 0, 0.3), -- not used
        ShowIcon = true,
        IconSpacing = 2,
        IconAlignmentLeft = true,
      },
    },
    uniqueWidget = {
      ON = true,
      scale = 22, -- old default: 35,
      x = 0,
      y = 30, -- old default:  24,
      x_hv = 0,
      y_hv = 22,
      level = 1,
      anchor = "CENTER"
    },
    classWidget = {
      ON = false,
      scale = 22,
      x = -76,
      y = -7,
      x_hv = -74,
      y_hv = -7,
      theme = "default",
      anchor = "CENTER",
      ShowInHeadlineView = false,
    },
    targetWidget = {
      ON = true,
      theme = "default",
      r = 1,
      g = 1,
      b = 1,
      a = 1,
      ModeHPBar = false,
      ModeNames = false,
      HPBarColor = RGB(255, 0, 255), -- Magenta / Fuchsia
      Size = 32,
      HorizontalOffset = 8,
      VerticalOffset = 0,
    },
    FocusWidget = {
      ON = true,
      theme = "arrow_less_than",
      r = 0,
      g = 0.8,
      b = 0.8,
      a = 1,
      ModeHPBar = false,
      ModeNames = false,
      HPBarColor = RGB(0, 204, 204),
      Size = 38,
      HorizontalOffset = 0,
      VerticalOffset = 12,
    },
    threatWidget = {
      ON = false,
      x = 0,
      y = 26,
      anchor = "CENTER",
    },
    tankedWidget = {
      ON = false,
      scale = 1,
      x = 65,
      y = 6,
      anchor = "CENTER",
    },
    ComboPoints = {
      ON = true,
      ShowInHeadlineView = false,
      Style = "Orbs",
      HorizontalSpacing = 0,
      UseUniformColor = true,
      ShowOffCPs = false,
      Scale = 1,
      Transparency = 1,
      x = 0,
      y = -10,
      x_hv = 0,
      y_hv = -20,
      Specialization = "DRUID",
      ColorBySpec = {
        DEATHKNIGHT = {
          [1] = RGB(255, 0, 255),
          [2] = RGB(255, 0, 255),
          [3] = RGB(255, 0, 255),
          [4] = RGB(255, 0, 255),
          [5] = RGB(255, 0, 255),
          [6] = RGB(255, 0, 255),
        },
        DRUID = {
          [1] = RGB(0, 0, 255),
          [2] = RGB(0, 150, 255),
          [3] = RGB(0, 255, 0),
          [4] = RGB(255, 105, 0),
          [5] = RGB(255, 0, 0),
        },
        MAGE = {
          [1] = RGB(105, 204, 240),
          [2] = RGB(105, 204, 240),
          [3] = RGB(105, 204, 240),
          [4] = RGB(105, 204, 240),
        },
        MONK = {
          [1] = RGB(0, 225, 255), -- Cyan
          [2] = RGB(0, 225, 255),
          [3] = RGB(0, 225, 255),
          [4] = RGB(0, 225, 255),
          [5] = RGB(0, 225, 255),
          [6] = RGB(0, 225, 255),
        },
        PALADIN = {
          [1] = RGB(255, 255, 0),
          [2] = RGB(255, 255, 0),
          [3] = RGB(255, 255, 0),
          [4] = RGB(255, 255, 0),
          [5] = RGB(255, 255, 0),
        },
        ROGUE = {
          [1] = RGB(0, 0, 255),
          [2] = RGB(0, 150, 255),
          [3] = RGB(0, 255, 0),
          [4] = RGB(255, 105, 0),
          [5] = RGB(255, 0, 0),
          [6] = RGB(255, 0, 0),
        },
        WARLOCK = {
          [1] = RGB(148, 130, 201),
          [2] = RGB(148, 130, 201),
          [3] = RGB(148, 130, 201),
          [4] = RGB(148, 130, 201),
          [5] = RGB(148, 130, 201),
        },
      },
      RuneCooldown = {
        Show = true,
        HorizontalOffset = 1,
        VerticalOffset = 0,
        Font = {
          Typeface = Addon.DEFAULT_FONT,
          Size = 10,
          flags = "OUTLINE",
          Shadow = true,
        },
      },
    },
    socialWidget = {
      ON = true,
      scale = 16,
      x = 65,
      y = 6,
      x_hv = 65,
      y_hv = 6,
      --anchor = "Top",
      ShowInHeadlineView = true,
      ShowFriendIcon = true,
      ShowFactionIcon = false,
      ShowFriendColor = false,
      FriendColor = RGB(29, 39, 61),      -- Blizzard friend dark blue, color for healthbars of friends
      ShowGuildmateColor = false,
      GuildmateColor = RGB(60, 168, 255), -- light blue, color for healthbars of guildmembers
    },
    FactionWidget = {
      --ON = false,
      scale = 16,
      x = 0,
      y = 28,
      x_hv = 0,
      y_hv = 20,
      --anchor = "Top",
    },
    questWidget = {
      ON = false, -- old default: false
      scale = 26,
      x = 0,
      y = 20,
      x_hv = 0,
      y_hv = 20,
      alpha = 1,
      anchor = "CENTER",
      ModeHPBar = false, -- old default: true
      ModeIcon = true,
      HPBarColor = RGB(218, 165, 32), -- Golden rod
      ColorPlayerQuest = RGB(255, 215, 0), -- Golden
      ColorGroupQuest = RGB(32, 217, 114), -- See green-ish
      IconTexture = "QUESTICON",
      HideInCombat = false,
      HideInCombatAttacked = true,
      HideInInstance = true,
      ShowInHeadlineView = false,
      ShowProgress = true,
      Font = Addon.DEFAULT_FONT,
      FontSize = 3
    },
    stealthWidget = {
      ON = false,
      scale = 28,
      x = 0,
      y = 0,
      alpha = 1,
      anchor = "CENTER",
      ShowInHeadlineView = false,
    },
    ResourceWidget  = {
      ON = true,
      --ShowInHeadlineView = false,
      --scale = 28,
      x = 0,
      y = -18,
      ShowFriendly = false,
      ShowEnemyPlayer = false,
      ShowEnemyNPC = false,
      ShowEnemyBoss = true,
      ShowOnlyAltPower = true,
      ShowBar = true,
      BarHeight = 12,
      BarWidth = 80,
      BarTexture = "Smooth", -- old default: "Aluminium"
      BackgroundUseForegroundColor = false,
      BackgroundColor = RGB(0, 0, 0, 0.3),
      BorderTexture = "ThreatPlatesBorder",
      BorderEdgeSize = 1,
      BorderOffset = 1,
      BorderUseForegroundColor = false,
      BorderUseBackgroundColor = false,
      BorderColor = RGB(0, 0, 0, 1),
      --BorderInset = 4,
      --BorderTileSize = 16,
      ShowText = true,
      Font = Addon.DEFAULT_FONT,
      FontSize = 10,
      FontColor = RGB(255, 255, 255),
    },
    BossModsWidget = {
      ON = true,
      ShowInHeadlineView = true,
      x = 0,
      y = 66,
      x_hv = 0,
      y_hv = 40,
      scale = 30,
      AuraSpacing = 4,
      Font = Addon.DEFAULT_FONT,
      FontSize = 24,
      FontColor = RGB(255, 255, 255),
      -- TODO: add font flags like for custom text
      --ShowTrackingLine = true, -- Removed in 9.1.9
      --TrackingLineThickness = 4  -- Removed in 9.1.9
    },
--    TestWidget = {
--      ON = true,
--      BarWidth = 120,
--      BarHeight = 10,
--      BarTexture = "Smooth",
--      BorderTexture = "TP_Border_1px",
--      BorderBackground = "ThreatPlatesEmpty",
--      EdgeSize = 5,
--      Offset = 5,
--      Inset = 5,
--      Scale = 1,
--    },
    PersonalNameplate = {
      HideBuffs = false,
      ShowResourceOnTarget = false,
    },
    totemSettings = GetDefaultTotemSettings(),
    uniqueSettings = {
      ["**"] = {
        Trigger = {
          Type = "Name",
          Name = {
            Input = "<Enter name here>",
            AsArray = {}, -- Generated after entering Input with Addon.Split
          },
          Aura = {
            Input = "",
            AsArray = {}, -- Generated after entering Input with Addon.Split
          },
          Cast = {
            Input = "",
            AsArray = {}, -- Generated after entering Input with Addon.Split
          },
        },
        Effects = {
          Glow = {
            Frame = "None",
            Type = "Pixel",
            CustomColor = false,
            Color = { 0.95, 0.95, 0.32, 1 },
          },
        },
        showNameplate = true,
        ShowHeadlineView = false,
        Enable = {
          Never = false,
          UnitReaction = {
            FRIENDLY = true,
            NEUTRAL = true,
            HOSTILE = true,
          },
        },
        showIcon = true,
        useStyle = true,
        useColor = true,
        UseThreatColor = false,
        UseThreatGlow = false,
        allowMarked = true,
        overrideScale = false,
        overrideAlpha = false,
        UseAutomaticIcon = true,
        -- AutomaticIcon = "number",
        icon = "INV_Misc_QuestionMark.blp",
        -- SpellID = "number",
        -- SpellName = "string",
        scale = 1,
        alpha = 1,
        color = {
          r = 1,
          g = 1,
          b = 1,
        },
      },
	  {
		Trigger = {
		  Type = "Name",
          Name = {
            Input = "炸藥",
            AsArray = {"炸藥",},
          },
        },
		Enable = {
		  UnitReaction = {
		    FRIENDLY = false,
		  },
		},
		name = "炸藥",
		showIcon = false,
		useColor = false,
		overrideAlpha = false,
		scale = 1.5,
	  },
	  {
		scale = 1.2,
		showIcon = false,
		useColor = true,
		Trigger = {
		  Type = "Aura",
		  Name = {
		    Input = "",
		  },
		  Aura = {
		    Input = "狂怒;激勵",
			AsArray = {
				"狂怒",
				"激勵",
			},
		  },
		},
		overrideAlpha = true,
		color = {
		  g = 0.5019607843137255,
		  b = 0,
		},
		Enable = {
		  UnitReaction = {
			FRIENDLY = false,
		  },
		},
		allowMarked = false,
	  },
    },
    CVarsBackup = {}, -- Backup for CVars that should be restored when TP is disabled
    settings = {
      frame = {
        x = 0,
        y = 0,
        width = 110,
        height = 45,
        SyncWithHealthbar = true,
      },
      highlight = {
        -- texture = "TP_HealthBarHighlight", -- removed in 8.7.0
        show = true,
      },
      elitehealthborder = {
        texture = "TP_EliteBorder_Default",
        show = false, -- old default: true
      },
      healthborder = {
        texture = "TP_Border_Thin", -- old default: "TP_HealthBarOverlay",
        backdrop = "",
        EdgeSize = 1,
        Offset = 1,
        show = true,
      },
      threatborder = {
        show = true,
      },
      healthbar = {
        width = 100,
        height = 8,
        texture = "Smooth", -- old default: "ThreatPlatesBar",
        backdrop = "Smooth", -- old default: "ThreatPlatesEmpty",
        BackgroundUseForegroundColor = false,
        BackgroundOpacity = 0.7, -- old default: 1,
        BackgroundColor = RGB(0, 0, 0),
        ShowHealAbsorbs = true,
        ShowAbsorbs = true,
        AbsorbColor = RGB(0, 255, 255, 1),
        AlwaysFullAbsorb = false,
        OverlayTexture = true,
        OverlayColor = RGB(0, 128, 255, 1),
      },
      castnostop = {
        show = true,
        ShowOverlay = true,
        ShowInterruptShield = true,
      },
      castborder = {
        texture = "TP_Castbar_Border_Thin", -- old default: "TP_CastBarOverlay",
        EdgeSize = 1,
        Offset = 1,
        show = true,
      },
      castbar = {
        width = 104,
        height = 8,
        texture = "Smooth", -- old default: "ThreatPlatesBar",
        backdrop = "Smooth",
        BackgroundUseForegroundColor = false,
        BackgroundOpacity = 0.3,
        BackgroundColor = RGB(0, 0, 0),
        x = 0,
        y = 14,
        x_hv = 0,
        y_hv = 14,
        x_target = 0,
        y_target = 0,
        show = true,
        ShowInHeadlineView = false,
        ShowSpark = true,
        ShowCastTime = true,
        SpellNameText = {
          HorizontalOffset = 8,
          VerticalOffset = 0,
        },
        CastTimeText = {
          HorizontalOffset = -2,
          VerticalOffset = 0,
          Font = {
            HorizontalAlignment = "RIGHT",
            VerticalAlignment = "CENTER",
          },
        },
      },
      name = { -- Names for Healthbar View
        show = true,
        typeface = Addon.DEFAULT_FONT, -- old default: "Accidental Presidency",
        size = 11, -- old default: 14
        shadow = true,
        flags = "NONE",
        width = 140, -- old default: 116,
        height = 14,
        x = 0,
        y = 13,
        align = "CENTER",
        vertical = "CENTER",
        --
        EnemyTextColorMode = "CUSTOM",
        EnemyTextColor = RGB(255, 255, 255),
        FriendlyTextColorMode = "CUSTOM",
        FriendlyTextColor = RGB(255, 255, 255),
        UseRaidMarkColoring = false,
      },
      level = {
        typeface = Addon.DEFAULT_FONT, -- old default: "Accidental Presidency",
        size = 9, -- old default: 12,
        width = 20,
        height = 10, -- old default: 14,
        x = 49, -- old default: 50,
        y = 0,
        align = "RIGHT",
        vertical = "CENTER", -- old default: "TOP",
        shadow = true,
        flags = "NONE",
        show = false,
      },
      eliteicon = {
        show = true,
        theme = "default",
        scale = 16,
        x = -58, -- old default: 64
        y = 1, -- old default: 9
        level = 22,
        anchor = "CENTER"
      },
      customtext = {
        typeface = Addon.DEFAULT_FONT, -- old default: "Accidental Presidency",
        size = 9, -- old default: 12,
        width = 110,
        height = 14,
        x = 0,
        y = 0, -- old default: 1,
        align = "CENTER",
        vertical = "CENTER",
        shadow = true,
        flags = "NONE",
        --
        FriendlySubtext = "HEALTH",
        EnemySubtext = "HEALTH",
        SubtextColorUseHeadline = false,
        SubtextColorUseSpecific = false,
        SubtextColor =  RGB(255, 255, 255, 1),
      },
      spelltext = {
        typeface = Addon.DEFAULT_FONT, -- old default: "Accidental Presidency",
        size = 11,  -- old default: 12
        width = 110,
        height = 14,
        -- x = 0,       -- Removed in 9.2.0
        -- y = -15,     -- Removed in 9.2.0 -- old default: -13
        -- x_hv = 0,    -- Removed in 9.2.0
        -- y_hv = -20,  -- Removed in 9.2.0 -- old default: -13
        align = "LEFT",
        vertical = "CENTER",
        shadow = true,
        flags = "OUTLINE",
        show = true,
      },
      raidicon = {
        scale = 20,
        x = -62,
        y = 0, -- old default: 27
        x_hv = 0,
        y_hv = 25,
        anchor = "CENTER",
        hpColor = false,
        show = true,
        ShowInHeadlineView = true,
        hpMarked = {
          ["STAR"] = RGB_P(0.85, 0.81, 0.27),
          ["MOON"] = RGB_P(0.60, 0.75, 0.85),
          ["CIRCLE"] = RGB_P(0.93, 0.51,0.06),
          ["SQUARE"] = RGB_P(0, 0.64, 1),
          ["DIAMOND"] = RGB_P(0.7, 0.06, 0.84),
          ["CROSS"] = RGB_P(0.82, 0.18, 0.18),
          ["TRIANGLE"] = RGB_P(0.14, 0.66, 0.14),
          ["SKULL"] = RGB_P(0.89, 0.83, 0.74),
        },
      },
      spellicon = {
        scale = 30,
        x = -70,
        y = 5,
        x_hv = -70,
        y_hv = 5,
        anchor = "CENTER",
        show = true,
      },
      customart = {
        scale = 22,
        x = -74,
        y = -7,
        anchor = "CENTER",
        show = true,
      },
      skullicon = {
        scale = 12,
        x = -69, -- old default: 55
        y = 0,
        anchor = "CENTER",
        show = true,
      },
      unique = {
        threatcolor = {
          LOW = RGB_P(0, 0, 0, 0),
          MEDIUM = RGB_P(0, 0, 0, 0),
          HIGH = RGB_P(0, 0, 0, 0),
        },
      },
      totem = {
        threatcolor = {
          LOW = RGB_P(0, 0, 0, 0),
          MEDIUM = RGB_P(0, 0, 0, 0),
          HIGH = RGB_P(0, 0, 0, 0),
        },
      },
      normal = {
        threatcolor = {
          LOW = RGB_P(1, 1, 1, 1),
          MEDIUM = RGB_P(1, 1, 0, 1),
          HIGH = RGB_P(1, 0, 0, 1),
        },
      },
      dps = {
        threatcolor = {
          LOW = RGB_P(0, 1, 0, 1),
          MEDIUM = RGB_P(1, 1, 0, 1),
          HIGH = RGB_P(1, 0, 0, 1),
        },
      },
      tank = {
        threatcolor = {
          LOW = RGB_P(1, 0, 0, 1),
          MEDIUM = RGB_P(1, 1, 0, 1),
          HIGH = RGB_P(0, 1, 0, 1),
          OFFTANK = RGB(15, 170, 200, 1),
        },
      },
    },
    threat = {
      ON = true,
      -- marked = false, -- not used at all, removed in 9.2.0
      -- nonCombat = true, -- removed in 9.1.3
      UseThreatTable = false,
      UseHeuristicInInstances = false,
      -- hideNonCombat = false, -- no longer used, removed in 9.1.3
      useType = true,
      useScale = true,
      AdditiveScale = true,
      useAlpha = true,
      AdditiveAlpha = true,
      useHPColor = true,
      art = {
        ON = true,
        theme = "default",
      },
      --        scaleType = {
      --          ["Normal"] = -0.2,
      --          ["Elite"] = 0,
      --          ["Boss"] = 0.2,
      --          ["Minus"] = -0.2,
      --        },
      toggle = {
        ["Boss"]	= true,
        ["Elite"]	= true,
        ["Normal"]	= true,
        ["Neutral"]	= true,
        ["Minus"] 	= true,
        ["Tapped"] 	= true,
        ["OffTank"] = true,
        ["InstancesOnly"] = false,
      },
      dps = {
        scale = {
          LOW 		= -0.2,
          MEDIUM		= -0.1,
          HIGH 		= 0, -- old default: 1.25,
        },
        alpha = {
          LOW 		= 1,
          MEDIUM		= 1,
          HIGH 		= 1
        },
      },
      tank = {
        scale = {
          LOW 		= 0, -- old default: 1.25,
          MEDIUM		= -0.1,
          HIGH 		= -0.2,
          OFFTANK = -0.2
        },
        alpha = {
          LOW 		= 1,
          MEDIUM		= 1,
          HIGH 		= 1,
          OFFTANK = 1
        },
      },
      marked = {
        alpha = false,
        art = false,
        scale = false
      },
    },
    nameplate = {
      toggle = {
        ["Boss"]	= true,
        ["Elite"]	= true,
        ["Normal"]	= true,
        ["Neutral"]	= true,
        ["Minus"]	= true,
        ["Tapped"] 	= true,
        ["TargetA"]  = false,   -- Target Alpha
        ["NonTargetA"]	= true, -- Non-Target Alpha
        ["NoTargetA"]  = false, -- No Target Alpha
        ["TargetS"]  = true,   -- Target Scale
        ["NonTargetS"]	= true, -- Non-Target Scale
        ["NoTargetS"]  = false, -- No Target Scale
        ["MarkedA"] = false,
        ["MarkedS"] = false,
        ["CastingUnitAlpha"] = false, -- Friendly Unit Alpha
        ["CastingEnemyUnitAlpha"] = false,
        ["CastingUnitScale"] = false, -- Friendly Unit Scale
        ["CastingEnemyUnitScale"] = false,
        ["MouseoverUnitAlpha"] = false,
        ["MouseoverUnitScale"] = false,
        OccludedUnits        = true,
      },
      scale = {
        AbsoluteTargetScale  = false,
        ["Target"]	  	     = 0.1,
        ["NonTarget"]	       = -0.1,
        ["NoTarget"]	       = 0,
        ["Totem"]		         = 0.75,
        ["Marked"] 		       = 1.3,
        --["Normal"]		     = 1,
        ["CastingUnit"]      = 1.3,  -- Friendly Unit Scale
        ["CastingEnemyUnit"] = 1.3,
        ["MouseoverUnit"]    = 1.3,
        ["FriendlyPlayer"]   = 1,
        ["FriendlyNPC"]      = 1,
        ["Neutral"]		       = 0.9,
        ["EnemyPlayer"]      = 1,
        ["EnemyNPC"]         = 1,
        ["Elite"]		         = 1.04,
        ["Boss"]		         = 1.1,
        ["Guardian"]         = 0.75,
        ["Pet"]              = 0.75,
        ["Minus"]	           = 0.6,
        ["Tapped"] 		       = 0.9,
      },
      alpha = {
        AbsoluteTargetAlpha  = false,
        ["Target"]		       = 1,
        ["NonTarget"]	       = 0.7,
        ["NoTarget"]	       = 1,
        ["Totem"]		         = 1,
        ["Marked"] 		       = 1,
        --["Normal"]		     = 1,
        ["CastingUnit"]	     = 1,  -- Friendly Unit Alpha
        ["CastingEnemyUnit"] = 1,
        ["MouseoverUnit"]	   = 1,
        ["FriendlyPlayer"]   = 1,
        ["FriendlyNPC"]      = 1,
        ["Neutral"]		       = 1,
        ["EnemyPlayer"]      = 1,
        ["EnemyNPC"]         = 1,
        ["Elite"]		         = 1,
        ["Boss"]		         = 1,
        ["Guardian"]         = 0.8,
        ["Pet"]              = 0.8,
        ["Minus"]	           = 0.8,
        ["Tapped"]		       = 1,
        OccludedUnits        = 0.3,
      },
    },
    Transparency = {
      Fadeing = true,
    },
  }
}
