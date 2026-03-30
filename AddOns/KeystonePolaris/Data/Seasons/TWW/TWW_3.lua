local AddOnName, KeystonePolaris = ...

-- Define which dungeons are in the current season
-- start_date: YYYY-MM-DD (required) or table keyed by portal (US/EU)
-- end_date: YYYY-MM-DD (optional) or table keyed by portal (US/EU)
KeystonePolaris.TWW_3_DUNGEONS = {
    start_date = {
        US = "2025-08-12",
        EU = "2025-08-13",
        default = "2025-08-13"
    },
    end_date = {
        US = "2026-01-20 05:00",
        EU = "2026-01-21 05:00",
        default = "2026-01-21 05:00"
    },
    -- War Within dungeons
    [503] = true, -- AKCE (Ara-Kara, City of Echoes)
    [499] = true, -- PotSF (Priory of the Sacred Flame)
    [505] = true, -- TDB (The Dawnbreaker)
    [525] = true, -- OFG (Operation: Floodgate)
    [542] = true, -- EDAD (Eco-dome Al'dani) (Coming in 11.2)
    -- Shadowlands dungeons
    [391] = true, -- TSoW (Tazavesh: Streets of Wonder)
    [392] = true, -- TSLG (Tazavesh: So'leah's Gambit)
    [378] = true, -- HoA (Halls of Atonement)
}