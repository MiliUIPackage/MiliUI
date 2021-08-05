LootFinder = LootFinder or {}

local pvp_gear_list = {
	[175912] = false,
	[179578] = false,
	[178367] = false,
	[175913] = false,
	[178368] = false,
	[182480] = false,
	[175914] = false,
	[181333] = false,
	[178369] = false,
	[183501] = false,
	[175915] = false,
	[181844] = false,
	[183470] = false,
	[181462] = false,
	[182769] = false,
	[175916] = false,
	[181335] = false,
	[183184] = false,
	[178371] = false,
	[175917] = false,
	[178372] = false,
	[175918] = false,
	[182325] = false,
	[178373] = false,
	[175887] = false,
	[175919] = false,
	[181816] = false,
	[181848] = false,
	[178374] = false,
	[183506] = false,
	[181498] = false,
	[175920] = false,
	[178375] = false,
	[183507] = false,
	[175889] = false,
	[175921] = false,
	[182137] = false,
	[178376] = false,
	[182743] = false,
	[175890] = false,
	[175922] = false,
	[181373] = false,
	[178377] = false,
	[175891] = false,
	[182681] = false,
	[183478] = false,
	[181980] = false,
	[178442] = false,
	[180004] = false,
	[179526] = false,
	[182140] = false,
	[178379] = false,
	[175893] = false,
	[179495] = false,
	[179559] = false,
	[183480] = false,
	[175894] = false,
	[180261] = false,
	[182142] = false,
	[182461] = false,
	[182748] = false,
	[175895] = false,
	[182621] = false,
	[178382] = false,
	[178414] = false,
	[184311] = false,
	[182686] = false,
	[178383] = false,
	[178447] = false,
	[182368] = false,
	[178352] = false,
	[178384] = false,
	[178448] = false,
	[182624] = false,
	[178353] = false,
	[183485] = false,
	[175899] = false,
	[178354] = false,
	[178386] = false,
	[175900] = false,
	[178355] = false,
	[178387] = false,
	[175901] = false,
	[180842] = false,
	[178356] = false,
	[175902] = false,
	[178357] = false,
	[175903] = false,
	[179569] = false,
	[178358] = false,
	[181737] = false,
	[175904] = false,
	[182598] = false,
	[178359] = false,
	[183491] = false,
	[175905] = false,
	[182344] = false,
	[180081] = false,
	[178360] = false,
	[175906] = false,
	[178361] = false,
	[175907] = false,
	[180019] = false,
	[181836] = false,
	[175892] = false,
	[178362] = false,
	[180935] = false,
	[182449] = false,
	[175908] = false,
	[182128] = false,
	[181837] = false,
	[182109] = false,
	[183514] = false,
	[178363] = false,
	[178378] = false,
	[181944] = false,
	[175909] = false,
	[181461] = false,
	[179543] = false,
	[178380] = false,
	[182667] = false,
	[178364] = false,
	[175888] = false,
	[181511] = false,
	[175910] = false,
	[178381] = false,
	[182349] = false,
	[175896] = false,
	[181700] = false,
	[178365] = false,
	[181712] = false,
	[178385] = false,
	[175911] = false,
	[182465] = false,
	[183197] = false,
	[178370] = false,
	[179609] = false,
	[178366] = false,
	[175897] = false,
	[182187] = false,
	[175898] = false,
}

local gear_type = {
    [1] = 4,
    [2] = 4,
    [3] = 3,
    [4] = 2,
    [5] = 1,
    [6] = 4,
    [7] = 3,
    [8] = 1,
    [9] = 1,
    [10] = 2,
    [11] = 2,
    [12] = 2
}

local slotids = {
    [0] = "INVTYPE_HEAD",
    [1] = "INVTYPE_NECK",
    [2] = "INVTYPE_SHOULDER",
    [3] = "INVTYPE_CLOAK",
    [4] = "INVTYPE_CHEST",
    [5] = "INVTYPE_WRIST",
    [6] = "INVTYPE_HAND",
    [7] = "INVTYPE_WAIST",
    [8] = "INVTYPE_LEGS",
    [9] = "INVTYPE_FEET",
    [10] = "INVTYPE_WEAPON",-- need weapon wear table
    [11] = "INVTYPE_HOLDABLEs",-- shields/ off hands
    [12] = "INVTYPE_FINGER",
    [13] = "INVTYPE_TRINKET"
}
--[[
    GetMerchantNumItems()
    link = GetMerchantItemLink(index);
    name, texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost = GetMerchantItemInfo(index)
    itemType, itemSubType, _, _, iconID, _, classID, subclassID = select(6, GetItemInfo(itemID))
    for i = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        local name = GetMerchantItemInfo(i)
        local itemType, itemSubType, _, _, iconID, _, classID, subclassID = select(6, GetItemInfo(link))
        testDB[#testDB + 1] = {
            itemlink = link,
            name = name,
            itemType = itemType,
            itemSubType = itemSubType,
            iconID = iconID,
            classID = classID,
            subclassID = subclassID
        }
    end

}
]]
--[[
local spec_main_atr = {

    [71] = "ITEM_MOD_STRENGTH_SHORT", -- arms
    [72] = "ITEM_MOD_STRENGTH_SHORT", -- fury
    [73] = "ITEM_MOD_STRENGTH_SHORT", -- protection

    [65] = "ITEM_MOD_INTELLECT_SHORT", -- holy
    [66] = "ITEM_MOD_STRENGTH_SHORT", -- protection
    [70] = "ITEM_MOD_STRENGTH_SHORT",  -- retribution

    [253] = "ITEM_MOD_AGILITY_SHORT", -- beast mastery
    [254] = "ITEM_MOD_AGILITY_SHORT", -- marksmanship
    [255] = "ITEM_MOD_AGILITY_SHORT",  -- survival

    [259] = "ITEM_MOD_AGILITY_SHORT", -- assassination
    [260] = "ITEM_MOD_AGILITY_SHORT", -- outlaw
    [261] = "ITEM_MOD_AGILITY_SHORT",  -- subtlety

    [256] = "ITEM_MOD_INTELLECT_SHORT", -- discipline
    [257] = "ITEM_MOD_INTELLECT_SHORT", -- holy
    [258] = "ITEM_MOD_INTELLECT_SHORT",  -- shadow

    [250] = "ITEM_MOD_STRENGTH_SHORT", -- blood
    [251] = "ITEM_MOD_STRENGTH_SHORT", -- frost
    [252] = "ITEM_MOD_STRENGTH_SHORT", -- unholy

    [262] = "ITEM_MOD_INTELLECT_SHORT", -- elemental
    [263] = "ITEM_MOD_AGILITY_SHORT", -- enchancement
    [264] = "ITEM_MOD_INTELLECT_SHORT", -- restoration

    [62] = "ITEM_MOD_INTELLECT_SHORT", -- arcane
    [63] = "ITEM_MOD_INTELLECT_SHORT", -- fire
    [64] = "ITEM_MOD_INTELLECT_SHORT",  -- frost

    [265] = "ITEM_MOD_INTELLECT_SHORT", -- affliction
    [266] = "ITEM_MOD_INTELLECT_SHORT", -- demonology
    [267] = "ITEM_MOD_INTELLECT_SHORT", -- destruction

    [268] = "ITEM_MOD_AGILITY_SHORT", -- brewmaster
    [270] = "ITEM_MOD_INTELLECT_SHORT", -- mistweaver
    [269] = "ITEM_MOD_AGILITY_SHORT",  -- windwalker

    [102] = "ITEM_MOD_INTELLECT_SHORT", -- balance
    [103] = "ITEM_MOD_AGILITY_SHORT", -- feral
    [104] = "ITEM_MOD_AGILITY_SHORT", -- guardian
    [105] = "ITEM_MOD_INTELLECT_SHORT",  -- restororation

    [577] = "ITEM_MOD_AGILITY_SHORT", -- havoc
    [581] = "ITEM_MOD_AGILITY_SHORT"  -- vengeance
}
--itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
->itemEquipLoc<- head/back/trinket/off,main hand


, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent
   = GetItemInfo(itemInfo)
local spec_weapons = {

        [71] = {1,5,8}, -- arms
        [72] = {0,1,4,5,7,8}, -- fury
        [73] = {0,4,7}, -- protection

        [65] = {0,4,7}, -- holy
        [66] = {0,4,7}, -- protection
        [70] = {1,5,8},  -- retribution

        [253] = {2,3,18}, -- beast mastery
        [254] = {2,3,18}, -- marksmanship
        [255] = {6,10},  -- survival

        [259] = {15}, -- assassination
        [260] = {0,4,7}, -- outlaw
        [261] = {15},  -- subtlety

        [256] = {10,15,19}, -- discipline
        [257] = {10,15,19}, -- holy
        [258] = {10,15,16},  -- shadow

        [250] = {1,5,8}, -- blood
        [251] = {0,1,4,5,7,8}, -- frost
        [252] = {1,5,8}, -- unholy

        [262] = {4,10}, -- elemental
        [263] = {0,4,7}, -- enchancement
        [264] = {4,10}, -- restoration

        [62] = {}, -- arcane
        [63] = {}, -- fire
        [64] = {},  -- frost

        [265] = {}, -- affliction
        [266] = {}, -- demonology
        [267] = {}, -- destruction

        [268] = {}, -- brewmaster
        [270] = {}, -- mistweaver
        [269] = {},  -- windwalker

        [102] = {}, -- balance
        [103] = {}, -- feral
        [104] = {}, -- guardian
        [105] = {},  -- restororation

        [577] = {}, -- havoc
        [581] = {}  -- vengeance
}

local function GetPrimaryStats(tbl)
    if LootFinder.spec ~= 0 then
        local main_atr = spec_main_atr[LootFinder.spec]
        tbl[main_atr] = true
        return
    elseif LootFinder.class ~= 0 then
        for _, value in ipairs(LootFinder.class_spec[LootFinder.class]) do
            local main_atr = spec_main_atr[value]
            tbl[main_atr] = true
        end
    end
end

--]]
local spec_main_atr = {

    [71] = "ITEM_MOD_STRENGTH_SHORT", -- arms
    [72] = "ITEM_MOD_STRENGTH_SHORT", -- fury
    [73] = "ITEM_MOD_STRENGTH_SHORT", -- protection

    [65] = "ITEM_MOD_INTELLECT_SHORT", -- holy
    [66] = "ITEM_MOD_STRENGTH_SHORT", -- protection
    [70] = "ITEM_MOD_STRENGTH_SHORT",  -- retribution

    [253] = "ITEM_MOD_AGILITY_SHORT", -- beast mastery
    [254] = "ITEM_MOD_AGILITY_SHORT", -- marksmanship
    [255] = "ITEM_MOD_AGILITY_SHORT",  -- survival

    [259] = "ITEM_MOD_AGILITY_SHORT", -- assassination
    [260] = "ITEM_MOD_AGILITY_SHORT", -- outlaw
    [261] = "ITEM_MOD_AGILITY_SHORT",  -- subtlety

    [256] = "ITEM_MOD_INTELLECT_SHORT", -- discipline
    [257] = "ITEM_MOD_INTELLECT_SHORT", -- holy
    [258] = "ITEM_MOD_INTELLECT_SHORT",  -- shadow

    [250] = "ITEM_MOD_STRENGTH_SHORT", -- blood
    [251] = "ITEM_MOD_STRENGTH_SHORT", -- frost
    [252] = "ITEM_MOD_STRENGTH_SHORT", -- unholy

    [262] = "ITEM_MOD_INTELLECT_SHORT", -- elemental
    [263] = "ITEM_MOD_AGILITY_SHORT", -- enchancement
    [264] = "ITEM_MOD_INTELLECT_SHORT", -- restoration

    [62] = "ITEM_MOD_INTELLECT_SHORT", -- arcane
    [63] = "ITEM_MOD_INTELLECT_SHORT", -- fire
    [64] = "ITEM_MOD_INTELLECT_SHORT",  -- frost

    [265] = "ITEM_MOD_INTELLECT_SHORT", -- affliction
    [266] = "ITEM_MOD_INTELLECT_SHORT", -- demonology
    [267] = "ITEM_MOD_INTELLECT_SHORT", -- destruction

    [268] = "ITEM_MOD_AGILITY_SHORT", -- brewmaster
    [270] = "ITEM_MOD_INTELLECT_SHORT", -- mistweaver
    [269] = "ITEM_MOD_AGILITY_SHORT",  -- windwalker

    [102] = "ITEM_MOD_INTELLECT_SHORT", -- balance
    [103] = "ITEM_MOD_AGILITY_SHORT", -- feral
    [104] = "ITEM_MOD_AGILITY_SHORT", -- guardian
    [105] = "ITEM_MOD_INTELLECT_SHORT",  -- restororation

    [577] = "ITEM_MOD_AGILITY_SHORT", -- havoc
    [581] = "ITEM_MOD_AGILITY_SHORT"  -- vengeance
}
local weapons = {
    [0] = { -- 1H axes

        [1] = true, -- warrior
        [72] = true, -- fury
        [73] = true, -- protection

        [2] = true, -- paladin
        [65] = true, -- holy
        [66] = true, -- protection

        [4] = true, -- rogue
        [260] = true, -- outlaw

        [6] = true, -- death knight
        [251] = true, -- frost

        [7] = true, -- shaman
        [263] = true, -- enchancement

        [10] = true, -- monk
        [269] = true, -- windwalker

        [12] = true, -- demon hunter
        [577] = true, -- havoc
        [581] = true  -- vengeance
    },
    [1] = { -- 2H axes
        [1] = true, -- warrior
        [71] = true, -- arms
        [72] = true, -- fury

        [2] = true, -- paladin
        [70] = true, -- retribution

        [6] = true, -- death knight
        [250] = true, -- blood
        [251] = true, -- frost
        [252] = true, -- unholy
    },
    [2] = { -- bows
        [3] = true, -- hunter
        [253] = true,-- beast mastery
        [254] = true -- marksmanship
    },
    [3] = { -- guns
        [3] = true, -- hunter
        [253] = true,-- beast mastery
        [254] = true -- marksmanship
    },
    [4] = {  -- 1H maces
        [1] = true, -- warrior
        [72] = true, -- fury
        [73] = true, -- protection

        [2] = true, -- paladin
        [65] = true, -- holy
        [66] = true, -- protection

        [4] = true, -- rogue
        [260] = true, -- outlaw

        [5] = true, -- priest
        [256] = true, -- discipline
        [257] = true, -- holy
        [258] = true, -- shadow

        [6] = true, -- death knight
        [251] = true, -- frost

        [7] = true, -- shaman
        [263] = true, -- enchancement

        [10] = true, -- monk
        [269] = true, -- windwalker
        [270] = true, -- mistweaver

        [12] = true, -- demon hunter
        [577] = true, -- havoc
        [581] = true  -- vengeance
    },
    [5] = { -- 2H maces
        [1] = true, -- warrior
        [71] = true, -- arms
        [72] = true, -- fury

        [2] = true, -- paladin
        [70] = true, -- retribution

        [6] = true, -- death knight
        [250] = true, -- blood
        [251] = true, -- frost
        [252] = true, -- unholy
    },
    [6] = {-- polearms
        [3] = true, -- hunter
        [255] = true, -- survival

        [11] = true, -- druid
        [103] = true, -- feral
        [104] = true, -- balance
    },
    [7] = { -- 1H swords
        [1] = true, -- warrior
        [72] = true, -- fury
        [73] = true, -- protection

        [2] = true, -- paladin
        [65] = true, -- holy
        [66] = true, -- protection

        [4] = true, -- rogue
        [260] = true, -- outlaw

        [6] = true, -- death knight
        [251] = true, -- frost

        [7] = true, -- shaman
        [263] = true, -- enchancement

        [8] =  true, -- mage
        [62] = true, -- arcane
        [63] = true, -- fire
        [64] = true,  -- frost

        [9] = true, -- warlock
        [265] = true, -- affliction
        [266] = true, -- demonology
        [267] = true,  -- destruction

        [10] = true, -- monk
        [269] = true, -- windwalker

        [12] = true, -- demon hunter
        [577] = true, -- havoc
        [581] = true  -- vengeance
    },
    [8] = { -- 2H swords
        [1] = true, -- warrior
        [71] = true, -- arms
        [72] = true, -- fury

        [2] = true, -- paladin
        [70] = true, -- retribution

        [6] = true, -- death knight
        [250] = true, -- blood
        [251] = true, -- frost
        [252] = true, -- unholy
    },
    [9] = { -- warglaives
        [12] = true, -- demon hunter
        [577] = true, -- havoc
        [581] = true  -- vengeance
    },
    [10] = { -- staves
        [3] = true, -- hunter
        [255] = true, -- survival

        [5] = true, -- priest
        [256] = true, -- discipline
        [257] = true, -- holy
        [258] = true, -- shadow

        [8] =  true, -- mage
        [62] = true, -- arcane
        [63] = true, -- fire
        [64] = true,  -- frost

        [9] = true, -- warlock
        [265] = true, -- affliction
        [266] = true, -- demonology
        [267] = true,  -- destruction

        [10] = true, -- monk
        [268] = true, -- brewmaster
        [269] = true, -- mistweaver
        [270] = true, -- windwalker

        [11] = true, -- druid
        [102] = true, -- balance
        [103] = true, -- feral
        [104] = true, -- guardian
        [105] = true, -- restoration

    },
    --[11] = {}, -- bear claw?
    --[12] = {}, -- catclaw?
    [13] = { -- fist
        [4] = true, -- rogue
        [260] = true, -- outlaw

        [7] = true, -- shaman
        [263] = true, -- enchancement

        [10] = true, -- monk
        [269] = true, -- windwalker

        [12] = true, -- demon hunter
        [577] = true, -- havoc
        [581] = true, -- vengance

    },
    --[14] = {}, -- Miscellaneous
    [15] = { -- dagger
        [4] = true, -- rogue
        [259] = true, -- assassination
        [261] = true, -- subtlety

        [5] = true, -- priest
        [256] = true, -- discipline
        [257] = true, -- holy
        [258] = true, -- shadow

        [8] =  true, -- mage
        [62] = true, -- arcane
        [63] = true, -- fire
        [64] = true,  -- frost

        [9] = true, -- warlock
        [265] = true, -- affliction
        [266] = true, -- demonology
        [267] = true,  -- destruction

    },
    --[16] = {}, -- thrown Classic
    --[17] = {}, -- spears?
    [18] = { -- crossbows

    },
    [19] = { -- wands
        [5] = true, -- priest
        [256] = true, -- discipline
        [257] = true, -- holy
        [258] = true, -- shadow

        [8] =  true, -- mage
        [62] = true, -- arcane
        [63] = true, -- fire
        [64] = true,  -- frost

        [9] = true, -- warlock
        [265] = true, -- affliction
        [266] = true, -- demonology
        [267] = true,  -- destruction
    },
    --[20] = {}, -- fishing poles
}

local shields = {

    [1] = true, -- warrior
    [73] = true, -- protection

    [2] = true, -- paladin
    [65] = true, -- holy
    [66] = true,  -- protection

    [7] = true, -- shaman
    [262] = true, -- elemental
    [264] = true, -- restoration
}

local offhand = {
    [5] = true, -- priest
    [256] = true, -- discipline
    [257] = true, -- holy
    [258] = true, -- shadow

    [8] =  true, -- mage
    [62] = true, -- arcane
    [63] = true, -- fire
    [64] = true,  -- frost

    [9] = true, -- warlock
    [265] = true, -- affliction
    [266] = true, -- demonology
    [267] = true,  -- destruction

    [10] = true, -- monk
    [270] = true, -- mistweaver

    [11] = true, -- druid
    [102] = true, -- balance
    [105] = true, -- restoration

}
LootFinder.class_spec = {
    [1] = { -- warrior
        71, -- arms
        72, -- fury
        73  -- protection
    },
    [2] = { -- paladin
        65, -- holy
        66, -- protection
        70  -- retribution
    },
    [3] = { -- hunter
        253, -- beast mastery
        254, -- marksmanship
        255  -- survival
    },
    [4] = { --  rogue
        259, -- assassination
        260, -- outlaw
        261  -- subtlety
    },
    [5] = { -- priest
        256, -- discipline
        257, -- holy
        258  -- shadow
    },
    [6] = { -- death knight
        250, -- blood
        251, -- frost
        252  -- unholy
    },
    [7] = { -- shaman
        262, -- elemental
        263, -- enchancement
        264  -- restoration
    },
    [8] = { -- mage
        62, -- arcane
        63, -- fire
        64  -- frost
    },
    [9] = { -- warlock
        265, -- affliction
        266, -- demonology
        267  -- destruction
    },
    [10] = { -- monk
        268, -- brewmaster
        270, -- mistweaver
        269  -- windwalker
    },
    [11] = { -- druid
        102, -- balance
        103, -- feral
        104, -- guardian
        105  -- restororation
    },
    [12] = { -- demon hunter
        577, -- havoc
        581  -- vengeance
    }
}

local pvprank = {
    6628, -- unranked
    6627, -- Combatant
    6626, -- Challenger
    6625, -- Rival
    6623, -- Duelist
    6624  -- Elite
}

local rating = {
    "0-1399",
    "1400-1599",
    "1600-1799",
    "1800-2099",
    "2100-2399",
    "2400+"
}

local pvpilvl = {
    200,  -- unranked
    207,  -- Combatant
    213,  -- Challenger
    220,  -- Rival
    226,  -- Duelist
    233   -- Elite
}

local mythic_level = {
    6808, -- I know m+ id
    6808,-- index 2 -> mythic 2
    6809,
    7203,
    7204,
    7205,
    7206,
    7207,
    7208,
    7209,
    7210,
    7211,
    7212,
    7213,
    7214
}

LootFinder.class = 0
LootFinder.spec = 0
LootFinder.slot = 15
LootFinder.expansion = 9

LootFinder.instances = {}
LootFinder.milvl = 226
LootFinder.mlevel = 15

LootFinder.raids = {}
LootFinder.raid_difficult = 16

LootFinder.pvptier = 0

--[[
    LootFinder.raids = {}
    LootFinder.raid_difficult = 16
    14 - normal
    15 - heroic
    16 - mythic
    17 - looking for raid
]]

LootFinder.loot_list = {}
LootFinder.sort_by = false

LootFinder.stats = {}
--[[
    SPEC_FRAME_PRIMARY_STAT_STRENGTH    'ITEM_MOD_STRENGTH_SHORT'
    SPEC_FRAME_PRIMARY_STAT_AGILITY     'ITEM_MOD_AGILITY_SHORT'
    SPEC_FRAME_PRIMARY_STAT_INTELLECT   'ITEM_MOD_INTELLECT_SHORT'
    STAT_CRITICAL_STRIKE                'ITEM_MOD_CRIT_RATING_SHORT'
    STAT_HASTE                          'ITEM_MOD_HASTE_RATING_SHORT'
    STAT_VERSATILITY                    'ITEM_MOD_VERSATILITY'
    STAT_MASTERY                        'ITEM_MOD_MASTERY_RATING_SHORT'
]]
--- Add loot to list
---@param source string instance/raid
---@param name string instance name
---@param boss string boss name
---@param itemlink string itemlink
---@param icon integer iconID
---@param mainstat integer str/agi/int value
---@param crit integer crit value
---@param haste integer haste value
---@param mastery integer mastery value
---@param versality integer versality value
function LootFinder:AddResult(source, name, boss, itemlink, icon, mainstat, crit, haste, mastery, versality)
    local tbl = {source = source, name = name, boss = boss, itemlink = itemlink, icon = icon, mainstat = mainstat, crit = crit, haste = haste, mastery = mastery, versality = versality}
    LootFinder.loot_list[#LootFinder.loot_list+1] = tbl
end

function LootFinder.SortBy(stat)
    table.sort(LootFinder.loot_list, function(a,b) return a[stat] > b[stat] end)
end


---Get table size
---@param tbl table
---@return integer table_size
local function getsize(tbl)
    local size = 0
    for _, _ in pairs(tbl or LootFinder.stats) do
        size = size + 1
    end
    return size
end

local itemtstats = {}
--- Start find loot, results stored in Lootfinde.loot_list
function LootFinder:Find()
    EJ_SetDifficulty(23)
    --EJ_SelectTier(LootFinder.expansion)
    EJ_SetDifficulty(LootFinder.raid_difficult)
    if EncounterJournal_ListInstances then
        EncounterJournal_ListInstances()
    end
    self.class = self.class or 0
    self.spec = self.spec or 0
    self.slot = self.slot or 0
    EJ_SetLootFilter(self.class,self.spec )
    C_EncounterJournal.SetSlotFilter(self.slot)
    table.wipe(LootFinder.loot_list)

    -- instnaces
    local index = 1
    ---[[
    while EJ_GetInstanceByIndex(index, false) ~= nil do -- for each instance
        if LootFinder.instances[index] == nil then LootFinder.instances[index] = true end
        if LootFinder.instances[index] then -- if not black-listed
            local instanceID, instancename = EJ_GetInstanceByIndex(index, false) -- get instanceID and instance name
            EJ_SelectInstance(instanceID) -- select instance
            for i=1,EJ_GetNumLoot() do -- each loot
                table.wipe(itemtstats) -- wipe previous results
                local itemInfo = C_EncounterJournal.GetLootInfoByIndex(i) -- get loot info
                if not itemInfo.link then -- sometimes link is nil
                    i = i - 1
                elseif getsize(GetItemStats(itemInfo.link)) > 0 then
                    --modify link
                    --if LootFinder.mlevel ~= 0 then
                        itemInfo.link = itemInfo.link:gsub("%d+:3524:%d+:%d+:%d+","5:"..mythic_level[max(LootFinder.mlevel,1)]..":6652:1501:"..(LootFinder.milvl + 5658)..":6646")
                    --end
                    --boss name
                    local bossname = EJ_GetEncounterInfo(itemInfo.encounterID)

                    --add or not to lootlist
                    itemtstats = GetItemStats(itemInfo.link, itemtstats)
                    --if #LootFinder.stats > 0 then
                    if getsize() > 1 then
                        local count = 0
                        for key, _ in pairs(LootFinder.stats) do
                            if  itemtstats[key] then
                                count = count + 1
                            end
                        end
                        if count >= 2 then
                            LootFinder:AddResult("instance", instancename, bossname,
                                        itemInfo.link, itemInfo.icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                        itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                        itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                        end
                    elseif getsize() == 1 then
                        for key, _ in pairs(LootFinder.stats) do
                            if itemtstats[key] then
                                LootFinder:AddResult("instance", instancename, bossname,
                                        itemInfo.link, itemInfo.icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                        itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                        itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                                break
                            end
                        end
                    else
                        LootFinder:AddResult("instance", instancename, bossname,
                                itemInfo.link, itemInfo.icon,
                                itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                end
            end -- for each loot
        end -- if not black lsited
        index = index + 1
    end -- for each instance
--]]
    -- raids
    EJ_SetDifficulty(LootFinder.raid_difficult)
    index = 1
    while EJ_GetInstanceByIndex(index, true) ~= nil do -- for each instance
        if LootFinder.raids[index] == nil then LootFinder.raids[index] = true end
        if LootFinder.raids[index] then -- if not black-listed
            local instanceID, instancename = EJ_GetInstanceByIndex(index, true) -- get instanceID and instance name
            EJ_SelectInstance(instanceID) -- select instance
            for i=1,EJ_GetNumLoot() do -- each loot
                table.wipe(itemtstats) -- wipe previous results
                local itemInfo = C_EncounterJournal.GetLootInfoByIndex(i) -- get loot info
                if not itemInfo.link then -- sometimes link is nil
                    i = i - 1
                elseif getsize(GetItemStats(itemInfo.link)) > 0 then
                    --boss name
                    local bossname = EJ_GetEncounterInfo(itemInfo.encounterID)

                    --add or not to lootlist
                    itemtstats = GetItemStats(itemInfo.link, itemtstats)
                    --if #LootFinder.stats > 0 then
                    if getsize() > 1 then
                        local count = 0
                        for key, _ in pairs(LootFinder.stats) do
                            if  itemtstats[key] then
                                count = count + 1
                            end
                        end
                        if count >= 2 then
                            LootFinder:AddResult("raid", instancename, bossname,
                                        itemInfo.link, itemInfo.icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                        itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                        itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                        end
                    elseif getsize() == 1 then
                        for key, _ in pairs(LootFinder.stats) do
                            if itemtstats[key] then
                                LootFinder:AddResult("raid", instancename, bossname,
                                        itemInfo.link, itemInfo.icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                        itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                        itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                                break
                            end
                        end
                    else
                        LootFinder:AddResult("raid", instancename, bossname,
                                itemInfo.link, itemInfo.icon,
                                itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                end
            end -- for each loot
        end -- if not black lsited
        index = index + 1
    end -- for each instance
    if LootFinder.pvptier > 0 then
        for id, _ in pairs(pvp_gear_list) do

            table.wipe(itemtstats) -- wipe previous results
            local itemlink, _,_,_,_,_,_,itemtype, icon, _, classID, subclassID = select(2, GetItemInfo(id))
            local pvprating = rating[LootFinder.pvptier]
            if itemtype == "INVTYPE_NECK" and LootFinder.slot == 1 then
                local link = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. pvprank[LootFinder.pvptier] ..":"..(1272 + pvpilvl[LootFinder.pvptier]) .. ":6646:1:28:807:::")

                --add or not to lootlist
                itemtstats = GetItemStats(link, itemtstats)
                --if #LootFinder.stats > 0 then
                if getsize() > 1 then
                    local count = 0
                    for key, _ in pairs(LootFinder.stats) do
                        if  itemtstats[key] then
                            count = count + 1
                        end
                    end 
                    if count >= 2 then
                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                        link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                elseif getsize() == 1 then
                    for key, _ in pairs(LootFinder.stats) do
                        if itemtstats[key] then
                            LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                            link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                            break
                        end
                    end
                else
                    LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                    link, icon,
                            itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                            itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                            itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                end
            elseif itemtype == "INVTYPE_FINGER" and LootFinder.slot == 12 then
                    local link = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. pvprank[LootFinder.pvptier] ..":"..(1272 + pvpilvl[LootFinder.pvptier]) .. ":6646:1:28:807:::")

    
                    --add or not to lootlist
                    itemtstats = GetItemStats(link, itemtstats)
                    --if #LootFinder.stats > 0 then
                    if getsize() > 1 then
                        local count = 0
                        for key, _ in pairs(LootFinder.stats) do
                            if  itemtstats[key] then
                                count = count + 1
                            end
                        end 
                        if count >= 2 then
                            LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                            link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                        itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                        itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                        end
                    elseif getsize() == 1 then
                        for key, _ in pairs(LootFinder.stats) do
                            if itemtstats[key] then
                                LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                                link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                        itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                        itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                                break
                            end
                        end
                    else
                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                        link, icon,
                                itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
            elseif itemtype == "INVTYPE_TRINKET" and LootFinder.slot == 13 then
                local link = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. pvprank[LootFinder.pvptier] ..":"..(1272 + pvpilvl[LootFinder.pvptier]) .. ":6646:1:28:807:::")


                --add or not to lootlist
                itemtstats = GetItemStats(link, itemtstats)
                --if #LootFinder.stats > 0 then
                if getsize() > 1 then
                    local count = 0
                    for key, _ in pairs(LootFinder.stats) do
                        if  itemtstats[key] then
                            count = count + 1
                        end
                    end 
                    if count >= 2 then
                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                        link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                elseif getsize() == 1 then
                    for key, _ in pairs(LootFinder.stats) do
                        if itemtstats[key] then
                            LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                            link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                            break
                        end
                    end
                else
                    LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                    link, icon,
                            itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                            itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                            itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                end
            elseif itemtype == "INVTYPE_SHIELD" and LootFinder.slot == 11 and (shields[LootFinder.spec] or (LootFinder.spec == 0 and shields[LootFinder.class])) then
                local link = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. pvprank[LootFinder.pvptier] ..":"..(1272 + pvpilvl[LootFinder.pvptier]) .. ":6646:1:28:807:::")


                --add or not to lootlist
                itemtstats = GetItemStats(link, itemtstats)
                --if #LootFinder.stats > 0 then
                if getsize() > 1 then
                    local count = 0
                    for key, _ in pairs(LootFinder.stats) do
                        if  itemtstats[key] then
                            count = count + 1
                        end
                    end 
                    if count >= 2 then
                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                        link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                elseif getsize() == 1 then
                    for key, _ in pairs(LootFinder.stats) do
                        if itemtstats[key] then
                            LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                            link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                            break
                        end
                    end
                else
                    LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                    link, icon,
                            itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                            itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                            itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                end
            elseif itemtype == "INVTYPE_HOLDABLE" and LootFinder.slot == 11 and (offhand[LootFinder.spec] or (LootFinder.spec == 0 and offhand[LootFinder.class])) then
                local link = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. pvprank[LootFinder.pvptier] ..":"..(1272 + pvpilvl[LootFinder.pvptier]) .. ":6646:1:28:807:::")


                --add or not to lootlist
                itemtstats = GetItemStats(link, itemtstats)
                --if #LootFinder.stats > 0 then
                if getsize() > 1 then
                    local count = 0
                    for key, _ in pairs(LootFinder.stats) do
                        if  itemtstats[key] then
                            count = count + 1
                        end
                    end 
                    if count >= 2 then
                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                        link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                elseif getsize() == 1 then
                    for key, _ in pairs(LootFinder.stats) do
                        if itemtstats[key] then
                            LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                            link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                            break
                        end
                    end
                else
                    LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                    link, icon,
                            itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                            itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                            itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                end
            elseif (itemtype == "INVTYPE_CHEST" or itemtype == "INVTYPE_ROBE") and LootFinder.slot == 4 and subclassID == gear_type[LootFinder.class] then

                local link = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. pvprank[LootFinder.pvptier] ..":"..(1272 + pvpilvl[LootFinder.pvptier]) .. ":6646:1:28:807:::")


                --add or not to lootlist
                itemtstats = GetItemStats(link, itemtstats)
                --if #LootFinder.stats > 0 then
                if getsize() > 1 then
                    local count = 0
                    for key, _ in pairs(LootFinder.stats) do
                        if  itemtstats[key] then
                            count = count + 1
                        end
                    end 
                    if count >= 2 then
                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                        link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                elseif getsize() == 1 then
                    for key, _ in pairs(LootFinder.stats) do
                        if itemtstats[key] then
                            LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                            link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                            break
                        end
                    end
                else
                    LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                    link, icon,
                            itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                            itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                            itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                end
            elseif itemtype == "INVTYPE_CLOAK" and LootFinder.slot == 3 then
                local link = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. pvprank[LootFinder.pvptier] ..":"..(1272 + pvpilvl[LootFinder.pvptier]) .. ":6646:1:28:807:::")


                --add or not to lootlist
                itemtstats = GetItemStats(link, itemtstats)
                --if #LootFinder.stats > 0 then
                if getsize() > 1 then
                    local count = 0
                    for key, _ in pairs(LootFinder.stats) do
                        if  itemtstats[key] then
                            count = count + 1
                        end
                    end 
                    if count >= 2 then
                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                        link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                elseif getsize() == 1 then
                    for key, _ in pairs(LootFinder.stats) do
                        if itemtstats[key] then
                            LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                            link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                            break
                        end
                    end
                else
                    LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                    link, icon,
                            itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                            itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                            itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                end


            elseif classID == 4 and subclassID == gear_type[LootFinder.class] and itemtype:find(slotids[LootFinder.slot] or "") then
                local link = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. pvprank[LootFinder.pvptier] ..":"..(1272 + pvpilvl[LootFinder.pvptier]) .. ":6646:1:28:807:::")


                --add or not to lootlist
                itemtstats = GetItemStats(link, itemtstats)
                --if #LootFinder.stats > 0 then

                if getsize() > 1 then
                    local count = 0
                    for key, _ in pairs(LootFinder.stats) do
                        if  itemtstats[key] then
                            count = count + 1
                        end
                    end
                    if count >= 2 then
                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                        link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                elseif getsize() == 1 then
                    for key, _ in pairs(LootFinder.stats) do
                        if itemtstats[key] then
                            LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                            link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                    itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                    itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                            break
                        end
                    end
                else
                    LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                    link, icon,
                            itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                            itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                            itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                end

            elseif classID == 2 and LootFinder.slot == 10 and (weapons[subclassID][LootFinder.spec] or (LootFinder.spec == 0 and weapons[subclassID][LootFinder.class])) then
                local link = itemlink:gsub("%d+:%d+:::::","60:258::14:3:".. pvprank[LootFinder.pvptier] ..":"..(1272 + pvpilvl[LootFinder.pvptier]) .. ":6646:1:28:807:::")
                

                --add or not to lootlist
                itemtstats = GetItemStats(link, itemtstats)
                --if #LootFinder.stats > 0 then

                if spec_main_atr[LootFinder.spec] and itemtstats[spec_main_atr[LootFinder.spec]] then
                    if getsize() > 1 then
                        local count = 0
                        for key, _ in pairs(LootFinder.stats) do
                            if  itemtstats[key] then
                                count = count + 1
                            end
                        end
                        if count >= 2 then
                            LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                            link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                        itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                        itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                        end
                    elseif getsize() == 1 then
                        for key, _ in pairs(LootFinder.stats) do
                            if itemtstats[key] then
                                LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                                link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                        itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                        itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                                break
                            end
                        end
                    else
                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                        link, icon,
                                itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                    end
                elseif LootFinder.spec == 0 and LootFinder.class > 0 then
                    for _, spec in pairs(LootFinder.class_spec[LootFinder.class]) do
                        if spec_main_atr[spec] and itemtstats[spec_main_atr[spec]] then
                            if getsize() > 1 then
                                local count = 0
                                for key, _ in pairs(LootFinder.stats) do
                                    if  itemtstats[key] then
                                        count = count + 1
                                    end
                                end
                                if count >= 2 then
                                    LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                                    link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                                itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                                itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                                end
                            elseif getsize() == 1 then
                                for key, _ in pairs(LootFinder.stats) do
                                    if itemtstats[key] then
                                        LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                                        link, icon, itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                                itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                                itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                                        break
                                    end
                                end
                            else
                                LootFinder:AddResult("pvp", PLAYER_V_PLAYER, pvprating,
                                link, icon,
                                        itemtstats.ITEM_MOD_STRENGTH_SHORT or itemtstats.ITEM_MOD_AGILITY_SHORT or itemtstats.ITEM_MOD_INTELLECT_SHORT or 0, 
                                        itemtstats.ITEM_MOD_CRIT_RATING_SHORT or 0, itemtstats.ITEM_MOD_HASTE_RATING_SHORT or 0,
                                        itemtstats.ITEM_MOD_MASTERY_RATING_SHORT or 0, itemtstats.ITEM_MOD_VERSATILITY or 0)
                            end
                            break
                        end
                    end
                end
            end

        end
    end
end

