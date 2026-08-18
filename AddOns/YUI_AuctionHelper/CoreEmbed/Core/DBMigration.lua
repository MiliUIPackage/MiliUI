local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local ADDON_NAME, YUI = ...
YUI = YUI or _G.YUI
if not YUI then return end

YUI.DB = YUI.DB or {}
local DB = YUI.DB

local SCHEMA_VERSION = 2
local MIGRATION_KEY = "legacyToV2"

local APPEARANCE_LEGACY_KEYS = {
    elvUI = "YUISkins",
    eqolUnitFrames = "YUISkins_EQoL",
    eqolPowerBorder = "YUISkins_EQoLPowerBorder",
    shadow = "YUISkins_Shadow",
    noise = "YUISkins_Noise",
    lightMode = "YUISkins_LightMode",
}

local YBAR_TELEPORTS_LEGACY_KEYS = {
    "hearthstoneMode",
    "customHearthstone",
}

local YBAR_SIZE_LEGACY_KEYS = {
    "fontSize",
    "iconSize",
    "iconSpacing",
}

local LEGACY_COMPONENT_KEY_MAP = {
    AuctionHelper = "AuctionHelper",
    ChatBar = "ChatBar",
    ElvUIAdapter = "ElvUIAdapter",
    NDuiAdapter = "NDuiAdapter",
    EQoLAdapter = "EQoLAdapter",
    AyijeCDMAdapter = "AyijeCDMAdapter",
    MasqueSupport = "MasqueSupport",
    YDamageMeter = "YDamageMeter",
    RaidOptimization = "RaidOptimization",
    SXMusic = "SXMusic",
    SyncFriendlyNameplates = "SyncFriendlyNameplates",
    GameMenuButtons = "GameMenuButtons",
    HideErrorMessages = "HideErrorMessages",
    LoginCheck = "LoginCheck",
    MapPos = "MapPosition",
    MapPosition = "MapPosition",
    MinimapCollection = "MinimapCollection",
    TabChat = "TabChat",
    TradeEnhancement = "TradeEnhancement",
}

local LEGACY_CONFIG_ALLOWLIST = {
    ChatBar_Config = {
        style = true,
        direction = true,
        reverse = true,
        width = true,
        height = true,
        spacing = true,
        autoHide = true,
        blockTexture = true,
        blockShadow = true,
        notifyPosition = true,
        maskWhisperName = true,
        iconOffsetX = true,
        iconOffsetY = true,
        font = true,
        locked = true,
        channels = true,
        pos = true,
    },
    MinimapCollection_Config = {
        iconSize = true,
        showOnMouseOver = true,
        expandMode = true,
        mainIconVisibility = true,
        panelPosition = true,
        panelBackground = true,
        spacingX = true,
        spacingY = true,
        mainIconSize = true,
        mainIconOffset = true,
    },
    ElvUIAdapter_Config = {
        disablePetFrame = true,
        tooltip_itemLevel = true,
        hideSellPrice = true,
        roleIcon = true,
    },
    EQoLAdapter_Config = {
        uiScale = true,
        enableScale = true,
        hideXPBar = true,
        hideRepBar = true,
        ufHealthTextSize = true,
        centerMinimapZoneText = true,
        worldMapScale = true,
        fixTopCenterWidget = true,
        topCenterOffsetY = true,
        enableQueueStatus = true,
        queueStatusSize = true,
        queueStatusAnchor = true,
        queueStatusOffsetX = true,
        queueStatusOffsetY = true,
        hideMinimapZoom = true,
        hideBlizzardRaidManager = true,
        enableShiftFocus = true,
        autoAdaptBelowMinimapWidget = true,
        adaptUFHeight = true,
    },
    LoginCheck_Config = {
        Welcome = true,
        CVar = true,
        DataVersion = true,
        LoadOutdatedAddOns = true,
        CheckAddonConflict = true,
        AutoMatchProfile = true,
        Installer = true,
        EditModeSwitch = true,
    },
    MasqueSupport_Config = {
        blizzardActionBars = true,
        blizzardAuras = true,
        ayijeCDM = true,
    },
    RaidOptimization_Config = {
        DisableElvUIPortrait = true,
    },
    SXMusic_Config = {
        builtin = true,
        custom = true,
        channel = true,
        customRows = true,
    },
    TradeEnhancement_Config = {
        tradeWhisper = true,
        autoBag = true,
        merchantFrame = true,
    },
}

local LEGACY_COMPONENT_TABLE_CONFIG_MAP = {
    ChatBar = "ChatBar_Config",
    MinimapCollection = "MinimapCollection_Config",
    ElvUIAdapter = "ElvUIAdapter_Config",
    EQoLAdapter = "EQoLAdapter_Config",
    LoginCheck = "LoginCheck_Config",
    MasqueSupport = "MasqueSupport_Config",
    RaidOptimization = "RaidOptimization_Config",
    SXMusic = "SXMusic_Config",
    TradeEnhancement = "TradeEnhancement_Config",
}

local LEGACY_YBOX_HANDLED_ELSEWHERE = {
    YUISkins = true,
    YUISkins_EQoL = true,
    YUISkins_EQoLPowerBorder = true,
    YUISkins_Shadow = true,
    YUISkins_Noise = true,
    YUISkins_LightMode = true,
    RoleIcon = true,
}

local function CopyValue(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local result = {}
    seen[value] = result
    for key, item in pairs(value) do
        result[CopyValue(key, seen)] = CopyValue(item, seen)
    end
    return result
end

local function EnsureTable(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

local function AddStats(stats, key, amount)
    stats[key] = (stats[key] or 0) + (amount or 1)
end

local function SetMissing(target, key, value, stats)
    if type(target) ~= "table" or key == nil or value == nil then
        return false
    end

    if target[key] == nil then
        target[key] = CopyValue(value)
        AddStats(stats, "fields")
        return true
    end

    if target[key] ~= value then
        AddStats(stats, "conflicts")
    end
    return false
end

local function CopyAllowedConfig(source, target, allowlist, stats)
    if type(source) ~= "table" or type(target) ~= "table" or type(allowlist) ~= "table" then
        return false
    end

    local copied = false
    for key, value in pairs(source) do
        if allowlist[key] then
            if SetMissing(target, key, value, stats) then
                copied = true
            end
        else
            AddStats(stats, "unmapped")
        end
    end
    return copied
end

local function MigrateLegacyComponents(profile, stats)
    local ybox = profile.YBox
    if type(ybox) ~= "table" then
        return
    end

    local components = EnsureTable(profile, "Components")
    local copied = 0
    for key, value in pairs(ybox) do
        local componentKey = LEGACY_COMPONENT_KEY_MAP[key]
        local configAllowlist = LEGACY_CONFIG_ALLOWLIST[key]

        if componentKey then
            if type(value) == "table" then
                local configKey = LEGACY_COMPONENT_TABLE_CONFIG_MAP[key]
                local allowlist = configKey and LEGACY_CONFIG_ALLOWLIST[configKey]
                if allowlist then
                    local target = EnsureTable(components, configKey)
                    if CopyAllowedConfig(value, target, allowlist, stats) then
                        copied = copied + 1
                    end
                end
            end
            if SetMissing(components, componentKey, type(value) == "table" or value == true, stats) then
                copied = copied + 1
            end
        elseif configAllowlist then
            local target = EnsureTable(components, key)
            if CopyAllowedConfig(value, target, configAllowlist, stats) then
                copied = copied + 1
            end
        elseif key == "RoleIcon" then
            local target = EnsureTable(components, "ElvUIAdapter_Config")
            if SetMissing(target, "roleIcon", value == true, stats) then
                copied = copied + 1
            end
        elseif not LEGACY_YBOX_HANDLED_ELSEWHERE[key] then
            AddStats(stats, "unmapped")
        end
    end

    profile.YBox = nil
    AddStats(stats, "profilesWithLegacy")
    AddStats(stats, "containers")
    if copied == 0 and (stats.unmapped or 0) == 0 then
        AddStats(stats, "conflicts")
    end
end

local function GetLegacyBoolean(profile, components, legacyKey)
    if type(components) == "table" and components[legacyKey] ~= nil then
        return components[legacyKey] == true, true
    end
    if type(profile.YBox) == "table" and profile.YBox[legacyKey] ~= nil then
        return profile.YBox[legacyKey] == true, true
    end
    if profile[legacyKey] ~= nil then
        return profile[legacyKey] == true, true
    end
    return nil, false
end

local function MigrateAppearance(profile, stats)
    local components = type(profile.Components) == "table" and profile.Components or nil
    local pendingSkins = {}
    local hasSkinLegacy = false

    for key, legacyKey in pairs(APPEARANCE_LEGACY_KEYS) do
        local value, found = GetLegacyBoolean(profile, components, legacyKey)
        if found then
            pendingSkins[key] = value
            hasSkinLegacy = true
        end
    end

    local hasDetailsSyncLegacy = profile.PluginSkins_DetailsSpecSync ~= nil
    if not hasSkinLegacy and not hasDetailsSyncLegacy then
        return
    end

    local appearance = EnsureTable(profile, "Appearance")
    if hasSkinLegacy then
        local skins = EnsureTable(appearance, "skins")
        for key, value in pairs(pendingSkins) do
            SetMissing(skins, key, value, stats)
        end
    end

    if profile.PluginSkins_DetailsSpecSync ~= nil then
        local scopes = EnsureTable(appearance, "classSpecIconScopes")
        SetMissing(scopes, "details_spec_sync", profile.PluginSkins_DetailsSpecSync == true, stats)
    end
end

local function MigrateYBar(profile, stats)
    local ybar = profile.YBar
    if type(ybar) ~= "table" then
        local hasLegacy = false
        if profile.YBar_Enable ~= nil then
            hasLegacy = true
        end
        for _, key in ipairs(YBAR_TELEPORTS_LEGACY_KEYS) do
            if profile[key] ~= nil then
                hasLegacy = true
                break
            end
        end
        if not hasLegacy then
            for _, key in ipairs(YBAR_SIZE_LEGACY_KEYS) do
                if profile[key] ~= nil then
                    hasLegacy = true
                    break
                end
            end
        end
        if not hasLegacy then
            return
        end
        ybar = EnsureTable(profile, "YBar")
    end

    if profile.YBar_Enable ~= nil then
        SetMissing(ybar, "enable", profile.YBar_Enable == true, stats)
    end

    local teleports = EnsureTable(ybar, "Teleports")
    local talents = EnsureTable(ybar, "Talents")

    for _, key in ipairs(YBAR_TELEPORTS_LEGACY_KEYS) do
        if profile[key] ~= nil then
            SetMissing(teleports, key, profile[key], stats)
        end
    end

    for _, key in ipairs(YBAR_SIZE_LEGACY_KEYS) do
        if profile[key] ~= nil then
            SetMissing(teleports, key, profile[key], stats)
            SetMissing(talents, key, profile[key], stats)
        end
    end
end

local function MigrateTradeEnhancement(profile, stats)
    if profile.TradeWhisper == nil and profile.TradeAutoBag == nil then
        return
    end

    local components = EnsureTable(profile, "Components")
    local config = EnsureTable(components, "TradeEnhancement_Config")
    if profile.TradeWhisper ~= nil then
        SetMissing(config, "tradeWhisper", profile.TradeWhisper == true, stats)
    end
    if profile.TradeAutoBag ~= nil then
        SetMissing(config, "autoBag", profile.TradeAutoBag == true, stats)
    end
end

function DB:NormalizeLegacyProfile(profile, stats)
    if type(profile) ~= "table" then
        return nil
    end

    stats = stats or {}
    AddStats(stats, "profiles")

    MigrateAppearance(profile, stats)
    MigrateYBar(profile, stats)
    MigrateTradeEnhancement(profile, stats)
    MigrateLegacyComponents(profile, stats)

    return stats
end

local function ResolveSavedVariables(db, savedVariableName)
    if type(db) == "table" and type(db.sv) == "table" then
        return db.sv
    end
    if savedVariableName and _G and type(_G[savedVariableName]) == "table" then
        return _G[savedVariableName]
    end
    return nil
end

local function GetLocaleText(key, fallback, ...)
    local text = fallback
    if YUI.Locale and YUI.Locale.Get then
        local locale = YUI.Locale:Get("Core")
        if type(locale) == "table" and locale[key] then
            text = locale[key]
        end
    end

    if select("#", ...) > 0 then
        return string.format(text, ...)
    end
    return text
end

local function PrintMigration(key, fallback, ...)
    if YUI.Print then
        YUI:Print(GetLocaleText(key, fallback, ...))
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffYUI|r " .. GetLocaleText(key, fallback, ...))
    elseif print then
        print("YUI " .. GetLocaleText(key, fallback, ...))
    end
end

function DB:MigrateSavedVariablesToV2(db, savedVariableName)
    local sv = ResolveSavedVariables(db, savedVariableName)
    if type(sv) ~= "table" then
        return nil
    end

    if type(sv.global) ~= "table" then
        sv.global = {}
    end
    local global = sv.global
    if type(global._yuiMigrations) ~= "table" then
        global._yuiMigrations = {}
    end

    if global._yuiDBSchemaVersion == SCHEMA_VERSION and global._yuiMigrations[MIGRATION_KEY] == true then
        return {
            skipped = true,
            schema = SCHEMA_VERSION,
        }
    end

    local stats = {
        profiles = 0,
        fields = 0,
        containers = 0,
        conflicts = 0,
        profilesWithLegacy = 0,
        unmapped = 0,
    }

    if type(sv.profiles) == "table" then
        for _, profile in pairs(sv.profiles) do
            self:NormalizeLegacyProfile(profile, stats)
        end
    end

    global._yuiDBSchemaVersion = SCHEMA_VERSION
    global._yuiMigrations[MIGRATION_KEY] = true

    if stats.fields > 0 or stats.containers > 0 then
        PrintMigration("db.migration.legacy_v2.start", "检测到旧版本 YUI 配置，正在迁移。")
        PrintMigration("db.migration.legacy_v2.done", "旧版本 YUI 配置迁移完成：%d 个配置文件，%d 个设置项。", stats.profiles, stats.fields)
        if stats.conflicts > 0 or stats.unmapped > 0 then
            PrintMigration("db.migration.legacy_v2.partial", "部分旧设置可能无法完全复原。")
        end
    end

    stats.schema = SCHEMA_VERSION
    return stats
end

function DB:NormalizeImportedProfile(data, sourcePrefix)
    if type(data) ~= "table" then
        return nil, {
            error = "invalid_data",
        }
    end

    local isLegacy = sourcePrefix == "!YUI:"
    local profile = data
    if sourcePrefix == "!YUI-v2:" then
        if type(data.profile) ~= "table" then
            return nil, {
                error = "invalid_profile",
            }
        end
        profile = data.profile
    elseif type(data.profile) == "table" and data.schema == SCHEMA_VERSION then
        profile = data.profile
    end

    local stats = {}
    if isLegacy or type(profile.YBox) == "table" then
        self:NormalizeLegacyProfile(profile, stats)
    end

    return profile, {
        legacy = isLegacy,
        schema = SCHEMA_VERSION,
        stats = stats,
    }
end
