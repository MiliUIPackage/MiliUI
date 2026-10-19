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

-- 剛好 n 個實體像素的 UI 單位（照 UIParent 的有效縮放）。
-- ⚠ 跟 P.Scale(n) 不一樣：P.Scale 把「n 個 UI 單位」貼到最近的整數像素，1 個 UI 單位
-- ≥ 1.5 實體像素（1440p 以上、UI 縮放偏大）時 P.Scale(1) 是 2px 以上，< 0.5 時是 0。
-- 邊框粗細、細線、「1px」這類以實體像素計的量用這支；尺寸、間距、座標照舊 P.Scale
function P.Pixel(n)
    n = math.floor((tonumber(n) or 0) + 0.5)
    if n <= 0 then return 0 end
    return n * PixelUtil.GetPixelToUIUnitFactor() / UIParent:GetEffectiveScale()
end

-- 關掉引擎的像素貼齊（SetSnapToPixelGrid／SetTexelSnappingBias），回傳原物件。
-- 貼齊開著時，引擎在畫的那一刻把**每張貼圖自己的**頂點各自四捨五入到最近的實體像素：框停在小數座標、
-- 或邊框粗細不是剛好整數像素時，1px 的邊兩側捨入到同一格就整條變 0px，跟隔壁貼圖方向不同就變 2px／露縫。
-- Cell／ElvUI 對全域貼圖 metatable 掛勾關掉了這項，所以裝著它們的人看不到這個 bug —— 我們自己要關。
-- 自己畫的邊框、細線、跟邊框相接的底／填充一律過這支；StatusBar 傳進來就關它的填充貼圖。
-- 只用在自己建的物件上（不寫欄位、pcall 包住，暴雪受限的貼圖會靜默略過）。
-- 規則全文：.claude/notes/wow-1px-border-rules.md
local function NoSnapRaw(t)
    t:SetSnapToPixelGrid(false)
    t:SetTexelSnappingBias(0)
end
function P.NoSnap(obj)
    if type(obj) ~= "table" then return obj end
    local t = obj
    if not t.SetSnapToPixelGrid and t.GetStatusBarTexture then t = t:GetStatusBarTexture() end
    if type(t) == "table" and t.SetSnapToPixelGrid then pcall(NoSnapRaw, t) end
    return obj
end

-- BackdropTemplate 的九張貼圖（SetBackdrop 之後才存在）
local BACKDROP_PIECES = {
    "Center", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
}
function P.NoSnapBackdrop(frame)
    for _, k in ipairs(BACKDROP_PIECES) do P.NoSnap(frame[k]) end
    return frame
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
