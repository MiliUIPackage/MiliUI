local addonName, addon = ...

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    addon:setupOptions()
    addon:initWatermark()
    
    C_Timer.After(0, function()
        EventUtil.ContinueOnAddOnLoaded("Blizzard_ChallengesUI", function()
            addon:initHighestFortTyr()
            addon:initPortalButtons()
            addon:initKeystoneMovable()
        end)
        
        EventUtil.ContinueOnAddOnLoaded("Blizzard_AchievementUI", function()
            addon:initAchievementExpansionFeatures()
        end)
    end)
end)
