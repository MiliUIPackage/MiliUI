local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local ctx = CDM._LayoutCtx

local CDM_C = ctx.CDM_C
local VIEWERS = ctx.VIEWERS
local SECONDARY_SET = ctx.SECONDARY_SET
local TERTIARY_SET = ctx.TERTIARY_SET

local GetFrameData = ctx.GetFrameData
local GetSpellIDCandidates = CDM.GetSpellIDCandidates
local CheckBuffRegistryMatch = ctx.CheckBuffRegistryMatch
local ResolveBaseSpellID = ctx.ResolveBaseSpellID
local ToSortNumber = ctx.ToSortNumber
local GetStableFrameSortID = ctx.GetStableFrameSortID

local PROVISIONAL_READY_WINDOW = 0.25

local tempProvisionalMainBuffs = {}
local CompareBuffFramesDeterministic
local ToPixelCountForRegion = CDM_C.ToPixelCountForRegion
local PixelsToUIForRegion = CDM_C.PixelsToUIForRegion
local SetPointPixels = CDM_C.SetPointPixels

local function GetSnappedBuffMetricsPx(sizeBuff, spacing)
    local itemWPx = ToPixelCountForRegion((sizeBuff and sizeBuff.w) or 40, UIParent, 1)
    local itemHPx = ToPixelCountForRegion((sizeBuff and sizeBuff.h) or 36, UIParent, 1)
    local gapPx = CDM_C.GetCooldownIconGapPixels(spacing or 1)
    local stepPx = itemWPx + gapPx
    return itemWPx, itemHPx, gapPx, stepPx
end

local function GetCenteredRowPlacementPx(containerWidth, count, itemWPx, gapPx)
    local rowWidthPx = (count * itemWPx) + ((count - 1) * gapPx)
    local snappedContainerWidthPx = containerWidth and ToPixelCountForRegion(containerWidth, UIParent, 0) or rowWidthPx
    if snappedContainerWidthPx < rowWidthPx then
        snappedContainerWidthPx = rowWidthPx
    end
    local startLeftPx = math.floor((snappedContainerWidthPx - rowWidthPx) * 0.5)
    return startLeftPx, rowWidthPx, snappedContainerWidthPx
end

local function PlaceFramePixels(frame, parent, point, relativeTo, relativePoint, xPx, yPx, pixelRegion)
    if not frame then
        return
    end
    frame:SetParent(parent)
    frame:ClearAllPoints()
    SetPointPixels(frame, point, relativeTo, relativePoint, xPx or 0, yPx or 0, pixelRegion or parent)
end

local function SetSizePixels(frame, widthPx, heightPx, pixelRegion)
    if not frame then
        return
    end
    frame:SetSize(
        PixelsToUIForRegion(widthPx or 0, pixelRegion or frame),
        PixelsToUIForRegion(heightPx or 0, pixelRegion or frame)
    )
end

local function ComputeProvisionalMainBuffXPx(cdm, frame, viewer, buffContainer)
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
    local itemWPx, _, gapPx, stepPx = GetSnappedBuffMetricsPx(sizeBuff, spacing)
    local containerWidth = (buffContainer and buffContainer.GetWidth and buffContainer:GetWidth()) or nil
    local startLeftPx, _, snappedContainerWidthPx = GetCenteredRowPlacementPx(containerWidth, count, itemWPx, gapPx)
    local containerCenterXPx = math.floor(snappedContainerWidthPx * 0.5)

    for index, positionedFrame in ipairs(tempProvisionalMainBuffs) do
        if positionedFrame == frame then
            local centerXFromLeftPx = startLeftPx + ((index - 1) * stepPx) + math.floor(itemWPx * 0.5)
            return centerXFromLeftPx - containerCenterXPx
        end
    end

    return 0
end

local function ProvisionalPlaceBuffFrame(cdm, frame, viewer, matchType, buffContainer)
    if not frame or not viewer then return end

    local frameData = GetFrameData(frame)
    if frameData then
        local now = GetTime()
        frameData.cdmProvisionalReadyUntil = now + PROVISIONAL_READY_WINDOW
    end

    if matchType == "secondary" or matchType == "tertiary" then
        local targetContainer = (matchType == "secondary") and cdm.secBuffs or cdm.tertBuffs
        if not targetContainer then return end
        local parent = frame:GetParent()
        if parent ~= targetContainer or frame:GetNumPoints() == 0 then
            if parent ~= targetContainer then
                frame:SetParent(targetContainer)
            end
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOM", targetContainer, "BOTTOM", 0, 0)
        end
        if CDM.EnableSecTertCentering then
            CDM.EnableSecTertCentering()
        end
        return
    end

    if not buffContainer then return end
    local xPx = ComputeProvisionalMainBuffXPx(cdm, frame, viewer, buffContainer)
    if frame:GetParent() ~= UIParent then
        frame:SetParent(UIParent)
    end
    frame:ClearAllPoints()
    SetPointPixels(frame, "BOTTOM", buffContainer, "BOTTOM", xPx, 0, UIParent)
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
    local itemWPx, _, gapPx, stepPx = GetSnappedBuffMetricsPx(sizeBuff, spacing)
    local startLeftPx = GetCenteredRowPlacementPx(container.GetWidth and container:GetWidth() or nil, count, itemWPx, gapPx)

    local leftSnapPx = 0
    do
        local uiScale = UIParent:GetEffectiveScale() or 1
        local cl = container:GetLeft()
        if cl then
            local px = cl * uiScale
            leftSnapPx = math.floor(px + 0.5) - px
        end
    end

    for i, frame in ipairs(frames) do
        local xPx = startLeftPx + ((i - 1) * stepPx)
        PlaceFramePixels(frame, UIParent, "BOTTOMLEFT", container, "BOTTOMLEFT", xPx + leftSnapPx, 0, UIParent)
    end
end

local groupRegistryRef
local function CompareByGroupOrder(a, b)
    local aData, bData = GetFrameData(a), GetFrameData(b)
    local aID = aData.buffCategorySpellID or ResolveBaseSpellID(a)
    local bID = bData.buffCategorySpellID or ResolveBaseSpellID(b)
    local aPos = ToSortNumber(groupRegistryRef[aID], 99)
    local bPos = ToSortNumber(groupRegistryRef[bID], 99)
    if aPos ~= bPos then return aPos < bPos end
    return GetStableFrameSortID(a) < GetStableFrameSortID(b)
end

local function PositionBuffGroup(frames, container, registrySet, horizontalKey, sizeBuff, spacing)
    local count = #frames
    if count == 0 or not container then return 0 end

    if count > 1 then
        groupRegistryRef = registrySet
        table.sort(frames, CompareByGroupOrder)
    end

    local horizontalMode = CDM_C.GetConfigValue(horizontalKey, false)
    local itemWPx, itemHPx, gapPx, stepPx = GetSnappedBuffMetricsPx(sizeBuff, spacing)
    if horizontalMode then
        local totalWidthPx = (count * itemWPx) + ((count - 1) * gapPx)
        SetSizePixels(container, totalWidthPx, itemHPx, UIParent)
        local leftSnapPx = 0
        do
            local uiScale = UIParent:GetEffectiveScale() or 1
            local cl = container:GetLeft()
            if cl then
                local px = cl * uiScale
                leftSnapPx = math.floor(px + 0.5) - px
            end
        end
        for i, frame in ipairs(frames) do
            local xPx = (i - 1) * stepPx
            PlaceFramePixels(frame, container, "BOTTOMLEFT", container, "BOTTOMLEFT", xPx + leftSnapPx, 0, container)
        end
    else
        local totalHeightPx = (count * itemHPx) + ((count - 1) * gapPx)
        SetSizePixels(container, itemWPx, totalHeightPx, UIParent)
        for i, frame in ipairs(frames) do
            local yPx = (i - 1) * (itemHPx + gapPx)
            PlaceFramePixels(frame, container, "BOTTOM", container, "BOTTOM", 0, yPx, container)
        end
    end

    return count
end

ctx.SortAndPositionBuffFrames = SortAndPositionBuffFrames
ctx.PositionBuffGroup = PositionBuffGroup

local catMainBuffs = {}
local catSecBuffs = {}
local catTertBuffs = {}
local lastCategorizationTime = -1

local function CategorizeVisibleBuffs()
    local now = GetTime()
    if now == lastCategorizationTime then return end
    lastCategorizationTime = now

    table.wipe(catMainBuffs)
    table.wipe(catSecBuffs)
    table.wipe(catTertBuffs)

    local viewer = _G[VIEWERS.BUFF]
    if viewer and viewer.itemFramePool then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if frame and frame:IsShown() then
                local matchType = CheckBuffRegistryMatch(frame)
                if matchType == "secondary" then
                    catSecBuffs[#catSecBuffs + 1] = frame
                elseif matchType == "tertiary" then
                    catTertBuffs[#catTertBuffs + 1] = frame
                else
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
    if not (specID and CDM.Glow) then return end
    for _, frame in ipairs(frames) do
        local glowEnabled, glowColor = false, nil
        local candidates = GetSpellIDCandidates(CDM, frame, true)
        for _, id in ipairs(candidates) do
            if CDM:GetSpellGlowEnabled(specID, id) then
                glowEnabled = true
                glowColor = CDM:GetSpellGlowColor(specID, id)
                break
            end
        end
        if glowEnabled then
            CDM.Glow:StartGlow(frame, glowColor)
        else
            CDM.Glow:StopGlow(frame)
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
end

CDM.MarkBuffCenteringDirty = MarkBuffCenteringDirty
CDM.EnableBuffCentering = EnableBuffCentering
CDM.DisableBuffCentering = DisableBuffCentering

local secTertCenteringFrame = CreateFrame("Frame")
local nextSecTertCenteringUpdate = 0
local secTertCenteringEnabled = false
local secTertCenteringDirty = true
local secTertCenteringBurstTicksRemaining = 0
local secTertCenteringLastActivityTime = 0
local secLastVisibleSet = {}
local tertLastVisibleSet = {}
local secLastVisibleCount = 0
local tertLastVisibleCount = 0
local secLastMatchID = {}
local tertLastMatchID = {}

local DisableSecTertCentering

local function CenterBuffGroup(container, registrySet, horizontalKey, sizeBuff, spacing, specID, lastSet, lastCount, lastMatchIDs, sourceList)
    if not container then return 0, 0, false end

    local count = #sourceList
    if count == 0 then
        wipe(lastSet)
        wipe(lastMatchIDs)
        return 0, 0, false
    end

    local changed = secTertCenteringDirty or HasVisibleSetChanged(sourceList, lastSet, lastCount)
    if not changed then
        for i = 1, count do
            local frame = sourceList[i]
            local frameData = GetFrameData(frame)
            local matchID = frameData.buffCategorySpellID or ResolveBaseSpellID(frame) or 0
            if lastMatchIDs[frame] ~= matchID then
                changed = true
                break
            end
        end
    end
    if not changed then
        return count, lastCount, false
    end

    PositionBuffGroup(sourceList, container, registrySet, horizontalKey, sizeBuff, spacing)

    ApplyGlowsToFrames(sourceList, specID)

    local cachedCount = CacheVisibleSet(sourceList, lastSet)
    wipe(lastMatchIDs)
    for i = 1, count do
        local frame = sourceList[i]
        local frameData = GetFrameData(frame)
        lastMatchIDs[frame] = frameData.buffCategorySpellID or ResolveBaseSpellID(frame) or 0
    end

    return count, cachedCount, true
end

local function MarkSecTertCenteringDirty()
    secTertCenteringDirty = true
    secTertCenteringBurstTicksRemaining = CENTERING_BURST_TICKS
    secTertCenteringLastActivityTime = GetTime()
    nextSecTertCenteringUpdate = 0
end

local function CenterSecondaryTertiaryImmediate()
    local now = GetTime()
    local throttle = (secTertCenteringDirty or secTertCenteringBurstTicksRemaining > 0)
        and CENTERING_BURST_THROTTLE
        or CENTERING_WATCHDOG_THROTTLE
    if now < nextSecTertCenteringUpdate then return end
    nextSecTertCenteringUpdate = now + throttle

    CategorizeVisibleBuffs()

    local sizes = CDM.Sizes or {}
    local sizeBuff = sizes.SIZE_BUFF or { w = 40, h = 36 }
    local sizeBuffSec = sizes.SIZE_BUFF_SEC or sizeBuff
    local sizeBuffTert = sizes.SIZE_BUFF_TERT or sizeBuff
    local spacing = sizes.SPACING or 1

    local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID() or nil
    if not specID then
        local specIndex = GetSpecialization()
        specID = specIndex and GetSpecializationInfo(specIndex)
    end

    local secCount, secChanged
    secCount, secLastVisibleCount, secChanged = CenterBuffGroup(
        CDM.secBuffs,
        SECONDARY_SET,
        "buffSecondaryHorizontal",
        sizeBuffSec,
        spacing,
        specID,
        secLastVisibleSet,
        secLastVisibleCount,
        secLastMatchID,
        catSecBuffs
    )

    local tertCount, tertChanged
    tertCount, tertLastVisibleCount, tertChanged = CenterBuffGroup(
        CDM.tertBuffs,
        TERTIARY_SET,
        "buffTertiaryHorizontal",
        sizeBuffTert,
        spacing,
        specID,
        tertLastVisibleSet,
        tertLastVisibleCount,
        tertLastMatchID,
        catTertBuffs
    )
    local changed = secChanged or tertChanged
    if changed then
        secTertCenteringDirty = false
        secTertCenteringBurstTicksRemaining = CENTERING_BURST_TICKS
        secTertCenteringLastActivityTime = now
    else
        if secTertCenteringDirty then
            secTertCenteringDirty = false
            secTertCenteringLastActivityTime = now
        end
        if secTertCenteringBurstTicksRemaining > 0 then
            secTertCenteringBurstTicksRemaining = secTertCenteringBurstTicksRemaining - 1
        end
    end

    if secCount == 0 and tertCount == 0 then
        DisableSecTertCentering()
        return
    end

    if (not changed)
        and secTertCenteringBurstTicksRemaining == 0
        and (now - secTertCenteringLastActivityTime) >= CENTERING_IDLE_DISABLE_SECONDS
    then
        DisableSecTertCentering()
    end
end

local function EnableSecTertCentering()
    MarkSecTertCenteringDirty()
    if not secTertCenteringEnabled then
        secTertCenteringFrame:SetScript("OnUpdate", CenterSecondaryTertiaryImmediate)
        secTertCenteringEnabled = true
    end
end

DisableSecTertCentering = function()
    if secTertCenteringEnabled then
        secTertCenteringFrame:SetScript("OnUpdate", nil)
        secTertCenteringEnabled = false
    end
    secTertCenteringDirty = true
    secTertCenteringBurstTicksRemaining = 0
    secTertCenteringLastActivityTime = 0
    nextSecTertCenteringUpdate = 0
    secLastVisibleCount = 0
    tertLastVisibleCount = 0
    wipe(secLastVisibleSet)
    wipe(tertLastVisibleSet)
    wipe(secLastMatchID)
    wipe(tertLastMatchID)
end

CDM.MarkSecTertCenteringDirty = MarkSecTertCenteringDirty
CDM.EnableSecTertCentering = EnableSecTertCentering
CDM.DisableSecTertCentering = DisableSecTertCentering
