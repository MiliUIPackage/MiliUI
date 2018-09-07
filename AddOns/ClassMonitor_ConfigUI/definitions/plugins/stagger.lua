local ADDON_NAME, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions

local colors = D.Helpers.CreateColorsDefinition("colors", 3, {L.StaggerLight, L.StaggerModerate, L.StaggerHeavy} )

local options = {
	[1] = D.Helpers.Description,
	[2] = D.Helpers.Name,
	[3] = D.Helpers.DisplayName,
	[4] = D.Helpers.Kind,
	[5] = D.Helpers.Enabled,
	[6] = D.Helpers.Autohide,
	[7] = D.Helpers.WidthAndHeight,
	[8] = {
		key = "threshold",
		name = L.Threshold,
		desc = L.StaggerThresholdDesc,
		type = "range",
		min = 1, max = 100, step = 1, -- isPercent = true,  isPercent implies values in range [0, 1]
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[9] = {
		key = "text",
		name = L.Text,
		desc = L.StaggerTextDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[10] = {
		key = "textSize",
		name = L.TextSize,
		desc = L.TextSizeDesc,
		type = "range",
		min = 10, max = 24, step = 2,
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[11] = colors,
	[12] = D.Helpers.Anchor,
	[13] = D.Helpers.AutoGridAnchor,
}

D.Helpers:NewPluginDefinition("STAGGER", options, L.PluginShortDescription_STAGGER, L.PluginDescription_STAGGER)