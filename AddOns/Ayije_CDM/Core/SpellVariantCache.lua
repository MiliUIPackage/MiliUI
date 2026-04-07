local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

CDM.SpellVariant = CDM.SpellVariant or {}

local NormalizeToBase = CDM.NormalizeToBase
local GetOverrideIfDifferent = CDM.GetOverrideIfDifferent

local function IsUsableSpellID(id)
    return type(id) == "number" and id > 0 and id == math.floor(id)
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
    StoreIfValid(target, GetOverrideIfDifferent(spellID), value, preserveExisting)

    local baseID = NormalizeToBase(spellID)
    if baseID and baseID ~= spellID then
        StoreIfValid(target, baseID, value, preserveExisting)
        StoreIfValid(target, GetOverrideIfDifferent(baseID), value, preserveExisting)
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

    local overrideID = GetOverrideIfDifferent(spellID)
    if overrideID then
        local overrideValue = sourceMap[overrideID]
        if overrideValue ~= nil then
            return overrideValue
        end
    end

    if baseID and baseID ~= spellID then
        local baseOverrideID = GetOverrideIfDifferent(baseID)
        if baseOverrideID then
            local baseOverrideValue = sourceMap[baseOverrideID]
            if baseOverrideValue ~= nil then
                return baseOverrideValue
            end
        end
    end

    return nil
end

CDM.SpellVariant.GetBaseSpellID = NormalizeToBase
CDM.SpellVariant.StoreValue = StoreVariantValue
CDM.SpellVariant.ResolveValue = ResolveVariantValue
