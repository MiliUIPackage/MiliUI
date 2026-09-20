do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI

local Locale = YUI.Locale or {}
YUI.Locale = Locale

Locale.namespaces = Locale.namespaces or {}
Locale.missing = Locale.missing or {}
Locale.defaultLocale = Locale.defaultLocale or "enUS"

local SUPPORTED_OVERRIDES = {
    deDE = true,
    enUS = true,
    esES = true,
    esMX = true,
    frFR = true,
    itIT = true,
    koKR = true,
    ptBR = true,
    ruRU = true,
    zhCN = true,
    zhTW = true,
}

local NORMALIZED_OVERRIDES = {
    dede = "deDE",
    enus = "enUS",
    eses = "esES",
    esmx = "esMX",
    frfr = "frFR",
    itit = "itIT",
    kokr = "koKR",
    ptbr = "ptBR",
    ruru = "ruRU",
    zhcn = "zhCN",
    zhtw = "zhTW",
}

local OVERRIDE_ORDER = {
    "enUS", "deDE", "esES", "esMX", "frFR", "itIT",
    "koKR", "ptBR", "ruRU", "zhCN", "zhTW",
}

local currentLocale = GetLocale and GetLocale() or Locale.defaultLocale
local previousSlashHandler = YUI.HandleSlashCommand

local function NormalizeOverrideLocale(locale)
    if type(locale) ~= "string" or locale == "" then
        return nil
    end

    return NORMALIZED_OVERRIDES[locale:lower()] or locale
end

local function IsSupportedOverride(locale)
    return SUPPORTED_OVERRIDES[locale] == true
end

local function GetRawGlobal()
    local sv = _G and _G.YUI_DB
    if type(sv) == "table" and type(sv.global) == "table" then
        return sv.global
    end
    return nil
end

local function GetDBGlobal()
    if YUI.DB and YUI.DB.IsReady and YUI.DB.GetGlobal and YUI.DB:IsReady() then
        local global = YUI.DB:GetGlobal("suite")
        if type(global) == "table" then
            return global
        end
    end

    if type(YUI.global) == "table" then
        return YUI.global
    end

    return GetRawGlobal()
end

local function GetPersistedOverride()
    local global = GetDBGlobal()
    local locale = global and NormalizeOverrideLocale(global.localeOverride)
    if IsSupportedOverride(locale) then
        return locale
    end
    return nil
end

Locale.overrideLocale = Locale.overrideLocale or GetPersistedOverride()
Locale.pendingPersistedOverride = Locale.pendingPersistedOverride

local function EnsureNamespace(namespace)
    local data = Locale.namespaces[namespace]
    if not data then
        data = {}
        Locale.namespaces[namespace] = data
    end
    return data
end

local function NoteMissing(namespace, key)
    if not YUI.IsDev then
        return
    end

    local missingKey = namespace .. "." .. tostring(key)
    if Locale.missing[missingKey] then
        return
    end

    Locale.missing[missingKey] = true
    if YUI.Print then
        YUI:Print("Missing locale:", missingKey)
    end
end

function Locale:Current()
    return self.overrideLocale or currentLocale or self.defaultLocale
end

function Locale:GetClientLocale()
    return currentLocale or self.defaultLocale
end

function Locale:GetOverride()
    return self.overrideLocale
end

function Locale:SetOverride(locale)
    locale = NormalizeOverrideLocale(locale)
    if not IsSupportedOverride(locale) then
        return false
    end

    self.overrideLocale = locale
    self:PersistOverride(locale)
    return true
end

function Locale:ClearOverride()
    self.overrideLocale = nil
    self:PersistOverride(nil)
end

function Locale:PersistOverride(locale)
    if locale ~= nil then
        locale = NormalizeOverrideLocale(locale)
        if not IsSupportedOverride(locale) then
            return false
        end
    end

    local global = GetDBGlobal()
    if type(global) == "table" then
        global.localeOverride = locale
        self.pendingPersistedOverride = nil
        return true
    end

    self.pendingPersistedOverride = locale or false
    return false
end

function Locale:ApplyPersistedOverride()
    local global = GetDBGlobal()
    if type(global) ~= "table" then
        return false
    end

    if self.pendingPersistedOverride ~= nil then
        if self.pendingPersistedOverride == false then
            global.localeOverride = nil
            self.pendingPersistedOverride = nil
            return true
        end

        if IsSupportedOverride(self.pendingPersistedOverride) then
            global.localeOverride = self.pendingPersistedOverride
            self.overrideLocale = self.pendingPersistedOverride
            self.pendingPersistedOverride = nil
            return true
        end
    end

    local persisted = GetPersistedOverride()
    if persisted then
        self.overrideLocale = persisted
    end
    return true
end

function Locale:GetPersistedOverride()
    return GetPersistedOverride()
end

function Locale:Register(namespace, locale, values)
    if type(namespace) ~= "string" or namespace == "" then
        return false
    end
    if type(locale) ~= "string" or locale == "" then
        return false
    end
    if type(values) ~= "table" then
        return false
    end

    local data = EnsureNamespace(namespace)
    data[locale] = data[locale] or {}

    for key, value in pairs(values) do
        data[locale][key] = value
    end

    return true
end

function Locale:Resolve(namespace, key, locale)
    namespace = namespace or "Core"

    local data = self.namespaces[namespace]
    if type(data) ~= "table" then
        return nil
    end

    local activeLocale = locale or self:Current()
    local active = data[activeLocale]
    if type(active) == "table" and active[key] ~= nil then
        return active[key]
    end

    local fallback = data[self.defaultLocale]
    if type(fallback) == "table" then
        return fallback[key]
    end

    return nil
end

function Locale:Get(namespace)
    namespace = namespace or "Core"

    EnsureNamespace(namespace)

    return setmetatable({}, {
        __index = function(_, key)
            local value = self:Resolve(namespace, key)
            if value ~= nil then
                return value
            end

            NoteMissing(namespace, key)
            return tostring(key)
        end,
    })
end

function Locale:Format(namespace, key, ...)
    return string.format(self:Get(namespace)[key], ...)
end

function Locale:GetClassName(classToken, fallback)
    if type(classToken) ~= "string" or classToken == "" then
        return fallback or ""
    end

    return self:Resolve("Core", "class." .. classToken:upper() .. ".name")
        or fallback
        or classToken
end

function Locale:GetSpecializationName(specID, fallback)
    specID = tonumber(specID)
    if not specID then
        return fallback or ""
    end

    return self:Resolve("Core", "specialization." .. tostring(specID) .. ".name")
        or fallback
        or tostring(specID)
end

function Locale:UsesCompactSpecializationNames()
    local locale = self:Current()
    return locale == "zhCN" or locale == "zhTW"
end

local BUILTIN_FONT_ROLES = {
    ["默认"] = "default",
    ["預設"] = "default",
    ["기본 글꼴"] = "default",
    ["聊天"] = "chat",
    ["伤害数字"] = "damage",
    ["傷害數字"] = "damage",
    ["데미지 글꼴"] = "damage",
}

function Locale:GetFontDisplayName(fontKey)
    local role = BUILTIN_FONT_ROLES[fontKey]
    if not role then return fontKey end
    return self:Resolve("Core", "font.builtin." .. role) or fontKey
end

YUI.L = Locale:Get("Core")

local function PrintLocaleStatus()
    if not YUI.Print then
        return
    end

    local override = Locale:GetOverride()
    local persisted = Locale:GetPersistedOverride()
    local active = Locale:Current()
    local client = Locale:GetClientLocale()
    if override then
        local source = persisted == override and "persisted" or "session"
        YUI:Print("Locale override:", override, "(" .. source .. ", client:", client .. ")")
    else
        YUI:Print("Locale:", active, "(client)")
    end
end

local function PrintLocaleHelp()
    if not YUI.Print then
        return
    end

    YUI:Print("Locale commands:")
    for _, locale in ipairs(OVERRIDE_ORDER) do
        YUI:Print("/yui locale " .. locale)
    end
    YUI:Print("/yui locale reset")
    YUI:Print("/yui locale status")
end

local function HandleLocaleSlash(args)
    args = strtrim(args or "")
    if args == "" or args == "help" then
        PrintLocaleHelp()
        return true
    end

    local locale = args:match("^(%S+)")
    if not locale then
        PrintLocaleHelp()
        return true
    end

    local normalized = locale:lower()
    locale = NormalizeOverrideLocale(locale)

    if normalized == "reset" or normalized == "clear" then
        Locale:ClearOverride()
        if YUI.Print then
            YUI:Print("Locale override cleared. Reopen the panel or /reload to refresh existing text.")
        end
        return true
    end

    if normalized == "status" then
        PrintLocaleStatus()
        return true
    end

    if not IsSupportedOverride(locale) then
        if YUI.Print then
            YUI:Print("Unsupported locale override:", locale)
        end
        PrintLocaleHelp()
        return true
    end

    Locale:SetOverride(locale)
    if YUI.Print then
        YUI:Print("Locale override set to:", locale, "(persisted). Reopen the panel or /reload to refresh existing text.")
    end
    return true
end

if YUI.Event and YUI.Event.On then
    YUI.Event:On("YUI_DB_READY", function()
        Locale:ApplyPersistedOverride()
    end, Locale, {
        priority = 9000,
        traceName = "Locale:ApplyPersistedOverride",
        moduleId = "core.locale",
        phase = "YUI_DB_READY",
    })
end

function YUI:HandleLocaleSlashCommand(msg)
    local text = strtrim(msg or "")
    local command, args = text:match("^(%S+)%s*(.*)$")

    if command and command:lower() == "locale" then
        return HandleLocaleSlash(args)
    end

    return false
end

function YUI:HandleSlashCommand(msg)
    if self.HandleLocaleSlashCommand and self:HandleLocaleSlashCommand(msg) then
        return true
    end

    if previousSlashHandler then
        return previousSlashHandler(self, msg)
    end

    return false
end
