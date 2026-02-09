local addonName, addonTable = ...

-- Helper: get MiliUI per-layout defaults for a bar DB key
local function GetMiliUIBarDefaults(dbKey)
    if not MiliUI_Luxthos_SenseiDB or not MiliUI_Luxthos_SenseiDB[dbKey] then
        return nil
    end
    -- Return the first available layout's data as the default template
    for _, layoutData in pairs(MiliUI_Luxthos_SenseiDB[dbKey]) do
        return layoutData
    end
    return nil
end

-- Bar DB keys that store per-layout settings
local barDBKeys = {
    "PrimaryResourceBarDB",
    "SecondaryResourceBarDB",
    "tertiaryResourceBarDB",
    "healthBarDB",
}

------------------------------------------------------------
-- BAR FACTORY
------------------------------------------------------------
local function CreateBarInstance(config, parent, frameLevel)
    -- Initialize database
    if not SenseiClassResourceBarDB[config.dbName] then
        SenseiClassResourceBarDB[config.dbName] = {}
    end

    -- Create frame
    local bar = CreateFromMixins(config.mixin or addonTable.BarMixin)
    bar:Init(config, parent, frameLevel)

    -- Copy defaults if needed
    local curLayout = addonTable.LEM.GetActiveLayoutName() or "Default"
    if not SenseiClassResourceBarDB[config.dbName][curLayout] then
        -- Prefer MiliUI defaults over addon built-in defaults
        local miliDefaults = GetMiliUIBarDefaults(config.dbName)
        if miliDefaults then
            SenseiClassResourceBarDB[config.dbName][curLayout] = CopyTable(miliDefaults)
        else
            SenseiClassResourceBarDB[config.dbName][curLayout] = CopyTable(bar.defaults)
        end
    end

    bar:OnLoad()
    bar:GetFrame():SetScript("OnEvent", function(_, ...)
        bar:OnEvent(...)
    end)

    bar:ApplyVisibilitySettings()
    bar:ApplyLayout(true)
    bar:UpdateDisplay(true)

    return bar
end

------------------------------------------------------------
-- INITIALIZE BARS
------------------------------------------------------------
local function InitializeBar(config, frameLevel)
    local bar = CreateBarInstance(config, UIParent, math.max(0, frameLevel or 0))

    local defaults = CopyTable(addonTable.commonDefaults)
    for k, v in pairs(config.defaultValues or {}) do
        defaults[k] = v
    end

    local LEMSettingsLoader = CreateFromMixins(addonTable.LEMSettingsLoaderMixin)
    LEMSettingsLoader:Init(bar, defaults)
    LEMSettingsLoader:LoadSettings()

    return bar
end

local SCRB = CreateFrame("Frame")
SCRB:RegisterEvent("ADDON_LOADED")
SCRB:RegisterEvent("PLAYER_ENTERING_WORLD")
SCRB:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not SenseiClassResourceBarDB then
            -- MiliUI Profile (first install)
            if MiliUI_Luxthos_SenseiDB then
                SenseiClassResourceBarDB = CopyTable(MiliUI_Luxthos_SenseiDB)
            else
                SenseiClassResourceBarDB = {}
            end
        else
            -- Merge MiliUI defaults for top-level keys that don't exist yet
            if MiliUI_Luxthos_SenseiDB then
                for key, value in pairs(MiliUI_Luxthos_SenseiDB) do
                    if SenseiClassResourceBarDB[key] == nil then
                        SenseiClassResourceBarDB[key] = CopyTable(value)
                    end
                end
            end
        end

        -- Register layout change callback BEFORE bars init (fires first = higher priority)
        if MiliUI_Luxthos_SenseiDB then
            addonTable.LEM:RegisterCallback("layout", function(layoutName)
                if not SenseiClassResourceBarDB then return end
                for _, dbKey in ipairs(barDBKeys) do
                    if SenseiClassResourceBarDB[dbKey] and not SenseiClassResourceBarDB[dbKey][layoutName] then
                        local miliDefaults = GetMiliUIBarDefaults(dbKey)
                        if miliDefaults then
                            SenseiClassResourceBarDB[dbKey][layoutName] = CopyTable(miliDefaults)
                        end
                    end
                end
            end)
        end

        addonTable.barInstances = addonTable.barInstances or {}

        for _, config in pairs(addonTable.RegisteredBar or {}) do
            if config.loadPredicate == nil or (type(config.loadPredicate) == "function" and config.loadPredicate(config) == true) then
                local frame = InitializeBar(config, config.frameLevel or 1)
                addonTable.barInstances[config.frameName] = frame
            end
        end

        addonTable.SettingsRegistrar()

    elseif event == "PLAYER_ENTERING_WORLD" then
        SCRB:UnregisterEvent("PLAYER_ENTERING_WORLD")
        -- Custom Edit Mode layouts are now available
        if not MiliUI_Luxthos_SenseiDB or not SenseiClassResourceBarDB then return end

        -- Get real active layout from C_EditMode API
        local layouts = C_EditMode and C_EditMode.GetLayouts and C_EditMode.GetLayouts()
        if not layouts then return end

        -- Build full layout name list (index 1=Modern, 2=Classic, 3+=custom)
        local allLayoutNames = {}
        allLayoutNames[1] = LAYOUT_STYLE_MODERN or "Modern"
        allLayoutNames[2] = LAYOUT_STYLE_CLASSIC or "Classic"
        if layouts.layouts then
            for i, info in ipairs(layouts.layouts) do
                if info and info.layoutName then
                    allLayoutNames[i + 2] = info.layoutName
                end
            end
        end
        -- Inject MiliUI defaults for all layouts that don't have data
        for _, layoutName in pairs(allLayoutNames) do
            for _, dbKey in ipairs(barDBKeys) do
                if SenseiClassResourceBarDB[dbKey] and not SenseiClassResourceBarDB[dbKey][layoutName] then
                    local miliDefaults = GetMiliUIBarDefaults(dbKey)
                    if miliDefaults then
                        SenseiClassResourceBarDB[dbKey][layoutName] = CopyTable(miliDefaults)
                    end
                end
            end
        end
    end
end)
