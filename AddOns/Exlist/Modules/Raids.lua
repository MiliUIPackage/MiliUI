local key = "raids"
local prio = 100
local Exlist = Exlist
local colors = Exlist.Colors
local L = Exlist.L
local pairs, ipairs, type = pairs, ipairs, type
local WrapTextInColorCode = WrapTextInColorCode
local LFRencounters = {}
local GetNumSavedInstances, GetSavedInstanceInfo, GetSavedInstanceEncounterInfo, GetLFGDungeonEncounterInfo =
   GetNumSavedInstances,
   GetSavedInstanceInfo,
   GetSavedInstanceEncounterInfo,
   GetLFGDungeonEncounterInfo
local table = table

local defaultSettings = {}

local raidDifficultyIds = {
   -- in order too
   --17, -- LFR (I overwrite this)
   3, -- 10 Player
   5, -- 10 Player (Heroic)
   4, -- 25 Player
   6, -- 25 Player (Heroic)
   14, -- Normal
   15, -- Heroic
   16 -- Mythic
}
local diffOrder = {"LFR"}
local diffShortened = {LFR = L[" LFR"]}
local diffShort = {
   [3] = L[" 10M"],
   [5] = L[" 10HC"],
   [4] = L[" 25M"],
   [6] = L[" 25HC"],
   [14] = L[" N"],
   [15] = L[" HC"],
   [16] = L[" M"]
}
local function AddRaidOptions()
   local settings = Exlist.ConfigDB.settings
   settings.raids = settings.raids or {}
   -- add missing raids
   settings.raids = Exlist.AddMissingTableEntries(settings.raids, defaultSettings)
   -- Options
   local numExpansions = #Exlist.Expansions
   local configOpt = {
      type = "group",
      name = L["Raids"],
      args = {
         desc = {
            type = "description",
            name = L["Enable raids you want to see\n"],
            width = "full",
            order = 0
         }
      }
   }
   -- add labels
   for i = numExpansions, 1, -1 do
      configOpt.args["expac" .. i] = {
         type = "description",
         name = WrapTextInColorCode(Exlist.Expansions[i], colors.config.heading1),
         fontSize = "large",
         width = "full",
         order = numExpansions - i + 1
      }
   end

   -- add raids
   for raid, opt in pairs(settings.raids) do
      configOpt.args[raid] = {
         type = "toggle",
         order = (numExpansions - opt.expansion + 1) + opt.order / 100,
         width = "full",
         name = raid,
         get = function()
            return opt.enabled
         end,
         set = function(self, v)
            opt.enabled = v
         end
      }
   end
   Exlist.AddModuleOptions(key, configOpt, L["Raids"])
end
Exlist.ModuleToBeAdded(AddRaidOptions)

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

local function Updater(event, ...)
   if event == "ENCOUNTER_END" then
      RequestRaidInfo()
      return
   end
   local t = {}
   local raids = Exlist.ConfigDB.settings.raids or {}
   for i = 1, GetNumSavedInstances() do
      local name, _, _, _, locked, extended, _, isRaid, _, difficultyName, numEncounters, encounterProgress =
         GetSavedInstanceInfo(i)
      if isRaid then
         t[name] = t[name] or {}
         t[name][difficultyName] = {
            ["done"] = encounterProgress,
            ["max"] = numEncounters,
            ["locked"] = locked,
            ["extended"] = extended,
            ["bosses"] = {}
         }
         if locked then
            local tt = t[name][difficultyName]
            -- add info about killed bosses too
            for j = 1, numEncounters do
               local bName, _, isKilled = GetSavedInstanceEncounterInfo(i, j)
               table.insert(tt.bosses, {name = bName, killed = isKilled})
               --t.bosses[bName] = isKilled
            end
         end
      end
   end
   -- lfr
   local isHorde = UnitFactionGroup("player") == "Horde"
   for raid, c in pairs(LFRencounters) do
      if raids[raid] and raids[raid].enabled then
         Exlist.Debug("Scanning ", raid)
         local killed = 0
         local total = 0
         t[raid] = t[raid] or {}
         t[raid].LFR = t[raid].LFR or {}
         t[raid].LFR = {bosses = {}}
         for id, lfr in spairs(
            c,
            function(t, a, b)
               return t[a].order < t[b].order
            end
         ) do
            if lfr.horde == nil or lfr.horde == isHorde then
               total = not lfr.dontCount and total + lfr.totalEncounters or total
               local saveId = lfr.saveId or id
               if lfr.map then
                  for index, i in ipairs(lfr.map) do
                     local bossName, _, isKilled = GetLFGDungeonEncounterInfo(id, i)
                     killed = isKilled and killed + 1 or killed
                     t[raid].LFR.bosses[saveId] = t[raid].LFR.bosses[saveId] or {}
                     t[raid].LFR.bosses[saveId].order = lfr.order
                     t[raid].LFR.bosses[saveId][lfr.name] = t[raid].LFR.bosses[saveId][lfr.name] or {}
                     if
                        (t[raid].LFR.bosses[saveId][lfr.name][index] and isKilled) or
                           not t[raid].LFR.bosses[saveId][lfr.name][index]
                      then
                        t[raid].LFR.bosses[saveId][lfr.name][index] = {name = bossName, killed = isKilled}
                     end
                  end
               else
                  local index = 1
                  local offset = lfr.firstBoss or 1
                  for i = offset, (offset + lfr.totalEncounters - 1) do
                     local bossName, _, isKilled = GetLFGDungeonEncounterInfo(id, i)
                     killed = isKilled and killed + 1 or killed
                     t[raid].LFR.bosses[saveId] = t[raid].LFR.bosses[saveId] or {}
                     t[raid].LFR.bosses[saveId].order = lfr.order
                     t[raid].LFR.bosses[saveId][lfr.name] = t[raid].LFR.bosses[saveId][lfr.name] or {}
                     if
                        (t[raid].LFR.bosses[saveId][lfr.name][index] and isKilled) or
                           not t[raid].LFR.bosses[saveId][lfr.name][index]
                      then
                        t[raid].LFR.bosses[saveId][lfr.name][index] = {name = bossName, killed = isKilled}
                     end
                     index = index + 1
                  end
               end
            end
         end
         t[raid].LFR.done = killed
         t[raid].LFR.max = total
         t[raid].LFR.locked = killed > 0
      end
      Exlist.UpdateChar(key, t)
   end
end

local function Linegenerator(tooltip, data, character)
   if not data then
      return
   end
   local raids = Exlist.ConfigDB.settings.raids or {}
   local info = {character = character}
   local infoTables = {}
   -- setup order
   local raidOrder = {}
   for raid in pairs(data) do
      if raids[raid] and raids[raid].enabled then
         raidOrder[#raidOrder + 1] = raid
      end
   end
   table.sort(
      raidOrder,
      function(a, b)
         local aValue = (raids[a].expansion or 0) * 100 + (50 - (raids[a].order or 0))
         local bValue = (raids[b].expansion or 0) * 100 + (50 - (raids[b].order or 0))
         return aValue > bValue
      end
   )
   for index = 1, #raidOrder do
      if data[raidOrder[index]] then
         -- Raid
         info.priority =
            prio + (index / 100) +
            ((20 - raids[raidOrder[index]].expansion) + 50 - raids[raidOrder[index]].order) / 1000
         local added = false
         local cellIndex = 1
         local line
         for difIndex = 1, #diffOrder do
            -- difficulties
            local raidInfo = data[raidOrder[index]][diffOrder[difIndex]]
            if raidInfo and raidInfo.locked then
               --killed something
               if not added then
                  -- raid shows up first time
                  info.moduleName = raidOrder[index]
                  info.titleName = WrapTextInColorCode(raidOrder[index], colors.faded)
                  added = true
                  cellIndex = cellIndex + 1
               end
               local sideTooltipTable = {
                  title = WrapTextInColorCode(
                     raidOrder[index] .. " (" .. diffOrder[difIndex] .. ")",
                     colors.sideTooltipTitle
                  ),
                  body = {}
               }

               -- Side Tooltip Data
               if difIndex == 1 then
                  -- LFR
                  for id in spairs(
                     raidInfo.bosses,
                     function(t, a, b)
                        return t[a].order < t[b].order
                     end
                  ) do
                     Exlist.Debug("Adding LFR id:", id, " -", key)
                     for name, b in pairs(raidInfo.bosses[id]) do
                        if type(b) == "table" then
                           table.insert(sideTooltipTable.body, {WrapTextInColorCode(name, colors.faded), ""})
                           for i = 1, #b do
                              table.insert(
                                 sideTooltipTable.body,
                                 {
                                    b[i].name,
                                    b[i].killed and WrapTextInColorCode(L["Defeated"], colors.completed) or
                                       WrapTextInColorCode(L["Available"], colors.available)
                                 }
                              )
                           end
                        end
                     end
                  end
               else
                  -- normal people difficulties
                  for boss = 1, #raidInfo.bosses do
                     table.insert(
                        sideTooltipTable.body,
                        {
                           raidInfo.bosses[boss].name,
                           raidInfo.bosses[boss].killed and WrapTextInColorCode(L["Defeated"], colors.completed) or
                              WrapTextInColorCode(L["Available"], colors.available)
                        }
                     )
                  end
               end

               local statusbar = {curr = raidInfo.done, total = raidInfo.max, color = "9b016a"}
               info.data = raidInfo.done .. "/" .. raidInfo.max .. diffShortened[diffOrder[difIndex]]

               info.colOff = cellIndex - 2
               info.OnEnter = Exlist.CreateSideTooltip(statusbar)
               info.OnEnterData = sideTooltipTable
               info.dontResize = true
               info.OnLeave = Exlist.DisposeSideTooltip()
               infoTables[info.moduleName] = infoTables[info.moduleName] or {}
               table.insert(infoTables[info.moduleName], Exlist.copyTable(info))
               cellIndex = cellIndex + 1
            end
         end
      end
   end
   for raid, t in pairs(infoTables) do
      for i = 1, #t do
         if i >= #t then
            t[i].dontResize = false
         end
         Exlist.AddData(t[i])
      end
   end
end

local function init()
   defaultSettings = {
      -- Shadowlands
      [GetLFGDungeonInfo(2288) or "Sepulcher of the First Ones"] = {enabled = true, expansion = 9, order = 8},
      [GetLFGDungeonInfo(2226) or "Sanctum of Domination"] = {enabled = true, expansion = 9, order = 9},
      [GetLFGDungeonInfo(2093) or "Castle Nathria"] = {enabled = true, expansion = 9, order = 10},
      -- BFA
      [GetLFGDungeonInfo(2033) or "Ny'alotha, the Waking City"] = {enabled = false, expansion = 8, order = 5},
      [GetLFGDungeonInfo(2014) or "The Eternal Palace"] = {enabled = false, expansion = 8, order = 6},
      [GetLFGDungeonInfo(1951) or "Crucible of Storms"] = {enabled = false, expansion = 8, order = 7},
      [GetLFGDungeonInfo(1942) or "Battle of Dazar'alor"] = {enabled = false, expansion = 8, order = 8},
      [GetLFGDungeonInfo(1887) or "Uldir"] = {enabled = false, expansion = 8, order = 9},
      -- LEGION
      [GetLFGDungeonInfo(1640) or "Antorus, the Burning Throne"] = {enabled = false, expansion = 7, order = 1},
      [GetLFGDungeonInfo(1527) or "Tomb of Sargeras"] = {enabled = false, expansion = 7, order = 2},
      [GetLFGDungeonInfo(1353) or "The Nighthold"] = {enabled = false, expansion = 7, order = 3},
      [GetLFGDungeonInfo(1439) or "Trials of Valor"] = {enabled = false, expansion = 7, order = 4},
      [GetLFGDungeonInfo(1350) or "Emerald Nightmare"] = {enabled = false, expansion = 7, order = 5},
      -- WoD
      [GetLFGDungeonInfo(987) or "Hellfire Citadel"] = {enabled = false, expansion = 6, order = 1},
      [GetLFGDungeonInfo(898) or "Blackrock Foundry"] = {enabled = false, expansion = 6, order = 2},
      [GetLFGDungeonInfo(895) or "Highmaul"] = {enabled = false, expansion = 6, order = 3},
      -- MoP
      [GetLFGDungeonInfo(714) or "Siege of Orgrimmar"] = {enabled = false, expansion = 5, order = 1},
      [GetLFGDungeonInfo(633) or "Throne of Thunder"] = {enabled = false, expansion = 5, order = 2},
      [GetLFGDungeonInfo(834) or "Terrace of Endless Spring"] = {enabled = false, expansion = 5, order = 3},
      [GetLFGDungeonInfo(533) or "Heart of Fear"] = {enabled = false, expansion = 5, order = 4},
      [GetLFGDungeonInfo(531) or "Mogu'shan Vaults"] = {enabled = false, expansion = 5, order = 5},
      -- Cata
      [GetLFGDungeonInfo(447) or "Dragon Soul"] = {enabled = false, expansion = 4, order = 1},
      [GetLFGDungeonInfo(361) or "Firelands"] = {enabled = false, expansion = 4, order = 2},
      [GetLFGDungeonInfo(317) or "Throne of the Four Winds"] = {enabled = false, expansion = 4, order = 3},
      [GetLFGDungeonInfo(315) or "The Bastion of Twilight"] = {enabled = false, expansion = 4, order = 4},
      [GetLFGDungeonInfo(313) or "Blackwing Descent"] = {enabled = false, expansion = 4, order = 5},
      [GetLFGDungeonInfo(328) or "Baradin Hold"] = {enabled = false, expansion = 4, order = 6},
      -- Wotlk
      [GetLFGDungeonInfo(293) or "Ruby Sanctum"] = {enabled = false, expansion = 3, order = 1},
      [GetLFGDungeonInfo(279) or "Icecrown Citadel"] = {enabled = false, expansion = 3, order = 2},
      [GetLFGDungeonInfo(257) or "Onyxia's Lair"] = {enabled = false, expansion = 3, order = 3},
      [GetLFGDungeonInfo(248) or "Trial of the Crusader"] = {enabled = false, expansion = 3, order = 4},
      [GetLFGDungeonInfo(243) or "Ulduar"] = {enabled = false, expansion = 3, order = 5},
      [GetLFGDungeonInfo(237) or "The Eye of Eternity"] = {enabled = false, expansion = 3, order = 6},
      [GetLFGDungeonInfo(238) or "The Obsidian Sanctum"] = {enabled = false, expansion = 3, order = 7},
      [GetLFGDungeonInfo(227) or "Naxxramas"] = {enabled = false, expansion = 3, order = 8},
      [GetLFGDungeonInfo(239) or "Vault of Archavon"] = {enabled = false, expansion = 3, order = 9},
      -- TBC
      [GetLFGDungeonInfo(199) or "The Sunwell"] = {enabled = false, expansion = 2, order = 1},
      [GetLFGDungeonInfo(196) or "Black Temple"] = {enabled = false, expansion = 2, order = 2},
      [select(19, GetLFGDungeonInfo(195)) or "The Battle for Mount Hyjal"] = {enabled = false, expansion = 2, order = 3},
      [GetLFGDungeonInfo(193) or "Tempest Keep"] = {enabled = false, expansion = 2, order = 4},
      [GetLFGDungeonInfo(194) or "Serpentshrine Cavern"] = {enabled = false, expansion = 2, order = 5},
      [GetLFGDungeonInfo(176) or "Magtheridon's Lair"] = {enabled = false, expansion = 2, order = 6},
      [GetLFGDungeonInfo(177) or "Gruul's Lair"] = {enabled = false, expansion = 2, order = 7},
      [GetLFGDungeonInfo(175) or "Karazhan"] = {enabled = false, expansion = 2, order = 8},
      -- Vanilla
      [select(19, GetLFGDungeonInfo(161)) or "Temple of Ahn'Qiraj"] = {enabled = false, expansion = 1, order = 1},
      [select(19, GetLFGDungeonInfo(160)) or "Ruins of Ahn'Qiraj"] = {enabled = false, expansion = 1, order = 2},
      [GetLFGDungeonInfo(50) or "Blackwing Lair"] = {enabled = false, expansion = 1, order = 3},
      [GetLFGDungeonInfo(48) or "Molten Core"] = {enabled = false, expansion = 1, order = 4}
   }

   LFRencounters = {
      -- [dungeonID] = {name = "", totalEncounters = 2}
      -- Dragon Soul
      [GetLFGDungeonInfo(447) or "Dragon Soul"] = {
         [416] = {name = "The Siege of Wyrmrest Temple", totalEncounters = 4, order = 1, firstBoss = 1}, -- DS Wing 1
         [843] = {
            name = "The Siege of Wyrmrest Temple",
            totalEncounters = 4,
            order = 1,
            firstBoss = 1,
            dontCount = true,
            saveId = 416
         }, -- Alt Id for DS wing 1
         [417] = {name = "Fall of Deathwing", totalEncounters = 4, order = 2, firstBoss = 5},
         -- DS Wing 2
         [844] = {
            name = "Fall of Deathwing",
            totalEncounters = 4,
            order = 2,
            firstBoss = 5,
            dontCount = true,
            saveId = 417
         }
         -- Alt DS Wing 2
      },
      -- Mogu'shan Vaults
      [GetLFGDungeonInfo(531) or "Mogu'shan Vaults"] = {
         [527] = {name = "Guardians of Mogu'shan", totalEncounters = 3, order = 1},
         [830] = {name = "Guardians of Mogu'shan", totalEncounters = 3, order = 1, dontCount = true, saveId = 527},
         [528] = {name = "The Vault of Mysteries", totalEncounters = 3, order = 2, firstBoss = 4},
         [831] = {name = "The Vault of Mysteries", totalEncounters = 3, order = 2, dontCount = true, saveId = 528}
      },
      -- Heart of Fear
      [GetLFGDungeonInfo(533) or "Heart of Fear"] = {
         [529] = {name = "The Dread Approach", totalEncounters = 3, order = 1},
         [832] = {name = "The Dread Approach", totalEncounters = 3, order = 1, dontCount = true, saveId = 529},
         [530] = {name = "Nightmare of Shek'zeer", totalEncounters = 3, order = 2, firstBoss = 4},
         [833] = {name = "Nightmare of Shek'zeer", totalEncounters = 3, order = 2, dontCount = true, saveId = 530}
      },
      -- Terrace of Endless Spring
      [GetLFGDungeonInfo(834) or "Terrace of Endless Spring"] = {
         [526] = {name = "Terrace of Endless Spring", totalEncounters = 4, order = 1},
         [834] = {name = "Terrace of Endless Spring", totalEncounters = 4, order = 1, dontCount = true, saveId = 526}
      },
      -- Throne of Thunder
      [GetLFGDungeonInfo(633) or "Throne of Thunder"] = {
         [610] = {name = "Last Stand of the Zandalari", totalEncounters = 3, order = 1},
         [835] = {name = "Last Stand of the Zandalari", totalEncounters = 3, order = 1, dontCount = true, saveId = 610},
         [611] = {name = "Forgotten Depths", totalEncounters = 3, order = 2, firstBoss = 4},
         [836] = {name = "Forgotten Depths", totalEncounters = 3, order = 2, dontCount = true, saveId = 611},
         [612] = {name = "Halls of Flesh-Shaping", totalEncounters = 3, order = 3, firstBoss = 7},
         [837] = {name = "Halls of Flesh-Shaping", totalEncounters = 3, order = 3, dontCount = true, saveId = 612},
         [613] = {name = "Pinnacle of Storms", totalEncounters = 3, order = 4, firstBoss = 10},
         [838] = {name = "Pinnacle of Storms", totalEncounters = 3, order = 4, dontCount = true, saveId = 613}
      },
      -- Siege of Orgrimmar
      [GetLFGDungeonInfo(714) or "Siege of Orgrimmar"] = {
         [716] = {name = "Vale of Eternal Sorrows", totalEncounters = 4, order = 1},
         [839] = {name = "Vale of Eternal Sorrows", totalEncounters = 4, order = 1, dontCount = true, saveId = 716},
         [717] = {name = "Gates of Retribution", totalEncounters = 4, order = 2, firstBoss = 5},
         [840] = {name = "Gates of Retribution", totalEncounters = 4, order = 2, dontCount = true, saveId = 717},
         [718] = {name = "The Underhold", totalEncounters = 3, order = 3, firstBoss = 9},
         [841] = {name = "The Underhold", totalEncounters = 3, order = 3, dontCount = true, saveId = 718},
         [719] = {name = "Downfall", totalEncounters = 3, order = 4, firstBoss = 12},
         [842] = {name = "Downfall", totalEncounters = 3, order = 4, dontCount = true, saveId = 719}
      },
      -- Highmaul
      [GetLFGDungeonInfo(895) or "Highmaul"] = {
         [849] = {name = "Walled City", totalEncounters = 3, order = 1},
         [1363] = {name = "Walled City", totalEncounters = 3, order = 1, dontCount = true, saveId = 849},
         [850] = {name = "Arcane Sanctum", totalEncounters = 3, order = 2, firstBoss = 4},
         [1364] = {name = "Arcane Sanctum", totalEncounters = 3, order = 2, dontCount = true, saveId = 850},
         [851] = {name = "Imperator's Rise", totalEncounters = 1, order = 3, firstBoss = 7},
         [1365] = {name = "Imperator's Rise", totalEncounters = 1, order = 3, dontCount = true, saveId = 851}
      },
      -- Blackrock Foundry
      [GetLFGDungeonInfo(898) or "Blackrock Foundry"] = {
         [847] = {name = "Slagworks", totalEncounters = 3, order = 1, map = {1, 2, 7}},
         [1361] = {name = "Slagworks", totalEncounters = 3, order = 1, dontCount = true, saveId = 847},
         [846] = {name = "The Black Forge", totalEncounters = 3, order = 2, map = {3, 5, 8}},
         [1360] = {name = "The Black Forge", totalEncounters = 3, order = 2, dontCount = true, saveId = 846},
         [848] = {name = "Iron Assembly", totalEncounters = 3, order = 3, map = {4, 6, 9}},
         [1362] = {name = "Iron Assembly", totalEncounters = 3, order = 3, dontCount = true, saveId = 848},
         [823] = {name = "Blackhand's Crucible", totalEncounters = 1, order = 4, firstBoss = 10},
         [1359] = {name = "Blackhand's Crucible", totalEncounters = 1, order = 4, dontCount = true, saveId = 823}
      },
      -- Hellfire Citadel
      [GetLFGDungeonInfo(987) or "Hellfire Citadel"] = {
         [982] = {name = "Hellbreach", totalEncounters = 3, order = 1},
         [1366] = {name = "Hellbreach", totalEncounters = 3, order = 1, dontCount = true, saveId = 982},
         [983] = {name = "Halls of Blood", totalEncounters = 3, order = 2, firstBoss = 4},
         [1367] = {name = "Halls of Blood", totalEncounters = 3, order = 2, dontCount = true, saveId = 983},
         [984] = {name = "Bastion of Shadows", totalEncounters = 3, order = 3, map = {7, 8, 11}},
         [1368] = {name = "Bastion of Shadows", totalEncounters = 3, order = 3, dontCount = true, saveId = 984},
         [985] = {name = "Destructor's Rise", totalEncounters = 3, order = 4, map = {9, 10, 12}},
         [1369] = {name = "Destructor's Rise", totalEncounters = 3, order = 4, dontCount = true, saveId = 985},
         [986] = {name = "The Black Gate", totalEncounters = 1, order = 5, firstBoss = 13},
         [1370] = {name = "The Black Gate", totalEncounters = 1, order = 5, dontCount = true, saveId = 986}
      },
      -- Emerald Nightmare
      [GetLFGDungeonInfo(1350) or "Emerald Nightmare"] = {
         [1287] = {name = "Darkbough", totalEncounters = 3, order = 1},
         [1288] = {name = "Tormented Guardians", totalEncounters = 3, order = 2},
         [1289] = {name = "Rift of Aln", totalEncounters = 1, order = 3}
      },
      -- Trials of Valor
      [GetLFGDungeonInfo(1439) or "Trials of Valor"] = {
         [1411] = {name = "Trials of Valor", totalEncounters = 3, order = 1}
      },
      -- Nighthold
      [GetLFGDungeonInfo(1353) or "The Nighthold"] = {
         [1290] = {name = "Arcing Aqueducts", totalEncounters = 3, order = 1},
         [1291] = {name = "Royal Athenaeum", totalEncounters = 3, order = 2},
         [1292] = {name = "Nightspire", totalEncounters = 3, order = 3},
         [1293] = {name = "Betrayer's Rise", totalEncounters = 1, order = 4}
      },
      --Tomb of Sargeras
      [GetLFGDungeonInfo(1527) or "Tomb of Sargeras"] = {
         [1494] = {name = "The Gates of Hell", totalEncounters = 3, order = 1},
         [1495] = {name = "Wailing Halls", totalEncounters = 3, order = 2}, --?? inq +sist + deso
         [1496] = {name = "Chamber of the Avatar", totalEncounters = 2, order = 3}, --?? maid + ava
         [1497] = {name = "Deceiver’s Fall", totalEncounters = 1, order = 4} --?? KJ
      },
      -- Antorus
      [GetLFGDungeonInfo(1640) or "Antorus, the Burning Throne"] = {
         [1610] = {name = "Light's Breach", totalEncounters = 3, order = 1}, -- Light's Breach
         [1611] = {name = "Forbidden Descent", totalEncounters = 3, order = 2}, -- Forbidden Descent
         [1612] = {name = "Hope's End", totalEncounters = 3, order = 3}, -- Hope's End
         [1613] = {name = "Seat of the Pantheon", totalEncounters = 2, order = 4} -- Seat of the Pantheon
      },
      -- BFA
      -- Uldir
      [GetLFGDungeonInfo(1887) or "Uldir"] = {
         [1731] = {name = "Halls of Containment", totalEncounters = 3, order = 1},
         [1732] = {name = "Crimson Descent", totalEncounters = 3, order = 2},
         [1733] = {name = "Heart of Corruption", totalEncounters = 2, order = 3}
      },
      -- Battle of Dazar'alor
      [GetLFGDungeonInfo(1942) or "Battle of Dezar'alor"] = {
         [1945] = {name = "Siege of Dazar'alor", totalEncounters = 3, order = 1, horde = false},
         [1946] = {name = "Empire's Fall", totalEncounters = 3, order = 2, horde = false},
         [1947] = {name = "Might of the Alliance", totalEncounters = 3, order = 3, horde = false},
         [1948] = {name = "Defense of Dazar'alor", totalEncounters = 3, order = 1, horde = true},
         [1949] = {name = "Death's Bargain", totalEncounters = 3, order = 2, horde = true},
         [1950] = {name = "Victory or Death", totalEncounters = 3, order = 3, horde = true}
      },
      -- Crucible of Storms
      [GetLFGDungeonInfo(1951) or "Crucible of Storms"] = {
         [1951] = {name = "Crucible of Storms", totalEncounters = 2, order = 1}
      },
      [GetLFGDungeonInfo(2014) or "The Eternal Palace"] = {
         [2009] = {name = "The Grand Reception", totalEncounters = 3, order = 1},
         [2010] = {name = "Depths of the Devoted", totalEncounters = 3, order = 2},
         [2011] = {name = "The Circle of Stars", totalEncounters = 2, order = 3}
      },
      [GetLFGDungeonInfo(2033) or "Ny'alotha, the Waking City"] = {
         [2036] = {name = "Ny'alotha: Vision of Destiny", totalEncounters = 3, order = 1},
         [2037] = {name = "Ny'alotha: Halls of Devotion", totalEncounters = 4, order = 2},
         [2038] = {name = "Ny'alotha: Halls of Devotion", totalEncounters = 3, order = 3},
         [2039] = {name = "Ny'alotha: The Waking Dream", totalEncounters = 2, order = 4}
      },
      [GetLFGDungeonInfo(2093) or "Castle Nathria"] = {
         [2090] = {name = "The Leeching Vaults", totalEncounters = 3, order = 1},
         [2091] = {name = "Reliquary of Opulence", totalEncounters = 3, order = 2},
         [2092] = {name = "Blood from Stone", totalEncounters = 3, order = 3},
         [2093] = {name = "An Audience with Arrogance", totalEncounters = 1, order = 4}
      },
      [GetLFGDungeonInfo(2226) or "Sanctum of Domination"] = {
         [2221] = {name = "The Jailer's Vanguard", totalEncounters = 3, order = 1},
         [2222] = {name = "The Dark Bastille", totalEncounters = 3, order = 2},
         [2223] = {name = "Shackles of Fate", totalEncounters = 3, order = 3},
         [2224] = {name = "The Reckoning", totalEncounters = 1, order = 4}
      },
      [GetLFGDungeonInfo(2288) or "Sepulcher of the First Ones"] = {
         [2292] = {name = "Ephemeral Plains", totalEncounters = 4, order = 1},
         [2291] = {name = "Cornerstone of Creation", totalEncounters = 3, order = 2},
         [2293] = {name = "Domination's Grasp", totalEncounters = 3, order = 3},
         [2294] = {name = "The Grand Design", totalEncounters = 1, order = 4}
      }
   }

   -- Order and Affixes
   for _, id in ipairs(raidDifficultyIds) do
      local name = GetDifficultyInfo(id)
      table.insert(diffOrder, name)
      diffShortened[name] = diffShort[id]
   end
end

local data = {
   name = L["Raids"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {"UPDATE_INSTANCE_INFO", "PLAYER_ENTERING_WORLD", "ENCOUNTER_END"},
   description = L["Tracks lockouts for current expansion raids"],
   weeklyReset = true,
   init = init
}

Exlist.RegisterModule(data)
