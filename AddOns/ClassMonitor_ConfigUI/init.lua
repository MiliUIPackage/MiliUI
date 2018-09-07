local _, Engine = ...

Engine.Locales = {} -- Localized strings
Engine.Globals = {} -- Variables/functions from ClassMonitor received with InitializeConfigUI
Engine.Definitions = {} -- Plugins options
Engine.Descriptions = {} -- Plugins descriptions

--[[
TODO:
	[DONE]test Tukui skin
	[DONE]saved variables
	[DONE]anchor
	colors
	[DONE]add/delete new plugin instances
	[DONE]reload UI when modification are done
	global enable/disable in classmonitor root node
	description in classmonitor root node
	[DONE]global width/height
	[DONE]reload UI only when modification has been done and config panel closed
	[DONE]dont recreate options everytime config panel is opened
	[DONE]add an option to reset to original config
	[DONE]input on number get/set must handle string  (check validatenumber to find them)
	[DONE]auto grid anchor  +  vertical/horizontalIndex in the same group --> dummy key, real key is set in getValue/setValue
	[DONE]width, height in the same group --> dummy key, real key is set in getValue/setValue
	[REMOVED]add spellName input in addition to spellID + add a function to get image instead of using GetSpellIDAndSetSpellIcon
	[DONE]in plugin kind list, only display available plugin
	[DONE]french traduction of kind definition/explanation
--]]