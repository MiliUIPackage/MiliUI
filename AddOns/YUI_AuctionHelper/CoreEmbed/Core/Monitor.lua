do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
if not YUI then return end

local Monitor = YUI.Monitor or {}
YUI.Monitor = Monitor

local Instance = {}
Instance.__index = Instance

local ipairs = ipairs
local math_max = math.max
local math_min = math.min
local pairs = pairs
local pcall = pcall
local select = select
local string_find = string.find
local string_gsub = string.gsub
local string_lower = string.lower
local string_match = string.match
local string_sub = string.sub
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = unpack

local DEFAULT_MODULE_ID = "core.monitor"
local DEFAULT_UPDATE_INTERVAL = 0.1
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_ICON_TEXCOORDS = { 0.08, 0.92, 0.08, 0.92 }
local LOAD_EVENTS = {
    "YUI_WORLD_READY",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED",
    "ACTIVE_COMBAT_CONFIG_CHANGED",
}
local CONTEXT_LOAD_EVENTS = {
    PLAYER_SPECIALIZATION_CHANGED = true,
    PLAYER_TALENT_UPDATE = true,
    TRAIT_CONFIG_UPDATED = true,
    ACTIVE_COMBAT_CONFIG_CHANGED = true,
}
local CONTEXT_LOAD_DELAY = 0.1

Monitor.instances = Monitor.instances or {}
Monitor.order = Monitor.order or {}
Monitor.Policy = Monitor.Policy or {
    defaultUpdateInterval = DEFAULT_UPDATE_INTERVAL,
    inactiveUpdateInterval = 0.25,
    eventThrottle = 0.02,
    cacheSnapshotsPerTick = true,
    diffPresenterUpdates = true,
    collectStats = true,
}
Monitor._owner = Monitor._owner or {}
Monitor._auraCache = Monitor._auraCache or {}
Monitor._activeTickers = Monitor._activeTickers or {}
Monitor._activeTickerCount = Monitor._activeTickerCount or 0
Monitor._stats = Monitor._stats or {
    refreshes = 0,
    triggerUpdates = 0,
    presenterUpdates = 0,
    contextRefreshRequests = 0,
    contextRefreshCoalesced = 0,
    contextRefreshExecutions = 0,
}
Monitor._stats.contextRefreshRequests =
    Monitor._stats.contextRefreshRequests or 0
Monitor._stats.contextRefreshCoalesced =
    Monitor._stats.contextRefreshCoalesced or 0
Monitor._stats.contextRefreshExecutions =
    Monitor._stats.contextRefreshExecutions or 0
Monitor._conditionScheduler = Monitor._conditionScheduler or {
    jobs = {},
    byInstance = {},
    token = 0,
    sequence = 0,
    pending = 0,
    scheduled = 0,
    fired = 0,
    requeued = 0,
    canceled = 0,
}
Monitor._delayedScheduler = Monitor._delayedScheduler or {
    jobs = {},
    byInstance = {},
    pending = 0,
    scheduled = 0,
    fired = 0,
    canceled = 0,
}
Monitor._triggerSchemas = Monitor._triggerSchemas or {}
Monitor._devLog = Monitor._devLog or {
    enabled = false,
    limit = 240,
    rows = {},
    cursor = 0,
    count = 0,
    serial = 0,
}
Monitor._devOwner = Monitor._devOwner or {}

local DEFAULT_TRIGGER_SCHEMAS = {
    playerAura = {
        label = "玩家光环",
        fields = {
            { key = "spellID", type = "number", required = true },
            { key = "unit", type = "unit", default = "player", readOnly = true },
            { key = "icon", type = "texture" },
        },
        example = { id = "aura", type = "playerAura", unit = "player", spellID = 0 },
    },
    unitAura = {
        label = "单位光环",
        fields = {
            { key = "unit", type = "unit", default = "target" },
            { key = "spellID", type = "number", required = true },
            { key = "icon", type = "texture" },
        },
        example = { id = "targetAura", type = "unitAura", unit = "target", spellID = 0 },
    },
    unitSpellcastSucceeded = {
        label = "施法成功",
        hidden = true,
        deprecated = true,
        fields = {
            { key = "unit", type = "unit", default = "player" },
            { key = "spellID", type = "number" },
            { key = "duration", type = "number", default = 0.25 },
        },
        example = { id = "cast", type = "event", event = "UNIT_SPELLCAST_SUCCEEDED", unit = "player", spellID = 0, duration = 0.25 },
    },
    event = {
        label = "事件",
        fields = {
            { key = "event", type = "event", default = "PLAYER_ENTERING_WORLD" },
            { key = "duration", type = "number", default = 0.25 },
        },
        eventFields = {
            default = {},
            unitDefault = {
                { key = "unit", type = "unit", default = "player" },
            },
            UNIT_SPELLCAST_SUCCEEDED = {
                { key = "unit", type = "unit", default = "player" },
                { key = "spellID", type = "number" },
            },
            SPELL_UPDATE_COOLDOWN = {
                { key = "spellID", type = "number" },
                { key = "matchBaseSpellID", type = "boolean", default = true },
            },
        },
        eventDefaults = {
            UNIT_SPELLCAST_SUCCEEDED = { unit = "player", duration = 0.25 },
            SPELL_UPDATE_COOLDOWN = { duration = 1, matchBaseSpellID = true },
        },
        example = { id = "refresh", type = "event", event = "PLAYER_ENTERING_WORLD", duration = 0.25 },
    },
    spellCooldownWindow = {
        label = "技能冷却窗口",
        hidden = true,
        deprecated = true,
        fields = {
            { key = "spellID", type = "number", required = true },
            { key = "duration", type = "number", default = 1 },
            { key = "matchBaseSpellID", type = "boolean", default = true },
        },
        example = { id = "cooldown", type = "event", event = "SPELL_UPDATE_COOLDOWN", spellID = 0, duration = 1 },
    },
    cooldownViewer = { label = "冷却管理器", future = true, fields = {}, example = { id = "cdm", type = "cooldownViewer", category = "essential" } },
    unitPower = { label = "单位资源", future = true, fields = {}, example = { id = "power", type = "unitPower", unit = "player" } },
    rune = { label = "符文", future = true, fields = {}, example = { id = "rune", type = "rune" } },
    unitCast = { label = "单位施法", future = true, fields = {}, example = { id = "castbar", type = "unitCast", unit = "player" } },
    itemCooldown = { label = "物品冷却", future = true, fields = {}, example = { id = "item", type = "itemCooldown", itemID = 0 } },
    auraInstance = { label = "光环实例", future = true, fields = {}, example = { id = "auraInstance", type = "auraInstance", unit = "target" } },
}

local function EventBus()
    return YUI.Event
end

local function SecurityAPI()
    return (YUI.API and YUI.API.Security) or YUI.WOW_API or {}
end

local function UnitAPI()
    return (YUI.API and YUI.API.Unit) or YUI.WOW_API or {}
end

local function SpellAPI()
    return (YUI.API and YUI.API.Spell) or YUI.WOW_API or {}
end

local function TalentAPI()
    return (YUI.API and YUI.API.Talent) or YUI.WOW_API or {}
end

local function GUI2()
    return YUI.GUI2 or YUI.GUI
end

local function Now()
    if type(GetTime) == "function" then
        return GetTime()
    end
    return 0
end

local function MonitorOnUpdate(_, elapsed)
    local cpuWatchdog = YUI.CPUWatchdog
    local cpuStartedAt = cpuWatchdog and cpuWatchdog.timingActive and cpuWatchdog:BeginProbeTiming()
    Monitor:_OnUpdate(elapsed)
    if cpuStartedAt then cpuWatchdog:EndProbeTiming("core.monitor", cpuStartedAt) end
end

local function MonitorWakeTimerCallback()
    Monitor._wakeTimer = nil
    Monitor:_RunScheduledWork(Now())
end

local function MonitorRuntimeEventHandler(event)
    if CONTEXT_LOAD_EVENTS[event] then
        Monitor:RequestRefreshLoad(event)
        return
    end
    Monitor:RefreshLoad(event)
end

local function MonitorContextRefreshTimerCallback()
    Monitor._contextRefreshTimer = nil
    local reason = Monitor._contextRefreshReason or "context-coalesced"
    Monitor._contextRefreshReason = nil
    Monitor._stats.contextRefreshExecutions =
        Monitor._stats.contextRefreshExecutions + 1
    Monitor:RefreshLoad(reason)
end

local function SafeCall(label, func, ...)
    if type(func) ~= "function" then return false, nil end
    local Security = SecurityAPI()
    local ok, result
    if Security and Security.SafeCall then
        ok, result = Security.SafeCall(label, func, ...)
    else
        ok, result = pcall(func, ...)
    end
    if ok ~= true and Monitor and Monitor.IsLogEnabled and Monitor:IsLogEnabled() then
        Monitor:_Log("error", nil, { label = label, message = tostring(result) })
    end
    return ok, result
end

local function IsSecretValue(value)
    local Security = SecurityAPI()
    if Security and Security.IsSecretValue then
        return Security.IsSecretValue(value) == true
    end
    if not issecretvalue then return false end
    local ok, result = pcall(issecretvalue, value)
    return ok and result == true
end

local function SafeNumber(value)
    local Security = SecurityAPI()
    if Security and Security.SafeNumber then
        return Security.SafeNumber(value)
    end
    if value == nil or IsSecretValue(value) then return nil end
    local ok, result = pcall(tonumber, value)
    if ok and result ~= nil and not IsSecretValue(result) then
        return result
    end
    return nil
end

local function SafeString(value)
    local Security = SecurityAPI()
    if Security and Security.SafeString then
        local text = Security.SafeString(value)
        if text ~= nil then return text end
    end
    if value == nil or IsSecretValue(value) then return nil end
    if type(value) == "string" then return value end
    return nil
end

local function SafeTexture(value, fallback)
    if value == nil or IsSecretValue(value) then return fallback end
    if type(value) == "string" and value ~= "" then return value end
    local numberValue = SafeNumber(value)
    if numberValue ~= nil then return numberValue end
    return fallback
end

local function TableContains(list, value)
    if type(list) ~= "table" then return false end
    for _, item in ipairs(list) do
        if item == value then return true end
    end
    return false
end

local function CopyTable(source, seen)
    if type(source) ~= "table" then return source end
    seen = seen or {}
    if seen[source] then return seen[source] end
    local copy = {}
    seen[source] = copy
    for key, value in pairs(source) do
        copy[CopyTable(key, seen)] = CopyTable(value, seen)
    end
    return copy
end

local function StartsWith(text, prefix)
    text = tostring(text or "")
    prefix = tostring(prefix or "")
    return prefix == "" or string_sub(text, 1, #prefix) == prefix
end

local function EnsureDefaultTriggerSchemas()
    if Monitor._defaultSchemasRegistered then return end
    Monitor._defaultSchemasRegistered = true
    for triggerType, schema in pairs(DEFAULT_TRIGGER_SCHEMAS) do
        Monitor._triggerSchemas[triggerType] = Monitor._triggerSchemas[triggerType] or CopyTable(schema)
    end
end

local function GetTriggerSummary(trigger)
    if type(trigger) ~= "table" then return nil end
    return {
        index = trigger.index,
        id = trigger.id,
        type = trigger.type,
        active = trigger.active == true,
        changed = trigger.changed == true,
        activation = trigger.activation ~= false,
        unit = trigger.unit,
        spellID = trigger.spellID,
        event = trigger.event,
        duration = trigger.duration,
    }
end

local function NormalizeLogInstance(instance)
    if type(instance) == "table" then
        return instance.id, instance.moduleId
    end
    return tostring(instance or ""), nil
end

local function NormalizeDevTrigger(trigger)
    local copy = CopyTable(trigger)
    if type(copy) ~= "table" then return nil end
    copy.type = copy.type or "event"
    return copy
end

local function RemoveOrder(order, id)
    for index = #order, 1, -1 do
        if order[index] == id then
            table_remove(order, index)
        end
    end
end

local function CopyColor(color, fallback)
    if type(color) == "function" then
        local ok, value = SafeCall("Monitor:color", color)
        if ok then color = value end
    end
    if type(color) ~= "table" then color = fallback end
    if type(color) ~= "table" then return nil end
    return color[1], color[2], color[3], color[4]
end

local function NormalizeUnit(unit, fallback)
    local value = SafeString(unit)
    if value and value ~= "" then return value end
    return fallback or "player"
end

local function ReadAuraField(aura, ...)
    if type(aura) ~= "table" then return nil end
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        local value = aura[key]
        if value ~= nil and not IsSecretValue(value) then
            return value
        end
    end
    return nil
end

local function UpdateAuraData(trigger, aura)
    local data = trigger.data
    local now = Now()
    local duration = SafeNumber(ReadAuraField(aura, "duration", "durationSec"))
    local expirationTime = SafeNumber(ReadAuraField(aura, "expirationTime", "expiration"))
    local remaining
    local elapsed

    if expirationTime then
        remaining = expirationTime - now
        if remaining < 0 then remaining = 0 end
    end
    if duration and remaining then
        elapsed = duration - remaining
        if elapsed < 0 then elapsed = 0 end
    end

    data.aura = aura
    data.name = SafeString(ReadAuraField(aura, "name"))
    data.icon = SafeTexture(ReadAuraField(aura, "icon", "texture", "textureID", "iconID"), trigger.icon)
    data.duration = duration
    data.expirationTime = expirationTime
    data.remaining = remaining
    data.elapsed = elapsed
    data.progress = (duration and duration > 0 and elapsed) and math_min(1, math_max(0, elapsed / duration)) or nil
    data.applications = SafeNumber(ReadAuraField(aura, "applications", "stacks"))
    data.spellID = SafeNumber(ReadAuraField(aura, "spellId", "spellID")) or trigger.spellID
    data.updatedAt = now
    local time = trigger.time
    if type(time) ~= "table" then
        time = {}
        trigger.time = time
    else
        for key in pairs(time) do
            time[key] = nil
        end
    end
    if duration and duration > 0 and expirationTime then
        time.duration = duration
        time.expirationTime = expirationTime
        time.remaining = remaining
        time.elapsed = elapsed
        time.progress = data.progress
        time.updatedAt = now
    else
        time.duration = duration or trigger.duration
        time.updatedAt = now
    end
end

local function ClearAuraData(trigger)
    local data = trigger.data
    data.aura = nil
    data.name = nil
    data.icon = trigger.icon
    data.duration = nil
    data.expirationTime = nil
    data.remaining = nil
    data.elapsed = nil
    data.progress = nil
    data.applications = nil
    data.spellID = trigger.spellID
    data.updatedAt = Now()
    if type(trigger.time) == "table" then
        for key in pairs(trigger.time) do
            trigger.time[key] = nil
        end
        trigger.time.duration = trigger.duration
    end
end

local function AuraCacheKey(unit, spellID)
    return tostring(unit or "") .. ":" .. tostring(spellID or "")
end

local function GetAuraSnapshot(instance, unit, spellID)
    local manager = instance.manager
    if not (manager.Policy and manager.Policy.cacheSnapshotsPerTick) then
        local Unit = UnitAPI()
        if unit == "player" and Unit.GetPlayerAuraBySpellID then
            return Unit.GetPlayerAuraBySpellID(spellID)
        end
        if Unit.GetUnitAuraBySpellID then
            return Unit.GetUnitAuraBySpellID(unit, spellID)
        end
        return nil
    end

    local key = AuraCacheKey(unit, spellID)
    local cached = manager._auraCache[key]
    if cached and cached.serial == manager._auraCacheSerial then
        return cached.value
    end

    local Unit = UnitAPI()
    local value
    if unit == "player" and Unit.GetPlayerAuraBySpellID then
        value = Unit.GetPlayerAuraBySpellID(spellID)
    elseif Unit.GetUnitAuraBySpellID then
        value = Unit.GetUnitAuraBySpellID(unit, spellID)
    end
    manager._auraCache[key] = {
        serial = manager._auraCacheSerial,
        value = value,
    }
    return value
end

local function NewToken(kind, value)
    return { kind = kind, value = value }
end

local function TokenizeExpression(expression)
    local normalized = string_gsub(expression or "", "&", " and ")
    normalized = string_gsub(normalized, "|", " or ")
    normalized = string_gsub(normalized, "!", " not ")

    local tokens = {}
    local index = 1
    local length = #normalized
    while index <= length do
        local char = string_sub(normalized, index, index)
        if char == " " or char == "\t" or char == "\n" or char == "\r" then
            index = index + 1
        elseif char == "(" or char == ")" then
            tokens[#tokens + 1] = NewToken(char, char)
            index = index + 1
        elseif string_sub(normalized, index, index + 1) == "t[" then
            local stop = string_find(normalized, "]", index + 2, true)
            if not stop then return nil, "missing ]" end
            local numberValue = tonumber(string_sub(normalized, index + 2, stop - 1))
            if not numberValue then return nil, "invalid trigger index" end
            tokens[#tokens + 1] = NewToken("trigger", numberValue)
            index = stop + 1
        else
            local word = string_match(string_sub(normalized, index), "^[%a_][%w_]*")
            if not word then
                return nil, "invalid token near " .. string_sub(normalized, index, index)
            end
            local lower = string_lower(word)
            if lower == "and" or lower == "or" or lower == "not" then
                tokens[#tokens + 1] = NewToken(lower, lower)
            elseif lower == "true" or lower == "false" then
                tokens[#tokens + 1] = NewToken("literal", lower == "true")
            else
                return nil, "unknown token " .. word
            end
            index = index + #word
        end
    end

    return tokens
end

local function CompileExpression(expression)
    if type(expression) ~= "string" or expression == "" then return nil end

    local tokens, tokenError = TokenizeExpression(expression)
    if not tokens then
        return nil, tokenError
    end

    local cursor = 1
    local function Peek()
        return tokens[cursor]
    end
    local function Take(kind)
        local token = tokens[cursor]
        if token and token.kind == kind then
            cursor = cursor + 1
            return token
        end
        return nil
    end

    local ParseOr
    local function ParsePrimary()
        local token = Peek()
        if not token then return nil, "unexpected end" end
        if Take("(") then
            local node, err = ParseOr()
            if err then return nil, err end
            if not Take(")") then return nil, "missing )" end
            return node
        end
        token = Take("trigger")
        if token then
            return { op = "trigger", index = token.value }
        end
        token = Take("literal")
        if token then
            return { op = "literal", value = token.value }
        end
        return nil, "unexpected token " .. tostring(Peek() and Peek().kind)
    end

    local function ParseUnary()
        if Take("not") then
            local node, err = ParseUnary()
            if err then return nil, err end
            return { op = "not", node = node }
        end
        return ParsePrimary()
    end

    local function ParseAnd()
        local node, err = ParseUnary()
        if err then return nil, err end
        while Take("and") do
            local right
            right, err = ParseUnary()
            if err then return nil, err end
            node = { op = "and", left = node, right = right }
        end
        return node
    end

    ParseOr = function()
        local node, err = ParseAnd()
        if err then return nil, err end
        while Take("or") do
            local right
            right, err = ParseAnd()
            if err then return nil, err end
            node = { op = "or", left = node, right = right }
        end
        return node
    end

    local tree, parseError = ParseOr()
    if parseError then return nil, parseError end
    if cursor <= #tokens then
        return nil, "trailing token " .. tostring(tokens[cursor].kind)
    end

    local function Eval(node, triggers)
        if node.op == "literal" then return node.value == true end
        if node.op == "trigger" then
            local trigger = triggers[node.index]
            return trigger and trigger.active == true or false
        end
        if node.op == "not" then return not Eval(node.node, triggers) end
        if node.op == "and" then return Eval(node.left, triggers) and Eval(node.right, triggers) end
        if node.op == "or" then return Eval(node.left, triggers) or Eval(node.right, triggers) end
        return false
    end

    return function(_, triggers)
        return Eval(tree, triggers)
    end
end

local function DefaultExpression(_, triggers)
    for _, trigger in ipairs(triggers) do
        if trigger.activation ~= false and trigger.active == true then
            return true
        end
    end
    return false
end

local function ResolveSpecID()
    local Talent = TalentAPI()
    if not (Talent.GetSpecialization and Talent.GetSpecializationInfo) then return nil end
    local index = Talent.GetSpecialization()
    if not index then return nil end
    local specID = Talent.GetSpecializationInfo(index)
    return SafeNumber(specID)
end

local function MatchesLoadTable(load)
    if load.retail ~= nil and (YUI.IsRetail == true) ~= (load.retail == true) then return false end
    if load.mists ~= nil and (YUI.IsMists == true) ~= (load.mists == true) then return false end
    if load.wrath ~= nil and (YUI.IsWrath == true) ~= (load.wrath == true) then return false end

    local Unit = UnitAPI()
    if load.class or load.classes then
        local classToken = Unit.GetClassToken and Unit.GetClassToken("player")
        if load.class and classToken ~= load.class then return false end
        if load.classes and not TableContains(load.classes, classToken) then return false end
    end

    if load.specID or load.specIDs then
        local specID = ResolveSpecID()
        if load.specID and specID ~= load.specID then return false end
        if load.specIDs and not TableContains(load.specIDs, specID) then return false end
    end

    if type(load.enabled) == "function" then
        local ok, result = SafeCall("Monitor:load.enabled", load.enabled)
        if not ok or result ~= true then return false end
    end

    return true
end

local function MatchesLoad(load, instance)
    if load == nil then return true end
    if type(load) == "function" then
        local ok, result = SafeCall("Monitor:load:" .. instance.id, load, instance)
        return ok and result == true
    end
    if type(load) == "table" then
        if load.all then
            for _, item in ipairs(load.all) do
                if not MatchesLoad(item, instance) then return false end
            end
            return true
        end
        if load.any then
            for _, item in ipairs(load.any) do
                if MatchesLoad(item, instance) then return true end
            end
            return false
        end
        return MatchesLoadTable(load)
    end
    return load == true
end

local function AppendLoadReason(reasons, text)
    if type(reasons) == "table" and text and text ~= "" then
        reasons[#reasons + 1] = text
    end
end

local function FormatExpected(value)
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for _, item in ipairs(value) do
        parts[#parts + 1] = tostring(item)
    end
    return table.concat(parts, ",")
end

local function ExplainLoadTable(load, instance, reasons)
    local ok = true
    if load.retail ~= nil and (YUI.IsRetail == true) ~= (load.retail == true) then
        ok = false
        AppendLoadReason(reasons, "版本条件不匹配：retail 期望=" .. tostring(load.retail) .. " 当前=" .. tostring(YUI.IsRetail == true))
    end
    if load.mists ~= nil and (YUI.IsMists == true) ~= (load.mists == true) then
        ok = false
        AppendLoadReason(reasons, "版本条件不匹配：mists 期望=" .. tostring(load.mists) .. " 当前=" .. tostring(YUI.IsMists == true))
    end
    if load.wrath ~= nil and (YUI.IsWrath == true) ~= (load.wrath == true) then
        ok = false
        AppendLoadReason(reasons, "版本条件不匹配：wrath 期望=" .. tostring(load.wrath) .. " 当前=" .. tostring(YUI.IsWrath == true))
    end

    local Unit = UnitAPI()
    if load.class or load.classes then
        local classToken = Unit.GetClassToken and Unit.GetClassToken("player")
        if load.class and classToken ~= load.class then
            ok = false
            AppendLoadReason(reasons, "职业不匹配：期望=" .. tostring(load.class) .. " 当前=" .. tostring(classToken))
        end
        if load.classes and not TableContains(load.classes, classToken) then
            ok = false
            AppendLoadReason(reasons, "职业不在允许列表：期望=" .. FormatExpected(load.classes) .. " 当前=" .. tostring(classToken))
        end
    end

    if load.specID or load.specIDs then
        local specID = ResolveSpecID()
        if load.specID and specID ~= load.specID then
            ok = false
            AppendLoadReason(reasons, "专精不匹配：期望=" .. tostring(load.specID) .. " 当前=" .. tostring(specID))
        end
        if load.specIDs and not TableContains(load.specIDs, specID) then
            ok = false
            AppendLoadReason(reasons, "专精不在允许列表：期望=" .. FormatExpected(load.specIDs) .. " 当前=" .. tostring(specID))
        end
    end

    if type(load.enabled) == "function" then
        local callOk, result = SafeCall("Monitor:load.enabled:" .. tostring(instance and instance.id or "?"), load.enabled)
        if not callOk then
            ok = false
            AppendLoadReason(reasons, "enabled 条件执行失败：" .. tostring(result))
        elseif result ~= true then
            ok = false
            AppendLoadReason(reasons, "enabled 条件返回 false")
        end
    end

    return ok
end

local function ExplainLoad(load, instance, reasons, depth)
    depth = (depth or 0) + 1
    if depth > 8 then
        AppendLoadReason(reasons, "load 条件嵌套过深")
        return false
    end
    if load == nil then return true end
    if type(load) == "function" then
        local ok, result = SafeCall("Monitor:load:" .. instance.id, load, instance)
        if not ok then
            AppendLoadReason(reasons, "load 函数执行失败：" .. tostring(result))
            return false
        end
        if result ~= true then
            AppendLoadReason(reasons, "load 函数返回 false")
            return false
        end
        return true
    end
    if type(load) == "table" then
        if load.all then
            local allOk = true
            for _, item in ipairs(load.all) do
                if not ExplainLoad(item, instance, reasons, depth) then
                    allOk = false
                end
            end
            return allOk
        end
        if load.any then
            local nestedReasons = {}
            for _, item in ipairs(load.any) do
                local itemReasons = {}
                if ExplainLoad(item, instance, itemReasons, depth) then
                    return true
                end
                for _, reason in ipairs(itemReasons) do
                    nestedReasons[#nestedReasons + 1] = reason
                end
            end
            AppendLoadReason(reasons, "any 条件全部失败")
            for _, reason in ipairs(nestedReasons) do
                AppendLoadReason(reasons, "  " .. reason)
            end
            return false
        end
        return ExplainLoadTable(load, instance, reasons)
    end
    if load ~= true then
        AppendLoadReason(reasons, "load 值不是 true：" .. tostring(load))
        return false
    end
    return true
end

local function GetLoadDiagnostic(instance)
    local load = instance and (instance.definition.load or instance.definition.loadConditions)
    local reasons = {}
    local ok = ExplainLoad(load, instance, reasons)
    local summary
    if ok then
        summary = "load 条件通过"
    elseif #reasons > 0 then
        summary = reasons[1]
    else
        summary = "load 条件未通过"
    end
    return {
        ok = ok == true,
        summary = summary,
        reasons = reasons,
        hasLoad = load ~= nil,
    }
end

local function ResolveValue(value, instance, fallback)
    if type(value) == "function" then
        local ok, result = SafeCall("Monitor:value:" .. instance.id, value, instance.context, instance)
        if ok and result ~= nil then return result end
        return fallback
    end
    if value ~= nil then return value end
    return fallback
end

local function ResolveConditionPath(source, path)
    if type(source) ~= "table" or type(path) ~= "string" or path == "" then return nil end
    local value = source
    for key in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[key]
        if value == nil then return nil end
    end
    return value
end

local function RefreshTriggerTimeData(trigger, now)
    if not (trigger and trigger.active == true and type(trigger.data) == "table") then return false end
    local data = trigger.data
    local duration = SafeNumber(data.duration) or SafeNumber(trigger.duration)
    local expirationTime = SafeNumber(data.expirationTime)
    local startTime = SafeNumber(data.startTime)
    if not expirationTime and startTime and duration then
        expirationTime = startTime + duration
        data.expirationTime = expirationTime
    end
    if not (duration and duration > 0 and expirationTime) then
        if type(trigger.time) == "table" then
            for key in pairs(trigger.time) do
                trigger.time[key] = nil
            end
            trigger.time.duration = duration or trigger.duration
        end
        return nil
    end

    now = SafeNumber(now) or Now()
    local remaining = expirationTime - now
    if remaining < 0 then remaining = 0 end
    local elapsed = startTime and (now - startTime) or (duration - remaining)
    if elapsed < 0 then elapsed = 0 end
    if elapsed > duration then elapsed = duration end

    local time = trigger.time
    if type(time) ~= "table" then
        time = {}
        trigger.time = time
    end
    time.startTime = startTime
    time.duration = duration
    time.expirationTime = expirationTime
    time.remaining = remaining
    time.elapsed = elapsed
    time.progress = math_min(1, math_max(0, elapsed / duration))
    time.updatedAt = now

    data.startTime = startTime
    data.duration = duration
    data.expirationTime = expirationTime
    data.remaining = remaining
    data.elapsed = elapsed
    data.progress = time.progress
    data.updatedAt = now
    return time
end

local function ResolveTriggerTimeSource(trigger, rest)
    if not trigger then return nil end
    local time = RefreshTriggerTimeData(trigger, Now())
    if type(time) ~= "table" then return nil end
    return ResolveConditionPath(time, rest)
end

local function ResolveTriggerConditionSource(trigger, rest)
    if not trigger then return nil end
    if rest == "active" then return trigger.active == true end
    if rest == "changed" then return trigger.changed == true end
    if rest == "type" then return trigger.type end
    if rest == "id" then return trigger.id end
    if rest == "unit" then return trigger.unit end
    if rest == "spellID" then return trigger.spellID end
    if rest == "event" then return trigger.event end
    if string_sub(rest, 1, 5) == "time." then
        return ResolveTriggerTimeSource(trigger, string_sub(rest, 6))
    end
    if string_sub(rest, 1, 5) == "data." then
        RefreshTriggerTimeData(trigger, Now())
        return ResolveConditionPath(trigger.data, string_sub(rest, 6))
    end
    return ResolveConditionPath(trigger, rest)
end

local function ResolveConditionSource(instance, source)
    if type(instance) ~= "table" or type(source) ~= "string" then return nil end
    if source == "context.active" then return instance.active == true end
    if source == "context.running" then return instance.running == true end
    if source == "context.loaded" then return instance.loaded == true end
    if source == "context.visible" then return instance.visible == true end
    if source == "context.progress" then return instance.context and instance.context.progress end
    if string_sub(source, 1, 8) == "context." then
        return ResolveConditionPath(instance.context, string_sub(source, 9))
    end

    local triggerIndex, rest = string_match(source, "^t%[(%d+)%]%.(.+)$")
    if triggerIndex then
        return ResolveTriggerConditionSource(instance.triggers and instance.triggers[tonumber(triggerIndex)], rest)
    end

    local triggerId
    triggerId, rest = string_match(source, "^triggers%.([^%.]+)%.(.+)$")
    if triggerId then
        return ResolveTriggerConditionSource(instance.triggerById and instance.triggerById[triggerId], rest)
    end
    return nil
end

local function NormalizeConditionExpected(expected, actual, instance, rule)
    if type(expected) == "function" then
        local ok, result = SafeCall("Monitor:condition.value:" .. instance.id, expected, instance.context, rule, instance)
        expected = ok and result or nil
    end
    if type(actual) == "number" then
        return tonumber(expected)
    end
    if type(actual) == "boolean" then
        if expected == true or expected == "true" or expected == "1" or expected == 1 or expected == "是" then return true end
        if expected == false or expected == "false" or expected == "0" or expected == 0 or expected == "否" then return false end
    end
    return expected
end

local function ConditionRuleMatches(instance, rule)
    if type(rule) ~= "table" or rule.enabled == false then return false end
    local actual = ResolveConditionSource(instance, rule.source or rule.path)
    local operator = rule.operator or "truthy"
    if operator == "truthy" then return actual and true or false, actual, nil, operator end
    if operator == "falsy" then return not actual, actual, nil, operator end
    local expectedValue = rule.value
    if expectedValue == nil then expectedValue = rule.expected end
    local expected = NormalizeConditionExpected(expectedValue, actual, instance, rule)
    if operator == "equals" then return actual == expected, actual, expected, operator end
    if operator == "notEquals" then return actual ~= expected, actual, expected, operator end
    if operator == "gt" or operator == "gte" or operator == "lt" or operator == "lte" then
        local left = tonumber(actual)
        local right = tonumber(expected)
        if not (left and right) then return false, actual, expected, operator end
        if operator == "gt" then return left > right, actual, expected, operator end
        if operator == "gte" then return left >= right, actual, expected, operator end
        if operator == "lt" then return left < right, actual, expected, operator end
        return left <= right, actual, expected, operator
    end
    if operator == "contains" then
        local left = tostring(actual or "")
        local right = tostring(expected or "")
        return right ~= "" and string_find(left, right, 1, true) ~= nil, actual, expected, operator
    end
    return false, actual, expected, operator
end

local function GetConditionRuleId(rule, index)
    local id = type(rule) == "table" and SafeString(rule.id or rule.key or rule.name) or nil
    if id and id ~= "" then return id end
    return tostring(index or 0)
end

local function GetConditionRuleJobKey(instance, rule, index)
    return tostring(instance and instance.id or "?") .. ":" .. GetConditionRuleId(rule, index)
end

local function GetConditionActionKind(action)
    if type(action) ~= "table" then return nil end
    local kind = action.kind or action.actionType or action.type
    if kind == nil and (action.target or action.key) then kind = "override" end
    return kind
end

local function GetConditionActionFire(rule, action, kind)
    local fire = action.fire or rule.fire
    if fire == "onEnter" or fire == "onExit" or fire == "whileMatched" then
        return fire
    end
    if kind == "override" then return "whileMatched" end
    return "onEnter"
end

local function GetConditionActions(rule)
    if type(rule.actions) == "table" then
        if #rule.actions > 0 then return rule.actions end
        return { rule.actions }
    end
    if type(rule.action) == "table" then return { rule.action } end
    if rule.actionTarget or rule.actionValue then
        return {
            {
                type = "override",
                target = rule.actionTarget,
                value = rule.actionValue,
            },
        }
    end
    return nil
end

local function ResolveConditionActionValue(instance, rule, action)
    local value = action.value
    if type(value) == "function" then
        local ok, result = SafeCall("Monitor:condition.action.value:" .. instance.id, value, instance.context, rule, action, instance)
        return ok and result or nil
    end
    return value
end

local function ResolveConditionCallback(instance, action)
    local callback = action.callback or action.func
    if type(callback) == "function" then return callback end

    local name = SafeString(action.name or callback)
    if not (name and name ~= "") then return nil end
    local actions = instance.definition and instance.definition.conditionActions
    if type(actions) == "table" and type(actions[name]) == "function" then
        return actions[name]
    end
    return nil
end

local function RunConditionAction(instance, rule, action, overrides)
    local kind = GetConditionActionKind(action)
    if kind == "override" then
        local target = action.target or action.key
        if type(target) ~= "string" or target == "" then return false end
        overrides[target] = ResolveConditionActionValue(instance, rule, action)
        return true
    end

    if kind == "callback" then
        local callback = ResolveConditionCallback(instance, action)
        if type(callback) ~= "function" then return false end
        SafeCall("Monitor:condition.callback:" .. instance.id .. ":" .. tostring(rule.id or rule.name or "?"), callback, instance.context, rule, action, instance)
        return true
    end

    if kind == "sound" then
        local channel = action.channel or "Master"
        local path = ResolveConditionActionValue(instance, rule, action)
        path = path or action.file or action.path
        if type(path) == "string" and path ~= "" and type(PlaySoundFile) == "function" then
            pcall(PlaySoundFile, path, channel)
            return true
        end
        if action.sound and type(PlaySound) == "function" then
            pcall(PlaySound, action.sound, channel)
            return true
        end
    end
    return false
end

local function SourceEndsWith(source, suffix)
    return type(source) == "string" and string_sub(source, -#suffix) == suffix
end

local function GetConditionTimeKind(source)
    if source == "context.state.elapsed" or SourceEndsWith(source, ".time.elapsed") or SourceEndsWith(source, ".data.elapsed") then
        return "elapsed"
    end
    if source == "context.state.remaining" or SourceEndsWith(source, ".time.remaining") or SourceEndsWith(source, ".data.remaining") then
        return "remaining"
    end
    if source == "context.state.progress" or SourceEndsWith(source, ".time.progress") or SourceEndsWith(source, ".data.progress") then
        return "progress"
    end
    return nil
end

local function GetConditionTriggerFromSource(instance, source)
    if type(instance) ~= "table" or type(source) ~= "string" then return nil end

    local triggerIndex = string_match(source, "^t%[(%d+)%]%.")
    if triggerIndex then
        return instance.triggers and instance.triggers[tonumber(triggerIndex)] or nil
    end

    local triggerId = string_match(source, "^triggers%.([^%.]+)%.")
    if triggerId then
        return instance.triggerById and instance.triggerById[triggerId] or nil
    end

    return nil
end

local function GetConditionSourceDuration(instance, source)
    if source == "context.state.progress" or source == "context.state.elapsed" or source == "context.state.remaining" then
        return SafeNumber(instance and instance.context and instance.context.state and instance.context.state.duration)
    end

    local trigger = GetConditionTriggerFromSource(instance, source)
    if trigger then
        return SafeNumber(ResolveTriggerTimeSource(trigger, "duration"))
            or SafeNumber(trigger.data and trigger.data.duration)
            or SafeNumber(trigger.duration)
    end

    return nil
end

local function ComputeIncreasingDeadline(now, matched, left, right, operator, scale)
    scale = scale or 1
    if operator == "gte" and not matched and left < right then
        return now + math_max(0, (right - left) * scale)
    end
    if operator == "gt" and not matched and left <= right then
        return now + math_max(0, (right - left) * scale) + 0.01
    end
    if operator == "lt" and matched and left < right then
        return now + math_max(0, (right - left) * scale)
    end
    if operator == "lte" and matched and left <= right then
        return now + math_max(0, (right - left) * scale) + 0.01
    end
    return nil
end

local function ComputeDecreasingDeadline(now, matched, left, right, operator)
    if operator == "lte" and not matched and left > right then
        return now + math_max(0, left - right)
    end
    if operator == "lt" and not matched and left >= right then
        return now + math_max(0, left - right) + 0.01
    end
    if operator == "gt" and matched and left > right then
        return now + math_max(0, left - right)
    end
    if operator == "gte" and matched and left >= right then
        return now + math_max(0, left - right) + 0.01
    end
    return nil
end

local function ComputeConditionNextCheck(instance, rule, matched, actual, expected, operator)
    local source = rule.source or rule.path
    local left = tonumber(actual)
    local right = tonumber(expected)
    if not (left and right) then return nil end

    local now = Now()
    local kind = GetConditionTimeKind(source)
    if kind == "elapsed" then
        return ComputeIncreasingDeadline(now, matched, left, right, operator, 1)
    elseif kind == "remaining" then
        return ComputeDecreasingDeadline(now, matched, left, right, operator)
    elseif kind == "progress" then
        local duration = GetConditionSourceDuration(instance, source)
        if duration and duration > 0 then
            return ComputeIncreasingDeadline(now, matched, left, right, operator, duration)
        end
    end
    return nil
end

local function EvaluateConditionRules(instance, reason)
    local rules = instance and instance.definition and instance.definition.conditionRules
    if type(rules) ~= "table" or #rules == 0 then
        if instance then
            instance.conditionRuleMatchCount = 0
            instance.conditionRuleOverrides = nil
            instance.conditionRuleState = nil
        end
        return nil
    end
    if type(instance._PrepareContext) == "function" then
        instance:_PrepareContext()
    end
    if type(instance._CallCondition) == "function" then
        instance:_CallCondition("beforeEvaluate", reason)
    end
    if type(instance._PrepareContext) == "function" then
        instance:_PrepareContext()
    end
    local overrides
    local matched = 0
    instance.conditionRuleState = instance.conditionRuleState or {}
    for index, rule in ipairs(rules) do
        local ruleId = GetConditionRuleId(rule, index)
        local state = instance.conditionRuleState[ruleId] or {}
        instance.conditionRuleState[ruleId] = state

        local ruleMatched, actual, expected, operator = ConditionRuleMatches(instance, rule)
        local previousMatched = state.matched == true
        state.matched = ruleMatched == true
        state.actual = actual
        state.expected = expected
        state.updatedAt = Now()

        if ruleMatched then
            matched = matched + 1
            overrides = overrides or {}
        end

        local actions = GetConditionActions(rule)
        if type(actions) == "table" then
            overrides = overrides or {}
            for _, action in ipairs(actions) do
                local kind = GetConditionActionKind(action)
                local fire = GetConditionActionFire(rule, action, kind)
                local shouldRun = (fire == "whileMatched" and ruleMatched)
                    or (fire == "onEnter" and ruleMatched and not previousMatched)
                    or (fire == "onExit" and not ruleMatched and previousMatched)
                if shouldRun then
                    RunConditionAction(instance, rule, action, overrides)
                end
            end
        end

        local dueAt = ComputeConditionNextCheck(instance, rule, ruleMatched, actual, expected, operator)
        if dueAt and instance.manager and instance.manager._ScheduleConditionCheck then
            instance.manager:_ScheduleConditionCheck(instance, rule, index, dueAt, reason)
        elseif instance.manager and instance.manager._CancelConditionJob then
            instance.manager:_CancelConditionJob(instance, rule, index)
        end
    end
    instance.conditionRuleMatchCount = matched
    instance.conditionRuleOverrides = overrides
    return overrides
end

local function ResolveAppearanceValue(instance, target, value, fallback)
    local overrides = instance and instance.conditionRuleOverrides
    if type(overrides) == "table" and overrides[target] ~= nil then
        return overrides[target]
    end
    return ResolveValue(value, instance, fallback)
end

local function ApplyFillColor(widget, color)
    local r, g, b, a = CopyColor(color)
    if not r then return end
    if widget.SetFillColor then
        widget:SetFillColor({ r, g, b, a or 1 })
    elseif widget.SetStatusBarColor then
        widget:SetStatusBarColor(r, g, b, a or 1)
    end
end

local function ApplyPoint(frame, point, fallbackRelativeTo)
    if not (frame and type(point) == "table") then return end
    frame:ClearAllPoints()
    frame:SetPoint(
        point.point or "CENTER",
        point.relativeTo or fallbackRelativeTo or UIParent,
        point.relativePoint or point.point or "CENTER",
        point.x or 0,
        point.y or 0
    )
end

local function ApplyGenericIconSource(texture, source, fallback)
    if not texture then return false end
    local iconSource = source
    if iconSource == nil or iconSource == "" then iconSource = fallback end
    if iconSource == nil or iconSource == "" then iconSource = DEFAULT_ICON end
    if type(iconSource) == "string" and string_sub(iconSource, 1, 6) == "atlas:" and texture.SetAtlas then
        texture:SetTexture(nil)
        texture:SetAtlas(string_sub(iconSource, 7), false)
        texture.yuiMonitorAtlas = true
        return true
    end
    texture:SetTexture(iconSource)
    texture.yuiMonitorAtlas = nil
    return false
end

local function GetCoverTexCoords(width, height)
    local left, right, top, bottom = DEFAULT_ICON_TEXCOORDS[1], DEFAULT_ICON_TEXCOORDS[2], DEFAULT_ICON_TEXCOORDS[3], DEFAULT_ICON_TEXCOORDS[4]
    width = tonumber(width) or 1
    height = math_max(tonumber(height) or 1, 1)
    local targetRatio = width / height
    local sourceRatio = (right - left) / math_max(bottom - top, 0.0001)
    if targetRatio > sourceRatio then
        local visibleHeight = (right - left) / targetRatio
        local center = (top + bottom) / 2
        top = center - (visibleHeight / 2)
        bottom = center + (visibleHeight / 2)
    elseif targetRatio < sourceRatio then
        local visibleWidth = (bottom - top) * targetRatio
        local center = (left + right) / 2
        left = center - (visibleWidth / 2)
        right = center + (visibleWidth / 2)
    end
    return left, right, top, bottom
end

local function ApplyGenericIconFit(texture, width, height, base)
    if not texture or texture.yuiMonitorAtlas then return end
    base = type(base) == "table" and base or {}
    if type(base.texCoords) == "table" then
        texture:SetTexCoord(unpack(base.texCoords))
        return
    end
    if base.textureFit == "contain" then
        texture:SetTexCoord(DEFAULT_ICON_TEXCOORDS[1], DEFAULT_ICON_TEXCOORDS[2], DEFAULT_ICON_TEXCOORDS[3], DEFAULT_ICON_TEXCOORDS[4])
        return
    end
    texture:SetTexCoord(GetCoverTexCoords(width, height))
end

local function ApplyGenericIconPadding(slot, padding)
    if not (slot and slot.icon) then return end
    padding = tonumber(padding) or 0
    slot.icon:ClearAllPoints()
    if padding <= 0 then
        slot.icon:SetAllPoints(slot)
    else
        slot.icon:SetPoint("TOPLEFT", padding, -padding)
        slot.icon:SetPoint("BOTTOMRIGHT", -padding, padding)
    end
end

local function CreateGenericIconSlot(gui, parent, width, height, base, instance)
    if not (gui and parent) then return nil end
    base = type(base) == "table" and base or {}
    local slot
    if gui.CreatePanel then
        slot = gui:CreatePanel(parent, {
            width = width,
            height = height,
            surface = "color.surface.sunken",
            border = "color.border.default",
            radiusKey = base.shape == "rounded" and "layout.radius.control" or "layout.radius.icon",
        })
    elseif gui.CreateFrame then
        slot = gui:CreateFrame(parent, { width = width, height = height })
    end
    if not slot then return nil end
    local texture
    if gui.CreateIcon then
        texture = gui:CreateIcon(slot, {
            icon = DEFAULT_ICON,
            crop = false,
            fillParent = true,
            padding = tonumber(base.padding) or 0,
        })
    else
        texture = slot:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints(slot)
    end
    slot.icon = texture
    slot.SetIcon = function(frame, source)
        local sourceValue = ResolveValue(source, instance, nil)
        ApplyGenericIconSource(frame.icon, sourceValue, DEFAULT_ICON)
        ApplyGenericIconFit(frame.icon, frame:GetWidth() or width, frame:GetHeight() or height, base)
    end
    slot.SetIconLayout = function(frame, nextWidth, nextHeight, nextBase)
        nextBase = type(nextBase) == "table" and nextBase or base
        frame:SetSize(nextWidth, nextHeight)
        ApplyGenericIconPadding(frame, nextBase.padding)
        ApplyGenericIconSource(frame.icon, ResolveValue(nextBase.icon, instance, nil), DEFAULT_ICON)
        ApplyGenericIconFit(frame.icon, nextWidth, nextHeight, nextBase)
    end
    slot:SetIconLayout(width, height, base)
    return slot
end

local function CreateGenericTextSlot(gui, parent, width, height, fontSize, colorKey, justifyH)
    if not (gui and gui.CreateFrame and gui.CreateText and parent) then return nil end
    local slot = gui:CreateFrame(parent, {
        width = math_max(tonumber(width) or 120, 24),
        height = math_max(tonumber(height) or 24, 16),
        mouse = false,
    })
    local text = gui:CreateText(slot, "", fontSize or "font.size.md", colorKey or "color.text.primary", justifyH or "CENTER")
    text:SetPoint("CENTER", slot, "CENTER", 0, 0)
    text:SetSize(math_max(tonumber(width) or 120, 24), math_max(tonumber(height) or 24, 16))
    slot.text = text
    slot.SetText = function(frame, value)
        if frame.text and frame.text.SetText then frame.text:SetText(tostring(value or "")) end
    end
    slot.SetTextColor = function(frame, r, g, b, a)
        if frame.text and frame.text.SetTextColor then frame.text:SetTextColor(r, g, b, a or 1) end
    end
    return slot
end

local function GetLayerOverlayToken(overlayDef, index)
    if type(overlayDef) == "table" and type(overlayDef.id) == "string" and overlayDef.id ~= "" then
        return overlayDef.id
    end
    return "overlay:" .. tostring(index)
end

local function BuildVisualLayerOrder(appearance)
    local order, seen, valid, tokenToOverlay = {}, {}, { base = true }, {}
    local overlays = type(appearance.overlays) == "table" and appearance.overlays or {}
    for index, overlayDef in ipairs(overlays) do
        local token = GetLayerOverlayToken(overlayDef, index)
        valid[token] = true
        tokenToOverlay[token] = index
    end

    local existing = type(appearance.layerOrder) == "table" and appearance.layerOrder or nil
    if existing and #existing > 0 then
        for _, token in ipairs(existing) do
            if valid[token] and not seen[token] then
                order[#order + 1] = token
                seen[token] = true
            end
        end
        if not seen.base then
            table_insert(order, 1, "base")
            seen.base = true
        end
    else
        order[#order + 1] = "base"
        seen.base = true
    end

    for index, overlayDef in ipairs(overlays) do
        local token = GetLayerOverlayToken(overlayDef, index)
        if not seen[token] then
            order[#order + 1] = token
            seen[token] = true
        end
    end
    return order, tokenToOverlay
end

local function ApplyVisualLayer(widget, rootFrame, rank)
    if not widget then return end
    if widget.SetFrameLevel and rootFrame and rootFrame.GetFrameLevel then
        widget:SetFrameLevel((rootFrame:GetFrameLevel() or 0) + rank)
    end
    if widget.SetDrawLayer then
        widget:SetDrawLayer("OVERLAY", math_min(rank, 7))
    end
    if widget.text and widget.text.SetDrawLayer then
        widget.text:SetDrawLayer("OVERLAY", math_min(rank, 7))
    end
end

local function ApplyVisualLayerOrder(visual, appearance)
    if not (visual and appearance) then return end
    local order, tokenToOverlay = BuildVisualLayerOrder(appearance)
    local baseWidget = visual.icon or visual.bar or visual.text
    for rank, token in ipairs(order) do
        if token == "base" then
            ApplyVisualLayer(baseWidget, visual.frame, rank)
        elseif visual.overlays then
            ApplyVisualLayer(visual.overlays[tokenToOverlay[token]], visual.frame, rank)
        end
    end
end

local ResolveBaseIcon

local function EnsureGenericPresenter(instance)
    local appearance = instance.definition.appearance or {}
    if appearance.presenter then return appearance.presenter end
    local gui = GUI2()
    if not (gui and gui.CreateFrame and UIParent) then return nil end

    local visual = instance.visual
    if visual and visual.frame then return visual end

    local base = appearance.base or {}
    local baseType = base.type or appearance.type or "icon"
    local fallbackSize = ResolveValue(base.size, instance, nil)
    local width = ResolveValue(base.width or appearance.width or fallbackSize, instance, baseType == "bar" and 180 or 64)
    local height = ResolveValue(base.height or appearance.height or fallbackSize, instance, baseType == "bar" and 24 or 64)
    local frame = gui:CreateFrame(UIParent, {
        width = width,
        height = height,
        strata = appearance.strata or "MEDIUM",
        clampedToScreen = appearance.clampedToScreen ~= false,
        mouse = appearance.mouse == true,
        hidden = true,
    })
    visual = {
        frame = frame,
        baseType = baseType,
        overlays = {},
    }
    instance.visual = visual

    if baseType == "bar" and gui.Data and gui.Data.CreateProgressBar then
        local bar = gui.Data:CreateProgressBar(frame, {
            width = width + ((base.iconPosition == "left"
                or base.iconPosition == "right")
                and (tonumber(base.iconSize) or height) or 0),
            height = height + ((base.iconPosition == "top"
                or base.iconPosition == "bottom"
                or base.iconPosition == "down")
                and (tonumber(base.iconSize) or height) or 0),
            value = 0,
            iconPosition = base.iconPosition,
            iconSize = base.iconSize,
            icon = ResolveBaseIcon(instance, base, nil),
            fillColor = base.fillColor,
        })
        bar:SetPoint("CENTER", frame, "CENTER", 0, 0)
        visual.bar = bar
    elseif baseType == "text" and gui.CreateText then
        local text = CreateGenericTextSlot(gui, frame, width, height, base.fontSize or "font.size.lg", base.colorKey or "color.text.primary", base.justifyH or "CENTER")
        text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        visual.text = text
    else
        local icon = CreateGenericIconSlot(gui, frame, width, height, base, instance)
        if icon then
            icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
            visual.icon = icon
        end
    end

    if type(appearance.overlays) == "table" then
        for _, overlayDef in ipairs(appearance.overlays) do
            local overlayType = overlayDef.type or "text"
            local overlay
            if overlayType == "bar" and gui.Data and gui.Data.CreateProgressBar then
                overlay = gui.Data:CreateProgressBar(frame, {
                    width = overlayDef.width or width,
                    height = overlayDef.height or 5,
                    value = 0,
                    fillColor = overlayDef.fillColor,
                })
            elseif gui.CreateText then
                overlay = CreateGenericTextSlot(gui, frame, overlayDef.width or math_max((tonumber(width) or 64) * 4, 240), overlayDef.height or 28, overlayDef.fontSize or "font.size.md", overlayDef.colorKey or "color.text.primary", overlayDef.justifyH or "CENTER")
            end
            if overlay then
                overlay.definition = overlayDef
                ApplyPoint(overlay, overlayDef.point or { point = "CENTER" }, frame)
                visual.overlays[#visual.overlays + 1] = overlay
            end
        end
    end

    ApplyVisualLayerOrder(visual, appearance)
    ApplyPoint(frame, appearance.point or { point = "CENTER", y = -120 })
    return visual
end

local function UpdateGenericPresenter(instance)
    local visual = EnsureGenericPresenter(instance)
    if not (visual and visual.frame) then return false end

    local appearance = instance.definition.appearance or {}
    local base = appearance.base or {}
    local baseType = visual.baseType or base.type or appearance.type or "icon"
    local sizeOverride = tonumber(ResolveAppearanceValue(instance, "base.size", nil, nil))
    local defaultSize = tonumber(base.size) or 64
    local widthDefault = baseType == "bar" and 180 or (sizeOverride or defaultSize)
    local heightDefault = baseType == "bar" and 24 or (sizeOverride or defaultSize)
    local widthSource = sizeOverride or base.width or appearance.width
    local heightSource = sizeOverride or base.height or appearance.height
    local width = tonumber(ResolveAppearanceValue(instance, "frame.width", widthSource, widthDefault)) or widthDefault
    local height = tonumber(ResolveAppearanceValue(instance, "frame.height", heightSource, heightDefault)) or heightDefault
    if visual.frame.SetSize then
        visual.frame:SetSize(width, height)
    end

    if visual.icon then
        if visual.icon.SetIconLayout then
            visual.icon:SetIconLayout(width, height, base)
        elseif visual.icon.SetSize then
            visual.icon:SetSize(width, height)
        end
        if visual.icon.SetIcon then
            visual.icon:SetIcon(ResolveBaseIcon(instance, base, DEFAULT_ICON))
        end
    end
    if visual.bar and visual.bar.SetValue then
        visual.bar:SetValue(tonumber(ResolveAppearanceValue(instance, "base.value", base.value, instance.context.progress or 0)) or 0)
        ApplyFillColor(visual.bar, ResolveAppearanceValue(instance, "base.fillColor", base.fillColor, nil))
        if visual.bar.SetIcon then
            visual.bar:SetIcon(ResolveBaseIcon(instance, base, nil))
        elseif visual.bar.icon and visual.bar.icon.SetTexture then
            visual.bar.icon:SetTexture(ResolveBaseIcon(instance, base, nil))
        end
    end
    if visual.text then
        visual.text:SetText(tostring(ResolveAppearanceValue(instance, "base.text", base.text, "")))
        local r, g, b, a = CopyColor(ResolveAppearanceValue(instance, "base.color", base.color or base.textColor, nil))
        if r then visual.text:SetTextColor(r, g, b, a or 1) end
    end

    for index, overlay in ipairs(visual.overlays) do
        local overlayDef = overlay.definition or {}
        if overlay.SetValue then
            overlay:SetValue(tonumber(ResolveAppearanceValue(instance, "overlay[" .. index .. "].value", overlayDef.value, 0)) or 0)
            ApplyFillColor(overlay, ResolveAppearanceValue(instance, "overlay[" .. index .. "].fillColor", overlayDef.fillColor, nil))
        elseif overlay.SetText then
            overlay:SetText(tostring(ResolveAppearanceValue(instance, "overlay[" .. index .. "].text", overlayDef.text, "")))
            local r, g, b, a = CopyColor(ResolveAppearanceValue(instance, "overlay[" .. index .. "].color", overlayDef.color, nil))
            if r then overlay:SetTextColor(r, g, b, a or 1) end
        end
        local overlayVisible = ResolveAppearanceValue(instance, "overlay[" .. index .. "].visible", overlayDef.visible, nil)
        if overlayVisible ~= nil then
            if overlayVisible then overlay:Show() else overlay:Hide() end
        end
    end

    ApplyVisualLayerOrder(visual, appearance)

    local forcedVisible = ResolveAppearanceValue(instance, "visible", nil, nil)
    if forcedVisible == false then
        visual.frame:Hide()
    elseif forcedVisible == true or instance.active or instance.manualVisible or instance.visible then
        visual.frame:Show()
    else
        visual.frame:Hide()
    end
    return true
end

local function CallPresenter(instance, method)
    local appearance = instance.definition.appearance or {}
    local presenter = appearance.presenter
    if instance.manager and instance.manager:IsLogEnabled() then
        instance.manager:_Log("presenter", instance, { method = method })
    end
    if presenter and type(presenter[method]) == "function" then
        SafeCall("Monitor:presenter." .. method .. ":" .. instance.id, presenter[method], instance, instance.context)
        return true
    end
    if method == "ensure" then
        return EnsureGenericPresenter(instance) ~= nil
    elseif method == "update" or method == "apply" then
        return UpdateGenericPresenter(instance)
    elseif method == "show" then
        local visual = EnsureGenericPresenter(instance)
        if visual and visual.frame then visual.frame:Show() end
        return true
    elseif method == "hide" then
        local visual = instance.visual
        if visual and visual.frame then visual.frame:Hide() end
        return true
    elseif method == "destroy" then
        local visual = instance.visual
        if visual and visual.frame then
            visual.frame:Hide()
            visual.frame:SetScript("OnUpdate", nil)
        end
        instance.visual = nil
        return true
    end
    return false
end

local function NormalizeTriggerDefinition(definition)
    if type(definition) ~= "table" then return nil end
    local triggerType = definition.type or "event"
    if triggerType ~= "unitSpellcastSucceeded" and triggerType ~= "spellCooldownWindow" then
        return definition
    end

    local normalized = CopyTable(definition)
    normalized.legacyType = triggerType
    normalized.type = "event"
    if triggerType == "unitSpellcastSucceeded" then
        normalized.event = normalized.event or "UNIT_SPELLCAST_SUCCEEDED"
        normalized.unit = normalized.unit or "player"
        if normalized.duration == nil then normalized.duration = 0.25 end
    elseif triggerType == "spellCooldownWindow" then
        normalized.event = normalized.event or "SPELL_UPDATE_COOLDOWN"
        normalized.keepArgs = false
    end
    return normalized
end

local function PrepareTrigger(instance, index, definition)
    if type(definition) ~= "table" then return nil end
    definition = NormalizeTriggerDefinition(definition)
    local spellID = SafeNumber(definition.spellID or definition.spellId)
    local duration = SafeNumber(definition.duration)
    local throttle = SafeNumber(definition.throttle)
    if not (throttle and throttle > 0) then throttle = nil end
    local debounce = SafeNumber(definition.debounce)
    if not (debounce and debounce > 0) then debounce = nil end
    local defaultUnit = definition.type == "playerAura" and "player" or nil
    local unit = (definition.unit ~= nil or defaultUnit ~= nil) and NormalizeUnit(definition.unit, defaultUnit) or nil
    local trigger = {
        index = index,
        id = definition.id or tostring(index),
        type = definition.type or "event",
        definition = definition,
        legacyType = definition.legacyType,
        unit = unit,
        event = definition.event,
        spellID = spellID,
        duration = duration,
        throttle = throttle,
        debounce = debounce,
        icon = definition.icon,
        activation = definition.activation,
        active = false,
        changed = false,
        data = {
            spellID = spellID,
            duration = duration,
            icon = definition.icon,
        },
        time = {
            duration = duration,
        },
    }
    return trigger
end

local function ResetTriggerRuntimeState(instance)
    if not instance or type(instance.triggers) ~= "table" then return end
    if instance.manager and instance.manager._CancelDelayedJobs then
        instance.manager:_CancelDelayedJobs(instance)
    end
    for _, trigger in ipairs(instance.triggers) do
        trigger.active = false
        trigger.changed = false
        trigger.pulseToken = (trigger.pulseToken or 0) + 1
        trigger.windowToken = (trigger.windowToken or 0) + 1
        if type(trigger.data) == "table" then
            for key in pairs(trigger.data) do
                trigger.data[key] = nil
            end
            trigger.data.spellID = trigger.spellID
            trigger.data.duration = trigger.duration
            trigger.data.icon = trigger.icon
        end
        if type(trigger.time) == "table" then
            for key in pairs(trigger.time) do
                trigger.time[key] = nil
            end
            trigger.time.duration = trigger.duration
        end
    end
end

local function ResolveSpellTexture(spellID)
    local id = SafeNumber(spellID)
    if not id then return nil end

    local Spell = SpellAPI()
    if Spell and Spell.GetTexture then
        local ok, texture = SafeCall("Monitor:spellTexture", Spell.GetTexture, id)
        if ok then
            local safeTexture = SafeTexture(texture, nil)
            if safeTexture then return safeTexture end
        end
    end
    if Spell and Spell.GetSpellIcon then
        local ok, texture = SafeCall("Monitor:spellIcon", Spell.GetSpellIcon, id)
        if ok then
            local safeTexture = SafeTexture(texture, nil)
            if safeTexture then return safeTexture end
        end
    end
    return nil
end

local function ResolveTriggerIcon(trigger)
    if type(trigger) ~= "table" then return nil end
    local data = trigger.data
    if type(data) == "table" then
        local dataIcon = SafeTexture(data.icon, nil)
        if dataIcon then return dataIcon end
        local dataSpellIcon = ResolveSpellTexture(data.spellID)
        if dataSpellIcon then return dataSpellIcon end
    end
    local triggerIcon = SafeTexture(trigger.icon, nil)
    if triggerIcon then return triggerIcon end
    return ResolveSpellTexture(trigger.spellID)
end

local function ResolveAutomaticBaseIcon(instance, fallback)
    local fallbackIcon = SafeTexture(fallback, nil) or DEFAULT_ICON
    if not (instance and type(instance.triggers) == "table") then
        return fallbackIcon
    end

    local selectedIcon
    local selectedTime = -1
    local selectedIndex = math.huge
    for index, trigger in ipairs(instance.triggers) do
        if trigger and trigger.active == true then
            local icon = ResolveTriggerIcon(trigger)
            if icon then
                local data = trigger.data
                local timestamp = type(data) == "table" and (SafeNumber(data.timestamp) or SafeNumber(data.updatedAt)) or nil
                timestamp = timestamp or 0
                if not selectedIcon or timestamp > selectedTime or (timestamp == selectedTime and index < selectedIndex) then
                    selectedIcon = icon
                    selectedTime = timestamp
                    selectedIndex = index
                end
            end
        end
    end

    return selectedIcon or fallbackIcon
end

function ResolveBaseIcon(instance, base, fallback)
    base = type(base) == "table" and base or {}
    local manualIcon = ResolveAppearanceValue(instance, "base.icon", base.icon, fallback or DEFAULT_ICON)
    if base.iconMode == "auto" then
        return ResolveAutomaticBaseIcon(instance, manualIcon)
    end
    return SafeTexture(manualIcon, DEFAULT_ICON)
end

local function TriggerMatchesUnit(trigger, unit)
    if trigger.unit then
        return NormalizeUnit(unit, "") == trigger.unit
    end
    return true
end

local function ClampProgress(value)
    value = SafeNumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function IsCooldownWindowTrigger(trigger)
    local duration = trigger and (SafeNumber(trigger.duration) or SafeNumber(trigger.definition and trigger.definition.duration))
    return trigger
        and trigger.type == "event"
        and trigger.event ~= nil
        and duration ~= nil
        and duration > 0
end

local function RefreshCooldownWindowData(trigger, now)
    if not IsCooldownWindowTrigger(trigger) then return false end
    if trigger.active ~= true then return false end

    now = SafeNumber(now) or Now()
    local data = trigger.data
    local startTime = SafeNumber(data.startTime)
    local duration = SafeNumber(data.duration) or SafeNumber(trigger.duration)
    local expirationTime = SafeNumber(data.expirationTime)
    if not (startTime and duration and duration > 0 and expirationTime) then
        local previous = trigger.active == true
        trigger.active = false
        trigger.changed = previous ~= false
        return trigger.changed
    end

    local remaining = expirationTime - now
    if remaining < 0 then remaining = 0 end
    local elapsed = now - startTime
    if elapsed < 0 then elapsed = 0 end
    if elapsed > duration then elapsed = duration end

    data.remaining = remaining
    data.elapsed = elapsed
    data.progress = ClampProgress(elapsed / duration)
    data.updatedAt = now
    local time = trigger.time
    if type(time) ~= "table" then
        time = {}
        trigger.time = time
    end
    time.startTime = startTime
    time.duration = duration
    time.expirationTime = expirationTime
    time.remaining = remaining
    time.elapsed = elapsed
    time.progress = data.progress
    time.updatedAt = now

    if remaining <= 0 then
        local previous = trigger.active == true
        trigger.active = false
        trigger.changed = previous ~= false
        return trigger.changed
    end

    trigger.changed = false
    return false
end

local function CooldownWindowMatches(trigger, spellID, baseSpellID)
    if not (trigger and trigger.spellID) then return false end

    local targetSpellID = trigger.spellID
    local eventSpellID = SafeNumber(spellID)
    if eventSpellID == targetSpellID then
        return true
    end

    if trigger.definition and trigger.definition.matchBaseSpellID == false then
        return false
    end

    return SafeNumber(baseSpellID) == targetSpellID
end

local function TriggerHasEvent(trigger, event)
    if not (trigger and trigger.type == "event" and event) then return false end
    if trigger.event == event then return true end
    return false
end

local function EventTriggerMatches(trigger, event, ...)
    if not TriggerHasEvent(trigger, event) then return false end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = select(1, ...)
        local spellID = select(3, ...)
        if not TriggerMatchesUnit(trigger, unit) then return false end
        return trigger.spellID == nil or SafeNumber(spellID) == trigger.spellID
    end

    if event == "SPELL_UPDATE_COOLDOWN" then
        local spellID = select(1, ...)
        local baseSpellID = select(2, ...)
        if trigger.spellID == nil then return true end
        return CooldownWindowMatches(trigger, spellID, baseSpellID)
    end

    if trigger.unit then
        local unit = select(1, ...)
        if not TriggerMatchesUnit(trigger, unit) then return false end
    end
    return true
end

local function ScheduleCooldownWindowReset(instance, trigger)
    if not (instance and trigger and instance.manager) then return end
    local expirationTime = SafeNumber(trigger.data and trigger.data.expirationTime)
    if not expirationTime then return end

    local token = (trigger.windowToken or 0) + 1
    trigger.windowToken = token
    instance.manager:_ScheduleDelayedTrigger(instance, trigger, "cooldown", expirationTime, token)
end

local function PopulateEventTriggerData(trigger, event, now, ...)
    local data = trigger.data
    data.event = event
    data.timestamp = now
    data.updatedAt = now
    data.count = (data.count or 0) + 1
    data.args = (trigger.definition.keepArgs ~= false and select("#", ...) > 0) and { ... } or nil

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        data.unit = NormalizeUnit(unit, trigger.unit or "player")
        data.castGUID = IsSecretValue(castGUID) and nil or castGUID
        data.spellID = SafeNumber(spellID) or trigger.spellID
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        local spellID, baseSpellID, category, startRecoveryCategory = ...
        data.spellID = SafeNumber(spellID) or trigger.spellID
        data.baseSpellID = SafeNumber(baseSpellID)
        data.category = SafeNumber(category)
        data.startRecoveryCategory = SafeNumber(startRecoveryCategory)
    elseif trigger.unit then
        data.unit = NormalizeUnit(select(1, ...), trigger.unit)
    end

    return data
end

local function StartCooldownWindowTrigger(instance, trigger, event, ...)
    local duration = SafeNumber(trigger.duration) or SafeNumber(trigger.definition and trigger.definition.duration)
    if not (duration and duration > 0) then return false end

    local now = Now()
    local previous = trigger.active == true
    local data = PopulateEventTriggerData(trigger, event, now, ...)
    trigger.active = true
    trigger.changed = previous ~= true
    data.startTime = now
    data.duration = duration
    data.expirationTime = now + duration
    data.remaining = duration
    data.elapsed = 0
    data.progress = 0
    local time = trigger.time
    if type(time) ~= "table" then
        time = {}
        trigger.time = time
    end
    time.startTime = now
    time.duration = duration
    time.expirationTime = now + duration
    time.remaining = duration
    time.elapsed = 0
    time.progress = 0
    time.updatedAt = now

    instance.manager._stats.triggerUpdates = instance.manager._stats.triggerUpdates + 1
    instance.triggerUpdateCount = (instance.triggerUpdateCount or 0) + 1
    instance.lastTriggerUpdateAt = now
    if instance.manager:IsLogEnabled() then
        instance.manager:_Log("trigger", instance, {
            triggerId = trigger.id,
            triggerType = trigger.type,
            reason = event,
            spellID = data.spellID,
            active = true,
            changed = trigger.changed == true,
        })
    end
    instance:_CallCondition("onTrigger", trigger, event, ...)
    instance:Refresh(event)
    ScheduleCooldownWindowReset(instance, trigger)
    return true
end

function Instance:_CallCondition(name, ...)
    local conditions = self.definition.conditions
    if type(conditions) ~= "table" then return end
    local callback = conditions[name]
    if type(callback) == "function" then
        SafeCall("Monitor:condition." .. name .. ":" .. self.id, callback, self.context, ...)
    end
end

function Instance:_PrepareContext()
    self.context = self.context or {}
    self.context.id = self.id
    self.context.monitor = self
    self.context.definition = self.definition
    self.context.state = self.state
    self.context.t = self.triggers
    self.context.active = self.active == true
    self.context.loaded = self.loaded == true
    self.context.running = self.running == true
    self.context.progress = self.progress or 0
    self.context.reason = self.reason
    return self.context
end

function Instance:_PrepareTriggers()
    local activation = self.definition.activation or {}
    local source = activation.triggers or self.definition.triggers or {}
    self.triggers = {}
    self.triggerById = {}

    for index, triggerDef in ipairs(source) do
        local trigger = PrepareTrigger(self, index, triggerDef)
        if trigger then
            self.triggers[#self.triggers + 1] = trigger
            if trigger.id then self.triggerById[trigger.id] = trigger end
        end
    end

    local expression = activation.expression or self.definition.expression
    if type(expression) == "function" then
        self.expression = expression
    elseif type(expression) == "string" then
        local compiled, err = CompileExpression(expression)
        self.expression = compiled or DefaultExpression
        self.expressionError = err
    else
        self.expression = DefaultExpression
    end
end

function Instance:_EvaluateCooldownWindowTriggers()
    local now = Now()
    for _, trigger in ipairs(self.triggers) do
        if IsCooldownWindowTrigger(trigger) then
            RefreshCooldownWindowData(trigger, now)
        end
    end
end

function Instance:_EvaluateActivation(reason)
    self:_PrepareContext()
    self:_EvaluateCooldownWindowTriggers()

    local nextActive
    if type(self.expression) == "function" then
        local ok, result = SafeCall("Monitor:expression:" .. self.id, self.expression, self.context, self.triggers, self.state, self)
        nextActive = ok and result == true
    else
        nextActive = DefaultExpression(self.context, self.triggers)
    end

    if self.manager:IsLogEnabled() then
        self.manager:_Log("expression", self, { reason = reason, active = nextActive == true })
    end

    self:_SetActive(nextActive, reason)
    return nextActive
end

function Instance:_SetActive(nextActive, reason)
    nextActive = nextActive == true
    if self.active == nextActive then
        self.context.active = nextActive
        if not nextActive and self.manualVisible ~= true then
            self.visible = false
        end
        return false
    end

    local previous = self.active == true
    self.active = nextActive
    self.visible = nextActive or self.manualVisible == true
    self.reason = reason
    self.context.active = nextActive
    self.context.reason = reason
    self.lastActiveChangedAt = Now()

    if self.manager:IsLogEnabled() then
        self.manager:_Log("active-change", self, {
            reason = reason,
            previous = previous,
            active = nextActive,
        })
    end

    if nextActive then
        self.activatedAt = Now()
        self:_CallCondition("onActivate", reason, previous)
        CallPresenter(self, "show")
        self.manager:_SetTicker(self, self:NeedsTick())
    else
        self.deactivatedAt = Now()
        self:_CallCondition("onDeactivate", reason, previous)
        self.manager:_SetTicker(self, self:NeedsTick())
    end
    self:_CallCondition("onStateChange", nextActive, previous, reason)
    self:UpdatePresenter("active-change")
    return true
end

function Instance:_UpdateAuraTrigger(trigger, reason)
    if not trigger.spellID then return false end
    self.manager._stats.triggerUpdates = self.manager._stats.triggerUpdates + 1
    local aura = GetAuraSnapshot(self, trigger.unit or "player", trigger.spellID)
    local previous = trigger.active == true
    if aura then
        trigger.active = true
        UpdateAuraData(trigger, aura)
    else
        trigger.active = false
        ClearAuraData(trigger)
    end
    trigger.changed = previous ~= trigger.active
    self.triggerUpdateCount = (self.triggerUpdateCount or 0) + 1
    self.lastTriggerUpdateAt = Now()
    if self.manager:IsLogEnabled() then
        self.manager:_Log("trigger", self, {
            triggerId = trigger.id,
            triggerType = trigger.type,
            reason = reason,
            active = trigger.active == true,
            changed = trigger.changed == true,
        })
    end
    if trigger.changed then
        self:_CallCondition("onTrigger", trigger, reason)
    end
    return trigger.changed
end

function Instance:_OnUnitAura(event, unit)
    for _, trigger in ipairs(self.triggers) do
        if (trigger.type == "playerAura" or trigger.type == "unitAura")
            and TriggerMatchesUnit(trigger, unit or trigger.unit or "player") then
            self:Refresh(event)
            return
        end
    end
end

function Instance:_OnSpellcastSucceeded(event, unit, castGUID, spellID)
    for _, trigger in ipairs(self.triggers) do
        if trigger.type == "unitSpellcastSucceeded" and TriggerMatchesUnit(trigger, unit) then
            if trigger.spellID == nil or SafeNumber(spellID) == trigger.spellID then
                local previous = trigger.active == true
                trigger.active = true
                trigger.changed = previous ~= true
                trigger.data.event = event
                trigger.data.unit = NormalizeUnit(unit, trigger.unit)
                trigger.data.castGUID = IsSecretValue(castGUID) and nil or castGUID
                trigger.data.spellID = SafeNumber(spellID) or trigger.spellID
                trigger.data.timestamp = Now()
                trigger.data.count = (trigger.data.count or 0) + 1
                self.manager._stats.triggerUpdates = self.manager._stats.triggerUpdates + 1
                self.triggerUpdateCount = (self.triggerUpdateCount or 0) + 1
                self.lastTriggerUpdateAt = trigger.data.timestamp
                if self.manager:IsLogEnabled() then
                    self.manager:_Log("trigger", self, {
                        triggerId = trigger.id,
                        triggerType = trigger.type,
                        reason = event,
                        unit = trigger.data.unit,
                        spellID = trigger.data.spellID,
                        active = true,
                        changed = trigger.changed == true,
                    })
                end
                self:_CallCondition("onTrigger", trigger, event, unit, castGUID, spellID)
                self:Refresh(event)
                self:_SchedulePulseReset(trigger)
            end
        end
    end
end

function Instance:_OnGenericEvent(event, ...)
    for _, trigger in ipairs(self.triggers) do
        if trigger.type == "event" and EventTriggerMatches(trigger, event, ...) then
            if IsCooldownWindowTrigger(trigger) then
                StartCooldownWindowTrigger(self, trigger, event, ...)
            else
                local previous = trigger.active == true
                local now = Now()
                local data = PopulateEventTriggerData(trigger, event, now, ...)
                trigger.active = true
                trigger.changed = previous ~= true

                self.manager._stats.triggerUpdates = self.manager._stats.triggerUpdates + 1
                self.triggerUpdateCount = (self.triggerUpdateCount or 0) + 1
                self.lastTriggerUpdateAt = now
                if self.manager:IsLogEnabled() then
                    self.manager:_Log("trigger", self, {
                        triggerId = trigger.id,
                        triggerType = trigger.type,
                        reason = event,
                        unit = data.unit,
                        spellID = data.spellID,
                        active = true,
                        changed = trigger.changed == true,
                    })
                end
                self:_CallCondition("onTrigger", trigger, event, ...)
                self:Refresh(event)
                self:_SchedulePulseReset(trigger)
            end
        end
    end
end

function Instance:_OnSpellCooldownWindowEvent(event, spellID, baseSpellID, category, startRecoveryCategory)
    for _, trigger in ipairs(self.triggers) do
        if trigger.type == "spellCooldownWindow" and CooldownWindowMatches(trigger, spellID, baseSpellID) then
            StartCooldownWindowTrigger(self, trigger, event, spellID, baseSpellID, category, startRecoveryCategory)
        end
    end
end

function Instance:_SchedulePulseReset(trigger)
    if trigger.definition.sticky == true then return end
    local delay = SafeNumber(trigger.definition.duration)
    if delay == nil then delay = 0 end
    local token = (trigger.pulseToken or 0) + 1
    trigger.pulseToken = token
    self.manager:_ScheduleDelayedTrigger(self, trigger, "pulse", Now() + delay, token)
end

function Instance:_RegisterTriggerEvents()
    local Event = EventBus()
    if not (Event and Event.On) then return false end
    if Event.OffOwner then Event:OffOwner(self.eventOwner) end

    local needsUnitAura = {}
    local genericEvents = {}
    local genericUnitEvents = {}

    local function ApplySchedule(entry, throttle, debounce, explicit)
        if not explicit then
            entry.unscheduled = true
            entry.hasSchedule = false
            entry.throttle = nil
            entry.debounce = nil
            return
        end
        if entry.unscheduled then return end
        if entry.hasSchedule and (entry.throttle ~= throttle or entry.debounce ~= debounce) then
            entry.unscheduled = true
            entry.hasSchedule = false
            entry.throttle = nil
            entry.debounce = nil
            return
        end
        entry.hasSchedule = true
        entry.throttle = throttle
        entry.debounce = debounce
    end

    local function ApplyTriggerSchedule(entry, trigger)
        local throttle = trigger and trigger.throttle
        local debounce = trigger and trigger.debounce
        ApplySchedule(entry, throttle, debounce, throttle ~= nil or debounce ~= nil)
    end

    local function ApplyScheduleEntry(target, source)
        if not source or source.unscheduled or not source.hasSchedule then
            ApplySchedule(target, nil, nil, false)
            return
        end
        ApplySchedule(target, source.throttle, source.debounce, true)
    end

    local function EnsureEventEntry(container, eventName)
        local entry = container[eventName]
        if not entry then
            entry = {}
            container[eventName] = entry
        end
        return entry
    end

    local function ListenerOptions(entry, unit)
        local options = { moduleId = self.moduleId }
        if unit then options.unit = unit end
        if entry and entry.hasSchedule and not entry.unscheduled then
            if entry.throttle then options.throttle = entry.throttle end
            if entry.debounce then options.debounce = entry.debounce end
        end
        return options
    end

    local function AddGenericEventEntry(eventName, trigger)
        local entry = EnsureEventEntry(genericEvents, eventName)
        ApplyTriggerSchedule(entry, trigger)

        local unitEntries = genericUnitEvents[eventName]
        if unitEntries then
            for _, unitEntry in pairs(unitEntries) do
                ApplyScheduleEntry(entry, unitEntry)
            end
            genericUnitEvents[eventName] = nil
        end
    end

    local function AddGenericUnitEvent(eventName, unit, trigger)
        if not eventName then return end
        unit = NormalizeUnit(unit, "")
        if unit == "" then
            AddGenericEventEntry(eventName, trigger)
            genericUnitEvents[eventName] = nil
            return
        end
        if genericEvents[eventName] then
            ApplyTriggerSchedule(genericEvents[eventName], trigger)
            return
        end
        genericUnitEvents[eventName] = genericUnitEvents[eventName] or {}
        local entry = genericUnitEvents[eventName][unit]
        if not entry then
            entry = {}
            genericUnitEvents[eventName][unit] = entry
        end
        ApplyTriggerSchedule(entry, trigger)
    end
    local function AddGenericEvent(eventName, trigger)
        if not eventName then return end
        if string_sub(eventName, 1, 5) == "UNIT_" and trigger.unit then
            if trigger.unit then
                AddGenericUnitEvent(eventName, trigger.unit, trigger)
            end
        else
            AddGenericEventEntry(eventName, trigger)
        end
    end

    for _, trigger in ipairs(self.triggers) do
        if trigger.type == "playerAura" or trigger.type == "unitAura" then
            needsUnitAura[trigger.unit or "player"] = true
        elseif trigger.type == "event" then
            if trigger.event then AddGenericEvent(trigger.event, trigger) end
        end
    end

    for unit in pairs(needsUnitAura) do
        Event:On("UNIT_AURA", "_OnUnitAura", self, {
            unit = unit,
            moduleId = self.moduleId,
            throttle = self.policy.eventThrottle,
        })
    end
    for eventName, entry in pairs(genericEvents) do
        Event:On(eventName, "_OnGenericEvent", self, ListenerOptions(entry))
    end
    for eventName, units in pairs(genericUnitEvents) do
        if not genericEvents[eventName] then
            for unit, entry in pairs(units) do
                Event:On(eventName, "_OnGenericEvent", self, ListenerOptions(entry, unit))
            end
        end
    end
    return true
end

function Instance:_UnregisterTriggerEvents()
    local Event = EventBus()
    if Event and Event.OffOwner then
        Event:OffOwner(self)
    end
end

function Instance:_RefreshAuraTriggers(reason)
    for _, trigger in ipairs(self.triggers) do
        if trigger.type == "playerAura" or trigger.type == "unitAura" then
            self:_UpdateAuraTrigger(trigger, reason)
        end
    end
end

function Instance:_ShouldRefreshTriggers(reason)
    if reason ~= "tick" then return true end
    local update = self.definition.update
    return type(update) == "table" and update.refreshTriggersOnTick == true
end

function Instance:NeedsTick()
    if not self.running then return false end
    local update = self.definition.update
    if type(update) ~= "table" then
        return self.active == true and self.hasActiveUpdater == true
    end
    if update.always == true then return true end
    if update.whileVisible == true and self.visible == true then return true end
    return self.active == true and update.activeOnly ~= false
end

function Instance:Refresh(reason)
    if not self.running then return false end
    self.manager:_BeginRefresh()
    self.manager._stats.refreshes = self.manager._stats.refreshes + 1
    self.refreshCount = (self.refreshCount or 0) + 1
    self.lastRefreshReason = reason
    self.lastRefreshAt = Now()
    if self.manager:IsLogEnabled() then
        self.manager:_Log("refresh", self, { reason = reason })
    end
    self:_PrepareContext()
    if self:_ShouldRefreshTriggers(reason) then
        self:_RefreshAuraTriggers(reason)
    end
    self:_EvaluateActivation(reason)
    EvaluateConditionRules(self, reason)
    self:UpdatePresenter(reason)
    self.manager:_EndRefresh()
    return true
end

function Instance:UpdatePresenter(reason)
    if not self.running and not self.visible then return false end
    self.context.reason = reason
    self:_CallCondition("onUpdate", reason)
    CallPresenter(self, "update")
    self.manager._stats.presenterUpdates = self.manager._stats.presenterUpdates + 1
    self.presenterUpdateCount = (self.presenterUpdateCount or 0) + 1
    self.lastPresenterUpdateReason = reason
    self.lastPresenterUpdateAt = Now()
    return true
end

function Instance:Tick(elapsed)
    if not self.running then return end
    self.elapsedSinceUpdate = (self.elapsedSinceUpdate or 0) + (elapsed or 0)
    local interval = SafeNumber(self.definition.update and self.definition.update.interval) or self.policy.defaultUpdateInterval or DEFAULT_UPDATE_INTERVAL
    if interval > 0 and self.elapsedSinceUpdate < interval then return end
    self.elapsedSinceUpdate = 0
    self.context.elapsed = elapsed
    self.tickCount = (self.tickCount or 0) + 1
    self.lastTickAt = Now()
    if self.manager:IsLogEnabled() then
        self.manager:_Log("tick", self, { elapsed = elapsed, interval = interval })
    end
    self:Refresh("tick")
    self.manager:_SetTicker(self, self:NeedsTick())
end

function Instance:IsLoaded()
    return MatchesLoad(self.definition.load or self.definition.loadConditions, self)
end

function Instance:IsRunning()
    return self.running == true
end

function Instance:SetEnabled(enabled)
    self.requestedEnabled = enabled == true
    if self.manager:IsLogEnabled() then
        self.manager:_Log("set-enabled", self, { enabled = self.requestedEnabled })
    end
    self:RefreshLoad("set-enabled")
    return self.running == true
end

function Instance:RefreshLoad(reason)
    local shouldRun = self.requestedEnabled == true and self:IsLoaded()
    self.loaded = shouldRun
    self.lastLoadReason = reason
    self.lastLoadAt = Now()
    if self.manager:IsLogEnabled() then
        self.manager:_Log("load", self, { reason = reason, shouldRun = shouldRun })
    end
    self:_PrepareContext()
    if shouldRun and not self.running then
        self.running = true
        self.visible = false
        self.manualVisible = false
        self.manager:_CancelConditionJobs(self)
        self.conditionRuleState = nil
        ResetTriggerRuntimeState(self)
        self:_CallCondition("onEnable", reason)
        CallPresenter(self, "ensure")
        CallPresenter(self, "apply")
        self:_RegisterTriggerEvents()
        self:Refresh(reason)
    elseif not shouldRun and self.running then
        self:_SetActive(false, reason)
        self.running = false
        self.active = false
        self.visible = false
        self.manualVisible = false
        self.manager:_CancelConditionJobs(self)
        self.conditionRuleState = nil
        ResetTriggerRuntimeState(self)
        self.manager:_SetTicker(self, false)
        self:_UnregisterTriggerEvents()
        self:_CallCondition("onDisable", reason)
        CallPresenter(self, "hide")
    elseif shouldRun then
        CallPresenter(self, "apply")
        self:Refresh(reason)
    end
    return self.running == true
end

function Instance:ApplyAppearance()
    CallPresenter(self, "apply")
    self:UpdatePresenter("appearance")
end

function Instance:Hide()
    self.manualVisible = false
    self.visible = false
    CallPresenter(self, "hide")
    self.manager:_SetTicker(self, self:NeedsTick())
end

function Instance:Show()
    self.manualVisible = true
    self.visible = true
    CallPresenter(self, "show")
    self.manager:_SetTicker(self, self:NeedsTick())
end

function Instance:GetTrigger(indexOrId)
    if type(indexOrId) == "number" then
        return self.triggers[indexOrId]
    end
    return self.triggerById[indexOrId]
end

function Instance:GetTriggerData(indexOrId)
    local trigger = self:GetTrigger(indexOrId)
    return trigger and trigger.data or nil
end

function Instance:Destroy()
    self.requestedEnabled = false
    if self.manager:IsLogEnabled() then
        self.manager:_Log("destroy", self, {})
    end
    if self.running then
        self:_SetActive(false, "destroy")
    end
    self.running = false
    self.active = false
    self.visible = false
    self.manualVisible = false
    self.manager:_CancelConditionJobs(self)
    self.conditionRuleState = nil
    ResetTriggerRuntimeState(self)
    self.manager:_SetTicker(self, false)
    self:_UnregisterTriggerEvents()
    self:_CallCondition("onDestroy")
    CallPresenter(self, "destroy")
end

function Monitor:_CreateInstance(definition)
    local instance = setmetatable({}, Instance)
    instance.manager = self
    instance.definition = definition
    instance.id = definition.id
    instance.moduleId = definition.moduleId or DEFAULT_MODULE_ID
    instance.policy = definition.policy or self.Policy
    instance.owner = definition.owner or instance
    instance.eventOwner = instance
    instance.state = definition.state or {}
    instance.active = false
    instance.loaded = false
    instance.running = false
    instance.visible = false
    instance.manualVisible = false
    instance.dev = definition.dev == true
    instance.hasActiveUpdater = type(definition.update) == "table"
    instance.refreshCount = 0
    instance.triggerUpdateCount = 0
    instance.presenterUpdateCount = 0
    instance.tickCount = 0
    instance:_PrepareTriggers()
    instance:_PrepareContext()
    return instance
end

function Monitor:Register(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string" or definition.id == "" then
        return nil
    end
    local id = definition.id
    if self.instances[id] then
        self:Unregister(id)
    end
    local instance = self:_CreateInstance(definition)
    self.instances[id] = instance
    table_insert(self.order, id)
    self:_EnsureRuntimeEvents()
    if self:IsLogEnabled() then
        self:_Log("register", instance, { enabled = definition.enabled == true })
    end
    if definition.enabled == true then
        instance:SetEnabled(true)
    end
    return instance
end

function Monitor:Get(id)
    return self.instances[id]
end

function Monitor:Unregister(id)
    local instance = type(id) == "table" and id or self.instances[id]
    if not instance then return false end
    if self:IsLogEnabled() then
        self:_Log("unregister", instance, {})
    end
    instance:Destroy()
    self.instances[instance.id] = nil
    RemoveOrder(self.order, instance.id)
    return true
end

function Monitor:SetEnabled(id, enabled)
    local instance = self:Get(id)
    if not instance then return false end
    return instance:SetEnabled(enabled)
end

function Monitor:GetTriggerData(id, indexOrId)
    local instance = self:Get(id)
    return instance and instance:GetTriggerData(indexOrId) or nil
end

function Monitor:GetDebugState(id)
    local instance = self:Get(id)
    if not instance then
        return nil
    end

    local triggers = {}
    for index, trigger in ipairs(instance.triggers or {}) do
        triggers[index] = {
            id = trigger.id,
            type = trigger.type,
            active = trigger.active == true,
            changed = trigger.changed == true,
            activation = trigger.activation ~= false,
            unit = trigger.unit,
            event = trigger.event,
            spellID = trigger.spellID,
            duration = trigger.duration,
            icon = trigger.icon,
            data = trigger.data,
            time = trigger.time,
        }
    end

    local loadDiagnostic = GetLoadDiagnostic(instance)
    local activation = instance.definition.activation or {}
    local expression = activation.expression or instance.definition.expression

    return {
        id = instance.id,
        moduleId = instance.moduleId,
        dev = instance.dev == true,
        requestedEnabled = instance.requestedEnabled == true,
        loaded = instance.loaded == true,
        running = instance.running == true,
        active = instance.active == true,
        visible = instance.visible == true,
        expressionError = instance.expressionError,
        expressionSource = type(expression) == "string" and expression or nil,
        expressionKind = type(expression),
        conditionRuleCount = type(instance.definition.conditionRules) == "table" and #instance.definition.conditionRules or 0,
        conditionRuleMatchCount = instance.conditionRuleMatchCount or 0,
        reason = instance.reason,
        loadDiagnostic = loadDiagnostic,
        loadSummary = loadDiagnostic.summary,
        lastRefreshReason = instance.lastRefreshReason,
        lastRefreshAt = instance.lastRefreshAt,
        lastLoadReason = instance.lastLoadReason,
        lastLoadAt = instance.lastLoadAt,
        lastActiveChangedAt = instance.lastActiveChangedAt,
        lastTriggerUpdateAt = instance.lastTriggerUpdateAt,
        lastPresenterUpdateReason = instance.lastPresenterUpdateReason,
        lastPresenterUpdateAt = instance.lastPresenterUpdateAt,
        lastTickAt = instance.lastTickAt,
        refreshCount = instance.refreshCount or 0,
        triggerUpdateCount = instance.triggerUpdateCount or 0,
        presenterUpdateCount = instance.presenterUpdateCount or 0,
        tickCount = instance.tickCount or 0,
        hasTicker = self._activeTickers[instance] == true,
        activeTickers = self._activeTickerCount,
        triggers = triggers,
    }
end

function Monitor:Dump(id)
    local state = self:GetDebugState(id)
    local Print = (YUI and YUI.Print) and function(message) YUI:Print(message) end or print
    if not state then
        Print("YUI.Monitor: missing " .. tostring(id))
        return false
    end

    Print(string.format(
        "YUI.Monitor[%s] enabled=%s loaded=%s running=%s active=%s visible=%s reason=%s",
        tostring(state.id),
        tostring(state.requestedEnabled),
        tostring(state.loaded),
        tostring(state.running),
        tostring(state.active),
        tostring(state.visible),
        tostring(state.reason)
    ))
    if state.expressionError then
        Print("  expressionError=" .. tostring(state.expressionError))
    end
    for index, trigger in ipairs(state.triggers) do
        Print(string.format(
            "  t[%d] %s type=%s active=%s changed=%s spellID=%s unit=%s",
            index,
            tostring(trigger.id),
            tostring(trigger.type),
            tostring(trigger.active),
            tostring(trigger.changed),
            tostring(trigger.spellID),
            tostring(trigger.unit)
        ))
    end
    return true
end

function Monitor:List()
    local ids = {}
    for id in pairs(self.instances or {}) do
        ids[#ids + 1] = id
    end
    table_sort(ids)
    return ids
end

function Monitor:ListDetailed()
    local rows = {}
    for _, id in ipairs(self.order or {}) do
        local instance = self.instances[id]
        if instance then
            local loadDiagnostic = GetLoadDiagnostic(instance)
            local triggers = {}
            for index, trigger in ipairs(instance.triggers or {}) do
                triggers[index] = GetTriggerSummary(trigger)
            end
            rows[#rows + 1] = {
                id = instance.id,
                name = instance.definition.name or instance.definition.displayName or instance.id,
                displayName = instance.definition.displayName or instance.definition.name or instance.id,
                moduleId = instance.moduleId,
                dev = instance.dev == true,
                editable = instance.dev == true,
                locked = instance.dev ~= true,
                requestedEnabled = instance.requestedEnabled == true,
                loaded = instance.loaded == true,
                running = instance.running == true,
                active = instance.active == true,
                visible = instance.visible == true,
                hasTicker = self._activeTickers[instance] == true,
                loadSummary = loadDiagnostic.summary,
                loadDiagnostic = loadDiagnostic,
                lastRefreshReason = instance.lastRefreshReason,
                lastRefreshAt = instance.lastRefreshAt,
                refreshCount = instance.refreshCount or 0,
                triggerUpdateCount = instance.triggerUpdateCount or 0,
                presenterUpdateCount = instance.presenterUpdateCount or 0,
                conditionRuleCount = type(instance.definition.conditionRules) == "table" and #instance.definition.conditionRules or 0,
                conditionRuleMatchCount = instance.conditionRuleMatchCount or 0,
                tickCount = instance.tickCount or 0,
                triggers = triggers,
            }
        end
    end
    return rows
end

function Monitor:RegisterTriggerSchema(triggerType, schema)
    if type(triggerType) ~= "string" or triggerType == "" or type(schema) ~= "table" then
        return false
    end
    self._triggerSchemas[triggerType] = CopyTable(schema)
    return true
end

function Monitor:GetTriggerSchema(triggerType)
    EnsureDefaultTriggerSchemas()
    local schema = self._triggerSchemas and self._triggerSchemas[triggerType]
    return schema and CopyTable(schema) or nil
end

function Monitor:ListTriggerSchemas(includeFuture)
    EnsureDefaultTriggerSchemas()
    local rows = {}
    for triggerType, schema in pairs(self._triggerSchemas or {}) do
        if schema.hidden ~= true and (includeFuture == true or schema.future ~= true) then
            rows[#rows + 1] = {
                type = triggerType,
                label = schema.label or triggerType,
                future = schema.future == true,
                fields = schema.fields,
                example = schema.example,
            }
        end
    end
    table_sort(rows, function(a, b) return tostring(a.type) < tostring(b.type) end)
    return rows
end

function Monitor:IsLogEnabled()
    local log = self._devLog
    return log and log.enabled == true
end

function Monitor:SetLogEnabled(enabled)
    self._devLog.enabled = enabled == true
    return self._devLog.enabled
end

function Monitor:ClearLog()
    local log = self._devLog
    log.rows = {}
    log.cursor = 0
    log.count = 0
    log.serial = 0
    return true
end

function Monitor:SetLogLimit(limit)
    limit = SafeNumber(limit) or self._devLog.limit or 240
    if limit < 40 then limit = 40 end
    if limit > 1000 then limit = 1000 end
    self._devLog.limit = limit
    self:ClearLog()
    return limit
end

function Monitor:_Log(eventType, instance, details)
    local log = self._devLog
    if not (log and log.enabled == true) then return false end
    local limit = log.limit or 240
    local monitorId, moduleId = NormalizeLogInstance(instance)
    log.serial = (log.serial or 0) + 1
    log.cursor = ((log.cursor or 0) % limit) + 1
    if (log.count or 0) < limit then
        log.count = (log.count or 0) + 1
    end
    log.rows[log.cursor] = {
        serial = log.serial,
        time = Now(),
        eventType = eventType,
        monitorId = monitorId,
        moduleId = moduleId,
        details = details,
    }
    return true
end

function Monitor:GetLog(filter)
    local log = self._devLog
    local rows = {}
    if not log then return rows end
    local count = log.count or 0
    local limit = log.limit or 240
    local start = (log.cursor or 0) - count + 1
    while start <= 0 do start = start + limit end
    for index = 0, count - 1 do
        local pos = ((start + index - 1) % limit) + 1
        local row = log.rows[pos]
        if row then
            local include = true
            if type(filter) == "table" then
                if filter.monitorId and row.monitorId ~= filter.monitorId then include = false end
                if filter.eventType and row.eventType ~= filter.eventType then include = false end
            end
            if include then rows[#rows + 1] = row end
        end
    end
    return rows
end

function Monitor:RegisterDevDefinition(definition)
    if type(definition) ~= "table" then return nil, "invalid definition" end
    local copy = CopyTable(definition)
    local rawId = tostring(copy.id or "test")
    if not StartsWith(rawId, "dev.monitor.") then
        rawId = "dev.monitor." .. rawId
    end
    copy.id = rawId
    copy.moduleId = copy.moduleId or "dev.monitor"
    copy.owner = copy.owner or self._devOwner
    copy.dev = true
    if type(copy.activation) ~= "table" then copy.activation = {} end
    if type(copy.activation.triggers) ~= "table" and type(copy.triggers) == "table" then
        copy.activation.triggers = copy.triggers
    end
    if type(copy.activation.triggers) ~= "table" then
        copy.activation.triggers = {}
    end
    for index, trigger in ipairs(copy.activation.triggers) do
        copy.activation.triggers[index] = NormalizeDevTrigger(trigger)
    end
    if type(copy.appearance) ~= "table" then
        copy.appearance = {
            type = "icon",
            width = 64,
            height = 64,
            point = { point = "CENTER", y = -160 },
        }
    end
    copy.enabled = copy.enabled == true
    return self:Register(copy)
end

function Monitor:InjectTrigger(id, indexOrId, opts)
    local instance = self:Get(id)
    if not instance or instance.dev ~= true then return false, "dev monitor not found" end
    local trigger = instance:GetTrigger(indexOrId)
    if not trigger then return false, "trigger not found" end
    opts = type(opts) == "table" and opts or {}
    if opts.active ~= nil then
        trigger.active = opts.active == true
    else
        trigger.active = true
    end
    trigger.changed = true
    trigger.data.timestamp = Now()
    trigger.data.injected = true
    if type(opts.data) == "table" then
        for key, value in pairs(opts.data) do
            trigger.data[key] = value
        end
    end
    self._stats.triggerUpdates = self._stats.triggerUpdates + 1
    instance.triggerUpdateCount = (instance.triggerUpdateCount or 0) + 1
    instance.lastTriggerUpdateAt = trigger.data.timestamp
    if self:IsLogEnabled() then
        self:_Log("trigger-inject", instance, {
            triggerId = trigger.id,
            triggerType = trigger.type,
            active = trigger.active == true,
        })
    end
    instance:_EvaluateActivation("dev-inject")
    EvaluateConditionRules(instance, "dev-inject")
    instance:UpdatePresenter("dev-inject")
    return true
end

function Monitor:SetPolicy(policy)
    if type(policy) ~= "table" then return false end
    for key, value in pairs(policy) do
        self.Policy[key] = value
    end
    return true
end

function Monitor:GetPolicy()
    return self.Policy
end

function Monitor:Refresh(id, reason)
    if id ~= nil then
        local instance = self:Get(id)
        return instance and instance:Refresh(reason or "manual")
    end
    for _, instanceId in ipairs(self.order) do
        local instance = self.instances[instanceId]
        if instance and instance.running then
            instance:Refresh(reason or "manual")
        end
    end
    return true
end

function Monitor:RefreshLoad(reason)
    for _, id in ipairs(self.order) do
        local instance = self.instances[id]
        if instance then
            instance:RefreshLoad(reason or "load")
        end
    end
end

function Monitor:RequestRefreshLoad(reason)
    self._stats.contextRefreshRequests =
        self._stats.contextRefreshRequests + 1
    self._contextRefreshReason = self._contextRefreshReason
        or reason or "context-coalesced"
    if self._contextRefreshTimer then
        self._stats.contextRefreshCoalesced =
            self._stats.contextRefreshCoalesced + 1
        if self._contextRefreshTimer.Cancel then
            self._contextRefreshTimer:Cancel()
        end
        self._contextRefreshTimer = nil
    end
    if C_Timer and C_Timer.NewTimer then
        self._contextRefreshTimer = C_Timer.NewTimer(
            CONTEXT_LOAD_DELAY,
            MonitorContextRefreshTimerCallback
        )
        return true
    end
    MonitorContextRefreshTimerCallback()
    return true
end

function Monitor:_BeginRefresh()
    self._auraCacheSerial = (self._auraCacheSerial or 0) + 1
end

function Monitor:_EndRefresh()
end

function Monitor:_SetTicker(instance, enabled)
    if not instance then return end
    if enabled then
        if not self._activeTickers[instance] then
            self._activeTickers[instance] = true
            self._activeTickerCount = self._activeTickerCount + 1
        end
        self:_StartDriver()
    elseif self._activeTickers[instance] then
        self._activeTickers[instance] = nil
        self._activeTickerCount = self._activeTickerCount - 1
    end
    self:_StopDriver()
end

function Monitor:_EnsureTickerFrame()
    if self._tickerFrame or not CreateFrame then return end
    local frame = CreateFrame("Frame")
    frame:Hide()
    self._tickerFrame = frame
end

function Monitor:_NeedsDriver()
    if self._activeTickerCount > 0 then return true end
    if self._wakeUsesDriver and self._nextWakeAt then return true end
    local Data = self.Data
    return Data and Data._NeedsDriver and Data:_NeedsDriver() == true
end

function Monitor:_StartDriver()
    self:_EnsureTickerFrame()
    local frame = self._tickerFrame
    if not frame then return false end
    if not self._driverRunning then
        frame:SetScript("OnUpdate", MonitorOnUpdate)
        self._driverRunning = true
    end
    frame:Show()
    return true
end

function Monitor:_StopDriver()
    if self:_NeedsDriver() then return false end
    local frame = self._tickerFrame
    if frame and self._driverRunning then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
    self._driverRunning = false
    return true
end

function Monitor:_OnUpdate(elapsed)
    for instance in pairs(self._activeTickers) do
        if instance and instance.running then
            instance:Tick(elapsed)
        else
            self:_SetTicker(instance, false)
        end
    end

    local Data = self.Data
    if Data and Data._OnUpdate then
        Data:_OnUpdate(elapsed, Now())
    end

    if self._wakeUsesDriver and self._nextWakeAt and Now() + 0.0001 >= self._nextWakeAt then
        self:_RunScheduledWork(Now())
    end
    self:_StopDriver()
end

function Monitor:_ScheduleDelayedTrigger(instance, trigger, kind, dueAt, token)
    local scheduler = self._delayedScheduler
    dueAt = SafeNumber(dueAt)
    if not (scheduler and instance and trigger and dueAt) then return false end
    if kind ~= "cooldown" and kind ~= "pulse" then return false end

    local job = scheduler.jobs[trigger]
    if not job then
        job = {
            instance = instance,
            trigger = trigger,
        }
        scheduler.jobs[trigger] = job
        scheduler.byInstance[instance] = scheduler.byInstance[instance] or {}
        scheduler.byInstance[instance][trigger] = true
    end

    local dueKey = kind .. "DueAt"
    local tokenKey = kind .. "Token"
    if job[dueKey] == nil then
        scheduler.pending = scheduler.pending + 1
    end
    job[dueKey] = dueAt
    job[tokenKey] = token
    scheduler.scheduled = scheduler.scheduled + 1
    self:_RearmDelayedScheduler()
    return true
end

function Monitor:_RemoveDelayedJob(trigger, job)
    local scheduler = self._delayedScheduler
    job = job or (scheduler and scheduler.jobs[trigger])
    if not (scheduler and trigger and job) then return false end
    if job.cooldownDueAt ~= nil then scheduler.pending = math_max(0, scheduler.pending - 1) end
    if job.pulseDueAt ~= nil then scheduler.pending = math_max(0, scheduler.pending - 1) end
    scheduler.jobs[trigger] = nil
    local rows = scheduler.byInstance[job.instance]
    if rows then
        rows[trigger] = nil
        if not next(rows) then scheduler.byInstance[job.instance] = nil end
    end
    return true
end

function Monitor:_CancelDelayedJobs(instance)
    local scheduler = self._delayedScheduler
    local rows = scheduler and scheduler.byInstance[instance]
    if not rows then return false end
    for trigger in pairs(rows) do
        if self:_RemoveDelayedJob(trigger) then
            scheduler.canceled = scheduler.canceled + 1
        end
    end
    scheduler.byInstance[instance] = nil
    self:_RearmDelayedScheduler()
    return true
end

function Monitor:_RearmDelayedScheduler()
    local scheduler = self._delayedScheduler
    if not scheduler then return false end
    local nextDueAt
    for trigger, job in pairs(scheduler.jobs) do
        if not (job and job.instance and job.instance.running and job.trigger == trigger) then
            self:_RemoveDelayedJob(trigger, job)
        else
            local cooldownDueAt = job.cooldownDueAt
            local pulseDueAt = job.pulseDueAt
            if cooldownDueAt and (not nextDueAt or cooldownDueAt < nextDueAt) then
                nextDueAt = cooldownDueAt
            end
            if pulseDueAt and (not nextDueAt or pulseDueAt < nextDueAt) then
                nextDueAt = pulseDueAt
            end
        end
    end
    scheduler.nextDueAt = nextDueAt
    self:_RearmWakeTimer()
    return nextDueAt ~= nil
end

function Monitor:_RunDelayedScheduler(now)
    local scheduler = self._delayedScheduler
    if not scheduler then return false end
    local fired = false
    for trigger, job in pairs(scheduler.jobs) do
        local instance = job and job.instance
        if not (instance and instance.running and job.trigger == trigger) then
            self:_RemoveDelayedJob(trigger, job)
        else
            if job.cooldownDueAt and now + 0.0001 >= job.cooldownDueAt then
                local token = job.cooldownToken
                job.cooldownDueAt = nil
                job.cooldownToken = nil
                scheduler.pending = math_max(0, scheduler.pending - 1)
                if trigger.windowToken == token and RefreshCooldownWindowData(trigger, now) then
                    instance:Refresh("cooldown-window-expired")
                end
                scheduler.fired = scheduler.fired + 1
                fired = true
            end
            if job.pulseDueAt and now + 0.0001 >= job.pulseDueAt then
                local token = job.pulseToken
                job.pulseDueAt = nil
                job.pulseToken = nil
                scheduler.pending = math_max(0, scheduler.pending - 1)
                if trigger.pulseToken == token then
                    trigger.active = false
                    trigger.changed = true
                    instance:Refresh("pulse-reset")
                end
                scheduler.fired = scheduler.fired + 1
                fired = true
            end
            if job.cooldownDueAt == nil and job.pulseDueAt == nil then
                self:_RemoveDelayedJob(trigger, job)
            end
        end
    end
    self:_RearmDelayedScheduler()
    return fired
end

local function RemoveConditionSchedulerJob(scheduler, key, job)
    if not (scheduler and key) then return false end
    job = job or scheduler.jobs[key]
    if not job then return false end
    scheduler.jobs[key] = nil
    if job.instance and scheduler.byInstance[job.instance] then
        scheduler.byInstance[job.instance][key] = nil
        if next(scheduler.byInstance[job.instance]) == nil then
            scheduler.byInstance[job.instance] = nil
        end
    end
    scheduler.canceled = (scheduler.canceled or 0) + 1
    return true
end

function Monitor:_CancelConditionJob(instance, rule, index, skipRearm)
    local scheduler = self._conditionScheduler
    if not (scheduler and instance and rule) then return false end
    local key = GetConditionRuleJobKey(instance, rule, index)
    local removed = RemoveConditionSchedulerJob(scheduler, key)
    if removed and skipRearm ~= true then
        self:_RearmConditionScheduler()
    end
    return removed
end

function Monitor:_CancelConditionJobs(instance)
    local scheduler = self._conditionScheduler
    if not (scheduler and instance) then return false end
    local rows = scheduler.byInstance[instance]
    if type(rows) ~= "table" then return false end
    for key in pairs(rows) do
        RemoveConditionSchedulerJob(scheduler, key)
    end
    scheduler.byInstance[instance] = nil
    self:_RearmConditionScheduler()
    return true
end

function Monitor:_ScheduleConditionCheck(instance, rule, index, dueAt, reason)
    local scheduler = self._conditionScheduler
    dueAt = SafeNumber(dueAt)
    if not (scheduler and instance and instance.running and rule and dueAt) then return false end
    local key = GetConditionRuleJobKey(instance, rule, index)
    local job = scheduler.jobs[key]
    local previousDueAt = job and job.dueAt
    if not job then
        scheduler.sequence = (scheduler.sequence or 0) + 1
        job = {
            key = key,
            instance = instance,
            rule = rule,
            index = index,
            sequence = scheduler.sequence,
        }
        scheduler.jobs[key] = job
        scheduler.byInstance[instance] = scheduler.byInstance[instance] or {}
        scheduler.byInstance[instance][key] = true
    end
    job.dueAt = dueAt
    job.reason = reason
    if previousDueAt and math.abs(previousDueAt - dueAt) < 0.001 and scheduler.nextDueAt ~= nil then
        return true
    end
    scheduler.scheduled = (scheduler.scheduled or 0) + 1
    self:_RearmConditionScheduler()
    return true
end

function Monitor:_RearmConditionScheduler()
    local scheduler = self._conditionScheduler
    if not scheduler then return false end

    local nextKey
    local nextDueAt
    local pending = 0
    for key, job in pairs(scheduler.jobs) do
        if not (job and job.instance and job.instance.running and type(job.rule) == "table" and job.rule.enabled ~= false) then
            RemoveConditionSchedulerJob(scheduler, key, job)
        else
            pending = pending + 1
            if not nextDueAt or job.dueAt < nextDueAt or (job.dueAt == nextDueAt and job.sequence < (scheduler.jobs[nextKey] and scheduler.jobs[nextKey].sequence or math.huge)) then
                nextKey = key
                nextDueAt = job.dueAt
            end
        end
    end
    scheduler.pending = pending

    scheduler.token = (scheduler.token or 0) + 1
    scheduler.nextDueAt = nextDueAt
    self:_RearmWakeTimer()
    return nextDueAt ~= nil
end

function Monitor:_RunConditionScheduler(token)
    local scheduler = self._conditionScheduler
    if not scheduler or token ~= scheduler.token then return false end
    scheduler.nextDueAt = nil

    local now = Now()
    local due = {}
    local pending = 0
    for key, job in pairs(scheduler.jobs) do
        if not (job and job.instance and job.instance.running and type(job.rule) == "table" and job.rule.enabled ~= false) then
            RemoveConditionSchedulerJob(scheduler, key, job)
        elseif now + 0.0001 < job.dueAt then
            pending = pending + 1
            scheduler.requeued = (scheduler.requeued or 0) + 1
        else
            due[#due + 1] = job
            RemoveConditionSchedulerJob(scheduler, key, job)
        end
    end
    scheduler.pending = pending

    for _, job in ipairs(due) do
        local instance = job.instance
        if instance and instance.running then
            scheduler.fired = (scheduler.fired or 0) + 1
            EvaluateConditionRules(instance, "condition-timer")
            instance:UpdatePresenter("condition-timer")
        end
    end

    self:_RearmConditionScheduler()
    return #due > 0
end

function Monitor:_GetNextWakeAt()
    local conditionDueAt = self._conditionScheduler and self._conditionScheduler.nextDueAt
    local delayedDueAt = self._delayedScheduler and self._delayedScheduler.nextDueAt
    if conditionDueAt and delayedDueAt then
        return math_min(conditionDueAt, delayedDueAt)
    end
    return conditionDueAt or delayedDueAt
end

function Monitor:_RearmWakeTimer()
    local nextWakeAt = self:_GetNextWakeAt()
    self._nextWakeAt = nextWakeAt

    local oldTimer = self._wakeTimer
    if oldTimer and oldTimer.Cancel then
        pcall(oldTimer.Cancel, oldTimer)
    end
    self._wakeTimer = nil
    self._wakeUsesDriver = false

    if not nextWakeAt then
        self:_StopDriver()
        return false
    end

    if C_Timer and C_Timer.NewTimer then
        local delay = nextWakeAt - Now()
        if delay < 0 then delay = 0 end
        self._wakeTimer = C_Timer.NewTimer(delay, MonitorWakeTimerCallback)
        self:_StopDriver()
        return true
    end

    self._wakeUsesDriver = true
    self:_StartDriver()
    return true
end

function Monitor:_RunScheduledWork(now)
    now = now or Now()
    local delayed = self._delayedScheduler
    if delayed and delayed.nextDueAt and now + 0.0001 >= delayed.nextDueAt then
        self:_RunDelayedScheduler(now)
    end
    local scheduler = self._conditionScheduler
    if scheduler and scheduler.nextDueAt and now + 0.0001 >= scheduler.nextDueAt then
        self:_RunConditionScheduler(scheduler.token)
    end
    self:_RearmWakeTimer()
end

function Monitor:_EnsureRuntimeEvents()
    if self._eventsRegistered then return end
    local Event = EventBus()
    if not (Event and Event.On) then return end
    self._eventsRegistered = true
    for _, eventName in ipairs(LOAD_EVENTS) do
        Event:On(eventName, MonitorRuntimeEventHandler, self._owner, { moduleId = DEFAULT_MODULE_ID, throttle = self.Policy.eventThrottle })
    end
end

function Monitor:GetStats()
    EnsureDefaultTriggerSchemas()
    local schemaCount = 0
    for _ in pairs(self._triggerSchemas or {}) do
        schemaCount = schemaCount + 1
    end
    local scheduler = self._conditionScheduler or {}
    local delayed = self._delayedScheduler or {}
    local conditionJobs = 0
    for _ in pairs(scheduler.jobs or {}) do
        conditionJobs = conditionJobs + 1
    end
    return {
        instances = #self.order,
        activeTickers = self._activeTickerCount,
        refreshes = self._stats.refreshes,
        triggerUpdates = self._stats.triggerUpdates,
        presenterUpdates = self._stats.presenterUpdates,
        contextRefreshRequests = self._stats.contextRefreshRequests,
        contextRefreshCoalesced = self._stats.contextRefreshCoalesced,
        contextRefreshExecutions = self._stats.contextRefreshExecutions,
        conditionJobs = conditionJobs,
        conditionTimerArmed = scheduler.nextDueAt ~= nil,
        conditionScheduled = scheduler.scheduled or 0,
        conditionFired = scheduler.fired or 0,
        conditionRequeued = scheduler.requeued or 0,
        delayedJobs = delayed.pending or 0,
        delayedScheduled = delayed.scheduled or 0,
        delayedFired = delayed.fired or 0,
        driverRunning = self._driverRunning == true,
        wakeTimerArmed = self._wakeTimer ~= nil,
        logEnabled = self:IsLogEnabled(),
        logCount = self._devLog and self._devLog.count or 0,
        logLimit = self._devLog and self._devLog.limit or 0,
        triggerSchemas = schemaCount,
    }
end

EnsureDefaultTriggerSchemas()
