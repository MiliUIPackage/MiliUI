HandyNotes_Draenor = LibStub("AceAddon-3.0"):GetAddon("HandyNotes_Draenor")

HandyNotes_Draenor.options = {
    type = "group",
    name = "Draenor",
    desc = "Locations of Rares and Treasures in Draenor",
    args = {

        IconSettingsGroup = {
            type = "group",
            order = 1,
            name = "Icon Settings:",
            inline = true,
            args = {
                Icon_Scale_Treasures = {
                    type = "range",
                    name = "Icon Scale for Treasures",
                    desc = "The scale of the icons",
                    min = 0.25, max = 3, step = 0.01,
                    order = 1,

                    get = function(info) return HandyNotes_Draenor.db.profile.Settings.Treasures.IconScale end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Settings.Treasures.IconScale = value; HandyNotes_Draenor:Refresh() end,
                },
                Icon_Scale_Rares = {
                    type = "range",
                    name = "Icon Scale for Rares",
                    desc = "The scale of the icons",
                    min = 0.25, max = 3, step = 0.01,
                    order = 2,

                    get = function(info) return HandyNotes_Draenor.db.profile.Settings.Rares.IconScale end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Settings.Rares.IconScale = value; HandyNotes_Draenor:Refresh() end,
                },
                Icon_Alpha_Treasures = {
                    type = "range",
                    name = "Icon Alpha for Treasures",
                    desc = "The alpha transparency of the icons",
                    min = 0, max = 1, step = 0.01,
                    order = 3,

                    get = function(info) return HandyNotes_Draenor.db.profile.Settings.Treasures.IconAlpha end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Settings.Treasures.IconAlpha = value; HandyNotes_Draenor:Refresh() end,
                },
                Icon_Alpha_Rares = {
                    type = "range",
                    name = "Icon Alpha for Rares",
                    desc = "The alpha transparency of the icons",
                    min = 0, max = 1, step = 0.01,
                    order = 4,

                    get = function(info) return HandyNotes_Draenor.db.profile.Settings.Rares.IconAlpha end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Settings.Rares.IconAlpha = value; HandyNotes_Draenor:Refresh() end,
                },
            },
        },
        VisibilityGroup = {
            type = "group",
            order = 2,
            name = "Visibility:",
            inline = true,
            args = {
                ShadowmoonValleyGroup = {
                    type = "header",
                    name = "Shadowmoon Valley",
                    desc = "Shadowmoon Valley",
                    order = 0,
                },
                ShadowmoonValleyTreasures = {
                    type = "toggle",
                    arg = "treasure_smv",
                    name = "Treasures",
                    desc = "Treasures that give various items",
                    order = 1,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.ShadowmoonValley.Treasures end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.ShadowmoonValley.Treasures = value; HandyNotes_Draenor:Refresh() end,
                },
                ShadowmoonValleyRares = {
                    type = "toggle",
                    arg = "rare_smv",
                    name = "Rares",
                    desc = "Rare spawns for leveling players",
                    order = 2,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.ShadowmoonValley.Rares end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.ShadowmoonValley.Rares = value; HandyNotes_Draenor:Refresh() end,
                },
                FrostfireRidgeGroup = {
                    type = "header",
                    name = "Frostfire Ridge",
                    desc = "Frostfire Ridge",
                    order = 10,
                },  
                FrostfireRidgeTreasures = {
                    type = "toggle",
                    name = "Treasures",
                    desc = "Treasures that give various items",
                    order = 11,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.FrostfireRidge.Treasures end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.FrostfireRidge.Treasures = value; HandyNotes_Draenor:Refresh() end,
                },
                FrostfireRidgeRares = {
                    type = "toggle",
                    name = "Rares",
                    desc = "Rare spawns for leveling players",
                    order = 12,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.FrostfireRidge.Rares end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.FrostfireRidge.Rares = value; HandyNotes_Draenor:Refresh() end,
                },
                GorgrondGroup = {
                    type = "header",
                    name = "Gorgrond",
                    desc = "Gorgrond",
                    order = 20,
                },  
                GorgrondTreasures = {
                    type = "toggle",
                    name = "Treasures",
                    desc = "Treasures that give various items",
                    order = 21,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.Gorgrond.Treasures end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.Gorgrond.Treasures = value; HandyNotes_Draenor:Refresh() end,
                },
                GorgrondRare = {
                    type = "toggle",
                    name = "Rares",
                    desc = "Rare spawns for leveling players",
                    order = 22,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.Gorgrond.Rares end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.Gorgrond.Rares = value; HandyNotes_Draenor:Refresh() end,
                },  
                TaladorGroup = {
                    type = "header",
                    name = "Talador",
                    desc = "Talador",
                    order = 30,
                },  
                TaladorTreasures = {
                    type = "toggle",
                    name = "Treasures",
                    desc = "Treasures that give various items",
                    order = 31,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.Talador.Treasures end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.Talador.Treasures = value; HandyNotes_Draenor:Refresh() end,
                },
                TaladorRares = {
                    type = "toggle",
                    name = "Rares",
                    desc = "Rare spawns for leveling players",
                    order = 32,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.Talador.Rares end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.Talador.Rares = value; HandyNotes_Draenor:Refresh() end,
                },  
                SpiresOfArakGroup = {
                    type = "header",
                    name = "Spires of Arak",
                    desc = "Spires of Arak",
                    order = 40,
                },    
                SpiresOfArakTreasures = {
                    type = "toggle",
                    name = "Treasures",
                    desc = "Treasures that give various items",
                    order = 41,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.SpiresOfArak.Treasures end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.SpiresOfArak.Treasures = value; HandyNotes_Draenor:Refresh() end,
                },
                SpiresOfArakRares = {
                    type = "toggle",
                    arg = "rare_soa",
                    name = "Rares",
                    desc = "Rare spawns for leveling players",
                    order = 42,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.SpiresOfArak.Rares end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.SpiresOfArak.Rares = value; HandyNotes_Draenor:Refresh() end,
                }, 
                NagrandGroup = {
                    type = "header",
                    name = "Nagrand",
                    desc = "Nagrand",
                    order = 50,
                },      
                NagrandTreasures = {
                    type = "toggle",
                    arg = "treasure_ng",
                    name = "Treasures",
                    desc = "Treasures that give various items",
                    order = 51,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.Nagrand.Treasures end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.Nagrand.Treasures = value; HandyNotes_Draenor:Refresh() end,
                },
                NagrandRares = {
                    type = "toggle",
                    name = "Rares",
                    desc = "Rare spawns for leveling players",
                    order = 52,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.Nagrand.Rares end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.Nagrand.Rares = value; HandyNotes_Draenor:Refresh() end,
                },
                TanaanJungleGroup = {
                    type = "header",
                    name = "Tanaan Jungle",
                    desc = "Tanaan Jungle",
                    order = 60,
                },
                TanaanJungleTreasures = {
                    type = "toggle",
                    name = "Treasures",
                    desc = "Treasures that give various items",
                    order = 61,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.TanaanJungle.Treasures end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.TanaanJungle.Treasures = value; HandyNotes_Draenor:Refresh() end,
                },
                TanaanJungleRares = {
                    type = "toggle",
                    name = "Rares",
                    desc = "Rare spawns for level 100 players",
                    order = 62,

                    get = function(info) return HandyNotes_Draenor.db.profile.Zones.TanaanJungle.Rares end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Zones.TanaanJungle.Rares = value; HandyNotes_Draenor:Refresh() end,
                },
                groupMount = {
                    type = "header",
                    name = "Mounts",
                    desc = "Mounts",
                    order = 70,
                },
                Mount_VoidTalon = {
                    type = "toggle",
                    name = "Void Talon",
                    desc = "Show Mount Void Talon",
                    order = 71,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_VoidTalon end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_VoidTalon = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_Pathrunner = {
                    type = "toggle",
                    name = "Pathrunner",
                    desc = "Show Mount Pathrunner",
                    order = 72,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_Pathrunner end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_Pathrunner = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_Terrorfist = {
                    type = "toggle",
                    name = "Terrorfist",
                    desc = "Show Mount Terrorfist",
                    order = 73,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_Terrorfist end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_Terrorfist = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_Deathtalon = {
                    type = "toggle",
                    name = "Deathtalon",
                    desc = "Show Mount Deathtalon",
                    order = 74,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_Deathtalon end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_Deathtalon = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_Doomroller = {
                    type = "toggle",
                    name = "Doomroller",
                    desc = "Show Mount Doomroller",
                    order = 75,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_Doomroller end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_Doomroller = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_Silthide = {
                    type = "toggle",
                    name = "Silthide",
                    desc = "Show Mount Silthide",
                    order = 76,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_Silthide end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_Silthide = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_Lukhok = {
                    type = "toggle",
                    name = "Luk Hok",
                    desc = "Show Mount Luk Hok",
                    order = 77,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_Lukhok end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_Lukhok = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_NakkTheThunderer = {
                    type = "toggle",
                    name = "Nakk the Thunderer",
                    desc = "Show Mount Nakk the Thunderer",
                    order = 78,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_NakkTheThunderer end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_NakkTheThunderer = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_Poundfist = {
                    type = "toggle",
                    name = "Poundfist",
                    desc = "Show Mount Poundfist",
                    order = 79,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_Poundfist end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_Poundfist = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_Gorok = {
                    type = "toggle",
                    name = "Gorok",
                    desc = "Show Mount Gorok",
                    order = 80,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_Gorok end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_Gorok = value; HandyNotes_Draenor:Refresh() end,
                },
                Mount_NokKarosh = {
                    type = "toggle",
                    name = "Nok Karosh",
                    desc = "Show Mount Nok Karosh",
                    order = 80,

                    get = function(info) return HandyNotes_Draenor.db.profile.Mounts.Mount_NokKarosh end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Mounts.Mount_NokKarosh = value; HandyNotes_Draenor:Refresh() end,
                },
            },
        },
        TooltipSettingsGroup = {
            type = "group",
            order = 3,
            name = "Tooltip Settings:",
            inline = true,
            args = {
                ShowNotes = {
                    type = "toggle",
                    name = "Show Notes",
                    desc = "Display Notes for some POI's",
                    order = 1,

                    get = function(info) return HandyNotes_Draenor.db.profile.Settings.General.ShowNotes end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Settings.General.ShowNotes = value; HandyNotes_Draenor:Refresh() end,
                },
                DisplayRewardsInsteadDefault = {
                    type = "toggle",
                    name = "Display Reward-Tooltip",
                    desc = "Display Rewards instead of the default tooltip style while hovering over nodes",
                    order = 2,

                    get = function(info) return HandyNotes_Draenor.db.profile.Settings.General.DisplayRewardsInsteadDefaults end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Settings.General.DisplayRewardsInsteadDefaults = value; HandyNotes_Draenor:Refresh() end,
                },
            },
        },
        GeneralGroup = {
            type = "group",
            order = 4,
            name = "General Settings:",
            inline = true,
            args = {
                ShowAlreadyKilledRares = {
                    type = "toggle",
                    name = "Already killed Rares",
                    desc = "Show already killed Rares",
                    order = 1,

                    get = function(info) return HandyNotes_Draenor.db.profile.Settings.Rares.ShowAlreadyKilled end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Settings.Rares.ShowAlreadyKilled = value; HandyNotes_Draenor:Refresh() end,
                },
                ShowAlreadyCollectedTreasures = {
                    type = "toggle",
                    name = "Already looted Treasures",
                    desc = "Show already looted Treasures",
                    order = 2,

                    get = function(info) return HandyNotes_Draenor.db.profile.Settings.Treasures.ShowAlreadyCollected end,
                    set = function(info, value) HandyNotes_Draenor.db.profile.Settings.Treasures.ShowAlreadyCollected = value; HandyNotes_Draenor:Refresh() end,
                },
            },
        },
    },
}