do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
YUI = YUI or _G.YUI
local M = YUI and YUI.Monitor
local Sources = M and M.CommonSources
local Spell = YUI and YUI.API and YUI.API.Spell
if not (Sources and Spell) then return end
local extensions = {}
local function Public(value)
    if type(issecretvalue) == 'function' and issecretvalue(value) then return nil end
    return value
end
local function ValidDuration(value)
    value = Public(value)
    return type(value) == 'number' and value == value and value >= 0 and value < 86400
end
local function Identity(id, unit)
    id, unit = Public(id), Public(unit)
    if type(id) == 'number' and id > 0 and (unit == 'player' or unit == 'target' or unit == 'focus') then
        return unit .. ':' .. id
    end
end
local function ParamIdentity(params) return Identity(params.spellID, params.unit) end
local function Read(source)
    local changed = source.predictionPending == true
    source.predictionPending = nil
    return changed
end
local function Receive(source, state, event, unit, guid, id, sentID)
    if event == 'UNIT_SPELLCAST_SENT' then guid, id = id, sentID end
    guid = Public(guid)
    if type(guid) ~= 'string' or guid == '' or Identity(id, unit) ~= ParamIdentity(source.params) then return false end
    local extension = extensions[source.params.extension]
    local now = GetTime()
    if event == 'UNIT_SPELLCAST_SENT' or event == 'UNIT_SPELLCAST_START' then
        if event == 'UNIT_SPELLCAST_START' and source.snapshotGUID == guid then return false end
        local ok, duration = pcall(extension.snapshot, source.params)
        source.snapshotGUID, source.snapshotAt = guid, now
        source.snapshotDuration = ok and ValidDuration(duration) and duration or nil
        return false
    elseif event ~= 'UNIT_SPELLCAST_SUCCEEDED' then
        if source.snapshotGUID == guid then source.snapshotGUID, source.snapshotDuration = nil, nil end
        return false
    end
    if state.castGUID == guid then return false end
    local duration = source.snapshotGUID == guid and now - source.snapshotAt <= 15 and source.snapshotDuration or nil
    source.snapshotGUID, source.snapshotDuration = nil, nil
    if duration == nil then
        local ok, fallback = pcall(extension.fallback, source.params)
        if ok and ValidDuration(fallback) then duration = fallback end
    end
    state.sequence = state.sequence + 1
    state.castGUID, state.castAt = guid, now
    state.targetAt = duration and now + duration or nil
    state.issue = not duration and 'prediction-duration-unavailable' or nil
    source.predictionPending = true
    return true
end
function Sources:RegisterCastPrediction(id, definition)
    if type(id) ~= 'string' or extensions[id] or type(definition) ~= 'table'
        or type(definition.snapshot) ~= 'function' or type(definition.fallback) ~= 'function' then return nil, 'invalid-cast-extension' end
    extensions[id] = { snapshot = definition.snapshot, fallback = definition.fallback }
    return true
end
function Sources:RegisterCastPredictionSourceType(extension)
    if not extensions[extension] then return nil, 'unknown-cast-extension' end
    self.predictionTypes = self.predictionTypes or {}
    local typeID = 'cast-prediction:' .. extension
    if self.predictionTypes[extension] then return typeID end
    local events = {}
    for _, event in ipairs({ 'UNIT_SPELLCAST_SENT', 'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_SUCCEEDED',
        'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED' }) do
        events[#events + 1] = { event = event, units = { 'player', 'target', 'focus' },
            identityArg = event == 'UNIT_SPELLCAST_SENT' and 4 or 3, mapIdentity = Identity, synchronous = true }
    end
    local registered, code = M:RegisterSourceType(typeID, { events = events, getIdentity = ParamIdentity,
        createState = function() return { sequence = 0 } end, read = Read, onEvent = Receive })
    if not registered and code ~= 'source-type-exists' then return nil, code end
    self.predictionTypes[extension] = true
    return typeID
end

local patterns = { zhCN = '在接下来的([%d%.]+)秒内', zhTW = '在後續的([%d%.]+)秒內',
    enUS = '[Ff]or the next ([%d%.]+) sec', enGB = '[Ff]or the next ([%d%.]+) sec' }
function Sources.ParseArcaneDuration(text, locale)
    text = Public(text)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('|T.-|t', ''):gsub('|A.-|a', '')
    local count, found = 0, nil
    if patterns[locale] then
        for value in text:gmatch(patterns[locale]) do count, found = count + 1, tonumber(value) end
    end
    if count > 0 then
        if count == 1 and found and found >= 15 and found <= 17.4 then return found end
        return nil
    end
    text = text:gsub(' ', ' '):gsub(' ', ' ')
    local changed
    repeat text, changed = text:gsub('(%d) (%d%d%d)', '%1%2') until changed == 0
    for token in text:gmatch('%d[%d%.,]*') do
        token = token:gsub('[.,]+$', '')
        local value
        if token:match('^%d+$') then value = tonumber(token)
        elseif token:match('^%d+[.,]%d%d?$') then value = tonumber((token:gsub(',', '.'))) end
        if value and value >= 15 and value <= 17.4 then count, found = count + 1, value end
    end
    if count == 1 then return found end
end
if YUI.IsRetail then
    Sources:RegisterCastPrediction('arcane-soul', {
        snapshot = function()
            return Sources.ParseArcaneDuration(Spell.GetPublicDescription and Spell.GetPublicDescription(365350), GetLocale())
        end,
        fallback = function()
            local known = Spell.GetKnownState and Spell.GetKnownState(449412)
            if known == true then return 17.4 elseif known == false then return 15 end
        end,
    })
end
return Sources
