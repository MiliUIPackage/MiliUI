local addonName = ...
local addon = _G[addonName]
local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
local LibStub = addon.LibStub
local L = LibStub("AceLocale-3.0"):GetLocale("TLDRMissions")
local AceEvent = LibStub("AceAddon-3.0"):NewAddon("TLDRMissions-AceEvent", "AceEvent-3.0")

local gui = addon.GUI

local nextMission
local hasNextMission
local missionCounter
local missionCounterUpper
local calculateNextMission
local setNextMissionText

local pauseReports

local missionWaitingUserAcceptance
local calculatedMissionBacklog = {}

local alreadyUsedFollowers

local numSent
local numSkipped
local numFailed

function addon:updateRewards()
    gui.GoldPriorityLabel:SetText()
    gui.AnimaPriorityLabel:SetText()
    gui.FollowerXPItemsPriorityLabel:SetText()
    gui.PetCharmsPriorityLabel:SetText()
    gui.AugmentRunesPriorityLabel:SetText()
    gui.ReputationPriorityLabel:SetText()
    gui.FollowerXPPriorityLabel:SetText()
    gui.RunecarverPriorityLabel:SetText()
    gui.CraftingCachePriorityLabel:SetText()
    gui.GearPriorityLabel:SetText()
    gui.CampaignPriorityLabel:SetText()
    gui.SanctumFeaturePriorityLabel:SetText()
    
    gui.GoldCheckButton.ExclusionLabel:Hide()
    gui.AnimaCheckButton.ExclusionLabel:Hide()
    gui.FollowerXPItemsCheckButton.ExclusionLabel:Hide()
    gui.PetCharmsCheckButton.ExclusionLabel:Hide()
    gui.AugmentRunesCheckButton.ExclusionLabel:Hide()
    gui.ReputationCheckButton.ExclusionLabel:Hide()
    gui.FollowerXPCheckButton.ExclusionLabel:Hide()
    gui.CraftingCacheCheckButton.ExclusionLabel:Hide()
    gui.RunecarverCheckButton.ExclusionLabel:Hide()
    gui.CampaignCheckButton.ExclusionLabel:Hide()
    gui.GearCheckButton.ExclusionLabel:Hide()
    gui.SanctumFeatureCheckButton.ExclusionLabel:Hide()
    
    gui.GoldCheckButton:SetChecked(false)
    gui.AnimaCheckButton:SetChecked(false)
    gui.FollowerXPItemsCheckButton:SetChecked(false)
    gui.PetCharmsCheckButton:SetChecked(false)
    gui.AugmentRunesCheckButton:SetChecked(false)
    gui.ReputationCheckButton:SetChecked(false)
    gui.FollowerXPCheckButton:SetChecked(false)
    gui.CraftingCacheCheckButton:SetChecked(false)
    gui.RunecarverCheckButton:SetChecked(false)
    gui.CampaignCheckButton:SetChecked(false)
    gui.GearCheckButton:SetChecked(false)
    gui.SanctumFeatureCheckButton:SetChecked(false)
    
    local wasSomethingChecked = false
    for i = 1, 12 do
        if addon.db.profile.selectedRewards[i] == "gold" then
            gui.GoldCheckButton:SetChecked(true)
            gui.GoldPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "anima" then
            gui.AnimaCheckButton:SetChecked(true)
            gui.AnimaPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "followerxp-items" then
            gui.FollowerXPItemsCheckButton:SetChecked(true)
            gui.FollowerXPItemsPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "pet-charms" then
            gui.PetCharmsCheckButton:SetChecked(true)
            gui.PetCharmsPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "augment-runes" then
            gui.AugmentRunesCheckButton:SetChecked(true)
            gui.AugmentRunesPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "reputation" then
            gui.ReputationCheckButton:SetChecked(true)
            gui.ReputationPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "followerxp" then
            gui.FollowerXPCheckButton:SetChecked(true)
            gui.FollowerXPPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "crafting-cache" then
            gui.CraftingCacheCheckButton:SetChecked(true)
            gui.CraftingCachePriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "runecarver" then
            gui.RunecarverCheckButton:SetChecked(true)
            gui.RunecarverPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "campaign" then
            gui.CampaignCheckButton:SetChecked(true)
            gui.CampaignPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "gear" then
            gui.GearCheckButton:SetChecked(true)
            gui.GearPriorityLabel:SetText(i)
            wasSomethingChecked = true
        elseif addon.db.profile.selectedRewards[i] == "sanctum" then
            gui.SanctumFeatureCheckButton:SetChecked(true)
            gui.SanctumFeaturePriorityLabel:SetText(i)
            wasSomethingChecked = true
        end
    end
    
    for k, v in pairs(addon.db.profile.excludedRewards) do
        if v == "gold" then
            gui.GoldCheckButton.ExclusionLabel:Show()
        elseif v == "anima" then
            gui.AnimaCheckButton.ExclusionLabel:Show()
        elseif v == "followerxp-items" then
            gui.FollowerXPItemsCheckButton.ExclusionLabel:Show()
        elseif v == "pet-charms" then
            gui.PetCharmsCheckButton.ExclusionLabel:Show()
        elseif v == "augment-runes" then
            gui.AugmentRunesCheckButton.ExclusionLabel:Show()
        elseif v == "reputation" then
            gui.ReputationCheckButton.ExclusionLabel:Show()
        elseif v == "followerxp" then
            gui.FollowerXPCheckButton.ExclusionLabel:Show()
        elseif v == "crafting-cache" then
            gui.CraftingCacheCheckButton.ExclusionLabel:Show()
        elseif v == "runecarver" then
            gui.RunecarverCheckButton.ExclusionLabel:Show()
        elseif v == "campaign" then
            gui.CampaignCheckButton.ExclusionLabel:Show()
        elseif v == "gear" then
            gui.GearCheckButton.ExclusionLabel:Show()
        elseif v == "sanctum" then
            gui.SanctumFeatureCheckButton.ExclusionLabel:Show()
        end
    end
    
    if addon.db.profile.anythingForXP or addon.db.profile.sacrificeRemaining then
        wasSomethingChecked = true
    end
    
    if wasSomethingChecked then
        gui.CalculateButton:SetEnabled(true)
    else
        gui.CalculateButton:SetEnabled(false)
    end
end

local checkButtonHandler = function(self, name)
    if self:GetChecked() then
        for k, v in pairs(addon.db.profile.excludedRewards) do
            if v == name then
                addon.db.profile.excludedRewards[k] = nil
                self:SetChecked(false)
                addon:updateRewards()
                return
            end
        end
        
        for i = 1, 12 do
            if not addon.db.profile.selectedRewards[i] then
                addon.db.profile.selectedRewards[i] = name
                addon:updateRewards()
                return
            end
        end
    else
        for i = 1, 12 do
            if addon.db.profile.selectedRewards[i] == name then
                for j = i, 12 do
                    if (j+1) > 12 then
                        addon.db.profile.selectedRewards[j] = nil
                        table.insert(addon.db.profile.excludedRewards, name)
                    else
                        addon.db.profile.selectedRewards[j] = addon.db.profile.selectedRewards[j+1]
                    end
                end
                addon:updateRewards()
                return
            end
        end
    end
    addon:updateRewards()
end

gui.GoldCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "gold") end)
gui.AnimaCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "anima") end)
gui.FollowerXPItemsCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "followerxp-items") end)
gui.PetCharmsCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "pet-charms") end)
gui.AugmentRunesCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "augment-runes") end)
gui.ReputationCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "reputation") end)
gui.FollowerXPCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "followerxp") end)
gui.CraftingCacheCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "crafting-cache") end)
gui.RunecarverCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "runecarver") end)
gui.CampaignCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "campaign") end)
gui.GearCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "gear") end)
gui.SanctumFeatureCheckButton:HookScript("OnClick", function(self) checkButtonHandler(self, "sanctum") end)

gui.AnythingForXPCheckButton:HookScript("OnClick", function(self)
    addon.db.profile.anythingForXP = self:GetChecked()
    addon:updateRewards()
end)

gui.SacrificeCheckButton:HookScript("OnClick", function(self)
    addon.db.profile.sacrificeRemaining = self:GetChecked()
    addon:updateRewards()
end)

local function clearReportText()
    gui.FailedCalcLabel:SetText()
    gui.NextMissionLabel:SetText()
    gui.shortcutButton:SetText(COVENANT_MISSIONS_START_ADVENTURE)
    for i = 1, 5 do
        gui["NextFollower"..i.."Label"]:SetText()
    end
    gui.RewardsDetailLabel:SetText()
    gui.LowTimeWarningLabel:SetText()
end

local function updateRewardText(mission)
    local text = ""
    if mission.sacrifice then
        text = L["SacrificeMissionReport"]:format(mission.xp)
    else
        local rewards = C_Garrison.GetMissionRewardInfo(mission.missionID)
        if rewards then
            for _, reward in pairs(rewards) do
                if reward.currencyID and (reward.currencyID == 0) then
                    text = text..GetCoinTextureString(reward.quantity).."; "
                elseif reward.followerXP then
                    text = text..reward.followerXP.." "..L["BonusFollowerXP"].."; "
                elseif reward.itemID then
                    local _, itemLink = addon:GetItemInfo(reward.itemID)
                    itemLink = itemLink or "[item: "..reward.itemID.."]"
                    text = text..itemLink.." x"..reward.quantity.."; "
                elseif reward.currencyID and (reward.currencyID ~= 0) then
                    local info = C_CurrencyInfo.GetCurrencyInfo(reward.currencyID)
                    text = text..info.name.." x"..reward.quantity.."; "
                end
            end
        end
    end
    gui.RewardsDetailLabel:SetText(text)
end

local function processResults(results, dontClear)
    if not results.counter then results.counter = missionCounter end
    
    if missionWaitingUserAcceptance then
        if (results.defeats == 0) and (results.victories > 0) then
            local problem -- something further down the chain is feeding multiple successes into the queue when it shouldn't. probably a caching problem. this is the workaround in the meantime
            if missionWaitingUserAcceptance and (missionWaitingUserAcceptance.missionID == results.missionID) then
                problem = true
            end
            
            for _, r in pairs(calculatedMissionBacklog) do
                if r.missionID == results.missionID then
                    problem = true
                    break
                end
            end
            
            if not problem then
                table.insert(calculatedMissionBacklog, results)
                for i = 1, 5 do
                    if results.combination[i] then
                        alreadyUsedFollowers[results.combination[i]] = true
                    end
                end
            --else
                --if table.getn(calculatedMissionBacklog) > 0 then
                --    processResults(table.remove(calculatedMissionBacklog, 1), true)
                --    return
                --end
            end
        end
        if addon:isCurrentWorkBatchEmpty() then
            calculateNextMission()
        end
        return
    end
    
    missionWaitingUserAcceptance = results
    
    clearReportText()
    
    if (results.defeats == 0) and (results.victories > 0) then
        if not dontClear then addon:clearWork() end
        local _, _, _, _, duration = C_Garrison.GetMissionTimes(results.missionID)
        if not duration then duration = 3600 end
        duration = duration/3600
        gui.shortcutButton:SetText("("..(results.counter or missionCounter).."/"..missionCounterUpper..")")
        gui.NextMissionLabel:SetText(string.format(L["MissionCounter"], results.counter or missionCounter, missionCounterUpper, C_Garrison.GetMissionName(results.missionID).." ("..string.format(COOLDOWN_DURATION_HOURS, math.floor(duration/0.5)*0.5)..")"))
        for i = 1, 5 do
            if results.combination[i] then
                alreadyUsedFollowers[results.combination[i]] = true
                gui["NextFollower"..i.."Label"]:SetText(C_Garrison.GetFollowerName(results.combination[i]))
            else
                gui["NextFollower"..i.."Label"]:SetText(L["Empty"])
            end
        end
        
        updateRewardText(results)
        
        local numAutoTroops = 0
        local autoTroops = C_Garrison.GetAutoTroops(123)
        if autoTroops then
            for _, f in pairs(results.combination) do
                for _, info in pairs(autoTroops) do
                    if f == info.followerID then
                        numAutoTroops = numAutoTroops + 1
                    end
                end
            end
        end
        
        gui.FailedCalcLabel:SetText()
        gui.CostLabel:Show()
        gui.CostResultLabel:SetText((C_Garrison.GetMissionCost(missionWaitingUserAcceptance.missionID) + numAutoTroops).." ".."靈魄")
        local timeRemaining = (C_Garrison.GetBasicMissionInfo(results.missionID).offerEndTime or (GetTime() + 601)) - GetTime()
        if timeRemaining < 600 then
            gui.LowTimeWarningLabel:SetText(string.format(L["LowTimeWarning"], math.floor(timeRemaining/60), math.floor(mod(timeRemaining, 60))))
        end
        
        if addon.db.profile.autoStart then
            gui.StartMissionButton:SetEnabled(true)
            gui.StartMissionButton:Click()
        else
            gui.StartMissionButton:SetEnabled(true)
            gui.SkipMissionButton:SetEnabled(true)
            if addon:isCurrentWorkBatchEmpty() then
                calculateNextMission()
            end
        end
    else
        numFailed = numFailed + 1
        missionWaitingUserAcceptance = nil
        if addon:isCurrentWorkBatchEmpty() then
            clearReportText()
            if hasNextMission() then
                calculateNextMission()
            else
                gui.CalculateButton:SetEnabled(true)
                gui.AbortButton:SetEnabled(false)
                gui.SkipCalculationButton:SetEnabled(false)
                if (numSkipped > 0) or (numSent > 0) then
                    local numFollowersAvailable = 0
                    for _, follower in pairs(C_Garrison.GetFollowers(123)) do
                        if (not follower.status) and (follower.isCollected) then
                            numFollowersAvailable = numFollowersAvailable + 1
                        end
                    end
                    gui.shortcutButton:SetText(DONE.."!")
                    gui.FailedCalcLabel:SetText(L["MissionsSentPartial"]:format(numSent, numSkipped, numFailed, numFollowersAvailable))
                    AceEvent:SendMessage("TLDRMISSIONS_SENT_PARTIAL", numSent, numSkipped, numFailed, numFollowersAvailable)
                    if WeakAuras then
                        WeakAuras.ScanEvents("TLDRMISSIONS_SENT_PARTIAL", numSent, numSkipped, numFailed, numFollowersAvailable)
                    end
                else
                    gui.shortcutButton:SetText(FAILED)
                    gui.FailedCalcLabel:SetText(L["AllSimsFailedError"])
                    AceEvent:SendMessage("TLDRMISSIONS_SENT_FAILURE")
                    if WeakAuras then
                        WeakAuras.ScanEvents("TLDRMISSIONS_SENT_FAILURE")
                    end
                end
            end
            
            if table.getn(calculatedMissionBacklog) > 0 then
                processResults(table.remove(calculatedMissionBacklog, 1), true)
            end
        end
    end
end

local lowerEstimate = 0
local function incrementEstimate()
    gui.EstimateLabel:SetText(L["Simulations"]..": "..lowerEstimate)
    lowerEstimate = lowerEstimate + 1
    if lowerEstimate > addon.db.profile.estimateLimit then
        gui.SkipCalculationButton:Click()
    end
    if addon.db.profile.TEELOTESTING then
        for i = 1, 5 do
            if addon.currentFollowersBeingTested[i] then
                gui["EstimateFollower"..i.."Label"]:SetText(C_Garrison.GetFollowerName(addon.currentFollowersBeingTested[i]))
            else
                gui["EstimateFollower"..i.."Label"]:SetText("")
            end
        end
    end
end

function addon:getSimulationEstimate()
    return lowerEstimate
end

local sacrificeStarted
local function startSacrifice()
    if sacrificeStarted then return end
    sacrificeStarted = true
    
    local missions = C_Garrison.GetAvailableMissions(123)
    local excludedMissions = {}
    
    for _, category in pairs(addon.db.profile.excludedRewards) do
        local missions = {}
        if category == "gold" then
            missions = addon:GetGoldMissions()
        elseif category == "followerxp" then
            missions = addon:GetFollowerXPMissions()
        elseif category == "followerxp-items" then
            missions = addon:GetFollowerXPItemMissions()
        elseif category == "anima" then
            missions = addon:GetAnimaMissions()
        elseif category == "pet-charms" then
            missions = addon:GetPetCharmMissions()
        elseif category == "augment-runes" then
            missions = addon:GetAugmentRuneMissions()
        elseif category == "reputation" then
            missions = addon:GetReputationMissions()
        elseif category == "crafting-cache" then
            missions = addon:GetCraftingCacheMissions()
        elseif category == "runecarver" then
            missions = addon:GetRunecarverMissions()    
        elseif category == "campaign" then
            missions = addon:GetCampaignMissions()
        elseif category == "gear" then
            missions = addon:GetGearMissions()
        elseif category == "sanctum" then
            missions = addon:GetSanctumFeatureMissions()
        end
        
        for _, mission in pairs(missions) do
            excludedMissions[mission.missionID] = true
        end
    end
    
    local m = {}
    for _, mission in pairs(missions) do
        local animaCost = C_Garrison.GetMissionCost(mission.missionID)
        if animaCost and (gui.AnimaCostLimitSlider:GetValue() >= animaCost) then
            local _, _, _, _, duration = C_Garrison.GetMissionTimes(mission.missionID)
            duration = duration/3600
            local d = addon.db.profile.durationLower
            if d <= 1 then d = 0 end
            if (duration >= d) and (duration <= addon.db.profile.durationHigher) and (not excludedMissions[mission.missionID]) then
                table.insert(m, mission)
            end
        end
    end
    
    missions = m
    
    table.sort(missions, function(a, b)
        if a.xp == b.xp then
            if a.durationSeconds == b.durationSeconds then
                return a.missionID < b.missionID
            end
            return a.durationSeconds < b.durationSeconds
        end
        return a.xp > b.xp
    end)
    
    local followers = C_Garrison.GetFollowers(123)
    local again
    repeat
        again = false
        for k, v in pairs(followers) do
            if v.status or alreadyUsedFollowers[v.followerID] or (v.level >= 60) then
                table.remove(followers, k)
                again = true
                break
            end
        end
    until not again
            
    local numFollowers = #followers
    if numFollowers == 0 then return end
    local combinations = {}
    while numFollowers > 0 do
        table.insert(combinations, {followers[numFollowers], followers[numFollowers-1], followers[numFollowers-2], followers[numFollowers-3], followers[numFollowers-4]})
        numFollowers = numFollowers - 5
    end
    
    for _, mission in ipairs(missions) do
        if #combinations < 1 then return end
        
        local combination = table.remove(combinations, 1)
        local c = {}
        for _, follower in pairs(combination) do
            table.insert(c, follower.followerID)
        end
        processResults({sacrifice = true, defeats = 0, victories = 1, incompletes = 0, ["combination"] = c, missionID = mission.missionID, xp = mission.xp})
    end
end

gui.CalculateButton:SetScript("OnClick", function (self, button)
    sacrificeStarted = false
    
    numSent = 0
    numSkipped = 0
    numFailed = 0
    
    addon:clearWork()
	self:SetEnabled(false)
    gui.AbortButton:SetEnabled(true)
    gui.SkipCalculationButton:SetEnabled(true)
    
    clearReportText()
    
    alreadyUsedFollowers = {}
    
    -- get missions matching conditions set
    local missions = {}
    local excludedMissions = {}
    
    for _, category in pairs(addon.db.profile.excludedRewards) do
        local missions = {}
        if category == "gold" then
            missions = addon:GetGoldMissions()
        elseif category == "followerxp" then
            missions = addon:GetFollowerXPMissions()
        elseif category == "followerxp-items" then
            missions = addon:GetFollowerXPItemMissions()
        elseif category == "anima" then
            missions = addon:GetAnimaMissions()
        elseif category == "pet-charms" then
            missions = addon:GetPetCharmMissions()
        elseif category == "augment-runes" then
            missions = addon:GetAugmentRuneMissions()
        elseif category == "reputation" then
            missions = addon:GetReputationMissions()
        elseif category == "crafting-cache" then
            missions = addon:GetCraftingCacheMissions()
        elseif category == "runecarver" then
            missions = addon:GetRunecarverMissions()    
        elseif category == "campaign" then
            missions = addon:GetCampaignMissions()
        elseif category == "gear" then
            missions = addon:GetGearMissions()
        elseif category == "sanctum" then
            missions = addon:GetSanctumFeatureMissions()
        end
        
        for _, mission in pairs(missions) do
            excludedMissions[mission.missionID] = true
        end
    end
    
    for i = 1, 12 do
        local newMissions = {}
        
        local acCategory -- i should really make the selected reward names the same as the button names
        if addon.db.profile.selectedRewards[i] == "gold" then
            newMissions = addon:GetGoldMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "Gold"
        elseif addon.db.profile.selectedRewards[i] == "followerxp" then
            newMissions = addon:GetFollowerXPMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "FollowerXP"
        elseif addon.db.profile.selectedRewards[i] == "followerxp-items" then
            newMissions = addon:GetFollowerXPItemMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "FollowerXPItems"
        elseif addon.db.profile.selectedRewards[i] == "anima" then
            newMissions = addon:GetAnimaMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "Anima"
        elseif addon.db.profile.selectedRewards[i] == "pet-charms" then
            newMissions = addon:GetPetCharmMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "PetCharms"
        elseif addon.db.profile.selectedRewards[i] == "augment-runes" then
            newMissions = addon:GetAugmentRuneMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "AugmentRunes"
        elseif addon.db.profile.selectedRewards[i] == "reputation" then
            newMissions = addon:GetReputationMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "Reputation"
        elseif addon.db.profile.selectedRewards[i] == "crafting-cache" then
            newMissions = addon:GetCraftingCacheMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "CraftingCache"
        elseif addon.db.profile.selectedRewards[i] == "runecarver" then
            newMissions = addon:GetRunecarverMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "Runecarver"    
        elseif addon.db.profile.selectedRewards[i] == "campaign" then
            newMissions = addon:GetCampaignMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "Campaign"
        elseif addon.db.profile.selectedRewards[i] == "gear" then
            newMissions = addon:GetGearMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "Gear"
        elseif addon.db.profile.selectedRewards[i] == "sanctum" then
            newMissions = addon:GetSanctumFeatureMissions(addon.db.profile.hardestOrEasiest == "hard")
            acCategory = "SanctumFeature"
        end
        
        for _, mission in ipairs(newMissions) do
            local exists = false
            for _, mission2 in pairs(missions) do
                if mission.missionID == mission2.missionID then
                    exists = true
                    break
                end
            end
            if (not exists) and (not excludedMissions[mission.missionID]) then
                local animaCost = C_Garrison.GetMissionCost(mission.missionID)
                if not animaCost then animaCost = 1 end
                if      ( gui.AnimaCostLimitSlider:GetValue() >= animaCost ) and
                        (
                          ( (animaCost < 25) and addon.db.profile.animaCosts[acCategory]["10-24"] ) or
                          ( (animaCost < 30) and (animaCost > 24) and addon.db.profile.animaCosts[acCategory]["25-29"] ) or
                          ( (animaCost < 50) and (animaCost > 29) and addon.db.profile.animaCosts[acCategory]["30-49"] ) or
                          ( (animaCost < 100) and (animaCost > 49) and addon.db.profile.animaCosts[acCategory]["50-99"] ) or 
                          ( (animaCost > 99) and addon.db.profile.animaCosts[acCategory]["100+"] )
                        ) then
                    local _, _, _, _, duration = C_Garrison.GetMissionTimes(mission.missionID)
                    duration = duration/3600
                    
                    -- support 1 minute missions under a minimum of 1 hour setting
                    local d = addon.db.profile.durationLower
                    if d <= 1 then d = 0 end
                    if (duration >= d) and (duration <= addon.db.profile.durationHigher) then
                        table.insert(missions, mission)
                    end
                end
            end
        end
    end
    
    if addon.db.profile.anythingForXP then
        local newMissions = C_Garrison.GetAvailableMissions(123)
        
        -- filter out missions already in the queue
        for key, mission in pairs(newMissions) do
            local exists = false
            for _, mission2 in pairs(missions) do
                if mission.missionID == mission2.missionID then
                    exists = true
                    break
                end
            end
            
            if exists then
                newMissions[key] = nil
            end
        end
        
        -- filter out missions with XP not in the dropdown selections
        for key, mission in pairs(newMissions) do
            if mission.xp <= 500 then
                if not addon.db.profile.anythingForXPCategories["1-500"] then
                    newMissions[key] = nil
                end
            elseif mission.xp <= 600 then
                if not addon.db.profile.anythingForXPCategories["501-600"] then
                    newMissions[key] = nil
                end
            elseif mission.xp <= 700 then
                if not addon.db.profile.anythingForXPCategories["601-700"] then
                    newMissions[key] = nil
                end
            elseif mission.xp <= 800 then
                if not addon.db.profile.anythingForXPCategories["701-800"] then
                    newMissions[key] = nil
                end
            elseif mission.xp <= 900 then
                if not addon.db.profile.anythingForXPCategories["801-900"] then
                    newMissions[key] = nil
                end
            elseif mission.xp <= 1000 then
                if not addon.db.profile.anythingForXPCategories["901-1000"] then
                    newMissions[key] = nil
                end
            else
                if not addon.db.profile.anythingForXPCategories["1000+"] then
                    newMissions[key] = nil
                end
            end
        end
        
        local n = {}
        for k, v in pairs(newMissions) do
            table.insert(n, v)
        end
        newMissions = n
        
        table.sort(newMissions, function(a, b)
            if a.xp == b.xp then
                return a.missionID < b.missionID
            end
            return a.xp > b.xp
        end)
        
        for _, mission in ipairs(newMissions) do
            local animaCost = C_Garrison.GetMissionCost(mission.missionID)
            if not animaCost then animaCost = 1 end
            local acCategory = "AnythingForXP"
            if      ( gui.AnimaCostLimitSlider:GetValue() >= animaCost ) and
                    (
                        ( (animaCost < 25) and addon.db.profile.animaCosts[acCategory]["10-24"] ) or
                        ( (animaCost < 30) and (animaCost > 24) and addon.db.profile.animaCosts[acCategory]["25-29"] ) or
                        ( (animaCost < 50) and (animaCost > 29) and addon.db.profile.animaCosts[acCategory]["30-49"] ) or
                        ( (animaCost < 100) and (animaCost > 49) and addon.db.profile.animaCosts[acCategory]["50-99"] ) or 
                        ( (animaCost > 99) and addon.db.profile.animaCosts[acCategory]["100+"] )
                    ) then
                local _, _, _, _, duration = C_Garrison.GetMissionTimes(mission.missionID)
                duration = duration/3600
                
                local d = addon.db.profile.durationLower
                if d <= 1 then d = 0 end
                if (duration >= d) and (duration <= addon.db.profile.durationHigher) then
                    mission.useSpecialTreatment = true
                    table.insert(missions, mission)
                end
            end
        end
    end
    
    local sortFunc
    if addon.db.profile.fewestOrMost == "fewest" then
        sortFunc = addon.arrangeFollowerCombinationsByFewestFollowersPlusTroops
    else
        sortFunc = addon.arrangeFollowerCombinationsByMostFollowersPlusTroops
    end
    
    local sortString = addon.db.profile.lowestOrHighest.."Level"
    
    local followers = C_Garrison.GetFollowers(123)
    
    if (table.getn(missions) == 0) and (not addon.db.profile.sacrificeRemaining) then
        gui.shortcutButton:SetText(FAILED)
        gui.FailedCalcLabel:SetText(L["MissionsAboveRestrictionsError"])
        gui.CalculateButton:SetEnabled(true)
        gui.AbortButton:SetEnabled(false)
        gui.SkipCalculationButton:SetEnabled(false)
        return
    end
    
    local followerLineup = {}
    for _, follower in ipairs(followers) do
        if (not follower.status) and (follower.isCollected) then
            table.insert(followerLineup, follower.followerID)
        end
        local info = C_Garrison.GetFollowerAutoCombatStats(follower.followerID)
        if info and (info.currentHealth < 1) then
            gui.shortcutButton:SetText(FAILED)
            gui.FailedCalcLabel:SetText(L["FollowerZeroHPError"])
            gui.CalculateButton:SetEnabled(true)
            gui.AbortButton:SetEnabled(false)
            gui.SkipCalculationButton:SetEnabled(false)
            return
        end
    end 
    
    if table.getn(followerLineup) == 0 then
        gui.shortcutButton:SetText(FAILED)
        gui.FailedCalcLabel:SetText(L["FollowersUnavailableError"])
        gui.CalculateButton:SetEnabled(true)
        gui.AbortButton:SetEnabled(false)
        gui.SkipCalculationButton:SetEnabled(false)
        return
    end 
    
    setNextMissionText = function()
        if nextMission then
            gui.FailedCalcLabel:SetText()
            local _, _, _, _, duration = C_Garrison.GetMissionTimes(nextMission.missionID)
            if not duration then duration = 3600 end
            duration = duration/3600
            gui.shortcutButton:SetText("("..((missionCounter>0) and missionCounter or 1).."/"..missionCounterUpper..")")
            gui.NextMissionLabel:SetText(string.format(L["MissionCounter"], (missionCounter>0) and missionCounter or 1, missionCounterUpper, nextMission.name).." ("..string.format(COOLDOWN_DURATION_HOURS, math.floor(duration/0.5)*0.5)..")")
            gui.NextFollower1Label:SetText(L["Calculating"])
            updateRewardText(nextMission)
            return true
        end
    end
    
    hasNextMission = function()
        return (table.getn(missions) > 0) or addon.db.profile.sacrificeRemaining
    end
    
    missionCounter = 0
    missionCounterUpper = table.getn(missions)
    
    calculateNextMission = function(doLater)
        local function processing()
            lowerEstimate = 0
            
            nextMission = table.remove(missions, 1)
            
            if (not missionWaitingUserAcceptance) then
                missionCounter = missionCounter + 1
                if not setNextMissionText() then
                    gui.shortcutButton:SetText(COVENANT_MISSIONS_START_ADVENTURE)
                    gui.NextMissionLabel:SetText()
                    for i = 1, 5 do
                        gui["NextFollower"..i.."Label"]:SetText()
                    end
                    gui.RewardsDetailLabel:SetText()
                    gui.LowTimeWarningLabel:SetText()
                    gui.CalculateButton:SetEnabled(true)
                    gui.AbortButton:SetEnabled(false)
                    gui.SkipCalculationButton:SetEnabled(false)
                end
                missionCounter = missionCounter - 1
            end
            
            if (not nextMission) and addon.db.profile.sacrificeRemaining then
                startSacrifice()
            end
            if not nextMission then
                gui.SkipCalculationButton:SetEnabled(false)
                return
            end
            
            missionCounter = missionCounter + 1
            
            if nextMission.missionScalar > 60 then
                nextMission.missionScalar = 60
            end
            
            local cost = C_Garrison.GetMissionCost(nextMission.missionID)
            if not cost then cost = 1 end
            if not nextMission.offerEndTime then nextMission.offerEndTime = GetTime() + 601 end
            if (nextMission.offerEndTime < GetTime()) or (gui.AnimaCostLimitSlider:GetValue() < cost) then
                if (not missionWaitingUserAcceptance) then
                    clearReportText()
                    gui.shortcutButton:SetText(FAILED)
                    gui.FailedCalcLabel:SetText(L["AnimaCostLimitError"])
                end
                calculateNextMission()
                return
            end
            
            followerLineup = {}
            
            local useSpecialTreatment = false
            if gui.FollowerXPSpecialTreatmentCheckButton:GetChecked() then
                if nextMission.useSpecialTreatment then
                    useSpecialTreatment = true
                else
                    local rewards = C_Garrison.GetMissionRewardInfo(nextMission.missionID)
                    if rewards then
                        for _, reward in pairs(rewards) do
                            if reward.followerXP then
                                useSpecialTreatment = true
                                break
                            end
                        end
                    end
                end
            end
            
            gui.SkipCalculationButton:SetEnabled(true)
            
            if useSpecialTreatment then
                if (addon.db.profile.followerXPSpecialTreatmentAlgorithm == 1) or (addon.db.profile.followerXPSpecialTreatmentAlgorithm == 2) then -- "All low level followers, lowest level first"
                    for _, follower in ipairs(followers) do
                        if (not follower.status) and (not alreadyUsedFollowers[follower.followerID]) and (follower.level < 60) then
                            table.insert(followerLineup, follower.followerID)
                        end
                    end
                else -- "Followers required to level troops only"
                    local numFollowers = #followers
                    if numFollowers > 0 then
                        local median = numFollowers/2
                        median = math.floor(median)
                        median = median + 1
                        
                        table.sort(followers, function(a, b)
                            if a.level == b.level then
                                if a.xp == b.xp then
                                    return a.garrFollowerID < b.garrFollowerID
                                end
                                return a.xp > b.xp
                            end
                            return a.level > b.level
                        end)
                        
                        for i = 1, median do
                            if (not followers[i].status) and (not alreadyUsedFollowers[followers[i].followerID]) and (followers[i].level < 60) then
                                table.insert(followerLineup, followers[i].followerID)
                            end
                        end
                    end
                end
                
                if (table.getn(followerLineup) < tonumber(addon.db.profile.followerXPSpecialTreatmentMinimum)) then
                    if not missionWaitingUserAcceptance then
                        clearReportText()
                        gui.shortcutButton:SetText(FAILED)
                        gui.FailedCalcLabel:SetText(L["RestrictedFollowersUnavailableError"])
                    end
                    calculateNextMission()
                    return
                end
                
                if (addon.db.profile.followerXPSpecialTreatmentAlgorithm == 1) or (addon.db.profile.followerXPSpecialTreatmentAlgorithm == 1) then
                    addon.arrangeFollowerCombinationsByMostFollowersPlusTroops(addon, followerLineup, nextMission.missionID, processResults, "lowestLevel")
                elseif addon.db.profile.followerXPSpecialTreatmentAlgorithm == 2 then
                    addon.arrangeFollowerCombinationsByMostFollowersPlusTroops(addon, followerLineup, nextMission.missionID, processResults, "highestLevel")
                else
                    addon.arrangeFollowerCombinationsByMostFollowersPlusTroops(addon, followerLineup, nextMission.missionID, processResults, "lowestLevel")
                end
            else
                for _, follower in ipairs(followers) do
                    if (not follower.status) and (not alreadyUsedFollowers[follower.followerID]) then
                        if (follower.level + gui.LowerBoundLevelRestrictionSlider:GetValue()) >= nextMission.missionScalar then
                            table.insert(followerLineup, follower.followerID)
                        end
                    end
                end 
            
                if table.getn(followerLineup) == 0 then
                    if not missionWaitingUserAcceptance then
                        clearReportText()
                        gui.shortcutButton:SetText(FAILED)
                        gui.FailedCalcLabel:SetText(L["RestrictedFollowersUnavailableError"])
                    end
                    calculateNextMission()
                    return
                end
                
                sortFunc(addon, followerLineup, nextMission.missionID, processResults, sortString)
            end
        end
        if doLater then
            local batch = addon:createWorkBatch(1)
            addon:addWork(batch, processing)
        else
            processing()
        end
    end
     
    addon:registerWorkStepCallback(incrementEstimate)
    calculateNextMission(true)
end)

gui.AbortButton:SetScript("OnClick", function (self, button)
	self:SetEnabled(false)
    
    clearReportText()
    addon:clearWork()
    missionWaitingUserAcceptance = nil
    wipe(calculatedMissionBacklog)
    gui.CostLabel:Hide()
    gui.CostResultLabel:SetText("")
    gui.StartMissionButton:SetEnabled(false)
    gui.SkipMissionButton:SetEnabled(false)
    gui.CalculateButton:SetEnabled(true)
    gui.SkipCalculationButton:SetEnabled(false)
end)

gui.SkipCalculationButton:SetScript("OnClick", function(self, button)
    numSkipped = numSkipped + 1
    addon:clearWork()
    self:SetEnabled(false)
    if (not missionWaitingUserAcceptance) and (not hasNextMission()) then
        clearReportText()
        gui.CostLabel:Hide()
        gui.CostResultLabel:SetText("")
        gui.StartMissionButton:SetEnabled(false)
        gui.CalculateButton:SetEnabled(true)
        gui.SkipCalculationButton:SetEnabled(false)
        gui.AbortButton:SetEnabled(false)
        if (numSkipped > 1) or (numSent > 0) then
            local numFollowersAvailable = 0
            for _, follower in pairs(C_Garrison.GetFollowers(123)) do
                if (not follower.status) and (follower.isCollected) then
                    numFollowersAvailable = numFollowersAvailable + 1
                end
            end
            gui.shortcutButton:SetText(DONE.."!")
            gui.FailedCalcLabel:SetText(L["MissionsSentPartial"]:format(numSent, numSkipped, numFailed, numFollowersAvailable))
            AceEvent:SendMessage("TLDRMISSIONS_SENT_PARTIAL", numSent, numSkipped, numFailed, numFollowersAvailable)
            if WeakAuras then
                WeakAuras.ScanEvents("TLDRMISSIONS_SENT_PARTIAL", numSent, numSkipped, numFailed, numFollowersAvailable)
            end
        else
            gui.shortcutButton:SetText(COVENANT_MISSIONS_START_ADVENTURE)
            gui.FailedCalcLabel:SetText(L["MissionSkipped"])
        end
    end
    if hasNextMission() then
        calculateNextMission()
    end
end)

local afterConfirmationEvent
function addon:garrisonMissionStartedHandler(garrFollowerTypeID, missionID)
    if garrFollowerTypeID ~= 123 then return end
    if afterConfirmationEvent then
        afterConfirmationEvent(missionID)
    end
end

gui.StartMissionButton:SetScript("OnClick", function(self, button)
    self:SetEnabled(false)
    gui.SkipMissionButton:SetEnabled(false)
    
    if not missionWaitingUserAcceptance then
        print("Error: mission awaiting user acceptance not found")
        return
    end
    
    local missions = C_Garrison.GetAvailableMissions(123)
    local found = false
    for _, mission in pairs(missions) do
        if mission.missionID == missionWaitingUserAcceptance.missionID then
            found = true
            break
        end
    end
    if not found then
        if table.getn(calculatedMissionBacklog) > 0 then
            processResults(table.remove(calculatedMissionBacklog, 1), true)
        end
        return
    end
    
    local animaCost = C_Garrison.GetMissionCost(missionWaitingUserAcceptance.missionID)
    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(C_CovenantSanctumUI.GetAnimaInfo());
	local amountOwned = currencyInfo.quantity;
	if (amountOwned < animaCost) then
		clearReportText()
        gui.shortcutButton:SetText(FAILED)
        gui.FailedCalcLabel:SetText(L["NotEnoughAnimaError"])
        gui.SkipMissionButton:SetEnabled(true)
        self:SetEnabled(true)
        AceEvent:SendMessage("TLDRMISSIONS_NOT_ENOUGH_ANIMA")
        if WeakAuras then
            WeakAuras.ScanEvents("TLDRMISSIONS_NOT_ENOUGH_ANIMA")
        end
        return
	end
    
    -- remove any followers already pending for this mission
    local lineup =  C_Garrison.GetBasicMissionInfo(missionWaitingUserAcceptance.missionID).followers
    if lineup then
        for _, followerID in pairs(lineup) do
            C_Garrison.RemoveFollowerFromMission(missionWaitingUserAcceptance.missionID, followerID)
        end
    end
    
    local success = true
    -- results.combination : combination will be in the order frontleft, frontmid, frontright, backleft, backright
    if missionWaitingUserAcceptance.combination[1] then
        if not C_Garrison.AddFollowerToMission(missionWaitingUserAcceptance.missionID, missionWaitingUserAcceptance.combination[1], 2) then
            success = false
        end
    end
    if missionWaitingUserAcceptance.combination[2] then
        if not C_Garrison.AddFollowerToMission(missionWaitingUserAcceptance.missionID, missionWaitingUserAcceptance.combination[2], 3) then
            success = false
        end
    end
    if missionWaitingUserAcceptance.combination[3] then
        if not C_Garrison.AddFollowerToMission(missionWaitingUserAcceptance.missionID, missionWaitingUserAcceptance.combination[3], 4) then
            success = false
        end
    end
    if missionWaitingUserAcceptance.combination[4] then
        if not C_Garrison.AddFollowerToMission(missionWaitingUserAcceptance.missionID, missionWaitingUserAcceptance.combination[4], 0) then
            success = false
        end
    end
    if missionWaitingUserAcceptance.combination[5] then
        if not C_Garrison.AddFollowerToMission(missionWaitingUserAcceptance.missionID, missionWaitingUserAcceptance.combination[5], 1) then
            success = false
        end
    end
    
    -- check the pending followers are correct, incase a slot was taken or something
    local lineup = C_Garrison.GetBasicMissionInfo(missionWaitingUserAcceptance.missionID).followers
    if not lineup then success = false end
    for i = 1, 5 do
        if missionWaitingUserAcceptance.combination[i] then
            local found = false
            for _, followerID in pairs(lineup) do
                if missionWaitingUserAcceptance.combination[i] == followerID then
                    found = true
                end
            end
            if not found then success = false end
        end
    end
    
    local _
    _, animaCost = C_Garrison.GetMissionCost(missionWaitingUserAcceptance.missionID)
	if (amountOwned < animaCost) then
		clearReportText()
        gui.shortcutButton:SetText(FAILED)
        gui.FailedCalcLabel:SetText(L["NotEnoughAnimaError"])
        self:SetEnabled(true)
        AceEvent:SendMessage("TLDRMISSIONS_NOT_ENOUGH_ANIMA")
        if WeakAuras then
            WeakAuras.ScanEvents("TLDRMISSIONS_NOT_ENOUGH_ANIMA")
        end
        return
	end
    
    if not success then
        print("Error: something went wrong with mission "..missionWaitingUserAcceptance.missionID.."; one or more followers were not correctly added")
        return
    else
        C_Timer.After(0.4, function()
            if not missionWaitingUserAcceptance then return end
            lineup = C_Garrison.GetBasicMissionInfo(missionWaitingUserAcceptance.missionID).followers
            if not lineup then success = false end
            for i = 1, 5 do
                if missionWaitingUserAcceptance.combination[i] then
                    local found = false
                    for _, followerID in pairs(lineup) do
                        if missionWaitingUserAcceptance.combination[i] == followerID then
                            found = true
                        end
                    end
                    if not found then success = false end
                end
            end
            
            if not success then
                print("Error: something went wrong with mission "..missionWaitingUserAcceptance.missionID.."; one or more followers were not correctly added")
                return
            end
            
            C_Garrison.StartMission(missionWaitingUserAcceptance.missionID)
            if not missionWaitingUserAcceptance.sacrifice then
                addon:logSentMission(missionWaitingUserAcceptance.missionID, missionWaitingUserAcceptance.combination, missionWaitingUserAcceptance.finalHealth)
            else
                addon:wipeObsoleteMissionLog(missionWaitingUserAcceptance.missionID)
            end
            AceEvent:SendMessage("TLDRMISSIONS_START_MISSION", missionWaitingUserAcceptance.missionID, GetAddOnMetadata(addonName, "Version"))
            numSent = numSent + 1
        end)
    end
    
    afterConfirmationEvent = function(missionID)
        if not missionWaitingUserAcceptance then return end
        if missionID ~= missionWaitingUserAcceptance.missionID then
            print("Error: Blizzard sent back confirmation for a different mission")
        end
        
        clearReportText()
        setNextMissionText()
        missionWaitingUserAcceptance = nil
        afterConfirmationEvent = nil
        
        if table.getn(calculatedMissionBacklog) > 0 then
            processResults(table.remove(calculatedMissionBacklog, 1), true)
        else
            gui.EstimateLabel:SetText()
            if hasNextMission() then
                calculateNextMission()
            end
            if addon:isCurrentWorkBatchEmpty() then
                clearReportText()
                if numSkipped > 0 then
                    local numFollowersAvailable = 0
                    for _, follower in pairs(C_Garrison.GetFollowers(123)) do
                        if (not follower.status) and (follower.isCollected) then
                            numFollowersAvailable = numFollowersAvailable + 1
                        end
                    end
                    gui.shortcutButton:SetText(DONE.."!")
                    gui.FailedCalcLabel:SetText(L["MissionsSentPartial"]:format(numSent, numSkipped, numFailed, numFollowersAvailable))
                    AceEvent:SendMessage("TLDRMISSIONS_SENT_PARTIAL", numSent, numSkipped, numFailed, numFollowersAvailable)
                    if WeakAuras then
                        WeakAuras.ScanEvents("TLDRMISSIONS_SENT_PARTIAL", numSent, numSkipped, numFailed, numFollowersAvailable)
                    end
                else
                    gui.shortcutButton:SetText(DONE.."!")
                    gui.NextMissionLabel:SetText(L["MissonsSentSuccess"])
                    -- two different ways to "listen" for this addon announcing the missions have been sent.
                    AceEvent:SendMessage("TLDRMISSIONS_SENT_SUCCESS")
                    if WeakAuras then
                        WeakAuras.ScanEvents("TLDRMISSIONS_SENT_SUCCESS")
                    end
                end
                gui.CalculateButton:SetEnabled(true)
                gui.AbortButton:SetEnabled(false)
                gui.SkipCalculationButton:SetEnabled(false)
            end
        end
    end
end)

gui.SkipMissionButton:SetScript("OnClick", function(self, button)
    numSkipped = numSkipped + 1
    self:SetEnabled(false)
    gui.CostLabel:Hide()
    gui.CostResultLabel:SetText("")
    gui.StartMissionButton:SetEnabled(false)
    
    if not missionWaitingUserAcceptance then
        print("Error: mission awaiting user acceptance not found")
        return
    end
    
    missionWaitingUserAcceptance = nil
    
    if table.getn(calculatedMissionBacklog) > 0 then
        processResults(table.remove(calculatedMissionBacklog, 1), true)
    else
        clearReportText()
        gui.EstimateLabel:SetText()
        if addon:isCurrentWorkBatchEmpty() then
            gui.CalculateButton:SetEnabled(true)
            gui.AbortButton:SetEnabled(false)
            gui.SkipCalculationButton:SetEnabled(false)
            
            local numFollowersAvailable = 0
            for _, follower in pairs(C_Garrison.GetFollowers(123)) do
                if (not follower.status) and (follower.isCollected) then
                    numFollowersAvailable = numFollowersAvailable + 1
                end
            end
            gui.shortcutButton:SetText(DONE.."!")
            gui.FailedCalcLabel:SetText(L["MissionsSentPartial"]:format(numSent, numSkipped, numFailed, numFollowersAvailable))
            AceEvent:SendMessage("TLDRMISSIONS_SENT_PARTIAL", numSent, numSkipped, numFailed, numFollowersAvailable)
            if WeakAuras then
                WeakAuras.ScanEvents("TLDRMISSIONS_SENT_PARTIAL", numSent, numSkipped, numFailed, numFollowersAvailable)
            end
        else
            setNextMissionText()
        end
    end
end)

local oncePerLogin = true
gui.CompleteMissionsButton:SetScript("OnClick", function(self, button)
    local i = 0
    local missions = C_Garrison.GetCompleteMissions(123)
    
    if table.getn(missions) == 0 then
        self:SetText(L["NotYet"])
        C_Timer.After(5, function()
            self:SetText(L["CompleteMissionsButtonText"])
        end)
        return
    end
    
    local size = table.getn(missions)
    for _, mission in pairs(missions) do
        self:SetText(size)
        C_Timer.After(i, function()
            C_Garrison.RegenerateCombatLog(mission.missionID)
            C_Timer.After(0.1, function()
                size = size - 1
                self:SetText(size)
                gui.shortcutButton:SetText(size)
                if size < 1 then
                    self:SetText(DONE.."!")
                    AceEvent:SendMessage("TLDRMISSIONS_COMPLETE_MISSIONS_FINISHED")
                    if WeakAuras then
                        WeakAuras.ScanEvents("TLDRMISSIONS_COMPLETE_MISSIONS_FINISHED")
                    end
                    C_Timer.After(2, function()
                        if #C_Garrison.GetCompleteMissions(123) == 0 then
                            self:Hide()
                        elseif oncePerLogin then
                            oncePerLogin = false
                            gui.CompleteMissionsButton:Click()
                            return
                        end
                        self:SetText(L["CompleteMissionsButtonText"])
                        if self.usedShortcut then
                            self.usedShortcut = nil
                            gui.CalculateButton:Click()
                        end
                    end)
                end
                C_Garrison.MarkMissionComplete(mission.missionID)
                C_Garrison.MissionBonusRoll(mission.missionID)
            end)
        end)
        i = i + 0.1
    end
end)

gui.MinimumTroopsSlider:SetScript("OnValueChanged", function(self, value, userInput)
    TLDRMissionsFrameMinimumTroopsSliderText:SetText(value)
    addon.db.profile.minimumTroops = value
end)

gui.LowerBoundLevelRestrictionSlider:SetScript("OnValueChanged", function(self, value, userInput)
    TLDRMissionsFrameSliderText:SetText(value)
    addon.db.profile.LevelRestriction = value
end)

gui.AnimaCostLimitSlider:SetScript("OnValueChanged", function(self, value, userInput)
    TLDRMissionsFrameAnimaCostSliderText:SetText(value)
    addon.db.profile.AnimaCostLimit = value
end)

gui.SimulationsPerFrameSlider:SetScript("OnValueChanged", function(self, value, userInput)
    TLDRMissionsFrameSimulationsSliderText:SetText(value)
    addon.db.profile.workPerFrame = value
end)

-- the reputation submenu dropdown
function gui.ReputationDropDown:OnSelect(factionID, arg2, checked)
    addon.db.profile.reputations[factionID] = checked
end

-- the crafting cache submenu dropdown
function gui.CraftingCacheDropDown:OnSelect(categoryIndex, itemQuality, checked)
    addon.db.profile.craftingCacheTypes[categoryIndex][itemQuality] = checked
end

function gui.RunecarverDropDown:OnSelect(currencyID, arg2, checked)
    addon.db.profile.runecarver[currencyID] = checked
end

function gui.AnimaDropDown:OnSelect(itemQuality, arg2, checked)
    addon.db.profile.animaItemQualities[itemQuality] = checked
end

function gui.FollowerXPItemsDropDown:OnSelect(itemQuality, arg2, checked)
    addon.db.profile.followerXPItemsItemQualities[itemQuality] = checked
end

gui.DurationLowerSlider:SetScript("OnValueChanged", function(self, value, userInput)
    if not userInput then return end
    addon.db.profile.durationLower = value
    if tonumber(addon.db.profile.durationLower) > tonumber(addon.db.profile.durationHigher) then
        local a = addon.db.profile.durationLower
        addon.db.profile.durationLower = addon.db.profile.durationHigher
        addon.db.profile.durationHigher = a
        gui.DurationLowerSlider:SetValue(addon.db.profile.durationLower)
        gui.DurationHigherSlider:SetValue(addon.db.profile.durationHigher)
    end
    TLDRMissionsFrameDurationLowerSliderText:SetText(L["DurationTimeSelectedLabel"]:format(addon.db.profile.durationLower, addon.db.profile.durationHigher))
end)

gui.DurationHigherSlider:SetScript("OnValueChanged", function(self, value, userInput)
    if not userInput then return end
    addon.db.profile.durationHigher = value
    if tonumber(addon.db.profile.durationLower) > tonumber(addon.db.profile.durationHigher) then
        local a = addon.db.profile.durationLower
        addon.db.profile.durationLower = addon.db.profile.durationHigher
        addon.db.profile.durationHigher = a
        gui.DurationLowerSlider:SetValue(addon.db.profile.durationLower)
        gui.DurationHigherSlider:SetValue(addon.db.profile.durationHigher)
    end
    TLDRMissionsFrameDurationLowerSliderText:SetText(L["DurationTimeSelectedLabel"]:format(addon.db.profile.durationLower, addon.db.profile.durationHigher))
end)

function gui.GearDropDown:OnSelect(goldCategory, arg2, checked)
    addon.db.profile.gearGoldCategories[goldCategory] = checked
end

function gui.CampaignDropDown:OnSelect(campaignCategory, arg2, checked)
    addon.db.profile.campaignCategories[campaignCategory] = checked
end

function gui.SanctumFeatureDropDown:OnSelect(category, arg2, checked)
    for categoryName, c in pairs(addon.sanctumFeatureItems) do
        if category == categoryName then
            -- if any of them are checked, deselect them all. if none of them are checked, select them all
            local isAnyChecked = false
            for itemID in pairs(c) do
                if addon.db.profile.sanctumFeatureCategories[itemID] then
                    isAnyChecked = true
                end
            end
            for currencyID in pairs(addon.sanctumFeatureCurrencies[categoryName]) do
                if addon.db.profile.sanctumFeatureCategories[currencyID] then
                    isAnyChecked = true
                end
            end
            isAnyChecked = not isAnyChecked
            for itemID in pairs(c) do
                addon.db.profile.sanctumFeatureCategories[itemID] = isAnyChecked
            end
            for currencyID in pairs(addon.sanctumFeatureCurrencies[categoryName]) do
                addon.db.profile.sanctumFeatureCategories[currencyID] = isAnyChecked
            end
            LibDD:ToggleDropDownMenu(nil, nil, TLDRMissionsSanctumFeatureDropDown)
            LibDD:ToggleDropDownMenu(nil, nil, TLDRMissionsSanctumFeatureDropDown)
            return
        end
    end
    addon.db.profile.sanctumFeatureCategories[category] = checked
end

function gui.AnythingForXPDropDown:OnSelect(category, arg2, checked)
    addon.db.profile.anythingForXPCategories[category] = checked
end