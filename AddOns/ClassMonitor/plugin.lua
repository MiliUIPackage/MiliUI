local ADDON_NAME, Engine = ...
if not Engine.Enabled then return end

local Plugins = {} -- List of plugins

------------------------------------------------
-- plugin class with metatable
------------------------------------------------
local Plugin = {}

------------------------------------------------
-- private ctor
------------------------------------------------
function Plugin:new(name, settings)
	assert(type(name) == "string", "Trying to create a plugin with non-string name")
	local p = {}
--print("self==Plugin: "..tostring(name).."  "..tostring(self).."  "..tostring(Plugin).."  "..tostring(self == Plugin))
	setmetatable(p, self)
	self.__index = self

	if self == Plugin then
--print("New plugin category:"..tostring(name))
		-- plugin category
		p.pluginName = name
		p.instances = {}
	else
		assert(settings and type(settings) == "table", "Missing settings while creating plugin instance "..tostring(name).." kind "..tostring(self.pluginName))
--print("New plugin instance:"..tostring(name))
		-- plugin instance
		p.eventHandler = CreateFrame("Frame")
		p.eventHandler.plugin = p -- loop back :)  used by OnEvent and OnUpdate to get plugin from event handler
		p.name = name
		p.settings = settings
		p.instances[name] = p -- save instance
	end
--[[
	-- add datas
	if not settings then
--print("New plugin category:"..tostring(name))
		-- plugin category
		p.pluginName = name
		p.instances = {}
	else
--print("New plugin instance:"..tostring(name))
		-- plugin instance
		p.eventHandler = CreateFrame("Frame")
		p.eventHandler.plugin = p -- loop back :)
		p.name = name
		p.settings = settings
		p.instances[name] = p -- save instance
	end
--]]
	return p
end

------------------------------------------------
-- private event handler methods
------------------------------------------------
function Plugin:OnEvent(event, ...) -- private
	local self = self.plugin or self
--print(tostring(self.pluginName)..":OnEvent:"..tostring(event).."  "..tostring(self))
	assert(self.eventHandler[event], "No event handler found for event "..tostring(event)..". Plugin: "..tostring(self.name).."/"..tostring(self.pluginName))
	self.eventHandler[event](self, event, ...)
end

function Plugin:OnUpdate(elapsed, ...) -- private
	local self = self.plugin or self
	assert(self.eventHandler["OnUpdate"], "No event handler found for update. Plugin: "..tostring(self.name).."/"..tostring(self.pluginName))
	self.eventHandler["OnUpdate"](self, elapsed)
end

------------------------------------------------
-- public event handler methods
------------------------------------------------
function Plugin:RegisterEvent(event, fct)
--print(tostring(self.pluginName)..":RegisterEvent:"..tostring(event).." "..tostring(fct))
	assert(type(event) == "string", "RegisterEvent event must be a string. Plugin: "..tostring(self.name).."/"..tostring(self.pluginName))
	assert(type(fct) == "function", "RegisterEvent fct must be a function. Plugin: "..tostring(self.name).."/"..tostring(self.pluginName))
	self.eventHandler:RegisterEvent(event)
	self.eventHandler[event] = fct
	self.eventHandler:SetScript("OnEvent", Plugin.OnEvent)
end
function Plugin:RegisterUnitEvent(event, unit, fct)
--print(tostring(self.pluginName)..":RegisterUnitEvent:"..tostring(event).." "..tostring(unit).." "..tostring(fct))
	assert(type(event) == "string", "RegisterUnitEvent event must be a string. Plugin: "..tostring(self.name).."/"..tostring(self.pluginName))
	assert(type(unit) == "string", "RegisterUnitEvent unit must be a string. Plugin: "..tostring(self.name).."/"..tostring(self.pluginName))
	assert(type(fct) == "function", "RegisterUnitEvent fct must be a function. Plugin: "..tostring(self.name).."/"..tostring(self.pluginName))
	self.eventHandler:RegisterUnitEvent(event, unit)
	self.eventHandler[event] = fct
	self.eventHandler:SetScript("OnEvent", Plugin.OnEvent)
end
function Plugin:UnregisterEvent(event)
	assert(type(event) == "string", "RegisterUnitEvent event must be a string. Plugin: "..tostring(self.name).."/"..tostring(self.pluginName))
	self.eventHandler:UnregisterEvent(event)
	self.eventHandler[event] = nil
end
function Plugin:UnregisterAllEvents()
--print(tostring(self.pluginName)..":UnregisterAllEvents")
	self.eventHandler:UnregisterAllEvents()
	-- TODO: remove every event handlers from self.eventHandler
	self.eventHandler:SetScript("OnEvent", nil)
end

function Plugin:RegisterUpdate(fct)
--print(tostring(self.pluginName..":RegisterUpdate")
	assert(type(fct) == "function", "RegisterUpdate fct must be a function. Plugin: "..tostring(self.name).."/"..tostring(self.pluginName))
	self.eventHandler["OnUpdate"] = fct
	self.eventHandler:SetScript("OnUpdate", Plugin.OnUpdate)
end
function Plugin:UnregisterUpdate()
	self.eventHandler:SetScript("OnUpdate", nil)
	self.eventHandler["OnUpdate"] = nil
end

------------------------------------------------
-- public abstract methods
------------------------------------------------
function Plugin:Initialize()
	assert(false, "Missing Initialize method in plugin: "..tostring(self.pluginName))
end
function Plugin:Enable()
	assert(false, "Missing Enable method in plugin: "..tostring(self.pluginName))
end
function Plugin:Disable()
	assert(false, "Missing Disable method in plugin: "..tostring(self.pluginName))
end
function Plugin:SettingsModified()
	assert(false, "Missing SettingsModified method in plugin: "..tostring(self.pluginName))
end

------------------------------------------------
-- public methods
------------------------------------------------

-- Return current anchor in function of anchoring mode
function Plugin:GetAnchor()
--print("GetAnchor:"..tostring(ClassMonitorDataPerChar.Global.autogridanchor).."  "..tostring(settings.__autogridanchor).."  "..tostring(settings.anchor))
	return (ClassMonitorDataPerChar.Global.autogridanchor == true and self.settings.__autogridanchor) or self.settings.anchor
end

-- Return current width in function of anchoring mode
function Plugin:GetWidth()
--print("GetWidth:"..tostring(ClassMonitorDataPerChar.Global.autogridanchor).."  "..tostring(settings.__autogridwidth).."  "..tostring(settings.width))
	return (ClassMonitorDataPerChar.Global.autogridanchor == true and self.settings.__autogridwidth) or self.settings.width
end

-- Return current height in function of anchoring mode
function Plugin:GetHeight()
--print("GetHeight:"..tostring(ClassMonitorDataPerChar.Global.autogridanchor).."  "..tostring(settings.__autogridheight).."  "..tostring(settings.height))
	return (ClassMonitorDataPerChar.Global.autogridanchor == true and self.settings.__autogridheight) or self.settings.height
end

-- Return color depend on current customcolor setting
function Plugin:GetColor(default)
	-- return customized color if customcolor == true, else return the dafault
	--print("GetColor:"..tostring(self.settings.customcolor).."  "..tostring(self.settings.color).."  "..tostring(default))
	return (self.settings.customcolor and self.settings.color) or default
end

function Plugin:IsEnabled()
	return self.settings.enabled
end

------------------------------------------------
-- Plugin factory
------------------------------------------------
-- function Plugin:NewInstance(instanceName, settings)
	-- assert(type(instanceName) == "string", "Instance name must be a string")
	-- assert(not self.instances[instanceName], "Plugin instance "..tostring(instanceName).." already exists")
	-- return self:new(instanceName, settings)
-- end

function Engine:NewPlugin(pluginName)
--print("NEW PLUGIN CATEGORY:"..tostring(pluginName))
	assert(type(pluginName) == "string", "Plugin name must be a string")
	assert(not Plugins[pluginName], "Plugin "..tostring(pluginName).." already exists")

	local p = Plugin:new(pluginName)
	Plugins[pluginName] = p
	return p
end

-- function Engine:GetPlugin(pluginName, instanceName)
	-- assert(type(pluginName) == "string", "Plugin name must be a string")
	-- local p = Plugins[pluginName]
	-- assert(p, "Plugin "..tostring(pluginName).." not found")
	-- if instanceName then
		-- assert(type(instanceName) == "string", "Instance name must be a string")
		-- p = p.instances[instanceName]
	-- end
	-- return p
-- end

function Engine:NewPluginInstance(pluginName, instanceName, settings)
--print("NEW PLUGIN INSTANCE:"..tostring(pluginName).."  "..tostring(instanceName))
	assert(type(pluginName) == "string", "Plugin name must be a string")
	assert(type(instanceName) == "string", "Instance name must be a string")
	assert(settings, "Settings cannot be null")
	local category = Plugins[pluginName]
	--assert(category, "Plugin "..tostring(pluginName).." not found")
	--assert(not category.instances[instanceName], "Plugin instance "..tostring(instanceName).." already exists")
	--return category:new(instanceName, settings)
--print("NEW INSTANCE:"..tostring(category.instances[instanceName]))
	if not category or category.instances[instanceName] then
		return nil
	end
	return category:new(instanceName, settings)
end

------------------------------------------------
-- Update plugin instance settings
------------------------------------------------
function Engine:UpdatePluginInstance(pluginName, instanceName)
	-- TODO: remove this workaround
	if pluginName == "MOVER" then return true end

	-- get instance
	assert(type(pluginName) == "string", "Plugin name must be a string")
	assert(type(instanceName) == "string", "Instance name must be a string")
	local category = Plugins[pluginName]
	if not category then return true end
	--assert(category, "Plugin "..tostring(pluginName).." not found")
	local instance = category.instances[instanceName]
	--assert(instance, "Plugin instance "..tostring(instanceName).." not found")
	if not instance then return true end
	-- update instance
	--instance:SettingsModified()
	Engine.safecall(instance.SettingsModified, instance)
	return true
end

function Engine:UpdateAllPlugins()
	for _, pluginCategory in pairs(Plugins) do
		for _, instance in pairs(pluginCategory.instances) do
--print("UPDATE:"..tostring(instance).."  "..tostring(instance.name))
			--instance:SettingsModified()
			Engine.safecall(instance.SettingsModified, instance)
		end
	end
end

------------------------------------------------
-- Create & Initialize plugin instance
------------------------------------------------
function Engine:CreatePluginInstance(pluginName, instanceName, settings)
--print("CreatePluginInstance:"..tostring(pluginName).."  "..tostring(instanceName).."  "..tostring(settings))
	local instance = Engine:NewPluginInstance(pluginName, instanceName, settings)
	if instance then
		--instance:Initialize()
		local success = Engine.safecall(instance.Initialize, instance)
		if success then
			if settings.enabled == true then
				--instance:Enable()
				Engine.safecall(instance.Enable, instance)
			end
		else
			-- remove plugin instance
			local category = Plugins[pluginName]
			category[instanceName] = nil
			-- set as invalid
			settings.__invalid = true
		end
	end
	return instance
end

------------------------------------------------
-- Build plugin category list (only plugin name)
------------------------------------------------
function Engine:GetPluginList()
	local list = {}
	for _, category in pairs(Plugins) do
--print("PLUGIN LIST:"..tostring(category.pluginName))
		list[category.pluginName] = true
	end
	return list
end

------------------------------------------------
-- Delete a plugin instance
------------------------------------------------
function Engine:DeletePluginInstance(pluginName, instanceName)
		-- TODO: remove this workaround
	if pluginName == "MOVER" then return true end
	-- get instance
	assert(type(pluginName) == "string", "Plugin name must be a string")
	assert(type(instanceName) == "string", "Instance name must be a string")
	local category = Plugins[pluginName]
	if not category then return false end
	local instance = category.instances[instanceName]
	if not instance then return false end
	-- Disable instance, no real deletion
	--instance:Disable()
	Engine.safecall(instance.Disable, instance)
	return true
end

------------------------------------------------
-- Check if plugin category already exists
------------------------------------------------
function Engine:IsPluginAvailable(pluginName)
	return Plugins[pluginName] ~= nil
end