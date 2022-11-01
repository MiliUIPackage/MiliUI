local key = "maw"
local prio = 15
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors

local TORGHAST_WIDGETS = {
  {name = 2925, level = 2930}, -- Fracture Chambers
  {name = 2926, level = 2932}, -- Skoldus Hall
  {name = 2924, level = 2934}, -- Soulforges
  {name = 2927, level = 2936}, -- Coldheart Interstitia
  {name = 2928, level = 2938}, -- Mort'regar
  {name = 2929, level = 2940} -- The Upper Reaches
}

local ASSAULT_QUESTS = {
  [63823] = {icon = "|TInterface\\ICONS\\UI_Sigil_NightFae:0:0:0:0:100:100:12:88:12:88|t"}, -- NF
  [63824] = {icon = "|TInterface\\ICONS\\UI_Sigil_Kyrian:0:0:0:0:100:100:12:88:12:88|t"}, -- Kyrian
  [63822] = {icon = "|TInterface\\ICONS\\UI_Sigil_Venthyr:0:0:0:0:100:100:12:88:12:88|t"}, -- Vethyr
  [63543] = {icon = "|TInterface\\ICONS\\UI_Sigil_Necrolord:0:0:0:0:100:100:12:88:12:88|t"} -- Necro
}

local function GetAssaultStatus()
  if (not C_QuestLog.IsQuestFlaggedCompleted(64556)) then
    -- Assaults are not available
    return
  end
  for questId, value in pairs(ASSAULT_QUESTS) do
    local data = {}
    if (C_TaskQuest.IsActive(questId)) then
      data.isComplete = false
      data.icon = value.icon
      return data
    elseif (C_QuestLog.IsQuestFlaggedCompleted(questId)) then
      data.isComplete = true
      data.icon = string.format("|T%s:0|t", Exlist.OKMark)
      return data
    end
  end
end

local function GetTormentorsStatus()
  return {
    isComplete = C_QuestLog.IsQuestFlaggedCompleted(63854)
  }
end

local function Updater(event, widgetInfo)
  local character = UnitName("player")
  local realm = GetRealmName()
  local data = Exlist.GetCharacterTableKey(realm, character, key)
  if (UnitLevel("player") < Exlist.constants.MAX_CHARACTER_LEVEL) then
    return
  end
  data.korthia = {
    assaults = GetAssaultStatus(),
    tormentors = GetTormentorsStatus()
  }

  Exlist.UpdateChar(key, data)
end

local function Linegenerator(tooltip, data, character)
  if (not data) then
    return
  end

  -- Torghast
  if (data.torghast) then
    for i, data in ipairs(data.torghast) do
      local info = {
        character = character,
        priority = prio + (i / 100),
        moduleName = key .. data.name,
        titleName = data.name:gsub("|n", ""),
        data = data.level
      }
      Exlist.AddData(info)
    end
  end

  if (data.korthia) then
    if (data.korthia.assaults) then
      Exlist.AddData(
        {
          character = character,
          priority = prio + 0.1,
          moduleName = key .. "korthia",
          titleName = L["Korthia"],
          data = string.format("|c%s%s|r: %s", colors.faded, L["Assault"], data.korthia.assaults.icon),
          colOff = 0,
          dontResize = true
        }
      )
    end
    if (data.korthia.tormentors) then
      Exlist.AddData(
        {
          character = character,
          priority = prio + 0.1,
          moduleName = key .. "korthia",
          titleName = L["Korthia"],
          data = string.format(
            "|c%s%s:|r |T%s:0|t",
            colors.faded,
            L["Tormentors"],
            data.korthia.tormentors.isComplete and Exlist.OKMark or Exlist.CancelMark
          ),
          colOff = 1,
          dontResize = true
        }
      )
    end
  end
end

local function ResetHandler(resetType)
  local realms = Exlist.GetRealmNames()
  for _, realm in ipairs(realms) do
    local characters = Exlist.GetRealmCharacters(realm)
    for _, character in ipairs(characters) do
      local data = Exlist.GetCharacterTableKey(realm, character, key)
      local essentials = Exlist.GetCharacterEssentials(realm, character)
      if (essentials.level == 60) then
        if (resetType == "weekly") then
          data.torghast = {}
        end
        Exlist.UpdateChar(key, data, character, realm)
      end
    end
  end
end

local function Modernize(data)
  if (data and data.torghast) then
    data.torghast = nil
  end

  return data
end

local data = {
  name = L["Maw"],
  key = key,
  linegenerator = Linegenerator,
  priority = prio,
  updater = Updater,
  event = {"UPDATE_UI_WIDGET", "PLAYER_ENTERING_WORLD", "QUEST_TURNED_IN", "QUEST_REMOVED"},
  weeklyReset = true,
  dailyReset = true,
  description = L["Track Torghast and Korthia/Maw weeklies"],
  specialResetHandle = ResetHandler,
  modernize = Modernize
}

Exlist.RegisterModule(data)
