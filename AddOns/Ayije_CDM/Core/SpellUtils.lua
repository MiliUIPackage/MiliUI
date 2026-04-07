local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local GetFrameData = CDM.GetFrameData

local COLOR_REGISTRY = {}

local lastRefreshSpecID = nil

local IsSafeNumber = CDM.IsSafeNumber

local function IsUsableID(id)
    return IsSafeNumber(id) and id > 0
end

local function AddCandidate(list, seen, id)
    if not IsUsableID(id) then return end
    if not seen[id] then
        list[#list + 1] = id
        seen[id] = true
    end
end

local function CallFrameMethod(frame, methodName)
    local method = frame and frame[methodName]
    if type(method) == "function" then
        return method(frame)
    end
end

local function GetFrameCooldownInfo(frame)
    if not frame then return nil end
    return frame.GetCooldownInfo and frame:GetCooldownInfo() or frame.cooldownInfo
end

local spellCandidateList = {}
local spellCandidateSeen = {}

function CDM:GetSpellIDCandidates(frame)
    table.wipe(spellCandidateList)
    table.wipe(spellCandidateSeen)
    if not frame then return spellCandidateList end

    AddCandidate(spellCandidateList, spellCandidateSeen, CallFrameMethod(frame, "GetSpellID"))

    local info = GetFrameCooldownInfo(frame)
    if info then
        AddCandidate(spellCandidateList, spellCandidateSeen, info.overrideSpellID)
        AddCandidate(spellCandidateList, spellCandidateSeen, info.spellID)
        if info.linkedSpellIDs then
            for _, linkedID in ipairs(info.linkedSpellIDs) do
                AddCandidate(spellCandidateList, spellCandidateSeen, linkedID)
            end
        end
    end

    if frame.isCustomBuff and IsSafeNumber(frame.spellID) then
        AddCandidate(spellCandidateList, spellCandidateSeen, frame.spellID)
    end

    return spellCandidateList
end

local buffGlowCandidateList = {}
local buffGlowCandidateSeen = {}

local function AddBuffGlowCandidate(id)
    if not IsUsableID(id) then return end
    if buffGlowCandidateSeen[id] then return end
    buffGlowCandidateSeen[id] = true
    buffGlowCandidateList[#buffGlowCandidateList + 1] = id
end

function CDM:ResolveBuffGlowState(frame, specID, preferCategory)
    if not frame or not specID then
        return false, nil, nil
    end
    if not self.GetSpellGlowEnabled or not self.GetSpellGlowColor then
        return false, nil, nil
    end

    local frameData = GetFrameData(frame)

    table.wipe(buffGlowCandidateList)
    table.wipe(buffGlowCandidateSeen)

    local groupedID = frameData.buffCategorySpellID
    if preferCategory then
        AddBuffGlowCandidate(groupedID)
    end

    AddBuffGlowCandidate(CallFrameMethod(frame, "GetSpellID"))
    local info = GetFrameCooldownInfo(frame)
    if info then
        AddBuffGlowCandidate(info.spellID)
        AddBuffGlowCandidate(info.overrideSpellID)
    end

    if not preferCategory then
        AddBuffGlowCandidate(groupedID)
    end

    for _, id in ipairs(buffGlowCandidateList) do
        if self:GetSpellGlowEnabled(specID, id) then
            local glowColor = self:GetSpellGlowColor(specID, id)
            frameData.cdmBuffGlowSourceID = id
            return true, glowColor, id
        end
    end

    frameData.cdmBuffGlowSourceID = nil
    return false, nil, nil
end

CDM.SpellSets = {
    colors = COLOR_REGISTRY,
    hasBuffGlows = false,
}

local overrideCache = {}

local function GetOverrideIfDifferent(spellID)
    if not IsUsableID(spellID) or not C_Spell.GetOverrideSpell then return nil end
    local cached = overrideCache[spellID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end
    local id = C_Spell.GetOverrideSpell(spellID)
    if IsUsableID(id) and id ~= spellID then
        overrideCache[spellID] = id
        return id
    end
    overrideCache[spellID] = false
    return nil
end

local function ClearOverrideCache()
    table.wipe(overrideCache)
end

local function GetEffectiveSpellID(spellID)
    if not spellID then return spellID end
    return GetOverrideIfDifferent(spellID) or spellID
end

CDM.GetOverrideIfDifferent = GetOverrideIfDifferent
CDM.GetEffectiveSpellID = GetEffectiveSpellID
CDM.WipeEffectiveIDCache = ClearOverrideCache

local normalizeBaseCache = {}
local normalizeBaseCacheSize = 0
local MAX_NORMALIZE_CACHE_ENTRIES = 4096

local function CacheNormalizedBase(id, resolved)
    if normalizeBaseCache[id] == nil then
        normalizeBaseCacheSize = normalizeBaseCacheSize + 1
        if normalizeBaseCacheSize > MAX_NORMALIZE_CACHE_ENTRIES then
            table.wipe(normalizeBaseCache)
            normalizeBaseCacheSize = 1
        end
    end
    normalizeBaseCache[id] = resolved
end

function CDM:ClearNormalizationCache()
    table.wipe(normalizeBaseCache)
    normalizeBaseCacheSize = 0
    ClearOverrideCache()
    self.spellCacheGeneration = (self.spellCacheGeneration or 0) + 1
end

local function NormalizeToBase(id)
    if not IsUsableID(id) then return nil end

    if normalizeBaseCache[id] ~= nil then
        return normalizeBaseCache[id]
    end

    local baseID = C_Spell.GetBaseSpell(id)
    if IsUsableID(baseID) and baseID ~= id then
        CacheNormalizedBase(id, baseID)
        return baseID
    end

    CacheNormalizedBase(id, id)
    return id
end

CDM.NormalizeToBase = NormalizeToBase

local function GetBaseSpellIfDifferent(spellID)
    if not IsUsableID(spellID) then return nil end
    local base = NormalizeToBase(spellID)
    return (base and base ~= spellID) and base or nil
end

local scratchMatchCandidates = {}
local scratchMatchSeen = {}
local scratchMatchCandidatesAlt = {}
local scratchMatchSeenAlt = {}
local scratchMatchShared = {}

local function BuildBuffGroupMatchCandidatesInto(spellID, out, outSeen)
    table.wipe(out)
    table.wipe(outSeen)
    if not IsUsableID(spellID) then return out end

    AddCandidate(out, outSeen, spellID)

    local baseID = GetBaseSpellIfDifferent(spellID)
    if baseID then
        AddCandidate(out, outSeen, baseID)
    end

    local overrideID = GetOverrideIfDifferent(spellID)
    if overrideID then
        AddCandidate(out, outSeen, overrideID)
        AddCandidate(out, outSeen, GetBaseSpellIfDifferent(overrideID))
    end

    if baseID then
        AddCandidate(out, outSeen, GetOverrideIfDifferent(baseID))
    end

    return out
end


function CDM:GetPreferredBuffGroupSpellID(frame)
    if not frame then return nil end
    local candidates = self:GetSpellIDCandidates(frame)
    return candidates and candidates[1] or nil
end

function CDM:GetBuffOverrideStorageKey(spellID)
    if not IsUsableID(spellID) then
        return nil
    end
    return NormalizeToBase(spellID)
end

local function CopyOverrideEntry(entry)
    if type(entry) ~= "table" then return entry end

    local copy = {}
    for key, value in pairs(entry) do
        if type(value) == "table" then
            local subCopy = {}
            for subKey, subValue in pairs(value) do
                subCopy[subKey] = subValue
            end
            copy[key] = subCopy
        else
            copy[key] = value
        end
    end

    return copy
end

function CDM:CopyBuffOverrideEntry(entry)
    return CopyOverrideEntry(entry)
end

local function MergeMissingOverrideFields(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then return end

    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = CopyOverrideEntry(value)
        end
    end
end

function CDM:MergeMissingBuffOverrideFields(target, source)
    MergeMissingOverrideFields(target, source)
end

local function CollectMergedBuffOverrideEntry(overrideMap, spellID, removeEntries)
    if type(overrideMap) ~= "table" or not IsUsableID(spellID) then
        return nil, {}
    end

    local keys = BuildBuffGroupMatchCandidatesInto(spellID, scratchMatchCandidates, scratchMatchSeen)
    local merged
    for _, key in ipairs(keys) do
        local entry = overrideMap[key]
        if type(entry) == "table" then
            if not merged then
                merged = CopyOverrideEntry(entry)
            else
                MergeMissingOverrideFields(merged, entry)
            end
            if removeEntries then
                overrideMap[key] = nil
            end
        end
    end

    return merged, keys
end

function CDM:ResolveBuffOverrideEntry(overrideMap, spellID)
    if type(overrideMap) ~= "table" or not IsUsableID(spellID) then
        return nil
    end

    for _, key in ipairs(BuildBuffGroupMatchCandidatesInto(spellID, scratchMatchCandidates, scratchMatchSeen)) do
        local entry = overrideMap[key]
        if type(entry) == "table" then
            return entry
        end
    end

    return nil
end

function CDM:GetMergedBuffOverrideEntry(overrideMap, spellID)
    return (CollectMergedBuffOverrideEntry(overrideMap, spellID, false))
end

function CDM:EnsureBuffOverrideEntry(overrideMap, spellID)
    if type(overrideMap) ~= "table" or not IsUsableID(spellID) then
        return nil
    end

    local target, keys = CollectMergedBuffOverrideEntry(overrideMap, spellID, false)
    local storageKey = self:GetBuffOverrideStorageKey(spellID)
    if not IsUsableID(storageKey) then
        return nil
    end

    if not target then
        target = {}
    end

    overrideMap[storageKey] = target
    for _, key in ipairs(keys) do
        if key ~= storageKey then
            overrideMap[key] = nil
        end
    end

    return target
end

function CDM:ExtractMergedBuffOverrideEntry(overrideMap, spellID)
    return (CollectMergedBuffOverrideEntry(overrideMap, spellID, true))
end

function CDM:StoreMergedBuffOverrideEntry(overrideMap, spellID, incoming)
    if type(overrideMap) ~= "table" or type(incoming) ~= "table" or not IsUsableID(spellID) then
        return
    end

    local storageKey = self:GetBuffOverrideStorageKey(spellID)
    if not IsUsableID(storageKey) then
        return
    end

    for _, key in ipairs(BuildBuffGroupMatchCandidatesInto(spellID, scratchMatchCandidates, scratchMatchSeen)) do
        if key ~= storageKey then
            overrideMap[key] = nil
        end
    end

    overrideMap[storageKey] = CopyOverrideEntry(incoming)
end

local EMPTY_SET = {}

local function CheckIDAgainstGroupSet(id, groupSet)
    if not IsUsableID(id) then return nil, nil end
    if groupSet[id] then return id, groupSet[id] end
    return nil, nil
end

local function CheckIDAgainstRegistry(id)
    local sets = CDM.BuffGroupSets
    local groupSet = sets and sets.grouped or EMPTY_SET
    local matchID, groupIdx = CheckIDAgainstGroupSet(id, groupSet)
    if matchID then return "buffgroup", matchID, groupIdx end
    return nil, nil
end

CDM.CheckIDAgainstRegistry = CheckIDAgainstRegistry

local function GetColorForSpellID(id)
    if not IsUsableID(id) then return nil end
    if COLOR_REGISTRY[id] then return COLOR_REGISTRY[id] end
    local base = NormalizeToBase(id)
    if base and base ~= id and COLOR_REGISTRY[base] then return COLOR_REGISTRY[base] end
    local stable = CDM.ResolveStableBase and CDM:ResolveStableBase(id)
    if stable and stable ~= id and stable ~= base and COLOR_REGISTRY[stable] then return COLOR_REGISTRY[stable] end
    return nil
end

CDM.GetColorForSpellID = GetColorForSpellID

local function GetBaseSpellID(frame)
    if not frame then return nil end

    local info = GetFrameCooldownInfo(frame)
    if info and IsUsableID(info.spellID) then
        return info.spellID
    end

    local id = CallFrameMethod(frame, "GetSpellID")
    if IsUsableID(id) then
        return NormalizeToBase(id)
    end

    return nil
end

CDM.GetBaseSpellID = GetBaseSpellID

function CDM:ResetFrameSpellCache(frame)
    if not frame then return end
    local frameData = GetFrameData(frame)
    frameData.buffCategorySpellID = nil
    frameData.cdGroupSpellID = nil
    frameData.cdmReadyGlowActive = nil
    frameData.cdmResolvedBorderColor = nil
    if frameData.borderFrame then
        GetFrameData(frameData.borderFrame).cdmResolvedBorderColor = nil
    end
    frameData.cdmLastBorderStyleVersion = nil
    frameData.cdmBuffGlowSourceID = nil
end


local frameCategoryCacheGeneration = 0

function CDM:InvalidateFrameCategoryCache()
    frameCategoryCacheGeneration = frameCategoryCacheGeneration + 1
end

local function CheckCooldownGroupMatch(frame, cdidGroupSet, spellGroupSet, cacheKey)
    if not frame then return nil, nil end

    local frameData = GetFrameData(frame)

    local gen = frameData.cdmCategoryCacheGen
    if gen ~= frameCategoryCacheGeneration then
        frameData.buffCategorySpellID = nil
        frameData.cdGroupSpellID = nil
        frameData.cdmCategoryCacheGen = frameCategoryCacheGeneration
        frameData.cdmResolvedBorderColor = nil
        if frameData.borderFrame then
            GetFrameData(frameData.borderFrame).cdmResolvedBorderColor = nil
        end
    end

    local cached = frameData[cacheKey]
    if cached and spellGroupSet[cached] then
        return cached, spellGroupSet[cached]
    end

    local cooldownID = frame.cooldownID
    if cooldownID then
        local entry = cdidGroupSet[cooldownID]
        if entry then
            frameData[cacheKey] = entry.storedID
            return entry.storedID, entry.groupIdx
        end
    end

    frameData[cacheKey] = nil
    return nil, nil
end

function CDM.CheckCdGroupMatch(frame)
    local sets = CDM.CooldownGroupSets
    local cdidSet = sets and sets.cooldownIDGrouped or EMPTY_SET
    local spellSet = sets and sets.grouped or EMPTY_SET
    local _, groupIdx = CheckCooldownGroupMatch(frame, cdidSet, spellSet, "cdGroupSpellID")
    return groupIdx
end

local function CheckBuffRegistryMatch(frame)
    local sets = CDM.BuffGroupSets
    local cdidSet = sets and sets.cooldownIDGrouped or EMPTY_SET
    local spellSet = sets and sets.grouped or EMPTY_SET
    local matchID, groupIdx = CheckCooldownGroupMatch(frame, cdidSet, spellSet, "buffCategorySpellID")
    if matchID then return "buffgroup", matchID, groupIdx end
    return nil, nil
end

CDM.CheckBuffRegistryMatch = CheckBuffRegistryMatch

function CDM:GetBuffRegistryMatch(frame)
    return CheckBuffRegistryMatch(frame)
end

function CDM:MarkSpecDataDirty()
    lastRefreshSpecID = nil
end

function CDM:RefreshSpecData()
    local specIndex = GetSpecialization()
    if not specIndex then
        self.SpellSets.hasBuffGlows = false
        return
    end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then
        self.SpellSets.hasBuffGlows = false
        return
    end

    if specID == lastRefreshSpecID then return end

    table.wipe(COLOR_REGISTRY)
    self.SpellSets.hasBuffGlows = false

    self:ClearNormalizationCache()
    if self.ClearStableBaseCache then self:ClearStableBaseCache() end
    self:InvalidateFrameCategoryCache()

    local rawColors = self.db and self.db.spellRegistry
        and self.db.spellRegistry[specID]
        and self.db.spellRegistry[specID].colors
    if rawColors then
        for id, color in pairs(rawColors) do
            COLOR_REGISTRY[id] = color
        end
    end

    local rawSpellRegistry = self.db and self.db.spellRegistry
    local rawSpecRegistry = rawSpellRegistry and rawSpellRegistry[specID]
    self.SpellSets.hasBuffGlows = type(rawSpecRegistry and rawSpecRegistry.glowEnabled) == "table"
        and next(rawSpecRegistry.glowEnabled) ~= nil or false

    if self.RefreshBuffGroupData then
        self:RefreshBuffGroupData()
    end
    if self.InvalidateStaticGroupsCache then
        self:InvalidateStaticGroupsCache()
    end

    if self.RefreshCooldownGroupData then
        self:RefreshCooldownGroupData()
    end

    lastRefreshSpecID = specID
end
