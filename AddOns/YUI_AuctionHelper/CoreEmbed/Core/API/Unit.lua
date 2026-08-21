do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Unit = YUI.API.Unit or {}
YUI.API.Unit = Unit

local Legacy = YUI.WOW_API

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, value = pcall(func, ...)
    if ok then
        return value
    end

    return nil
end

local function IsSecretValue(value)
    local security = YUI.API and YUI.API.Security
    if security and security.IsSecretValue then
        return security.IsSecretValue(value) == true
    end

    if not issecretvalue then
        return false
    end

    local ok, isSecret = pcall(issecretvalue, value)
    return ok and isSecret == true
end

local function SafeValue(func, ...)
    local value = SafeCall(func, ...)

    if IsSecretValue(value) then
        return nil
    end

    return value
end

local function SafeBool(func, ...)
    local value = SafeValue(func, ...)

    if value == nil then
        return nil
    end

    return value and true or false
end

local CLASS_ID_ORDER = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }
local classInfosCache
local classInfosByID
local classInfosByFile
local raceInfosCache
local raceInfosByID
local raceInfosByFile
local raceInfosByName

local function CopyClassInfo(info)
    if type(info) ~= "table" then return nil end
    return {
        className = info.className,
        classFile = info.classFile,
        classID = info.classID,
    }
end

local function NormalizeClassInfo(info, fallbackID)
    if type(info) ~= "table" then return nil end

    local classFile = info.classFile or info.fileName or info.filename
    if type(classFile) == "string" then
        classFile = strupper and strupper(classFile) or string.upper(classFile)
    end

    if not classFile or classFile == "" then return nil end

    return {
        className = info.className or info.name or classFile,
        classFile = classFile,
        classID = tonumber(info.classID or info.id or fallbackID),
    }
end

local function CopyRaceInfo(info)
    if type(info) ~= "table" then return nil end
    return {
        raceName = info.raceName,
        clientFileString = info.clientFileString,
        raceID = info.raceID,
    }
end

local function NormalizeRaceInfo(info, fallbackID)
    if type(info) ~= "table" then return nil end

    local clientFileString = info.clientFileString or info.fileName or info.fileString
    if type(clientFileString) == "string" then
        clientFileString = string.upper(clientFileString)
    end

    if not clientFileString or clientFileString == "" then return nil end

    return {
        raceName = info.raceName or info.name or clientFileString,
        clientFileString = clientFileString,
        raceID = tonumber(info.raceID or info.id or fallbackID),
    }
end

local function BuildClassInfoCaches()
    if classInfosCache then
        return classInfosCache, classInfosByID, classInfosByFile
    end

    local list = {}
    local byID = {}
    local byFile = {}

    local function Add(info, fallbackID)
        info = NormalizeClassInfo(info, fallbackID)
        if not info or byFile[info.classFile] then return end

        list[#list + 1] = info
        byFile[info.classFile] = info
        if info.classID then
            byID[info.classID] = info
        end
    end

    if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        for _, classID in ipairs(CLASS_ID_ORDER) do
            Add(C_CreatureInfo.GetClassInfo(classID), classID)
        end
    end

    if GetClassInfo then
        local count = GetNumClasses and GetNumClasses() or #CLASS_ID_ORDER
        for index = 1, count do
            local name, tag, id = GetClassInfo(index)
            Add({ className = name, classFile = tag, classID = id }, id or index)
        end
    end

    if UnitClass then
        local name, tag, id = UnitClass("player")
        Add({ className = name, classFile = tag, classID = id }, id)
    end

    table.sort(list, function(a, b)
        local idA = a.classID or 9999
        local idB = b.classID or 9999
        if idA ~= idB then return idA < idB end
        return (a.classFile or "") < (b.classFile or "")
    end)

    classInfosCache = list
    classInfosByID = byID
    classInfosByFile = byFile
    return classInfosCache, classInfosByID, classInfosByFile
end

local function BuildRaceInfoCaches()
    if raceInfosCache then
        return raceInfosCache, raceInfosByID, raceInfosByFile, raceInfosByName
    end

    local list = {}
    local byID = {}
    local byFile = {}
    local byName = {}

    local function Add(info, fallbackID)
        info = NormalizeRaceInfo(info, fallbackID)
        if not info or byFile[info.clientFileString] then return end

        list[#list + 1] = info
        byFile[info.clientFileString] = info
        if info.raceID then
            byID[info.raceID] = info
        end
        if type(info.raceName) == "string" and info.raceName ~= "" then
            byName[info.raceName] = info
        end
    end

    if C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
        for raceID = 1, 100 do
            local ok, info = pcall(C_CreatureInfo.GetRaceInfo, raceID)
            if ok then
                Add(info, raceID)
            end
        end
    end

    table.sort(list, function(a, b)
        local idA = a.raceID or 9999
        local idB = b.raceID or 9999
        if idA ~= idB then return idA < idB end
        return (a.clientFileString or "") < (b.clientFileString or "")
    end)

    raceInfosCache = list
    raceInfosByID = byID
    raceInfosByFile = byFile
    raceInfosByName = byName
    return raceInfosCache, raceInfosByID, raceInfosByFile, raceInfosByName
end

function Unit.GetClassInfos()
    local list = BuildClassInfoCaches()
    local result = {}
    for index, info in ipairs(list) do
        result[index] = CopyClassInfo(info)
    end
    return result
end

function Unit.GetNumClasses()
    local list = BuildClassInfoCaches()
    return #list
end

function Unit.GetClassInfo(index)
    index = tonumber(index)
    if not index then return nil end

    local list, byID = BuildClassInfoCaches()
    return CopyClassInfo(list[index] or byID[index])
end

function Unit.GetClassInfoByID(classID)
    classID = tonumber(classID)
    if not classID then return nil end

    local _, byID = BuildClassInfoCaches()
    return CopyClassInfo(byID[classID])
end

function Unit.GetClassColor(classFilename)
    if not classFilename then return nil end

    local color
    if C_ClassColor and C_ClassColor.GetClassColor then
        color = C_ClassColor.GetClassColor(classFilename)
    elseif RAID_CLASS_COLORS then
        color = RAID_CLASS_COLORS[classFilename]
    end

    if color then
        return {
            r = color.r or 1,
            g = color.g or 1,
            b = color.b or 1,
            GenerateHexColor = function()
                return color.GenerateHexColor and color:GenerateHexColor() or color.colorStr or "ffffffff"
            end,
            WrapTextInColorCode = function(self, text)
                return "|c" .. self:GenerateHexColor() .. text .. "|r"
            end
        }
    end

    return nil
end

function Unit.GetRaceInfoByID(raceID)
    raceID = tonumber(raceID)
    if not raceID then return nil end

    local _, byID = BuildRaceInfoCaches()
    return CopyRaceInfo(byID[raceID])
end

function Unit.GetRaceInfoByFile(clientFileString)
    if type(clientFileString) ~= "string" or clientFileString == "" then
        return nil
    end

    local _, _, byFile = BuildRaceInfoCaches()
    return CopyRaceInfo(byFile[string.upper(clientFileString)])
end

function Unit.GetRaceInfoByName(raceName)
    if type(raceName) ~= "string" or raceName == "" then
        return nil
    end

    local _, _, _, byName = BuildRaceInfoCaches()
    return CopyRaceInfo(byName[raceName])
end

function Unit.GetRaceToken(unit)
    if not UnitRace then return nil end

    local ok, _, raceToken = pcall(UnitRace, unit or "player")
    if not ok
        or IsSecretValue(raceToken)
        or type(raceToken) ~= "string"
        or raceToken == "" then
        return nil
    end

    return string.upper(raceToken)
end

function Unit.UnitClass(unit)
    if UnitClass then
        return UnitClass(unit)
    end

    return nil
end

function Unit.UnitClassBase(unit)
    if UnitClassBase then
        return UnitClassBase(unit)
    end

    if UnitClass then
        local _, classFilename, classID = UnitClass(unit)
        return classFilename, classID
    end

    return nil
end

function Unit.GetClassToken(unit)
    if UnitClass then
        local ok, _, classFilename = pcall(UnitClass, unit)
        if ok and not IsSecretValue(classFilename) then
            return classFilename
        end
    end

    if UnitClassBase then
        local ok, classFilename = pcall(UnitClassBase, unit)
        if ok and not IsSecretValue(classFilename) then
            return classFilename
        end
    end

    return nil
end

function Unit.GetPlayerShapeshiftFormID()
    if type(GetShapeshiftFormID) ~= "function" then return nil end
    local ok, formID = pcall(GetShapeshiftFormID)
    if not ok or IsSecretValue(formID) or type(formID) ~= "number" then
        return nil
    end
    return math.floor(formID)
end

function Unit.GetPowerType(unit)
    if type(UnitPowerType) ~= "function" then return nil, nil end
    local ok, powerType, powerToken = pcall(UnitPowerType, unit or "player")
    if not ok or IsSecretValue(powerType) or IsSecretValue(powerToken) then
        return nil, nil
    end
    if type(powerType) ~= "number" then powerType = nil end
    if type(powerToken) ~= "string" then powerToken = nil end
    return powerType, powerToken
end

function Unit.GetUnitClassColor(unit)
    local classToken = Unit.GetClassToken(unit)
    if not classToken then
        return nil
    end
    return Unit.GetClassColor(classToken)
end

function Unit.UnitTreatAsPlayerForDisplay(unit)
    if UnitTreatAsPlayerForDisplay then
        return UnitTreatAsPlayerForDisplay(unit) == true
    end

    return false
end

function Unit.UnitName(unit)
    if UnitName then
        return UnitName(unit)
    end

    return nil
end

function Unit.UnitFullName(unit)
    if UnitFullName then
        return UnitFullName(unit)
    end

    if UnitName then
        return UnitName(unit)
    end

    return nil
end

function Unit.GetDisplayNameInfo(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end

    local nameRaw, realmRaw
    if UnitFullName then
        local ok, name, realm = pcall(UnitFullName, unit)
        if ok then
            nameRaw = name
            realmRaw = realm
        end
    end
    if not IsSecretValue(nameRaw) and nameRaw == nil and UnitName then
        local ok, name, realm = pcall(UnitName, unit)
        if ok then
            nameRaw = name
            realmRaw = realm
        end
    end

    local name = not IsSecretValue(nameRaw) and nameRaw or nil
    local realm = not IsSecretValue(realmRaw) and realmRaw or nil
    local displayName
    if type(name) == "string" and name ~= "" then
        if type(realm) == "string" and realm ~= "" then
            displayName = name .. "-" .. realm
        else
            displayName = name
        end
    end

    local displayNameRaw = displayName or nameRaw
    if not IsSecretValue(displayNameRaw) and displayNameRaw == nil then
        return nil
    end

    return {
        unit = unit,
        exists = SafeBool(UnitExists, unit),
        name = displayName,
        displayName = displayName,
        nameRaw = nameRaw,
        displayNameRaw = displayNameRaw,
        realm = realm,
        realmRaw = realmRaw,
        classToken = Unit.GetClassToken(unit),
    }
end

function Unit.GetNormalizedRealmName()
    if GetNormalizedRealmName then
        local ok, realm = pcall(GetNormalizedRealmName)
        if ok then
            return realm
        end
    end

    return nil
end

function Unit.GetRealmName()
    if GetRealmName then
        local ok, realm = pcall(GetRealmName)
        if ok then
            return realm
        end
    end

    return nil
end

function Unit.UnitFactionGroup(unit)
    if UnitFactionGroup then
        return UnitFactionGroup(unit)
    end

    return nil
end

function Unit.UnitGUID(unit)
    if UnitGUID then
        return UnitGUID(unit)
    end

    return nil
end

function Unit.UnitExists(unit)
    if UnitExists then
        return UnitExists(unit)
    end

    return false
end

function Unit.Exists(unit)
    return SafeBool(UnitExists, unit) == true
end

function Unit.IsDead(unit)
    return SafeBool(UnitIsDead, unit) == true
end

function Unit.IsFriend(unit, otherUnit)
    return SafeBool(UnitIsFriend, otherUnit or "player", unit) == true
end

function Unit.CanAttack(unit, otherUnit)
    return SafeBool(UnitCanAttack, otherUnit or "player", unit)
end

function Unit.IsPlayer(unit)
    return SafeBool(UnitIsPlayer, unit) == true
end

function Unit.IsMinion(unit)
    return SafeBool(UnitIsMinion, unit) == true
end

function Unit.IsOtherPlayersPet(unit)
    return SafeBool(UnitIsOtherPlayersPet, unit) == true
end

function Unit.IsBattlePet(unit)
    return SafeBool(UnitIsBattlePet, unit) == true
end

function Unit.IsOtherPlayersBattlePet(unit)
    return SafeBool(UnitIsOtherPlayersBattlePet, unit) == true
end

function Unit.IsBattlePetCompanion(unit)
    return SafeBool(UnitIsBattlePetCompanion, unit) == true
end

function Unit.IsUnit(unit, otherUnit)
    return SafeBool(UnitIsUnit, unit, otherUnit) == true
end

function Unit.Reaction(unit, otherUnit)
    return SafeValue(UnitReaction, unit, otherUnit or "player")
end

function Unit.Name(unit)
    return SafeValue(UnitName, unit)
end

function Unit.CreatureType(unit)
    return SafeValue(UnitCreatureType, unit)
end

function Unit.Classification(unit)
    return SafeValue(UnitClassification, unit)
end

function Unit.GetGUIDType(unit)
    local guid = SafeValue(UnitGUID, unit)

    if type(guid) ~= "string" or guid == "" then
        return nil
    end

    local ok, guidType = pcall(function()
        return guid:match("^([^-]+)") or guid
    end)

    if ok and not IsSecretValue(guidType) then
        return guidType
    end

    return nil
end

function Unit.GetPlayerInfoByGUID(guid)
    if type(guid) ~= "string" or guid == "" or not GetPlayerInfoByGUID then
        return nil
    end

    local ok, localizedClass, classFile, localizedRace, raceFile, sex, name, realm = pcall(GetPlayerInfoByGUID, guid)
    if not ok then
        return nil
    end

    return {
        localizedClass = localizedClass,
        classFile = classFile,
        localizedRace = localizedRace,
        raceFile = raceFile,
        sex = sex,
        gender = sex,
        name = name,
        realm = realm,
    }
end

local function SafeAuraSpellID(aura)
    if type(aura) ~= "table" then return nil end

    local ok, value = pcall(function()
        return aura.spellId or aura.spellID
    end)
    if not ok or value == nil or IsSecretValue(value) then
        return nil
    end

    local okNumber, numberValue = pcall(tonumber, value)
    if okNumber and numberValue ~= nil and not IsSecretValue(numberValue) then
        return numberValue
    end
    return nil
end

local function FindUnitAuraByFilter(unit, spellID, filter)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        return nil
    end

    local targetSpellID = tonumber(spellID)
    if not targetSpellID then
        return nil
    end

    for index = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if not ok or not aura then
            break
        end

        if SafeAuraSpellID(aura) == targetSpellID then
            return aura
        end
    end
    return nil
end

function Unit.FindUnitAuraBySpellID(unit, spellID)
    if not unit or spellID == nil then
        return nil
    end

    return FindUnitAuraByFilter(unit, spellID, "HELPFUL")
        or FindUnitAuraByFilter(unit, spellID, "HARMFUL")
end

local function ReadExactAura(func, ...)
    if type(func) ~= "function" then return nil, "aura-api-unavailable" end
    local ok, aura = pcall(func, ...)
    if not ok then return nil, "aura-query-failed" end
    if IsSecretValue(aura) then return nil, "aura-result-secret" end
    return aura, nil
end

function Unit.GetUnitAuraBySpellID(unit, spellID)
    if not unit or spellID == nil then
        return nil
    end

    if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
        return ReadExactAura(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
    end
    return nil, "aura-api-unavailable"
end

function Unit.GetPlayerAuraBySpellID(spellID)
    if spellID == nil then
        return nil
    end

    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return ReadExactAura(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    end
    if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
        return ReadExactAura(C_UnitAuras.GetUnitAuraBySpellID, "player", spellID)
    end
    return nil, "aura-api-unavailable"
end

function Unit.GetMaxPlayerLevel()
    if GetMaxPlayerLevel then
        local ok, level = pcall(GetMaxPlayerLevel)
        if ok and tonumber(level) then
            return tonumber(level)
        end
    end

    if MAX_PLAYER_LEVEL_TABLE and GetExpansionLevel then
        local ok, expansionLevel = pcall(GetExpansionLevel)
        local level = ok and MAX_PLAYER_LEVEL_TABLE[expansionLevel] or nil
        if tonumber(level) then
            return tonumber(level)
        end
    end

    if tonumber(MAX_PLAYER_LEVEL) then
        return tonumber(MAX_PLAYER_LEVEL)
    end

    return nil
end

local function SafeNumberValue(value)
    if IsSecretValue(value) or value == nil then
        return nil
    end

    local ok, numberValue = pcall(tonumber, value)
    if ok and not IsSecretValue(numberValue) and numberValue ~= nil then
        return numberValue
    end
    return nil
end

local function ReadAuraField(aura, key)
    if type(aura) ~= "table" then return nil, false end
    local ok, value = pcall(function()
        return aura[key]
    end)
    if not ok then return nil, false end
    if IsSecretValue(value) then return nil, true end
    return value, false
end

local function ReadAuraIdentity(aura)
    if IsSecretValue(aura) then return nil, "aura-result-secret" end
    if type(aura) ~= "table" then return nil, "aura-result-invalid" end

    local spellID, spellSecret = ReadAuraField(aura, "spellId")
    if spellID == nil and not spellSecret then
        spellID, spellSecret = ReadAuraField(aura, "spellID")
    end
    local auraInstanceID, instanceSecret = ReadAuraField(
        aura,
        "auraInstanceID"
    )
    local sourceUnit, sourceSecret = ReadAuraField(aura, "sourceUnit")

    spellID = SafeNumberValue(spellID)
    if spellID and spellID <= 0 then spellID = nil end
    auraInstanceID = SafeNumberValue(auraInstanceID)
    if auraInstanceID and (auraInstanceID <= 0
        or auraInstanceID % 1 ~= 0) then
        auraInstanceID = nil
    end
    if type(sourceUnit) ~= "string" or sourceUnit == "" then
        sourceUnit = nil
    end

    local identity = {
        spellID = spellID,
        auraInstanceID = auraInstanceID,
        sourceUnit = sourceUnit,
    }
    local secret = spellSecret or instanceSecret or sourceSecret
    if not spellID and not auraInstanceID and not sourceUnit then
        return nil, secret and "aura-result-secret"
            or "aura-identity-unavailable"
    end
    return identity, secret and "aura-result-secret" or nil
end

local function QueryAuraIdentity(func, ...)
    if type(func) ~= "function" then return nil, "aura-api-unavailable" end
    local ok, aura = pcall(func, ...)
    if not ok then return nil, "aura-query-failed" end
    if aura == nil then return nil, "aura-absent" end
    return ReadAuraIdentity(aura)
end

function Unit.ReadAuraIdentityByIndex(unit, index, filter)
    local auraAPI = C_UnitAuras
    return QueryAuraIdentity(
        auraAPI and auraAPI.GetAuraDataByIndex,
        unit,
        index,
        filter
    )
end

function Unit.ReadAuraIdentityByInstance(unit, auraInstanceID)
    local auraAPI = C_UnitAuras
    return QueryAuraIdentity(
        auraAPI and auraAPI.GetAuraDataByAuraInstanceID,
        unit,
        auraInstanceID
    )
end

local function AddAuraDisplayLookupEntry(lookup, aura)
    if IsSecretValue(aura) or type(aura) ~= "table" then
        return false, "aura-result-secret"
    end

    local spellID, spellSecret = ReadAuraField(aura, "spellId")
    if spellID == nil and not spellSecret then
        spellID, spellSecret = ReadAuraField(aura, "spellID")
    end
    local icon, iconSecret = ReadAuraField(aura, "icon")
    local applications, applicationsSecret = ReadAuraField(
        aura,
        "applications"
    )
    local duration, durationSecret = ReadAuraField(aura, "duration")
    local expirationTime, expirationSecret = ReadAuraField(
        aura,
        "expirationTime"
    )
    if spellSecret or iconSecret or applicationsSecret
        or durationSecret or expirationSecret then
        return false, "aura-result-secret"
    end

    spellID = SafeNumberValue(spellID)
    applications = SafeNumberValue(applications) or 0
    duration = SafeNumberValue(duration)
    expirationTime = SafeNumberValue(expirationTime)
    if not spellID or spellID <= 0 or not duration or duration <= 0
        or not expirationTime then
        return false, "aura-display-unavailable"
    end
    if type(icon) ~= "number" and type(icon) ~= "string" then icon = nil end

    local existing = lookup[spellID]
    if existing and existing.expirationTime >= expirationTime then
        return true
    end
    lookup[spellID] = {
        icon = icon,
        applications = applications,
        duration = duration,
        expirationTime = expirationTime,
        start = expirationTime - duration,
    }
    return true
end

local function AddLegacyAuraDisplayLookupEntry(
    lookup,
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k
)
    if IsSecretValue(a) or IsSecretValue(b) or IsSecretValue(c)
        or IsSecretValue(d) or IsSecretValue(e) or IsSecretValue(f)
        or IsSecretValue(g) or IsSecretValue(h) or IsSecretValue(i)
        or IsSecretValue(j) or IsSecretValue(k) then
        return false, "aura-result-secret"
    end

    local spellID = SafeNumberValue(j) or SafeNumberValue(k)
    local icon = b
    if SafeNumberValue(k) then icon = c end
    local applications = SafeNumberValue(c) or SafeNumberValue(d)
    local duration = SafeNumberValue(e) or SafeNumberValue(f)
    local expirationTime = SafeNumberValue(f) or SafeNumberValue(g)
    if not spellID or not duration or duration <= 0 or not expirationTime then
        return false, "aura-display-unavailable"
    end
    local existing = lookup[spellID]
    if existing and existing.expirationTime >= expirationTime then return true end
    lookup[spellID] = {
        icon = icon,
        applications = applications or 0,
        duration = duration,
        expirationTime = expirationTime,
        start = expirationTime - duration,
    }
    return true
end

function Unit.FillPlayerAuraDisplayLookup(reuse)
    local lookup = type(reuse) == "table" and reuse or {}
    for key in pairs(lookup) do lookup[key] = nil end

    local restricted = false
    local queryFailed = false
    local auraUtil = _G.AuraUtil
    if type(auraUtil) == "table"
        and type(auraUtil.ForEachAura) == "function" then
        for pass = 1, 2 do
            local filter = pass == 1 and "HELPFUL" or "HARMFUL"
            local ok = pcall(
                auraUtil.ForEachAura,
                "player",
                filter,
                nil,
                function(aura)
                    local _, code = AddAuraDisplayLookupEntry(lookup, aura)
                    restricted = restricted or code == "aura-result-secret"
                end,
                true
            )
            queryFailed = queryFailed or not ok
        end
    else
        local foundReader = false
        for pass = 1, 2 do
            local reader = pass == 1 and _G.UnitBuff or _G.UnitDebuff
            if type(reader) == "function" then
                foundReader = true
                for index = 1, 40 do
                    local ok, a, b, c, d, e, f, g, h, i, j, k = pcall(
                        reader,
                        "player",
                        index
                    )
                    if not ok then
                        queryFailed = true
                        break
                    end
                    if a == nil then break end
                    local _, code = AddLegacyAuraDisplayLookupEntry(
                        lookup,
                        a,
                        b,
                        c,
                        d,
                        e,
                        f,
                        g,
                        h,
                        i,
                        j,
                        k
                    )
                    restricted = restricted or code == "aura-result-secret"
                end
            end
        end
        if not foundReader then return lookup, "aura-api-unavailable" end
    end

    if restricted then return lookup, "aura-result-secret" end
    if queryFailed then return lookup, "aura-query-failed" end
    return lookup, nil
end

function Unit.ReadPlayerAuraDisplay(spellIDs, state)
    state = type(state) == "table" and state or {}
    if type(spellIDs) ~= "table" then spellIDs = { spellIDs } end

    local aura
    local matchedSpellID
    local queryFailed = false
    for index = 1, #spellIDs do
        local spellID = SafeNumberValue(spellIDs[index])
        if spellID then
            local code
            aura, code = Unit.GetPlayerAuraBySpellID(spellID)
            queryFailed = queryFailed or code ~= nil
            if aura then
                matchedSpellID = spellID
                break
            end
        end
    end

    local secret = false
    local icon
    local duration = 0
    local expirationTime = 0
    local displayCount
    local modRate = 1
    if aura then
        local value
        local protected
        value, protected = ReadAuraField(aura, "icon")
        secret = secret or protected
        if type(value) == "number" or type(value) == "string" then
            icon = value
        end
        value, protected = ReadAuraField(aura, "duration")
        secret = secret or protected
        duration = SafeNumberValue(value) or 0
        value, protected = ReadAuraField(aura, "expirationTime")
        secret = secret or protected
        expirationTime = SafeNumberValue(value) or 0
        value, protected = ReadAuraField(aura, "applications")
        secret = secret or protected
        displayCount = SafeNumberValue(value)
        if displayCount and displayCount <= 1 then displayCount = nil end
        value, protected = ReadAuraField(aura, "timeMod")
        secret = secret or protected
        modRate = SafeNumberValue(value) or 1
        local auraSpellID = SafeAuraSpellID(aura)
        if auraSpellID then matchedSpellID = auraSpellID end
    end

    local available = aura ~= nil and secret ~= true
    local resolved = available or (aura == nil and not queryFailed)
    local startTime = duration > 0 and expirationTime > 0
        and (expirationTime - duration) or 0
    local changed = state.sourceKind ~= "aura"
        or state.spellID ~= matchedSpellID
        or state.icon ~= icon
        or state.startTime ~= startTime
        or state.duration ~= duration
        or state.modRate ~= modRate
        or state.displayCount ~= displayCount
        or state.available ~= available
        or state.resolved ~= resolved
        or state.isEnabled ~= true
        or state.secret ~= secret

    state.sourceKind = "aura"
    state.spellID = matchedSpellID
    state.icon = icon
    state.startTime = startTime
    state.duration = duration
    state.modRate = modRate
    state.displayCount = displayCount
    state.available = available
    state.resolved = resolved
    state.isEnabled = true
    state.secret = secret
    return state, changed
end

local function GetRangeCheckLibrary()
    local libStub = _G.LibStub
    if type(libStub) ~= "table" then
        return nil
    end

    local ok, lib
    if type(libStub.GetLibrary) == "function" then
        ok, lib = pcall(libStub.GetLibrary, libStub, "LibRangeCheck-3.0", true)
    else
        ok, lib = pcall(libStub, "LibRangeCheck-3.0", true)
    end

    if ok and type(lib) == "table" and type(lib.GetRange) == "function" then
        return lib
    end
    return nil
end

local function SafeUnitDistanceSquared(unit)
    if type(UnitDistanceSquared) ~= "function" then
        return nil
    end

    local ok, distanceSquared, checkedDistance = pcall(UnitDistanceSquared, unit)
    if not ok or checkedDistance ~= true then
        return nil
    end

    distanceSquared = SafeNumberValue(distanceSquared)
    if not distanceSquared or distanceSquared < 0 then
        return nil
    end

    return math.sqrt(distanceSquared)
end

local function SafeInteractDistance(unit, index)
    if type(CheckInteractDistance) ~= "function" then
        return nil, false
    end

    local ok, result = pcall(CheckInteractDistance, unit, index)
    if ok and not IsSecretValue(result) then
        return result == true, true
    end
    return nil, false
end

local function GetInteractRangeEstimate(unit)
    local checked = false
    local inDuelRange, checkedDuel = SafeInteractDistance(unit, 3)
    local inTradeRange, checkedTrade = SafeInteractDistance(unit, 2)
    checked = checked or checkedDuel or checkedTrade
    if inDuelRange == true or inTradeRange == true then
        return nil, 10, "InteractDistance"
    end

    local inInspectRange, checkedInspect = SafeInteractDistance(unit, 1)
    local inFollowRange, checkedFollow = SafeInteractDistance(unit, 4)
    checked = checked or checkedInspect or checkedFollow
    if inInspectRange == true or inFollowRange == true then
        return nil, 30, "InteractDistance"
    end

    if checked then
        return 30, nil, "InteractDistance"
    end
    return nil, nil, nil
end

function Unit.GetRangeEstimate(unit, checkVisible, noItems, maxCacheAge)
    if type(unit) ~= "string" or unit == "" then
        return nil, nil, nil
    end
    if not Unit.Exists(unit) then
        return nil, nil, nil
    end
    if checkVisible and UnitIsVisible and SafeBool(UnitIsVisible, unit) ~= true then
        return nil, nil, nil
    end

    local lib = GetRangeCheckLibrary()
    if lib then
        local ok, minRange, maxRange = pcall(lib.GetRange, lib, unit, checkVisible, noItems, maxCacheAge)
        if ok then
            minRange = SafeNumberValue(minRange)
            maxRange = SafeNumberValue(maxRange)
            if minRange or maxRange then
                return minRange, maxRange, "LibRangeCheck"
            end
        end
    end

    if YUI.IsRetail then
        return nil, nil, nil
    end

    local yards = SafeUnitDistanceSquared(unit)
    if yards then
        return yards, yards, "UnitDistanceSquared"
    end

    return GetInteractRangeEstimate(unit)
end

local function SafeRawValue(value)
    if IsSecretValue(value) or value == nil then
        return nil
    end
    return value
end

-- Raw display values may be secret; consumers must only pass them to UI setter APIs.
local function RawDisplayValue(value)
    if value == nil then
        return nil
    end
    return value
end

local function FirstSafeRawValue(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if not IsSecretValue(value) and value ~= nil then
            return value
        end
    end
    return nil
end

local function FirstRawDisplayValue(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function FirstSafeNumberValue(...)
    for i = 1, select("#", ...) do
        local numberValue = SafeNumberValue(select(i, ...))
        if numberValue ~= nil then
            return numberValue
        end
    end
    return nil
end

local function SafeInterruptibleFlag(value)
    if IsSecretValue(value) then
        return nil, false
    end
    if value == nil then
        return nil, false
    end
    if value == true then
        return true, true
    end
    if value == false then
        return false, true
    end
    return value and true or false, true
end

local function SafeDurationObject(func, unit)
    if type(func) ~= "function" then
        return nil
    end

    local ok, durationObject = pcall(func, unit)
    if ok then
        return durationObject
    end
    return nil
end

local function SafeDurationNumber(durationObject, methodName)
    if durationObject == nil or type(methodName) ~= "string" then
        return nil
    end

    local ok, value = pcall(function()
        local method = durationObject[methodName]
        if type(method) ~= "function" then
            return nil
        end
        return method(durationObject)
    end)

    if ok and not IsSecretValue(value) and value ~= nil then
        local convertOK, numberValue = pcall(tonumber, value)
        if convertOK and not IsSecretValue(numberValue) then
            return numberValue
        end
    end
    return nil
end

local function ApplyDurationClock(castInfo, durationObject)
    if not castInfo then
        return nil
    end

    durationObject = durationObject or castInfo.durationObject
    if durationObject ~= nil then
        castInfo.durationObject = durationObject

        local total = SafeDurationNumber(durationObject, "GetTotalDuration")
        local remaining = SafeDurationNumber(durationObject, "GetRemainingDuration")
        local elapsed = SafeDurationNumber(durationObject, "GetElapsedDuration")

        if total and total >= 0 then
            castInfo.totalSeconds = castInfo.totalSeconds or total
        end
        if remaining and remaining >= 0 then
            castInfo.remainingSeconds = remaining
        end
        if elapsed and elapsed >= 0 then
            castInfo.elapsedSeconds = elapsed
        end
        if castInfo.totalSeconds and not castInfo.elapsedSeconds and castInfo.remainingSeconds then
            castInfo.elapsedSeconds = math.max(0, castInfo.totalSeconds - castInfo.remainingSeconds)
        end
        if castInfo.totalSeconds and not castInfo.remainingSeconds and castInfo.elapsedSeconds then
            castInfo.remainingSeconds = math.max(0, castInfo.totalSeconds - castInfo.elapsedSeconds)
        end
    end

    if castInfo.startTimeMS and castInfo.endTimeMS and castInfo.endTimeMS >= castInfo.startTimeMS then
        local now = GetTime and GetTime() or 0
        castInfo.totalSeconds = math.max(0, (castInfo.endTimeMS - castInfo.startTimeMS) / 1000)
        castInfo.remainingSeconds = math.max(0, (castInfo.endTimeMS / 1000) - now)
        castInfo.elapsedSeconds = math.max(0, now - (castInfo.startTimeMS / 1000))
    end

    return castInfo
end

local function NormalizeCastInfoTable(unit, info, isChannel)
    if type(info) ~= "table" then
        return nil
    end

    local notInterruptibleRaw = FirstRawDisplayValue(info.notInterruptible, info.uninterruptible)
    local notInterruptible, notInterruptibleKnown = SafeInterruptibleFlag(notInterruptibleRaw)
    local startTimeMS = FirstSafeNumberValue(info.startTimeMS, info.startTime, info.startTimeMilliseconds)
    local endTimeMS = FirstSafeNumberValue(info.endTimeMS, info.endTime, info.endTimeMilliseconds)
    local texture = FirstSafeRawValue(info.texture, info.textureID, info.icon, info.iconID)
    local textureRaw = FirstRawDisplayValue(info.texture, info.textureID, info.icon, info.iconID)
    return ApplyDurationClock({
        unit = unit,
        name = FirstSafeRawValue(info.name, info.spellName),
        displayName = FirstSafeRawValue(info.displayName, info.text),
        nameRaw = FirstRawDisplayValue(info.name, info.spellName),
        displayNameRaw = FirstRawDisplayValue(info.displayName, info.text, info.name, info.spellName),
        texture = texture,
        displayTexture = texture,
        textureRaw = textureRaw,
        displayTextureRaw = textureRaw,
        spellID = FirstSafeRawValue(info.spellID, info.spellId, info.castingSpellID),
        spellIDRaw = FirstRawDisplayValue(info.spellID, info.spellId, info.castingSpellID),
        castID = FirstSafeRawValue(info.castID, info.castId, info.castGUID),
        castIDRaw = FirstRawDisplayValue(info.castID, info.castId, info.castGUID),
        isChannel = isChannel == true,
        startTimeMS = startTimeMS,
        endTimeMS = endTimeMS,
        durationObject = SafeRawValue(info.durationObject),
        notInterruptibleRaw = notInterruptibleRaw,
        visualNotInterruptibleRaw = notInterruptibleRaw,
        notInterruptibleKnown = notInterruptibleKnown == true,
        notInterruptible = notInterruptible == true,
    })
end

local function ReadCastInfo(unit, isChannel)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end

    local func = isChannel and UnitChannelInfo or UnitCastingInfo
    local durationObject = SafeDurationObject(isChannel and UnitChannelDuration or UnitCastingDuration, unit)

    if type(func) ~= "function" then
        if durationObject == nil then
            return nil
        end
        return ApplyDurationClock({
            unit = unit,
            isChannel = isChannel == true,
            durationObject = durationObject,
            notInterruptibleKnown = false,
            notInterruptible = false,
            visualNotInterruptibleRaw = nil,
        }, durationObject)
    end

    local ok, name, text, texture, startTimeMS, endTimeMS, isTradeSkill, arg7, arg8, arg9 = pcall(func, unit)
    if not ok then
        if durationObject == nil then
            return nil
        end
        return ApplyDurationClock({
            unit = unit,
            isChannel = isChannel == true,
            durationObject = durationObject,
            notInterruptibleKnown = false,
            notInterruptible = false,
            visualNotInterruptibleRaw = nil,
        }, durationObject)
    end

    local nameIsSecret = IsSecretValue(name)
    if not nameIsSecret and name == nil then
        if durationObject == nil then
            return nil
        end
        return ApplyDurationClock({
            unit = unit,
            isChannel = isChannel == true,
            durationObject = durationObject,
            notInterruptibleKnown = false,
            notInterruptible = false,
            visualNotInterruptibleRaw = nil,
        }, durationObject)
    end

    if not nameIsSecret and type(name) == "table" then
        local castInfo = NormalizeCastInfoTable(unit, name, isChannel)
        if castInfo and not castInfo.durationObject then
            castInfo.durationObject = durationObject
        end
        return ApplyDurationClock(castInfo, durationObject)
    end

    local startCandidate = SafeNumberValue(startTimeMS)
    local endCandidate = SafeNumberValue(endTimeMS)
    local nextCandidate = SafeNumberValue(isTradeSkill)
    local shiftedLegacyShape = endCandidate ~= nil
        and nextCandidate ~= nil
        and (
            startCandidate == nil
            or (startCandidate < 10000000 and nextCandidate >= endCandidate)
        )

    local castID, notInterruptibleRaw, spellID
    if shiftedLegacyShape then
        texture, startTimeMS, endTimeMS, isTradeSkill = startTimeMS, endTimeMS, isTradeSkill, arg7
        notInterruptibleRaw = arg8
        spellID = arg9
    elseif isChannel then
        notInterruptibleRaw = arg7
        spellID = arg8
    else
        castID = arg7
        notInterruptibleRaw = arg8
        spellID = arg9
    end

    local safeName = SafeRawValue(name)
    if safeName == nil and durationObject == nil and not nameIsSecret then
        return nil
    end

    local safeDisplayName = SafeRawValue(text)
    local safeTexture = SafeRawValue(texture)
    local safeSpellID = SafeRawValue(spellID)
    local safeCastID = SafeRawValue(castID)
    local safeStartTimeMS = SafeNumberValue(startTimeMS)
    local safeEndTimeMS = SafeNumberValue(endTimeMS)
    local notInterruptible, notInterruptibleKnown = SafeInterruptibleFlag(notInterruptibleRaw)

    return ApplyDurationClock({
        unit = unit,
        name = safeName,
        displayName = safeDisplayName,
        nameRaw = RawDisplayValue(name),
        displayNameRaw = FirstRawDisplayValue(text, name),
        texture = safeTexture,
        displayTexture = safeTexture,
        textureRaw = RawDisplayValue(texture),
        displayTextureRaw = RawDisplayValue(texture),
        spellID = safeSpellID,
        spellIDRaw = RawDisplayValue(spellID),
        castID = safeCastID,
        castIDRaw = RawDisplayValue(castID),
        isChannel = isChannel == true,
        startTimeMS = safeStartTimeMS,
        endTimeMS = safeEndTimeMS,
        durationObject = durationObject,
        notInterruptibleRaw = notInterruptibleRaw,
        visualNotInterruptibleRaw = notInterruptibleRaw,
        notInterruptibleKnown = notInterruptibleKnown == true,
        notInterruptible = notInterruptible == true,
    }, durationObject)
end

function Unit.GetCastInfo(unit)
    return ReadCastInfo(unit, false) or ReadCastInfo(unit, true)
end

function Unit.GetCastingInfo(unit)
    return ReadCastInfo(unit, false)
end

function Unit.GetChannelInfo(unit)
    return ReadCastInfo(unit, true)
end

function Unit.GetSpellTargetInfo(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end

    local shouldDisplay
    if UnitShouldDisplaySpellTargetName then
        shouldDisplay = SafeBool(UnitShouldDisplaySpellTargetName, unit)
        if shouldDisplay == false then
            return nil
        end
    end

    local nameRaw = SafeCall(UnitSpellTargetName, unit)
    local classTokenRaw = SafeCall(UnitSpellTargetClass, unit)
    local name = SafeRawValue(nameRaw)
    local hasRawName = IsSecretValue(nameRaw) or nameRaw ~= nil
    if (type(name) ~= "string" or name == "") and not hasRawName then
        return nil
    end

    return {
        unit = unit,
        name = name,
        displayName = name,
        nameRaw = RawDisplayValue(nameRaw),
        displayNameRaw = RawDisplayValue(nameRaw),
        classToken = SafeRawValue(classTokenRaw),
        classTokenRaw = RawDisplayValue(classTokenRaw),
        shouldDisplay = shouldDisplay ~= false,
    }
end

local function CreatePowerColor(color)
    if type(color) ~= "table" then return nil end
    local r = color.r or color[1]
    local g = color.g or color[2]
    local b = color.b or color[3]
    local a = color.a or color[4]
    if type(r) ~= "number" or type(g) ~= "number"
        or type(b) ~= "number" then
        return nil
    end
    if CreateColor then return CreateColor(r, g, b, a == nil and 1 or a) end
    return nil
end

local function CreateResourceThresholdColorCurve(
    policy,
    structuralMax,
    rawValueDomain
)
    if type(policy) ~= "table" or policy.thresholdColorEnabled ~= true
        or not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then
        return nil
    end
    local thresholds = policy.thresholds
    local low = type(thresholds) == "table" and thresholds.low or nil
    local high = type(thresholds) == "table" and thresholds.high or nil
    local baseColor = CreatePowerColor(policy.fillColor)
    local lowColor = low and CreatePowerColor(low.color) or nil
    local highColor = high and CreatePowerColor(high.color) or nil
    if not baseColor then return nil end

    local discrete = policy.valueKind == "discrete"
    structuralMax = tonumber(structuralMax)
    if discrete and (not structuralMax or structuralMax <= 0) then return nil end
    local domainMax = rawValueDomain == true and structuralMax or 1
    local multiplier = rawValueDomain == true and 1
        or (discrete and (1 / structuralMax) or 0.01)
    local lowAt = low and math.max(0, math.min(domainMax,
        (tonumber(low.value) or 0) * multiplier)) or 0
    local highAt = high and math.max(0, math.min(domainMax,
        (tonumber(high.value) or 0) * multiplier)) or domainMax
    local lowEnabled = low and low.enabled == true and lowColor ~= nil
    local highEnabled = high and high.enabled == true and highColor ~= nil
    if lowEnabled and highEnabled and highAt < lowAt then
        if lowAt >= domainMax then
            lowAt = math.max(0, domainMax - multiplier)
            highAt = domainMax
        else
            highAt = math.min(domainMax, lowAt + multiplier)
        end
    end

    local ok, curve = pcall(C_CurveUtil.CreateColorCurve)
    if not ok or not curve or not curve.AddPoint then return nil end
    local EPSILON = 0.0001
    local function AddPoint(at, color)
        return pcall(curve.AddPoint, curve, at, color)
    end

    if highEnabled and highAt <= 0 then
        if not AddPoint(0, highColor)
            or not AddPoint(domainMax, highColor) then
            return nil
        end
        return curve
    end

    if lowEnabled and highEnabled and highAt == lowAt then
        if not AddPoint(0, lowAt > 0 and lowColor or highColor) then
            return nil
        end
        if lowAt > 0 then
            local beforeHigh = math.max(0, highAt - EPSILON)
            if beforeHigh > 0 and not AddPoint(beforeHigh, lowColor) then
                return nil
            end
            if not AddPoint(highAt, highColor) then return nil end
        end
        if highAt < domainMax and not AddPoint(domainMax, highColor) then
            return nil
        end
        return curve
    end

    local startColor = lowEnabled and lowColor or baseColor
    if not AddPoint(0, startColor) then return nil end

    if lowEnabled and lowAt > 0
        and not AddPoint(lowAt, lowColor) then
        return nil
    end
    if lowEnabled and lowAt < domainMax then
        local afterLow = math.min(domainMax, lowAt + EPSILON)
        local boundaryColor = highEnabled and highAt <= afterLow
            and highColor or baseColor
        if not AddPoint(afterLow, boundaryColor) then
            return nil
        end
    end

    if highEnabled and highAt > lowAt then
        local beforeHigh = math.max(lowAt, highAt - EPSILON)
        if beforeHigh > lowAt and not AddPoint(beforeHigh, baseColor) then
            return nil
        end
        if not AddPoint(highAt, highColor) then return nil end
    elseif highEnabled and not lowEnabled then
        local beforeHigh = math.max(0, highAt - EPSILON)
        if beforeHigh > 0 and not AddPoint(beforeHigh, baseColor) then
            return nil
        end
        if not AddPoint(highAt, highColor) then return nil end
    end

    local endColor = highEnabled and highColor
        or (lowEnabled and lowAt >= domainMax and lowColor or baseColor)
    if (not highEnabled or highAt < domainMax)
        and not AddPoint(domainMax, endColor) then
        return nil
    end
    return curve
end

function Unit.CreatePowerColorCurve(policy, structuralMax)
    return CreateResourceThresholdColorCurve(policy, structuralMax, false)
end

function Unit.CreateResourceValueColorCurve(policy, structuralMax)
    return CreateResourceThresholdColorCurve(policy, structuralMax, true)
end

local function EvaluateResourceValueColor(colorCurve, valueRaw)
    return colorCurve:Evaluate(valueRaw)
end

function Unit.ReadResourceValueColor(valueRaw, colorCurve)
    if not colorCurve or not colorCurve.Evaluate then
        return nil
    end
    if IsSecretValue(valueRaw) or valueRaw == nil then return nil end
    local ok, colorRaw = pcall(
        EvaluateResourceValueColor,
        colorCurve,
        valueRaw
    )
    if not ok then return nil end
    return colorRaw
end

function Unit.ReadPowerColor(unit, powerType, colorCurve)
    if not colorCurve or type(UnitPowerPercent) ~= "function" then return nil end
    unit = type(unit) == "string" and unit ~= "" and unit or "player"
    powerType = type(powerType) == "number" and powerType or nil
    if powerType == nil then return nil end
    local ok, colorRaw = pcall(
        UnitPowerPercent,
        unit,
        powerType,
        false,
        colorCurve
    )
    if not ok then return nil end
    return colorRaw
end

local powerPercentDisplayCurve
local function GetPowerPercentDisplayCurve()
    local shared = _G.CurveConstants and _G.CurveConstants.ScaleTo100
    if shared then return shared end
    if powerPercentDisplayCurve then return powerPercentDisplayCurve end
    if not (C_CurveUtil and type(C_CurveUtil.CreateCurve) == "function") then
        return nil
    end
    local curve = C_CurveUtil.CreateCurve()
    if not curve then return nil end
    if curve.SetType and Enum and Enum.LuaCurveType then
        curve:SetType(Enum.LuaCurveType.Linear)
    end
    if not curve.AddPoint then return nil end
    curve:AddPoint(0, 0)
    curve:AddPoint(1, 100)
    powerPercentDisplayCurve = curve
    return curve
end

function Unit.ReadPowerDisplay(unit, powerType, state, colorCurve)
    state = type(state) == "table" and state or {}
    unit = type(unit) == "string" and unit ~= "" and unit or "player"
    powerType = type(powerType) == "number" and powerType or nil

    local valueOK, valueRaw = false, nil
    local maxOK, maxRaw = false, nil
    if powerType ~= nil and type(UnitPower) == "function" then
        valueOK, valueRaw = pcall(UnitPower, unit, powerType)
    end
    if powerType ~= nil and type(UnitPowerMax) == "function" then
        maxOK, maxRaw = pcall(UnitPowerMax, unit, powerType)
    end

    local valueSecret = valueOK and IsSecretValue(valueRaw) or false
    local maxSecret = maxOK and IsSecretValue(maxRaw) or false
    local valuePresent = valueOK
        and (valueSecret or type(valueRaw) == "number")
    local maxPresent = maxOK
        and (maxSecret or type(maxRaw) == "number")
    local available = valuePresent and maxPresent
    local secret = available and (valueSecret or maxSecret) or false
    local value = not valueSecret and type(valueRaw) == "number"
        and valueRaw or nil
    local maxValue = not maxSecret and type(maxRaw) == "number"
        and maxRaw or nil
    local changed = false

    if state.sourceKind ~= "resource"
        or state.unit ~= unit
        or state.powerType ~= powerType then
        state.sourceKind = "resource"
        state.unit = unit
        state.powerType = powerType
        changed = true
    end
    if state.available ~= available or state.secret ~= secret then
        state.available = available
        state.secret = secret
        changed = true
    end

    if secret then
        state.value = nil
        state.maxValue = nil
        state.opaqueRevision = (state.opaqueRevision or 0) + 1
        changed = true
    else
        if state.value ~= value or state.maxValue ~= maxValue then
            state.value = value
            state.maxValue = maxValue
            changed = true
        end
    end

    state.valueRaw = nil
    if available then state.valueRaw = valueRaw end
    state.maxValueRaw = available and maxRaw or nil
    state.rawValuesAvailable = available
    state.percentRaw = nil
    if secret and type(UnitPowerPercent) == "function" then
        local percentOK, percentRaw = pcall(
            UnitPowerPercent,
            unit,
            powerType,
            false,
            GetPowerPercentDisplayCurve()
        )
        if percentOK then state.percentRaw = percentRaw end
    end
    state.colorRaw = nil
    if secret and colorCurve then
        state.colorRaw = Unit.ReadPowerColor(unit, powerType, colorCurve)
    end
    return state, changed
end

function Unit.ReadPowerPartialFraction(unit, powerType, scale, sourceMode)
    unit = type(unit) == "string" and unit ~= "" and unit or "player"
    powerType = type(powerType) == "number" and powerType or nil
    scale = SafeNumberValue(scale) or 1000
    if powerType == nil or scale <= 0 then return nil end
    local api = sourceMode == "unmodified-power" and UnitPower or UnitPartialPower
    if type(api) ~= "function" then return nil end
    local ok, raw
    if sourceMode == "unmodified-power" then
        ok, raw = pcall(api, unit, powerType, true)
    else
        ok, raw = pcall(api, unit, powerType)
    end
    if not ok then return nil end
    local value = SafeNumberValue(raw)
    if value == nil then return nil end
    if sourceMode == "unmodified-power" then value = value % scale end
    return math.max(0, math.min(1, value / scale))
end

function Unit.ReadChargedPowerPointMask(unit, maxPoints)
    if type(GetUnitChargedPowerPoints) ~= "function" then return nil, false end
    unit = type(unit) == "string" and unit ~= "" and unit or "player"
    maxPoints = SafeNumberValue(maxPoints)
    maxPoints = maxPoints and math.floor(maxPoints) or 10
    if maxPoints < 1 then return nil, false end
    if maxPoints > 20 then maxPoints = 20 end
    local ok, points = pcall(GetUnitChargedPowerPoints, unit)
    if not ok or IsSecretValue(points) or type(points) ~= "table" then
        return nil, false
    end
    local mask = 0
    for index = 1, #points do
        local pointIndex = points[index]
        if IsSecretValue(pointIndex) or type(pointIndex) ~= "number" then
            return nil, false
        end
        pointIndex = math.floor(pointIndex)
        if pointIndex >= 1 and pointIndex <= maxPoints then
            local weight = 2 ^ (pointIndex - 1)
            if math.floor(mask / weight) % 2 == 0 then mask = mask + weight end
        end
    end
    return mask, true
end

local function ReadRawUnitNumber(api, unit)
    if type(api) ~= "function" then return false, nil end
    local ok, value = pcall(api, unit)
    if not ok then return false, nil end
    return IsSecretValue(value) or type(value) == "number", value
end

local function ReadPercentResourceDisplay(
    providerKind,
    unit,
    valueAPI,
    maxScale,
    state
)
    state = type(state) == "table" and state or {}
    unit = type(unit) == "string" and unit ~= "" and unit or "player"
    local valueOK, valueRaw = ReadRawUnitNumber(valueAPI, unit)
    local maxOK, healthRaw = ReadRawUnitNumber(UnitHealthMax, unit)
    local maxRaw = healthRaw
    if maxOK and maxScale ~= 1 then
        local safeHealth = SafeNumberValue(healthRaw)
        maxRaw = safeHealth and (safeHealth * maxScale) or nil
        maxOK = maxRaw ~= nil
    end
    local secret = valueOK and maxOK
        and (IsSecretValue(valueRaw) or IsSecretValue(maxRaw)) or false
    local value
    local safeValue = SafeNumberValue(valueRaw)
    local safeMax = SafeNumberValue(maxRaw)
    if safeValue and safeMax and safeMax > 0 then
        value = math.max(0, math.min(100, safeValue / safeMax * 100))
    end
    local available = valueOK and maxOK
    local changed = state.providerKind ~= providerKind
        or state.unit ~= unit
        or state.available ~= available
        or state.secret ~= secret
        or state.value ~= value
    state.sourceKind = "resource"
    state.providerKind = providerKind
    state.unit = unit
    state.available = available
    state.secret = secret
    state.value = value
    state.maxValue = 100
    state.valueRaw = available and valueRaw or nil
    state.maxValueRaw = available and maxRaw or nil
    state.rawValuesAvailable = available
    -- Stagger/absorb are ratios of two potentially opaque values. There is no
    -- UnitPowerPercent-equivalent API for them, so never retain a stale percent.
    state.percentRaw = nil
    if secret then
        state.opaqueRevision = (state.opaqueRevision or 0) + 1
        changed = true
    end
    return state, changed, available and nil or "resource-unavailable"
end

function Unit.ReadStaggerResourceDisplay(unit, state)
    return ReadPercentResourceDisplay(
        "stagger",
        unit,
        UnitStagger,
        1,
        state
    )
end

function Unit.ReadAbsorbResourceDisplay(unit, capFraction, state)
    capFraction = SafeNumberValue(capFraction) or 0.30
    return ReadPercentResourceDisplay(
        "absorb",
        unit,
        UnitGetTotalAbsorbs,
        capFraction,
        state
    )
end

local function GetAuraRawField(aura, key)
    return aura[key]
end

local function ReadAuraRawField(aura, key)
    if type(aura) ~= "table" then return nil, false end
    local ok, value = pcall(GetAuraRawField, aura, key)
    if not ok then return nil, false end
    return value, IsSecretValue(value)
end

function Unit.ReadAuraDurationResourceDisplay(unit, spellID, state)
    state = type(state) == "table" and state or {}
    unit = type(unit) == "string" and unit ~= "" and unit or "player"
    spellID = SafeNumberValue(spellID)
    if not spellID then return state, false, "invalid-spell" end

    local aura, code = Unit.GetUnitAuraBySpellID(unit, spellID)
    if aura == nil and code == nil then code = "aura-absent" end
    local durationRaw, durationSecret = ReadAuraRawField(aura, "duration")
    local expirationRaw, expirationSecret = ReadAuraRawField(
        aura,
        "expirationTime"
    )
    local modRateRaw = ReadAuraRawField(aura, "timeMod")
    if modRateRaw == nil then modRateRaw = 1 end
    local durationObject = state.durationObject
    if aura and not durationObject
        and C_DurationUtil and C_DurationUtil.CreateDuration then
        local ok, created = pcall(C_DurationUtil.CreateDuration)
        if ok then durationObject = created end
    end
    local bound = false
    if durationObject and durationObject.SetTimeFromEnd
        and durationRaw ~= nil and expirationRaw ~= nil then
        bound = pcall(
            durationObject.SetTimeFromEnd,
            durationObject,
            expirationRaw,
            durationRaw,
            modRateRaw
        ) == true
    end
    local secret = durationSecret or expirationSecret
    local duration = SafeNumberValue(durationRaw)
    local available = aura ~= nil and bound
    local changed = state.providerKind ~= "aura-duration"
        or state.unit ~= unit
        or state.spellID ~= spellID
        or state.available ~= available
        or state.secret ~= secret
        or state.value ~= duration
    state.sourceKind = "resource"
    state.providerKind = "aura-duration"
    state.unit = unit
    state.spellID = spellID
    state.durationObject = durationObject
    state.durationResourceRaw = available and durationObject or nil
    state.available = available
    state.secret = secret
    state.value = duration
    state.maxValue = duration
    state.valueRaw = not secret and available and durationRaw or nil
    state.maxValueRaw = not secret and available and durationRaw or nil
    state.rawValuesAvailable = available and not secret
    if secret then
        state.opaqueRevision = (state.opaqueRevision or 0) + 1
        changed = true
    end
    if available then return state, changed, nil end
    return state, changed, code or "aura-duration-unavailable"
end

function Unit.SupportsFilteredAuraDisplay()
    local auraContainerUtil = _G.C_AuraContainerUtil
    return type(_G.CreateFrame) == "function"
        and type(auraContainerUtil) == "table"
        and type(auraContainerUtil.ProcessCustomAuraButtonApplicationBarOptions)
            == "function"
        and type(auraContainerUtil.ProcessCustomAuraButtonApplicationCountOptions)
            == "function"
end

function Unit.EnsureFilteredAuraDisplay()
    if Unit.SupportsFilteredAuraDisplay() then return true end
    if YUI.IsRetail == false then
        return false, "filtered-aura-display-unsupported-client"
    end

    local system = YUI.API and YUI.API.System
    if not (system and type(system.LoadAddOn) == "function") then
        return false, "filtered-aura-loader-unavailable"
    end
    local ok, loaded = pcall(
        system.LoadAddOn,
        "Blizzard_AuraContainer"
    )
    if not ok or loaded == false then
        return false, "filtered-aura-addon-load-failed"
    end
    if not Unit.SupportsFilteredAuraDisplay() then
        return false, "filtered-aura-display-unavailable"
    end
    return true
end

function Unit.SupportsFilteredAuraDurationDisplay()
    return Unit.SupportsFilteredAuraDisplay()
end

function Unit.IsPlayerHelpfulAuraIdentityTrusted()
    if YUI.IsRetail == false then return true end

    local usingVehicle = SafeBool(_G.UnitUsingVehicle, "player")
    if usingVehicle == true then return false end
    local inVehicle = SafeBool(_G.UnitInVehicle, "player")
    if inVehicle == true then return false end
    if usingVehicle == nil and inVehicle == nil then return false end

    return SafeBool(_G.UnitCanAssist, "player", "player") == true
end

local function NormalizeFilteredAuraSpellIDs(value)
    if type(value) == "number" then value = { value } end
    if type(value) ~= "table" then return nil end
    local result = {}
    for key, candidate in pairs(value) do
        local spellID = type(candidate) == "number" and candidate
            or candidate == true and key or nil
        spellID = SafeNumberValue(spellID)
        if spellID then result[spellID] = true end
    end
    return next(result) and result or nil
end

local function ResolveFilteredAuraBinding(value)
    if type(value) ~= "table" then return value, nil end
    if value.target ~= nil then return value.target, value.options end
    return value, nil
end

local function ApplyFilteredAuraBindings(auraFrame, bindings)
    bindings = type(bindings) == "table" and bindings or {}
    local definitions = {
        { "applicationBar", "SetApplicationBar", true },
        { "applicationCount", "SetApplicationCount", true },
        { "durationBar", "SetDurationBar", true },
        { "durationText", "SetDurationText", true },
        { "durationCooldown", "SetDurationCooldown", false },
        { "icon", "SetIcon", false },
        { "spellName", "SetSpellName", false },
    }
    for index = 1, #definitions do
        local definition = definitions[index]
        local target, options = ResolveFilteredAuraBinding(
            bindings[definition[1]]
        )
        local method = auraFrame[definition[2]]
        if target ~= nil and type(method) == "function" then
            local ok
            if definition[3] then
                ok = pcall(method, auraFrame, target, options)
            else
                ok = pcall(method, auraFrame, target)
            end
            if not ok then return false, definition[1] .. "-bind-failed" end
        end
    end
    return true
end

local function ApplyFilteredAuraContainerLayout(container, layout)
    if type(layout) ~= "table" then return true end
    local definitions = {
        {
            { "SetFlowLayoutAxis", "SetAuraLayoutAxis" },
            { layout.axis },
            1,
        },
        {
            { "SetFlowLayoutAnchorPoint", "SetAuraLayoutAnchorPoint" },
            { layout.anchorPoint },
            1,
        },
        {
            {
                "SetFlowLayoutGrowthDirection",
                "SetAuraLayoutGrowthDirection",
            },
            { layout.horizontalGrowth, layout.verticalGrowth },
            2,
        },
        {
            { "SetFlowLayoutPadding", "SetAuraLayoutPadding" },
            {
                layout.paddingLeft,
                layout.paddingRight,
                layout.paddingTop,
                layout.paddingBottom,
            },
            4,
        },
        {
            {
                "SetFlowLayoutMaximumLineSize",
                "SetAuraLayoutRowWidth",
            },
            { layout.maximumLineSize },
            1,
        },
    }
    for index = 1, #definitions do
        local definition = definitions[index]
        local arguments = definition[2]
        if arguments[1] ~= nil then
            local method
            for methodIndex = 1, #definition[1] do
                method = container[definition[1][methodIndex]]
                if type(method) == "function" then break end
                method = nil
            end
            local ok = true
            if method and definition[3] == 1 then
                ok = pcall(method, container, arguments[1])
            elseif method and definition[3] == 2 then
                ok = pcall(method, container, arguments[1], arguments[2])
            elseif method and definition[3] == 4 then
                ok = pcall(
                    method,
                    container,
                    arguments[1],
                    arguments[2],
                    arguments[3],
                    arguments[4]
                )
            end
            if not ok then
                return false
            end
        end
    end
    return true
end

function Unit.RefreshFilteredAuraDisplay(handle)
    if type(handle) ~= "table" or handle.released == true then
        return false, "filtered-aura-handle-unavailable"
    end
    local container = handle.container
    if not (container and type(container.UpdateAllAuras) == "function") then
        return false, "filtered-aura-refresh-unavailable"
    end
    local ok = pcall(container.UpdateAllAuras, container)
    if not ok then return false, "filtered-aura-refresh-failed" end
    return true
end

function Unit.SetFilteredAuraDisplayIdentitySuppressed(handle, suppressed)
    if type(handle) ~= "table"
        or handle.active ~= true
        or handle.released == true then
        return false, 0
    end
    local proxy = handle.proxy
    if not (proxy and type(proxy.IsShown) == "function"
        and type(proxy.Hide) == "function"
        and type(proxy.Show) == "function") then
        return false, 0
    end

    suppressed = suppressed == true
    if (handle.identitySuppressed == true) == suppressed then
        return false, 0
    end

    if suppressed then
        handle.identitySuppressed = true
        local ok, shown = pcall(proxy.IsShown, proxy)
        handle.identitySuppressedWasShown = ok and shown == true or false
        pcall(proxy.Hide, proxy)
        return true, 0
    end

    local shouldShow = handle.identitySuppressedWasShown == true
    handle.identitySuppressed = nil
    handle.identitySuppressedWasShown = nil
    if shouldShow then
        local ok = pcall(proxy.Show, proxy)
        return true, ok and 1 or 0
    end
    return true, 0
end

function Unit.ReleaseFilteredAuraDisplay(handle)
    if type(handle) ~= "table" or handle.released == true then return false end
    handle.released = true
    local proxy = handle.proxy
    if proxy then
        if proxy.UnregisterAllEvents then
            pcall(proxy.UnregisterAllEvents, proxy)
        elseif handle.contextEvent and proxy.UnregisterEvent then
            pcall(proxy.UnregisterEvent, proxy, handle.contextEvent)
        end
        if proxy.SetScript then
            pcall(proxy.SetScript, proxy, "OnEvent", nil)
            pcall(proxy.SetScript, proxy, "OnShow", nil)
        end
    end
    if proxy and proxy.Hide then
        pcall(proxy.Hide, proxy)
    elseif handle.container and handle.container.Hide then
        pcall(handle.container.Hide, handle.container)
    end
    handle.active = false
    handle.identitySuppressed = nil
    handle.identitySuppressedWasShown = nil
    return true
end

function Unit.CreateFilteredAuraDisplay(parent, spec)
    if not parent or not Unit.SupportsFilteredAuraDisplay() then
        return nil, "filtered-aura-display-unavailable"
    end
    spec = type(spec) == "table" and spec or {}
    local unit = type(spec.unit) == "string" and spec.unit ~= ""
        and spec.unit or "player"
    local groups = type(spec.groups) == "table" and spec.groups or {}
    local slots
    if type(spec.slots) == "table" then
        slots = spec.slots
    elseif #groups > 0 then
        slots = {}
    else
        slots = { spec }
    end
    if #slots == 0 and #groups == 0 then
        return nil, "filtered-aura-displays-empty"
    end

    local createFrame = _G.CreateFrame
    local proxy = createFrame("Frame", nil, parent)
    proxy:SetAllPoints(parent)
    local ok, container = pcall(
        createFrame,
        "AuraContainer",
        nil,
        proxy,
        "CustomAuraContainerTemplate"
    )
    if not ok or not container then
        proxy:Hide()
        return nil, "filtered-aura-container-create-failed"
    end
    if #groups > 0 then
        container:SetPoint(
            spec.point or "TOPLEFT",
            proxy,
            spec.relativePoint or spec.point or "TOPLEFT",
            tonumber(spec.offsetX) or 0,
            tonumber(spec.offsetY) or 0
        )
        container:SetSize(1, 1)
        if not ApplyFilteredAuraContainerLayout(container, spec.layout) then
            proxy:Hide()
            return nil, "filtered-aura-layout-failed"
        end
    else
        container:SetAllPoints(proxy)
    end

    local handle = {
        container = container,
        proxy = proxy,
        frames = {},
        unit = unit,
        hasHelpfulFilter = false,
        hasHarmfulFilter = false,
        active = false,
        released = false,
    }

    local function BuildInitializer(initializeFrame, bindings, index)
        return function(auraFrame)
            handle.frames[#handle.frames + 1] = auraFrame
            local resolvedBindings = bindings
            if type(initializeFrame) == "function" then
                resolvedBindings = initializeFrame(auraFrame, index, handle)
                    or resolvedBindings
            elseif auraFrame.SetAllPoints then
                auraFrame:SetAllPoints(container)
            end
            local bound, code = ApplyFilteredAuraBindings(
                auraFrame,
                resolvedBindings
            )
            if not bound then error(code) end
            if auraFrame.SetMouseClickEnabled then
                auraFrame:SetMouseClickEnabled(false)
            end
            if auraFrame.SetMouseMotionEnabled then
                auraFrame:SetMouseMotionEnabled(false)
            end
            if auraFrame.EnableMouse then auraFrame:EnableMouse(false) end
        end
    end

    local function BuildCandidateFilters(display)
        local spellIDs = NormalizeFilteredAuraSpellIDs(
            display.spellIDs or display.spellID
                or spec.spellIDs or spec.spellID
        )
        if not spellIDs then return nil end
        local candidateFilters = { includeSpellIDs = spellIDs }
        if display.requirePlayerSource == true
            or spec.requirePlayerSource == true then
            candidateFilters.isFromPlayerOrPlayerPet = true
        end
        return candidateFilters
    end

    for index = 1, #slots do
        local slot = type(slots[index]) == "table" and slots[index] or {}
        local candidateFilters = BuildCandidateFilters(slot)
        if not candidateFilters then
            Unit.ReleaseFilteredAuraDisplay(handle)
            return nil, "invalid-spell"
        end
        local filter = slot.filter or spec.filter
        filter = filter == "HARMFUL" and "HARMFUL" or "HELPFUL"
        if filter == "HARMFUL" then
            handle.hasHarmfulFilter = true
        else
            handle.hasHelpfulFilter = true
        end
        local initializeFrame = slot.initializeFrame or spec.initializeFrame
        local bindings = slot.bindings or spec.bindings
        local slotOK, auraFrame = pcall(
            container.AddAuraSlot,
            container,
            slot.key or ("yui-filtered-aura-" .. tostring(index)),
            filter,
            {
                candidateFilters = candidateFilters,
                initializeFrame = BuildInitializer(
                    initializeFrame,
                    bindings,
                    index
                ),
            }
        )
        if not slotOK or not auraFrame then
            Unit.ReleaseFilteredAuraDisplay(handle)
            return nil, "filtered-aura-slot-create-failed"
        end
    end
    for index = 1, #groups do
        local group = type(groups[index]) == "table" and groups[index] or {}
        local candidateFilters = BuildCandidateFilters(group)
        if not candidateFilters then
            Unit.ReleaseFilteredAuraDisplay(handle)
            return nil, "invalid-spell"
        end
        local filter = group.filter or spec.filter
        filter = filter == "HARMFUL" and "HARMFUL" or "HELPFUL"
        if filter == "HARMFUL" then
            handle.hasHarmfulFilter = true
        else
            handle.hasHelpfulFilter = true
        end
        local options = {
            candidateFilters = candidateFilters,
            initializeFrame = BuildInitializer(
                group.initializeFrame or spec.initializeFrame,
                group.bindings or spec.bindings,
                index
            ),
            layout = type(group.layout) == "table" and group.layout or {},
            maxFrameCount = tonumber(group.maxFrameCount) or 1,
            sortMethod = group.sortMethod,
            sortDirection = group.sortDirection,
        }
        local groupOK, auraGroup = pcall(
            container.AddAuraGroup,
            container,
            group.key or ("yui-filtered-aura-group-" .. tostring(index)),
            filter,
            options
        )
        if not groupOK or not auraGroup then
            Unit.ReleaseFilteredAuraDisplay(handle)
            return nil, "filtered-aura-group-create-failed"
        end
    end
    local unitOK = pcall(container.SetUnit, container, unit)
    if not unitOK then
        Unit.ReleaseFilteredAuraDisplay(handle)
        return nil, "filtered-aura-unit-bind-failed"
    end
    handle.active = true
    local refreshOK = Unit.RefreshFilteredAuraDisplay(handle)
    if not refreshOK then
        Unit.ReleaseFilteredAuraDisplay(handle)
        return nil, "filtered-aura-initial-refresh-failed"
    end
    if proxy.SetScript then
        proxy:SetScript("OnShow", function()
            Unit.RefreshFilteredAuraDisplay(handle)
        end)
    end
    if unit == "target" and proxy.RegisterEvent and proxy.SetScript then
        handle.contextEvent = "PLAYER_TARGET_CHANGED"
        proxy:RegisterEvent(handle.contextEvent)
        proxy:SetScript("OnEvent", function(_, event)
            if event == handle.contextEvent then
                Unit.RefreshFilteredAuraDisplay(handle)
            end
        end)
    end
    proxy:Show()
    return handle
end

function Unit.CreateFilteredAuraDurationDisplay(parent, unit, spellID, options)
    if not parent or not Unit.SupportsFilteredAuraDurationDisplay() then
        return nil, "filtered-aura-display-unavailable"
    end
    spellID = SafeNumberValue(spellID)
    if not spellID then return nil, "invalid-spell" end
    unit = type(unit) == "string" and unit ~= "" and unit or "player"
    options = type(options) == "table" and options or {}

    return Unit.CreateFilteredAuraDisplay(parent, {
        unit = unit,
        spellID = spellID,
        filter = "HELPFUL",
        key = "yhud-duration",
        initializeFrame = function(auraFrame, _, handle)
            auraFrame:SetAllPoints(handle.container)
            local statusBar = _G.CreateFrame("StatusBar", nil, auraFrame)
            statusBar:SetAllPoints(auraFrame)
            statusBar:SetStatusBarTexture(
                options.texture or "Interface\\Buttons\\WHITE8X8"
            )
            statusBar:SetStatusBarColor(
                options.r or 1,
                options.g or 1,
                options.b or 1,
                options.a or 1
            )
            local bindings = {
                durationBar = {
                    target = statusBar,
                    options = {
                        direction = Enum and Enum.StatusBarTimerDirection
                            and Enum.StatusBarTimerDirection.RemainingTime or 1,
                    },
                },
            }
            if options.showText ~= false then
                local durationText = auraFrame:CreateFontString(nil, "OVERLAY")
                durationText:SetPoint(
                    options.textPoint or "CENTER",
                    auraFrame,
                    options.textPoint or "CENTER",
                    options.textOffsetX or 0,
                    options.textOffsetY or 0
                )
                durationText:SetJustifyH(options.textJustifyH or "CENTER")
                durationText:SetJustifyV("MIDDLE")
                durationText:SetFont(
                    options.font or _G.STANDARD_TEXT_FONT
                        or "Fonts\\FRIZQT__.TTF",
                    options.fontSize or 12,
                    options.fontFlags or ""
                )
                durationText:SetTextColor(
                    options.textR or 1,
                    options.textG or 1,
                    options.textB or 1,
                    options.textA or 1
                )
                if durationText.SetShadowColor then
                    durationText:SetShadowColor(
                        0,
                        0,
                        0,
                        options.textShadow and 1 or 0
                    )
                end
                if durationText.SetShadowOffset then
                    durationText:SetShadowOffset(
                        options.textShadow and 1 or 0,
                        options.textShadow and -1 or 0
                    )
                end
                bindings.durationText = durationText
            end
            return bindings
        end,
    })
end

local function ReadAuraStackRaw(unit, spellID)
    local auraAPI = C_UnitAuras
    if not auraAPI then
        return nil, nil, nil
    end
    local aura
    if unit == "player" and auraAPI.GetPlayerAuraBySpellID then
        aura = auraAPI.GetPlayerAuraBySpellID(spellID)
    elseif auraAPI.GetUnitAuraBySpellID then
        aura = auraAPI.GetUnitAuraBySpellID(unit, spellID)
    else
        return nil, nil, nil
    end
    if not aura then return nil, nil, nil end
    local applications = aura.applications
    if IsSecretValue(applications) then
        return aura, applications, aura.sourceUnit
    end
    if type(applications) ~= "number" then
        applications = aura.charges
    end
    if IsSecretValue(applications) then
        return aura, applications, aura.sourceUnit
    end
    if type(applications) ~= "number" then applications = 1 end
    return aura, applications, aura.sourceUnit
end

function Unit.ReadAuraStackDisplay(unit, spellID, state, options)
    state = type(state) == "table" and state or {}
    options = type(options) == "table" and options or {}
    unit = type(unit) == "string" and unit ~= "" and unit or "player"
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then
        state.valueRaw = nil
        state.rawValuesAvailable = false
        state.available = false
        return state, false, "invalid-spell"
    end

    local ok, aura, valueRaw, sourceUnit = pcall(
        ReadAuraStackRaw,
        unit,
        spellID
    )
    local code
    if not ok then
        code = "direct-error"
    elseif not aura then
        code = "direct-absent"
    elseif options.requirePlayerSource == true then
        if IsSecretValue(sourceUnit) or type(sourceUnit) ~= "string" then
            code = "direct-source-unavailable"
        elseif sourceUnit ~= "player" then
            code = "direct-foreign-source"
        end
    end

    local valueSecret = code == nil and IsSecretValue(valueRaw) or false
    local value = code == nil and not valueSecret
        and type(valueRaw) == "number" and valueRaw or nil
    local available = code == nil
        and (valueSecret or type(valueRaw) == "number")
    local changed = state.sourceKind ~= "resource"
        or state.providerKind ~= "unit-aura-stacks"
        or state.unit ~= unit
        or state.spellID ~= spellID
        or state.available ~= available
        or state.secret ~= valueSecret
        or state.value ~= value
        or state.backendStatus ~= (code or "direct")

    state.sourceKind = "resource"
    state.providerKind = "unit-aura-stacks"
    state.unit = unit
    state.spellID = spellID
    state.available = available
    state.secret = valueSecret
    state.value = value
    state.valueRaw = available and not valueSecret and valueRaw or nil
    state.rawValuesAvailable = available and not valueSecret
    state.backendStatus = code or "direct"
    if valueSecret then
        state.opaqueRevision = (state.opaqueRevision or 0) + 1
        changed = true
    end
    return state, changed, code
end

Legacy.GetClassInfos = Unit.GetClassInfos
Legacy.GetNumClasses = Unit.GetNumClasses
Legacy.GetClassInfo = Unit.GetClassInfo
Legacy.GetClassInfoByID = Unit.GetClassInfoByID
Legacy.GetClassColor = Unit.GetClassColor
Legacy.GetRaceInfoByID = Unit.GetRaceInfoByID
Legacy.GetRaceInfoByFile = Unit.GetRaceInfoByFile
Legacy.GetRaceInfoByName = Unit.GetRaceInfoByName
Legacy.GetRaceToken = Unit.GetRaceToken
Legacy.UnitClass = Unit.UnitClass
Legacy.UnitClassBase = Unit.UnitClassBase
Legacy.GetClassToken = Unit.GetClassToken
Legacy.GetUnitClassColor = Unit.GetUnitClassColor
Legacy.UnitTreatAsPlayerForDisplay = Unit.UnitTreatAsPlayerForDisplay
Legacy.UnitName = Unit.UnitName
Legacy.UnitFullName = Unit.UnitFullName
Legacy.GetUnitDisplayNameInfo = Unit.GetDisplayNameInfo
Legacy.GetNormalizedRealmName = Unit.GetNormalizedRealmName
Legacy.GetRealmName = Unit.GetRealmName
Legacy.UnitFactionGroup = Unit.UnitFactionGroup
Legacy.UnitGUID = Unit.UnitGUID
Legacy.UnitExists = Unit.UnitExists
Legacy.UnitExistsSafe = Unit.Exists
Legacy.UnitIsDeadSafe = Unit.IsDead
Legacy.UnitIsFriendSafe = Unit.IsFriend
Legacy.UnitCanAttackSafe = Unit.CanAttack
Legacy.UnitIsPlayerSafe = Unit.IsPlayer
Legacy.UnitIsMinionSafe = Unit.IsMinion
Legacy.UnitIsOtherPlayersPetSafe = Unit.IsOtherPlayersPet
Legacy.UnitIsBattlePetSafe = Unit.IsBattlePet
Legacy.UnitIsOtherPlayersBattlePetSafe = Unit.IsOtherPlayersBattlePet
Legacy.UnitIsBattlePetCompanionSafe = Unit.IsBattlePetCompanion
Legacy.UnitIsUnitSafe = Unit.IsUnit
Legacy.UnitReactionSafe = Unit.Reaction
Legacy.UnitNameSafe = Unit.Name
Legacy.UnitCreatureTypeSafe = Unit.CreatureType
Legacy.UnitClassificationSafe = Unit.Classification
Legacy.GetUnitGUIDType = Unit.GetGUIDType
Legacy.GetPlayerInfoByGUID = Unit.GetPlayerInfoByGUID
Legacy.FindUnitAuraBySpellID = Unit.FindUnitAuraBySpellID
Legacy.GetUnitAuraBySpellID = Unit.GetUnitAuraBySpellID
Legacy.GetPlayerAuraBySpellID = Unit.GetPlayerAuraBySpellID
Legacy.ReadAuraIdentityByIndex = Unit.ReadAuraIdentityByIndex
Legacy.ReadAuraIdentityByInstance = Unit.ReadAuraIdentityByInstance
Legacy.FillPlayerAuraDisplayLookup = Unit.FillPlayerAuraDisplayLookup
Legacy.GetMaxPlayerLevel = Unit.GetMaxPlayerLevel
Legacy.GetUnitRangeEstimate = Unit.GetRangeEstimate
Legacy.GetUnitCastInfo = Unit.GetCastInfo
Legacy.GetUnitCastingInfo = Unit.GetCastingInfo
Legacy.GetUnitChannelInfo = Unit.GetChannelInfo
Legacy.GetUnitSpellTargetInfo = Unit.GetSpellTargetInfo
Legacy.ReadUnitPowerDisplay = Unit.ReadPowerDisplay
Legacy.ReadUnitPowerPartialFraction = Unit.ReadPowerPartialFraction
Legacy.ReadUnitChargedPowerPointMask = Unit.ReadChargedPowerPointMask
Legacy.CreateUnitPowerColorCurve = Unit.CreatePowerColorCurve
Legacy.ReadUnitPowerColor = Unit.ReadPowerColor
Legacy.CreateResourceValueColorCurve = Unit.CreateResourceValueColorCurve
Legacy.ReadResourceValueColor = Unit.ReadResourceValueColor
Legacy.ReadUnitAuraStackDisplay = Unit.ReadAuraStackDisplay
Legacy.ReadUnitStaggerResourceDisplay = Unit.ReadStaggerResourceDisplay
Legacy.ReadUnitAbsorbResourceDisplay = Unit.ReadAbsorbResourceDisplay
Legacy.ReadUnitAuraDurationResourceDisplay = Unit.ReadAuraDurationResourceDisplay
Legacy.SupportsFilteredAuraDisplay = Unit.SupportsFilteredAuraDisplay
Legacy.SupportsFilteredAuraDurationDisplay = Unit.SupportsFilteredAuraDurationDisplay
Legacy.EnsureFilteredAuraDisplay = Unit.EnsureFilteredAuraDisplay
Legacy.CreateFilteredAuraDisplay = Unit.CreateFilteredAuraDisplay
Legacy.CreateFilteredAuraDurationDisplay = Unit.CreateFilteredAuraDurationDisplay
Legacy.RefreshFilteredAuraDisplay = Unit.RefreshFilteredAuraDisplay
Legacy.ReleaseFilteredAuraDisplay = Unit.ReleaseFilteredAuraDisplay
