-- Stagger plugin, credits to Demise and FrozenEmu (http://www.wowinterface.com/downloads/info21191-BrewmasterTao.html)
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

if UI.MyClass ~= "MONK" then return end -- Available only for monks

local _, _, _, toc = GetBuildInfo()

local FormatNumber = Engine.FormatNumber
local CheckSpec = Engine.CheckSpec
local DefaultBoolean = Engine.DefaultBoolean
local GetColor = Engine.GetColor

--
local plugin = Engine:NewPlugin("STAGGER")

local lightStagger = GetSpellInfo(124275)
local moderateStagger = GetSpellInfo(124274)
local heavyStagger = GetSpellInfo(124273)

local DefaultTextSize = 12
local DefaultColors = {
	[1] = {0, .4, 0, 1},
	[2] = {.7, .7, .2, 1},
	[3] = {.9, .2, .2, 1},
}

-- own methods
function plugin:UpdateVisibilityAndValue(event)
	local inCombat = true
	if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
		inCombat = true
	else
		inCombat = false
	end
	local visible = false
	if (self.settings.autohide == false or inCombat) and GetSpecialization() == 1 then -- only for brewmaster
		local spellName, duration, value1, _
			spellName, _, _, _, duration, _, _, _, _, _, _, _, _, _, _, value1 = AuraUtil.FindAuraByName(lightStagger, "player",  "HARMFUL")
			if (not spellName) then spellName, _, _, _, duration, _, _, _, _, _, _, _, _, _, _, value1 = AuraUtil.FindAuraByName(moderateStagger, "player", "HARMFUL") end
			if (not spellName) then spellName, _, _, _, duration, _, _, _, _, _, _, _, _, _, _, value1 = AuraUtil.FindAuraByName(heavyStagger, "player", "HARMFUL") end
		if spellName and value1 ~= nil and type(value1) == "number" and value1 > 0 and duration > 0 then
			if spellName == lightStagger then self.bar.status:SetStatusBarColor(unpack(GetColor(self.settings.colors, 1, DefaultColors[1]))) end
			if spellName == moderateStagger then self.bar.status:SetStatusBarColor(unpack(GetColor(self.settings.colors, 2, DefaultColors[2]))) end
			if spellName == heavyStagger then self.bar.status:SetStatusBarColor(unpack(GetColor(self.settings.colors, 3, DefaultColors[3]))) end
			local staggerTick = value1
			local staggerTotal = staggerTick * math.floor(duration)
			local hp = math.ceil(100 * staggerTotal / UnitHealthMax("player"))
			if self.settings.text == true then
				self.bar.valueText:SetText(FormatNumber(staggerTick).." - "..FormatNumber(staggerTotal).." ("..hp.."%)")
			end
			if hp <= self.settings.threshold then
				self.bar.status:SetValue(hp)
			else
				self.bar.status:SetValue(self.settings.threshold)
			end
			visible = true
		end
	end
	if visible then
		self.bar:Show()
	else
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
	end
	bar.status:SetMinMaxValues(0, self.settings.threshold)

	if self.settings.text == true and not bar.valueText then
		bar.valueText = UI.SetFontString(bar.status, self.settings.textSize)
		bar.valueText:Point("CENTER", bar.status)
	end
	if bar.valueText then bar.valueText:SetText("") end
end

-- overridden methods
function plugin:Initialize()
	-- set defaults
	self.settings.threshold = self.settings.threshold or 100
	self.settings.text = DefaultBoolean(self.settings.text, true)
	self.settings.colors = self.settings.colors or DefaultColors
	self.settings.textSize = self.settings.textSize or DefaultTextSize
	--
	self:UpdateGraphics()
end

function plugin:Enable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibilityAndValue)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibilityAndValue)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibilityAndValue)
	self:RegisterUnitEvent("UNIT_AURA", "player", plugin.UpdateVisibilityAndValue)
	self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", plugin.UpdateVisibilityAndValue)
end

function plugin:Disable()
	--
	self:UnregisterAllEvents()
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
		self:UpdateVisibilityAndValue()
	end
end