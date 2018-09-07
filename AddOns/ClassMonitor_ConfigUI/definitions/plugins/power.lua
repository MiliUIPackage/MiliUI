local ADDON_NAME, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions

--local color = D.Helpers.CreateColorsDefinition("color", 1, {L.BarColor})

local powerTypes = {
	[4] = L.PluginShortDescription_COMBO,
	[7] = L.PowerValueSoulShards,
	[9] = L.PowerValueHolyPower,
	[12] = L.PowerValueChi,
	[16] = L.PowerValueArcaneBlast,
}
local function GetPowerTypes()
	return powerTypes
end

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
		key = "powerType",
		name = L.PowerType,
		desc = L.PowerTypeDesc,
		type = "select",
		values = GetPowerTypes,
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[11] = {
		key = "filled",
		name = L.Filled,
		desc = L.PowerFilledDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[12] = {
		key = "reverse",
		name = L.Reverse,
		desc = L.ReverseDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[13] = {
		key = "borderRemind",
		name = L.BorderRemind,
		desc = L.ComboBorderRemindDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
    [14] = D.Helpers.ColorPanel,
	[15] = D.Helpers.Anchor,
	[16] = D.Helpers.AutoGridAnchor,
}

D.Helpers:NewPluginDefinition("POWER", options, L.PluginShortDescription_POWER, L.PluginDescription_POWER)