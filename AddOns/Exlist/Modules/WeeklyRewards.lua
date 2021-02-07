local key = "weeklyrewards"
local prio = 12
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors
-- local strings = Exlist.Strings

local rewardTypes = {
   [Enum.WeeklyRewardChestThresholdType.Raid] = {title = L["Raid"], prio = 1},
   [Enum.WeeklyRewardChestThresholdType.MythicPlus] = {
      title = L["Mythic+"],
      prio = 2
   },
   [Enum.WeeklyRewardChestThresholdType.RankedPvP] = {title = "PvP", prio = 3}
}

local function getActivitiesByType(type, activities)
   local sortedActivities = {}
   for _, activity in ipairs(activities or {}) do
      if activity.type == type then
         table.insert(sortedActivities, activity)
      end
   end

   table.sort(
      sortedActivities,
      function(a, b)
         return a.index < b.index
      end
   )
   return sortedActivities
end

local function formatLevel(type, level)
   if type == Enum.WeeklyRewardChestThresholdType.MythicPlus then
      return string.format("+%s", level)
   elseif type == Enum.WeeklyRewardChestThresholdType.Raid then
      return DifficultyUtil.GetDifficultyName(level)
   elseif type == Enum.WeeklyRewardChestThresholdType.RankedPvP then
      return PVPUtil.GetTierName(level)
   end
   return level
end

local function getCurrentIlvl(id)
   local exampleItem, upgradeItem = C_WeeklyRewards.GetExampleRewardItemHyperlinks(id)
   local data = {}

   if exampleItem then
      data.ilvl = GetDetailedItemLevelInfo(exampleItem)
   end
   if upgradeItem then
      data.upgradeIlvl = GetDetailedItemLevelInfo(upgradeItem)
   end

   return data
end

local function getActivityTooltip(id, type, progress, threshold)
   local sideTooltip = {body = {}}
   local ilvls = getCurrentIlvl(id)

   if ilvls.ilvl then
      table.insert(sideTooltip.body, {L["Current"], string.format("%s %s", ilvls.ilvl, L["ilvl"])})
   end
   if ilvls.upgradeIlvl then
      table.insert(sideTooltip.body, {L["Upgrade"], string.format("%s %s", ilvls.upgradeIlvl, L["ilvl"])})
   end

   local typeName = ""

   if type == Enum.WeeklyRewardChestThresholdType.MythicPlus then
      typeName = L["Mythic+"]
   elseif type == Enum.WeeklyRewardChestThresholdType.Raid then
      typeName = L["Raid"]
   elseif type == Enum.WeeklyRewardChestThresholdType.RankedPvP then
      typeName = L["PvP"]
   end

   sideTooltip.title =
      WrapTextInColorCode(string.format("%s %i/%i", typeName, progress, threshold), colors.sideTooltipTitle)

   return sideTooltip
end

local function Updater(event)
   local t = {}

   if event == "WEEKLY_REWARDS_UPDATE" or event == "PLAYER_ENTERING_WORLD_DELAYED" then
      t.activities = C_WeeklyRewards.GetActivities()
   elseif event == "CHALLENGE_MODE_COMPLETED" then
      C_MythicPlus.RequestMapInfo()
   end

   if (t.activities and #t.activities > 0) then
      Exlist.UpdateChar(key, t)
   end
end

local function Linegenerator(tooltip, data, character)
   if (not data) then
      return
   end
   local info = {
      character = character
      -- priority = prio,
      -- moduleName = key,
      -- titleName = L["Weekly Rewards"],
      -- data = "",
      -- colOff = 0,
      -- dontResize = false,
      -- pulseAnim = false,
      -- OnEnter = function() end,
      -- OnEnterData = {},
      -- OnLeave = function() end,
      -- OnLeaveData = {},
      -- OnClick = function() end,
      -- OnClickData = {},
   }
   local infoTables = {}
   local priority = prio
   for rewardType, reward in Exlist.spairs(
      rewardTypes,
      function(t, a, b)
         return t[a].prio < t[b].prio
      end
   ) do
      priority = priority + 0.1
      local activityName = reward.title
      info.priority = priority
      info.moduleName = activityName
      info.titleName = WrapTextInColorCode(activityName or "", colors.questTitle)
      local cellIndex = 1
      for _, activity in ipairs(getActivitiesByType(rewardType, data.activities)) do
         info.celOff = cellIndex - 2
         info.dontResize = true
         local color = "ffffffff"
         if (activity.progress >= activity.threshold) then
            color = colors.available
         end
         info.data =
            string.format(
            "|c%s%s/%s|r",
            color,
            Exlist.ShortenNumber(activity.progress),
            Exlist.ShortenNumber(activity.threshold)
         ) .. (activity.level > 0 and string.format(" (%s)", formatLevel(activity.type, activity.level)) or "")

         info.OnEnter = Exlist.CreateSideTooltip()
         info.OnEnterData = getActivityTooltip(activity.id, activity.type, activity.progress, activity.threshold)
         info.OnLeave = Exlist.DisposeSideTooltip()
         infoTables[info.moduleName] = infoTables[info.moduleName] or {}
         table.insert(infoTables[info.moduleName], Exlist.copyTable(info))
         cellIndex = cellIndex + 1
      end
   end

   for _, t in pairs(infoTables) do
      for i = 1, #t do
         if i >= #t then
            t[i].dontResize = false
         end
         Exlist.AddData(t[i])
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
-- local function init() end

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
   name = L["Weekly Rewards"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {
      "WEEKLY_REWARDS_UPDATE",
      "CHALLENGE_MODE_COMPLETED",
      "PLAYER_ENTERING_WORLD_DELAYED"
   },
   weeklyReset = true,
   dailyReset = false,
   description = L["Tracks Shadowlands Weekly Rewards"]
   -- globallgenerator = GlobalLineGenerator,
   -- type = 'customTooltip'
   -- modernize = Modernize,
   -- init = init
   -- override = true,
   -- specialResetHandle = ResetHandler
}

Exlist.RegisterModule(data)
