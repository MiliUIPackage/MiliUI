local addon, Engine = ...

local DE = Engine.Core
local L = Engine.L

local format, ipairs, min, pairs, select, strsplit, tonumber = format, ipairs, min, pairs, select, strsplit, tonumber

local Spells = {
    -- Debug
    -- [] = 20,        -- ()
    -- [252144] = 1,
    -- [190984] = 1,         -- DEBUG Druid Wrath
    -- [285452] = 1,         -- DEBUG Shaman Lava Burst
    -- [188389] = 1,         -- DEBUG Shaman Flame Shock

    -- Affixes
    [209862] = 20, -- Volcanic Plume (Environment)
    [226512] = 20, -- Sanguine Ichor (Environment)
    [240448] = 20, -- Quaking (Environment)
    [343520] = 20, -- Storming (Environment)
    [350163] = 20, -- Melee (Spiteful Shade)

    [394873] = 20, -- Lightning Strike (Season 1 Thundering)
    [396411] = 20, -- Primal Overload (Season 1 Thundering)


    -- Uldaman: Legacy of Tyr
    [369811] = 20, -- Brutal Slam (Hulking Berserker)
    [369854] = 20, -- Throw Rock (Burly Rock-Thrower)
    [382576] = 20, -- Scorn of Tyr (Earthen Guardian)

    [369573] = 20, -- Heavy Arrow (Baelog, The Lost Dwarves)
    [369792] = 20, -- Skullcracker (Eric "The Swift", The Lost Dwarves)
    [375286] = 20, -- Searing Cannonfire (The Lost Dwarves)
    [377825] = 20, -- Burning Pitch (The Lost Dwarves)
    [369703] = 20, -- Thundering Slam (Bromach)
    [368996] = 20, -- Purging Flames (Emberon)
    [369029] = 20, -- Heat Engine (Emberon)
    [369052] = 20, -- Seeking Flame (Vault Keeper, Emberon)
    [376325] = 20, -- Eternity Zone (Chrono-Lord Deios)
    [377561] = 20, -- Time Eruption (Chrono-Lord Deios)


    -- Ruby Life Pools
    [372696] = 20, -- Excavating Blast (Primal Juggernaut)
    [372697] = 20, -- Jagged Earth (Primal Juggernaut)
    [373458] = 20, -- Stone Missile (Primal Terrasentry)
    [372088] = 20, -- Blazing Rush, Hit (Defier Draghar)
    [372796] = 20, -- Blazing Rush, DoT (Defier Draghar)
    [385292] = 20, -- Molten Steel (Defier Draghar)
    [378968] = 20, -- Flame Patch (Scorchling)
    [373973] = 20, -- Blaze of Glory, AoE (Primalist Flamedancer)
    [373977] = 20, -- Blaze of Glory, Projectile (Primalist Flamedancer)
    [391727] = 20, -- Storm Breath (Thunderhead)
    [391724] = 20, -- Flame Breath (Flamegullet)
    [373614] = 20, -- Burnout (Blazebound Destroyer)
    --[385311] = 20, -- Thunderstorm (Primalist Shockcaster) - no indicator
    --[392406] = 20, -- Thunderclap (Storm Warrior) - TODO probably not avoidable for melee
    [392399] = 20, -- Crackling Detonation (Primal Thundercloud)

    [384024] = 20, -- Hailbombs, Projectiles (Melidrussa Chillworm)
    [372863] = 20, -- Ritual of Blazebinding (Kokia Blazehoof)
    [372811] = 20, -- Molten Boulder, Projectile (Kokia Blazehoof)
    [872819] = 20, -- Molten Boulder, Explosion (Kokia Blazehoof)
    [372820] = 20, -- Scorched Earth (Kokia Blazehoof)
    [373087] = 20, -- Burnout (Blazebound Firestorm, Kokia Blazehoof)
    [381526] = 20, -- Roaring Firebreath (Kyrakka)
    [384773] = 20, -- Flaming Embers (Kyrakka)


    -- Neltharus
    [372459] = 20, -- Burning (Environment)
    [382708] = 20, -- Volcanic Guard (Qalashi Warden) - TODO which one is correct?
    [397010] = 20, -- Volcanic Guard (Qalashi Warden) - TODO which one is correct?
    [372583] = 20, -- Binding Spear, Impact (Qalashi Hunter)
    --[373540] = 20, -- Binding Spear, periodic (Qalashi Hunter) - should this be tracked?
    [376186] = 20, -- Eruptive Crush, Area (Overseer Lahar)
    [383928] = 20, -- Eruptive Crush, Projectiles (Overseer Lahar)
    [395427] = 20, -- Burning Roar (Overseer Lahar)
    [372372] = 20, -- Magma Fist (Qalashi Trainee)
    [379410] = 20, -- Throw Lava (Qalashi Lavabearer) - TODO which one is correct?
    [394969] = 20, -- Throw Lava (Qalashi Lavabearer) - TODO which one is correct?
    [372208] = 20, -- Djaradin Lava (Qalashi Lavabearer) - TODO which one is correct?
    [398200] = 20, -- Djaradin Lava (Qalashi Lavabearer) - TODO which one is correct?
    [372203] = 20, -- Scorching Breath (Qalashi Irontorch)
    [372293] = 20, -- Conflagrant Battery (Irontorch Commander)
    [378831] = 20, -- Explosive Concoction (Qalashi Plunderer)

    [373756] = 20, -- Magma Wave (Chargath, Bane of Scales)
    [375397] = 20, -- Lava Splash (Chargath, Bane of Scales)
    [375061] = 20, -- Blazing Eruption (Forgemaster Gorek)
    [375241] = 20, -- Forgestorm (Forgemaster Gorek)
    [374397] = 20, -- Heated Swings, Jump (Forgemaster Gorek) - TODO which one is correct?
    [374517] = 20, -- Heated Swings, Jump (Forgemaster Gorek) - TODO which one is correct?
    [381482] = 20, -- Forgefire (Forgemaster Gorek)
    [375071] = 20, -- Magma Lob (Magmatusk)
    [375204] = 20, -- Liquid Hot Magma (Magmatusk)
    [375449] = 20, -- Blazing Charge (Magmatusk)
    [375535] = 20, -- Lava Wave (Magmatusk)
    [377204] = 20, -- The Dragon's Kiln (Warlord Sargha)
    [377477] = 20, -- Burning Ember (Warlord Sargha)
    [377542] = 20, -- Burning Ground (Warlord Sargha)
    [391773] = 20, -- The Dragon's Eruption (Warlord Sargha)


    -- The Nokhud Offensive
    [384868] = 20, -- Multi-Shot (Nokhud Longbow)
    [384479] = 20, -- Rain of Arrows (Nokhud Longbow)
    [384336] = 20, -- War Stomp (Nokhud Plainstomper / Nokhud Lancemaster / Nokhud Defender)
    [386028] = 20, -- Thunder Clap (Primalist Thunderbeast)
    [384882] = 20, -- Stormsurge Lightning (Stormsurge Totem)
    [386694] = 20, -- Stormsurge (Stormsurge Totem)
    [386912] = 20, -- Stormsurge Cloud (Stormsurge Totem)
    [396376] = 20, -- Chant of the Dead (Ukhel Deathspeaker)
    [387611] = 20, -- Necrotic Eruption (Ukhel Corruptor)
    [387629] = 20, -- Rotting Wind (Desecrated Ohuna)
    [388451] = 20, -- Stormcaller's Fury (Environment)
    [382233] = 20, -- Broad Stomp (Nokhud Defender / Batak)
    [382274] = 20, -- Vehement Charge (Nokhud Defender / Balara)
    [374711] = 20, -- Ravaging Spear (Nokhud Warspear / Balara)

    [385916] = 20, -- Tectonic Stomp (Granyth)
    [386920] = 20, -- Raging Lightning (The Raging Tempest)
    [391967] = 20, -- Electrical Overload (The Raging Tempest)
    [386916] = 20, -- The Raging Tempest (The Raging Tempest)
    [388104] = 20, -- Ritual of Desecration (Environment)
    [385193] = 20, -- Earthsplitter (Maruuk) - TODO which is correct?
    [384960] = 20, -- Earthsplitter (Maruuk) - TODO which is correct?
    [395669] = 20, -- Aftershock (Maruuk)
    [386063] = 20, -- Frightful Roar (Maruuk)
    [386037] = 20, -- Gale Arrow, Whirls (Teera)
    [376685] = 20, -- Iron Stampede (Balakar Khan) - TODO which is correct?
    [376688] = 20, -- Iron Stampede (Balakar Khan) - TODO which is correct?
    [375943] = 20, -- Upheaval (Balakar Khan)
    [376737] = 20, -- Lightning (Balakar Khan)
    [376892] = 20, -- Crackling Upheaval (Balakar Khan)
    [376899] = 20, -- Crackling Cloud (Balakar Khan) - TODO is first tick avoidable?


    -- Brackenhide Hollow
    [368297] = 20, -- Toxic Trap, Trigger (Bonebolt Hunter)
    [368299] = 20, -- Toxic Trap, Area (Bonebolt Hunter)
    [382556] = 20, -- Ragestorm (Bracken Warscourge)
    [384673] = 20, -- Spreading Rot (Decay Ritual, Environment)
    --[381770] = 20, -- Gushing Ooze (Decaying Slime) - TODO probably not avoidable for melee
    [378055] = 20, -- Burst (Decaying Slime)
    [378054] = 20, -- Withering Away! (Decaying Slime)
    --[373872] = 20, -- Gushing Ooze (Monstrous Decay) - TODO probably not avoidable for melee
    [374569] = 20, -- Burst (Monstrous Decay)
    [373943] = 20, -- Stomp (Wilted Oak)
    [385303] = 20, -- Teeth Trap (Environment)
    [385524] = 20, -- Sentry Fire (Environment)
    [385805] = 20, -- Violent Whirlwind (Stinkbreath)
    --[385186] = 20, -- Stink Breath (Stinkbreath) - TODO can targeted player outrange?
    [379425] = 20, -- Rotting Creek (Environment)
    [383392] = 20, -- Rotting Surge, Impact (Filth Caller)
    [383399] = 20, -- Rotting Surge, periodic (Filth Caller)

    [377830] = 20, -- Bladestorm (Rira Hackclaw)
    [384148] = 20, -- Ensnaring Trap (Gutshot)
    [384558] = 20, -- Bounding Leap (Rotfang Hyena, Gutshot)
    [376797] = 20, -- Decay Spray (Treemouth)
    [373944] = 20, -- Rotburst Totem, Spawn (Decatriarch Wratheye)
    [376170] = 20, -- Choking Rotcloud, Frontal (Decatriarch Wratheye)
    [376149] = 20, -- Choking Rotcloud, Area (Decatriarch Wratheye)
    [379425] = 20, -- Decaying Fog (Environment, Decatriarch Wratheye)


    -- The Azure Vault
    [370766] = 20, -- Crystalline Rupture (Crystal Thrasher)
    [371021] = 20, -- Splintering Shards, Aura (Crystal Thrasher)
    [375649] = 20, -- Infused Ground (Arcane Tender)
    [375591] = 20, -- Sappy Burst (Volatile Sapling / Bubbling Sapling)
    [371352] = 20, -- Forbidden Knowledge (Unstable Curator)
    [387067] = 20, -- Arcane Bash (Arcane Construct)
    [374868] = 20, -- Unstable Power (Astral Attendant)
    [386536] = 20, -- Null Stomp (Nullmagic Hornswog)

    [374523] = 20, -- Stinging Sap (Leymor)
    [386660] = 20, -- Erupting Fissure (Leymor)
    [374582] = 20, -- Explosive Brand, Area (Leymor)
    [385579] = 20, -- Ancient Orb (Azureblade)
    [390462] = 20, -- Ancient Orb Fragment (Azureblade)
    [389855] = 20, -- Unstable Magic (Draconic Image / Draconic Illusion, Azureblade)
    [384699] = 20, -- Crystalline Roar (Umbrelskul)
    [385078] = 20, -- Arcane Eruption (Umbrelskul)
    [385267] = 20, -- Crackling Vortex (Umbrelskul)


    -- Halls of Infusion
    [374075] = 20, -- Seismic Slam (Primalist Geomancer)
    [393444] = 20, -- Spear Flurry / Gushing Wound (Refti Defender)
    --[374045] = 20, -- Expulse (Containment Apparatus) - no indicator
    [375215] = 20, -- Cave In (Curious Swoglet)
    [374563] = 20, -- Dazzle (Dazzling Dragonfly)
    [374741] = 20, -- Magma Crush (Flamecaller Aymi)
    [375080] = 20, -- Whirling Fury (Squallbringer Cyraz)
    [385168] = 20, -- Thunderstorm (Primalist Galesinger) - TODO is first tick avoidable?
    [375384] = 20, -- Rumbling Earth (Primalist Earthshaker)
    [383204] = 20, -- Crashing Tsunami (Environment)
    [390290] = 20, -- Flash Flood (Infuser Sariya)

    [383935] = 20, -- Spark Volley (Watcher Irideus)
    [389446] = 20, -- Nullifying Pulse (Nullification Device, Watcher Irideus)
    [385691] = 20, -- Belly Slam (Gulping Goliath)
    [386757] = 20, -- Hailstorm (Khajin the Unyielding)
    [386562] = 20, -- Glacial Surge (Khajin the Unyielding)
    [386295] = 20, -- Avalanche (Khajin the Unyielding)
    [390118] = 20, -- Frost Cyclone (Khajin the Unyielding)
    [387474] = 20, -- Infused Globule, Impact (Primal Tsunami)
    [387359] = 20, -- Waterlogged (Primal Tsunami)
    [387363] = 20, -- Infused Globule, Explosion (Primal Tsunami)
    [388786] = 20, -- Rogue Waves (Primal Tsunami)


    -- Algeth'ar Academy
    [388884] = 20, -- Arcane Rain (Spellbound Scepter)
    [388957] = 20, -- Riftbreath (Arcane Ravager)
    [378011] = 20, -- Deadly Winds (Guardian Sentry)
    [377516] = 20, -- Dive Bomb (Territorial Eagle)
    [377524] = 20, -- Dive Bomb (Alpha Eagle)
    [377383] = 20, -- Gust (Alpha Eagle)
    [390918] = 20, -- Seed Detonation (Vile Lasher)
    [387932] = 20, -- Astral Whirlwind (Algeth'ar Echoknight)

    [385970] = 20, -- Arcane Orb, Spawn (Vexamus)
    [386201] = 20, -- Corrupted Mana (Vexamus) - TODO is first tick avoidable?
    [388537] = 20, -- Arcane Fissure, Swirly (Vexamus)
    [377034] = 20, -- Overpowering Gust (Crawth)
    [376449] = 20, -- Firestorm (Crawth)
    [393122] = 20, -- Roving Cyclone (Crawth)
    [388799] = 20, -- Germinate (Overgrown Ancient)
    [388625] = 20, -- Branch Out (Overgrown Ancient)
    [388822] = 20, -- Power Vacuum (Echo of Doragosa)
    [374361] = 20, -- Astral Breath (Echo of Doragosa)
    [388902] = 20, -- Arcane Rift (Echo of Doragosa) - TODO is first tick avoidable?
    [388996] = 20, -- Energy Eruption (Echo of Doragosa)


    -- Court of Stars
    [209027] = 20, -- Quelling Strike (Duskwatch Guard)
    [209477] = 20, -- Wild Detonation (Mana Wyrm)
    [212031] = 20, -- Charged Blast (Bound Energy)
    [209404] = 20, -- Seal Magic (Duskwatch Arcanist)
    [211391] = 20, -- Felblaze Puddle (Legion Hound) - TODO is first tick avoidable?

    [206574] = 20, -- Resonant Slash, Front (Patrol Captain Gerdo)
    [206580] = 20, -- Resonant Slash, Back (Patrol Captain Gerdo)
    [219498] = 20, -- Streetsweeper (Patrol Captain Gerdo)
    [209378] = 20, -- Whirling Blades (Imacu'tya, Talixae Flamewreath)
    [207979] = 20, -- Shockwave (Jazshariu, Talixae Flamewreath)
    [397903] = 20, -- Crushing Leap (Jazshariu, Talixae Flamewreath)
    [207887] = 20, -- Infernal Eruption, Impact (Talixae Flamewreath)
    [211457] = 20, -- Infernal Eruption, Area (Talixae Flamewreath)
    [209628] = 20, -- Piercing Gale (Advisor Melandrus)
    [209630] = 20, -- Piercing Gale (Image of Advisor Melandrus, Advisor Melandrus)
    [209667] = 20, -- Blade Surge (Advisor Melandrus)


    -- Halls of Valor
    [198903] = 20, -- Crackling Storm (Storm Drake)
    [210875] = 20, -- Charged Pulse (Stormforged Sentinel)
    [199818] = 20, -- Crackle (Stormforged Sentinel)
    [199210] = 20, -- Penetrating Shot (Valarjar Marksman)
    [192565] = 20, -- Cleansing Flames (Valarjar Purifier)
    [191508] = 20, -- Blast of Light (Valarjar Aspirant)
    [199337] = 20, -- Bear Trap (Valarjar Trapper)
    [199146] = 20, -- Bucking Charge (Gildedfur Stag)
    [199090] = 20, -- Rumbling Stomp (Angerhoof Bull)

    [193234] = 20, -- Dancing Blade (Hymdall)
    [193260] = 20, -- Static Field (Storm Drake, Hymdall)
    [188395] = 20, -- Ball Lightning (Storm Drake, Hymdall)
    [192206] = 20, -- Sanctify, Orb (Olmyr the Enlightened / Hyrja) - TODO does separate tracking work?
    --[215457] = 20, -- Sanctify, Group Explosion (Olmyr the Enlightened / Hyrja)
    [193827] = 20, -- Ragnarok (God-King Skovald)
    [193702] = 20, -- Infernal Flames (God-King Skovald)
    [198263] = 20, -- Radiant Tempest (Odyn)
    [198088] = 20, -- Glowing Fragment (Odyn)
    [198412] = 20, -- Feedback (Odyn)


    -- Shadowmoon Burial Grounds
    [152688] = 20, -- Shadow Rune (Environment)
    [152690] = 20, -- Shadow Rune (Environment)
    [152696] = 20, -- Shadow Rune (Environment)
    [152854] = 20, -- Void Sphere (Shadowmoon Loyalist) - TODO which is correct?
    [152855] = 20, -- Void Sphere (Shadowmoon Loyalist) - TODO which is correct?
    [398154] = 20, -- Cry of Anguish (Defiled Spirit)
    [394524] = 20, -- Void Eruptions (Void Spawn)
    [153395] = 20, -- Body Slam (Carrion Worm)

    [153232] = 20, -- Daggerfall (Sadana Bloodfury)
    [153373] = 20, -- Daggerfall (Sadana Bloodfury) - TODO is this relevant?
    [153224] = 20, -- Shadow Burn (Sadana Bloodfury)
    [152800] = 20, -- Void Vortex (Nhallish)
    [153070] = 20, -- Void Devastation (Nhallish)
    [153908] = 20, -- Inhale (Bonemaw)
    [153686] = 20, -- Body Slam (Bonemaw)
    --[153692] = 20, -- Necrotic Pitch (Bonemaw) - can be used to avoid Inhale
    [154442] = 20, -- Malevolence (Ner'zhul)
    [154468] = 20, -- Ritual of Bones, Area (Ner'zhul)
    [154469] = 20, -- Ritual of Bones, Debuff (Ner'zhul)


    -- Temple of the Jade Serpent
    [397881] = 20, -- Surging Deluge (Corrupt Living Water)
    [396003] = 20, -- Territorial Display (The Songbird Queen)
    [396010] = 20, -- Tears of Pain (The Crybaby Hozen)
    [398301] = 20, -- Flames of Doubt (Shambling Infester)
    [397899] = 20, -- Leg Sweep (Sha-Touched Guardian)
    [110125] = 20, -- Shattered Resolve (Minion of Doubt)

    [397785] = 20, -- Wash Away (Wise Mari)
    [397793] = 20, -- Corrupted Geyser (Wise Mari)
    [106856] = 20, -- Serpent Kick (Liu Flameheart)
    [106938] = 20, -- Serpent Wave (Liu Flameheart)
    [106864] = 20, -- Jade Serpent Kick (Liu Flameheart)
    [107053] = 20, -- Jade Serpent Wave, Projectile (Liu Flameheart)
    [118540] = 20, -- Jade Serpent Wave, Area (Liu Flameheart)
    [396907] = 20, -- Jade Fire Breath (Yu'lon, Liu Flameheart)
    [107103] = 20, -- Jade Fire, Impact (Yu'lon, Liu Flameheart)
    [107110] = 20 -- Jade Fire, Area (Yu'lon, Liu Flameheart)
}

local SpellsNoTank = {
    -- Uldaman: Legacy of Tyr
    [369409] = 20, -- Cleave (Earthen Custodian)
    [369563] = 20, -- Wild Cleave (Baelog, The Lost Dwarves)
    [369061] = 20, -- Searing Clap (Emberon)
    [375727] = 20, -- Sand Breath (Chrono-Lord Deios)

    -- Neltharus
    [384019] = 20, -- Fiery Focus (Chargath, Bane of Scales)

    -- The Nokhud Offensive
    [384512] = 20, -- Cleaving Strikes (Nokhud Lancemaster / Nokhud Defender)
    [387135] = 20, -- Arcing Strike (Primalist Arcblade)

    -- Brackenhide Hollow
    [382712] = 20, -- Necrotic Breath, Initial (Wilted Oak)
    [382805] = 20, -- Necrotic Breath, DoT (Wilted Oak)
    [377807] = 20, -- Cleave (Rira Hackclaw)
    [381419] = 20, -- Savage Charge (Rira Hackclaw)
    [377559] = 20, -- Vine Whip (Treemouth)

    -- The Azure Vault
    [370764] = 20, -- Piercing Shards (Crystal Fury)
    [391120] = 20, -- Spellfrost Breath (Scalebane Lieutenant)
    [372222] = 20, -- Arcane Cleave (Azureblade)

    -- Halls of Infusion
    [375349] = 20, -- Gusting Breath (Gusting Proto-Drake)
    [375341] = 20, -- Tectonic Breath (Subterranean Proto-Drake)
    [375353] = 20, -- Oceanic Breath (Glacial Proto-Drake)
    [384524] = 20, -- Titanic Fist (Watcher Irideus)
    --[388245] = 20, -- Gulp (Gulping Goliath) - TODO how to handle this properly?

    -- Algeth'ar Academy
    [385958] = 20, -- Arcane Expulsion (Vexamus)

    -- Court of Stars
    [209036] = 20, -- Throw Torch (Duskwatch Sentry)
    [209495] = 20, -- Charged Smash (Guardian Construct)
    [209512] = 20, -- Disrupting Energy (Guardian Construct)

    -- Halls of Valor
    [198888] = 20, -- Lightning Breath (Storm Drake) - TODO is this avoidable by tank?
    [199050] = 20, -- Mortal Hew (Valarjar Shieldmaiden)
    [192018] = 20, -- Shield of Light (Hyrja)

    -- Shadowmoon Burial Grounds
    [153501] = 20 -- Void Blast (Nhallish)
}

local Auras = {
    -- Uldaman: Legacy of Tyr
    [369411] = true, -- Sonic Burst (Cavern Seeker)
    [372652] = true, -- Resonating Orb (Sentinel Talondras)

    -- The Azure Vault
    [386368] = true, -- Polymorphed (Polymorphic Rune, Environment)
    [396722] = true, -- Absolute Zero, Root (Telash Greywing)

    -- Court of Stars
    [214987] = true, -- Righteous Indignation (Suspicious Noble) - TODO find ID for stun
    [224333] = true -- Enveloping Winds (Advisor Melandrus)
}

local AurasNoTank = {}

local Swings = {
    -- [161917] = 20, -- DEBUG
    [174773] = 20 -- Spiteful Shade
}

DE:MergeTables(DE.Spells, Spells);
DE:MergeTables(DE.SpellsNoTank, SpellsNoTank);
DE:MergeTables(DE.Auras, Auras);
DE:MergeTables(DE.AurasNoTank, AurasNoTank);
DE:MergeTables(DE.Swings, Swings);
