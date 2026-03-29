DamageMeterTools_Locale = DamageMeterTools_Locale or {}
local L = DamageMeterTools_Locale

L.strings = L.strings or {}
L.default = "enUS"

local function NormalizeLocale(locale)
    locale = tostring(locale or "enUS")
    locale = locale:gsub("%s+", "")

    if locale == "zhCN" then
        return "zhCN"
    elseif locale == "zhTW" then
        return "zhTW"
    elseif locale == "enUS" or locale == "enGB" or locale == "zhEN" then
        return "enUS"
    end

    return "enUS"
end

local function GetSavedDB()
    local db = rawget(_G, "DamageMeterToolsDB")
    if type(db) ~= "table" then
        return nil
    end
    return db
end

local function GetSavedLocaleOverride()
    local db = GetSavedDB()
    if not db or type(db.locale) ~= "table" then
        return nil
    end

    local value = db.locale.override
    if type(value) ~= "string" or value == "" then
        return nil
    end

    local upper = value:upper()

    if upper == "AUTO" then
        return nil
    elseif upper == "ZHCN" then
        return "zhCN"
    elseif upper == "ZHTW" then
        return "zhTW"
    elseif upper == "ZHEN" or upper == "ENUS" or upper == "ENGB" then
        return "enUS"
    end

    return nil
end

local function ResolveLocale(requestedLocale)
    if requestedLocale ~= nil then
        return NormalizeLocale(requestedLocale)
    end

    local override = GetSavedLocaleOverride()
    if override then
        return override
    end

    local gameLocale = GetLocale and GetLocale() or "enUS"
    return NormalizeLocale(gameLocale)
end

function L:Register(locale, tbl)
    if type(locale) ~= "string" or type(tbl) ~= "table" then
        return
    end

    locale = NormalizeLocale(locale)
    self.strings[locale] = self.strings[locale] or {}

    for k, v in pairs(tbl) do
        if type(k) == "string" and type(v) == "string" then
            self.strings[locale][k] = v
        end
    end
end

function L:Get(text, locale)
    if type(text) ~= "string" then
        return tostring(text or "")
    end

    local current = ResolveLocale(locale)
    local defaultLocale = NormalizeLocale(self.default)

    if self.strings[current] and self.strings[current][text] then
        return self.strings[current][text]
    end

    if self.strings[defaultLocale] and self.strings[defaultLocale][text] then
        return self.strings[defaultLocale][text]
    end

    return text
end

function L:Has(text, locale)
    if type(text) ~= "string" then
        return false
    end

    local current = ResolveLocale(locale)
    return self.strings[current] and self.strings[current][text] ~= nil
end

function L:GetCurrentLocale()
    return ResolveLocale(nil)
end

function L:GetGameLocale()
    local gameLocale = GetLocale and GetLocale() or "enUS"
    return NormalizeLocale(gameLocale)
end

function DamageMeterTools_L(text)
    return L:Get(text)
end

function DamageMeterTools_SetLocaleOverride(locale)
    DamageMeterToolsDB = DamageMeterToolsDB or {}
    DamageMeterToolsDB.locale = DamageMeterToolsDB.locale or {}

    local value = tostring(locale or "AUTO")
    local upper = value:upper()

    if upper == "AUTO" or upper == "" then
        DamageMeterToolsDB.locale.override = "AUTO"
    elseif upper == "ZHCN" then
        DamageMeterToolsDB.locale.override = "zhCN"
    elseif upper == "ZHTW" then
        DamageMeterToolsDB.locale.override = "zhTW"
    elseif upper == "ZHEN" or upper == "ENUS" or upper == "ENGB" then
        DamageMeterToolsDB.locale.override = "enUS"
    else
        DamageMeterToolsDB.locale.override = "AUTO"
    end
end

function DamageMeterTools_GetLocaleOverride()
    DamageMeterToolsDB = DamageMeterToolsDB or {}
    DamageMeterToolsDB.locale = DamageMeterToolsDB.locale or {}

    local value = DamageMeterToolsDB.locale.override
    if type(value) ~= "string" or value == "" then
        return "AUTO"
    end

    local upper = value:upper()

    if upper == "ZHCN" then
        return "zhCN"
    elseif upper == "ZHTW" then
        return "zhTW"
    elseif upper == "ZHEN" or upper == "ENUS" or upper == "ENGB" then
        return "enUS"
    end

    return "AUTO"
end