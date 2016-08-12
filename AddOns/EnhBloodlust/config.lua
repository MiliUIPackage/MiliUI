--[[
    If you want to customize the settings (add own sounds or spells, for
    example), you can create a new file called "myconfig.lua" and put
    your own variables in it. A good starting point is probably copying
    this file.
]]--

EnhBloodlustConfig = {};

local config = EnhBloodlustConfig;

-- Bloodlust, Heroism, Time Warp, Ancient Hysteria
config.spells = {2825, 32182, 80353, 90355}

config.sound = {
    "Interface\\AddOns\\EnhBloodlust\\bloodlust_mid.mp3",
    "Interface\\AddOns\\EnhBloodlust\\bloodlust_short.mp3"
}
config.length = 40;

-- Possible values are "Master", "SFX", "Ambience" and "Music".
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
