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
Chain.GatheringOfTheElves = 120013
Chain.TheBattleOfTheBridge = 120014
Chain.MarchOnQuelDanas = 120015
Chain.DawnOfANewWell = 120016

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
        id = 90777,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 88706,
    },
    items = {
        {
            type = "npc",
            id = 235787,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Feeding the Flame
            type = "quest",
            id = 90777,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Devouring Citadel
            type = "quest",
            id = 88696,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Clarity of Purpose
            type = "quest",
            id = 88697,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Master of Mayhem
            type = "quest",
            id = 88698,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Powerless
            type = "quest",
            id = 88699,
            connections = {
                1, 
            },
        },
        { -- Two Tons of Metal and Holy Fire
            type = "quest",
            id = 88700,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Seek out Arator
            type = "quest",
            id = 91417,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Memory Remains
            type = "quest",
            id = 88701,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Aegis of the Redeemer
            type = "quest",
            id = 88702,
            connections = {
                1, 
            },
        },
        { -- The People's Champion
            type = "quest",
            id = 91426,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Night Before
            type = "quest",
            id = 88703,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Patient Hunter
            type = "quest",
            id = 88704,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Killing Blow
            type = "quest",
            id = 88705,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Nothing Stands Forever
            type = "quest",
            id = 88706,
            x = 0,
        },
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
        ids = { 90690, 88709, },
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
            id = 92520,
    },
    items = {
        {
            variations = {
                { -- Charge of the Vanguard
                    type = "quest",
                    id = 90690,
                    restrictions = { -- Charge of the Vanguard
                        type = "quest",
                        id = 90690,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 239810,
                    locations = {
                        [2405] = {
                            {
                                x = 0.451887,
                                y = 0.628775,
                            },
                        },
                    },
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Voidspire
            type = "quest",
            id = 88709,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Broken Sky
            type = "quest",
            id = 90724,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Wake of the Darkwell
            type = "quest",
            id = 92520,
            x = 0,
        },
    }
})
Database:AddChain(Chain.GatheringOfTheElves, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID, 3),
    questline = 5795,
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
        id = 88920,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 88942,
    },
    items = {
        {
            type = "npc",
            id = 240267,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Kaldorei
            type = "quest",
            id = 88920,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Children of the Stars
            type = "quest",
            id = 88923,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Awaken the Ancient of War
            type = "quest",
            id = 88925,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Awaken the Ancient of Lore
            type = "quest",
            id = 88937,
            connections = {
                2, 
            },
        },
        { -- Awaken the Ancient Protector
            type = "quest",
            id = 88927,
            connections = {
                1, 
            },
        },
        { -- The Quel'dorei
            type = "quest",
            id = 88922,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Symbols of the Past
            type = "quest",
            id = 88938,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Rest for the Restless
            type = "quest",
            id = 88939,
            connections = {
                1, 
            },
        },
        { -- For Quel'Thalas
            type = "quest",
            id = 88941,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Shal'dorei
            type = "quest",
            id = 88928,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Drained Mana
            type = "quest",
            id = 88930,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- An Illusion!
            type = "quest",
            id = 88929,
            connections = {
                1, 
            },
        },
        { -- Into the Darkway
            type = "quest",
            id = 88919,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Elves are Going to War
            type = "quest",
            id = 88942,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheBattleOfTheBridge, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID, 4),
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
            id = Chain.GatheringOfTheElves,
        },
    },
    active = {
        type = "quest",
        id = 88769,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 88769,
    },
    items = {
        {
            type = "npc",
            id = 240267,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Battle of the Bridge
            type = "quest",
            id = 88769,
            x = 0,
        },
    }
})
Database:AddChain(Chain.MarchOnQuelDanas, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID, 5),
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
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.GatheringOfTheElves,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.TheBattleOfTheBridge,
        },
    },
    active = {
        type = "quest",
        ids = { 90748, 88710, },
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 88710,
    },
    items = {
        {
            variations = {
                { -- Quel'Danas
                    type = "quest",
                    id = 90748,
                    restrictions = { -- Quel'Danas
                        type = "quest",
                        id = 90748,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 245061,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- March on Quel'Danas
            type = "quest",
            id = 88710,
            x = 0,
        },
    }
})
Database:AddChain(Chain.DawnOfANewWell, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID, 6),
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
            id = Chain.GatheringOfTheElves,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.TheBattleOfTheBridge,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.MarchOnQuelDanas,
        },
    },
    active = {
        type = "quest",
        id = 92689,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 90867,
    },
    items = {
        {
            type = "npc",
            id = 235787,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Path Forward
            type = "quest",
            id = 92689,
            completed = { -- A Path Forward
                type = "quest",
                id = 92689,
                status = { "active", "completed", },
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Reluctant Hand
            type = "quest",
            id = 90876,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- The Silversun Compact
            type = "quest",
            id = 90871,
            connections = {
                1, 
            },
        },
        { -- A Path Forward
            type = "quest",
            id = 92689,
            active = {
                type = "quest",
                ids = {
                    90876, 90871, 
                },
                count = 2,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Those Left Behind
            type = "quest",
            id = 90861,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- In Times of Need
            type = "quest",
            id = 90862,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- From Darkness, Light
            type = "quest",
            id = 90867,
            x = 0,
        },
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

    {
        type = "chain",
        id = Chain.Foothold,
    },
    {
        type = "chain",
        id = Chain.TheVoidspire,
    },
    {
        type = "chain",
        id = Chain.GatheringOfTheElves,
    },
    {
        type = "chain",
        id = Chain.TheBattleOfTheBridge,
    },
    {
        type = "chain",
        id = Chain.MarchOnQuelDanas,
    },
    {
        type = "chain",
        id = Chain.DawnOfANewWell,
    },
})
