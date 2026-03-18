local addonName, ns = ...
local L = ns.L

-- Official Midnight Silvermoon City uiMapID
ns.mapID = 2393

-- Coordinates are multiplied by 10000 to form the index (e.g., 50.2, 66.2 => 50206620)
ns.nodes = {
    -- ==========================================
    -- SERVICES & AMENITIES
    -- ==========================================
    [50206620] = { title = L.NODE_BANK_TITLE, category = "services", icon = "banker", desc = L.NODE_BANK_DESC, npc = L.NPC_VAULT_KEEPER },
    [50307490] = { title = L.NODE_BAZAAR_TITLE, category = "services", icon = "auctioneer", desc = L.NODE_BAZAAR_DESC, npc = L.NPC_AUCTIONEER },
    [55107030] = { title = L.NODE_MAIN_INN_TITLE, category = "services", icon = "innkeeper", desc = L.NODE_MAIN_INN_DESC, npc = L.NPC_INNKEEPER },
    [48306170] = { title = L.NODE_GEAR_UPGRADES_TITLE, category = "services", icon = "upgrade_gear", desc = L.NODE_GEAR_UPGRADES_DESC, npc = L.NPC_VASKARN_CUZOLTH },
    [40206480] = { title = L.NODE_CATALYST_TITLE, category = "services", icon = "catalyst", desc = L.NODE_CATALYST_DESC, npc = L.NPC_CATALYST },
    [51804840] = { title = L.NODE_BLACK_MARKET_TITLE, category = "services", icon = "auctioneer", desc = L.NODE_BLACK_MARKET_DESC, npc = L.NPC_MADAM_GOYA },
    [52405820] = { title = L.NODE_TRANSMOG_TITLE, category = "services", icon = "transmogrifier", desc = L.NODE_TRANSMOG_DESC, npc = L.NPC_WARPWEAVER },
    [42207850] = { title = L.NODE_BARBER_TITLE, category = "services", icon = "barber", desc = L.NODE_BARBER_DESC, npc = L.NPC_TRIM_AND_DYE_EXPERT },

    -- ==========================================
    -- TRAVEL & PORTALS
    -- ==========================================
    [42305830] = { title = L.NODE_TIMEWAYS_TITLE, category = "portals", icon = "portal", desc = L.NODE_TIMEWAYS_DESC, npc = L.NPC_LINDORMI },

    -- ==========================================
    -- MIDNIGHT ACTIVITIES & COMBAT
    -- ==========================================
    [52107770] = { title = L.NODE_DELVERS_TITLE, category = "activities", icon = "delves", desc = L.NODE_DELVERS_DESC, npc = L.NPC_VALEERA_ASTRANDIS },
    [34408100] = { title = L.NODE_PVP_TITLE, category = "activities", icon = "battlemaster", desc = L.NODE_PVP_DESC, npc = L.NPC_GLADIATOR_VENDORS },
    [36208450] = { title = L.NODE_TRAINING_DUMMIES_TITLE, category = "activities", icon = "training_dummy", desc = L.NODE_TRAINING_DUMMIES_DESC, npc = L.NPC_TARGET_DUMMIES },
    
    -- ==========================================
    -- PROFESSIONS
    -- ==========================================
    [45705220] = { title = L.NODE_PROFESSIONS_AREA_TITLE, category = "professions", icon = "profession", desc = L.NODE_PROFESSIONS_AREA_DESC },
    [45205560] = { title = L.NODE_CRAFTING_ORDERS_TITLE, category = "professions", icon = "crafting_orders", desc = L.NODE_CRAFTING_ORDERS_DESC, npc = L.NPC_CONSORTIUM_CLERK },
    [44706020] = { title = L.NODE_FISHING_TITLE, category = "professions", icon = "fishing", desc = L.NODE_FISHING_DESC, npc = L.NPC_FISHING_MASTER },
    [56306970] = { title = L.NODE_COOKING_TITLE, category = "professions", icon = "cook", desc = L.NODE_COOKING_DESC, npc = L.NPC_SYLANN },
}

return ns
