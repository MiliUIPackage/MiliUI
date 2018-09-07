local ADDON_NAME, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions

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
		key = "count",
		name = L.Count,
		desc = L.TotemsCountDesc,
		type = "select",
		values = {
			[4] = L.TotemsShaman,
			[1] = L.TotemsOthers,
		},
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[10] = {
		key = "text",
		name = L.TimeLeft,
		desc = L.TotemsTextDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	-- TODO: map
	-- TODO: colors
	[12] = D.Helpers.ColorPanel,
	[13] = D.Helpers.Anchor,
	[14] = D.Helpers.AutoGridAnchor,
}

D.Helpers:NewPluginDefinition("TOTEMS", options, L.PluginShortDescription_TOTEMS, L.PluginDescription_TOTEMS)