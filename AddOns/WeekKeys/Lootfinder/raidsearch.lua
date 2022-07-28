function LF:RaidSearch()
    local index = 1

    while EJ_GetInstanceByIndex(index, true) ~= nil do -- for each instance
        if not self:IsBlacklisted("raid", index) then

            local instanceID, instancename = EJ_GetInstanceByIndex(index, true)
            EJ_SelectInstance(instanceID)

            for i=1, EJ_GetNumLoot() do
                local itemInfo = C_EncounterJournal.GetLootInfoByIndex(i)
                local bossname = EJ_GetEncounterInfo(itemInfo.encounterID)
                if not itemInfo.link then
                    i = i - 1 -- item not loaded, step back
                elseif self:FilterCheck(itemInfo.link) then
                    self:AddResult("raid", instancename, bossname,itemInfo.link)
                end
            end
        end
        index = index + 1
    end
-----------------------------------------------------------------------------------------------------------
-- LootFinder.selectedstats

end


