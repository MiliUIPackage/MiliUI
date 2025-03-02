local addonName, addon = ...

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    addon:setupOptions()
    addon:initWatermark()
    
    RunNextFrame(function()
        EventUtil.ContinueOnAddOnLoaded("Blizzard_ChallengesUI", function()
            addon:initPortalButtons()
            addon:initKeystoneMovable()
            addon:initAcronyms()
        end)
        
        EventUtil.ContinueOnAddOnLoaded("Blizzard_AchievementUI", addon.initAchievementExpansionFeatures)
        EventUtil.ContinueOnAddOnLoaded("Blizzard_Collections", addon.initWardrobeClassColours)
        EventUtil.ContinueOnAddOnLoaded("Blizzard_TokenUI", addon.initWarbandTransferable)
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WeeklyRewards", addon.initDelvesProgressTooltip)
    end)
end)
