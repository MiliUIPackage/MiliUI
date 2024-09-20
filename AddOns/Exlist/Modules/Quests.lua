local key = "quests"
local prio = 90
local pairs, ipairs, table, print, type, string, tonumber = pairs, ipairs, table, print, type, string, tonumber
local time, date = time, date
local WrapTextInColorCode = WrapTextInColorCode
local C_Calendar = C_Calendar
local UnitName, GetRealmName = UnitName, GetRealmName
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors
local strings = Exlist.Strings

local function spairs(t, order)
   -- collect the keys
   local keys = {}
   for k in pairs(t) do
      keys[#keys + 1] = k
   end

   -- if order function given, sort by it by passing the table and keys a, b,
   -- otherwise just sort the keys
   if order then
      table.sort(
         keys,
         function(a, b)
            return order(t, a, b)
         end
      )
   else
      table.sort(keys)
   end

   -- return the iterator function
   local i = 0
   return function()
      i = i + 1
      if keys[i] then
         return keys[i], t[keys[i]]
      end
   end
end

local checkFunctions = {}
local questTypes = {
   ["daily"] = L["Daily"],
   ["weekly"] = L["Weekly"]
}
local questTypeOrder = {"daily", "weekly"}

local trackedQuests = {}

local bquestIds = {
   {questId = 53030, name = "World Quest Bonus Event", spellId = 225788}, -- WQ
   {questId = 53037, name = "Battle for Azeroth Dungeon Event", spellId = 225787}, -- Dungeons
   {questId = 53036, name = "Battleground Bonus Event", spellId = 186403}, -- BGs
   {questId = 53039, name = "Arena Skirmish Bonus Event", spellId = 186401}, -- Arenas
   {questId = 53038, name = "Pet Battle Bonus Event", spellId = 186406}, -- Pet Battles
   -- timewalking
   {questId = 44164, name = "Timewalking Dungeon Event"}, -- BC TODO: wowhead doesnt have BFA version of this quest atm
   {questId = 53033, name = "Timewalking Dungeon Event"}, -- Wotlk
   {questId = 53035, name = "Timewalking Dungeon Event"}, -- MoP
   {questId = 53034, name = "Timewalking Dungeon Event"} -- Cata
}
local twIconIds = {
   [1129673] = 44164, -- BC
   [1129674] = 44164, -- BC (alt)
   [1129686] = 53033, -- Wotlk
   [1129685] = 53033, -- Wotlk (alt)
   [1530589] = 53035, -- MoP
   [1530590] = 53035, -- MoP (alt)
   [1304687] = 53034, -- Cata
   [1304688] = 53034 -- Cata (alt)
}
local bonusQuestId
local refreshedCalendar = false
function checkFunctions.WeeklyBonusQuest(questId)
   -- Unfortunately can't find this weeks by simple API calls
   local settings = Exlist.ConfigDB.settings
   if bonusQuestId and bonusQuestId == questId then
      -- already have found what quest is this week
      local name = Exlist.GetCachedQuestTitle(questId)
      local completed = C_QuestLog.IsQuestFlaggedCompleted(questId)
      settings.unsortedFolder.weekly.bonusQuestId = questId
      return name, true, completed
   elseif bonusQuestId then
      return nil, false, false
   end
   if settings.unsortedFolder.weekly.bonusQuestId and settings.unsortedFolder.weekly.bonusQuestId == questId then
      -- already found it in previous sessions
      bonusQuestId = questId
      local name = Exlist.GetCachedQuestTitle(questId)
      local completed = C_QuestLog.IsQuestFlaggedCompleted(questId)
      return name, true, completed
   elseif settings.unsortedFolder.weekly.bonusQuestId then
      return nil, false, false
   end
   local holidayNames = {}
   for _, qId in ipairs(bquestIds) do
      -- maybe have already completed
      if C_QuestLog.IsQuestFlaggedCompleted(qId.questId) then
         bonusQuestId = qId.questId
         if qId.questId == questId then
            local name = Exlist.GetCachedQuestTitle(questId)
            return name, true, true
         end
         return nil, false, false
      end
      -- Most bonus events have buff associated with them
      if qId.spellId then
         local name = Exlist.AuraFromId("player", qId.spellId, "HELPFUL")
         if name then
            bonusQuestId = qId.questId
            if qId.questId == questId then
               local questName = Exlist.GetCachedQuestTitle(questId)
               return questName, true, false
            end
            return nil, false, false
         end
      end
      holidayNames[qId.name] = qId.questId
   end
   -- oh well time to go hard way
   --
   local date = date("*t", time())
   for i = 1, 5 do
      local holiday = C_Calendar.GetHolidayInfo(0, date.day, i)
      if holiday then
         if holidayNames[holiday.name] then
            local t = holiday.endTime
            local tEndTime = {
               day = t.monthDay,
               hour = t.hour,
               min = t.minute,
               month = t.month,
               year = t.year
            }
            local deltaTime = time(tEndTime) - time()
            if deltaTime > 0 and deltaTime <= 7 * 24 * 60 * 60 then
               -- found it !!
               local tmpQuestId = 0
               if twIconIds[holiday.texture] then
                  tmpQuestId = twIconIds[holiday.texture]
               else
                  tmpQuestId = holidayNames[holiday.name]
               end
               bonusQuestId = tmpQuestId
               settings.unsortedFolder.weekly.bonusQuestId = tmpQuestId
               if questId == bonusQuestId then
                  local name = Exlist.GetCachedQuestTitle(questId)
                  local completed = C_QuestLog.IsQuestFlaggedCompleted(questId)
                  return name, true, completed
               end
            end
         end
      end
   end
   -- nope
   -- to refresh calendar info
   if not refreshedCalendar then
      refreshedCalendar = true
      ToggleCalendar()
      ToggleCalendar()
   end
   return nil, false, false
end

local DEFAULT_QUESTS = {
   -- Same as trackedQuests
   [53030] = {
      enabled = true,
      type = "weekly",
      default = true,
      showSeparate = false,
      checkFunction = "WeeklyBonusQuest",
      altName = L["World Quest Bonus"]
   }, -- BQ_WQ
   [53037] = {
      enabled = true,
      type = "weekly",
      default = true,
      showSeparate = false,
      checkFunction = "WeeklyBonusQuest",
      altName = L["Dungeon Bonus"]
   },
   -- BQ_Dungeons
   [53036] = {
      enabled = true,
      type = "weekly",
      default = true,
      showSeparate = false,
      checkFunction = "WeeklyBonusQuest",
      altName = L["Battleground Bonus"]
   },
   -- BQ_BGs
   [53039] = {
      enabled = true,
      type = "weekly",
      default = true,
      showSeparate = false,
      checkFunction = "WeeklyBonusQuest",
      altName = L["Arena Bonus"]
   },
   -- BQ_Arenas
   [53038] = {
      enabled = true,
      type = "weekly",
      default = true,
      showSeparate = false,
      checkFunction = "WeeklyBonusQuest",
      altName = L["Pet Battle Bonus"]
   },
   -- BQ_PetBatles
   [44164] = {
      enabled = true,
      type = "weekly",
      default = true,
      showSeparate = false,
      checkFunction = "WeeklyBonusQuest",
      altName = L["BC Timewalking Bonus"]
   },
   -- BQ_TW_BC
   [53033] = {
      enabled = true,
      type = "weekly",
      default = true,
      showSeparate = false,
      checkFunction = "WeeklyBonusQuest",
      altName = L["Wotlk Timewalking Bonus"]
   },
   -- BQ_TW_Wotlk
   [53035] = {
      enabled = true,
      type = "weekly",
      default = true,
      showSeparate = false,
      checkFunction = "WeeklyBonusQuest",
      altName = L["MoP Timewalking Bonus"]
   },
   -- BQ_TW_MoP
   [53034] = {
      enabled = true,
      type = "weekly",
      default = true,
      showSeparate = false,
      checkFunction = "WeeklyBonusQuest",
      altName = L["Cataclysm Timewalking Bonus"]
   }
   -- BQ_TW_Cata
}

local function AddQuest(questId, t)
   -- mby
   if type(questId) ~= "number" then
      print(Exlist.debugString, L["Invalid QuestId"])
      return
   end
   local dbQuests = Exlist.ConfigDB.settings.quests
   dbQuests[questId] = {enabled = true, type = t, showSeparate = false}
   trackedQuests[questId] = {enabled = true, type = t, showSeparate = false}
end

local function RemoveQuest(questId)
   local dbQuests = Exlist.ConfigDB.settings.quests
   dbQuests[questId] = nil
   trackedQuests[questId] = nil
end

local function ChangeType(questId, oldType, newType)
   trackedQuests[questId].type = newType
   local dbQuests = Exlist.ConfigDB.settings.quests
   dbQuests[questId].type = newType

   local realms = Exlist.GetRealmNames()
   for _, realm in ipairs(realms) do
      local characters = Exlist.GetRealmCharacters(realm)
      for _, character in ipairs(characters) do
         Exlist.Debug("Reset", type, "quests for:", character, "-", realm)
         local data = Exlist.GetCharacterTableKey(realm, character, key)
         if data[oldType] and data[oldType][questId] then
            -- found
            data[newType] = data[newType] or {}
            data[newType][questId] = data[oldType][questId]
            data[oldType][questId] = nil
         end
         Exlist.UpdateChar(key, data, character, realm)
      end
   end
end

local function Updater(event)
   local t = {}
   for questId, v in pairs(trackedQuests) do
      if v.checkFunction then
         local name, available, completed = checkFunctions[v.checkFunction](questId)
         if available then
            t[v.type] = t[v.type] or {}
            t[v.type][questId] = {name = name, completed = completed}
         end
      else
         local name = Exlist.QuestInfo(questId)
         local completed = C_QuestLog.IsQuestFlaggedCompleted(questId)
         t[v.type] = t[v.type] or {}
         t[v.type][questId] = {name = name, completed = completed}
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
      titleName = L["Quests"]
   }
   local extraInfos = {}
   local done, available = 0, 0
   local sideTooltip = {title = L["Quests"], body = {}}
   local i = 1
   for _, type in ipairs(questTypeOrder) do
      local v = data[type] or {}
      local added = false
      for questId, values in pairs(v) do
         if trackedQuests[questId] and trackedQuests[questId].enabled then
            if not added then
               table.insert(
                  sideTooltip.body,
                  {WrapTextInColorCode(questTypes[type], colors.questTypeTitle[type]), "", {"headerseparator"}}
               )
               added = true
            end
            available = available + 1
            done = values.completed and done + 1 or done
            local name = Exlist.GetCachedQuestTitle(questId)
            table.insert(
               sideTooltip.body,
               {
                  WrapTextInColorCode(name, colors.questTitle),
                  (values.completed and WrapTextInColorCode(L["Completed"], colors.completed) or
                     WrapTextInColorCode(L["Available"], colors.available))
               }
            )
            if trackedQuests[questId].showSeparate then
               local settings = Exlist.ConfigDB.settings
               local completedString, availableString = L["Completed"], L["Available"]
               if settings.shortenInfo then
                  completedString, availableString = L["Done"], L["Avail"]
               end
               table.insert(
                  extraInfos,
                  {
                     character = character,
                     moduleName = key .. questId,
                     priority = prio + i / 1000,
                     titleName = WrapTextInColorCode(name, colors.questTypeTitle[type]),
                     data = (values.completed and WrapTextInColorCode(completedString, colors.completed) or
                        WrapTextInColorCode(availableString, colors.available))
                  }
               )
               i = i + 1
            end
         end
      end
   end
   info.data = string.format("%i/%i", done, available)
   info.OnEnter = Exlist.CreateSideTooltip()
   info.OnEnterData = sideTooltip
   info.OnLeave = Exlist.DisposeSideTooltip()

   for i, t in ipairs(extraInfos) do
      Exlist.AddData(t)
   end
   if available > 0 then
      Exlist.AddData(info)
   end
end

local function GlobalLineGenerator(tooltip, data)
   if Exlist.ConfigDB.settings.showQuestsInExtra and Exlist.ConfigDB.settings.extraInfoToggles.quests.enabled then
      local charData = Exlist.GetCharacterTableKey(GetRealmName(), UnitName("player"), key)
      if charData then
         for _, type in ipairs(questTypeOrder) do
            local v = charData[type] or {}
            local added = false
            for questId, values in pairs(v) do
               if trackedQuests[questId].enabled then
                  if not added then
                     Exlist.AddLine(
                        tooltip,
                        WrapTextInColorCode(questTypes[type] .. " " .. L["Quests"], colors.questTypeTitle[type]),
                        14
                     )
                     added = true
                  end
                  Exlist.AddLine(
                     tooltip,
                     {
                        Exlist.GetCachedQuestTitle(questId),
                        (values.completed and WrapTextInColorCode(L["Completed"], colors.completed) or
                           WrapTextInColorCode(L["Available"], colors.available))
                     }
                  )
               end
            end
         end
      end
   end
end

local function Modernize(data)
   -- data is table of module table from character
   -- always return table or don't use at all
end

local function ResetHandle(resetType)
   local realms = Exlist.GetRealmNames()
   for _, realm in ipairs(realms) do
      local characters = Exlist.GetRealmCharacters(realm)
      for _, character in ipairs(characters) do
         Exlist.Debug("Reset", resetType, "quests for:", character, "-", realm)
         local data = Exlist.GetCharacterTableKey(realm, character, key)
         if data[resetType] and type(data[resetType]) == "table" then
            wipe(data[resetType])
         end
         Exlist.UpdateChar(key, data, character, realm)
      end
   end
   -- reset Bonus quest
   if resetType == "weekly" then
      Exlist.ConfigDB.settings.unsortedFolder.weekly.bonusQuestId = nil
   end
end

local function SetupQuestConfig(refresh)
   if not Exlist.ConfigDB then
      return
   end
   local settings = Exlist.ConfigDB.settings
   local dbQuests = settings.quests
   local options = {
      type = "group",
      name = L["Quests"],
      args = {
         desc = {
            type = "description",
            order = 1,
            width = "full",
            name = L["Controls quests that are being tracked by addon\n"]
         },
         note = {
            type = "description",
            order = 1,
            width = "full",
            fontSize = "medium",
            name = strings.Note ..
               "  " .. L["Due to restrictions to API Quest Titles might take couple reloads to appear\n"]
         },
         showExtraTooltip = {
            order = 1.05,
            name = L["Show in Extra Tooltip"],
            desc = L["Show selected quests and their completetion in extra tooltip for current character"],
            type = "toggle",
            width = "full",
            get = function()
               return settings.showQuestsInExtra
            end,
            set = function(self, v)
               settings.showQuestsInExtra = v
            end
         },
         itemInput = {
            type = "input",
            order = 1.1,
            name = L["Add Quest ID"],
            get = function()
               return ""
            end,
            set = function(self, v)
               local questId = tonumber(v)
               AddQuest(questId, "daily")
               SetupQuestConfig(true)
               Exlist.SendFakeEvent("EXLIST_REFRESH_QUESTS")
            end,
            width = "full"
         },
         spacer0 = {
            type = "description",
            order = 1.19,
            width = 0.15,
            name = ""
         },
         nameLabel = {
            type = "description",
            order = 1.2,
            width = 1.35,
            fontSize = "large",
            name = WrapTextInColorCode(L["Quest Title"], colors.config.tableColumn)
         },
         typeLabel = {
            type = "description",
            order = 1.3,
            width = 0.55,
            fontSize = "large",
            name = WrapTextInColorCode(L["Type"], colors.config.tableColumn)
         },
         separatelabel = {
            type = "description",
            order = 1.4,
            width = 0.75,
            fontSize = "large",
            name = WrapTextInColorCode(L["Show Separate"], colors.config.tableColumn)
         },
         spacer1 = {
            type = "description",
            order = 1.5,
            width = 0.45,
            name = ""
         }
      }
   }
   local n = 2
   for questId, info in spairs(
      trackedQuests,
      function(t, a, b)
         if (not t[a].default and not t[b].default) or (t[a].default and t[b].default) then
            local nameA = Exlist.GetCachedQuestTitle(a) -- could probably optimize this by having name in trackedQuests
            local nameB = Exlist.GetCachedQuestTitle(b) -- but this shouldnt be running too many times so mehh.
            return nameA < nameB
         end
         return t[a].default and not t[b].default
      end
   ) do
      local o = options.args
      local qname = Exlist.GetCachedQuestTitle(questId)
      if qname and qname:find("Unknown %(") and info.altName then
         qname = info.altName
      end
      o[questId .. "enabled"] = {
         order = n,
         name = WrapTextInColorCode(qname, colors.questTitle),
         type = "toggle",
         width = 1.5,
         get = function()
            return info.enabled
         end,
         set = function(self, v)
            info.enabled = v
         end
      }
      n = n + 1
      o[questId .. "type"] = {
         order = n,
         name = "",
         type = "select",
         values = questTypes,
         width = 0.5,
         disabled = function()
            return info.default
         end,
         get = function()
            return info.type
         end,
         set = function(self, v)
            ChangeType(questId, info.type, v)
         end
      }
      n = n + 1
      o[questId .. "spacer"] = {
         type = "description",
         order = n,
         width = 0.3,
         name = ""
      }
      n = n + 1
      o[questId .. "showSeparate"] = {
         type = "toggle",
         order = n,
         width = 0.45,
         descStyle = "inline",
         name = "  ",
         disabled = function()
            return not info.enabled
         end,
         get = function()
            return info.showSeparate
         end,
         set = function(self, v)
            info.showSeparate = v
            dbQuests[questId].showSeparate = v
         end
      }
      n = n + 1
      o[questId .. "delete"] = {
         type = "execute",
         order = n,
         name = L["Delete"],
         disabled = function()
            return info.default
         end,
         width = 0.5,
         func = function()
            StaticPopupDialogs["DeleteQDataPopup_" .. questId] = {
               text = L["Do you really want to delete "] ..
                  WrapTextInColorCode(Exlist.GetCachedQuestTitle(questId), colors.questTitle) .. "?",
               button1 = OKAY,
               button3 = CANCEL,
               hasEditBox = false,
               OnAccept = function(self)
                  StaticPopup_Hide("DeleteQDataPopup_" .. questId)
                  RemoveQuest(questId)
                  SetupQuestConfig(true)
                  Exlist.NotifyOptionsChange(key)
               end,
               timeout = 0,
               cancels = "DeleteQDataPopup_" .. questId,
               whileDead = true,
               hideOnEscape = true,
               preferredIndex = 4,
               showAlert = 1,
               enterClicksFirstButton = 1
            }
            StaticPopup_Show("DeleteQDataPopup_" .. questId)
         end
      }
      n = n + 1
   end
   if not refresh then
      Exlist.AddModuleOptions(key, options, L["Quests"])
   else
      Exlist.RefreshModuleOptions(key, options, L["Quests"])
   end
end
Exlist.ModuleToBeAdded(SetupQuestConfig)

local deprecietedQuests = {
   48799, -- Fuel of a Doomed World
   49293, -- Invasion Onslaught
   44175, -- WQ Legion
   44171, -- Dungeons Legion
   44173, -- BGs Legion
   44172, -- Arenas Legion
   44174, -- Pet Legion
   44166, -- Wotlk Legion
   45799, -- MoP Legion
   44167 -- Cata Legion
}

local function init()
   -- setup quests
   local dbQuests = Exlist.ConfigDB.settings.quests
   dbQuests = Exlist.AddMissingTableEntries(dbQuests, DEFAULT_QUESTS)
   for _, questId in ipairs(deprecietedQuests) do
      if dbQuests[questId] and dbQuests[questId].default then
         dbQuests[questId] = nil
      end
      if
         Exlist.ConfigDB.settings.unsortedFolder.weekly.bonusQuestId and
            Exlist.ConfigDB.settings.unsortedFolder.weekly.bonusQuestId == questId
       then
         Exlist.ConfigDB.settings.unsortedFolder.weekly.bonusQuestId = nil
      end
   end

   -- add all to tracked
   for questId, t in pairs(dbQuests) do
      trackedQuests[questId] = t
   end

   Exlist.ConfigDB.settings.extraInfoToggles.quests =
      Exlist.ConfigDB.settings.extraInfoToggles.quests or
      {
         name = L["Weekly/Daily Quests"],
         enabled = true
      }
end

local data = {
   name = L["Quests"],
   key = key,
   linegenerator = Linegenerator,
   globallgenerator = GlobalLineGenerator,
   priority = prio,
   updater = Updater,
   event = {
      "QUEST_TURNED_IN",
      "PLAYER_ENTERING_WORLD",
      "QUEST_REMOVED",
      "PLAYER_ENTERING_WORLD_DELAYED",
      "EXLIST_REFRESH_QUESTS"
   },
   weeklyReset = true,
   dailyReset = true,
   description = L["Allows user to track different daily or weekly quests"],
   specialResetHandle = ResetHandle,
   init = init
   -- modernize = Modernize
}

Exlist.RegisterModule(data)
