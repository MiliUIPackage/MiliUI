local addonName = ...
local addon = _G[addonName]

local followerXPItemIDs = {
    [187414] = true, 
    [187415] = true, 
    [187413] = true, 
    [188655] = true,   
    [188656] = true, 
    [188657] = true, 
    [188651] = 2400,
    [188654] = 6000,
    [184688] = 6000,
    [188652] = 3600,
    [184687] = 5000,
    [184684] = 2000,
    [184686] = 3600,
    [188653] = 5000,
    [188650] = 2000,
    [184685] = 2400,
}

addon.followerXPItemIDs = followerXPItemIDs

local reputationCurrencyIDs = {
    [1804] = true, -- Ascended
    [1805] = true, -- Undying Army
    [1806] = true, -- Wild Hunt
    [1807] = true, -- Court of Harvesters
}
addon.reputationCurrencyIDs = reputationCurrencyIDs

local SPELL_ID_ENCHANTING = 7411
local SPELL_ID_TAILORING = 3908
local SPELL_ID_SKINNING = 8613
local SPELL_ID_MINING = 2575
local SPELL_ID_HERBALISM = 2366
local SPELL_ID_COOKING = 2550
local SPELL_ID_FISHING = 131474

local craftingCacheCategories = {
    [SPELL_ID_ENCHANTING] = GetSpellInfo(SPELL_ID_ENCHANTING),
    [SPELL_ID_TAILORING] = GetSpellInfo(SPELL_ID_TAILORING),
    [SPELL_ID_SKINNING] = GetSpellInfo(SPELL_ID_SKINNING),
    [SPELL_ID_MINING] = GetSpellInfo(SPELL_ID_MINING),
    [SPELL_ID_HERBALISM] = GetSpellInfo(SPELL_ID_HERBALISM),
    [SPELL_ID_COOKING] = GetSpellInfo(SPELL_ID_COOKING),
    [SPELL_ID_FISHING] = GetSpellInfo(SPELL_ID_FISHING),
    ["zereth"] = C_Map.GetMapInfo(1970).name,
}
addon.craftingCacheCategories = craftingCacheCategories

local craftingMaterialsCacheIDs = {
    [184634] = SPELL_ID_HERBALISM, -- Adventurer's Herbalism Cache
    [184633] = SPELL_ID_COOKING, -- Champion's Meat Cache
    [184637] = SPELL_ID_COOKING, -- Hero's Meat Cache
    [184640] = SPELL_ID_SKINNING, -- Champion's Skinning Cache
    [184636] = SPELL_ID_SKINNING, -- Adventurer's Skinning Cache
    [184631] = SPELL_ID_ENCHANTING, -- Adventurer's Enchanting Cache
    [184639] = SPELL_ID_TAILORING, -- Champion's Tailoring Cache
    [184642] = SPELL_ID_HERBALISM, -- Champion's Herbalism Cache
    [184630] = SPELL_ID_TAILORING, -- Adventurer's Tailoring Cache
    [184632] = SPELL_ID_FISHING, -- Champion's Fish Cache
    [184643] = SPELL_ID_ENCHANTING, -- Champion's Enchanting Cache
    [184647] = SPELL_ID_HERBALISM, -- Hero's Herbalism Cache
    [187575] = SPELL_ID_FISHING, -- Korthian Fishing Cache
    [184641] = SPELL_ID_MINING, -- Champion's Mining Cache
    [184644] = SPELL_ID_TAILORING, -- Hero's Tailoring Cache
    [184645] = SPELL_ID_SKINNING, -- Hero's Skinning Cache
    [184646] = SPELL_ID_MINING, -- Hero's Mining Cache
    [187576] = SPELL_ID_SKINNING, -- Korthian Skinning Cache
    [184635] = SPELL_ID_MINING, -- Adventurer's Mining Cache
    [184648] = SPELL_ID_ENCHANTING, -- Hero's Enchanting Cache
    [187577] = SPELL_ID_COOKING, -- Korthian Meat Cache
    [184638] = SPELL_ID_FISHING, -- Hero's Fish Cache
    [190178] = "zereth", -- Pouch of Protogenic Provisions
    [187569] = SPELL_ID_TAILORING, -- Brokers' Tailoring Mote of Potentiation
    [187573] = SPELL_ID_ENCHANTING, -- Brokers' Enchanting Mote of Potentiation
    [187572] = SPELL_ID_HERBALISM, -- Brokers' Herbalism Mote of Potentiation
    [187574] = SPELL_ID_FISHING, -- Brokers' Overflowing Bucket -- (has both meat and fish)
}
addon.craftingMaterialsCacheIDs = craftingMaterialsCacheIDs

-- 1 = Common (white)
-- 2 = Uncommon (green)
-- 3 = Rare (blue)
local craftingCacheQualities = {
    [184634] = 1, -- Adventurer's Herbalism Cache
    [184633] = 2, -- Champion's Meat Cache
    [184637] = 3, -- Hero's Meat Cache
    [184640] = 2, -- Champion's Skinning Cache
    [184636] = 1, -- Adventurer's Skinning Cache
    [184631] = 1, -- Adventurer's Enchanting Cache
    [184639] = 2, -- Champion's Tailoring Cache
    [184642] = 2, -- Champion's Herbalism Cache
    [184630] = 1, -- Adventurer's Tailoring Cache
    [184632] = 2, -- Champion's Fish Cache
    [184643] = 2, -- Champion's Enchanting Cache
    [184647] = 3, -- Hero's Herbalism Cache
    [187575] = 3, -- Korthian Fishing Cache
    [184641] = 2, -- Champion's Mining Cache
    [184644] = 3, -- Hero's Tailoring Cache
    [184645] = 3, -- Hero's Skinning Cache
    [184646] = 3, -- Hero's Mining Cache
    [187576] = 3, -- Korthian Skinning Cache
    [184635] = 1, -- Adventurer's Mining Cache
    [184648] = 3, -- Hero's Enchanting Cache
    [187577] = 3, -- Korthian Meat Cache
    [184638] = 3, -- Hero's Fish Cache
    [190178] = 3, -- Pouch of Protogenic Provisions
    [187569] = 3, -- Brokers' Tailoring Mote of Potentiation
    [187573] = 3, -- Brokers' Enchanting Mote of Potentiation
    [187572] = 3, -- Brokers' Herbalism Mote of Potentiation
    [187574] = 3,
}
addon.craftingCacheQualities = craftingCacheQualities

local runecarverCurrencyIDs = {
    [1767] = false, -- Stygia, making it off by default
    [1828] = true,
    [1906] = true,
    [2009] = true, -- Cosmic Flux, not currently a reward for any missions, I'll leave it here incase they add one in 9.2.5 or whatever
}
addon.runecarverCurrencyIDs = runecarverCurrencyIDs

local stygiaItemID = 178040

local sanctumFeatureItems = {
    [COVENANT_SANCTUM_FEATURE_NECROLORDS] = {
        [183744] = true,
    },
    [COVENANT_SANCTUM_FEATURE_NIGHT_FAE] = {
        [177699] = true,
        [178877] = true,
        [178880] = true,
        [178883] = true,
    },
    [COVENANT_SANCTUM_FEATURE_KYRIAN] = {},
    [COVENANT_SANCTUM_FEATURE_VENTHYR] = {
        [168583] = true,
        [168589] = true,
        [170554] = true,
        [171263] = true,
        [171264] = true,
        [171266] = true,
        [171267] = true,
        [171274] = true,
        [171301] = true,
        [171828] = true,
        [171831] = true,
        [171832] = true,
        [171840] = true,
        [171841] = true,
        [172230] = true,
        [172416] = true,
        [172902] = true,
        [172904] = true,
        [173049] = true,
        [173059] = true,
        [173109] = true,
        [173141] = true,
        [173202] = true,
        [177061] = true,
    },
}
addon.sanctumFeatureItems = sanctumFeatureItems

local sanctumFeatureCurrencies = {
    [COVENANT_SANCTUM_FEATURE_KYRIAN] = {
        [1819] = true,
    },
    [COVENANT_SANCTUM_FEATURE_VENTHYR] = {
        [1816] = true,
        [1820] = true,
    },
    [COVENANT_SANCTUM_FEATURE_NECROLORDS] = {},
    [COVENANT_SANCTUM_FEATURE_NIGHT_FAE] = {},
}
addon.sanctumFeatureCurrencies = sanctumFeatureCurrencies

local function isSanctumFeatureItem(itemID)
    for categoryName, category in pairs(sanctumFeatureItems) do
        for k, v in pairs(category) do
            if itemID == k then
                return true
            end
        end
    end
end

local function isSanctumFeatureCurrency(currencyID)
    for categoryName, category in pairs(sanctumFeatureCurrencies) do
        for k, v in pairs(category) do
            if currencyID == k then
                return true
            end
        end
    end
end

function addon:GetAllMissionsMatchingFilter(rewardFilter, hard)
    local missions = C_Garrison.GetAvailableMissions(123)
    local missionLineup = {}
    
    for _, mission in pairs(missions) do
        local rewards = mission.rewards
        local include = false
        for _, reward in pairs(rewards) do
            if (rewardFilter == "gold") and reward.currencyID and (reward.currencyID == 0) then
                include = true
            end
            
            if (rewardFilter == "followerxp") and reward.followerXP then
                include = true
            end
            
            if (rewardFilter == "pet-charms") and (reward.itemID == 163036) then
                include = true
            end
            
            if (rewardFilter == "augment-runes") and (reward.itemID == 181468) then
                include = true
            end
        end
        
        if include then
            table.insert(missionLineup, mission)
        end
    end
    
    local sort_func
    if hard then
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar > b.missionScalar
        end
    else
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar < b.missionScalar
        end
    end
    
    table.sort(missionLineup, sort_func)
    
    return missionLineup
end

function addon:GetGoldMissions(hard)
    return addon:GetAllMissionsMatchingFilter("gold", hard)
end

function addon:GetFollowerXPMissions(hard)
    return addon:GetAllMissionsMatchingFilter("followerxp", hard)
end

function addon:GetFollowerXPItemMissions(hard)
    local missions = C_Garrison.GetAvailableMissions(123)
    local missionLineup = {}
    
    for _, mission in pairs(missions) do
        for _, reward in pairs(mission.rewards) do
            if reward.itemID and followerXPItemIDs[reward.itemID] and addon.db.profile.followerXPItemsItemQualities[select(3, addon:GetItemInfo(reward.itemID))] then
                table.insert(missionLineup, mission)
            end
        end
    end
    
    local sort_func
    if hard then
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar > b.missionScalar
        end
    else
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar < b.missionScalar
        end
    end
    
    table.sort(missionLineup, sort_func)
    
    return missionLineup
end

local animaItemDiscrepancies = {}
function addon:GetAnimaMissions(hard)
    local missions = C_Garrison.GetAvailableMissions(123)
    local missionLineup = {}
    
    for _, mission in pairs(missions) do
        for _, reward in pairs(mission.rewards) do
            if reward.itemID and C_Item.IsAnimaItemByID(reward.itemID) and addon.db.profile.animaItemQualities[select(3, addon:GetItemInfo(reward.itemID))] then
                table.insert(missionLineup, mission)
            end
        end
    end
    
    local sort_func
    if hard then
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar > b.missionScalar
        end
    else
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar < b.missionScalar
        end
    end
    
    table.sort(missionLineup, sort_func)
    
    return missionLineup
end

function addon:GetPetCharmMissions(hard)
    return addon:GetAllMissionsMatchingFilter("pet-charms", hard)
end

function addon:GetAugmentRuneMissions(hard)
    return addon:GetAllMissionsMatchingFilter("augment-runes", hard)
end

function addon:GetReputationMissions(hard)
    local missions = C_Garrison.GetAvailableMissions(123)
    local missionLineup = {}
    
    for _, mission in pairs(missions) do
        local rewards = mission.rewards

        for _, reward in pairs(rewards) do
            if reward.currencyID and reputationCurrencyIDs[reward.currencyID] and addon.db.profile.reputations[reward.currencyID] then
                table.insert(missionLineup, mission)
            end
        end
    end
    
    local sort_func
    if hard then
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar > b.missionScalar
        end
    else
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar < b.missionScalar
        end
    end
    
    table.sort(missionLineup, sort_func)
    
    return missionLineup
end

function addon:GetCraftingCacheMissions(hard)
    local missions = C_Garrison.GetAvailableMissions(123)
    local missionLineup = {}
    
    for _, mission in pairs(missions) do
        for _, reward in pairs(mission.rewards) do
            if reward.itemID and craftingMaterialsCacheIDs[reward.itemID] and addon.db.profile.craftingCacheTypes[craftingMaterialsCacheIDs[reward.itemID]][craftingCacheQualities[reward.itemID]] then
                table.insert(missionLineup, mission)
            end
        end
    end
    
    local sort_func
    if hard then
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar > b.missionScalar
        end
    else
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar < b.missionScalar
        end
    end
    
    table.sort(missionLineup, sort_func)
    
    return missionLineup
end

function addon:GetRunecarverMissions(hard)
    local missions = C_Garrison.GetAvailableMissions(123)
    local missionLineup = {}
    
    for _, mission in pairs(missions) do
        local rewards = mission.rewards

        for _, reward in pairs(rewards) do
            if (reward.currencyID and runecarverCurrencyIDs[reward.currencyID] and addon.db.profile.runecarver[reward.currencyID]) or (reward.itemID and (reward.itemID == stygiaItemID) and addon.db.profile.runecarver[1767]) then
                table.insert(missionLineup, mission)
            end
        end
    end
    
    local sort_func
    if hard then
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar > b.missionScalar
        end
    else
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar < b.missionScalar
        end
    end
    
    table.sort(missionLineup, sort_func)
    
    return missionLineup
end

function addon:GetCampaignMissions(hard)
    local missions = C_Garrison.GetAvailableMissions(123)
    local missionLineup = {}
    
    for _, mission in pairs(missions) do
        local rewards = mission.rewards

        if (rewardFilter == "campaign") and reward.currencyID and (reward.currencyID == 1889) then
                include = true
            end

        for _, reward in pairs(rewards) do
            if reward.currencyID and (reward.currencyID == 1889) then
                local quantity = C_CurrencyInfo.GetCurrencyInfo(1889).quantity
                local include = false
                if quantity < 4 then
                    include = addon.db.profile.campaignCategories["1-4"]
                elseif quantity < 8 then
                    include = addon.db.profile.campaignCategories["5-8"]
                elseif quantity < 12 then
                    include = addon.db.profile.campaignCategories["9-12"]
                elseif quantity < 16 then
                    include = addon.db.profile.campaignCategories["13-16"]
                else
                    include = addon.db.profile.campaignCategories["17+"]
                end
                if include then
                    table.insert(missionLineup, mission)
                end
            end
        end
    end
    
    local sort_func
    if hard then
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar > b.missionScalar
        end
    else
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar < b.missionScalar
        end
    end
    
    table.sort(missionLineup, sort_func)
    
    return missionLineup
end

function addon:GetGearMissions(hard)
    local missions = C_Garrison.GetAvailableMissions(123)
    local missionLineup = {}
    
    local goldCategories = {
            ["1-19"] = {0.1, 20},
            ["20-29"] = {20, 30},
            ["30-39"] = {30, 40},
            ["40-49"] = {40, 50},
            ["50-59"] = {50, 60},
            ["60-69"] = {60, 70},
            ["70-79"] = {70, 80},
            ["80-89"] = {80, 90},
            ["90-99"] = {90, 100},
            ["100+"] = {100, 9999},
        }
    
    for _, mission in pairs(missions) do
        for _, reward in pairs(mission.rewards) do
            if (reward.itemID and IsEquippableItem(reward.itemID)) then
                local _, _, _, _, _, _, _, _, _, _, sellPrice = addon:GetItemInfo(reward.itemLink)
                if sellPrice then
                    for category, minMax in pairs(goldCategories) do
                        if ((sellPrice/10000) >= minMax[1]) and ((sellPrice/10000) < minMax[2]) then
                            if addon.db.profile.gearGoldCategories[category] then
                                table.insert(missionLineup, mission)
                            break
                           end 
                        end
                    end
                end
            end
        end
    end
    
    local sort_func
    if hard then
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar > b.missionScalar
        end
    else
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar < b.missionScalar
        end
    end
    
    table.sort(missionLineup, sort_func)
    
    return missionLineup
end

function addon:GetSanctumFeatureMissions(hard)
    local missions = C_Garrison.GetAvailableMissions(123)
    local missionLineup = {}
    
    for _, mission in pairs(missions) do
        for _, reward in pairs(mission.rewards) do
            if (reward.itemID and isSanctumFeatureItem(reward.itemID) and addon.db.profile.sanctumFeatureCategories[reward.itemID]) or (reward.currencyID and isSanctumFeatureCurrency(reward.currencyID) and addon.db.profile.sanctumFeatureCategories[reward.currencyID]) then
                table.insert(missionLineup, mission)
            end
        end
    end
    
    local sort_func
    if hard then
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar > b.missionScalar
        end
    else
        function sort_func(a, b)
            if a.missionScalar == b.missionScalar then
                return a.missionID < b.missionID
            end
            return a.missionScalar < b.missionScalar
        end
    end
    
    table.sort(missionLineup, sort_func)
    
    return missionLineup
    
end