local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local GetFrameData = CDM.GetFrameData
local IsSafeNumber = CDM.IsSafeNumber
CDM.GroupContainerUtils = {}

function CDM.GroupContainerUtils.AssignGroupSortKeys(frames, spellOrder, frameDataKey)
    for _, frame in ipairs(frames) do
        local fd = GetFrameData(frame)
        local fID = fd[frameDataKey]
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
        fd.cdmSortKey = ord or 999
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

function CDM.GroupContainerUtils.CreateDescriptor(opts)
    local desc = {}
    desc.containers = opts.containers
    desc.registered = {}

    local namePrefix = opts.namePrefix
    local callbackPrefix = opts.callbackPrefix
    local getSets = opts.getSets

    function desc:GetOrCreateContainer(groupIndex)
        if self.containers[groupIndex] then
            return self.containers[groupIndex]
        end

        local container = CreateFrame("Frame", namePrefix .. groupIndex, UIParent)
        container:SetSize(1, 1)
        container:SetClampedToScreen(false)
        container:Show()

        self.containers[groupIndex] = container
        return container
    end

    function desc:UpdateContainerPosition(groupIndex, groupData, getAnchorTarget)
        local container = self.containers[groupIndex]
        if not container or not groupData then return end

        local anchorTarget = groupData.anchorTarget or "screen"
        local anchorPoint = groupData.anchorPoint or "CENTER"
        local relativePoint = groupData.anchorRelativeTo or "CENTER"
        local offsetX = groupData.offsetX or 0
        local offsetY = groupData.offsetY or 0

        local iconW = groupData.iconWidth or 30
        local iconH = groupData.iconHeight or 30
        Pixel.SetSize(container, iconW, iconH)

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
            local targetContainer = getAnchorTarget(anchorTarget)
            if targetContainer then
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
