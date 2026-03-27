local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local L = CDM.L

function CDM:DeepCopy(original)
    if type(original) ~= "table" then
        return original
    end

    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = CDM:DeepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function CopyConfigValue(value)
    if type(value) == "table" then
        return CDM:DeepCopy(value)
    end
    return value
end

local IsEmptyTable = CDM.CONST.IsEmptyTable

local PROFILE_MT = {
    __index = function(self, key)
        local default = CDM.defaults[key]
        if default == nil then return nil end
        if type(default) == "table" then
            if next(default) == nil then return nil end
            local copy = {}
            for k, v in pairs(default) do copy[k] = v end
            rawset(self, key, copy)
            return copy
        end
        return default
    end,
}

local function ApplyProfileMetatable(profile)
    setmetatable(profile, PROFILE_MT)
end

local TAG_DEFAULT_BAR1 = true
local TAG_DEFAULT_BAR2 = false

local function IsUsableSpellID(spellID)
    return CDM.IsSafeNumber(spellID) and spellID > 0 and spellID == math.floor(spellID)
end

local NormalizeNumericKeys

local function CompactSpellOverrideMap(overrideMap)
    if type(overrideMap) ~= "table" then return end

    NormalizeNumericKeys(overrideMap)

    local groupedEntries = {}
    for rawKey, entry in pairs(overrideMap) do
        if IsUsableSpellID(rawKey) and type(entry) == "table" then
            local storageKey = CDM:GetBuffOverrideStorageKey(rawKey)
            if IsUsableSpellID(storageKey) then
                if not groupedEntries[storageKey] then
                    groupedEntries[storageKey] = {}
                end
                groupedEntries[storageKey][#groupedEntries[storageKey] + 1] = {
                    key = rawKey,
                    entry = entry,
                }
            end
        end
    end

    local compacted = {}
    for storageKey, entries in pairs(groupedEntries) do
        table.sort(entries, function(left, right)
            local leftIsStorage = left.key == storageKey
            local rightIsStorage = right.key == storageKey
            if leftIsStorage ~= rightIsStorage then
                return leftIsStorage
            end
            return left.key < right.key
        end)

        local merged
        for _, item in ipairs(entries) do
            if not merged then
                merged = (CDM.CopyBuffOverrideEntry and CDM:CopyBuffOverrideEntry(item.entry)) or CopyConfigValue(item.entry)
            else
                if CDM.MergeMissingBuffOverrideFields then
                    CDM:MergeMissingBuffOverrideFields(merged, item.entry)
                end
            end
        end

        if merged then
            compacted[storageKey] = merged
        end
    end

    table.wipe(overrideMap)
    for storageKey, entry in pairs(compacted) do
        overrideMap[storageKey] = entry
    end
end

local function CompactGroupedOverrides(groups)
    if type(groups) ~= "table" then return end
    for _, specGroups in pairs(groups) do
        if type(specGroups) == "table" then
            for _, group in pairs(specGroups) do
                if type(group) == "table" and type(group.spellOverrides) == "table" then
                    CompactSpellOverrideMap(group.spellOverrides)
                end
            end
        end
    end
end

local function CompactUngroupedOverrides(ungrouped)
    if type(ungrouped) ~= "table" then return end
    for _, specOverrides in pairs(ungrouped) do
        if type(specOverrides) == "table" then
            CompactSpellOverrideMap(specOverrides)
        end
    end
end

local function CompactBuffOverrideTables(profile)
    if type(profile) ~= "table" then return end
    CompactGroupedOverrides(profile.buffGroups)
    CompactUngroupedOverrides(profile.ungroupedBuffOverrides)
    CompactGroupedOverrides(profile.cooldownGroups)
    CompactUngroupedOverrides(profile.ungroupedCooldownOverrides)
end

local function NormalizeBuffGroupSpellList(spellList)
    if type(spellList) ~= "table" then
        return {}
    end

    local normalized = {}
    local seen = {}

    for _, rawID in ipairs(spellList) do
        if IsUsableSpellID(rawID) and not seen[rawID] then
            normalized[#normalized + 1] = rawID
            seen[rawID] = true
        end
    end

    return normalized
end

local function CompactGroupSpellListsForKey(profile, key)
    local data = profile[key]
    if type(data) ~= "table" then return end

    for _, specGroups in pairs(data) do
        if type(specGroups) == "table" then
            for _, group in pairs(specGroups) do
                if type(group) == "table" and type(group.spells) == "table" then
                    group.spells = NormalizeBuffGroupSpellList(group.spells)
                end
            end
        end
    end
end

local function CompactBuffGroupSpellLists(profile)
    if type(profile) ~= "table" then return end
    CompactGroupSpellListsForKey(profile, "buffGroups")
    CompactGroupSpellListsForKey(profile, "cooldownGroups")
end

NormalizeNumericKeys = function(t)
    if type(t) ~= "table" then return end
    local toRekey
    for k, v in pairs(t) do
        if type(k) == "string" then
            local num = tonumber(k)
            if num then
                if not toRekey then toRekey = {} end
                toRekey[k] = num
            end
        end
    end
    if not toRekey then return end
    for oldKey, newKey in pairs(toRekey) do
        t[newKey] = t[oldKey]
        t[oldKey] = nil
    end
end

local NUMERIC_KEYED_TABLES = {
    "racialsCustomEntries",
    "racialsOrderPerSpec",
    "racialsDisabled",
    "defensivesCustomSpells",
    "defensivesOrder",
    "defensivesDisabledSpells",
    "spellRegistry",
    "resourcesManaSettings",
    "resourcesPrimaryResourceSettings",
    "resourcesSecondaryResourceSettings",
    "resourcesTagSettings",
    "buffGroups",
    "ungroupedBuffOverrides",
    "cooldownGroups",
    "ungroupedCooldownOverrides",
    "customBuffRegistry",
}

local function NormalizeImportedProfile(profile)
    if type(profile) ~= "table" then return end
    for _, key in ipairs(NUMERIC_KEYED_TABLES) do
        local t = profile[key]
        if type(t) == "table" then
            NormalizeNumericKeys(t)
            for _, subtable in pairs(t) do
                NormalizeNumericKeys(subtable)
            end
        end
    end

    CompactBuffGroupSpellLists(profile)
    CompactBuffOverrideTables(profile)
end

local function CompactSparseRuntimeData(profile)
    if type(profile) ~= "table" then return end

    CompactBuffGroupSpellLists(profile)
    CompactBuffOverrideTables(profile)

    if IsEmptyTable(profile.resourcesTagSettings) then
        profile.resourcesTagSettings = nil
    end
    if IsEmptyTable(profile.resourcesManaSettings) then
        profile.resourcesManaSettings = nil
    end
    if IsEmptyTable(profile.resourcesPrimaryResourceSettings) then
        profile.resourcesPrimaryResourceSettings = nil
    end
    if IsEmptyTable(profile.resourcesSecondaryResourceSettings) then
        profile.resourcesSecondaryResourceSettings = nil
    end

    if profile.spellRegistry ~= nil and type(profile.spellRegistry) ~= "table" then
        profile.spellRegistry = nil
    elseif CDM.SpellRegistry and CDM.SpellRegistry.CompactAll then
        CDM.SpellRegistry:CompactAll(profile)
    elseif IsEmptyTable(profile.spellRegistry) then
        profile.spellRegistry = nil
    end

    if IsEmptyTable(profile.buffGroups) then
        profile.buffGroups = nil
    end
    if IsEmptyTable(profile.ungroupedBuffOverrides) then
        profile.ungroupedBuffOverrides = nil
    end
    if profile.cooldownGroups and IsEmptyTable(profile.cooldownGroups) then
        profile.cooldownGroups = nil
    end
    if profile.ungroupedCooldownOverrides and IsEmptyTable(profile.ungroupedCooldownOverrides) then
        profile.ungroupedCooldownOverrides = nil
    end
end

local function MigrateSecondaryTertiaryToBuffGroups(prof)
    if type(prof) ~= "table" then return end

    local secSize = prof.sizeBuffSecondary or { w = 40, h = 36 }
    local tertSize = prof.sizeBuffTertiary or { w = 40, h = 36 }
    local secOffX = prof.buffSecondaryOffsetX or -120
    local secOffY = prof.buffSecondaryOffsetY or 1
    local tertOffX = prof.buffTertiaryOffsetX or 120
    local tertOffY = prof.buffTertiaryOffsetY or 1
    local secHoriz = prof.buffSecondaryHorizontal == true
    local tertHoriz = prof.buffTertiaryHorizontal == true
    local countPosSec = prof.countPositionSec or "RIGHT"
    local countOXSec = prof.countOffsetXSec or 4
    local countOYSec = prof.countOffsetYSec or 0
    local countPosTert = prof.countPositionTert or "LEFT"
    local countOXTert = prof.countOffsetXTert or -4
    local countOYTert = prof.countOffsetYTert or 0
    local globalSpacing = prof.spacing or 1
    local globalCountFS = prof.countFontSize or 15
    local gc = prof.countColor
    local globalCountColor = gc
        and { r = gc.r or 1, g = gc.g or 1, b = gc.b or 1, a = gc.a or 1 }
        or { r = 1, g = 1, b = 1, a = 1 }
    local globalCdFS = prof.buffCooldownFontSize or 15
    local cdc = prof.buffCooldownColor or prof.cooldownColor
    local globalCdColor = cdc
        and { r = cdc.r or 1, g = cdc.g or 1, b = cdc.b or 1, a = cdc.a or 1 }
        or { r = 1, g = 1, b = 1, a = 1 }

    if type(prof.spellRegistry) == "table" then
        for specID, specData in pairs(prof.spellRegistry) do
            if type(specData) == "table" then
                local hasSec = type(specData.secondary) == "table" and #specData.secondary > 0
                local hasTert = type(specData.tertiary) == "table" and #specData.tertiary > 0

                if hasSec or hasTert then
                    if not prof.buffGroups then prof.buffGroups = {} end
                    if not prof.buffGroups[specID] then prof.buffGroups[specID] = {} end
                    local groups = prof.buffGroups[specID]

                    if #groups == 0 then
                        if hasSec then
                            local spells = NormalizeBuffGroupSpellList(specData.secondary)
                            groups[#groups + 1] = {
                                name = "Secondary",
                                spells = spells,
                                grow = secHoriz and "CENTER_H" or "UP",
                                spacing = globalSpacing,
                                iconWidth = secSize.w,
                                iconHeight = secSize.h,
                                countFontSize = globalCountFS,
                                countColor = { r = globalCountColor.r, g = globalCountColor.g, b = globalCountColor.b, a = globalCountColor.a },
                                countPosition = countPosSec,
                                countOffsetX = countOXSec,
                                countOffsetY = countOYSec,
                                cooldownFontSize = globalCdFS,
                                cooldownColor = { r = globalCdColor.r, g = globalCdColor.g, b = globalCdColor.b, a = globalCdColor.a },
                                anchorTarget = "buff",
                                anchorPoint = "BOTTOM",
                                anchorRelativeTo = "TOP",
                                offsetX = secOffX,
                                offsetY = secOffY,
                            }
                        end

                        if hasTert then
                            local spells = NormalizeBuffGroupSpellList(specData.tertiary)
                            groups[#groups + 1] = {
                                name = "Tertiary",
                                spells = spells,
                                grow = tertHoriz and "CENTER_H" or "UP",
                                spacing = globalSpacing,
                                iconWidth = tertSize.w,
                                iconHeight = tertSize.h,
                                countFontSize = globalCountFS,
                                countColor = { r = globalCountColor.r, g = globalCountColor.g, b = globalCountColor.b, a = globalCountColor.a },
                                countPosition = countPosTert,
                                countOffsetX = countOXTert,
                                countOffsetY = countOYTert,
                                cooldownFontSize = globalCdFS,
                                cooldownColor = { r = globalCdColor.r, g = globalCdColor.g, b = globalCdColor.b, a = globalCdColor.a },
                                anchorTarget = "buff",
                                anchorPoint = "BOTTOM",
                                anchorRelativeTo = "TOP",
                                offsetX = tertOffX,
                                offsetY = tertOffY,
                            }
                        end
                    end
                end

                specData.secondary = nil
                specData.tertiary = nil
            end
        end
    end

    prof.sizeBuffSecondary = nil
    prof.sizeBuffTertiary = nil
    prof.buffSecondaryOffsetX = nil
    prof.buffSecondaryOffsetY = nil
    prof.buffTertiaryOffsetX = nil
    prof.buffTertiaryOffsetY = nil
    prof.buffSecondaryHorizontal = nil
    prof.buffTertiaryHorizontal = nil
    prof.countPositionSec = nil
    prof.countOffsetXSec = nil
    prof.countOffsetYSec = nil
    prof.countPositionTert = nil
    prof.countOffsetXTert = nil
    prof.countOffsetYTert = nil
end

local function TablesMatch(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do
        if b[k] ~= v then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function StripDefaultMatchingValues(profile)
    for key, default in pairs(CDM.defaults) do
        local raw = rawget(profile, key)
        if raw == nil then
            -- already absent
        elseif type(default) ~= "table" then
            if raw == default then
                rawset(profile, key, nil)
            end
        elseif next(default) ~= nil then
            if TablesMatch(raw, default) then
                rawset(profile, key, nil)
            end
        end
    end
end

local DB_SCHEMA_VERSION = 8

local function MigrateGroupOverrides(profile, groupsKey, ungroupedKey)
    local groups = profile[groupsKey]
    local ungrouped = profile[ungroupedKey]
    if type(groups) ~= "table" then return end
    for specID, specGroups in pairs(groups) do
        if type(specGroups) == "table" then
            local specOv = type(ungrouped) == "table" and type(ungrouped[specID]) == "table" and ungrouped[specID]
            for _, group in pairs(specGroups) do
                if type(group) == "table" and type(group.spells) == "table" then
                    if specOv then
                        for _, sid in ipairs(group.spells) do
                            local key = CDM:GetBuffOverrideStorageKey(sid)
                            if key and type(specOv[key]) == "table" then
                                if not group.spellOverrides then group.spellOverrides = {} end
                                if not group.spellOverrides[key] then
                                    group.spellOverrides[key] = specOv[key]
                                    specOv[key] = nil
                                end
                            end
                        end
                    end
                    local ov = group.spellOverrides
                    if type(ov) == "table" and next(ov) and CDM.EnsureBuffOverrideEntry then
                        for _, sid in ipairs(group.spells) do
                            local entry = CDM:EnsureBuffOverrideEntry(ov, sid)
                            if entry and not next(entry) then
                                local key = CDM:GetBuffOverrideStorageKey(sid)
                                if key then ov[key] = nil end
                            end
                        end
                    end
                end
            end
        end
    end
end

local PROFILE_MIGRATIONS = {
    {
        version = 1,
        run = function(profile)
            MigrateSecondaryTertiaryToBuffGroups(profile)
        end,
    },
    {
        version = 2,
        run = StripDefaultMatchingValues,
    },
    {
        version = 3,
        run = function(profile)
            local old = rawget(profile, "fadingTrigger")
            if old ~= nil then
                profile.fadingTriggerNoTarget = (old == "notarget")
                profile.fadingTriggerOOC = (old == "ooc")
                profile.fadingTriggerMounted = false
                profile.fadingTrigger = nil
            end
        end,
    },
    {
        version = 4,
        run = function(profile)
            local size = rawget(profile, "cooldownFontSize")
            if size ~= nil then
                if rawget(profile, "essRow2CooldownFontSize") == nil then
                    profile.essRow2CooldownFontSize = size
                end
                if rawget(profile, "utilityCooldownFontSize") == nil then
                    profile.utilityCooldownFontSize = size
                end
            end
        end,
    },
    {
        version = 5,
        run = function(profile)
            MigrateGroupOverrides(profile, "buffGroups", "ungroupedBuffOverrides")
        end,
    },
    {
        version = 6,
        run = function(profile)
            local size = rawget(profile, "chargeFontSize")
            if size ~= nil then
                if rawget(profile, "utilityChargeFontSize") == nil then
                    profile.utilityChargeFontSize = size
                end
            end
        end,
    },
    {
        version = 7,
        run = function(profile)
            MigrateGroupOverrides(profile, "cooldownGroups", "ungroupedCooldownOverrides")
        end,
    },
    {
        version = 8,
        run = function(profile)
            local reg = profile.spellRegistry
            if type(reg) ~= "table" then return end
            for specID, node in pairs(reg) do
                if type(node) == "table" and type(node.glowEnabled) == "table" then
                    for k, v in pairs(node.glowEnabled) do
                        if v ~= true then
                            node.glowEnabled[k] = nil
                        end
                    end
                    if not next(node.glowEnabled) then
                        node.glowEnabled = nil
                    end
                end
            end
        end,
    },
}

local function GetCurrentSchemaVersion(globalData)
    local schemaVersion = globalData and tonumber(globalData.schemaVersion)
    if schemaVersion then
        return schemaVersion
    end
    return 0
end

function CDM:RunProfileMigrations(profile, fromVersion, toVersion)
    if type(profile) ~= "table" then return end
    local currentVersion = tonumber(fromVersion) or 0
    local targetVersion = tonumber(toVersion) or DB_SCHEMA_VERSION
    if currentVersion >= targetVersion then return end

    for _, migration in ipairs(PROFILE_MIGRATIONS) do
        if migration.version > currentVersion and migration.version <= targetVersion then
            migration.run(profile)
        end
    end
end

local function RunDatabaseMigrations()
    local globalData = Ayije_CDMDB.global
    local currentVersion = GetCurrentSchemaVersion(globalData)
    if currentVersion < DB_SCHEMA_VERSION then
        for _, profile in pairs(Ayije_CDMDB.profiles) do
            CDM:RunProfileMigrations(profile, currentVersion, DB_SCHEMA_VERSION)
        end
        globalData.schemaVersion = DB_SCHEMA_VERSION
    else
        globalData.schemaVersion = currentVersion
    end

end

local function InitializeDB()
    if not Ayije_CDMDB then Ayije_CDMDB = {} end
    if not Ayije_CDMDB.profileKeys then Ayije_CDMDB.profileKeys = {} end
    if not Ayije_CDMDB.profiles then Ayije_CDMDB.profiles = {} end
    if not Ayije_CDMDB.global then Ayije_CDMDB.global = {} end
    Ayije_CDMDB.global.multiChargeSpells = nil
    if not Ayije_CDMDB.specProfiles then Ayije_CDMDB.specProfiles = {} end

    RunDatabaseMigrations()

    local charKey = UnitName("player") .. " - " .. GetRealmName()
    local defaultProfile = Ayije_CDMDB.global.defaultProfile or "Default"
    local profileName = Ayije_CDMDB.profileKeys[charKey] or defaultProfile
    Ayije_CDMDB.profileKeys[charKey] = profileName

    if not Ayije_CDMDB.profiles[profileName] then
        Ayije_CDMDB.profiles[profileName] = {}
    end

    local profile = Ayije_CDMDB.profiles[profileName]

    StripDefaultMatchingValues(profile)
    ApplyProfileMetatable(profile)
    CompactSparseRuntimeData(profile)

    CDM.db = profile
    CDM.activeProfileName = profileName
    CDM.charKey = charKey

    if not Ayije_CDMDB.global.cooldownViewerAutoEnabled then
        Ayije_CDMDB.global.cooldownViewerAutoEnabled = {}
    end
    if not Ayije_CDMDB.global.cooldownViewerAutoEnabled[charKey] then
        Ayije_CDMDB.global.cooldownViewerAutoEnabled[charKey] = true
        if not InCombatLockdown() then
            SetCVar("cooldownViewerEnabled", 1)
            print("|cff00ccff[CDM]|r " .. L["Enabled Blizzard Cooldown Manager."])
        end
    end
end

CDM.InitializeDB = InitializeDB

function CDM:GetProfileList()
    local list = {}
    for name in pairs(Ayije_CDMDB.profiles) do
        list[#list + 1] = name
    end
    table.sort(list)
    return list
end

function CDM:GetActiveProfileName()
    return self.activeProfileName
end

local function CommitActiveProfileReference(name)
    if not Ayije_CDMDB.profiles[name] then
        return false
    end
    Ayije_CDMDB.profileKeys[CDM.charKey] = name
    CDM.db = Ayije_CDMDB.profiles[name]
    ApplyProfileMetatable(CDM.db)
    CDM.activeProfileName = name
    return true
end

local function RebuildOptionsIfLoaded(targetTab)
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Ayije_CDM_Options")) then
        return
    end
    if CDM.RebuildConfigFrame then
        CDM:RebuildConfigFrame(targetTab)
    end
end

local function InvalidateProfileCaches()
    if CDM.InvalidateSpecIDCache then
        CDM:InvalidateSpecIDCache()
    end

    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    if specID and CDM.InvalidateSpellRegistryCache then
        CDM:InvalidateSpellRegistryCache(specID)
    elseif CDM.MarkSpecDataDirty then
        CDM:MarkSpecDataDirty()
    end

    if CDM.InvalidateFrameCategoryCache then
        CDM:InvalidateFrameCategoryCache()
    end
end

local function PrepareProfileDataForApply(profileData, fromSchemaVersion)
    if type(profileData) ~= "table" then
        return nil, "invalid_profile_data"
    end

    local prepared = CDM:DeepCopy(profileData)
    NormalizeImportedProfile(prepared)
    if fromSchemaVersion and fromSchemaVersion < DB_SCHEMA_VERSION then
        CDM:RunProfileMigrations(prepared, fromSchemaVersion, DB_SCHEMA_VERSION)
    end
    for key, value in pairs(prepared) do
        local defaultValue = CDM.defaults[key]
        if defaultValue ~= nil and type(defaultValue) ~= type(value) then
            prepared[key] = CopyConfigValue(defaultValue)
        elseif type(value) == "table" and type(defaultValue) == "table" then
            for dk, dv in pairs(defaultValue) do
                if value[dk] == nil and type(dv) ~= "table" then
                    value[dk] = dv
                end
            end
        end
    end
    ApplyProfileMetatable(prepared)
    CompactSparseRuntimeData(prepared)
    return prepared
end

local function QueueCanonicalProfileRefresh(options)
    if options and options.rebuildOptions ~= false then
        RebuildOptionsIfLoaded(options.targetTab)
    end

    CDM:RefreshConfig()
end

function CDM:ApplyProfileAtomic(name, preparedProfileData, options)
    if type(name) ~= "string" or name == "" then
        return false, "invalid_profile_name"
    end
    if not Ayije_CDMDB or not Ayije_CDMDB.profiles or not Ayije_CDMDB.profileKeys then
        return false, "db_not_initialized"
    end
    if InCombatLockdown() and not (options and options.allowInCombat) then
        return false, "combat_blocked"
    end

    local sourceProfileData = preparedProfileData
    if sourceProfileData == nil then
        sourceProfileData = Ayije_CDMDB.profiles[name]
    end
    if sourceProfileData == nil then
        return false, "profile_not_found"
    end

    local commitProfileData, prepareErr = PrepareProfileDataForApply(
        sourceProfileData,
        options and options.fromSchemaVersion
    )
    if not commitProfileData then
        return false, prepareErr or "invalid_profile_data"
    end

    options = options or {}

    Ayije_CDMDB.profiles[name] = commitProfileData
    CommitActiveProfileReference(name)

    if options.updateCurrentSpecProfile then
        local specData = Ayije_CDMDB.specProfiles
            and Ayije_CDMDB.specProfiles[self.charKey]
        if specData and specData.enabled then
            local specIndex = GetSpecialization()
            if specIndex and specIndex > 0 then
                specData[specIndex] = name
            end
        end
    end

    InvalidateProfileCaches()
    CDM:RefreshScopesNow({ "spec_data" })

    if CDM.ModuleManager and CDM.ModuleManager.NotifyProfileApplied then
        CDM.ModuleManager:NotifyProfileApplied()
    end
    if CDM.DisableBlizzardPlayerCastBar then
        CDM:DisableBlizzardPlayerCastBar()
    end

    QueueCanonicalProfileRefresh(options)
    return true
end

function CDM:SetProfile(name)
    local ok, err = self:ApplyProfileAtomic(name, nil, {
        rebuildOptions = true,
        targetTab = "profiles",
        updateCurrentSpecProfile = true,
    })
    if not ok then
        return false, err
    end
    return true
end

function CDM:NewProfile(name)
    if not name or name == "" then return false, "invalid_profile_name" end
    if Ayije_CDMDB.profiles[name] then return false, "profile_exists" end
    return self:ApplyProfileAtomic(name, {}, {
        rebuildOptions = true,
        targetTab = "profiles",
        updateCurrentSpecProfile = true,
    })
end

function CDM:CopyProfile(sourceName)
    if not Ayije_CDMDB.profiles[sourceName] then return false, "profile_not_found" end
    if sourceName == self.activeProfileName then return false, "source_is_active" end
    local source = Ayije_CDMDB.profiles[sourceName]
    local targetProfileData = {}
    for key, value in pairs(source) do
        targetProfileData[key] = CopyConfigValue(value)
    end
    return self:ApplyProfileAtomic(self.activeProfileName, targetProfileData, {
        rebuildOptions = true,
        targetTab = "profiles",
    })
end

function CDM:DeleteProfile(name)
    if name == self.activeProfileName then return false, "cannot_delete_active_profile" end
    if not Ayije_CDMDB.profiles[name] then return false, "profile_not_found" end
    local fallback = Ayije_CDMDB.global.defaultProfile or "Default"
    if fallback == name then fallback = "Default" end

    Ayije_CDMDB.profiles[name] = nil
    for charKey, profileName in pairs(Ayije_CDMDB.profileKeys) do
        if profileName == name then
            Ayije_CDMDB.profileKeys[charKey] = nil
        end
    end
    if Ayije_CDMDB.specProfiles then
        for _, specData in pairs(Ayije_CDMDB.specProfiles) do
            for i = 1, 4 do
                if specData[i] == name then
                    specData[i] = fallback
                end
            end
        end
    end
    if Ayije_CDMDB.global.defaultProfile == name then
        Ayije_CDMDB.global.defaultProfile = "Default"
    end
    return true
end

function CDM:ResetProfile()
    return self:ApplyProfileAtomic(self.activeProfileName, {}, {
        rebuildOptions = true,
        targetTab = "profiles",
    })
end

function CDM:RenameProfile(newName)
    if not newName or newName == "" then return false, "invalid_profile_name" end
    if Ayije_CDMDB.profiles[newName] then return false, "profile_exists" end
    if InCombatLockdown() then return false, "combat_blocked" end

    local oldName = self.activeProfileName
    if oldName == newName then return false, "same_profile_name" end
    if not Ayije_CDMDB.profiles[oldName] then return false, "profile_not_found" end

    local renamedProfileData = Ayije_CDMDB.profiles[oldName]

    Ayije_CDMDB.profiles[newName] = Ayije_CDMDB.profiles[oldName]
    Ayije_CDMDB.profiles[oldName] = nil
    for charKey, profileName in pairs(Ayije_CDMDB.profileKeys) do
        if profileName == oldName then
            Ayije_CDMDB.profileKeys[charKey] = newName
        end
    end
    if Ayije_CDMDB.specProfiles then
        for _, specData in pairs(Ayije_CDMDB.specProfiles) do
            for i = 1, 4 do
                if specData[i] == oldName then
                    specData[i] = newName
                end
            end
        end
    end
    if Ayije_CDMDB.global.defaultProfile == oldName then
        Ayije_CDMDB.global.defaultProfile = newName
    end

    if self.db == renamedProfileData then
        self.db = Ayije_CDMDB.profiles[newName]
    end
    if self.activeProfileName == oldName then
        self.activeProfileName = newName
    end

    RebuildOptionsIfLoaded("profiles")
    return true
end

function CDM:GetSpecProfileData()
    if not Ayije_CDMDB.specProfiles then return nil end
    return Ayije_CDMDB.specProfiles[self.charKey]
end

function CDM:IsSpecProfileEnabled()
    local data = self:GetSpecProfileData()
    return data and data.enabled or false
end

function CDM:SetSpecProfileEnabled(enabled)
    if not Ayije_CDMDB.specProfiles then Ayije_CDMDB.specProfiles = {} end
    local data = Ayije_CDMDB.specProfiles[self.charKey]
    if enabled then
        if not data then
            data = {}
            Ayije_CDMDB.specProfiles[self.charKey] = data
        end
        data.enabled = true
        local classId = select(3, UnitClass("player"))
        if not classId then return end
        local numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classId)
        for i = 1, numSpecs do
            if not data[i] then
                data[i] = self.activeProfileName
            end
        end
    elseif data then
        data.enabled = false
    end
end

function CDM:GetSpecProfile(specIndex)
    local data = self:GetSpecProfileData()
    if not data or not data.enabled then return nil end
    return data[specIndex]
end

function CDM:SetSpecProfile(specIndex, profileName)
    local data = self:GetSpecProfileData()
    if data then
        data[specIndex] = profileName
    end
end

function CDM:CheckSpecProfileSwitch(specIndex)
    local targetProfile = self:GetSpecProfile(specIndex)
    if not targetProfile then return end
    if targetProfile == self.activeProfileName then return end
    if not Ayije_CDMDB.profiles[targetProfile] then return end
    local ok, err = self:ApplyProfileAtomic(targetProfile, nil, {
        rebuildOptions = false,
    })
    if not ok then
        return false, err
    end
    local optNS = self._OptionsNS
    if optNS and optNS.RefreshProfilesTab then
        optNS.RefreshProfilesTab()
    end
    return true
end

function CDM:ImportProfileData(profileName, profileData)
    if type(profileName) ~= "string" or profileName == "" then
        return false, "invalid_profile_name"
    end
    if type(profileData) ~= "table" then
        return false, "invalid_profile_data"
    end
    if not Ayije_CDMDB or not Ayije_CDMDB.profiles or not Ayije_CDMDB.profileKeys then
        return false, "db_not_initialized"
    end

    local ok, err = self:ApplyProfileAtomic(profileName, profileData, {
        rebuildOptions = true,
        targetTab = "importexport",
        updateCurrentSpecProfile = true,
        fromSchemaVersion = 0,
    })
    if not ok then
        return false, err or "apply_failed"
    end
    return true
end

local cachedSpecID = nil

function CDM:GetCurrentSpecID()
    if cachedSpecID then return cachedSpecID end
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local specID = GetSpecializationInfo(specIndex)
    if not specID or specID == 0 then return nil end
    cachedSpecID = specID
    return cachedSpecID
end

function CDM:InvalidateSpecIDCache()
    cachedSpecID = nil
end

local function GetPerSpecSetting(dbFieldName, specID, default)
    if not specID then return default end
    local db = CDM.db
    if not db then return default end
    local settings = db[dbFieldName]
    if type(settings) ~= "table" then return default end
    local stored = settings[specID]
    if stored ~= nil then return stored end
    return default
end

local function SetPerSpecSetting(dbFieldName, specID, value, default)
    if not specID then return end
    local db = CDM.db
    if not db then return end
    local isDefault = (value == default) or (default == true and value == nil)
    if isDefault then
        local settings = db[dbFieldName]
        if type(settings) == "table" then
            settings[specID] = nil
            if not next(settings) then db[dbFieldName] = nil end
        end
    else
        if type(db[dbFieldName]) ~= "table" then
            db[dbFieldName] = {}
        end
        db[dbFieldName][specID] = value
    end
end

function CDM:GetTagEnabled(isBar2)
    local specID = self:GetCurrentSpecID()
    if not specID then return false end

    local default
    if isBar2 then
        default = TAG_DEFAULT_BAR2
    else
        default = TAG_DEFAULT_BAR1
    end

    local tagSettings = CDM.db.resourcesTagSettings
    if type(tagSettings) ~= "table" then
        return default
    end

    local entry = tagSettings[specID]
    if type(entry) ~= "table" then
        return default
    end

    local key = isBar2 and "bar2Enabled" or "bar1Enabled"
    local val = entry[key]
    if val == nil then
        return default
    end
    return val
end

function CDM:SetTagEnabled(isBar2, enabled)
    local specID = self:GetCurrentSpecID()
    if not specID then return end

    local defaultVal
    if isBar2 then
        defaultVal = TAG_DEFAULT_BAR2
    else
        defaultVal = TAG_DEFAULT_BAR1
    end
    local key = isBar2 and "bar2Enabled" or "bar1Enabled"

    if enabled == defaultVal then
        local tagSettings = CDM.db.resourcesTagSettings
        if type(tagSettings) ~= "table" then return end
        local entry = tagSettings[specID]
        if type(entry) ~= "table" then return end
        entry[key] = nil
        if IsEmptyTable(entry) then
            tagSettings[specID] = nil
        end
        if IsEmptyTable(tagSettings) then
            CDM.db.resourcesTagSettings = nil
        end
    else
        if not CDM.db.resourcesTagSettings then
            CDM.db.resourcesTagSettings = {}
        end
        if not CDM.db.resourcesTagSettings[specID] then
            CDM.db.resourcesTagSettings[specID] = {}
        end
        CDM.db.resourcesTagSettings[specID][key] = enabled
    end
end

function CDM:GetManaEnabled()
    local specID = self:GetCurrentSpecID()
    if not specID then return false end
    local manaSpecs = self.MANA_SPECS
    if not manaSpecs or manaSpecs[specID] == nil then return false end
    return GetPerSpecSetting("resourcesManaSettings", specID, manaSpecs[specID])
end

function CDM:SetManaEnabled(enabled)
    local specID = self:GetCurrentSpecID()
    if not specID then return end
    local manaSpecs = self.MANA_SPECS
    local default = manaSpecs and manaSpecs[specID] or false
    SetPerSpecSetting("resourcesManaSettings", specID, enabled, default)
end

function CDM:GetPrimaryResourceEnabled()
    return GetPerSpecSetting("resourcesPrimaryResourceSettings", self:GetCurrentSpecID(), true)
end

function CDM:SetPrimaryResourceEnabled(enabled)
    SetPerSpecSetting("resourcesPrimaryResourceSettings", self:GetCurrentSpecID(), enabled, true)
end

function CDM:GetSecondaryResourceEnabled()
    return GetPerSpecSetting("resourcesSecondaryResourceSettings", self:GetCurrentSpecID(), true)
end

function CDM:SetSecondaryResourceEnabled(enabled)
    SetPerSpecSetting("resourcesSecondaryResourceSettings", self:GetCurrentSpecID(), enabled, true)
end

function CDM:InvalidateSpellRegistryCache(specID)
    if self.SpellRegistry and self.SpellRegistry.Refresh then
        self.SpellRegistry:Refresh(specID)
    end
    if self.MarkSpecDataDirty then
        self:MarkSpecDataDirty()
    end
end

local function RefreshBuffViewer()
    if CDM.RefreshSpecData then CDM:RefreshSpecData() end
    CDM.styleCacheVersion = (CDM.styleCacheVersion or 0) + 1
    local BUFF = CDM.CONST.VIEWERS and CDM.CONST.VIEWERS.BUFF
    if BUFF and CDM.QueueViewer then
        CDM:QueueViewer(BUFF)
    end
end

function CDM:SaveSpell(specID, spellID, color)
    self.SpellRegistry:Save(specID, spellID, color)
    self:InvalidateSpellRegistryCache(specID)
    RefreshBuffViewer()
end

function CDM:ClearSpellBorderColor(specID, spellID)
    self.SpellRegistry:ClearColor(specID, spellID)
    self:InvalidateSpellRegistryCache(specID)
    RefreshBuffViewer()
end

local stableBaseCache = {}
local cooldownViewerDataReady = false

if CDM.RegisterEvent then
    CDM:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED", function()
        cooldownViewerDataReady = true
        table.wipe(stableBaseCache)
    end)
end

local ALL_VIEWER_CATEGORIES = {}
if Enum and Enum.CooldownViewerCategory then
    local evc = Enum.CooldownViewerCategory
    if evc.Essential then ALL_VIEWER_CATEGORIES[#ALL_VIEWER_CATEGORIES + 1] = evc.Essential end
    if evc.Utility then ALL_VIEWER_CATEGORIES[#ALL_VIEWER_CATEGORIES + 1] = evc.Utility end
    if evc.TrackedBuff then ALL_VIEWER_CATEGORIES[#ALL_VIEWER_CATEGORIES + 1] = evc.TrackedBuff end
    if evc.TrackedBar then ALL_VIEWER_CATEGORIES[#ALL_VIEWER_CATEGORIES + 1] = evc.TrackedBar end
end

local function ResolveStableBase(spellID)
    if not IsUsableSpellID(spellID) then return nil end

    local cached = stableBaseCache[spellID]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCategorySet
        or not C_CooldownViewer.GetCooldownViewerCooldownInfo then
        if cooldownViewerDataReady then
            stableBaseCache[spellID] = false
        end
        return nil
    end

    for _, cat in ipairs(ALL_VIEWER_CATEGORIES) do
        local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
        if cooldownIDs then
            for _, cdID in ipairs(cooldownIDs) do
                local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                if info and info.spellID then
                    local matched = false
                    if info.spellID == spellID or info.overrideSpellID == spellID then
                        matched = true
                    end
                    if not matched and info.linkedSpellIDs then
                        for _, lid in ipairs(info.linkedSpellIDs) do
                            if lid == spellID then
                                matched = true
                                break
                            end
                        end
                    end
                    if matched then
                        local base = info.spellID
                        stableBaseCache[base] = base
                        if info.overrideSpellID then
                            stableBaseCache[info.overrideSpellID] = base
                        end
                        if info.linkedSpellIDs then
                            for _, lid in ipairs(info.linkedSpellIDs) do
                                stableBaseCache[lid] = base
                            end
                        end
                        return base
                    end
                end
            end
        end
    end

    if cooldownViewerDataReady then
        stableBaseCache[spellID] = false
    end
    return nil
end

function CDM:ResolveStableBase(spellID)
    return ResolveStableBase(spellID)
end

function CDM:ClearStableBaseCache()
    table.wipe(stableBaseCache)
end

local function EnsureGlowRegistryNode(specID)
    return CDM.SpellRegistry.EnsureStructure(specID)
end

function CDM:GetSpellGlowEnabled(specID, spellID)
    if not CDM.db or not CDM.db.spellRegistry then return false end
    local reg = CDM.db.spellRegistry[specID]
    if not reg or not reg.glowEnabled then return false end
    if reg.glowEnabled[spellID] == true then return true end
    local base = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if base and base ~= spellID and reg.glowEnabled[base] == true then return true end
    local stable = self.ResolveStableBase and self:ResolveStableBase(spellID)
    if stable and stable ~= spellID and stable ~= base and reg.glowEnabled[stable] == true then return true end
    return false
end

function CDM:HasAnySpellGlowConfigured(specID)
    if not specID then return false end

    local currentSpecID = self:GetCurrentSpecID()
    if currentSpecID and specID == currentSpecID and self.SpellSets then
        return self.SpellSets.hasBuffGlows == true
    end

    if not self.db or not self.db.spellRegistry then
        return false
    end

    local reg = self.db.spellRegistry[specID]
    return type(reg and reg.glowEnabled) == "table" and next(reg.glowEnabled) ~= nil or false
end

function CDM:SetSpellGlowEnabled(specID, spellID, enabled)
    local reg = EnsureGlowRegistryNode(specID)
    if not reg then return end

    if not reg.glowEnabled then
        reg.glowEnabled = {}
    end

    reg.glowEnabled[spellID] = enabled and true or nil
    local base = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if base and base ~= spellID then reg.glowEnabled[base] = nil end
    local stable = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if stable and stable ~= spellID and stable ~= base then reg.glowEnabled[stable] = nil end

    if CDM.SpellRegistry and CDM.SpellRegistry.CompactSpec then
        CDM.SpellRegistry:CompactSpec(specID)
    end
    self:InvalidateSpellRegistryCache(specID)
    self:RefreshConfig()
end

function CDM:GetSpellGlowColor(specID, spellID)
    if not CDM.db or not CDM.db.spellRegistry then return nil end
    local reg = CDM.db.spellRegistry[specID]
    if not reg or not reg.glowColors then return nil end
    if reg.glowColors[spellID] then return reg.glowColors[spellID] end
    local base = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if base and base ~= spellID and reg.glowColors[base] then return reg.glowColors[base] end
    local stable = self.ResolveStableBase and self:ResolveStableBase(spellID)
    if stable and stable ~= spellID and stable ~= base and reg.glowColors[stable] then return reg.glowColors[stable] end
    return nil
end

function CDM:SetSpellGlowColor(specID, spellID, color)
    local reg = EnsureGlowRegistryNode(specID)
    if not reg then return end

    if not reg.glowColors then
        reg.glowColors = {}
    end

    reg.glowColors[spellID] = color and { r = color.r, g = color.g, b = color.b } or nil
    local base = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if base and base ~= spellID then reg.glowColors[base] = nil end
    local stable = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if stable and stable ~= spellID and stable ~= base then reg.glowColors[stable] = nil end

    if CDM.SpellRegistry and CDM.SpellRegistry.CompactSpec then
        CDM.SpellRegistry:CompactSpec(specID)
    end
    self:InvalidateSpellRegistryCache(specID)
    self:RefreshConfig()
end

CDM.BuffGroupSets = {
    grouped = {},
    cooldownIDGrouped = {},
    groups = nil,
}

CDM.CooldownGroupSets = {
    grouped = {},
    cooldownIDGrouped = {},
    groups = nil,
}

local function RefreshGroupData(self, sets, dbKey, categories, shouldInvalidateCache)
    table.wipe(sets.grouped)
    table.wipe(sets.cooldownIDGrouped)
    sets.groups = nil

    local specID = self:GetCurrentSpecID()
    if not specID then return end

    local groupDB = self.db and self.db[dbKey]
    if not groupDB then return end

    local specGroups = groupDB[specID]
    if not specGroups then return end

    sets.groups = specGroups

    local spellToGroup = {}

    for groupIndex, group in ipairs(specGroups) do
        if group.spells then
            for _, spellID in ipairs(group.spells) do
                sets.grouped[spellID] = groupIndex
                local entry = { groupIdx = groupIndex, storedID = spellID }
                spellToGroup[spellID] = entry
            end
        end
    end

    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet
        and C_CooldownViewer.GetCooldownViewerCooldownInfo
        and Enum and Enum.CooldownViewerCategory then
        for _, cat in ipairs(categories) do
            local cooldownIDs = C_CooldownViewer.GetCooldownViewerCategorySet(cat, true)
            if cooldownIDs then
                for _, cdID in ipairs(cooldownIDs) do
                    local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cdID)
                    if info then
                        local match
                        if IsUsableSpellID(info.overrideSpellID) and info.overrideSpellID ~= info.spellID then
                            match = spellToGroup[info.overrideSpellID]
                        end
                        if not match then
                            match = spellToGroup[info.spellID]
                        end
                        if not match and info.linkedSpellIDs then
                            for _, lid in ipairs(info.linkedSpellIDs) do
                                if IsUsableSpellID(lid) then
                                    match = spellToGroup[lid]
                                    if match then break end
                                end
                            end
                        end
                        if match then
                            sets.cooldownIDGrouped[cdID] = match
                        end
                    end
                end
            end
        end
    end

    if shouldInvalidateCache and self.InvalidateFrameCategoryCache then
        self:InvalidateFrameCategoryCache()
    end
end

function CDM:RefreshBuffGroupData()
    RefreshGroupData(self, self.BuffGroupSets, "buffGroups", ALL_VIEWER_CATEGORIES, true)
end

function CDM:RefreshCooldownGroupData()
    RefreshGroupData(self, self.CooldownGroupSets, "cooldownGroups", ALL_VIEWER_CATEGORIES, false)
end

local configOpenQueueEventsRegistered = false

local function GetConfigOpenBlockedStatus()
    if InCombatLockdown() then
        return "queued_combat"
    end
    if CDM.loginFinished ~= true then
        return "queued_login"
    end
    return nil
end

local function PrintConfigOpenQueuedNotice(status)
    if CDM._configOpenQueueNoticeShown then
        return
    end

    local message
    if status == "queued_combat" then
        message = L["Config open queued until combat ends."]
    else
        message = L["Config open queued until login setup finishes."]
    end

    print("|cff00ccff[CDM]|r " .. tostring(message))
    CDM._configOpenQueueNoticeShown = true
end

local function OpenConfigNow(targetTab)
    if not C_AddOns.IsAddOnLoaded("Ayije_CDM_Options") then
        local loaded, reason = C_AddOns.LoadAddOn("Ayije_CDM_Options")
        if not loaded then
            print("|cffff0000[CDM]|r " .. string.format(L["Could not load options: %s"], reason or "unknown"))
            return "load_failed"
        end
    end

    if targetTab and CDM.RebuildConfigFrame then
        CDM:RebuildConfigFrame(targetTab)
    else
        CDM:ShowConfig()
    end
    return "opened"
end

local function EnsureConfigOpenQueueEventsRegistered()
    if configOpenQueueEventsRegistered then
        return
    end
    configOpenQueueEventsRegistered = true

    CDM:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if CDM.TryOpenQueuedConfig then
            CDM:TryOpenQueuedConfig("combat_end")
        end
    end)
end

function CDM:TryOpenQueuedConfig(_reason)
    local blockedStatus = GetConfigOpenBlockedStatus()
    if blockedStatus then
        return blockedStatus
    end

    local pending = self._pendingConfigOpen
    if not pending then
        return nil
    end

    local status = OpenConfigNow(pending.targetTab)
    self._pendingConfigOpen = nil
    self._configOpenQueueNoticeShown = nil
    return status
end

function CDM:RequestConfigOpen(origin, targetTab)
    EnsureConfigOpenQueueEventsRegistered()

    local blockedStatus = GetConfigOpenBlockedStatus()
    if blockedStatus then
        -- Last request wins while blocked.
        local hadPending = self._pendingConfigOpen ~= nil
        self._pendingConfigOpen = {
            origin = origin,
            targetTab = targetTab,
        }
        if not hadPending then
            PrintConfigOpenQueuedNotice(blockedStatus)
        end
        return blockedStatus
    end

    if self._pendingConfigOpen then
        return self:TryOpenQueuedConfig("request_unblocked")
    end

    return OpenConfigNow(targetTab)
end
