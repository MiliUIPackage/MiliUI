local addonName, addon = ...

function addon:initAchievementExpansionFeatures()
    if not addon.db.profile.achievementExpansionFeatures then return end
    for _, categoryID in pairs(ACHIEVEMENTUI_SUMMARYCATEGORIES) do
        if categoryID == 15301 then
            return
        end
    end
    table.insert(ACHIEVEMENTUI_SUMMARYCATEGORIES, 15301)
    
    -- This bar is finally being used, but is currently anchored differently from the rest
    AchievementFrameSummaryCategoriesCategory11:ClearAllPoints()
    AchievementFrameSummaryCategoriesCategory11:SetPoint("TOPLEFT", AchievementFrameSummaryCategoriesCategory9, "BOTTOMLEFT", 0, -10)
    
    -- This is Remix: Pandaria
    -- There is no longer enough room to show this one, and it will probably get removed next patch anyway.
    --table.insert(ACHIEVEMENTUI_SUMMARYCATEGORIES, 15509)
end
