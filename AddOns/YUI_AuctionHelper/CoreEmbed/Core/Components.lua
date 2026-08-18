local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local ADDON_NAME, YUI = ...
YUI = YUI or _G.YUI
if not YUI then return end

local Components = YUI.Components or {}
YUI.Components = Components
YUI.YBox = Components -- Legacy runtime API alias.

Components.registry = Components.registry or {}
Components.order = Components.order or {}
Components.features = Components.features or {}
Components.initializedFeatures = Components.initializedFeatures or {}
Components.initializedFeatureStates = Components.initializedFeatureStates or {}
Components.initializedFeatureErrors = Components.initializedFeatureErrors or {}

Components.TAGS = Components.TAGS or {
    "全部",
    "实用功能",
    "交易社交",
    "插件适配",
    "美化皮肤",
    "战斗辅助",
    "系统修正",
}

local FEATURE_META = {
    SXMusic = { tags = { "战斗辅助" }, settingsMode = "inline", order = 100, sourceRoot = "Components\\SXMusic", assetFolders = { "Components\\SXMusic\\Media" }, modSwitchImage = "modswitch\\sxmusic-bg.png", modSwitchImageCrop = false },
    MythicPlusTools = { tags = { "战斗辅助" }, settingsMode = "inline", order = 101, sourceRoot = "Components\\MythicPlusTools", modSwitchImage = "modswitch\\mythicplustools-bg.png", modSwitchImageCrop = false },
    FocusHelper = { tags = { "战斗辅助" }, settingsMode = "inline", default = false, order = 102, sourceRoot = "Components\\FocusHelper", versions = { "mainline", "mists", "wrath" }, modSwitchImage = "modswitch\\focushelper-bg.png", modSwitchImageCrop = false },
    ClassExtraMonitor = { tags = { "战斗辅助" }, settingsMode = "inline", default = false, order = 103, sourceRoot = "Components\\ClassExtraMonitor", versions = { "mainline" }, modSwitchImage = "modswitch\\classextramonitor-bg.png", modSwitchImageCrop = false },

    LagTolerance = { tags = { "战斗辅助" }, settingsMode = "inline", default = false, order = 200, sourceRoot = "Components\\LagTolerance", modSwitchImage = "modswitch\\lagtolerance-bg.png", modSwitchImageCrop = false },
    CombatCue = { tags = { "战斗辅助" }, settingsMode = "inline", order = 201, sourceRoot = "Components\\CombatCue", assetFolders = { "Components\\CombatCue\\Media" }, modSwitchImage = "modswitch\\combatcue-bg.png", modSwitchImageCrop = false },
    CombatEnhancement = { tags = { "战斗辅助" }, settingsMode = "inline", default = false, order = 202, sourceRoot = "Components\\CombatEnhancement", assetFolders = { "Components\\CombatEnhancement\\Media" }, versions = { "mainline", "wrath" }, modSwitchImage = "modswitch\\combatenhancement-bg.png", modSwitchImageCrop = false },
    TabChat = { tags = { "交易社交" }, settingsMode = "toggleOnly", order = 203, sourceRoot = "Components\\TabChat", modSwitchImage = "modswitch\\tabchat-bg.png", modSwitchImageCrop = false },

    GameMenuButtons = { tags = { "实用功能" }, settingsMode = "toggleOnly", order = 300, sourceRoot = "Components\\GameMenuButtons", modSwitchImage = "modswitch\\gamemenubuttons-bg.png", modSwitchImageCrop = false },
    LoginCheck = { tags = { "实用功能" }, settingsMode = "inline", order = 301, sourceRoot = "Components\\LoginCheck", modSwitchImage = "modswitch\\logincheck-bg.png", modSwitchImageCrop = false },
    MinimapCollection = { tags = { "实用功能", "美化皮肤" }, settingsMode = "inline", order = 302, sourceRoot = "Components\\MinimapCollection", modSwitchImage = "modswitch\\minimapcollection-bg.png", modSwitchImageCrop = false },
    MapPosition = { tags = { "实用功能" }, settingsMode = "toggleOnly", order = 303, sourceRoot = "Components\\MapPosition", modSwitchImage = "modswitch\\mapposition-bg.png", modSwitchImageCrop = false },
    TradeEnhancement = { tags = { "实用功能" }, settingsMode = "inline", order = 304, sourceRoot = "Components\\TradeEnhancement", modSwitchImage = "modswitch\\tradeenhancement-bg.png", modSwitchImageCrop = false },

    AuctionHelper = { tags = { "交易社交" }, settingsMode = "toggleOnly", standalone = true, order = 400, sourceRoot = "Components\\AuctionHelper", modSwitchImage = "modswitch\\auctionhelper-bg.png", modSwitchImageCrop = false },
    ChatBar = { tags = { "交易社交" }, settingsMode = "inline", order = 401, sourceRoot = "Components\\ChatBar", modSwitchImage = "modswitch\\chatbar-bg.png", modSwitchImageCrop = false },
    WhisperManager = { tags = { "交易社交" }, settingsMode = "inline", order = 402, sourceRoot = "Components\\WhisperManager", modSwitchImage = "modswitch\\whispermanager-bg.png", modSwitchImageCrop = false },
    WhisperColor = { tags = { "交易社交" }, settingsMode = "toggleOnly", order = 403, sourceRoot = "Components\\WhisperColor", modSwitchImage = "modswitch\\whispercolor-bg.png", modSwitchImageCrop = false },

    ElvUIAdapter = { tags = { "插件适配", "美化皮肤" }, settingsMode = "inline", order = 500, sourceRoot = "Components\\ElvUIAdapter", modSwitchImage = "modswitch\\elvuiadapter-bg.png", modSwitchImageCrop = false },
    NDuiAdapter = { tags = { "插件适配", "美化皮肤" }, settingsMode = "toggleOnly", order = 501, sourceRoot = "Components\\NDuiAdapter", modSwitchImage = "modswitch\\nduiadapter-bg.png", modSwitchImageCrop = false },
    EQoLAdapter = { tags = { "插件适配" }, settingsMode = "inline", order = 502, sourceRoot = "Components\\EQoLAdapter", modSwitchImage = "modswitch\\eqoladapter-bg.png", modSwitchImageCrop = false },
    AyijeCDMAdapter = { tags = { "插件适配" }, settingsMode = "toggleOnly", order = 503, sourceRoot = "Components\\AyijeCDMAdapter", modSwitchImage = "modswitch\\ayijecdmadapter-bg.png", modSwitchImageCrop = false },
    MasqueSupport = { tags = { "美化皮肤", "插件适配" }, settingsMode = "inline", order = 504, sourceRoot = "Components\\MasqueSupport", modSwitchImage = "modswitch\\masquesupport-bg.png", modSwitchImageCrop = false },
    TalentFrameEnhancement = { tags = { "实用功能" }, settingsMode = "toggleOnly", default = true, order = 505, sourceRoot = "Components\\TalentFrameEnhancement", modSwitchImage = "modswitch\\talentframeenhancement-bg.png", modSwitchImageCrop = false },

    HideErrorMessages = { tags = { "实用功能" }, settingsMode = "toggleOnly", order = 600, sourceRoot = "Components\\HideErrorMessages", modSwitchImage = "modswitch\\hideerrormessages-bg.png", modSwitchImageCrop = false },
    FixWrathKeyDown = { tags = { "系统修正" }, settingsMode = "toggleOnly", order = 601, sourceRoot = "Components\\FixWrathKeyDown", modSwitchImage = "modswitch\\fixwrathkeydown-bg.png", modSwitchImageCrop = false },
    ForbiddenNamePlates = { tags = { "插件适配" }, settingsMode = "toggleOnly", order = 602, sourceRoot = "Components\\ForbiddenNamePlates", modSwitchImage = "modswitch\\forbiddennameplates-bg.png", modSwitchImageCrop = false },
    SyncFriendlyNameplates = { tags = { "系统修正" }, settingsMode = "toggleOnly", order = 603, sourceRoot = "Components\\SyncFriendlyNameplates", modSwitchImage = "modswitch\\syncfriendlynameplates-bg.png", modSwitchImageCrop = false },

    RaidOptimization = { tags = { "战斗辅助" }, settingsMode = "toggleOnly", order = 701, sourceRoot = "Components\\RaidOptimization", modSwitchImage = "modswitch\\raidoptimization-bg.png", modSwitchImageCrop = false },
    YDamageMeter = { tags = { "美化皮肤", "战斗辅助" }, settingsMode = "inline", order = 702, sourceRoot = "Components\\YDamageMeter", modSwitchImage = "modswitch\\ydamagemeter-bg.png", modSwitchImageCrop = false },
}


local function CopyArray(value, fallback)
    local result = {}
    if type(value) == "table" then
        for _, item in ipairs(value) do
            if item ~= nil then
                result[#result + 1] = item
            end
        end
    end
    if #result == 0 and fallback then
        for _, item in ipairs(fallback) do
            result[#result + 1] = item
        end
    end
    return result
end

local function HasTag(component, tag)
    if tag == nil or tag == "" or tag == "全部" then
        return true
    end
    for _, item in ipairs(component.tags or {}) do
        if item == tag then
            return true
        end
    end
    return false
end

local function SortComponents(a, b)
    local orderA = a.order or 9999
    local orderB = b.order or 9999
    if orderA ~= orderB then
        return orderA < orderB
    end
    local nameA = a.displayName or a.name or a.id or ""
    local nameB = b.displayName or b.name or b.id or ""
    if nameA ~= nameB then
        return nameA < nameB
    end
    return (a.id or "") < (b.id or "")
end

local function Normalize(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
        return nil
    end

    def.displayName = def.displayName or def.name or def.id
    def.name = def.name or def.displayName
    def.description = def.description or ""
    def.tags = CopyArray(def.tags, {"实用功能"})
    def.settingsMode = def.settingsMode or (def.GetOptions and "inline" or "toggleOnly")
    def.kind = def.kind or "component"
    def.storageKey = def.storageKey or def.id
    def.isBeta = def.isBeta == true
    return def
end

function Components:Register(def)
    def = Normalize(def)
    if not def then
        return nil
    end

    local existing = self.registry[def.id]
    self.registry[def.id] = def
    if not existing then
        self.order[#self.order + 1] = def.id
    end
    return def
end

function Components:Get(id)
    return self.registry[id]
end

function Components:GetAll(tag)
    local items = {}
    for _, id in ipairs(self.order) do
        local component = self.registry[id]
        if component and HasTag(component, tag) then
            items[#items + 1] = component
        end
    end
    table.sort(items, SortComponents)
    return items
end

function Components:GetTags()
    return self.TAGS
end

function Components:IsEnabled(component)
    if type(component) == "string" then
        component = self.registry[component]
    end
    if not component then
        return false
    end
    if type(component.getEnabled) == "function" then
        local ok, enabled = pcall(component.getEnabled, component)
        if ok then
            return enabled == true
        end
        return false
    end
    return component.defaultEnabled ~= false
end

function Components:SetEnabled(component, enabled)
    if type(component) == "string" then
        component = self.registry[component]
    end
    if not component then
        return false
    end
    enabled = enabled == true
    if type(component.setEnabled) == "function" then
        local ok = pcall(component.setEnabled, component, enabled)
        return ok == true
    end
    component.defaultEnabled = enabled
    return true
end

local function NormalizeEffectiveState(value, reason, tone)
    if type(value) == "table" then
        if value.effective == false then
            return {
                effective = false,
                reason = value.reason or value.message or reason or "该组件当前未生效。",
                tone = value.tone or tone or "warning",
            }
        end
        return {
            effective = true,
            reason = value.reason or value.message,
            tone = value.tone or tone,
        }
    end

    if value == false then
        return {
            effective = false,
            reason = reason or "该组件当前未生效。",
            tone = tone or "warning",
        }
    end

    return { effective = true }
end

function Components:GetEffectiveState(component)
    if type(component) == "string" then
        component = self.registry[component]
    end
    if not component then
        return { effective = false, reason = "组件不存在。", tone = "danger" }
    end

    local feature = component.feature or component
    local resolver = component.getEffectiveState or component.GetEffectiveState
    if type(resolver) ~= "function" and type(feature) == "table" then
        resolver = feature.getEffectiveState or feature.GetEffectiveState
    end
    if type(resolver) ~= "function" then
        return { effective = true }
    end

    local ok, value, reason, tone = pcall(resolver, feature, component)
    if not ok then
        return {
            effective = false,
            reason = "组件状态检查失败：" .. tostring(value),
            tone = "danger",
        }
    end

    return NormalizeEffectiveState(value, reason, tone)
end

local function MergeMissing(target, source)
    if type(target) ~= "table" or type(source) ~= "table" or target == source then
        return
    end
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

local function CopyDefaultValue(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, item in pairs(value) do
        result[key] = CopyDefaultValue(item)
    end
    return result
end

local function FillDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then
        return target
    end

    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = CopyDefaultValue(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            FillDefaults(target[key], value)
        end
    end
    return target
end

local function EnsureStore(productId)
    local profile
    if YUI.DB and YUI.DB.GetProfile then
        profile = YUI.DB:GetProfile(productId or YUI.ProductId or "suite")
    end

    if type(profile) ~= "table" then
        return nil
    end

    local store = profile.Components
    if type(store) ~= "table" then
        store = {}
        profile.Components = store
    end

    local legacyStore = profile.YBox
    if legacyStore ~= nil then
        if type(legacyStore) == "table" then
            MergeMissing(store, legacyStore)
        end
        profile.YBox = nil
    end

    return store
end

function Components:GetStore(productId)
    return EnsureStore(productId or YUI.ProductId or "suite")
end

function Components:EnsureConfig(configKey, defaults, productId)
    if type(configKey) ~= "string" or configKey == "" then
        return nil
    end

    local store = self:GetStore(productId)
    if not store then
        return nil
    end

    if type(store[configKey]) ~= "table" then
        store[configKey] = {}
    end

    return FillDefaults(store[configKey], defaults), store
end

function Components:GetStoreValue(key, default, productId)
    if type(key) ~= "string" or key == "" then
        return default
    end

    local store = self:GetStore(productId)
    if store and store[key] ~= nil then
        return store[key]
    end
    return default
end

function Components:SetStoreValue(key, value, productId)
    if type(key) ~= "string" or key == "" then
        return false
    end

    local store = self:GetStore(productId)
    if not store then
        return false
    end

    store[key] = value
    return true
end

local function GetFeatureEnabled(key, feature)
    local store = EnsureStore(feature and feature.product)
    if store and store[key] ~= nil then
        return store[key] == true
    end
    return feature and feature.default == true
end

local function InitializeFeature(key, feature)
    if not key or not feature then
        return false
    end

    local store = EnsureStore(feature and feature.product)
    if not store then
        return false
    end

    local isEnabled = store[key]
    if isEnabled == nil then
        isEnabled = feature.default == true
        store[key] = isEnabled
    else
        isEnabled = isEnabled == true
    end

    if Components.initializedFeatures[key] and Components.initializedFeatureStates[key] == isEnabled then
        return false
    end

    if feature.callback then
        local traceRecord
        if YUI.Trace and YUI.Trace.Begin then
            traceRecord = YUI.Trace:Begin("Modules", "Component:" .. tostring(key), isEnabled and "enabled" or "disabled", {
                moduleId = "component:" .. tostring(key),
                phase = isEnabled and "enabled" or "disabled",
                durationKind = "sync",
                blocking = true,
            })
        end
        local success, err = pcall(feature.callback, isEnabled)
        if traceRecord and YUI.Trace and YUI.Trace.Finish then
            YUI.Trace:Finish(traceRecord, success and "ok" or "error", success and nil or err)
        end
        if not success then
            Components.initializedFeatureErrors[key] = tostring(err)
            print("|cffff0000YUI Component Error:|r Feature '" .. (feature.name or key) .. "' failed: " .. tostring(err))
            return false
        end
    end

    Components.initializedFeatures[key] = true
    Components.initializedFeatureStates[key] = isEnabled
    Components.initializedFeatureErrors[key] = nil
    return true
end

local function RegisterComponentBridge(key, feature)
    if not Components.Register then
        return
    end

    local meta = FEATURE_META[key] or {}
    local settingsMode = feature.settingsMode or meta.settingsMode
    if not settingsMode then
        settingsMode = feature.GetOptions and "inline" or "toggleOnly"
    end
    local modSwitchImageCrop = feature.modSwitchImageCrop
    if modSwitchImageCrop == nil then
        modSwitchImageCrop = meta.modSwitchImageCrop
    end
    local isBeta = feature.isBeta
    if isBeta == nil then
        isBeta = meta.isBeta
    end

    Components:Register({
        id = key,
        kind = "component",
        displayName = feature.name or key,
        description = feature.description or "",
        tags = CopyArray(feature.tags or meta.tags, { Components.TAGS[2] }),
        settingsMode = settingsMode,
        standalone = feature.standalone ~= nil and feature.standalone or meta.standalone,
        product = feature.product or meta.product or YUI.ProductId or "suite",
        order = meta.order or feature.order,
        storageKey = feature.storageKey or key,
        sourceRoot = feature.sourceRoot or meta.sourceRoot,
        versions = feature.versions or feature.version or meta.versions,
        mediaBundles = CopyArray(feature.mediaBundles or meta.mediaBundles),
        assetFolders = CopyArray(feature.assetFolders or meta.assetFolders),
        modSwitchImage = feature.modSwitchImage or meta.modSwitchImage,
        modSwitchImageCrop = modSwitchImageCrop,
        modSwitchImageTexCoords = feature.modSwitchImageTexCoords or meta.modSwitchImageTexCoords,
        modSwitchImageInset = feature.modSwitchImageInset or meta.modSwitchImageInset,
        isBeta = isBeta == true,
        feature = feature,
        GetOptions = feature.GetOptions,
        getEnabled = function()
            return GetFeatureEnabled(key, feature)
        end,
        setEnabled = function(_, enabled)
            return Components:SetFeatureEnabled(key, enabled)
        end,
        openSettings = function()
            if not YUI.Settings then return end
            if YUI.Settings.OpenComponentFeature then
                YUI.Settings:OpenComponentFeature(key)
            elseif YUI.Settings.OpenYBoxFeature then
                YUI.Settings:OpenYBoxFeature(key)
            end
        end,
    })
end

function Components:RegisterFeature(key, options)
    if type(key) ~= "string" or key == "" or type(options) ~= "table" then
        return nil
    end

    if YUI.Debug then
        YUI:Debug(string.format("Components | RegisterFeature | %s | %s", key, options.name or key))
    end
    if self.features[key] then
        local existing = self.features[key]
        if self._featuresInitialized then
            InitializeFeature(key, existing)
        end
        return existing
    end

    if options.default == nil then
        options.default = false
    end
    options.id = options.id or key
    options.storageKey = options.storageKey or key

    local meta = FEATURE_META[key]
    if meta then
        options.tags = options.tags or CopyArray(meta.tags)
        options.settingsMode = options.settingsMode or meta.settingsMode
        options.standalone = options.standalone ~= nil and options.standalone or meta.standalone
        options.product = options.product or meta.product or YUI.ProductId or "suite"
        options.order = meta.order or options.order
        options.sourceRoot = options.sourceRoot or meta.sourceRoot
        options.versions = options.versions or meta.versions
        options.mediaBundles = options.mediaBundles or CopyArray(meta.mediaBundles)
        options.assetFolders = options.assetFolders or CopyArray(meta.assetFolders)
        options.modSwitchImage = options.modSwitchImage or meta.modSwitchImage
        if options.modSwitchImageCrop == nil then
            options.modSwitchImageCrop = meta.modSwitchImageCrop
        end
        options.modSwitchImageTexCoords = options.modSwitchImageTexCoords or meta.modSwitchImageTexCoords
        options.modSwitchImageInset = options.modSwitchImageInset or meta.modSwitchImageInset
        if options.isBeta == nil then
            options.isBeta = meta.isBeta == true
        end
    end

    self.features[key] = options
    RegisterComponentBridge(key, options)
    if self._featuresInitialized then
        InitializeFeature(key, options)
    end
    return options
end

function Components:InitializeFeatures()
    local traceRecord
    if YUI.Trace and YUI.Trace.Begin then
        traceRecord = YUI.Trace:Begin("Login", "Components:InitializeFeatures", nil, {
            moduleId = "YUI.Components",
            phase = "InitializeFeatures",
            durationKind = "sync",
            blocking = true,
        })
    end

    self._featuresInitialized = true

    for key, feature in pairs(self.features) do
        InitializeFeature(key, feature)
    end

    if traceRecord and YUI.Trace and YUI.Trace.Finish then
        YUI.Trace:Finish(traceRecord, "ok")
    end
end

function Components:Initialize()
    return self:InitializeFeatures()
end

function Components:SetFeatureEnabled(key, enable)
    local feature = self.features[key]
    if not feature then
        return false
    end

    enable = enable == true
    if YUI.Debug then
        YUI:Debug(string.format("Components | SetFeatureEnabled | %s | %s", key, enable and "enabled" or "disabled"))
    end

    local store = EnsureStore(feature and feature.product)
    if store then
        store[key] = enable
    end

    if feature.callback then
        local success, err = pcall(feature.callback, enable)
        if not success then
            self.initializedFeatureErrors[key] = tostring(err)
            print("|cffff0000YUI Component Error:|r Feature '" .. (feature.name or key) .. "' failed: " .. tostring(err))
        else
            self.initializedFeatures[key] = true
            self.initializedFeatureStates[key] = enable
            self.initializedFeatureErrors[key] = nil
        end
    else
        self.initializedFeatures[key] = true
        self.initializedFeatureStates[key] = enable
        self.initializedFeatureErrors[key] = nil
    end

    if feature.requiresReload and YUI.Settings and YUI.Settings.ShowReload then
        YUI.Settings:ShowReload()
    end
    return true
end

if YUI.Event then
    YUI.Event:On("YUI_DB_READY", function()
        if YUI.Trace and YUI.Trace.Measure then
            YUI.Trace:Measure("Framework", "Components store", function()
                EnsureStore(YUI.ProductId or "suite")
            end, nil, {
                moduleId = "YUI.Components",
                phase = "EnsureStore",
            })
        else
            EnsureStore(YUI.ProductId or "suite")
        end
    end, Components, {
        priority = 8000,
        traceName = "Components:EnsureStore",
        moduleId = "YUI.Components",
        phase = "YUI_DB_READY",
    })

    YUI.Event:Once("YUI_LOGIN_READY", function()
        Components:InitializeFeatures()
    end, Components, {
        priority = -100,
        traceName = "Components:InitializeFeatures(login)",
        moduleId = "YUI.Components",
        phase = "YUI_LOGIN_READY",
    })

    YUI.Event:Once("YUI_WORLD_READY", function()
        Components:InitializeFeatures()
    end, Components, {
        priority = -100,
        traceName = "Components:InitializeFeatures(world)",
        moduleId = "YUI.Components",
        phase = "YUI_WORLD_READY",
    })
end
