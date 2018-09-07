local ADDON_NAME, Engine = ...

local ClassMonitor = ClassMonitor
local UI = ClassMonitor.UI
local ClassMonitor_ConfigUI = ClassMonitor_ConfigUI

-- Plugin displaying a simple castbar
local pluginName = "CASTBARPLUGIN"
local CastbarPlugin = ClassMonitor:NewPlugin(pluginName) -- create new plugin entry point in ClassMonitor

-- Return value or default is value is nil
local function DefaultBoolean(value, default)
	if value == nil then
		return default
	else
		return value
	end
end


-- MANDATORY FUNCTIONS
function CastbarPlugin:Initialize()
	--
	self.settings.unit = self.settings.unit or "player"
	self.settings.color = self.settings.color or {1, 0, 0, 1}
	self.settings.fill = DefaultBoolean(self.settings.fill, true)
	--
	self:UpdateGraphics()
end

function CastbarPlugin:Enable()
	--

--	self:RegisterUnitEvent("UNIT_SPELLCAST_START", self.settings.unit, CastbarPlugin.SpellCastStart)
--	self:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", self.settings.unit, CastbarPlugin.SpellCastFailed)
--	self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", self.settings.unit, CastbarPlugin.SpellCastInterrupted)
--	self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", self.settings.unit, CastbarPlugin.SpellCastStop)
	--UNIT_SPELLCAST_INTERRUPTIBLE
	--UNIT_SPELLCAST_NOT_INTERRUPTIBLE
	--UNIT_SPELLCAST_DELAYED
--	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", self.settings.unit, CastbarPlugin.SpellCastChannelStart)
--	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", self.settings.unit, CastbarPlugin.SpellCastChannelUpdate)
--	self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", self.settings.unit, CastbarPlugin.SpellCastChannelStop)
end

function CastbarPlugin:Disable()
	--
	self:UnregisterAllEvents()
	--
	self.bar:Hide()
end

function CastbarPlugin:SettingsModified()
	self:Disable()
	self:UpdateGraphics()
	if self:IsEnabled() then
		self:Enable()
	end
end

-- OWN FUNCTIONS
function CastbarPlugin:UpdateGraphics()
	--local x = GetToto(self.settings)  -- safecall test
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
		bar.status:Point("TOPLEFT", bar, "TOPLEFT", 2, -2)
		bar.status:Point("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
	end
	bar.status:SetStatusBarColor(unpack(self.settings.color))
	bar.status:SetMinMaxValues(0, 1)
	--
	if not bar.text then
		bar.text = UI.SetFontString(bar.status, 12)
		bar.text:Point("CENTER", bar.status)
	end
	if bar.text then bar.text:SetText("") end
	--
	if not bar.durationText then
		bar.durationText = UI.SetFontString(bar.status, 12)
		bar.durationText:Point("RIGHT", bar.status)
	end
end

function CastbarPlugin:Update(elapsed)
	self.timeSinceLastUpdate = (self.timeSinceLastUpdate or GetTime()) + elapsed
	if self.timeSinceLastUpdate > 0.2 then
		local timeElapsed = GetTime() - self.startTime
		if self.settings.fill == true then
			self.bar.status:SetValue(timeElapsed)
		else
			self.bar.status:SetValue(self.duration - timeElapsed)
		end
		self.bar.durationText:SetFormattedText("%2.1f / %2.1f", timeElapsed, self.duration)
	end
end

function CastbarPlugin:SpellCastStart(_, unit, spell, _, lineID, spellID)
	local name, text, _, startTime, endTime, _, castID, notInterruptible = UnitCastingInfo(self.settings.unit)
	if not name then return end

	self.endTime = endTime / 1e3
	self.startTime = startTime / 1e3
	self.duration = self.endTime - self.startTime
	self.bar.text:SetText(text)
	self.bar.status:SetMinMaxValues(0, self.duration)
	self.bar.status:SetValue(0)
	self.bar:Show()
	self:RegisterUpdate(CastbarPlugin.Update)
end

function CastbarPlugin:SpellCastFailed(_, unit, spell, _, lineID, spellID)
	self:UnregisterUpdate()
	self.bar:Hide()
end

function CastbarPlugin:SpellCastInterrupted(_, unit, spell, _, lineID, spellID)
	self:UnregisterUpdate()
	self.bar:Hide()
end

function CastbarPlugin:SpellCastStop(_, unit, spell, _, lineID, spellID)
	self:UnregisterUpdate()
	self.bar:Hide()
end

function CastbarPlugin:SpellCastChannelStart(_, unit, spell, _, lineID, spellID)
	local name, text, _, startTime, endTime, _, notInterruptible = UnitChannelInfo(self.settings.unit)

	self.endTime = endTime / 1e3
	self.startTime = startTime / 1e3
	self.duration = self.endTime - self.startTime
	self.bar.text:SetText(name..":"..text)
	self.bar.status:SetMinMaxValues(0, self.duration)
	self.bar.status:SetValue(0)
	self.bar:Show()
	self:RegisterUpdate(CastbarPlugin.Update)
end

function CastbarPlugin:SpellCastChannelUpdate(_, unit, spell, _, lineID, spellID)
	-- NOP
end

function CastbarPlugin:SpellCastChannelStop(_, unit, spell, _, lineID, spellID)
	self:UnregisterUpdate()
	self.bar:Hide()
end

-- OPTION DEFINITION
if ClassMonitor_ConfigUI then
--print("CREATE CastbarPlugin DEFINITION")
	local Helpers = ClassMonitor_ConfigUI.Helpers

	local color = Helpers.CreateColorsDefinition("color", 1, "Color")
	local options = {
		[1] = Helpers.Description,
		[2] = Helpers.Name,
		[3] = Helpers.DisplayName,
		[4] = Helpers.Kind,
		[5] = Helpers.Enabled,
		[6] = Helpers.WidthAndHeight,
		[7] = Helpers.Unit,
		[8] = {
			key = "fill", -- use self.settings.fill to access this option
			name = "Fill", -- TODO: locales
			desc = "Fill or empty bar", -- TODO: locales
			type = "toggle", -- Ace3 config type
			get = Helpers.GetValue, -- simple get value
			set = Helpers.SetValue, -- simple set value
			disabled = Helpers.IsPluginDisabled, -- disabled if plugin is disabled
		},
		[9] = color,
		[10] = Helpers.Anchor,
		[11] = Helpers.AutoGridAnchor,
	}
	local short = "Cast bar"
	local long = "Display a cast bar"
	ClassMonitor_ConfigUI:NewPluginDefinition(pluginName, options, short, long) -- add plugin definition in ClassMonitor_ConfigUI
end