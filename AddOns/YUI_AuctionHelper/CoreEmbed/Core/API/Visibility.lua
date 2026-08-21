do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}

local Visibility = YUI.API.Visibility or {}
YUI.API.Visibility = Visibility

local function IsSecret(value)
    local security = YUI.API and YUI.API.Security
    if security and security.IsSecretValue then
        return security.IsSecretValue(value) == true
    end
    local checker = _G.issecretvalue
    if type(checker) ~= "function" then return false end
    local ok, secret = pcall(checker, value)
    return ok and secret == true
end

local function SafeBooleanCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) or type(value) ~= "boolean" then
        return nil
    end
    return value
end

local function SupportsCombat()
    return type(_G.UnitAffectingCombat) == "function"
        or type(_G.InCombatLockdown) == "function"
end

local function ReadCombat()
    local value = SafeBooleanCall(_G.UnitAffectingCombat, "player")
    if value ~= nil then return value end
    return SafeBooleanCall(_G.InCombatLockdown)
end

local function SupportsMounted()
    return type(_G.IsMounted) == "function"
        or type(_G.GetShapeshiftFormID) == "function"
end

local function ReadMounted()
    local mounted = SafeBooleanCall(_G.IsMounted)
    if mounted == true then return true end

    local getFormID = _G.GetShapeshiftFormID
    if type(getFormID) == "function" then
        local ok, formID = pcall(getFormID)
        if not ok or IsSecret(formID) then return nil end
        if formID == 3 or formID == 4 or formID == 27 then
            return true
        end
    end
    return mounted
end

local function SupportsTarget()
    return type(_G.UnitExists) == "function"
end

local function ReadTarget()
    return SafeBooleanCall(_G.UnitExists, "target")
end

local function SupportsPetBattle()
    local api = _G.C_PetBattles
    return api and type(api.IsInBattle) == "function" or false
end

local function ReadPetBattle()
    local api = _G.C_PetBattles
    return SafeBooleanCall(api and api.IsInBattle)
end

local function SupportsSkyriding()
    local api = _G.C_PlayerInfo
    return api and type(api.GetGlidingInfo) == "function" or false
end

local function ReadSkyriding()
    local api = _G.C_PlayerInfo
    return SafeBooleanCall(api and api.GetGlidingInfo)
end

local function SupportsHousing()
    local api = _G.C_Housing
    return api and type(api.IsInsideHouseOrPlot) == "function" or false
end

local function ReadHousing()
    local api = _G.C_Housing
    return SafeBooleanCall(api and api.IsInsideHouseOrPlot)
end

local function SupportsInstance()
    return type(_G.IsInInstance) == "function"
end

local function ReadInstance()
    return SafeBooleanCall(_G.IsInInstance)
end

local function SupportsGroup()
    return type(_G.IsInGroup) == "function"
end

local function ReadGroup()
    return SafeBooleanCall(_G.IsInGroup)
end

local function SupportsRaid()
    return type(_G.IsInRaid) == "function"
end

local function ReadRaid()
    return SafeBooleanCall(_G.IsInRaid)
end

local function SupportsTaxi()
    return type(_G.UnitOnTaxi) == "function"
end

local function ReadTaxi()
    return SafeBooleanCall(_G.UnitOnTaxi, "player")
end

local READERS = {
    combat = ReadCombat,
    instance = ReadInstance,
    group = ReadGroup,
    raid = ReadRaid,
    taxi = ReadTaxi,
    mounted = ReadMounted,
    target = ReadTarget,
    petBattle = ReadPetBattle,
    skyriding = ReadSkyriding,
    housing = ReadHousing,
}

local SUPPORT = {
    combat = SupportsCombat,
    instance = SupportsInstance,
    group = SupportsGroup,
    raid = SupportsRaid,
    taxi = SupportsTaxi,
    mounted = SupportsMounted,
    target = SupportsTarget,
    petBattle = SupportsPetBattle,
    skyriding = SupportsSkyriding,
    housing = SupportsHousing,
}

function Visibility.IsSupported(stateKey)
    local checker = SUPPORT[stateKey]
    return checker and checker() == true or false
end

function Visibility.Read(stateKey)
    local reader = READERS[stateKey]
    if not reader then return nil end
    return reader()
end
