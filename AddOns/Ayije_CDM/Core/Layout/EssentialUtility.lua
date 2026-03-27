local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local ctx = CDM._LayoutCtx

local CDM_C = ctx.CDM_C
local GetFrameData = ctx.GetFrameData
local VIEWERS = ctx.VIEWERS

local ResolveBaseSpellID = ctx.ResolveBaseSpellID
local ToSortNumber = ctx.ToSortNumber
local GetLayoutConfig = ctx.GetLayoutConfig
local GetRowForIndex = ctx.GetRowForIndex
local ComputeEssentialOrUtilityPosition = ctx.ComputeEssentialOrUtilityPosition
local ComputeEssentialContainerSize = ctx.ComputeEssentialContainerSize
local ComputeUtilityContainerSize = ctx.ComputeUtilityContainerSize
local GetSnappedMetrics = ctx.GetSnappedMetrics

local tempIconPositionRecords = {}
local tempIconPositionRecordPool = {}
local tempIconPositionRecordCount = 0
local tempTrinketReorder = {}
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local table_sort = table.sort
local table_wipe = table.wipe
local InCombatLockdown = InCombatLockdown

local scratchPlacements = {}
local scratchPlacementsCount = 0
local scratchPlacementPool = {}
local scratchRowBuckets = {}
local scratchRowBucketPool = {}
local scratchRowBucketPoolCount = 0
local scratchRowOrderSeen = {}
local scratchRowOrderSeenCount = 0
local scratchRowMetrics = {}
local scratchRowMetricPool = {}
local scratchRowMetricPoolCount = 0
local scratchPreSnapUtil = {}

local function ResetScratchPlacements()
    for i = 1, scratchPlacementsCount do
        scratchPlacements[i] = nil
    end
    scratchPlacementsCount = 0
end

local function AcquireScratchPlacement()
    scratchPlacementsCount = scratchPlacementsCount + 1
    local p = scratchPlacementPool[scratchPlacementsCount]
    if not p then
        p = {}
        scratchPlacementPool[scratchPlacementsCount] = p
    end
    scratchPlacements[scratchPlacementsCount] = p
    return p
end
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local function ResizeLayoutContainerIfAllowed(container, inCombat, width, height)
    if inCombat or not container or not width or not height then
        return
    end
    container:SetSize(Snap(width), Snap(height))
end

local function PlaceIconTopLeft(frame, container, x, y, viewer)
    if not frame then
        return
    end

    if viewer and frame:GetParent() ~= viewer then
        frame:SetParent(UIParent)
    end
    local fd = GetFrameData(frame)
    fd.cdmAnchor = { "TOPLEFT", container, "TOPLEFT", Snap(x or 0), Snap(y or 0) }
    frame:ClearAllPoints()
    Pixel.SetPoint(frame, "TOPLEFT", container, "TOPLEFT", x or 0, y or 0)
    frame:Show()
end

local GetStableFrameSortID = ctx.GetStableFrameSortID

local function ResetTempIconPositionRecords()
    for i = 1, tempIconPositionRecordCount do
        tempIconPositionRecords[i] = nil
    end
    tempIconPositionRecordCount = 0
end

local function AcquireTempIconPositionRecord()
    tempIconPositionRecordCount = tempIconPositionRecordCount + 1
    local record = tempIconPositionRecordPool[tempIconPositionRecordCount]
    if not record then
        record = {}
        tempIconPositionRecordPool[tempIconPositionRecordCount] = record
    end
    tempIconPositionRecords[tempIconPositionRecordCount] = record
    return record
end

local function PushTempIconPositionRecord(frame, layoutIndex, sortID)
    local record = AcquireTempIconPositionRecord()
    record.frame = frame
    record.layoutIndex = layoutIndex
    record.sortID = sortID
    return record
end

local function CompareIconPositionRecords(a, b)
    if a.layoutIndex ~= b.layoutIndex then
        return a.layoutIndex < b.layoutIndex
    end

    return a.sortID < b.sortID
end

function CDM:PositionEssentialOrUtilityIcons(icons, viewer, vName)
    local sizeEssRow1, sizeEssRow2, sizeUtility, _, spacing, maxRowEss, _, maxRowUtil, utilityVertical = GetLayoutConfig()
    ResetTempIconPositionRecords()

    local isEssential = (vName == VIEWERS.ESSENTIAL)

    local injectedTrinketCount = 0
    local injFrames = isEssential and CDM.GetTrinketInjectionFrames and CDM.GetTrinketInjectionFrames() or nil

    if #icons == 0 and not injFrames then
        return
    end

    local container = self:GetOrCreateAnchorContainer(viewer)
    if not container then return end

    for _, frame in ipairs(icons) do
        local spellID = ResolveBaseSpellID(frame)
        if spellID or frame.cooldownInfo then
            PushTempIconPositionRecord(frame, ToSortNumber(frame.layoutIndex, 0), GetStableFrameSortID(frame))
        end
    end

    local db = CDM.db or {}
    local injRow = db.trinketsEssentialRow or 1
    local injPos = db.trinketsEssentialPosition or "end"

    if injFrames then
        for i, tFrame in ipairs(injFrames) do
            local record = AcquireTempIconPositionRecord()
            record.frame = tFrame
            if injPos == "start" then
                record.layoutIndex = -1000 + i
            else
                record.layoutIndex = 99000 + i
            end
            record.sortID = 90000 + (tFrame.slotID or i)
        end
        injectedTrinketCount = #injFrames

        if injRow == 2 then
            local essOnlyCount = tempIconPositionRecordCount - injectedTrinketCount
            maxRowEss = math_min(maxRowEss, essOnlyCount)
        end
    end

    local totalIcons = tempIconPositionRecordCount
    if totalIcons > 1 then
        table_sort(tempIconPositionRecords, CompareIconPositionRecords)
    end

    if injectedTrinketCount > 0 then
        if injRow == 2 and injPos == "start" then
            table_wipe(tempTrinketReorder)
            for i = 1, injectedTrinketCount do
                tempTrinketReorder[i] = tempIconPositionRecords[i]
            end
            for i = 1, maxRowEss do
                tempIconPositionRecords[i] = tempIconPositionRecords[injectedTrinketCount + i]
            end
            for i = 1, injectedTrinketCount do
                tempIconPositionRecords[maxRowEss + i] = tempTrinketReorder[i]
            end

        elseif injRow == 1 and injPos == "end" and totalIcons > maxRowEss then
            local insertPos = math_max(1, maxRowEss - injectedTrinketCount + 1)
            table_wipe(tempTrinketReorder)
            for i = 1, injectedTrinketCount do
                tempTrinketReorder[i] = tempIconPositionRecords[totalIcons - injectedTrinketCount + i]
            end
            for i = totalIcons - injectedTrinketCount, insertPos, -1 do
                tempIconPositionRecords[i + injectedTrinketCount] = tempIconPositionRecords[i]
            end
            for i = 1, injectedTrinketCount do
                tempIconPositionRecords[insertPos + i - 1] = tempTrinketReorder[i]
            end
        end
    end

    ResetScratchPlacements()
    for k, bucket in pairs(scratchRowBuckets) do
        for i = 1, #bucket do bucket[i] = nil end
        scratchRowBuckets[k] = nil
        scratchRowBucketPoolCount = scratchRowBucketPoolCount + 1
        scratchRowBucketPool[scratchRowBucketPoolCount] = bucket
    end
    for i = 1, scratchRowOrderSeenCount do
        scratchRowOrderSeen[i] = nil
    end
    scratchRowOrderSeenCount = 0
    for k, rm in pairs(scratchRowMetrics) do
        scratchRowMetrics[k] = nil
        scratchRowMetricPoolCount = scratchRowMetricPoolCount + 1
        scratchRowMetricPool[scratchRowMetricPoolCount] = rm
    end

    local placements = scratchPlacements
    local rowBuckets = scratchRowBuckets
    local rowOrderSeen = scratchRowOrderSeen
    local useMeasuredHorizontalLayout = isEssential or (not utilityVertical)

    local preSnapUtil
    if not useMeasuredHorizontalLayout then
        scratchPreSnapUtil[1], scratchPreSnapUtil[2], scratchPreSnapUtil[3] = GetSnappedMetrics(sizeUtility, spacing)
        preSnapUtil = scratchPreSnapUtil
    end

    for index, record in ipairs(tempIconPositionRecords) do
        local frame = record.frame

        if useMeasuredHorizontalLayout then
            local row = GetRowForIndex(index, totalIcons, isEssential, maxRowEss, maxRowUtil, utilityVertical)
            GetFrameData(frame).cdmRow = row
            self:ApplyStyle(frame, vName)
            local placement = AcquireScratchPlacement()
            placement.frame = frame
            placement.row = row
            placement.x = nil
            placement.y = nil
            local bucket = rowBuckets[row]
            if not bucket then
                if scratchRowBucketPoolCount > 0 then
                    bucket = scratchRowBucketPool[scratchRowBucketPoolCount]
                    scratchRowBucketPool[scratchRowBucketPoolCount] = nil
                    scratchRowBucketPoolCount = scratchRowBucketPoolCount - 1
                else
                    bucket = {}
                end
                rowBuckets[row] = bucket
                scratchRowOrderSeenCount = scratchRowOrderSeenCount + 1
                rowOrderSeen[scratchRowOrderSeenCount] = row
            end
            bucket[#bucket + 1] = placement
        else
            local row, _, _, _, x, y = ComputeEssentialOrUtilityPosition(
                index, totalIcons, isEssential, sizeEssRow1, sizeEssRow2, sizeUtility, spacing, maxRowEss, maxRowUtil, utilityVertical, preSnapUtil
            )
            GetFrameData(frame).cdmRow = row
            self:ApplyStyle(frame, vName)
            local placement = AcquireScratchPlacement()
            placement.frame = frame
            placement.row = row
            placement.x = x
            placement.y = y
        end
    end

    local containerWidth, containerHeight
    if isEssential then
        containerWidth, containerHeight = ComputeEssentialContainerSize(
            totalIcons, sizeEssRow1, sizeEssRow2, spacing, maxRowEss
        )
    else
        containerWidth, containerHeight = ComputeUtilityContainerSize(
            totalIcons, sizeUtility, spacing, maxRowUtil, utilityVertical
        )
    end

    local inCombat = InCombatLockdown()
    local gap = Snap(spacing or 0)

    if useMeasuredHorizontalLayout and scratchPlacementsCount > 0 then
        table_sort(rowOrderSeen)

        local pixelSize = Pixel.GetSize()
        local measuredContainerWidth = 0
        local measuredContainerHeight = 0
        local rowMetrics = scratchRowMetrics

        for orderIndex, row in ipairs(rowOrderSeen) do
            local bucket = rowBuckets[row]
            local rowWidth = 0
            local rowHeight = 0

            for i, placement in ipairs(bucket) do
                local f = placement.frame
                local rawW = f:GetWidth() or 0
                local rawH = f:GetHeight() or 0
                local fallbackSize = sizeUtility
                if isEssential then
                    fallbackSize = (placement.row == 2) and sizeEssRow2 or sizeEssRow1
                end
                local fallbackW = math_max(pixelSize, Snap(fallbackSize and fallbackSize.w or 1))
                local fallbackH = math_max(pixelSize, Snap(fallbackSize and fallbackSize.h or 1))
                local w = rawW > 1 and Snap(rawW) or fallbackW
                local h = rawH > 1 and Snap(rawH) or fallbackH
                placement._w = w
                placement._h = h
                rowWidth = rowWidth + w
                if i > 1 then
                    rowWidth = rowWidth + gap
                end
                if h > rowHeight then
                    rowHeight = h
                end
            end

            measuredContainerWidth = math_max(measuredContainerWidth, rowWidth)
            if orderIndex > 1 then
                measuredContainerHeight = measuredContainerHeight + gap
            end
            local rm = rowMetrics[row]
            if not rm then
                if scratchRowMetricPoolCount > 0 then
                    rm = scratchRowMetricPool[scratchRowMetricPoolCount]
                    scratchRowMetricPool[scratchRowMetricPoolCount] = nil
                    scratchRowMetricPoolCount = scratchRowMetricPoolCount - 1
                else
                    rm = {}
                end
                rowMetrics[row] = rm
            end
            rm.width = rowWidth
            rm.height = rowHeight
            rm.top = measuredContainerHeight
            measuredContainerHeight = measuredContainerHeight + rowHeight
        end

        containerWidth = Snap(measuredContainerWidth)
        containerHeight = Snap(measuredContainerHeight)

        ResizeLayoutContainerIfAllowed(container, inCombat, containerWidth, containerHeight)
        if not inCombat then
            self:ReanchorContainer(vName)
        end

        for _, row in ipairs(rowOrderSeen) do
            local bucket = rowBuckets[row]
            local metrics = rowMetrics[row]
            local leftPad = Pixel.HalfFloor(containerWidth) - Pixel.HalfFloor(metrics.width)
            if leftPad < 0 then leftPad = 0 end
            local cursor = leftPad
            local yOff = Snap(-(metrics.top or 0))

            for _, placement in ipairs(bucket) do
                local frame = placement.frame
                PlaceIconTopLeft(frame, container, Snap(cursor), yOff, viewer)
                cursor = cursor + (placement._w or 0) + gap
            end
        end
    else
        ResizeLayoutContainerIfAllowed(container, inCombat, containerWidth, containerHeight)
        if not inCombat then
            self:ReanchorContainer(vName)
        end

        for _, placement in ipairs(placements) do
            local frame = placement.frame
            PlaceIconTopLeft(frame, container, placement.x or 0, placement.y or 0, viewer)
        end
    end

    if not inCombat then
        local viewerFrame = _G[vName]
        if viewerFrame then
            viewerFrame:ClearAllPoints()
            viewerFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            viewerFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        end

    else
        CDM.combatDirtyViewers[vName] = true
    end

end

function CDM:GetEssentialContentWidth()
    local c = self.anchorContainers and self.anchorContainers[VIEWERS.ESSENTIAL]
    return c and c:GetWidth() or 0
end

function CDM:GetUtilityContentWidth()
    local c = self.anchorContainers and self.anchorContainers[VIEWERS.UTILITY]
    return c and c:GetWidth() or 0
end
