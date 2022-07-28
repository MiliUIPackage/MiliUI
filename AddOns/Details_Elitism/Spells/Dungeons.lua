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
    [355234] = 20, -- Volatile Pufferfish (Murkbrine Fishmancer) TODO verify
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
    [351646] = 20 -- Hyperlight Nova (So'leah)
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
    [323489] = 20, -- Throw Cleaver (Flesh Crafter, Stitching Assistant)

    -- Plaguefall
    -- Theater of Pain
    -- Sanguine Depths

    -- Halls of Atonement
    -- [323001] = 20,        -- Glass Shards (Halkias) This is always unavoidable for tanks but sometimes unavoidable for everyone
    [322936] = 20, -- Crumbling Slam (Halkias)
    [346866] = 20 -- Stone Breath (Loyal Stoneborn)

    -- Tazavesh: Streets of Wonder
    -- Tazavesh: So'leah's Gambit
}

local Auras = {
    -- Mists of Tirna Scithe

    -- De Other Side
    [331381] = 20, -- Slipped (Lubricator)
    [334505] = 20, -- Shimmerdust Sleep (Weald Shimmermoth)

    -- Spires of Ascension
    [324205] = 20, -- Blinding Flash (Ventunax)

    -- The Necrotic Wake
    [324293] = 20, -- Rasping Scream (Skeletal Marauder)

    -- Plaguefall
    [330092] = 20, -- Plaguefallen (Environment)
    [336301] = 20, -- Web Wrap (Domina Venomblade)

    -- Theater of Pain
    -- Sanguine Depths
    -- Halls of Atonement

    -- Affixes
    [358973] = 20 -- Wave of Terror (Season 2 Affix - Varruth)

    -- Tazavesh: Streets of Wonder
    -- Tazavesh: So'leah's Gambit
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
