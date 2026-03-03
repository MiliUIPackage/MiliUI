-- Config/Core.lua

local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM and CDM.CONST or {}
local L = CDM.L

-- Note: CDM.defaults is defined in Config/Defaults.lua (loaded before this file)

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
end

-- =========================================================================
--  DATABASE INITIALIZATION
-- =========================================================================

local function InitializeDB()
    if not Ayije_CDMDB then Ayije_CDMDB = {} end
    if not Ayije_CDMDB.profileKeys then Ayije_CDMDB.profileKeys = {} end
    if not Ayije_CDMDB.profiles then Ayije_CDMDB.profiles = {} end
    if not Ayije_CDMDB.global then Ayije_CDMDB.global = {} end
    if not Ayije_CDMDB.specProfiles then Ayije_CDMDB.specProfiles = {} end

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

-- =========================================================================
--  PROFILE MANAGEMENT API
-- =========================================================================

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

local function RebuildAndRefresh()
    if CDM.RebuildConfigFrame then CDM:RebuildConfigFrame() end
    CDM:RefreshConfig()
end

local function ApplyProfile(name)
    if not Ayije_CDMDB.profiles[name] then return false end
    Ayije_CDMDB.profileKeys[CDM.charKey] = name
    local profile = Ayije_CDMDB.profiles[name]
    FillMissingDefaults(profile, CDM.defaults)
    CompactSparseRuntimeData(profile)
    CDM.db = profile
    CDM.activeProfileName = name
    if CDM.MarkSpecDataDirty then CDM:MarkSpecDataDirty() end
    return true
end

CDM.ApplyProfile = ApplyProfile

function CDM:SetProfile(name)
    if not ApplyProfile(name) then return false end
    local specData = Ayije_CDMDB.specProfiles and Ayije_CDMDB.specProfiles[self.charKey]
    if specData and specData.enabled then
        local specIndex = GetSpecialization()
        if specIndex and specIndex > 0 then
            specData[specIndex] = name
        end
    end
    RebuildAndRefresh()
    return true
end

function CDM:NewProfile(name)
    if not name or name == "" then return false end
    if Ayije_CDMDB.profiles[name] then return false end  -- already exists
    Ayije_CDMDB.profiles[name] = {}
    return self:SetProfile(name)
end

function CDM:CopyProfile(sourceName)
    if not Ayije_CDMDB.profiles[sourceName] then return false end
    if sourceName == self.activeProfileName then return false end
    local source = Ayije_CDMDB.profiles[sourceName]
    local target = Ayije_CDMDB.profiles[self.activeProfileName]
    wipe(target)
    for key, value in pairs(source) do
        target[key] = CopyConfigValue(value)
    end
    FillMissingDefaults(target, self.defaults)
    CompactSparseRuntimeData(target)
    self.db = target
    RebuildAndRefresh()
    return true
end

function CDM:DeleteProfile(name)
    if name == self.activeProfileName then return false end  -- can't delete active
    if not Ayije_CDMDB.profiles[name] then return false end
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
    local profile = Ayije_CDMDB.profiles[self.activeProfileName]
    wipe(profile)
    FillMissingDefaults(profile, self.defaults)
    CompactSparseRuntimeData(profile)
    self.db = profile
    RebuildAndRefresh()
    return true
end

function CDM:RenameProfile(newName)
    if not newName or newName == "" then return false end
    if Ayije_CDMDB.profiles[newName] then return false end
    local oldName = self.activeProfileName
    if oldName == newName then return false end
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
    self.activeProfileName = newName
    RebuildAndRefresh()
    return true
end

-- =========================================================================
--  SPECIALIZATION PROFILE AUTO-SWITCHING
-- =========================================================================

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
    ApplyProfile(targetProfile)
    self:RefreshConfig()
    local optNS = self._OptionsNS
    if optNS and optNS.RefreshProfilesTab then
        optNS.RefreshProfilesTab()
    end
end

function CDM:ImportProfileData(profileName, profileData)
    if type(profileName) ~= "string" or profileName == "" then
        return false, "Invalid profile name"
    end
    if type(profileData) ~= "table" then
        return false, "Invalid profile data"
    end
    if not Ayije_CDMDB or not Ayije_CDMDB.profiles or not Ayije_CDMDB.profileKeys then
        return false, "Database not initialized"
    end

    local importedProfile = self:DeepCopy(profileData)
    FillMissingDefaults(importedProfile, self.defaults)
    CompactSparseRuntimeData(importedProfile)

    Ayije_CDMDB.profiles[profileName] = importedProfile
    Ayije_CDMDB.profileKeys[self.charKey] = profileName
    self.db = importedProfile
    self.activeProfileName = profileName

    local specData = Ayije_CDMDB.specProfiles and Ayije_CDMDB.specProfiles[self.charKey]
    if specData and specData.enabled then
        local specIndex = GetSpecialization()
        if specIndex and specIndex > 0 then
            specData[specIndex] = profileName
        end
    end

    self:RefreshConfig()
    return true
end

-- =========================================================================
--  UTILITY HELPERS
-- =========================================================================

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

    local tagSettings = CDM.db.resourcesTagSettings
    if type(tagSettings) ~= "table" then
        return isBar2 and TAG_DEFAULT_BAR2 or TAG_DEFAULT_BAR1
    end

    local entry = tagSettings[specID]
    if type(entry) ~= "table" then
        return isBar2 and TAG_DEFAULT_BAR2 or TAG_DEFAULT_BAR1
    end

    local key = isBar2 and "bar2Enabled" or "bar1Enabled"
    local val = entry[key]
    if val == nil then
        return isBar2 and TAG_DEFAULT_BAR2 or TAG_DEFAULT_BAR1
    end
    return val
end

function CDM:SetTagEnabled(isBar2, enabled)
    local specID = self:GetCurrentSpecID()
    if not specID then return end

    local defaultVal = isBar2 and TAG_DEFAULT_BAR2 or TAG_DEFAULT_BAR1
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

-- =========================================================================
--  MANA BAR SETTINGS (per-spec enable/disable)
-- =========================================================================

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

-- =========================================================================
--  SPELL REGISTRY HELPERS
-- =========================================================================

function CDM:GetSpellRegistry(specID)
    if self.SpellRegistry and self.SpellRegistry.GetRaw then
        return self.SpellRegistry:GetRaw(specID)
    end

    local registry = {
        secondary = {},
        tertiary = {},
        colors = {}
    }

    local spellReg = CDM.db and CDM.db.spellRegistry
    local userRegistry = spellReg and spellReg[specID]
    if userRegistry then
        if userRegistry.secondary then
            for _, id in ipairs(userRegistry.secondary) do
                table.insert(registry.secondary, id)
            end
        end

        if userRegistry.tertiary then
            for _, id in ipairs(userRegistry.tertiary) do
                table.insert(registry.tertiary, id)
            end
        end

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

function CDM:SaveSpell(specID, spellID, isSecondary, isTertiary, color)
    self.SpellRegistry:Save(specID, spellID, isSecondary, isTertiary, color)
    self:InvalidateSpellRegistryCache(specID)
    RefreshBuffViewer()
end

function CDM:RemoveSpell(specID, spellID)
    self.SpellRegistry:Remove(specID, spellID)
    self:InvalidateSpellRegistryCache(specID)
    RefreshBuffViewer()
end

-- =========================================================================
--  PER-SPELL GLOW SETTINGS
-- =========================================================================

local function EnsureGlowRegistryNode(specID)
    if not CDM.db then return nil end
    if not CDM.db.spellRegistry then
        CDM.db.spellRegistry = {}
    end
    if not CDM.db.spellRegistry[specID] then
        CDM.db.spellRegistry[specID] = { secondary = {}, tertiary = {}, colors = {} }
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

-- =========================================================================
--  SLASH COMMAND
-- =========================================================================

SLASH_AYIJECDM1 = "/cdm"
SLASH_AYIJECDM2 = "/acdm"
SlashCmdList["AYIJECDM"] = function()
    if InCombatLockdown() then
        print("|cffff0000[CDM]|r " .. L["Cannot open config while in combat"])
        return
    end

    if not C_AddOns.IsAddOnLoaded("Ayije_CDM_Options") then
        local loaded, reason = C_AddOns.LoadAddOn("Ayije_CDM_Options")
        if not loaded then
            print("|cffff0000[CDM]|r " .. string.format(L["Could not load options: %s"], reason or "unknown"))
            return
        end
    end
    CDM:ShowConfig()
end
