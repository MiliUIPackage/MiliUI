local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local ctx = CDM._LayoutCtx

local VIEWERS = CDM_C.VIEWERS
local GetFrameData = CDM.GetFrameData
local CheckBuffRegistryMatch = CDM.CheckBuffRegistryMatch
local ResolveBaseSpellID = CDM.GetBaseSpellID
local GetLayoutConfig = ctx.GetLayoutConfig
local CheckCdGroupMatch = CDM.CheckCdGroupMatch
local ToSortNumber = ctx.ToSortNumber
local GetStableFrameSortID = ctx.GetStableFrameSortID
local RowWidth = ctx.RowWidth
local SetCdmAnchor = ctx.SetCdmAnchor

local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local math_max = math.max
local table_sort = table.sort
local table_wipe = table.wipe
local ipairs = ipairs
local pairs = pairs

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
    local fd = GetFrameData(frame)
    SetCdmAnchor(fd, point, relativeTo, relativePoint, x, y)
    frame:ClearAllPoints()
    Pixel.SetPoint(frame, point, relativeTo, relativePoint, x or 0, y or 0)
end

local function GetBuffSortPair(frame)
    if frame.isCustomBuff then
        return frame._cdmSortPrimary or 999999, frame._cdmSortSecondary or 0
    end
    return ToSortNumber(frame.layoutIndex, 0), -1
end

local function CompareBuffFramesDeterministic(a, b)
    local aP, aS = GetBuffSortPair(a)
    local bP, bS = GetBuffSortPair(b)
    if aP ~= bP then return aP < bP end
    if aS ~= bS then return aS < bS end
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

local tempBuff = {}
local tempBuffGroups = {}
local tempCdGroups = {}
local tempEssential, tempUtility = {}, {}
local tempAllMainBuffs = {}
local tempBuffSubCounts = {}
local EMPTY_FRAMES = {}

local reanchorInProgress = {}
local reanchorPending = {}
local reanchorSelf = nil
local reanchorViewer = nil
local reanchorVName = nil

local cachedHasStaticGroups = false

function CDM:InvalidateStaticGroupsCache()
    cachedHasStaticGroups = false
    local bgSets = self.BuffGroupSets
    if bgSets and bgSets.groups then
        for _, gd in ipairs(bgSets.groups) do
            if gd.staticDisplay and gd.spells then
                cachedHasStaticGroups = true
                break
            end
        end
    end
end

local function IsBuffFrameIncluded(frame)
    if not frame then return false end
    if frame:IsShown() then return true end
    if frame.cooldownInfo then return true end
    return false
end

local function ResetReanchorTempTables()
    table_wipe(tempBuff)
    for _, t in pairs(tempBuffGroups) do table_wipe(t) end
    for _, t in pairs(tempCdGroups) do table_wipe(t) end
    table_wipe(tempEssential)
    table_wipe(tempUtility)
end

local function CollectFramesForReanchor(activeViewer, activeVName, inEditMode)
    if not activeViewer.itemFramePool then
        return false
    end

    local hiddenBuffSet = CDM.resourcesHiddenBuffSet
    for frame in activeViewer.itemFramePool:EnumerateActive() do
        if activeVName == VIEWERS.BUFF then
            if inEditMode or IsBuffFrameIncluded(frame) then
                local spellID = ResolveBaseSpellID(frame)
                if spellID and hiddenBuffSet and hiddenBuffSet[spellID] then
                    frame:ClearAllPoints()
                    frame:Hide()
                else
                    local matchType, matchID, groupIdx = CheckBuffRegistryMatch(frame)

                    if matchType == "buffgroup" and groupIdx then
                        if not tempBuffGroups[groupIdx] then
                            tempBuffGroups[groupIdx] = {}
                        end
                        tempBuffGroups[groupIdx][#tempBuffGroups[groupIdx] + 1] = frame
                    else
                        tempBuff[#tempBuff + 1] = frame
                    end
                end
            end
        elseif frame:IsShown() or inEditMode or frame.cooldownInfo then
            local cdGroupIdx = CheckCdGroupMatch and CheckCdGroupMatch(frame)
            if cdGroupIdx then
                if not tempCdGroups[cdGroupIdx] then
                    tempCdGroups[cdGroupIdx] = {}
                end
                tempCdGroups[cdGroupIdx][#tempCdGroups[cdGroupIdx] + 1] = frame
            elseif activeVName == VIEWERS.ESSENTIAL then
                tempEssential[#tempEssential + 1] = frame
            elseif activeVName == VIEWERS.UTILITY then
                tempUtility[#tempUtility + 1] = frame
            end
        end
    end

    if activeVName == VIEWERS.BUFF then
        local CB = CDM.CustomBuffs
        if CB and CB.activeBuffs then
            local bgSets = CDM.BuffGroupSets
            local grouped = bgSets and bgSets.grouped
            for spellID, buffData in pairs(CB.activeBuffs) do
                local frame = buffData.frame
                if frame and frame:IsShown() then
                    local fd = GetFrameData(frame)
                    fd.buffCategorySpellID = spellID
                    local groupIdx = grouped and grouped[spellID]
                    if groupIdx then
                        if not tempBuffGroups[groupIdx] then
                            tempBuffGroups[groupIdx] = {}
                        end
                        tempBuffGroups[groupIdx][#tempBuffGroups[groupIdx] + 1] = frame
                    else
                        tempBuff[#tempBuff + 1] = frame
                    end
                end
            end
        end
    end
end

local function PositionBuffFramesForReanchor(activeSelf, activeViewer, activeVName)
    local buffContainer = activeSelf:GetOrCreateAnchorContainer(activeViewer)

    local groupFrameCount = 0
    for _, groupFrames in pairs(tempBuffGroups) do
        groupFrameCount = groupFrameCount + #groupFrames
    end

    local totalBuffCount = #tempBuff + groupFrameCount

    local activeSpellSet
    if cachedHasStaticGroups then
        local buildFn = CDM.API and CDM.API.BuildActiveSpellSet
        if buildFn then
            activeSpellSet = buildFn()
        end
    end

    if totalBuffCount > 0 then

        for groupIdx, groupFrames in pairs(tempBuffGroups) do
            if #groupFrames > 0 then
                activeSelf:PositionBuffGroupFrames(groupIdx, groupFrames, activeSpellSet)
            end
        end

        for _, frame in ipairs(tempBuff) do
            activeSelf:RestoreCooldownTextIfHidden(frame)
            activeSelf:RestoreVisualsIfHidden(frame)
            activeSelf:ApplyStyle(frame, activeVName)
            if activeSelf.ApplyUngroupedBuffOverrides then
                activeSelf:ApplyUngroupedBuffOverrides(frame)
            end
        end

        if buffContainer then
            local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID() or nil
            local CB = CDM.CustomBuffs
            local iconFrames = CB and CB.iconFrames
            if specID and iconFrames then
                local order = CDM:GetUngroupedCustomBuffOrder(specID)
                table_wipe(tempBuffSubCounts)
                for _, entry in ipairs(order) do
                    local aN = entry.afterNative or 0
                    local sub = (tempBuffSubCounts[aN] or 0) + 1
                    tempBuffSubCounts[aN] = sub
                    local frame = iconFrames[entry.spellID]
                    if frame then
                        frame._cdmSortPrimary = aN
                        frame._cdmSortSecondary = sub
                    end
                end
            end

            table_wipe(tempAllMainBuffs)
            for _, f in ipairs(tempBuff) do
                tempAllMainBuffs[#tempAllMainBuffs + 1] = f
            end
            SortAndPositionBuffFrames(tempAllMainBuffs, buffContainer)

            if CDM.Glow then
                local hasBuffGlows = specID and CDM.HasAnySpellGlowConfigured
                    and CDM:HasAnySpellGlowConfigured(specID) or false
                for _, frame in ipairs(tempAllMainBuffs) do
                    if hasBuffGlows and CDM.ResolveBuffGlowState then
                        local glowEnabled, glowColor, glowSourceID = CDM:ResolveBuffGlowState(frame, specID, false)
                        CDM.Glow:RequestBuffGlow(frame, glowEnabled, glowColor, glowSourceID)
                    else
                        CDM.Glow:RequestBuffGlow(frame, false, nil, nil)
                    end
                end
            end
        end
    end

    if cachedHasStaticGroups then
        local bgSets = CDM.BuffGroupSets
        if bgSets and bgSets.groups then
            for groupIdx, groupData in ipairs(bgSets.groups) do
                if groupData.staticDisplay and groupData.spells and not tempBuffGroups[groupIdx] then
                    activeSelf:PositionBuffGroupFrames(groupIdx, EMPTY_FRAMES, activeSpellSet)
                end
            end
        end
    end
end

local function CollectCrossViewerGroupFrames(activeVName, inEditMode)
    local oppositeVName
    if activeVName == VIEWERS.ESSENTIAL then
        oppositeVName = VIEWERS.UTILITY
    elseif activeVName == VIEWERS.UTILITY then
        oppositeVName = VIEWERS.ESSENTIAL
    else
        return
    end

    local oppositeViewer = _G[oppositeVName]
    if not oppositeViewer or not oppositeViewer.itemFramePool then return end

    for frame in oppositeViewer.itemFramePool:EnumerateActive() do
        if frame:IsShown() or inEditMode or frame.cooldownInfo then
            local cdGroupIdx = CheckCdGroupMatch and CheckCdGroupMatch(frame)
            if cdGroupIdx then
                if not tempCdGroups[cdGroupIdx] then
                    tempCdGroups[cdGroupIdx] = {}
                end
                tempCdGroups[cdGroupIdx][#tempCdGroups[cdGroupIdx] + 1] = frame
            end
        end
    end
end

local function DispatchCooldownGroupFrames(activeSelf)
    for groupIdx, groupFrames in pairs(tempCdGroups) do
        if #groupFrames > 0 and activeSelf.PositionCooldownGroupFrames then
            activeSelf:PositionCooldownGroupFrames(groupIdx, groupFrames)
        end
    end
end

local function ReanchorErrorHandler(err)
    if debugstack then
        return tostring(err) .. "\n" .. debugstack()
    end
    return err
end

local tempRepositionBuff = {}
local tempRepositionGroups = {}

local function RepositionBuffFrames(viewer)
    if not viewer or not viewer.itemFramePool then return end

    local buffContainer = CDM:GetOrCreateAnchorContainer(viewer)
    if not buffContainer then return end

    local hiddenBuffSet = CDM.resourcesHiddenBuffSet

    table_wipe(tempRepositionBuff)
    for _, t in pairs(tempRepositionGroups) do table_wipe(t) end

    for frame in viewer.itemFramePool:EnumerateActive() do
        if IsBuffFrameIncluded(frame) then
            local spellID = ResolveBaseSpellID(frame)
            if spellID and hiddenBuffSet and hiddenBuffSet[spellID] then
                -- resource-hidden: skip
            else
                local matchType, _, matchGroupIdx = CheckBuffRegistryMatch(frame)
                if matchType == "buffgroup" and matchGroupIdx then
                    if not tempRepositionGroups[matchGroupIdx] then
                        tempRepositionGroups[matchGroupIdx] = {}
                    end
                    tempRepositionGroups[matchGroupIdx][#tempRepositionGroups[matchGroupIdx] + 1] = frame
                else
                    tempRepositionBuff[#tempRepositionBuff + 1] = frame
                end
            end
        end
    end

    local CB = CDM.CustomBuffs
    if CB and CB.activeBuffs then
        local bgSets = CDM.BuffGroupSets
        local grouped = bgSets and bgSets.grouped
        for spellID, buffData in pairs(CB.activeBuffs) do
            local frame = buffData.frame
            if frame and frame:IsShown() then
                local groupIdx = grouped and grouped[spellID]
                if groupIdx then
                    if not tempRepositionGroups[groupIdx] then
                        tempRepositionGroups[groupIdx] = {}
                    end
                    tempRepositionGroups[groupIdx][#tempRepositionGroups[groupIdx] + 1] = frame
                else
                    tempRepositionBuff[#tempRepositionBuff + 1] = frame
                end
            end
        end
    end

    local activeSpellSet
    if cachedHasStaticGroups then
        local buildFn = CDM.API and CDM.API.BuildActiveSpellSet
        if buildFn then
            activeSpellSet = buildFn()
        end
    end

    for groupIdx, groupFrames in pairs(tempRepositionGroups) do
        if #groupFrames > 0 and CDM.PositionBuffGroupFrames then
            CDM:PositionBuffGroupFrames(groupIdx, groupFrames, activeSpellSet, true)
        end
    end

    SortAndPositionBuffFrames(tempRepositionBuff, buffContainer)
end

local repositionInProgress = {}
local repositionPending = {}

function CDM:RepositionBuffViewer(viewer)
    if not viewer then return false end
    local vName = viewer.GetName and viewer:GetName()
    if not vName then return false end

    if self.pendingSpecChange then
        return false
    end

    if reanchorInProgress[vName] then
        return false
    end

    if repositionInProgress[vName] then
        repositionPending[vName] = true
        return false
    end

    repositionInProgress[vName] = true

    local ok, err = xpcall(RepositionBuffFrames, ReanchorErrorHandler, viewer)
    repositionInProgress[vName] = nil
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(err)
        else
            print(err)
        end
    end

    if repositionPending[vName] then
        repositionPending[vName] = nil
        self:RepositionBuffViewer(viewer)
    end
    return ok
end

local function RunReanchor()
    local activeSelf = reanchorSelf
    local activeViewer = reanchorViewer
    local activeVName = reanchorVName
    if not activeSelf or not activeViewer or not activeVName then
        return
    end

    local editModeFrame = _G.EditModeManagerFrame
    local inEditMode = activeSelf.isEditModeActive or (editModeFrame and editModeFrame:IsShown())

    ResetReanchorTempTables()
    CollectFramesForReanchor(activeViewer, activeVName, inEditMode)

    if activeVName == VIEWERS.ESSENTIAL then
        local essContainer = activeSelf.anchorContainers and activeSelf.anchorContainers[VIEWERS.ESSENTIAL]
        local prevWidth = essContainer and essContainer:GetWidth() or 0
        activeSelf:PositionEssentialOrUtilityIcons(tempEssential, activeViewer, activeVName)
        if activeSelf.InvalidateEssentialRow1WidthCache then
            activeSelf:InvalidateEssentialRow1WidthCache()
        end

        local newWidth = essContainer and essContainer:GetWidth() or 0
        if newWidth ~= prevWidth then
            activeSelf:ReanchorContainer(VIEWERS.UTILITY)
            if activeSelf.UpdateResources then
                activeSelf:UpdateResources()
            end
            if activeSelf.UpdatePlayerCastBar then
                activeSelf:UpdatePlayerCastBar()
            end
        end

        CollectCrossViewerGroupFrames(activeVName, inEditMode)
        DispatchCooldownGroupFrames(activeSelf)

    elseif activeVName == VIEWERS.UTILITY then
        local utilContainer = activeSelf.anchorContainers and activeSelf.anchorContainers[VIEWERS.UTILITY]
        local prevWidth = utilContainer and utilContainer:GetWidth() or 0
        activeSelf:PositionEssentialOrUtilityIcons(tempUtility, activeViewer, activeVName)
        if activeSelf.InvalidateUtilityVisibleCountCache then
            activeSelf:InvalidateUtilityVisibleCountCache()
        end
        local newWidth = utilContainer and utilContainer:GetWidth() or 0
        if newWidth ~= prevWidth then
            if activeSelf.UpdatePlayerCastBar then
                activeSelf:UpdatePlayerCastBar()
            end
        end

        CollectCrossViewerGroupFrames(activeVName, inEditMode)
        DispatchCooldownGroupFrames(activeSelf)

    elseif activeVName == VIEWERS.BUFF then
        PositionBuffFramesForReanchor(activeSelf, activeViewer, activeVName)

    elseif activeVName == VIEWERS.BUFF_BAR then
        activeSelf:PositionBuffBarFrames(activeViewer, activeVName)
    end
end

function CDM:ForceReanchor(viewer)
    if not viewer then return false end
    local vName = viewer.GetName and viewer:GetName()
    if not vName then return false end

    if self.pendingSpecChange then
        return false
    end

    if reanchorInProgress[vName] then
        reanchorPending[vName] = true
        return false
    end

    reanchorInProgress[vName] = true

    reanchorSelf = self
    reanchorViewer = viewer
    reanchorVName = vName

    local ok, err = xpcall(RunReanchor, ReanchorErrorHandler)
    reanchorSelf = nil
    reanchorViewer = nil
    reanchorVName = nil
    reanchorInProgress[vName] = nil
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(err)
        else
            print(err)
        end
    end

    if self.Fading then
        self.Fading:ReapplyCurrent()
    end

    if reanchorPending[vName] then
        reanchorPending[vName] = nil
        self:ForceReanchor(viewer)
    end
    return ok
end
