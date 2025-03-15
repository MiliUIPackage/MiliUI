local addonName, MyAddon = ...

MyAddon.Mobs = {

-- Siege of Boralus (1822) TWW Season 1
--	[128650] = {name = "[BOSS] Chopper Redhook", instanceID = 1822},	-- elite Humanoid ENERGY 52 hostile attackable
--	[128651] = {name = "[BOSS] Hadal Darkfathom", instanceID = 1822},	-- elite Giant POWER_TYPE_ENERGY 52 hostile attackable
--	[128652] = {name = "[BOSS] Viq'Goth", instanceID = 1822},	-- elite Aberration ENERGY 52 hostile attackable
--	[128967] = {name = "Ashvane Sniper", instanceID = 1822},	-- elite Humanoid RAGE 50 hostile attackable
	[128969] = {name = "Ashvane Commander", instanceID = 1822},	-- elite Humanoid MANA 51 hostile attackable
--	[129208] = {name = "[BOSS] Dread Captain Lockwood", instanceID = 1822},	-- elite Humanoid ENERGY 52 hostile attackable
--	[129366] = {name = "Bilge Rat Buccaneer", instanceID = 1822},	-- elite Humanoid RAGE 50 hostile attackable
	[129367] = {name = "Bilge Rat Tempest", instanceID = 1822},	-- elite Humanoid MANA 50 hostile attackable
--	[129369] = {name = "Irontide Raider", instanceID = 1822},	-- elite Humanoid RAGE 51 hostile attackable
	[129370] = {name = "Irontide Waveshaper", instanceID = 1822},	-- elite Humanoid MANA 50 hostile attackable
--	[129371] = {name = "Riptide Shredder", instanceID = 1822},	-- elite Humanoid RAGE 50 hostile attackable
	[129372] = {name = "Blacktar Bomber", instanceID = 1822},	-- elite Humanoid MANA 50 hostile attackable
	[129374] = {name = "Scrimshaw Enforcer", instanceID = 1822, marks = "8"},	-- elite Humanoid RAGE 50 hostile attackable
--	[129640] = {name = "Snarling Dockhound", instanceID = 1822},	-- elite Beast RAGE 50 hostile attackable
--	[129879] = {name = "Irontide Cleaver", instanceID = 1822},	-- elite Humanoid RAGE 51 hostile attackable
	[129928] = {name = "Irontide Powdershot", instanceID = 1822, auto = "nameplate", marks = "87"},	-- normal Humanoid RAGE 50 hostile attackable
	[129989] = {name = "Irontide Powdershot", instanceID = 1822, auto = "nameplate", marks = "87"},	-- normal Humanoid RAGE 50 hostile attackable
--	[129996] = {name = "Irontide Cleaver", instanceID = 1822},	-- elite Humanoid RAGE 51 hostile attackable
--	[133990] = {name = "Scrimshaw Gutter", instanceID = 1822},	-- normal Humanoid RAGE 50 hostile attackable
	[135241] = {name = "Bilge Rat Pillager", instanceID = 1822},	-- elite Humanoid MANA 50 hostile attackable
--	[135245] = {name = "Bilge Rat Demolisher", instanceID = 1822},	-- elite Humanoid RAGE 51 hostile attackable
--	[135258] = {name = "Irontide Curseblade", instanceID = 1822},	-- normal Humanoid MANA 50 hostile attackable
	[135263] = {name = "Ashvane Spotter", instanceID = 1822, marks = "+8"},	-- elite Humanoid RAGE 50 hostile attackable
--	[136483] = {name = "Ashvane Deckhand", instanceID = 1822},	-- elite Humanoid RAGE 50 hostile attackable
	[136549] = {name = "Ashvane Cannoneer", instanceID = 1822, marks = "8"},	-- elite Humanoid RAGE 51 hostile attackable
--	[137405] = {name = "[BOSS ADD] Gripping Terror", instanceID = 1822},	-- elite Aberration RAGE 52 hostile attackable
--	[137511] = {name = "Bilge Rat Cutthroat", instanceID = 1822},	-- elite Humanoid RAGE 50 hostile attackable
--	[137516] = {name = "Ashvane Invader", instanceID = 1822},	-- elite Humanoid ENERGY 50 hostile attackable
--	[137517] = {name = "Ashvane Destroyer", instanceID = 1822},	-- elite Humanoid RAGE 50 hostile attackable
--	[137521] = {name = "Irontide Powdershot", instanceID = 1822},	-- normal Humanoid RAGE 50 hostile attackable
--	[137614] = {name = "Demolishing Terror", instanceID = 1822},	-- elite Aberration RAGE 51 hostile attackable
--	[137625] = {name = "Demolishing Terror", instanceID = 1822},	-- elite Aberration RAGE 51 hostile attackable
--	[137626] = {name = "Demolishing Terror", instanceID = 1822},	-- elite Aberration RAGE 51 hostile attackable
--	[138002] = {name = "Scrimshaw Gutter", instanceID = 1822},	-- normal Humanoid RAGE 50 hostile attackable
--	[138247] = {name = "Irontide Curseblade", instanceID = 1822},	-- normal Humanoid MANA 50 hostile attackable
--	[138254] = {name = "Irontide Powdershot", instanceID = 1822, auto = "nameplate", marks = "87"},	-- normal Humanoid RAGE 50 hostile attackable
--	[138255] = {name = "Ashvane Spotter", instanceID = 1822},	-- elite Humanoid RAGE 51 hostile attackable
--	[138464] = {name = "Ashvane Deckhand", instanceID = 1822},	-- elite Humanoid RAGE 50 hostile attackable
--	[138465] = {name = "Ashvane Cannoneer", instanceID = 1822},	-- elite Humanoid RAGE 51 hostile attackable
--	[141938] = {name = "Ashvane Sniper", instanceID = 1822},	-- elite Humanoid RAGE 50 hostile attackable
--	[141939] = {name = "Ashvane Spotter", instanceID = 1822},	-- elite Humanoid RAGE 51 hostile attackable
	[144071] = {name = "Irontide Waveshaper", instanceID = 1822},	-- elite Humanoid MANA 50 hostile attackable

-- The Necrotic Wake (2286) TWW Season 1
--	[162689] = {name = "[BOSS] Surgeon Stitchflesh", instanceID = 2286},	-- elite Humanoid RAGE 62 hostile attackable
--	[162691] = {name = "[BOSS] Blightbone", instanceID = 2286},	-- elite Undead RAGE 62 hostile attackable
--	[162693] = {name = "[BOSS] Nalthor the Rimebinder", instanceID = 2286},	-- elite Undead ENERGY 62 hostile attackable
--	[162729] = {name = "Patchwerk Soldier", instanceID = 2286},	-- elite Undead RAGE 60 hostile attackable
--	[163121] = {name = "Stitched Vanguard", instanceID = 2286},	-- elite Undead RAGE 60 hostile attackable
--	[163122] = {name = "Brittlebone Warrior", instanceID = 2286},	-- normal Undead RAGE 60 hostile attackable
--	[163126] = {name = "Brittlebone Mage", instanceID = 2286},	-- normal Undead MANA 60 hostile attackable
	[163128] = {name = "Zolramus Sorcerer", instanceID = 2286},	-- elite Humanoid MANA 60 hostile attackable
	[163157] = {name = "[BOSS] Amarth", instanceID = 2286},	-- elite Beast MANA 62 hostile attackable
	[163618] = {name = "Zolramus Necromancer", instanceID = 2286, marks = "87"},	-- elite Humanoid MANA 60 hostile attackable
	[163619] = {name = "Zolramus Bonecarver", instanceID = 2286},	-- elite Humanoid MANA 60 hostile attackable
--	[163620] = {name = "Rotspew", instanceID = 2286},	-- elite Undead RAGE 61 hostile attackable
--	[163621] = {name = "Goregrind", instanceID = 2286},	-- elite Undead RAGE 61 hostile attackable
--	[163622] = {name = "Goregrind Bits", instanceID = 2286},	-- elite Undead RAGE 60 hostile attackable
--	[163623] = {name = "Rotspew Leftovers", instanceID = 2286},	-- elite Undead RAGE 60 hostile attackable
--	[164414] = {name = "[BOSS ADD] Reanimated Mage", instanceID = 2286},	-- normal Undead MANA 60 hostile attackable
--	[164427] = {name = "[BOSS ADD] Reanimated Warrior", instanceID = 2286},	-- normal Undead RAGE 60 hostile attackable
--	[164578] = {name = "Stitchflesh's Creation", instanceID = 2286},	-- elite Undead RAGE 61 hostile attackable
--	[164702] = {name = "[BOSS ADD] Carrion Worm", instanceID = 2286},	-- normal Beast RAGE 60 hostile attackable
	[165137] = {name = "Zolramus Gatekeeper", instanceID = 2286},	-- elite Humanoid MANA 61 hostile attackable
--	[165138] = {name = "Blight Bag", instanceID = 2286},	-- normal Undead RAGE 60 hostile attackable
--	[165197] = {name = "Skeletal Monstrosity", instanceID = 2286},	-- elite Undead RAGE 61 hostile attackable
	[165222] = {name = "Zolramus Bonemender", instanceID = 2286},	-- elite Humanoid MANA 60 hostile attackable
	[165824] = {name = "Nar'zudah", instanceID = 2286},	-- elite Humanoid MANA 61 hostile attackable
	[165872] = {name = "Flesh Crafter", instanceID = 2286},	-- elite Humanoid MANA 60 hostile attackable
--	[165911] = {name = "Loyal Creation", instanceID = 2286},	-- elite Undead RAGE 60 hostile attackable
	[165919] = {name = "Skeletal Marauder", instanceID = 2286, marks = "+1"},	-- elite Undead RAGE 61 hostile attackable
--	[166079] = {name = "Brittlebone Crossbowman", instanceID = 2286},	-- normal Undead ENERGY 60 hostile attackable
--	[166264] = {name = "Spare Parts", instanceID = 2286},	-- normal Undead RAGE 60 hostile attackable
--	[166266] = {name = "Spare Parts", instanceID = 2286},	-- normal Undead RAGE 60 hostile attackable
	[166302] = {name = "Corpse Harvester", instanceID = 2286},	-- elite Humanoid MANA 60 hostile attackable
--	[167731] = {name = "Separation Assistant", instanceID = 2286},	-- elite Humanoid ENERGY 61 hostile attackable
--	[168246] = {name = "[BOSS ADD] Reanimated Crossbowman", instanceID = 2286},	-- normal Undead ENERGY 60 hostile attackable
--	[171500] = {name = "Shuffling Corpse", instanceID = 2286},	-- normal Undead RAGE 60 hostile attackable
--	[172981] = {name = "Kyrian Stitchwerk", instanceID = 2286},	-- elite Undead RAGE 61 hostile attackable
	[173016] = {name = "Corpse Collector", instanceID = 2286},	-- elite Humanoid MANA 60 hostile attackable
	[173044] = {name = "Stitching Assistant", instanceID = 2286},	-- elite Humanoid MANA 61 hostile attackable
	[174783] = {name = "Opeth", instanceID = 2286},	-- elite Humanoid MANA 61 hostile attackable

-- Mists of Tirna Scithe (2290) TWW Season 1
--	[163058] = {name = "Mistveil Defender", instanceID = 2290},	-- elite Humanoid RAGE 60 hostile attackable
--	[164501] = {name = "[BOSS] Mistcaller", instanceID = 2290},	-- elite Humanoid RAGE 62 hostile attackable
--	[164517] = {name = "[BOSS] Tred'ova", instanceID = 2290},	-- elite Beast RAGE 62 hostile attackable
	[164567] = {name = "[BOSS] Ingra Maloch", instanceID = 2290},	-- elite Humanoid MANA 62 hostile attackable
	[164804] = {name = "[BOSS ADD] Droman Oulfarran", instanceID = 2290},	-- elite Elemental MANA 62 hostile attackable
--	[164920] = {name = "Drust Soulcleaver", instanceID = 2290},	-- elite Humanoid RAGE 60 hostile attackable
	[164921] = {name = "Drust Harvester", instanceID = 2290},	-- elite Humanoid MANA 60 hostile attackable
	[164926] = {name = "Drust Boughbreaker", instanceID = 2290, marks = "87"},	-- elite Aberration RAGE 61 hostile attackable
--	[164929] = {name = "Tirnenn Villager", instanceID = 2290},	-- elite Elemental MANA 61 hostile attackable
--	[165111] = {name = "Drust Spiteclaw", instanceID = 2290},	-- elite Aberration RAGE 60 hostile attackable
--	[165251] = {name = "Illusionary Vulpin", instanceID = 2290},	-- normal Beast RAGE 60 hostile attackable
--	[165560] = {name = "Gormling Larva", instanceID = 2290},	-- normal Beast RAGE 60 hostile attackable
	[166275] = {name = "Mistveil Shaper", instanceID = 2290},	-- elite Humanoid MANA 60 hostile attackable
--	[166276] = {name = "Mistveil Guardian", instanceID = 2290},	-- elite Humanoid RAGE 60 hostile attackable
	[166299] = {name = "Mistveil Tender", instanceID = 2290},	-- elite Humanoid MANA 60 hostile attackable
--	[166301] = {name = "Mistveil Stalker", instanceID = 2290},	-- elite Beast RAGE 60 hostile attackable
	[166304] = {name = "Mistveil Stinger", instanceID = 2290},	-- elite Beast MANA 60 hostile attackable
	[167111] = {name = "Spinemaw Staghorn", instanceID = 2290, marks = "+1"},	-- elite Beast MANA 61 hostile attackable
	[167113] = {name = "Spinemaw Acidgullet", instanceID = 2290},	-- elite Beast MANA 60 hostile attackable
	[167116] = {name = "Spinemaw Reaver", instanceID = 2290},	-- elite Beast MANA 60 hostile attackable
--	[167117] = {name = "Spinemaw Larva", instanceID = 2290},	-- normal Beast MANA 60 hostile attackable
--	[171772] = {name = "Mistveil Defender", instanceID = 2290},	-- elite Humanoid RAGE 60 hostile attackable
	[172312] = {name = "Spinemaw Gorger", instanceID = 2290},	-- elite Beast MANA 60 hostile attackable
--	[172991] = {name = "Drust Soulcleaver", instanceID = 2290},	-- elite Humanoid RAGE 60 hostile attackable
--	[173655] = {name = "Mistveil Matriarch", instanceID = 2290},	-- elite Dragonkin RAGE 61 hostile attackable
--	[173720] = {name = "Mistveil Gorgegullet", instanceID = 2290},	-- elite Beast RAGE 61 hostile attackable
	[166885] = {name = "Mistcaller", instanceID = 2290, auto = "*mouseover", marks = "8"},

-- The Rookery (2648) TWW
--	[207186] = {name = "Unruly Stormrook", instanceID = 2648},	-- elite Elemental ENERGY 81 hostile attackable
--	[207197] = {name = "Cursed Rookguard", instanceID = 2648},	-- elite Humanoid RAGE 80 hostile attackable
	[207198] = {name = "Cursed Thunderer", instanceID = 2648},	-- elite Humanoid MANA 80 hostile attackable
	[207199] = {name = "Cursed Rooktender", instanceID = 2648},	-- elite Humanoid MANA 80 hostile attackable
	[207202] = {name = "Void Fragment", instanceID = 2648},	-- elite Aberration MANA 80 hostile attackable
	[207205] = {name = "[BOSS] Stormguard Gorren", instanceID = 2648},	-- elite Humanoid MANA 82 hostile attackable
	[207207] = {name = "[BOSS] Voidstone Monstrosity", instanceID = 2648},	-- elite Aberration MANA 82 hostile attackable
--	[209230] = {name = "[BOSS] Kyrioss", instanceID = 2648},	-- elite Elemental POWER_TYPE_ENERGY 82 hostile attackable
	[209801] = {name = "Quartermaster Koratite", instanceID = 2648},	-- elite Humanoid MANA 81 hostile attackable
--	[212739] = {name = "Radiating Voidstone", instanceID = 2648},	-- elite Aberration RAGE 81 hostile attackable
--	[212786] = {name = "Voidrider", instanceID = 2648},	-- elite Elemental RAGE 81 hostile attackable
	[212793] = {name = "Void Ascendant", instanceID = 2648},	-- elite Humanoid MANA 80 hostile attackable
--	[214419] = {name = "Corrupted Rookguard", instanceID = 2648},	-- elite Aberration RAGE 81 hostile attackable
--	[214421] = {name = "Coalescing Void Diffuser", instanceID = 2648},	-- elite Aberration MANA 81 hostile attackable
	[214439] = {name = "Corrupted Oracle", instanceID = 2648},	-- elite Humanoid MANA 80 hostile attackable
--	[219066] = {name = "Inflicted Civilian", instanceID = 2648},	-- elite Humanoid RAGE 80 hostile attackable

-- Priory of the Sacred Flame (2649) TWW
--	[206694] = {name = "Fervent Sharpshooter", instanceID = 2649},	-- elite Humanoid RAGE 80 hostile attackable
--	[206696] = {name = "Arathi Knight", instanceID = 2649},	-- elite Humanoid POWER_TYPE_RED_POWER 81 hostile attackable
	[206697] = {name = "Devout Priest", instanceID = 2649},	-- elite Humanoid MANA 80 hostile attackable
	[206698] = {name = "Fanatical Conjuror", instanceID = 2649},	-- elite Humanoid MANA 80 hostile attackable
--	[206699] = {name = "War Lynx", instanceID = 2649},	-- elite Beast RAGE 80 hostile attackable
--	[206704] = {name = "Ardent Paladin", instanceID = 2649},	-- elite Humanoid MANA 81 hostile attackable
--	[206705] = {name = "Arathi Footman", instanceID = 2649},	-- elite Humanoid RAGE 80 hostile attackable
--	[206710] = {name = "Lightspawn", instanceID = 2649},	-- elite Elemental MANA 80 hostile attackable
--	[207939] = {name = "[BOSS] Baron Braunpyke", instanceID = 2649},	-- elite Humanoid POWER_TYPE_ENERGY 82 hostile attackable
--	[207940] = {name = "[BOSS] Prioress Murrpray", instanceID = 2649},	-- elite Humanoid POWER_TYPE_ENERGY 82 hostile attackable
--	[207943] = {name = "Arathi Neophyte", instanceID = 2649},	-- normal Humanoid MANA 80 hostile attackable
	[207946] = {name = "[BOSS] Captain Dailcry", instanceID = 2649, marks = "+2"},	-- elite Humanoid POWER_TYPE_ENERGY 82 hostile attackable
	[211289] = {name = "[BOSS-ADD] Taener Duelmal", instanceID = 2649, marks = "+1"},	-- elite Humanoid POWER_TYPE_ENERGY 81 hostile attackable
--	[211290] = {name = "[BOSS-ADD] Elaena Emberlanz", instanceID = 2649},	-- elite Humanoid POWER_TYPE_ENERGY 81 hostile attackable
--	[211291] = {name = "[BOSS-ADD] Sergeant Shaynemail", instanceID = 2649},	-- elite Humanoid POWER_TYPE_ENERGY 81 hostile attackable
--	[207949] = {name = "Zealous Templar", instanceID = 2649},	-- elite Humanoid MANA 81 hostile attackable
--	[211140] = {name = "Arathi Neophyte", instanceID = 2649},	-- normal Humanoid RAGE 80 hostile attackable
	[212826] = {name = "Guard Captain Suleyman", instanceID = 2649, marks = "8"},	-- elite Humanoid POWER_TYPE_ENERGY 81 hostile attackable
--	[212827] = {name = "High Priest Aemya", instanceID = 2649},	-- elite Humanoid POWER_TYPE_ENERGY 81 hostile attackable
	[212831] = {name = "Forge Master Damian", instanceID = 2649},	-- elite Humanoid MANA 81 hostile attackable
--	[212835] = {name = "Risen Footman", instanceID = 2649},	-- elite Undead ENERGY 80 hostile attackable
--	[212838] = {name = "Arathi Neophyte", instanceID = 2649},	-- normal Humanoid MANA 80 hostile attackable
	[217658] = {name = "Sir Braunpyke", instanceID = 2649, marks = "8"},	-- elite Undead ENERGY 81 hostile attackable
	[221760] = {name = "Risen Mage", instanceID = 2649},	-- elite Undead MANA 80 hostile attackable
--	[222927] = {name = "Sacred Flame Vintner", instanceID = 2649},	-- normal Humanoid RAGE 80 hostile attackable

-- Darkflame Cleft (2651) TWW
--	[208446] = {name = "Kobold Worker", instanceID = 2651},	-- elite Humanoid RAGE 80 hostile attackable
	[208450] = {name = "Wandering Candle", instanceID = 2651},	-- elite Elemental MANA 81 hostile attackable
--	[208456] = {name = "Shuffling Horror", instanceID = 2651},	-- elite Aberration RAGE 80 hostile attackable
--	[208457] = {name = "Skittering Darkness", instanceID = 2651},	-- normal Aberration RAGE 81 hostile attackable
	[208743] = {name = "[BOSS] Blazikon", instanceID = 2651},	-- elite Elemental MANA 82 hostile attackable
--	[208745] = {name = "[BOSS] The Candle King", instanceID = 2651},	-- elite Humanoid RAGE 82 hostile attackable
--	[208747] = {name = "[BOSS] The Darkness", instanceID = 2651},	-- normal Aberration POWER_TYPE_DARKNESS_ENERGY -1 hostile attackable
--	[210148] = {name = "Menial Laborer", instanceID = 2651},	-- minus Humanoid RAGE 80 hostile attackable
--	[210153] = {name = "[BOSS] Ol' Waxbeard", instanceID = 2651},	-- elite Beast RAGE 82 hostile attackable
--	[210539] = {name = "Corridor Creeper", instanceID = 2651},	-- elite Beast RAGE 81 hostile attackable
--	[210797] = {name = "The Darkness", instanceID = 2651},	-- normal Aberration POWER_TYPE_DARKNESS_ENERGY -1 hostile attackable
--	[210810] = {name = "Menial Laborer", instanceID = 2651},	-- normal Humanoid RAGE 80 hostile attackable
	[210812] = {name = "Royal Wicklighter", instanceID = 2651},	-- elite Humanoid MANA 80 hostile attackable
--	[210818] = {name = "Lowly Moleherd", instanceID = 2651},	-- elite Humanoid RAGE 80 hostile attackable
--	[211121] = {name = "Rank Overseer", instanceID = 2651},	-- elite Humanoid RAGE 81 hostile attackable
	[211228] = {name = "Blazing Fiend", instanceID = 2651},	-- elite Elemental MANA 80 hostile attackable
--	[211977] = {name = "Pack Mole", instanceID = 2651},	-- elite Beast RAGE 80 hostile attackable
	[212238] = {name = "Darkness Spawn", instanceID = 2651},	-- elite Aberration MANA 80 hostile attackable
--	[212383] = {name = "Kobold Taskworker", instanceID = 2651},	-- elite Humanoid RAGE 80 hostile attackable
--	[212411] = {name = "Torchsnarl", instanceID = 2651},	-- elite Humanoid RAGE 81 hostile attackable
	[212412] = {name = "Sootsnout", instanceID = 2651},	-- elite Humanoid RAGE 81 hostile attackable
--	[213008] = {name = "Wriggling Darkspawn", instanceID = 2651},	-- normal Aberration RAGE 80 hostile attackable
--	[213913] = {name = "Kobold Flametender", instanceID = 2651},	-- normal Humanoid MANA 80 hostile attackable
--	[220616] = {name = "Corridor Sleeper", instanceID = 2651},	-- elite Beast RAGE 81 hostile attackable
	[220815] = {name = "Blazing Fiend", instanceID = 2651},	-- elite Elemental MANA 80 hostile attackable
	[223770] = {name = "Blazing Fiend", instanceID = 2651},	-- elite Elemental MANA 80 hostile attackable
	[223772] = {name = "Blazing Fiend", instanceID = 2651},	-- elite Elemental MANA 80 hostile attackable
	[223773] = {name = "Blazing Fiend", instanceID = 2651},	-- elite Elemental MANA 80 hostile attackable
	[223774] = {name = "Blazing Fiend", instanceID = 2651},	-- elite Elemental MANA 80 hostile attackable
	[223775] = {name = "Blazing Fiend", instanceID = 2651},	-- elite Elemental MANA 80 hostile attackable
	[223776] = {name = "Blazing Fiend", instanceID = 2651},	-- elite Elemental MANA 80 hostile attackable
	[223777] = {name = "Blazing Fiend", instanceID = 2651},	-- elite Elemental MANA 80 hostile attackable
	[213751] = {name = "Dynamite Mine Cart", instanceID = 2651, auto = "nameplate", marks = "8"},

-- The Stonevault (2652) TWW Season 1
--	[210108] = {name = "[BOSS] E.D.N.A", instanceID = 2652},	-- elite Mechanical POWER_TYPE_ENERGY 82 hostile attackable
--	[210109] = {name = "Earth Infused Golem", instanceID = 2652},	-- elite Mechanical RAGE 81 hostile attackable
--	[210156] = {name = "[BOSS] Skarmorak", instanceID = 2652},	-- elite Elemental POWER_TYPE_ENERGY 82 hostile attackable
	[212389] = {name = "Cursedheart Invader", instanceID = 2652},	-- elite Humanoid MANA 80 hostile attackable
--	[212400] = {name = "Void Touched Elemental", instanceID = 2652},	-- elite Elemental RAGE 80 hostile attackable
	[212403] = {name = "Cursedheart Invader", instanceID = 2652},	-- elite Aberration RAGE 80 hostile attackable
--	[212405] = {name = "Aspiring Forgehand", instanceID = 2652},	-- normal Humanoid RAGE 80 hostile attackable
	[212453] = {name = "Ghastly Voidsoul", instanceID = 2652, marks = "+12"},	-- elite Humanoid MANA 80 hostile attackable
--	[212764] = {name = "Engine Speaker", instanceID = 2652},	-- elite Humanoid RAGE 80 hostile attackable
	[212765] = {name = "Void Bound Despoiler", instanceID = 2652, marks = "87"},	-- elite Humanoid MANA 81 hostile attackable
--	[213119] = {name = "[BOSS] High Speaker Eirich", instanceID = 2652},	-- elite Humanoid RAGE 82 hostile attackable
--	[213216] = {name = "[BOSS] Speaker Dorlita", instanceID = 2652},	-- elite Humanoid RAGE 82 hostile attackable
	[213217] = {name = "[BOSS] Speaker Brokk", instanceID = 2652},	-- elite Humanoid RAGE 82 hostile attackable
	[213338] = {name = "Forgebound Mender", instanceID = 2652},	-- elite Humanoid MANA 80 hostile attackable
--	[213343] = {name = "Forge Loader", instanceID = 2652},	-- elite Mechanical POWER_TYPE_MOLTEN_ENERGY 81 hostile attackable
--	[213954] = {name = "Rock Smasher", instanceID = 2652},	-- elite Elemental RAGE 81 hostile attackable
	[214066] = {name = "Cursedforge Stoneshaper", instanceID = 2652},	-- elite Humanoid MANA 80 hostile attackable
--	[214264] = {name = "Cursedforge Honor Guard", instanceID = 2652},	-- elite Humanoid RAGE 81 hostile attackable
	[214350] = {name = "Turned Speaker", instanceID = 2652},	-- elite Aberration MANA 80 hostile attackable
--	[214443] = {name = "[BOSS ADD] Crystal Shard", instanceID = 2652},	-- elite Not specified RAGE 80 hostile attackable
	[221979] = {name = "Void Bound Howler", instanceID = 2652},	-- elite Humanoid RAGE 80 hostile attackable
--	[222923] = {name = "Repurposed Loaderbot", instanceID = 2652},	-- elite Mechanical RAGE 80 hostile attackable
--	[224516] = {name = "Skardyn Invader", instanceID = 2652},	-- normal Mechanical RAGE 81 hostile attackable
	[224962] = {name = "Cursedforge Mender", instanceID = 2652},	-- elite Humanoid MANA 80 hostile attackable

-- Ara-Kara, City of Echoes (2660) TWW Season 1
--	[213179] = {name = "[BOSS] Avanoxx", instanceID = 2660},	-- elite Beast RAGE 82 hostile attackable
--	[214840] = {name = "Engorged Crawler", instanceID = 2660},	-- elite Beast RAGE 80 hostile attackable
--	[215405] = {name = "[BOSS] Anub'zekt", instanceID = 2660},	-- elite Humanoid POWER_TYPE_DARKNESS_ENERGY 82 hostile attackable
--	[215407] = {name = "[BOSS] Ki'katal the Harvester", instanceID = 2660},	-- elite Humanoid POWER_TYPE_ENTROPY 82 hostile attackable
--	[215826] = {name = "[BOSS ADD] Bloodworker", instanceID = 2660},	-- minus Humanoid RAGE 80 hostile attackable
	[216293] = {name = "Trilling Attendant", instanceID = 2660},	-- elite Humanoid MANA 80 hostile attackable
--	[216333] = {name = "Bloodstained Assistant", instanceID = 2660},	-- elite Humanoid MANA 80 hostile attackable
--	[216336] = {name = "Ravenous Crawler", instanceID = 2660},	-- normal Beast RAGE 80 hostile attackable
--	[216337] = {name = "Bloodworker", instanceID = 2660},	-- normal Humanoid RAGE 80 hostile attackable
--	[216338] = {name = "Hulking Bloodguard", instanceID = 2660},	-- elite Humanoid RAGE 81 hostile attackable
	[216340] = {name = "Sentry Stagshell", instanceID = 2660, marks = "8"},	-- normal Beast RAGE 80 hostile attackable
--	[216341] = {name = "Jabbing Flyer", instanceID = 2660},	-- normal Beast RAGE 80 hostile attackable
--	[216363] = {name = "Reinforced Drone", instanceID = 2660},	-- elite Humanoid RAGE 80 hostile attackable
	[216364] = {name = "Blood Overseer", instanceID = 2660},	-- elite Humanoid MANA 81 hostile attackable
--	[216365] = {name = "Winged Carrier", instanceID = 2660},	-- elite Beast RAGE 80 hostile attackable
--	[216856] = {name = "Black Blood", instanceID = 2660},	-- minus Aberration RAGE 80 hostile attackable
--	[217039] = {name = "Nerubian Hauler", instanceID = 2660},	-- elite Humanoid RAGE 81 hostile attackable
	[217531] = {name = "Ixin", instanceID = 2660},	-- elite Humanoid MANA 81 hostile attackable
	[217533] = {name = "Atik", instanceID = 2660},	-- elite Humanoid MANA 81 hostile attackable
	[218324] = {name = "Nakt", instanceID = 2660},	-- elite Humanoid MANA 81 hostile attackable
--	[218961] = {name = "[BOSS ADD] Starved Crawler", instanceID = 2660},	-- normal Beast RAGE 80 hostile attackable
--	[219221] = {name = "Ravenous Crawler", instanceID = 2660},	-- normal Beast RAGE 80 hostile attackable
	[223253] = {name = "Bloodstained Webmage", instanceID = 2660},	-- elite Humanoid MANA 80 hostile attackable
--	[228015] = {name = "Hulking Bloodguard", instanceID = 2660},	-- elite Humanoid RAGE 81 hostile attackable

-- Cinderbrew Meadery (2661) TWW
	[210264] = {name = "Bee Wrangler", instanceID = 2661},	-- elite Humanoid RAGE 80 hostile attackable
--	[210265] = {name = "Worker Bee", instanceID = 2661},	-- elite Beast RAGE 80 hostile attackable
--	[210267] = {name = "[BOSS] I'pa", instanceID = 2661},	-- elite Elemental POWER_TYPE_ENERGY 82 hostile attackable
--	[210269] = {name = "Hired Muscle", instanceID = 2661},	-- elite Humanoid RAGE 81 hostile attackable
--	[210270] = {name = "Brew Drop", instanceID = 2661},	-- normal Elemental RAGE 80 hostile attackable
--	[210271] = {name = "[BOSS] Brew Master Aldryr", instanceID = 2661},	-- elite Humanoid ENERGY 82 hostile attackable
--	[214661] = {name = "[BOSS] Goldie Baronbottom", instanceID = 2661},	-- elite Humanoid ENERGY 82 hostile attackable
--	[214668] = {name = "Venture Co. Patron", instanceID = 2661},	-- elite Humanoid RAGE 80 hostile attackable
	[214673] = {name = "Flavor Scientist", instanceID = 2661},	-- elite Humanoid MANA 80 hostile attackable
	[214697] = {name = "Chef Chewie", instanceID = 2661, auto = "nameplate", marks = "8"},	-- elite Humanoid RAGE 81 hostile attackable
--	[214920] = {name = "Tasting Room Attendant", instanceID = 2661},	-- elite Humanoid RAGE 80 hostile attackable
--	[218002] = {name = "[BOSS] Benk Buzzbee", instanceID = 2661},	-- elite Humanoid RAGE 82 hostile attackable
	[218671] = {name = "Venture Co. Pyromaniac", instanceID = 2661},	-- elite Humanoid RAGE 80 hostile attackable
--	[218865] = {name = "Bee-let", instanceID = 2661},	-- minus Beast RAGE 80 hostile attackable
	[219588] = {name = "Yes Man", instanceID = 2661, auto = "nameplate", marks = "8726"},	-- elite Humanoid RAGE 80 hostile attackable
	[220060] = {name = "Taste Tester", instanceID = 2661},	-- elite Humanoid RAGE 80 hostile attackable
	[220141] = {name = "Royal Jelly Purveyor", instanceID = 2661},	-- elite Humanoid MANA 80 hostile attackable
	[220368] = {name = "Failed Batch", instanceID = 2661, auto = "nameplate", marks = "87"},	-- normal Not specified RAGE 80 hostile attackable
--	[220946] = {name = "Venture Co. Honey Harvester", instanceID = 2661},	-- elite Humanoid RAGE 81 hostile attackable
	[222964] = {name = "Flavor Scientist", instanceID = 2661},	-- elite Humanoid MANA 80 hostile attackable
--	[223423] = {name = "Careless Hopgoblin", instanceID = 2661},	-- elite Humanoid RAGE 81 hostile attackable
--	[223497] = {name = "Worker Bee", instanceID = 2661},	-- elite Beast RAGE 80 hostile attackable
--	[223498] = {name = "Bee-let", instanceID = 2661},	-- minus Beast RAGE 80 hostile attackable
--	[223562] = {name = "Brew Drop", instanceID = 2661},	-- normal Elemental RAGE 80 hostile attackable

-- The Dawnbreaker (2662) TWW Season 1
	[210966] = {name = "Sureki Webmage", instanceID = 2662},	-- elite Humanoid MANA 81 hostile attackable
--	[211087] = {name = "[BOSS] Speaker Shadowcrown", instanceID = 2662},	-- elite Humanoid POWER_TYPE_SHADOW_ENERGY 82 hostile attackable
--	[211089] = {name = "[BOSS] Anub'ikkaj", instanceID = 2662},	-- elite Humanoid POWER_TYPE_SHADOW_ENERGY 82 hostile attackable
	[211261] = {name = "Ascendant Vis'coxria", instanceID = 2662},	-- elite Humanoid MANA 81 hostile attackable
--	[211262] = {name = "Ixkreten the Unbreakable", instanceID = 2662},	-- elite Humanoid RAGE 81 hostile attackable
	[211263] = {name = "Deathscreamer Iken'tak", instanceID = 2662},	-- elite Humanoid MANA 81 hostile attackable
--	[211341] = {name = "Manifested Shadow", instanceID = 2662},	-- elite Elemental MANA 81 hostile attackable
	[213885] = {name = "Nightfall Dark Architect", instanceID = 2662},	-- elite Humanoid MANA 81 hostile attackable
	[213892] = {name = "Nightfall Shadowmage", instanceID = 2662},	-- elite Humanoid MANA 80 hostile attackable
	[213893] = {name = "Nightfall Darkcaster", instanceID = 2662},	-- elite Humanoid MANA 80 hostile attackable
--	[213894] = {name = "Nightfall Curseblade", instanceID = 2662},	-- elite Humanoid RAGE 80 hostile attackable
--	[213895] = {name = "Nightfall Shadowalker", instanceID = 2662},	-- elite Humanoid ENERGY 80 hostile attackable
--	[213905] = {name = "Animated Darkness", instanceID = 2662},	-- normal Aberration RAGE 79 hostile attackable
--	[213932] = {name = "Sureki Militant", instanceID = 2662},	-- elite Humanoid RAGE 81 hostile attackable
--	[213934] = {name = "Nightfall Tactician", instanceID = 2662},	-- elite Humanoid RAGE 81 hostile attackable
--	[213937] = {name = "[BOSS] Rasha'nan", instanceID = 2662},	-- elite Humanoid ENERGY -1 hostile attackable
	[214761] = {name = "Nightfall Ritualist", instanceID = 2662},	-- elite Humanoid MANA 81 hostile attackable
	[214762] = {name = "Nightfall Commander", instanceID = 2662},	-- elite Humanoid RAGE 81 hostile attackable
--	[217124] = {name = "Arathi Bomb", instanceID = 2662},	-- normal Not specified RAGE 80 hostile attackable
	[223994] = {name = "Nightfall Shadowmage", instanceID = 2662},	-- elite Humanoid MANA 81 hostile attackable
	[223995] = {name = "Nightfall Curseblade", instanceID = 2662},	-- elite Humanoid MANA 81 hostile attackable
	[225605] = {name = "Nightfall Darkcaster", instanceID = 2662},	-- elite Humanoid MANA 81 hostile attackable
	[225606] = {name = "Nightfall Shadowalker", instanceID = 2662},	-- elite Humanoid MANA 80 hostile attackable

-- City of Threads (2669) TWW Season 1
--	[216320] = {name = "[BOSS] The Coaglamation", instanceID = 2669},	-- elite Elemental POWER_TYPE_ENERGY 82 hostile attackable
--	[216326] = {name = "Ascended Neophyte", instanceID = 2669},	-- elite Aberration RAGE 80 hostile attackable
--	[216328] = {name = "Unstable Test Subject", instanceID = 2669},	-- elite Aberration RAGE 81 hostile attackable
--	[216329] = {name = "Congealed Droplet", instanceID = 2669},	-- minus Aberration RAGE 80 hostile attackable
	[216339] = {name = "Sureki Unnaturaler", instanceID = 2669},	-- elite Humanoid MANA 80 hostile attackable
--	[216342] = {name = "Skittering Assistant", instanceID = 2669},	-- elite Humanoid MANA 80 hostile attackable
--	[216619] = {name = "[BOSS] Orator Krix'vizk", instanceID = 2669},	-- elite Humanoid POWER_TYPE_ENERGY 82 hostile attackable
--	[216648] = {name = "[BOSS] Nx", instanceID = 2669},	-- elite Humanoid ENERGY 82 hostile attackable
--	[216649] = {name = "[BOSS] Vx", instanceID = 2669},	-- elite Humanoid ENERGY 82 hostile attackable
--	[216658] = {name = "[BOSS] Izo, the Grand Splicer", instanceID = 2669},	-- elite Humanoid POWER_TYPE_ENERGY 82 hostile attackable
--	[219198] = {name = "Ravenous Scarab", instanceID = 2669},	-- normal Beast RAGE 80 hostile attackable
--	[219984] = {name = "Xeph'itik", instanceID = 2669},	-- elite Humanoid RAGE 81 hostile attackable
--	[220003] = {name = "Eye of the Queen", instanceID = 2669},	-- elite Humanoid ENERGY 81 hostile attackable
--	[220193] = {name = "Sureki Venomblade", instanceID = 2669},	-- elite Humanoid RAGE 80 hostile attackable
	[220195] = {name = "Sureki Silkbinder", instanceID = 2669},	-- elite Humanoid MANA 80 hostile attackable
	[220196] = {name = "Herald of Ansurek", instanceID = 2669},	-- elite Humanoid MANA 81 hostile attackable
--	[220197] = {name = "Royal Swarmguard", instanceID = 2669},	-- elite Humanoid RAGE 81 hostile attackable
--	[220199] = {name = "Battle Scarab", instanceID = 2669},	-- normal Beast RAGE 80 hostile attackable
	[220401] = {name = "Pale Priest", instanceID = 2669},	-- elite Humanoid MANA 81 hostile attackable
--	[220423] = {name = "Retired Lord Vul'azak", instanceID = 2669},	-- elite Humanoid RAGE 81 hostile attackable
--	[220730] = {name = "Royal Venomshell", instanceID = 2669},	-- elite Humanoid RAGE 81 hostile attackable
	[221102] = {name = "Elder Shadeweaver", instanceID = 2669},	-- elite Humanoid MANA 81 hostile attackable
--	[221103] = {name = "Hulking Warshell", instanceID = 2669},	-- elite Humanoid RAGE 81 hostile attackable
--	[222700] = {name = "Umbral Weave", instanceID = 2669},	-- normal Not specified RAGE 80 hostile attackable
--	[222974] = {name = "Hungry Scarab", instanceID = 2669},	-- normal Beast RAGE 80 hostile attackable
--	[223181] = {name = "Agile Pursuer", instanceID = 2669},	-- elite Humanoid ENERGY 80 hostile attackable
--	[223182] = {name = "Web Marauder", instanceID = 2669},	-- elite Humanoid RAGE 80 hostile attackable
--	[223357] = {name = "Sureki Conscript", instanceID = 2669},	-- elite Humanoid RAGE 80 hostile attackable
	[223844] = {name = "Covert Webmancer", instanceID = 2669},	-- elite Humanoid MANA 80 hostile attackable
--	[224731] = {name = "Web Marauder", instanceID = 2669},	-- elite Humanoid RAGE 80 hostile attackable
	[224732] = {name = "Covert Webmancer", instanceID = 2669},	-- elite Humanoid MANA 80 hostile attackable
--	[228361] = {name = "Agile Pursuer", instanceID = 2669},	-- elite Humanoid ENERGY 80 hostile attackable
-- [219983] = {name = "Eye of the Queen", instanceID = 2669, marks = "8", auto = "nameplate"},

-- Grim Batol (670) TWW Season 1
--	[224152] = {name = "Twilight Brute", instanceID = 670},	-- elite Dragonkin RAGE 35 hostile attackable
	[224219] = {name = "Twilight Earthcaller", instanceID = 670},	-- elite Dragonkin MANA 35 hostile attackable
--	[224221] = {name = "Twilight Overseer", instanceID = 670},	-- elite Dragonkin RAGE 36 hostile attackable
--	[224240] = {name = "Twilight Flamerender", instanceID = 670},	-- elite Humanoid RAGE 35 hostile attackable
	[224249] = {name = "Twilight Lavabender", instanceID = 670},	-- elite Humanoid MANA 36 hostile attackable
	[224271] = {name = "Twilight Warlock", instanceID = 670},	-- elite Humanoid MANA 35 hostile attackable
	[224276] = {name = "Twilight Enforcer", instanceID = 670, marks = "8"},	-- elite Humanoid RAGE 35 hostile attackable
--	[224609] = {name = "Twilight Destroyer", instanceID = 670},	-- elite Dragonkin RAGE 36 hostile attackable
--	[224853] = {name = "Mutated Hatchling", instanceID = 670},	-- elite Dragonkin RAGE 35 hostile attackable
	[39392] = {name = "Faceless Corruptor", instanceID = 670},	-- elite Aberration MANA 36 hostile attackable
--	[40166] = {name = "Molten Giant", instanceID = 670},	-- elite Giant RAGE 36 hostile attackable
	[40167] = {name = "Twilight Beguiler", instanceID = 670},	-- elite Humanoid MANA 35 hostile attackable
--	[40177] = {name = "[BOSS] Forgemaster Throngus", instanceID = 670},	-- elite Giant RAGE 37 hostile attackable
	[40319] = {name = "[BOSS] Drahga Shadowburner", instanceID = 670},	-- elite Humanoid MANA 37 hostile attackable
--	[40320] = {name = "[BOSS] Valiona", instanceID = 670},	-- elite Dragonkin RAGE 37 hostile attackable
--	[40484] = {name = "[BOSS] Erudax", instanceID = 670},	-- elite Aberration RAGE 37 hostile attackable

-- Theater of Pain (2293) TWW Season 2
	[160495] = {name = "Maniacal Soulbinder", instanceID = 2293},	-- elite Humanoid MANA 60 hostile attackable
--	[162309] = {name = "[BOSS] Kul'tharok", instanceID = 2293},	-- elite Undead ENERGY 62 hostile attackable
--	[162317] = {name = "[BOSS] Gorechop", instanceID = 2293},	-- elite Undead ENERGY 62 hostile attackable
--	[162329] = {name = "[BOSS] Xav the Unfallen", instanceID = 2293},	-- elite Humanoid POWER_TYPE_WARLORD_BOSS_PVP_MECHANIC_ENERGY_BAR 62 hostile attackable
--	[162744] = {name = "Nekthara the Mangler", instanceID = 2293},	-- elite Humanoid RAGE 61 hostile attackable
--	[162763] = {name = "Soulforged Bonereaver", instanceID = 2293},	-- elite Undead RAGE 61 hostile attackable
--	[163086] = {name = "Rancid Gasbag", instanceID = 2293},	-- elite Undead RAGE 61 hostile attackable
--	[163089] = {name = "Disgusting Refuse", instanceID = 2293},	-- normal Undead RAGE 60 hostile attackable
--	[164451] = {name = "[BOSS] Dessia the Decapitator", instanceID = 2293},	-- elite Humanoid POWER_TYPE_RED_POWER 62 hostile attackable
	[164461] = {name = "[BOSS] Sathel the Accursed", instanceID = 2293, marks = "8"},	-- elite Humanoid POWER_TYPE_ENERGY 62 hostile attackable
	[164463] = {name = "[BOSS] Paceran the Virulent", instanceID = 2293, marks = "7"},	-- elite Humanoid POWER_TYPE_ENERGY 62 hostile attackable
	[164506] = {name = "Ancient Captain", instanceID = 2293, marks = "8"},	-- elite Undead RAGE 61 hostile attackable
--	[164510] = {name = "Shambling Arbalest", instanceID = 2293},	-- elite Undead ENERGY 60 hostile attackable
--	[165946] = {name = "[BOSS] Mordretha, the Endless Empress", instanceID = 2293},	-- elite Humanoid MANA 62 hostile attackable
--	[167532] = {name = "Heavin the Breaker", instanceID = 2293},	-- elite Humanoid RAGE 61 hostile attackable
--	[167533] = {name = "Advent Nevermore", instanceID = 2293},	-- elite Humanoid RAGE 61 hostile attackable
--	[167534] = {name = "Rek the Hardened", instanceID = 2293},	-- elite Humanoid RAGE 61 hostile unattackable
--	[167536] = {name = "Harugia the Bloodthirsty", instanceID = 2293},	-- elite Humanoid RAGE 61 hostile attackable
--	[167538] = {name = "Dokigg the Brutalizer", instanceID = 2293},	-- elite Humanoid RAGE 61 hostile unattackable
--	[167994] = {name = "Ossified Conscript", instanceID = 2293},	-- elite Undead RAGE 60 hostile attackable
--	[167998] = {name = "Portal Guardian", instanceID = 2293},	-- elite Elemental MANA 61 hostile attackable
--	[169875] = {name = "Shackled Soul", instanceID = 2293},	-- elite Undead MANA 60 hostile attackable
	[169893] = {name = "Nefarious Darkspeaker", instanceID = 2293},	-- elite Undead MANA 61 hostile attackable
--	[169927] = {name = "Putrid Butcher", instanceID = 2293},	-- elite Undead RAGE 60 hostile attackable
	[170690] = {name = "Diseased Horror", instanceID = 2293},	-- elite Undead RAGE 60 hostile attackable
--	[170838] = {name = "Unyielding Contender", instanceID = 2293},	-- elite Humanoid RAGE 60 hostile attackable
--	[170850] = {name = "Raging Bloodhorn", instanceID = 2293},	-- elite Beast RAGE 61 hostile attackable
	[170882] = {name = "Bone Magus", instanceID = 2293},	-- elite Undead MANA 60 hostile attackable
	[174197] = {name = "Battlefield Ritualist", instanceID = 2293},	-- elite Humanoid MANA 60 hostile attackable
	[174210] = {name = "Blighted Sludge-Spewer", instanceID = 2293},	-- elite Undead MANA 60 hostile attackable

-- The MOTHERLOAD!! (1594) TWW Season 2
--	[129214] = {name = "[BOSS] Coin-Operated Crowd Pummeler", instanceID = 1594},	-- elite Mechanical ENERGY 62 hostile attackable
--	[129227] = {name = "Azerokk", instanceID = 1594},	-- elite Elemental ENERGY 62 hostile attackable
--	[129231] = {name = "[BOSS] Rixxa Fluxflame", instanceID = 1594},	-- elite Humanoid MANA 62 hostile attackable
--	[129232] = {name = "[BOSS] Mogul Razdunk", instanceID = 1594},	-- elite Mechanical ENERGY 62 hostile attackable
--	[129246] = {name = "Azerite Footbomb", instanceID = 1594},	-- normal Not specified RAGE 60 hostile attackable
--	[129802] = {name = "[BOSS ADD] Earthrager", instanceID = 1594},	-- elite Elemental RAGE 60 hostile attackable
--	[130435] = {name = "Addled Thug", instanceID = 1594},	-- elite Humanoid RAGE 61 hostile attackable
--	[130436] = {name = "Off-Duty Laborer", instanceID = 1594},	-- normal Humanoid RAGE 60 hostile attackable
--	[130437] = {name = "Mine Rat", instanceID = 1594},	-- normal Humanoid RAGE 60 hostile attackable
--	[130485] = {name = "Mechanized Peacekeeper", instanceID = 1594},	-- elite Mechanical RAGE 61 hostile attackable
	[130488] = {name = "Mech Jockey", instanceID = 1594, marks = "87"},	-- elite Humanoid RAGE 60 hostile attackable
	[130635] = {name = "Stonefury", instanceID = 1594},	-- elite Elemental MANA 60 hostile attackable
--	[130653] = {name = "Wanton Sapper", instanceID = 1594},	-- elite Humanoid RAGE 60 hostile attackable
	[130661] = {name = "Venture Co. Earthshaper", instanceID = 1594},	-- elite Humanoid MANA 60 hostile attackable
--	[132056] = {name = "[BOSS ADD] Venture Co. Skyscorcher", instanceID = 1594},	-- elite Humanoid RAGE 61 hostile attackable
--	[132713] = {name = "Mogul Razdunk", instanceID = 1594},	-- normal Humanoid RAGE 60 hostile attackable
	[133430] = {name = "Venture Co. Mastermind", instanceID = 1594, marks = "87"},	-- elite Humanoid MANA 61 hostile attackable
	[133432] = {name = "Venture Co. Alchemist", instanceID = 1594},	-- elite Humanoid RAGE 60 hostile attackable
--	[133463] = {name = "Venture Co. War Machine", instanceID = 1594},	-- elite Mechanical RAGE 61 hostile attackable
--	[133482] = {name = "Crawler Mine", instanceID = 1594},	-- minus Mechanical RAGE 61 hostile attackable
--	[133963] = {name = "Test Subject", instanceID = 1594},	-- normal Beast RAGE 60 hostile attackable
--	[134005] = {name = "Shalebiter", instanceID = 1594},	-- normal Beast RAGE 60 hostile attackable
--	[134012] = {name = "Taskmaster Askari", instanceID = 1594},	-- elite Humanoid RAGE 61 hostile attackable
	[134232] = {name = "Hired Assassin", instanceID = 1594},	-- elite Humanoid ENERGY 60 hostile attackable
--	[135975] = {name = "Off-Duty Laborer", instanceID = 1594},	-- normal Humanoid RAGE 60 hostile attackable
--	[136139] = {name = "Mechanized Peacekeeper", instanceID = 1594},	-- elite Mechanical RAGE 61 hostile attackable
	[136470] = {name = "Refreshment Vendor", instanceID = 1594},	-- elite Humanoid MANA 60 hostile attackable
--	[136643] = {name = "Azerite Extractor", instanceID = 1594},	-- elite Mechanical RAGE 61 hostile attackable
--	[136688] = {name = "Fanatical Driller", instanceID = 1594},	-- normal Humanoid RAGE 60 hostile attackable
--	[136934] = {name = "Weapons Tester", instanceID = 1594},	-- elite Humanoid RAGE 60 hostile attackable
--	[137029] = {name = "Ordnance Specialist", instanceID = 1594},	-- elite Humanoid RAGE 60 hostile attackable
--	[137940] = {name = "Safety Shark", instanceID = 1594},	-- elite Beast RAGE 60 hostile attackable
--	[138369] = {name = "Footbomb Hooligan", instanceID = 1594},	-- normal Humanoid RAGE 60 hostile attackable

-- Operation: Mechagon - Workshop (2097) TWW Season 2
--	[144244] = {name = "[BOSS] The Platinum Pummeler", instanceID = 2097},	-- elite Mechanical RAGE 52 hostile attackable
--	[144246] = {name = "[BOSS] K.U.-J.0.", instanceID = 2097},	-- elite Mechanical RAGE 52 hostile attackable
--	[144248] = {name = "[BOSS] Head Machinist Sparkflux", instanceID = 2097},	-- elite Mechanical ENERGY 52 hostile attackable
--	[144249] = {name = "[BOSS] Omega Buster", instanceID = 2097},	-- elite Mechanical ENERGY 52 hostile attackable
--	[144293] = {name = "Waste Processing Unit", instanceID = 2097},	-- elite Mechanical RAGE 51 hostile attackable
	[144294] = {name = "Mechagon Tinkerer", instanceID = 2097},	-- elite Humanoid RAGE 50 hostile attackable
	[144295] = {name = "Mechagon Mechanic", instanceID = 2097},	-- elite Humanoid RAGE 50 hostile attackable
--	[144296] = {name = "Spider Tank", instanceID = 2097},	-- elite Mechanical RAGE 51 hostile attackable
--	[144298] = {name = "Defense Bot Mk III", instanceID = 2097},	-- elite Mechanical RAGE 50 hostile attackable
--	[144299] = {name = "Workshop Defender", instanceID = 2097},	-- elite Humanoid RAGE 50 hostile attackable
--	[144301] = {name = "Living Waste", instanceID = 2097},	-- minus Elemental RAGE 50 hostile attackable
--	[144303] = {name = "G.U.A.R.D.", instanceID = 2097},	-- elite Mechanical RAGE 50 hostile attackable
--	[145185] = {name = "[BOSS] Gnomercy 4.U.", instanceID = 2097},	-- elite Mechanical RAGE 52 hostile attackable
--	[150396] = {name = "[BOSS] Aerial Unit R-21/X", instanceID = 2097},	-- elite Mechanical ENERGY 52 hostile attackable
--	[150397] = {name = "King Mechagon", instanceID = 2097},	-- elite Mechanical ENERGY 52 hostile attackable
--	[151325] = {name = "Alarm-o-Bot", instanceID = 2097},	-- normal Mechanical RAGE 50 hostile attackable
--	[151476] = {name = "Blastatron X-80", instanceID = 2097},	-- elite Mechanical RAGE 51 hostile attackable
--	[151579] = {name = "Shield Generator", instanceID = 2097},	-- normal Mechanical ENERGY 50 hostile attackable
--	[151613] = {name = "Anti-Personnel Squirrel", instanceID = 2097},	-- normal Mechanical RAGE 50 hostile attackable
--	[151649] = {name = "Defense Bot Mk I", instanceID = 2097},	-- elite Mechanical RAGE 50 hostile attackable
	[151657] = {name = "Bomb Tonk", instanceID = 2097},	-- elite Mechanical RAGE 50 hostile attackable
--	[151658] = {name = "Strider Tonk", instanceID = 2097},	-- elite Mechanical RAGE 50 hostile attackable
--	[151659] = {name = "Rocket Tonk", instanceID = 2097},	-- elite Mechanical RAGE 50 hostile attackable
--	[151773] = {name = "Junkyard D.0.G.", instanceID = 2097},	-- elite Mechanical RAGE 50 hostile attackable
--	[151812] = {name = "Detect-o-Bot", instanceID = 2097},	-- normal Mechanical RAGE 50 hostile attackable
--	[152033] = {name = "[BOSS ADD] Inconspicuous Plant", instanceID = 2097},	-- normal Mechanical RAGE 50 hostile attackable

-- Operation: Floodgate (2773) TWW Season 2
--	[226396] = {name = "[BOSS] Swampface", instanceID = 2773},	-- elite Elemental ENERGY 82 hostile attackable
--	[226398] = {name = "[BOSS] Big M.O.M.M.A.", instanceID = 2773},	-- elite Mechanical POWER_TYPE_ENERGY 82 hostile attackable
--	[226402] = {name = "[BOSS] Bront", instanceID = 2773},	-- elite Humanoid ENERGY 82 hostile attackable
--	[226403] = {name = "[BOSS] Keeza Quickfuse", instanceID = 2773},	-- elite Humanoid ENERGY 82 hostile attackable
--	[226404] = {name = "[BOSS] Geezle Gigazap", instanceID = 2773},	-- elite Humanoid POWER_TYPE_STORMENERGY 82 hostile attackable
--	[227145] = {name = "Waterworks Crocolisk", instanceID = 2773},	-- elite Beast RAGE 80 hostile attackable
--	[228144] = {name = "Darkfuse Soldier", instanceID = 2773},	-- elite Humanoid RAGE 80 hostile attackable
--	[228424] = {name = "Darkfuse Mechadrone", instanceID = 2773},	-- elite Mechanical RAGE 81 hostile attackable
	[229069] = {name = "Mechadrone Sniper", instanceID = 2773},	-- elite Mechanical RAGE 80 hostile attackable
--	[229212] = {name = "Darkfuse Demolitionist", instanceID = 2773},	-- elite Humanoid RAGE 80 hostile attackable
--	[229250] = {name = "Venture Co. Contractor", instanceID = 2773},	-- elite Humanoid RAGE 80 hostile attackable
	[229251] = {name = "Venture Co. Architect", instanceID = 2773},	-- elite Humanoid MANA 81 hostile attackable
--	[229252] = {name = "Darkfuse Hyena", instanceID = 2773},	-- elite Beast RAGE 80 hostile attackable
	[229686] = {name = "Venture Co. Surveyor", instanceID = 2773},	-- elite Humanoid MANA 80 hostile attackable
	[230740] = {name = "Shreddinator 3000", instanceID = 2773, marks = "87"},	-- elite Mechanical RAGE 81 hostile attackable
	[230748] = {name = "Darkfuse Bloodwarper", instanceID = 2773},	-- elite Humanoid MANA 81 hostile attackable
--	[231014] = {name = "Loaderbot", instanceID = 2773},	-- elite Mechanical RAGE 80 hostile attackable
--	[231176] = {name = "Scaffolding", instanceID = 2773},	-- normal Not specified RAGE 80 hostile attackable
--	[231197] = {name = "Bubbles", instanceID = 2773},	-- elite Beast RAGE 81 hostile attackable
	[231223] = {name = "Disturbed Kelp", instanceID = 2773},	-- elite Elemental RAGE 80 hostile attackable
	[231312] = {name = "Venture Co. Electrician", instanceID = 2773},	-- elite Humanoid MANA 80 hostile attackable
	[231325] = {name = "Darkfuse Jumpstarter", instanceID = 2773, marks = "87"},	-- elite Humanoid RAGE 81 hostile attackable
--	[231380] = {name = "Undercrawler", instanceID = 2773},	-- elite Beast RAGE 80 hostile attackable
--	[231385] = {name = "Darkfuse Inspector", instanceID = 2773},	-- elite Humanoid RAGE 80 hostile attackable
--	[231496] = {name = "Venture Co. Diver", instanceID = 2773},	-- elite Humanoid RAGE 80 hostile attackable
--	[231497] = {name = "Bombshell Crab", instanceID = 2773},	-- elite Beast RAGE 80 hostile attackable
--	[236982] = {name = "Darkfuse Soldier", instanceID = 2773},	-- elite Humanoid RAGE 80 hostile attackable

-- Algeth'ar Academy (2526)
	[196548] = {name = "[BOSS-ADD] Ancient Branch", instanceID = 2526, auto = "nameplate", marks = "87"},
	[196202] = {name = "Spectral Invoker", instanceID = 2526},
	[192333] = {name = "Alpha Eagle", instanceID = 2526},
	[196798] = {name = "Corrupted Manafiend", instanceID = 2526},
	[196045] = {name = "Corrupted Manafiend", instanceID = 2526},
	[196576] = {name = "Spellbound Scepter", instanceID = 2526},
	[197905] = {name = "Spellbound Scepter", instanceID = 2526},
	[196044] = {name = "Unruly Textbook", instanceID = 2526},
	[197406] = {name = "Aggravated Skitterfly", instanceID = 2526, marks = "87"},

-- Uldaman: Legacy of Tyr (2451)
	[184580] = {name = "[BOSS] Olaf", instanceID = 2451, auto = "nameplate", marks = "7"},
	[186696] = {name = "[BOSS-ADD] Quaking Totem", instanceID = 2451, auto = "nameplate", marks = "!8"},
	[186658] = {name = "[BOSS-ADD] Stonevault Geomancer", instanceID = 2451},
	[184019] = {name = "Burly Rock-Thrower", instanceID = 2451, marks = "87"},
	[184301] = {name = "Cavern Seeker", instanceID = 2451},
	[184132] = {name = "Earthen Warder", instanceID = 2451},
	[186420] = {name = "Earthen Weaver", instanceID = 2451},
	[184335] = {name = "Infinite Agent", instanceID = 2451},
	[184331] = {name = "Infinite Timereaver", instanceID = 2451, marks = "87"},
	[184022] = {name = "Stonevault Geomancer", instanceID = 2451},
	[184023] = {name = "Vicious Basilisk", instanceID = 2451},

-- The Nokhud Offensive (2516)
	[186339] = {name = "[BOSS] Teera", instanceID = 2516},
	[193462] = {name = "Batak", instanceID = 2516},
	[199717] = {name = "Nokhud Defender", instanceID = 2516},
	[192800] = {name = "Nokhud Lancemaster", instanceID = 2516, marks = "+1"},
	[191847] = {name = "Nokhud Plainstomper", instanceID = 2516, marks = "+1"},
	[190294] = {name = "[BOSS-ADD] Nokhud Stormcaster", instanceID = 2516, auto = "*mouseover"},
	[199719] = {name = "Nokhud Wardog", instanceID = 2516},
	[195696] = {name = "Primalist Thunderbeast", instanceID = 2516},
	[195877] = {name = "Risen Mystic", instanceID = 2516},
	[195928] = {name = "Soulharvester Duuren", instanceID = 2516, marks = "+1"},
	[195927] = {name = "Soulharvester Galtmaa", instanceID = 2516, marks = "+1"},
	[195930] = {name = "Soulharvester Mandakh", instanceID = 2516, marks = "+1"},
	[195929] = {name = "Soulharvester Tumen", instanceID = 2516, marks = "+1"},
	[195265] = {name = "Stormcaller Arynga", instanceID = 2516, marks = "+1"},
	[194317] = {name = "Stormcaller Boroo", instanceID = 2516, marks = "+1"},
	[194315] = {name = "Stormcaller Solongo", instanceID = 2516, marks = "+1"},
	[194316] = {name = "Stormcaller Zarii", instanceID = 2516, marks = "+1"},
	[195842] = {name = "Ukhel Corruptor", instanceID = 2516},
	[192796] = {name = "Nokhud Hornsounder", instanceID = 2516},
	[194897] = {name = "Stormsurge Totem", instanceID = 2516, marks = "+8"},
	[194894] = {name = "Primalist Stormspeaker", instanceID = 2516},
	[195876] = {name = "Desecrated Ohuna", instanceID = 2516},

-- The Azure Vault (2515)
	[186741] = {name = "Arcane Elemental", instanceID = 2515},
	[196115] = {name = "Arcane Tender", instanceID = 2515},
	[191164] = {name = "Arcane Tender", instanceID = 2515},
	[196102] = {name = "Conjured Lasher", instanceID = 2515},
	[190187] = {name = "[BOSS-ADD] Draconic Image", instanceID = 2515},
	[187155] = {name = "Rune Seal Keeper", instanceID = 2515},
	[199368] = {name = "[BOSS-ADD] Hardened Crystal", instanceID = 2515, auto = "nameplate", marks = "!8"},

-- Ruby Life Pools (2521)
	[188252] = {name = "[BOSS] Melidrussa Chillworn", instanceID = 2521},
	[189886] = {name = "[BOSS-ADD] Blazebound Firestorm", instanceID = 2521, auto = "nameplate", marks = "8"},
	[197985] = {name = "Flame Channeler", instanceID = 2521},
	[188067] = {name = "Flashfrost Chillweaver", instanceID = 2521},
	[187969] = {name = "Flashfrost Earthshaper", instanceID = 2521},
	[197535] = {name = "High Channeler Ryvati", instanceID = 2521},
	[190207] = {name = "Primalist Cinderweaver", instanceID = 2521},
	[190206] = {name = "Primalist Flamedancer", instanceID = 2521},
	[198047] = {name = "Tempest Channeler", instanceID = 2521},

-- Neltharus (2519)
	[194816] = {name = "Forgewrought Monstrosity", instanceID = 2519},
	[189470] = {name = "Lava Flare", instanceID = 2519},
	[189235] = {name = "Overseer Lahar", instanceID = 2519},
	[189265] = {name = "Qalashi Bonetender", instanceID = 2519},
	[189464] = {name = "Qalashi Irontorch", instanceID = 2519},
	[193944] = {name = "Qalashi Lavamancer", instanceID = 2519},
	[192788] = {name = "Qalashi Thaumaturge", instanceID = 2519},

-- Halls of Infusion (2527)
	[196043] = {name = "[BOSS-ADD] Primalist Infuser", instanceID = 2527, auto = "nameplate", marks = "8726"},
	[190407] = {name = "Aqua Rager", instanceID = 2527},
	[190342] = {name = "Containment Apparatus", instanceID = 2527},
	[190362] = {name = "Dazzling Dragonfly", instanceID = 2527},
	[190368] = {name = "Flamecaller Aymi", instanceID = 2527},
	[190405] = {name = "Infuser Sariya", instanceID = 2527},
	[190371] = {name = "Primalist Earthshaker", instanceID = 2527},
	[190373] = {name = "Primalist Galesinger", instanceID = 2527},
	[190377] = {name = "Primalist Icecaller", instanceID = 2527},
	[199037] = {name = "Primalist Shocktrooper", instanceID = 2527},
	[190340] = {name = "Refti Defender", instanceID = 2527},

-- Brackenhide Hollow (2520)
	[186122] = {name = "[BOSS] Rira Hackclaw", instanceID = 2520, auto = "nameplate", marks = "7"},
	[186125] = {name = "[BOSS] Tricktotem", instanceID = 2520, auto = "nameplate", marks = "1"},
	[186124] = {name = "[BOSS] Gashtooth", instanceID = 2520, auto = "nameplate", marks = "8"},
	[185529] = {name = "Bracken Warscourge", instanceID = 2520},
	[195135] = {name = "Bracken Warscourge", instanceID = 2520},
	[186191] = {name = "Decay Speaker", instanceID = 2520},
	[189531] = {name = "Decayed Elder", instanceID = 2520},
	[186226] = {name = "Fetid Rotsinger", instanceID = 2520},
	[185656] = {name = "Filth Caller", instanceID = 2520},
	[186246] = {name = "Fleshripper Vulture", instanceID = 2520},
	[186208] = {name = "Rotbow Stalker", instanceID = 2520},
	[193799] = {name = "Rotchanting Totem", instanceID = 2520, auto = "nameplate", marks = "87"},
	[185528] = {name = "Trickclaw Mystic", instanceID = 2520},
	[190426] = {name = "Decay Totem", instanceID = 2520, auto = "nameplate", marks = "87"},
	[186220] = {name = "Brackenhide Shaper", instanceID = 2520},

-- Darkheart Thicket (1466)
	[100991] = {name = "[BOSS-ADD] Strangling Roots", instanceID = 1466, auto = "nameplate"},
	[100527] = {name = "Dreadfire Imp", instanceID = 1466},
	[95771] = {name = "Dreadsoul Ruiner", instanceID = 1466},
	[95769] = {name = "Mindshattered Screecher", instanceID = 1466},
	[101991] = {name = "Nightmare Dweller", instanceID = 1466},
	[99365] = {name = "Taintheart Stalker", instanceID = 1466, marks = "8"},
	[99366] = {name = "Taintheart Summoner", instanceID = 1466},

-- Black Rook Hold (1501)
	[99664] = {name = "[BOSS-ADD] Restless Soul", instanceID = 1501, auto = "nameplate"},
	[100486] = {name = "[BOSS-ADD] Risen Arcanist", instanceID = 1501, auto = "nameplate", marks = "8"},
	[100485] = {name = "[BOSS-ADD] Soul-torn Vanguard", instanceID = 1501, auto = "nameplate", marks = "7"},
	[101008] = {name = "[BOSS-ADD] Stinging Swarm", instanceID = 1501, auto = "nameplate", marks = "8"},
	[101549] = {name = "Arcane Minion", instanceID = 1501, marks = "8"},
	[111068] = {name = "Archmage Galeorn", instanceID = 1501},
	[98813] = {name = "Bloodscent Felhound", instanceID = 1501},
	[102788] = {name = "Felspite Dominator", instanceID = 1501},
	[98370] = {name = "Ghostly Councilor", instanceID = 1501},
	[98368] = {name = "Ghostly Protector", instanceID = 1501, marks = "8"},
	[98521] = {name = "Lord Etheldrin Ravencrest", instanceID = 1501},
	[98280] = {name = "Risen Arcanist", instanceID = 1501},
	[98691] = {name = "Risen Scout", instanceID = 1501},

-- Waycrest Manor (1862)
	[136330] = {name = "[BOSS-ADD] Soul Thorns", instanceID = 1862, marks = "8"},
	[133361] = {name = "[BOSS-ADD] Wasting Servant", instanceID = 1862},
	[131545] = {name = "[BOSS] Lady Waycrest", instanceID = 1862},
	[131587] = {name = "Bewitched Captain", instanceID = 1862},
	[131819] = {name = "Coven Diviner", instanceID = 1862},
	[131666] = {name = "Coven Thornshaper", instanceID = 1862},
	[134024] = {name = "Devouring Maggot", instanceID = 1862},
	[135049] = {name = "Dreadwing Raven", instanceID = 1862},
	[131677] = {name = "Heartsbane Runeweaver", instanceID = 1862},
	[131812] = {name = "Heartsbane Soulcharmer", instanceID = 1862},
	[131670] = {name = "Heartsbane Vinetwister", instanceID = 1862},
	[131850] = {name = "Maddened Survivalist", instanceID = 1862},
	[131818] = {name = "Marked Sister", instanceID = 1862},
	[135365] = {name = "Matron Alma", instanceID = 1862},
	[137830] = {name = "Pallid Gorger", instanceID = 1862},
	[131685] = {name = "Runic Disciple", instanceID = 1862},
	[135240] = {name = "Soul Essence", instanceID = 1862},
	[135474] = {name = "Thistle Acolyte", instanceID = 1862},

-- Atal'Dazar (1763)
	[125977] = {name = "[BOSS-ADD] Reanimation Totem", instanceID = 1763, marks = "123"},
	[125828] = {name = "[BOSS-ADD] Soul Rend Copy", instanceID = 1763, auto = "nameplate"},
	[122972] = {name = "Dazar'ai Augur", instanceID = 1763},
	[122973] = {name = "Dazar'ai Confessor", instanceID = 1763},
	[122971] = {name = "Dazar'ai Juggernaut", instanceID = 1763},
	[128434] = {name = "Feasting Skyscreamer", instanceID = 1763},
	[132126] = {name = "Gilded Priestess", instanceID = 1763},
	[127879] = {name = "Shieldbearer of Zul", instanceID = 1763},
	[135989] = {name = "Shieldbearer of Zul", instanceID = 1763},
	[122969] = {name = "Zanchuli Witch-Doctor", instanceID = 1763},

-- The Everbloom (1279)
	[82682] = {name = "[BOSS] Archmage Sol", instanceID = 1279},
	[84550] = {name = "[BOSS] Xeri'tac", instanceID = 1279},
	[86547] = {name = "[BOSS-ADD] Venom Sprayer", instanceID = 1279},
	[84990] = {name = "Addled Arcanomancer", instanceID = 1279},
	[81820] = {name = "Everbloom Mender", instanceID = 1279},
	[81819] = {name = "Everbloom Naturalist", instanceID = 1279},
	[81985] = {name = "Everbloom Tender", instanceID = 1279},
	[84989] = {name = "Infested Icecaller", instanceID = 1279},
	[84957] = {name = "Putrid Pyromancer", instanceID = 1279},

-- Throne of the Tides (643)
	[40586] = {name = "[BOSS] Lady Naz'jar", instanceID = 643},
	[44404] = {name = "[BOSS-ADD] Naz'jar Tempest Witch", instanceID = 643},
	[40825] = {name = "[BOSS] Erunak Stonespeaker", instanceID = 643},
	[44715] = {name = "[BOSS-ADD] Vicious Mindlasher", instanceID = 643},
	[40943] = {name = "Gilgoblin Aquamage", instanceID = 643},
	[40634] = {name = "Naz'jar Tempest Witch", instanceID = 643},
	[41096] = {name = "Naz'jar Spiritmender", instanceID = 643},
	[41139] = {name = "Naz'jar Spiritmender", instanceID = 643},
	[41096] = {name = "Naz'jar Oracle", instanceID = 643},
	[212775] = {name = "Faceless Seer", instanceID = 643},
	[44404] = {name = "Naz'jar Frost Witch", instanceID = 643},

-- Dawn of the Infinite: Murozond's Rise (2579)
	[208165] = {name = "Alliance Knight", instanceID = 2579},
	[204206] = {name = "Horde Farseer", instanceID = 2579},
	[207969] = {name = "Horde Raider", instanceID = 2579},
	[203857] = {name = "Horde Warlock", instanceID = 2579},
	[208698] = {name = "Infinite Riftmage", instanceID = 2579},
	[201223] = {name = "Infinite Twilight Magus", instanceID = 2579},
	[208193] = {name = "Paladin of the Silver Hand", instanceID = 2579},
	[206074] = {name = "Pendule", instanceID = 2579},
	[205363] = {name = "Time-Lost Waveshaper", instanceID = 2579},
	[199748] = {name = "Timeline Marauder", instanceID = 2579},

-- Dawn of the Infinite: Galakrond's Fall (2579)
	[206064] = {name = "Coalesced Moment", instanceID = 2579},
	[206140] = {name = "Coalesced Time", instanceID = 2579},
	[205384] = {name = "Infinite Chronoweaver", instanceID = 2579},
	[205691] = {name = "Iridikron's Creation", instanceID = 2579},
	[206066] = {name = "Timestream Leech", instanceID = 2579},
	[206074] = {name = "Pendule", instanceID = 2579},

-- Temple of the Jade Serpent (960)
	[56448] = {name = "[BOSS] Wise Mari", instanceID = 960},
	[62358] = {name = "Corrupt Droplet", instanceID = 960},
	[200137] = {name = "Depraved Mistweaver", instanceID = 960},
	[200126] = {name = "Fallen Waterspeaker", instanceID = 960},
	[59555] = {name = "Haunting Sha", instanceID = 960},
	[59552] = {name = "The Crybaby Hozen", instanceID = 960},
	[59546] = {name = "The Talking Fish", instanceID = 960},

-- Shadowmoon Burial Grounds (1176)
	[75966] = {name = "[BOSS-ADD] Defiled Spirit", instanceID = 1176, auto = "nameplate", marks = "87"},
	[75451] = {name = "[BOSS-ADD] Defiled Spirit", instanceID = 1176, auto = "nameplate", marks = "87"},
	[76104] = {name = "Monstrous Corpse Spider", instanceID = 1176},
	[75459] = {name = "Plagued Bat", instanceID = 1176},
	[75713] = {name = "Shadowmoon Bone-Mender", instanceID = 1176},
	[76446] = {name = "Shadowmoon Enslaver", instanceID = 1176},
	[77700] = {name = "Shadowmoon Exhumer", instanceID = 1176},
	[75506] = {name = "Shadowmoon Loyalist", instanceID = 1176},

-- Court of Stars (1571)
	[104217] = {name = "[BOSS] Talixae Flamewreath", instanceID = 1571},
	[104247] = {name = "Duskwatch Arcanist", instanceID = 1571},
	[104246] = {name = "Duskwatch Guard", instanceID = 1571},
	[104251] = {name = "Duskwatch Sentry", instanceID = 1571, marks = "87"},
	[104270] = {name = "Guardian Construct", instanceID = 1571},
	[104300] = {name = "Shadow Mistress", instanceID = 1571},
	[105715] = {name = "Watchful Inquisitor", instanceID = 1571},

-- Halls of Valor (1477)
	[97202] = {name = "Olmyr the Enlightened", instanceID = 1477},
	[102019] = {name = "Stormforged Obliterator", instanceID = 1477},
	[95834] = {name = "Valarjar Mystic", instanceID = 1477},
	[97197] = {name = "Valarjar Purifier", instanceID = 1477},
	[96664] = {name = "Valarjar Runecarver", instanceID = 1477},
	[95842] = {name = "Valarjar Thundercaller", instanceID = 1477},
	[97081] = {name = "King Bjorn", instanceID = 1477},
	[95843] = {name = "King Haldor", instanceID = 1477},
	[97083] = {name = "King Ranulf", instanceID = 1477},
	[97084] = {name = "King Tor", instanceID = 1477},

-- Underrot (1841)
	[131318] = {name = "[BOSS] Elder Leaxa", instanceID = 1841, auto = "nameplate", marks = "8"},
	[134701] = {name = "Blood Effigy", instanceID = 1841, auto = "nameplate", marks = "7"},
	[137103] = {name = "Blood Visage", instanceID = 1841, auto = "nameplate", marks = "7"},
	[133835] = {name = "Feral Bloodswarmer", instanceID = 1841},
	[133870] = {name = "Diseased Lasher", instanceID = 1841},
	[134284] = {name = "Fallen Deathspeaker", instanceID = 1841},
	[133912] = {name = "Bloodsworn Defiler", instanceID = 1841},
	[138187] = {name = "Grotesque Horror", instanceID = 1841},
	[131492] = {name = "Devout Blood Priest", instanceID = 1841},
	[130909] = {name = "Fetid Maggot", instanceID = 1841, marks = "8"},
	[133685] = {name = "Befouled Spirit", instanceID = 1841},

-- Freehold (1754)
	[126848] = {name = "[BOSS] Captain Eudora", instanceID = 1754, auto = "nameplate", marks = "8"},
	[129758] = {name = "Irontide Grenadier", instanceID = 1754},
	[129788] = {name = "Irontide Bonesaw", instanceID = 1754},
	[129559] = {name = "Cutwater Duelist", instanceID = 1754},
	[130012] = {name = "Irontide Ravager", instanceID = 1754},
	[126919] = {name = "Irontide Stormcaller", instanceID = 1754},
	[129527] = {name = "Bilge Rat Buccaneer", instanceID = 1754},
	[129600] = {name = "Bilge Rat Brinescale", instanceID = 1754},

-- The Vortex Pinnacle (657)
	[88186] = {name = "Empyrean Assassin", instanceID = 657},
	[45935] = {name = "Temple Adept", instanceID = 657},
	[45912] = {name = "Wild Vortex", instanceID = 657},
	[45928] = {name = "Executor of the Caliph", instanceID = 657},
	[45924] = {name = "Turbulent Squall", instanceID = 657},

-- Neltharion's Lair (1458)
	[97720] = {name = "[BOSS-ADD] Blightshard Skitter", instanceID = 1458, auto = "nameplate", marks = "87"},
	[98081] = {name = "[BOSS-ADD] Bellowing Idol", instanceID = 1458, auto = "nameplate", marks = "87"},
	[100818] = {name = "[BOSS-ADD] Bellowing Idol", instanceID = 1458, auto = "nameplate"},
	[101075] = {name = "[BOSS-ADD] Wormspeaker Devout", instanceID = 1458, auto = "nameplate", marks = "87"},
	[101476] = {name = "[BOSS-ADD] Molten Charskin", instanceID = 1458, auto = "nameplate", marks = "8"},
	[92610] = {name = "Understone Drummer", instanceID = 1458, auto = "combat", marks = "87"},
	[90998] = {name = "Blightshard Shaper", instanceID = 1458},
	[91000] = {name = "Vileshard Hulk", instanceID = 1458, marks = "87"},
	[102232] = {name = "Rockbound Trapper", instanceID = 1458},
	[102253] = {name = "Understone Demolisher", instanceID = 1458},
	[92538] = {name = "[ADD] Tarspitter Grub", instanceID = 1458, auto = "nameplate", marks = "87"},
	[91008] = {name = "Rockbound Pelter", instanceID = 1458, marks = "87"},
	[101437] = {name = "Burning Geode", instanceID = 1458, marks = "8"},

}

MyAddon.Icons = {1,2,3,6,7,8}

MyAddon.PlayerMarks = {
	["TANK"] = 4,
	["HEALER"] = 0,
}
