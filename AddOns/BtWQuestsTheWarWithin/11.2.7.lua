if select(4, GetBuildInfo()) < 110207  then
    return
end

local BtWQuests = BtWQuests
local Database = BtWQuests.Database
local L = BtWQuests.L
local EXPANSION_ID = BtWQuests.Constant.Expansions.TheWarWithin
local Chain = BtWQuests.Constant.Chain.TheWarWithin.TheWarning
local CATEGORY_ID_1 = BtWQuests.Constant.Category.TheWarWithin.VisionsOfAShadowedSun
local ACHIEVEMENT_ID_1 = 42299 -- "Visions of a Shadowed Sun"
local CATEGORY_ID_2 = BtWQuests.Constant.Category.TheWarWithin.Lorewalking

local LEVEL_RANGE = {80, 80}

Chain.RadiantVisions = 110801
Chain.AMeetingwithMinnda = 110802
Chain.PathsForward = 110803
Chain.LorewalkingBladesBane = 110810
Chain.LorewalkingTheLichKing = 110811
Chain.LorewalkingEtherealWisdom = 110812
Chain.LorewalkingTheElvesOfQuelthalas = 110813
Chain.TheWarWithinRecap = 110820

Database:AddChain(Chain.RadiantVisions, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 1),
    questline = 5707,
    expansion = EXPANSION_ID,
    category = CATEGORY_ID_1,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
    },
    active = {
        type = "quest",
        id = 92405,
        status = {'active', 'completed'}
    },
    completed = {
        type = "quest",
        id = 85002,
    },
    items = {
        {
            type = "npc",
            id = 250839,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Meet Arator
            type = "quest",
            id = 92405,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Vereesa's Tale
            type = "quest",
            id = 84996,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- What Might Come
            type = "quest",
            id = 84997,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Bringer of the Void
            type = "quest",
            id = 84998,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Blessings Be Upon You
            type = "quest",
            id = 85001,
            connections = {
                1, 
            },
        },
        { -- Off to Tazavesh
            type = "quest",
            id = 85002,
            x = 0,
        },
    }
})
Database:AddChain(Chain.AMeetingwithMinnda, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 2),
    questline = 5708,
    expansion = EXPANSION_ID,
    category = CATEGORY_ID_1,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = Chain.RadiantVisions,
        },
    },
    active = {
        type = "quest",
        id = 85011,
        status = {'active', 'completed'}
    },
    completed = {
        type = "quest",
        id = 85214,
    },
    items = {
        {
            type = "npc",
            id = 231266,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Where in K'aresh is Alleria Windrunner?
            type = "quest",
            id = 85011,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Parent Trap
            type = "quest",
            id = 85804,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- In Her Shadow
            type = "quest",
            id = 85151,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Do You Have a Spare?
            type = "quest",
            id = 85155,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Repossession is Nine-Tenths of the Law
            type = "quest",
            id = 85184,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Those As Well
            type = "quest",
            id = 85185,
            connections = {
                1, 
            },
        },
        { -- A Cage for Alleria
            type = "quest",
            id = 85186,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Tag, You're It
            type = "quest",
            id = 85196,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Void Test of Wills
            type = "quest",
            id = 85212,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Off to Tazavesh, Again
            type = "quest",
            id = 85213,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Here Goes Something
            type = "quest",
            id = 85214,
            x = 0,
        },
    }
})
Database:AddChain(Chain.PathsForward, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(ACHIEVEMENT_ID_1, 3),
    questline = 5706,
    expansion = EXPANSION_ID,
    category = CATEGORY_ID_1,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = Chain.RadiantVisions,
            lowPriority = true,
        },
        {
            type = "chain",
            id = Chain.AMeetingwithMinnda,
        },
    },
    active = {
        type = "quest",
        id = 84935,
        status = {'active', 'completed'}
    },
    completed = {
        type = "quest",
        id = 84949,
    },
    items = {
        {
            type = "npc",
            id = 231030,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Excising the Incursion
            type = "quest",
            id = 84935,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- To Cleanse Shadow's Stain
            type = "quest",
            id = 84936,
            connections = {
                1, 
            },
        },
        { -- Distant Echoes
            type = "quest",
            id = 84937,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Chaos Control
            type = "quest",
            id = 84938,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Mad Space
            type = "quest",
            id = 84939,
            connections = {
                1, 
            },
        },
        { -- The Final Hazard
            type = "quest",
            id = 84942,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- The Long Vigil
            type = "quest",
            id = 84943,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Preludes and Preparations
            type = "quest",
            id = 84944,
            connections = {
                1, 
            },
        },
        { -- Repent of the Highborne
            type = "quest",
            id = 84945,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Determination
            type = "quest",
            id = 84947,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Returning to Life
            type = "quest",
            id = 84946,
            connections = {
                1, 
            },
        },
        { -- The Eleventh Hour
            type = "quest",
            id = 84949,
            x = 0,
        },
    }
})

Database:AddCategory(CATEGORY_ID_1, {
    name = BtWQuests_GetAchievementName(ACHIEVEMENT_ID_1),
    expansion = EXPANSION_ID,
    items = {
        {
            type = "chain",
            id = Chain.RadiantVisions,
        },
        {
            type = "chain",
            id = Chain.AMeetingwithMinnda,
        },
        {
            type = "chain",
            id = Chain.PathsForward,
        },
    },
})


Database:AddChain(Chain.LorewalkingBladesBane, {
    name = BtWQuests_GetAchievementName(42188), -- Lorewalking: Blade's Bane
    expansion = EXPANSION_ID,
    category = CATEGORY_ID_2,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
    },
    active = {
        type = "quest",
        id = 84371,
        status = {'active', 'completed'}
    },
    completed = {
        type = "achievement",
        id = 42188,
    },
    items = {
        {
            type = "npc",
            id = 230246,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Blade and the High Priest
            type = "quest",
            id = 84371,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Blade's Gambit
            type = "quest",
            id = 84779,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Blade's Past
            type = "quest",
            id = 84782,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Lorewalking: The Blade's Forces
            type = "quest",
            id = 85871,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Lorewalking: The Blade's Nemeses
            type = "quest",
            id = 84784,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Blade's Downfall
            type = "quest",
            id = 84789,
            x = 0,
        },
    }
})
Database:AddChain(Chain.LorewalkingTheLichKing, {
    name = BtWQuests_GetAchievementName(42189), -- Lorewalking: The Lich King
    expansion = EXPANSION_ID,
    category = CATEGORY_ID_2,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
    },
    active = {
        type = "quest",
        id = 85884,
        status = {'active', 'completed'}
    },
    completed = {
        type = "achievement",
        id = 42189,
    },
    items = {
        {
            type = "npc",
            id = 230246,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Prince Who Would Be King
            type = "quest",
            id = 85884,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Prince's Duty
            type = "quest",
            id = 85862,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Prince Who Would Be King
            type = "quest",
            id = 85884,
            breadcrumb = true,
            active = { -- A Prince's Duty
                type = "quest",
                id = 85862,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Forgotten Tale
            type = "quest",
            id = 12291,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Truth Shall Set Us Free
            type = "quest",
            id = 12301,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Parting Thoughts
            type = "quest",
            id = 12305,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Frostmourne Cavern
            type = "quest",
            id = 12478,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Prince Who Would Be King
            type = "quest",
            id = 85884,
            breadcrumb = true,
            active = { -- Frostmourne Cavern
                type = "quest",
                id = 12478,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: No King Rules Forever
            type = "quest",
            id = 85885,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Ascent of the Lich King
            type = "quest",
            id = 85875,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: No King Rules Forever
            type = "quest",
            id = 85885,
            breadcrumb = true,
            active = { -- Ascent of the Lich King
                type = "quest",
                id = 85875,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- O' Thanagor
            type = "quest",
            id = 85878,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: No King Rules Forever
            type = "quest",
            id = 85885,
            active = { -- O' Thanagor
                type = "quest",
                id = 85878,
            },
            x = 0,
        },
    }
})
Database:AddChain(Chain.LorewalkingEtherealWisdom, {
    name = BtWQuests_GetAchievementName(42187), -- Lorewalking: Ethereal Wisdom
    expansion = EXPANSION_ID,
    category = CATEGORY_ID_2,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
    },
    active = {
        type = "quest",
        id = 85027,
        status = {'active', 'completed'}
    },
    completed = {
        type = "achievement",
        id = 42187,
    },
    items = {
        {
            type = "npc",
            id = 230246,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Protectorate
            type = "quest",
            id = 85027,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Ethereum
            type = "quest",
            id = 10339,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Ethereum Data
            type = "quest",
            id = 10384,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Potential for Brain Damage = High
            type = "quest",
            id = 10385,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Delivering the Message
            type = "quest",
            id = 10406,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Nexus-King Salhadaar
            type = "quest",
            id = 10408,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Protectorate
            type = "quest",
            id = 85027,
            breadcrumb = true,
            active = { -- Nexus-King Salhadaar
                type = "quest",
                id = 10408,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recipe for Destruction
            type = "quest",
            id = 10437,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Dimensius the All-Devouring
            type = "quest",
            id = 10439,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Protectorate
            type = "quest",
            id = 85027,
            active = { -- Dimensius the All-Devouring
                type = "quest",
                id = 10439,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: Locus-Walker
            type = "quest",
            id = 85029,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Throwing Shade
            type = "quest",
            id = 47203,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Sources of Darkness
            type = "quest",
            id = 47217,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- The Shadowguard Incursion
            type = "quest",
            id = 47218,
            connections = {
                1, 
            },
        },
        { -- A Vessel Made Ready
            type = "quest",
            id = 47219,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: Locus-Walker
            type = "quest",
            id = 85029,
            active = { -- A Vessel Made Ready
                type = "quest",
                id = 47219,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Brokers
            type = "quest",
            id = 85028,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Al'ley Cat of Oribos
            type = "quest",
            id = 63976,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Insider Trading
            type = "quest",
            id = 63977,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Things Best Kept Dark
            type = "quest",
            id = 63979,
            connections = {
                1, 
            },
        },
        { -- Seeking Smugglers
            type = "quest",
            id = 63980,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Above My Station
            type = "quest",
            id = 63982,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Dead Drop
            type = "quest",
            id = 63983,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Coins for the Ferryman
            type = "quest",
            id = 63984,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Veiled Market
            type = "quest",
            id = 63985,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Brokers
            type = "quest",
            id = 85028,
            breadcrumb = true,
            active = { -- The Veiled Market
                type = "quest",
                id = 63985,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Ease of Passage
            type = "quest",
            id = 63855,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Grab Bag
            type = "quest",
            id = 63895,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: The Brokers
            type = "quest",
            id = 85028,
            active = { -- Grab Bag
                type = "quest",
                id = 63895,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Locus-Walker, Telogrus Ranger
            type = "quest",
            id = 85035,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Veni Vidi Ve'nari
            type = "quest",
            id = 85036,
            x = 0,
        },
    }
})
Database:AddChain(Chain.LorewalkingTheElvesOfQuelthalas, {
    name = BtWQuests_GetAchievementName(61467), -- Lorewalking: The Elves of Quel'thalas
    expansion = EXPANSION_ID,
    category = CATEGORY_ID_2,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
    },
    active = {
        type = "quest",
        id = 85252,
        status = {'active', 'completed'}
    },
    completed = {
        type = "achievement",
        id = 61467,
    },
    items = {
        {
            type = "npc",
            id = 230246,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: Children of the Blood
            type = "quest",
            id = 85252,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Writing on the Wall
            type = "quest",
            id = 53882,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The First to Fall
            type = "quest",
            id = 53735,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Day Hope Died
            type = "quest",
            id = 53737,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Fall of the Sunwell
            type = "quest",
            id = 54096,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: Children of the Blood
            type = "quest",
            id = 85252,
            breadcrumb = true,
            active = { -- The Fall of the Sunwell
                type = "quest",
                id = 54096,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: Children of the Void
            type = "quest",
            id = 85254,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Remember the Sunwell
            type = "quest",
            id = 49354,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: Children of the Void
            type = "quest",
            id = 85254,
            breadcrumb = true,
            active = { -- Remember the Sunwell
                type = "quest",
                id = 49354,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Ghostlands
            type = "quest",
            id = 49787,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Telogrus Rift
            type = "quest",
            id = 48962,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lorewalking: Children of the Void
            type = "quest",
            id = 85254,
            breadcrumb = true,
            active = { -- Telogrus Rift
                type = "quest",
                id = 48962,
            },
            x = 0,
        },
    }
})

Database:AddCategory(CATEGORY_ID_2, {
    name = { -- Lorewalking
        type = "quest",
        id = 90705,
    },
    expansion = EXPANSION_ID,
    items = {
        {
            type = "chain",
            id = Chain.LorewalkingBladesBane,
        },
        {
            type = "chain",
            id = Chain.LorewalkingTheLichKing,
        },
        {
            type = "chain",
            id = Chain.LorewalkingEtherealWisdom,
        },
        {
            type = "chain",
            id = Chain.LorewalkingTheElvesOfQuelthalas,
        },
    },
})

Database:AddChain(Chain.TheWarWithinRecap, {
    name = "The War Within Recap",
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
        id = 91843,
        status = {'active', 'completed'}
    },
    completed = {
        type = "achievement",
        id = 61467,
    },
    items = {
        {
            type = "npc",
            id = 248948,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: The Harbinger
            type = "quest",
            id = 91843,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Fractured Visions
            type = "quest",
            id = 91864,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Breach
            type = "quest",
            id = 79105,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Rupture
            type = "quest",
            id = 79106,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Departure
            type = "quest",
            id = 80321,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Violent Impact
            type = "quest",
            id = 78529,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        {
            type = "npc",
            id = 211993,
            x = -2,
            connections = {
                3, 
            },
        },
        {
            variations = {
                { -- Isle of Dorn
                    type = "quest",
                    id = 83548,
                    restrictions = { -- Isle of Dorn
                        type = "quest",
                        id = 83548,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 211994,
                },
            },
            connections = {
                3, 
            },
        },
        {
            variations = {
                { -- Shattered Spires
                    type = "quest",
                    id = 80334,
                    restrictions = { -- Shattered Spires
                        type = "quest",
                        id = 80334,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 223166,
                },
            },
            connections = {
                3, 
            },
        },
        { -- Urgent Recovery
            type = "quest",
            id = 78531,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Slay the Saboteurs
            type = "quest",
            id = 78530,
            connections = {
                2, 
            },
        },
        { -- Erratic Artifacts
            type = "quest",
            id = 78532,
            connections = {
                1, 
            },
        },
        { -- Secure the Beach
            type = "quest",
            id = 78533,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Fractured Visions
            type = "quest",
            id = 91864,
            breadcrumb = true,
            active = { -- Secure the Beach
                type = "quest",
                id = 78533,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- State of the Union
            type = "quest",
            id = 78459,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Fourth Seat
            type = "quest",
            id = 78461,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Echoes of Compassion
            type = "quest",
            id = 78462,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Fractured Visions
            type = "quest",
            id = 91864,
            breadcrumb = true,
            active = { -- Echoes of Compassion
                type = "quest",
                id = 78462,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Calling the Stormriders
            type = "quest",
            id = 80022,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Fractured Visions
            type = "quest",
            id = 91864,
            breadcrumb = true,
            active = { -- Calling the Stormriders
                type = "quest",
                id = 80022,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Bring the Thunder
            type = "quest",
            id = 78544,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Return to the Coreway
            type = "quest",
            id = 78545,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recompense
            type = "quest",
            id = 78546,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Into the Deeps
            type = "quest",
            id = 80434,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Pomp and Dire Circumstance
            type = "quest",
            id = 78837,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Fractured Visions
            type = "quest",
            id = 91864,
            breadcrumb = true,
            active = { -- Pomp and Dire Circumstance
                type = "quest",
                id = 78837,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Find the Foreman
            type = "quest",
            id = 78704,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- What She Saw
            type = "quest",
            id = 78705,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The High Speaker's Secret
            type = "quest",
            id = 78706,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Fractured Visions
            type = "quest",
            id = 91864,
            breadcrumb = true,
            active = { -- The High Speaker's Secret
                type = "quest",
                id = 78706,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Into the Machine
            type = "quest",
            id = 78761,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Fractured Visions
            type = "quest",
            id = 91864,
            breadcrumb = true,
            active = { -- Into the Machine
                type = "quest",
                id = 78761,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Hallowed Path
            type = "quest",
            id = 78658,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Where the Light Touches
            type = "quest",
            id = 78659,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            active = { -- Where the Light Touches
                type = "quest",
                id = 78659,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Light of the Dawntower
            type = "quest",
            id = 78671,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            active = { -- The Light of the Dawntower
                type = "quest",
                id = 78671,
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Crossroads of Twilight
            type = "quest",
            id = 78620,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- The Shadow Rising
            type = "quest",
            id = 78621,
            connections = {
                1, 
            },
        },
        { -- A Candle in the Dark
            type = "quest",
            id = 78624,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            active = { -- A Candle in the Dark
                type = "quest",
                id = 78624,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Rise of the Reckoning
            type = "quest",
            id = 78630,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            active = { -- The Rise of the Reckoning
                type = "quest",
                id = 78630,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Friends in Low Places
            type = "quest",
            id = 78348,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Fear the Old Blood
            type = "quest",
            id = 78353,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- For Naught, So Vial
            type = "quest",
            id = 78352,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            active = {
                type = "quest",
                ids = {
                    78353, 78352, 
                },
                count = 2,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Most Intriguing Invitation
            type = "quest",
            id = 78226,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Into a Skittering City
            type = "quest",
            id = 78228,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            active = { -- Into a Skittering City
                type = "quest",
                id = 78228,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Kaheti Hospitality
            type = "quest",
            id = 78244,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            active = { -- Kaheti Hospitality
                type = "quest",
                id = 78244,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Edicts
            type = "quest",
            id = 79156,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            active = { -- The Edicts
                type = "quest",
                id = 79156,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Light in the Dark
            type = "quest",
            id = 78948,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Return to Dornogal
            type = "quest",
            id = 83503,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: Shadowy Pursuits
            type = "quest",
            id = 91868,
            breadcrumb = true,
            active = { -- Return to Dornogal
                type = "quest",
                id = 83503,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: The Dark Heart
            type = "quest",
            id = 91871,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Ethereal Invasion
            type = "quest",
            id = 83126,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Phase Shift
            type = "quest",
            id = 85449,
            connections = {
                1, 
            },
        },
        { -- Evacuation Plan
            type = "quest",
            id = 85450,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Racing the Clock
            type = "quest",
            id = 83127,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Get Our People Out
            type = "quest",
            id = 83128,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Nowhere Left to Hide
            type = "quest",
            id = 83129,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: The Dark Heart
            type = "quest",
            id = 91871,
            breadcrumb = true,
            active = { -- Nowhere Left to Hide
                type = "quest",
                id = 83129,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Shadowguard Shattered
            type = "quest",
            id = 84967,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lingering Memories
            type = "quest",
            id = 93979,
            breadcrumb = true,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: The Dark Heart
            type = "quest",
            id = 91871,
            breadcrumb = true,
            active = { -- Lingering Memories
                type = "quest",
                id = 93979,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Reshii Ribbon
            type = "quest",
            id = 86495,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Where the Void Gathers
            type = "quest",
            id = 84856,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Eco-Dome: Primus
            type = "quest",
            id = 84857,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: The Dark Heart
            type = "quest",
            id = 91871,
            breadcrumb = true,
            active = { -- Eco-Dome: Primus
                type = "quest",
                id = 84857,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Void Alliance
            type = "quest",
            id = 84862,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        { -- Her Dark Side
            type = "quest",
            id = 84864,
            x = -2,
            connections = {
                3, 
            },
        },
        { -- Divide and Conquer
            type = "quest",
            id = 84865,
            connections = {
                2, 
            },
        },
        { -- Counter Measures
            type = "quest",
            id = 84863,
            connections = {
                1, 
            },
        },
        { -- To Purchase Safety
            type = "quest",
            id = 84866,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Unwrapped and Unraveled
            type = "quest",
            id = 86946,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- My Part of the Deal
            type = "quest",
            id = 90517,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: The Dark Heart
            type = "quest",
            id = 91871,
            breadcrumb = true,
            active = { -- My Part of the Deal
                type = "quest",
                id = 90517,
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- That's a Wrap
            type = "quest",
            id = 85037,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Manaforge Omega: Dimensius Looms
            type = "quest",
            id = 86820,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Recap: The Dark Heart
            type = "quest",
            id = 91871,
            active = { -- Manaforge Omega: Dimensius Looms
                type = "quest",
                id = 86820,
            },
            x = 0,
        },
    }
})

BtWQuestsDatabase:AddExpansionItems(EXPANSION_ID, {
    {
        type = "category",
        id = CATEGORY_ID_1,
    },
    {
        type = "category",
        id = CATEGORY_ID_2,
    }
})

BtWQuestsDatabase:AddQuestItemsForChain(Chain.RadiantVisions)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.AMeetingwithMinnda)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.PathsForward)

-- BtWQuestsDatabase:AddQuestItemsForChain(Chain.LorewalkingBladesBane)
-- BtWQuestsDatabase:AddQuestItemsForChain(Chain.LorewalkingTheLichKing)
-- BtWQuestsDatabase:AddQuestItemsForChain(Chain.LorewalkingEtherealWisdom)
-- BtWQuestsDatabase:AddQuestItemsForChain(Chain.LorewalkingTheElvesOfQuelthalas)

-- BtWQuestsDatabase:AddQuestItemsForChain(Chain.TheWarWithinRecap)
