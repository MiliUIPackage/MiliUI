local AddonName, Addon = ...

function Addon:InitUI()
    local ConfigFrame = CreateFrame("Frame")
    ConfigFrame.name = Addon.Loc.Title
    
    local CheckBoxID = 1
    function self:CreateCheckBox(Data)
        local CheckBox = CreateFrame("CheckButton", "RareShare_CheckBox_"..CheckBoxID.."_", Data.Parent, "OptionsCheckButtonTemplate")
        CheckBox:SetPoint("TOPLEFT", Data.X, Data.Y)
        CheckBox.tooltipText      = Data.Tooltip
        CheckBox.defaultValue     = Data.Default
        CheckBox.value            = Data.Value
        CheckBox.oldValue         = Data.OldValue
        CheckBox.Setting          = Data.Setting

        function CheckBox:SetValue()
            self.value = not self.value
        end

        function CheckBox:GetValue()
            return self.value
        end

        function CheckBox:CheckChecked()
            self:SetChecked(self.value)
        end
        
        _G[string.format("%sText", CheckBox:GetName())]:SetText(Data.DisplayText)
        -- _G[CheckBox:GetName() .. "Text"]:SetText(Data.DisplayText)

        CheckBoxID = CheckBoxID + 1
        
        return CheckBox
    end
    
    local X, Y = 20, -20

    local CheckBoxes = {}
    CheckBoxes.Announcement = self:CreateCheckBox({
        ["Parent"]      = ConfigFrame,
        ["DisplayText"] = Addon.Loc.Config.RareAnnounce[1],
        ["X"]           = X,
        ["Y"]           = Y,
        ["Tooltip"]     = Addon.Loc.Config.RareAnnounce[2],
        ["Default"]     = true,
        ["Value"]       = RareShareDB["Config"]["ChatAnnounce"],
        ["OldValue"]    = RareShareDB["Config"]["ChatAnnounce"],
        ["Setting"]     = "RareShareDB[\"Config\"][\"ChatAnnounce\"] = ",
    })
    Y = Y - 40

    CheckBoxes.Sound = self:CreateCheckBox({
        ["Parent"]      = ConfigFrame,
        ["DisplayText"] = Addon.Loc.Config.Sound[1],
        ["X"]           = X,
        ["Y"]           = Y,
        ["Tooltip"]     = Addon.Loc.Config.Sound[2],
        ["Default"]     = true,
        ["Value"]       = RareShareDB["Config"]["Sound"]["Master"],
        ["OldValue"]    = RareShareDB["Config"]["Sound"]["Master"],
        ["Setting"]     = "RareShareDB[\"Config\"][\"Sound\"][\"Master\"] = ",
    })
    Y = Y - 40

    if (Addon.TomTom) then
        CheckBoxes.TomTom = self:CreateCheckBox({
            ["Parent"]      = ConfigFrame,
            ["DisplayText"] = Addon.Loc.Config.TomTom[1],
            ["X"]           = X,
            ["Y"]           = Y,
            ["Tooltip"]     = Addon.Loc.Config.TomTom[2],
            ["Default"]     = true,
            ["Value"]       = RareShareDB["Config"]["TomTom"]["Master"],
            ["OldValue"]    = RareShareDB["Config"]["TomTom"]["Master"],
            ["Setting"]     = "RareShareDB[\"Config\"][\"TomTom\"][\"Master\"] = ",
        })
        Y = Y - 40
    end

    CheckBoxes.OnDeath = self:CreateCheckBox({
        ["Parent"]      = ConfigFrame,
        ["DisplayText"] = Addon.Loc.Config.OnDeath[1],
        ["X"]           = X,
        ["Y"]           = Y,
        ["Tooltip"]     = Addon.Loc.Config.OnDeath[2],
        ["Default"]     = false,
        ["Value"]       = RareShareDB["Config"]["OnDeath"],
        ["OldValue"]    = RareShareDB["Config"]["OnDeath"],
        ["Setting"]     = "RareShareDB[\"Config\"][\"OnDeath\"] = ",
    })
    Y = Y - 40

    CheckBoxes.Duplicates = self:CreateCheckBox({
        ["Parent"]      = ConfigFrame,
        ["DisplayText"] = Addon.Loc.Config.Duplicates[1],
        ["X"]           = X,
        ["Y"]           = Y,
        ["Tooltip"]     = Addon.Loc.Config.Duplicates[2],
        ["Default"]     = true,
        ["Value"]       = RareShareDB["Config"]["Duplicates"],
        ["OldValue"]    = RareShareDB["Config"]["Duplicates"],
        ["Setting"]     = "RareShareDB[\"Config\"][\"Duplicates\"] = ",
    })
    Y = Y - 40

    function ConfigFrame.default()
        for i,v in pairs(CheckBoxes) do
            v.value = v.defaultValue
        end
    end

    function ConfigFrame.okay()
        for i,v in pairs(CheckBoxes) do
            loadstring(v.Setting .. tostring(v.value))()
            v.oldValue = v.value
        end
    end

    function ConfigFrame.cancel()
        for i,v in pairs(CheckBoxes) do
            v.value = v.oldValue
        end
    end

    function ConfigFrame.refresh()
        for i,v in pairs(CheckBoxes) do
            v:CheckChecked()
        end
    end

    InterfaceOptions_AddCategory(ConfigFrame)
    Addon.CheckBoxes = CheckBoxes
    RareShare.Title = Addon.Loc.Title
end