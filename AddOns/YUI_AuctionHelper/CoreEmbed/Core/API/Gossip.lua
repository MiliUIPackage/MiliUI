do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}

local Gossip = YUI.API.Gossip or {}
YUI.API.Gossip = Gossip

local Security = YUI.API.Security
local EMPTY_OPTIONS = {}
local MAX_SAFE_INTEGER = 9007199254740991
local bitBand = (_G.bit and _G.bit.band) or (_G.bit32 and _G.bit32.band)

local function ReadField(option, key)
    if type(option) ~= "table" then return nil, false end
    local ok, value = pcall(function() return option[key] end)
    if not ok or (Security and Security.IsSecretValue and Security.IsSecretValue(value)) then
        return nil, false
    end
    return value, true
end

local function SafeNumber(value)
    if Security and Security.SafeNumber then
        return Security.SafeNumber(value)
    end
    local ok, numberValue = pcall(tonumber, value)
    return ok and numberValue or nil
end

local function PositiveInteger(value)
    value = SafeNumber(value)
    if not value or value <= 0 or value > MAX_SAFE_INTEGER or value ~= math.floor(value) then return nil end
    return value
end

function Gossip.GetOptions()
    local api = _G.C_GossipInfo
    if not (api and type(api.GetOptions) == "function") then return EMPTY_OPTIONS end
    local ok, options
    if Security and Security.SafeCall then
        ok, options = Security.SafeCall("Gossip.GetOptions", api.GetOptions)
    else
        ok, options = pcall(api.GetOptions)
    end
    if not ok or type(options) ~= "table" then return EMPTY_OPTIONS end
    if Security and Security.CanAccessTable and Security.CanAccessTable(options) == false then
        return EMPTY_OPTIONS
    end
    return options
end

function Gossip.GetText()
    local api = _G.C_GossipInfo
    if not (api and type(api.GetText) == "function") then return "" end
    local ok, value
    if Security and Security.SafeCall then
        ok, value = Security.SafeCall("Gossip.GetText", api.GetText)
    else
        ok, value = pcall(api.GetText)
    end
    if not ok then return "" end
    if Security and Security.SafeString then
        return Security.SafeString(value) or ""
    end
    return type(value) == "string" and value or ""
end

-- Normalizes one cold-path Gossip record. Passing reuse avoids an allocation.
-- Returns nil when a field required for safe selection is unreadable or secret.
function Gossip.ReadOption(option, fallbackOrder, reuse)
    local orderIndex, orderReadable = ReadField(option, "orderIndex")
    local status, statusReadable = ReadField(option, "status")
    local flags, flagsReadable = ReadField(option, "flags")
    local name, nameReadable = ReadField(option, "name")
    local optionID, optionIDReadable = ReadField(option, "gossipOptionID")
    local spellID, spellReadable = ReadField(option, "spellID")
    local rewards, rewardsReadable = ReadField(option, "rewards")
    local selectWhenOnly, selectReadable = ReadField(option, "selectOptionWhenOnlyOption")

    if not orderReadable or not statusReadable or not flagsReadable or not nameReadable
        or not optionIDReadable or not spellReadable or not rewardsReadable or not selectReadable then
        return nil, "unreadable"
    end

    orderIndex = PositiveInteger(orderIndex) or PositiveInteger(fallbackOrder)
    status = SafeNumber(status)
    flags = SafeNumber(flags)
    if not orderIndex or status == nil or flags == nil or type(name) ~= "string" then
        return nil, "invalid"
    end

    local optionIDWasPresent = optionID ~= nil
    optionID = optionIDWasPresent and PositiveInteger(optionID) or nil
    if optionIDWasPresent and not optionID then return nil, "invalid_option_id" end

    if spellID ~= nil then
        spellID = PositiveInteger(spellID)
        if not spellID then return nil, "invalid_spell_id" end
    end

    local hasRewards = false
    if rewards ~= nil then
        if type(rewards) ~= "table" then return nil, "invalid_rewards" end
        local rewardsOK, firstReward = pcall(next, rewards)
        if not rewardsOK then return nil, "unreadable_rewards" end
        hasRewards = firstReward ~= nil
    end

    if selectWhenOnly ~= nil and type(selectWhenOnly) ~= "boolean" then
        return nil, "invalid_select_policy"
    end

    local record = reuse or {}
    record.optionID = optionID
    record.orderIndex = orderIndex
    record.status = status
    record.flags = flags
    record.name = name
    record.spellID = spellID
    record.hasRewards = hasRewards
    record.selectOptionWhenOnlyOption = selectWhenOnly == true
    return record
end

function Gossip.IsOptionAvailable(record)
    local available = _G.Enum and _G.Enum.GossipOptionStatus
        and _G.Enum.GossipOptionStatus.Available
    return type(record) == "table" and available ~= nil and record.status == available
end

function Gossip.HasOptionFlag(record, flag)
    flag = SafeNumber(flag)
    return type(record) == "table" and type(record.flags) == "number"
        and flag ~= nil and type(bitBand) == "function" and bitBand(record.flags, flag) ~= 0
end

function Gossip.SelectOptionByID(optionID)
    optionID = PositiveInteger(optionID)
    local api = _G.C_GossipInfo
    if not optionID or not (api and type(api.SelectOption) == "function") then
        return false
    end
    if Security and Security.SafeCall then
        return Security.SafeCall("Gossip.SelectOption", api.SelectOption, optionID)
    end
    return pcall(api.SelectOption, optionID)
end

function Gossip.SelectOptionByIndex(orderIndex)
    orderIndex = PositiveInteger(orderIndex)
    local api = _G.C_GossipInfo
    if not orderIndex or not (api and type(api.SelectOptionByIndex) == "function") then
        return false
    end
    if Security and Security.SafeCall then
        return Security.SafeCall("Gossip.SelectOptionByIndex", api.SelectOptionByIndex, orderIndex)
    end
    return pcall(api.SelectOptionByIndex, orderIndex)
end
