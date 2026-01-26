local _, ns = ...

--- WilduSettings_Checkbox

local function InitializeSettingTooltip(initializer)
    Settings.InitTooltip(initializer:GetName(), initializer:GetTooltip())
end

CMC_WilduSettingsListElementMixin = {}

function CMC_WilduSettingsListElementMixin:OnLoad()
    self.cbrHandles = Settings.CreateCallbackHandleContainer()
end

function CMC_WilduSettingsListElementMixin:DisplayEnabled(enabled)
    local color = enabled and NORMAL_FONT_COLOR or GRAY_FONT_COLOR
    self.Text:SetTextColor(color:GetRGB())
    self:DesaturateHierarchy(enabled and 0 or 1)
end

function CMC_WilduSettingsListElementMixin:GetIndent()
    local initializer = self:GetElementData()
    return initializer:GetIndent()
end

function CMC_WilduSettingsListElementMixin:SetTooltipFunc(tooltipFunc)
    WilduDefaultTooltipMixin.SetTooltipFunc(self.Tooltip, tooltipFunc)
end

function CMC_WilduSettingsListElementMixin:SetTooltipHideFunc(tooltipFunc)
    WilduDefaultTooltipMixin.SetTooltipHideFunc(self.Tooltip, tooltipFunc)
end

function CMC_WilduSettingsListElementMixin:Init(initializer)
    assert(self.cbrHandles:IsEmpty())
    self.data = initializer.data

    local parentInitializer = initializer:GetParentInitializer()
    if parentInitializer and parentInitializer.GetSetting then
        local setting = parentInitializer:GetSetting()
        if setting then
            self.cbrHandles:SetOnValueChangedCallback(
                setting:GetVariable(),
                self.OnParentSettingValueChanged,
                self
            )
        end
    end

    local font = initializer:IsParentInitializerInLayout() and "GameFontNormalSmall" or "GameFontNormal"
    self.Text:SetFontObject(font)
    self.Text:SetText(initializer:GetName())
    self.Text:SetPoint("TOPLEFT", self, "TOPLEFT", (self:GetIndent() + 57), 0)
    self.Text:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -40, 0)

    if initializer.hideText then
        self.Text:Hide()
    end

    -- Setup tooltip with optional preview support
    if self.data and self.data.setting and ns.WilduSettings.settingPreview[self.data.setting.variable] then 
        self:SetTooltipFunc(function()
            ns.WilduSettings:SetVariableToPreview(initializer.data.setting.variable)
            InitializeSettingTooltip(initializer)
        end)
        self:SetTooltipHideFunc(function() ns.WilduSettings:SetVariableToPreview(nil) end)
    else
        self:SetTooltipFunc(function() InitializeSettingTooltip(initializer) end)
    end
  
    local newTagShown = initializer.IsNewTagShown and initializer:IsNewTagShown()
    self.NewFeature:SetShown(newTagShown)
    if newTagShown then
        initializer:MarkSettingAsSeen()
    end
end

function CMC_WilduSettingsListElementMixin:Release()
    self.cbrHandles:Unregister()
    self.data = nil
end

function CMC_WilduSettingsListElementMixin:OnParentSettingValueChanged(setting, value)
    self:EvaluateState()
end

function CMC_WilduSettingsListElementMixin:EvaluateState()
    local initializer = self:GetElementData()
    self:SetShown(initializer:ShouldShow())
end

CMC_WilduSettingsControlMixin = CreateFromMixins(CMC_WilduSettingsListElementMixin)

function CMC_WilduSettingsControlMixin:OnLoad()
    CMC_WilduSettingsListElementMixin.OnLoad(self)
end

function CMC_WilduSettingsControlMixin:Init(initializer)
    CMC_WilduSettingsListElementMixin.Init(self, initializer)

    local setting = self:GetSetting()
    if not setting then return end

    self.cbrHandles:SetOnValueChangedCallback(setting:GetVariable(), self.OnSettingValueChanged, self)

    local evaluateStateFrameEvents = initializer.GetEvaluateStateFrameEvents and initializer:GetEvaluateStateFrameEvents()
    if evaluateStateFrameEvents then
        for _, event in ipairs(evaluateStateFrameEvents) do
            self.cbrHandles:AddHandle(EventRegistry:RegisterFrameEventAndCallbackWithHandle(event, self.EvaluateState, self))
        end
    end
end

function CMC_WilduSettingsControlMixin:Release()
    CMC_WilduSettingsListElementMixin.Release(self)
end

function CMC_WilduSettingsControlMixin:GetSetting()
    return self.data and self.data.setting or nil
end

function CMC_WilduSettingsControlMixin:SetValue(value)
end

function CMC_WilduSettingsControlMixin:OnSettingValueChanged(setting, value)
    self:SetValue(value)
end

function CMC_WilduSettingsControlMixin:IsEnabled()
    local initializer = self:GetElementData()
    local prereqs = initializer.GetModifyPredicates and initializer:GetModifyPredicates()
    if prereqs then
        for _, prereq in ipairs(prereqs) do
            if not prereq() then return false end
        end
    end
    return true
end

function CMC_WilduSettingsControlMixin:ShouldInterceptSetting(value)
    local initializer = self:GetElementData()
    local intercept = initializer.GetSettingIntercept and initializer:GetSettingIntercept()
    if intercept then
        local result = intercept(value)
        assert(result ~= nil)
        return result
    end
    return false
end

CMC_WilduSettingsCheckboxControlMixin = CreateFromMixins(CMC_WilduSettingsControlMixin)

function CMC_WilduSettingsCheckboxControlMixin:OnLoad()
    CMC_WilduSettingsControlMixin.OnLoad(self)

    self.Checkbox = CreateFrame("CheckButton", nil, self, "SettingsCheckboxTemplate")
    self.Checkbox:SetPoint("LEFT", self, "LEFT", 46, 0)
    self.Checkbox:SetScale(0.6)

    self.Tooltip:SetScript("OnMouseUp", function()
        if self.Checkbox:IsEnabled() then
            self.Checkbox:Click()
        end
    end)
end

function CMC_WilduSettingsCheckboxControlMixin:OnEnter()
    if self.data and self.data.setting and self.data.setting.variable then
        ns.WilduSettings:SetVariableToPreview(self.data.setting.variable)
    end
end

function CMC_WilduSettingsCheckboxControlMixin:OnLeave()
    ns.WilduSettings:SetVariableToPreview(nil)
end

function CMC_WilduSettingsCheckboxControlMixin:Init(initializer)
    CMC_WilduSettingsControlMixin.Init(self, initializer)

    local setting = self:GetSetting()
    if not setting then return end

    local options = initializer.GetOptions and initializer:GetOptions() or nil
    local initTooltip = Settings.CreateOptionsInitTooltip(setting, initializer:GetName(), initializer:GetTooltip(), options)

    self.Checkbox:Init(setting:GetValue(), initTooltip)
    self.cbrHandles:RegisterCallback(self.Checkbox, SettingsCheckboxMixin.Event.OnValueChanged, self.OnCheckboxValueChanged, self)

    self:EvaluateState()
end

function CMC_WilduSettingsCheckboxControlMixin:OnSettingValueChanged(setting, value)
    CMC_WilduSettingsControlMixin.OnSettingValueChanged(self, setting, value)
    self.Checkbox:SetChecked(value)
end

function CMC_WilduSettingsCheckboxControlMixin:OnCheckboxValueChanged(value)
    if self:ShouldInterceptSetting(value) then
        self.Checkbox:SetChecked(not value)
    else
        self:GetSetting():SetValue(value)
    end
end

function CMC_WilduSettingsCheckboxControlMixin:SetValue(value)
    self.Checkbox:SetChecked(value)
    PlaySound(value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

function CMC_WilduSettingsCheckboxControlMixin:EvaluateState()
    SettingsListElementMixin.EvaluateState(self)
    local enabled = CMC_WilduSettingsControlMixin.IsEnabled(self)

    local initializer = self:GetElementData()
    local options = initializer.GetOptions and initializer:GetOptions() or nil
    if options then
        local optionData = type(options) == 'function' and options() or options
        local value = self:GetSetting():GetValue()
        for _, option in ipairs(optionData) do
            if option.disabled and option.value ~= value then
                enabled = false
            end
        end
    end

    self.Checkbox:SetEnabled(enabled)
    self:DisplayEnabled(enabled)
end

function CMC_WilduSettingsCheckboxControlMixin:Release()
    self.Checkbox:Release()
    CMC_WilduSettingsControlMixin.Release(self)
end
