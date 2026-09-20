do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Sound = YUI.API.Sound or {}
YUI.API.Sound = Sound

local Legacy = YUI.WOW_API

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local volumeCVars = { Master='Sound_MasterVolume', SFX='Sound_SFXVolume',
    Dialog='Sound_DialogVolume', Music='Sound_MusicVolume', Ambience='Sound_AmbienceVolume' }

-- Settings-only read of the channel slider, not effective mixed output volume.
-- Missing or protected values remain unknown; never write global sound CVars.
function Sound.GetChannelVolume(channel)
    if IsSecret(channel) or type(channel)~='string' then return nil end
    local name=volumeCVars[channel]
    local getter=C_CVar and C_CVar.GetCVar or GetCVar
    if not name or type(getter)~='function' then return nil end
    local ok,value=pcall(getter,name)
    if not ok or IsSecret(value) then return nil end
    value=tonumber(value)
    if not value or value~=value or value<0 or value>1 then return nil end
    return math.floor(value*100+0.5)
end

-- Read only: never change the player's global sound preference to play a preview.
function Sound.GetOutputIssue()
    local getter = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    if type(getter) ~= 'function' then return end
    local ok, enabled = pcall(getter, 'Sound_EnableAllSound')
    if ok and not IsSecret(enabled) and enabled == false then return 'game-sound-disabled' end
end

function Sound.PlayFile(file, channel)
    if IsSecret(file) or IsSecret(channel) then return false, nil end
    local fileType = type(file)
    if (fileType ~= "string" and fileType ~= "number")
        or type(PlaySoundFile) ~= "function" then
        return false, nil
    end

    local ok, played, handle = pcall(PlaySoundFile, file, channel)
    if not ok or IsSecret(played) or played ~= true or IsSecret(handle) then
        return false, nil
    end
    return true, handle
end

function Sound.PlayKit(soundKitId, channel)
    if IsSecret(soundKitId) or IsSecret(channel) then return false, nil end
    if type(soundKitId) ~= "number" or type(PlaySound) ~= "function" then
        return false, nil
    end

    local ok, played, handle = pcall(PlaySound, soundKitId, channel)
    if not ok or IsSecret(played) or played ~= true or IsSecret(handle) then
        return false, nil
    end
    return true, handle
end

Legacy.PlaySoundFile = Sound.PlayFile
Legacy.PlaySound = Sound.PlayKit

-- Unknown is distinct from stopped; callers must not advance a serialized
-- queue on an unavailable or protected playback-state result.
function Sound.IsPlaying(handle)
    if type(issecretvalue) == "function" and issecretvalue(handle) then return nil end
    if type(handle) ~= "number" or not (C_Sound and C_Sound.IsPlaying) then return nil end
    local ok, playing = pcall(C_Sound.IsPlaying, handle)
    if not ok or (type(issecretvalue) == "function" and issecretvalue(playing)) then return nil end
    if type(playing) ~= "boolean" then return nil end
    return playing
end

function Sound.Stop(handle)
    if type(issecretvalue) == "function" and issecretvalue(handle) then return false end
    if type(handle) ~= "number" or type(StopSound) ~= "function" then return false end
    return pcall(StopSound, handle)
end

function Sound.RegisterAura(event, unit, spellID, file, channel)
    if YUI.IsRetail~=true or not (C_UnitAuras and type(C_UnitAuras.AddAuraSound)=='function'
        and type(C_UnitAuras.RemoveAuraSound)=='function') then return nil,'aura-sound-unavailable' end
    if IsSecret(event) or IsSecret(unit) or IsSecret(spellID) or IsSecret(file) or IsSecret(channel) then return nil,'invalid-aura-sound' end
    local triggers=Enum and Enum.UnitAuraSoundTrigger
    local trigger=triggers and (event=='auraAdded' and triggers.Added or event=='auraRemoved' and triggers.Removed)
    if trigger==nil or trigger==false or (unit~='player' and unit~='target' and unit~='focus')
        or type(spellID)~='number' or spellID<=0 or spellID>=math.huge or spellID%1~=0
        or (type(file)~='string' and type(file)~='number')
        or type(file)=='string' and file==''
        or type(file)=='number' and (file<=0 or file>=math.huge or file%1~=0) then return nil,'invalid-aura-sound' end
    local combat = YUI.API.Combat
    if combat and combat.InCombatLockdown and combat.InCombatLockdown()
        or not (combat and combat.InCombatLockdown) and InCombatLockdown and InCombatLockdown() then
        return nil, 'aura-sound-combat-pending'
    end
    local ok,id=pcall(C_UnitAuras.AddAuraSound,trigger,{unitToken=unit,spellID=spellID,
        soundFileName=type(file)=='string' and file or nil,soundFileID=type(file)=='number' and file or nil,outputChannel=channel})
    if not ok or IsSecret(id) or type(id)~='number' or id<0 or id>=math.huge or id%1~=0 then return nil,'aura-sound-registration-failed' end
    return id
end

function Sound.RemoveAura(id)
    if IsSecret(id) or type(id)~='number' or id<0 or id>=math.huge or id%1~=0
        or not (C_UnitAuras and type(C_UnitAuras.RemoveAuraSound)=='function') then return false end
    return pcall(C_UnitAuras.RemoveAuraSound,id)
end
