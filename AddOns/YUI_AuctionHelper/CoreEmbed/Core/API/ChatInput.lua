do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, addonTable = ...
local YUI = _G.YUI or addonTable

YUI.API = YUI.API or {}

local ChatInput = YUI.API.ChatInput or {}
YUI.API.ChatInput = ChatInput

local Security = YUI.API.Security
local owners = {}
local suspendedEditBoxes = setmetatable({}, { __mode = "k" })
local previousHandler
local installed = false
local activeOwner
local lifecycleOwner = {}
local lifecycleAttached = false

local type = type
local pcall = pcall
local floor = math.floor
local sub = string.sub
local pairs = pairs
local tostring = tostring

local GetChannelList = _G.GetChannelList
local IsShiftKeyDown = _G.IsShiftKeyDown
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local IsInGuild = _G.IsInGuild
local IsGuildLeader = _G.IsGuildLeader
local IsPartyLFG = _G.IsPartyLFG
local IsPartyWalkIn = type(_G.C_PartyInfo) == "table" and _G.C_PartyInfo.IsPartyWalkIn or nil
local HOME_PARTY_CATEGORY = _G.LE_PARTY_CATEGORY_HOME
local INSTANCE_PARTY_CATEGORY = _G.LE_PARTY_CATEGORY_INSTANCE

local function IsSafeValue(value)
    local checker = _G.issecretvalue
    if type(checker) == "function" then
        local ok, secret = pcall(checker, value)
        return ok and secret == false
    end
    return not (Security and Security.IsSecretValue and Security.IsSecretValue(value))
end

local function ReadBoolean(callback, argument)
    if type(callback) ~= "function" then return false, true end
    local ok, value
    if argument == nil then
        ok, value = pcall(callback)
    else
        ok, value = pcall(callback, argument)
    end
    if not ok or not IsSafeValue(value) or type(value) ~= "boolean" then
        return nil, false
    end
    return value, true
end

local function ReadMethod(object, callback, argument)
    if type(callback) ~= "function" then return nil, false end
    local ok, value
    if argument == nil then
        ok, value = pcall(callback, object)
    else
        ok, value = pcall(callback, object, argument)
    end
    if not ok or not IsSafeValue(value) then return nil, false end
    return value, true
end

local function ReadEditBox(editBox, explicit)
    if not IsSafeValue(editBox)
        or (type(editBox) ~= "table" and type(editBox) ~= "userdata")
        or type(editBox.GetText) ~= "function"
        or type(editBox.GetAttribute) ~= "function"
    then
        return false
    end

    local text, textSafe = ReadMethod(editBox, editBox.GetText)
    if not textSafe or type(text) ~= "string" or (not explicit and sub(text, 1, 1) == "/") then
        return false
    end
    local chatType, typeSafe = ReadMethod(editBox, editBox.GetAttribute, "chatType")
    if not typeSafe or type(chatType) ~= "string" or chatType == "" then return false end
    local channelTarget, channelSafe = ReadMethod(editBox, editBox.GetAttribute, "channelTarget")
    if not channelSafe then return false end
    if YUI.IsRetail then return true, chatType, channelTarget end
    local tellTarget, tellSafe = ReadMethod(editBox, editBox.GetAttribute, "tellTarget")
    if not tellSafe then return false end
    return true, chatType, channelTarget, tellTarget
end

local function CanWrite(editBox)
    local restricted = _G.C_RestrictedActions
    local checker = restricted and restricted.CheckAllowProtectedFunctions
    if type(checker) ~= "function" then return false end
    local ok, allowed = pcall(checker, editBox, true)
    return ok and IsSafeValue(allowed) and allowed == true
end

local function IsInteractionAllowed()
    local chatAPI = _G.C_ChatInfo
    local callback = chatAPI and chatAPI.InChatMessagingLockdown
    if type(callback) ~= "function" then return false end
    local ok, locked = pcall(callback)
    return ok and IsSafeValue(locked) and type(locked) == "boolean"
end

local function IsWorldChannelName(name)
    return name == "大脚世界频道" or name == "大腳世界頻道"
end

local function AddTarget(targets, chatType, channelId)
    targets[#targets + 1] = { chatType = chatType, channelId = channelId }
end

local function BuildTargets()
    local targets = {}
    AddTarget(targets, "SAY")

    if YUI.IsRetail and (HOME_PARTY_CATEGORY == nil or INSTANCE_PARTY_CATEGORY == nil) then return nil end
    local grouped, groupSafe = ReadBoolean(IsInGroup, YUI.IsRetail and HOME_PARTY_CATEGORY or nil)
    if not groupSafe then return nil end
    if grouped then AddTarget(targets, "PARTY") end

    local raiding, raidSafe = ReadBoolean(IsInRaid, YUI.IsRetail and HOME_PARTY_CATEGORY or nil)
    if not raidSafe then return nil end
    if raiding then AddTarget(targets, "RAID") end

    if YUI.IsRetail then
        local instance, safe = ReadBoolean(IsInGroup, INSTANCE_PARTY_CATEGORY)
        if not safe then return nil end
        if instance then AddTarget(targets, "INSTANCE_CHAT") end
    else
        local inLFG, lfgSafe = ReadBoolean(IsPartyLFG)
        if not lfgSafe then return nil end
        local inWalkIn, walkInSafe = ReadBoolean(IsPartyWalkIn)
        if not walkInSafe then return nil end
        if inLFG or inWalkIn then AddTarget(targets, "INSTANCE_CHAT") end
    end

    local guilded, guildSafe = ReadBoolean(IsInGuild)
    if not guildSafe then return nil end
    if guilded then
        AddTarget(targets, "GUILD")
        local officer, officerSafe = ReadBoolean(IsGuildLeader)
        if not officerSafe then return nil end
        local guildInfo = _G.C_GuildInfo
        if not officer and type(guildInfo) == "table"
            and type(guildInfo.IsGuildOfficer) == "function"
        then
            officer, officerSafe = ReadBoolean(guildInfo.IsGuildOfficer)
            if not officerSafe then return nil end
        end
        if officer then AddTarget(targets, "OFFICER") end
    end

    if type(GetChannelList) == "function" then
        local values = { pcall(GetChannelList) }
        if values[1] ~= true or (#values - 1) % 3 ~= 0 then return nil end
        for index = 2, #values, 3 do
            local id, name, disabled = values[index], values[index + 1], values[index + 2]
            if not IsSafeValue(id) or not IsSafeValue(name) or not IsSafeValue(disabled)
                or type(name) ~= "string" or type(disabled) ~= "boolean"
            then
                return nil
            end
            if type(id) == "number" and id >= 1 and floor(id) == id
                and disabled ~= true and IsWorldChannelName(name)
            then
                AddTarget(targets, "CHANNEL", id)
                break
            end
        end
    end
    return targets
end

local function UpdateHeader(editBox)
    if type(editBox.UpdateHeader) == "function" then return pcall(editBox.UpdateHeader, editBox) end
    if type(_G.ChatEdit_UpdateHeader) == "function" then return pcall(_G.ChatEdit_UpdateHeader, editBox) end
    return true
end

local function RestoreTarget(editBox, chatType, channelTarget, tellTarget)
    local restored = true
    if type(editBox.SetChannelTarget) == "function" then
        restored = pcall(editBox.SetChannelTarget, editBox, channelTarget) and restored
    end
    if type(editBox.SetTellTarget) == "function" then
        restored = pcall(editBox.SetTellTarget, editBox, tellTarget) and restored
    elseif tellTarget ~= nil then
        restored = false
    end
    restored = type(editBox.SetChatType) == "function"
        and pcall(editBox.SetChatType, editBox, chatType) and restored
    return UpdateHeader(editBox) and restored
end

local function ApplyTarget(editBox, target)
    if not CanWrite(editBox) or type(editBox.SetChatType) ~= "function" then return false end
    local snapshotOK, oldType, oldChannel, oldTell = ReadEditBox(editBox)
    if not snapshotOK then return false end
    local applied = true
    if target.chatType == "CHANNEL" then
        applied = type(editBox.SetChannelTarget) == "function"
            and pcall(editBox.SetChannelTarget, editBox, target.channelId)
    end
    if applied then applied = pcall(editBox.SetChatType, editBox, target.chatType) end
    if applied then applied = UpdateHeader(editBox) end

    local appliedType, typeSafe
    if applied then
        appliedType, typeSafe = ReadMethod(editBox, editBox.GetAttribute, "chatType")
        applied = typeSafe and (appliedType == target.chatType
            or ((target.chatType == "PARTY" or target.chatType == "RAID")
                and appliedType == "INSTANCE_CHAT"))
    end
    if applied and target.chatType == "CHANNEL" then
        local appliedChannel, channelSafe = ReadMethod(editBox, editBox.GetAttribute, "channelTarget")
        applied = channelSafe and appliedChannel == target.channelId
    end
    if applied then return true end

    RestoreTarget(editBox, oldType, oldChannel, oldTell)
    suspendedEditBoxes[editBox] = true
    return false
end

local function IsSwitchTargetAvailable(chatType, channelId)
    if not IsSafeValue(chatType) or type(chatType) ~= "string" then return false end
    if chatType == "SAY" or chatType == "YELL" then return true end
    if chatType == "PARTY" or chatType == "RAID" or chatType == "INSTANCE_CHAT" then
        return ChatInput.IsGroupChatTypeAvailable(chatType)
    end
    if chatType == "GUILD" or chatType == "OFFICER" then
        local guilded, safe = ReadBoolean(IsInGuild)
        if not safe or not guilded then return false end
        if chatType == "GUILD" then return true end
        local leader, leaderSafe = ReadBoolean(IsGuildLeader)
        if not leaderSafe then return false end
        if leader then return true end
        local officer, officerSafe = ReadBoolean(_G.C_GuildInfo and _G.C_GuildInfo.IsGuildOfficer)
        return officerSafe and officer == true
    end
    if chatType == "RAID_WARNING" then
        if not ChatInput.IsGroupChatTypeAvailable("RAID") then return false end
        local leader, leaderSafe = ReadBoolean(_G.UnitIsGroupLeader, "player")
        local assistant, assistantSafe = ReadBoolean(_G.UnitIsGroupAssistant, "player")
        local everyone, everyoneSafe = ReadBoolean(_G.IsEveryoneAssistant)
        return leaderSafe and assistantSafe and everyoneSafe and (leader or assistant or everyone)
    end
    if chatType ~= "CHANNEL" or not IsSafeValue(channelId) or type(channelId) ~= "number"
        or channelId < 1 or floor(channelId) ~= channelId or type(GetChannelList) ~= "function" then
        return false
    end
    local values = { pcall(GetChannelList) }
    if values[1] ~= true or (#values - 1) % 3 ~= 0 then return false end
    for index = 2, #values, 3 do
        local id, disabled = values[index], values[index + 2]
        if not IsSafeValue(id) or not IsSafeValue(disabled) then return false end
        if id == channelId then return disabled == false end
    end
    return false
end

-- Explicit switching leaves text, selection, sticky type and whisper identity untouched.
-- Only attributes modified by this transaction are read for rollback.
function ChatInput.SwitchChannel(editBox, chatType, channelId, activate)
    if not YUI.IsRetail then return false, "unsupported-client" end
    if not IsSafeValue(editBox) or (type(editBox) ~= "table" and type(editBox) ~= "userdata") then
        return false, "invalid-editbox"
    end
    if not IsInteractionAllowed() or not CanWrite(editBox) then return false, "restricted" end
    if not IsSwitchTargetAvailable(chatType, channelId) then return false, "unavailable-channel" end
    local safe, oldType, oldChannel = ReadEditBox(editBox, true)
    if not safe then return false, "unsafe-input" end
    if type(editBox.SetChatType) ~= "function"
        or (chatType == "CHANNEL" and type(editBox.SetChannelTarget) ~= "function") then
        return false, "missing-method"
    end
    local activateChat = _G.ChatFrameUtil and _G.ChatFrameUtil.ActivateChat or _G.ChatEdit_ActivateChat
    if activate and type(activateChat) ~= "function" then return false, "missing-activation" end
    local applied = true
    if chatType == "CHANNEL" then applied = pcall(editBox.SetChannelTarget, editBox, channelId) end
    if applied then applied = pcall(editBox.SetChatType, editBox, chatType) end
    if applied then applied = UpdateHeader(editBox) end
    if applied and activate then applied = pcall(activateChat, editBox) end
    local actual, actualSafe = ReadMethod(editBox, editBox.GetAttribute, "chatType")
    applied = applied and actualSafe and actual == chatType
    if applied and chatType == "CHANNEL" then
        local actualChannel, channelSafe = ReadMethod(editBox, editBox.GetAttribute, "channelTarget")
        applied = channelSafe and actualChannel == channelId
    end
    if applied then
        suspendedEditBoxes[editBox] = nil
        return true
    end
    local restored = true
    if chatType == "CHANNEL" then restored = pcall(editBox.SetChannelTarget, editBox, oldChannel) end
    restored = pcall(editBox.SetChatType, editBox, oldType) and restored
    restored = UpdateHeader(editBox) and restored
    local restoredType, restoredSafe = ReadMethod(editBox, editBox.GetAttribute, "chatType")
    restored = restored and restoredSafe and restoredType == oldType
    suspendedEditBoxes[editBox] = true
    return false, restored and "switch-failed" or "restore-failed"
end

local function ResolveWhisperExit()
    if HOME_PARTY_CATEGORY == nil or INSTANCE_PARTY_CATEGORY == nil
        or type(IsInGroup) ~= "function" or type(IsInRaid) ~= "function" then return nil end
    local instance, instanceSafe = ReadBoolean(IsInGroup, INSTANCE_PARTY_CATEGORY)
    if not instanceSafe then return nil end
    if instance then return "INSTANCE_CHAT" end
    local raid, raidSafe = ReadBoolean(IsInRaid, HOME_PARTY_CATEGORY)
    if not raidSafe then return nil end
    if raid then return "RAID" end
    local party, partySafe = ReadBoolean(IsInGroup, HOME_PARTY_CATEGORY)
    if not partySafe then return nil end
    return party and "PARTY" or "SAY"
end

local function SelectActiveOwner()
    local selectedId, selected
    for id, owner in pairs(owners) do
        if owner.claimed == true and (not selected
            or owner.priority > selected.priority
            or (owner.priority == selected.priority and id < selectedId))
        then
            selectedId, selected = id, owner
        end
    end
    return selectedId, selected
end

local function EmitOwnerChanged(previousId, nextId)
    if previousId == nextId then return end
    activeOwner = nextId
    if YUI.Event and YUI.Event.Emit then
        YUI.Event:Emit("YUI_CHAT_TAB_OWNER_CHANGED", nextId, previousId)
    end
end

local function RefreshOwner()
    local nextId = SelectActiveOwner()
    EmitOwnerChanged(activeOwner, nextId)
end

local function Cycle(editBox)
    local ownerId, owner = SelectActiveOwner()
    if not ownerId or not owner or owner.enabled ~= true or suspendedEditBoxes[editBox] then return false end
    if not IsInteractionAllowed() or not CanWrite(editBox) then return false end

    local inputSafe, current, channelTarget = ReadEditBox(editBox)
    if not inputSafe then return false end
    local reverse, shiftSafe = ReadBoolean(IsShiftKeyDown)
    if not shiftSafe then return false end
    if current == "WHISPER" or current == "BN_WHISPER" then
        if not YUI.IsRetail or not reverse then return false end
        local target = ResolveWhisperExit()
        if not target then return false end
        return ChatInput.SwitchChannel(editBox, target)
    end
    local targets = BuildTargets()
    if type(targets) ~= "table" or #targets < 1 then return false end

    local selected = 1
    for index = 1, #targets do
        local target = targets[index]
        if target.chatType == current
            and (target.chatType ~= "CHANNEL" or target.channelId == channelTarget)
        then
            selected = index
            break
        end
    end
    selected = reverse and (selected > 1 and selected - 1 or #targets)
        or (selected < #targets and selected + 1 or 1)
    if YUI.IsRetail then
        return ChatInput.SwitchChannel(editBox, targets[selected].chatType, targets[selected].channelId)
    end
    return ApplyTarget(editBox, targets[selected])
end

local function SharedTabHandler(editBox)
    if type(previousHandler) == "function" then
        local ok, handled = pcall(previousHandler, editBox)
        if ok and handled then return handled end
    end
    return Cycle(editBox)
end

local function ResetSuspended()
    suspendedEditBoxes = setmetatable({}, { __mode = "k" })
end

local function AttachLifecycle()
    if lifecycleAttached or not (YUI.Event and YUI.Event.On) then return end
    YUI.Event:On("PLAYER_ENTERING_WORLD", ResetSuspended, lifecycleOwner, { moduleId = "YUI.API.ChatInput" })
    YUI.Event:On("ADDON_RESTRICTION_STATE_CHANGED", ResetSuspended, lifecycleOwner, { moduleId = "YUI.API.ChatInput" })
    YUI.Event:On("CHANNEL_UI_UPDATE", ResetSuspended, lifecycleOwner, { moduleId = "YUI.API.ChatInput" })
    lifecycleAttached = true
end

local function DetachLifecycle()
    if not lifecycleAttached then return end
    if YUI.Event and YUI.Event.OffOwner then YUI.Event:OffOwner(lifecycleOwner) end
    lifecycleAttached = false
end

local function Install()
    if installed then return true end
    previousHandler = _G.ChatEdit_CustomTabPressed
    _G.ChatEdit_CustomTabPressed = SharedTabHandler
    installed = true
    AttachLifecycle()
    return true
end

local function Restore()
    if not installed then return true end
    if _G.ChatEdit_CustomTabPressed == SharedTabHandler then
        _G.ChatEdit_CustomTabPressed = previousHandler
    end
    previousHandler = nil
    installed = false
    DetachLifecycle()
    return true
end

function ChatInput.RegisterTabOwner(id, priority)
    if type(id) ~= "string" or id == "" or type(priority) ~= "number" then
        return false, "invalid_owner"
    end
    local owner = owners[id]
    if not owner then
        owner = { claimed = false, enabled = false }
        owners[id] = owner
    end
    owner.priority = priority
    Install()
    RefreshOwner()
    return true
end

function ChatInput.SetTabOwnerState(id, state)
    local owner = owners[id]
    if not owner or type(state) ~= "table" then return false, "unknown_owner" end
    owner.claimed = state.claimed == true
    owner.enabled = state.enabled == true
    RefreshOwner()
    return true
end

function ChatInput.UnregisterTabOwner(id)
    if not owners[id] then return false, "unknown_owner" end
    owners[id] = nil
    RefreshOwner()
    if next(owners) == nil then Restore() end
    return true
end

function ChatInput.GetTabOwner()
    local id, owner = SelectActiveOwner()
    return id, owner and { priority = owner.priority, claimed = true, enabled = owner.enabled == true } or nil
end

function ChatInput.ResetSuspendedEditBoxes()
    ResetSuspended()
end

-- Returns the valid group chat type without allocating. Home groups take
-- precedence when the player also belongs to an instance group, matching the
-- native chat edit box routing rules. Unknown or unsafe state fails closed.
function ChatInput.ResolveGroupChatType()
    if type(IsInGroup) ~= "function" or type(IsInRaid) ~= "function"
        or HOME_PARTY_CATEGORY == nil or INSTANCE_PARTY_CATEGORY == nil
    then
        return nil
    end

    local inHomeRaid, homeRaidSafe = ReadBoolean(IsInRaid, HOME_PARTY_CATEGORY)
    if not homeRaidSafe then return nil end
    if inHomeRaid then return "RAID" end

    local inHomeGroup, homeGroupSafe = ReadBoolean(IsInGroup, HOME_PARTY_CATEGORY)
    if not homeGroupSafe then return nil end
    if inHomeGroup then return "PARTY" end

    local inInstanceGroup, instanceGroupSafe = ReadBoolean(IsInGroup, INSTANCE_PARTY_CATEGORY)
    if not instanceGroupSafe then return nil end
    if inInstanceGroup then return "INSTANCE_CHAT" end

    return nil
end

-- Validates an already selected group chat type against its exact party
-- category. Instance raids still use INSTANCE_CHAT rather than RAID.
function ChatInput.IsGroupChatTypeAvailable(chatType)
    if not IsSafeValue(chatType) or type(chatType) ~= "string" then return false end

    local callback, category
    if chatType == "PARTY" then
        callback, category = IsInGroup, HOME_PARTY_CATEGORY
    elseif chatType == "RAID" then
        callback, category = IsInRaid, HOME_PARTY_CATEGORY
    elseif chatType == "INSTANCE_CHAT" then
        callback, category = IsInGroup, INSTANCE_PARTY_CATEGORY
    else
        return false
    end

    if category == nil or type(callback) ~= "function" then return false end
    local available, safe = ReadBoolean(callback, category)
    return safe and available == true
end
