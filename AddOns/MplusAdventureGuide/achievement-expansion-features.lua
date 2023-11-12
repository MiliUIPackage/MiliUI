local addonName, addon = ...

function addon:initAchievementExpansionFeatures()
    if not addon.db.profile.achievementExpansionFeatures then return end
    table.insert(ACHIEVEMENTUI_SUMMARYCATEGORIES, 15301)
end
