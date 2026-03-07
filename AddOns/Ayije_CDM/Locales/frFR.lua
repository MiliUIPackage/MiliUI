local CDM = _G["Ayije_CDM"]
local L = CDM:NewLocale("frFR")
if not L then return end

-----------------------------------------------------------------------
-- Init.lua
-----------------------------------------------------------------------

L["Callback error in '%s':"] = "Erreur de rappel dans '%s' :"

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "Impossible d'ouvrir la configuration en combat"
L["Could not load options: %s"] = "Impossible de charger les options : %s"
L["Enabled Blizzard Cooldown Manager."] = "Gestionnaire de temps de recharge Blizzard activé."
-- L["Config open queued until combat ends."] = ""
-- L["Config open queued until login setup finishes."] = ""

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "Mode édition verrouillé"
L["use /cdm"] = "utilisez /cdm"
L["Edit Mode locked - use /cdm"] = "Mode édition verrouillé – utilisez /cdm"
L["Cooldown Viewer settings are managed by /cdm. Edit Mode changes are disabled to avoid taint."] = "Les paramètres de la vue de temps de recharge sont gérés par /cdm. Les modifications du mode édition sont désactivées pour éviter la corruption."

-----------------------------------------------------------------------
-- Core/Layout/Containers.lua
-----------------------------------------------------------------------

L["Click and drag to move - /cdm > Positions to lock"] = "Cliquer-glisser pour déplacer – /cdm > Positions à verrouiller"

-----------------------------------------------------------------------
-- Modules/PlayerCastBar.lua
-----------------------------------------------------------------------

L["Preview Cast"] = "Aperçu d'incantation"
L["Click and drag to move - /cdm > Cast Bar to lock"] = "Cliquer-glisser pour déplacer – /cdm > Barre d'incantation à verrouiller"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Init.lua
-----------------------------------------------------------------------

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

L["Layout Settings"] = "Paramètres de disposition"
L["Icon Spacing"] = "Espacement des icônes"
L["Max Icons Per Row"] = "Icônes max. par rangée"
L["Utility Y Offset"] = "Décalage Y utilitaire"
L["Wrap Utility Bar"] = "Diviser la barre utilitaire"
L["Utility Max Icons Per Row"] = "Icônes max. par rangée de la barre utilitaire"
L["Unlock Utility Bar"] = "Déverrouiller la barre utilitaire"
L["Utility X Offset"] = "Décalage X de la barre utilitaire"
L["Display Vertical"] = "Affichage vertical"
L["Layout"] = "Disposition"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Positions.lua
-----------------------------------------------------------------------

L["Lock Container"] = "Verrouiller le conteneur"
L["Unlock to drag the container freely.\nUse sliders below for precise positioning."] = "Déverrouiller pour déplacer le conteneur librement.\nUtilisez les curseurs en dessous pour un positionnement précis."
L["Current: %s (%d, %d)"] = "Actuel : %s (%d, %d)"
L["X Position"] = "Position X"
L["Y Position"] = "Position Y"
L["X Offset"] = "Décalage X"
L["Y Offset"] = "Décalage Y"
L["Essential Container Position"] = "Position du conteneur essentiel"
L["Main Buff Container Position"] = "Position du conteneur d'améliorations principal"
L["Buff Bar Container Position"] = "Position du conteneur de barres d'améliorations"
L["Positions"] = "Positions"

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
L["Zoom Icons (Remove Borders & Overlay)"] = "Zoomer les icônes (supprimer bordures et superposition)"
L["Visual Elements"] = "Éléments visuels"
L["Hide Debuff Border (red outline on harmful effects)"] = "Masquer la bordure de débuff (contour rouge sur les effets néfastes)"
L["Hide Pandemic Indicator (animated refresh window border)"] = "Masquer l'indicateur pandémique (bordure animée de fenêtre de renouvellement)"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "Masquer l'éclat de temps de recharge (animation flash à la fin du temps de recharge)"
L["* These options require /reload to take effect"] = "* Ces options nécessitent /reload pour prendre effet"
L["Borders"] = "Bordures"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Text.lua
-----------------------------------------------------------------------

L["Global Settings"] = "Paramètres globaux"
L["Font"] = "Police"
L["Font Outline"] = "Contour de police"
L["None"] = "Aucun"
L["Outline"] = "Contour"
L["Thick Outline"] = "Contour épais"
L["Cooldown Timer"] = "Minuterie de temps de recharge"
L["Font Size"] = "Taille de police"
L["Color"] = "Couleur"
L["Cooldown Stacks (Charges)"] = "Charges de temps de recharge"
L["Position"] = "Position"
L["Anchor"] = "Ancrage"
L["Buff Bars - Name Text"] = "Barres d'amélioration – Texte du nom"
L["Buff Bars - Duration Text"] = "Barres d'amélioration – Texte de durée"
L["Buff Bars - Stack Count Text"] = "Barres d'amélioration – Texte de cumuls"
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
L["Fade Trigger"] = "Déclencheur de fondu"
L["Fade when no target"] = "Fondu sans cible"
L["Fade out of combat"] = "Fondu hors combat"
L["Faded Opacity"] = "Opacité en fondu"
L["Apply Fading To"] = "Appliquer le fondu à"
L["Buff Bars"] = "Barres d'améliorations"
L["Racials"] = "Raciaux"
L["Defensives"] = "Défensifs"
L["Trinkets"] = "Bijoux"
L["Resources"] = "Ressources"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Assist.lua
-----------------------------------------------------------------------

L["Assist"] = "Assistance"
L["Rotation Assist"] = "Aide à la rotation"
L["Enable Rotation Assist"] = "Activer l'aide à la rotation"
L["Highlight Size"] = "Taille de la surbrillance"
L["Keybindings"] = "Raccourcis clavier"
L["Enable Keybind Text"] = "Afficher le texte des raccourcis"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/BuffGroups.lua & Shared
-----------------------------------------------------------------------

L["Unknown"] = "Inconnu"
L["Add"] = "Ajouter"
L["Border:"] = "Bordure :"
L["Enable Glow"] = "Activer la lueur"
L["Glow Color:"] = "Couleur de lueur :"
-- L["Select a group or spell to edit settings"] = ""
-- L["Grow Direction"] = ""
-- L["Spacing"] = ""
-- L["Cooldown Size"] = ""
-- L["Charge Size"] = ""
-- L["Anchor To"] = ""
-- L["Screen"] = ""
-- L["Player Frame"] = ""
-- L["Essential Viewer"] = ""
-- L["Buff Viewer"] = ""
-- L["Anchor Point"] = ""
-- L["Player Frame Point"] = ""
-- L["Buff Viewer Point"] = ""
-- L["Essential Viewer Point"] = ""
-- L["Right-click icon to reset border color"] = ""
-- L["Per-Spell Overrides"] = ""
-- L["Hide Cooldown Timer"] = ""
-- L["Override Text Settings"] = ""
-- L["Cooldown Color"] = ""
-- L["Charge Color"] = ""
-- L["Charge Position"] = ""
-- L["Charge X Offset"] = ""
-- L["Charge Y Offset"] = ""
-- L["Ungrouped Buffs"] = ""
-- L["No ungrouped buffs"] = ""
-- L["Delete group with %d spell(s)?"] = ""
-- L["Drag spells here"] = ""
-- L["Add Group"] = ""
-- L["Static Display"] = ""
-- L["Hide Icon"] = ""
-- L["Show Placeholder"] = ""
L["Buff Groups"] = "Groupes d'améliorations"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ImportExport.lua
-----------------------------------------------------------------------

L["Serialization failed: %s"] = "Échec de la sérialisation : %s"
L["Compression failed: %s"] = "Échec de la compression : %s"
L["Base64 encoding failed: %s"] = "Échec de l'encodage Base64 : %s"
L["No import string provided"] = "Aucune chaîne d'importation fournie"
L["Invalid Base64 encoding"] = "Encodage Base64 invalide"
L["Decompression failed"] = "Échec de la décompression"
L["Invalid profile data"] = "Données de profil invalides"
L["Missing profile metadata"] = "Métadonnées de profil manquantes"
L["Profile is for a different addon: %s"] = "Le profil est destiné à un autre addon : %s"
L["Invalid profile version"] = "Version de profil invalide"
L["Failed to import profile"] = "Échec de l'importation du profil"
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
-- L["Select at least one category to export."] = ""
-- L["Profile is for a different addon"] = ""
-- L["Type mismatch on key '%s': expected %s, got %s"] = ""
L["Import/Export"] = "Import/Export"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Profiles.lua
-----------------------------------------------------------------------

L["Current Profile"] = "Profil actuel"
L["New Profile"] = "Nouveau profil"
L["Create"] = "Créer"
L["Enter a name"] = "Entrez un nom"
L["Already exists"] = "Existe déjà"
L["Copy From"] = "Copier depuis"
L["Copy all settings from another profile into the current one."] = "Copier tous les paramètres d'un autre profil dans le profil actuel."
L["Select Source..."] = "Sélectionner la source..."
L["Manage"] = "Gérer"
L["Rename"] = "Renommer"
L["Reset Profile"] = "Réinitialiser le profil"
L["Delete Profile..."] = "Supprimer le profil..."
L["Default Profile for New Characters"] = "Profil par défaut pour les nouveaux personnages"
L["Specialization Profiles"] = "Profils de spécialisation"
L["Auto-switch profile per specialization"] = "Changement auto. de profil par spécialisation"
L["Spec %d"] = "Spéc. %d"
-- L["Failed to apply profile"] = ""
-- L["Profile not found"] = ""
-- L["Cannot copy active profile"] = ""
-- L["Cannot delete active profile"] = ""
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
-- L["Show Items at 0 Stacks"] = ""
L["Tracked Spells"] = "Sorts suivis"
L["Manage Spells"] = "Gérer les sorts"
L["Icon Size"] = "Taille d'icône"
L["Icon Width"] = "Largeur d'icône"
L["Icon Height"] = "Hauteur d'icône"
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

L["Current Spec"] = "Spécialisation actuelle"
L["Add Custom Spell"] = "Ajouter un sort personnalisé"
L["Spell ID"] = "ID de sort"
L["Enter a valid spell ID"] = "Entrez un ID de sort valide"
L["Not available for spec"] = "Non disponible pour cette spécialisation"
L["Enable Defensives"] = "Activer les défensifs"
L["Hide tracked defensives from Essential/Utility viewers"] = "Masquer les défensifs suivis des visualiseurs Essentiel/Utilitaire"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Trinkets.lua
-----------------------------------------------------------------------

L["Independent"] = "Indépendant"
L["Append to Defensives"] = "Ajouter aux défensifs"
L["Append to Spells"] = "Ajouter aux sorts"
L["Row 1"] = "Rangée 1"
L["Row 2"] = "Rangée 2"
L["Start"] = "Début"
L["End"] = "Fin"
L["Enable Trinkets"] = "Activer les bijoux"
L["Layout Mode"] = "Mode de disposition"
L["Display Mode"] = "Mode d'affichage"
L["Row"] = "Rangée"
L["Position in Row"] = "Position dans la rangée"
L["Show Passive Trinkets"] = "Afficher les bijoux passifs"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources.lua
-----------------------------------------------------------------------

L["Background"] = "Arrière-plan"
L["Rage"] = "Rage"
L["Energy"] = "Énergie"
L["Focus"] = "Focalisation"
L["Astral Power"] = "Puissance astrale"
L["Maelstrom"] = "Maelström"
L["Insanity"] = "Démence"
L["Fury"] = "Fureur"
L["Mana"] = "Mana"
L["Essence"] = "Essence"
L["Essence Recharging"] = "Essence en recharge"
L["Combo Points"] = "Points de combo"
L["Charged"] = "Charged"
L["Charged Empty"] = "Charged Empty"
L["Holy Power"] = "Puissance sacrée"
L["Soul Shards"] = "Éclats d'âme"
L["Soul Shards Partial"] = "Éclats d'âme partiels"
L["Arcane Charges"] = "Charges d'arcanes"
L["Chi"] = "Chi"
L["Runic Power"] = "Puissance runique"
L["Runes Ready"] = "Runes prêtes"
L["Runes Recharging"] = "Runes en recharge"
L["Soul Fragments"] = "Fragments d'âme"
-- L["Devourer Souls"] = ""
L["Light (<30%)"] = "Léger (<30%)"
L["Moderate (30-60%)"] = "Modéré (30-60%)"
L["Heavy (>60%)"] = "Lourd (>60%)"
L["Enable Resources"] = "Activer les ressources"
L["Bar Dimensions"] = "Dimensions de barre"
L["Bar 1 Height"] = "Hauteur barre 1"
L["Bar 2 Height"] = "Hauteur barre 2"
L["Bar Width (0 = Auto)"] = "Largeur de barre (0 = Auto)"
L["Bar Spacing (Vertical)"] = "Espacement de barre (vertical)"
L["Unified Border (wrap all bars)"] = "Bordure unifiée (entourer toutes les barres)"
L["Move buffs down dynamically"] = "Déplacer les améliorations vers le bas dynamiquement"
L["Show Mana Bar"] = "Afficher la barre de mana"
L["Display Mana as %"] = "Afficher le mana en %"
L["Bar Texture:"] = "Texture de barre :"
L["Select Texture..."] = "Sélectionner la texture..."
L["Background Texture:"] = "Texture d'arrière-plan :"
L["Position Offsets"] = "Décalages de position"
L["Power Type Colors"] = "Couleurs des types de puissance"
L["Show All Colors"] = "Afficher toutes les couleurs"
L["Stagger uses threshold colors: "] = "Le report utilise des couleurs de seuil : "
L["Light"] = "Léger"
L["Moderate"] = "Modéré"
L["Heavy"] = "Lourd"
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
L["Tags (Power Value Text)"] = "Étiquettes (texte de valeur de puissance)"
L["Left"] = "Gauche"
L["Center"] = "Centre"
L["Right"] = "Droite"
L["Bar %s"] = "Barre %s"
L["Enable %s Tag (current value)"] = "Activer l'étiquette %s (valeur actuelle)"
L["%s Font Size"] = "Taille de police %s"
L["%s Anchor:"] = "Ancrage %s :"
L["%s Offset X"] = "Décalage X %s"
L["%s Offset Y"] = "Décalage Y %s"
L["%s Text Color"] = "Couleur du texte %s"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CustomBuffs.lua
-----------------------------------------------------------------------

L["ID: %s  |  Duration: %ss"] = "ID : %s  |  Durée : %ss"
L["Remove"] = "Retirer"
L["Custom Timers"] = "Minuteries personnalisées"
L["Track spell casts and display custom buff icons alongside native buffs. Icons appear in the main buff container."] = "Suivre les incantations et afficher des icônes d'amélioration personnalisées à côté des améliorations natives. Les icônes apparaissent dans le conteneur d'améliorations principal."
L["Add Tracked Spell"] = "Ajouter un sort suivi"
L["Spell ID:"] = "ID de sort :"
L["Duration (sec):"] = "Durée (sec.) :"
L["Add Spell"] = "Ajouter un sort"
L["Invalid spell ID"] = "ID de sort invalide"
L["Enter a valid duration"] = "Entrez une durée valide"
L["Limit reached (9 max)"] = "Limite atteinte (9 max.)"
L["Added!"] = "Ajouté !"
L["Failed - invalid spell ID"] = "Échec – ID de sort invalide"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "Dimensions"
L["Bar Height"] = "Hauteur de barre"
L["Bar Spacing"] = "Espacement de barre"
L["Appearance"] = "Apparence"
L["Bar Color"] = "Couleur de barre"
L["Background Color"] = "Couleur d'arrière-plan"
L["Growth Direction:"] = "Direction de croissance :"
L["Down"] = "Bas"
L["Up"] = "Haut"
L["Icon Position:"] = "Position de l'icône :"
L["Hidden"] = "Masqué"
L["Icon-Bar Gap"] = "Écart icône-barre"
L["Dual Bar Mode (2 bars per row)"] = "Mode double barre (2 barres par rangée)"
L["Show Buff Name"] = "Afficher le nom de l'amélioration"
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
L["Width (0 = Auto)"] = "Largeur (0 = Auto)"
L["Spell Icon"] = "Icône de sort"
L["Show Spell Icon"] = "Afficher l'icône de sort"
L["Bar Texture"] = "Texture de barre"
L["Use Blizzard Atlas Textures"] = "Utiliser les textures atlas Blizzard"
L["Cast Color"] = "Couleur d'incantation"
L["Channel Color"] = "Couleur de canalisation"
L["Uninterruptible Color"] = "Couleur non interruptible"
L["Anchor to Resource Bars"] = "Ancrer aux barres de ressources"
L["Y Spacing"] = "Espacement Y"
L["Lock Position"] = "Verrouiller la position"
L["Show Spell Name"] = "Afficher le nom du sort"
L["Name X Offset"] = "Décalage X du nom"
L["Name Y Offset"] = "Décalage Y du nom"
L["Show Timer"] = "Afficher la minuterie"
L["Timer X Offset"] = "Décalage X de la minuterie"
L["Timer Y Offset"] = "Décalage Y de la minuterie"
L["Show Spark"] = "Afficher l'étincelle"
L["Empowered Stages"] = "Phases de renforcement"
L["Wind Up Color"] = "Couleur de préparation"
L["Stage 1 Color"] = "Couleur phase 1"
L["Stage 2 Color"] = "Couleur phase 2"
L["Stage 3 Color"] = "Couleur phase 3"
L["Stage 4 Color"] = "Couleur phase 4"
-- L["Class Color"] = ""
L["Cast Bar"] = "Barre d'incantation"

-----------------------------------------------------------------------
-- Core/EditMode.lua (placeholders)
-----------------------------------------------------------------------

-- L["Cooldown Manager settings differ from AyijeCDM recommendations. Apply now?"] = ""
-- L["Apply CDM Settings"] = ""
-- L["Not now"] = ""
-- L["Cooldown Manager settings will be applied after combat."] = ""
