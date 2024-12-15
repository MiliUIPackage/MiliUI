local addonName, addon = ...

-- Blizzards implementation of the minimum rating field caps out at 999
-- I haven't been able to find a way to retrieve that field so I can edit its character limit
-- This adds another minimum rating field capped to 9999

function addon.initMinRatingLonger()
    if not addon.db.profile.minRatingLonger then return end
    local minRatingFrame = CreateFrame("Frame", "MPAGMinRatingFrame", nil, "LevelRangeFrameTemplate")
    minRatingFrame.MinLevel:SetMaxLetters(4)
    minRatingFrame:Hide()
	minRatingFrame:SetWidth(58)
    minRatingFrame.MinLevel:SetWidth(38)
	minRatingFrame.MaxLevel:Hide()
	minRatingFrame.MinLevel.Dash:Hide()

    local enabled = C_LFGList.GetAdvancedFilter();
  	local overrideMinRating = enabled.minimumRating;
  	if overrideMinRating > 0 then
  		minRatingFrame:SetMinLevel(overrideMinRating);
  	end 
    
    minRatingFrame:SetLevelRangeChangedCallback(function(minLevel, maxLevel)
		overrideMinRating = minLevel 
	end)
    
    hooksecurefunc(LFGListFrame.SearchPanel.FilterButton, "OnMenuOpened", function(self, dropdown)
        if LFGListFrame.CategorySelection.selectedCategory == GROUP_FINDER_CATEGORY_ID_DUNGEONS then
            minRatingFrame:SetParent(dropdown)
            minRatingFrame:SetPoint("BOTTOMLEFT", dropdown, "BOTTOMLEFT", 8, 125)
            minRatingFrame:SetFrameStrata("TOOLTIP")
            minRatingFrame:Show()
            
            local enabled = C_LFGList.GetAdvancedFilter();
        	enabled.minimumRating = overrideMinRating
        	C_LFGList.SaveAdvancedFilter(enabled)
        else
            minRatingFrame:Hide()
        end
    end)
    
    hooksecurefunc(LFGListFrame.SearchPanel.FilterButton, "OnMenuClosed", function(self, dropdown)
        minRatingFrame:Hide()
        if LFGListFrame.CategorySelection.selectedCategory ~= GROUP_FINDER_CATEGORY_ID_DUNGEONS then return end
        
        local enabled = C_LFGList.GetAdvancedFilter()
        enabled.minimumRating = overrideMinRating
        C_LFGList.SaveAdvancedFilter(enabled)
    end)
end