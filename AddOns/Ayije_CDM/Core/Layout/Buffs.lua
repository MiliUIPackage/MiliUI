local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local ctx = CDM._LayoutCtx

local CDM_C = ctx.CDM_C
local VIEWERS = ctx.VIEWERS
local GetFrameData = ctx.GetFrameData
local CheckBuffRegistryMatch = ctx.CheckBuffRegistryMatch
local ResolveBaseSpellID = ctx.ResolveBaseSpellID
local ToSortNumber = ctx.ToSortNumber
local GetStableFrameSortID = ctx.GetStableFrameSortID

local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local PROVISIONAL_READY_WINDOW = 0.25

local tempProvisionalMainBuffs = {}
local CompareBuffFramesDeterministic

local function GetSnappedBuffMetrics(sizeBuff, spacing)
    local itemW = math.max(Pixel.GetSize(), Snap((sizeBuff and sizeBuff.w) or 40))
    local itemH = math.max(Pixel.GetSize(), Snap((sizeBuff and sizeBuff.h) or 36))
    local gap = Snap(spacing or 1)
    local step = itemW + gap
    return itemW, itemH, gap, step
end

local function GetCenteredRowPlacement(containerWidth, count, itemW, gap)
    local rowWidth = (count * itemW) + ((count - 1) * gap)
    local cWidth = containerWidth and Snap(containerWidth) or rowWidth
    if cWidth < rowWidth then
        cWidth = rowWidth
    end
    local startLeft = Pixel.HalfFloor(cWidth) - Pixel.HalfFloor(rowWidth)
    if startLeft < 0 then startLeft = 0 end
    return startLeft, rowWidth, cWidth
end

local function PlaceBuffFrame(frame, parent, point, relativeTo, relativePoint, x, y)
    if not frame then
        return
    end
    frame:SetParent(parent)
    frame:ClearAllPoints()
    Pixel.SetPoint(frame, point, relativeTo, relativePoint, x or 0, y or 0)
end

local function ComputeProvisionalMainBuffX(cdm, frame, viewer, buffContainer)
    if not frame or not viewer then return 0 end

    table.wipe(tempProvisionalMainBuffs)

    if viewer.itemFramePool then
        for activeFrame in viewer.itemFramePool:EnumerateActive() do
            if activeFrame and activeFrame ~= frame and activeFrame:IsShown() then
                local matchType = CheckBuffRegistryMatch(activeFrame)
                if not matchType then
                    tempProvisionalMainBuffs[#tempProvisionalMainBuffs + 1] = activeFrame
                end
            end
        end
    end

    if cdm and cdm.CustomBuffs and cdm.CustomBuffs.activeBuffs then
        for _, buffData in pairs(cdm.CustomBuffs.activeBuffs) do
            local customFrame = buffData.frame
            if customFrame and customFrame:IsShown() then
                tempProvisionalMainBuffs[#tempProvisionalMainBuffs + 1] = customFrame
            end
        end
    end

    tempProvisionalMainBuffs[#tempProvisionalMainBuffs + 1] = frame

    local count = #tempProvisionalMainBuffs
    if count > 1 then
        table.sort(tempProvisionalMainBuffs, CompareBuffFramesDeterministic)
    end

    local sizes = cdm and cdm.Sizes or {}
    local df = CDM.defaults or {}
    local sizeBuff = sizes.SIZE_BUFF or df.sizeBuff or { w = 40, h = 36 }
    local spacing = sizes.SPACING or df.spacing or 1
    local itemW, _, gap, step = GetSnappedBuffMetrics(sizeBuff, spacing)
    local containerWidth = (buffContainer and buffContainer.GetWidth and buffContainer:GetWidth()) or nil
    local startLeft, _, cWidth = GetCenteredRowPlacement(containerWidth, count, itemW, gap)
    local containerCenterX = Pixel.HalfFloor(cWidth)

    for index, positionedFrame in ipairs(tempProvisionalMainBuffs) do
        if positionedFrame == frame then
            local centerXFromLeft = startLeft + ((index - 1) * step) + Pixel.HalfFloor(itemW)
            return centerXFromLeft - containerCenterX
        end
    end

    return 0
end

local function ProvisionalPlaceBuffFrame(cdm, frame, viewer, matchType, buffContainer)
    if not frame or not viewer then return end

    if matchType == "buffgroup" then
        return
    end

    local frameData = GetFrameData(frame)
    if frameData then
        local now = GetTime()
        frameData.cdmProvisionalReadyUntil = now + PROVISIONAL_READY_WINDOW
    end

    if not buffContainer then return end
    local xOff = ComputeProvisionalMainBuffX(cdm, frame, viewer, buffContainer)
    if frame:GetParent() ~= UIParent then
        frame:SetParent(UIParent)
    end
    frame:ClearAllPoints()
    Pixel.SetPoint(frame, "BOTTOM", buffContainer, "BOTTOM", xOff, 0)
end

CDM.ProvisionalPlaceBuffFrame = ProvisionalPlaceBuffFrame

CompareBuffFramesDeterministic = function(a, b)
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
        table.sort(frames, CompareBuffFramesDeterministic)
    end

    local sizes = CDM.Sizes or {}
    local sizeBuff = sizes.SIZE_BUFF or { w = 40, h = 36 }
    local spacing = sizes.SPACING or 1
    local itemW, _, gap, step = GetSnappedBuffMetrics(sizeBuff, spacing)
    local startLeft = GetCenteredRowPlacement(container.GetWidth and container:GetWidth() or nil, count, itemW, gap)

    for i, frame in ipairs(frames) do
        local xOff = startLeft + ((i - 1) * step)
        PlaceBuffFrame(frame, UIParent, "BOTTOMLEFT", container, "BOTTOMLEFT", xOff, 0)
    end
end

ctx.SortAndPositionBuffFrames = SortAndPositionBuffFrames

local catMainBuffs = {}
local lastCategorizationTime = -1

local function CategorizeVisibleBuffs()
    local now = GetTime()
    if now == lastCategorizationTime then return end
    lastCategorizationTime = now

    table.wipe(catMainBuffs)

    local viewer = _G[VIEWERS.BUFF]
    if viewer and viewer.itemFramePool then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if frame and frame:IsShown() then
                local matchType = CheckBuffRegistryMatch(frame)
                if matchType == "buffgroup" then
                    -- excluded from main; handled by BuffGroups module
                elseif not matchType then
                    catMainBuffs[#catMainBuffs + 1] = frame
                end
            end
        end
    end
end

local CENTERING_BURST_THROTTLE = 0.033
local CENTERING_WATCHDOG_THROTTLE = 0.25
local CENTERING_BURST_TICKS = 5
local CENTERING_IDLE_DISABLE_SECONDS = 2.0

local buffCenteringFrame = CreateFrame("Frame")
local nextBuffCenteringUpdate = 0
local visibleBuffs = {}
local buffCenteringEnabled = false
local buffCenteringDirty = true
local buffCenteringBurstTicksRemaining = 0
local buffCenteringLastActivityTime = 0
local buffCenteringLastVisibleSet = {}
local buffCenteringLastVisibleCount = 0
local buffCenteringLastLayout = setmetatable({}, { __mode = "k" })
local buffCenteringLastCustomStart = setmetatable({}, { __mode = "k" })
local cachedVisibleCustomBuffFrames = {}
local cachedVisibleCustomBuffCount = 0
local cachedCustomBuffVersion = -1
local hadCenteredBuffGlows = false

local function HasVisibleSetChanged(visibleList, lastSet, lastCount)
    local count = #visibleList
    if count ~= lastCount then
        return true
    end
    for i = 1, count do
        if not lastSet[visibleList[i]] then
            return true
        end
    end
    return false
end

local function CacheVisibleSet(visibleList, outSet)
    wipe(outSet)
    local count = #visibleList
    for i = 1, count do
        outSet[visibleList[i]] = true
    end
    return count
end

local function HasMainBuffStateChanged(visibleList)
    if buffCenteringDirty then
        return true
    end

    if HasVisibleSetChanged(visibleList, buffCenteringLastVisibleSet, buffCenteringLastVisibleCount) then
        return true
    end

    for i = 1, #visibleList do
        local frame = visibleList[i]
        local layoutIndex = ToSortNumber(frame.layoutIndex, 0)
        if buffCenteringLastLayout[frame] ~= layoutIndex then
            return true
        end

        local customStart = frame.isCustomBuff and (frame.customBuffStartTime or 0) or nil
        if buffCenteringLastCustomStart[frame] ~= customStart then
            return true
        end
    end

    return false
end

local function CacheMainBuffState(visibleList)
    buffCenteringLastVisibleCount = CacheVisibleSet(visibleList, buffCenteringLastVisibleSet)

    wipe(buffCenteringLastLayout)
    wipe(buffCenteringLastCustomStart)

    for i = 1, #visibleList do
        local frame = visibleList[i]
        buffCenteringLastLayout[frame] = ToSortNumber(frame.layoutIndex, 0)
        buffCenteringLastCustomStart[frame] = frame.isCustomBuff and (frame.customBuffStartTime or 0) or nil
    end
end

local DisableBuffCentering

local function RefreshVisibleCustomBuffSnapshot(forceRefresh)
    local customBuffs = CDM.CustomBuffs
    if not (customBuffs and customBuffs.activeBuffs) then
        cachedCustomBuffVersion = -1
        cachedVisibleCustomBuffCount = 0
        wipe(cachedVisibleCustomBuffFrames)
        return cachedVisibleCustomBuffFrames, 0
    end

    local currentVersion = customBuffs.activeBuffVersion or 0
    if not forceRefresh and currentVersion == cachedCustomBuffVersion then
        return cachedVisibleCustomBuffFrames, cachedVisibleCustomBuffCount
    end

    cachedCustomBuffVersion = currentVersion
    cachedVisibleCustomBuffCount = 0
    wipe(cachedVisibleCustomBuffFrames)

    for _, buffData in pairs(customBuffs.activeBuffs) do
        if buffData and buffData.frame and buffData.frame:IsShown() then
            cachedVisibleCustomBuffCount = cachedVisibleCustomBuffCount + 1
            cachedVisibleCustomBuffFrames[cachedVisibleCustomBuffCount] = buffData.frame
        end
    end

    return cachedVisibleCustomBuffFrames, cachedVisibleCustomBuffCount
end

local function MarkBuffCenteringDirty()
    buffCenteringDirty = true
    buffCenteringBurstTicksRemaining = CENTERING_BURST_TICKS
    buffCenteringLastActivityTime = GetTime()
    nextBuffCenteringUpdate = 0
end

local function ApplyGlowsToFrames(frames, specID)
    if not CDM.Glow then return end
    if not specID then
        for _, frame in ipairs(frames) do
            CDM.Glow:RequestBuffGlow(frame, false, nil, nil)
        end
        hadCenteredBuffGlows = false
        return
    end

    local hasBuffGlows = CDM.HasAnySpellGlowConfigured and CDM:HasAnySpellGlowConfigured(specID) or false
    if not hasBuffGlows then
        if hadCenteredBuffGlows then
            for _, frame in ipairs(frames) do
                CDM.Glow:RequestBuffGlow(frame, false, nil, nil)
            end
        end
        hadCenteredBuffGlows = false
        return
    end

    hadCenteredBuffGlows = true

    for _, frame in ipairs(frames) do
        local frameData = GetFrameData(frame)
        if frameData and frameData.cdmVisualsHidden then
            CDM.Glow:RequestBuffGlow(frame, false, nil, nil)
        else
            local glowEnabled, glowColor, glowSourceID = false, nil, nil
            if CDM.ResolveBuffGlowState then
                glowEnabled, glowColor, glowSourceID = CDM:ResolveBuffGlowState(frame, specID, false)
            end
            CDM.Glow:RequestBuffGlow(frame, glowEnabled, glowColor, glowSourceID)
        end
    end
end

local function CenterBuffsImmediate()
    local now = GetTime()
    local throttle = (buffCenteringDirty or buffCenteringBurstTicksRemaining > 0)
        and CENTERING_BURST_THROTTLE
        or CENTERING_WATCHDOG_THROTTLE
    if now < nextBuffCenteringUpdate then return end
    nextBuffCenteringUpdate = now + throttle

    local container = CDM.anchorContainers and CDM.anchorContainers[VIEWERS.BUFF]
    if not container then return end

    CategorizeVisibleBuffs()

    table.wipe(visibleBuffs)
    for i = 1, #catMainBuffs do
        visibleBuffs[i] = catMainBuffs[i]
    end

    local customFrames, customCount = RefreshVisibleCustomBuffSnapshot(buffCenteringDirty)
    for i = 1, customCount do
        visibleBuffs[#visibleBuffs + 1] = customFrames[i]
    end

    if #visibleBuffs == 0 then
        DisableBuffCentering()
        return
    end

    local changed = HasMainBuffStateChanged(visibleBuffs)
    if not changed then
        if buffCenteringBurstTicksRemaining > 0 then
            buffCenteringBurstTicksRemaining = buffCenteringBurstTicksRemaining - 1
        elseif (now - buffCenteringLastActivityTime) >= CENTERING_IDLE_DISABLE_SECONDS then
            DisableBuffCentering()
        end
        return
    end

    SortAndPositionBuffFrames(visibleBuffs, container)
    CacheMainBuffState(visibleBuffs)
    buffCenteringDirty = false
    buffCenteringBurstTicksRemaining = CENTERING_BURST_TICKS
    buffCenteringLastActivityTime = now

    local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID() or nil
    ApplyGlowsToFrames(visibleBuffs, specID)
end

local function EnableBuffCentering()
    MarkBuffCenteringDirty()
    if not buffCenteringEnabled then
        buffCenteringFrame:SetScript("OnUpdate", CenterBuffsImmediate)
        buffCenteringEnabled = true
    end
end

DisableBuffCentering = function()
    if buffCenteringEnabled then
        buffCenteringFrame:SetScript("OnUpdate", nil)
        buffCenteringEnabled = false
    end
    buffCenteringDirty = true
    buffCenteringBurstTicksRemaining = 0
    buffCenteringLastActivityTime = 0
    nextBuffCenteringUpdate = 0
    buffCenteringLastVisibleCount = 0
    wipe(buffCenteringLastVisibleSet)
    wipe(buffCenteringLastLayout)
    wipe(buffCenteringLastCustomStart)
    wipe(cachedVisibleCustomBuffFrames)
    cachedVisibleCustomBuffCount = 0
    cachedCustomBuffVersion = -1
    hadCenteredBuffGlows = false
end

CDM.MarkBuffCenteringDirty = MarkBuffCenteringDirty
CDM.EnableBuffCentering = EnableBuffCentering
CDM.DisableBuffCentering = DisableBuffCentering

