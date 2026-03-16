local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST

local GetFrameData = CDM.GetFrameData
local IsSafeNumber = CDM.IsSafeNumber
local GetBaseSpellID = CDM.GetBaseSpellID
local GetCachedBaseSpellID = CDM.GetCachedBaseSpellID
local CheckBuffRegistryMatch = CDM.CheckBuffRegistryMatch

local function ResolveBaseSpellID(frame)
    return GetCachedBaseSpellID(CDM, frame) or GetBaseSpellID(frame)
end

local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local math_floor = math.floor

local function GetSnappedMetrics(size, spacing)
    local itemW = math.max(Pixel.GetSize(), Snap(size and size.w or 1))
    local itemH = math.max(Pixel.GetSize(), Snap(size and size.h or 1))
    local gap = Snap(spacing or 0)
    return itemW, itemH, gap
end

local function RowWidth(count, itemW, gap)
    if not count or count <= 0 then
        return 0
    end
    return (count * itemW) + ((count - 1) * gap)
end

local function CenteredRowLeft(containerWidth, rowWidth)
    local result = Pixel.HalfFloor(containerWidth or rowWidth or 0) - Pixel.HalfFloor(rowWidth or 0)
    return result >= 0 and result or 0
end

local function CenteredRowXForCol(col, itemW, gap, containerWidth, rowWidth)
    return CenteredRowLeft(containerWidth, rowWidth) + (col * (itemW + gap))
end

local function LayoutPosition(row, col, itemW, itemH, x, y, countInRow)
    return row, col, itemW, itemH, x, -y, countInRow
end

local function LayoutSize(width, height)
    return width, height
end

local function HasPositiveLimit(value)
    return value and value > 0
end

local VIEWERS = CDM_C.VIEWERS
local defensivesHiddenSet = CDM.defensivesHiddenSet

local DEFAULT_SIZE_ESS = { w = 46, h = 40 }
local DEFAULT_SIZE_BUFF = { w = 40, h = 36 }

local function Val(primary, fallback, default)
    if primary ~= nil then return primary end
    if fallback ~= nil then return fallback end
    return default
end

local function GetLayoutConfig()
    local sizes = CDM.Sizes or {}
    local df = CDM.defaults or {}
    local utilVertical = sizes.UTILITY_VERTICAL
    if utilVertical == nil then utilVertical = df.utilityVertical or false end
    return sizes.SIZE_ESS_ROW1 or df.sizeEssRow1 or DEFAULT_SIZE_ESS,
        sizes.SIZE_ESS_ROW2 or df.sizeEssRow2 or DEFAULT_SIZE_ESS,
        sizes.SIZE_UTILITY or df.sizeUtility or DEFAULT_SIZE_ESS,
        sizes.SIZE_BUFF or df.sizeBuff or DEFAULT_SIZE_BUFF,
        Val(sizes.SPACING, df.spacing, 1),
        Val(sizes.MAX_ROW_ESS, df.maxRowEss, 9),
        Val(sizes.UTILITY_Y_OFFSET, df.utilityYOffset, 0),
        Val(sizes.MAX_ROW_UTIL, df.maxRowUtil, 8),
        utilVertical,
        Val(sizes.UTILITY_X_OFFSET, df.utilityXOffset, 0)
end

local reanchorRetry = {}

local function QueueReanchorRetry(cdm, vName, delay)
    if not cdm or not vName then return end
    local now = GetTime()
    local state = reanchorRetry[vName]
    if not state or (now - state.last) > 2 then
        if not state then
            state = { count = 0, last = now, pending = false }
            reanchorRetry[vName] = state
        else
            state.count = 0
            state.last = now
            state.pending = false
        end
    end

    if state.pending then
        return
    end

    if state.count >= 5 then
        return
    end
    state.count = state.count + 1
    state.last = now
    state.pending = true

    C_Timer.After(delay or 0.1, function()
        state.pending = false
        cdm:QueueViewer(vName, true)
    end)
end

local function ComputeGridPosition(index, total, maxPerRow, size, spacing)
    if not maxPerRow or maxPerRow <= 0 then
        maxPerRow = total
    end
    local row = math.ceil(index / maxPerRow)
    local col = (index - 1) % maxPerRow
    local countInRow = math.min(maxPerRow, total - (row - 1) * maxPerRow)
    local itemW, itemH, gap = GetSnappedMetrics(size, spacing)
    local cWidth = RowWidth(maxPerRow, itemW, gap)
    local rWidth = RowWidth(countInRow, itemW, gap)
    local x = CenteredRowXForCol(col, itemW, gap, cWidth, rWidth)
    local y = (row - 1) * (itemH + gap)
    return LayoutPosition(row, col, itemW, itemH, x, y, countInRow)
end

local function GetRowForIndex(index, total, isEssential, maxRowEss, maxRowUtil, utilityVertical)
    if isEssential then
        return (index <= maxRowEss) and 1 or 2
    end
    if utilityVertical and HasPositiveLimit(maxRowUtil) then
        return math_floor((index - 1) / maxRowUtil) + 1
    end
    if HasPositiveLimit(maxRowUtil) and maxRowUtil < total then
        return (index <= maxRowUtil) and 1 or 2
    end
    return 1
end

local function ComputeEssentialOrUtilityPosition(index, total, isEssential, sizeEssRow1, sizeEssRow2, sizeUtility, spacing, maxRowEss, maxRowUtil, utilityVertical, _preEssRow1, _preEssRow2, _preUtil)
    if isEssential then
        local row1W, row1H, gap
        if _preEssRow1 then
            row1W, row1H, gap = _preEssRow1[1], _preEssRow1[2], _preEssRow1[3]
        else
            row1W, row1H, gap = GetSnappedMetrics(sizeEssRow1, spacing)
        end
        local row2W, row2H
        if _preEssRow2 then
            row2W, row2H = _preEssRow2[1], _preEssRow2[2]
        else
            row2W, row2H = GetSnappedMetrics(sizeEssRow2, spacing)
        end
        local row1Count = math.min(maxRowEss, total)
        local row2Count = math.max(0, total - maxRowEss)
        local row1Width = RowWidth(row1Count, row1W, gap)
        local row2Width = RowWidth(row2Count, row2W, gap)
        local cWidth = math.max(row1Width, row2Width)

        if index <= maxRowEss then
            local countInRow = row1Count
            local col = index - 1
            local x = CenteredRowXForCol(col, row1W, gap, cWidth, row1Width)
            return LayoutPosition(1, col, row1W, row1H, x, 0, countInRow)
        else
            local countInRow = row2Count
            local col = index - maxRowEss - 1
            local x = CenteredRowXForCol(col, row2W, gap, cWidth, row2Width)
            local y = row1H + gap
            return LayoutPosition(2, col, row2W, row2H, x, y, countInRow)
        end
    end

    local utilW, utilH, gap
    if _preUtil then
        utilW, utilH, gap = _preUtil[1], _preUtil[2], _preUtil[3]
    else
        utilW, utilH, gap = GetSnappedMetrics(sizeUtility, spacing)
    end

    if utilityVertical and HasPositiveLimit(maxRowUtil) then
        local numCols = math.ceil(total / maxRowUtil)
        local colIndex = math.floor((index - 1) / maxRowUtil)
        local rowInCol = (index - 1) % maxRowUtil
        local iconsInThisCol = math.min(maxRowUtil, total - colIndex * maxRowUtil)
        local x = colIndex * (utilW + gap)
        local y = (iconsInThisCol - 1 - rowInCol) * (utilH + gap)
        return LayoutPosition(colIndex + 1, rowInCol, utilW, utilH, x, y, iconsInThisCol)
    end

    if HasPositiveLimit(maxRowUtil) and maxRowUtil < total then
        local row1Count = maxRowUtil
        local row2Count = total - maxRowUtil
        local row1Width = RowWidth(row1Count, utilW, gap)
        local row2Width = RowWidth(row2Count, utilW, gap)
        local cWidth = math.max(row1Width, row2Width)
        if index <= maxRowUtil then
            local countInRow = row1Count
            local col = index - 1
            local x = CenteredRowXForCol(col, utilW, gap, cWidth, row1Width)
            return LayoutPosition(1, col, utilW, utilH, x, 0, countInRow)
        else
            local countInRow = row2Count
            local col = index - maxRowUtil - 1
            local x = CenteredRowXForCol(col, utilW, gap, cWidth, row2Width)
            local y = utilH + gap
            return LayoutPosition(2, col, utilW, utilH, x, y, countInRow)
        end
    end
    return ComputeGridPosition(index, total, total, sizeUtility, spacing)
end

local function ComputeEssentialContainerSize(total, sizeEssRow1, sizeEssRow2, spacing, maxRowEss)
    local row1W, row1H, gap = GetSnappedMetrics(sizeEssRow1, spacing)
    local row2W, row2H = GetSnappedMetrics(sizeEssRow2, spacing)
    if total <= 0 then
        return LayoutSize(row1W, row1H)
    end
    local row1Count = math.min(maxRowEss, total)
    local row2Count = math.max(0, total - maxRowEss)
    local r1Width = RowWidth(row1Count, row1W, gap)
    local r2Width = RowWidth(row2Count, row2W, gap)
    local cWidth = math.max(r1Width, r2Width)
    local cHeight = row1H
    if row2Count > 0 then
        cHeight = row1H + gap + row2H
    end
    return LayoutSize(cWidth, cHeight)
end

local function ComputeUtilityContainerSize(total, sizeUtility, spacing, maxRowUtil, utilityVertical)
    local utilW, utilH, gap = GetSnappedMetrics(sizeUtility, spacing)
    if total <= 0 then
        return LayoutSize(utilW, utilH)
    end
    if utilityVertical and HasPositiveLimit(maxRowUtil) then
        local numCols = math.ceil(total / maxRowUtil)
        local tallestCol = math.min(maxRowUtil, total)
        local cWidth = RowWidth(numCols, utilW, gap)
        local cHeight = RowWidth(tallestCol, utilH, gap)
        return LayoutSize(cWidth, cHeight)
    end

    if HasPositiveLimit(maxRowUtil) and maxRowUtil < total then
        local row2Count = total - maxRowUtil
        local r1Width = RowWidth(maxRowUtil, utilW, gap)
        local r2Width = RowWidth(row2Count, utilW, gap)
        local cWidth = math.max(r1Width, r2Width)
        local cHeight = (2 * utilH) + gap
        return LayoutSize(cWidth, cHeight)
    end
    local cWidth = RowWidth(total, utilW, gap)
    local cHeight = utilH
    return LayoutSize(cWidth, cHeight)
end

local function ToSortNumber(value, fallback)
    return IsSafeNumber(value) and value or fallback
end

local function CompareByLayoutIndex(a, b)
    return ToSortNumber(a.layoutIndex, 0) < ToSortNumber(b.layoutIndex, 0)
end

local function CountPopulatedFrames(viewer)
    if not viewer or not viewer.itemFramePool then return 0, 0 end
    local total, populated = 0, 0
    for frame in viewer.itemFramePool:EnumerateActive() do
        if frame:IsShown() then
            total = total + 1
            if GetBaseSpellID(frame) then
                populated = populated + 1
            end
        end
    end
    return populated, total
end

CDM.CountPopulatedFrames = CountPopulatedFrames

local function GetXSide(point)
    if point == "LEFT" or point == "TOPLEFT" or point == "BOTTOMLEFT" then
        return "LEFT"
    elseif point == "RIGHT" or point == "TOPRIGHT" or point == "BOTTOMRIGHT" then
        return "RIGHT"
    end
    return "CENTER"
end

local function GetYSide(point)
    if point == "TOP" or point == "TOPLEFT" or point == "TOPRIGHT" then
        return "TOP"
    elseif point == "BOTTOM" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT" then
        return "BOTTOM"
    end
    return "CENTER"
end

local function ComposePoint(xSide, ySide)
    if ySide == "TOP" then
        if xSide == "LEFT" then return "TOPLEFT" end
        if xSide == "RIGHT" then return "TOPRIGHT" end
        return "TOP"
    elseif ySide == "BOTTOM" then
        if xSide == "LEFT" then return "BOTTOMLEFT" end
        if xSide == "RIGHT" then return "BOTTOMRIGHT" end
        return "BOTTOM"
    end
    if xSide == "LEFT" then return "LEFT" end
    if xSide == "RIGHT" then return "RIGHT" end
    return "CENTER"
end

local function DeriveSelfPoint(anchorPoint, grow)
    local point = anchorPoint or "CENTER"
    if grow == "CENTER_H" or grow == "CENTER_V" then
        return point
    end

    local xSide = GetXSide(point)
    local ySide = GetYSide(point)

    if grow == "RIGHT" then
        xSide = "LEFT"
    elseif grow == "LEFT" then
        xSide = "RIGHT"
    elseif grow == "DOWN" then
        ySide = "TOP"
    elseif grow == "UP" then
        ySide = "BOTTOM"
    end

    return ComposePoint(xSide, ySide)
end

local function PositionFrameAtSlot(frame, container, idx, iconW, iconH, spacingW, grow, layoutCount, anchorPoint, selfPoint)
    local x, y
    local stepW = Snap(iconW + spacingW)
    local stepH = Snap(iconH + spacingW)
    if grow == "RIGHT" then
        x, y = idx * stepW, 0
    elseif grow == "LEFT" then
        x, y = -idx * stepW, 0
    elseif grow == "UP" then
        x, y = 0, idx * stepH
    elseif grow == "DOWN" then
        x, y = 0, -idx * stepH
    elseif grow == "CENTER_H" then
        local startX = -Pixel.HalfFloor((layoutCount - 1) * stepW)
        x, y = startX + idx * stepW, 0
    elseif grow == "CENTER_V" then
        local startY = Pixel.HalfFloor((layoutCount - 1) * stepH)
        x, y = 0, startY - idx * stepH
    end
    Pixel.SetPoint(frame, selfPoint or "CENTER", container, anchorPoint or "CENTER", x or 0, y or 0)
end

local function PlaceFrame(frame, container, selfPoint, anchorPoint, x, y)
    Pixel.SetPoint(frame, selfPoint, container, anchorPoint, x, y)
end

local function OverrideCooldownText(t, pixelSize, color)
    if not t or not t.SetFont then return end
    if pixelSize then
        local fp, _, ff = t:GetFont()
        if fp then t:SetFont(fp, pixelSize, ff) end
    end
    if color then
        t:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
end

local function GetCooldownFontRegions(cd, frameData)
    local regions = frameData and frameData.cdmCdFontRegions
    if regions then
        return regions
    end
    regions = {}
    for ri = 1, select("#", cd:GetRegions()) do
        local region = select(ri, cd:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            regions[#regions + 1] = region
        end
    end
    if frameData then
        frameData.cdmCdFontRegions = regions
    end
    return regions
end

local function OverrideCooldownRegions(cd, pixelSize, color, frameData)
    local regions = GetCooldownFontRegions(cd, frameData)
    for _, region in ipairs(regions) do
        OverrideCooldownText(region, pixelSize, color)
    end
end

local nextStableSortID = 0

local function GetStableFrameSortID(frame)
    local frameData = GetFrameData(frame)
    local sortID = frameData.cdmStableSortID
    if sortID then
        return sortID
    end

    nextStableSortID = nextStableSortID + 1
    frameData.cdmStableSortID = nextStableSortID
    return nextStableSortID
end

CDM._LayoutCtx = {
    GetFrameData = GetFrameData,
    CheckBuffRegistryMatch = CheckBuffRegistryMatch,
    CheckCdGroupMatch = CDM.CheckCdGroupMatch,
    VIEWERS = VIEWERS,
    defensivesHiddenSet = defensivesHiddenSet,
    CDM_C = CDM_C,
    Pixel = Pixel,
    Snap = Snap,
    ResolveBaseSpellID = ResolveBaseSpellID,
    ToSortNumber = ToSortNumber,
    GetLayoutConfig = GetLayoutConfig,
    CompareByLayoutIndex = CompareByLayoutIndex,
    QueueReanchorRetry = QueueReanchorRetry,
    GetRowForIndex = GetRowForIndex,
    ComputeEssentialOrUtilityPosition = ComputeEssentialOrUtilityPosition,
    ComputeEssentialContainerSize = ComputeEssentialContainerSize,
    ComputeUtilityContainerSize = ComputeUtilityContainerSize,
    GetSnappedMetrics = GetSnappedMetrics,
    RowWidth = RowWidth,
    GetXSide = GetXSide,
    GetYSide = GetYSide,
    ComposePoint = ComposePoint,
    DeriveSelfPoint = DeriveSelfPoint,
    PositionFrameAtSlot = PositionFrameAtSlot,
    PlaceFrame = PlaceFrame,
    OverrideCooldownText = OverrideCooldownText,
    GetCooldownFontRegions = GetCooldownFontRegions,
    OverrideCooldownRegions = OverrideCooldownRegions,
    CenteredRowLeft = CenteredRowLeft,
    GetStableFrameSortID = GetStableFrameSortID,
}
