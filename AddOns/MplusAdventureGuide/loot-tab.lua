local addonName = ...

EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterJournal", function()
    function EncounterJournal_CheckAndDisplayLootTab()
        if (EJ_GetCurrentTier()==9) or (EJ_GetCurrentTier()==10) then 
            PanelTemplates_ShowTab(EncounterJournal, EncounterJournal.LootJournalTab:GetID()) 
        else 
            PanelTemplates_HideTab(EncounterJournal, EncounterJournal.LootJournalTab:GetID())
        end 
    end
    
    EncounterJournalLootJournalTab:HookScript("OnClick", 
        function() 
            EncounterJournal_SetLootJournalView(LOOT_JOURNAL_ITEM_SETS) 
        end
    )
end)
