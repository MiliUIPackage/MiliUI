local ADDON_NAME, Engine = ...

-- Expose public methods
ClassMonitor_ConfigUI = {}

-- Methods exposed to external addons
ClassMonitor_ConfigUI.NewPluginDefinition = Engine.Definitions.Helpers.NewPluginDefinition -- Add a new plugin definition, parameters are pluginName, options, short description, long description

-- Namespaces exposed to extern addons
ClassMonitor_ConfigUI.Helpers = Engine.Definitions.Helpers -- Namespace with a lot functions/tables to help building an option table for a plugin

-- Methods needed by ClassMonitor, don't call these methods from your own addon
ClassMonitor_ConfigUI.InitializeConfigUI = Engine.InitializeConfigUI -- PRIVATE USE
ClassMonitor_ConfigUI.DisplayConfigPanel = Engine.DisplayConfigFrame -- PRIVATE USE