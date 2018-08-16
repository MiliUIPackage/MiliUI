--[[--------------------------------------------------------------------
	GridStatusHealTrace
	Shows in Grid who was healed by your multi-target heals.
	Copyright (c) 2010-2011 Akkorian <akkorian@armord.net>. All rights reserved.
	Copyright (c) 2011-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://www.wowinterface.com/downloads/info16608-GridStatusHealTrace.html
	https://www.curseforge.com/wow/addons/gridstatushealtrace
	https://github.com/Phanx/GridStatusHealTrace

	TODO:
	Listen for totem/guardian create/destroy events in CLEU, keep a list
	of their GUIDs, and match against the list instead of only matching
	against the player's GUID, so heals from totems/mushrooms/etc can
	be traced.
----------------------------------------------------------------------]]

local _, ns = ...
local L = ns.L

local GridStatusHealTrace = Grid:NewStatusModule("GridStatusHealTrace")
local active, spellOrder, playerGUID, settings, spells = {}, {}

------------------------------------------------------------------------

GridStatusHealTrace.defaultDB = {
	alert_healTrace = {
		color = { r = 0.8, g = 1.0, b = 0.2, a = 1 },
		enable = true,
		holdTime = 1,
		priority = 75,
		range = false,
		spells = {},
	}
}
for _, spellID in ipairs({
	-- Druid
--	81262,  -- Efflorescence (doesn't work: caster not player)
--	740,    -- Tranquility (ignored: channelled + hits all targets)
	-- Monk
	123986, -- Chi Burst
	115098, -- Chi Wave
	191840, -- Essence Font
--	196725, -- Refreshing Jade Wind
	116670, -- Vivify
	-- Paladin
	119952, -- Arcing Light (talent: Light's Hammer)
--	183415, -- Aura of Mercy (ignored: passive + too small to matter?)
	114852, -- Holy Prism (talent, cast on enemy target)
	114871, -- Holy Prism (talent, cast on friendly target)
	85222,  -- Light of Dawn
	-- Priest
	32546,  -- Binding Heal -- TODO: ignore on self?
	204883, -- Circle of Healing
--	64843,  -- Divine Hymn (ignored: channelled + hits all targets + applies a buff)
	110745, -- Divine Star (talent, disc version)
	110744, -- Divine Star (talent, holy version)
	120692, -- Halo (talent, disc version)
	120517, -- Halo (talent, holy version)
	132157, -- Holy Nova
	34861,  -- Holy Word: Sanctify
	194509, -- Power Word: Radiance -- NEEDS CHECK
	596,    -- Prayer of Healing
	204065, -- Shadow Covenant -- NEEDS CHECK
	200128, -- Trail of Light -- NEEDS CHECK, might show as Flash Heal on secondary target
	-- Shaman
	1064,   -- Chain Heal
--	157503, -- Cloudburst  (doesn't work, caster not player)
--	73920,  -- Healing Rain -- NEEDS CHECK, is it big enough to care about?
--	5394,   -- Healing Stream Totem (doesn't work, caster not player)
--	108280, -- Healing Tide Totem (doesn't work, caster not player)
	197995, -- Wellspring
}) do
	local name, _, icon = GetSpellInfo(spellID)
	if name then
		GridStatusHealTrace.defaultDB.alert_healTrace.spells[name] = icon
	end
end

------------------------------------------------------------------------

local optionsForStatus = {
	holdTime = {
		order = -3,
		width = "double",
		name = L["Hold time"],
		desc = L["Show the status for this many seconds."],
		type = "range",
		min = 0.25,
		max = 5,
		step = 0.25,
		get = function()
			return GridStatusHealTrace.db.profile.alert_healTrace.holdTime
		end,
		set = function(_, v)
			GridStatusHealTrace.db.profile.alert_healTrace.holdTime = v
		end,
	},
	addSpell = {
		order = -2,
		width = "double",
		name = L["Add new spell"],
		desc = L["Add another healing spell to trace."],
		type = "input",
		usage = L["<spell name or spell ID>"],
		get = false,
		set = function(_, v)
			GridStatusHealTrace:AddSpell(string.trim(v))
		end,
	},
	removeSpell = {
		order = -1,
		name = L["Remove spell"],
		desc = L["Remove a spell from the trace list."],
		type = "group", dialogInline = true,
		args = {},
	},
}

------------------------------------------------------------------------

do
	local function removeSpell_func(info)
		GridStatusHealTrace:RemoveSpell(info.arg)
	end

	function GridStatusHealTrace:AddSpell(name, icon)
		if name:match("^(%d+)$") then
			local _
			name, _, icon = GetSpellInfo(name)
		end

		if not name then return end

		if type(icon) == "boolean" then
			icon = nil
		end

		self.db.profile.alert_healTrace.spells[name] = icon or true

		optionsForStatus.removeSpell.args[name] = {
			name = string.format("\124T%s:0:0:0:0:32:32:3:29:3:29\124t %s", icon or "Interface\\ICONS\\INV_Misc_QuestionMark", name),
			desc = string.format(L["Remove %s from the trace list."], name),
			type = "execute",
			func = removeSpell_func,
			arg = name,
		}

		if not spellOrder[name] then
			spellOrder[name] = true
			spellOrder[#spellOrder + 1] = name
			table.sort(spellOrder)
			for i = 1, #spellOrder do
				optionsForStatus.removeSpell.args[spellOrder[i]].order = i
			end
		end
	end

	function GridStatusHealTrace:RemoveSpell(name)
		self.db.profile.alert_healTrace.spells[name] = nil
		optionsForStatus.removeSpell.args[name] = nil
	end
end

------------------------------------------------------------------------

function GridStatusHealTrace:PostInitialize()
	self:RegisterStatus("alert_healTrace", L["Heal Trace"], optionsForStatus, true)

	settings = self.db.profile.alert_healTrace
	spells = settings.spells

	if not settings.version or settings.version < 1 then
		wipe(spells)
		for k, v in pairs(self.defaultDB.alert_healTrace.spells) do
			spells[k] = v
		end
		settings.version = 1
	end

	for name, icon in pairs(spells) do
		self:AddSpell(name, icon)
	end
end

function GridStatusHealTrace:PostEnable()
	playerGUID = UnitGUID("player")
	self:RegisterEvent("SPELLS_CHANGED", "OnStatusEnable")
end

function GridStatusHealTrace:OnStatusEnable(status)
	for name in pairs(spells) do
		if GetSpellInfo(name) then
			return self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
	end
	self:OnStatusDisable(status)
end

function GridStatusHealTrace:OnStatusDisable(status)
	self:UnregisterAllEvents()
	self.core:SendStatusLostAllUnits("alert_healTrace")
end

function GridStatusHealTrace:PostReset()
	self.core:SendStatusLostAllUnits("alert_healTrace")

	settings = self.db.profile.alert_healTrace
	spells = settings.spells
	for name in pairs(optionsForStatus.removeSpell.args) do
		if not spells[name] then
			optionsForStatus.removeSpell.args[name] = nil
		end
	end
	for name, icon in pairs(spells) do
		if not optionsForStatus.removeSpell.args[name] then
			self:AddSpell(name, icon)
		end
	end
	if self.db.profile.alert_healTrace.enable then
		self:RegisterEvent("SPELLS_CHANGED", "OnStatusEnable")
	end
end

------------------------------------------------------------------------

local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self, elapsed)
	local i = 0
	for destGUID, holdTime in pairs(active) do
		holdTime = holdTime - elapsed
		if holdTime <= 0 then
			GridStatusHealTrace.core:SendStatusLost(destGUID, "alert_healTrace")
			active[destGUID] = nil
		else
			active[destGUID] = holdTime
			i = i + 1
		end
	end
	if i == 0 then
		self:Hide()
	end
end)

function GridStatusHealTrace:COMBAT_LOG_EVENT_UNFILTERED(_, _, event)
	local _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
	if sourceGUID ~= playerGUID or event ~= "SPELL_HEAL" or not spells[spellName] then
		return
	end

	local spellIcon = spells[spellName]
	if type(spellIcon) == "boolean" then
		local name, _, icon = GetSpellInfo(spellID)
		self:RemoveSpell(name)
		self:AddSpell(name, icon)
		spellIcon = icon
	end

	self.core:SendStatusGained(destGUID, "alert_healTrace",
		settings.priority,
		settings.range,
		settings.color,
		spellName,
		nil,
		nil,
		spellIcon
	)

	active[destGUID] = settings.holdTime
	timerFrame:Show()
end
