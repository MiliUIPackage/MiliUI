local addonName = ...
local addon = _G[addonName]
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
local LibStub = addon.LibStub
local L = LibStub("AceLocale-3.0"):GetLocale("TLDRMissions")


function addon:RefreshProfile()
    local defaults = {
        profile = {
            selectedRewards = {
                ["*"] = nil,
            },
            excludedRewards = {
                ["*"] = nil,
            },
            hardestOrEasiest = "easy",
            fewestOrMost = "fewest",
            lowestOrHighest = "lowest",
            minimumTroops = 4,
            followerXPSpecialTreatment = false,
            followerXPSpecialTreatmentMinimum = 4,
            followerXPSpecialTreatmentAlgorithm = 1,
            workPerFrame = 10,
            reputations = CopyTable(addon.reputationCurrencyIDs),
            animaCosts = {
                ["*"] = {
                    ["*"] = true,
                },
            },
            craftingCacheTypes = {
                ["*"] = {
                    ["*"] = true,
                },
            },
            animaItemQualities = {
                ["*"] = true,
            },
            followerXPItemsItemQualities = {
                ["*"] = true,
            },
            runecarver = CopyTable(addon.runecarverCurrencyIDs),
            campaignCategories = {
                ["1-4"] = true,
                ["5-8"] = true,
                ["9-12"] = true,
                ["13-16"] = true,
                ["17+"] = true,
            },
            gearGoldCategories = {
                ["0-19"] = true,
                ["20-29"] = true,
                ["30-39"] = true,
                ["40-49"] = true,
                ["50-59"] = true,
                ["60-69"] = true,
                ["70-79"] = true,
                ["80-89"] = true,
                ["90-99"] = true,
                ["100+"] = true,
            },
            sanctumFeatureCategories = {
                ["*"] = true,
            },
            anythingForXP = false,
            anythingForXPCategories = {
                ["1-500"] = true,
                ["501-600"] = true,
                ["601-700"] = true,
                ["701-800"] = true,
                ["801-900"] = true,
                ["901-1000"] = true,
                ["1000+"] = true,
            },
            allowProcessingAnywhere = false,
            autoStart = false,
            estimateLimit = 30000,
            durationLower = 1,
            durationHigher = 24,
            autoShowUI = false,
            DEVTESTING = nil,
            LevelRestriction = 3,
            AnimaCostLimit = 300,
            sacrificeRemaining = false,
        }
    }
    
    if TLDRMissionsProfiles then
        for k, v in pairs(TLDRMissionsProfiles) do
            if (k ~= "profileKeys") and (k ~= "profiles") then
                TLDRMissionsProfiles[k] = nil
            end
        end
    end
    
    addon.db = LibStub("AceDB-3.0"):New("TLDRMissionsProfiles", defaults)

	addon.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
    addon.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	addon.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")

    local function setupAnimaCostDropDown(name)
        local options = {"10-24", "25-29", "30-49", "50-99", "100+"}

        LibDD:UIDropDownMenu_Initialize(_G["TLDRMissions"..name.."AnimaCostDropDown"], function(self, level, menuList)
            local info = LibDD:UIDropDownMenu_CreateInfo()        
            
            for _, option in ipairs(options) do
                info.text = option.." ".."靈魄"
                info.checked = addon.db.profile.animaCosts[name][option]
                info.isNotRadio = true
                info.keepShownOnClick = true
                info.arg1 = option
                info.func = function()
                    addon.db.profile.animaCosts[name][option] = not addon.db.profile.animaCosts[name][option]
                end
                LibDD:UIDropDownMenu_AddButton(info)
            end
        end)
    end
    
    setupAnimaCostDropDown("Gold")
    setupAnimaCostDropDown("Anima")
    setupAnimaCostDropDown("FollowerXPItems")
    setupAnimaCostDropDown("PetCharms")
    setupAnimaCostDropDown("AugmentRunes")
    setupAnimaCostDropDown("Reputation")
    setupAnimaCostDropDown("FollowerXP")
    setupAnimaCostDropDown("CraftingCache")
    setupAnimaCostDropDown("Runecarver")
    setupAnimaCostDropDown("Campaign")
    setupAnimaCostDropDown("Gear")
    setupAnimaCostDropDown("SanctumFeature")
    setupAnimaCostDropDown("AnythingForXP")

    LibDD:UIDropDownMenu_Initialize(TLDRMissionsFollowerXPSpecialTreatmentDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
    
        for i = 1, 5 do
            info.text = MINIMUM.." "..i.." "..GARRISON_FOLLOWERS
            info.checked = tonumber(addon.db.profile.followerXPSpecialTreatmentMinimum) == i
            info.arg1 = i
            info.func = function(self, arg1)
                addon.db.profile.followerXPSpecialTreatmentMinimum = arg1
            end
            LibDD:UIDropDownMenu_AddButton(info)
        end
    end)
    
    LibDD:UIDropDownMenu_Initialize(TLDRMissionsFollowerXPSpecialTreatmentAlgorithmDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        
        info.text = L["FollowerXPAlgorithm1Label"]
        info.checked = addon.db.profile.followerXPSpecialTreatmentAlgorithm == 1
        info.arg1 = 1
        info.func = function(self, arg1)
            addon.db.profile.followerXPSpecialTreatmentAlgorithm = arg1
        end
        LibDD:UIDropDownMenu_AddButton(info)
        info.text = L["FollowerXPAlgorithm2Label"]
        info.checked = addon.db.profile.followerXPSpecialTreatmentAlgorithm == 2
        info.arg1 = 2
        LibDD:UIDropDownMenu_AddButton(info)
        info.text = L["FollowerXPAlgorithm3Label"]
        info.checked = addon.db.profile.followerXPSpecialTreatmentAlgorithm == 3
        info.arg1 = 3
        LibDD:UIDropDownMenu_AddButton(info)
    end)

    LibDD:UIDropDownMenu_Initialize(TLDRMissionsReputationDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
    
        info.hasCross = false
        for k, v in pairs(addon.db.profile.excludedRewards) do
            if v == "reputation" then
                info.hasCross = true
            end
        end
    
        for currencyID, _ in pairs(addon.reputationCurrencyIDs) do
            info.text = C_CurrencyInfo.GetCurrencyInfo(currencyID).name
            info.checked = addon.db.profile.reputations[currencyID]
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.arg1 = currencyID
            info.func = addon.GUI.ReputationDropDown.OnSelect
            LibDD:UIDropDownMenu_AddButton(info)
        end
    end) 
    
    LibDD:UIDropDownMenu_Initialize(TLDRMissionsCraftingCacheDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        
        if level == 1 then
            for categoryIndex, name in pairs(addon.craftingCacheCategories) do
                info.text = name
                info.hasArrow = true
                info.notCheckable = true
                info.keepShownOnClick = true
                info.menuList = categoryIndex
                LibDD:UIDropDownMenu_AddButton(info)
            end
        elseif menuList then
            info.hasCross = false
            for k, v in pairs(addon.db.profile.excludedRewards) do
                if v == "crafting-cache" then
                    info.hasCross = true
                end
            end
            info.text = "|cFFFFFFFF"..ITEM_QUALITY1_DESC.."|r"
            info.checked = addon.db.profile.craftingCacheTypes[menuList][1]
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.arg1 = menuList
            info.arg2 = 1
            info.func = addon.GUI.CraftingCacheDropDown.OnSelect
            LibDD:UIDropDownMenu_AddButton(info, level)
            info.text = "|cFF00FF00"..ITEM_QUALITY2_DESC.."|r"
            info.checked = addon.db.profile.craftingCacheTypes[menuList][2]
            info.arg1 = menuList
            info.arg2 = 2
            info.func = addon.GUI.CraftingCacheDropDown.OnSelect
            LibDD:UIDropDownMenu_AddButton(info, level)
            info.text = "|cFF0000FF"..ITEM_QUALITY3_DESC.."|r"
            info.checked = addon.db.profile.craftingCacheTypes[menuList][3]
            info.arg1 = menuList
            info.arg2 = 3
            info.func = addon.GUI.CraftingCacheDropDown.OnSelect
            LibDD:UIDropDownMenu_AddButton(info, level)
        end
    end)

    LibDD:UIDropDownMenu_Initialize(TLDRMissionsAnimaDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        
        info.isNotRadio = true
        info.keepShownOnClick = true
        info.func = addon.GUI.AnimaDropDown.OnSelect
        
        info.hasCross = false
        for k, v in pairs(addon.db.profile.excludedRewards) do
            if v == "anima" then
                info.hasCross = true
            end
        end
        
        info.text = "|cFF00FF00"..ITEM_QUALITY2_DESC.."|r"
        info.checked = addon.db.profile.animaItemQualities[2]
        info.arg1 = 2
        LibDD:UIDropDownMenu_AddButton(info, level)
        
        info.text = "|cFF0000FF"..ITEM_QUALITY3_DESC.."|r"
        info.checked = addon.db.profile.animaItemQualities[3]
        info.arg1 = 3
        LibDD:UIDropDownMenu_AddButton(info, level)
        
        info.text = "|cFFA020F0"..ITEM_QUALITY4_DESC.."|r"
        info.checked = addon.db.profile.animaItemQualities[4]
        info.arg1 = 4
        LibDD:UIDropDownMenu_AddButton(info, level)
    end)
    
    LibDD:UIDropDownMenu_Initialize(TLDRMissionsFollowerXPItemsDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        
        info.isNotRadio = true
        info.keepShownOnClick = true
        info.func = addon.GUI.FollowerXPItemsDropDown.OnSelect
        
        info.hasCross = false
        for k, v in pairs(addon.db.profile.excludedRewards) do
            if v == "followerxp-items" then
                info.hasCross = true
            end
        end
        
        info.text = "|cFF00FF00"..ITEM_QUALITY2_DESC.."|r"
        info.checked = addon.db.profile.followerXPItemsItemQualities[2]
        info.arg1 = 2
        LibDD:UIDropDownMenu_AddButton(info, level)
        
        info.text = "|cFF0000FF"..ITEM_QUALITY3_DESC.."|r"
        info.checked = addon.db.profile.followerXPItemsItemQualities[3]
        info.arg1 = 3
        LibDD:UIDropDownMenu_AddButton(info, level)
        
        info.text = "|cFFA020F0"..ITEM_QUALITY4_DESC.."|r"
        info.checked = addon.db.profile.followerXPItemsItemQualities[4]
        info.arg1 = 4
        LibDD:UIDropDownMenu_AddButton(info, level)
    end)
    
    LibDD:UIDropDownMenu_Initialize(TLDRMissionsRunecarverDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        
        info.isNotRadio = true
        info.keepShownOnClick = true
        info.func = addon.GUI.RunecarverDropDown.OnSelect
        
        info.hasCross = false
        for k, v in pairs(addon.db.profile.excludedRewards) do
            if v == "runecarver" then
                info.hasCross = true
            end
        end
        
        for currencyID, name in pairs(addon.runecarverCurrencyIDs) do
            info.text = C_CurrencyInfo.GetCurrencyInfo(currencyID).name
            info.checked = addon.db.profile.runecarver[currencyID]
            info.arg1 = currencyID
            LibDD:UIDropDownMenu_AddButton(info)
        end
    end)
    
    local campaignCategories = {
        "1-4",
        "5-8",
        "9-12",
        "13-16",
        "17+",
    }
    
    LibDD:UIDropDownMenu_Initialize(TLDRMissionsCampaignDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        info.isNotRadio = true
        info.keepShownOnClick = true
        info.func = addon.GUI.CampaignDropDown.OnSelect
        info.tooltipTitle = ""
        info.tooltipOnButton = true
        info.tooltipText = L["CampaignDropDownTooltip"]
        
        info.hasCross = false
        for k, v in pairs(addon.db.profile.excludedRewards) do
            if v == "campaign" then
                info.hasCross = true
            end
        end
        
        local name = C_CurrencyInfo.GetCurrencyInfo(1889)
        if name then
            name = name.name
        else
            name = ""
        end
        for _, campaignCategory in ipairs(campaignCategories) do
            info.text = name.." "..campaignCategory
            info.checked = addon.db.profile.campaignCategories[campaignCategory]
            info.arg1 = campaignCategory
            LibDD:UIDropDownMenu_AddButton(info)
        end
    end)

    local goldCategories = {
        "0-19",
        "20-29",
        "30-39",
        "40-49",
        "50-59",
        "60-69",
        "70-79",
        "80-89",
        "90-99",
        "100+",
    }
    
    LibDD:UIDropDownMenu_Initialize(TLDRMissionsGearDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        info.isNotRadio = true
        info.keepShownOnClick = true
        info.func = addon.GUI.GearDropDown.OnSelect
        
        info.hasCross = false
        for k, v in pairs(addon.db.profile.excludedRewards) do
            if v == "gear" then
                info.hasCross = true
            end
        end
        
        for _, goldCategory in ipairs(goldCategories) do
            info.text = goldCategory.." "..BATTLE_PET_SOURCE_3.." "..BONUS_ROLL_REWARD_MONEY -- hope that doesn't get lost in translation :|
            info.checked = addon.db.profile.gearGoldCategories[goldCategory]
            info.arg1 = goldCategory
            LibDD:UIDropDownMenu_AddButton(info)
        end
    end)
    
    local xpCategories = {
        "1-500",
        "501-600",
        "601-700",
        "701-800",
        "801-900",
        "901-1000",
        "1000+",
    }
    
    LibDD:UIDropDownMenu_Initialize(TLDRMissionsAnythingForXPDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        info.isNotRadio = true
        info.keepShownOnClick = true
        info.func = addon.GUI.AnythingForXPDropDown.OnSelect
        
        for _, xpCategory in ipairs(xpCategories) do
            info.text = xpCategory.." "..COMBAT_XP_GAIN
            info.checked = addon.db.profile.anythingForXPCategories[xpCategory]
            info.arg1 = xpCategory
            LibDD:UIDropDownMenu_AddButton(info)
        end
    end)
    
    local function isAnySanctumFeatureCategoryChecked(categoryName)
        for itemID in pairs(addon.sanctumFeatureItems[categoryName]) do
            if addon.db.profile.sanctumFeatureCategories[itemID] then
                return true
            end
        end
        for currencyID in pairs(addon.sanctumFeatureCurrencies[categoryName]) do
            if addon.db.profile.sanctumFeatureCategories[currencyID] then
                return true
            end
        end
        return false
    end
    
    local itemNameCache = {}
    LibDD:UIDropDownMenu_Initialize(TLDRMissionsSanctumFeatureDropDown, function(self, level, menuList)
        local info = LibDD:UIDropDownMenu_CreateInfo()
        info.isNotRadio = true
        info.func = addon.GUI.SanctumFeatureDropDown.OnSelect
        info.keepShownOnClick = true
        
        info.hasCross = false
        for k, v in pairs(addon.db.profile.excludedRewards) do
            if v == "sanctum" then
                info.hasCross = true
            end
        end
        
        if level == 1 then
            for categoryName, category in pairs(addon.sanctumFeatureItems) do
                info.text = categoryName
                info.hasArrow = true
                info.arg1 = categoryName
                info.menuList = categoryName
                info.checked = isAnySanctumFeatureCategoryChecked(categoryName)
                LibDD:UIDropDownMenu_AddButton(info)
            end
        elseif menuList then
            for itemID in pairs(addon.sanctumFeatureItems[menuList]) do
                local itemName = itemNameCache[itemID] or "Loading..."
                info.text = itemName
                info.checked = addon.db.profile.sanctumFeatureCategories[itemID]
                info.arg1 = itemID
                LibDD:UIDropDownMenu_AddButton(info, level)
            end
            
            for currencyID in pairs(addon.sanctumFeatureCurrencies[menuList]) do
                info.text = C_CurrencyInfo.GetCurrencyInfo(currencyID).name or "Loading..."
                info.checked = addon.db.profile.sanctumFeatureCategories[currencyID]
                info.arg1 = currencyID
                LibDD:UIDropDownMenu_AddButton(info, level)
            end
        end
    end)
    
    --preload the items
    for categoryName, category in pairs(addon.sanctumFeatureItems) do
        for itemID in pairs(category) do
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function()
            	itemNameCache[itemID] = item:GetItemName()
            end)
        end
    end
    
    if not TLDRMissionsLogging then
        TLDRMissionsLogging = {}
    end
    
    if not TLDRMissionsCache then
        TLDRMissionsCache = {}
    end
    
    -- wipe obsolete data from previous versions of the addon - cannot be relied upon anymore
    for addonVersion, _ in pairs(TLDRMissionsCache) do
        if addonVersion ~= GetAddOnMetadata(addonName, "Version") then
            TLDRMissionsCache[addonVersion] = nil
        end
    end
    
    if not TLDRMissionsCache[GetAddOnMetadata(addonName, "Version")] then
        TLDRMissionsCache[GetAddOnMetadata(addonName, "Version")] = {}
    end
    
    local options = {type = "group", args = {}}
    LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(options, addonName)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options, {"tldrmissions"})
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, nil, nil, "profiles")
    
    if addon.db.profile.moreOrLessTroops then
        if addon.db.profile.moreOrLessTroops == "less" then
            addon.db.profile.minimumTroops = 0
            addon.db.profile.moreOrLessTroops = nil
        end
    end
    
    addon:ProfileChanged()
end
    
    
function addon:ProfileChanged()
    addon.GUI.CalculateButton:SetEnabled(false)
    for i = 1, 12 do
        if addon.db.profile.selectedRewards[i] then
            addon.GUI.CalculateButton:SetEnabled(true)
            break
        end
    end
    if addon.db.profile.anythingForXP or addon.db.profile.sacrificeRemaining then
        addon.GUI.CalculateButton:SetEnabled(true)
    end
    addon.GUI.AnythingForXPCheckButton:SetChecked(addon.db.profile.anythingForXP)    
    addon.GUI.SacrificeCheckButton:SetChecked(addon.db.profile.sacrificeRemaining)
    
    addon.GUI.HardestRadioButton:SetChecked(addon.db.profile.hardestOrEasiest == "hard")
    addon.GUI.EasiestRadioButton:SetChecked(addon.db.profile.hardestOrEasiest ~= "hard")
    
    addon.GUI.FewestRadioButton:SetChecked(addon.db.profile.fewestOrMost ~= "most")
    addon.GUI.MostRadioButton:SetChecked(addon.db.profile.fewestOrMost == "most")
    
    addon.GUI.LowestRadioButton:SetChecked(addon.db.profile.lowestOrHighest ~= "highest")
    addon.GUI.HighestRadioButton:SetChecked(addon.db.profile.lowestOrHighest == "highest")
    
    addon.GUI.MinimumTroopsSlider:SetValue(addon.db.profile.minimumTroops)
    addon.GUI.LowerBoundLevelRestrictionSlider:SetValue(addon.db.profile.LevelRestriction)
    addon.GUI.AnimaCostLimitSlider:SetValue(addon.db.profile.AnimaCostLimit)
    addon.GUI.FollowerXPSpecialTreatmentCheckButton:SetChecked(addon.db.profile.followerXPSpecialTreatment)  
    addon.GUI.SimulationsPerFrameSlider:SetValue(addon.db.profile.workPerFrame)    
    addon.GUI.AutoShowButton:SetChecked(addon.db.profile.autoShowUI)
    addon.GUI.MaxSimulationsEditBox:SetText(addon.db.profile.estimateLimit)
    
    addon.GUI.AllowProcessingAnywhereButton:SetChecked(addon.db.profile.allowProcessingAnywhere)
    
    addon.GUI.AutoStartButton:SetChecked(addon.db.profile.autoStart)
    
    TLDRMissionsFrameDurationLowerSliderText:SetText(L["DurationTimeSelectedLabel"]:format(addon.db.profile.durationLower, addon.db.profile.durationHigher))
    TLDRMissionsFrameDurationLowerSlider:SetValue(addon.db.profile.durationLower)
    TLDRMissionsFrameDurationHigherSlider:SetValue(addon.db.profile.durationHigher)
    
    addon:updateRewards()
end