local myname, ns = ...

local L = LibStub("AceLocale-3.0"):GetLocale(myname, false)

--[[ structure:
    [mapFil00] = { -- "_terrain1" etc will be stripped from attempts to fetch this
        [coord] = {
            label=[string], -- label: text that'll be the label, optional
            item=[id], -- itemid
            quest=[id], -- will be checked, for whether character already has it
            achievement=[id], -- will be shown in the tooltip
            junk=[bool], -- doesn't count for achievement
            npc=[id], -- related npc id, used to display names in tooltip
            note=[string], -- some text which might be helpful
        },
    },
--]]
ns.points = {
    -- Halls of valor
    [704] = {
        [47516614] = {
            ["cont"] = false,
            ["icon"] = 12,
            ["title"] = L["HOV_percentage"],
            ["desc"] = "",
        },
    },
    [705] = {
        [51227199] = {
            ["cont"] = false,
            ["icon"] = 12,
            ["title"] = L["HOV_percentage"],
            ["desc"] = "",
        },
        [54698831] = {
            ["icon"] = 2,
            ["title"] = L["HOV_haldor"],
            ["cont"] = false,
            ["desc"] = L["HOV_haldor_desc"],
        },
        [48478382] = {
            ["icon"] = 4,
            ["title"] = L["HOV_tor"],
            ["cont"] = false,
            ["desc"] = L["HOV_tor_desc"],
        },
        [48598885] = {
            ["icon"] = 3,
            ["title"] = L["HOV_bjorn"],
            ["cont"] = false,
            ["desc"] = L["HOV_bjorn_desc"],
        },
        [54938347] = {
            ["icon"] = 1,
            ["title"] = L["HOV_ranulf"],
            ["cont"] = false,
            ["desc"] = L["HOV_ranulf_desc"],
        },
    },
    -- Agelthar academy
    [2097] = {
        [42856894] = {
            ["icon"] = 2,
            ["title"] = L["AA_bronze_drake"],
            ["cont"] = false,
            ["desc"] = L["AA_bronze_drake_desc"],
        },
        [49675936] = {
            ["icon"] = 7,
            ["title"] = L["AA_red_drake"],
            ["cont"] = false,
            ["desc"] = L["AA_red_drake_desc"],
        },
        [46565603] = {
            ["icon"] = 4,
            ["title"] = L["AA_green_drake"],
            ["cont"] = false,
            ["desc"] = L["AA_green_drake_desc"],
        },
        [41896051] = {
            ["icon"] = 6,
            ["title"] = L["AA_blue_drake"],
            ["cont"] = false,
            ["desc"] = L["AA_blue_drake_desc"],
        },
        [46567181] = {
            ["icon"] = 5,
            ["title"] = L["AA_black_drake"],
            ["cont"] = false,
            ["desc"] = L["AA_black_drake_desc"],
        },
    },
    -- Ruby Sanctum (upper)
    [2094] = {
        [39755387] = {
            ["cont"] = false,
            ["icon"] = 8,
            ["title"] = L["RS_thunderdragon"],
            ["desc"] = L["RS_thunderdragon_desc"],
        },
        [67006470] = {
            ["icon"] = 8,
            ["title"] = L["RS_firedragon"],
            ["cont"] = false,
            ["desc"] = L["RS_firedragon_desc"],
        },
    },
    -- Nokhud invasion
    [2093] = {
        [33764275] = {
            ["cont"] = false,
            ["icon"] = 12,
            ["title"] = L["NO_percentage"],
            ["desc"] = "",
        },
    },
    -- Court of stars
    [761] = {
        [53976105] = {
            ["cont"] = false,
            ["icon"] = 8,
            ["title"] = L["COS_percentage"],
            ["desc"] = "",
        },
    },
    -- Brackenhide Hollow (BH entrance)
    [2096] = {
        [9733430] = {
            ["cont"] = false,
            ["icon"] = 12,
            ["title"] = L["BH_skip"],
            ["desc"] = L["BH_skip_desc"],
        },
        [28503637] = {
            ["cont"] = false,
            ["icon"] = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"] = L["BH_cauldron_desc"],
        },
        [17863978] = {
            ["cont"] = false,
            ["icon"] = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"] = L["BH_cauldron_desc"],
        },
        [21623021] = {
            ["cont"] = false,
            ["icon"] = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"] = L["BH_cauldron_desc"],
        },
        [11413935] = {
            ["cont"] = false,
            ["icon"] = 19,
            ["title"] = L["BH_gen_cauldron"],
            ["desc"] = L["BH_gen_cauldron_desc"],
        },
        [47636607] = {
            ["cont"] = false,
            ["icon"] = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"] = L["BH_cauldron_desc"],
        },
        [40944319] = {
            ["cont"] = false,
            ["icon"] = 1,
            ["title"] = L["BH_cauldron"],
            ["desc"] = L["BH_cauldron_desc"],
        },
    },
    -- Freehold (FH)
    [936] = {
        [39744706] = {
            ["icon"] = 12,
            ["title"] = L["FH_percentage"],
            ["cont"] = false,
            ["desc"] = "",
        },
    },
    -- Halls of Infusion (HOI)
    [2082] = {
        [39504892] = {
            ["cont"] = false,
            ["icon"] = 12,
            ["title"] = L["HOI_door"],
            ["desc"] = "",
        },
        [50387403] = {
            ["cont"] = false,
            ["icon"] = 4,
            ["title"] = L["HOI_shortcut_frog"],
            ["desc"] = "",
        },
        [28387360] = {
            ["cont"] = false,
            ["icon"] = 6,
            ["title"] = L["HOI_shortcut_icelady"],
            ["desc"] = "",
        },
    },
    [2083] = {
        [45369179] = {
            ["title"] = L["HOI_mushroom"],
            ["cont"] = false,
            ["icon"] = 4,
            ["desc"] = L["HOI_mushroom_desc"],
        },
    },
    -- Neltharion's Lair (NL)
    [731] = {
    },
    -- Neltharus (NELT)
    [2080] = {
        [52065674] = {
            ["title"] = L["NELT_percentage"],
            ["cont"] = false,
            ["icon"] = 12,
            ["desc"] = L["NELT_percentage_desc"],
        },
    },
    -- Uldaman: Legacy of Tyr (ULD)
    [2071] = {
        [25751879] = {
            ["title"] = L["ULD_percentage"],
            ["cont"] = false,
            ["icon"] = 12,
            ["desc"] = "",
        },
        [57686786] = {
            ["title"] = L["ULD_mining"],
            ["cont"] = false,
            ["icon"] = 18,
            ["desc"] = "",
        },
        [80874419] = {
            ["title"] = L["ULD_mining"],
            ["cont"] = false,
            ["icon"] = 18,
            ["desc"] = "",
        },
        [73708867] = {
            ["title"] = L["ULD_mining"],
            ["cont"] = false,
            ["icon"] = 18,
            ["desc"] = "",
        },
    },
    -- The Underrot (UNDR)
    [1041] = {
        [55525341] = {
            ["title"] = L["UNDR_skip"],
            ["cont"] = false,
            ["icon"] = 12,
            ["desc"] = "",
        },
    },
    -- The Vortex Pinnacle (VP)
    [325] = {
        [31018095] = {
            ["icon"] = 4,
            ["title"] = L["VP_slipstream"],
            ["cont"] = false,
            ["desc"] = L["VP_slipstream_desc2"],
        },
        [52532141] = {
            ["icon"] = 4,
            ["title"] = L["VP_slipstream"],
            ["cont"] = false,
            ["desc"] = L["VP_slipstream_desc2"],
        },
        [63535843] = {
            ["icon"] = 3,
            ["title"] = L["VP_slipstream"],
            ["cont"] = false,
            ["desc"] = L["VP_slipstream_desc1"],
        },
        [56601539] = {
            ["icon"] = 3,
            ["title"] = L["VP_slipstream"],
            ["cont"] = false,
            ["desc"] = L["VP_slipstream_desc1"],
        },

    },

}
