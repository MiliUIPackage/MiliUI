do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}

local ActionBar = YUI.API.ActionBar or {}
YUI.API.ActionBar = ActionBar

local function IsSecretValue(value)
    local security = YUI.API and YUI.API.Security
    if security and security.IsSecretValue then
        return security.IsSecretValue(value) == true
    end
    if type(issecretvalue) ~= "function" then return false end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function SafeNumber(value)
    if IsSecretValue(value) or value == nil then return nil end
    local ok, numberValue = pcall(tonumber, value)
    if not ok or IsSecretValue(numberValue) then return nil end
    return numberValue
end

local function SafeString(value)
    if IsSecretValue(value) or type(value) ~= "string" then return nil end
    return value
end

local BINDING_MODIFIERS = {
    CTRL = "C",
    ALT = "A",
    SHIFT = "S",
    META = "M",
}

local BINDING_KEYS = {
    MOUSEWHEELUP = "MwU",
    MOUSEWHEELDOWN = "MwD",
    NUMPADDECIMAL = "N.",
    NUMPADPLUS = "N+",
    NUMPADMINUS = "N-",
    NUMPADMULTIPLY = "N*",
    NUMPADDIVIDE = "N/",
    CAPSLOCK = "Caps",
    PAGEUP = "PU",
    PAGEDOWN = "PD",
    SPACE = "SpB",
    INSERT = "Ins",
    HOME = "Hm",
    DELETE = "Del",
}

local function SplitBindingKey(rawKey)
    local prefix = ""
    local baseKey = rawKey
    while true do
        local modifier = baseKey:match("^(%u+)%-")
        local abbreviation = modifier and BINDING_MODIFIERS[modifier]
        if not abbreviation then break end
        prefix = prefix .. abbreviation
        baseKey = baseKey:sub(#modifier + 2)
    end
    return prefix, baseKey
end

local function FormatKnownBindingKey(baseKey)
    local text = BINDING_KEYS[baseKey]
    if text then return text end

    local button = baseKey:match("^BUTTON(%d+)$")
    if button then return "M" .. button end
    local numpad = baseKey:match("^NUMPAD(%d+)$")
    if numpad then return "N" .. numpad end

    if #baseKey == 1 or baseKey:match("^F%d+$") then
        return baseKey
    end
    return nil
end

local function ClearResult(result)
    result = result or {}
    for key in pairs(result) do
        result[key] = nil
    end
    return result
end

local function ReadActionInfo(slot)
    local modern = _G.C_ActionBar and _G.C_ActionBar.GetActionInfo
    local reader = type(modern) == "function" and modern or _G.GetActionInfo
    if type(reader) ~= "function" then return nil, "api-unavailable" end

    local ok, actionType, actionID, actionSubType = pcall(reader, slot)
    if not ok then return nil, "api-error" end
    if IsSecretValue(actionType)
        or IsSecretValue(actionID)
        or IsSecretValue(actionSubType) then
        return nil, "restricted"
    end
    if actionType == nil then return nil, "empty" end
    actionType = SafeString(actionType)
    if not actionType then return nil, "invalid-action-type" end
    return actionType, actionID, actionSubType
end

local function ReadMacroSpellID(macroIndex)
    if type(_G.GetMacroSpell) ~= "function" then
        return nil, "api-unavailable"
    end
    local ok, first, second, third = pcall(_G.GetMacroSpell, macroIndex)
    if not ok then return nil, "api-error" end
    if IsSecretValue(first) or IsSecretValue(second) or IsSecretValue(third) then
        return nil, "restricted"
    end
    local spellID = SafeNumber(first)
        or SafeNumber(second)
        or SafeNumber(third)
    if not spellID or spellID <= 0 then return nil, "unavailable" end
    return math.floor(spellID), nil
end

local function ResolveMacroIndexByActionText(slot)
    if type(_G.GetActionText) ~= "function"
        or type(_G.GetMacroIndexByName) ~= "function" then
        return nil, "unavailable"
    end
    local okText, macroName = pcall(_G.GetActionText, slot)
    if not okText then return nil, "api-error" end
    if IsSecretValue(macroName) then return nil, "restricted" end
    macroName = SafeString(macroName)
    if not macroName or macroName == "" then return nil, "unavailable" end
    local okIndex, resolvedIndex = pcall(_G.GetMacroIndexByName, macroName)
    if not okIndex then return nil, "api-error" end
    if IsSecretValue(resolvedIndex) then return nil, "restricted" end
    resolvedIndex = SafeNumber(resolvedIndex)
    if not resolvedIndex or resolvedIndex <= 0 then return nil, "unavailable" end
    return math.floor(resolvedIndex), nil
end

local function ResolveMacroIndex(slot, actionID, actionSubType)
    local macroIndex, reason = ResolveMacroIndexByActionText(slot)
    if macroIndex then return macroIndex, nil end
    if reason == "api-error" or reason == "restricted" then
        return nil, reason
    end

    -- Retail may expose the currently effective spell ID in actionID when
    -- subtype is "spell". In that shape actionID must never be treated as a
    -- macro index. Older shapes expose the actual macro index instead.
    if actionSubType == "spell" then return nil, "unavailable" end
    macroIndex = SafeNumber(actionID)
    if macroIndex and macroIndex > 0 then
        return math.floor(macroIndex), nil
    end
    return nil, "unavailable"
end

function ActionBar:IsAvailable()
    return type(_G.C_ActionBar and _G.C_ActionBar.GetActionInfo) == "function"
        or type(_G.GetActionInfo) == "function"
end

function ActionBar:GetProfessionQualityAtlas(slot)
    if YUI.IsRetail ~= true then return nil end
    slot = SafeNumber(slot)
    if not slot or slot <= 0 then return nil end

    local reader = _G.C_ActionBar and _G.C_ActionBar.GetProfessionQualityInfo
    if type(reader) ~= "function" then return nil end

    local ok, info = pcall(reader, math.floor(slot))
    if not ok or IsSecretValue(info) or type(info) ~= "table" then return nil end
    return SafeString(info.iconInventory)
end

function ActionBar:ReadSlotIdentity(slot, result)
    slot = SafeNumber(slot)
    if not slot or slot <= 0 then return nil, "invalid-slot" end
    slot = math.floor(slot)

    local actionType, actionID, actionSubType = ReadActionInfo(slot)
    if not actionType then return nil, actionID end

    result = ClearResult(result)
    result.slot = slot
    result.actionType = actionType
    result.actionSubType = SafeString(actionSubType)
    result.actionID = SafeNumber(actionID)

    if actionType == "spell" then
        local spellID = SafeNumber(actionID)
        if not spellID or spellID <= 0 then return nil, "invalid-spell" end
        result.spellID = math.floor(spellID)
    elseif actionType == "macro" then
        local macroIndex, macroReason = ResolveMacroIndex(
            slot, actionID, result.actionSubType
        )
        if macroReason == "api-error" or macroReason == "restricted" then
            return nil, macroReason
        end
        result.macroIndex = macroIndex
        if result.actionSubType == "spell" then
            local currentSpellID = SafeNumber(actionID)
            if currentSpellID and currentSpellID > 0 then
                result.currentSpellID = math.floor(currentSpellID)
            end
        elseif macroIndex then
            local spellID, spellReason = ReadMacroSpellID(macroIndex)
            if spellReason == "api-error" or spellReason == "restricted" then
                return nil, spellReason
            end
            result.currentSpellID = spellID
        end
    elseif actionType == "item" then
        local itemID = SafeNumber(actionID)
        if itemID and itemID > 0 then result.itemID = math.floor(itemID) end
    end

    return result, nil
end

function ActionBar:ReadMacroBody(macroIndex)
    macroIndex = SafeNumber(macroIndex)
    if not macroIndex or macroIndex <= 0 then return nil, "invalid-macro" end
    macroIndex = math.floor(macroIndex)

    if type(_G.GetMacroBody) == "function" then
        local ok, body = pcall(_G.GetMacroBody, macroIndex)
        if not ok then return nil, "api-error" end
        if IsSecretValue(body) then return nil, "restricted" end
        body = SafeString(body)
        if body then return body, nil end
    end

    if type(_G.GetMacroInfo) ~= "function" then
        return nil, "api-unavailable"
    end
    local ok, name, icon, body = pcall(_G.GetMacroInfo, macroIndex)
    if not ok then return nil, "api-error" end
    if IsSecretValue(name) or IsSecretValue(icon) or IsSecretValue(body) then
        return nil, "restricted"
    end
    body = SafeString(body)
    if body then return body, nil end
    return nil, "unavailable"
end

function ActionBar:FormatBindingKey(rawKey)
    rawKey = SafeString(rawKey)
    if not rawKey or rawKey == "" then return nil, "invalid-key" end

    local prefix, baseKey = SplitBindingKey(rawKey)
    if baseKey == "" then return nil, "invalid-key" end
    local known = FormatKnownBindingKey(baseKey)
    if known then return prefix .. known, nil end
    if type(_G.GetBindingText) ~= "function" then
        return prefix .. baseKey, nil
    end

    local ok, text = pcall(_G.GetBindingText, baseKey, 1)
    if not ok then return nil, "api-error" end
    if IsSecretValue(text) then return nil, "restricted" end
    text = SafeString(text)
    if not text or text == "" then text = baseKey end
    return prefix .. text, nil
end

function ActionBar:ReadBinding(command, result)
    command = SafeString(command)
    if not command or command == "" then return nil, "invalid-command" end
    if type(_G.GetBindingKey) ~= "function" then
        return nil, "api-unavailable"
    end

    local ok, primaryKey, secondaryKey = pcall(_G.GetBindingKey, command)
    if not ok then return nil, "api-error" end
    if IsSecretValue(primaryKey) or IsSecretValue(secondaryKey) then
        return nil, "restricted"
    end
    primaryKey = SafeString(primaryKey)
    secondaryKey = SafeString(secondaryKey)
    if not primaryKey and not secondaryKey then return nil, "unbound" end

    result = ClearResult(result)
    result.command = command
    result.primaryKey = primaryKey
    result.secondaryKey = secondaryKey
    if primaryKey then
        local text, reason = self:FormatBindingKey(primaryKey)
        if not text then return nil, reason end
        result.primaryText = text
    end
    if secondaryKey then
        local text, reason = self:FormatBindingKey(secondaryKey)
        if not text then return nil, reason end
        result.secondaryText = text
    end
    return result, nil
end
