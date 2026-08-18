local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local ADDON_NAME, YUI = ...
local bootstrapState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[ADDON_NAME]

YUI.AddonName = ADDON_NAME
YUI.CoreVersion = YUI.CoreVersion or (bootstrapState and bootstrapState.embeddedCoreVersion) or 1
YUI.CoreMode = YUI.CoreMode or (bootstrapState and bootstrapState.coreMode) or "suite"
YUI.ProductId = YUI.ProductId or (bootstrapState and bootstrapState.productId) or "suite"
YUI.SettingsScope = YUI.SettingsScope or (bootstrapState and bootstrapState.settingsScope) or "suite"
YUI.Locale = YUI.Locale or {}
YUI.Player = YUI.Player or {}
YUI.Products = YUI.Products or {}
YUI.BlockedProducts = YUI.BlockedProducts or {}
YUI.VersionType = YUI.VersionType or ""
YUI.IsDev = YUI.IsDev or false

local Player = YUI.Player

function Player:GetName()
    local playerName = UnitName and UnitName("player") or nil
    if playerName and playerName ~= "" then
        return playerName
    end
    return self and self.Name or nil
end

function Player:GetRealmName()
    local realmName = GetRealmName and GetRealmName() or nil
    if realmName and realmName ~= "" then
        return realmName
    end
    return self and self.Server or nil
end

function Player:GetCharacterKey(fallback)
    local playerName = self:GetName()
    local realmName = self:GetRealmName()
    if playerName and playerName ~= "" and realmName and realmName ~= "" then
        return playerName .. " - " .. realmName
    end
    return fallback
end

local AceDB = LibStub("AceDB-3.0")

local function CopyMissing(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then
        return target
    end
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = value
        elseif type(target[key]) == "table" and type(value) == "table" then
            CopyMissing(target[key], value)
        end
    end
    return target
end

local function NormalizeSettings(settings)
    settings = type(settings) == "table" and settings or {}
    return {
        enabled = settings.enabled == true,
        entry = settings.entry,
        commonPages = type(settings.commonPages) == "table" and settings.commonPages or {},
        mode = settings.mode,
        minimapIcon = settings.minimapIcon == true,
    }
end

local function ProductHasSettings(product)
    return product and product.settings and product.settings.enabled == true
end

local function DefaultSavedVariable(productId)
    if productId == "suite" or YUI.CoreMode == "suite" then
        return "YUI_DB"
    end
    return (ADDON_NAME or "YUI") .. "_DB"
end

local function GetRawSavedVariables(savedVariableName)
    if not savedVariableName or not _G then
        return nil
    end
    local sv = _G[savedVariableName]
    if type(sv) == "table" then
        return sv
    end
    return nil
end

local function GetRawGlobal(savedVariableName)
    local sv = GetRawSavedVariables(savedVariableName)
    if type(sv) ~= "table" then
        return nil
    end

    if type(sv.global) ~= "table" then
        return nil
    end
    return sv.global
end

local function GetDevModeSavedVariableName()
    return DefaultSavedVariable((bootstrapState and bootstrapState.productId) or YUI.ProductId or "suite")
end

function YUI:GetPersistedDevMode()
    if self.db and self.db.global and self.db.global.devMode ~= nil then
        return self.db.global.devMode == true
    end
    if type(self.global) == "table" and self.global.devMode ~= nil then
        return self.global.devMode == true
    end
    local rawGlobal = GetRawGlobal(GetDevModeSavedVariableName())
    if type(rawGlobal) == "table" and rawGlobal.devMode ~= nil then
        return rawGlobal.devMode == true
    end
    return false
end

function YUI:SetPersistedDevMode(enabled)
    enabled = enabled == true

    local global = self.db and self.db.global
    if type(global) ~= "table" then
        global = type(self.global) == "table" and self.global or nil
    end
    if type(global) == "table" then
        global.devMode = enabled
        self.global = global
    end

    self.IsDev = enabled
    return enabled
end

YUI.IsDev = YUI:GetPersistedDevMode()

local function NormalizeDB(productId, db)
    db = type(db) == "table" and db or {}
    if db.enabled == false then
        return { enabled = false }
    end
    return {
        enabled = true,
        savedVariable = db.savedVariable or DefaultSavedVariable(productId),
        storageKey = db.storageKey,
    }
end

local defaults = {
    profile = {
        WhisperColor = true,
        PluginSkins_DetailsSpecSync = false,
    },
    global = {
        Gold = {},
        installedChars = {},
        devMode = false,
    },
}

YUI.DB = YUI.DB or {}
local DB = YUI.DB
DB.products = DB.products or {}
DB.databases = DB.databases or {}
DB.savedVariables = DB.savedVariables or {}
DB.databaseProducts = DB.databaseProducts or {}
DB.databaseSavedVariables = DB.databaseSavedVariables or {}
DB.profileProxies = DB.profileProxies or {}
DB.addonsLoaded = DB.addonsLoaded or {}
DB.pendingProductDatabases = DB.pendingProductDatabases or {}
DB.activeProductId = DB.activeProductId or YUI.ProductId or "suite"
DB.ready = DB.ready == true
DB.notReadyAccesses = DB.notReadyAccesses or {}

local function GetCharacterProfileKey(db)
    local fallback = db and db.keys and db.keys.char or nil
    return YUI.Player:GetCharacterKey(fallback)
end

local function ResolveSavedVariablesTable(db, savedVariableName)
    local rawSV = GetRawSavedVariables(savedVariableName)
    if rawSV and type(db) == "table" and type(db.sv) == "table" and db.sv ~= rawSV then
        return rawSV
    end
    if type(db) == "table" and type(db.sv) == "table" then
        return db.sv
    end
    return rawSV
end

local function EnsureProfileKeys(sv)
    if type(sv) ~= "table" then
        return nil
    end
    if type(sv.profileKeys) ~= "table" then
        sv.profileKeys = {}
    end
    return sv.profileKeys
end

local function ResolvePersistedProfileName(sv, charKey)
    if type(sv) ~= "table" or not charKey or charKey == "" or type(sv.profiles) ~= "table" then
        return nil
    end

    local profileKeys = EnsureProfileKeys(sv)
    local profileName = profileKeys and profileKeys[charKey] or nil
    if profileName and type(sv.profiles[profileName]) == "table" then
        return profileName
    end

    local legacyProfileName = type(sv.yuiProfileKeys) == "table" and sv.yuiProfileKeys[charKey] or nil
    if legacyProfileName and type(sv.profiles[legacyProfileName]) == "table" and profileKeys then
        profileKeys[charKey] = legacyProfileName
        return legacyProfileName
    end

    return nil
end

function DB:PersistCurrentProfile(db, savedVariableName)
    if type(db) ~= "table" or type(db.GetCurrentProfile) ~= "function" then
        return false
    end

    local profileName = db:GetCurrentProfile()
    local charKey = GetCharacterProfileKey(db)
    if not profileName or profileName == "" or not charKey or charKey == "" then
        return false
    end

    savedVariableName = savedVariableName or self.databaseSavedVariables[db]
    local sv = ResolveSavedVariablesTable(db, savedVariableName)
    local profileKeys = EnsureProfileKeys(sv)
    if not profileKeys then
        return false
    end

    profileKeys[charKey] = profileName
    return true
end

function DB:RestorePersistedProfile(db, savedVariableName)
    if type(db) ~= "table" or type(db.SetProfile) ~= "function" then
        return false
    end

    local charKey = GetCharacterProfileKey(db)
    if not charKey or charKey == "" then
        return false
    end

    local sv = ResolveSavedVariablesTable(db, savedVariableName)
    if type(sv) ~= "table" or type(sv.profiles) ~= "table" then
        return false
    end

    local profileName = ResolvePersistedProfileName(sv, charKey)
    if not profileName then
        return false
    end

    db.profiles = sv.profiles

    if db:GetCurrentProfile() ~= profileName then
        db:SetProfile(profileName)
    else
        local _ = db.profile
    end
    return true
end

function DB:RestoreProductProfile(productId)
    local product = self:GetProduct(productId)
    if not product or not product.db or product.db.enabled == false then
        return false
    end

    local savedVariableName = product.db.savedVariable
    local db = self.databases[product.id] or (savedVariableName and self.savedVariables[savedVariableName])
    if not db then
        return false
    end

    return self:RestorePersistedProfile(db, savedVariableName)
end

function DB:RestoreAllPersistedProfiles()
    local restored = false
    for db, savedVariableName in pairs(self.databaseSavedVariables or {}) do
        if type(db) == "table" and self:RestorePersistedProfile(db, savedVariableName) then
            restored = true
        end
    end
    return restored
end

local function NormalizeProduct(product)
    if type(product) ~= "table" or not product.id then
        return nil
    end

    local productId = product.id
    local normalized = {}
    for key, value in pairs(product) do
        normalized[key] = value
    end
    normalized.id = productId
    normalized.title = normalized.title or productId
    normalized.addonName = normalized.addonName or ADDON_NAME
    normalized.coreMode = normalized.coreMode or YUI.CoreMode
    normalized.settingsScope = normalized.settingsScope or normalized.id
    normalized.settings = NormalizeSettings(normalized.settings)
    normalized.db = NormalizeDB(productId, normalized.db)
    normalized.commands = type(normalized.commands) == "table" and normalized.commands or {}
    return normalized
end

local function CaptureDBAccessSource()
    if type(debugstack) ~= "function" then
        return nil
    end

    local ok, stack = pcall(debugstack, 2, 12, 0)
    if not ok then
        ok, stack = pcall(debugstack)
    end
    if not ok or type(stack) ~= "string" then
        return nil
    end

    local fallback
    for line in stack:gmatch("[^\r\n]+") do
        local file, lineNo = line:match('@([^"]+%.lua)"]:(%d+)')
        if not file then
            file, lineNo = line:match('@([^:]+%.lua):(%d+)')
        end
        if not file then
            file, lineNo = line:match('([^%s"]+%.lua):(%d+)')
        end
        if file and lineNo then
            local candidate = file .. ":" .. lineNo
            fallback = fallback or candidate
            if not candidate:find("YUI.lua", 1, true) then
                return candidate
            end
        end
    end

    return fallback
end

function DB:IsReady()
    return self.ready == true
end

function DB:RecordNotReadyAccess(apiName, productId)
    local source = CaptureDBAccessSource()
    local item = {
        api = apiName,
        productId = productId,
        source = source,
    }
    self.notReadyAccesses[#self.notReadyAccesses + 1] = item
    if YUI.Trace and YUI.Trace.RecordDBAccessBeforeReady then
        YUI.Trace:RecordDBAccessBeforeReady(apiName, productId, source)
    end
    return nil
end

local function RegisterProductDatabaseCallbacks(db)
    if type(db) ~= "table" or db.__yuiCallbacksRegistered then
        return
    end

    db.RegisterCallback(YUI, "OnProfileChanged", "OnProfileChanged")
    db.RegisterCallback(YUI, "OnProfileCopied", "OnProfileChanged")
    db.RegisterCallback(YUI, "OnProfileReset", "OnProfileChanged")
    db.__yuiCallbacksRegistered = true
end

function DB:IsProductAddonReady(productOrId)
    local product = type(productOrId) == "table" and productOrId or self:GetProduct(productOrId)
    local addonName = product and product.addonName
    if type(addonName) ~= "string" or addonName == "" then
        return true
    end

    if self.addonsLoaded and self.addonsLoaded[addonName] then
        return true
    end

    return false
end

function DB:AdoptProductDatabase(product, db, savedVariableName, oldDb)
    if type(product) ~= "table" or type(db) ~= "table" then
        return db
    end

    savedVariableName = savedVariableName or (product.db and product.db.savedVariable)
    local productIds = oldDb and self.databaseProducts[oldDb] or nil
    if type(productIds) ~= "table" then
        productIds = self.databaseProducts[db] or {}
    end
    productIds[product.id] = true

    if oldDb and oldDb ~= db then
        self.databases[oldDb] = nil
        self.databaseProducts[oldDb] = nil
        self.databaseSavedVariables[oldDb] = nil
    end

    self.databaseProducts[db] = productIds
    for productId in pairs(productIds) do
        self.databases[productId] = db
    end
    self.databases[product.id] = db
    self.databases[db] = self.databases[db] or product.id
    self.databaseSavedVariables[db] = savedVariableName

    if savedVariableName then
        self.savedVariables[savedVariableName] = db
    end

    if product.id == YUI.ProductId or product.id == self.activeProductId or YUI.db == oldDb or not YUI.db then
        YUI.db = db
        YUI.global = db.global
    end

    return db
end

function DB:RepairProductDatabaseBinding(product, db, savedVariableName)
    if type(product) ~= "table" or type(db) ~= "table" then
        return db
    end

    local rawSV = GetRawSavedVariables(savedVariableName)
    if type(rawSV) ~= "table" or type(db.sv) ~= "table" or db.sv == rawSV then
        return db
    end

    if YUI.Trace and YUI.Trace.RecordDBSplit then
        YUI.Trace:RecordDBSplit(product.id, db, savedVariableName)
    end

    local repaired = AceDB:New(savedVariableName, defaults, true)
    RegisterProductDatabaseCallbacks(repaired)
    return self:AdoptProductDatabase(product, repaired, savedVariableName, db)
end

function DB:EnsureProductDatabase(productId)
    if not self:IsReady() then
        return nil
    end

    local product = self:GetProduct(productId)
    if not product or not product.db or product.db.enabled == false then
        return nil
    end

    if not self:IsProductAddonReady(product) then
        self.pendingProductDatabases[product.id] = true
        return nil
    end

    local savedVariableName = product.db.savedVariable
    local db = self.databases[product.id] or self.savedVariables[savedVariableName]

    db = self:RepairProductDatabaseBinding(product, db, savedVariableName)

    if not db then
        db = AceDB:New(savedVariableName, defaults, true)
        self.savedVariables[savedVariableName] = db
        RegisterProductDatabaseCallbacks(db)
    end

    db = self:AdoptProductDatabase(product, db, savedVariableName)
    self.pendingProductDatabases[product.id] = nil

    self:RestorePersistedProfile(db, savedVariableName)
    self:PersistCurrentProfile(db, savedVariableName)

    local rawSV = GetRawSavedVariables(savedVariableName)
    if rawSV and db.sv and rawSV ~= db.sv and YUI.Trace and YUI.Trace.RecordDBSplit then
        YUI.Trace:RecordDBSplit(product.id, db, savedVariableName)
    end

    if product.id == YUI.ProductId or product.id == self.activeProductId or not YUI.db then
        YUI.db = db
        YUI.global = db.global
    end

    return db
end

function DB:BindProductDatabase(productId, migrate)
    local product = self:GetProduct(productId)
    if not product or not product.db or product.db.enabled == false then
        return nil
    end

    local db = self:EnsureProductDatabase(product.id)
    if db and migrate and self.MigrateSavedVariablesToV2 then
        self:MigrateSavedVariablesToV2(db, product.db.savedVariable)
    end
    return db
end

function DB:OnAddonLoaded(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return false
    end

    self.addonsLoaded[addonName] = true
    if not self:IsReady() then
        return true
    end

    for productId, product in pairs(self.products or {}) do
        if product and product.addonName == addonName and product.db and product.db.enabled ~= false then
            self:BindProductDatabase(productId, true)
        end
    end

    local activeProduct = self:GetProduct(self.activeProductId)
    if activeProduct and activeProduct.addonName == addonName then
        self:SetActiveProduct(activeProduct.id)
    end

    return true
end

function DB:RegisterProduct(product)
    product = NormalizeProduct(product)
    if not product then
        return nil
    end

    local existing = self.products[product.id]
    if existing then
        CopyMissing(product, existing)
        CopyMissing(product.settings, existing.settings)
        CopyMissing(product.db, existing.db)
    end

    self.products[product.id] = product

    if self:IsReady() and product.db and product.db.enabled ~= false then
        self:BindProductDatabase(product.id, true)
    end

    return product
end

function DB:GetProduct(productId)
    productId = productId or self.activeProductId or YUI.ProductId or "suite"
    return self.products[productId] or (YUI.Products and YUI.Products[productId])
end

local function ResolveProduct(productOrId)
    if type(productOrId) == "table" then
        return productOrId
    end
    local productId = productOrId or DB.activeProductId or YUI.ProductId or "suite"
    if type(productId) ~= "string" or productId == "" then
        return nil
    end
    return (YUI.Products and YUI.Products[productId]) or (DB.products and DB.products[productId])
end

local function GetActiveLocale()
    if YUI.Locale and type(YUI.Locale.Current) == "function" then
        return YUI.Locale:Current()
    end
    return (GetLocale and GetLocale()) or "enUS"
end

local function ResolveLocaleKey(namespace, key)
    if not key or key == "" or not YUI.Locale or type(YUI.Locale.Get) ~= "function" then
        return nil
    end

    local locale = YUI.Locale:Get(namespace or "Core")
    local value = locale and locale[key]
    if type(value) == "string" and value ~= "" and value ~= key then
        return value
    end
    return nil
end

local function ResolveLocalizedMap(values)
    if type(values) ~= "table" then
        return nil
    end

    local active = GetActiveLocale()
    local value = active and values[active]
    if type(value) == "string" and value ~= "" then
        return value
    end

    value = values.enUS
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

function YUI:GetProductTitle(productOrId)
    local product = ResolveProduct(productOrId)
    if not product then
        return type(productOrId) == "string" and productOrId or "YUI"
    end

    return ResolveLocaleKey(product.titleNamespace, product.titleKey)
        or ResolveLocalizedMap(product.localizedTitles)
        or product.title
        or product.id
        or "YUI"
end

local function StripProductBrandSuffix(title)
    if type(title) ~= "string" or title == "" then
        return nil
    end

    local shortTitle = title:match("^(.-)%s*·%s*.+$")
    if type(shortTitle) == "string" and shortTitle ~= "" then
        return shortTitle
    end
    return title
end

function YUI:GetProductShortTitle(productOrId)
    local product = ResolveProduct(productOrId)
    if not product then
        return type(productOrId) == "string" and productOrId or "YUI"
    end

    return ResolveLocaleKey(product.shortTitleNamespace or product.titleNamespace, product.shortTitleKey)
        or ResolveLocalizedMap(product.localizedShortTitles)
        or product.shortTitle
        or StripProductBrandSuffix(self:GetProductTitle(product))
        or product.id
        or "YUI"
end

function YUI:GetProductNotes(productOrId)
    local product = ResolveProduct(productOrId)
    if not product then
        return nil
    end

    return ResolveLocaleKey(product.notesNamespace, product.notesKey)
        or ResolveLocalizedMap(product.localizedNotes)
        or product.notes
end

function DB:GetAceDB(productId)
    local hasExplicitProductId = type(productId) == "string" and productId ~= ""
    productId = hasExplicitProductId and productId or self.activeProductId or YUI.ProductId or "suite"
    if not self:IsReady() then
        return self:RecordNotReadyAccess("GetAceDB", productId)
    end

    local product = self:GetProduct(productId)
    if product and product.db and product.db.enabled ~= false then
        local db = self:EnsureProductDatabase(productId)
        if db then
            return db
        end
        return nil
    end

    local db = self.databases[productId]
    if db then
        return db
    end

    if YUI.CoreMode == "suite" and productId ~= "suite" then
        return self.databases.suite or YUI.db
    end

    if hasExplicitProductId then
        return nil
    end

    return YUI.db
end

function DB:GetProfile(productId)
    if not self:IsReady() then
        return self:RecordNotReadyAccess("GetProfile", productId or self.activeProductId or YUI.ProductId or "suite")
    end
    local db = self:GetAceDB(productId)
    return db and db.profile or nil
end

function DB:GetGlobal(productId)
    if not self:IsReady() then
        return self:RecordNotReadyAccess("GetGlobal", productId or self.activeProductId or YUI.ProductId or "suite")
    end
    local db = self:GetAceDB(productId)
    return db and db.global or nil
end

local function DescribeDiagnosticValue(value)
    if type(value) == "table" then
        return tostring(value)
    end
    return tostring(value) .. " (" .. type(value) .. ")"
end

local function GetDiagnosticProfileKey(sv, charKey)
    if type(sv) ~= "table" or type(sv.profileKeys) ~= "table" or not charKey then
        return nil
    end
    return sv.profileKeys[charKey]
end

local function HasDiagnosticProfile(sv, profileName)
    return type(sv) == "table"
        and type(sv.profiles) == "table"
        and profileName ~= nil
        and type(sv.profiles[profileName]) == "table"
end

local function ListDiagnosticProfiles(sv)
    if type(sv) ~= "table" or type(sv.profiles) ~= "table" then
        return "-"
    end

    local names = {}
    for name in pairs(sv.profiles) do
        names[#names + 1] = tostring(name)
    end
    table.sort(names)
    if #names == 0 then
        return "(empty)"
    end

    local limit = math.min(#names, 8)
    local shown = {}
    for i = 1, limit do
        shown[i] = names[i]
    end
    local result = table.concat(shown, ", ")
    if #names > limit then
        result = result .. ", ... +" .. tostring(#names - limit)
    end
    return result
end

local function PrintDBDiagnostic(...)
    local prefix = "|cff66c6ffYUI DBDiag|r"
    if YUI.Print then
        YUI:Print(prefix, ...)
        return
    end

    local parts = { prefix }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    local message = table.concat(parts, " ")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    elseif print then
        print(message)
    end
end

function DB:CaptureSavedVariablesDiagnostic(label, productId, db)
    productId = productId or self.activeProductId or YUI.ProductId or "suite"
    db = db or self:GetAceDB(productId)

    local product = self:GetProduct(productId)
    local savedVariableName = db and self.databaseSavedVariables[db]
    if not savedVariableName and product and product.db then
        savedVariableName = product.db.savedVariable
    end
    savedVariableName = savedVariableName or DefaultSavedVariable(productId)

    local rawSV = GetRawSavedVariables(savedVariableName)
    local dbSV = type(db) == "table" and db.sv or nil
    local charKey = type(db) == "table" and GetCharacterProfileKey(db) or YUI.Player:GetCharacterKey()
    local currentProfile = type(db) == "table" and type(db.GetCurrentProfile) == "function" and db:GetCurrentProfile() or nil

    self.savedVariablesDiagLog = self.savedVariablesDiagLog or {}
    self.savedVariablesDiagLog[#self.savedVariablesDiagLog + 1] = {
        label = label or "manual",
        productId = productId,
        savedVariableName = savedVariableName,
        dbSV = DescribeDiagnosticValue(dbSV),
        rawSV = DescribeDiagnosticValue(rawSV),
        same = dbSV ~= nil and dbSV == rawSV,
        currentProfile = currentProfile,
        charKey = charKey,
        dbProfileKey = GetDiagnosticProfileKey(dbSV, charKey),
        rawProfileKey = GetDiagnosticProfileKey(rawSV, charKey),
        dbHasCurrent = HasDiagnosticProfile(dbSV, currentProfile),
        rawHasCurrent = HasDiagnosticProfile(rawSV, currentProfile),
        dbProfiles = ListDiagnosticProfiles(dbSV),
        rawProfiles = ListDiagnosticProfiles(rawSV),
    }
end

function DB:PrintSavedVariablesDiagnostics()
    local log = self.savedVariablesDiagLog
    if type(log) ~= "table" or #log == 0 then
        PrintDBDiagnostic("no snapshots captured")
        return
    end

    for index, item in ipairs(log) do
        PrintDBDiagnostic("#" .. index, item.label, "product=" .. tostring(item.productId), "sv=" .. tostring(item.savedVariableName))
        PrintDBDiagnostic("  tables:", "db.sv=" .. tostring(item.dbSV), "_G[sv]=" .. tostring(item.rawSV), "same=" .. tostring(item.same), "current=" .. tostring(item.currentProfile))
        PrintDBDiagnostic("  keys:", "char=" .. tostring(item.charKey), "dbKey=" .. tostring(item.dbProfileKey), "rawKey=" .. tostring(item.rawProfileKey))
        PrintDBDiagnostic("  profiles:", "dbHasCurrent=" .. tostring(item.dbHasCurrent), "rawHasCurrent=" .. tostring(item.rawHasCurrent), "db={" .. tostring(item.dbProfiles) .. "}", "raw={" .. tostring(item.rawProfiles) .. "}")
    end
end

function DB:SetActiveProduct(productId)
    if not productId or productId == "" then
        productId = YUI.ProductId or "suite"
    end
    self.activeProductId = productId
    if self:IsReady() and self.GetAceDB then
        local db = self:GetAceDB(productId)
        if db then
            YUI.db = db
            YUI.global = db.global
        end
    end
    if self:IsReady() and self.InstallYUIDBProxy then
        self:InstallYUIDBProxy(productId)
    end
    return productId
end

function DB:GetProfileProxy(productId)
    productId = productId or self.activeProductId or YUI.ProductId or "suite"
    local proxy = self.profileProxies[productId]
    if proxy then
        return proxy
    end

    proxy = {}
    setmetatable(proxy, {
        __index = function(_, key)
            local profile = DB:GetProfile(productId)
            return profile and profile[key] or nil
        end,
        __newindex = function(_, key, value)
            local profile = DB:GetProfile(productId)
            if profile then
                profile[key] = value
            end
        end,
    })
    self.profileProxies[productId] = proxy
    return proxy
end

function DB:InstallYUIDBProxy(productId)
    _G.YUIDB = self:GetProfileProxy(productId or self.activeProductId or YUI.ProductId or "suite")
end

function YUI:RegisterProduct(product)
    product = NormalizeProduct(product)
    if not product then
        return false
    end

    self.Products = self.Products or {}
    local existing = self.Products[product.id]
    if existing then
        CopyMissing(product, existing)
        CopyMissing(product.settings, existing.settings)
        CopyMissing(product.db, existing.db)
    end
    self.Products[product.id] = product
    DB:RegisterProduct(product)

    local activeProduct = DB:GetProduct(DB.activeProductId)
    local shouldPreferProduct = ProductHasSettings(product) and not ProductHasSettings(activeProduct)
    if shouldPreferProduct then
        DB:SetActiveProduct(product.id)
    end

    if self.Commands and self.Commands.RegisterProduct then
        self.Commands:RegisterProduct(product)
    end
    if self.MinimapIcon and self.MinimapIcon.RegisterProduct then
        self.MinimapIcon:RegisterProduct(product)
    end
    if self.Settings and self.Settings.RefreshProducts then
        if shouldPreferProduct and self.Settings.SetActiveProduct then
            self.Settings:SetActiveProduct(product.id)
        end
        self.Settings:RefreshProducts()
    end

    return true
end

function YUI:BlockProduct(productId, reason)
    if not productId then
        return
    end

    self.BlockedProducts = self.BlockedProducts or {}
    self.BlockedProducts[productId] = reason or true
end

function YUI:InitializeDB()
    if self._dbInitialized then
        return
    end

    local bootstrapProduct = {
        addonName = ADDON_NAME,
        id = (bootstrapState and bootstrapState.productId) or self.ProductId or "suite",
        title = (bootstrapState and bootstrapState.productTitle) or (((bootstrapState and bootstrapState.productId) or self.ProductId) == "suite" and "YUI" or self.ProductId) or "YUI",
        logo = bootstrapState and bootstrapState.productLogo,
        author = "阿言",
        notes = "一起见证最棒的界面配置成长",
        version = bootstrapState and bootstrapState.productVersion,
        coreMode = self.CoreMode,
        settingsScope = self.SettingsScope,
        settings = (bootstrapState and bootstrapState.settings) or {
            enabled = self.CoreMode == "suite",
            mode = self.CoreMode == "suite" and "suite" or nil,
        },
        db = (bootstrapState and bootstrapState.db) or {
            enabled = true,
            savedVariable = DefaultSavedVariable((bootstrapState and bootstrapState.productId) or self.ProductId or "suite"),
        },
        commands = bootstrapState and bootstrapState.commands,
    }

    self:RegisterProduct(bootstrapProduct)
    DB:SetActiveProduct(bootstrapProduct.id)
    self._dbInitialized = true
end

function DB:InitializeSavedVariables()
    if self.ready then
        return true
    end

    self.addonsLoaded[ADDON_NAME] = true
    self.ready = true

    local activeProductId = self.activeProductId or YUI.ProductId or "suite"
    local activeDB

    if YUI.Trace and YUI.Trace.Measure then
        activeDB = YUI.Trace:Measure("DB", "Bind active DB", function()
            return self:EnsureProductDatabase(activeProductId)
        end, activeProductId, {
            moduleId = "YUI.DB",
            phase = "BindActive",
        })
    else
        activeDB = self:EnsureProductDatabase(activeProductId)
    end

    for productId, product in pairs(self.products or {}) do
        if product and product.db and product.db.enabled ~= false and productId ~= activeProductId then
            if YUI.Trace and YUI.Trace.Measure then
                YUI.Trace:Measure("DB", "Bind product DB: " .. tostring(productId), function()
                    self:EnsureProductDatabase(productId)
                end, product.db.savedVariable, {
                    moduleId = "YUI.DB",
                    phase = "BindProduct:" .. tostring(productId),
                })
            else
                self:EnsureProductDatabase(productId)
            end
        end
    end

    if self.MigrateSavedVariablesToV2 then
        local migratedSavedVariables = {}
        for db, savedVariableName in pairs(self.databaseSavedVariables or {}) do
            local migrationKey = savedVariableName or db
            if type(db) == "table" and migrationKey and not migratedSavedVariables[migrationKey] then
                migratedSavedVariables[migrationKey] = true
                if YUI.Trace and YUI.Trace.Measure then
                    YUI.Trace:Measure("DB", "Migrate SavedVariables: " .. tostring(savedVariableName or "?"), function()
                        self:MigrateSavedVariablesToV2(db, savedVariableName)
                    end, savedVariableName, {
                        moduleId = "YUI.DB",
                        phase = "MigrateSavedVariables",
                    })
                else
                    self:MigrateSavedVariablesToV2(db, savedVariableName)
                end
            end
        end
    end

    if not YUI.db and activeDB then
        YUI.db = activeDB
        YUI.global = activeDB.global
    end

    if YUI.SetPersistedDevMode then
        YUI:SetPersistedDevMode(YUI:GetPersistedDevMode())
    elseif YUI.global and YUI.global.devMode ~= nil then
        YUI.IsDev = YUI.global.devMode == true
    end

    self:InstallYUIDBProxy(activeProductId)
    self:CaptureSavedVariablesDiagnostic("InitializeSavedVariables:ready", activeProductId, YUI.db)

    if YUI.Lifecycle and YUI.Lifecycle.MarkReady then
        YUI.Lifecycle:MarkReady("YUI_DB_READY")
    elseif YUI.Event and YUI.Event.Emit then
        if YUI.Trace and YUI.Trace.RecordStage then
            YUI.Trace:RecordStage("YUI_DB_READY", "Lifecycle")
        end
        YUI.Event:Emit("YUI_DB_READY")
    end

    return true
end

function YUI:OnProfileChanged(event, database, newProfileKey)
    if database and DB.PersistCurrentProfile then
        DB:PersistCurrentProfile(database)
    end

    local productId = DB.databases and DB.databases[database] or DB.activeProductId or self.ProductId or "suite"
    local current = database and database.GetCurrentProfile and database:GetCurrentProfile()
    local product = self.Products and self.Products[productId]
    local title = self.GetProductTitle and self:GetProductTitle(product or productId) or (product and product.title or productId)
    self:Print(title .. " 配置已切换为: " .. (newProfileKey or current or "Default"))

    if self.Settings and self.Settings.RefreshNav then
        self.Settings:RefreshNav()
    end

    if self.Module and self.Module.NotifyProfileChanged then
        self.Module:NotifyProfileChanged(event, database, newProfileKey)
    elseif self.YBar and self.YBar.ReloadDB then
        self.YBar:ReloadDB()
    end
end

YUI.Commands = YUI.Commands or {}
local Commands = YUI.Commands
Commands.registeredAliases = Commands.registeredAliases or {}

local function NormalizeSlashAlias(alias)
    alias = tostring(alias or "")
    if alias == "" then return nil end
    if alias:sub(1, 1) ~= "/" then
        alias = "/" .. alias
    end
    return alias:lower()
end

local function IsSlashAliasTaken(alias)
    if not SlashCmdList then return false end
    local upper = alias:upper()
    for name in pairs(SlashCmdList) do
        local i = 1
        while _G["SLASH_" .. name .. i] do
            if tostring(_G["SLASH_" .. name .. i]):upper() == upper then
                return true
            end
            i = i + 1
        end
    end
    return false
end

function Commands:Register(command)
    if not SlashCmdList or type(command) ~= "table" then
        return false
    end

    local aliases = {}
    for _, alias in ipairs(command.aliases or {}) do
        alias = NormalizeSlashAlias(alias)
        if alias and not self.registeredAliases[alias] and not IsSlashAliasTaken(alias) then
            aliases[#aliases + 1] = alias
        elseif alias and YUI.IsDev and YUI.Print then
            YUI:Print("Slash command conflict:", alias)
        end
    end
    if #aliases == 0 then
        return false
    end

    local slashId = "YUI_PRODUCT_" .. tostring(command.id or command.productId or aliases[1]):upper():gsub("[^A-Z0-9_]", "_")
    for index, alias in ipairs(aliases) do
        _G["SLASH_" .. slashId .. index] = alias
        self.registeredAliases[alias] = slashId
    end

    SlashCmdList[slashId] = function(msg)
        if YUI.HandleSlashCommand and YUI:HandleSlashCommand(msg) then
            return
        end

        if type(command.handler) == "function" then
            command.handler(msg, command)
            return
        end

        if command.action == "openSettings" and YUI.Settings and YUI.Settings.OpenProduct then
            YUI.Settings:OpenProduct(command.productId, command.entry)
        end
    end
    return true
end

function Commands:RegisterProduct(product)
    if type(product) ~= "table" or type(product.commands) ~= "table" then
        return
    end

    local targetProductId = product.id
    if (product.coreMode == "suite" or YUI.CoreMode == "suite") and product.id ~= "suite" then
        targetProductId = "suite"
    end

    for index, command in ipairs(product.commands) do
        local aliases = {}
        if command.alias then
            aliases[#aliases + 1] = command.alias
        end
        for _, alias in ipairs(command.aliases or {}) do
            aliases[#aliases + 1] = alias
        end
        self:Register({
            id = command.id or (product.id .. "." .. index),
            productId = targetProductId,
            aliases = aliases,
            action = command.action,
            entry = command.entry or (product.settings and product.settings.entry),
        })
    end
end

YUI:InitializeDB()

-- 配置访问器
function YUI:getConfigByKey(key, default, productId)
    local profile = DB:GetProfile(productId)
    if profile and profile[key] ~= nil then
        return profile[key]
    end
    return default
end

function YUI:setConfigByKey(key, value, productId)
    local profile = DB:GetProfile(productId)
    if profile then
        profile[key] = value
    end
end

if SlashCmdList and not SlashCmdList.YUIDBDIAG then
    _G.SLASH_YUIDBDIAG1 = "/yuidbdiag"
    SlashCmdList.YUIDBDIAG = function(msg)
        local productId = tostring(msg or ""):match("^%s*(.-)%s*$")
        if productId == "" then
            productId = DB.activeProductId or YUI.ProductId or "suite"
        end
        DB:CaptureSavedVariablesDiagnostic("slash:/yuidbdiag", productId)
        DB:PrintSavedVariablesDiagnostics()
    end
end

_G.YUI = YUI
