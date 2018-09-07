local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end

local UI = Engine.UI
local L = Engine.Locales
local C = Engine.Config

local CMDebug = false

local settings = C[UI.MyClass]
if not settings then return end

local DefaultBoolean = Engine.DefaultBoolean
local DeepCopy = Engine.DeepCopy

local function WARNING(line)
	print("|CFFFF0000ClassMonitor|r: WARNING - "..line)
end

local function DEBUG(line)
	if not CMDebug or CMDebug == false then return end
	print("|CFF0000FFClassMonitor|r: DEBUG - "..line)
end

-- Config management
local function UpgradeConfig(saved, savedVersion, version)
	for saved_key, saved_setting in pairs(saved) do
		if Engine.CompareVersion("3.4.3.0", savedVersion) < 0 then -- older
			if saved_setting.deleted ~= nil then -- .delete ==> .__deleted
				saved_setting.__deleted = saved_setting.deleted
				saved_setting.deleted = nil
			end
			if saved_setting.enable ~= nil then -- .enable ==> .enabled
				saved_setting.enabled = saved_setting.enable
				saved_setting.enable = nil
			end
		end
	end
end

local function MergeConfig(config, saved)
	for _, config_setting in pairs(config) do
		local savedEntry = nil
		for saved_key, saved_setting in pairs(saved) do
			if saved_key == config_setting.name then
				savedEntry = saved_setting
				break
			end
		end
		if savedEntry then
			if savedEntry.__deleted == true then
				config_setting.__deleted = true -- set to deleted
			else
				-- overwrite value from saved to config
				for key, value in pairs(config_setting) do
					if key ~= "name" and savedEntry[key] ~= nil then
						config_setting[key] = DeepCopy(savedEntry[key])
					end
				end
				-- add new entry from saved to config
				for key, value in pairs(savedEntry) do
					if config_setting[key] == nil then
						config_setting[key] = DeepCopy(value)
					end
				end
			end
		end
	end
	for saved_key, saved_setting in pairs(saved) do
		if saved_setting.__deleted ~= true then
			local found = false
			for _, config_setting in pairs(config) do
				if saved_key == config_setting.name then
--print("FOUND:"..tostring(saved_key))
					found = true
					break
				end
			end
			if not found then
--print("NOT FOUND:"..tostring(saved_key).."  "..tostring(saved_setting.kind).."  "..tostring(saved_setting.name))
				if saved_setting.kind and saved_setting.name then
					tinsert(config, DeepCopy(saved_setting))
				-- else: entry probably added in profiles.lua, modified in config and not found anymore in profiles.lua
				end
			end
		end
	end
end

local function CleanConfig()
	-- Remove non-class specific config
	for class in pairs(C) do
		if class ~= UI.MyClass then
			C[class] = nil
		end
	end
	-- Delete deleted and remove invalid option
	for i, setting in pairs(settings) do
		if setting.__deleted == true then
			settings[i] = nil
		else
			setting.__autogridanchor = nil
			setting.__autogridwidth = nil
			setting.__autogridheight = nil
			setting.__processed = nil
		end
	end
end

-- Plugins
local function CreatePlugins() -- Plugins must be created on PLAYER_LOGIN to allow external addon to add own plugins and plugins to use PLAYER_ENTERING_WORLD
	local creationOrder = {} -- frame creation order relatively to anchoring
	-- Fix anchor problem
	local processedFrames = {}
	processedFrames["UIParent"] = true
	processedFrames["CM_MOVER"] = true
	while true do
		-- plugins anchored to already processed plugins are added to processed
		local processed = 0 -- count number of plugin processed in this loop
		local notProcessed = 0 -- count number of plugin not created in this loop (invalid anchor)
		local unknownFrames = {}
		for _, setting in pairs(settings) do
			if not processedFrames[setting.name] and setting.__deleted ~= true then
				if not setting.anchor then
					-- no anchor, set dummy one
--print("NO ANCHOR:"..tostring(setting.name))
					setting.anchor = {"CENTER", "CM_MOVER", "CENTER", 0, 0}
					processedFrames[setting.name] = true
				else
					local anchorName = setting.anchor[2]
					--if _G[anchorName] then
					if processedFrames[anchorName] then
						-- anchor found
						processedFrames[setting.name] = true
						tinsert(creationOrder, setting)
						processed = processed + 1
--print("OK:"..tostring(setting.name).."  "..tostring(anchorName))
					else
--print("KO:"..tostring(setting.name).."  "..tostring(anchorName))
						-- keep number of frames pointing to an unknown frame
						if not unknownFrames[anchorName] then unknownFrames[anchorName] = {count = 0, list = {}} end
						unknownFrames[anchorName].count = unknownFrames[anchorName].count + 1
						tinsert(unknownFrames[anchorName].list, setting)
						notProcessed = notProcessed + 1
					end
				end
			end
		end
--print("LOOP COMPLETE:"..tostring(processed).."  "..tostring(notProcessed))
		if 0 == notProcessed then -- DONE, everything is processed
			break
		end
		if 0 == processed then -- no plugin processed in this loop -> cycle -> break it   or  pointer to invalid frame -> set to dummy value
--print("NO FRAMES CREATED")
			-- check & fix invalid frames
			local fixed = 0
			for frameName, info in pairs(unknownFrames) do
				-- search if unknown anchor is in frame list
				local found = false
				for _, setting in pairs(settings) do
					if setting.name == frameName then
						found = true
						break
					end
				end
				if not found then -- invalid frame, will never be found in our own frames -> set dummy anchor and a display warning
					for _, setting in pairs(info.list) do
--print("INVALID:"..tostring(setting.name).."  "..tostring(setting.anchor[2]).."  "..tostring(unknownFrames[setting.anchor[2]].count).." -> RESET ANCHOR")
						setting.anchor = {"CENTER", "CM_MOVER", "CENTER", 0, 0}
						processedFrames[setting.name] = true
						tinsert(creationOrder, setting)
						if ClassMonitorDataPerChar.Global.autogridanchor ~= true then
							WARNING("Invalid anchor for plugin instance '"..(setting.displayName or setting.name or setting.kind or "UNKNOWN").."'. Setting anchor to default mover. Please change it with config UI")
						end
						fixed = fixed + 1
					end
				end
			end
			if 0 == fixed then -- fix remaining frames only if no invalid frame found
--print("FIXING CYCLE")
				-- find plugin anchoring most plugins
				local maxCount = 0
				local bestGuess = nil
				for name, info in pairs(unknownFrames) do
					if not processedFrames[name] and (not bestGuess or maxCount < info.count) then
						bestGuess = name
						maxCount = info.count
					end
				end
				if bestGuess then -- most anchored plugin found -> set dummy anchor and a display warning
					for _, setting in pairs(settings) do
						if setting.name == bestGuess then
--print("CYCLE OR END OF CHAIN:"..tostring(setting.name).."  "..tostring(bestGuess).."  "..tostring(unknownFrames[bestGuess].count).." -> RESET ANCHOR")
							setting.anchor = {"CENTER", "CM_MOVER", "CENTER", 0, 0}
							processedFrames[setting.name] = true
							tinsert(creationOrder, setting)
							if ClassMonitorDataPerChar.Global.autogridanchor ~= true then
								WARNING("Anchor cycle detected for plugin instance '"..(setting.displayName or setting.name or setting.kind or "UNKNOWN").."'. Setting anchor to default mover. Please change it with config UI")
							end
							break -- plugin name are unique, no need to continue
						end
					end
				else
					-- SHOULD NEVER HAPPEN -> FIX EVERYTHING
					ERROR("Problem while fixing anchors. Resetting every invalid anchor to default mover. Please change them with config UI")
					for _, setting in pairs(settings) do
						if setting.kind ~= "MOVER" and not processedFrames[setting.name] then
							setting.anchor = {"CENTER", "CM_MOVER", "CENTER", 0, 0}
							processedFrames[setting.name] = true
							tinsert(creationOrder, setting)
						end
					end
				end
			end
		end
		wipe(unknownFrames)
	end
	wipe(processedFrames)

	-- Create plugins using creation order table
	for i, setting in ipairs(creationOrder) do
--print("NAME:"..tostring(setting.name).."  "..tostring(i))
		if type(setting) == "table" and setting.kind ~= "MOVER" then
			if setting.name and setting.kind then
				if not setting.__deleted then -- deleted plugin are not created, disabled plugin (enable == false) are created
					-- set common default values
					setting.enabled = DefaultBoolean(setting.enabled, true)
					setting.width = setting.width or 85
					setting.height = setting.height or 16
					setting.specs = setting.specs or {"any"}
					setting.autohide = DefaultBoolean(setting.autohide, true)
					-- create plugin instance
					local instance = Engine:CreatePluginInstance(setting.kind, setting.name, setting)
					if not instance then
						WARNING("Found saved plugin instance '"..(setting.displayName or setting.name).."' of unknown kind '"..tostring(setting.kind).."'")
						setting.__invalid = true -- instance not created, invalidate config entry
					end
				end
			else
				setting.__invalid = true -- instance not created, invalidate config entry
				WARNING("Invalid plugin "..tostring(i).."  "..tostring(setting.name or "UNNAMED").."  "..tostring(setting.kind or "NOKIND"))
			end
		end
	end
	wipe(creationOrder)
	--[[
	-- TODO: I'm ashamed of following code but I don't have time (and too lazy for the moment) to code a better cycle-detection/handling
	local setDummyAnchor = false
	while true do
		local created = 0
		local anchorNotFound = 0
		for i, setting in pairs(settings) do
			if setting.kind ~= "MOVER" and setting.processed ~= true then
				local anchorName = setting.anchor[2]
				if _G[anchorName] or setDummyAnchor then
--print("CREATE PLUGIN:"..tostring(i).."  "..tostring(setting.name).."  "..tostring(setting.kind).."  "..tostring(anchorName).."  "..tostring(setDummyAnchor))
					-- anchor frame found, create plugin
					if setting.name and setting.kind then
						if not setting.__deleted then -- deleted plugin are not created, disabled plugin (enable == false) are created
							if setDummyAnchor then
								setting.anchor = {"CENTER", "CM_MOVER", "CENTER", 0, 0}
								if ClassMonitorDataPerChar.Global.autogridanchor ~= true then
									-- No need to warn about wrong anchors when mode autogrid is set
									WARNING("Invalid anchor for plugin instance '"..(setting.displayName or setting.name).."'. Setting anchor to center of screen")
								end
								setDummyAnchor = false -- retry other plugin now that we have split a cycle
							end
							-- set common default values
							setting.enabled = DefaultBoolean(setting.enabled, true)
							setting.width = setting.width or 85
							setting.height = setting.height or 16
							setting.specs = setting.specs or {"any"}
							setting.autohide = DefaultBoolean(setting.autohide, true)
							-- create plugin instance
							local instance = Engine:CreatePluginInstance(setting.kind, setting.name, setting)
							if not instance then
								WARNING("Found saved plugin instance '"..(setting.displayName or setting.name).."' of unknown kind '"..tostring(setting.kind).."'")
								setting.__invalid = true -- instance not created, invalidate config entry
							end
						end
					else
						setting.__invalid = true -- instance not created, invalidate config entry
						WARNING("Invalid plugin "..tostring(i).."  "..tostring(setting.name or "UNAMED").."  "..tostring(setting.kind or "NOKIND"))
					end
					setting.processed = true
					created = created + 1
				else
					anchorNotFound = anchorNotFound + 1
--print("ANCHOR NOT FOUND:"..tostring(setting.name).."  "..tostring(setting.anchor[2]))
				end
			end
		end
--print("LOOP:"..tostring(created).."  "..tostring(anchorNotFound))
		if 0 == created then
			if 0 == anchorNotFound then
				break
			else
				if setDummyAnchor then
					break -- SHOULD NEVER HAPPEN
				end
				-- every setting not processed has invalid anchor
				setDummyAnchor = true
			end
		end
	end
	--]]
	-- for i, setting in pairs(settings) do
-- --print("CREATE PLUGIN:"..tostring(i).."  "..tostring(setting.name).."  "..tostring(setting.kind))
		-- if setting.name and setting.kind then
			-- if not setting.__deleted then -- deleted plugin are not created, disabled plugin (enable == false) are created
				-- -- set common default values
				-- setting.enabled = DefaultBoolean(setting.enabled, true)
				-- setting.width = setting.width or 85
				-- setting.height = setting.height or 16
				-- setting.specs = setting.specs or {"any"}
				-- setting.autohide = DefaultBoolean(setting.autohide, true)
				-- -- create plugin instance
				-- if setting.kind ~= "MOVER" then
					-- local instance = Engine:CreatePluginInstance(setting.kind, setting.name, setting)
					-- if not instance then
						-- WARNING("Found saved plugin instance '"..(setting.displayName or setting.name).."' of unknown kind '"..tostring(setting.kind).."'")
						-- setting.__invalid = true -- instance not created, invalidate config entry
					-- end
				-- end
			-- end
		-- else
			-- WARNING("Invalid plugin "..tostring(i).."  "..tostring(setting.name or "UNAMED").."  "..tostring(setting.kind or "NOKIND"))
		-- end
	-- end
end

-- Movers
local function CreateMovers() -- Movers must be created on ADDON_LOADED to use auto-saved anchors
	for i, setting in pairs(settings) do
--print("CREATE PLUGIN:"..tostring(i).."  "..tostring(setting.name).."  "..tostring(setting.kind))
		if setting.name and setting.kind then
			if not setting.__deleted then -- deleted plugin are not created, disabled plugin (enable == false) are created
				-- create plugin instance
				if setting.kind == "MOVER" then
					UI.CreateMover(setting.name, setting.width, setting.height, setting.anchor, setting.text or setting.name.."_MOVER")
				end
			end
		end
	end
end

-- Multisampling test
StaticPopupDialogs["CLASSMONITOR_MULTISAMPLE_PROBLEM"] = {
	text = "Pixel perfect border cannot be guaranteed with multisampling activated. Click on accept to disable multisampling or cancel to continue.", -- TODO: locales
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function()
		SetCVar("ffxAntiAliasingMode", 1)
		RestartGx()
	end,
	OnCancel = function()
		ClassMonitorData.MultisamplingChecked = true
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = false,
}
local function CheckMultisampling()
	if GetCVar("ffxAntiAliasingMode") ~= "1" and not ClassMonitorData.MultisamplingChecked then
		StaticPopup_Show("CLASSMONITOR_MULTISAMPLE_PROBLEM")
	end
end

-- Main frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, addon)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")

		-- Create plugins
		CreatePlugins()
		-- Set autogrid anchor if it exists
		if ClassMonitorDataPerChar.Global.autogridanchor == true and Engine.AutoGridAnchor and type(Engine.AutoGridAnchor) == "function" then
			Engine:AutoGridAnchor(settings, ClassMonitorDataPerChar.Global.width, ClassMonitorDataPerChar.Global.height, ClassMonitorDataPerChar.Global.autogridanchorspacing)
		end
		-- Initialize ConfigUI if loaded
		if ClassMonitor_ConfigUI and ClassMonitor_ConfigUI.InitializeConfigUI and type(ClassMonitor_ConfigUI.InitializeConfigUI) == "function" then
			ClassMonitor_ConfigUI.InitializeConfigUI(settings, ClassMonitorDataPerChar, ClassMonitorData, Engine.UpdatePluginInstance, Engine.CreatePluginInstance, Engine.DeletePluginInstance, Engine.AutoGridAnchor, Engine.GetPluginList)
		end
	elseif event == "ADDON_LOADED" and addon == ADDON_NAME then
		self:UnregisterEvent("ADDON_LOADED")

		-- Greetings
		local version = GetAddOnMetadata(ADDON_NAME, "Version")
		local configVersion = GetAddOnMetadata("ClassMonitor_ConfigUI", "Version")
		if configVersion then
			print(string.format(L.classmonitor_greetingwithconfig, tostring(version), tostring(configVersion)))
		else
			print(string.format(L.classmonitor_greetingnoconfig, tostring(version)))
		end
		print(string.format(L.classmonitor_help_use, SLASH_CLASSMONITOR1, SLASH_CLASSMONITOR2))
		--
		ClassMonitorData = ClassMonitorData or {}
		ClassMonitorDataPerChar = ClassMonitorDataPerChar or {}
		if not ClassMonitorDataPerChar.Plugins then
			-- create plugins settings from basic config if not found (old version of saved variables)
			ClassMonitorDataPerChar.Plugins = {}
			for k, v in pairs(ClassMonitorDataPerChar) do
				if k ~= "Global" and k ~= "Plugins" then
					ClassMonitorDataPerChar.Plugins[k] = DeepCopy(ClassMonitorDataPerChar[k]) -- copy setting
					ClassMonitorDataPerChar[k] = nil -- delete old setting
				end
			end
		end
		-- Default global per char variables
		ClassMonitorDataPerChar.Global = ClassMonitorDataPerChar.Global or {}
		local savedVersion = ClassMonitorDataPerChar.Global.version or tostring(version)
		ClassMonitorDataPerChar.Global.version = tostring(version)
		ClassMonitorDataPerChar.Global.configVersion = tostring(configVersion)
		ClassMonitorDataPerChar.Global.debug = DefaultBoolean(ClassMonitorDataPerChar.Global.debug, false)
		ClassMonitorDataPerChar.Global.width = ClassMonitorDataPerChar.Global.width or 262
		ClassMonitorDataPerChar.Global.height = ClassMonitorDataPerChar.Global.height or 16
		ClassMonitorDataPerChar.Global.autogridanchor = DefaultBoolean(ClassMonitorDataPerChar.Global.autogridanchor, false) -- manual anchoring by default
		ClassMonitorDataPerChar.Global.autogridanchorspacing = ClassMonitorDataPerChar.Global.autogridanchorspacing or 3
		-- Convert saved variables from old version to latest
		UpgradeConfig(ClassMonitorDataPerChar.Plugins, savedVersion, version)
		-- Merge config and saved variables
		MergeConfig(settings, ClassMonitorDataPerChar.Plugins)
		-- Check multisampling
		CheckMultisampling()
		-- Clean config
		CleanConfig()
		-- Create movers
		CreateMovers()
	end
end)