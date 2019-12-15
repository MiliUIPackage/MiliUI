local key = "worldboss"
local prio = 120
local Exlist = Exlist
local colors = Exlist.Colors
local L = Exlist.L
local EJ_GetEncounterInfo = EJ_GetEncounterInfo
local UnitLevel,GetRealmName,UnitName = UnitLevel,GetRealmName,UnitName
local IsQuestFlaggedCompleted = IsQuestFlaggedCompleted
local WrapTextInColorCode = WrapTextInColorCode
local string,table = string,table
local C_TaskQuest, C_WorldMap, EJ_GetCreatureInfo,C_ContributionCollector, C_Timer = C_TaskQuest, C_WorldMap ,EJ_GetCreatureInfo, C_ContributionCollector, C_Timer
local pairs,ipairs,time,select = pairs,ipairs,time,select
local GetTime = GetTime
local IsInRaid, IsInInstance = IsInRaid, IsInInstance
local GetCurrentMapAreaID, SetMapByID,GetMapNameByID = GetCurrentMapAreaID, SetMapByID,GetMapNameByID
local GetNumMapLandmarks, GetMapLandmarkInfo = GetNumMapLandmarks, GetMapLandmarkInfo
local GetSpellInfo = GetSpellInfo
local GameTooltip = GameTooltip

local worldBossIDs = {
  --[questId] = {encounterId, name,endtime}
  --[[
  [42270] = {eid = 1749}, -- Nithogg
  [42269] = {eid = 1756, name = EJ_GetEncounterInfo(1756)}, -- The Soultakers
  [42779] = {eid = 1763}, -- Shar'thos
  [43192] = {eid = 1769}, -- Levantus
  [42819] = {eid = 1770}, -- Humongris
  [43193] = {eid = 1774}, -- Calamir
  [43513] = {eid = 1783}, -- Na'zak the Fiend
  [43448] = {eid = 1789}, -- Drugon the Frostblood
  [43512] = {eid = 1790}, -- Ana-Mouz
  [43985] = {eid = 1795}, -- Flotsam
  [44287] = {eid = 1796}, -- Withered Jim
  [47061] = {eid = 1956, endTime = 0}, -- Apocron
  [46947] = {eid = 1883, endTime = 0}, -- Brutalus
  [46948] = {eid = 1884, endTime = 0}, -- Malificus
  [46945] = {eid = 1885, endTime = 0}, -- Si'vash
  [49167] = {eid = 2011}, -- Mistress Alluradel
  [49170] = {eid = 2013}, -- Occularus
  [49168] = {eid = 2015}, -- Pit Lord Vilemus
  [49166] = {eid = 2012}, -- Inquisitor Meto
  [49171] = {eid = 2014}, -- Sotanathor
  [49169] = {eid = 2010, name=EJ_GetEncounterInfo(2010)}, -- Matron Foluna
  ]] -- TODO: Decide if we want to track old WorldBosses
  -- BFA
  [52847] = {eid = 2213,warfront = 'Arathi'}, -- Doom's Howl
  [52848] = {eid = 2212,warfront = 'Arathi'}, -- The Lion's Roar
  [52196]  = {eid = 2210}, -- Dunegorger Kraulok
  [52181] =  {eid = 2139}, -- T'zane
  [52169] =  {eid = 2141}, -- Ji'arak
  [52157] =  {eid = 2197}, -- Hailstone Construct
  [52163] =  {eid = 2199}, -- Azurethos, The Winged Typhoon
  [52166] =  {eid = 2198}, -- Warbringer Yenajz
  [54896] = {eid = 2329, warfront = 'Darkshore'}, -- Ivus the Forest Lord
  [54895] = {eid = 2345, warfront = 'Darkshore'} -- Ivus the Decayed
}
local lastUpdate = 0
local unknownIcon = "Interface\\ICONS\\INV_Misc_QuestionMark"
local warfronts = {
  Arathi = {
    Horde = 11,
    Alliance = 116
  },
  Darkshore = {
    Alliance = 117,
    Horde = 118
  }
}

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

local statusMarks = {
  [true] = [[Interface/Addons/Exlist/Media/Icons/ok-icon]],
  [false] = [[Interface/Addons/Exlist/Media/Icons/cancel-icon]]
}
local function AddCheckmark(text,status)
  return string.format("|T%s:0|t %s",statusMarks[status],text)
end

local factions = {'Horde', 'Alliance'}
local function OpossiteFacton(faction)
  return factions[1] ~= faction and factions[1] or factions[2]
end

local function GetWarfrontEnd(warfront)
  local faction = UnitFactionGroup('player')
  local state, pctComplete, timeNext, timeStart = C_ContributionCollector.GetState(warfronts[warfront][faction])
  if state == 2 then
    return { value = timeNext, type = 'time' }
  elseif state == 1 and pctComplete < 1 then
    return { value = pctComplete, type = 'pct' }
  else
    state, pctComplete, timeNext, timeStart = C_ContributionCollector.GetState(warfronts[warfront][OpossiteFacton(faction)])
    if state == 1 then
      return { value = pctComplete, type = 'pct' }
    end
  end
end

local function FormatEndTime(timeInfo)
  local timeNow = time()
  if type(timeInfo) == 'table' then
    if timeInfo.type == 'pct' then
      return string.format("%.1f%%",timeInfo.value*100)
    else
      return Exlist.TimeLeftColor(timeInfo.value-timeNow)
    end
  else
    return Exlist.TimeLeftColor(timeInfo-timeNow)
  end
end

local function GetWarfrontStatus()
  local t = {}
  for wf, ids in pairs(warfronts) do
    t[wf] = {}
      for faction, id in pairs(ids) do
        local state, pctComplete, timeNext, timeStart = C_ContributionCollector.GetState(id)
        local appearanceData = C_ContributionCollector.GetContributionAppearance(id, state)
        local name = C_ContributionCollector.GetName(id)
        t[wf][faction] = {
          name = name,
          faction = faction,
          state = state,
          stateName = appearanceData.stateName,
          contributed = pctComplete,
          timeNext = timeNext,
          timeStart = timeStart
        }
      end
  end

  return t
end

local function Updater(e,info)
  if e == "WORLD_QUEST_SPOTTED" and #info > 0 then
    -- got info from WQ module
    local t = Exlist.GetCharacterTableKey((GetRealmName()),(UnitName('player')),key)
    local gt = Exlist.GetCharacterTableKey("global","global",key)
    gt.worldbosses = gt.worldbosses or {}
    local db = gt.worldbosses
    for _,wq in ipairs(info) do
      local defaultInfo = worldBossIDs[wq.questId]
      if defaultInfo then
        local endTime = defaultInfo.warfront and GetWarfrontEnd(defaultInfo.warfront) or wq.endTime
        t[wq.questId] = {
          name = defaultInfo.name or select(2,EJ_GetCreatureInfo(1,defaultInfo.eid)),
          defeated = IsQuestFlaggedCompleted(wq.questId),
          endTime = endTime,
        }
        db[wq.questId] = {
          name = defaultInfo.name or select(2,EJ_GetCreatureInfo(1,defaultInfo.eid)),
          endTime = endTime,
          zoneId = wq.zoneId,
          questId = wq.questId
        }
      end
    end
    Exlist.UpdateChar(key,t)
    Exlist.UpdateChar(key,gt,'global','global')
    return
  elseif not( IsPlayerAtEffectiveMaxLevel() ) or
    GetTime() - lastUpdate < 5 or
    IsInRaid() or
    select(2,IsInInstance()) ~= "none"
  then
    -- Check for cached WB kill status
    local t = Exlist.GetCharacterTableKey((GetRealmName()),(UnitName("player")),key)
    local changed = false
    for questId,info in pairs(t) do
      if not info.defeated and IsQuestFlaggedCompleted(questId) then
        t[questId].defeated = true
        changed = true
      end
    end
    if changed then Exlist.UpdateChar(key,t) end
    return
  end
  if e == "PLAYER_ENTERING_WORLD" or e == "EJ_DIFFICULTY_UPDATE" then
    C_Timer.After(1,function() Exlist.SendFakeEvent("PLAYER_ENTERING_WORLD_DELAYED") end) -- delay update
    return
  end
  lastUpdate = GetTime()
  local t = Exlist.GetCharacterTableKey((GetRealmName()),(UnitName('player')),key)
  local gt = Exlist.GetCharacterTableKey("global","global",key)
  gt.worldbosses = gt.worldbosses or {}
  local timeNow = time()
  -- Check global
  for questId,info in pairs(gt.worldbosses) do
    if not t[questId] then
      local defaultInfo = worldBossIDs[questId]
      if defaultInfo then
        t[questId] = {
          name = info.name or "",
          defeated = IsQuestFlaggedCompleted(questId),
          endTime = info.endTime,
        }
      end
    end
  end

  -- Warfronts
  gt.warfronts = GetWarfrontStatus()

  Exlist.UpdateChar(key,t)
  Exlist.UpdateChar(key,gt,'global','global')
end

local function Linegenerator(tooltip,data,character)
  if not data then return end

  local availableWB = 0
  local killed = 0
  local strings = {}
  local timeNow = time()
  for spellId,info in pairs(data) do
    availableWB = availableWB + 1
    killed = info.defeated and killed + 1 or killed
    table.insert(strings,{
      string.format("%s (%s)",
        info.name,
        info.endTime and (type(info.endTime) == 'table' or info.endTime > timeNow) and FormatEndTime(info.endTime)
        or WrapTextInColorCode(L["Not Available"],colors.notavailable
        )
      ),
      info.defeated and WrapTextInColorCode(L["Defeated"],colors.completed) or WrapTextInColorCode(L["Available"],colors.available)})
  end
  if availableWB > 0 then
    local sideTooltip = {body = strings,title=WrapTextInColorCode(L["World Bosses"],colors.sideTooltipTitle)}
    local info = {
      character = character,
      moduleName = key,
      priority = prio,
      titleName = WrapTextInColorCode(L["World Bosses"],colors.faded),
      data = string.format("%i/%i",killed,availableWB),
      OnEnter = Exlist.CreateSideTooltip(),
      OnEnterData = sideTooltip,
      OnLeave = Exlist.DisposeSideTooltip()
    }
    Exlist.AddData(info)
  end
end

local function GetWFCurrentStatus(wf)
  local faction = UnitFactionGroup('player')
  local tmp = wf[faction]
  for f, data in pairs(wf) do
    if faction ~= f then
      -- states: 1 - contributing, 2 - siege, 3 - ??, 4 - patrol
      if data.state == 1 or data.state == 2 then
        tmp = data
      end
    end
  end
  local stateName = tmp.stateName
  if tmp.state == 1 or tmp.state == 2 then
    stateName = L[tmp.faction] .. ' ' .. stateName
  end
  return tmp.name, stateName, tmp.timeNext and tmp.timeNext - time(), tmp.contributed
end

local function GlobalLineGenerator(tooltip,data)
  local timeNow = time()
  if not data then return end
  if data.worldbosses and Exlist.ConfigDB.settings.extraInfoToggles.worldbosses.enabled then
    local added = false
    for questId,info in pairs(data.worldbosses) do
      if type(info.endTime) == 'table' or info.endTime > timeNow then
        if not added then
          added = true
          Exlist.AddLine(tooltip,{WrapTextInColorCode(L["World Bosses"],colors.sideTooltipTitle)},14)
        end
        local lineNum = Exlist.AddLine(tooltip,{
          AddCheckmark(info.name,IsQuestFlaggedCompleted(questId)),
          FormatEndTime(info.endTime)})
        Exlist.AddScript(tooltip,lineNum,nil,"OnMouseDown",function(self)
          if not WorldMapFrame:IsShown() then
            ToggleWorldMap()
          end
          WorldMapFrame:SetMapID(info.zoneId)
          BonusObjectiveTracker_TrackWorldQuest(questId)
        end)
      end
    end
  end
  if data.warfronts and Exlist.ConfigDB.settings.extraInfoToggles.warfronts.enabled then
    Exlist.AddLine(tooltip,{WrapTextInColorCode(L["Warfronts"],colors.sideTooltipTitle)},14)
    local faction = UnitFactionGroup('player')
    local addedWF = {}
    for wf, wfData in pairs(data.warfronts) do
      local name,stateName,timeLeft,pct = GetWFCurrentStatus(wfData)
      Exlist.AddLine(tooltip,{
        name,
        stateName,
        pct < 1 and string.format("%.1f%%", pct*100) or Exlist.TimeLeftColor(timeLeft)
      })
    end
  end
end

local function init()
  local t = {}
  for questId in pairs(worldBossIDs) do
    t[#t+1] = questId
  end
  Exlist.RegisterWorldQuests(t,true)
  Exlist.ConfigDB.settings.extraInfoToggles.worldbosses = Exlist.ConfigDB.settings.extraInfoToggles.worldbosses or {
    name = L["World Bosses"],
    enabled = true,
  }
  Exlist.ConfigDB.settings.extraInfoToggles.warfronts = Exlist.ConfigDB.settings.extraInfoToggles.warfronts or {
    name = L["Warfronts"],
    enabled = true,
  }
  -- BFA Prepatch Retire
  Exlist.ConfigDB.settings.extraInfoToggles.invasions = nil
  Exlist.ConfigDB.settings.extraInfoToggles.brokenshore = nil

  local gt = Exlist.GetCharacterTableKey("global","global",key)
  if gt.worldbosses and gt.worldbosses.argus then
    local t = {}
    for _,quests in pairs(gt.worldbosses) do
      for questId,info in pairs(quests) do
        t[questId] = info
      end
    end
    gt.worldbosses = t
    Exlist.UpdateChar(key,gt,"global","global")
  end

end




local data = {
  name = L['World Bosses'],
  key = key,
  linegenerator = Linegenerator,
  globallgenerator = GlobalLineGenerator,
  priority = prio,
  updater = Updater,
  event = {"PLAYER_ENTERING_WORLD","EJ_DIFFICULTY_UPDATE","PLAYER_ENTERING_WORLD_DELAYED","WORLD_QUEST_SPOTTED"},
  description = L["Tracks World Boss availability for each character."],
  weeklyReset = true,
  init = init,
}

Exlist.RegisterModule(data)
