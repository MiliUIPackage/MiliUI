--[[
LibSpellbook-1.0 - Track the spellbook to parry to IsSpellKnown discrepancies.
Copyright (C) 2013-2018 Adirelle (adirelle@gmail.com)

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Redistribution of a stand alone version is strictly prohibited without
      prior written authorization from the LibSpellbook project manager.
    * Neither the name of the LibSpellbook authors nor the names of its contributors
      may be used to endorse or promote products derived from this software without
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]

local MAJOR, MINOR = "LibSpellbook-1.0", 24
assert(LibStub, MAJOR.." requires LibStub")
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- constants
local _G = _G
local BOOKTYPE_PET = _G.BOOKTYPE_PET
local BOOKTYPE_SPELL = _G.BOOKTYPE_SPELL
local MAX_TALENT_TIERS = _G.MAX_TALENT_TIERS
local NUM_TALENT_COLUMNS = _G.NUM_TALENT_COLUMNS
-- blizzard api
local CreateFrame = _G.CreateFrame
local GetActiveSpecGroup = _G.GetActiveSpecGroup
local GetAllSelectedPvpTalentIDs = _G.C_SpecializationInfo.GetAllSelectedPvpTalentIDs
local GetFlyoutInfo = _G.GetFlyoutInfo
local GetFlyoutSlotInfo = _G.GetFlyoutSlotInfo
local GetPvpTalentInfoByID = _G.GetPvpTalentInfoByID
local GetSpellBookItemInfo = _G.GetSpellBookItemInfo
local GetSpellBookItemName = _G.GetSpellBookItemName
local GetSpellLink = _G.GetSpellLink
local GetSpellInfo = _G.GetSpellInfo
local GetSpellTabInfo = _G.GetSpellTabInfo
local GetTalentInfo = _G.GetTalentInfo
local HasPetSpells = _G.HasPetSpells
local InCombatLockdown = _G.InCombatLockdown
local IsPlayerSpell = _G.IsPlayerSpell
local IsWarModeDesired = _G.C_PvP.IsWarModeDesired
-- lua api
local next = _G.next
local pairs = _G.pairs
local strmatch = _G.strmatch
local tonumber = _G.tonumber
local type = _G.type

if not lib.spells then
	lib.spells = {
		byName     = {},
		byId       = {},
		lastSeen   = {},
		book       = {},
	}
end

if not lib.frame then
	lib.frame = CreateFrame("Frame")
	lib.frame:SetScript('OnEvent', function() return lib:ScanSpellbooks() end)
	lib.frame:RegisterEvent('SPELLS_CHANGED')
	lib.frame:RegisterEvent('PLAYER_ENTERING_WORLD')
end

lib.generation = lib.generation or 0

lib.callbacks = lib.callbacks or LibStub('CallbackHandler-1.0'):New(lib)

-- Upvalues
local byName, byId, book, lastSeen = lib.spells.byName, lib.spells.byId, lib.spells.book, lib.spells.lastSeen

-- Resolve a spell name, link or identifier into a spell identifier, or nil.
function lib:Resolve(spell)
	if type(spell) == "number" then
		return spell
	elseif type(spell) == "string" then
		local ids = byName[spell]
		if ids then
			return next(ids)
		else
			return tonumber(strmatch(spell, "spell:(%d+)") or "")
		end
	end
end

--- Return all ids associated to a spell name
-- @name LibSpellbook:GetAllIds
-- @param spell (string|number) The spell name, link or identifier.
-- @return ids A table with spell ids as keys.
function lib:GetAllIds(spell)
	local id = self:Resolve(spell)
	local name = id and byId[id]
	return name and byName[name]
end

--- Return whether the player or her pet knowns a spell.
-- @name LibSpellbook:IsKnown
-- @param spell (string|number) The spell name, link or identifier.
-- @param bookType (string) The spellbook to look into, either BOOKTYPE_SPELL, BOOKTYPE_PET, "TALENT", "PVP", or nil (=any).
-- @return True if the spell is known to the player
function lib:IsKnown(spell, bookType)
	local id = self:Resolve(spell)
	if id and byId[id] then
		return bookType == nil or bookType == book[id]
	end
	return false
end

--- Return the spellbook.
-- @name LibSpellbook:GetBookType
-- @param spell (string|number) The spell name, link or identifier.
-- @return BOOKTYPE_SPELL ("spell"), BOOKTYPE_PET ("pet"), "TALENT", "PVP", or nil if the spell if unknown.
function lib:GetBookType(spell)
	local id = self:Resolve(spell)
	return id and book[id]
end

-- Filtering iterator
local function iterator(bookType, id)
	local name
	repeat
		id, name = next(byId, id)
		if id and book[id] == bookType then
			return id, name
		end
	until not id
end

--- Iterate through all spells.
-- @name LibSpellbook:IterateSpells
-- @param bookType (string) The book to iterate : BOOKTYPE_SPELL, BOOKTYPE_PET, "TALENT", "PVP", or nil for all.
-- @return An iterator and a table, suitable to use in "in" part of a "for ... in" loop.
-- @usage
--   for id, name in LibSpellbook:IterateSpells(BOOKTYPE_SPELL) do
--     -- Do something
--   end
function lib:IterateSpells(bookType)
	if bookType then
		return iterator, bookType
	else
		return pairs(byId)
	end
end

function lib:FoundSpell(id, name, bookType)
	if not (id and name) then return end
	local isNew = not lastSeen[id]
	if byName[name] then
		byName[name][id] = true
	else
		byName[name] = { [id] = true }
	end
	byId[id] = name
	book[id] = bookType
	lastSeen[id] = self.generation
	if isNew then
		self.callbacks:Fire("LibSpellbook_Spell_Added", id, bookType, name)
		return true
	end
end

-- Scan the spells of a flyout
function lib:ScanFlyout(flyoutId, bookType)
	local _, _, numSlots, isKnown = GetFlyoutInfo(flyoutId)
	if not isKnown or numSlots < 1 then
		return
	end
	local changed = false
	for i = 1, numSlots do
		local id1, id2, isKnown, spellName = GetFlyoutSlotInfo(flyoutId, i)
		if isKnown then
			changed = self:FoundSpell(id1, spellName, bookType) or changed
			if id2 ~= id1 then
				changed = self:FoundSpell(id2, spellName, bookType) or changed
			end
		end
	end
	return changed
end


local playerClass
local spellRanks = {
	DEATHKNIGHT = {
		278223, -- Death Strike (Rank 2) (Unholy)
	},
	DRUID = {
		159456, -- Travel Form (Rank 2)
		231021, -- Starsurge (Rank 2) (Balance)
		231040, -- Rejuvenation (Rank 2) (Restoration)
		231042, -- Moonkin Form (Rank 2) (Balance)
		231050, -- Sunfire (Rank 2) (Balance/Restoration)
		231052, -- Rake (Rank 2) (Feral)
		231055, -- Tiger's Fury (Rank 2) (Feral)
		231056, -- Ferocious Bite (Rank 2) (Feral)
		231057, -- Shred (Rank 3) (Feral)
		231063, -- Shred (Rank 2) (Feral)
		231064, -- Mangle (Rank 2) (Guardian)
		231070, -- Ironfur (Rank 2) (Guardian)
		231283, -- Swipe (Rank 2) (Feral)
		270100, -- Bear Form (Rank 2) (Guardian)
		273048, -- Frenzied Regeneration (Rank 2) (Guardian)
	},
	HUNTER = {
		231546, -- Exhilaration (Rank 2)
		231549, -- Disengage (Rank 2)
		231550, -- Harpoon (Rank 2) (Survival)
		262837, -- Cobra Shot (Rank 2) (Beast Mastery)
		262838, -- Cobra Shot (Rank 3) (Beast Mastery)
		262839, -- Raptor Strike (Rank 2) (Survival)
		263186, -- Kill Command (Rank 2) (Survival)
	},
	MAGE = {
		231564, -- Arcane Barrage (Rank 2) (Arcane)
		231565, -- Evocation (Rank 2) (Arcane)
		231567, -- Fire Blast (Rank 3) (Fire)
		231568, -- Fire Blast (Rank 2) (Fire)
		231582, -- Shatter (Rank 2) (Frost)
		231584, -- Brain Freeze (Rank 2) (Frost)
		231596, -- Freeze (Pet) (Frost)
		236662, -- Blizzard (Rank 2) (Frost)
	},
	MONK = {
		231231, -- Renewing Mist (Rank 2) (Mistweaver)
		231602, -- Vivify (Rank 2)
		231605, -- Enveloping Mist (Rank 2) (Mistweaver)
		231627, -- Storm, Earth, and Fire (Rank 2) (Windwalker)
		231633, -- Essence Font (Rank 2) (Mistweaver)
		231876, -- Thunder Focus Tea (Rank 2) (Mistweaver)
		261916, -- Blackout Kick (Rank 2) (Windwalker)
		261917, -- Blackout Kick (Rank 3) (Windwalker)
		262840, -- Rising Sun Kick (Rank 2) (Mistweaver/Windwalker)
		274586, -- Vivify (Rank 2) (Mistweaver)
	},
	PALADIN = {
		200327, -- Blessing of Sacrifice (Rank 2) (Holy)
		231642, -- Beacon of Light (Rank 2) (Holy)
		231644, -- Judgement (Rank 2) (Holy)
		231657, -- Judgement (Rank 2) (Protection)
		231663, -- Judgement (Rank 2) (Retribution)
		231667, -- Crusader Strike (Rank 2) (Holy/Retribution)
		272906, -- Holy Shock (Rank 2) (Holy)
	},
	PRIEST = {
		231682, -- Smite (Rank 2) (Discipline)
		231688, -- Void Bolt (Rank 2) (Shadow)
		262861, -- Smite (Rank 2) (Discipline/Holy)
	},
	ROGUE = {
		231691, -- Sprint (Rank 2)
		231716, -- Eviscerate (Rank 2) (Subtlety)
		231718, -- Shadowstrike (Rank 2) (Subtlety)
		231719, -- Garotte (Rank 2) (Assasination)
		235484, -- Between the Eyes (Rank 2) (Outlaw)
		245751, -- Sprint (Rank 2) (Subtlety)
		279876, -- Sinister Strike (Rank 2) (Outlaw)
		279877, -- Sinister Strike (Rank 2) (Assasination)
	},
	SHAMAN = {
		190899, -- Healing Surge (Rank 2) (Enhancement)
		231721, -- Lava Burst (Rank 2) (Elemental/Restoration)
		231722, -- Chain Lightning (Rank 2) (Elemental)
		231723, -- Feral Spirit (Rank 2) (Enhancement)
		231725, -- Riptide (Rank 2) (Restoration)
		231780, -- Chain Heal (Rank 2) (Restoration)
		231785, -- Tidal Waves (Rank 2) (Restoration)
		280609, -- Mastery: Elemental Overload (Rank 2) (Elemental)
	},
	WARLOCK = {
		231791, -- Unstable Affliction (Rank 2) (Affliction)
		231792, -- Agony (Rank 2) (Affliction)
		231793, -- Conflagrate (Rank 2) (Destruction)
		231811, -- Soulstone (Rank 2)
	},
	WARRIOR = {
		 12950, -- Whirlwind (Rank 2) (Fury)
		231827, -- Execute (Rank 2) (Fury)
		231830, -- Execute (Rank 2) (Arms)
		231834, -- Shield Slam (Rank 2) (Protection)
		231847, -- Shield Block (Rank 2) (Protection)
	},
}
function lib:ScanRanks()
	playerClass = playerClass or select(2, UnitClass('player'))
	local ranks = spellRanks[playerClass]
	if not ranks then return end

	local changed = false
	for spell in next, ranks do
		if IsPlayerSpell(spell) then
			local name = GetSpellInfo(spell)
			changed = self:FoundSpell(spell, name, BOOKTYPE_SPELL) or changed
		end
	end

	return changed
end

-- Scan one spellbook
function lib:ScanSpellbook(bookType, numSpells, offset)
	local changed = false
	offset = offset or 0

	for index = offset + 1, offset + numSpells do
		local spellType, id1 = GetSpellBookItemInfo(index, bookType)
		if spellType == "SPELL" then
			local link = GetSpellLink(index, bookType)
			local id2, name
			-- BUG: Summon Lightforged Warframe does not have a link
			if link then
				id2, name = strmatch(link, "spell:(%d+):%d+\124h%[(.+)%]")
			else
				name, _, _, _, _, _, id2 = GetSpellInfo(GetSpellInfo(id1))
			end
			id2 = tonumber(id2)
			changed = self:FoundSpell(id2, name, bookType) or changed
			if id1 ~= id2 then
				changed = self:FoundSpell(id1, GetSpellBookItemName(index, bookType), bookType) or changed
			end
		elseif spellType == "FLYOUT" then
			changed = self:ScanFlyout(id1, bookType) or changed
		elseif spellType == "PETACTION" then
			local name, _, id = GetSpellBookItemName(index, bookType)
			changed = self:FoundSpell(id, name, bookType) or changed
		elseif not spellType then
			break
		end
	end

	return changed
end

function lib:ScanTalents()
	local changed = false

	local activeSpec = GetActiveSpecGroup()

	for tier = 1, MAX_TALENT_TIERS do
		for column = 1, NUM_TALENT_COLUMNS do
			local _, _, _, _, _, id, _, _, _, isKnown = GetTalentInfo(tier, column, activeSpec)
			if isKnown then
				local name = GetSpellInfo(id)
				changed = self:FoundSpell(id, name, "TALENT") or changed
			end
		end
	end

	return changed
end

function lib:ScanPvpTalents()
	local changed = false

	if IsWarModeDesired() then
		local selectedPvpTalents = GetAllSelectedPvpTalentIDs()
		for _, talentId in next, selectedPvpTalents do
			local _, name, _, _, _, spellId = GetPvpTalentInfoByID(talentId)
			if IsPlayerSpell(spellId) then
				changed = self:FoundSpell(spellId, name, 'PVP') or changed
			end
		end
	end

	return changed
end

local function CleanUp(id, bookType, name)
	byName[name][id] = nil
	if not next(byName[name]) then
		byName[name] = nil
	end
	byId[id] = nil
	book[id] = nil
	lastSeen[id] = nil

	lib.callbacks:Fire("LibSpellbook_Spell_Removed", id, bookType, name)
end

function lib:ScanSpellbooks()
	self.generation = self.generation + 1

	-- Scan spell tabs
	local changed = false
	for tab = 1, 2 do
		local _, _, offset, numSlots = GetSpellTabInfo(tab)
		changed = self:ScanSpellbook(BOOKTYPE_SPELL, numSlots, offset) or changed
	end

	-- Scan pet spells
	local numPetSpells = HasPetSpells()
	if numPetSpells then
		changed = self:ScanSpellbook(BOOKTYPE_PET, numPetSpells) or changed
	end

	local inCombat = InCombatLockdown()

	if not inCombat then
		changed = self:ScanTalents() or changed
	end

	changed = self:ScanPvpTalents() or changed
	changed = self:ScanRanks() or changed

	-- Remove old spells
	local current = self.generation
	for id, gen in pairs(self.spells.lastSeen) do
		if gen ~= current then
			changed = true
			local name = byId[id]
			local bookType = book[id]
			if not inCombat or bookType ~= "TALENT" then
				CleanUp(id, bookType, name)
			end
		end
	end

	-- Fire an event if anything was added or removed
	if changed then
		self.callbacks:Fire("LibSpellbook_Spells_Changed")
	end
end

function lib:HasSpells()
	return next(byId) and self.generation > 0
end
