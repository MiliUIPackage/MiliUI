local CDM = _G["Ayije_CDM"]
local L = CDM:NewLocale("frFR")
if not L then return end

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Enabled Blizzard Cooldown Manager."] = "Gestionnaire de temps de recharge Blizzard activé."
--L["Config open queued until combat ends."] = "Config open queued until combat ends."
--L["Config open queued until login setup finishes."] = "Config open queued until login setup finishes."
L["Could not load options: %s"] = "Impossible de charger les options : %s"

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "Mode édition verrouillé"
L["use /acdm"] = "utilisez /acdm"
L["Edit Mode locked - use /acdm"] = "Mode édition verrouillé – utilisez /acdm"
L["Cooldown Viewer settings are managed by /acdm."] = "Les paramètres de la vue de temps de recharge sont gérés par /acdm."

-----------------------------------------------------------------------
-- Modules/BuffGroupOverlays.lua
-----------------------------------------------------------------------

--L["Ungrouped"] = "Ungrouped"

-----------------------------------------------------------------------
-- Modules/PlayerCastBar.lua
-----------------------------------------------------------------------

L["Preview Cast"] = "Aperçu d'incantation"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Init.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "Impossible d'ouvrir la configuration en combat"
L["Invalid profile data"] = "Données de profil invalides"
L["Copy this URL:"] = "Copiez cette URL :"
L["Close"] = "Fermer"
L["Reset the current profile to default settings?"] = "Réinitialiser le profil actuel aux paramètres par défaut ?"
L["Reset"] = "Réinitialiser"
L["Cancel"] = "Annuler"
L["Copy"] = "Copier"
L["Delete"] = "Supprimer"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "Impossible de %s en combat"
L["open CDM config"] = "ouvrir la configuration CDM"
L["Display"] = "Affichage"
L["Styling"] = "Style"
L["Buffs"] = "Améliorations"
L["Features"] = "Fonctionnalités"
L["Utility"] = "Utilitaire"
L["Cooldown Manager"] = "Gestionnaire de temps de recharge"
L["Settings"] = "Paramètres"
--L["Edit Mode Settings"] = "Edit Mode Settings"
L["rebuild CDM config"] = "reconstruire la configuration CDM"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "Essentiel"
L["Row 1 Width"] = "Largeur rangée 1"
L["Row 1 Height"] = "Hauteur rangée 1"
L["Row 2 Width"] = "Largeur rangée 2"
L["Row 2 Height"] = "Hauteur rangée 2"
L["Width"] = "Largeur"
L["Height"] = "Hauteur"
L["Buff"] = "Amélioration"
L["Icon Sizes"] = "Tailles des icônes"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Layout.lua
-----------------------------------------------------------------------

--L["Cooldowns"] = "Cooldowns"
--L["General"] = "General"
--L["Externals"] = "Externals"
--L["Cooldown Swipe"] = "Cooldown Swipe"
--L["Hide GCD Swipe"] = "Hide GCD Swipe"
--L["Swipe Color"] = "Swipe Color"
--L["Swipe Opacity"] = "Swipe Opacity"
L["Layout Settings"] = "Paramètres de disposition"
L["Icon Spacing"] = "Espacement des icônes"
L["Max Icons Per Row"] = "Icônes max. par rangée"
L["Wrap Utility Bar"] = "Diviser la barre utilitaire"
L["Utility Max Icons Per Row"] = "Icônes max. par rangée de la barre utilitaire"
L["Unlock Utility Bar"] = "Déverrouiller la barre utilitaire"
L["Utility X Offset"] = "Décalage X de la barre utilitaire"
L["Display Vertical"] = "Affichage vertical"
L["Layout"] = "Disposition"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Positions.lua
-----------------------------------------------------------------------

L["Current: %s (%d, %d)"] = "Actuel : %s (%d, %d)"
L["X Position"] = "Position X"
L["Y Position"] = "Position Y"
L["Essential Container Position"] = "Position du conteneur essentiel"
L["Utility Y Offset"] = "Décalage Y utilitaire"
L["Main Buff Container Position"] = "Position du conteneur d'améliorations principal"
L["Buff Bar Container Position"] = "Position du conteneur de barres d'améliorations"
L["Positions"] = "Positions"
--L["Buffs are currently anchored to resources"] = "Buffs are currently anchored to resources"
--L["Resources tab > Global"] = "Resources tab > Global"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "Paramètres de bordure"
L["Border Texture"] = "Texture de bordure"
L["Select Border..."] = "Sélectionner la bordure..."
L["Border Color"] = "Couleur de bordure"
L["Border Size"] = "Taille de bordure"
L["Border Offset X"] = "Décalage X de bordure"
L["Border Offset Y"] = "Décalage Y de bordure"
L["Zoom Icons"] = "Zoomer les icônes"
--L["Zoom Amount"] = "Zoom Amount"
--L["Remove Shadow Overlay"] = "Remove Shadow Overlay"
--L["Remove Default Icon Mask"] = "Remove Default Icon Mask"
L["Visual Elements"] = "Éléments visuels"
L["* These options require /reload to take effect"] = "* Ces options nécessitent /reload pour prendre effet"
L["Hide Debuff Border (red outline on harmful effects)"] = "Masquer la bordure de débuff (contour rouge sur les effets néfastes)"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "Masquer l'éclat de temps de recharge (animation flash à la fin du temps de recharge)"
--L["Pandemic Display"] = "Pandemic Display"
L["Hide Blizzard's Pandemic Indicator (animated refresh window border)"] = "Masquer l'indicateur pandémique de Blizzard (bordure animée de fenêtre de renouvellement)"
--L["Enable Pandemic Customization"] = "Enable Pandemic Customization"
--L["Custom Pandemic Border"] = "Custom Pandemic Border"
L["Color"] = "Couleur"
--L["Pandemic Glow"] = "Pandemic Glow"
--L["Charge Cooldowns"] = "Charge Cooldowns"
--L["Show Edge"] = "Show Edge"
--L["Hide Swipe"] = "Hide Swipe"
L["Borders"] = "Bordures"
--L["Look"] = "Look"
--L["Borders & Look"] = "Borders & Look"
--L["Hide Buff Swipe"] = "Hide Buff Swipe"
--L["Don't desaturate on cooldown"] = "Don't desaturate on cooldown"
--L["Hide recharge timer"] = "Hide recharge timer"
--L["Color Buff Bars Borders"] = "Color Buff Bars Borders"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Text.lua
-----------------------------------------------------------------------

L["None"] = "Aucun"
L["Outline"] = "Contour"
L["Thick Outline"] = "Contour épais"
L["Slug"] = "Slug"
L["Font"] = "Police"
L["Font Outline"] = "Contour de police"
L["Cooldown Timer"] = "Minuterie de temps de recharge"
--L["Cooldown Countdown Format"] = "Cooldown Countdown Format"
--L["Show decimals below (seconds, 0 = off)"] = "Show decimals below (seconds, 0 = off)"
--L["Threshold Color"] = "Threshold Color"
--L["Color countdown below threshold"] = "Color countdown below threshold"
--L["Threshold (seconds)"] = "Threshold (seconds)"
--L["Row 1 Font Size"] = "Row 1 Font Size"
--L["Row 2 Font Size"] = "Row 2 Font Size"
--L["Row 1 - Stacks (Charges)"] = "Row 1 - Stacks (Charges)"
L["Font Size"] = "Taille de police"
L["Position"] = "Position"
L["X Offset"] = "Décalage X"
L["Y Offset"] = "Décalage Y"
--L["Row 2 - Stacks (Charges)"] = "Row 2 - Stacks (Charges)"
--L["Stacks (Charges)"] = "Stacks (Charges)"
--L["Name Text"] = "Name Text"
L["Anchor"] = "Ancrage"
--L["Duration Text"] = "Duration Text"
--L["Stack Count Text"] = "Stack Count Text"
--L["Global"] = "Global"
--L["Buff Icons"] = "Buff Icons"
L["Buff Bars"] = "Barres d'améliorations"
L["Text"] = "Texte"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Glow.lua
-----------------------------------------------------------------------

L["Pixel Glow"] = "Lueur pixel"
L["Autocast Glow"] = "Lueur d'incantation auto."
L["Button Glow"] = "Lueur de bouton"
L["Proc Glow"] = "Lueur de proc"
L["Glow Settings"] = "Paramètres de lueur"
L["Glow Type"] = "Type de lueur"
L["Use Custom Color"] = "Utiliser une couleur personnalisée"
L["Glow Color"] = "Couleur de lueur"
L["Pixel Glow Settings"] = "Paramètres de lueur pixel"
L["Lines"] = "Lignes"
L["Frequency"] = "Fréquence"
L["Length (0=auto)"] = "Longueur (0=auto)"
L["Thickness"] = "Épaisseur"
--L["Border"] = "Border"
L["Autocast Glow Settings"] = "Paramètres de lueur d'incantation auto."
L["Particles"] = "Particules"
L["Scale"] = "Échelle"
L["Button Glow Settings"] = "Paramètres de lueur de bouton"
L["Frequency (0=default)"] = "Fréquence (0=défaut)"
L["Proc Glow Settings"] = "Paramètres de lueur de proc"
L["Duration (x10)"] = "Durée (x10)"
L["Glow"] = "Lueur"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "Fondu"
L["Enable Fading"] = "Activer le fondu"
L["Fade Triggers"] = "Déclencheurs de fondu"
L["Fade when no target"] = "Fondu sans cible"
L["Fade out of combat"] = "Fondu hors combat"
L["Fade when mounted"] = "Fondu sur monture"
L["Faded Opacity"] = "Opacité en fondu"
L["Apply Fading To"] = "Appliquer le fondu à"
L["Racials"] = "Raciaux"
L["Defensives"] = "Défensifs"
L["Trinkets"] = "Bijoux"
L["Resources"] = "Ressources"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Assist.lua
-----------------------------------------------------------------------

--L["Press Overlay"] = "Press Overlay"
--L["Enable Press Overlay"] = "Enable Press Overlay"
--L["Color Tint"] = "Color Tint"
--L["Tint Color"] = "Tint Color"
--L["Highlight"] = "Highlight"
L["Rotation Assist"] = "Aide à la rotation"
L["Enable Rotation Assist"] = "Activer l'aide à la rotation"
L["Highlight Size"] = "Taille de la surbrillance"
L["Keybindings"] = "Raccourcis clavier"
L["Enable Keybind Text"] = "Afficher le texte des raccourcis"
L["Assist"] = "Assistance"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/GroupEditorShared.lua
-----------------------------------------------------------------------

--L["Text Overrides"] = "Text Overrides"
--L["Override Text Settings"] = "Override Text Settings"
--L["Cooldown Size"] = "Cooldown Size"
--L["Cooldown Color"] = "Cooldown Color"
--L["Charge Size"] = "Charge Size"
--L["Charge Color"] = "Charge Color"
L["Current Spec"] = "Spécialisation actuelle"
--L["Grow Direction"] = "Grow Direction"
--L["Spacing"] = "Spacing"
L["Icon Width"] = "Largeur d'icône"
L["Icon Height"] = "Hauteur d'icône"
--L["Anchor To"] = "Anchor To"
--L["Anchor Point"] = "Anchor Point"
--L["Essential Viewer Point"] = "Essential Viewer Point"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/BuffGroups.lua
-----------------------------------------------------------------------

--L["Select a group or spell to edit settings"] = "Select a group or spell to edit settings"
--L["Static Display"] = "Static Display"
--L["Screen"] = "Screen"
--L["Player Frame"] = "Player Frame"
--L["Essential Viewer"] = "Essential Viewer"
--L["Buff Viewer"] = "Buff Viewer"
--L["Player Frame Point"] = "Player Frame Point"
--L["Buff Viewer Point"] = "Buff Viewer Point"
--L["Per-Spell Overrides"] = "Per-Spell Overrides"
--L["Hide Cooldown Timer"] = "Hide Cooldown Timer"
--L["Hide Icon"] = "Hide Icon"
--L["Show Placeholder"] = "Show Placeholder"
--L["Play Sound"] = "Play Sound"
--L["On Show"] = "On Show"
--L["On Hide"] = "On Hide"
--L["Text to Speech"] = "Text to Speech"
--L["Voice Settings"] = "Voice Settings"
--L["(empty = spell name)"] = "(empty = spell name)"
L["Unknown"] = "Inconnu"
L["Border:"] = "Bordure :"
--L["Right-click icon to reset border color"] = "Right-click icon to reset border color"
L["Enable Glow"] = "Activer la lueur"
L["Glow Color:"] = "Couleur de lueur :"
L["Spell ID:"] = "ID de sort :"
L["Duration (sec):"] = "Durée (sec.) :"
--L["Save"] = "Save"
L["Invalid spell ID"] = "ID de sort invalide"
L["Enter a valid duration"] = "Entrez une durée valide"
--L["Ungrouped Buffs"] = "Ungrouped Buffs"
--L["Add Spell to:"] = "Add Spell to:"
--L["Log %s to build spell list"] = "Log %s to build spell list"
--L["No untracked buff icons available for this spec"] = "No untracked buff icons available for this spec"
--L["All available icons are assigned to groups"] = "All available icons are assigned to groups"
--L["Add Custom Buff to:"] = "Add Custom Buff to:"
--L["Add Custom Buff"] = "Add Custom Buff"
--L["Quick Add"] = "Quick Add"
L["Add"] = "Ajouter"
--L["Custom Spell"] = "Custom Spell"
L["Add Spell"] = "Ajouter un sort"
L["Failed - invalid spell ID"] = "Échec – ID de sort invalide"
L["Added!"] = "Ajouté !"
--L["Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"] = "Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"
--L["Back"] = "Back"
--L["Add Group"] = "Add Group"
--L["Add Icon"] = "Add Icon"
--L["No ungrouped buffs"] = "No ungrouped buffs"
L["Rename"] = "Renommer"
--L["Duplicate"] = "Duplicate"
--L["Copy to"] = "Copy to"
--L["Delete group with %d spell(s)?"] = "Delete group with %d spell(s)?"
--L["Drag spells here"] = "Drag spells here"
L["Buff Groups"] = "Groupes d'améliorations"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CooldownGroups.lua
-----------------------------------------------------------------------

--L["Max Per Row"] = "Max Per Row"
--L["Utility Viewer"] = "Utility Viewer"
--L["Utility Viewer Point"] = "Utility Viewer Point"
--L["Show Aura Overlay"] = "Show Aura Overlay"
--L["Desaturate when inactive"] = "Desaturate when inactive"
--L["Aura Glow"] = "Aura Glow"
--L["Aura Border Color"] = "Aura Border Color"
--L["Border Color:"] = "Border Color:"
--L["Glow When Ready"] = "Glow When Ready"
--L["No untracked cooldown icons available for this spec"] = "No untracked cooldown icons available for this spec"
--L["All spells are in groups"] = "All spells are in groups"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ImportExport.lua
-----------------------------------------------------------------------

L["Invalid Base64 encoding"] = "Encodage Base64 invalide"
L["Decompression failed"] = "Échec de la décompression"
L["Invalid profile version"] = "Version de profil invalide"
L["Missing profile metadata"] = "Métadonnées de profil manquantes"
--L["Profile is for a different addon"] = "Profile is for a different addon"
L["No import string provided"] = "Aucune chaîne d'importation fournie"
L["Failed to import profile"] = "Échec de l'importation du profil"
--L["Select at least one category to export."] = "Select at least one category to export."
L["Profile is for a different addon: %s"] = "Le profil est destiné à un autre addon : %s"
L["Imported %d settings as '%s'"] = "%d paramètres importés en tant que '%s'"
L["Export Profile"] = "Exporter le profil"
L["Select categories to include, then click Export."] = "Sélectionnez les catégories à inclure, puis cliquez sur Exporter."
L["Export"] = "Exporter"
L["Export String (Ctrl+C to copy):"] = "Chaîne d'exportation (Ctrl+C pour copier) :"
L["Profile exported! Copy the string above."] = "Profil exporté ! Copiez la chaîne ci-dessus."
L["Export failed."] = "Échec de l'exportation."
L["Import Profile"] = "Importer le profil"
L["Paste an export string below and click Import."] = "Collez une chaîne d'exportation ci-dessous et cliquez sur Importer."
L["Import"] = "Importer"
L["Clear"] = "Effacer"
L["Import/Export"] = "Import/Export"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Profiles.lua
-----------------------------------------------------------------------

L["Already exists"] = "Existe déjà"
L["Enter a name"] = "Entrez un nom"
--L["Failed to apply profile"] = "Failed to apply profile"
--L["Profile not found"] = "Profile not found"
--L["Cannot copy active profile"] = "Cannot copy active profile"
--L["Cannot delete active profile"] = "Cannot delete active profile"
L["Current Profile"] = "Profil actuel"
L["New Profile"] = "Nouveau profil"
L["Create"] = "Créer"
L["Copy From"] = "Copier depuis"
L["Copy all settings from another profile into the current one."] = "Copier tous les paramètres d'un autre profil dans le profil actuel."
L["Select Source..."] = "Sélectionner la source..."
L["Manage"] = "Gérer"
L["Reset Profile"] = "Réinitialiser le profil"
L["Delete Profile..."] = "Supprimer le profil..."
L["Default Profile for New Characters"] = "Profil par défaut pour les nouveaux personnages"
L["Specialization Profiles"] = "Profils de spécialisation"
L["Auto-switch profile per specialization"] = "Changement auto. de profil par spécialisation"
L["Spec %d"] = "Spéc. %d"
L["Profiles"] = "Profils"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "Ajouter un sort ou objet personnalisé"
L["Spell"] = "Sort"
L["Item"] = "Objet"
L["Enter a valid ID"] = "Entrez un ID valide"
L["Loading item data, try again"] = "Chargement des données d'objet, réessayez"
L["Unknown spell ID"] = "ID de sort inconnu"
L["Added: %s"] = "Ajouté : %s"
L["Already tracked"] = "Déjà suivi"
L["Enable Racials"] = "Activer les raciaux"
--L["Show Items at 0 Stacks"] = "Show Items at 0 Stacks"
L["Tracked Spells"] = "Sorts suivis"
L["Manage Spells"] = "Gérer les sorts"
L["Icon Size"] = "Taille d'icône"
L["Party Frame Anchoring"] = "Ancrage au cadre de groupe"
L["Anchor to Party Frame"] = "Ancrer au cadre de groupe"
L["Side (relative to Party Frame)"] = "Côté (relatif au cadre de groupe)"
L["Party Frame X Offset"] = "Décalage X du cadre de groupe"
L["Party Frame Y Offset"] = "Décalage Y du cadre de groupe"
L["Anchor Position (relative to Player Frame)"] = "Position d'ancrage (relative au cadre du joueur)"
L["Cooldown"] = "Temps de recharge"
L["Stacks"] = "Cumuls"
L["Text Position"] = "Position du texte"
L["Text X Offset"] = "Décalage X du texte"
L["Text Y Offset"] = "Décalage Y du texte"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Defensives.lua
-----------------------------------------------------------------------

L["Add Custom Spell"] = "Ajouter un sort personnalisé"
L["Spell ID"] = "ID de sort"
L["Enter a valid spell ID"] = "Entrez un ID de sort valide"
L["Not available for spec"] = "Non disponible pour cette spécialisation"
L["Enable Defensives"] = "Activer les défensifs"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/EditModeOverlay.lua
-----------------------------------------------------------------------

--L["Compliant"] = "Compliant"
--L["Mismatched"] = "Mismatched"
--L["N/A"] = "N/A"
--L["Active layout is a preset. Switch to or create a custom layout to save changes."] = "Active layout is a preset. Switch to or create a custom layout to save changes."
--L["Apply"] = "Apply"
--L["All settings are correct"] = "All settings are correct"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Trinkets.lua
-----------------------------------------------------------------------

--L["Trinket Blacklist"] = "Trinket Blacklist"
--L["Add Item"] = "Add Item"
--L["Item ID"] = "Item ID"
--L["(loading...)"] = "(loading...)"
--L["Enter a valid item ID"] = "Enter a valid item ID"
--L["Unknown item ID"] = "Unknown item ID"
--L["Already blacklisted"] = "Already blacklisted"
L["Independent"] = "Indépendant"
L["Append to Defensives"] = "Ajouter aux défensifs"
L["Append to Spells"] = "Ajouter aux sorts"
L["Row 1"] = "Rangée 1"
L["Row 2"] = "Rangée 2"
L["Start"] = "Début"
L["End"] = "Fin"
L["Enable Trinkets"] = "Activer les bijoux"
--L["Manage Blacklist"] = "Manage Blacklist"
L["Layout Mode"] = "Mode de disposition"
L["Display Mode"] = "Mode d'affichage"
L["Row"] = "Rangée"
L["Position in Row"] = "Position dans la rangée"
L["Show Passive Trinkets"] = "Afficher les bijoux passifs"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources_Conditions.lua
-----------------------------------------------------------------------

L["Mana"] = "Mana"
L["Rage"] = "Rage"
L["Energy"] = "Énergie"
L["Focus"] = "Focalisation"
L["Combo Points"] = "Points de combo"
--L["Runes"] = "Runes"
L["Runic Power"] = "Puissance runique"
L["Soul Shards"] = "Éclats d'âme"
L["Astral Power"] = "Puissance astrale"
L["Holy Power"] = "Puissance sacrée"
L["Maelstrom"] = "Maelström"
L["Chi"] = "Chi"
L["Insanity"] = "Démence"
L["Arcane Charges"] = "Charges d'arcanes"
L["Fury"] = "Fureur"
L["Essence"] = "Essence"
L["Soul Fragments"] = "Fragments d'âme"
--L["Stagger"] = "Stagger"
--L["Maelstrom Weapon"] = "Maelstrom Weapon"
--L["Devourer Souls"] = "Devourer Souls"
--L["Ironfur"] = "Ironfur"
--L["Ignore Pain"] = "Ignore Pain"
--L["Tip of the Spear"] = "Tip of the Spear"
--L["Always"] = "Always"
--L["Power Value"] = "Power Value"
--L["Power %"] = "Power %"
--L["Power Full"] = "Power Full"
--L["Specialization"] = "Specialization"
--L["Pip Recharging"] = "Pip Recharging"
--L["All"] = "All"
--L["Pip"] = "Pip"
--L["Is Full"] = "Is Full"
--L["Is Not Full"] = "Is Not Full"
--L["Is Recharging"] = "Is Recharging"
--L["Is Not Recharging"] = "Is Not Recharging"
--L["Rule"] = "Rule"
--L["Target:"] = "Target:"
--L["If:"] = "If:"
--L["Else If:"] = "Else If:"
--L["+ Add Check"] = "+ Add Check"
--L["Then:"] = "Then:"
--L["Alpha"] = "Alpha"
L["Bar Color"] = "Couleur de barre"
L["Background"] = "Arrière-plan"
--L["Tag Color"] = "Tag Color"
--L["+ Add Rule"] = "+ Add Rule"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources_Load.lua
-----------------------------------------------------------------------

--L["Never"] = "Never"
--L["Conditional"] = "Conditional"
--L["Don't care"] = "Don't care"
--L["In Combat"] = "In Combat"
--L["Out of Combat"] = "Out of Combat"
--L["Load Mode"] = "Load Mode"
--L["Combat"] = "Combat"
--L["Hide when mounted"] = "Hide when mounted"
--L["Hide out of human form"] = "Hide out of human form"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources.lua
-----------------------------------------------------------------------

L["Warrior"] = "Guerrier"
L["Paladin"] = "Paladin"
L["Hunter"] = "Chasseur"
L["Rogue"] = "Voleur"
L["Priest"] = "Prêtre"
L["Death Knight"] = "Chevalier de la mort"
L["Shaman"] = "Chaman"
L["Mage"] = "Mage"
L["Warlock"] = "Démoniste"
L["Monk"] = "Moine"
L["Druid"] = "Druide"
L["Demon Hunter"] = "Chasseur de démons"
L["Evoker"] = "Évocateur"
--L["Recharging"] = "Recharging"
--L["Partial Fill"] = "Partial Fill"
L["Charged"] = "Charged"
L["Charged Empty"] = "Charged Empty"
--L["Overflowing"] = "Overflowing"
--L["Overflowing Empty"] = "Overflowing Empty"
--L["Ticks"] = "Ticks"
--L["Show Tick"] = "Show Tick"
--L["Tick Color"] = "Tick Color"
--L["Tick Placement"] = "Tick Placement"
L["Enable Resources"] = "Activer les ressources"
--L["Conditions"] = "Conditions"
--L["Load"] = "Load"
--L["Select a resource bar to configure"] = "Select a resource bar to configure"
--L["Copy settings from..."] = "Copy settings from..."
L["Width (0 = Auto)"] = "Largeur (0 = Auto)"
--L["Colors"] = "Colors"
--L["Base Color"] = "Base Color"
--L["Bar Ceiling (% HP)"] = "Bar Ceiling (% HP)"
--L["Tier %d"] = "Tier %d"
--L["Enabled"] = "Enabled"
--L["Threshold (% HP)"] = "Threshold (% HP)"
--L["Textures"] = "Textures"
L["Bar Texture:"] = "Texture de barre :"
L["Background Texture:"] = "Texture d'arrière-plan :"
--L["Smooth Fill"] = "Smooth Fill"
--L["Anchor To:"] = "Anchor To:"
L["Bar Spacing"] = "Espacement de barre"
--L["Stack Direction:"] = "Stack Direction:"
--L["Below"] = "Below"
--L["Above"] = "Above"
--L["Right of"] = "Right of"
--L["Left of"] = "Left of"
--L["Bar Anchor Point:"] = "Bar Anchor Point:"
--L["Target Point:"] = "Target Point:"
--L["Tag (Value Text)"] = "Tag (Value Text)"
--L["Enable Tag"] = "Enable Tag"
--L["Show aura time"] = "Show aura time"
L["Left"] = "Gauche"
L["Center"] = "Centre"
L["Right"] = "Droite"
--L["Tag Anchor:"] = "Tag Anchor:"
--L["Tag X Offset"] = "Tag X Offset"
--L["Tag Y Offset"] = "Tag Y Offset"
--L["Display as %"] = "Display as %"
--L["Wrap bars and display textured separators"] = "Wrap bars and display textured separators"
--L["Anchor buff icons to resources"] = "Anchor buff icons to resources"
--L["Last resource"] = "Last resource"
--L["Buff viewer X/Y"] = "Buff viewer X/Y"
--L["Fallback when no resources"] = "Fallback when no resources"
--L["More options coming soon..."] = "More options coming soon..."

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "Dimensions"
L["Bar Width (0 = Auto)"] = "Largeur de barre (0 = Auto)"
L["Bar Height"] = "Hauteur de barre"
L["Appearance"] = "Apparence"
L["Background Color"] = "Couleur d'arrière-plan"
L["Growth Direction:"] = "Direction de croissance :"
L["Down"] = "Bas"
L["Up"] = "Haut"
L["Icon Position:"] = "Position de l'icône :"
L["Hidden"] = "Masqué"
L["Icon-Bar Gap"] = "Écart icône-barre"
L["Dual Bar Mode (2 bars per row)"] = "Mode double barre (2 barres par rangée)"
L["Show Buff Name"] = "Afficher le nom de l'amélioration"
--L["Max Name Length (0 = Full)"] = "Max Name Length (0 = Full)"
L["Show Duration Text"] = "Afficher le texte de durée"
L["Show Stack Count"] = "Afficher le nombre de cumuls"
L["Notes"] = "Notes"
L["Border settings: see Borders tab"] = "Paramètres de bordure : voir l'onglet Bordures"
L["Text styling (font size, color, offsets): see Text tab"] = "Style du texte (taille de police, couleur, décalages) : voir l'onglet Texte"
L["Position lock and X/Y controls: see Positions tab"] = "Verrouillage de position et contrôles X/Y : voir l'onglet Positions"
L["Bars"] = "Barres"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CastBar.lua
-----------------------------------------------------------------------

L["Enable Cast Bar"] = "Activer la barre d'incantation"
L["Hide Blizzard Cast Bar"] = "Masquer la barre d'incantation Blizzard"
--L["Match Utility Width"] = "Match Utility Width"
L["Spell Icon"] = "Icône de sort"
L["Show Spell Icon"] = "Afficher l'icône de sort"
L["Bar Texture"] = "Texture de barre"
L["Use Blizzard Atlas Textures"] = "Utiliser les textures atlas Blizzard"
L["Cast Color"] = "Couleur d'incantation"
--L["Class Color"] = "Class Color"
L["Channel Color"] = "Couleur de canalisation"
L["Uninterruptible Color"] = "Couleur non interruptible"
--L["Top Left"] = "Top Left"
--L["Top"] = "Top"
--L["Top Right"] = "Top Right"
--L["Bottom Left"] = "Bottom Left"
--L["Bottom"] = "Bottom"
--L["Bottom Right"] = "Bottom Right"
--L["Anchor Point:"] = "Anchor Point:"
--L["Show Preview"] = "Show Preview"
L["Show Spell Name"] = "Afficher le nom du sort"
L["Name X Offset"] = "Décalage X du nom"
L["Name Y Offset"] = "Décalage Y du nom"
L["Show Timer"] = "Afficher la minuterie"
--L["Show Total Duration (e.g. 0.5/1.5)"] = "Show Total Duration (e.g. 0.5/1.5)"
L["Timer X Offset"] = "Décalage X de la minuterie"
L["Timer Y Offset"] = "Décalage Y de la minuterie"
L["Show Spark"] = "Afficher l'étincelle"
L["Empowered Stages"] = "Phases de renforcement"
L["Wind Up Color"] = "Couleur de préparation"
L["Stage 1 Color"] = "Couleur phase 1"
L["Stage 2 Color"] = "Couleur phase 2"
L["Stage 3 Color"] = "Couleur phase 3"
--L["Hold At Max Color"] = "Hold At Max Color"
L["Cast Bar"] = "Barre d'incantation"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Externals.lua
-----------------------------------------------------------------------

--L["Enable Externals"] = "Enable Externals"
--L["Disable Blink"] = "Disable Blink"

