local key = "maw"
local prio = 15
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors
--local strings = Exlist.Strings

local MAW_WIDGETS = {
  [2359] = 2873,
  [2360] = 2874,
  [2361] = 2875,
  [2362] = 2876,
  [2363] = 2877
}

local EOJ_STAGES = {
  [2359] = 0,
  [2360] = 1,
  [2361] = 2,
  [2362] = 3,
  [2363] = 4
}

local STAGE_COLORS = {
  [0] = "ffffffff",
  [1] = "fff5ff82",
  [2] = "fff5dd42",
  [3] = "fff5aa42",
  [4] = "fff56642",
  [5] = "ffff0000"
}

local TORGHAST_WIDGETS = {
  {name = 2925, level = 2930}, -- Fracture Chambers
  {name = 2926, level = 2932}, -- Skoldus Hall
  {name = 2924, level = 2934}, -- Soulforges
  {name = 2927, level = 2936}, -- Coldheart Interstitia
  {name = 2928, level = 2938}, -- Mort'regar
  {name = 2929, level = 2940} -- The Upper Reaches
}

local function GetStageString(stage, stageProgress)
  if (stageProgress >= 100) then
    stage = stage + 1
  end
  return string.format("|c%s%s %i|r", STAGE_COLORS[stage or 0], L["Tier"], stage)
end

local function GetEyeOfTheJailerProgress(widgetId)
  local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(widgetId)
  local stage = EOJ_STAGES[widgetId] or 0
  if (info.barValue == 0) then
    -- Returns as 0 when returning to Oribos
    -- Cant catch it by zoneId as we are still in maw theoretically
    return false
  end
  local stageProgress = info.barValue - info.barMin
  return {
    stage = stage or 0,
    stageProgress = stageProgress > 0 and stageProgress or 0,
    stageMax = info.barMax - info.barMin,
    tooltip = info.tooltip
  }
end

local function FindEyeOfTheJailerWidget()
  for widgetId, shownWidgetId in pairs(MAW_WIDGETS) do
    local info = C_UIWidgetManager.GetTextureWithAnimationVisualizationInfo(shownWidgetId)

    if (info and info.shownState == 1) then
      return GetEyeOfTheJailerProgress(widgetId)
    end
  end
  return false
end

local function GetTorghastProgress()
  local data = {}
  for _, widgets in ipairs(TORGHAST_WIDGETS) do
    local nameData = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widgets.name)
    if (nameData.shownState == 1) then
      -- Available this week
      local levelData = C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(widgets.level)
      if (levelData) then
        table.insert(
          data,
          {
            name = nameData.text,
            level = levelData.shownState == 1 and levelData.text or
              string.format("|c%s%s|r", colors.torghastAvailable, L["Available"])
          }
        )
      end
    end
  end

  return data
end

local function Updater(event, widgetInfo)
  local character = UnitName("player")
  local realm = GetRealmName()
  local data = Exlist.GetCharacterTableKey(realm, character, key)
  if (UnitLevel("player") < Exlist.constants.MAX_CHARACTER_LEVEL) then
    return
  end
  if (event == "UPDATE_UI_WIDGET") then
    local widgetId = widgetInfo and widgetInfo.widgetID
    if (widgetInfo and MAW_WIDGETS[widgetId]) then
      local widget = MAW_WIDGETS[widgetId]
      local widgetInfo = C_UIWidgetManager.GetTextureWithAnimationVisualizationInfo(widget)
      if (widgetInfo and widgetInfo.shownState == 1) then
        data.eoj = GetEyeOfTheJailerProgress(widgetId) or data.eoj
      end
    end
  else
    local eojData = FindEyeOfTheJailerWidget()

    if (eojData) then
      data.eoj = eojData
    end
  end
  data.torghast = GetTorghastProgress() or data.torghast
  Exlist.UpdateChar(key, data)
end

local function Linegenerator(tooltip, data, character)
  if (not data) then
    return
  end
  -- Maw - Eye of the Jailer
  if (data.eoj) then
    local stageProgress = (data.eoj.stageProgress / data.eoj.stageMax) * 100
    local info = {
      character = character,
      priority = prio,
      moduleName = key,
      titleName = L["Eye of the Jailer"],
      data = string.format(
        "%s %.1f%%",
        GetStageString(data.eoj.stage, stageProgress),
        stageProgress >= 100 and 0 or stageProgress
      )
      -- colOff = 0,
      -- dontResize = false,
      -- pulseAnim = false,
      -- OnClick = function() end,
      -- OnClickData = {},
    }

    if (data.eoj.tooltip) then
      info.OnEnter = Exlist.CreateSideTooltip()
      info.OnEnterData = {
        body = {
          data.eoj.tooltip
        },
        title = GetStageString(data.eoj.stage, stageProgress)
      }
      info.OnLeave = Exlist.DisposeSideTooltip()
    end
    Exlist.AddData(info)
  end

  -- Torghast
  if (data.torghast) then
    for i, data in ipairs(data.torghast) do
      local info = {
        character = character,
        priority = prio + (i / 10),
        moduleName = key .. data.name,
        titleName = data.name:gsub("|n", ""),
        data = data.level
      }
      Exlist.AddData(info)
    end
  end
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
local function ResetHandler(resetType)
  -- code that will be run at reset for this module
  -- instead of just wiping all data that is keyed
  -- by this module key
  local realms = Exlist.GetRealmNames()
  for _, realm in ipairs(realms) do
    local characters = Exlist.GetRealmCharacters(realm)
    for _, character in ipairs(characters) do
      local data = Exlist.GetCharacterTableKey(realm, character, key)
      local essentials = Exlist.GetCharacterEssentials(realm, character)
      if (essentials.level == 60) then
        -- Reset Eye of the Jailer debuff progress
        if (resetType == "daily") then
          data.eoj = {
            stage = 0,
            stageProgress = 0,
            stageMax = 1000
          }
        end
        if (resetType == "weekly") then
          data.torghast = {}
        end
        Exlist.UpdateChar(key, data, character, realm)
      end
    end
  end
end

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
  name = L["Maw"],
  key = key,
  linegenerator = Linegenerator,
  priority = prio,
  updater = Updater,
  event = {"UPDATE_UI_WIDGET", "PLAYER_ENTERING_WORLD"},
  weeklyReset = true,
  dailyReset = true,
  description = L["Track eye of the jailer buff for the player and Torghast"],
  -- globallgenerator = GlobalLineGenerator,
  -- type = 'customTooltip'
  -- modernize = Modernize,
  -- init = init,
  -- override = true,
  specialResetHandle = ResetHandler
}

Exlist.RegisterModule(data)
