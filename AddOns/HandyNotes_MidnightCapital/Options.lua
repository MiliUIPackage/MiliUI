local addonName, ns = ...
local L = ns.L

local FILTER_OPTIONS = {
    { key = "show_services", name = L.SHOW_SERVICES, label = L.SHOW_SERVICES },
    { key = "show_professions", name = L.SHOW_PROFESSIONS, label = L.SHOW_PROFESSIONS },
    { key = "show_activities", name = L.SHOW_ACTIVITIES, label = L.SHOW_ACTIVITIES },
    { key = "show_travel", name = L.SHOW_TRAVEL, label = L.SHOW_TRAVEL },
    { key = "show_portals", name = L.SHOW_PORTALS, label = L.SHOW_PORTALS },
}

ns.defaults = {
    profile = {
        show_worldmap_button = true,
        minimap_icon_scale = 1.2,
        map_icon_scale = 1.6,
        icon_alpha = 1.0,
        show_services = true,
        show_professions = true,
        show_activities = true,
        show_travel = true,
        show_portals = true,
    }
}

ns.filterOptions = FILTER_OPTIONS

local function ApplyDefaults(target, defaults)
    for key in pairs(target) do
        if defaults[key] == nil then
            target[key] = nil
        end
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end

            ApplyDefaults(target[key], value)
        else
            target[key] = value
        end
    end
end

local function NotifyOptionsChanged()
    local registry = LibStub("AceConfigRegistry-3.0", true)
    if registry and registry.NotifyChange then
        registry:NotifyChange(addonName)
    end

    if ns.RefreshWorldMapOptions then
        ns.RefreshWorldMapOptions()
    end

    if ns.core and ns.core.Refresh then
        ns.core:Refresh()
    end
end

function ns.GetOption(key)
    return ns.db[key]
end

function ns.SetOption(key, value)
    ns.db[key] = value
    NotifyOptionsChanged()
end

function ns.SetAllFilterOptions(value)
    for _, option in ipairs(FILTER_OPTIONS) do
        ns.db[option.key] = value
    end

    NotifyOptionsChanged()
end

function ns.ResetOptions()
    ApplyDefaults(ns.db, ns.defaults.profile)
    NotifyOptionsChanged()
end

ns.options = {
    type = "group",
    name = L.ADDON_NAME,
    desc = L.ADDON_DESCRIPTION,
    get = function(info) return ns.GetOption(info[#info]) end,
    set = function(info, v) ns.SetOption(info[#info], v) end,
    args = {
        show_worldmap_button = {
            type = "toggle",
            name = L.SHOW_WORLD_MAP_BUTTON,
            desc = L.SHOW_WORLD_MAP_BUTTON_DESC,
            width = "full",
            order = 1,
        },
        minimap_icon_scale = {
            type = "range",
            name = L.MINIMAP_ICON_SCALE,
            desc = L.MINIMAP_ICON_SCALE_DESC,
            min = 0.5, max = 3, step = 0.1,
            order = 2,
        },
        map_icon_scale = {
            type = "range",
            name = L.MAP_ICON_SCALE,
            desc = L.MAP_ICON_SCALE_DESC,
            min = 0.5, max = 3, step = 0.1,
            order = 3,
        },
        icon_alpha = {
            type = "range",
            name = L.ICON_ALPHA,
            desc = L.ICON_ALPHA_DESC,
            min = 0.1, max = 1, step = 0.05,
            order = 4,
        },
        filters = {
            type = "group",
            name = L.FILTERS,
            inline = true,
            order = 5,
            args = {
                show_services = { type = "toggle", name = L.SHOW_SERVICES, order = 1 },
                show_professions = { type = "toggle", name = L.SHOW_PROFESSIONS, order = 2 },
                show_activities = { type = "toggle", name = L.SHOW_ACTIVITIES, order = 3 },
                show_travel = { type = "toggle", name = L.SHOW_TRAVEL, order = 4 },
                show_portals = { type = "toggle", name = L.SHOW_PORTALS, order = 5 },
            }
        },
        reset_defaults = {
            type = "execute",
            name = L.RESET_TO_DEFAULTS,
            desc = L.RESET_TO_DEFAULTS_DESC,
            confirm = function()
                return L.RESET_CONFIRM
            end,
            func = ns.ResetOptions,
            width = "full",
            order = 6,
        },
    }
}
