local addon, Engine = ...

local DE = Engine.Core

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

    [394873] = 20, -- Lightning Strike (Thundering, Environment)
    [396411] = 20, -- Primal Overload (Thundering, Environment)

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
    -- [385311] = 20, -- Thunderstorm (Primalist Shockcaster) - no indicator
    -- [392406] = 20, -- Thunderclap (Storm Warrior) - TODO probably not avoidable for melee
    [392399] = 20, -- Crackling Detonation (Primal Thundercloud)

    [384024] = 20, -- Hailbombs, Projectiles (Melidrussa Chillworm)
    [372863] = 20, -- Ritual of Blazebinding (Kokia Blazehoof)
    [372811] = 20, -- Molten Boulder, Projectile (Kokia Blazehoof)
    [372819] = 20, -- Molten Boulder, Explosion (Kokia Blazehoof)
    [372820] = 20, -- Scorched Earth (Kokia Blazehoof)
    [373087] = 20, -- Burnout (Blazebound Firestorm, Kokia Blazehoof)
    [381526] = 20, -- Roaring Firebreath (Kyrakka)
    [384773] = 20, -- Flaming Embers (Kyrakka)

    -- Neltharus
    [372459] = 20, -- Burning (Environment)
    [382708] = 20, -- Volcanic Guard (Qalashi Warden)
    [372583] = 20, -- Binding Spear, Impact (Qalashi Hunter)
    -- [373540] = 20, -- Binding Spear, periodic (Qalashi Hunter) - should this be tracked?
    [376186] = 20, -- Eruptive Crush, Area (Overseer Lahar)
    [383928] = 20, -- Eruptive Crush, Projectiles (Overseer Lahar)
    [395427] = 20, -- Burning Roar (Overseer Lahar)
    [372372] = 20, -- Magma Fist (Qalashi Trainee)
    [379410] = 20, -- Throw Lava (Qalashi Lavabearer)
    [372208] = 20, -- Djaradin Lava (Qalashi Lavabearer)
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
    [378055] = 20, -- Burst (Decaying Slime)
    [378054] = 20, -- Withering Away! (Decaying Slime)
    [374569] = 20, -- Burst (Monstrous Decay)
    [373943] = 20, -- Stomp (Wilted Oak)
    [385303] = 20, -- Teeth Trap (Environment)
    [385524] = 20, -- Sentry Fire (Environment)
    [385805] = 20, -- Violent Whirlwind (Stinkbreath)
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
    [387150] = 20, -- Frozen Ground (Telash Greywing)
    [384699] = 20, -- Crystalline Roar (Umbrelskul)
    [385078] = 20, -- Arcane Eruption (Umbrelskul)
    [385267] = 20, -- Crackling Vortex (Umbrelskul)

    -- Halls of Infusion
    [374075] = 20, -- Seismic Slam (Primalist Geomancer)
    [393444] = 20, -- Spear Flurry / Gushing Wound (Refti Defender)
    -- [374045] = 20, -- Expulse (Containment Apparatus) - no indicator
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
    [388546] = 20, -- Arcane Fissure, Swirly (Vexamus)
    [377034] = 20, -- Overpowering Gust (Crawth)
    [376449] = 20, -- Firestorm (Crawth)
    [393122] = 20, -- Roving Cyclone (Crawth)
    [388799] = 20, -- Germinate (Overgrown Ancient)
    [388625] = 20, -- Branch Out (Overgrown Ancient)
    [388822] = 20, -- Power Vacuum (Echo of Doragosa)
    [374361] = 20, -- Astral Breath (Echo of Doragosa)
    [389007] = 20, -- Arcane Rift / Wild Energy (Echo of Doragosa)
    [388996] = 20, -- Energy Eruption (Echo of Doragosa)

    -- Dawn of the Infinite: Galakrond's Fall
    [419447] = 20, -- Bronze Radiance (Environment)
    [419380] = 20, -- Timeline Conflux, small Swirlies (Environment)
    [419383] = 20, -- Timeline Conflux, big Swirlies (Environment)
    [412065] = 20, -- Timerip (Epoch Ripper)
    [414032] = 20, -- Errant Time (Environment)
    [413332] = 20, -- Sand Zone (Environment)
    [415773] = 20, -- Temporal Detonation (Interval)
    [413536] = 20, -- Untwist, Swirly (Timestream Anomaly)
    [413618] = 20, -- Timeless Curse (Infinite Infiltrator)
    [419526] = 20, -- Loose Time (Environment)
    [412810] = 20, -- Blight Spew (Risen Dragon)

    [401794] = 20, -- Withering Sandpool, Area (Chronikar)
    [403088] = 20, -- Eon Shatter (Chronikar)
    [405970] = 20, -- Eon Fragment (Chronikar)
    [403259] = 20, -- Residue Blast (Chronikar)
    [404650] = 20, -- Fragments of Time (Manifested Timeways)
    [407147] = 20, -- Blight Seep (Blight of Galakrond)
    [407027] = 20, -- Corrosive Expulsion (Blight of Galakrond)
    [408008] = 20, -- Necrotic Winds, Tornado (Ahnzon, Blight of Galakrond)
    [408177] = 20, -- Incinerating Blightbreath (Dazhak, Blight of Galakrond)
    [409287] = 20, -- Rending Earthspikes (Iridikron)
    [414376] = 20, -- Punctured Ground (Iridikron)
    [409642] = 20, -- Pulverizing Exhalation (Iridikron)
    [409969] = 20, -- Stone Dispersion (Iridikron)

    -- Dawn of the Infinite: Murozond's Rise
    [412137] = 20, -- Temporal Strike (Valow, Timesworn Keeper)
    [412131] = 20, -- Orb of Contemplation (Leirai, Timesworm Maiden)
    [412242] = 20, -- Shrouding Sandstorm, Hit (Spurlok, Timesworn Sentinel)
    [413618] = 20, -- Timeless Curse (Infinite Watchkeeper / Infinite Saboteur / Infinite Diversionist / Infinite Slayer)
    [419328] = 20, -- Infinite Schism, Swirlies (Timeline Marauder)
    [409038] = 20, -- Displacement (Infinite Protector / Infinite Warder, Bronze Temple Run)
    [413536] = 20, -- Untwist, Swirly (Timestream Anomaly)
    [411610] = 20, -- Bubbly Barrage (Time-Lost Waveshaper)
    [412225] = 20, -- Electro-Juiced Gigablast (Time-Lost Aerobot)
    [412181] = 20, -- Bombing Run (Time-Lost Aerobot)
    [413428] = 20, -- Time Beam, Swirlies (Pendule)
    [419517] = 20, -- Chronal Eruption (Chronaxie)
    [407312] = 20, -- Volatile Mortar (Alliance Destroyer / Horde Destroyer)
    [407315] = 20, -- Embers (Alliance Destroyer / Horde Destroyer)
    [407317] = 20, -- Shrapnel Shell (Alliance Destroyer / Horde Destroyer)
    [407313] = 20, -- Shrapnel (Alliance Destroyer / Horde Destroyer)
    [419629] = 20, -- Kaboom! (Dwarven Bomber)
    [407715] = 20, -- Kaboom! (Goblin Sapper)
    [407125] = 20, -- Sundering Slam (Alliance Knight / Horde Raider)
    [417002] = 20, -- Consecration (Paladin of the Silver Hand)
    [407906] = 20, -- Earthquake (Horde Farseer)
    [419526] = 20, -- Loose Time (Environment)

    [400597] = 20, -- Infinite Annihilation (Tyr, the Infinite Keeper)
    [403724] = 20, -- Consecrated Ground (Tyr, the Infinite Keeper)
    [404365] = 20, -- Dragon's Breath (Morchie)
    [413208] = 20, -- Sand Buffeted (Morchie)
    [412769] = 20, -- Anachronistic Decay (Familiar Face, Morchie)
    [410238] = 20, -- Bladestorm (Anduin Lothar / Grommash Hellscream, Time-Lost Battlefield)
    [418056] = 20, -- Shockwave (Anduin Lothar, Time-Lost Battlefield)
    [408228] = 20, -- Shockwave (Grommash Hellscream, Time-Lost Battlefield)
    [417026] = 20, -- Blizzard (Alliance Conjuror, Time-Lost Battlefield)
    [407123] = 20, -- Rain of Fire (Horde Warlock, Time-Lost Battlefield)
    [416265] = 20, -- Infinite Corruption, small Swirlies (Chrono-Lord Deios)
    [416266] = 20, -- Infinite Corruption, big Swirlies (Chrono-Lord Deios)
    [417413] = 20, -- Temporal Scar (Chrono-Lord Deios)

    -- Atal'Dazar
    [253654] = 20, -- Fiery Enchant (Dazar'ai Augur)
    [253666] = 20, -- Fiery Bolt (Dazar'ai Augur)
    [257692] = 20, -- Tiki Blaze (Environment)
    [256884] = 20, -- Wild Thrash (Monzumi)
    [258723] = 20, -- Grotesque Pool (Reanimated Honor Guard)
    [255620] = 20, -- Festering Eruption (Reanimated Honor Guard)

    [258709] = 20, -- Corrupted Gold (Priestess Alun'za)
    [255373] = 20, -- Tail (Rezan)
    [255445] = 20, -- Devour (Rezan)
    [250259] = 20, -- Toxic Leap (Vol'kaal)
    [250585] = 20, -- Toxic Pool (Vol'kaal)
    [250028] = 20, -- Echoes of Shadra, Swirly (Yazma)
    [263093] = 20, -- Echoes of Shadra, Swirly (Yazma)
    [250022] = 20, -- Echoes of Shadra, Explosion (Echoes of Shadra, Yazma)
    [263096] = 20, -- Echoes of Shadra, Explosion (Echoes of Shadra, Yazma)
    [250036] = 20, -- Shadowy Remains (Echoes of Shadra, Yazma)
    [263098] = 20, -- Shadowy Remains (Echoes of Shadra, Yazma)

    -- Waycrest Manor
    -- [278849] = 20, -- Uproot (Coven Thornshaper) - TODO probably not avoidable
    [264040] = 20, -- Uprooted Thorns (Coven Thornshaper)
    [264150] = 20, -- Shatter (Thornguard)
    [265757] = 20, -- Splinter Spike (Matron Bryndle)
    [264531] = 20, -- Shrapnel Trap (Maddened Survivalist)
    [271174] = 20, -- Retch (Pallid Gorger)
    [265407] = 20, -- Dinner Bell (Banquet Steward)

    [260570] = 20, -- Wildfire, Swirly (Soulbound Goliath)
    [260569] = 20, -- Wildfire, Area (Soulbound Goliath)
    [272669] = 20, -- Burning Fists (Burning Soul, Soulbound Goliath)
    [264923] = 20, -- Tenderize (Raal the Gluttonous)
    [264698] = 20, -- Rotten Expulsion, Impact (Raal the Gluttonous)
    [264712] = 20, -- Rotten Expulsion, Area (Raal the Gluttonous)
    [268234] = 20, -- Bile Explosion (Bile Oozeling, Raal the Gluttonous)
    [268387] = 20, -- Contagious Remnants (Lord Waycrest)
    [268308] = 20, -- Discordant Cadenza (Lady Waycrest)

    -- Black Rook Hold
    [200261] = 20, -- Bonebreaking Strike (Soul-Torn Champion / Commander Shendah'sohn)
    [200344] = 20, -- Arrow Barrage (Risen Archer)
    [200256] = 20, -- Phased Explosion (Arcane Minion)
    [222397] = 20, -- Boulder Crush (Environment)
    [201175] = 20, -- Throw Priceless Artifact (Wyrmtongue Scavenger)
    [200914] = 20, -- Indigestion (Wyrmtongue Scavenger)
    [201062] = 20, -- Bowled Over! (Wyrmtongue Scavenger)
    [214002] = 20, -- Raven's Dive (Risen Lancer)

    [196517] = 20, -- Swirling Scythe (Amalgam of Souls)
    [194960] = 20, -- Soul Echoes, Explosion (Lord Etheldrin Ravencrest / Amalgam of Souls)
    [194956] = 20, -- Reap Soul (Amalgam of Souls)
    [197521] = 20, -- Blazing Trail (Illysanna Ravencrest)
    [197821] = 20, -- Felblazed Ground (Illysanna Ravencrest)
    [197974] = 20, -- Bonecrushing Strike (Soul-Torn Vanguard, Illysanna Ravencrest)
    [198501] = 20, -- Fel Vomitus (Fel Bat, Smashspite the Hateful)
    [198781] = 20, -- Whirling Blade (Lord Kur'talos Ravencrest)
    [198820] = 20, -- Dark Blast (Latosius, Lord Kur'talos Ravencrest)
    [199567] = 20, -- Dark Obliteration (Image of Latosius, Lord Kur'talos Ravencrest)

    -- Darkheart Thicket
    [218759] = 20, -- Corruption Pool (Nightmare Abomination, Festerhide Grizzly / Archdruid Glaidalis) - TODO check ID of boss version
    [204402] = 20, -- Star Shower (Dreadsoul Ruiner)
    [201123] = 20, -- Root Burst (Vilethorn Blossom)
    [198916] = 20, -- Vile Burst (Rotheart Keeper)
    [212797] = 20, -- Hatespawn Detonation (Hatespawn Whelpling) - TODO removed?
    [201273] = 20, -- Blood Bomb (Bloodtainted Fury)
    [201227] = 20, -- Blood Assault (Bloodtainted Fury) - TODO is this avoidable for tanks?
    [201842] = 20, -- Curse of Isolation (Taintheart Summoner)

    [198408] = 20, -- Nightfall (Archdruid Glaidalis)
    [198386] = 20, -- Primal Rampage, Dash (Archdruid Glaidalis)
    [199063] = 20, -- Strangling Roots (Oakheart)
    [191326] = 20, -- Breath of Corruption (Dresaron)
    [199460] = 20, -- Falling Rocks (Dresaron) - TODO is first tick avoidable?
    [200329] = 20, -- Overwhelming Terror (Shade of Xavius)
    [200111] = 20, -- Apocalyptic Fire (Shade of Xavius)

    -- The Everbloom
    [172579] = 20, -- Bounding Whirl (Melded Berserker)
    [169495] = 20, -- Living Leaves (Gnarlroot)
    [426849] = 20, -- Cold Fusion (Infested Icecaller)
    [426982] = 20, -- Spatial Disruption (Addled Arcanomancer)

    [177734] = 20, -- Agitated Water (Witherbark)
    [164294] = 20, -- Unchecked Growth, Area (Witherbark)
    [427922] = 20, -- Cinderbolt Storm, Swirlies (Archmage Sol)
    [426991] = 20, -- Blazing Cinders (Archmage Sol)
    [428084] = 20, -- Glacial Fusion (Archmage Sol)
    [428148] = 20, -- Spatial Compression (Archmage Sol)
    [169179] = 20, -- Colossal Blow (Yalnu) - always does damage to party as well
    [428834] = 20, -- Verdant Eruption (Yalnu)
    [169930] = 20, -- Lumbering Swipe (Flourishing Ancient, Yalnu)

    [172643] = 20, -- Descend (Xeri'tac) - not part of M+
    [173081] = 20, -- Burst (Gorged Burster, Xeri'tac) - not part of M+
    [169223] = 20, -- Toxic Gas (Xeri'tac / Toxic Spiderling, Xeri'tac) - not part of M+

    -- Throne of the Tides
    [426685] = 20, -- Volatile Bolt (Naz'jar Ravager)
    [426688] = 20, -- Volatile Acid (Naz'jar Ravager)
    [426681] = 20, -- Electric Jaws (Environment) - TODO ID?
    [76590] = 20, -- Shadow Smash (Faceless Watcher)
    [426808] = 20, -- Null Blast (Faceless Seer)

    [427769] = 20, -- Geyser (Lady Naz'jar)
    [428048] = 20, -- Shock Orb (Lady Naz'jar)
    [428294] = 20, -- Trident Flurry (Naz'jar Honor Guard, Lady Naz'jar)
    [427565] = 20, -- Bubbling Fissure (Commander Ulthok)
    [427559] = 20, -- Bubbling Ooze (Commander Ulthok)
    [429057] = 20, -- Earthfury (Erunak Stonespeaker, Mindbender Ghur'sha)
    [429172] = 20, -- Terrifying Vision (Mindbender Ghur'sha)
    [428404] = 20, -- Blotting Darkness (Ink of Ozumat / Sludge, Ozumat)
    [428616] = 20, -- Deluge of Filth (Ozumat)
    [428618] = 20, -- Deluge of Filth (Ozumat)
    [428809] = 20 -- Gushing Ink (Sludge, Ozumat)
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
    -- [374544] = 20, -- Burst of Decay (Fetid Rotsinger) - TODO does this only target tank?
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

    -- Algeth'ar Academy
    [385958] = 20, -- Arcane Expulsion (Vexamus)

    -- Dawn of the Infinite: Galakrond's Fall
    [413532] = 20, -- Untwist, Frontal (Timestream Anomaly)
    [414304] = 20, -- Unwind (Manifested Timeways)
    [407159] = 20, -- Blight Reclamation (Blight of Galakrond)

    -- Dawn of the Infinite: Murozond's Rise
    [412505] = 20, -- Rending Cleave (Tyr's Vanguard)
    [419351] = 20, -- Bronze Exhalation (Infinite Saboteur / Infinite Slayer)
    [418092] = 20, -- Twisted Timeways (Environment) - TODO is this reasonable?
    [413532] = 20, -- Untwist, Frontal (Timestream Anomaly)
    [412029] = 20, -- Millennium Aid (Infinite Timebender)
    [417339] = 20, -- Titanic Blow (Tyr, the Infinite Keeper)
    [404917] = 20, -- Sand Blast (Morchie)
    [416139] = 20, -- Temporal Breath (Chrono-Lord Deios)

    -- Waycrest Manor
    [265372] = 20, -- Shadow Cleave (Enthralled Guard)

    -- Black Rook Hold
    [225909] = 20, -- Soul Venom (Rook Spiderling)

    -- Darkheart Thicket
    [200589] = 20, -- Festering Swipe (Festerhide Grizzly) - TODO removed?
    [200771] = 20, -- Propelling Charge (Crazed Razorbeak) - TODO is this avoidable for tanks?
    [198376] = 20, -- Primal Rampage, Frontal (Archdruid Glaidalis)
    [204667] = 20, -- Nightmare Breath (Oakheart)

    -- The Everbloom
    [164357] = 20, -- Parched Gasp (Witherbark)
    [427512] = 20, -- Noxious Charge (Dulhu, Ancient Protectors)
    [427513] = 20, -- Noxious Discharge (Dulhu, Ancient Protectors)
    [170411] = 20, -- Spore Breath (Infested Venomfang) - not part of M+
    [169371] = 20, -- Swipe (Venom-Crazed Pale One, Xeri'tac) - not part of M+
    [169267] = 20, -- Toxic Blood (Toxic Spiderling, Xeri'tac) - not part of M+

    -- Throne of the Tides
    [426645] = 20, -- Acid Barrage, Hit (Naz'jar Ravager)
    [426727] = 20, -- Acid Barrage, DoT (Naz'jar Ravager)
    [428530] = 20 -- Murk Spew (Ink of Ozumat, Ozumat)
}

local Auras = {
    -- Affixes
    [408777] = true, -- Entangled, Stun (Environment)

    -- Uldaman: Legacy of Tyr
    [372652] = true, -- Resonating Orb (Sentinel Talondras)

    -- The Azure Vault
    [386368] = true, -- Polymorphed (Polymorphic Rune, Environment)
    [396722] = true, -- Absolute Zero, Root (Telash Greywing)

    -- Dawn of the Infinite: Galakrond's Fall
    [418346] = true, -- Corrupted Mind (Blight of Galakrond)

    -- Dawn of the Infinite: Murozond's Rise
    [401667] = true, -- Time Stasis (Morchie)

    -- Atal'Dazar
    [257483] = true, -- Pile of Bones (Environment, Rezan)
    [255371] = true, -- Terrifying Visage (Rezan)

    -- Waycrest Manor
    [265352] = true, -- Toad Blight (Blight Toad)
    [278468] = true, -- Freezing Trap (Maddened Survivalist)

    -- Black Rook Hold
    [199097] = true, -- Cloud of Hypnosis (Dantalionax, Lord Kur'talos Ravencrest)

    -- Darkheart Thicket
    [200273] = true -- Cowardice (Shade of Xavius)
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
