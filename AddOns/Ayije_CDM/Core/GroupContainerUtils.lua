local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local Pixel = CDM.Pixel

local IsSafeNumber = CDM.IsSafeNumber
CDM.GroupContainerUtils = {}

function CDM.GroupContainerUtils.AssignGroupSortKeys(frames, spellOrder, frameKey)
    for _, frame in ipairs(frames) do
        local fID = frame[frameKey]
        local ord = fID and spellOrder[fID] or nil
        if not ord then
            local fInfo = frame.GetCooldownInfo and frame:GetCooldownInfo() or frame.cooldownInfo
            if fInfo and fInfo.linkedSpellIDs then
                for _, lid in ipairs(fInfo.linkedSpellIDs) do
                    if IsSafeNumber(lid) then
                        ord = spellOrder[lid]
                        if ord then break end
                    end
                end
            end
        end
        frame.cdmSortKey = ord or 999
    end
end

function CDM.GroupContainerUtils.AnchorToTarget(container, targetContainer, anchorPoint, relativePoint, offsetX, offsetY)
    if not targetContainer or not targetContainer:IsShown() then
        container:ClearAllPoints()
        container:Hide()
        return false
    end
    container:ClearAllPoints()
    Pixel.SetPoint(container, anchorPoint, targetContainer, relativePoint, offsetX, offsetY)
    if not container:IsShown() then
        container:Show()
    end
    return true
end

-- MiliUI: cacheSize 為真時值沒變就不寫（Snap 後比對，跟 PositionBuffGroupFrames 寫的
-- cdmGroupSizeW/H 同一對欄位、同一種值）；否則照舊 Pixel.SetSize
local function SetContainerSize(container, w, h, cacheSize)
    if not cacheSize then
        Pixel.SetSize(container, w, h)
        return
    end
    local sw, sh = Pixel.Snap(w), Pixel.Snap(h)
    if container.cdmGroupSizeW == sw and container.cdmGroupSizeH == sh then return end
    container:SetSize(sw, sh)
    container.cdmGroupSizeW, container.cdmGroupSizeH = sw, sh
end

function CDM.GroupContainerUtils.CreateDescriptor(opts)
    local desc = {}
    desc.containers = opts.containers
    desc.registered = {}

    local namePrefix = opts.namePrefix
    local callbackPrefix = opts.callbackPrefix
    local getSets = opts.getSets
    local getInitialSize = opts.getInitialSize
    local containerFrameLevel = opts.containerFrameLevel
    -- MiliUI: 光環格用（只有增益群組的 descriptor 會帶）。
    --   deferInCombat(groupIndex, groupData)：回 true ＝ 這個群組戰鬥中整支不動、延到脫戰
    --   cacheSize：尺寸值沒變不寫，快取欄位跟 BuffGroups.lua 的 PositionBuffGroupFrames 共用
    -- 沒帶這兩個的 descriptor（冷卻群組、長條群組）行為不變。
    local deferInCombat = opts.deferInCombat
    local cacheSize = opts.cacheSize

    function desc:GetOrCreateContainer(groupIndex)
        if self.containers[groupIndex] then
            return self.containers[groupIndex]
        end

        local container = CreateFrame("Frame", namePrefix .. groupIndex, UIParent)
        container:SetSize(1, 1)
        container:SetClampedToScreen(false)
        if containerFrameLevel then
            container:SetFrameLevel(containerFrameLevel)
        end
        container:Show()

        self.containers[groupIndex] = container
        return container
    end

    function desc:UpdateContainerPosition(groupIndex, groupData, getAnchorTarget)
        local container = self.containers[groupIndex]
        if not container or not groupData then return end
        -- MiliUI: 群組容器被光環格的持有框錨定 ⇒ 隱式保護框，戰鬥中 SetSize／SetPoint／
        -- Show／Hide 都會被擋，整支延到脫戰
        if deferInCombat and InCombatLockdown() and deferInCombat(groupIndex, groupData) then
            return
        end

        local anchorTarget = groupData.anchorTarget or "screen"
        local anchorPoint = groupData.anchorPoint or "CENTER"
        local relativePoint = groupData.anchorRelativeTo or "CENTER"
        local offsetX = groupData.offsetX or 0
        local offsetY = groupData.offsetY or 0

        if getInitialSize then
            local w, h = getInitialSize(groupData)
            if w and h and w > 0 and h > 0 then
                SetContainerSize(container, w, h, cacheSize)
            end
        else
            local iconW = groupData.iconWidth or 30
            local iconH = groupData.iconHeight or 30
            SetContainerSize(container, iconW, iconH, cacheSize)
        end

        if anchorTarget == "playerFrame" then
            CDM.AnchorToPlayerFrame(
                container,
                relativePoint,
                offsetX, offsetY,
                callbackPrefix .. groupIndex,
                false,
                anchorPoint
            )
        else
            CDM.InvalidateTrackerAnchorCache(container)
            local targetContainer, useCenterFallback = getAnchorTarget(anchorTarget)
            if targetContainer and useCenterFallback then
                container:ClearAllPoints()
                Pixel.SetPoint(container, "CENTER", targetContainer, "CENTER", offsetX, offsetY)
                if not container:IsShown() then
                    container:Show()
                end
            elseif targetContainer then
                CDM.GroupContainerUtils.AnchorToTarget(container, targetContainer, anchorPoint, relativePoint, offsetX, offsetY)
            elseif anchorTarget == "screen" then
                container:ClearAllPoints()
                Pixel.SetPoint(container, "CENTER", UIParent, "CENTER", offsetX, offsetY)
                if not container:IsShown() then
                    container:Show()
                end
            else
                if container:IsShown() then
                    container:Hide()
                end
            end
        end
    end

    function desc:SyncCallbacks(getAnchorTarget)
        local sets = getSets()
        local groups = sets and sets.groups
        local needed = {}

        if groups then
            for idx, gd in ipairs(groups) do
                if (gd.anchorTarget or "screen") == "playerFrame" then
                    needed[idx] = true
                end
            end
        end

        for idx in pairs(needed) do
            if not self.registered[idx] then
                local capturedIdx = idx
                CDM.RegisterTrackerPositionCallback(callbackPrefix .. capturedIdx, function()
                    local s = getSets()
                    local g = s and s.groups and s.groups[capturedIdx]
                    if g and (g.anchorTarget or "screen") == "playerFrame" then
                        CDM.InvalidateTrackerAnchorCache(self.containers[capturedIdx])
                        self:UpdateContainerPosition(capturedIdx, g, getAnchorTarget)
                    end
                end)
                self.registered[idx] = true
            end
        end

        local toRemove
        for idx in pairs(self.registered) do
            if not needed[idx] then
                if not toRemove then toRemove = {} end
                toRemove[#toRemove + 1] = idx
            end
        end
        if toRemove then
            for _, idx in ipairs(toRemove) do
                CDM.UnregisterTrackerPositionCallback(callbackPrefix .. idx)
                self.registered[idx] = nil
            end
        end
    end

    return desc
end
