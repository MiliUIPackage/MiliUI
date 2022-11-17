local L = Exlist.L

-- CONSTANTS
local MAX_CHARACTER_LEVEL = 60
local MAX_PROFESSION_LEVEL = 150
if GetExpansionLevel() == 6 then
   MAX_CHARACTER_LEVEL = 110
   MAX_PROFESSION_LEVEL = 100
end
Exlist.constants.MAX_CHARACTER_LEVEL = MAX_CHARACTER_LEVEL
Exlist.constants.MAX_PROFESSION_LEVEL = MAX_PROFESSION_LEVEL

Exlist.activeTooltips = {}

Exlist.iconPaths = {
   -- [specId] = [[path]]
   [250] = [[Interface\AddOns\Exlist\Media\Icons\DEATHKNIGHTBlood.tga]],
   [251] = [[Interface\AddOns\Exlist\Media\Icons\DEATHKNIGHTFrost.tga]],
   [252] = [[Interface\AddOns\Exlist\Media\Icons\DEATHKNIGHTUnholy.tga]],
   [577] = [[Interface\AddOns\Exlist\Media\Icons\DEMONHUNTERHavoc.tga]],
   [581] = [[Interface\AddOns\Exlist\Media\Icons\DEMONHUNTERVengeance.tga]],
   [102] = [[Interface\AddOns\Exlist\Media\Icons\DRUIDBalance.tga]],
   [103] = [[Interface\AddOns\Exlist\Media\Icons\DRUIDFeral.tga]],
   [104] = [[Interface\AddOns\Exlist\Media\Icons\DRUIDGuardian.tga]],
   [105] = [[Interface\AddOns\Exlist\Media\Icons\DRUIDRestoration.tga]],
   [253] = [[Interface\AddOns\Exlist\Media\Icons\HUNTERBeastmastery.tga]],
   [254] = [[Interface\AddOns\Exlist\Media\Icons\HUNTERMarksmanship.tga]],
   [255] = [[Interface\AddOns\Exlist\Media\Icons\HUNTERSurvival.tga]],
   [62] = [[Interface\AddOns\Exlist\Media\Icons\MAGEArcane.tga]],
   [63] = [[Interface\AddOns\Exlist\Media\Icons\MAGEFire.tga]],
   [64] = [[Interface\AddOns\Exlist\Media\Icons\MAGEFrost.tga]],
   [268] = [[Interface\AddOns\Exlist\Media\Icons\MONKBrewmaster.tga]],
   [270] = [[Interface\AddOns\Exlist\Media\Icons\MONKMistweaver.tga]],
   [269] = [[Interface\AddOns\Exlist\Media\Icons\MONKWindwalker.tga]],
   [65] = [[Interface\AddOns\Exlist\Media\Icons\PALADINHoly.tga]],
   [66] = [[Interface\AddOns\Exlist\Media\Icons\PALADINProtection.tga]],
   [70] = [[Interface\AddOns\Exlist\Media\Icons\PALADINRetribution.tga]],
   [256] = [[Interface\AddOns\Exlist\Media\Icons\PRIESTDiscipline.tga]],
   [257] = [[Interface\AddOns\Exlist\Media\Icons\PRIESTHoly.tga]],
   [258] = [[Interface\AddOns\Exlist\Media\Icons\PRIESTShadow.tga]],
   [259] = [[Interface\AddOns\Exlist\Media\Icons\ROGUEAssasination.tga]],
   [260] = [[Interface\AddOns\Exlist\Media\Icons\ROGUEOutlaw.tga]],
   [261] = [[Interface\AddOns\Exlist\Media\Icons\ROGUESubtlety.tga]],
   [262] = [[Interface\AddOns\Exlist\Media\Icons\SHAMANElemental.tga]],
   [263] = [[Interface\AddOns\Exlist\Media\Icons\SHAMANEnhancement.tga]],
   [264] = [[Interface\AddOns\Exlist\Media\Icons\SHAMANRestoration.tga]],
   [265] = [[Interface\AddOns\Exlist\Media\Icons\WARLOCKAffliction.tga]],
   [266] = [[Interface\AddOns\Exlist\Media\Icons\WARLOCKDemonology.tga]],
   [267] = [[Interface\AddOns\Exlist\Media\Icons\WARLOCKDestruction.tga]],
   [71] = [[Interface\AddOns\Exlist\Media\Icons\WARRIORArms.tga]],
   [72] = [[Interface\AddOns\Exlist\Media\Icons\WARRIORFury.tga]],
   [73] = [[Interface\AddOns\Exlist\Media\Icons\WARRIORProtection.tga]],
   [0] = [[Interface\AddOns\Exlist\Media\Icons\SpecNone.tga]],
   [1467] = [[Interface\AddOns\Exlist\Media\Icons\EVOKERdevastation.tga]],
   [1468] = [[Interface\AddOns\Exlist\Media\Icons\EVOKERpreservation.tga]]
}

Exlist.ShortenedMPlus = {
   [197] = L["EoA"],
   [198] = L["DHT"],
   [199] = L["BRH"],
   [200] = L["HoV"],
   [206] = L["NL"],
   [207] = L["VotW"],
   [208] = L["MoS"],
   [209] = L["Arc"],
   [210] = L["CoS"],
   [227] = L["LKara"],
   [233] = L["CoEN"],
   [234] = L["UKara"],
   [239] = L["SotT"],
   -- BFA
   [244] = L["AD"], -- Atal'dazar
   [245] = L["FH"], -- Freehold
   [246] = L["TD"], -- Tol Dagor
   [247] = L["MOTHER"], -- The MOTHERLODE!!
   [248] = L["WM"], -- Waycrest Manor
   [249] = L["KR"], -- Kings' Rest
   [250] = L["ToS"], -- Temple of Sethraliss
   [251] = L["URot"], -- The Underrot
   [252] = L["SotS"], -- Shrine of the Storm
   [353] = L["SoB"], -- Siege of Boralus
   -- SL
   -- S4
   [370] = L["Work"], -- Workshop
   [391] = L["Streets"], -- Streets of Wonder
   [169] = L["ID"], -- Iron Docks
   [166] = L["GD"], -- Grimrail Depot
   [369] = L["Junk"], -- Junkyard
   [392] = L['Gambit'], -- Gambit
}

local Colors = {
   -- default colors
   questTitle = "ffffd200",
   missionName = "ffffd200",
   questTypeHeading = "ff42c8f4",
   faded = "ffc1c1c1",
   hardfaded = "ff494949",
   note = "fff4c842",
   sideTooltipTitle = "ffffd200",
   available = "ff00ff00",
   torghastAvailable = "ffffd200",
   completed = "ffff0000",
   incomplete = "fff49b42",
   notavailable = "fff49e42",
   enchantName = "ff98f907",
   debug = "ffc73000",
   debugTime = {
      short = "FF00FF00",
      medium = "ffe5f441",
      almostlong = "FFf48c42",
      long = "FFFF0000"
   },
   questTypeTitle = {daily = "ff70afd8", weekly = "ffe0a34e"},
   config = {
      heading1 = "ffffd200",
      heading2 = "ffffb600",
      tableColumn = "ffffd200"
   },
   time = {long = "fff44141", medium = "FFf4a142", short = "FF00FF00"},
   missions = {
      completed = "ff00ff00",
      inprogress = "FFf48642",
      available = "FFefe704"
   },
   mythicplus = {
      key = "ffd541e2",
      times = {
         "ffbfbfbf", -- depleted
         "fffaff00", -- +1
         "fffbdb00", -- +2
         "fffacd0c" -- +3
      }
   },
   covenant = {
      "ff0ad5f5", -- Kyrian
      "fff50a0a", -- Venthyr
      "ffb007e3", -- NightFae
      "ff00b837" -- Necrolord
   },
   ilvlColors = {
      -- Shadowlands --
      {ilvl = 200, str = "ff26ff3f"},
      {ilvl = 210, str = "ff26ffba"},
      {ilvl = 220, str = "ff26e2ff"},
      {ilvl = 230, str = "ff26a0ff"},
      {ilvl = 240, str = "ff2663ff"},
      {ilvl = 250, str = "ff8e26ff"},
      {ilvl = 260, str = "ffe226ff"},
      {ilvl = 270, str = "ffff2696"},
      {ilvl = 280, str = "ffff2634"},
      {ilvl = 290, str = "ffff7526"},
      {ilvl = 300, str = "ffffc526"}
   },
   profColors = {
      {val = 20, color = "c6c3b4"},
      {val = 30, color = "dbd3ab"},
      {val = 40, color = "e2d388"},
      {val = 50, color = "efd96b"},
      {val = 70, color = "ffe254"},
      {val = 90, color = "ffde3d"},
      {val = 110, color = "ffd921"},
      {val = 130, color = "ffd50c"},
      {val = 150, color = "ffae00"}
   },
   -- REPUTATION --
   repColors = {
      [1] = "ffe00000", -- Hated
      [2] = "ffff3700", -- Hostile
      [3] = "ffff8300", -- Unfriendly
      [4] = "ffffc300", -- Neutral
      [5] = "fff7ff20", -- Friendly
      [6] = "ff5fff20", -- Honored
      [7] = "ff2096ff", -- Revered
      [8] = "ffd220ff", -- Exiled
      [100] = "ffff20ca" -- Paragon
   },
   friendColors = {
      [1] = "ffff8300", -- Unfriendly
      [2] = "ffffc300", -- Neutral
      [3] = "fff7ff20", -- Friendly
      [4] = "ff5fff20", -- Honored
      [5] = "ff2096ff", -- Revered
      [6] = "ffd220ff", -- Exiled
      [100] = "ffff20ca" -- Paragon
   },
   paragonReward = "fff4f142"
}
Exlist.Colors = Colors

Exlist.Strings = {
   Note = string.format(
      "|T%s:15|t %s",
      [[Interface/MINIMAP/TRACKING/QuestBlob]],
      WrapTextInColorCode(L["Note!"], Colors.questTitle)
   )
}

Exlist.DEFAULT_BACKDROP = {
   bgFile = "Interface\\BUTTONS\\WHITE8X8.blp",
   edgeFile = "Interface\\BUTTONS\\WHITE8X8.blp",
   tile = false,
   tileSize = 0,
   edgeSize = 1,
   insets = {left = 0, right = 0, top = 0, bottom = 0}
}

Exlist.Expansions = {
   L["Vanilla"],
   L["The Burning Crusade"],
   L["Wrath of The Lich King"],
   L["Cataclysm"],
   L["Mists of Pandaria"],
   L["Warlords of Draenor"],
   L["Legion"],
   L["Battle for Azeroth"],
   L["Shadowlands"]
}

Exlist.OKMark = [[Interface/Addons/Exlist/Media/Icons/ok-icon]]
Exlist.CancelMark = [[Interface/Addons/Exlist/Media/Icons/cancel-icon]]
