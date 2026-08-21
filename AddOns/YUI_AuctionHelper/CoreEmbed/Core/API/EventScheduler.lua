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
            opened = SafeCall(OpenWorldMap, uiMapID)
        elseif WorldMapFrame and type(WorldMapFrame.HandleUserActionOpenSelf) == "function" then
            opened = SafeCall(WorldMapFrame.HandleUserActionOpenSelf, WorldMapFrame, uiMapID)
        end
        if not opened then return false, "map_unavailable" end
        return true, nil, location
    end

    if type(OpenMapToEventPoi) == "function" then
        local ok = SafeCall(OpenMapToEventPoi, areaPoiID)
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
