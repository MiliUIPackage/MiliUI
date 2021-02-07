local key = "callings"
local prio = 89
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors
-- local strings = Exlist.Strings

local clocks = {
   {icon = [[Interface/Addons/Exlist/Media/Icons/clock_red.tga]], t = 86400},
   {
      icon = [[Interface/Addons/Exlist/Media/Icons/clock_yellow.tga]],
      t = 172800
   },
   {icon = [[Interface/Addons/Exlist/Media/Icons/clock_green.tga]], t = 259200}
}

local function GetClockIcon(endTime)
   local timeLeft = endTime - time()
   local c = [[Interface/Addons/Exlist/Media/Icons/clock_green.tga]]
   for _, clock in ipairs(clocks) do
      if clock.t > timeLeft then
         c = clock.icon
         break
      end
   end
   return string.format("|T%s:12:12|t", c)
end

local function Updater(event, callings)
   local t = {}

   if (callings) then
      t = callings
      for i, calling in ipairs(t) do
         local questTitle = Exlist.GetCachedQuestTitle(calling.questID)
         t[i].questTitle = questTitle
         local timeleft = C_TaskQuest.GetQuestTimeLeftMinutes(calling.questID) or 0
         local endTime = time() + timeleft * 60
         t[i].endTime = endTime
      end
   end
   Exlist.UpdateChar(key, t)
end

local function Linegenerator(tooltip, data, character)
   if not data then
      return
   end
   local info = {
      character = character,
      priority = prio,
      moduleName = key,
      titleName = L["Callings"]
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
   local cellIndex = 1
   table.sort(
      data,
      function(a, b)
         return a.endTime < b.endTime
      end
   )
   for _, calling in ipairs(data) do
      if (calling.endTime and time() <= calling.endTime) then
         info.data =
            string.format("|T%s:45:45:::256:256:58:198:51:197|t %s", calling.icon or "", GetClockIcon(calling.endTime))
         local sideTooltip = {
            body = {},
            title = WrapTextInColorCode(calling.questTitle or "", colors.sideTooltipTitle)
         }
         table.insert(
            sideTooltip.body,
            {
               L["Time Left:"],
               Exlist.TimeLeftColor(calling.endTime - time(), {36000, 72000})
            }
         )

         info.colOff = cellIndex - 2
         info.OnEnter = Exlist.CreateSideTooltip()
         info.OnEnterData = sideTooltip
         info.OnLeave = Exlist.DisposeSideTooltip()

         table.insert(infoTables, Exlist.copyTable(info))
      end
   end
   for i, t in ipairs(infoTables) do
      if i >= #infoTables then
         t.dontResize = false
      end
      Exlist.AddData(t)
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
local function init()
   -- code that will run before any other function
   C_Timer.After(
      0.5,
      function()
         if UIParentLoadAddOn("Blizzard_CovenantCallings") then
            if (C_CovenantCallings.AreCallingsUnlocked()) then
               C_CovenantCallings.RequestCallings()
            end
         end
      end
   )
end

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
   name = L["Callings"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {"COVENANT_CALLINGS_UPDATED"},
   weeklyReset = false,
   dailyReset = false,
   description = L["Tracks characters available callings"],
   -- globallgenerator = GlobalLineGenerator,
   -- type = 'customTooltip'
   -- modernize = Modernize,
   init = init
   -- override = true,
   -- specialResetHandle = ResetHandler
}

Exlist.RegisterModule(data)
