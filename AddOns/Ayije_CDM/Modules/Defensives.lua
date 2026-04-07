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
local DesaturationCurve = CDM_C.DesaturationCurve
local DEFENSIVES_SPELL_WATCH_OWNER = "CDM_Defensives_Spells"

local function GetCurrentSpecID()
    return CDM:GetCurrentSpecID()
end

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

    local cSet = {}
    for _, id in ipairs(customSpells) do cSet[id] = true end

    local result = {}
    local added = {}

    if savedOrder then
        for _, id in ipairs(savedOrder) do
            if builtinSet[id] or cSet[id] then
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

local function IsCustomSpell(spellID)
    return customSpellSet[spellID] == true
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

local defensivesTracker

local function UpdateIcon(frame)
    if not frame or not frame:IsShown() then return end

    local hasCharges = false
    local desatDurationObject = nil

    local spellID = frame.spellID
    if not spellID then return end

    local effectiveID = GetEffectiveSpellID(spellID)

    local CCD = C_Spell.GetSpellChargeDuration(effectiveID)
    local SCD = C_Spell.GetSpellCooldownDuration(effectiveID)

    local chargeInfo = C_Spell.GetSpellCharges(effectiveID)
    local isChargeSpell = chargeInfo and chargeInfo.maxCharges and chargeInfo.maxCharges > 1

    if isChargeSpell and CCD then
        frame.Cooldown:SetCooldownFromDurationObject(CCD)
        frame.Cooldown:SetDrawSwipe(true)
    elseif SCD then
        frame.Cooldown:SetCooldownFromDurationObject(SCD)
        frame.Cooldown:SetDrawSwipe(true)
    else
        frame.Cooldown:Clear()
    end

    desatDurationObject = SCD

    if isChargeSpell and chargeInfo.currentCharges then
        local chargeText = CDM.EnsureTrackerChargeWidgets(frame)
        if chargeText then
            chargeText:SetText(C_StringUtil.TruncateWhenZero(chargeInfo.currentCharges))
        end
        hasCharges = true
    end

    if frame.Icon then
        local cdInfo = desatDurationObject and C_Spell.GetSpellCooldown(effectiveID)
        if desatDurationObject and cdInfo and cdInfo.isActive and desatDurationObject.EvaluateRemainingDuration then
            local gcdResult = CDM.EvaluateGCDFilteredDesaturation(desatDurationObject)
            if gcdResult then
                frame.Icon:SetDesaturation(gcdResult)
            else
                frame.Icon:SetDesaturation(desatDurationObject:EvaluateRemainingDuration(DesaturationCurve, 0) or 0)
            end
        else
            frame.Icon:SetDesaturation(0)
        end
    end

    if frame.ChargeCount and frame.ChargeCount.Current then
        local chargeText = frame.ChargeCount.Current
        local chargeStyleVersion = defensivesTracker.GetChargeStyleVersion()

        if hasCharges then
            if frame._cdmDefensivesChargeStyleVersion ~= chargeStyleVersion or not chargeText:IsShown() then
                local styles = defensivesTracker.GetCachedStyles()
                CDM.StyleChargeText(chargeText, frame, styles)
                frame._cdmDefensivesChargeStyleVersion = chargeStyleVersion
            end
        else
            chargeText:Hide()
        end
    end
end

local function ResetDefensiveTrackerFrame(f)
    f.spellID = nil
    f._spellbookCached = nil
    f._cdmDefensivesChargeStyleVersion = nil
end

local function OnDefensivesSpellWatchChanged(cooldownsChanged, chargesChanged)
    if not defensivesTracker.IsEnabled() then return end
    if not (cooldownsChanged or chargesChanged) then return end
    defensivesTracker.Queue(false)
end

defensivesTracker = CDM.CreateTracker({
    containerName       = "CDM_DefensivesContainer",
    viewerName          = "CDM_Defensives",
    positionCallbackKey = "CDM_Defensives",
    iconWidthKey        = "defensivesIconWidth",
    iconHeightKey       = "defensivesIconHeight",
    anchorPointKey      = "defensivesAnchorPoint",
    offsetXKey          = "defensivesOffsetX",
    offsetYKey          = "defensivesOffsetY",
    moduleKey           = "defensives",
    watchOwnerKey       = DEFENSIVES_SPELL_WATCH_OWNER,
    showCharges         = true,
    styleRefreshPriority = 16,
    useEntryPool        = true,
    useDispatch         = true,
    GetEntries          = function(specID)
        RebuildCustomSpellSet(specID)
        local ordered = CDM.GetOrderedDefensiveSpells(specID)
        local result = {}
        for _, spellID in ipairs(ordered) do
            result[#result + 1] = { spellID = spellID }
        end
        return result
    end,
    PlayerHasAbility    = PlayerHasAbility,
    UpdateIcon          = UpdateIcon,
    resetFrame          = ResetDefensiveTrackerFrame,
    onEntriesChanged    = function(entries)
        if not (CDM.WatchSpellState and CDM.UnwatchAllSpellStates) then return end
        CDM.UnwatchAllSpellStates(DEFENSIVES_SPELL_WATCH_OWNER)
        for _, entry in ipairs(entries) do
            if entry and entry.spellID then
                CDM.WatchSpellState(DEFENSIVES_SPELL_WATCH_OWNER, entry.spellID, OnDefensivesSpellWatchChanged)
            end
        end
    end,
    onStyleRefresh      = function()
        CDM.RefreshChargeStyleCache(defensivesTracker.GetCachedStyles(), "defensives")
    end,
})

function CDM:InitializeDefensives()
    defensivesTracker.Initialize()
end

function CDM:UpdateDefensives()
    defensivesTracker.Update()
end

function CDM:ReinitDefensiveIcons()
    if not defensivesTracker.IsInitialized() then return end
    InvalidateTalentTreeCache()
    InvalidateOrderedSpellsCache()
    CDM.WipeEffectiveIDCache()
    RebuildCustomSpellSet(GetCurrentSpecID())
    defensivesTracker.Reinit()
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
        CDM:Refresh()
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
        CDM:Refresh()
    end
end

local function OnDefensivesProfileApplied()
    defensivesTracker.OnProfileApplied()
    InvalidateTalentTreeCache()
    InvalidateOrderedSpellsCache()
end

local function ReconcileDefensives()
    defensivesTracker.Reconcile("defensivesEnabled")
    if defensivesTracker.IsEnabled() then
        RebuildCustomSpellSet(GetCurrentSpecID())
        defensivesTracker.Update()
    end
end

CDM.ReconcileDefensives = ReconcileDefensives
CDM.OnDefensivesProfileApplied = OnDefensivesProfileApplied
