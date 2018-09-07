local ADDON_NAME, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions

local function ValidateSpellID(info, value)
	local asNumber = tonumber(value)
	if asNumber and type(asNumber) == "number" then
		local spellName = GetSpellInfo(asNumber)
		if not spellName then
			return L.InvalidSpellID
		else
			return true
		end
	else
		return L.MustBeANumber
	end
end

local function GetSpellName(info)
	local spellID = tonumber(D.Helpers.GetValue(info) or 0)
	local spellName = GetSpellInfo(spellID)
	return spellName or "Invalid"
end

local function GetSpellIcon(info)
	local spellID = tonumber(D.Helpers.GetValue(info) or 0)
	local _, _, icon = GetSpellInfo(spellID)
	return icon or "INTERFACE/ICONS/INV_MISC_QUESTIONMARK"
end

local color = D.Helpers.CreateColorsDefinition("color", 1, { L.BarColor })

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
    [10] = D.Helpers.Filter,
    [11] = D.Helpers.Spell,
    [12] = D.Helpers.Fill,
    [13] = {
        key = "countFromOther",
        name = L.AurabarCountFromOther,
        desc = L.AurabarCountFromOtherDesc,
        type = "toggle",
        get = D.Helpers.GetValue,
        set = D.Helpers.SetValue,
        disabled = D.Helpers.IsPluginDisabled
    },
    [14] = {
        key = "countSpellID",
        name = L.AurabarCountSpellID,
        desc = L.AurabarCountSpellIDDesc,
        type = "group",
        guiInline = true,
        args = {
            countSpellID = {
                order = 1,
                name = L.AurabarCountSpellID,
                desc = L.AurabarCountSpellID,
                type = "input",
                validate = ValidateSpellID,
                --get = GetSpellIDAndSetSpellIcon,
                get = D.Helpers.GetNumberValue,
                set = D.Helpers.SetNumberValue, --D.Helpers.SetValue,
            },
            countSpellIcon = {
                order = 3,
                name = GetSpellName, --"Invalid",
                type = "description",
                --image = "INTERFACE/ICONS/INV_MISC_QUESTIONMARK",
                image = GetSpellIcon,
            },
        },
        disabled = D.Helpers.IsPluginDisabled
    },
    [15] = {
        key = "count",
        name = L.AuraCount,
        desc = L.AuraCountDesc,
        type = "range",
        min = 1,
        max = 100,
        step = 1,
        get = D.Helpers.GetValue,
        set = D.Helpers.SetValue,
        disabled = D.Helpers.IsPluginDisabled
    },
    [16] = {
        key = "showspellname",
        name = L.AurabarShowspellname,
        desc = L.AurabarShowspellnameDesc,
        type = "toggle",
        get = D.Helpers.GetValue,
        set = D.Helpers.SetValue,
        disabled = D.Helpers.IsPluginDisabled
    },
    [17] = {
        key = "text",
        name = L.CurrentValue,
        desc = L.AurabarTextDesc,
        type = "toggle",
        get = D.Helpers.GetValue,
        set = D.Helpers.SetValue,
        disabled = D.Helpers.IsPluginDisabled
    },
    [18] = {
        key = "duration",
        name = L.TimeLeft,
        desc = L.AurabarDurationDesc,
        type = "toggle",
        get = D.Helpers.GetValue,
        set = D.Helpers.SetValue,
        disabled = D.Helpers.IsPluginDisabled
    },
    --    [19] = color,
    [19] = D.Helpers.ColorPanel,
    [20] = D.Helpers.Anchor,
    [21] = D.Helpers.AutoGridAnchor,
}

D.Helpers:NewPluginDefinition("AURABAR", options, L.PluginShortDescription_AURABAR, L.PluginDescription_AURABAR)