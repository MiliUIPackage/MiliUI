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
            return copy
        end
        return default
    end,
}

local function ApplyProfileMetatable(profile)
    setmetatable(profile, PROFILE_MT)
end

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

-- Used for import normalization (string→int key fixup) and compaction (nil when empty).
local SPARSE_TABLE_KEYS = {}
for key, default in pairs(CDM.defaults) do
    if type(default) == "table" and next(default) == nil then
        SPARSE_TABLE_KEYS[#SPARSE_TABLE_KEYS + 1] = key
    end
end

local function NormalizeImportedProfile(profile)
    if type(profile) ~= "table" then return end
    for _, key in ipairs(SPARSE_TABLE_KEYS) do
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

local function IsRegistrySpecEmpty(node)
    if type(node) ~= "table" then return true end
    if not IsEmptyTable(node.colors) then return false end
    if node.glowEnabled ~= nil and not IsEmptyTable(node.glowEnabled) then return false end
    if node.glowColors ~= nil and not IsEmptyTable(node.glowColors) then return false end
    return true
end

local function CompactRegistrySpec(specID, profile)
    local db = profile or CDM.db
    if type(db) ~= "table" or type(db.spellRegistry) ~= "table" then return end
    local node = db.spellRegistry[specID]
    if not node then return end

    if IsEmptyTable(node.glowEnabled) then node.glowEnabled = nil end
    if IsEmptyTable(node.glowColors) then node.glowColors = nil end

    if IsRegistrySpecEmpty(node) then
        db.spellRegistry[specID] = nil
    end

    if IsEmptyTable(db.spellRegistry) then
        db.spellRegistry = nil
    end
end

local function CompactSparseRuntimeData(profile)
    if type(profile) ~= "table" then return end

    CompactBuffGroupSpellLists(profile)
    CompactBuffOverrideTables(profile)

    if type(profile.spellRegistry) == "table" then
        local specIDs = {}
        for specID in pairs(profile.spellRegistry) do
            specIDs[#specIDs + 1] = specID
        end
        for _, specID in ipairs(specIDs) do
            CompactRegistrySpec(specID, profile)
        end
    elseif profile.spellRegistry ~= nil then
        profile.spellRegistry = nil
    end

    for _, key in ipairs(SPARSE_TABLE_KEYS) do
        if key ~= "spellRegistry" and IsEmptyTable(profile[key]) then
            profile[key] = nil
        end
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

local DB_SCHEMA_VERSION = 23

local LEGACY_RESOURCE_KEYS = {
    "resourcesBarHeight", "resourcesBar2Height", "resourcesBarWidth",
    "resourcesBarTexture", "resourcesBarBackgroundTexture",
    "resourcesBackgroundColor", "resourcesBarSpacing",
    "resourcesOffsetX", "resourcesOffsetY",
    "resourcesBar1TagFontSize", "resourcesBar1TagAnchor",
    "resourcesBar1TagOffsetX", "resourcesBar1TagOffsetY", "resourcesBar1TagColor",
    "resourcesBar2TagFontSize", "resourcesBar2TagAnchor",
    "resourcesBar2TagOffsetX", "resourcesBar2TagOffsetY", "resourcesBar2TagColor",
    "resourcesManaColor", "resourcesRageColor", "resourcesEnergyColor",
    "resourcesFocusColor", "resourcesComboPointsColor",
    "resourcesComboPointsChargedColor", "resourcesComboPointsChargedEmptyColor",
    "resourcesFeralOverflowingColor", "resourcesFeralOverflowingEmptyColor",
    "resourcesRunesReadyColor", "resourcesRunesRechargingColor",
    "resourcesRunicPowerColor", "resourcesLunarPowerColor",
    "resourcesIronfurColor", "resourcesIgnorePainColor", "resourcesIgnorePainHideIcon",
    "resourcesMaelstromColor", "resourcesInsanityColor", "resourcesFuryColor",
    "resourcesEssenceColor", "resourcesEssenceRechargingColor",
    "resourcesSoulShardsColor", "resourcesSoulShardsRechargingColor",
    "resourcesHolyPowerColor", "resourcesArcaneChargesColor", "resourcesChiColor",
    "resourcesStaggerLightColor", "resourcesStaggerModerateColor",
    "resourcesStaggerHeavyColor", "resourcesSoulFragmentsColor",
    "resourcesDevourerSoulFragmentsColor", "resourcesTipOfTheSpearColor",
    "resourcesManaPercentage", "resourcesManaSettings",
    "resourcesPrimaryResourceSettings", "resourcesSecondaryResourceSettings",
    "resourcesTagSettings", "resourcesSmoothBars", "resourcesMoveBuffsDown",
}

-- A bar-name key (as opposed to a class-name key) at the top level of
-- resourceBarSettings indicates a corrupt flat structure from an older
-- alpha shape or a metatable auto-populate. Used by v13 to force a rebuild.
local RESOURCE_BAR_NAME_LOOKUP = {
    Mana=true, Rage=true, Energy=true, Focus=true, ComboPoints=true, Runes=true,
    RunicPower=true, SoulShards=true, LunarPower=true, HolyPower=true,
    Maelstrom=true, Chi=true, Insanity=true, ArcaneCharges=true, Fury=true,
    Essence=true, SoulFragments=true, DevourerSoulFragments=true, Ironfur=true,
    IgnorePain=true, TipOfTheSpear=true, Stagger=true, MaelstromWeapon=true,
}

local SECOND_BAR_PARENT = {
    ComboPoints           = "Energy",
    Ironfur               = "Rage",
    Chi                   = "Energy",
    Stagger               = "Energy",
    IgnorePain            = "Rage",
    SoulFragments         = "Fury",
    DevourerSoulFragments = "Fury",
    TipOfTheSpear         = "Focus",
    Runes                 = "RunicPower",
}

local OLD_COLOR_KEY_MAP = {
    Mana = "resourcesManaColor",
    Rage = "resourcesRageColor",
    Energy = "resourcesEnergyColor",
    Focus = "resourcesFocusColor",
    ComboPoints = "resourcesComboPointsColor",
    Runes = "resourcesRunesReadyColor",
    RunicPower = "resourcesRunicPowerColor",
    SoulShards = "resourcesSoulShardsColor",
    LunarPower = "resourcesLunarPowerColor",
    HolyPower = "resourcesHolyPowerColor",
    Maelstrom = "resourcesMaelstromColor",
    Chi = "resourcesChiColor",
    Insanity = "resourcesInsanityColor",
    ArcaneCharges = "resourcesArcaneChargesColor",
    Fury = "resourcesFuryColor",
    Essence = "resourcesEssenceColor",
    SoulFragments = "resourcesSoulFragmentsColor",
    MaelstromWeapon = "resourcesMaelstromColor",
    DevourerSoulFragments = "resourcesDevourerSoulFragmentsColor",
    Ironfur = "resourcesIronfurColor",
    IgnorePain = "resourcesIgnorePainColor",
    TipOfTheSpear = "resourcesTipOfTheSpearColor",
}

local SECONDARY_COLOR_MIGRATIONS = {
    Runes = { rechargingColor = "resourcesRunesRechargingColor" },
    Essence = { rechargingColor = "resourcesEssenceRechargingColor" },
    SoulShards = { rechargingColor = "resourcesSoulShardsRechargingColor" },
    ComboPoints = {
        chargedColor = "resourcesComboPointsChargedColor",
        chargedEmptyColor = "resourcesComboPointsChargedEmptyColor",
        overflowingColor = "resourcesFeralOverflowingColor",
        overflowingEmptyColor = "resourcesFeralOverflowingEmptyColor",
    },
    Stagger = {
        lightColor = "resourcesStaggerLightColor",
        moderateColor = "resourcesStaggerModerateColor",
        heavyColor = "resourcesStaggerHeavyColor",
    },
}

local LEGACY_SPEC_BAR_SLOTS = {
    [71]   = {"Rage"}, [72] = {"Rage"}, [73] = {"Rage","IgnorePain"},
    [65]   = {"HolyPower"}, [66] = {"HolyPower"}, [70] = {"HolyPower"},
    [253]  = {"Focus"}, [254] = {"Focus"}, [255] = {"Focus","TipOfTheSpear"},
    [259]  = {"Energy","ComboPoints"}, [260] = {"Energy","ComboPoints"}, [261] = {"Energy","ComboPoints"},
    [258]  = {"Insanity"},
    [250]  = {"RunicPower","Runes"}, [251] = {"RunicPower","Runes"}, [252] = {"RunicPower","Runes"},
    [262]  = {"Maelstrom"}, [263] = {"MaelstromWeapon"},
    [62]   = {"ArcaneCharges"},
    [265]  = {"SoulShards"}, [266] = {"SoulShards"}, [267] = {"SoulShards"},
    [268]  = {"Energy","Stagger"}, [269] = {"Energy","Chi"},
    [102]  = {"LunarPower"}, [103] = {"Energy","ComboPoints"}, [104] = {"Rage","Ironfur"},
    [577]  = {"Fury"}, [581] = {"Fury","SoulFragments"}, [1480] = {"Fury","DevourerSoulFragments"},
    [1467] = {"Essence"}, [1468] = {"Essence"}, [1473] = {"Essence"},
}

local LEGACY_SMOOTH_ELIGIBLE = {
    Mana=true, Rage=true, Energy=true, Focus=true, RunicPower=true,
    LunarPower=true, Maelstrom=true, Insanity=true, Fury=true,
}

local function MigrateToPerBarResources(profile)
    if profile.resourceBarSettings then return end

    local commonDefaults = CDM.RESOURCE_BAR_COMMON_DEFAULTS
    if not commonDefaults then return end

    local height = rawget(profile, "resourcesBarHeight") or commonDefaults.height
    local width = rawget(profile, "resourcesBarWidth") or commonDefaults.width
    local barTexture = rawget(profile, "resourcesBarTexture") or commonDefaults.barTexture
    local bgTexture = rawget(profile, "resourcesBarBackgroundTexture") or commonDefaults.bgTexture
    local bgColor = rawget(profile, "resourcesBackgroundColor") or commonDefaults.bgColor
    local offsetX = rawget(profile, "resourcesOffsetX") or commonDefaults.offsetX
    local offsetY = rawget(profile, "resourcesOffsetY") or commonDefaults.offsetY
    local barSpacing = rawget(profile, "resourcesBarSpacing") or commonDefaults.barSpacing
    local tagFontSize = rawget(profile, "resourcesBar1TagFontSize") or commonDefaults.tagFontSize
    local tagAnchor = rawget(profile, "resourcesBar1TagAnchor") or commonDefaults.tagAnchor
    local tagOffsetX = rawget(profile, "resourcesBar1TagOffsetX") or commonDefaults.tagOffsetX
    local tagOffsetY = rawget(profile, "resourcesBar1TagOffsetY") or commonDefaults.tagOffsetY
    local tagColor = rawget(profile, "resourcesBar1TagColor") or commonDefaults.tagColor

    local smoothDisabled = rawget(profile, "resourcesSmoothBars") == false

    local height2 = rawget(profile, "resourcesBar2Height") or height
    local tagFontSize2 = rawget(profile, "resourcesBar2TagFontSize") or tagFontSize
    local tagAnchor2 = rawget(profile, "resourcesBar2TagAnchor") or tagAnchor
    local tagOffsetX2 = rawget(profile, "resourcesBar2TagOffsetX") or tagOffsetX
    local tagOffsetY2 = rawget(profile, "resourcesBar2TagOffsetY") or tagOffsetY
    local tagColor2 = rawget(profile, "resourcesBar2TagColor") or tagColor

    local function BuildBarEntry(barKey)
        local parentBar = SECOND_BAR_PARENT[barKey]
        local isSecond = parentBar ~= nil
        local entry = {
            enabled = true,
            height = isSecond and height2 or height,
            width = width,
            barTexture = barTexture,
            bgTexture = bgTexture,
            bgColor = bgColor,
            tagEnabled = true,
            tagFontSize = isSecond and tagFontSize2 or tagFontSize,
            tagAnchor = isSecond and tagAnchor2 or tagAnchor,
            tagOffsetX = isSecond and tagOffsetX2 or tagOffsetX,
            tagOffsetY = isSecond and tagOffsetY2 or tagOffsetY,
            tagColor = isSecond and tagColor2 or tagColor,
        }

        if isSecond then
            entry.anchorTo = parentBar
            entry.barSpacing = barSpacing
        else
            entry.offsetX = offsetX
            entry.offsetY = offsetY
        end

        if smoothDisabled and LEGACY_SMOOTH_ELIGIBLE[barKey] then
            entry.smoothBars = false
        end

        local oldColorKey = OLD_COLOR_KEY_MAP[barKey]
        if oldColorKey then
            local color = rawget(profile, oldColorKey)
            if color then entry.color = color end
        end

        local secondaries = SECONDARY_COLOR_MIGRATIONS[barKey]
        if secondaries then
            for settingKey, oldKey in pairs(secondaries) do
                local val = rawget(profile, oldKey)
                if val then entry[settingKey] = val end
            end
        end

        if barKey == "Mana" then
            local pct = rawget(profile, "resourcesManaPercentage")
            if pct ~= nil then entry.displayAsPercent = pct end
        elseif barKey == "IgnorePain" then
            local hide = rawget(profile, "resourcesIgnorePainHideIcon")
            if hide ~= nil then entry.hideIcon = hide end
        end

        return entry
    end

    local result = {}

    local classesToMigrate = { "General" }
    for classKey in pairs(CDM.CLASS_BARS) do
        if classKey ~= "General" then
            classesToMigrate[#classesToMigrate + 1] = classKey
        end
    end

    for _, classKey in ipairs(classesToMigrate) do
        local bars = CDM.CLASS_BARS[classKey]
        if bars then
            result[classKey] = {}
            for _, barKey in ipairs(bars) do
                result[classKey][barKey] = BuildBarEntry(barKey)
            end
        end
    end

    local oldTagSettings = rawget(profile, "resourcesTagSettings")
    if oldTagSettings then
        local tagDisabledBars = {}
        for specID, specTags in pairs(oldTagSettings) do
            if type(specTags) == "table" then
                local slots = LEGACY_SPEC_BAR_SLOTS[specID]
                if slots then
                    if specTags["bar1Enabled"] == false and slots[1] then tagDisabledBars[slots[1]] = true end
                    if specTags["bar2Enabled"] == false and slots[2] then tagDisabledBars[slots[2]] = true end
                end
            end
        end
        for barKey in pairs(tagDisabledBars) do
            for _, classKey in ipairs(classesToMigrate) do
                if result[classKey] and result[classKey][barKey] then
                    result[classKey][barKey].tagEnabled = false
                end
            end
        end
    end

    profile.resourceBarSettings = result
end

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

local function RunResourceKeyMigrationCleanup(profile)
    local rbs = profile.resourceBarSettings
    if not rbs then return end
    local MANA_SPECS = CDM.MANA_SPECS

    for classKey, bars in pairs(rbs) do
        for barKey, entry in pairs(bars) do
            if type(entry) == "table" then
                if entry.enabled == false then
                    entry.loadMode = "never"
                end
                entry.enabled = nil

                if barKey == "Mana" and MANA_SPECS then
                    entry.loadMode = entry.loadMode or "conditional"
                    local spec = {}
                    for specID, defaultOn in pairs(MANA_SPECS) do
                        if defaultOn then spec[specID] = true end
                    end
                    local oldManaSettings = rawget(profile, "resourcesManaSettings")
                    if oldManaSettings then
                        for specID, val in pairs(oldManaSettings) do
                            if val == true then
                                spec[specID] = true
                            elseif val == false then
                                spec[specID] = nil
                            end
                        end
                    end
                    entry.load = entry.load or {}
                    entry.load.spec = spec
                end
            end
        end
    end

    local function ApplyVisibilityMigration(oldKey, slotIndex)
        local oldSettings = rawget(profile, oldKey)
        if not oldSettings then return end
        local _, playerClass = UnitClass("player")
        if not playerClass then return end
        local hiddenByBar = {}
        for specID, val in pairs(oldSettings) do
            if val == false then
                local slots = LEGACY_SPEC_BAR_SLOTS[specID]
                local barKey = slots and slots[slotIndex]
                if barKey then
                    if not hiddenByBar[barKey] then hiddenByBar[barKey] = {} end
                    hiddenByBar[barKey][specID] = true
                end
            end
        end
        for barKey, hiddenSpecs in pairs(hiddenByBar) do
            local classKey = (barKey == "Mana") and "General" or playerClass
            local entry = rbs[classKey] and rbs[classKey][barKey]
            if entry then
                entry.loadMode = "conditional"
                entry.load = entry.load or {}
                local spec = entry.load.spec or {}
                for sID, slots in pairs(LEGACY_SPEC_BAR_SLOTS) do
                    if slots[slotIndex] == barKey then
                        spec[sID] = true
                    end
                end
                for specID in pairs(hiddenSpecs) do
                    spec[specID] = nil
                end
                entry.load.spec = spec
            end
        end
    end

    ApplyVisibilityMigration("resourcesPrimaryResourceSettings", 1)
    ApplyVisibilityMigration("resourcesSecondaryResourceSettings", 2)

    for _, key in ipairs(LEGACY_RESOURCE_KEYS) do
        profile[key] = nil
    end
end

local function HasFlatResourceBarSettings(profile)
    local rbs = rawget(profile, "resourceBarSettings")
    if type(rbs) ~= "table" then return false end
    for key in pairs(rbs) do
        if RESOURCE_BAR_NAME_LOOKUP[key] then
            return true
        end
    end
    return false
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
    {
        version = 9,
        run = MigrateToPerBarResources,
    },
    {
        version = 10,
        run = RunResourceKeyMigrationCleanup,
    },
    {
        version = 11,
        run = function(profile)
            local legacy = rawget(profile, "resourcesUnifiedBorder")
            if legacy == nil then return end
            local _, playerClass = UnitClass("player")
            if playerClass then
                profile.resourceGroupSettings = profile.resourceGroupSettings or {}
                profile.resourceGroupSettings[playerClass] = profile.resourceGroupSettings[playerClass] or {}
                if profile.resourceGroupSettings[playerClass].unifiedBorder == nil then
                    profile.resourceGroupSettings[playerClass].unifiedBorder = legacy
                end
            end
            profile.resourcesUnifiedBorder = nil
        end,
    },
    {
        version = 12,
        run = function(profile)
            local rbs = profile.resourceBarSettings
            if type(rbs) ~= "table" then return end
            for _, classEntries in pairs(rbs) do
                if type(classEntries) == "table" then
                    for barKey, entry in pairs(classEntries) do
                        local parent = SECOND_BAR_PARENT[barKey]
                        if parent and type(entry) == "table" and entry.anchorTo == nil then
                            entry.anchorTo = parent
                        end
                    end
                end
            end
        end,
    },
    {
        version = 13,
        run = function(profile)
            local needsRebuild = HasFlatResourceBarSettings(profile)
            if not needsRebuild then
                for _, key in ipairs(LEGACY_RESOURCE_KEYS) do
                    if rawget(profile, key) ~= nil then
                        needsRebuild = true
                        break
                    end
                end
            end
            if not needsRebuild then return end

            profile.resourceBarSettings = nil
            MigrateToPerBarResources(profile)
            RunResourceKeyMigrationCleanup(profile)
        end,
    },
    {
        version = 14,
        run = function(profile)
            local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
            if not LSM then return end
            local name = rawget(profile, "textFont")
            if name ~= nil and not LSM:IsValid("font", name) then
                profile.textFont = nil
            end
        end,
    },
    {
        version = 15,
        run = function(profile)
            if profile.castBarAnchorToResources == nil
               and profile.castBarResourcesSpacing == nil
               and profile.castBarContainerLocked == nil then
                return
            end
            if profile.castBarAnchorToResources ~= false then
                profile.castBarAnchor       = "resources"
                profile.castBarAnchorPoint  = "BOTTOM"
                profile.castBarTargetPoint  = "TOP"
                profile.castBarOffsetX      = 0
                profile.castBarOffsetY      = profile.castBarResourcesSpacing or 1
            else
                profile.castBarAnchor       = "screen"
                profile.castBarAnchorPoint  = "BOTTOM"
                profile.castBarTargetPoint  = "CENTER"
                profile.castBarOffsetX      = profile.castBarOffsetX or 0
                profile.castBarOffsetY      = profile.castBarOffsetY or -166
            end
            profile.castBarPreviewEnabled = false
            profile.castBarAnchorToResources = nil
            profile.castBarResourcesSpacing  = nil
            profile.castBarContainerLocked   = nil
        end,
    },
    {
        version = 16,
        run = function(profile)
            local rbs = profile.resourceBarSettings
            local mana = rbs and rbs.General and rbs.General.Mana
            if type(mana) ~= "table" then return end
            mana.load = mana.load or {}
            mana.load.hideInFeralForm = true
        end,
    },
    {
        version = 19,
        run = function(profile)
            local rbs = profile.resourceBarSettings
            if type(rbs) ~= "table" then return end
            local mana = rbs.General and rbs.General.Mana

            local manaAvailable = false
            if type(mana) == "table" and mana.enabled ~= false then
                if mana.loadMode == "always" then
                    manaAvailable = true
                elseif mana.loadMode ~= "never" then
                    local loadSpec = mana.load and mana.load.spec
                    if type(loadSpec) == "table" then
                        for _, v in pairs(loadSpec) do
                            if v == true then manaAvailable = true break end
                        end
                    end
                end
            end

            local manaX = (mana and mana.offsetX) or 0
            local manaY = (mana and mana.offsetY) or -200

            local BARS_TO_FLIP = {
                Essence = true, LunarPower = true,
                SoulShards = true, ArcaneCharges = true, Maelstrom = true,
                MaelstromWeapon = true, Insanity = true, HolyPower = true,
            }
            local DRUID_ONLY_FLIP = { Rage = true, Energy = true }

            for classKey, classEntries in pairs(rbs) do
                if type(classEntries) == "table" then
                    for barKey, entry in pairs(classEntries) do
                        local shouldFlip = BARS_TO_FLIP[barKey]
                                       or (classKey == "DRUID" and DRUID_ONLY_FLIP[barKey])
                        if shouldFlip and type(entry) == "table"
                           and entry.anchorTo == nil then
                            if manaAvailable
                               and (entry.offsetX or 0) == manaX
                               and (entry.offsetY or -200) == manaY then
                                entry.anchorTo = "Mana"
                                entry.offsetY = 1
                            else
                                entry.anchorTo = "screen"
                            end
                        end
                    end
                end
            end
        end,
    },
    {
        version = 20,
        run = function(profile)
            local rbs = profile.resourceBarSettings
            if type(rbs) ~= "table" then return end
            for classKey, classEntries in pairs(rbs) do
                if type(classEntries) == "table" and classKey ~= "DRUID" then
                    for _, barKey in ipairs({ "Rage", "Energy" }) do
                        local entry = classEntries[barKey]
                        if type(entry) == "table" and entry.anchorTo == "Mana" then
                            entry.anchorTo = nil
                            if entry.offsetY == 1 then
                                entry.offsetY = nil
                            end
                        end
                    end
                end
            end
        end,
    },
    {
        version = 21,
        run = function(profile)
            local rgs = profile.resourceGroupSettings
            if type(rgs) ~= "table" then return end
            local anyUnified = false
            for classKey, entry in pairs(rgs) do
                if type(entry) == "table" then
                    if entry.unifiedBorder == true then
                        anyUnified = true
                    end
                    entry.unifiedBorder = nil
                    if next(entry) == nil then
                        rgs[classKey] = nil
                    end
                end
            end
            if anyUnified then
                profile.unifiedBorder = true
            end
        end,
    },
    {
        version = 22,
        run = function(profile)
            local function copyIfMissing(srcKey, dstKey)
                local src = rawget(profile, srcKey)
                if src == nil then return end
                if rawget(profile, dstKey) ~= nil then return end
                if type(src) == "table" then
                    profile[dstKey] = { r = src.r, g = src.g, b = src.b, a = src.a }
                else
                    profile[dstKey] = src
                end
            end
            for _, key in ipairs({ "chargeColor", "chargePosition", "chargeOffsetX", "chargeOffsetY" }) do
                copyIfMissing(key, "utility" .. key:sub(1, 1):upper() .. key:sub(2))
            end
            copyIfMissing("chargeFontSize",  "essRow2ChargeFontSize")
            copyIfMissing("chargeColor",     "essRow2ChargeColor")
            copyIfMissing("chargePosition",  "essRow2ChargePosition")
            copyIfMissing("chargeOffsetX",   "essRow2ChargeOffsetX")
            copyIfMissing("chargeOffsetY",   "essRow2ChargeOffsetY")
        end,
    },
    {
        version = 23,
        run = function(profile)
            if rawget(profile, "textFontOutline") == "NONE" then
                profile.textFontOutline = ""
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
            if GetCVar("cooldownViewerEnabled") ~= "1" then
                SetCVar("cooldownViewerEnabled", 1)
                print("|cff00ccff[CDM]|r " .. L["Enabled Blizzard Cooldown Manager."])
            end
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
    if specID and CDM.MarkSpecDataDirty then
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

    CDM:Refresh()
end

function CDM:ApplyProfile(name, preparedProfileData, options)
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
    CDM.RunProfileAppliedHooks()

    if CDM.DisableBlizzardPlayerCastBar then
        CDM:DisableBlizzardPlayerCastBar()
    end

    QueueCanonicalProfileRefresh(options)
    return true
end

function CDM:SetProfile(name)
    local ok, err = self:ApplyProfile(name, nil, {
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
    return self:ApplyProfile(name, {}, {
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
    return self:ApplyProfile(self.activeProfileName, targetProfileData, {
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
            Ayije_CDMDB.profileKeys[charKey] = fallback
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
    return self:ApplyProfile(self.activeProfileName, {}, {
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
    local ok, err = self:ApplyProfile(targetProfile, nil, {
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

    local ok, err = self:ApplyProfile(profileName, profileData, {
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

local _, RESOURCE_PLAYER_CLASS = UnitClass("player")

local function ResolveBarClass(barKey)
    if barKey == "Mana" then return "General" end
    return RESOURCE_PLAYER_CLASS
end

function CDM:GetBarSettingForClass(classKey, barKey, settingKey)
    local bs = self.db and self.db.resourceBarSettings
    if bs and bs[classKey] and bs[classKey][barKey] then
        local val = bs[classKey][barKey][settingKey]
        if val ~= nil then return val end
    end
    local pc = CDM.RESOURCE_BAR_PER_CLASS_DEFAULTS
    if pc and pc[classKey] and pc[classKey][barKey] then
        local val = pc[classKey][barKey][settingKey]
        if val ~= nil then return val end
    end
    local ds = CDM.RESOURCE_BAR_DEFAULTS
    if ds and ds[barKey] then
        return ds[barKey][settingKey]
    end
    return nil
end

function CDM:SetBarSettingForClass(classKey, barKey, settingKey, value)
    if not self.db then return end
    if not self.db.resourceBarSettings then
        self.db.resourceBarSettings = {}
    end
    if not self.db.resourceBarSettings[classKey] then
        self.db.resourceBarSettings[classKey] = {}
    end
    if not self.db.resourceBarSettings[classKey][barKey] then
        self.db.resourceBarSettings[classKey][barKey] = {}
    end
    self.db.resourceBarSettings[classKey][barKey][settingKey] = value
    if settingKey == "color" or settingKey == "bgColor" or settingKey == "tagColor" or settingKey == "conditions" then
        CDM._conditionsVersion = (CDM._conditionsVersion or 0) + 1
    end
end

function CDM:GetBarSetting(barKey, settingKey)
    return self:GetBarSettingForClass(ResolveBarClass(barKey), barKey, settingKey)
end

function CDM:SetBarSetting(barKey, settingKey, value)
    self:SetBarSettingForClass(ResolveBarClass(barKey), barKey, settingKey, value)
end

local function RefreshBuffViewer()
    if CDM.RefreshSpecData then CDM:RefreshSpecData() end
    CDM.styleCacheVersion = (CDM.styleCacheVersion or 0) + 1
    local BUFF = CDM.CONST.VIEWERS and CDM.CONST.VIEWERS.BUFF
    local v = BUFF and _G[BUFF]
    if v then CDM:ForceReanchor(v) end
end

local function ResolveWithVariants(spellID)
    local base = CDM.NormalizeToBase and CDM.NormalizeToBase(spellID)
    if base == spellID then base = nil end
    local stable = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if stable == spellID or stable == base then stable = nil end
    return base, stable
end

local function EnsureRegistryStructure(specID)
    if not CDM.db then return nil end
    if not CDM.db.spellRegistry then
        CDM.db.spellRegistry = {}
    end
    if not CDM.db.spellRegistry[specID] then
        CDM.db.spellRegistry[specID] = { colors = {} }
    end
    return CDM.db.spellRegistry[specID]
end

function CDM:SaveSpell(specID, spellID, color)
    local registry = EnsureRegistryStructure(specID)
    if not registry then return end
    if color then
        registry.colors[spellID] = { r = color.r, g = color.g, b = color.b, a = color.a or 1 }
    end
    local base, stable = ResolveWithVariants(spellID)
    if base then registry.colors[base] = nil end
    if stable then registry.colors[stable] = nil end
    if self.MarkSpecDataDirty then self:MarkSpecDataDirty() end
    RefreshBuffViewer()
end

function CDM:ClearSpellBorderColor(specID, spellID)
    if not CDM.db or not CDM.db.spellRegistry then return end
    local registry = CDM.db.spellRegistry[specID]
    if not registry or not registry.colors then return end
    registry.colors[spellID] = nil
    local base, stable = ResolveWithVariants(spellID)
    if base then registry.colors[base] = nil end
    if stable then registry.colors[stable] = nil end
    CompactRegistrySpec(specID)
    if self.MarkSpecDataDirty then self:MarkSpecDataDirty() end
    RefreshBuffViewer()
end

function CDM:GetSpellBorderColor(specID, spellID)
    if not CDM.db or not CDM.db.spellRegistry then return nil end
    local reg = CDM.db.spellRegistry[specID]
    if not reg or not reg.colors then return nil end
    if reg.colors[spellID] then return reg.colors[spellID] end
    local base, stable = ResolveWithVariants(spellID)
    if base and reg.colors[base] then return reg.colors[base] end
    if stable and reg.colors[stable] then return reg.colors[stable] end
    return nil
end

function CDM:CompactRegistrySpec(specID)
    CompactRegistrySpec(specID)
end

local stableBaseCache = {}
local stableBaseCacheSize = 0
local MAX_STABLE_BASE_ENTRIES = 4096
local cooldownViewerDataReady = false

local function StoreStableBase(id, value)
    if stableBaseCache[id] == nil then
        stableBaseCacheSize = stableBaseCacheSize + 1
        if stableBaseCacheSize > MAX_STABLE_BASE_ENTRIES then
            table.wipe(stableBaseCache)
            stableBaseCacheSize = 1
        end
    end
    stableBaseCache[id] = value
end

if CDM.RegisterEvent then
    CDM:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED", function()
        cooldownViewerDataReady = true
        table.wipe(stableBaseCache)
        stableBaseCacheSize = 0
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
            StoreStableBase(spellID, false)
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
                        StoreStableBase(base, base)
                        if info.overrideSpellID then
                            StoreStableBase(info.overrideSpellID, base)
                        end
                        if info.linkedSpellIDs then
                            for _, lid in ipairs(info.linkedSpellIDs) do
                                StoreStableBase(lid, base)
                            end
                        end
                        return base
                    end
                end
            end
        end
    end

    if cooldownViewerDataReady then
        StoreStableBase(spellID, false)
    end
    return nil
end

function CDM:ResolveStableBase(spellID)
    return ResolveStableBase(spellID)
end

function CDM:ClearStableBaseCache()
    table.wipe(stableBaseCache)
    stableBaseCacheSize = 0
end

function CDM:GetSpellGlowEnabled(specID, spellID)
    if not CDM.db or not CDM.db.spellRegistry then return false end
    local reg = CDM.db.spellRegistry[specID]
    if not reg or not reg.glowEnabled then return false end
    if reg.glowEnabled[spellID] == true then return true end
    local base, stable = ResolveWithVariants(spellID)
    if base and reg.glowEnabled[base] == true then return true end
    if stable and reg.glowEnabled[stable] == true then return true end
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
    local reg = EnsureRegistryStructure(specID)
    if not reg then return end

    if not reg.glowEnabled then
        reg.glowEnabled = {}
    end

    reg.glowEnabled[spellID] = enabled and true or nil
    local base, stable = ResolveWithVariants(spellID)
    if base then reg.glowEnabled[base] = nil end
    if stable then reg.glowEnabled[stable] = nil end

    CompactRegistrySpec(specID)
    if self.MarkSpecDataDirty then self:MarkSpecDataDirty() end
    self:Refresh()
end

function CDM:GetSpellGlowColor(specID, spellID)
    if not CDM.db or not CDM.db.spellRegistry then return nil end
    local reg = CDM.db.spellRegistry[specID]
    if not reg or not reg.glowColors then return nil end
    if reg.glowColors[spellID] then return reg.glowColors[spellID] end
    local base, stable = ResolveWithVariants(spellID)
    if base and reg.glowColors[base] then return reg.glowColors[base] end
    if stable and reg.glowColors[stable] then return reg.glowColors[stable] end
    return nil
end

function CDM:SetSpellGlowColor(specID, spellID, color)
    local reg = EnsureRegistryStructure(specID)
    if not reg then return end

    if not reg.glowColors then
        reg.glowColors = {}
    end

    reg.glowColors[spellID] = color and { r = color.r, g = color.g, b = color.b } or nil
    local base, stable = ResolveWithVariants(spellID)
    if base then reg.glowColors[base] = nil end
    if stable then reg.glowColors[stable] = nil end

    CompactRegistrySpec(specID)
    if self.MarkSpecDataDirty then self:MarkSpecDataDirty() end
    self:Refresh()
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
                spellToGroup[spellID] = { groupIdx = groupIndex, storedID = spellID }
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
                        if info.overrideTooltipSpellID then
                            match = spellToGroup[info.overrideTooltipSpellID]
                        end
                        if not match and IsUsableSpellID(info.overrideSpellID) and info.overrideSpellID ~= info.spellID then
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
