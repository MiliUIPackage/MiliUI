# ClassMonitor
Monitor class resources such as combo points, energy, runes, soul shards, mana, eclipse, mana tea. 
This version is compatible with standard Blizzard UI, Tukui and ElvUI. This replaced old versions Tukui_ClassMonitor and Tukui_ElvUI_ClassMonitor 

To move frames, you can use /clm move or /moveui if you're using Tukui/ElvUI 
To config, you can use /clm config (or /ec in ElvUI) 

If you see blurry borders on top/bottom of bars, try with multisampling set to 1 (it's impossible to perform pixel perfect with multisampling set higher than 1) You may also try to set an even value for bar height and/or move your bars one pixel above/below

You can still modify your config by creating a new file profiles.lua in /ClassMonitor/config/ but it will be lost each time you perform an update of the addon. 

### Default functions by class:
* Druid: mana/rage/energy, combo
* Paladin: mana, holy power
* Warlock: mana, soul shards
* Rogue: energy, combo
* Priest: mana, shadow orbs,
* Mage: mana, arcane blast
* DK: runic power, runes blood shield
* Hunter: mana, focus
* Warrior: rage, shield barrier 
* Shaman: mana, maelstorm
* Monk: mana/energy, chi, stagger

Additional plugin (must be added in config.lua or with config UI): 
Health, CD, Recharge (points and bar CD with charge like monk's roll) , Aura (points and bar check buff or debuff) 

This addon is based on sCombo by Smelly and Hydra. It has been totally rewritten and many new features have been added. Ildyria also wrote some plugins. 
******
## Add new plugin
New plugin can be added to ClassMonitor using ClassMonitor:NewPlugin  (see public.lua)
You can also add your plugin options definition using ClassMonitor_ConfigUI:NewPluginDefinition

A full sample is provided in ClassMonitor\test\ClassMonitor_TestPlugins

### Hello World sample:
```
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
```

### OPTION DEFINITION
```
if ClassMonitor_ConfigUI then
--print("CREATE pluginCastBar DEFINITION")
	local Helpers = ClassMonitor_ConfigUI.Helpers
	local HelloWorldPluginOptions = {
		[1] = Helpers.Name, -- MANDATORY (add .name to settings)
		[2] = Helpers.DisplayName, -- MANDATORY (add .displayName to settings  internal use)
		[3] = Helpers.Kind, -- MANDATORY (add .kind to settings  internal use)
		[4] = Helpers.Enabled, -- MANDATORY (add .enable to settings)
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
			disabled = Helpers.IsPluginDisabled -- when plugin.enable is false, option is disabled
		},
		[9] = ClassMonitor_ConfigUI.Helpers.Anchor, -- MANDATORY when not in autogrid anchoring mode  (add .anchor to settings)
		[10] = ClassMonitor_ConfigUI.Helpers.AutoGridAnchor, -- MANDATORY when in autogrid anchoring mode (add .verticalIndex and .horizontalIndex    internal use)
		-- add other options
	}

	local HelloWorldPluginShortDescription = "Hello world"
	local HelloWorldPluginLongDescription = "Display hellow world when entering world"

	ClassMonitor_ConfigUI:NewPluginDefinition(HelloWorldPluginName, HelloWorldPluginOptions, HelloWorldPluginShortDescription, HelloWorldPluginLongDescription) -- add plugin definition in ClassMonitor_ConfigUI
end
```
