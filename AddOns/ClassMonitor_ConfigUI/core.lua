local ADDON_NAME, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions
local G = Engine.Globals

local AC = LibStub("AceConfig-3.0-ElvUI")
local ACD = LibStub("AceConfigDialog-3.0-ElvUI")
local ACR = LibStub("AceConfigRegistry-3.0-ElvUI")

assert(AC, "AceConfig-3.0 library not found")
assert(ACD, "AceConfigDialog-3.0 library not found")
assert(ACR, "AceConfigRegistry-3.0 library not found")

----------------------------------------------------------------------------------------
StaticPopupDialogs["CLASSMONITOR_CONFIG_RL"] = {
	text = L.CLASSMONITOR_CONFIG_RL,
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = false,
}

----------------------------------------------------------------------------------------
local function HookAce3OnHide(ACD, addonName)
	if not ACD.OpenFrames[addonName] or not ACD.OpenFrames[addonName].frame then return end
	if ACD.OpenFrames[addonName].frame.ClassMonitor_ConfigUI_Hooked then return end
--print("HookAce3OnHide:"..tostring(ACD.OpenFrames[ADDON_NAME].frame))
	ACD.OpenFrames[addonName].frame.ClassMonitor_ConfigUI_Hooked = true
	ACD.OpenFrames[addonName].frame:HookScript("OnHide", function(self)
--print("OnHide:"..tostring(self).."  "..tostring(G.ConfigModified))
		if G.ConfigModified == true then
			StaticPopup_Show("CLASSMONITOR_CONFIG_RL")
			G.ConfigModified = false
		end
	end)
end

----------------------------------------------------------------------------------------
local function BuildAce3Options()
	local options = {
		type = "group",
		--childGroups = "tree", -- default
		--childGroups = "select",
		--childGroups = "tab",
		name = "Class Monitor",
		args = {
		},
		order = 500
	}
	local index = 1
	-- Add global width option
	options.args["GlobalWidth"] = D.Globals.CreateGlobalWidthOption(index)
	index = index + 1
	-- Add global width option
	options.args["GlobalHeight"] = D.Globals.CreateGlobalHeightOption(index)
	index = index + 1
	-- Add reset option
	options.args["Reset"] = D.Globals.CreateResetOption(index)
	index = index + 1
	-- Add create new plugin option
	if G.PluginCreateFunction and type(G.PluginCreateFunction) == "function" then
		options.args["NewInstance"] = D.Globals.CreateNewPluginInstanceOption(index)
		index = index + 1
	end
	-- Add autogrid anchor option
	if G.AutoGridAnchorFunction and type(G.AutoGridAnchorFunction) == "function" then
		options.args["AutoGridAnchor"] = D.Globals.CreateAutoGridAnchorOption(index)
		index = index + 1
	end
	-- Add debug/release
	options.args["Debug"] = D.Globals.CreateDebugModeOption(index)
	-- Add options for every section in config
	for i, section in pairs(G.Config) do
		if section.kind ~= "MOVER" then -- can't configure MOVER
			local definition = D[section.kind] or D.DefaultPluginDefinition
			-- create new entry
			options.args[section.name] = D.Globals.CreateOptionFromDefinition(definition, index, section)
			index = index + 1
		end
	end
	return options
end

-- if ElvUI then
	-- local E = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB, Localize Underscore

	-- --
	-- Engine.InitializeConfigUI = function(config, savedPerChar, savedPerAccount, updatePluginFunction, createPluginFunction, deletePluginFunction, autoGridAnchorFunction, getPluginListFunction)
		-- -- Set globals
		-- G.Config = config
		-- G.SavedPerChar = savedPerChar
		-- G.SavedPerAccount = savedPerAccount
		-- G.PluginUpdateFunction = updatePluginFunction
		-- G.PluginCreateFunction = createPluginFunction
		-- G.PluginDeleteFunction = deletePluginFunction
		-- G.AutoGridAnchorFunction = autoGridAnchorFunction
		-- G.GetPluginListFunction = getPluginListFunction
		-- --
		-- E.Options.args.ClassMonitor = BuildAce3Options() -- no need to add a root node, ElvUI config panel is our root node
		-- HookAce3OnHide(ACD, "ElvUI")
		-- --
		-- G.Options = E.Options.args.ClassMonitor
	-- end
	-- --
	-- Engine.DisplayConfigFrame = function()
		-- --
		-- G.ConfigModified = false
		-- --
		-- E:ToggleConfig()
		-- ACD:SelectGroup("ElvUI", "ClassMonitor") -- try to select classmonitor node
	-- end
-- elseif Tukui then
	-- local blizOptions = nil

	-- Engine.InitializeConfigUI = function(config, savedPerChar, savedPerAccount, updatePluginFunction, createPluginFunction, deletePluginFunction, autoGridAnchorFunction, getPluginListFunction)
		-- -- Set globals
		-- G.Config = config
		-- G.SavedPerChar = savedPerChar
		-- G.SavedPerAccount = savedPerAccount
		-- G.PluginUpdateFunction = updatePluginFunction
		-- G.PluginCreateFunction = createPluginFunction
		-- G.PluginDeleteFunction = deletePluginFunction
		-- G.AutoGridAnchorFunction = autoGridAnchorFunction
		-- G.GetPluginListFunction = getPluginListFunction
		-- --[[
-- print("NEW CONFIG")
		-- -- create options
		-- local options = BuildAce3Options()
		-- -- add to AceConfig and blizzard menu
		-- --                       addon name
		-- ACR:RegisterOptionsTable("ClassMonitor", options)
		-- --                                 addon name       display name         path
		-- blizOptions = ACD:AddToBlizOptions("ClassMonitor", "Class Monitor", nil, "GeneralOptions") -- save blizzard options entry point to be used in DisplayConfigFrame
		-- for k, v in pairs(options.args) do
-- print("SUB MENU:"..tostring(k))
			-- if k ~= "GeneralOptions" then
				-- -- add to blizzard menu
				-- --                                 addon name                                            parent display name | path
				-- ACD:AddToBlizOptions("ClassMonitor", v.displayName or v.name, "Class Monitor", v.name)
			-- end
		-- end
		-- --]]
		-- --
		-- local options = BuildAce3Options()
		-- local rootNode = { -- add a root node, to get a tree with general/global options on ClassMonitor and plugins as children of ClassMonitor
			-- type = "group",
			-- --childGroups = "tree", -- default
			-- --childGroups = "select",
			-- --childGroups = "tab",
			-- name = "Class Monitor",
			-- args = {
				-- ClassMonitor = options,
			-- }
		-- }
		-- AC:RegisterOptionsTable("ClassMonitor", rootNode)
		-- --
		-- G.Options = rootNode.args.ClassMonitor
	-- end
	-- --
	-- Engine.DisplayConfigFrame = function()
		-- --
		-- G.ConfigModified = false
		-- --
		-- --InterfaceOptionsFrame_OpenToCategory(blizOptions)
		-- ACD:SetDefaultSize("ClassMonitor", 640, 480)
		-- ACD:Open("ClassMonitor")
		-- HookAce3OnHide(ACD, "ClassMonitor")
	-- end
-- else
	Engine.InitializeConfigUI = function(config, savedPerChar, savedPerAccount, updatePluginFunction, createPluginFunction, deletePluginFunction, autoGridAnchorFunction, getPluginListFunction)
		-- Set globals
		G.Config = config
		G.SavedPerChar = savedPerChar
		G.SavedPerAccount = savedPerAccount
		G.PluginUpdateFunction = updatePluginFunction
		G.PluginCreateFunction = createPluginFunction
		G.PluginDeleteFunction = deletePluginFunction
		G.AutoGridAnchorFunction = autoGridAnchorFunction
		G.GetPluginListFunction = getPluginListFunction
		--
		local options = BuildAce3Options()
		local rootNode = { -- add a root node, to get a tree with general/global options on ClassMonitor and plugins as children of ClassMonitor
			type = "group",
			name = "Class Monitor",
			args = {
				ClassMonitor = options,
			}
		}
		AC:RegisterOptionsTable("ClassMonitor", rootNode)
		--AC:RegisterOptionsTable("ClassMonitor", options)
		--
		G.Options = rootNode.args.ClassMonitor
	end
	--
	Engine.DisplayConfigFrame = function()
		--
		G.ConfigModified = false
		--
		ACD:SetDefaultSize("ClassMonitor", 640, 480)
		ACD:Open("ClassMonitor")
		HookAce3OnHide(ACD, "ClassMonitor")
	end
--end