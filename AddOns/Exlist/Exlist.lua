-- GLOBALS: Exlist Exlist_Db Exlist_Config
local addonName, addonTable = ...
local QTip = LibStub("LibQTip-1.0")
local LSM = LibStub("LibSharedMedia-3.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LDBI = LibStub("LibDBIcon-1.0")
-- SavedVariables localized
local db = {}
local config_db = {}
local debugMode = false
local debugString = "|cffc73000[Exlist Debug]|r"
local Exlist = Exlist
local L = Exlist.L
Exlist.debugMode = debugMode
Exlist.debugString = debugString
-- TOOLTIP --
local tooltipData = {
  --[[
  [character] = {
  [modules] = {
  [module] =  {
  data = {{},{},{}}
  priority = number
  name = string
  num = number
  }
  }
  num = number
  }
  ]]
  }
local tooltipColCoords = {
  --[[
  [character] = starting column
  ]]
  }
-- API --
local _G = _G
local CreateFrame, CreateFont = CreateFrame, CreateFont
local GetRealmName = GetRealmName
local UnitName = UnitName
local GetCVar = GetCVar
local GetMoney = GetMoney
local WrapTextInColorCode,SecondsToTime = WrapTextInColorCode, SecondsToTime
local UnitClass, UnitLevel = UnitClass, UnitLevel
local GetAverageItemLevel, GetSpecialization, GetSpecializationInfo = GetAverageItemLevel, GetSpecialization, GetSpecializationInfo
local C_Timer = C_Timer
local C_ArtifactUI = C_ArtifactUI
local HasArtifactEquipped = HasArtifactEquipped
local GetItemInfo,GetInventoryItemLink = GetItemInfo,GetInventoryItemLink
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local GetGameTime,GetTime,debugprofilestop = GetGameTime,GetTime,debugprofilestop
local InCombatLockdown = InCombatLockdown
local strsplit = strsplit
local UIParent, WorldMapFrame = UIParent, WorldMapFrame
local GetItemGem, UnitAura, GetTalentInfo, GetProfessions, GetProfessionInfo, IsInRaid = GetItemGem, UnitAura, GetTalentInfo, GetProfessions, GetProfessionInfo, IsInRaid
local GetScreenWidth, GetScreenHeight, GetCurrentRegion, CalendarGetDate, GetQuestResetTime = GetScreenWidth, GetScreenHeight, GetCurrentRegion, CalendarGetDate, GetQuestResetTime
local hooksecurefunc, SendChatMessage = hooksecurefunc, SendChatMessage
-- lua api
local tonumber = _G.tonumber
local next = next
local floor = _G.math.floor
local format = _G.format
local string = string
local strlen = strlen
local type,pairs,ipairs,table = type,pairs,ipairs,table
local print,select,date,math,time = print,select,date,math,time
local timer = Exlist.timers

-- CONSTANTS
local MAX_CHARACTER_LEVEL = 120
local MAX_PROFESSION_LEVEL = 150
if GetExpansionLevel() == 6 then
  MAX_CHARACTER_LEVEL = 110
  MAX_PROFESSION_LEVEL = 100
end
Exlist.CONSTANTS.MAX_CHARACTER_LEVEL = MAX_CHARACTER_LEVEL
Exlist.CONSTANTS.MAX_PROFESSION_LEVEL = MAX_PROFESSION_LEVEL

-- SETTINGS
LSM:Register("font","PT_Sans_Narrow",[[Interface\Addons\Exlist\Media\Font\font.ttf]])
local DEFAULT_BACKDROP = { bgFile = "Interface\\BUTTONS\\WHITE8X8.blp",
  edgeFile = "Interface\\BUTTONS\\WHITE8X8.blp",
  tile = false,
  tileSize = 0,
  edgeSize = 1,
  insets = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0 }}
local settings = { -- default settings
  minLevel = 80,
  fonts = {
    big = { size = 18},
    medium = { size = 16},
    small = { size = 14}
  },
  Font = "PT_Sans_Narrow",
  tooltipHeight = 600,
  delay = 0.2,
  iconScale = .8,
  tooltipScale = 1,
  allowedCharacters = {},
  reorder = true,
  characterOrder = {},
  orderByIlvl = false,
  allowedModules = {},
  lockIcon = false,
  iconAlpha = 1,
  backdrop = {
    color = {r = 0,g = 0, b = 0, a = .9},
    borderColor = {r = .2,b = .2,g = .2,a = 1}
  },
  currencies = {},
  worldQuests = {},
  wqRules = {
    money = {},
    currency = {},
    item = {},
    honor = {},
  },
  quests = {},
  extraInfoToggles = {},
  announceReset = true,
  showMinimapIcon = true,
  minimapTable = {},
  showIcon = false,
  horizontalMode = true,
  hideEmptyCurrency = false,
  showExtraInfoTooltip = true,
  shortenInfo = true,
  showCurrentRealm = false,
  showQuestsInExtra = false,
  unsortedFolder = {
    -- used to store vars that aren't connected to specific characters but need to be reset daily/weekly
    ["daily"] = {

    },
    ["weekly"] = {

    }
  },
  reputation = {
    cache = {},
    charOption = {},
    enabled = {},
  },
  azeriteWeekly = true,
}
local iconPaths = {
  --[specId] = [[path]]
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
  --BFA
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

}

local Colors = { --default colors
  questTitle = "ffffd200",
  missionName = "ffffd200",
  questTypeHeading = "ff42c8f4",
  faded = "ffc1c1c1",
  hardfaded = "ff494949",
  note = "fff4c842",
  sideTooltipTitle = "ffffd200",
  available = "ff00ff00",
  completed = "ffff0000",
  incomplete = "fff49b42",
  notavailable = "fff49e42",
  enchantName = "ff98f907",
  debug = "ffc73000",
  debugTime = {
    short = "FF00FF00",
    medium = "ffe5f441",
    almostlong = "FFf48c42",
    long = "FFFF0000",
  },
  questTypeTitle = {
    daily = "ff70afd8",
    weekly = "ffe0a34e"
  },
  config = {
    heading1 = "ffffd200",
    heading2 = "ffffb600",
    tableColumn = "ffffd200",
  },
  time = {
    long = "fff44141",
    medium = "FFf4a142",
    short = "FF00FF00"
  },
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
      "fffacd0c", -- +3
    }
  },
  ilvlColors = {
    -- BFA --
    {ilvl = 270 , str ="ff26ff3f"},
    {ilvl = 290 , str ="ff26ffba"},
    {ilvl = 300 , str ="ff26e2ff"},
    {ilvl = 320 , str ="ff26a0ff"},
    {ilvl = 340 , str ="ff2663ff"},
    {ilvl = 360 , str ="ff8e26ff"},
    {ilvl = 380 , str ="ffe226ff"},
    {ilvl = 400 , str ="ffff2696"},
    {ilvl = 420 , str ="ffff2634"},
    {ilvl = 440 , str ="ffff7526"},
    {ilvl = 460 , str ="ffffc526"},
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
    [100] = "ffff20ca", -- Paragon
  },
  paragonReward = "fff4f142",
}
Exlist.Colors = Colors

Exlist.Strings = {
  Note = string.format( "|T%s:15|t %s",[[Interface/MINIMAP/TRACKING/QuestBlob]],WrapTextInColorCode(L["Note!"],Colors.questTitle) ),
}

--[[ Module prio list
0 - mail
10 - currency
20 - raiderio
30 - azerite
40 - mythicKey
50 - mythicPlus
60 - coins
70 - emissary
80 - missions
90 - quests
95 - reputation
100 - raids
110 - dungeons
120 - worldbosses
130 - worldquests
10000 - note
]]
local butTool

-- fonts
local fontSet = settings.fonts
local font = LSM:Fetch("font",settings.Font)
local hugeFont = CreateFont("Exlist_HugeFont")
hugeFont:SetFont(font, fontSet.big.size)
hugeFont:SetTextColor(1,1,1)
local smallFont = CreateFont("Exlist_SmallFont")
smallFont:SetFont(font, fontSet.small.size)
smallFont:SetTextColor(1,1,1)
local mediumFont = CreateFont("Exlist_MediumFont")
mediumFont:SetFont(font, fontSet.medium.size)
mediumFont:SetTextColor(1,1,1)

local customFonts = {
  --[fontSize] = fontObject
  }
local monthNames = {L['January'], L['February'], L['March'], L['April'], L['May'], L['June'], L['July'], L['August'], L['September'], L['October'], L['November'], L['December']}

-- register events
local frame = CreateFrame("FRAME")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
--frame:RegisterEvent("Exlist_DELAY")

-- utility
local function spairs(t, order)
  -- collect the keys
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end

  -- if order function given, sort by it by passing the table and keys a, b,
  -- otherwise just sort the keys
  if order then
    table.sort(keys, function(a, b) return order(t, a, b) end)
  else
    table.sort(keys)
  end

  -- return the iterator function
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end
end

local function AddMissingTableEntries(data,DEFAULT)
  if not data or not DEFAULT then return data end
  local rv = data
  for k,v in pairs(DEFAULT) do
    if rv[k] == nil then
      rv[k] = v
    elseif type(v) == "table" then
      if type(rv[k]) == "table" then
        rv[k] = AddMissingTableEntries(rv[k],v)
      else
        rv[k] = AddMissingTableEntries({},v)
      end
    end
  end
  return rv
end
Exlist.AddMissingTableEntries = AddMissingTableEntries

local function ShortenNumber(number)
  if type(number) ~= "number" then
    number = tonumber(number)
  end
  if not number then
    return
  end

if number < 10000 then
		return number
	else
		return string.format("%.1f萬", number/10000)
	end

--[[
  local affixes = {
    "",
    "k",
    "m",
    "b",
    "t",
  }
  local affix = 1
  local dec = 0
  local num1 = math.abs(number)
  while num1 >= 1000 and affix < #affixes do
    num1 = num1 / 1000
    affix = affix + 1
  end
  if affix > 1 then
    dec = 2
    local num2 = num1
    while num2 >= 10 and dec > 0 do
      num2 = num2 / 10
      dec = dec - 1
    end
  end
  if number < 0 then
    num1 = -num1
  end

  return string.format("%."..dec.."f"..affixes[affix], num1)
--]]
end
Exlist.ShortenNumber = ShortenNumber
local function copyTableInternal(source, seen)
  if type(source) ~= "table" then return source end
  if seen[source] then return seen[source] end
  local rv = {}
  seen[source] = rv
  for k, v in pairs(source) do
    rv[copyTableInternal(k, seen)] = copyTableInternal(v, seen)
  end
  return rv
end

local function copyTable(source)
  return copyTableInternal(source, {})
end
Exlist.copyTable = copyTable

local function ConvertColor(color)
  return (color / 255)
end
Exlist.ConvertColor = ConvertColor

local function ColorHexToDec(hex)
  if not hex or strlen(hex) < 6 then return end
  local values = {}
  for i = 1, 6, 2 do
    table.insert(values, tonumber(string.sub(hex, i, i + 1), 16))
  end
  return (values[1]/ 255),(values[2]/ 255),(values[3]/ 255)
end
Exlist.ColorHexToDec = ColorHexToDec

local function ColorDecToHex(col1,col2,col3)
  col1 = col1 or 0
  col2 = col2 or 0
  col3 = col3 or 0
  local hexColor = string.format("%02x%02x%02x",col1*255,col2*255,col3*255)
  return hexColor
end
Exlist.ColorDecToHex = ColorDecToHex

local function TimeLeftColor(timeLeft, times, col)
  -- times (opt) = {red,orange} upper limit
  -- i.e {100,1000} = 0-100 Green 100-1000 Orange 1000-inf Green
  -- colors (opt) - colors to use
  times = times or {3600, 18000} --default
  local colors = col or {Colors.time.long, Colors.time.medium, Colors.time.short} -- default
  for i = 1, #times do
    if timeLeft < times[i] then
      return WrapTextInColorCode(SecondsToTime(timeLeft), colors[i])
    end
  end
  return WrapTextInColorCode(SecondsToTime(timeLeft), colors[#colors])
end
Exlist.TimeLeftColor = TimeLeftColor

-- To find quest name from questID
local MyScanningTooltip = CreateFrame("GameTooltip", "ExlistScanningTooltip", UIParent, "GameTooltipTemplate")

function MyScanningTooltip.ClearTooltip(self)
  local TooltipName = self:GetName()
  self:ClearLines()
  for i = 1, 10 do
    _G[TooltipName..'Texture'..i]:SetTexture(nil)
    _G[TooltipName..'Texture'..i]:ClearAllPoints()
    _G[TooltipName..'Texture'..i]:SetPoint('TOPLEFT', self)
  end
end

Exlist.QuestTitleFromID = setmetatable({}, { __index = function(t, id)
  MyScanningTooltip:ClearTooltip()
  MyScanningTooltip:SetOwner(UIParent, "ANCHOR_NONE")
  MyScanningTooltip:SetHyperlink("quest:"..id)
  local title = ExlistScanningTooltipTextLeft1:GetText()
  MyScanningTooltip:Hide()
  if title and title ~= RETRIEVING_DATA then
    t[id] = title
    return title
  end
end })

local function GetItemEnchant(itemLink)
  MyScanningTooltip:ClearTooltip()
  MyScanningTooltip:SetOwner(UIParent,"ANCHOR_NONE")
  MyScanningTooltip:SetHyperlink(itemLink)
  local enchantKey = ENCHANTED_TOOLTIP_LINE:gsub('%%s', '(.+)')
  for i=1,MyScanningTooltip:NumLines() do
    if _G["ExlistScanningTooltipTextLeft"..i]:GetText() and _G["ExlistScanningTooltipTextLeft"..i]:GetText():match(enchantKey) then
      -- name,id
      local name = _G["ExlistScanningTooltipTextLeft"..i]:GetText()
      name = name:match("^%w+: (.*)")
      local _,_,enchantId = strsplit(":",itemLink)
      return name, enchantId
    end
  end
end
Exlist.GetItemEnchant = GetItemEnchant
local function GetItemGems(itemLink)
  local t = {}
  for i=1,MAX_NUM_SOCKETS do
    local name,iLink = GetItemGem(itemLink,i)
    if iLink then
      local icon = select(10,GetItemInfo(iLink))
      table.insert(t,{name = name,icon = icon})
    end
  end
  MyScanningTooltip:ClearTooltip()
  MyScanningTooltip:SetOwner(UIParent,"ANCHOR_NONE")
  MyScanningTooltip:SetHyperlink(itemLink)
  for i=1,MAX_NUM_SOCKETS do
    local tex = _G["ExlistScanningTooltipTexture"..i]:GetTexture()
    if tex then
      tex = tostring(tex)
      if tex:find("Interface\\ItemSocketingFrame\\UI--Empty") then
        table.insert(t,{name = WrapTextInColorCode(L["Empty Slot"], Colors.faded),icon = tex})
      end
    end
  end
  return t
end
Exlist.GetItemGems = GetItemGems
local function QuestInfo(questid)
  if not questid or questid == 0 then return nil end
  MyScanningTooltip:ClearTooltip()
  MyScanningTooltip:SetOwner(UIParent,"ANCHOR_NONE")
  MyScanningTooltip:SetHyperlink("\124cffffff00\124Hquest:"..questid..":90\124h[]\124h\124r")
  local l = _G[MyScanningTooltip:GetName().."TextLeft1"]
  l = l and l:GetText()
  if not l or #l == 0 then return nil end -- cache miss
  return l, "\124cffffff00\124Hquest:"..questid..":90\124h["..l.."]\124h\124r"
end
Exlist.QuestInfo = QuestInfo

local function FormatTimeMilliseconds(time)
  if not time then return end
  local minutes = math.floor((time/1000)/60)
  local seconds = math.floor((time - (minutes*60000))/1000)
  local milliseconds = time-(minutes*60000)-(seconds*1000)
  return string.format("%02d:%02d:%02d",minutes,seconds,milliseconds)
end
Exlist.FormatTimeMilliseconds = FormatTimeMilliseconds

local function GetTimeLeftColor(time,inverse)
  if not time then return "ffffffff" end
  -- long
  -- long,medium,short
  local times = {18000,3600}
  local colorKeys = {"long","medium","short"}
  for i=1,#times do
    if time > times[i] then
      return inverse and Colors.time[colorKeys[4-i]] or Colors.time[colorKeys[i]]
    end
  end
  return inverse and Colors.time[colorKeys[1]] or Colors.time[colorKeys[3]]
end
Exlist.GetTimeLeftColor = GetTimeLeftColor

local function FormatTime(time)
  if not time then return "" end
  local days = math.floor (time/(60*60*24))
  time = time - days * (60*60*24)
  local hours = math.floor(time/(60*60))
  time = time - hours * (60*60)
  local minutes = math.floor((time)/60)
  local seconds = time%60
  if days > 0 then
    return string.format("%dd %02d:%02d:%02d",days,hours,minutes,seconds)
  elseif hours > 0 then
    return string.format("%02d:%02d:%02d",hours,minutes,seconds)
  end
  return string.format( "%02d:%02d",minutes,seconds )
end
Exlist.FormatTime = FormatTime

-- Originally by Asakawa but has been modified --
local sTextCache = {}
local function ShortenText(s,separator,full)
--[[
  wipe(sTextCache)
  sTextCache = {strsplit(" ",s)}
  separator = separator or "."
  local offset = full and 0 or 1
  for i = 1, #sTextCache-offset do
    sTextCache[i] = string.sub(sTextCache[i], 1, 1)
  end
  return table.concat(sTextCache, separator)
--]]
  return string.sub(s, 1, 6)
end
Exlist.ShortenText = ShortenText

local function GetTableNum(t)
  if type(t) ~= "table" then
    return 0
  end
  local count = 0
  for i in pairs(t) do
    count = count + 1
  end
  return count
end
Exlist.GetTableNum = GetTableNum

local function AuraFromId(unit,ID,filter)
  -- Already Preparing for BFA
  for i=1,40 do
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3 = UnitAura(unit,i,filter)
    if name then
      if spellId and spellId == ID then
        return name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3
      end
    else
      -- afaik auras always are in list w/o gaps ie 1,2,3,4,5,6 instead of 1,2,4,5,8...
      -- so can just break out of loop as soon
      -- as you don't find any aura
      return
    end
  end
end
Exlist.AuraFromId = AuraFromId

function Exlist.Debug(...)
  if debugMode then
    local debugString = string.format("|c%s[Exlist Debug]|r",Exlist.Colors.debug)
    print(debugString,...)
  end
end


--------------
local function AddMissingCharactersToSettings()
  settings.allowedCharacters = settings.allowedCharacters or {}
  local chars = settings.allowedCharacters
  for realm,v in pairs(db) do
    if realm ~= "global" then
      for name,values in pairs(v) do
        local charFullName = name .. "-" .. realm
        if not chars[charFullName] then
          chars[charFullName] = {
            enabled = true,
            name = name,
            order = 70,
            classClr = values.class and RAID_CLASS_COLORS[values.class].colorStr or name == UnitName("player") and RAID_CLASS_COLORS[select(2, UnitClass('player'))].colorStr or "FFFFFFFF",
            ilvl = values.iLvl or 0,
          }
        end
      end
    end
  end
end

local function AddModulesToSettings()
  if not settings.allowedModules then settings.allowedModules = {} end
  local t = settings.allowedModules
  local newT = {}
  for key,data in pairs(Exlist.ModuleData.modules) do
    if t[key] == nil then
      -- first time
      newT[key] = {enabled = data.defaultEnable, name = data.name}
    else
      newT[key] = t[key]
      newT[key].name = data.name
    end
  end
  settings.allowedModules = newT
end

local function UpdateChar(key,data,charname,charrealm)
  if not data then return end
  charrealm = charrealm or GetRealmName()
  charname = charname or UnitName('player')
  if not key then
    -- table is {key = value}
    db[charrealm] = db[charrealm] or {}
    db[charrealm][charname] = db[charrealm][charname] or {}
    local charToUpdate = db[charrealm][charname]
    for i, v in pairs(data) do
      charToUpdate[i] = v
    end
  else
    db[charrealm] = db[charrealm] or {}
    db[charrealm][charname] = db[charrealm][charname] or {}
    local charToUpdate = db[charrealm][charname]
    charToUpdate[key] = data
  end
end
Exlist.UpdateChar = UpdateChar

local function GetCachedItemInfo(itemId)
  if config_db.item_cache and config_db.item_cache[itemId] then
    return config_db.item_cache[itemId]
  else
    local name, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemId)
    local t = {name = name, texture = texture}
    if name and texture then
      -- only save if GetItemInfo actually gave info
      config_db.item_cache = config_db.item_cache or {}
      config_db.item_cache[itemId] = t
    end
    return t
  end
end
Exlist.GetCachedItemInfo = GetCachedItemInfo

local function GetCachedQuestTitle(questId)
  if config_db.quest_cache and config_db.quest_cache[questId] then
    return config_db.quest_cache[questId]
  else
    if type(questId) ~= "number" then
      return
    end
    local name = Exlist.QuestInfo(questId)
    if name then
      -- only save if you actually got info
      config_db.quest_cache = config_db.quest_cache or {}
      config_db.quest_cache[questId] = name
    end
    return name or "Unknown (" .. questId .. ")"
  end
end
Exlist.GetCachedQuestTitle = GetCachedQuestTitle

local function DeleteCharacterKey(name, realm, key)
  if not key or not db[realm] or not db[realm][name] then return end
  db[realm][name][key] = nil
end

local function WipeKey(key)
  -- ... yea
  -- if i need to delete 1 key info from all characters on all realms
  Exlist.Debug('wiped ' .. key)
  for realm in pairs(db) do
    for name in pairs(db[realm]) do
      for keys in pairs(db[realm][name]) do
        if keys == key then
          Exlist.Debug(' - wiping ',key, ' From:',name,'-',realm)
          db[realm][name][key] = nil
        end
      end
    end
  end
  Exlist.Debug(' Wiping Key (',key,') completed.')
end

local slotNames = {L["Head"],L["Neck"],L["Shoulders"],L["Shirt"],L["Chest"],L["Waist"],L["Legs"],L["Feet"],L["Wrists"],
  L["Hands"],L["Ring"],L["Ring"],L["Trinket"],L["Trinket"],L["Back"],L["Main Hand"],L["Off Hand"],L["Ranged"]}

local function UpdateCharacterGear()
  local t = {}
  local order = {1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17,18}
  for i=1,#order do
    local iLink = GetInventoryItemLink('player',order[i])
    if iLink then
      local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture, _ = GetItemInfo(iLink)
      local ilvl = GetDetailedItemLevelInfo(iLink)
      local relics = {}
      local enchant = GetItemEnchant(iLink)
      local gem = GetItemGems(iLink)
      table.insert(t,{slot = slotNames[order[i]], name = itemName,itemTexture = itemTexture, itemLink = itemLink,
        ilvl = ilvl, enchant = enchant, gem = gem})
    end
  end
  if HasArtifactEquipped() then
    for i=1,3 do
      local name,icon,slotTypeName,link = C_ArtifactUI.GetEquippedArtifactRelicInfo(i)
      if name then
        local ilvl = GetDetailedItemLevelInfo(link)
        table.insert(t,{slot = slotTypeName .. " "..L["Relic"], name = name,itemTexture = icon, itemLink = link,
          ilvl = ilvl})
      end
    end
  end
  UpdateChar("gear",t)
end

local function UpdateCharacterProfessions()
  local profIndexes = {GetProfessions()}
  local t = {}
  for i=1,#profIndexes do
    if profIndexes[i] then
      local name, texture, rank, maxRank = GetProfessionInfo(profIndexes[i])
      table.insert(t,{name=name,icon=texture,curr=rank,max=maxRank})
    end
  end
  Exlist.UpdateChar("professions",t)
end

local function UpdateCharacterSpecifics(event)
  if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
    UpdateCharacterGear()
  end
  UpdateCharacterProfessions()
  local name = UnitName('player')
  local level = UnitLevel('player')
  local _, class = UnitClass('player')
  local _, iLvl = GetAverageItemLevel()
  local specId, spec = GetSpecializationInfo(GetSpecialization())
  local realm = GetRealmName()
  local table = {}
  table.level = level
  table.class = class
  table.iLvl = iLvl
  table.spec = spec
  table.specId = specId
  table.realm = realm
  if settings.allowedCharacters[name..'-'..realm] then
    settings.allowedCharacters[name..'-'..realm].ilvl = iLvl
  end
  UpdateChar(nil,table,name,realm)
end

local function GetRealms()
  -- returns table with realm names and number of realms
  local realms = {}
  local n = 1
  for i in pairs(db) do
    if i ~= "global" then
      realms[n] = i
      n = n + 1
    end
  end
  local numRealms = #realms
  table.sort(realms, function(a, b) return GetTableNum(db[a]) > GetTableNum(db[b]) end)
  return realms, numRealms
end

local function GetRealmCharInfo(realm)
  if not db[realm] then return end
  local charInfo = {}
  local charNum = 0

  for char in pairs(db[realm]) do
    if not settings.allowedCharacters[char.."-"..realm] then AddMissingCharactersToSettings() end
    if settings.allowedCharacters[char.."-"..realm].enabled then
      charNum = charNum + 1
      charInfo[charNum] = {}
      charInfo[charNum].name = char
      for key, value in pairs(db[realm][char]) do
        charInfo[charNum][key] = value
      end
    end
  end
  table.sort(charInfo, function(a, b) return a.iLvl > b.iLvl end)
  return charInfo, charNum
end

local function GetPosition(frame)
  local screenWidth,screenHeight = GetScreenWidth(), GetScreenHeight()
  local x,y = frame:GetRect() -- from lower left
  local frameScale = frame:GetScale()
  x = x * frameScale
  y = y * frameScale
  local vPos,xPos
  if x > screenWidth/2 then
    xPos = "right"
  else
    xPos = "left"
  end
  if y > screenHeight/2 then
    vPos = "top"
  else
    vPos = "bottom"
  end
  return xPos,vPos
end

local function AttachStatusBar(frame)
  local statusBar = CreateFrame("StatusBar", nil, frame)
  statusBar:SetStatusBarTexture("Interface\\AddOns\\Exlist\\Media\\Texture\\statusBar")
  statusBar:GetStatusBarTexture():SetHorizTile(false)
  local bg = {
    bgFile = "Interface\\AddOns\\Exlist\\Media\\Texture\\statusBar"
  }
  statusBar:SetBackdrop(bg)
  statusBar:SetBackdropColor(.1, .1, .1, .8)
  statusBar:SetStatusBarColor(Exlist.ColorHexToDec("ffffff"))
  statusBar:SetMinMaxValues(0, 100)
  statusBar:SetValue(0)
  statusBar:SetHeight(5)
  --  print('createdNewStatusBar')
  return statusBar
end

-- Modules/API
-- Info attaching to tooltip
function Exlist.AddLine(tooltip,info,fontSize)
  -- info =  {'1st cell','2nd cell','3rd cell' ...} or "string"
  if not tooltip or not info or (type(info) ~= 'table' and type(info) ~= 'string') then return end
  -- Set Font
  fontSize = fontSize or settings.fonts.small.size
  local fontObj
  if customFonts[fontSize] then
    fontObj = customFonts[fontSize]
  else
    local font = LSM:Fetch("font",settings.Font)
    fontObj = CreateFont("Exlist_Font"..fontSize)
    fontObj:SetFont(font,fontSize)
    fontObj:SetTextColor(1,1,1)
    customFonts[fontSize] = fontObj
  end
  tooltip:SetFont(fontObj)

  local maxColumns = 5
  local n = tooltip:AddLine()
  if type(info) == 'string' then
    tooltip:SetCell(n,1,info,"LEFT",maxColumns-1)
  else
    for i=1,#info do
      if i<#info then
        tooltip:SetCell(n,i,info[i])
      else
        tooltip:SetCell(n,i,info[i],"LEFT",maxColumns-i)
      end
    end
  end
  -- return line number
  return n
end

local lineNums = {} -- only for Horizontal
local columnNums = {} -- only for Horizontal
local lastLineNum = 1 -- only for Horizontal
local lastColNum = -2 -- only for Horizontal
local function releasedTooltip() -- HIDING TOOLTIP
  lineNums = {} -- only for Horizontal
  columnNums = {} -- only for Horizontal
  lastLineNum = 1 -- only for Horizontal
  lastColNum = -2
end

function Exlist.AddData(info)
  --[[
  info = {
  data = "string" text to be displayed
  character = "name-realm" which column to display
  moduleName = "key" Module key
  priority = number Priority in tooltip
  titleName = "string" row title
  colOff = number (optional) offset from first column defaults:0
  dontResize = boolean (optional) if cell should span across
  pulseAnim = bool (optional) if cell should use pulse
  OnEnter = function (optional) script
  OnEnterData = {} (optional) scriptData
  OnLeave = function (optional) script
  OnLeaveData = {} (optional) scriptData
  OnClick = function (optional) script
  OnClickData = {} (optional) scriptData
  }
  ]]
  if not info then return end
  info.colOff = info.colOff or 0
  local char = info.character.name .. info.character.realm
  tooltipData[char] =  tooltipData[char] or {modules = {},num = 0}
  local t = tooltipData[char]
  if t.modules[info.moduleName] then
    table.insert(t.modules[info.moduleName].data,info)
    t.modules[info.moduleName].num = t.modules[info.moduleName].num + 1
  else
    if info.moduleName ~= "_Header" and info.moduleName ~= "_HeaderSmall" then
      t.num = t.num + 1
    end
    t.modules[info.moduleName] = {
      data  = {info},
      priority = info.priority,
      name = info.titleName,
      num = 1
    }
  end
end


function Exlist.AddToLine(tooltip,row,col,text)
  -- Add text to lines column
  if not tooltip or not row or not col or not text then return end
  tooltip:SetCell(row,col,text)
end

function Exlist.AddScript(tooltip,row,col,event,func,arg)
  -- Script for cell
  if not tooltip or not row or not event or not func then return end
  if col then
    tooltip:SetCellScript(row,col,event,func,arg)
  else
    tooltip:SetLineScript(row,event,func,arg)
  end
end

function Exlist.CreateSideTooltip(statusbar)
  -- Creates Side Tooltip function that can be attached to script
  -- statusbar(optional) {} {enabled = true, curr = ##, total = ##, color = 'hex'}
  local function a(self, info)
    -- info {} {body = {'1st lane',{'2nd lane', 'side number w/e'}},title = ""}
    local sideTooltip = QTip:Acquire("CharInf_Side", 2, "LEFT", "RIGHT")
    sideTooltip:SetScale(settings.tooltipScale or 1)
    self.sideTooltip = sideTooltip
    sideTooltip:SetHeaderFont(hugeFont)
    sideTooltip:SetFont(smallFont)
    sideTooltip:AddHeader(info.title or "")
    local body = info.body
    for i = 1, #body do
      if type(body[i]) == "table" then
        if body[i][3] then
          if body[i][3][1] == "header" then
            sideTooltip:SetHeaderFont(mediumFont)
            sideTooltip:AddHeader(body[i][1], body[i][2])
          elseif body[i][3][1] == "separator" then
            sideTooltip:AddLine(body[i][1], body[i][2])
            sideTooltip:AddSeparator(1,1,1,1,.8)
          elseif body[i][3][1] == "headerseparator" then
            sideTooltip:AddHeader(body[i][1], body[i][2])
            sideTooltip:AddSeparator(1,1,1,1,.8)
          end
        else
          sideTooltip:AddLine(body[i][1], body[i][2])
        end
      else
        sideTooltip:AddLine(body[i])
      end
    end
    local position,vPos = GetPosition(self:GetParent():GetParent():GetParent().parentFrame or
      self:GetParent():GetParent():GetParent())
    if position == "left" then
      sideTooltip:SetPoint("TOPLEFT", self:GetParent():GetParent():GetParent(), "TOPRIGHT",-1,0)
    else
      sideTooltip:SetPoint("TOPRIGHT", self:GetParent():GetParent():GetParent(), "TOPLEFT",1,0)
    end
    sideTooltip:Show()
    sideTooltip:SetClampedToScreen(true)
    local parentFrameLevel = self:GetFrameLevel(self)
    sideTooltip:SetFrameLevel(parentFrameLevel + 5)
    sideTooltip:SetBackdrop(DEFAULT_BACKDROP)
    local c = settings.backdrop
    sideTooltip:SetBackdropColor(c.color.r, c.color.g, c.color.b, c.color.a);
    sideTooltip:SetBackdropBorderColor(c.borderColor.r, c.borderColor.g, c.borderColor.b, c.borderColor.a)
    if statusbar then
      statusbar.total = statusbar.total or 100
      statusbar.curr = statusbar.curr or 0
      local statusBar = CreateFrame("StatusBar", nil, sideTooltip)
      self.statusBar = statusBar
      statusBar:SetStatusBarTexture("Interface\\AddOns\\Exlist\\Media\\Texture\\statusBar")
      statusBar:GetStatusBarTexture():SetHorizTile(false)
      local bg = {
        bgFile = "Interface\\AddOns\\Exlist\\Media\\Texture\\statusBar"
      }
      statusBar:SetBackdrop(bg)
      statusBar:SetBackdropColor(.1, .1, .1, .8)
      statusBar:SetStatusBarColor(Exlist.ColorHexToDec(statusbar.color))
      statusBar:SetMinMaxValues(0, statusbar.total)
      statusBar:SetValue(statusbar.curr)
      statusBar:SetWidth(sideTooltip:GetWidth() - 2)
      statusBar:SetHeight(5)
      statusBar:SetPoint("TOPLEFT", sideTooltip, "BOTTOMLEFT", 1, 0)
    end

  end
  return a
end

function Exlist.DisposeSideTooltip()
  -- requires to have saved side tooltip in tooltip.sideTooltip
  -- returns function that can be used for script
  return function(self)
    QTip:Release(self.sideTooltip)
    --  texplore(self)
    if self.statusBar then
      self.statusBar:Hide()
      self.statusBar = nil
    elseif self.sideTooltip.statusBars then
      for i=1,#self.sideTooltip.statusBars do
        local statusBar = self.sideTooltip.statusBars[i]
        if statusBar then
          statusBar:Hide()
          statusBar = nil
        end
      end
    end
    self.sideTooltip = nil
  end
end

local registeredEvents = {}
local function RegisterEvents()
  for event in pairs(Exlist.ModuleData.updaters) do
    if not registeredEvents[event] then
      xpcall(frame.RegisterEvent,function() return true end,frame,event)
      registeredEvents[event] = true
    end
  end
end

function Exlist.RegisterModule(data)
  --[[
  data = table
  {
  enabled = bool (enabled/disabled by default)
  name = string (name of module)
  key = string (module key that will be used in db)
  linegenerator = func  (function that adds text to tooltip   function(tooltip,Exlist) ...)
  priority = numberr (data priority in tooltip lower>higher)
  updater = func (function that updates data in db)
  event = {} or string (table or string that contains events that triggers updater func)
  weeklyReset = bool (should this be reset on weekly reset)
  dailyReset = bool (should data for this reset every day)
  specialResetHandle = function (replaces just wiping table for this key)
  description = string
  override = bool (overrides user selection disable/enable module)
  init = function (function that will run at init)
  }
  ]]
  if not data then return end
  local mDB = Exlist.ModuleData
  -- add updater
  if data.updater and data.event then
    if type(data.event) == "table" then
      -- multiple events
      for i=1,#data.event do
        mDB.updaters[data.event[i]] = mDB.updaters[data.event[i]] or {}
        table.insert(mDB.updaters[data.event[i]], {
          func = data.updater,
          name = data.name,
          override = data.override,
          key = data.key,
        })
      end
    elseif type(data.event) == "string" then
      -- single event
      mDB.updaters[data.event] = mDB.updaters[data.event] or {}
      table.insert(mDB.updaters[data.event], {
        func = data.updater,
        name = data.name,
        override = data.override,
        key = data.key,
      })
    end
  end
  RegisterEvents()

  -- add line generator
  table.insert(mDB.lineGenerators,{
    name = data.name,
    func = data.linegenerator,
    prio = data.priority,
    key = data.key,
    type = "main",
  })
  if data.globallgenerator then
    table.insert(mDB.lineGenerators,{
      name=data.name,
      func = data.globallgenerator,
      prio=data.priority,
      key=data.key,
      type = "global",
    })
  end
  -- Add module data
  mDB.modules[data.key] = {
    name = data.name,
    defaultEnable = data.enabled == nil or data.enabled,
    description = data.description or "",
    modernize = data.modernize,
    init = data.init,
    events = data.event,
  }
  -- Reset Stuff
  mDB.resetHandle[data.key] = {
    weekly = data.weeklyReset,
    daily = data.dailyReset,
    handler = data.specialResetHandle,
  }
end

function Exlist.GetRealmNames()
  local t = {}
  for i in pairs(db) do
    if i ~= "global" then
      t[#t+1] = i
    end
  end
  return t
end

function Exlist.GetRealmCharacters(realm)
  local t = {}
  if db[realm] then
    for i in pairs(db[realm]) do
      t[#t+1] = i
    end
  end
  return t
end

function Exlist.GetCharacterTable(realm,name)
  local t = {}
  if db[realm] and db[realm][name] then
    t = db[realm][name]
  end
  return t
end

function Exlist.GetCharacterTableKey(realm,name,key)
  local t = {}
  if db[realm] and db[realm][name] and db[realm][name][key] then
    t = db[realm][name][key]
  end
  return t
end

function Exlist.CharacterExists(realm,name)
  if db[realm] and db[realm][name] then
    return true
  end
  return false
end

function Exlist.DeleteCharacterFromDB(name,realm)
  if db[realm] then
    db[realm][name] = nil
    settings.allowedCharacters[name.."-"..realm] = nil
    for i,char in ipairs(settings.characterOrder) do
      if char.name == name and char.realm == realm then
        settings.characterOrder[i] = nil
        settings.reorder = true
        break
      end
    end
    print(debugString,L["Successfully deleted"],name.."-"..realm,".")
  else
    print(debugString,string.format(L["Deleting %s-%s failed."],name,realm))
  end
end

local function ModernizeCharacters()
  for key,data in pairs(Exlist.ModuleData.modules) do
    if data.modernize then
      for realm in pairs(db) do
        if realm ~= "global" then
          for character in pairs(db[realm]) do
            if db[realm][character][key] then
              db[realm][character][key] = data.modernize(db[realm][character][key])
            end
          end
        end
      end
    end
  end
end

local function GetCharacterOrder()
  if not settings.reorder then
    return settings.characterOrder
  end
  local t ={}
  for i,v in pairs(settings.allowedCharacters) do
    if v.enabled then
      if settings.orderByIlvl then
        table.insert(t,{name = v.name,realm = i:match("^.*-(.*)"),ilvl = v.ilvl or 0})
      else
        table.insert(t,{name = v.name,realm = i:match("^.*-(.*)"),order = v.order or 0})
      end
    end
  end
  if settings.orderByIlvl then
    table.sort(t,function(a,b) return a.ilvl>b.ilvl end)
  else
    table.sort(t,function(a,b) return a.order<b.order end)
  end
  settings.characterOrder = t
  settings.reorder = false
  return t
end


local function AddNote(tooltip,data,realm,name)
  if data.note then
    -- show note
    StaticPopupDialogs["DeleteNotePopup_"..name..realm] = {
      text = L["Delete Note?"],
      button1 = YES,
      button3 = CANCEL,
      hasEditBox = false,
      OnAccept = function()
        StaticPopup_Hide("DeleteNotePopup_"..name..realm)
        DeleteCharacterKey(name, realm, "note")
      end,
      timeout = 0,
      cancels = "DeleteNotePopup_"..name..realm,
      whileDead = true,
      hideOnEscape = false,
      preferredIndex = 4,
      showAlert = false
    }
    local lineNum = tooltip:AddLine(WrapTextInColorCode("Note:", "fff4c842"), data.note)
    tooltip:SetLineScript(lineNum, "OnMouseDown", function() StaticPopup_Show("DeleteNotePopup_"..name..realm) end)
  else
    -- Add note
    StaticPopupDialogs["AddNotePopup_"..name..realm] = {
      text = L["Add Note"],
      button1 = OKAY,
      button3 = CANCEL,
      hasEditBox = 1,
      editBoxWidth = 200,
      OnShow = function(self)
        self.editBox:SetText("")
      end,
      OnAccept = function(self)
        StaticPopup_Hide("AddNotePopup_"..name..realm)
        UpdateChar("note",self.editBox:GetText(),name,realm)
      end,
      timeout = 0,
      cancels = "AddNotePopup_"..name..realm,
      whileDead = true,
      hideOnEscape = false,
      preferredIndex = 4,
      showAlert = false,
      enterClicksFirstButton = 1
    }
    local lineNum = tooltip:AddLine(WrapTextInColorCode(L["Add Note"], "fff4c842"))
    tooltip:SetLineScript(lineNum, "OnMouseDown", function() StaticPopup_Show("AddNotePopup_"..name..realm) end)
  end
end

local function setIlvlColor(ilvl)
  if not ilvl then return "ffffffff" end
  local colors = Colors.ilvlColors
  for i=1,#colors do
    if colors[i].ilvl > ilvl then
      return colors[i].str
    end
  end
  return "fffffb26"
end
local hasEnchantSlot = {
  Neck = true,
  Ring = true,
  Back = true
}
local function ProfessionValueColor(value,isArch)
  local colors = Colors.profColors
  local mod = isArch and 8 or 1
  for i=1,#colors do
    if value <= colors[i].val*mod then
      return colors[i].color
    end
  end
  return "FFFFFF"
end

local function GearTooltip(self,info)
  local geartooltip = QTip:Acquire("CharInf_GearTip",7,"CENTER","LEFT","LEFT","LEFT","LEFT","LEFT","LEFT")
  geartooltip.statusBars = {}

  geartooltip:SetScale(settings.tooltipScale or 1)
  self.sideTooltip = geartooltip
  geartooltip:SetHeaderFont(hugeFont)
  geartooltip:SetFont(smallFont)
  local fontName, fontHeight, fontFlags = geartooltip:GetFont()
  local specIcon = info.specId and iconPaths[info.specId] or iconPaths[0]
  -- character name header
  local header = "|T" .. specIcon ..":25:25|t "..
    "|c" .. RAID_CLASS_COLORS[info.class].colorStr .. info.name .. "|r " ..
    (info.level or 0) .. L[' level']
  local line = geartooltip:AddHeader()
  geartooltip:SetCell(line,1,header,"LEFT",3)
  geartooltip:SetCell(line,7,string.format("%i "..L["ilvl"],(info.iLvl or 0)),"CENTER")
  geartooltip:AddSeparator(1,.8,.8,.8,1)
  line = geartooltip:AddHeader()
  geartooltip:SetCell(line,1,WrapTextInColorCode(L["Gear"],Colors.sideTooltipTitle),"CENTER",7)
  local gear = info.gear
  if gear then
    for i=1,#gear do
      local enchantements = ""
      if gear[i].enchant or gear[i].gem then
        if type(gear[i].gem) == 'table' then
          if gear[i].enchant then
            enchantements = string.format("|c%s%s|r",Colors.enchantName,gear[i].enchant or "")
          end
          for b=1,#gear[i].gem do
            if enchantements ~= "" then
              enchantements = string.format("%s\n|T%s:20|t%s",enchantements,gear[i].gem[b].icon,gear[i].gem[b].name)
            else
              enchantements = string.format("|T%s:20|t%s",gear[i].gem[b].icon,gear[i].gem[b].name)
            end
          end
        end
      elseif hasEnchantSlot[gear[i].slot] then
        enchantements = WrapTextInColorCode(L["No Enchant!"],"ffff0000")
      end
      local line = geartooltip:AddLine(gear[i].slot)
      geartooltip:SetCell(line,2,string.format("|c%s%-5d|r",setIlvlColor(gear[i].ilvl),gear[i].ilvl or 0))
      geartooltip:SetCell(line,3,string.format("|T%s:20|t %s",gear[i].itemTexture or "",gear[i].itemLink or ""),"LEFT",2)
      geartooltip:SetFont(fontName, fontHeight and fontHeight-2 or 10, fontFlags)
      geartooltip:SetCell(line,5,enchantements,"LEFT",3)
      geartooltip:SetFont(smallFont)
    end
    geartooltip:AddSeparator(1,.8,.8,.8,1)
  end
  if info.professions and #info.professions > 0 then
    -- professsions
    line = geartooltip:AddHeader()
    geartooltip:SetCell(line,1,WrapTextInColorCode(L["Professions"],"ffffb600"),"CENTER",7)
    local p = info.professions
    local tipWidth = geartooltip:GetWidth()
    for i=1,#p do
      line = geartooltip:AddLine()
      local isArch = p[i].name == L["Archaeology"]
      geartooltip:SetCell(line,1,string.format("|T%s:20|t%s",p[i].icon,p[i].name),"LEFT")
      geartooltip:SetCell(line,2,"","LEFT",5) -- spacer for status bar
      geartooltip:SetCell(line,7,string.format("|cff%s%s|r",ProfessionValueColor(p[i].curr,isArch),p[i].curr),"CENTER")

      local statusBar = AttachStatusBar(geartooltip.lines[line].cells[2])
      table.insert(geartooltip.statusBars,statusBar)
      statusBar:SetMinMaxValues(0,isArch and 800 or MAX_PROFESSION_LEVEL)
      statusBar:SetValue(p[i].curr)
      statusBar:SetWidth(tipWidth)
      statusBar:SetStatusBarColor(Exlist.ColorHexToDec(ProfessionValueColor(p[i].curr,isArch)))
      statusBar:SetPoint("LEFT",geartooltip.lines[line].cells[2],5,0)
      statusBar:SetPoint("RIGHT",geartooltip.lines[line].cells[2],5,0)
    end
    geartooltip:AddSeparator(1,.8,.8,.8,1)
  end
  local line = geartooltip:AddLine(L["Last Updated:"])
  geartooltip:SetCell(line, 2,info.updated,"LEFT",3)
  local position,vPos = GetPosition(self:GetParent():GetParent():GetParent().parentFrame)
  if position == "left" then
    geartooltip:SetPoint("TOPLEFT", self:GetParent():GetParent():GetParent(), "TOPRIGHT",-1,0)
  else
    geartooltip:SetPoint("TOPRIGHT", self:GetParent():GetParent():GetParent(), "TOPLEFT",1,0)
  end
  geartooltip:Show()
  geartooltip:SetClampedToScreen(true)
  local parentFrameLevel = self:GetFrameLevel(self)
  geartooltip:SetFrameLevel(parentFrameLevel + 5)
  local backdrop = { bgFile = "Interface\\BUTTONS\\WHITE8X8.blp",
    edgeFile = "Interface\\BUTTONS\\WHITE8X8.blp",
    tile = false,
    tileSize = 0,
    edgeSize = 1,
    insets = {
      left = 0,
      right = 0,
      top = 0,
      bottom = 0 }}
  geartooltip:SetBackdrop(backdrop)
  local c = settings.backdrop
  geartooltip:SetBackdropColor(c.color.r, c.color.g, c.color.b, c.color.a);
  geartooltip:SetBackdropBorderColor(c.borderColor.r, c.borderColor.g, c.borderColor.b, c.borderColor.a)
  local tipWidth = geartooltip:GetWidth()
  for i=1,#geartooltip.statusBars do
    geartooltip.statusBars[i]:SetWidth(tipWidth+tipWidth/3)
  end
end

-- DISPLAY INFO
butTool = CreateFrame("Frame", "Exlist_Tooltip", UIParent)
local bg = butTool:CreateTexture("CharInf_BG", "HIGH")
butTool:SetSize(32, 32)
bg:SetTexture("Interface\\AddOns\\Exlist\\Media\\Icons\\logo")
bg:SetSize(32, 32)
butTool:SetScale(settings.iconScale)
bg:SetAllPoints()
local function SetTooltipBut()
  if not config_db.config then
    butTool:SetPoint("CENTER", UIParent, "CENTER", 200, - 50)
  else
    local point = config_db.config.point
    local relativeTo = config_db.config.relativeTo
    local relativePoint = config_db.config.relativePoint
    local xOfs = config_db.config.xOfs
    local yOfs = config_db.config.yOfs
    butTool:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
  end
end
butTool:SetFrameStrata("HIGH")
butTool:EnableMouse(true)
-- make icon draggable
butTool:SetMovable(true)
butTool:RegisterForDrag("LeftButton")
butTool:SetScript("OnDragStart", butTool.StartMoving)

local function Exlist_StopMoving(self)
  self:StopMovingOrSizing();
  self.isMoving = false;
  local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
  config_db.config = {
    point = point,
    relativePoint = relativePoint,
    xOfs = xOfs,
    yOfs = yOfs
  }
end

-- Animations --
local pulseLowAlpha = 0.4
local pulseDuration = 1.2
local pulseDelta = -(1 - pulseLowAlpha)
local function AnimPulse(self)
  self.startTime = self.startTime or GetTime()
  local nowTime = GetTime()
  local progress = mod((nowTime - self.startTime),pulseDuration)/pulseDuration
  local angle = (progress * 2 * math.pi) - (math.pi / 2)
  local finalAlpha =  1 + (((math.sin(angle) + 1)/2) * pulseDelta)
  self.fontString:SetAlpha(finalAlpha)
end

local function ClearFunctions(tooltip)
  if tooltip.animations then
    for _,frame in ipairs(tooltip.animations) do
      frame:SetScript("OnUpdate",nil)
      frame:SetAlpha(1)
    end
  end
end

local function PopulateTooltip(tooltip)
  -- Setup Tooltip (Add appropriate amounts of rows)
  tooltip.animations = {}
  local modulesAdded = {} -- for horizontal
  local moduleLine = {} -- for horizontal
  local charHeaderRows = {} -- for vertical
  local charOrder = GetCharacterOrder()
  for i=1,#charOrder do
    local character = charOrder[i].name .. charOrder[i].realm
    local t = tooltipData[character]
    if t then
      if settings.horizontalMode then
        for module,info in pairs(t.modules) do
          if not modulesAdded[module] and (module ~= "_Header" and module ~= "_HeaderSmall") then
            modulesAdded[module] = {prio=info.priority, name = info.name}
          end
        end
      else
        -- for vertical we add rows already because we need to know where to put seperator
        tooltip:AddHeader()
        local l = tooltip:AddLine()
        table.insert(charHeaderRows,l)
        for i=1,t.num do
          tooltip:AddLine()
        end
        if i ~= #charOrder then
          tooltip:AddSeparator(1, 1, 1, 1, .85)
        end
      end
    end
  end
  -- add rows for horizontal
  if settings.horizontalMode then
    tooltip:AddHeader()
    tooltip:AddLine()
    tooltip:AddSeparator(1, 1, 1, 1, .85)
    -- Add Module Texts
    for module,info in spairs(modulesAdded,function(t,a,b) return t[a].prio<t[b].prio end) do
      moduleLine[module] = tooltip:AddLine(info.name)
    end
  end

  -- Add Char Info
  local rowHeadNum = 2
  for i=1,#charOrder do
    local character = charOrder[i].name .. charOrder[i].realm
    if tooltipData[character] then
      local col = tooltipColCoords[character]
      local justification = settings.horizontalMode and "CENTER" or "LEFT"
      -- Add Headers
      local headerCol = settings.horizontalMode and col or 1
      local headerWidth = settings.horizontalMode and 3 or 4
      local header = tooltipData[character].modules["_Header"]
      local logoTexSize = settings.shortenInfo and "30:60" or "40:80"
      if settings.horizontalMode then
		-- 名字旁的裝等文字換行
        local headerText = settings.shortenInfo and header.data[1].data.."\n" .. header.data[2].data or header.data[1].data.."             " .. header.data[2].data
        tooltip:SetCell(1,1,"|T"..[[Interface/Addons/Exlist/Media/Icons/ExlistLogo2.tga]]..":".. logoTexSize .."|t","CENTER")
        tooltip:SetCell(rowHeadNum-1,headerCol,headerText,"CENTER",4)
        tooltip:SetCellScript(rowHeadNum-1,headerCol,"OnEnter",header.data[1].OnEnter,header.data[1].OnEnterData)
        tooltip:SetCellScript(rowHeadNum-1,headerCol,"OnLeave",header.data[1].OnLeave,header.data[1].OnLeaveData)
      else
        tooltip:SetCell(rowHeadNum-1,headerCol,header.data[1].data,"LEFT",headerWidth)
        tooltip:SetCell(rowHeadNum-1,headerCol+headerWidth,header.data[2].data,"RIGHT")
        tooltip:SetLineScript(rowHeadNum-1,"OnEnter",header.data[1].OnEnter,header.data[1].OnEnterData)
        tooltip:SetLineScript(rowHeadNum-1,"OnLeave",header.data[1].OnLeave,header.data[1].OnLeaveData)
      end
      local smallHeader = tooltipData[character].modules["_HeaderSmall"]
      tooltip:SetCell(rowHeadNum,headerCol,smallHeader.data[1].data,justification,4,nil,nil,nil,2000,settings.shortenInfo and 0 or 170)
      -- Add Module Data
      local offsetRow = 0
      local row = 0
      for module,info in spairs(tooltipData[character].modules,function(t,a,b) return t[a].priority<t[b].priority end) do
        if module ~= "_HeaderSmall" and module ~= "_Header" then
          offsetRow = offsetRow + 1
          -- Find Row
          if settings.horizontalMode then
            row = moduleLine[module]
          else
            row = rowHeadNum + offsetRow
            tooltip:SetCell(row,1,info.name) -- Add Module Name
          end
          -- how many rows should 1 data object take (Spread them out)
          local width = math.floor(4/info.num)
          local spreadMid = info.num == 3
          local offsetCol = 0
          -- Add Module Data
          for i=1,info.num do
            local data = info.data[i]
            local column = col + width*data.colOff
            if i == 2 and spreadMid then width = 2 end
            tooltip:SetCell(row,col + offsetCol,data.data,justification,width)
            -- ANIM TEST --
            if data.pulseAnim then
              local cell = tooltip.lines[row].cells[col + offsetCol]
              cell:SetScript("OnUpdate",AnimPulse)
              table.insert(tooltip.animations,cell)
              -- ANIM TEST --
            end
            if data.OnEnter then
              tooltip:SetCellScript(row,col + offsetCol,"OnEnter",data.OnEnter,data.OnEnterData)
            end
            if data.OnLeave then
              tooltip:SetCellScript(row,col + offsetCol,"OnLeave",data.OnLeave,data.OnLeaveData)
            end
            if data.OnClick then
              tooltip:SetCellScript(row,col + offsetCol,"OnMouseDown",data.OnClick,data.OnClickData)
            end
            offsetCol = offsetCol + width
            if i == 2 then width = 1 end
          end
        end
      end
      rowHeadNum = settings.horizontalMode and 2 or charHeaderRows[i+1]
    end
  end
  -- Color every second line for horizontal orientation
  if settings.horizontalMode then
    for i=4,tooltip:GetLineCount() do
      if i%2 == 0 then
        tooltip:SetLineColor(i,1,1,1,0.2)
      end
    end
  end
end

butTool:SetScript("OnDragStop", Exlist_StopMoving)

local function OnEnter(self)
  if QTip:IsAcquired("Exlist_Tooltip") then return end
  self:SetAlpha(1)
  tooltipData = {}
  local mDB = Exlist.ModuleData
  -- sort line generators
  table.sort(mDB.lineGenerators,function(a,b) return a.prio < b.prio end)

  local charOrder = GetCharacterOrder()
  local tmp = {}
  for i,char in ipairs(charOrder) do
    if not settings.showCurrentRealm or char.realm == GetRealmName() then
      tmp[#tmp+1] = char
    end
  end
  charOrder = tmp
  local tooltip
  if settings.horizontalMode then
    tooltip = QTip:Acquire("Exlist_Tooltip", (#charOrder*4)+1)
  else
    tooltip = QTip:Acquire("Exlist_Tooltip", 5)
  end
  tooltip.parentFrame = self
  tooltip:SetCellMarginV(3)
  tooltip:SetScale(settings.tooltipScale or 1)
  self.tooltip = tooltip

  tooltip:SetHeaderFont(mediumFont)
  tooltip:SetFont(smallFont)

  -- character info main tooltip
  for i=1,#charOrder do
    local name = charOrder[i].name
    local realm = charOrder[i].realm
    local character = {
      name = name,
      realm = realm
    }
    local charData = Exlist.GetCharacterTable(realm,name)
    charData.name = name
    -- header
    local specIcon = charData.specId and iconPaths[charData.specId] or iconPaths[0]
    local headerText,subHeaderText = "",""
    if settings.shortenInfo then

      headerText = "|c" .. RAID_CLASS_COLORS[charData.class].colorStr .. name .. "|r "
	  -- 等級文字換行
      -- subHeaderText = string.format("|c%s%s",Colors.sideTooltipTitle,realm)
	  subHeaderText = string.format("|c%s%s\n"..L["Level"] .." %i",Colors.sideTooltipTitle,realm,charData.level)

    else
      headerText = "|T" .. specIcon ..":25:25|t ".. "|c" .. RAID_CLASS_COLORS[charData.class].colorStr .. name .. "|r "
      subHeaderText = string.format("|c%s%s - "..L["Level"] .." %i",Colors.sideTooltipTitle,realm,charData.level)
    end
    -- Header Info
    Exlist.AddData({
      data = headerText,
      character = character,
      priority = -1000,
      moduleName = "_Header",
      titleName = "Header",
      OnEnter = GearTooltip,
      OnEnterData = charData,
      OnLeave = Exlist.DisposeSideTooltip()

    })
    Exlist.AddData({
      data = string.format("%i 物品等級", charData.iLvl or 0),
      character = character,
      priority = -1000,
      moduleName = "_Header",
      titleName = "Header",
    })
    Exlist.AddData({
      data = subHeaderText,
      character = character,
      priority = -999,
      moduleName = "_HeaderSmall",
      titleName = "Header",
      OnEnter = GearTooltip,
      OnEnterData = charData,
      OnLeave = Exlist.DisposeSideTooltip()
    })


    local col = settings.horizontalMode and ((i-1)*4)+2 or 2
    tooltipColCoords[name..realm] = col

    -- Add Info
    for _,data in ipairs(mDB.lineGenerators) do
      if settings.allowedModules[data.key].enabled and data.type == "main" then
        xpcall(data.func,geterrorhandler(),tooltip,charData[data.key],character)
      end
    end
  end
  -- Add Data to tooltip
  PopulateTooltip(tooltip)
  -- global data
  if settings.showExtraInfoTooltip then
    local gData = db.global and db.global.global or nil
    if gData then
      local gTip = QTip:Acquire("Exlist_Tooltip_Global", 5, "LEFT", "LEFT", "LEFT", "LEFT","LEFT")
      gTip:SetScale(settings.tooltipScale or 1)
      gTip:SetFont(smallFont)
      tooltip.globalTooltip = gTip
      local added = false
      for _,data in ipairs(mDB.lineGenerators) do
        if settings.allowedModules[data.key].enabled and data.type == "global" then
          xpcall(data.func,geterrorhandler(),gTip,gData[data.key])
          added = true
        end
      end

      if added then
        local position,vpos = GetPosition(self)
        if position == "left" then
          if settings.horizontalMode then
            if vpos == "bottom" then
              gTip:SetPoint("BOTTOMLEFT",tooltip,"TOPLEFT",0,-1)
            else
              gTip:SetPoint("TOPLEFT",tooltip,"BOTTOMLEFT",0,1)
            end
          else
            gTip:SetPoint("BOTTOMLEFT",tooltip,"BOTTOMRIGHT")
          end
        else
          if settings.horizontalMode then
            if vpos == "bottom" then
              gTip:SetPoint("BOTTOMRIGHT",tooltip,"TOPRIGHT",0,-1)
            else
              gTip:SetPoint("TOPRIGHT",tooltip,"BOTTOMRIGHT",0,1)
            end
          else
            gTip:SetPoint("BOTTOMRIGHT",tooltip,"BOTTOMLEFT",1,0)
          end
        end
        gTip:Show()
        local parentFrameLevel = tooltip:GetFrameLevel(tooltip)
        gTip:SetFrameLevel(parentFrameLevel)
        gTip.parent = self
        gTip.time = 0
        gTip.elapsed = 0
        gTip:SetScript("OnUpdate",function(self, elapsed)
          self.time = self.time + elapsed
          if self.time > 0.1 then
            if self.parent:IsMouseOver() or tooltip:IsMouseOver() or self:IsMouseOver() then
              self.elapsed = 0
            else
              self.elapsed = self.elapsed + self.time
              if self.elapsed > settings.delay then
                QTip:Release(self)
              end
            end
            self.time = 0
          end
        end)
        gTip:SetBackdrop(DEFAULT_BACKDROP)
        local c = settings.backdrop
        gTip:SetBackdropColor(c.color.r, c.color.g, c.color.b, c.color.a);
        gTip:SetBackdropBorderColor(c.borderColor.r, c.borderColor.g, c.borderColor.b, c.borderColor.a)
      end
    end
  end

  -- Tooltip visuals
  tooltip:SmartAnchorTo(self)
  --tooltip:SetAutoHideDelay(settings.delay, self)
  tooltip.parent = self
  tooltip.time = 0
  tooltip.elapsed = 0
  tooltip:SetScript("OnUpdate",function(self, elapsed)
    self.time = self.time + elapsed
    if self.time > 0.1 then
      if self.globalTooltip and self.globalTooltip:IsMouseOver() or self:IsMouseOver() or self.parent:IsMouseOver() then
        self.elapsed = 0
      else
        self.elapsed = self.elapsed + self.time
        if self.elapsed > settings.delay then
          self.parent:SetAlpha(settings.iconAlpha or 1)
          releasedTooltip()
          ClearFunctions(self)
          QTip:Release(self)
        end
      end
      self.time = 0
    end
  end)
  tooltip:Show()
  tooltip:SetBackdrop(DEFAULT_BACKDROP)
  local c = settings.backdrop
  tooltip:SetBackdropColor(c.color.r, c.color.g, c.color.b, c.color.a);
  tooltip:SetBackdropBorderColor(c.borderColor.r, c.borderColor.g, c.borderColor.b, c.borderColor.a)
  tooltip:UpdateScrolling(settings.tooltipHeight)
end

butTool:SetScript("OnEnter", OnEnter)

-- config --
local function OpenConfig(self, button)
  InterfaceOptionsFrame_OpenToCategory(L[addonName])
  InterfaceOptionsFrame_OpenToCategory(L[addonName])
end
butTool:SetScript("OnMouseUp", OpenConfig)


local LDB_Exlist = LDB:NewDataObject("Exlist",{
  type = "data source",
  text = "Exlist",
  icon = "Interface\\AddOns\\Exlist\\Media\\Icons\\logo",
  OnClick = OpenConfig,
  OnEnter = OnEnter
})

-- refresh
function Exlist.RefreshAppearance()
  --texplore(fontSet)
  butTool:SetAlpha(settings.iconAlpha or 1)
  butTool:SetMovable(not settings.lockIcon)
  butTool:RegisterForDrag("LeftButton")
  butTool:SetScript("OnDragStart", not settings.lockIcon and butTool.StartMoving or function() end)
  local font = LSM:Fetch("font",settings.Font)
  hugeFont:SetFont(font, settings.fonts.big.size)
  smallFont:SetFont(font, settings.fonts.small.size)
  mediumFont:SetFont(font, settings.fonts.medium.size)
  for fontSize,f in pairs(customFonts) do
    f:SetFont(font,fontSize)
  end
  butTool:SetScale(settings.iconScale)

  if settings.showMinimapIcon then
    LDBI:Show("Exlist")
  else
    LDBI:Hide("Exlist")
  end
  if settings.showIcon then
    butTool:Show()
  else
    butTool:Hide()
  end
end

-- addon loaded
local function IsNewCharacter()
  local name = UnitName('player')
  local realm = GetRealmName()
  return db[realm] == nil or db[realm][name] == nil
end

function Exlist.InitConfig()
end

local function Modernize()
  -- to new allowedModules format
  local deleteList = {}
  for name,value in pairs(settings.allowedModules) do
    if type(value) ~= 'table' then
      for key,t in pairs(Exlist.ModuleData.modules) do
        if t.name == name then
          settings.allowedModules[t.key] = {enabled = value, name = name}
          break
        end
      end
      deleteList[#deleteList+1] = name
    end
  end
  for i,name in ipairs(deleteList) do settings.allowedModules[name] = nil end

  -- Normalize character Order
  local chars = settings.allowedCharacters
  local order = 1
  for char,t in spairs(chars,function(t,a,b) return t[a].order < t[b].order end) do
    chars[char].order = order
    order = order + 1
  end
end

local function init()
  Exlist_DB = Exlist_DB or db
  Exlist_Config = Exlist_Config or config_db
  -- setupt settings
  Exlist_Config.settings = AddMissingTableEntries(Exlist_Config.settings or {},settings)

  db = Exlist.copyTable(Exlist_DB)
  db.global = db.global or {}
  db.global.global = db.global.global or {}
  Exlist.DB = db
  config_db = Exlist.copyTable(Exlist_Config)
  settings = config_db.settings
  Exlist.ConfigDB = config_db
  settings.reorder = true
  if not LDBI:IsRegistered("Exlist") then
    LDBI:Register("Exlist",LDB_Exlist,settings.minimapTable)
  end

  for key,data in pairs(Exlist.ModuleData.modules) do
    if data.init then
      data.init()
    end
  end

  Modernize()
  ModernizeCharacters()

  if IsNewCharacter() then
    -- for config page if it's first time that character logins
    C_Timer.After(0.2, function()
      UpdateCharacterSpecifics("PLAYER_ENTERING_WORLD")
      AddMissingCharactersToSettings()
      AddModulesToSettings()
      Exlist.InitConfig()
    end)
  else
    AddMissingCharactersToSettings()
    AddModulesToSettings()
    Exlist.InitConfig()
  end
  C_Timer.After(0.5, function() Exlist.RefreshAppearance() end)
end

-- Reset handling Credit to SavedInstances
local function GetRegion()
  if not config_db.region then
    local reg = GetCVar("portal")
    if reg == "public-test" then -- PTR uses US region resets, despite the misleading realm name suffix
      reg = "US"
    end
    if not reg or #reg ~= 2 then
      local gcr = GetCurrentRegion()
      reg = gcr and ({ "US", "KR", "EU", "TW", "CN" })[gcr]
    end
    if not reg or #reg ~= 2 then
      reg = (GetCVar("realmList") or ""):match("^(%a+)%.")
    end
    if not reg or #reg ~= 2 then -- other test realms?
      reg = (GetRealmName() or ""):match("%((%a%a)%)")
    end
    reg = reg and reg:upper()
    if reg and #reg == 2 then
      config_db.region = reg
    end
  end
  return config_db.region
end

local function GetServerOffset()
  local serverDay = C_Calendar.GetDate().weekday - 1
  --local serverDay = CalendarGetDate() - 1 -- 1-based starts on Sun
  local localDay = tonumber(date("%w")) -- 0-based starts on Sun
  local serverHour, serverMinute = GetGameTime()
  local localHour, localMinute = tonumber(date("%H")), tonumber(date("%M"))
  if serverDay == (localDay + 1)%7 then -- server is a day ahead
    serverHour = serverHour + 24
  elseif localDay == (serverDay + 1)%7 then -- local is a day ahead
    localHour = localHour + 24
  end
  local server = serverHour + serverMinute / 60
  local localT = localHour + localMinute / 60
  local offset = floor((server - localT) * 2 + 0.5) / 2
  return offset
end

local function GetNextDailyResetTime()
  local resettime = GetQuestResetTime()
  if not resettime or resettime <= 0 or -- ticket 43: can fail during startup
    resettime > 24 * 3600 + 30 then -- can also be wrong near reset in an instance
    return nil
  end
  if false then
    local serverHour, serverMinute = GetGameTime()
    local serverResetTime = (serverHour * 3600 + serverMinute * 60 + resettime) % 86400 -- GetGameTime of the reported reset
    local diff = serverResetTime - 10800 -- how far from 3AM server
    if math.abs(diff) > 3.5 * 3600 -- more than 3.5 hours - ignore TZ differences of US continental servers
      and GetRegion() == "US" then
      local diffhours = math.floor((diff + 1800) / 3600)
      resettime = resettime - diffhours * 3600
      if resettime < - 900 then -- reset already passed, next reset
        resettime = resettime + 86400
      elseif resettime > 86400 + 900 then
        resettime = resettime - 86400
      end
      --debug("Adjusting GetQuestResetTime() discrepancy of %d seconds (%d hours). Reset in %d seconds", diff, diffhours, resettime)
    end
  end
  return time() + resettime
end

local function GetNextWeeklyResetTime()
  if not config_db.resetDays then
    local region = GetRegion()
    --print('Getnextweekly region: ', region)
    if not region then return nil end
    config_db.resetDays = {}
    config_db.resetDays.DLHoffset = 0
    if region == "US" then
      config_db.resetDays["2"] = true -- tuesday
      -- ensure oceanic servers over the dateline still reset on tues UTC (wed 1/2 AM server)
      config_db.resetDays.DLHoffset = -3
    elseif region == "EU" then
      config_db.resetDays["3"] = true -- wednesday
    elseif region == "CN" or region == "KR" or region == "TW" then -- XXX: codes unconfirmed
      config_db.resetDays["4"] = true -- thursday
    else
      config_db.resetDays["2"] = true -- tuesday?
    end
  end
  local offset = (GetServerOffset() + config_db.resetDays.DLHoffset) * 3600
  local nightlyReset = GetNextDailyResetTime()
  if not nightlyReset then return nil end
  while not config_db.resetDays[date("%w", nightlyReset + offset)] do
    nightlyReset = nightlyReset + 24 * 3600
  end
  return nightlyReset
end
Exlist.GetNextWeeklyResetTime = GetNextWeeklyResetTime
Exlist.GetNextDailyResetTime = GetNextDailyResetTime

local function ResetHandling() end

local function HasWeeklyResetHappened()
  if not config_db.resetTime then return end
  local weeklyReset = GetNextWeeklyResetTime()
  if weeklyReset ~= config_db.resetTime then
    -- reset has happened because next weekly reset time is different from stored one
    return true
  else
    Exlist.Debug("Reset recheck in:",weeklyReset-time()+1)
    timer:ScheduleTimer(ResetHandling,weeklyReset-time()+1)
  end
  return false
end

local function HasDailyResetHappened()
  if not config_db.resetDailyTime then return end
  local dailyReset = GetNextDailyResetTime()
  if dailyReset ~= config_db.resetDailyTime then
    -- reset has happened because next weekly reset time is different from stored one
    return true
  else
    Exlist.Debug("Reset recheck in:",dailyReset-time()+1)
    timer:ScheduleTimer(ResetHandling,dailyReset-time()+1)
  end
  return false
end

local function ResetCoins()
  local realm, numRealms = GetRealms()
  for i = 1, numRealms do
    local charInfo, charNum = GetRealmCharInfo(realm[i])
    for ci = 1, charNum do
      if charInfo[ci].coins and charInfo[ci].level == MAX_CHARACTER_LEVEL then
        -- char can have coins
        charInfo[ci].coins.available = 3
      end
    end
  end
end

local function GetResetKeys(type)
  local keys = {}
  for key,data in pairs(Exlist.ModuleData.resetHandle) do

  end
end

local function WipeKeysForReset(type)
  Exlist.Debug("Reset:",type)
  settings.unsortedFolder[type] = {}
  for key,data in pairs(Exlist.ModuleData.resetHandle) do
    if data[type] then
      if data.handler then
        Exlist.Debug("Reset",key,"with handler function")
        data.handler(type)
      else
        Exlist.Debug("Reset",key,"by wiping")
        WipeKey(key)
      end
    end
  end
end

local function GetLastUpdateTime()
  local d = date("*t", time())
  local gameTime = GetGameTime()
  UpdateChar("updated",string.format("%d %s %02d:%02d",d.day,monthNames[d.month],d.hour,d.min))
end

function ResetHandling()
  Exlist.Debug("Reset Check")
  if HasWeeklyResetHappened() then
    -- check for reset
    WipeKeysForReset("weekly")
    WipeKeysForReset("daily")
  elseif HasDailyResetHappened() then
    WipeKeysForReset("daily")
  end
  config_db.resetTime = GetNextWeeklyResetTime()
  config_db.resetDailyTime = GetNextDailyResetTime()
end

local function AnnounceReset(msg)
  local channel = IsInRaid() and "raid" or "party"
  if IsInGroup() then
    SendChatMessage(string.format("[%s] %s",L[addonName],msg),channel)
  end
end
hooksecurefunc("ResetInstances", function()
  AnnounceReset(L["Reset All Instances"])
end)

-- Updaters
function Exlist.SendFakeEvent(event) end

local delay = true
local delayedEvents = {}
local running = false
local runEvents = {}

local function SendDelayedEvents()
  for e in pairs(delayedEvents) do
    Exlist.SendFakeEvent(e)
  end
end

local function IsEventEligible(event)
  if runEvents[event] then
    if GetTime() - runEvents[event] > 0.5 then
      runEvents[event] = nil
      return true
    else
      Exlist.Debug("Denied running event(",event,")")
      return false
    end
  else
    runEvents[event] = GetTime()
    return true
  end
end

local function DebugTimeColors(timeSpent)
  if timeSpent < 0.2 then
    return WrapTextInColorCode(string.format("%.6f",timeSpent), Colors.debugTime.short)
  elseif timeSpent <= 1 then
    return WrapTextInColorCode(string.format("%.6f",timeSpent), Colors.debugTime.medium)
  elseif timeSpent <= 2 then
    return WrapTextInColorCode(string.format("%.6f",timeSpent), Colors.debugTime.almostlong)
  end
  return WrapTextInColorCode(string.format("%.6f",timeSpent), Colors.debugTime.long)
end

function frame:OnEvent(event, ...)
  if not IsEventEligible(event) then return end
  if event == "PLAYER_LOGOUT" then
    -- save things
    if db and next(db) ~= nil then
      Exlist_DB = db
    end
    if config_db and next(config_db) ~= nil then
      Exlist_Config = config_db
    end
    return
  end
  if event == "VARIABLES_LOADED" then
    local started = debugprofilestop()
    init()
    SetTooltipBut()
    Exlist.Debug('Init ran for: ' .. DebugTimeColors(debugprofilestop() - started))
    C_Timer.After(3,function() ResetHandling() end)
    return
  end
  -- Delays
  if event == "Exlist_DELAY" then
    delay = false
    SendDelayedEvents()
    return
  end
  if delay then
    Exlist.Debug(event,"delayed")
    if not running then
      C_Timer.After(4,function() Exlist.SendFakeEvent("Exlist_DELAY") end)
      delayedEvents[event] = 1
      running = true
    else
      delayedEvents[event] = 1
    end
    return
  end
  --if InCombatLockdown() then return end -- Don't update in combat

  Exlist.Debug('Event ',event)
  if Exlist.ModuleData.updaters[event] then
    for i,data in ipairs(Exlist.ModuleData.updaters[event]) do
      if settings.allowedModules[data.key] and settings.allowedModules[data.key].enabled or data.override then
        local started = debugprofilestop()
        xpcall(data.func, geterrorhandler(), event, ...)
        Exlist.Debug(data.name .. ' finished: ' .. DebugTimeColors(debugprofilestop() - started))
        GetLastUpdateTime()
      end
    end
  end
  if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
    local started = debugprofilestop()
    UpdateCharacterSpecifics(event)
    Exlist.Debug('Character Stat Updated: ' .. DebugTimeColors(debugprofilestop() - started))
  elseif event == "CHAT_MSG_SYSTEM" then
    if settings.announceReset and ... then
      local resetString = INSTANCE_RESET_SUCCESS:gsub("%%s",".+")
      local msg = ...
      if msg:match("^"..resetString.."$") then
        AnnounceReset(msg)
      end
    end
  end
end
frame:SetScript("OnEvent", frame.OnEvent)

function Exlist.SendFakeEvent(event,...)
  frame.OnEvent(nil,event,...)
end

local function func(...)
  Exlist.SendFakeEvent("WORLD_MAP_OPEN")
end

hooksecurefunc(WorldMapFrame,"Show",func)

function Exlist.PrintUpdates()
  local realms, numRealms = GetRealms()
  for j = 1, numRealms do
    local charInfo, charNum = GetRealmCharInfo(realms[j])
    for i = 1, charNum do
      if charInfo[i].updated then
        print(realms[j] .. ' - ' .. charInfo[i].name .. ' : ' .. charInfo[i].updated)
      end
    end
  end
end

SLASH_CHARINF1, SLASH_CHARINF2 = '/EXL', '/Exlist'; -- 3.
function SlashCmdList.CHARINF(msg, editbox) -- 4.
  local args = {strsplit(" ",msg)}
  if args[1] == "" then
    OpenConfig()
  elseif args[1] == "refresh" then
    UpdateCharacterSpecifics()
  elseif args[1] == "update" then
    Exlist.PrintUpdates()
  elseif args[1] == "debug" then
    print(debugMode and L['Debug: stopped'] or L['Debug: started'])
    debugMode = not debugMode
    Exlist.debugMode = debugMode
  elseif args[1] == "reset" then
    print(L['Weekly reset in: '], SecondsToTime(GetNextWeeklyResetTime()-time()))
    print(L['Daily reset in: '], SecondsToTime(GetNextDailyResetTime()-time()))
  elseif args[1] == "wipe" then
    if args[2] then
      -- testing purposes
      WipeKey(args[2])
    end
  elseif args[1] == "triggerreset" then
    if args[2] then
      WipeKeysForReset(args[2])
    end
  elseif args[1] == "resetsettings" then
    Exlist.ConfigDB.settings = {}
    ReloadUI()
  end
end
