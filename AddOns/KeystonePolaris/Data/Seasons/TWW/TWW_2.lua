local AddOnName, KeystonePolaris = ...

-- Define which dungeons are in the current season
-- start_date: YYYY-MM-DD (required) or table keyed by portal (US/EU)
-- end_date: YYYY-MM-DD (optional) or table keyed by portal (US/EU)
KeystonePolaris.TWW_2_DUNGEONS = {
    start_date = {
        US = "2025-03-04",
        EU = "2025-03-05",
        default = "2025-03-05"
    },
    end_date = {
        US = "2025-08-11",
        EU = "2025-08-12",
        default = "2025-08-12"
    },
    -- War Within dungeons
    [506] = true, -- CBM (Cinderbrew Meadery)
    [504] = true, -- DFC (Darkflame Cleft)
    [525] = true, -- OFG (Operation: Floodgate)
    [499] = true, -- PotSF (Priory of the Sacred Flame)
    [500] = true, -- TR (The Rookery)
    -- Shadowlands
    [382] = true, -- ToP (Theater of Pain)
    -- Battle for Azeroth dungeons
    [370] = true, -- OMGW (Operation: Mechagon - Workshop)
    [247] = true, -- TML (The MOTHERLODE!!)
}