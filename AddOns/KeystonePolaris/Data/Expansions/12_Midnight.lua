local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.MIDNIGHT_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    MAGI = { -- Magisters' Terrace
        id = 558,
        mapID = 2811,
        displayName = "Magisters' Terrace",
        teleportID = 1254572,
        bosses = {
            {1, 27.81, false, 1, 2659, "Arcanotron Custos"}, -- Arcanotron Custos
            {2, 48.91, false, 2, 2661, "Seranel Sunlash"}, -- Seranel Sunlash
            {3, 78.06, false, 3, 2660, "Gemellus"}, -- Gemellus
            {4, 100,   true,  4, 2662, "Degentrius"} -- Degentrius
        }
    },
    MAIS = { -- Maisara Caverns
        id = 560,
        mapID = 2874,
        displayName = "Maisara Caverns",
        teleportID = 1254559,
        bosses = {
            {1, 48.6,  false, 1, 2810, "Muro'jin and Nekraxx"}, -- Muro'jin and Nekraxx
            {2, 89.95, false, 2, 2811, "Vordaza"}, -- Vordaza
            {3, 100,   true,  3, 2812, "Rak'tul, Vessel of Souls"}, -- Rak'tul, Vessel of Souls
        }
    },
    NPX = { -- Nexus-Point Xenas
        id = 559,
        mapID = 2915,
        displayName = "Nexus-Point Xenas",
        teleportID = 1254563,
        bosses = {
            {1, 29.36, false, 1, 2813, "Chief Corewright Kasreth"}, -- Chief Corewright Kasreth
            {2, 73.66, false, 2, 2814, "Corewarden Nysarra"}, -- Corewarden Nysarra
            {3, 100,   true,  3, 2815, "Lothraxion"}, -- Lothraxion
        }
    },
    WIS = { -- Windrunner Spire
        id = 557,
        mapID = 2805,
        displayName = "Windrunner Spire",
        teleportID = 1254400,
        bosses = {
            {1, 45.35, false, 1, 2655, "Emberdawn"}, -- Emberdawn
            {2, 57.36, false, 2, 2656, "Derelict Duo"}, -- Derelict Duo
            {3, 100,   true,  3, 2657, "Commander Kroluk"}, -- Commander Kroluk
            {4, 100,   true,  4, 2658, "The Restless Heart"}, -- The Restless Heart
        }
    },
}
