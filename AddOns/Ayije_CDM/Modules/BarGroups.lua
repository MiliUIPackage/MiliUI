local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local table_wipe = table.wipe
local table_sort = table.sort
local math_floor = math.floor
local math_ceil = math.ceil

CDM.barGroupContainers = {}

local containers = CDM.barGroupContainers

local GCU = CDM.GroupContainerUtils

local function GetContainerForBarAnchorTarget(anchorTarget)
    local anchorContainers = CDM.anchorContainers
    if anchorTarget == "essential" then
        return anchorContainers and anchorContainers[CDM_C.VIEWERS.ESSENTIAL] or nil
    end
    if anchorTarget == "resources" then
        local db = CDM.db
        if db == nil or db.resourcesEnabled ~= false then
            local rTarget = CDM.ResolveResourcesAnchor and CDM.ResolveResourcesAnchor()
            if rTarget then return rTarget end
        end
        local essential = anchorContainers and anchorContainers[CDM_C.VIEWERS.ESSENTIAL]
        if essential and essential:IsShown() then return essential end
        return UIParent, true
    end
    return nil
end

local function IsCenterGrow(grow)
    return grow == "CENTER_UP" or grow == "CENTER_DOWN"
end
CDM.IsBarCenterGrow = IsCenterGrow

local barDescriptor = GCU.CreateDescriptor({
    containers = containers,
    namePrefix = "Ayije_CDM_BarGroup",
    callbackPrefix = "CDM_BarGroup_",
    containerFrameLevel = 10,
    getSets = function() return CDM.BarGroupSets end,
    getInitialSize = function(groupData)
        local w = groupData.barWidth or 0
        if w == 0 then
            w = CDM.CalculateEssentialRow1Width()
        end
        if IsCenterGrow(groupData.grow) then
            local limit = groupData.wrapLimit or 2
            if limit < 2 then limit = 2 elseif limit > 5 then limit = 5 end
            local hSpacing = groupData.hSpacing or 1
            w = limit * w + (limit - 1) * hSpacing
        end
        local h = groupData.barHeight or 20
        return w, h
    end,
})

local layoutCtx = CDM._LayoutCtx
local GetStableFrameSortID = layoutCtx.GetStableFrameSortID
local SetupBarFrame = layoutCtx.SetupBarFrame
local ApplyBarAnchor = layoutCtx.ApplyBarAnchor

local scratchSpellOrder = {}
local scratchFrameHeights = {}
local scratchFrameSpellOvs = {}
local scratchRowHeight = {}
local scratchRowSize = {}
local scratchRowYOffset = {}

local function CompareBarGroupFrames(a, b)
    local aKey = a.cdmSortKey or 999
    local bKey = b.cdmSortKey or 999
    if aKey ~= bKey then return aKey < bKey end
    return GetStableFrameSortID(a) < GetStableFrameSortID(b)
end

function CDM:CreateBarGroupContainer(groupIndex)
    return barDescriptor:GetOrCreateContainer(groupIndex)
end

function CDM:UpdateBarGroupContainerPosition(groupIndex)
    local sets = self.BarGroupSets
    if not sets or not sets.groups then return end
    local groupData = sets.groups[groupIndex]
    if not groupData then return end
    barDescriptor:UpdateContainerPosition(groupIndex, groupData, GetContainerForBarAnchorTarget)
end

local scratchBarActiveIndices = {}

function CDM:UpdateViewerAnchoredBarGroupContainers()
    local sets = self.BarGroupSets
    if not sets or not sets.groups then return end
    for groupIndex, groupData in ipairs(sets.groups) do
        local at = groupData.anchorTarget
        if at == "essential" or at == "resources" then
            barDescriptor:UpdateContainerPosition(groupIndex, groupData, GetContainerForBarAnchorTarget)
        end
    end
end

function CDM:UpdateAllBarGroupContainers()
    local sets = self.BarGroupSets
    if not sets or not sets.groups then
        for _, container in pairs(containers) do
            container:Hide()
        end
        barDescriptor:SyncCallbacks(GetContainerForBarAnchorTarget)
        return
    end

    local activeIndices = scratchBarActiveIndices
    table_wipe(activeIndices)
    for groupIndex, groupData in ipairs(sets.groups) do
        local container = barDescriptor:GetOrCreateContainer(groupIndex)
        barDescriptor:UpdateContainerPosition(groupIndex, groupData, GetContainerForBarAnchorTarget)
        activeIndices[groupIndex] = true
    end

    for idx, container in pairs(containers) do
        if not activeIndices[idx] then
            container:Hide()
        end
    end

    barDescriptor:SyncCallbacks(GetContainerForBarAnchorTarget)
end

local function ResolveBarWidth(groupData)
    local w = groupData.barWidth
    if w == nil or w == 0 then
        return CDM.CalculateEssentialRow1Width()
    end
    return w
end

function CDM:PositionBarGroupFrames(groupIndex, frames, vName)
    local sets = self.BarGroupSets
    if not sets or not sets.groups then return end

    local groupData = sets.groups[groupIndex]
    if not groupData then return end

    local container = barDescriptor:GetOrCreateContainer(groupIndex)

    if not container:IsShown() then
        for _, frame in ipairs(frames) do
            frame:Hide()
        end
        return
    end

    local grow = groupData.grow
    if grow ~= "UP" and grow ~= "DOWN" and not IsCenterGrow(grow) then grow = "DOWN" end

    local barWidth = Snap(ResolveBarWidth(groupData))
    local barHeight = Snap(groupData.barHeight or 20)
    local spacing = Snap(groupData.spacing or 1)

    if #frames > 1 and groupData.spells then
        table_wipe(scratchSpellOrder)
        for i, sid in ipairs(groupData.spells) do
            if not scratchSpellOrder[sid] then scratchSpellOrder[sid] = i end
        end
        GCU.AssignGroupSortKeys(frames, scratchSpellOrder, "cdmBarGroupSpellID")
        table_sort(frames, CompareBarGroupFrames)
    end

    local containerLevel = container:GetFrameLevel()

    local frameHeights = scratchFrameHeights
    local frameSpellOvs = scratchFrameSpellOvs
    table_wipe(frameHeights)
    table_wipe(frameSpellOvs)
    local shownCount = 0
    local shownExtent = 0
    for i, frame in ipairs(frames) do
        local spellOv = CDM.ResolveBarSpellOverride(frame, groupData)
        frameSpellOvs[i] = spellOv
        local fh
        if spellOv and type(spellOv.barHeight) == "number" and spellOv.barHeight > 0 then
            fh = Snap(spellOv.barHeight)
        else
            fh = barHeight
        end
        frameHeights[i] = fh
        if frame:IsShown() then
            shownCount = shownCount + 1
            shownExtent = shownExtent + fh + spacing
        end
    end
    if shownCount > 0 then shownExtent = shownExtent - spacing end

    if IsCenterGrow(grow) then
        local limit = groupData.wrapLimit or 2
        if limit < 2 then limit = 2 elseif limit > 5 then limit = 5 end
        local hSpacing = Snap(groupData.hSpacing or 1)
        local containerWidth = Snap(limit * barWidth + (limit - 1) * hSpacing)

        local numRows = shownCount > 0 and math_ceil(shownCount / limit) or 0
        local rowHeight = scratchRowHeight
        local rowSize = scratchRowSize
        table_wipe(rowHeight)
        table_wipe(rowSize)
        do
            local shownIdx = 0
            for i, frame in ipairs(frames) do
                if frame:IsShown() then
                    shownIdx = shownIdx + 1
                    local row = math_floor((shownIdx - 1) / limit) + 1
                    rowSize[row] = (rowSize[row] or 0) + 1
                    local fh = frameHeights[i]
                    if (rowHeight[row] or 0) < fh then rowHeight[row] = fh end
                end
            end
        end

        shownExtent = 0
        local rowYOffset = scratchRowYOffset
        table_wipe(rowYOffset)
        for r = 1, numRows do
            rowYOffset[r] = shownExtent
            shownExtent = shownExtent + rowHeight[r]
            if r < numRows then shownExtent = shownExtent + spacing end
        end

        local hiddenOffset = shownCount > 0 and shownExtent + spacing or 0
        local shownIdx = 0
        for i, frame in ipairs(frames) do
            local fh, xOff, yOff
            if frame:IsShown() then
                shownIdx = shownIdx + 1
                local row = math_floor((shownIdx - 1) / limit) + 1
                local col = (shownIdx - 1) % limit
                fh = rowHeight[row]
                local rsize = rowSize[row]
                local rowWidth = rsize * barWidth + (rsize - 1) * hSpacing
                local xStart = (containerWidth - rowWidth) / 2
                xOff = Snap(xStart + col * (barWidth + hSpacing))
                yOff = Snap(rowYOffset[row])
            else
                fh = frameHeights[i]
                xOff = Snap((containerWidth - barWidth) / 2)
                yOff = Snap(hiddenOffset)
                hiddenOffset = hiddenOffset + fh + spacing
            end

            SetupBarFrame(frame, containerLevel, barWidth, fh)
            if grow == "CENTER_DOWN" then
                ApplyBarAnchor(frame, "TOPLEFT", container, "TOPLEFT", xOff, -yOff)
            else
                ApplyBarAnchor(frame, "BOTTOMLEFT", container, "BOTTOMLEFT", xOff, yOff)
            end
            self:ApplyBarStyle(frame, vName, nil, barWidth, fh, groupData, frameSpellOvs[i])
        end

        local containerHeight = shownCount > 0 and shownExtent or barHeight
        if containerHeight < barHeight then containerHeight = barHeight end
        Pixel.SetSize(container, containerWidth, containerHeight)
        return
    end

    local shownOffset = 0
    local hiddenOffset = shownCount > 0 and shownExtent + spacing or 0
    for i, frame in ipairs(frames) do
        local fh = frameHeights[i]
        SetupBarFrame(frame, containerLevel, barWidth, fh)

        local offset
        if frame:IsShown() then
            offset = shownOffset
            shownOffset = shownOffset + fh + spacing
        else
            offset = hiddenOffset
            hiddenOffset = hiddenOffset + fh + spacing
        end

        if grow == "DOWN" then
            ApplyBarAnchor(frame, "TOPLEFT", container, "TOPLEFT", 0, -offset)
        else
            ApplyBarAnchor(frame, "BOTTOMLEFT", container, "BOTTOMLEFT", 0, offset)
        end

        self:ApplyBarStyle(frame, vName, nil, barWidth, fh, groupData, frameSpellOvs[i])
    end

    local containerHeight = shownCount > 0 and shownExtent or barHeight
    if containerHeight < barHeight then containerHeight = barHeight end
    Pixel.SetSize(container, barWidth, containerHeight)
end

CDM:RegisterRefreshCallback("barGroups", function()
    CDM:UpdateAllBarGroupContainers()
end, 31, { "BAR_DATA" })

CDM:RegisterRefreshCallback("barGroups_postViewer", function()
    CDM:UpdateViewerAnchoredBarGroupContainers()
end, 45, { "LAYOUT", "BAR_DATA" })
