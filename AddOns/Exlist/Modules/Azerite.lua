local key = "azerite"
local prio = 30
local Exlist = Exlist
local L = Exlist.L
local C_AzeriteItem,C_AzeriteEmpoweredItem = C_AzeriteItem,C_AzeriteEmpoweredItem
local Item = Item
local format = string.format
local tinsert = tinsert
local next, ipairs, pairs = next, ipairs, pairs
local WrapTextInColorCode = WrapTextInColorCode
local colors = Exlist.Colors
--local strings = Exlist.Strings

local function GetAvailableTraits(powerLevel)
  local t = {}
  for _,slot in next, { 1, 3, 5 } do
    -- 1=head,3=shoulders,5=chest
    local item = Item:CreateFromEquipmentSlot(slot)
    if not item:IsItemEmpty() then
      local itemLoc = item:GetItemLocation()
      if C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItem(itemLoc) and C_AzeriteEmpoweredItem.HasAnyUnselectedPowers(itemLoc) then
        -- check if azerite armor has available traits
        local tiers = C_AzeriteEmpoweredItem.GetAllTierInfo(itemLoc)
        t[slot] = 0
        for _,tierInfo in ipairs(tiers) do
          if tierInfo.unlockLevel <= powerLevel then
            -- is tier available to player
            local empty = true
            for _,powerId in ipairs(tierInfo.azeritePowerIDs) do
              -- check if player has selected any of tier's traits
              if C_AzeriteEmpoweredItem.IsPowerSelected(itemLoc,powerId) then
                empty = false
                break
              end
            end
            t[slot] = empty and t[slot] + 1 or t[slot]
          end
        end
      end
    end
  end
  return t
end

local function GetAzeriteInfo()
  if not C_AzeriteItem.HasActiveAzeriteItem() then return end
  local itemLocation = C_AzeriteItem.FindActiveAzeriteItem()
  local xp,maxXp = C_AzeriteItem.GetAzeriteItemXPInfo(itemLocation)
  local powerLevel = C_AzeriteItem.GetPowerLevel(itemLocation)
  local t = {
    xp = xp,
    maxXp = maxXp,
    powerLevel = powerLevel,
    traitsAvailable = GetAvailableTraits(powerLevel),
  }
  return t
end

local function GetIslandsProgress()
  local questId = C_IslandsQueue.GetIslandsWeeklyQuestID()
  if IsQuestFlaggedCompleted(questId) then
    return true, 0, 0 -- Completed
  end
  local _, _, _, numFulfilled, numRequired = GetQuestObjectiveInfo(questId, 1, false)
  return false, numFulfilled or 0, numRequired or 40000 -- fallback values if user hasnt done quest
end

local function Updater(event)
  local t = GetAzeriteInfo()
  if not t then return end
  if UnitLevel("player") == 120 then
    local completed, curr, max = GetIslandsProgress()
    t.weekly = {
      completed = completed,
      curr = curr,
      max = max,
    }
  end
  Exlist.UpdateChar(key,t)
end

local slotNames = {
  [1] = L["Head"],
  [3] = L["Shoulders"],
  [5] = L["Chest"],
}

local function Linegenerator(tooltip,data,character)
  -- 暫時修正
  if not data or not data.xp then return end
  local info = {
    character = character,
    priority = prio,
    moduleName = key,
    titleName = L["Azerite Power"],
    data = format("|c%s%s:|r %i\n%.1f%%",colors.faded,L["Level"],data.powerLevel,(data.xp/data.maxXp)*100),
    OnEnter = Exlist.CreateSideTooltip(),
    OnEnterData = {
      title = WrapTextInColorCode(L["Azerite Power"], colors.sideTooltipTitle),
      body = {
        { L["Progress"], format("%.1f%% (%i/%i)",(data.xp/data.maxXp)*100,data.xp,data.maxXp)},
        { L["Level"],data.powerLevel },
      }
    },
    OnLeave = Exlist.DisposeSideTooltip(),
  }
  local shorten = Exlist.ConfigDB.settings.shortenInfo
  local total = 0
  for slot,availableTraits in pairs(data.traitsAvailable) do
    tinsert(info.OnEnterData.body,{format("%s: %s",slotNames[slot],WrapTextInColorCode(format("%i |4 %s: %s; %s",availableTraits,L["trait"],L["traits"],L["available"]), colors.available))})
    total = total + availableTraits
  end
  if total > 0 then
    info.data = info.data .. WrapTextInColorCode(format(" %i %s",total,shorten and L["avail"] or L["available"]), colors.available)
  end
  Exlist.AddData(info)
  -- Weekly Info
  if data.weekly and Exlist.ConfigDB.settings.azeriteWeekly then
    local weekly = {
      character = character,
      priority = prio + 1,
      moduleName = key.."Weekly",
      titleName = L["Weekly Islands"],
    }
    if data.weekly.completed then
      weekly.data = WrapTextInColorCode(L["Completed"], colors.completed)
    elseif data.weekly.curr >= data.weekly.max then
      weekly.data = WrapTextInColorCode(L["Turn In!"], colors.available)
      weekly.pulseAnim = true
    else
      weekly.data = string.format("%s/%s\n%.1f%%",
        Exlist.ShortenNumber(data.weekly.curr),
        Exlist.ShortenNumber(data.weekly.max),
        (data.weekly.curr/data.weekly.max) * 100)
    end
    Exlist.AddData(weekly)
  end
end

--[[
local function GlobalLineGenerator(tooltip,data)

end
]]


local function Modernize(data)
  -- data is table of module table from character
  -- always return table or don't use at all
  if Exlist.GetTableNum(data) == 0 then
    return
  end
  if data.weekly and not data.weekly.curr then
    data.weekly = nil
  end
  return data
end

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
  for _,realm in ipairs(realms) do
    local characters = Exlist.GetRealmCharacters(realm)
    for _,character in ipairs(characters) do
      local data = Exlist.GetCharacterTableKey(realm,character,key)
      if data.weekly then
        data.weekly =  {
          completed = false,
          curr = 0,
          max = 40000, -- hardcode for now
        }
      end
      Exlist.UpdateChar(key,data,character,realm)
    end
  end

end


local function AddOptions()
  local settings = Exlist.ConfigDB.settings
  local options = {
    type = "group",
    name = L["Azerite"],
    args = {
      azeriteWeekly = {
        type = "toggle",
        order = 1,
        width = "full",
        name = L["Show Islands Weekly"],
        desc = L["Show characters progress with weekly Islands Expedition quest"],
        get = function() return settings.azeriteWeekly end,
        set = function(self,value) settings.azeriteWeekly = value end
      }
    }
  }
  Exlist.AddModuleOptions(key,options,L["Azerite"])
end
Exlist.ModuleToBeAdded(AddOptions)

local data = {
  name = L['Azerite'],
  key = key,
  linegenerator = Linegenerator,
  priority = prio,
  updater = Updater,
  event = {
    "PLAYER_ENTERING_WORLD",
    "AZERITE_ITEM_EXPERIENCE_CHANGED",
    "AZERITE_ITEM_POWER_LEVEL_CHANGED",
    "AZERITE_EMPOWERED_ITEM_SELECTION_UPDATED",
    "PLAYER_EQUIPMENT_CHANGED",
    "QUEST_LOG_UPDATE"
  },
  weeklyReset = true,
  dailyReset = false,
  description = L["Tracks Heart of Azeroth's current level and progress. Also show available traits."],
-- globallgenerator = GlobalLineGenerator,
  modernize = Modernize,
-- init = init,
-- override = true,
  specialResetHandle = ResetHandler
}

Exlist.RegisterModule(data)
