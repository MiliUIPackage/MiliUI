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
    -- [385186] = 20, -- Stink Breath (Stinkbreath) - TODO can targeted melee outrange?
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

    -- The Underrot
    [265540] = 20, -- Rotten Bile (Fetid Maggot)
    [265542] = 20, -- Rotten Bile (Fetid Maggot)
    [265019] = 20, -- Savage Cleave (Chosen Blood Matron)
    [278789] = 20, -- Wave of Decay (Living Rot)
    [265665] = 20, -- Foul Sludge (Living Rot)
    [265511] = 20, -- Spirit Drain (Spirit Drain Totem, Bloodsworn Defiler)
    [272609] = 20, -- Maddening Gaze (Faceless Corruptor)
    [272469] = 20, -- Abyssal Slam (Abyssal Reach, Faceless Corruptor)

    [261498] = 20, -- Creeping Rot (Elder Leaxa)
    [264757] = 20, -- Sanguine Feast (Elder Leaxa)
    [260312] = 20, -- Charge (Cragmaw the Infested)
    [259720] = 20, -- Upheaval (Sporecaller Zancha)
    -- [259714] = 20, -- Decaying Spores, Hit (Sporecaller Zancha) - might be necessary to eat
    [269843] = 20, -- Vile Expulsion, Impact (Unbound Abomination)
    [269838] = 20, -- Vile Expulsion, periodic (Unbound Abomination)
    [270108] = 20, -- Rotting Spore (Unbound Abomination)

    -- Freehold
    [258673] = 20, -- Azerite Grenade (Irontide Crackshot)
    [257426] = 20, -- Brutal Backhand (Irontide Enforcer)
    [258779] = 20, -- Sea Spout (Irontide Oarsman)
    [274400] = 20, -- Duelist Dash (Cutwater Duelist)
    [274389] = 20, -- Rat Traps (Vermin Trapper)
    [295945] = 20, -- Rat Traps (Vermin Trapper)
    [257757] = 20, -- Goin' Bananas (Bilge Rat Buccaneer)
    -- [257784] = 20, -- Frost Blast (Bilge Rat Brinescale) - TODO avoidable frontal or unavoidable AoE?
    [276061] = 20, -- Boulder Throw (Irontide Crusher)
    [258199] = 20, -- Ground Shatter (Irontide Crusher)
    [257737] = 20, -- Thundering Squall (Irontide Stormcaller)
    [257871] = 20, -- Blade Barrage (Irontide Buccaneer) - TODO is first tick avoidable?

    [258773] = 20, -- Charrrrrge (Sharkbait, Skycap'n Kragg)
    [257274] = 20, -- Vile Coating (Sharkbait, Skycap'n Kragg)
    [272046] = 20, -- Dive Bomb (Sharkbait, Skycap'n Kragg)
    [256594] = 20, -- Barrel Smash (Captain Raoul, Council o' Captains)
    [258352] = 20, -- Grapeshot (Captain Eudora, Council o' Captains)
    [267523] = 20, -- Cutting Surge (Captain Jolly, Council o' Captains) - not active in DF S2
    [272374] = 20, -- Whirlpool of Blades, Impact (Captain Jolly, Council o' Captains) - not active in DF S2
    [272397] = 20, -- Whirlpool of Blades, periodic (Captain Jolly, Council o' Captains) - not active in DF S2
    [278467] = 20, -- Caustic Freehold Brew (Rummy Mancomb, Council o' Captains)
    [257902] = 20, -- Shell Bounce (Ludwig Von Tortollan, Ring of Booty)
    [256546] = 20, -- Shark Tornado (Trothak, Ring of Booty)
    -- [256477] = 20, -- Shark Toss (Trothak, Ring of Booty) - TODO is this avoidable?
    [256552] = 20, -- Flailing Shark (Trothak, Ring of Booty)
    [256706] = 20, -- Rearm (Trothak, Ring of Booty)
    [257310] = 20, -- Cannon Barrage (Harlan Sweete)
    [257963] = 20, -- Cannon Barrage (Harlan Sweete) - TODO ID?
    [257308] = 20, -- Flaming Shrapnel (Harlan Sweete)
    [257460] = 20, -- Fiery Debris (Harlan Sweete)
    [413146] = 20, -- Swiftwind Saber (Harlan Sweete)
    [257293] = 20, -- Swiftwind Saber (Harlan Sweete) - TODO ID?
    [257315] = 20, -- Black Powder Bomb (Irontide Grenadier, Harlan Sweete)

    -- Neltharion's Lair
    [183407] = 20, -- Acid Splatter (Vileshard Crawler)
    [183465] = 20, -- Viscid Bile (Tarspitter Lurker)
    [226388] = 20, -- Rancid Ooze (Tarspitter Luker)
    [226287] = 20, -- Crush (Vileshard Chunk)
    [183088] = 20, -- Avalanche, Frontal (Mightstone Breaker)
    -- [183100] = 20, -- Avalanche, Rocks (Mightstone Breaker) - TODO is this avoidable?
    -- [226347] = 20, -- Stone Shatter (Stoneclaw Hunter / Stoneclaw Grubmaster) - TODO probably not avoidable for melee
    [186576] = 20, -- Petrifying Cloud (Petrifying Totem, Blightshard Shaper)
    [202089] = 20, -- Scorch (Burning Geode)
    -- [183566] = 20, -- Rancid Pool (Rotdrool Grabber, Stoneclaw Grubmaster) - not really avoidable

    [198028] = 20, -- Crystalline Ground (Rokmora)
    [188169] = 20, -- Razor Shards (Rokmora)
    [192800] = 20, -- Choking Dust (Blightshard Skitter, Rokmora)
    -- [193273] = 20, -- Falling Debris (Ularogg Cragshaper) - TODO is this avoidable?
    [198475] = 20, -- Strike of the Mountain (Ularogg Cragshaper)
    [210166] = 20, -- Toxic Retch, Area (Naraxas)
    [199705] = 20, -- Devouring (Naraxas)
    [200338] = 20, -- Crystal Spikes (Dargrul)
    [217090] = 20, -- Magma Wave, Initial (Dargrul)
    [200404] = 20, -- Magma Wave, Final (Dargrul)
    [216407] = 20, -- Lava Geyser (Dargrul)

    -- Vortex Pinnacle
    [410999] = 20, -- Pressurized Blast (Armored Mistral)
    -- [411001] = 20, -- Lethal Current (Lurking Tempest) - should this be considered avoidable?
    [411005] = 20, -- Bomb Cyclone (Cloud Prince)
    [88308] = 20, -- Chilling Breath (Young Storm Dragon / Altairus)
    [88963] = 20, -- Lightning Lash (Minister of Air)
    [413386] = 20, -- Overload Grounding Field (Minister of Air)

    [86292] = 20, -- Cyclone Shield / Cyclone Shield Fragment (Grand Vizier Ertan)
    [413319] = 20, -- Downwind of Altairus (Altairus)
    [413271] = 20, -- Downburst Impact (Altairus)
    [413296] = 20, -- Downburst, Ring (Altairus)
    [413275] = 20, -- Cold Front (Environment, Altairus)
    [87553] = 20, -- Supremacy of the Storm (Asaad)
    [87618] = 20 -- Static Cling (Asaad)
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

    -- The Underrot
    [260793] = 20, -- Indigestion (Cragmaw the Infested)
    [272457] = 20, -- Shockwave (Sporecaller Zancha)

    -- Neltharion's Lair
    [193505] = 20, -- Fracture (Vileshard Hulk)
    [226296] = 20, -- Piercing Shards (Vileshard Hulk)
    [226304] = 20, -- Piercing Shards (Vileshard Hulk)
    [226406] = 20, -- Ember Swipe (Emberhusk Dominator)
    [188494] = 20, -- Rancid Maw (Naraxas)
    [205609] = 20, -- Rancid Maw (Naraxas) - TODO ID?
    [200721] = 20 -- Landslide (Dargrul)
}

local Auras = {
    -- Affixes
    [408777] = true, -- Entangled, Stun (Environment)

    -- Uldaman: Legacy of Tyr
    [372652] = true, -- Resonating Orb (Sentinel Talondras)

    -- The Azure Vault
    [386368] = true, -- Polymorphed (Polymorphic Rune, Environment)
    [396722] = true, -- Absolute Zero, Root (Telash Greywing)

    -- Freehold
    [274516] = true, -- Slippery Suds (Bilge Rat Swabby)
    [272554] = true, -- Bloody Mess (Trothak, Ring of Booty)
    [268283] = true -- Obscured Vision (Booty Fanatic, Ring of Booty)
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
