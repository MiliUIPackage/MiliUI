local addonName, addon = ...

function addon:initAchievementTrackerFix()
    if not addon.db.profile.achievementTrackerFix then return end
    
    -- Fixes Blizzard bug that sometimes keeps completed achievements tracked in an invisible way
    
    C_Timer.After(30, function()
        local entryIDs = C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement)
        for _, entryID in ipairs(entryIDs) do
        	local id, name, points, completed = GetAchievementInfo(entryID)
        	if (not id) or completed then
        	    C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, entryID, Enum.ContentTrackingStopType.Collected)
        	end
        end
    end)
end
