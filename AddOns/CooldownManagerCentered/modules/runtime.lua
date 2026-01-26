local _, ns = ...

local Runtime = {}
ns.Runtime = Runtime

local function UpdateRuntime()
    if Runtime.isInEditMode or Runtime.hasSettingsOpened then
        Runtime.stop = true
    else
        Runtime.stop = false
    end
end

Runtime.stop = false
Runtime.isInEditMode = false
Runtime.hasSettingsOpened = false
EventRegistry:RegisterCallback("EditMode.Enter", function()
    Runtime.isInEditMode = true
    UpdateRuntime()
end)
EventRegistry:RegisterCallback("EditMode.Exit", function()
    Runtime.isInEditMode = false
    UpdateRuntime()
end)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnShow", function()
    Runtime.hasSettingsOpened = true
    UpdateRuntime()
end)
EventRegistry:RegisterCallback("CooldownViewerSettings.OnHide", function()
    Runtime.hasSettingsOpened = false
    UpdateRuntime()
end)

function Runtime:IsReady(viewerNameOrFrame)
    if Runtime.stop then
        return false
    end

    local viewer = nil
    if type(viewerNameOrFrame) == "string" then
        viewer = _G[viewerNameOrFrame]
    elseif type(viewerNameOrFrame) == "table" then
        viewer = viewerNameOrFrame
    end
    if not viewer or not viewer.IsInitialized or not EditModeManagerFrame then
        return false
    end

    if EditModeManagerFrame.layoutApplyInProgress or not viewer:IsInitialized() then
        return false
    end

    return true
end
