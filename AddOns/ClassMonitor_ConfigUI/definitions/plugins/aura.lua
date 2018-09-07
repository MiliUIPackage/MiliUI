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
	[9] = D.Helpers.Unit,
	[10] = D.Helpers.Spell,
	[11] = D.Helpers.Filter,
	[12] = {
		key = "count",
		name = L.AuraCount,
		desc = L.AuraCountDesc,
		type = "range",
		min = 1, max = 16, step = 1,
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[13] = {
		key = "filled",
		name = L.Filled,
		desc = L.AuraFilledDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[14] = {
		key = "reverse",
		name = L.Reverse,
		desc = L.ReverseDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	--	[15] = color,
	[15] = D.Helpers.ColorPanel,
	[16] = D.Helpers.Anchor,
	[17] = D.Helpers.AutoGridAnchor,
--	[0] = __TestDefinition
}

D.Helpers:NewPluginDefinition("AURA", options, L.PluginShortDescription_AURA, L.PluginDescription_AURA)