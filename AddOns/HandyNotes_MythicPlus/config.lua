local myname, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(myname, false)

ns.defaults = {
    profile = {
        icon_scale = 1.5,
        icon_alpha = 1.0,
        entrances = true,
        upcoming = false,
    },
}

ns.options = {
    type = "group",
    name = myname:gsub("HandyNotes_", ""),
    get = function(info) return ns.db[info[#info]] end,
    set = function(info, v)
        ns.db[info[#info]] = v
        ns.HL:SendMessage("HandyNotes_NotifyUpdate", myname:gsub("HandyNotes_", ""))
    end,
    args = {
        icon = {
            type = "group",
            name = L["Settings_Icons"],
            inline = true,
            args = {
                desc = {
                    name = L["Settings_desc"],
                    type = "description",
                    order = 0,
                },
                icon_scale = {
                    type = "range",
                    name = L["Settings_iconscale"],
                    desc = L["Settings_iconscale_desc"],
                    min = 0.25, max = 2, step = 0.01,
                    order = 20,
                },
                icon_alpha = {
                    type = "range",
                    name = L["Settings_iconalpha"],
                    desc = L["Settings_iconalpha_desc"],
                    min = 0, max = 1, step = 0.01,
                    order = 30,
                },
            },
        },
    },
}
