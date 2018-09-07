-- Statue plugin
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

if UI.MyClass ~= "MONK" and UI.MyClass ~= "PRIEST" and UI.MyClass ~= "WARRIOR" and UI.MyClass ~= "DEATHKNIGHT" then return end -- Statue for monk, Shadowfiend for priest, Ghoul for DK

local ToClock = Engine.ToClock
local CheckSpec = Engine.CheckSpec
local DefaultBoolean = Engine.DefaultBoolean
local GetColor = Engine.GetColor

local DefaultColors = {
	["MONK"] = { 95/255, 222/255,  95/255 },
	["PRIEST"] = { 238/255, 221/255,  130/255 },
	["WARRIOR"] = { 205/255, 92/255,  92/255 },
	["DEATHKNIGHT"] = { 153/255, 102/255, 0 }
}

local plugin = Engine:NewPlugin("STATUE")

-- own methods
function plugin:UpdateStatueTimer(elapsed)
	if not self.expirationTime then return end
	self.expirationTime = self.expirationTime - elapsed

	local timeLeft = self.expirationTime
	if timeLeft > 0 then
		self.bar.status:SetValue(timeLeft)
		if self.settings.text == true then
			self.bar.text:SetText(ToClock(timeLeft))
		end
	else
		self:UnregisterUpdate()
		if self.settings.text == true then
			self.bar.text:SetText("")
		end
	end
end

function plugin:Update()
	local slot = 1
	local up, name, start, duration, icon = GetTotemInfo(slot)
	if up then
		local timeLeft = (start+duration) - GetTime()
		self.expirationTime = timeLeft
		self.bar.status:SetMinMaxValues(0, duration)
		self:RegisterUpdate(plugin.UpdateStatueTimer)
		self.bar:Show()
	else
		self.bar.status:SetValue(0)
		self:UnregisterUpdate()
		self.bar:Hide()
	end
end

function plugin:UpdateVisibility(event)
	local inCombat = true
	if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
		inCombat = true
	else
		inCombat = false
	end
	if (self.settings.autohide == false or inCombat) and CheckSpec(self.settings.specs) then
		self:RegisterEvent("PLAYER_TOTEM_UPDATE", plugin.Update)
		self:Update() -- at least one update
	else
		self:UnregisterEvent("PLAYER_TOTEM_UPDATE")
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
		bar.status:SetMinMaxValues(0, 300) -- dummy value
	end
	bar.status:SetStatusBarColor(unpack(self.settings.color))
	bar.status:SetValue(0)

	if not bar.text and self.settings.text == true then
		bar.text = UI.SetFontString(bar.status, 12)
		bar.text:Point("CENTER", bar.status)
	end
	if self.settings.text == true then
		bar.text:SetText("")
	end
end

-- overriden methods
function plugin:Initialize()
-- set defaults
	self.settings.color = self.settings.color or DefaultColors[UI.MyClass]
	self.settings.text = DefaultBoolean(self.settings.text, false)
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
	self:UpdateGraphics()
	--
	if self:IsEnabled() then
		self:Enable()
		self:UpdateVisibility()
	end
end