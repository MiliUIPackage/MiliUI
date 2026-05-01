if not Stuf then return end

local Stuf = Stuf
local su = Stuf.units
local s40, dbg
Stuf:AddOnInit(function(_, idbg)
	dbg = idbg
	s40 = Stuf.supportspell and (GetSpellTexture and GetSpellTexture(Stuf.supportspell) or true) and Stuf.supportspell
end)

local CreateFrame = CreateFrame
local UnitCanAttack = UnitCanAttack
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsDeadOrGhost, UnitIsDead, UnitIsGhost, UnitIsConnected = UnitIsDeadOrGhost, UnitIsDead, UnitIsGhost, UnitIsConnected
local UnitIsAFK, UnitIsDND = UnitIsAFK, UnitIsDND
local UnitSex = UnitSex
local UnitIsVisible = UnitIsVisible
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local IsSpellInRange = IsSpellInRange
local C_SpellIsInRange = C_Spell and C_Spell.IsSpellInRange
local UnitInRange = UnitInRange
local UnitAffectingCombat, InCombatLockdown = UnitAffectingCombat, InCombatLockdown

local format, strmatch, gsub = format, strmatch, gsub
local type = type
local loadstring = loadstring

local nK, nM = "K", "M"

local specialchars = { ["nl"] = "\n", ["%"] = "%%", ["lp"] = "%(", ["rp"] = "%)", }
-- WoW 12.0+: UnitIsVisible / UnitInRange return "secret booleans" that cannot
-- be used with not / == / ~= / tostring-then-compare.
-- issecretvalue() is a C-side function returning a plain boolean.
-- When secret, default to true (assume visible/in-range) to avoid false OOR.
local _issecretvalue = issecretvalue
local function desecret(v)
	if _issecretvalue and _issecretvalue(v) then return true end
	return v and true or false
end
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
		elseif ( not desecret(UnitIsVisible(unit)) ) or
		       ( s40 and not C_SpellIsInRange and IsSpellInRange and IsSpellInRange(s40, unit) == 0 ) or
			   ( not s40 and Stuf.ingroup and ca.ingroup and not desecret(UnitInRange(unit)) ) or
		( s40 and C_SpellIsInRange and C_SpellIsInRange(s40, unit) == false ) then
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
	-- Secret value detection and safe C-side formatter (same approach as MSUF)
	local _issecret = _G.issecretvalue
	local _abbreviate = _G.AbbreviateLargeNumbers or _G.ShortenNumber or _G.AbbreviateNumbers
	local function IsSecret(v)
		return _issecret and _issecret(v) and true or false
	end
	local _CSU = _G.C_StringUtil
	local function SafeNumStr(t)
		-- Secret: only C_StringUtil.RoundToNearestString returns a PLAIN string from a secret.
		-- AbbreviateLargeNumbers returns a secret string which still can't be used in gsub.
		if IsSecret(t) then
			if _CSU and _CSU.RoundToNearestString then
				local s = _CSU.RoundToNearestString(t, 1)
				if s then return tostring(s) end
			end
			return ""  -- can't format safely
		end
		-- Plain number: normal K/M shortening
		local n = t < 0 and -t or t
		if n >= 1000000 then return format("%.1f%s", t * 0.000001, nM)
		elseif n >= shortk then return format("%.1f%s", t * 0.001, nK)
		else return tostring(t)
		end
	end
	local function TextFormat(t, r, g, b)
		if type(t) ~= "number" then
			local ts = tostring(t)
			if r then return format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, ts) end
			return ts
		end
		local ts = SafeNumStr(t)
		if r then return format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, ts) end
		return ts
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
	-- Secret-value tags: raw UnitHealth/Power values that can ONLY go to C-side APIs.
	-- Never pass these through gsub — use SetFormattedText instead.
	-- Plain percent tags are safe because UnitHealthPercent/UnitPowerPercent return plain numbers.
	local DIRECT_TAGS = {
		curhp  = function(u) return UnitHealth(u) end,
		maxhp  = function(u) return UnitHealthMax(u) end,
		curmp  = function(u) return UnitPower(u) end,
		maxmp  = function(u) return UnitPowerMax(u) end,
	}

	local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
	local UnitPower, UnitPowerMax   = UnitPower, UnitPowerMax
	local UnitHealthPercent         = UnitHealthPercent
	local UnitPowerPercent          = UnitPowerPercent

	local function UpdateText(unit, uf, f, _, _, config)
		if not f or f.db.hide then return end
		local dbt, cache = f.db, uf.cache
		if dbt.useadvance and f.textcode then
			AddAdvanceText(f.fontstring, f.textcode(unit, cache, f))
		else
			local text = dbt.pattern or ""

			-- Phase 1+2: ALL health/power values are secret in 12.0.1.
			-- Replace every secret tag with a \001N marker and collect raw values.
			-- SetFormattedText will pass them to C which handles secrets natively.
			local rawArgs = {}
			local argCount = 0
			local _percentMask = {}  -- MiliUI
			local function collectTag(placeholder, valueFn, isPercent)
				if strmatch(text, placeholder) then
					argCount = argCount + 1
					rawArgs[argCount] = valueFn(unit)
					if isPercent then _percentMask[argCount] = true end  -- MiliUI
					text = gsub(text, placeholder, "\001" .. argCount)
				end
			end
				-- CurveConstants.ScaleTo100 scales the result to 0-100.
			-- Fallback: passing 'true' achieves the same effect (MSUF pattern).
			local _scale = (CurveConstants and CurveConstants.ScaleTo100) or true
			collectTag("%[perchp%]", function(u) return UnitHealthPercent(u, false, _scale) end, true)  -- MiliUI
			collectTag("%[percmp%]", function(u)
				local pt = UnitPowerType(u)
				return UnitPowerPercent(u, pt, false, _scale)
			end, true)  -- MiliUI
			for tag, valueFn in pairs(DIRECT_TAGS) do
				collectTag("%[" .. tag .. "%]", valueFn)
			end

			-- Phase 3: normal gsub loop for all remaining safe tags
			for i = 1, 20, 1 do
				local pat = strmatch(text, "%[(.-)%]")
				if not pat then break end
				local pat1, pat2 = strmatch(pat, "(.+):(.+)")
				if pat1 and pat2 then  -- [something:infotag]
					local replace
					itag = cache[pat2] or specialchars[pat2] or pat2
					if not IsSecret(itag) then
						if itag == true then itag = pat2 end
						if itag == "" then itag = nil end
					end
					if itag and not IsSecret(itag) then
						local ct = colortags[pat1]
						if ct then
							replace = ((pat1 == "custom" or pat1 == "solid") and TextFormat(itag)) or TextFormat(itag, ct(uf, dbt, nil, "fontcolor"))
						else
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
					local rep = replace or ""
					if IsSecret(rep) then rep = "" end
					text = gsub(text, "%[(.-)%]", rep, 1)
				else  -- [infotag]
					local val = cache[pat] or specialchars[pat] or pat
					local rep2
					if IsSecret(val) then
						rep2 = ""
					else
						rep2 = TextFormat(val) or ""
						if IsSecret(rep2) then rep2 = "" end
					end
					text = gsub(text, "%[(.-)%]", rep2, 1)
				end
			end

			-- Phase 4: walk the text scanning for \001N markers (any index, any frequency).
			-- AbbreviateLargeNumbers(secret) returns a secret string; .. concatenation is
			-- allowed on secret strings; SetText(secretString) renders correctly.
			if argCount > 0 then
				local _abbrev_orig = _G.AbbreviateLargeNumbers or _G.ShortenNumber
				-- MiliUI 改動: 開啟在地化縮寫時用 AbbreviateNumbers (萬/億)，百分比走原函式避免 secret 處理異常
				local _abbrev_locale = _G.MiliUI_DB and _G.MiliUI_DB.localeNumberAbbrev ~= false and _G.AbbreviateNumbers
				local _abbrev = _abbrev_locale or _abbrev_orig
				local result = ""
				local pos = 1
				local len = #text
				while pos <= len do
					local ms = text:find("\001", pos, true)
					if not ms then
						result = result .. text:sub(pos)
						break
					end
					-- plain text before the marker
					result = result .. text:sub(pos, ms - 1)
					-- single digit index after \001
					local idx = tonumber(text:sub(ms + 1, ms + 1))
					if idx and rawArgs[idx] then
						local _fn = _percentMask[idx] and _abbrev_orig or _abbrev  -- MiliUI
						local abbrevd = _fn and _fn(rawArgs[idx]) or rawArgs[idx]
						-- strip space before K/M/B/T suffixes e.g. "45.0 K" -> "45.0K"
						-- only safe on plain strings; secret strings can't be gsub'd
						if not IsSecret(abbrevd) then
							abbrevd = gsub(abbrevd, " ([KMBTkmbt])", "%1")
						end
						result = result .. abbrevd
						pos = ms + 2
					else
						result = result .. "\001"
						pos = ms + 1
					end
				end
				f.fontstring:SetTexty(result, f)
			else
				f.fontstring:SetTexty(text, f)
			end
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
	local GetRaidRosterInfo = GetRaidRosterInfo  -- still a global in 12.0, no namespace change
	local UnitIsUnit = UnitIsUnit
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
			local GetPetTimeRemaining = GetPetTimeRemaining or function() return nil end
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
