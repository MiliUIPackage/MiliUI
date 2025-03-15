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
    
    -- TWW season 1
    [376] = "NW",
    [501] = "SV",
    [505] = "DB",
    [353] = "SOB",
    [375] = "MOTS",
    [507] = "GB",
    [502] = "COT",
    [503] = "AK",

    -- TWW season 2
    [506] = "BREW",
    [247] = "ML",
    [500] = "ROOK",
    [382] = "TOP",
    [370] = "WORK",
    [525] = "FLOOD",
    [504] = "DFC",
    [499] = "PSF",
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
