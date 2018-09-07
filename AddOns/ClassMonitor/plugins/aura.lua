-- Aura plugin
local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end
local UI = Engine.UI

local CheckSpec = Engine.CheckSpec
local PixelPerfect = Engine.PixelPerfect
local DefaultBoolean = Engine.DefaultBoolean
local GetColor = Engine.GetColor

--
local plugin = Engine:NewPlugin("AURA")

-- own methods
function plugin:UpdateVisibility(event)
	local inCombat = true
	if event == "PLAYER_REGEN_DISABLED" or InCombatLockdown() then
		inCombat = true
	else
		inCombat = false
	end
	if (self.settings.autohide == false or inCombat) and CheckSpec(self.settings.specs) then
		self:RegisterUnitEvent("UNIT_AURA", self.settings.unit, plugin.UpdateValue)
		self:UpdateValue() -- at least one update
		self.frame:Show()
	else
		self:UnregisterEvent("UNIT_AURA")
		self.frame:Hide()
	end
end

function plugin:UpdateValue()
	if not self.auraName then return end
	local name, _, stack, _, _, _, unitCaster = AuraUtil.FindAuraByName(self.auraName, self.settings.unit, self.settings.filter)
	--	print("auraname: "..tostring(self.auraName).."; name: "..tostring(name))
	if name == self.auraName and (unitCaster == "player" or (self.settings.unit == "pet" and unitCaster == "pet")) and stack > 0 then
		assert(stack <= self.settings.count, "Too many stacks:"..tostring(stack)..", maximum has been set to "..tostring(self.settings.count))
		for i = 1, stack do self.stacks[i]:Show() end
		for i = stack+1, self.settings.count do self.stacks[i]:Hide() end
	else
		for i = 1, self.settings.count do self.stacks[i]:Hide() end
	end
end

function plugin:UpdateGraphics()
	-- Create a frame including every stacks
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
	-- Create stacks
	local width, spacing = PixelPerfect(frameWidth, self.settings.count)
	self.stacks = self.stacks or {}
	for i = 1, self.settings.count do
		local stack = self.stacks[i]
		if not stack then
			stack = CreateFrame("Frame", nil, self.frame)
			stack:SetTemplate()
			stack:SetFrameStrata("BACKGROUND")
			stack:Hide()
			self.stacks[i] = stack
		end
		stack:Size(width, height)
		stack:ClearAllPoints()
		if self.settings.reverse == true then
			if i == 1 then
				stack:Point("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
			else
				stack:Point("RIGHT", self.stacks[i-1], "LEFT", spacing, 0)
			end
		else
			if i == 1 then
				stack:Point("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
			else
				stack:Point("LEFT", self.stacks[i-1], "RIGHT", spacing, 0)
			end
		end
		if self.settings.filled == true and not stack.status then
			stack.status = CreateFrame("StatusBar", nil, stack)
			stack.status:SetStatusBarTexture(UI.NormTex)
			stack.status:SetFrameLevel(6)
			stack.status:SetInside()
		end
		local color = self:GetColor(self.settings.color)
		--		local color = GetColor(self.settings.colors, i, UI.ClassColor())
		if self.settings.filled == true then
			stack.status:SetStatusBarColor(unpack(color))
			stack.status:Show()
			stack:SetBackdropBorderColor(unpack(UI.BorderColor))
		else
			stack:SetBackdropBorderColor(unpack(color))
			if stack.status then stack.status:Hide() end
		end
	end
end

-- overridden methods
function plugin:Initialize()
	-- set defaults
	self.settings.unit = self.settings.unit or "player"
	self.settings.filled = DefaultBoolean(self.settings.filled, false)
	self.settings.count = self.settings.count or 1
	self.settings.filter = self.settings.filter or "HELPFUL"
	--	self.settings.colors = self.settings.colors or self.settings.color or UI.ClassColor()
	self.settings.customcolor = DefaultBoolean(self.settings.customcolor, false)
	self.settings.color = self.settings.color or UI.ClassColor()
	--
	self.auraName = GetSpellInfo(self.settings.spellID)
	--
	self:UpdateGraphics()
end

function plugin:Enable()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_REGEN_DISABLED", plugin.UpdateVisibility)
	self:RegisterEvent("PLAYER_REGEN_ENABLED", plugin.UpdateVisibility)
	if self.settings.unit == "focus" then self:RegisterEvent("PLAYER_FOCUS_CHANGED", plugin.UpdateVisibility) end
	if self.settings.unit == "target" then self:RegisterEvent("PLAYER_TARGET_CHANGED", plugin.UpdateVisibility) end
	if self.settings.unit == "pet" then self:RegisterUnitEvent("UNIT_PET", "player", plugin.UpdateVisibility) end
	self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", plugin.UpdateVisibility)

	--self:RegisterUnitEvent("UNIT_AURA", unit, plugin.UpdateValue)
end

function plugin:Disable()
	--
	self:UnregisterAllEvents()
	--
	self.frame:Hide()
end

function plugin:SettingsModified()
	--
	self:Disable()
	--
	self.auraName = GetSpellInfo(self.settings.spellID)
	--
	self:UpdateGraphics()
	--
	if self.settings.enabled == true then
		self:Enable()
		self:UpdateVisibility()
	end
end