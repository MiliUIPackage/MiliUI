local key = "dungeons"
local prio = 110
local L = Exlist.L
local GetNumSavedInstances, GetSavedInstanceInfo = GetNumSavedInstances, GetSavedInstanceInfo
local GetLFGDungeonInfo = GetLFGDungeonInfo
local WrapTextInColorCode = WrapTextInColorCode
local pairs, table, ipairs = pairs, table, ipairs
local Exlist = Exlist
local colors = Exlist.Colors
local dungeonNames = {}

-- Dragonflight
local dungeons = {
   2334, -- The Azure Vault
   2354, -- Uldaman: Legacy of Tyr
   2358, -- Neltharus
   2375, -- Ruby Life Pools
   2377, -- The Nokhud Offensive
   2379, -- Brackenhide Hollow
   2381, -- Halls of Infusion
   2383, -- Academy
}

local NUMBER_OF_DUNGEONS = #dungeons

local function Updater(event, ...)
   local t = {
      ["done"] = 0,
      ["max"] = NUMBER_OF_DUNGEONS,
      ["dungeonList"] = dungeonNames
   }
   for i = 1, GetNumSavedInstances() do
      local name, _, _, _, locked, extended, _, isRaid, _, difficultyName, numEncounters, encounterProgress =
         GetSavedInstanceInfo(i)
      if not isRaid and difficultyName == "Mythic" then
         -- dungeons
         if locked then
            t.dungeonList[name] = {locked = true, done = encounterProgress, max = numEncounters}
            t.done = t.done + 1
         end
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
      moduleName = key,
      priority = prio,
      titleName = WrapTextInColorCode(L["Dungeons"], colors.faded),
      data = data.done .. "/" .. data.max
   }
   local sideTooltip = {title = WrapTextInColorCode(L["Mythic Dungeons"], colors.sideTooltipTitle), body = {}}
   for name, dungInfo in pairs(data.dungeonList) do
      if dungInfo.locked then
         local statusCol = dungInfo.done < dungInfo.max and colors.incomplete or colors.completed
         table.insert(
            sideTooltip.body,
            {name, WrapTextInColorCode(string.format("%i/%i", dungInfo.done, dungInfo.max), statusCol)}
         )
      else
         table.insert(sideTooltip.body, {name, WrapTextInColorCode(L["Available"], colors.available)})
      end
   end
   info.OnEnter = Exlist.CreateSideTooltip()
   info.OnEnterData = sideTooltip
   info.OnLeave = Exlist.DisposeSideTooltip()
   Exlist.AddData(info)
end

local function init()
   for _, id in ipairs(dungeons) do
      local name = GetLFGDungeonInfo(id)
      if name then
         dungeonNames[name] = {locked = false, done = 0, max = 0}
      end
   end
end

local function Modernize(data)
   -- data is table of module table from character
   -- always return table or don't use at all
   if not data then
      return
   end
   for name, info in pairs(data.dungeonList) do
      if type(info) ~= "table" then
         data.dungeonList[name] = {locked = info, done = 0, max = 0}
      end
   end
   return data
end

local data = {
   name = L["Dungeons"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {"UPDATE_INSTANCE_INFO", "PLAYER_ENTERING_WORLD"},
   description = L["Tracks weekly completed mythic dungeons"],
   weeklyReset = true,
   modernize = Modernize,
   init = init
}

Exlist.RegisterModule(data)
