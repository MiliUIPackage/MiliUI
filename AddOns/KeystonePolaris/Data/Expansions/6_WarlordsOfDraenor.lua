local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.WOD_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    SKY = { -- Skyreach
        id = 161,
        mapID = 1209,
        teleportID = {159898, 1254557},
        bosses = {
            {1, 28.07, false, 1, 965, "Ranjit", 75964},
            {2, 52.2,  false, 2, 966, "Araknath", 76141},
            {3, 60.09, false, 3, 967, "Rukhran", 76143},
            {4, 100,   true,  4, 968, "High Sage Viryx", 76266}
        }
    }
}
