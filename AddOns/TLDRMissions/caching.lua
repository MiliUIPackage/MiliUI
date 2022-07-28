local addonName = ...
local addon = _G[addonName]
local addonVersion = GetAddOnMetadata(addonName, "Version")

local GFICache = {}
function addon:C_Garrison_GetFollowerInfo(garrFollowerID)
    local cache = C_Garrison.GetFollowerInfo(garrFollowerID)
    if cache then
        GFICache[garrFollowerID] = CopyTable(cache)
        return cache
    end
    
    if GFICache[garrFollowerID] then
        return CopyTable(GFICache[garrFollowerID])
    end
end

local function getGarrFollowerID(followerID)
    if GFICache[followerID] then
        if GFICache[followerID].garrFollowerID then
            return GFICache[followerID].garrFollowerID
        end
        for i = 1, 2 do
            local troop = C_Garrison.GetAutoTroops(123)[i]
            if troop.followerID == followerID then
                GFICache[followerID].garrFollowerID = troop.garrFollowerID
                return troop.garrFollowerID
            end
        end
    end
    GFICache[followerID] = C_Garrison.GetFollowerInfo(followerID)
    if GFICache[followerID] then
        if GFICache[followerID].garrFollowerID then
            return GFICache[followerID].garrFollowerID
        end
        for i = 1, 2 do
            local troop = C_Garrison.GetAutoTroops(123)[i]
            if troop.followerID == followerID then
                GFICache[followerID].garrFollowerID = troop.garrFollowerID
                return troop.garrFollowerID
            end
        end
    end
end

local function getKey(follower1, follower2, follower3, follower4, follower5)
    local lineup = {follower1, follower2, follower3, follower4, follower5}
    
    local function sort_func(a, b)
        if a == nil then return false end
        if b == nil then return true end
        return getGarrFollowerID(a) < getGarrFollowerID(b)
    end
    
    table.sort(lineup, sort_func)
    
    local key = ""
    for i = 1, 5 do --_, follower in ipairs(lineup) do
        local follower = lineup[i]
        if follower then
            if key ~= "" then
                key = key .. "--"
            end
            
            local info = addon:C_Garrison_GetFollowerInfo(follower)
            key = key..info.garrFollowerID.."-"
            
            info = addon:C_Garrison_GetFollowerAutoCombatStats(follower)
            key = key..info.attack.."-"
            key = key..info.currentHealth
        end
    end
    
    return key
end

function addon:isResultCacheGuaranteedFailure(missionID, follower1, follower2, follower3, follower4, follower5)
    local key = getKey(follower1, follower2, follower3, follower4, follower5)
    local missionLevel = C_Garrison.GetBasicMissionInfo(missionID).missionScalar
    local troopsLevel = C_Garrison.GetAutoTroops(123)[1].level
    
    if TLDRMissionsCache[addonVersion][missionID] then
        if TLDRMissionsCache[addonVersion][missionID][missionLevel] then
            if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] then
                if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"] then
                    return TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"][key]
                end
            end
        end
    end
end

-- the keys should be followers only. no matter what troops we set, the mission will fail
function addon:setResultCacheGuaranteedFailure(missionID, follower1, follower2, follower3, follower4, follower5)
    local key = getKey(follower1, follower2, follower3, follower4, follower5)
    local missionLevel = C_Garrison.GetBasicMissionInfo(missionID).missionScalar
    local troopsLevel = C_Garrison.GetAutoTroops(123)[1].level
    
    if TLDRMissionsCache[addonVersion][missionID] then
        if TLDRMissionsCache[addonVersion][missionID][missionLevel] then
            if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] then
                if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"] then
                    TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"][key] = true
                else
                    TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"] = {}
                    TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"][key] = true
                end
            else
                TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] = {}
                TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"] = {}
                TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"][key] = true
            end
        else
            TLDRMissionsCache[addonVersion][missionID][missionLevel] = {}
            TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] = {}
            TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"] = {}
            TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"][key] = true
        end
    else
        TLDRMissionsCache[addonVersion][missionID] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["g"][key] = true
    end
end

function addon:isResultCacheCombinationKnown(missionID, follower1, follower2, follower3, follower4, follower5)
    local key = getKey(follower1, follower2, follower3, follower4, follower5)
    local missionLevel = C_Garrison.GetBasicMissionInfo(missionID).missionScalar
    local troopsLevel = C_Garrison.GetAutoTroops(123)[1].level
    
    if TLDRMissionsCache[addonVersion][missionID] then
        if TLDRMissionsCache[addonVersion][missionID][missionLevel] then
            if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] then
                if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] then
                    local cache = TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key]
                    
                    if cache == nil then
                        return
                    elseif cache == false then
                        return false 
                    else
                        local lineup = {follower1, follower2, follower3, follower4, follower5}
                        
                        -- cache will have garrFollowerIDs in the order frontleft, frontmid, frontright, backleft, backright
                        -- need to convert them to followerIDs
                        local combination = {}
                        for l, c in pairs(cache.combination) do
                            for k, v in pairs(lineup) do
                                local garrFollowerID = getGarrFollowerID(v)
                                if c and (c == garrFollowerID) then
                                    combination[l] = v
                                end
                            end
                        end
                        
                        return {
                            ["defeats"] = 0,
                            ["victories"] = 1,
                            ["missionID"] = missionID,
                            ["finalHealth"] = cache.finalHealth,
                            ["combination"] = combination,
                            ["incompletes"] = 0,
                        }
                    end
                end
            end
        end
    end
end

function addon:setResultCacheCombinationUnknown(missionID, follower1, follower2, follower3, follower4, follower5)
    local key = getKey(follower1, follower2, follower3, follower4, follower5)
    local missionLevel = C_Garrison.GetBasicMissionInfo(missionID).missionScalar
    local troopsLevel = C_Garrison.GetAutoTroops(123)[1].level
    
    if TLDRMissionsCache[addonVersion][missionID] then
        if TLDRMissionsCache[addonVersion][missionID][missionLevel] then
            if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] then
                if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] then
                    TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = false
                else
                    TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] = {}
                    TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = false
                end
            else
                TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] = {}
                TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] = {}
                TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = false
            end
        else
            TLDRMissionsCache[addonVersion][missionID][missionLevel] = {}
            TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] = {}
            TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] = {}
            TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = false
        end
    else
        TLDRMissionsCache[addonVersion][missionID] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = false
    end
end

function addon:setResultCacheCombinationKnown(missionID, follower1, follower2, follower3, follower4, follower5, results)
    local key = getKey(follower1, follower2, follower3, follower4, follower5)
    local missionLevel = C_Garrison.GetBasicMissionInfo(missionID).missionScalar
    local combination = CopyTable(results.combination)
    local lineup = {follower1, follower2, follower3, follower4, follower5}
    local troopsLevel = C_Garrison.GetAutoTroops(123)[1].level
    
    -- need to convert them to followerIDs
    for k, v in pairs(combination) do
        local garrFollowerID = getGarrFollowerID(v)
        for l, c in pairs(lineup) do
            if c then
                if c == v then
                    combination[k] = garrFollowerID
                end
            end
        end
    end
    
    local cache = {
        ["finalHealth"] = results.finalHealth,
        ["combination"] = combination,
    }
    
    if TLDRMissionsCache[addonVersion][missionID] then
        if TLDRMissionsCache[addonVersion][missionID][missionLevel] then
            if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] then
                if TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] then
                    TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = cache
                else
                    TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] = {}
                    TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = cache
                end
            else
                TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] = {}
                TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] = {}
                TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = cache
            end
        else
            TLDRMissionsCache[addonVersion][missionID][missionLevel] = {}
            TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] = {}
            TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] = {}
            TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = cache
        end
    else
        TLDRMissionsCache[addonVersion][missionID] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"] = {}
        TLDRMissionsCache[addonVersion][missionID][missionLevel][troopsLevel]["c"][key] = cache
    end
end

-- https://github.com/teelolws/TLDRMissions/issues/68
local ACSCache = {}
function addon:C_Garrison_GetFollowerAutoCombatStats(garrFollowerID)
    local cache = C_Garrison.GetFollowerAutoCombatStats(garrFollowerID)
    if cache then
        ACSCache[garrFollowerID] = cache
        return CopyTable(cache)
    end
    
    if ACSCache[garrFollowerID] then
        return CopyTable(ACSCache[garrFollowerID])
    end
end