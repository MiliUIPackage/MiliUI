if GetLocale() ~= "deDE" then
    return
end

local _, ns = ...
local L = ns.L

L.ADDON_NAME = "Midnight - Hauptstadt"
L.ADDON_DESCRIPTION = "HandyNotes-Plugin fuer Silbermond in WoW: Midnight."

L.FILTERS = "Filter"
L.SHOW_WORLD_MAP_BUTTON = "Weltkarten-Schaltflaeche anzeigen"
L.SHOW_WORLD_MAP_BUTTON_DESC = "Fuegt der Karte der Midnight-Hauptstadt eine schnelle Optionsschaltflaeche hinzu."
L.MINIMAP_ICON_SCALE = "Symbolgroesse auf der Minikarte"
L.MINIMAP_ICON_SCALE_DESC = "Skalierung der Symbole auf der Minikarte."
L.MAP_ICON_SCALE = "Symbolgroesse auf der Weltkarte"
L.MAP_ICON_SCALE_DESC = "Skalierung der Symbole auf der Weltkarte."
L.ICON_ALPHA = "Symboltransparenz"
L.ICON_ALPHA_DESC = "Transparenz der Symbole."
L.SHOW_SERVICES = "Dienste anzeigen"
L.SHOW_PROFESSIONS = "Berufe anzeigen"
L.SHOW_ACTIVITIES = "Aktivitaeten anzeigen"
L.SHOW_TRAVEL = "Reisen anzeigen"
L.SHOW_PORTALS = "Portale anzeigen"
L.RESET_TO_DEFAULTS = "Auf Standard zuruecksetzen"
L.RESET_TO_DEFAULTS_DESC = "Stellt alle Optionen von Midnight - Hauptstadt auf ihre Standardwerte zurueck."
L.RESET_CONFIRM = "Alle Optionen von Midnight - Hauptstadt auf ihre Standardwerte zuruecksetzen?"
L.CLICK_TO_SET_WAYPOINT = "Klicken, um einen Wegpunkt zu setzen."
L.QUICK_OPTIONS_DESCRIPTION = "Schnelle HandyNotes-Optionen fuer diese Karte."
L.LEFT_CLICK_OPTIONS_DESCRIPTION = "Linksklick, um Filter und Symbolanzeige zu aendern."
L.SHOW_ALL = "Alle anzeigen"
L.HIDE_ALL = "Alle ausblenden"
L.WORLD_MAP_SCALE_FORMAT = "Weltkarten-Skalierung (%sx)"
L.MINIMAP_SCALE_FORMAT = "Minikarten-Skalierung (%sx)"
L.ICON_ALPHA_FORMAT = "Symboltransparenz (%s)"
L.OPEN_FULL_SETTINGS = "Vollstaendige Einstellungen oeffnen"

L.CATEGORY_SERVICES = "Dienste"
L.CATEGORY_PROFESSIONS = "Berufe"
L.CATEGORY_ACTIVITIES = "Aktivitaeten"
L.CATEGORY_TRAVEL = "Reisen"
L.CATEGORY_PORTALS = "Portale"

L.NODE_BANK_TITLE = "Bank und grosses Gewoelbe"
L.NODE_BANK_DESC = "Greife auf deine gelagerten Gegenstaende und woechentlichen Belohnungen zu."
L.NPC_VAULT_KEEPER = "Gewoelbewaechter"

L.NODE_BAZAAR_TITLE = "Auktionshaus"
L.NODE_BAZAAR_DESC = "Handle Waren mit anderen Spielern."
L.NPC_AUCTIONEER = "Auktionator"

L.NODE_MAIN_INN_TITLE = "Hauptgasthaus"
L.NODE_MAIN_INN_DESC = "Ruhebereich und Heimatstein-Bindepunkt."
L.NPC_INNKEEPER = "Gastwirt"

L.NODE_GEAR_UPGRADES_TITLE = "Gegenstandsaufwertungen"
L.NODE_GEAR_UPGRADES_DESC = "Verbessere deine Ausruestung."
L.NPC_VASKARN_CUZOLTH = "Vaskarn und Cuzolth"

L.NODE_CATALYST_TITLE = "Katalysator-Konsole"
L.NODE_CATALYST_DESC = "Wandle Gegenstaende in Setteile um."
L.NPC_CATALYST = "Katalysator"

L.NODE_BLACK_MARKET_TITLE = "Schwarzmarkt-Auktionshaus"
L.NODE_BLACK_MARKET_DESC = "Biete auf seltene und nicht mehr erhaeltliche Gegenstaende."
L.NPC_MADAM_GOYA = "Madam Goya"

L.NODE_TRANSMOG_TITLE = "Transmogrifikation"
L.NODE_TRANSMOG_DESC = "Aendere dein Aussehen und greife auf die Leerenlagerung zu."
L.NPC_WARPWEAVER = "Transmogrifizierer"

L.NODE_BARBER_TITLE = "Barbier"
L.NODE_BARBER_DESC = "Passe das Aussehen deines Charakters an."
L.NPC_TRIM_AND_DYE_EXPERT = "Schneid- und Faerbeexperte"

L.NODE_SILVERMOON_INN_TITLE = "Gasthaus von Silbermond"
L.NODE_SILVERMOON_INN_DESC = "Nur fuer die Horde: Ruhebereich und Heimatstein-Bindepunkt."

L.NODE_SILVERMOON_BANK_TITLE = "Gewoelbe und Bank"
L.NODE_SILVERMOON_BANK_DESC = "Nur fuer die Horde: Zugang zu Bank und Grossem Gewoelbe."

L.NODE_SILVERMOON_AUCTION_HOUSE_TITLE = "Auktionshaus"
L.NODE_SILVERMOON_AUCTION_HOUSE_DESC = "Nur fuer die Horde: Zugang zum Auktionshaus."

L.NODE_SILVERMOON_CATALYST_TITLE = "Katalysator"
L.NODE_SILVERMOON_CATALYST_DESC = "Nur fuer die Horde: Zugang zum Katalysator."

L.NODE_TIMEWAYS_TITLE = "Zeitpfade"
L.NODE_TIMEWAYS_DESC = "Greife auf Zeitwanderungskampagnen zu."
L.NPC_LINDORMI = "Lindormi"

L.NODE_DELVERS_TITLE = "Hauptquartier der Tiefenforscher"
L.NODE_DELVERS_DESC = "Fortschritt fuer Tiefen und ergiebige Tiefen."
L.NPC_VALEERA_ASTRANDIS = "Valeera Sanguinar und Telemantin Astrandis"

L.NODE_PVP_TITLE = "PvP-Zentrum"
L.NODE_PVP_DESC = "Anbieter fuer Ehre und Eroberung."
L.NPC_GLADIATOR_VENDORS = "Gladiatorenhaendler"

L.NODE_TRAINING_DUMMIES_TITLE = "Trainingspuppen"
L.NODE_TRAINING_DUMMIES_DESC = "Teste deine Kampffaehigkeiten (DPS, Tank und Heilung)."
L.NPC_TARGET_DUMMIES = "Trainingspuppen"

L.NODE_CRAFTING_ORDERS_TITLE = "Herstellungsauftraege"
L.NODE_CRAFTING_ORDERS_DESC = "Herstellungsauftraege und Berufswissen."
L.NPC_CONSORTIUM_CLERK = "Konsortiumsschreiber"

L.NODE_FISHING_TITLE = "Angeltrainer"
L.NODE_FISHING_DESC = "Erlerne den Beruf Angeln."
L.NPC_FISHING_MASTER = "Angelmeister"

L.NODE_COOKING_TITLE = "Kochtrainer"
L.NODE_COOKING_DESC = "Erlerne und trainiere Midnight-Kochen."
L.NPC_SYLANN = "Sylann <Kochtrainer>"
