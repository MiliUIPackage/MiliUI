local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local ctx = CDM._LayoutCtx

local CDM_C = ctx.CDM_C
local GetFrameData = ctx.GetFrameData
local VIEWERS = ctx.VIEWERS
local defensivesHiddenSet = ctx.defensivesHiddenSet

local ResolveBaseSpellID = ctx.ResolveBaseSpellID
local ToSortNumber = ctx.ToSortNumber
local GetLayoutConfig = ctx.GetLayoutConfig
local QueueReanchorRetry = ctx.QueueReanchorRetry
local GetRowForIndex = ctx.GetRowForIndex
local ComputeEssentialOrUtilityPosition = ctx.ComputeEssentialOrUtilityPosition
local ComputeEssentialContainerSize = ctx.ComputeEssentialContainerSize
local ComputeUtilityContainerSize = ctx.ComputeUtilityContainerSize

local tempIconPositionRecords = {}
local tempIconPositionRecordPool = {}
local tempIconPositionRecordCount = 0
local nextStableFrameSortID = 0
local tempTrinketReorder = {}
local math_floor = math.floor

local scratchPlacements = {}
local scratchPlacementsCount = 0
local scratchPlacementPool = {}
local scratchRowBuckets = {}
local scratchRowOrderSeen = {}
local scratchRowOrderSeenCount = 0
local scratchRowMetrics = {}

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
local ToPixelCountForFrame = CDM_C.ToPixelCountForRegion
local PixelsToUIForRegion = CDM_C.PixelsToUIForRegion
local SetPointPixels = CDM_C.SetPointPixels
local SnapContainerWidth = CDM_C.SnapContainerWidth

local function ResizeLayoutContainerIfAllowed(container, inCombat, width, height)
    if inCombat or not container or not width or not height then
        return
    end
    container:SetSize(SnapContainerWidth(width, container), height)
end

local function PlaceIconTopLeft(frame, container, x, y, usePixelOffsets, pixelRegion)
    if not frame then
        return
    end

    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    if usePixelOffsets then
        SetPointPixels(frame, "TOPLEFT", container, "TOPLEFT", x or 0, y or 0, pixelRegion or container or UIParent)
    else
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", x or 0, y or 0)
    end
    frame:Show()
end

local function GetStableFrameSortID(frame)
    local frameData = GetFrameData(frame)
    local sortID = frameData.cdmStableSortID
    if sortID then
        return sortID
    end
    nextStableFrameSortID = nextStableFrameSortID + 1
    frameData.cdmStableSortID = nextStableFrameSortID
    return nextStableFrameSortID
end

ctx.GetStableFrameSortID = GetStableFrameSortID

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

    if #icons == 0 and not injFrames then return end

    local container = self:GetOrCreateAnchorContainer(viewer)
    if not container then return end

    local missingDataCount = 0
    local hasHiddenSet = next(defensivesHiddenSet) ~= nil
    for _, frame in ipairs(icons) do
        local spellID = ResolveBaseSpellID(frame)
        if spellID and defensivesHiddenSet[spellID] then
            frame:ClearAllPoints()
            frame:SetParent(viewer)
            frame:Hide()
            GetFrameData(frame).cdmHiddenByDefensives = true
        elseif not spellID and hasHiddenSet then
            frame:ClearAllPoints()
            frame:SetParent(viewer)
            frame:Hide()
            missingDataCount = missingDataCount + 1
        elseif spellID or frame.cooldownInfo then
            PushTempIconPositionRecord(frame, ToSortNumber(frame.layoutIndex, 0), GetStableFrameSortID(frame))
        else
            missingDataCount = missingDataCount + 1
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
            maxRowEss = math.min(maxRowEss, essOnlyCount)
        end
    end

    local totalIcons = tempIconPositionRecordCount
    if totalIcons > 1 then
        table.sort(tempIconPositionRecords, CompareIconPositionRecords)
    end

    if injectedTrinketCount > 0 then
        if injRow == 2 and injPos == "start" then
            table.wipe(tempTrinketReorder)
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
            local insertPos = math.max(1, maxRowEss - injectedTrinketCount + 1)
            table.wipe(tempTrinketReorder)
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
    end
    for i = 1, scratchRowOrderSeenCount do
        scratchRowOrderSeen[i] = nil
    end
    scratchRowOrderSeenCount = 0
    table.wipe(scratchRowMetrics)

    local placements = scratchPlacements
    local rowBuckets = scratchRowBuckets
    local rowOrderSeen = scratchRowOrderSeen
    local useMeasuredHorizontalLayout = isEssential or (not utilityVertical)

    for index, record in ipairs(tempIconPositionRecords) do
        local frame = record.frame

        if useMeasuredHorizontalLayout then
            local row = GetRowForIndex(index, totalIcons, isEssential, maxRowEss, maxRowUtil, utilityVertical)
            GetFrameData(frame).cdmRow = row
            self:ApplyStyle(frame, vName)
            local placement = AcquireScratchPlacement()
            placement.frame = frame
            placement.row = row
            placement._wPx = nil
            placement._hPx = nil
            placement.x = nil
            placement.y = nil
            local bucket = rowBuckets[row]
            if not bucket then
                bucket = {}
                rowBuckets[row] = bucket
                scratchRowOrderSeenCount = scratchRowOrderSeenCount + 1
                rowOrderSeen[scratchRowOrderSeenCount] = row
            end
            bucket[#bucket + 1] = placement
        else
            local row, _, _, _, x, y = ComputeEssentialOrUtilityPosition(
                index, totalIcons, isEssential, sizeEssRow1, sizeEssRow2, sizeUtility, spacing, maxRowEss, maxRowUtil, utilityVertical
            )
            GetFrameData(frame).cdmRow = row
            self:ApplyStyle(frame, vName)
            local placement = AcquireScratchPlacement()
            placement.frame = frame
            placement.row = row
            placement.x = x
            placement.y = y
            placement._wPx = nil
            placement._hPx = nil
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
    local gapPx = CDM_C.GetCooldownIconGapPixels(spacing)

    if useMeasuredHorizontalLayout and scratchPlacementsCount > 0 then
        table.sort(rowOrderSeen)

        local containerWidthPx = 0
        local containerHeightPx = 0
        local rowMetrics = scratchRowMetrics

        for orderIndex, row in ipairs(rowOrderSeen) do
            local bucket = rowBuckets[row]
            local rowWidthPx = 0
            local rowHeightPx = 0

            for i, placement in ipairs(bucket) do
                local f = placement.frame
                local rawW = f:GetWidth() or 0
                local rawH = f:GetHeight() or 0
                local fallbackSize = sizeUtility
                if isEssential then
                    fallbackSize = (placement.row == 2) and sizeEssRow2 or sizeEssRow1
                end
                local fallbackWPx = math.max(1, ToPixelCountForFrame(container, fallbackSize and fallbackSize.w or 1, 1))
                local fallbackHPx = math.max(1, ToPixelCountForFrame(container, fallbackSize and fallbackSize.h or 1, 1))
                local wPx = rawW > 1 and ToPixelCountForFrame(container, rawW, 1) or fallbackWPx
                local hPx = rawH > 1 and ToPixelCountForFrame(container, rawH, 1) or fallbackHPx
                placement._wPx = wPx
                placement._hPx = hPx
                rowWidthPx = rowWidthPx + wPx
                if i > 1 then
                    rowWidthPx = rowWidthPx + gapPx
                end
                if hPx > rowHeightPx then
                    rowHeightPx = hPx
                end
            end

            containerWidthPx = math.max(containerWidthPx, rowWidthPx)
            if orderIndex > 1 then
                containerHeightPx = containerHeightPx + gapPx
            end
            local rm = rowMetrics[row]
            if not rm then
                rm = {}
                rowMetrics[row] = rm
            end
            rm.widthPx = rowWidthPx
            rm.heightPx = rowHeightPx
            rm.topPx = containerHeightPx
            containerHeightPx = containerHeightPx + rowHeightPx
        end

        local contentWidthPx = containerWidthPx
        if containerWidthPx % 2 ~= 0 then
            containerWidthPx = containerWidthPx + 1
        end

        if isEssential then
            CDM._essentialContentWidth = PixelsToUIForRegion(contentWidthPx, container)
            CDM._essentialLeftPadPx = containerWidthPx - contentWidthPx
        end

        if containerWidthPx > 0 and containerHeightPx > 0 then
            containerWidth = PixelsToUIForRegion(containerWidthPx, container)
            containerHeight = PixelsToUIForRegion(containerHeightPx, container)
        end

        ResizeLayoutContainerIfAllowed(container, inCombat, containerWidth, containerHeight)

        for _, row in ipairs(rowOrderSeen) do
            local bucket = rowBuckets[row]
            local metrics = rowMetrics[row]
            local leftPadPx = math_floor(math.max(0, (containerWidthPx - metrics.widthPx)) * 0.5)
            local cursorPx = leftPadPx
            local yPx = -(metrics.topPx or 0)

            for _, placement in ipairs(bucket) do
                local frame = placement.frame
                PlaceIconTopLeft(frame, container, cursorPx, yPx, true, container)
                cursorPx = cursorPx + (placement._wPx or 0) + gapPx
            end
        end
    else
        ResizeLayoutContainerIfAllowed(container, inCombat, containerWidth, containerHeight)

        for _, placement in ipairs(placements) do
            local frame = placement.frame
            PlaceIconTopLeft(frame, container, placement.x or 0, placement.y or 0, false)
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

    if missingDataCount > 0 and not self.pendingSpecChange and not self.pendingTalentChange then
        QueueReanchorRetry(self, vName, 0.05)
    end

end

function CDM:GetEssentialContentWidth()
    return self._essentialContentWidth or 0
end

function CDM:GetEssentialContentCenterX()
    local essContainer = self.anchorContainers and self.anchorContainers[VIEWERS.ESSENTIAL]
    if not essContainer then return nil end
    local cx = select(1, essContainer:GetCenter())
    if not cx then return nil end
    local padPx = self._essentialLeftPadPx or 0
    local onePixel = CDM_C.GetPixelSizeForRegion(essContainer) or 1
    return cx - padPx * 0.5 * onePixel
end
