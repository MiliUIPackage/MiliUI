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
	[9] = D.Helpers.Spell,
	[10] = {
		key = "filling",
		name = L.EnergizeFilling,
		desc = L.EnergizeFillingDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[11] = {
		key = "duration",
		name = L.EnergizeDuration,
		desc = L.EnergizeDurationDesc,
		type = "input",
		get = D.Helpers.GetNumberValue, --D.Helpers.GetValue,
		set = D.Helpers.SetNumberValue, --D.Helpers.SetValue,
		validate = D.Helpers.ValidateNumber,
		disabled = D.Helpers.IsPluginDisabled
	},
	[12] = color,
	[13] = D.Helpers.Anchor,
	[14] = D.Helpers.AutoGridAnchor,
}

D.Helpers:NewPluginDefinition("ENERGIZE", options, L.PluginShortDescription_ENERGIZE, L.PluginDescription_ENERGIZE)