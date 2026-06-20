local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local L = CDM.L
local CDM_C = CDM.CONST

local ResolveBaseSpellID = CDM.GetBaseSpellID

local GetConfigValue = CDM_C.GetConfigValue

local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local HalfFloor = Pixel.HalfFloor
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_ceil = math.ceil
local table_sort = table.sort
local table_wipe = table.wipe
local select = select
local InCombatLockdown = InCombatLockdown

local VIEWERS = CDM_C.VIEWERS
local DEFAULT_SIZE_ESS = { w = 46, h = 40 }
local DEFAULT_SIZE_BUFF = { w = 40, h = 36 }

local function GetSnappedMetrics(size, spacing)
    local itemW = math_max(Pixel.GetSize(), Snap(size and size.w or 1))
    local itemH = math_max(Pixel.GetSize(), Snap(size and size.h or 1))
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
    return Pixel.HalfFloor(containerWidth or rowWidth or 0) - Pixel.HalfFloor(rowWidth or 0)
end

local function CenteredRowXForCol(col, itemW, gap, containerWidth, rowWidth)
    return CenteredRowLeft(containerWidth, rowWidth) + (col * (itemW + gap))
end

local function LayoutPosition(row, col, itemW, itemH, x, y, countInRow)
    return row, col, itemW, itemH, x, -y, countInRow
end

local function HasPositiveLimit(value)
    return value and value > 0
end

local function GetLayoutConfig()
    local df = CDM.defaults or {}
    local utilityWrap = GetConfigValue("utilityWrap", df.utilityWrap)
    local utilityUnlock = utilityWrap and GetConfigValue("utilityUnlock", df.utilityUnlock)
    return {
        sizeEssRow1     = GetConfigValue("sizeEssRow1", df.sizeEssRow1) or DEFAULT_SIZE_ESS,
        sizeEssRow2     = GetConfigValue("sizeEssRow2", df.sizeEssRow2) or DEFAULT_SIZE_ESS,
        sizeUtility     = GetConfigValue("sizeUtility", df.sizeUtility) or DEFAULT_SIZE_ESS,
        sizeBuff        = GetConfigValue("sizeBuff", df.sizeBuff) or DEFAULT_SIZE_BUFF,
        spacing         = GetConfigValue("spacing", df.spacing) or 1,
        maxRowEss       = GetConfigValue("maxRowEss", df.maxRowEss) or 9,
        utilityYOffset  = GetConfigValue("utilityYOffset", df.utilityYOffset) or 0,
        maxRowUtil      = utilityWrap and GetConfigValue("maxRowUtil", df.maxRowUtil) or 0,
        utilityVertical = utilityUnlock and GetConfigValue("utilityVertical", df.utilityVertical) or false,
        utilityXOffset  = utilityUnlock and GetConfigValue("utilityXOffset", df.utilityXOffset) or 0,
    }
end

local function ComputeGridPosition(index, total, maxPerRow, size, spacing)
    if not maxPerRow or maxPerRow <= 0 then
        maxPerRow = total
    end
    local row = math_ceil(index / maxPerRow)
    local col = (index - 1) % maxPerRow
    local countInRow = math_min(maxPerRow, total - (row - 1) * maxPerRow)
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

local function ComputeEssentialOrUtilityPosition(index, total, isEssential, sizeEssRow1, sizeEssRow2, sizeUtility, spacing, maxRowEss, maxRowUtil, utilityVertical, preUtilW, preUtilH, preUtilGap)
    if isEssential then
        local row1W, row1H, gap = GetSnappedMetrics(sizeEssRow1, spacing)
        local row2W, row2H = GetSnappedMetrics(sizeEssRow2, spacing)
        local row1Count = math_min(maxRowEss, total)
        local row2Count = math_max(0, total - maxRowEss)
        local row1Width = RowWidth(row1Count, row1W, gap)
        local row2Width = RowWidth(row2Count, row2W, gap)
        local cWidth = math_max(row1Width, row2Width)

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
    if preUtilW then
        utilW, utilH, gap = preUtilW, preUtilH, preUtilGap
    else
        utilW, utilH, gap = GetSnappedMetrics(sizeUtility, spacing)
    end

    if utilityVertical and HasPositiveLimit(maxRowUtil) then
        local colIndex = math_floor((index - 1) / maxRowUtil)
        local rowInCol = (index - 1) % maxRowUtil
        local iconsInThisCol = math_min(maxRowUtil, total - colIndex * maxRowUtil)
        local x = colIndex * (utilW + gap)
        local y = (iconsInThisCol - 1 - rowInCol) * (utilH + gap)
        return LayoutPosition(colIndex + 1, rowInCol, utilW, utilH, x, y, iconsInThisCol)
    end

    if HasPositiveLimit(maxRowUtil) and maxRowUtil < total then
        local row1Count = maxRowUtil
        local row2Count = total - maxRowUtil
        local row1Width = RowWidth(row1Count, utilW, gap)
        local row2Width = RowWidth(row2Count, utilW, gap)
        local cWidth = math_max(row1Width, row2Width)
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
        return row1W, row1H
    end
    local row1Count = math_min(maxRowEss, total)
    local row2Count = math_max(0, total - maxRowEss)
    local r1Width = RowWidth(row1Count, row1W, gap)
    local r2Width = RowWidth(row2Count, row2W, gap)
    local cWidth = math_max(r1Width, r2Width)
    local cHeight = row1H
    if row2Count > 0 then
        cHeight = row1H + gap + row2H
    end
    return cWidth, cHeight
end

local function ComputeUtilityContainerSize(total, sizeUtility, spacing, maxRowUtil, utilityVertical)
    local utilW, utilH, gap = GetSnappedMetrics(sizeUtility, spacing)
    if total <= 0 then
        return utilW, utilH
    end
    if utilityVertical and HasPositiveLimit(maxRowUtil) then
        local numCols = math_ceil(total / maxRowUtil)
        local tallestCol = math_min(maxRowUtil, total)
        local cWidth = RowWidth(numCols, utilW, gap)
        local cHeight = RowWidth(tallestCol, utilH, gap)
        return cWidth, cHeight
    end

    if HasPositiveLimit(maxRowUtil) and maxRowUtil < total then
        local row2Count = total - maxRowUtil
        local r1Width = RowWidth(maxRowUtil, utilW, gap)
        local r2Width = RowWidth(row2Count, utilW, gap)
        local cWidth = math_max(r1Width, r2Width)
        local cHeight = (2 * utilH) + gap
        return cWidth, cHeight
    end
    local cWidth = RowWidth(total, utilW, gap)
    local cHeight = utilH
    return cWidth, cHeight
end

local function ToSortNumber(value, fallback)
    return value or fallback
end

local function CompareByLayoutIndex(a, b)
    return ToSortNumber(a.layoutIndex, 0) < ToSortNumber(b.layoutIndex, 0)
end

local SELF_POINT_CACHE = {}
do
    local function xSide(p)
        if p == "LEFT" or p == "TOPLEFT" or p == "BOTTOMLEFT" then return "LEFT" end
        if p == "RIGHT" or p == "TOPRIGHT" or p == "BOTTOMRIGHT" then return "RIGHT" end
        return "CENTER"
    end
    local function ySide(p)
        if p == "TOP" or p == "TOPLEFT" or p == "TOPRIGHT" then return "TOP" end
        if p == "BOTTOM" or p == "BOTTOMLEFT" or p == "BOTTOMRIGHT" then return "BOTTOM" end
        return "CENTER"
    end
    local function compose(x, y)
        if y == "TOP" then
            if x == "LEFT" then return "TOPLEFT" end
            if x == "RIGHT" then return "TOPRIGHT" end
            return "TOP"
        elseif y == "BOTTOM" then
            if x == "LEFT" then return "BOTTOMLEFT" end
            if x == "RIGHT" then return "BOTTOMRIGHT" end
            return "BOTTOM"
        end
        if x == "LEFT" then return "LEFT" end
        if x == "RIGHT" then return "RIGHT" end
        return "CENTER"
    end
    for _, a in ipairs({"CENTER","TOP","BOTTOM","LEFT","RIGHT","TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT"}) do
        SELF_POINT_CACHE[a] = {}
        for _, g in ipairs({"RIGHT","LEFT","UP","DOWN","CENTER_H","CENTER_V"}) do
            local r = a
            if g ~= "CENTER_H" and g ~= "CENTER_V" then
                local xs, ys = xSide(a), ySide(a)
                if g == "RIGHT" then xs = "LEFT"
                elseif g == "LEFT" then xs = "RIGHT"
                elseif g == "DOWN" then ys = "TOP"
                elseif g == "UP" then ys = "BOTTOM"
                end
                r = compose(xs, ys)
            end
            SELF_POINT_CACHE[a][g] = r
        end
    end
end

local function DeriveSelfPoint(anchorPoint, grow)
    local byAnchor = SELF_POINT_CACHE[anchorPoint]
    return (byAnchor and byAnchor[grow]) or anchorPoint or "CENTER"
end

local function SetCdmAnchor(frame, point, relativeTo, relativePoint, x, y)
    local sx = Snap(x or 0)
    local sy = Snap(y or 0)
    local a = frame.cdmAnchor
    if a and a[1] == point and a[2] == relativeTo and a[3] == relativePoint
       and a[4] == sx and a[5] == sy then
        return false
    end
    if not a then
        a = {}
        frame.cdmAnchor = a
    end
    a[1], a[2], a[3] = point, relativeTo, relativePoint
    a[4], a[5] = sx, sy
    return true
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
    local sp = selfPoint or "CENTER"
    local ap = anchorPoint or "CENTER"
    if not SetCdmAnchor(frame, sp, container, ap, x, y) then return end
    frame:ClearAllPoints()
    Pixel.SetPoint(frame, sp, container, ap, x or 0, y or 0)
end

local function PlaceFrame(frame, container, selfPoint, anchorPoint, x, y)
    if not SetCdmAnchor(frame, selfPoint, container, anchorPoint, x, y) then return end
    frame:ClearAllPoints()
    Pixel.SetPoint(frame, selfPoint, container, anchorPoint, x, y)
end

local function OverrideCooldownText(t, pixelSize, color)
    if not t then return end
    if pixelSize then
        local fp, _, ff = t:GetFont()
        if fp then t:SetFont(fp, pixelSize, ff) end
    end
    if color then
        t:SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
end

local nextStableSortID = 0

local function GetStableFrameSortID(frame)
    local sortID = frame.cdmStableSortID
    if sortID then
        return sortID
    end

    nextStableSortID = nextStableSortID + 1
    frame.cdmStableSortID = nextStableSortID
    return nextStableSortID
end

local utilityVisibleCountCache = {
    valid = false,
    count = 0,
}

function CDM:InvalidateUtilityVisibleCountCache()
    utilityVisibleCountCache.valid = false
end

local function ComputeUtilityVisibleCount()
    local utilityCount = 0
    local viewer = _G[VIEWERS.UTILITY]
    if viewer and viewer.itemFramePool then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if frame:IsShown() then
                local spellID = ResolveBaseSpellID(frame)
                if spellID then
                    utilityCount = utilityCount + 1
                end
            end
        end
    end
    return utilityCount
end

local function GetUtilityVisibleCount()
    if utilityVisibleCountCache.valid then
        return utilityVisibleCountCache.count
    end

    local count = ComputeUtilityVisibleCount()
    utilityVisibleCountCache.count = count
    utilityVisibleCountCache.valid = true
    return count
end

function CDM:GetUtilityVisibleCount()
    return GetUtilityVisibleCount()
end

local function SetUtilityAnchor(utilContainer, essContainer, utilHalfW, utilityXOffset, utilityYOffset, spacing)
    local essHalfW = HalfFloor(essContainer:GetWidth() or 0)
    Pixel.SetPoint(utilContainer, "TOPLEFT", essContainer, "BOTTOMLEFT", essHalfW - utilHalfW + utilityXOffset, -spacing + utilityYOffset)
end

local function AnchorEssentialContainer(frame, relativePoint, x, y)
    local halfW = HalfFloor(frame:GetWidth() or 0)
    Pixel.SetPoint(frame, "TOPLEFT", UIParent, relativePoint, x - halfW, y)
end

local function AnchorBuffContainer(frame, relativePoint, x, y)
    Pixel.SetPoint(frame, "BOTTOM", UIParent, relativePoint, x, y or 0)
end

local function EnsureDBSubTable(parent, key)
    local t = parent[key]
    if not t then
        t = {}
        parent[key] = t
    end
    return t
end

local function SetRegionBlendMode(blendMode, ...)
    local n = select("#", ...)
    for i = 1, n do
        local region = select(i, ...)
        if region and region:IsObjectType("Texture") then
            region:SetBlendMode(blendMode)
        end
    end
end
CDM.SetRegionBlendMode = SetRegionBlendMode

function CDM:UpdateUtilityContainerPosition()
    if InCombatLockdown() then
        CDM.combatDirtyViewers[VIEWERS.UTILITY] = true
        return
    end

    local essContainer = self.anchorContainers[VIEWERS.ESSENTIAL]
    local utilContainer = self.anchorContainers[VIEWERS.UTILITY]
    if not essContainer or not utilContainer then return end

    local cfg = GetLayoutConfig()
    local utilityCount = GetUtilityVisibleCount()
    local containerWidth, containerHeight = ComputeUtilityContainerSize(
        utilityCount, cfg.sizeUtility, cfg.spacing, cfg.maxRowUtil, cfg.utilityVertical
    )
    utilContainer:SetSize(Snap(containerWidth), Snap(containerHeight))

    self:ReanchorContainer(VIEWERS.UTILITY)
end

local FALLBACK_POSITION = {
    point = "CENTER",
    x = 0,
    y = -201,
}

local FALLBACK_BUFF_POSITION = {
    point = "CENTER",
    x = 0,
    y = -149,
}

local FALLBACK_BUFF_BAR_POSITION = {
    point = "CENTER",
    x = 0,
    y = -324,
}

local function GetPositionSettings(viewerName, layoutName)
    local defaultY = -201
    local fallbackPosition = FALLBACK_POSITION
    if viewerName == VIEWERS.BUFF then
        defaultY = -149
        fallbackPosition = FALLBACK_BUFF_POSITION
    elseif viewerName == VIEWERS.BUFF_BAR then
        defaultY = -324
        fallbackPosition = FALLBACK_BUFF_BAR_POSITION
    end

    local db = CDM.db
    if not db then
        return fallbackPosition
    end

    local editModePositions = EnsureDBSubTable(db, "editModePositions")
    local viewerTable = EnsureDBSubTable(editModePositions, viewerName)

    if not viewerTable[layoutName] then
        viewerTable[layoutName] = {
            point = "CENTER",
            x = 0,
            y = defaultY
        }
    end

    return viewerTable[layoutName]
end

function CDM:UpdateBuffContainerPosition()
    local buffContainer = self.anchorContainers[VIEWERS.BUFF]
    if not buffContainer then return end

    local db = CDM.db
    if db and db.moveBuffsDown and db.resourcesEnabled ~= false then
        local fallback = db.moveBuffsDownFallback or "lastResource"
        local allowHidden = fallback == "lastResource"
        local topBar = CDM.ResolveResourcesAnchor(allowHidden)
        local offsetY = tonumber(db.moveBuffsDownOffset) or 0
        if topBar then
            buffContainer:ClearAllPoints()
            Pixel.SetPoint(buffContainer, "BOTTOM", topBar, "TOP", 0, offsetY)
            return
        end
        if fallback == "essential" then
            local essContainer = self.anchorContainers[VIEWERS.ESSENTIAL]
            if essContainer and essContainer:IsShown() then
                buffContainer:ClearAllPoints()
                Pixel.SetPoint(buffContainer, "BOTTOM", essContainer, "TOP", 0, offsetY)
                return
            end
        end
    end

    local savedPos = GetPositionSettings(VIEWERS.BUFF, "Default")

    buffContainer:ClearAllPoints()
    AnchorBuffContainer(buffContainer, savedPos.point, savedPos.x, savedPos.y)
end

function CDM:ReanchorContainer(vName)
    if InCombatLockdown() then return end
    local container = self.anchorContainers and self.anchorContainers[vName]
    if not container then return end

    if vName == VIEWERS.ESSENTIAL then
        local savedPos = GetPositionSettings(VIEWERS.ESSENTIAL, "Default")
        container:ClearAllPoints()
        AnchorEssentialContainer(container, savedPos.point, savedPos.x, savedPos.y)
    elseif vName == VIEWERS.UTILITY then
        local essContainer = self.anchorContainers[VIEWERS.ESSENTIAL]
        if not essContainer then return end
        local cfg = GetLayoutConfig()
        local utilHalfW = HalfFloor(container:GetWidth())
        container:ClearAllPoints()
        SetUtilityAnchor(container, essContainer, utilHalfW, cfg.utilityXOffset, cfg.utilityYOffset, cfg.spacing)
    end
end

function CDM:UpdateEssentialContainerPosition()
    if InCombatLockdown() then
        CDM.combatDirtyViewers[VIEWERS.ESSENTIAL] = true
        return
    end

    self:ReanchorContainer(VIEWERS.ESSENTIAL)
    self:UpdateUtilityContainerPosition()
end

local function CreateBaseContainer(name)
    local container = CreateFrame("Frame", name, UIParent)
    container:SetFrameLevel(10)
    return container
end

function CDM:CreateEssentialAnchorContainer()
    local cfg = GetLayoutConfig()
    local container = CreateBaseContainer(VIEWERS.ESSENTIAL .. "_CDM_Container")
    container:SetSize(Snap(400), Snap(cfg.sizeEssRow1.h))

    self.anchorContainers[VIEWERS.ESSENTIAL] = container
    self:UpdateEditModeSelectionOverlay(VIEWERS.ESSENTIAL)

    local savedPos = GetPositionSettings(VIEWERS.ESSENTIAL, "Default")
    container:ClearAllPoints()
    AnchorEssentialContainer(container, savedPos.point, savedPos.x, savedPos.y)

    container:Show()
    return container
end

function CDM:CreateBuffAnchorContainer()
    local cfg = GetLayoutConfig()
    local container = CreateBaseContainer(VIEWERS.BUFF .. "_CDM_Container")
    container:SetSize(Pixel.SnapEven(400), Snap(cfg.sizeBuff.h))

    self.anchorContainers[VIEWERS.BUFF] = container
    self:UpdateEditModeSelectionOverlay(VIEWERS.BUFF)

    local savedPos = GetPositionSettings(VIEWERS.BUFF, "Default")
    container:ClearAllPoints()
    AnchorBuffContainer(container, savedPos.point, savedPos.x, savedPos.y)

    container:Show()
    return container
end

function CDM:CreateBuffBarAnchorContainer()
    local container = CreateBaseContainer(VIEWERS.BUFF_BAR .. "_CDM_Container")
    container:SetSize(300, 200)

    self.anchorContainers[VIEWERS.BUFF_BAR] = container
    self:UpdateEditModeSelectionOverlay(VIEWERS.BUFF_BAR)
    self:UpdateBuffBarContainerPosition()

    container:Show()
    return container
end

function CDM:CreateUtilityAnchorContainer()
    local container = CreateBaseContainer(VIEWERS.UTILITY .. "_CDM_Container")

    self.anchorContainers[VIEWERS.UTILITY] = container
    self:UpdateEditModeSelectionOverlay(VIEWERS.UTILITY)
    self:UpdateUtilityContainerPosition()

    container:Show()
    return container
end

function CDM:GetAnchorContainer(viewer)
    return self.anchorContainers[viewer:GetName()]
end

local function makeSequentialPool()
    return { items = {}, slots = {}, count = 0 }
end

local function ResetPool(pool)
    for i = 1, pool.count do pool.items[i] = nil end
    pool.count = 0
end

local function AcquireFromPool(pool)
    local n = pool.count + 1
    pool.count = n
    local p = pool.slots[n]
    if not p then
        p = {}
        pool.slots[n] = p
    end
    pool.items[n] = p
    return p
end

local recordPool = makeSequentialPool()
local placementPool = makeSequentialPool()
local tempTrinketReorder = {}

local scratchRowBuckets = {}
local scratchRowBucketPool = {}
local scratchRowBucketPoolCount = 0
local scratchRowOrderSeen = {}
local scratchRowOrderSeenCount = 0
local scratchRowMetrics = {}
local scratchRowMetricPool = {}
local scratchRowMetricPoolCount = 0

local function ResizeLayoutContainerIfAllowed(container, inCombat, width, height)
    if inCombat or not container or not width or not height then
        return
    end
    container:SetSize(Snap(width), Snap(height))
end

local function PlaceIconTopLeft(frame, container, x, y, viewer)
    if viewer and frame:GetParent() ~= viewer then
        frame:SetParent(UIParent)
        frame.cdmAnchor = nil
    end
    if SetCdmAnchor(frame, "TOPLEFT", container, "TOPLEFT", x, y) then
        frame:ClearAllPoints()
        Pixel.SetPoint(frame, "TOPLEFT", container, "TOPLEFT", x or 0, y or 0)
    end
    frame:Show()
end

local function PushIconPositionRecord(frame, layoutIndex, sortID)
    local record = AcquireFromPool(recordPool)
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

local function CollectAndOrderRecords(icons, isEssential, maxRowEss, injFrames)
    ResetPool(recordPool)
    local records = recordPool.items

    for _, frame in ipairs(icons) do
        local spellID = ResolveBaseSpellID(frame)
        if spellID or frame.cooldownInfo then
            PushIconPositionRecord(frame, ToSortNumber(frame.layoutIndex, 0), GetStableFrameSortID(frame))
        end
    end

    local db = CDM.db or {}
    local injRow = db.trinketsEssentialRow or 1
    local injPos = db.trinketsEssentialPosition or "end"
    local injectedTrinketCount = 0

    if injFrames then
        for i, tFrame in ipairs(injFrames) do
            local record = AcquireFromPool(recordPool)
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
            local essOnlyCount = recordPool.count - injectedTrinketCount
            maxRowEss = math_min(maxRowEss, essOnlyCount)
        end
    end

    local totalIcons = recordPool.count
    if totalIcons > 1 then
        table_sort(records, CompareIconPositionRecords)
    end

    if injectedTrinketCount > 0 then
        if injRow == 2 and injPos == "start" then
            table_wipe(tempTrinketReorder)
            for i = 1, injectedTrinketCount do
                tempTrinketReorder[i] = records[i]
            end
            for i = 1, maxRowEss do
                records[i] = records[injectedTrinketCount + i]
            end
            for i = 1, injectedTrinketCount do
                records[maxRowEss + i] = tempTrinketReorder[i]
            end

        elseif injRow == 1 and injPos == "end" and totalIcons > maxRowEss then
            local insertPos = math_max(1, maxRowEss - injectedTrinketCount + 1)
            table_wipe(tempTrinketReorder)
            for i = 1, injectedTrinketCount do
                tempTrinketReorder[i] = records[totalIcons - injectedTrinketCount + i]
            end
            for i = totalIcons - injectedTrinketCount, insertPos, -1 do
                records[i + injectedTrinketCount] = records[i]
            end
            for i = 1, injectedTrinketCount do
                records[insertPos + i - 1] = tempTrinketReorder[i]
            end
        end
    end

    return totalIcons, maxRowEss
end

local function LayoutMeasuredRows(self, container, viewer, vName, isEssential, sizeEssRow1, sizeEssRow2, sizeUtility, gap, inCombat)
    table_sort(scratchRowOrderSeen)

    local pixelSize = Pixel.GetSize()
    local measuredContainerWidth = 0
    local measuredContainerHeight = 0

    for orderIndex, row in ipairs(scratchRowOrderSeen) do
        local bucket = scratchRowBuckets[row]
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
        local rm = scratchRowMetrics[row]
        if not rm then
            if scratchRowMetricPoolCount > 0 then
                rm = scratchRowMetricPool[scratchRowMetricPoolCount]
                scratchRowMetricPool[scratchRowMetricPoolCount] = nil
                scratchRowMetricPoolCount = scratchRowMetricPoolCount - 1
            else
                rm = {}
            end
            scratchRowMetrics[row] = rm
        end
        rm.width = rowWidth
        rm.height = rowHeight
        rm.top = measuredContainerHeight
        measuredContainerHeight = measuredContainerHeight + rowHeight
    end

    local containerWidth = Snap(measuredContainerWidth)
    local containerHeight = Snap(measuredContainerHeight)

    ResizeLayoutContainerIfAllowed(container, inCombat, containerWidth, containerHeight)
    if not inCombat then
        self:ReanchorContainer(vName)
    end

    for _, row in ipairs(scratchRowOrderSeen) do
        local bucket = scratchRowBuckets[row]
        local metrics = scratchRowMetrics[row]
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
end

function CDM:PositionEssentialOrUtilityIcons(icons, viewer, vName)
    local cfg = GetLayoutConfig()
    local maxRowEss = cfg.maxRowEss
    local isEssential = (vName == VIEWERS.ESSENTIAL)

    local injFrames = isEssential and CDM.GetTrinketInjectionFrames and CDM.GetTrinketInjectionFrames() or nil

    if #icons == 0 and not injFrames then
        return
    end

    local container = self:GetAnchorContainer(viewer)
    if not container then return end

    local totalIcons
    totalIcons, maxRowEss = CollectAndOrderRecords(icons, isEssential, maxRowEss, injFrames)

    ResetPool(placementPool)
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

    local useMeasuredHorizontalLayout = isEssential or (not cfg.utilityVertical)

    local preUtilW, preUtilH, preUtilGap
    if not useMeasuredHorizontalLayout then
        preUtilW, preUtilH, preUtilGap = GetSnappedMetrics(cfg.sizeUtility, cfg.spacing)
    end

    local records = recordPool.items
    for index, record in ipairs(records) do
        local frame = record.frame

        if useMeasuredHorizontalLayout then
            local row = GetRowForIndex(index, totalIcons, isEssential, maxRowEss, cfg.maxRowUtil, cfg.utilityVertical)
            frame.cdmRow = row
            self:ApplyStyle(frame, vName)
            local placement = AcquireFromPool(placementPool)
            placement.frame = frame
            placement.row = row
            local bucket = scratchRowBuckets[row]
            if not bucket then
                if scratchRowBucketPoolCount > 0 then
                    bucket = scratchRowBucketPool[scratchRowBucketPoolCount]
                    scratchRowBucketPool[scratchRowBucketPoolCount] = nil
                    scratchRowBucketPoolCount = scratchRowBucketPoolCount - 1
                else
                    bucket = {}
                end
                scratchRowBuckets[row] = bucket
                scratchRowOrderSeenCount = scratchRowOrderSeenCount + 1
                scratchRowOrderSeen[scratchRowOrderSeenCount] = row
            end
            bucket[#bucket + 1] = placement
        else
            local row, _, _, _, x, y = ComputeEssentialOrUtilityPosition(
                index, totalIcons, isEssential, cfg.sizeEssRow1, cfg.sizeEssRow2, cfg.sizeUtility, cfg.spacing, maxRowEss, cfg.maxRowUtil, cfg.utilityVertical, preUtilW, preUtilH, preUtilGap
            )
            frame.cdmRow = row
            self:ApplyStyle(frame, vName)
            local placement = AcquireFromPool(placementPool)
            placement.frame = frame
            placement.row = row
            placement.x = x
            placement.y = y
        end
    end

    local inCombat = InCombatLockdown()
    local gap = Snap(cfg.spacing or 0)

    if useMeasuredHorizontalLayout and placementPool.count > 0 then
        LayoutMeasuredRows(self, container, viewer, vName, isEssential, cfg.sizeEssRow1, cfg.sizeEssRow2, cfg.sizeUtility, gap, inCombat)
    else
        local containerWidth, containerHeight
        if isEssential then
            containerWidth, containerHeight = ComputeEssentialContainerSize(
                totalIcons, cfg.sizeEssRow1, cfg.sizeEssRow2, cfg.spacing, maxRowEss
            )
        else
            containerWidth, containerHeight = ComputeUtilityContainerSize(
                totalIcons, cfg.sizeUtility, cfg.spacing, cfg.maxRowUtil, cfg.utilityVertical
            )
        end

        ResizeLayoutContainerIfAllowed(container, inCombat, containerWidth, containerHeight)
        if not inCombat then
            self:ReanchorContainer(vName)
        end

        for _, placement in ipairs(placementPool.items) do
            local frame = placement.frame
            PlaceIconTopLeft(frame, container, placement.x, placement.y, viewer)
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
    local c = self.anchorContainers[VIEWERS.ESSENTIAL]
    return c and c:GetWidth() or 0
end

function CDM:GetUtilityContentWidth()
    local c = self.anchorContainers[VIEWERS.UTILITY]
    return c and c:GetWidth() or 0
end

local function CalculateEssentialRow1Width()
    local cfg = GetLayoutConfig()

    local contentWidth = CDM:GetEssentialContentWidth()
    if contentWidth > 0 then
        return contentWidth
    end

    local viewer = _G[VIEWERS.ESSENTIAL]
    if viewer and viewer.itemFramePool then
        local activeCount = 0
        for frame in viewer.itemFramePool:EnumerateActive() do
            if frame:IsShown() then
                local spellID = ResolveBaseSpellID(frame)
                if spellID then
                    activeCount = activeCount + 1
                end
            end
        end

        if activeCount > 0 then
            local row1Count = math_min(activeCount, cfg.maxRowEss)
            return (row1Count * cfg.sizeEssRow1.w) + ((row1Count - 1) * cfg.spacing)
        end
    end

    local fallbackCount = math_max(cfg.maxRowEss, 1)
    return (fallbackCount * cfg.sizeEssRow1.w) + ((fallbackCount - 1) * cfg.spacing)
end

CDM.CalculateEssentialRow1Width = CalculateEssentialRow1Width


function CDM:UpdateBuffBarContainerPosition()
    local container = self.anchorContainers and self.anchorContainers[VIEWERS.BUFF_BAR]
    if not container then return end

    local db = CDM.db or {}
    local savedPos = GetPositionSettings(VIEWERS.BUFF_BAR, "Default")
    local growDirection = db.buffBarGrowDirection or "DOWN"
    local edgeAnchor = growDirection == "DOWN" and "TOPLEFT" or "BOTTOMLEFT"
    local screenPoint = savedPos.point or "CENTER"
    local snappedY = Snap(savedPos.y or 0)

    local xOff = Snap(savedPos.x or 0)
    local halfW = HalfFloor(container:GetWidth() or 0)

    container:ClearAllPoints()
    Pixel.SetPoint(container, edgeAnchor, UIParent, screenPoint, xOff - halfW, snappedY)
end

local function SetupBarFrame(frame, containerLevel, frameWidth, barHeight)
    local barLevel = containerLevel + 1
    if frame.cdmBarLevel ~= barLevel then
        frame:SetFrameLevel(barLevel)
        if frame.Bar then frame.Bar:SetFrameLevel(barLevel + 1) end
        if frame.Icon then frame.Icon:SetFrameLevel(barLevel + 2) end
        frame.cdmBarLevel = barLevel
    end
    Pixel.SetSize(frame, frameWidth, barHeight)
end

local function ApplyBarAnchor(frame, point, relativeTo, relativePoint, x, y)
    local sx = Snap(x or 0)
    local sy = Snap(y or 0)
    local a = frame.cdmBarAnchor
    if a and a[1] == point and a[2] == relativeTo and a[3] == relativePoint
       and a[4] == sx and a[5] == sy then
        return
    end
    if not a then
        a = {}
        frame.cdmBarAnchor = a
    end
    a[1] = point
    a[2] = relativeTo
    a[3] = relativePoint
    a[4] = sx
    a[5] = sy
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, sx, sy)
end

local tempBars = {}

function CDM:PositionBuffBarFrames(viewer, vName, frames)
    if not viewer or not viewer.itemFramePool then return end

    local container = self:GetAnchorContainer(viewer)
    if not container then return end

    local db = CDM.db or {}
    local barWidth = db.buffBarWidth ~= nil and db.buffBarWidth or 0
    local barHeight = Snap(db.buffBarHeight or 20)
    local spacing = Snap(db.buffBarSpacing ~= nil and db.buffBarSpacing or 2)
    local growDirection = db.buffBarGrowDirection or "DOWN"

    local effectiveWidth = barWidth
    if barWidth == 0 then
        effectiveWidth = CalculateEssentialRow1Width()
    end
    effectiveWidth = Snap(effectiveWidth)

    table_wipe(tempBars)
    local bars = tempBars
    if frames then
        for _, frame in ipairs(frames) do
            if frame:IsShown() then
                bars[#bars + 1] = frame
            elseif frame.cooldownInfo then
                local spellOv = CDM.ResolveBarSpellOverride(frame, nil)
                self:ApplyBarStyle(frame, vName, nil, nil, nil, nil, spellOv)
            end
        end
    else
        for frame in viewer.itemFramePool:EnumerateActive() do
            if frame:IsShown() then
                bars[#bars + 1] = frame
            elseif frame.cooldownInfo then
                local spellOv = CDM.ResolveBarSpellOverride(frame, nil)
                self:ApplyBarStyle(frame, vName, nil, nil, nil, nil, spellOv)
            end
        end
    end

    if #bars > 1 then
        table_sort(bars, CompareByLayoutIndex)
    end

    if #bars == 0 then
        Pixel.SetSize(container, effectiveWidth, barHeight)
        self:UpdateBuffBarContainerPosition()
        return
    end

    local containerLevel = container:GetFrameLevel()

    local offset = 0
    local containerHeight = 0
    for i, frame in ipairs(bars) do
        local spellOv = CDM.ResolveBarSpellOverride(frame, nil)
        local fh
        if spellOv and type(spellOv.barHeight) == "number" and spellOv.barHeight > 0 then
            fh = Snap(spellOv.barHeight)
        else
            fh = barHeight
        end

        SetupBarFrame(frame, containerLevel, effectiveWidth, fh)

        if growDirection == "DOWN" then
            ApplyBarAnchor(frame, "TOPLEFT", container, "TOPLEFT", 0, -offset)
        else
            ApplyBarAnchor(frame, "BOTTOMLEFT", container, "BOTTOMLEFT", 0, offset)
        end
        self:ApplyBarStyle(frame, vName, nil, effectiveWidth, fh, nil, spellOv)

        offset = offset + fh + spacing
        containerHeight = containerHeight + fh + (i > 1 and spacing or 0)
    end

    Pixel.SetSize(container, effectiveWidth, math_max(barHeight, containerHeight))
    self:UpdateBuffBarContainerPosition()
end

CDM._LayoutCtx = {
    DeriveSelfPoint        = DeriveSelfPoint,
    GetStableFrameSortID   = GetStableFrameSortID,
    PositionFrameAtSlot    = PositionFrameAtSlot,
    PlaceFrame             = PlaceFrame,
    OverrideCooldownText   = OverrideCooldownText,
    ToSortNumber           = ToSortNumber,
    RowWidth               = RowWidth,
    GetSnappedMetrics      = GetSnappedMetrics,
    CenteredRowLeft        = CenteredRowLeft,
    SetupBarFrame          = SetupBarFrame,
    ApplyBarAnchor         = ApplyBarAnchor,
}

function CDM:InstallLayoutAcquireResetHook(v)
    hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
        itemFrame.cdmAnchor = nil
        itemFrame.cdmBarLevel = nil
        itemFrame.cdmBarAnchor = nil
    end)
end
