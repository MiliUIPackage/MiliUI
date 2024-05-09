do
    local addonId = ...
    local languageTable = DetailsFramework.Language.RegisterLanguage(addonId, "frFR")
    local L = languageTable

------------------------------------------------------------
--[[Translation missing --]]
L["EXPORT"] = "Export"
--[[Translation missing --]]
L["EXPORT_CAST_COLORS"] = "Share Colors"
--[[Translation missing --]]
L["EXPORT_CAST_SOUNDS"] = "Share Sounds"
--[[Translation missing --]]
L["HIGHLIGHT_HOVEROVER"] = "Hover Over Highlight"
--[[Translation missing --]]
L["HIGHLIGHT_HOVEROVER_ALPHA"] = "Hover Over Highlight Alpha"
--[[Translation missing --]]
L["HIGHLIGHT_HOVEROVER_DESC"] = "Highlight effect when the mouse is over the nameplate."
--[[Translation missing --]]
L["IMPORT"] = "Import"
--[[Translation missing --]]
L["IMPORT_CAST_COLORS"] = "Import Colors"
--[[Translation missing --]]
L["IMPORT_CAST_SOUNDS"] = "Import Sounds"
L["OPTIONS_ALPHA"] = "Alpha"
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_ALPHAMULTIPLIER"] = "Transparency multiplier."
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_DEFAULT"] = "Default Transparency"
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_DEFAULT_DESC"] = "Amount of transparency applyed to all the components of a single nameplate."
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_ENABLE_ENEMIES"] = "Enable For Enemies"
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_ENABLE_ENEMIES_DESC"] = "Apply Transparency settings to enemy units."
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_ENABLE_FRIENDLY"] = "Enable For Friendly"
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_ENABLE_FRIENDLY_DESC"] = "Apply Transparency settings to friendly units."
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_TARGET_INRANGE"] = "Target Alpha/In-Range"
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_TARGET_INRANGE_DESC"] = "Transparency for targets or in-range units."
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_TITLE_ENEMIES"] = "Transparency Amount Per Frame (enemies)"
--[[Translation missing --]]
L["OPTIONS_ALPHABYFRAME_TITLE_FRIENDLY"] = "Transparency Amount Per Frame (friendly)"
--[[Translation missing --]]
L["OPTIONS_AMOUNT"] = "Amount"
L["OPTIONS_ANCHOR"] = "Ancre"
L["OPTIONS_ANCHOR_BOTTOM"] = "Bas"
L["OPTIONS_ANCHOR_BOTTOMLEFT"] = "En bas à gauche"
L["OPTIONS_ANCHOR_BOTTOMRIGHT"] = "En bas à droite"
L["OPTIONS_ANCHOR_CENTER"] = "Centre"
L["OPTIONS_ANCHOR_INNERBOTTOM"] = "Bas intérieur"
L["OPTIONS_ANCHOR_INNERLEFT"] = "Intérieur gauche"
L["OPTIONS_ANCHOR_INNERRIGHT"] = "Intérieur droit"
L["OPTIONS_ANCHOR_INNERTOP"] = "Haut intérieur"
L["OPTIONS_ANCHOR_LEFT"] = "A gauche"
L["OPTIONS_ANCHOR_RIGHT"] = "A droite"
--[[Translation missing --]]
L["OPTIONS_ANCHOR_TARGET_SIDE"] = "Which side this widget is attach to."
L["OPTIONS_ANCHOR_TOP"] = "Haut"
L["OPTIONS_ANCHOR_TOPLEFT"] = "En haut à gauche"
L["OPTIONS_ANCHOR_TOPRIGHT"] = "En haut à droite"
--[[Translation missing --]]
L["OPTIONS_AURA_DEBUFF_HEIGHT"] = "Debuff's icon height."
--[[Translation missing --]]
L["OPTIONS_AURA_DEBUFF_WITH"] = "Debuff's icon width."
--[[Translation missing --]]
L["OPTIONS_AURA_HEIGHT"] = "Debuff's icon height."
--[[Translation missing --]]
L["OPTIONS_AURA_SHOW_BUFFS"] = "Show Buffs"
--[[Translation missing --]]
L["OPTIONS_AURA_SHOW_BUFFS_DESC"] = "Show buffs on you on the Personal Bar."
--[[Translation missing --]]
L["OPTIONS_AURA_SHOW_DEBUFFS"] = "Show Debuffs"
--[[Translation missing --]]
L["OPTIONS_AURA_SHOW_DEBUFFS_DESC"] = "Show debuffs on you on the Personal Bar."
--[[Translation missing --]]
L["OPTIONS_AURA_WIDTH"] = "Debuff's icon width."
--[[Translation missing --]]
L["OPTIONS_AURAS_ENABLETEST"] = "Enable this to hide test auras shown when configuring."
--[[Translation missing --]]
L["OPTIONS_AURAS_SORT"] = "Sort Auras"
--[[Translation missing --]]
L["OPTIONS_AURAS_SORT_DESC"] = "Auras are sorted by time remaining (default)."
--[[Translation missing --]]
L["OPTIONS_BACKGROUND_ALWAYSSHOW"] = "Always Show Background"
--[[Translation missing --]]
L["OPTIONS_BACKGROUND_ALWAYSSHOW_DESC"] = "Enable a background showing the area of the clickable area."
--[[Translation missing --]]
L["OPTIONS_BORDER_COLOR"] = "Border Color"
--[[Translation missing --]]
L["OPTIONS_BORDER_THICKNESS"] = "Border Thickness"
--[[Translation missing --]]
L["OPTIONS_BUFFFRAMES"] = "Buff Frames"
L["OPTIONS_CANCEL"] = "Annuler"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_CHANNELING"] = "Channelled"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_INTERRUPTED"] = "Interrupted"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_REGULAR"] = "Regular"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_SUCCESS"] = "Success"
--[[Translation missing --]]
L["OPTIONS_CAST_COLOR_UNINTERRUPTIBLE"] = "Uninterruptible"
--[[Translation missing --]]
L["OPTIONS_CAST_SHOW_TARGETNAME"] = "Show Target Name"
--[[Translation missing --]]
L["OPTIONS_CAST_SHOW_TARGETNAME_DESC"] = "Show who is the target of the current cast (if the target exists)"
--[[Translation missing --]]
L["OPTIONS_CAST_SHOW_TARGETNAME_TANK"] = "[Tank] Don't Show Your Name"
--[[Translation missing --]]
L["OPTIONS_CAST_SHOW_TARGETNAME_TANK_DESC"] = "If you are a tank don't show the target name if the cast is on you."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_APPEARANCE"] = "Cast Bar Appearance"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_BLIZZCASTBAR"] = "Blizzard Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_COLORS"] = "Cast Bar Colors"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_ENABLED"] = "Enable Fade Animations"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_ENABLED_DESC"] = "Enable fade animations when the cast starts and stop."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_END"] = "On Stop"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_END_DESC"] = "When a cast ends, this is the amount of time the cast bar takes to go from 100% transparency to not be visible at all."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_START"] = "On Start"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_FADE_ANIM_TIME_START_DESC"] = "When a cast starts, this is the amount of time the cast bar takes to go from zero transparency to full opaque."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_HEIGHT"] = "Height of the cast bar."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_HIDE_ENEMY"] = "Hide Enemy Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_HIDE_FRIENDLY"] = "Hide Friendly Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_HIDEBLIZZARD"] = "Hide Blizzard Player Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_ICON_CUSTOM_ENABLE"] = "Enable Icon Customization"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_ICON_CUSTOM_ENABLE_DESC"] = "If this option is disabled, Plater won't modify the spell icon, leaving it for scripts to do."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_NO_SPELLNAME_LIMIT"] = "No Spell Name Length Limitation"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_NO_SPELLNAME_LIMIT_DESC"] = "Spell name text won't be cut to fit within the cast bar width."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_QUICKHIDE"] = "Quick Hide Cast Bar"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_QUICKHIDE_DESC"] = "After the cast finishes, immediately hide the cast bar."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPARK_HALF"] = "Half Spark"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPARK_HALF_DESC"] = "Show only half of the spark texture."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPARK_HIDE_INTERRUPT"] = "Hide Spark On Interrupt"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPARK_SETTINGS"] = "Spark Settings"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_SPELLICON"] = "Spell Icon"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_TOGGLE_TEST"] = "Toggle Cast Bar Test"
--[[Translation missing --]]
L["OPTIONS_CASTBAR_TOGGLE_TEST_DESC"] = "Start cast bar test, press again to stop."
--[[Translation missing --]]
L["OPTIONS_CASTBAR_WIDTH"] = "Width of the cast bar."
--[[Translation missing --]]
L["OPTIONS_CASTCOLORS_DISABLECOLORS"] = "Disable All Colors"
--[[Translation missing --]]
L["OPTIONS_CLICK_SPACE_HEIGHT"] = "The height of the are area which accepts mouse clicks to select the target"
--[[Translation missing --]]
L["OPTIONS_CLICK_SPACE_WIDTH"] = "The width of the are area which accepts mouse clicks to select the target"
L["OPTIONS_COLOR"] = "couleur"
--[[Translation missing --]]
L["OPTIONS_COLOR_BACKGROUND"] = "Background Color"
--[[Translation missing --]]
L["OPTIONS_CVAR_ENABLE_PERSONAL_BAR"] = "Personal Health and Mana Bars|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_CVAR_ENABLE_PERSONAL_BAR_DESC"] = [=[Shows a mini health and mana bars under your character.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
--[[Translation missing --]]
L["OPTIONS_CVAR_NAMEPLATES_ALWAYSSHOW"] = "Always Show Nameplates|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_CVAR_NAMEPLATES_ALWAYSSHOW_DESC"] = [=[Show nameplates for all units near you. If disabled only show relevant units when you are in combat.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
L["OPTIONS_ENABLED"] = "Activée"
L["OPTIONS_ERROR_CVARMODIFY"] = "les Cvars ne peuvent pas être changés en combat."
L["OPTIONS_ERROR_EXPORTSTRINGERROR"] = "erreur des chaines exportées"
--[[Translation missing --]]
L["OPTIONS_EXECUTERANGE"] = "Execute Range"
--[[Translation missing --]]
L["OPTIONS_EXECUTERANGE_DESC"] = [=[Show an indicator when the target unit is in 'execute' range.

If the detection does not work after a patch, communicate at Discord.]=]
--[[Translation missing --]]
L["OPTIONS_EXECUTERANGE_HIGH_HEALTH"] = "Execute Range (high heal)"
--[[Translation missing --]]
L["OPTIONS_EXECUTERANGE_HIGH_HEALTH_DESC"] = [=[Show the execute indicator for the high portion of the health.

If the detection does not work after a patch, communicate at Discord.]=]
L["OPTIONS_FONT"] = "Police de caractère"
--[[Translation missing --]]
L["OPTIONS_FORMAT_NUMBER"] = "Number Format"
L["OPTIONS_FRIENDLY"] = "Amical"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_ANCHOR_TITLE"] = "Apparence de la barre de santé"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_BGCOLOR"] = "Barre de Santé Couleur de Fond et Alpha"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_BGTEXTURE"] = "Texture de fond de la barre de santé"
L["OPTIONS_GENERALSETTINGS_HEALTHBAR_TEXTURE"] = "Texture de barre de santé"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_ANCHOR_TITLE"] = "La transparence est utilisée pour"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_RANGECHECK"] = "Vérification de la portée."
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_RANGECHECK_ALPHA"] = "Gamme de Transparence"
L["OPTIONS_GENERALSETTINGS_TRANSPARENCY_RANGECHECK_SPEC_DESC"] = "Sort vérifiant la distance avec cette spécialisation."
--[[Translation missing --]]
L["OPTIONS_HEALTHBAR"] = "Health Bar"
--[[Translation missing --]]
L["OPTIONS_HEALTHBAR_HEIGHT"] = "Health Bar Height"
--[[Translation missing --]]
L["OPTIONS_HEALTHBAR_SIZE_GLOBAL_DESC"] = [=[Change the size of Enemy and Friendly nameplates for players and npcs in combat and out of combat.

Each one of these options can be changed individually on Enemy Npc, Enemy Player tabs.]=]
--[[Translation missing --]]
L["OPTIONS_HEALTHBAR_WIDTH"] = "Health Bar Width"
--[[Translation missing --]]
L["OPTIONS_HEIGHT"] = "Height"
L["OPTIONS_HOSTILE"] = "Hostile"
--[[Translation missing --]]
L["OPTIONS_ICON_ELITE"] = "Elite Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_ENEMYCLASS"] = "Enemy Class Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_ENEMYFACTION"] = "Enemy Faction Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_ENEMYSPEC"] = "Enemy Spec Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_FRIENDLY_SPEC"] = "Friendly Spec Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_FRIENDLYCLASS"] = "Friendly Class"
--[[Translation missing --]]
L["OPTIONS_ICON_FRIENDLYFACTION"] = "Friendly Faction Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_PET"] = "Pet Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_QUEST"] = "Quest Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_RARE"] = "Rare Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_SHOW"] = "Show Icon"
--[[Translation missing --]]
L["OPTIONS_ICON_SIDE"] = "Show Side"
--[[Translation missing --]]
L["OPTIONS_ICON_SIZE"] = "Show Size"
--[[Translation missing --]]
L["OPTIONS_ICON_WORLDBOSS"] = "World Boss Icon"
--[[Translation missing --]]
L["OPTIONS_ICONROWSPACING"] = "Icon Row Spacing"
--[[Translation missing --]]
L["OPTIONS_ICONSPACING"] = "Icon Spacing"
--[[Translation missing --]]
L["OPTIONS_INDICATORS"] = "Indicators"
--[[Translation missing --]]
L["OPTIONS_INTERRUPT_FILLBAR"] = "Fill Cast Bar On Interrupt"
--[[Translation missing --]]
L["OPTIONS_INTERRUPT_SHOW_ANIM"] = "Play Interrupt Animation"
--[[Translation missing --]]
L["OPTIONS_INTERRUPT_SHOW_AUTHOR"] = "Show Interrupt Author"
--[[Translation missing --]]
L["OPTIONS_MINOR_SCALE_DESC"] = "Slightly adjust the size of nameplates when showing a minor unit (these units has a smaller nameplate by default)."
--[[Translation missing --]]
L["OPTIONS_MINOR_SCALE_HEIGHT"] = "Minor Unit Height Scale"
--[[Translation missing --]]
L["OPTIONS_MINOR_SCALE_WIDTH"] = "Minor Unit Width Scale"
--[[Translation missing --]]
L["OPTIONS_MOVE_HORIZONTAL"] = "Move horizontally."
--[[Translation missing --]]
L["OPTIONS_MOVE_VERTICAL"] = "Move vertically."
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_HIDE_FRIENDLY_HEALTH"] = "Hide Blizzard Health Bars|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_HIDE_FRIENDLY_HEALTH_DESC"] = [=[While in dungeons or raids, if friendly nameplates are enabled it'll show only the player name.
If any Plater module is disabled, this will affect these nameplates as well.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r

|cFFFF2200[*]|r |cFFa0a0a0A /reload may be required to take effect.|r]=]
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_OFFSET"] = "Slightly adjust the entire nameplate."
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_SHOW_ENEMY"] = "Show Enemy Nameplates|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_SHOW_ENEMY_DESC"] = [=[Show nameplate for enemy and neutral units.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_SHOW_FRIENDLY"] = "Show Friendly Nameplates|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATE_SHOW_FRIENDLY_DESC"] = [=[Show nameplate for friendly players.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
--[[Translation missing --]]
L["OPTIONS_NAMEPLATES_OVERLAP"] = "Nameplate Overlap (V)|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATES_OVERLAP_DESC"] = [=[The space between each nameplate vertically when stacking is enabled.

|cFFFFFFFFDefault: 1.10|r

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r

|cFFFFFF00Important |r: if you find issues with this setting, use:
|cFFFFFFFF/run SetCVar ('nameplateOverlapV', '1.6')|r]=]
--[[Translation missing --]]
L["OPTIONS_NAMEPLATES_STACKING"] = "Stacking Nameplates|cFFFF7700*|r"
--[[Translation missing --]]
L["OPTIONS_NAMEPLATES_STACKING_DESC"] = [=[If enabled, nameplates won't overlap with each other.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r

|cFFFFFF00Important |r: to set the amount of space between each nameplate see '|cFFFFFFFFNameplate Vertical Padding|r' option below.
Please check the Auto tab settings to setup automatic toggling of this option.]=]
L["OPTIONS_NEUTRAL"] = "Neutre"
--[[Translation missing --]]
L["OPTIONS_NOCOMBATALPHA_AMOUNT_DESC"] = "Amount of transparency for 'No Combat Alpha'."
--[[Translation missing --]]
L["OPTIONS_NOCOMBATALPHA_ENABLED"] = "Use No Combat Alpha"
--[[Translation missing --]]
L["OPTIONS_NOCOMBATALPHA_ENABLED_DESC"] = [=[Changes the nameplate alpha when you are in combat and the unit isn't.

|cFFFFFF00 Important |r:If the unit isn't in combat, it overrides the alpha from the range check.]=]
--[[Translation missing --]]
L["OPTIONS_NOESSENTIAL_DESC"] = [=[On updating Plater, it is common for the new version to also update scripts from the scripts tab.
This may sometimes overwrite changes made by the creator of the profile. The option below prevents Plater from modifying scripts when the addon receives an update.

Note: During major patches and bug fixes, Plater may still update scripts.]=]
--[[Translation missing --]]
L["OPTIONS_NOESSENTIAL_NAME"] = "Disable non-essential script updates during Plater version upgrades."
--[[Translation missing --]]
L["OPTIONS_NOESSENTIAL_SKIP_ALERT"] = "Skipped non-essential patch:"
--[[Translation missing --]]
L["OPTIONS_NOESSENTIAL_TITLE"] = "Skip Non Essential Script Patches"
--[[Translation missing --]]
L["OPTIONS_NOTHING_TO_EXPORT"] = "There's nothing to export."
L["OPTIONS_OKAY"] = "OK"
L["OPTIONS_OUTLINE"] = "Contour"
--[[Translation missing --]]
L["OPTIONS_PERSONAL_HEALTHBAR_HEIGHT"] = "Height of the health bar."
--[[Translation missing --]]
L["OPTIONS_PERSONAL_HEALTHBAR_WIDTH"] = "Width of the health bar."
--[[Translation missing --]]
L["OPTIONS_PERSONAL_SHOW_HEALTHBAR"] = "Show health bar."
--[[Translation missing --]]
L["OPTIONS_PET_SCALE_DESC"] = "Slightly adjust the size of nameplates when showing a pet"
--[[Translation missing --]]
L["OPTIONS_PET_SCALE_HEIGHT"] = "Pet Height Scale"
--[[Translation missing --]]
L["OPTIONS_PET_SCALE_WIDTH"] = "Pet Width Scale"
L["OPTIONS_PLEASEWAIT"] = "Cela peut ne prendra que quelques secondes"
--[[Translation missing --]]
L["OPTIONS_POWERBAR"] = "Power Bar"
--[[Translation missing --]]
L["OPTIONS_POWERBAR_HEIGHT"] = "Height of the power bar."
--[[Translation missing --]]
L["OPTIONS_POWERBAR_WIDTH"] = "Width of the power bar."
L["OPTIONS_PROFILE_CONFIG_EXPORTINGTASK"] = "Plater exporte le profil actuel"
L["OPTIONS_PROFILE_CONFIG_EXPORTPROFILE"] = "Exporter le profil"
L["OPTIONS_PROFILE_CONFIG_IMPORTPROFILE"] = "Importer le profil"
L["OPTIONS_PROFILE_CONFIG_MOREPROFILES"] = "Obtenez plus de profils sur Wago.io"
L["OPTIONS_PROFILE_CONFIG_OPENSETTINGS"] = "Ouvrir les paramètres du profil"
L["OPTIONS_PROFILE_CONFIG_PROFILENAME"] = "Nouveau nom de profil"
L["OPTIONS_PROFILE_CONFIG_PROFILENAME_DESC"] = "Un nouveau profil est créé avec la chaîne importée. L'insertion du nom d'un profil déjà existant le remplacera."
L["OPTIONS_PROFILE_ERROR_PROFILENAME"] = "Nom de profil invalide"
L["OPTIONS_PROFILE_ERROR_STRINGINVALID"] = "Fichier de profil non valide."
L["OPTIONS_PROFILE_ERROR_WRONGTAB"] = "Fichier de profil non valide. Importez des scripts ou des mods dans l’onglet Script."
L["OPTIONS_PROFILE_IMPORT_OVERWRITE"] = "Le profil  '%s' existe déjà, l'écraser ?"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NONE"] = "Nothing"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NONE_DESC"] = "No alpha modifications is applyed."
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGET"] = "Units Which Isn't Your Target"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGET_DESC"] = "When a nameplate isn't your current target, alpha is reduced."
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGETOUTOFRANGE"] = "Out of Range + Isn't Your Target"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_NOTMYTARGETOUTOFRANGE_DESC"] = [=[Reduces the alpha of units which isn't your target.
Reduces even more if the unit is out of range.]=]
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_OUTOFRANGE"] = "Units Out of Your Range"
--[[Translation missing --]]
L["OPTIONS_RANGECHECK_OUTOFRANGE_DESC"] = "When a nameplate is out of range, alpha is reduced."
--[[Translation missing --]]
L["OPTIONS_RESOURCES_TARGET"] = "Show Resources on Target"
--[[Translation missing --]]
L["OPTIONS_RESOURCES_TARGET_DESC"] = [=[Shows your resource such as combo points above your current target.
Uses Blizzard default resources and disables Platers own resources.

Character specific setting!]=]
--[[Translation missing --]]
L["OPTIONS_SCALE"] = "Scale"
--[[Translation missing --]]
L["OPTIONS_SCRIPTING_REAPPLY"] = "Re-Apply Default Values"
L["OPTIONS_SETTINGS_COPIED"] = "réglages copiés."
L["OPTIONS_SETTINGS_FAIL_COPIED"] = "n'a pas réussi à obtenir les paramètres de l'onglet actuellement sélectionné."
L["OPTIONS_SHADOWCOLOR"] = "Couleur de l'ombre"
--[[Translation missing --]]
L["OPTIONS_SHIELD_BAR"] = "Shield Bar"
--[[Translation missing --]]
L["OPTIONS_SHOW_CASTBAR"] = "Show cast bar"
--[[Translation missing --]]
L["OPTIONS_SHOW_POWERBAR"] = "Show power bar"
--[[Translation missing --]]
L["OPTIONS_SHOWOPTIONS"] = "Show Options"
--[[Translation missing --]]
L["OPTIONS_SHOWSCRIPTS"] = "Show Scripts"
--[[Translation missing --]]
L["OPTIONS_SHOWTOOLTIP"] = "Show Tooltip"
--[[Translation missing --]]
L["OPTIONS_SHOWTOOLTIP_DESC"] = "Show tooltip when hovering over the aura icon."
L["OPTIONS_SIZE"] = "Taille"
--[[Translation missing --]]
L["OPTIONS_STACK_AURATIME"] = "Show shortest time of stacked auras"
--[[Translation missing --]]
L["OPTIONS_STACK_AURATIME_DESC"] = "Show shortest time of stacked auras or the longes time, when disabled."
--[[Translation missing --]]
L["OPTIONS_STACK_SIMILAR_AURAS"] = "Stack Similar Auras"
--[[Translation missing --]]
L["OPTIONS_STACK_SIMILAR_AURAS_DESC"] = "Auras with the same name (e.g. warlock's unstable affliction debuff) get stacked together."
L["OPTIONS_STATUSBAR_TEXT"] = "Vous pouvez désormais importer des profils, des mods, des scripts, des animations et des tables de couleurs à partir de |cFFFFAA00http://wago.io|r"
L["OPTIONS_TABNAME_ADVANCED"] = "Avancé"
L["OPTIONS_TABNAME_ANIMATIONS"] = "Animations"
L["OPTIONS_TABNAME_AUTO"] = "Auto"
L["OPTIONS_TABNAME_BUFF_LIST"] = "Liste des Buffs"
L["OPTIONS_TABNAME_BUFF_SETTINGS"] = "Paramêtres des Buffs"
L["OPTIONS_TABNAME_BUFF_SPECIAL"] = "Buffs Spéciaux"
L["OPTIONS_TABNAME_BUFF_TRACKING"] = "Suivi des Buffs"
L["OPTIONS_TABNAME_CASTBAR"] = "Barre d'incantation"
L["OPTIONS_TABNAME_CASTCOLORS"] = "Couleurs et noms d'incantations"
L["OPTIONS_TABNAME_COMBOPOINTS"] = "Points de combo"
L["OPTIONS_TABNAME_GENERALSETTINGS"] = "Réglages généraux"
L["OPTIONS_TABNAME_MODDING"] = "Modding"
L["OPTIONS_TABNAME_NPC_COLORNAME"] = "Couleurs et noms des PNJ"
L["OPTIONS_TABNAME_NPCENEMY"] = "Ennemi Npc"
L["OPTIONS_TABNAME_NPCFRIENDLY"] = "Pnj Amical"
L["OPTIONS_TABNAME_PERSONAL"] = "Barre personnelle"
L["OPTIONS_TABNAME_PLAYERENEMY"] = "Joueur ennemi"
L["OPTIONS_TABNAME_PLAYERFRIENDLY"] = "Joueur amical"
L["OPTIONS_TABNAME_PROFILES"] = [=[Profils
]=]
L["OPTIONS_TABNAME_SCRIPTING"] = "Scripting"
L["OPTIONS_TABNAME_SEARCH"] = "Recherche"
L["OPTIONS_TABNAME_STRATA"] = "Niveau & strate"
L["OPTIONS_TABNAME_TARGET"] = "Cible"
L["OPTIONS_TABNAME_THREAT"] = "Menace / Aggro"
--[[Translation missing --]]
L["OPTIONS_TEXT_COLOR"] = "The color of the text."
--[[Translation missing --]]
L["OPTIONS_TEXT_FONT"] = "Font of the text."
--[[Translation missing --]]
L["OPTIONS_TEXT_SIZE"] = "Size of the text."
L["OPTIONS_TEXTURE"] = "Texture"
--[[Translation missing --]]
L["OPTIONS_TEXTURE_BACKGROUND"] = "Background Texture"
L["OPTIONS_THREAT_AGGROSTATE_ANOTHERTANK"] = "Aggro sur un autre Tank"
L["OPTIONS_THREAT_AGGROSTATE_HIGHTHREAT"] = "Menace élevée"
L["OPTIONS_THREAT_AGGROSTATE_NOAGGRO"] = "Pas d'aggro"
L["OPTIONS_THREAT_AGGROSTATE_NOTANK"] = "Pas d'Aggro du Tank"
L["OPTIONS_THREAT_AGGROSTATE_NOTINCOMBAT"] = "Unité pas en combat"
L["OPTIONS_THREAT_AGGROSTATE_ONYOU_LOWAGGRO"] = "L'Aggro est sur vous mais il est faible"
L["OPTIONS_THREAT_AGGROSTATE_ONYOU_LOWAGGRO_DESC"] = "L'unité vous attaque mais d'autres sont sur le point de prendre l'aggro."
L["OPTIONS_THREAT_AGGROSTATE_ONYOU_SOLID"] = "L'Aggro est sur vous"
L["OPTIONS_THREAT_AGGROSTATE_TAPPED"] = "Unité engagée"
--[[Translation missing --]]
L["OPTIONS_THREAT_CLASSIC_USE_TANK_COLORS"] = "Use Tank Threat Colors"
L["OPTIONS_THREAT_COLOR_DPS_ANCHOR_TITLE"] = "Couleur quand vous jouez en tant que DPS ou HEALER"
L["OPTIONS_THREAT_COLOR_DPS_HIGHTHREAT_DESC"] = "L'unité est sur le point de commencer à vous attaquer."
L["OPTIONS_THREAT_COLOR_DPS_NOAGGRO_DESC"] = "L'unité ne vous attaque pas."
L["OPTIONS_THREAT_COLOR_DPS_NOTANK_DESC"] = "L'unité ne vous attaque pas, vous ou un tank, et probablement un autre guérisseur ou dps de votre groupe."
L["OPTIONS_THREAT_COLOR_DPS_ONYOU_SOLID_DESC"] = "L'unité vous attaque."
L["OPTIONS_THREAT_COLOR_OVERRIDE_ANCHOR_TITLE"] = "Remplacer les couleurs par défaut."
L["OPTIONS_THREAT_COLOR_OVERRIDE_DESC"] = "Modifiez les couleurs par défaut définies par le jeu pour les unités neutres, hostiles et amicales. Pendant le combat, ces couleurs seront également remplacées si les couleurs de la menace sont autorisées à changer la couleur de la barre de vie."
L["OPTIONS_THREAT_COLOR_TANK_ANCHOR_TITLE"] = "Couleur lors de la lecture en tant que tank."
L["OPTIONS_THREAT_COLOR_TANK_ANOTHERTANK_DESC"] = "L'unité est en train d'être tankée par un autre tank de votre groupe"
L["OPTIONS_THREAT_COLOR_TANK_NOAGGRO_DESC"] = "L'unité n'a pas d'aggro sur vous."
L["OPTIONS_THREAT_COLOR_TANK_NOTINCOMBAT_DESC"] = "L'unité n'est pas en combat."
L["OPTIONS_THREAT_COLOR_TANK_ONYOU_SOLID_DESC"] = "L'unité vous attaque et vous avez un aggro solide."
L["OPTIONS_THREAT_COLOR_TAPPED_DESC"] = "Quand quelqu'un d'autre a revendiqué l'unité (lorsque vous ne recevez pas d'expérience ou de butin pour l'avoir tuée)."
L["OPTIONS_THREAT_DPS_CANCHECKNOTANK"] = "Vérifier si il n'y à pas d'Aggro du tank"
L["OPTIONS_THREAT_DPS_CANCHECKNOTANK_DESC"] = "Lorsque vous n'avez pas d'aggro comme soigneur ou dps, vérifiez si l'ennemi attaque une autre unité qui n'est pas un tank."
L["OPTIONS_THREAT_MODIFIERS_ANCHOR_TITLE"] = "La menace se modifie"
L["OPTIONS_THREAT_MODIFIERS_BORDERCOLOR"] = "Couleur de la bordure."
L["OPTIONS_THREAT_MODIFIERS_HEALTHBARCOLOR"] = "Couleur de la Barre de santé."
L["OPTIONS_THREAT_MODIFIERS_NAMECOLOR"] = "Nom de la couleur"
--[[Translation missing --]]
L["OPTIONS_THREAT_PULL_FROM_ANOTHER_TANK"] = "Pulling From Another Tank"
--[[Translation missing --]]
L["OPTIONS_THREAT_PULL_FROM_ANOTHER_TANK_TANK"] = "The unit has aggro on another tank and you're about to pull it."
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_AGGRO_FLASH"] = "Enable aggro flash"
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_AGGRO_FLASH_DESC"] = "Enables the -AGGRO- flash animation on the nameplates when gaining aggro as dps."
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_AGGRO_GLOW"] = "Enable aggro glow"
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_AGGRO_GLOW_DESC"] = "Enables the healthbar glow on the nameplates when gaining aggro as dps or losing aggro as tank."
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_SOLO_COLOR"] = "Solo Color"
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_SOLO_COLOR_DESC"] = "Use the 'Solo' color when not in a group."
--[[Translation missing --]]
L["OPTIONS_THREAT_USE_SOLO_COLOR_ENABLE"] = "Use 'Solo' color"
--[[Translation missing --]]
L["OPTIONS_TOGGLE_TO_CHANGE"] = "|cFFFFFF00 Important |r: hide and show nameplates to see changes."
--[[Translation missing --]]
L["OPTIONS_WIDTH"] = "Width"
L["OPTIONS_XOFFSET"] = "Décalage X"
--[[Translation missing --]]
L["OPTIONS_XOFFSET_DESC"] = [=[Adjust the position on the X axis.

*right click to type the value.]=]
L["OPTIONS_YOFFSET"] = "Décalage Y"
--[[Translation missing --]]
L["OPTIONS_YOFFSET_DESC"] = [=[Adjust the position on the Y axis.

*right click to type the value.]=]
--[[Translation missing --]]
L["TARGET_CVAR_ALWAYSONSCREEN"] = "Target Always on the Screen|cFFFF7700*|r"
--[[Translation missing --]]
L["TARGET_CVAR_ALWAYSONSCREEN_DESC"] = [=[When enabled, the nameplate of your target is always shown even when the enemy isn't in the screen.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
--[[Translation missing --]]
L["TARGET_CVAR_LOCKTOSCREEN"] = "Lock to Screen (Top Side)|cFFFF7700*|r"
--[[Translation missing --]]
L["TARGET_CVAR_LOCKTOSCREEN_DESC"] = [=[Min space between the nameplate and the top of the screen. Increase this if some part of the nameplate are going out of the screen.

|cFFFFFFFFDefault: 0.065|r

|cFFFFFF00 Important |r: if you're having issue, manually set using these macros:
/run SetCVar ('nameplateOtherTopInset', '0.065')
/run SetCVar ('nameplateLargeTopInset', '0.065')

|cFFFFFF00 Important |r: setting to 0 disables this feature.

|cFFFF7700[*]|r |cFFa0a0a0CVar, saved within Plater profile and restored when loading the profile.|r]=]
--[[Translation missing --]]
L["TARGET_HIGHLIGHT"] = "Target Highlight"
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_ALPHA"] = "Target Highlight Alpha"
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_COLOR"] = "Target Highlight Color"
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_DESC"] = "Highlight effect on the nameplate of your current target."
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_SIZE"] = "Target Highlight Size"
--[[Translation missing --]]
L["TARGET_HIGHLIGHT_TEXTURE"] = "Target Highlight Texture"
--[[Translation missing --]]
L["TARGET_OVERLAY_ALPHA"] = "Target Overlay Alpha"
--[[Translation missing --]]
L["TARGET_OVERLAY_TEXTURE"] = "Target Overlay Texture"
--[[Translation missing --]]
L["TARGET_OVERLAY_TEXTURE_DESC"] = "Used above the health bar when it is the current target."

end