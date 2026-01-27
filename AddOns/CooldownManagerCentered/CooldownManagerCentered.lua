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
    -- MiliUI Profile Injection (Clean & Robust)
    -- Instead of just checking if DB is nil, we also update the addon's internal default settings.
    -- This ensures that even if the user resets their profile later, it reverts to THESE defaults
    -- rather than the addon's original factory settings.
    if MiliUI_Luxthos_CMCDB and MiliUI_Luxthos_CMCDB.profiles and MiliUI_Luxthos_CMCDB.profiles["Luxthos"] then
        local luxthosDefaults = MiliUI_Luxthos_CMCDB.profiles["Luxthos"]
        
        -- Ensure profile defaults table exists
        if not ns.DEFAULT_SETTINGS then ns.DEFAULT_SETTINGS = {} end
        if not ns.DEFAULT_SETTINGS.profile then ns.DEFAULT_SETTINGS.profile = {} end
        
        -- Overwrite internal defaults with Luxthos settings
        for k, v in pairs(luxthosDefaults) do
            ns.DEFAULT_SETTINGS.profile[k] = v
        end
        -- print("MiliUI: Injected Luxthos settings into CMC defaults.")
    end

    self.db = LibStub("AceDB-3.0"):New("CooldownManagerCenteredDB", ns.DEFAULT_SETTINGS, true)
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
    ns.Swipe:Initialize()

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
    ns.Swipe:Initialize()

    _cleanup()
end
local gameVersion = select(1, GetBuildInfo())
addon.isMidnight = gameVersion:match("^12")
addon.isRetail = gameVersion:match("^11")
