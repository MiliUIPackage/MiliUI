local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local API = CDM.API
local CDM_C = CDM.CONST
local Pixel = CDM.Pixel
local Snap = Pixel.Snap

local GetFrameData = CDM.GetFrameData
local NormalizeToBase = CDM.NormalizeToBase
local StoreVariantValue = CDM.SpellVariant.StoreValue
local VIEWERS = CDM_C.VIEWERS

local cdContainers = {}

CDM.cooldownGroupContainers = cdContainers

CDM._auraOverlayEnabled = CDM._auraOverlayEnabled or {}

local GCU = CDM.GroupContainerUtils

local cdDescriptor = GCU.CreateDescriptor({
    containers = cdContainers,
    namePrefix = "Ayije_CDM_CdGroup",
    callbackPrefix = "CDM_CdGroup_",
    getSets = function() return CDM.CooldownGroupSets end,
})

local function GetContainerForAnchorTarget(anchorTarget)
    local anchorContainers = CDM.anchorContainers
    if not anchorContainers then return nil end
    if anchorTarget == "essential" then
        return anchorContainers[CDM_C.VIEWERS.ESSENTIAL]
    end
    if anchorTarget == "utility" then
        return anchorContainers[CDM_C.VIEWERS.UTILITY]
    end
    if anchorTarget == "buff" then
        return anchorContainers[CDM_C.VIEWERS.BUFF]
    end
    return nil
end

function CDM:UpdateAllCooldownGroupContainers()
    local sets = CDM.CooldownGroupSets

    if not sets or not sets.groups then
        for idx, container in pairs(cdDescriptor.containers) do
            container:Hide()
        end
        cdDescriptor:SyncCallbacks(GetContainerForAnchorTarget)
    else
        local activeIndices = {}
        for groupIndex, groupData in ipairs(sets.groups) do
            local container = cdDescriptor:GetOrCreateContainer(groupIndex)
            cdDescriptor:UpdateContainerPosition(groupIndex, groupData, GetContainerForAnchorTarget)
            local at = groupData.anchorTarget or "screen"
            if not container:IsShown() and at ~= "essential" and at ~= "utility" and at ~= "buff" and at ~= "playerFrame" then
                container:Show()
            end
            activeIndices[groupIndex] = true
        end

        for idx, container in pairs(cdDescriptor.containers) do
            if not activeIndices[idx] then
                container:Hide()
            end
        end

        cdDescriptor:SyncCallbacks(GetContainerForAnchorTarget)
    end
end

local scratchSpellOrder = {}

local function GetCooldownLayoutCtx()
    return CDM._LayoutCtx
end

local function GetSpellOverride(groupData, spellID)
    if not groupData or not groupData.spellOverrides or not spellID then return nil end
    if CDM.ResolveBuffOverrideEntry then
        return CDM:ResolveBuffOverrideEntry(groupData.spellOverrides, spellID)
    end
    return groupData.spellOverrides[spellID]
end

CDM.GetCooldownGroupSpellOverride = GetSpellOverride

function CDM:PositionCooldownGroupFrames(groupIndex, frames)
    local layout = GetCooldownLayoutCtx()
    if not layout then return end

    local sets = CDM.CooldownGroupSets
    if not sets or not sets.groups then return end

    local groupData = sets.groups[groupIndex]
    if not groupData then return end

    local container = cdDescriptor:GetOrCreateContainer(groupIndex)

    if not container:IsShown() then
        for _, frame in ipairs(frames) do
            frame:Hide()
        end
        return
    end

    local grow = groupData.grow
    if grow ~= "RIGHT" and grow ~= "LEFT" and grow ~= "UP" and grow ~= "DOWN" and grow ~= "CENTER_H" and grow ~= "CENTER_V" then
        grow = "RIGHT"
    end
    local spacing = groupData.spacing or 4
    local iconW = groupData.iconWidth or 30
    local iconH = groupData.iconHeight or 30
    local anchorPoint = groupData.anchorPoint or "CENTER"
    local selfPoint = layout.DeriveSelfPoint(anchorPoint, grow)
    local iconWSnapped = Snap(iconW)
    local iconHSnapped = Snap(iconH)
    local spacingSnapped = Snap(spacing)
    local count = #frames
    local maxPerRow = groupData.maxPerRow or 0

    container:SetSize(iconWSnapped, iconHSnapped)

    if count == 0 then return end

    local cacheKey = "cdGroupSpellID"

    if groupData.spells then
        table.wipe(scratchSpellOrder)
        for i, sid in ipairs(groupData.spells) do
            StoreVariantValue(scratchSpellOrder, sid, i, true)
        end
        if count > 1 then
            local stableSortIDFn = layout.GetStableFrameSortID
            table.sort(frames, function(a, b)
                local aID = GetFrameData(a)[cacheKey]
                local bID = GetFrameData(b)[cacheKey]
                local aOrd = aID and scratchSpellOrder[aID] or 999
                local bOrd = bID and scratchSpellOrder[bID] or 999
                if aOrd ~= bOrd then return aOrd < bOrd end
                if stableSortIDFn then
                    return stableSortIDFn(a) < stableSortIDFn(b)
                end
                return false
            end)
        end
    end

    for i, frame in ipairs(frames) do
        local idx = i - 1
        local row, col
        if maxPerRow > 0 and maxPerRow < count then
            row = math.floor(idx / maxPerRow)
            col = idx - row * maxPerRow
        end

        local frameViewer = frame.viewerFrame or (frame.GetViewerFrame and frame:GetViewerFrame())
        local frameVName = (frameViewer == _G[VIEWERS.ESSENTIAL]) and VIEWERS.ESSENTIAL or VIEWERS.UTILITY
        self:ApplyStyle(frame, frameVName)

        frame:SetParent(UIParent)
        frame:ClearAllPoints()

        if row and col then
            local xPx, yPx
            if grow == "RIGHT" then
                xPx = col * (iconWSnapped + spacingSnapped)
                yPx = -row * (iconHSnapped + spacingSnapped)
            elseif grow == "LEFT" then
                xPx = -col * (iconWSnapped + spacingSnapped)
                yPx = -row * (iconHSnapped + spacingSnapped)
            elseif grow == "DOWN" then
                local dcol = math.floor(idx / maxPerRow)
                local drow = idx - dcol * maxPerRow
                xPx = dcol * (iconWSnapped + spacingSnapped)
                yPx = -drow * (iconHSnapped + spacingSnapped)
            elseif grow == "UP" then
                local ucol = math.floor(idx / maxPerRow)
                local urow = idx - ucol * maxPerRow
                xPx = ucol * (iconWSnapped + spacingSnapped)
                yPx = urow * (iconHSnapped + spacingSnapped)
            else
                xPx = col * (iconWSnapped + spacingSnapped)
                yPx = -row * (iconHSnapped + spacingSnapped)
            end
            layout.PlaceFrame(frame, container, selfPoint, anchorPoint, xPx or 0, yPx or 0)
        else
            layout.PositionFrameAtSlot(frame, container, idx, iconWSnapped, iconHSnapped, spacingSnapped, grow, count, anchorPoint, selfPoint)
        end

        frame:Show()
    end
end

local DOT_OVERRIDE_SPELLS = CDM_C.DOT_OVERRIDE_SPELLS

local function AddToEnabledMap(map, spellID, entry, isDotDefault, auraOverlay)
    local mapEntry = {}
    if auraOverlay then
        mapEntry.auraOverlay = true
    end
    if entry and entry.auraDesaturateInactive ~= nil then
        mapEntry.auraDesaturateInactive = entry.auraDesaturateInactive
    elseif isDotDefault then
        mapEntry.auraDesaturateInactive = true
    end
    if entry then
        if entry.auraGlowEnabled then mapEntry.auraGlowEnabled = true end
        if entry.auraGlowColor then mapEntry.auraGlowColor = entry.auraGlowColor end
        if entry.auraBorderEnabled then mapEntry.auraBorderEnabled = true end
        if entry.auraBorderColor then mapEntry.auraBorderColor = entry.auraBorderColor end
        if entry.readyGlowEnabled then mapEntry.readyGlowEnabled = true end
        if entry.readyGlowColor then mapEntry.readyGlowColor = entry.readyGlowColor end
    end
    if CDM.GetBuffGroupMatchCandidates then
        for _, id in ipairs(CDM:GetBuffGroupMatchCandidates(spellID)) do
            map[id] = mapEntry
        end
    else
        map[spellID] = mapEntry
    end
end

function CDM:RebuildAuraOverlayEnabledMap()
    local map = CDM._auraOverlayEnabled
    table.wipe(map)

    local specID = CDM.GetCurrentSpecID and CDM:GetCurrentSpecID()
    if not specID then
        CDM._auraOverlayVersion = (CDM._auraOverlayVersion or 0) + 1
        CDM.styleCacheVersion = (CDM.styleCacheVersion or 0) + 1
        return
    end

    local seen = {}

    local sets = CDM.CooldownGroupSets
    local groups = sets and sets.groups
    if groups then
        for _, group in ipairs(groups) do
            if group.spells then
                for _, spellID in ipairs(group.spells) do
                    local canonical = NormalizeToBase(spellID) or spellID
                    if not seen[canonical] then
                        seen[canonical] = true
                        local ov = GetSpellOverride(group, spellID)
                        if ov and ov.showAuraOverlay == false then
                            if ov.readyGlowEnabled then
                                AddToEnabledMap(map, spellID, ov, false, false)
                            end
                        elseif ov and ov.showAuraOverlay == true then
                            AddToEnabledMap(map, spellID, ov, DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[spellID], true)
                        elseif DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[spellID] then
                            AddToEnabledMap(map, spellID, ov, true, true)
                        elseif ov and ov.readyGlowEnabled then
                            AddToEnabledMap(map, spellID, ov, false, false)
                        end
                    end
                end
            end
        end
    end

    local specOv = CDM.db and CDM.db.ungroupedCooldownOverrides and CDM.db.ungroupedCooldownOverrides[specID]
    if specOv then
        for sid, entry in pairs(specOv) do
            local canonical = NormalizeToBase(sid) or sid
            if type(entry) == "table" and not seen[canonical] then
                seen[canonical] = true
                if entry.showAuraOverlay == false then
                    if entry.readyGlowEnabled then
                        AddToEnabledMap(map, sid, entry, false, false)
                    end
                elseif entry.showAuraOverlay == true then
                    AddToEnabledMap(map, sid, entry, DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[sid], true)
                elseif DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[sid] then
                    AddToEnabledMap(map, sid, entry, true, true)
                elseif entry.readyGlowEnabled then
                    AddToEnabledMap(map, sid, entry, false, false)
                end
            end
        end
    end

    if DOT_OVERRIDE_SPELLS then
        for spellID in pairs(DOT_OVERRIDE_SPELLS) do
            local canonical = NormalizeToBase(spellID) or spellID
            if not seen[canonical] then
                seen[canonical] = true
                AddToEnabledMap(map, spellID, nil, true, true)
            end
        end
    end

    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet
        and C_CooldownViewer.GetCooldownViewerCooldownInfo
        and Enum.CooldownViewerCategory then
        local categories = {
            Enum.CooldownViewerCategory.Essential,
            Enum.CooldownViewerCategory.Utility,
        }
        for _, cat in ipairs(categories) do
            local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
            if cooldownIDs then
                for _, cdID in ipairs(cooldownIDs) do
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    if info then
                        local matchEntry = map[info.spellID]
                        if not matchEntry and info.overrideSpellID then
                            matchEntry = map[info.overrideSpellID]
                        end
                        if not matchEntry and info.linkedSpellIDs then
                            for _, lid in ipairs(info.linkedSpellIDs) do
                                matchEntry = map[lid]
                                if matchEntry then break end
                            end
                        end
                        if matchEntry then
                            map[info.spellID] = matchEntry
                            if info.overrideSpellID then
                                map[info.overrideSpellID] = matchEntry
                            end
                            if info.linkedSpellIDs then
                                for _, lid in ipairs(info.linkedSpellIDs) do
                                    map[lid] = matchEntry
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    CDM._auraOverlayVersion = (CDM._auraOverlayVersion or 0) + 1
    CDM.styleCacheVersion = (CDM.styleCacheVersion or 0) + 1
end

function CDM:GetUngroupedCooldownOverride(spellID, specID)
    if not spellID then return nil end
    specID = specID or (self.GetCurrentSpecID and self:GetCurrentSpecID())
    if not specID then return nil end
    local db = self.db
    if not db or not db.ungroupedCooldownOverrides then return nil end
    local specOv = db.ungroupedCooldownOverrides[specID]
    if not specOv then return nil end
    if self.ResolveBuffOverrideEntry then
        return self:ResolveBuffOverrideEntry(specOv, spellID)
    end
    return specOv[spellID]
end

function CDM:EnsureUngroupedCooldownOverrideEntry(spellID, specID)
    if not spellID then return nil end
    specID = specID or (self.GetCurrentSpecID and self:GetCurrentSpecID())
    if not specID then return nil end
    local db = self.db
    if not db then return nil end
    if not db.ungroupedCooldownOverrides then db.ungroupedCooldownOverrides = {} end
    if not db.ungroupedCooldownOverrides[specID] then db.ungroupedCooldownOverrides[specID] = {} end
    if self.EnsureBuffOverrideEntry then
        return self:EnsureBuffOverrideEntry(db.ungroupedCooldownOverrides[specID], spellID)
    end
    local ov = db.ungroupedCooldownOverrides[specID]
    if not ov[spellID] then ov[spellID] = {} end
    return ov[spellID]
end

CDM:RegisterRefreshCallback("cooldownGroups", function()
    CDM:MarkSpecDataDirty()
    CDM:RefreshSpecData()
    CDM:RebuildAuraOverlayEnabledMap()
    CDM:UpdateAllCooldownGroupContainers()
    if CDM.QueueViewer then
        CDM:QueueViewer(CDM_C.VIEWERS.ESSENTIAL, true)
        CDM:QueueViewer(CDM_C.VIEWERS.UTILITY, true)
    end
end, 29, { "spec_data", "viewers", "trackers_layout" })

CDM:RegisterRefreshCallback("cooldownGroups_postViewer", function()
    CDM:UpdateAllCooldownGroupContainers()
end, 45, { "viewers" })
