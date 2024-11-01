local key = "worldquests"
local prio = 130
local Exlist = Exlist
local L = Exlist.L
local table, pairs, ipairs, type, math, time, GetTime, string, tonumber, print =
   table,
   pairs,
   ipairs,
   type,
   math,
   time,
   GetTime,
   string,
   tonumber,
   print
local C_TaskQuest = C_TaskQuest
local GetQuestLogRewardInfo, GetNumQuestLogRewardCurrencies, GetQuestLogRewardCurrencyInfo, GetQuestLogRewardMoney =
   GetQuestLogRewardInfo,
   GetNumQuestLogRewardCurrencies,
   GetQuestLogRewardCurrencyInfo,
   GetQuestLogRewardMoney
local GetCurrentMapAreaID, SetMapByID, ToggleWorldMap = GetCurrentMapAreaID, SetMapByID, ToggleWorldMap
local GetCurrencyInfo, GetSpellInfo, GetItemSpell = GetCurrencyInfo, GetSpellInfo, GetItemSpell
local BonusObjectiveTracker_TrackWorldQuest = BonusObjectiveTracker_TrackWorldQuest
local loadstring = loadstring
local WrapTextInColorCode = WrapTextInColorCode
local timer = Exlist.timers
local trackedQuests = {}
local updateFrq = 30 -- every x minutes max
local rescanTimer
local mapOpens = 0
local colors = Exlist.Colors

local zones = {
   -- BFA
   1355, -- Nazjatar
   1462, -- Mechagon
   -- EK
   14, -- Arathi Highlands
   -- Kalimdor
   62, -- Darkshore
   -- Kultiras
   895, -- Tiragarde Sound
   896, -- Drustvar
   942, -- Stormsong Valley
   -- Zandalar
   864, -- Vol'dun
   863, -- Nazmir
   862, -- Zuldazar
   -- Legion
   -- Broken Isles
   630, -- Aszuna
   641, -- Val'Sharah
   650, -- Highmountain
   634, -- Stormheim
   680, -- Suramar
   646, -- Broken Shore
   -- Argus
   882, -- Mac'reee
   830, -- Kro'kuun
   885, -- Antoran Wastes
   -- Shadowlands
   1533, -- Bastion
   1565, -- Ardenweald
   1536, -- Maldraxxus
   1525, -- Revendreth
   1543, -- The Maw
   1970, -- Zereth Mortis
   -- Dragonflight
   2022, -- The Walking Shores
   2025, -- Thaldraszus
   2023, -- Ohn'ahran Plains
   2023, -- The Azure Span
   2133, -- Zaralek Caverns
   2200, -- Emerald Dream
   -- The War Within
   2248, -- Isle of Dorn
   2214, -- Ringing Deeps
   2215, -- Hallowfall
   2270, -- Azj'kahet
}

local rewardRules = {}
local tmpConfigRule = {
   ruleType = "",
   compareValue = ">",
   rewardName = "",
   amount = 0
}

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

local statusMarks = {
   [true] = [[Interface/Addons/Exlist/Media/Icons/ok-icon]],
   [false] = [[Interface/Addons/Exlist/Media/Icons/cancel-icon]]
}
local function AddCheckmark(text, status)
   return string.format("|T%s:0|t %s", statusMarks[status], text)
end

function Exlist.RegisterWorldQuests(quests, readOnly)
   -- quests = info
   -- readOnly = can't be removed in session
   if type(quests) == "number" then
      trackedQuests[quests] = {enabled = true, readOnly = readOnly}
   elseif type(quests) == "table" then
      for i, questId in ipairs(quests) do
         trackedQuests[questId] = {enabled = true, readOnly = readOnly}
      end
   end
end

local function GetQuestRewards(questId)
   local rewards = {}
   C_TaskQuest.RequestPreloadRewardData(questId)
   local name, texture, numItems = GetQuestLogRewardInfo(1, questId)
   if name then
      local itemType = "item"
      table.insert(rewards, {name = name, amount = numItems, texture = texture, type = itemType})
   end
   for _, currencyReward in ipairs(C_QuestLog.GetQuestRewardCurrencies(questId)) do
      if currencyReward.name then
         table.insert(rewards,
            {
               name = currencyReward.name,
               amount = currencyReward.totalRewardAmount,
               texture = currencyReward.texture,
               type =
               "currency"
            })
      end
   end
   local coppers = GetQuestLogRewardMoney(questId)
   if coppers and coppers > 0 then
      table.insert(
         rewards,
         {
            name = "Gold",
            amount = {
               ["gold"] = math.floor(coppers / 10000),
               ["silver"] = math.floor((coppers / 100) % 100),
               ["coppers"] = math.floor(coppers % 100)
            },
            type = "money"
         }
      )
   end
   local honor = GetQuestLogRewardHonor(questId)
   if honor > 0 then
      table.insert(rewards, {name = "Honor", amount = honor, texture = 1455894, type = "honor"})
   end
   return rewards
end
Exlist.GetQuestRewards = GetQuestRewards

local function compare(current, target, comp)
   if not current or not target then
      return false
   end
   comp = comp or ">="
   -- reduce numbers because of overflows
   current = current / 1000
   target = target / 1000
   local ret = loadstring(string.format("return %f %s %f", current, comp, target))
   return ret()
end

local function CheckRewardRules(rewards)
   if not rewards then
      return
   end
   local rules = Exlist.ConfigDB.settings.wqRules
   local verdict = false
   local ruleId, targetReward
   for i, reward in ipairs(rewards) do
      if rules[reward.type] and rules[reward.type][reward.name] then
         local rule = rules[reward.type][reward.name]
         -- rule for this
         if reward.type == "money" then
            verdict, ruleId, targetReward = compare(reward.amount.gold, rule.amount, rule.compare), rule.id, i
         else
            verdict, ruleId, targetReward = compare(reward.amount, rule.amount, rule.compare), rule.id, i
         end
      end
   end
   return verdict, ruleId, targetReward
end

local function CleanTable(id)
   if not id then
      return
   end
   local gt = Exlist.GetCharacterTableKey("global", "global", key)
   for faction, wqs in pairs(gt) do
      for questId, info in pairs(wqs) do
         if info.ruleid and info.ruleid == id then
            gt[faction][questId] = nil
         end
      end
   end
   Exlist.UpdateChar(key, gt, "global", "global")
end

local function RemoveRule(rewardId, rewardType)
   if not rewardId or not rewardType then
      return
   end
   local rules = Exlist.ConfigDB.settings.wqRules
   CleanTable(rules[rewardType][rewardId].id)
   rules[rewardType][rewardId] = nil
end

local function SetQuestRule(rewardId, rewardType, amount, compare)
   if not rewardId or not rewardType then
      return
   end
   amount = amount or 1
   compare = compare or ">="
   local name = rewardId
   if type(tonumber(name) or "") == "number" then
      if rewardType == "item" then
         name = Exlist.GetCachedItemInfo(rewardId).name
      elseif rewardType == "currency" then
         name = C_CurrencyInfo.GetCurrencyInfo(rewardId)
      end
   else
      name = rewardRules.DEFAULT[rewardType].values[rewardId] or rewardId
   end
   local rules = Exlist.ConfigDB.settings.wqRules
   if rules[rewardType] and rules[rewardType][name] then
      RemoveRule(name, rewardType) -- remove previously set rule
   end
   local id = GetTime() -- for cleaning up when removed
   rules[rewardType] = rules[rewardType] or {}
   rules[rewardType][name] = {amount = amount, compare = compare, id = id}
end

function Exlist.ScanQuests()
   -- add refresh quests
   if not Exlist.ConfigDB then
      return
   end
   local settings = Exlist.ConfigDB.settings
   local rt = {}
   local tl = 500
   for questId, info in pairs(settings.worldQuests) do
      trackedQuests[questId] = {enabled = info.enabled, readOnly = false}
   end
   for index, zoneId in ipairs(zones) do
      local wqs = C_TaskQuest.GetQuestsForPlayerByMapID(zoneId)
      for _, info in pairs(wqs or {}) do
         local timeLeft = C_TaskQuest.GetQuestTimeLeftMinutes(info.questID) or 0
         local rewards = GetQuestRewards(info.questID)
         local checkRules, ruleid, targetReward = CheckRewardRules(rewards)
         if (trackedQuests[info.questID] and trackedQuests[info.questID].enabled) or checkRules then
            local name = C_TaskQuest.GetQuestInfoByQuestID(info.questID)
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            local endTime = time() + (timeLeft * 60)
            if targetReward then
               rewards[targetReward].target = true
            end
            Exlist.Debug("Spotted", name, "world quest - ", key)
            rt[#rt + 1] = {
               name = name,
               questId = info.questID,
               endTime = endTime,
               rewards = rewards,
               zoneId = info.mapID, -- Use mapId provided from API... however Tiragarde Sound still return
               -- Drustvar WQs.. soo why ????
               ruleid = ruleid,
               objectives = objectives
            }
         end
         if timeLeft == 0 then
            timeLeft = 5
         end
         tl = tl > timeLeft and timeLeft or tl
      end
   end
   -- Rescan Scheduling
   Exlist.Debug("Rescan Scheduled in:", tl, "minutes")
   if rescanTimer then
      timer:CancelTimer(rescanTimer)
   end
   rescanTimer = timer:ScheduleTimer(Exlist.ScanQuests, (60 * tl + 30) / 2)

   -- Send Data
   if #rt > 0 then
      Exlist.SendFakeEvent("WORLD_QUEST_SPOTTED", rt)
   end
end

local function RemoveExpiredQuest(questId)
   local gt = Exlist.GetCharacterTableKey("global", "global", key)
   for _, wqs in pairs(gt) do
      wqs[questId] = nil
   end
   Exlist.UpdateChar(key, gt, "global", "global")
end

local function RemoveTrackedQuest(questId)
   if trackedQuests[questId] and not trackedQuests[questId].readOnly then
      trackedQuests[questId] = nil
   end
   local wq = Exlist.ConfigDB.settings.worldQuests
   wq[questId] = nil
   local gt = Exlist.GetCharacterTableKey("global", "global", key)
   for _, wqs in pairs(gt) do
      wqs[questId] = nil
   end
   Exlist.UpdateChar(key, gt, "global", "global")
end

local function GetFormatedRewardString(r, noColor)
   local s = ""
   if r.name == "Gold" then
      if noColor then
         s = r.amount.gold .. "g " .. r.amount.silver .. "s " .. r.amount.coppers .. "c"
      else
         s =
            r.amount.gold ..
            "|cFFd8b21ag|r " .. r.amount.silver .. "|cFFadadads|r " .. r.amount.coppers .. "|cFF995813c|r"
      end
   else
      if r.amount > 1 then
         s = string.format("%ix|T%s:12|t", r.amount, r.texture)
      else
         s = string.format("|T%s:12|t", r.texture)
      end
   end
   return s
end

local function Updater(event, questInfo)
   if event == "PLAYER_ENTERING_WORLD" and UnitLevel("player") >= Exlist.constants.MAX_CHARACTER_LEVEL then
      rescanTimer = timer:ScheduleTimer(Exlist.ScanQuests, 3)
      return
   elseif event == "WORLD_MAP_OPEN" then
      if mapOpens % 10 == 0 then
         Exlist.ScanQuests() -- Scan every 10th map open
      end
      mapOpens = mapOpens + 1
   elseif event == "WORLD_QUEST_SPOTTED" then
      local faction = UnitFactionGroup("player")
      local gt = Exlist.GetCharacterTableKey("global", "global", key)
      gt[faction] = gt[faction] or {}
      if questInfo and #questInfo > 0 then
         local wq = Exlist.ConfigDB.settings.worldQuests
         for i, info in ipairs(questInfo) do
            if (wq[info.questId] or info.ruleid) then
               gt[faction][info.questId] = info
            end
         end

         Exlist.UpdateChar(key, gt, "global", "global")
      end
   end
end

local function Linegenerator(tooltip, data, character)
   -- does nothing
end

local function GlobalLineGenerator(tooltip, data)
   local timeNow = time()
   if data and Exlist.ConfigDB.settings.extraInfoToggles.worldquests.enabled then
      local wq = Exlist.ConfigDB.settings.worldQuests
      local faction = UnitFactionGroup("player")
      local first = true
      for questId, info in spairs(
         data[faction] or {},
         function(t, a, b)
            return t[a].endTime < t[b].endTime
         end
      ) do
         if info.endTime < timeNow or (wq[questId] and not wq[questId].enabled) then
            RemoveExpiredQuest(questId)
         else
            if first then
               Exlist.AddLine(tooltip, {WrapTextInColorCode(L["World Quests"], colors.sideTooltipTitle)}, 14)
               first = false
            end
            -- Refresh rewards
            if not info.rewards or #info.rewards < 1 then
               info.rewards = GetQuestRewards(questId)
            end

            local timeLeft = Exlist.TimeLeftColor(info.endTime - timeNow, {3600, 14400})
            local targetReward = ""
            local sideTooltip = {
               title = WrapTextInColorCode(info.name, colors.questTitle),
               body = {L["Time Left: "] .. timeLeft, WrapTextInColorCode(L["Rewards"], colors.questTitle)}
            }

            for i, reward in ipairs(info.rewards) do
               if reward.target then
                  targetReward = GetFormatedRewardString(reward, true)
               end
               table.insert(sideTooltip.body, GetFormatedRewardString(reward))
            end
            if targetReward == "" then
               targetReward = GetFormatedRewardString(info.rewards[1], true)
            end

            local lineNum =
               Exlist.AddLine(
               tooltip,
               {
                  AddCheckmark(info.name, C_QuestLog.IsQuestFlaggedCompleted(info.questId)),
                  timeLeft,
                  WrapTextInColorCode(
                     string.format("%s  - %s", targetReward, C_Map.GetMapInfo(info.zoneId).name or ""),
                     colors.faded
                  )
               }
            )
            Exlist.AddScript(
               tooltip,
               lineNum,
               nil,
               "OnMouseDown",
               function(self)
                  if not WorldMapFrame:IsShown() then
                     ToggleWorldMap()
                  end
                  WorldMapFrame:SetMapID(info.zoneId)
                  BonusObjectiveTracker_TrackWorldQuest(questId)
               end
            )

            -- Add Objectives to Side Tooltip
            if info.objectives then
               table.insert(sideTooltip.body, WrapTextInColorCode(L["Objectives"], colors.questTitle))
               for i, objective in ipairs(info.objectives) do
                  if objective.type == "progressbar" then
                     table.insert(
                        sideTooltip.body,
                        string.format(
                           "%d/100%% %s",
                           (objective.numFulfilled / objective.numRequired) * 100,
                           objective.text
                        )
                     )
                  else
                     table.insert(sideTooltip.body, objective.text)
                  end
               end
            end
            Exlist.AddScript(tooltip, lineNum, nil, "OnEnter", Exlist.CreateSideTooltip(), sideTooltip)
            Exlist.AddScript(tooltip, lineNum, nil, "OnLeave", Exlist.DisposeSideTooltip())
         end
      end
   end
end

local function SetupWQConfig(refresh)
   if not Exlist.ConfigDB then
      return
   end
   local wq = Exlist.ConfigDB.settings.worldQuests
   local options = {
      type = "group",
      name = L["World Quests"],
      args = {
         desc = {
            type = "description",
            order = 1,
            width = "full",
            name = L["Add World Quests you want to see"]
         },
         forceRefresh = {
            type = "execute",
            order = 1.1,
            width = 1,
            desc = L["Force Refresh World Quests"],
            name = L["Force Refresh"],
            func = function()
               Exlist.ScanQuests()
            end
         },
         itemInput = {
            type = "input",
            order = 1.5,
            name = L["Add World Quest ID"],
            get = function()
               return ""
            end,
            set = function(self, v)
               local questId = tonumber(v)
               local name = Exlist.GetCachedQuestTitle(questId)
               if name then
                  wq[questId] = {
                     name = name,
                     enabled = true,
                     rewards = GetQuestRewards(v)
                  }
                  SetupWQConfig(true)
                  Exlist.ScanQuests()
               else
                  print(Exlist.debugString, L["Invalid World Quest ID:"], v)
               end
            end,
            width = "full"
         }
      }
   }
   local n = 2
   for questID, info in pairs(wq) do
      local o = options.args
      o[questID .. "enabled"] = {
         order = n,
         name = function()
            local name = info.name
            if name:find("Unknown") then
               name = Exlist.GetCachedQuestTitle(questID)
               info.name = name
            end
            return WrapTextInColorCode(name, colors.questTitle)
         end,
         type = "toggle",
         width = "normal",
         get = function()
            return info.enabled
         end,
         set = function(self, v)
            info.enabled = v
         end
      }
      n = n + 1
      if not info.rewards or #info.rewards < 1 then
         info.rewards = GetQuestRewards(questID)
      end
      o[questID .. "rewards"] = {
         order = n,
         name = function()
            return GetFormatedRewardString(info.rewards[1])
         end,
         type = "description",
         width = 1.8
      }
      n = n + 1
      o[questID .. "delete"] = {
         type = "execute",
         order = n,
         name = "Delete",
         width = 0.5,
         func = function()
            StaticPopupDialogs["DeleteWQDataPopup_" .. questID] = {
               text = L["Do you really want to delete"] ..
                  " " .. WrapTextInColorCode(info.name, colors.questTitle) .. "?",
               button1 = "Ok",
               button3 = "Cancel",
               hasEditBox = false,
               OnAccept = function(self)
                  StaticPopup_Hide("DeleteWQDataPopup_" .. questID)
                  RemoveTrackedQuest(questID)
                  SetupWQConfig(true)
                  Exlist.NotifyOptionsChange(key)
               end,
               timeout = 0,
               cancels = "DeleteWQDataPopup_" .. questID,
               whileDead = true,
               hideOnEscape = true,
               preferredIndex = 4,
               showAlert = 1,
               enterClicksFirstButton = 1
            }
            StaticPopup_Show("DeleteWQDataPopup_" .. questID)
         end
      }
   end

   -- Rules
   n = n + 1
   options.args["WQRulesTitle"] = {
      type = "description",
      order = n,
      fontSize = "large",
      width = "full",
      name = WrapTextInColorCode(L["\nWorld Quest rules"], colors.config.heading2)
   }
   n = n + 1
   options.args["WQRulesdesc"] = {
      type = "description",
      order = n,
      width = "full",
      name = L[
         "Add rules by which addon is going to track world quests. \nFor example, show all world quest that have more than 3 Bloods of Sargeras"
      ]
   }
   n = n + 1
   options.args["WQRulesType"] = {
      type = "select",
      order = n,
      width = 0.7,
      name = L["Reward Type"],
      values = rewardRules.types,
      get = function()
         if tmpConfigRule.ruleType == "" then
            tmpConfigRule.ruleType = rewardRules.defaultType
         end
         return tmpConfigRule.ruleType
      end,
      set = function(_, v)
         tmpConfigRule.ruleType = v
         tmpConfigRule.rewardName = rewardRules.DEFAULT[v].defaultValue
         SetupWQConfig(true)
      end
   }
   n = n + 1
   options.args["WQRulesName"] = {
      type = "select",
      order = n,
      width = 1,
      name = L["Reward Name"],
      disabled = function()
         if not rewardRules.DEFAULT[tmpConfigRule.ruleType] then
            tmpConfigRule.ruleType = rewardRules.defaultType
         end
         return rewardRules.DEFAULT[tmpConfigRule.ruleType].disableItems
      end,
      values = function()
         if not rewardRules.DEFAULT[tmpConfigRule.ruleType] then
            tmpConfigRule.ruleType = rewardRules.defaultType
         end
         return rewardRules.DEFAULT[tmpConfigRule.ruleType].values
      end,
      get = function()
         if tmpConfigRule.rewardName == "" then
            tmpConfigRule.rewardName = rewardRules.DEFAULT[tmpConfigRule.ruleType].defaultValue
         end
         return tmpConfigRule.rewardName
      end,
      set = function(_, v)
         tmpConfigRule.rewardName = v
         SetupWQConfig(true)
      end
   }
   n = n + 1
   options.args["WQRulesCompare"] = {
      type = "select",
      order = n,
      width = 0.5,
      name = L["Amount"],
      values = rewardRules.compareValues,
      get = function()
         return tmpConfigRule.compareValue
      end,
      set = function(_, v)
         tmpConfigRule.compareValue = v
         SetupWQConfig(true)
      end
   }
   n = n + 1
   options.args["WQRulesAmount"] = {
      type = "input",
      order = n,
      width = 0.6,
      name = "",
      get = function()
         return tostring(tmpConfigRule.amount)
      end,
      set = function(_, v)
         tmpConfigRule.amount = tonumber(v) or 0
         SetupWQConfig(true)
      end
   }
   n = n + 1
   options.args["WQRulesSpacer"] = {
      type = "description",
      order = n,
      width = 0.1,
      name = ""
   }
   n = n + 1
   options.args["WQRulesSaveBtn"] = {
      type = "execute",
      order = n,
      width = 0.4,
      name = L["Save"],
      func = function()
         local name =
            rewardRules.DEFAULT[tmpConfigRule.ruleType].customFieldValue == tmpConfigRule.rewardName and
            tmpConfigRule.customReward or
            tmpConfigRule.rewardName
         SetQuestRule(name, tmpConfigRule.ruleType, tmpConfigRule.amount, tmpConfigRule.compareValue)
         Exlist.ScanQuests()
         SetupWQConfig(true)
      end
   }

   -- for custom rewards
   if
      rewardRules.DEFAULT[tmpConfigRule.ruleType].useCustom and
         rewardRules.DEFAULT[tmpConfigRule.ruleType].customFieldValue == tmpConfigRule.rewardName
    then
      n = n + 1
      options.args["WQRulesCustomName"] = {
         type = "input",
         order = n,
         width = "full",
         name = L["Custom Reward"],
         get = function()
            return tmpConfigRule.customReward or ""
         end,
         set = function(_, v)
            tmpConfigRule.customReward = v
            SetupWQConfig(true)
         end
      }
   end

   n = n + 1
   options.args["WQRulesLabel1"] = {
      type = "description",
      order = n,
      width = 0.8,
      name = WrapTextInColorCode(L["Reward Name"], colors.config.tableColumn),
      fontSize = "medium"
   }
   n = n + 1
   options.args["WQRulesLabel2"] = {
      type = "description",
      order = n,
      width = 2.4,
      name = WrapTextInColorCode(L["Reward Amount"], colors.config.tableColumn),
      fontSize = "medium"
   }
   -- setup all rules
   local wqRules = Exlist.ConfigDB.settings.wqRules
   for rewardType, t in pairs(wqRules) do
      for rewardName, info in pairs(t) do
         n = n + 1
         options.args["WQRulesListItemName" .. rewardName] = {
            type = "description",
            order = n,
            width = 0.8,
            fontSize = "small",
            name = rewardName or ""
         }
         n = n + 1
         options.args["WQRulesListItemCompare" .. rewardName] = {
            type = "description",
            order = n,
            width = 0.1,
            fontSize = "small",
            name = info.compare or ""
         }
         n = n + 1
         options.args["WQRulesListItemAmount" .. rewardName] = {
            type = "description",
            order = n,
            width = 2,
            fontSize = "small",
            name = Exlist.ShortenNumber(info.amount or 0, 1)
         }
         n = n + 1
         options.args["WQRulesListItemDelete" .. rewardName] = {
            type = "execute",
            order = n,
            name = L["Delete"],
            width = 0.5,
            func = function()
               StaticPopupDialogs["DeleteWQRuleDataPopup_" .. rewardName] = {
                  text = L["Do you really want to delete this rule?"],
                  button1 = "Ok",
                  button3 = "Cancel",
                  hasEditBox = false,
                  OnAccept = function(self)
                     StaticPopup_Hide("DeleteWQRuleDataPopup_" .. rewardName)
                     RemoveRule(rewardName, rewardType)
                     SetupWQConfig(true)
                     Exlist.NotifyOptionsChange(key)
                  end,
                  timeout = 0,
                  cancels = "DeleteWQRuleDataPopup_" .. rewardName,
                  whileDead = true,
                  hideOnEscape = true,
                  preferredIndex = 4,
                  showAlert = 1,
                  enterClicksFirstButton = 1
               }
               StaticPopup_Show("DeleteWQRuleDataPopup_" .. rewardName)
            end
         }
      end
   end

   if not refresh then
      Exlist.AddModuleOptions(key, options, L["World Quests"])
   else
      Exlist.RefreshModuleOptions(key, options, L["World Quests"])
   end
end
--Exlist.ModuleToBeAdded(SetupWQConfig)

local function init()
   local gt = Exlist.GetCharacterTableKey("global", "global", key)
   for key in pairs(gt) do
      if key ~= "Alliance" and key ~= "Horde" then
         gt[key] = nil
      end
   end
   Exlist.UpdateChar(key, gt, "global", "global")

   rewardRules = {
      types = {
         currency = L["Currency"],
         item = L["Item"],
         money = L["Gold"],
         honor = L["Honor"]
      },
      compareValues = {
         ["<"] = "<",
         ["<="] = "<=",
         ["=="] = "=",
         [">"] = ">",
         [">="] = ">="
      },
      DEFAULT = {
         currency = {
            values = {
               -- Legion
               [1220] = C_CurrencyInfo.GetCurrencyInfo(1220), -- Order Resources
               [1508] = C_CurrencyInfo.GetCurrencyInfo(1508), -- Veiled Argunite
               [1226] = C_CurrencyInfo.GetCurrencyInfo(1226), -- Nethershard
               [1533] = C_CurrencyInfo.GetCurrencyInfo(1533), -- Wakening Essences
               -- BFA
               [1560] = C_CurrencyInfo.GetCurrencyInfo(1560), -- War Resources
               [1553] = C_CurrencyInfo.GetCurrencyInfo(1553), -- Azerite
               --
               [0] = L["Custom Currency"]
            },
            defaultValue = 1553,
            disableItems = false,
            useCustom = true,
            customFieldValue = 0
         },
         item = {
            values = {
               [124124] = Exlist.GetCachedItemInfo(124124).name, -- Blood of Sargeras
               [137642] = Exlist.GetCachedItemInfo(137642).name, -- Mark of Honor
               [151568] = Exlist.GetCachedItemInfo(151568).name, -- Primal Sargerite
               [0] = "Custom"
            },
            defaultValue = 124124,
            disableItems = false,
            useCustom = true,
            customFieldValue = 0
         },
         money = {
            values = {
               gold = L["Gold"]
            },
            defaultValue = "gold",
            disableItems = true,
            useCustom = false
         },
         honor = {
            values = {
               honor = L["Honor"]
            },
            defaultValue = "honor",
            disableItems = true,
            useCustom = false
         }
      },
      defaultType = "currency"
   }
   tmpConfigRule.ruleType = rewardRules.defaultType

   Exlist.ConfigDB.settings.extraInfoToggles.worldquests =
      Exlist.ConfigDB.settings.extraInfoToggles.worldquests or
      {
         name = L["World Quests"],
         enabled = true
      }
end

local data = {
   name = L["World Quests"],
   key = key,
   linegenerator = Linegenerator,
   globallgenerator = GlobalLineGenerator,
   priority = prio,
   updater = Updater,
   event = {"WORLD_QUEST_SPOTTED", "PLAYER_ENTERING_WORLD", "WORLD_MAP_OPEN"},
   weeklyReset = false,
   description = L[
      "Tracks user specified world quests. Provides information like - Time Left, Reward and availability for current character"
   ],
   override = true,
   init = init
}

Exlist.RegisterModule(data)
