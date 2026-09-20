do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
local M=YUI and YUI.Monitor
local Sources=M and M.CommonSources
if not Sources or YUI.IsRetail~=true then return end
local TYPE='native-totem-signal'
local supported={[2484]=true,[5394]=true,[8143]=true,[98008]=true,[192058]=true,
    [192077]=true,[204331]=true,[204336]=true,[355580]=true,[383013]=true}
local bindings=setmetatable({},{__mode='k'})
local hooks=setmetatable({},{__mode='k'})
local viewers=setmetatable({},{__mode='k'})
local generation=0
local function Public(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
local function Call(fn,...)
    if type(fn)~='function' then return nil end
    local ok,v=pcall(fn,...)
    if ok then return Public(v) end
end
local function Source(b)
    local s=b and M.Data.sources[b.key]
    if s and s.consumerCount>0 and s.state.generation==b.generation then return s end
end
local function Identity(frame,spellID)
    local id=Public(frame.cooldownID)
    local info=Call(frame.GetCooldownInfo,frame)
    if type(info)~='table' or (issecrettable and issecrettable(info)) then return nil end
    if type(id)=='number' and Public(info.spellID)==spellID then return id end
end
local function Invalidate(frame,why)
    local b=bindings[frame]; bindings[frame]=nil
    local s=Source(b)
    if not s then return end
    s.state.present=nil;s.state.nativeEvent=nil;s.state.issue=why or 'native-totem-unavailable'
    s.frame=nil;s.viewer=nil
    M:RefreshSourceNow(s,'totem-edge',true)
end
local function Active(frame)
    local b=bindings[frame];local s=Source(b)
    if not s then bindings[frame]=nil;return end
    if Public(frame.cooldownID)~=b.id or Call(b.viewer.IsShown,b.viewer)~=true then Invalidate(frame);return end
    local value=Call(frame.IsActive,frame)
    if type(value)~='boolean' then Invalidate(frame);return end
    local old=s.state.present
    if old==value then return end
    s.state.present=value;s.state.issue=nil;s.state.nativeEvent=nil
    if type(old)=='boolean' then
        s.state.sequence=s.state.sequence+1
        s.state.nativeEvent=value and 'totemAdded' or 'totemRemoved'
    end
    M:RefreshSourceNow(s,'totem-edge',true)
end
local Bind
local function Rebind(frame)
    local b=bindings[frame];Invalidate(frame)
    if b then
        local s=Source(b)
        if s then M:QueueSource(s,'totem-rebind') end
    end
end
local function Hidden(viewer)
    for frame,b in pairs(bindings) do if b.viewer==viewer then Invalidate(frame,'native-totem-viewer-hidden') end end
end
local function Acquired(viewer,frame)
    -- Acquisition can precede SetCooldownID. Watch identity without guessing a spell.
    if type(frame.SetCooldownID)=='function' and not hooks[frame] then
        local ok=pcall(hooksecurefunc,frame,'SetCooldownID',function(item)
            Rebind(item)
            local sourceType=M.Data.types and M.Data.types[TYPE]
            for _,s in pairs(sourceType and sourceType.sources or {}) do M:QueueSource(s,'totem-acquired') end
        end)
        if ok then hooks[frame]={identity=true} end
    end
    local sourceType=M.Data.types and M.Data.types[TYPE]
    for _,s in pairs(sourceType and sourceType.sources or {}) do M:QueueSource(s,'totem-acquired') end
end
Bind=function(s,viewer,frame)
    local id=Identity(frame,s.params.spellID)
    if not id or Call(viewer.IsShown,viewer)~=true then return false end
    if type(frame.SetIsActive)~='function' or type(frame.SetCooldownID)~='function' then return false end
    Acquired(viewer,frame)
    local h=hooks[frame] or {};hooks[frame]=h
    if not h.active then h.active=pcall(hooksecurefunc,frame,'SetIsActive',Active) end
    if not h.active or not h.identity then return false end
    local active=Call(frame.IsActive,frame)
    if type(active)~='boolean' then return false end
    bindings[frame]={key=s.key,generation=s.state.generation,id=id,viewer=viewer}
    s.frame=frame;s.viewer=viewer
    s.state.present=active;s.state.nativeEvent=nil;s.state.issue=nil
    return true
end
local function Read(s,state,reason)
    if reason=='totem-edge' then return true end
    local b=s.frame and bindings[s.frame]
    if b and Source(b)==s and Public(s.frame.cooldownID)==b.id and Call(s.viewer.IsShown,s.viewer)==true then return false end
    if s.frame then bindings[s.frame]=nil;s.frame=nil;s.viewer=nil end
    state.present=nil;state.nativeEvent=nil;state.issue='native-totem-unavailable'
    if Call(YUI.API.Combat.InCombatLockdown)~=false then return true end
    for _,name in ipairs({'BuffIconCooldownViewer','BuffBarCooldownViewer'}) do
        local viewer=_G[name];local pool=viewer and viewer.itemFramePool
        if pool and type(pool.EnumerateActive)=='function' and type(hooksecurefunc)=='function' then
            if not viewers[viewer] then
                if type(viewer.HookScript)=='function' then
                    viewer:HookScript('OnHide',Hidden)
                    viewer:HookScript('OnShow',function(owner) Acquired(owner,{}) end)
                    if type(viewer.OnAcquireItemFrame)=='function' then pcall(hooksecurefunc,viewer,'OnAcquireItemFrame',Acquired) end
                    viewers[viewer]=true
                end
            end
            if viewers[viewer] then
                local ok,found=pcall(function()
                    local count=0
                    for frame in pool:EnumerateActive() do
                        count=count+1;if count>256 then break end
                        if Bind(s,viewer,frame) then return true end
                    end
                end)
                if ok and found then return true end
            end
        end
    end
    return true
end
function Sources:DescribeTotem(spellID,event)
    if not supported[spellID] or (event~='totemAdded' and event~='totemRemoved') then return nil,'invalid-totem' end
    if not self.totemSignalRegistered then
        local ok,why=M:RegisterSourceType(TYPE,{
            createState=function() generation=generation+1;return {sequence=0,generation=generation,issue='native-totem-unavailable'} end,
            read=Read,onEvent=function(s,state,event)
                if event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_SPECIALIZATION_CHANGED' then
                    if s.frame then bindings[s.frame]=nil;s.frame=nil;s.viewer=nil end
                    state.present=nil;state.nativeEvent=nil
                end
                return true
            end,
            events={{event='PLAYER_REGEN_ENABLED',all=true},{event='PLAYER_ENTERING_WORLD',all=true},
                {event='PLAYER_SPECIALIZATION_CHANGED',all=true},{event='ADDON_LOADED',all=true},{event='CVAR_UPDATE',all=true}},
        })
        if not ok and why~='source-type-exists' then return nil,why end
        self.totemSignalRegistered=true
    end
    return {key='totem:player:'..spellID,type=TYPE,params={spellID=spellID,unit='player'}}
end
