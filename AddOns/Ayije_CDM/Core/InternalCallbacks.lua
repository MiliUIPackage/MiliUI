local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local L = CDM.L

local internalCallbacks = {}
local internalCallbacksSorted = {}
local internalCallbacksDirty = {}
local internalCallbackSeq = 0

local INTERNAL_DISPATCH_ORDER = {
    "OnCombatStateChanged",
    "OnSpecStateChanged",
    "OnTalentDataChanged",
    "OnCooldownDataChanged",
}
local INTERNAL_DISPATCH_ORDER_SET = {}
for _, callbackName in ipairs(INTERNAL_DISPATCH_ORDER) do
    INTERNAL_DISPATCH_ORDER_SET[callbackName] = true
end

local pendingInternalDispatch = {}
local internalDispatchQueued = false
local internalDispatchFrame = CreateFrame("Frame")
local pendingInternalDispatchNameScratch = {}

local function CallbackSort(a, b)
    if a.priority ~= b.priority then
        return a.priority < b.priority
    end
    return a.seq < b.seq
end

local function EnsurePendingDispatchPayload(name)
    local payload = pendingInternalDispatch[name]
    if payload then
        return payload
    end

    payload = {
        pending = false,
        n = 0,
    }
    pendingInternalDispatch[name] = payload
    return payload
end

local function SetPendingDispatchArgs(payload, ...)
    local count = select("#", ...)
    local previousCount = payload.n or 0
    payload.n = count
    for i = 1, count do
        payload[i] = select(i, ...)
    end
    for i = count + 1, previousCount do
        payload[i] = nil
    end
end

local TALENT_DISPATCH_PRIORITY = {
    ACTIVE_TALENT_GROUP_CHANGED = 3,
    TRAIT_CONFIG_CREATED = 2,
    TRAIT_CONFIG_UPDATED = 2,
    PLAYER_TALENT_UPDATE = 2,
    PLAYER_PVP_TALENT_UPDATE = 2,
    WAR_MODE_STATUS_UPDATE = 2,
    SPELLS_CHANGED = 1,
}

local function GetTalentDispatchPriority(event)
    return TALENT_DISPATCH_PRIORITY[event] or 0
end

local function ShouldReplaceTalentDispatch(payload, event)
    if not payload.pending then
        return true
    end

    local pendingEvent = payload[1]
    if pendingEvent == event then
        return false
    end

    local pendingPriority = GetTalentDispatchPriority(pendingEvent)
    local eventPriority = GetTalentDispatchPriority(event)
    if eventPriority > pendingPriority then
        return true
    end
    if eventPriority < pendingPriority then
        return false
    end

    return true
end

local function FlushPendingDispatchPayload(callbackName, payload)
    if not (payload and payload.pending) then
        return
    end

    payload.pending = false
    local count = payload.n or 0
    if count > 0 then
        CDM:TriggerInternalCallback(callbackName, unpack(payload, 1, count))
    else
        CDM:TriggerInternalCallback(callbackName)
    end
end

local function FlushInternalDispatchQueue()
    internalDispatchQueued = false

    for _, callbackName in ipairs(INTERNAL_DISPATCH_ORDER) do
        FlushPendingDispatchPayload(callbackName, pendingInternalDispatch[callbackName])
    end

    table.wipe(pendingInternalDispatchNameScratch)
    for callbackName, payload in pairs(pendingInternalDispatch) do
        if payload and payload.pending and not INTERNAL_DISPATCH_ORDER_SET[callbackName] then
            pendingInternalDispatchNameScratch[#pendingInternalDispatchNameScratch + 1] = callbackName
        end
    end
    if #pendingInternalDispatchNameScratch > 1 then
        table.sort(pendingInternalDispatchNameScratch)
    end
    for i = 1, #pendingInternalDispatchNameScratch do
        local callbackName = pendingInternalDispatchNameScratch[i]
        FlushPendingDispatchPayload(callbackName, pendingInternalDispatch[callbackName])
    end
end

local function QueueInternalCallback(name, ...)
    if type(name) ~= "string" or name == "" then
        return
    end

    local payload = EnsurePendingDispatchPayload(name)
    if name == "OnTalentDataChanged" then
        if ShouldReplaceTalentDispatch(payload, select(1, ...)) then
            SetPendingDispatchArgs(payload, ...)
        end
    else
        SetPendingDispatchArgs(payload, ...)
    end
    payload.pending = true

    if not internalDispatchQueued then
        internalDispatchQueued = true
        internalDispatchFrame:Show()
    end
end

local function SafeInvokeInternalCallback(callbackName, callback, ...)
    local success, err = pcall(callback, ...)
    if not success then
        print("|cffff0000[CDM] " .. string.format(L["Callback error in '%s':"], "internal:" .. callbackName) .. "|r " .. tostring(err))
    end
end

local function GetSortedInternalCallbacks(name)
    if internalCallbacksDirty[name] then
        local sorted = internalCallbacksSorted[name]
        if not sorted then
            sorted = {}
            internalCallbacksSorted[name] = sorted
        else
            table.wipe(sorted)
        end

        local registry = internalCallbacks[name]
        if registry then
            for _, entry in ipairs(registry) do
                sorted[#sorted + 1] = entry
            end
            table.sort(sorted, CallbackSort)
        end

        internalCallbacksDirty[name] = false
    end
    return internalCallbacksSorted[name]
end

function CDM:RegisterInternalCallback(name, callback, priority)
    if type(name) ~= "string" or name == "" then return false end
    if type(callback) ~= "function" then return false end

    local registry = internalCallbacks[name]
    if not registry then
        registry = {}
        internalCallbacks[name] = registry
    else
        for _, entry in ipairs(registry) do
            if entry.callback == callback then
                return true
            end
        end
    end

    internalCallbackSeq = internalCallbackSeq + 1
    registry[#registry + 1] = {
        callback = callback,
        priority = priority or 50,
        seq = internalCallbackSeq,
    }
    internalCallbacksDirty[name] = true
    return true
end

function CDM:UnregisterInternalCallback(name, callback)
    if type(name) ~= "string" or name == "" then return false end
    if type(callback) ~= "function" then return false end

    local registry = internalCallbacks[name]
    if not registry then return false end

    for i = #registry, 1, -1 do
        if registry[i].callback == callback then
            table.remove(registry, i)
            internalCallbacksDirty[name] = true
            if #registry == 0 then
                internalCallbacks[name] = nil
                internalCallbacksSorted[name] = nil
                internalCallbacksDirty[name] = nil
            end
            return true
        end
    end
    return false
end

function CDM:TriggerInternalCallback(name, ...)
    if type(name) ~= "string" or name == "" then return end
    local sorted = GetSortedInternalCallbacks(name)
    if not sorted or #sorted == 0 then return end
    for _, entry in ipairs(sorted) do
        SafeInvokeInternalCallback(name, entry.callback, ...)
    end
end

local function DispatchTalentDataChanged(event, ...)
    QueueInternalCallback("OnTalentDataChanged", event, ...)
end

local function DispatchSpecStateChanged(event, unit, ...)
    if unit and unit ~= "player" then
        return
    end
    QueueInternalCallback("OnSpecStateChanged", unit or "player", event, ...)
end

local function DispatchCombatStateChanged(event)
    QueueInternalCallback("OnCombatStateChanged", event == "PLAYER_REGEN_DISABLED", event)
end

local function DispatchCooldownDataChanged(event, ...)
    QueueInternalCallback("OnCooldownDataChanged", event, ...)
end

internalDispatchFrame:SetScript("OnUpdate", function(self)
    FlushInternalDispatchQueue()
    if not internalDispatchQueued then
        self:Hide()
    end
end)
internalDispatchFrame:Hide()

CDM:RegisterEvent("SPELLS_CHANGED", DispatchTalentDataChanged)
CDM:RegisterEvent("TRAIT_CONFIG_CREATED", DispatchTalentDataChanged)
CDM:RegisterEvent("TRAIT_CONFIG_UPDATED", DispatchTalentDataChanged)
CDM:RegisterEvent("PLAYER_TALENT_UPDATE", DispatchTalentDataChanged)
CDM:RegisterEvent("PLAYER_PVP_TALENT_UPDATE", DispatchTalentDataChanged)
CDM:RegisterEvent("WAR_MODE_STATUS_UPDATE", DispatchTalentDataChanged)
CDM:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", DispatchTalentDataChanged)

CDM:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", DispatchSpecStateChanged)

CDM:RegisterEvent("PLAYER_REGEN_ENABLED", DispatchCombatStateChanged)
CDM:RegisterEvent("PLAYER_REGEN_DISABLED", DispatchCombatStateChanged)

CDM:RegisterEvent("SPELL_UPDATE_COOLDOWN", DispatchCooldownDataChanged)
