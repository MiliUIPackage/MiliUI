if not Stuf then return end

local Stuf = Stuf
local su = Stuf.units
local dbg
Stuf:AddOnInit(function(_, idbg) dbg = idbg end)
local CreateFrame = CreateFrame

do
	local SetPortraitTexture, UnitIsVisible = SetPortraitTexture, UnitIsVisible
	local function UpdatePortrait(unit, uf, f, reset)
		uf = uf or su[unit]
		f = f or (uf and not uf.hidden and uf.portrait)
		if not f or f.db.hide then return end
		local d2, d3 = f.d2, f.d3
		
		if d3 and f.db.show3d and UnitIsVisible(unit) then
			if not reset and uf.ismetro then  -- reduce jittering for metro units
				uf.skipport = (uf.skipport or 0) + 1
				if uf.skipport < 3 then return end
				uf.skipport = 0
			end
			d2:Hide()
			d3:Show()
			d3:SetUnit(unit)
			d3:SetPortraitZoom(f.db.camera or 1)
			d3:SetAlpha(0.8)
			d3:SetAlpha(uf.cache.dead and 0.5 or 1)
			if f.portraitrefreshing then
				Stuf:RegisterElementRefresh(uf, "portrait", "metroelements", nil)
				f.portraitrefreshing = nil
			end
		else  -- show or update 2d portrait instead
			if d3 then
				d3:ClearModel()
				d3:SetAlpha(0.01)
				d3:SetAlpha(0)
				f.alpha = 0
			end
			d2:SetTexture()
			SetPortraitTexture(d2, unit)
			d2:Show()
			d2:SetAlpha(1)
			if not d2:GetTexture() then
				if not f.portraitrefreshing then
					Stuf:RegisterElementRefresh(uf, "portrait", "metroelements", true)
					f.portraitrefreshing = true
				end
			elseif f.portraitrefreshing then
				Stuf:RegisterElementRefresh(uf, "portrait", "metroelements", nil)
				f.portraitrefreshing = nil
			end
		end
	end
	local function PortraitOnShow(this)
		this:SetPortraitZoom(this.db.camera or 1) 
		this:SetModelScale(2)
		UpdatePortrait(this.unit, this.uf, this.f)
	end
	Stuf:AddBuilder("portrait", function(unit, uf, name, db, _, config)
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db)
			f.d2 = f:CreateTexture(nil, "BORDER")
			f.d2:SetAllPoints(f)
			uf.refreshfuncs[name] = UpdatePortrait
			Stuf:RegisterElementRefresh(uf, name, "deathelements", true)
			Stuf:RegisterElementRefresh(uf, name, "reactionelements", true)
			
		end
		Stuf:UpdateBaseLook(uf, f, db, db.framelevel)
		f:Show()
		if db.show3d then  -- create or setup 3D model
			if not f.d3 then
				local d3 = CreateFrame("PlayerModel", nil, f)
				d3:SetAllPoints(f)
				d3:SetScript("OnShow", PortraitOnShow)
				d3:SetModelScale(2)
				d3.unit, d3.uf, d3.f = unit, uf, f
				d3.db = db
				f.d3 = d3
			else
				f.d3:Show()
			end
		elseif f.d3 then
			f.d3:Hide()
		end
		local low, high = db.zoom2d and 0.15 or 0, db.zoom2d and 0.85 or 1
		if db.w > db.h then
			local offset = 0.5 * (high - low) * db.h / db.w
			f.d2:SetTexCoord(low, high, 0.5 - offset, 0.5 + offset)
		elseif db.w < db.h then
			local offset = 0.5 * (high - low) * db.w / db.h
			f.d2:SetTexCoord(0.5 - offset, 0.5 + offset, low, high)
		else
			f.d2:SetTexCoord(low, high, low, high)
		end
		if Stuf.inworld then
			UpdatePortrait(config and "player" or unit, uf)
		end
	end)
end


do  -- Voice Icons ----------------------------------------------------------------------------------------------------
	local speakers
	Stuf:AddBuilder("voiceicon", function(unit, uf, name, db, _, config)
		local f = uf[name]
		speakers = speakers or {  -- use blizz's default speaker frames for voice
			player = PlayerSpeakerFrame,
			party1 = PartyMemberFrame1SpeakerFrame,
			party2 = PartyMemberFrame2SpeakerFrame,
			party3 = PartyMemberFrame3SpeakerFrame,
			party4 = PartyMemberFrame4SpeakerFrame,
		}
		if db.hide or not speakers[unit] then
			if f then f:Hide() end
			return
		end
		if not f then
			f = speakers[unit]  -- voice speaker icon
			local p = (unit == "player" and f:GetParent():GetParent()) or f:GetParent()
			p:RegisterEvent("VOICE_START")
			p:RegisterEvent("VOICE_STOP")
			if unit ~= "player" then
				p:RegisterEvent("MUTELIST_UPDATE")
				p:RegisterEvent("IGNORELIST_UPDATE")
				p:RegisterEvent("VOICE_STATUS_UPDATE")
			end
			f.ep = p
			f:SetParent(uf.border)
			f:Hide()
			f.db = db
			uf[name] = f
		end
		f:SetWidth(db.w)
		f:SetHeight(db.h)
		f:SetPoint("TOPLEFT", uf, "TOPLEFT", db.x, db.y)
		f:SetAlpha(db.alpha or 1)
		f:SetFrameLevel(db.framelevel or 4)
		if config then
			(unit == "player" and PlayerFrame_OnEvent or PartyMemberFrame_OnEvent)(f.ep, "VOICE_START", uf.unit)
			f.config = true
		elseif f.config then
			(unit == "player" and PlayerFrame_OnEvent or PartyMemberFrame_OnEvent)(f.ep, "VOICE_STOP", uf.unit)
			f.config = nil
		end
	end)
end


do  -- General Icons --------------------------------------------------------------------------------------------------
	local checkready, tar
	local IsResting, GetReadyCheckStatus, UnitIsConnected = IsResting, GetReadyCheckStatus, UnitIsConnected
	local UnitGroupRolesAssigned = UnitGroupRolesAssigned
	local function SetIconCoord(f, sta, texture, l, r, t, b)
		if f.pstat == sta then return end
		f:SetTexture(texture)
		f:SetTexCoord(l, r, t, b)
		f:Show()
		f.pstat = sta
	end
	local function UpdateStatusIcon(unit, uf, f, _, _, config)
		uf = (type(uf) == "table" and uf) or su[unit]
		f = f or (uf and not uf.hidden and uf.statusicon)
		if not f or f.db.hide then return end
		if config then
			f.pstat = nil
			return SetIconCoord(f, 3, "Interface\\CharacterFrame\\UI-StateIcon", .5625, .9, .08, .4375)
		end
		if checkready and GetReadyCheckStatus(unit) then  -- ready check
			local status = GetReadyCheckStatus(unit)
			if status == "ready" then
				SetIconCoord(f, 5, "Interface\\RaidFrame\\ReadyCheck-Ready", 0, 1, 0, 1)
			elseif status == "notready" then
				SetIconCoord(f, 6, "Interface\\RaidFrame\\ReadyCheck-NotReady", 0, 1, 0, 1)
			else -- "waiting"
				SetIconCoord(f, 7, "Interface\\RaidFrame\\ReadyCheck-Waiting", 0, 1, 0, 1)
			end
		elseif uf.cache.dead then  -- if unit is dead, set status icon to skull, add "DEAD" text, and adjust portrait effects
			SetIconCoord(f, 1, "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", 0, 1, 0, 1)
		elseif not UnitIsConnected(unit) then  -- offline
			SetIconCoord(f, 2, "Interface\\CharacterFrame\\Disconnect-Icon", 0, 1, 0, 1)
		elseif uf.cache.incombat then  -- in combat
			SetIconCoord(f, 3, "Interface\\CharacterFrame\\UI-StateIcon", 0.5625, 0.9, 0.08, 0.4375)
		elseif unit == "player" and IsResting() then  -- player resting
			SetIconCoord(f, 4, "Interface\\CharacterFrame\\UI-StateIcon", 0.0625, 0.4375, 0.0625, 0.4375)
		elseif f.pstat then  -- none
			f:Hide()
			f.pstat = nil
		end
	end
	local function UpdateReadyCheck()
		checkready = true
		for u, uf in pairs(su) do
			if uf.statusicon then
				UpdateStatusIcon(u, uf, uf.statusicon)
			end
		end
	end
	local function ClearReadyCheck()
		checkready = nil
		for u, uf in pairs(su) do
			if uf.statusicon then
				UpdateStatusIcon(u, uf, uf.statusicon)
			end
		end
	end
	local function UpdateResting()
		UpdateStatusIcon("player", su.player)
	end
	
	local select, GetLootMethod, GetRaidRosterInfo = select, GetLootMethod, GetRaidRosterInfo
	local UnitIsGroupLeader, UnitIsUnit = UnitIsGroupLeader, UnitIsUnit
	local function updateuniticon(uf, icon, show)
		local f = uf and not uf.hidden and uf[icon]
		if f and not f.db.hide then
			f[show](f)
		end
	end
	local function UpdatePartyIcons(unit, uf, _, _, _, config)
		if config then
			if uf then
				updateuniticon(uf, "looticon", "Show")
				updateuniticon(uf, "leadericon", "Show")
			end
			return
		end
		if not Stuf.ingroup then  -- do less work if not in group
			updateuniticon(su.player, "looticon", "Hide")
			updateuniticon(su.player, "leadericon", "Hide")
			updateuniticon(tar, "looticon", "Hide")
			updateuniticon(tar, "leadericon", UnitIsGroupLeader("target") and "Show" or "Hide")
			return
		end
		partyiconhidden = nil
		-- find out which unit is master looter if any
		local method, looter = GetLootMethod()
		if method == "master" then
			if looter then
				looter = (looter == 0 and "player") or "party"..looter
			elseif tar and tar.cache.ingroup then
				for i = 1, Stuf.numraid, 1 do
					if select(11, GetRaidRosterInfo(i)) then
						looter = "raid"..i
						break
					end
				end
			end
		end
		for u, uf in pairs(su) do  -- now update each applicable frame
			if uf.looticon or uf.leadericon then
				updateuniticon(uf, "looticon", looter and UnitIsUnit(looter, u) and "Show" or "Hide")
				updateuniticon(uf, "leadericon", UnitIsGroupLeader(u) and "Show" or "Hide")
			end
		end
	end
	
	local GetRaidTargetIndex, SetRaidTargetIconTexture = GetRaidTargetIndex, SetRaidTargetIconTexture
	local function UpdateRaidTargetIcons(unit, uf, _, _, _, config)  -- raid target icon
		if config then
			local icon = uf and not uf.hidden and uf.raidtargeticon
			if icon and not icon.db.hide then
				SetRaidTargetIconTexture(icon, math.random(1, 8))
				icon:Show()
			end
			return
		end
		if unit then
			uf = uf or su[unit]
			if uf.db.hide then return end
			local icon = uf.raidtargeticon
			if icon and not icon.db.hide then
				local iconindex = GetRaidTargetIndex(unit)
				if iconindex then
					SetRaidTargetIconTexture(icon, iconindex)
					icon:Show()
				else
					icon:Hide()
				end
			end
		else
			for unit, uf in pairs(su) do
				local icon = uf.raidtargeticon
				if icon and not icon.db.hide then
					local iconindex = GetRaidTargetIndex(unit)
					if iconindex then
						SetRaidTargetIconTexture(icon, iconindex)
						icon:Show()
					else
						icon:Hide()
					end
				end
			end
		end
	end
	
	local CLASS_BUTTONS = CLASS_ICON_TCOORDS or CLASS_BUTTONS
	local function UpdateInfoIcon(unit, uf, f)  -- Class/info icon
		uf = uf or su[unit]
		f = f or (uf and not uf.hidden and uf.infoicon)
		if f and not f.db.hide then
			if f.db.circular then
				local c = CLASS_ICON_TCOORDS[uf.cache.CLASS or "WARRIOR"] or CLASS_ICON_TCOORDS["WARRIOR"]
				if f.db.flip then
					f:SetTexCoord(c[2], c[1], c[3], c[4])
				else
					f:SetTexCoord(c[1], c[2], c[3], c[4])
				end
			else
				local c = CLASS_BUTTONS[uf.cache.CLASS or "WARRIOR"] or CLASS_BUTTONS["WARRIOR"]
				if f.db.flip then
					f:SetTexCoord(c[2] - 0.015, c[1] + 0.015, c[3] + 0.02, c[4] - 0.02)
				else
					f:SetTexCoord(c[1] + 0.015, c[2] - 0.015, c[3] + 0.02, c[4] - 0.02)
				end
			end
			f:Show()
		end
	end
	
	local function SetTexture(this, texture)
		this.texture:SetTexture(texture)
	end
	local function SetTexCoord(this, ...)
		this.texture:SetTexCoord(...)
	end
	local function CreateBasicIcon(unit, uf, name, db, _, config)
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = CreateFrame("Frame", nil, uf)
			f.texture = f:CreateTexture(nil, "ARTWORK")
			f.texture:SetAllPoints()
			f.SetTexture = SetTexture
			f.SetTexCoord = SetTexCoord
			f.db = db
			f:Hide()
			uf[name] = f
		end
		tar = su.target
		if name == "statusicon" then
			uf.refreshfuncs[name] = UpdateStatusIcon
			Stuf:RegisterElementRefresh(uf, name, "deathelements", true)
			Stuf:RegisterElementRefresh(uf, name, "reactionelements", true)
			
			Stuf:AddEvent("READY_CHECK", UpdateReadyCheck)
			Stuf:AddEvent("READY_CHECK_CONFIRM", UpdateReadyCheck)
			Stuf:AddEvent("READY_CHECK_FINISHED", ClearReadyCheck)
			if unit == "player" then
				Stuf:AddEvent("PLAYER_UPDATE_RESTING", UpdateResting)
			end
		elseif name == "leadericon" then
			uf.refreshfuncs[name] = UpdatePartyIcons
			f:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
			Stuf:AddEvent("PARTY_LEADER_CHANGED", UpdatePartyIcons)
		elseif name == "looticon" then
			uf.refreshfuncs[name] = UpdatePartyIcons
			f:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
			Stuf:AddEvent("PARTY_LOOT_METHOD_CHANGED", UpdatePartyIcons)
		elseif name == "raidtargeticon" then
			uf.refreshfuncs[name] = UpdateRaidTargetIcons
			f:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
			Stuf:AddEvent("RAID_TARGET_UPDATE", UpdateRaidTargetIcons)
		elseif name == "infoicon" then
			uf.refreshfuncs[name] = UpdateInfoIcon
			f:SetTexture(db.circular and "Interface\\TargetingFrame\\UI-Classes-Circles" or "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
		elseif name == "vehicleicon" then
			Stuf.UpdateVehicleIcon = Stuf.UpdateVehicleIcon or function(unit, _, _, _, _, config)
				local uf = su[unit]
				local f = (uf and not uf.hidden and uf.vehicleicon)
				if not f or f.db.hide then return end
				if UnitHasVehicleUI(unit) or config then
					f:Show()
				else
					f:Hide()
				end
			end
			uf.refreshfuncs[name] = Stuf.UpdateVehicleIcon
			f:SetTexture("Interface\\GossipFrame\\BinderGossipIcon.blp")
			Stuf:AddEvent("UNIT_ENTERED_VEHICLE", Stuf.UpdateVehicleIcon)
			Stuf:AddEvent("UNIT_EXITED_VEHICLE", Stuf.UpdateVehicleIcon)
		elseif name == "lfgicon" and UnitGroupRolesAssigned then
			Stuf.UpdateRoleIcon = Stuf.UpdateRoleIcon or function(_, _, _, _, _, config)
				for u, uf in pairs(su) do
					local f = (uf and not uf.hidden and uf.lfgicon)
					if f and not f.db.hide then
						local role
						if Stuf.ingroup then
							role = UnitGroupRolesAssigned(u)
						end
						if not config and (not role or role == "NONE") then
							f:Hide()
						else
							local l, r, t, b = GetTexCoordsForRole(role ~= "NONE" and role or "TANK")
							if not f.db.circular then
								local offset1, offset2 = (r - l) * .2, (b - t) * .2
								f:SetTexCoord(l + offset1, r - offset1, t + offset2, b - (offset2 * 1.2))
							else
								f:SetTexCoord(l, r, t, b)
							end
							f:Show()
						end
					end
				end
			end
			uf.refreshfuncs[name] = Stuf.UpdateRoleIcon
			f:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-ROLES")
			Stuf:AddEvent("PLAYER_ROLES_ASSIGNED", Stuf.UpdateRoleIcon)
		end
		f:SetWidth(db.w or 20)
		f:SetHeight(db.h or 20)
		f:SetPoint("TOPLEFT", uf, "TOPLEFT", db.x or 0, db.y or 0)
		f:SetAlpha(db.alpha or 1)
		f:SetFrameLevel(db.framelevel or 4)
		if Stuf.inworld then
			uf.refreshfuncs[name](unit, uf, f, nil, nil, config)
		end
	end
	
	Stuf:AddBuilder("statusicon", CreateBasicIcon)
	Stuf:AddBuilder("leadericon", CreateBasicIcon)
	Stuf:AddBuilder("looticon", CreateBasicIcon)
	Stuf:AddBuilder("raidtargeticon", CreateBasicIcon)
	Stuf:AddBuilder("infoicon", CreateBasicIcon)
	Stuf:AddBuilder("vehicleicon", CreateBasicIcon)
	Stuf:AddBuilder("lfgicon", CreateBasicIcon)
end


do  -- PVP icon -------------------------------------------------------------------------------------------------------
	local isrunning = false
	local GetPVPTimer, IsPVPTimerRunning = GetPVPTimer, IsPVPTimerRunning
	local function PVPTimerOnUpdate(this, a1)
		this.nextupdate = (this.nextupdate or 0) - a1
		if this.nextupdate > 0 then return end

		local remain = (GetPVPTimer() * 0.001) - 2
		if remain > 60 then
			this.fontstring:SetFormattedText("%dm", 1 + remain * 0.01666)
			this.nextupdate = remain % 60
		elseif remain > 0 then
			this.fontstring:SetFormattedText("%d", remain)
			this.nextupdate = remain - floor(remain)
		else
			this.fontstring:SetText("")
			this:Hide()
		end
	end
	local function UpdatePVPTimer(unit, uf)
		if unit ~= "player" then return end
		uf = uf or su.player
		if not uf or uf.hidden then return end
		if IsPVPTimerRunning() then
			if not isrunning then
				uf.pvpicon.nextupdate = 0
				uf.pvpicon:SetScript("OnUpdate", PVPTimerOnUpdate)
				isrunning = true
			end
		elseif isrunning then
			uf.pvpicon:SetScript("OnUpdate", nil)
			uf.pvpicon.fontstring:SetText("")
			isrunning = false
		end
	end
	local UnitPrestige = UnitPrestige or function() return 0 end
	local function UpdatePVP(unit, uf, f, _, _, config)
		uf = uf or su[unit]
		f = f or (uf and not uf.hidden and uf.pvpicon)
		if not f or f.db.hide then return end
		local icon = f.texture
		local cache = uf.cache
		if config then
			icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..(cache.faction ~= "" and cache.faction or UnitFactionGroup("player") or "Horde"))
			icon:SetVertexColor(1, 1, 1)
			return f:Show()
		end
		local prestige = UnitPrestige(unit)
		if cache.pvpffa then  -- free for all pvp (Arena)
			icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
			icon:SetVertexColor(1, 1, 1)
			icon:SetTexCoord(0, 0.65, 0, 0.65)
			f:Show()			
		elseif cache.pvp then
			if prestige > 0 then
				icon:SetTexture(GetPrestigeInfo(prestige))
				icon:SetVertexColor(1, 1, 1)
				icon:SetTexCoord(0, 1, 0, 1)
				f:Show()
			else
				icon:SetTexCoord(0, 0.65, 0, 0.65)
				if cache.faction ~= "" then  -- faction pvp (Alliance, Horde)
					icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..(cache.faction or "FFA"))
					icon:SetVertexColor(1, 1, 1)
					f:Show()
				else  -- nonfaction pvp
					icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
					icon:SetVertexColor(Stuf:GetColorFromMethod("reaction", uf))
					f:Show()
				end
				if UnitIsMercenary(unit) then
					if cache.faction == "Horde" then
						icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance")
					elseif cache.faction == "Alliance" then
						icon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde")
					end
				end
			end
		else  -- not pvp
			f:Hide()
		end
	end
	Stuf:AddBuilder("pvpicon", function(unit, uf, name, db, _, config)
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = Stuf:CreateBase(unit, uf, name, db)
			f.texture = f:CreateTexture(nil, "ARTWORK")
			f.texture:SetAllPoints(f)

			uf.refreshfuncs[name] = UpdatePVP
			Stuf:RegisterElementRefresh(uf, name, "reactionelements", true)
			if unit == "player" then
				f.fontstring = f:CreateFontString(nil, "ARTWORK")
				f.fontstring:SetPoint("CENTER")
				uf.refreshfuncs["pvptimer"] = UpdatePVPTimer
				Stuf:AddEvent("PLAYER_FLAGS_CHANGED", UpdatePVPTimer)
			end
		end
		Stuf:UpdateBaseLook(uf, f, db, db.framelevel or 4)
		if f.fontstring then
			f.fontstring:SetFont(Stuf:GetMedia("font", db.font), db.fontsize or 10)
		end
		if Stuf.inworld then
			UpdatePVP(unit, uf, f, nil, nil, config)
		end
	end)
end


do  -- Combo Points ---------------------------------------------------------------------------------------------------
	local GetComboPoints = GetComboPoints
	local function UpdateFrameCombo(unit, uf, config)
		if not config and not UnitExists(unit) then return end
		uf = uf or su[unit]
		local f = uf and not uf.hidden and uf.comboframe
		if not f or f.db.hide then return end
		local points = (config and 6) or GetComboPoints(Stuf.vunit, unit)
		if points > 0 then
			if f.individual then
				for i = 1, 6, 1 do
					if i <= points then
						f[i]:Show()
					else
						f[i]:Hide()
					end
				end
			else
				local offsetr = points * 0.167
				local offsetl = offsetr - 0.167
				if f.db.tflip then
					f.texture:SetTexCoord(offsetr, offsetl, 0, 0.5)
					f.glow:SetTexCoord(offsetr, offsetl, 0.5, 1)
				else
					f.texture:SetTexCoord(offsetl, offsetr, 0, 0.5)
					f.glow:SetTexCoord(offsetl, offsetr, 0.5, 1)
				end

				f:Show()
			end
			f:Show()
		else
			f:Hide()
		end
	end
	local function UpdateComboPoints(unit, uf, _, _, _, config)
		--if uf then
		--	UpdateFrameCombo(unit, uf, config)
		--elseif unit == "player" or unit == "vehicle" then
			UpdateFrameCombo("target", nil, config)
			UpdateFrameCombo("focus", nil, config)
		--end
	end
	local function ComboOnUpdate(this, a1)
		local dir = this.dir or 1
		local alp = (this.alp or 0.7) + a1 * dir
		if (dir == 1 and alp > 0.95) or (dir == -1 and alp < 0.45) then
			this.dir = dir * -1
		end
		this.alp = alp

		if this.individual then
			for i = 1, 6, 1 do
				local g = this[i].glow
				if g.a > 0.2 then
					g:SetAlpha(alp)
				end
			end
		elseif this.glow.a > 0.3 then
			this.glow:SetAlpha(alp)
		end
	end
	Stuf:AddBuilder("comboframe", function(unit, uf, name, db, _, config)
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = CreateFrame("Frame", nil, uf)
			f:SetScript("OnUpdate", ComboOnUpdate)
			
			Stuf:AddEvent("UNIT_POWER_FREQUENT", UpdateComboPoints)
			uf.refreshfuncs[name] = UpdateComboPoints
			
			f.db = db
			uf[name] = f
		end
		f:SetFrameLevel(db.framelevel or 5)

		f:SetWidth(db.w)
		f:SetHeight(db.h)
		f:SetAlpha(db.alpha or 1)
		f:SetPoint("TOPLEFT", db.x, db.y)
		
		if db.combostyle == 2 then  -- individual circles
			f.individual = true
			for i = 1, 6, 1 do
				local c = f[i] or CreateFrame("Frame", nil, f)
				c:SetWidth(db["combo"..i.."w"] or 10)
				c:SetHeight(db["combo"..i.."h"] or 10)
				c:SetPoint("TOPLEFT", db["combo"..i.."x"] or ((i-1)*10 + 1), db["combo"..i.."y"] or 0)
				f[i] = c

				if not c.texture then
					c.glow = c:CreateTexture(nil, "ARTWORK")
					c.glow:SetTexture("Interface\\AddOns\\Stuf\\media\\point.tga")
					c.glow:SetTexCoord(0.5, 1, 0, 1)
					c.glow:SetAllPoints()
					
					c.texture = c:CreateTexture(nil, "ARTWORK")
					c.texture:SetTexture("Interface\\AddOns\\Stuf\\media\\point.tga")
					c.texture:SetTexCoord(0, 0.5, 0, 1)
					c.texture:SetAllPoints()
				end
				local cg = db["combo"..i.."glowcolor"] or Stuf.whitecolor
				c.glow:SetVertexColor(cg.r, cg.g, cg.b, cg.a)
				c.glow.a = cg.a

				local cc = db["combo"..i.."color"] or cg
				c.texture:SetVertexColor(cc.r, cc.g, cc.b, cc.a)
			end
			if f.texture then
				f.texture:Hide()
				f.glow:Hide()
			end
		else  -- tally points
			f.individual = nil
			if not f.glow then
				f.glow = f:CreateTexture(nil, "BORDER")
				f.glow:SetTexture("Interface\\AddOns\\Stuf\\media\\combo.tga")
				f.glow:SetAllPoints()
			end
			local cg = db.glowcolor or Stuf.whitecolor
			f.glow:SetVertexColor(cg.r, cg.g, cg.b, cg.a)
			f.glow.a = cg.a
			f.glow:Show()
			
			if not f.texture then
				f.texture = f:CreateTexture(nil, "ARTWORK")
				f.texture:SetTexture("Interface\\AddOns\\Stuf\\media\\combo.tga")
				f.texture:SetAllPoints()
			end
			local cc = db.color or cg
			f.texture:SetVertexColor(cc.r, cc.g, cc.b, cc.a)
			f.texture:Show()
			f:Show()
			if f[1] then
				for i = 1, 6, 1 do
					f[i]:Hide()
				end
			end
		end
		if Stuf.inworld then
			UpdateComboPoints(unit, uf, nil, nil, nil, config)
		end
	end)
end


do  -- Inspect Button -------------------------------------------------------------------------------------------------
	Stuf:AddBuilder("inspectbutton", function(unit, uf, name, db)
		local f = uf[name]
		if db.hide then
			if f then f:Hide() end
			return
		end
		if not f then
			f = CreateFrame("Button", nil, uf)
			f:SetScript("OnMouseUp", function(this, a1)
				if not UnitIsVisible("target") then return end
				if a1 == "LeftButton" then
					InspectUnit("target")
				elseif a1 == "MiddleButton" then
					if SlashCmdList.NOTETARGET then SlashCmdList.NOTETARGET() end
					if SlashCmdList.MOBNOTES_SHORTHAND then SlashCmdList.MOBNOTES_SHORTHAND() end
				elseif a1 == "RightButton" then 
					if not DressUpFrame:IsShown() then 
						ShowUIPanel(DressUpFrame) 
					end
					if IsAddOnLoaded("CloseUp") then
						DressUpFrameCancelButton:Click()
					else
						DressUpModel:SetUnit("target")
						SetPortraitTexture(DressUpFramePortrait, "target")
					end
				end 
			end)
			f:SetScript("OnEnter", function(this)
				GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT")
				GameTooltip:SetText("Inspect", 1, 1, 1)
				GameTooltip:AddLine(" <Left-click> to inspect.\n"..
				            ((SlashCmdList.NOTETARGET or SlashCmdList.MOBNOTES_SHORTHAND) and " <Middle-click> to note target.\n" or "")..
				            " <Right-click> to dressup.", 0, 1, 0)
				GameTooltip:Show()
			end)
			f:SetScript("OnLeave", Stuf.GameTooltipOnLeave)
			f:SetBackdrop({ bgFile="Interface\\AddOns\\Stuf\\media\\inspectup", })
			
			f.db = db
			uf[name] = f
		else
			f:Show()
		end
		f:SetWidth(db.w)
		f:SetHeight(db.h)
		f:SetAlpha(db.alpha or 1)
		f:SetPoint("TOPLEFT", uf, "TOPLEFT", db.x, db.y)
		f:SetFrameLevel(db.framelevel or 4)
	end)
end
