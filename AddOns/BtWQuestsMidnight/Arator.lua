local BtWQuests = BtWQuests
local Database = BtWQuests.Database
local EXPANSION_ID = BtWQuests.Constant.Expansions.Midnight
local CATEGORY_ID = BtWQuests.Constant.Category.Midnight.Arator
local Chain = BtWQuests.Constant.Chain.Midnight.Arator
local ALLIANCE_RESTRICTIONS, HORDE_RESTRICTIONS = 724, 723
local MAP_ID = 2437
local CONTINENT_ID = 2537
local ACHIEVEMENT_ID_1 = 41805
local LEVEL_RANGE = {70, 80}
local LEVEL_PREREQUISITES = {
    {
        type = "level",
        level = 70,
    },
}

Chain.ThePathOfLight = 120501
Chain.RegretsOfThePast = 120502
Chain.OtherAlliance = 120597
Chain.OtherHorde = 120598
Chain.OtherBoth = 120599

Database:AddChain(Chain.ThePathOfLight, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 1),
    questline = 5750,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    major = true,
    prerequisites = {
        {
            type = "level",
            variations = {
                {
                    level = 80,
                    restrictions = -120001,
                },
                {
                    level = 81,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.EversongWoods.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.EversongWoods.Shadowfall,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.EversongWoods.RippleEffects,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 89193,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 89338,
    },
    items = {
        { -- Arator
            type = "quest",
            id = 89193,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Meet at the Sunwell
            type = "quest",
            id = 86837,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Renewal for the Weary
            type = "quest",
            id = 86838,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Relics of Light's Hope
            type = "quest",
            id = 86839,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Flickering Hope
            type = "quest",
            id = 86840,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Relics of Paladins Past
            type = "quest",
            id = 86841,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Scarlet Power
            type = "quest",
            id = 86842,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Light Miswielded
            type = "quest",
            id = 86843,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Light Repurposed
            type = "quest",
            id = 86844,
            connections = {
                1, 
            },
        },
        { -- Infusion of Hope
            type = "quest",
            id = 92136,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Relinquishing Relics
            type = "quest",
            id = 86902,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Sunwalker Path
            type = "quest",
            id = 86845,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- A Humble Servant
            type = "quest",
            id = 91000,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Resupplying Our Suppliers
            type = "quest",
            id = 86846,
            connections = {
                1, 
            },
        },
        { -- Gathering Plowshares
            type = "quest",
            id = 89338,
            x = 0,
        },
    }
})
Database:AddChain(Chain.RegretsOfThePast, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 2),
    questline = 5751,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    major = true,
    prerequisites = {
        {
            type = "level",
            variations = {
                {
                    level = 80,
                    restrictions = -120001,
                },
                {
                    level = 81,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.EversongWoods.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.EversongWoods.Shadowfall,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.EversongWoods.RippleEffects,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Arator.ThePathOfLight,
        },
    },
    active = {
        type = "quest",
        id = 86822,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86903,
    },
    items = {
        {
            type = "npc",
            id = 240747,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- One Final Relic
            type = "quest",
            id = 86822,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- The Dark Horde
            type = "quest",
            id = 86823,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- None Left Standing
            type = "quest",
            id = 86824,
            connections = {
                2, 
            },
        },
        { -- Faithful Servant, Faithless Cause
            type = "quest",
            id = 86825,
            connections = {
                1, 
            },
        },
        { -- Still Scouting
            type = "quest",
            id = 91391,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Due Recognition
            type = "quest",
            id = 86827,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Nagosh the Scarred
            type = "quest",
            id = 86826,
            connections = {
                2, 
            },
        },
        { -- Disarm the Dark Horde
            type = "quest",
            id = 91842,
            connections = {
                1, 
            },
        },
        { -- Not Just a Troll's Bane
            type = "quest",
            id = 86828,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Warriors Without a Warlord
            type = "quest",
            id = 86831,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- A True Horde of Dark Horde
            type = "quest",
            id = 86830,
            connections = {
                1, 
            },
        },
        { -- A Landmark Moment
            type = "quest",
            id = 86829,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Unstoppable Force
            type = "quest",
            id = 91726,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Worthy Forge
            type = "quest",
            id = 86832,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Bulwark Remade
            type = "quest",
            id = 86833,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Arcantina
            type = "quest",
            id = 86903,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Journey Ends
            type = "quest",
            id = 91787,
            aside = true,
            x = 0,
        },
    }
})
Database:AddChain(Chain.OtherAlliance, {
    name = "Other Alliance",
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    items = {
    },
})
Database:AddChain(Chain.OtherHorde, {
    name = "Other Horde",
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    items = {
    },
})
Database:AddChain(Chain.OtherBoth, {
    name = "Other Both",
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    items = {
    },
})

Database:AddCategory(CATEGORY_ID, {
    name = { -- Arator
        type = "quest",
        id = 89193,
    },
    expansion = EXPANSION_ID,
    items = {
        {
            type = "chain",
            id = Chain.ThePathOfLight,
        },
        {
            type = "chain",
            id = Chain.RegretsOfThePast,
        },
--[==[@debug@
        {
            type = "chain",
            id = Chain.OtherAlliance,
        },
        {
            type = "chain",
            id = Chain.OtherHorde,
        },
        {
            type = "chain",
            id = Chain.OtherBoth,
        },
--@end-debug@]==]
    },
})

Database:AddExpansionItem(EXPANSION_ID, {
    type = "category",
    id = CATEGORY_ID,
})

BtWQuestsDatabase:AddQuestItemsForChain(Chain.ThePathOfLight)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.RegretsOfThePast)
