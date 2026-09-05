--
-- Masque Blizzard Bars
-- Enables Masque to skin the built-in WoW action bars
--
-- Copyright 2022 - 2026 SimGuy
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.
--

local AddonName, Shared = ...

-- From Locales/Locales.lua
-- Not used yet
--local L = Shared.Locale

-- From Metadata.lua
local Metadata = Shared.Metadata
local Groups = Metadata.Groups
-- Not used yet
--local Callbacks = Metadata.OptionCallbacks

-- From Core.lua
local Core = Shared.Core

-- Push us into shared object
local Addon = {}
Shared.Addon = Addon

local SkinnedKey = "_"..AddonName.."Skinned"

local AddonRestrictions = false

-- Handle events for buttons that get created dynamically by Blizzard
function Addon:HandleEvent(event)
	-- Handle ExtraActionButton on Extra ActionBar updates
	--
	-- We don't handle the ZAB here because if EAB and ZAB are both
	-- active, the ZAB will get added after the event fires and get
	-- missed.
	if event == "UPDATE_EXTRA_ACTIONBAR" then
		local bar = Groups.ExtraAbilityContainer
		local eab = ExtraActionButton1

		-- Make sure the EAB exists and hasn't already been added
		if not bar.State.ExtraActionButton and eab and
		   eab:GetObjectType() == "CheckButton" then
			-- TODO: Update this to use Core:Skin()
			bar.Group:AddButton(eab, nil, "Action")
			bar.State.ExtraActionButton = true
			-- Move the overlay art behind the Normal frame
			if eab.style then
				eab.style:SetDrawLayer("ARTWORK", -1)
			end
		end

	-- Handle Pet Battle Buttons on Pet Battle start
	elseif event == "PET_BATTLE_OPENING_START" then
		local bar = Groups.PetBattleFrame
		local pbf = _G["PetBattleFrame"]["BottomFrame"]

		-- Find the Pet Battle Frame children that are buttons
		-- but only skin the ones that haven't already been seen
		for i = 1, select("#", pbf:GetChildren()) do
			local pbb = select(i, pbf:GetChildren())
			if type(pbb) == "table" and pbb.GetObjectType then
				local name = pbb:GetDebugName()
				local obj = pbb:GetObjectType()
				if bar.State.PetBattleButton[name] ~= pbb and
				   (obj == "CheckButton" or obj == "Button") then
					-- TODO: Update this to use Core:Skin()
					-- Define the regions for this weird button
					local pbbRegions = {
						Icon = pbb.Icon,
						Count = pbb.Count,
						Cooldown = nil, -- These buttons have no cooldown frame
						Normal = pbb.NormalTexture,
						Highlight = pbb:GetHighlightTexture()
					}
					bar.Group:AddButton(pbb, pbbRegions)
					bar.State.PetBattleButton[name] = pbb
				end
			end
		end
	end
end

-- Spell Flyout buttons are created as needed when a flyout is opened, so
-- check for any new buttons any time that happens
function Addon:SpellFlyout_Toggle(_, flyoutID)
	local _, _, numSlots, _ = GetFlyoutInfo(flyoutID)
	local activeSlots = 0
        for slot = 1, numSlots do
		local _, _, isKnown, _, _ = GetFlyoutSlotInfo(flyoutID, slot)
		if (isKnown) then
			activeSlots = activeSlots + 1
		end
	end

	-- Skin any extra buttons found
	local bar = Groups.SpellFlyout
	local numButtons = bar.Buttons.SpellFlyoutPopupButton
        if (numButtons < activeSlots) then
		bar.Buttons.SpellFlyoutPopupButton = activeSlots
		Core:Skin(bar.Buttons, bar.Group)
	end
end

-- This helper gets attached to BuffBarCooldownViewer to return a table of icon frames
-- This is needed because we can't give Masque the top level frame or it will stretch
-- the icon across the whole thing.
function Addon:Helper_BuffBar_GetItemIconFrames()
	if not self.itemFramePool then return end
	local icons = {}
	for frame in self.itemFramePool:EnumerateActive() do
		table.insert(icons, frame.Icon)
	end
	return icons
end

-- This is called as a PreHookFunction from the HookFunction to set up the frame so Masque understands it.
-- We also set up some hooks we will need for later, especially one to handle the dispel coloring, and for
-- masking the out of range overlay to fit the icon.
function Addon:PreHook_CooldownViewer()
	local frameName = self:GetName()
	if frameName and Groups[frameName] and Groups[frameName].Buttons[frameName] then
		for frame in self.itemFramePool:EnumerateActive() do
			-- Assume the iconParent is the same as the frame to start
			-- We're going to put all elements that Masque needs to see in iconParent directly
			local iconParent = frame

			-- Buff Bars - Icon is nested on Icon, so map iconParent to frame.Icon,
			--             then Map Count to Applications
			if frame.Icon.Icon then
				iconParent = frame.Icon
				if not iconParent.Count then
					iconParent.Count = iconParent.Applications
				end
			end

			-- Cooldowns - Map Count to ChargeCount.Current
			if frame.ChargeCount and frame.ChargeCount.Current and not frame.Count then
				frame.Count = frame.ChargeCount.Current
			end

			-- Buff Icons - Map Count to Applications.Applications
			if frame.Applications and frame.Applications.Applications and not frame.Count then
				frame.Count = frame.Applications.Applications
			end

			-- Cooldowns - Handle masking the Out of Range frame
			if frame.OutOfRange and not iconParent[SkinnedKey] then
				frame.OutOfRange:SetDrawLayer('ARTWORK', -1)
				hooksecurefunc(frame, "RefreshIconColor",
				               Addon.CooldownViewerItem_RefreshIconColor)
			end

			-- All - Map IconMask to the Icon's mask texture which helps Masque find it
			if not iconParent.IconMask then
				iconParent.IconMask = iconParent.Icon:GetMaskTexture(1)
			end

			-- All - Map the IconOverlay to a key for easy access to hide or show it later
			if not iconParent.IconOverlay then
				-- There should be one region left that isn't mapped
				for i = 1, select("#", iconParent:GetRegions()) do
					local texture = select(i, iconParent:GetRegions())
					if texture.GetAtlas and texture:GetAtlas() == "UI-HUD-CoolDownManager-IconOverlay" then
						iconParent.IconOverlay = texture
					end
				end
			end

			-- Some CDM addons like BCDM change the size of the icons, let's reskin the icons when this happens
			if not iconParent[SkinnedKey] then
				hooksecurefunc(iconParent, "SetSize", Addon.CooldownViewerItem_SetSize)
			end

			local groupDisabled = Groups[frameName].Group.db.Disabled

			-- Show the IconOverlay only if this group isn't enabled
			if iconParent.IconOverlay then
				iconParent.IconOverlay:SetShown(groupDisabled)
			end
		end

	end
end

-- If something calls SetSize() on a CDM button we need to call ReSkin() or the button won't look right
function Addon:CooldownViewerItem_SetSize()
	if AddonRestrictions or InCombatLockdown() then return end
	local parent = self:GetParent()
	if parent then
		local frameName = parent:GetName()
		if Groups[frameName] then
			Groups[frameName].Group:ReSkin(self)
		end
	end
end

-- Handle the out of range texture if it exists
function Addon:CooldownViewerItem_RefreshIconColor()
	local frame = self
	if frame and frame.OutOfRange then
		local frameName = frame:GetParent():GetName()
		if frameName and Groups[frameName] then
			local groupDisabled = Groups[frameName].Group.db.Disabled
			local iconMask = frame.Icon:GetMaskTexture(1)
			if frame._MBB_OOR_Mask then
				local OORMask = frame.OutOfRange:GetMaskTexture(frame._MBB_OOR_Mask)
				if groupDisabled or iconMask ~= OORMask then
					frame.OutOfRange:RemoveMaskTexture(OORMask)
					frame._MBB_OOR_Mask = nil
				end
			end
			if not groupDisabled and not frame._MBB_OOR_Mask then
				if iconMask then
					frame.OutOfRange:AddMaskTexture(iconMask)
					frame._MBB_OOR_Mask = frame.OutOfRange:GetNumMaskTextures()
				end
			end
		end
	end
end

-- Attempt to adopt the ZoneAbilityButton, which has no name, when Blizzard
-- tries to update the displayed buttons. We do this here because when
-- UPDATE_EXTRA_ACTIONBAR is fired and both EAB and ZAB are active, it will
-- fire too early, the ZAB won't exist, and we'll miss it completely.
function Addon:ZoneAbilityFrame_UpdateDisplayedZoneAbilities()
	local zac = ZoneAbilityFrame.SpellButtonContainer
	local bar = Groups.ExtraAbilityContainer

	for i = 1, select("#", zac:GetChildren()) do
		local zab = select(i, zac:GetChildren())

		-- Try not to add buttons that are already added
		--
		-- I'm not sure if the Frame created for the ZAB is used for
		-- the whole life of the UI so if the frame changes, we'll
		-- skin whatever replaced it.
		if zab and zab:GetObjectType() == "Button" then
			local name = zab:GetDebugName()
			if bar.State.ZoneAbilityButton[name] ~= zab then

				-- TODO: Update this to use Core:Skin()
				-- Define the regions for this weird button
				local zabRegions = {
					Icon = zab.Icon,
					Count = zab.Count,
					Cooldown = zab.Cooldown,
					Normal = zab.NormalTexture,
					Highlight = zab:GetHighlightTexture()
				}

				bar.Group:AddButton(zab, zabRegions, "Action")
				bar.State.ZoneAbilityButton[name] = zab
			end
		end
	end
end

function Addon:HandleEvent(event, _, state)
	if event == "ADDON_RESTRICTION_STATE_CHANGED" then
		if state == 0 then
			AddonRestrictions = false
		else
			AddonRestrictions = true
		end
	end
end

-- These are init steps specific to this addon
-- This should be run before Core:Init()
function Addon:Init()
	-- Hook for Addon Restrictions
	if Core:CheckVersion({ 120000, nil }) then
		Addon.Events = CreateFrame("Frame")
		Addon.Events:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
		Addon.Events:SetScript("OnEvent", Addon.HandleEvent)
	end

	-- Spell Flyout
	if Core:CheckVersion({ 70003, nil }) then
		hooksecurefunc(SpellFlyout, "Toggle",
		               Addon.SpellFlyout_Toggle)
	end

	-- Cooldown Manager hook setup
	if Core:CheckVersion({ 110105, nil }) then
		Groups.BuffBarCooldownViewer.PreHookFunction   = Addon.PreHook_CooldownViewer
		Groups.BuffIconCooldownViewer.PreHookFunction  = Addon.PreHook_CooldownViewer
		Groups.EssentialCooldownViewer.PreHookFunction = Addon.PreHook_CooldownViewer
		Groups.UtilityCooldownViewer.PreHookFunction   = Addon.PreHook_CooldownViewer
		BuffBarCooldownViewer.GetItemIconFrames = Addon.Helper_BuffBar_GetItemIconFrames
	end

	-- Zone Ability Buttons
	-- This may be DraenorZoneAbilityFrame_Update if Classic reaches WoD
	-- This may be ZoneAbilityFrame_Update if Classic reaches Legion
	if Core:CheckVersion({ 90001, nil }) then
		hooksecurefunc(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities",
		               Addon.ZoneAbilityFrame_UpdateDisplayedZoneAbilities)
	end

	Addon.Events = CreateFrame("Frame")

	-- Extra Action Button
	if Core:CheckVersion({ 40402, nil }) then
		Addon.Events:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
	end

	-- Pet Battles
	if Core:CheckVersion({ 50004, nil }) then
		Addon.Events:RegisterEvent("PET_BATTLE_OPENING_START")
	end

	Addon.Events:SetScript("OnEvent", Addon.HandleEvent)

	if Core:CheckVersion({ 100000, nil }) then
		-- Empty the whole options table because we have no options yet
		Metadata.Options = nil
	else
		-- Empty the whole options table because we don't support it on Classic
		Metadata.Options = nil
	end
end

Addon:Init()
Core:Init()
