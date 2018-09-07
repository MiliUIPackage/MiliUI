local ADDON_NAME, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions

local color = D.Helpers.CreateColorsDefinition("color", 1, {L.BarColor})
local options = {
	[1] = D.Helpers.Description,
	[2] = D.Helpers.Name,
	[3] = D.Helpers.DisplayName,
	[4] = D.Helpers.Kind,
	[5] = D.Helpers.Enabled,
	[6] = D.Helpers.Autohide,
	[7] = D.Helpers.WidthAndHeight,
	[8] = D.Helpers.Specs,
	[9] = {
		key = "text",
		name = L.CDText,
		desc = L.CDTextDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[10] = {
		key = "duration",
		name = L.TimeLeft,
		desc = L.CDDurationDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[11] = D.Helpers.Spell,
	[12] = D.Helpers.ColorPanel,
	[13] = D.Helpers.Anchor,
	[14] = D.Helpers.AutoGridAnchor,
}

D.Helpers:NewPluginDefinition("CD", options, L.PluginShortDescription_CD, L.PluginDescription_CD)