local ADDON_NAME, Engine = ...

-- Expose public methods
ClassMonitor = {}

-- Methods exposed to external addons
ClassMonitor.NewPlugin = Engine.NewPlugin -- Create a new plugin category (must be done before ADDON_LOADED)   [call with ClassMonitor:NewPlugin]
ClassMonitor.GetPluginList = Engine.GetPluginList -- Get a list of plugin category name   [call with ClassMonitor:GetPluginList]
ClassMonitor.IsPluginAvailable = Engine.IsPluginAvailable -- Return true if plugin category already exists, false otherwise   [call with ClassMonitor:IsPluginAvailable]
ClassMonitor.GetColor = Engine.GetColor -- Return colors[index] or default color if colors is nil or colors[index] doesn't exist   [call with ClassMonitor.GetColor]
--ClassMonitor.GetAnchor = Engine.GetAnchor -- Return current anchor in function of anchoring mode   [call with ClassMonitor.GetAnchor]
--ClassMonitor.GetWidth = Engine.GetWidth -- Return current width in function of anchoring mode   [call with ClassMonitor.GetWidth]
--ClassMonitor.GetHeight = Engine.GetHeight -- Return current height in function of anchoring mode   [call with ClassMonitor.GetHeight]

-- Namespaces exposed to extern addons
ClassMonitor.UI = Engine.UI