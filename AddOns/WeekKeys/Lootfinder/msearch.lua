
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
local loot_table = {
    [370] = {
        168962,168955,168967,168958,168957,168966,168964,168965,
        168970,168971,168969,168968,168972,
        168973,169608,168976,168974,168975,169160,169161,168977,169159,169344,
        168978,168989,168980,168985,168983,168986,168988,168982
    },
    [391] = {
        185824,185780,185816,185815,185791,185793,
        185777,185821,185814,185792,185794,185809,185840,
        185811,185817,185808,185807,185787,185846,185845,190652,
        185783,185812,185842,185804,185802,185806,185789,
        185778,185843,185782,185786,185800,185798,185836
    },
    [166] = {
        109866,109846,109972,109932,109901,109869,109978,
        109937,109897,109934,109983,109890,109942,109895,
        109988,109840,109946,110052,110053,110054,109996,
        110051,110001
    },
    [369] = {
        169050,169035,169052,169054,169051,169049,169053,
        169062,169058,169059,169061,169060,169057,169056,169055,
        169066,169068,169064,169069,169063,169067,169070,169065,169769,

    },
    [234] = {
        142130,142125,142149,142133,142141,142172,142165,
        142207,142152,142131,142129,142145,142157,142169,
        142150,142144,142128,142215,142135,142162,
        142142,142127,142151,142132,142173,142167,
    },
    [392] = {
        185810,185779,185803,185805,185781,185790,185788,
        185823,185841,185776,185796,185797,185795,185820,
        185822,185819,185784,185785,185799,185801,185813,190958,
    },
    [227] = {
        142296,142198,142299,142205,142137,142300,142298,142204,
        142201,142302,142154,142146,142160,142164,
        142304,142206,142196,142202,142197,142168,
        142170,142139,142138,142153,142124,142158,
        142126,142174,142136,142140,142148,142161,
        142134,142123,142147,142143,142171,142159,
    },
    [169] = {
        109881,109903,109948,109979,109885,109875,109887,109980,
        109939,109879,109859,109802,109822,110058,110056,110055,
        110057,110059,110060,110017,110002,109997
    }
}

function LF:MPlusSearch()
    for instanceID, instance_loot in pairs(loot_table) do
        local name, id, timeLimit, texture, backgroundTexture = C_ChallengeMode.GetMapUIInfo(instanceID)
        for _, itemID in pairs(instance_loot) do
            local _,itemlink = GetItemInfo(itemID)
            if self:FilterCheck(itemlink) then
                local chest, key = C_MythicPlus.GetRewardLevelForDifficultyLevel(self.mlevel)
                local milvl = nil
                if self.chest then
                    milvl = chest
                else
                    milvl = key
                end
                itemlink = itemlink:gsub("%d+:3524:%d+:%d+:%d+","5:"..(mythic_level[self.mlevel] or 6808)..":6652:1501:"..((milvl or 220) + 5658)..":6646")
                self:AddResult("instance", name, name,itemlink)
            end
        end
    end

    --[[
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
--]]
end


