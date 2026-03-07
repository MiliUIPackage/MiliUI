local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM and CDM.CONST or {}
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

local function IsEmptyTable(t)
    return type(t) == "table" and next(t) == nil
end

local SPARSE_EMPTY_TABLE_DEFAULTS = {
    resourcesManaSettings = true,
    resourcesTagSettings = true,
    spellRegistry = true,
    buffGroups = true,
    ungroupedBuffOverrides = true,
}

local function ShouldSkipDefaultCopy(key, value)
    return SPARSE_EMPTY_TABLE_DEFAULTS[key] and IsEmptyTable(value)
end

local function FillMissingDefaults(profile, defaults)
    for key, value in pairs(defaults) do
        if profile[key] == nil and not ShouldSkipDefaultCopy(key, value) then
            profile[key] = CopyConfigValue(value)
        end
    end
end

local TAG_DEFAULT_BAR1 = true
local TAG_DEFAULT_BAR2 = false

local function IsUsableSpellID(spellID)
    if CDM.IsSafeNumber then
        return CDM.IsSafeNumber(spellID) and spellID > 0 and spellID == math.floor(spellID)
    end
    return type(spellID) == "number" and spellID > 0 and spellID == math.floor(spellID)
end

local function GetNormalizedBaseSpellID(spellID)
    if not IsUsableSpellID(spellID) then return nil end
    if type(CDM.NormalizeToBase) ~= "function" then return nil end

    local baseID = CDM.NormalizeToBase(spellID)
    if IsUsableSpellID(baseID) then
        return baseID
    end
    return nil
end

local function GetOverrideSpellID(spellID)
    if not IsUsableSpellID(spellID) then return nil end
    if not (C_Spell and C_Spell.GetOverrideSpell) then return nil end

    local overrideID = C_Spell.GetOverrideSpell(spellID)
    if IsUsableSpellID(overrideID) and overrideID ~= spellID then
        return overrideID
    end
    return nil
end

local function NormalizeLegacyBuffGroupSpellList(spellList)
    if type(spellList) ~= "table" then
        return {}
    end

    local normalized = {}
    local seen = {}

    for _, rawID in ipairs(spellList) do
        if IsUsableSpellID(rawID) then
            local baseID = GetNormalizedBaseSpellID(rawID)
            local overrideID = GetOverrideSpellID(rawID)
            local baseOverrideID = GetOverrideSpellID(baseID)
            local canonicalID = baseID or rawID

            if not seen[rawID]
                and not (baseID and seen[baseID])
                and not (overrideID and seen[overrideID])
                and not (baseOverrideID and seen[baseOverrideID]) then
                normalized[#normalized + 1] = canonicalID
                seen[rawID] = true
                seen[canonicalID] = true
                if baseID then
                    seen[baseID] = true
                end
                if overrideID then
                    seen[overrideID] = true
                end
                if baseOverrideID then
                    seen[baseOverrideID] = true
                end
            end
        end
    end

    return normalized
end

local function NormalizeNumericKeys(t)
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
    "resourcesTagSettings",
    "buffGroups",
    "ungroupedBuffOverrides",
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

    local bg = profile.buffGroups
    if type(bg) == "table" then
        for _, specGroups in pairs(bg) do
            if type(specGroups) == "table" then
                for _, group in pairs(specGroups) do
                    if type(group) == "table" and type(group.spellOverrides) == "table" then
                        NormalizeNumericKeys(group.spellOverrides)
                    end
                end
            end
        end
    end

    local ubo = profile.ungroupedBuffOverrides
    if type(ubo) == "table" then
        for _, specOverrides in pairs(ubo) do
            if type(specOverrides) == "table" then
                NormalizeNumericKeys(specOverrides)
            end
        end
    end
end

local function CompactSparseRuntimeData(profile)
    if type(profile) ~= "table" then return end

    if IsEmptyTable(profile.resourcesTagSettings) then
        profile.resourcesTagSettings = nil
    end
    if IsEmptyTable(profile.resourcesManaSettings) then
        profile.resourcesManaSettings = nil
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
                            local spells = NormalizeLegacyBuffGroupSpellList(specData.secondary)
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
                            local spells = NormalizeLegacyBuffGroupSpellList(specData.tertiary)
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

local DB_SCHEMA_VERSION = 1

local PROFILE_MIGRATIONS = {
    {
        version = 1,
        run = function(profile)
            MigrateSecondaryTertiaryToBuffGroups(profile)
        end,
    },
}

local function GetCurrentSchemaVersion(globalData)
    local schemaVersion = globalData and tonumber(globalData.schemaVersion)
    if schemaVersion then
        return schemaVersion
    end
    if globalData and globalData.buffGroupsMigrated then
        return 1
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

    if globalData.schemaVersion >= 1 then
        globalData.buffGroupsMigrated = true
    end
end

local function InitializeDB()
    if not Ayije_CDMDB then Ayije_CDMDB = {} end
    if not Ayije_CDMDB.profileKeys then Ayije_CDMDB.profileKeys = {} end
    if not Ayije_CDMDB.profiles then Ayije_CDMDB.profiles = {} end
    if not Ayije_CDMDB.global then Ayije_CDMDB.global = {} end
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

    FillMissingDefaults(profile, CDM.defaults)
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
    FillMissingDefaults(prepared, CDM.defaults)
    for key, value in pairs(prepared) do
        local defaultValue = CDM.defaults[key]
        if defaultValue ~= nil and type(defaultValue) ~= type(value) then
            prepared[key] = CopyConfigValue(defaultValue)
        end
    end
    CompactSparseRuntimeData(prepared)
    return prepared
end

local function QueueCanonicalProfileRefresh(options)
    if options and options.rebuildOptions ~= false then
        RebuildOptionsIfLoaded(options.targetTab)
    end

    if CDM.RefreshConfig then
        CDM:RefreshConfig()
    end
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
                    specData[i] = nil
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
    local manaSpecs = CDM.MANA_SPECS
    if not manaSpecs or manaSpecs[specID] == nil then return false end

    local manaSettings = CDM.db.resourcesManaSettings
    if type(manaSettings) == "table" and manaSettings[specID] ~= nil then
        return manaSettings[specID]
    end
    return manaSpecs[specID]
end

function CDM:SetManaEnabled(enabled)
    local specID = self:GetCurrentSpecID()
    if not specID then return end

    local manaSpecs = CDM.MANA_SPECS
    local defaultEnabled = manaSpecs and manaSpecs[specID] or false

    if enabled == defaultEnabled then
        local manaSettings = CDM.db.resourcesManaSettings
        if type(manaSettings) ~= "table" then return end
        manaSettings[specID] = nil
        if IsEmptyTable(manaSettings) then
            CDM.db.resourcesManaSettings = nil
        end
    else
        if not CDM.db.resourcesManaSettings then
            CDM.db.resourcesManaSettings = {}
        end
        CDM.db.resourcesManaSettings[specID] = enabled
    end
end

function CDM:GetSpellRegistry(specID)
    if self.SpellRegistry and self.SpellRegistry.GetRaw then
        return self.SpellRegistry:GetRaw(specID)
    end

    local registry = {
        colors = {}
    }

    local spellReg = CDM.db and CDM.db.spellRegistry
    local userRegistry = spellReg and spellReg[specID]
    if userRegistry then
        if userRegistry.colors then
            for id, color in pairs(userRegistry.colors) do
                registry.colors[id] = color
            end
        end
    end

    return registry
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
    if CDM.InvalidateFrameCategoryCache then CDM:InvalidateFrameCategoryCache() end
    if CDM.QueueViewer then CDM:QueueViewer("BuffIconCooldownViewer", true) end
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

local function EnsureGlowRegistryNode(specID)
    if not CDM.db then return nil end
    if not CDM.db.spellRegistry then
        CDM.db.spellRegistry = {}
    end
    if not CDM.db.spellRegistry[specID] then
        CDM.db.spellRegistry[specID] = { colors = {} }
    end
    return CDM.db.spellRegistry[specID]
end

function CDM:GetSpellGlowEnabled(specID, spellID)
    if not CDM.db or not CDM.db.spellRegistry then return false end
    local reg = CDM.db.spellRegistry[specID]
    if not reg or not reg.glowEnabled then return false end
    return reg.glowEnabled[spellID] or false
end

function CDM:SetSpellGlowEnabled(specID, spellID, enabled)
    local reg = EnsureGlowRegistryNode(specID)
    if not reg then return end

    if not reg.glowEnabled then
        reg.glowEnabled = {}
    end

    reg.glowEnabled[spellID] = enabled or nil  -- nil to remove false entries

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
    return reg.glowColors[spellID]
end

function CDM:SetSpellGlowColor(specID, spellID, color)
    local reg = EnsureGlowRegistryNode(specID)
    if not reg then return end

    if not reg.glowColors then
        reg.glowColors = {}
    end

    if color then
        reg.glowColors[spellID] = { r = color.r, g = color.g, b = color.b }
    else
        reg.glowColors[spellID] = nil
    end

    if CDM.SpellRegistry and CDM.SpellRegistry.CompactSpec then
        CDM.SpellRegistry:CompactSpec(specID)
    end
    self:InvalidateSpellRegistryCache(specID)
    self:RefreshConfig()
end

CDM.BuffGroupSets = {
    grouped = {},
    groups = nil,
}

function CDM:RefreshBuffGroupData()
    local sets = self.BuffGroupSets
    table.wipe(sets.grouped)
    sets.groups = nil

    local specID = self:GetCurrentSpecID()
    if not specID then return end

    local bg = self.db and self.db.buffGroups
    if not bg then return end

    local specGroups = bg[specID]
    if not specGroups then return end

    sets.groups = specGroups

    for groupIndex, group in ipairs(specGroups) do
        if group.spells then
            for _, spellID in ipairs(group.spells) do
                sets.grouped[spellID] = groupIndex
            end
        end
    end

    if self.InvalidateFrameCategoryCache then
        self:InvalidateFrameCategoryCache()
    end
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

SLASH_AYIJECDM1 = "/cdm"
SLASH_AYIJECDM2 = "/acdm"
SlashCmdList["AYIJECDM"] = function(msg)
    local command = ""
    if type(msg) == "string" then
        command = msg:match("^(%S+)") or ""
        command = string.lower(command)
    end

    if command == "enable" then
        if CDM.SetupCooldownViewerEditModeCompliancePrompt then
            CDM:SetupCooldownViewerEditModeCompliancePrompt()
        end
        if CDM.TriggerCooldownViewerSettingsComplianceFlow then
            CDM:TriggerCooldownViewerSettingsComplianceFlow("slash_enable")
        elseif CDM.RunCooldownViewerSettingsComplianceFlow then
            CDM:RunCooldownViewerSettingsComplianceFlow("slash_enable")
        end
        return
    end

    CDM:RequestConfigOpen("slash", nil)
end
