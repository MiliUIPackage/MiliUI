MFH_DB_BOSSES = {
    [10184] = { name = "Onyxia" },
    [16152] = { name = "Attumen the Huntsman" },
    [19622] = { name = "Kael'thas Sunstrider" },
    [23035] = { name = "Anzu" },
    [23577] = { name = "Halazzi" },
    [24664] = { name = "Kael'thas Sunstrider" },
    [26693] = { name = "Skadi the Ruthless" },
    [28859] = { name = "Malygos" },
    [28860] = { name = "Sartharion" },
    [31125] = { name = "Archavon the Stone Watcher" },
    [32273] = { name = "Infinite Corruptor" },
    [33288] = { name = "Yogg-Saron" },
    [33993] = { name = "Emalon the Storm Watcher" },
    [35013] = { name = "Koralon the Flame Watcher" },
    [36597] = { name = "The Lich King" },
    [38433] = { name = "Toravon the Ice Watcher" },
    [43214] = { name = "Slabhide" },
    [43873] = { name = "Altairus" },
    [45412] = { name = "Lord Aurius Rivendare" },
    [46753] = { name = "Al'Akir" },
    [52059] = { name = "High Priestess Kilnara" },
    [52151] = { name = "Bloodlord Mandokir" },
    [52409] = { name = "Ragnaros" },
    [52530] = { name = "Alysrazor" },
    [55294] = { name = "Ultraxion" },
    [56173] = { name = "Deathwing"                  , raid = "Madness of Deathwing" },
    [60410] = { name = "Elegon" },
    [60491] = { name = "Sha of Anger" },
    [62346] = { name = "Galleon" },
    [68476] = { name = "Horridon" },
    [69099] = { name = "Nalak" },
    [69161] = { name = "Oondasta" },
    [69712] = { name = "Ji-Kun" },
    [71865] = { name = "Garrosh Hellscream" },
    [87493] = { name = "Rukhmar" },
    [95044] = { name = "Terrorfist" },
    [95053] = { name = "Deathtalon" },
    [95054] = { name = "Vengeance" },
    [95056] = { name = "Doomroller" },
}

MFH_DB_ZONES = {
    [723] = { raid = "Auchindoun: Sethekk Halls" },
    [798] = { raid = "Magister's Terrace" },
}

MFH_DB_MOUNTS = {
    [13335] = { -- Deathcharger's Reins
        spell_id = 17481,
        from = {
            {
                type = 'dungeon', npc_id = 45412,
                zone_id = 765,
                level = 37, for_sort = 59,
            },
        },
    },
    [30480] = { -- Fiery Warhorse's Reins
        spell_id = 36702,
        from = {
            {
                type = 'raid', npc_id = 16152,
                zone_id = 799,
                level = 70, for_sort = 115,
            },
        },
    },
    [32458] = { -- Ashes of Al'ar
        spell_id = 40192,
        from = {
            {
                type = 'raid', npc_id = 19622,
                zone_id = 782,
                level = 70, for_sort = 141,
            },
        },
    },
    [32768] = { -- Reins of the Raven Lord
        spell_id = 41252,
        from = {
            {
                type = 'dungeon', subtype = 'heroic', npc_id = 23035,
                zone_id = 723,
                level = 70, for_sort = 115,
            },
        },
    },
    [35513] = { -- Swift White Hawkstrider
        spell_id = 46628,
        from = {
            {
                type = 'dungeon', subtype = 'heroic', npc_id = 24664,
                zone_id = 798,
                level = 70, for_sort = 125,
            },
        },
    },
    [43952] = { -- Reins of the Azure Drake
        spell_id = 59567,
        from = {
            {
                type = 'raid', npc_id = 28859,
                zone_id = 527,
                level = 80, for_sort = 213,
            },
        },
    },
    [43951] = { -- Reins of the Bronze Drake
        spell_id = 59569,
        from = {
            {
                type = 'dungeon', subtype = 'heroic', npc_id = 32273,
                zone_id = 521,
                level = 80, for_sort = 200,
                cond = '25_mins',
            },
        },
    },
    [43954] = { -- Reins of the Twilight Drake
        spell_id = 59571,
        from = {
            {
                type = 'raid', subtype = 'normal_25', npc_id = 28860,
                zone_id = 531,
                level = 80, for_sort = 226,
                cond = '3_drakes_up',
            },
        },
    },
    [43986] = { -- Reins of the Black Drake
        spell_id = 59650,
        from = {
            {
                type = 'raid', subtype = 'normal_10', npc_id = 28860,
                zone_id = 531,
                level = 80, for_sort = 213,
                cond = '3_drakes_up',
            },
        },
    },
    [43953] = { -- Reins of the Blue Drake
        spell_id = 59568,
        from = {
            {
                type = 'raid', npc_id = 28859,
                zone_id = 527,
                level = 80, for_sort = 213,
            },
        },
    },
    [43959] = { -- Reins of the Grand Black War Mammoth (alliance)
        spell_id = 61465, faction = 'alliance',
        from = {
            {
                type = 'raid', npc_id = 31125,
                zone_id = 532,
                level = 80, for_sort = 200,
            },
            {
                type = 'raid', npc_id = 33993,
                zone_id = 532,
                level = 80, for_sort = 219,
            },
            {
                type = 'raid', npc_id = 35013,
                zone_id = 532,
                level = 80, for_sort = 232,
            },
            {
                type = 'raid', npc_id = 38433,
                zone_id = 532,
                level = 80, for_sort = 251,
            },
        },
    },
    [44083] = { -- Reins of the Grand Black War Mammoth (horde)
        spell_id = 61467, faction = 'horde',
        from = {
            {
                type = 'raid', npc_id = 31125,
                zone_id = 532,
                level = 80, for_sort = 200,
            },
            {
                type = 'raid', npc_id = 33993,
                zone_id = 532,
                level = 80, for_sort = 219,
            },
            {
                type = 'raid', npc_id = 35013,
                zone_id = 532,
                level = 80, for_sort = 232,
            },
            {
                type = 'raid', npc_id = 38433,
                zone_id = 532,
                level = 80, for_sort = 251,
            },
        },
    },
    [44151] = { -- Reins of the Blue Proto-Drake
        spell_id = 59996,
        from = {
            {
                type = 'dungeon', subtype = 'heroic', npc_id = 26693,
                zone_id = 524,
                level = 80, for_sort = 200,
            },
        },
    },
    [45693] = { -- Mimiron's Head
        spell_id = 63796,
        from = {
            {
                type = 'raid', subtype = 'normal_25', npc_id = 33288,
                zone_id = 529,
                level = 80, for_sort = 239,
                cond = '0_keepers',
            },
        },
    },
    [49636] = { -- Reins of the Onyxian Drake
        spell_id = 69395,
        from = {
            {
                type = 'raid', npc_id = 10184,
                zone_id = 718,
                level = 80, for_sort = 232,
            },
        },
    },
    [50818] = { -- Invincible's Reins
        spell_id = 72286,
        from = {
            {
                type = 'raid', subtype = 'heroic_25', npc_id = 36597,
                zone_id = 604,
                level = 80, for_sort = 284,
            },
        },
    },
    [63040] = { -- Reins of the Drake of the North Wind
        spell_id = 88742,
        from = {
            {
                type = 'dungeon', npc_id = 43873,
                zone_id = 769,
                level = 82, for_sort = 316,
            },
        },
    },
    [63041] = { -- Reins of the Drake of the South Wind
        spell_id = 88744,
        from = {
            {
                type = 'raid', npc_id = 46753,
                zone_id = 773,
                level = 85, for_sort = 359,
            },
        },
    },
    [63043] = { -- Reins of the Vitreous Stone Drake
        spell_id = 88746,
        from = {
            {
                type = 'dungeon', npc_id = 43214,
                zone_id = 768,
                level = 82, for_sort = 316,
            },
        },
    },
    [68823] = { -- Armored Razzashi Raptor
        spell_id = 96491,
        from = {
            {
                type = 'dungeon', subtype = 'heroic', npc_id = 52151,
                zone_id = 793,
                level = 85, for_sort = 353,
            },
        },
    },
    [68824] = { -- Swift Zulian Panther
        spell_id = 96499,
        from = {
            {
                type = 'dungeon', subtype = 'heroic', npc_id = 52059,
                zone_id = 793,
                level = 85, for_sort = 353,
            },
        },
    },
    [69224] = { -- Smoldering Egg of Millagazor
        spell_id = 97493,
        from = {
            {
                type = 'raid', npc_id = 52409,
                zone_id = 800,
                level = 85, for_sort = 384,
            },
        },
    },
    [69747] = { -- Amani Battle Bear
        spell_id = 98204,
        from = {
            {
                type = 'dungeon', subtype = 'heroic', npc_id = 23577,
                zone_id = 781,
                level = 85, for_sort = 353,
                cond = '25_mins',
            },
        },
    },
    [71665] = { -- Flametalon of Alysrazor
        spell_id = 101542,
        from = {
            {
                type = 'raid', npc_id = 52530,
                zone_id = 800,
                level = 85, for_sort = 378,
            },
        },
    },
    [77067] = { -- Reins of the Blazing Drake
        spell_id = 107842,
        from = {
            {
                type = 'raid', npc_id = 56173,
                zone_id = 824,
                level = 85, for_sort = 403,
            },
        },
    },
    [77069] = { -- Life-Binder's Handmaiden
        spell_id = 107845,
        from = {
            {
                type = 'raid', subtype = 'heroic', npc_id = 56173,
                zone_id = 824,
                level = 85, for_sort = 416,
            },
        },
    },
    [78919] = { -- Experiment 12-B
        spell_id = 110039,
        from = {
            {
                type = 'raid', npc_id = 55294,
                zone_id = 824,
                level = 85, for_sort = 397,
            },
        },
    },
    [87771] = { -- Reins of the Heavenly Onyx Cloud Serpent
        spell_id = 127158,
        from = {
            {
                type = 'world', quest_id = 32099, npc_id = 60491,
                zone_id = 809,
                level = 90, for_sort = 496,
            },
        },
    },
    [87777] = { -- Reins of the Astral Cloud Serpent
        spell_id = 127170,
        from = {
            {
                type = 'raid', npc_id = 60410,
                zone_id = 896,
                level = 90, for_sort = 489,
            },
        },
    },
    [89783] = { -- Son of Galleon's Saddle
        spell_id = 130965,
        from = {
            {
                type = 'world', quest_id = 32098, npc_id = 62346,
                zone_id = 807,
                level = 90, for_sort = 496,
            },
        },
    },
    [93666] = { -- Spawn of Horridon
        spell_id = 136471,
        from = {
            {
                type = 'raid', npc_id = 68476,
                zone_id = 930,
                level = 90, for_sort = 522,
            },
        },
    },
    [94228] = { -- Reins of the Cobalt Primordial Direhorn
        spell_id = 138423,
        from = {
            {
                type = 'world', quest_id = 32519, npc_id = 69161,
                zone_id = 929,
                level = 90, for_sort = 522,
            },
        },
    },
    [95057] = { -- Reins of the Thundering Cobalt Cloud Serpent
        spell_id = 139442,
        from = {
            {
                type = 'world', quest_id = 32518, npc_id = 69099,
                zone_id = 928,
                level = 90, for_sort = 522,
            },
        },
    },
    [95059] = { -- Clutch of Ji-Kun
        spell_id = 139448,
        from = {
            {
                type = 'raid', npc_id = 69712,
                zone_id = 930,
                level = 90, for_sort = 522,
            },
        },
    },
    [104253] = { -- Kor'kron Juggernaut
        spell_id = 148417,
        from = {
            {
                type = 'raid', subtype = 'mythic', npc_id = 71865,
                zone_id = 953,
                level = 90, for_sort = 620,
            },
        },
    },
    [116663] = { -- Shadowhide Pearltusk
        spell_id = 171624,
        from = {
            {
                faction = 'alliance',
                type = 'special', subtype = 'garrison_invasion', quest_id = 37640,
                zone_id = 947,
                level = 100, for_sort = 645,
                cond = 'gold_victory',
            },
            {
                faction = 'horde',
                type = 'special', subtype = 'garrison_invasion', quest_id = 37640,
                zone_id = 941,
                level = 100, for_sort = 645,
                cond = 'gold_victory',
            },
        },
    },
    [116673] = { -- Giant Coldsnout
        spell_id = 171635,
        from = {
            {
                faction = 'alliance',
                type = 'special', subtype = 'garrison_invasion', quest_id = 37640,
                zone_id = 947,
                level = 100, for_sort = 645,
                cond = 'gold_victory',
            },
            {
                faction = 'horde',
                type = 'special', subtype = 'garrison_invasion', quest_id = 37640,
                zone_id = 941,
                level = 100, for_sort = 645,
                cond = 'gold_victory',
            },
        },
    },
    [116779] = { -- Garn Steelmaw
        spell_id = 171836,
        from = {
            {
                faction = 'alliance',
                type = 'special', subtype = 'garrison_invasion', quest_id = 37640,
                zone_id = 947,
                level = 100, for_sort = 645,
                cond = 'gold_victory',
            },
            {
                faction = 'horde',
                type = 'special', subtype = 'garrison_invasion', quest_id = 37640,
                zone_id = 941,
                level = 100, for_sort = 645,
                cond = 'gold_victory',
            },
        },
    },
    [116786] = { -- Smoky Direwolf
        spell_id = 171843,
        from = {
            {
                faction = 'alliance',
                type = 'special', subtype = 'garrison_invasion', quest_id = 37640,
                zone_id = 947,
                level = 100, for_sort = 645,
                cond = 'gold_victory',
            },
            {
                faction = 'horde',
                type = 'special', subtype = 'garrison_invasion', quest_id = 37640,
                zone_id = 941,
                level = 100, for_sort = 645,
                cond = 'gold_victory',
            },
        },
    },
    [116771] = { -- Solar Spirehawk
        spell_id = 171828,
        from = {
            {
                type = 'world', quest_id = 37464, npc_id = 87493,
                zone_id = 948,
                level = 100, for_sort = 655,
            },
        },
    },
    [116658] = { -- Tundra Icehoof
        spell_id = 171619,
        from = {
            {
                type = 'world', quest_id = 39288, npc_id = 95044,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
            {
                type = 'world', quest_id = 39287, npc_id = 95053,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
            {
                type = 'world', quest_id = 39290, npc_id = 95054,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
            {
                type = 'world', quest_id = 39289, npc_id = 95056,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
        },
    },
    [116669] = { -- Armored Razorback
        spell_id = 171630,
        from = {
            {
                type = 'world', quest_id = 39288, npc_id = 95044,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
            {
                type = 'world', quest_id = 39287, npc_id = 95053,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
            {
                type = 'world', quest_id = 39290, npc_id = 95054,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
            {
                type = 'world', quest_id = 39289, npc_id = 95056,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
        },
    },
    [116780] = { -- Warsong Direfang
        spell_id = 171837,
        from = {
            {
                type = 'world', quest_id = 39288, npc_id = 95044,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
            {
                type = 'world', quest_id = 39287, npc_id = 95053,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
            {
                type = 'world', quest_id = 39290, npc_id = 95054,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
            {
                type = 'world', quest_id = 39289, npc_id = 95056,
                zone_id = 970,
                level = 100, for_sort = 675,
            },
        },
    },
}
