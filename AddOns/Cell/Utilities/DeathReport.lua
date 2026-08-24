local _, Cell = ...
local L = Cell.L
local F = Cell.funcs

local UnitIsFeignDeath = UnitIsFeignDeath
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitName = UnitName
local IsInGroup = IsInGroup
local IsEncounterInProgress = IsEncounterInProgress

----------------------------------------------------
-- vars
----------------------------------------------------
local init, instanceType, inInstance
local limit, count

----------------------------------------------------
-- Send helper
----------------------------------------------------
local function Send(msg)
    if Cell.hasHighestPriority then
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
            SendChatMessage(strupper(ACTION_UNIT_DIED)..": "..msg, "INSTANCE_CHAT")
        else
            SendChatMessage(strupper(ACTION_UNIT_DIED)..": "..msg, IsInRaid() and "RAID" or "PARTY")
        end
    end
end

local function CheckSendLimit()
    if instanceType == "raid" and IsEncounterInProgress() then
        count = count + 1
        if count > limit then
            return false
        end
    end
    return true
end

----------------------------------------------------
-- Death detection
-- 12.x: addons cannot register COMBAT_LOG_EVENT_UNFILTERED, so the detailed
-- "killed by X, hit for Y, overkill Z" report is gone for good -- with it went the
-- deathLogs bookkeeping and the whole pre-Midnight branch. What is left: watch group
-- units' UNIT_HEALTH and announce the first moment UnitIsDeadOrGhost() turns true.
-- Group channels are still allowed to receive chat during an encounter, so the
-- announcement itself works; it just says who died, never what killed them.
----------------------------------------------------
local frame = CreateFrame("Frame")

local reportedDead = {} -- guid -> true when already reported this death

local function OnUnitHealth(unit)
    if not unit then return end
    local guid = UnitGUID(unit)
    -- Secret GUIDs can't be used as table keys.
    if F.IsSecretValue and F.IsSecretValue(guid) then return end
    if UnitIsDeadOrGhost(unit) and not UnitIsFeignDeath(unit) then
        if guid and not reportedDead[guid] then
            reportedDead[guid] = true
            if not CheckSendLimit() then return end
            local name = UnitName(unit) or unit
            Send(name)
        end
    else
        -- unit is alive again; allow future death reports
        if guid then
            reportedDead[guid] = nil
        end
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_HEALTH" then
        OnUnitHealth(...)
    elseif self[event] then
        self[event](self, ...)
    end
end)

----------------------------------------------------
-- Shared event handlers (both paths)
----------------------------------------------------
function frame:PLAYER_ENTERING_WORLD()
    local isIn, iType = IsInInstance()
    instanceType = iType

    if instanceType == "pvp" or instanceType == "arena" then
        frame:UnregisterEvent("ENCOUNTER_START")
        frame:UnregisterEvent("ENCOUNTER_END")
        frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
        return
    else
        frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    end

    if not init then frame:GROUP_ROSTER_UPDATE() end
    if isIn then
        inInstance = true
        if instanceType == "raid" then
            frame:RegisterEvent("ENCOUNTER_START")
            count = 0
        else
            frame:UnregisterEvent("ENCOUNTER_START")
        end
    elseif inInstance then -- left instance
        inInstance = false
        frame:UnregisterEvent("ENCOUNTER_START")
    end
end

local timer
function frame:GROUP_ROSTER_UPDATE()
    if IsInGroup() then
        if IsEncounterInProgress() then
            frame:RegisterEvent("ENCOUNTER_END")
        else
            if timer then timer:Cancel() end
            timer = C_Timer.NewTimer(7, function()
                F.CheckPriority()
            end)
        end
    else
    end
    init = true
end

function frame:ENCOUNTER_END()
    frame:UnregisterEvent("ENCOUNTER_END")
    frame:GROUP_ROSTER_UPDATE()
end

function frame:ENCOUNTER_START()
    count = 0
end

-- (the UpdatePriority callback is gone with the CLEU path -- all it ever did was arm and
-- disarm COMBAT_LOG_EVENT_UNFILTERED. Send() still checks Cell.hasHighestPriority, so only
-- one addon in the group announces.)

----------------------------------------------------
-- UpdateTools
----------------------------------------------------
local enabled
local function UpdateTools(which)
    if not which or which == "deathReport" then
        if CellDB["tools"]["deathReport"][1] then
            frame:RegisterEvent("PLAYER_ENTERING_WORLD")
            frame:RegisterEvent("GROUP_ROSTER_UPDATE")
            -- UNIT_HEALTH on the roster is the death signal now: UnitHealth() itself is
            -- secret, UnitIsDeadOrGhost() is not.
            frame:RegisterEvent("UNIT_HEALTH")

            limit = CellDB["tools"]["deathReport"][2]
            count = 0
            if not enabled and which == "deathReport" then -- already in world, manually enabled
                frame:PLAYER_ENTERING_WORLD()
            end
            enabled = true
        else
            frame:UnregisterAllEvents()
            enabled = false
        end
    end
end
Cell.RegisterCallback("UpdateTools", "DeathReport_UpdateTools", UpdateTools)