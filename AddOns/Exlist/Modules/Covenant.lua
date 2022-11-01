local key = "covenant"
local prio = 1
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors

local ANIMA_QUESTS = {61984, 61981, 61982, 61983}

local function colorProgress(curr, target)
  local perc = curr / target
  if (perc < 0.3) then
    return "fffc3503"
  elseif (perc < 0.7) then
    return "FFfc8403"
  elseif (perc < 0.99) then
    return "ffa1fc03"
  else
    return "ff00ff00"
  end
end

local function GetCurrentTier(talents)
  local currentTier = 0
  for i, talentInfo in ipairs(talents) do
    if talentInfo.talentAvailability == Enum.GarrisonTalentAvailability.UnavailableAlreadyHave then
      currentTier = currentTier + 1
    end
  end
  return currentTier
end

local function GetRemainingUpgradeTime(talents)
  for i, talentInfo in ipairs(talents) do
    if talentInfo.isBeingResearched and not talentInfo.hasInstantResearch then
      return talentInfo.timeRemaining
    end
  end
end

local function GetFeatureIds()
  local data = {}
  local features = C_CovenantSanctumUI.GetFeatures()
  for _, featureInfo in ipairs(features) do
    if (featureInfo.featureType ~= Enum.GarrTalentFeatureType.ReservoirUpgrades) then -- Ignore anima storage
      table.insert(
        data,
        {
          treeId = featureInfo.garrTalentTreeID
        }
      )
    end
  end

  return data
end

local function GetFeatureData(features)
  if not features then
    return
  end
  for _, data in ipairs(features) do
    if (data.treeId) then
      local treeInfo = C_Garrison.GetTalentTreeInfo(data.treeId)
      data.name = treeInfo.title
      local tier = GetCurrentTier(treeInfo.talents)
      data.tier = data.tier and data.tier > tier and data.tier or tier -- Make Sure data has been loaded?
      local remainingTime = GetRemainingUpgradeTime(treeInfo.talents)
      data.endTime = remainingTime and time() + remainingTime
    end
  end
  return features
end

local function GetWeeklyRenownQuestProgress()
  local data = {}
  -- Shaping Fate (63949)
  if (C_TaskQuest.IsActive(63949)) then
    table.insert(
      data,
      {
        completed = false,
        progress = string.format("%i%%", GetQuestProgressBarPercent(63949)),
        progressColor = colorProgress(GetQuestProgressBarPercent(63949), 100),
        name = L["Korthia"],
        turnIn = GetQuestProgressBarPercent(63949) / 100 == 1
      }
    )
  elseif (C_QuestLog.IsQuestFlaggedCompleted(63949)) then
    table.insert(
      data,
      {
        completed = true,
        name = L["Korthia"]
      }
    )
  end

  -- Anima
  for _, questId in ipairs(ANIMA_QUESTS) do
    if (C_QuestLog.IsOnQuest(questId)) then
      local objective = C_QuestLog.GetQuestObjectives(questId)[1]
      table.insert(
        data,
        {
          completed = false,
          progress = string.format("%i/%i", objective.numFulfilled, objective.numRequired),
          progressColor = colorProgress(objective.numFulfilled, objective.numRequired),
          name = L["Anima"],
          turnIn = objective.numFulfilled / objective.numRequired == 1
        }
      )
    elseif (C_QuestLog.IsQuestFlaggedCompleted(questId)) then
      table.insert(
        data,
        {
          completed = true,
          name = L["Anima"]
        }
      )
    end
  end

  return data
end

local function Updater(event)
  local character = UnitName("player")
  local realm = GetRealmName()
  if (UnitLevel("player") < Exlist.constants.MAX_CHARACTER_LEVEL) then
    return
  end
  local data = Exlist.GetCharacterTableKey(realm, character, key)
  local covenantId = C_Covenants.GetActiveCovenantID()
  local covenantData = C_Covenants.GetCovenantData(covenantId)
  local renownLevel = C_CovenantSanctumUI.GetRenownLevel()
  data.id = covenantId
  if (covenantData) then
    data.name = covenantData.name
  end
  data.renownLevel = renownLevel

  if (event == "COVENANT_SANCTUM_INTERACTION_STARTED") then
    -- Get TreeIds for sanctum upgrades
    data.features = GetFeatureData(GetFeatureIds())
  end

  Exlist.UpdateChar(key, data)
end

local function Linegenerator(tooltip, data, character)
  if not data or data.id == 0 then
    return
  end
  local covenantString =
    string.format("|c%s%s (%s %i)|r", colors.covenant[data.id], data.name, L["Renown"], data.renownLevel)
  local info = {
    character = character,
    priority = prio,
    moduleName = key,
    titleName = L["Covenant"],
    data = covenantString
  }

  if (data.features) then
    info.OnEnter = Exlist.CreateSideTooltip()
    info.OnLeave = Exlist.DisposeSideTooltip()
    local sideData = {
      title = covenantString,
      body = {}
    }

    for _, feature in ipairs(data.features) do
      local upgradeString = ""
      if (feature.endTime) then
        local remaining = feature.endTime - time()
        upgradeString =
          string.format(
          " (%s%s|c%s%s|r)",
          remaining > 0 and L["Upgrading"] or "",
          remaining > 0 and " " or "",
          remaining > 0 and Exlist.GetTimeLeftColor(remaining) or colors.available,
          remaining > 0 and Exlist.FormatTime(remaining) or L["Upgrade Ready"]
        )
      end
      local row = {feature.name, string.format("%s %i%s", L["Tier"], feature.tier or 0, upgradeString)}
      table.insert(sideData.body, row)
    end

    info.OnEnterData = sideData
  end

  Exlist.AddData(info)
end

local data = {
  name = L["Covenant"],
  key = key,
  linegenerator = Linegenerator,
  priority = prio,
  updater = Updater,
  event = {
    "PLAYER_ENTERING_WORLD",
    "COVENANT_SANCTUM_RENOWN_LEVEL_CHANGED",
    "COVENANT_RENOWN_INTERACTION_STARTED",
    "COVENANT_CHOSEN",
    "COVENANT_SANCTUM_INTERACTION_STARTED",
    "QUEST_TURNED_IN",
    "QUEST_REMOVED",
    "QUEST_ACCEPTED"
  },
  weeklyReset = false,
  dailyReset = false,
  description = L["Tracks various information about characters covnenant"]
}

Exlist.RegisterModule(data)
