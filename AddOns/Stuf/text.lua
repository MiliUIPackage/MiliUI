if not Stuf then return end

local Stuf = Stuf
local su = Stuf.units
local s40, dbg
Stuf:AddOnInit(function(_, idbg)
	dbg = idbg
	s40 = Stuf.supportspell and GetSpellTexture(Stuf.supportspell) and Stuf.supportspell
end)

local CreateFrame = CreateFrame
local UnitCanAttack = UnitCanAttack
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsDeadOrGhost, UnitIsDead, UnitIsGhost, UnitIsConnected = UnitIsDeadOrGhost, UnitIsDead, UnitIsGhost, UnitIsConnected
local UnitIsAFK, UnitIsDND = UnitIsAFK, UnitIsDND
local UnitSex = UnitSex
local UnitIsVisible, GetSpellTexture, IsSpellInRange, UnitInRange = UnitIsVisible, GetSpellTexture, IsSpellInRange, UnitInRange
local UnitAffectingCombat, InCombatLockdown = UnitAffectingCombat, InCombatLockdown

local format, strmatch, gsub = format, strmatch, gsub
local type = type
local loadstring = loadstring

local nK, nM = "K", "M"

local specialchars = { ["nl"] = "\n", ["%"] = "%%", ["lp"] = "%(", ["rp"] = "%)", }
local conditions = {
	pc = function(ca, unit) return ca.pc end,
	npc = function(ca, unit) return not ca.pc end,
	pvp = function(ca, unit) return ca.pvp end,
	male = function(ca, unit) return UnitSex(unit) == 2 end,
	female = function(ca, unit) return UnitSex(unit) == 3 end,
	helpful = function(ca, unit) return ca.assist end,
	hostile = function(ca, unit) return ca.hostile end,
	attackable = function(ca, unit) return ca.attackable end,
	tapped = function(ca, unit) return UnitIsTapDenied(unit) end,
	alive = function(ca, unit) return not ca.dead end,
	dead = function(ca, unit) return ca.dead and UnitIsDead(unit) end,
	ghost = function(ca, unit) return ca.dead and UnitIsGhost(unit) end,
	offline = function(ca, unit) return not UnitIsConnected(unit) end,
	afk = function(ca, unit) return UnitIsAFK(unit) end,
	dnd = function(ca, unit) return UnitIsDND(unit) end,
	ingroup = function(ca, unit) return ca.ingroup end,
	oor = function(ca, unit)
		if ( unit == "player" or not ca.assist or ca.dead or not UnitIsConnected(unit) ) then
			return false
		elseif ( not UnitIsVisible(unit) ) or
		       ( s40 and IsSpellInRange(s40, BOOKTYPE_SPELL, unit) == 0 ) or
			   ( not s40 and Stuf.ingroup and ca.ingroup and not UnitInRange(unit) ) then
			return true
		end
		return false
	end,
	combat = function(ca, unit) return ca.incombat end,
	selfcombat = function(ca, unit) return InCombatLockdown() end,
	aggro = function(ca, unit) return ca.aggro end,
	hp10 = function(ca, unit) return (ca.frachp or 1) < 0.1 end,
	hp20 = function(ca, unit) return (ca.frachp or 1) < 0.2 end,
	hp35 = function(ca, unit) return (ca.frachp or 1) < 0.35 end,
	hp99 = function(ca, unit) return (ca.frachp or 1) < 0.99 end,
	mp15 = function(ca, unit) return (ca.fracmp or 1) < 0.15 end,
	mp99 = function(ca, unit) return (ca.fracmp or 1) < 0.99 end,
	manapower = function(ca, unit) return ca.powertype == 0 end,
	boss = function(ca, unit) return ca.classification == dbg.classification.worldboss end,
}
Stuf.conditions = conditions
Stuf.specialchars = specialchars

do  -- custom text handlers -------------------------------------------------------------------------------------------
	local colortags = Stuf.colormethods
	local rer = Stuf.RegisterElementRefresh
	local metrotags = { "oor", "aggro", }
	local reactiontags = { "reaction", "creature", "pvp", "hostile", "attack", "helpful", "afk", "dnd", "combat", "tapped", "offline", }
	local lifestatus = { "dead", "ghost", "alive", }
	local function TextFormat(t, r, g, b)
		if r then
			if type(t) ~= "number" then
				return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, t)
			end
			local tnum = t < 0 and t * -1 or t
			if tnum < shortk then
				return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, t)
			elseif tnum < 10000 then
				-- return format("|cff%02x%02x%02x%.1f%s|r", r * 255, g * 255, b * 255, t * 0.001, nK)
				return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, t)
			elseif tnum < 1000000 then
				t = t * 0.0001
				local t1, t2 = math.modf(t)
				if (t2 > 0) then 
					return format("|cff%02x%02x%02x%.1f%s|r", r * 255, g * 255, b * 255, t, "萬")
				else 
					return format("|cff%02x%02x%02x%d%s|r", r * 255, g * 255, b * 255, t, "萬")
				end
			elseif tnum < 100000000 then
				return format("|cff%02x%02x%02x%d%s|r", r * 255, g * 255, b * 255, t * 0.0001, "萬")
			else
				return format("|cff%02x%02x%02x%.2f%s|r", r * 255, g * 255, b * 255, t * 0.00000001, "億")
			end
		else
			if type(t) ~= "number" then
				return t
			end
			local tnum = t < 0 and t * -1 or t
			if tnum < shortk then
				return t
			elseif tnum < 10000 then
				-- return format("%.1f%s", t * 0.001, nK)
				return t
			elseif tnum < 1000000 then
				t = format("%.1f", t * 0.0001)
				local t1, t2 = math.modf(t)
				if (t2 > 0) then 
					return t.."萬"
				else 
					return t1.."萬"
				end
			elseif tnum < 100000000 then
				return format("%d萬", t * 0.0001)
			else 
				return format("%.2f億", t * 0.00000001)
			end
		end
	end
	local function AddAdvanceText(fs, a1, ...)
		fs:SetFormattedText(gsub(a1 or "", "||", "|"), ...)
	end
	local function SetText2(fs, text, f)  -- handles option to hide text frame if empty
		fs:SetText(text)
		if not text or text == "" or text == " " then
			f:Hide()
		else
			f:Show()
		end
	end
	local function UpdateText(unit, uf, f, _, _, config)
		if not f or f.db.hide then return end
		local dbt, cache = f.db, uf.cache
		if dbt.useadvance and f.textcode then
			AddAdvanceText(f.fontstring, f.textcode(unit, cache, f))
		else
			local text = dbt.pattern or ""
			for i = 1, 20, 1 do
				local pat = strmatch(text, "%[(.-)%]")
				if not pat then break end
				local pat1, pat2 = strmatch(pat, "(.+):(.+)")
				if pat1 and pat2 then  -- [something:infotag]
					local replace
					itag = cache[pat2] or specialchars[pat2] or pat2
					itag = (itag == true and pat2) or itag
					if itag ~= "" then
						local ct = colortags[pat1]
						if ct then  -- [colortag:infotag]
							replace = ((pat1 == "custom" or pat1 == "solid") and TextFormat(itag)) or TextFormat(itag, ct(uf, dbt, nil, "fontcolor"))
						else  -- probably [colortag_if_condition:infotag]
							local clr, cond = strmatch(pat1, "(.+)_if_(.+)")
							local iffy
							if not clr then
								clr, cond = strmatch(pat1, "(.+)_ifnot_(.+)")
								iffy = true
							end
							if colortags[clr or "blah"] then
								local condfunc = conditions[cond or "blah"]
								condfunc = condfunc and condfunc(cache, unit)
								if (not iffy and condfunc) or (iffy and not condfunc) then
									replace = ((clr == "custom" or clr == "solid") and TextFormat(itag)) or TextFormat(itag, colortags[clr or "blah"](uf, dbt, nil, "fontcolor"))
								end
							end
						end
					end
					text = gsub(text, "%[(.-)%]", replace or "", 1)
				else  -- [infotag]
					text = gsub(text, "%[(.-)%]", TextFormat(cache[pat] or specialchars[pat] or pat) or "", 1)
				end
			end
			f.fontstring:SetTexty(text, f)
		end
	end
	local function UpdateMouseText(unit, uf, f, _, _, config)
		if not f or f.db.hide then return end
		if GetMouseFocus() == uf then
			UpdateText(unit, uf, f, nil, nil, config)
			f:Show()
		else
			f:Hide()
		end
	end
	local function CreateText(unit, uf, name, db)
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db)
			f.fontstring = f:CreateFontString(nil, "ARTWORK")
			f.fontstring:SetAllPoints(f)
			uf.refreshfuncs[name] = UpdateText
		else
			f:Show()
		end
		Stuf:UpdateBaseLook(uf, f, db, db.framelevel or 3)
		shortk = dbg.shortk
		nK, nM = dbg.nK or "K", dbg.nM or "M"
		
		local t = f.fontstring
		Stuf:UpdateTextLook( t, db.font, nil, db.fontsize, db.fontflags, db.justifyH, db.justifyV,
		                     db.fontcolor or Stuf.whitecolor, db.shadowx, db.shadowy )
		t:SetNonSpaceWrap(true)
		
		if not db.pattern then return end  -- check text patterns to determine how often to update them
		
		local pattern = db.pattern
		local ismetro = uf.ismetro
		f.dbid = (f.dbid or 0) + 1
		if f.dbid > 1 then
			rer(Stuf, uf, name, "metroelements", nil)
			rer(Stuf, uf, name, "deathelements", nil)
			rer(Stuf, uf, name, "healthelements", nil)
			rer(Stuf, uf, name, "powerelements", nil)
			rer(Stuf, uf, name, "powercolorelements", nil)
			rer(Stuf, uf, name, "reactionelements", nil)
			uf.skiprefreshelement[name] = nil
		end
		if db.onmouse then
			uf.mouseover = uf.mouseover or { }
			uf.mouseover[name] = UpdateMouseText
			uf.refreshfuncs[name] = UpdateMouseText
		elseif uf.mouseover and uf.mouseover[name] then
			uf.mouseover[name] = nil
			uf.refreshfuncs[name] = UpdateText
		end
		t.SetTexty = (db.emptyhide and SetText2) or f.fontstring.SetText
		if db.useadvance then  -- set up text to work with advanced code option
			if db.frequent then
				rer(Stuf, uf, name, "metroelements", true)
			end
			local tfunc, err = loadstring("return "..(db.advancecode or "nil"), unit.." "..name)
			f.textcode = tfunc and tfunc()
		else  -- check text patterns to see when it should update
			local found1, found2, found3
			for _, keyword in ipairs(metrotags) do
				if strmatch(pattern, keyword) then
					found1 = true
					break
				end
			end
			if found1 then
				rer(Stuf, uf, name, "metroelements", true)
				if Stuf.EnableAggro and strmatch(pattern, "aggro") then
					Stuf:EnableAggro()
				end
			end
			
			for _, keyword in ipairs(lifestatus) do
				if strmatch(pattern, keyword) then
					found2 = true
					break
				end
			end
			if found2 then
				rer(Stuf, uf, name, "deathelements", true)
			end
			if strmatch(pattern, "hp") or strmatch(pattern, "level") then
				rer(Stuf, uf, name, "healthelements", true)
				found2 = true
			end
			if strmatch(pattern, "mp") or (Stuf.CLS == "WARLOCK" and strmatch(pattern, "shards")) then
				rer(Stuf, uf, name, "powerelements", true)
				found2 = true
			end
			if strmatch(pattern, "power") then
				rer(Stuf, uf, name, "powercolorelements", true)
				found2 = true
			end

			for _, keyword in ipairs(reactiontags) do
				if strmatch(pattern, keyword) then
					found3 = true
					break
				end
			end
			rer(Stuf, uf, name, "reactionelements", (found3 and true) or nil)
			if strmatch(pattern, "guild") then
				if not uf.checkguild then
					uf.checkguild = true
					Stuf.UpdateGuild(unit, uf, f)
				end
			end
			if uf.ismetro then
				uf.skiprefreshelement[name] = ((found2 or found3) and not found1 and true) or nil
			end
		end
		if Stuf.inworld then
			uf.refreshfuncs[name](unit, uf, f)
		end
	end
	for i = 1, 8, 1 do
		Stuf:AddBuilder("text"..i, CreateText)
	end
end


do  -- Combat Text ----------------------------------------------------------------------------------------------------
	local CombatFeedbackText = CombatFeedbackText
	local function UpdateCombatText(unit, cevent, flag, amount, ctype)
		local uf = su[unit]
		local f = uf and not uf.hidden and uf.combattext
		if not f or f.db.hide then return end
		
		local r, g, b, text, symbol
		if cevent == "WOUND" then
			if amount ~= 0 then
				if amount > 999999 then
					text = format("-%.2fM", amount/1000000)
				elseif amount > 99999 then
					text = format("-%dK", amount/1000)
				else
					text = "-"..amount
				end
				if flag == "CRITICAL" then
					symbol = "!"
				elseif flag == "CRUSHING" then
					symbol = "~"
				elseif flags == "GLANCING" then
					symbol = "'"
				end
				r, g, b = 1, 0, 0
			elseif flag == "ABSORB" then
				text = CombatFeedbackText[flag]
			elseif flag == "BLOCK" then
				text = CombatFeedbackText[flag]
			elseif flag == "RESIST" then
				text = CombatFeedbackText[flag]
			else
				text = CombatFeedbackText[flag]
			end
		elseif cevent == "HEAL" then
			if amount > 999999 then
				text = format("+%.2fM", amount/1000000)
				elseif amount > 99999 then
					text = format("-%dK", amount/1000)
			else
				text = "+"..amount
			end
			symbol = (flag == "CRITICAL" and "!") or ""
			r, g, b = 0, 1, 0
		elseif cevent == "BLOCK" then
			text = CombatFeedbackText[cevent]
			r, g, b = 1, 1, 0
		elseif cevent == "IMMUNE" then
			text = CombatFeedbackText[cevent]
			r, g, b = 1, 1, 0
		elseif cevent == "ENERGIZE" then
			text = amount
			symbol = (flag == "CRITICAL" and "!") or ""
			r, g, b = 0.41, 0.8, 0.94
		else
			text = CombatFeedbackText[cevent or "MISS"]
		end
		f:AddMessage((text or "")..(symbol or ""), r or 1, g or 1, b or 1)
	end
	local function ClearCombatText(unit, uf)
		if uf and not uf.hidden and uf.combattext then 
			uf.combattext:Clear()
		end
	end
	Stuf:AddBuilder("combattext", function(unit, uf, name, db, _, config)
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db, "MessageFrame")
			f:SetTimeVisible(1.5)
			f:SetFadeDuration(0.5)
			f:SetInsertMode("BOTTOM")
			uf.refreshfuncs[name] = ClearCombatText
			Stuf:AddEvent("UNIT_COMBAT", UpdateCombatText)
			--Stuf:AddEvent("UNIT_SPELLMISS", UpdateCombatText)
		else
			f:Show()
		end
		Stuf:UpdateBaseLook(uf, f, db, db.framelevel or 4)
		db.h = max(db.h, (db.fontsize or 12) + 2)
		f:SetHeight(db.h)
		Stuf:UpdateTextLook(f, db.font, nil, db.fontsize, db.fontflags, db.justifyH, "none", nil, db.shadowx, db.shadowy)

		if config then
			Stuf.combattextconfig = Stuf.combattextconfig or function(this, a1)
				local e = (this.elapsed or 0) + a1
				if e > 1.75 then
					e = 0
					this.rand = (this.rand or 0) + 1
					if this.rand == 1 then
						UpdateCombatText(this:GetParent().unit, "WOUND", "CRITICAL", 1234)
					elseif this.rand == 2 then
						UpdateCombatText(this:GetParent().unit, "HEAL", "", 4321)
					else
						UpdateCombatText(this:GetParent().unit, "BLOCK")
						this.rand = 0
					end
				end
				this.elapsed = e
			end
			f:SetScript("OnUpdate", Stuf.combattextconfig)
		else
			f:Clear()
			f:SetScript("OnUpdate", nil)
		end
	end)
end


do  -- Group Number Text ----------------------------------------------------------------------------------------------
	local GetRaidRosterInfo, UnitIsUnit = GetRaidRosterInfo, UnitIsUnit
	local UpdateGroupText
	Stuf:AddBuilder("grouptext", function(unit, uf, name, db, _, config)
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db)
			f.fontstring = f:CreateFontString(nil, "ARTWORK")
			f.fontstring:SetAllPoints()
			if not UpdateGroupText then
				local function updategroup(f, show, text)
					if f and not f.db.hide then
						f[show](f)
						if text then
							f.fontstring:SetText(text)
						end
					end
				end
				UpdateGroupText = function(_, _, _, _, _, config)
					local pla, tar = su.player, su.target
					local pg, tg = pla and pla.grouptext, tar and tar.grouptext
					
					if config then
						updategroup(pg, "Show", 3)
						updategroup(tg, "Show", 3)
						return
					elseif Stuf.numraid == 0 then
						updategroup(pg, "Hide")
						updategroup(tg, "Hide")
						return
					end
					
					local foundplayer, foundtarget
					if not tar or not tar.cache.ingroup then 
						foundtarget = true
						updategroup(tg, "Hide")
					end
					for i = 1, Stuf.numraid, 1 do
						local _, _, subgroup = GetRaidRosterInfo(i)
						if not foundplayer and UnitIsUnit("raid"..i, "player") then
							updategroup(pg, "Show", subgroup)
							foundplayer = true
						end
						if not foundtarget and UnitIsUnit("raid"..i, "target") then
							updategroup(tg, "Show", subgroup)
							foundtarget = true
						end
						if foundplayer and foundtarget then break end
					end
				end
			end
			uf.refreshfuncs[name] = UpdateGroupText
			Stuf:AddEvent("RAID_ROSTER_UPDATE", UpdateGroupText)
		end

		Stuf:UpdateBaseLook(uf, f, db, db.framelevel or 4)
		Stuf:UpdateTextLook( f.fontstring, db.font, nil, db.fontsize, db.fontflags, db.justifyH, db.justifyV,
		                     db.fontcolor or Stuf.whitecolor, db.shadowx, db.shadowy )
		if Stuf.inworld then
			UpdateGroupText(unit, uf, name, db, nil, config)
		end
	end)
end


do  -- Pet Timer ------------------------------------------------------------------------------------------------------
	local UpdatePetTime
	Stuf:AddBuilder("pettime", function(unit, uf, name, db, _, config)
		if unit ~= "pet" then return end
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db)
			f.fontstring = f:CreateFontString(nil, "ARTWORK")
			f.fontstring:SetAllPoints()
			local GetPetTimeRemaining = GetPetTimeRemaining
			UpdatePetTime = function(unit, uf, f, _, _, config)
				uf = uf or uf[unit]
				f = f or (uf and not uf.hidden and uf.pettime)
				if not f then return end
				local remain = (config and 30000) or GetPetTimeRemaining()
				if remain and remain > 0 and not uf.cache.dead then
					uf.metroelements.pettime = UpdatePetTime
					if remain < 60000 then
						f.fontstring:SetFormattedText("%d", remain * 0.001)
					else
						f.fontstring:SetFormattedText("%dm", 1 + remain * 0.00001666)
					end
					f:Show()
				else
					uf.metroelements.pettime = nil
					f.fontstring:SetText("")
					f:Hide()
				end
			end
			uf.refreshfuncs[name] = UpdatePetTime
		end
		
		Stuf:UpdateBaseLook(uf, f, db, db.framelevel or 4)
		Stuf:UpdateTextLook( f.fontstring, db.font, nil, db.fontsize, db.fontflags, db.justifyH, db.justifyV,
		                     db.fontcolor or Stuf.whitecolor, db.shadowx, db.shadowy )
		if Stuf.inworld then
			UpdatePetTime(unit, uf, f, nil, nil, config)
		end
	end)
end
