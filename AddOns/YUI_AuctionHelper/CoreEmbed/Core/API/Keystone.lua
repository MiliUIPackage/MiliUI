do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Keystone = YUI.API.Keystone or {}
YUI.API.Keystone = Keystone

local Legacy = YUI.WOW_API

local PREFIX = "LibKS"
local SEND_MESSAGE_DELAY = 0.3
local REQUEST_COOLDOWN = 30

local consumers = {}
local consumerCount = 0
local active = false
local partyKeystones = {}
local lastRequestTime = 0
local isReporting = false

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then
        return a, b, c, d
    end
    return nil
end

local function IsSecretValue(value)
    return issecretvalue and issecretvalue(value) == true
end

local function ReadSafeField(value, key)
    if type(value) ~= "table" or IsSecretValue(value) then return nil end
    local ok, result = pcall(function() return value[key] end)
    if not ok or IsSecretValue(result) then return nil end
    return result
end

local function NormalizeNumber(value)
    if value == nil or IsSecretValue(value) then return nil end
    local ok, result = pcall(tonumber, value)
    if not ok or IsSecretValue(result) then return nil end
    return result
end

local function EmitUpdated()
    if YUI.Event and YUI.Event.Emit then
        YUI.Event:Emit("YUI_KEYSTONE_PARTY_UPDATED")
    end
end

local function IsSupported()
    return YUI.IsRetail == true and C_ChatInfo and C_ChatInfo.SendAddonMessage and C_ChatInfo.RegisterAddonMessagePrefix
end

local function GetTimeSafe()
    local combat = YUI.API and YUI.API.Combat
    if combat and combat.GetTime then
        return combat.GetTime()
    end
    return GetTime and GetTime() or 0
end

local function GetMapName(mapID)
    mapID = tonumber(mapID)
    if not (mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then return nil end
    return SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
end

local function SendAddonMessage(message)
    if not (IsSupported() and IsInGroup and IsInGroup()) then return false end
    local ok = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message, "PARTY")
    return ok == true
end

local function SendPlayerKeystone()
    local data = Keystone.GetPlayerKeystone()
    if data.level > 0 and data.mapID > 0 then
        SendAddonMessage(string.format("%d,%d,%d", data.level, data.mapID, data.rating or 0))
    end
end

local function OnKeystoneEvent(event, prefix, msg, channel, sender)
    if event == "GROUP_ROSTER_UPDATE" then
        if not (IsInGroup and IsInGroup()) then
            wipe(partyKeystones)
            EmitUpdated()
        end
        return
    end

    if event ~= "CHAT_MSG_ADDON" or prefix ~= PREFIX then return end
    if IsSecretValue(msg) then return end

    if msg == "R" then
        SendPlayerKeystone()
        return
    end

    local lvlStr, mapStr, ratingStr = string.match(tostring(msg or ""), "^(%d+),(%d+),(%d+)$")
    if not (lvlStr and mapStr and sender) then return end

    local senderName = Ambiguate and Ambiguate(sender, "none") or sender
    partyKeystones[senderName] = {
        level = tonumber(lvlStr) or 0,
        mapID = tonumber(mapStr) or 0,
        rating = tonumber(ratingStr) or 0,
    }
    EmitUpdated()
end

local function EnableRuntime()
    if active or not IsSupported() then return false end
    active = true
    SafeCall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)

    if YUI.Event and YUI.Event.On then
        if YUI.Event.OffOwner then
            YUI.Event:OffOwner(Keystone)
        end
        YUI.Event:On("CHAT_MSG_ADDON", OnKeystoneEvent, Keystone)
        YUI.Event:On("GROUP_ROSTER_UPDATE", OnKeystoneEvent, Keystone, {
            moduleId = "core:Keystone",
            traceName = "Core:Keystone:GROUP_ROSTER_UPDATE",
        })
    end
    return true
end

local function DisableRuntime()
    if not active then return end
    active = false
    if YUI.Event and YUI.Event.OffOwner then
        YUI.Event:OffOwner(Keystone)
    end
    wipe(partyKeystones)
    EmitUpdated()
end

function Keystone.Activate(owner)
    if not owner then return false end
    if not consumers[owner] then
        consumers[owner] = true
        consumerCount = consumerCount + 1
    end
    return EnableRuntime()
end

function Keystone.Deactivate(owner)
    if owner and consumers[owner] then
        consumers[owner] = nil
        consumerCount = math.max(0, consumerCount - 1)
    end
    if consumerCount <= 0 then
        DisableRuntime()
    end
end

function Keystone.IsActive()
    return active == true
end

-- Shared presentation colors for Retail Mythic+ consumers. These return the
-- Blizzard-owned color object when available and nil for unsafe/invalid input.
function Keystone.GetKeystoneLevelColor(level)
    if YUI.IsRetail ~= true then return nil end
    level = NormalizeNumber(level)
    if not level or level <= 0 then return nil end

    local quality
    if level >= 12 then
        quality = 5
    elseif level >= 9 then
        quality = 4
    elseif level >= 4 then
        quality = 3
    else
        quality = 2
    end

    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color == nil or IsSecretValue(color) then return nil end
    return color
end

function Keystone.GetSpecificDungeonScoreColor(score)
    score = NormalizeNumber(score)
    if not score or score <= 0 then return nil end
    if not (YUI.IsRetail == true and C_ChallengeMode and C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor) then
        return nil
    end

    local color = SafeCall(C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor, score)
    if color == nil or IsSecretValue(color) then return nil end
    return color
end

-- Cold-path normalized view for player unit tooltips and inspection summaries.
-- Returns nil when unsupported or unreadable; callers own the returned tables.
function Keystone.GetPlayerRatingSummary(unit)
    if not YUI.IsRetail or type(unit) ~= "string" or IsSecretValue(unit) or unit == "" then
        return nil
    end
    if not (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then
        return nil
    end

    local raw = SafeCall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
    if type(raw) ~= "table" or IsSecretValue(raw) then return nil end

    local score = NormalizeNumber(ReadSafeField(raw, "currentSeasonScore")) or 0
    local result = { score = score, runs = {} }
    local rawRuns = ReadSafeField(raw, "runs")
    if type(rawRuns) ~= "table" or IsSecretValue(rawRuns) then
        return result
    end

    local ok = pcall(function()
        for _, run in ipairs(rawRuns) do
            if type(run) == "table" and not IsSecretValue(run) then
                local mapID = NormalizeNumber(ReadSafeField(run, "challengeModeID"))
                local level = NormalizeNumber(ReadSafeField(run, "bestRunLevel"))
                if mapID and mapID > 0 and level and level >= 0 then
                    local finishedSuccess = ReadSafeField(run, "finishedSuccess")
                    result.runs[#result.runs + 1] = {
                        mapID = math.floor(mapID),
                        mapScore = NormalizeNumber(ReadSafeField(run, "mapScore")) or 0,
                        level = math.floor(level),
                        durationMS = NormalizeNumber(ReadSafeField(run, "bestRunDurationMS")) or 0,
                        timed = finishedSuccess == true,
                    }
                end
            end
        end
    end)
    if not ok then
        result.runs = {}
    end
    return result
end

-- Returns the current official challenge-map order. Non-Retail and unavailable
-- data use an empty table so cross-version consumers do not need branches.
function Keystone.GetCurrentSeasonMaps()
    local result = {}
    if not YUI.IsRetail or not (C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapUIInfo) then
        return result
    end

    local mapIDs = SafeCall(C_ChallengeMode.GetMapTable)
    if type(mapIDs) ~= "table" or IsSecretValue(mapIDs) then return result end

    local ok = pcall(function()
        for _, rawMapID in ipairs(mapIDs) do
            local mapID = NormalizeNumber(rawMapID)
            if mapID and mapID > 0 then
                local name, _, _, texture = SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
                if type(name) == "string" and name ~= "" and not IsSecretValue(name) then
                    if IsSecretValue(texture) then texture = nil end
                    result[#result + 1] = {
                        mapID = math.floor(mapID),
                        name = name,
                        texture = texture,
                    }
                end
            end
        end
    end)
    if not ok then return {} end
    return result
end

function Keystone.GetPlayerKeystone()
    local level = 0
    local mapID = 0
    local link = nil

    if not YUI.IsRetail then
        return {
            level = level,
            mapID = mapID,
            rating = 0,
            link = link,
        }
    end

    if C_MythicPlus then
        level = tonumber(C_MythicPlus.GetOwnedKeystoneLevel and SafeCall(C_MythicPlus.GetOwnedKeystoneLevel)) or 0
        mapID = tonumber(C_MythicPlus.GetOwnedKeystoneChallengeMapID and SafeCall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)) or 0
    end

    local isTimerunning = PlayerIsTimerunning and PlayerIsTimerunning()
    if (level == 0 or mapID == 0 or isTimerunning) and C_Container then
        local itemAPI = YUI.API and YUI.API.Item
        for bag = 0, NUM_BAG_SLOTS do
            local slots = tonumber(SafeCall(C_Container.GetContainerNumSlots, bag)) or 0
            for slot = 1, slots do
                local itemID = SafeCall(C_Container.GetContainerItemID, bag, slot)
                if itemID and itemAPI and itemAPI.IsKeystoneByID and itemAPI.IsKeystoneByID(itemID) then
                    local itemLink = SafeCall(C_Container.GetContainerItemLink, bag, slot)
                    if itemLink then
                        link = itemLink
                        local _, _, _, strMapID, strLevel = string.split(":", itemLink)
                        local parsedMapID = tonumber(strMapID)
                        local parsedLevel = tonumber(strLevel)
                        if parsedMapID and parsedLevel then
                            mapID = parsedMapID
                            level = parsedLevel
                        end
                        break
                    end
                end
            end
            if link then break end
        end
    end

    local rating = 0
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local ratingSummary = SafeCall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
        rating = NormalizeNumber(ReadSafeField(ratingSummary, "currentSeasonScore")) or 0
    end

    return {
        level = level,
        mapID = mapID,
        rating = rating,
        link = link,
    }
end

function Keystone.GetPartyKeystone(name)
    if not name then return nil end
    local key = Ambiguate and Ambiguate(name, "none") or name
    return partyKeystones[key]
end

local function IsDisplayablePartyUnit(unit)
    if not unit or IsSecretValue(unit) then return false end
    if UnitIsPlayer then
        return UnitIsPlayer(unit) and true or false
    end
    return true
end

function Keystone.GetPartyKeystoneRows()
    if not YUI.IsRetail then return {} end

    local rows = {}
    local pName = UnitName and UnitName("player") or PLAYER
    local player = Keystone.GetPlayerKeystone()
    rows[#rows + 1] = {
        unit = "player",
        name = pName,
        isPlayer = true,
        level = player.level,
        mapID = player.mapID,
        rating = player.rating,
        link = player.link,
        mapName = player.mapID and player.mapID > 0 and GetMapName(player.mapID) or nil,
        status = (player.level > 0 and player.mapID > 0) and "ready" or "none",
    }

    if IsInGroup and IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists and UnitExists(unit) and IsDisplayablePartyUnit(unit) then
                local unitName = GetUnitName and GetUnitName(unit, true) or UnitName(unit)
                local data = Keystone.GetPartyKeystone(unitName)
                rows[#rows + 1] = {
                    unit = unit,
                    name = unitName,
                    isPlayer = false,
                    level = data and data.level or 0,
                    mapID = data and data.mapID or 0,
                    rating = data and data.rating or 0,
                    mapName = data and data.mapID and data.mapID > 0 and GetMapName(data.mapID) or nil,
                    status = (data and data.level and data.level > 0 and data.mapID and data.mapID > 0) and "ready" or "loading",
                }
            end
        end
    end

    return rows
end

function Keystone.RequestPartyKeystones(force)
    if not (IsSupported() and IsInGroup and IsInGroup()) then return false end
    local now = GetTimeSafe()
    if not force and now - lastRequestTime < REQUEST_COOLDOWN then return false end
    lastRequestTime = now
    return SendAddonMessage("R")
end

function Keystone.ReportPartyKeystones()
    if isReporting or not (IsInGroup and IsInGroup()) then return false end
    isReporting = true

    local messages = {}
    messages[#messages + 1] = "----------"

    for _, row in ipairs(Keystone.GetPartyKeystoneRows()) do
        if row.status == "ready" and row.level and row.level > 0 and row.mapID and row.mapID > 0 then
            if row.isPlayer and row.link then
                messages[#messages + 1] = string.format("%s: %s", row.name or "", row.link)
            else
                messages[#messages + 1] = string.format("%s: %s (%d)", row.name or "", row.mapName or UNKNOWN or tostring(row.mapID), row.level)
            end
        end
    end

    messages[#messages + 1] = "----------"

    for index, message in ipairs(messages) do
        if C_Timer and C_Timer.After then
            C_Timer.After((index - 1) * SEND_MESSAGE_DELAY, function()
                SendChatMessage(message, "PARTY")
            end)
        elseif SendChatMessage then
            SendChatMessage(message, "PARTY")
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(#messages * SEND_MESSAGE_DELAY, function()
            isReporting = false
        end)
    else
        isReporting = false
    end

    return true
end

function Keystone.ClearPartyKeystones()
    wipe(partyKeystones)
    EmitUpdated()
end

Legacy.Keystone = Keystone
