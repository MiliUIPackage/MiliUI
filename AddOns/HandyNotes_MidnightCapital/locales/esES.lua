local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then
    return
end

local _, ns = ...
local L = ns.L

L.ADDON_NAME = "Midnight - Capital"
L.ADDON_DESCRIPTION = "Complemento de HandyNotes para Ciudad de Lunargenta en WoW: Midnight."

L.FILTERS = "Filtros"
L.SHOW_WORLD_MAP_BUTTON = "Mostrar boton del mapa del mundo"
L.SHOW_WORLD_MAP_BUTTON_DESC = "Anade un boton de opciones rapidas al mapa de la capital de Midnight."
L.MINIMAP_ICON_SCALE = "Escala de iconos del minimapa"
L.MINIMAP_ICON_SCALE_DESC = "Escala de los iconos en el minimapa."
L.MAP_ICON_SCALE = "Escala de iconos del mapa"
L.MAP_ICON_SCALE_DESC = "Escala de los iconos en el mapa del mundo."
L.ICON_ALPHA = "Transparencia de iconos"
L.ICON_ALPHA_DESC = "Transparencia de los iconos."
L.SHOW_SERVICES = "Mostrar servicios"
L.SHOW_PROFESSIONS = "Mostrar profesiones"
L.SHOW_ACTIVITIES = "Mostrar actividades"
L.SHOW_TRAVEL = "Mostrar viajes"
L.SHOW_PORTALS = "Mostrar portales"
L.RESET_TO_DEFAULTS = "Restablecer valores"
L.RESET_TO_DEFAULTS_DESC = "Restaura todas las opciones de Midnight - Capital a sus valores predeterminados."
L.RESET_CONFIRM = "Restablecer todas las opciones de Midnight - Capital a sus valores predeterminados?"
L.CLICK_TO_SET_WAYPOINT = "Haz clic para fijar un punto de ruta."
L.QUICK_OPTIONS_DESCRIPTION = "Opciones rapidas de HandyNotes para este mapa."
L.LEFT_CLICK_OPTIONS_DESCRIPTION = "Clic izquierdo para cambiar filtros y opciones de iconos."
L.SHOW_ALL = "Mostrar todo"
L.HIDE_ALL = "Ocultar todo"
L.WORLD_MAP_SCALE_FORMAT = "Escala del mapa del mundo (%sx)"
L.MINIMAP_SCALE_FORMAT = "Escala del minimapa (%sx)"
L.ICON_ALPHA_FORMAT = "Transparencia de iconos (%s)"
L.OPEN_FULL_SETTINGS = "Abrir ajustes completos"

L.CATEGORY_SERVICES = "Servicios"
L.CATEGORY_PROFESSIONS = "Profesiones"
L.CATEGORY_ACTIVITIES = "Actividades"
L.CATEGORY_TRAVEL = "Viajes"
L.CATEGORY_PORTALS = "Portales"

L.NODE_BANK_TITLE = "Banco y gran boveda"
L.NODE_BANK_DESC = "Accede a tus objetos guardados y recompensas semanales."
L.NPC_VAULT_KEEPER = "Guardian de la boveda"

L.NODE_BAZAAR_TITLE = "Casa de Subastas"
L.NODE_BAZAAR_DESC = "Comercia bienes con otros jugadores."
L.NPC_AUCTIONEER = "Subastador"

L.NODE_MAIN_INN_TITLE = "Posada principal"
L.NODE_MAIN_INN_DESC = "Zona de descanso y punto de vinculacion de piedra de hogar."
L.NPC_INNKEEPER = "Posadero"

L.NODE_GEAR_UPGRADES_TITLE = "Mejoras de equipo"
L.NODE_GEAR_UPGRADES_DESC = "Mejora tu equipo."
L.NPC_VASKARN_CUZOLTH = "Vaskarn y Cuzolth"

L.NODE_CATALYST_TITLE = "Consola del catalizador"
L.NODE_CATALYST_DESC = "Convierte objetos en piezas de conjunto."
L.NPC_CATALYST = "Catalizador"

L.NODE_BLACK_MARKET_TITLE = "Casa de Subastas del Mercado Negro"
L.NODE_BLACK_MARKET_DESC = "Puja por objetos raros e inalcanzables."
L.NPC_MADAM_GOYA = "Madam Goya"

L.NODE_TRANSMOG_TITLE = "Transfiguracion"
L.NODE_TRANSMOG_DESC = "Cambia tu apariencia y accede al Almacenamiento del Vacio."
L.NPC_WARPWEAVER = "Tejevacio"

L.NODE_BARBER_TITLE = "Peluqueria"
L.NODE_BARBER_DESC = "Personaliza la apariencia de tu personaje."
L.NPC_TRIM_AND_DYE_EXPERT = "Experto en corte y tinte"

L.NODE_SILVERMOON_INN_TITLE = "Posada de Lunargenta"
L.NODE_SILVERMOON_INN_DESC = "Solo para la Horda: zona de descanso y punto de vinculacion de piedra de hogar."

L.NODE_SILVERMOON_BANK_TITLE = "Camara y banco"
L.NODE_SILVERMOON_BANK_DESC = "Solo para la Horda: acceso al banco y a la gran boveda."

L.NODE_SILVERMOON_AUCTION_HOUSE_TITLE = "Casa de Subastas"
L.NODE_SILVERMOON_AUCTION_HOUSE_DESC = "Solo para la Horda: acceso a la casa de subastas."

L.NODE_SILVERMOON_CATALYST_TITLE = "Catalizador"
L.NODE_SILVERMOON_CATALYST_DESC = "Solo para la Horda: acceso al catalizador."

L.NODE_TIMEWAYS_TITLE = "Sendas temporales"
L.NODE_TIMEWAYS_DESC = "Accede a campanas de Paseo en el Tiempo."
L.NPC_LINDORMI = "Lindormi"

L.NODE_DELVERS_TITLE = "Cuartel general de las profundidades"
L.NODE_DELVERS_DESC = "Progreso de profundidades y profundidades abundantes."
L.NPC_VALEERA_ASTRANDIS = "Valeera Sanguinar y Telemante Astrandis"

L.NODE_PVP_TITLE = "Centro JcJ"
L.NODE_PVP_DESC = "Vendedores de honor y conquista."
L.NPC_GLADIATOR_VENDORS = "Vendedores de gladiador"

L.NODE_TRAINING_DUMMIES_TITLE = "Munecos de entrenamiento"
L.NODE_TRAINING_DUMMIES_DESC = "Pon a prueba tus habilidades de combate (DPS, tanque y sanacion)."
L.NPC_TARGET_DUMMIES = "Munecos de entrenamiento"

L.NODE_CRAFTING_ORDERS_TITLE = "Pedidos de fabricacion"
L.NODE_CRAFTING_ORDERS_DESC = "Pedidos de fabricacion y conocimientos de profesion."
L.NPC_CONSORTIUM_CLERK = "Escribano del consorcio"

L.NODE_FISHING_TITLE = "Instructor de pesca"
L.NODE_FISHING_DESC = "Aprende la profesion de pesca."
L.NPC_FISHING_MASTER = "Maestro pescador"

L.NODE_COOKING_TITLE = "Instructor de cocina"
L.NODE_COOKING_DESC = "Aprende y mejora la cocina de Midnight."
L.NPC_SYLANN = "Sylann <Instructor de cocina>"
