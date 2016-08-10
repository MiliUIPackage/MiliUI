Skada:AddLoadableModule("Friendly Fire", function(Skada, L)
if Skada.db.profile.modulesBlocked.FriendlyFire then return end

local mod = Skada:NewModule(L["Friendly Fire"])
local playermod = Skada:NewModule(L["Friendly Fire"].." - "..L["List of players damaged"])
local spellmod = Skada:NewModule(L["Friendly Fire"].." - "..L["List of damaging spells"])

local db
local defaults = {
  ignoredefensive = true,
  ignoreability = false,
}

local function log_ffdamage_done(set, dmg)
	-- Get the player.
	local player = Skada:get_player(set, dmg.playerid, dmg.playername)
	if player then
		-- 
		-- Also add to set total ff damage done.
		set.ffdamagedone = set.ffdamagedone + dmg.amount
		
		-- Add spell to player if it does not exist.
		if not player.ffdamagedonespells[dmg.spellname] then
			player.ffdamagedonespells[dmg.spellname] = {id = dmg.spellid, name = dmg.spellname, damage = 0}
		end
		
		-- Add damage to target if it does not exist.
		if not player.ffdamagedonetargets[dmg.targetname] then
			player.ffdamagedonetargets[dmg.targetname] = {id = dmg.targetid, name = dmg.targetname, damage = 0}
		end
		
		-- Add to player total damage.
		player.ffdamagedone = player.ffdamagedone + dmg.amount
		
		-- Get the spell from player.
		local spell = player.ffdamagedonespells[dmg.spellname]
	    	spell.damage = spell.damage + dmg.amount
	    
	    	-- Get the target from player
	    	local target = player.ffdamagedonetargets[dmg.targetname]
	    	target.damage = target.damage + dmg.amount
	end
end

local dmg = {}

local defensive_spell = {
	[87023]  = true, -- Cauterize (Mage)
	[110914] = true, -- Dark Bargain (Warlock)
	[124255] = true, -- Stagger (Monk)
}

local ability_spell = {
	[49016] = true, -- Unholy Frenzy
	[32409] = true, -- Glyph of Shadow Word: Death -- doesnt show
	-- [31818] = true, -- Life Tap: combat log event is SPELL_CAST_SUCCESS and does not record amount, 
                           -- same with Unbound Will and prob other lock abilities with a health cost
} 

local function SpellDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	local spellId, spellName, spellSchool, amount, overkill, school, resist, block, absorb = ...
	--if srcName then Skada:Print("Friendly Fire : ", spellName, spellId, "(", srcName, ">", dstName, ")") end

	if spellId and db.ignoredefensive and defensive_spell[spellId] then return end
	if spellId and db.ignoreability and ability_spell[spellId] then return end

	dmg.playerid = srcGUID
	dmg.playername = srcName
	dmg.spellid = spellId
	dmg.spellname = spellName
	dmg.amount = (amount or 0) + (overkill or 0) + (absorb or 0)
	dmg.targetid = dstGUID
	dmg.targetname = dstName
	
	log_ffdamage_done(Skada.current, dmg)
	log_ffdamage_done(Skada.total, dmg)
end

local function SwingDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	-- White melee.
	local amount, overkill, school, resist, block, absorb = ...
	
	dmg.playerid = srcGUID
	dmg.playername = srcName
	dmg.spellid = 6603
	dmg.spellname = GetSpellInfo(6603)
	dmg.amount = (amount or 0) + (overkill or 0) + (absorb or 0)
	dmg.targetid = dstGUID
	dmg.targetname = dstName
		
	log_ffdamage_done(Skada.current, dmg)
	log_ffdamage_done(Skada.total, dmg)
end

-- this mechanism handles boss encounter debuffs that are put on a SINGLE player
-- and then hit the raid for SPELL_DAMAGE with a nil src.
-- It will charge the damage to the last player who received the debuff
local ff_debuffs = {
	{ 123788, 123792 }, 		-- Cry of Terror (HoF: Empress Shek'zeer)
	{ 123081,			-- Pungency (HoF: Garalon)
	  122835, 123092, 129815 }, 	-- Pheromones
	{ 136917, 136991, 136992 },	-- Biting Cold (ToT: Council)
	{ 136990, 136922, 136937 },	-- Frostbite (ToT: Council)
	{ 143423, 143424 },		-- Sha Sear (SoO: Sun Tenderheart)
	-- { 85415 }, 			-- Mangle (testing only)
}
local ff_debuffmap = {}
for _, di in pairs(ff_debuffs) do
  for _, did in pairs(di) do
    ff_debuffmap[did] = di
  end
end

local function DebuffApplied(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	local spellId, spellName = ...
	local di = spellId and ff_debuffmap[spellId]
	if di then
		--Skada:Print("Friendly Fire Debuff: ", spellName, "(", srcName, ">", dstName, ")")
		di.srcGUID = dstGUID
		di.srcName = dstName
	end
end

local function DebuffDamage(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	local spellId, spellName, spellSchool, samount, soverkill = ...

	local di = spellId and ff_debuffmap[spellId]
	if di and di.srcGUID and di.srcName and di.srcGUID ~= dstGUID then
		SpellDamage(timestamp, eventtype, di.srcGUID, di.srcName, 0, dstGUID, dstName, dstFlags, ...)
	end
end

function mod:Update(win, set)
	local max = 0
	
	local nr = 1
	for i, player in ipairs(set.players) do
		if player.ffdamagedone > 0 then
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			d.label = player.name
			d.value = player.ffdamagedone
			d.valuetext = Skada:FormatNumber(player.ffdamagedone)..(" (%02.1f%%)"):format(player.ffdamagedone / set.ffdamagedone * 100)
			d.id = player.id
			d.class = player.class
			
			if player.ffdamagedone > max then
				max = player.ffdamagedone
			end
			nr = nr + 1
		end
	end
	
	-- Sort the possibly changed bars.
	win.metadata.maxvalue = max
end

function spellmod:Enter(win, id, label)
	spellmod.playerid = id
	spellmod.title = label..": "..L["Friendly Fire"].." ("..L["spells"]..")"
end

function playermod:Enter(win, id, label)
	playermod.playerid = id
	playermod.title = label..": "..L["Friendly Fire"].." ("..L["targets"]..")"
end

-- Detail view of a player - spells.
function spellmod:Update(win, set)
	-- View spells for this player.
		
	local player = Skada:find_player(set, self.playerid)
	
	local nr = 1
	if player then
		for spellname, spell in pairs(player.ffdamagedonespells) do
				
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d
			
			d.label = spellname
			d.value = spell.damage
			d.icon = select(3, GetSpellInfo(spell.id))
			d.id = spellname
			d.spellid = spell.id
			d.valuetext = Skada:FormatNumber(spell.damage)..(" (%02.1f%%)"):format(spell.damage / player.ffdamagedone * 100)
			
			nr = nr + 1
		end
		
		-- Sort the possibly changed bars.
		win.metadata.maxvalue = player.ffdamagedone
	end
end

-- Detail view of a player - targets.
function playermod:Update(win, set)
	-- View targets for this player.
		
	local player = Skada:find_player(set, self.playerid)
	
	local nr = 1
	if player then
		win.metadata.maxvalue = 0
		for targetname, target in pairs(player.ffdamagedonetargets) do
				
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d

			local ptgt = Skada:find_player(set, target.id)
			if ptgt then
				d.class = ptgt.class
			else
				d.class = nil
			end
			
			d.label = targetname
			d.value = target.damage
			d.icon = nil
			d.id = targetname
			d.valuetext = Skada:FormatNumber(target.damage)..(" (%02.1f%%)"):format(target.damage / player.ffdamagedone * 100)
			
			win.metadata.maxvalue = math.max(win.metadata.maxvalue, d.value)
			nr = nr + 1
		end
	end
end

function mod:OnEnable()
	spellmod.metadata 		= {}
	playermod.metadata 		= {}
	mod.metadata 			= {click1 = spellmod, click2 = playermod, showspots = true}

	Skada:RegisterForCL(DebuffApplied, 'SPELL_AURA_APPLIED', {dst_is_interesting_nopets = true})
	Skada:RegisterForCL(DebuffApplied, 'SPELL_AURA_APPLIED_DOSE', {dst_is_interesting_nopets = true})
	Skada:RegisterForCL(DebuffDamage,  'SPELL_DAMAGE', {dst_is_interesting_nopets = true})

	Skada:RegisterForCL(SpellDamage, 'SPELL_DAMAGE', {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
	Skada:RegisterForCL(SpellDamage, 'SPELL_PERIODIC_DAMAGE', {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
	Skada:RegisterForCL(SpellDamage, 'SPELL_BUILDING_DAMAGE', {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
	Skada:RegisterForCL(SpellDamage, 'RANGE_DAMAGE', {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})
	
	Skada:RegisterForCL(SwingDamage, 'SWING_DAMAGE', {dst_is_interesting_nopets = true, src_is_interesting_nopets = true})

	Skada:AddMode(self)

  	db = Skada.db.profile.ffoptions or {}
	Skada.db.profile.ffoptions = db
  	for k,v in pairs(defaults) do
	   	if db[k] == nil then
      			db[k] = v
    		end	
  	end
  	Skada.options.args.ffoptions = {
    		type = "group",
   	 	name = L["Friendly Fire"],
    		order=110,
    		set = function(info,val)
          		db[info[#info]] = val;
        	end,
    		get = function(info)
          		return db[info[#info]]
        	end,
    		args = {
      			ignoredefensive = {
        			type="toggle",
				width="double",
        			name=L["Ignore defensive damage"],
        			desc=L["Ignore delayed damage from defensive abilities, such as Monk Stagger"],
       	 			order=10,
      			},
      			ignoreability = {
        			type="toggle",
				width="double",
        			name=L["Ignore class abilities"],
        			desc=L["Ignore damage from other class abilities, such as Unholy Frenzy"],
       	 			order=20,
      			},
    		}
 	}
end

function mod:OnDisable()
	Skada:RemoveMode(self)
end


-- Called by Skada when a new player is added to a set.
function mod:AddPlayerAttributes(player)
	if not player.ffdamagedone then
		player.ffdamagedone = 0
		player.ffdamagedonespells = {}
		player.ffdamagedonetargets = {}
	end
end

-- Called by Skada when a new set is created.
function mod:AddSetAttributes(set)
	if not set.ffdamagedone then
		set.ffdamagedone = 0
	end
end

function mod:GetSetSummary(set)
	return Skada:FormatNumber(set.ffdamagedone)
end
end)
