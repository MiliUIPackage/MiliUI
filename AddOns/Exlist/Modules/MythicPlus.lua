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
local mapTimes = {
  --[mapId] = {+1Time,+2Time,+3Time} in seconds
  --BFA
  [244] = {1800,1440,1080}, -- Atal'dazar
  [245] = {2160,1728,1296}, -- Freehold
  [246] = {1980,1584,1188}, -- Tol Dagor
  [247] = {2340,1872,1404}, -- The MOTHERLODE!!
  [248] = {2340,1872,1404}, -- Waycrest Manor
  [249] = {2340,1872,1404}, -- Kings' Rest
  [250] = {2160,1728,1296}, -- Temple of Sethraliss
  [251] = {1800,1440,1080}, -- The Underrot
  [252] = {2340,1872,1404}, -- Shrine of the Storm
  [353] = {2160,1728,1296}, -- Siege of Boralus

  [197] = {2100,1680,1260}, -- Eye of Azshara
  [198] = {1800,1440,1080}, -- Darkheart Thicket
  [199] = {2340,1872,1405}, -- BRH
  [200] = {2700,2160,1620}, -- HoV
  [206] = {1980,1584,1188}, -- Nelth
  [207] = {1980,1584,1188}, -- VotW
  [208] = {1440,1152,864},  -- Maw
  [209] = {2700,2160,1620}, -- Arc
  [210] = {1800,1440,1080}, -- CoS
  [227] = {2340,1872,1404}, -- Kara: Lower
  [233] = {2100,1680,1260}, -- Cath
  [234] = {2100,1680,1260}, -- Kara: Upper
  [239] = {2100,1680,1260}, -- Seat
}
local mapIds = {}

local function IsItPlayersRun(members)
  for i=1, #members do
    if members[i].name == playersName then
      return true
    end
  end
  return false
end

local gotEvent = false
local function Updater(event)
  if not C_MythicPlus.IsMythicPlusActive() then return end -- if mythic+ season isn't active
  -- make sure code is run after data is received
  if not gotEvent and event ~="CHALLENGE_MODE_MAPS_UPDATE" then
    C_Timer.After(1,function() Exlist.SendFakeEvent('FUCK_YOU_BLIZZARD') end)
  end
  if event == "MYTHIC_PLUS_INIT_DELAY" then
    initialized = 1
  end
  if initialized < 1 then return end
  if not IsAddOnLoaded("Blizzard_ChallengesUI") then
    LoadAddOn("Blizzard_ChallengesUI")
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
    local mapTime, mapLevel,_,_,members = C_MythicPlus.GetWeeklyBestForMap(mapIds[i])
    -- add to completed dungeons
    local mapName = C_ChallengeMode.GetMapUIInfo(mapIds[i])
    if mapLevel then
      -- wonderful api you got there
      -- getting other character M+ info and shit
      if not IsItPlayersRun(members) then return end
      table.insert(dungeons,{ mapId = mapIds[i], name = mapName, level = mapLevel, time = mapTime })
    end
    -- check if best map this week
    if mapLevel and mapLevel > bestLevel then
      bestLevel = mapLevel
      bestMapId = mapIds[i]
      bestMap = mapName
    end
  end
  -- sort maps by level descending
  table.sort(dungeons,function(a,b) return a.level > b.level end)

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
    },
  }
  -- check for available weekly chest
  if C_MythicPlus.IsWeeklyRewardAvailable() then
    local _,level = C_MythicPlus.GetLastWeeklyBestInformation()
    t.chest = {
      available = true,
      level = level
    }
  end

  Exlist.UpdateChar(key,t)
end

local function MythicPlusTimeString(time,mapId)
  if not time or not mapId then return end
  local times = mapTimes[mapId] or {}
  local rstring = ""
  local secTime = time
  local colors = colors.mythicplus.times
  for i=1, #times do
    if secTime > times[i] then
      if i == 1 then return WrapTextInColorCode("("..L["Depleted"]..") " .. Exlist.FormatTime(secTime),colors[i])
      else return WrapTextInColorCode("(+".. (i-1) .. ") " .. Exlist.FormatTime(secTime),colors[i]) end
    end
  end
  return WrapTextInColorCode("(+3) " .. Exlist.FormatTime(time),colors[#colors])
end

local function Linegenerator(tooltip,data,character)
  if not data or (data.bestLvl and data.bestLvl < 2 and data.chest and not data.chest.available) then return end
  local settings = Exlist.ConfigDB.settings
  local dungeonName = settings.shortenInfo and Exlist.ShortenedMPlus[data.mapId] or data.bestLvlMap or ""
  local info = {
    character = character,
    moduleName = key,
    priority = prio,
    titleName = L["Best Mythic+"],
  }
  if data.chest and data.chest.available then
    info.data = WrapTextInColorCode(
      string.format("+%i %s",data.chest.level,L["Chest Available"]),
      colors.available
    )
    info.pulseAnim = true
  elseif data.bestLvl and data.bestLvl >= 2 then
    info.data = "+" .. (data.bestLvl or "") .. " " .. dungeonName
  else
    return
  end

  if data.mapsDone and #data.mapsDone > 0 then
    local sideTooltip = {title = WrapTextInColorCode(L["Mythic+"],colors.sideTooltipTitle), body = {}}
    local maps = data.mapsDone
    for i=1, #maps do
      table.insert(sideTooltip.body,{"+" .. maps[i].level .. " " .. maps[i].name,MythicPlusTimeString(maps[i].time,maps[i].mapId)})
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
    for i,id in ipairs(mapIDs) do
      if data.bestLvlMap == (C_ChallengeMode.GetMapUIInfo(id)) then
        Exlist.Debug("Added mapId",id)
        data.mapId = id
        break
      end
    end
  end
  if not data.chest then
    data.chest = {
      level = 0,
      available = false,
    }
  end
  return data
end

local function ResetHandle(resetType)
  if not resetType or resetType ~= "weekly" then return end
  local realms = Exlist.GetRealmNames()
  for _,realm in ipairs(realms) do
    local characters = Exlist.GetRealmCharacters(realm)
    for _,character in ipairs(characters) do
      Exlist.Debug("Reset",resetType,"quests for:",character,"-",realm)
      local data = Exlist.GetCharacterTableKey(realm,character,key)
      if data.bestLvl and data.bestLvl >= 2 then
        data = {
          bestLvl = 0,
          chest = {
            available = true,
            level = data.bestLvl
          }
        }
      end
      Exlist.UpdateChar(key,data,character,realm)
    end
  end
end

local function init()
  playersName = UnitName("player")
  C_Timer.After(5,function() Exlist.SendFakeEvent("MYTHIC_PLUS_INIT_DELAY") end)
end

local data = {
  name = L['Mythic+'],
  key = key,
  linegenerator = Linegenerator,
  priority = prio,
  updater = Updater,
  event = {"MYTHIC_PLUS_INIT_DELAY","CHALLENGE_MODE_MAPS_UPDATE","CHALLENGE_MODE_LEADERS_UPDATE","PLAYER_ENTERING_WORLD","LOOT_CLOSED","MYTHIC_PLUS_REFRESH_INFO","FUCK_YOU_BLIZZARD"},
  description = L["Tracks highest completed mythic+ in a week and all highest level runs per dungeon"],
  weeklyReset = true,
  init = init,
  specialResetHandle = ResetHandle,
  modernize = Modernize
}

Exlist.RegisterModule(data)
