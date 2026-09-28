local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local ctx = CDM._LayoutCtx

local VIEWERS = CDM_C.VIEWERS
local CheckBuffRegistryMatch = CDM.CheckBuffRegistryMatch
local CheckBarRegistryMatch = CDM.CheckBarRegistryMatch
local ResolveBaseSpellID = CDM.GetBaseSpellID
local CheckCdGroupMatch = CDM.CheckCdGroupMatch
local ToSortNumber = ctx.ToSortNumber
local GetStableFrameSortID = ctx.GetStableFrameSortID
local RowWidth = ctx.RowWidth
local GetSnappedMetrics = ctx.GetSnappedMetrics
local CenteredRowLeft = ctx.CenteredRowLeft
local PlaceFrame = ctx.PlaceFrame

local GetConfigValue = CDM_C.GetConfigValue

local table_sort = table.sort
local table_wipe = table.wipe
local ipairs = ipairs
local pairs = pairs
local EditModeManagerFrame = _G.EditModeManagerFrame

local function GetBuffSortPair(frame)
    if frame.isCustomBuff then
        return frame.cdmSortPrimary or 999999, frame.cdmSortSecondary or 0
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

-- MiliUI: 光環格的持有框（固定前綴）與其餘框分開排。暫存表重用，不每次現配。
local scratchAuraSlotFrames = {}
local scratchOtherBuffFrames = {}

-- 原本的置中排法。prefixWidth > 0 時只在 [prefixWidth, 容器寬] 這段裡置中；
-- prefixWidth = 0 時算式跟改前逐字相同（零光環格時的回歸點）。
local function PositionCenteredBuffRow(frames, container, itemW, gap, step, prefixWidth)
    local count = #frames
    if count == 0 then return end

    local shownCount = 0
    for _, f in ipairs(frames) do
        if f:IsShown() then shownCount = shownCount + 1 end
    end
    if shownCount == 0 then shownCount = count end

    local rowWidth = RowWidth(shownCount, itemW, gap)
    local startLeft
    if prefixWidth > 0 then
        startLeft = prefixWidth + CenteredRowLeft(container:GetWidth() - prefixWidth, rowWidth)
    else
        startLeft = CenteredRowLeft(container:GetWidth(), rowWidth)
    end

    local shownIdx = 0
    for _, frame in ipairs(frames) do
        local xOff
        if frame:IsShown() then
            xOff = startLeft + (shownIdx * step)
            shownIdx = shownIdx + 1
        else
            xOff = startLeft + ((shownCount + (frame.layoutIndex or 0)) * step)
        end
        PlaceFrame(frame, container, "BOTTOMLEFT", "BOTTOMLEFT", xOff, 0)
    end
end

local function SortAndPositionBuffFrames(frames, container)
    local count = #frames
    if count == 0 or not container then return end

    if count > 1 then
        table_sort(frames, CompareBuffFramesDeterministic)
    end

    local df = CDM.defaults or {}
    local sizeBuff = GetConfigValue("sizeBuff", df.sizeBuff) or { w = 40, h = 36 }
    local spacing = GetConfigValue("spacing", df.spacing) or 1
    local itemW, _, gap = GetSnappedMetrics(sizeBuff, spacing)
    local step = itemW + gap

    -- MiliUI: 光環格改成固定前綴：持有框照未分組順序表（上面的排序已經照 cdmSortPrimary／
    -- cdmSortSecondary 排好）從 BOTTOMLEFT 起一格一格放，位置只跟光環格的數量有關，
    -- 戰鬥中原生增益出現／消失時不會動（持有框戰鬥中不能 SetPoint，見 Layout.lua）。
    -- 其餘框在剩下的寬度裡照原本的置中邏輯排。沒有光環格時整段走原本的路徑。
    local auraCount = 0
    for _, f in ipairs(frames) do
        if f.isAuraSlot then auraCount = auraCount + 1 end
    end
    if auraCount == 0 then
        PositionCenteredBuffRow(frames, container, itemW, gap, step, 0)
        return
    end

    local auraFrames, others = scratchAuraSlotFrames, scratchOtherBuffFrames
    table_wipe(auraFrames)
    table_wipe(others)
    for _, f in ipairs(frames) do
        if f.isAuraSlot then
            auraFrames[#auraFrames + 1] = f
        else
            others[#others + 1] = f
        end
    end
    for i, holder in ipairs(auraFrames) do
        PlaceFrame(holder, container, "BOTTOMLEFT", "BOTTOMLEFT", (i - 1) * step, 0)
    end
    PositionCenteredBuffRow(others, container, itemW, gap, step, auraCount * step)
    table_wipe(auraFrames)
    table_wipe(others)
end

local tempBuff = {}
local tempBuffGroups = {}
local tempBarUngrouped = {}
local tempBarGroups = {}
local tempCdGroups = {}
local tempEssential, tempUtility = {}, {}
local tempBuffSubCounts = {}
local EMPTY_FRAMES = {}

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
    if frame:IsShown() then return true end
    if frame.cooldownInfo then return true end
    return false
end

local function ResetReanchorTempTables()
    for _, t in pairs(tempCdGroups) do table_wipe(t) end
    table_wipe(tempEssential)
    table_wipe(tempUtility)
end

local function CollectBuffFramesInto(buffTbl, groupTbls, inEditMode, enforceHidden)
    local viewer = _G[VIEWERS.BUFF]
    if not viewer or not viewer.itemFramePool then return end

    local hiddenBuffSet = CDM.resourcesHiddenBuffSet
    for frame in viewer.itemFramePool:EnumerateActive() do
        if inEditMode or IsBuffFrameIncluded(frame) then
            local spellID = ResolveBaseSpellID(frame)
            if spellID and hiddenBuffSet and hiddenBuffSet[spellID] then
                if enforceHidden then
                    frame:ClearAllPoints()
                    frame.cdmAnchor = nil
                    frame:Hide()
                end
            else
                local matchType, _, groupIdx = CheckBuffRegistryMatch(frame)
                if matchType == "buffgroup" and groupIdx then
                    if not groupTbls[groupIdx] then groupTbls[groupIdx] = {} end
                    groupTbls[groupIdx][#groupTbls[groupIdx] + 1] = frame
                else
                    buffTbl[#buffTbl + 1] = frame
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
                frame.cdmBuffCategorySpellID = spellID
                local groupIdx = grouped and grouped[spellID]
                if groupIdx then
                    if not groupTbls[groupIdx] then groupTbls[groupIdx] = {} end
                    groupTbls[groupIdx][#groupTbls[groupIdx] + 1] = frame
                else
                    buffTbl[#buffTbl + 1] = frame
                end
            end
        end

        -- MiliUI: 光環格的持有框是常駐格，不看光環有沒有（也讀不到）。
        -- 不看 IsShown：戰鬥中顯示切換被延後時也要留住格位；未分組的在這裡要求顯示，
        -- 群組裡的由 PositionBuffGroupFrames 依群組容器決定。
        local auraSlots = CB.auraSlots
        if auraSlots and CB.AuraSlots then
            for spellID, holder in pairs(auraSlots) do
                holder.cdmBuffCategorySpellID = spellID
                local groupIdx = grouped and grouped[spellID]
                if groupIdx then
                    if not groupTbls[groupIdx] then groupTbls[groupIdx] = {} end
                    groupTbls[groupIdx][#groupTbls[groupIdx] + 1] = holder
                else
                    CB.AuraSlots.SetShown(holder, true)
                    buffTbl[#buffTbl + 1] = holder
                end
            end
        end
    end
end

local function CollectFramesForReanchor(activeViewer, activeVName, inEditMode)
    if not activeViewer.itemFramePool then return end
    if activeVName ~= VIEWERS.ESSENTIAL and activeVName ~= VIEWERS.UTILITY then return end

    for frame in activeViewer.itemFramePool:EnumerateActive() do
        if frame:IsShown() or inEditMode or frame.cooldownInfo then
            local cdGroupIdx = CheckCdGroupMatch(frame)
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
end

local function RunBuffPipeline(activeSelf, viewer, vName, full)
    if not viewer or not viewer.itemFramePool then return end

    table_wipe(tempBuff)
    for _, t in pairs(tempBuffGroups) do table_wipe(t) end

    local inEditMode = false
    if full then
        inEditMode = activeSelf.isEditModeActive or EditModeManagerFrame:IsShown()
    end
    CollectBuffFramesInto(tempBuff, tempBuffGroups, inEditMode, full)

    local activeSpellSet
    if cachedHasStaticGroups then
        activeSpellSet = CDM.API.BuildActiveSpellSet()
    end

    for groupIdx, groupFrames in pairs(tempBuffGroups) do
        if #groupFrames > 0 then
            activeSelf:PositionBuffGroupFrames(groupIdx, groupFrames, activeSpellSet, not full)
        end
    end

    if full then
        for _, frame in ipairs(tempBuff) do
            activeSelf:RestoreCooldownTextIfHidden(frame)
            activeSelf:RestoreVisualsIfHidden(frame)
            activeSelf:ApplyStyle(frame, vName)
            activeSelf:ApplyUngroupedBuffOverrides(frame)
        end
    end

    local buffContainer = activeSelf:GetAnchorContainer(viewer)
    local specID = full and CDM:GetCurrentSpecID() or nil

    if buffContainer then
        if full then
            local CB = CDM.CustomBuffs
            local iconFrames = CB and CB.iconFrames
            if specID and iconFrames then
                local order = CDM:GetUngroupedCustomBuffOrder(specID)
                table_wipe(tempBuffSubCounts)
                for _, entry in ipairs(order) do
                    local aN = entry.afterNative or 0
                    local sub = (tempBuffSubCounts[aN] or 0) + 1
                    tempBuffSubCounts[aN] = sub
                    -- MiliUI: 光環格的持有框跟施法計時的圖示共用同一張未分組順序表
                    local frame = (CB.auraSlots and CB.auraSlots[entry.spellID]) or iconFrames[entry.spellID]
                    if frame then
                        frame.cdmSortPrimary = aN
                        frame.cdmSortSecondary = sub
                    end
                end
            end
        end

        SortAndPositionBuffFrames(tempBuff, buffContainer)

        if full and CDM.Glow then
            local hasBuffGlows = specID and CDM:HasAnySpellGlowConfigured(specID) or false
            for _, frame in ipairs(tempBuff) do
                if hasBuffGlows then
                    local glowEnabled, glowColor, glowSourceID = CDM:ResolveBuffGlowState(frame, specID, false)
                    CDM.Glow:RequestBuffGlow(frame, "buff", glowEnabled, glowColor, glowSourceID)
                else
                    CDM.Glow:RequestBuffGlow(frame, "buff", false, nil, nil)
                end
            end
        end
    end

    if full and cachedHasStaticGroups then
        local bgSets = CDM.BuffGroupSets
        if bgSets and bgSets.groups then
            for groupIdx, groupData in ipairs(bgSets.groups) do
                if groupData.staticDisplay and groupData.spells and (not tempBuffGroups[groupIdx] or #tempBuffGroups[groupIdx] == 0) then
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
            local cdGroupIdx = CheckCdGroupMatch(frame)
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
        if #groupFrames > 0 then
            activeSelf:PositionCooldownGroupFrames(groupIdx, groupFrames)
        end
    end
end

function CDM:RepositionBuffViewer(viewer)
    if not viewer or self.pendingSpecChange then return false end
    RunBuffPipeline(self, viewer, VIEWERS.BUFF, false)
    self:UpdateBuffGroupOverlays(tempBuffGroups, tempBuff)
    if self.Fading then self.Fading:ReapplyCurrent() end
    return true
end

local function CollectBarFramesInto(barTbl, groupTbls, inEditMode)
    local viewer = _G[VIEWERS.BUFF_BAR]
    if not viewer or not viewer.itemFramePool then return viewer end

    for frame in viewer.itemFramePool:EnumerateActive() do
        local matchType, _, groupIdx = CheckBarRegistryMatch(frame)
        if matchType == "bargroup" and groupIdx then
            if not groupTbls[groupIdx] then groupTbls[groupIdx] = {} end
            groupTbls[groupIdx][#groupTbls[groupIdx] + 1] = frame
        elseif inEditMode or frame:IsShown() or frame.cooldownInfo then
            barTbl[#barTbl + 1] = frame
        end
    end

    return viewer
end

local function RunBarPipeline(activeSelf, viewer, vName)
    if not viewer or not viewer.itemFramePool then return end

    table_wipe(tempBarUngrouped)
    for _, t in pairs(tempBarGroups) do table_wipe(t) end

    local inEditMode = activeSelf.isEditModeActive or EditModeManagerFrame:IsShown()

    CollectBarFramesInto(tempBarUngrouped, tempBarGroups, inEditMode)

    for groupIdx, groupFrames in pairs(tempBarGroups) do
        if #groupFrames > 0 then
            activeSelf:PositionBarGroupFrames(groupIdx, groupFrames, vName)
        end
    end

    activeSelf:PositionBuffBarFrames(viewer, vName, tempBarUngrouped)
end

function CDM:RepositionBuffBarViewer(viewer)
    if not viewer or self.pendingSpecChange then return false end
    RunBarPipeline(self, viewer, viewer:GetName())
    if self.Fading then self.Fading:ReapplyCurrent() end
    return true
end

local function RunReanchor(activeSelf, activeViewer, activeVName)
    local inEditMode = activeSelf.isEditModeActive or EditModeManagerFrame:IsShown()

    ResetReanchorTempTables()
    CollectFramesForReanchor(activeViewer, activeVName, inEditMode)

    if activeVName == VIEWERS.ESSENTIAL then
        local essContainer = activeSelf.anchorContainers[VIEWERS.ESSENTIAL]
        local prevWidth = essContainer and essContainer:GetWidth() or 0
        activeSelf:PositionEssentialOrUtilityIcons(tempEssential, activeViewer, activeVName)

        local newWidth = essContainer and essContainer:GetWidth() or 0
        if newWidth ~= prevWidth then
            activeSelf:ReanchorContainer(VIEWERS.UTILITY)
            activeSelf:UpdateResources()
            activeSelf:UpdatePlayerCastBar()
        end

        if next(CDM.CooldownGroupSets.cooldownIDGrouped) then
            CollectCrossViewerGroupFrames(activeVName, inEditMode)
            DispatchCooldownGroupFrames(activeSelf)
        end

    elseif activeVName == VIEWERS.UTILITY then
        local utilContainer = activeSelf.anchorContainers[VIEWERS.UTILITY]
        local prevWidth = utilContainer and utilContainer:GetWidth() or 0
        activeSelf:PositionEssentialOrUtilityIcons(tempUtility, activeViewer, activeVName)
        activeSelf:InvalidateUtilityVisibleCountCache()
        local newWidth = utilContainer and utilContainer:GetWidth() or 0
        if newWidth ~= prevWidth then
            activeSelf:UpdatePlayerCastBar()
        end

        if next(CDM.CooldownGroupSets.cooldownIDGrouped) then
            CollectCrossViewerGroupFrames(activeVName, inEditMode)
            DispatchCooldownGroupFrames(activeSelf)
        end

    elseif activeVName == VIEWERS.BUFF then
        RunBuffPipeline(activeSelf, activeViewer, activeVName, true)
        activeSelf:UpdateBuffGroupOverlays(tempBuffGroups, tempBuff)

    elseif activeVName == VIEWERS.BUFF_BAR then
        RunBarPipeline(activeSelf, activeViewer, activeVName)
    end
end

function CDM:ForceReanchor(viewer)
    if not viewer or self.pendingSpecChange then return false end
    local vName = viewer:GetName()
    if not vName then return false end

    RunReanchor(self, viewer, vName)
    if self.Fading then self.Fading:ReapplyCurrent() end
    return true
end
