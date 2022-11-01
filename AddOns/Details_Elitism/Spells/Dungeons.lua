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

    [342494] = 20, -- Belligerent Boast (Season 1 Prideful)
    [356414] = 20, -- Frost Lance (Season 2 Oros)
    [358894] = 20, -- Cold Snap (Season 2 Oros)
    [358897] = 20, -- Cold Snap (Season 2 Oros)
    [355806] = 20, -- Massive Smash (Season 2 Soggodon)
    [355737] = 20, -- Scorching Blast (Season 2 Arkolath)
    [355738] = 20, -- Scorching Blast DoT (Season 2 Arkolath)
    [366288] = 20, -- Force Slam (Season 3 Urh Dismantler)
    [366409] = 20, -- Fusion Beam (Season 3 Vy Interceptor)
    [373513] = 20, -- Shadow Eruption (Season 4 Zul'gamux)
    [373429] = 20, -- Carrion Swarm (Season 4 Nathrezim Infiltrator)

    -- Mists of Tirna Scithe
    [321968] = 20, -- Bewildering Pollen (Tirnenn Villager)
    [323137] = 20, -- Bewildering Pollen (Tirnenn Villager)
    [325027] = 20, -- Bramble Burst (Drust Boughbreaker)
    [326022] = 20, -- Acid Globule (Spinemaw Gorger)
    [340300] = 20, -- Tongue Lashing (Mistveil Gorgegullet)
    [340304] = 20, -- Poisonous Secretions (Mistveil Gorgegullet)
    [340311] = 20, -- Crushing Leap (Mistveil Gorgegullet)
    [331743] = 20, -- Bucking Rampage (Mistveil Guardian)
    [331748] = 20, -- Back Kick (Mistveil Guardian)
    [340160] = 20, -- Radiant Breath (Mistveil Matriarch)

    -- id ? [323177] = 20,        -- Tears of the Forest (Ingra Maloch)
    [323250] = 20, -- Anima Puddle (Droman Oulfarran)
    [321834] = 20, -- Dodge Ball (Mistcaller)
    [336759] = 20, -- Dodge Ball (Mistcaller)
    [321893] = 20, -- Freezing Burst (Mistcaller)
    [321828] = 20, -- Patty Cake (Mistcaller)
    [322655] = 20, -- Acid Expulsion (Tred'ova)
    [326309] = 20, -- Decomposing Acid (Tred'ova)
    [326263] = 20, -- Anima Shedding (Tred'ova)

    -- De Other Side
    [334051] = 20, -- Erupting Darkness (Death Speaker)
    [328729] = 20, -- Dark Lotus (Risen Cultist)
    [333250] = 20, -- Reaver (Risen Warlord)
    [342869] = 20, -- Enraged Mask (Enraged Spirit)
    [333790] = 20, -- Enraged Mask (Enraged Spirit)
    [332672] = 20, -- Bladestorm (Atal'ai Deathwalker)
    [323118] = 20, -- Blood Barrage (Hakkar the Soulflayer)
    [331933] = 20, -- Haywire (Defunct Dental Drill)
    [331398] = 20, -- Volatile Capacitor (Volatile Memory)
    [331008] = 20, -- Icky Sticky (Experimental Sludge)
    [323569] = 20, -- Spilled Essence (Environment - Son of Hakkar boss version)
    [332332] = 20, -- Spilled Essence (Environment - Son of Hakkar trash version)
    [323136] = 20, -- Anima Starstorm (Runestag Elderhorn)
    [345498] = 20, -- Anima Starstorm (Runestag Elderhorn)
    [340026] = 20, -- Wailing Grief (Mythresh, Sky's Talons)
    [332729] = 20, -- Malefic Blast (Environment - Dealer's Hallway)

    [324010] = 20, -- Eruption (Millificent Manastorm)
    [320723] = 20, -- Displaced Blastwave (Dealer Xy'exa)
    [320727] = 20, -- Displaced Blastwave (Dealer Xy'exa)
    [320232] = 20, -- Explosive Contrivance (Dealer Xy'exa)
    [334913] = 20, -- Master of Death (Mueh'zala)
    [325691] = 20, -- Cosmic Collapse (Mueh'zala)
    [335000] = 20, -- Stellar Cloud (Mueh'zala)

    -- Spires of Ascension
    -- [323786] = 20,        -- Swift Slice (Kyrian Dark-Praetor)
    [323740] = 20, -- Impact (Forsworn Squad-Leader)
    [336447] = 20, -- Crashing Strike (Forsworn Squad-Leader)
    [336444] = 20, -- Crescendo (Forsworn Helion)
    [328466] = 20, -- Charged Spear (Lakesis / Klotos)
    [336420] = 20, -- Diminuendo (Klotos / Lakesis)

    [331251] = 20, -- Deep Connection (Azules / Kin-Tara)
    [317626] = 20, -- Maw-Touched Venom (Azules)
    -- [321034] = 20,        -- Charged Spear (Kin-Tara) Cannot be avoided
    [324662] = 20, -- Ionized Plasma (Multiple) Can this be avoided?
    [324370] = 20, -- Attenuated Barrage (Kin-Tara)
    [324141] = 20, -- Dark Bolt (Ventunax)
    [323372] = 20, -- Empyreal Ordnance (Oryphrion)
    [323792] = 20, -- Anima Field (Oryphrion)
    [323943] = 20, -- Run Through (Devos)
    -- [] = 20,        -- Seed of the Abyss (Devos) ???

    -- The Necrotic Wake
    [324391] = 20, -- Frigid Spikes (Skeletal Monstrosity)
    [324381] = 20, -- Chill Scythe / Reaping Winds (Skeletal Monstrosity)
    [323957] = 20, -- Animate Dead (Zolramus Necromancer - summons Warrior)
    [324026] = 20, -- Animate Dead (Zolramus Necromancer - summons Crossbowman)
    [324027] = 20, -- Animate Dead (Zolramus Necromancer - summons Mage)
    [320574] = 20, -- Shadow Well (Zolramus Sorcerer)
    [333477] = 20, -- Gut Slice (Goregrind)
    [345625] = 20, -- Death Burst (Nar'zudah)
    [327240] = 20, -- Spine Crush (Loyal Creation)

    -- id ?[320637] = 20,        -- Fetid Gas (Blightbone)
    [319897] = 20, -- Land of the Dead (Amarth - summons Crossbowman)
    [319902] = 20, -- Land of the Dead (Amarth - summons Warrior)
    [333627] = 20, -- Land of the Dead (Amarth - summons Mage)
    [321253] = 20, -- Final Harvest (Amarth)
    [333489] = 20, -- Necrotic Breath (Amarth)
    [333492] = 20, -- Necrotic Ichor (Amarth apply by Necrotic Breath)
    [320365] = 20, -- Embalming Ichor (Surgeon Stitchflesh)
    [320366] = 20, -- Embalming Ichor (Surgeon Stitchflesh)
    [327952] = 20, -- Meat Hook (Stitchflesh)
    [327100] = 20, -- Noxious Fog (Stitchflesh)
    [328212] = 20, -- Razorshard Ice (Nalthor the Rimebinder)
    [320784] = 20, -- Comet Storm (Nalthor the Rimebinder)
    [321956] = 20, -- Comet Storm (Nalthor the Rimebinder) (this one is for Dark Exiled players)

    -- Plaguefall
    [320072] = 20, -- Toxic Pool (Decaying Flesh Giant)
    [330513] = 20, -- Doom Shroom DoT (Environment)
    [327552] = 20, -- Doom Shroom (Environment)
    -- id ?[335882] = 20,        -- Clinging Infestation (Fen Hatchling)
    [330404] = 20, -- Wing Buffet (Plagueroc)
    -- id ?[320040] = 20,        -- Plagued Carrion (Decaying Flesh Giant)
    [344001] = 20, -- Slime Trail (Environment)
    [318949] = 20, -- Festering Belch (Blighted Spinebreaker)
    [320576] = 20, -- Obliterating Ooze (Virulax Blightweaver)
    [319120] = 20, -- Putrid Bile (Gushing Slime)
    [327233] = 20, -- Belch Plague (Plagebelcher)
    [320519] = 20, -- Jagged Spines (Blighted Spinebreaker)
    [328501] = 20, -- Plague Bomb (Environment)
    [328986] = 20, -- Violent Detonation (Environment - Unstable Canister)
    [330135] = 20, -- Fount of Pestilence (Environment - Stradama's Slime)

    [324667] = 20, -- Slime Wave (Globgrog)
    [326242] = 20, -- Slime Wave DoT (Globgrog)
    [333808] = 20, -- Oozing Outbreak (Doctor Ickus)
    [329217] = 20, -- Slime Lunge (Doctor Ickus)
    [330026] = 20, -- Slime Lunge (Doctor Ickus)
    [322475] = 20, -- Plague Crash (Environment Margrave Stradama)

    -- Theater of Pain
    [342126] = 20, -- Brutal Leap (Dokigg the Brutalizer)
    [337037] = 20, -- Whirling Blade (Nekthara the Mangler) ?? TODO: Which one is correct?
    [336996] = 20, -- Whirling Blade (Nekthara the Mangler) ?? TODO: Which one is correct?
    [317605] = 20, -- Whirlwind (Nekthara the Mangler and Rek the Hardened)
    [332708] = 20, -- Ground Smash (Heavin the Breaker)
    [334025] = 20, -- Bloodthirsty Charge (Haruga the Bloodthirsty)
    [333301] = 20, -- Curse of Desolation (Nefarious Darkspeaker)
    [333297] = 20, -- Death Winds (Nefarious Darkspeaker)
    [331243] = 20, -- Bone Spikes (Soulforged Bonereaver)
    [331224] = 20, -- Bonestorm (Soulforged Bonereaver)
    [330592] = 20, -- Vile Eruption (back) (Rancid Gasbag)
    [330608] = 20, -- Vile Eruption (front) (Rancid Gasbag)
    [321039] = 20, -- Disgusting Burst (Disgusting Refuse and Blighted Sludge-Spewer)
    [321041] = 20, -- Disgusting Burst (Disgusting Refuse and Blighted Sludge-Spewer)

    [317231] = 20, -- Crushing Slam (Xav the Unfallen)
    [339415] = 20, -- Deafening Crash (Xav the Unfallen)
    [320729] = 20, -- Massive Cleave (Xav the Unfallen)
    [318406] = 20, -- Tenderizing Smash (Gorechop)
    [323406] = 20, -- Jagged Gash (Gorechop)
    -- id ?[323542] = 20,        -- Oozing (Gorechop)
    [317367] = 20, -- Necrotic Volley (Kul'tharok)
    [319639] = 20, -- Grasping Hands (Kul'tharok)
    [323681] = 20, -- Dark Devastation (Mordretha)
    [339550] = 20, -- Echo of Battle (Mordretha)
    [323831] = 20, -- Death Grasp (Mordretha)
    [339751] = 20, -- Ghostly Charge (Mordretha)

    -- Sanguine Depths
    [334563] = 20, -- Volatile Trap (Dreadful Huntmaster)
    [320991] = 20, -- Echoing Thrust (Regal Mistdancer)
    [320999] = 20, -- Echoing Thrust (Regal Mistdancer Mirror)
    [322418] = 20, -- Craggy Fracture (Chamber Sentinel)
    [334378] = 20, -- Explosive Vellum (Research Scribe)
    [323573] = 20, -- Residue (Fleeting Manifestation)
    [334615] = 20, -- Sweeping Slash (Head Custodian Javlin)
    [322212] = 20, -- Growing Mistrust (Vestige of Doubt)

    [328494] = 20, -- Sintouched Anima (Executor Tarvold)
    [325885] = 20, -- Anguished Cries (Z'rali)
    [323810] = 20, -- Piercing Blur (General Kaal)

    -- Halls of Atonement
    [325523] = 20, -- Deadly Thrust (Depraved Darkblade)
    [325799] = 20, -- Rapid Fire (Depraved Houndmaster)
    [326440] = 20, -- Sin Quake (Shard of Halkias)
    [326997] = 20, -- Powerful Swipe (Stoneborn Slasher)
    [326891] = 20, -- Anguish (Inquisitor Sigar)

    [322945] = 20, -- Heave Debris (Halkias)
    [324044] = 20, -- Refracted Sinlight (Halkias)
    [319702] = 20, -- Blood Torrent (Echelon)
    [319703] = 20, -- Blood Torrent (Echelon)
    [329340] = 20, -- Anima Fountain (High Adjudicator Aleez)
    [338013] = 20, -- Anima Fountain (High Adjudicator Aleez)
    [323126] = 20, -- Telekinetic Collision (Lord Chamberlain)
    [329113] = 20, -- Telekinteic Onslaught (Lord Chamberlain)
    [327885] = 20, -- Erupting Torment (Lord Chamberlain)
    [323236] = 20, -- Unleashed Suffering (Lord Chamberlain)

    -- Tazavesh: Streets of Wonder
    [355903] = 20, -- Disruption Grenade (Customs Security)
    [356011] = 20, -- Beam Splicer (Armored Overseer / Tracker Zo'Korss)
    [355306] = 20, -- Rift Blast (Portalmancer Zo'honn)
    [357019] = 20, -- Lightshard Retreat (Cartel Wiseguy)
    [355502] = 20, -- Shocklight Barrier (Environment)
    [355476] = 20, -- Shock Mines (Commander Zo'far)
    [355487] = 20, -- Lethal Force (Commander Zo'far)

    [348366] = 20, -- Armed Security (Zo'phex)
    [357799] = 20, -- Bounced! (Zo'gron)
    [350921] = 20, -- Crowd Control (Zo'gron)
    [356482] = 20, -- Rotten Food (Zo'gron)
    [346329] = 20, -- Spilled Liquids (P.O.S.T. Master)
    [349801] = 20, -- Grand Consumption (Alcruux)
    [349663] = 20, -- Grip of Hunger (Alcruux)
    [349999] = 20, -- Anima Detonation (Achillite) TODO avoidable?
    [351070] = 20, -- Venting Concussion (Achillite) TODO avoidable?
    [349989] = 20, -- Volatile Anima TODO verify
    [350090] = 20, -- Whirling Annihilation (Venza Goldfuse)
    [347481] = 20, -- Shuri (So'azmi)

    -- Tazavesh: So'leah's Gambit
    [355423] = 20, -- Volatile Pufferfish (Murkbrine Fishmancer)
    [355465] = 20, -- Boulder Throw (Coastwalker Goliath)
    [355581] = 20, -- Crackle (Stormforged Guardian)
    [355584] = 20, -- Charged Pulse (Stormforged Guardian)
    [356260] = 20, -- Tidal Burst (Hourglass Tidesage)
    [357228] = 20, -- Drifting Star (Adorned Starseer)

    -- [346828] = 20,    -- Sanitizing Field (Hylbrande) - more like a wipe mechanic
    [356796] = 20, -- Runic Feedback (Hylbrande)
    [346960] = 20, -- Purged by Fire (Hylbrande)
    [346961] = 20, -- Purging Field (Hylbrande)
    [347094] = 20, -- Titanic Crash (Hylbrande)
    [347149] = 20, -- Infinite Breath (Timecap'n Hooktail)
    [347370] = 20, -- Cannon Barrage (Timecap'n Hooktail)
    [358947] = 20, -- Burning Tar (Timecap'n Hooktail)
    [347151] = 20, -- Hook Swipe (Timecap'n Hooktail)
    [354334] = 20, -- Hook'd! (Timecap'n Hooktail)
    -- [?] = 20,            -- Deadly Seas (Timecap'n Hooktail) (oneshot from going in water, debuff?)
    [351101] = 20, -- Energy Fragmentation (So'leah)
    [351646] = 20, -- Hyperlight Nova (So'leah)

    -- Iron Docks
    [172963] = 20, -- Gatecrasher (Siegemaster Olugar / Siegemaster Rokra)
    [164632] = 20, -- Burning Arrows (Grom'kar Flameslinger)
    [173105] = 20, -- Whirling Chains (Grom'kar Chainmaster)
    [168514] = 20, -- Cannon Barrage (Environment)
    [168540] = 20, -- Cannon Barrage (Environment)
    [173113] = 20, -- Hatchet Toss (Grom'kar Deckhand) - TODO is this avoidable?
    [178299] = 20, -- High Explosive Grenade (Grom'kar Technician)
    [173149] = 20, -- Flaming Arrows (Grom'kar Flameslinger) - TODO is initial tick avoidable?
    [173351] = 20, -- Trampling Stampede (Rampaging Clefthoof) - TODO is this avoidable?
    [173324] = 20, -- Jagged Caltrops (Thunderlord Wrangler)
    [173517] = 20, -- Lava Blast (Ironwing Flamespitter)
    [173489] = 20, -- Lava Barrage (Ironwing Flamespitter)

    [164734] = 20, -- Shredding Swipes (Dreadfang)
    [163276] = 20, -- Shredded Tendons (Grimrail Enforcers)
    [163668] = 20, -- Flaming Slash (Grimrail Enforcers - Makogg Emberblade)
    [165152] = 20, -- Lava Sweep (Grimrail Enforcers - Makogg Emberblade)
    [163276] = 20, -- Ogre Traps (Grimrail Enforcers - Neesa Nox)
    [163379] = 20, -- Bombsquad (Grimrail Enforcers - Nessa Nox)
    [161256] = 20, -- Primal Assault (Oshir)
    [178157] = 20, -- Acid Spit (Oshir)
    [178156] = 20, -- Acid Splash (Oshir)
    [168148] = 20, -- Cannon Barrage (Skulloc)
    [168390] = 20, -- Cannon Barrage (Skulloc)
    [169129] = 20, -- Backdraft (Skulloc)
    [169132] = 20, -- Backdraft (Skulloc)

    -- Grimrail Depot
    [164188] = 20, -- Blackrock Bomb (Grimrail Bombardier)
    [176131] = 20, -- Cannon Barrage (Grom'kar Boomer)
    [160963] = 20, -- Blackrock Mortar (Grom'kar Boomer)
    [166676] = 20, -- Shrapnel Blast (Grom'kar Gunner)
    [176147] = 20, -- Ignite (Grom'kar Gunner)
    [176033] = 20, -- Flametongue (Grom'kar Cinderseer)
    [167038] = 20, -- Slag Tanker (Environmnet)
    [166404] = 20, -- Arcane Blitz (Grimrail Scout)
    [166340] = 20, -- Thunder Zone (Grom'kar Far Seer) - TODO is initial tick avoidable?
    [166380] = 20, -- Reckless Slash (Grom'kar Captain)

    [162513] = 20, -- VX18-B Target Eliminator (Railmaster Rocketspark)
    [163741] = 20, -- Blackrock Mortar (Nitrogg Thundertower)
    [161220] = 20, -- Suppressive Fire (Nitrogg Thundertower)
    [166570] = 20, -- Slag Blast (Nitrogg Thundertower)
    [156303] = 20, -- Shrapnel Blast (Grom'kar Gunner)
    [162065] = 20, -- Freezing Snare (Skylord Tovra)
    [162057] = 20, -- Spinning Spear (Skylord Tovra)
    [161588] = 20, -- Diffused Energy (Skylord Tovra)

    -- Return to Karazhan: Lower
    [228001] = 20, -- Pennies From Heaven (Ghostly Philanthropist)
    [227917] = 20, -- Poetry Slam (Ghostly Understudy)
    [227925] = 20, -- Final Curtain (Ghostly Understudy)
    [238606] = 20, -- Arcane Eruption (Arcane Warden)
    [228612] = 20, -- Burning Brand Explosion (Spectral Apprentice)
    -- [227966] = 20,      -- Flashlight (Skeletal Usher) - also dmg when turned away
    -- [227977] = 20,      -- Flashlight (Skeletal Usher) - also dmg when turned away, ID?
    [228603] = 20, -- Charge (Spectral Charger)
    [228833] = 20, -- Bone Shrapnel (Restless Bones)
    [229004] = 20, -- Arcane Orb (Arcanid)
    [228993] = 20, -- Caustic Pool (Coldmist Widow / Coldmist Stalker) - TODO is initial tick avoidable?

    [227568] = 20, -- Burning Leg Sweep (Toe Knee, Opera Hall: Westside Story)
    [227480] = 20, -- Flame Gale (Toe Knee, Opera Hall: Westside Story) - TODO is initial tick avoidable?
    [227799] = 20, -- Wash Away (Mrrgria, Opera Hall: Westside Story)
    [227434] = 20, -- Bubble Blast (Mrrgria, Opera Hall: Westside Story)
    [228221] = 20, -- Severe Dusting (Babblet, Opera Hall: Beautiful Beast)
    [228200] = 20, -- Burning Blaze (Luminore, Opera Hall: Beautiful Beast) - TODO ID?
    [228019] = 20, -- Leftovers (Mrs. Cauldrons, Opera Hall: Beautiful Beast) - TODO ID?
    [232144] = 20, -- Flashing Forks (Coggleston, Opera Hall: Beautiful Beast) - TODO is this avoidable? ID?
    [227776] = 20, -- Magic Magnificent (Galindre, Opera Hall: Wikket)
    [227416] = 20, -- Wondrous Radiance (Galindre, Opera Hall: Wikket)
    [227645] = 20, -- Spectral Charge (Midnight)
    [227339] = 20, -- Mezair (Midnight) - sometimes should not be avoided by tank
    [227651] = 20, -- Iron Whirlwind (Baron Rafe Dreuger)
    [227469] = 20, -- Whirling Edge Impact (Lord Robin Daris)
    [227473] = 20, -- Whirling Edge periodic (Lord Robin Daris)
    [227672] = 20, -- Will Breaker (Lord Crispin Ference)

    -- Return to Karazhan: Upper
    [229563] = 20, -- Knight Move (Knight)
    [229298] = 20, -- Knight Move Smash (Knight)
    [229545] = 20, -- White Bishop Move (Bishop)
    [229559] = 20, -- Black Bishop Move (Bishop)
    [229384] = 20, -- Queen Move (Queen)
    [229335] = 20, -- Rook Move Dash (Rook)
    [229568] = 20, -- Rook Move (Rook)
    [229427] = 20, -- Royal Slash (King)
    [242894] = 20, -- Unstable Energy (Damaged Golem)
    [229597] = 20, -- Fel Mortar (Fel Bat)
    [229623] = 20, -- Fel Breath (Fel Bat)
    [229682] = 20, -- Gleeful Immolation (Infused Pyromancer)
    [229988] = 20, -- Burning Tile (Environment)
    [229696] = 20, -- Stampede (Rat)

    [227285] = 20, -- Power Discharge Impact (The Curator)
    [227465] = 20, -- Power Discharge periodic (The Curator)
    [227806] = 20, -- Ceaseless Winter (Shade of Medivh)
    [227620] = 20, -- Arcane Bomb (Mana Devourer)
    [229248] = 20, -- Fel Beam (Command Ship, Viz'aduum the Watcher)
    [229250] = 20, -- Fel Flames (Command Ship, Viz'aduum the Watcher)
    [229285] = 20, -- Bombardment (Command Ship, Viz'aduum the Watcher)
    [229151] = 20, -- Disintegrate (Viz'aduum the Watcher)
    [229161] = 20, -- Explosive Shadows (Viz'aduum the Watcher)
    [229905] = 20, -- Soul Harvest (Viz'aduum the Watcher)
    [230067] = 20, -- Shadow Phlegm (Viz'aduum the Watcher)

    -- Operation: Mechagon - Junkyard
    [300659] = 20, -- Consuming Slime (Toxic Monstrosity)
    [300816] = 20, -- Slimewave (Slime Elemental)
    [300427] = 20, -- Shockwave (Scrapbone Bully)
    [300160] = 20, -- Gyro-Scrap (Heavy Scrapbot)
    [294890] = 20, -- Gyro-Scrap (Malfunctioning Scrapbot)
    [300129] = 20, -- Self-Destruct Protocol (Malfunctioning Scrapbot)
    [294894] = 20, -- Malfunction Sparks (Malfunctioning Scrapbot / HK-8 Aerial Oppression Unit)
    [300561] = 20, -- Explosion (Scrapbone Trashtosser)
    [299475] = 20, -- B.O.R.K (Scraphound)
    [299535] = 20, -- Scrap Blast (Pistonhead Blaster)
    [301680] = 20, -- Rapid Fire (Mechagon Cavalry)
    [301681] = 20, -- Charge (Mechagon Cavalry) - TODO does deal avoidable dmg, but Details does not show it?

    -- [298259] = 20, -- Gooped (Gunker) - should dmg be tracked for this?
    [297283] = 20, -- Cave In (King Gobbamak)
    [302681] = 20, -- Mega Taze (Trixie Tazer)
    [298947] = 20, -- Roadkill (Naeno Megacrash)
    [298588] = 20, -- Crash (Naeno Megacrash)
    [298940] = 20, -- Bolt Buster (Naeno Megacrash)
    [295552] = 20, -- Cannon Blast (HK-8 Aerial Oppression Unit)
    [302384] = 20, -- Static Discharge (HK-8 Aerial Oppression Unit)
    [296560] = 20, -- Clinging Static (HK-8 Aerial Oppression Unit)
    [296522] = 20, -- Self-Destruct (HK-8 Aerial Oppression Unit)
    [296150] = 20, -- Vent Blast (HK-8 Aerial Oppression Unit - Environment)

    -- Operation: Mechagon - Workshop
    [282943] = 20, -- Piston Smasher (Environment)
    [282945] = 20, -- Buzz Saw (Environment)
    [294128] = 20, -- Rocket Barrage (Rocket Tonk)
    [294073] = 20, -- Flying Peck (Strider Tonk)
    [294349] = 20, -- Volatile Waste (Living Waste)
    [301299] = 20, -- Furnace Flames (Environment)
    [293861] = 20, -- Anti-Personnel Squirrel (Anti-Personnel Squirrel)
    [294324] = 20, -- Mega Drill (Waste Processing Unit)
    [295168] = 20, -- Capacitor Discharge (Blastatron X-80)
    [293986] = 20, -- Sonic Pulse (Spider Tank / Blastatron X-80)
    [294058] = 20, -- High-Explosive Rockets (Spider Tank / Blastatron X-80)

    [285020] = 20, -- Whirling Edge (The Platinum Pummeler)
    [285377] = 20, -- B.4.T.T.L.3. Mine (Platinum Pummeler)
    [283422] = 20, -- Maximum Thrust (Gnomercy 4.U.)
    [291930] = 20, -- Air Drop (K.U-J.0.)
    [291953] = 20, -- Junk Bomb (K.U.-J.0.)
    [291949] = 20, -- Venting Flames (K.U-J.0.)
    [294954] = 20, -- Self-Trimming Hedge (Machinist's Garden)
    [285443] = 20, -- "Hidden" Flame Cannon (Machinist's Garden)
    [285460] = 20, -- Discom-BOMB-ulator (Machinist's Garden)
    [294869] = 20, -- Roaring Flame (Machinist's Garden)
    [291613] = 20, -- Take Off! (King Mechagon)
    [291915] = 20, -- Plasma Orb (King Mechagon)
    [291856] = 20 -- Recalibrate (King Mechagon)
}

local SpellsNoTank = {
    -- Mists of Tirna Scithe
    [331721] = 20, -- Spear Flurry (Mistveil Defender)

    -- De Other Side
    [332157] = 20, -- Spinning Up (Headless Client)

    -- Spires of Ascension
    [317943] = 20, -- Sweeping Blow (Frostsworn Vanguard)
    [324608] = 20, -- Charged Stomp (Oryphrion)

    -- The Necrotic Wake
    [324323] = 20, -- Gruesome Cleave (Skeletal Marauder)
    [323489] = 20, -- Throw Cleaver (Flesh Crafter / Stitching Assistant)

    -- Plaguefall
    -- Theater of Pain
    -- Sanguine Depths

    -- Halls of Atonement
    -- [323001] = 20,        -- Glass Shards (Halkias) This is always unavoidable for tanks but sometimes unavoidable for everyone
    [322936] = 20, -- Crumbling Slam (Halkias)
    [346866] = 20, -- Stone Breath (Loyal Stoneborn)

    -- Tazavesh: Streets of Wonder
    -- Tazavesh: So'leah's Gambit

    -- Iron Docks
    [172982] = 20, -- Shattering Strike (Siegemaster Olugar / Siegemaster Rokra)
    [167233] = 20, -- Bladestorm (Grom'kar Battlemaster / Pitwarden Gwarnok)
    [167516] = 20, -- Shrapnel Blast (Grom'kar Incinerator)
    [167815] = 20, -- Rending Cleave (Thunderlord Wrangler)
    [168401] = 20, -- Bladestorm (Koramar)

    -- Grimrail Depot
    [161089] = 20, -- Mad Dash (Borka the Brute)
    [164170] = 20, -- Dash (Grimrail Overseer) - always targets tank despite marker?
    [164163] = 20, -- Hewing Swipe (Grimrail Overseer)

    -- Return to Karazhan: Lower
    [99758] = 20, -- Flame Breath (Ancient Core Hound)
    [228637] = 20, -- Smash (Spectral Journeyman)
    [241774] = 20, -- Shield Smash (Phantom Guardsman)
    [29665] = 20, -- Cleave (Ghostly Chef)
    [228625] = 20, -- Banshee Wail (Wholesome Host / Wholesome Hostess)
    [228986] = 20, -- Web Spray (Coldmist Widow / Coldmist Stalker)
    [227493] = 20, -- Mortal Strike (Attumen the Huntsman)

    -- Return to Karazhan: Upper
    [230044] = 20, -- Cleave (Wrathguard Flamebringer)
    [229608] = 20, -- Mighty Swing (Erudite Slayer)

    -- Operation: Mechagon - Junkyard

    -- Operation: Mechagon - Workshop
    [294291] = 20 -- Process Waste (Waste Processing Unit)
}

local Auras = {
    -- Affixes
    [358973] = true, -- Wave of Terror (Season 2 Affix - Varruth)
    [373391] = true, -- Nightmare (Season 4 Affix - Nightmare Cloud)

    -- Mists of Tirna Scithe

    -- De Other Side
    [331381] = true, -- Slipped (Lubricator)
    [334505] = true, -- Shimmerdust Sleep (Weald Shimmermoth)

    -- Spires of Ascension
    [324205] = true, -- Blinding Flash (Ventunax)

    -- The Necrotic Wake
    [324293] = true, -- Rasping Scream (Skeletal Marauder)

    -- Plaguefall
    [330092] = true, -- Plaguefallen (Environment)
    [336301] = true, -- Web Wrap (Domina Venomblade)

    -- Theater of Pain
    -- Sanguine Depths
    -- Halls of Atonement
    -- Tazavesh: Streets of Wonder
    -- Tazavesh: So'leah's Gambit

    -- Iron Docks
    [164504] = true, -- Intimidated (Fleshrender Nok'gar)
    [172631] = true, -- Knocked Down (Slippery Grease, Grom'kar Technician)

    -- Grimrail Depot

    -- Return to Karazhan: Lower
    [228278] = true, -- Demoralizing Shout (Spectral Valet)
    [228578] = true, -- Lured (Wholesome Host / Wholesome Hostess)

    -- Return to Karazhan: Upper

    -- Operation: Mechagon - Junkyard
    [398529] = true, -- Gooped (Gunker)

    -- Operation: Mechagon - Workshop
    [285153] = true -- Foe Flipper (Gnomercy 4.U.)
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
