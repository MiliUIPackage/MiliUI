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
if not Sources then return end

local function Public(value)
    if type(issecretvalue) == 'function' and issecretvalue(value) then return nil end
    return value
end

local function Identity(spellID, unit)
    spellID, unit = Public(spellID), Public(unit)
    if type(spellID) ~= 'number' or spellID <= 0 or spellID % 1 ~= 0
        or (unit ~= 'player' and unit ~= 'target' and unit ~= 'focus') then return nil end
    return unit .. ':' .. spellID
end

local function CastIdentity(params)
    return Identity(params.spellID, params.unit or 'player')
end

local function CastState(params)
    return { available = true, spellID = params.spellID, sequence = 0 }
end

local function ReceiveCast(source, state, _, unit, guid, spellID)
    guid = Public(guid)
    if type(guid) ~= 'string' or guid == '' or guid == state.castGUID then return false end
    if Identity(spellID, unit) ~= CastIdentity(source.params) then return false end
    state.castGUID, state.castAt = guid, GetTime()
    state.sequence = state.sequence + 1
    source.castPending = true
    return true
end

local function ReadCast(source)
    local changed = source.castPending == true
    source.castPending = nil
    return changed
end

function Sources:RegisterCastSourceType()
    if self.castSourceTypeRegistered then return true end
    local sourceType, code = Monitor:RegisterSourceType('spell-cast', {
        createState = CastState, getIdentity = CastIdentity,
        read = ReadCast, onEvent = ReceiveCast,
        events = {{ event = 'UNIT_SPELLCAST_SUCCEEDED', units = { 'player', 'target', 'focus' },
            identityArg = 3, mapIdentity = Identity, synchronous = true }},
    })
    if not sourceType and code ~= 'source-type-exists' then return nil, code end
    self.castSourceTypeRegistered = true
    return true
end

return Sources
