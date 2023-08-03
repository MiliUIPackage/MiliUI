EnhBloodlust = CreateFrame("frame")
EnhBloodlust:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

local config = EnhBloodlustConfig
local playing = false

EnhBloodlust:RegisterEvent("ADDON_LOADED")
function EnhBloodlust:ADDON_LOADED(e, addon)
	if addon:lower() ~= "enhbloodlust" then return end

	EnhBloodlust:RegisterEvent("PLAYER_REGEN_DISABLED");
	EnhBloodlust:RegisterEvent("PLAYER_REGEN_ENABLED");

	EnhBloodlust:UnregisterEvent("ADDON_LOADED");
end

SLASH_ENHBLOODLUST1 = '/enhbl';
SLASH_ENHBLOODLUST2 = '/測試音樂';
function SlashCmdList.ENHBLOODLUST(args)
    if args and args == "" then
		args = nil
	end
	EnhBloodlust:BLOODLUST(args);
end

function EnhBloodlust:PLAYER_REGEN_DISABLED()
	EnhBloodlust:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
end

function EnhBloodlust:COMBAT_LOG_EVENT_UNFILTERED()
	local _, event, _, _, _, _, _, destGUID, _, _, _, spellID = CombatLogGetCurrentEventInfo()
	if (event == "SPELL_AURA_APPLIED") and (destGUID == UnitGUID("player")) and (not playing) then
		for _,v in pairs(config.spells) do
            if v == spellID then
                if spellID == 390386 and C_UnitAuras.GetPlayerAuraBySpellID(spellID).duration < 40 then -- 檢查龍人套裝嗜血，播放短音效。
						-- PlaySoundFile(config.soundShort[ math.random( #config.soundShort ) ], config.channel);
						EnhBloodlust:BLOODLUST(true);
				else
					EnhBloodlust:BLOODLUST();
				end
				break;
            end
        end
	end
end

function EnhBloodlust:PLAYER_REGEN_ENABLED()
	EnhBloodlust:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
end

function EnhBloodlust:BLOODLUST(short)
	-- 檢查是否已經播放音樂
	if playing then return end
	
	local Volume = tonumber(GetCVar("Sound_MusicVolume"))
	local AmbienceVolume = tonumber(GetCVar("Sound_AmbienceVolume"))
	SetCVar("Sound_MusicVolume", 0)
	SetCVar("Sound_AmbienceVolume", 0)

    if (config.channel == nil) then
        config.channel = "Master";
    end

	-- 隨機播放一首歌曲
	if short then 
		playing = PlaySoundFile(config.soundShort[ math.random( #config.soundShort ) ], config.channel);
	else
		playing = PlaySoundFile(config.sound[ math.random( #config.sound ) ], config.channel);
	end
	
    C_Timer.After(short and config.lengthShort or config.length, function()
		SetCVar("Sound_MusicVolume", Volume)
		SetCVar("Sound_AmbienceVolume", AmbienceVolume)
		playing = false
	end)
end
