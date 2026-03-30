local AddOnName, KeystonePolaris = ...

-- Define which dungeons are in the current season
-- start_date: YYYY-MM-DD (required) or table keyed by portal (US/EU)
-- end_date: YYYY-MM-DD (optional) or table keyed by portal (US/EU)
KeystonePolaris.TWW_1_DUNGEONS = {
    start_date = {
        US = "2024-09-10",
        EU = "2024-09-10",
        default = "2024-09-10"
    },
    end_date = {
        US = "2025-03-03",
        EU = "2025-03-04",
        default = "2025-03-04"
    },
    -- War Within dungeons
    [503] = true, -- AKCE (Ara-Kara, City of Echoes)
    [502] = true, -- CoT (City of Threads)
    [505] = true, -- TDB (The Dawnbreaker)
    [501] = true, -- TSV (The Stonevault)
    -- Shadowlands dungeons
    [375] = true, -- MoTS (Mists of Tirna Scithe)
    [376] = true, -- NW (Necrotic Wake)
    -- BFA dungeons
    [353] = true, -- SoB (Siege of Boralus)
    -- Cataclysm dungeons
    [507] = true, -- GB (Grim Batol)
}