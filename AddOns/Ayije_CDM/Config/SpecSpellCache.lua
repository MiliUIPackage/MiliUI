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
local specEssentialCache = {}
local specUtilityCache = {}
local specBuffSpellCache = {}

local function EnsureStorage()
    local db = Ayije_CDMDB
    if not db then return nil end
    if not db.global then db.global = {} end
    if not db.global.sharedSpecCaches then db.global.sharedSpecCaches = {} end
    local s = db.global.sharedSpecCaches
    if not s.specEssentialCache then s.specEssentialCache = {} end
    if not s.specUtilityCache then s.specUtilityCache = {} end
    if not s.specBuffSpellCache then s.specBuffSpellCache = {} end
    return s
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
            local spellID = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID
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
    local specID = PlayerUtil and PlayerUtil.GetCurrentSpecID and PlayerUtil.GetCurrentSpecID()
    if not specID then return end
    specEssentialCache[specID] = CollectCategory(CAT_ESSENTIAL)
    specUtilityCache[specID]   = CollectCategory(CAT_UTILITY)
    specBuffSpellCache[specID] = CollectCategory(CAT_BUFF)

    local storage = EnsureStorage()
    if storage then
        storage.specEssentialCache[specID] = specEssentialCache[specID]
        storage.specUtilityCache[specID]   = specUtilityCache[specID]
        storage.specBuffSpellCache[specID] = specBuffSpellCache[specID]
    end
end

local function ScheduleRefresh()
    if specCacheScheduled then return end
    specCacheScheduled = true
    C_Timer.After(0, RefreshSpecSpellCache)
end

function API:GetSpecEssentialCache(specID)
    local cached = specEssentialCache[specID]
    if cached then return cached end
    local storage = EnsureStorage()
    return storage and storage.specEssentialCache[specID]
end

function API:GetSpecUtilityCache(specID)
    local cached = specUtilityCache[specID]
    if cached then return cached end
    local storage = EnsureStorage()
    return storage and storage.specUtilityCache[specID]
end

function API:GetSpecBuffSpellCache(specID)
    local cached = specBuffSpellCache[specID]
    if cached then return cached end
    local storage = EnsureStorage()
    return storage and storage.specBuffSpellCache[specID]
end

CDM:RegisterEvent("PLAYER_ENTERING_WORLD", ScheduleRefresh)
CDM:RegisterSpecStateHandler(ScheduleRefresh)
CDM:RegisterTalentDataHandler(ScheduleRefresh)
