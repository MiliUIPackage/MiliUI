local addonName, addon = ...

function addon:setupOptions()
    local defaults = {
        profile = {
            itemUpgrade = true,
            itemUpgradeOldSeasons = true,
            portalButtons = true,
            watermark = true,
            achievementExpansionFeatures = true,
            achievementTrackerFix = true,
            keystoneMovable = true,
            acronyms = false,
            wardrobeClassColours = true,
            delvesProgressTooltip = true,
            inspectilvl = true,
            premadeFinderRedX = true,
            remixIP = false,
            houseDropdownFactionIcon = true,
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
            itemUpgrade = {
                type = "toggle",
                name = "Enable Item Upgrade Range Module",
                set = function(_, v) addon.db.profile.itemUpgrade = v end,
                get = function() return addon.db.profile.itemUpgrade end,
                width = "full",
            },
            itemUpgradeOldSeasons = {
                type = "toggle",
                name = "Item Upgrade Module: include old seasons (requires /reload)",
                set = function(_, v) addon.db.profile.itemUpgradeOldSeasons = v end,
                get = function() return addon.db.profile.itemUpgradeOldSeasons end,
                width = "full",
            },
            showCoordinates = {
                type = "toggle",
                name = "Enable Portal Buttons Module",
                set = function(_, v) addon.db.profile.portalButtons = v end,
                get = function() return addon.db.profile.portalButtons end,
                width = "full",
            },
            hideZoneCaldera = {
                type = "toggle",
                name = "Enable Watermark Module",
                set = function(_, v) addon.db.profile.watermark = v end,
                get = function() return addon.db.profile.watermark end,
                width = "full",
            },
            achievementExpansionFeatures = {
                type = "toggle",
                name = "Enable Achievements Expansion Features Module",
                set = function(_, v) addon.db.profile.achievementExpansionFeatures = v end,
                get = function() return addon.db.profile.achievementExpansionFeatures end,
                width = "full",
            },
            achievementTrackerFix = {
                type = "toggle",
                name = "Enable Achievement Tracker Fix Module",
                set = function(_, v) addon.db.profile.achievementTrackerFix = v end,
                get = function() return addon.db.profile.achievementTrackerFix end,
                width = "full",
            },
            keystoneMovable = {
                type = "toggle",
                name = "Enable Keystone Movable Module",
                set = function(_, v) addon.db.profile.keystoneMovable = v end,
                get = function() return addon.db.profile.keystoneMovable end,
                width = "full",
            },
            acronyms = {
                type = "toggle",
                name = "Enable Mythic+ Acronym Module",
                set = function(_, v) addon.db.profile.acronyms = v end,
                get = function() return addon.db.profile.acronyms end,
                width = "full",
            },
            wardrobeClassColours = {
                type = "toggle",
                name = "Enable Wardrobe Class Colours Module",
                set = function(_, v) addon.db.profile.wardrobeClassColours = v end,
                get = function() return addon.db.profile.wardrobeClassColours end,
                width = "full",
            },
            delvesProgressTooltip = {
                type = "toggle",
                name = "Enable Delves Progress Tooltip Module",
                set = function(_, v) addon.db.profile.delvesProgressTooltip = v end,
                get = function() return addon.db.profile.delvesProgressTooltip end,
                width = "full",
            },
            inspectilvl = {
                type = "toggle",
                name = "Enable Inspect Item Level Module",
                desc = "Adds the target's item level to the Inspect UI",
                set = function(_, v) addon.db.profile.inspectilvl = v end,
                get = function() return addon.db.profile.inspectilvl end,
                width = "full",
            },
            premadeFinderRedX = {
                type = "toggle",
                name = "Enable Premade Finder Red X Module",
                desc = "Hides that annoying Red X that appears over the Filter button but also clips over the Refresh button",
                set = function(_, v) addon.db.profile.premadeFinderRedX = v end,
                get = function() return addon.db.profile.premadeFinderRedX end,
                width = "full",
            },
            remixIP = {
                type = "toggle",
                name = "Enable Remix Infinite Power Module",
                set = function(_, v) addon.db.profile.remixIP = v end,
                get = function() return addon.db.profile.remixIP end,
                width = "full",
            },
            houseDropdownFactionIcon = {
                type = "toggle",
                name = "Enable Housing Dashboard Dropdown Faction Icon Module",
                desc = "Adds a Faction Icon to the Dropdown so you know which house belongs to which faction",
                set = function(_, v) addon.db.profile.houseDropdownFactionIcon = v end,
                get = function() return addon.db.profile.houseDropdownFactionIcon end,
                width = "full",
            },
        },
    }

    LibStub("AceConfigRegistry-3.0"):ValidateOptionsTable(options, addonName)
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options, {"mplusadventureguide"})
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName)
    
    addon:initItemUpgradeOldSeasons()
end
