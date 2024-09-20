local key = "professions-df"
local prio = 50
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors

local WEEKLY_TYPE = {
   QUEST = "quest",
   ITEM = "item",
   DARKMOON = 'darkmoon'
}

local TYPE_ATLAS = {
   [WEEKLY_TYPE.QUEST] = "questlog-questtypeicon-Recurringturnin:14:14",
   [WEEKLY_TYPE.ITEM] = "Levelup-Icon-Bag:14:12",
   [WEEKLY_TYPE.DARKMOON] = "questlog-questtypeicon-clockyellow:14:14"
}

local professionWeeklies = {
   [171] = {
      -- Alchemy
      {
         questId = 29506,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 83253,
         name = L["Alchemical Sediment (Treasure)"],
         points = 2,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83255,
         name = L["Deepstone Crucible (Treasure)"],
         points = 2,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 84133 },
         name = L["Work Order Weekly"],
         points = 2,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83725,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [164] = {
      -- Blacksmithing
      {
         questId = 29508,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 83257,
         name = L["Coreway Billet (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83256,
         name = L["Dense Bladestone (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 84127 },
         name = L["Work Order Weekly"],
         points = 2,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83726,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [333] = {
      -- Enchanting
      {
         questId = 29510,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 83259,
         name = L["Crystalline Repository (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83258,
         name = L["Powdered Fulgurance (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 84290,
         name = L["Fleeting Arcane Manifestation 1 (Disenchanting)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 84291,
         name = L["Fleeting Arcane Manifestation 2 (Disenchanting)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 84292,
         name = L["Fleeting Arcane Manifestation 3 (Disenchanting)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 84293,
         name = L["Fleeting Arcane Manifestation 4 (Disenchanting)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 84294,
         name = L["Fleeting Arcane Manifestation 5 (Disenchanting)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 84295,
         name = L["Gleaming Telluric Crystal (Disenchanting)"],
         points = 4,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 84085, 84086, 84084 },
         name = L["Trainer Weekly"],
         points = 3,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83727,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [202] = {
      -- Engineering
      {
         questId = 29511,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 83261,
         name = L["Earthen Induction Coil (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83260,
         name = L["Rust-Locked Mechanism (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 84128 },
         name = L["Work Order Weekly"],
         points = 2,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83728,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [773] = {
      -- Inscription
      {
         questId = 29515,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 83264,
         name = L["Striated Inkstone (Treasure)"],
         points = 2,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83262,
         name = L["Wax-Sealed Records (Treasure)"],
         points = 2,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 84129 },
         name = L["Work Order Weekly"],
         points = 2,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83730,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [755] = {
      -- Jewelcrafting
      {
         questId = 29516,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 83266,
         name = L["Deepstone Fragment (Treasure)"],
         points = 2,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83265,
         name = L["Diaphanous Gem Shards (Treasure)"],
         points = 2,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 84130 },
         name = L["Work Order Weekly"],
         points = 2,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83731,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [165] = {
      -- Letherworking
      {
         questId = 29517,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 83268,
         name = L["Stone-Leather Swatch (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83267,
         name = L["Sturdy Nerubian Carapace (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 84131 },
         name = L["Work Order Weekly"],
         points = 2,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83732,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [197] = {
      -- Tailoring
      {
         questId = 29520,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 83270,
         name = L["Chitin Needle (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83269,
         name = L["Spool of Webweave (Treasure)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 84132 },
         name = L["Work Order Weekly"],
         points = 2,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83735,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [182] = {
      -- Herbalism
      {
         questId = 29514,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 81416,
         name = L["Deepgrove Petal 1 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81417,
         name = L["Deepgrove Petal 2 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81418,
         name = L["Deepgrove Petal 3 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81419,
         name = L["Deepgrove Petal 4 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81420,
         name = L["Deepgrove Petal 5 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81421,
         name = L["Deepgrove Rose (Gathering)"],
         points = 4,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 82970, 82958, 82965, 82916, 82962 },
         name = L["Trainer Weekly"],
         points = 3,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83729,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [186] = {
      -- Mining
      {
         questId = 29518,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 83050,
         name = L["Slab of Slate 1 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83051,
         name = L["Slab of Slate 2 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83052,
         name = L["Slab of Slate 3 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83053,
         name = L["Slab of Slate 4 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83054,
         name = L["Slab of Slate 5 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 83049,
         name = L["Erosion Polished Slate (Gathering)"],
         points = 3,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 83104, 83105, 83103, 83106, 83102 },
         name = L["Trainer Weekly"],
         points = 3,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83733,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   },
   [393] = {
      -- Skinning
      {
         questId = 29519,
         name = L["Darkmoon Faire"],
         points = 3,
         type = WEEKLY_TYPE.DARKMOON
      },
      {
         questId = 81459,
         name = L["Toughened Tempest Pelt 1 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81460,
         name = L["Toughened Tempest Pelt 2 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81461,
         name = L["Toughened Tempest Pelt 3 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81462,
         name = L["Toughened Tempest Pelt 4 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81463,
         name = L["Toughened Tempest Pelt 5 (Gathering)"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      },
      {
         questId = 81464,
         name = L["Abyssal Fur (Gathering)"],
         points = 2,
         type = WEEKLY_TYPE.ITEM
      },
      {
         quests = { 83097, 83098, 83100, 82992, 82993 },
         name = L["Trainer Weekly"],
         points = 3,
         type = WEEKLY_TYPE.QUEST
      },
      {
         questId = 83734,
         name = L["Algari Treatise"],
         points = 1,
         type = WEEKLY_TYPE.ITEM
      }
   }
}

local function isDFup()
   -- Temp Quick Fix
   return false
   -- local i = 1
   -- local date = C_DateAndTime.GetCurrentCalendarTime();
   -- repeat
   --    local holidayInfo = C_Calendar.GetHolidayInfo(0, date.monthDay, i)
   --    if (holidayInfo and holidayInfo.texture == 235448) then
   --       return true
   --    end
   -- until holidayInfo == nil

   -- return false
end

local function getProfessionData(profId)
   local profName, icon, currentSkill, maxSkill, _, _, skillId = GetProfessionInfo(profId)
   local data = {
      name = profName,
      icon = icon,
      skill = currentSkill,
      maxSkill = maxSkill,
      weeklies = {}
   }

   if (professionWeeklies[skillId]) then
      for _, weekly in ipairs(professionWeeklies[skillId]) do
         if (weekly.type ~= WEEKLY_TYPE.DARKMOON or isDFup()) then
            local completed = weekly.questId and C_QuestLog.IsQuestFlaggedCompleted(weekly.questId) or false
            if (weekly.quests) then
               for _, questId in ipairs(weekly.quests) do
                  if (C_QuestLog.IsQuestFlaggedCompleted(questId)) then
                     completed = true
                     break
                  end
               end
            end
            table.insert(
               data.weeklies,
               {
                  points = weekly.points,
                  name = weekly.name,
                  completed = completed,
                  type = weekly.type
               }
            )
         end
      end
   end

   return data
end

local function getWeeklyPoints(weeklies)
   local curr, max = 0, 0
   for _, weekly in pairs(weeklies) do
      max = max + weekly.points
      if (weekly.completed) then
         curr = curr + weekly.points
      end
   end

   return curr, max
end

local function getWeeklyTooltipData(profession, data)
   table.insert(
      data,
      {
         string.format("|T%s:25:25|t %s", profession.icon, profession.name)
      }
   )

   table.insert(
      data,
      {
         WrapTextInColorCode(L["Name"], colors.faded),
         WrapTextInColorCode(L["Amount"], colors.faded)
      }
   )

   table.sort(
      profession.weeklies,
      function(a, b)
         return a.points > b.points
      end
   )

   for _, weekly in ipairs(profession.weeklies) do
      local name = weekly.name
      if (weekly.type) then
         name = string.format("|A:%s|a%s", TYPE_ATLAS[weekly.type], name)
      end
      table.insert(
         data,
         {
            Exlist.AddCheckmark(name, weekly.completed),
            weekly.points
         }
      )
   end

   return data
end

local function Updater(event)
   if (event == "CURRENCY_DISPLAY_UPDATE") then
      C_Timer.After(
         0.5,
         function()
            Exlist.SendFakeEvent("REFRESH_PROFESSION")
         end
      )
   end
   local t = {}
   local prof1, prof2 = GetProfessions()
   for _, id in ipairs({ prof1, prof2 }) do
      table.insert(t, getProfessionData(id))
   end

   Exlist.UpdateChar(key, t)
end

local function Linegenerator(tooltip, data, character)
   if (not data) then
      return
   end
   local info = {
      character = character,
      priority = prio,
      moduleName = key,
      titleName = L["Professions"]
   }

   local tooltipData = {
      title = WrapTextInColorCode(L["Available Knowledge Point Weeklies"], colors.sideTooltipTitle),
      body = {}
   }

   local profKPCurr, profKPMax = 0, 0

   for _, prof in ipairs(data) do
      local curr, max = getWeeklyPoints(prof.weeklies or {})
      profKPCurr = profKPCurr + curr
      profKPMax = profKPMax + max
      tooltipData.body = getWeeklyTooltipData(prof, tooltipData.body)
   end

   if (profKPMax > 0) then
      info.data = string.format(L["%i/%i (KP)"], profKPCurr, profKPMax)
      if (profKPCurr / profKPMax == 1) then
         info.data = Exlist.AddCheckmark(info.data, true)
      elseif (profKPCurr / profKPMax > 0.3 or profKPCurr == 0) then
         info.data = WrapTextInColorCode(info.data, colors.incomplete)
      end
   end

   info.OnEnter = Exlist.CreateSideTooltip()
   info.OnEnterData = tooltipData
   info.OnLeave = Exlist.DisposeSideTooltip()
   Exlist.AddData(info)
end

local data = {
   name = L["Professions"],
   key = key,
   linegenerator = Linegenerator,
   priority = prio,
   updater = Updater,
   event = {
      "QUEST_TURNED_IN",
      "PLAYER_ENTERING_WORLD",
      "QUEST_REMOVED",
      "PLAYER_ENTERING_WORLD_DELAYED",
      "CURRENCY_DISPLAY_UPDATE",
      "REFRESH_PROFESSION"
   },
   weeklyReset = true,
   dailyReset = false,
   description = L["Tracks professions KPs"]
}

Exlist.RegisterModule(data)
