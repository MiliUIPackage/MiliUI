local _, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions

-- Generic configuration if specific definition not found
D.DefaultPluginDefinition = {
	[1] = D.Helpers.Description,
	[2] = D.Helpers.Name,
	[3] = D.Helpers.DisplayName,
	[4] = D.Helpers.Kind,
	[5] = D.Helpers.Enabled,
	[6] = D.Helpers.Autohide,
	[7] = D.Helpers.WidthAndHeight,
	[8] = D.Helpers.Specs,
	[9] = D.Helpers.Anchor,
	[10] = D.Helpers.AutoGridAnchor,
}