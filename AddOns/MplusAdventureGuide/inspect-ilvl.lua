local addonName, addon = ...

function addon:initInspectIlvl()
    if not addon.db.profile.inspectilvl then return end
    
    local f = InspectFrame:CreateFontString("InspectFrameIlvl", "OVERLAY", "GameTooltipText")
    f:SetPoint("TOPRIGHT", -20, -40)
    InspectFrame:HookScript("OnShow", function()
        f:SetText(C_PaperDollInfo.GetInspectItemLevel(InspectFrame.unit))
    end)
end
