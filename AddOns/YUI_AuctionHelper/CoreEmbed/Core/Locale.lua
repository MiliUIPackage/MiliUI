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

-- Development builds may replace nil with one supported locale before loading.
-- Never read SavedVariables here: they arrive after the locale files execute.
local DEVELOPMENT_LOCALE = nil
local currentLocale = GetLocale and GetLocale() or Locale.defaultLocale
local previousSlashHandler = YUI.HandleSlashCommand
local function NormalizeOverrideLocale(locale)
    return type(locale) == "string" and (NORMALIZED_OVERRIDES[locale:lower()] or locale) or nil
end
local selectedLocale = NormalizeOverrideLocale(DEVELOPMENT_LOCALE) or currentLocale
if not SUPPORTED_OVERRIDES[selectedLocale] then selectedLocale = "enUS" end
Locale.overrideLocale = DEVELOPMENT_LOCALE and selectedLocale or nil
Locale.pendingPersistedOverride = nil

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
    return selectedLocale
end

function Locale:GetClientLocale()
    return currentLocale
end

function Locale:GetOverride()
    return self.overrideLocale
end

function Locale:ShouldLoad(locale)
    return locale == "enUS" or locale == selectedLocale
end

-- A merged table cannot switch languages in place: overwritten text is released.
function Locale:SetOverride(locale)
    return NormalizeOverrideLocale(locale) == selectedLocale
end

function Locale:ClearOverride()
    self:ApplyPersistedOverride()
    return DEVELOPMENT_LOCALE == nil
end

function Locale:ApplyPersistedOverride()
    local global = YUI.DB and YUI.DB.IsReady and YUI.DB:IsReady()
        and YUI.DB.GetGlobal and YUI.DB:GetGlobal("suite")
        or YUI.global or (_G.YUI_DB and _G.YUI_DB.global)
    if type(global) ~= "table" then return false end
    global.localeOverride = nil
    return true
end

function Locale:GetPersistedOverride()
    return nil
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

    if not self:ShouldLoad(locale) then return false end
    local data = EnsureNamespace(namespace)
    for key, value in pairs(values) do
        if locale == selectedLocale or data[key] == nil then
            data[key] = value
        end
    end

    return true
end

function Locale:Resolve(namespace, key, locale)
    namespace = namespace or "Core"

    local data = self.namespaces[namespace]
    if type(data) ~= "table" then
        return nil
    end

    -- Explicit requests for an unloaded language must not mislabel active text.
    if locale and locale ~= selectedLocale then return nil end
    return data[key]
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

local function HandleLocaleSlash(args)
    args = strtrim(args or "")
    if args == "reset" or args == "clear" then Locale:ClearOverride() end
    if YUI.Print then
        YUI:Print("Locale:", Locale:Current(), "(client:", Locale:GetClientLocale() .. ")")
        if args ~= "status" then
            YUI:Print("Development locale: set DEVELOPMENT_LOCALE in Core/Locale.lua in the test build, then /reload. Set nil to follow the client.")
        end
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
