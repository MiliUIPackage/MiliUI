local key = "coins"
local L = Exlist.L
local prio = 60
local UnitLevel, IsQuestFlaggedCompleted, GetCurrencyInfo = UnitLevel, IsQuestFlaggedCompleted, GetCurrencyInfo
local pairs, table = pairs, table
local WrapTextInColorCode = WrapTextInColorCode
local Exlist = Exlist
local colors = Exlist.Colors

local function Updater(event)
  if not IsPlayerAtEffectiveMaxLevel() then return end
  local coinsQuests = UnitLevel'player' <= 110 and
    {
      [43895] = 1,
      [43897] = 1,
      [43896] = 1,
      [43892] = 1,
      [43893] = 1,
      [43894] = 1,
      [43510] = 1, -- Order Hall
      [47851] = 1,
      [47864] = 1,
      [47865] = 1,
    } or
    { -- BFA
      [52834] = true, -- Gold
      [52835] = true, -- Honor
      [52837] = true, -- Resources
      [52838] = true, -- 2xGold
      [52839] = true, -- 2xHonor
      [52840] = true, -- 2xResources
    }
  -- 暫時修正
  local coinsCurrency = 1580 -- UnitLevel('player') <= 110 and 1273 or 1580
  local maxCoins = 2 -- UnitLevel('player') <= 110 and 3 or 2
  local count = 0
  local quests = {}
  for id, _ in pairs(coinsQuests) do
    if IsQuestFlaggedCompleted(id) then
      local title = Exlist.GetCachedQuestTitle(id)
      table.insert(quests,title)
      count = count + 1
    end
  end
  local _, amount, _, _, _, totalMax, _, _ = GetCurrencyInfo(coinsCurrency)
  local table = {
    ["curr"] = amount,
    ["max"] = totalMax,
    ["available"] = maxCoins - count,
    ["quests"] = quests
  }
  Exlist.UpdateChar(key,table)
end

local function Linegenerator(tooltip,data,character)
  if not data or data.max <= 0 then return end
  local settings = Exlist.ConfigDB.settings
  local availableCoins = data.available > 0 and WrapTextInColorCode(settings.shortenInfo and "+" .. data.available or (data.available .. L[" available!"]), colors.available) or ""
  local info = {
    data = data.curr .. "/" .. data.max .. " " .. availableCoins,
    character = character,
    priority = prio,
    moduleName = key,
    titleName = L["Coins"]
  }
  if data.quests and #data.quests > 0 then
    local sideTooltip = {title = WrapTextInColorCode(L["Quests Done This Week"],colors.sideTooltipTitle), body = {}}
    for i=1,#data.quests do
      table.insert(sideTooltip.body,WrapTextInColorCode("[" .. data.quests[i] .. "]",colors.questTitle))
    end
    info.OnEnter = Exlist.CreateSideTooltip()
    info.OnEnterData = sideTooltip
    info.OnLeave = Exlist.DisposeSideTooltip()
  end
  Exlist.AddData(info)
end

local data = {
  name = L['Coins'],
  key = key,
  linegenerator = Linegenerator,
  priority = prio,
  updater = Updater,
  event = {"CURRENCY_DISPLAY_UPDATE","QUEST_FINISHED","QUEST_TURNED_IN"},
  description = L["Tracks currently available bonus roll coins and amount of coins available from weekly quests"],
  weeklyReset = false
}

Exlist.RegisterModule(data)
