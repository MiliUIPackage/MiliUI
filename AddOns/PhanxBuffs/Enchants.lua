--[[--------------------------------------------------------------------
	PhanxBuffs
	Replacement player buff, debuff, and temporary enchant frames.
	Copyright (c) 2010-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/PhanxBuffs
	http://mods.curse.com/addons/wow/phanxbuffs
	http://www.wowinterface.com/downloads/info16874-PhanxBuffs.html
----------------------------------------------------------------------]]

local PhanxTempEnchantFrame = CreateFrame("Frame", "PhanxTempEnchantFrame", UIParent)

local _, ns = ...
local GetFontFile = ns.GetFontFile
local L = ns.L

local db
local dirty, bagsDirty, spellsDirty, inVehicle

local enchants = {}

local MAIN_HAND_SLOT = GetInventorySlotInfo("MainHandSlot")
local OFF_HAND_SLOT = GetInventorySlotInfo("SecondaryHandSlot")

------------------------------------------------------------------------

local function button_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetInventoryItem("player", self:GetID())
end

local function button_OnLeave()
	GameTooltip:Hide()
end

local function button_OnClick(self)
	local id = self:GetID()
	local button = "TempEnchant" .. (id - 15)
	_G[button]:SetID(id)
	PhanxBuffsCancelButton:SetMacro(self, self.icon:GetTexture(), "/click " .. button .. " RightButton")
end

local buttons = setmetatable({}, { __index = function(t, i)
	local button = ns.CreateAuraIcon(PhanxTempEnchantFrame)
	button:SetWidth(db.buffSize)
	button:SetHeight(db.buffSize)
	button:SetScript("OnEnter", button_OnEnter)
	button:SetScript("OnLeave", button_OnLeave)
	button:SetScript("OnClick", button_OnClick)

	if PhanxBorder then
		button:SetBorderColor(180 / 255, 76 / 255, 1) -- 118 / 255, 47 / 255, 170 / 255)
	else
		button.border = button:CreateTexture(nil, "BORDER")
		button.border:SetPoint("TOPLEFT", button, -2, 2)
		button.border:SetPoint("BOTTOMRIGHT", button, 2, -2)
		button.border:SetTexture("Interface\\Buttons\\UI-TempEnchant-Border")
	end

	t[i] = button
	PhanxTempEnchantFrame:UpdateLayout()
	return button
end })

PhanxTempEnchantFrame.buttons = buttons

------------------------------------------------------------------------

function PhanxTempEnchantFrame:UpdateLayout()
	local anchorH = db.buffAnchorH
	local anchorV = db.buffAnchorV
	local size = db.buffSize
	local spacing = db.buffSpacing

	local fontFace = GetFontFile(db.fontFace)
	local fontScale = db.fontScale
	local fontOutline = db.fontOutline

	for i = 1, #buttons do
		local x = (spacing + size) * (i - 1) * (anchorH == "LEFT" and 1 or -1)

		local button = buttons[i]
		button:ClearAllPoints()
		button:SetPoint(anchorV .. anchorH, self, anchorV .. anchorH, x, 0)
		button:SetWidth(size)
		button:SetHeight(size)

		button.count:SetFont(fontFace, 18 * fontScale, fontOutline)
		button.timer:SetFont(fontFace, 14 * fontScale, fontOutline)

		if fontOutline == "THICKOUTLINE" then
			button.count:SetPoint("CENTER", button, "TOP", 2, -1)
			button.timer:SetPoint("TOP", button, "BOTTOM", 2, -1)
		elseif fontOutline == "OUTLINE" then
			button.count:SetPoint("CENTER", button, "TOP", 1, 0)
			button.timer:SetPoint("TOP", button, "BOTTOM", 1, 0)
		else
			button.count:SetPoint("CENTER", button, "TOP", 0, 0)
			button.timer:SetPoint("TOP", button, "BOTTOM", 0, 0)
		end
	end

	self:ClearAllPoints()
	self:SetPoint(anchorV .. anchorH, PhanxBuffFrame, anchorV .. anchorH, 0, 0)
	self:SetWidth((size * 2) + spacing)
	self:SetHeight(size)
end

------------------------------------------------------------------------

function PhanxTempEnchantFrame:Update()
	local mainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID,
		offHandEnchant, offHandExpiration, offHandCharges, offHandEnchantID = GetWeaponEnchantInfo()

	local numEnchants = 0

	if mainHandEnchant then
		numEnchants = numEnchants + 1

		local button = buttons[numEnchants]
		button.expires = GetTime() + (mainHandExpiration / 1000)
		button.icon:SetTexture(GetInventoryItemTexture("player", MAIN_HAND_SLOT))
		button.count:SetText(mainHandCharges > 0 and mainHandCharges or nil)
		button:SetID(MAIN_HAND_SLOT)
		button:Show()
	end

	if offHandEnchant then
		numEnchants = numEnchants + 1

		local b = buttons[numEnchants]
		b.expires = GetTime() + (offHandExpiration / 1000)
		b.icon:SetTexture(GetInventoryItemTexture("player", OFF_HAND_SLOT))
		b.count:SetText(offHandCharges > 0 and offHandCharges or nil)
		b:SetID(OFF_HAND_SLOT)
		b:Show()
	end

	if #buttons > numEnchants then
		for i = numEnchants + 1, #buttons do
			local f = buttons[i]
			f.icon:SetTexture()
			f.count:SetText()
			f.expires = nil
			f:Hide()
		end
	end

	self.numEnchants = numEnchants
	PhanxBuffFrame:UpdateLayout()
end

------------------------------------------------------------------------

local timerGroup = PhanxTempEnchantFrame:CreateAnimationGroup()
local timer = timerGroup:CreateAnimation()
timer:SetOrder(1)
timer:SetDuration(0.1) -- how often you want it to finish
-- timer:SetMaxFramerate(25) -- use this to throttle
timerGroup:SetScript("OnFinished", function(self, requested)
	if dirty then
		PhanxTempEnchantFrame:Update()
		dirty = false
	end
	for i = 1, #buttons do
		local button = buttons[i]
		if not button:IsShown() then break end
		if button.expires and button.expires > 0 then
			local remaining = button.expires - GetTime()
			if remaining < 0 then
				dirty = true
			elseif remaining <= db.maxTimer then
				if remaining > 3600 then
					button.timer:SetFormattedText(MINUTE_ONELETTER_ABBR, floor((remaining / 60) + 0.5))
				elseif remaining > 60 then
					button.timer:SetFormattedText(MINUTE_ONELETTER_ABBR, floor((remaining / 60) + 0.5))
				else
					button.timer:SetText(floor(remaining + 0.5))
				end
			else
				button.timer:SetText()
			end
		else
			button.timer:SetText()
		end
	end
	self:Play() -- start it over again
end)

------------------------------------------------------------------------

function PhanxTempEnchantFrame:BAG_UPDATE()
	bagsDirty = true
end

function PhanxTempEnchantFrame:SPELLS_CHANGED()
	spellsDirty = true
end

function PhanxTempEnchantFrame:UNIT_INVENTORY_CHANGED(unit)
	dirty = true
end

function PhanxTempEnchantFrame:UNIT_ENTERED_VEHICLE(unit)
	if UnitHasVehicleUI(unit) then
		inVehicle = true
		self:Hide()
		PhanxBuffFrame.buttons[1]:SetPoint(db.buffAnchorV .. db.buffAnchorH, PhanxBuffFrame)
	end
end

function PhanxTempEnchantFrame:UNIT_EXITED_VEHICLE(unit)
	inVehicle = nil
	dirty = true
	self:Show()
end

function PhanxTempEnchantFrame:PET_BATTLE_OPENING_START()
	self:Hide()
end

function PhanxTempEnchantFrame:PET_BATTLE_CLOSE()
	dirty = true
	self:Show()
end

function PhanxTempEnchantFrame:PLAYER_ENTERING_WORLD()
	local inVehicleNow = UnitHasVehicleUI("player")
	if inVehicle and not inVehicleNow then
		return self:UNIT_EXITED_VEHICLE("player")
	elseif inVehicleNow and not inVehicle then
		return self:UNIT_ENTERED_VEHICLE("player")
	end
	dirty = true
end

PhanxTempEnchantFrame:SetScript("OnEvent", function(self, event, unit)
	return self[event] and self[event](self, unit)
end)

------------------------------------------------------------------------

function PhanxTempEnchantFrame:Load()
	if db then return end

	db = PhanxBuffsDB

	self:PLAYER_ENTERING_WORLD()

	dirty = true
	timerGroup:Play()

	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("SPELLS_CHANGED")
	self:RegisterEvent("PET_BATTLE_OPENING_START")
	self:RegisterEvent("PET_BATTLE_CLOSE")
	self:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
	self:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
	self:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
end
