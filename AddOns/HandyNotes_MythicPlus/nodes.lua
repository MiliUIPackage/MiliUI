local myname, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(myname, false)

--[[ structure:
    [uiMapId] = {
        [coord] = {  -- coord = x*100 .. y*100 (e.g. 5050 = 50%, 50%)
            ["icon"]  = <number>,  -- icon index from HandyNotes
            ["title"] = L["KEY"],  -- tooltip title
            ["desc"]  = L["KEY"],  -- tooltip description (or "")
        },
    },
--]]
ns.points = {
    ---------------------------------------------------------------------------
    -- Legion
    ---------------------------------------------------------------------------

    -- Halls of Valor (HOV) — floor 1
    [704] = {
        [47516614] = {
            ["icon"]  = 12,
            ["title"] = L["HOV_percentage"],
            ["desc"]  = "",
        },
    },
    -- Halls of Valor (HOV) — floor 2
    [705] = {
        [51227199] = {
            ["icon"]  = 12,
            ["title"] = L["HOV_percentage"],
            ["desc"]  = "",
        },
        [54698831] = {
            ["icon"]  = 2,
            ["title"] = L["HOV_haldor"],
            ["desc"]  = L["HOV_haldor_desc"],
        },
        [48478382] = {
            ["icon"]  = 4,
            ["title"] = L["HOV_tor"],
            ["desc"]  = L["HOV_tor_desc"],
        },
        [48598885] = {
            ["icon"]  = 3,
            ["title"] = L["HOV_bjorn"],
            ["desc"]  = L["HOV_bjorn_desc"],
        },
        [54938347] = {
            ["icon"]  = 1,
            ["title"] = L["HOV_ranulf"],
            ["desc"]  = L["HOV_ranulf_desc"],
        },
    },
    -- Court of Stars (COS)
    [761] = {
        [53976105] = {
            ["icon"]  = 8,
            ["title"] = L["COS_percentage"],
            ["desc"]  = "",
        },
    },

    ---------------------------------------------------------------------------
    -- Battle for Azeroth
    ---------------------------------------------------------------------------

    -- Freehold (FH)
    [936] = {
        [39744706] = {
            ["icon"]  = 12,
            ["title"] = L["FH_percentage"],
            ["desc"]  = "",
        },
    },
    -- The Underrot (UNDR)
    [1041] = {
        [55525341] = {
            ["icon"]  = 12,
            ["title"] = L["UNDR_skip"],
            ["desc"]  = "",
        },
    },

    ---------------------------------------------------------------------------
    -- Shadowlands
    ---------------------------------------------------------------------------

    -- Mists of Tirna Scithe (MoTS)
    [1669] = {
        [78202990] = {
            ["icon"]  = 18,
            ["title"] = L["MoTSD_buff"],
            ["desc"]  = L["MoTSD_buff_desc"],
        },
        [89802310] = {
            ["icon"]  = 18,
            ["title"] = L["MoTSD_shortcut"],
            ["desc"]  = L["MoTSD_shortcut_desc"],
        },
        [41705251] = {
            ["icon"]  = 1,
            ["title"] = L["MoTSD_seed"],
            ["desc"]  = L["MoTSD_seed_desc"],
        },
        [67613199] = {
            ["icon"]  = 1,
            ["title"] = L["MoTSD_seed"],
            ["desc"]  = L["MoTSD_seed_desc"],
        },
    },

    ---------------------------------------------------------------------------
    -- Dragonflight
    ---------------------------------------------------------------------------

    -- Algeth'ar Academy (AA)
    [2097] = {
        [42856894] = {
            ["icon"]  = 2,
            ["title"] = L["AA_bronze_drake"],
            ["desc"]  = L["AA_bronze_drake_desc"],
        },
        [49675936] = {
            ["icon"]  = 7,
            ["title"] = L["AA_red_drake"],
            ["desc"]  = L["AA_red_drake_desc"],
        },
        [46565603] = {
            ["icon"]  = 4,
            ["title"] = L["AA_green_drake"],
            ["desc"]  = L["AA_green_drake_desc"],
        },
        [41896051] = {
            ["icon"]  = 6,
            ["title"] = L["AA_blue_drake"],
            ["desc"]  = L["AA_blue_drake_desc"],
        },
        [46567181] = {
            ["icon"]  = 5,
            ["title"] = L["AA_black_drake"],
            ["desc"]  = L["AA_black_drake_desc"],
        },
    },
    -- Ruby Life Pools (RLP)
    [2094] = {
        [39755387] = {
            ["icon"]  = 8,
            ["title"] = L["RS_thunderdragon"],
            ["desc"]  = L["RS_thunderdragon_desc"],
        },
        [67006470] = {
            ["icon"]  = 8,
            ["title"] = L["RS_firedragon"],
            ["desc"]  = L["RS_firedragon_desc"],
        },
    },
    -- The Nokhud Offensive (NO)
    [2093] = {
        [33764275] = {
            ["icon"]  = 12,
            ["title"] = L["NO_percentage"],
            ["desc"]  = "",
        },
    },
    -- Brackenhide Hollow (BH)
    [2096] = {
        [9733430] = {
            ["icon"]  = 12,
            ["title"] = L["BH_skip"],
            ["desc"]  = L["BH_skip_desc"],
        },
        [11413935] = {
            ["icon"]  = 19,
            ["title"] = L["BH_gen_cauldron"],
            ["desc"]  = L["BH_gen_cauldron_desc"],
        },
        [17863978] = {
            ["icon"]  = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"]  = L["BH_cauldron_desc"],
        },
        [21623021] = {
            ["icon"]  = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"]  = L["BH_cauldron_desc"],
        },
        [28503637] = {
            ["icon"]  = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"]  = L["BH_cauldron_desc"],
        },
        [40944319] = {
            ["icon"]  = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"]  = L["BH_cauldron_desc"],
        },
        [47636607] = {
            ["icon"]  = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"]  = L["BH_cauldron_desc"],
        },
    },
    -- Halls of Infusion (HOI) — main floor
    [2082] = {
        [39504892] = {
            ["icon"]  = 12,
            ["title"] = L["HOI_door"],
            ["desc"]  = "",
        },
        [50387403] = {
            ["icon"]  = 4,
            ["title"] = L["HOI_shortcut_frog"],
            ["desc"]  = "",
        },
        [28387360] = {
            ["icon"]  = 6,
            ["title"] = L["HOI_shortcut_icelady"],
            ["desc"]  = "",
        },
    },
    -- Halls of Infusion (HOI) — upper floor
    [2083] = {
        [45369179] = {
            ["icon"]  = 4,
            ["title"] = L["HOI_mushroom"],
            ["desc"]  = L["HOI_mushroom_desc"],
        },
    },
    -- Neltharus (NELT)
    [2080] = {
        [52065674] = {
            ["icon"]  = 12,
            ["title"] = L["NELT_percentage"],
            ["desc"]  = L["NELT_percentage_desc"],
        },
    },
    -- Uldaman: Legacy of Tyr (ULD)
    [2071] = {
        [25751879] = {
            ["icon"]  = 12,
            ["title"] = L["ULD_percentage"],
            ["desc"]  = "",
        },
        [57686786] = {
            ["icon"]  = 18,
            ["title"] = L["ULD_mining"],
            ["desc"]  = "",
        },
        [73708867] = {
            ["icon"]  = 18,
            ["title"] = L["ULD_mining"],
            ["desc"]  = "",
        },
        [80874419] = {
            ["icon"]  = 18,
            ["title"] = L["ULD_mining"],
            ["desc"]  = "",
        },
    },
    -- The Vortex Pinnacle (VP)
    [325] = {
        [31018095] = {
            ["icon"]  = 4,
            ["title"] = L["VP_slipstream"],
            ["desc"]  = L["VP_slipstream_desc2"],
        },
        [52532141] = {
            ["icon"]  = 4,
            ["title"] = L["VP_slipstream"],
            ["desc"]  = L["VP_slipstream_desc2"],
        },
        [63535843] = {
            ["icon"]  = 3,
            ["title"] = L["VP_slipstream"],
            ["desc"]  = L["VP_slipstream_desc1"],
        },
        [56601539] = {
            ["icon"]  = 3,
            ["title"] = L["VP_slipstream"],
            ["desc"]  = L["VP_slipstream_desc1"],
        },
    },

    ---------------------------------------------------------------------------
    -- The War Within
    ---------------------------------------------------------------------------

    -- Stonevault (SV)
    [2341] = {
        [35304940] = {
            ["icon"]  = 18,
            ["title"] = L["SV_buff"],
            ["desc"]  = L["SV_buff_desc"],
        },
    },
    -- City of Threads (CT)
    [2343] = {
        [48161811] = {
            ["icon"]  = 18,
            ["title"] = L["CT_buff"],
            ["desc"]  = L["CT_buff_desc"],
        },
        [55002100] = {
            ["icon"]  = 18,
            ["title"] = L["CT_buff"],
            ["desc"]  = L["CT_buff_desc"],
        },
        [55502990] = {
            ["icon"]  = 18,
            ["title"] = L["CT_buff"],
            ["desc"]  = L["CT_buff_desc"],
        },
    },
    -- Ara-Kara, City of Echoes (ARAK)
    [2357] = {
        [18005100] = {
            ["icon"]  = 18,
            ["title"] = L["ARAK_buff"],
            ["desc"]  = L["ARAK_buff_desc"],
        },
        [33403750] = {
            ["icon"]  = 18,
            ["title"] = L["ARAK_buff"],
            ["desc"]  = L["ARAK_buff_desc"],
        },
        [64104430] = {
            ["icon"]  = 18,
            ["title"] = L["ARAK_buff"],
            ["desc"]  = L["ARAK_buff_desc"],
        },
        [69105960] = {
            ["icon"]  = 18,
            ["title"] = L["ARAK_buff"],
            ["desc"]  = L["ARAK_buff_desc"],
        },
        [73105370] = {
            ["icon"]  = 18,
            ["title"] = L["ARAK_buff"],
            ["desc"]  = L["ARAK_buff_desc"],
        },
    },

    ---------------------------------------------------------------------------
    -- Midnight — Legacy Dungeons
    ---------------------------------------------------------------------------

    -- Algeth'ar Academy (AA) — uiMapId 2097, already present above

    -- Pit of Saron (POS) — uiMapId 184
    -- Bosses: Forgemaster Garfrost, Ick & Krick, Scourgelord Tyrannus
    [184] = {
        -- TODO: add coordinates (use /run print(C_Map.GetBestMapForUnit("player")))
    },

    -- Skyreach (SKY) — uiMapId 601 (main), 602 (upper)
    -- Bosses: Ranjit, Araknath, Rukhran, High Sage Viryx
    [601] = {
        -- TODO: add coordinates
    },
    [602] = {
        -- TODO: add coordinates
    },

    -- The Seat of the Triumvirate (SOT) — uiMapId 903
    -- Bosses: Zuraal the Ascended, Saprish, Viceroy Nezhar, L'ura
    [903] = {
        -- TODO: add coordinates
    },

    ---------------------------------------------------------------------------
    -- Midnight — New Dungeons
    ---------------------------------------------------------------------------

    -- The Blinding Vale (BV) — uiMapId 2500
    -- Bosses: (TODO)
    [2500] = {
        -- TODO: coordonnées du buff Flourishing Stride (outlook avant premier boss)
        -- [COORD] = {
        --     ["icon"]  = 18,
        --     ["title"] = L["BV_buff"],
        --     ["desc"]  = L["BV_buff_desc"],
        -- },
    },

    -- Den of Nalorakk (DN) — uiMapId 2513 (main), 2514
    -- Bosses: (TODO)
    [2513] = {
    },

    -- Den of Nalorakk (DN) — sub-zone / uiMapId 2514
    [2514] = {
        [25975843] = {
            ["icon"]  = 1,
            ["title"] = L["DN_buff_alchemy"],
            ["desc"]  = L["DN_buff_alchemy_desc"],
        },
        [70453386] = {
            ["icon"]  = 3,
            ["title"] = L["DN_buff_rune"],
            ["desc"]  = L["DN_buff_rune_desc"],
        },
        [39847744] = {
            ["icon"]  = 1,
            ["title"] = L["DN_buff_alchemy"],
            ["desc"]  = L["DN_buff_alchemy_desc"],
        },
    },

    -- Magisters' Terrace (MT) — uiMapId 2520 (main), sous-zones 2511–2519
    -- Wowhead zone 15829 — Bosses: Seranel Sunlash, Gemellus, Degentrius
    [2520] = {
    },

    -- Magisters' Terrace (MT) — library sub-zone / uiMapId 2515
    [2515] = {
        [49886417] = {
            ["icon"]  = 1,
            ["title"] = L["MT_buff"],
            ["desc"]  = L["MT_buff_desc"],
        },
    },

    -- Maisara Caverns (MC) — uiMapId 2501
    -- Wowhead zone 16395 — Bosses: Muro'jin & Nekraxx, Vordaza, Rak'tul (Vessel of Souls)
    [2501] = {
        -- TODO: add coordinates
    },

    -- Nexus-Point Xenas (NPX) — uiMapId 2556
    -- Wowhead zone 16573 — Bosses: Chief Corewright Kasreth, Corewarden Nysarra, Lothraxion
    [2556] = {
        -- TODO: coordonnées fils de détection arcaniques (Engineering/Rogue)
        -- [COORD] = {
        --     ["icon"]  = 18,
        --     ["title"] = L["NPX_tripwire"],
        --     ["desc"]  = L["NPX_tripwire_desc"],
        -- },
        -- TODO: coordonnées conduits Corespark Surge
        -- [COORD] = {
        --     ["icon"]  = 18,
        --     ["title"] = L["NPX_conduit"],
        --     ["desc"]  = L["NPX_conduit_desc"],
        -- },
    },

    -- Windrunner Spire (WRS) — uiMapId 2492+ (map découpée en plusieurs zones)
    -- Wowhead zone 15808 — Bosses: Emberdawn, Derelict Duo, Commander Kroluk, The Restless Heart
    -- Sous-zone "Derelict Legion Vessel" : 2557/2558
    [2492] = {
        [52875502] = {
            ["icon"]  = 1,
            ["title"] = L["WRS_speed_potion"],
            ["desc"]  = L["WRS_speed_potion_desc"],
        },
    },
    [2496] = {
        [43075997] = {
            ["icon"]  = 1,
            ["title"] = L["WRS_speed_potion"],
            ["desc"]  = L["WRS_speed_potion_desc"],
        },
    },
}
