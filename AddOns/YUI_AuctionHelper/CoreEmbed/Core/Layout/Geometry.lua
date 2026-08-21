do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - pure placement geometry
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local P = YUI.Layout._private
local Geometry = {}
P.Geometry = Geometry

local math_max = math.max
local math_min = math.min
local string_find = string.find
local tonumber = tonumber

local function PointHas(point, token)
    return string_find(point or "", token, 1, true) ~= nil
end
local function PointCoordinates(left, bottom, width, height, point)
    local x
    if PointHas(point, "LEFT") then
        x = left
    elseif PointHas(point, "RIGHT") then
        x = left + width
    else
        x = left + width / 2
    end

    local y
    if PointHas(point, "BOTTOM") then
        y = bottom
    elseif PointHas(point, "TOP") then
        y = bottom + height
    else
        y = bottom + height / 2
    end
    return x, y
end

function Geometry.ComputeAnchoredRect(sourceWidth, sourceHeight, sourcePoint, targetLeft, targetBottom, targetWidth, targetHeight, targetPoint, offsetX, offsetY)
    sourceWidth = math_max(tonumber(sourceWidth) or 0, 0)
    sourceHeight = math_max(tonumber(sourceHeight) or 0, 0)
    targetLeft = tonumber(targetLeft) or 0
    targetBottom = tonumber(targetBottom) or 0
    targetWidth = math_max(tonumber(targetWidth) or 0, 0)
    targetHeight = math_max(tonumber(targetHeight) or 0, 0)

    local sourceX, sourceY = PointCoordinates(0, 0, sourceWidth, sourceHeight, sourcePoint or "CENTER")
    local targetX, targetY = PointCoordinates(targetLeft, targetBottom, targetWidth, targetHeight, targetPoint or sourcePoint or "CENTER")
    local left = targetX + (tonumber(offsetX) or 0) - sourceX
    local bottom = targetY + (tonumber(offsetY) or 0) - sourceY
    return left, bottom, left + sourceWidth, bottom + sourceHeight
end

function Geometry.HasMinimumVisibleArea(left, bottom, right, top, screenLeft, screenBottom, screenRight, screenTop, minimumVisible)
    left = tonumber(left) or 0
    bottom = tonumber(bottom) or 0
    right = tonumber(right) or left
    top = tonumber(top) or bottom
    screenLeft = tonumber(screenLeft) or 0
    screenBottom = tonumber(screenBottom) or 0
    screenRight = tonumber(screenRight) or screenLeft
    screenTop = tonumber(screenTop) or screenBottom
    minimumVisible = math_max(tonumber(minimumVisible) or 0, 0)

    local width = math_max(right - left, 0)
    local height = math_max(top - bottom, 0)
    local visibleWidth = math_max(math_min(right, screenRight) - math_max(left, screenLeft), 0)
    local visibleHeight = math_max(math_min(top, screenTop) - math_max(bottom, screenBottom), 0)
    local requiredWidth = math_min(minimumVisible, width)
    local requiredHeight = math_min(minimumVisible, height)
    local visible = width > 0 and height > 0 and visibleWidth >= requiredWidth and visibleHeight >= requiredHeight
    return visible, visibleWidth, visibleHeight
end
