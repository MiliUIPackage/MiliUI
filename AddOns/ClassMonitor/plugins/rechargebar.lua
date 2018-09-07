-- Aura plugin
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

--[[
Savage Defense uses a new mechanic - Recharge time. The 1.5 cooldown displayed here is accurate (though it seems confusing with the Omni CC add-on that seems to show a 9 second cooldown).
You have up to 3 charges stored at a time.
You gain 1 charge every 9 seconds (the fake cooldown)
You can press Savage Defense even when you still have the 6 second buff on you, and it will simply add 6 seconds to your buff.
With enough rage (60 rage a pop), the 1.5 second cooldown and a 6 second duration you could've kept this 45% dodge buff up indefinately, making it just a boring buff you have to keep active or you fail.
The 9 second Recharge timer simply serves to prevent that. You can keep the buff active 2/3 of the time, the nice thing is you get to choose when that is. 6 on 3 off, or 12 on 6 off, or 12 on 1 off 6 on....
It's a new way of thinking about cooldowns, and I personally am excited to see what else could use it.
--]]

local ToClock = Engine.ToClock
local CheckSpec = Engine.CheckSpec
local DefaultBoolean = Engine.DefaultBoolean

--
local plugin = Engine:NewPlugin("RECHARGEBAR")

-- own methods
function plugin:Update(elapsed)
	if not self.expirationTime then return end
	self.expirationTime = self.expirationTime - elapsed

	local timeLeft = self.expirationTime
	local timeElapsed = self.cooldownDuration - timeLeft
	if timeLeft > 0 then
		--self.status:SetValue(timeLeft)
		self.bar.status:SetValue(timeElapsed)
		if self.settings.text == true then
			self.bar.durationText:SetText(ToClock(timeLeft))
		end
	end
end

function plugin:UpdateValue()
	if not self.spellName then return end
	local currentCharges, maxCharges, timeLastCast, cooldownDuration = GetSpellCharges(self.spellName)
--print(tostring(event)..":"..tostring(currentCharges).."  "..tostring(maxCharges).."  "..tostring(timeLastCast).."  "..tostring(cooldownDuration))
	maxCharges = maxCharges or 0
	currentCharges = currentCharges or 0
	self.bar.chargeText:SetText(tostring(currentCharges).."/"..tostring(maxCharges))
	if currentCharges ~= maxCharges and timeLastCast ~= nil then
		-- set cooldown on bar
		local timeLeft = (timeLastCast+cooldownDuration) - GetTime()
		self.cooldownDuration = cooldownDuration
		self.expirationTime = timeLeft
		self.bar.status:SetMinMaxValues(0, cooldownDuration)
		self:RegisterUpdate(plugin.Update)
	else
		-- fill bar
		self.expirationTime = nil
		self.bar.status:SetMinMaxValues(0, 1)
		self.bar.status:SetValue(1)
		if self.settings.text == true then
			self.bar.durationText:SetText("")
		end
		self:UnregisterUpdate()
	end
end

function plugin:UpdateVisibility(event)
	--
	local inCombat = true
	if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
		inCombat = true
	else
		inCombat = false
	end
	--
	if (self.settings.autohide == false or inCombat) and CheckSpec(self.settings.specs) then
		--
		self:UpdateValue()
		--
		self:RegisterEvent("SPELLS_CHANGED", plugin.UpdateValue)
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN", plugin.UpdateValue)
		--
		self.bar:Show()
	else
		self:UnregisterUpdate()
		self:UnregisterEvent("SPELLS_CHANGED")
		self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
		--
		self.bar:Hide()
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
		bar.status:SetMinMaxValues(0, 300) -- dummy value
		bar.status:SetValue(0)
	end
	bar.status:SetStatusBarColor(unpack(self.settings.color))

	if not bar.chargeText then
		bar.chargeText = UI.SetFontString(bar.status, 12)
		bar.chargeText:Point("CENTER", bar.status)
	end
	bar.chargeText:SetText("")

	if self.settings.text == true and not bar.durationText then
		bar.durationText = UI.SetFontString(bar.status, 12)
		bar.durationText:Point("RIGHT", bar.status)
	end
	if bar.durationText then bar.durationText:SetText("") end
end

-- overridden methods
function plugin:Initialize()
	-- set defaults
	self.settings.customcolor = DefaultBoolean(self.settings.customcolor, false)
	self.settings.color = self.settings.color or UI.ClassColor()
	self.settings.text = DefaultBoolean(self.settings.text, true)
	-- no default for spellID
	--
	self.spellName = GetSpellInfo(self.settings.spellID)
	--
	self:UpdateGraphics()
end

function plugin:Enable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibility)
	self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", plugin.UpdateVisibility)
end

function plugin:Disable()
	--
	self:UnregisterAllEvents()
	self:UnregisterUpdate()
	--
	self.bar:Hide()
end

function plugin:SettingsModified()
	--
	self:Disable()
	--
	self.spellName = GetSpellInfo(self.settings.spellID)
	--
	self:UpdateGraphics()
	--
	if self:IsEnabled() then
		self:Enable()
		self:UpdateVisibility()
	end
end