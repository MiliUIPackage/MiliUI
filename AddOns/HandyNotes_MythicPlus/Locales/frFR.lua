local myname, ns = ...

local L = LibStub("AceLocale-3.0"):NewLocale(myname, "frFR")
if not L then return end

-- Migration popup
L["Migration_text"] = "Ce message provient de |cff00aaffHandyNotes: MythicPlus|r, un addon que vous avez installé.\n\nAvec cet addon, je voulais proposer quelque chose de plus travaillé et d'utile à la communauté. Mais à l'époque je débutais dans la création d'addons, et j'ai appris en faisant.\n\nAujourd'hui, je peux enfin proposer quelque chose qui me plaît vraiment : |cffffd200%s|r.\n\nJ'aimerais beaucoup que vous l'essayiez."
L["Migration_btn_get"] = "Voir le nouvel addon"
L["Migration_url_text"] = "Copier le lien ci-dessous :"

L["AA_black_drake"] = "5% chance de Coup Critique"
L["AA_black_drake_desc"] = "Recruteur des dragons noirs"
L["AA_blue_drake"] = "584 points de Maitrise"
L["AA_blue_drake_desc"] = "Recruteur des dragons bleus"
L["AA_bronze_drake"] = "5% Hâte"
L["AA_bronze_drake_desc"] = "Recruteur des dragons de bronze"
L["AA_green_drake"] = "10% de soins reçus supplémentaires"
L["AA_green_drake_desc"] = "Recruteur des dragons verts"
L["AA_red_drake"] = "5% Polyvalence"
L["AA_red_drake_desc"] = "Recruteur des dragons rouges"
L["BH_cauldron"] = "Chaudron"
L["BH_cauldron_desc"] = "Ramassez le chaudron puis utilisez l'extra bouton pour supprimer un effet de maladie sur vous"
L["BH_gen_cauldron"] = "Utilisation des chaudrons"
L["BH_gen_cauldron_desc"] = "Un alchimiste avec 25 points de compétence peut activer le chaudron. Ensuite, les joueurs doivent interagir avec le chaudron pour acquérir une capacité supplémentaire qui peut supprimer une maladie."
L["BH_skip"] = "Skip"
L["BH_skip_desc"] = "Vous pouvez passer dans l'eau"
L["COS_percentage"] = "93.68% avant d'entrer dans le bâtiment de la mascarade, après avoir tué Talixae"
L["FH_percentage"] = "82.25% Avant le pont"
L["HOI_door"] = "La porte s'ouvre après la mort du premier boss"
L["HOI_mushroom"] = "Champignon"
L["HOI_mushroom_desc"] = "Un herboriste avec 25 points de compétence peut ramasser le champignon. Cela donne au groupe un buff de 30 minutes qui guérira un effet de poison ou de maladie toutes les 15 secondes."
L["HOI_shortcut_frog"] = "Raccourci vers Goliath gobeur (grenouille)"
L["HOI_shortcut_icelady"] = "Raccourci vers Khajin l'Inflexible (madame de glace)"
L["HOV_bjorn"] = "Roi Bjorn"
L["HOV_bjorn_desc"] = "Lance une dague sur une cible aléatoire"
L["HOV_haldor"] = "Roi Haldor"
L["HOV_haldor_desc"] = "Applique un saignement sur le tank pouvant s'empiler avec le temps"
L["HOV_percentage"] = "83.7% Avant d'emprunter le pont"
L["HOV_ranulf"] = "Roi Ranulf"
L["HOV_ranulf_desc"] = "Interrompre hurlement indiscipliné"
L["HOV_tor"] = "Roi Tor"
L["HOV_tor_desc"] = "Appel d'ancêtre, soigne le roi au contact (50% de sa barre de vie), doit être tué ou contrôlé"
L["NELT_percentage"] = "88.57% Requis avant le pont"
L["NELT_percentage_desc"] = "Vous pouvez compenser les quelques % manquant avec les mobs autour de la zone du boss final."
L["NO_percentage"] = "93.8% requis avant d'entrer dans la zone du boss"
L["Options"] = "Options"
L["RS_firedragon"] = "Gorge-de-feu"
L["RS_firedragon_desc"] = "Attention au souffle. Possède une aura de feu dont les dégâts augmentent avec le temps."
L["RS_thunderdragon"] = "Tête-tonnerre"
L["RS_thunderdragon_desc"] = "Attention au souffle. Place une magie sur deux membres du groupe au hasard en plus de faire de gros dégâts sur le tank."
L["Settings_desc"] = "Ces réglages modifient l'apparence des icônes"
L["Settings_iconalpha"] = "Transparence des icônes"
L["Settings_iconalpha_desc"] = "La transparence alpha des icônes"
L["Settings_Icons"] = "Réglage des icônes"
L["Settings_iconscale"] = "Taille des icônes"
L["Settings_iconscale_desc"] = "Modifie la taille des icônes"
L["ULD_mining"] = "Un Mineur avec 25 points de métier peut récolter le dépôt, donnant 10% de vitesse de déplacement hors combat par dépôt (3 au total, jusqu'à 30% de vitesse de déplacement)"
L["ULD_percentage"] = "57.22% Requis avant l'événement temporel"
L["UNDR_skip"] = "Vous pouvez utiliser le raccourci après la défaite du second boss"
L["VP_slipstream"] = "Utilisez le sillage pour vous téléporter sur l'autre marqueur"
L["VP_slipstream_desc1"] = "Après la défaite du Grand Vizier Ertan"
L["VP_slipstream_desc2"] = "Après la défaite d'Altairus"
L["MoTSD_shortcut"] = "Raccourci"
L["MoTSD_shortcut_desc"] = "Les Druides, Elfes de la Nuit, Taurens et Heboristes peuvent ouvrir le passage"
L["MoTSD_buff"] = "Amélioration"
L["MoTSD_buff_desc"] = "Les Druides, Elfes de la Nuit, Taurens et Heboristes peuvent ouvrir une zone avec des champignons (10% à toutes les caractéristiques)"
L["MoTSD_seed"] = "Point de contrôle"
L["MoTSD_seed_desc"] = "Un joueur peu cliquer sur la graine pour activer un point de résurection"
L["SV_buff"] = "Amélioration"
L["SV_buff_desc"] = "Les Guerriers, Nain et Forgerons peuvent donner une amélioration au groupe (10% polyvalence)"
L["CT_buff"] = "Amélioration"
L["CT_buff_desc"] = "Les Voleurs, Prêtres et Ingénieurs peuvent donner une amélioration au groupe (15% dégats et soins, ainsi que 50% de vitesse de déplacement)"
L["ARAK_buff"] = "Amélioration"
L["ARAK_buff_desc"] = "Les Tailleurs peuvent récupérer un sort supplémentaire qui assome une créature pendant 10 secondes, fonctionne sur les mini-boss avant l'araignée"

-------------------------------------------------------------------------------
-- Midnight — Donjons Legacy S1
-------------------------------------------------------------------------------

-- Siège du Triumvirat (SOT) — uiMapId 903
-- L["SOT_TODO"] = "TODO"

-- Orée-du-Ciel (SKY) — uiMapId 601/602
-- L["SKY_TODO"] = "TODO"

-- Fosse de Saron (POS) — uiMapId 184
-- L["POS_TODO"] = "TODO"

-------------------------------------------------------------------------------
-- Midnight — Nouveaux donjons S1
-------------------------------------------------------------------------------

-- Vallée de l'Aveuglement (BV) — uiMapId 2500
-- Boss : (TODO)
L["BV_buff"] = "Amélioration"
L["BV_buff_desc"] = "Les Herboristes (et peut-être Paladins/Prêtres) peuvent activer Foulée Épanouie : +20% vitesse de déplacement et +5% Hâte pendant 2 minutes"

-- Tanière de Nalorakk (DN) — uiMapId 2513
-- Boss : (TODO)
L["DN_buff_alchemy"] = "Encens Protecteur"
L["DN_buff_alchemy_desc"] = "Les Alchimistes de Minuit (compétence 25) et les Druides en forme d'ours peuvent brûler l'encens : +1% Polyvalence pendant 10 minutes pour tout le groupe"
L["DN_buff_rune"] = "Rune d'Ancrage"
L["DN_buff_rune_desc"] = "Les Elfes de la Nuit, Trolls et Druides en forme d'ours peuvent activer la rune : -50% de forces de déplacement pendant 15 minutes (utile pendant le mini-jeu des Vents Violents)"

-- Terrasse des Magistères (MT) — uiMapId 2520
-- Boss : Seranel Sunlash, Gemellus, Degentrius
L["MT_buff"] = "Empowerment Arcanique"
L["MT_buff_desc"] = "N'importe quel membre du groupe peut interagir avec le livre dans la bibliothèque : +5% Hâte pendant 30 minutes"

-- Cavernes de Maisara (MC) — uiMapId 2501
-- Boss : Muro'jin & Nekraxx, Vordaza, Rak'tul (Réceptacle des âmes)
-- Mécanique clé : interrompre les sorts d'absorption d'âme

-- Point-nexus Xenas (NPX) — uiMapId 2556
-- Boss : Chef Corewright Kasreth, Corewarden Nysarra, Lothraxion
L["NPX_tripwire"] = "Fils de détection arcaniques"
L["NPX_tripwire_desc"] = "Les Ingénieurs de Minuit (compétence 25) ou les Voleurs peuvent désactiver les fils de détection : supprime les étourdissements et dégâts du couloir"
L["NPX_conduit"] = "Surge de Noyau-Étincelle"
L["NPX_conduit_desc"] = "Se tenir sur un conduit octroie +5% Hâte par seconde (cumulable) — inflige des dégâts sur soi-même croissants avec le temps"

-- Flèche de Coursevent (WRS) — uiMapId 2492+
-- Boss : Emberdawn, Duo Délabré (Kalis & Latch), Commandant Kroluk, Le Cœur sans repos
L["WRS_speed_potion"] = "Potion de vitesse"
L["WRS_speed_potion_desc"] = "Consommer pour gagner 100% de vitesse de déplacement supplémentaire pendant 1 minute"
