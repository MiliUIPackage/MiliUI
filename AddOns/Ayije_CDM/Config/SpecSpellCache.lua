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
local CAT_BAR       = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory.TrackedBar

local specEssentialCache = {}
local specUtilityCache = {}
local specBuffSpellCache = {}
local specBarSpellCache = {}

local function EnsureStorage()
    local db = Ayije_CDMDB
    if not db then return nil end
    if not db.global then db.global = {} end
    if not db.global.sharedSpecCaches then db.global.sharedSpecCaches = {} end
    local s = db.global.sharedSpecCaches
    if not s.specEssentialCache then s.specEssentialCache = {} end
    if not s.specUtilityCache then s.specUtilityCache = {} end
    if not s.specBuffSpellCache then s.specBuffSpellCache = {} end
    if not s.specBarSpellCache then s.specBarSpellCache = {} end
    return s
end

function CDM:_BuildSnapshotEntry(info, cooldownID)
    if not info then return nil end
    return {
        cooldownID = cooldownID,
        spellID = info.overrideTooltipSpellID or info.overrideSpellID or info.spellID,
        baseSpellID = info.spellID,
        hidden = IsHiddenByDefault(info),
        charges = info.charges or false,
    }
end

function CDM:_PersistSpecSnapshots(specID, snapshotLists)
    if not specID then return end
    local essential = snapshotLists and snapshotLists[CAT_ESSENTIAL]
    local utility   = snapshotLists and snapshotLists[CAT_UTILITY]
    local buff      = snapshotLists and snapshotLists[CAT_BUFF]
    local bar       = snapshotLists and snapshotLists[CAT_BAR]

    if essential and #essential == 0 then essential = nil end
    if utility and #utility == 0 then utility = nil end
    if buff and #buff == 0 then buff = nil end
    if bar and #bar == 0 then bar = nil end

    specEssentialCache[specID] = essential
    specUtilityCache[specID]   = utility
    specBuffSpellCache[specID] = buff
    specBarSpellCache[specID]  = bar

    local storage = EnsureStorage()
    if storage then
        storage.specEssentialCache[specID] = essential
        storage.specUtilityCache[specID]   = utility
        storage.specBuffSpellCache[specID] = buff
        storage.specBarSpellCache[specID]  = bar
    end
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

function API:GetSpecBarSpellCache(specID)
    local cached = specBarSpellCache[specID]
    if cached then return cached end
    local storage = EnsureStorage()
    return storage and storage.specBarSpellCache[specID]
end
