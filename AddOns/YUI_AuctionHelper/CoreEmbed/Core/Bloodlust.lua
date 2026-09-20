do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

local Bloodlust = YUI.Bloodlust or {}
YUI.Bloodlust = Bloodlust

local DURATION = 40
local EDGE_GUARD_DURATION = 1.5
-- Only Bloodlust lockout debuffs belong here. Do not add unrelated
-- non-secret Aura whitelist entries to this set.
local FATIGUE_SPELL_ID_ORDER = {
    57724,  -- Sated (Bloodlust)
    57723,  -- Exhaustion (Heroism)
    80354,  -- Temporal Displacement (Time Warp)
    95809,  -- Insanity (Ancient Hysteria)
    390435, -- Exhaustion (Fury of the Aspects)
    160455, -- Fatigued (Netherwinds)
    264689, -- Fatigued (Primal Rage)
}
local FATIGUE_SPELL_IDS = {}
for index = 1, #FATIGUE_SPELL_ID_ORDER do
    FATIGUE_SPELL_IDS[FATIGUE_SPELL_ID_ORDER[index]] = true
end

Bloodlust.consumers = Bloodlust.consumers or {}
Bloodlust.consumerCount = Bloodlust.consumerCount or 0
Bloodlust.presentBySpell = Bloodlust.presentBySpell or {}
Bloodlust.spellByInstance = Bloodlust.spellByInstance or {}
Bloodlust.instanceBySpell = Bloodlust.instanceBySpell or {}
Bloodlust.state = Bloodlust.state or {
    active = false,
    startTime = 0,
    duration = DURATION,
    revision = 0,
}

local function GetSecurity()
    return YUI.API and YUI.API.Security
end

local function IsSecret(value)
    local security = GetSecurity()
    if security and security.IsSecretValue then
        return security.IsSecretValue(value) == true
    end
    local checker = _G.issecretvalue
    if type(checker) ~= "function" then return false end
    local ok, secret = pcall(checker, value)
    return ok and secret == true
end

local function SafePositiveInteger(value)
    if value == nil or IsSecret(value) then return nil end
    local security = GetSecurity()
    local numberValue = security and security.SafeNumber
        and security.SafeNumber(value)
        or (type(value) == "number" and value or nil)
    if not numberValue or numberValue <= 0
        or numberValue ~= math.floor(numberValue) then
        return nil
    end
    return numberValue
end

local function SafeBoolean(value)
    local security = GetSecurity()
    if security and security.SafeBoolean then
        return security.SafeBoolean(value)
    end
    if value == nil or IsSecret(value) then return nil end
    if type(value) == "boolean" then return value end
    return nil
end

local function ReadAuraField(aura, key)
    if type(aura) ~= "table" then return nil end
    local ok, value = pcall(function()
        return aura[key]
    end)
    if not ok or IsSecret(value) then return nil end
    return value
end

local function HasPresentFatigue(presentBySpell)
    for index = 1, #FATIGUE_SPELL_ID_ORDER do
        local spellID = FATIGUE_SPELL_ID_ORDER[index]
        if presentBySpell[spellID] == true then return true end
    end
    return false
end

local function HasUnmappedFatigue(service)
    for index = 1, #FATIGUE_SPELL_ID_ORDER do
        local spellID = FATIGUE_SPELL_ID_ORDER[index]
        if service.presentBySpell[spellID] == true
            and service.instanceBySpell[spellID] == nil then
            return true
        end
    end
    return false
end

local function GetTimeNow()
    local combat = YUI.API and YUI.API.Combat
    if combat and combat.GetTime then
        local value = combat.GetTime()
        if type(value) == "number" then return value end
    end
    return type(_G.GetTime) == "function" and _G.GetTime() or 0
end

local function IsWorldReady()
    local lifecycle = YUI.Lifecycle
    if not (lifecycle and lifecycle.IsReady) then return true end
    return lifecycle:IsReady("YUI_WORLD_READY") == true
end

local function InvokeConsumer(handle, state, reason)
    local callback = handle.callback
    if type(callback) == "string" then
        callback = handle.owner and handle.owner[callback]
    end
    if type(callback) ~= "function" then return end
    if handle.owner ~= nil then
        pcall(callback, handle.owner, state, reason)
    else
        pcall(callback, state, reason)
    end
end

function Bloodlust:_Notify(reason)
    for handle in pairs(self.consumers) do
        if handle.active == true then
            InvokeConsumer(handle, self.state, reason)
        end
    end
end

function Bloodlust:_CancelTimer()
    local timer = self.timer
    self.timer = nil
    self.timerToken = nil
    if timer and timer.Cancel then timer:Cancel() end
end

function Bloodlust:_SetInactive(reason, notify)
    self:_CancelTimer()
    local state = self.state
    if state.active ~= true then return false end
    state.active = false
    state.startTime = 0
    state.duration = DURATION
    state.revision = (state.revision or 0) + 1
    if notify then self:_Notify(reason or "expired") end
    return true
end

function Bloodlust:_StartWindow(reason)
    local state = self.state
    if state.active == true then return false end

    state.active = true
    state.startTime = GetTimeNow()
    state.duration = DURATION
    state.revision = (state.revision or 0) + 1

    self:_CancelTimer()
    local token = {}
    self.timerToken = token
    if _G.C_Timer and _G.C_Timer.NewTimer then
        self.timer = _G.C_Timer.NewTimer(DURATION, function()
            if Bloodlust.timerToken ~= token then return end
            Bloodlust.timer = nil
            Bloodlust.timerToken = nil
            Bloodlust:_SetInactive("expired", true)
        end)
    end
    self:_Notify(reason or "started")
    return true
end

function Bloodlust:_RememberAura(aura)
    local spellID = SafePositiveInteger(ReadAuraField(aura, "spellId"))
    if not spellID then return false, true end
    if not FATIGUE_SPELL_IDS[spellID] then return false, false end

    local instanceID = SafePositiveInteger(
        ReadAuraField(aura, "auraInstanceID")
    )
    local previousInstance = self.instanceBySpell[spellID]
    self.presentBySpell[spellID] = true
    if instanceID then
        if previousInstance and previousInstance ~= instanceID then
            self.spellByInstance[previousInstance] = nil
        end
        self.spellByInstance[instanceID] = spellID
        self.instanceBySpell[spellID] = instanceID
    else
        if previousInstance then
            self.spellByInstance[previousInstance] = nil
        end
        self.instanceBySpell[spellID] = nil
    end
    return true, false
end

function Bloodlust:_ForgetAuraInstance(instanceID)
    instanceID = SafePositiveInteger(instanceID)
    if not instanceID then return false end
    local spellID = self.spellByInstance[instanceID]
    self.spellByInstance[instanceID] = nil
    if not spellID then return false end
    if self.instanceBySpell[spellID] ~= instanceID then return true end
    self.presentBySpell[spellID] = nil
    self.instanceBySpell[spellID] = nil
    return true
end

function Bloodlust:_ScanPresence()
    local unit = YUI.API and YUI.API.Unit
    local reader = unit and unit.GetPlayerAuraBySpellID
    if type(reader) ~= "function" then return false end

    local nextPresent = {}
    local nextInstances = {}
    local nextInstanceBySpell = {}
    for index = 1, #FATIGUE_SPELL_ID_ORDER do
        local spellID = FATIGUE_SPELL_ID_ORDER[index]
        local aura, code = reader(spellID)
        if type(aura) == "table" then
            nextPresent[spellID] = true
            local instanceID = SafePositiveInteger(
                ReadAuraField(aura, "auraInstanceID")
            )
            if instanceID then
                nextInstances[instanceID] = spellID
                nextInstanceBySpell[spellID] = instanceID
            end
        elseif code ~= nil and self.presentBySpell[spellID] == true then
            nextPresent[spellID] = true
            local instanceID = self.instanceBySpell[spellID]
            if instanceID then
                nextInstances[instanceID] = spellID
                nextInstanceBySpell[spellID] = instanceID
            end
        end
    end
    self.presentBySpell = nextPresent
    self.spellByInstance = nextInstances
    self.instanceBySpell = nextInstanceBySpell
    return HasPresentFatigue(nextPresent)
end

function Bloodlust:_ReadExactPresence()
    local unit = YUI.API and YUI.API.Unit
    local reader = unit and unit.GetPlayerAuraBySpellID
    if type(reader) ~= "function" then
        return nil, nil, "aura-api-unavailable"
    end

    local unknownCode
    for index = 1, #FATIGUE_SPELL_ID_ORDER do
        local spellID = FATIGUE_SPELL_ID_ORDER[index]
        local aura, code = reader(spellID)
        if type(aura) == "table" then
            return true, spellID
        end
        if code ~= nil and unknownCode == nil then
            unknownCode = code
        end
    end
    if unknownCode ~= nil then return nil, nil, unknownCode end
    return false
end

function Bloodlust:_ApplyExactPresence(isPresent, spellID)
    if isPresent == true then
        if spellID then
            local previousInstance = self.instanceBySpell[spellID]
            if previousInstance then
                self.spellByInstance[previousInstance] = nil
            end
            self.presentBySpell[spellID] = true
            self.instanceBySpell[spellID] = nil
        end
        return
    end
    if isPresent ~= false then return end

    for key in pairs(self.presentBySpell) do
        self.presentBySpell[key] = nil
    end
    for key in pairs(self.spellByInstance) do
        self.spellByInstance[key] = nil
    end
    for key in pairs(self.instanceBySpell) do
        self.instanceBySpell[key] = nil
    end
end

function Bloodlust:_RefreshRestrictedPresence(wasPresent)
    if wasPresent == nil then
        wasPresent = HasPresentFatigue(self.presentBySpell)
    end
    local isPresent, spellID = self:_ReadExactPresence()
    if isPresent == nil then return false end

    self:_ApplyExactPresence(isPresent, spellID)
    if self.transitionsArmed == true
        and GetTimeNow() >= (self.guardUntil or 0)
        and not wasPresent and isPresent then
        self:_StartWindow("fatigue-added")
    end
    return true
end

function Bloodlust:OnUnitAura(_, _, updateInfo)
    if self.consumerCount <= 0 then return end
    if IsSecret(updateInfo) then
        self:_RefreshRestrictedPresence()
        return
    end
    if type(updateInfo) ~= "table" then
        self:_ScanPresence()
        return
    end

    local isFullUpdateRaw = updateInfo.isFullUpdate
    local isFullUpdate = SafeBoolean(isFullUpdateRaw)
    if IsSecret(isFullUpdateRaw) then
        self:_RefreshRestrictedPresence()
        return
    end
    if isFullUpdate ~= false then
        self:_ScanPresence()
        return
    end

    local wasPresent = HasPresentFatigue(self.presentBySpell)
    local needsScan = false
    local addedFatigue = false
    local restrictedFields = false
    local added = updateInfo.addedAuras
    local removed = updateInfo.removedAuraInstanceIDs
    if IsSecret(added) or IsSecret(removed) then
        self:_RefreshRestrictedPresence()
        return
    end
    if type(added) == "table" then
        for index = 1, #added do
            local remembered, unreadable = self:_RememberAura(added[index])
            if remembered then addedFatigue = true end
            if unreadable then
                restrictedFields = true
            end
        end
    end

    if type(removed) == "table" then
        local hadUnmappedFatigue = HasUnmappedFatigue(self)
        for index = 1, #removed do
            local instanceID = removed[index]
            if SafePositiveInteger(instanceID) then
                self:_ForgetAuraInstance(instanceID)
            else
                restrictedFields = true
            end
        end
        if hadUnmappedFatigue and #removed > 0 then needsScan = true end
    end

    if restrictedFields then
        self:_RefreshRestrictedPresence(wasPresent)
        return
    end
    if needsScan then
        self:_ScanPresence()
    end
    local isPresent = HasPresentFatigue(self.presentBySpell)
    if self.transitionsArmed == true
        and GetTimeNow() >= (self.guardUntil or 0)
        and addedFatigue and not wasPresent and isPresent then
        self:_StartWindow("fatigue-added")
    end
end

function Bloodlust:_EstablishTransitionBaseline()
    self:_ScanPresence()
    self.guardUntil = GetTimeNow() + EDGE_GUARD_DURATION
    self.transitionsArmed = true
end

function Bloodlust:OnWorldReady()
    if self.consumerCount <= 0 or self.listening ~= true then return end
    self:_EstablishTransitionBaseline()
end

function Bloodlust:_Activate()
    if self.listening == true then return true end
    self.presentBySpell = {}
    self.spellByInstance = {}
    self.instanceBySpell = {}
    self.transitionsArmed = false
    self.guardUntil = 0
    self.worldReadyListener = nil
    self:_SetInactive("activate", false)
    self:_ScanPresence()

    local event = YUI.Event
    if not (event and event.On) then return false end
    self.listener = event:On(
        "UNIT_AURA",
        "OnUnitAura",
        self,
        { unit = "player" }
    )
    self.worldReadyListener = event:On(
        "YUI_WORLD_READY",
        "OnWorldReady",
        self
    )
    local worldReady = IsWorldReady()
    self.listening = self.listener ~= nil
        and self.worldReadyListener ~= nil
    if not self.listening then
        if event.OffOwner then event:OffOwner(self) end
        self.listener = nil
        self.worldReadyListener = nil
        return false
    end
    if worldReady then self:_EstablishTransitionBaseline() end
    return self.listening
end

function Bloodlust:_Deactivate()
    if YUI.Event and YUI.Event.OffOwner then
        YUI.Event:OffOwner(self)
    end
    self.listener = nil
    self.worldReadyListener = nil
    self.listening = false
    self.transitionsArmed = false
    self.guardUntil = 0
    self.presentBySpell = {}
    self.spellByInstance = {}
    self.instanceBySpell = {}
    self:_SetInactive("deactivate", false)
end

function Bloodlust:Acquire(owner, callback)
    if type(callback) ~= "function" and type(callback) ~= "string" then
        return nil, "invalid-callback"
    end
    local handle = {
        owner = owner,
        callback = callback,
        active = true,
    }
    self.consumers[handle] = true
    self.consumerCount = self.consumerCount + 1
    if self.consumerCount == 1 and not self:_Activate() then
        self.consumers[handle] = nil
        self.consumerCount = 0
        handle.active = false
        return nil, "event-unavailable"
    end
    return handle
end

function Bloodlust:Release(handle)
    if type(handle) ~= "table" or self.consumers[handle] ~= true then
        return false
    end
    self.consumers[handle] = nil
    handle.active = false
    self.consumerCount = math.max(0, self.consumerCount - 1)
    if self.consumerCount == 0 then self:_Deactivate() end
    return true
end

function Bloodlust:ReleaseOwner(owner)
    local released = 0
    for handle in pairs(self.consumers) do
        if handle.owner == owner and self:Release(handle) then
            released = released + 1
        end
    end
    return released
end

function Bloodlust:GetState(target)
    target = type(target) == "table" and target or {}
    local state = self.state
    target.active = state.active == true
    target.startTime = state.startTime or 0
    target.duration = state.duration or DURATION
    target.revision = state.revision or 0
    return target
end
