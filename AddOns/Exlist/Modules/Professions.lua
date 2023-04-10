local key = "professions-df"
local prio = 50
local Exlist = Exlist
local L = Exlist.L
local colors = Exlist.Colors

local WEEKLY_TYPE = {
  QUEST = "quest",
  ITEM = "item"
}

local TYPE_ATLAS = {
  [WEEKLY_TYPE.QUEST] = "AutoQuest-Badge-Campaign:14:14:-2",
  [WEEKLY_TYPE.ITEM] = "Levelup-Icon-Bag:14:12"
}

-- Thanks to Tamas Df helper WA for most quests Ids https://wago.io/TamasDragonflightHelper
local professionWeeklies = {
  [171] = {
    -- Alchemy
    {
      questId = 66373,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 66374,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70511,
      name = L["Elementious Splinter"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70504,
      name = L["Decaying Phlegm"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      quests = {66940, 66938, 72427},
      name = L["Weekly Quest for Dhurrel"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      quests = {70531, 70530, 70533, 70532},
      name = L["Weekly Quest for Conflago"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 74108,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [164] = {
    -- Blacksmithing
    {
      questId = 66381,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 66382,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70513,
      name = L["Molten Globule"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70512,
      name = L["Primeval Earth Fragment"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      quests = {66897, 66517, 66941, 72398},
      name = L["Weekly Quest for Dhurrel"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 70589,
      name = L["Work Order Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      quests = {70211, 70235, 70233, 70234},
      name = L["Crafting Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 74109,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [333] = {
    -- Enchanting
    {
      quests = {72172, 72173, 72175, 72155},
      name = L["Crafting Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 66377,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 66378,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      quests = {66884, 66900, 66935, 72423},
      name = L["Weekly quest for Temnaayu or Gnoklin"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 70515,
      name = L["Primalist Charm"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70514,
      name = L["Primordial Aether"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 74110,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [202] = {
    -- Engineering
    {
      quests = {70557, 70545, 70539, 70540},
      name = L["Crafting Weekly"],
      points = 2,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 66379,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 66380,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70591,
      name = L["Work Order Weekly"],
      points = 2,
      type = WEEKLY_TYPE.QUEST
    },
    {
      quests = {72396, 66942, 66891, 66890},
      name = L["Weekly quest for Dothenos or Gnoklin"],
      points = 2,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 70517,
      name = L["Infinitely Attachable Pair o' Docks"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70516,
      name = L["Keeper's Mark"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 74111,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [773] = {
    -- Inscription
    {
      quests = {70558, 70559, 70560, 70561},
      name = L["Crafting Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 66375,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 66376,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70592,
      name = L["Work Order Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      quests = {66884, 66900, 66935, 72423},
      name = L["Weekly quest for Temnaayu or Gnoklin"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 70519,
      name = L["Draconic Glamour"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70518,
      name = L["Curious Djaradin Rune"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 74105,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [755] = {
    -- Jewelcrafting
    {
      quests = {70562, 70563, 70564, 70565},
      name = L["Crafting Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 66389,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 66388,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70593,
      name = L["Work Order Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      quests = {66950, 72428, 66949, 66516},
      name = L["Weekly quest for Temnaayu or Gnoklin"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 70520,
      name = L["Incandescent Curio"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70521,
      name = L["Elegantly Engraved.."],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 74112,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [165] = {
    -- Letherworking
    {
      quests = {70567, 70568, 70569, 70571},
      name = L["Crafting Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 66385,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 66384,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70594,
      name = L["Work Order Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      quests = {66363, 72407, 66951, 66364},
      name = L["Weekly quest for Temnaayu or Dhurrel"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 70523,
      name = L["Exceedingly Soft Skin"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70522,
      name = L["Ossified Hide"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 74113,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [197] = {
    -- Tailoring
    {
      quests = {70587, 70582, 70572, 70586},
      name = L["Crafting Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 66386,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 66387,
      name = L["Dirt Pile / Expedition Pack"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70595,
      name = L["Work Order Weekly"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      quests = {66953, 72410, 66899, 66952},
      name = L["Weekly quest for Temnaayu or Gnoklin"],
      points = 3,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 70525,
      name = L["Stupidly Effective Stitchery"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70524,
      name = L["Ohn'arhan Weave"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 74115,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [182] = {
    -- Herbalism
    {
      questId = 71857,
      name = L["Dreambloom"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 71858,
      name = L["Dreambloom"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 71859,
      name = L["Dreambloom"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 71860,
      name = L["Dreambloom"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 71861,
      name = L["Dreambloom"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 71864,
      name = L["Dreambloom"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 74107,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [186] = {
    -- Mining
    {
      questId = 72160,
      name = L["Iridescent Ore"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 72161,
      name = L["Iridescent Ore"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 72162,
      name = L["Iridescent Ore"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 72163,
      name = L["Iridescent Ore"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 72164,
      name = L["Iridescent Ore"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 72165,
      name = L["Iridescent Ore"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 74106,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  },
  [393] = {
    -- Skinning
    {
      quests = {70620, 72158, 72159, 70619},
      name = L["Handin Resources Weekly"],
      points = 1,
      type = WEEKLY_TYPE.QUEST
    },
    {
      questId = 70381,
      name = L["Curious Hide"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70383,
      name = L["Curious Hide"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70384,
      name = L["Curious Hide"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70385,
      name = L["Curious Hide"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70386,
      name = L["Curious Hide"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 70389,
      name = L["Curious Hide"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    },
    {
      questId = 74114,
      name = L["Draconic Treatise"],
      points = 1,
      type = WEEKLY_TYPE.ITEM
    }
  }
}

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
  for _, id in ipairs({prof1, prof2}) do
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

  info.data = string.format(L["%i/%i (KP)"], profKPCurr, profKPMax)
  if (profKPCurr / profKPMax == 1) then
    info.data = Exlist.AddCheckmark(info.data, true)
  elseif (profKPCurr / profKPMax > 0.3) then
    info.data = WrapTextInColorCode(info.data, colors.incomplete)
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
