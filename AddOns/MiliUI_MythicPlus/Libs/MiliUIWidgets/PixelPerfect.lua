------------------------------------------------------------
-- 像素工具（取自 Cell/Libs/PixelPerfect.lua 精簡版，改掛本插件 namespace）
-- 只保留設定介面與 1px 邊框需要的部分
------------------------------------------------------------
local _, ns = ...
ns.P = {}
local P = ns.P

local GetNearestPixelSize = PixelUtil.GetNearestPixelSize

function P.GetPixelPerfectScale()
    local _, vRes = GetPhysicalScreenSize()
    if vRes then
        return 768 / vRes
    end
    return 1
end

function P.Scale(desiredPixels)
    if desiredPixels == 0 then return 0 end
    return GetNearestPixelSize(desiredPixels, UIParent:GetEffectiveScale())
end

function P.Size(frame, width, height)
    frame.width = width
    frame.height = height
    frame:SetSize(P.Scale(width), P.Scale(height))
end

function P.Width(frame, width)
    frame.width = width
    frame:SetWidth(P.Scale(width))
end

function P.Height(frame, height)
    frame.height = height
    frame:SetHeight(P.Scale(height))
end

function P.Point(frame, ...)
    if not frame.points then frame.points = {} end
    local point, anchorTo, anchorPoint, x, y

    local n = select("#", ...)
    if n == 1 then
        point = ...
    elseif n == 3 and type(select(2, ...)) == "number" then
        point, x, y = ...
    elseif n == 4 then
        point, anchorTo, x, y = ...
    else
        point, anchorTo, anchorPoint, x, y = ...
    end

    tinsert(frame.points, {point, anchorTo or frame:GetParent(), anchorPoint or point, x or 0, y or 0})
    local i = #frame.points
    frame:SetPoint(frame.points[i][1], frame.points[i][2], frame.points[i][3], P.Scale(frame.points[i][4]), P.Scale(frame.points[i][5]))
end

function P.ClearPoints(frame)
    frame:ClearAllPoints()
    if frame.points then wipe(frame.points) end
end

function P.Repoint(frame)
    if not frame.points or #frame.points == 0 then return end
    frame:ClearAllPoints()
    for _, t in pairs(frame.points) do
        frame:SetPoint(t[1], t[2], t[3], P.Scale(t[4]), P.Scale(t[5]))
    end
end

function P.Resize(frame)
    if frame.width then frame:SetWidth(P.Scale(frame.width)) end
    if frame.height then frame:SetHeight(P.Scale(frame.height)) end
end
