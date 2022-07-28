HandyNotes_Draenor = LibStub("AceAddon-3.0"):NewAddon("HandyNotes_Draenor", "AceEvent-3.0", "AceBucket-3.0")

HandyNotes_Draenor.nodes = {}

HandyNotes_Draenor.DefaultNodeTypes = {
    Treasure = "Treasure",
    Treasure_Quest = "Treasure_Quest",
    Rare = "Rare",
    Mount_VoidTalon = "Mount_VoidTalon",
    Mount_Pathrunner = "Mount_Pathrunner",
    Mount_Poundfist = "Mount_Poundfist",
    Mount_NakkTheThunderer = "Mount_NakkTheThunderer",
    Mount_Lukhok = "Mount_Lukhok",
    Mount_Silthide = "Mount_Silthide",
    Mount_Gorok = "Mount_Gorok",
    Mount_NokKarosh = "Mount_NokKarosh",
    Mount_Doomroller = "Mount_Doomroller",
    Mount_Vengeance = "Mount_Vengeance",
    Mount_Deathtalon = "Mount_Deathtalon",
    Mount_Terrorfist = "Mount_Terrorfist",
}

HandyNotes_Draenor.DefaultIcons = {
    Icon_Treasure_Default = "Interface\\Addons\\HandyNotes_Draenor\\Artwork\\Chest.blp",
    Icon_Skull_Blue = "Interface\\Addons\\HandyNotes_Draenor\\Artwork\\Skull-Blue.blp",
    Icon_Skull_Grey = "Interface\\Addons\\HandyNotes_Draenor\\Artwork\\Skull-White.tga",
    Icon_Mount_Green = "Interface\\Addons\\HandyNotes_Draenor\\Artwork\\Portal-Green.blp",
    Icon_Mount_Red = "Interface\\Addons\\HandyNotes_Draenor\\Artwork\\Portal-Red.blp",
    Icon_Mount_Blue = "Interface\\Addons\\HandyNotes_Draenor\\Artwork\\Portal-Blue.blp",
    Icon_Mount_Purple = "Interface\\Addons\\HandyNotes_Draenor\\Artwork\\Portal-Purple.blp",
    Icon_Scroll = "Interface\\Addons\\HandyNotes_Draenor\\Artwork\\Scroll.blp",
}

-- HandyNotes_Draenor.DefaultIcons.Icon_Treasure_Default

function HandyNotes_Draenor:OnInitialize()

    local Defaults = {
        profile = {
            Settings = {
                General = {
                    ShowNotes = true,
                    DisplayRewardsInsteadDefaults = false,
                },
                Treasures = {
                    ShowAlreadyCollected = false,
                    IconScale = 1.0,
                    IconAlpha = 1.0,
                },
                Rares = {
                    ShowAlreadyKilled = false,
                    IconScale = 1.0,
                    IconAlpha = 1.0,
                },
            },
            Zones = {
                FrostfireRidge = {
                    Rares = true,
                    Treasures = true,
                },
                ShadowmoonValley = {
                    Rares = true,
                    Treasures = true,
                },
                Nagrand = {
                    Rares = true,
                    Treasures = true,
                },
                Gorgrond = {
                    Rares = true,
                    Treasures = true,
                },
                SpiresOfArak = {
                    Rares = true,
                    Treasures = true,
                },
                Talador = {
                    Rares = true,
                    Treasures = true,
                },
                TanaanJungle = {
                    Rares = true,
                    Treasures = true,
                },
            },
            Mounts = {
                Mount_VoidTalon = true,
                Mount_Pathrunner = true,
                Mount_Terrorfist = true,
                Mount_Deathtalon = true,
                Mount_Vengeance = true,
                Mount_Doomroller = true,
                Mount_Silthide = true,
                Mount_Lukhok = true,
                Mount_NakkTheThunderer = true,
                Mount_Poundfist = true,
                Mount_Gorok = true,
                Mount_NokKarosh = true,
            },
            Integration = {
                DBM = {
                    Loaded = false,
                    ArrowCreated = false,
                    ArrowNote = nil,
                },
                TomTom = {
                    Loaded = true,
                },
            },
        },
    }

    self.db = LibStub("AceDB-3.0"):New("HandyNotesDraenorDB", Defaults, "Default")

    if HandyNotes then 
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "WorldEnter")
        self:RegisterEvent("PLAYER_LEAVING_WORLD", "WorldLeave")
    else
        print("HandyNotes Draenor: HandyNotes is not installed")
        return
    end

end