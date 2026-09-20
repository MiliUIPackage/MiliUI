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
local TYPE = 'native-charge-signal'
local bindings, hooked, viewers = setmetatable({}, {__mode='k'}), setmetatable({}, {__mode='k'}), setmetatable({}, {__mode='k'})
local owners = setmetatable({}, {__mode='k'})
local Bind
local names = {'EssentialCooldownViewer','UtilityCooldownViewer'}
local function Public(value)
    if type(issecretvalue)=='function' and issecretvalue(value) then return nil end
    return value
end
local function Number(value)
    value=Public(value)
    if type(value)=='number' and value==value and value>-math.huge and value<math.huge then return value end
end
local function Call(method,...)
    if type(method)~='function' then return nil end
    local ok,value=pcall(method,...); if ok then return Public(value) end
end
local function Source(key)
    local source=M.Data.sources[key]
    return source and source.consumerCount>0 and source or nil
end
local function Invalidate(frame)
    local binding=bindings[frame]; bindings[frame]=nil
    local source=binding and Source(binding.key)
    if source then source.state.issue='native-charge-unavailable'; M:QueueSource(source,'native-charge-rebind') end
end
local function Spell(frame)
    local info=Call(frame.GetCooldownInfo,frame)
    if type(info)~='table' then return nil end
    local id=Number(info.overrideSpellID) or Number(info.spellID)
    if id and id>0 and id%1==0 then return id end
end
local function Identity(frame,_,force)
    local binding=bindings[frame]
    if binding and (Number(frame.cooldownID)~=binding.id or Public(force)~=false and Spell(frame)~=binding.spell) then Invalidate(frame) end
    if owners[frame] and Bind(owners[frame],frame) then
        local source=Source(bindings[frame].key)
        if source then M:QueueSource(source,'native-charge-rebind') end
    end
end
local function Gain(frame,_,gainTime)
    local binding=bindings[frame]
    local source=binding and Source(binding.key)
    if not source then return end
    if Number(frame.cooldownID)~=binding.id then Invalidate(frame); return end
    if Call(binding.viewer.IsShown,binding.viewer)~=true then source.state.issue='native-charge-unavailable'; return end
    local time=Number(gainTime)
    if not time or time>GetTime() or time==source.state.gainTime then return end
    source.state.sequence=source.state.sequence+1
    source.state.gainTime,source.state.issue=time,nil
    M:RefreshSourceNow(source,'native-charge-gained',true)
end
Bind=function(viewer,frame)
    if not frame or Call(InCombatLockdown)~=false then return false end
    if type(hooksecurefunc)~='function' or type(frame.AddChargeGainedAlertTime)~='function' or type(frame.SetCooldownID)~='function' then return false end
    owners[frame]=viewer
    local installed=hooked[frame] or {}; hooked[frame]=installed
    if not installed.gain then installed.gain=pcall(hooksecurefunc,frame,'AddChargeGainedAlertTime',Gain) end
    if not installed.identity then installed.identity=pcall(hooksecurefunc,frame,'SetCooldownID',Identity) end
    if not installed.gain or not installed.identity then return false end
    local spell,id=Spell(frame),Number(frame.cooldownID)
    if not spell or not id then bindings[frame]=nil; return false end
    local key='native-charge:player:'..spell
    if not Source(key) then bindings[frame]=nil; return false end
    local previous=bindings[frame]
    if previous and previous.key==key and previous.id==id and previous.viewer==viewer then return true end
    bindings[frame]={key=key,spell=spell,id=id,viewer=viewer}
    return true
end
local function Acquired(viewer,frame)
    if Bind(viewer,frame) then
        local source=Source(bindings[frame].key)
        if source then M:QueueSource(source,'native-charge-rebind') end
    end
end
local function Read(source,state,reason)
    if reason=='native-charge-gained' then return true end
    if Call(InCombatLockdown)~=false then return false end
    local found=false
    for _,name in ipairs(names) do
        local viewer=_G[name]
        if viewer then
            if not viewers[viewer] and type(viewer.OnAcquireItemFrame)=='function' and type(hooksecurefunc)=='function' then
                viewers[viewer]=pcall(hooksecurefunc,viewer,'OnAcquireItemFrame',Acquired) or nil
            end
            local pool=viewer.itemFramePool
            if pool and type(pool.EnumerateActive)=='function' then
                pcall(function()
                    local count=0
                    for frame in pool:EnumerateActive() do
                        count=count+1; if count>256 then break end
                        if Bind(viewer,frame) and bindings[frame].key==source.key and Call(viewer.IsShown,viewer)==true then found=true end
                    end
                end)
            end
        end
    end
    local issue=not found and 'native-charge-unavailable' or nil
    local changed=state.issue~=issue; state.issue=issue
    return changed
end
function Sources:DescribeNativeCharge(spellID,unit)
    if not Number(spellID) or spellID<1 or spellID%1~=0 or unit~='player' then return nil,'native-charge-unavailable' end
    if not self.nativeChargeRegistered then
        local registered,code=M:RegisterSourceType(TYPE,{createState=function() return {sequence=0,issue='native-charge-unavailable'} end,
            read=Read,onEvent=function(source,state,event)
                if event=='PLAYER_ENTERING_WORLD' then state.gainTime=nil end
                return true
            end,
            events={{event='PLAYER_ENTERING_WORLD',all=true},{event='PLAYER_REGEN_ENABLED',all=true},
                {event='ADDON_LOADED',all=true},{event='CVAR_UPDATE',all=true},
                {event='PLAYER_SPECIALIZATION_CHANGED',all=true}}})
        if not registered and code~='source-type-exists' then return nil,code end
        self.nativeChargeRegistered=true
    end
    return {key='native-charge:player:'..spellID,type=TYPE,params={spellID=spellID,unit=unit}}
end
return Sources
