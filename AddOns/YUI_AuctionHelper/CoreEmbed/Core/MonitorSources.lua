do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
YUI = YUI or _G.YUI
if not (YUI and YUI.Monitor) then return end
local Monitor = YUI.Monitor
local Sources = Monitor.CommonSources or {}
Monitor.CommonSources = Sources
local Item = YUI.API and YUI.API.Item
local Spell = YUI.API and YUI.API.Spell
local SLOT_SOURCE_TYPE = "yhud.inventory-slot-cooldown"
local SPELL_SOURCE_TYPE = "spell-cooldown"
local ITEM_SOURCE_TYPE = "item-cooldown"
local GLOBAL_RECOVERY_CATEGORY = Constants and Constants.SpellCooldownConsts
    and Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY or 133
local function SafeNumber(value)
    local security = YUI.API and YUI.API.Security
    if security and security.SafeNumber then return security.SafeNumber(value) end
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return type(value) == "number" and value or nil
end

local function WakeCooldown(source)
    source.cooldownWakeAt = nil
    if source.consumerCount > 0 then
        Monitor:RefreshSourceNow(source, 'cooldown-deadline', true)
    end
end

local function ScheduleCooldownRead(source, state)
    if not Monitor.ScheduleTask or source.consumerCount <= 0 then return end
    local start, duration = SafeNumber(state.startTime), SafeNumber(state.duration)
    local dueAt
    if state.secret ~= true and state.available == true and state.isEnabled ~= false
        and state.isEnabled ~= 0 and start and duration and duration > 0 then
        local ending = start + duration
        if ending > GetTime() and ending < math.huge then dueAt = ending end
    end
    if source.cooldownWakeAt == dueAt then return end
    source.cooldownWakeAt = dueAt
    if dueAt then
        local ok, code = Monitor:ScheduleTask(source, 'cooldown', dueAt, WakeCooldown)
        if not ok then source.cooldownWakeAt, source.scheduleIssue = nil, code end
    else
        Monitor:CancelTask(source, 'cooldown')
    end
end

local function CreateSlotState(params)
    return {
        sourceKind = "slot",
        slotID = params.slotID,
        itemID = nil,
        icon = nil,
        startTime = 0,
        duration = 0,
        isEnabled = false,
        available = false,
        secret = false,
    }
end

local function ReadInventorySlot(source, state, reason)
    local _, changed = Item.ReadActiveInventorySlotCooldown(
        "player",
        source.params.slotID,
        state,
        reason == "slot-item-data"
    )
    return changed == true
end

local function GetSlotIdentity(params)
    return params.slotID
end

local function CreateSpellState(params)
    return {
        sourceKind = "spell",
        spellID = params.spellID,
        chargeSpellID = params.chargeSpellID or params.spellID,
        hasChargesHint = params.hasCharges == true,
        hasCharges = params.hasCharges == true,
        icon = nil,
        isEnabled = true,
        available = false,
        secret = false,
        cooldownActive = false,
        cooldownStateSecret = false,
        chargeActive = false,
        chargeStateSecret = false,
        chargeCountSecret = false,
        chargeMetadataSecret = false,
        currentCharges = nil,
        maxCharges = nil,
        castCount = nil,
        castCountSecret = false,
        displayCount = nil,
        displayCountRaw = nil,
        countSecret = false,
        activationOverlay = false,
        durationMode = "none",
        durationObject = nil,
        opaqueRevision = 0,
        cooldownDisplayInitialized = false,
    }
end

local function CaptureSpellReadyStart(source)
    if not YUI.IsRetail or not source.readyConsumers or source.readyConsumers <= 0 then return end
    local active, resolved = Spell.ReadCooldownRuleState(source.params.spellID)
    if resolved == true and active == true then
        local state = source.state
        state.readyStartSequence = (state.readyStartSequence or 0) + 1
        state.readyStartSpellID = source.params.spellID
        source.readyStartDirty = true
    end
end

local function ReadSpellCooldown(source, state, reason)
    if reason == "spell-activation" and Spell.ReadActivationOverlay then
        local _, changed = Spell.ReadActivationOverlay(
            source.params.spellID,
            state
        )
        return changed == true
    end
    local _, changed = Spell.ReadCooldownDisplay(
        source.params.spellID,
        state,
        reason,
        source.params.chargeSpellID,
        source.params.hasCharges == true or state.hasCharges == true
    )
    local captured = source.readyStartDirty == true
    source.readyStartDirty = nil
    return changed == true or captured
end

local function GetSpellIdentity(params)
    if type(params.identities) == "table" and #params.identities > 0 then
        return params.identities
    end
    return params.spellID
end

local function ClearSpellTransient(_, state)
    state.durationObject = nil
    state.displayCountRaw = nil
end

local function CreateItemState(params)
    local familyStates = {}
    local candidateCount = #(type(params.itemIDs) == "table"
        and params.itemIDs or {})
    if candidateCount < 1 then candidateCount = 1 end
    for index = 1, candidateCount do
        familyStates[index] = {}
    end
    return {
        sourceKind = "item",
        itemID = params.itemID,
        icon = nil,
        startTime = 0,
        duration = 0,
        isEnabled = true,
        available = false,
        resolved = false,
        secret = false,
        displayCount = nil,
        cooldownActive = false,
        familyStates = familyStates,
        ownedMembers = params.selectionPolicy and {} or nil,
    }
end

local function IsItemCooldownEnabled(value)
    return value ~= false and value ~= 0
end

local function ProjectItemCooldownState(
    state,
    itemID,
    candidate,
    count
)
    local secret = candidate and candidate.secret == true
    local enabled = not secret
        and IsItemCooldownEnabled(candidate and candidate.isEnabled)
    local startTime = enabled and candidate.startTime or 0
    local duration = enabled and candidate.duration or 0
    local resolved = not secret and count ~= nil and candidate.cooldownResolved ~= false
    local available = resolved and count and count > 0 or false
    local displayCount = available and count or nil
    local cooldownActive = resolved and available and enabled
        and type(duration) == "number" and duration > 0
    local icon = candidate and candidate.icon or nil
    local changed = state.itemID ~= itemID
        or state.icon ~= icon
        or state.startTime ~= startTime
        or state.duration ~= duration
        or state.isEnabled ~= enabled
        or state.available ~= available
        or state.resolved ~= resolved
        or state.secret ~= secret
        or state.displayCount ~= displayCount
        or state.cooldownActive ~= cooldownActive

    state.itemID = itemID
    state.icon = icon
    state.startTime = startTime
    state.duration = duration
    state.isEnabled = enabled
    state.available = available
    state.resolved = resolved
    state.secret = secret
    state.displayCount = displayCount
    state.cooldownActive = cooldownActive
    return changed
end

local function ReadItemCooldown(source, state)
    local itemIDs = source.params.itemIDs
    local primaryID = source.params.itemID
    local chosenItemID = primaryID
    local chosenState
    local chosenCount
    local hasDemonicHealthstone
    local hasClassicHealthstone
    if type(itemIDs) == "table" and #itemIDs > 1 then
        local activeItemID
        local activeState
        local activeCount
        local ownedItemID
        local ownedState
        local ownedCount
        for index = 1, #itemIDs do
            local itemID = tonumber(itemIDs[index])
            if itemID then
                if itemID == 224464 then
                    hasDemonicHealthstone = true
                elseif itemID == 5512 then
                    hasClassicHealthstone = true
                end
                local candidate = state.familyStates[index]
                Item.ReadItemCooldown(itemID, candidate)
                local count = Item.GetCount
                    and SafeNumber(Item.GetCount(itemID, false, true))
                    or nil
                if not ownedItemID and count and count > 0 then
                    ownedItemID = itemID
                    ownedState = candidate
                    ownedCount = count
                end
                if not activeItemID and count and count > 0
                    and candidate.secret ~= true
                    and IsItemCooldownEnabled(candidate.isEnabled)
                    and candidate.duration > 0 then
                    activeItemID = itemID
                    activeState = candidate
                    activeCount = count
                end
            end
        end
        local preferOwned = hasDemonicHealthstone and hasClassicHealthstone
        if preferOwned and ownedItemID then
            chosenItemID = ownedItemID
            chosenState = ownedState
            chosenCount = ownedCount
        elseif activeItemID then
            chosenItemID = activeItemID
            chosenState = activeState
            chosenCount = activeCount
        elseif ownedItemID then
            chosenItemID = ownedItemID
            chosenState = ownedState
            chosenCount = ownedCount
        end
    end
    if chosenState then
        return ProjectItemCooldownState(
            state,
            chosenItemID,
            chosenState,
            chosenCount
        )
    end
    local fallbackItemID = hasDemonicHealthstone
            and hasClassicHealthstone
            and 5512
        or primaryID
    local candidate = state.familyStates[1]
    Item.ReadItemCooldown(fallbackItemID, candidate)
    local count = Item.GetCount
        and SafeNumber(Item.GetCount(fallbackItemID, false, true))
        or nil
    return ProjectItemCooldownState(
        state,
        fallbackItemID,
        candidate,
        count
    )
end

-- Conservative grouped policy: all owned members must have public cooldowns.
-- It deliberately makes no assumption that the category shares one cooldown.
local function ReadItemGroup(source, state)
    local owned, unknown, earliest, selected, total = state.ownedMembers, false, nil, nil, 0
    local ownedCount, membershipChanged = 0, false
    local now = GetTime()
    for index, itemID in ipairs(source.params.itemIDs) do
        local candidate = state.familyStates[index]
        Item.ReadItemCooldown(itemID, candidate)
        local count = Item.GetCount and SafeNumber(Item.GetCount(itemID, false, true))
        if not count then unknown = true
        elseif count > 0 then
            ownedCount = ownedCount + 1
            if owned[ownedCount] ~= itemID then membershipChanged = true; owned[ownedCount] = itemID end
            total = total + count
            local start, duration = SafeNumber(candidate.startTime), SafeNumber(candidate.duration)
            if candidate.cooldownResolved == false or candidate.secret == true or candidate.isEnabled == false or candidate.isEnabled == 0
                or candidate.isEnabled == nil or not start or not duration then unknown = true
            elseif duration > 0 and start + duration > now then
                if not earliest or start + duration < earliest then earliest, selected = start + duration, candidate end
            end
        end
    end
    for index = #owned, ownedCount + 1, -1 do owned[index] = nil; membershipChanged = true end
    local identity = (state.groupIdentity or 0) + (membershipChanged and 1 or 0)
    local available = ownedCount > 0 and not unknown
    local active = available and earliest ~= nil
    local start, duration = active and selected.startTime or 0, active and selected.duration or 0
    local changed = state.groupIdentity ~= identity or state.available ~= available
        or state.cooldownActive ~= active or state.secret ~= unknown or state.startTime ~= start
        or state.duration ~= duration or state.displayCount ~= total
    state.groupIdentity, state.available, state.secret = identity, available, unknown
    state.cooldownActive, state.startTime, state.duration = active, start, duration
    state.displayCount, state.isEnabled, state.resolved = total, not unknown, not unknown
    return changed
end

function Sources:DescribeItemGroup(ids, policy)
    if policy ~= 'all-owned-ready' or type(ids) ~= 'table' or #ids < 1 or #ids > 64 then
        return nil, 'invalid-item-group'
    end
    local normalized, seen = {}, {}
    for _, id in ipairs(ids) do
        id = SafeNumber(id)
        if not id or id <= 0 or id >= math.huge or id % 1 ~= 0 then return nil, 'invalid-item-group' end
        if not seen[id] then normalized[#normalized + 1], seen[id] = id, true end
    end
    table.sort(normalized)
    local key = 'item-group:' .. policy .. ':' .. table.concat(normalized, ',')
    return { key = key, type = 'item-group', params = { itemIDs = normalized,
        itemID = normalized[1], selectionPolicy = policy, signature = key } }
end

function Sources:RegisterItemGroupSourceType()
    if self.itemGroupSourceTypeRegistered then return true end
    if not (Item and Item.ReadItemCooldown and Item.GetCount) then return nil, 'item-api-unavailable' end
    local sourceType, code = Monitor:RegisterSourceType('item-group', {
        createState = CreateItemState, read = ReadItemGroup, afterDispatch = ScheduleCooldownRead,
        events = { { event = 'BAG_UPDATE_DELAYED', all = true },
            { event = 'BAG_UPDATE_COOLDOWN', all = true }, { event = 'PLAYER_REGEN_ENABLED', all = true } },
    })
    if not sourceType and code ~= 'source-type-exists' then return nil, code end
    self.itemGroupSourceTypeRegistered = true
    return true
end

local function GetItemIdentity(params)
    return params.itemID
end

function Sources:RegisterSlotSourceType()
    if self.slotSourceTypeRegistered then return true end
    if not (Item and Item.ReadActiveInventorySlotCooldown) then
        return nil, "item-api-unavailable"
    end
    local sourceType, code = Monitor:RegisterSourceType(SLOT_SOURCE_TYPE, {
        createState = CreateSlotState,
        getIdentity = GetSlotIdentity,
        read = ReadInventorySlot,
        afterDispatch = ScheduleCooldownRead,
        events = {
            { event = "PLAYER_EQUIPMENT_CHANGED", identityArg = 1 },
            { event = "BAG_UPDATE_COOLDOWN", all = true },
            {
                event = "ITEM_DATA_LOAD_RESULT",
                all = true,
                reason = "slot-item-data",
            },
        },
    })
    if not sourceType and code ~= "source-type-exists" then
        return nil, code
    end
    self.slotSourceTypeRegistered = true
    return true
end

function Sources:RegisterSpellSourceType()
    if self.spellSourceTypeRegistered then return true end
    if not (Spell and Spell.ReadCooldownDisplay) then
        return nil, "spell-api-unavailable"
    end
    local sourceType, code = Monitor:RegisterSourceType(SPELL_SOURCE_TYPE, {
        createState = CreateSpellState,
        getIdentity = GetSpellIdentity,
        -- Mixed spell domains must not discard a charge/uses/completion update.
        coalescedReason = "spell-refresh",
        read = ReadSpellCooldown,
        afterDispatch = ClearSpellTransient,
        events = {
            {
                event = "SPELL_UPDATE_COOLDOWN",
                capture = CaptureSpellReadyStart,
                identityArgs = { 1, 2 },
                identityReason = "spell-update",
                allWhenIdentityMissing = true,
                missingAllReason = "spell-all",
                allWhenArgEquals = {
                    arg = 4,
                    value = GLOBAL_RECOVERY_CATEGORY,
                },
                matchAllReason = "spell-global",
            },
            {
                event = "SPELL_UPDATE_CHARGES",
                all = true,
                reason = "spell-charge-all",
            },
            {
                event = "SPELL_UPDATE_USES",
                identityArgs = { 1, 2 },
                identityReason = "spell-uses",
            },
            {
                event = "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
                identityArg = 1,
                identityReason = "spell-activation",
            },
            {
                event = "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
                identityArg = 1,
                identityReason = "spell-activation",
            },
            {
                event = "SPELL_UPDATE_ICON",
                identityArg = 1,
                identityReason = "spell-identity",
            },
            {
                event = "LEARNED_SPELL_IN_SKILL_LINE",
                identityArgs = { 1, 2 },
                identityReason = "spell-learned",
            },
            {
                event = "PLAYER_SPECIALIZATION_CHANGED",
                all = true,
                reason = "spell-identity",
            },
            {
                event = "TRAIT_CONFIG_UPDATED",
                all = true,
                reason = "spell-identity",
            },
        },
    })
    if not sourceType and code ~= "source-type-exists" then
        return nil, code
    end
    self.spellSourceTypeRegistered = true
    return true
end

function Sources:RegisterItemSourceType()
    if self.itemSourceTypeRegistered then return true end
    if not (Item and Item.ReadItemCooldown) then
        return nil, "item-api-unavailable"
    end
    local sourceType, code = Monitor:RegisterSourceType(ITEM_SOURCE_TYPE, {
        createState = CreateItemState,
        getIdentity = GetItemIdentity,
        read = ReadItemCooldown,
        afterDispatch = ScheduleCooldownRead,
        events = {
            {
                event = "BAG_UPDATE",
                all = true,
                reason = "item-count",
            },
            {
                event = "BAG_UPDATE_COOLDOWN",
                all = true,
                reason = "item-cooldown",
            },
            {
                event = "PLAYER_REGEN_ENABLED",
                all = true,
                reason = "item-combat-ended",
            },
        },
    })
    if not sourceType and code ~= "source-type-exists" then
        return nil, code
    end
    self.itemSourceTypeRegistered = true
    return true
end


return Sources
