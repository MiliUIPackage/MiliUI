local addonName, addon = ...

local mapToAcronym = {
    [400] = "NO",
    [404] = "NELT",
    [401] = "AV",
    [399] = "RLP",
    [406] = "HoI",
    [402] = "AA",
    [405] = "BH",
    [403] = "ULDA",
}

function addon:initAcronyms()
    if GetLocale() ~= "enUS" then return end
    if not addon.db.profile.acronyms then return end
    ChallengesFrame.WeeklyInfo.Child.SeasonBest:Hide()
    
    hooksecurefunc(ChallengesFrame, "Update", function()
        for i, icon in ipairs(ChallengesFrame.DungeonIcons) do
            icon.AcronymLabel = icon.AcronymLabel or icon:CreateFontString(nil, "BORDER", "SystemFont_Huge1_Outline")
            local label = icon.AcronymLabel
            label:SetJustifyH("CENTER")
            label:SetPoint("BOTTOM", icon, "TOP", 0, 2)
            label:SetTextColor(1, 1, 0.8)
            label:SetShadowColor(0, 0, 0)
            label:SetShadowOffset(1, -1)
            label:SetScale(0.9)
            if mapToAcronym[icon.mapID] then
                label:SetText(mapToAcronym[icon.mapID])
            end
        end
    end)
end
