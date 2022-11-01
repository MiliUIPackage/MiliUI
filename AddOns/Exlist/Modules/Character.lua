local key = "character"
local prio = 10
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors

local function toggleChatEvent(register)
   for i = 1, 10 do
      local cf = _G["ChatFrame" .. i]
      if (register) then
         cf:RegisterEvent("TIME_PLAYED_MSG")
      else
         if (cf:IsEventRegistered("TIME_PLAYED_MSG")) then
            cf:UnregisterEvent("TIME_PLAYED_MSG")
         end
      end
   end
end

local function Updater(event, ...)
   local name = UnitName("player")
   local realm = GetRealmName()
   local t = Exlist.GetCharacterTableKey(realm, name, key) or {}
   if (event == "PLAYER_ENTERING_WORLD_DELAYED") then
      toggleChatEvent()
      RequestTimePlayed()
      return
   end
   if (event == "TIME_PLAYED_MSG") then
      local totalTimePlayed, timePlayedThisLevel = ...
      if (totalTimePlayed) then
         t.totalPlayed = totalTimePlayed
         t.totalPlayedLevel = timePlayedThisLevel
      end
      toggleChatEvent(true)
   end

   Exlist.UpdateChar(key, t)
end

local function Linegenerator(tooltip, data, character)
   -- Module doesnt show anything in main tooltip
end

local function customGenerator(tooltip, db)
   -- data here will be all db
   local totalPlayed = 0
   local totalGold = 0

   for _, realm in pairs(db) do
      for _, char in pairs(realm) do
         totalPlayed = totalPlayed + (char[key] and char[key].totalPlayed or 0)
         totalGold = totalGold + (char.currency and char.currency.money.totalCoppers or 0)
      end
   end

   Exlist.AddLine(
      tooltip,
      {
         WrapTextInColorCode(L["Total Played"], colors.sideTooltipTitle),
         SecondsToTime(totalPlayed)
      }
   )
   Exlist.AddLine(
      tooltip,
      {
         WrapTextInColorCode(L["Total Gold"], colors.sideTooltipTitle),
         Exlist.FormatGold(totalGold)
      }
   )
end

local function init()
   -- RequestTimePlayed()
   C_Timer.NewTicker(
      120,
      function()
         toggleChatEvent()
         RequestTimePlayed()
      end
   ) -- temp
end

local data = {
   name = L["Character"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {"TIME_PLAYED_MSG", "PLAYER_ENTERING_WORLD_DELAYED"},
   weeklyReset = false,
   dailyReset = false,
   description = L["Gathers various data about character"],
   type = "totals",
   customGenerator = customGenerator,
   init = init
}

Exlist.RegisterModule(data)
