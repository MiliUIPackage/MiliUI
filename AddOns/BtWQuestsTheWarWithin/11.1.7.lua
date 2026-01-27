if select(4, GetBuildInfo()) < 110107  then
    return
end

local BtWQuests = BtWQuests
local Database = BtWQuests.Database
local L = BtWQuests.L
local EXPANSION_ID = BtWQuests.Constant.Expansions.TheWarWithin
local Chain = BtWQuests.Constant.Chain.TheWarWithin
local LEVEL_RANGE = {80, 80}

Chain.RiseOfTheRedDawn = 110010
Chain.ArcaneDesolation = 110011
Chain.StrengthAmidstRuins = 110012

Database:AddChain(Chain.RiseOfTheRedDawn, {
    name = { -- Rise of the Red Dawn
        type = "quest",
        id = 84717,
    },
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    questline = 5684,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
    },
    active = {
        type = "quest",
        ids = { 91039, 84638, },
        status = {'active', 'completed'}
    },
    completed = {
        type = "quest",
        id = 85529,
    },
    items = {
        {
            variations = {
                {
                    type = "quest",
                    id = 91039,
                    restrictions = {
                        type = "quest",
                        id = 91039,
                        status = { "active", "completed", },
                    },
                },
                {
                    type = "npc",
                    id = 223875,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84638,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        {
            type = "quest",
            id = 84639,
            x = -2,
            connections = {
                3, 
            },
        },
        {
            type = "quest",
            id = 84658,
            connections = {
                2, 
            },
        },
        {
            type = "quest",
            id = 84640,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84641,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        {
            type = "quest",
            id = 84643,
            x = -1,
            connections = {
                2, 
            },
        },
        {
            type = "quest",
            id = 84645,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84649,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84650,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        {
            type = "quest",
            id = 84651,
            x = -1,
            connections = {
                2, 
            },
        },
        {
            type = "quest",
            id = 84652,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84656,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84704,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84707,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        {
            type = "quest",
            id = 84705,
            x = -1,
            connections = {
                2, 
            },
        },
        {
            type = "quest",
            id = 84706,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84708,
            x = 0,
            connections = {
                1, 2, 3, 
            },
        },
        {
            type = "quest",
            id = 84709,
            x = -2,
            connections = {
                3, 
            },
        },
        {
            type = "quest",
            id = 84710,
            connections = {
                2, 
            },
        },
        {
            type = "quest",
            id = 85451,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84711,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84712,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            variations = {
                {
                    type = "quest",
                    id = 84713,
                    restrictions = 923,
                },
                {
                    type = "quest",
                    id = 84657,
                },
            },
            x = 0,
            connections = {
                1, 2, 
            },
        },
        {
            variations = {
                {
                    type = "quest",
                    id = 84715,
                    restrictions = 923,
                    connections = {
                        2, 
                    },
                },
                {
                    type = "quest",
                    id = 84659,
                    connections = {
                        3, 
                    },
                },
            },
            x = -1,
        },
        {
            variations = {
                {
                    type = "quest",
                    id = 84714,
                    restrictions = 923,
                    connections = {
                        1, 
                    },
                },
                {
                    type = "quest",
                    id = 87299,
                    connections = {
                        2, 
                    },
                },
            },
        },
        {
            type = "quest",
            id = 84716,
            restrictions = 923,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 84717,
            x = 0,
            connections = {
                1, 
            },
        },
        {
            type = "quest",
            id = 85529,
            x = 0,
        },
    }
})
Database:AddChain(Chain.ArcaneDesolation, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(40791, 1), -- Arcane Desolation
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    questline = 5664,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
    },
    active = {
        type = "quest",
        id = 84223,
        status = {'active', 'completed'}
    },
    completed = {
        type = "quest",
        id = 83643,
    },
    items = {
        {
            type = "npc",
            id = 227436,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Survivor's Guilt
            type = "quest",
            id = 84223,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Hardest Part
            type = "quest",
            id = 83031,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Arcane Wasteland
            type = "quest",
            id = 83499,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Lessons in Defensive Magic
            type = "quest",
            id = 83502,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Feeling Blue
            type = "quest",
            id = 83539,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Magic-stealing Kobolds
            type = "quest",
            id = 83553,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Trinkets, Curios and Other Powerful Objects
            type = "quest",
            id = 83554,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Mysterious Necklace
            type = "quest",
            id = 83555,
            connections = {
                1, 
            },
        },
        { -- Maybe You Shouldn't Touch That
            type = "quest",
            id = 83556,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Trapped Between Life and Death
            type = "quest",
            id = 83641,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Somehow We Survived
            type = "quest",
            id = 83643,
            x = 0,
        },
    }
})
Database:AddChain(Chain.StrengthAmidstRuins, {
    name = BtWQuests_GetAchievementCriteriaNameDelayed(40791, 2), -- Strength Amidst Ruins
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    questline = 5666,
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            type = "chain",
            id = Chain.ArcaneDesolation,
        }
    },
    active = {
        type = "quest",
        id = 83723,
        status = {'active', 'completed'}
    },
    completed = {
        type = "quest",
        id = 83773,
    },
    items = {
        {
            type = "npc",
            id = 212829,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- A Helping Hand
            type = "quest",
            id = 83723,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Arcane Cold War
            type = "quest",
            id = 83743,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Critical Mass
            type = "quest",
            id = 83762,
            x = 0,
            connections = {
                1, 2, 
            },
        },
        { -- Preserve the Legacy
            type = "quest",
            id = 83763,
            x = -1,
            connections = {
                2, 
            },
        },
        { -- Too Powerful, Too Dangerous
            type = "quest",
            id = 83764,
            connections = {
                1, 
            },
        },
        { -- Farewell, City of Magic
            type = "quest",
            id = 83773,
            x = 0,
        },
    }
})

BtWQuestsDatabase:AddExpansionItems(EXPANSION_ID, {
    {
        type = "chain",
        id = Chain.RiseOfTheRedDawn,
    },
    {
        type = "chain",
        id = Chain.ArcaneDesolation,
    },
    {
        type = "chain",
        id = Chain.StrengthAmidstRuins,
    },
})

BtWQuestsDatabase:AddQuestItemsForChain(Chain.RiseOfTheRedDawn)
BtWQuestsDatabase:AddQuestItemsForChain(Chain.ArcaneDesolation)
