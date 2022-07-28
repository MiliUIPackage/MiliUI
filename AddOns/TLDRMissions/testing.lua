local addonName = ...
local addon = _G[addonName]

function addon:TestNextCompletedMission()
    local mission = C_Garrison.GetCompleteMissions(123)
    if not mission[1] then
        print("Error: no completed missions found") 
    else
    
        mission = mission[1]
        local missionID = mission.missionID
        
        local followers = mission.followers
        local sortedFollowers = {}
        for i = 1, 5 do
            if followers[i] then
                sortedFollowers[C_Garrison.GetFollowerMissionCompleteInfo(followers[i]).boardIndex] = followers[i]
            end
        end
        
        -- GetFollowerMissionCompleteInfo puts the boardIndex in a different order to how I coded this addon
        -- It uses 0 = backleft, 1 = backright, 2 = frontleft, 3 = frontmiddle, 4 = frontright
        print("Simulating mission "..mission.name)
        addon:Simulate(sortedFollowers[2], sortedFollowers[3], sortedFollowers[4], sortedFollowers[0], sortedFollowers[1], missionID)
        
        -- addon.currentSimResults
        
    end
    
    -- override the Adventures Combat Log to show the board index next to the name
    function CombatLog:GetNameAtBoardIndex(boardIndex) 
        if boardIndex == -1 and self.environmentEffect then 
            return self.environmentEffect.name 
        end 
        local frame = self:GetCompleteScreen():GetFrameFromBoardIndex(boardIndex) 
        return frame and frame:GetName().."["..boardIndex.."]["..frame:GetHealth().."HP]" or "" 
    end
    
    for i = 1, CombatLog.CombatLogMessageFrame:GetNumMessages() do
        local a = CombatLog.CombatLogMessageFrame:GetMessageInfo(i) 
        table.insert(TLDRMissionsDB, a)
    end
end

local function report(result)
    DevTools_Dump(result)
end

function addon:TestFirstTenFollowersPlusTroops()
    local mission = C_Garrison.GetAvailableMissions(123)
    if not mission[1] then print("Error: no available missions found") return end
    
    mission = mission[1]
    local missionID = mission.missionID
    
    local followers = {}
    for i = 1, 5 do
        table.insert(followers, C_Garrison.GetFollowers(123)[i].followerID)
    end
    
    print("Simulating mission "..mission.name)
    addon:arrangeFollowerCombinationsByFewestFollowersPlusTroops(followers, missionID, report, "lowestLevel")
end

function addon:TestGetMissions()
    DevTools_Dump(addon:GetAllMissionsMatchingFilter("gold"))
end

function addon:TestExistingMission(missionID)    
    local followers = C_Garrison.GetBasicMissionInfo(missionID).followers
    local followerLineup = {}
    for _, follower in pairs(followers) do
        followerLineup[C_Garrison.GetFollowerMissionCompleteInfo(follower).boardIndex] = follower
    end
    addon:Simulate(followerLineup[2], followerLineup[3], followerLineup[4], followerLineup[0], followerLineup[1], missionID)
end

function addon:TestMission(missionID)
    local followers = C_Garrison.GetFollowers(123)
    addon:Simulate(followers[1].followerID, followers[2].followerID, followers[3].followerID, followers[4].followerID, followers[5].followerID, missionID)
end