EnhBloodlust = CreateFrame("frame")
EnhBloodlust:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

local UpdateSeconds, DelayTime, TrackLength, TrackPosition, MusicSetting, Volume, config = 1, 0, 0, -1, 0, 0, EnhBloodlustConfig;
local AmbienceVolume = 0.6;

EnhBloodlust:RegisterEvent("ADDON_LOADED")
function EnhBloodlust:ADDON_LOADED(e, addon)
	if addon:lower() ~= "enhbloodlust" then return end

	EnhBloodlust:RegisterEvent("PLAYER_REGEN_DISABLED");
	EnhBloodlust:RegisterEvent("PLAYER_REGEN_ENABLED");

	EnhBloodlust:UnregisterEvent("ADDON_LOADED");
end

SLASH_ENHBLOODLUST1 = '/enhbl';
function SlashCmdList.ENHBLOODLUST(args)
    EnhBloodlust:BLOODLUST();
end

function EnhBloodlust:PLAYER_REGEN_DISABLED()
	EnhBloodlust:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
end

function EnhBloodlust:COMBAT_LOG_EVENT_UNFILTERED()
	local _, event, _, _, _, _, _, destGUID, _, _, _, spellID = CombatLogGetCurrentEventInfo()
	if (event == "SPELL_AURA_APPLIED") and (destGUID == UnitGUID("player")) and (EnhBloodlust_Status ~= 0) then
		for _,v in pairs(config.spells) do
            if v == spellID then
                EnhBloodlust:BLOODLUST();
				break;
            end
        end
	end
end

function EnhBloodlust:PLAYER_REGEN_ENABLED()
	EnhBloodlust:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
end

function EnhBloodlust:ON_UPDATE()
	local CurrentTime = GetTime();
	if (CurrentTime >= DelayTime) then
		DelayTime = (CurrentTime + UpdateSeconds);
		TrackPosition = (TrackPosition + UpdateSeconds);
 	  	if (TrackPosition >= TrackLength) then
			EnhBloodlust:SetScript("OnUpdate", nil);
			SetCVar("Sound_MusicVolume", Volume)
			SetCVar("Sound_AmbienceVolume", AmbienceVolume)
		end
 	end
end

function EnhBloodlust:BLOODLUST()
	Volume = tonumber(GetCVar("Sound_MusicVolume"))
	AmbienceVolume = tonumber(GetCVar("Sound_AmbienceVolume"))
	if (Volume == 0) then Volume = 0.4; end
	SetCVar("Sound_MusicVolume", 0)
	SetCVar("Sound_AmbienceVolume", 0)

    if (config.channel == nil) then
        config.channel = "Master";
    end
--[[
    for _,v in pairs(config.sound) do
        PlaySoundFile(v, config.channel);
    end
--]]

	-- 隨機播放一首歌曲
	PlaySoundFile(config.sound[ math.random( #config.sound ) ], config.channel);
	
    TrackLength = config.length;

	DelayTime, TrackPosition = 0, -1;
	EnhBloodlust:SetScript("OnUpdate", function() EnhBloodlust:ON_UPDATE(); end)
end
