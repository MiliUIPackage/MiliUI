
local mythic_level = {
    6808,
    6808,-- index 2 -> mythic 2
    6809,
    7203,
    7204,
    7205,
    7206,
    7207,
    7208,
    7209,
    7210,
    7211,
    7212,
    7213,
    7214
}

function LF:MPlusSearch()
    local index = 1

    while EJ_GetInstanceByIndex(index, false) ~= nil do -- for each instance
        if not self:IsBlacklisted("m+", index) then
            local instanceID, instancename = EJ_GetInstanceByIndex(index, false)
            EJ_SelectInstance(instanceID)

            for i=1, EJ_GetNumLoot() do
                local itemInfo = C_EncounterJournal.GetLootInfoByIndex(i)
                local bossname = EJ_GetEncounterInfo(itemInfo.encounterID)
                if not itemInfo.link then
                    i = i - 1 -- item not loaded, step back
                elseif self:FilterCheck(itemInfo.link) then
                    local chest, key = C_MythicPlus.GetRewardLevelForDifficultyLevel(self.mlevel)
                    local milvl = nil
                    if self.chest then
                        milvl = chest
                    else
                        milvl = key
                    end
                    itemInfo.link = itemInfo.link:gsub("%d+:3524:%d+:%d+:%d+","5:"..(mythic_level[self.mlevel] or 6808)..":6652:1501:"..((milvl or 220) + 5658)..":6646")
                    self:AddResult("instance", instancename, bossname,itemInfo.link)
                end
            end
        end
        index = index + 1
    end

end


