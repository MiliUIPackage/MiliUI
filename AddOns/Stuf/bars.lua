if not Stuf then return end

local Stuf = Stuf
local su = Stuf.units
local dbg, CLS = UnitClass("player")
Stuf:AddOnInit(function(_, idbg, iCLS)
	dbg = idbg
	CLS = iCLS
end)

local floor, sin = math.floor, math.sin
local CreateFrame = CreateFrame
local GetTime = GetTime
local GameTooltip = GameTooltip
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitHealthMax   = UnitHealthMax
local UnitHealthPercent = UnitHealthPercent
-- oUF-style heal prediction calculator (secret-value-safe absorbs + incoming heals)
-- NOTE: In 12.0.1 ALL unit numeric APIs return secret values — no Lua comparisons allowed.
-- UnitGetIncomingHeals and UnitGetTotalAbsorbs are also secret; do NOT use them for guards.
local UnitGetDetailedHealPrediction = UnitGetDetailedHealPrediction
local CreateUnitHealPredictionCalc  = CreateUnitHealPredictionCalculator
local stamin, stahr = 1/60, 1/3600

local methodcolor = Stuf.GetColorFromMethod
local function BarFaderOnUpdate(this, a1)  -- loss fader
	local alp = this.alp - a1
	this.barfade:SetAlpha((alp < 0 and 0) or (alp > 0.8 and 0.8) or alp)
	if alp < 0 then 
		this:SetScript("OnUpdate", nil)
	end
	this.alp = alp
end
local function SmoothBarOnUpdate(this, a1)  -- smooth bar
	local alp = this.alp - a1
	if alp < 0.02 then
		this.bar:SetValue(this.smoothend, this.bvalue)
		this.alp = 0
		this:SetScript("OnUpdate", nil)
	else
		this.bar:SetValue(this.smoothend + (this.smoothdif * alp * 2), this.bvalue)
		this.alp = alp
	end
end
local function UpdateStatusBar(unit, uf, f, reset, frac)
	if not f then return end
	local db, bar, bv = f.db, f.bar, f.bvalue or 1

	-- NATIVE STATUSBAR PATH (hpbar/mpbar): drive with raw secret values via C API
	if f.nativeBar then
		local nb = f.nativeBar
		local cache = uf and uf.cache
		if cache then
			local ishp = (f.ename == "hpbar")
			local cur = ishp and cache.curhp or cache.curmp
			local max = ishp and cache.maxhp or cache.maxmp
			if max then
				nb:SetMinMaxValues(0, max)  -- C handles secret values natively
				nb:SetValue(cur)            -- C handles secret values natively
			end
		end
		-- refresh coloring using frac from cache (safe normal number)
		local safefrac = (f.ename == "hpbar") and (cache and cache.frachp or 1) or (cache and cache.fracmp or 1)
		if f.barth then
			nb:SetStatusBarColor(methodcolor(Stuf, f.barth, uf, db, safefrac, "barcolor", "baralpha"))
		end
		if f.bgth then
			f.bg:SetVertexColor(methodcolor(Stuf, f.bgth, uf, db, safefrac, "bgcolor", "bgalpha"))
		end

		-- ===== INCOMING HEALS + ABSORB SHIELDS overlay (hpbar only) =====
		-- GOLDEN RULE: In 12.0.1, ALL unit numeric APIs return secret values.
		-- Never use them in if/then, comparisons, or arithmetic.
		-- pcall wraps SetMinMaxValues/SetValue to silently swallow nil/NaN/out-of-range
		-- values that an uninitialized calculator returns during options-panel preview.
		-- In real gameplay the calculator is properly fed and C handles secrets natively.
		if f.ename == "hpbar" and f._hpCalc then
			local maxHP = UnitHealthMax(unit)  -- secret; passed to C only
			if UnitGetDetailedHealPrediction then
				UnitGetDetailedHealPrediction(unit, "player", f._hpCalc)
			end

			-- MASKING MODEL:
			-- All three bars share SetAllPoints(barbase) and always draw from pixel 0.
			-- SetMinMaxValues cannot spatially shift a bar's start position.
			-- Visibility of deltas is achieved by layering: nativeBar (top) masks
			-- 0→currentHP, leaving only the delta regions of lower bars visible.
			--
			-- shieldbar (lowest):  fills 0 → currentHP+absorb
			-- incbar   (middle):   fills 0 → currentHP+heal   (covers shieldbar 0→healEnd)
			-- nativeBar(top):      fills 0 → currentHP        (masks both for 0→currentHP)
			--
			-- Visible result: health | green heal delta | blue shield delta | empty

			if db.inc and f.incbar then
				-- MSUF texture-anchor approach:
				-- Anchor incbar to the moving edge of nativeBar's StatusBarTexture.
				-- Horizontal: anchor LEFT edge to texture RIGHT (or RIGHT to LEFT if reversed).
				-- Vertical:   anchor BOTTOM edge to texture TOP (or TOP to BOTTOM if reversed).
				local hpTex = f.nativeBar and f.nativeBar:GetStatusBarTexture()
				if hpTex then
					local rev  = db.reverse  and true or false
					local vert = db.vertical and true or false
					if f.incbar._anchorTex ~= hpTex or f.incbar._anchorRev ~= rev or f.incbar._anchorVert ~= vert then
						f.incbar:ClearAllPoints()
						if vert then
							if rev then
								-- Vertical reverse: health fills top-to-bottom; incbar extends above texture top edge
								f.incbar:SetPoint("BOTTOMLEFT",  hpTex, "TOPLEFT",  0, 0)
								f.incbar:SetPoint("BOTTOMRIGHT", hpTex, "TOPRIGHT", 0, 0)
							else
								-- Vertical normal: health fills bottom-to-top; incbar extends above texture top edge
								f.incbar:SetPoint("BOTTOMLEFT",  hpTex, "TOPLEFT",  0, 0)
								f.incbar:SetPoint("BOTTOMRIGHT", hpTex, "TOPRIGHT", 0, 0)
							end
						else
							if rev then
								-- Horizontal reverse: health fills right-to-left; incbar extends leftward
								f.incbar:SetPoint("TOPRIGHT",    hpTex, "TOPLEFT",    0, 0)
								f.incbar:SetPoint("BOTTOMRIGHT", hpTex, "BOTTOMLEFT", 0, 0)
							else
								-- Horizontal normal: health fills left-to-right; incbar extends rightward
								f.incbar:SetPoint("TOPLEFT",    hpTex, "TOPRIGHT",    0, 0)
								f.incbar:SetPoint("BOTTOMLEFT", hpTex, "BOTTOMRIGHT", 0, 0)
							end
						end
						f.incbar._anchorTex  = hpTex
						f.incbar._anchorRev  = rev
						f.incbar._anchorVert = vert
					end
				end
				local allHeal = f._hpCalc:GetIncomingHeals()
				pcall(function()
					f.incbar:SetMinMaxValues(0, maxHP)
					f.incbar:SetValue(allHeal)
					f.incbar:Show()
				end)
			end

			if db.shield and f.shieldbar then
				local damageAbsorbAmount = f._hpCalc:GetDamageAbsorbs()
				pcall(function()
					f.shieldbar:SetMinMaxValues(0, maxHP)
					f.shieldbar:SetValue(damageAbsorbAmount)
					f.shieldbar:Show()
				end)
			end
		end

		return
	end

	-- TEXTURE PATH (all other bars): requires a safe 0-1 frac
	if not frac then return end
	local tfrac = nil

	if db.fade then  -- refresh fade bar
		local new = frac * bv
		if reset then
			f.alp = 0
			f.barfade:SetAlpha(0)
			f:SetScript("OnUpdate", nil)
		else
			local prev = f.prev or (db.vertical and bar:GetHeight()) or bar:GetWidth()
			if db.smoothfade then
				if new + 3 < prev or new - 3 > prev or ((f.alp or 0) > 0.02) then
					tfrac = prev / bv
					f.alp, f.smoothdif, f.smoothend = 0.4, tfrac - frac, frac
					f:SetScript("OnUpdate", SmoothBarOnUpdate)
				end
			elseif new + 1 < prev then
				f:SetScript("OnUpdate", BarFaderOnUpdate)
				f.alp = 1.3
				f.barfade:SetAlpha(0.8)
				f.barfade:SetValue(prev / bv, bv)
			end
		end
		f.prev = new
	end
	-- (incbar and shieldbar are handled in the nativeBar block above for hpbar)
	bar:SetValue(tfrac or frac, bv)  -- refresh main bar

	-- refresh main bar coloring
	if f.barth then
		bar:SetVertexColor(methodcolor(Stuf, f.barth, uf, db, frac, "barcolor", "baralpha"))
	end
	if f.bgth then
		f.bg:SetVertexColor(methodcolor(Stuf, f.bgth, uf, db, frac, "bgcolor", "bgalpha"))
	end
end
local function UpdateBarColors(unit, uf, _, reset)
	local hp = uf.hpbar
	if hp and (reset or hp.colorchanges) then
		local db = hp.db
		local frac = uf.cache.frachp or 1
		hp.bg:SetVertexColor(methodcolor(Stuf, db.bgcolormethod, uf, db, frac, "bgcolor", "bgalpha"))
		if hp.nativeBar then
			hp.nativeBar:SetStatusBarColor(methodcolor(Stuf, db.barcolormethod, uf, db, frac, "barcolor", "baralpha"))
		else
			hp.bar:SetVertexColor(methodcolor(Stuf, db.barcolormethod, uf, db, frac, "barcolor", "baralpha"))
		end
	end
	local mp = uf.mpbar
	if mp and (reset or mp.colorchanges) then
		local db = mp.db
		local frac = uf.cache.fracmp or 1
		mp.bg:SetVertexColor(methodcolor(Stuf, db.bgcolormethod, uf, db, frac, "bgcolor", "bgalpha"))
		if mp.nativeBar then
			mp.nativeBar:SetStatusBarColor(methodcolor(Stuf, db.barcolormethod, uf, db, frac, "barcolor", "baralpha"))
		else
			mp.bar:SetVertexColor(methodcolor(Stuf, db.barcolormethod, uf, db, frac, "barcolor", "baralpha"))
		end
	end
end
local function UpdateBarLook(unit, uf, f, db)  -- update bar look for statusbars
	local ename = f.ename
	local bg, barbase, bar, barfade, spark, incbar = f.bg, f.barbase, f.bar, f.barfade, f.spark, f.incbar
	local shieldbar = f.shieldbar
	local cw = db.w - (db.barinsetleft or 0) - (db.barinsetright or 0)
	local ch = db.h - (db.barinsettop or 0) - (db.barinsetbottom or 0)

	Stuf:UpdateBaseLook(uf, f, db)

	local texture = Stuf:GetMedia("statusbar", db.bartexture)
	barbase:SetWidth(cw)
	barbase:SetHeight(ch)
	barbase:SetPoint("TOPLEFT", f, "TOPLEFT", (db.barinsetleft or 0), -(db.barinsettop or 0))
	bar:SetWidth(cw)
	bar:SetHeight(ch)
	bar:ClearAllPoints()
	bar:SetTexture(texture)

	if barfade then
		local fc = dbg[(ename == "hpbar" and "hpfadecolor") or "mpfadecolor"]
		barfade:SetWidth(cw)
		barfade:SetHeight(ch)
		barfade:SetTexture(texture)
		barfade:SetVertexColor(fc.r, fc.g, fc.b, fc.a)
		barfade:SetAlpha(0)
		barfade:ClearAllPoints()
	end
	-- incbar and shieldbar are native StatusBars; update them via StatusBar API.
	if incbar and incbar.SetStatusBarTexture then
		local inctexture = Stuf:GetMedia("statusbar", db.inctexture) or texture
		incbar:SetStatusBarTexture(inctexture)
		local ic = db.inccolor
		if ic then
			incbar:SetStatusBarColor(ic.r, ic.g, ic.b, db.incalpha or ic.a or 0.9)
		else
			incbar:SetStatusBarColor(0.4, 1, 0.4, db.incalpha or 0.9)
		end
		if db.vertical then
			incbar:SetOrientation("VERTICAL")
		else
			incbar:SetOrientation("HORIZONTAL")
		end
		incbar:SetReverseFill(db.reverse and true or false)  -- same direction as health bar
		-- Size to full bar dimensions; anchor to nativeBar moving texture in UpdateStatusBar
		incbar:SetSize(cw, ch)
		incbar._anchorTex  = nil  -- force re-anchor on next update
		incbar._anchorRev  = nil
		incbar._anchorVert = nil
	end
	if shieldbar and shieldbar.SetStatusBarTexture then
		local shieldtexture = Stuf:GetMedia("statusbar", db.shieldtexture) or texture
		shieldbar:SetStatusBarTexture(shieldtexture)
		local sc = db.shieldcolor
		if sc then
			shieldbar:SetStatusBarColor(sc.r, sc.g, sc.b, db.shieldalpha or sc.a or 0.85)
		else
			shieldbar:SetStatusBarColor(0.2, 0.6, 1.0, db.shieldalpha or 0.85)
		end
		shieldbar:ClearAllPoints()
		shieldbar:SetAllPoints(barbase)
		if db.vertical then
			shieldbar:SetOrientation("VERTICAL")
		else
			shieldbar:SetOrientation("HORIZONTAL")
		end
		shieldbar:SetReverseFill(db.reverse and true or false)
	end

	-- setup bar orientations and texture coordinates
	local rev = db.reverse
	local setup = (db.hflip and db.vflip and "hvflip") or (db.hflip and "hflip") or (db.vflip and "vflip") or "normal"
	if db.vertical then
		f.bvalue = ch
		local _, sv = Stuf:GetTexCoordOptions(true, setup, rev, db.deplete, bar)
		local point, opoint = rev and "TOP" or "BOTTOM", rev and "BOTTOM" or "TOP"
		sv(bg, 1, ch)
		bar:SetPoint(point, barbase, point)
		if barfade then
			barfade.SetValue = sv
			barfade:SetPoint(point, barbase, point)
		end
		-- incbar/shieldbar are SetAllPoints(barbase) StatusBars; no SetValue or SetPoint override needed
		if spark then
			local sparkc = db.sparkcolor or Stuf.whitecolor
			spark:SetWidth(cw * 2.3)
			spark:SetHeight(12)
			spark:SetVertexColor(sparkc.r, sparkc.g, sparkc.b, sparkc.a)
			spark:SetPoint("CENTER", bar, opoint)
		end
	else
		f.bvalue = cw
		local _, sv = Stuf:GetTexCoordOptions(false, setup, rev, db.deplete, bar)
		local point, opoint = rev and "RIGHT" or "LEFT", rev and "LEFT" or "RIGHT"
		sv(bg, 1, cw)
		bar:SetPoint(point, barbase, point)
		if barfade then
			barfade.SetValue = sv
			barfade:SetPoint(point, barbase, point)
		end
		-- incbar/shieldbar are SetAllPoints(barbase) StatusBars; no SetValue or SetPoint override needed
		if spark then
			local sparkc = db.sparkcolor or Stuf.whitecolor
			spark:SetWidth(12)
			spark:SetHeight(ch * 2.3)
			spark:SetVertexColor(sparkc.r, sparkc.g, sparkc.b, sparkc.a)
			spark:SetPoint("CENTER", bar, opoint)
		end
	end
	if ename == "hpbar" or ename == "mpbar" then
		UpdateBarColors(unit, uf, f, true)
		-- Sync the native StatusBar to match the barbase geometry and texture
		if f.nativeBar then
			local nb = f.nativeBar
			nb:SetStatusBarTexture(texture)
			nb:ClearAllPoints()
			nb:SetAllPoints(barbase)
			if db.vertical then
				nb:SetOrientation("VERTICAL")
			else
				nb:SetOrientation("HORIZONTAL")
			end
			nb:SetReverseFill(db.reverse and true or false)
			-- nativeBar level is driven by db.framelevel (config); never hardcoded.
			-- shieldbar = nativeBar + 1, incbar = nativeBar + 2 (incbar has visual priority).
			local nbLevel = db.framelevel or 1
			nb:SetFrameLevel(nbLevel)
			if f.incbar and f.incbar.SetStatusBarTexture then
				f.incbar:SetFrameLevel(nbLevel + 2)
			end
			if f.shieldbar and f.shieldbar.SetStatusBarTexture then
				f.shieldbar:SetFrameLevel(nbLevel + 1)
			end
			nb:Show()
		end
	else
		local bc = db.bgcolor or Stuf.hidecolor
		bg:SetVertexColor(bc.r, bc.g, bc.b, bc.a)
	end
end


do  -- Health and Power Bars ------------------------------------------------------------------------------------------
	local showtick
	local function IncomingHeal(unit)
		local uf = su[unit]
		local f = uf and uf.hpbar and uf.hpbar.incbar
		if not f then return end
		UpdateStatusBar(unit, uf, uf.hpbar, nil, uf.cache.frachp)
	end
	-- Shield/absorb update: fires on UNIT_ABSORB_AMOUNT_CHANGED
	local function ShieldUpdate(unit)
		local uf = su[unit]
		local hp = uf and uf.hpbar
		if not hp or not hp.shieldbar then return end
		UpdateStatusBar(unit, uf, hp, nil, uf.cache and (uf.cache.frachp or 1))
	end
	local function CreateBar(unit, uf, name, db)  -- create status bars for health or power
		local f = uf[name]
		local ishp = (name == "hpbar")
		if db.hide then
			if f then 
				f:Hide()
				Stuf:RegisterElementRefresh(uf, name, (ishp and "healthelements") or "powerelements", nil)
			end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db)
			f.bg = f:CreateTexture(nil, "BACKGROUND")
			f.bg:SetAllPoints(f)
			f.barbase = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
			-- Native StatusBar: C engine handles secret health/power values safely.
			-- f.bar is the texture used by UpdateBarLook for background sizing;
			-- f.nativeBar is the real StatusBar that renders the fill.
			local nb = CreateFrame("StatusBar", nil, f.barbase)
			nb:SetMinMaxValues(0, 1)
			nb:SetValue(1)
			f.nativeBar = nb
			-- Keep f.bar as a plain texture so UpdateBarLook works unchanged
			f.bar = f:CreateTexture(nil, "ARTWORK")
			f.bar:SetAlpha(0)  -- invisible; nativeBar does the actual rendering

			uf.refreshfuncs[name] = UpdateStatusBar
			uf.refreshfuncs["barcolors"] = UpdateBarColors
		else
			f:Show()
		end
		if db.fade and not f.barfade then
			f.barfade = f:CreateTexture(nil, "BORDER")
		end
		if ishp then
			-- Heal prediction calculator (feeds both incbar and shieldbar without
			-- any Lua arithmetic on secret values).
			if not f._hpCalc and CreateUnitHealPredictionCalc then
				local calc = CreateUnitHealPredictionCalc()
				-- Configure clamp modes to match oUF defaults (required or GetIncomingHeals
				-- / GetDamageAbsorbs return zero/garbage on an unconfigured calculator).
				if calc.SetDamageAbsorbClampMode then calc:SetDamageAbsorbClampMode(2) end  -- Enum.UnitDamageAbsorbClampMode.Max
				if calc.SetHealAbsorbClampMode  then calc:SetHealAbsorbClampMode(1)  end  -- Enum.UnitHealAbsorbClampMode.Capped
				if calc.SetHealAbsorbMode       then calc:SetHealAbsorbMode(1)       end  -- Enum.UnitHealAbsorbMode.CounterHeals
				f._hpCalc = calc
			end
			if db.inc then
				-- incbar is a native StatusBar that overlaps the health bar area.
				-- nativeBar (higher frame level) draws on top, so only the
				-- "predicted heal" portion beyond the health fill is visible.
				if not f.incbar then
					local ib = CreateFrame("StatusBar", nil, f.barbase)
					-- Size and anchor set in UpdateBarLook/UpdateStatusBar (MSUF texture-anchor approach)
					ib:SetMinMaxValues(0, 1)
					ib:SetValue(0)
					ib:Hide()
					f.incbar = ib
				end
				f.incbar:SetAlpha(1)
				Stuf:AddEvent("UNIT_HEAL_PREDICTION", IncomingHeal)
			elseif f.incbar then
				f.incbar:SetAlpha(0)
			end
			-- Absorb shield overlay (same native StatusBar pattern)
			if db.shield then
				if not f.shieldbar then
					local sb = CreateFrame("StatusBar", nil, f.barbase)
					sb:SetAllPoints(f.barbase)
					sb:SetMinMaxValues(0, 1)
					sb:SetValue(0)
					sb:Hide()
					f.shieldbar = sb
				end
				f.shieldbar:SetAlpha(1)
				Stuf:AddEvent("UNIT_ABSORB_AMOUNT_CHANGED", ShieldUpdate)
			elseif f.shieldbar then
				f.shieldbar:SetAlpha(0)
			end
		end

		-- five second rule mana tick
		if unit == "player" and not ishp and not db.hidemanatick and CLS ~= "HUNTER" and CLS ~= "ROGUE" and CLS ~= "WARRIOR" and CLS ~= "DEATHKNIGHT" then
			if not f.spark then
				local spark = f:CreateTexture(nil, "OVERLAY")
				spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
				spark:SetBlendMode("ADD")
				f.spark = spark
				
				local lastmana, fivestart, recentcast = 1000000, 0, 0
				local function SparkOnUpdate(this, a1)
					local frac = (GetTime() - fivestart) * 0.2062
					if frac > 1 then
						f.barbase:SetScript("OnUpdate", nil)
						spark:Hide()
					else
						spark:SetAlpha(frac > 0.1 and frac or 0.1)
						spark:SetSparkPoint(f.bvalue * frac)
					end
				end
				local function manatick(unit)
					if unit ~= "player" or not showtick then return end
					if not uf or uf.hidden then return end
					if uf.cache.powertype ~= 0 then
						spark:Hide()
						f.barbase:SetScript("OnUpdate", nil)
						return
					end
					local current = UnitPower(unit)
					-- current may be a secret value in combat; pcall-protect the comparison
					local ok = pcall(function()
						if current < lastmana and GetTime() - recentcast < 0.6 then
							fivestart = recentcast
							recentcast = 0
							spark:Show()
							f.barbase:SetScript("OnUpdate", SparkOnUpdate)
						end
						lastmana = current
					end)
					if not ok then
						-- in combat, secret values can't be compared; hide tick spark silently
						spark:Hide()
						f.barbase:SetScript("OnUpdate", nil)
					end
				end
				Stuf:AddEvent("UNIT_SPELLCAST_SUCCEEDED", function(unit)
					if unit == "player" and showtick then
						recentcast = GetTime()
					end
				end)
				Stuf:AddEvent("UNIT_POWER_UPDATE", manatick)
				uf.refreshfuncs["manatick"] = manatick
				Stuf:RegisterElementRefresh(uf, "manatick", "powercolorelements", true)
			end
			showtick = true
		elseif f.spark and db.hidemanatick then
			f.spark:Hide()
			showtick = nil
		end

		UpdateBarLook(unit, uf, f, db)

		if f.spark then
			f.spark:Hide()
			if db.vertical then
				if db.reverse then
					f.spark.SetSparkPoint = function(this, value) this:SetPoint("CENTER", f.barbase, "TOP", 0, -value) end
				else
					f.spark.SetSparkPoint = function(this, value) this:SetPoint("CENTER", f.barbase, "BOTTOM", 0, value) end
				end
			else
				if db.reverse then
					f.spark.SetSparkPoint = function(this, value) this:SetPoint("CENTER", f.barbase, "RIGHT", -value, 0) end
				else
					f.spark.SetSparkPoint = function(this, value) this:SetPoint("CENTER", f.barbase, "LEFT", value, 0) end
				end
			end
		end
		local barcm, bgcm = db.barcolormethod or "blah", db.bgcolormethod or "blah"
		f.barth = (barcm == "hpthreshold" or barcm == "hpthresholddark") and barcm or nil
		f.bgth = (bgcm == "hpthreshold" or bgcm == "hpthresholddark") and bgcm or nil
		
		if not ishp and (strmatch(barcm, "power") or strmatch(bgcm, "power")) then
			f.colorchanges = true
			Stuf:RegisterElementRefresh(uf, "barcolors", "powercolorelements", true)
		end
		if strmatch(barcm, "reaction") or strmatch(bgcm, "reaction") then
			f.colorchanges = true
			Stuf:RegisterElementRefresh(uf, "barcolors", "reactionelements", true)
		end
		Stuf:RegisterElementRefresh(uf, name, ishp and "healthelements" or "powerelements", true)
		if Stuf.inworld then
			UpdateStatusBar(unit, uf, f, true, uf.cache[ishp and "frachp" or "fracmp"])
		end
	end
	Stuf:AddBuilder("hpbar", CreateBar)
	Stuf:AddBuilder("mpbar", CreateBar)
end


do  -- Cast Bar -------------------------------------------------------------------------------------------------------
	local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
	local castunits, lagtime = { }, 0
	local setftext = BankFrameTitleText.SetFormattedText
	local timeformat = {
		remain = function(fs, remain, duration, sign, delay)
			setftext(fs, "%0.1f", remain)
		end,
		remaindelay = function(fs, remain, duration, sign, delay)
			if delay then
				setftext(fs, "|cffff0000%s%0.1f|r %0.1f", sign, delay, remain)
			else
				setftext(fs, "%0.1f", remain)
			end
		end,
		remainduration = function(fs, remain, duration, sign, delay)
			setftext(fs, "%0.1f | %0.1f", remain, duration)
		end,
		remaindurationdelay = function(fs, remain, duration, sign, delay)
			if delay then
				setftext(fs, "|cffff0000%s%0.1f|r %0.1f | %0.1f", sign, delay, remain, duration)
			else
				setftext(fs, "%0.1f | %0.1f", remain, duration)
			end
		end,
		none = Stuf.nofunc,
	}
	local castr, castg, castb, chanr, chang, chanb, compr, compg, compb, failr, failg, failb
	local function StopCast(f, r, g, b, a, value, norefresh)
		f.cstate = 3
		f.fadestart = norefresh and f.fadestart or GetTime()
		if (a or 0) > 0.03 then
			f.bar:SetVertexColor(r, g, b, a)
		end
		if value then
			f.bar:SetValue(value, f.bvalue)
			f.time:SetValue(0, f.duration)
		end
		f.spark:Hide()
	end

	local function UNIT_SPELLCAST_START(unit)
		local f = castunits[unit]
		if not f then return end
		local spell, displayName, icon, startTime, endTime, istrade, castid, notInterruptible = UnitCastingInfo(unit)
		if not spell then return end
		local endS, durS
		pcall(function() endS = endTime * 0.001; durS = (endTime - startTime) * 0.001 end)
		if not endS then return end

		f.endtime = endS
		f.duration = durS
		f.delay = nil
		f.cstate = 1
		f.castid = castid
		f:SetAlpha(f.db.alpha or 1)
		
		f.bar:SetVertexColor(castr, castg, castb, f.db.baralpha)
		f.spell:SetFormattedText("%s%s", (unit ~= "player" and notInterruptible and "(X) ") or "", spell)
		f.icon:SetTexture(icon)
		f.spark:Show()
		if f.lag then
			f.lag:ClearAllPoints()
			f.lag:SetPoint(f.lag.castpoint, f.barbase, f.lag.castpoint)
			local lagfrac = 0.0001
			pcall(function() lagfrac = (startTime * 0.001 - lagtime) / f.duration end)
			f.lag:SetValueCast((lagfrac > 0.9 or lagfrac < 0.0001) and 0.0001 or lagfrac, f.bvalue)
		end
		f:Show()
		return true
	end
	local function UNIT_SPELLCAST_CHANNEL_START(unit)
		local f = castunits[unit]
		if not f then return end
		local spell, displayName, icon, startTime, endTime, isTradeSkill, notInterruptible = UnitChannelInfo(unit)
		if not spell then return end
		local endS, durS
		pcall(function() endS = endTime * 0.001; durS = (endTime - startTime) * 0.001 end)
		if not endS then return end

		f.endtime = endS
		f.duration = durS
		f.delay = nil
		f.cstate = 2
		f:SetAlpha(f.db.alpha or 1)

		f.bar:SetVertexColor(chanr, chang, chanb, f.db.baralpha)
		f.spell:SetFormattedText("%s%s", (unit ~= "player" and notInterruptible and "(X) ") or "", spell)
		f.icon:SetTexture(icon)
		f.spark:Show()
		if f.lag then
			f.lag:ClearAllPoints()
			f.lag:SetPoint(f.lag.chanpoint, f.barbase, f.lag.chanpoint)
			local lagfrac = 0.0001
			pcall(function() lagfrac = (startTime * 0.001 - lagtime) / f.duration end)
			f.lag:SetValueChan(lagfrac > 0.8 and 0.0001 or lagfrac, f.bvalue)
		end
		f:Show()
	end
	local function UNIT_SPELLCAST_STOP(unit)
		local f = castunits[unit]
		if not f or f.cstate ~= 1 then return end
		StopCast(f, compr, compg, compb, f.db.baralpha, 1, nil)
	end
	local function UNIT_SPELLCAST_CHANNEL_STOP(unit)
		local f = castunits[unit]
		if not f or f.cstate ~= 2 then return end
		StopCast(f, failr, failg, failb, f.db.baralpha, 0, nil)
	end
	local function UNIT_SPELLCAST_FAILED(unit, a1, a2, a3, a4)
		local f = castunits[unit]
		if not f or f.cstate ~= 1 or a4 ~= f.castid then return end
		StopCast(f, failr, failg, failb, f.db.baralpha, nil, true)
	end
	local function UNIT_SPELLCAST_INTERRUPTED(unit)
		local f = castunits[unit]
		if not f or (f.cstate ~= 1 and f.cstate ~= 2) then return end
		StopCast(f, failr, failg, failb, f.db.baralpha, nil, true)
	end
	local function UNIT_SPELLCAST_DELAYED(unit)
		local f = castunits[unit]
		if not f then return end
		local spell, displayName, icon, startTime, endTime = UnitCastingInfo(unit)
		if not startTime then
			f:Hide()
		else
			local endS, durS
			pcall(function() endS = endTime * 0.001; durS = (endTime - startTime) * 0.001 end)
			if endS then
				local p_endtime = f.endtime
				f.endtime = endS
				f.duration = durS
				f.delay = (f.delay or 0) + (f.endtime - p_endtime)
			end
		end
	end
	local function UNIT_SPELLCAST_CHANNEL_UPDATE(unit)
		local f = castunits[unit]
		if not f then return end
		local spell, displayName, icon, startTime, endTime = UnitChannelInfo(unit)
		if not startTime then
			f:Hide()
		else
			local endS, durS
			pcall(function() endS = endTime * 0.001; durS = (endTime - startTime) * 0.001 end)
			if endS then
				local p_endtime = f.endtime
				f.endtime = endS
				f.duration = durS
				f.delay = (f.delay or 0) + (f.endtime - p_endtime)
			end
		end
	end

	local function CastOnUpdate(f, a1)
		if f.cstate == 1 then  -- casting
			local remain = f.endtime - GetTime()
			if remain < 0 then
				StopCast(f, compr, compg, compb, f.db.baralpha, 1, nil)
			else
				f.bar:SetValue(1 - remain / f.duration, f.bvalue)
				f.time:SetValue(remain, f.duration, "+", f.delay)
			end
		elseif f.cstate == 2 then  -- channeling
			local remain = f.endtime - GetTime()
			if remain < 0 then
				StopCast(f, compr, compg, compb, 0, 0, nil)
			else
				f.bar:SetValue(remain / f.duration, f.bvalue)
				f.time:SetValue(remain, f.duration, "-", f.delay)
			end
		elseif f.cstate == 3 then  -- fading
			local t = GetTime() - f.fadestart
			if t < 0.8 then
				f:SetAlpha((0.8 - t) * (f.db.alpha or 1))
			else
				f:Hide()
				f.cstate = nil
				f.fadestart = nil
			end
		else  -- clear
			f:Hide()
		end
	end
	local function CastOnShowHide(this)
		local bg = this.p.buffgroup
		if bg and (bg.db.push == "v" or bg.db.push == "h") and not bg.db.hide then
			local debuff = this.p.debuffgroup
			local auratimers = this.p.auratimers
			Stuf.ApplyPush(bg, debuff and not debuff.db.hide and debuff, auratimers and not auratimers.db.hide and auratimers)
		end
	end
	local function RefreshCast(unit, uf, f, _, a5, config)
		f = f or castunits[unit]
		if not f then return end
		if config then
			f.endtime = GetTime() + 30
			f.duration = 30
			f.cstate = 1
			f.castid = 1
			f.delay = 0.2
			f:SetAlpha(f.db.alpha or 1)

			local c = dbg.castcolor
			f.bar:SetVertexColor(c.r, c.g, c.b, c.a)
			f.spell:SetText("Spell Name Spell Name Spell Name Spell Name Spell Name")
			f.icon:SetTexture("Interface\\Icons\\Ability_ThunderBolt")
			f.spark:Show()
			f:Show()
		else
			f.cstate, f.fadestart = nil, nil
			if not UNIT_SPELLCAST_START(unit) then
				UNIT_SPELLCAST_CHANNEL_START(unit)
			end
		end
	end

	Stuf:AddBuilder("castbar", function(unit, uf, name, db, a5, config)
		local f = uf[name]
		if db.hide then
			if f then
				f:Hide()
				castunits[unit], uf.refreshfuncs[name] = nil, nil
			end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db)
			f:Hide()
			f.barbase = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
			f.bg = f:CreateTexture(nil, "BACKGROUND")
			f.bg:SetAllPoints(f)
			f.bar = f:CreateTexture(nil, "BORDER")
			f.icon = f:CreateTexture(nil, "ARTWORK")
			f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			f.spell = f:CreateFontString(nil, "OVERLAY")
			f.time = f:CreateFontString(nil, "OVERLAY")
			f.spark = f.border:CreateTexture(nil, "ARTWORK")
			f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
			f.spark:SetBlendMode("ADD")

			f:SetScript("OnUpdate", CastOnUpdate)
			f:SetScript("OnShow", CastOnShowHide)
			f:SetScript("OnHide", CastOnShowHide)
			f.p = uf

			Stuf:AddEvent("UNIT_SPELLCAST_START", UNIT_SPELLCAST_START)
			Stuf:AddEvent("UNIT_SPELLCAST_STOP", UNIT_SPELLCAST_STOP)
			Stuf:AddEvent("UNIT_SPELLCAST_FAILED", UNIT_SPELLCAST_FAILED)
			Stuf:AddEvent("UNIT_SPELLCAST_INTERRUPTED", UNIT_SPELLCAST_INTERRUPTED)
			Stuf:AddEvent("UNIT_SPELLCAST_DELAYED", UNIT_SPELLCAST_DELAYED)
			Stuf:AddEvent("UNIT_SPELLCAST_CHANNEL_START", UNIT_SPELLCAST_CHANNEL_START)
			Stuf:AddEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", UNIT_SPELLCAST_CHANNEL_UPDATE)
			Stuf:AddEvent("UNIT_SPELLCAST_CHANNEL_STOP", UNIT_SPELLCAST_CHANNEL_STOP)
		end
		UpdateBarLook(unit, uf, f, db)
		f:SetFrameLevel(db.framelevel or 3)
		uf.refreshfuncs[name] = RefreshCast
		castunits[unit] = f

		castr, castg, castb = dbg.castcolor.r, dbg.castcolor.g, dbg.castcolor.b
		chanr, chang, chanb = dbg.channelcolor.r, dbg.channelcolor.g, dbg.channelcolor.b
		compr, compg, compb = dbg.completecolor.r, dbg.completecolor.g, dbg.completecolor.b
		failr, failg, failb = dbg.failcolor.r, dbg.failcolor.g, dbg.failcolor.b

		local spell, ctime = f.spell, f.time
		local vertical = db.vertical
		local sc = dbg.shadowcolor
		spell:SetFont(Stuf.font, 1)
		ctime:SetFont(Stuf.font, 1)
		if db.spellfontcolor and db.spellfontcolor.a < 0.01 then
			spell:Hide()
		else
			spell:SetWidth(db.spellw)
			spell:SetHeight(db.spellh)
			spell:SetPoint("TOPLEFT", f.barbase, "TOPLEFT", db.spellx or 0, db.spelly or 0)
			Stuf:UpdateTextLook( spell, db.spellfont, nil, db.spellfontsize, db.spellfontflags, db.spelljustifyH or "LEFT", db.spelljustifyV,
			                     db.spellfontcolor or Stuf.whitecolor, db.spellshadowx, db.spellshadowy)
			spell:SetNonSpaceWrap(true)
			spell:Show()
		end
		if db.timeformat == "none" or db.timefontcolor and db.timefontcolor.a < 0.01 then
			ctime.SetValue = timeformat.none
			ctime:Hide()
		else
			local c = db.timefontcolor or Stuf.whitecolor
			ctime:SetWidth(db.timew)
			ctime:SetHeight(db.timeh)
			ctime:SetPoint("TOPLEFT", f.barbase, "TOPLEFT", db.timex or 0, db.timey or 0)
			Stuf:UpdateTextLook( ctime, db.timefont, nil, db.timefontsize, db.timefontflags, db.timejustifyH or "LEFT", db.timejustifyV,
			                     db.timefontcolor or Stuf.whitecolor, db.timeshadowx, db.timeshadowy)
			ctime:SetNonSpaceWrap(true)
			ctime.SetValue = timeformat[db.timeformat or "remain"] or timeformat.remain
			ctime:Show()
		end
		if unit == "player" then
			if db.showlag then
				db.lagcolor = db.lagcolor or { r = 1, g = 0, b = 0, a = 0.6, }
				if not f.lag then
					f.lag = f:CreateTexture(nil, "ARTWORK")
					Stuf:AddEvent("UNIT_SPELLCAST_SENT", function(unit)
						if unit ~= "player" then return end
						lagtime = GetTime()
					end)
				end
				f.lag:SetWidth(f.bar:GetWidth())
				f.lag:SetHeight(f.bar:GetHeight())
				f.lag:SetTexture(f.bar:GetTexture())
				f.lag:SetVertexColor(db.lagcolor.r, db.lagcolor.g, db.lagcolor.b, db.lagcolor.a)
				local barpoint = f.bar:GetPoint()
				f.lag.SetValueCast = Stuf:GetTexCoordOptions(db.vertical, (db.hflip and db.vflip and "hvflip") or (db.hflip and "hflip") or (db.vflip and "vflip") or "normal", not db.reverse, nil, f.lag)
				f.lag.castpoint = (barpoint == "LEFT" and "RIGHT") or (barpoint == "RIGHT" and "LEFT") or (barpoint == "TOP" and "BOTTOM") or (barpoint == "BOTTOM" and "TOP")
				f.lag.SetValueChan = f.bar.SetValue
				f.lag.chanpoint = barpoint
				f.lag:Show()
			elseif f.lag then
				f.lag:Hide()
			end
		end

		f.icon:SetPoint("TOPLEFT", f.barbase, "TOPLEFT", db.iconx, db.icony)
		f.icon:SetWidth(db.iconw)
		f.icon:SetHeight(db.iconh)
		f.icon:SetAlpha(db.iconalpha or 1)

		local sc = db.sparkcolor or Stuf.whitecolor
		f.spark:SetVertexColor(sc.r, sc.g, sc.b, sc.a)
		f.bar:SetAlpha(db.baralpha or 1)
		if Stuf.inworld then
			RefreshCast(unit, uf, nil, nil, a5, config)
		end
	end)
end


do  -- Threat Bar -----------------------------------------------------------------------------------------------------
	local UnitExists, UnitDetailedThreatSituation, GetThreatStatusColor = UnitExists, UnitDetailedThreatSituation, GetThreatStatusColor
	local ThreatOnUpdate, UpdateThreatOnUnit, UpdateThreat
	Stuf:AddBuilder("threatbar", function(unit, uf, name, db, a5, config)
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db)
			f.barbase = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
			f.bg = f:CreateTexture(nil, "BACKGROUND")
			f.bg:SetAllPoints(f)
			f.bar = f:CreateTexture(nil, "BORDER")
			f.text = f:CreateFontString(nil, "OVERLAY")
			f.text:SetAllPoints(f)
			f.text:SetJustifyH("CENTER")
			f.text:SetJustifyV("MIDDLE")

			ThreatOnUpdate = ThreatOnUpdate or function(this, a1)
				local dir = this.dir or 1
				local alp = (this.alp or 0) + a1 * dir
				if (dir == 1 and alp > 0.3) or (dir == -1 and alp < -0.3) then
					this.dir = dir * -1
				end
				this.alp = alp
				this:SetAlpha(this.basealpha + alp)
			end
			UpdateThreatOnUnit = UpdateThreatOnUnit or function(unit, uf, _, _, a5, config)
				uf = uf or su[unit]
				local f = uf and not uf.hidden and uf.threatbar
				if not f or f.db.hide then return end

				local isTanking, status, threatpct
				if config then
					isTanking, status, threatpct = false, 3, 100
				elseif not f.db.groupshow or Stuf.ingroup then
					isTanking, status, threatpct = UnitDetailedThreatSituation("player", unit)
				end

				-- 12.0.1: threatpct and status are secret values; pcall-wrap all comparisons
				local showThreat, frac, isHighThreat = false, 0.01, false
				if threatpct then
					pcall(function()
						if threatpct >= 1 then
							showThreat = true
							frac = threatpct * 0.01
							isHighThreat = (status > 0)
						end
					end)
				end
				if not showThreat then
					f:Hide()
				else
					local r, g, b = GetThreatStatusColor(status)
					f.text:SetFormattedText("%d%%", threatpct)
					f.bar:SetValue(frac, f.bvalue)
					f.bar:SetVertexColor(r, g, b, f.db.baralpha or 1)
					if isHighThreat then
						f:SetScript("OnUpdate", ThreatOnUpdate)
					else
						f:SetAlpha(f.db.alpha or 1)
						f:SetScript("OnUpdate", nil)
					end
					f:Show()
				end
			end

			f:Hide()
			Stuf:AddEvent("UNIT_THREAT_LIST_UPDATE", UpdateThreatOnUnit)
			uf.refreshfuncs[name] = UpdateThreatOnUnit
		end
		UpdateBarLook(unit, uf, f, db)
		f:SetFrameLevel(db.framelevel or 3)

		f.text:SetFont(Stuf:GetMedia("font", db.font), db.fontsize or max(2, db.h - 2))
		f.text:SetNonSpaceWrap(true)
		f.basealpha = (db.alpha or 1) - 0.3
		f.basealpha = f.basealpha < 0.4 and 0.4 or f.basealpha
		if db.fontcolor then
			f.text:SetTextColor(db.fontcolor.r, db.fontcolor.g, db.fontcolor.b, db.fontcolor.a)
		end
		if Stuf.inworld then
			UpdateThreatOnUnit(unit, uf, nil, nil, a5, config)
		end
	end)
end


if CLS == "SHAMAN" or CLS == "DRUID" or CLS == "DEATHKNIGHT" or CLS == "PALADIN" then  -- Totem Bar ---------------------------------------------------------------------------------
	local pi = math.pi
	local UpdateTotem
	Stuf:AddBuilder("totembar", function(unit, uf, name, db, a5, config)
		if unit ~= "player" then return end
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
			f:SetHeight(1)
			f:SetWidth(1)

			f.db = db
			uf[name] = f

			local GetTotemInfo = GetTotemInfo
			local totcolors = { 
				{ r=0.8, g=0.6, b=0.4, a=0.8, },  -- earth
				{ r=1.0, g=0.4, b=0.0, a=0.8, },  -- fire
				{ r=0.4, g=0.6, b=1.0, a=0.8, },  -- water
				{ r=0.9, g=0.9, b=1.0, a=0.8, },  -- air
			}
			local function TotemOnEnter(this)
				GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
				GameTooltip:SetTotem(this.id)
				GameTooltip:AddLine("<Right-click> to destroy totem", 0, 1, 0)
				GameTooltip:Show()
			end
			local function TotemOnClick(this, button)
				DestroyTotem(this.id)
			end
			local function TotemOnUpdate(this, a1)
				this.elapsed = (this.elapsed or 0) + a1
				if this.elapsed < this.throt then return end
				this.elapsed = 0

				local remain = this.endtime - GetTime()
				this.bar:SetValue(remain * this.duration, this.bvalue)
				if remain < 60 then
					if remain > 10 then
						this.throt = 0.2
						this.time:SetFormattedText("%d", remain)
					elseif remain > 0.5 then
						this.throt = 0.03
						this:SetAlpha(0.7 + 0.3 * sin(remain * pi))
						this.time:SetFormattedText("%0.1f", remain)
					elseif remain > -1.5 then
						this:SetAlpha(remain * 0.5 + 0.75)
						this.time:SetFormattedText("%0.1f", remain < 0 and 0 or remain)
					else
						this:Hide()
						return
					end
				elseif remain < 600 then
					this.time:SetFormattedText("%d:%02d", remain * stamin, remain % 60)
				elseif remain < 3600 then
					this.time:SetFormattedText("%dm", 1 + remain * stamin)
				else
					this.time:SetFormattedText("%0.1fh", remain * stahr)
				end
				if this.id and GameTooltip:IsOwned(this.click) then
					TotemOnEnter(this.click)
				end
			end
			UpdateTotem = function(unit, uf, _, _, a5, config)
				uf = uf or su.player
				local f = uf and not uf.hidden and uf.totembar
				if not f or f.db.hide then return end

				for i = 1, 4, 1 do
					-- 12.0.1: GetTotemInfo returns secret values for all returns.
					-- haveTotem (1st return) is a secret boolean — cannot test with 'if'.
					-- Use icon (a plain string: nil when empty, texture path when active) as proxy.
					local _, totemName, startTime, duration, icon = GetTotemInfo(i)
					if config then
						startTime = GetTime()
						duration = i * 20
						icon = "Interface\\Icons\\Spell_ChargePositive"
					end
					local reorder = (i == 1 and 2) or (i == 2 and 1) or i  -- switch earth and fire
					if icon and icon ~= "" then  -- safe string check; nil/empty = no totem
						local b = f[reorder]
						local c = totcolors[reorder]
						-- startTime and duration are secret values; pcall-extract a safe remain
						-- so that TotemOnUpdate can use safe GetTime() arithmetic thereafter.
						local safeRemain = i * 20  -- fallback (config mode or pcall failure)
						pcall(function() safeRemain = startTime + duration - GetTime() end)
						if safeRemain < 0.1 then safeRemain = 0.1 end
						b.endtime = GetTime() + safeRemain  -- safe non-secret value
						b.duration = 1 / safeRemain          -- safe non-secret value
						b.throt = 0.1
						b.elapsed = 1
						b.icon:SetTexture(icon)
						b.bar:SetVertexColor(c.r, c.g, c.b, f.db.baralpha or 1)
						b:SetAlpha(1)
						b:Show()
					else
						f[reorder]:Hide()
					end
				end
			end

			for i = 1, 4, 1 do
				local b = CreateFrame("Frame", nil, f, BackdropTemplateMixin and 'BackdropTemplate')
				b:SetScript("OnUpdate", TotemOnUpdate)

				b.click = CreateFrame("Button", nil, b, BackdropTemplateMixin and 'BackdropTemplate')
				b.click:RegisterForClicks("RightButtonUp")
				b.click:SetScript("OnEnter", TotemOnEnter)
				b.click:SetScript("OnLeave", Stuf.GameTooltipOnLeave)
				b.click:SetScript("OnClick", TotemOnClick)
				b.click.id = (i == 1 and 2) or (i == 2 and 1) or i  -- switch earth and fire

				b.barbase = CreateFrame("Frame", nil, b, BackdropTemplateMixin and 'BackdropTemplate')
				b.bg = b:CreateTexture(nil, "BACKGROUND")
				b.bg:SetAllPoints(b.barbase)
				b.bar = b:CreateTexture(nil, "BORDER")
				b.time = b:CreateFontString(nil, "OVERLAY")
				b.time:SetAllPoints(b.barbase)
				b.icon = b:CreateTexture(nil, "ARTWORK")
				b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				b.spark = b:CreateTexture(nil, "ARTWORK")
				b.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
				b.spark:SetBlendMode("ADD")

				b.ename = name
				b.id = i

				f[i] = b
			end
			
			Stuf:AddEvent("PLAYER_TOTEM_UPDATE", UpdateTotem)
			uf.refreshfuncs[name] = UpdateTotem
		end
		f:Show()
		f:SetPoint("TOPLEFT", db.x, db.y)
		f:SetAlpha(db.alpha or 1)
		if db.framelevel then f:SetFrameLevel(db.framelevel) end

		local texture = Stuf.statusbar
		local bgc = db.bgcolor or Stuf.hidecolor
		local reverse, vertical = db.reverse, db.vertical
		for i = 1, 4, 1 do
			local b = f[i]
			b:SetWidth(db.w)
			b:SetHeight(db.h)
			b:SetAlpha(db.alpha or 1)
			UpdateBarLook(unit, uf, b, db)
			b.bg:SetTexture(texture)
			b.bg:SetVertexColor(bgc.r, bgc.g, bgc.b, bgc.a)
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint("TOPLEFT", f, "TOPLEFT")
			else
				if db.vstack then
					b:SetPoint("TOP", f[i-1], "BOTTOM", 0, -((vertical and db.w or 0) + 2))
				else
					b:SetPoint("LEFT", f[i-1], "RIGHT", ((vertical and 0 or db.h) + 2), 0)
				end
			end
			b.time:SetFont(Stuf:GetMedia("font", db.font), db.fontsize or max(2, db.h - 2))
			b.time:SetNonSpaceWrap(true)

			b.icon:ClearAllPoints()
			b.click:ClearAllPoints()
			if db.vertical then
				b.icon:SetWidth(db.w)
				b.icon:SetHeight(db.w)
				if reverse then
					b.icon:SetPoint("BOTTOM", b, "TOP")
					b.time:SetJustifyH("CENTER")
					b.time:SetJustifyV("BOTTOM")
					b.click:SetPoint("TOPLEFT", b.icon, "TOPLEFT")
					b.click:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT")
				else
					b.icon:SetPoint("TOP", b, "BOTTOM")
					b.time:SetJustifyH("CENTER")
					b.time:SetJustifyV("TOP")
					b.click:SetPoint("TOPLEFT", b, "TOPLEFT")
					b.click:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT")
				end
			else
				b.icon:SetWidth(db.h)
				b.icon:SetHeight(db.h)
				if reverse then
					b.icon:SetPoint("LEFT", b, "RIGHT")
					b.time:SetJustifyH("LEFT")
					b.time:SetJustifyV("MIDDLE")
					b.click:SetPoint("TOPLEFT", b, "TOPLEFT")
					b.click:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT")
				else
					b.icon:SetPoint("RIGHT", b, "LEFT")
					b.time:SetJustifyH("RIGHT")
					b.time:SetJustifyV("MIDDLE")
					b.click:SetPoint("TOPLEFT", b.icon, "TOPLEFT")
					b.click:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT")
				end
			end
			if db.fontcolor then
				local c = db.fontcolor
				b.time:SetTextColor(c.r, c.g, c.b, c.a)
			end
			b:Hide()
			b.click:EnableMouse(not db.nomouse)
		end
		if Stuf.inworld then
			UpdateTotem(unit, uf, nil, nil, a5, config)
		end
	end)

end

if CLS == "DRUID" or CLS == "PRIEST" or CLS == "SHAMAN" then  -- Druid Bar ------------------------------------------------------------------------------
	Stuf:AddBuilder("druidbar", function(unit, uf, name, db)
		if unit ~= "player" then return end
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db)
			f.bg = f:CreateTexture(nil, "BACKGROUND")
			f.bg:SetAllPoints(f)
			f.barbase = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
			f.bar = f:CreateTexture(nil, "ARTWORK")
			
			-- Druid bar uses a native StatusBar to avoid secret-value arithmetic.
			if not f.nativeDruidBar then
				local nb = CreateFrame("StatusBar", nil, f.barbase)
				nb:SetAllPoints(f.barbase)
				nb:SetMinMaxValues(0, 1)
				nb:SetValue(1)
				f.nativeDruidBar = nb
				f.bar:SetAlpha(0)  -- hide the old texture, nativeDruidBar renders instead
			end
			uf.refreshfuncs[name] = function(unit, uf, f)
				uf = uf or su[unit]
				f = f or (uf and not uf.hidden and uf.druidbar)
				if not f or f.db.hide then return end
				
				if uf.cache.powertype == 0 then
					f:Hide()
				else
					-- Pass raw secret values directly to C; no Lua division
					local current = UnitPower(unit, 0)
					local total = UnitPowerMax(unit, 0)
					if f.nativeDruidBar then
						f.nativeDruidBar:SetMinMaxValues(0, total)
						f.nativeDruidBar:SetValue(current)
					end
					f:Show()
				end
			end
			Stuf:AddEvent("UNIT_POWER_UPDATE", uf.refreshfuncs[name])
			Stuf:RegisterElementRefresh(uf, name, "metroelements", true)
		end
		if db.fade and not f.barfade then
			f.barfade = f:CreateTexture(nil, "BORDER")
		end
		UpdateBarLook(unit, uf, f, db)
		
		local c = db.barcolor or Stuf.whitecolor
		f.bar:SetVertexColor(c.r, c.g, c.b, db.baralpha or c.a or 1)
	end)
end

if CLS == "DEATHKNIGHT" then  -- Rune Bar -------------------------------------------------------------------------------------------------------

	Stuf:AddBuilder("runebar", function(unit, uf, name, db, a5, config)
		if unit ~= "player" then return end
		local f = RuneFrame
		if not f or db.hide then
			if f then
				f:Hide()
				f:SetAlpha(0)
			end
			return
		end

		f:SetParent(uf)
		-- Suppress Blizzard's own positioning scripts so they don't fight our anchor
		if not f._stufOwned then
		f:SetScript("OnUpdate", nil)
		f:SetScript("OnEvent", nil)
		f:UnregisterAllEvents()
		f._stufOwned = true
		end
		f:ClearAllPoints()
		f:SetPoint("TOP", uf, "BOTTOM", db.x or 0, db.y or 0)
		f:SetScale(db.scale or 1)
		f:SetAlpha(db.alpha or 1)
		if db.framelevel then
		f:SetFrameLevel(db.framelevel)
		end
		if db.strata then
		f:SetFrameStrata(db.strata)
		end
		f:EnableMouse(not db.nomouse)
		f:Show()
	end)


end
if CLS == "PALADIN" then  -- Holy Bar -------------------------------------------------------------------------------------------------------
	-- PaladinPowerBarFrame no longer exists in 12.0.1 (Midnight).
	-- 5 individual orbs using point.tga, styled after the comboframe individual-circles pattern.
	local holyPowerType = (Enum.PowerType and Enum.PowerType.HolyPower) or 9
	local HOLY_MAX = 5
	local HOLY_TGA = "Interface\\AddOns\\Stuf\\media\\holy_tga.tga"

	local function HolyGlowOnUpdate(this, a1)
		-- Pulse the glow alpha on active orbs, same as comboframe
		local dir = this.dir or 1
		local alp = (this.alp or 0.7) + a1 * dir
		if (dir == 1 and alp > 0.95) or (dir == -1 and alp < 0.45) then
			this.dir = dir * -1
		end
		this.alp = alp
		for i = 1, HOLY_MAX do
			local orb = this[i]
			if orb and orb.glow and orb.glow.active then
				orb.glow:SetAlpha(alp)
			end
		end
	end

	Stuf:AddBuilder("holybar", function(unit, uf, name, db, a5, config)
		if unit ~= "player" then return end
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
			f.db = db
			uf[name] = f
			f:SetScript("OnUpdate", HolyGlowOnUpdate)

			-- Build 5 orb frames, each using the full holy_tga.tga image
			for i = 1, HOLY_MAX do
				local orb = CreateFrame("Frame", nil, f, BackdropTemplateMixin and 'BackdropTemplate')
				local tex = orb:CreateTexture(nil, "ARTWORK")
				tex:SetTexture(HOLY_TGA)
				tex:SetTexCoord(0, 1, 0, 1)
				tex:SetAllPoints(orb)
				orb.texture = tex
				-- glow is the same texture on a higher layer for the pulse effect
				local glow = orb:CreateTexture(nil, "OVERLAY")
				glow:SetTexture(HOLY_TGA)
				glow:SetTexCoord(0, 1, 0, 1)
				glow:SetAllPoints(orb)
				glow:SetBlendMode("ADD")
				glow.active = false
				orb.glow = glow
				f[i] = orb
			end

			-- Update: extract safe plain integer from secret Holy Power value
			local function UpdateHolyPower(evtUnit, powerToken)
				if evtUnit and evtUnit ~= "player" then return end
				if powerToken and powerToken ~= "HOLY_POWER" then return end
				local fuu = su["player"]
				local ff = fuu and not fuu.hidden and fuu[name]
				if not ff or ff.db.hide then return end
				-- Secret value: pcall-extract a plain integer 0-5
				local cur = UnitPower("player", holyPowerType)
				local points = 0
				for i = 1, HOLY_MAX do
					local match = false
					pcall(function() match = (cur == i) end)
					if match then points = i; break end
				end
				local cc = ff.db.barcolor or { r=1.0, g=0.82, b=0.0, a=1 }
				local gc = ff.db.glowcolor or cc
				for i = 1, HOLY_MAX do
					local orb = ff[i]
					if i <= points then
						orb.texture:SetVertexColor(cc.r, cc.g, cc.b, ff.db.baralpha or cc.a or 1)
						orb.glow:SetVertexColor(gc.r, gc.g, gc.b, gc.a or 0.8)
						orb.glow.active = true
						orb:Show()
					else
						orb.texture:SetVertexColor(cc.r * 0.25, cc.g * 0.25, cc.b * 0.25, 0.5)
						orb.glow:SetAlpha(0)
						orb.glow.active = false
						orb:Show()  -- always visible as dim inactive orb
					end
				end
			end
			f.UpdateHolyPower = UpdateHolyPower
			uf.refreshfuncs[name] = UpdateHolyPower
			Stuf:AddEvent("UNIT_POWER_UPDATE",    UpdateHolyPower)
			Stuf:AddEvent("UNIT_MAXPOWER",         UpdateHolyPower)
			Stuf:AddEvent("UNIT_DISPLAYPOWER",     UpdateHolyPower)
			Stuf:AddEvent("PLAYER_ENTERING_WORLD", function() UpdateHolyPower() end)
		end

		-- Layout orbs: use db.w as orb size, db.spacing as gap (default 2)
		local ow = db.w or 14
		local oh = db.h or 14
		local spacing = db.spacing or 2
		local cc = db.barcolor or { r=1.0, g=0.82, b=0.0, a=1 }
		local gc = db.glowcolor or cc
		for i = 1, HOLY_MAX do
			local orb = f[i]
			orb:SetWidth(ow)
			orb:SetHeight(oh)
			orb:ClearAllPoints()
			if i == 1 then
				orb:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
			else
				orb:SetPoint("LEFT", f[i-1], "RIGHT", spacing, 0)
			end
			-- base texture: dim when inactive
			orb.texture:SetTexture(HOLY_TGA)
			orb.texture:SetTexCoord(0, 1, 0, 1)
			orb.texture:SetVertexColor(cc.r * 0.25, cc.g * 0.25, cc.b * 0.25, 0.5)
			-- additive glow layer: pulsing when active, hidden when inactive
			orb.glow:SetTexture(HOLY_TGA)
			orb.glow:SetTexCoord(0, 1, 0, 1)
			orb.glow:SetVertexColor(gc.r, gc.g, gc.b, gc.a or 0.8)
			orb.glow.active = false
			orb.glow:SetAlpha(0)
		end

		-- Size the container to fit all orbs
		f:SetWidth((ow * HOLY_MAX) + (spacing * (HOLY_MAX - 1)))
		f:SetHeight(oh)
		f:ClearAllPoints()
		f:SetPoint("TOP", uf, "BOTTOM", db.x or 0, db.y or 0)
		f:SetScale(db.scale or 1)
		f:SetAlpha(db.alpha or 1)
		if db.framelevel then f:SetFrameLevel(db.framelevel) end
		if db.strata then f:SetFrameStrata(db.strata) end
		f:EnableMouse(not db.nomouse)
		f:Show()

		if Stuf.inworld then
			f.UpdateHolyPower()
		end
	end)

end
if CLS == "PRIEST" then  -- Priest Power Frame -----------------------------------------------------------------------------------------------
	Stuf:AddBuilder("priestbar", function(unit, uf, name, db, a5, config) 
		if unit ~= "player" then return end
		local f = PriestBarFrame
		if not f or db.hide then
			if f then f:Hide() end
			return
		end

		f:SetParent(uf)
		f:SetPoint("TOP", uf, "BOTTOM", db.x or 0, db.y or 0)
		f:SetScale(db.scale or 1)
		f:SetAlpha(db.alpha or 1)
		if db.framelevel then
			f:SetFrameLevel(db.framelevel)
		end
		if db.strata then
			f:SetFrameStrata(db.strata)
		end
		f:EnableMouse(not db.nomouse)
	end)

end
if CLS == "WARLOCK" then  -- Warlock Power Frame -----------------------------------------------------------------------------------------------
	Stuf:AddBuilder("shardbar", function(unit, uf, name, db, a5, config) 
		if unit ~= "player" then return end
		local f = WarlockPowerFrame
		if not f or db.hide then
			if f then f:Hide() end
			return
		end

		f:SetParent(uf)
		f:SetPoint("TOP", uf, "BOTTOM", db.x or 0, db.y or 0)
		f:SetScale(db.scale or 1)
		f:SetAlpha(db.alpha or 1)
		if db.framelevel then
			f:SetFrameLevel(db.framelevel)
		end
		if db.strata then
			f:SetFrameStrata(db.strata)
		end
		if _G.ShardBarFrame then _G.ShardBarFrame:EnableMouse(not db.nomouse) end
		if _G.DemonicFuryBarFrame then _G.DemonicFuryBarFrame:EnableMouse(not db.nomouse) end
		if _G.BurningEmbersBarFrame then _G.BurningEmbersBarFrame:EnableMouse(not db.nomouse) end
	end)

end
if CLS == "MONK" then  -- Monk Power Frame -----------------------------------------------------------------------------------------------
	Stuf:AddBuilder("chibar", function(unit, uf, name, db, a5, config) 
		if unit ~= "player" then return end
		local f = MonkHarmonyBarFrame
		if not f or db.hide then
			if f then f:Hide() end
			return
		end

		f:SetParent(uf)
		f:SetPoint("TOP", uf, "BOTTOM", db.x or 0, db.y or 0)
		f:SetScale(db.scale or 1)
		f:SetAlpha(db.alpha or 1)
		if db.framelevel then
			f:SetFrameLevel(db.framelevel)
		end
		if db.strata then
			f:SetFrameStrata(db.strata)
		end
		if _G.MonkHarmonyBar then _G.MonkHarmonyBar:EnableMouse(not db.nomouse) end
		for i = 1, 4, 1 do
			if _G.MonkHarmonyBar and _G.MonkHarmonyBar["lightEnergy"..i] then
				_G.MonkHarmonyBar["lightEnergy"..i]:EnableMouse(not db.nomouse)
			end
		end
	end)
end
