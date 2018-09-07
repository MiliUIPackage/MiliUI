local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end

local L = Engine.Locales
local Config = Engine.Config
local UI = Engine.UI

local GetConfig = Engine.GetConfig
local AddConfig = Engine.AddConfig

if UI.MyName == "Meuhhnon" then
	local mover = GetConfig("druid", "mover")
	-- add 2 health frames, player below wild mushrooms and target above combo/eclipse
	AddConfig("druid", 
		{
			name = "CM_PLAYER_HEALTH",
			kind = "HEALTH",
			unit = "player",
			text = true,
			autohide = false,
			anchor = { "TOPLEFT", "CM_WILDMUSHROOMS", "BOTTOMLEFT", 0, -3},
			width = 262,
			height = 10,
			autohide = true,
		})
	AddConfig("druid",
		{
			name = "CM_TARGET_HEALTH",
			kind = "HEALTH",
			unit = "target",
			text = true,
			autohide = false,
			anchor = { "BOTTOMLEFT", "CM_COMBO", "TOPLEFT", 0, 3},
			width = 262,
			height = 10,
			autohide = true
		})
end

if UI.MyName == "Gargulqwas" then
	GetConfig("druid", "resource").specs = {2, 3} -- resource only in cat/bear
	GetConfig("druid", "combo").specs = {2} -- combo only in cat
	GetConfig("druid", "eclipse").anchor = {unpack(GetConfig("druid", "resource").anchor)} -- eclipse at the same location than resource(already only visible in balance spec)
end