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

local SECONDARY_SET = CDM.SpellSets and CDM.SpellSets.secondary
local TERTIARY_SET = CDM.SpellSets and CDM.SpellSets.tertiary
assert(SECONDARY_SET and TERTIARY_SET, "CDM: SpellUtils.lua must load before Layout/Shared.lua")

local math_floor = math.floor
local math_ceil = math.ceil

local function GetLayoutPixelSize()
    local pixel = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()) or 1
    local scale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if scale and scale > 0 then
        pixel = pixel / scale
    end
    if not pixel or pixel <= 0 then
        return 1
    end
    return pixel
end

local function RoundToNearestInt(value)
    if value >= 0 then
        return math_floor(value + 0.5)
    end
    return math_ceil(value - 0.5)
end

local function ToPixelCount(value)
    return RoundToNearestInt((value or 0) / GetLayoutPixelSize())
end

local function PixelCountToUnits(pixelCount)
    return pixelCount * GetLayoutPixelSize()
end

local function GetSnappedMetricsPx(size, spacing)
    local itemWPx = math.max(1, ToPixelCount(size and size.w or 1))
    local itemHPx = math.max(1, ToPixelCount(size and size.h or 1))
    local gapPx = CDM_C.GetCooldownIconGapPixels(spacing)
    return itemWPx, itemHPx, gapPx
end

local function RowWidthPx(count, itemWPx, gapPx)
    if not count or count <= 0 then
        return 0
    end
    return (count * itemWPx) + ((count - 1) * gapPx)
end

local function CenteredRowLeftPx(containerWidthPx, rowWidthPx)
    local slackPx = (containerWidthPx or rowWidthPx or 0) - (rowWidthPx or 0)
    if slackPx < 0 then
        slackPx = 0
    end
    return math_floor(slackPx * 0.5)
end

local function CenteredRowXForColPx(col, itemWPx, gapPx, containerWidthPx, rowWidthPx)
    return CenteredRowLeftPx(containerWidthPx, rowWidthPx) + (col * (itemWPx + gapPx))
end

local function LayoutPositionFromPx(row, col, itemWPx, itemHPx, xPx, yPx, countInRow)
    return row, col,
        PixelCountToUnits(itemWPx),
        PixelCountToUnits(itemHPx),
        PixelCountToUnits(xPx),
        -PixelCountToUnits(yPx),
        countInRow
end

local function LayoutSizeFromPx(widthPx, heightPx)
    return PixelCountToUnits(widthPx), PixelCountToUnits(heightPx)
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
        Val(sizes.UTILITY_X_OFFSET, df.utilityXOffset, 0),
        sizes.SIZE_BUFF_SEC or sizes.SIZE_BUFF or df.sizeBuff or DEFAULT_SIZE_BUFF,
        sizes.SIZE_BUFF_TERT or sizes.SIZE_BUFF or df.sizeBuff or DEFAULT_SIZE_BUFF
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
    local itemWPx, itemHPx, gapPx = GetSnappedMetricsPx(size, spacing)
    local containerWidthPx = RowWidthPx(maxPerRow, itemWPx, gapPx)
    local rowWidthPx = RowWidthPx(countInRow, itemWPx, gapPx)
    local xPx = CenteredRowXForColPx(col, itemWPx, gapPx, containerWidthPx, rowWidthPx)
    local yPx = (row - 1) * (itemHPx + gapPx)
    return LayoutPositionFromPx(row, col, itemWPx, itemHPx, xPx, yPx, countInRow)
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

local function ComputeEssentialOrUtilityPosition(index, total, isEssential, sizeEssRow1, sizeEssRow2, sizeUtility, spacing, maxRowEss, maxRowUtil, utilityVertical)
    if isEssential then
        local row1WPx, row1HPx, gapPx = GetSnappedMetricsPx(sizeEssRow1, spacing)
        local row2WPx, row2HPx = GetSnappedMetricsPx(sizeEssRow2, spacing)
        local row1Count = math.min(maxRowEss, total)
        local row2Count = math.max(0, total - maxRowEss)
        local row1WidthPx = RowWidthPx(row1Count, row1WPx, gapPx)
        local row2WidthPx = RowWidthPx(row2Count, row2WPx, gapPx)
        local containerWidthPx = math.max(row1WidthPx, row2WidthPx)

        if index <= maxRowEss then
            local countInRow = row1Count
            local col = index - 1
            local xPx = CenteredRowXForColPx(col, row1WPx, gapPx, containerWidthPx, row1WidthPx)
            return LayoutPositionFromPx(1, col, row1WPx, row1HPx, xPx, 0, countInRow)
        else
            local countInRow = row2Count
            local col = index - maxRowEss - 1
            local xPx = CenteredRowXForColPx(col, row2WPx, gapPx, containerWidthPx, row2WidthPx)
            local yPx = row1HPx + gapPx
            return LayoutPositionFromPx(2, col, row2WPx, row2HPx, xPx, yPx, countInRow)
        end
    end

    local utilWPx, utilHPx, gapPx = GetSnappedMetricsPx(sizeUtility, spacing)

    if utilityVertical and HasPositiveLimit(maxRowUtil) then
        local numCols = math.ceil(total / maxRowUtil)
        local colIndex = math.floor((index - 1) / maxRowUtil)
        local rowInCol = (index - 1) % maxRowUtil
        local iconsInThisCol = math.min(maxRowUtil, total - colIndex * maxRowUtil)
        local xPx = colIndex * (utilWPx + gapPx)
        local yPx = (iconsInThisCol - 1 - rowInCol) * (utilHPx + gapPx)
        return LayoutPositionFromPx(colIndex + 1, rowInCol, utilWPx, utilHPx, xPx, yPx, iconsInThisCol)
    end

    if HasPositiveLimit(maxRowUtil) and maxRowUtil < total then
        local row1Count = maxRowUtil
        local row2Count = total - maxRowUtil
        local row1WidthPx = RowWidthPx(row1Count, utilWPx, gapPx)
        local row2WidthPx = RowWidthPx(row2Count, utilWPx, gapPx)
        local containerWidthPx = math.max(row1WidthPx, row2WidthPx)
        if index <= maxRowUtil then
            local countInRow = row1Count
            local col = index - 1
            local xPx = CenteredRowXForColPx(col, utilWPx, gapPx, containerWidthPx, row1WidthPx)
            return LayoutPositionFromPx(1, col, utilWPx, utilHPx, xPx, 0, countInRow)
        else
            local countInRow = row2Count
            local col = index - maxRowUtil - 1
            local xPx = CenteredRowXForColPx(col, utilWPx, gapPx, containerWidthPx, row2WidthPx)
            local yPx = utilHPx + gapPx
            return LayoutPositionFromPx(2, col, utilWPx, utilHPx, xPx, yPx, countInRow)
        end
    end
    return ComputeGridPosition(index, total, total, sizeUtility, spacing)
end

local function ComputeEssentialContainerSize(total, sizeEssRow1, sizeEssRow2, spacing, maxRowEss)
    local row1WPx, row1HPx, gapPx = GetSnappedMetricsPx(sizeEssRow1, spacing)
    local row2WPx, row2HPx = GetSnappedMetricsPx(sizeEssRow2, spacing)
    if total <= 0 then
        return LayoutSizeFromPx(row1WPx, row1HPx)
    end
    local row1Count = math.min(maxRowEss, total)
    local row2Count = math.max(0, total - maxRowEss)
    local row1Width = RowWidthPx(row1Count, row1WPx, gapPx)
    local row2Width = RowWidthPx(row2Count, row2WPx, gapPx)
    local containerWidth = math.max(row1Width, row2Width)
    local containerHeight = row1HPx
    if row2Count > 0 then
        containerHeight = row1HPx + gapPx + row2HPx
    end
    return LayoutSizeFromPx(containerWidth, containerHeight)
end

local function ComputeUtilityContainerSize(total, sizeUtility, spacing, maxRowUtil, utilityVertical)
    local utilWPx, utilHPx, gapPx = GetSnappedMetricsPx(sizeUtility, spacing)
    if total <= 0 then
        return LayoutSizeFromPx(utilWPx, utilHPx)
    end
    if utilityVertical and HasPositiveLimit(maxRowUtil) then
        local numCols = math.ceil(total / maxRowUtil)
        local tallestCol = math.min(maxRowUtil, total)
        local containerWidth = RowWidthPx(numCols, utilWPx, gapPx)
        local containerHeight = RowWidthPx(tallestCol, utilHPx, gapPx)
        return LayoutSizeFromPx(containerWidth, containerHeight)
    end

    if HasPositiveLimit(maxRowUtil) and maxRowUtil < total then
        local row2Count = total - maxRowUtil
        local row1Width = RowWidthPx(maxRowUtil, utilWPx, gapPx)
        local row2Width = RowWidthPx(row2Count, utilWPx, gapPx)
        local containerWidth = math.max(row1Width, row2Width)
        local containerHeight = (2 * utilHPx) + gapPx
        return LayoutSizeFromPx(containerWidth, containerHeight)
    end
    local containerWidth = RowWidthPx(total, utilWPx, gapPx)
    local containerHeight = utilHPx
    return LayoutSizeFromPx(containerWidth, containerHeight)
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

CDM._LayoutCtx = {
    GetFrameData = GetFrameData,
    CheckBuffRegistryMatch = CheckBuffRegistryMatch,
    VIEWERS = VIEWERS,
    defensivesHiddenSet = defensivesHiddenSet,
    CDM_C = CDM_C,
    SECONDARY_SET = SECONDARY_SET,
    TERTIARY_SET = TERTIARY_SET,
    ResolveBaseSpellID = ResolveBaseSpellID,
    ToSortNumber = ToSortNumber,
    GetLayoutConfig = GetLayoutConfig,
    CompareByLayoutIndex = CompareByLayoutIndex,
    QueueReanchorRetry = QueueReanchorRetry,
    GetRowForIndex = GetRowForIndex,
    ComputeEssentialOrUtilityPosition = ComputeEssentialOrUtilityPosition,
    ComputeEssentialContainerSize = ComputeEssentialContainerSize,
    ComputeUtilityContainerSize = ComputeUtilityContainerSize,
}
