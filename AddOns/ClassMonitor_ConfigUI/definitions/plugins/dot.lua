local ADDON_NAME, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions

local color = D.Helpers.CreateColorsDefinition("color", 3, { L.DotColor1, L.DotColor2, L.DotColor3 })

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
	--	[10] = {
	--		key = "latency",
	--		name = L.DotLatency,
	--		desc = L.DotLatencyDesc,
	--		type = "toggle",
	--		get = D.Helpers.GetValue,
	--		set = D.Helpers.SetValue,
	--		disabled = D.Helpers.IsPluginDisabled
	--	},
	--	[11] = {
	--		key = "threshold",
	--		name = L.Threshold,
	--		desc = L.DotThresholdDesc,
	--		type = "input",
	--		get = D.Helpers.GetNumberValue, --D.Helpers.GetValue,
	--		set = D.Helpers.SetNumberValue, --D.Helpers.SetValue,
	--		validate = D.Helpers.ValidateNumber,
	--		disabled = D.Helpers.IsPluginDisabled
	--	},
	--	[12] = color,
	[12] = D.Helpers.ColorPanel,
	[13] = D.Helpers.Anchor,
	[14] = D.Helpers.AutoGridAnchor,
}

D.Helpers:NewPluginDefinition("DOT", options, L.PluginShortDescription_DOT, L.PluginDescription_DOT)