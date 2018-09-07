local _, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions
local G = Engine.Globals

D.Globals = {}

----------------------------------------------------------------------------------------
-- Create an Ace3 config from a plugin definition, add arg with keyValue, sectionNode and parentNode
local function SetArgRecursively(option, keyValue, sectionNode, parentNode)
	option.arg = {key = keyValue, section = sectionNode, parent = parentNode} -- TODO: if option already has .arg, merge both .arg
	if option.args then
		for k, v in pairs(option.args) do
			SetArgRecursively(v, keyValue, sectionNode, option)
		end
	end
end

local function GetDisplayName(info)
	-- get displayName or name and appends (*) if plugin is disabled
	local displayName = info.arg.section.displayName or info.arg.section.name or info.arg.section.kind or "UNKNOWN"
--print("DISPLAY:"..tostring(displayName).."  "..tostring(info.arg.section.__invalid).."  "..tostring(info.arg.section.enabled))
	if info.arg.section.__invalid == true then
		displayName = displayName .. "(**)"
	elseif info.arg.section.enabled == false then
		displayName = displayName .. "(*)"
	end
	return displayName
end

local function GetDeletePluginButtonConfirmationText(info)
	return string.format(L.CLASSMONITOR_DELETEPLUGIN_CONFIRM, info.arg.section.displayName or info.arg.section.name)
end

local function DeletePluginInstance(info)
	local pluginName = info.arg.section.name
	local invalid = info.arg.section.__invalid
--print("DELETING plugin instance:"..tostring(pluginName))
	-- delete option
	G.Options.args[pluginName] = nil
	-- "delete" from saved variables
	G.SavedPerChar.Plugins[pluginName] = { __deleted = true } -- we don't delete it, we just remove every setting and set deleted to true
	-- disable plugin
	if invalid ~= true then
		if G.PluginDeleteFunction and type(G.PluginDeleteFunction) == "function" then
			G:PluginDeleteFunction(info.arg.section.kind, pluginName)
		end
	end
	-- change frame using deleted plugin as anchor
	for k, setting in pairs(G.Config) do
		if setting.anchor and setting.anchor[2] == pluginName then
			setting.anchor = Engine.DeepCopy(info.arg.section.anchor)
			G.SavedPerChar.Plugins[setting.name] = G.SavedPerChar.Plugins[setting.name] or {}
			G.SavedPerChar.Plugins[setting.name].anchor = Engine.DeepCopy(setting.anchor)
			-- TODO: save value
			G:PluginUpdateFunction(setting.kind, setting.name)
		end
	end
	-- delete from config
	local indexToDelete = nil
	for k, setting in pairs(G.Config) do
		if setting.name == pluginName then
			indexToDelete = k
			break
		end
	end
	if indexToDelete then
--print("DELETE FROM CONFIG:"..tostring(pluginName))
		G.Config[indexToDelete] = nil
	end
	-- rebuild auto anchor
	if invalid ~= true then
		if G.SavedPerChar.Global.autogridanchor == true then -- reapply autogridanchor
			if G.AutoGridAnchorFunction and type(G.AutoGridAnchorFunction) == "function" then
				G:AutoGridAnchorFunction(G.Config, G.SavedPerChar.Global.width, G.SavedPerChar.Global.height, G.SavedPerChar.Global.autogridanchorspacing)
			end
		end
	end

--[[
	local parent = info.arg.section.anchor[2]
	local parentFrame = _G[parent]
	local parentTop = parentFrame:GetTop()
	local parentBottom = parentFrame:GetBottom()
	local parentLeft = parentFrame:GetLeft()
	local parentRight = parentFrame:GetRight()
print(tostring(pluginName).."  PARENT:"..tostring(parent).."  "..tostring(parentTop).."  "..tostring(parentBottom).."  "..tostring(parentLeft).."  "..tostring(parentRight))
	-- change frame using deleted plugin as anchor
	for k, setting in pairs(G.Config) do
		if setting.anchor and setting.anchor[2] == pluginName then
			local frame = _G[setting.name]
			local top = frame:GetTop()
			local bottom = frame:GetBottom()
			local left = frame:GetLeft()
			local right = frame:GetRight()
			local VPos = "TOP"
			local VDiff = 0
			if parentTop <= top then
				VPos = "TOP"
				VDiff = top-parentTop
			else
				VPos = "BOTTOM"
			end
			local HPos = "LEFT"
			if parentLeft <= left then
				HPos = "LEFT"
			else
				HPos = "RIGHT"
			end
		end
	end
--]]
end

local DeleteButtonOption = {
	name = L.Delete,
	desc = L.DeleteDesc,
	type = "execute",
	func = DeletePluginInstance,
	confirm = GetDeletePluginButtonConfirmationText,
}

D.Globals.CreateOptionFromDefinition = function(definition, orderID, sectionNode, ...)
	local options = {
		order = orderID,
		type = "group",
		--name = sectionNode.displayName or sectionNode.name,
		name = GetDisplayName,
		arg = {section = sectionNode}, -- to be coherent with subnodes
        args = {}
	}
	if sectionNode.__invalid ~= true then -- invalid plugin can only be deleted
		for k, v in pairs(definition) do
			-- clone
			local option = Engine.DeepCopy(v) -- clone to avoid modifying original option definition
			-- remove key
			option.key = nil
			-- add order
			option.order = k
			-- add arg
			SetArgRecursively(option, v.key, sectionNode, options)
			-- change entries
			for i = 1, select("#", ...), 2 do
				local entry, value = select(i, ...)
				if not entry then break end
				option[entry] = value
			end
			-- save copy
			options.args[v.key] = option
		end
	end
	-- add delete button if not found
	if not options.args.delete then
		options.args.delete = Engine.DeepCopy(DeleteButtonOption)
		options.args.delete.order = 0 -- first
		options.args.delete.arg = {section = sectionNode} -- to be coherent with other subnodes
	end
	return options
end

----------------------------------------------------------------------------------------
-- Global width
local function GetGlobalWidth(info)
	if G.SavedPerChar.Global.width then
		return G.SavedPerChar.Global.width
	else
		-- MOVER is the reference
		for _, section in pairs(G.Config) do
			if section.name == "CM_MOVER" or section.kind == "MOVER" then
				return section.width
			end
		end
		return 262 -- hardcoded default
	end
end

local function SetGlobalWidth(info, value)
	G.SavedPerChar.Global.width = value
	if G.SavedPerChar.Global.autogridanchor == true then
		if G.AutoGridAnchorFunction and type(G.AutoGridAnchorFunction) == "function" then
			G:AutoGridAnchorFunction(G.Config, G.SavedPerChar.Global.width, G.SavedPerChar.Global.height, G.SavedPerChar.Global.autogridanchorspacing)
		end
	else
		local updated = false
		for _, section in pairs(G.Config) do
			if section.width then
				section.width = value
				G.SavedPerChar.Plugins[section.name] = G.SavedPerChar.Plugins[section.name] or {}
				G.SavedPerChar.Plugins[section.name].width = value
				updated = G.PluginUpdateFunction and G:PluginUpdateFunction(section.kind, section.name) or false
			end
		end
		if not updated then
			-- something modified, -> /reloadui
			G.ConfigModified = true
		end
	end
end

D.Globals.CreateGlobalWidthOption = function(index)
	return {
		name = L.GlobalWidth,
		desc = L.GlobalWidthDesc,
		order = index,
		--guiInline = true,
		type = "range",
		arg = {key = "width"},
		min = 80, max = 300, step = 1,
		get = GetGlobalWidth,
		set = SetGlobalWidth,
	}
end

----------------------------------------------------------------------------------------
-- Global height
local function GetGlobalHeight(info)
	if G.SavedPerChar.Global.height then
		return G.SavedPerChar.Global.height
	else
		-- MOVER is the reference
		for _, section in pairs(G.Config) do
			if section.name == "CM_MOVER" or section.kind == "MOVER" then
				return section.height
			end
		end
		return 16 -- hardcoded default
	end
end

local function SetGlobalHeight(info, value)
	G.SavedPerChar.Global.height = value
	if G.SavedPerChar.Global.autogridanchor == true then
		if G.AutoGridAnchorFunction and type(G.AutoGridAnchorFunction) == "function" then
			G:AutoGridAnchorFunction(G.Config, G.SavedPerChar.Global.width, G.SavedPerChar.Global.height, G.SavedPerChar.Global.autogridanchorspacing)
		end
	else
		local updated = false
		for _, section in pairs(G.Config) do
			if section.height then
				section.height = value
				G.SavedPerChar.Plugins[section.name] = G.SavedPerChar.Plugins[section.name] or {}
				G.SavedPerChar.Plugins[section.name].height = value
				updated = G.PluginUpdateFunction and G:PluginUpdateFunction(section.kind, section.name) or false
			end
		end
		if not updated then
			-- something modified, -> /reloadui
			G.ConfigModified = true
		end
	end
end

D.Globals.CreateGlobalHeightOption = function(index)
	return {
		name = L.GlobalHeight,
		desc = L.GlobalHeightDesc,
		order = index,
		--guiInline = true,
		type = "range",
		arg = {key = "height"},
		min = 10, max = 50, step = 1,
		get = GetGlobalHeight,
		set = SetGlobalHeight,
	}
end

----------------------------------------------------------------------------------------
-- Reset
local function ResetConfig()
	-- delete data per char
	for k, v in pairs(G.SavedPerChar) do
		G.SavedPerChar[k] = nil
	end
	-- delete data per realm
	for k, v in pairs(G.SavedPerAccount) do
		G.SavedPerAccount[k] = nil
	end
	G.SavedPerChar.Global = { -- crash if we don't recreate at least an empty array
	}
	-- reload
	ReloadUI()
end

function D.Globals.CreateResetOption(index)
	return {
		name = L.GlobalReset,
		desc = L.GlobalResetDesc,
		order = index,
		type = "execute",
		func = ResetConfig,
		confirm = true,
		confirmText = L.CLASSMONITOR_RESETCONFIG_CONFIRM
	}
end

----------------------------------------------------------------------------------------
-- Auto anchor
D.Globals.IsNormalAnchorDisabled = function(info)
	return G.SavedPerChar.Global.autogridanchor
end

D.Globals.IsAutoAnchorDisabled = function(info)
	return not G.SavedPerChar.Global.autogridanchor
end

local function GetAutoGridAnchor(info)
	return G.SavedPerChar.Global.autogridanchor
end

local function SetAutoGridAnchor(info, value)
	G.SavedPerChar.Global.autogridanchor = value
	if value == true then
		if G.AutoGridAnchorFunction and type(G.AutoGridAnchorFunction) == "function" then
			G:AutoGridAnchorFunction(G.Config, G.SavedPerChar.Global.width, G.SavedPerChar.Global.height, G.SavedPerChar.Global.autogridanchorspacing)
		end
	else
		for _, section in pairs(G.Config) do
			if G.PluginUpdateFunction and type(G.PluginUpdateFunction) == "function" then
				G:PluginUpdateFunction(section.kind, section.name)
			end
		end
	end
end

local function GetAutoGridAnchorSpacing(info)
	return G.SavedPerChar.Global.autogridanchorspacing or 3 -- default value
end

local function SetAutoGridAnchorSpacing(info, value)
	G.SavedPerChar.Global.autogridanchorspacing = value
	if G.SavedPerChar.Global.autogridanchor == true then -- reapply autogridanchor
		if G.AutoGridAnchorFunction and type(G.AutoGridAnchorFunction) == "function" then
			G:AutoGridAnchorFunction(G.Config, G.SavedPerChar.Global.width, G.SavedPerChar.Global.height, G.SavedPerChar.Global.autogridanchorspacing)
		end
	end
end

local function GetAutoGridAnchorConfirmationText(info)
	if G.SavedPerChar.Global.autogridanchor ~= true then -- only when not activated
		return L.CLASSMONITOR_SWITCHAUTOGRIDANCHOR_CONFIRM
	else
		return false
	end
end

D.Globals.CreateAutoGridAnchorOption = function(index)
	return {
		name = L.GlobalAutoGridAnchor,
		desc = L.GlobalAutoGridAnchorDesc,
		order = index,
		type = "group",
		order = index,
		guiInline = true,
		args = {
			enable = {
				order = 1,
				name = L.GlobalAutoGridAnchorEnabled,
				desc = L.GlobalAutoGridAnchorEnabledDesc,
				type = "toggle",
				get = GetAutoGridAnchor,
				set = SetAutoGridAnchor,
				confirm = GetAutoGridAnchorConfirmationText,
			},
			spacing = {
				order = 2,
				name = L.GlobalAutoGridAnchorSpacing,
				desc = L.GlobalAutoGridAnchorSpacingDesc,
				type = "range",
				min = 1, max = 10, step = 1,
				get = GetAutoGridAnchorSpacing,
				set = SetAutoGridAnchorSpacing,
				disabled = D.Globals.IsAutoAnchorDisabled,
			}
		}
	}
end

----------------------------------------------------------------------------------------
-- New plugin instance
local newPlugin = { -- this instance is modified, then cloned and inserted in config
	name = "", -- set when kind is changed
	displayName = "",
	kind = "",
}

local function GetNewPluginValue(info)
	return newPlugin[info[#info]]
end

local function SetNewPluginValue(info, value)
	newPlugin[info[#info]] = value
end

local function SetNewPluginKind(info, value)
	newPlugin.kind = value
	-- create a unique name
	local index = 0
	local name = nil
	local restart = true
	while restart do -- check until a unique name has been created
		restart = false
		name = "CM_"..tostring(value).."_"..tostring(index)
		index = index + 1
		for _, section in pairs(G.Config) do
			if section.name == name or _G[name] ~= nil then -- search in setting and in global cache
				restart = true
				break
			end
		end
	end
--print("NEW PLUGIN NAME:"..tostring(name))
	newPlugin.name = name
end

local function GetCreateNewPluginButtonConfirmationText(info)
	return string.format(L.CLASSMONITOR_CREATENEWPLUGIN_CONFIRM, newPlugin.displayName, newPlugin.kind) -- TODO: localized kind
end

local function GetPluginDescription(info)
	--return L["PluginDescription_"..tostring(newPlugin.kind)] or newPlugin.kind
--print("PLUGIN:["..tostring(newPlugin.kind).."]")
	return newPlugin.kind ~= "" and (Engine.Descriptions[newPlugin.kind].long or L.NoPluginDescription) or ""
end

local function IsCreateNewPluginButtonHidden(info)
--print(tostring(not newPlugin.kind).."  "..tostring(newPlugin.kind == "").."  "..tostring(not newPlugin.displayName).."  "..tostring(newPlugin.displayName == "").." -- "..tostring(newPlugin.kind).."  "..tostring(newPlugin.displayName))
	return not newPlugin.kind or newPlugin.kind == "" or not newPlugin.displayName or newPlugin.displayName == ""
end

local function CreateNewPluginInstance(info)
    -- set plugin instance default config here
	local plugin = {
		name = newPlugin.name,
		kind = newPlugin.kind,
		displayName = newPlugin.displayName,
		enabled = false, -- disabled by default
		autohide = true,
		width = G.SavedPerChar.Global.width,
		height = G.SavedPerChar.Global.height,
		specs = {"any"},
		anchor = {"CENTER", "UIParent", "CENTER", 0, 0}, -- dummy value
		verticalIndex = 10, -- dummy value
		horizontalIndex = 0 -- dummy value
	}
	-- autogrid vertical index is set upmost (positive index) and horizontal is set leftmost
	local maxVerticalIndex = 0
	for _, setting in pairs(G.Config) do
--print(tostring(setting.name).."  "..tostring(setting.verticalIndex))
		if setting.kind ~= "MOVER" and setting.verticalIndex and maxVerticalIndex <= setting.verticalIndex then
--print("changing MAX")
			maxVerticalIndex = setting.verticalIndex + 1
		end
	end
	if maxVerticalIndex > 20 then -- if max is 21, we are on the last line maybe not alone, find leftmost
		-- check other one the line only if 
		plugin.verticalIndex = 20
		local maxHorizontalIndex = 0
		for _, setting in pairs(G.Config) do
			if setting.kind ~= "MOVER" and setting.verticalIndex and setting.verticalIndex == plugin.verticalIndex then
				if setting.horizontalIndex and maxHorizontalIndex <= setting.horizontalIndex then
					maxHorizontalIndex = setting.horizontalIndex + 1
				end
			end
		end
		if maxHorizontalIndex > 9 then -- from 0 to 9
			maxHorizontalIndex = 9
		end
		plugin.horizontalIndex = maxHorizontalIndex
	else
		-- alone on a line
		plugin.horizontalIndex = 0
		plugin.verticalIndex = maxVerticalIndex
	end
	-- attach frame to most bottom frame and leftmost (lowest bottom value)
	-- this is the actual position, if autogrid anchor is set we'll receive these values
	local bottomFrameName = nil
	local bottomValue = GetScreenHeight()
	local leftValue = 0
	for k, setting in pairs(G.Config) do
		local frame = _G[setting.name]
		local bottom = frame:GetBottom()
		local left = frame:GetLeft()
--print(tostring(setting.name).."  BOTTOM:"..tostring(bottom).."  LEFT:"..tostring(left))
		if not bottomFrameName or bottom < bottomValue then
--print("UPDATE TOP")
			bottomValue = bottom
			leftValue = left
			bottomFrameName = setting.name
		elseif bottom == bottomValue and left < leftValue then
--print("UPDATE LEFT")
			leftValue = left
			bottomFrameName = setting.name
		end
	end
	if bottomFrameName then
--print("FRAME"..tostring(bottomFrameName).." -> "..tostring(bottomValue).."  "..tostring(leftValue))
		plugin.anchor = {"TOPLEFT", bottomFrameName, "BOTTOMLEFT", 0, -3}
	else
		-- no bottom frame found, set anchor to center
		plugin.anchor = {"CENTER", "UIParent", "CENTER", 0, 0}
	end
	--
--print("CREATE NEW PLUGIN:"..tostring(plugin.name).."  "..tostring(plugin.displayName).."  "..tostring(plugin.kind))
	local instance = nil
	-- create plugin instance, call initialize method
	if G.PluginCreateFunction and type(G.PluginCreateFunction) == "function" then
		instance = G:PluginCreateFunction(plugin.kind, plugin.name, plugin)
	end
	if instance then
--print("INSTANCE CREATED")
		-- add plugin to saved variables
		G.SavedPerChar.Plugins[plugin.name] = Engine.DeepCopy(plugin) -- overwrite existing if any (may happen with .__deleted == true)   create a copy to avoid saving internal value added later in plugin setting such as autogridanchor, autogridwidth, autogridheight
		-- add plugin to config
		tinsert(G.Config, plugin)
		-- add entry in options 
		local definition = D[plugin.kind] or D.DefaultPluginDefinition
		G.Options.args[plugin.name] = D.Globals.CreateOptionFromDefinition(definition, 100--[[TODO get last index--]], plugin)
		-- rebuild auto anchor
		if G.SavedPerChar.Global.autogridanchor == true then -- reapply autogridanchor
			if G.AutoGridAnchorFunction and type(G.AutoGridAnchorFunction) == "function" then
				G:AutoGridAnchorFunction(G.Config, G.SavedPerChar.Global.width, G.SavedPerChar.Global.height, G.SavedPerChar.Global.autogridanchorspacing)
			end
		end
	end
	-- reset new plugin
	newPlugin.name = ""
	newPlugin.displayName = ""
	newPlugin.kind = ""
end

D.Globals.CreateNewPluginInstanceOption = function(index)
	-- kind
	local kindOption = Engine.DeepCopy(D.Helpers.Kind) -- clone kind to avoid modifying original option definition
	kindOption.get = GetNewPluginValue
	kindOption.set = SetNewPluginKind
	kindOption.disabled = false
	kindOption.order = 1
	kindOption.key = nil -- not used
	-- displayName
	local displayNameOption = Engine.DeepCopy(D.Helpers.DisplayName) -- clone displayName to avoid modifying original option definition
	displayNameOption.get = GetNewPluginValue
	displayNameOption.set = SetNewPluginValue
	displayNameOption.disabled = false
	displayNameOption.order = 2
	displayNameOption.key = nil -- not used
	--
	return {
		name = L.GlobalNewPluginInstance,
		desc = L.GlobalNewPluginInstanceDesc,
		order = index,
		type = "group",
		guiInline = true,
		args = {
			kind = kindOption,
			displayName = displayNameOption,
			kindDescription = {
				name = GetPluginDescription,
				order = 3,
				type = "description",
			},
			create = {
				name = L.GlobalCreateNewPluginButton,
				desc = L.GlobalCreateNewPluginButtonDesc,
				order = 4,
				type = "execute",
				func = CreateNewPluginInstance,
				confirm = GetCreateNewPluginButtonConfirmationText,
				hidden = IsCreateNewPluginButtonHidden
			}
		}
	}
end

----------------------------------------------------------------------------------------
-- Debug/Release mode
D.Globals.IsInReleaseMode = function(info)
	return not G.SavedPerChar.Global.debug
end

local function GetDebugMode(info)
	return G.SavedPerChar.Global.debug
end

local function SetDebugMode(info, value)
	G.SavedPerChar.Global.debug = value
end

D.Globals.CreateDebugModeOption = function(index)
	return {
		name = L.GlobalDebugMode,
		desc = L.GlobalDebugModeDesc,
		order = index,
		type = "toggle",
		get = GetDebugMode,
		set = SetDebugMode
	}
end