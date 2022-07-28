local key = "covenant"
local prio = 1
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors
--local strings = Exlist.Strings

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

local function Updater(event)
  local character = UnitName("player")
  local realm = GetRealmName()
  local data = Exlist.GetCharacterTableKey(realm, character, key)
  local covenantId = C_Covenants.GetActiveCovenantID()
  local covenantData = C_Covenants.GetCovenantData(covenantId)
  local renownLevel = C_CovenantSanctumUI.GetRenownLevel()
  data.id = covenantId
  data.name = covenantData.name
  data.renownLevel = renownLevel

  if (event == "COVENANT_SANCTUM_INTERACTION_STARTED") then
    -- Get TreeIds for sanctum upgrades
    data.features = GetFeatureData(GetFeatureIds())
  end

  Exlist.UpdateChar(key, data)
end

local function Linegenerator(tooltip, data, character)
  if not data then
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

--[[
local function GlobalLineGenerator(tooltip,data)

end
]]
--[[
local function customGenerator(tooltip, data)

end
]]
--[[
local function Modernize(data)
  -- data is table of module table from character
  -- always return table or don't use at all
  return data
end
]]
--[[
local function init()
  -- code that will run before any other function
end
]]
--[[
local function ResetHandler(resetType)
  -- code that will be run at reset for this module
  -- instead of just wiping all data that is keyed
  -- by this module key
end
]]
--[[
local function AddOptions()
  local options = {
    type = "group",
    name = L["Reputations"],
    args = {}
  }
  Exlist.AddModuleOptions(key,options,L["Reputation"])
end
Exlist.ModuleToBeAdded(AddOptions)
]]
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
    "COVENANT_SANCTUM_INTERACTION_STARTED"
  },
  weeklyReset = false,
  dailyReset = false,
  description = L["Tracks various information about characters covnenant"]
  -- globallgenerator = GlobalLineGenerator,
  -- type = 'customTooltip'
  -- modernize = Modernize,
  -- init = init,
  -- override = true,
  -- specialResetHandle = ResetHandler
}

Exlist.RegisterModule(data)
