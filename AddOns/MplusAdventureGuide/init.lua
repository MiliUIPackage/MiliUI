local addonName, addon = ...

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    addon:setupOptions()
    addon:initWatermark()
    addon:initEnablePlunderstormRenownButton()
    
    RunNextFrame(function()
        EventUtil.ContinueOnAddOnLoaded("Blizzard_ChallengesUI", function()
            addon:initHighestFortTyr()
            addon:initPortalButtons()
            addon:initKeystoneMovable()
            addon:initAcronyms()
        end)
        
        EventUtil.ContinueOnAddOnLoaded("Blizzard_AchievementUI", function()
            addon:initAchievementExpansionFeatures()
        end)
        
        EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", function()
            addon:initWardrobeClassColours()
        end)
        
        EventUtil.ContinueOnAddOnLoaded("Blizzard_TokenUI", function()
            addon:initWarbandTransferable()
            addon:initCurrencyTransferAllButton()
        end)
    end)
end)
