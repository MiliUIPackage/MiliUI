local addonName, ns = ...
local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")
local Core = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0")
local L = ns.L

ns.core = Core

local function MigrateProfile(profile)
    local legacyScale = rawget(profile, "icon_scale")
    if legacyScale == nil then
        return
    end

    if legacyScale == 1.5 then
        legacyScale = nil
    end

    if rawget(profile, "minimap_icon_scale") == nil then
        profile.minimap_icon_scale = legacyScale or ns.defaults.profile.minimap_icon_scale
    end

    if rawget(profile, "map_icon_scale") == nil then
        profile.map_icon_scale = legacyScale or ns.defaults.profile.map_icon_scale
    end

    profile.icon_scale = nil
end

function Core:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("HandyNotes_MidnightCapitalDB", ns.defaults, true)
    ns.db = self.db.profile
    MigrateProfile(ns.db)

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, ns.options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, L.ADDON_NAME, "HandyNotes")

    HandyNotes:RegisterPluginDB(addonName, ns.PluginHandler, ns.options)
end

function Core:OnEnable()
    if ns.InitializeWorldMapOptions then
        ns.InitializeWorldMapOptions()
    end
end

function Core:Refresh()
    HandyNotes:SendMessage("HandyNotes_NotifyUpdate", addonName)
end
