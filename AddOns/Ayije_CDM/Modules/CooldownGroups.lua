local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local API = CDM.API
local CDM_C = CDM.CONST
local Pixel = CDM.Pixel
local Snap = Pixel.Snap
local HalfFloor = Pixel.HalfFloor

local IsSafeNumber = CDM.IsSafeNumber
local VIEWERS = CDM_C.VIEWERS

local math_ceil = math.ceil
local math_floor = math.floor
local table_wipe = table.wipe
local table_sort = table.sort

local cdContainers = {}

CDM.cooldownGroupContainers = cdContainers

CDM._auraOverlayEnabled = CDM._auraOverlayEnabled or {}
CDM._readyGlowCooldownIDs = CDM._readyGlowCooldownIDs or {}

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

local scratchCdActiveIndices = {}

function CDM:UpdateViewerAnchoredCooldownGroupContainers()
    local sets = CDM.CooldownGroupSets
    if not sets or not sets.groups then return end
    for groupIndex, groupData in ipairs(sets.groups) do
        local at = groupData.anchorTarget
        if at == "essential" or at == "utility" or at == "buff" then
            cdDescriptor:UpdateContainerPosition(groupIndex, groupData, GetContainerForAnchorTarget)
        end
    end
end

function CDM:UpdateAllCooldownGroupContainers()
    local sets = CDM.CooldownGroupSets

    if not sets or not sets.groups then
        for idx, container in pairs(cdDescriptor.containers) do
            container:Hide()
        end
        cdDescriptor:SyncCallbacks(GetContainerForAnchorTarget)
    else
        local activeIndices = scratchCdActiveIndices
        table_wipe(activeIndices)
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

local function GetSpellOverride(groupData, spellID)
    if not groupData or not groupData.spellOverrides or not spellID then return nil end
    return CDM:ResolveBuffOverrideEntry(groupData.spellOverrides, spellID)
end

CDM.GetCooldownGroupSpellOverride = GetSpellOverride

function CDM:PositionCooldownGroupFrames(groupIndex, frames)
    local layout = CDM._LayoutCtx
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

    local cacheKey = "cdmCdGroupSpellID"

    if groupData.spells then
        table_wipe(scratchSpellOrder)
        for i, sid in ipairs(groupData.spells) do
            if not scratchSpellOrder[sid] then scratchSpellOrder[sid] = i end
        end
        if count > 1 then
            local stableSortIDFn = layout.GetStableFrameSortID
            GCU.AssignGroupSortKeys(frames, scratchSpellOrder, cacheKey)
            table_sort(frames, function(a, b)
                local aKey = a.cdmSortKey
                local bKey = b.cdmSortKey
                if aKey ~= bKey then return aKey < bKey end
                if stableSortIDFn then
                    return stableSortIDFn(a) < stableSortIDFn(b)
                end
                return false
            end)
        end
    end

    local stepW = iconWSnapped + spacingSnapped
    local stepH = iconHSnapped + spacingSnapped
    local totalWraps = (maxPerRow > 0 and maxPerRow < count) and math_ceil(count / maxPerRow) or 0

    for i, frame in ipairs(frames) do
        local idx = i - 1
        local row, col
        if maxPerRow > 0 and maxPerRow < count then
            row = math_floor(idx / maxPerRow)
            col = idx - row * maxPerRow
        end

        local frameViewer = frame.viewerFrame
        local frameVName = (frameViewer == _G[VIEWERS.ESSENTIAL]) and VIEWERS.ESSENTIAL or VIEWERS.UTILITY
        self:ApplyStyle(frame, frameVName)

        if row and col then
            local xPx, yPx
            if grow == "RIGHT" then
                xPx = col * stepW
                yPx = -row * stepH
            elseif grow == "LEFT" then
                xPx = -col * stepW
                yPx = -row * stepH
            elseif grow == "DOWN" then
                local dcol = math_floor(idx / maxPerRow)
                local drow = idx - dcol * maxPerRow
                xPx = dcol * stepW
                yPx = -drow * stepH
            elseif grow == "UP" then
                local ucol = math_floor(idx / maxPerRow)
                local urow = idx - ucol * maxPerRow
                xPx = ucol * stepW
                yPx = urow * stepH
            elseif grow == "CENTER_H" then
                local countInRow = (row < totalWraps - 1) and maxPerRow or (count - row * maxPerRow)
                xPx = -HalfFloor((countInRow - 1) * stepW) + col * stepW
                yPx = HalfFloor((totalWraps - 1) * stepH) - row * stepH
            elseif grow == "CENTER_V" then
                local vcol = math_floor(idx / maxPerRow)
                local vrow = idx - vcol * maxPerRow
                local countInCol = (vcol < totalWraps - 1) and maxPerRow or (count - vcol * maxPerRow)
                xPx = -HalfFloor((totalWraps - 1) * stepW) + vcol * stepW
                yPx = HalfFloor((countInCol - 1) * stepH) - vrow * stepH
            end
            layout.PlaceFrame(frame, container, selfPoint, anchorPoint, xPx or 0, yPx or 0)
        else
            layout.PositionFrameAtSlot(frame, container, idx, iconWSnapped, iconHSnapped, spacingSnapped, grow, count, anchorPoint, selfPoint)
        end

        frame:Show()
    end
end

local DOT_OVERRIDE_SPELLS = CDM_C.DOT_OVERRIDE_SPELLS

local function BuildMapEntry(entry, isDotDefault, auraOverlay)
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
    return mapEntry
end

local function IsOverrideDot(info)
    return DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[info.overrideSpellID] and true or false
end

local function AuraOverlayFallback(info, spellToEntry)
    local match
    CDM:ForEachSpellMatchCandidate(info.spellID, function(candidate)
        local entry = spellToEntry[candidate]
        if not entry then return end
        if entry.dotDefaultOnly then return end
        match = entry
        return true
    end)
    return match
end

local AURA_OVERLAY_MATCH_OPTS = {
    validator = IsSafeNumber,
    isOverrideDot = IsOverrideDot,
    fallback = AuraOverlayFallback,
}
CDM.AURA_OVERLAY_MATCH_OPTS = AURA_OVERLAY_MATCH_OPTS

local scratchSeen = {}

function CDM:_BuildAuraOverlaySpellMap(specID)
    if not specID then return {} end

    local seen = scratchSeen
    table_wipe(seen)

    local spellToEntry = {}

    local sets = CDM.CooldownGroupSets
    local groups = sets and sets.groups
    if groups then
        for _, group in ipairs(groups) do
            if group.spells then
                for _, spellID in ipairs(group.spells) do
                    if not seen[spellID] then
                        seen[spellID] = true
                        local ov = GetSpellOverride(group, spellID)
                        if ov and ov.showAuraOverlay == false then
                            if ov.readyGlowEnabled then
                                spellToEntry[spellID] = BuildMapEntry(ov, false, false)
                            end
                        elseif ov and ov.showAuraOverlay == true then
                            spellToEntry[spellID] = BuildMapEntry(ov, DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[spellID], true)
                        elseif DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[spellID] then
                            spellToEntry[spellID] = BuildMapEntry(ov, true, true)
                        elseif ov and ov.readyGlowEnabled then
                            spellToEntry[spellID] = BuildMapEntry(ov, false, false)
                        end
                    end
                end
            end
        end
    end

    local specOv = CDM.db and CDM.db.ungroupedCooldownOverrides and CDM.db.ungroupedCooldownOverrides[specID]
    if specOv then
        for sid, entry in pairs(specOv) do
            if type(entry) == "table" and not seen[sid] then
                seen[sid] = true
                if entry.showAuraOverlay == false then
                    if entry.readyGlowEnabled then
                        spellToEntry[sid] = BuildMapEntry(entry, false, false)
                    end
                elseif entry.showAuraOverlay == true then
                    spellToEntry[sid] = BuildMapEntry(entry, DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[sid], true)
                elseif DOT_OVERRIDE_SPELLS and DOT_OVERRIDE_SPELLS[sid] then
                    spellToEntry[sid] = BuildMapEntry(entry, true, true)
                elseif entry.readyGlowEnabled then
                    spellToEntry[sid] = BuildMapEntry(entry, false, false)
                end
            end
        end
    end

    if DOT_OVERRIDE_SPELLS then
        for spellID in pairs(DOT_OVERRIDE_SPELLS) do
            if not seen[spellID] then
                seen[spellID] = true
                local mapEntry = BuildMapEntry(nil, true, true)
                mapEntry.dotDefaultOnly = true
                spellToEntry[spellID] = mapEntry
            end
        end
    end

    return spellToEntry
end

function CDM:_PostAuraOverlayBuild()
    if CDM.GlowDirector then CDM.GlowDirector:RebuildIndex() end
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
    return self:ResolveBuffOverrideEntry(specOv, spellID)
end

function CDM:EnsureUngroupedCooldownOverrideEntry(spellID, specID)
    if not spellID then return nil end
    specID = specID or (self.GetCurrentSpecID and self:GetCurrentSpecID())
    if not specID then return nil end
    local db = self.db
    if not db then return nil end
    if not db.ungroupedCooldownOverrides then db.ungroupedCooldownOverrides = {} end
    if not db.ungroupedCooldownOverrides[specID] then db.ungroupedCooldownOverrides[specID] = {} end
    return self:EnsureBuffOverrideEntry(db.ungroupedCooldownOverrides[specID], spellID)
end

CDM:RegisterRefreshCallback("cooldownGroups", function()
    CDM:UpdateAllCooldownGroupContainers()
end, 31, { "CD_DATA" })

CDM:RegisterRefreshCallback("cooldownGroups_postViewer", function()
    CDM:UpdateViewerAnchoredCooldownGroupContainers()
end, 45, { "LAYOUT", "CD_DATA" })
