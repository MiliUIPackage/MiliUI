local BtWQuests = BtWQuests
local Database = BtWQuests.Database
local EXPANSION_ID = BtWQuests.Constant.Expansions.Midnight
local CATEGORY_ID = BtWQuests.Constant.Category.Midnight.Harandar
local Chain = BtWQuests.Constant.Chain.Midnight.Harandar
local THREADS_OF_FATE_RESTRICTION = BtWQuests.Constant.Restrictions.MidnightToF
local NOT_THREADS_OF_FATE_RESTRICTION = BtWQuests.Constant.Restrictions.NotMidnightToF
local ALLIANCE_RESTRICTIONS, HORDE_RESTRICTIONS = 724, 723
local MAP_ID = 2413
local CONTINENT_ID = 2537
local ACHIEVEMENT_ID_1 = 41804
local ACHIEVEMENT_ID_2 = 61739
local LEVEL_RANGE = {70, 80}
local LEVEL_PREREQUISITES = {
    {
        type = "level",
        level = 70,
    },
}

Chain.OfCavesAndCradles = 120301
Chain.CallOfTheGoddess = 120302
Chain.Emergence = 120303
Chain.AGoblinInHarandar = 120311
Chain.TheLegendOfAlnsharan = 120312
Chain.LateBloomers = 120313
Chain.TheGreenspeakersVigil = 120314
Chain.PerilAmongPetals = 120315
Chain.HaranirNeverSayDie = 120316
Chain.HarandarsKitchen = 120317
Chain.SilenceAtFungaraVillage = 120318
Chain.CultivatingHope = 120319
Chain.HuntersRights = 120320
Chain.APaletteOfFeelings = 120321
Chain.PredatorReintroduction = 120322
Chain.Bloomtown = 120323
Chain.TheGrudgePit = 120324
Chain.TrialsOfTheShulka = 120325
Chain.OtherAlliance = 120397
Chain.OtherHorde = 120398
Chain.OtherBoth = 120399

Database:AddChain(Chain.OfCavesAndCradles, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 1),
    questline = 5725,
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
        id = 89402,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86944,
    },
    items = {
        { -- Harandar
            type = "quest",
            id = 89402,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Root Cause
            type = "quest",
            id = 86899,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- To Har'athir
            type = "quest",
            id = 86900,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Rift and the Den
            type = "quest",
            id = 86901,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Council Assembles
            type = "quest",
            id = 86929,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Den of Echoes
            type = "quest",
            id = 86907,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Echoes and Memories
            type = "quest",
            id = 86911,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Echo of the Hunt
            type = "quest",
            id = 90094,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Echo of the Call
            type = "quest",
            id = 90095,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Down the Rootways
            type = "quest",
            id = 86912,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Hut in Har'mara
            type = "quest",
            id = 86913,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Tending to Har'mara
            type = "quest",
            id = 86914,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- The Traveling Flowers
            type = "quest",
            id = 86956,
            connections = {
                1, 
            },
        },
        { -- Koozat's Trample
            type = "quest",
            id = 86910,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Burning Bitterblooms
            type = "quest",
            id = 89034,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Halting Harm in Har'mara
            type = "quest",
            id = 86973,
            connections = {
                2, 
            },
        },
        { -- Culling the Spread
            type = "quest",
            id = 86942,
            connections = {
                1, 
            },
        },
        { -- Seeds of the Rift
            type = "quest",
            id = 86944,
            x = 0,
        },
    }
})
Database:AddChain(Chain.CallOfTheGoddess, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 2),
    questline = 5726,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
        },
    },
    active = {
        type = "quest",
        id = 86930,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86890,
    },
    items = {
        {
            type = "npc",
            id = 237786,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- To Sow the Seed
            type = "quest",
            id = 86930,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Watch the Den
            type = "quest",
            id = 86864,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Hunter Awaits
            type = "quest",
            id = 86836,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Foundation of Aln
            type = "quest",
            id = 86851,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Consequences of Our Duty
            type = "quest",
            id = 86855,
            connections = {
                1, 
            },
        },
        { -- Dampening the Call
            type = "quest",
            id = 86856,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Descent into the Rift
            type = "quest",
            id = 86857,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Madness Roots Deep
            type = "quest",
            id = 86858,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Grinding Out a Solution
            type = "quest",
            id = 86859,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Before They Grow
            type = "quest",
            id = 86860,
            connections = {
                2, 
            },
        },
        { -- Herding Manifestations
            type = "quest",
            id = 86861,
            connections = {
                1, 
            },
        },
        { -- The Greater They Aln
            type = "quest",
            id = 86862,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- In Search of the Problem
            type = "quest",
            id = 86865,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Missing Rootwarden
            type = "quest",
            id = 94677,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Can We Heal This?
            type = "quest",
            id = 86866,
            connections = {
                1, 
            },
        },
        { -- Alndust in Right Hands
            type = "quest",
            id = 86882,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Into the Lightbloom
            type = "quest",
            id = 86867,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Righteous Pruning
            type = "quest",
            id = 86877,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Our Beloved, Returned
            type = "quest",
            id = 86880,
            connections = {
                2, 
            },
        },
        { -- At the Root
            type = "quest",
            id = 86881,
            connections = {
                1, 
            },
        },
        { -- Tell the People What You Have Seen
            type = "quest",
            id = 86890,
            x = 0,
        },
    }
})
Database:AddChain(Chain.Emergence, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 3),
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.CallOfTheGoddess,
        },
    },
    active = {
        type = "quest",
        id = 86883,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 86898,
    },
    items = {
        {
            type = "npc",
            id = 241742,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Frenzied March
            type = "quest",
            id = 86883,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Cull and Burn
            type = "quest",
            id = 86884,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Stem the Tides
            type = "quest",
            id = 86885,
            connections = {
                1, 2, 
            },
        },
        { -- Expeditious Retreat
            type = "quest",
            id = 86887,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- A Last Resort
            type = "quest",
            id = 86891,
            connections = {
                1, 
            },
        },
        { -- Survive
            type = "quest",
            id = 86892,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Gift of Aln'hara
            type = "quest",
            id = 86894,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Light Finds a Way
            type = "quest",
            id = 86896,
            connections = {
                1, 
            },
        },
        { -- Quelling the Frenzy
            type = "quest",
            id = 86897,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Rise of the Haranir
            type = "quest",
            id = 86898,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Blinding Vale: Lightbloom Roots
            type = "quest",
            id = 93651,
            aside = true,
            x = 0,
        },
    }
})
Database:AddChain(Chain.AGoblinInHarandar, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 1),
    questline = 5907,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.CallOfTheGoddess,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.Emergence,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 90533,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90535,
    },
    items = {
        {
            type = "npc",
            id = 242593,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Go Get Orweyna!
            type = "quest",
            id = 90533,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Home of the Haranir
            type = "quest",
            id = 90534,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Leave Your Mark
            type = "quest",
            id = 90535,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheLegendOfAlnsharan, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 2),
    questline = 5909,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            comment = "Or Renown 3?",
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        ids = {
            90467, 90468, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90474,
    },
    items = {
        {
            type = "npc",
            id = 242358,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Tales of the Sky
            type = "quest",
            id = 90467,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Ugh, Chores!
            type = "quest",
            id = 90468,
            connections = {
                1, 
            },
        },
        { -- Carry On, Wayward Kuri
            type = "quest",
            id = 90469,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Skyglass Scavenging
            type = "quest",
            id = 90470,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Legend of Aln'sharan
            type = "quest",
            id = 90474,
            x = 0,
        },
    }
})
Database:AddChain(Chain.LateBloomers, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 3),
    questline = 5935,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            comment = "Or Renown 3?",
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        id = 90537,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90602,
    },
    items = {
        {
            type = "npc",
            id = 242650,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Late Bloomers
            type = "quest",
            id = 90537,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        {
            type = "quest",
            id = 90540,
            x = -1,
            connections = {
                2, 
            },
        },
        {
            type = "quest",
            id = 90569,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 90963,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        {
            type = "quest",
            id = 90601,
            aside = true,
            x = -1,
        },
        {
            type = "quest",
            id = 90602,
        },
    }
})
Database:AddChain(Chain.TheGreenspeakersVigil, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 4),
    questline = 5952,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            comment = "Or Renown 3?",
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        id = 91346,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91361,
    },
    items = {
        {
            type = "npc",
            id = 246607,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Supplicants to the Goddess
            type = "quest",
            id = 91346,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Fungal Lashers B Gone
            type = "quest",
            id = 91359,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Weeding Out the Unwanted
            type = "quest",
            id = 91360,
            connections = {
                1, 
            },
        },
        { -- Back on Duty?
            type = "quest",
            id = 91361,
            x = 0,
        },
    }
})
Database:AddChain(Chain.PerilAmongPetals, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 5),
    questline = 5944,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            comment = "Or Renown 3?",
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        id = 91063,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91136,
    },
    items = {
        {
            type = "npc",
            id = 245637,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Blooming Lattice
            type = "quest",
            id = 91063,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Purloining Petals
            type = "quest",
            id = 91065,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Petal Bristles
            type = "quest",
            id = 91085,
            connections = {
                2, 
            },
        },
        { -- Nipping the Buds
            type = "quest",
            id = 91086,
            connections = {
                1, 
            },
        },
        { -- Behind the Falls
            type = "quest",
            id = 91088,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Memories in Stone
            type = "quest",
            id = 91136,
            x = 0,
        },
    }
})
Database:AddChain(Chain.HaranirNeverSayDie, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 6),
    questline = 5960,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            comment = "Or Renown 3?",
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        id = 91550,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91553,
    },
    items = {
        {
            type = "npc",
            id = 247640,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Game of Silence and Shadow
            type = "quest",
            id = 91550,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- De-nest-stration
            type = "quest",
            id = 91551,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Feathered Fury
            type = "quest",
            id = 91552,
            connections = {
                1, 
            },
        },
        { -- Haranir Never Say Die!
            type = "quest",
            id = 91553,
            x = 0,
        },
    }
})
Database:AddChain(Chain.HarandarsKitchen, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 7),
    questline = 5966,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            comment = "Or Renown 3?",
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        ids = {
            91585, 91586, 91587, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91589,
    },
    items = {
        {
            type = "npc",
            id = 247936,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Fresh from the Garden
            type = "quest",
            id = 91585,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Soil-Based Alternatives
            type = "quest",
            id = 91586,
            connections = {
                2, 
            },
        },
        { -- Carcass Cuisine
            type = "quest",
            id = 91587,
            connections = {
                1, 
            },
        },
        { -- Harandar's Kitchen
            type = "quest",
            id = 91588,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Root Dash Delivery
            type = "quest",
            id = 91589,
            x = 0,
        },
    }
})
Database:AddChain(Chain.SilenceAtFungaraVillage, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 8),
    questline = 6036,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.CallOfTheGoddess,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        ids = {
            91375, 91376, 91377, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91381,
    },
    items = {
        {
            variations = {
                { -- The Silence at Fungara Village
                    type = "quest",
                    id = 91375,
                    restrictions = { -- The Silence at Fungara Village
                        type = "quest",
                        id = 91375,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 246777,
                },
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Little Monsters
            type = "quest",
            id = 91376,
            x = -1,
            connections = {
                2, 3, 
            },
        },
        { -- Spawn of the Dead
            type = "quest",
            id = 91377,
            connections = {
                1, 2, 
            },
        },
        { -- You Are Legend
            type = "quest",
            id = 91378,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Decayed Land
            type = "quest",
            id = 91379,
            connections = {
                1, 
            },
        },
        { -- Reticent Evil
            type = "quest",
            id = 91381,
            x = 0,
        },
    }
})
Database:AddChain(Chain.CultivatingHope, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 9),
    questline = 5977,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.CallOfTheGoddess,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.Emergence,
        },
    },
    active = {
        type = "quest",
        id = 91872,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 91876,
    },
    items = {
        {
            type = "npc",
            id = 237572,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Former Rootwarden
            type = "quest",
            id = 91872,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Buffer Zone
            type = "quest",
            id = 91873,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Natural Remedy
            type = "quest",
            id = 91875,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Flare Up
            type = "quest",
            id = 91874,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Tending Hope
            type = "quest",
            id = 91876,
            x = 0,
        },
    }
})
Database:AddChain(Chain.HuntersRights, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 10),
    questline = 6039,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            comment = "Or Renown 3?",
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        id = 92882,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92885,
    },
    items = {
        {
            type = "npc",
            id = 253390,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Hunter's Plight
            type = "quest",
            id = 92882,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Hunter's Duty
            type = "quest",
            id = 92883,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Hunter's Weapon
            type = "quest",
            id = 92884,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Hunter's Prey
            type = "quest",
            id = 92885,
            x = 0,
        },
    }
})
Database:AddChain(Chain.APaletteOfFeelings, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 11),
    questline = 6038,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            comment = "Or Renown 3?",
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        id = 92694,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92697,
    },
    items = {
        {
            type = "npc",
            id = 252871,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Dusk Among Pigments
            type = "quest",
            id = 92694,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Stroke of Storms
            type = "quest",
            id = 92695,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Colors Born Anew
            type = "quest",
            id = 92696,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Hues of Tomorrow
            type = "quest",
            id = 92697,
            x = 0,
        },
    }
})
Database:AddChain(Chain.PredatorReintroduction, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 12),
    questline = 6040,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            comment = "Or Renown 3?",
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        ids = {
            92864, 92865, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92866,
    },
    items = {
        {
            type = "npc",
            id = 253312,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Drift Them Away
            type = "quest",
            id = 92864,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Feeding the Buds
            type = "quest",
            id = 92865,
            connections = {
                1, 
            },
        },
        { -- Re-Hydra-ted
            type = "quest",
            id = 92866,
            x = 0,
        },
    }
})
Database:AddChain(Chain.Bloomtown, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 13),
    questline = 6032,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.CallOfTheGoddess,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
        {
            type = "chain",
            id = BtWQuests.Constant.Chain.Midnight.Harandar.Emergence,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
        },
    },
    active = {
        type = "quest",
        id = 92732,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 92739,
    },
    items = {
        {
            type = "npc",
            id = 241629,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Light Disturbance
            type = "quest",
            id = 92732,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Light Stroll
            type = "quest",
            id = 92736,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Light Carnage
            type = "quest",
            id = 92737,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Potatoad Tots
            type = "quest",
            id = 92738,
            connections = {
                1, 
            },
        },
        { -- O.K. Bloomer
            type = "quest",
            id = 92739,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TheGrudgePit, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 14),
    questline = 5910,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.OfCavesAndCradles,
            restrictions = NOT_THREADS_OF_FATE_RESTRICTION,
            comment = "Or Renown 3?",
            upto = 86930,
        },
    },
    active = {
        type = "quest",
        ids = {
            90615, 90616, 
        },
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90622,
    },
    items = {
        {
            variations = {
                { -- Be Grudge You
                    type = "quest",
                    id = 90615,
                    restrictions = { -- Be Grudge You
                        type = "quest",
                        id = 90615,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 243226,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- You Strong?
            type = "quest",
            id = 90616,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Few Fun Guys
            type = "quest",
            id = 90617,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- What Doesn't Kill Them
            type = "quest",
            id = 90619,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- We Ready Now
            type = "quest",
            id = 91450,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Most Important Thing
            type = "quest",
            id = 91270,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- To the Ring
            type = "quest",
            id = 90620,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Tiny Heroes' Journeys
            type = "quest",
            id = 90621,
            completed = { -- Tiny Heroes' Journeys
                type = "quest",
                id = 90621,
                status = { "active", "completed", },
            },
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Mushrooming Courage
            type = "quest",
            id = 92616,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Mushrooming Resilience
            type = "quest",
            id = 92617,
            connections = {
                2, 
            },
        },
        { -- Mushrooming Confidence
            type = "quest",
            id = 92618,
            connections = {
                1, 
            },
        },
        { -- Tiny Heroes' Journeys
            type = "quest",
            id = 90621,
            active = {
                type = "quest",
                ids = {
                    92616, 92617, 92618, 
                },
                count = 3,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Not-Yet Defeated Champions
            type = "quest",
            id = 90622,
            x = 0,
        },
    }
})
Database:AddChain(Chain.TrialsOfTheShulka, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_2, 15),
    questline = 5932,
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
            id = BtWQuests.Constant.Chain.Midnight.Harandar.CallOfTheGoddess,
        },
    },
    active = {
        type = "quest",
        id = 90824,
        status = { "active", "completed", },
    },
    completed = {
        type = "quest",
        id = 90834,
    },
    items = {
        {
            type = "npc",
            id = 244163,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- My Brother's Alive!
            type = "quest",
            id = 90824,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Healing Waters of Ahl'ua
            type = "quest",
            id = 90826,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Only the Poisonous Parts
            type = "quest",
            id = 90827,
            connections = {
                1, 
            },
        },
        { -- Meeting My Mentor
            type = "quest",
            id = 90829,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Path Will Reveal Itself
            type = "quest",
            id = 90830,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Doing Is Becoming
            type = "quest",
            id = 90831,
            connections = {
                1, 
            },
        },
        { -- As Her Voice Goes Silent
            type = "quest",
            id = 90832,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Final Rite
            type = "quest",
            id = 90833,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- From This Point Forward
            type = "quest",
            id = 90834,
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
        { -- Culling the Light
            type = "quest",
            id = 86874,
        },
        { -- Renowned with the Hara'ti
            type = "quest",
            id = 89035,
        },
        { -- Renowned with the Amani Tribe
            type = "quest",
            id = 93566,
        },
    },
})

Database:AddCategory(CATEGORY_ID, {
    name = BtWQuests.GetMapName(MAP_ID),
    expansion = EXPANSION_ID,
    items = {
        {
            type = "chain",
            id = Chain.OfCavesAndCradles,
        },
        {
            type = "chain",
            id = Chain.CallOfTheGoddess,
        },
        {
            type = "chain",
            id = Chain.Emergence,
        },
        {
            type = "chain",
            id = Chain.AGoblinInHarandar,
        },
        {
            type = "chain",
            id = Chain.TheLegendOfAlnsharan,
        },
        {
            type = "chain",
            id = Chain.LateBloomers,
        },
        {
            type = "chain",
            id = Chain.TheGreenspeakersVigil,
        },
        {
            type = "chain",
            id = Chain.PerilAmongPetals,
        },
        {
            type = "chain",
            id = Chain.HaranirNeverSayDie,
        },
        {
            type = "chain",
            id = Chain.HarandarsKitchen,
        },
        {
            type = "chain",
            id = Chain.SilenceAtFungaraVillage,
        },
        {
            type = "chain",
            id = Chain.CultivatingHope,
        },
        {
            type = "chain",
            id = Chain.HuntersRights,
        },
        {
            type = "chain",
            id = Chain.APaletteOfFeelings,
        },
        {
            type = "chain",
            id = Chain.PredatorReintroduction,
        },
        {
            type = "chain",
            id = Chain.Bloomtown,
        },
        {
            type = "chain",
            id = Chain.TheGrudgePit,
        },
        {
            type = "chain",
            id = Chain.TrialsOfTheShulka,
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

BtWQuestsDatabase:AddQuestItemsForChain(Chain.OfCavesAndCradles)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.CallOfTheGoddess)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.Emergence)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.AGoblinInHarandar)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheLegendOfAlnsharan)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.LateBloomers)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheGreenspeakersVigil)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.PerilAmongPetals)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.HaranirNeverSayDie)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.HarandarsKitchen)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.SilenceAtFungaraVillage)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.CultivatingHope)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.HuntersRights)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.APaletteOfFeelings)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.PredatorReintroduction)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.Bloomtown)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheGrudgePit)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.TrialsOfTheShulka)
