--[[
    If you want to customize the settings (add own sounds or spells, for
    example), you can create a new file called "myconfig.lua" and put
    your own variables in it. A good starting point is probably copying
    this file.
]]--

EnhBloodlustConfig = {};

local config = EnhBloodlustConfig;

-- Bloodlust, Heroism, Time Warp, Ancient Hysteria
config.spells = {2825, 32182, 80353, 90355, 160452, 178207, 230935, 264667, 256740, 292686}

config.sound = {
	-- 加入音樂檔案路徑，一行一首歌，結尾加上逗號，會隨機播放。
	-- 最後一首歌 (最後一行) 的結尾不要加逗號。
	-- 每一行前面加上兩條橫線的歌曲不會播放。
	-- "Interface\\AddOns\\EnhBloodlust\\音樂檔案名稱.副檔名",
	"Interface\\AddOns\\EnhBloodlust\\Is_She_With_You.mp3",
	"Interface\\AddOns\\EnhBloodlust\\bloodlust_mid.mp3"
}

-- 音樂長度建議40秒，剛好是嗜血的時間。
config.length = 40;

-- 嗜血音樂所使用的聲音頻道，可以使用的值有主音量 "Master" 和法術音效 "SFX"。
config.channel = "Master";

--[[
--Some other examples

--Duration
config.sound = {
    "Sound\\Music\\ZoneMusic\\DMF_L70ETC01.mp3"
}
config.length = 264;

--Short
config.sound = {
    "Interface\\AddOns\\EnhBloodlust\\bloodlust_short.mp3"
}
config.length = 4;

--Long
config.sound = {
    ""Interface\\AddOns\\EnhBloodlust\\bloodlust_mid.mp3""
}
config.length = 40;
]]--
