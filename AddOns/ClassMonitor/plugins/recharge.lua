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
local PixelPerfect = Engine.PixelPerfect
local DefaultBoolean = Engine.DefaultBoolean

--
local plugin = Engine:NewPlugin("RECHARGE")

-- self.count == number of created bars
-- self.numBars == current max value

-- own methods
function plugin:UpdateActiveBar(elapsed)
--print("UpdateActiveBar:"..tostring(self.activeBarIndex).."  "..tostring(self.bars[self.activeBarIndex]))
	-- update only 'active' bar
	if not self.activeBarIndex then return end
	local bar = self.bars[self.activeBarIndex]
	if not bar then return end

	if not self.expirationTime then return end
	self.expirationTime = self.expirationTime - elapsed

	local timeLeft = self.expirationTime
	local timeElapsed = self.cooldownDuration - timeLeft
--print("timeLeft:"..tostring(timeLeft).."  timeElapsed:"..tostring(timeElapsed))
	if timeLeft > 0 then
		--self.status:SetValue(timeLeft)
		bar.status:SetValue(timeElapsed)
		if self.settings.text == true and bar.text then
			bar.text:SetText(ToClock(timeLeft))
		end
	end
end

function plugin:UpdateValue()
	if not self.spellName then return end
	local currentCharges, maxCharges, timeLastCast, cooldownDuration = GetSpellCharges(self.spellName)
--print("spell:"..tostring(self.spellName).."  current:"..tostring(currentCharges).."  max:"..tostring(maxCharges).."  "..tostring(timeLastCast).."  "..tostring(cooldownDuration))
	-- check if max charge has changed
	if maxCharges and maxCharges ~= self.numBars then
		-- compute new width, spacing
		if maxCharges > self.count then
			self.count = maxCharges
		end
		-- update bars (create any needed bars)
		local width, spacing = PixelPerfect(self:GetWidth(), maxCharges)
		local height = self:GetHeight()
		for i = 1, self.count do
			self:UpdateBarGraphics(i, width, height, spacing)
			self.bars[i]:Hide()
		end
		-- update current max
		self.numBars = maxCharges
		-- desactivate update
		self:UnregisterUpdate()
	end
	maxCharges = maxCharges or 0
	currentCharges = currentCharges or 0
	-- [BAR1]  [BAR2]  [BAR3]
	-- if bar2 is on cooldown (3 sec left), this will be displayed
	-- [FILL]  [3SEC]  [EMPTY]
	for i = 1, maxCharges do
		local bar = self.bars[i]
		if i-1 == currentCharges and timeLastCast ~= nil then
			-- set cooldown on bar
			local timeLeft = (timeLastCast+cooldownDuration) - GetTime()
			self.cooldownDuration = cooldownDuration
			self.expirationTime = timeLeft
			self.activeBarIndex = i -- set active bar
			bar.status:SetMinMaxValues(0, cooldownDuration)
			self:RegisterUpdate(plugin.UpdateActiveBar)
		elseif i-1 < currentCharges then
			-- fill bar
			bar.status:SetMinMaxValues(0, 1)
			bar.status:SetValue(1)
			if self.settings.text == true and bar.text then
				bar.text:SetText("")
			end
		else
			-- empty bar
			bar.status:SetMinMaxValues(0, 1)
			bar.status:SetValue(0)
			if self.settings.text == true and bar.text then
				bar.text:SetText("")
			end
		end
		bar:Show()
	end
	for i = maxCharges+1, self.count do -- hide remaining bars
		self.bars[i]:Hide()
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
		self.frame:Show()
	else
		self:UnregisterUpdate()
		self.frame:Hide()
	end
end

function plugin:UpdateBarGraphics(index, width, height, spacing)
	--
	local bar = self.bars[index]
	if not bar then
		bar = CreateFrame("Frame", nil, self.frame)
		bar:SetTemplate()
		bar:SetFrameStrata("BACKGROUND")
		bar:Hide()
		self.bars[index] = bar
	end
	bar:Size(width, height)
	bar:ClearAllPoints()
	if index == 1 then
		bar:Point("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
	else
		bar:Point("LEFT", self.bars[index-1], "RIGHT", spacing, 0)
	end
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
	--
	if self.settings.text == true and not bar.text then
		bar.text = UI.SetFontString(bar.status, 12)
		bar.text:Point("CENTER", bar.status)
	end
	if bar.text then bar.text:SetText("") end
end

function plugin:UpdateGraphics()
	-- Create a frame including every bars
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
	-- Create bars
	local width, spacing = PixelPerfect(frameWidth, self.numBars)
	self.bars = self.bars or {}
	for i = 1, self.count do
		self:UpdateBarGraphics(i, width, height, spacing)
	end
end

-- overridden methods
function plugin:Initialize()
	-- set defaults
	self.settings.customcolor = DefaultBoolean(self.settings.customcolor, false)
	self.settings.color = self.settings.color or UI.ClassColor()
	self.settings.text = DefaultBoolean(self.settings.text, true)
	-- no default for spellID
	--
	self.count = 1 -- starts with one charge
	self.spellName = GetSpellInfo(self.settings.spellID)
	self.numBars = self.count
	--
	self:UpdateGraphics()
end

function plugin:Enable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibility)
	self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", plugin.UpdateVisibility)

	self:RegisterEvent("SPELLS_CHANGED", plugin.UpdateValue) -- only valid event triggered after a talent is learned
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN", plugin.UpdateValue)
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
	self.spellName = GetSpellInfo(self.settings.spellID)
	self.numBars = 1
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