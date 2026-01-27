local _, ns = ...
local addon = ns.Addon

function addon:OpenSettings()
    if InCombatLockdown() then
        ns.Addon:Print("Cannot open settings panel while in combat.")
        return
    end

    local id = ns.WilduSettings.SettingsLayout.rootCategory:GetID()
    Settings.OpenToCategory(id)
end

function addon:OnInitialize()
    -- MiliUI Profile
    if not CooldownManagerCenteredDB then
        if MiliUI_Luxthos_CMCDB then
            print("MiliUI: Injecting CMC defaults")
            CooldownManagerCenteredDB = CopyTable(MiliUI_Luxthos_CMCDB)
        else
            print("MiliUI: CMC defaults not found")
        end
    else
        print("MiliUI: CMC DB already exists")
    end
    self.db = LibStub("AceDB-3.0"):New("CooldownManagerCenteredDB", ns.DEFAULT_SETTINGS, true)
    
    
    if self.db:GetCurrentProfile() == "Default" then
        self.db:SetProfile("Luxthos")
    end

    ns.db = self.db

    -- Register database callbacks for profile changes
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    self.db.RegisterCallback(self, "OnNewProfile", "OnNewProfile")
    self.db.RegisterCallback(self, "OnProfileDeleted", "OnProfileDeleted")

    ns.WilduSettings:RegisterSettings()
    ns.WilduSettings:InitializeSettings()
end
local openCooldownViewerSettings = function()
    if not InCombatLockdown() then
        CooldownViewerSettings:ShowUIPanel(false)
    else
        ns.Addon:Print("Cannot open Cooldown Viewer settings while in combat.")
    end
end

SLASH_CMC_CVS1 = "/cds"
SLASH_CMC_CVS2 = "/cdm"
SlashCmdList["CMC_CVS"] = openCooldownViewerSettings
SLASH_CMC_SETTINGS1 = "/cmc"
SlashCmdList["CMC_SETTINGS"] = function()
    addon:OpenSettings()
end

function addon:RefreshConfig()
    ns.StyledIcons:Initialize()
    ns.CooldownManager.Initialize()
    ns.Stacks:Initialize()
    ns.Keybinds:Initialize()
    ns.Assistant:Initialize()

    ns.API:RefreshCooldownManager()
    ns.API:ShowReloadUIConfirmation()
    self:Print("Profile settings applied.")
end

function addon:OnNewProfile(event, db, profile)
    self:Print("Created new profile: " .. profile)
end

function addon:OnProfileDeleted(event, db, profile)
    self:Print("Deleted profile: " .. profile)
end

local function _cleanup()
    ns.db.profile.cooldownManager_forceCenterX_BuffIcons = false
    ns.db.profile.cooldownManager_forceCenterX_Essential = false
    ns.db.profile.cooldownManager_forceCenterX_Utility = false
    ns.db.profile.cooldownManager_forceCenterX_BuffIcons_lastY = {}
    ns.db.profile.cooldownManager_forceCenterX_Essential_lastY = {}
    ns.db.profile.cooldownManager_forceCenterX_Utility_lastY = {}
end

function addon:OnEnable()
    C_CVar.SetCVar("cooldownViewerEnabled", "1")
    ns.StyledIcons:Initialize()
    ns.CooldownManager.Initialize()
    ns.Stacks:Initialize()
    ns.Keybinds:Initialize()
    ns.Assistant:Initialize()

    _cleanup()
end
local gameVersion = select(1, GetBuildInfo())
addon.isMidnight = gameVersion:match("^12")
addon.isRetail = gameVersion:match("^11")
