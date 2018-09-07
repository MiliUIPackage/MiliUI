-- Energize Plugin, written by Ildyria (edited by SinaC)
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

local CheckSpec = Engine.CheckSpec
local DefaultBoolean = Engine.DefaultBoolean
local ToClock = Engine.ToClock

--
local plugin = Engine:NewPlugin("ENERGIZE")

-- own methods
function plugin:Update(elapsed)
	self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
	if self.timeSinceLastUpdate > 0.1 then
--print("UPDATE...")
		local newValue = 0
		local finished = false
		if self.settings.filling then
			newValue = GetTime() - self.startTime -- delay since start
			finished = newValue >= self.settings.duration
--print("FILLING: "..tostring(newValue).."  "..tostring(finished))
		else
			newValue = self.settings.duration - (GetTime() - self.startTime)
			finished = newValue <= 0
--print("NOT FILLING: "..tostring(newValue).."  "..tostring(finished))
		end
		if finished then
			self:UnregisterUpdate()
			self.bar:Hide()
		else
			local timeLeft = self.settings.duration - (GetTime() - self.startTime)
			self.bar.status:SetValue(newValue)
			self.bar.timeLeftText:SetText(ToClock(timeLeft))
		end
		self.timeSinceLastUpdate = 0
	end
end

function plugin:CombatLog(_, _, eventType, _, caster, _, _, _, target, _, _, _, spellID)
--print("CombatLog:"..tostring(eventType).."  "..tostring(caster).."  "..tostring(target).."  "..tostring(spellID))
	if eventType == "SPELL_ENERGIZE" and spellID == self.settings.spellID and target == UnitGUID("player") and caster == UnitGUID("player") then
--print("SPELL_ENERGIZE")
		if self.settings.filling then
			self.bar.status:SetValue(0)
		else
			self.bar.status:SetValue(self.settings.duration)
		end
		self.bar.timeLeftText:SetText(ToClock(self.settings.duration))
		self.startTime = GetTime()
		self.timeSinceLastUpdate = GetTime()
		self:RegisterUpdate(plugin.Update)
		self.bar:Show()
	elseif eventType == "SPELL_PERIODIC_ENERGIZE" and spellID == self.settings.spellID and target == UnitGUID("player") then 
--print("SPELL_PERIODIC_ENERGIZE")
		if self.settings.filling then
			self.bar.status:SetValue(0)
		else
			self.bar.status:SetValue(self.settings.duration)
		end
		self.bar.timeLeftText:SetText(ToClock(self.settings.duration))
		self.startTime = GetTime()
		self.timeSinceLastUpdate = GetTime()
		self:RegisterUpdate(plugin.Update)
		self.bar:Show()
	end
end

function plugin:UpdateVisibility(event)
	-- TODO: autohide ?
	if CheckSpec(self.settings.specs) then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", plugin.CombatLog)
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
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

	if not bar.status then
		bar.status = CreateFrame("StatusBar", nil, bar)
		bar.status:SetStatusBarTexture(UI.NormTex)
		bar.status:SetFrameLevel(6)
		bar.status:SetInside()
	end
	bar.status:SetMinMaxValues(0, self.settings.duration)
	bar.status:SetStatusBarColor(unpack(self.settings.color))

	if not bar.timeLeftText then
		bar.timeLeftText = UI.SetFontString(bar.status, 12)
		bar.timeLeftText:Point("RIGHT", bar.status)
	end
	bar.timeLeftText:SetText("")
end

-- overridden methods
function plugin:Initialize()
	-- set defaults
	self.settings.filling = DefaultBoolean(self.settings.filling, false)
	self.settings.color = self.settings.color or UI.ClassColor()
	self.settings.duration = self.settings.duration or 12
	-- no default for spellID
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
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:UnregisterUpdate()
	--
	self.bar:Hide()
end

function plugin:SettingsModified()
	--
	self:Disable()
	--
	self:UpdateGraphics()
	--
	if self:IsEnabled() then
		self:Enable()
	end
end