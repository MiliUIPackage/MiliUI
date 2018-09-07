local ADDON_NAME, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions

local orientationValues = {
	["HORIZONTAL"] = L.RunesOrientationHorizontal,
	["VERTICAL"] = L.RunesOrientationVertical,
}
local function GetOrientationValues()
	return orientationValues
end

local runesValues = {
	["1"] = L.RunesBlood.."1",
	["2"] = L.RunesBlood.."2",
	["3"] = L.RunesUnholy.."1",
	["4"] = L.RunesUnholy.."2",
	["5"] = L.RunesFrost.."1",
	["6"] = L.RunesFrost.."2",
}

local function GetRunemap(info)
	local section = info.arg.section
	local option = info[#info]
	if option == "slot1" then
		value = tostring(section[info.arg.key][1])
	elseif option == "slot2" then
		value = tostring(section[info.arg.key][2])
	elseif option == "slot3" then
		value = tostring(section[info.arg.key][3])
	elseif option == "slot4" then
		value = tostring(section[info.arg.key][4])
	elseif option == "slot5" then
		value = tostring(section[info.arg.key][5])
	elseif option == "slot6" then
		value = tostring(section[info.arg.key][6])
	end
--print("GetRunemap:"..tostring(option).."  "..table.concat(section[info.arg.key],",").."  "..tostring(value))
	return value
end

local function SetRunemap(info, value)
	local section = info.arg.section
	local option = info[#info]
	if option == "slot1" then
		section[info.arg.key][1] = tonumber(value)
	elseif option == "slot2" then
		section[info.arg.key][2] = tonumber(value)
	elseif option == "slot3" then
		section[info.arg.key][3] = tonumber(value)
	elseif option == "slot4" then
		section[info.arg.key][4] = tonumber(value)
	elseif option == "slot5" then
		section[info.arg.key][5] = tonumber(value)
	elseif option == "slot6" then
		section[info.arg.key][6] = tonumber(value)
	end
	D.Helpers.SaveValue(info.arg.section, info, section[info.arg.key])
--print("SetRunemap:"..tostring(option).."  "..table.concat(section[info.arg.key],",").."  "..tostring(value))
end

local runeMap = {
	key = "runemap",
	name = L.RunesRunemap,
	desc = L.RunesRunemapDesc,
	type = "group",
	guiInline = true,
	get = GetRunemap,
	set = SetRunemap,
	args = {
		slot1 = {
			order = 1,
			name = string.format(L.RunesSlot, 1),
			desc = string.format(L.RunesSlotDesc, 1),
			type = "select",
			values = runesValues,
		},
		slot2 = {
			order = 2,
			name = string.format(L.RunesSlot, 2),
			desc = string.format(L.RunesSlotDesc, 2),
			type = "select",
			values = runesValues,
		},
		slot3 = {
			order = 3,
			name = string.format(L.RunesSlot, 3),
			desc = string.format(L.RunesSlotDesc, 3),
			type = "select",
			values = runesValues,
		},
		slot4 = {
			order = 4,
			name = string.format(L.RunesSlot, 4),
			desc = string.format(L.RunesSlotDesc, 4),
			type = "select",
			values = runesValues,
		},
		slot5 = {
			order = 5,
			name = string.format(L.RunesSlot, 5),
			desc = string.format(L.RunesSlotDesc, 5),
			type = "select",
			values = runesValues,
		},
		slot6 = {
			order = 6,
			name = string.format(L.RunesSlot, 6),
			desc = string.format(L.RunesSlotDesc, 6),
			type = "select",
			values = runesValues,
		}
	}
}

local colors = D.Helpers.CreateColorsDefinition("colors", 4, {L.RunesBlood, L.RunesUnholy, L.RunesFrost, L.RunesDeath} )

local options = {
	[1] = D.Helpers.Description,
	[2] = D.Helpers.Name,
	[3] = D.Helpers.DisplayName,
	[4] = D.Helpers.Kind,
	[5] = D.Helpers.Enabled,
	[6] = D.Helpers.Autohide,
	[7] = D.Helpers.WidthAndHeight,
	[8] = {
		key = "updatethreshold",
		name = L.Threshold,
		desc = L.RunesThresholdDesc,
		type = "range",
		min = 0.1, max = 1, step = 0.1,
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[9] = {
		key = "orientation",
		name = L.RunesOrientation,
		desc = L.RunesOrientationDesc,
		type = "select",
		values = GetOrientationValues,
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[12] = D.Helpers.Anchor,
	[13] = D.Helpers.AutoGridAnchor,
	[14] = {
		key = "duration",
		name = L.RuneDuration,
		desc = L.RuneDurationDesc,
		type = "toggle",
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
	[15] = {
		key = "durationTextSize",
		name = L.RuneDurationSize,
		desc = L.RuneDurationSizeDesc,
		type = "range",
		min = 6, max = 20, step = 1,
		get = D.Helpers.GetValue,
		set = D.Helpers.SetValue,
		disabled = D.Helpers.IsPluginDisabled
	},
}

D.Helpers:NewPluginDefinition("RUNES", options, L.PluginShortDescription_RUNES, L.PluginDescription_RUNES)