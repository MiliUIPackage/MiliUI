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
if not Sources then return end
local function Public(value)
    if type(issecretvalue)=='function' and issecretvalue(value) then return nil end
    return value
end
local function Clear(source)
    M:CancelTasks(source)
    source.timers=nil
    source.timerCount=0
end
local function Read(source)
    local changed=source.timerDirty==true
    source.timerDirty=nil
    return changed
end
local function EndTimer(source,key)
    local timer=source.timers and source.timers[key]
    if not timer then return end
    source.timers[key]=nil; source.timerCount=source.timerCount-1
    local state=source.state
    state.sequence=state.sequence+1
    state.phase,state.timerID,state.startedAt,state.endsAt='ended',key,timer.startedAt,timer.endsAt
    source.timerDirty=true
    M:RefreshSourceNow(source,'cast-timer-ended',true)
end
local function Receive(source,state,event,unit,guid,spellID)
    if event~='UNIT_SPELLCAST_SUCCEEDED' then
        Clear(source)
        state.sequence=state.sequence+1; state.phase='reset'; state.timerID=nil
        state.startedAt,state.endsAt,state.castGUID=nil,nil,nil
        source.timerDirty=true
        return true
    end
    local params=source.params
    unit,guid,spellID=Public(unit),Public(guid),Public(spellID)
    if unit~=params.unit or spellID~=params.spellID or type(guid)~='string' or guid=='' or guid==state.castGUID then return false end
    state.castGUID=guid
    if params.policy=='ignore' and (source.timerCount or 0)>0 then return false end
    if params.policy=='restart' then Clear(source) end
    if (source.timerCount or 0)>=32 then state.issue='timer-capacity'; return false end
    local now=GetTime()
    source.timerSerial=(source.timerSerial or 0)+1
    local key=tostring(source.timerSerial)
    local timer={startedAt=now,endsAt=now+params.duration}
    local scheduled,code=M:ScheduleTask(source,key,timer.endsAt,EndTimer)
    if not scheduled then
        state.issue=code
        if params.policy=='restart' then
            -- The old source timer was already cancelled. Notify consumers so
            -- their remaining-time tasks are cancelled in the same event.
            state.sequence=state.sequence+1; state.phase='reset'; state.timerID=nil
            state.startedAt,state.endsAt=nil,nil
            source.timerDirty=true
            return true
        end
        return false
    end
    source.timers=source.timers or {}; source.timers[key]=timer
    source.timerCount=(source.timerCount or 0)+1
    state.sequence=state.sequence+1; state.phase='started'; state.timerID=key
    state.startedAt,state.endsAt,state.issue=now,timer.endsAt,nil
    source.timerDirty=true
    return true
end

function Sources:DescribeCastTimer(spellID,unit,duration,policy)
    spellID,unit,duration,policy=Public(spellID),Public(unit),Public(duration),Public(policy)
    if type(spellID)~='number' or spellID<=0 or spellID>=math.huge or spellID%1~=0
        or (unit~='player' and unit~='target' and unit~='focus')
        or type(duration)~='number' or duration~=duration or duration<=0 or duration>86400
        or (policy~='ignore' and policy~='restart' and policy~='parallel') then return nil,'invalid-cast-timer' end
    return {key='cast-timer:'..unit..':'..spellID..':'..duration..':'..policy,type='cast-timer',
        params={spellID=spellID,unit=unit,duration=duration,policy=policy}}
end
function Sources:RegisterCastTimerSourceType()
    if self.castTimerRegistered then return true end
    local sourceType,code=M:RegisterSourceType('cast-timer',{
        createState=function() return {sequence=0,phase='idle'} end,
        read=Read,onEvent=Receive,
        -- The event has no duration/policy identity. Filter in Receive so one
        -- stable type covers all bounded timer configurations without creating
        -- a permanently retained source type for every edited duration.
        events={{event='UNIT_SPELLCAST_SUCCEEDED',units={'player','target','focus'},all=true,synchronous=true},
            {event='PLAYER_ENTERING_WORLD',all=true,synchronous=true},
            {event='PLAYER_DEAD',all=true,synchronous=true}},
    })
    if not sourceType and code~='source-type-exists' then return nil,code end
    self.castTimerRegistered=true
    return true
end
-- Built-in event window shared by visual and sound consumers. This is not an aura.
local WINDOW_TYPE = 'yhud.spell-event-window'
local function EndWindow(source)
    M:RefreshSourceNow(source,'spell-event-window-expired',true)
end
local function WindowRead(source,state,reason)
    if reason=='spell-event-window-trigger' then
        M:CancelTasks(source)
        local now=GetTime()
        local ok,code=M:ScheduleTask(source,'window-end',now+source.params.durationSeconds,EndWindow)
        state.sequence=state.sequence+1
        state.issue=not ok and code or nil
        state.phase=ok and 'started' or 'reset'
        state.startTime=ok and now or 0
        state.available=ok==true
        return true
    end
    if reason=='PLAYER_DEAD' or reason=='PLAYER_ENTERING_WORLD' then
        M:CancelTasks(source)
        state.sequence=state.sequence+1;state.phase='reset';state.available=false;state.startTime=0
        return true
    end
    if state.available and GetTime()>=state.startTime+state.duration then
        state.sequence=state.sequence+1;state.phase='ended';state.available=false;state.startTime=0
        return true
    end
    return false
end
function Sources:RegisterSpellEventWindowSourceType()
    if self.eventWindowRegistered then return true end
    local registered,code=M:RegisterSourceType(WINDOW_TYPE,{
        createState=function(params) return {sourceKind='spell-event-window',spellID=params.spellID,
            icon=params.icon,startTime=0,duration=params.durationSeconds,isEnabled=true,
            available=false,resolved=true,secret=false,sequence=0,phase='idle'} end,
        getIdentity=function(params) return params.triggerSpellIDs end,
        read=WindowRead,
        events={{event='SPELL_UPDATE_COOLDOWN',identityArgs={1,2},identityReason='spell-event-window-trigger',synchronous=true},
            {event='PLAYER_ENTERING_WORLD',all=true,synchronous=true},
            {event='PLAYER_DEAD',all=true,synchronous=true}},
    })
    if not registered and code~='source-type-exists' then return nil,code end
    self.eventWindowRegistered=true
    return true
end
-- The gain sound is registered directly on aura 1265968. Only the delayed
-- ending consumes this existing visual window; it never represents aura loss.
function Sources:DescribeBoilingPoint()
    if not YUI.IsRetail then return nil,'unsupported-client' end
    local ok,code=self:RegisterSpellEventWindowSourceType()
    if not ok then return nil,code end
    return {key='spell-event-window:1265982',type=WINDOW_TYPE,
        params={spellID=50842,triggerSpellIDs={1265982},durationSeconds=3,
            icon=YUI.API and YUI.API.Spell and YUI.API.Spell.GetTexture and YUI.API.Spell.GetTexture(50842)}}
end
-- Bone Shield is a cast-based estimate, not a readable aura expiration time.
local function BoneRead(source,state)
    local changed=Read(source)
    if source.boneDead then return changed end
    if not source.boneAuraDirty and source.initialized then return changed end
    source.boneAuraDirty=nil
    local api=YUI.API and YUI.API.CooldownViewer
    local active,frame,id
    if api and api.ReadAuraActivation then
        active,frame,id=api:ReadAuraActivation(219786,source.boneFrame,source.boneFrameID)
    end
    local issue=active==nil and 'bone-shield-cdm-unavailable' or nil
    if state.stackIssue~=issue then
        changed=true;state.stackIssue=issue
        if YUI.Event and YUI.Event.Emit then YUI.Event:Emit('YUI_MONITOR_SOURCE_STATUS_CHANGED',source.key) end
    end
    if active==nil then
        source.bonePresent,source.boneFrame,source.boneFrameID=nil,nil,nil
        return changed
    end
    if source.bonePresent==true and active==false and frame==source.boneFrame and id==source.boneFrameID then
        state.stackSequence=state.stackSequence+1;changed=true
    end
    source.bonePresent,source.boneFrame,source.boneFrameID=active,frame,id
    return changed
end
local function BoneReceive(source,state,event,unit,guid,spellID)
    if event=='UNIT_SPELLCAST_SUCCEEDED' then
        spellID=Public(spellID)
        if spellID~=195182 and spellID~=195292 and not (spellID==49028 and source.params.dancingRuneWeapon) then return false end
        return Receive(source,state,event,unit,guid,195181)
    end
    if event=='PLAYER_DEAD' or event=='PLAYER_ENTERING_WORLD' then
        source.boneDead=event=='PLAYER_DEAD'
        source.bonePresent,source.boneFrame,source.boneFrameID=nil,nil,nil
        source.boneAuraDirty=true
        return Receive(source,state,event)
    end
    if event=='COOLDOWN_VIEWER_DATA_LOADED' then
        source.bonePresent,source.boneFrame,source.boneFrameID=nil,nil,nil
    end
    if event=='PLAYER_ALIVE' or event=='PLAYER_UNGHOST' then source.boneDead=nil end
    source.boneAuraDirty=true
    return true
end
function Sources:DescribeBoneShield(remaining)
    if not YUI.IsRetail then return nil,'unsupported-client' end
    if type(remaining)~='number' or remaining<1 or remaining>15 or remaining%1~=0 then return nil,'invalid-threshold' end
    if not self.boneShieldRegistered then
        local ok,code=M:RegisterSourceType('bone-shield-estimate',{
            createState=function() return {sequence=0,stackSequence=0,phase='idle'} end,read=BoneRead,onEvent=BoneReceive,
            events={{event='UNIT_SPELLCAST_SUCCEEDED',units={'player'},all=true,synchronous=true},
                {event='UNIT_AURA',units={'player'},all=true},
                {event='COOLDOWN_VIEWER_DATA_LOADED',all=true},{event='PLAYER_REGEN_ENABLED',all=true},
                {event='CVAR_UPDATE',all=true},{event='PLAYER_ALIVE',all=true},{event='PLAYER_UNGHOST',all=true},
                {event='PLAYER_ENTERING_WORLD',all=true,synchronous=true},{event='PLAYER_DEAD',all=true,synchronous=true}},
        })
        if not ok and code~='source-type-exists' then return nil,code end
        self.boneShieldRegistered=true
    end
    local spell=YUI.API and YUI.API.Spell
    local talented=spell and spell.GetKnownState and spell.GetKnownState(377637)==true or false
    local talent=YUI.API and YUI.API.Talent
    if not talented and talent and talent.ReadActiveTraitSpellSet then
        local ok,set=pcall(talent.ReadActiveTraitSpellSet,{})
        talented=ok and type(set)=='table' and set[377637]==true or false
    end
    return {key='bone-shield-estimate:'..remaining..':'..tostring(talented),type='bone-shield-estimate',
        params={spellID=195181,unit='player',duration=30-remaining,policy='restart',dancingRuneWeapon=talented}}
end
return Sources
