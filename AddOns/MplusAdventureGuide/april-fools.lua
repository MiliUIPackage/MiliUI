if GetLocale() ~= "enUS" then return end

local localTime = date("*t")
if (localTime.month < 3) or (localTime.month > 4) then return end
if (localTime.month == 3) and (localTime.day < 30) then return end
if (localTime.month == 4) and (localTime.day > 1) then return end

local originalName = "March on Quel'Danas"
local replacementName = "April on Quel'Danas"

EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterJournal", function()
    hooksecurefunc("EncounterJournal_ListInstances", function()
        pcall(function()
            localTime = date("*t")
            if (localTime.month ~= 4) or (localTime.day ~= 1) then return end
            
            local items = EncounterJournalInstanceSelect.ScrollBox.view.frames
            for _, item in ipairs(items) do
                if item.name:GetText() == originalName then
                    if item.fakeName then return end
                    item.fakeName = item:CreateFontString("$parentFakeName", "OVERLAY", "QuestTitleFontBlackShadow")
                    local name = item.fakeName
                    name:SetSize(150, 0)
                    name:SetPoint("TOP", 0, -15)
                    item.name:Hide()
                    name:SetText(replacementName)
                    return
                end
            end
        end)
    end)
    
    hooksecurefunc("EncounterJournal_DisplayInstance", function()
        pcall(function()
            localTime = date("*t")
            if (localTime.month ~= 4) or (localTime.day ~= 1) then return end
            
            local instanceTitle = EncounterJournalEncounterFrameInfo.instanceTitle
            if instanceTitle:GetText() == originalName then
                instanceTitle:SetText(replacementName)
            end
            
            instanceTitle = EncounterJournalEncounterFrame.instance.title
            if instanceTitle:GetText() == originalName then
                instanceTitle:SetText(replacementName)
                EncounterJournalEncounterFrame.instance.LoreScrollingFont:SetText("The First of April has arrived upon the Isle of Quel'Danas, darkening the skies above Silvermoon City. The Champions of Azeroth and Arator the Redeemer have checked their calendar, and confirmed they can no longer March upon the Sunwell. Instead, they must April upon the Sunwell before the light of the blood elves is lost forever.")
            end
            
            for _, button in ipairs(EncounterJournalNavBar.navList) do
                if button.text:GetText() == originalName then
                    button.text:SetText(replacementName)
                end
            end
        end)
    end)
end)
