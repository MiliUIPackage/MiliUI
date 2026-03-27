local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local ctx = CDM._LayoutCtx

local CDM_C = ctx.CDM_C
local VIEWERS = ctx.VIEWERS
local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local HalfFloor = Pixel.HalfFloor
local ResolveBaseSpellID = ctx.ResolveBaseSpellID
local CompareByLayoutIndex = ctx.CompareByLayoutIndex
local GetLayoutConfig = ctx.GetLayoutConfig
local GetBuffBarPositionSettings = ctx.GetBuffBarPositionSettings

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
            local row1Count = math.min(activeCount, maxRowEss)
            return CacheEssentialRow1Width((row1Count * sizeEssRow1.w) + ((row1Count - 1) * spacing))
        end
    end

    local fallbackCount = math.max(maxRowEss, 1)
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

    table.wipe(tempBars)
    local bars = tempBars
    for frame in viewer.itemFramePool:EnumerateActive() do
        if frame:IsShown() then
            bars[#bars + 1] = frame
        elseif frame.cooldownInfo then
            self:ApplyBarStyle(frame, vName)
        end
    end

    if #bars > 1 then
        table.sort(bars, CompareByLayoutIndex)
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
        local leftWidth = math.max(Pixel.GetSize(), HalfFloor(effectiveWidth - spacing))
        local rightX = leftWidth + spacing
        local rightWidth = math.max(1, effectiveWidth - rightX)
        containerWidth = effectiveWidth
        local totalBars = #bars
        local hasOddBar = (totalBars % 2) == 1

        for i, frame in ipairs(bars) do
            local isLastOdd = hasOddBar and (i == totalBars)
            local isLeft, rowOffset, frameWidth

            if isLastOdd then
                rowOffset = math.floor((i - 1) / 2) * (barHeight + spacing)
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
                rowOffset = math.floor((i - 1) / 2) * (barHeight + spacing)
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

        local rowCount = math.ceil(totalBars / 2)
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

    container:SetSize(containerWidth, math.max(barHeight, containerHeight))
    self:UpdateBuffBarContainerPosition()
end
