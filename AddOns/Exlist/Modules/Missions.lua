local key = "missions"
local prio = 80
local CG = C_Garrison
local LE_FOLLOWER_TYPE_GARRISON_7_0 = LE_FOLLOWER_TYPE_GARRISON_7_0
local LE_FOLLOWER_TYPE_GARRISON_8_0 = LE_FOLLOWER_TYPE_GARRISON_8_0
local time, table, strlen, string, type, math = time, table, strlen, string, type, math
local WrapTextInColorCode, SecondsToTime = WrapTextInColorCode, SecondsToTime
local GetMoneyString = GetMoneyString
local GetTime = GetTime
local Exlist = Exlist
local colors = Exlist.Colors
local L = Exlist.L

local unknownIcon = "Interface\\ICONS\\INV_Misc_QuestionMark"

local followerTypes = {
   {type = Enum.GarrisonFollowerType.FollowerType_6_0_GarrisonFollower, level = 40},
   {type = Enum.GarrisonFollowerType.FollowerType_7_0_GarrisonFollower, level = 45},
   {type = Enum.GarrisonFollowerType.FollowerType_8_0_GarrisonFollower, level = 50},
   {type = Enum.GarrisonFollowerType.FollowerType_9_0_GarrisonFollower, level = 60}
}

local function GetFollowerType()
   local level = UnitLevel("player")
   local followerType = Enum.GarrisonFollowerType.FollowerType_9_0_GarrisonFollower
   for _, types in ipairs(followerTypes) do
      if (level >= types.level) then
         followerType = types.type
      end
   end
   return followerType
end

local function GetMissionRewards(rewards)
   local reward = {}
   for i = 1, #rewards do
      reward[i] = {}
      local r = reward[i]
      if rewards[i].currencyID and rewards[i].currencyID == 0 then
         -- gold
         r.icon = rewards[i].icon
         r.quantity = GetMoneyString(rewards[i].quantity)
         r.name = rewards[i].title
      elseif rewards[i].itemID then
         -- item
         local itemInfo = Exlist.GetCachedItemInfo(rewards[i].itemID)
         r.quantity = rewards[i].quantity
         r.name = itemInfo.name
         r.icon = itemInfo.texture
      elseif rewards[i].currencyID then
         local info = C_CurrencyInfo.GetCurrencyInfo(rewards[i].currencyID)
         r.quantity = rewards[i].quantity
         r.name = info.name
         r.icon = info.iconFileID
      elseif rewards[i].followerXP then
         r.quantity = 1
         r.icon = rewards[i].icon
         r.name = rewards[i].title
      end
   end

   return reward
end

local function Updater(event)
   if event == "Exlist_DELAY" then
      return
   end

   local followerType = GetFollowerType()

   local mission = CG.GetInProgressMissions(followerType)
   local availMissions = CG.GetAvailableMissions(followerType)
   local t = {}
   local currTime = time()
   if mission then
      -- in progress/finished
      for i = 1, #mission do
         local endTime = mission[i].missionEndTime
         local successChance = CG.GetMissionSuccessChance(mission[i].missionID)
         local reward = GetMissionRewards(mission[i].rewards)
         local mis = {
            ["name"] = mission[i].name,
            ["endTime"] = endTime,
            ["rewards"] = reward
         }
         table.insert(t, mis)
      end
   end
   if availMissions then
      -- available
      for i = 1, #availMissions do
         local reward = GetMissionRewards(availMissions[i].rewards)
         local offer = availMissions[i].offerEndTime
         if offer then
            offer = currTime + (offer - GetTime())
         end
         local mis = {
            ["name"] = availMissions[i].name,
            ["rewards"] = reward,
            ["offerEndTime"] = offer
         }
         table.insert(t, mis)
      end
   end
   if #t > 0 then
      Exlist.UpdateChar(key, t)
   end
end

local function GetRewardsString(rewards)
   local rewardString = ""

   for _, reward in ipairs(rewards) do
      if (rewardString ~= "") then
         rewardString = rewardString .. " / "
      end
      if type(reward.quantity) == "number" and reward.quantity > 1 then
         rewardString =
            string.format(
            "%s%ix|T%s:15:15|t %s",
            rewardString,
            reward.quantity or "",
            reward.icon or unknownIcon,
            reward.name or L["Unknown"]
         )
      elseif type(reward.quantity) == "string" then
         rewardString =
            string.format("%s|T%s:15:15|t%s", rewardString, reward.icon or unknownIcon, reward.quantity or "")
      else
         rewardString =
            string.format("%s|T%s:15:15|t %s", rewardString, reward.icon or unknownIcon, reward.name or L["Unknown"])
      end
   end
   return rewardString
end

local function missionStrings(source, hasTime)
   local t = {}
   if type(source) ~= "table" then
      return
   end
   local ti = time()
   for i = 1, #source do
      if hasTime then
         if source[i].endTime > ti then
            table.insert(
               t,
               {
                  WrapTextInColorCode(source[i].name, colors.missionName),
                  string.format(
                     "%s: %s",
                     L["Time Left"],
                     Exlist.TimeLeftColor(
                        (source[i].endTime - ti) or 0,
                        {1800, 7200},
                        {colors.time.short, colors.time.medium, colors.time.long}
                     )
                  )
               }
            )
         else
            table.insert(t, {WrapTextInColorCode(source[i].name, colors.missionName)})
         end
      else
         table.insert(
            t,
            {
               WrapTextInColorCode(source[i].name, colors.missionName),
               source[i].offerEndTime and
                  (L["Expires in"] ..
                     ": " ..
                        Exlist.TimeLeftColor(
                           (source[i].offerEndTime - ti) or 0,
                           {14400, 28800},
                           {colors.time.long, colors.time.medium, colors.time.short}
                        )) or
                  ""
            }
         )
      end
      table.insert(t, {L["Reward"] .. ": " .. GetRewardsString(source[i].rewards), ""})
   end
   return t
end

local function Linegenerator(tooltip, data, character)
   local t = time()
   local m = data
   if not m then
      return
   end
   local info = {
      character = character,
      priority = prio,
      moduleName = key,
      titleName = L["Missions"]
   }

   local available, inprogress, done = {}, {}, {}
   local ip = 0
   local completed = 0
   for i = 1, #m do
      if m[i].endTime then
         ip = ip + 1
         if t >= m[i].endTime then
            completed = completed + 1
            table.insert(done, m[i])
         else
            table.insert(inprogress, m[i])
         end
      elseif not m[i].offerEndTime or m[i].offerEndTime > t then
         table.insert(available, m[i])
      end
   end
   if completed > 0 then
      completed = "|cFF00FF00" .. completed
   end
   local t2 = string.format("%s/%i", completed, ip) or ""
   info.data = t2
   local sideTooltip = {body = {}, title = WrapTextInColorCode(L["Missions"], colors.sideTooltipTitle)}
   if #done > 0 then
      table.insert(
         sideTooltip.body,
         {WrapTextInColorCode(L["Completed"], colors.missions.completed), "", {"headerseparator"}}
      )
      local t = missionStrings(done, true)
      for i = 1, #t do
         table.insert(sideTooltip.body, t[i])
      end
   end
   if #inprogress > 0 then
      table.insert(
         sideTooltip.body,
         {WrapTextInColorCode(L["In Progress"], colors.missions.inprogress), "", {"headerseparator"}}
      )
      table.sort(
         inprogress,
         function(a, b)
            return a.endTime < b.endTime
         end
      )
      local t = missionStrings(inprogress, true)
      for i = 1, #t do
         table.insert(sideTooltip.body, t[i])
      end
   end
   if #available > 0 then
      table.insert(
         sideTooltip.body,
         {WrapTextInColorCode(L["Available"], colors.missions.available), "", {"headerseparator"}}
      )
      table.sort(
         available,
         function(a, b)
            local aValue = a.offerEndTime or 0
            local bValue = b.offerEndTime or 0
            return aValue < bValue
         end
      )
      local t = missionStrings(available)
      for i = 1, #t do
         table.insert(sideTooltip.body, t[i])
      end
   end
   if (#sideTooltip.body > 0) then
      info.OnEnter = Exlist.CreateSideTooltip()
      info.OnEnterData = sideTooltip
      info.OnLeave = Exlist.DisposeSideTooltip()
   end

   Exlist.AddData(info)
end

local data = {
   name = L["Missions"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {"GARRISON_MISSION_COMPLETE_RESPONSE", "GARRISON_MISSION_STARTED", "GARRISON_MISSION_NPC_OPENED"},
   description = L["Garrison mission progress"],
   weeklyReset = false
}

Exlist.RegisterModule(data)
