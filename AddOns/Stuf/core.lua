-- Stuf by TotalPackage
-- http://www.wowinterface.com/list.php?skinnerid=27891

local Stuf = CreateFrame("Frame", "Stuf", UIParent, BackdropTemplateMixin and 'BackdropTemplate')

-- LibSharedMedia-3.0 register media files
local smed = LibStub("LibSharedMedia-3.0")
smed:Register("statusbar", "Flat Smooth", "Interface\\AddOns\\Stuf\\media\\flatsmooth.tga")
smed:Register("statusbar", "Curved Bar", "Interface\\AddOns\\Stuf\\media\\curvedbar.tga")
smed:Register("statusbar", "Steel", "Interface\\AddOns\\Stuf\\media\\Steel.tga")
smed:Register("font", "Franklin Gothic Medium", "Interface\\AddOns\\Stuf\\media\\font1.ttf")
smed:Register("border", "Square Outline", "Interface\\AddOns\\Stuf\\media\\squareline.tga")

-- optional localization support
-- for external localization, make a mod titled StufLocale and create table StufLocalization
local rawget = rawget
local L = setmetatable(StufLocalization or { }, {
	__index = function(self, key)
		return rawget(self, key) or key
	end
})

local _G = getfenv(0)
local ipairs, pairs = ipairs, pairs
local strmatch = strmatch
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local UnitClass, UnitName = UnitClass, UnitName
local IsInRaid, GetNumGroupMembers = IsInRaid, GetNumGroupMembers
local UnitExists, UnitCanAttack, UnitInRaid, UnitIsUnit, UnitCanAssist = UnitExists, UnitCanAttack, UnitInRaid, UnitIsUnit, UnitCanAssist
local FOREIGN_SERVER_LABEL = FOREIGN_SERVER_LABEL

Stuf.units = { } -- [unit] = frame
Stuf.unitcopy = {  -- determines which unit copies which
	party1="party1", party2="party1", party3="party1", party4="party1",
	pettarget="pettarget", party1target="pettarget", party2target="pettarget", party3target="pettarget", party4target="pettarget",
	partypet1="partypet1", partypet2="partypet1", partypet3="partypet1", partypet4="partypet1",
	arena1="arena1", arena2="arena1", arena3="arena1", arena4="arena1", arena5="arena1",
	arenapet1="arenapet1", arenapet2="arenapet1", arenapet3="arenapet1", arenapet4="arenapet1", arenapet5="arenapet1",
	arena1target="arena1target", arena2target="arena1target", arena3target="arena1target", arena4target="arena1target", arena5target="arena1target",
}
Stuf.mainunits1 = { player=true, focus=true, party1=true, party4=true, partypet1=true, partypet4=true, arena1=true, arena3=true, arena5=true }
Stuf.mainunits2 = { target=true, pet=true, party2=true, party3=true, partypet2=true, partypet3=true, arena2=true, arena4=true, }
Stuf.inits = { }  -- func,
Stuf.modules = { }  -- func,
Stuf.hidecolor = { r = 0, g = 0, b = 0, a = 0, }
Stuf.whitecolor = { r = 1, g = 1, b = 1, a = 1, }
Stuf.GameTooltipOnLeave = function() GameTooltip:Hide() end
Stuf.nofunc = function() end
Stuf.vunit = "player"
Stuf.numraid = 0


-- fast access local variables
local su, pla, tar, vunit, vf, partyvisible, doaggro = Stuf.units, nil, nil, "player", nil, nil, nil
local db, dbg, config
local powercolor, classcolor, reactioncolor, hpgreen, hpred, gray, aggrocolor
local bgmousecr, bgmousecg, bgmousecb, bgmouseca = 0, 0, 0, 0
local bgcr, bgcg, bgcb, bgca = 0, 0, 0, 0
local events = { } -- [event] = func
local backdrop, borderdrop = { }, { edgeSize = 16, }
local buildorder = { }  -- elementname,
local builders = { }  -- elementname = func(parent),
local mainunits1, mainunits2 = Stuf.mainunits1, Stuf.mainunits2
local su1, su2 = { }, { } -- mainunits framed
local dropdown = {  -- use blizz's default unit dropdown menus
	player = "PlayerFrame", target = "TargetFrame", pet = "PetFrame", focus = "FocusFrame",
	party1 = "PartyMemberFrame1", party2 = "PartyMemberFrame2", party3 = "PartyMemberFrame3", party4 = "PartyMemberFrame4",
}
local metrounits = { }

-- local functions
local function HideFrame(frame) -- 從 Cell 借來的 code
    if not frame then return end
    
    frame:UnregisterAllEvents()
    frame:Hide()
    frame:SetParent(hiddenParent)

    local health = frame.healthBar or frame.healthbar
    if health then
        health:UnregisterAllEvents()
    end

    local power = frame.manabar
    if power then
        power:UnregisterAllEvents()
    end

    local spell = frame.castBar or frame.spellbar
    if spell then
        spell:UnregisterAllEvents()
    end

    local altpowerbar = frame.powerBarAlt
    if altpowerbar then
        altpowerbar:UnregisterAllEvents()
    end

    local buffFrame = frame.BuffFrame
    if buffFrame then
        buffFrame:UnregisterAllEvents()
    end

    local petFrame = frame.PetFrame
    if petFrame then
        petFrame:UnregisterAllEvents()
    end
end

local function HideBlizzardParty() -- 從 Cell 借來的 code
    _G.UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")

    if _G.CompactPartyFrame then
        _G.CompactPartyFrame:UnregisterAllEvents()
    end

    if _G.PartyFrame then
        _G.PartyFrame:UnregisterAllEvents()
        _G.PartyFrame:SetScript('OnShow', nil)
        for frame in _G.PartyFrame.PartyMemberFramePool:EnumerateActive() do
            HideFrame(frame)
        end
        HideFrame(_G.PartyFrame)
    else
        for i = 1, 4 do
            HideFrame(_G["PartyMemberFrame"..i])
            HideFrame(_G["CompactPartyMemberFrame"..i])
        end
        HideFrame(_G.PartyMemberBackground)
    end
end

local function IsInGroup()
	return UnitExists("party1") or Stuf.numraid ~= 0
end
local function GetUnitName(unit)
	local name, server = UnitName(unit)
	if server and server ~= "" then
		return name..FOREIGN_SERVER_LABEL
	else
		return name
	end
end
local function Disable(f)
	if not f then return end
	f:UnregisterAllEvents()
	f:SetScript("OnUpdate", nil)
	f:Hide()
	f:SetAlpha(0)
end
local function DisableDefault(f)
	if not f then return end
	if f == PlayerFrame and PlayerFrameBottomManagedFramesContainer then PlayerFrameBottomManagedFramesContainer:SetParent(UIParent) end -- 暫時修正職業資源條
	f:SetAlpha(0)
	f:EnableMouse(false)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -400, -400)
	local name = f:GetName() or "blah"
	Disable(f)
	Disable(_G[name.."HealthBar"])
	Disable(_G[name.."ManaBar"])
	Disable(_G[name.."SpellBar"])
end
local RefreshUnit, UpdateHealth, UpdatePower, UpdatePowerType, UpdateReaction, GroupUpdate
local UpdateAggro = Stuf.nofunc

-- load
Stuf:SetScript("OnEvent", function(this, event, ...)
	events[event](...)
end)
Stuf:RegisterEvent("ADDON_LOADED")
function events.ADDON_LOADED(a1)
	if a1 ~= "Stuf" then return end
	Stuf:UnregisterEvent("ADDON_LOADED")
	events.ADDON_LOADED = Stuf.nofunc
	Stuf:RegisterEvent("PLAYER_LOGIN")
	events.PLAYER_LOGIN = function()
		if InCombatLockdown() then return print("|cff00ff00Stuf|r: "..L["Cannot load Stuf while in combat."]) end
		
		-- Saved Variables
		if StufDB == "perchar" then
			StufCharDB = type(StufCharDB) == "table" and StufCharDB or { }
			db = StufCharDB
		elseif StufDB and StufDB.temp then
			StufCharDB = StufDB.temp
			db = StufCharDB
			StufDB = "perchar"
			print("|cff00ff00Stuf|r: "..L["Settings copied to this character."])
		else
			StufCharDB = nil
			StufDB = type(StufDB) == "table" and StufDB or { }
			db = StufDB
		end
		if not db.global or db.global.init ~= 9 then
			C_AddOns.LoadAddOn("Stuf_Options")
			if Stuf.LoadDefaults then
				Stuf:LoadDefaults(db)
				db.global.init = 9
			else
				return print("|cff00ff00Stuf|r: "..L["Stuf_Options is required to initialize variables."])
			end
		end

		dbg = db.global
		classcolor, powercolor, reactioncolor = dbg.classcolor, dbg.powercolor, dbg.reactioncolor
		if dbg.initTWW ~= 1 then
			for i = 0, 20, 1 do
				local color = PowerBarColor[i]
				if color and (not powercolor[i] or not powercolor[i].r) then
					powercolor[i]={ r=color.r, g=color.g, b=color.b, }
				end
			end
			for class, color in pairs(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) do
				if not classcolor[class] or not classcolor[class].r then
					classcolor[class]={ r=color.r, g=color.g, b=color.b, }
				end
			end
			dbg.classification.unknown = dbg.classification.unknown or "??"
			dbg.nK, dbg.nM = dbg.nK or "K", dbg.nM or "M"

			if UnitGroupRolesAssigned and not db.player.lfgicon then
				db.player.lfgicon = db.player.lfgicon or { alpha=0.6, w=16, h=16, }
				db.party1.lfgicon = db.party1.lfgicon or { alpha=0.6, w=14, h=14, }
				db.target.lfgicon = db.target.lfgicon or { hide=true, }
			end
			db.player.runebar = db.player.runebar or { x=0, y=0, }
			db.player.holybar = db.player.holybar or { x=0, y=0, }
			db.player.shardbar = db.player.shardbar or { x=0, y=0, }
			db.player.chibar = db.player.chibar or { x=0, y=0, }
			db.player.arcanebar = db.player.arcanebar or { x=0, y=0, }
			db.player.essencesbar = db.player.essencesbar or { x=0, y=0, }
			db.player.priestbar = db.player.priestbar or { x=0, y=0, }
			db.player.combopointbar = db.player.combopointbar or { x=0, y=0, }

			dbg.initTWW = 1
		end

		hpgreen, hpred, gray = dbg.hpgreen, dbg.hpred, dbg.gray

		Stuf.dbg = db.global
		
		Stuf.statusbar = Stuf:GetMedia("statusbar", dbg.bartexture)
		Stuf.font = Stuf:GetMedia("font", dbg.font)
		Stuf.border = Stuf:GetMedia("border", dbg.border)
		
		local cls, CLS = UnitClass("player")
		Stuf.cls, Stuf.CLS = cls, CLS
		
		ClickCastFrames = ClickCastFrames or {}  -- Clique support
		
		if not dbg.nocustomclass and CUSTOM_CLASS_COLORS then  -- Class Colors support
			Stuf.CCC_CB = Stuf.CCC_CB or function()
				for class, color in pairs(CUSTOM_CLASS_COLORS) do
					classcolor[class].r, classcolor[class].g, classcolor[class].b = color.r, color.g, color.b
				end
				Stuf:UpdateElementLook("global")
			end
			CUSTOM_CLASS_COLORS:RegisterCallback(Stuf.CCC_CB)
			Stuf.CCC_CB()
		end
		
		CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}  -- OneButtonConfig support
		CONFIGMODE_CALLBACKS.Stuf = function(action, mode)
			if action == "ON" then
				if not Stuf.GetOptionsTable then
					C_AddOns.LoadAddOn("Stuf_Options")
				end
				if Stuf.GetOptionsTable then
					Stuf:GetOptionsTable().args.configmode.set(nil, true)
					Stuf:GetOptionsTable().args.movable.set(nil, true)
				end
			elseif action == "OFF" then
				if Stuf.GetOptionsTable then
					Stuf:GetOptionsTable().args.configmode.set(nil, nil)
					Stuf:GetOptionsTable().args.movable.set(nil, nil)
				end
			end
		end
		
		-- spell range setup
		if CLS == "PALADIN" then
			Stuf.supportspell = 19750  -- Flash of Light
		elseif CLS == "PRIEST" then
			Stuf.supportspell = 17  -- Power Word Shield
		elseif CLS == "DRUID" then
			Stuf.supportspell = 774  -- Rejuv
		elseif CLS == "SHAMAN" then
			Stuf.supportspell = 8004  -- Healing Surge
		elseif CLS == "MONK" then
			Stuf.supportspell = 115450  -- Detox
		end
		
		for _, func in ipairs(Stuf.inits) do  -- let other sections know variables are loaded
			func(db, dbg, CLS)
		end
		Stuf.inits = nil
		Stuf.AddOnInit = nil
		
		DisableDefault(PlayerFrame)
		DisableDefault(TargetFrame)
		DisableDefault(TargetofTargetFrame)
		DisableDefault(ComboFrame)
		DisableDefault(PetFrame)
		DisableDefault(FocusFrame)
		DisableDefault(TargetofFocusFrame)
				
		if dbg.disableprframes then
			HideBlizzardParty()  -- 隱藏遊戲內建隊伍框架，暫時修正
		end
		
		for i = 1, 4, 1 do
			DisableDefault(_G["PartyMemberFrame"..i])
			DisableDefault(_G["PartyMemberFrame"..i.."PetFrame"])
		end
		if dbg.disableboss and Boss1TargetFrame then
			for i = 1, MAX_BOSS_FRAMES, 1 do
				local bu = "boss"..i
				DisableDefault(_G["Boss"..i.."TargetFrame"])
				Stuf.unitcopy[bu] = "boss1"
				Stuf.unitcopy["boss"..i.."target"] = "boss1target"

				if not db[bu] then
					C_AddOns.LoadAddOn("Stuf_Options")
					if Stuf.LoadDefaults then
						Stuf:LoadDefaults(db, nil, nil, 1)
					end
				end
				dropdown[bu] = "Boss"..i.."TargetFrame"
			end
		end

		SLASH_STUF1 = "/stuf"
		SlashCmdList.STUF = function()
			if not Stuf.OpenOptions then
				C_AddOns.LoadAddOn("Stuf_Options")
			end
			if Stuf.OpenOptions then
				Stuf:OpenOptions(Stuf.panel)
			else
				print("|cff00ff00Stuf|r: "..L["Stuf_Options not found."])
			end
		end
		if not Stuf.OpenOptions then -- AceConfig hack to be LOD friendly
			Stuf.panel = CreateFrame("Frame", nil, nil, BackdropTemplateMixin and 'BackdropTemplate')
			Stuf.panel.name = "Stuf"
			Stuf.panel:SetScript("OnShow", SlashCmdList.STUF)
			local category = Settings.RegisterCanvasLayoutCategory(Stuf.panel, Stuf.panel.name)
			category.ID = "Stuf"
			Settings.RegisterAddOnCategory(category)
		end

		for k, v in pairs(events) do
			Stuf:RegisterEvent(k)
		end
		for unit in pairs(db) do
			if unit ~= "global" and not strmatch(unit, "party") and not strmatch(unit, "arena") and not strmatch(unit, "boss") then
				Stuf:CreateUnitFrame(unit)
			end
		end

		--InterfaceOptionsFrameOkay:HookScript("OnClick", GroupUpdate)
		Stuf:AddEvent("GROUP_ROSTER_UPDATE", Stuf.CreateParty)
		Stuf:CreateParty()
		
		if ArenaEnemyFrames then
			Stuf:CreateArena()
		else
			--hooksecurefunc("Arena_LoadUI", function() if Stuf.CreateArena then Stuf:CreateArena() end end)
		end

		Stuf:DefaultCastBar("player")
		Stuf:DefaultCastBar("pet")
		Stuf.IsLoggedIn = true
		local elapsed, cprocess = 0, 0
		Stuf:SetScript("OnUpdate", function(this, a1)
			elapsed = elapsed + a1
			if elapsed < 0.07 then return end
			elapsed = 0
			-- theoretically spreads processing of stuff that requires OnUpdate-ing (don't do all the work in a single update)
			if cprocess == 0 then  -- update first set of main units' metro elements
				cprocess = 1
				UpdatePower(vunit, vf, nil, nil, nil, true)  -- quick updates of player/vehicle power
				for unit, uf in pairs(su1) do
					if uf:IsShown() then
						for ename, func in pairs(uf.metroelements) do
							func(unit, uf, uf[ename], nil, nil, config)
						end
					end
				end
			elseif cprocess == 1 then  -- update metro units
				cprocess = 2
				for unit, uf in pairs(metrounits) do
					if uf:IsShown() then
						if uf.cache.name ~= GetUnitName(unit) then
							RefreshUnit(config and "player" or unit, uf)
						else
							UpdateReaction(unit, uf)
							for ename, func in pairs(uf.refreshfuncs) do
								if not uf.skiprefreshelement[ename] then
									func(unit, uf, uf[ename], nil, nil, config)
								end
							end
						end
					end
				end
			elseif cprocess == 2 then  -- update second set of main units' metro elements
				cprocess = 3
				UpdatePower(vunit, vf, nil, nil, nil, true)  -- quick updates of player/vehicle power
				for unit, uf in pairs(su2) do
					if uf:IsShown() then
						for ename, func in pairs(uf.metroelements) do
							func(unit, uf, uf[ename], nil, nil, config)
						end
					end
				end
			else  -- update aggro
				cprocess = 0
				UpdateAggro()
			end
		end)
		events.PLAYER_LOGIN = nil
		Stuf:UnregisterEvent("PLAYER_LOGIN")
		Stuf:AddEvent("PLAYER_ENTERING_WORLD", function()
			Stuf.inworld = true
			for unit, uf in pairs(su) do
				RefreshUnit(unit, uf)
			end
		end)
		Stuf:AddEvent("CHAT_MSG_ADDON", function(prefix, message, chan, sender)
			if prefix == "Stufv" and sender ~= UnitName("player") then
				SendAddonMessage("Stufr", (GetAddOnMetadata("Stuf", "Version") or "?.?.???").." "..(GetCVar("gxResolution") or "?"), "WHISPER", sender)
			elseif prefix == "Stufr" and sender ~= UnitName("player") then
				print(format(L["%s is using version %s."], sender, message))
			end
		end)
		function Stuf:RequestVersion(name)
			if not name then return end
			SendAddonMessage("Stufv", "a", "WHISPER", name)
		end
		Stuf:AddEvent("UNIT_NAME_UPDATE", RefreshUnit)
		for _, func in ipairs(Stuf.modules) do  -- run external modules
			func()
		end
		Stuf.modules = nil
	end
	if IsLoggedIn() then
		events.PLAYER_LOGIN()
		events.PLAYER_ENTERING_WORLD()
	end
end

-- events handlers
local emulti = { } -- event = { func1, func2, ..., }
-----------------------------------
function Stuf:AddEvent(event, func)
-----------------------------------
	if not events[event] then
		events[event] = func
		if not Stuf.inits then
			Stuf:RegisterEvent(event)
		end
	elseif events[event] == func then
		return
	elseif not emulti[event] then  -- setup multiple function calls for a single event
		emulti[event] = { events[event], func, }
		local mfee = emulti[event]
		events[event] = function(...)
			for _, f in ipairs(mfee) do
				f(...)
			end
		end
	else
		for index, ifunc in ipairs(emulti[event]) do
			if ifunc == func then return end
		end
		tinsert(emulti[event], func)
	end
end
--------------------------------------
function Stuf:RemoveEvent(event, func)
--------------------------------------
	if not events[event] then return end
	if events[event] == func then
		events[event] = nil
		Stuf:UnregisterEvent(event)
	elseif emulti[event] then
		for index, ifunc in ipairs(emulti[event]) do
			if ifunc == func then
				tremove(emulti[event], index)
				break
			end
		end
		if #emulti[event] == 0 then
			emulti[event], events[event] = nil, nil
			Stuf:UnregisterEvent(event)
		end
	end
end

-------------------------------------------
function Stuf:AddBuilder(elementname, func)  -- functions used to create and setup elements
-------------------------------------------
	if not builders[elementname] then
		tinsert(buildorder, elementname)
	end
	builders[elementname] = func
end

-----------------------------
function Stuf:AddOnInit(func)  -- to process when variables are loaded and ready
-----------------------------
	tinsert(Stuf.inits, func)
end

----------------------------------
function Stuf:SetConfigMode(value)
----------------------------------
	config = value
	if config then
		Stuf:UnregisterAllEvents()
	else
		for k, v in pairs(events) do
			Stuf:RegisterEvent(k)
		end
	end
	for unit, dbu in pairs(db) do
		if unit ~= "global" then
			Stuf:CreateUnitFrame(unit)
			RefreshUnit(config and "player" or unit, su[unit])
		end
	end
end


--------------------------------------------
function Stuf:UpdateElementLook(unit, ename)  -- update specific unit/element settings, mainly used by options
--------------------------------------------
	if unit == "global" then
		Stuf.statusbar = Stuf:GetMedia("statusbar", dbg.bartexture)
		Stuf.font = Stuf:GetMedia("font", dbg.font)
		Stuf.border = Stuf:GetMedia("border", dbg.border)
		if ename == "font" or ename == "bartexture" then  -- clears all local settings, thus defaulting to global
			for u, ut in pairs(db) do
				if u ~= "global" then
					for e, et in pairs(ut) do
						if ename == "font" then
							et.font, et.spellfont, et.timefont, et.counttfont = nil, nil, nil, nil
						elseif ename == "bartexture" then
							et.bartexture = nil
						end
					end
				end
			end
		end
		for u, uf in pairs(su) do  -- refresh all units and their elements
			Stuf:CreateUnitFrame(u)
			RefreshUnit(config and "player" or u, uf)
		end
	elseif ename == "frame" then  -- update base frame
		if Stuf.unitcopy[unit] == unit then
			for u, cu in pairs(Stuf.unitcopy) do
				if cu == unit then
					Stuf:CreateUnitFrame(u)
					RefreshUnit(config and "player" or u, su[u])
				end
			end
		else
			Stuf:CreateUnitFrame(unit)
			RefreshUnit(config and "player" or unit, su[unit])
		end
	else  -- update individual element
		if ename == "castbar" and (unit == "player" or unit == "pet") then
			Stuf:DefaultCastBar(unit)
		end
		if Stuf.unitcopy[unit] == unit then
			local b = su[unit] and builders[ename]
			if b then
				for u, cu in pairs(Stuf.unitcopy) do
					if cu == unit and su[u] then
						b(u, su[u], ename, db[unit][ename], nil, config)
					end
				end
			end
		else
			local b = su[unit] and builders[ename]
			if b then
				b(unit, su[unit], ename, db[unit][ename], nil, config)
			end
		end
	end
end

--------------------------------------------------------------
function Stuf:RegisterElementRefresh(uf, ename, category, add)
--------------------------------------------------------------
	uf[category][ename] = add and uf.refreshfuncs[ename]
	if uf.metroelements[ename] then
		uf.skiprefreshelement[ename] = nil
	else
		uf.skiprefreshelement[ename] = add
	end
end

----------------------------------
function Stuf:DefaultCastBar(unit)  -- hide or show blizzard's cast bars depending if Stuf's are shown
----------------------------------
	local bar = (unit == "player" and CastingBarFrame) or (unit == "pet" and PetCastingBarFrame)
	if not bar then return end
	if not db[unit].castbar.hide then
		if not bar.stufhidden and bar:IsEventRegistered("UNIT_SPELLCAST_START") then
			bar:UnregisterAllEvents()
			bar:Hide()
			bar.stufhidden = true
			if not bar.stufcheck then  -- make sure to not reshow castbars if another addon hid them
				hooksecurefunc(bar, "UnregisterAllEvents", function() bar.stufhidden = nil end)
				bar.stufcheck = true
			end
		end
	elseif bar.stufhidden and not bar:IsEventRegistered("UNIT_SPELLCAST_START") then
		bar:RegisterEvent("UNIT_SPELLCAST_START")
		bar:RegisterEvent("UNIT_SPELLCAST_STOP")
		bar:RegisterEvent("UNIT_SPELLCAST_FAILED")
		bar:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
		bar:RegisterEvent("UNIT_SPELLCAST_DELAYED")
		bar:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
		bar:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
		bar:RegisterEvent("PLAYER_ENTERING_WORLD")
		if unit == "pet" then
			bar:RegisterEvent("UNIT_PET")
		end
		bar.stufhidden = nil
	end
end

----------------------------------
function Stuf:GetMedia(mtype, key)
----------------------------------
	if not key and Stuf[mtype] then
		return Stuf[mtype]
	end
	if not smed:IsValid(mtype, key) then
		if not Stuf.nomedia then  -- handles missing textures
			Stuf.nomedia = { }
			smed.RegisterCallback(Stuf, "LibSharedMedia_Registered", function(event, mediatype, key)
				if not Stuf.nomedia[key] then return end
				Stuf:UpdateElementLook("global")
			end)
		end
		Stuf.nomedia[key] = true
	end
	return smed:Fetch(mtype, key)
end

------------------------------------------------------------------------------------
function Stuf:UpdateTextLook(t, font, afont, fontsize, fontflag, hj, vj, tc, sx, sy)
------------------------------------------------------------------------------------
	t:SetFont(afont or Stuf:GetMedia("font", font), fontsize or 12, fontflag ~= "None" and fontflag or "")
	t:SetJustifyH(hj or "CENTER")
	if vj ~= "none" then
		if vj == "CENTER" then vj = "MIDDLE" end -- 10.2.7 fix											  
		t:SetJustifyV(vj or "MIDDLE")
	end
	if tc then
		t:SetTextColor(tc.r, tc.g, tc.b, tc.a)
	end
	sx, sy = sx or 0, sy or 0
	if sx ~= 0 or sy ~= 0 then
		t:SetShadowColor(dbg.shadowcolor.r, dbg.shadowcolor.g, dbg.shadowcolor.b, dbg.shadowcolor.a)
	end
	t:SetShadowOffset(sx, sy)
end

do  -- color methods = function(parent, element db, 0-1 if hpthreshold, solid color choice, alpha override choice, hide if no color)
	local GetDifficultyColor, type = GetQuestDifficultyColor, type
	local c, r, g, b, a, colormethods
	colormethods = {
		class = function(p, db, value, choice, calpha)
			c = classcolor[p.cache.CLASS or "PRIEST"] or classcolor.PRIEST
			return c.r, c.g, c.b, (calpha and db[calpha]) or c.a or 1
		end,
		classdark = function(p, db, value, choice, calpha)
			r, g, b, a = colormethods.class(p, db, value, choice, calpha)
			return r * 0.3, g * 0.3, b * 0.3, a
		end,
		reaction = function(p, db, value, choice, calpha)
			c = reactioncolor[p.cache.reaction or 0] or Stuf.whitecolor
			return c.r, c.g, c.b, (calpha and db[calpha]) or c.a or 1
		end,
		reactiondark = function(p, db, value, choice, calpha)
			r, g, b, a = colormethods.reaction(p, db, value, choice, calpha)
			return r * 0.3, g * 0.3, b * 0.3, a
		end,
		classreaction = function(p, db, value, choice, calpha)
			local react = not p.cache.pc or p.cache.reaction == 2 or p.cache.reaction == 4
			return colormethods[react and "reaction" or "class"](p, db, value, choice, calpha)
		end,
		classreactiondark = function(p, db, value, choice, calpha)
			local react = not p.cache.pc or p.cache.reaction == 2 or p.cache.reaction == 4
			return colormethods[react and "reactiondark" or "classdark"](p, db, value, choice, calpha)
		end,
		reactionnpc = function(p, db, value, choice, calpha)
			return colormethods[p.cache.pc and "class" or "reaction"](p, db, value, choice, calpha)
		end,
		reactionnpcdark = function(p, db, value, choice, calpha)
			return colormethods[p.cache.pc and "classdark" or "reactiondark"](p, db, value, choice, calpha)
		end,
		difficulty = function(p, db, value, choice, calpha)
			c = GetDifficultyColor( (type(p.cache.level) ~= "number" and 999) or p.cache.level or 1 )
			return c.r, c.g, c.b, (calpha and db[calpha]) or c.a or 1
		end,
		difficultydark = function(p, db, value, choice, calpha)
			r, g, b, a = colormethods.difficulty(p, db, value, choice, calpha)
			return r * 0.3, g * 0.3, b * 0.3, a
		end,
		power = function(p, db, value, choice, calpha)
			c = powercolor[p.cache.powertype or UnitPowerType(p.unit) or 1] or powercolor[1]
			return c.r, c.g, c.b, (calpha and db[calpha]) or c.a or 1
		end,
		powerdark = function(p, db, value, choice, calpha)
			r, g, b, a = colormethods.power(p, db, value, choice, calpha)
			return r * 0.3, g * 0.3, b * 0.3, a
		end,
		hpgreen = function(p, db, value, choice, calpha)
			return hpgreen.r, hpgreen.g, hpgreen.b, (calpha and db[calpha]) or hpgreen.a or 1
		end,
		hpgreendark = function(p, db, value, choice, calpha)
			return hpgreen.r * 0.3, hpgreen.g * 0.3, hpgreen.b * 0.3, (calpha and db[calpha]) or hpgreen.a or 1
		end,
		hpred = function(p, db, value, choice, calpha)
			return hpred.r, hpred.g, hpred.b, (calpha and db[calpha]) or hpred.a or 1
		end,
		hpreddark = function(p, db, value, choice, calpha)
			return hpred.r * 0.3, hpred.g * 0.3, hpred.b * 0.3, (calpha and db[calpha]) or hpred.a or 1
		end,
		hpthreshold = function(p, db, value, choice, calpha)
			value = value or p.cache.frachp or 1
			if value > 0.5 then
				r = hpgreen.r + ((1 - value) * 2 * (hpgreen.g - hpgreen.r))
				g = hpgreen.g
				b = hpgreen.b
				a = (calpha and db[calpha]) or hpgreen.a or 1
			else
				r = hpred.r
				g = hpgreen.g - ((0.5 - value) * 2 * hpgreen.g)
				b = hpred.b
				a = (calpha and db[calpha]) or hpred.a or 1
			end
			return r, g, b, a
		end,
		hpthresholddark = function(p, db, value, choice, calpha)
			r, g, b, a = colormethods.hpthreshold(p, db, value, choice, calpha)
			return r * 0.3, g * 0.3, b * 0.3, a
		end,
		gray = function(p, db, value, choice, calpha)
			return gray.r, gray.g, gray.b, (calpha and db[calpha]) or gray.a or 1
		end,
		solid = function(p, db, value, choice, calpha, hide)
			c = db[choice or "bgcolor"]
			if c then
				return c.r, c.g, c.b, (calpha and db[calpha]) or c.a or 1
			elseif hide then
				return 0, 0, 0, 0
			else
				return 1, 1, 1, 1
			end
		end,
		custom = function(p, db, value, choice, calpha, hide)
			return colormethods.solid(p, db, value, choice, calpha, hide)
		end,
		hide = function(p) return 0, 0, 0, 0 end,
	}
	Stuf.colormethods = colormethods
	------------------------------------------
	function Stuf:AddColorMethod(method, func)  -- enables adding color methods from the outside
	------------------------------------------
		colormethods[method] = func
	end
	--------------------------------------------------------------------------------------
	function Stuf:GetColorFromMethod(method, p, db, value, choice, choicealpha, hideifnil)  -- 
	--------------------------------------------------------------------------------------
		return (colormethods[method or "hide"] or colormethods.hide)(p, db, value or 1, choice, choicealpha, hideifnil)
	end
end

do  -- statusbar texture orientations
	local setw, seth, setc = PlayerFrame.PlayerFrameContainer.FrameTexture.SetWidth, PlayerFrame.PlayerFrameContainer.FrameTexture.SetHeight, PlayerFrame.PlayerFrameContainer.FrameTexture.SetTexCoord
	local function verval(val)
		return ((val > 1) and 1) or ((val <= 0) and 0.00001) or val
	end
	local setvalues = {  -- setvalue functions for various statusbar orientations
		h = { normal = {
				normal =  function(this, val, bv) val=verval(val) setw(this, val * bv) setc(this, 0, val, 0, 1) end,
				reverse = function(this, val, bv) val=verval(val) setw(this, val * bv) setc(this, 1-val, 1, 0, 1) end,
			}, hflip = {
				normal =  function(this, val, bv) val=verval(val) setw(this, val * bv) setc(this, 1,0, 1,1, 1-val,0, 1-val,1) end,
				reverse = function(this, val, bv) val=verval(val) setw(this, val * bv) setc(this, val,0, val,1, 0,0, 0,1) end,
			}, vflip = {
				normal =  function(this, val, bv) val=verval(val) setw(this, val * bv) setc(this, 0,1, 0,0, val,1, val,0) end,
				reverse = function(this, val, bv) val=verval(val) setw(this, val * bv) setc(this, 1-val,1, 1-val,0, 1,1, 1,0) end,
			}, hvflip = {
				normal =  function(this, val, bv) val=verval(val) setw(this, val * bv) setc(this, 1,1, 1,0, 1-val,1, 1-val,0) end,
				reverse = function(this, val, bv) val=verval(val) setw(this, val * bv) setc(this, val,1, val,0, 0,1, 0,0) end,
			},
		}, 
		v = { normal = {
				normal =  function(this, val, bv) val=verval(val) seth(this, val * bv) setc(this, val,0, 0,0, val,1, 0,1) end,
				reverse = function(this, val, bv) val=verval(val) seth(this, val * bv) setc(this, 1,0, 1-val,0, 1,1, 1-val,1) end,
			}, hflip = {
				normal =  function(this, val, bv) val=verval(val) seth(this, val * bv) setc(this, 1-val,0, 1,0, 1-val,1, 1,1) end,
				reverse = function(this, val, bv) val=verval(val) seth(this, val * bv) setc(this, 0,0, val,0, 0,1, val,1) end,
			}, vflip = {
				normal =  function(this, val, bv) val=verval(val) seth(this, val * bv) setc(this, val,1, 0,1, val,0, 0,0) end,
				reverse = function(this, val, bv) val=verval(val) seth(this, val * bv) setc(this, 1,1, 1-val,1, 1,0, 1-val,0) end,
			}, hvflip = {
				normal =  function(this, val, bv) val=verval(val) seth(this, val * bv) setc(this, 1-val,1, 1,1, 1-val,0, 1,0) end,
				reverse = function(this, val, bv) val=verval(val) seth(this, val * bv) setc(this, 0,1, val,1, 0,0, val,0) end,
			},
		},
	}
	local function deplete(this, val, bv)
		this.sv(this, 1-val, bv)
	end
	-----------------------------------------------------------------------------------
	function Stuf:GetTexCoordOptions(isvertical, flipoption, isreverse, isdeplete, bar)
	-----------------------------------------------------------------------------------
		bar.sv = setvalues[(isvertical and "v") or "h"][flipoption or "normal"][(isreverse and "reverse") or "normal"]
		bar.SetValue = isdeplete and deplete or bar.sv
		return bar.SetValue, bar.sv
	end
end

do  -- general data updating
	local UnitLevel, UnitFactionGroup, UnitClassification = UnitLevel, UnitFactionGroup, UnitClassification
	local UnitPlayerControlled, GetGuildInfo, UnitIsPlayer = UnitPlayerControlled, GetGuildInfo, UnitIsPlayer
	local UnitInParty, UnitInRaid = UnitInParty, UnitInRaid
	local UnitRace, UnitCreatureType, UnitReaction = UnitRace, UnitCreatureType, UnitReaction
	local UnitPVPName, UnitIsPVP, UnitIsPVPSanctuary, UnitIsPVPFreeForAll = UnitPVPName, UnitIsPVP, UnitIsPVPSanctuary, UnitIsPVPFreeForAll
	local UnitIsDeadOrGhost = UnitIsDeadOrGhost
	local StufTT
	local function UpdateGuild(unit, uf, gt)
		if uf.cache.pc then
			local guild = GetGuildInfo(unit)
			uf.cache.guild = (guild and "<"..guild..">") or ""
		else
			if not StufTT then
				StufTT = CreateFrame("GameTooltip", "StufTT", Stuf, "GameTooltipTemplate")
				StufTT:SetOwner(Stuf, "ANCHOR_NONE")
			end
			StufTT:SetUnit(unit)
			local lt = StufTTTextLeft2:GetText()
			if lt and not strmatch(lt, _G.LEVEL) then
				uf.cache.guild = "<"..lt..">"
			else
				uf.cache.guild = ""
			end
		end
		uf.guildtext = uf.guildtext or gt
		if unit == "player" and not uf.pguild then
			Stuf:AddEvent("GUILD_ROSTER_UPDATE", function()
				for cu, cuf in pairs(su) do
					if cuf.guildtext then
						Stuf.UpdateGuild(cu, cuf)
						uf.refreshfuncs[cuf.guildtext.ename](cu, cuf, cuf.guildtext)
					end
				end
			end)
			uf.pguild = true
		end
	end
	Stuf.UpdateGuild = UpdateGuild
	
	RefreshUnit = function(unit, uf)  -- updates cache and runs all updaters
		if not UnitExists(unit) then return end
		uf = uf or su[unit]
		if not uf or uf.hidden or not uf.bg then return end
		local cache = uf.cache
		local level = UnitLevel(unit)
		cache.level = (level == -1 and dbg.classification.unknown) or level
		cache.name = (config and uf.unit) or GetUnitName(unit)
		cache.class, cache.CLASS = UnitClass(unit)
		
		if UnitIsPlayer(unit) then
			cache.pc = true
			cache.race = UnitRace(unit) or UnitCreatureType(unit) or L["Humanoid"] or ""
			cache.titlename = UnitPVPName(unit) or cache.name
			cache.ingroup = uf.skipgroup or (UnitInParty(unit) or UnitInRaid(unit))
		else
			cache.pc = nil
			cache.race = UnitCreatureType(unit) or _G.UNKNOWN or ""
			cache.titlename = cache.name
			cache.ingroup = uf.skipgroup
		end
		if uf.checkguild then
			UpdateGuild(unit, uf)
		end
		cache.classification = dbg.classification[UnitClassification(unit)] or ""
		cache.curhp = -1
		
		UpdateReaction(unit, uf, nil, true)
		for ename, func in pairs(uf.refreshfuncs) do
			if not uf.skiprefreshelement[ename] then
				func(unit, uf, uf[ename], true, nil, config)
			end
		end
	end
	Stuf.RefreshUnit = RefreshUnit

	Stuf:AddEvent("PLAYER_TARGET_CHANGED", function()
		if tar and UnitExists("target") then
			tar.cache.aggro = nil
			RefreshUnit("target", tar)
			PlaySound(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT)
		end
	end)
	
	Stuf:AddEvent("PLAYER_FOCUS_CHANGED", function()
		RefreshUnit("focus", su.focus)
		doaggro = Stuf.ingroup or UnitExists("pet") or UnitExists("focus")
	end)
	
	local ownerpet = { player = "pet", party1 = "partypet1", party2 = "partypet2", party3 = "partypet3", party4 = "partypet4", }
	Stuf:AddEvent("UNIT_PET", function(unit)  -- update pet and party pets
		local pet = ownerpet[unit]
		if not pet then return end
		RefreshUnit(pet, su[pet])
		if unit == "player" then
			doaggro = Stuf.ingroup or UnitExists("pet") or UnitExists("focus")
		end
	end)
	
	Stuf:AddEvent("UNIT_CLASSIFICATION_CHANGED", RefreshUnit)
	Stuf:AddEvent("UNIT_LEVEL", RefreshUnit)
	
	UpdateReaction = function(unit, uf, a3, reset)  -- refresh cache based on flags (pvp, reaction, combat)
		uf = uf or su[unit]
		if not uf or uf.hidden then return end
		local cache = uf.cache
		local creaturetype = UnitCreatureType(unit) or _G.UNKNOWN
		cache.creaturetype = (creaturetype == "Not specified" and _G.UNKNOWN) or creaturetype
		cache.pvp = UnitIsPVP(unit)
		cache.faction = cache.pvp and UnitFactionGroup(unit) or ""  -- only check for faction if PVPed
		cache.incombat = UnitAffectingCombat(unit)
		
		cache.assist = cache.ingroup or UnitCanAssist("player", unit)
		if cache.assist then
			cache.enemy = nil
			cache.hostile = nil
			cache.attackable = nil
		else
			cache.enemy = UnitIsEnemy(unit, "player")
			cache.hostile = UnitCanAttack(unit, vunit or "player")
			cache.attackable = UnitCanAttack("player", unit)
		end
		if cache.pc then
			cache.pvpffa = UnitIsPVPFreeForAll(unit)
			if cache.hostile then 
				cache.reaction = 2
			elseif cache.attackable then  -- Players we can attack but which are not hostile are yellow
				cache.reaction = 4
			elseif cache.pvp and not UnitIsPVPSanctuary(unit) and not UnitIsPVPSanctuary("player") then  -- Players we can assist but are PvP flagged are green
				cache.reaction = 6
			elseif cache.enemy then
				cache.reaction = 10
			else
				cache.reaction = 9
			end
		else  -- NPC
			cache.pvpffa = nil
			cache.reaction = UnitReaction(unit, "player")
		end
		for ename, func in pairs(uf.reactionelements) do  -- update all reaction/pvp elements
			func(unit, uf, uf[ename], reset, nil, config)
		end
	end
	Stuf:AddEvent("UNIT_FACTION", UpdateReaction)  -- update pvp and reaction
	Stuf:AddEvent("UNIT_FLAGS", UpdateReaction)  -- update reaction
	Stuf:AddEvent("PLAYER_FLAGS_CHANGED", UpdateReaction)
	Stuf:AddEvent("UNIT_MODEL_CHANGED", UpdateReaction)  -- update creature type
	
	local floor = math.floor
	local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
	local UnitPower, UnitPowerMax, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerType
	UpdateHealth = function(unit, uf, a3, reset)  -- update health cache and health elements
		uf = uf or su[unit]
		if not uf or uf.hidden then return end
		local cache = uf.cache
		local current, total = UnitHealth(unit), UnitHealthMax(unit)
		if cache.curhp ~= current or cache.maxhp ~= total then
			local frac = (current <= 0 and 0.00001) or (current >= total and 1) or (current / total)
			if cache.maxhp ~= total then
				cache.maxhp = total
				local level = UnitLevel(unit)
				cache.level = (level == -1 and dbg.classification.unknown) or level
			end
			cache.curhp = current
			cache.frachp = frac

			if current == 0 then
				cache.perchp = 0
			elseif current == total then
				cache.perchp = 100
			elseif frac > 0.005 then
				cache.perchp = floor(frac * 100 + 0.5)  -- floor operation is slow, avoid if possible
			else
				cache.perchp = 1  -- to prevent showing 0% if unit isn't dead
			end
			cache.deficithp = (frac < 0.99 and current - total) or ""
			
			if frac < 0.2 and UnitIsDeadOrGhost(unit) then  -- check if dead, then update related elements
				cache.dead = true
				for ename, func in pairs(uf.deathelements) do
					func(unit, uf, uf[ename])
				end
			elseif cache.dead then  -- was dead
				cache.dead = nil
				for ename, func in pairs(uf.deathelements) do
					func(unit, uf, uf[ename])
				end
			end
			for ename, func in pairs(uf.healthelements) do  -- update all health elements
				func(unit, uf, uf[ename], reset, frac)
			end
		end
	end
	UpdatePower = function(unit, uf, a3, reset, xfrac, ufframe)  -- update power cache and power elements
		uf = ufframe and uf or su[unit]
		if not uf or uf.hidden then return end
		local cache = uf.cache
		local current, total = UnitPower(unit), UnitPowerMax(unit)
		if cache.curmp ~= current or cache.maxmp ~= total then
			local frac = (current == 0 and 0.00001) or (current >= total and 1) or (current / total)
			cache.curmp = current
			cache.maxmp = total
			cache.fracmp = frac
			cache.shards = uf.iswl and UnitPower("player", _G.SPELL_POWER_SOUL_SHARDS) or ""

			if current == 0 then
				cache.percmp = 0
			elseif current == total then
				cache.percmp = 100
			elseif frac > 0.005 then
				cache.percmp = floor(frac * 100 + 0.5)
			else
				cache.percmp = 1
			end
			cache.deficitmp = (frac < 0.99 and (current - total)) or ""
			for ename, func in pairs(uf.powerelements) do  -- update all power elements
				func(unit, uf, uf[ename], reset, frac)
			end
		end
	end
	UpdatePowerType = function(unit, uf)  -- update power type and colors
		uf = uf or su[unit]
		if not uf or uf.hidden then return end
		uf.cache.powertype = UnitPowerType(unit)
		for ename, func in pairs(uf.powercolorelements) do
			func(unit, uf, uf[ename], true, true)
		end
		UpdatePower(unit, uf, nil, true, nil, true)
	end
	Stuf:AddEvent("UNIT_HEALTH", UpdateHealth)
	Stuf:AddEvent("UNIT_MAXHEALTH", UpdateHealth)
	Stuf:AddEvent("UNIT_POWER_UPDATE", UpdatePower)
	Stuf:AddEvent("UNIT_MAXPOWER", UpdatePower)
	Stuf:AddEvent("UNIT_DISPLAYPOWER", UpdatePowerType)
	
	local UnitHasVehicleUI = UnitHasVehicleUI
	Stuf:AddEvent("UNIT_ENTERED_VEHICLE", function(unit)
		if unit ~= "player" then return end
		if UnitHasVehicleUI(unit) then
			vunit, vf = "pet", su.pet
		else
			vunit, vf = "player", pla
		end
		Stuf.vunit = vunit
	end)
	Stuf:AddEvent("UNIT_EXITED_VEHICLE", function(unit)
		if unit ~= "player" then return end
		vunit, vf = "player", pla
		Stuf.vunit = vunit
	end)
	---------------------------
	function Stuf:EnableAggro()  -- enables aggro checking if user enabled features that requires it
	---------------------------
		Stuf.EnableAggro = nil
		aggrocolor = dbg.borderaggrocolor
		local wiped = true
		local aggrounits = {  -- only check these units for aggro
			"target", "focus", "targettarget", "focustarget", "pettarget",
			"party1target", "party2target", "party3target", "party4target",
			"arena1", "arena2", "arena3", "arena4", "arena5",
		}
		local function UnitAggro(ut)
			if not UnitCanAttack("player", ut) then return end
			ut = ut.."target"
			if not UnitCanAssist("player", ut) then return end
			for u, uf in pairs(su) do
				if UnitIsUnit(u, ut) then
					uf.cache.aggro = true
					wiped = nil
				end
			end
		end
		UpdateAggro = function()
			if not wiped then
				for u, uf in pairs(su) do
					uf.cache.aggro = nil
				end
				wiped = true
			end
			if Stuf.numraid ~= 0 then  -- check aggro in a raid
				for i = 1, Stuf.numraid, 1 do
					UnitAggro("raid"..i.."target")
				end
			elseif doaggro then  -- check aggro in group
				for _, au in ipairs(aggrounits) do
					UnitAggro(au)
				end
			end
		end
	end
end

do  -- handle dynamic loading of party frames
	local function ShowHideUnit(uf, hide)
		if not uf then return end
		if hide then
			UnregisterUnitWatch(uf)
			uf:Hide()
			uf.hidden = true
		elseif not uf.db.hide then
			RegisterUnitWatch(uf, false)
			uf.hidden = nil
		end
	end
	GroupUpdate = function()  -- hide party interface in raid if default UI's option is checked
		local wasingroup = Stuf.ingroup
		Stuf.numraid = (IsInRaid() and GetNumGroupMembers()) or 0
		Stuf.ingroup = IsInGroup()
		doaggro = Stuf.ingroup or UnitExists("pet") or UnitExists("focus")
		if wasingroup and not Stuf.ingroup then
			RefreshUnit("player", pla)
		end
		if InCombatLockdown() then
			if Stuf.CreateParty then Stuf:CreateParty() end
			return
		end
		if Stuf.numraid > 0 and dbg.hidepartyinraid and (select(2, IsInInstance()) ~= "arena" or not dbg.showarena) then
			if partyvisible then 
				for i = 1, 4, 1 do
					ShowHideUnit(su["party"..i], true)
					ShowHideUnit(su["partypet"..i], true)
					ShowHideUnit(su["party"..i.."target"], true)
				end
				partyvisible = false
			end
		elseif not partyvisible then
			if Stuf.CreateParty then
				Stuf:CreateParty()
			else
				for i = 1, 4, 1 do
					ShowHideUnit(su["party"..i])
					ShowHideUnit(su["partypet"..i])
					ShowHideUnit(su["party"..i.."target"])
				end
				partyvisible = true
			end
		end
	end
	Stuf.GroupUpdate = GroupUpdate
	---------------------------
	function Stuf:CreateParty()
	---------------------------
		Stuf.ingroup = IsInGroup()
		if Stuf.ingroup then
			Stuf.numraid = (IsInRaid() and GetNumGroupMembers()) or 0
			if Boss1TargetFrame then
				for unit in pairs(db) do
					if strmatch(unit, "boss") then
						Stuf:CreateUnitFrame(unit)
					end
				end
			end
		else
			Stuf.numraid = 0
			return
		end
		if Stuf.numraid > 0 and dbg.hidepartyinraid and (select(2, IsInInstance()) ~= "arena" or not dbg.showarena) then return end
		if InCombatLockdown() then  -- wait til combat is over to create protected frames
			return Stuf:AddEvent("PLAYER_REGEN_ENABLED", Stuf.CreateParty)
		end
		Stuf:RemoveEvent("PLAYER_REGEN_ENABLED", Stuf.CreateParty)
		Stuf:RemoveEvent("GROUP_ROSTER_UPDATE", Stuf.CreateParty)
		for unit in pairs(db) do
			if strmatch(unit, "party") then
				Stuf:CreateUnitFrame(unit)
			end
		end
		
		local function updateparty()
			local wasingroup = Stuf.ingroup
			Stuf.ingroup = IsInGroup()
			doaggro = Stuf.ingroup or UnitExists("pet") or UnitExists("focus")
			for i = 1, 4, 1 do
				local uf = su["party"..i]
				if uf and not uf.hidden then
					RefreshUnit("party"..i, uf)
					RefreshUnit("partypet"..i)
				end
			end
			if wasingroup and not Stuf.ingroup then
				RefreshUnit("player", pla)
			end
		end
		Stuf:AddEvent("GROUP_ROSTER_UPDATE", updateparty)
		updateparty()
		partyvisible = true
		Stuf.CreateParty = nil
		GroupUpdate()
	end
	Stuf:AddEvent("GROUP_ROSTER_UPDATE", GroupUpdate)
	
	---------------------------
	function Stuf:CreateArena()
	---------------------------
		if select(2, IsInInstance()) ~= "arena" then return end
		if InCombatLockdown() then  -- wait til combat is over to create protected frames
			return Stuf:AddEvent("PLAYER_REGEN_ENABLED", Stuf.CreateArena)
		end
		Stuf:RemoveEvent("PLAYER_REGEN_ENABLED", Stuf.CreateArena)
		
		local arenashown
		for unit in pairs(db) do
			if strmatch(unit, "arena") and not Stuf:CreateUnitFrame(unit) then
				arenashown = true
			end
		end
		
		if not arenashown then return end
		for i = 1, 5, 1 do
			DisableDefault(_G["ArenaEnemyFrame"..i])
			DisableDefault(_G["ArenaEnemyFrame"..i.."PetFrame"])
		end
		ArenaEnemyFrames:UnregisterAllEvents()
		ArenaEnemyFrames:Hide()
		Stuf:AddEvent("ARENA_OPPONENT_UPDATE", function(unit, a1)
			local uf = su[unit]
			if not uf or uf.hidden then return end
			if a1 == "unseen" then
				if not uf.placeholder then
					uf.placeholder = UIParent:CreateTexture(nil, "BACKGROUND")
					uf.placeholder:SetTexture(uf.bg:GetTexture())
					uf.placeholder:SetVertexColor(0.6, 0.4, 0.4, 0.7)
					uf.placeholder:SetAllPoints(uf)
				end
				uf.placeholder:Show()
			else
				if a1 == "seen" then
					RefreshUnit(unit, uf)
				end
				if uf.placeholder then
					uf.placeholder:Hide()
				end
			end
		end)
		Stuf.CreateArena = nil
	end
end	

--------------------------------------------------------
function Stuf:UpdateBaseLook(parent, f, dbe, framelevel)
--------------------------------------------------------
	local c = dbe.bgcolor or Stuf.hidecolor
	if f.bg then
		f.bg:SetTexture(Stuf:GetMedia("statusbar", dbe.bartexture))
		if dbe.bgcolormethod then
			f.bg:SetVertexColor(Stuf:GetColorFromMethod(dbe.bgcolormethod, parent, dbe, 1, nil, "bgalpha"))
		else
			local c = dbe.bgcolor or Stuf.hidecolor
			f.bg:SetVertexColor(c.r, c.g, c.b, c.a)
		end
	elseif c.a and c.a > 0 then
		backdrop.bgFile = Stuf:GetMedia("statusbar", dbe.bg)
		f:SetBackdrop(backdrop)
		f:SetBackdropColor(c.r, c.g, c.b, c.a)
	end
	f:SetWidth(dbe.w)
	f:SetHeight(dbe.h)
	f:SetAlpha(dbe.alpha or 1)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", dbe.x, dbe.y)

	c = dbe.bordercolor or Stuf.hidecolor
	if f.border and c.a > 0 then
		borderdrop.edgeFile = Stuf:GetMedia("border", dbe.border)
		f.border:SetBackdrop(borderdrop)
		f.border:SetBackdropBorderColor(c.r, c.g, c.b, c.a)
	end
	if framelevel then
		f:SetFrameLevel(framelevel)
	elseif dbe.framelevel then
		f:SetFrameLevel(dbe.framelevel)
	end
end
--------------------------------------------------------
function Stuf:CreateBase(unit, uf, name, dbe, frametype)  -- basic base frame for many elements
--------------------------------------------------------
	local f = CreateFrame(frametype or "Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
	f.border = CreateFrame("Frame", nil, f, BackdropTemplateMixin and 'BackdropTemplate')
	f.border:SetPoint("TOPLEFT", -4, 4)
	f.border:SetPoint("BOTTOMRIGHT", 4, -4)
	f.ename = name
	f.db = dbe
	uf[name] = f
	return f
end

-- setup base frame
local SetBackdropBorderColor = Stuf.SetBackdropBorderColor
local function UpdateBorderColor(unit, uf, f, reset)
	if not uf then return end
	if uf.cache.aggro and aggrocolor.a > 0.1 then
		uf.border:SetBackdropBorderColor(aggrocolor.r, aggrocolor.g, aggrocolor.b, aggrocolor.a)
	else
		uf.border:SetBackdropBorderColor(uf.borderc(uf, uf.dbf, uf.cache.frachp, "bordercolor"))
	end
end
local function MainOnShow(this)
	if not this.bg then
		this:SetScript("OnShow", nil)
		Stuf:CreateUnitFrame(this.unit, true)
		if not this.ismetro then
			RefreshUnit(this.unit, this)
		end
	elseif not this.metro then
		this:SetScript("OnShow", nil)
	end
	if this.ismetro then
		RefreshUnit(this.unit, this)
	end
end
local function MainOnEnter(this)  -- main frame on mouse enter script
	this.bg:SetVertexColor(bgmousecr, bgmousecg, bgmousecb, bgmouseca)
	if this.borderc and dbg.bordermousecolor.a > 0 then  -- set mouseover border color if needed
		this.border:SetBackdropBorderColor(dbg.bordermousecolor.r, dbg.bordermousecolor.g, dbg.bordermousecolor.b, dbg.bordermousecolor.a)
		this.border.SetBackdropBorderColor = Stuf.nofunc
		this.bordermoused = true
	end
	if this.mouseover then  -- show mouseover elements
		for ename, func in pairs(this.mouseover) do
			func(this.unit, this, this[ename], nil, nil, config)
		end
	end
	UnitFrame_UpdateTooltip(this)
end
local function MainOnLeave(this)  -- main frame on mouse leave script
	this.bg:SetVertexColor(bgcr, bgcg, bgcb, bgca)
	if this.bordermoused then
		this.border.SetBackdropBorderColor = SetBackdropBorderColor
		UpdateBorderColor(nil, this)
		this.bordermoused = nil
	end
	if this.mouseover then
		for ename, func in pairs(this.mouseover) do
			func(this.unit, this, this[ename], nil, nil, config)
		end
	end
	GameTooltip:Hide()
end
local function MainPostClick(this, a1)
	if a1 == "RightButton" and UIDROPDOWNMENU_OPEN_MENU == _G[dropdown[this.unit].."DropDown"] and DropDownList1:IsShown() then
		DropDownList1:ClearAllPoints()
		if (this:GetBottom() * (this.dbf.scale or 1)) < (GetScreenHeight() * 0.45) then
			DropDownList1:SetPoint("BOTTOMLEFT", this, "TOPLEFT", 60, 0 )
		else
			DropDownList1:SetPoint("TOPLEFT", this, "BOTTOMLEFT", 60, 0 )
		end
	end
end
local function FastHealthOnUpdate(this)
	this.dofasthp = not this.dofasthp
	if not this.dofasthp then return end
	UpdateHealth(this.unit, this.uf)
end

---------------------------------------------
function Stuf:CreateUnitFrame(unit, fromshow)  -- creates entire unit frame and updates its settings 
---------------------------------------------
	if InCombatLockdown() and not fromshow then return end
	local uf = su[unit]
	local dbuf = db[unit].frame
	local notpla = unit ~= "player"
	if dbuf.hide then
		if uf then
			if notpla then
				UnregisterUnitWatch(uf)
			end
			uf.hidden = true
			uf:Hide()
		end
		return true
	end
	local copy = Stuf.unitcopy[unit]
	local targetdb = (copy and db[copy]) or db[unit]
	local dbf = targetdb.frame
	
	if not fromshow then  -- secure stuff, requires out of combat
		if not uf then
			uf = CreateFrame("Button", "Stuf.units."..unit, UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
			su[unit] = uf
			uf.frame = uf
			uf.unit = unit
			if mainunits1[unit] then
				su1[unit] = uf
			elseif mainunits2[unit] then
				su2[unit] = uf
			else
				metrounits[unit] = uf
				uf.ismetro = true
			end
			uf.cache = { unit = unit, }
			uf.refreshfuncs = { health = UpdateHealth, power = UpdatePowerType, }
			uf.healthelements, uf.powerelements, uf.powercolorelements = { }, { }, { }
			uf.deathelements, uf.reactionelements, uf.metroelements, uf.skiprefreshelement = { }, { }, { }, { }

			uf:SetClampedToScreen(true)
			uf:RegisterForClicks("AnyUp")

			uf.db, uf.dbf = dbuf, dbf
			--SecureUnitButton_OnLoad(uf, unit)
			uf:SetAttribute("*type1", "target")
			uf:SetAttribute("type2", "togglemenu")
			
			uf:SetAttribute("unit", unit)

			if notpla then
				uf:SetScript("OnShow", MainOnShow)
				if unit == "target" then
					tar = uf
				elseif strmatch(unit, "party(%d?)$") then
					uf:SetAttribute("toggleForVehicle", true)
					uf.skipgroup = true
				elseif unit == "pet" or strmatch(unit, "partypet") then  -- skips checking if these units are friendly
					uf.skipgroup = true
				elseif strmatch(unit, "arena(%d+)$") then  -- main arena unit
					uf:SetAttribute("*type2", "focus")
				elseif unit == "boss1" then
					Stuf:AddEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", RefreshUnit)
				end
				uf:Hide()
				RegisterUnitWatch(uf, false)
			else
				pla = uf
				vf = (vunit == "player" and pla) or vf
				uf:SetAttribute("toggleForVehicle", true)
				uf.cache.shards = ""
			end

			uf.hidden = true
			ClickCastFrames[uf] = true
		elseif not notpla then
			uf:Show()
		else
			uf:Hide()
			RegisterUnitWatch(uf, false)
		end
		if notpla then  -- register watch for secure units; player is always visible
			if config then
				UnregisterUnitWatch(uf)
				uf:Show()
				partyvisible = true
				uf.config = true
			elseif uf.config then
				uf:Hide()
				RegisterUnitWatch(uf, false)
				uf.config = nil
			end
			if uf.ismetro then
				uf:SetScript("OnShow", MainOnShow)
			end
		end
		uf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", dbuf.x, dbuf.y)
		uf:SetWidth(dbf.w or 1)
		uf:SetHeight(dbf.h or 1)
		uf:SetScale(dbf.scale or 1)
		if dbg.strata then
			uf:SetFrameStrata(dbg.strata)
		end
	end
	uf.hidden = nil
	
	local initial = not uf.bg
	if not uf:IsShown() and initial then return end
	if initial then
		uf.bg = uf:CreateTexture(nil, "BACKGROUND")
		uf.bg:SetAllPoints(uf)
		uf.border = CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
		uf.border:SetPoint("TOPLEFT", -5, 5)
		uf.border:SetPoint("BOTTOMRIGHT", 5, -5)
		uf:SetScript("OnEnter", MainOnEnter)
		uf:SetScript("OnLeave", MainOnLeave)
	end

	bgmousecr, bgmousecg, bgmousecb, bgmouseca = dbg.bgmousecolor.r, dbg.bgmousecolor.g, dbg.bgmousecolor.b, dbg.bgmousecolor.a
	bgcr, bgcg, bgcb, bgca = dbg.bgcolor.r, dbg.bgcolor.g, dbg.bgcolor.b, dbg.bgcolor.a
	uf.bg:SetTexture(Stuf:GetMedia(dbg.bglist or "statusbar", dbg.bg))
	uf.bg:SetVertexColor(bgcr, bgcg, bgcb, bgca)

	local setup = (dbf.hflip and dbf.vflip and "hvflip") or (dbf.hflip and "hflip") or (dbf.vflip and "vflip") or "normal"
	Stuf:GetTexCoordOptions(dbf.vertical, setup, nil, nil, uf.bg)(uf.bg, 1, dbf.vertical and dbf.h or dbf.w)

	if dbg.border and dbg.border ~= "None" then  -- setups border and its color behavior
		borderdrop.edgeFile = Stuf.border
		uf.border:SetBackdrop(borderdrop)
		local bcm = dbf.bordercolormethod
		if bcm and bcm ~= "solid" then
			uf.refreshfuncs["ufborder"] = UpdateBorderColor
			if bcm == "hpthreshold" then
				Stuf:RegisterElementRefresh(uf, "ufborder", "healthelements", true)
			elseif bcm == "power" or bcm == "powerdark" then
				Stuf:RegisterElementRefresh(uf, "ufborder", "powercolorelements", true)
			elseif strmatch(bcm, "reaction") then
				Stuf:RegisterElementRefresh(uf, "ufborder", "reactionelements", true)
			end
		end
		uf.borderc = self.colormethods[bcm or "hide"] or self.colormethods.hide
		if dbg.borderaggrocolor.a > 0 then
			if Stuf.EnableAggro then Stuf:EnableAggro() end
			uf.refreshfuncs["ufborder"] = UpdateBorderColor
			Stuf:RegisterElementRefresh(uf, "ufborder", "metroelements", true)
		end
		UpdateBorderColor(unit, uf)
	else
		borderdrop.edgeFile = ""
		uf.border:SetBackdrop(borderdrop)
	end

	if dbg.morealpha then
		if not Stuf.enabledalpha then  -- combat and/or target fade setup
			local function AlphaSettings()
				if not dbg.morealpha then return end
				local incombat, a = UnitAffectingCombat("player"), 1
				if UnitExists("target") or config then
					a = (incombat and (dbg.combattargetalpha or 1)) or (dbg.targetalpha or 1)
				else
					a = (incombat and (dbg.combatalpha or 1)) or (dbg.alpha or 1)
				end
				for u, uf in pairs(su) do
					uf:SetAlpha(a)
				end
			end
			Stuf:AddEvent("PLAYER_REGEN_ENABLED", AlphaSettings)
			Stuf:AddEvent("PLAYER_REGEN_DISABLED", AlphaSettings)
			Stuf:AddEvent("PLAYER_TARGET_CHANGED", AlphaSettings)
			Stuf.enabledalpha = true
		end
		events.PLAYER_REGEN_ENABLED()
	else
		uf:SetAlpha(dbg.alpha or 1)
	end
	if dbg.petbattlehide then
		if not Stuf.enabledpetbattle then
			local function PetBattleHide()
				if C_PetBattles.IsInBattle() then
					for u, uf in pairs(su) do
						uf:SetAlpha(0.01)
					end
				else
					for u, uf in pairs(su) do
						uf:SetAlpha(dbg.alpha or 1)
					end
				end
			end
			Stuf:AddEvent("PET_BATTLE_OPENING_START", PetBattleHide)
			Stuf:AddEvent("PET_BATTLE_CLOSE", PetBattleHide)
			Stuf.enabledpetbattle = true
		end
	else
		uf:SetAlpha(dbg.alpha or 1)
	end

	if notpla then  -- OOR fade setup
		if not dbg.morealpha and dbg.ooralpha and dbg.ooralpha ~= (dbg.alpha or 1) then
			Stuf.OORAlpha = Stuf.OORAlpha or function(unit, uf)
				if not uf or uf.hidden then return end
				uf:SetAlpha((Stuf.conditions.oor(uf.cache, uf.unit) or (uf.cache.dead and uf.cache.assist)) and dbg.ooralpha or dbg.alpha or 1)
			end
			uf.refreshfuncs["ooralpha"] = Stuf.OORAlpha
			Stuf:RegisterElementRefresh(uf, "ooralpha", "metroelements", true)
		elseif uf.refreshfuncs.ooralpha then
			uf.refreshfuncs.ooralpha = nil
			Stuf:RegisterElementRefresh(uf, "ooralpha", "metroelements", nil)
		end
	else
		uf.iswl = Stuf.CLS == "WARLOCK"
	end

	if dbf.fasthp then
		uf.fasthpframe = uf.fasthpframe or CreateFrame("Frame", nil, uf, BackdropTemplateMixin and 'BackdropTemplate')
		uf.fasthpframe.unit, uf.fasthpframe.uf = uf.unit, uf
		uf.fasthpframe:SetScript("OnUpdate", FastHealthOnUpdate)
	elseif uf.fasthpframe then
		uf.fasthpframe:SetScript("OnUpdate", nil)
	end

	for index, ename in ipairs(buildorder) do  -- now build all elements
		local dbe = targetdb[ename]
		local b = dbe and builders[ename]
		if b then
			b(unit, uf, ename, dbe, nil, config)
		end
	end
end
