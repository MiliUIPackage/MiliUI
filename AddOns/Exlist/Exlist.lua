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
Exlist.tooltipData = {}
-- API --
local _G = _G
local CreateFrame, CreateFont = CreateFrame, CreateFont
local GetRealmName = GetRealmName
local UnitName = UnitName
local GetCVar = GetCVar
local WrapTextInColorCode, SecondsToTime = WrapTextInColorCode, SecondsToTime
local UnitClass, UnitLevel = UnitClass, UnitLevel
local GetAverageItemLevel, GetSpecialization, GetSpecializationInfo =
   GetAverageItemLevel,
   GetSpecialization,
   GetSpecializationInfo
local C_Timer = C_Timer
local C_ArtifactUI = C_ArtifactUI
local HasArtifactEquipped = HasArtifactEquipped
local GetItemInfo, GetInventoryItemLink = C_Item.GetItemInfo, GetInventoryItemLink
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local GetGameTime, GetTime, debugprofilestop = GetGameTime, GetTime, debugprofilestop
local strsplit = strsplit
local UIParent, WorldMapFrame = UIParent, WorldMapFrame
local GetItemGem, GetProfessions, GetProfessionInfo, IsInRaid =
    C_Item.GetItemGem,
    GetProfessions,
    GetProfessionInfo,
    IsInRaid
local hooksecurefunc, SendChatMessage = hooksecurefunc, SendChatMessage
-- lua api
local tonumber = _G.tonumber
local next = next
local floor = _G.math.floor
local format = _G.format
local string = string
local strlen = strlen
local type, pairs, ipairs, table = type, pairs, ipairs, table
local print, select, date, math, time = print, select, date, math, time
local timer = Exlist.timers

-- SETTINGS
LSM:Register("font", "PT_Sans_Narrow", [[Interface\Addons\Exlist\Media\Font\font.ttf]])
local settings = {
   -- default settings
   minLevelToTrack = 60,
   fonts = { big = { size = 18 }, medium = { size = 16 }, small = { size = 14 } },
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
      color = {r = 0, g = 0, b = 0, a = .9},
      borderColor = {r = .2, b = .2, g = .2, a = 1}
   },
   currencies = {},
   worldQuests = {},
   worldbosses = {},
   wqRules = {money = {}, currency = {}, item = {}, honor = {}},
   quests = {},
   extraInfoToggles = {},
   announceReset = true,
   showMinimapIcon = true,
   minimapTable = {},
   showIcon = false,
   horizontalMode = true,
   hideEmptyCurrency = false,
   showExtraInfoTooltip = true,
   showTotalsTooltip = true,
   shortenInfo = true,
   showCurrentRealm = false,
   showQuestsInExtra = false,
   unsortedFolder = {
      -- used to store vars that aren't connected to specific characters but need to be reset daily/weekly
      ["daily"] = {},
      ["weekly"] = {}
   },
   reputation = {cache = {}, charOption = {}, enabled = {}},
   azeriteWeekly = true
}

local Colors = Exlist.Colors

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
local font = LSM:Fetch("font", settings.Font)
local hugeFont = CreateFont("Exlist_HugeFont")
hugeFont:SetFont(font, fontSet.big.size, "OUTLINE")
hugeFont:SetTextColor(1, 1, 1)
local smallFont = CreateFont("Exlist_SmallFont")
smallFont:SetFont(font, fontSet.small.size,"OUTLINE")
smallFont:SetTextColor(1, 1, 1)
local mediumFont = CreateFont("Exlist_MediumFont")
mediumFont:SetFont(font, fontSet.medium.size,"OUTLINE")
mediumFont:SetTextColor(1, 1, 1)

Exlist.Fonts = {
   hugeFont = hugeFont,
   mediumFont = mediumFont,
   smallFont = smallFont
}

local customFonts = {}
local monthNames = {
   L["January"],
   L["February"],
   L["March"],
   L["April"],
   L["May"],
   L["June"],
   L["July"],
   L["August"],
   L["September"],
   L["October"],
   L["November"],
   L["December"]
}

-- register events
local frame = CreateFrame("FRAME")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("CHAT_MSG_SYSTEM")

-- utility
local function spairs(t, order)
   -- collect the keys
   local keys = {}
   for k in pairs(t) do
      keys[#keys + 1] = k
   end

   -- if order function given, sort by it by passing the table and keys a, b,
   -- otherwise just sort the keys
   if order then
      table.sort(
         keys,
         function(a, b)
            return order(t, a, b)
         end
      )
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
   local affixes = {"", "k", "m", "b", "t"}
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

   return string.format("%." .. dec .. "f" .. affixes[affix], num1)
--]]
end
Exlist.ShortenNumber = ShortenNumber
local function copyTableInternal(source, seen)
   if type(source) ~= "table" then
      return source
   end
   if seen[source] then
      return seen[source]
   end
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

local function ColorDecToHex(col1, col2, col3)
   col1 = col1 or 0
   col2 = col2 or 0
   col3 = col3 or 0
   local hexColor = string.format("%02x%02x%02x", col1 * 255, col2 * 255, col3 * 255)
   return hexColor
end
Exlist.ColorDecToHex = ColorDecToHex

local function TimeLeftColor(timeLeft, times, col)
   -- times (opt) = {red,orange} upper limit
   -- i.e {100,1000} = 0-100 Green 100-1000 Orange 1000-inf Green
   -- colors (opt) - colors to use
   if not timeLeft then
      return
   end
   times = times or {3600, 18000} -- default
   local colors = col or {Exlist.Colors.time.long, Exlist.Colors.time.medium, Exlist.Colors.time.short} -- default
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
      _G[TooltipName .. "Texture" .. i]:SetTexture(nil)
      _G[TooltipName .. "Texture" .. i]:ClearAllPoints()
      _G[TooltipName .. "Texture" .. i]:SetPoint("TOPLEFT", self)
   end
end

Exlist.QuestTitleFromID =
   setmetatable(
   {},
   {
      __index = function(t, id)
         MyScanningTooltip:ClearTooltip()
         MyScanningTooltip:SetOwner(UIParent, "ANCHOR_NONE")
         MyScanningTooltip:SetHyperlink("quest:" .. id)
         local title = ExlistScanningTooltipTextLeft1:GetText()
         MyScanningTooltip:Hide()
         if title and title ~= RETRIEVING_DATA then
            t[id] = title
            return title
         end
      end
   }
)

local function GetItemEnchant(itemLink)
   MyScanningTooltip:ClearTooltip()
   MyScanningTooltip:SetOwner(UIParent, "ANCHOR_NONE")
   MyScanningTooltip:SetHyperlink(itemLink)
   local enchantKey = ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.+)")
   for i = 1, MyScanningTooltip:NumLines() do
      if
         _G["ExlistScanningTooltipTextLeft" .. i]:GetText() and
            _G["ExlistScanningTooltipTextLeft" .. i]:GetText():match(enchantKey)
       then
         -- name,id
         local name = _G["ExlistScanningTooltipTextLeft" .. i]:GetText()
         name = name:match("^%w+: (.*)")
         local _, _, enchantId = strsplit(":", itemLink)
         return name, enchantId
      end
   end
end
Exlist.GetItemEnchant = GetItemEnchant
local function GetItemGems(itemLink)
   local t = {}
   for i = 1, MAX_NUM_SOCKETS do
      local name, iLink = GetItemGem(itemLink, i)
      if iLink then
         local icon = select(10, GetItemInfo(iLink))
         table.insert(t, {name = name, icon = icon})
      end
   end
   MyScanningTooltip:ClearTooltip()
   MyScanningTooltip:SetOwner(UIParent, "ANCHOR_NONE")
   MyScanningTooltip:SetHyperlink(itemLink)
   for i = 1, MAX_NUM_SOCKETS do
      local tex = _G["ExlistScanningTooltipTexture" .. i]:GetTexture()
      if tex then
         tex = tostring(tex)
         if tex:find("Interface\\ItemSocketingFrame\\UI--Empty") then
            table.insert(
               t,
               {
                  name = WrapTextInColorCode(L["Empty Slot"], Exlist.Colors.faded),
                  icon = tex
               }
            )
         end
      end
   end
   return t
end
Exlist.GetItemGems = GetItemGems
local function QuestInfo(questid)
   if not questid or questid == 0 then
      return nil
   end
   MyScanningTooltip:ClearTooltip()
   MyScanningTooltip:SetOwner(UIParent, "ANCHOR_NONE")
   MyScanningTooltip:SetHyperlink("\124cffffff00\124Hquest:" .. questid .. ":90\124h[]\124h\124r")
   local l = _G[MyScanningTooltip:GetName() .. "TextLeft1"]
   l = l and l:GetText()
   if not l or #l == 0 then
      return nil
   end -- cache miss
   return l, "\124cffffff00\124Hquest:" .. questid .. ":90\124h[" .. l .. "]\124h\124r"
end
Exlist.QuestInfo = QuestInfo

local function FormatTimeMilliseconds(time)
   if not time then
      return
   end
   local minutes = math.floor((time / 1000) / 60)
   local seconds = math.floor((time - (minutes * 60000)) / 1000)
   local milliseconds = time - (minutes * 60000) - (seconds * 1000)
   return string.format("%02d:%02d:%02d", minutes, seconds, milliseconds)
end
Exlist.FormatTimeMilliseconds = FormatTimeMilliseconds

local function GetTimeLeftColor(time, inverse)
   if not time then
      return "ffffffff"
   end
   -- long
   -- long,medium,short
   local times = {18000, 3600}
   local colorKeys = {"long", "medium", "short"}
   for i = 1, #times do
      if time > times[i] then
         return inverse and Exlist.Colors.time[colorKeys[4 - i]] or Exlist.Colors.time[colorKeys[i]]
      end
   end
   return inverse and Exlist.Colors.time[colorKeys[1]] or Exlist.Colors.time[colorKeys[3]]
end
Exlist.GetTimeLeftColor = GetTimeLeftColor

local function FormatTime(time)
   if not time then
      return ""
   end
   local days = math.floor(time / (60 * 60 * 24))
   time = time - days * (60 * 60 * 24)
   local hours = math.floor(time / (60 * 60))
   time = time - hours * (60 * 60)
   local minutes = math.floor((time) / 60)
   local seconds = time % 60
   if days > 0 then
      return string.format("%dd %02d:%02d:%02d", days, hours, minutes, seconds)
   elseif hours > 0 then
      return string.format("%02d:%02d:%02d", hours, minutes, seconds)
   end
   return string.format("%02d:%02d", minutes, seconds)
end
Exlist.FormatTime = FormatTime

-- Originally by Asakawa but has been modified --
local sTextCache = {}
local function ShortenText(s, separator, full)
--[[
   wipe(sTextCache)
   sTextCache = {strsplit(" ", s)}
   separator = separator or "."
   local offset = full and 0 or 1
   for i = 1, #sTextCache - offset do
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

local function AuraFromId(unit, ID, filter)
   -- Already Preparing for BFA
   for i = 1, 40 do
      local name,
      icon,
      count,
      debuffType,
      duration,
      expirationTime,
      unitCaster,
      canStealOrPurge,
      nameplateShowPersonal,
      spellId,
      canApplyAura,
      isBossDebuff,
      isCastByPlayer,
      nameplateShowAll,
      timeMod,
      value1,
      value2,
      value3 = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
      if name then
         if spellId and spellId == ID then
            return name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge,
                nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, isCastByPlayer, nameplateShowAll, timeMod,
                value1, value2, value3
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
      local debugString = string.format("|c%s[Exlist Debug]|r", Exlist.Colors.debug)
      print(debugString, ...)
   end
end

--------------
local function AddMissingCharactersToSettings()
   settings.allowedCharacters = settings.allowedCharacters or {}
   local chars = settings.allowedCharacters
   for realm, v in pairs(db) do
      if realm ~= "global" then
         for name, values in pairs(v) do
            local charFullName = name .. "-" .. realm
            if not chars[charFullName] then
               chars[charFullName] = {
                  enabled = true,
                  name = name,
                  order = 70,
                  classClr = values.class and RAID_CLASS_COLORS[values.class].colorStr or
                     name == UnitName("player") and RAID_CLASS_COLORS[select(2, UnitClass("player"))].colorStr or
                     "FFFFFFFF",
                  ilvl = values.iLvl or 0
               }
            end
         end
      end
   end
end
Exlist.AddMissingCharactersToSettings = AddMissingCharactersToSettings

local function AddModulesToSettings()
   if not settings.allowedModules then
      settings.allowedModules = {}
   end
   local t = settings.allowedModules
   local newT = {}
   for key, data in pairs(Exlist.ModuleData.modules) do
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

local function UpdateChar(key, data, charname, charrealm)
   if not data or (UnitLevel('player') < (Exlist.ConfigDB.minLevelToTrack or settings.minLevelToTrack)) then
      return
   end
   charrealm = charrealm or GetRealmName()
   charname = charname or UnitName("player")
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
      local name = C_TaskQuest.GetQuestInfoByQuestID(questId)
      name = name or Exlist.QuestInfo(questId)
      if name then
         -- only save if you actually got info
         config_db.quest_cache = config_db.quest_cache or {}
         config_db.quest_cache[questId] = name
      end
      return name or ("Unknown (" .. questId .. ")")
   end
end
Exlist.GetCachedQuestTitle = GetCachedQuestTitle

local function DeleteCharacterKey(name, realm, key)
   if not key or not db[realm] or not db[realm][name] then
      return
   end
   db[realm][name][key] = nil
end

local function WipeAll()
   db = {}
end

local function WipeKey(key)
   -- ... yea
   -- if i need to delete 1 key info from all characters on all realms
   Exlist.Debug("wiped " .. key)
   for realm in pairs(db) do
      for name in pairs(db[realm]) do
         for keys in pairs(db[realm][name]) do
            if keys == key then
               Exlist.Debug(" - wiping ", key, " From:", name, "-", realm)
               db[realm][name][key] = nil
            end
         end
      end
   end
   Exlist.Debug(" Wiping Key (", key, ") completed.")
end

local slotNames = {
   L["Head"],
   L["Neck"],
   L["Shoulders"],
   L["Shirt"],
   L["Chest"],
   L["Waist"],
   L["Legs"],
   L["Feet"],
   L["Wrists"],
   L["Hands"],
   L["Ring"],
   L["Ring"],
   L["Trinket"],
   L["Trinket"],
   L["Back"],
   L["Main Hand"],
   L["Off Hand"],
   L["Ranged"]
}

local function UpdateCharacterGear()
   local t = {}
   local order = {1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18}
   for i = 1, #order do
      local iLink = GetInventoryItemLink("player", order[i])
      if iLink then
         local itemName, itemLink, itemRarity, _, _, _, _, _, _, itemTexture, _ = GetItemInfo(iLink)
         local ilvl = C_Item.GetDetailedItemLevelInfo(iLink)
         local relics = {}
         local enchant = GetItemEnchant(iLink)
         local gem = GetItemGems(iLink)
         if (not itemName) then
            -- Sometimes there might be item info missing
            -- Don't pollute db with broken data in these cases and abort
            -- gear update
            return
         end
         table.insert(
            t,
            {
               slot = slotNames[order[i]],
               name = itemName,
               itemTexture = itemTexture,
               itemLink = itemLink,
               ilvl = ilvl,
               enchant = enchant,
               gem = gem
            }
         )
      end
   end
   if HasArtifactEquipped() then
      for i = 1, 3 do
         local name, icon, slotTypeName, link = C_ArtifactUI.GetEquippedArtifactRelicInfo(i)
         if name then
            local ilvl = C_Item.GetDetailedItemLevelInfo(link)
            table.insert(
               t,
               {
                  slot = slotTypeName .. " " .. L["Relic"],
                  name = name,
                  itemTexture = icon,
                  itemLink = link,
                  ilvl = ilvl
               }
            )
         end
      end
   end
   UpdateChar("gear", t)
end

local function UpdateCharacterProfessions()
   local profIndexes = {GetProfessions()}
   local t = {}
   for i = 1, #profIndexes do
      if profIndexes[i] then
         local name, texture, rank, maxRank = GetProfessionInfo(profIndexes[i])
         table.insert(
            t,
            {
               name = name,
               icon = texture,
               curr = rank,
               max = maxRank
            }
         )
      end
   end
   Exlist.UpdateChar("professions", t)
end

local function UpdateCharacterSpecifics(event)
   if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
      UpdateCharacterGear()
   end
   UpdateCharacterProfessions()
   local name = UnitName("player")
   local level = UnitLevel("player")
   local _, class = UnitClass("player")
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
   if settings.allowedCharacters[name .. "-" .. realm] then
      settings.allowedCharacters[name .. "-" .. realm].ilvl = iLvl
   end
   UpdateChar(nil, table, name, realm)
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
   table.sort(
      realms,
      function(a, b)
         return GetTableNum(db[a]) > GetTableNum(db[b])
      end
   )
   return realms, numRealms
end

local function GetRealmCharInfo(realm)
   if not db[realm] then
      return
   end
   local charInfo = {}
   local charNum = 0

   for char in pairs(db[realm]) do
      if not settings.allowedCharacters[char .. "-" .. realm] then
         AddMissingCharactersToSettings()
      end
      if settings.allowedCharacters[char .. "-" .. realm].enabled then
         charNum = charNum + 1
         charInfo[charNum] = {}
         charInfo[charNum].name = char
         for key, value in pairs(db[realm][char]) do
            charInfo[charNum][key] = value
         end
      end
   end
   table.sort(
      charInfo,
      function(a, b)
         return a.iLvl > b.iLvl
      end
   )
   return charInfo, charNum
end

-- Modules/API
-- Info attaching to tooltip
function Exlist.AddLine(tooltip, info, fontSize)
   -- info =  {'1st cell','2nd cell','3rd cell' ...} or "string"
   if not tooltip or not info or (type(info) ~= "table" and type(info) ~= "string") then
      return
   end
   -- Set Font
   fontSize = fontSize or settings.fonts.small.size
   local fontObj
   if customFonts[fontSize] then
      fontObj = customFonts[fontSize]
   else
      local font = LSM:Fetch("font", settings.Font)
      fontObj = CreateFont("Exlist_Font" .. fontSize)
      fontObj:SetFont(font, fontSize, "OUTLINE")
      fontObj:SetTextColor(1, 1, 1)
      customFonts[fontSize] = fontObj
   end
   tooltip:SetFont(fontObj)

   local maxColumns = #tooltip.columns
   local n = tooltip:AddLine()
   if type(info) == "string" then
      tooltip:SetCell(n, 1, info, "LEFT", maxColumns - 1)
   else
      for i = 1, #info do
         if i < #info then
            tooltip:SetCell(n, i, info[i])
         else
            tooltip:SetCell(n, i, info[i], "LEFT", maxColumns - i)
         end
      end
   end
   -- return line number
   return n
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
  cellColor = "string" (optional) cell background in hex
  lineColor = "string" (optional) line background in hex
  }
  ]]
   if not info then
      return
   end
   info.colOff = info.colOff or 0
   local char = info.character.name .. info.character.realm
   Exlist.tooltipData[char] = Exlist.tooltipData[char] or {modules = {}, num = 0}
   local t = Exlist.tooltipData[char]
   if t.modules[info.moduleName] then
      table.insert(t.modules[info.moduleName].data, info)
      t.modules[info.moduleName].num = t.modules[info.moduleName].num + 1
   else
      if info.moduleName ~= "_Header" and info.moduleName ~= "_HeaderSmall" then
         t.num = t.num + 1
      end
      t.modules[info.moduleName] = {
         data = {info},
         priority = info.priority,
         name = info.titleName,
         num = 1
      }
   end
end

function Exlist.AddToLine(tooltip, row, col, text)
   -- Add text to lines column
   if not tooltip or not row or not col or not text then
      return
   end
   tooltip:SetCell(row, col, text)
end

function Exlist.AddScript(tooltip, row, col, event, func, arg)
   -- Script for cell
   if not tooltip or not row or not event or not func then
      return
   end
   if col then
      tooltip:SetCellScript(row, col, event, func, arg)
   else
      tooltip:SetLineScript(row, event, func, arg)
   end
end

local registeredEvents = {}
local function RegisterEvents()
   for event in pairs(Exlist.ModuleData.updaters) do
      if not registeredEvents[event] then
         xpcall(
            frame.RegisterEvent,
            function()
               return true
            end,
            frame,
            event
         )
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
   if not data then
      return
   end
   local mDB = Exlist.ModuleData
   -- add updater
   if data.updater and data.event then
      if type(data.event) == "table" then
         -- multiple events
         for i = 1, #data.event do
            mDB.updaters[data.event[i]] = mDB.updaters[data.event[i]] or {}
            table.insert(
               mDB.updaters[data.event[i]],
               {
                  func = data.updater,
                  name = data.name,
                  override = data.override,
                  key = data.key
               }
            )
         end
      elseif type(data.event) == "string" then
         -- single event
         mDB.updaters[data.event] = mDB.updaters[data.event] or {}
         table.insert(
            mDB.updaters[data.event],
            {
               func = data.updater,
               name = data.name,
               override = data.override,
               key = data.key
            }
         )
      end
   end
   RegisterEvents()

   -- add line generator
   table.insert(
      mDB.lineGenerators,
      {
         name = data.name,
         func = data.linegenerator,
         prio = data.priority,
         key = data.key,
         type = "main"
      }
   )
   if data.globallgenerator then
      table.insert(
         mDB.lineGenerators,
         {
            name = data.name,
            func = data.globallgenerator,
            prio = data.priority,
            key = data.key,
            type = "global"
         }
      )
   end
   if data.customGenerator then
      table.insert(
         mDB.lineGenerators,
         {
            name = data.name,
            func = data.customGenerator,
            prio = data.priority,
            key = data.key,
            type = data.type
         }
      )
   end
   -- Add module data
   mDB.modules[data.key] = {
      name = data.name,
      defaultEnable = data.enabled == nil or data.enabled,
      description = data.description or "",
      modernize = data.modernize,
      init = data.init,
      events = data.event
   }
   -- Reset Stuff
   mDB.resetHandle[data.key] = {
      weekly = data.weeklyReset,
      daily = data.dailyReset,
      handler = data.specialResetHandle
   }
end

function Exlist.GetRealmNames()
   local t = {}
   for i in pairs(db) do
      if i ~= "global" then
         t[#t + 1] = i
      end
   end
   return t
end

function Exlist.GetRealmCharacters(realm)
   local t = {}
   if db[realm] then
      for i in pairs(db[realm]) do
         t[#t + 1] = i
      end
   end
   return t
end

function Exlist.GetCharacterTable(realm, name)
   local t = {}
   if db[realm] and db[realm][name] then
      t = db[realm][name]
   end
   return t
end

function Exlist.GetCharacterTableKey(realm, name, key)
   local t = {}
   if db[realm] and db[realm][name] and db[realm][name][key] then
      t = db[realm][name][key]
   end
   return t
end

function Exlist.GetCharacterEssentials(realm, name)
   local t = Exlist.GetCharacterTable(realm, name)
   if (t.class) then
      return {
         class = t.class,
         ilvl = t.ilvl,
         name = t.name,
         realm = t.realm,
         specId = t.specId,
         level = t.level
      }
   end
   return false
end

function Exlist.CharacterExists(realm, name)
   if db[realm] and db[realm][name] then
      return true
   end
   return false
end

function Exlist.DeleteCharacterFromDB(name, realm)
   if db[realm] then
      db[realm][name] = nil
      settings.allowedCharacters[name .. "-" .. realm] = nil
      for i, char in ipairs(settings.characterOrder) do
         if char.name == name and char.realm == realm then
            settings.characterOrder[i] = nil
            settings.reorder = true
            break
         end
      end
      print(debugString, L["Successfully deleted"], name .. "-" .. realm, ".")
   else
      print(debugString, string.format(L["Deleting %s-%s failed."], name, realm))
   end
end

local function ModernizeCharacters()
   for key, data in pairs(Exlist.ModuleData.modules) do
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

-- DISPLAY INFO
butTool = CreateFrame("Frame", "Exlist_Tooltip", UIParent)
local bg = butTool:CreateTexture(nil, "ARTWORK")
butTool:SetSize(32, 32)
bg:SetTexture("Interface\\AddOns\\Exlist\\Media\\Icons\\logo")
bg:SetSize(32, 32)
butTool:SetScale(settings.iconScale)
bg:SetAllPoints()
local function SetTooltipBut()
   if not config_db.config then
      butTool:SetPoint("CENTER", UIParent, "CENTER", 200, -50)
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
   self:StopMovingOrSizing()
   self.isMoving = false
   local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
   config_db.config = {
      point = point,
      relativePoint = relativePoint,
      xOfs = xOfs,
      yOfs = yOfs
   }
end

butTool:SetScript("OnDragStop", Exlist_StopMoving)

local tooltips = {}

function Exlist.RegisterTooltip(tooltipInfo)
   -- tooltipInfo - { showFunc, isMain, order }
   -- showFunc always have to return tooltip that it created
   -- init mainly used to ensure data between files are in sync
   table.insert(tooltips, tooltipInfo)
   table.sort(
      tooltips,
      function(a, b)
         if (a.isMain) then
            return true
         end
         if (b.isMain) then
            return false
         end

         return a.order < b.order
      end
   )
end

-- MAIN SHOW TOOLTIP METHOD
local function OnEnter(self)
   local mainTooltip
   for _, t in ipairs(tooltips) do
      t.init()
      local tooltip = t.showFunc(self, mainTooltip)
      if (t.isMain) then
         mainTooltip = tooltip
      end
      table.insert(Exlist.activeTooltips, tooltip)
   end
   local button = self;
   if (mainTooltip) then
      mainTooltip.time = 0
      mainTooltip.elapsed = 0
      mainTooltip:SetScript(
         "OnUpdate",
         function(self, elapsed)
            self.time = self.time + elapsed
            if self.time > 0.1 then
               if Exlist.MouseOverTooltips() or button:IsMouseOver() then
                  self.elapsed = 0
               else
                  self.elapsed = self.elapsed + self.time
                  if self.elapsed > settings.delay then
                     Exlist.ReleaseActiveTooltips()
                     self:SetScript("OnUpdate", nil)
                  end
               end
               self.time = 0
            end
         end
      )
   end
end

butTool:SetScript("OnEnter", OnEnter)

-- config --
local function OpenConfig(self, button)
   Settings.OpenToCategory(L[addonName])
end
butTool:SetScript("OnMouseUp", OpenConfig)

local LDB_Exlist =
   LDB:NewDataObject(
   "Exlist",
   {
      type = "data source",
      text = "Exlist",
      icon = "Interface\\AddOns\\Exlist\\Media\\Icons\\logo",
      OnClick = OpenConfig,
      OnEnter = OnEnter
   }
)

-- refresh
function Exlist.RefreshAppearance()
   butTool:SetAlpha(settings.iconAlpha or 1)
   butTool:SetMovable(not settings.lockIcon)
   butTool:RegisterForDrag("LeftButton")
   butTool:SetScript(
      "OnDragStart",
      not settings.lockIcon and butTool.StartMoving or function()
         end
   )
   local font = LSM:Fetch("font", settings.Font)
   hugeFont:SetFont(font, settings.fonts.big.size, "OUTLINE")
   smallFont:SetFont(font, settings.fonts.small.size, "OUTLINE")
   mediumFont:SetFont(font, settings.fonts.medium.size, "OUTLINE")
   for fontSize, f in pairs(customFonts) do
      f:SetFont(font, fontSize, "OUTLINE")
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
   local name = UnitName("player")
   local realm = GetRealmName()
   return db[realm] == nil or db[realm][name] == nil
end

function Exlist.InitConfig()
end

local function Modernize()
   -- to new allowedModules format
   local deleteList = {}
   for name, value in pairs(settings.allowedModules) do
      if type(value) ~= "table" then
         for key, t in pairs(Exlist.ModuleData.modules) do
            if t.name == name then
               settings.allowedModules[t.key] = {enabled = value, name = name}
               break
            end
         end
         deleteList[#deleteList + 1] = name
      end
   end
   for i, name in ipairs(deleteList) do
      settings.allowedModules[name] = nil
   end

   -- Normalize character Order
   local chars = settings.allowedCharacters
   local order = 1
   for char, t in spairs(
      chars,
      function(t, a, b)
         return t[a].order < t[b].order
      end
   ) do
      chars[char].order = order
      order = order + 1
   end
end

local function init()
   Exlist_DB = Exlist_DB or db
   Exlist_Config = Exlist_Config or config_db
   -- setupt settings
   Exlist_Config.settings = Exlist.AddMissingTableEntries(Exlist_Config.settings or {}, settings)

   db = Exlist.copyTable(Exlist_DB)
   db.global = db.global or {}
   db.global.global = db.global.global or {}
   Exlist.DB = db
   config_db = Exlist.copyTable(Exlist_Config)
   settings = config_db.settings
   Exlist.ConfigDB = config_db
   settings.reorder = true
   if not LDBI:IsRegistered("Exlist") then
      LDBI:Register("Exlist", LDB_Exlist, settings.minimapTable)
   end

   for key, data in pairs(Exlist.ModuleData.modules) do
      if data.init then
         data.init()
      end
   end

   Modernize()
   ModernizeCharacters()

   if IsNewCharacter() then
      -- for config page if it's first time that character logins
      C_Timer.After(
         0.2,
         function()
            UpdateCharacterSpecifics("PLAYER_ENTERING_WORLD")
            AddMissingCharactersToSettings()
            AddModulesToSettings()
            Exlist.InitConfig()
         end
      )
   else
      AddMissingCharactersToSettings()
      AddModulesToSettings()
      Exlist.InitConfig()
   end

   C_Timer.After(
      0.5,
      function()
         Exlist.RefreshAppearance()
      end
   )
end

local function GetNextDailyResetTime()
   local timeToNextWeeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
   local timeToNextDailyReset = timeToNextWeeklyReset - (floor(timeToNextWeeklyReset / 86400) * 86400)
   return timeToNextDailyReset + time()
end

local function GetNextWeeklyResetTime()
   local secondsToNextReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
   return secondsToNextReset + time()
end
Exlist.GetNextWeeklyResetTime = GetNextWeeklyResetTime
Exlist.GetNextDailyResetTime = GetNextDailyResetTime

local function ResetHandling()
end

local function HasWeeklyResetHappened()
   if not config_db.resetTime then
      return
   end
   local weeklyReset = GetNextWeeklyResetTime()
   if weeklyReset ~= config_db.resetTime then
      -- reset has happened because next weekly reset time is different from stored one
      return true
   else
      Exlist.Debug("Reset recheck in:", weeklyReset - time() + 1)
      timer:ScheduleTimer(ResetHandling, weeklyReset - time() + 1)
   end
   return false
end

local function HasDailyResetHappened()
   if not config_db.resetDailyTime then
      return
   end
   local dailyReset = GetNextDailyResetTime()
   if dailyReset ~= config_db.resetDailyTime then
      -- reset has happened because next weekly reset time is different from stored one
      return true
   else
      Exlist.Debug("Reset recheck in:", dailyReset - time() + 1)
      timer:ScheduleTimer(ResetHandling, dailyReset - time() + 1)
   end
   return false
end

local function WipeKeysForReset(type)
   Exlist.Debug("Reset:", type)
   settings.unsortedFolder[type] = {}
   for key, data in pairs(Exlist.ModuleData.resetHandle) do
      if data[type] then
         if data.handler then
            Exlist.Debug("Reset", key, "with handler function")
            data.handler(type)
         else
            Exlist.Debug("Reset", key, "by wiping")
            WipeKey(key)
         end
      end
   end
end

local function GetLastUpdateTime()
   local d = date("*t", time())
   local gameTime = GetGameTime()
   UpdateChar("updated", string.format("%d %s %02d:%02d", d.day, monthNames[d.month], d.hour, d.min))
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
   if not settings.announceReset then return end
   local channel = IsInRaid() and "raid" or "party"
   if IsInGroup() then
      SendChatMessage(string.format("[%s] %s", L[addonName], msg), channel)
   end
end
hooksecurefunc(
   "ResetInstances",
   function()
      AnnounceReset(L["Reset All Instances"])
   end
)

-- Updaters
function Exlist.SendFakeEvent(event)
end

local delay = true
local delayedEvents = {}
local running = false
local runEvents = {}

local function SendDelayedEvents()
   for e in pairs(delayedEvents) do
      Exlist.SendFakeEvent(e)
   end
end

local IGNORED_EVENTS = {
   ["UPDATE_UI_WIDGET"] = true
}

local function IsEventEligible(event)
   if (not Exlist.ConfigDB) then
      if (delay) then
         if not running then
            C_Timer.After(
               4,
               function()
                  Exlist.SendFakeEvent("Exlist_DELAY")
               end
            )
            delayedEvents[event] = 1
            running = true
         else
            delayedEvents[event] = 1
         end
      end
      return
   end
   if (UnitLevel('player') < (Exlist.ConfigDB.minLevelToTrack or settings.minLevelToTrack)) then
      return false
   end
   if runEvents[event] then
      if GetTime() - runEvents[event] > 0.5 then
         runEvents[event] = nil
         return true
      elseif (not IGNORED_EVENTS[event]) then
         Exlist.Debug("Denied running event(", event, ")")
         return false
      end
      return true
   else
      runEvents[event] = GetTime()
      return true
   end
end

local function DebugTimeColors(timeSpent)
   if timeSpent < 0.2 then
      return WrapTextInColorCode(string.format("%.6f", timeSpent), Exlist.Colors.debugTime.short)
   elseif timeSpent <= 1 then
      return WrapTextInColorCode(string.format("%.6f", timeSpent), Exlist.Colors.debugTime.medium)
   elseif timeSpent <= 2 then
      return WrapTextInColorCode(string.format("%.6f", timeSpent), Exlist.Colors.debugTime.almostlong)
   end
   return WrapTextInColorCode(string.format("%.6f", timeSpent), Exlist.Colors.debugTime.long)
end

function frame:OnEvent(event, ...)
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
      Exlist.Debug("Init ran for: " .. DebugTimeColors(debugprofilestop() - started))
      C_Timer.After(
         3,
         function()
            ResetHandling()
            Exlist.accountSync.init()
         end
      )
      return
   end
   if not IsEventEligible(event) then
      return
   end
   -- Delays
   if event == "Exlist_DELAY" then
      delay = false
      SendDelayedEvents()
      return
   end
   if delay then
      Exlist.Debug(event, "delayed")
      if not running then
         C_Timer.After(
            4,
            function()
               Exlist.SendFakeEvent("Exlist_DELAY")
            end
         )
         delayedEvents[event] = 1
         running = true
      else
         delayedEvents[event] = 1
      end
      return
   end

   Exlist.Debug("Event ", event, ...)
   if Exlist.ModuleData.updaters[event] then
      for i, data in ipairs(Exlist.ModuleData.updaters[event]) do
         if settings.allowedModules[data.key] and settings.allowedModules[data.key].enabled or data.override then
            local started = debugprofilestop()
            xpcall(data.func, geterrorhandler(), event, ...)
            Exlist.Debug(data.name .. " finished: " .. DebugTimeColors(debugprofilestop() - started))
            GetLastUpdateTime()
         end
      end
   end
   if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
      local started = debugprofilestop()
      UpdateCharacterSpecifics(event)
      Exlist.Debug("Character Stat Updated: " .. DebugTimeColors(debugprofilestop() - started))
   elseif event == "CHAT_MSG_SYSTEM" then
      if settings.announceReset and ... then
         local resetString = INSTANCE_RESET_SUCCESS:gsub("%%s", ".+")
         local msg = ...
         if msg:match("^" .. resetString .. "$") then
            AnnounceReset(msg)
         end
      end
   end
end

frame:SetScript("OnEvent", frame.OnEvent)

function Exlist.SendFakeEvent(event, ...)
   frame.OnEvent(nil, event, ...)
end

-- Have to do this as Elvui hooks into WorldMapFrame, attaches some kind of animation that runs every frame
-- and calls :Show() every time :)
local mapOpen = false
local function openMap(...)
   if not mapOpen then
      Exlist.SendFakeEvent("WORLD_MAP_OPEN")
      mapOpen = true
   end
end

local function closeMap()
   mapOpen = false
end

hooksecurefunc(WorldMapFrame, "Show", openMap)
hooksecurefunc(WorldMapFrame, "Hide", closeMap)

function Exlist.PrintUpdates()
   local realms, numRealms = GetRealms()
   for j = 1, numRealms do
      local charInfo, charNum = GetRealmCharInfo(realms[j])
      for i = 1, charNum do
         if charInfo[i].updated then
            print(realms[j] .. " - " .. charInfo[i].name .. " : " .. charInfo[i].updated)
         end
      end
   end
end

SLASH_CHARINF1, SLASH_CHARINF2 = "/EXL", "/Exlist"
function SlashCmdList.CHARINF(msg, editbox)
   local args = {strsplit(" ", msg)}
   if args[1] == "" then
      OpenConfig()
   elseif args[1] == "refresh" then
      UpdateCharacterSpecifics()
   elseif args[1] == "update" then
      Exlist.PrintUpdates()
   elseif args[1] == "debug" then
      print(debugMode and L["Debug: stopped"] or L["Debug: started"])
      debugMode = not debugMode
      Exlist.debugMode = debugMode
   elseif args[1] == "reset" then
      print(L["Weekly reset in: "], SecondsToTime(GetNextWeeklyResetTime() - time()))
      print(L["Daily reset in: "], SecondsToTime(GetNextDailyResetTime() - time()))
   elseif args[1] == "wipe" then
      if args[2] then
         -- testing purposes
         WipeKey(args[2])
      end
   elseif args[1] == "wipeall" then
      WipeAll()
   elseif args[1] == "triggerreset" then
      if args[2] then
         WipeKeysForReset(args[2])
      end
   elseif args[1] == "resetsettings" then
      Exlist.ConfigDB.settings = {}
      ReloadUI()
   end
end
