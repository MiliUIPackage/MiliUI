local BtWQuests = BtWQuests
local Database = BtWQuests.Database
local EXPANSION_ID = BtWQuests.Constant.Expansions.Midnight
local Category = BtWQuests.Constant.Category.Midnight
local Chain = BtWQuests.Constant.Chain.Midnight
local ALLIANCE_RESTRICTIONS, HORDE_RESTRICTIONS = 924, 923
local LEVEL_RANGE = {80, 90}
local ACHIEVEMENT_ID = 42117

Chain.TheLightsSummons = 120002
Chain.TheDarkeningSky = 120003

Chain.Foothold = 120011
Chain.TheVoidspire = 120012
Chain.TheDarkwell = 120013
Chain.DawnOfANewWell = 120014

Database:AddChain(Chain.TheLightsSummons, {
    name = BtWQuests.L["THE_LIGHTS_SUMMONS"],
    questline = 5811,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
    },
    active = {
        type = "quest",
        id = 91281,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 86852,
    },
    items = {
        { -- Midnight
            type = "quest",
            id = 91281,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Voice from the Light
            type = "quest",
            id = 88719,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Last Bastion of the Light
            type = "quest",
            id = 86769,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Champions of Quel'Danas
            type = "quest",
            id = 86770,
            x = -2,
            connections = {
                3, 4, 
            },
        },
        { -- My Son
            type = "quest",
            id = 89271,
            connections = {
                2, 3, 
            },
        },
        { -- Where Heroes Hold
            type = "quest",
            id = 86780,
            connections = {
                1, 2, 
            },
        },
        { -- The Hour of Need
            type = "quest",
            id = 86805,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- A Safe Path
            type = "quest",
            id = 89012,
            connections = {
                1, 
            },
        },
        { -- Luminous Wings
            type = "quest",
            id = 86806,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Gate
            type = "quest",
            id = 86807,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Severing the Void
            type = "quest",
            id = 91274,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Voidborn Banishing
            type = "quest",
            id = 86834,
            connections = {
                1, 2, 
            },
        },
        { -- Ethereal Eradication
            type = "quest",
            id = 86811,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Light's Arsenal
            type = "quest",
            id = 86848,
            connections = {
                1, 
            },
        },
        { -- Wrath Unleashed
            type = "quest",
            id = 86849,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Broken Sun
            type = "quest",
            id = 86850,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Light's Last Stand
            type = "quest",
            id = 86852,
            x = 0,
        },
    },
})
Database:AddChain(Chain.TheDarkeningSky, {
    name = BtWQuests.L["THE_DARKENING_SKY"],
    questline = 5979,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            name = "1 Campaign Chapter",
            type = "chain",
            ids = {
                120204, 120303, 120502, 
            },
            count = 1,
        },
    },
    active = {
        type = "quest",
        id = 91854,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 91967,
    },
    items = {
        {
            type = "npc",
            id = 248631,
            x = 0,
            connections = {
                2, 
            },
        },
        {
            visible = false,
            x = -2,
        },
        { -- Deepening Shadows
            type = "quest",
            id = 91854,
            x = 0,
            connections = {
                2, 
            },
        },
        {
            name = "2 Campaign Chapters",
            type = "chain",
            ids = {
                120204, 120303, 120502, 
            },
            count = 2,
            connections = {
                1, 
            },
        },
        { -- You Know This Evil?
            type = "quest",
            id = 91967,
            x = 0,
        },
    }
})
Database:AddChain(Chain.Foothold, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID, 1),
    questline = 5792,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 90,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 91854,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 91967,
    },
    items = {
    }
})
Database:AddChain(Chain.TheVoidspire, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID, 2),
    questline = 5793,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 90,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.Foothold,
        },
    },
    active = {
        type = "quest",
        id = 91854,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 91967,
    },
    items = {
    }
})
Database:AddChain(Chain.TheDarkwell, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID, 3),
    questline = 5797,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 90,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.Foothold,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.TheVoidspire,
        },
    },
    active = {
        type = "quest",
        id = 91854,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 91967,
    },
    items = {
    }
})
Database:AddChain(Chain.DawnOfANewWell, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID, 4),
    questline = 5798,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 90,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.Foothold,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.TheVoidspire,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.TheDarkwell,
        },
    },
    active = {
        type = "quest",
        id = 91854,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 91967,
    },
    items = {
    }
})
BtWQuestsDatabase:AddExpansionItems(EXPANSION_ID, {
    {
        type = "chain",
        id = Chain.TheLightsSummons,
    },
    {
        type = "chain",
        id = Chain.TheDarkeningSky,
    },

    -- {
    --     type = "chain",
    --     id = Chain.Foothold,
    -- },
    -- {
    --     type = "chain",
    --     id = Chain.TheVoidspire,
    -- },
    -- {
    --     type = "chain",
    --     id = Chain.TheDarkwell,
    -- },
    -- {
    --     type = "chain",
    --     id = Chain.DawnOfANewWell,
    -- },
})
