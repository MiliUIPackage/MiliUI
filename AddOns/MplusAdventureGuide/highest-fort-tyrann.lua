local addonName, addon = ...

function addon:initHighestFortTyr()
    if not addon.db.profile.highestFortTyr then return end
    
    hooksecurefunc(ChallengesFrame, "Update", function()
        local currentAffix = C_MythicPlus.GetCurrentAffixes()
        if not currentAffix then return end
        if #currentAffix == 0 then return end
        currentAffix = currentAffix[1]
        if not currentAffix then return end
        currentAffix = currentAffix.id
        local tyrannical = currentAffix == 9
        
        for i, icon in ipairs(ChallengesFrame.DungeonIcons) do
            icon.HighestLevelFortifiedTyrannical = icon.HighestLevelFortifiedTyrannical or icon:CreateFontString(nil, "BORDER", "SystemFont_Huge1_Outline")
            local highest = icon.HighestLevelFortifiedTyrannical
            highest:SetJustifyH("CENTER")
            highest:SetPoint("BOTTOM", 0, 4)
            highest:SetTextColor(1, 1, 1)
            highest:SetShadowColor(0, 0, 0)
            highest:SetShadowOffset(1, -1)
            highest:SetScale(0.8)

            local affixScores, overAllScore = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(icon.mapID)
            local wasChanged
            if (affixScores and #affixScores > 0) then
                for _, affixInfo in ipairs(affixScores) do
                    if (tyrannical and (affixInfo.name == C_ChallengeMode.GetAffixInfo(9))) or ((not tyrannical) and (affixInfo.name == C_ChallengeMode.GetAffixInfo(10))) then
                        highest:SetText("["..affixInfo.level.."]")
                        if (affixInfo.overTime) then
                            highest:SetTextColor(LIGHTGRAY_FONT_COLOR.r, LIGHTGRAY_FONT_COLOR.g, LIGHTGRAY_FONT_COLOR.b)
                        else
                            highest:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                        end
                        wasChanged = true
                    end
                end
            end
            if not wasChanged then
                highest:SetText("")
            end
        end
    end)
end
