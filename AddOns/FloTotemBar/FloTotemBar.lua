-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local VERSION
if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
	VERSION = "9.0.44.2"
elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	VERSION = "1.13.43"
end

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
local _

local ALGO_TRAP;

local SHOW_WELCOME = true;
local FLOTOTEMBAR_OPTIONS_DEFAULT = { [1] = { scale = 1, borders = true, barLayout = "1row", barSettings = {} }, active = 1 };
FLOTOTEMBAR_OPTIONS = FLOTOTEMBAR_OPTIONS_DEFAULT;
local FLOTOTEMBAR_BARSETTINGS_DEFAULT = {
	["SEAL"] = { buttonsOrder = {}, position = "auto", color = { 0.49, 0.49, 0, 0.7 }, hiddenSpells = {} },
	["TRAP"] = { buttonsOrder = {}, position = "auto", color = { 0.49, 0.49, 0, 0.7 }, hiddenSpells = {} },
	["EARTH"] = { buttonsOrder = {}, position = "auto", color = { 0, 0.49, 0, 0.7 }, hiddenSpells = {} },
	["FIRE"] = { buttonsOrder = {}, position = "auto", color = { 0.49, 0, 0, 0.7 }, hiddenSpells = {} },
	["WATER"] = { buttonsOrder = {}, position = "auto", color = { 0, 0.49, 0.49, 0.7 }, hiddenSpells = {} },
	["AIR"] = { buttonsOrder = {}, position = "auto", color = { 0, 0, 0.99, 0.7 }, hiddenSpells = {} },
};
FLO_CLASS_NAME = nil;
local ACTIVE_OPTIONS = FLOTOTEMBAR_OPTIONS[1];

-- Ugly
local changingSpec = true;

local GetSpecialization = GetSpecialization;
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	GetSpecialization = function ()
		return 1
	end
end

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

-- Executed on load, calls general set-up functions
function FloTotemBar_OnLoad(self)

	ALGO_TRAP = {
		[1] = FloTotemBar_CheckTrapLife,
		[2] = FloTotemBar_CheckTrapLife,
		[3] = FloTotemBar_CheckTrapLife,
		[4] = function() end
	};
	
	-- Class-based setup, abort if not supported
	_, FLO_CLASS_NAME = UnitClass("player");
	FLO_CLASS_NAME = strupper(FLO_CLASS_NAME);

	local classSpells = FLO_TOTEM_SPELLS[FLO_CLASS_NAME];

	if classSpells == nil then
		return;
	end
	
	if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
		self.sharedCooldown = true;
	end

	local thisName = self:GetName();
	self.totemtype = string.sub(thisName, 7);

	-- Store the spell list for later
	self.availableSpells = classSpells[self.totemtype];
	if self.availableSpells == nil then
		return;
	end

	-- Init the settings variable
	ACTIVE_OPTIONS.barSettings[self.totemtype] = FLOTOTEMBAR_BARSETTINGS_DEFAULT[self.totemtype];

	self.spells = {};
	self.SetupSpell = FloTotemBar_SetupSpell;
	self.OnSetup = FloTotemBar_OnSetup;
	self.menuHooks = { SetPosition = FloTotemBar_SetPosition, SetBorders = FloTotemBar_SetBorders };
	if FLO_CLASS_NAME == "SHAMAN" and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
		self.menuHooks.SetLayoutMenu = FloTotemBar_SetLayoutMenu;
		self.slot = _G[self.totemtype.."_TOTEM_SLOT"];
	end
	self:EnableMouse(1);
	
	if SHOW_WELCOME then
		DEFAULT_CHAT_FRAME:AddMessage( "FloTotemBar "..VERSION.." loaded." );
		SHOW_WELCOME = nil;

		SLASH_FLOTOTEMBAR1 = "/flototembar";
		SLASH_FLOTOTEMBAR2 = "/ftb";
		SlashCmdList["FLOTOTEMBAR"] = FloTotemBar_ReadCmd;

		self:RegisterEvent("ADDON_LOADED");
		if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
			self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
		end
		self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
	end
	self:RegisterEvent("LEARNED_SPELL_IN_TAB");
	self:RegisterEvent("CHARACTER_POINTS_CHANGED");
	self:RegisterEvent("SPELLS_CHANGED");
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	self:RegisterEvent("ACTIONBAR_UPDATE_USABLE");
	self:RegisterEvent("UPDATE_BINDINGS");
	
	if self.totemtype ~= "CALL" then
		self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player");
		self:RegisterEvent("PLAYER_DEAD");

		-- Destruction detection
		if FLO_CLASS_NAME == "SHAMAN" then
			self:RegisterEvent("PLAYER_TOTEM_UPDATE");
		else
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
		end
	end
end

function FloTotemBar_OnEvent(self, event, arg1, ...)

	if event == "LEARNED_SPELL_IN_TAB" or event == "CHARACTER_POINTS_CHANGED" or event == "SPELLS_CHANGED" then
		if not changingSpec then
			if GetSpecialization() ~= FLOTOTEMBAR_OPTIONS.active then
				FloTotemBar_CheckTalentGroup(GetSpecialization());
			else
				FloLib_Setup(self);
			end
		end

	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if arg1 == "player" then
			FloLib_StartTimer(self, ...);
		end

	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		local _, spellId = ...;
		local spellName = GetSpellInfo(spellId);
		if arg1 == "player" and spellName == FLOLIB_ACTIVATE_SPEC then
			changingSpec = false;
		end

	elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_USABLE" then
		--FloTotemBar_TryAddFixupTrapAction();
		FloLib_UpdateState(self);

	elseif event == "PLAYER_DEAD" then
		FloTotemBar_ResetTimers(self);

	elseif (event == "ADDON_LOADED" and arg1 == "FloTotemBar") or event == "UPDATE_BINDINGS" then
		if event == "ADDON_LOADED" then
			FloTotemBar_CheckTalentGroup(FLOTOTEMBAR_OPTIONS.active);

			-- Hook the UIParent_ManageFramePositions function
			hooksecurefunc("UIParent_ManageFramePositions", FloTotemBar_UpdatePositions);
			if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
				hooksecurefunc("SetSpecialization", function() changingSpec = true; end);
			end
		end

		local totemtype = self.totemtype;
		if totemtype == "TRAP" then totemtype = "EARTH" end
		FloLib_UpdateBindings(self, "FLOTOTEM"..totemtype);

	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		local spec = GetSpecialization();
		if arg1 == "player" and FLOTOTEMBAR_OPTIONS.active ~= spec then
			FloTotemBar_TalentGroupChanged(spec);
		end

	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		-- Events used for totem destruction detection
		local i, pos;
		for i = 1, #self.spells do
			if self.sharedCooldown then
				pos = 1
			else
				pos = i
			end
			if self["activeSpell"..pos] and i == self["activeSpell"..pos] then
				self.spells[i].algo(self, i, CombatLogGetCurrentEventInfo());
			end
		end
	elseif event == "PLAYER_TOTEM_UPDATE" then
		-- Events used for totem destruction detection
		local i, pos;
		for i = 1, #self.spells do
			if self.sharedCooldown then
				pos = 1
			else
				pos = i
			end
			if arg1 and self["activeSpell"..pos] and i == self["activeSpell"..pos] then
				self.spells[i].algo(self, arg1, i, ...);
			end
		end
	end
end

function FloTotemBar_SetFixupTrap(pos)

	local i;
	ACTIVE_OPTIONS.baseActionTrap = pos;
	for i = 1, #FLO_TOTEM_SPELLS.HUNTER.TRAP do
		local name = GetSpellInfo(FLO_TOTEM_SPELLS.HUNTER.TRAP[i].id);
		PickupSpellBookItem(name);
		PlaceAction(pos - 1 + i);
		ClearCursor();
	end
end

function FloTotemBar_FindEmptyActions(qty)

	local a, remain, start;

	start = nil;
	remain = qty;
	a = 73;
	while a <= 120 and remain > 0 do
		if GetActionInfo(a) then
			start = nil;
			remain = qty;
		else
			if start == nil then
				start = a;
			end
			remain = remain - 1;
		end
		a = a + 1;
	end
	if remain > 0 then
		start = nil;
	end
	return start;
end

function FloTotemBar_TryAddFixupTrapAction()

	if ACTIVE_OPTIONS.baseActionTrap == nil then
		local pos = FloTotemBar_FindEmptyActions(#FLO_TOTEM_SPELLS.HUNTER.TRAP);

		if pos then
			FloTotemBar_SetFixupTrap(pos);
		end
	end
end

function FloTotemBar_TalentGroupChanged(grp)

	local k, v;
	-- Save old spec position
	for k, v in pairs(ACTIVE_OPTIONS.barSettings) do
		if v.position ~= "auto" then
			local bar = _G["FloBar"..k];
                        if bar ~= nil then
			        v.refPoint = { bar:GetPoint() };
                        end
		end
	end

	FloTotemBar_CheckTalentGroup(grp);
	for k, v in pairs(ACTIVE_OPTIONS.barSettings) do
		local bar = _G["FloBar"..k];
                if bar ~= nil then
		        FloLib_Setup(bar);
		        -- Restore position
		        if v.position ~= "auto" and v.refPoint then
			        bar:ClearAllPoints();
			        bar:SetPoint(unpack(v.refPoint));
		        end
			end
	end
end

function FloTotemBar_CheckTalentGroup(grp)

	local k, v;
	changingSpec = false;

	FLOTOTEMBAR_OPTIONS.active = grp;
	ACTIVE_OPTIONS = FLOTOTEMBAR_OPTIONS[grp];
	-- first time talent activation ?
	if not ACTIVE_OPTIONS then
		-- Copy primary spec options into other spec
		FLOTOTEMBAR_OPTIONS[grp] = {};
		FloLib_CopyPreserve(FLOTOTEMBAR_OPTIONS[1], FLOTOTEMBAR_OPTIONS[grp]);
		ACTIVE_OPTIONS = FLOTOTEMBAR_OPTIONS[grp];
	end
	for k, v in pairs(ACTIVE_OPTIONS.barSettings) do
		local bar = _G["FloBar"..k];
                if bar ~= nil then
		        bar.globalSettings = ACTIVE_OPTIONS;
		        bar.settings = v;
		        FloTotemBar_SetPosition(nil, bar, v.position);
                else
                        ACTIVE_OPTIONS.barSettings[k] = nil;
                end
	end
	FloTotemBar_SetScale(ACTIVE_OPTIONS.scale);
	FloTotemBar_SetBorders(nil, ACTIVE_OPTIONS.borders);

end

function FloTotemBar_ReadCmd(line)

	local i, v;
	local cmd, var = strsplit(' ', line or "");

	if cmd == "scale" and tonumber(var) then
		FloTotemBar_SetScale(var);
	elseif cmd == "lock" or cmd == "unlock" or cmd == "auto" then
		for i, v in ipairs({FloBarTRAP, FloBarEARTH}) do
			FloTotemBar_SetPosition(nil, v, cmd);
		end
	elseif cmd == "borders" then
		FloTotemBar_SetBorders(nil, true);
	elseif cmd == "noborders" then
		FloTotemBar_SetBorders(nil, false);
	elseif cmd == "panic" or cmd == "reset" then
		FloLib_ResetAddon("FloTotemBar");
	elseif cmd == "clearfixup" then
		if ACTIVE_OPTIONS.baseActionTrap then
			ACTIVE_OPTIONS.baseActionTrap = nil;
			for i = 73, 120 do
				local t, id = GetActionInfo(i);
				if t == "spell" and (id == 13795 or id == 1499 or id == 13809 or id == 13813 or id == 34600 or id == 77769) then
					PickupAction(i);
					ClearCursor();
				end
			end
		end
	elseif cmd == "addfixup" then
		FloTotemBar_TryAddFixupTrapAction();
	else
		DEFAULT_CHAT_FRAME:AddMessage( "FloTotemBar usage :" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ftb lock|unlock : lock/unlock position" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ftb borders|noborders : show/hide borders" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ftb auto : Automatic positioning" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ftb scale <num> : Set scale" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ftb panic||reset : Reset FloTotemBar" );
		return;
	end
end

function FloTotemBar_UpdateTotem(self, slot, idx)

	if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		local haveTotem, totemName, startTime, duration, icon = GetTotemInfo(slot);

		-- Find spell
		if totemName == "" and self.spells[idx].slot == slot then
			FloLib_ResetTimer(self, idx);
		elseif self.spells[idx].name == totemName then
			self.spells[idx].slot = slot;
			local countdown = _G[self:GetName().."Countdown"..idx];
			if countdown then
				local timeleft = GetTotemTimeLeft(slot);

				countdown:SetMinMaxValues(0, duration);
				countdown:SetValue(timeleft);
			end
		end
	elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
		if self.slot == slot then

			local haveTotem, totemName, startTime, duration, icon = GetTotemInfo(slot);
			local timeleft = GetTotemTimeLeft(slot);
			local countdown = _G[self:GetName().."Countdown"..idx];
			if countdown then
				countdown:SetMinMaxValues(0, duration);
				countdown:SetValue(timeleft);
			end
			if timeleft == 0 then
				FloLib_ResetTimer(self, idx);
			end
		end
	end
end

function FloTotemBar_CheckTrapLife(self, spellIdx, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, ...)

	local spell = self.spells[spellIdx];
	local name = string.upper(spell.name);

	_, _, spellTexture = GetSpellInfo(spell.id);
	-- bad french localisation
	if spellName == "Effet Piège immolation" then spellName = "Effet Piège d'immolation" end

	if event ~= nil and strsub(event, 1, 5) == "SPELL" and event ~= "SPELL_CAST_SUCCESS" and event ~= "SPELL_CREATE" and (spell.texture == spellTexture or string.find(string.upper(spellName), name, 1, true)) and destGUID ~= "" then
		if CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MINE) then
			FloLib_ResetTimer(self, spellIdx);
		else
			FloTotemBar_TimerRed(self, spellIdx);
		end
	end
end

-- For old Serpent Trap I think
function FloTotemBar_CheckTrap2Life(self, spellIdx, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, ...)

	local spell = self.spells[spellIdx];
	local name = string.upper(spell.name);
	local COMBATLOG_FILTER_MY_GUARDIAN = bit.bor(
		COMBATLOG_OBJECT_AFFILIATION_MINE,
		COMBATLOG_OBJECT_REACTION_FRIENDLY,
		COMBATLOG_OBJECT_CONTROL_PLAYER,
		COMBATLOG_OBJECT_TYPE_GUARDIAN
		);

	if event ~= nil and strsub(event, 1, 5) == "SWING" and CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MY_GUARDIAN) then
		FloLib_ResetTimer(self, spellIdx);
	end
end

function FloTotemBar_UpdateSeal(self, spellIdx, timestamp, event, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, ...)
	if event == "SPELL_AURA_REMOVED" and CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_MINE) then
		local spell = self.spells[spellIdx];
		if (spell.name == spellName) then
			FloLib_ResetTimer(self, spellIdx);
		end
	end
end

function FloTotemBar_SetupSpell(self, spell, pos)

	local duration, algo, algoIdx, spellName, spellTexture;

        algoIdx = spell.algo;
        spellName = spell.name;
        spellTexture = spell.texture;

	-- Avoid tainting
	if not InCombatLockdown() then
		local name, button, icon;
		name = self:GetName();
		button = _G[name.."Button"..pos];
		icon = _G[name.."Button"..pos.."Icon"];

		button:SetAttribute("type", "spell");
		button:SetAttribute("spell", spell.name);

		icon:SetTexture(spellTexture);
	end

	if FLO_CLASS_NAME == "SHAMAN" then
		algo = FloTotemBar_UpdateTotem;
		duration = spell.duration;
	elseif FLO_CLASS_NAME == "HUNTER" then
		duration = spell.duration or 60;
		algo = ALGO_TRAP[algoIdx];
	elseif FLO_CLASS_NAME == "PALADIN" then
		duration = spell.duration or 30;
		algo = FloTotemBar_UpdateSeal;
	end

	self.spells[pos] = { id = spell.id, name = spellName, addName = spell.addName, duration = duration, algo = algo, talented = spell.talented, talentedName = spell.talentedName };

end

function FloTotemBar_OnSetup(self)

	-- Avoid tainting
	if not InCombatLockdown() then
	        if next(self.spells) == nil then
		        UnregisterStateDriver(self, "visibility")
	        else
		        local stateCondition = "nopetbattle,nooverridebar,novehicleui,nopossessbar"
		        RegisterStateDriver(self, "visibility", "["..stateCondition.."] show; hide")
	        end
        end

	FloTotemBar_ResetTimers(self);
end

function FloTotemBar_UpdatePosition(self)

	-- Avoid tainting when in combat
	if InCombatLockdown() or self == nil then
		return;
	end

	-- non auto positionning
	if not self.settings or self.settings.position ~= "auto" then
		return;
	end

	local layout
	if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
		layout = FLO_TOTEM_LAYOUTS[ACTIVE_OPTIONS.barLayout];
	end

	self:ClearAllPoints();
	if self == FloBarEARTH or self == FloBarTRAP or self == FloBarSEAL then
		local yOffset = 0;
		local yOffset1 = 0;
		local yOffset2 = 0;
		local anchorFrame;

		if not MainMenuBar:IsShown() and not (VehicleMenuBar and VehicleMenuBar:IsShown()) then
			anchorFrame = UIParent;
			yOffset = 110 - UIParent:GetHeight();
		else
			anchorFrame = MainMenuBar;

			if SHOW_MULTI_ACTIONBAR_2 then
				yOffset2 = yOffset2 + 45;
			end

			if SHOW_MULTI_ACTIONBAR_1 then
				yOffset1 = yOffset1 + 45;
			end
		end

		if FLO_CLASS_NAME == "HUNTER" then
            if FloAspectBar ~= nil then
                self:SetPoint("LEFT", FloAspectBar, "RIGHT", 10/ACTIVE_OPTIONS.scale, 0);
            else
			    self:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 512/ACTIVE_OPTIONS.scale, (yOffset + yOffset2)/ACTIVE_OPTIONS.scale);
            end
		elseif FLO_CLASS_NAME == "PALADIN" then
			self:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 320/ACTIVE_OPTIONS.scale, (yOffset + yOffset1)/ACTIVE_OPTIONS.scale);
		else
			if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
				self:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 464, (yOffset + yOffset1)/ACTIVE_OPTIONS.scale);
			elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
				local finalOffset = layout.offset * self:GetHeight();
				self:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 164, (yOffset + yOffset1)/ACTIVE_OPTIONS.scale + finalOffset);
			end
		end

	elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC and FLO_CLASS_NAME == "SHAMAN" then
		self:SetPoint(unpack(layout[self:GetName()]));
	end
end

function FloTotemBar_UpdatePositions()

	local k, j;
	-- Avoid tainting when in combat
	if InCombatLockdown() then
		return;
	end

	for k, v in pairs(ACTIVE_OPTIONS.barSettings) do
		if v.position == "auto" then
			FloTotemBar_UpdatePosition(_G["FloBar"..k])
		end
	end
end

function FloTotemBar_SetBarDrag(frame, enable)

	local countdown = _G[frame:GetName().."Countdown"];
	if enable then
		FloLib_ShowBorders(frame);
		frame:RegisterForDrag("LeftButton");
		if countdown then
			countdown:RegisterForDrag("LeftButton");
		end
	else
		if ACTIVE_OPTIONS.borders then
			FloLib_ShowBorders(frame);
		else
			FloLib_HideBorders(frame);
		end
	end
end

function FloTotemBar_SetBorders(self, visible)

	local k, j;
	ACTIVE_OPTIONS.borders = visible;
	for k, v in pairs(ACTIVE_OPTIONS.barSettings) do
		local bar = _G["FloBar"..k];
		if visible or v.position == "unlock" then
			FloLib_ShowBorders(bar);
		else
			FloLib_HideBorders(bar);
		end
	end

end

function FloTotemBar_SetPosition(self, bar, mode)

	local unlocked = (mode == "unlock");

	-- Close all dropdowns
	CloseDropDownMenus();

	if bar.settings then
		local savePoints = bar.settings.position ~= mode;
		bar.settings.position = mode;
		DEFAULT_CHAT_FRAME:AddMessage(bar:GetName().." position "..mode);

		FloTotemBar_SetBarDrag(bar, unlocked);

		if mode == "auto" then
			-- Force the auto positionning
			FloTotemBar_UpdatePosition(bar);
		else
			-- Force the game to remember position
			bar:StartMoving();
			bar:StopMovingOrSizing();
			if savePoints then
				bar.settings.refPoint = { bar:GetPoint() };
			end
		end
	end
end

function FloTotemBar_SetLayoutMenu()

	local i;
	-- Add the possible values to the menu
	for i = 1, #FLO_TOTEM_LAYOUTS_ORDER do
		local value = FLO_TOTEM_LAYOUTS_ORDER[i];
		local info = UIDropDownMenu_CreateInfo();
		info.text = FLO_TOTEM_LAYOUTS[value].label;
		info.value = value;
		info.func = FloTotemBar_SetLayout;
		info.arg1 = value;

		if value == ACTIVE_OPTIONS.barLayout then
			info.checked = 1;
		end
		UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
	end

end

function FloTotemBar_SetLayout(self, layout)

	-- Close all dropdowns
	CloseDropDownMenus();

	ACTIVE_OPTIONS.barLayout = layout;
	FloTotemBar_UpdatePositions();
end

function FloTotemBar_SetScale(scale)

	local i, v;
	scale = tonumber(scale);
	if not scale or scale <= 0 then
		DEFAULT_CHAT_FRAME:AddMessage( "FloTotemBar : scale must be >0 ("..scale..")" );
		return;
	end

	local setPoints = ACTIVE_OPTIONS.scale ~= scale;
	ACTIVE_OPTIONS.scale = scale;

	for i, v in ipairs({FloBarTRAP, FloBarEARTH}) do
		local p, a, rp, ox, oy = v:GetPoint();
		local os = v:GetScale();
		v:SetScale(scale);
		if setPoints and p and (a == nil or a == UIParent or a == MainMenuBar) then
			v:SetPoint(p, a, rp, ox*os/scale, oy*os/scale);
		end
	end
	FloTotemBar_UpdatePositions();

end

function FloTotemBar_ResetTimers(self)

        local i;
        for i = 1, 10 do
	        self["startTime"..i] = 0;
        end
	FloLib_OnUpdate(self);
end

function FloTotemBar_TimerRed(self, school)

	local countdown = _G[self:GetName().."Countdown"..school];
	if countdown then
		countdown:SetStatusBarColor(0.5, 0.5, 0.5);
	end

end

function FloTotemBar_OnEnter(self)
	FloLib_Button_SetTooltip(self);
end

function FloTotemBar_OnLeave(self)
	GameTooltip:Hide();
end

