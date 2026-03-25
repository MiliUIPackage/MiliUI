local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}

local DEFENSIVES = CDM_C.DEFENSIVE_SPELLS
local DEFENSIVES_SET = CDM_C.DEFENSIVE_SPELLS_SET
local EMPTY = {}

local _, playerClass = UnitClass("player")

local talentTreeCache = {}
local talentTreeCacheConfigID = nil

local function InvalidateTalentTreeCache()
    table.wipe(talentTreeCache)
    talentTreeCacheConfigID = nil
end

local function IsInTalentTree(spellID)
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID
        and C_Traits and C_Traits.GetConfigInfo
        and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo
        and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo)
    then
        return false
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return false end

    if configID ~= talentTreeCacheConfigID then
        InvalidateTalentTreeCache()
        talentTreeCacheConfigID = configID
    end

    if talentTreeCache[spellID] ~= nil then
        return talentTreeCache[spellID]
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs then
        talentTreeCache[spellID] = false
        return false
    end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodes = C_Traits.GetTreeNodes(treeID)
        if nodes then
            for _, nodeID in ipairs(nodes) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo and nodeInfo.entryIDs then
                    for _, entryID in ipairs(nodeInfo.entryIDs) do
                        local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                        if entryInfo and entryInfo.definitionID then
                            local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                            if defInfo and (defInfo.spellID == spellID or defInfo.overriddenSpellID == spellID) then
                                talentTreeCache[spellID] = true
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    talentTreeCache[spellID] = false
    return false
end

local function IsSpecSpell(spellID)
    if C_SpellBook.IsSpellKnown(spellID) then return true end
    if IsInTalentTree(spellID) then return true end

    local baseID = CDM.NormalizeToBase(spellID)
    if baseID and baseID ~= spellID then
        if C_SpellBook.IsSpellKnown(baseID) then return true end
        if IsInTalentTree(baseID) then return true end
    end

    if C_Spell.GetOverrideSpell then
        local overrideID = C_Spell.GetOverrideSpell(baseID or spellID)
        if CDM.IsSafeNumber(overrideID) and overrideID ~= spellID and overrideID ~= baseID and overrideID > 0 then
            if C_SpellBook.IsSpellKnown(overrideID) then return true end
        end
    end

    return false
end

CDM.IsSpecSpell = IsSpecSpell

local GetEffectiveSpellID = CDM.GetEffectiveSpellID

function CDM.GetBuiltinDefensiveSpells(specID)
    return CDM.GetBuiltinDefensiveSpellsForClass(playerClass, specID)
end

function CDM.GetBuiltinDefensiveSpellsForClass(classTag, specID)
    local classData = DEFENSIVES[classTag]
    if not classData then return EMPTY end
    local result = {}
    if classData.class then
        for _, id in ipairs(classData.class) do
            table.insert(result, id)
        end
    end
    if specID and classData[specID] then
        for _, id in ipairs(classData[specID]) do
            table.insert(result, id)
        end
    end
    return result
end

local defensivesHiddenSet = CDM.defensivesHiddenSet

local isInitialized = false
local isEnabled = false
local needsStyleUpdate = true
local lastDefensivesSpecID = nil
local DEFENSIVES_SPELL_WATCH_OWNER = "CDM_Defensives_Spells"
local function GetCurrentSpecID()
    return CDM:GetCurrentSpecID()
end

function CDM.GetCustomDefensiveSpells(specID)
    if not specID then return EMPTY end
    local custom = CDM.db and CDM.db.defensivesCustomSpells
    if not custom then return EMPTY end
    return custom[specID] or EMPTY
end

local customSpellSet = {}

local function RebuildCustomSpellSet(specID)
    table.wipe(customSpellSet)
    for _, id in ipairs(CDM.GetCustomDefensiveSpells(specID)) do
        customSpellSet[id] = true
    end
end

local orderedSpellsCache = {}
local orderedSpellsCacheSpecID = nil

local function InvalidateOrderedSpellsCache()
    table.wipe(orderedSpellsCache)
    orderedSpellsCacheSpecID = nil
end

function CDM.GetOrderedDefensiveSpells(specID, filterFn, classTag)
    if not filterFn and not classTag and specID == orderedSpellsCacheSpecID and #orderedSpellsCache > 0 then
        return orderedSpellsCache
    end

    local builtinSpells = classTag and CDM.GetBuiltinDefensiveSpellsForClass(classTag, specID)
        or CDM.GetBuiltinDefensiveSpells(specID)
    local savedOrder = specID and CDM.db.defensivesOrder and CDM.db.defensivesOrder[specID]
    local customSpells = CDM.GetCustomDefensiveSpells(specID)

    local builtinSet = {}
    for _, id in ipairs(builtinSpells) do
        if not filterFn or filterFn(id) then
            builtinSet[id] = true
        end
    end

    local customSet = {}
    for _, id in ipairs(customSpells) do customSet[id] = true end

    local result = {}
    local added = {}

    if savedOrder then
        for _, id in ipairs(savedOrder) do
            if builtinSet[id] or customSet[id] then
                table.insert(result, id)
                added[id] = true
            end
        end
    end

    for _, id in ipairs(builtinSpells) do
        if builtinSet[id] and not added[id] then
            table.insert(result, id)
            added[id] = true
        end
    end

    for _, id in ipairs(customSpells) do
        if not added[id] then
            table.insert(result, id)
        end
    end

    if not filterFn and not classTag then
        table.wipe(orderedSpellsCache)
        for _, id in ipairs(result) do
            orderedSpellsCache[#orderedSpellsCache + 1] = id
        end
        orderedSpellsCacheSpecID = specID
    end

    return result
end

local defensivesContainer
local iconEntries = {}
local iconFrames = {}
local iconFramePool = {}
local iconEntryPool = {}
local DesaturationCurve = CDM_C.DesaturationCurve
local GCDFilterCurve = CDM_C.GCDFilterCurve
local gcdActive = false
local GCD_SPELL_ID = CDM_C.GCD_SPELL_ID
local lastDefensivesVisibilityHash = 0
local lastDefensivesWidth, lastDefensivesHeight = nil, nil
local lastDefensivesSpacing = nil

local defensivesTrackerAcquireOpts = {
    size = nil,
    showCharges = true,
    named = false,
}

local function AcquireDefensiveIconEntry(spellID)
    local entry = table.remove(iconEntryPool)
    if entry then
        table.wipe(entry)
    else
        entry = {}
    end

    entry.spellID = spellID
    entry._spellbookCached = nil
    entry.frame = nil
    return entry
end

local function ReleaseDefensiveIconEntry(entry)
    if not entry then return end
    table.wipe(entry)
    iconEntryPool[#iconEntryPool + 1] = entry
end

local cachedDefensivesStyles = {
    fontPath = nil,
    fontOutline = nil,
    chargeFontSize = 10,
    chargeColor = { r = 1, g = 1, b = 1, a = 1 },
    chargePosition = "BOTTOMRIGHT",
    chargeOffsetX = 0,
    chargeOffsetY = 0,
}
local defensivesChargeStyleVersion = 0

local function RefreshCachedDefensivesStyles()
    CDM.RefreshChargeStyleCache(cachedDefensivesStyles, "defensives")
    defensivesChargeStyleVersion = defensivesChargeStyleVersion + 1
end

local GetSpacing = CDM.GetTrackerSpacing

local function CreateIconFrame(spellID)
    defensivesTrackerAcquireOpts.size = CDM.GetTrackerIconSize("defensivesIconWidth", "defensivesIconHeight")
    local frame = CDM.AcquireFromTrackerPool(iconFramePool, defensivesContainer, "CDM_Defensive_", spellID, defensivesTrackerAcquireOpts)

    frame.spellID = spellID
    frame._spellbookCached = nil

    local texture = C_Spell.GetSpellTexture(GetEffectiveSpellID(spellID))
    if texture and frame.Icon then
        frame.Icon:SetTexture(texture)
        frame.Icon:SetDesaturation(0)
    end

    return frame
end

local function BindEntryFrame(entry)
    local frame = entry.frame
    if frame then
        return frame, false
    end

    frame = CreateIconFrame(entry.spellID)
    frame._spellbookCached = entry._spellbookCached
    frame.cdmDefensiveEntry = entry
    entry.frame = frame
    return frame, true
end

local function ResetDefensiveTrackerFrame(f)
    f.cdmDefensiveEntry = nil
    f.spellID = nil
    f._spellbookCached = nil
    f._cdmDefensivesChargeStyleVersion = nil
end

local function ReleaseEntryFrame(entry)
    local frame = entry and entry.frame
    if not frame then return end

    entry.frame = nil
    CDM.ReleaseToTrackerPool(iconFramePool, frame, ResetDefensiveTrackerFrame)
end

local function ReleaseDefensiveFramesForLowMemory()
    for _, entry in ipairs(iconEntries) do
        ReleaseEntryFrame(entry)
    end
    table.wipe(iconFrames)
    if CDM.ClearTrackerPool then
        CDM.ClearTrackerPool(iconFramePool)
    end
    lastDefensivesVisibilityHash = -1
    lastDefensivesWidth = nil
    lastDefensivesHeight = nil
    lastDefensivesSpacing = nil
end

local function UpdateIcon(frame)
    if not frame or not frame:IsShown() then return end

    local hasCharges = false
    local desatDurationObject = nil

    local spellID = frame.spellID
    if not spellID then return end

    local effectiveID = GetEffectiveSpellID(spellID)

    local CCD = C_Spell.GetSpellChargeDuration(effectiveID)
    local SCD = C_Spell.GetSpellCooldownDuration(effectiveID)

    local isOnGCD = false
    if gcdActive and SCD then
        local cdInfo = C_Spell.GetSpellCooldown(effectiveID)
        isOnGCD = cdInfo and cdInfo.isOnGCD
    end

    if CCD then
        frame.Cooldown:SetCooldownFromDurationObject(CCD)
        frame.Cooldown:SetDrawSwipe(true)
    elseif SCD then
        frame.Cooldown:SetCooldownFromDurationObject(SCD)
        frame.Cooldown:SetDrawSwipe(true)
    else
        frame.Cooldown:Clear()
    end

    if SCD then
        desatDurationObject = SCD
    end

    local entry = frame.cdmDefensiveEntry
    if entry and entry.hasMultipleCharges then
        local chargeInfo = C_Spell.GetSpellCharges(effectiveID)
        if chargeInfo and chargeInfo.currentCharges then
            local chargeText = CDM.EnsureTrackerChargeWidgets(frame)
            if chargeText then
                chargeText:SetText(C_StringUtil.TruncateWhenZero(chargeInfo.currentCharges))
            end
            hasCharges = true
        end
    end

    if frame.Icon then
        if desatDurationObject then
            local curve = isOnGCD and GCDFilterCurve or DesaturationCurve
            if curve and desatDurationObject.EvaluateRemainingDuration then
                frame.Icon:SetDesaturation(desatDurationObject:EvaluateRemainingDuration(curve, 0) or 0)
            else
                frame.Icon:SetDesaturation(0)
            end
        else
            frame.Icon:SetDesaturation(0)
        end
    end

    if frame.ChargeCount and frame.ChargeCount.Current then
        local chargeText = frame.ChargeCount.Current

        if hasCharges then
            if frame._cdmDefensivesChargeStyleVersion ~= defensivesChargeStyleVersion or not chargeText:IsShown() then
                local styles = cachedDefensivesStyles
                if not styles.fontPath then
                    RefreshCachedDefensivesStyles()
                end
                CDM.StyleChargeText(chargeText, frame, styles)
                frame._cdmDefensivesChargeStyleVersion = defensivesChargeStyleVersion
            end
        else
            chargeText:Hide()
        end
    end
end

local function PositionIcons()
    CDM.PositionTrackerIconsFromDB(defensivesContainer, iconFrames, "defensivesIconWidth", "defensivesIconHeight", "spacing", "defensivesAnchorPoint")
end

local function IsCustomSpell(spellID)
    return customSpellSet[spellID] == true
end

local function InvalidateSpellbookCache()
    for _, entry in ipairs(iconEntries) do
        entry._spellbookCached = nil
        entry.hasMultipleCharges = nil
        if entry.frame then
            entry.frame._spellbookCached = nil
        end
    end
end

local function PlayerHasAbility(entry, specID)
    local spellID = entry.spellID
    if not spellID then return false end

    specID = specID or GetCurrentSpecID()
    local db = CDM.db
    local specDisabled = db and db.defensivesDisabledSpells and specID and db.defensivesDisabledSpells[specID]

    if specDisabled and specDisabled[spellID] then
        return false
    end

    if entry._spellbookCached ~= nil then
        return entry._spellbookCached
    end

    local known
    if IsCustomSpell(spellID) then
        known = C_SpellBook.IsSpellInSpellBook(spellID)
            or C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Pet)
    else
        known = C_SpellBook.IsSpellInSpellBook(spellID)
    end

    if not known then
        local effectiveID = GetEffectiveSpellID(spellID)
        if effectiveID ~= spellID then
            known = C_SpellBook.IsSpellInSpellBook(effectiveID)
        end
    end

    entry._spellbookCached = known
    if entry.frame then
        entry.frame._spellbookCached = known
    end
    return known
end

local function UpdateContainerPosition()
    if not defensivesContainer then return end

    local anchorPoint = CDM.db and CDM.db.defensivesAnchorPoint or "TOPLEFT"
    local offsetX = CDM.db and CDM.db.defensivesOffsetX or 0
    local offsetY = CDM.db and CDM.db.defensivesOffsetY or 0
    CDM.AnchorToPlayerFrame(defensivesContainer, anchorPoint, offsetX, offsetY, "Defensives")
end

local VIEWERS = CDM_C.VIEWERS
local RESHOW_VIEWERS = { VIEWERS.ESSENTIAL, VIEWERS.UTILITY }

local hiddenSetScratch = {}

local function RebuildHiddenSet()
    local db = CDM.db
    local shouldHide = db and db.defensivesEnabled ~= false and db.defensivesHideFromViewers == true

    local changed = false

    if not shouldHide then
        if next(defensivesHiddenSet) then
            table.wipe(defensivesHiddenSet)
            changed = true
        end
        return changed
    end

    local specID = GetCurrentSpecID()
    local specDisabled = specID and db.defensivesDisabledSpells and db.defensivesDisabledSpells[specID] or {}
    table.wipe(hiddenSetScratch)
    for _, spellID in ipairs(CDM.GetBuiltinDefensiveSpells(specID)) do
        if not specDisabled[spellID] then
            hiddenSetScratch[spellID] = true
        end
    end
    for _, spellID in ipairs(CDM.GetCustomDefensiveSpells(specID)) do
        if not specDisabled[spellID] then
            hiddenSetScratch[spellID] = true
        end
    end

    for id in pairs(hiddenSetScratch) do
        if not defensivesHiddenSet[id] then
            changed = true
            break
        end
    end
    if not changed then
        for id in pairs(defensivesHiddenSet) do
            if not hiddenSetScratch[id] then
                changed = true
                break
            end
        end
    end

    if changed then
        table.wipe(defensivesHiddenSet)
        for id in pairs(hiddenSetScratch) do
            defensivesHiddenSet[id] = true
        end
    end

    return changed
end

local function ReshowViewerFrames()
    for _, viewerName in ipairs(RESHOW_VIEWERS) do
        local viewer = _G[viewerName]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                local fd = CDM.GetFrameData and CDM.GetFrameData(frame)
                if fd and fd.cdmHiddenByDefensives then
                    fd.cdmHiddenByDefensives = false
                    if frame.Cooldown and frame.Cooldown.SetDrawSwipe then
                        frame.Cooldown:SetDrawSwipe(true)
                    end
                end
            end
        end
    end
end

local function InvalidateViewers()
    if CDM.InvalidateUtilityVisibleCountCache then
        CDM:InvalidateUtilityVisibleCountCache()
    end
    if CDM.InvalidateEssentialRow1WidthCache then
        CDM:InvalidateEssentialRow1WidthCache()
    end
    ReshowViewerFrames()
    CDM:QueueViewer(VIEWERS.ESSENTIAL)
    CDM:QueueViewer(VIEWERS.UTILITY)
end

local UpdateDefensivesCooldownsOnly
local defensivesUpdatePending = false
local defensivesDispatchFrame = CreateFrame("Frame")
defensivesDispatchFrame:Hide()
local defensivesQueuedFullUpdate = false
local defensivesQueuedCooldownUpdate = false
local defensivesStartupCooldownGate = CDM.CreateStartupSettleGate(function()
    if isEnabled then
        UpdateDefensivesCooldownsOnly()
    end
end)

local function DoDefensivesUpdate()
    defensivesUpdatePending = false
    if not isEnabled then
        return
    end
    local doFull = defensivesQueuedFullUpdate
    local doCooldowns = defensivesQueuedCooldownUpdate
    defensivesQueuedFullUpdate = false
    defensivesQueuedCooldownUpdate = false

    if doFull then
        CDM:UpdateDefensives()
    elseif doCooldowns then
        UpdateDefensivesCooldownsOnly()
    end
end

defensivesDispatchFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    DoDefensivesUpdate()
end)

local function QueueDefensivesUpdate(fullUpdate)
    if not fullUpdate and not defensivesStartupCooldownGate:IsSettled() then
        return
    end
    if fullUpdate then
        defensivesQueuedFullUpdate = true
    else
        defensivesQueuedCooldownUpdate = true
    end
    if defensivesUpdatePending then return end
    defensivesUpdatePending = true
    defensivesDispatchFrame:Show()
end

local function OnDefensivesSpellWatchChanged(cooldownsChanged, chargesChanged)
    if not isEnabled then return end
    if not (cooldownsChanged or chargesChanged) then return end
    QueueDefensivesUpdate(false)
end

local function RegisterDefensiveSpellWatches()
    if not (CDM.WatchSpellState and CDM.UnwatchAllSpellStates) then
        return
    end

    CDM.UnwatchAllSpellStates(DEFENSIVES_SPELL_WATCH_OWNER)
    for _, entry in ipairs(iconEntries) do
        if entry and entry.spellID then
            CDM.WatchSpellState(DEFENSIVES_SPELL_WATCH_OWNER, entry.spellID, OnDefensivesSpellWatchChanged)
        end
    end
end

local function UnregisterDefensiveSpellWatches()
    if CDM.UnwatchAllSpellStates then
        CDM.UnwatchAllSpellStates(DEFENSIVES_SPELL_WATCH_OWNER)
    end
end

function CDM:InitializeDefensives()
    if isInitialized then return end

    RefreshCachedDefensivesStyles()

    defensivesContainer = CDM.CreateTrackerContainer("CDM_DefensivesContainer")

    UpdateContainerPosition()

    lastDefensivesSpecID = GetCurrentSpecID()
    RebuildCustomSpellSet(lastDefensivesSpecID)
    local ordered = CDM.GetOrderedDefensiveSpells(lastDefensivesSpecID)
    for _, spellID in ipairs(ordered) do
        iconEntries[#iconEntries + 1] = AcquireDefensiveIconEntry(spellID)
    end

    defensivesStartupCooldownGate:Begin()
    self:UpdateDefensives()

    CDM.RegisterTrackerPositionCallback("CDM_Defensives", UpdateContainerPosition)
    isInitialized = true
    isEnabled = true
    RegisterDefensiveSpellWatches()
    defensivesStartupCooldownGate:ScheduleSettle()

    RebuildHiddenSet()
end

local function EnableDefensives()
    if not isInitialized or isEnabled then return end
    defensivesStartupCooldownGate:Begin()
    CDM.RegisterTrackerPositionCallback("CDM_Defensives", UpdateContainerPosition)
    if defensivesContainer then
        defensivesContainer:Show()
    end
    needsStyleUpdate = true
    isEnabled = true
    for _, entry in ipairs(iconEntries) do
        entry._spellbookCached = nil
        if entry.frame then
            entry.frame._spellbookCached = nil
        end
    end
    RebuildCustomSpellSet(GetCurrentSpecID())
    CDM:UpdateDefensives()
    RegisterDefensiveSpellWatches()
    defensivesStartupCooldownGate:ScheduleSettle()
end

local function DisableDefensives()
    if not isEnabled then return end
    defensivesStartupCooldownGate:Cancel()
    defensivesUpdatePending = false
    defensivesQueuedFullUpdate = false
    defensivesQueuedCooldownUpdate = false
    UnregisterDefensiveSpellWatches()
    CDM.UnregisterTrackerPositionCallback("CDM_Defensives")
    if defensivesContainer then
        defensivesContainer:Hide()
    end
    ReleaseDefensiveFramesForLowMemory()
    isEnabled = false
end

UpdateDefensivesCooldownsOnly = function()
    if not defensivesContainer or not isEnabled then return end

    if needsStyleUpdate then
        CDM:UpdateDefensives()
        return
    end

    local currentSpec = GetCurrentSpecID()
    if currentSpec and currentSpec ~= lastDefensivesSpecID then
        lastDefensivesSpecID = currentSpec
        CDM:ReinitDefensiveIcons()
        return
    end

    gcdActive = C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID) ~= nil
    for _, frame in ipairs(iconFrames) do
        if frame:IsShown() then
            UpdateIcon(frame)
        end
    end
end

function CDM:UpdateDefensives()
    if not defensivesContainer then return end

    local currentSpec = GetCurrentSpecID()
    if currentSpec and currentSpec ~= lastDefensivesSpecID then
        lastDefensivesSpecID = currentSpec
        self:ReinitDefensiveIcons()
        return
    end

    InvalidateSpellbookCache()
    CDM.WipeEffectiveIDCache()

    local size = CDM.GetTrackerIconSize("defensivesIconWidth", "defensivesIconHeight")
    local spacing = GetSpacing()

    local sizeChanged = (lastDefensivesWidth ~= size.w or lastDefensivesHeight ~= size.h)
    if sizeChanged then
        lastDefensivesWidth = size.w
        lastDefensivesHeight = size.h
    end

    local spacingChanged = (lastDefensivesSpacing ~= spacing)
    if spacingChanged then
        lastDefensivesSpacing = spacing
    end

    local applyStyle = needsStyleUpdate or sizeChanged

    gcdActive = C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID) ~= nil

    local visibilityHash = 0
    local bit = 1
    local visibleCount = 0
    for _, entry in ipairs(iconEntries) do
        if PlayerHasAbility(entry, currentSpec) then
            visibilityHash = visibilityHash + bit

            local frame, boundNow = BindEntryFrame(entry)

            if not boundNow and frame.Icon then
                local texture = C_Spell.GetSpellTexture(GetEffectiveSpellID(entry.spellID))
                if texture then
                    frame.Icon:SetTexture(texture)
                end
            end

            CDM.CacheMultipleCharges(entry, entry.spellID)

            if sizeChanged then
                frame:SetSize(size.w, size.h)

                if frame.Icon then
                    frame.Icon:SetAllPoints(frame)
                end
                if frame.Cooldown then
                    frame.Cooldown:SetAllPoints(frame)
                end
                if frame.cdmBorderFrame then
                    frame.cdmBorderFrame:SetAllPoints(frame)
                end
                if frame.ChargeCount then
                    frame.ChargeCount:SetAllPoints(frame)
                end
            end

            frame:Show()
            if (applyStyle or boundNow) and CDM.ApplyTrackerStyle then
                CDM:ApplyTrackerStyle(frame, "CDM_Defensives", boundNow)
            end
            UpdateIcon(frame)

            visibleCount = visibleCount + 1
            iconFrames[visibleCount] = frame
        else
            ReleaseEntryFrame(entry)
        end
        bit = bit + bit
    end
    for i = visibleCount + 1, #iconFrames do
        iconFrames[i] = nil
    end

    needsStyleUpdate = false

    if visibilityHash ~= lastDefensivesVisibilityHash or sizeChanged or spacingChanged then
        lastDefensivesVisibilityHash = visibilityHash
        PositionIcons()
    end
end

function CDM:ReinitDefensiveIcons()
    if not isInitialized then return end
    InvalidateTalentTreeCache()
    InvalidateOrderedSpellsCache()
    CDM.WipeEffectiveIDCache()
    for _, entry in ipairs(iconEntries) do
        ReleaseEntryFrame(entry)
        ReleaseDefensiveIconEntry(entry)
    end
    table.wipe(iconEntries)
    table.wipe(iconFrames)
    lastDefensivesVisibilityHash = -1

    local specID = GetCurrentSpecID()
    RebuildCustomSpellSet(specID)
    local ordered = CDM.GetOrderedDefensiveSpells(specID)
    for _, spellID in ipairs(ordered) do
        iconEntries[#iconEntries + 1] = AcquireDefensiveIconEntry(spellID)
    end
    needsStyleUpdate = true
    if isEnabled then
        RegisterDefensiveSpellWatches()
    end
    self:UpdateDefensives()
    CDM.TrimTrackerPool(iconFramePool, #iconEntries)
end

function CDM:AddDefensiveSpell(spellID, targetSpecID)
    local specID = targetSpecID or GetCurrentSpecID()
    if not specID then return false end

    spellID = CDM.NormalizeToBase(spellID) or spellID

    if not CDM.db.defensivesCustomSpells then
        CDM.db.defensivesCustomSpells = {}
    end
    if not CDM.db.defensivesCustomSpells[specID] then
        CDM.db.defensivesCustomSpells[specID] = {}
    end

    for _, id in ipairs(CDM.db.defensivesCustomSpells[specID]) do
        if id == spellID then return false end
    end
    if DEFENSIVES_SET[spellID] then return false end

    table.insert(CDM.db.defensivesCustomSpells[specID], spellID)

    if CDM.db.defensivesOrder and CDM.db.defensivesOrder[specID] then
        table.insert(CDM.db.defensivesOrder[specID], spellID)
    end

    if specID == GetCurrentSpecID() then
        self:ReinitDefensiveIcons()
        CDM:RefreshConfig()
    end
    return true
end

function CDM:RemoveDefensiveSpell(spellID, targetSpecID)
    spellID = CDM.NormalizeToBase(spellID) or spellID
    local specID = targetSpecID or GetCurrentSpecID()
    if not specID then return end

    local list = CDM.db.defensivesCustomSpells and CDM.db.defensivesCustomSpells[specID]
    if not list then return end

    for i = #list, 1, -1 do
        if list[i] == spellID then
            table.remove(list, i)
            break
        end
    end

    if CDM.db.defensivesOrder and CDM.db.defensivesOrder[specID] then
        local order = CDM.db.defensivesOrder[specID]
        for i = #order, 1, -1 do
            if order[i] == spellID then
                table.remove(order, i)
                break
            end
        end
    end

    if specID == GetCurrentSpecID() then
        self:ReinitDefensiveIcons()
        CDM:RefreshConfig()
    end
end

local function OnDefensivesProfileApplied()
    needsStyleUpdate = true
    lastDefensivesSpecID = nil
    lastDefensivesVisibilityHash = -1
    lastDefensivesWidth = nil
    lastDefensivesHeight = nil
    lastDefensivesSpacing = nil
    InvalidateSpellbookCache()
    InvalidateTalentTreeCache()
    InvalidateOrderedSpellsCache()
    if RebuildHiddenSet() then
        InvalidateViewers()
    end
end

local function RefreshDefensivesLifecycle()
    if not isEnabled then return end

    local currentSpec = GetCurrentSpecID()
    if currentSpec and currentSpec ~= lastDefensivesSpecID then
        lastDefensivesSpecID = currentSpec
        CDM:ReinitDefensiveIcons()
    end

    if RebuildHiddenSet() then
        InvalidateViewers()
    end

    RebuildCustomSpellSet(GetCurrentSpecID())
    UpdateContainerPosition()
    CDM:UpdateDefensives()
end

if CDM.ModuleManager and CDM.ModuleManager.RegisterModule then
    CDM.ModuleManager:RegisterModule({
        id = "defensives",
        Initialize = function()
            CDM:InitializeDefensives()
            if RebuildHiddenSet() then
                InvalidateViewers()
            end
        end,
        Enable = function()
            EnableDefensives()
            if RebuildHiddenSet() then
                InvalidateViewers()
            end
        end,
        Disable = function()
            DisableDefensives()
            if next(defensivesHiddenSet) then
                table.wipe(defensivesHiddenSet)
                InvalidateViewers()
            end
        end,
        Refresh = RefreshDefensivesLifecycle,
        OnProfileApplied = OnDefensivesProfileApplied,
        ShouldBeEnabled = function(db)
            return db and db.defensivesEnabled ~= false
        end,
    })
end

CDM:RegisterRefreshCallback("defensivesStyles", function()
    RefreshCachedDefensivesStyles()
    needsStyleUpdate = true
end, 16, { "text_visuals", "trackers_layout", "viewers" })

CDM:RegisterRefreshCallback("defensives", function()
    local moduleManager = CDM.ModuleManager
    if moduleManager and moduleManager.ReconcileModule then
        moduleManager:ReconcileModule("defensives")
    end
end, 38, { "trackers_layout", "viewers" })
