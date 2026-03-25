local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local ctx = CDM._LayoutCtx

local VIEWERS = ctx.VIEWERS

local GetFrameData = ctx.GetFrameData
local CheckBuffRegistryMatch = ctx.CheckBuffRegistryMatch
local ResolveBaseSpellID = ctx.ResolveBaseSpellID
local GetLayoutConfig = ctx.GetLayoutConfig

local SortAndPositionBuffFrames = ctx.SortAndPositionBuffFrames

local CheckCdGroupMatch = ctx.CheckCdGroupMatch
local defensivesHiddenSet = ctx.defensivesHiddenSet

local tempBuff = {}
local tempBuffGroups = {}
local tempCdGroups = {}
local tempEssential, tempUtility = {}, {}
local tempAllMainBuffs = {}
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
    table.wipe(tempBuff)
    for _, t in pairs(tempBuffGroups) do table.wipe(t) end
    for _, t in pairs(tempCdGroups) do table.wipe(t) end
    table.wipe(tempEssential)
    table.wipe(tempUtility)
end

local function CollectFramesForReanchor(activeViewer, activeVName, inEditMode)
    if not activeViewer.itemFramePool then
        return false
    end

    local hasDefensivesHidden = next(defensivesHiddenSet) ~= nil

    local hiddenBuffSet = CDM.resourcesHiddenBuffSet
    for frame in activeViewer.itemFramePool:EnumerateActive() do
        if activeVName == VIEWERS.BUFF then
            if inEditMode or IsBuffFrameIncluded(frame) then
                local spellID = ResolveBaseSpellID(frame)
                if spellID and hiddenBuffSet and hiddenBuffSet[spellID] then
                    frame:ClearAllPoints()
                    frame:SetParent(activeViewer)
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
            local isDefHidden = false
            if hasDefensivesHidden then
                local frameSpellID = ResolveBaseSpellID(frame)
                isDefHidden = frameSpellID and defensivesHiddenSet[frameSpellID] or false
            end
            local cdGroupIdx = not isDefHidden and CheckCdGroupMatch and CheckCdGroupMatch(frame)
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
    return hasDefensivesHidden
end

local function PositionBuffFramesForReanchor(activeSelf, activeViewer, activeVName)
    local buffContainer = activeSelf:GetOrCreateAnchorContainer(activeViewer)

    local customBuffFrames = activeSelf:GetSortedCustomBuffFrames()

    local groupFrameCount = 0
    for _, groupFrames in pairs(tempBuffGroups) do
        groupFrameCount = groupFrameCount + #groupFrames
    end

    local totalBuffCount = #tempBuff + groupFrameCount + (customBuffFrames and #customBuffFrames or 0)

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
            table.wipe(tempAllMainBuffs)
            for _, f in ipairs(customBuffFrames or {}) do
                tempAllMainBuffs[#tempAllMainBuffs + 1] = f
            end
            for _, f in ipairs(tempBuff) do
                tempAllMainBuffs[#tempAllMainBuffs + 1] = f
            end
            SortAndPositionBuffFrames(tempAllMainBuffs, buffContainer)

            if CDM.Glow then
                local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID() or nil
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

local function CollectCrossViewerGroupFrames(activeVName, inEditMode, hasDefensivesHidden)
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
            local isDefHidden = false
            if hasDefensivesHidden then
                local frameSpellID = ResolveBaseSpellID(frame)
                isDefHidden = frameSpellID and defensivesHiddenSet[frameSpellID] or false
            end
            if not isDefHidden then
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
end

local function DispatchCooldownGroupFrames(activeSelf)
    for groupIdx, groupFrames in pairs(tempCdGroups) do
        if #groupFrames > 0 and activeSelf.PositionCooldownGroupFrames then
            activeSelf:PositionCooldownGroupFrames(groupIdx, groupFrames)
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

    local editModeFrame = _G.EditModeManagerFrame
    local inEditMode = activeSelf.isEditModeActive or (editModeFrame and editModeFrame:IsShown())

    ResetReanchorTempTables()
    local hasDefensivesHidden = CollectFramesForReanchor(activeViewer, activeVName, inEditMode)

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

        CollectCrossViewerGroupFrames(activeVName, inEditMode, hasDefensivesHidden)
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

        CollectCrossViewerGroupFrames(activeVName, inEditMode, hasDefensivesHidden)
        DispatchCooldownGroupFrames(activeSelf)

    elseif activeVName == VIEWERS.BUFF then
        PositionBuffFramesForReanchor(activeSelf, activeViewer, activeVName)

    elseif activeVName == VIEWERS.BUFF_BAR then
        activeSelf:PositionBuffBarFrames(activeViewer, activeVName)
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

    if self.pendingSpecChange then
        self.queue[vName] = true
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
    if reanchorPending[vName] then
        reanchorPending[vName] = nil
        self:QueueViewer(vName)
    end
    return ok
end
