local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local L = CDM.L

CDM.ModuleManager = CDM.ModuleManager or {}
local ModuleManager = CDM.ModuleManager

ModuleManager._definitions = ModuleManager._definitions or {}
ModuleManager._order = ModuleManager._order or {}
ModuleManager._state = ModuleManager._state or {}

local function SafeInvokeModuleHandler(moduleId, phase, handler)
    if type(handler) ~= "function" then
        return true
    end

    local ok, err = pcall(handler)
    if not ok then
        print("|cffff0000[CDM] " .. string.format(L["Callback error in '%s':"], "module:" .. moduleId .. ":" .. phase) .. "|r " .. tostring(err))
        return false, err
    end
    return true
end

local function EnsureState(self, moduleId)
    local state = self._state[moduleId]
    if not state then
        state = {
            initialized = false,
            enabled = false,
        }
        self._state[moduleId] = state
    end
    return state
end

function ModuleManager:RegisterModule(definition)
    if type(definition) ~= "table" then return false end
    local moduleId = definition.id
    if type(moduleId) ~= "string" or moduleId == "" then
        return false
    end

    if not self._definitions[moduleId] then
        self._order[#self._order + 1] = moduleId
    end

    self._definitions[moduleId] = definition
    EnsureState(self, moduleId)
    return true
end

function ModuleManager:ReconcileModule(moduleId)
    local definition = self._definitions[moduleId]
    if not definition then
        return false, "Module not registered"
    end

    local state = EnsureState(self, moduleId)

    local wantEnabled = true
    if definition.ShouldBeEnabled then
        local ok, value = pcall(definition.ShouldBeEnabled, CDM.db)
        if ok then
            wantEnabled = value ~= false
        else
            print("|cffff0000[CDM] " .. string.format(L["Callback error in '%s':"], "module:" .. moduleId .. ":should_be_enabled") .. "|r " .. tostring(value))
            wantEnabled = state.enabled
        end
    end

    if wantEnabled then
        if not state.initialized then
            local ok, err = SafeInvokeModuleHandler(moduleId, "initialize", definition.Initialize)
            if not ok then
                return false, err
            end
            state.initialized = true
        end

        if not state.enabled then
            local ok, err = SafeInvokeModuleHandler(moduleId, "enable", definition.Enable)
            if not ok then
                return false, err
            end
            state.enabled = true
        end

        local ok, err = SafeInvokeModuleHandler(moduleId, "refresh", definition.Refresh)
        if not ok then
            return false, err
        end
        return true
    end

    if state.enabled then
        local ok, err = SafeInvokeModuleHandler(moduleId, "disable", definition.Disable)
        if not ok then
            return false, err
        end
        state.enabled = false
    end
    return true
end

function ModuleManager:NotifyProfileApplied()
    local failures
    for _, moduleId in ipairs(self._order) do
        local definition = self._definitions[moduleId]
        if definition and definition.OnProfileApplied then
            local ok, err = SafeInvokeModuleHandler(moduleId, "profile_applied", definition.OnProfileApplied)
            if not ok then
                failures = failures or {}
                failures[#failures + 1] = {
                    moduleId = moduleId,
                    error = err,
                }
            end
        end
    end

    if failures and #failures > 0 then
        local labels = {}
        for _, entry in ipairs(failures) do
            labels[#labels + 1] = string.format("%s (%s)", tostring(entry.moduleId), tostring(entry.error))
        end
        print("|cffff0000[CDM] " .. string.format(L["Callback error in '%s':"], "module:profile_applied") .. "|r " .. table.concat(labels, "; "))
        return false, failures
    end

    return true
end

