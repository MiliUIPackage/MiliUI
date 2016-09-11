local addonName, addonNamespace = ...

LoadAddOn("Blizzard_InspectUI")

local L = addonNamespace.L

local AddOn = LibStub("AceAddon-3.0"):NewAddon(addonName,
    "AceConsole-3.0",
    "AceEvent-3.0")

_G[addonName] = AddOn

AddOn.configPanel = nil
AddOn.defaults = {
    profile = {
        Upgrades = false,
        UpgradesSummary = true,
        Character = true,
        Inspection = true,
        Color = true,
        Small = false,
        Debug = false,
    }
}

function AddOn:OnInitialize()
    self:Debug("OnInitialize")

    self.db = LibStub("AceDB-3.0"):New(self:GetName() .. "DB", self.defaults, true)

    addonNamespace.SetDebugPrinter(function(...)
        if self.db.profile.Debug then
            self:Print(...)
        end
    end)

    LibStub("AceConfig-3.0"):RegisterOptionsTable(self:GetName(), {
        type = "group",
        args = {},
    }, "/kibc")

    self:RegisterChatCommand("kibc", function(input)
        if not input or input:trim() == "" then
            InterfaceOptionsFrame_OpenToCategory(self.configPanel)

            InterfaceOptionsFrameTab2:Click("LeftButton", true)

            for _, button in pairs(self:FindFrames("InterfaceOptionsFrameAddOnsButton")) do
                if button.Click and button.GetText and button:GetText() == self.configPanel.name then
                    button:Click("LeftButton", true)
                    break
                end
            end
        else
            LibStub("AceConfigCmd-3.0").HandleCommand(MyAddon, "kibc", self:GetName(), input)
        end
    end)

    self.playerSlotIconManager = addonNamespace.SlotIconManager:new(addonNamespace.CharacterFrameAdapter:new())
    self.inspectorSlotIconManager = addonNamespace.SlotIconManager:new(addonNamespace.InspectionFrameAdapter:new())

    self.db.RegisterCallback(self, "OnProfileChanged", function()
        self:Debug("OnProfileChanged")
        self:ApplyStyle()
    end)

    self.db.RegisterCallback(self, "OnProfileCopied", function()
        self:Debug("OnProfileCopied")
        self:ApplyStyle()
    end)

    self.db.RegisterCallback(self, "OnProfileReset", function()
        self:Debug("OnProfileReset")
        self:ApplyStyle()
    end)

    if self.configPanel then
        self:EnhanceControls(self.configPanel)

        self.configPanel.name = L["Kibs Item Level (continued)"]

        self.configPanel.okay = function()
            self:Debug("configPanel.okay")
            self.db.profile.Upgrades = self.configPanel.controls.Upgrades:GetChecked()
            self.db.profile.UpgradesSummary = self.configPanel.controls.UpgradesSummary:GetChecked()
            self.db.profile.Character = self.configPanel.controls.Character:GetChecked()
            self.db.profile.Inspection = self.configPanel.controls.Inspection:GetChecked()
            self.db.profile.Small = self.configPanel.controls.Small:GetChecked()
            self.db.profile.Color = self.configPanel.controls.Color:GetChecked()
            self.db.profile.Debug = self.configPanel.controls.Debug:GetChecked()
            self:ApplyStyle()
        end

        self.configPanel.cancel = function()
            self:Debug("configPanel.cancel")
        end

        self.configPanel.refresh = function()
            self:Debug("configPanel.refresh")
            self.configPanel.controls.Upgrades:SetChecked(self.db.profile.Upgrades)
            self.configPanel.controls.UpgradesSummary:SetChecked(self.db.profile.UpgradesSummary)
            self.configPanel.controls.Character:SetChecked(self.db.profile.Character)
            self.configPanel.controls.Inspection:SetChecked(self.db.profile.Inspection)
            self.configPanel.controls.Small:SetChecked(self.db.profile.Small)
            self.configPanel.controls.Color:SetChecked(self.db.profile.Color)
            self.configPanel.controls.Debug:SetChecked(self.db.profile.Debug)
        end

        self.configPanel.default = function()
            self:Debug("configPanel.default")
            self.db:ResetProfile()
        end

        InterfaceOptions_AddCategory(self.configPanel)
    end

--    self:RegisterEvent("UNIT_INVENTORY_CHANGED", function(event, unit)
--        self:Debug("UNIT_INVENTORY_CHANGED", unit)
--        if unit == 'player' then
--            self.playerSlotIconManager:Refresh()
--        else
--            self.inspectorSlotIconManager:Refresh()
--        end
--    end)
--
--    self:RegisterEvent("SOCKET_INFO_CLOSE", function()
--        self:Debug("SOCKET_INFO_CLOSE")
--        self.playerSlotIconManager:Refresh()
--    end)
--
--    self:RegisterEvent("SOCKET_INFO_SUCCESS", function()
--        self:Debug("SOCKET_INFO_SUCCESS")
--        self.playerSlotIconManager:Refresh()
--    end)
--
--    self:RegisterEvent("SOCKET_INFO_UPDATE", function()
--        self:Debug("SOCKET_INFO_UPDATE")
--        self.playerSlotIconManager:Refresh()
--    end)
--
--    self:RegisterEvent("INSPECT_READY", function()
--        self:Debug("INSPECT_READY")
--        self.inspectorSlotIconManager:Refresh()
--    end)

    local KIB_CONFLICT_FLAG = 'KIB_CONFLICT_FLAG'

    if _G[KIB_CONFLICT_FLAG] then
        local KIB_CONFLICT_DIALOG = 'KIB_CONFLICT_DIALOG'

        StaticPopupDialogs[KIB_CONFLICT_DIALOG] = {
            showAlert = true,
            text = L['Looks like both Kibs Item Level add-on and its Continued version are installed. They provide exactly the same functionality (they both updated to the latest version), and having them both is just a CPU/memory overhead and a soruce of UI glitches. Please, disable or uninstall one of them.'],
            button1 = "OK",
            timeout = 0,
            enterClicksFirstButton = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }

        StaticPopup_Show(KIB_CONFLICT_DIALOG)
    else
        _G[KIB_CONFLICT_FLAG] = true
    end

    self:ApplyStyle()
end

function AddOn:ApplyStyle()
    self:Debug("ApplyStyle")

    local style = 0

    if self.db.profile.Small then
        style = style + addonNamespace.SlotIconManager.STYLE.SMALL
    end

    if self.db.profile.Upgrades then
        style = style + addonNamespace.SlotIconManager.STYLE.UPGRADES
    end

    if self.db.profile.Color then
        style = style + addonNamespace.SlotIconManager.STYLE.COLOR
    end

    if self.db.profile.UpgradesSummary then
        style = style + addonNamespace.SlotIconManager.STYLE.UPGRADES_SUMMARY
    end

    local playerSlotIconManager = style
    if self.db.profile.Character then
        playerSlotIconManager = playerSlotIconManager + addonNamespace.SlotIconManager.STYLE.ENABLED
    end
    self.playerSlotIconManager:SetStyle(playerSlotIconManager)

    local inspectorSlotIconManager = style
    if self.db.profile.Inspection then
        inspectorSlotIconManager = inspectorSlotIconManager + addonNamespace.SlotIconManager.STYLE.ENABLED
    end
    self.inspectorSlotIconManager:SetStyle(inspectorSlotIconManager)
end

function AddOn:FindFrames(prefix)
    local result = {}

    if type(prefix) == "string" then
        local len = string.len(prefix)

        for name, ref in pairs(_G) do
            if ref and type(ref) == "table" and ref.GetObjectType and string.sub(name, 1, len) == prefix then
                result[name] = ref
            end
        end
    end

    return result
end

function AddOn:EnhanceControls(rootFrame)
    self:Debug("EnhanceControls")

    for name, frame in pairs(self:FindFrames(rootFrame:GetName())) do
        local type = frame:GetObjectType()

        if type == "FontString" then
            local text = frame:GetText()

            if text then
                frame:SetText(L[text])
            end
        elseif type == "CheckButton" then
            if frame.tooltipText then
                frame.tooltipText = L[frame.tooltipText]
            end

            local text = _G[name .. "Text"]

            frame.Disable = function(self)
                getmetatable(self).__index.Disable(self)
                text:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
            end

            frame.Enable = function(self)
                getmetatable(self).__index.Enable(self)
                text:SetTextColor(text:GetFontObject():GetTextColor())
            end
        end
    end
end

function AddOn:RegisterConfigPanel(frame)
    self:Debug("RegisterConfigPanel")
    self.configPanel = frame
end

function AddOn:Debug(...)
    addonNamespace.Debug(...)
end