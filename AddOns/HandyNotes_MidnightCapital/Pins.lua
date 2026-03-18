local addonName, ns = ...
local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")
local HBD = LibStub("HereBeDragons-2.0", true)

local PluginHandler = {}

function PluginHandler:OnEnter(mapFile, coord)
    local tooltip = self:GetParent() == WorldMapButton and WorldMapTooltip or GameTooltip
    if self:GetCenter() > UIParent:GetCenter() then
        tooltip:SetOwner(self, "ANCHOR_LEFT")
    else
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
    end

    local node = ns.nodes[coord]
    if node then
        ns.PrepareTooltip(tooltip, node)
    end
end

function PluginHandler:OnLeave()
    local tooltip = self:GetParent() == WorldMapButton and WorldMapTooltip or GameTooltip
    tooltip:Hide()
end

local function ResolveWaypointCoordinates(uiMapID, coord)
    local x, y = HandyNotes:getXY(coord)
    if not x or not y then
        return nil
    end

    if C_Map.CanSetUserWaypointOnMap(uiMapID) then
        return uiMapID, x, y
    end

    if not HBD then
        return nil
    end

    local currentMapID = uiMapID
    local currentX = x
    local currentY = y
    local visited = {}

    while currentMapID and not visited[currentMapID] do
        visited[currentMapID] = true

        local mapInfo = C_Map.GetMapInfo(currentMapID)
        local parentMapID = mapInfo and mapInfo.parentMapID
        if not parentMapID or parentMapID == currentMapID then
            break
        end

        local worldX, worldY = HBD:GetWorldCoordinatesFromZone(currentX, currentY, currentMapID)
        if not worldX or not worldY then
            break
        end

        currentMapID = parentMapID
        currentX, currentY = HBD:GetZoneCoordinatesFromWorld(worldX, worldY, currentMapID)
        if not currentX or not currentY then
            break
        end

        if C_Map.CanSetUserWaypointOnMap(currentMapID) then
            return currentMapID, currentX, currentY
        end
    end

    return nil
end

local function SetWaypoint(uiMapID, coord)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and C_SuperTrack) then
        return
    end

    local waypointMapID, x, y = ResolveWaypointCoordinates(uiMapID, coord)
    if not waypointMapID or not x or not y then
        return
    end

    local waypoint = UiMapPoint.CreateFromCoordinates(waypointMapID, x, y)
    if not waypoint then
        return
    end

    C_Map.SetUserWaypoint(waypoint)
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
end

function PluginHandler:OnClick(button, down, uiMapID, coord)
    if down then
        return
    end

    SetWaypoint(uiMapID, coord)
end

local function CreateIter(minimap)
    local scaleSetting = minimap and "minimap_icon_scale" or "map_icon_scale"

    return function(t, prestate)
        if not t then return nil end

        local state = next(t, prestate)
        while state do
            local node = ns.nodes[state]
            if node and ns.db["show_" .. node.category] then
                local icon = ns.icons[node.icon or node.category] or ns.icons.services
                local scale = (node.scale or 1) * ns.db[scaleSetting]
                local alpha = (node.alpha or 1) * ns.db.icon_alpha
                return state, nil, icon, scale, alpha
            end
            state = next(t, state)
        end

        return nil, nil, nil, nil, nil
    end
end

local mapIter = CreateIter(false)
local minimapIter = CreateIter(true)

function PluginHandler:GetNodes2(uiMapID, minimap)
    if uiMapID == ns.mapID then
        return minimap and minimapIter or mapIter, ns.nodes, nil
    end
    return mapIter, nil, nil
end

ns.PluginHandler = PluginHandler
