local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local API = CDM.API

local HIDE_BY_DEFAULT_FLAG = Enum.CooldownSetSpellFlags and Enum.CooldownSetSpellFlags.HideByDefault
local function IsHiddenByDefault(info)
    return info and info.flags and HIDE_BY_DEFAULT_FLAG and FlagsUtil and FlagsUtil.IsSet
        and FlagsUtil.IsSet(info.flags, HIDE_BY_DEFAULT_FLAG) or false
end

local CAT_ESSENTIAL = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.Essential
local CAT_UTILITY   = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.Utility
local CAT_BUFF      = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBuff

local specCacheScheduled = false

local function EnsureStorage()
    if not Ayije_CDMDB then return nil end
    if not Ayije_CDMDB.global then Ayije_CDMDB.global = {} end
    if not Ayije_CDMDB.global.sharedSpecCaches then
        Ayije_CDMDB.global.sharedSpecCaches = {}
    end
    return Ayije_CDMDB.global.sharedSpecCaches
end

local function CollectCategory(cat)
    if not cat or not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCategorySet then
        return nil
    end

    local ids = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
    if not ids or #ids == 0 then return nil end

    local result = {}
    for _, cooldownID in ipairs(ids) do
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
        if info then
            local spellID = info.overrideSpellID or info.spellID
            result[#result + 1] = {
                cooldownID = cooldownID,
                spellID = spellID,
                baseSpellID = info.spellID,
                hidden = IsHiddenByDefault(info),
                charges = info.charges or false,
            }
        end
    end

    return #result > 0 and result or nil
end

local function RefreshSpecSpellCache()
    specCacheScheduled = false

    local storage = EnsureStorage()
    if not storage then return end

    local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID()
    if not specID then return end

    if not storage.specSpellCache then storage.specSpellCache = {} end
    if not storage.specEssentialCache then storage.specEssentialCache = {} end
    if not storage.specUtilityCache then storage.specUtilityCache = {} end
    if not storage.specBuffSpellCache then storage.specBuffSpellCache = {} end

    local essential = CollectCategory(CAT_ESSENTIAL)
    local utility = CollectCategory(CAT_UTILITY)
    local buff = CollectCategory(CAT_BUFF)

    local combined = {}
    if essential then
        for _, entry in ipairs(essential) do
            combined[#combined + 1] = entry
        end
    end
    if utility then
        for _, entry in ipairs(utility) do
            combined[#combined + 1] = entry
        end
    end

    storage.specSpellCache[specID] = #combined > 0 and combined or nil
    storage.specEssentialCache[specID] = essential
    storage.specUtilityCache[specID] = utility
    storage.specBuffSpellCache[specID] = buff
end

local function ScheduleRefresh()
    if specCacheScheduled then return end
    specCacheScheduled = true
    C_Timer.After(0, RefreshSpecSpellCache)
end

function API:GetSpecSpellCache(specID)
    local storage = Ayije_CDMDB and Ayije_CDMDB.global and Ayije_CDMDB.global.sharedSpecCaches
    return storage and storage.specSpellCache and storage.specSpellCache[specID]
end

function API:GetSpecEssentialCache(specID)
    local storage = Ayije_CDMDB and Ayije_CDMDB.global and Ayije_CDMDB.global.sharedSpecCaches
    return storage and storage.specEssentialCache and storage.specEssentialCache[specID]
end

function API:GetSpecUtilityCache(specID)
    local storage = Ayije_CDMDB and Ayije_CDMDB.global and Ayije_CDMDB.global.sharedSpecCaches
    return storage and storage.specUtilityCache and storage.specUtilityCache[specID]
end

function API:GetSpecBuffSpellCache(specID)
    local storage = Ayije_CDMDB and Ayije_CDMDB.global and Ayije_CDMDB.global.sharedSpecCaches
    return storage and storage.specBuffSpellCache and storage.specBuffSpellCache[specID]
end

CDM:RegisterEvent("PLAYER_ENTERING_WORLD", ScheduleRefresh)
CDM:RegisterInternalCallback("OnSpecStateChanged", ScheduleRefresh)
CDM:RegisterInternalCallback("OnTalentDataChanged", ScheduleRefresh)
