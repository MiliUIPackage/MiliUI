if not Stuf then return end

local Stuf = Stuf
local su = Stuf.units
local dbg, dbgaura, notmage, iswarlock
Stuf:AddOnInit(function(_, idbg, CLS) 
	dbg = idbg
	dbgaura = dbg.auracolor
	notmage, iswarlock = CLS ~= "MAGE", CLS == "WARLOCK"
	-- In 12.0.1 DebuffTypeColor may be nil; seed fallback colors so debuff
	-- type lookups (dbgaura.Curse etc.) never return nil.
	dbgaura.Magic   = dbgaura.Magic   or { r=0.2,  g=0.2,  b=1.0  }
	dbgaura.Curse   = dbgaura.Curse   or { r=0.6,  g=0.0,  b=1.0  }
	dbgaura.Poison  = dbgaura.Poison  or { r=0.0,  g=0.6,  b=0.0  }
	dbgaura.Disease = dbgaura.Disease or { r=0.6,  g=0.4,  b=0.0  }
end)

local floor, ceil = floor, ceil
local pairs, ipairs = pairs, ipairs
local sort, tremove, tinsert = sort, tremove, tinsert
local strmatch = strmatch
local GetTime = GetTime
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local stamin, stahr = 1/60, 1/3600

local backdrop = { bgFile="Interface\\AddOns\\Stuf\\media\\aura1.tga", }

local key = { L = "LEFT", R = "RIGHT", T = "TOP", B = "BOTTOM", }
local function GrowthBreakdown(var)
	local d1, d2, d3, d4 = strmatch(var or "LRTB", "(%u?)(%u?)(%u?)(%u?)")
	d1, d2, d3, d4 = key[d1 or "L"], key[d2 or "R"], key[d3 or "T"], key[d4 or "B"]
	
	local hdir, vdir
	if d1 == "LEFT" or d1 == "RIGHT" then
		hdir, vdir = (d1 == "RIGHT" and -1) or 1, (d3 == "BOTTOM" and 1) or -1
	else
		hdir, vdir = (d3 == "RIGHT" and -1) or 1, (d1 == "BOTTOM" and 1) or -1
	end
	return d1, d2, d3, d4, hdir, vdir
end
Stuf.GrowthBreakdown = GrowthBreakdown


local StartTimer, StopTimer, SortTimerBars
do  -- Timer Bars handlers --------------------------------------------------------------------------------------------
	local bars = { }
	-- lsort: sort timer bars by time remaining.
	-- endtime stores a raw expirationTime from C_UnitAuras — tainted secret
	-- number in 12.0.1.  Comparing two tainted numbers crashes Lua, so wrap
	-- the comparison in pcall.  On failure treat as equal (false), which keeps
	-- sort stable and avoids an infinite loop in table.sort.
	local function lsort(a, b)
		local result = false
		pcall(function() result = a.endtime < b.endtime end)
		return result
	end
	local function ClearAndSetPoint(f, lrp, lrt, lp, lx, ly, rrp, rrt, rp, rx, ry)
		f:ClearAllPoints()
		f:SetPoint(lrp, lrt, lp, lx, ly)
		if rrp then f:SetPoint(rrp, rrt, rp, rx, ry) end
	end
	function SortTimerBars(p, ptimers)
		local db = p.db
		local count, cols, rows = db.count, db.cols, db.rows
		local d1, d2, d3, d4 = p.d1, p.d2, p.d3, p.d4
		local hdir, vdir = p.hdir, p.vdir
		local spacing, vspacing = db.spacing or 0, db.vspacing or 0

		sort(ptimers, lsort)
		if d1 == "LEFT" or d1 == "RIGHT" then  -- LRTB, LRBT, RLTB, RLBT
			for i, icon in ipairs(ptimers) do
				local crow = ceil(i / cols)
				if crow > rows then
					icon:Hide()
				else
					local ccol = i % cols
					ccol = (ccol == 0 and cols) or ccol
					icon:ClearAllPoints()
					if i == 1 then
						icon:SetPoint(d3..d1, p, d3..d1)
					elseif ccol == 1 then
						icon:SetPoint(d3, ptimers[i - cols], d4, 0, (1 + vspacing) * vdir)
					else
						icon:SetPoint(d1, ptimers[i - 1], d2, (2 + spacing) * hdir, 0)
					end
					icon:Show()
				end
			end
		else  -- TBLR, TBRL, BTLR, BTRL
			for i, icon in ipairs(ptimers) do
				local ccol = ceil(i / rows)
				if ccol > cols then
					icon:Hide()
				else
					icon:ClearAllPoints()
					local crow = i % rows
					crow = (crow == 0 and rows) or crow
					if i == 1 then
						icon:SetPoint(d1..d3, p, d1..d3)
					elseif crow == 1 then
						icon:SetPoint(d3, ptimers[i - rows], d4, (2 + spacing) * hdir, 0)
					else
						icon:SetPoint(d1, ptimers[i - 1], d2, 0, (1 + vspacing) * vdir)
					end
					icon:Show()
				end
			end
		end
	end
	local function TimerOnUpdate(this, a1)
		this.nextupdate = this.nextupdate - a1
		if this.nextupdate > 0 then return end
		this.nextupdate = this.throt

		-- expirationTime is tainted; wrap arithmetic in pcall.
		local remain
		pcall(function() remain = this.endtime - GetTime() end)
		if not remain then return end
		this.bar:SetValue(remain * this.duration, this.bvalue)
		if remain < 60 then
			if remain > 10 then
				this.time:SetFormattedText("%d", remain)
			elseif remain > 0.8 then
				this.nextupdate = 0.03
				this.time:SetFormattedText("%0.1f", remain)
			elseif remain > -0.2 then
				this.nextupdate = 0.03
				this:SetAlpha(remain + 0.2)
				this.time:SetFormattedText("%0.1f", remain < 0 and 0 or remain)
			else
				local p = this:GetParent()
				StopTimer(this.name, p)
				SortTimerBars(p, p.timers)
				return
			end
		elseif remain < 600 then
			this.time:SetFormattedText("%d:%02d", remain * stamin, remain % 60)
		elseif remain < 3600 then
			this.time:SetFormattedText("%dm", 1 + remain * stamin)
		else
			this.time:SetFormattedText("%0.1fh", remain * stahr)
		end
	end
	local function GetTimer(name, p, db)
		local timer
		for k, v in ipairs(p.timers) do
			if v.name == name then
				timer = v
			end
		end
		if not timer then
			timer = tremove(bars)  -- attempt to get unused timer
			if not timer then  -- create new timer
				timer = CreateFrame("Frame", nil, p, BackdropTemplateMixin and 'BackdropTemplate')
				timer:SetScript("OnUpdate", TimerOnUpdate)
				timer:SetScript("OnHide", TimerOnHide)
				timer:Hide()
			
				timer.icon = timer:CreateTexture(nil, "BORDER")
				timer.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				
				local bb = timer:CreateTexture(nil, "BACKGROUND")
				bb:SetVertexColor(0, 0, 0, 0.4)
				timer.backbar = bb
				
				timer.bar = timer:CreateTexture(nil, "BORDER")
				
				local spark = timer:CreateTexture(nil, "ARTWORK")
				spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
				spark:SetBlendMode("ADD")
				spark:SetAlpha(0.8)
				spark:SetWidth(10)
				timer.spark = spark
				
				timer.ctext = timer:CreateFontString(nil, "OVERLAY")
				timer.ctext:SetPoint("TOPLEFT", bb, "TOPLEFT", 1, 0)
				timer.ctext:SetPoint("BOTTOMRIGHT", bb, "BOTTOMRIGHT", -1, 0)
				
				timer.time = timer:CreateFontString(nil, "OVERLAY")
				timer.time:SetPoint("TOPLEFT", bb, "TOPLEFT", 1, 0)
				timer.time:SetPoint("BOTTOMRIGHT", bb, "BOTTOMRIGHT", -1, 0)
			end
			tinsert(p.timers, timer)
		end

		if timer.p ~= p or timer.pdb ~= p.dbupdate then  -- only update layout when necessary
			timer.p, timer.pdb = p, p.dbupdate
			
			local icon, bar, backbar, spark, ctext, ttext = timer.icon, timer.bar, timer.backbar, timer.spark, timer.ctext, timer.time
			local w, h = db.w, db.h
			local sparkc = db.sparkcolor or Stuf.whitecolor
			local fontc = db.fontcolor or Stuf.whitecolor
			local font = Stuf:GetMedia("font", db.font)
			local fontsize = db.fontsize or (h - 2)
			fontsize = fontsize < 2 and 2 or fontsize
			
			timer:SetWidth(w)
			timer:SetHeight(h)
			if db.framelevel then
				timer:SetFrameLevel(db.framelevel)
			end
		
			timer.bvalue = w - h
			icon:SetWidth(h)
			icon:SetHeight(h)
			bar:SetHeight(h)
			spark:SetHeight(h * 2.3)
			spark:SetVertexColor(sparkc.r, sparkc.g, sparkc.b, sparkc.a)
			bar:SetTexture(Stuf.statusbar)
			backbar:SetTexture(Stuf.statusbar)
			ctext:SetFont(font, fontsize - 1)
			ctext:SetTextColor(fontc.r, fontc.g, fontc.b, fontc.a)
			ttext:SetFont(font, fontsize)
			ttext:SetTextColor(fontc.r, fontc.g, fontc.b, fontc.a)
			
			if db.reverse then
				if timer.reversed ~= 1 then
					ClearAndSetPoint(backbar, "TOPLEFT", timer, "TOPLEFT", 0, 0, "BOTTOMRIGHT", icon, "BOTTOMLEFT", 0, 0)
					ClearAndSetPoint(icon, "RIGHT", timer, "RIGHT")
					ClearAndSetPoint(bar, "RIGHT", backbar, "RIGHT")
					spark:SetPoint("CENTER", bar, "LEFT")
					ctext:SetJustifyH("RIGHT")
					ttext:SetJustifyH("LEFT")
					Stuf:GetTexCoordOptions(false, "hflip", true, nil, bar)
					timer.reversed = 1
				end
			elseif timer.reversed ~= 0 then
				ClearAndSetPoint(backbar, "TOPLEFT", icon, "TOPRIGHT", 0, 0, "BOTTOMRIGHT", timer, "BOTTOMRIGHT", 0, 0)
				ClearAndSetPoint(icon, "LEFT", timer, "LEFT")
				ClearAndSetPoint(bar, "LEFT", backbar, "LEFT")
				spark:SetPoint("CENTER", bar, "RIGHT")
				ctext:SetJustifyH("LEFT")
				ttext:SetJustifyH("RIGHT")
				Stuf:GetTexCoordOptions(false, "normal", false, nil, bar)
				timer.reversed = 0
			end
		end
		return timer
	end
	function StartTimer(name, duration, endtime, icon, color, count, p, spellname)
		local f = GetTimer(name, p, p.db)
		f.name = name
		f:SetParent(p)
		f.endtime = endtime
		-- duration is a tainted secret number in 12.0.1; wrap all arithmetic
		-- and comparisons in pcall.  Fall back to safe defaults on failure.
		pcall(function() f.duration = 1 / duration end)
		if not f.duration then f.duration = 1 end
		local throt = 0.1
		pcall(function() throt = (duration < 300 and 0.1) or (duration < 600 and 0.25) or 0.5 end)
		f.throt = throt
		f.nextupdate = 0
		-- count is nil or plain int from GetAuraCount; pass with or "" to be safe
		f.ctext:SetFormattedText("%s%s", count or "", p.db.showspellname and spellname or "")
		f.icon:SetTexture(icon)
		f.bar:SetVertexColor(color.r, color.g, color.b, color.a or 0.9)
		f:SetAlpha(1)
		f:Show()
	end
	function StopTimer(name, parent)
		for k, v in ipairs(parent.timers) do
			if v.name == name then
				v.name = ""
				v:Hide()
				tinsert(bars, tremove(parent.timers, k))
				break
			end
		end
	end
end

local function AuraTimeTextOnUpdate(this, a1)
	this.nextupdate = (this.nextupdate or 0) - a1
	if this.nextupdate > 0 then return end

	-- expirationTime (stored in this.endtime) is a tainted secret number in
	-- 12.0.1.  Arithmetic on it in Lua crashes.  Wrap in pcall; on failure
	-- stop the timer gracefully rather than spamming errors every frame.
	local remain
	pcall(function() remain = this.endtime - GetTime() end)
	if not remain then
		this.ttext:SetText("")
		this:SetScript("OnUpdate", nil)
		return
	end
	if remain < 60 then
		if remain > 10 then
			this.ttext:SetFormattedText("%d", remain)
			this.nextupdate = remain - floor(remain)
		elseif remain > 0 then
			this.ttext:SetFormattedText("%0.1f", remain)
			this.nextupdate = 0.08
		else
			this.ttext:SetText("")
			this:SetScript("OnUpdate", nil)
		end
		if this.id and GameTooltip:IsOwned(this) then
			this:GetScript("OnEnter")(this)
		end
	elseif remain < 3600 then
		this.ttext:SetFormattedText("%dm", 1 + remain * stamin)
		this.nextupdate = remain % 60
	else
		this.ttext:SetFormattedText("%0.1fh", remain * stahr)
		this.nextupdate = remain % 3600
	end
end
local function StartIconTimer(this, duration, endtime, mine)
	-- endtime/duration may be secret tainted numbers in 12.0.1; wrap all comparisons
	-- and arithmetic in pcall so they can be passed to C functions safely.
	local endtime_ok = false
	pcall(function() if endtime and endtime > 0 then endtime_ok = true end end)
	if this.ttext then
		if (mine or not this.ttextonlymine) and endtime_ok then
			this.endtime = endtime
			this.nextupdate = 0
			this:SetScript("OnUpdate", AuraTimeTextOnUpdate)
		else
			this.ttext:SetText("")
			this:SetScript("OnUpdate", nil)
		end
	end
	if this.showpie then
		if (mine or this.showpie ~= 1) and endtime_ok then
			pcall(function() this.pie:SetCooldown(endtime - duration, duration) end)
			this.pie:Show()
		else
			this.pie:Hide()
		end
	end
end

local UpdateAura
do 	-- Aura handlers --------------------------------------------------------------------------------------------------
	local function getoffset(t, xy, dir)  -- gets precalculated offset if certain aura icons are shown
		local offset = 0
		for index, frame in ipairs(t) do
			if frame:IsShown() then
				offset = (frame[xy] or 0) + (1 * dir)
			else
				break
			end
		end
		return offset
	end
	local function ApplyPush(buffgroup, debuffgroup, auratimers)
		local x, y = 0, 0

		local bdb = buffgroup and buffgroup.db
		local ddb = debuffgroup and debuffgroup.db
		local adb = auratimers and auratimers.db

		if buffgroup and not buffgroup.disablepush then
			if (bdb.push == "v" or bdb.push == "h") then
				local castbar = buffgroup:GetParent().castbar
				if castbar and castbar:IsShown() then
					if bdb.push == "v" then
						y = (castbar.db.h + 2) * buffgroup.vdir
					else
						x = (castbar.db.w + 2) * buffgroup.hdir
					end
				end
			end
			buffgroup:SetPoint("TOPLEFT", bdb.x + x, bdb.y + y)
		end
		if debuffgroup then
			if buffgroup and (ddb.push == "h" or ddb.push == "v") then
				if ddb.push == "h" then
					x = x + getoffset(buffgroup.firstrow, "xoff", buffgroup.hdir)
				else
					y = y + getoffset(buffgroup.firstcol, "yoff", buffgroup.vdir)
				end
				debuffgroup:SetPoint("TOPLEFT", ddb.x + x, ddb.y + y)
			else
				debuffgroup:SetPoint("TOPLEFT", ddb.x, ddb.y)
			end
		end
		if auratimers then
			if debuffgroup and (adb.push == "h" or adb.push == "v") then
				if adb.push == "h" then
					x = x + getoffset(debuffgroup.firstrow, "xoff", debuffgroup.hdir)
				else
					y = y + getoffset(debuffgroup.firstcol, "yoff", debuffgroup.vdir)
				end
				auratimers:SetPoint("TOPLEFT", adb.x + x, adb.y + y)
			else
				auratimers:SetPoint("TOPLEFT", adb.x, adb.y)
			end
		end
	end
	Stuf.ApplyPush = ApplyPush
	local ShowSetupMode
	local temp, debuffconfig, rtime, showpet = { }, nil, nil, nil

	-- -----------------------------------------------------------------------
	-- 12.0.1 Secret-safe aura API layer
	-- -----------------------------------------------------------------------
	-- In 12.0 / Midnight, almost every field in C_UnitAuras data tables is a
	-- "secret tainted value": you cannot compare, do arithmetic on, or use as
	-- a table key in Lua.  You CAN pass them straight to C API functions
	-- (SetTexture, SetText, SetCooldown, etc.).
	--
	-- The fix: replace tainted field reads with dedicated C_UnitAuras APIs
	-- that return plain Lua values:
	--
	--   IsAuraFilteredOutByInstanceID(unit, aid, filter)
	--       Returns a plain boolean.  "Not filtered out" = aura passes the
	--       filter.  Used for ownership (HELPFUL|PLAYER / HARMFUL|PLAYER).
	--
	--   GetAuraApplicationDisplayCount(unit, aid, min, max)
	--       Returns a tainted number in 12.0.1 too, so we pcall the >= 2
	--       comparison inside GetAuraCount and return nil or a plain int.
	--
	--   GetAuraDispelTypeColor(unit, aid, colorCurve)
	--       Returns a ColorMixin directly — bypasses the tainted dispelName
	--       field entirely.  We build a color curve from stUF's dbgaura colors
	--       once (lazily) and reuse it.  isStealable still needs pcall.
	--
	--   name, icon, duration, expirationTime: left as tainted — they are only
	--   ever passed to C functions (SetTexture, SetText, SetCooldown) which
	--   accept secret values without complaint.
	-- -----------------------------------------------------------------------

	local _isFiltered     -- C_UnitAuras.IsAuraFilteredOutByInstanceID
	local _getStackCount  -- C_UnitAuras.GetAuraApplicationDisplayCount
	local _getDispelColor -- C_UnitAuras.GetAuraDispelTypeColor
	local _dispelCurve    -- built lazily; maps dispel type index -> stUF dbgaura color
	local _apisReady = false
	local function BindAuraAPIs()
		if _apisReady or not C_UnitAuras then return end
		_isFiltered     = C_UnitAuras.IsAuraFilteredOutByInstanceID
		_getStackCount  = C_UnitAuras.GetAuraApplicationDisplayCount
		_getDispelColor = C_UnitAuras.GetAuraDispelTypeColor
		_apisReady = true
	end

	-- IsPlayerAura: returns plain bool — true if this aura was cast by the
	-- player or their pet.  Replaces the tainted isFromPlayerOrPlayerPet field.
	local function IsPlayerAura(unit, aid, isHelpful)
		if not _isFiltered or not aid then return false end
		local filter = isHelpful and "HELPFUL|PLAYER" or "HARMFUL|PLAYER"
		-- "filtered out" = false means aura PASSES the player filter = is ours
		return (_isFiltered(unit, aid, filter) == false)
	end

	-- GetAuraCount: returns a plain integer stack count (>= 2), or NIL when
	-- there are fewer than 2 stacks (nothing to display).  Returning nil lets
	-- all callsites use `count or ""` with NO Lua comparison on count — zero
	-- risk of a taint crash at the callsite.
	--
	-- GetAuraApplicationDisplayCount also returns a tainted secret number in
	-- 12.0.1 (just like d.applications), so we still need pcall on the >= 2
	-- comparison inside this function.
	local function GetAuraCount(unit, aid)
		if not _getStackCount or not aid then return nil end
		local n = _getStackCount(unit, aid, 2, 99)
		if type(n) ~= "number" then return nil end
		local val = nil
		pcall(function() if n >= 2 then val = n end end)
		return val  -- nil (hide count text) or plain integer >= 2
	end

	-- BuildDispelCurve: creates a C_CurveUtil color curve mapping dispel type
	-- indices to stUF's own dbgaura colors.  Called lazily on first use.
	-- Indices (Blizzard SpellDispelType DB2): 0=None, 1=Magic, 2=Curse, 3=Disease, 4=Poison
	local function BuildDispelCurve()
		if not C_CurveUtil then return nil end
		local curve = C_CurveUtil.CreateColorCurve()
		curve:SetType(Enum.LuaCurveType.Step)
		local function addPoint(idx, clr)
			if clr then curve:AddPoint(idx, CreateColor(clr.r, clr.g, clr.b, 1)) end
		end
		addPoint(0, dbgaura.Buff)     -- None -> generic
		addPoint(1, dbgaura.Magic)    -- Magic
		addPoint(2, dbgaura.Curse)    -- Curse
		addPoint(3, dbgaura.Disease)  -- Disease
		addPoint(4, dbgaura.Poison)   -- Poison
		return curve
	end

	-- GetDispelColor: returns a ColorMixin for the aura's dispel type via the
	-- C API directly — no pcall, no tainted dispelName field access at all.
	-- Returns nil for non-dispellable auras or when the API is unavailable.
	-- ColorMixin exposes .r .g .b, compatible with SetBackdropColor.
	local function GetDispelColor(unit, aid)
		if not _getDispelColor or not aid then return nil end
		if not _dispelCurve then _dispelCurve = BuildDispelCurve() end
		if not _dispelCurve then return nil end
		return _getDispelColor(unit, aid, _dispelCurve)
	end

	-- IsMagicType: plain bool — true if dispel type is Magic (index 1).
	-- d.dispelType is numeric but still tainted in 12.0.1, so one pcall needed.
	local function IsMagicType(d)
		local result = false
		pcall(function() if d.dispelType == 1 then result = true end end)
		return result
	end

	-- GetIsStealable: plain bool.  isStealable has no dedicated API; pcall-decode.
	local function GetIsStealable(d)
		local v = false
		pcall(function() if d.isStealable then v = true end end)
		return v
	end

	-- UnitBuff / UnitDebuff: drop-in replacements for the removed global
	-- functions.  Return the same 8-value tuple the rest of the code expects,
	-- but every value is either plain (safe to compare) or tainted-but-only-
	-- used-in-C-calls (safe to pass through).
	--
	-- auraInstanceID from the data table is ALWAYS a plain number per Blizzard
	-- 12.0 documentation — it is the stable ID used by all the new APIs.
	local function UnitBuff(unit, index, filter)
		if not _apisReady then BindAuraAPIs() end
		local ok, d = pcall(C_UnitAuras.GetBuffDataByIndex, unit, index, filter)
		if not ok or not d then return nil end
		local aid = d.auraInstanceID  -- plain number
		return d.name, d.icon,
		       GetAuraCount(unit, aid),        -- nil or plain int >= 2
		       GetDispelColor(unit, aid),      -- ColorMixin or nil (no pcall)
		       IsMagicType(d),                 -- plain bool
		       d.duration, d.expirationTime,   -- tainted, C-only
		       IsPlayerAura(unit, aid, true),  -- plain bool
		       GetIsStealable(d)               -- plain bool
	end
	local function UnitDebuff(unit, index, filter)
		if not _apisReady then BindAuraAPIs() end
		local ok, d = pcall(C_UnitAuras.GetDebuffDataByIndex, unit, index, filter)
		if not ok or not d then return nil end
		local aid = d.auraInstanceID
		return d.name, d.icon,
		       GetAuraCount(unit, aid),
		       GetDispelColor(unit, aid),
		       IsMagicType(d),
		       d.duration, d.expirationTime,
		       IsPlayerAura(unit, aid, false),
		       GetIsStealable(d)
	end
	function UpdateAura(unit, uf, _, _, _, config)  -- updates all elements dealing with buffs/debuffs
		-----------------------------------------------
		-- edited on 3MAY2022 uf = uf or su[unit]
		-- In 12.0.1, UNIT_AURA fires with (unit, updateInfo) where updateInfo is
		-- a table.  The old "is it a table?" check mistook updateInfo for a unit
		-- frame, making live aura updates silently do nothing.  Check for .cache
		-- which only a real stUF unit frame carries.
		uf = (type(uf) == "table" and uf.cache) and uf or su[unit]
		-----------------------------------------------
		if not uf or uf.hidden then return end
		
		local allow, clr, bfilter, dfilter, onlymineb, onlymined = true, nil, nil, nil, nil, nil
		local name, icon, count, acolor, ismagic, duration, endtime, ismine, isstealable
		local cache = uf.cache
		
		local dispellicon, buffgroup, debuffgroup, auratimers = uf.dispellicon, uf.buffgroup, uf.debuffgroup, uf.auratimers
		if not dispellicon or dispellicon.hidden then
			dispellicon = nil
		end
		if not buffgroup or buffgroup.hidden then
			buffgroup = nil
		elseif cache.assist then
			bfilter = buffgroup.filter
			onlymineb = buffgroup.db.onlymine
		end
		if not debuffgroup or debuffgroup.hidden then
			debuffgroup = nil
		elseif cache.assist then
			dfilter = debuffgroup.filter
		else
			onlymined = debuffgroup.db.onlymine
		end
		if not auratimers or auratimers.hidden then
			auratimers = nil
		else
			for k, v in ipairs(auratimers.timers) do
				temp[v.name] = true
			end
			showpet = auratimers.db.showpet or Stuf.vunit == "pet"
		end
		if config then
			ShowSetupMode = ShowSetupMode or function(dispellicon, buffgroup, debuffgroup, auratimers)  -- shows buffs/debuffs in config mode
				local currenttime = GetTime()
				if dispellicon then
					-- dbgaura.Curse may be nil if DebuffTypeColor was absent at startup (12.0.1)
					local dc = dbgaura.Curse or dbgaura.Buff or { r=0.5, g=0, b=0.5 }
					dispellicon.texture:SetTexture("Interface\\Icons\\Spell_ChargeNegative")
					dispellicon.ctext:SetText(2)
					dispellicon:SetBackdropColor(dc.r, dc.g, dc.b)
					dispellicon:Show()
				end
				rtime = rtime or { 0, 65, 610, 3000, }
				for i = 1, 32, 1 do
					local icon = buffgroup and buffgroup[i]
					if icon then
						icon.texture:SetTexture("Interface\\Icons\\Spell_ChargePositive")
						icon.ctext:SetText(i)
						local clr = i > 3 and dbgaura.Buff or dbgaura.MyBuff
						icon:SetBackdropColor(clr.r, clr.g, clr.b)
						icon:Show()
						local duration = rtime[math.random(1,4)] or 0
						StartIconTimer(icon, duration, currenttime + duration, true)
					end
					if auratimers and i <= auratimers.db.count/2 then
						local duration = 30 * i
						StartTimer("b"..i, duration, currenttime + duration, "Interface\\Icons\\Spell_ChargePositive", dbgaura.MyBuff, i*2 - 2, auratimers, "Spell Name Spell Name Spell Name")
						temp["b"..i] = nil
					end
				end
				debuffconfig = debuffconfig or { "none", "Magic", "Curse", "Poison", "Disease", }
				for i = 1, 40, 1 do
					local icon = debuffgroup and debuffgroup[i]
					-- dbgaura may lack debuff type entries if DebuffTypeColor was nil at startup (12.0.1)
					local clr = dbgaura[debuffconfig[(i % 5) + 1] or "none"] or dbgaura.Buff or { r=0.5, g=0, b=0.5 }
					if icon then
						icon.texture:SetTexture("Interface\\Icons\\Spell_ChargeNegative")
						icon.ctext:SetText(i)
						icon:SetBackdropColor(clr.r, clr.g, clr.b)
						icon:Show()
						local duration = rtime[math.random(1,4)] or 0
						StartIconTimer(icon, duration, currenttime + duration, true)
					end
					if auratimers and i <= auratimers.db.count/2 then
						local duration = 30.5 * i
						StartTimer("d"..i, duration, currenttime + duration, "Interface\\Icons\\Spell_ChargeNegative", clr, i*2-1, auratimers, "Spell Name Spell Name Spell Name")
						temp["d"..i] = nil
					end
				end
				if auratimers then  -- stop timers that shouldn't exist anymore
					for k, v in pairs(temp) do
						StopTimer(k, auratimers)
					end
					SortTimerBars(auratimers, auratimers.timers)
				end
				ApplyPush(buffgroup, debuffgroup, auratimers)
			end
			return ShowSetupMode(dispellicon, buffgroup, debuffgroup, auratimers)
		end
		if dispellicon then
			if cache.assist then
				if iswarlock then
					if UnitCreatureFamily("pet") == "Felhunter" then
						for i = 1, 40, 1 do
						name, icon, count, acolor, ismagic = UnitDebuff(unit, i)
						if not name or ismagic then
							break
						else
							name = nil
						end
					end
					end
				else
					name, icon, count, acolor, ismagic = UnitDebuff(unit, 1, "RAID")
				end
				if name then
					local dc = acolor or dbgaura.Buff
					dispellicon.texture:SetTexture(icon)
					dispellicon.ctext:SetText(count or "")  -- count is nil or plain int
					dispellicon:SetBackdropColor(dc.r, dc.g, dc.b)
					dispellicon:Show()
				else
					dispellicon:Hide()
				end
			else
				dispellicon:Hide()
			end
		end

		for i = 1, 32, 1 do  -- update buffgroup
			if allow then  -- prevents calling UnitBuff when it's useless
				name, icon, count, acolor, ismagic, duration, endtime, ismine, isstealable = UnitBuff(unit, i, bfilter)
				allow = name and (not onlymineb or ismine)
			end
			
			local b = buffgroup and buffgroup[i]
			if b then
				if allow then
					b.texture:SetTexture(icon)
					b.ctext:SetText(count or "")  -- count is nil or plain int; no comparison needed
					if cache.attackable and (isstealable or (ismagic and notmage)) then
						clr = dbgaura.Magic
					elseif ismine then
						clr = dbgaura.MyBuff
					else
						clr = dbgaura.Buff
					end
					b:SetBackdropColor(clr.r, clr.g, clr.b)
					b:Show()
					StartIconTimer(b, duration, endtime, ismine)
				else
					b:Hide()
				end
			elseif not allow then
				break
			end
			if auratimers and ismine then
				StartTimer("b"..i, duration, endtime, icon, dbgaura.MyBuff, count, auratimers, name)
				temp["b"..i] = nil
			end
		end
		
		allow = true
		for i = 1, 40, 1 do  -- update debuffgroup
			if allow then  -- prevents calling UnitDebuff when it's useless
				name, icon, count, acolor, ismagic, duration, endtime, ismine, isstealable = UnitDebuff(unit, i, dfilter)
				clr = acolor or dbgaura.Buff  -- acolor is ColorMixin-or-nil from GetDispelColor
				allow = name and (not onlymined or ismine)
			end
			
			local b = debuffgroup and debuffgroup[i]
			if b then
				if allow then
					b:SetBackdropColor(clr.r, clr.g, clr.b)
					b.texture:SetTexture(icon)
					b.ctext:SetText(count or "")  -- count is nil or plain int; no comparison needed
					b:Show()
					StartIconTimer(b, duration, endtime, ismine)
				else
					b:Hide()
				end
			elseif not allow then
				break
			end
			if auratimers and ismine then
				StartTimer("d"..i, duration, endtime, icon, clr, count, auratimers, name)
				temp["d"..i] = nil
			end
		end
		if auratimers then  -- stop timers that shouldn't exist anymore
			for k, v in pairs(temp) do
				StopTimer(k, auratimers)
				temp[k] = nil
			end
			SortTimerBars(auratimers, auratimers.timers)
		end
		ApplyPush(buffgroup, debuffgroup, auratimers)
	end
end


do  -- Aura Icons -----------------------------------------------------------------------------------------------------
	local lbf = nil
	local GetWeaponEnchantInfo = GetWeaponEnchantInfo
	local function BuffOnEnter(this) -- buff tooltip
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT", 8, -16)
		GameTooltip:SetUnitBuff(this:GetParent().unit, this.id, this:GetParent().filter)
	end
	local function BuffOnClick(this, button) -- right-click to dismount
		if button == "RightButton" and IsMounted() then
			Dismount()
		end
	end
	local function DebuffOnEnter(this) -- debuff tooltip
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT", 8, -16)
		GameTooltip:SetUnitDebuff(this:GetParent().unit, this.id, this:GetParent().filter)
	end
	local function TempOnEnter(this)
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT", 8, -16)
		GameTooltip:SetInventoryItem("player", (this.id == 1 and 16) or 17)
	end
	local function TempEnchantOnUpdate(unit, uf, _, _, _, config)
		uf = uf or su[unit]
		local f = uf and not uf.hidden and uf.tempenchant
		if not f then return end
		
		f.tog = (f.tog or 0) + 1
		if f.tog < 4 then return end
		f.tog = 0
		
		local ctime = GetTime()
		local i1, i2 = f[1], f[2]
		if not i1 or not i2 then return end  -- icons not built yet, skip
		
		local e1, e1duration, e1count, e1id, e2, e2duration, e2count, e2id
		if config then
			e1, e1duration, e1count, e2, e2duration, e2count = true, 60000, 0, true, 600000, 23
		else
			e1, e1duration, e1count, e1id, e2, e2duration, e2count, e2id = GetWeaponEnchantInfo()
		end
		if e1 then
			i1.texture:SetTexture(GetInventoryItemTexture("player", 16))
			i1.ctext:SetText(e1count > 1 and e1count or "")
			i1:Show()
			local duration = e1duration * 0.001
			StartIconTimer(i1, duration, ctime + duration, true)
		else
			i1:Hide()
		end
		if e2 then
			i2.texture:SetTexture(GetInventoryItemTexture("player", 17))
			i2.endtime = ctime + e2duration * 0.001
			i2.ctext:SetText(e2count > 1 and e2count or "")
			i2:Show()
			local duration = e2duration * 0.001
			StartIconTimer(i2, duration, ctime + duration, true)
		else
			i2:Hide()
		end
	end
	local function CreateAuraGroup(unit, uf, name, db, _, config)
		local f = uf[name]
		local isplayer, isbuff, isdebuff, istemp = (unit == "player"), (name == "buffgroup"), (name == "debuffgroup"), (name == "tempenchant")
		if db.hide then
			if f then
				f.hidden = true
				f:Hide()
				if isplayer then
					if istemp then
						if TemporaryEnchantFrame then TemporaryEnchantFrame:Show() end
					elseif isbuff then
						if BuffFrame then BuffFrame:Show() end
						if BuffFrame then BuffFrame:RegisterEvent("UNIT_AURA") end
					end
				end
				UpdateAura(unit, uf, nil, nil, nil, config)
			end
			return
		end
		if not f then
			f = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
			f:SetSize(2, 2)
			f.unit = unit
			f.db = db
			f.firstcol, f.firstrow = { }, { }
			
			uf[name] = f
			uf.refreshfuncs["auras"] = UpdateAura
			if istemp then
				uf.refreshfuncs.tempenchant = TempEnchantOnUpdate
				uf.metroelements.tempenchant = TempEnchantOnUpdate
			-- ================================================
			-- >>> START: RIGHT-CLICK CANCEL AURA TODO <<<
			-- ================================================
			-- TODO: Right-click-to-cancel own buffs — BLOCKED in 12.0.1 (Midnight)
			-- -----------------------------------------------------------------------
			-- The original stUF approach used SecureAuraHeaderTemplate which created
			-- secure child buttons that called RegisterForClicks() in OnLoad.  This
			-- is now ADDON_ACTION_BLOCKED because stUF's code is tainted (we touch
			-- secret values from C_UnitAuras), and RegisterForClicks is also
			-- unavailable inside initialConfigFunction's restricted sandbox.
			--
			-- WHY WE CAN'T JUST WIRE IT UP MANUALLY:
			--   Wall 1 — RegisterForClicks is a protected call.  It can only be
			--            invoked from untainted code, and our aura code is tainted
			--            the moment it touches any C_UnitAuras data field.
			--   Wall 2 — The buff name (d.name) is a tainted secret value in 12.0.1.
			--            To cancel via macro we'd need:
			--              button:SetAttribute("macrotext2", "/cancelaura " .. name)
			--            But concatenating a tainted string taints the whole button,
			--            which blocks it from executing the protected CancelUnitBuff.
			--
			-- THE ONE THING THAT WOULD UNLOCK THIS:
			--   auraInstanceID IS a plain (non-tainted) number per Blizzard's 12.0
			--   documentation.  If Blizzard ever adds a function like:
			--     C_UnitAuras.RemoveAura(auraInstanceID)
			--   ...we could store icon.aid = d.auraInstanceID (plain), then in a
			--   secure OnClick handler call that API without any taint chain.
			--   Watch Blizzard patch notes for this.  Until then, no right-click
			--   cancel is possible without a complete redesign using XML templates.
			-- ================================================
			-- >>> END: RIGHT-CLICK CANCEL AURA TODO <<<
			-- ================================================
			end
		else
			f.hidden = nil
			f:Show()
		end
		
		local x, y, w, h = db.x, db.y, db.w, db.h
		local cfontsize = db.counttfontsize or db.fontsize or (w < 2 and 1) or floor(w * 0.6 + 0.5)
		local cfont = Stuf:GetMedia("font", db.counttfont)
		local cfontflags = db.counttfontflags ~= "None" and db.counttfontflags
		local cc = db.counttfontcolor or Stuf.whitecolor
		local sc = dbg.shadowcolor
		local d1, d2, d3, d4, hdir, vdir = GrowthBreakdown(db.growth)
		local hfirst = (d1 == "LEFT" or d1 == "RIGHT")
		local spacing, vspacing = db.spacing or 0, db.vspacing or 0
		local cols, rows = db.cols or (hfirst and 2) or 1, db.rows or (hfirst and 1) or 2
		f.hdir, f.vdir = hdir, vdir
		
		f.filter = db.curable and "RAID"
		f:SetPoint("TOPLEFT", uf, "TOPLEFT", x, y)
		if db.framelevel then
			f:SetFrameLevel(db.framelevel)
		end
		if istemp then
			if TemporaryEnchantFrame then TemporaryEnchantFrame:Hide() end
		elseif isplayer and isbuff then
			-- Still hide Blizzard's default buff frame since we're drawing our own.
			-- f.secure is disabled in 12.0.1 (see comment above).
			BuffFrame:Hide()
			BuffFrame:UnregisterEvent("UNIT_AURA")
		end
		f:Show()

		local offset1, offset2, uselbf
		if dbg.aurastyle == 2 then
			offset1 = w * 0.05 + 0.5
			offset1 = (offset1 > 3 and 3) or (offset1 < 1 and 1) or floor(offset1)
			offset2 = offset1
			backdrop.bgFile = "Interface\\AddOns\\Stuf\\media\\aura2.tga"
		elseif dbg.aurastyle == 3 and lbf then
			uselbf = true
			offset1, offset2 = 0, 0
			backdrop.bgFile = ""
			if not Stuf.lbfgroup then
				Stuf.lbfgroup = lbf:Group("Stuf")
				lbf:RegisterSkinCallback("Stuf", function(_, SkinID, Gloss, Backdrop, Group, Button, Colors)
					dbg.lbfskin, dbg.lbfgloss, dbg.lbfbackdrop = SkinID, Gloss, Backdrop
				end)
			end
			Stuf.lbfgroup:Skin(dbg.lbfskin, dbg.lbfgloss or true, dbg.lbfbackdrop or true)
		else
			offset1 = (w < 6 and 1) or floor(w * 0.1 + 0.5)
			offset2 = floor(w * 0.05)
			backdrop.bgFile = "Interface\\AddOns\\Stuf\\media\\aura1.tga"
		end

		wipe(f.firstcol)
		wipe(f.firstrow)
		
		local tfc, tfont, tfontsize, tfontflags
		if not uf.ismetro and db.timefontcolor and db.timefontcolor.a > 0.1 then
			tfc = db.timefontcolor
			tfont = Stuf:GetMedia("font", db.timefont)
			tfontsize = db.timefontsize or cfontsize
			tfontflags = db.timefontflags ~= "None" and db.timefontflags
		end
		for i = 1, db.count or 2, 1 do
			local icon = f[i]
			if not icon then
				icon = CreateFrame("Button", lbf and format("Stuf.units.%s.%s.a%d", unit, name, i) or nil, f, BackdropTemplateMixin and 'BackdropTemplate')
				icon:Hide()
				icon.overlay = CreateFrame("Frame", nil, icon, BackdropTemplateMixin and 'BackdropTemplate')
				icon.overlay:SetFrameLevel(4)
				icon.texture = icon.overlay:CreateTexture(nil, "BORDER")
				icon.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
				icon.ctext = icon.overlay:CreateFontString(nil, "ARTWORK")
			
				icon.id = i
				icon:SetScript("OnEnter", (isdebuff and DebuffOnEnter) or (istemp and TempOnEnter) or BuffOnEnter)
				icon:SetScript("OnLeave", Stuf.GameTooltipOnLeave)
				icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				if not isdebuff and not istemp then
					icon:SetScript("OnClick", BuffOnClick)
				end

				f[i] = icon
			end
			if db.showpie then
				icon.pie = icon.pie or CreateFrame("Cooldown", nil, icon, "StufAuraCooldown")
				icon.pie:SetReverse(true)
				icon.pie.noCooldownCount = db.hidecc
				icon.showpie = (db.pieonlymine and 1) or true
			elseif icon.pie then
				icon.pie:Hide()
				icon.showpie = nil
			end
			icon:SetWidth(w)
			icon:SetHeight(h)
			icon:EnableMouse(not db.nomouse)
			icon.SetAlpha = Stuf.SetAlpha
			icon:SetAlpha(1)
			icon:SetBackdrop(backdrop)
			if uselbf then
				icon.Icon = icon.texture
				icon.Cooldown = icon.pie
				icon.Border = icon.Border or icon:CreateTexture(icon:GetName().."Border", "OVERLAY")
				Stuf.lbfgroup:AddButton(icon, icon)
				Stuf.lbfsetcolor = Stuf.lbfsetcolor or function(icon, r, g, b, a)
					icon.Border:SetVertexColor(r, g, b, a)
				end
				icon.SetBackdropColor = Stuf.lbfsetcolor
			else
				if icon.Icon then
					icon.SetBackdropColor = Stuf.SetBackdropColor
				end
				icon.texture:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -offset1, -offset1)
				icon.texture:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", offset2, offset2)
			end
			if istemp then
				icon:SetBackdropColor(0.5, 0, 1)
			end
			
			icon.ctext:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", db.counttx or (-offset2 + 1), db.countty or offset2)
			Stuf:UpdateTextLook( icon.ctext, nil, cfont, cfontsize, cfontflags,
			                     db.counttjustifyH or "RIGHT", db.counttjustifyV or "BOTTOM", cc, db.counttshadowx or -1, db.counttshadowy or 1 )
			if tfc then
				local ttext = icon.ttext
				if not ttext then
					ttext = icon.overlay:CreateFontString(nil, "ARTWORK")
					icon.ttext = ttext
				end
				icon.ttextonlymine = db.timeonlymine
				icon.talpha = db.alpha or 1
				ttext:SetWidth(db.timew or (w + 4))
				ttext:SetHeight(db.timeh or cfontsize)
				ttext:SetPoint("TOPLEFT", icon, "TOPLEFT", db.timex or -2, db.timey or -(h - cfontsize))
				Stuf:UpdateTextLook( ttext, nil, tfont, tfontsize, tfontflags,
				                     db.timejustifyH, db.timejustifyV, tfc, db.timeshadowx, db.timeshadowy )
				ttext:Show()
			elseif icon.ttext then
				icon.ttextonlymine = nil
				icon.ttext:Hide()
			end
			
			icon:ClearAllPoints()
			icon.xoff, icon.yoff = nil, nil
			if hfirst then  -- LRTB, LRBT, RLTB, RLBT
				local crow = ceil(i / cols)
				if crow > rows then break end
				local ccol = i % cols
				ccol = (ccol == 0 and cols) or ccol
				if i == 1 then  -- first row, first col
					icon:SetPoint(d3..d1, f, d3..d1)
					icon.xoff = (w + 4 + spacing) * hdir
					icon.yoff = (h + 2 + vspacing) * vdir
					tinsert(f.firstrow, icon)
					tinsert(f.firstcol, icon)
				elseif ccol == 1 then  -- start of a new row (first column)
					icon:SetPoint(d3, f[i - cols], d4, 0, vspacing * vdir)
					icon.yoff = ((h * crow) + (vspacing * crow) + 2) * vdir
					tinsert(f.firstcol, icon)
				else
					icon:SetPoint(d1, f[i - 1], d2, spacing * hdir, 0)
					if crow == 1 then
						icon.xoff = ((w * ccol) + (spacing * ccol) + 4) * hdir
						tinsert(f.firstrow, icon)
					end
				end
			else  -- TBLR, TBRL, BTLR, BTRL
				local ccol = ceil(i / rows)
				if ccol > cols then break end
				local crow = i % rows
				crow = (crow == 0 and rows) or crow
				if i == 1 then  -- first row, first col
					icon:SetPoint(d1..d3, f, d1..d3)
					icon.xoff = (w + 4 + spacing) * hdir 
					icon.yoff = (h + 2 + vspacing) * vdir
					tinsert(f.firstrow, icon)
					tinsert(f.firstcol, icon)
				elseif crow == 1 then  -- start of a new column (first row)
					icon:SetPoint(d3, f[i - rows], d4, spacing * hdir, 0)
					icon.xoff = ((w * ccol) + (spacing * ccol) + 4) * hdir
					tinsert(f.firstrow, icon)
				else
					icon:SetPoint(d1, f[i - 1], d2, 0, vspacing * vdir)
					if ccol == 1 then
						icon.yoff = ((h * crow) + (vspacing * crow) + 2) * vdir
						tinsert(f.firstcol, icon)
					end
				end
			end
		end  -- for
		for i = db.count + 1, 80, 1 do  -- hide icons in case db.count is less than before
			if not f[i] then break end
			f[i]:EnableMouse(false)
			f[i]:SetAlpha(0)
			f[i].SetAlpha = Stuf.nofunc
		end
		if Stuf.inworld then
			UpdateAura(unit, uf, nil, nil, nil, config)
		end
	end
	Stuf:AddBuilder("buffgroup", CreateAuraGroup)
	Stuf:AddBuilder("debuffgroup", CreateAuraGroup)
	Stuf:AddBuilder("tempenchant", CreateAuraGroup)
	Stuf:AddEvent("UNIT_AURA", UpdateAura)
	
	Stuf:AddBuilder("auratimers", function(unit, uf, name, db, _, config)
		local f = uf[name]
		if db.hide then
			if f then
				f.hidden = true
				f:Hide()
			end
			return
		end
		if not f then
			f = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
			f:SetWidth(2)
			f:SetHeight(2)
			f.unit = unit
			f.db = db
			f.timers = { }
			uf[name] = f
			uf.refreshfuncs["auras"] = UpdateAura
		else
			f.hidden = nil
			f:Show()
		end

		f.d1, f.d2, f.d3, f.d4, f.hdir, f.vdir = GrowthBreakdown(db.growth)
		f:SetPoint("TOPLEFT", uf, "TOPLEFT", db.x, db.y)
		
		f.dbupdate = (f.dbupdate or 0) + 1
		if Stuf.inworld then
			UpdateAura(unit, uf, nil, nil, nil, config)
		end
	end)
end


do  -- Dispell Icon ---------------------------------------------------------------------------------------------------
	local function DispellOnUpdate(this, a1)  -- flash effect
		local dir = this.dir or 0.5
		local alp = (this.alp or 0.5) + a1 * dir
		if (dir == 0.5 and alp > 0.7) or (dir == -0.5 and alp < 0.3) then
			this.dir = dir * -1
		end
		this.alp = alp
		this:SetAlpha(alp)  -- flash between 0.3 and 0.7 alpha
	end
	Stuf:AddBuilder("dispellicon", function(unit, uf, name, db, _, config)
		if not Stuf.supportspell and not iswarlock then return end
		local f = uf[name]
		if db.hide then
			if f then
				f.hidden = true
				f:Hide()
			end
			return
		end
		if not f then
			f = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
			f.texture = f:CreateTexture(nil, "BORDER")
			f.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			f.ctext = f:CreateFontString(nil, "ARTWORK")
			f:SetScript("OnUpdate", DispellOnUpdate)
			
			f.db = db
			f:Hide()
			uf.refreshfuncs["auras"] = UpdateAura
			uf[name] = f
		else
			f.hidden = nil
		end
		f:SetFrameLevel(db.framelevel or 3)
		f:SetWidth(db.w)
		f:SetHeight(db.h)
		f:SetPoint("TOPLEFT", uf, "TOPLEFT", db.x, db.y)
		f:SetAlpha(db.alpha or 1)
		f:SetBackdrop(backdrop)
		
		local offset1, offset2 = 0, floor(db.h * 0.05 + 0.5)
		if dbg.aurastyle == 2 then
			backdrop.bgFile = "Interface\\AddOns\\Stuf\\media\\aura2.tga"
			offset1 = offset2
		else
			backdrop.bgFile = "Interface\\AddOns\\Stuf\\media\\aura1.tga"
			offset1 = floor(db.h * 0.1 + 0.5)
		end
		f:SetBackdrop(backdrop)
		f.texture:SetPoint("TOPRIGHT", f, "TOPRIGHT", -offset1, -offset1)
		f.texture:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", offset2, offset2)
		f.ctext:SetPoint("TOPLEFT", f, "TOPLEFT", db.counttx or 0, db.countty or 0)
		f.ctext:SetWidth(db.counttw or db.w)
		f.ctext:SetHeight(db.countth or db.h)

		Stuf:UpdateTextLook( f.ctext, db.counttfont, nil, db.counttfontsize or (db.h * 0.5), db.counttfontflags,
		                     db.counttjustifyH or "RIGHT", db.counttjustifyV or "BOTTOM", 
							 db.counttfontcolor or Stuf.whitecolor, db.counttshadowx or -1, db.counttshadowy or 1 )
		if Stuf.inworld then
			UpdateAura(unit, uf, nil, nil, nil, config)
		end
	end)
end
