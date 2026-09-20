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
if not Sources or YUI.IsRetail ~= true then return end
local KEY, TYPE = 'native-aura-signal:cdm:365362', 'native-aura-signal'
local generation=0
local bindings = setmetatable({}, { __mode = 'k' })
local hooked = setmetatable({}, { __mode = 'k' })
local viewers = setmetatable({}, { __mode = 'k' })
local owners = setmetatable({}, { __mode = 'k' })
local Bind
local LOSS_TASK = 'native-aura-loss'
local function CancelLoss(source)
    source.state.lossFrame = nil
    M:CancelTask(source, LOSS_TASK)
end
local viewerNames = { 'BuffIconCooldownViewer', 'BuffBarCooldownViewer' }
local directIdentityFields = { 'linkedSpellID', 'overrideSpellID', 'overrideTooltipSpellID' }
local function Public(value)
    if type(issecretvalue) == 'function' and issecretvalue(value) then return nil end
    return value
end
local function Call(method, ...)
    if type(method) ~= 'function' then return nil end
    local ok, value = pcall(method, ...)
    if ok then return Public(value) end
end
local function TraceEdge(stage,source,frame)
    local trace=YUI.Sound and YUI.Sound.DebugTiming
    if not (trace and trace.enabled) then return end
    local state=source.state
    local binding=frame and bindings[frame]
    trace:Record(stage,source.params.spellID,trace:Identity(frame),
        binding and trace:Identity(binding.viewer),frame and Public(frame.cooldownID),
        state.sequence,state.present,state.lossFrame~=nil,state.generation,
        state.auraUnit,frame and Call(frame.GetAuraDataUnit,frame))
end
local function ID(frame)
    local id = Public(frame.cooldownID)
    if type(id) == 'number' and id > 0 and id < math.huge and id % 1 == 0 then return id end
end
local function Source(key)
    local source = M.Data.sources[key or KEY]
    return source and source.consumerCount > 0 and source or nil
end
local function Unique(frame, source)
    local info = Call(frame.GetCooldownInfo, frame)
    if type(info) ~= 'table' or Public(info.spellID) ~= (source.params.nativeBase or 365350) then return false end
    local linked, count = Public(info.linkedSpellIDs), 0
    if source.params.nativeDirect then
        if type(issecretvalue)=='function' and issecretvalue(info.linkedSpellIDs) then return false end
        if linked~=nil and type(linked)~='table' then return false end
        if linked and next(linked)~=nil then return false end
        for _,key in ipairs(directIdentityFields) do
            if type(issecretvalue)=='function' and issecretvalue(info[key]) then return false end
            local value=Public(info[key])
            if value~=nil and value~=0 and value~=source.params.spellID then return false end
        end
        return source.params.spellID==source.params.nativeBase
    end
    if type(linked) ~= 'table' then return false end
    for key, value in pairs(linked) do
        if type(Public(key)) ~= 'number' or Public(value) ~= source.params.spellID then return false end
        count = count + 1
        if count > 1 then return false end
    end
    return count == 1
end
local function Invalidate(frame)
    local binding = bindings[frame]
    local source = binding and Source(binding.key)
    if source then TraceEdge('aura-invalidate',source,frame) end
    bindings[frame] = nil
    if source then
        CancelLoss(source)
        source.state.present, source.state.nativeEvent = nil, nil
        source.state.auraUnit = nil
        source.state.issue = 'native-aura-binding-unavailable'
        M:RefreshSourceNow(source, 'native-aura-signal', true)
        M:QueueSource(source, 'native-aura-rebind')
    end
end
local function OnIdentity(frame, _, forceSet)
    local binding = bindings[frame]
    local source = binding and Source(binding.key)
    if source and binding and ID(frame) == binding.id and (Public(forceSet) == false or Unique(frame, source)) then return end
    if binding then Invalidate(frame) end
    local rebound = owners[frame] and Bind(owners[frame],frame)
    if rebound then
        local source=rebound; if source then M:QueueSource(source,'native-aura-rebind') end
    end
end
local function CommitLoss(source)
    local state = source.state
    local frame = state.lossFrame
    TraceEdge('loss-wake',source,frame)
    state.lossFrame = nil
    local binding = frame and bindings[frame]
    if Source(source.key) ~= source or not binding or binding.key ~= source.key
        or binding.generation ~= state.generation then return end
    if ID(frame) ~= binding.id then Invalidate(frame); return end
    if Call(binding.viewer.IsShown, binding.viewer) ~= true then
        state.present, state.nativeEvent, state.issue = nil, nil, 'native-aura-viewer-hidden'
        state.auraUnit = nil
        M:RefreshSourceNow(source, 'native-aura-signal', true)
        return
    end
    if state.present ~= true then return end
    state.sequence = state.sequence + 1
    state.present, state.nativeEvent, state.issue = false, 'auraRemoved', nil
    TraceEdge('loss-commit',source,frame)
    state.auraUnit = nil
    M:RefreshSourceNow(source, 'native-aura-signal', true)
end
local function Edge(frame, present)
    local binding = bindings[frame]
    local source = binding and Source(binding.key)
    if not source or not binding or binding.generation~=source.state.generation then return end
    if ID(frame) ~= binding.id then Invalidate(frame); return end
    local state = source.state
    TraceEdge(present and 'native-gain' or 'native-loss',source,frame)
    if Call(binding.viewer.IsShown, binding.viewer) ~= true then
        CancelLoss(source)
        state.present, state.nativeEvent, state.issue = nil, nil, 'native-aura-viewer-hidden'
        state.auraUnit = nil
        M:RefreshSourceNow(source, 'native-aura-signal', true)
        return
    end
    if present then
        if state.lossFrame then TraceEdge('loss-cancel-by-gain',source,frame) end
        CancelLoss(source)
        -- Keep the observed owner across target changes; the native viewer can
        -- also display target auras, whose baseline must still be discarded.
        state.auraUnit = Call(frame.GetAuraDataUnit, frame)
    else
        -- Native removal precedes replacement gains in the same UNIT_AURA update.
        -- Keep the committed presence until the shared one-shot task settles it.
        if state.present == nil then state.present = false; return end
        if state.present == true and not state.lossFrame then
            state.lossFrame = frame
            -- A due-now task can run before later aura events in this same frame.
            -- Per-rule confirmation delays belong to the sound consumer;
            -- the shared source only coalesces same-frame replacements.
            local ok, code = M:ScheduleTask(source, LOSS_TASK, GetTime() + 0.001, CommitLoss)
            TraceEdge(ok and 'loss-queued' or 'loss-queue-failed',source,frame)
            if not ok then
                state.lossFrame = nil
                state.present, state.nativeEvent, state.issue = nil, nil, code
                M:RefreshSourceNow(source, 'native-aura-signal', true)
            end
        end
        return
    end
    if state.present == present then return end
    state.sequence = state.sequence + 1
    state.present, state.nativeEvent, state.issue = present, present and 'auraAdded' or 'auraRemoved', nil
    M:RefreshSourceNow(source, 'native-aura-signal', true)
end
local function Gain(frame) Edge(frame, true) end
local function Loss(frame) Edge(frame, false) end
Bind = function(viewer, frame, source)
    if not source then
        for _, candidate in pairs(M.Data.sources) do
            if candidate.sourceType.id == TYPE and candidate.consumerCount > 0 then
                local bound = Bind(viewer, frame, candidate)
                if bound then return bound end
            end
        end
        return false
    end
    local combat = YUI.API and YUI.API.Combat
    if not source or not frame or not combat or Call(combat.InCombatLockdown) ~= false then return false end
    if type(hooksecurefunc) ~= 'function'
        or type(frame.TriggerAuraAppliedAlert) ~= 'function' or type(frame.TriggerAuraRemovedAlert) ~= 'function'
        or type(frame.SetCooldownID) ~= 'function' then bindings[frame] = nil; return false end
    owners[frame] = viewer
    local installed = hooked[frame] or {}
    hooked[frame] = installed
    for _, pair in ipairs({ { 'TriggerAuraAppliedAlert', Gain }, { 'TriggerAuraRemovedAlert', Loss }, { 'SetCooldownID', OnIdentity } }) do
        if not installed[pair[1]] then
            local ok = pcall(hooksecurefunc, frame, pair[1], pair[2])
            if not ok then return false end
            installed[pair[1]] = true
        end
    end
    local id = ID(frame)
    if not id or not Unique(frame, source) then
        local old=bindings[frame]
        if old and old.key==source.key then bindings[frame]=nil end
        return false
    end
    local previous=bindings[frame]
    if previous and previous.id==id and previous.viewer==viewer and previous.key==source.key and previous.generation==source.state.generation then return source end
    bindings[frame] = { id = id, viewer = viewer, key = source.key, generation=source.state.generation }
    TraceEdge('aura-bind',source,frame)
    return source
end
local function Acquired(viewer, frame)
    local source=Bind(viewer,frame)
    if source then M:QueueSource(source,'native-aura-rebind') end
end
local function NativeLayoutChanged()
    for _,source in pairs(M.Data.sources) do
        if (source.sourceType.id==TYPE or source.sourceType.id=='native-equipment-aura') and source.consumerCount>0 then
            M:QueueSource(source,'native-aura-layout')
        end
    end
end
local layoutObservers=setmetatable({},{__mode='k'})
local function ObserveLayout(viewer)
    if layoutObservers[viewer] or type(hooksecurefunc)~='function' then return end
    layoutObservers[viewer]=true
    for _,method in ipairs({'RefreshLayout','RefreshData'}) do
        if type(viewer[method])=='function' then pcall(hooksecurefunc,viewer,method,NativeLayoutChanged) end
    end
end
function Sources:RefreshNativeAuraBindings()
    NativeLayoutChanged()
end
local function Read(source, state, reason)
    if reason == 'native-aura-signal' then return true end
    local previousIssue = state.issue
    local found = false
    local combat = YUI.API and YUI.API.Combat
    if not combat or Call(combat.InCombatLockdown) ~= false then return false end
    -- Rebuild membership from the active pool; released frames may retain their old ID.
    for frame,binding in pairs(bindings) do
        if binding.key==source.key then bindings[frame]=nil end
    end
    for _, name in ipairs(viewerNames) do
        local viewer = _G[name]
        if viewer then
            if not viewers[viewer] and type(viewer.OnAcquireItemFrame) == 'function' and type(hooksecurefunc) == 'function' then
                viewers[viewer] = pcall(hooksecurefunc, viewer, 'OnAcquireItemFrame', Acquired) or nil
                ObserveLayout(viewer)
            end
            local pool = viewer.itemFramePool
            if pool and type(pool.EnumerateActive) == 'function' then
                pcall(function()
                    local count = 0
                    for frame in pool:EnumerateActive() do
                        count = count + 1; if count > 256 then break end
                        found = (Bind(viewer, frame, source) and Call(viewer.IsShown, viewer) == true) or found
                    end
                end)
            end
        end
    end
    state.issue = nil
    if not found then state.issue = 'native-aura-binding-unavailable' end
    if not found then CancelLoss(source); state.present, state.nativeEvent, state.auraUnit = nil, nil, nil end
    if state.issue~=previousIssue and YUI.Event and YUI.Event.Emit then YUI.Event:Emit('YUI_MONITOR_SOURCE_STATUS_CHANGED',source.key) end
    return state.issue ~= previousIssue
end
function Sources:DescribeNativeAuraSignal(spellID, unit, event)
    if unit ~= 'cdm' or (event ~= 'auraAdded' and event ~= 'auraRemoved') then return nil end
    local auraID, base, direct = 365362, 365350, false
    if spellID ~= auraID then
        local api = YUI.API and YUI.API.CooldownViewer
        if not api or not api.ReadEntries then return nil end
        local entries = api:ReadEntries({includeHidden=true,allowUnlearned=true})
        local selected
        for index, entry in ipairs(type(entries)=='table' and entries or {}) do
            if index>512 then break end
            if entry.sourceCategory=='trackedBuff' or entry.sourceCategory=='trackedBar' then
                local linked=entry.linkedSpellIDs
                local isDirect=(linked==nil or type(linked)=='table' and #linked==0) and entry.spellID==spellID
                    and (not entry.overrideSpellID or entry.overrideSpellID==spellID)
                    and (not entry.overrideTooltipSpellID or entry.overrideTooltipSpellID==spellID)
                if isDirect or type(linked)=='table' and #linked==1 and
                    (entry.spellID==spellID or linked[1]==spellID) then
                    local candidateAura=isDirect and spellID or linked[1]
                    if selected and (selected.spellID~=entry.spellID or auraID~=candidateAura) then return nil end
                    selected=entry
                    auraID,direct=candidateAura,isDirect
                end
            end
        end
        if not selected then return nil end
        base=selected.spellID
        if type(auraID)~='number' or type(base)~='number' then return nil end
    end
    if not self.nativeAuraSignalRegistered then
        local registered, code = M:RegisterSourceType(TYPE, {
            createState = function() generation=generation+1;return { sequence = 0, generation=generation, issue = 'native-aura-binding-unavailable' } end,
            read = Read, onEvent = function(source, state, event)
                TraceEdge(event,source,nil)
                if event == 'PLAYER_ENTERING_WORLD'
                    or event=='PLAYER_TARGET_CHANGED' and state.auraUnit~='player' then
                    CancelLoss(source)
                    state.present, state.nativeEvent = nil, nil
                    state.auraUnit = nil
                    state.sequence = state.sequence + 1
                    M:RefreshSourceNow(source, 'native-aura-signal', true)
                end
                return true
            end,
            events = { { event = 'PLAYER_ENTERING_WORLD', all = true },
                { event = 'PLAYER_TARGET_CHANGED', all = true },
                { event = 'PLAYER_REGEN_ENABLED', all = true }, { event = 'ADDON_LOADED', all = true },
                { event = 'CVAR_UPDATE', all = true }, { event = 'PLAYER_SPECIALIZATION_CHANGED', all = true } },
        })
        if not registered and code ~= 'source-type-exists' then return nil, code end
        self.nativeAuraSignalRegistered = true
    end
    return { key = 'native-aura-signal:cdm:'..auraID, type = TYPE, params = { spellID = auraID, unit = 'cdm', nativeBase = base, nativeDirect=direct } }
end
-- Equipment presets own a slot, not the item or aura captured during setup.
local EQUIPMENT_TYPE='native-equipment-aura'
local equipmentBindings=setmetatable({},{__mode='k'})
local equipmentHooks=setmetatable({},{__mode='k'})
local equipmentViewers=setmetatable({},{__mode='k'})
local equipmentGeneration=0
local function Equipped(slot)
    local item=YUI.API and YUI.API.Item
    local id=item and Call(item.GetInventoryItemID,'player',slot)
    if type(id)=='number' and id>0 then return id end
end
local function EquipmentIdentity(frame,slot)
    local info=Call(frame.GetCooldownInfo,frame)
    return type(info)=='table' and Public(info.equipSlot)==slot and ID(frame) or nil
end
local function EquipmentEdge(frame,present)
    local b=equipmentBindings[frame]
    local source=b and Source(b.key)
    if not source or source.state.generation~=b.generation then return end
    local state=source.state
    if Equipped(source.params.equipSlot)~=b.itemID or EquipmentIdentity(frame,source.params.equipSlot)~=b.id
        or Call(b.viewer.IsShown,b.viewer)~=true then
        equipmentBindings[frame]=nil
        state.nativeEvent=nil;state.issue='native-aura-binding-unavailable';state.entries[b.id]=nil
        M:RefreshSourceNow(source,'native-equipment-edge',true)
        M:QueueSource(source,'equipment-rebind')
        return
    end
    if state.entries[b.id]==present then return end
    state.entries[b.id]=present
    state.sequence=state.sequence+1;state.nativeEvent=present and 'auraAdded' or 'auraRemoved';state.issue=nil
    M:RefreshSourceNow(source,'native-equipment-edge',true)
end
local function EquipmentGain(frame) EquipmentEdge(frame,true) end
local function EquipmentLoss(frame) EquipmentEdge(frame,false) end
local function EquipmentRebind(frame)
    local b=equipmentBindings[frame]
    if b then
        local source=Source(b.key)
        if source and source.state.generation==b.generation then
            if EquipmentIdentity(frame,source.params.equipSlot)==b.id and Equipped(source.params.equipSlot)==b.itemID then return end
            source.state.entries[b.id]=nil;source.state.nativeEvent=nil
            M:QueueSource(source,'equipment-rebind')
        end
        equipmentBindings[frame]=nil
    end
    for _,source in pairs(M.Data.sources) do
        if source.sourceType.id==EQUIPMENT_TYPE and source.consumerCount>0 then M:QueueSource(source,'equipment-rebind') end
    end
end
local function EquipmentAcquired(viewer,frame)
    local active=false
    for _,source in pairs(M.Data.sources) do if source.sourceType.id==EQUIPMENT_TYPE and source.consumerCount>0 then active=true;break end end
    if not active then return end
    -- Acquisition may precede SetCooldownID; hook once and resolve on the queued read.
    if not equipmentHooks[frame] and type(hooksecurefunc)=='function' and type(frame.SetCooldownID)=='function' then
        equipmentHooks[frame]={identity=pcall(hooksecurefunc,frame,'SetCooldownID',EquipmentRebind)}
    end
    EquipmentRebind(frame)
end
local function ReadEquipment(source,state,reason)
    if reason=='native-equipment-edge' then return true end
    local itemID=Equipped(source.params.equipSlot)
    if state.itemID~=itemID then
        state.itemID=itemID;state.entries={};state.nativeEvent=nil
        for frame,b in pairs(equipmentBindings) do if b.generation==source.state.generation then equipmentBindings[frame]=nil end end
    end
    local combat=YUI.API and YUI.API.Combat
    if not combat or Call(combat.InCombatLockdown)~=false then
        state.nativeEvent=nil;state.issue='native-aura-binding-unavailable';return true
    end
    local previousIssue=state.issue
    local found,activeIDs=false,{}
    for frame,b in pairs(equipmentBindings) do if b.key==source.key then equipmentBindings[frame]=nil end end
    if itemID then
        for _,name in ipairs(viewerNames) do
            local viewer=_G[name]
            if viewer then
                ObserveLayout(viewer)
                if not equipmentViewers[viewer] and type(hooksecurefunc)=='function' and type(viewer.OnAcquireItemFrame)=='function' then
                    equipmentViewers[viewer]=pcall(hooksecurefunc,viewer,'OnAcquireItemFrame',EquipmentAcquired) or nil
                end
                local pool=viewer.itemFramePool
                if pool and type(pool.EnumerateActive)=='function' then
                    pcall(function()
                        local count=0
                        for frame in pool:EnumerateActive() do
                            count=count+1;if count>256 then break end
                            local id=EquipmentIdentity(frame,source.params.equipSlot)
                            if id and type(hooksecurefunc)=='function' then
                                local h=equipmentHooks[frame] or {};equipmentHooks[frame]=h
                                if not h.identity and type(frame.SetCooldownID)=='function' then h.identity=pcall(hooksecurefunc,frame,'SetCooldownID',EquipmentRebind) end
                                if not h.gain and type(frame.TriggerAuraAppliedAlert)=='function' then h.gain=pcall(hooksecurefunc,frame,'TriggerAuraAppliedAlert',EquipmentGain) end
                                if not h.loss and type(frame.TriggerAuraRemovedAlert)=='function' then h.loss=pcall(hooksecurefunc,frame,'TriggerAuraRemovedAlert',EquipmentLoss) end
                                if h.identity and h.gain and h.loss then
                                    equipmentBindings[frame]={key=source.key,generation=state.generation,id=id,itemID=itemID,viewer=viewer}
                                    activeIDs[id]=true
                                    found=Call(viewer.IsShown,viewer)==true or found
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
    for id in pairs(state.entries) do if not activeIDs[id] then state.entries[id]=nil end end
    state.issue=not found and 'native-aura-binding-unavailable' or nil
    if not found then state.nativeEvent=nil end
    if state.issue~=previousIssue and YUI.Event and YUI.Event.Emit then YUI.Event:Emit('YUI_MONITOR_SOURCE_STATUS_CHANGED',source.key) end
    return true
end
function Sources:DescribeEquipmentAura(slot,event)
    if (slot~=13 and slot~=14) or (event~='auraAdded' and event~='auraRemoved') then return nil,'invalid-equipment-aura' end
    if not self.equipmentAuraRegistered then
        local ok,code=M:RegisterSourceType(EQUIPMENT_TYPE,{
            createState=function() equipmentGeneration=equipmentGeneration+1;return {sequence=0,entries={},generation=equipmentGeneration,issue='native-aura-binding-unavailable'} end,
            read=ReadEquipment,
            onEvent=function(source,state,event)
                if event=='PLAYER_EQUIPMENT_CHANGED' or event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_SPECIALIZATION_CHANGED' then
                    state.entries={};state.nativeEvent=nil
                    for frame,b in pairs(equipmentBindings) do if b.generation==source.state.generation then equipmentBindings[frame]=nil end end
                end
                return true
            end,
            events={{event='PLAYER_EQUIPMENT_CHANGED',all=true},{event='PLAYER_ENTERING_WORLD',all=true},
                {event='PLAYER_REGEN_ENABLED',all=true},{event='PLAYER_SPECIALIZATION_CHANGED',all=true},
                {event='CVAR_UPDATE',all=true},{event='ADDON_LOADED',all=true}}
        })
        if not ok and code~='source-type-exists' then return nil,code end
        self.equipmentAuraRegistered=true
    end
    return {key='equipment-aura:player:'..slot,type=EQUIPMENT_TYPE,params={equipSlot=slot,unit='player'}}
end
return Sources
