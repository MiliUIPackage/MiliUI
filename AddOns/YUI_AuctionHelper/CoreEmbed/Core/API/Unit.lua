local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
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

function Unit.GetUnitAuraBySpellID(unit, spellID)
    if not unit or spellID == nil then
        return nil
    end

    if C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID then
        local aura = SafeValue(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
        if aura then
            return aura
        end
    end

    return Unit.FindUnitAuraBySpellID(unit, spellID)
end

function Unit.GetPlayerAuraBySpellID(spellID)
    if spellID == nil then
        return nil
    end

    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = SafeValue(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if aura then
            return aura
        end
    end

    return Unit.GetUnitAuraBySpellID("player", spellID)
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

Legacy.GetClassInfos = Unit.GetClassInfos
Legacy.GetNumClasses = Unit.GetNumClasses
Legacy.GetClassInfo = Unit.GetClassInfo
Legacy.GetClassInfoByID = Unit.GetClassInfoByID
Legacy.GetClassColor = Unit.GetClassColor
Legacy.GetRaceInfoByID = Unit.GetRaceInfoByID
Legacy.GetRaceInfoByFile = Unit.GetRaceInfoByFile
Legacy.GetRaceInfoByName = Unit.GetRaceInfoByName
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
Legacy.GetMaxPlayerLevel = Unit.GetMaxPlayerLevel
Legacy.GetUnitRangeEstimate = Unit.GetRangeEstimate
Legacy.GetUnitCastInfo = Unit.GetCastInfo
Legacy.GetUnitCastingInfo = Unit.GetCastingInfo
Legacy.GetUnitChannelInfo = Unit.GetChannelInfo
Legacy.GetUnitSpellTargetInfo = Unit.GetSpellTargetInfo
