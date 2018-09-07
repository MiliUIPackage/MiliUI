-- Aura plugin
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

local ToClock = Engine.ToClock
local CheckSpec = Engine.CheckSpec
local DefaultBoolean = Engine.DefaultBoolean

--
local plugin = Engine:NewPlugin("AURABAR")

-- own methods
function plugin:Update(elapsed)
	self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed
	if self.timeSinceLastUpdate > 0.2 then
        local timeLeft = self.expirationTime - GetTime()
		if self.settings.duration == true then
			if timeLeft > 0 then
				self.bar.durationText:SetText(ToClock(timeLeft))
			else
				self.bar.durationText:SetText("")
			end
		end
		self.bar.status:SetValue(timeLeft)
		self.timeSinceLastUpdate = 0
	end
end

function plugin:UpdateVisibilityAndValue(event)
--print("AURABAR:UpdateVisibilityAndValue:"..tostring(self.auraName))
	local inCombat = true
	if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
		inCombat = true
	else
		inCombat = false
	end
	local visible = false
    local needUpdate = false
	if (self.settings.autohide == false or inCombat) and CheckSpec(self.settings.specs) then
        local name, _, stack, _, duration, expirationTime, unitCaster = AuraUtil.FindAuraByName(self.auraName, self.settings.unit, self.settings.filter)
        if self.settings.countFromOther == true then
            _, _, stack = AuraUtil.FindAuraByName(self.auraName, self.settings.unit, self.settings.filter)
        end
        if not stack then stack = 0 end
        if self.settings.text == true then
            self.bar.valueText:SetText(tostring(stack).."/"..tostring(self.settings.count))
        end
		if name == self.auraName and unitCaster == "player" then --and stack > 0 then
            self.bar.status:Show()
			if self.settings.showspellname == true then
				self.bar.spellText:SetText(name)
			end
			self.bar.status:SetMinMaxValues(0, duration or 1)
			self.expirationTime = expirationTime -- save to use in Update
            needUpdate = true
        else
            self.bar.status:Hide()
		end
        visible = true
	end
	if visible then
		self.bar:Show()
--        self:UpdateValue()
	else
		self.bar:Hide()
	end
    if needUpdate then
		self.timeSinceLastUpdate = GetTime()
		self:RegisterUpdate(plugin.Update)
	else
		self:UnregisterUpdate()
	end
end

function plugin:UpdateGraphics()
--print("AURABAR:UpdateGraphics")
	--
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
		bar.status:SetFrameLevel(5)
		bar.status:SetInside()
		bar.status:Hide()
    end
    --
	local color = self:GetColor(self.settings.color)
	bar.status:SetStatusBarColor(unpack(color))
--	bar.status:SetMinMaxValues(0, self.settings.count)
	if self.settings.text == true and not bar.valueText then
        bar.textBar = CreateFrame("Frame", nil, bar)
		bar.textBar:SetFrameLevel(6)
		bar.valueText = UI.SetFontString(bar.textBar, 12)
		bar.valueText:Point("CENTER", bar)
    end
    --
	if self.settings.duration == true and not bar.durationText then
		bar.durationText = UI.SetFontString(bar.status, 12)
		bar.durationText:Point("RIGHT", bar.status)
	end
	if bar.durationText then bar.durationText:SetText("") end
	--
	if self.settings.showspellname == true and not bar.spellText then
		bar.spellText = UI.SetFontString(bar.status, 12)
		bar.spellText:Point("LEFT", bar.status)
	end
	if bar.spellText then bar.spellText:SetText("") end
end

-- overridden methods
function plugin:Initialize()
--print("AURABAR:Initialize")
	-- set defaults
	self.settings.unit = self.settings.unit or "player"
	self.settings.text = DefaultBoolean(self.settings.text, true)
	self.settings.duration = DefaultBoolean(self.settings.duration, false)
	self.settings.filter = self.settings.filter or "HELPFUL"
	self.settings.count = self.settings.count or 1
	self.settings.countFromOther = self.settings.countFromOther or false
	self.settings.countSpellID = self.settings.countSpellID or self.settings.spellID
	self.settings.showspellname = DefaultBoolean(self.settings.showspellname, true)
	self.settings.color = self.settings.color or UI.ClassColor()
	self.settings.customcolor = DefaultBoolean(self.settings.customcolor, false)
	--
	self.auraName = GetSpellInfo(self.settings.spellID)
	self.countAuraName = GetSpellInfo(self.settings.countSpellID)
	--
	self:UpdateGraphics()
end

function plugin:Enable()
--print("AURABAR:Enable")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibilityAndValue)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibilityAndValue)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibilityAndValue)
	if self.settings.unit == "focus" then self:RegisterEvent("PLAYER_FOCUS_CHANGED", plugin.UpdateVisibilityAndValue) end
	if self.settings.unit == "target" then self:RegisterEvent("PLAYER_TARGET_CHANGED", plugin.UpdateVisibilityAndValue) end
	if self.settings.unit == "pet" then self:RegisterUnitEvent("UNIT_PET", "player", plugin.UpdateVisibilityAndValue) end
	self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", plugin.UpdateVisibilityAndValue)
	self:RegisterUnitEvent("UNIT_AURA", self.settings.unit, plugin.UpdateVisibilityAndValue)
end

function plugin:Disable()
--print("AURABAR:Disable")
	self:UnregisterAllEvents()
	self:UnregisterUpdate()

	self.bar:Hide()
end

function plugin:SettingsModified()
--print("AURABAR:SettingsModified")
	--
	self:Disable()
	--
	self.auraName = GetSpellInfo(self.settings.spellID)
	--
	self:UpdateGraphics()
	--
	if self:IsEnabled() then
		self:Enable()
		self:UpdateVisibilityAndValue()
	end
end