-- Runes plugin (based on fRunes by Krevlorne [https://github.com/Krevlorne])
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

if UI.MyClass ~= "DEATHKNIGHT" then return end -- only for DK

local ToClock = Engine.ToClock
local PixelPerfect = Engine.PixelPerfect
local DefaultBoolean = Engine.DefaultBoolean

--
local plugin = Engine:NewPlugin("RUNES")

local DefaultColors = {
	{ 0.69, 0.31, 0.31, 1 }, -- Blood
	{ 0.31, 0.45, 0.63, 1 }, -- Frost
	{ 0.33, 0.59, 0.33, 1 }, -- Death
}

-- own methods
function plugin:UpdateVisibility(event)
	local inCombat = true
	if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
		inCombat = true
	else
		inCombat = false
	end
	if self.settings.autohide == false or inCombat then
		--UIFrameFadeIn(self, (0.3 * (1-self.frame:GetAlpha())), self.frame:GetAlpha(), 1)
		self.frame:Show()
		self.timeSinceLastUpdate = GetTime()
		self:RegisterUpdate(plugin.Update)
	else
		--UIFrameFadeOut(self, (0.3 * (0+self.frame:GetAlpha())), self.frame:GetAlpha(), 0)
		self.frame:Hide()
		self:UnregisterUpdate()
	end
end

function plugin:Update(elapsed)
	self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
	if self.timeSinceLastUpdate > self.settings.updatethreshold then
		local runesReady = 0
		for i = 1, self.count do
			local runeIndex = self.settings.runemap[i]
			local start, duration, finished = GetRuneCooldown(runeIndex)
--			print(start, duration, finished)

			local rune = self.runes[i]
			rune.status:SetMinMaxValues(0, duration)

			if finished then
				rune.status:SetValue(duration)
				if self.settings.duration == true then
					rune.durationText:SetText("")
				end
			else
				rune.status:SetValue(GetTime() - start)
				if self.settings.duration == true then
					rune.durationText:SetText(ToClock(start+duration-GetTime()))
				end
			end
		end
		self.timeSinceLastUpdate = 0
	end
end

function plugin:UpdateGraphics()
	-- Create a frame including every runes
	local frame = self.frame
	if not frame then
		frame = CreateFrame("Frame", self.name, UI.PetBattleHider)
		frame:Hide()
		self.frame = frame
	end
	local frameWidth = self:GetWidth()
	local height = self:GetHeight()
	frame:ClearAllPoints()
	frame:Point(unpack(self:GetAnchor()))
	frame:Size(frameWidth, height)
	-- Create runes
	local width, spacing = PixelPerfect(frameWidth, self.count)
	self.runes = self.runes or {}
	for i = 1, self.count do
		local rune = self.runes[i]
		if not rune then
			rune = CreateFrame("Frame", nil, self.frame)
			rune:SetTemplate()
			rune:SetFrameStrata("BACKGROUND")
			self.runes[i] = rune
		end
		rune:Size(width, height)
		rune:ClearAllPoints()
		if i == 1 then
			rune:Point("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
		else
			rune:Point("LEFT", self.runes[i-1], "RIGHT", spacing, 0)
		end
		if not rune.status then
			rune.status = CreateFrame("StatusBar", nil, rune)
			rune.status:SetStatusBarTexture(UI.NormTex)
			rune.status:SetFrameLevel(6)
			rune.status:SetInside()
			rune.status:SetMinMaxValues(0, 10)
		end
		local specIndex = GetSpecialization()
		local color = self:GetColor(self.settings.colors[specIndex])
		rune.status:SetStatusBarColor(unpack(color))
		rune.status:SetOrientation(self.settings.orientation)
		--
		if self.settings.duration == true and not rune.durationText then
			rune.durationText = UI.SetFontString(rune.status, self.settings.durationTextSize)
			rune.durationText:Point("CENTER", rune.status)
		end
		if rune.durationText then rune.durationText:SetText("") end
	end
end

-- overridden methods
function plugin:Initialize()
	-- set defaults
	self.settings.updatethreshold = self.settings.updatethreshold or 0.1
	self.settings.orientation = self.settings.orientation or "HORIZONTAL"

	self.settings.runemap = { 1, 2, 3, 4, 5, 6 }
	self.settings.colors = self.settings.colors or DefaultColors
	--
	self.count = 6
	self.settings.duration = DefaultBoolean(self.settings.duration, true)
	self.settings.durationTextSize = self.settings.durationTextSize or 12
	--
	self:UpdateGraphics()
end

function plugin:Enable()
	self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibility)
	
	self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", plugin.UpdateGraphics)
end

function plugin:Disable()
	--
	self:UnregisterAllEvents()
	self:UnregisterUpdate()
	--
	self.frame:Hide()
end

function plugin:SettingsModified()
	--
	self:Disable()
	--
	self:UpdateGraphics()
	--
	if self:IsEnabled() then
		self:Enable()
		self:UpdateVisibility()
	end
end