local lib, oldMinor = LibStub:NewLibrary("LibArmorToken-1.0", 2)
if not lib then return end

local ITEMDATA

local armorTypes = {
    PLATE = {"PALADIN", "WARRIOR", "DEATHKNIGHT"},
    MAIL = {"SHAMAN", "HUNTER", "EVOKER"},
    LEATHER = {"DRUID", "DEMONHUNTER", "ROGUE", "MONK"},
    CLOTH = {"MAGE", "PRIEST", "WARLOCK"},
    ALL = {"PALADIN", "WARRIOR", "DEATHKNIGHT", "SHAMAN", "HUNTER", "EVOKER", "DRUID", "DEMONHUNTER", "ROGUE", "MONK", "MAGE", "PRIEST", "WARLOCK"},
}
local classArmorType = {}
for armorType, classes in pairs(armorTypes) do
    if armorType ~= "ALL" then
        for _, class in ipairs(classes) do
            classArmorType[class] = armorType
        end
    end
end

-- this mapping came from Blizzard_Reports.lua
local fields = {
   "itemID", "enchantID", "gemID1", "gemID2", "gemID3",
   "gemID4", "suffixID", "uniqueID", "linkLevel", "specializationID",
   "upgradeTypeID", "instanceDifficultyID", "numBonusIDs", -- [:bonusID1:bonusID2:...]
   --[:upgradeValue1:upgradeValue2:...]:relic1NumBonusIDs[:relic1BonusID1:relic1BonusID2:...]:relic2NumBonusIDs[:relic2BonusID1:relic2BonusID2:...]:relic3NumBonusIDs[:relic3BonusID1:relic3BonusID2:...]
}
local function LinkOptions(link)
    local linkType, linkOptions, displayText = LinkUtil.ExtractLink(link)
    local splitOptions = {LinkUtil.SplitLinkOptions(linkOptions)}
    local options = {}
    for i, field in ipairs(fields) do
        options[field] = tonumber(splitOptions[i])
    end
    local numBonusIDs = tonumber(options.numBonusIDs)
    if numBonusIDs and numBonusIDs > 0 then
        local b = {}
        for i=1, numBonusIDs, 1 do
            local bonusID = tonumber(splitOptions[#fields + i])
            table.insert(b, bonusID)
            options["bonusID"..i] = bonusID
        end
        options.bonusIDs = b
    end
    --TODO: support the rest of the fields if they ever become relevant
    return options, linkType, displayText
end
local function IsVariantRelevant(linkOptions, variant)
    -- variant is a linkoptions table
    for field, value in pairs(variant) do
        if field == "bonusIDs" then
            for _, bonusID in ipairs(value) do
                if not tContains(linkOptions.bonusIDs, bonusID) then
                    return false
                end
            end
        else
            if linkOptions[field] ~= value then
                return false
            end
        end
    end
    return true
end
local function RelevantVariants(itemLinkOrId, variants)
    if not (variants and type(itemLinkOrId) == "string") then return end
    local linkOptions = LinkOptions(itemLinkOrId)
    local relevant = {}
    for _, variant in ipairs(variants) do
        if IsVariantRelevant(linkOptions, variant) then
            table.insert(relevant, variant)
        end
    end
    return #relevant > 0 and relevant or nil
end

-- API

function lib:ItemIsToken(itemid)
    if ITEMDATA[itemid] then
        return true
    end
end

do
    local t = {}
    function lib:IterateClassesForToken(itemid)
        if not ITEMDATA[itemid] then
            return ipairs({})
        end
        wipe(t)
        for cl in pairs(ITEMDATA[itemid]) do
            if classArmorType[cl] then
                table.insert(t, cl)
            end
        end
        return ipairs(t)
    end
end

do
    local t = {}
    function lib:IterateItemsForTokenAndClass(itemLinkOrId, class)
        -- TODO: this doesn't support variants, and the API would need to change for it to do so.
        -- Insofar as it's a wrapper for IterateItemsForToken with a parameter provided, combining
        -- it with GetTokenVariants should be sufficient.
        wipe(t)
        for itemid in self:IterateItemsForToken(itemLinkOrId, class) do
            table.insert(t, itemid)
        end
        return ipairs(t)
    end
end

function lib:GetTokenVariants(itemLinkOrId)
    local itemid = C_Item.GetItemInfoInstant(itemLinkOrId)
    if not (itemid and ITEMDATA[itemid] and ITEMDATA[itemid]._variants) then return end
    local relevantVariants = RelevantVariants(itemLinkOrId, ITEMDATA[itemid]._variants)
    if relevantVariants then
        return relevantVariants
    end
    return {unpack(ITEMDATA[itemid]._variants)}
end

do
    local co = function(tokenData, classOnly, itemLinkOrId)
        local relevantVariants = RelevantVariants(itemLinkOrId, tokenData._variants)
        local playerClass = select(2, UnitClass("player"))
        for class, citems in pairs(tokenData) do
            if (class ~= "_variants") and ((not classOnly) or (class == classOnly) or (class == "ALL") or (class == classArmorType[classOnly])) then
                for _, ci in ipairs(citems) do
                    -- relevant means "is specific to the player's class OR is non-class-specific and of the player's armor-type"
                    local relevant = class == playerClass or class == "ALL"
                    if not relevant and armorTypes[class] then
                        relevant = class == classArmorType[playerClass]
                    end
                    if tokenData._variants and not relevantVariants then
                        coroutine.yield(ci, class, relevant, {unpack(tokenData._variants)})
                    else
                        coroutine.yield(ci, class, relevant, relevantVariants)
                    end
                end
            end
        end
    end
    -- iterates over `itemid, restriction, relevant[, variants]`
    -- `restriction` will be either CLASSNAME, ARMORTYPE, or "ALL"
    -- `relevant` means it's either the armortype for the current player-class, or class-specific to the current player-class
    -- `variants` will be nil or a table; if an itemLink was provided for the token, the table will be filtered to only variants that apply to the link
    function lib:IterateItemsForToken(itemLinkOrId, classOnly)
        local itemid = C_Item.GetItemInfoInstant(itemLinkOrId)
        if not ITEMDATA[itemid] then
            return ipairs({})
        end
        return coroutine.wrap(function() return co(ITEMDATA[itemid], classOnly, itemLinkOrId) end)
    end
end

-- Helper function for the above, if you get a variant from it and need to e.g. check transmog.
-- Its goal is to make just enough of a link for it to be valid input to core Blizzard functions
function lib:GetBareLinkForItem(itemid, variant, itemName)
    if not variant then return (string.format("|Hitem:%d|h[%s]|h", itemid, itemName or itemid)) end
    local linkFields = {itemID=itemid, numBonusIDs=variant.numBonusIDs or (variant.bonusIDs and #variant.bonusIDs or 0)}
    MergeTable(linkFields, variant)
    local link = {}
    for i, field in ipairs(fields) do
        table.insert(link, linkFields[field] or "")
    end
    if variant.bonusIDs then
        tAppendAll(link, variant.bonusIDs)
    end
    return (string.format("|Hitem:%s|h[%s]|h", table.concat(link, ":"), itemName or itemid))
end

-- DATA
ITEMDATA = {
    [119305] = { -- Chest of the Iron Conqueror
        PALADIN = {115566},
        PRIEST = {115560},
        WARLOCK = {115588},
    },
    [119306] = { -- Gauntlets of the Iron Conqueror
        PALADIN = {115567},
        PRIEST = {115562},
        WARLOCK = {115585},
    },
    [119307] = { -- Leggings of the Iron Conqueror
        PALADIN = {115569},
        PRIEST = {115564},
        WARLOCK = {115587},
    },
    [119308] = { -- Helm of the Iron Conqueror
        PALADIN = {115568},
        PRIEST = {115563},
        WARLOCK = {115586},
    },
    [119309] = { -- Shoulders of the Iron Conqueror
        PALADIN = {115565},
        PRIEST = {115561},
        WARLOCK = {115589},
    },
    [119311] = { -- Gauntlets of the Iron Vanquisher
        DEATHKNIGHT = {115538},
        DRUID = {115541},
        MAGE = {115552},
        ROGUE = {115571},
    },
    [119312] = { -- Helm of the Iron Vanquisher
        DEATHKNIGHT = {115539},
        DRUID = {115542},
        MAGE = {115553},
        ROGUE = {115572},
    },
    [119313] = { -- Leggings of the Iron Vanquisher
        DEATHKNIGHT = {115535},
        DRUID = {115543},
        MAGE = {115554},
        ROGUE = {115573},
    },
    [119314] = { -- Shoulders of the Iron Vanquisher
        DEATHKNIGHT = {115536},
        DRUID = {115544},
        MAGE = {115551},
        ROGUE = {115574},
    },
    [119315] = { -- Chest of the Iron Vanquisher
        DEATHKNIGHT = {115537},
        DRUID = {115540},
        MAGE = {115550},
        ROGUE = {115570},
    },
    [119318] = { -- Chest of the Iron Protector
        HUNTER = {115548},
        MONK = {115558},
        SHAMAN = {115577},
        WARRIOR = {115582},
    },
    [119319] = { -- Gauntlets of the Iron Protector
        HUNTER = {115549},
        MONK = {115555},
        SHAMAN = {115578},
        WARRIOR = {115583},
    },
    [119320] = { -- Leggings of the Iron Protector
        HUNTER = {115546},
        MONK = {115557},
        SHAMAN = {115575},
        WARRIOR = {115580},
    },
    [119321] = { -- Helm of the Iron Protector
        HUNTER = {115545},
        MONK = {115556},
        SHAMAN = {115579},
        WARRIOR = {115584},
    },
    [127953] = { -- Chest of Hellfire's Conqueror
        DEMONHUNTER = {139625},
        PALADIN = {124318},
        PRIEST = {124172},
        WARLOCK = {124173},
    },
    [127954] = { -- Gauntlets of Hellfire's Conqueror
        DEMONHUNTER = {139626},
        PALADIN = {124328},
        PRIEST = {124155},
        WARLOCK = {124156},
    },
    [127955] = { -- Leggings of Hellfire's Conqueror
        DEMONHUNTER = {139628},
        PALADIN = {124339},
        PRIEST = {124166},
        WARLOCK = {124167},
    },
    [127956] = { -- Helm of Hellfire's Conqueror
        DEMONHUNTER = {139627},
        PALADIN = {124333},
        PRIEST = {124161},
        WARLOCK = {124162},
    },
    [127957] = { -- Shoulders of Hellfire's Conqueror
        DEMONHUNTER = {139629},
        PALADIN = {124345},
        PRIEST = {124178},
        WARLOCK = {124179},
    },
    [127958] = { -- Gauntlets of Hellfire's Vanquisher
        DEATHKNIGHT = {124327},
        DRUID = {124255},
        MAGE = {124154},
        ROGUE = {124257},
    },
    [127959] = { -- Helm of Hellfire's Vanquisher
        DEATHKNIGHT = {124332},
        DRUID = {124261},
        MAGE = {124160},
        ROGUE = {124263},
    },
    [127960] = { -- Leggings of Hellfire's Vanquisher
        DEATHKNIGHT = {124338},
        DRUID = {124267},
        MAGE = {124165},
        ROGUE = {124269},
    },
    [127961] = { -- Shoulders of Hellfire's Vanquisher
        DEATHKNIGHT = {124344},
        DRUID = {124272},
        MAGE = {124177},
        ROGUE = {124274},
    },
    [127962] = { -- Chest of Hellfire's Vanquisher
        DEATHKNIGHT = {124317},
        DRUID = {124246},
        MAGE = {124171},
        ROGUE = {124248},
    },
    [127963] = { -- Chest of Hellfire's Protector
        HUNTER = {124284},
        MONK = {124247},
        SHAMAN = {124303},
        WARRIOR = {124319},
    },
    [127964] = { -- Gauntlets of Hellfire's Protector
        HUNTER = {124292},
        MONK = {124256},
        SHAMAN = {124293},
        WARRIOR = {124329},
    },
    [127965] = { -- Leggings of Hellfire's Protector
        HUNTER = {124301},
        MONK = {124268},
        SHAMAN = {124302},
        WARRIOR = {124340},
    },
    [127966] = { -- Helm of Hellfire's Protector
        HUNTER = {124296},
        MONK = {124262},
        SHAMAN = {124297},
        WARRIOR = {124334},
    },
    [127967] = { -- Shoulders of Hellfire's Protector
        HUNTER = {124307},
        MONK = {124273},
        SHAMAN = {124308},
        WARRIOR = {124346},
    },
    [127968] = { -- Badge of Hellfire's Vanquisher
        DEATHKNIGHT = {124513},
        DRUID = {124514},
        MAGE = {124516},
        ROGUE = {124520},
    },
    [127969] = { -- Badge of Hellfire's Conqueror
        PALADIN = {124518},
        PRIEST = {124519},
        WARLOCK = {124522},
    },
    [127970] = { -- Badge of Hellfire's Protector
        HUNTER = {124515},
        MONK = {124517},
        SHAMAN = {124521},
        WARRIOR = {124523},
    },
    [29753] = { -- Chestguard of the Fallen Defender
        DRUID = {28130, 29091, 29096, 28140, 31379, 29087},
        PRIEST = {29056, 29050, 31413, 27711},
        WARRIOR = {24544, 29019, 29012},
    },
    [29754] = { -- Chestguard of the Fallen Champion
        PALADIN = {29062, 27879, 29066, 29071, 27702, 31613},
        ROGUE = {29045, 25831},
        SHAMAN = {31396, 29029, 29033, 27469, 25997, 29038},
    },
    [29755] = { -- Chestguard of the Fallen Hero
        HUNTER = {29082, 28334},
        MAGE = {25856, 29077},
        WARLOCK = {24552, 28964, 30200},
    },
    [29756] = { -- Gloves of the Fallen Hero
        HUNTER = {29085, 28335},
        MAGE = {29080, 25857},
        WARLOCK = {28968, 30188, 24556},
    },
    [29757] = { -- Gloves of the Fallen Champion
        PALADIN = {27880, 29065, 29067, 29072, 27703, 31614},
        ROGUE = {29048, 25834},
        SHAMAN = {31397, 29032, 29034, 27470, 29039, 26000},
    },
    [29758] = { -- Gloves of the Fallen Defender
        DRUID = {29090, 29092, 28136, 29097, 31375, 28126},
        PRIEST = {31409, 29057, 27707, 29055},
        WARRIOR = {29017, 29020, 24549},
    },
    [29759] = { -- Helm of the Fallen Hero
        HUNTER = {29081, 28331},
        MAGE = {29076, 25855},
        WARLOCK = {24553, 28963, 30187},
    },
    [29760] = { -- Helm of the Fallen Champion
        PALADIN = {31616, 29061, 27881, 29068, 29073, 27704},
        ROGUE = {29044, 25830},
        SHAMAN = {29028, 31400, 29035, 25998, 27471, 29040},
    },
    [29761] = { -- Helm of the Fallen Defender
        DRUID = {29093, 28137, 29098, 31376, 29086, 28127},
        PRIEST = {29049, 31410, 27708, 29058},
        WARRIOR = {24545, 29011, 29021},
    },
    [29762] = { -- Pauldrons of the Fallen Hero
        HUNTER = {29084, 28333},
        MAGE = {25854, 29079},
        WARLOCK = {30186, 24554, 28967},
    },
    [29763] = { -- Pauldrons of the Fallen Champion
        PALADIN = {31619, 29064, 27883, 29070, 29075, 27706},
        ROGUE = {25832, 29047},
        SHAMAN = {29031, 29037, 31407, 25999, 27473, 29043},
    },
    [29764] = { -- Pauldrons of the Fallen Defender
        DRUID = {28129, 29089, 29095, 28139, 29100, 31378},
        PRIEST = {29060, 29054, 31412, 27710},
        WARRIOR = {29016, 24546, 29023},
    },
    [29765] = { -- Leggings of the Fallen Hero
        HUNTER = {29083, 28332},
        MAGE = {25858, 29078},
        WARLOCK = {30201, 24555, 28966},
    },
    [29766] = { -- Leggings of the Fallen Champion
        PALADIN = {31618, 29063, 27882, 29069, 29074, 27705},
        ROGUE = {25833, 29046},
        SHAMAN = {29030, 29036, 31406, 27472, 26001, 29042},
    },
    [29767] = { -- Leggings of the Fallen Defender
        DRUID = {28128, 29088, 29094, 28138, 29099, 31377},
        PRIEST = {31411, 29059, 27709, 29053},
        WARRIOR = {24547, 29022, 29015},
    },
    [30236] = { -- Chestguard of the Vanquished Champion
        PALADIN = {32039, 30123, 30129, 32020, 30134, 31992},
        ROGUE = {30144, 32002},
        SHAMAN = {32004, 32009, 30185, 30164, 30169, 32029},
    },
    [30237] = { -- Chestguard of the Vanquished Defender
        DRUID = {31972, 30216, 30222, 30231, 31991, 32060},
        PRIEST = {32019, 30150, 32038, 30159},
        WARRIOR = {30113, 30118, 30486},
    },
    [30238] = { -- Chestguard of the Vanquished Hero
        HUNTER = {31960, 30139},
        MAGE = {32050, 30196},
        WARLOCK = {31977, 31982, 30214},
    },
    [30239] = { -- Gloves of the Vanquished Champion
        PALADIN = {32040, 30124, 30130, 32021, 30135, 31993},
        ROGUE = {30145, 31998},
        SHAMAN = {32005, 32010, 30189, 30165, 30170, 32030},
    },
    [30240] = { -- Gloves of the Vanquished Defender
        DRUID = {30217, 30232, 30223, 31987, 32056, 31967},
        PRIEST = {30160, 30151, 32034, 32015},
        WARRIOR = {30119, 30114, 30487},
    },
    [30241] = { -- Gloves of the Vanquished Hero
        HUNTER = {31961, 30140},
        MAGE = {32049, 30205},
        WARLOCK = {31981, 30211, 31973},
    },
    [30242] = { -- Helm of the Vanquished Champion
        PALADIN = {32041, 30125, 30131, 32022, 30136, 31997},
        ROGUE = {30146, 31999},
        SHAMAN = {32006, 32011, 30190, 30166, 30171, 32031},
    },
    [30243] = { -- Helm of the Vanquished Defender
        DRUID = {31968, 30219, 30233, 31988, 30228, 32057},
        PRIEST = {32016, 30161, 32035, 30152},
        WARRIOR = {30488, 30115, 30120},
    },
    [30244] = { -- Helm of the Vanquished Hero
        HUNTER = {31962, 30141},
        MAGE = {32048, 30206},
        WARLOCK = {31980, 30212, 31974},
    },
    [30245] = { -- Leggings of the Vanquished Champion
        PALADIN = {32042, 30126, 30132, 32023, 30137, 31995},
        ROGUE = {32000, 30148},
        SHAMAN = {32032, 32007, 32012, 30192, 30167, 30172},
    },
    [30246] = { -- Leggings of the Vanquished Defender
        DRUID = {31969, 30220, 30234, 30229, 31989, 32058},
        PRIEST = {32017, 30153, 30162, 32036},
        WARRIOR = {30489, 30121, 30116},
    },
    [30247] = { -- Leggings of the Vanquished Hero
        HUNTER = {31963, 30142},
        MAGE = {32051, 30207},
        WARLOCK = {31983, 30213, 31975},
    },
    [30248] = { -- Pauldrons of the Vanquished Champion
        PALADIN = {32043, 30127, 30133, 32024, 30138, 31996},
        ROGUE = {32001, 30149},
        SHAMAN = {32033, 32008, 32013, 30194, 30168, 30173},
    },
    [30249] = { -- Pauldrons of the Vanquished Defender
        DRUID = {31971, 30221, 32059, 31990, 30230, 30235},
        PRIEST = {30154, 32018, 30163, 32037},
        WARRIOR = {30122, 30490, 30117},
    },
    [30250] = { -- Pauldrons of the Vanquished Hero
        HUNTER = {31964, 30143},
        MAGE = {30210, 32047},
        WARLOCK = {31976, 31979, 30215},
    },
    [31089] = { -- Chestguard of the Forgotten Conqueror
        PALADIN = {32039, 30990, 30991, 30992, 32020, 31992},
        PRIEST = {31065, 31066, 32019, 32038},
        WARLOCK = {31977, 31052, 31982},
    },
    [31090] = { -- Chestguard of the Forgotten Vanquisher
        DRUID = {31041, 31042, 31043, 31972, 31991, 32060},
        MAGE = {31057, 32050},
        ROGUE = {32002, 31028},
    },
    [31091] = { -- Chestguard of the Forgotten Protector
        HUNTER = {31960, 31004},
        SHAMAN = {32004, 31016, 31017, 31018, 32009, 32029},
        WARRIOR = {30976, 30486, 30975},
    },
    [31092] = { -- Gloves of the Forgotten Conqueror
        PALADIN = {30982, 30983, 32040, 30985, 32021, 31993},
        PRIEST = {32034, 31060, 31061, 32015},
        WARLOCK = {31981, 31050, 31973},
    },
    [31093] = { -- Gloves of the Forgotten Vanquisher
        DRUID = {32056, 31987, 31032, 31034, 31035, 31967},
        MAGE = {32049, 31055},
        ROGUE = {31026, 31998},
    },
    [31094] = { -- Gloves of the Forgotten Protector
        HUNTER = {31001, 31961},
        SHAMAN = {31008, 31011, 32005, 32010, 32030, 31007},
        WARRIOR = {30969, 30970, 30487},
    },
    [31095] = { -- Helm of the Forgotten Protector
        HUNTER = {31962, 31003},
        SHAMAN = {31012, 32006, 31014, 31015, 32011, 32031},
        WARRIOR = {30488, 30972, 30974},
    },
    [31096] = { -- Helm of the Forgotten Vanquisher
        DRUID = {31040, 31968, 31988, 32057, 31037, 31039},
        MAGE = {31056, 32048},
        ROGUE = {31027, 31999},
    },
    [31097] = { -- Helm of the Forgotten Conqueror
        PALADIN = {32041, 30987, 30988, 30989, 32022, 31997},
        PRIEST = {31064, 32016, 32035, 31063},
        WARLOCK = {31051, 31980, 31974},
    },
    [31098] = { -- Leggings of the Forgotten Conqueror
        PALADIN = {32042, 30993, 30994, 30995, 32023, 31995},
        PRIEST = {32017, 31067, 31068, 32036},
        WARLOCK = {31975, 31053, 31983},
    },
    [31099] = { -- Leggings of the Forgotten Vanquisher
        DRUID = {31969, 31044, 31045, 31046, 31989, 32058},
        MAGE = {31058, 32051},
        ROGUE = {32000, 31029},
    },
    [31100] = { -- Leggings of the Forgotten Protector
        HUNTER = {31963, 31005},
        SHAMAN = {32032, 32007, 31019, 32012, 31020, 31021},
        WARRIOR = {30977, 30978, 30489},
    },
    [31101] = { -- Pauldrons of the Forgotten Conqueror
        PALADIN = {32043, 30996, 30997, 30998, 32024, 31996},
        PRIEST = {32018, 32037, 31069, 31070},
        WARLOCK = {31976, 31979, 31054},
    },
    [31102] = { -- Pauldrons of the Forgotten Vanquisher
        DRUID = {31971, 31047, 31048, 31049, 31990, 32059},
        MAGE = {31059, 32047},
        ROGUE = {32001, 31030},
    },
    [31103] = { -- Pauldrons of the Forgotten Protector
        HUNTER = {31964, 31006},
        SHAMAN = {32033, 32008, 32013, 31022, 31023, 31024},
        WARRIOR = {30490, 30979, 30980},
    },
    [34848] = { -- Bracers of the Forgotten Conqueror
        MAGE = {33883, 33901},
        PALADIN = {34432, 34433, 33889, 33904, 33910, 34431},
        PRIEST = {34434, 34435, 33883, 33901},
        WARLOCK = {33883, 34436, 33901},
        WARRIOR = {33904, 33889, 33910},
    },
    [34851] = { -- Bracers of the Forgotten Protector
        DEATHKNIGHT = {33876},
        HUNTER = {33897, 33906, 34443, 33876, 33894},
        PALADIN = {33813},
        SHAMAN = {34437, 33894, 34438, 34439, 33897, 33906, 33876},
        WARRIOR = {34441, 34442, 33813},
    },
    [34852] = { -- Bracers of the Forgotten Vanquisher
        DRUID = {33893, 34444, 34445, 34446, 33881, 33917, 33887},
        MAGE = {33913, 34447},
        MONK = {33881, 33893, 33917, 33887},
        PRIEST = {33913},
        ROGUE = {34448, 33881, 33893, 33917, 33887},
        WARLOCK = {33913},
    },
    [34853] = { -- Belt of the Forgotten Conqueror
        MAGE = {33882, 33900},
        PALADIN = {33888, 33903, 33909, 34485, 34487, 34488},
        PRIEST = {34528, 33882, 33900, 34527},
        WARLOCK = {33882, 33900, 34541},
        WARRIOR = {33888, 33909, 33903},
    },
    [34854] = { -- Belt of the Forgotten Protector
        HUNTER = {33898, 33907, 33877, 34549, 33895},
        PALADIN = {33811},
        SHAMAN = {33895, 33898, 34542, 34543, 34545, 33907, 33877},
        WARRIOR = {33811, 34546, 34547},
    },
    [34855] = { -- Belt of the Forgotten Vanquisher
        DRUID = {33891, 33915, 33879, 34554, 34555, 34556, 33885},
        MAGE = {33912, 34557},
        MONK = {33915, 33891, 33885, 33879},
        PRIEST = {33912},
        ROGUE = {33915, 33891, 33885, 34558, 33879},
        WARLOCK = {33912},
    },
    [34856] = { -- Boots of the Forgotten Conqueror
        MAGE = {33884, 33902},
        PALADIN = {34560, 34561, 33890, 33905, 33911, 34559},
        PRIEST = {34562, 34563, 33884, 33902},
        WARLOCK = {34564, 33902, 33884},
        WARRIOR = {33905, 33890, 33911},
    },
    [34857] = { -- Boots of the Forgotten Protector
        HUNTER = {33896, 34570, 33899, 33908, 33878},
        PALADIN = {33812},
        SHAMAN = {34565, 34566, 34567, 33896, 33899, 33908, 33878},
        WARRIOR = {34568, 34569, 33812},
    },
    [34858] = { -- Boots of the Forgotten Vanquisher
        DRUID = {33892, 34571, 34572, 34573, 33880, 33916, 33886},
        MAGE = {33914, 34574},
        MONK = {33880, 33916, 33892, 33886},
        PRIEST = {33914},
        ROGUE = {33880, 33916, 33892, 33886, 34575},
        WARLOCK = {33914},
    },
    [40610] = { -- Chestguard of the Lost Conqueror
        PALADIN = {39633, 39629, 39638},
        PRIEST = {39515, 39523},
        WARLOCK = {39497},
    },
    [40611] = { -- Chestguard of the Lost Protector
        HUNTER = {39579},
        SHAMAN = {39592, 39588, 39597},
        WARRIOR = {39611, 39606},
    },
    [40612] = { -- Chestguard of the Lost Vanquisher
        DEATHKNIGHT = {39617, 39623},
        DRUID = {39538, 39547, 39554},
        MAGE = {39492},
        ROGUE = {39558},
    },
    [40613] = { -- Gloves of the Lost Conqueror
        PALADIN = {39632, 39634, 39639},
        PRIEST = {39530, 39519},
        WARLOCK = {39500},
    },
    [40614] = { -- Gloves of the Lost Protector
        HUNTER = {39582},
        SHAMAN = {39593, 39601, 39591},
        WARRIOR = {39609, 39622},
    },
    [40615] = { -- Gloves of the Lost Vanquisher
        DEATHKNIGHT = {39624, 39618},
        DRUID = {39544, 39557, 39543},
        MAGE = {39495},
        ROGUE = {39560},
    },
    [40616] = { -- Helm of the Lost Conqueror
        PALADIN = {39640, 39635, 39628},
        PRIEST = {39521, 39514},
        WARLOCK = {39496},
    },
    [40617] = { -- Helm of the Lost Protector
        HUNTER = {39578},
        SHAMAN = {39602, 39594, 39583},
        WARRIOR = {39610, 39605},
    },
    [40618] = { -- Helm of the Lost Vanquisher
        DEATHKNIGHT = {39625, 39619},
        DRUID = {39545, 39553, 39531},
        MAGE = {39491},
        ROGUE = {39561},
    },
    [40619] = { -- Leggings of the Lost Conqueror
        PALADIN = {39641, 39636, 39630},
        PRIEST = {39528, 39517},
        WARLOCK = {39498},
    },
    [40620] = { -- Leggings of the Lost Protector
        HUNTER = {39580},
        SHAMAN = {39603, 39595, 39589},
        WARRIOR = {39612, 39607},
    },
    [40621] = { -- Leggings of the Lost Vanquisher
        DEATHKNIGHT = {39626, 39620},
        DRUID = {39546, 39539, 39555},
        MAGE = {39493},
        ROGUE = {39564},
    },
    [40622] = { -- Spaulders of the Lost Conqueror
        PALADIN = {39642, 39637, 39631},
        PRIEST = {39529, 39518},
        WARLOCK = {39499},
    },
    [40623] = { -- Spaulders of the Lost Protector
        HUNTER = {39581},
        SHAMAN = {39604, 39596, 39590},
        WARRIOR = {39608, 39613},
    },
    [40624] = { -- Spaulders of the Lost Vanquisher
        DEATHKNIGHT = {39627, 39621},
        DRUID = {39556, 39548, 39542},
        MAGE = {39494},
        ROGUE = {39565},
    },
    [40625] = { -- Breastplate of the Lost Conqueror
        PALADIN = {40569, 40579, 40574},
        PRIEST = {40449, 40458},
        WARLOCK = {40423},
    },
    [40626] = { -- Breastplate of the Lost Protector
        HUNTER = {40503},
        SHAMAN = {40514, 40523, 40508},
        WARRIOR = {40544, 40525},
    },
    [40627] = { -- Breastplate of the Lost Vanquisher
        DEATHKNIGHT = {40550, 40559},
        DRUID = {40471, 40469, 40463},
        MAGE = {40418},
        ROGUE = {40495},
    },
    [40628] = { -- Gauntlets of the Lost Conqueror
        PALADIN = {40570, 40580, 40575},
        PRIEST = {40445, 40454},
        WARLOCK = {40420},
    },
    [40629] = { -- Gauntlets of the Lost Protector
        HUNTER = {40504},
        SHAMAN = {40520, 40515, 40509},
        WARRIOR = {40545, 40527},
    },
    [40630] = { -- Gauntlets of the Lost Vanquisher
        DEATHKNIGHT = {40552, 40563},
        DRUID = {40472, 40466, 40460},
        MAGE = {40415},
        ROGUE = {40496},
    },
    [40631] = { -- Crown of the Lost Conqueror
        PALADIN = {40576, 40571, 40581},
        PRIEST = {40456, 40447},
        WARLOCK = {40421},
    },
    [40632] = { -- Crown of the Lost Protector
        HUNTER = {40505},
        SHAMAN = {40521, 40516, 40510},
        WARRIOR = {40528, 40546},
    },
    [40633] = { -- Crown of the Lost Vanquisher
        DEATHKNIGHT = {40554, 40565},
        DRUID = {40473, 40467, 40461},
        MAGE = {40416},
        ROGUE = {40499},
    },
    [40634] = { -- Legplates of the Lost Conqueror
        PALADIN = {40577, 40572, 40583},
        PRIEST = {40448, 40457},
        WARLOCK = {40422},
    },
    [40635] = { -- Legplates of the Lost Protector
        HUNTER = {40506},
        SHAMAN = {40512, 40522, 40517},
        WARRIOR = {40529, 40547},
    },
    [40636] = { -- Legplates of the Lost Vanquisher
        DEATHKNIGHT = {40556, 40567},
        DRUID = {40468, 40493, 40462},
        MAGE = {40417},
        ROGUE = {40500},
    },
    [40637] = { -- Mantle of the Lost Conqueror
        PALADIN = {40584, 40578, 40573},
        PRIEST = {40450, 40459},
        WARLOCK = {40424},
    },
    [40638] = { -- Mantle of the Lost Protector
        HUNTER = {40507},
        SHAMAN = {40513, 40524, 40518},
        WARRIOR = {40530, 40548},
    },
    [40639] = { -- Mantle of the Lost Vanquisher
        DEATHKNIGHT = {40568, 40557},
        DRUID = {40494, 40465, 40470},
        MAGE = {40419},
        ROGUE = {40502},
    },
    [45632] = { -- Breastplate of the Wayward Conqueror
        PALADIN = {46154, 46173, 46178},
        PRIEST = {46168, 46193},
        WARLOCK = {46137},
    },
    [45633] = { -- Breastplate of the Wayward Protector
        HUNTER = {46141},
        SHAMAN = {46206, 46205, 46198},
        WARRIOR = {46146, 46162},
    },
    [45634] = { -- Breastplate of the Wayward Vanquisher
        DEATHKNIGHT = {46118, 46111},
        DRUID = {46186, 46194, 46159},
        MAGE = {46130},
        ROGUE = {46123},
    },
    [45635] = { -- Chestguard of the Wayward Conqueror
        PALADIN = {45381, 45374, 45375},
        PRIEST = {45395, 45389},
        WARLOCK = {45421},
    },
    [45636] = { -- Chestguard of the Wayward Protector
        HUNTER = {45364},
        SHAMAN = {45411, 45405, 45413},
        WARRIOR = {45424, 45429},
    },
    [45637] = { -- Chestguard of the Wayward Vanquisher
        DEATHKNIGHT = {45340, 45335},
        DRUID = {45354, 45348, 45358},
        MAGE = {45368},
        ROGUE = {45396},
    },
    [45638] = { -- Crown of the Wayward Conqueror
        PALADIN = {46180, 46156, 46175},
        PRIEST = {46172, 46197},
        WARLOCK = {46140},
    },
    [45639] = { -- Crown of the Wayward Protector
        HUNTER = {46143},
        SHAMAN = {46209, 46201, 46212},
        WARRIOR = {46166, 46151},
    },
    [45640] = { -- Crown of the Wayward Vanquisher
        DEATHKNIGHT = {46120, 46115},
        DRUID = {46184, 46161, 46191},
        MAGE = {46129},
        ROGUE = {46125},
    },
    [45641] = { -- Gauntlets of the Wayward Conqueror
        PALADIN = {46155, 46179, 46174},
        PRIEST = {46163, 46188},
        WARLOCK = {46135},
    },
    [45642] = { -- Gauntlets of the Wayward Protector
        HUNTER = {46142},
        SHAMAN = {46200, 46207, 46199},
        WARRIOR = {46148, 46164},
    },
    [45643] = { -- Gauntlets of the Wayward Vanquisher
        DEATHKNIGHT = {46113, 46119},
        DRUID = {46189, 46158, 46183},
        MAGE = {46132},
        ROGUE = {46124},
    },
    [45644] = { -- Gloves of the Wayward Conqueror
        PALADIN = {45376, 45370, 45383},
        PRIEST = {45392, 45387},
        WARLOCK = {45419},
    },
    [45645] = { -- Gloves of the Wayward Protector
        HUNTER = {45360},
        SHAMAN = {45401, 45414, 45406},
        WARRIOR = {45426, 45430},
    },
    [45646] = { -- Gloves of the Wayward Vanquisher
        DEATHKNIGHT = {45337, 45341},
        DRUID = {45345, 45355, 45351},
        MAGE = {46131},
        ROGUE = {45397},
    },
    [45647] = { -- Helm of the Wayward Conqueror
        PALADIN = {45377, 45372, 45382},
        PRIEST = {45386, 45391},
        WARLOCK = {45417},
    },
    [45648] = { -- Helm of the Wayward Protector
        HUNTER = {45361},
        SHAMAN = {45408, 45402, 45412},
        WARRIOR = {45425, 45431},
    },
    [45649] = { -- Helm of the Wayward Vanquisher
        DEATHKNIGHT = {45336, 45342},
        DRUID = {46313, 45346, 45356},
        MAGE = {45365},
        ROGUE = {45398},
    },
    [45650] = { -- Leggings of the Wayward Conqueror
        PALADIN = {45384, 45379, 45371},
        PRIEST = {45394, 45388},
        WARLOCK = {45420},
    },
    [45651] = { -- Leggings of the Wayward Protector
        HUNTER = {45362},
        SHAMAN = {45416, 45409, 45403},
        WARRIOR = {45432, 45427},
    },
    [45652] = { -- Leggings of the Wayward Vanquisher
        DEATHKNIGHT = {45338, 45343},
        DRUID = {45353, 45347, 45357},
        MAGE = {45367},
        ROGUE = {45399},
    },
    [45653] = { -- Legplates of the Wayward Conqueror
        PALADIN = {46176, 46153, 46181},
        PRIEST = {46170, 46195},
        WARLOCK = {46139},
    },
    [45654] = { -- Legplates of the Wayward Protector
        HUNTER = {46144},
        SHAMAN = {46208, 46210, 46202},
        WARRIOR = {46169, 46150},
    },
    [45655] = { -- Legplates of the Wayward Vanquisher
        DEATHKNIGHT = {46121, 46116},
        DRUID = {46192, 46185, 46160},
        MAGE = {46133},
        ROGUE = {46126},
    },
    [45656] = { -- Mantle of the Wayward Conqueror
        PALADIN = {46152, 46177, 46182},
        PRIEST = {46165, 46190},
        WARLOCK = {46136},
    },
    [45657] = { -- Mantle of the Wayward Protector
        HUNTER = {46145},
        SHAMAN = {46211, 46204, 46203},
        WARRIOR = {46149, 46167},
    },
    [45658] = { -- Mantle of the Wayward Vanquisher
        DEATHKNIGHT = {46122, 46117},
        DRUID = {46187, 46196, 46157},
        MAGE = {46134},
        ROGUE = {46127},
    },
    [45659] = { -- Spaulders of the Wayward Conqueror
        PALADIN = {45385, 45380, 45373},
        PRIEST = {45393, 45390},
        WARLOCK = {45422},
    },
    [45660] = { -- Spaulders of the Wayward Protector
        HUNTER = {45363},
        SHAMAN = {45410, 45404, 45415},
        WARRIOR = {45433, 45428},
    },
    [45661] = { -- Spaulders of the Wayward Vanquisher
        DEATHKNIGHT = {45344, 45339},
        DRUID = {45352, 45349, 45359},
        MAGE = {45369},
        ROGUE = {45400},
    },
    [47242] = { -- Trophy of the Crusade
        DEATHKNIGHT = {48481, 48482, 48483, 48484, 48485, 48553, 48554, 48555, 48556, 48557, 48496, 48497, 48498, 48499, 48500, 48538, 48539, 48540, 48541, 48542},
        DRUID = {48133, 48134, 48135, 48136, 48137, 48148, 48149, 48150, 48151, 48152, 48163, 48164, 48165, 48166, 48167, 48178, 48179, 48180, 48181, 48182, 48193, 48194, 48195, 48196, 48197, 48208, 48209, 48210, 48211, 48212},
        HUNTER = {48256, 48257, 48258, 48259, 48270, 48271, 48272, 48273, 48274, 48255},
        MAGE = {47753, 47754, 47755, 47756, 47757, 47768, 47769, 47770, 47771, 47772},
        PALADIN = {48640, 48641, 48657, 48658, 48659, 48660, 48661, 48575, 48576, 48577, 48578, 48579, 48590, 48591, 48592, 48593, 48594, 48607, 48608, 48609, 48610, 48611, 48622, 48623, 48624, 48625, 48626, 48637, 48638, 48639},
        PRIEST = {48096, 48064, 48065, 48066, 48077, 48078, 48079, 48080, 48081, 47983, 47984, 48062, 47985, 47986, 47987, 48063, 48092, 48093, 48094, 48095},
        ROGUE = {48224, 48225, 48226, 48227, 48238, 48239, 48240, 48241, 48242, 48223},
        SHAMAN = {48285, 48286, 48287, 48288, 48289, 48300, 48301, 48302, 48303, 48304, 48316, 48317, 48318, 48319, 48320, 48331, 48332, 48333, 48334, 48335, 48346, 48347, 48348, 48349, 48350, 48361, 48362, 48363, 48364, 48365},
        WARLOCK = {47778, 47779, 47780, 47781, 47782, 47803, 47804, 47805, 47806, 47807},
        WARRIOR = {48450, 48452, 48454, 48391, 48392, 48393, 48394, 48395, 48461, 48462, 48430, 48463, 48464, 48465, 48376, 48377, 48378, 48379, 48380, 48446},
    },
    [47557] = { -- Regalia of the Grand Conqueror
        PALADIN = {48642, 48643, 48644, 48645, 48646, 48647, 48648, 48649, 48650, 48651, 48580, 48581, 48582, 48583, 48584, 48585, 48586, 48587, 48588, 48589, 48612, 48613, 48614, 48615, 48616, 48617, 48618, 48619, 48620, 48621},
        PRIEST = {48058, 48033, 48035, 48037, 48091, 48029, 48082, 48083, 48084, 48085, 48086, 48087, 48088, 48089, 48090, 48059, 48060, 48061, 48057, 48031},
        WARLOCK = {47788, 47789, 47790, 47791, 47792, 47793, 47794, 47795, 47796, 47797},
    },
    [47558] = { -- Regalia of the Grand Protector
        HUNTER = {48260, 48261, 48262, 48263, 48264, 48265, 48266, 48267, 48268, 48269},
        SHAMAN = {48290, 48291, 48292, 48293, 48294, 48305, 48306, 48307, 48308, 48309, 48321, 48322, 48323, 48324, 48325, 48326, 48327, 48328, 48329, 48330, 48351, 48352, 48353, 48354, 48355, 48356, 48357, 48358, 48359, 48360},
        WARRIOR = {48384, 48385, 48451, 48447, 48453, 48455, 48396, 48397, 48398, 48399, 48400, 48433, 48466, 48467, 48468, 48469, 48470, 48381, 48382, 48383},
    },
    [47559] = { -- Regalia of the Grand Vanquisher
        DEATHKNIGHT = {48544, 48545, 48546, 48547, 48548, 48549, 48550, 48551, 48552, 48486, 48487, 48488, 48489, 48493, 48494, 48495, 48491, 48490, 48492, 48543},
        DRUID = {48138, 48139, 48140, 48141, 48142, 48143, 48144, 48145, 48146, 48147, 48168, 48169, 48170, 48171, 48172, 48173, 48174, 48175, 48176, 48177, 48198, 48199, 48200, 48201, 48202, 48203, 48204, 48205, 48206, 48207},
        MAGE = {47758, 47759, 47760, 47761, 47762, 47763, 47764, 47765, 47766, 47767},
        ROGUE = {48228, 48229, 48230, 48231, 48232, 48233, 48234, 48235, 48236, 48237},
    },
    [52025] = { -- Vanquisher's Mark of Sanctification
        DEATHKNIGHT = {51125, 51126, 51127, 51128, 51129, 51130, 51131, 51132, 51133, 51134},
        DRUID = {51136, 51137, 51138, 51139, 51140, 51141, 51142, 51143, 51144, 51145, 51146, 51147, 51148, 51149, 51135},
        MAGE = {51155, 51156, 51157, 51158, 51159},
        ROGUE = {51185, 51186, 51187, 51188, 51189},
    },
    [52026] = { -- Protector's Mark of Sanctification
        HUNTER = {51152, 51153, 51154, 51150, 51151},
        SHAMAN = {51200, 51201, 51202, 51203, 51204, 51190, 51191, 51192, 51193, 51194, 51195, 51196, 51197, 51198, 51199},
        WARRIOR = {51210, 51211, 51212, 51213, 51214, 51215, 51216, 51217, 51218, 51219},
    },
    [52027] = { -- Conqueror's Mark of Sanctification
        PALADIN = {51168, 51169, 51170, 51171, 51172, 51173, 51174, 51160, 51161, 51162, 51163, 51164, 51165, 51166, 51167},
        PRIEST = {51175, 51176, 51177, 51178, 51179, 51180, 51181, 51182, 51183, 51184},
        WARLOCK = {51208, 51209, 51205, 51206, 51207},
    },
    [52028] = { -- Vanquisher's Mark of Sanctification
        DEATHKNIGHT = {51305, 51306, 51307, 51308, 51309, 51310, 51311, 51312, 51313, 51314},
        DRUID = {51296, 51297, 51298, 51299, 51300, 51301, 51302, 51303, 51304, 51290, 51291, 51292, 51293, 51294, 51295},
        MAGE = {51280, 51281, 51282, 51283, 51284},
        ROGUE = {51250, 51251, 51252, 51253, 51254},
    },
    [52029] = { -- Protector's Mark of Sanctification
        HUNTER = {51288, 51289, 51285, 51286, 51287},
        SHAMAN = {51235, 51236, 51237, 51238, 51239, 51240, 51241, 51242, 51243, 51244, 51245, 51246, 51247, 51248, 51249},
        WARRIOR = {51220, 51221, 51222, 51223, 51224, 51225, 51226, 51227, 51228, 51229},
    },
    [52030] = { -- Conqueror's Mark of Sanctification
        PALADIN = {51265, 51266, 51267, 51268, 51269, 51270, 51271, 51272, 51273, 51274, 51275, 51276, 51277, 51278, 51279},
        PRIEST = {51264, 51255, 51256, 51257, 51258, 51259, 51260, 51261, 51262, 51263},
        WARLOCK = {51232, 51233, 51234, 51230, 51231},
    },
    -- 4.0 Bastion of Twilight
    [63682] = { -- Helm of the Forlorn Vanquisher
        DEATHKNIGHT = {60351, 60341},
        DRUID = {60282, 60286, 60277},
        MAGE = {60243},
        ROGUE = {60299},
    },
    [63683] = { -- Helm of the Forlorn Conqueror
        PALADIN = {60356, 60359, 60346},
        PRIEST = {60258, 60256},
        WARLOCK = {60249},
    },
    [63684] = { -- Helm of the Forlorn Protector
        HUNTER = {60303},
        SHAMAN = {60308, 60315, 60320},
        WARRIOR = {60328, 60325},
    },
    [64314] = { -- Mantle of the Forlorn Vanquisher
        DEATHKNIGHT = {60343, 60353},
        DRUID = {60279, 60284, 60289},
        MAGE = {60246},
        ROGUE = {60302},
    },
    [64315] = { -- Mantle of the Forlorn Conqueror
        PALADIN = {60362, 60348, 60358},
        PRIEST = {60262, 60253},
        WARLOCK = {60252},
    },
    [64316] = { -- Mantle of the Forlorn Protector
        HUNTER = {60306},
        SHAMAN = {60311, 60317, 60322},
        WARRIOR = {60327, 60331},
    },
    [65000] = { -- Crown of the Forlorn Protector
        HUNTER = {65206},
        SHAMAN = {65256, 65251, 65246},
        WARRIOR = {65266, 65271},
    },
    [65001] = { -- Crown of the Forlorn Conqueror
        PALADIN = {65216, 65226, 65221},
        PRIEST = {65235, 65230},
        WARLOCK = {65260},
    },
    [65002] = { -- Crown of the Forlorn Vanquisher
        DEATHKNIGHT = {65186, 65181},
        DRUID = {65200, 65195, 65190},
        MAGE = {65210},
        ROGUE = {65241},
    },
    [65087] = { -- Shoulders of the Forlorn Protector
        HUNTER = {65208},
        SHAMAN = {65248, 65258, 65253},
        WARRIOR = {65273, 65268},
    },
    [65088] = { -- Shoulders of the Forlorn Conqueror
        PALADIN = {65218, 65228, 65223},
        PRIEST = {65233, 65238},
        WARLOCK = {65263},
    },
    [65089] = { -- Shoulders of the Forlorn Vanquisher
        DEATHKNIGHT = {65188, 65183},
        DRUID = {65193, 65203, 65198},
        MAGE = {65213},
        ROGUE = {65243},
    },
    [67423] = { -- Chest of the Forlorn Conqueror
        PALADIN = {65224, 65219, 65214},
        PRIEST = {65232, 65237},
        WARLOCK = {65262},
    },
    [67424] = { -- Chest of the Forlorn Protector
        HUNTER = {65204},
        SHAMAN = {65249, 65244, 65254},
        WARRIOR = {65264, 65269},
    },
    [67425] = { -- Chest of the Forlorn Vanquisher
        DEATHKNIGHT = {65184, 65179},
        DRUID = {65192, 65202, 65197},
        MAGE = {65212},
        ROGUE = {65239},
    },
    [67426] = { -- Leggings of the Forlorn Vanquisher
        DEATHKNIGHT = {65187, 65182},
        DRUID = {65201, 65196, 65191},
        MAGE = {65211},
        ROGUE = {65242},
    },
    [67427] = { -- Leggings of the Forlorn Protector
        HUNTER = {65207},
        SHAMAN = {65257, 65252, 65247},
        WARRIOR = {65272, 65267},
    },
    [67428] = { -- Leggings of the Forlorn Conqueror
        PALADIN = {65217, 65227, 65222},
        PRIEST = {65236, 65231},
        WARLOCK = {65261},
    },
    [67429] = { -- Gauntlets of the Forlorn Conqueror
        PALADIN = {65225, 65220, 65215},
        PRIEST = {65234, 65229},
        WARLOCK = {65259},
    },
    [67430] = { -- Gauntlets of the Forlorn Protector
        HUNTER = {65205},
        SHAMAN = {65250, 65245, 65255},
        WARRIOR = {65265, 65270},
    },
    [67431] = { -- Gauntlets of the Forlorn Vanquisher
        DEATHKNIGHT = {65185, 65180},
        DRUID = {65194, 65189, 65199},
        MAGE = {65209},
        ROGUE = {65240},
    },
    -- 4.2.0 Firelands
    [71668] = { -- Helm of the Fiery Vanquisher
        DEATHKNIGHT = {70954, 71060},
        DRUID = {71108, 71098, 71103},
        MAGE = {71287},
        ROGUE = {71047},
    },
    [71669] = { -- Gauntlets of the Fiery Vanquisher (heroic)
        DEATHKNIGHT = {71482, 71477},
        DRUID = {71496, 71491, 71487},
        MAGE = {71507},
        ROGUE = {71538},
    },
    [71670] = { -- Crown of the Fiery Vanquisher (heroic)
        DEATHKNIGHT = {71483, 71478},
        DRUID = {71488, 71497, 71492},
        MAGE = {71508},
        ROGUE = {71539},
    },
    [71671] = { -- Leggings of the Fiery Vanquisher (heroic)
        DEATHKNIGHT = {71484, 71479},
        DRUID = {71489, 71498, 71493},
        MAGE = {71509},
        ROGUE = {71540},
    },
    [71672] = { -- Chest of the Fiery Vanquisher (heroic)
        DEATHKNIGHT = {71481, 71476},
        DRUID = {71486, 71499, 71494},
        MAGE = {71510},
        ROGUE = {71537},
    },
    [71673] = { -- Shoulders of the Fiery Vanquisher (heroic)
        DEATHKNIGHT = {71480, 71485},
        DRUID = {71490, 71500, 71495},
        MAGE = {71511},
        ROGUE = {71541},
    },
    [71674] = { -- Mantle of the Fiery Vanquisher
        DEATHKNIGHT = {71062, 70951},
        DRUID = {71106, 71111, 71101},
        MAGE = {71290},
        ROGUE = {71049},
    },
    [71675] = { -- Helm of the Fiery Conqueror
        PALADIN = {70948, 71093, 71065},
        PRIEST = {71272, 71277},
        WARLOCK = {71282},
    },
    [71676] = { -- Gauntlets of the Fiery Conqueror (heroic)
        PALADIN = {71513, 71523, 71518},
        PRIEST = {71532, 71527},
        WARLOCK = {71594},
    },
    [71677] = { -- Crown of the Fiery Conqueror (heroic)
        PALADIN = {71514, 71524, 71519},
        PRIEST = {71528, 71533},
        WARLOCK = {71595},
    },
    [71678] = { -- Leggings of the Fiery Conqueror (heroic)
        PALADIN = {71520, 71515, 71525},
        PRIEST = {71529, 71534},
        WARLOCK = {71596},
    },
    [71679] = { -- Chest of the Fiery Conqueror (heroic)
        PALADIN = {71512, 71522, 71517},
        PRIEST = {71530, 71535},
        WARLOCK = {71597},
    },
    [71680] = { -- Shoulders of the Fiery Conqueror (heroic)
        PALADIN = {71521, 71516, 71526},
        PRIEST = {71536, 71531},
        WARLOCK = {71598},
    },
    [71681] = { -- Mantle of the Fiery Conqueror
        PALADIN = {71095, 71067, 70946},
        PRIEST = {71275, 71280},
        WARLOCK = {71285},
    },
    [71682] = { -- Helm of the Fiery Protector
        HUNTER = {71051},
        SHAMAN = {71298, 71293, 71303},
        WARRIOR = {71070, 70944},
    },
    [71683] = { -- Gauntlets of the Fiery Protector (heroic)
        HUNTER = {71502},
        SHAMAN = {71553, 71548, 71543},
        WARRIOR = {71601, 71605},
    },
    [71684] = { -- Crown of the Fiery Protector (heroic)
        HUNTER = {71503},
        SHAMAN = {71544, 71554, 71549},
        WARRIOR = {71606, 71599},
    },
    [71685] = { -- Leggings of the Fiery Protector (heroic)
        HUNTER = {71504},
        SHAMAN = {71545, 71555, 71550},
        WARRIOR = {71602, 71607},
    },
    [71686] = { -- Chest of the Fiery Protector (heroic)
        HUNTER = {71501},
        SHAMAN = {71552, 71547, 71542},
        WARRIOR = {71600, 71604},
    },
    [71687] = { -- Shoulders of the Fiery Protector (heroic)
        HUNTER = {71505},
        SHAMAN = {71546, 71556, 71551},
        WARRIOR = {71608, 71603},
    },
    [71688] = { -- Mantle of the Fiery Protector
        HUNTER = {71053},
        SHAMAN = {71300, 71295, 71305},
        WARRIOR = {71072, 70941},
    },
    -- 4.3 Dragon Soul
    [78170] = { -- Shoulders of the Corrupted Vanquisher
        DEATHKNIGHT = {76978, 77012},
        DRUID = {76753, 77017, 77022},
        MAGE = {76216},
        ROGUE = {77027},
    },
    [78171] = { -- Leggings of the Corrupted Vanquisher
        DEATHKNIGHT = {76977, 77011},
        DRUID = {77016, 77020, 76751},
        MAGE = {76214},
        ROGUE = {77026},
    },
    [78172] = { -- Crown of the Corrupted Vanquisher
        DEATHKNIGHT = {76976, 77010},
        DRUID = {77019, 76750, 77015},
        MAGE = {76213},
        ROGUE = {77025},
    },
    [78173] = { -- Gauntlets of the Corrupted Vanquisher
        DEATHKNIGHT = {77009, 76975},
        DRUID = {77018, 76749, 77014},
        MAGE = {76212},
        ROGUE = {77024},
    },
    [78174] = { -- Chest of the Corrupted Vanquisher
        DEATHKNIGHT = {77008, 76974},
        DRUID = {76752, 77021, 77013},
        MAGE = {76215},
        ROGUE = {77023},
    },
    [78175] = { -- Shoulders of the Corrupted Protector
        HUNTER = {77032},
        SHAMAN = {76760, 77035, 77044},
        WARRIOR = {76992, 76987},
    },
    [78176] = { -- Leggings of the Corrupted Protector
        HUNTER = {77031},
        SHAMAN = {77043, 77036, 76759},
        WARRIOR = {76986, 76991},
    },
    [78177] = { -- Crown of the Corrupted Protector
        HUNTER = {77030},
        SHAMAN = {77042, 77037, 76758},
        WARRIOR = {76990, 76983},
    },
    [78178] = { -- Gauntlets of the Corrupted Protector
        HUNTER = {77029},
        SHAMAN = {77041, 76757, 77038},
        WARRIOR = {76985, 76989},
    },
    [78179] = { -- Chest of the Corrupted Protector
        HUNTER = {77028},
        SHAMAN = {77040, 76756, 77039},
        WARRIOR = {76984, 76988},
    },
    [78180] = { -- Shoulders of the Corrupted Conqueror
        PALADIN = {76769, 76878, 77007},
        PRIEST = {76344, 76361},
        WARLOCK = {76339},
    },
    [78181] = { -- Leggings of the Corrupted Conqueror
        PALADIN = {76768, 76877, 77006},
        PRIEST = {76346, 76359},
        WARLOCK = {76341},
    },
    [78182] = { -- Crown of the Corrupted Conqueror
        PALADIN = {76876, 77005, 76767},
        PRIEST = {76347, 76358},
        WARLOCK = {76342},
    },
    [78183] = { -- Gauntlets of the Corrupted Conqueror
        PALADIN = {76875, 77004, 76766},
        PRIEST = {76348, 76357},
        WARLOCK = {76343},
    },
    [78184] = { -- Chest of the Corrupted Conqueror
        PALADIN = {76874, 77003, 76765},
        PRIEST = {76360, 76345},
        WARLOCK = {76340},
    },
    [78847] = { -- Chest of the Corrupted Conqueror
        PALADIN = {78732, 78726, 78727},
        PRIEST = {78728, 78731},
        WARLOCK = {78730},
    },
    [78848] = { -- Chest of the Corrupted Protector
        HUNTER = {78661},
        SHAMAN = {78723, 78724, 78725},
        WARRIOR = {78657, 78658},
    },
    [78849] = { -- Chest of the Corrupted Vanquisher
        DEATHKNIGHT = {78659, 78663},
        DRUID = {78665, 78660, 78662},
        MAGE = {78729},
        ROGUE = {78664},
    },
    [78850] = { -- Crown of the Corrupted Conqueror
        PALADIN = {78692, 78693, 78695},
        PRIEST = {78700, 78703},
        WARLOCK = {78702},
    },
    [78851] = { -- Crown of the Corrupted Protector
        HUNTER = {78698},
        SHAMAN = {78691, 78685, 78686},
        WARRIOR = {78688, 78689},
    },
    [78852] = { -- Crown of the Corrupted Vanquisher
        DEATHKNIGHT = {78697, 78687},
        DRUID = {78696, 78690, 78694},
        MAGE = {78701},
        ROGUE = {78699},
    },
    [78853] = { -- Gauntlets of the Corrupted Conqueror
        PALADIN = {78673, 78675, 78677},
        PRIEST = {78682, 78683},
        WARLOCK = {78681},
    },
    [78854] = { -- Gauntlets of the Corrupted Protector
        HUNTER = {78674},
        SHAMAN = {78672, 78666, 78667},
        WARRIOR = {78668, 78669},
    },
    [78855] = { -- Gauntlets of the Corrupted Vanquisher
        DEATHKNIGHT = {78678, 78670},
        DRUID = {78680, 78676, 78684},
        MAGE = {78671},
        ROGUE = {78679},
    },
    [78856] = { -- Leggings of the Corrupted Conqueror
        PALADIN = {78712, 78715, 78717},
        PRIEST = {78722, 78719},
        WARLOCK = {78721},
    },
    [78857] = { -- Leggings of the Corrupted Protector
        HUNTER = {78709},
        SHAMAN = {78704, 78718, 78711},
        WARRIOR = {78705, 78706},
    },
    [78858] = { -- Leggings of the Corrupted Vanquisher
        DEATHKNIGHT = {78707, 78716},
        DRUID = {78713, 78714, 78710},
        MAGE = {78720},
        ROGUE = {78708},
    },
    [78859] = { -- Shoulders of the Corrupted Conqueror
        PALADIN = {78745, 78746, 78742},
        PRIEST = {78747, 78750},
        WARLOCK = {78749},
    },
    [78860] = { -- Shoulders of the Corrupted Protector
        HUNTER = {78737},
        SHAMAN = {78739, 78733, 78741},
        WARRIOR = {78734, 78735},
    },
    [78861] = { -- Shoulders of the Corrupted Vanquisher
        DEATHKNIGHT = {78736, 78751},
        DRUID = {78744, 78740, 78743},
        MAGE = {78748},
        ROGUE = {78738},
    },
    [78862] = { -- Chest of the Corrupted Vanquisher
        DEATHKNIGHT = {78754, 78758},
        DRUID = {78760, 78755, 78757},
        MAGE = {78824},
        ROGUE = {78759},
    },
    [78863] = { -- Chest of the Corrupted Conqueror
        PALADIN = {78827, 78821, 78822},
        PRIEST = {78826, 78823},
        WARLOCK = {78825},
    },
    [78864] = { -- Chest of the Corrupted Protector
        HUNTER = {78756},
        SHAMAN = {78818, 78819, 78820},
        WARRIOR = {78752, 78753},
    },
    [78865] = { -- Gauntlets of the Corrupted Vanquisher
        DEATHKNIGHT = {78773, 78765},
        DRUID = {78779, 78771, 78775},
        MAGE = {78766},
        ROGUE = {78774},
    },
    [78866] = { -- Gauntlets of the Corrupted Conqueror
        PALADIN = {78768, 78770, 78772},
        PRIEST = {78777, 78778},
        WARLOCK = {78776},
    },
    [78867] = { -- Gauntlets of the Corrupted Protector
        HUNTER = {78769},
        SHAMAN = {78761, 78762, 78767},
        WARRIOR = {78763, 78764},
    },
    [78868] = { -- Crown of the Corrupted Vanquisher
        DEATHKNIGHT = {78792, 78782},
        DRUID = {78785, 78789, 78791},
        MAGE = {78796},
        ROGUE = {78794},
    },
    [78869] = { -- Crown of the Corrupted Conqueror
        PALADIN = {78787, 78788, 78790},
        PRIEST = {78795, 78798},
        WARLOCK = {78797},
    },
    [78870] = { -- Crown of the Corrupted Protector
        HUNTER = {78793},
        SHAMAN = {78786, 78780, 78781},
        WARRIOR = {78784, 78783},
    },
    [78871] = { -- Leggings of the Corrupted Vanquisher
        DEATHKNIGHT = {78802, 78811},
        DRUID = {78808, 78809, 78805},
        MAGE = {78815},
        ROGUE = {78803},
    },
    [78872] = { -- Leggings of the Corrupted Conqueror
        PALADIN = {78810, 78812, 78807},
        PRIEST = {78817, 78814},
        WARLOCK = {78816},
    },
    [78873] = { -- Leggings of the Corrupted Protector
        HUNTER = {78804},
        SHAMAN = {78813, 78806, 78799},
        WARRIOR = {78800, 78801},
    },
    [78874] = { -- Shoulders of the Corrupted Vanquisher
        DEATHKNIGHT = {78846, 78831},
        DRUID = {78835, 78838, 78839},
        MAGE = {78843},
        ROGUE = {78833},
    },
    [78875] = { -- Shoulders of the Corrupted Conqueror
        PALADIN = {78840, 78841, 78837},
        PRIEST = {78842, 78845},
        WARLOCK = {78844},
    },
    [78876] = { -- Shoulders of the Corrupted Protector
        HUNTER = {78832},
        SHAMAN = {78836, 78834, 78828},
        WARRIOR = {78829, 78830},
    },
    -- Terrace of Endless Spring / Heart of Fear
    [89234] = { -- Helm of the Shadowy Vanquisher
        DEATHKNIGHT = {85336, 85316},
        DRUID = {85307, 85357, 85381, 85311},
        MAGE = {85377},
        ROGUE = {85301},
    },
    [89235] = { -- Helm of the Shadowy Conqueror
        PALADIN = {85321, 85346, 85341},
        PRIEST = {85362, 85365},
        WARLOCK = {85370},
    },
    [89236] = { -- Helm of the Shadowy Protector
        HUNTER = {85296},
        MONK = {85386, 85396, 85390},
        SHAMAN = {85291, 85286, 85351},
        WARRIOR = {85333, 85326},
    },
    [89237] = { -- Chest of the Shadowy Conqueror
        PALADIN = {85323, 85348, 85343},
        PRIEST = {85360, 85367},
        WARLOCK = {85372},
    },
    [89238] = { -- Chest of the Shadowy Protector
        HUNTER = {85298},
        MONK = {85392, 85394, 85388},
        SHAMAN = {85288, 85289, 85353},
        WARRIOR = {85328, 85332},
    },
    [89239] = { -- Chest of the Shadowy Vanquisher
        DEATHKNIGHT = {85338, 85318},
        DRUID = {85313, 85305, 85355, 85379},
        MAGE = {85375},
        ROGUE = {85303},
    },
    [89240] = { -- Gauntlets of the Shadowy Conqueror
        PALADIN = {85322, 85347, 85342},
        PRIEST = {85363, 85364},
        WARLOCK = {85369},
    },
    [89241] = { -- Gauntlets of the Shadowy Protector
        HUNTER = {85297},
        MONK = {85395, 85387, 85389},
        SHAMAN = {85352, 85290, 85287},
        WARRIOR = {85331, 85327},
    },
    [89242] = { -- Gauntlets of the Shadowy Vanquisher
        DEATHKNIGHT = {85337, 85317},
        DRUID = {85312, 85380, 85308, 85358},
        MAGE = {85378},
        ROGUE = {85302},
    },
    [89243] = { -- Leggings of the Shadowy Conqueror
        PALADIN = {85320, 85345, 85340},
        PRIEST = {85361, 85366},
        WARLOCK = {85371},
    },
    [89244] = { -- Leggings of the Shadowy Protector
        HUNTER = {85295},
        MONK = {85385, 85397, 85391},
        SHAMAN = {85292, 85285, 85350},
        WARRIOR = {85330, 85325},
    },
    [89245] = { -- Leggings of the Shadowy Vanquisher
        DEATHKNIGHT = {85315, 85335},
        DRUID = {85306, 85382, 85356, 85310},
        MAGE = {85376},
        ROGUE = {85300},
    },
    [89246] = { -- Shoulders of the Shadowy Conqueror
        PALADIN = {85344, 85339, 85319},
        PRIEST = {85368, 85359},
        WARLOCK = {85373},
    },
    [89247] = { -- Shoulders of the Shadowy Protector
        HUNTER = {85294},
        MONK = {85384, 85393, 85398},
        SHAMAN = {85349, 85284, 85293},
        WARRIOR = {85329, 85324},
    },
    [89248] = { -- Shoulders of the Shadowy Vanquisher
        DEATHKNIGHT = {85314, 85334},
        DRUID = {85304, 85354, 85309, 85383},
        MAGE = {85374},
        ROGUE = {85299},
    },
    [89249] = { -- Chest of the Shadowy Vanquisher
        DEATHKNIGHT = {86913, 86918},
        DRUID = {86936, 86938, 86923, 86931},
        MAGE = {87010},
        ROGUE = {87124},
    },
    [89250] = { -- Chest of the Shadowy Conqueror
        PALADIN = {87104, 87099, 87109},
        PRIEST = {87122, 87117},
        WARLOCK = {87190},
    },
    [89251] = { -- Chest of the Shadowy Protector
        HUNTER = {87002},
        MONK = {87094, 87084, 87092},
        SHAMAN = {87129, 87139, 87134},
        WARRIOR = {87193, 87197},
    },
    [89252] = { -- Leggings of the Shadowy Vanquisher
        DEATHKNIGHT = {86921, 86916},
        DRUID = {86930, 86941, 86926, 86935},
        MAGE = {87009},
        ROGUE = {87127},
    },
    [89253] = { -- Leggings of the Shadowy Conqueror
        PALADIN = {87112, 87107, 87102},
        PRIEST = {87121, 87116},
        WARLOCK = {87189},
    },
    [89254] = { -- Leggings of the Shadowy Protector
        HUNTER = {87005},
        MONK = {87097, 87091, 87087},
        SHAMAN = {87137, 87132, 87142},
        WARRIOR = {87200, 87195},
    },
    [89255] = { -- Gauntlets of the Shadowy Vanquisher
        DEATHKNIGHT = {86914, 86919},
        DRUID = {86928, 86939, 86924, 86933},
        MAGE = {87007},
        ROGUE = {87125},
    },
    [89256] = { -- Gauntlets of the Shadowy Conqueror
        PALADIN = {87105, 87100, 87110},
        PRIEST = {87114, 87119},
        WARLOCK = {87187},
    },
    [89257] = { -- Gauntlets of the Shadowy Protector
        HUNTER = {87003},
        MONK = {87089, 87085, 87095},
        SHAMAN = {87130, 87140, 87135},
        WARRIOR = {87194, 87198},
    },
    [89258] = { -- Helm of the Shadowy Vanquisher
        DEATHKNIGHT = {86920, 86915},
        DRUID = {86929, 86940, 86925, 86934},
        MAGE = {87008},
        ROGUE = {87126},
    },
    [89259] = { -- Helm of the Shadowy Conqueror
        PALADIN = {87106, 87101, 87111},
        PRIEST = {87120, 87115},
        WARLOCK = {87188},
    },
    [89260] = { -- Helm of the Shadowy Protector
        HUNTER = {87004},
        MONK = {87096, 87090, 87086},
        SHAMAN = {87136, 87131, 87141},
        WARRIOR = {87192, 87199},
    },
    [89261] = { -- Shoulders of the Shadowy Vanquisher
        DEATHKNIGHT = {86922, 86917},
        DRUID = {86937, 86932, 86942, 86927},
        MAGE = {87011},
        ROGUE = {87128},
    },
    [89262] = { -- Shoulders of the Shadowy Conqueror
        PALADIN = {87113, 87108, 87103},
        PRIEST = {87123, 87118},
        WARLOCK = {87191},
    },
    [89263] = { -- Shoulders of the Shadowy Protector
        HUNTER = {87006},
        MONK = {87088, 87098, 87093},
        SHAMAN = {87138, 87133, 87143},
        WARRIOR = {87201, 87196},
    },
    [89264] = { -- Chest of the Shadowy Vanquisher
        DEATHKNIGHT = {86658, 86678},
        DRUID = {86719, 86645, 86653, 86695},
        MAGE = {86715},
        ROGUE = {86643},
    },
    [89265] = { -- Chest of the Shadowy Conqueror
        PALADIN = {86688, 86683, 86663},
        PRIEST = {86707, 86700},
        WARLOCK = {86712},
    },
    [89266] = { -- Chest of the Shadowy Protector
        HUNTER = {86638},
        MONK = {86728, 86732, 86734},
        SHAMAN = {86628, 86629, 86693},
        WARRIOR = {86672, 86668},
    },
    [89267] = { -- Leggings of the Shadowy Vanquisher
        DEATHKNIGHT = {86675, 86655},
        DRUID = {86696, 86722, 86650, 86646},
        MAGE = {86716},
        ROGUE = {86640},
    },
    [89268] = { -- Leggings of the Shadowy Conqueror
        PALADIN = {86680, 86660, 86685},
        PRIEST = {86706, 86701},
        WARLOCK = {86711},
    },
    [89269] = { -- Leggings of the Shadowy Protector
        HUNTER = {86635},
        MONK = {86737, 86731, 86725},
        SHAMAN = {86632, 86625, 86690},
        WARRIOR = {86665, 86670},
    },
    [89270] = { -- Gauntlets of the Shadowy Vanquisher
        DEATHKNIGHT = {86657, 86677},
        DRUID = {86648, 86698, 86652, 86720},
        MAGE = {86718},
        ROGUE = {86642},
    },
    [89271] = { -- Gauntlets of the Shadowy Conqueror
        PALADIN = {86682, 86662, 86687},
        PRIEST = {86704, 86703},
        WARLOCK = {86709},
    },
    [89272] = { -- Gauntlets of the Shadowy Protector
        HUNTER = {86637},
        MONK = {86729, 86735, 86727},
        SHAMAN = {86627, 86692, 86630},
        WARRIOR = {86667, 86671},
    },
    [89273] = { -- Helm of the Shadowy Vanquisher
        DEATHKNIGHT = {86656, 86676},
        DRUID = {86697, 86651, 86721, 86647},
        MAGE = {86717},
        ROGUE = {86641},
    },
    [89274] = { -- Helm of the Shadowy Conqueror
        PALADIN = {86681, 86661, 86686},
        PRIEST = {86705, 86702},
        WARLOCK = {86710},
    },
    [89275] = { -- Helm of the Shadowy Protector
        HUNTER = {86636},
        MONK = {86736, 86730, 86726},
        SHAMAN = {86626, 86691, 86631},
        WARRIOR = {86673, 86666},
    },
    [89276] = { -- Shoulders of the Shadowy Vanquisher
        DEATHKNIGHT = {86674, 86654},
        DRUID = {86649, 86723, 86644, 86694},
        MAGE = {86714},
        ROGUE = {86639},
    },
    [89277] = { -- Shoulders of the Shadowy Conqueror
        PALADIN = {86659, 86684, 86679},
        PRIEST = {86699, 86708},
        WARLOCK = {86713},
    },
    [89278] = { -- Shoulders of the Shadowy Protector
        HUNTER = {86634},
        MONK = {86738, 86724, 86733},
        SHAMAN = {86624, 86633, 86689},
        WARRIOR = {86664, 86669},
    },
    -- Throne of Thunder
    [95569] = { -- Chest of the Crackling Vanquisher
        DEATHKNIGHT = {95225, 95230},
        DRUID = {95243, 95248, 95250, 95235},
        MAGE = {95263},
        ROGUE = {95305},
    },
    [95570] = { -- Gauntlets of the Crackling Vanquisher
        DEATHKNIGHT = {95226, 95231},
        DRUID = {95240, 95251, 95236, 95245},
        MAGE = {95260},
        ROGUE = {95306},
    },
    [95571] = { -- Helm of the Crackling Vanquisher
        DEATHKNIGHT = {95232, 95227},
        DRUID = {95241, 95252, 95237, 95246},
        MAGE = {95261},
        ROGUE = {95307},
    },
    [95572] = { -- Leggings of the Crackling Vanquisher
        DEATHKNIGHT = {95233, 95228},
        DRUID = {95242, 95253, 95238, 95247},
        MAGE = {95262},
        ROGUE = {95308},
    },
    [95573] = { -- Shoulders of the Crackling Vanquisher
        DEATHKNIGHT = {95234, 95229},
        DRUID = {95249, 95244, 95254, 95239},
        MAGE = {95264},
        ROGUE = {95309},
    },
    [95574] = { -- Chest of the Crackling Conqueror
        PALADIN = {95280, 95290, 95285},
        PRIEST = {95298, 95303},
        WARLOCK = {95328},
    },
    [95575] = { -- Gauntlets of the Crackling Conqueror
        PALADIN = {95281, 95291, 95286},
        PRIEST = {95300, 95295},
        WARLOCK = {95325},
    },
    [95576] = { -- Leggings of the Crackling Conqueror
        PALADIN = {95288, 95283, 95293},
        PRIEST = {95297, 95302},
        WARLOCK = {95327},
    },
    [95577] = { -- Helm of the Crackling Conqueror
        PALADIN = {95282, 95292, 95287},
        PRIEST = {95296, 95301},
        WARLOCK = {95326},
    },
    [95578] = { -- Shoulders of the Crackling Conqueror
        PALADIN = {95289, 95284, 95294},
        PRIEST = {95304, 95299},
        WARLOCK = {95329},
    },
    [95579] = { -- Chest of the Crackling Protector
        HUNTER = {95255},
        MONK = {95265, 95275, 95273},
        SHAMAN = {95320, 95315, 95310},
        WARRIOR = {95331, 95335},
    },
    [95580] = { -- Gauntlets of the Crackling Protector
        HUNTER = {95256},
        MONK = {95266, 95276, 95270},
        SHAMAN = {95321, 95316, 95311},
        WARRIOR = {95336, 95332},
    },
    [95581] = { -- Leggings of the Crackling Protector
        HUNTER = {95258},
        MONK = {95272, 95268, 95278},
        SHAMAN = {95313, 95323, 95318},
        WARRIOR = {95338, 95333},
    },
    [95582] = { -- Helm of the Crackling Protector
        HUNTER = {95257},
        MONK = {95267, 95277, 95271},
        SHAMAN = {95312, 95322, 95317},
        WARRIOR = {95337, 95330},
    },
    [95583] = { -- Shoulders of the Crackling Protector
        HUNTER = {95259},
        MONK = {95274, 95269, 95279},
        SHAMAN = {95314, 95324, 95319},
        WARRIOR = {95339, 95334},
    },
    [95822] = { -- Chest of the Crackling Vanquisher
        DEATHKNIGHT = {95825, 95830},
        DRUID = {95848, 95850, 95835, 95843},
        MAGE = {95893},
        ROGUE = {95935},
    },
    [95823] = { -- Chest of the Crackling Conqueror
        PALADIN = {95920, 95915, 95910},
        PRIEST = {95928, 95933},
        WARLOCK = {95984},
    },
    [95824] = { -- Chest of the Crackling Protector
        HUNTER = {95882},
        MONK = {95903, 95905, 95895},
        SHAMAN = {95945, 95940, 95950},
        WARRIOR = {95987, 95991},
    },
    [95855] = { -- Gauntlets of the Crackling Vanquisher
        DEATHKNIGHT = {95826, 95831},
        DRUID = {95840, 95851, 95836, 95845},
        MAGE = {95890},
        ROGUE = {95936},
    },
    [95856] = { -- Gauntlets of the Crackling Conqueror
        PALADIN = {95921, 95916, 95911},
        PRIEST = {95930, 95925},
        WARLOCK = {95981},
    },
    [95857] = { -- Gauntlets of the Crackling Protector
        HUNTER = {95883},
        MONK = {95896, 95906, 95900},
        SHAMAN = {95946, 95941, 95951},
        WARRIOR = {95992, 95988},
    },
    [95879] = { -- Helm of the Crackling Vanquisher
        DEATHKNIGHT = {95832, 95827},
        DRUID = {95841, 95852, 95837, 95846},
        MAGE = {95891},
        ROGUE = {95937},
    },
    [95880] = { -- Helm of the Crackling Conqueror
        PALADIN = {95912, 95922, 95917},
        PRIEST = {95931, 95926},
        WARLOCK = {95982},
    },
    [95881] = { -- Helm of the Crackling Protector
        HUNTER = {95884},
        MONK = {95897, 95907, 95901},
        SHAMAN = {95952, 95947, 95942},
        WARRIOR = {95993, 95986},
    },
    [95887] = { -- Leggings of the Crackling Vanquisher
        DEATHKNIGHT = {95833, 95828},
        DRUID = {95842, 95853, 95838, 95847},
        MAGE = {95892},
        ROGUE = {95938},
    },
    [95888] = { -- Leggings of the Crackling Conqueror
        PALADIN = {95913, 95923, 95918},
        PRIEST = {95932, 95927},
        WARLOCK = {95983},
    },
    [95889] = { -- Leggings of the Crackling Protector
        HUNTER = {95885},
        MONK = {95898, 95908, 95902},
        SHAMAN = {95953, 95948, 95943},
        WARRIOR = {95994, 95989},
    },
    [95955] = { -- Shoulders of the Crackling Vanquisher
        DEATHKNIGHT = {95834, 95829},
        DRUID = {95849, 95844, 95854, 95839},
        MAGE = {95894},
        ROGUE = {95939},
    },
    [95956] = { -- Shoulders of the Crackling Conqueror
        PALADIN = {95914, 95924, 95919},
        PRIEST = {95929, 95934},
        WARLOCK = {95985},
    },
    [95957] = { -- Shoulders of the Crackling Protector
        HUNTER = {95886},
        MONK = {95904, 95899, 95909},
        SHAMAN = {95944, 95954, 95949},
        WARRIOR = {95995, 95990},
    },
    [96566] = { -- Chest of the Crackling Vanquisher
        DEATHKNIGHT = {96569, 96574},
        DRUID = {96592, 96587, 96579, 96594},
        MAGE = {96637},
        ROGUE = {96679},
    },
    [96567] = { -- Chest of the Crackling Conqueror
        PALADIN = {96664, 96659, 96654},
        PRIEST = {96672, 96677},
        WARLOCK = {96728},
    },
    [96568] = { -- Chest of the Crackling Protector
        HUNTER = {96626},
        MONK = {96647, 96649, 96639},
        SHAMAN = {96689, 96684, 96694},
        WARRIOR = {96731, 96735},
    },
    [96599] = { -- Gauntlets of the Crackling Vanquisher
        DEATHKNIGHT = {96570, 96575},
        DRUID = {96584, 96595, 96580, 96589},
        MAGE = {96634},
        ROGUE = {96680},
    },
    [96600] = { -- Gauntlets of the Crackling Conqueror
        PALADIN = {96665, 96660, 96655},
        PRIEST = {96674, 96669},
        WARLOCK = {96725},
    },
    [96601] = { -- Gauntlets of the Crackling Protector
        HUNTER = {96627},
        MONK = {96640, 96650, 96644},
        SHAMAN = {96690, 96685, 96695},
        WARRIOR = {96736, 96732},
    },
    [96623] = { -- Helm of the Crackling Vanquisher
        DEATHKNIGHT = {96576, 96571},
        DRUID = {96585, 96596, 96581, 96590},
        MAGE = {96635},
        ROGUE = {96681},
    },
    [96624] = { -- Helm of the Crackling Conqueror
        PALADIN = {96656, 96666, 96661},
        PRIEST = {96675, 96670},
        WARLOCK = {96726},
    },
    [96625] = { -- Helm of the Crackling Protector
        HUNTER = {96628},
        MONK = {96641, 96651, 96645},
        SHAMAN = {96696, 96691, 96686},
        WARRIOR = {96737, 96730},
    },
    [96631] = { -- Leggings of the Crackling Vanquisher
        DEATHKNIGHT = {96577, 96572},
        DRUID = {96586, 96597, 96582, 96591},
        MAGE = {96636},
        ROGUE = {96682},
    },
    [96632] = { -- Leggings of the Crackling Conqueror
        PALADIN = {96657, 96667, 96662},
        PRIEST = {96676, 96671},
        WARLOCK = {96727},
    },
    [96633] = { -- Leggings of the Crackling Protector
        HUNTER = {96629},
        MONK = {96642, 96652, 96646},
        SHAMAN = {96697, 96692, 96687},
        WARRIOR = {96738, 96733},
    },
    [96699] = { -- Shoulders of the Crackling Vanquisher
        DEATHKNIGHT = {96578, 96573},
        DRUID = {96593, 96588, 96598, 96583},
        MAGE = {96638},
        ROGUE = {96683},
    },
    [96700] = { -- Shoulders of the Crackling Conqueror
        PALADIN = {96658, 96668, 96663},
        PRIEST = {96673, 96678},
        WARLOCK = {96729},
    },
    [96701] = { -- Shoulders of the Crackling Protector
        HUNTER = {96630},
        MONK = {96648, 96643, 96653},
        SHAMAN = {96688, 96698, 96693},
        WARRIOR = {96739, 96734},
    },
    -- Siege of Orgrimmar
    [99667] = { -- Gauntlets of the Cursed Protector
        HUNTER = {99086},
        MONK = {99064, 99072, 99068},
        SHAMAN = {99088, 98993, 98988},
        WARRIOR = {99034, 99038},
    },
    [99668] = { -- Shoulders of the Cursed Vanquisher
        DEATHKNIGHT = {99040, 99059},
        DRUID = {99016, 98978, 99022, 98998},
        MAGE = {99079},
        ROGUE = {99010},
    },
    [99669] = { -- Shoulders of the Cursed Conqueror
        PALADIN = {98987, 99076, 99027},
        PRIEST = {99018, 99005},
        WARLOCK = {99045},
    },
    [99670] = { -- Shoulders of the Cursed Protector
        HUNTER = {99082},
        MONK = {99075, 99051, 99062},
        SHAMAN = {98977, 99091, 98991},
        WARRIOR = {99036, 99030},
    },
    [99671] = { -- Helm of the Cursed Vanquisher
        DEATHKNIGHT = {99049, 99057},
        DRUID = {99001, 98995, 99043, 99013},
        MAGE = {99084},
        ROGUE = {99008},
    },
    [99672] = { -- Helm of the Cursed Conqueror
        PALADIN = {98985, 98979, 99029},
        PRIEST = {99024, 99020},
        WARLOCK = {99054},
    },
    [99673] = { -- Helm of the Cursed Protector
        HUNTER = {99080},
        MONK = {99065, 99069, 99073},
        SHAMAN = {99089, 98989, 98983},
        WARRIOR = {99032, 99046},
    },
    [99674] = { -- Leggings of the Cursed Vanquisher
        DEATHKNIGHT = {99058, 99039},
        DRUID = {99044, 98996, 98981, 99014},
        MAGE = {99077},
        ROGUE = {99009},
    },
    [99675] = { -- Leggings of the Cursed Conqueror
        PALADIN = {99026, 98986, 98980},
        PRIEST = {99025, 99021},
        WARLOCK = {99055},
    },
    [99676] = { -- Leggings of the Cursed Protector
        HUNTER = {99081},
        MONK = {99050, 99074, 99070},
        SHAMAN = {98984, 99090, 98990},
        WARRIOR = {99033, 99035},
    },
    [99677] = { -- Chest of the Cursed Vanquisher
        DEATHKNIGHT = {99066, 99060},
        DRUID = {99041, 98997, 98999, 99015},
        MAGE = {99078},
        ROGUE = {99006},
    },
    [99678] = { -- Chest of the Cursed Conqueror
        PALADIN = {99003, 99052, 99031},
        PRIEST = {99017, 99004},
        WARLOCK = {99056},
    },
    [99679] = { -- Chest of the Cursed Protector
        HUNTER = {99085},
        MONK = {99071, 99061, 99063},
        SHAMAN = {98992, 99011, 99087},
        WARRIOR = {99037, 99047},
    },
    [99680] = { -- Gauntlets of the Cursed Vanquisher
        DEATHKNIGHT = {99048, 99067},
        DRUID = {99000, 98994, 99042, 99012},
        MAGE = {99083},
        ROGUE = {99007},
    },
    [99681] = { -- Gauntlets of the Cursed Conqueror
        PALADIN = {99002, 99028, 98982},
        PRIEST = {99019, 99023},
        WARLOCK = {99053},
    },
    [99682] = { -- Gauntlets of the Cursed Vanquisher
        DEATHKNIGHT = {99193, 99189},
        DRUID = {99185, 99163, 99181, 99174},
        MAGE = {99160},
        ROGUE = {99113},
    },
    [99683] = { -- Helm of the Cursed Vanquisher
        DEATHKNIGHT = {99194, 99190},
        DRUID = {99178, 99164, 99182, 99175},
        MAGE = {99161},
        ROGUE = {99114},
    },
    [99684] = { -- Leggings of the Cursed Vanquisher
        DEATHKNIGHT = {99186, 99191},
        DRUID = {99176, 99171, 99165, 99183},
        MAGE = {99162},
        ROGUE = {99115},
    },
    [99685] = { -- Shoulders of the Cursed Vanquisher
        DEATHKNIGHT = {99187, 99179},
        DRUID = {99184, 99169, 99173, 99166},
        MAGE = {99153},
        ROGUE = {99116},
    },
    [99686] = { -- Chest of the Cursed Conqueror
        PALADIN = {99136, 99133, 99126},
        PRIEST = {99110, 99119},
        WARLOCK = {99204},
    },
    [99687] = { -- Gauntlets of the Cursed Conqueror
        PALADIN = {99137, 99134, 99127},
        PRIEST = {99121, 99131},
        WARLOCK = {99096},
    },
    [99688] = { -- Leggings of the Cursed Conqueror
        PALADIN = {99129, 99139, 99124},
        PRIEST = {99123, 99118},
        WARLOCK = {99098},
    },
    [99689] = { -- Helm of the Cursed Conqueror
        PALADIN = {99128, 99138, 99135},
        PRIEST = {99122, 99117},
        WARLOCK = {99097},
    },
    [99690] = { -- Shoulders of the Cursed Conqueror
        PALADIN = {99130, 99132, 99125},
        PRIEST = {99120, 99111},
        WARLOCK = {99205},
    },
    [99691] = { -- Chest of the Cursed Protector
        HUNTER = {99167},
        MONK = {99154, 99140, 99150},
        SHAMAN = {99106, 99107, 99101},
        WARRIOR = {99201, 99197},
    },
    [99692] = { -- Gauntlets of the Cursed Protector
        HUNTER = {99168},
        MONK = {99155, 99147, 99141},
        SHAMAN = {99092, 99102, 99108},
        WARRIOR = {99202, 99198},
    },
    [99693] = { -- Leggings of the Cursed Protector
        HUNTER = {99158},
        MONK = {99145, 99149, 99143},
        SHAMAN = {99104, 99099, 99094},
        WARRIOR = {99195, 99199},
    },
    [99694] = { -- Helm of the Cursed Protector
        HUNTER = {99157},
        MONK = {99148, 99142, 99156},
        SHAMAN = {99109, 99093, 99103},
        WARRIOR = {99203, 99206},
    },
    [99695] = { -- Shoulders of the Cursed Protector
        HUNTER = {99159},
        MONK = {99144, 99146, 99151},
        SHAMAN = {99105, 99100, 99095},
        WARRIOR = {99200, 99196},
    },
    [99696] = { -- Chest of the Cursed Vanquisher
        DEATHKNIGHT = {99192, 99188},
        DRUID = {99180, 99177, 99170, 99172},
        MAGE = {99152},
        ROGUE = {99112},
    },
    [99712] = { -- Leggings of the Cursed Conqueror
        PALADIN = {99377, 99371, 99372},
        PRIEST = {99361, 99367},
        WARLOCK = {99426},
    },
    [99713] = { -- Leggings of the Cursed Protector
        HUNTER = {99403},
        MONK = {99385, 99394, 99390},
        SHAMAN = {99354, 99333, 99342},
        WARRIOR = {99410, 99413},
    },
    [99714] = { -- Chest of the Cursed Vanquisher
        DEATHKNIGHT = {99330, 99335},
        DRUID = {99427, 99430, 99419, 99326},
        MAGE = {99400},
        ROGUE = {99356},
    },
    [99715] = { -- Chest of the Cursed Conqueror
        PALADIN = {99368, 99387, 99374},
        PRIEST = {99362, 99357},
        WARLOCK = {99416},
    },
    [99716] = { -- Chest of the Cursed Protector
        HUNTER = {99405},
        MONK = {99396, 99382, 99391},
        SHAMAN = {99344, 99347, 99351},
        WARRIOR = {99411, 99415},
    },
    [99717] = { -- Shoulders of the Cursed Vanquisher
        DEATHKNIGHT = {99339, 99325},
        DRUID = {99322, 99428, 99431, 99423},
        MAGE = {99401},
        ROGUE = {99350},
    },
    [99718] = { -- Shoulders of the Cursed Conqueror
        PALADIN = {99378, 99364, 99373},
        PRIEST = {99363, 99358},
        WARLOCK = {99417},
    },
    [99719] = { -- Shoulders of the Cursed Protector
        HUNTER = {99404},
        MONK = {99386, 99395, 99381},
        SHAMAN = {99346, 99334, 99343},
        WARRIOR = {99414, 99407},
    },
    [99720] = { -- Gauntlets of the Cursed Vanquisher
        DEATHKNIGHT = {99336, 99331},
        DRUID = {99432, 99435, 99420, 99327},
        MAGE = {99397},
        ROGUE = {99355},
    },
    [99721] = { -- Gauntlets of the Cursed Conqueror
        PALADIN = {99369, 99380, 99375},
        PRIEST = {99365, 99359},
        WARLOCK = {99424},
    },
    [99722] = { -- Gauntlets of the Cursed Protector
        HUNTER = {99406},
        MONK = {99392, 99388, 99383},
        SHAMAN = {99352, 99345, 99340},
        WARRIOR = {99408, 99412},
    },
    [99723] = { -- Helm of the Cursed Vanquisher
        DEATHKNIGHT = {99337, 99323},
        DRUID = {99328, 99433, 99436, 99421},
        MAGE = {99398},
        ROGUE = {99348},
    },
    [99724] = { -- Helm of the Cursed Conqueror
        PALADIN = {99376, 99370, 99379},
        PRIEST = {99360, 99366},
        WARLOCK = {99425},
    },
    [99725] = { -- Helm of the Cursed Protector
        HUNTER = {99402},
        MONK = {99384, 99393, 99389},
        SHAMAN = {99353, 99332, 99341},
        WARRIOR = {99409, 99418},
    },
    [99726] = { -- Leggings of the Cursed Vanquisher
        DEATHKNIGHT = {99338, 99324},
        DRUID = {99329, 99434, 99429, 99422},
        MAGE = {99399},
        ROGUE = {99349},
    },
    [99742] = { -- Chest of the Cursed Vanquisher
        DEATHKNIGHT = {99608, 99640},
        DRUID = {99622, 99632, 99620, 99582},
        MAGE = {99658},
        ROGUE = {99629},
    },
    [99743] = { -- Chest of the Cursed Conqueror
        PALADIN = {99626, 99566, 99598},
        PRIEST = {99584, 99627},
        WARLOCK = {99570},
    },
    [99744] = { -- Chest of the Cursed Protector
        HUNTER = {99577},
        MONK = {99641, 99555, 99643},
        SHAMAN = {99579, 99636, 99615},
        WARRIOR = {99562, 99603},
    },
    [99745] = { -- Gauntlets of the Cursed Vanquisher
        DEATHKNIGHT = {99609, 99604},
        DRUID = {99617, 99637, 99633, 99623},
        MAGE = {99575},
        ROGUE = {99630},
    },
    [99746] = { -- Gauntlets of the Cursed Conqueror
        PALADIN = {99648, 99625, 99595},
        PRIEST = {99586, 99590},
        WARLOCK = {99567},
    },
    [99747] = { -- Gauntlets of the Cursed Protector
        HUNTER = {99578},
        MONK = {99552, 99556, 99644},
        SHAMAN = {99616, 99611, 99580},
        WARRIOR = {99563, 99559},
    },
    [99748] = { -- Helm of the Cursed Vanquisher
        DEATHKNIGHT = {99571, 99605},
        DRUID = {99624, 99618, 99638, 99599},
        MAGE = {99576},
        ROGUE = {99631},
    },
    [99749] = { -- Helm of the Cursed Conqueror
        PALADIN = {99665, 99651, 99596},
        PRIEST = {99587, 99591},
        WARLOCK = {99568},
    },
    [99750] = { -- Helm of the Cursed Protector
        HUNTER = {99660},
        MONK = {99553, 99653, 99607},
        SHAMAN = {99649, 99612, 99645},
        WARRIOR = {99602, 99557},
    },
    [99751] = { -- Leggings of the Cursed Vanquisher
        DEATHKNIGHT = {99564, 99572},
        DRUID = {99600, 99610, 99619, 99581},
        MAGE = {99657},
        ROGUE = {99634},
    },
    [99752] = { -- Leggings of the Cursed Conqueror
        PALADIN = {99593, 99666, 99661},
        PRIEST = {99592, 99588},
        WARLOCK = {99569},
    },
    [99753] = { -- Leggings of the Cursed Protector
        HUNTER = {99573},
        MONK = {99654, 99554, 99606},
        SHAMAN = {99650, 99613, 99646},
        WARRIOR = {99560, 99558},
    },
    [99754] = { -- Shoulders of the Cursed Vanquisher
        DEATHKNIGHT = {99652, 99639},
        DRUID = {99664, 99621, 99589, 99583},
        MAGE = {99659},
        ROGUE = {99635},
    },
    [99755] = { -- Shoulders of the Cursed Conqueror
        PALADIN = {99656, 99594, 99662},
        PRIEST = {99585, 99628},
        WARLOCK = {99601},
    },
    [99756] = { -- Shoulders of the Cursed Protector
        HUNTER = {99574},
        MONK = {99642, 99565, 99655},
        SHAMAN = {99663, 99614, 99647},
        WARRIOR = {99561, 99597},
    },
    -- This isn't generated by update.py!
    -- 5.4 Timeless Isle
    [102263] = { -- Timeless Plate Chestpiece
        PLATE = {101789, 101819, 101851, 101878, 101908, 101938},
    },
    [102264] = { -- Timeless Plate Boots
        PLATE = {101797, 101825, 101859, 101886, 101914, 101946},
    },
    [102265] = { -- Timeless Plate Gloves
        PLATE = {101791, 101820, 101853, 101880, 101909, 101940},
    },
    [102266] = { -- Timeless Plate Helm
        PLATE = {101793, 101822, 101855, 101882, 101911, 101942},
    },
    [102267] = { -- Timeless Plate Leggings
        PLATE = {101794, 101823, 101856, 101883, 101912, 101943},
    },
    [102268] = { -- Timeless Plate Spaulders
        PLATE = {101796, 101824, 101858, 101885, 101913, 101945},
    },
    [102269] = { -- Timeless Plate Belt
        PLATE = {101792, 101821, 101854, 101881, 101910, 101941},
    },
    [102270] = { -- Timeless Mail Chestpiece
        MAIL = {101837, 101845, 101926, 101934},
    },
    [102271] = { -- Timeless Mail Boots
        MAIL = {101833, 101841, 101922, 101930},
    },
    [102272] = { -- Timeless Mail Gloves
        MAIL = {101832, 101840, 101921, 101929},
    },
    [102273] = { -- Timeless Mail Helm
        MAIL = {101834, 101842, 101923, 101931},
    },
    [102274] = { -- Timeless Mail Leggings
        MAIL = {101835, 101843, 101924, 101932},
    },
    [102275] = { -- Timeless Mail Spaulders
        MAIL = {101836, 101844, 101925, 101933},
    },
    [102276] = { -- Timeless Mail Belt
        MAIL = {101830, 101838, 101919, 101927},
    },
    [102277] = { -- Timeless Leather Chestpiece
        LEATHER = {101786, 101867, 101875, 101954},
    },
    [102278] = { -- Timeless Leather Boots
        LEATHER = {101782, 101863, 101871, 101950},
    },
    [102279] = { -- Timeless Leather Gloves
        LEATHER = {101784, 101865, 101873, 101952},
    },
    [102280] = { -- Timeless Leather Helm
        LEATHER = {101785, 101866, 101874, 101953},
    },
    [102281] = { -- Timeless Leather Leggings
        LEATHER = {101783, 101864, 101872, 101951},
    },
    [102282] = { -- Timeless Leather Spaulders
        LEATHER = {101787, 101868, 101876, 101955},
    },
    [102283] = { -- Timeless Leather Belt
        LEATHER = {101788, 101869, 101877, 101956},
    },
    [102284] = { -- Timeless Cloth Robes
        CLOTH = {101806, 101815, 101895, 101904},
    },
    [102285] = { -- Timeless Cloth Boots
        CLOTH = {101807, 101816, 101896, 101905},
    },
    [102286] = { -- Timeless Cloth Gloves
        CLOTH = {101803, 101813, 101892, 101902},
    },
    [102287] = { -- Timeless Cloth Helm
        CLOTH = {101802, 101812, 101891, 101901},
    },
    [102288] = { -- Timeless Cloth Leggings
        CLOTH = {101804, 101814, 101893, 101903},
    },
    [102289] = { -- Timeless Cloth Spaulders
        CLOTH = {101808, 101817, 101897, 101906},
    },
    [102290] = { -- Timeless Cloth Belt
        CLOTH = {101801, 101811, 101890, 101900},
    },
    [102291] = { -- Timeless Signet
        ALL = {101798, 101809, 101829, 101850, 101860, 101887, 101898, 101918, 101937, 101947},
    },
    [102318] = { -- Timeless Cloak
        ALL = {101790, 101800, 101828, 101848, 101852, 101879, 101889, 101917, 101935, 101939},
    },
    [102320] = { -- Timeless Plate Bracers
        PLATE = {101799, 101826, 101861, 101888, 101915, 101948},
    },
    [102321] = { -- Timeless Cloth Bracers
        CLOTH = {101810, 101818, 101899, 101907},
    },
    [102322] = { -- Timeless Leather Bracers
        LEATHER = {101781, 101862, 101870, 101949},
    },
    [102323] = { -- Timeless Mail Bracers
        MAIL = {101831, 101839, 101920, 101928},
    },
    [104345] = { -- Timeless Lavalliere
        ALL = {101795, 101805, 101827, 101849, 101857, 101884, 101894, 101916, 101936, 101944},
    },
    [104347] = { -- Timeless Curio
        ALL = {103686, 103687, 103688, 103689, 103690},
    },
    -- 6.2 Tanaan Jungle Baleful
    [128348] = { -- Baleful Spaulders
        PLATE = {124590},
        MAIL = {124589},
        LEATHER = {124588},
        CLOTH = {124587},
    },
    [124550] = { -- Baleful Bracers
        PLATE = {124566},
        MAIL = {124565},
        LEATHER = {124564},
        CLOTH = {124563},
    },
    [124551] = { -- Baleful Tunic
        PLATE = {124569},
        MAIL = {124568},
        LEATHER = {124567},
        CLOTH = {124570},
    },
    [124552] = { -- Baleful Treads
        PLATE = {124574},
        MAIL = {124573},
        LEATHER = {124572},
        CLOTH = {124571},
    },
    [124553] = { -- Baleful Gauntlets
        PLATE = {124578},
        MAIL = {124577},
        LEATHER = {124576},
        CLOTH = {124575},
    },
    [124554] = { -- Baleful Hood
        PLATE = {124582},
        MAIL = {124581},
        LEATHER = {124580},
        CLOTH = {124579},
    },
    [124555] = { -- Baleful Leggings
        PLATE = {124586},
        MAIL = {124585},
        LEATHER = {124584},
        CLOTH = {124583},
    },
    [124556] = { -- Baleful Spaulders
        PLATE = {124590},
        MAIL = {124589},
        LEATHER = {124588},
        CLOTH = {124587},
    },
    [124557] = { -- Baleful Girdle
        PLATE = {124594},
        MAIL = {124593},
        LEATHER = {124592},
        CLOTH = {124591},
    },
    [124558] = { -- Baleful Ring
        ALL = {124595, 124596, 124598, 124601, 124602, 124604},
    },
    [124559] = { -- Baleful Choker
        ALL = {124607, 124608, 124609, 124610, 124611, 124612},
    },
    [124560] = { -- Baleful Cloak
        ALL = {124613, 124614, 124615, 124616, 124617, 124618},
    },
    [124561] = { -- Baleful Trinket
        ALL = {124619, 124620, 124621, 124622, 124623},
    },
    [127798] = { -- Baleful Ring
        ALL = {124595, 124596, 124598, 124601, 124602, 124604},
    },
    [127799] = { -- Baleful Pendant
        ALL = {124607, 124608, 124609, 124610, 124611, 124612},
    },
    [127800] = { -- Baleful Cloak
        ALL = {124613, 124614, 124615, 124616, 124617, 124618},
    },
    [124562] = { -- Baleful Armament
        ALL = {124624, 124625, 124626, 124627, 124628, 124629, 124630, 124631},
    },
    -- the rest of the baleful items were cooperation / mission rewards
    [127777] = { -- Baleful Cloth Bracers
        CLOTH = {124563},
    },
    [127778] = { -- Baleful Cloth Robe
        CLOTH = {124570},
    },
    [127779] = { -- Baleful Cloth Treads
        CLOTH = {124571},
    },
    [127780] = { -- Baleful Cloth Gauntlets
        CLOTH = {124575},
    },
    [127781] = { -- Baleful Cloth Hood
        CLOTH = {124579},
    },
    [127782] = { -- Baleful Cloth Leggings
        CLOTH = {124583},
    },
    [127783] = { -- Baleful Cloth Spaulders
        CLOTH = {124587},
    },
    [127784] = { -- Baleful Cloth Girdle
        CLOTH = {124591},
    },
    [127790] = { -- Baleful Leather Bracers
        LEATHER = {124564},
    },
    [127791] = { -- Baleful Leather Tunic
        LEATHER = {124567},
    },
    [127792] = { -- Baleful Leather Treads
        LEATHER = {124572},
    },
    [127793] = { -- Baleful Leather Gauntlets
        LEATHER = {124576},
    },
    [127794] = { -- Baleful Leather Hood
        LEATHER = {124580},
    },
    [127795] = { -- Baleful Leather Leggings
        LEATHER = {124584},
    },
    [127796] = { -- Baleful Leather Spaulders
        LEATHER = {124588},
    },
    [127797] = { -- Baleful Leather Girdle
        LEATHER = {124592},
    },
    [127803] = { -- Baleful Mail Bracers
        MAIL = {124565},
    },
    [127804] = { -- Baleful Mail Robe
        MAIL = {124568},
    },
    [127805] = { -- Baleful Mail Treads
        MAIL = {124573},
    },
    [127806] = { -- Baleful Mail Gauntlets
        -- Wowhead says it's the plate gauntlets, but...
        MAIL = {124577},
    },
    [127807] = { -- Baleful Mail Hood
        MAIL = {124581},
    },
    [127808] = { -- Baleful Mail Leggings
        MAIL = {124585},
    },
    [127809] = { -- Baleful Mail Spaulders
        MAIL = {124589},
    },
    [127810] = { -- Baleful Mail Girdle
        MAIL = {124593},
    },
    [127816] = { -- Baleful Plate Bracers
        PLATE = {124566},
    },
    [127817] = { -- Baleful Plate Chest
        PLATE = {124569},
    },
    [127818] = { -- Baleful Plate Treads
        PLATE = {124574},
    },
    [127819] = { -- Baleful Plate Gauntlets
        -- Wowhead says it's the mail gauntlets, but...
        PLATE = {124578},
    },
    [127820] = { -- Baleful Plate Hood
        PLATE = {124582},
    },
    [127821] = { -- Baleful Plate Leggings
        PLATE = {124586},
    },
    [127822] = { -- Baleful Plate Spaulders
        PLATE = {124590},
    },
    [127823] = { -- Baleful Plate Girdle
        PLATE = {124594},
    },
    -- They switch to being in "other > consumables" here
    -- 7.2 Dauntless
    [147212] = { -- Dauntless Bracers
        PLATE = {147228},
        MAIL = {147227},
        LEATHER = {147226},
        CLOTH = {147225},
    },
    [147213] = { -- Dauntless Tunic
        PLATE = {147231},
        MAIL = {147230},
        LEATHER = {147229},
        CLOTH = {147232},
    },
    [147214] = { -- Dauntless Treads
        PLATE = {147236},
        MAIL = {147235},
        LEATHER = {147234},
        CLOTH = {147233},
    },
    [147215] = { -- Dauntless Gauntlets
        PLATE = {147240},
        MAIL = {147239},
        LEATHER = {147238},
        CLOTH = {147237},
    },
    [147216] = { -- Dauntless Hood
        PLATE = {147244},
        MAIL = {147243},
        LEATHER = {147242},
        CLOTH = {147241},
    },
    [147217] = { -- Dauntless Leggings
        PLATE = {147248},
        MAIL = {147247},
        LEATHER = {147246},
        CLOTH = {147245},
    },
    [147218] = { -- Dauntless Spaulders
        PLATE = {147252},
        MAIL = {147251},
        LEATHER = {147250},
        CLOTH = {147249},
    },
    [147219] = { -- Dauntless Girdle
        PLATE = {147256},
        MAIL = {147255},
        LEATHER = {147254},
        CLOTH = {147253},
    },
    [147220] = { -- Dauntless Ring
        ALL = {147257},
    },
    [147221] = { -- Dauntless Choker
        ALL = {147263},
    },
    [147222] = { -- Dauntless Cloak
        ALL = {147269},
    },
    [147223] = { -- Dauntless Trinket
        ALL = {147275, 147276, 147278},
    },
    -- 7.3 Relinquished (might not be appropriate -- it's a large drop table?)
    --[[
    [153059] = { -- Relinquished Arcane Relic
        UNKNOWN = {147079, 137547, 141272, 150997, 142176, 147076, 142514, 140813, 137379, 151006, 143699, 139269, 142305, 137303, 141515, 141266, 140827, 137473, 147077, 137490, 137420, 152344, 151293, 153446, 147078, 138227, 140810, 142175, 133768, 143523, 140047, 143692, 141259, 140812},
    },
    [153060] = { -- Relinquished Blood Relic
        UNKNOWN = {147082, 137363, 139257, 152030, 142510, 142179, 147754, 139254, 141280, 141264, 147080, 143682, 151296, 137302, 147081, 143691, 137471, 153450, 140818, 141523, 139260, 140819, 137465, 141283, 143684, 137544, 136718, 133687, 153449, 150998, 144466, 142180, 151189, 140044, 140820, 143524, 137350},
    },
    [153061] = { -- Relinquished Fel Relic
        UNKNOWN = {141281, 142182, 143525, 141255, 136721, 137476, 133764, 140826, 147085, 153453, 143696, 152345, 137407, 137542, 151289, 147087, 144459, 139253, 147755, 151008, 137491, 143687, 140086, 153454, 142181, 141277, 153452, 142513, 141520, 139267, 150999, 140824, 147084, 147086, 140825, 137351},
    },
    [153062] = { -- Relinquished Fire Relic
        UNKNOWN = {144460, 139256, 142183, 151000, 151009, 143701, 137375, 141279, 151290, 136769, 137546, 137316, 140835, 137358, 140837, 153455, 147089, 140836, 143526, 152294, 153457, 147756, 133686, 139266, 137470, 142307, 142184, 147090, 141265, 147088, 142516, 153456, 147091, 137492, 140834, 141261, 140043, 141522, 143683},
    },
    [153063] = { -- Relinquished Frost Relic
        UNKNOWN = {153459, 142308, 153460, 140831, 140080, 137370, 137272, 141257, 133683, 137545, 142515, 151001, 142186, 152346, 147092, 151010, 137380, 140833, 143700, 137340, 139250, 147095, 137466, 137403, 147757, 142185, 141274, 143527, 140832, 137308, 147093, 143703, 141517, 139259, 151291, 153458, 141267, 144461},
    },
    [153064] = { -- Relinquished Holy Relic
        UNKNOWN = {147098, 139252, 153462, 152347, 137548, 137366, 147099, 142519, 137402, 153463, 137495, 143695, 147097, 142187, 141260, 143686, 141519, 139258, 142188, 151005, 136717, 140843, 147758, 144467, 143528, 139265, 151297, 133685, 140042, 150996, 140845, 140844, 136771, 141271, 153461, 137346, 147096, 141276},
    },
    [153065] = { -- Relinquished Iron Relic
        UNKNOWN = {151011, 137359, 151002, 144462, 153465, 140815, 141262, 147101, 142178, 142177, 137469, 143529, 141521, 152292, 147759, 151292, 143705, 153466, 141268, 139261, 136778, 137543, 147100, 137408, 140817, 143685, 141263, 140816, 137371, 140045, 133763, 137326, 153464, 147102, 137472, 142306, 139255, 142511},
    },
    [153066] = { -- Relinquished Life Relic
        UNKNOWN = {151012, 137478, 143530, 139263, 142309, 153469, 137381, 140838, 143698, 136973, 142189, 147104, 151003, 153468, 138228, 140839, 139249, 143689, 141256, 147106, 147105, 147760, 137307, 141275, 144458, 143702, 140088, 137339, 141269, 137327, 147107, 142517, 142190, 137411, 152053, 151288, 136720, 153467},
    },
    [153067] = { -- Relinquished Shadow Relic
        UNKNOWN = {151013, 142192, 141282, 151004, 137347, 137399, 143694, 143531, 151294, 144464, 143690, 153471, 140821, 137463, 147111, 137549, 133684, 142191, 137377, 142310, 137317, 138226, 137464, 153472, 136719, 153470, 142512, 141518, 140822, 147109, 139268, 140823, 147108, 140041, 147110, 143693, 141254, 152290, 139251},
    },
    [153068] = { -- Relinquished Storm Relic
        UNKNOWN = {147112, 137421, 137270, 140840, 147115, 143697, 142194, 141258, 147113, 140842, 142518, 137468, 140841, 136974, 142193, 133682, 147114, 147761, 144465, 151014, 143704, 141278, 143532, 153473, 137550, 137493, 140079, 137008, 137365, 153474, 139262, 151015, 152348, 139264, 143688, 137313, 141270, 141514, 151295, 153475},
    },
    [153205] = { -- Relinquished Girdle
        PLATE = {137436, 134269, 147256, 149032, 136773, 139057, 152749, 137499, 134225, 146851, 134181, 151327, 150244, 140892, 137361, 150140, 142424, 144497, 134313, 142129, 137523, 133770, 141442, 150959, 139227, 140912, 134357, 136727, 134137, 150038, 137310, 149137, 150039, 121278},
        MAIL = {134207, 134295, 134251, 139211, 142420, 136724, 142137, 137416, 147255, 150977, 152767, 133805, 150087, 136753, 148979, 134482, 147056, 151326, 134339, 140890, 134383, 144496, 137456, 146777, 139115},
        LEATHER = {134287, 152756, 139073, 142196, 134457, 150118, 136745, 137409, 148946, 144486, 142145, 140858, 134155, 137513, 146866, 150966, 150070, 134375, 146775, 134455, 141444, 121299, 147254, 149070, 140859, 134199, 134456, 151316, 147039, 134243, 142416, 147347, 137435, 150054, 150179},
        CLOTH = {146785, 147736, 134259, 152772, 134433, 150229, 149120, 144472, 150157, 147253, 150228, 151302, 134434, 134303, 140887, 137331, 139123, 134347, 134391, 137413, 142411, 136761, 134171, 137507, 142153, 139085, 150103, 121323, 137488},
    },
    [153206] = { -- Relinquished Bracers
        PLATE = {134186, 134502, 139100, 142130, 134520, 150962, 147228, 134318, 134142, 150142, 149034, 140902, 152752, 150041, 134362, 142198, 134522, 151328, 133632, 139283, 150040, 149138, 121283, 148932, 134230, 150246, 137337, 137431, 146856, 139062, 140893, 144498},
        MAIL = {152762, 137522, 139282, 150089, 136754, 134164, 142423, 150197, 147057, 134208, 134484, 149089, 139116, 134296, 148981, 150972, 133626, 150088, 149088, 148980, 139222, 134252, 134485, 121316, 137305, 137325, 139078, 134340, 142138, 137405},
        LEATHER = {134461, 137512, 134192, 144485, 152754, 150057, 147226, 133621, 150964, 136979, 134368, 150056, 134236, 146859, 134459, 148964, 139066, 134458, 149013, 136738, 147042, 141429, 150121, 121292, 142146, 146768, 137442, 137425, 151315, 139104, 140889, 150072, 134324, 134280, 140857, 149577, 134148},
        CLOTH = {134178, 137434, 139130, 136768, 139092, 144475, 147735, 121330, 134435, 152773, 137314, 134310, 146883, 140850, 134398, 137372, 150983, 147000, 134222, 150230, 141428, 151305, 147225, 134437, 133614, 142415, 134266, 146792, 149122, 148996, 149123},
    },
    [153207] = { -- Relinquished Treads
        PLATE = {136772, 146855, 146764, 140884, 152753, 121282, 134185, 134507, 142124, 150235, 151330, 134361, 148921, 147236, 134317, 134505, 150234, 139099, 147059, 140904, 139241, 150130, 134229, 147060, 137529, 150963, 144500, 134504, 139061, 137417, 136731, 137334, 134141, 134273, 140891},
        MAIL = {137517, 121318, 133623, 146871, 134464, 138211, 134386, 134342, 147235, 139118, 150185, 136756, 150077, 146780, 134210, 137444, 134166, 147045, 134477, 134466, 139220, 139080, 134298, 148968, 149076, 141432, 152766, 142132},
        LEATHER = {147234, 137324, 140861, 137497, 134429, 151317, 150967, 146769, 134369, 146860, 134441, 137397, 134325, 139200, 142140, 144487, 140860, 137448, 150045, 152757, 121293, 141430, 150044, 136739, 150169, 134193, 148952, 149061, 147030, 150061, 150060, 139067, 134442, 150168, 142417, 147029},
        CLOTH = {134176, 139090, 151301, 134264, 136766, 134419, 134220, 134352, 142148, 134417, 152774, 147233, 134396, 146881, 121328, 150090, 146790, 139128, 146986, 136774, 140885, 144471, 134308, 150216, 150145, 139280, 137454},
    },
    [153208] = { -- Relinquished Chestguard
        PLATE = {147231, 150128, 134179, 134501, 139093, 142303, 136976, 134311, 121276, 134500, 146758, 134267, 137527, 134223, 144499, 137437, 134503, 151329, 152748, 134135, 150026, 147751, 137457, 150129, 136725, 142431, 146849, 139055, 140877, 134355, 148918, 150958, 141413, 142123, 150027, 138350, 141481},
        MAIL = {146875, 136760, 137498, 152768, 134214, 139122, 134463, 150074, 148966, 137428, 134462, 142301, 121322, 139084, 134346, 141423, 134302, 144495, 134258, 140875, 137460, 147230, 142433, 146784, 141491, 150978, 139221, 150075, 134390, 133622, 137368, 137354, 142131},
        LEATHER = {147229, 134438, 142139, 121297, 137514, 134285, 152758, 134439, 139109, 146773, 134153, 144483, 136743, 146864, 134329, 151313, 142203, 133615, 134197, 139208, 150968, 150166, 150117, 147027, 150058, 137336, 141419, 137449, 150043, 147737, 140865, 149058, 134241, 148950, 139071, 134373, 147133, 150059, 149009, 150042},
        CLOTH = {139246, 134414, 152775, 137352, 147232, 146880, 136765, 134175, 134395, 151303, 150098, 139127, 137504, 142147, 142297, 121327, 134307, 146789, 139089, 140848, 133611, 150099, 134415, 150224, 138320, 144473, 148624, 134219, 134351, 142410, 148990, 148553, 150225, 134263, 150152, 150153, 138215, 146995, 150985},
    },
    [153209] = { -- Relinquished Cloak
        ALL = {152778, 146886, 147269, 146885, 146766, 139112, 121307, 134334, 146884, 150988, 134158, 134402, 134411, 150019, 134412, 134365, 136748, 144468, 134290, 136770, 133765, 139074, 134408, 151635, 147764, 151298, 134246, 150010, 133771, 134202, 136977, 134410, 146793, 142540, 137531, 142170, 148914, 150008, 146985, 134404, 150014, 151306, 144476, 137483, 141541, 133639, 146857, 150022, 134406, 148913, 137530, 150004, 146794, 147193, 150020, 146984, 141448, 134407, 150006, 150018, 142206, 148902, 150003, 148909, 141538, 148906, 141540, 148915, 134405, 142521, 151634, 138221, 142215, 148916, 146795, 148896, 150024, 142412, 138370, 150021, 148898, 141543, 147163, 141539, 138368, 141542, 139248, 150023, 150025, 148897, 148903, 148912},
    },
    [153210] = { -- Relinquished Gauntlets
        PLATE = {150961, 152751, 146850, 144502, 149023, 148923, 147240, 150132, 139056, 134312, 137525, 134136, 139094, 139226, 134180, 142299, 137429, 142125, 137355, 140907, 133628, 121277, 150236, 150237, 136726, 150133, 134519, 146759, 134509, 151332, 134508, 147061, 139225, 134356, 134268},
        MAIL = {137519, 150078, 134385, 152763, 142133, 150187, 151322, 137348, 141466, 147239, 134253, 146870, 139117, 150973, 144492, 121317, 150079, 134469, 134341, 150186, 137300, 137333, 141694, 134297, 139213, 138340},
        LEATHER = {121295, 146862, 136741, 134283, 134444, 152755, 140996, 134371, 147238, 133617, 147739, 146771, 147031, 150062, 150965, 137509, 139242, 151318, 138329, 134327, 141440, 134445, 137480, 134195, 134239, 134443, 139107, 142205, 137320, 148938},
        CLOTH = {150218, 137506, 134422, 148984, 146787, 150219, 134305, 134173, 150147, 152771, 150093, 144470, 134421, 147237, 134349, 147164, 139087, 142149, 138310, 134431, 134420, 136763, 146878, 150981, 134217, 133609, 141435, 141470, 150092},
    },
    [153211] = { -- Relinquished Hood
        PLATE = {152747, 134314, 146852, 134358, 147244, 150033, 134226, 142304, 134512, 133629, 134182, 137451, 139058, 137445, 137526, 146761, 139096, 142126, 134513, 147063, 134138, 150239, 134511, 151333, 136728, 150957, 137410, 144503, 141459, 147124, 147749, 139229, 150238, 141424, 134270, 150134, 149025, 138355, 150135, 121279},
        MAIL = {147243, 150080, 134471, 144494, 137479, 151324, 137516, 134255, 152765, 150975, 134387, 134473, 146781, 150188, 121319, 139244, 148973, 134343, 136777, 137443, 139119, 140870, 140903, 142134, 147142, 147050, 147049, 134167, 139214, 139081, 146872, 134470, 150081, 134299, 136757, 148972},
        LEATHER = {147242, 134240, 152759, 134372, 134328, 150064, 137511, 134152, 134440, 137415, 134447, 146863, 134446, 134196, 146772, 134284, 150969, 150049, 147033, 137427, 139108, 136742, 149064, 139204, 148956, 121296, 150173, 133618, 151336, 142142, 147034, 150065, 141453, 138330, 141418, 139070, 150172, 139281, 150110},
        CLOTH = {139124, 147241, 137341, 152770, 134426, 136762, 150221, 137441, 121324, 134172, 142296, 146877, 134260, 150094, 139189, 141449, 137502, 140851, 151337, 146786, 134425, 150980, 134424, 134348, 139086, 150220, 134304, 134392, 146991, 149113, 134216, 142150, 148986, 149041},
    },
    [153212] = { -- Relinquished Leggings
        PLATE = {147248, 137528, 134514, 152746, 150136, 134506, 134183, 133630, 134315, 150034, 151339, 146762, 149027, 140882, 150956, 134359, 134227, 134516, 148927, 137342, 121280, 146853, 134271, 136729, 141425, 148926, 134515, 139240, 142127, 150137, 142425, 139059, 150240, 147750, 139230, 147065, 134139, 139097, 147066},
        MAIL = {152764, 134474, 150974, 142197, 146782, 136758, 133769, 139082, 142135, 150082, 141421, 138345, 151338, 150083, 134388, 134168, 134212, 137450, 134475, 134476, 147247, 134344, 134256, 139120, 134483, 134300, 137518, 146873, 121320, 148975},
        LEATHER = {134449, 134326, 147246, 139106, 134282, 136740, 134460, 137353, 134150, 152761, 150066, 146861, 134448, 134451, 139068, 134450, 142300, 149067, 142143, 150971, 134238, 146770, 137515, 133616, 134370, 121294, 140862, 150174, 141417, 150067, 134194, 150050, 147741, 144484, 140908, 139201},
        CLOTH = {150986, 137496, 152776, 136764, 137304, 134350, 150223, 134427, 137505, 149114, 137404, 147245, 146788, 146879, 134174, 150222, 139088, 144474, 138315, 121326, 139126, 134262, 142202, 141415, 151304, 134394, 134218, 150097, 146993, 142151, 137424},
    },
    [153213] = { -- Relinquished Necklace
        ALL = {147263, 134275, 121284, 150124, 139101, 134249, 136733, 152780, 137311, 134187, 133633, 150990, 150122, 139063, 134376, 134488, 149018, 137487, 146867, 134541, 134497, 149014, 134161, 134319, 134529, 137418, 146776, 134491, 137458, 134498, 137461, 137535, 151309, 147765, 134499, 140898, 150126, 141696, 134492, 141438, 139332, 142174, 133636, 150125, 149019, 137536, 142428, 144479, 149629, 133767, 149627, 149630, 149628, 134495, 142207, 140894, 147013, 140900, 141473, 150123, 140899, 149631, 149017, 150127, 149626, 148029, 148033},
    },
    [153214] = { -- Relinquished Ring
        ALL = {152779, 147257, 134323, 150162, 134367, 139103, 134157, 149052, 150989, 134490, 134245, 136737, 134191, 121288, 134279, 150160, 133679, 139065, 151311, 150164, 134533, 150163, 146858, 149054, 134528, 134487, 134539, 141534, 138220, 146767, 134524, 137432, 140896, 142172, 134530, 150165, 147767, 134527, 134540, 144481, 134532, 147195, 134525, 133637, 144478, 133638, 134493, 134526, 139238, 147194, 141488, 137533, 134534, 134542, 141546, 142520, 149053, 151308, 149057, 134489, 139237, 133634, 137532, 134537, 141492, 147021, 150161, 147766, 137438, 149664, 149667, 149665, 142173, 149669, 141533, 147020, 140906, 149668, 140895, 134531, 149666, 141486},
    },
    [153215] = { -- Relinquished Spaulders
        PLATE = {147252, 152750, 134140, 134228, 133631, 134518, 139060, 134521, 146763, 137524, 134272, 121281, 137322, 146854, 139098, 142201, 144501, 140883, 151331, 150243, 134517, 150037, 150242, 150960, 134360, 150138, 147069, 134316, 142128, 147070, 134510, 150036, 150139, 147126, 136730, 134184, 139233, 141426, 147752},
        MAIL = {134480, 150084, 152769, 134257, 134389, 134213, 147251, 139245, 134478, 121321, 149084, 136759, 150085, 144493, 147054, 150979, 146874, 134472, 142136, 133625, 137321, 150192, 148977, 134301, 139083, 140872, 134345, 139121, 138347, 141422, 150193, 146783},
        LEATHER = {152760, 137332, 147250, 137510, 140864, 146865, 150970, 134374, 134198, 142144, 133620, 136744, 137455, 139206, 134330, 137364, 144489, 134454, 150177, 134453, 139110, 134242, 121298, 148960, 150052, 147037, 151319, 150068, 146774, 150053, 141445, 134154, 134452, 139072, 134286, 147742, 150176, 141006, 148961},
        CLOTH = {147249, 137360, 139247, 139129, 136767, 137447, 152777, 150227, 134353, 136775, 150100, 134265, 144469, 149118, 134430, 142152, 137309, 150155, 150987, 134177, 146791, 146996, 151299, 134432, 140853, 137503, 139091, 146882, 149119, 150101, 134309, 150226},
    },
    [153216] = { -- Relinquished Trinket
        ALL = {137419, 153172, 121311, 121310, 142166, 133642, 152783, 134248, 152782, 134159, 134203, 152781, 139113, 136750, 134204, 134247, 134379, 134291, 134335, 136749, 137357, 134336, 139114, 137367, 139102, 142160, 137485, 151190, 136715, 137349, 133641, 137537, 134160, 134322, 134380, 137541, 134366, 137486, 134234, 139075, 136736, 142167, 121287, 139064, 137406, 137369, 149090, 137329, 137462, 150205, 144477, 139076, 142164, 136716, 137306, 144480, 142159, 151307, 151310, 147275, 134190, 137338, 137459, 134278, 134292, 147276, 133644, 150199, 150200, 137430, 142165, 137312, 142507, 137439, 137433, 147002, 137373, 137539, 147015, 142157, 147017, 140806, 137398, 147278, 140790, 137538, 137362, 136975, 150204, 150211, 139325, 137301, 150206, 137446, 150198, 137344, 150201, 140809, 134146, 147009, 141536, 147012, 142169, 150203, 150210, 141537, 149103, 149104, 149092, 149106, 142508, 140801, 149096, 150208, 140792, 151340, 142161, 140802, 139335, 139324, 147018, 147011, 140798, 136978, 144482, 150213, 140804, 147026, 139329, 141482, 138222, 149095, 138224, 150202, 137315},
    },
    --]]
    -- 7.3 Argus Unsullied
    [152733] = { -- Unsullied Trinket
        ALL = {153172, 152781, 152783, 152782},
    },
    [152734] = { -- Unsullied Cloth Mantle
        CLOTH = {152777},
    },
    [152735] = { -- Unsullied Ring
        ALL = {152779},
    },
    [152736] = { -- Unsullied Necklace
        ALL = {152780},
    },
    [152737] = { -- Unsullied Leather Trousers
        LEATHER = {152761},
    },
    [152738] = { -- Unsullied Cloth Cap
        CLOTH = {152770},
    },
    [152739] = { -- Unsullied Leather Grips
        LEATHER = {152755},
    },
    [152740] = { -- Unsullied Cloak
        ALL = {152778},
    },
    [152741] = { -- Unsullied Mail Chestguard
        MAIL = {152768},
    },
    [152742] = { -- Unsullied Cloth Cuffs
        CLOTH = {152773},
    },
    [152743] = { -- Unsullied Plate Sabatons
        PLATE = {152753},
    },
    [152744] = { -- Unsullied Mail Girdle
        MAIL = {152767},
    },
    [152799] = { -- Unsullied Relic
        ALL = {151002, 150998, 150997, 151001, 151004, 151000, 151003, 151015, 150996, 150999},
    },
    [153135] = { -- Unsullied Cloth Robes
        CLOTH = {152775},
    },
    [153136] = { -- Unsullied Leather Treads
        LEATHER = {152757},
    },
    [153137] = { -- Unsullied Mail Spaulders
        MAIL = {152769},
    },
    [153138] = { -- Unsullied Mail Legguards
        MAIL = {152764},
    },
    [153139] = { -- Unsullied Leather Headgear
        LEATHER = {152759},
    },
    [153140] = { -- Unsullied Plate Waistplate
        PLATE = {152749},
    },
    [153141] = { -- Unsullied Cloth Mitts
        CLOTH = {152771},
    },
    [153142] = { -- Unsullied Leather Armbands
        LEATHER = {152754},
    },
    [153143] = { -- Unsullied Plate Breastplate
        PLATE = {152748},
    },
    [153144] = { -- Unsullied Cloth Slippers
        CLOTH = {152774},
    },
    [153145] = { -- Unsullied Leather Spaulders
        LEATHER = {152760},
    },
    [153146] = { -- Unsullied Plate Greaves
        PLATE = {152746},
    },
    [153147] = { -- Unsullied Mail Coif
        MAIL = {152765},
    },
    [153148] = { -- Unsullied Leather Belt
        LEATHER = {152756},
    },
    [153149] = { -- Unsullied Mail Gloves
        MAIL = {152763},
    },
    [153150] = { -- Unsullied Plate Vambraces
        PLATE = {152752},
    },
    [153151] = { -- Unsullied Leather Tunic
        LEATHER = {152758},
    },
    [153152] = { -- Unsullied Mail Boots
        MAIL = {152766},
    },
    [153153] = { -- Unsullied Plate Pauldrons
        PLATE = {152750},
    },
    [153154] = { -- Unsullied Cloth Leggings
        CLOTH = {152776},
    },
    [153155] = { -- Unsullied Plate Helmet
        PLATE = {152747},
    },
    [153156] = { -- Unsullied Cloth Sash
        CLOTH = {152772},
    },
    [153157] = { -- Unsullied Plate Gauntlets
        PLATE = {152751},
    },
    [153158] = { -- Unsullied Mail Bracers
        MAIL = {152762},
    },
    -- 8.1 Relinquished
    -- 8.2 Nazjatar Benthic
    -- These can generate items with bonuses 40 (avoidance), 41 (leech), 42 (speed), 43 (indestructable)
    [169479] = { -- Benthic Helm
        PLATE = {167778},
        MAIL = {167770},
        LEATHER = {167762},
        CLOTH = {167754},
    },
    [169484] = { -- Benthic Spaulders
        PLATE = {167781},
        MAIL = {167772},
        LEATHER = {167764},
        CLOTH = {167756},
    },
    [169480] = { -- Benthic Chestguard
        PLATE = {167775},
        MAIL = {167767},
        LEATHER = {167759},
        CLOTH = {167779},
    },
    [169482] = { -- Benthic Leggings
        PLATE = {170110, 167780, 169811},
        MAIL = {170109, 169810, 167771},
        LEATHER = {170108, 167763, 169809, },
        CLOTH = {170107, 167755, 169808},
    },
    [169477] = { -- Benthic Girdle
        PLATE = {167782, 170370},
        MAIL = {167773, 170369},
        LEATHER = {167765, 170368},
        CLOTH = {167757, 170367},
    },
    [169478] = { -- Benthic Bracers
        PLATE = {170111, 169815, 170106, 167783, 170328, 170303},
        MAIL = {170121, 170105, 170329, 167774, 169814, 170304},
        LEATHER = {170104, 170122, 170330, 167766, 169813, 170305},
        CLOTH = {167758, 170103, 170331, 170123, 169812, 170306},
    },
    [169481] = { -- Benthic Cloak
        ALL = {169489, 169488, 169486, 169487},
    },
    [169483] = { -- Benthic Treads
        PLATE = {169891, 167776, 170374, 170143},
        MAIL = {170373, 169892, 167768, 170142},
        LEATHER = {170372, 169893, 167760, 170141},
        CLOTH = {169894, 167752, 170371, 170140},
    },
    [169485] = { -- Benthic Gauntlets
        PLATE = {170136, 169793, 170336, 167777, 170378},
        MAIL = {169792, 167769, 170335, 170135, 170377},
        LEATHER = {169791, 167761, 170334, 170134, 170376},
        CLOTH = {170133, 167753, 170333, 169790, 170375},
    },
    -- 8.2 other
    [169137] = { -- Extraordinary Adventurer Augmentation
        ALL = {169002, 169007, 169009, 170273, 169008, 161414, 161374},
    },
    [168833] = { -- Experimental Adventurer Augmentation
        ALL = {169009, 169002, 169007, 161374, 161418, 169008, 161375, 161382},
    },
    -- 8.3 Black Empire
    -- Back to items > armor
    -- These can generate items with bonuses 40 (avoidance), 41 (leech), 42 (speed), 43 (indestructable)
    [173396] = { -- Black Empire Plate Helm
        PLATE = {173457, 173836},
    },
    [173398] = { -- Black Empire Plate Spaulders
        PLATE = {173835, 173460},
    },
    [173393] = { -- Black Empire Plate Chestpiece
        PLATE = {173454, 173837},
    },
    [173422] = { -- Black Empire Plate Bracers
        PLATE = {173487, 173482, 173462, 173474},
    },
    [173399] = { -- Black Empire Plate Belt
        PLATE = {173514, 173821, 173461, 173822},
    },
    [173395] = { -- Black Empire Plate Gloves
        PLATE = {173510, 173494, 173466, 173456},
    },
    [173397] = { -- Black Empire Plate Leggings
        PLATE = {173820, 173470, 173486, 173459},
    },
    [173394] = { -- Black Empire Plate Boots
        PLATE = {173518, 173475, 173498, 173455},
    },
    [173403] = { -- Black Empire Mail Helm
        MAIL = {173839, 173449},
    },
    [173405] = { -- Black Empire Mail Spaulders
        MAIL = {173838, 173451},
    },
    [173400] = { -- Black Empire Mail Chestpiece
        MAIL = {173446, 173840},
    },
    [173425] = { -- Black Empire Mail Bracers
        MAIL = {173481, 173473, 173488, 173453},
    },
    [173406] = { -- Black Empire Mail Belt
        MAIL = {173819, 173452, 173513, 173818},
    },
    [173402] = { -- Black Empire Mail Gloves
        MAIL = {173509, 173448, 173465, 173493},
    },
    [173404] = { -- Black Empire Mail Leggings
        MAIL = {173450, 173485, 173817, 173469},
    },
    [173401] = { -- Black Empire Mail Boots
        MAIL = {173476, 173447, 173497, 173517},
    },
    [173410] = { -- Black Empire Leather Helm
        LEATHER = {173441, 173842},
    },
    [173412] = { -- Black Empire Leather Spaulders
        LEATHER = {173841, 173443},
    },
    [173407] = { -- Black Empire Leather Chestpiece
        LEATHER = {173438, 173843},
    },
    [173424] = { -- Black Empire Leather Bracers
        LEATHER = {173445, 173472, 173480, 173489},
    },
    [173409] = { -- Black Empire Leather Gloves
        LEATHER = {173440, 173464, 173492, 173508},
    },
    [173413] = { -- Black Empire Leather Belt
        LEATHER = {173444, 173512, 173815, 173816},
    },
    [173411] = { -- Black Empire Leather Leggings
        LEATHER = {173442, 173468, 173484, 173814},
    },
    [173408] = { -- Black Empire Leather Boots
        LEATHER = {173439, 173477, 173496, 173516},
    },
    [173417] = { -- Black Empire Cloth Helm
        CLOTH = {173433, 173845},
    },
    [173419] = { -- Black Empire Cloth Spaulders
        CLOTH = {173435, 173844},
    },
    [173414] = { -- Black Empire Cloth Robes
        CLOTH = {173846, 173458},
    },
    [173423] = { -- Black Empire Cloth Bracers
        CLOTH = {173437, 173471, 173490, 173479},
    },
    [173416] = { -- Black Empire Cloth Gloves
        CLOTH = {173507, 173491, 173432, 173463},
    },
    [173420] = { -- Black Empire Cloth Belt
        CLOTH = {173813, 173511, 173812, 173436},
    },
    [173418] = { -- Black Empire Cloth Leggings
        CLOTH = {173467, 173434, 173483, 173811},
    },
    [173415] = { -- Black Empire Cloth Boots
        CLOTH = {173495, 173431, 173515, 173478},
    },
    -- 9.0.1 Castle Nathria weapon tokens:

    -- 9.2 Sepulcher of the First Ones class set tokens: below
    -- 10.0.7 Primalist
    [203611] = { -- Primalist Plate Helm
        PLATE = {199433},
    },
    [203612] = { -- Primalist Cloth Helm
        CLOTH = {199420},
    },
    [203613] = { -- Primalist Mail Helm
        MAIL = {199444},
    },
    [203614] = { -- Primalist Leather Helm
        LEATHER = {199427},
    },
    [203615] = { -- Primalist Plate Chestpiece
        PLATE = {199434},
    },
    [203616] = { -- Primalist Cloth Chestpiece
        CLOTH = {199417},
    },
    [203617] = { -- Primalist Mail Chestpiece
        MAIL = {199441},
    },
    [203618] = { -- Primalist Leather Chestpiece
        LEATHER = {199431},
    },
    [203619] = { -- Primalist Leather Leggings
        LEATHER = {199428},
    },
    [203620] = { -- Primalist Mail Leggings
        MAIL = {199445},
    },
    [203622] = { -- Primalist Cloth Leggings
        CLOTH = {199421},
    },
    [203623] = { -- Primalist Plate Leggings
        PLATE = {199437},
    },
    [203626] = { -- Primalist Plate Spaulders
        PLATE = {199438},
    },
    [203627] = { -- Primalist Cloth Spaulders
        CLOTH = {199424},
    },
    [203628] = { -- Primalist Mail Spaulders
        MAIL = {199446},
    },
    [203629] = { -- Primalist Leather Spaulders
        LEATHER = {199432},
    },
    [203630] = { -- Primalist Leather Bracers
        LEATHER = {199430},
    },
    [203631] = { -- Primalist Mail Bracers
        MAIL = {199448},
    },
    [203632] = { -- Primalist Cloth Bracers
        CLOTH = {199423},
    },
    [203633] = { -- Primalist Plate Bracers
        PLATE = {199440},
    },
    [203634] = { -- Primalist Plate Belt
        PLATE = {199439},
    },
    [203635] = { -- Primalist Cloth Belt
        CLOTH = {199422},
    },
    [203636] = { -- Primalist Mail Belt
        MAIL = {199447},
    },
    [203637] = { -- Primalist Leather Belt
        LEATHER = {199429},
    },
    [203638] = { -- Primalist Leather Boots
        LEATHER = {199425},
    },
    [203639] = { -- Primalist Mail Boots
        MAIL = {199442},
    },
    [203640] = { -- Primalist Plate Boots
        PLATE = {199435},
    },
    [203641] = { -- Primalist Cloth Boots
        CLOTH = {199418},
    },
    [203642] = { -- Primalist Cloth Gloves
        CLOTH = {199419},
    },
    [203643] = { -- Primalist Plate Gloves
        PLATE = {199436},
    },
    [203644] = { -- Primalist Mail Gloves
        MAIL = {199443},
    },
    [203645] = { -- Primalist Leather Gloves
        LEATHER = {199426},
    },
    [203646] = { -- Primalist Cloak
        ALL = {199449, 199450, 199451, 199452},
    },
    [203647] = { -- Primalist Ring
        ALL = {201960, 201961},
    },
    [203648] = { -- Primalist Necklace
        ALL = {201962},
    },
    [203649] = { -- Primalist Trinket
        ALL = {202015},
    },
    [203650] = { -- Primalist Weapon
        PALADIN = {199325, 199316, 199315, 199319, 199304, 199324, 199317},
        WARRIOR = {199315, 199320, 199304, 199324, 199317, 199318},
        DEATHKNIGHT = {199315, 199304, 199324, 199317, 199320},
        SHAMAN = {199325, 199316, 199309, 199319, 199305, 199306, 199318, 199323},
        HUNTER = {199307, 199313, 199321},
        EVOKER = {199312, 199316, 199309, 199311},
        DRUID = {199312, 199316, 199309, 199313, 199321},
        DEMONHUNTER = {199306, 199308},
        ROGUE = {199310, 199306, 199318, 199323},
        MONK = {199313, 199321, 199325, 199316, 199306, 199318, 199323},
        MAGE = {199312, 199309, 199322},
        PRIEST = {199312, 199325, 199316, 199309, 199322},
        WARLOCK = {199312, 199309, 199322},
    },
    -- 10.0 Vault of the Incarnates: below
    -- 10.1.0 Aberrus: below
    -- 10.1.7 Dreambound
    [208911] = { -- Dreambound Cloth Belt
        CLOTH = {209406}, -- Cord
    },
    [208917] = { -- Dreambound Cloth Boots
        CLOTH = {209410}, -- Sandals
    },
    [208908] = { -- Dreambound Cloth Bracers
        CLOTH = {209405}, -- Cuffs
    },
    [208895] = { -- Dreambound Cloth Chestpiece
        CLOTH = {209411}, -- Vestment
    },
    [208918] = { -- Dreambound Cloth Gloves
        CLOTH = {209409}, -- Mitts
    },
    [208891] = { -- Dreambound Cloth Helm
        CLOTH = {209408}, -- Crown
    },
    [208900] = { -- Dreambound Cloth Leggings
        CLOTH = {209407}, -- Pants
    },
    [208903] = { -- Dreambound Cloth Spaulders
        CLOTH = {209380}, -- Shoulderpads
    },
    [208913] = { -- Dreambound Leather Belt
        LEATHER = {209400}, -- Sash
    },
    [208914] = { -- Dreambound Leather Boots
        LEATHER = {209404}, -- Waders
    },
    [208906] = { -- Dreambound Leather Bracers
        LEATHER = {209399}, -- Bindings
    },
    [208897] = { -- Dreambound Leather Chestpiece
        LEATHER = {209382}, -- Vest
    },
    [208921] = { -- Dreambound Leather Gloves
        LEATHER = {209403}, -- Handwraps
    },
    [208893] = { -- Dreambound Leather Helm
        LEATHER = {209402}, -- Cowl
    },
    [208898] = { -- Dreambound Leather Leggings
        LEATHER = {209401}, -- Breeches
    },
    [208905] = { -- Dreambound Leather Spaulders
        LEATHER = {209381}, -- Epaulets
    },
    [208912] = { -- Dreambound Mail Belt
        MAIL = {209392}, -- Cinch
    },
    [208915] = { -- Dreambound Mail Boots
        MAIL = {209397}, -- Striders
    },
    [208907] = { -- Dreambound Mail Bracers
        MAIL = {209391}, -- Vambraces
    },
    [208896] = { -- Dreambound Mail Chestpiece
        MAIL = {209398}, -- Chainmail
    },
    [208920] = { -- Dreambound Mail Gloves
        MAIL = {209396}, -- Grips
    },
    [208892] = { -- Dreambound Mail Helm
        MAIL = {209395}, -- Coif
    },
    [208899] = { -- Dreambound Mail Leggings
        MAIL = {209394}, -- Greaves
    },
    [208904] = { -- Dreambound Mail Spaulders
        MAIL = {209393}, -- Shoulderguards
    },
    [208910] = { -- Dreambound Plate Belt
        PLATE = {209384}, -- Girdle
    },
    [208916] = { -- Dreambound Plate Boots
        PLATE = {209388}, -- Sabatons
    },
    [208909] = { -- Dreambound Plate Bracers
        PLATE = {209383}, -- Armplates
    },
    [208894] = { -- Dreambound Plate Chestpiece
        PLATE = {209389}, -- Breastplate
    },
    [208919] = { -- Dreambound Plate Gloves
        PLATE = {209387}, -- Gauntlets
    },
    [208890] = { -- Dreambound Plate Helm
        PLATE = {209390}, -- Faceplate
    },
    [208901] = { -- Dreambound Plate Leggings
        PLATE = {209386}, -- Legguards
    },
    [208902] = { -- Dreambound Plate Spaulders
        PLATE = {209385}, -- Mantle
    },
    [208922] = { -- Dreambound Cloak
        ALL = {
            --209414, -- Drape (WH comments suggest this can't generate?)
            209412, -- Greatcloak
            209413, -- Cape
            209357, -- Shawl
        },
    },
    [208923] = { -- Dreambound Ring
        ALL = {
            {209368}, -- Loop
            {209367}, -- Signet
            {209358}, -- Band
        },
    },
    [208924] = { -- Dreambound Necklace
        ALL = {209356}, -- Choker
    },
    -- [208925] = { -- Dreambound Trinket
    --     ALL = {},
    -- },
    [208926] = { -- Dreambound Weapon
        -- These are a bit spec-based as well, but...
        PALADIN = {209378, 209366, 209363, 209364, 209371, 209374, 209361, 209379, 209369}, -- Scepter (int Off-hand), Hacker (str 1h Axe), Mallet (str 1h Mace), Censer (int 1h Mace), Sword (1h Sword), Spellblade (1h Sword), Halberd (str Polearm), Barrier (Shield), Greatsword (2h sword)
        WARRIOR = {209366, 209363, 209371, 209361, 209379, 209369}, -- Hacker (str 1h Axe), Mallet (str 1h Mace), Sword (1h Sword), Halberd (str Polearm), Barrier (Shield), Greatsword (2h sword)
        DEATHKNIGHT = {209378, 209366, 209363, 209371, 209361, 209369}, -- Scepter (int Off-hand), Hacker (str 1h Axe), Mallet (str 1h Mace), Sword (1h Sword), Halberd (str Polearm), Greatsword (2h sword)
        DEMONHUNTER = {209365, 209370, 209374, 209359}, -- Cleaver (agi 1h Axe), Blade (1h Sword), Spellblade (1h Sword), Warglaive
        HUNTER = {209375, 209376}, -- Rifle (Gun), Polearm (agi Polearm)
        ROGUE = {209373, 209365, 209362, 209370}, -- Shank (agi Dagger), Cleaver (agi 1h Axe), Cudgel (agi 1h Mace), Blade (1h Sword)
        MONK = {209378, 209365, 209362, 209364, 209370, 209374, 209376, 209360}, -- Scepter (int Off-hand), Cleaver (agi 1h Axe), Cudgel (agi 1h Mace), Censer (int 1h Mace), Blade (1h Sword), Spellblade (1h Sword), Polearm (agi Polearm), Staff (int Staff)
        MAGE = {209372, 209378, 209374, 209360, 209377}, -- Kris (int Dagger), Scepter (int Off-hand), Spellblade (1h Sword), Staff (int Staff), Wand (Wand)
        DRUID = {209372, 209378, 209364, 209376, 209360}, -- Kris (int Dagger), Scepter (int Off-hand), Censer (int 1h Mace), Polearm (agi Polearm), Staff (int Staff)
        PRIEST = {209372, 209378, 209364, 209360, 209377}, -- Kris (int Dagger), Scepter (int Off-hand), Censer (int 1h Mace), Staff (int Staff), Wand (Wand)
        SHAMAN = {209372, 209378, 209365, 209362, 209364, 209379, 209360}, -- Kris (int Dagger), Scepter (int Off-hand), Cleaver (agi 1h Axe), Cudgel (agi 1h Mace), Censer (int 1h Mace), Barrier (Shield), Staff (int Staff)
        WARLOCK = {209372, 209378, 209374, 209360, 209377}, -- Kris (int Dagger), Scepter (int Off-hand), Spellblade (1h Sword), Staff (int Staff), Wand (Wand)
        EVOKER = {209372, 209378, 209364, 209374, 209360}, -- Kris (int Dagger), Scepter (int Off-hand), Censer (int 1h Mace), Spellblade (1h Sword), Staff (int Staff)
    },
    -- 10.2.0 Amirdrassil: below
    -- 11.0.0 Adventurer's Warbound (Delve rewards -- turned into non-token gray after Season 1)
    -- 11.1.0 Liberation of Undermine: below
    -- 11.2.0 Manaforge Omega: below
    -- 12.0 The Voidspire: below
}

-- Common case is everything from a given set having a shared set of link modifiers that represent the difficulty variants
-- See https://warcraft.wiki.gg/wiki/ItemLink for values:
local function addItemsWithVariants(variants, items)
    for tokenid, tokenitems in pairs(items) do
        tokenitems._variants = variants
        ITEMDATA[tokenid] = tokenitems
    end
end
local function addItemsWithBonuses(bonuses, items)
    for i, bonusID in ipairs(bonuses) do
        bonuses[i] = {bonusIDs={bonusID}}
    end
    return addItemsWithVariants(bonuses, items)
end

-- 9.2 Sepulcher of the First Ones class set tokens:
-- Bonuses: LFR 9122, Normal 9123, Heroic 9124, Mythic 9125
addItemsWithBonuses({9122, 9123, 9124, 9125}, {
    -- Mystic
    [191002] = { -- Mystic Helm Module
        DRUID = {188847}, -- Headpiece of the Fixed Stars
        HUNTER = {188859}, -- Godstalker's Sallet
        MAGE = {188844}, -- Erudite Occultist's Hood
    },
    [191007] = { -- Mystic Shoulder Module
        DRUID = {188851}, -- Shoulderpads of the Fixed Stars
        HUNTER = {188856}, -- Godstalker's Pauldrons
        MAGE = {188843}, -- Erudite Occultist's Mantle
    },
    [191011] = { -- Mystic Chest Module
        DRUID = {188849}, -- Chestguard of the Fixed Stars
        HUNTER = {188858}, -- Godstalker's Hauberk
        MAGE = {188839}, -- Erudite Occultist's Robes
    },
    [191015] = { -- Mystic Hand Module
        DRUID = {188853}, -- Handwraps of the Fixed Stars
        HUNTER = {188861}, -- Godstalker's Gauntlets
        MAGE = {188845}, -- Erudite Occultist's Handwraps
    },
    [191019] = { -- Mystic Leg Module
        DRUID = {188848}, -- Leggings of the Fixed Stars
        HUNTER = {188860}, -- Godstalker's Tassets
        MAGE = {188842}, -- Erudite Occultist's Leggings
    },
    -- Venerated
    [191003] = { --Venerated Helm Module
        PALADIN = {188933}, -- Luminous Chevalier's Casque
        PRIEST = {188880}, -- Amice of the Empyrean
        SHAMAN = {188923}, -- Theurgic Starspeaker's Howl
    },
    [191008] = { --Venerated Shoulder Module
        PALADIN = {188932}, -- Luminous Chevalier's Epaulettes
        PRIEST = {188879}, -- Capelet of the Empyrean
        SHAMAN = {188920}, -- Theurgic Starspeaker's Adornment
    },
    [191012] = { --Venerated Chest Module
        PALADIN = {188929}, -- Luminous Chevalier's Plackart
        PRIEST = {188875}, -- Habit of the Empyrean
        SHAMAN = {188922}, -- Theurgic Starspeaker's Ringmail
    },
    [191016] = { --Venerated Hand Module
        PALADIN = {188928}, -- Luminous Chevalier's Gauntlets
        PRIEST = {188881}, -- Caress of the Empyrean
        SHAMAN = {188925}, -- Theurgic Starspeaker's Runebindings
    },
    [191020] = { --Venerated Leg Module
        PALADIN = {188931}, -- Luminous Chevalier's Robes
        PRIEST = {188878}, -- Leggings of the Empyrean
        SHAMAN = {188924}, -- Theurgic Starspeaker's Tassets
    },
    -- Zenith
    [191004] = { -- Zenith Helm Module
        MONK = {188910}, -- Crown of the Grand Upwelling
        ROGUE = {188901}, -- Soulblade Guise
        WARRIOR = {188942}, -- Gaze of the Infinite Infantry
    },
    [191009] = { -- Zenith Shoulder Module
        MONK = {188914}, -- Tassets of the Grand Upwelling
        ROGUE = {188905}, -- Soulblade Nightwings
        WARRIOR = {188941}, -- Pauldrons of the Infinite Infantry
    },
    [191013] = { -- Zenith Chest Module
        MONK = {188912}, -- Cuirass of the Grand Upwelling
        ROGUE = {188903}, -- Soulblade Leathers
        WARRIOR = {188938}, -- Breastplate of the Infinite Infantry
    },
    [191017] = { -- Zenith Hand Module
        MONK = {188916}, -- Grips of the Grand Upwelling
        ROGUE = {188907}, -- Soulblade Grasps
        WARRIOR = {188937}, -- Grasps of the Infinite Infantry
    },
    [191021] = { -- Zenith Leg Module
        MONK = {188911}, -- Legguards of the Grand Upwelling
        ROGUE = {188902}, -- Soulblade Leggings
        WARRIOR = {188940}, -- Legplates of the Infinite Infantry
    },
    -- Dreadful
    [191005] = { -- Dreadful Helm Module
        DEATHKNIGHT = {188868}, -- Visage of the First Eidolon
        DEMONHUNTER = {188892}, -- Mercurial Punisher's Hood
        WARLOCK = {188889}, -- Horns of the Demon Star
    },
    [191006] = { -- Dreadful Shoulder Module
        DEATHKNIGHT = {188867}, -- Shoulderplates of the First Eidolon
        DEMONHUNTER = {188896}, -- Mercurial Punisher's Shoulderpads
        WARLOCK = {188888}, -- Mantle of the Demon Star
    },
    [191010] = { -- Dreadful Chest Module
        DEATHKNIGHT = {188864}, -- Carapace of the First Eidolon
        DEMONHUNTER = {188894}, -- Mercurial Punisher's Jerkin
        WARLOCK = {188884}, -- Robes of the Demon Star
    },
    [191014] = { -- Dreadful Hand Module
        DEATHKNIGHT = {188863}, -- Gauntlets of the First Eidolon
        DEMONHUNTER = {188898}, -- Mercurial Punisher's Grips
        WARLOCK = {188890}, -- Grasps of the Demon Star
    },
    [191018] = { -- Dreadful Leg Module
        DEATHKNIGHT = {188866}, -- Chausses of the First Eidolon
        DEMONHUNTER = {188893}, -- Mercurial Punisher's Breeches
        WARLOCK = {188887}, -- Leggings of the Demon Star
    },
})

-- 10.0 Vault of the Incarnates
-- These are Topaz=Head, Lapis=Shoulder, Amethyst=Chest, Garnet=Hands, Jade=Legs
addItemsWithBonuses({
    -- LFR, Normal, Heroic, Mythic
    13470, 13471, 13472, 13473
}, {
    -- Dreadful (Death Knight, Demon Hunter, Warlock)
    [196586] = { -- Dreadful Amethyst Forgestone
        DEATHKNIGHT = {200405}, -- Breastplate of the Haunted Frostbrood
        DEMONHUNTER = {200342}, -- Skybound Avenger's Harness
        WARLOCK = {200333}, -- Scalesworn Cultist's Frock
    },
    [196587] = { -- Dreadful Garnet Forgestone
        DEATHKNIGHT = {200407}, -- Grasps of the Haunted Frostbrood
        DEMONHUNTER = {200344}, -- Skybound Avenger's Grips
        WARLOCK = {200335}, -- Scalesworn Cultist's Gloves
    },
    [196588] = { -- Dreadful Jade Forgestone
        DEATHKNIGHT = {200409}, -- Greaves of the Haunted Frostbrood
        DEMONHUNTER = {200346}, -- Skybound Avenger's Legguards
        WARLOCK = {200337}, -- Scalesworn Cultist's Culottes
    },
    [196589] = { -- Dreadful Lapis Forgestone
        DEATHKNIGHT = {200410}, -- Jaws of the Haunted Frostbrood
        DEMONHUNTER = {200347}, -- Skybound Avenger's Ailerons
        WARLOCK = {200338}, -- Scalesworn Cultist's Effigy
    },
    [196590] = { -- Dreadful Topaz Forgestone
        DEATHKNIGHT = {200408}, -- Maw of the Haunted Frostbrood
        DEMONHUNTER = {200345}, -- Skybound Avenger's Visor
        WARLOCK = {200336}, -- Scalesworn Cultist's Scorn
    },
    -- Mystic (Druid, Hunter, Mage)
    [196596] = { -- Mystic Amethyst Forgestone
        DRUID = {200351}, -- Lost Landcaller's Robes
        HUNTER = {200387}, -- Stormwing Harrier's Cuirass
        MAGE = {200315}, -- Crystal Scholar's Tunic
    },
    [196597] = { -- Mystic Garnet Forgestone
        DRUID = {200353}, -- Lost Landcaller's Claws
        HUNTER = {200389}, -- Stormwing Harrier's Handguards
        MAGE = {200317}, -- Crystal Scholar's Pageturners
    },
    [196598] = { -- Mystic Jade Forgestone
        DRUID = {200355}, -- Lost Landcaller's Leggings
        HUNTER = {200391}, -- Stormwing Harrier's Greaves
        MAGE = {200319}, -- Crystal Scholar's Britches
    },
    [196599] = { -- Mystic Lapis Forgestone
        DRUID = {200356}, -- Lost Landcaller's Mantle
        HUNTER = {200392}, -- Stormwing Harrier's Pinions
        MAGE = {200320}, -- Crystal Scholar's Beacons
    },
    [196600] = { -- Mystic Topaz Forgestone
        DRUID = {200354}, -- Lost Landcaller's Antlers
        HUNTER = {200390}, -- Stormwing Harrier's Skullmask
        MAGE = {200318}, -- Crystal Scholar's Cowl
    },
})
addItemsWithBonuses({
    -- LFR, Normal, Heroic, Mythic
    7982, 7979, 7980, 7981
}, {
    -- Zenith (Evoker, Monk, Rogue, Warrior)
    [196591] = { -- Zenith Amethyst Forgestone
        EVOKER = {200378}, -- Hauberk of the Awakened
        MONK = {200360}, -- Chestwrap of the Waking Fist
        ROGUE = {200369}, -- Vault Delver's Brigandine
        WARRIOR = {200423}, -- Husk of the Walking Mountain
    },
    [196592] = { -- Zenith Garnet Forgestone
        EVOKER = {200380}, -- Gauntlets of the Awakened
        MONK = {200362}, -- Palms of the Waking Fist
        ROGUE = {200371}, -- Vault Delver's Lockbreakers
        WARRIOR = {200425}, -- Gauntlets of the Walking Mountain
    },
    [196593] = { -- Zenith Jade Forgestone
        EVOKER = {200382}, -- Legguards of the Awakened
        MONK = {200364}, -- Legguards of the Waking Fist
        ROGUE = {200373}, -- Vault Delver's Pantaloons
        WARRIOR = {200427}, -- Poleyns of the Walking Mountain
    },
    [196594] = { -- Zenith Lapis Forgestone
        EVOKER = {200383}, -- Talons of the Awakened
        MONK = {200365}, -- Mantle of the Waking Fist
        ROGUE = {200374}, -- Vault Delver's Epaulets
        WARRIOR = {200428}, -- Peaks of the Walking Mountain
    },
    [196595] = { -- Zenith Topaz Forgestone
        EVOKER = {200381}, -- Crown of the Awakened
        MONK = {200363}, -- Gaze of the Waking Fist
        ROGUE = {200372}, -- Vault Delver's Vizard
        WARRIOR = {200426}, -- Casque of the Walking Mountain
    },
    -- Venerated (Paladin, Priest, Shaman)
    [196601] = { -- Venerated Amethyst Forgestone
        PALADIN = {200414}, -- Virtuous Silver Breastplate
        PRIEST = {200324}, -- Draconic Hierophant's Vestment
        SHAMAN = {200396}, -- Robe of Infused Earth
    },
    [196602] = { -- Venerated Garnet Forgestone
        PALADIN = {200416}, -- Virtuous Silver Gauntlets
        PRIEST = {200326}, -- Draconic Hierophant's Grips
        SHAMAN = {200398}, -- Gauntlets of Infused Earth
    },
    [196603] = { -- Venerated Jade Forgestone
        PALADIN = {200418}, -- Virtuous Silver Cuisses
        PRIEST = {200328}, -- Draconic Hierophant's Britches
        SHAMAN = {200400}, -- Leggings of Infused Earth
    },
    [196604] = { -- Venerated Lapis Forgestone
        PALADIN = {200419}, -- Virtuous Silver Pauldrons
        PRIEST = {200329}, -- Draconic Hierophant's Wisdom
        SHAMAN = {200401}, -- Calderas of Infused Earth
    },
    [196605] = { -- Venerated Topaz Forgestone
        PALADIN = {200417}, -- Virtuous Silver Heaume
        PRIEST = {200327}, -- Draconic Hierophant's Archcowl
        SHAMAN = {200399}, -- Faceguard of Infused Earth
    },
})

-- 10.1.0 Aberrus
addItemsWithBonuses({
    -- LFR, Normal, Heroic, Mythic
    7982, 7979, 7980, 7981
}, {
    -- Dreadful (Death Knight, Demon Hunter, Warlock)
    [202631] = { -- Dreadful Ventilation Fluid (Chest)
        DEATHKNIGHT = {202464}, -- Lingering Phantom's Plackart
        DEMONHUNTER = {202527}, -- Kinslayer's Vest
        WARLOCK = {202536}, -- Cursed Robes of the Sinister Savant
    },
    [202624] = { -- Dreadful Mixing Fluid (Hands)
        DEATHKNIGHT = {202462}, -- Lingering Phantom's Gauntlets
        DEMONHUNTER = {202525}, -- Kinslayer's Bloodstained Grips
        WARLOCK = {202534}, -- Grips of the Sinister Savant
    },
    [202627] = { -- Dreadful Melting Fluid (Helm)
        DEATHKNIGHT = {202461}, -- Lingering Phantom's Dreadhorns
        DEMONHUNTER = {202524}, -- Kinslayer's Hood
        WARLOCK = {202533}, -- Grimhorns of the Sinister Savant
    },
    [202634] = { -- Dreadful Cooling Fluid (Legs)
        DEATHKNIGHT = {202460}, -- Lingering Phantom's Schynbalds
        DEMONHUNTER = {202523}, -- Kinslayer's Legguards
        WARLOCK = {202532}, -- Leggings of the Sinister Savant
    },
    [202621] = { -- Dreadful Corrupting Fluid (Shoulders)
        DEATHKNIGHT = {202459}, -- Lingering Phantom's Shoulderplates
        DEMONHUNTER = {202522}, -- Kinslayer's Tainted Spaulders
        WARLOCK = {202531}, -- Amice of the Sinister Savant
    },
    -- Mystic (Druid, Hunter, Mage)
    [202632] = { -- Mystic Ventilation Fluid (Chest)
        DRUID = {202518}, -- Chestroots of the Autumn Blaze
        HUNTER = {202482}, -- Ashen Predator's Sling Vest
        MAGE = {202554}, -- Underlight Conjurer's Vestment
    },
    [202625] = { -- Mystic Mixing Fluid (Hands)
        DRUID = {202516}, -- Handguards of the Autumn Blaze
        HUNTER = {202480}, -- Ashen Predator's Skinners
        MAGE = {202552}, -- Underlight Conjurer's Gloves
    },
    [202628] = { -- Mystic Melting Fluid (Helm)
        DRUID = {202515}, -- Bough of the Autumn Blaze
        HUNTER = {202479}, -- Ashen Predator's Faceguard
        MAGE = {202551}, -- Underlight Conjurer's Arcanocowl
    },
    [202635] = { -- Mystic Cooling Fluid (Legs)
        DRUID = {202514}, -- Pants of the Autumn Blaze
        HUNTER = {202478}, -- Ashen Predator's Poleyns
        MAGE = {202550}, -- Underlight Conjurer's Trousers
    },
    [202622] = { -- Mystic Corrupting Fluid (Shoulders)
        DRUID = {202513}, -- Mantle of the Autumn Blaze
        HUNTER = {202477}, -- Ashen Predator's Trophy
        MAGE = {202549}, -- Underlight Conjurer's Aurora
    },
    -- Venerated (Paladin, Priest, Shaman)
    [202633] = { -- Venerated Ventilation Fluid (Chest)
        PALADIN = {202455}, -- Heartfire Sentinel's Brigandine
        PRIEST = {202545}, -- Command of the Furnace Seraph
        SHAMAN = {202473}, -- Adornments of the Cinderwolf
    },
    [202626] = { -- Venerated Mixing Fluid (Hands)
        PALADIN = {202453}, -- Heartfire Sentinel's Protectors
        PRIEST = {202543}, -- Grasp of the Furnace Seraph
        SHAMAN = {202471}, -- Knuckles of the Cinderwolf
    },
    [202629] = { -- Venerated Melting Fluid (Helm)
        PALADIN = {202452}, -- Heartfire Sentinel's Forgehelm
        PRIEST = {202542}, -- Mask of the Furnace Seraph
        SHAMAN = {202470}, -- Spangenhelm of the Cinderwolf
    },
    [202636] = { -- Venerated Cooling Fluid (Legs)
        PALADIN = {202451}, -- Heartfire Sentinel's Faulds
        PRIEST = {202541}, -- Breeches of the Furnace Seraph
        SHAMAN = {202469}, -- Braies of the Cinderwolf
    },
    [202623] = { -- Venerated Corrupting Fluid (Shoulders)
        PALADIN = {202450}, -- Heartfire Sentinel's Steelwings
        PRIEST = {202540}, -- Devotion of the Furnace Seraph
        SHAMAN = {202468}, -- Thunderpads of the Cinderwolf
    },
    -- Zenith (Evoker, Monk, Rogue, Warrior)
    [202639] = { -- Zenith Ventilation Fluid (Chest)
        EVOKER = {202491}, -- Hauberk of Obsidian Secrets
        MONK = {202509}, -- Cuirass of the Vermillion Forge
        ROGUE = {202500}, -- Lurking Specter's Brigandine
        WARRIOR = {202446}, -- Battlechest of the Onyx Crucible
    },
    [202638] = { -- Zenith Mixing Fluid (Hands)
        EVOKER = {202489}, -- Claws of Obsidian Secrets
        MONK = {202507}, -- Fists of the Vermillion Forge
        ROGUE = {202498}, -- Lurking Specter's Handgrips
        WARRIOR = {202444}, -- Handguards of the Onyx Crucible
    },
    [202630] = { -- Zenith Melting Fluid (Helm)
        EVOKER = {202488}, -- Crown of Obsidian Secrets
        MONK = {202506}, -- Cover of the Vermillion Forge
        ROGUE = {202497}, -- Lurking Specter's Visage
        WARRIOR = {202443}, -- Thraexhelm of the Onyx Crucible
    },
    [202640] = { -- Zenith Cooling Fluid (Legs)
        EVOKER = {202487}, -- Chausses of Obsidian Secrets
        MONK = {202505}, -- Pantaloons of the Vermillion Forge
        ROGUE = {202496}, -- Lurking Specter's Tights
        WARRIOR = {202442}, -- Legplates of the Onyx Crucible
    },
    [202637] = { -- Zenith Corrupting Fluid (Shoulders)
        EVOKER = {202486}, -- Wingspan of Obsidian Secrets
        MONK = {202504}, -- Spines of the Vermillion Forge
        ROGUE = {202495}, -- Lurking Specter's Shoulderblades
        WARRIOR = {202441}, -- Pauldrons of the Onyx Crucible
    },
})

-- 10.2.0 Amirdrassil
addItemsWithBonuses({
    -- LFR, Normal, Heroic, Mythic
    7982, 7979, 7980, 7981
}, {
    -- Dreadful (Death Knight, Demon Hunter, Warlock)
    [207462] = { -- Dreadful Verdurous Dreamheart (Chest)
        DEATHKNIGHT = {207203}, -- Casket of the Risen Nightmare
        DEMONHUNTER = {207266}, -- Screaming Torchfiend's Binding
        WARLOCK = {207275}, -- Devout Ashdevil's Razorhide
    },
    [207466] = { -- Dreadful Tormented Dreamheart (Hands)
        DEATHKNIGHT = {207201}, -- Thorns of the Risen Nightmare
        DEMONHUNTER = {207264}, -- Screaming Torchfiend's Grasp
        WARLOCK = {207273}, -- Devout Ashdevil's Claws
    },
    [207470] = { -- Dreadful Blazing Dreamheart (Helm)
        DEATHKNIGHT = {207200}, -- Piercing Gaze of the Risen Nightmare
        DEMONHUNTER = {207263}, -- Screaming Torchfiend's Burning Scowl
        WARLOCK = {207272}, -- Devout Ashdevil's Grimhorns
    },
    [207474] = { -- Dreadful Ashen Dreamheart (Legs)
        DEATHKNIGHT = {207199}, -- Greaves of the Risen Nightmare
        DEMONHUNTER = {207262}, -- Screaming Torchfiend's Blazewraps
        WARLOCK = {207271}, -- Devout Ashdevil's Tights
    },
    [207478] = { -- Dreadful Smoldering Dreamheart (Shoulders)
        DEATHKNIGHT = {207198}, -- Skewers of the Risen Nightmare
        DEMONHUNTER = {207261}, -- Screaming Torchfiend's Horned Memento
        WARLOCK = {207270}, -- Devout Ashdevil's Hatespikes
    },
    -- Mystic (Druid, Hunter, Mage)
    [207463] = { -- Mystic Verdurous Dreamheart (Chest)
        DRUID = {207257}, -- Benevolent Embersage's Robe
        HUNTER = {207221}, -- Blazing Dreamstalker's Scaled Hauberk
        MAGE = {207293}, -- Wayward Chronomancer's Patchwork
    },
    [207467] = { -- Mystic Tormented Dreamheart (Hands)
        DRUID = {207255}, -- Benevolent Embersage's Talons
        HUNTER = {207219}, -- Blazing Dreamstalker's Skinners
        MAGE = {207291}, -- Wayward Chronomancer's Gloves
    },
    [207471] = { -- Mystic Blazing Dreamheart (Helm)
        DRUID = {207254}, -- Benevolent Embersage's Casque
        HUNTER = {207218}, -- Blazing Dreamstalker's Flamewaker Horns
        MAGE = {207290}, -- Wayward Chronomancer's Chronocap
    },
    [207475] = { -- Mystic Ashen Dreamheart (Legs)
        DRUID = {207253}, -- Benevolent Embersage's Leggings
        HUNTER = {207217}, -- Blazing Dreamstalker's Shellgreaves
        MAGE = {207289}, -- Wayward Chronomancer's Pantaloons
    },
    [207479] = { -- Mystic Smoldering Dreamheart (Shoulders)
        DRUID = {207252}, -- Benevolent Embersage's Wisdom
        HUNTER = {207216}, -- Blazing Dreamstalker's Finest Hunt
        MAGE = {207288}, -- Wayward Chronomancer's Metronomes
    },
    -- Venerated (Paladin, Priest, Shaman)
    [207464] = { -- Venerated Verdurous Dreamheart (Chest)
        PALADIN = {207194}, -- Zealous Pyreknight's Warplate
        PRIEST = {207284}, -- Cassock of Lunar Communion
        SHAMAN = {207212}, -- Greatwolf Outcast's Harness
    },
    [207468] = { -- Venerated Tormented Dreamheart (Hands)
        PALADIN = {207192}, -- Zealous Pyreknight's Jeweled Gauntlets
        PRIEST = {207282}, -- Touch of Lunar Communion
        SHAMAN = {207210}, -- Greatwolf Outcast's Grips
    },
    [207472] = { -- Venerated Blazing Dreamheart (Helm)
        PALADIN = {207191}, -- Zealous Pyreknight's Barbute
        PRIEST = {207281}, -- Crest of Lunar Communion
        SHAMAN = {207209}, -- Greatwolf Outcast's Jaws
    },
    [207476] = { -- Venerated Ashen Dreamheart (Legs)
        PALADIN = {207190}, -- Zealous Pyreknight's Cuisses
        PRIEST = {207280}, -- Leggings of Lunar Communion
        SHAMAN = {207208}, -- Greatwolf Outcast's Fur-Lined Kilt
    },
    [207480] = { -- Venerated Smoldering Dreamheart (Shoulders)
        PALADIN = {207189}, -- Zealous Pyreknight's Ailettes
        PRIEST = {207279}, -- Shoulderguardians of Lunar Communion
        SHAMAN = {207207}, -- Greatwolf Outcast's Companions
    },
    -- Zenith (Evoker, Monk, Rogue, Warrior)
    [207465] = { -- Zenith Verdurous Dreamheart (Chest)
        EVOKER = {207230}, -- Weyrnkeeper's Timeless Raiment
        MONK = {207248}, -- Mystic Heron's Burdens
        ROGUE = {207239}, -- Lucid Shadewalker's Cuirass
        WARRIOR = {207185}, -- Molten Vanguard's Plackart
    },
    [207469] = { -- Zenith Tormented Dreamheart (Hands)
        EVOKER = {207228}, -- Weyrnkeeper's Timeless Clawguards
        MONK = {207246}, -- Mystic Heron's Glovebills
        ROGUE = {207237}, -- Lucid Shadewalker's Clawgrips
        WARRIOR = {207183}, -- Molten Vanguard's Crushers
    },
    [207473] = { -- Zenith Blazing Dreamheart (Helm)
        EVOKER = {207227}, -- Weyrnkeeper's Timeless Dracoif
        MONK = {207245}, -- Mystic Heron's Hatsuburi
        ROGUE = {207236}, -- Lucid Shadewalker's Deathmask
        WARRIOR = {207182}, -- Molten Vanguard's Domeplate
    },
    [207477] = { -- Zenith Ashen Dreamheart (Legs)
        EVOKER = {207226}, -- Weyrnkeeper's Timeless Breeches
        MONK = {207244}, -- Mystic Heron's Waders
        ROGUE = {207235}, -- Lucid Shadewalker's Chausses
        WARRIOR = {207181}, -- Molten Vanguard's Steel Tassets
    },
    [207481] = { -- Zenith Smoldering Dreamheart (Shoulders)
        EVOKER = {207225}, -- Weyrnkeeper's Timeless Sandbrace
        MONK = {207243}, -- Mystic Heron's Hopeful Effigy
        ROGUE = {207234}, -- Lucid Shadewalker's Bladed Spaulders
        WARRIOR = {207180}, -- Molten Vanguard's Shouldervents
    },
})

-- 11.0.0 Nerub-ar Palace
addItemsWithVariants({
    {instanceDifficultyID=Enum.ItemCreationContext.RaidFinder, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidNormal, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidHeroic, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidMythic, bonusIDs={3524}},
}, {
    -- Dreadful (Death Knight, Demon Hunter, Warlock)
    [225614] = { -- Dreadful Blasphemer's Effigy (Chest)
        DEATHKNIGHT = {212005}, -- Exhumed Centurion's Breastplate
        DEMONHUNTER = {212068}, -- Chestguard of the Hypogeal Nemesis
        WARLOCK = {212077}, -- Hexflame Coven's Ritual Harness
    },
    [225618] = { -- Dreadful Stalwart's Emblem (Hands)
        DEATHKNIGHT = {212003}, -- Exhumed Centurion's Gauntlets
        DEMONHUNTER = {212066}, -- Claws of the Hypogeal Nemesis
        WARLOCK = {212075}, -- Hexflame Coven's Sleeves
    },
    [225622] = { -- Dreadful Conniver's Badge (Helm)
        DEATHKNIGHT = {212002}, -- Exhumed Centurion's Galea
        DEMONHUNTER = {212065}, -- Impalers of the Hypogeal Nemesis
        WARLOCK = {212074}, -- Hexflame Coven's All-Seeing Eye
    },
    [225626] = { -- Dreadful Slayer's Icon (Legs)
        DEATHKNIGHT = {212001}, -- Exhumed Centurion's Chausses
        DEMONHUNTER = {212064}, -- Pantaloons of the Hypogeal Nemesis
        WARLOCK = {212073}, -- Hexflame Coven's Leggings
    },
    [225630] = { -- Dreadful Obscenity's Idol (Shoulders)
        DEATHKNIGHT = {212000}, -- Exhumed Centurion's Spikes
        DEMONHUNTER = {212063}, -- War-Mantle of the Hypogeal Nemesis
        WARLOCK = {212072}, -- Hexflame Coven's Altar
    },

    -- Mystic (Druid, Hunter, Mage)
    [225615] = { -- Mystic Blasphemer's Effigy (Chest)
        DRUID = {212059}, -- Hide of the Greatlynx
        HUNTER = {212023}, -- Lightless Scavenger's Tunic
        MAGE = {212094}, -- Slippers of Violet Rebirth
    },
    [225619] = { -- Mystic Stalwart's Emblem (Hands)
        DRUID = {212057}, -- Eviscerators of the Greatlynx
        HUNTER = {212021}, -- Lightless Scavenger's Mitts
        MAGE = {212093}, -- Jeweled Gauntlets of Violet Rebirth
    },
    [225623] = { -- Mystic Conniver's Badge (Helm)
        DRUID = {212056}, -- Mask of the Greatlynx
        HUNTER = {212020}, -- Lightless Scavenger's Skull
        MAGE = {212092}, -- Hood of Violet Rebirth
    },
    [225627] = { -- Mystic Slayer's Icon (Legs)
        DRUID = {212055}, -- Leggings of the Greatlynx
        HUNTER = {212019}, -- Lightless Scavenger's Stalkings
        MAGE = {212091}, -- Coattails of Violet Rebirth
    },
    [225631] = { -- Mystic Obscenity's Idol (Shoulders)
        DRUID = {212054}, -- Maw of the Greatlynx
        HUNTER = {212018}, -- Lightless Scavenger's Taxidermy
        MAGE = {212090}, -- Beacons of Violet Rebirth
    },

    -- Venerated (Paladin, Priest, Shaman)
    [225616] = { -- Venerated Blasphemer's Effigy (Chest)
        PALADIN = {211996}, -- Entombed Seraph's Breastplate
        PRIEST = {212086}, -- Living Luster's Raiment
        SHAMAN = {212014}, -- Vestments of the Forgotten Reservoir
    },
    [225620] = { -- Venerated Stalwart's Emblem (Hands)
        PALADIN = {211994}, -- Entombed Seraph's Castigation
        PRIEST = {212084}, -- Living Luster's Touch
        SHAMAN = {212012}, -- Covenant of the Forgotten Reservoir
    },
    [225624] = { -- Venerated Conniver's Badge (Helm)
        PALADIN = {211993}, -- Entombed Seraph's Casque
        PRIEST = {212083}, -- Living Luster's Semblance
        SHAMAN = {212011}, -- Noetic of the Forgotten Reservoir
    },
    [225628] = { -- Venerated Slayer's Icon (Legs)
        PALADIN = {211992}, -- Entombed Seraph's Greaves
        PRIEST = {212082}, -- Living Luster's Trousers
        SHAMAN = {212010}, -- Sarong of the Forgotten Reservoir
    },
    [225632] = { -- Venerated Obscenity's Idol (Shoulders)
        PALADIN = {211991}, -- Entombed Seraph's Plumes
        PRIEST = {212081}, -- Living Luster's Dominion
        SHAMAN = {212009}, -- Concourse of the Forgotten Reservoir
    },

    -- Zenith (Evoker, Monk, Rogue, Warrior)
    [225617] = { -- Zenith Blasphemer's Effigy (Chest)
        EVOKER = {212032}, -- Scales of the Destroyer
        MONK = {212050}, -- Gatecrasher's Gi
        ROGUE = {212041}, -- K'areshi Phantom's Nexus Wraps
        WARRIOR = {211987}, -- Warsculptor's Furred Plastron
    },
    [225621] = { -- Zenith Stalwart's Emblem (Hands)
        EVOKER = {212030}, -- Rippers of the Destroyer
        MONK = {212048}, -- Gatecrasher's Protectors
        ROGUE = {212039}, -- K'areshi Phantom's Grips
        WARRIOR = {211985}, -- Warsculptor's Crushers
    },
    [225625] = { -- Zenith Conniver's Badge (Helm)
        EVOKER = {212029}, -- Horns of the Destroyer
        MONK = {212047}, -- Gatecrasher's Horns
        ROGUE = {212038}, -- K'areshi Phantom's Emptiness
        WARRIOR = {211984}, -- Warsculptor's Barbute
    },
    [225629] = { -- Zenith Slayer's Icon (Legs)
        EVOKER = {212028}, -- Legguards of the Destroyer
        MONK = {212046}, -- Gatecrasher's Kilt
        ROGUE = {212037}, -- K'areshi Phantom's Leggings
        WARRIOR = {211983}, -- Warsculptor's Cuisses
    },
    [225633] = { -- Zenith Obscenity's Idol (Shoulders)
        EVOKER = {212027}, -- Fumaroles of the Destroyer
        MONK = {212045}, -- Gatecrasher's Enduring Effigy
        ROGUE = {212036}, -- K'areshi Phantom's Shoulderpads
        WARRIOR = {211982}, -- Warsculptor's Horned Spaulders
    },
})

-- 11.1.0 Liberation of Undermine
addItemsWithVariants({
    {instanceDifficultyID=Enum.ItemCreationContext.RaidFinder, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidNormal, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidHeroic, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidMythic, bonusIDs={3524}},
}, {
    -- Dreadful (Death Knight, Demon Hunter, Warlock)
    [228799] = { -- Dreadful Greased Gallybux (Chest)
        DEATHKNIGHT = {229256}, -- Cauldron Champion's Ribcage
        DEMONHUNTER = {229319}, -- Fel-Dealer's Soul Engine
        WARLOCK = {229328}, -- Spliced Fiendtrader's Surgical Gown
    },
    [228803] = { -- Dreadful Bloody Gallybux (Hands)
        DEATHKNIGHT = {229254}, -- Cauldron Champion's Fistguards
        DEMONHUNTER = {229317}, -- Fel-Dealer's Underhandlers
        WARLOCK = {229326}, -- Spliced Fiendtrader's Demonic Grasp
    },
    [228807] = { -- Dreadful Gilded Gallybux (Helm)
        DEATHKNIGHT = {229253}, -- Cauldron Champion's Crown
        DEMONHUNTER = {229316}, -- Fel-Dealer's Visor
        WARLOCK = {229325}, -- Spliced Fiendtrader's Transcendence
    },
    [228811] = { -- Dreadful Rusty Gallybux (Legs)
        DEATHKNIGHT = {229252}, -- Cauldron Champion's Tattered Cuisses
        DEMONHUNTER = {229315}, -- Fel-Dealer's Fur Kilt
        WARLOCK = {229324}, -- Spliced Fiendtrader's Skin Tights
    },
    [228815] = { -- Dreadful Polished Gallybux (Shoulders)
        DEATHKNIGHT = {229251}, -- Cauldron Champion's Screamplate
        DEMONHUNTER = {229314}, -- Fel-Dealer's Recycled Reavers
        WARLOCK = {229323}, -- Spliced Fiendtrader's Loyal Servants
    },

    -- Mystic (Druid, Hunter, Mage)
    [228800] = { -- Mystic Greased Gallybux (Chest)
        DRUID = {229310}, -- Robes of Reclaiming Blight
        HUNTER = {229274}, -- Tireless Collector's Battlegear
        MAGE = {229346}, -- Aspectral Emissary's Primal Robes
    },
    [228804] = { -- Mystic Bloody Gallybux (Hands)
        DRUID = {229308}, -- Grips of Reclaiming Blight
        HUNTER = {229272}, -- Tireless Collector's Gauntlets
        MAGE = {229344}, -- Aspectral Emissary's Hardened Grasp
    },
    [228808] = { -- Mystic Gilded Gallybux (Helm)
        DRUID = {229307}, -- Branches of Reclaiming Blight
        HUNTER = {229271}, -- Tireless Collector's Chained Cowl
        MAGE = {229343}, -- Aspectral Emissary's Crystalline Cowl
    },
    [228812] = { -- Mystic Rusty Gallybux (Legs)
        DRUID = {229306}, -- Breeches of Reclaiming Blight
        HUNTER = {229270}, -- Tireless Collector's Armored Breeches
        MAGE = {229342}, -- Aspectral Emissary's Trousers
    },
    [228816] = { -- Mystic Polished Gallybux (Shoulders)
        DRUID = {229305}, -- Jaws of Reclaiming Blight
        HUNTER = {229269}, -- Tireless Collector's Hunted Heads
        MAGE = {229341}, -- Aspectral Emissary's Arcane Vents
    },

    -- Venerated (Paladin, Priest, Shaman)
    [228801] = { -- Venerated Greased Gallybux (Chest)
        PALADIN = {229247}, -- Aureate Sentry's Encasement
        PRIEST = {229337}, -- Confessor's Unshakable Vestment
        SHAMAN = {229265}, -- Gale Sovereign's Clouded Hauberk
    },
    [228805] = { -- Venerated Bloody Gallybux (Hands)
        PALADIN = {229245}, -- Aureate Sentry's Gauntlets
        PRIEST = {229335}, -- Confessor's Unshakable Mitts
        SHAMAN = {229263}, -- Gale Sovereign's Grasps
    },
    [228809] = { -- Venerated Gilded Gallybux (Helm)
        PALADIN = {229244}, -- Aureate Sentry's Pledge
        PRIEST = {229334}, -- Confessor's Unshakable Halo
        SHAMAN = {229262}, -- Gale Sovereign's Charged Hood
    },
    [228813] = { -- Venerated Rusty Gallybux (Legs)
        PALADIN = {229243}, -- Aureate Sentry's Legguards
        PRIEST = {229333}, -- Confessor's Unshakable Leggings
        SHAMAN = {229261}, -- Gale Sovereign's Pantaloons
    },
    [228817] = { -- Venerated Polished Gallybux (Shoulders)
        PALADIN = {229242}, -- Aureate Sentry's Roaring Will
        PRIEST = {229332}, -- Confessor's Unshakable Radiance
        SHAMAN = {229260}, -- Gale Sovereign's Zephyrs
    },

    -- Zenith (Evoker, Monk, Rogue, Warrior)
    [228802] = { -- Zenith Greased Gallybux (Chest)
        EVOKER = {229283}, -- Opulent Treasurescale's Tunic
        MONK = {229301}, -- Ageless Serpent's Inked Coils
        ROGUE = {229292}, -- Spectral Gambler's Vest
        WARRIOR = {229238}, -- Enforcer's Backalley Vestplate
    },
    [228806] = { -- Zenith Bloody Gallybux (Hands)
        EVOKER = {229281}, -- Opulent Treasurescale's Gold-Counters
        MONK = {229299}, -- Ageless Serpent's Handguards
        ROGUE = {229290}, -- Spectral Gambler's Gloves
        WARRIOR = {229236}, -- Enforcer's Backalley Crushers
    },
    [228810] = { -- Zenith Gilded Gallybux (Helm)
        EVOKER = {229280}, -- Opulent Treasurescale's Crowned Jewel
        MONK = {229298}, -- Ageless Serpent's Mane
        ROGUE = {229289}, -- Spectral Gambler's Damned Visage
        WARRIOR = {229235}, -- Enforcer's Backalley Faceshield
    },
    [228814] = { -- Zenith Rusty Gallybux (Legs)
        EVOKER = {229279}, -- Opulent Treasurescale's Petticoat
        MONK = {229297}, -- Ageless Serpent's Leggings
        ROGUE = {229288}, -- Spectral Gambler's Pantaloons
        WARRIOR = {229234}, -- Enforcer's Backalley Chausses
    },
    [228818] = { -- Zenith Polished Gallybux (Shoulders)
        EVOKER = {229278}, -- Opulent Treasurescale's Gleaming Mantle
        MONK = {229296}, -- Ageless Serpent's Shoulderpads
        ROGUE = {229287}, -- Spectral Gambler's Bladed Mantle
        WARRIOR = {229233}, -- Enforcer's Backalley Shoulderplates
    },
})

-- 12.0 The Voidspire
addItemsWithVariants({
    {instanceDifficultyID=Enum.ItemCreationContext.RaidFinder, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidNormal, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidHeroic, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidMythic, bonusIDs={3524}},
}, {
    -- Dreadful (Death Knight, Demon Hunter, Warlock)
    [237581] = { -- Dreadful Voidglass Contaminant (Chest)
        DEATHKNIGHT = {237631}, -- Hollow Sentinel's Breastplate
        DEMONHUNTER = {237694}, -- Charhound's Vicious Bindings
        WARLOCK = {237703}, -- Inquisitor's Robes of Madness
    },
    [237585] = { -- Dreadful Binding Agent (Hands)
        DEATHKNIGHT = {237629}, -- Hollow Sentinel's Gauntlets
        DEMONHUNTER = {237692}, -- Charhound's Vicious Felclaws
        WARLOCK = {237701}, -- Inquisitor's Clutches of Madness
    },
    [237589] = { -- Dreadful Foreboding Beaker (Head)
        DEATHKNIGHT = {237628}, -- Hollow Sentinel's Stonemask
        DEMONHUNTER = {237691}, -- Charhound's Vicious Scalp
        WARLOCK = {237700}, -- Inquisitor's Portal to Madness
    },
    [237593] = { -- Dreadful Silken Offering (Legs)
        DEATHKNIGHT = {237627}, -- Hollow Sentinel's Stonekilt
        DEMONHUNTER = {237690}, -- Charhound's Vicious Hidecoat
        WARLOCK = {237699}, -- Inquisitor's Leggings of Madness
    },
    [237597] = { -- Dreadful Yearning Cursemark (Shoulders)
        DEATHKNIGHT = {237626}, -- Hollow Sentinel's Perches
        DEMONHUNTER = {237689}, -- Charhound's Vicious Hornguards
        WARLOCK = {237698}, -- Inquisitor's Gaze of Madness
    },

    -- Mystic (Druid, Hunter, Mage)
    [237582] = { -- Mystic Voidglass Contaminant (Chest)
        DRUID = {237685}, -- Vest of the Mother Eagle
        HUNTER = {237649}, -- Midnight Herald's Hauberk
        MAGE = {237721}, -- Augur's Ephemeral Habiliments
    },
    [237586] = { -- Mystic Binding Agent (Hands)
        DRUID = {237683}, -- Wings of the Mother Eagle
        HUNTER = {237647}, -- Midnight Herald's Gloves
        MAGE = {237719}, -- Augur's Ephemeral Mitts
    },
    [237590] = { -- Mystic Foreboding Beaker (Head)
        DRUID = {237682}, -- Skymane of the Mother Eagle
        HUNTER = {237646}, -- Midnight Herald's Cowl
        MAGE = {237718}, -- Augur's Ephemeral Wide-Brim
    },
    [237594] = { -- Mystic Silken Offering (Legs)
        DRUID = {237681}, -- Breeches of the Mother Eagle
        HUNTER = {237645}, -- Midnight Herald's Petticoat
        MAGE = {237717}, -- Augur's Ephemeral Trousers
    },
    [237598] = { -- Mystic Yearning Cursemark (Shoulders)
        DRUID = {237680}, -- Ritual Pauldrons of the Mother Eagle
        HUNTER = {237644}, -- Midnight Herald's Shadowguards
        MAGE = {237716}, -- Augur's Ephemeral Orbs of Power
    },

    -- Venerated (Paladin, Priest, Shaman)
    [237583] = { -- Venerated Voidglass Contaminant (Chest)
        PALADIN = {237622}, -- Cuirass of the Lucent Battalion
        PRIEST = {237712}, -- Dying Star's Cassock
        SHAMAN = {237640}, -- Furs of Channeled Fury
    },
    [237587] = { -- Venerated Binding Agent (Hands)
        PALADIN = {237620}, -- Protectors of the Lucent Battalion
        PRIEST = {237710}, -- Dying Star's Caress
        SHAMAN = {237638}, -- Claws of Channeled Fury
    },
    [237591] = { -- Venerated Foreboding Beaker (Head)
        PALADIN = {237619}, -- Lightmane of the Lucent Battalion
        PRIEST = {237709}, -- Dying Star's Veil
        SHAMAN = {237637}, -- Aspect of Channeled Fury
    },
    [237595] = { -- Venerated Silken Offering (Legs)
        PALADIN = {237618}, -- Cuisses of the Lucent Battalion
        PRIEST = {237708}, -- Dying Star's Leggings
        SHAMAN = {237636}, -- Tassets of Channeled Fury
    },
    [237599] = { -- Venerated Yearning Cursemark (Shoulders)
        PALADIN = {237617}, -- Chargers of the Lucent Battalion
        PRIEST = {237707}, -- Dying Star's Pyrelights
        SHAMAN = {237635}, -- Fangs of Channeled Fury
    },

    -- Zenith (Evoker, Monk, Rogue, Warrior)
    [237584] = { -- Zenith Voidglass Contaminant (Chest)
        EVOKER = {237658}, -- Spellweaver's Immaculate Crestward
        MONK = {237676}, -- Gi of Fallen Storms
        ROGUE = {237667}, -- Tactical Vest of the Sudden Eclipse
        WARRIOR = {237613}, -- Living Weapon's Bulwark
    },
    [237588] = { -- Zenith Binding Agent (Hands)
        EVOKER = {237656}, -- Spellweaver's Immaculate Scaleguards
        MONK = {237674}, -- Grasp of Fallen Storms
        ROGUE = {237665}, -- Deathgrips of the Sudden Eclipse
        WARRIOR = {237611}, -- Living Weapon's Crushers
    },
    [237592] = { -- Zenith Foreboding Beaker (Head)
        EVOKER = {237655}, -- Spellweaver's Immaculate Focus
        MONK = {237673}, -- Half-Mask of Fallen Storms
        ROGUE = {237664}, -- Hood of the Sudden Eclipse
        WARRIOR = {237610}, -- Living Weapon's Faceshield
    },
    [237596] = { -- Zenith Silken Offering (Legs)
        EVOKER = {237654}, -- Spellweaver's Immaculate Runeslacks
        MONK = {237672}, -- Legwraps of Fallen Storms
        ROGUE = {237663}, -- Pants of the Sudden Eclipse
        WARRIOR = {237609}, -- Living Weapon's Legguards
    },
    [237600] = { -- Zenith Yearning Cursemark (Shoulders)
        EVOKER = {237653}, -- Spellweaver's Immaculate Pauldrons
        MONK = {237671}, -- Glyphs of Fallen Storms
        ROGUE = {237662}, -- Smokemantle of the Sudden Eclipse
        WARRIOR = {237608}, -- Living Weapon's Ramparts
    },
})

addItemsWithVariants({
    {instanceDifficultyID=Enum.ItemCreationContext.RaidFinder, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidNormal, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidHeroic, bonusIDs={3524}},
    {instanceDifficultyID=Enum.ItemCreationContext.RaidMythic, bonusIDs={3524}},
}, {
    -- Voidforged (Warrior, Paladin, Death Knight)
    [249354] = { -- Voidforged Hungering Nullcore (Hands)
        WARRIOR = {249953}, -- Night Ender's Fists
        PALADIN = {249962}, -- Luminant Verdict's Gauntlets
        DEATHKNIGHT = {249971}, -- Relentless Rider's Bonegrasps
    },
    [249358] = { -- Voidforged Fanatical Nullcore (Head)
        WARRIOR = {249952}, -- Night Ender's Tusks
        PALADIN = {249961}, -- Luminant Verdict's Unwavering Gaze
        DEATHKNIGHT = {249970}, -- Relentless Rider's Crown
    },
    [249362] = { -- Voidforged Corrupted Nullcore (Legs)
        WARRIOR = {249951}, -- Night Ender's Chausses
        PALADIN = {249960}, -- Luminant Verdict's Greaves
        DEATHKNIGHT = {249969}, -- Relentless Rider's Legguards
    },
    [249366] = { -- Voidforged Unraveled Nullcore (Shoulders)
        WARRIOR = {249950}, -- Night Ender's Pauldrons
        PALADIN = {249959}, -- Luminant Verdict's Providence Watch
        DEATHKNIGHT = {249968}, -- Relentless Rider's Dreadthorns
    },

    -- Voidcured (Rogue, Monk, Druid, Demon Hunter)
    [249352] = { -- Voidcured Hungering Nullcore (Hands)
        ROGUE = {250007}, -- Sleight of Hand of the Grim Jest
        MONK = {250016}, -- Thunderfists of Ra-den's Chosen
        DRUID = {250025}, -- Arbortenders of the Luminous Bloom
        DEMONHUNTER = {250034}, -- Devouring Reaver's Essence Grips
    },
    [249356] = { -- Voidcured Fanatical Nullcore (Head)
        ROGUE = {250006}, -- Masquerade of the Grim Jest
        MONK = {250015}, -- Fearsome Visage of Ra-den's Chosen
        DRUID = {250024}, -- Branches of the Luminous Bloom
        DEMONHUNTER = {250033}, -- Devouring Reaver's Intake
    },
    [249360] = { -- Voidcured Corrupted Nullcore (Legs)
        ROGUE = {250005}, -- Blade Holsters of the Grim Jest
        MONK = {250014}, -- Swiftsweepers of Ra-den's Chosen
        DRUID = {250023}, -- Phloemwraps of the Luminous Bloom
        DEMONHUNTER = {250032}, -- Devouring Reaver's Pistons
    },
    [249364] = { -- Voidcured Unraveled Nullcore (Shoulders)
        ROGUE = {250004}, -- Venom Casks of the Grim Jest
        MONK = {250013}, -- Aurastones of Ra-den's Chosen
        DRUID = {250022}, -- Seedpods of the Luminous Bloom
        DEMONHUNTER = {250031}, -- Devouring Reaver's Exhaustplates
    },

    -- Voidcast (Hunter, Shaman, Evoker)
    [249353] = { -- Voidcast Hungering Nullcore (Hands)
        HUNTER = {249989}, -- Primal Sentry's Talonguards
        SHAMAN = {249980}, -- Earthgrips of the Primal Core
        EVOKER = {249998}, -- Enforcer's Grips of the Black Talon
    },
    [249357] = { -- Voidcast Fanatical Nullcore (Head)
        HUNTER = {249988}, -- Primal Sentry's Maw
        SHAMAN = {249979}, -- Locus of the Primal Core
        EVOKER = {249997}, -- Hornhelm of the Black Talon
    },
    [249361] = { -- Voidcast Corrupted Nullcore (Legs)
        HUNTER = {249987}, -- Primal Sentry's Legguards
        SHAMAN = {249978}, -- Leggings of the Primal Core
        EVOKER = {249996}, -- Greaves of the Black Talon
    },
    [249365] = { -- Voidcast Unraveled Nullcore (Shoulders)
        HUNTER = {249986}, -- Primal Sentry's Trophies
        SHAMAN = {249977}, -- Tempests of the Primal Core
        EVOKER = {249995}, -- Beacons of the Black Talon
    },

    -- Voidwoven (Priest, Mage, Warlock)
    [249351] = { -- Voidwoven Hungering Nullcore (Hands)
        PRIEST = {250052}, -- Blind Oath's Touch
        MAGE = {250061}, -- Voidbreaker's Gloves
        WARLOCK = {250043}, -- Abyssal Immolator's Grasps
    },
    [249355] = { -- Voidwoven Fanatical Nullcore (Head)
        PRIEST = {250051}, -- Blind Oath's Winged Crest
        MAGE = {250060}, -- Voidbreaker's Veil
        WARLOCK = {250042}, -- Abyssal Immolator's Smoldering Flames
    },
    [249359] = { -- Voidwoven Corrupted Nullcore (Legs)
        PRIEST = {250050}, -- Blind Oath's Leggings
        MAGE = {250059}, -- Voidbreaker's Britches
        WARLOCK = {250041}, -- Abyssal Immolator's Pillars
    },
    [249363] = { -- Voidwoven Unraveled Nullcore (Shoulders)
        PRIEST = {250049}, -- Blind Oath's Seraphguards
        MAGE = {250058}, -- Voidbreaker's Leyline Nexi
        WARLOCK = {250040}, -- Abyssal Immolator's Fury
    },

    -- Alnforged (Warrior, Paladin, Death Knight)
    [249350] = { -- Alnforged Riftbloom (Chest)
        WARRIOR = {249955}, -- Night Ender's Breastplate
        PALADIN = {249964}, -- Luminant Verdict's Divine Warplate
        DEATHKNIGHT = {249973}, -- Relentless Rider's Cuirass
    },

    -- Alncured (Rogue, Monk, Druid, Demon Hunter)
    [249348] = { -- Alncured Riftbloom (Chest)
        ROGUE = {250009}, -- Fantastic Finery of the Grim Jest
        MONK = {250018}, -- Battle Garb of Ra-den's Chosen
        DRUID = {250027}, -- Trunk of the Luminous Bloom
        DEMONHUNTER = {250036}, -- Devouring Reaver's Engine
    },

    -- Alncast (Hunter, Shaman, Evoker)
    [249349] = { -- Alncast Riftbloom (Chest)
        HUNTER = {249991}, -- Primal Sentry's Scaleplate
        SHAMAN = {249982}, -- Embrace of the Primal Core
        EVOKER = {250000}, -- Frenzyward of the Black Talon
    },

    -- Alnwoven (Priest, Mage, Warlock)
    [249347] = { -- Alnwoven Riftbloom (Chest)
        PRIEST = {250054}, -- Blind Oath's Raiment
        MAGE = {250063}, -- Voidbreaker's Robe
        WARLOCK = {250045}, -- Abyssal Immolator's Dreadrobe
    },
})

-- END DATA

lib._ITEMDATA = ITEMDATA
