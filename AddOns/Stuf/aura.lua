if not Stuf then return end

local Stuf = Stuf
local su = Stuf.units
local dbg, dbgaura, notmage, iswarlock
Stuf:AddOnInit(function(_, idbg, CLS) 
	dbg = idbg
	dbgaura = dbg.auracolor
	notmage, iswarlock = CLS ~= "MAGE", CLS == "WARLOCK"
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
	local function lsort(a, b)
		return a.endtime < b.endtime
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
		
		local remain = this.endtime - GetTime()
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
		f.duration = 1 / duration
		f.throt = (duration < 300 and 0.1) or (duration < 600 and 0.25) or 0.5
		f.nextupdate = 0
		f.ctext:SetFormattedText("%s%s", (count and count > 0 and (count.." ")) or "", p.db.showspellname and spellname or "")
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
	
	local remain = this.endtime - GetTime()
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
	if this.ttext then
		if (mine or not this.ttextonlymine) and endtime and endtime > 0 then
			this.endtime = endtime
			this.nextupdate = 0
			this:SetScript("OnUpdate", AuraTimeTextOnUpdate)
		else
			this.ttext:SetText("")
			this:SetScript("OnUpdate", nil)
		end
	end
	if this.showpie then
		if (mine or this.showpie ~= 1) and endtime and endtime > 0 then
			this.pie:SetCooldown(endtime - duration, duration)
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
	-- local UnitBuff, UnitDebuff, UnitIsUnit = UnitBuff, UnitDebuff, UnitIsUnit
	function UpdateAura(unit, uf, _, _, _, config)  -- updates all elements dealing with buffs/debuffs
		-----------------------------------------------
		-- edited on 3MAY2022 uf = uf or su[unit]
		if unit then uf = su[unit] end --fix 100002--I noticed that Unit_Aura event throw wrong uf table
		uf = type(uf) == "table" and uf or su[unit]
		-----------------------------------------------
		if not uf or uf.hidden then return end
		
		local allow, clr, bfilter, dfilter, onlymineb, onlymined = true, nil, nil, nil, nil, nil
		local name, icon, count, atype, duration, endtime, ismine, isstealable, aura
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
					local dc = dbgaura.Curse
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
					local clr = dbgaura[debuffconfig[(i % 5) + 1] or "none"]
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
							-- name, icon, count, atype = UnitDebuff(unit, i)
							aura = C_UnitAuras.GetDebuffDataByIndex(unit, i)
							if aura then
								name = aura.name
								icon = aura.icon
								count = aura.applications
								atype = aura.dispelName
							else
								name = nil
								atype = nil
							end
							if not name or atype == "Magic" then
								break
							else
								name = nil
							end
						end
					end
				else
					-- name, icon, count, atype = UnitDebuff(unit, 1, "RAID")
					aura = C_UnitAuras.GetDebuffDataByIndex(unit, 1, "RAID")
					if aura then
						name = aura.name
						icon = aura.icon
						count = aura.applications
						atype = aura.dispelName
					else
						name = nil
					end
				end
				if name then
					local dc = dbgaura[atype or "none"] or dbgaura.none
					dispellicon.texture:SetTexture(icon)
					dispellicon.ctext:SetText((count and count > 1 and count) or "")
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
				-- name, icon, count, atype, duration, endtime, ismine, isstealable = UnitBuff(unit, i, bfilter)
				aura = C_UnitAuras.GetBuffDataByIndex(unit, i, bfilter)
				if aura then
					name = aura.name
					icon = aura.icon
					count = aura.applications
					atype = aura.dispelName
					duration = aura.duration
					endtime = aura.expirationTime
					ismine = aura.sourceUnit
					isstealable = aura.isStealable
				else
					name = nil
					ismine = nil
				end
				ismine = ismine == "player" or ismine == "vehicle" or (showpet and ismine == "pet")
				allow = name and (not onlymineb or ismine)
			end
			
			local b = buffgroup and buffgroup[i]
			if b then
				if allow then
					b.texture:SetTexture(icon)
					b.ctext:SetText((count and count > 1 and count) or "")
					if cache.attackable and (isstealable or (atype == "Magic" and notmage)) then
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
			if auratimers and ismine and endtime and endtime > 0 then
				StartTimer("b"..i, duration, endtime, icon, dbgaura.MyBuff, count, auratimers, name)
				temp["b"..i] = nil
			end
		end
		
		allow = true
		for i = 1, 40, 1 do  -- update debuffgroup
			if allow then  -- prevents calling UnitDebuff when it's useless
				-- name, icon, count, atype, duration, endtime, ismine, isstealable = UnitDebuff(unit, i, dfilter)
				aura = C_UnitAuras.GetDebuffDataByIndex(unit, i, dfilter)
				if aura then
					name = aura.name
					icon = aura.icon
					count = aura.applications
					atype = aura.dispelName
					duration = aura.duration
					endtime = aura.expirationTime
					ismine = aura.sourceUnit
					isstealable = aura.isStealable
				else
					name = nil
					ismine = nil
					atype = nil
				end
				ismine = ismine == "player" or ismine == "boss1" or ismine == "boss2" or ismine == "boss3" or ismine == "boss4" or ismine == "vehicle" or (showpet and ismine == "pet") -- 自行修改，加上 BOSS 的
				clr = dbgaura[atype or "none"] or dbgaura.none
				allow = name and (not onlymined or ismine)
			end
			
			local b = debuffgroup and debuffgroup[i]
			if b then
				if allow then
					b:SetBackdropColor(clr.r, clr.g, clr.b)
					b.texture:SetTexture(icon)
					b.ctext:SetText((count and count > 1 and count) or "")
					b:Show()
					StartIconTimer(b, duration, endtime, ismine)
				else
					b:Hide()
				end
			elseif not allow then
				break
			end
			if auratimers and ismine and endtime and endtime > 0 then
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
					if istemp and TemporaryEnchantFrame then -- 10.0.2 fix
						TemporaryEnchantFrame:Show()
					elseif isbuff then
						BuffFrame:Show()
						BuffFrame:RegisterEvent("UNIT_AURA")
					elseif isdebuff then
						DebuffFrame:Show()
						DebuffFrame:RegisterEvent("UNIT_AURA")
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
			elseif isplayer and isbuff then
				f.secure = CreateFrame("Frame", nil, f, "SecureAuraHeaderTemplate,BackdropTemplate")
				f.secure:SetSize(2, 2)
				f.secure:SetAttribute("unit", "player")
				f.secure:SetAttribute("filter", "HELPFUL")
				f.secure:SetAttribute("separateOwn", "1")
				f.secure:SetAttribute("template", "StufBuffTemplate")
				f.secure:SetAttribute("minWidth", 1)
				f.secure:SetAttribute("minHeight", 1)
				f.secure:SetAttribute("sortMethod", "INDEX")
				f.secure:SetAttribute("sortDir", "+")
				f.disablepush = true
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
		if istemp and TemporaryEnchantFrame then -- 10.0.2 fix
			TemporaryEnchantFrame:Hide()
		elseif isplayer and isbuff then
			BuffFrame:Hide()
			BuffFrame:UnregisterEvent("UNIT_AURA")
			f.secure:ClearAllPoints()
			if hfirst then
				f.secure:SetAttribute("point", d3..d1)
				f.secure:SetAttribute("xOffset", (spacing + w) * hdir)
				f.secure:SetAttribute("yOffset", 0)
				f.secure:SetAttribute("wrapAfter", cols)
				f.secure:SetAttribute("wrapXOffset", 0)
				f.secure:SetAttribute("wrapYOffset", (vspacing + h) * vdir)
				f.secure:SetAttribute("maxWraps", rows)
				f.secure:SetPoint(d3..d1, f, "TOPLEFT")
			else
				f.secure:SetAttribute("point", d1..d3)
				f.secure:SetAttribute("xOffset", 0)
				f.secure:SetAttribute("yOffset", (vspacing + h) * vdir)
				f.secure:SetAttribute("wrapAfter", rows)
				f.secure:SetAttribute("wrapXOffset", (spacing + w) * hdir)
				f.secure:SetAttribute("wrapYOffset", 0)
				f.secure:SetAttribute("maxWraps", cols)
				f.secure:SetPoint(d1..d3, f, "TOPLEFT")
			end
			f.secure:SetFrameLevel(f:GetFrameLevel() + 20)
			f.secure:Show()
		elseif isplayer and isdebuff then
			DebuffFrame:Hide()
			DebuffFrame:UnregisterEvent("UNIT_AURA")
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
		if alp > 0.7 then  -- 自行修正
			alp = 0.7
		elseif alp < 0.3 then
			alp = 0.3
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
