local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local ctx = CDM._LayoutCtx

local VIEWERS = ctx.VIEWERS

local GetFrameData = ctx.GetFrameData
local CheckBuffRegistryMatch = ctx.CheckBuffRegistryMatch
local ResolveBaseSpellID = ctx.ResolveBaseSpellID
local GetLayoutConfig = ctx.GetLayoutConfig
local QueueReanchorRetry = ctx.QueueReanchorRetry

local SortAndPositionBuffFrames = ctx.SortAndPositionBuffFrames

local tempBuff = {}
local tempBuffGroups = {}
local tempEssential, tempUtility = {}, {}
local tempCustomBuffFrames, tempActiveSpellIDs = {}, {}
local tempAllMainBuffs = {}

local reanchorInProgress = {}
local reanchorPending = {}
local lastReanchorTime = {}
local REANCHOR_MIN_INTERVAL = 0.05
local reanchorSelf = nil
local reanchorViewer = nil
local reanchorVName = nil

-- Buff icons and buff bars share buff-like queue/reanchor timing at the hook layer,
-- but keep distinct runtime reanchor policies here where their layout pipelines differ.
local REANCHOR_READINESS_SKIP_VIEWERS = {
    [VIEWERS.BUFF_BAR] = true,
}

local REANCHOR_THROTTLE_INTERVALS = {
    [VIEWERS.BUFF_BAR] = REANCHOR_MIN_INTERVAL,
}

local function ShouldSkipReadinessChecksForViewer(vName, hasActiveCustomBuffs)
    if hasActiveCustomBuffs and vName == VIEWERS.BUFF then
        return true
    end
    return REANCHOR_READINESS_SKIP_VIEWERS[vName] == true
end

local function GetReanchorThrottleInterval(vName)
    return REANCHOR_THROTTLE_INTERVALS[vName]
end

local function IsPublicTrueBoolean(value)
    if type(value) ~= "boolean" then
        return false
    end

    if type(issecretvalue) == "function" and issecretvalue(value) then
        return false
    end

    return value == true
end

local function CollectActiveCustomBuffFrames(cdm, outFrames, outSpellIDs)
    table.wipe(outFrames)

    if not (cdm and cdm.CustomBuffs and cdm.CustomBuffs.activeBuffs) then
        return outFrames
    end

    table.wipe(outSpellIDs)
    for spellID in pairs(cdm.CustomBuffs.activeBuffs) do
        outSpellIDs[#outSpellIDs + 1] = spellID
    end
    table.sort(outSpellIDs)

    for _, spellID in ipairs(outSpellIDs) do
        local buffData = cdm.CustomBuffs.activeBuffs[spellID]
        if buffData and buffData.frame and buffData.frame:IsShown() then
            outFrames[#outFrames + 1] = buffData.frame
        end
    end

    return outFrames
end

local function HasVisibleBuffFramesForMatchType(viewer, targetMatchType, excludeFrame)
    if viewer and viewer.itemFramePool then
        for activeFrame in viewer.itemFramePool:EnumerateActive() do
            if activeFrame and activeFrame ~= excludeFrame and activeFrame:IsShown() then
                local matchType = CheckBuffRegistryMatch(activeFrame)
                if matchType == targetMatchType then
                    return true
                end
            end
        end
    end

    if targetMatchType == nil and CDM.CustomBuffs and CDM.CustomBuffs.activeBuffs then
        for _, buffData in pairs(CDM.CustomBuffs.activeBuffs) do
            local customFrame = buffData and buffData.frame
            if customFrame and customFrame ~= excludeFrame and customFrame:IsShown() then
                return true
            end
        end
    end

    return false
end

local function IsBuffFrameReadyForReanchor(frame, viewer)
    if not frame then return false end
    local frameData = GetFrameData(frame)
    if frame:IsShown() then
        return true
    end

    local now = GetTime()
    local provisionalUntil = frameData and frameData.cdmProvisionalReadyUntil
    if provisionalUntil and provisionalUntil > now then
        local frameViewer = frame.viewerFrame
        if not frameViewer and frame.GetViewerFrame and type(frame.GetViewerFrame) == "function" then
            frameViewer = frame:GetViewerFrame()
        end
        if frameViewer == viewer and frame.cooldownInfo then
            local matchType = CheckBuffRegistryMatch(frame)
            if matchType == "buffgroup" then
                if frameData then frameData.cdmProvisionalReadyUntil = nil end
            else
                local hasVisibleInTargetGroup = HasVisibleBuffFramesForMatchType(viewer, matchType, frame)
                if not hasVisibleInTargetGroup then
                    return true
                end
            end
        end
    elseif provisionalUntil and frameData then
        frameData.cdmProvisionalReadyUntil = nil
    end

    local isActive
    if frame.IsActive and type(frame.IsActive) == "function" then
        isActive = frame:IsActive()
    end

    if IsPublicTrueBoolean(isActive) then
        if frame.cooldownInfo or ResolveBaseSpellID(frame) then
            return true
        end
    end

    return false
end

local function HasReadyFramesForReanchor(viewer, vName)
    if not viewer or not viewer.itemFramePool then return false end

    if vName == VIEWERS.BUFF then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if IsBuffFrameReadyForReanchor(frame, viewer) then
                return true
            end
        end
        return false
    end

    for frame in viewer.itemFramePool:EnumerateActive() do
        if frame:IsShown() then
            return true
        end
        if frame.cooldownInfo then
            return true
        end
    end
    return false
end

local function GetReanchorRetryDelay(vName)
    if vName == VIEWERS.BUFF then
        return 0.01
    end
    return 0.02
end

local function QueueReanchorRetryIfNotReady(activeSelf, activeViewer, activeVName)
    if HasReadyFramesForReanchor(activeViewer, activeVName) then
        return false
    end
    QueueReanchorRetry(activeSelf, activeVName, GetReanchorRetryDelay(activeVName))
    return true
end

local function ResetReanchorTempTables()
    table.wipe(tempBuff)
    table.wipe(tempBuffGroups)
    table.wipe(tempEssential)
    table.wipe(tempUtility)
end

local function CollectFramesForReanchor(activeViewer, activeVName, inEditMode)
    if not activeViewer.itemFramePool then
        return
    end

    for frame in activeViewer.itemFramePool:EnumerateActive() do
        if activeVName == VIEWERS.BUFF then
            if inEditMode or IsBuffFrameReadyForReanchor(frame, activeViewer) then
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
        elseif frame:IsShown() or inEditMode or frame.cooldownInfo then
            if activeVName == VIEWERS.ESSENTIAL then
                tempEssential[#tempEssential + 1] = frame
            elseif activeVName == VIEWERS.UTILITY then
                tempUtility[#tempUtility + 1] = frame
            end
        end
    end
end

local function PositionBuffFramesForReanchor(activeSelf, activeViewer, activeVName, sizeBuff, spacing)
    local buffContainer = activeSelf:GetOrCreateAnchorContainer(activeViewer)

    local customBuffFrames
    if activeSelf.GetSortedCustomBuffFrames then
        customBuffFrames = activeSelf:GetSortedCustomBuffFrames()
    else
        customBuffFrames = CollectActiveCustomBuffFrames(activeSelf, tempCustomBuffFrames, tempActiveSpellIDs)
    end

    local groupFrameCount = 0
    for _, groupFrames in pairs(tempBuffGroups) do
        groupFrameCount = groupFrameCount + #groupFrames
    end

    local totalBuffCount = #tempBuff + groupFrameCount + (customBuffFrames and #customBuffFrames or 0)
    if totalBuffCount > 0 then
        if CDM.EnableBuffCentering then CDM.EnableBuffCentering() end

        for _, frame in ipairs(customBuffFrames) do
            frame:SetParent(UIParent)
        end

        for groupIdx, groupFrames in pairs(tempBuffGroups) do
            if #groupFrames > 0 then
                for _, frame in ipairs(groupFrames) do
                    activeSelf:ApplyStyle(frame, VIEWERS.BUFF)
                end
                activeSelf:PositionBuffGroupFrames(groupIdx, groupFrames)
            end
        end

        for _, frame in ipairs(tempBuff) do
            activeSelf:RestoreCooldownTextIfHidden(frame)
            activeSelf:RestoreVisualsIfHidden(frame)
            activeSelf:ApplyStyle(frame, activeVName)
            frame:SetParent(UIParent)
            if activeSelf.ApplyUngroupedBuffOverrides then
                activeSelf:ApplyUngroupedBuffOverrides(frame)
            end
        end

        if #tempBuff > 0 and buffContainer then
            table.wipe(tempAllMainBuffs)
            for _, f in ipairs(customBuffFrames) do
                tempAllMainBuffs[#tempAllMainBuffs + 1] = f
            end
            for _, f in ipairs(tempBuff) do
                tempAllMainBuffs[#tempAllMainBuffs + 1] = f
            end
            SortAndPositionBuffFrames(tempAllMainBuffs, buffContainer)
        end
    end

    local bgSets = CDM.BuffGroupSets
    if bgSets and bgSets.groups then
        local emptyFrames = {}
        for groupIdx, groupData in ipairs(bgSets.groups) do
            if groupData.staticDisplay and groupData.spells and not tempBuffGroups[groupIdx] then
                activeSelf:PositionBuffGroupFrames(groupIdx, emptyFrames)
            end
        end
    end
end

local function RunReanchor()
    local activeSelf = reanchorSelf
    local activeViewer = reanchorViewer
    local activeVName = reanchorVName
    if not activeSelf or not activeViewer or not activeVName then
        return
    end

    local _, _, _, sizeBuff, spacing = GetLayoutConfig()

    local hasActiveCustomBuffs = activeVName == VIEWERS.BUFF
        and activeSelf.CustomBuffs
        and activeSelf.CustomBuffs.activeBuffs
        and next(activeSelf.CustomBuffs.activeBuffs)

    local hasStaticBuffGroups = false
    if activeVName == VIEWERS.BUFF then
        local bgSets = CDM.BuffGroupSets
        if bgSets and bgSets.groups then
            for _, gd in ipairs(bgSets.groups) do
                if gd.staticDisplay and gd.spells then
                    hasStaticBuffGroups = true
                    break
                end
            end
        end
    end

    local skipReadinessChecks = ShouldSkipReadinessChecksForViewer(activeVName, hasActiveCustomBuffs)
        or hasStaticBuffGroups

    local editModeFrame = _G.EditModeManagerFrame
    local inEditMode = activeSelf.isEditModeActive or (editModeFrame and editModeFrame:IsShown())
    if not activeViewer:IsShown() and not skipReadinessChecks and not inEditMode then
        if QueueReanchorRetryIfNotReady(activeSelf, activeViewer, activeVName) then
            return
        end
    end

    if activeSelf.pendingSpecChange then
        return
    end

    if activeViewer.itemFramePool and not skipReadinessChecks and not inEditMode then
        if QueueReanchorRetryIfNotReady(activeSelf, activeViewer, activeVName) then
            return
        end
    end

    ResetReanchorTempTables()
    CollectFramesForReanchor(activeViewer, activeVName, inEditMode)

    if activeVName == VIEWERS.ESSENTIAL then
        local prevWidth = activeSelf._essentialContentWidth or 0
        activeSelf:PositionEssentialOrUtilityIcons(tempEssential, activeViewer, activeVName)
        if activeSelf.InvalidateEssentialRow1WidthCache then
            activeSelf:InvalidateEssentialRow1WidthCache()
        end

        activeSelf:UpdateUtilityContainerPosition()

        local newWidth = activeSelf._essentialContentWidth or 0
        if newWidth ~= prevWidth then
            if activeSelf.UpdateResources then
                activeSelf:UpdateResources()
            end
            if activeSelf.UpdatePlayerCastBar then
                activeSelf:UpdatePlayerCastBar()
            end
        end

    elseif activeVName == VIEWERS.UTILITY then
        activeSelf:PositionEssentialOrUtilityIcons(tempUtility, activeViewer, activeVName)
        if activeSelf.InvalidateUtilityVisibleCountCache then
            activeSelf:InvalidateUtilityVisibleCountCache()
        end

    elseif activeVName == VIEWERS.BUFF then
        PositionBuffFramesForReanchor(activeSelf, activeViewer, activeVName, sizeBuff, spacing)

    elseif activeVName == VIEWERS.BUFF_BAR then
        activeSelf:PositionBuffBarFrames(activeViewer, activeVName)
    end

    if CDM.Fading then
        CDM.Fading:ReapplyCurrent()
    end
end

local function ReanchorErrorHandler(err)
    if debugstack then
        return tostring(err) .. "\n" .. debugstack()
    end
    return err
end

function CDM:ForceReanchor(viewer)
    if not viewer then return false end
    local vName = viewer.GetName and viewer:GetName()
    if not vName then return false end

    if reanchorInProgress[vName] then
        reanchorPending[vName] = true
        return false
    end

    local now = GetTime()
    local throttleInterval = GetReanchorThrottleInterval(vName)
    if throttleInterval then
        local lastTime = lastReanchorTime[vName]
        if lastTime and (now - lastTime) < throttleInterval then
            self:QueueViewer(vName)
            return false
        end
        lastReanchorTime[vName] = now
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
    if reanchorPending[vName] then
        reanchorPending[vName] = nil
        self:QueueViewer(vName, true)
    end
    return ok
end
