local BtWQuests = BtWQuests
local Database = BtWQuests.Database
local EXPANSION_ID = BtWQuests.Constant.Expansions.Midnight
local CATEGORY_ID = BtWQuests.Constant.Category.Midnight.EversongWoods
local Chain = BtWQuests.Constant.Chain.Midnight.EversongWoods
local THREADS_OF_FATE_RESTRICTION = BtWQuests.Constant.Restrictions.MidnightToF
local NOT_THREADS_OF_FATE_RESTRICTION = BtWQuests.Constant.Restrictions.NotMidnightToF
local ALLIANCE_RESTRICTIONS, HORDE_RESTRICTIONS = 724, 723
local MAP_ID = 2395
local CONTINENT_ID = 2537
local ACHIEVEMENT_ID_1 = 41802
local ACHIEVEMENT_ID_2 = 61957
local LEVEL_RANGE = {80, 90}
local LEVEL_PREREQUISITES = {
    {
        type = "level",
        level = 80,
    },
}

Chain.WhispersInTheTwilight = 120101
Chain.Shadowfall = 120102
Chain.RippleEffects = 120103
Chain.FearAndFel = 120111
Chain.FlowersForAmalthea = 120112
Chain.SunbathTakeMeAway = 120113
Chain.PortDetective = 120114
Chain.LesserEvil = 120115
Chain.OneAdventurousHatchling = 120116
Chain.FarStriding = 120117
Chain.TailorTroubles = 120118
Chain.BlindingSun = 120119
Chain.RunestoneRumbles = 120120
Chain.PaladinRescue = 120121
Chain.HowToTrainYourProtege = 120122
Chain.ScootinThroughSilvermoon = 120123
Chain.AspiringAcademic = 120124
Chain.TheDrinkingDebt = 120125
Chain.TheftTracking = 120126
Chain.DaggerspineLanding = 120127
Chain.OtherAlliance = 120197
Chain.OtherHorde = 120198
Chain.OtherBoth = 120199

Database:AddChain(Chain.WhispersInTheTwilight, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 1),
    questline = 5719,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    major = true,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
        },
    },
    active = {
        {
            type = "quest",
            id = 86733,
            status = { "active", "completed" },
            restrictions = {
                type = "quest",
                id = 94993,
                status = { "pending" }
            },
        },
        {
            type = "quest",
            ids = { 86738, 86739, 86740, 94871, },
            status = { "active", "completed" },
            count = 1,
        },
    },
    completed = {
        type = "quest",
        id = 86745,
    },
    items = {
        {
            type = "npc",
            id = 236779,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Silvermoon Negotiations
            type = "quest",
            id = 86733,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Diplomacy
            type = "quest",
            id = 86734,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            variations = {
                { -- Paved in Ash
                    type = "quest",
                    id = 86735,
                    restrictions = 924,
                },
                { -- Paved in Ash
                    type = "quest",
                    id = 86736,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Fair Breeze, Light Bloom
            type = "quest",
            id = 86737,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Sharpmaw
            type = "quest",
            id = 86738,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Fairbreeze Favors
            type = "quest",
            id = 86739,
            connections = {
                2, 
            },
        },
        { -- Displaced Denizens
            type = "quest",
            id = 86740,
            connections = {
                1, 
            },
        },
        { -- Lightbloom Looming
            type = "quest",
            id = 86741,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Curious Cultivation
            type = "quest",
            id = 86742,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Trimming the Lightbloom
            type = "quest",
            id = 86743,
            connections = {
                1, 
            },
        },
        { -- Seeking Truth
            type = "quest",
            id = 86744,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Silvermoon Must Know
            type = "quest",
            id = 86745,
            x = 0,
        },
    },
})
Database:AddChain(Chain.Shadowfall, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 2),
    questline = 5720,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    major = true,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
        },
    },
    active = {
        type = "quest",
        id = 86621,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86636,
    },
    items = {
        {
            type = "npc",
            id = 236716,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Wayward Magister
            type = "quest",
            id = 86621,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Appeal to the Void
            type = "quest",
            id = 86623,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Rational Explanation
            type = "quest",
            id = 86624,
            connections = {
                1, 
            },
        },
        { -- The First to Know
            type = "quest",
            id = 90907,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Chance Meeting
            type = "quest",
            id = 86622,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Ransacked Lab
            type = "quest",
            id = 86626,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- The Battle for Tranquillien
            type = "quest",
            id = 86632,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- The Heart of Tranquillien
            type = "quest",
            id = 90493,
            connections = {
                2, 
            },
        },
        { -- The Traitors of Tranquillien
            type = "quest",
            id = 90509,
            connections = {
                1, 
            },
        },
        { -- The Missing Magister
            type = "quest",
            id = 90494,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Face the Past
            type = "quest",
            id = 86781,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Past Keeps Watch
            type = "quest",
            id = 86634,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Comprehend the Void
            type = "quest",
            id = 86633,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- To Deatholme
            type = "quest",
            id = 86635,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Void Walk With Me
            type = "quest",
            id = 86636,
            x = 0,
        },
    }
})
Database:AddChain(Chain.RippleEffects, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 3),
    questline = 5721,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    major = true,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.Shadowfall,
        },
    },
    active = {
        type = "quest",
        id = 86637,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86650,
    },
    items = {
        {
            type = "npc",
            id = 242433,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Anything but Reprieve
            type = "quest",
            id = 86637,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Choking Tendrils
            type = "quest",
            id = 86638,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- What's Left
            type = "quest",
            id = 86639,
            connections = {
                1, 
            },
        },
        { -- Premonition
            type = "quest",
            id = 86640,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Old Scars
            type = "quest",
            id = 86641,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- A Foe Unseen
            type = "quest",
            id = 86642,
            connections = {
                1, 
            },
        },
        { -- Following the Root
            type = "quest",
            id = 86643,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Gods Before Us
            type = "quest",
            id = 86644,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- An Impasse
            type = "quest",
            id = 86646,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Beat of Blood
            type = "quest",
            id = 86647,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Light Guide Us
            type = "quest",
            id = 86648,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Past Redemption
            type = "quest",
            id = 86649,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Fractured
            type = "quest",
            id = 86650,
            x = 0,
        },
    }
})
Database:AddChain(Chain.FearAndFel, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 1),
    questline = 5931,
    category = CATEGORY_ID,
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
        id = 90835,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90821,
    },
    items = {
        {
            type = "npc",
            id = 244493,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Murder Row: Rumors Abound
            type = "quest",
            id = 90835,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Murder Row: Loose Lips
            type = "quest",
            id = 90818,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Murder Row: Traces of Fel
            type = "quest",
            id = 90837,
            connections = {
                1, 
            },
        },
        { -- Murder Row: Acting the Part
            type = "quest",
            id = 90819,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Murder Row: Harbored Secrets
            type = "quest",
            id = 90821,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Murder Row: One Fel Swoop
            type = "quest",
            id = 90822,
            aside = true,
            x = 0,
        },
    }
})
Database:AddChain(Chain.FlowersForAmalthea, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 2),
    questline = 6020,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.Shadowfall,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            completed = { -- Face the Past
                type = "quest",
                id = 86781,
                status = { "active", "completed", },
            },
            upto = 86781,
        },
    },
    active = {
        type = "quest",
        ids = {
            92021, 92022, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92025,
    },
    items = {
        {
            type = "npc",
            id = 249337,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Graveblossom Gardening
            type = "quest",
            id = 92021,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- A Venomous Vocation
            type = "quest",
            id = 92022,
            connections = {
                1, 
            },
        },
        { -- Suspicious Sundries
            type = "quest",
            id = 92023,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- House Call
            type = "quest",
            id = 92024,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Flowers for Amalthea
            type = "quest",
            id = 92025,
            x = 0,
        },
    }
})
Database:AddChain(Chain.SunbathTakeMeAway, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 3),
    questline = 5949,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        }, -- Might be missing something, I may have missed it when copying stuff from addon because smort
    },
    active = {
        type = "quest",
        id = 91271,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91137,
    },
    items = {
        {
            type = "npc",
            id = 245745,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Fish!
            type = "quest",
            id = 91271,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Pesky Pests
            type = "quest",
            id = 91090,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Secret Ingredients
            type = "quest",
            id = 91328,
            connections = {
                1, 
            },
        },
        { -- Lost in Light
            type = "quest",
            id = 91137,
            x = 0,
        },
    }
})
Database:AddChain(Chain.PortDetective, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 4),
    questline = 5805,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86735,
            completed = {
                type = "quest",
                ids = { 86735, 86736, }
            }
        },
    },
    active = {
        type = "quest",
        id = 87392,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 87398,
    },
    items = {
        {
            type = "npc",
            id = 238490,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Cargo Conspiracy
            type = "quest",
            id = 87392,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Supplier Surveillance
            type = "quest",
            id = 87394,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Warranted Search
            type = "quest",
            id = 87393,
            connections = {
                1, 
            },
        },
        { -- Below the Brine
            type = "quest",
            id = 87395,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Dead to Rights
            type = "quest",
            id = 87396,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Cargo Collateral
            type = "quest",
            id = 87397,
            connections = {
                1, 
            },
        },
        { -- Smuggler Showdown
            type = "quest",
            id = 87398,
            x = 0,
        },
    }
})
Database:AddChain(Chain.LesserEvil, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 5),
    questline = 5812,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86735,
            completed = {
                type = "quest",
                ids = { 86735, 86736, }
            }
        },
    },
    active = {
        type = "quest",
        id = 90669,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 89208,
    },
    items = {
        {
            type = "npc",
            id = 243290,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Gold is Gold
            type = "quest",
            id = 90669,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Small Task
            type = "quest",
            id = 89199,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Unraveling Wards
            type = "quest",
            id = 89200,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Outschemed
            type = "quest",
            id = 89201,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Stir the Nest
            type = "quest",
            id = 89202,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Mutual Benefit
            type = "quest",
            id = 89203,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Five Finger Discount
            type = "quest",
            id = 89204,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Cutting a Key
            type = "quest",
            id = 89205,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Break and Enter
            type = "quest",
            id = 89206,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Rats Can Bite
            type = "quest",
            id = 89207,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- What We're Owed
            type = "quest",
            id = 89208,
            x = 0,
        },
    }
})
Database:AddChain(Chain.OneAdventurousHatchling, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 6),
    questline = 5898,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.Shadowfall,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.RippleEffects,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            89383, 89384, 89386, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 89385,
    },
    items = {
        {
            type = "npc",
            id = 241553,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- One Adventurous Hatchling
            type = "quest",
            id = 89383,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- A Roost-ed Development
            type = "quest",
            id = 89386,
            connections = {
                2, 
            },
        },
        { -- A Hungry Flock
            type = "quest",
            id = 89384,
            connections = {
                1, 
            },
        },
        { -- First Step Into Parenthood
            type = "quest",
            id = 89385,
            x = 0,
        },
    }
})
Database:AddChain(Chain.FarStriding, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 7),
    questline = 5969,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.Shadowfall,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86735,
            completed = {
                type = "quest",
                ids = { 86735, 86736, }
            }
        },
    },
    active = {
        type = "quest",
        ids = {
            91342, 91452, 94371, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91385,
    },
    items = {
        {
            variations = {
                { -- A Ranger's Dream
                    type = "quest",
                    id = 94371,
                    restrictions = { -- A Ranger's Dream
                        type = "quest",
                        id = 94371,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 246806,
                },
            },
            x = 0,
            connections = {
                1, 2
            },
        },
        { -- If You Want It Done Right
            type = "quest",
            id = 91342,
            x = -1,
            connections = {
                2, 3
            },
        },
        { -- Range of Knowledge
            type = "quest",
            id = 91452,
            aside = true,
        },
        { -- To the North Tower
            type = "quest",
            id = 91345,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- To the Central Tower
            type = "quest",
            id = 91462,
            connections = {
                2, 
            },
        },
        { -- Strider Stampede
            type = "quest",
            id = 91347,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- See a Mana 'bout a Wyrm
            type = "quest",
            id = 91348,
            connections = {
                1, 
            },
        },
        { -- To the South Tower
            type = "quest",
            id = 91463,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Dark Part of the Woods
            type = "quest",
            id = 91349,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Real Assignment
            type = "quest",
            id = 91350,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Tidy Up
            type = "quest",
            id = 91383,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Recovery Mission
            type = "quest",
            id = 91384,
            connections = {
                1, 
            },
        },
        { -- A Ranger's Spirit
            type = "quest",
            id = 91385,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TailorTroubles, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 8),
    questline = 5989,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86735,
            completed = {
                type = "quest",
                ids = { 86735, 86736, }
            }
        },
    },
    active = {
        type = "quest",
        id = 91386,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91389,
    },
    items = {
        {
            type = "npc",
            id = 247645,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Mad to Measure
            type = "quest",
            id = 91386,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Material Gains
            type = "quest",
            id = 92408,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Uncommon Threads
            type = "quest",
            id = 91388,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Clothes Make the Man
            type = "quest",
            id = 91389,
            x = 0,
        },
    }
})
Database:AddChain(Chain.BlindingSun, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 9),
    questline = 6018,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 87399,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 87402,
    },
    items = {
        {
            type = "npc",
            id = 238083,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Facing the Sun
            type = "quest",
            id = 87399,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Scattered in Sunbeams
            type = "quest",
            id = 87400,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Gardener Mishap
            type = "quest",
            id = 87401,
            connections = {
                1, 
            },
        },
        { -- The Light Provides
            type = "quest",
            id = 87402,
            x = 0,
        },
    }
})
Database:AddChain(Chain.RunestoneRumbles, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 10),
    questline = 5993,
    category = CATEGORY_ID,
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
        id = 92396,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92398,
    },
    items = {
        {
            type = "npc",
            id = 250791,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Calling in the Cavalry
            type = "quest",
            id = 92396,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Dawnstar Defense
            type = "quest",
            id = 92397,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- And Then They Came
            type = "quest",
            id = 92398,
            x = 0,
        },
    }
})
Database:AddChain(Chain.PaladinRescue, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 11),
    questline = 5908,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 90,
        },
    },
    active = {
        type = "quest",
        ids = {
            90546, 90547, 90548, 90549, 90550, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90556,
    },
    items = {
        {
            variations = {
                {
                    type = "npc",
                    id = 242803,
                    restrictions = 924,
                },
                {
                    type = "npc",
                    id = 242802,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        {
            variations = {
                { -- Missing Paladins
                    type = "quest",
                    id = 90546,
                    restrictions = 924,
                },
                { -- Missing Paladins
                    type = "quest",
                    id = 90547,
                },
            },
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Twilight Missive
            type = "quest",
            id = 90548,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Signs of the Struggle
            type = "quest",
            id = 90549,
            connections = {
                2, 
            },
        },
        { -- A Somber Sun
            type = "quest",
            id = 90550,
            connections = {
                1, 
            },
        },
        { -- Captured Information
            type = "quest",
            id = 90551,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Interrogation
            type = "quest",
            id = 90552,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- To the Ruins of Deatholme
            type = "quest",
            id = 90570,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Executing the Blades
            type = "quest",
            id = 90553,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Leave Ashes in Your Wake
            type = "quest",
            id = 90554,
            connections = {
                2, 
            },
        },
        { -- Blessing of Freedom
            type = "quest",
            id = 90555,
            connections = {
                1, 
            },
        },
        { -- Cutting off the Head
            type = "quest",
            id = 90556,
            x = 0,
        },
    }
})
Database:AddChain(Chain.HowToTrainYourProtege, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 12),
    questline = 5937,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86735,
            completed = {
                type = "quest",
                ids = { 86735, 86736, }
            }
        },
    },
    active = {
        type = "quest",
        ids = {
            91284, 94393, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91301,
    },
    items = {
        {
            variations = {
                { -- Career Counseling
                    type = "quest",
                    id = 94393,
                    restrictions = { -- Career Counseling
                        type = "quest",
                        id = 94393,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 245192,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Path Not Yet Chosen
            type = "quest",
            id = 91284,
            completed = { -- A Path Not Yet Chosen
                type = "quest",
                id = 91284,
                status = { "active", "completed", },
            },
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- A Test of the Hunt
            type = "quest",
            id = 91288,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- A Test of Blood
            type = "quest",
            id = 91291,
            connections = {
                2, 
            },
        },
        { -- A Test of the Arcane
            type = "quest",
            id = 91292,
            connections = {
                1, 
            },
        },
        { -- A Path Not Yet Chosen
            type = "quest",
            id = 91284,
            active = {
                type = "quest",
                ids = {
                    91288, 91291, 91292, 
                },
                count = 3,
            },
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- How to Train Your Protege
            type = "quest",
            id = 91301,
            x = 0,
        },
    }
})
Database:AddChain(Chain.ScootinThroughSilvermoon, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 13),
    questline = 6030,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86735,
            completed = {
                type = "quest",
                ids = { 86735, 86736, }
            }
        },
    },
    active = {
        type = "quest",
        id = 92729,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92870,
    },
    items = {
        {
            type = "npc",
            id = 252500,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Hounded and Hassled
            type = "quest",
            id = 92729,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Dogged Disturbances
            type = "quest",
            id = 92728,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- He Went Thataway
            type = "quest",
            id = 92868,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Fishy Dis-pondencies
            type = "quest",
            id = 92869,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Scoot Along Now
            type = "quest",
            id = 92870,
            x = 0,
        },
    }
})
Database:AddChain(Chain.AspiringAcademic, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 14),
    questline = 5781,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86735,
            completed = {
                type = "quest",
                ids = { 86735, 86736, }
            }
        },
    },
    active = {
        type = "quest",
        ids = {
            86997, 94396, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 87002,
    },
    items = {
        {
            variations = {
                { -- Down a Peg
                    type = "quest",
                    id = 94396,
                    restrictions = { -- Down a Peg
                        type = "quest",
                        id = 94396,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 237873,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Spellbook Scuffle
            type = "quest",
            id = 86997,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Training Arc
            type = "quest",
            id = 86998,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Academic Aspirations
            type = "quest",
            id = 87002,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheDrinkingDebt, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 15),
    questline = 5784,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86735,
            completed = {
                type = "quest",
                ids = { 86735, 86736, }
            }
        },
    },
    active = {
        type = "quest",
        id = 87455,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 87458,
    },
    items = {
        {
            type = "npc",
            id = 238730,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Trials and Tabulations
            type = "quest",
            id = 87455,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Souvenirs Scattered
            type = "quest",
            id = 87456,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- What We Do Best
            type = "quest",
            id = 87457,
            connections = {
                1, 
            },
        },
        { -- Debts Paid
            type = "quest",
            id = 87458,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheftTracking, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 16),
    questline = 5804,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86735,
            completed = {
                type = "quest",
                ids = { 86735, 86736, }
            }
        },
    },
    active = {
        type = "quest",
        ids = {
            88977, 88978, 94388, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90544,
    },
    items = {
        {
            type = "npc",
            id = 240408,
            x = -1,
            connections = {
                2, 
            },
        },
        {
            variations = {
                { -- Second Time's a Choice
                    type = "quest",
                    id = 94388,
                    restrictions = { -- Second Time's a Choice
                        type = "quest",
                        id = 94388,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 240403,
                },
            },
            connections = {
                2, 
            },
        },
        { -- Tracking the Trail
            type = "quest",
            id = 88978,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Reenact the Crime
            type = "quest",
            id = 88977,
            connections = {
                1, 
            },
        },
        { -- Caught Red-Handed
            type = "quest",
            id = 88979,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Thief at Bark
            type = "quest",
            id = 90544,
            x = 0,
        },
    }
})
Database:AddChain(Chain.DaggerspineLanding, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 17),
    questline = 5958,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheLightsSummons,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = Chain.Shadowfall,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            completed = {
                type = "quest",
                ids = {
                    86781, 94370, 91493, 
                },
                status = { "active", "completed", },
            },
            upto = 86781,
        },
    },
    active = {
        type = "quest",
        ids = {
            91493, 94370, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91504,
    },
    items = {
        {
            variations = {
                { -- Slithering Closer
                    type = "quest",
                    id = 94370,
                    restrictions = { -- Slithering Closer
                        type = "quest",
                        id = 94370,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 247503,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Not What I Ordered
            type = "quest",
            id = 91493,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Daggers in My Spine
            type = "quest",
            id = 91505,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Familiar Faces in Peril
            type = "quest",
            id = 91495,
            connections = {
                2, 
            },
        },
        { -- One Elf's Trash, Another Elf's Treasure
            type = "quest",
            id = 91494,
            connections = {
                1, 
            },
        },
        { -- Arcane Amassing
            type = "quest",
            id = 91504,
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
        { -- Renowned with the Silvermoon Court
            type = "quest",
            id = 93811,
        },
        { -- Eversong
            type = "quest",
            id = 94871,
        },
        { -- Adventuring in Midnight
            type = "quest",
            id = 94993,
        },
        { -- Adventuring in Midnight
            type = "quest",
            id = 95008,
        },
    },
})

Database:AddCategory(CATEGORY_ID, {
    name = BtWQuests.GetMapName(MAP_ID),
    expansion = EXPANSION_ID,
    items = {
        {
            type = "chain",
            id = Chain.WhispersInTheTwilight,
        },
        {
            type = "chain",
            id = Chain.Shadowfall,
        },
        {
            type = "chain",
            id = Chain.RippleEffects,
        },
        {
            type = "chain",
            id = Chain.FearAndFel,
        },
        {
            type = "chain",
            id = Chain.FlowersForAmalthea,
        },
        {
            type = "chain",
            id = Chain.SunbathTakeMeAway,
        },
        {
            type = "chain",
            id = Chain.PortDetective,
        },
        {
            type = "chain",
            id = Chain.LesserEvil,
        },
        {
            type = "chain",
            id = Chain.OneAdventurousHatchling,
        },
        {
            type = "chain",
            id = Chain.FarStriding,
        },
        {
            type = "chain",
            id = Chain.TailorTroubles,
        },
        {
            type = "chain",
            id = Chain.BlindingSun,
        },
        {
            type = "chain",
            id = Chain.RunestoneRumbles,
        },
        {
            type = "chain",
            id = Chain.PaladinRescue,
        },
        {
            type = "chain",
            id = Chain.HowToTrainYourProtege,
        },
        {
            type = "chain",
            id = Chain.ScootinThroughSilvermoon,
        },
        {
            type = "chain",
            id = Chain.AspiringAcademic,
        },
        {
            type = "chain",
            id = Chain.TheDrinkingDebt,
        },
        {
            type = "chain",
            id = Chain.TheftTracking,
        },
        {
            type = "chain",
            id = Chain.DaggerspineLanding,
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

Database:AddMapRecursive(MAP_ID, {
    type = "category",
    id = CATEGORY_ID,
})

BtWQuestsDatabase:AddQuestItemsForChain(Chain.WhispersInTheTwilight)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.Shadowfall)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.RippleEffects)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.FearAndFel)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.FlowersForAmalthea)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.SunbathTakeMeAway)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.PortDetective)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.LesserEvil)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.OneAdventurousHatchling)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.FarStriding)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TailorTroubles)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.BlindingSun)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.RunestoneRumbles)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.PaladinRescue)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.HowToTrainYourProtege)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.ScootinThroughSilvermoon)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.AspiringAcademic)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheDrinkingDebt)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheftTracking)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.DaggerspineLanding)
