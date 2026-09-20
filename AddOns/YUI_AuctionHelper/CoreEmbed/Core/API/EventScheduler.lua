do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

if not YUI or not YUI.IsRetail then return end

YUI.API = YUI.API or {}

local EventScheduler = YUI.API.EventScheduler or {}
YUI.API.EventScheduler = EventScheduler
local WorldQuest = YUI.API.WorldQuest or {}
YUI.API.WorldQuest = WorldQuest

local Security = YUI.API.Security

local function IsSecret(value)
    if Security and type(Security.IsSecretValue) == "function" then
        local ok, result = pcall(Security.IsSecretValue, value)
        if ok then return result == true end
    end
    if type(issecretvalue) == "function" then
        local ok, result = pcall(issecretvalue, value)
        if ok then return result == true end
    end
    return false
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return false end
    local results = { pcall(fn, ...) }
    if not results[1] then return false end
    return true, unpack(results, 2)
end

local function SafeSecureCall(fn, ...)
    if type(fn) ~= "function" then return false end
    if Security and type(Security.SecureCallFunction) == "function" then
        return SafeCall(Security.SecureCallFunction, fn, ...)
    end
    if type(securecallfunction) == "function" then
        return SafeCall(securecallfunction, fn, ...)
    end
    return SafeCall(fn, ...)
end

local function SafeField(value, key)
    if type(value) ~= "table" or IsSecret(value) then return nil, false end
    local ok, result = pcall(function() return value[key] end)
    if not ok or IsSecret(result) then return nil, false end
    return result, true
end

local function SafeNumber(value, minimum)
    if type(value) ~= "number" or IsSecret(value) then return nil end
    if value ~= value or value == math.huge or value == -math.huge then return nil end
    if minimum ~= nil and value < minimum then return nil end
    return value
end

local function SafeInteger(value, minimum)
    value = SafeNumber(value, minimum)
    if not value then return nil end
    return math.floor(value)
end

local function SafeString(value)
    if type(value) ~= "string" or IsSecret(value) or value == "" then return nil end
    return value
end

local function SafeBoolean(value, readable)
    if not readable or IsSecret(value) then return nil end
    if value == true then return true end
    if value == false then return false end
    return nil
end

local function ResetTable(value)
    if type(value) ~= "table" then return {} end
    for key in pairs(value) do value[key] = nil end
    return value
end

local function NormalizeDisplayInfo(raw, reuse)
    local display = ResetTable(reuse)
    if type(raw) ~= "table" or IsSecret(raw) then
        display.restricted = true
        display.hideTimeLeft = true
        display.hideDescription = true
        return display
    end

    local hideTimeLeft, timeReadable = SafeField(raw, "hideTimeLeft")
    local hideDescription, descriptionReadable = SafeField(raw, "hideDescription")
    display.restricted = not timeReadable or not descriptionReadable
    display.hideTimeLeft = display.restricted or hideTimeLeft == true
    display.hideDescription = display.restricted or hideDescription == true
    display.overrideAtlas = SafeString(select(1, SafeField(raw, "overrideAtlas")))
    display.overrideTooltipWidgetSetID = SafeInteger(
        select(1, SafeField(raw, "overrideTooltipWidgetSetID")),
        0
    )
    return display
end

local function NormalizeEvent(raw, kind, reuse)
    if type(raw) ~= "table" or IsSecret(raw) then return nil end

    local areaPoiID = SafeInteger(select(1, SafeField(raw, "areaPoiID")), 1)
    if not areaPoiID then return nil end

    local event = ResetTable(reuse)
    event.kind = kind
    event.areaPoiID = areaPoiID
    event.eventKey = SafeString(select(1, SafeField(raw, "eventKey")))
    event.eventID = SafeInteger(select(1, SafeField(raw, "eventID")), 0)
    event.startTime = SafeNumber(select(1, SafeField(raw, "startTime")), 0)
    event.endTime = SafeNumber(select(1, SafeField(raw, "endTime")), 0)
    event.duration = SafeNumber(select(1, SafeField(raw, "duration")), 0)

    local rewardsClaimed, rewardsReadable = SafeField(raw, "rewardsClaimed")
    local hasReminder, reminderReadable = SafeField(raw, "hasReminder")
    event.rewardsClaimed = SafeBoolean(rewardsClaimed, rewardsReadable)
    event.hasReminder = SafeBoolean(hasReminder, reminderReadable)

    local rawDisplay = select(1, SafeField(raw, "displayInfo"))
    event.displayInfo = NormalizeDisplayInfo(rawDisplay, event.displayInfo)
    return event
end

local function NormalizeList(raw, kind, reuse)
    local output = type(reuse) == "table" and reuse or {}
    local count = 0
    if type(raw) == "table" and not IsSecret(raw) then
        pcall(function()
            for _, rawEvent in ipairs(raw) do
                local nextIndex = count + 1
                local event = NormalizeEvent(rawEvent, kind, output[nextIndex])
                if event then
                    count = nextIndex
                    output[count] = event
                end
            end
        end)
    end
    for index = count + 1, #output do output[index] = nil end
    return output
end

function EventScheduler.IsAvailable()
    local api = C_EventScheduler
    return YUI.IsRetail == true
        and type(api) == "table"
        and type(api.RequestEvents) == "function"
        and type(api.GetOngoingEvents) == "function"
        and type(api.GetScheduledEvents) == "function"
        and type(api.HasData) == "function"
end

function EventScheduler.RequestEvents()
    if not EventScheduler.IsAvailable() then return false, "unsupported" end
    local ok = SafeCall(C_EventScheduler.RequestEvents)
    if not ok then return false, "api_error" end
    return true
end

function EventScheduler.GetSnapshot(reuse)
    local snapshot = type(reuse) == "table" and reuse or {}
    snapshot.ongoing = type(snapshot.ongoing) == "table" and snapshot.ongoing or {}
    snapshot.scheduled = type(snapshot.scheduled) == "table" and snapshot.scheduled or {}
    snapshot.canShow = nil
    snapshot.activeContinentName = nil

    if not EventScheduler.IsAvailable() then
        snapshot.status = "unsupported"
        NormalizeList(nil, "ongoing", snapshot.ongoing)
        NormalizeList(nil, "scheduled", snapshot.scheduled)
        return snapshot
    end

    local canShowOk, canShow = SafeCall(C_EventScheduler.CanShowEvents)
    if canShowOk and not IsSecret(canShow) and type(canShow) == "boolean" then
        snapshot.canShow = canShow
    end

    local continentOk, continentName = SafeCall(C_EventScheduler.GetActiveContinentName)
    if continentOk then snapshot.activeContinentName = SafeString(continentName) end

    local hasDataOk, hasData = SafeCall(C_EventScheduler.HasData)
    local ongoingOk, ongoing = SafeCall(C_EventScheduler.GetOngoingEvents)
    local scheduledOk, scheduled = SafeCall(C_EventScheduler.GetScheduledEvents)
    snapshot.status = hasDataOk and hasData == true and "ready" or "loading"
    if not ongoingOk then ongoing = nil end
    if not scheduledOk then scheduled = nil end
    snapshot.ongoing = NormalizeList(ongoing, "ongoing", snapshot.ongoing)
    snapshot.scheduled = NormalizeList(scheduled, "scheduled", snapshot.scheduled)
    return snapshot
end

local function NormalizeAreaPoiID(areaPoiID)
    return SafeInteger(areaPoiID, 1)
end

local function NormalizeNavigationLocation(areaPoiID, raw)
    if type(raw) ~= "table" or IsSecret(raw) then return nil, "invalid_location" end
    local rawAreaPoiID = SafeInteger(select(1, SafeField(raw, "areaPoiID")), 1)
    if rawAreaPoiID and rawAreaPoiID ~= areaPoiID then return nil, "invalid_location" end

    local uiMapID = SafeInteger(select(1, SafeField(raw, "uiMapID")), 1)
        or SafeInteger(select(1, SafeField(raw, "linkedUiMapID")), 1)
    local x = SafeNumber(select(1, SafeField(raw, "positionX")), 0)
    local y = SafeNumber(select(1, SafeField(raw, "positionY")), 0)
    if not uiMapID or not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1 then
        return nil, "invalid_location"
    end
    return {
        areaPoiID = areaPoiID,
        uiMapID = uiMapID,
        positionX = x,
        positionY = y,
    }
end

local function NormalizePosition(position)
    if position == nil or IsSecret(position) then return nil, nil end

    local x = SafeNumber(select(1, SafeField(position, "x")), 0)
    local y = SafeNumber(select(1, SafeField(position, "y")), 0)
    if not x or not y then
        local methodOk, getXY = pcall(function() return position.GetXY end)
        local xyOk
        if methodOk then xyOk, x, y = SafeCall(getXY, position) end
        if xyOk ~= true then return nil, nil end
        x = SafeNumber(x, 0)
        y = SafeNumber(y, 0)
    end
    if not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1 then return nil, nil end
    return x, y
end

function EventScheduler.GetEventLocation(areaPoiID)
    areaPoiID = NormalizeAreaPoiID(areaPoiID)
    if not areaPoiID then return nil, "invalid_area_poi" end
    if not EventScheduler.IsAvailable()
        or type(C_AreaPoiInfo) ~= "table"
        or type(C_AreaPoiInfo.GetAreaPOIInfo) ~= "function"
    then
        return nil, "unsupported"
    end

    local mapOk, uiMapID = SafeCall(C_EventScheduler.GetEventUiMapID, areaPoiID)
    uiMapID = mapOk and SafeInteger(uiMapID, 1) or nil
    local poiOk, poiInfo = SafeCall(C_AreaPoiInfo.GetAreaPOIInfo, uiMapID, areaPoiID)
    if (not poiOk or type(poiInfo) ~= "table") and uiMapID ~= nil then
        poiOk, poiInfo = SafeCall(C_AreaPoiInfo.GetAreaPOIInfo, nil, areaPoiID)
    end
    if not poiOk or type(poiInfo) ~= "table" or IsSecret(poiInfo) then
        return nil, "map_unavailable"
    end

    local location = {
        areaPoiID = areaPoiID,
        uiMapID = uiMapID,
        linkedUiMapID = SafeInteger(select(1, SafeField(poiInfo, "linkedUiMapID")), 1),
        name = SafeString(select(1, SafeField(poiInfo, "name"))),
        description = SafeString(select(1, SafeField(poiInfo, "description"))),
        atlasName = SafeString(select(1, SafeField(poiInfo, "atlasName"))),
        tooltipWidgetSet = SafeInteger(select(1, SafeField(poiInfo, "tooltipWidgetSet")), 0),
        iconWidgetSet = SafeInteger(select(1, SafeField(poiInfo, "iconWidgetSet")), 0),
    }

    local zoneOk, zoneName = SafeCall(C_EventScheduler.GetEventZoneName, areaPoiID)
    location.zoneName = zoneOk and SafeString(zoneName) or nil

    local position = select(1, SafeField(poiInfo, "position"))
    location.positionX, location.positionY = NormalizePosition(position)

    if type(C_AreaPoiInfo.GetAreaPOISecondsLeft) == "function" then
        local secondsOk, secondsLeft = SafeCall(C_AreaPoiInfo.GetAreaPOISecondsLeft, areaPoiID)
        location.secondsLeft = secondsOk and SafeNumber(secondsLeft, 0) or nil
    end

    return location
end

function EventScheduler.OpenEvent(areaPoiID, navigationLocation)
    areaPoiID = NormalizeAreaPoiID(areaPoiID)
    if not areaPoiID then return false, "invalid_area_poi" end
    if not EventScheduler.IsAvailable() then return false, "unsupported" end

    local location, locationReason
    if navigationLocation ~= nil then
        location, locationReason = NormalizeNavigationLocation(areaPoiID, navigationLocation)
        if not location then return false, locationReason end
    else
        location = EventScheduler.GetEventLocation(areaPoiID)
    end
    local uiMapID = location and (location.uiMapID or location.linkedUiMapID) or nil

    if uiMapID and location.positionX and location.positionY then
        local opened = false
        if type(OpenWorldMap) == "function" then
            opened = SafeSecureCall(OpenWorldMap, uiMapID)
        elseif WorldMapFrame and type(WorldMapFrame.HandleUserActionOpenSelf) == "function" then
            opened = SafeSecureCall(WorldMapFrame.HandleUserActionOpenSelf, WorldMapFrame, uiMapID)
        end
        if not opened then return false, "map_unavailable" end
        return true, nil, location
    end

    if type(OpenMapToEventPoi) == "function" then
        local ok = SafeSecureCall(OpenMapToEventPoi, areaPoiID)
        if ok then return true, nil, location end
        return false, "api_error"
    end

    if EventRegistry and type(EventRegistry.TriggerEvent) == "function" then
        SafeCall(EventRegistry.TriggerEvent, EventRegistry, "PingAreaPOIEvent", areaPoiID)
    end
    return false, "map_unavailable"
end

function EventScheduler.GetUserWaypoint()
    if type(C_Map) ~= "table" or type(C_Map.GetUserWaypoint) ~= "function" then
        return nil, "unsupported"
    end

    local ok, point = SafeCall(C_Map.GetUserWaypoint)
    if not ok then return nil, "api_error" end
    if point == nil then return nil end
    if type(point) ~= "table" or IsSecret(point) then return nil, "api_error" end

    local uiMapID = SafeInteger(select(1, SafeField(point, "uiMapID")), 1)
    local position = select(1, SafeField(point, "position"))
    local x, y = NormalizePosition(position)
    if not uiMapID or not x or not y then return nil, "api_error" end
    return {
        uiMapID = uiMapID,
        positionX = x,
        positionY = y,
    }
end

function EventScheduler.ToggleEventWaypoint(areaPoiID, navigationLocation)
    areaPoiID = NormalizeAreaPoiID(areaPoiID)
    if not areaPoiID then return false, nil, "invalid_area_poi" end
    if type(C_Map) ~= "table"
        or type(C_Map.CanSetUserWaypointOnMap) ~= "function"
        or type(C_Map.GetUserWaypoint) ~= "function"
        or type(C_Map.SetUserWaypoint) ~= "function"
        or type(C_Map.ClearUserWaypoint) ~= "function"
        or type(UiMapPoint) ~= "table"
        or type(UiMapPoint.CreateFromCoordinates) ~= "function"
    then
        return false, nil, "unsupported"
    end

    local location, locationReason
    if navigationLocation ~= nil then
        location, locationReason = NormalizeNavigationLocation(areaPoiID, navigationLocation)
    else
        location, locationReason = EventScheduler.GetEventLocation(areaPoiID)
    end
    if not location then return false, nil, locationReason or "map_unavailable" end
    local uiMapID = location.uiMapID or location.linkedUiMapID
    local x, y = location.positionX, location.positionY
    if not uiMapID or type(x) ~= "number" or type(y) ~= "number" then
        return false, nil, "map_unavailable"
    end

    local current, currentReason = EventScheduler.GetUserWaypoint()
    if currentReason then return false, nil, currentReason end
    if current and current.uiMapID == uiMapID
        and math.abs(current.positionX - x) <= 0.0001
        and math.abs(current.positionY - y) <= 0.0001
    then
        if not SafeCall(C_Map.ClearUserWaypoint) then return false, nil, "api_error" end
        if type(C_SuperTrack) == "table"
            and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function"
        then
            SafeCall(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
        end
        return true, false
    end

    local allowedOk, allowed = SafeCall(C_Map.CanSetUserWaypointOnMap, uiMapID)
    if not allowedOk then return false, nil, "api_error" end
    if IsSecret(allowed) then return false, nil, "api_error" end
    if allowed ~= true then return false, nil, "waypoint_unavailable" end

    local pointOk, point = SafeCall(UiMapPoint.CreateFromCoordinates, uiMapID, x, y)
    if not pointOk or type(point) ~= "table" or IsSecret(point) then
        return false, nil, "api_error"
    end
    local setOk, wasSet = SafeCall(C_Map.SetUserWaypoint, point)
    if not setOk then return false, nil, "api_error" end
    if IsSecret(wasSet) then return false, nil, "api_error" end
    if wasSet ~= true then return false, nil, "waypoint_unavailable" end
    if type(C_SuperTrack) == "table"
        and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function"
    then
        SafeCall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return true, true
end

local function NormalizeWorldQuestLocation(questID, raw)
    if type(raw) ~= "table" or IsSecret(raw) then return nil, "invalid_location" end
    local rawQuestID = SafeInteger(select(1, SafeField(raw, "questID")), 1)
    if rawQuestID and rawQuestID ~= questID then return nil, "invalid_location" end

    local uiMapID = SafeInteger(select(1, SafeField(raw, "uiMapID")), 1)
        or SafeInteger(select(1, SafeField(raw, "linkedUiMapID")), 1)
    local x = SafeNumber(select(1, SafeField(raw, "positionX")), 0)
    local y = SafeNumber(select(1, SafeField(raw, "positionY")), 0)
    if not uiMapID or not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1 then
        return nil, "invalid_location"
    end
    return {
        questID = questID,
        uiMapID = uiMapID,
        positionX = x,
        positionY = y,
    }
end

local function IsWorldQuestAvailable()
    return YUI.IsRetail == true
        and type(C_Map) == "table"
        and type(C_Map.GetMapInfo) == "function"
        and type(C_Map.GetMapChildrenInfo) == "function"
        and type(C_TaskQuest) == "table"
        and type(C_TaskQuest.GetQuestsOnMap) == "function"
        and type(C_QuestLog) == "table"
        and type(C_QuestLog.GetQuestTagInfo) == "function"
end

local function GetMapInfo(mapID)
    local ok, info = SafeCall(C_Map and C_Map.GetMapInfo, mapID)
    if not ok or type(info) ~= "table" or IsSecret(info) then return nil end
    local normalizedID = SafeInteger(select(1, SafeField(info, "mapID")), 1)
    local mapType = SafeInteger(select(1, SafeField(info, "mapType")), 0)
    if not normalizedID or not mapType then return nil end
    return {
        mapID = normalizedID,
        mapType = mapType,
        parentMapID = SafeInteger(select(1, SafeField(info, "parentMapID")), 0),
        name = SafeString(select(1, SafeField(info, "name"))),
    }
end

local function GetContinentMapInfo(mapID)
    local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent
    if type(continentType) ~= "number" then return nil end
    local info = GetMapInfo(mapID)
    local iterations = 0
    while info and iterations < 32 do
        if info.mapType == continentType then return info end
        if not info.parentMapID or info.parentMapID < 1 or info.parentMapID == info.mapID then return nil end
        info = GetMapInfo(info.parentMapID)
        iterations = iterations + 1
    end
end

local function IsWorldBossTask(taskType, tagInfo)
    local tagTypes = Enum and Enum.QuestTagType
    if type(tagTypes) ~= "table" then return false end
    local worldQuestType = SafeInteger(select(1, SafeField(tagInfo, "worldQuestType")), 0)
    local effectiveType = taskType or worldQuestType
    if effectiveType == tagTypes.WorldBoss then return true end

    local quality = SafeInteger(select(1, SafeField(tagInfo, "quality")), 0)
    local isElite = select(1, SafeField(tagInfo, "isElite")) == true
    local epicQuality = Enum and Enum.WorldQuestQuality and Enum.WorldQuestQuality.Epic
    return effectiveType == tagTypes.Normal and isElite and quality == epicQuality
end

local function NormalizeWorldBossTask(task, mapID, mapName, now, reuse)
    if type(task) ~= "table" or IsSecret(task) then return nil end
    local questID = SafeInteger(select(1, SafeField(task, "questID")), 1)
    if not questID then return nil end

    local tagTypes = Enum and Enum.QuestTagType
    if type(tagTypes) ~= "table" then return nil end
    local taskType = SafeInteger(select(1, SafeField(task, "questTagType")), 0)
    if taskType and taskType ~= tagTypes.WorldBoss and taskType ~= tagTypes.Normal then return nil end
    local tagInfo
    if taskType ~= tagTypes.WorldBoss then
        local tagOk, rawTagInfo = SafeCall(C_QuestLog.GetQuestTagInfo, questID)
        if tagOk and type(rawTagInfo) == "table" and not IsSecret(rawTagInfo) then tagInfo = rawTagInfo end
    end
    if not IsWorldBossTask(taskType, tagInfo) then return nil end

    local taskMapID = SafeInteger(select(1, SafeField(task, "mapID")), 1) or mapID
    local taskMapInfo = GetMapInfo(taskMapID)
    local x = SafeNumber(select(1, SafeField(task, "x")), 0)
    local y = SafeNumber(select(1, SafeField(task, "y")), 0)
    if not x or not y or x <= 0 or y <= 0 or x >= 1 or y >= 1 then x, y = nil, nil end

    local titleOk, title = SafeCall(C_TaskQuest.GetQuestInfoByQuestID, questID)
    title = titleOk and SafeString(title) or nil
    if not title and type(C_QuestLog.RequestLoadQuestByID) == "function" then
        SafeCall(C_QuestLog.RequestLoadQuestByID, questID)
    end

    local secondsLeft
    if type(C_TaskQuest.GetQuestTimeLeftSeconds) == "function" then
        local secondsOk, seconds = SafeCall(C_TaskQuest.GetQuestTimeLeftSeconds, questID)
        secondsLeft = secondsOk and SafeNumber(seconds, 0) or nil
    end
    if not secondsLeft and type(C_TaskQuest.GetQuestTimeLeftMinutes) == "function" then
        local minutesOk, minutes = SafeCall(C_TaskQuest.GetQuestTimeLeftMinutes, questID)
        minutes = minutesOk and SafeNumber(minutes, 0) or nil
        secondsLeft = minutes and minutes * 60 or nil
    end

    local completedOk, completed = SafeCall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    local boss = ResetTable(reuse)
    boss.source = "worldBoss"
    boss.kind = "ongoing"
    boss.questID = questID
    boss.rewardsClaimed = completedOk and not IsSecret(completed) and completed == true or false
    boss.startTime = nil
    boss.endTime = secondsLeft and now + secondsLeft or nil
    boss.displayInfo = ResetTable(boss.displayInfo)
    boss.displayInfo.overrideAtlas = "worldquest-icon-boss"
    boss.displayInfo.hideTimeLeft = secondsLeft == nil
    boss.displayInfo.hideDescription = true
    boss.location = ResetTable(boss.location)
    boss.location.questID = questID
    boss.location.uiMapID = taskMapID
    boss.location.positionX = x
    boss.location.positionY = y
    boss.location.name = title
    boss.location.zoneName = taskMapInfo and taskMapInfo.name or mapName
    boss.location.atlasName = "worldquest-icon-boss"
    return boss
end

local function ResetWorldBossSnapshot(reuse)
    local snapshot = type(reuse) == "table" and reuse or {}
    snapshot.bosses = type(snapshot.bosses) == "table" and snapshot.bosses or {}
    snapshot._seenQuestIDs = ResetTable(snapshot._seenQuestIDs)
    snapshot._seenMapIDs = ResetTable(snapshot._seenMapIDs)
    snapshot._seenScanMapIDs = type(snapshot._seenScanMapIDs) == "table" and snapshot._seenScanMapIDs or {}
    snapshot._continentBySeedMapID = type(snapshot._continentBySeedMapID) == "table"
        and snapshot._continentBySeedMapID or {}
    snapshot._roots = type(snapshot._roots) == "table" and snapshot._roots or {}
    snapshot._cachedRootIDs = type(snapshot._cachedRootIDs) == "table" and snapshot._cachedRootIDs or {}
    snapshot._scanMaps = type(snapshot._scanMaps) == "table" and snapshot._scanMaps or {}
    snapshot._rootCount = 0
    snapshot.status = "unavailable"
    return snapshot
end

local function GetContinentMapInfoCached(snapshot, mapID)
    local cached = snapshot._continentBySeedMapID[mapID]
    if type(cached) == "table" then return cached end
    local continent = GetContinentMapInfo(mapID)
    if continent then snapshot._continentBySeedMapID[mapID] = continent end
    return continent
end

local function AcquireScanMap(snapshot, mapID, name)
    local index = snapshot._scanMapCount + 1
    snapshot._scanMapCount = index
    local info = snapshot._scanMaps[index]
    if type(info) ~= "table" then
        info = {}
        snapshot._scanMaps[index] = info
    end
    info.mapID = mapID
    info.name = name
end

local function RefreshScanMaps(snapshot)
    local rootsChanged = type(snapshot._scanMapCount) ~= "number"
        or snapshot._rootCount ~= #snapshot._cachedRootIDs
    if not rootsChanged then
        for index = 1, snapshot._rootCount do
            if snapshot._cachedRootIDs[index] ~= snapshot._roots[index].mapID then
                rootsChanged = true
                break
            end
        end
    end
    if not rootsChanged then return end

    snapshot._scanMapCount = 0
    ResetTable(snapshot._seenScanMapIDs)
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    for rootIndex = 1, snapshot._rootCount do
        local root = snapshot._roots[rootIndex]
        if not snapshot._seenScanMapIDs[root.mapID] then
            snapshot._seenScanMapIDs[root.mapID] = true
            AcquireScanMap(snapshot, root.mapID, root.name)
        end
        local childrenOk, children = SafeCall(C_Map.GetMapChildrenInfo, root.mapID, zoneType, true)
        if childrenOk and type(children) == "table" and not IsSecret(children) then
            for childIndex = 1, #children do
                local child = children[childIndex]
                local childID = SafeInteger(select(1, SafeField(child, "mapID")), 1)
                if childID and not snapshot._seenScanMapIDs[childID] then
                    snapshot._seenScanMapIDs[childID] = true
                    AcquireScanMap(snapshot, childID, SafeString(select(1, SafeField(child, "name"))))
                end
            end
        end
    end
    for index = snapshot._scanMapCount + 1, #snapshot._scanMaps do
        local info = snapshot._scanMaps[index]
        if type(info) == "table" then info.mapID, info.name = nil, nil end
    end
    for index = 1, snapshot._rootCount do snapshot._cachedRootIDs[index] = snapshot._roots[index].mapID end
    for index = snapshot._rootCount + 1, #snapshot._cachedRootIDs do snapshot._cachedRootIDs[index] = nil end
end

function WorldQuest.IsAvailable()
    return IsWorldQuestAvailable()
end

function WorldQuest.GetWorldBossSnapshot(seedMapIDs, activeContinentName, now, reuse)
    local snapshot = ResetWorldBossSnapshot(reuse)
    if not IsWorldQuestAvailable() then
        for index = #snapshot.bosses, 1, -1 do snapshot.bosses[index] = nil end
        snapshot.status = "unsupported"
        return snapshot
    end

    now = SafeNumber(now, 0) or (type(GetServerTime) == "function" and GetServerTime() or 0)
    activeContinentName = SafeString(activeContinentName)
    local matchedActiveName = false
    if type(seedMapIDs) == "table" and not IsSecret(seedMapIDs) then
        for index = 1, #seedMapIDs do
            local mapID = SafeInteger(seedMapIDs[index], 1)
            local continent = mapID and GetContinentMapInfoCached(snapshot, mapID) or nil
            if continent and not snapshot._seenMapIDs[continent.mapID] then
                local nameMatches = activeContinentName and continent.name == activeContinentName
                if not activeContinentName or nameMatches then
                    snapshot._rootCount = snapshot._rootCount + 1
                    snapshot._roots[snapshot._rootCount] = continent
                    snapshot._seenMapIDs[continent.mapID] = true
                    matchedActiveName = matchedActiveName or nameMatches == true
                end
            end
        end
    end

    if activeContinentName and not matchedActiveName then
        snapshot._rootCount = 0
        ResetTable(snapshot._seenMapIDs)
        if type(seedMapIDs) == "table" and not IsSecret(seedMapIDs) then
            for index = 1, #seedMapIDs do
                local mapID = SafeInteger(seedMapIDs[index], 1)
                local continent = mapID and GetContinentMapInfoCached(snapshot, mapID) or nil
                if continent and not snapshot._seenMapIDs[continent.mapID] then
                    snapshot._rootCount = snapshot._rootCount + 1
                    snapshot._roots[snapshot._rootCount] = continent
                    snapshot._seenMapIDs[continent.mapID] = true
                end
            end
        end
    end
    for index = snapshot._rootCount + 1, #snapshot._roots do snapshot._roots[index] = nil end

    RefreshScanMaps(snapshot)
    local bossCount = 0
    for mapIndex = 1, snapshot._scanMapCount do
        local mapInfo = snapshot._scanMaps[mapIndex]
        local tasksOk, tasks = SafeCall(C_TaskQuest.GetQuestsOnMap, mapInfo.mapID)
        if tasksOk and type(tasks) == "table" and not IsSecret(tasks) then
            for taskIndex = 1, #tasks do
                local questID = SafeInteger(select(1, SafeField(tasks[taskIndex], "questID")), 1)
                if questID and not snapshot._seenQuestIDs[questID] then
                    snapshot._seenQuestIDs[questID] = true
                    local nextBoss = NormalizeWorldBossTask(
                        tasks[taskIndex], mapInfo.mapID, mapInfo.name, now, snapshot.bosses[bossCount + 1]
                    )
                    if nextBoss then
                        bossCount = bossCount + 1
                        snapshot.bosses[bossCount] = nextBoss
                    end
                end
            end
        end
    end
    for index = bossCount + 1, #snapshot.bosses do snapshot.bosses[index] = nil end
    snapshot.status = snapshot._rootCount > 0 and "ready" or "unavailable"
    return snapshot
end

function WorldQuest.GetTrackedQuestID()
    if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.GetSuperTrackedQuestID) ~= "function" then
        return nil, "unsupported"
    end
    local ok, questID = SafeCall(C_SuperTrack.GetSuperTrackedQuestID)
    if not ok then return nil, "api_error" end
    if IsSecret(questID) then return nil, "api_error" end
    return SafeInteger(questID, 1)
end

function WorldQuest.ToggleTrackedQuest(questID)
    questID = SafeInteger(questID, 1)
    if not questID then return false, nil, "invalid_quest" end
    if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.SetSuperTrackedQuestID) ~= "function" then
        return false, nil, "unsupported"
    end
    local tracked, reason = WorldQuest.GetTrackedQuestID()
    if reason and reason ~= "unsupported" then return false, nil, reason end
    if tracked == questID then
        if not SafeCall(C_SuperTrack.SetSuperTrackedQuestID, 0) then return false, nil, "api_error" end
        return true, false
    end
    if type(C_QuestLog) == "table" and type(C_QuestLog.AddWorldQuestWatch) == "function" then
        local automatic = Enum and Enum.QuestWatchType and Enum.QuestWatchType.Automatic
        SafeCall(C_QuestLog.AddWorldQuestWatch, questID, automatic)
    end
    if not SafeCall(C_SuperTrack.SetSuperTrackedQuestID, questID) then return false, nil, "api_error" end
    return true, true
end

local function OpenWorldQuestLocation(location)
    if type(OpenWorldMap) == "function" then
        return SafeSecureCall(OpenWorldMap, location.uiMapID)
    end
    if WorldMapFrame and type(WorldMapFrame.HandleUserActionOpenSelf) == "function" then
        return SafeSecureCall(WorldMapFrame.HandleUserActionOpenSelf, WorldMapFrame, location.uiMapID)
    end
    return false
end

function WorldQuest.OpenWorldBoss(questID, rawLocation)
    questID = SafeInteger(questID, 1)
    if not questID then return false, "invalid_quest" end
    local location, reason = NormalizeWorldQuestLocation(questID, rawLocation)
    if not location then return false, reason end
    if not OpenWorldQuestLocation(location) then return false, "map_unavailable", location end
    return true, nil, location
end

function WorldQuest.ToggleWorldBossWaypoint(questID, rawLocation)
    questID = SafeInteger(questID, 1)
    if not questID then return false, nil, "invalid_quest" end
    local location, reason = NormalizeWorldQuestLocation(questID, rawLocation)
    if not location then return false, nil, reason end
    if type(C_Map) ~= "table"
        or type(C_Map.CanSetUserWaypointOnMap) ~= "function"
        or type(C_Map.SetUserWaypoint) ~= "function"
        or type(C_Map.ClearUserWaypoint) ~= "function"
        or type(UiMapPoint) ~= "table"
        or type(UiMapPoint.CreateFromCoordinates) ~= "function"
    then
        return false, nil, "unsupported"
    end

    local current, currentReason = EventScheduler.GetUserWaypoint()
    if currentReason then return false, nil, currentReason end
    if current and current.uiMapID == location.uiMapID
        and math.abs(current.positionX - location.positionX) <= 0.0001
        and math.abs(current.positionY - location.positionY) <= 0.0001
    then
        if not SafeCall(C_Map.ClearUserWaypoint) then return false, nil, "api_error" end
        if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
            SafeCall(C_SuperTrack.SetSuperTrackedUserWaypoint, false)
        end
        return true, false, nil, location
    end

    local allowedOk, allowed = SafeCall(C_Map.CanSetUserWaypointOnMap, location.uiMapID)
    if not allowedOk or IsSecret(allowed) then return false, nil, "api_error" end
    if allowed ~= true then return false, nil, "waypoint_unavailable" end
    local pointOk, point = SafeCall(
        UiMapPoint.CreateFromCoordinates, location.uiMapID, location.positionX, location.positionY
    )
    if not pointOk or type(point) ~= "table" or IsSecret(point) then return false, nil, "api_error" end
    local setOk, wasSet = SafeCall(C_Map.SetUserWaypoint, point)
    if not setOk or IsSecret(wasSet) then return false, nil, "api_error" end
    if wasSet ~= true then return false, nil, "waypoint_unavailable" end
    if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
        SafeCall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end

    return true, true, nil, location
end

local function GetAreaPoiPinType()
    return Enum and Enum.SuperTrackingMapPinType and Enum.SuperTrackingMapPinType.AreaPOI
end

function EventScheduler.GetTrackedAreaPOI()
    local pinType = GetAreaPoiPinType()
    if not pinType or type(C_SuperTrack) ~= "table"
        or type(C_SuperTrack.GetSuperTrackedMapPin) ~= "function"
    then
        return nil, "unsupported"
    end
    local ok, trackedType, areaPoiID = SafeCall(C_SuperTrack.GetSuperTrackedMapPin)
    if not ok then return nil, "api_error" end
    if trackedType ~= pinType or IsSecret(trackedType) then return nil end
    return NormalizeAreaPoiID(areaPoiID)
end

function EventScheduler.ToggleTrackedAreaPOI(areaPoiID)
    areaPoiID = NormalizeAreaPoiID(areaPoiID)
    if not areaPoiID then return false, nil, "invalid_area_poi" end
    local pinType = GetAreaPoiPinType()
    if not pinType or type(C_SuperTrack) ~= "table" then
        return false, nil, "unsupported"
    end

    local tracked, reason = EventScheduler.GetTrackedAreaPOI()
    if reason and reason ~= "unsupported" then return false, nil, reason end
    if tracked == areaPoiID then
        if type(C_SuperTrack.ClearSuperTrackedMapPin) ~= "function" then
            return false, nil, "unsupported"
        end
        if not SafeCall(C_SuperTrack.ClearSuperTrackedMapPin) then
            return false, nil, "api_error"
        end
        return true, false
    end

    if type(C_SuperTrack.SetSuperTrackedMapPin) ~= "function" then
        return false, nil, "unsupported"
    end
    if not SafeCall(C_SuperTrack.SetSuperTrackedMapPin, pinType, areaPoiID) then
        return false, nil, "api_error"
    end
    return true, true
end
