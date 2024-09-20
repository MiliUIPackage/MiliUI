local key = "weeklyrewards"
local prio = 12
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors

local rewardTypes = {
   [Enum.WeeklyRewardChestThresholdType.Raid] = { title = L["Raid"], prio = 1 },
   [Enum.WeeklyRewardChestThresholdType.Activities] = {
      title = L["Dungeons"],
      prio = 2
   },
   [Enum.WeeklyRewardChestThresholdType.RankedPvP] = { title = "PvP", prio = 3 },
   [Enum.WeeklyRewardChestThresholdType.World] = { title = L["World"], prio = 3 }
}

local slimDifficulty = {
   [PLAYER_DIFFICULTY1] = L['N'],
   [PLAYER_DIFFICULTY2] = L['HC'],
   [PLAYER_DIFFICULTY6] = L['M'],
   [PLAYER_DIFFICULTY3] = L['LFR']
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

local function formatLevel(type, level, isSlim)
   if type == Enum.WeeklyRewardChestThresholdType.Activities then
      return string.format("+%s", level)
   elseif type == Enum.WeeklyRewardChestThresholdType.Raid then
      local diff = DifficultyUtil.GetDifficultyName(level)
      return isSlim and slimDifficulty[diff] or diff
   elseif type == Enum.WeeklyRewardChestThresholdType.RankedPvP then
      return PVPUtil.GetTierName(level)
   end
   return level
end

local function getCurrentIlvl(id)
   local exampleItem, upgradeItem = C_WeeklyRewards.GetExampleRewardItemHyperlinks(id)
   local data = {}

   if exampleItem then
      data.ilvl = C_Item.GetDetailedItemLevelInfo(exampleItem)
   end
   if upgradeItem then
      data.upgradeIlvl = C_Item.GetDetailedItemLevelInfo(upgradeItem)
   end

   return data
end

local function getBestMythicPlusRuns(threshold)
   local history = C_MythicPlus.GetRunHistory(false, true)
   table.sort(
      history,
      function(a, b)
         if (a.level == b.level) then
            return a.mapChallengeModeID < b.mapChallengeModeID
         else
            return a.level > b.level
         end
      end
   )

   local runs = {}

   for i = 1, threshold do
      if (history[i]) then
         table.insert(
            runs,
            {
               name = C_ChallengeMode.GetMapUIInfo(history[i].mapChallengeModeID),
               level = history[i].level,
               score = history[i].runScore
            }
         )
      end
   end

   return runs
end

local function getActivityTooltip(activity)
   local sideTooltip = { body = {} }
   local ilvls = getCurrentIlvl(activity.id)

   if ilvls.ilvl then
      table.insert(sideTooltip.body, { L["Current"], string.format("%s %s", ilvls.ilvl, L["ilvl"]) })
   end
   if ilvls.upgradeIlvl then
      table.insert(sideTooltip.body, { L["Upgrade"], string.format("%s %s", ilvls.upgradeIlvl, L["ilvl"]) })
   end

   local typeName = ""

   if activity.type == Enum.WeeklyRewardChestThresholdType.Activities then
      typeName = L["Mythic+"]

      if (activity.runs) then
         table.insert(sideTooltip.body, {})
         table.insert(sideTooltip.body, { WrapTextInColorCode(L["Best Mythic+ Runs"], colors.sideTooltipTitle) })
         table.insert(
            sideTooltip.body,
            { WrapTextInColorCode(L["Dungeon"], colors.faded), WrapTextInColorCode(L["Score"], colors.faded) }
         )
         for _, run in ipairs(activity.runs) do
            table.insert(
               sideTooltip.body,
               {
                  string.format(
                     "[%s] %s",
                     WrapTextInColorCode(run.level, Exlist.GetMythicPlusLevelColor(run.level)),
                     run.name
                  ),
                  run.score
               }
            )
         end
      end
   elseif activity.type == Enum.WeeklyRewardChestThresholdType.Raid then
      typeName = L["Raid"]
   elseif activity.type == Enum.WeeklyRewardChestThresholdType.World then
      typeName = L["World"]
   elseif activity.type == Enum.WeeklyRewardChestThresholdType.RankedPvP then
      typeName = L["PvP"]
   end

   sideTooltip.title =
       WrapTextInColorCode(
          string.format("%s %i/%i", typeName, activity.progress, activity.threshold),
          colors.sideTooltipTitle
       )

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
      for _, activity in pairs(t.activities) do
         if (activity.type == Enum.WeeklyRewardChestThresholdType.Activities) then
            activity.runs = getBestMythicPlusRuns(activity.threshold)
         end
      end

      Exlist.UpdateChar(key, t)
   end
end

local function Linegenerator(tooltip, data, character)
   if (not data) then
      return
   end
   local info = {
      character = character
   }
   local settings = Exlist.ConfigDB.settings
   local isSlim = settings.shortenInfo
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
         info.data =
             string.format(
                "|c%s%s/%s|r",
                activity.progress >= activity.threshold and colors.available or colors.faded,
                Exlist.ShortenNumber(activity.progress),
                Exlist.ShortenNumber(activity.threshold)
             ) ..
             (activity.level > 0 and string.format(" (%s)", formatLevel(activity.type, activity.level, isSlim)) or "")

         if (activity.progress >= activity.threshold and not isSlim) then
            info.data = Exlist.AddCheckmark(info.data, true)
         end

         info.OnEnter = Exlist.CreateSideTooltip()
         info.OnEnterData = getActivityTooltip(activity)
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
}

Exlist.RegisterModule(data)
