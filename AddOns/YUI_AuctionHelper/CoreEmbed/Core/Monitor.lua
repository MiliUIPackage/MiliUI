local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...
if not YUI then return end

local Monitor = YUI.Monitor or {}
YUI.Monitor = Monitor

local Instance = {}
Instance.__index = Instance

local ipairs = ipairs
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

local DEFAULT_MODULE_ID = "core.monitor"
local DEFAULT_UPDATE_INTERVAL = 0.1
local LOAD_EVENTS = {
    "YUI_WORLD_READY",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED",
    "ACTIVE_COMBAT_CONFIG_CHANGED",
}

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

local function SafeCall(label, func, ...)
    if type(func) ~= "function" then return false, nil end
    local Security = SecurityAPI()
    if Security and Security.SafeCall then
        return Security.SafeCall(label, func, ...)
    end
    return pcall(func, ...)
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
    data.applications = SafeNumber(ReadAuraField(aura, "applications", "stacks"))
    data.spellID = SafeNumber(ReadAuraField(aura, "spellId", "spellID")) or trigger.spellID
    data.updatedAt = now
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
    data.applications = nil
    data.spellID = trigger.spellID
    data.updatedAt = Now()
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

local function ResolveValue(value, instance, fallback)
    if type(value) == "function" then
        local ok, result = SafeCall("Monitor:value:" .. instance.id, value, instance.context, instance)
        if ok and result ~= nil then return result end
        return fallback
    end
    if value ~= nil then return value end
    return fallback
end

local function ApplyPoint(frame, point)
    if not (frame and type(point) == "table") then return end
    frame:ClearAllPoints()
    frame:SetPoint(
        point.point or "CENTER",
        point.relativeTo or UIParent,
        point.relativePoint or point.point or "CENTER",
        point.x or 0,
        point.y or 0
    )
end

local function EnsureGenericPresenter(instance)
    local appearance = instance.definition.appearance or {}
    if appearance.presenter then return appearance.presenter end
    local gui = GUI2()
    if not (gui and gui.CreateFrame and UIParent) then return nil end

    local visual = instance.visual
    if visual and visual.frame then return visual end

    local base = appearance.base or {}
    local baseType = base.type or appearance.type or "icon"
    local width = ResolveValue(base.width or appearance.width, instance, baseType == "bar" and 180 or 64)
    local height = ResolveValue(base.height or appearance.height, instance, baseType == "bar" and 24 or 64)
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
            width = width,
            height = height,
            value = 0,
            iconPosition = base.iconPosition,
            iconSize = base.iconSize,
            icon = ResolveValue(base.icon, instance, nil),
            fillColor = base.fillColor,
        })
        bar:SetPoint("CENTER", frame, "CENTER", 0, 0)
        visual.bar = bar
    elseif baseType == "text" and gui.CreateText then
        local text = gui:CreateText(frame, "", base.fontSize or "font.size.lg", base.colorKey or "color.text.primary", base.justifyH or "CENTER")
        text:SetPoint("CENTER", frame, "CENTER", 0, 0)
        visual.text = text
    elseif gui.CreateIconSlot then
        local size = ResolveValue(base.size, instance, width)
        local icon = gui:CreateIconSlot(frame, {
            size = size,
            icon = ResolveValue(base.icon, instance, nil),
            shape = base.shape or "square",
            padding = base.padding or 0,
            animate = base.animate,
        })
        icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
        visual.icon = icon
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
                overlay = gui:CreateText(frame, "", overlayDef.fontSize or "font.size.md", overlayDef.colorKey or "color.text.primary", overlayDef.justifyH or "CENTER")
            end
            if overlay then
                overlay.definition = overlayDef
                ApplyPoint(overlay, overlayDef.point or { point = "CENTER" })
                visual.overlays[#visual.overlays + 1] = overlay
            end
        end
    end

    ApplyPoint(frame, appearance.point or { point = "CENTER", y = -120 })
    return visual
end

local function UpdateGenericPresenter(instance)
    local visual = EnsureGenericPresenter(instance)
    if not (visual and visual.frame) then return false end

    local appearance = instance.definition.appearance or {}
    local base = appearance.base or {}
    if visual.icon and visual.icon.SetIcon then
        visual.icon:SetIcon(ResolveValue(base.icon, instance, visual.icon.icon))
    end
    if visual.bar and visual.bar.SetValue then
        visual.bar:SetValue(ResolveValue(base.value, instance, instance.context.progress or 0))
    end
    if visual.text then
        visual.text:SetText(tostring(ResolveValue(base.text, instance, "")))
    end

    for _, overlay in ipairs(visual.overlays) do
        local overlayDef = overlay.definition or {}
        if overlay.SetValue then
            overlay:SetValue(ResolveValue(overlayDef.value, instance, 0))
        elseif overlay.SetText then
            overlay:SetText(tostring(ResolveValue(overlayDef.text, instance, "")))
            local r, g, b, a = CopyColor(ResolveValue(overlayDef.color, instance, nil))
            if r then overlay:SetTextColor(r, g, b, a or 1) end
        end
        if overlayDef.visible then
            if ResolveValue(overlayDef.visible, instance, true) then overlay:Show() else overlay:Hide() end
        end
    end

    if instance.active or instance.visible then
        visual.frame:Show()
    end
    return true
end

local function CallPresenter(instance, method)
    local appearance = instance.definition.appearance or {}
    local presenter = appearance.presenter
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

local function PrepareTrigger(instance, index, definition)
    if type(definition) ~= "table" then return nil end
    local spellID = SafeNumber(definition.spellID or definition.spellId)
    local duration = SafeNumber(definition.duration)
    local unit = NormalizeUnit(definition.unit, definition.type == "playerAura" and "player" or nil)
    local trigger = {
        index = index,
        id = definition.id or tostring(index),
        type = definition.type or "event",
        definition = definition,
        unit = unit,
        units = definition.units,
        event = definition.event,
        events = definition.events,
        spellID = spellID,
        duration = duration,
        icon = definition.icon,
        activation = definition.activation,
        active = false,
        changed = false,
        data = {
            spellID = spellID,
            duration = duration,
            icon = definition.icon,
        },
    }
    return trigger
end

local function TriggerMatchesUnit(trigger, unit)
    if trigger.unit then
        return NormalizeUnit(unit, "") == trigger.unit
    end
    if type(trigger.units) == "table" then
        local safeUnit = NormalizeUnit(unit, "")
        for _, item in ipairs(trigger.units) do
            if item == safeUnit then return true end
        end
        return false
    end
    return true
end

local function ClampProgress(value)
    value = SafeNumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function RefreshCooldownWindowData(trigger, now)
    if not (trigger and trigger.type == "spellCooldownWindow") then return false end
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

local function ScheduleCooldownWindowReset(instance, trigger)
    if not (instance and trigger and C_Timer and C_Timer.After) then return end
    local expirationTime = SafeNumber(trigger.data and trigger.data.expirationTime)
    if not expirationTime then return end

    local delay = expirationTime - Now()
    if delay < 0 then delay = 0 end
    local token = (trigger.windowToken or 0) + 1
    trigger.windowToken = token

    C_Timer.After(delay, function()
        if trigger.windowToken ~= token or not instance.running then return end
        if RefreshCooldownWindowData(trigger, Now()) then
            instance:Refresh("cooldown-window-expired")
        end
    end)
end

local function StartCooldownWindowTrigger(instance, trigger, event, spellID, baseSpellID, category, startRecoveryCategory)
    local duration = SafeNumber(trigger.duration) or SafeNumber(trigger.definition and trigger.definition.duration)
    if not (duration and duration > 0) then return false end

    local now = Now()
    local previous = trigger.active == true
    local data = trigger.data
    trigger.active = true
    trigger.changed = previous ~= true
    data.event = event
    data.spellID = SafeNumber(spellID) or trigger.spellID
    data.baseSpellID = SafeNumber(baseSpellID)
    data.category = SafeNumber(category)
    data.startRecoveryCategory = SafeNumber(startRecoveryCategory)
    data.startTime = now
    data.duration = duration
    data.expirationTime = now + duration
    data.remaining = duration
    data.elapsed = 0
    data.progress = 0
    data.timestamp = now
    data.updatedAt = now
    data.count = (data.count or 0) + 1

    instance.manager._stats.triggerUpdates = instance.manager._stats.triggerUpdates + 1
    instance:_CallCondition("onTrigger", trigger, event, spellID, baseSpellID, category, startRecoveryCategory)
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

function Instance:_EvaluateDerivedTriggers()
    for _, trigger in ipairs(self.triggers) do
        if trigger.type == "derived" then
            local previous = trigger.active == true
            local update = trigger.definition.update
            local nextActive = previous
            if type(update) == "function" then
                local ok, active = SafeCall("Monitor:derived:" .. self.id .. ":" .. trigger.id, update, self.context, trigger, self)
                if ok and active ~= nil then
                    nextActive = active == true
                end
            end
            trigger.changed = previous ~= nextActive
            trigger.active = nextActive
        end
    end
end

function Instance:_EvaluateCooldownWindowTriggers()
    local now = Now()
    for _, trigger in ipairs(self.triggers) do
        if trigger.type == "spellCooldownWindow" then
            RefreshCooldownWindowData(trigger, now)
        end
    end
end

function Instance:_EvaluateActivation(reason)
    self:_PrepareContext()
    self:_EvaluateDerivedTriggers()
    self:_EvaluateCooldownWindowTriggers()

    local nextActive
    if type(self.expression) == "function" then
        local ok, result = SafeCall("Monitor:expression:" .. self.id, self.expression, self.context, self.triggers, self.state, self)
        nextActive = ok and result == true
    else
        nextActive = DefaultExpression(self.context, self.triggers)
    end

    self:_SetActive(nextActive, reason)
    return nextActive
end

function Instance:_SetActive(nextActive, reason)
    nextActive = nextActive == true
    if self.active == nextActive then
        self.context.active = nextActive
        return false
    end

    local previous = self.active == true
    self.active = nextActive
    self.visible = nextActive or self.visible == true
    self.reason = reason
    self.context.active = nextActive
    self.context.reason = reason

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
                self:_CallCondition("onTrigger", trigger, event, unit, castGUID, spellID)
                self:Refresh(event)
                self:_SchedulePulseReset(trigger)
            end
        end
    end
end

function Instance:_OnGenericEvent(event, ...)
    for _, trigger in ipairs(self.triggers) do
        if trigger.type == "event" then
            local matches = false
            if trigger.event == event then
                matches = true
            elseif type(trigger.events) == "table" then
                matches = TableContains(trigger.events, event)
            end
            if matches then
                local previous = trigger.active == true
                trigger.active = true
                trigger.changed = previous ~= true
                trigger.data.event = event
                trigger.data.timestamp = Now()
                trigger.data.args = trigger.definition.keepArgs == true and { ... } or nil
                self.manager._stats.triggerUpdates = self.manager._stats.triggerUpdates + 1
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
    local function ResetPulse()
        if trigger.pulseToken ~= token or not self.running then return end
        trigger.active = false
        trigger.changed = true
        self:Refresh("pulse-reset")
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, ResetPulse)
    else
        ResetPulse()
    end
end

function Instance:_RegisterTriggerEvents()
    local Event = EventBus()
    if not (Event and Event.On) then return false end
    if Event.OffOwner then Event:OffOwner(self.eventOwner) end

    local needsUnitAura = {}
    local needsSpellcast = {}
    local genericEvents = {}
    local needsSpellCooldownWindow = false
    for _, trigger in ipairs(self.triggers) do
        if trigger.type == "playerAura" or trigger.type == "unitAura" then
            needsUnitAura[trigger.unit or "player"] = true
        elseif trigger.type == "unitSpellcastSucceeded" then
            needsSpellcast[trigger.unit or "player"] = true
        elseif trigger.type == "event" then
            if trigger.event then genericEvents[trigger.event] = true end
            if type(trigger.events) == "table" then
                for _, eventName in ipairs(trigger.events) do
                    genericEvents[eventName] = true
                end
            end
        elseif trigger.type == "spellCooldownWindow" then
            needsSpellCooldownWindow = true
        end
    end

    for unit in pairs(needsUnitAura) do
        Event:On("UNIT_AURA", "_OnUnitAura", self, {
            unit = unit,
            moduleId = self.moduleId,
            throttle = self.policy.eventThrottle,
        })
    end
    for unit in pairs(needsSpellcast) do
        Event:On("UNIT_SPELLCAST_SUCCEEDED", "_OnSpellcastSucceeded", self, {
            unit = unit,
            moduleId = self.moduleId,
        })
    end
    for eventName in pairs(genericEvents) do
        Event:On(eventName, "_OnGenericEvent", self, {
            moduleId = self.moduleId,
            throttle = self.policy.eventThrottle,
        })
    end
    if needsSpellCooldownWindow then
        Event:On("SPELL_UPDATE_COOLDOWN", "_OnSpellCooldownWindowEvent", self, {
            moduleId = self.moduleId,
        })
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
    self:_PrepareContext()
    if self:_ShouldRefreshTriggers(reason) then
        self:_RefreshAuraTriggers(reason)
    end
    self:_EvaluateActivation(reason)
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
    return true
end

function Instance:Tick(elapsed)
    if not self.running then return end
    self.elapsedSinceUpdate = (self.elapsedSinceUpdate or 0) + (elapsed or 0)
    local interval = SafeNumber(self.definition.update and self.definition.update.interval) or self.policy.defaultUpdateInterval or DEFAULT_UPDATE_INTERVAL
    if interval > 0 and self.elapsedSinceUpdate < interval then return end
    self.elapsedSinceUpdate = 0
    self.context.elapsed = elapsed
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
    self:RefreshLoad("set-enabled")
    return self.running == true
end

function Instance:RefreshLoad(reason)
    local shouldRun = self.requestedEnabled == true and self:IsLoaded()
    self.loaded = shouldRun
    self:_PrepareContext()
    if shouldRun and not self.running then
        self.running = true
        self.visible = false
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
    self.visible = false
    CallPresenter(self, "hide")
    self.manager:_SetTicker(self, self:NeedsTick())
end

function Instance:Show()
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
    if self.running then
        self:_SetActive(false, "destroy")
    end
    self.running = false
    self.active = false
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
    instance.hasActiveUpdater = type(definition.update) == "table"
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
            spellID = trigger.spellID,
            data = trigger.data,
        }
    end

    return {
        id = instance.id,
        requestedEnabled = instance.requestedEnabled == true,
        loaded = instance.loaded == true,
        running = instance.running == true,
        active = instance.active == true,
        visible = instance.visible == true,
        expressionError = instance.expressionError,
        reason = instance.reason,
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
        self:_EnsureTickerFrame()
        self._tickerFrame:Show()
    elseif self._activeTickers[instance] then
        self._activeTickers[instance] = nil
        self._activeTickerCount = self._activeTickerCount - 1
    end
    if self._tickerFrame and self._activeTickerCount <= 0 then
        self._tickerFrame:Hide()
    end
end

function Monitor:_EnsureTickerFrame()
    if self._tickerFrame or not CreateFrame then return end
    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnUpdate", function(_, elapsed)
        Monitor:_OnUpdate(elapsed)
    end)
    self._tickerFrame = frame
end

function Monitor:_OnUpdate(elapsed)
    if self._activeTickerCount <= 0 then
        if self._tickerFrame then self._tickerFrame:Hide() end
        return
    end
    for instance in pairs(self._activeTickers) do
        if instance and instance.running then
            instance:Tick(elapsed)
        else
            self:_SetTicker(instance, false)
        end
    end
end

function Monitor:_EnsureRuntimeEvents()
    if self._eventsRegistered then return end
    local Event = EventBus()
    if not (Event and Event.On) then return end
    self._eventsRegistered = true
    for _, eventName in ipairs(LOAD_EVENTS) do
        Event:On(eventName, function(event)
            Monitor:RefreshLoad(event)
        end, self._owner, { moduleId = DEFAULT_MODULE_ID, throttle = self.Policy.eventThrottle })
    end
end

function Monitor:GetStats()
    return {
        instances = #self.order,
        activeTickers = self._activeTickerCount,
        refreshes = self._stats.refreshes,
        triggerUpdates = self._stats.triggerUpdates,
        presenterUpdates = self._stats.presenterUpdates,
    }
end
