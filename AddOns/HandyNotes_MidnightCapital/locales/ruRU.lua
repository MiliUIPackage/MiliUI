if GetLocale() ~= "ruRU" then
    return
end

local _, ns = ...
local L = ns.L

L.ADDON_NAME = "Midnight - Столица"
L.ADDON_DESCRIPTION = "Плагин HandyNotes для Луносвета в WoW: Midnight."

L.FILTERS = "Фильтры"
L.SHOW_WORLD_MAP_BUTTON = "Показывать кнопку карты мира"
L.SHOW_WORLD_MAP_BUTTON_DESC = "Добавляет кнопку быстрых настроек на карту столицы Midnight."
L.MINIMAP_ICON_SCALE = "Масштаб значков мини-карты"
L.MINIMAP_ICON_SCALE_DESC = "Размер значков на мини-карте."
L.MAP_ICON_SCALE = "Масштаб значков карты"
L.MAP_ICON_SCALE_DESC = "Размер значков на карте мира."
L.ICON_ALPHA = "Прозрачность значков"
L.ICON_ALPHA_DESC = "Прозрачность значков."
L.SHOW_SERVICES = "Показывать услуги"
L.SHOW_PROFESSIONS = "Показывать профессии"
L.SHOW_ACTIVITIES = "Показывать активности"
L.SHOW_TRAVEL = "Показывать путешествия"
L.SHOW_PORTALS = "Показывать порталы"
L.RESET_TO_DEFAULTS = "Сбросить настройки"
L.RESET_TO_DEFAULTS_DESC = "Восстановить значения по умолчанию для всех настроек Midnight - Столица."
L.RESET_CONFIRM = "Сбросить все настройки Midnight - Столица к значениям по умолчанию?"
L.CLICK_TO_SET_WAYPOINT = "Щелкните, чтобы установить точку маршрута."
L.QUICK_OPTIONS_DESCRIPTION = "Быстрые настройки HandyNotes для этой карты."
L.LEFT_CLICK_OPTIONS_DESCRIPTION = "ЛКМ для изменения фильтров и параметров отображения значков."
L.SHOW_ALL = "Показать все"
L.HIDE_ALL = "Скрыть все"
L.WORLD_MAP_SCALE_FORMAT = "Масштаб на карте мира (%sx)"
L.MINIMAP_SCALE_FORMAT = "Масштаб на мини-карте (%sx)"
L.ICON_ALPHA_FORMAT = "Прозрачность значков (%s)"
L.OPEN_FULL_SETTINGS = "Открыть полные настройки"

L.CATEGORY_SERVICES = "Услуги"
L.CATEGORY_PROFESSIONS = "Профессии"
L.CATEGORY_ACTIVITIES = "Активности"
L.CATEGORY_TRAVEL = "Путешествия"
L.CATEGORY_PORTALS = "Порталы"

L.NODE_BANK_TITLE = "Банк и великое хранилище"
L.NODE_BANK_DESC = "Доступ к вашим сохраненным предметам и еженедельным наградам."
L.NPC_VAULT_KEEPER = "Хранитель хранилища"

L.NODE_BAZAAR_TITLE = "Аукционный дом"
L.NODE_BAZAAR_DESC = "Торгуйте предметами с другими игроками."
L.NPC_AUCTIONEER = "Аукционист"

L.NODE_MAIN_INN_TITLE = "Главная гостиница"
L.NODE_MAIN_INN_DESC = "Зона отдыха и точка привязки камня возвращения."
L.NPC_INNKEEPER = "Хозяин таверны"

L.NODE_GEAR_UPGRADES_TITLE = "Улучшение экипировки"
L.NODE_GEAR_UPGRADES_DESC = "Улучшайте свое снаряжение."
L.NPC_VASKARN_CUZOLTH = "Васкарн и Кузолт"

L.NODE_CATALYST_TITLE = "Консоль катализатора"
L.NODE_CATALYST_DESC = "Преобразуйте предметы в элементы комплекта."
L.NPC_CATALYST = "Катализатор"

L.NODE_BLACK_MARKET_TITLE = "Черный аукцион"
L.NODE_BLACK_MARKET_DESC = "Делайте ставки на редкие и недоступные предметы."
L.NPC_MADAM_GOYA = "Мадам Гойя"

L.NODE_TRANSMOG_TITLE = "Трансмогрификация"
L.NODE_TRANSMOG_DESC = "Изменяйте внешний вид и получайте доступ к Хранилищу Бездны."
L.NPC_WARPWEAVER = "Ткач Пустоты"

L.NODE_BARBER_TITLE = "Парикмахерская"
L.NODE_BARBER_DESC = "Настройте внешний вид своего персонажа."
L.NPC_TRIM_AND_DYE_EXPERT = "Эксперт по стрижке и окраске"

L.NODE_SILVERMOON_INN_TITLE = "Таверна Луносвета"
L.NODE_SILVERMOON_INN_DESC = "Только для Орды: зона отдыха и точка привязки камня возвращения."

L.NODE_SILVERMOON_BANK_TITLE = "Хранилище и банк"
L.NODE_SILVERMOON_BANK_DESC = "Только для Орды: доступ к банку и великому хранилищу."

L.NODE_SILVERMOON_AUCTION_HOUSE_TITLE = "Аукционный дом"
L.NODE_SILVERMOON_AUCTION_HOUSE_DESC = "Только для Орды: доступ к аукционному дому."

L.NODE_SILVERMOON_CATALYST_TITLE = "Катализатор"
L.NODE_SILVERMOON_CATALYST_DESC = "Только для Орды: доступ к катализатору."

L.NODE_TIMEWAYS_TITLE = "Пути времени"
L.NODE_TIMEWAYS_DESC = "Доступ к кампаниям путешествий во времени."
L.NPC_LINDORMI = "Линдорми"

L.NODE_DELVERS_TITLE = "Штаб покорителей вылазок"
L.NODE_DELVERS_DESC = "Прогресс вылазок и щедрые вылазки."
L.NPC_VALEERA_ASTRANDIS = "Валира Сангвинар и телемант Астрандис"

L.NODE_PVP_TITLE = "PvP-центр"
L.NODE_PVP_DESC = "Продавцы чести и завоевания."
L.NPC_GLADIATOR_VENDORS = "Продавцы-гладиаторы"

L.NODE_TRAINING_DUMMIES_TITLE = "Тренировочные манекены"
L.NODE_TRAINING_DUMMIES_DESC = "Проверьте свои боевые способности (урон, танк и исцеление)."
L.NPC_TARGET_DUMMIES = "Тренировочные манекены"

L.NODE_CRAFTING_ORDERS_TITLE = "Заказы на изготовление"
L.NODE_CRAFTING_ORDERS_DESC = "Заказы на изготовление и знания профессий."
L.NPC_CONSORTIUM_CLERK = "Служащий консорциума"

L.NODE_FISHING_TITLE = "Учитель рыбалки"
L.NODE_FISHING_DESC = "Изучите профессию рыболовства."
L.NPC_FISHING_MASTER = "Мастер рыбной ловли"

L.NODE_COOKING_TITLE = "Учитель кулинарии"
L.NODE_COOKING_DESC = "Изучайте и совершенствуйте кулинарию Midnight."
L.NPC_SYLANN = "Силанн <Учитель кулинарии>"
