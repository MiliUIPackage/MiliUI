local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local GetFrameData = CDM.GetFrameData

local COLOR_REGISTRY = {}

local lastRefreshSpecID = nil
local specDataDirty = true

local IsSafeNumber = CDM.IsSafeNumber

local function IsUsableID(id)
    if not IsSafeNumber(id) then
        return false
    end
    return id > 0 and id == math.floor(id)
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

function CDM:GetSpellIDCandidates(frame, includeBase, skipAura)
    if not frame then return {} end

    local frameData = GetFrameData(frame)
    local out = frameData.cdmSpellCandidates
    if not out then
        out = {}
        frameData.cdmSpellCandidates = out
    else
        table.wipe(out)
    end

    local seen = frameData.cdmSpellCandidatesSeen
    if not seen then
        seen = {}
        frameData.cdmSpellCandidatesSeen = seen
    else
        table.wipe(seen)
    end

    if not skipAura and frame.GetAuraSpellID then
        AddCandidate(out, seen, frame:GetAuraSpellID())
    end

    AddCandidate(out, seen, CallFrameMethod(frame, "GetSpellID"))

    local info = GetFrameCooldownInfo(frame)
    if info then
        AddCandidate(out, seen, info.linkedSpellID)
        AddCandidate(out, seen, info.overrideTooltipSpellID)
        AddCandidate(out, seen, info.overrideSpellID)
        AddCandidate(out, seen, info.spellID)
        if info.linkedSpellIDs then
            for _, linkedID in ipairs(info.linkedSpellIDs) do
                AddCandidate(out, seen, linkedID)
            end
        end
    end

    if includeBase then
        AddCandidate(out, seen, CDM.GetBaseSpellID(frame))
    end

    return out
end

local buffGlowCandidateList = {}
local buffGlowCandidateSeen = {}

local function AddBuffGlowCandidate(id)
    if not IsUsableID(id) then return end
    if buffGlowCandidateSeen[id] then return end
    buffGlowCandidateSeen[id] = true
    buffGlowCandidateList[#buffGlowCandidateList + 1] = id
end

local function AddBuffGlowCandidateWithBase(id)
    if not IsUsableID(id) then return end
    AddBuffGlowCandidate(id)
    local baseID = CDM.NormalizeToBase and CDM.NormalizeToBase(id) or nil
    if baseID and baseID ~= id then
        AddBuffGlowCandidate(baseID)
    end
end

local function MoveBuffGlowCandidateToFront(id)
    if not IsUsableID(id) then return end
    if not buffGlowCandidateSeen[id] then return end
    if buffGlowCandidateList[1] == id then return end
    for i = 2, #buffGlowCandidateList do
        if buffGlowCandidateList[i] == id then
            table.remove(buffGlowCandidateList, i)
            table.insert(buffGlowCandidateList, 1, id)
            return
        end
    end
end

function CDM:ResolveBuffGlowState(frame, specID, preferCategory)
    if not frame or not specID then
        return false, nil, nil
    end
    if not self.GetSpellGlowEnabled or not self.GetSpellGlowColor then
        return false, nil, nil
    end

    local frameData = GetFrameData(frame)
    local cachedID = frameData.cdmBuffGlowSourceID

    table.wipe(buffGlowCandidateList)
    table.wipe(buffGlowCandidateSeen)

    local groupedID = frameData.buffCategorySpellID
    if preferCategory then
        AddBuffGlowCandidateWithBase(groupedID)
    end

    local candidates = self.GetSpellIDCandidates and self:GetSpellIDCandidates(frame, true) or nil
    if candidates then
        for _, id in ipairs(candidates) do
            AddBuffGlowCandidateWithBase(id)
        end
    end

    if not preferCategory then
        AddBuffGlowCandidateWithBase(groupedID)
    end

    -- Keep animation stable when the previous source is still among active candidates.
    if cachedID then
        MoveBuffGlowCandidateToFront(cachedID)
        local cachedBase = CDM.NormalizeToBase and CDM.NormalizeToBase(cachedID) or nil
        if cachedBase and cachedBase ~= cachedID then
            MoveBuffGlowCandidateToFront(cachedBase)
        end
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
}

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
    self.spellCacheGeneration = (self.spellCacheGeneration or 0) + 1
end

local normalizeSeen = {}

local function NormalizeToBase(id)
    if not IsUsableID(id) then return nil end

    if normalizeBaseCache[id] ~= nil then
        return normalizeBaseCache[id]
    end

    local cursor = id
    local resolved = id
    local hops = 0
    table.wipe(normalizeSeen)
    normalizeSeen[id] = true
    local terminatedOnSelf = false

    while hops < 20 do
        hops = hops + 1
        local baseID = C_Spell.GetBaseSpell(cursor)
        if baseID == cursor then
            terminatedOnSelf = true
            break
        end
        if not IsUsableID(baseID) then
            break
        end
        if normalizeSeen[baseID] then
            break
        end
        normalizeSeen[baseID] = true
        resolved = baseID
        cursor = baseID
    end

    if resolved ~= id then
        CacheNormalizedBase(id, resolved)
        return resolved
    end

    if terminatedOnSelf then
        CacheNormalizedBase(id, id)
    end

    return id
end

CDM.NormalizeToBase = NormalizeToBase

local BUFF_GROUP_SET = {}

local function CheckIDAgainstRegistry(id)
    if not IsUsableID(id) then return nil, nil end
    if BUFF_GROUP_SET[id] then return "buffgroup", id, BUFF_GROUP_SET[id] end
    local normalized = NormalizeToBase(id)
    if normalized and normalized ~= id then
        if BUFF_GROUP_SET[normalized] then return "buffgroup", normalized, BUFF_GROUP_SET[normalized] end
    end
    return nil, nil
end

CDM.CheckIDAgainstRegistry = CheckIDAgainstRegistry

local function GetBaseSpellIfDifferent(spellID)
    if not spellID then return nil end
    local base = NormalizeToBase(spellID)
    return (base and base ~= spellID) and base or nil
end

local function GetOverrideSpellIfDifferent(spellID)
    if not spellID or not C_Spell.GetOverrideSpell then return end
    local overrideID = C_Spell.GetOverrideSpell(spellID)
    if IsUsableID(overrideID) and overrideID ~= spellID then
        return overrideID
    end
end

local function StoreWithVariants(targetSet, id, value)
    if not IsUsableID(id) then return end
    targetSet[id] = value
    local overrideID = GetOverrideSpellIfDifferent(id)
    if overrideID then targetSet[overrideID] = value end
    local baseID = GetBaseSpellIfDifferent(id)
    if baseID then
        targetSet[baseID] = value
        local baseOverride = GetOverrideSpellIfDifferent(baseID)
        if baseOverride then targetSet[baseOverride] = value end
    end
end

local function GetColorForSpellID(id)
    if not IsUsableID(id) then return nil end
    if COLOR_REGISTRY[id] then return COLOR_REGISTRY[id] end
    local normalizedID = NormalizeToBase(id)
    if normalizedID and normalizedID ~= id and COLOR_REGISTRY[normalizedID] then
        return COLOR_REGISTRY[normalizedID]
    end
    return nil
end

CDM.GetColorForSpellID = GetColorForSpellID

local function GetBaseSpellID(frame)
    if not frame then return nil end

    local rawSpellID
    local info = GetFrameCooldownInfo(frame)
    if info then
        rawSpellID = info.overrideSpellID or info.spellID
    end

    if not rawSpellID then
        local id = CallFrameMethod(frame, "GetSpellID")
        if IsUsableID(id) then
            rawSpellID = id
        end
    end

    if not rawSpellID then return nil end

    return NormalizeToBase(rawSpellID)
end

CDM.GetBaseSpellID = GetBaseSpellID

function CDM:ResetFrameSpellCache(frame)
    if not frame then return end
    local frameData = GetFrameData(frame)
    frameData.buffCategorySpellID = nil
    frameData.cdmProvisionalReadyUntil = nil
    frameData.cdmAuraStateDirty = nil
    frameData.cdmAuraLastSpellID = nil
    frameData.cdmLastBorderColorID = nil
    frameData.cdmLastBorderStyleVersion = nil
    frameData.cdmBuffGlowSourceID = nil
end

function CDM:GetCachedBaseSpellID(frame)
    if not frame then return nil end

    local id = GetBaseSpellID(frame)

    if not id then
        local raw = CallFrameMethod(frame, "GetBaseSpellID")
        if IsUsableID(raw) then
            id = NormalizeToBase(raw)
        end
    end

    return IsUsableID(id) and id or nil
end

function CDM:InvalidateFrameCategoryCache()
    local VIEWERS = CDM.CONST and CDM.CONST.VIEWERS
    if not VIEWERS then return end
    for _, vName in ipairs({ VIEWERS.BUFF, VIEWERS.BUFF_BAR, VIEWERS.ESSENTIAL, VIEWERS.UTILITY }) do
        local v = _G[vName]
        if v and v.itemFramePool then
            for frame in v.itemFramePool:EnumerateActive() do
                local fd = GetFrameData(frame)
                fd.buffCategorySpellID = nil
                fd.cdmLastBorderColorID = nil
                fd.cdmLastBorderStyleVersion = nil
            end
        end
    end
end

local function CheckBuffRegistryMatch(frame)
    if not frame then return nil, nil end

    local frameData = GetFrameData(frame)

    local cached = frameData.buffCategorySpellID
    if cached ~= nil then
        if cached == false then return nil, nil end
        if BUFF_GROUP_SET[cached] then return "buffgroup", cached, BUFF_GROUP_SET[cached] end
    end

    local matchType, matchID, groupIdx

    local candidates = CDM.GetSpellIDCandidates and CDM:GetSpellIDCandidates(frame, true) or {}
    for _, id in ipairs(candidates) do
        matchType, matchID, groupIdx = CheckIDAgainstRegistry(id)
        if matchType then
            frameData.buffCategorySpellID = matchID
            return matchType, matchID, groupIdx
        end
    end

    frameData.buffCategorySpellID = false
    return nil, nil
end

CDM.CheckBuffRegistryMatch = CheckBuffRegistryMatch

function CDM:GetBuffRegistryMatch(frame)
    return CheckBuffRegistryMatch(frame)
end

function CDM:MarkSpecDataDirty()
    specDataDirty = true
    lastRefreshSpecID = nil
end

function CDM:RefreshSpecData()
    local specIndex = GetSpecialization()
    if not specIndex then return end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then return end

    if specID == lastRefreshSpecID and not specDataDirty then return end

    table.wipe(COLOR_REGISTRY)
    table.wipe(BUFF_GROUP_SET)

    self:ClearNormalizationCache()
    self:InvalidateFrameCategoryCache()

    local registry = self:GetSpellRegistry(specID)
    if not registry then return end

    if registry.colors then
        for id, color in pairs(registry.colors) do
            StoreWithVariants(COLOR_REGISTRY, id, color)
        end
    end

    if self.RefreshBuffGroupData then
        self:RefreshBuffGroupData()
    end
    local groupSets = self.BuffGroupSets
    if groupSets and groupSets.grouped then
        for id, groupIdx in pairs(groupSets.grouped) do
            StoreWithVariants(BUFF_GROUP_SET, id, groupIdx)
        end
    end

    lastRefreshSpecID = specID
    specDataDirty = false
end
