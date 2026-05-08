local myname, ns = ...

local L = LibStub("AceLocale-3.0"):NewLocale(myname, "enUS", true)

L["Options"] = true
L["Settings_Icons"] = "Icon settings"
L["Settings_desc"] = "These settings control the look and feel of the icon."
L["Settings_iconscale"] = "Icon Scale"
L["Settings_iconscale_desc"] = "The scale of the icons"
L["Settings_iconalpha"] = "Icon Alpha"
L["Settings_iconalpha_desc"] ="The alpha transparency of the icons"

-- Migration popup
L["Migration_text"] = "This message is from |cff00aaffHandyNotes: MythicPlus|r, an addon you have installed.\n\nWith this addon, I wanted to offer something more polished and useful to the community. But I was new to addon development back then, and I learned by doing.\n\nToday, I can finally offer something I'm truly happy with: |cffffd200%s|r.\n\nI'd love for you to give it a try."
L["Migration_btn_get"] = "Get the new addon"
L["Migration_url_text"] = "Copy the link below:"

-- Halls of valor
L["HOV_percentage"] = "83.7 % Before bridge"
L["HOV_haldor"] =  "King Haldor"
L["HOV_haldor_desc"] = "Bleed on tank, stack"
L["HOV_tor"] =  "King Tor"
L["HOV_tor_desc"] = "Call ancestor, heal king on hit (50% max health), must be burn or CC"
L["HOV_bjorn"] =  "King Bjorn"
L["HOV_bjorn_desc"] = "Throw dagger at a random target"
L["HOV_ranulf"] =  "King Ranulf"
L["HOV_ranulf_desc"] = "Kick Unruly Yell"

-- Agelthar academy
L["AA_bronze_drake"] = "5% Haste"
L["AA_bronze_drake_desc"] = "Bronze Dragonflight Recruiter"
L["AA_red_drake"] = "5% Versatility"
L["AA_red_drake_desc"] = "Red Dragonflight Recruiter"
L["AA_green_drake"] = "10% Healing taken"
L["AA_green_drake_desc"] = "Green Dragonflight Recruiter"
L["AA_blue_drake"] = "Mastery points(584 rating)"
L["AA_blue_drake_desc"] = "Blue Dragonflight Recruiter"
L["AA_black_drake"] = "5% Critical Strike"
L["AA_black_drake_desc"] = "Black Dragonflight Recruiter"

-- Ruby Sanctum
L["RS_thunderdragon"] = "Thunderhead"
L["RS_thunderdragon_desc"] = "Warning: Breath"
L["RS_firedragon"] = "Flamegullet"
L["RS_firedragon_desc"] = "Warning: Breath"

-- Nokhud offensive
L["NO_percentage"] = "93.8 % For skip"

-- Court of stars
L["COS_percentage"] = "93.68% before entering the masquerade after killing Talixae"

-- Brackenhide Hollow (BH)
L["BH_skip"] = "Skip"
L["BH_skip_desc"] = "You can pass by walking/swimming in the water."
L["BH_gen_cauldron"] = "Cauldron usage"
L["BH_gen_cauldron_desc"] = "An alchemist with 25 skill points can activate the cauldron. Then players must interact with the cauldron to gain an additional ability that can remove a disease."
L["BH_cauldron"] = "Cauldron"
L["BH_cauldron_desc"] = "Pick the cauldron then use the extra button to clean any desease."

-- Freehold (FH)
L["FH_percentage"] = "82.25% Before Bridge"
-- Halls of Infusion (HOI)
L["HOI_door"] = "Opens after death of first boss"
L["HOI_shortcut_frog"] = "Shortcut to Gulping Goliath (frog)"
L["HOI_shortcut_icelady"] = "Shortcut to Khajin the Unyielding (ice lady)"
L["HOI_mushroom"] = "Mushroom"
L["HOI_mushroom_desc"] = "A herbalist with 25 skill points can collect the mushroom. This gives the party a 30 minute buff that will heal a poison or disease effect every 15 seconds."
-- Neltharion's Lair (NL)
-- Neltharus (NELT)
L["NELT_percentage"] = "88.57% Required before bridge"
L["NELT_percentage_desc"] = "You can compensate missing % by pulling mobs around the last boss area"
-- Uldaman: Legacy of Tyr (ULD)
L["ULD_percentage"] = "57.22% Before event"
L["ULD_mining"] = "A Miner with 25 skill points can mine the deposit, granting 10% out of combat movement speed per deposit (3 in total, up to 30% movement speed)"
-- The Underrot (UNDR)
L["UNDR_skip"] = "You can use the shortcut after the death of the second boss"
-- The Vortex Pinnacle (VP)
L["VP_slipstream"] = "Use the slipstream to teleport to the other marker"
L["VP_slipstream_desc1"] = "After defeat of Ertan"
L["VP_slipstream_desc2"] = "After defeat of Altairus"
-- Mists of Tirna Scithe (MoTS)
L["MoTSD_shortcut"] = "Shortcut"
L["MoTSD_shortcut_desc"] = "Druids, Night Elves, Taurens, and Herbalists can open a path"
L["MoTSD_buff"] = "Buff"
L["MoTSD_buff_desc"] = "Druids, Night Elves, Taurens, and Herbalists can open a zone with mushrooms (10% stat buff)"
L["MoTSD_seed"] = "Checkpoint"
L["MoTSD_seed_desc"] = "Anyone can click on the seed to enable checkpoint"
-- Stonevault (SV)
L["SV_buff"] = "Buff"
L["SV_buff_desc"] = "Warriors, Dwarves, and Blacksmiths can buff group (10% versatility)"
-- City of threads (CT)
L["CT_buff"] = "Buff"
L["CT_buff_desc"] = "Rogues, Priests, and Engineers can buff group (15% increase to DPS and HPS and a 50% increase to movement speed)"
-- Ara Kara (ARAK)
L["ARAK_buff"] = "Buff"
L["ARAK_buff_desc"] = "Tailoring get a on use 10 second stun that even works on the Shrilling Voice mini-bosses"

-------------------------------------------------------------------------------
-- Midnight — Legacy Dungeons (S1)
-------------------------------------------------------------------------------

-- The Seat of the Triumvirate (SOT) — uiMapId 903
-- L["SOT_TODO"] = "TODO"

-- Skyreach (SKY) — uiMapId 601/602
-- L["SKY_TODO"] = "TODO"

-- Pit of Saron (POS) — uiMapId 184
-- L["POS_TODO"] = "TODO"

-------------------------------------------------------------------------------
-- Midnight — New Dungeons (S1)
-------------------------------------------------------------------------------

-- The Blinding Vale (BV) — uiMapId 2500
-- Bosses: (TODO)
L["BV_buff"] = "Buff"
L["BV_buff_desc"] = "Herbalists (and possibly Paladins/Priests) can activate Flourishing Stride: 20% movement speed and 5% Haste for 2 minutes"

-- Den of Nalorakk (DN) — uiMapId 2513
-- Bosses: (TODO)
L["DN_buff_alchemy"] = "Warding Incense"
L["DN_buff_alchemy_desc"] = "Midnight Alchemists (skill 25) and Bear Form Druids can burn incense: +1% Versatility for 10 minutes for the whole party"
L["DN_buff_rune"] = "Rune of Anchoring"
L["DN_buff_rune_desc"] = "Night Elves, Trolls, and Bear Form Druids can activate: -50% movement forces for 15 minutes (useful during Harsh Winds mini-game)"

-- Magisters' Terrace (MT) — uiMapId 2520
-- Bosses: Seranel Sunlash, Gemellus, Degentrius
L["MT_buff"] = "Arcane Empowerment"
L["MT_buff_desc"] = "Anyone in the party can interact with the book in the library: +5% Haste for 30 minutes"

-- Maisara Caverns (MC) — uiMapId 2501
-- Bosses: Muro'jin & Nekraxx, Vordaza, Rak'tul (Vessel of Souls)
-- Key mechanic: interrupt soul-linking abilities

-- Nexus-Point Xenas (NPX) — uiMapId 2556
-- Bosses: Chief Corewright Kasreth, Corewarden Nysarra, Lothraxion
L["NPX_tripwire"] = "Arcane Tripwires"
L["NPX_tripwire_desc"] = "Midnight Engineers (skill 25) or Rogues can disable the tripwires: removes stuns and damage from the hallway"
L["NPX_conduit"] = "Corespark Surge"
L["NPX_conduit_desc"] = "Stand on a conduit to gain a stacking +5% Haste per second — causes self-damage that increases over time"

-- Windrunner Spire (WRS) — uiMapId 2492+
-- Bosses: Emberdawn, Derelict Duo (Kalis & Latch), Commander Kroluk, The Restless Heart
L["WRS_speed_potion"] = "Speed Boost Potion"
L["WRS_speed_potion_desc"] = "Consume to gain 100% increased movement speed for 1 minute"
