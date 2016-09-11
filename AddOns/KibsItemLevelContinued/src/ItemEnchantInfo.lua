local _, addonNamespace = ...

local ItemEnchantInfo = {}
ItemEnchantInfo.__index = ItemEnchantInfo

addonNamespace.ItemEnchantInfo = ItemEnchantInfo

local CONSUMABLE_ID = 1
local RECEIPE_ID = 2
local FORMULA_ID = 3

local db = {
    -- WoD:

    -- Enchant Ring
    [5284] = { 110617, 158907, 118448 }, -- Breath of Critical Strike
    [5297] = { 110618, 158908, 118449 }, -- Breath of Haste
    [5299] = { 110619, 158909, 118450 }, -- Breath of Mastery
    [5301] = { 110620, 158910, 118451 }, -- Breath of Multistrike
    [5303] = { 110621, 158911, 118452 }, -- Breath of Versatility
    [5324] = { 110638, 158914, 118453 }, -- Gift of Critical Strike
    [5325] = { 110639, 158915, 118454 }, -- Gift of Haste
    [5326] = { 110640, 158916, 118455 }, -- Gift of Mastery
    [5327] = { 110641, 158917, 118456 }, -- Gift of Multistrike
    [5328] = { 110642, 158918, 118457 }, -- Gift of Versatility

    -- Enchant Neck
    [5285] = { 110624, 158892, 118438 }, -- Breath of Critical Strike
    [5292] = { 110625, 158893, 118439 }, -- Breath of Haste
    [5293] = { 110626, 158894, 118440 }, -- Breath of Mastery
    [5294] = { 110627, 158895, 118441 }, -- Breath of Multistrike
    [5295] = { 110628, 158896, 118442 }, -- Breath of Versatility
    [5317] = { 110645, 158899, 118443 }, -- Gift of Critical Strike
    [5318] = { 110646, 158900, 118444 }, -- Gift of Haste
    [5319] = { 110647, 158901, 118445 }, -- Gift of Mastery
    [5320] = { 110648, 158902, 118446 }, -- Gift of Multistrike
    [5321] = { 110649, 158903, 118447 }, -- Gift of Versatility

    -- Enchant Cloak
    [5281] = { 110631, 158877, 118394 }, -- Breath of Critical Strike
    [5298] = { 110632, 158878, 118429 }, -- Breath of Haste
    [5300] = { 110633, 158879, 118430 }, -- Breath of Mastery
    [5302] = { 110634, 158880, 118431 }, -- Breath of Multistrike
    [5304] = { 110635, 158881, 118432 }, -- Breath of Versatility
    [5310] = { 110652, 158884, 118433 }, -- Gift of Critical Strike
    [5311] = { 110653, 158885, 118434 }, -- Gift of Haste
    [5312] = { 110654, 158886, 118435 }, -- Gift of Mastery
    [5313] = { 110655, 158887, 118436 }, -- Gift of Multistrike
    [5314] = { 110656, 158889, 118437 }, -- Gift of Versatility

    -- Enchant Ranged Weapon
    [5275] = { 109120, 156050, 118477 }, -- Oglethorpe's Missile Splitter
    [5276] = { 109122, 156061, 118478 }, -- Megawatt Filament
    [5383] = { 118008, 173287, 118495 }, -- Hemet's Heartseeker

    -- Enchant Fishing Pole
    [5357] = { 116117, 170886, nil }, -- Rook's Lucky Fishin' Line

    -- Enchant Weapon
    [5330] = { 110682, 159235, 159235 }, -- Mark of the Thunderlord
    [5331] = { 112093, 159236, 159236 }, -- Mark of the Shattered Hand
    [5335] = { 112115, 159673, 159673 }, -- Mark of Shadowmoon
    [5336] = { 112160, 159674, 159674 }, -- Mark of Blackrock
    [5337] = { 112164, 159671, 159671 }, -- Mark of Warsong
    [5334] = { 112165, 159672, 159672 }, -- Mark of the Frostwolf
    [5352] = { 115973, 170627, 170627 }, -- Glory of the Thunderlord
    [5353] = { 115975, 170628, 170628 }, -- Glory of the Shadowmoon
    [5354] = { 115976, 170629, 170629 }, -- Glory of the Blackrock
    [5355] = { 115977, 170630, 170630 }, -- Glory of the Warsong
    [5356] = { 115978, 170631, 170631 }, -- Glory of the Frostwolf

    -- Death Knight Runes
    [3370] = { nil, 53343, nil }, -- Rune of Razorice
    [3595] = { nil, 54447, nil }, -- Rune of Spellbreaking
    [3367] = { nil, 53342, nil }, -- Rune of Spellshattering
    [3366] = { nil, 53331, nil }, -- Rune of Lichbane
    [3368] = { nil, 53344, nil }, -- Rune of the Fallen Crusader
    [3847] = { nil, 62158, nil }, -- Rune of the Stoneskin Gargoyle

    -- Legion:

    -- Enchant Ring
    [5423] = { 128537, 190866, 128562 }, -- Word of Critical Strike
    [5424] = { 128538, 190867, 128563 }, -- Word of Haste
    [5425] = { 128539, 190868, 128564 }, -- Word of Mastery
    [5426] = { 128540, 190869, 128565 }, -- Word of Versatility
    [5427] = { 128541, 190870, 128566 }, -- Binding of Critical Strike
    [5428] = { 128542, 190871, 128567 }, -- Binding of Haste
    [5429] = { 128543, 190872, 128568 }, -- Binding of Mastery
    [5430] = { 128544, 190873, 128569 }, -- Binding of Versatility

    -- Enchant Cloak
    [5431] = { 128545, 190874, 128570 }, -- Word of Strength
    [5432] = { 128546, 190875, 128571 }, -- Word of Agility
    [5433] = { 128547, 190876, 128572 }, -- Word of Intellect
    [5434] = { 128548, 190877, 128573 }, -- Binding of Strength
    [5435] = { 128549, 190878, 128574 }, -- Binding of Agility
    [5436] = { 128550, 190879, 128575 }, -- Binding of Intellect

    -- Enchant Neck
    [5437] = { 128551, 190892, 128576 }, -- Mark of the Claw
    [5438] = { 128552, 190893, 128577 }, -- Mark of the Distant Army
    [5439] = { 128553, 190894, 128578 }, -- Mark of the Hidden Satyr
    [5889] = { 141908, 228402, 141911 }, -- Mark of the Heavy Hide
    [5890] = { 141909, 228405, 141912 }, -- Mark of the Trained Soldier
    [5891] = { 141910, 228408, 141913 }, -- Mark of the Ancient Priestess

    -- Enchant Gloves
    [5444] = { 128558, 190988, 128617 }, -- Legion Herbalism
    [5445] = { 128559, 190989, 128618 }, -- Legion Mining
    [5446] = { 128560, 190990, 128619 }, -- Legion Skinning
    [5447] = { 128561, 190991, 128620 }, -- Legion Surveying

    -- Enchant Shoulder
    [5440] = { 128554, 190954, nil }, -- Boon of the Scavenger
    [5441] = { 140213, 190955, nil }, -- Boon of the Gemfinder
    [5442] = { 140214, 190956, nil }, -- Boon of the Harvester
    [5443] = { 140215, 190957, nil }, -- Boon of the Butcher
    [5881] = { 140217, 222851, nil }, -- Boon of the Salvager
    [5882] = { 140218, 222852, nil }, -- Boon of the Manaseeker
    [5883] = { 140219, 222853, nil }, -- Boon of the Bloodhunter
    [5888] = { 141861, 228139, nil }, -- Boon of the Nether
}

function ItemEnchantInfo:new(enchantId)
    return setmetatable({
        enchantId = tonumber(enchantId),
    }, self)
end

function ItemEnchantInfo:getId()
    return self.enchantId
end

function ItemEnchantInfo:getConsumableItem()
    local rec = db[self.enchantId]
    return rec and rec[CONSUMABLE_ID] and addonNamespace.ItemStringInfo:new("item:"..rec[CONSUMABLE_ID]..":0:0:0:0:0:0:0:0:0:0")
end

function ItemEnchantInfo:getReceipeSpell()
    local rec = db[self.enchantId]
    return rec and rec[RECEIPE_ID] and addonNamespace.SpellInfo:new("spell:"..rec[RECEIPE_ID])
end

function ItemEnchantInfo:getFormulaItem()
    local rec = db[self.enchantId]
    return rec and rec[FORMULA_ID] and addonNamespace.ItemStringInfo:new("item:"..rec[FORMULA_ID]..":0:0:0:0:0:0:0:0:0:0")
end