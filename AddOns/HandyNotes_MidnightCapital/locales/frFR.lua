if GetLocale() ~= "frFR" then
    return
end

local _, ns = ...
local L = ns.L

L.ADDON_NAME = "Midnight - Capitale"
L.ADDON_DESCRIPTION = "Plugin HandyNotes pour la ville de Lune-d'Argent dans WoW: Midnight."

L.FILTERS = "Filtres"
L.SHOW_WORLD_MAP_BUTTON = "Afficher le bouton de la carte du monde"
L.SHOW_WORLD_MAP_BUTTON_DESC = "Ajoute un bouton d'options rapide sur la carte de la capitale de Midnight."
L.MINIMAP_ICON_SCALE = "Taille des icones de la minicarte"
L.MINIMAP_ICON_SCALE_DESC = "Taille des icones sur la minicarte."
L.MAP_ICON_SCALE = "Taille des icones de la carte"
L.MAP_ICON_SCALE_DESC = "Taille des icones sur la carte du monde."
L.ICON_ALPHA = "Transparence des icones"
L.ICON_ALPHA_DESC = "Transparence des icones."
L.SHOW_SERVICES = "Afficher les services"
L.SHOW_PROFESSIONS = "Afficher les metiers"
L.SHOW_ACTIVITIES = "Afficher les activites"
L.SHOW_TRAVEL = "Afficher les voyages"
L.SHOW_PORTALS = "Afficher les portails"
L.RESET_TO_DEFAULTS = "Reinitialiser"
L.RESET_TO_DEFAULTS_DESC = "Restaure toutes les options de Midnight - Capitale a leurs valeurs par defaut."
L.RESET_CONFIRM = "Reinitialiser toutes les options de Midnight - Capitale a leurs valeurs par defaut ?"
L.CLICK_TO_SET_WAYPOINT = "Cliquez pour definir un point de passage."
L.QUICK_OPTIONS_DESCRIPTION = "Options HandyNotes rapides pour cette carte."
L.LEFT_CLICK_OPTIONS_DESCRIPTION = "Clic gauche pour modifier les filtres et l'affichage des icones."
L.SHOW_ALL = "Tout afficher"
L.HIDE_ALL = "Tout masquer"
L.WORLD_MAP_SCALE_FORMAT = "Taille sur la carte du monde (%sx)"
L.MINIMAP_SCALE_FORMAT = "Taille sur la minicarte (%sx)"
L.ICON_ALPHA_FORMAT = "Transparence des icones (%s)"
L.OPEN_FULL_SETTINGS = "Ouvrir les parametres complets"

L.CATEGORY_SERVICES = "Services"
L.CATEGORY_PROFESSIONS = "Metiers"
L.CATEGORY_ACTIVITIES = "Activites"
L.CATEGORY_TRAVEL = "Voyage"
L.CATEGORY_PORTALS = "Portails"

L.NODE_BANK_TITLE = "Banque et grand coffre"
L.NODE_BANK_DESC = "Accedez a vos objets stockes et a vos recompenses hebdomadaires."
L.NPC_VAULT_KEEPER = "Gardien du coffre"

L.NODE_BAZAAR_TITLE = "Hôtel des ventes"
L.NODE_BAZAAR_DESC = "Echangez des marchandises avec d'autres joueurs."
L.NPC_AUCTIONEER = "Commissaire-priseur"

L.NODE_MAIN_INN_TITLE = "Auberge principale"
L.NODE_MAIN_INN_DESC = "Zone de repos et point de foyer."
L.NPC_INNKEEPER = "Aubergiste"

L.NODE_GEAR_UPGRADES_TITLE = "Ameliorations d'equipement"
L.NODE_GEAR_UPGRADES_DESC = "Ameliorez votre equipement."
L.NPC_VASKARN_CUZOLTH = "Vaskarn et Cuzolth"

L.NODE_CATALYST_TITLE = "Console du Catalyseur"
L.NODE_CATALYST_DESC = "Transformez des objets en pieces de set."
L.NPC_CATALYST = "Catalyseur"

L.NODE_BLACK_MARKET_TITLE = "Hotel des ventes du marche noir"
L.NODE_BLACK_MARKET_DESC = "Misez sur des objets rares et introuvables."
L.NPC_MADAM_GOYA = "Madam Goya"

L.NODE_TRANSMOG_TITLE = "Transmogrification"
L.NODE_TRANSMOG_DESC = "Changez votre apparence et accedez au stockage du Vide."
L.NPC_WARPWEAVER = "Tisse-vide"

L.NODE_BARBER_TITLE = "Salon de coiffure"
L.NODE_BARBER_DESC = "Personnalisez l'apparence de votre personnage."
L.NPC_TRIM_AND_DYE_EXPERT = "Expert coupe et couleur"

L.NODE_SILVERMOON_INN_TITLE = "Auberge de Lune-d'Argent"
L.NODE_SILVERMOON_INN_DESC = "Reserve a la Horde : zone de repos et point de foyer."

L.NODE_SILVERMOON_BANK_TITLE = "Coffre et banque"
L.NODE_SILVERMOON_BANK_DESC = "Reserve a la Horde : acces a la banque et au grand coffre."

L.NODE_SILVERMOON_AUCTION_HOUSE_TITLE = "Hotel des ventes"
L.NODE_SILVERMOON_AUCTION_HOUSE_DESC = "Reserve a la Horde : acces a l'hotel des ventes."

L.NODE_SILVERMOON_CATALYST_TITLE = "Catalyseur"
L.NODE_SILVERMOON_CATALYST_DESC = "Reserve a la Horde : acces au catalyseur."

L.NODE_TIMEWAYS_TITLE = "Voies temporelles"
L.NODE_TIMEWAYS_DESC = "Accedez aux campagnes des Marcheurs du temps."
L.NPC_LINDORMI = "Lindormi"

L.NODE_DELVERS_TITLE = "Quartier general des gouffres"
L.NODE_DELVERS_DESC = "Progression des gouffres et gouffres abondants."
L.NPC_VALEERA_ASTRANDIS = "Valeera Sanguinar et Telemancienne Astrandis"

L.NODE_PVP_TITLE = "Centre JcJ"
L.NODE_PVP_DESC = "Vendeurs d'Honneur et de Conquete."
L.NPC_GLADIATOR_VENDORS = "Vendeurs gladiateurs"

L.NODE_TRAINING_DUMMIES_TITLE = "Mannequins d'entrainement"
L.NODE_TRAINING_DUMMIES_DESC = "Testez vos capacites de combat (DPS, tank et soins)."
L.NPC_TARGET_DUMMIES = "Mannequins d'entrainement"

L.NODE_CRAFTING_ORDERS_TITLE = "Commandes d'artisanat"
L.NODE_CRAFTING_ORDERS_DESC = "Commandes d'artisanat et connaissances de metier."
L.NPC_CONSORTIUM_CLERK = "Commis du consortium"

L.NODE_FISHING_TITLE = "Maitre de peche"
L.NODE_FISHING_DESC = "Apprenez la peche."
L.NPC_FISHING_MASTER = "Maitre pecheur"

L.NODE_COOKING_TITLE = "Maitre de cuisine"
L.NODE_COOKING_DESC = "Apprenez et entrainez la cuisine de Midnight."
L.NPC_SYLANN = "Sylann <Maitre de cuisine>"
