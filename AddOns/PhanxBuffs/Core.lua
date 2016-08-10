--[[--------------------------------------------------------------------
	PhanxBuffs
	Replacement player buff, debuff, and temporary enchant frames.
	Copyright (c) 2010-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/PhanxBuffs
	http://mods.curse.com/addons/wow/phanxbuffs
	http://www.wowinterface.com/downloads/info16874-PhanxBuffs.html
----------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local L = ns.L
local db

local defaultDB = {
	buffAnchorH = "RIGHT",
	buffAnchorV = "TOP",
	buffColumns = 20,
	buffSize    = 36,
	buffSpacing = 6,

	debuffAnchorH = "RIGHT",
	debuffAnchorV = "TOP",
	debuffColumns = 10,
	debuffSize    = 48,
	debuffSpacing = 3,

	fontFace    = "Arial Narrow",
	fontOutline = "OUTLINE",
	fontScale   = 1,

	maxTimer = 7200,

	showBuffSources = false,

	minimapIcon = {},
}

local defaultIgnore = {
	buffs = {},
	debuffs = {},
}

------------------------------------------------------------------------

local Media = LibStub("LibSharedMedia-3.0")

ns.COUNT_SIZE  = 18
ns.TIMER_SIZE  = 14
ns.SYMBOL_SIZE = 16

------------------------------------------------------------------------

local tablePool = {}

local function newTable()
	local t = next(tablePool) or {}
	tablePool[t] = nil
	return t
end

local function remTable(t)
	if type(t) == "table" then
		tablePool[wipe(t)] = true
	end
end

ns.newTable = newTable
ns.remTable = remTable

------------------------------------------------------------------------

local function GetFontFile(name)
	return Media:Fetch("font", name)
end
ns.GetFontFile = GetFontFile

local function SetButtonFonts(parent, face, outline)
	if not face then face = db.fontFace end
	if not outline then outline = db.fontOutline end

	local file = Media:Fetch("font", face)
	local scale = db.fontScale

	for i = 1, #parent.buttons do
		local button = parent.buttons[i]
		button.count:SetFont(file, ns.COUNT_SIZE * scale, outline)
		button.timer:SetFont(file, ns.TIMER_SIZE * scale, outline)
		if button.symbol then
			button.symbol:SetFont(file, ns.SYMBOL_SIZE * scale, outline)
		end
	end
end
ns.SetButtonFonts = SetButtonFonts

------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		local function initDB(db, defaults)
			if type(db) ~= "table" then db = {} end
			if type(defaults) ~= "table" then return db end
			for k, v in pairs(defaults) do
				if type(v) == "table" then
					db[k] = initDB(db[k], v)
				elseif type(v) ~= type(db[k]) then
					db[k] = v
				end
			end
			return db
		end

		PhanxBuffsDB = initDB(PhanxBuffsDB, defaultDB)
		db = PhanxBuffsDB

		local LDB = LibStub("LibDataBroker-1.1", true)
		if LDB then
			LDB:NewDataObject(ADDON_NAME, {
				type = "launcher",
				icon = "Interface\\Icons\\Ability_Warrior_ShieldMastery",
				OnTooltipShow = function(tooltip)
					tooltip:AddLine(ADDON_NAME, 1, 1, 1)
					tooltip:AddLine(L["Click to lock or unlock the frames."])
					tooltip:AddLine(L["Right-click for options."])
					tooltip:Show()
				end,
				OnClick = function(_, button)
					if button == "RightButton" then
						-- double up to work around Blizz bug
						InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
						InterfaceOptionsFrame_OpenToCategory(ns.optionsPanel)
					else
						ns.ToggleFrameLocks()
					end
				end,
			})
		end

		PhanxBuffsIgnoreDB = initDB(PhanxBuffsIgnoreDB, defaultIgnore)

		local function MediaCallback(callbackName, mediaType, mediaName)
			if mediaType == "font" then
				SetButtonFonts(PhanxBuffFrame)
				SetButtonFonts(PhanxDebuffFrame)
				SetButtonFonts(PhanxTempEnchantFrame)
			end
		end
		Media.RegisterCallback(self, "LibSharedMedia_Registered", MediaCallback)
		Media.RegisterCallback(self, "LibSharedMedia_SetGlobal", MediaCallback)
		MediaCallback(event, "font")

		BuffFrame:Hide()
		TemporaryEnchantFrame:Hide()
		BuffFrame:UnregisterAllEvents()

		PhanxBuffFrame:Load()
		PhanxDebuffFrame:Load()
		PhanxTempEnchantFrame:Load()

		self:UnregisterAllEvents()
		self:RegisterEvent("PLAYER_LOGOUT")
	else
		local function cleanDB(db, defaults)
			if type(db) ~= "table" then return {} end
			if type(defaults) ~= "table" then return db end
			for k, v in pairs(db) do
				if type(v) == "table" then
					if not next(cleanDB(v, defaults[k])) then
						db[k] = nil
					end
				elseif v == defaults[k] then
					db[k] = nil
				end
			end
			return db
		end
		PhanxBuffsDB = cleanDB(PhanxBuffsDB, defaultDB)
	end
end)

------------------------------------------------------------------------

local cancelButton = CreateFrame("Button", "PhanxBuffsCancelButton", UIParent, "SecureActionButtonTemplate")
cancelButton:SetPoint("CENTER")
cancelButton:SetSize(64, 64)
cancelButton:Hide()

function cancelButton:Setup()
	self:RegisterForClicks("RightButtonUp")
	self:SetAttribute("unit", "player")
	self:SetAttribute("type2", "macro")

	self.overlay = self:CreateTexture(nil, "BACKGROUND")
	self.overlay:SetAllPoints(true)
	self.overlay:SetTexture(1, 0, 0, 0.5)
	self.overlay:Hide()

	self:SetScript("PreClick", function(self, button)
		self.owner:Click(button)
	end)
	
	self:SetScript("PostClick", function(self, button)
		return not InCombatLockdown() and self:Hide()
	end)

	self.Setup = nil
end

function cancelButton:SetMacro(button, macro)
	if InCombatLockdown() then return end
	if self.Setup then self:Setup() end

	self:ClearAllPoints()
	self:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
	self:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
	self:SetFrameLevel(100)

	self.owner = button
	self:SetAttribute("macrotext2", "/stopmacro [mod:alt,mod:shift]\n" .. macro)

	self:Show()
end

cancelButton:SetScript("OnHide", function(self)
	self:ClearAllPoints()
	self:SetPoint("CENTER", UIParent, 0, 0)
	if self.owner then
		self.owner:GetScript(self.owner:IsMouseOver() and "OnEnter" or "OnLeave")(self.owner)
	end
	self.owner = nil
end)

cancelButton:SetScript("OnEnter", function(self)
	if not self.owner then
		return self:Hide()
	end
	return self.owner:GetScript("OnEnter")(self.owner)
end)

cancelButton:SetScript("OnLeave", function(self)
	self:Hide()
end)

cancelButton:RegisterEvent("PLAYER_REGEN_DISABLED")
cancelButton:SetScript("OnEvent", function(self)
	if not InCombatLockdown() then
		self:Hide()
	end
end)

------------------------------------------------------------------------

function ns.CreateAuraIcon(parent)
	local button = CreateFrame("Button", nil, parent)
	button:EnableMouse(true)
	button:RegisterForClicks("RightButtonUp")
	button:Hide()

	button.icon = button:CreateTexture(nil, "BACKGROUND")
	button.icon:SetAllPoints(button)

	button.count = button:CreateFontString(nil, "OVERLAY")
	button.count:SetPoint("CENTER", button, "TOP")
	button.count:SetShadowOffset(1, -1)

	button.timer = button:CreateFontString(nil, "OVERLAY")
	button.timer:SetPoint("TOP", button, "BOTTOM")
	button.timer:SetShadowOffset(1, -1)

	local file, scale, outline = GetFontFile(), db.fontScale, db.fontOutline
	button.count:SetFont(file, ns.COUNT_SIZE * scale, outline)
	button.timer:SetFont(file, ns.TIMER_SIZE * scale, outline)

	if PhanxBorder and (db.noMasque or not LibStub("Masque", true)) then
		PhanxBorder.AddBorder(button)
		button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	end

	return button
end

------------------------------------------------------------------------

do
	local dragBackdrop = {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background"
	}

	local function OnDragStart(self)
		self:StartMoving()
	end

	local function OnDragStop(self)
		self:StopMovingOrSizing()

		local w, h, x, y = UIParent:GetWidth(), UIParent:GetHeight(), self:GetCenter()
		w, h, x, y = floor(w + 0.5), floor(h + 0.5), floor(x + 0.5), floor(y + 0.5)
		local hhalf, vhalf = (x > w / 2) and "RIGHT" or "LEFT", (y > h / 2) and "TOP" or "BOTTOM"
		local dx = hhalf == "RIGHT" and floor(self:GetRight() + 0.5) - w or floor(self:GetLeft() + 0.5)
		local dy = vhalf == "TOP" and floor(self:GetTop() + 0.5) - h or floor(self:GetBottom() + 0.5)

		if self:GetName() == "PhanxDebuffFrame" then
			db.debuffPoint, db.debuffX, db.debuffY = vhalf..hhalf, dx, dy
		else
			db.buffPoint, db.buffX, db.buffY = vhalf..hhalf, dx, dy
		end

		self:ClearAllPoints()
		self:SetPoint(vhalf..hhalf, UIParent, dx, dy)
	end

	local isLocked = true

	function ns.ToggleFrameLocks(lock)
		if lock == nil then
			lock = not isLocked
		end

		PhanxBuffFrame:UpdateLayout()
		PhanxDebuffFrame:UpdateLayout()

		if lock then
			PhanxBuffFrame:SetBackdrop(nil)
			PhanxBuffFrame:SetMovable(false)
			PhanxBuffFrame:SetScript("OnDragStart", nil)
			PhanxBuffFrame:SetScript("OnDragStop", nil)
			PhanxBuffFrame:EnableMouse(false)
			PhanxBuffFrame:RegisterForDrag(nil)

			PhanxDebuffFrame:SetBackdrop(nil)
			PhanxDebuffFrame:SetMovable(false)
			PhanxDebuffFrame:SetScript("OnDragStart", nil)
			PhanxDebuffFrame:SetScript("OnDragStop", nil)
			PhanxDebuffFrame:EnableMouse(false)
			PhanxDebuffFrame:RegisterForDrag(nil)

			isLocked = true
		else
			PhanxBuffFrame:SetBackdrop(dragBackdrop)
			PhanxBuffFrame:SetBackdropColor(1, 1, 1, 1)
			PhanxBuffFrame:SetClampedToScreen(true)
			PhanxBuffFrame:SetMovable(true)
			PhanxBuffFrame:SetScript("OnDragStart", OnDragStart)
			PhanxBuffFrame:SetScript("OnDragStop", OnDragStop)
			PhanxBuffFrame:EnableMouse(true)
			PhanxBuffFrame:RegisterForDrag("LeftButton")

			PhanxDebuffFrame:SetBackdrop(dragBackdrop)
			PhanxDebuffFrame:SetBackdropColor(1, 1, 1, 1)
			PhanxDebuffFrame:SetClampedToScreen(true)
			PhanxDebuffFrame:SetMovable(true)
			PhanxDebuffFrame:SetScript("OnDragStart", OnDragStart)
			PhanxDebuffFrame:SetScript("OnDragStop", OnDragStop)
			PhanxDebuffFrame:EnableMouse(true)
			PhanxDebuffFrame:RegisterForDrag("LeftButton")

			isLocked = false
		end
	end
end
