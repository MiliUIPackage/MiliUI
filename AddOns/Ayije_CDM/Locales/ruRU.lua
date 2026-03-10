local CDM = _G["Ayije_CDM"]
local L = CDM:NewLocale("ruRU")
if not L then return end

-----------------------------------------------------------------------
-- Init.lua
-----------------------------------------------------------------------

L["Callback error in '%s':"] = "Ошибка обратного вызова в '%s':"

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "Невозможно открыть настройки в бою"
L["Could not load options: %s"] = "Не удалось загрузить настройки: %s"
-- L["Enabled Blizzard Cooldown Manager."] = ""
-- L["Config open queued until combat ends."] = ""
-- L["Config open queued until login setup finishes."] = ""

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "Режим редактирования заблокирован"
L["use /cdm"] = "используйте /cdm"
L["Edit Mode locked - use /cdm"] = "Режим редактирования заблокирован — используйте /cdm"
L["Cooldown Viewer settings are managed by /cdm. Edit Mode changes are disabled to avoid taint."] = "Настройки трекера восстановления способностей управляются через /cdm. Изменения в режиме редактирования отключены во избежание ошибок."

-----------------------------------------------------------------------
-- Core/Layout/Containers.lua
-----------------------------------------------------------------------

L["Click and drag to move - /cdm > Positions to lock"] = "Нажмите и перетащите для перемещения — /cdm > «Позиции», чтобы заблокировать"

-----------------------------------------------------------------------
-- Modules/PlayerCastBar.lua
-----------------------------------------------------------------------

L["Preview Cast"] = "Предпросмотр заклинания"
L["Click and drag to move - /cdm > Cast Bar to lock"] = "Нажмите и перетащите для перемещения — /cdm > «Полоса заклинания», чтобы заблокировать"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Init.lua
-----------------------------------------------------------------------

L["Copy this URL:"] = "Скопируйте этот URL:"
L["Close"] = "Закрыть"
L["Reset the current profile to default settings?"] = "Сбросить текущий профиль до настроек по умолчанию?"
L["Reset"] = "Сбросить"
L["Cancel"] = "Отмена"
L["Copy"] = "Копировать"
L["Delete"] = "Удалить"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "Невозможно %s в бою"
L["open CDM config"] = "открыть настройки CDM"
L["Display"] = "Отображение"
L["Styling"] = "Внешний вид"
L["Buffs"] = "Баффы"
L["Features"] = "Функции"
L["Utility"] = "Утилиты"
L["Cooldown Manager"] = "Трекер восстановления способностей"
L["Settings"] = "Настройки"
L["rebuild CDM config"] = "перестроить настройки CDM"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "Основные способности"
L["Row 1 Width"] = "Ширина ряда 1"
L["Row 1 Height"] = "Высота ряда 1"
L["Row 2 Width"] = "Ширина ряда 2"
L["Row 2 Height"] = "Высота ряда 2"
L["Width"] = "Ширина"
L["Height"] = "Высота"
L["Buff"] = "Бафф"
L["Icon Sizes"] = "Размеры иконок"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Layout.lua
-----------------------------------------------------------------------

L["Layout Settings"] = "Настройки макета"
L["Icon Spacing"] = "Расстояние между иконками"
L["Max Icons Per Row"] = "Макс. иконок в ряду"
L["Utility Y Offset"] = "Смещение вспомогательных способностей по Y"
L["Wrap Utility Bar"] = "Перенос панели вспомогательных способностей"
L["Utility Max Icons Per Row"] = "Макс. иконок вспомогательных способностей в ряду"
L["Unlock Utility Bar"] = "Разблокировать панель вспомогательных способностей"
L["Utility X Offset"] = "Смещение вспомогательных способностей по X"
L["Display Vertical"] = "Вертикальное отображение"
L["Layout"] = "Макет"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Positions.lua
-----------------------------------------------------------------------

L["Lock Container"] = "Заблокировать контейнер"
L["Unlock to drag the container freely.\nUse sliders below for precise positioning."] = "Разблокируйте для свободного перемещения контейнера.\nИспользуйте ползунки ниже для точного позиционирования."
L["Current: %s (%d, %d)"] = "Текущее: %s (%d, %d)"
L["X Position"] = "Позиция по X"
L["Y Position"] = "Позиция по Y"
L["X Offset"] = "Смещение по X"
L["Y Offset"] = "Смещение по Y"
L["Essential Container Position"] = "Позиция контейнера основных способностей"
L["Main Buff Container Position"] = "Позиция контейнера основных баффов"
L["Buff Bar Container Position"] = "Позиция контейнера полос баффов"
L["Positions"] = "Позиции"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "Настройки границы"
L["Border Texture"] = "Текстура границы"
L["Select Border..."] = "Выбрать границу..."
L["Border Color"] = "Цвет границы"
L["Border Size"] = "Размер границы"
L["Border Offset X"] = "Смещение границы по X"
L["Border Offset Y"] = "Смещение границы по Y"
L["Zoom Icons (Remove Borders & Overlay)"] = "Увеличить иконки (обрезка границ и наложения)"
L["Visual Elements"] = "Визуальные элементы"
L["Hide Debuff Border (red outline on harmful effects)"] = "Скрыть границу дебаффа (красный контур на негативных эффектах)"
L["Hide Pandemic Indicator (animated refresh window border)"] = "Скрыть индикатор пандемии (анимированная граница окна обновления)"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "Скрыть вспышку восстановления (вспышка при завершении восстановления)"
L["* These options require /reload to take effect"] = "* Для применения этих настроек требуется /reload"
L["Borders"] = "Границы"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Text.lua
-----------------------------------------------------------------------

L["Global Settings"] = "Глобальные настройки"
L["Font"] = "Шрифт"
L["Font Outline"] = "Контур шрифта"
L["None"] = "Нет"
L["Outline"] = "Outline"
L["Thick Outline"] = "Thick Outline"
L["Cooldown Timer"] = "Таймер восстановления"
L["Font Size"] = "Размер шрифта"
L["Color"] = "Цвет"
L["Cooldown Stacks (Charges)"] = "Стаки способностей (заряды)"
L["Position"] = "Позиция"
L["Anchor"] = "Якорь"
L["Buff Bars - Name Text"] = "Полосы баффов — текст названия"
L["Buff Bars - Duration Text"] = "Полосы баффов — текст длительности"
L["Buff Bars - Stack Count Text"] = "Полосы баффов — текст количества стаков"
L["Text"] = "Текст"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Glow.lua
-----------------------------------------------------------------------

L["Pixel Glow"] = "Pixel Glow"
L["Autocast Glow"] = "Autocast Glow"
L["Button Glow"] = "Button Glow"
L["Proc Glow"] = "Proc Glow"
L["Glow Settings"] = "Настройки свечения"
L["Glow Type"] = "Тип свечения"
L["Use Custom Color"] = "Использовать свой цвет"
L["Glow Color"] = "Цвет свечения"
L["Pixel Glow Settings"] = "Настройки Pixel Glow"
L["Lines"] = "Линии"
L["Frequency"] = "Частота"
L["Length (0=auto)"] = "Длина (0=авто)"
L["Thickness"] = "Толщина"
L["Autocast Glow Settings"] = "Настройки Autocast Glow"
L["Particles"] = "Частицы"
L["Scale"] = "Масштаб"
L["Button Glow Settings"] = "Настройки Button Glow"
L["Frequency (0=default)"] = "Частота (0=по умолчанию)"
L["Proc Glow Settings"] = "Настройки Proc Glow"
L["Duration (x10)"] = "Длительность (x10)"
L["Glow"] = "Свечение"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "Затухание"
L["Enable Fading"] = "Включить затухание"
L["Fade Trigger"] = "Условие затухания"
L["Fade when no target"] = "Затухание, если нет цели"
L["Fade out of combat"] = "Затухание, если не в бою"
L["Faded Opacity"] = "Прозрачность при затухании"
L["Apply Fading To"] = "Применить затухание к"
L["Buff Bars"] = "Полосы баффов"
L["Racials"] = "Расовые способности"
L["Defensives"] = "Защитные способности"
L["Trinkets"] = "Аксессуары"
L["Resources"] = "Ресурсы"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Assist.lua
-----------------------------------------------------------------------

L["Assist"] = "Помощник"
-- L["Rotation Assist"] = ""
-- L["Enable Rotation Assist"] = ""
-- L["Highlight Size"] = ""
-- L["Keybindings"] = ""
-- L["Enable Keybind Text"] = ""

-----------------------------------------------------------------------
-- Ayije_CDM_Options/BuffGroups.lua & Shared
-----------------------------------------------------------------------

L["Unknown"] = "Неизвестно"
L["Add"] = "Добавить"
L["Border:"] = "Граница:"
L["Enable Glow"] = "Включить свечение"
L["Glow Color:"] = "Цвет свечения:"
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
L["Buff Groups"] = "Группы баффов"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ImportExport.lua
-----------------------------------------------------------------------

L["Serialization failed: %s"] = "Ошибка сериализации: %s"
L["Compression failed: %s"] = "Ошибка сжатия: %s"
L["Base64 encoding failed: %s"] = "Ошибка кодирования Base64: %s"
L["No import string provided"] = "Строка импорта не указана"
L["Invalid Base64 encoding"] = "Некорректная кодировка Base64"
L["Decompression failed"] = "Ошибка распаковки"
L["Invalid profile data"] = "Некорректные данные профиля"
L["Missing profile metadata"] = "Отсутствуют метаданные профиля"
L["Profile is for a different addon: %s"] = "Профиль предназначен для другого аддона: %s"
L["Invalid profile version"] = "Некорректная версия профиля"
L["Failed to import profile"] = "Не удалось импортировать профиль"
L["Imported %d settings as '%s'"] = "Импортировано %d настроек как '%s'"
L["Export Profile"] = "Экспорт профиля"
L["Select categories to include, then click Export."] = "Выберите категории для включения, затем нажмите «Экспорт»."
L["Export"] = "Экспорт"
L["Export String (Ctrl+C to copy):"] = "Строка экспорта (Ctrl+C для копирования):"
L["Profile exported! Copy the string above."] = "Профиль экспортирован! Скопируйте строку выше."
L["Export failed."] = "Экспорт не удался."
L["Import Profile"] = "Импорт профиля"
L["Paste an export string below and click Import."] = "Вставьте строку экспорта ниже и нажмите «Импорт»."
L["Import"] = "Импорт"
L["Clear"] = "Очистить"
-- L["Select at least one category to export."] = ""
-- L["Profile is for a different addon"] = ""
-- L["Type mismatch on key '%s': expected %s, got %s"] = ""
L["Import/Export"] = "Импорт/Экспорт"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Profiles.lua
-----------------------------------------------------------------------

L["Current Profile"] = "Текущий профиль"
L["New Profile"] = "Новый профиль"
L["Create"] = "Создать"
L["Enter a name"] = "Введите название"
L["Already exists"] = "Уже существует"
L["Copy From"] = "Копировать из"
L["Copy all settings from another profile into the current one."] = "Скопировать все настройки из другого профиля в текущий."
L["Select Source..."] = "Выбрать источник..."
L["Manage"] = "Управление"
L["Rename"] = "Переименовать"
L["Reset Profile"] = "Сбросить профиль"
L["Delete Profile..."] = "Удалить профиль..."
L["Default Profile for New Characters"] = "Профиль по умолчанию для новых персонажей"
L["Specialization Profiles"] = "Профили специализаций"
L["Auto-switch profile per specialization"] = "Автоматически переключать профиль по специализации"
L["Spec %d"] = "Специализация %d"
-- L["Failed to apply profile"] = ""
-- L["Profile not found"] = ""
-- L["Cannot copy active profile"] = ""
-- L["Cannot delete active profile"] = ""
L["Profiles"] = "Профили"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "Добавить свое заклинание или предмет"
L["Spell"] = "Заклинание"
L["Item"] = "Предмет"
L["Enter a valid ID"] = "Введите корректный ID"
L["Loading item data, try again"] = "Загрузка данных предмета, попробуйте снова"
L["Unknown spell ID"] = "Неизвестный ID заклинания"
L["Added: %s"] = "Добавлено: %s"
L["Already tracked"] = "Уже отслеживается"
L["Enable Racials"] = "Включить расовые способности"
-- L["Show Items at 0 Stacks"] = ""
L["Tracked Spells"] = "Отслеживаемые заклинания"
L["Manage Spells"] = "Управление заклинаниями"
L["Icon Size"] = "Размер иконки"
L["Icon Width"] = "Ширина иконки"
L["Icon Height"] = "Высота иконки"
L["Party Frame Anchoring"] = "Привязка к фрейму группы"
L["Anchor to Party Frame"] = "Привязать к фрейму группы"
L["Side (relative to Party Frame)"] = "Сторона (относительно фрейма группы)"
L["Party Frame X Offset"] = "Смещение фрейма группы по X"
L["Party Frame Y Offset"] = "Смещение фрейма группы по Y"
L["Anchor Position (relative to Player Frame)"] = "Позиция привязки (относительно фрейма игрока)"
L["Cooldown"] = "Восстановление"
L["Stacks"] = "Стаки"
L["Text Position"] = "Позиция текста"
L["Text X Offset"] = "Смещение текста по X"
L["Text Y Offset"] = "Смещение текста по Y"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Defensives.lua
-----------------------------------------------------------------------

L["Current Spec"] = "Текущая специализация"
L["Add Custom Spell"] = "Добавить свое заклинание"
L["Spell ID"] = "ID заклинания"
L["Enter a valid spell ID"] = "Введите корректный ID заклинания"
L["Not available for spec"] = "Недоступно для данной специализации"
L["Enable Defensives"] = "Включить защитные способности"
L["Hide tracked defensives from Essential/Utility viewers"] = "Скрыть отслеживаемые защитные способности из трекера основных/вспомогательных способностей"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Trinkets.lua
-----------------------------------------------------------------------

L["Independent"] = "Отдельно"
L["Append to Defensives"] = "Добавить к защитным способностям"
L["Append to Spells"] = "Добавить к заклинаниям"
L["Row 1"] = "Ряд 1"
L["Row 2"] = "Ряд 2"
L["Start"] = "Начало"
L["End"] = "Конец"
L["Enable Trinkets"] = "Включить аксессуары"
L["Layout Mode"] = "Режим размещения"
L["Display Mode"] = "Режим отображения"
L["Row"] = "Ряд"
L["Position in Row"] = "Позиция в ряду"
L["Show Passive Trinkets"] = "Показывать пассивные аксессуары"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources.lua
-----------------------------------------------------------------------

L["Background"] = "Фон"
L["Rage"] = "Ярость"
L["Energy"] = "Энергия"
L["Focus"] = "Концентрация"
L["Astral Power"] = "Астральная мощь"
L["Maelstrom"] = "Энергия Водоворота"
L["Insanity"] = "Безумие"
L["Fury"] = "Гнев"
L["Mana"] = "Мана"
L["Essence"] = "Сущность"
L["Essence Recharging"] = "Перезарядка сущности"
L["Combo Points"] = "Серия приемов"
-- L["Charged"] = ""
-- L["Charged Empty"] = ""
L["Holy Power"] = "Энергия Света"
L["Soul Shards"] = "Осколки души"
L["Soul Shards Partial"] = "Осколки души (частичные)"
L["Arcane Charges"] = "Чародейские заряды"
L["Chi"] = "Энергия Ци"
L["Runic Power"] = "Сила рун"
L["Runes Ready"] = "Руны готовы"
L["Runes Recharging"] = "Руны перезаряжаются"
L["Soul Fragments"] = "Фрагменты души"
-- L["Devourer Souls"] = ""
L["Light (<30%)"] = "Лёгкое (<30%)"
L["Moderate (30-60%)"] = "Умеренное (30-60%)"
L["Heavy (>60%)"] = "Тяжёлое (>60%)"
L["Enable Resources"] = "Включить ресурсы"
L["Bar Dimensions"] = "Размеры полосы"
L["Bar 1 Height"] = "Высота полосы 1"
L["Bar 2 Height"] = "Высота полосы 2"
L["Bar Width (0 = Auto)"] = "Ширина полосы (0 = авто)"
L["Bar Spacing (Vertical)"] = "Расстояние между полосами (по вертикали)"
L["Unified Border (wrap all bars)"] = "Единая граница (охватывает все полосы)"
L["Move buffs down dynamically"] = "Динамическое смещение баффов вниз"
L["Show Mana Bar"] = "Показывать полосу маны"
L["Display Mana as %"] = "Отображать ману в %"
L["Bar Texture:"] = "Текстура полосы:"
L["Select Texture..."] = "Выбрать текстуру..."
L["Background Texture:"] = "Текстура фона:"
L["Position Offsets"] = "Смещение позиции"
L["Power Type Colors"] = "Цвета ресурсов"
L["Show All Colors"] = "Показать все цвета"
L["Stagger uses threshold colors: "] = "Для Пошатывания используются пороговые цвета: "
L["Light"] = "Лёгкое"
L["Moderate"] = "Умеренное"
L["Heavy"] = "Тяжёлое"
L["Warrior"] = "Воин"
L["Paladin"] = "Паладин"
L["Hunter"] = "Охотник"
L["Rogue"] = "Разбойник"
L["Priest"] = "Жрец"
L["Death Knight"] = "Рыцарь смерти"
L["Shaman"] = "Шаман"
L["Mage"] = "Маг"
L["Warlock"] = "Чернокнижник"
L["Monk"] = "Монах"
L["Druid"] = "Друид"
L["Demon Hunter"] = "Охотник на демонов"
L["Evoker"] = "Пробудитель"
L["Tags (Power Value Text)"] = "Теги (текст значения ресурса)"
L["Left"] = "Слева"
L["Center"] = "По центру"
L["Right"] = "Справа"
L["Bar %s"] = "Полоса %s"
L["Enable %s Tag (current value)"] = "Включить тег %s (текущее значение)"
L["%s Font Size"] = "Размер шрифта %s"
L["%s Anchor:"] = "Якорь %s:"
L["%s Offset X"] = "Смещение %s по X"
L["%s Offset Y"] = "Смещение %s по Y"
L["%s Text Color"] = "Цвет текста %s"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CustomBuffs.lua
-----------------------------------------------------------------------

L["ID: %s  |  Duration: %ss"] = "ID: %s  |  Длительность: %ss"
L["Remove"] = "Удалить"
L["Custom Timers"] = "Свои таймеры"
L["Track spell casts and display custom buff icons alongside native buffs. Icons appear in the main buff container."] = "Отслеживает применение заклинаний и отображает пользовательские иконки баффов рядом со встроенными. Иконки появляются в основном контейнере баффов."
L["Add Tracked Spell"] = "Добавить отслеживаемое заклинание"
L["Spell ID:"] = "ID заклинания:"
L["Duration (sec):"] = "Длительность (сек):"
L["Add Spell"] = "Добавить заклинание"
L["Invalid spell ID"] = "Некорректный ID заклинания"
L["Enter a valid duration"] = "Введите корректную длительность"
L["Limit reached (9 max)"] = "Достигнут лимит (макс. 9)"
L["Added!"] = "Добавлено!"
L["Failed - invalid spell ID"] = "Ошибка — некорректный ID заклинания"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "Размеры"
L["Bar Height"] = "Высота полосы"
L["Bar Spacing"] = "Расстояние между полосами"
L["Appearance"] = "Внешний вид"
L["Bar Color"] = "Цвет полосы"
L["Background Color"] = "Цвет фона"
L["Growth Direction:"] = "Направление роста:"
L["Down"] = "Вниз"
L["Up"] = "Вверх"
L["Icon Position:"] = "Позиция иконки:"
L["Hidden"] = "Скрыто"
L["Icon-Bar Gap"] = "Расстояние между иконкой и полосой"
L["Dual Bar Mode (2 bars per row)"] = "Режим «двойной полосы» (2 полосы в ряду)"
L["Show Buff Name"] = "Показывать название баффа"
L["Show Duration Text"] = "Показывать текст длительности"
L["Show Stack Count"] = "Показывать количество стаков"
L["Notes"] = "Примечания"
L["Border settings: see Borders tab"] = "Настройки границы: см. вкладку «Границы»"
L["Text styling (font size, color, offsets): see Text tab"] = "Оформление текста (размер шрифта, цвет, смещения): см. вкладку «Текст»"
L["Position lock and X/Y controls: see Positions tab"] = "Блокировка позиции и перемещение по X/Y: см. вкладку «Позиции»"
L["Bars"] = "Полосы"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CastBar.lua
-----------------------------------------------------------------------

L["Enable Cast Bar"] = "Включить полосу заклинания"
L["Hide Blizzard Cast Bar"] = "Скрыть стандартную полосу заклинания"
L["Width (0 = Auto)"] = "Ширина (0 = авто)"
L["Spell Icon"] = "Иконка заклинания"
L["Show Spell Icon"] = "Показывать иконку заклинания"
L["Bar Texture"] = "Текстура полосы"
L["Use Blizzard Atlas Textures"] = "Использовать текстуры Blizzard Atlas"
L["Cast Color"] = "Цвет применения"
L["Channel Color"] = "Цвет потокового применения"
L["Uninterruptible Color"] = "Цвет непрерываемого заклинания"
L["Anchor to Resource Bars"] = "Привязать к полосам ресурсов"
L["Y Spacing"] = "Расстояние по Y"
L["Lock Position"] = "Заблокировать позицию"
L["Show Spell Name"] = "Показывать название заклинания"
L["Name X Offset"] = "Смещение названия по X"
L["Name Y Offset"] = "Смещение названия по Y"
L["Show Timer"] = "Показывать таймер"
L["Timer X Offset"] = "Смещение таймера по X"
L["Timer Y Offset"] = "Смещение таймера по Y"
L["Show Spark"] = "Показывать искру"
L["Empowered Stages"] = "Фазы усиления"
L["Wind Up Color"] = "Цвет подготовки"
L["Stage 1 Color"] = "Цвет фазы 1"
L["Stage 2 Color"] = "Цвет фазы 2"
L["Stage 3 Color"] = "Цвет фазы 3"
L["Stage 4 Color"] = "Цвет фазы 4"
-- L["Class Color"] = ""
L["Cast Bar"] = "Полоса заклинания"

-----------------------------------------------------------------------
