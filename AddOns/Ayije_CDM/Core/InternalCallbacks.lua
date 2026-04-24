local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local ipairs = ipairs

local combatHandlers = {}
local specHandlers = {}
local talentHandlers = {}

local combatPending, combatIsInCombat, combatEvent = false, nil, nil
local specPending, specUnit, specEvent = false, nil, nil
local talentPending, talentEvent, talentPriority = false, nil, 0
local spellsChangedPending = false

local TALENT_PRIORITIES = {
    ACTIVE_TALENT_GROUP_CHANGED = 3,
    TRAIT_CONFIG_CREATED = 2,
    TRAIT_CONFIG_UPDATED = 2,
    PLAYER_TALENT_UPDATE = 2,
    PLAYER_PVP_TALENT_UPDATE = 2,
    WAR_MODE_STATUS_UPDATE = 2,
}

local dispatchFrame = CreateFrame("Frame")
local dispatchQueued = false

local function RegisterHandler(list, fn)
    if type(fn) ~= "function" then return false end
    for _, existing in ipairs(list) do
        if existing == fn then return true end
    end
    list[#list + 1] = fn
    return true
end

local function UnregisterHandler(list, fn)
    if type(fn) ~= "function" then return false end
    for i = #list, 1, -1 do
        if list[i] == fn then
            table.remove(list, i)
            return true
        end
    end
    return false
end

local function FlushHandlers(list, ...)
    for _, fn in ipairs(list) do
        fn(...)
    end
end

local function FlushInternalDispatch()
    dispatchQueued = false

    if combatPending then
        combatPending = false
        FlushHandlers(combatHandlers, combatIsInCombat, combatEvent)
    end

    if specPending then
        specPending = false
        FlushHandlers(specHandlers, specUnit, specEvent)
    end

    if talentPending then
        talentPending = false
        local event = talentEvent
        talentEvent = nil
        talentPriority = 0
        FlushHandlers(talentHandlers, event)
    end

    if spellsChangedPending then
        spellsChangedPending = false
        FlushHandlers(talentHandlers, "SPELLS_CHANGED")
    end
end

local function QueueDispatch()
    if not dispatchQueued then
        dispatchQueued = true
        dispatchFrame:Show()
    end
end

function CDM:RegisterCombatStateHandler(fn) return RegisterHandler(combatHandlers, fn) end
function CDM:UnregisterCombatStateHandler(fn) return UnregisterHandler(combatHandlers, fn) end
function CDM:RegisterSpecStateHandler(fn) return RegisterHandler(specHandlers, fn) end
function CDM:UnregisterSpecStateHandler(fn) return UnregisterHandler(specHandlers, fn) end
function CDM:RegisterTalentDataHandler(fn) return RegisterHandler(talentHandlers, fn) end
function CDM:UnregisterTalentDataHandler(fn) return UnregisterHandler(talentHandlers, fn) end

local function DispatchTalentDataChanged(event)
    if event == "SPELLS_CHANGED" then
        spellsChangedPending = true
        QueueDispatch()
        return
    end
    local priority = TALENT_PRIORITIES[event] or 0
    if not talentPending or priority >= talentPriority then
        talentEvent = event
        talentPriority = priority
    end
    talentPending = true
    QueueDispatch()
end

local function DispatchSpecStateChanged(event, unit)
    if unit and unit ~= "player" then return end
    specPending = true
    specUnit = unit or "player"
    specEvent = event
    QueueDispatch()
end

local function DispatchCombatStateChanged(event)
    combatPending = true
    combatIsInCombat = event == "PLAYER_REGEN_DISABLED"
    combatEvent = event
    QueueDispatch()
end

dispatchFrame:SetScript("OnUpdate", function(self)
    FlushInternalDispatch()
    if not dispatchQueued then
        self:Hide()
    end
end)

local INTERNAL_EVENT_DISPATCH = {
    SPELLS_CHANGED              = DispatchTalentDataChanged,
    TRAIT_CONFIG_CREATED        = DispatchTalentDataChanged,
    TRAIT_CONFIG_UPDATED        = DispatchTalentDataChanged,
    PLAYER_TALENT_UPDATE        = DispatchTalentDataChanged,
    PLAYER_PVP_TALENT_UPDATE    = DispatchTalentDataChanged,
    WAR_MODE_STATUS_UPDATE      = DispatchTalentDataChanged,
    ACTIVE_TALENT_GROUP_CHANGED = DispatchTalentDataChanged,
    PLAYER_SPECIALIZATION_CHANGED = DispatchSpecStateChanged,
    PLAYER_REGEN_ENABLED        = DispatchCombatStateChanged,
    PLAYER_REGEN_DISABLED       = DispatchCombatStateChanged,
}

dispatchFrame:SetScript("OnEvent", function(_, event, ...)
    local fn = INTERNAL_EVENT_DISPATCH[event]
    if fn then fn(event, ...) end
end)

dispatchFrame:RegisterEvent("SPELLS_CHANGED")
dispatchFrame:RegisterEvent("TRAIT_CONFIG_CREATED")
dispatchFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
dispatchFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
dispatchFrame:RegisterEvent("PLAYER_PVP_TALENT_UPDATE")
dispatchFrame:RegisterEvent("WAR_MODE_STATUS_UPDATE")
dispatchFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
dispatchFrame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
dispatchFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
dispatchFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
dispatchFrame:Hide()
