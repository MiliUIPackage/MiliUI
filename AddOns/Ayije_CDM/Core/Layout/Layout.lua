local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local L = CDM.L
local CDM_C = CDM.CONST

local GetFrameData = CDM.GetFrameData
local IsSafeNumber = CDM.IsSafeNumber
local GetBaseSpellID = CDM.GetBaseSpellID
local CheckBuffRegistryMatch = CDM.CheckBuffRegistryMatch
local ResolveBaseSpellID = GetBaseSpellID

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
    local result = Pixel.HalfFloor(containerWidth or rowWidth or 0) - Pixel.HalfFloor(rowWidth or 0)
    return result >= 0 and result or 0
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
            if frame.cooldownID then
                populated = populated + 1
            end
        end
    end
    return populated, total
end

CDM.CountPopulatedFrames = CountPopulatedFrames

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

local function SetCdmAnchor(fd, point, relativeTo, relativePoint, x, y)
    local a = fd.cdmAnchor
    if not a then
        a = {}
        fd.cdmAnchor = a
    end
    a[1] = point
    a[2] = relativeTo
    a[3] = relativePoint
    a[4] = Snap(x or 0)
    a[5] = Snap(y or 0)
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
    local fd = GetFrameData(frame)
    SetCdmAnchor(fd, sp, container, ap, x, y)
    Pixel.SetPoint(frame, sp, container, ap, x or 0, y or 0)
end

local function PlaceFrame(frame, container, selfPoint, anchorPoint, x, y)
    local fd = GetFrameData(frame)
    SetCdmAnchor(fd, selfPoint, container, anchorPoint, x, y)
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

local scratchCdFontRegions = {}

local function CollectFontRegions(target, ...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            target[#target + 1] = region
        end
    end
    return target
end

local function GetCooldownFontRegions(cd)
    table_wipe(scratchCdFontRegions)
    return CollectFontRegions(scratchCdFontRegions, cd:GetRegions())
end

local function OverrideCooldownRegions(cd, pixelSize, color)
    local regions = GetCooldownFontRegions(cd)
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

local function AnchorMainLayoutContainer(frame, isBuffContainer, relativePoint, x, y, yOffset)
    if not frame then
        return
    end

    if isBuffContainer then
        Pixel.SetPoint(frame, "BOTTOM", UIParent, relativePoint, x, (y or 0) + (yOffset or 0))
        return
    end

    local halfW = HalfFloor(frame:GetWidth() or 0)
    Pixel.SetPoint(frame, "TOPLEFT", UIParent, relativePoint, x - halfW, y)
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
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            region:SetBlendMode(blendMode)
        end
    end
end

function CDM:UpdateUtilityContainerPosition()
    if InCombatLockdown() then
        CDM.combatDirtyViewers[VIEWERS.UTILITY] = true
        return
    end

    local essContainer = self.anchorContainers[VIEWERS.ESSENTIAL]
    local utilContainer = self.anchorContainers[VIEWERS.UTILITY]
    local _, _, sizeUtility, _, spacing, _, utilityYOffset, maxRowUtil, utilityVertical, utilityXOffset = GetLayoutConfig()

    if not essContainer or not utilContainer then return end

    local utilityCount = GetUtilityVisibleCount()

    local containerWidth, containerHeight = ComputeUtilityContainerSize(
        utilityCount > 0 and utilityCount or 0, sizeUtility, spacing, maxRowUtil, utilityVertical
    )
    utilContainer:SetSize(Snap(containerWidth), Snap(containerHeight))

    local utilHalfW = HalfFloor(Snap(containerWidth))
    utilContainer:ClearAllPoints()
    SetUtilityAnchor(utilContainer, essContainer, utilHalfW, utilityXOffset, utilityYOffset, spacing)
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

local function GetPositionSettings(viewerName, layoutName)
    local db = CDM.db
    if not db then
        local fallbackPosition = FALLBACK_POSITION
        if viewerName == VIEWERS.BUFF then
            fallbackPosition = FALLBACK_BUFF_POSITION
        end
        return fallbackPosition
    end

    local editModePositions = EnsureDBSubTable(db, "editModePositions")
    local viewerTable = EnsureDBSubTable(editModePositions, viewerName)
    local defaultY = -201
    if viewerName == VIEWERS.BUFF then
        defaultY = -149
    end

    if not viewerTable[layoutName] then
        viewerTable[layoutName] = {
            point = "CENTER",
            x = 0,
            y = defaultY
        }
    end

    return viewerTable[layoutName]
end

local FALLBACK_BUFF_BAR_POSITION = {
    point = "CENTER",
    x = 0,
    y = -324
}

local function GetBuffBarPositionSettings()
    local db = CDM.db
    if not db then
        return FALLBACK_BUFF_BAR_POSITION
    end

    local editModePositions = EnsureDBSubTable(db, "editModePositions")
    local viewerTable = EnsureDBSubTable(editModePositions, VIEWERS.BUFF_BAR)
    if not viewerTable.Default then
        viewerTable.Default = {
            point = "CENTER",
            x = 0,
            y = -324
        }
    end
    return viewerTable.Default
end

function CDM:UpdateBuffContainerPosition()
    local buffContainer = self.anchorContainers[VIEWERS.BUFF]
    if not buffContainer then return end

    local db = CDM.db
    if db and db.moveBuffsDown and db.resourcesEnabled ~= false then
        local fallback = db.moveBuffsDownFallback or "lastResource"
        local allowHidden = fallback == "lastResource"
        local topBar = CDM.ResolveResourcesAnchor and CDM.ResolveResourcesAnchor(allowHidden)
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
    AnchorMainLayoutContainer(buffContainer, true, savedPos.point, savedPos.x, savedPos.y, 0)
end

function CDM:ReanchorContainer(vName)
    if InCombatLockdown() then return end
    local container = self.anchorContainers and self.anchorContainers[vName]
    if not container then return end

    if vName == VIEWERS.ESSENTIAL then
        local savedPos = GetPositionSettings(VIEWERS.ESSENTIAL, "Default")
        container:ClearAllPoints()
        AnchorMainLayoutContainer(container, false, savedPos.point, savedPos.x, savedPos.y)
    elseif vName == VIEWERS.UTILITY then
        local essContainer = self.anchorContainers[VIEWERS.ESSENTIAL]
        if not essContainer then return end
        local _, _, _, _, spacing, _, utilityYOffset, _, _, utilityXOffset = GetLayoutConfig()
        local utilHalfW = HalfFloor(container:GetWidth())
        container:ClearAllPoints()
        SetUtilityAnchor(container, essContainer, utilHalfW, utilityXOffset, utilityYOffset, spacing)
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

local function GetFramePointCoords(frame, point)
    if not frame or not point or not frame.GetLeft then return nil, nil end
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local centerX, centerY = frame:GetCenter()
    if not (left and right and top and bottom and centerX and centerY) then return nil, nil end

    if point == "CENTER" then return centerX, centerY
    elseif point == "TOP" then return centerX, top
    elseif point == "BOTTOM" then return centerX, bottom
    elseif point == "LEFT" then return left, centerY
    elseif point == "RIGHT" then return right, centerY
    elseif point == "TOPLEFT" then return left, top
    elseif point == "TOPRIGHT" then return right, top
    elseif point == "BOTTOMLEFT" then return left, bottom
    elseif point == "BOTTOMRIGHT" then return right, bottom
    end
    return centerX, centerY
end

local function ResolveDraggedCoords(frame, anchorPoint, relativePoint, x, y)
    local anchorX, anchorY = GetFramePointCoords(frame, anchorPoint)
    local relX, relY = GetFramePointCoords(UIParent, relativePoint)
    if anchorX and relX then
        return anchorX - relX, anchorY - relY
    end
    return x, y
end

local function SetupDraggableContainer(container, lockKey, overlayOpts)
    overlayOpts = overlayOpts or {}

    local function IsLocked()
        return CDM_C.GetConfigValue(lockKey, true) ~= false
    end

    local function IsEditModeActive()
        local editModeFrame = _G.EditModeManagerFrame
        return CDM.isEditModeActive or (editModeFrame and editModeFrame:IsShown())
    end

    local isLocked = IsLocked()
    if not InCombatLockdown() then
        container:SetMovable(not isLocked)
        container:EnableMouse(not isLocked)
    end
    container:SetClampedToScreen(true)
    container:RegisterForDrag("LeftButton")

    container:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() and not IsLocked() then
            self:StartMoving()
        end
    end)

    if not container.helperText then
        local helperText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        helperText:SetPoint("BOTTOM", container, "TOP", 0, 8)
        helperText:SetText(L["Click and drag to move - /cdm > Positions to lock"])
        helperText:SetTextColor(CDM_C.GOLD.r, CDM_C.GOLD.g, CDM_C.GOLD.b, 1)
        CDM_C.ApplyShadow(helperText)
        container.helperText = helperText
    end

    if not container.dragOverlay then
        local overlayParent = overlayOpts.parent or container
        local overlay = CreateFrame("Frame", nil, overlayParent, "NineSliceCodeTemplate")
        overlay:SetAllPoints(container)
        if overlayOpts.strata then
            overlay:SetFrameStrata(overlayOpts.strata)
        end
        if overlayOpts.level then
            overlay:SetFrameLevel(overlayOpts.level)
        else
            overlay:SetFrameLevel(container:GetFrameLevel() + 1)
        end
        overlay:EnableMouse(false)

        if NineSliceUtil and NineSliceUtil.ApplyLayout then
            local overlayLayout = {
                ["TopRightCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
                ["TopLeftCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
                ["BottomLeftCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
                ["BottomRightCorner"] = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
                ["TopEdge"] = { atlas = "_%s-NineSlice-EdgeTop" },
                ["BottomEdge"] = { atlas = "_%s-NineSlice-EdgeBottom" },
                ["LeftEdge"] = { atlas = "!%s-NineSlice-EdgeLeft" },
                ["RightEdge"] = { atlas = "!%s-NineSlice-EdgeRight" },
                ["Center"] = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
            }
            NineSliceUtil.ApplyLayout(overlay, overlayLayout, "editmode-actionbar-highlight")
            SetRegionBlendMode("ADD", overlay:GetRegions())
            overlay:SetAlpha(0.4)
        end

        overlay:Hide()
        container.dragOverlay = overlay
    end

    local function UpdateHelperText()
        local unlocked = not IsLocked()
        if not InCombatLockdown() then
            container:SetMovable(unlocked)
            container:EnableMouse(unlocked)
        end
        if container.helperText then
            container.helperText:SetShown(unlocked)
        end
        if container.dragOverlay then
            container.dragOverlay:SetShown(unlocked and not IsEditModeActive())
        end
    end
    UpdateHelperText()
    container.UpdateHelperText = UpdateHelperText
    container.lockKey = lockKey
end

local function CreateBaseContainer(name)
    local container = _G[name] or CreateFrame("Frame", name, UIParent)
    container:SetFrameStrata(CDM_C.STRATA_MAIN)
    container:SetFrameLevel(10)
    if container.SetPreventSecretValues then
        container:SetPreventSecretValues(true)
    end
    return container
end

function CDM:GetOrCreateAnchorContainer(viewer)
    local sizeEssRow1, _, _, sizeBuff = GetLayoutConfig()
    local vName = viewer:GetName()

    if self.anchorContainers[vName] then
        return self.anchorContainers[vName]
    end

    if vName == VIEWERS.ESSENTIAL or vName == VIEWERS.BUFF then
        local container = CreateBaseContainer(vName .. "_CDM_Container")
        local initH = (vName == VIEWERS.ESSENTIAL) and sizeEssRow1.h or sizeBuff.h
        if vName == VIEWERS.ESSENTIAL then
            container:SetSize(Snap(400), Snap(initH))
        else
            container:SetSize(Pixel.SnapEven(400), Snap(initH))
        end

        self.anchorContainers[vName] = container
        self:UpdateEditModeSelectionOverlay(vName)

        local savedPos = GetPositionSettings(vName, "Default")
        container:ClearAllPoints()
        AnchorMainLayoutContainer(container, vName == VIEWERS.BUFF, savedPos.point, savedPos.x, savedPos.y)

        container:Show()

        return container
    elseif vName == VIEWERS.BUFF_BAR then
        local container = CreateBaseContainer(vName .. "_CDM_Container")
        container:SetSize(300, 200)

        SetupDraggableContainer(container, "buffBarContainerLocked", {
            parent = UIParent, strata = "DIALOG", level = 100
        })

        container:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()

            local _, _, relativePoint, x, y = self:GetPoint()
            if relativePoint and x and y then
                local growDirection = CDM_C.GetConfigValue("buffBarGrowDirection", "DOWN")
                local anchorPoint = growDirection == "DOWN" and "TOP" or "BOTTOM"
                x, y = ResolveDraggedCoords(self, anchorPoint, relativePoint, x, y)

                local settings = GetBuffBarPositionSettings()
                settings.point = relativePoint
                settings.x = Snap(x)
                settings.y = Snap(y)

                CDM:UpdateBuffBarContainerPosition()

                CDM:NotifyPositionSliderUpdate("buffBar", settings.x, settings.y, true)
            end
        end)

        self.anchorContainers[vName] = container
        self:UpdateEditModeSelectionOverlay(vName)

        self:UpdateBuffBarContainerPosition()

        container:Show()

        return container
    else
        local container = CreateBaseContainer(vName .. "_AnchorContainer")

        self.anchorContainers[vName] = container
        self:UpdateEditModeSelectionOverlay(vName)

        if vName == VIEWERS.UTILITY then
            self:UpdateUtilityContainerPosition()
        end

        container:Show()

        return container
    end
end

function CDM:UpdateContainerDragOverlays()
    if not self.anchorContainers then return end
    for _, container in pairs(self.anchorContainers) do
        if container and container.UpdateHelperText then
            container.UpdateHelperText()
        end
    end
end

local tempIconPositionRecords = {}
local tempIconPositionRecordPool = {}
local tempIconPositionRecordCount = 0
local tempTrinketReorder = {}

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
    SetCdmAnchor(fd, "TOPLEFT", container, "TOPLEFT", x, y)
    frame:ClearAllPoints()
    Pixel.SetPoint(frame, "TOPLEFT", container, "TOPLEFT", x or 0, y or 0)
    frame:Show()
end

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

    local preUtilW, preUtilH, preUtilGap
    if not useMeasuredHorizontalLayout then
        preUtilW, preUtilH, preUtilGap = GetSnappedMetrics(sizeUtility, spacing)
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
                index, totalIcons, isEssential, sizeEssRow1, sizeEssRow2, sizeUtility, spacing, maxRowEss, maxRowUtil, utilityVertical, preUtilW, preUtilH, preUtilGap
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

local essentialRow1WidthCache = {
    valid = false,
    value = 0,
}
function CDM:InvalidateEssentialRow1WidthCache()
    essentialRow1WidthCache.valid = false
end

local function CacheEssentialRow1Width(width)
    essentialRow1WidthCache.value = width
    essentialRow1WidthCache.valid = true
    return width
end


local function CalculateEssentialRow1Width()
    local sizeEssRow1, _, _, _, spacing, maxRowEss = GetLayoutConfig()

    local contentWidth = CDM:GetEssentialContentWidth()
    if contentWidth > 0 then
        return CacheEssentialRow1Width(contentWidth)
    end

    local essContainer = CDM.anchorContainers and CDM.anchorContainers[VIEWERS.ESSENTIAL]
    if essContainer then
        local width = essContainer:GetWidth()
        if width and width > 0 then
            return CacheEssentialRow1Width(width)
        end
    end

    if essentialRow1WidthCache.valid then
        return essentialRow1WidthCache.value
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
            local row1Count = math_min(activeCount, maxRowEss)
            return CacheEssentialRow1Width((row1Count * sizeEssRow1.w) + ((row1Count - 1) * spacing))
        end
    end

    local fallbackCount = math_max(maxRowEss, 1)
    return (fallbackCount * sizeEssRow1.w) + ((fallbackCount - 1) * spacing)
end

CDM.CalculateEssentialRow1Width = CalculateEssentialRow1Width


function CDM:UpdateBuffBarContainerPosition()
    local container = self.anchorContainers and self.anchorContainers[VIEWERS.BUFF_BAR]
    if not container then return end

    local db = CDM.db or {}
    local savedPos = GetBuffBarPositionSettings()
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
    frame:ClearAllPoints()
    frame:SetFrameStrata(CDM_C.STRATA_MAIN)
    local barLevel = containerLevel + 1
    frame:SetFrameLevel(barLevel)
    if frame.Bar then frame.Bar:SetFrameLevel(barLevel + 1) end
    if frame.Icon then frame.Icon:SetFrameLevel(barLevel + 2) end
    frame:SetSize(frameWidth, barHeight)
end

local tempBars = {}

function CDM:PositionBuffBarFrames(viewer, vName)
    if not viewer or not viewer.itemFramePool then return end

    local container = self:GetOrCreateAnchorContainer(viewer)
    if not container then return end

    local db = CDM.db or {}
    local barWidth = db.buffBarWidth ~= nil and db.buffBarWidth or 0
    local barHeight = Snap(db.buffBarHeight or 20)
    local spacing = Snap(db.buffBarSpacing ~= nil and db.buffBarSpacing or 2)
    local growDirection = db.buffBarGrowDirection or "DOWN"
    local iconPosition = db.buffBarIconPosition or "LEFT"
    local dualMode = db.buffBarDualMode or false

    local effectiveWidth = barWidth
    if barWidth == 0 then
        effectiveWidth = CalculateEssentialRow1Width()
    end
    effectiveWidth = Snap(effectiveWidth)

    table_wipe(tempBars)
    local bars = tempBars
    for frame in viewer.itemFramePool:EnumerateActive() do
        if frame:IsShown() then
            bars[#bars + 1] = frame
        elseif frame.cooldownInfo then
            self:ApplyBarStyle(frame, vName)
        end
    end

    if #bars > 1 then
        table_sort(bars, CompareByLayoutIndex)
    end

    if #bars == 0 then
        container:SetSize(effectiveWidth, barHeight)
        self:UpdateBuffBarContainerPosition()
        return
    end

    local containerHeight = 0
    local containerWidth = effectiveWidth

    local containerLevel = container:GetFrameLevel()

    if dualMode and #bars >= 2 then
        local leftWidth = math_max(Pixel.GetSize(), HalfFloor(effectiveWidth - spacing))
        local rightX = leftWidth + spacing
        local rightWidth = math_max(1, effectiveWidth - rightX)
        containerWidth = effectiveWidth
        local totalBars = #bars
        local hasOddBar = (totalBars % 2) == 1

        for i, frame in ipairs(bars) do
            local isLastOdd = hasOddBar and (i == totalBars)
            local isLeft, rowOffset, frameWidth

            if isLastOdd then
                rowOffset = math_floor((i - 1) / 2) * (barHeight + spacing)
                frameWidth = effectiveWidth

                local overridePos = (iconPosition == "HIDDEN") and "HIDDEN" or nil
                if frame:GetParent() ~= container then
                    frame:SetParent(container)
                end
                SetupBarFrame(frame, containerLevel, frameWidth, barHeight)

                if growDirection == "DOWN" then
                    frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -rowOffset)
                else
                    frame:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, rowOffset)
                end
                self:ApplyBarStyle(frame, vName, overridePos, frameWidth, barHeight)
            else
                isLeft = ((i - 1) % 2) == 0
                rowOffset = math_floor((i - 1) / 2) * (barHeight + spacing)
                frameWidth = isLeft and leftWidth or rightWidth

                local dualIconPosition
                if iconPosition == "HIDDEN" then
                    dualIconPosition = "HIDDEN"
                else
                    dualIconPosition = isLeft and "RIGHT" or "LEFT"
                end
                if frame:GetParent() ~= container then
                    frame:SetParent(container)
                end
                SetupBarFrame(frame, containerLevel, frameWidth, barHeight)

                local xOff = isLeft and 0 or rightX
                if growDirection == "DOWN" then
                    frame:SetPoint("TOPLEFT", container, "TOPLEFT", xOff, -rowOffset)
                else
                    frame:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", xOff, rowOffset)
                end
                self:ApplyBarStyle(frame, vName, dualIconPosition, frameWidth, barHeight)
            end
        end

        local rowCount = math_ceil(totalBars / 2)
        containerHeight = (rowCount * barHeight) + ((rowCount - 1) * spacing)
    else
        for i, frame in ipairs(bars) do
            local offset = (i - 1) * (barHeight + spacing)

            if frame:GetParent() ~= container then
                frame:SetParent(container)
            end
            SetupBarFrame(frame, containerLevel, effectiveWidth, barHeight)

            if growDirection == "DOWN" then
                frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -offset)
            else
                frame:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, offset)
            end
            self:ApplyBarStyle(frame, vName, nil, effectiveWidth, barHeight)
        end

        containerHeight = (#bars * barHeight) + ((#bars - 1) * spacing)
    end

    container:SetSize(containerWidth, math_max(barHeight, containerHeight))
    self:UpdateBuffBarContainerPosition()
end

CDM._LayoutCtx = {
    DeriveSelfPoint        = DeriveSelfPoint,
    GetStableFrameSortID   = GetStableFrameSortID,
    PositionFrameAtSlot    = PositionFrameAtSlot,
    PlaceFrame             = PlaceFrame,
    OverrideCooldownText   = OverrideCooldownText,
    GetCooldownFontRegions = GetCooldownFontRegions,
    OverrideCooldownRegions = OverrideCooldownRegions,
    GetLayoutConfig        = GetLayoutConfig,
    ToSortNumber           = ToSortNumber,
    RowWidth               = RowWidth,
    SetCdmAnchor           = SetCdmAnchor,
}
