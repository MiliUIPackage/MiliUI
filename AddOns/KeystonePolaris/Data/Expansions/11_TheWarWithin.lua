local AddOnName, KeystonePolaris = ...

-- Define a single source of truth for dungeon data
KeystonePolaris.TWW_DUNGEON_DATA = {
    -- Format: [shortName] = {id = dungeonID, bosses = {{bossID, percent, shouldInform, bossOrder, journalEncounterID}, ...}}
    AKCE = { -- Ara-Kara, City of Echoes
        id = 503,
        mapID = 2660,
        teleportID = 445417,
        bosses = {
            {1, 37.75, false, 1, 2583},
            {2, 73.50, false, 2, 2584},
            {3, 100, true, 3, 2585}
        }
    },
    CoT = { -- City of Threads
        id = 502,
        mapID = 2669,
        teleportID = 445416,
        bosses = {
            {1, 31.54, false, 1, 2594},
            {2, 56.60, false, 2, 2595},
            {3, 87.60, false, 3, 2596},
            {4, 100, true, 4, 2600}
        }
    },
    CBM = { -- Cinderbrew Meadery
        id = 506,
        mapID = 2661,
        teleportID = 445440,
        bosses = {
            {1, 24.87, false, 1, 2586},
            {2, 61.33, false, 2, 2587},
            {3, 97.96, true, 3, 2588},
            {4, 100, true, 4, 2589}
        }
    },
    DFC = { -- Darkflame Cleft
        id = 504,
        mapID = 2651,
        teleportID = 445441,
        bosses = {
            {1, 28.24, false, 1, 2569},
            {2, 65.02, true, 2, 2559},
            {3, 80.05, true, 3, 2560},
            {4, 100, true, 4, 2561}
        }
    },
    OFG = { -- Operation: Floodgate
        id = 525,
        mapID = 2773,
        teleportID = 1216786,
        bosses = {
            {1, 36.81, false, 2, 2648},
            {2, 67.86, false, 1, 2649},
            {3, 57.87, true, 3, 2650},
            {4, 100, true, 4, 2651}
        }
    },
    PotSF = { -- Priory of the Sacred Flame
        id = 499,
        mapID = 2649,
        teleportID = 445444,
        bosses = {
            {1, 46.98, false, 1, 2571},
            {2, 69.48, false, 2, 2570},
            {3, 100, true, 3, 2573}
        }
    },
    TDB = { -- The Dawnbreaker
        id = 505,
        mapID = 2662,
        teleportID = 445414,
        bosses = {
            {1, 29.78, false, 1, 2580},
            {2, 93.48, false, 2, 2581},
            {3, 100, true, 3, 2593}
        }
    },
    TR = { -- The Rookery
        id = 500,
        mapID = 2648,
        teleportID = 445443,
        bosses = {
            {1, 41.13, false, 1, 2566},
            {2, 66.73, false, 2, 2567},
            {3, 100, true, 3, 2568}
        }
    },
    TSV = { -- The Stonevault
        id = 501,
        mapID = 2652,
        teleportID = 445269,
        bosses = {
            {1, 26.79, false, 1, 2572},
            {2, 54.40, false, 2, 2579},
            {3, 75.66, false, 3, 2590},
            {4, 100, true, 4, 2582}
        }
    },
    EDAD = { -- Eco-Dome Al'dani
        id = 542,
        mapID = 2830,
        teleportID = 1237215,
        bosses = {
            {1, 18.92, false, 1, 2675},
            {2, 57.12, false, 2, 2676},
            {3, 100, true, 3, 2677}
        }
    }
}
