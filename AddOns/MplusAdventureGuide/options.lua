local addonName, addon = ...

function addon:setupOptions()
    local defaults = {
        profile = {
            highestFortTyr = true,
            itemUpgrade = true,
            portalButtons = true,
            watermark = true,
            achievementExpansionFeatures = true,
            keystoneMovable = true,
            plunderstormRenown = true,
            acronyms = false,
            wardrobeClassColours = true,
            warbandTransferable = true,
            currencyTransferAllButton = true,
        },
    }
        
    addon.db = LibStub("AceDB-3.0"):New("MPlusAdventureGuideADB", defaults)
        
    local options = {
        type = "group",
        args = {
            description = {
                name = "All changes require a /reload to take effect!",
                type = "description",
                fontSize = "medium",
                order = 0,
            },
            highestFortTyr = {
                type = "toggle",
                name = "Enable Highest Fortified/Tyrannical Module",
                set = function(info, v) addon.db.profile.highestFortTyr = v end,
                get = function() return addon.db.profile.highestFortTyr end,
                width = "full",
            },
            showCompleted = {
                type = "toggle",
                name = "Enable Item Upgrade Range Module",
                set = function(info, v) addon.db.profile.itemUpgrade = v end,
                get = function() return addon.db.profile.itemUpgrade end,
                width = "full",
            },
            showCoordinates = {
                type = "toggle",
                name = "Enable Portal Buttons Module",
                set = function(info, v) addon.db.profile.portalButtons = v end,
                get = function() return addon.db.profile.portalButtons end,
                width = "full",
            },
            hideZoneCaldera = {
                type = "toggle",
                name = "Enable Watermark Module",
                set = function(info, v) addon.db.profile.watermark = v end,
                get = function() return addon.db.profile.watermark end,
                width = "full",
            },
            achievementExpansionFeatures = {
                type = "toggle",
                name = "Enable Achievements Expansion Features Module",
                set = function(info, v) addon.db.profile.achievementExpansionFeatures = v end,
                get = function() return addon.db.profile.achievementExpansionFeatures end,
                width = "full",
            },
            keystoneMovable = {
                type = "toggle",
                name = "Enable Keystone Movable Module",
                set = function(info, v) addon.db.profile.keystoneMovable = v end,
                get = function() return addon.db.profile.keystoneMovable end,
                width = "full",
            },
            plunderstormRenown = {
                type = "toggle",
                name = "Enable Plunderstorm Renown Module",
                set = function(info, v) addon.db.profile.plunderstormRenown = v end,
                get = function() return addon.db.profile.plunderstormRenown end,
                width = "full",
            },
            acronyms = {
                type = "toggle",
                name = "Enable Mythic+ Acronym Module",
                set = function(info, v) addon.db.profile.acronyms = v end,
                get = function() return addon.db.profile.acronyms end,
                width = "full",
            },
            wardrobeClassColours = {
                type = "toggle",
                name = "Enable Wardrobe Class Colours Module",
                set = function(info, v) addon.db.profile.wardrobeClassColours = v end,
                get = function() return addon.db.profile.wardrobeClassColours end,
                width = "full",
            },
            warbandTransferable = {
                type = "toggle",
                name = "Enable Warband Transferable Module: Always show the 'Warband Transferable' icons on the Currency window",
                set = function(info, v) addon.db.profile.warbandTransferable = v end,
                get = function() return addon.db.profile.warbandTransferable end,
                width = "full",
            },
            currencyTransferAllButton = {
                type = "toggle",
                name = "Enable Currency Transfer All Button Module",
                set = function(info, v) addon.db.profile.currencyTransferAllButton = v end,
                get = function() return addon.db.profile.currencyTransferAllButton end,
                width = "full",
            },
        },
    }

    LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(options, addonName)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options, {"mplusadventureguide"})
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName)
end
