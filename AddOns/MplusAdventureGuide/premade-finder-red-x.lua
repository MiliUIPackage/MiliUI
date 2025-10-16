local addonName, addon = ...

function addon:initPremadeFinderRedX()
    if not addon.db.profile.premadeFinderRedX then return end
    if not LFGListFrame then return end
    
    LFGListFrame.SearchPanel.FilterButton.ResetButton:Hide()
    LFGListFrame.SearchPanel.FilterButton.ResetButton:HookScript("OnShow", function()
        LFGListFrame.SearchPanel.FilterButton.ResetButton:Hide()
    end)
end
