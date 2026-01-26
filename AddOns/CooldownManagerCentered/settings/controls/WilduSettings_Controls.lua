local _, ns = ...

--- WilduSettings_Controls

local WilduSettings = ns.WilduSettings

---Create a checkbox control and add it to the category layout
---@param category table Settings category
---@param setting table Setting object
---@param desc string|nil Optional desc text
---@return table initializer The created checkbox initializer
function WilduSettings.CreateCheckbox(category, setting, desc)
    assert(setting:GetVariableType() == "boolean")
    local initializer = Settings.CreateControlInitializer("CMC_WilduSettingsCheckboxControlTemplate", setting, nil, desc)
    SettingsPanel:GetLayout(category):AddInitializer(initializer)
    return initializer
end

---Create a checkbox with full configuration from CheckboxData
---@param categoryTbl table Settings category
---@param cbData CheckboxData Checkbox configuration data
---@return table result Table with setting and element references
function WilduSettings.SettingsCreateCheckbox(categoryTbl, cbData)
    ns.WilduSettings.settingPreview["CMC_"..cbData.variable] = { 
        text = cbData.desc, 
        image = cbData.previewImage or "no_preview"
    }
    
    local setting = Settings.RegisterProxySetting(
        categoryTbl or ns.WilduSettings.SettingsLayout.rootCategory,
        "CMC_"..cbData.variable,
        Settings.VarType.Boolean,
        cbData.name,
        cbData.defaultValue,
        cbData.getValue,
        cbData.setValue
    )
    
    local element = WilduSettings.CreateCheckbox(categoryTbl, setting, cbData.desc)

    if cbData.parent then
        element:SetParentInitializer(cbData.element, cbData.parentCheck)
    end

    return { setting = setting, element = element }
end
