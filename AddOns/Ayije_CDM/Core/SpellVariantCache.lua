local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

CDM.SpellVariant = CDM.SpellVariant or {}

local NormalizeToBase = CDM.NormalizeToBase

local spellVariantOverrideCache = {}

local function IsUsableSpellID(id)
    return type(id) == "number" and id > 0 and id == math.floor(id)
end

local function ClearSpellVariantResolutionCaches()
    table.wipe(spellVariantOverrideCache)
end

local function GetOverrideSpellIfDifferent(spellID)
    if not IsUsableSpellID(spellID) or not C_Spell.GetOverrideSpell then
        return nil
    end

    local cached = spellVariantOverrideCache[spellID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    local overrideID = C_Spell.GetOverrideSpell(spellID)
    if IsUsableSpellID(overrideID) and overrideID ~= spellID then
        spellVariantOverrideCache[spellID] = overrideID
        return overrideID
    end

    spellVariantOverrideCache[spellID] = false
    return nil
end

local function StoreIfValid(target, id, value, preserveExisting)
    if not IsUsableSpellID(id) then return end
    if preserveExisting and target[id] ~= nil then return end
    target[id] = value
end

local function StoreVariantValue(target, spellID, value, preserveExisting)
    if type(target) ~= "table" or not IsUsableSpellID(spellID) then
        return
    end

    StoreIfValid(target, spellID, value, preserveExisting)
    StoreIfValid(target, GetOverrideSpellIfDifferent(spellID), value, preserveExisting)

    local baseID = NormalizeToBase(spellID)
    if baseID and baseID ~= spellID then
        StoreIfValid(target, baseID, value, preserveExisting)
        StoreIfValid(target, GetOverrideSpellIfDifferent(baseID), value, preserveExisting)
    end
end

local function ResolveVariantValue(sourceMap, spellID)
    if type(sourceMap) ~= "table" or not IsUsableSpellID(spellID) then
        return nil
    end

    local direct = sourceMap[spellID]
    if direct ~= nil then
        return direct
    end

    local baseID = NormalizeToBase(spellID)
    if baseID and baseID ~= spellID then
        local baseValue = sourceMap[baseID]
        if baseValue ~= nil then
            return baseValue
        end
    end

    local overrideID = GetOverrideSpellIfDifferent(spellID)
    if overrideID then
        local overrideValue = sourceMap[overrideID]
        if overrideValue ~= nil then
            return overrideValue
        end
    end

    if baseID and baseID ~= spellID then
        local baseOverrideID = GetOverrideSpellIfDifferent(baseID)
        if baseOverrideID then
            local baseOverrideValue = sourceMap[baseOverrideID]
            if baseOverrideValue ~= nil then
                return baseOverrideValue
            end
        end
    end

    return nil
end

CDM.SpellVariant.ClearCaches = ClearSpellVariantResolutionCaches
CDM.SpellVariant.GetBaseSpellID = NormalizeToBase
CDM.SpellVariant.GetOverrideIfDifferent = GetOverrideSpellIfDifferent
CDM.SpellVariant.StoreValue = StoreVariantValue
CDM.SpellVariant.ResolveValue = ResolveVariantValue
