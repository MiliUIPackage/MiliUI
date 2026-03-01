local BtWQuests = BtWQuests
local Database = BtWQuests.Database
local EXPANSION_ID = BtWQuests.Constant.Expansions.Midnight
local CATEGORY_ID = BtWQuests.Constant.Category.Midnight.Voidstorm
local Chain = BtWQuests.Constant.Chain.Midnight.Voidstorm
local THREADS_OF_FATE_RESTRICTION = BtWQuests.Constant.Restrictions.MidnightToF
local NOT_THREADS_OF_FATE_RESTRICTION = BtWQuests.Constant.Restrictions.NotMidnightToF
local ALLIANCE_RESTRICTIONS, HORDE_RESTRICTIONS = 724, 723
local MAP_ID = 2405
local CONTINENT_ID = 2537
local ACHIEVEMENT_ID_1 = 41806
local ACHIEVEMENT_ID_2 = 61864
local LEVEL_RANGE = {70, 80}
local LEVEL_PREREQUISITES = {
    {
        type = "level",
        level = 70,
    },
}

Chain.IntoTheAbyss = 120401
Chain.TheNightsVeil = 120402
Chain.DawnOfReckoning = 120403
Chain.TheVoidPeersBack = 120411
Chain.ShadowPuppets = 120412
Chain.TheNethersent = 120413
Chain.TheNightbreaker = 120414
Chain.PathogenicProblem = 120415
Chain.AVoiceInside = 120416
Chain.ShadowguardsShadow = 120417
Chain.AGiftGivenFreely = 120418
Chain.BreakingTheTriad = 120419
Chain.GoLowGoLoud = 120420
Chain.SecretsInTheDark = 120421
Chain.OathsToFamily = 120422
Chain.ToBeChanged = 120423
Chain.ADanceWithTheDevil = 120424
Chain.ADomanaarsBestFriend = 120425
Chain.AMorePotentFoe = 120426
Chain.OtherAlliance = 120497
Chain.OtherHorde = 120498
Chain.OtherBoth = 120499

Database:AddChain(Chain.IntoTheAbyss, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 1),
    questline = 5728,
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
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DeAmaniNeverDie,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.Emergence,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Arator.RegretsOfThePast,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheDarkeningSky,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            89388, 92061, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86565,
    },
    items = {
        {
            variations = {
                { -- Voidstorm
                    type = "quest",
                    id = 89388,
                    restrictions = { -- Voidstorm
                        type = "quest",
                        id = 89388,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 235787,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Rising Storm
            type = "quest",
            id = 92061,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Magisters' Terrace: Homecoming
            type = "quest",
            id = 86543,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- No Fear of the Dark
            type = "quest",
            id = 86549,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- A Matter of Strife and Death
            type = "quest",
            id = 86557,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Save a Piece of Mind
            type = "quest",
            id = 86558,
            connections = {
                1, 
            },
        },
        { -- The Far, Far Frontier
            type = "quest",
            id = 86559,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- A Strange, Different World
            type = "quest",
            id = 86561,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Dancing with Death
            type = "quest",
            id = 86562,
            connections = {
                1, 
            },
        },
        { -- No Prayer for the Wicked
            type = "quest",
            id = 86565,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheNightsVeil, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 2),
    questline = 5729,
    category = CATEGORY_ID,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    major = true,
    prerequisites = {
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DeAmaniNeverDie,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.Emergence,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Arator.RegretsOfThePast,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheDarkeningSky,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.IntoTheAbyss,
        },
    },
    active = {
        type = "quest",
        id = 86536,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86545,
    },
    items = {
        {
            type = "npc",
            id = 235606,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Reliable Enemies
            type = "quest",
            id = 86536,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Work Disruption
            type = "quest",
            id = 86531,
            x = -2,
            connections = {
                3, 4, 
            },
        },
        { -- First, The Shells
            type = "quest",
            id = 86530,
            connections = {
                2, 3, 
            },
        },
        { -- A Cracked Holokey
            type = "quest",
            id = 86528,
            connections = {
                1, 2, 
            },
        },
        { -- Second, The Fuel
            type = "quest",
            id = 86538,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Network Insecurity
            type = "quest",
            id = 86537,
            connections = {
                1, 
            },
        },
        { -- A Naaru!
            type = "quest",
            id = 86539,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Agents of Darkness
            type = "quest",
            id = 88768,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Third, Blow It Up
            type = "quest",
            id = 86540,
            connections = {
                2, 
            },
        },
        { -- Just In Case...
            type = "quest",
            id = 86541,
            connections = {
                1, 
            },
        },
        { -- Flicker in the Dark
            type = "quest",
            id = 86542,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Overwhelmed
            type = "quest",
            id = 89249,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Post-Mortem
            type = "quest",
            id = 86544,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Light's Brand
            type = "quest",
            id = 86545,
            x = 0,
        },
    }
})
Database:AddChain(Chain.DawnOfReckoning, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 3),
    questline = 5730,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Zulaman.DeAmaniNeverDie,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.Emergence,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Arator.RegretsOfThePast,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.TheDarkeningSky,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.IntoTheAbyss,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.TheNightsVeil,
        },
    },
    active = {
        type = "quest",
        id = 86509,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86522,
    },
    items = {
        {
            type = "npc",
            id = 240691,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Friend or Fiend
            type = "quest",
            id = 86509,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Domus Penumbra
            type = "quest",
            id = 86510,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Lay of the Beast
            type = "quest",
            id = 90571,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Edge of the Abyss
            type = "quest",
            id = 86511,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Harvest
            type = "quest",
            id = 86512,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Face the Tide
            type = "quest",
            id = 86513,
            connections = {
                1, 
            },
        },
        { -- Lady of the Pit
            type = "quest",
            id = 86514,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Hollow Hunger
            type = "quest",
            id = 86515,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- All Become Prey
            type = "quest",
            id = 86516,
            connections = {
                2, 
            },
        },
        { -- Vanished in the Void
            type = "quest",
            id = 86517,
            connections = {
                1, 
            },
        },
        { -- The Mantle of Predation
            type = "quest",
            id = 86518,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Abyssus, Abyssum
            type = "quest",
            id = 86519,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Hunt the Light
            type = "quest",
            id = 86520,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Nexus-Point Xenas: Eclipse
            type = "quest",
            id = 86521,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Daylight is Breaking
            type = "quest",
            id = 86522,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheVoidPeersBack, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 1),
    questline = 6010,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.IntoTheAbyss,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            87388, 87391, 88755, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 88708,
    },
    items = {
        {
            type = "npc",
            id = 236908,
            visible = { -- Scholarly Pursuits
                type = "quest",
                id = 88755,
                status = { "pending", },
            },
            x = -1,
            connections = {
                3, 
            },
        },
        { -- Scholarly Pursuits
            type = "quest",
            id = 88755,
            visible = { -- Scholarly Pursuits
                type = "quest",
                id = 88755,
                status = { "active", "completed", },
            },
            x = 0,
            connections = {
                2, 3, 
            },
        },
        {
            type = "npc",
            id = 236930,
            visible = { -- Scholarly Pursuits
                type = "quest",
                id = 88755,
                status = { "pending", },
            },
            x = 1,
            connections = {
                2, 
            },
        },
        { -- A Bigger Beast
            type = "quest",
            id = 87388,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Sampling the Local Fare
            type = "quest",
            id = 87391,
            connections = {
                1, 2, 
            },
        },
        { -- Yolks on You
            type = "quest",
            id = 88653,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Void is in the Air
            type = "quest",
            id = 87672,
            connections = {
                1, 
            },
        },
        { -- Violent Conclusions
            type = "quest",
            id = 88708,
            x = 0,
        },
    }
})
Database:AddChain(Chain.ShadowPuppets, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 2),
    questline = 5943,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 91145,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91149,
    },
    items = {
        {
            type = "npc",
            id = 245878,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Conquered Heroes
            type = "quest",
            id = 91145,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Flickering Light
            type = "quest",
            id = 91146,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Cut Her Strings
            type = "quest",
            id = 91147,
            connections = {
                1, 
            },
        },
        { -- Strung Along
            type = "quest",
            id = 91148,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Bury Me Not
            type = "quest",
            id = 91149,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheNethersent, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 3),
    questline = 5933,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86509,
        },
    },
    active = {
        type = "quest",
        id = 90782,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90875,
    },
    items = {
        {
            type = "npc",
            id = 242233,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Nethersent
            type = "quest",
            id = 90782,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 90866,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 90872,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        {
            type = "quest",
            id = 90873,
            x = -1,
            connections = {
                2, 
            },
        },
        {
            type = "quest",
            id = 90874,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 90875,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheNightbreaker, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 4),
    questline = 5962,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.IntoTheAbyss,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 90910,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91343,
    },
    items = {
        {
            type = "npc",
            id = 239720,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Overwhelming Darkness
            type = "quest",
            id = 90910,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Smothered in the Crib
            type = "quest",
            id = 91339,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- For Violence's Sake
            type = "quest",
            id = 91340,
            connections = {
                1, 
            },
        },
        { -- Unlimited
            type = "quest",
            id = 91341,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Ambition's Reward
            type = "quest",
            id = 91343,
            x = 0,
        },
    }
})
Database:AddChain(Chain.PathogenicProblem, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 5),
    questline = 6028,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.IntoTheAbyss,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            91557, 91558, 91559, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91561,
    },
    items = {
        {
            variations = {
                { -- Message to the Molt
                    type = "quest",
                    id = 91557,
                    restrictions = { -- Message to the Molt
                        type = "quest",
                        id = 91557,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 247664,
                },
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Pestilent Petals
            type = "quest",
            id = 91558,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Virulent Vermin
            type = "quest",
            id = 91559,
            connections = {
                1, 2, 
            },
        },
        { -- Expunging Explorers
            type = "quest",
            id = 91560,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Calculated Culling
            type = "quest",
            id = 93801,
            connections = {
                1, 
            },
        },
        { -- Bloodborne Pathogen
            type = "quest",
            id = 91561,
            x = 0,
        },
    }
})
Database:AddChain(Chain.AVoiceInside, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 6),
    questline = 6013,
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
                    level = 86,
                },
            },
        },
    },
    active = {
        type = "quest",
        ids = {
            91884, 91885, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91887,
    },
    items = {
        {
            variations = {
                { -- The Illusion of Motion
                    type = "quest",
                    id = 91884,
                    restrictions = { -- The Illusion of Motion
                        type = "quest",
                        id = 91884,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 248880,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Drain You
            type = "quest",
            id = 91885,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 91886,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 91887,
            x = 0,
        },
    }
})
Database:AddChain(Chain.ShadowguardsShadow, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 7),
    questline = 5987,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86509,
        },
    },
    active = {
        type = "quest",
        id = 92390,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92159,
    },
    items = {
        {
            type = "npc",
            id = 250677,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Risk for Research
            type = "quest",
            id = 92390,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Object Exorcism
            type = "quest",
            id = 92155,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- It Follows Me
            type = "quest",
            id = 92156,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Ritual Activity
            type = "quest",
            id = 92157,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Let It In
            type = "quest",
            id = 92158,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Final Destination
            type = "quest",
            id = 92159,
            x = 0,
        },
    }
})
Database:AddChain(Chain.AGiftGivenFreely, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 8),
    questline = 6019,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86509,
        },
    },
    active = {
        type = "quest",
        id = 92603,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92607,
    },
    items = {
        {
            type = "npc",
            id = 252510,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- O Lonely Star
            type = "quest",
            id = 92603,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Speak in Blood
            type = "quest",
            id = 92604,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Honest as Bone
            type = "quest",
            id = 92605,
            connections = {
                1, 
            },
        },
        { -- Take Up Your Gift
            type = "quest",
            id = 92606,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- And Carve New Shapes
            type = "quest",
            id = 92607,
            x = 0,
        },
    }
})
Database:AddChain(Chain.BreakingTheTriad, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 9),
    questline = 5964,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86509,
        },
    },
    active = {
        type = "quest",
        ids = {
            91565, 91566, 91583, 91597, 91598, 91599, 91600, 91603, 91605, 94844, 94845, 94848, 94849, 94855, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91606,
    },
    items = {
        {
            variations = {
                {
                    type = "npc",
                    id = 257478,
                    restrictions = 923,
                },
                {
                    type = "npc",
                    id = 257479,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        {
            variations = {
                { -- Voidscar Arena: The Hate Spire
                    type = "quest",
                    id = 91566,
                    restrictions = 923,
                },
                { -- Voidscar Arena: The Grief Spire
                    type = "quest",
                    id = 91565,
                },
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        {
            variations = {
                { -- Voidscar Arena: The Bastion of Might
                    type = "quest",
                    id = 94845,
                    restrictions = 923,
                },
                { -- Voidscar Arena: The Bastion of Valor
                    type = "quest",
                    id = 91583,
                },
            },
            x = -1,
            connections = {
                2, 3, 
            },
        },
        {
            variations = {
                { -- Voidscar Arena: For My Horde
                    type = "quest",
                    id = 94844,
                    restrictions = 923,
                },
                { -- Voidscar Arena: For My Alliance
                    type = "quest",
                    id = 91597,
                },
            },
            connections = {
                1, 2, 
            },
        },
        {
            variations = {
                { -- Voidscar Arena: Pre-Provoked Violence
                    type = "quest",
                    id = 94848,
                    restrictions = 923,
                },
                { -- Voidscar Arena: Pre-Provoked Violence
                    type = "quest",
                    id = 91598,
                },
            },
            x = -1,
            connections = {
                2, 
            },
        },
        {
            variations = {
                { -- Voidscar Arena: A Familiar Grudge
                    type = "quest",
                    id = 94849,
                    restrictions = 923,
                },
                { -- Voidscar Arena: A Familiar Grudge
                    type = "quest",
                    id = 91599,
                },
            },
            connections = {
                1, 
            },
        },
        {
            variations = {
                { -- Voidscar Arena: Setting It Aside
                    type = "quest",
                    id = 94855,
                    restrictions = 923,
                },
                { -- Voidscar Arena: Setting It Aside
                    type = "quest",
                    id = 91600,
                },
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Voidscar Arena: Two Against One
            type = "quest",
            id = 91603,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Voidscar Arena: The Wrong Side
            type = "quest",
            id = 91605,
            connections = {
                1, 
            },
        },
        { -- Voidscar Arena: Clearing House
            type = "quest",
            id = 91606,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Voidscar Arena: Breaking the Triad
            type = "quest",
            id = 91694,
            aside = true,
            x = 0,
        },
    }
})
Database:AddChain(Chain.GoLowGoLoud, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 10),
    questline = 6022,
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
                    level = 90,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            92657, 92658, 92659, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92662,
    },
    items = {
        {
            variations = {
                { -- The Brewing Storm
                    type = "quest",
                    id = 92657,
                    restrictions = { -- The Brewing Storm
                        type = "quest",
                        id = 92657,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 254509,
                },
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Tactical Acquisition
            type = "quest",
            id = 92658,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Resource Denial
            type = "quest",
            id = 92659,
            connections = {
                1, 2, 
            },
        },
        { -- Null Implements
            type = "quest",
            id = 92660,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Hammer Meet Anvil
            type = "quest",
            id = 92661,
            connections = {
                1, 
            },
        },
        { -- Core Collapse
            type = "quest",
            id = 92662,
            x = 0,
        },
    }
})
Database:AddChain(Chain.SecretsInTheDark, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 11),
    questline = 6017,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.IntoTheAbyss,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 92939,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92948,
    },
    items = {
        {
            type = "npc",
            id = 253038,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- It's Not Just a Rock!
            type = "quest",
            id = 92939,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Sifting Through Void
            type = "quest",
            id = 92944,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Buried in the Dark
            type = "quest",
            id = 92946,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- In Over My Head
            type = "quest",
            id = 92948,
            x = 0,
        },
    }
})
Database:AddChain(Chain.OathsToFamily, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 12),
    questline = 6014,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86509,
        },
    },
    active = {
        type = "quest",
        ids = {
            90838, 90844, 90845, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90860,
    },
    items = {
        {
            variations = {
                { -- Oaths and Heirlooms
                    type = "quest",
                    id = 90838,
                    restrictions = { -- Oaths and Heirlooms
                        type = "quest",
                        id = 90838,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 244499,
                },
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Fits of Lucidity
            type = "quest",
            id = 90844,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Distant Memories
            type = "quest",
            id = 90845,
            connections = {
                1, 
            },
        },
        { -- Truth From Power
            type = "quest",
            id = 90847,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- She Started the Fire
            type = "quest",
            id = 90848,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Eating Their Own
            type = "quest",
            id = 90851,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Techno-Magnetic Pulse
            type = "quest",
            id = 90852,
            connections = {
                1, 
            },
        },
        { -- Bursting at the Seams
            type = "quest",
            id = 93396,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Repress the Oppressors
            type = "quest",
            id = 90858,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Shedding the Yoke
            type = "quest",
            id = 90860,
            x = 0,
        },
    }
})
Database:AddChain(Chain.ToBeChanged, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 13),
    questline = 5961,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
        },
    },
    active = {
        type = "quest",
        id = 91533,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91546,
    },
    items = {
        {
            type = "npc",
            id = 249034,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- What We Leave Behind
            type = "quest",
            id = 91533,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Home Sweet Grave
            type = "quest",
            id = 91535,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Like a Weed
            type = "quest",
            id = 91536,
            connections = {
                1, 
            },
        },
        { -- Confronting It
            type = "quest",
            id = 91537,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Unchecked Emotions
            type = "quest",
            id = 91541,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Town Inside Me
            type = "quest",
            id = 91542,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Familiar Energies
            type = "quest",
            id = 91544,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Retaking Control
            type = "quest",
            id = 91543,
            connections = {
                2, 
            },
        },
        { -- Running Amok
            type = "quest",
            id = 91963,
            connections = {
                1, 
            },
        },
        { -- Stronger Than Before
            type = "quest",
            id = 91545,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- To Be Changed
            type = "quest",
            id = 91546,
            x = 0,
        },
    }
})
Database:AddChain(Chain.ADanceWithTheDevil, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 14),
    questline = 5936,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86521,
        },
    },
    active = {
        type = "quest",
        id = 90914,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90924,
    },
    items = {
        {
            type = "npc",
            id = 243907,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Born Killer
            type = "quest",
            id = 90914,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Artifice of Aggression
            type = "quest",
            id = 90915,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Seek to Destroy
            type = "quest",
            id = 90916,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Harvester of Savagery
            type = "quest",
            id = 90917,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- The Unforgiven
            type = "quest",
            id = 90918,
            connections = {
                1, 
            },
        },
        { -- The Fiend That Failed
            type = "quest",
            id = 90919,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Warmth for the Soul
            type = "quest",
            id = 90920,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Shepherd of Fear
            type = "quest",
            id = 90923,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- The Fallen Wake
            type = "quest",
            id = 90922,
            connections = {
                1, 
            },
        },
        { -- The Wicked End
            type = "quest",
            id = 90924,
            x = 0,
        },
    }
})
Database:AddChain(Chain.ADomanaarsBestFriend, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 15),
    questline = 6012,
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
                    level = 86,
                },
            },
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Voidstorm.DawnOfReckoning,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86509,
        },
    },
    active = {
        type = "quest",
        id = 91363,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91382,
    },
    items = {
        {
            type = "npc",
            id = 246727,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Harvest of Darkness
            type = "quest",
            id = 91363,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Belly of the Beast
            type = "quest",
            id = 91380,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Mighty and Superior
            type = "quest",
            id = 91382,
            x = 0,
        },
    }
})
Database:AddChain(Chain.AMorePotentFoe, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 16),
    questline = 6001,
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
        id = 92505,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92512,
    },
    items = {
        {
            type = "npc",
            id = 252110,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Truth of the Past
            type = "quest",
            id = 92505,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Soul Price
            type = "quest",
            id = 92506,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A More Potent Foe
            type = "quest",
            id = 92507,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Mark of Sacrifice
            type = "quest",
            id = 92508,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- One Cruel Implement
            type = "quest",
            id = 92509,
            connections = {
                1, 
            },
        },
        { -- Dark Infusion
            type = "quest",
            id = 92510,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Event Horizon
            type = "quest",
            id = 92511,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Devourer
            type = "quest",
            id = 92512,
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
        { -- Bloodying the Plain
            type = "quest",
            id = 92641,
        },
        { -- The Last Push
            type = "quest",
            id = 95276,
        },
    },
})

Database:AddCategory(CATEGORY_ID, {
    name = BtWQuests.GetMapName(MAP_ID),
    expansion = EXPANSION_ID,
    items = {
        {
            type = "chain",
            id = Chain.IntoTheAbyss,
        },
        {
            type = "chain",
            id = Chain.TheNightsVeil,
        },
        {
            type = "chain",
            id = Chain.DawnOfReckoning,
        },
        {
            type = "chain",
            id = Chain.TheVoidPeersBack,
        },
        {
            type = "chain",
            id = Chain.ShadowPuppets,
        },
        {
            type = "chain",
            id = Chain.TheNethersent,
        },
        {
            type = "chain",
            id = Chain.TheNightbreaker,
        },
        {
            type = "chain",
            id = Chain.PathogenicProblem,
        },
        {
            type = "chain",
            id = Chain.AVoiceInside,
        },
        {
            type = "chain",
            id = Chain.ShadowguardsShadow,
        },
        {
            type = "chain",
            id = Chain.AGiftGivenFreely,
        },
        {
            type = "chain",
            id = Chain.BreakingTheTriad,
        },
        {
            type = "chain",
            id = Chain.GoLowGoLoud,
        },
        {
            type = "chain",
            id = Chain.SecretsInTheDark,
        },
        {
            type = "chain",
            id = Chain.OathsToFamily,
        },
        {
            type = "chain",
            id = Chain.ToBeChanged,
        },
        {
            type = "chain",
            id = Chain.ADanceWithTheDevil,
        },
        {
            type = "chain",
            id = Chain.ADomanaarsBestFriend,
        },
        {
            type = "chain",
            id = Chain.AMorePotentFoe,
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

BtWQuestsDatabase:AddQuestItemsForChain(Chain.IntoTheAbyss)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheNightsVeil)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.DawnOfReckoning)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheVoidPeersBack)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.ShadowPuppets)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheNethersent)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheNightbreaker)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.PathogenicProblem)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.AVoiceInside)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.ShadowguardsShadow)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.AGiftGivenFreely)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.BreakingTheTriad)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.GoLowGoLoud)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.SecretsInTheDark)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.OathsToFamily)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.ToBeChanged)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.ADanceWithTheDevil)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.ADomanaarsBestFriend)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.AMorePotentFoe)
