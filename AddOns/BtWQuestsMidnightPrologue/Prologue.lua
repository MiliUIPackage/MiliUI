local BtWQuests = BtWQuests
local Database = BtWQuests.Database
local EXPANSION_ID = BtWQuests.Constant.Expansions.Midnight
local Category = BtWQuests.Constant.Category.Midnight
local Chain = BtWQuests.Constant.Chain.Midnight
local ALLIANCE_RESTRICTIONS, HORDE_RESTRICTIONS = 924, 923
local LEVEL_RANGE = {80, 90}

Chain.TheCultWithin = 120001
Chain.RageOfTheRendorei = 120010

Database:AddChain(Chain.TheCultWithin, {
    name = { -- The Cult Within
        type = "quest",
        id = 90764,
    },
    questline = 5930,
    expansion = EXPANSION_ID,
    range = LEVEL_RANGE,
    prerequisites = {
        {
            type = "level",
            level = 10,
        },
    },
    active = {
        type = "quest",
        ids = { 90764, 90759 },
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 90768,
    },
    items = {
        {
            variations = {
                { -- The Cult Within
                    type = "quest",
                    id = 90764,
                    restrictions = 923,
                },
                { -- The Cult Within
                    type = "quest",
                    id = 90759,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        {
            variations = {
                { -- Avoiding Blame
                    type = "quest",
                    id = 90761,
                    restrictions = 923,
                },
                { -- Avoiding Blame
                    type = "quest",
                    id = 90760,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        {
            variations = {
                { -- The Twilight Highlands
                    type = "quest",
                    id = 90763,
                    restrictions = 923,
                },
                { -- The Twilight Highlands
                    type = "quest",
                    id = 90762,
                },
            },
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Midnight Dress
            type = "quest",
            id = 90765,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Xal'atath's Proven Faithful
            type = "quest",
            id = 90766,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- More Doom
            type = "quest",
            id = 90767,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Cult It Out
            type = "quest",
            id = 90768,
            x = 0,
        },
    },
})
Database:AddChain(Chain.RageOfTheRendorei, {
    name = { -- Rage of the Ren'dorei
        type = "achievement",
        id = 61916,
    },
    questline = 6043,
    expansion = EXPANSION_ID,
    range = { 80, 90 },
    prerequisites = {
        {
            type = "level",
            level = 80,
        },
        {
            name = BtWQuests_GetAchievementCriteriaNameDelayed(42739, 3),
            type = "chain",
            id = 110713,
            completed = {
                type = "achievement",
                id = 42739,
                criteria = 3,
            },
        },
    },
    active = {
        type = "quest",
        id = 92630,
        status = {'active', 'completed'},
    },
    completed = {
        type = "quest",
        id = 92632,
    },
    items = {
        {
            type = "npc",
            id = 248153,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- The Pursuit Continues
            type = "quest",
            id = 92630,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Abhorrent Gauntlet
            type = "quest",
            id = 92631,
            x = 0,
            connections = {
                1, 
            },
        },
        { -- Trial of Wrath
            type = "quest",
            id = 92632,
            x = 0,
        },
    }
})
BtWQuestsDatabase:AddExpansionItems(EXPANSION_ID, {
    {
        type = "chain",
        id = Chain.TheCultWithin,
        restrictions = function (item, character)
            return GetServerExpansionLevel() == 10
        end
    },
    {
        type = "chain",
        id = Chain.RageOfTheRendorei,
    },
})
