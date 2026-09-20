do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
YUI = YUI or _G.YUI
local Monitor = YUI and YUI.Monitor
local Sources = Monitor and Monitor.CommonSources
local Unit, Combat = YUI and YUI.API and YUI.API.Unit, YUI and YUI.API and YUI.API.Combat
if not (Sources and Unit) then return end

local function Public(value)
    if type(issecretvalue) == 'function' and issecretvalue(value) then return nil end
    return value
end
local function Number(value)
    value = Public(value)
    if type(value) == 'number' and value == value and value > -math.huge and value < math.huge then return value end
end
local function Call(method, ...)
    if type(method) ~= 'function' then return nil, 'aura-api-unavailable' end
    local ok, value, code = pcall(method, ...)
    if not ok then return nil, 'aura-query-failed' end
    if type(issecretvalue) == 'function' and issecretvalue(value) then return nil, 'aura-result-secret' end
    return value, code
end
local function Read(source, state)
    local params = source.params
    local guid = Call(Unit.UnitGUID, params.unit)
    local aura, code
    if type(guid) ~= 'string' or guid == '' then code = 'unit-identity-unavailable'
    elseif params.unit == 'player' then aura, code = Call(Unit.GetPlayerAuraBySpellID, params.spellID)
    else aura, code = Call(Unit.GetUnitAuraBySpellID, params.unit, params.spellID) end
    local present, expiration, stacks
    if type(aura) == 'table' then
        present = true
        expiration, stacks = Number(aura.expirationTime), Number(aura.applications)
    elseif not code then
        -- A restricted exact query may return nil. Never convert that into
        -- an aura-lost event; public absence is only accepted out of combat.
        if YUI.IsRetail and (not Combat or Combat.InCombatLockdown() ~= false) then
            code = 'aura-absence-unknown'
        else present = false end
    end
    local changed = state.present ~= present or state.expirationTime ~= expiration or state.stacks ~= stacks
        or state.unitGUID ~= guid or state.issue ~= code
    state.present, state.expirationTime, state.stacks = present, expiration, stacks
    state.unitGUID, state.issue = guid, code
    return changed
end

function Sources:RegisterAuraSourceType(unit)
    unit = unit or 'player'
    if unit ~= 'player' and unit ~= 'target' and unit ~= 'focus' then return nil, 'invalid-unit' end
    self.auraSourceTypes = self.auraSourceTypes or {}
    if self.auraSourceTypes[unit] then return true end
    local events = {
        { event = 'UNIT_AURA', unit = unit, all = true },
        { event = 'PLAYER_ENTERING_WORLD', all = true },
        { event = 'PLAYER_REGEN_ENABLED', all = true },
    }
    if unit == 'target' then events[#events + 1] = { event = 'PLAYER_TARGET_CHANGED', all = true }
    elseif unit == 'focus' then events[#events + 1] = { event = 'PLAYER_FOCUS_CHANGED', all = true } end
    local sourceType, code = Monitor:RegisterSourceType('public-aura-' .. unit, {
        read = Read,
        events = events,
    })
    if not sourceType and code ~= 'source-type-exists' then return nil, code end
    self.auraSourceTypes[unit] = true
    return true
end
return Sources
