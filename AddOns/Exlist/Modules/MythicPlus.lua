local key = "mythicPlus"
local prio = 50
local C_ChallengeMode = C_ChallengeMode
local C_MythicPlus = C_MythicPlus
local Exlist = Exlist
local colors = Exlist.Colors
local L = Exlist.L
local WrapTextInColorCode, SecondsToTime = WrapTextInColorCode, SecondsToTime
local table, ipairs = table, ipairs
local initialized = 0
local playersName
local mapIds = {}

local function IsItPlayersRun(members)
   for i = 1, #members do
      if members[i].name == playersName then
         return true
      end
   end
   return false
end

local gotEvent = false
local function Updater(event)
   if not C_MythicPlus.IsMythicPlusActive() then
      return
   end -- if mythic+ season isn't active
   -- make sure code is run after data is received
   if not gotEvent and event ~= "CHALLENGE_MODE_MAPS_UPDATE" then
      C_Timer.After(
         1,
         function()
            Exlist.SendFakeEvent("BLIZZARD_THANKS_SMILE")
         end
      )
   end
   if event == "MYTHIC_PLUS_INIT_DELAY" then
      initialized = 1
   end
   if initialized < 1 then
      return
   end
   if not C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI") then
      C_AddOns.LoadAddOn("Blizzard_ChallengesUI")
      C_MythicPlus.RequestRewards()
      C_MythicPlus.RequestMapInfo()
      return
   end
   if event ~= "CHALLENGE_MODE_MAPS_UPDATE" then
      C_MythicPlus.RequestRewards()
      C_MythicPlus.RequestMapInfo()
      return
   end
   gotEvent = true
   if initialized < 2 then
      C_MythicPlus.RequestRewards()
      C_MythicPlus.RequestMapInfo()
      initialized = 2
   end
   mapIds = C_ChallengeMode.GetMapTable()
   local bestLevel, bestMap, bestMapId, dungeons = 0, "", 0, {}
   for i = 1, #mapIds do
      local mapTime, mapLevel, _, _, members = C_MythicPlus.GetWeeklyBestForMap(mapIds[i])
      -- add to completed dungeons
      local mapName = C_ChallengeMode.GetMapUIInfo(mapIds[i])
      if mapLevel then
         -- wonderful api you got there
         -- getting other character M+ info and shit
         if not IsItPlayersRun(members) then
            return
         end
         table.insert(dungeons, { mapId = mapIds[i], name = mapName, level = mapLevel, time = mapTime })
      end
      -- check if best map this week
      if mapLevel and mapLevel > bestLevel then
         bestLevel = mapLevel
         bestMapId = mapIds[i]
         bestMap = mapName
      end
   end
   -- sort maps by level descending
   table.sort(
      dungeons,
      function(a, b)
         return a.level > b.level
      end
   )

   if bestLevel == 0 then
      -- Blizz why
      bestLevel = C_MythicPlus.GetWeeklyChestRewardLevel()
   end

   local t = {
      bestLvl = bestLevel,
      bestLvlMap = bestMap,
      mapId = bestMapId,
      mapsDone = dungeons,
      chest = {
         level = 0,
         available = false
      }
   }

   Exlist.UpdateChar(key, t)
end

local function Linegenerator(tooltip, data, character)
   if not data or (data.bestLvl and data.bestLvl < 2 and data.chest and not data.chest.available) then
      return
   end
   local settings = Exlist.ConfigDB.settings
   local dungeonName = settings.shortenInfo and Exlist.ShortenedMPlus[data.mapId] or data.bestLvlMap or ""
   local info = {
      character = character,
      moduleName = key,
      priority = prio,
      titleName = L["Best Mythic+"]
   }
   if data.bestLvl and data.bestLvl >= 2 then
      info.data = "+" .. (data.bestLvl or "") .. " " .. dungeonName
   else
      return
   end

   if data.mapsDone and #data.mapsDone > 0 then
      local sideTooltip = { title = WrapTextInColorCode(L["Mythic+"], colors.sideTooltipTitle), body = {} }
      local maps = data.mapsDone
      for i = 1, #maps do
         table.insert(
            sideTooltip.body,
            { "+" .. maps[i].level .. " " .. maps[i].name, Exlist.FormatTime(maps[i].time) }
         )
      end
      info.OnEnter = Exlist.CreateSideTooltip()
      info.OnEnterData = sideTooltip
      info.OnLeave = Exlist.DisposeSideTooltip()
   end
   Exlist.AddData(info)
end

local function Modernize(data)
   -- data is table of module table from character
   -- always return table or don't use at all
   if not data.mapId and data.bestLvlMap then
      C_MythicPlus.RequestMapInfo() -- request update
      local mapIDs = C_ChallengeMode.GetMapTable()
      for i, id in ipairs(mapIDs) do
         if data.bestLvlMap == (C_ChallengeMode.GetMapUIInfo(id)) then
            Exlist.Debug("Added mapId", id)
            data.mapId = id
            break
         end
      end
   end
   if not data.chest then
      data.chest = {
         level = 0,
         available = false
      }
   end
   return data
end

local function ResetHandle(resetType)
   if not resetType or resetType ~= "weekly" then
      return
   end
   local realms = Exlist.GetRealmNames()
   for _, realm in ipairs(realms) do
      local characters = Exlist.GetRealmCharacters(realm)
      for _, character in ipairs(characters) do
         Exlist.Debug("Reset", resetType, "quests for:", character, "-", realm)
         local data = Exlist.GetCharacterTableKey(realm, character, key)
         if data.bestLvl and data.bestLvl >= 2 then
            data = {
               bestLvl = 0,
               chest = {
                  available = true,
                  level = data.bestLvl
               }
            }
         end
         Exlist.UpdateChar(key, data, character, realm)
      end
   end
end

local function init()
   playersName = UnitName("player")
   C_Timer.After(
      5,
      function()
         Exlist.SendFakeEvent("MYTHIC_PLUS_INIT_DELAY")
      end
   )
end

local data = {
   name = L["Mythic+"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {
      "MYTHIC_PLUS_INIT_DELAY",
      "CHALLENGE_MODE_MAPS_UPDATE",
      "CHALLENGE_MODE_LEADERS_UPDATE",
      "PLAYER_ENTERING_WORLD",
      "LOOT_CLOSED",
      "MYTHIC_PLUS_REFRESH_INFO",
      "BLIZZARD_THANKS_SMILE"
   },
   description = L["Tracks highest completed mythic+ in a week and all highest level runs per dungeon"],
   weeklyReset = true,
   init = init,
   specialResetHandle = ResetHandle,
   modernize = Modernize
}

Exlist.RegisterModule(data)
