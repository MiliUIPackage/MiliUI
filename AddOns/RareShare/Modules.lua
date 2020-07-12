local AddonName, Addon = ...

Addon.Modules = {}

function Addon:InitModule()
    local Map = self:CheckZone()
    if (Map and not self.Status) then
        self:InitChat()
        self.Status = true
        self.LastMap = Map
        self:RegisterEventTable(self.Events)
        self:RegisterModule(Map)
        self:Log(Addon.Loc.Enabled, 1, Map)
    elseif (not Map and Addon.Status) then
        self.Status = false
        self:UnregisterEventTable(self.Events)
        self:UnregisterModule(self.LastMap)
        self:Log(Addon.Loc.Disabled, 2, Addon.LastMap)
    end
end

function Addon:InitModuleUI()
    for i,v in pairs(Addon.Modules) do
        if (v.InitUI) then v:InitUI() end
    end
end

function Addon:InitModuleConfig()
    for i,v in pairs(Addon.Modules) do
        if (v.Config) then v:Config() end
    end
end

function Addon:LoadModule(Module)
    self.Modules[Module.ID] = {}
    for i,v in pairs(Module) do
        self.Modules[Module.ID][i] = v 
    end
end

function Addon:RegisterModule(ModuleID)
    for i, v in pairs(self.Modules[ModuleID].Events) do
        self:RegisterEvent(i, v)
    end
end

function Addon:UnregisterModule(ModuleID)
    for i, v in pairs(self.Modules[ModuleID].Events) do
        self:UnregisterEvent(i, v)
    end
end

function Addon:UnloadModule(ModuleID)
    self:UnregisterModule(ModuleID)
    self.Modules[ModuleID] = nil
end

function Addon:GetModule(ModuleID)
    return self.Modules[ModuleID]
end