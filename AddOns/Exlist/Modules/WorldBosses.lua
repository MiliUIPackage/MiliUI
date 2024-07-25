local key = "worldboss"
local prio = 120
local Exlist = Exlist
local colors = Exlist.Colors
local L = Exlist.L
local EJ_GetEncounterInfo = EJ_GetEncounterInfo
local UnitLevel, GetRealmName, UnitName = UnitLevel, GetRealmName, UnitName
local WrapTextInColorCode = WrapTextInColorCode
local string, table = string, table
local C_TaskQuest, C_WorldMap, EJ_GetCreatureInfo, C_ContributionCollector, C_Timer =
    C_TaskQuest,
    C_WorldMap,
    EJ_GetCreatureInfo,
    C_ContributionCollector,
    C_Timer
local pairs, ipairs, time, select = pairs, ipairs, time, select
local GetTime = GetTime
local IsInRaid, IsInInstance = IsInRaid, IsInInstance
local GetCurrentMapAreaID, SetMapByID, GetMapNameByID = GetCurrentMapAreaID, SetMapByID, GetMapNameByID
local GetNumMapLandmarks, GetMapLandmarkInfo = GetNumMapLandmarks, GetMapLandmarkInfo
local GetSpellInfo = GetSpellInfo
local GameTooltip = GameTooltip

local worldBossIDs = {
   -- MoP
   [32099] = { eid = 691, expansion = 5, enabled = false },                                  -- Sha of Anger
   [32098] = { eid = 725, expansion = 5, enabled = false },                                  -- Galleon
   [32518] = { eid = 814, expansion = 5, enabled = false },                                  -- Nalak
   [32519] = { eid = 826, expansion = 5, enabled = false },                                  -- Oondasta
   [33117] = { eid = 857, expansion = 5, enabled = false, name = L["The Four Celestials"] }, -- Chi-Ji
   -- WoD
   [37462] = {
      eid = 1211,
      expansion = 6,
      name = select(2, EJ_GetCreatureInfo(1, 1291)):match("^[^ ]+") ..
          " / " .. select(2, EJ_GetCreatureInfo(1, 1211)):match("^[^ ]+"),
      enabled = false
   },                                                                                                     -- Drov/Tarlna share a loot and quest atm
   [37464] = { eid = 1262, expansion = 6, enabled = false },                                              -- Rukhmar
   [39380] = { eid = 1452, expansion = 6, enabled = false },                                              -- Kazzak
   -- Legion
   [42270] = { eid = 1749, expansion = 7, enabled = false, wq = true },                                   -- Nithogg
   [42269] = { eid = 1756, expansion = 7, name = EJ_GetEncounterInfo(1756), enabled = false, wq = true }, -- The Soultakers
   [42779] = { eid = 1763, expansion = 7, enabled = false, wq = true },                                   -- Shar'thos
   [43192] = { eid = 1769, expansion = 7, enabled = false, wq = true },                                   -- Levantus
   [42819] = { eid = 1770, expansion = 7, enabled = false, wq = true },                                   -- Humongris
   [43193] = { eid = 1774, expansion = 7, enabled = false, wq = true },                                   -- Calamir
   [43513] = { eid = 1783, expansion = 7, enabled = false, wq = true },                                   -- Na'zak the Fiend
   [43448] = { eid = 1789, expansion = 7, enabled = false, wq = true },                                   -- Drugon the Frostblood
   [43512] = { eid = 1790, expansion = 7, enabled = false, wq = true },                                   -- Ana-Mouz
   [43985] = { eid = 1795, expansion = 7, enabled = false, wq = true },                                   -- Flotsam
   [44287] = { eid = 1796, expansion = 7, enabled = false, wq = true },                                   -- Withered Jim
   [46947] = { eid = 1883, expansion = 7, enabled = false, wq = true },                                   -- Brutallus
   [46948] = { eid = 1884, expansion = 7, enabled = false, wq = true },                                   -- Malificus
   [46945] = { eid = 1885, expansion = 7, enabled = false, wq = true },                                   -- Si'vash
   [47061] = { eid = 1956, expansion = 7, enabled = false, wq = true },                                   -- Apocron
   -- BFA
   [52847] = { eid = 2213, warfront = "Arathi", expansion = 8, enabled = false, wq = true },              -- Doom's Howl
   [52848] = { eid = 2212, warfront = "Arathi", expansion = 8, enabled = false, wq = true },              -- The Lion's Roar
   [52196] = { eid = 2210, expansion = 8, enabled = false, wq = true },                                   -- Dunegorger Kraulok
   [52181] = { eid = 2139, expansion = 8, enabled = false, wq = true },                                   -- T'zane
   [52169] = { eid = 2141, expansion = 8, enabled = false, wq = true },                                   -- Ji'arak
   [52157] = { eid = 2197, expansion = 8, enabled = false, wq = true },                                   -- Hailstone Construct
   [52163] = { eid = 2199, expansion = 8, enabled = false, wq = true },                                   -- Azurethos, The Winged Typhoon
   [52166] = { eid = 2198, expansion = 8, enabled = false, wq = true },                                   -- Warbringer Yenajz
   [54896] = { eid = 2329, warfront = "Darkshore", expansion = 8, enabled = false, wq = true },           -- Ivus the Forest Lord
   [54895] = { eid = 2345, warfront = "Darkshore", expansion = 8, enabled = false, wq = true },           -- Ivus the Decayed
   -- Shadowlands
   [61813] = { eid = 2430, expansion = 9, enabled = true, wq = true },                                    -- Valinor, the Light of Eons
   [61814] = { eid = 2433, expansion = 9, enabled = true, wq = true },                                    -- Nurgash Muckformed
   [61815] = { eid = 2432, expansion = 9, enabled = true, wq = true },                                    -- Oranomonos the Everbanching
   [61816] = { eid = 2431, expansion = 9, enabled = true, wq = true },                                    -- Mortanis
   [64531] = { eid = 2456, expansion = 9, enabled = true, wq = true },                                    -- Mor'geth
   [65143] = { eid = 2468, expansion = 9, enabled = true, wq = true },                                    -- Antros
   -- Dragonflight
   [69930] = { eid = 2506, expansion = 10, enabled = true, wq = true },                                   -- Basrikron
   [69929] = { eid = 2515, expansion = 10, enabled = true, wq = true },                                   -- Strunraan
   [69927] = { eid = 2517, expansion = 10, enabled = true, wq = true },                                   -- Bazual
   [69928] = { eid = 2518, expansion = 10, enabled = true, wq = true },                                   -- Liskanoth
   [74892] = { eid = 2531, expansion = 10, enabled = true, wq = true },                                   -- Zaqali Elders
   [76367] = { eid = 2562, expansion = 10, enabled = true, wq = true },                                   -- Aurostor
   -- The War Within
   [81624] = { eid = 2625, expansion = 11, enabled = true, wq = true },                                   -- Orta
   [81653] = { eid = 2636, expansion = 11, enabled = true, wq = true },                                   -- Shurrai
   [82653] = { eid = 2635, expansion = 11, enabled = true, wq = true },                                   -- Aggregation
   [81630] = { eid = 2625, expansion = 11, enabled = true, wq = true },                                   -- Kordac


}
local lastUpdate = 0
local warfronts = {
   Arathi = { Horde = 11, Alliance = 116 },
   Darkshore = { Alliance = 117, Horde = 118 }
}

local statusMarks = {
   [true] = [[Interface/Addons/Exlist/Media/Icons/ok-icon]],
   [false] = [[Interface/Addons/Exlist/Media/Icons/cancel-icon]]
}
local function AddCheckmark(text, status)
   return string.format("|T%s:0|t %s", statusMarks[status], text)
end

local factions = { "Horde", "Alliance" }
local function OpossiteFacton(faction)
   return factions[1] ~= faction and factions[1] or factions[2]
end

local function GetWarfrontEnd(warfront)
   local faction = UnitFactionGroup("player")
   local state, pctComplete, timeNext = C_ContributionCollector.GetState(warfronts[warfront][faction])
   if state == 2 then
      return { value = timeNext, type = "time" }
   elseif state == 1 and pctComplete < 1 then
      return { value = pctComplete, type = "pct" }
   else
      state, pctComplete, timeNext = C_ContributionCollector.GetState(warfronts[warfront][OpossiteFacton(faction)])
      if state == 1 then
         return { value = pctComplete, type = "pct" }
      end
   end
end

local function FormatEndTime(timeInfo)
   local timeNow = time()
   if type(timeInfo) == "table" then
      if timeInfo.type == "pct" then
         return string.format("%.1f%%", timeInfo.value * 100)
      else
         return Exlist.TimeLeftColor(timeInfo.value - timeNow)
      end
   else
      return Exlist.TimeLeftColor(timeInfo - timeNow)
   end
end

local function GetWarfrontStatus()
   local t = {}
   for wf, ids in pairs(warfronts) do
      t[wf] = {}
      for faction, id in pairs(ids) do
         local state, pctComplete, timeNext, timeStart = C_ContributionCollector.GetState(id)
         local appearanceData = C_ContributionCollector.GetContributionAppearance(id, state)
         local name = C_ContributionCollector.GetName(id)
         t[wf][faction] = {
            name = name,
            faction = faction,
            state = state,
            stateName = appearanceData and appearanceData.stateName or L["Contributing"],
            contributed = pctComplete,
            timeNext = timeNext,
            timeStart = timeStart
         }
      end
   end

   return t
end

local function Updater(e, info)
   local wbSettings = Exlist.GetSettings("worldbosses")
   if e == "WORLD_QUEST_SPOTTED" and #info > 0 then
      -- got info from WQ module
      local t = Exlist.GetCharacterTableKey((GetRealmName()), (UnitName("player")), key)
      local gt = Exlist.GetCharacterTableKey("global", "global", key)
      gt.worldbosses = gt.worldbosses or {}
      local db = gt.worldbosses
      for _, wq in ipairs(info) do
         local defaultInfo = wbSettings[wq.questId]
         if defaultInfo and defaultInfo.enabled then
            local endTime = defaultInfo.warfront and GetWarfrontEnd(defaultInfo.warfront) or wq.endTime
            t[wq.questId] = {
               name = defaultInfo.name or select(2, EJ_GetCreatureInfo(1, defaultInfo.eid)),
               defeated = C_QuestLog.IsQuestFlaggedCompleted(wq.questId),
               endTime = endTime
            }
            db[wq.questId] = {
               name = defaultInfo.name or select(2, EJ_GetCreatureInfo(1, defaultInfo.eid)),
               endTime = endTime,
               zoneId = wq.zoneId,
               questId = wq.questId
            }
         end
      end
      Exlist.UpdateChar(key, t)
      Exlist.UpdateChar(key, gt, "global", "global")
      return
   elseif GetTime() - lastUpdate < 5 then
      -- Check for cached WB kill status
      local t = Exlist.GetCharacterTableKey((GetRealmName()), (UnitName("player")), key)
      local changed = false
      for questId, info in pairs(t) do
         if not info.defeated and C_QuestLog.IsQuestFlaggedCompleted(questId) then
            t[questId].defeated = true
            changed = true
         end
      end
      if changed then
         Exlist.UpdateChar(key, t)
      end
      return
   end
   if e == "PLAYER_ENTERING_WORLD" or e == "EJ_DIFFICULTY_UPDATE" then
      C_Timer.After(
         1,
         function()
            Exlist.SendFakeEvent("PLAYER_ENTERING_WORLD_DELAYED")
         end
      ) -- delay update
      return
   end
   lastUpdate = GetTime()
   local t = Exlist.GetCharacterTableKey((GetRealmName()), (UnitName("player")), key)
   local gt = Exlist.GetCharacterTableKey("global", "global", key)
   gt.worldbosses = gt.worldbosses or {}
   local timeNow = time()
   -- Check global
   for questId, info in pairs(gt.worldbosses) do
      if not t[questId] then
         local defaultInfo = worldBossIDs[questId]
         if defaultInfo then
            t[questId] = {
               name = info.name or "",
               defeated = C_QuestLog.IsQuestFlaggedCompleted(questId),
               endTime = info.endTime
            }
         end
      end
   end
   -- Check non WQ World Bosses that are enabled to track
   for questId, wb in pairs(wbSettings) do
      if (wb.enabled and (not wb.wq or C_QuestLog.IsQuestFlaggedCompleted(questId))) then
         t[questId] = {
            name = wb.name or select(2, EJ_GetCreatureInfo(1, wb.eid)),
            defeated = C_QuestLog.IsQuestFlaggedCompleted(questId),
            endTime = Exlist.GetNextWeeklyResetTime()
         }
      end
   end

   if (UnitLevel("player") == 50) then
      -- Warfronts
      gt.warfronts = GetWarfrontStatus()
   end

   Exlist.UpdateChar(key, t)
   Exlist.UpdateChar(key, gt, "global", "global")
end

local function Linegenerator(_, data, character)
   if not data then
      return
   end

   local availableWB = 0
   local killed = 0
   local strings = {}
   local timeNow = time()
   local wbSettings = Exlist.GetSettings("worldbosses")
   for questId, info in pairs(data) do
      local default = wbSettings[questId]
      if (default and default.enabled and info.name) then
         availableWB = availableWB + 1
         killed = info.defeated and killed + 1 or killed
         strings[default.expansion] = strings[default.expansion] or {}
         table.insert(
            strings[default.expansion],
            {
               string.format(
                  "%s (%s)",
                  info.name,
                  info.endTime and (type(info.endTime) == "table" or info.endTime > timeNow) and
                  FormatEndTime(info.endTime) or
                  WrapTextInColorCode(L["Not Available"], colors.notavailable)
               ),
               info.defeated and WrapTextInColorCode(L["Defeated"], colors.completed) or
               WrapTextInColorCode(L["Available"], colors.available)
            }
         )
      end
   end
   if availableWB > 0 then
      local body = {}
      for expansion, data in Exlist.spairs(
         strings,
         function(t, a, b)
            return a > b
         end
      ) do
         table.insert(
            body,
            string.format("%s", WrapTextInColorCode(Exlist.Expansions[expansion], colors.sideTooltipTitle))
         )
         for _, s in ipairs(data) do
            table.insert(body, s)
         end
      end

      local sideTooltip = {
         body = body,
         title = WrapTextInColorCode(L["World Bosses"], colors.sideTooltipTitle)
      }
      local info = {
         character = character,
         moduleName = key,
         priority = prio,
         titleName = WrapTextInColorCode(L["World Bosses"] .. ":", colors.faded),
         data = string.format("%i/%i", killed, availableWB),
         OnEnter = Exlist.CreateSideTooltip(),
         OnEnterData = sideTooltip,
         OnLeave = Exlist.DisposeSideTooltip()
      }
      Exlist.AddData(info)
   end
end

local function GetWFCurrentStatus(wf)
   local faction = UnitFactionGroup("player")
   local tmp = wf[faction]
   for f, data in pairs(wf) do
      if faction ~= f then
         -- states: 1 - contributing, 2 - siege, 3 - ??, 4 - patrol
         if data.state == 1 or data.state == 2 then
            tmp = data
         end
      end
   end
   local stateName = tmp.stateName
   if tmp.state == 1 or tmp.state == 2 then
      stateName = L[tmp.faction] .. " " .. stateName
   end
   return tmp.name, stateName, tmp.timeNext and tmp.timeNext - time(), tmp.contributed
end

local function GlobalLineGenerator(tooltip, data)
   local timeNow = time()
   if not data then
      return
   end
   local wbSettings = Exlist.GetSettings("worldbosses")
   if data.worldbosses and Exlist.ConfigDB.settings.extraInfoToggles.worldbosses.enabled then
      local added = false
      for questId, info in pairs(data.worldbosses) do
         if (wbSettings[questId] and wbSettings[questId].enabled) then
            if type(info.endTime) == "table" or info.endTime > timeNow then
               if not added then
                  added = true
                  Exlist.AddLine(
                     tooltip,
                     {
                        WrapTextInColorCode(L["World Bosses"], colors.sideTooltipTitle)
                     },
                     14
                  )
               end
               local lineNum =
                   Exlist.AddLine(
                      tooltip,
                      {
                         AddCheckmark(info.name, C_QuestLog.IsQuestFlaggedCompleted(questId)),
                         FormatEndTime(info.endTime)
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
            end
         end
      end
   end
   if data.warfronts and Exlist.ConfigDB.settings.extraInfoToggles.warfronts.enabled then
      Exlist.AddLine(
         tooltip,
         {
            WrapTextInColorCode(L["Warfronts"], colors.sideTooltipTitle)
         },
         14
      )
      for _, wfData in pairs(data.warfronts) do
         local name, stateName, timeLeft, pct = GetWFCurrentStatus(wfData)
         Exlist.AddLine(
            tooltip,
            {
               name,
               stateName,
               pct < 1 and string.format("%.1f%%", pct * 100) or Exlist.TimeLeftColor(timeLeft)
            }
         )
      end
   end
end

local function RegisterWorldBossWQs()
   local t = {}
   for questId, info in pairs(worldBossIDs) do
      if (info.wq and info.enabled) then
         t[#t + 1] = questId
      end
   end
   Exlist.RegisterWorldQuests(t, true)
end

local function init()
   RegisterWorldBossWQs()
   Exlist.ConfigDB.settings.extraInfoToggles.worldbosses =
       Exlist.ConfigDB.settings.extraInfoToggles.worldbosses or { name = L["World Bosses"], enabled = true }
   Exlist.ConfigDB.settings.extraInfoToggles.warfronts =
       Exlist.ConfigDB.settings.extraInfoToggles.warfronts or { name = L["Warfronts"], enabled = true }
   -- BFA Prepatch Retire
   Exlist.ConfigDB.settings.extraInfoToggles.invasions = nil
   Exlist.ConfigDB.settings.extraInfoToggles.brokenshore = nil
   local gt = Exlist.GetCharacterTableKey("global", "global", key)
   if gt.worldbosses and gt.worldbosses.argus then
      local t = {}
      for _, quests in pairs(gt.worldbosses) do
         for questId, info in pairs(quests) do
            t[questId] = info
         end
      end
      gt.worldbosses = t
      Exlist.UpdateChar(key, gt, "global", "global")
   end
end

local function AddWorldBossOptions()
   local settings = Exlist.ConfigDB.settings
   settings.worldbosses = settings.worldbosses or {}
   -- add missing raids
   settings.worldbosses = Exlist.AddMissingTableEntries(settings.worldbosses, worldBossIDs)
   -- Options
   local numExpansions = #Exlist.Expansions
   local configOpt = {
      type = "group",
      name = "World Bosses",
      args = {
         desc = {
            type = "description",
            name = L["Enable world bosses you want to see\n"],
            width = "full",
            order = 0
         }
      }
   }
   -- add worldbosses
   for questId, opt in pairs(settings.worldbosses) do
      configOpt.args[questId] = {
         type = "toggle",
         order = (numExpansions - opt.expansion + 1.1),
         width = "full",
         name = opt.name or select(2, EJ_GetCreatureInfo(1, opt.eid)),
         get = function()
            return opt.enabled
         end,
         set = function(self, v)
            opt.enabled = v
            RegisterWorldBossWQs()
            Updater()
         end
      }
   end

   -- add labels
   for i = numExpansions, 5, -1 do
      configOpt.args["wb" .. i] = {
         type = "description",
         name = WrapTextInColorCode(Exlist.Expansions[i], colors.config.heading1),
         fontSize = "large",
         width = "full",
         order = numExpansions - i + 1
      }
   end
   Exlist.AddModuleOptions(key, configOpt, L["World Bosses"])
end
Exlist.ModuleToBeAdded(AddWorldBossOptions)

local data = {
   name = L["World Bosses"],
   key = key,
   linegenerator = Linegenerator,
   globallgenerator = GlobalLineGenerator,
   priority = prio,
   updater = Updater,
   event = {
      "PLAYER_ENTERING_WORLD",
      "EJ_DIFFICULTY_UPDATE",
      "PLAYER_ENTERING_WORLD_DELAYED",
      "WORLD_QUEST_SPOTTED",
      "BOSS_KILL"
   },
   description = L["Tracks World Boss availability for each character."],
   weeklyReset = true,
   init = init
}

Exlist.RegisterModule(data)
