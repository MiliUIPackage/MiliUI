-- Aura plugin
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

local ToClock = Engine.ToClock
local CheckSpec = Engine.CheckSpec
local DefaultBoolean = Engine.DefaultBoolean

--
local plugin = Engine:NewPlugin("CD")

-- own methods
function plugin:Update(elapsed)
	self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
	if self.timeSinceLastUpdate > 0.05 then
		local timeLeft = self.expirationTime - GetTime()
		self.bar.status:SetValue(timeLeft)
		if self.settings.duration == true then
			if timeLeft > 0 then
				self.bar.durationText:SetText(ToClock(timeLeft))
			else
				self.bar.durationText:SetText("")
			end
		end
		if timeLeft <= 0 then
			self:UnregisterUpdate()
			self.bar:Hide()
		end
		self.timeSinceLastUpdate = 0
	end
end

function plugin:UpdateVisibility(event)
	local inCombat = true
	if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
		inCombat = true
	else
		inCombat = false
	end
	local visible = false
	if (self.settings.autohide == false or inCombat) and CheckSpec(self.settings.specs) and self.spellName then
		local start, duration, _ = GetSpellCooldown(self.spellName)
		--local value1 = GetSpellBaseCooldown(spellID)
--print("UPDATE_COOLDOWN:"..tostring(self.spellName).."  "..tostring(start).."  "..tostring(duration))
		if start and duration and start > 0 and duration > 1.5 then -- duration > GCD
			self.expirationTime = start + duration
			self.bar.status:SetMinMaxValues(0, duration)
			visible = true
		end
	end
	if visible then
		self.bar:Show()
		self.timeSinceLastUpdate = GetTime()
		self:RegisterUpdate(plugin.Update)
	else
		self.bar:Hide()
		self:UnregisterUpdate()
	end
end

function plugin:UpdateGraphics()
	local bar = self.bar
	if not bar then
		bar = CreateFrame("Frame", self.name, UI.PetBattleHider)
		bar:SetTemplate()
		bar:SetFrameStrata("BACKGROUND")
		bar:Hide()
		self.bar = bar
	end
	bar:ClearAllPoints()
	bar:Point(unpack(self:GetAnchor()))
	bar:Size(self:GetWidth(), self:GetHeight())
	--
	if not bar.status then
		bar.status = CreateFrame("StatusBar", nil, bar)
		bar.status:SetStatusBarTexture(UI.NormTex)
		bar.status:SetFrameLevel(6)
		bar.status:SetInside()
	end
	local color = self:GetColor(self.settings.color)
	bar.status:SetStatusBarColor(unpack(color))
	--
	if self.settings.text == true and not bar.nameText then
		bar.nameText = UI.SetFontString(bar.status, 12)
		bar.nameText:Point("CENTER", bar.status)
	end
	if bar.nameText then bar.nameText:SetText(self.spellName) end
	--
	if self.settings.duration == true and not bar.durationText then
		bar.durationText = UI.SetFontString(bar.status, 12)
		bar.durationText:Point("RIGHT", bar.status)
	end
	if bar.durationText then bar.durationText:SetText("") end
end

-- overridden methods
function plugin:Initialize()
	-- set defaults
	self.settings.text = DefaultBoolean(self.settings.text, true)
	self.settings.duration = DefaultBoolean(self.settings.duration, true)
	self.settings.customcolor = DefaultBoolean(self.settings.customcolor, false)
	self.settings.color = self.settings.color or UI.ClassColor()
	-- no default for spellID
	--
	self.spellName = GetSpellInfo(self.settings.spellID)
--print(tostring(self.settings.spellID).."  "..tostring(self.spellName))
	--
	self:UpdateGraphics()
end

function plugin:Enable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibility)
	self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", plugin.UpdateVisibility)
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN", plugin.UpdateVisibility)
end

function plugin:Disable()
	self:UnregisterAllEvents()
	self:UnregisterUpdate()

	self.bar:Hide()
end

function plugin:SettingsModified()
	--
	self:Disable()
	--
	self.spellName = GetSpellInfo(self.settings.spellID)
--print(tostring(self.settings.spellID).."  "..tostring(self.spellName))
	--
	self:UpdateGraphics()
	--
	if self:IsEnabled() then
		self:Enable()
		self:UpdateVisibility()
	end
end