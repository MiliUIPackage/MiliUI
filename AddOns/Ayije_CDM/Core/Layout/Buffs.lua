local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local ctx = CDM._LayoutCtx

local ToSortNumber = ctx.ToSortNumber
local GetStableFrameSortID = ctx.GetStableFrameSortID
local RowWidth = ctx.RowWidth

local math_max = math.max
local table_sort = table.sort

local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local function GetSnappedBuffMetrics(sizeBuff, spacing)
    local itemW = math_max(Pixel.GetSize(), Snap((sizeBuff and sizeBuff.w) or 40))
    local itemH = math_max(Pixel.GetSize(), Snap((sizeBuff and sizeBuff.h) or 36))
    local gap = Snap(spacing or 1)
    local step = itemW + gap
    return itemW, itemH, gap, step
end

local function GetCenteredRowPlacement(containerWidth, count, itemW, gap)
    local rowWidth = RowWidth(count, itemW, gap)
    local cWidth = containerWidth and Snap(containerWidth) or rowWidth
    if cWidth < rowWidth then
        cWidth = rowWidth
    end
    local startLeft = Pixel.HalfFloor(cWidth) - Pixel.HalfFloor(rowWidth)
    if startLeft < 0 then startLeft = 0 end
    return startLeft, rowWidth, cWidth
end

local function PlaceBuffFrame(frame, point, relativeTo, relativePoint, x, y)
    if not frame then
        return
    end
    frame:ClearAllPoints()
    Pixel.SetPoint(frame, point, relativeTo, relativePoint, x or 0, y or 0)
end

local function CompareBuffFramesDeterministic(a, b)
    local aIsCustom = a.isCustomBuff == true
    local bIsCustom = b.isCustomBuff == true

    if aIsCustom ~= bIsCustom then
        return aIsCustom
    end

    if aIsCustom then
        local aTime = a.customBuffStartTime or 0
        local bTime = b.customBuffStartTime or 0
        if aTime ~= bTime then
            return aTime < bTime
        end

        local aSpell = ToSortNumber(a.spellID, 0)
        local bSpell = ToSortNumber(b.spellID, 0)
        if aSpell ~= bSpell then
            return aSpell < bSpell
        end

        return GetStableFrameSortID(a) < GetStableFrameSortID(b)
    end

    local aLayout = ToSortNumber(a.layoutIndex, 0)
    local bLayout = ToSortNumber(b.layoutIndex, 0)
    if aLayout ~= bLayout then
        return aLayout < bLayout
    end

    return GetStableFrameSortID(a) < GetStableFrameSortID(b)
end

local function SortAndPositionBuffFrames(frames, container)
    local count = #frames
    if count == 0 or not container then return end

    if count > 1 then
        table_sort(frames, CompareBuffFramesDeterministic)
    end

    local sizes = CDM.Sizes or {}
    local sizeBuff = sizes.SIZE_BUFF or { w = 40, h = 36 }
    local spacing = sizes.SPACING or 1
    local itemW, _, gap, step = GetSnappedBuffMetrics(sizeBuff, spacing)

    local shownCount = 0
    for _, f in ipairs(frames) do
        if f:IsShown() then shownCount = shownCount + 1 end
    end
    if shownCount == 0 then shownCount = count end

    local startLeft = GetCenteredRowPlacement(container.GetWidth and container:GetWidth() or nil, shownCount, itemW, gap)

    local shownIdx = 0
    for _, frame in ipairs(frames) do
        local xOff
        if frame:IsShown() then
            xOff = startLeft + (shownIdx * step)
            shownIdx = shownIdx + 1
        else
            xOff = startLeft + ((shownCount + (frame.layoutIndex or 0)) * step)
        end
        PlaceBuffFrame(frame, "BOTTOMLEFT", container, "BOTTOMLEFT", xOff, 0)
    end
end

ctx.SortAndPositionBuffFrames = SortAndPositionBuffFrames


