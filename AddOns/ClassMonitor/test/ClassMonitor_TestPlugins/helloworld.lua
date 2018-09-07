local ADDON_NAME, Engine = ...

local ClassMonitor = ClassMonitor
local UI = ClassMonitor.UI
local ClassMonitor_ConfigUI = ClassMonitor_ConfigUI

local HelloWorldPluginName = "HELLOWORLD"
local HelloWorldPlugin = ClassMonitor:NewPlugin(HelloWorldPluginName) -- create new plugin entry point in ClassMonitor

function HelloWorldPlugin:Initialize() -- MANDATORY
--print("Initialize")
	-- set default value for self.settings.helloworldpluginfirstoption
	self.settings.helloworldpluginfirstoption = self.settings.helloworldpluginfirstoption or 50
	--
	self:UpdateGraphics()
end

function HelloWorldPlugin:Enable() -- MANDATORY
--print("Enable")
	-- TODO: register events
	self:RegisterEvent("PLAYER_ENTERING_WORLD", HelloWorldPlugin.UpdateValue)
end

function HelloWorldPlugin:Disable() -- MANDATORY
--print("Disable")
	-- TODO: unregister event, hide GUI
	self:UnregisterAllEvents()
	--
	self.bar:Hide()
end

function HelloWorldPlugin:SettingsModified() -- MANDATORY
--print("SettingsModified")
	-- It's advised to disable plugin before updating GUI
	self:Disable()
	-- update graphics
	self:UpdateGraphics()
	-- Re-enable plugin if it was enabled
	if self:IsEnabled() then
		self:Enable()
		self:UpdateValue()
	end
end

-- OWN FUNCTIONS
function HelloWorldPlugin:UpdateGraphics()
	local bar = self.bar
	if not bar then
		bar = CreateFrame("Frame", self.settings.name, UI.PetBattleHider)
		bar:Hide()
		self.bar = bar
	end
	bar:ClearAllPoints()
	bar:Point(unpack(self:GetAnchor()))
	bar:Size(self:GetWidth(), self:GetHeight())
	--
	if not bar.centerText then
		bar.centerText = UI.SetFontString(bar, 12)
		bar.centerText:Point("CENTER", bar)
	end
	--
	if not bar.leftText then
		bar.leftText = UI.SetFontString(bar, 12)
		bar.leftText:Point("LEFT", bar)
	end
	--
	if not bar.rightText then
		bar.rightText = UI.SetFontString(bar, 12)
		bar.rightText:Point("RIGHT", bar)
	end
end

function HelloWorldPlugin:UpdateValue()
	self.bar:Show()
	--
	--print("Hellow world!")
	--print("VALUE: "..tostring(self.settings.helloworldpluginfirstoption))
	self.bar.centerText:SetFormattedText("Hellow world! -> %d", self.settings.helloworldpluginfirstoption)
	self.bar.leftText:SetText(">")
	self.bar.rightText:SetText("<")
end

-- OPTION DEFINITION
if ClassMonitor_ConfigUI then
--print("CREATE pluginCastBar DEFINITION")
	local Helpers = ClassMonitor_ConfigUI.Helpers
	local HelloWorldPluginOptions = {
		[1] = Helpers.Name, -- MANDATORY (add .name to settings)
		[2] = Helpers.DisplayName, -- MANDATORY (add .displayName to settings  internal use)
		[3] = Helpers.Kind, -- MANDATORY (add .kind to settings  internal use)
		[4] = Helpers.Enabled, -- MANDATORY (add .enabled to settings)
		[5] = Helpers.Autohide, -- OPTIONAL (add .autohide to settings)
		[6] = Helpers.WidthAndHeight, -- MANDATORY (add .width and .height to settings)
		[7] = Helpers.Specs, -- OPTIONAL (add .specs to settings)
		[8] = {
			key = "helloworldpluginfirstoption", -- use  self.settings.helloworldpluginfirstoption in plugin methods to access current value
			name = "My Plugin First Option",
			desc = "This is the first option of my own plugin",
			type = "range", -- Ace3 option type
			min = 10, max = 100, step = 10,
			get = Helpers.GetValue, -- generic get value
			set = Helpers.SetValue, -- generic set value
			disabled = Helpers.IsPluginDisabled -- when plugin.enabled is false, option is disabled
		},
		[9] = ClassMonitor_ConfigUI.Helpers.Anchor, -- MANDATORY when not in autogrid anchoring mode  (add .anchor to settings)
		[10] = ClassMonitor_ConfigUI.Helpers.AutoGridAnchor, -- MANDATORY when in autogrid anchoring mode (add .verticalIndex and .horizontalIndex    internal use)
		-- add other options
	}

	local HelloWorldPluginShortDescription = "Hello world"
	local HelloWorldPluginLongDescription = "Display hellow world when entering world"

	ClassMonitor_ConfigUI:NewPluginDefinition(HelloWorldPluginName, HelloWorldPluginOptions, HelloWorldPluginShortDescription, HelloWorldPluginLongDescription) -- add plugin definition in ClassMonitor_ConfigUI
end