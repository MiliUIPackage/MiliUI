local key = "coins"
local L = Exlist.L
local prio = 60
local UnitLevel = UnitLevel
local pairs, table = pairs, table
local WrapTextInColorCode = WrapTextInColorCode
local Exlist = Exlist
local colors = Exlist.Colors

local function Updater(event)
   if UnitLevel("player") ~= 50 then -- Check only for level 50 (BFA)
      Exlist.UpdateChar(key, {})
      return
   end
   local coinsQuests = {
      -- BFA
      [52834] = true, -- Gold
      [52835] = true, -- Honor
      [52837] = true, -- Resources
      [52838] = true, -- 2xGold
      [52839] = true, -- 2xHonor
      [52840] = true -- 2xResources
   }
   local coinsCurrency = 1580
   local maxCoins = 2
   local count = 0
   local quests = {}
   for id, _ in pairs(coinsQuests) do
      if C_QuestLog.IsQuestFlaggedCompleted(id) then
         local title = Exlist.GetCachedQuestTitle(id)
         table.insert(quests, title)
         count = count + 1
      end
   end
   local info = C_CurrencyInfo.GetCurrencyInfo(coinsCurrency)
   local table = {
      ["curr"] = info.quantity,
      ["max"] = info.maxQuantity,
      ["available"] = maxCoins - count,
      ["quests"] = quests
   }
   Exlist.UpdateChar(key, table)
end

local function Linegenerator(tooltip, data, character)
   if not data or not data.max or data.max <= 0 then
      return
   end

   -- Dont show for below BFA level
   local char = Exlist.GetCharacterEssentials(character.realm, character.name)
   if (not char or char.level > 50) then
      return
   end

   local settings = Exlist.ConfigDB.settings
   local availableCoins =
      data.available > 0 and
      WrapTextInColorCode(
         settings.shortenInfo and "+" .. data.available or (data.available .. L[" available!"]),
         colors.available
      ) or
      ""
   local info = {
      data = data.curr .. "/" .. data.max .. " " .. availableCoins,
      character = character,
      priority = prio,
      moduleName = key,
      titleName = L["Coins"]
   }
   if data.quests and #data.quests > 0 then
      local sideTooltip = {
         title = WrapTextInColorCode(L["Quests Done This Week"], colors.sideTooltipTitle),
         body = {}
      }
      for i = 1, #data.quests do
         table.insert(sideTooltip.body, WrapTextInColorCode("[" .. data.quests[i] .. "]", colors.questTitle))
      end
      info.OnEnter = Exlist.CreateSideTooltip()
      info.OnEnterData = sideTooltip
      info.OnLeave = Exlist.DisposeSideTooltip()
   end
   Exlist.AddData(info)
end

local data = {
   name = L["Coins"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {"CURRENCY_DISPLAY_UPDATE", "QUEST_FINISHED", "QUEST_TURNED_IN"},
   description = L["Tracks currently available bonus roll coins and amount of coins available from weekly quests"],
   weeklyReset = false
}

Exlist.RegisterModule(data)
