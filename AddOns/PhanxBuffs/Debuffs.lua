--[[--------------------------------------------------------------------
	PhanxBuffs
	Replacement player buff, debuff, and temporary enchant frames.
	Copyright (c) 2010-2016 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/Phanx/PhanxBuffs
	http://mods.curse.com/addons/wow/phanxbuffs
	http://www.wowinterface.com/downloads/info16874-PhanxBuffs.html
----------------------------------------------------------------------]]

local PhanxDebuffFrame = CreateFrame("Frame", "PhanxDebuffFrame", UIParent)

local _, ns = ...
local newTable = ns.newTable
local remTable = ns.remTable
local GetFontFile = ns.GetFontFile

local db, ignore

local debuffUnit = "player"
local debuffs = {}

local ceil, floor, next, pairs, sort, tremove, type = math.ceil, math.floor, next, pairs, table.sort, table.remove, type -- Lua
local UnitAura = UnitAura -- WoW
local DebuffTypeSymbol = DebuffTypeSymbol -- FrameXML

local DebuffTypeColor = {
	["Curse"]	= { 0.6, 0.0, 1 },
	["Disease"]	= { 0.6, 0.4, 0 },
	["Magic"]	= { 0.2, 0.6, 1 },
	["Poison"]	= { 0.0, 0.6, 0 },
}

local GetDispelMacro
do--[=[
	local _, class = UnitClass("player")
	if class == "DRUID" then
		local macro = "/cast [@player] " .. (GetSpellInfo(2782)) -- Remove Corruption
		GetDispelMacro = function(kind)
			if kind == "Curse" or kind == "Poison" or (kind == "Magic" and GetSpecialization() == 4 and UnitLevel("player") >= 22) then
				return macro
			end
		end
	elseif class == "MONK" then
		local macro = "/cast [@player] " .. (GetSpellInfo(115450)) -- Detox
		GetDispelMacro = function(kind)
			if kind == "Disease" or kind == "Poison" or (kind == "Magic" and GetSpecialization() == 2 and UnitLevel("player") >= 20) then
				return macro
			end
		end
	elseif class == "PALADIN" then
		local macro = "/cast [@player] " .. (GetSpellInfo(4987)) -- Cleanse
		GetDispelMacro = function(kind)
			if kind == "Disease" or kind == "Poison" or (kind == "Magic" and GetSpecialization() == 1 and UnitLevel("player") >= 20) then
				return macro
			end
		end
	elseif class == "PRIEST" then
		local macro = "/cast [@player] " .. (GetSpellInfo(527)) -- Purify
		GetDispelMacro = function(kind)
			if (kind == "Disease" or kind == "Magic") and (GetSpecialization() == 2 and level >= 22) then
				return macro
			end
		end
	elseif class == "SHAMAN" then
		local macro = "/cast [@player] " .. (GetSpellInfo(51886)) -- Cleanse Spirit
		GetDispelMacro = function(kind)
			if kind == "Curse" or (kind == "Magic" and GetSpecialization() == 3 and UnitLevel("player") >= 18) then
				return macro
			end
		end
	end]=]
end

------------------------------------------------------------------------

local function button_OnEnter(self)
	local debuff = debuffs[self:GetID()]
	if not debuff then return end

	GameTooltip:SetOwner(self, "ANCHOR_" .. (db.buffAnchorV == "TOP" and "BOTTOM" or "TOP") .. (db.buffAnchorH == "RIGHT" and "LEFT" or "RIGHT"))
	GameTooltip:SetUnitAura(debuffUnit, debuff.index, "HARMFUL")

	if not InCombatLockdown() and (PhanxBuffsCancelButton.owner ~= self) then
		local macro = GetDispelMacro and GetDispelMacro(debuff.kind)
		if macro then
			PhanxBuffsCancelButton:SetMacro(self, debuff.icon, macro)
		end
	end
end

local function button_OnLeave()
	GameTooltip:Hide()
	if not InCombatLockdown() then
		PhanxBuffsCancelButton:Hide()
	end
end

local function button_OnClick(self)
	local debuff = debuffs[self:GetID()]
	if debuff and IsAltKeyDown() and IsShiftKeyDown() then
		ignore[debuff.name] = true
		print("|cffffcc00PhanxBuffs:|r", format(ns.L["Now ignoring debuff:"], debuff.name))
		self:GetParent():Update()
	end
end

local function button_SetBorderColor(self, ...)
	return self.border:SetVertexColor(...)
end

local buttons = setmetatable({}, { __index = function(t, i)
	local button = ns.CreateAuraIcon(PhanxDebuffFrame)
	button:SetID(i)
	button:SetWidth(db.debuffSize)
	button:SetHeight(db.debuffSize)
	button:SetScript("OnEnter", button_OnEnter)
	button:SetScript("OnLeave", button_OnLeave)
	button:SetScript("OnClick", button_OnClick)

	button.symbol = button:CreateFontString(nil, "OVERLAY")
	button.symbol:SetPoint("BOTTOMRIGHT", button)
	button.symbol:SetShadowOffset(1, -1)

	local file, scale, outline = GetFontFile(), db.fontScale, db.fontOutline
	button.symbol:SetFont(file, ns.SYMBOL_SIZE * scale, outline)

	if not PhanxBorder or (IsAddOnLoaded("Masque") and not db.noMasque) then
		button.border = button:CreateTexture(nil, "BORDER")
		button.border:SetPoint("TOPLEFT", button, -3, 2)
		button.border:SetPoint("BOTTOMRIGHT", button, 2, -2)
		button.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		button.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		button.SetBorderColor = button_SetBorderColor
	end

	t[i] = button
	PhanxDebuffFrame:UpdateLayout()
	return button
end })

PhanxDebuffFrame.buttons = buttons

------------------------------------------------------------------------

function PhanxDebuffFrame:UpdateLayout()
	local anchorH = db.debuffAnchorH
	local anchorV = db.debuffAnchorV
	local size = db.debuffSize
	local spacing = db.debuffSpacing
	local cols = db.debuffColumns

	local fontFace = GetFontFile(db.fontFace)
	local fontScale = db.fontScale
	local fontOutline = db.fontOutline

	for i = 1, #buttons do
		local button = buttons[i]
		local col = (i - 1) % cols
		local row = ceil(i / cols) - 1

		local x = floor(col * (spacing + size) * (anchorH == "LEFT" and 1 or -1) + 0.5)
		local y = floor(row * (spacing + (size * 1.5)) + 0.5)

		button:ClearAllPoints()
		button:SetSize(size, size)
		button:SetPoint(anchorV .. anchorH, self, anchorV .. anchorH, x, anchorV == "BOTTOM" and y or -y)
		button:SetHitRectInsets(-spacing * 0.5, -spacing * 0.5, -spacing * 0.5, -spacing * 0.5)

		button.count:SetFont(fontFace, 18 * fontScale, fontOutline)
		button.timer:SetFont(fontFace, 14 * fontScale, fontOutline)
		button.symbol:SetFont(fontFace, 16 * fontScale, fontOutline == "THICKOUTLINE" and fontOutline or "OUTLINE")

		if fontOutline == "THICKOUTLINE" then
			button.count:SetPoint("CENTER", button, "TOP", 2, -1)
			button.timer:SetPoint("TOP", button, "BOTTOM", 2, -1)
			button.symbol:SetPoint("BOTTOMRIGHT", 2, 0)
		elseif fontOutline == "OUTLINE" then
			button.count:SetPoint("CENTER", button, "TOP", 1, 0)
			button.timer:SetPoint("TOP", button, "BOTTOM", 1, 0)
			button.symbol:SetPoint("BOTTOMRIGHT", 0, 0)
		else
			button.count:SetPoint("CENTER", button, "TOP", 0, 0)
			button.timer:SetPoint("TOP", button, "BOTTOM", 0, 0)
			button.symbol:SetPoint("BOTTOMRIGHT", 0, 0)
		end
	end

	self:ClearAllPoints()
	if db.debuffPoint and db.debuffX and db.debuffY then
		self:SetPoint(db.debuffPoint, UIParent, db.debuffX, db.debuffY + 0.5)
	else
		self:SetPoint("BOTTOMRIGHT", UIParent, -70 - floor(Minimap:GetWidth() + 0.5), floor(UIParent:GetHeight() + 0.5) - floor(Minimap:GetHeight() + 0.5) - 62)
	end
	self:SetWidth((size * cols) + (spacing * (cols - 1)))
	self:SetHeight(size)
end

------------------------------------------------------------------------

local function DebuffSort(a, b)
	if a and not b then
		return true
	elseif b and not a then
		return false
	elseif a.duration == 0 then
		if b.duration == 0 then
			-- both timeless, sort by name REVERSE
			return a.name < b.name
		else
			-- a timeless, b not
			return true
		end
	else
		if b.duration == 0 then
			-- b timeless, a not
			return false
		else
			-- neither timeless, sort by expiry time
			return a.expires > b.expires
		end
	end
end

------------------------------------------------------------------------

function PhanxDebuffFrame:Update()
	local numDisplayedDebuffs = 0
	for i = 1, 40 do
		local name, _, icon, count, kind, duration, expires, caster, _, _, spellID = UnitAura(debuffUnit, i, "HARMFUL")
		if not icon or icon == "" then
			break
		end

		if not ignore[name] then
			local t = debuffs[i] or newTable()

			t.name = name
			t.icon = icon
			t.count = count
			t.kind = kind
			t.duration = duration or 0
			t.expires = expires
			t.caster = caster
			t.spellID = spellID
			t.index = i

			numDisplayedDebuffs = numDisplayedDebuffs + 1
			debuffs[numDisplayedDebuffs] = t
		end
	end

	for i = numDisplayedDebuffs + 1, #debuffs do
		debuffs[i] = remTable(debuffs[i])
	end

	sort(debuffs, DebuffSort)

	for i = 1, #debuffs do
		local debuff = debuffs[i]
		local f = buttons[i]
		f.icon:SetTexture(debuff.icon)

		if debuff.count > 1 then
			f.count:SetText(debuff.count)
		else
			f.count:SetText()
		end

		local debuffTypeColor = DebuffTypeColor[debuff.kind]
		if debuffTypeColor then
			local r, g, b = debuffTypeColor[1], debuffTypeColor[2], debuffTypeColor[3]
			f:SetBorderColor(r, g, b, 1)
			if ENABLE_COLORBLIND_MODE == "0" then
				f.symbol:Hide()
			else
				f.symbol:Show()
				f.symbol:SetText(DebuffTypeSymbol[debuff.kind])
			end
		else
			f:SetBorderColor(1, 0, 0, 1)
			f.symbol:Hide()
		end

		f:Show()
	end

	if #buttons > #debuffs then
		for i = #debuffs + 1, #buttons do
			local f = buttons[i]
			f.icon:SetTexture()
			f.count:SetText()
			f:Hide()
		end
	end
end

------------------------------------------------------------------------

local dirty
local timerGroup = PhanxDebuffFrame:CreateAnimationGroup()
local timer = timerGroup:CreateAnimation()
timer:SetOrder(1)
timer:SetDuration(0.1) -- how often you want it to finish
-- timer:SetMaxFramerate(25) -- use this to throttle
timerGroup:SetScript("OnFinished", function(self, requested)
	if dirty then
		PhanxDebuffFrame:Update()
		dirty = false
	end
	local maxTimer = db.maxTimer
	for i = 1, #buttons do
		local button = buttons[i]
		if not button:IsShown() then break end
		local debuff = debuffs[button:GetID()]
		if debuff then
			if debuff.expires > 0 then
				local remaining = debuff.expires - GetTime()
				if remaining < 0 then
					-- bugged out, kill it
					remTable(tremove(debuffs, button:GetID()))
					dirty = true
				elseif remaining <= maxTimer then
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
	end
	self:Play() -- start it over again
end)

PhanxDebuffFrame:SetScript("OnEvent", function(self, event, unit)
	if event == "UNIT_AURA" then
		if unit == debuffUnit then
			dirty = true
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if UnitHasVehicleUI("player") then
			buffUnit = "vehicle"
		else
			buffUnit = "player"
		end
		dirty = true
	elseif event == "UNIT_ENTERED_VEHICLE" then
		if UnitHasVehicleUI("player") then
			buffUnit = "vehicle"
		end
		dirty = true
	elseif event == "UNIT_EXITED_VEHICLE" then
		buffUnit = "player"
		dirty = true
	elseif event == "PET_BATTLE_OPENING_START" then
		self:Hide()
	elseif event == "PET_BATTLE_CLOSE" then
		dirty = true
		self:Show()
	end
end)

------------------------------------------------------------------------

function PhanxDebuffFrame:Load()
	if db then return end

	db = PhanxBuffsDB
	ignore = PhanxBuffsIgnoreDB.debuffs

	self:GetScript("OnEvent")(self, "PLAYER_ENTERING_WORLD")

	dirty = true
	timerGroup:Play()

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PET_BATTLE_OPENING_START")
	self:RegisterEvent("PET_BATTLE_CLOSE")
	self:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
	self:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
	self:RegisterUnitEvent("UNIT_AURA", "player", "vehicle")
end
