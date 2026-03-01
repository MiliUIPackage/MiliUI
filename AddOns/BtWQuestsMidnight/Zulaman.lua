local BtWQuests = BtWQuests
local Database = BtWQuests.Database
local EXPANSION_ID = BtWQuests.Constant.Expansions.Midnight
local CATEGORY_ID = BtWQuests.Constant.Category.Midnight.Zulaman
local Chain = BtWQuests.Constant.Chain.Midnight.Zulaman
local THREADS_OF_FATE_RESTRICTION = BtWQuests.Constant.Restrictions.MidnightToF
local NOT_THREADS_OF_FATE_RESTRICTION = BtWQuests.Constant.Restrictions.NotMidnightToF
local ALLIANCE_RESTRICTIONS, HORDE_RESTRICTIONS = 724, 723
local MAP_ID = 2437
local CONTINENT_ID = 2537
local ACHIEVEMENT_ID_1 = 41803
local ACHIEVEMENT_ID_2 = 61452
local LEVEL_RANGE = {70, 80}
local LEVEL_PREREQUISITES = {
    {
        type = "level",
        level = 70,
    },
}

Chain.DisWasOurLand = 120201
Chain.PathOfDeHashey = 120202
Chain.WhereWarSlumbers = 120203
Chain.DeAmaniNeverDie = 120204
Chain.HealingTheSpirit = 120211
Chain.SawdustToSawdust = 120212
Chain.BetweenTwoTrolls = 120213
Chain.SorrowingKin = 120214
Chain.UnlikelyFriends = 120215
Chain.TheVoiceOfNalorakk = 120216
Chain.ReclaimingDeHonor = 120217
Chain.VengeanceForTolbani = 120218
Chain.TheLoaOfMurlocs = 120219
Chain.NoFear = 120220
Chain.BitterHonor = 120221
Chain.TheSoundOfHerVoice = 120222
Chain.AVenomousHistory = 120223
Chain.BeyondTheWalls = 120224
Chain.SomethingVileThisWayComes = 120225
Chain.RiverWalkersOfTheProwl = 120226
Chain.Bloodstains = 120227
Chain.OtherAlliance = 120297
Chain.OtherHorde = 120298
Chain.OtherBoth = 120299

Database:AddChain(Chain.DisWasOurLand, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 1),
    questline = 5722,
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
        id = 86708,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86652,
    },
    items = {
        {
            type = "npc",
            id = 240523,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Gates of Zul'Aman
            type = "quest",
            id = 86708,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Line Must be Drawn Here
            type = "quest",
            id = 86710,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Our Mutual Enemy
            type = "quest",
            id = 90749,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Amani Clarion Call
            type = "quest",
            id = 86711,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Goodwill Tour
            type = "quest",
            id = 86868,
            connections = {
                1, 2, 
            },
        },
        { -- Important Amani
            type = "quest",
            id = 86719,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Show Us Your Worth
            type = "quest",
            id = 86717,
            connections = {
                1, 2, 
            },
        },
        { -- Armed by Light
            type = "quest",
            id = 86716,
            x = -1,
            connections = {
                2, 3, 4, 
            },
        },
        { -- Everything We Worked For
            type = "quest",
            id = 86721,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Twilight Bled
            type = "quest",
            id = 86718,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Rituals Cut Short
            type = "quest",
            id = 86715,
            connections = {
                2, 
            },
        },
        { -- The Amani Stand Strong
            type = "quest",
            id = 86712,
            connections = {
                1, 
            },
        },
        { -- Break the Blade
            type = "quest",
            id = 86720,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Heart of the Amani
            type = "quest",
            id = 86722,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Isolation
            type = "quest",
            id = 86723,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Left in the Shadows
            type = "quest",
            id = 86652,
            x = 0,
        },
    }
})
Database:AddChain(Chain.PathOfDeHashey, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 2),
    questline = 5723,
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
                    restrictions = THREADS_OF_FATE_RESTRICTION,
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
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.DisWasOurLand,
        },
    },
    active = {
        type = "quest",
        id = 86653,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86666,
    },
    items = {
        {
            type = "npc",
            id = 236126,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Path of the Amani
            type = "quest",
            id = 86653,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Gnarldin Bashing
            type = "quest",
            id = 86654,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- De Ancient Path
            type = "quest",
            id = 86655,
            connections = {
                2, 
            },
        },
        { -- Ahead of the Issue
            type = "quest",
            id = 89334,
            connections = {
                1, 
            },
        },
        { -- Brutal Feast
            type = "quest",
            id = 86656,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Test of Conviction
            type = "quest",
            id = 86809,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Shadebasin Watch
            type = "quest",
            id = 86657,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Crypt in the Mist
            type = "quest",
            id = 86658,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Rescue from the Shadows
            type = "quest",
            id = 86660,
            connections = {
                1, 
            },
        },
        { -- Breaching the Mist
            type = "quest",
            id = 86659,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Halazzi's Guile
            type = "quest",
            id = 92084,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Coals of a Dead Loa
            type = "quest",
            id = 86661,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Riddled Speaker
            type = "quest",
            id = 86808,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Embers to a Flame
            type = "quest",
            id = 86663,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Seer or Sear
            type = "quest",
            id = 86664,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Face in the Fire
            type = "quest",
            id = 86665,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Flames Rise Higher
            type = "quest",
            id = 90772,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- In the Shadow of Rebirth
            type = "quest",
            id = 86666,
            x = 0,
        },
    }
})
Database:AddChain(Chain.WhereWarSlumbers, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 3),
    questline = 5938,
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
                    restrictions = THREADS_OF_FATE_RESTRICTION,
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
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.DisWasOurLand,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.PathOfDeHashey,
        },
    },
    active = {
        type = "quest",
        id = 86681,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91958,
    },
    items = {
        {
            type = "npc",
            id = 240186,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Den of Nalorakk: A Taste of Vengeance
            type = "quest",
            id = 86681,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Den of Nalorakk: Waking de Bear
            type = "quest",
            id = 86682,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Den of Nalorakk: Unforgiven
            type = "quest",
            id = 91958,
            x = 0,
        },
    }
})
Database:AddChain(Chain.DeAmaniNeverDie, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 4),
    questline = 5724,
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
                    restrictions = THREADS_OF_FATE_RESTRICTION,
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
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.DisWasOurLand,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.PathOfDeHashey,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.WhereWarSlumbers,
        },
    },
    active = {
        type = "quest",
        id = 86683,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91062,
    },
    items = {
        {
            type = "npc",
            id = 240215,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Hash'ey Away
            type = "quest",
            id = 86683,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Blade's Edge
            type = "quest",
            id = 86684,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Chip and Shatter
            type = "quest",
            id = 86685,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Light Indiscriminate
            type = "quest",
            id = 86686,
            connections = {
                2, 
            },
        },
        { -- Conduit Crisis
            type = "quest",
            id = 86687,
            connections = {
                1, 
            },
        },
        { -- Clear de Way
            type = "quest",
            id = 91001,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Blade Shattered
            type = "quest",
            id = 86692,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- De Legend of de Hash'ey
            type = "quest",
            id = 86693,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Broken Bridges
            type = "quest",
            id = 91062,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Reports Returned
            type = "quest",
            id = 91087,
            aside = true,
            x = 0,
        },
    }
})
Database:AddChain(Chain.HealingTheSpirit, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 1),
    questline = 5778,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DeAmaniNeverDie,
            completed = {
                type = "quest",
                id = 91062,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 91206,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92531,
    },
    items = {
        {
            type = "npc",
            id = 254665,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Loa Disturbance
            type = "quest",
            id = 91206,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Curse Cleanse
            type = "quest",
            id = 87254,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Alternative Medicine
            type = "quest",
            id = 87256,
            connections = {
                1, 
            },
        },
        { -- Demands Unmet
            type = "quest",
            id = 87267,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Required Repentance
            type = "quest",
            id = 87268,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Denial Denied
            type = "quest",
            id = 87317,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Medicine Loa's Shrine
            type = "quest",
            id = 92531,
            x = 0,
        },
    }
})
Database:AddChain(Chain.SawdustToSawdust, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 2),
    questline = 6048,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            variations = {
                {
                    level = 80,
                    restrictions = THREADS_OF_FATE_RESTRICTION,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DisWasOurLand,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            88985, 88986, 88987, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 88989,
    },
    items = {
        {
            variations = {
                { -- Recuperating Returns
                    type = "quest",
                    id = 88985,
                    restrictions = { -- Recuperating Returns
                        type = "quest",
                        id = 88985,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 240521,
                },
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Blind the Bandits
            type = "quest",
            id = 88986,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Salvaged Sabotage
            type = "quest",
            id = 88987,
            connections = {
                1, 
            },
        },
        { -- The Artisan's Apprentice
            type = "quest",
            id = 88988,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Another One Bites the Sawdust
            type = "quest",
            id = 88989,
            x = 0,
        },
    }
})
Database:AddChain(Chain.BetweenTwoTrolls, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 3),
    questline = 5981,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DeAmaniNeverDie,
            completed = {
                type = "quest",
                id = 91062,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            89230, 89231, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 89233,
    },
    items = {
        {
            type = "npc",
            id = 240976,
            x = -1,
            connections = {
                2, 
            },
        },
        {
            type = "npc",
            id = 240977,
            connections = {
                2, 
            },
        },
        { -- A Lover Not a Fighter
            type = "quest",
            id = 89230,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- A Fighter Not a Lover
            type = "quest",
            id = 89231,
            connections = {
                1, 
            },
        },
        { -- Love Triangle
            type = "quest",
            id = 89233,
            x = 0,
        },
    }
})
Database:AddChain(Chain.SorrowingKin, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 4),
    questline = 5901,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DeAmaniNeverDie,
            completed = {
                type = "quest",
                id = 91062,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 89565,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 89560,
    },
    items = {
        {
            type = "npc",
            id = 242014,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Path of Mourning
            type = "quest",
            id = 89565,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Somber Siblings
            type = "quest",
            id = 89503,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Strong Ties
            type = "quest",
            id = 89506,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Kindling Aplenty
            type = "quest",
            id = 89513,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Reasonless Worship
            type = "quest",
            id = 89559,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Quiet Farewell
            type = "quest",
            id = 89560,
            x = 0,
        },
    }
})
Database:AddChain(Chain.UnlikelyFriends, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 5),
    questline = 5905,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DisWasOurLand,
            completed = {
                type = "quest",
                id = 86657,
                onAccount = true,
            },
            upto = 86657,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            90481, 93667, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90568,
    },
    items = {
        {
            variations = {
                { -- Camp Stonewash
                    type = "quest",
                    id = 93667,
                    restrictions = { -- Camp Stonewash
                        type = "quest",
                        id = 93667,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 242383,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- I Have a Permit
            type = "quest",
            id = 90481,
            x = 0,
            connections = {
                1, 2, 3, 4, 
            },
        },
        {
            type = "quest",
            id = 90483,
            x = -3,
            connections = {
                5, 
            },
        },
        {
            type = "quest",
            id = 90485,
            connections = {
                4, 
            },
        },
        {
            type = "quest",
            id = 90484,
            connections = {
                3, 
            },
        },
        { -- Cuisine Connection
            type = "quest",
            id = 90482,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 90486,
            x = 3,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 90568,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheVoiceOfNalorakk, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 6),
    questline = 5971,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.WhereWarSlumbers,
            completed = {
                type = "quest",
                id = 91958,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 91813,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91750,
    },
    items = {
        {
            type = "npc",
            id = 248657,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Spiritpaw
            type = "quest",
            id = 91813,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Not Quite Nalorakk
            type = "quest",
            id = 91747,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Too Much Twilight
            type = "quest",
            id = 91748,
            connections = {
                1, 
            },
        },
        { -- It's Just Not Right
            type = "quest",
            id = 91749,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Precious Trinkets
            type = "quest",
            id = 93734,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Perils of Trust
            type = "quest",
            id = 91750,
            x = 0,
        },
    }
})
Database:AddChain(Chain.ReclaimingDeHonor, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 7),
    questline = 6011,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DeAmaniNeverDie,
            completed = {
                type = "quest",
                id = 91062,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 92492,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92499,
    },
    items = {
        {
            type = "npc",
            id = 245664,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Honorin' de Sacrifice
            type = "quest",
            id = 92492,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- What Remains of Idago
            type = "quest",
            id = 92493,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Disruptin' de Blade
            type = "quest",
            id = 92495,
            connections = {
                1, 2, 
            },
        },
        { -- Spears Against de Shadow
            type = "quest",
            id = 92496,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Simply Magical
            type = "quest",
            id = 92497,
            connections = {
                1, 
            },
        },
        { -- The Wisest Leaders Follow
            type = "quest",
            id = 92499,
            x = 0,
        },
    }
})
Database:AddChain(Chain.VengeanceForTolbani, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 8),
    questline = 5939,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DisWasOurLand,
            completed = {
                type = "quest",
                id = 86652,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            91069, 91070, 91071, 94867, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91556,
    },
    items = {
        {
            variations = {
                { -- Lost in Atal'Abasi
                    type = "quest",
                    id = 94867,
                    restrictions = { -- Lost in Atal'Abasi
                        type = "quest",
                        id = 94867,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 245669,
                },
            },
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Vengeance for Tolbani
            type = "quest",
            id = 91069,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Reclaim the Goods
            type = "quest",
            id = 91070,
            connections = {
                2, 
            },
        },
        { -- The Menace of Atal'Abasi
            type = "quest",
            id = 91071,
            connections = {
                1, 
            },
        },
        { -- Loa's Flame
            type = "quest",
            id = 91556,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheLoaOfMurlocs, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 9),
    questline = 5988,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
    },
    active = {
        type = "quest",
        ids = {
            92163, 92164, 92165, 92166, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92167,
    },
    items = {
        {
            variations = {
                { -- The Loa of Murlocs
                    type = "quest",
                    id = 92163,
                    restrictions = { -- The Loa of Murlocs
                        type = "quest",
                        id = 92163,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 250196,
                },
            },
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Murloc Madness
            type = "quest",
            id = 92164,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Fish Are Food, Not Friends
            type = "quest",
            id = 92165,
            connections = {
                2, 
            },
        },
        { -- Following Suit
            type = "quest",
            id = 92166,
            connections = {
                1, 
            },
        },
        { -- There Can Be Only One
            type = "quest",
            id = 92167,
            x = 0,
        },
    }
})
Database:AddChain(Chain.NoFear, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 10),
    questline = 5999,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DisWasOurLand,
            completed = {
                type = "quest",
                id = 86652,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 92450,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92453,
    },
    items = {
        {
            type = "npc",
            id = 251258,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Growing Up is Hard
            type = "quest",
            id = 92450,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- I Think I Can
            type = "quest",
            id = 92451,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Not According to Plan
            type = "quest",
            id = 92452,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Fearless
            type = "quest",
            id = 92453,
            x = 0,
        },
    }
})
Database:AddChain(Chain.BitterHonor, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 11),
    questline = 6042,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DisWasOurLand,
            completed = {
                type = "quest",
                id = 86652,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            93093, 93094, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 93096,
    },
    items = {
        {
            type = "npc",
            id = 253997,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Gnarldin Trophies
            type = "quest",
            id = 93093,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Scavenged Victory
            type = "quest",
            id = 93094,
            connections = {
                1, 
            },
        },
        { -- Bitter Fury
            type = "quest",
            id = 93095,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Amani Honor
            type = "quest",
            id = 93096,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheSoundOfHerVoice, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 12),
    questline = 6055,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
    },
    active = {
        type = "quest",
        id = 93178,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 93182,
    },
    items = {
        {
            type = "npc",
            id = 254716,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Quiet Walk Interrupted
            type = "quest",
            id = 93178,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Childlike Devotion
            type = "quest",
            id = 93179,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Shrine Preparations
            type = "quest",
            id = 93180,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Temple and a Teapot
            type = "quest",
            id = 93181,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Healing Homeward
            type = "quest",
            id = 93182,
            x = 0,
        },
    }
})
Database:AddChain(Chain.AVenomousHistory, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 13),
    questline = 5950,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        -- {
        --     name = "Unknown requirements, appeared while doing Harandar side quests, at level 88",
        -- },
    },
    active = {
        type = "quest",
        id = 91406,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91410,
    },
    items = {
        {
            type = "npc",
            id = 247014,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Far from the Hinterlands
            type = "quest",
            id = 91406,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Eye of the Loa
            type = "quest",
            id = 91407,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Halazzi's Hunt
            type = "quest",
            id = 91563,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Probable Paralytic
            type = "quest",
            id = 91403,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- A Most Vile Venom
            type = "quest",
            id = 91404,
            connections = {
                1, 
            },
        },
        { -- Validating the Venom
            type = "quest",
            id = 91405,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Seeking Shadra
            type = "quest",
            id = 91408,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Stolen Sight
            type = "quest",
            id = 91630,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Dreaming of Spiders
            type = "quest",
            id = 91409,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Maisara Caverns: Deep in Maisara
            type = "quest",
            id = 91411,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Return of the Venom Queen
            type = "quest",
            id = 91412,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Shared Loa
            type = "quest",
            id = 91410,
            x = 0,
        },
    }
})
Database:AddChain(Chain.BeyondTheWalls, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 14),
    questline = 6044,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DisWasOurLand,
            completed = {
                type = "quest",
                id = 86652,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            93047, 93048, 93049, 93050, 93051, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        ids = {
            93047, 93048, 93049, 93050, 93051, 
        },
        count = 5,
    },
    items = {
        {
            type = "npc",
            id = 255406,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Final Exam
            type = "quest",
            id = 93051,
            x = 0,
        },
        {
            type = "npc",
            id = 241072,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Butchery Basics
            type = "quest",
            id = 93047,
            x = 0,
        },
        {
            type = "npc",
            id = 254142,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Got No Rhythm
            type = "quest",
            id = 93048,
            x = 0,
        },
        {
            type = "npc",
            id = 254144,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Homework Support
            type = "quest",
            id = 93049,
            x = 0,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DeAmaniNeverDie,
        },
        {
            type = "npc",
            id = 254146,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Altar History
            type = "quest",
            id = 93050,
            x = 0,
        },
    }
})
Database:AddChain(Chain.SomethingVileThisWayComes, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 15),
    questline = 5975,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 90,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.AVenomousHistory,
        },
    },
    active = {
        type = "quest",
        id = 91833,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91839,
    },
    items = {
        {
            type = "npc",
            id = 244591,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Dirty Deeps
            type = "quest",
            id = 91833,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Send Dem Home
            type = "quest",
            id = 91835,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Respect de Totem
            type = "quest",
            id = 91836,
            connections = {
                2, 
            },
        },
        { -- De Vile Diminished
            type = "quest",
            id = 91838,
            connections = {
                1, 
            },
        },
        { -- One Will Not Rise
            type = "quest",
            id = 91840,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Sacrifice Denied
            type = "quest",
            id = 91839,
            x = 0,
        },
    }
})
Database:AddChain(Chain.RiverWalkersOfTheProwl, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 16),
    questline = 6045,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DisWasOurLand,
            completed = {
                type = "quest",
                id = 86652,
                onAccount = true,
            },
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 93257,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 93261,
    },
    items = {
        {
            type = "npc",
            id = 254488,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Revantusk at Risk
            type = "quest",
            id = 93257,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Crab Clues
            type = "quest",
            id = 93258,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Clobbering Crawlers
            type = "quest",
            id = 93259,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Caging Crawlers
            type = "quest",
            id = 93260,
            connections = {
                1, 
            },
        },
        { -- A Crab of Unusual Size
            type = "quest",
            id = 93261,
            x = 0,
        },
    }
})
Database:AddChain(Chain.Bloodstains, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 17),
    questline = 6052,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
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
            lowPriority = true,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.EversongWoods.WhispersInTheTwilight,
            lowPriority = true,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.EversongWoods.Shadowfall,
            lowPriority = true,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.EversongWoods.RippleEffects,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DeAmaniNeverDie,
        },
    },
    active = {
        type = "quest",
        id = 93440,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 93437,
    },
    items = {
        {
            type = "npc",
            id = 249653,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Personal History
            type = "quest",
            id = 93440,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Swords to Plowshares
            type = "quest",
            id = 93432,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Shrine, Sealed, Delivered
            type = "quest",
            id = 93433,
            connections = {
                1, 2, 
            },
        },
        { -- Four Instigators
            type = "quest",
            id = 93435,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Hex the Innocent, Disrupt the Guilty
            type = "quest",
            id = 93436,
            connections = {
                1, 
            },
        },
        { -- In Their Own Blood
            type = "quest",
            id = 93437,
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
    name = BtWQuests.GetMapName(MAP_ID),
    expansion = EXPANSION_ID,
    items = {
        {
            type = "chain",
            id = Chain.DisWasOurLand,
        },
        {
            type = "chain",
            id = Chain.PathOfDeHashey,
        },
        {
            type = "chain",
            id = Chain.WhereWarSlumbers,
        },
        {
            type = "chain",
            id = Chain.DeAmaniNeverDie,
        },
        {
            type = "chain",
            id = Chain.HealingTheSpirit,
        },
        {
            type = "chain",
            id = Chain.SawdustToSawdust,
        },
        {
            type = "chain",
            id = Chain.BetweenTwoTrolls,
        },
        {
            type = "chain",
            id = Chain.SorrowingKin,
        },
        {
            type = "chain",
            id = Chain.UnlikelyFriends,
        },
        {
            type = "chain",
            id = Chain.TheVoiceOfNalorakk,
        },
        {
            type = "chain",
            id = Chain.ReclaimingDeHonor,
        },
        {
            type = "chain",
            id = Chain.VengeanceForTolbani,
        },
        {
            type = "chain",
            id = Chain.TheLoaOfMurlocs,
        },
        {
            type = "chain",
            id = Chain.NoFear,
        },
        {
            type = "chain",
            id = Chain.BitterHonor,
        },
        {
            type = "chain",
            id = Chain.TheSoundOfHerVoice,
        },
        {
            type = "chain",
            id = Chain.AVenomousHistory,
        },
        {
            type = "chain",
            id = Chain.BeyondTheWalls,
        },
        {
            type = "chain",
            id = Chain.SomethingVileThisWayComes,
        },
        {
            type = "chain",
            id = Chain.RiverWalkersOfTheProwl,
        },
        {
            type = "chain",
            id = Chain.Bloodstains,
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

BtWQuestsDatabase:AddQuestItemsForChain(Chain.DisWasOurLand)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.PathOfDeHashey)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.WhereWarSlumbers)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.DeAmaniNeverDie)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.HealingTheSpirit)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.SawdustToSawdust)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.BetweenTwoTrolls)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.SorrowingKin)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.UnlikelyFriends)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheVoiceOfNalorakk)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.ReclaimingDeHonor)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.VengeanceForTolbani)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheLoaOfMurlocs)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.NoFear)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.BitterHonor)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheSoundOfHerVoice)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.AVenomousHistory)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.BeyondTheWalls)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.SomethingVileThisWayComes)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.RiverWalkersOfTheProwl)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.Bloodstains)
