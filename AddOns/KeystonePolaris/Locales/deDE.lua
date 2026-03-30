local AddonName, Engine = ...;

local LibStub = LibStub;
local AceLocale = LibStub:GetLibrary("AceLocale-3.0");
local L = AceLocale:NewLocale(AddonName, "deDE", false, false);
if not L then return end

-- TRANSLATION REQUIRED

-- Temporary locales for Midnight Compatibility Warning
L["COMPATIBILITY_WARNING"] = "Midnight Compatibility Warning"
L["COMPATIBILITY_WARNING_MESSAGE"] = "|cffff0000Some features are disabled on Midnight for now due to API restrictions:|r\n\n" ..
                                "|cff8888ff• Mob percentages on nameplates (MDT Integration)|r\n" ..
                                "|cff8888ff• Current pull tracking|r\n" ..
                                "|cff8888ff• Projected values|r\n\n" ..
                                "|cff8888ffThese features will be re-enabled once Blizzard releases the new Mythic+ API. There is currently no ETA for this.|r\n\n" ..
                                "All other features should remain available, sorry for the inconvenience.\n"

-- Dungeon Group
L["DUNGEONS"] = "Dungeons"
L["CURRENT_SEASON"] = "Aktuelle Saison"
L["NEXT_SEASON"] = "Nächste Saison"
L["REMIX"] = "Remix" -- To Translate
L["SEASON_ENDS_IN_ONE_MONTH"] = "Current season ends in less than one month." -- To Translate
L["SEASON_ENDS_IN_WEEKS"] = "Current season ends in less than %d weeks." -- To Translate
L["SEASON_ENDS_IN_DAYS"] = "Current season ends in %d days." -- To Translate
L["SEASON_ENDS_IN_TOMORROW"] = "Current season ends tomorrow." -- To Translate
L["SEASON_STARTS_IN_ONE_MONTH"] = "Next season starts in less than one month." -- To Translate
L["SEASON_STARTS_IN_WEEKS"] = "Next season starts in less than %d weeks." -- To Translate
L["SEASON_STARTS_IN_DAYS"] = "Next season starts in %d days." -- To Translate
L["SEASON_STARTS_IN_TOMORROW"] = "Next season starts tomorrow." -- To Translate

L["EXPANSION_MIDNIGHT"] = "Midnight"
L["EXPANSION_WW"] = "The War Within"
L["EXPANSION_DF"] = "Dragonflight"
L["EXPANSION_SL"] = "Shadowlands"
L["EXPANSION_BFA"] = "Battle for Azeroth"
L["EXPANSION_LEGION"] = "Legion"
L["EXPANSION_WOD"] = "Warlords of Draenor"
L["EXPANSION_CATA"] = "Cataclysm"
L["EXPANSION_WOTLK"] = "Wrath of the Lich King"

-- UI Strings
L["MODULES"] = "Module" -- To Translate
L["MODULES_SUMMARY_HEADER"] = "Modules overview" -- To Translate
L["MODULES_SUMMARY_DESC"] = "Quick tour of available modules:\n\n• MythicDungeonTools Integration\n  > Mob Percentages\n\n• Group Reminder" -- To Translate
L["FINISHED"] = "Dungeon-Prozentsatz erreicht"
L["SECTION_DONE"] = "Abschnitt abgeschlossen"
L["DONE"] = "Abschnittsprozentsatz erreicht"
L["DUNGEON_DONE"] = "Dungeon abgeschlossen"
L["OPTIONS"] = "Optionen"
L["GENERAL_SETTINGS"] = "Allgemeine Einstellungen"
L["Changelog"] = "Änderungsprotokoll"
L["Version"] = "Version"
L["Important"] = "Wichtig"
L["New"] = "Neu"
L["Bugfixes"] = "Fehlerbehebungen"
L["Improvment"] = "Verbesserungen"
L["%month%-%day%-%year%"] = "%day%.%month%.%year%"   -- deutsches Datumsformat
L["DEFAULT_PERCENTAGES"] = "Standard-Prozentsätze"
L["DEFAULT_PERCENTAGES_DESC"] = "This view shows the addon's built-in defaults and does not reflect your custom routes configuration." -- To Translate
L["ROUTES_DISCLAIMER"] = "By default, Keystone Polaris uses Raider.IO Weekly Routes (Beginner). Custom routes let you define your own different routes. To enable these routes, make sure to enable \"Custom routes\" in the addon's General Settings." -- To Translate
L["ADVANCED_SETTINGS"] = "Benutzerdefinierte Routen"
L["TANK_GROUP_HEADER"] = "Boss-Prozentsätze"
L["ROLES_ENABLED"] = "Benötigte Rolle(n)"
L["ROLES_ENABLED_DESC"] = "Wähle, welche Rollen die Prozente sehen und die Gruppe informieren sollen"
L["LEADER"] = "Anführer"
L["TANK"] = "Tank"
L["HEALER"] = "Heiler"
L["DPS"] = "Schaden"
L["ENABLE"] = "Aktivieren"
L["ENABLE_ADVANCED_OPTIONS"] = "Benutzerdefinierte Routen aktivieren"
L["ADVANCED_OPTIONS_DESC"] = "Ermöglicht es dir, eigene Prozentsätze festzulegen, die vor jedem Boss erreicht werden sollen, und zu wählen, ob die Gruppe über fehlende Prozente informiert wird"
L["INFORM_GROUP"] = "Gruppe informieren"
L["INFORM_GROUP_DESC"] = "Sendet Nachrichten in den Chat, wenn Prozente fehlen"
L["SHOW_INFORM_GROUP_BUTTON"] = "Inform Group Button" -- TODO: To Translate
L["SHOW_INFORM_GROUP_BUTTON_DESC"] = "Show the Inform Group button on the addon's display" -- TODO: To Translate
L["MESSAGE_CHANNEL"] = "Chat-Kanal"
L["MESSAGE_CHANNEL_DESC"] = "Wähle, welchen Chat-Kanal du für Benachrichtigungen verwenden möchtest"
L["PARTY"] = "Gruppe"
L["SAY"] = "Sagen"
L["YELL"] = "Schreien"
L["PERCENTAGE"] = "Prozentsatz"
L["PERCENTAGE_DESC"] = "Die Textgröße anpassen"
L["FONT"] = "Schriftart"
L["FONT_SIZE"] = "Textgröße"
L["FONT_SIZE_DESC"] = "Die Textgröße anpassen"
L["POSITIONING"] = "Positionierung"
L["COLORS"] = "Farben"
L["IN_PROGRESS"] = "In Arbeit"
L["MISSING"] = "Fehlend"
L["FINISHED_COLOR"] = "Done" -- To Translate
L["VALIDATE"] = "Bestätigen"
L["CANCEL"] = "Abbrechen"
L["POSITION"] = "Position"
L["TOP"] = "Oben"
L["CENTER"] = "Mitte"
L["BOTTOM"] = "Unten"
L["X_OFFSET"] = "X-Versatz"
L["Y_OFFSET"] = "Y-Versatz"
L["SHOW_ANCHOR"] = "Anker zur Positionierung anzeigen"
L["ANCHOR_TEXT"] = "< KPL Anker >"
L["RESET_DUNGEON"] = "Auf Standard zurücksetzen"
L["RESET_DUNGEON_DESC"] = "Setzt alle Boss-Prozentsätze in diesem Dungeon auf ihre Standardwerte zurück"
L["RESET_DUNGEON_CONFIRM"] = "Bist du sicher, dass du alle Boss-Prozentsätze in diesem Dungeon auf die Standardwerte zurücksetzen möchtest?"
L["RESET_ALL_DUNGEONS"] = "Alle Dungeons zurücksetzen"
L["RESET_ALL_DUNGEONS_DESC"] = "Setzt alle Dungeons auf ihre Standardwerte zurück"
L["RESET_ALL_DUNGEONS_CONFIRM"] = "Bist du sicher, dass du alle Dungeons auf die Standardwerte zurücksetzen möchtest?"
L["NEW_SEASON_RESET_PROMPT"] = "Eine neue Mythisch+-Saison hat begonnen. Möchtest du alle Dungeon-Werte auf die Standardwerte zurücksetzen?"
L["YES"] = "Ja"
L["NO"] = "Nein"
L["WE_STILL_NEED"] = "Es fehlen noch"
L["NEW_ROUTES_RESET_PROMPT"] = "Die Standardrouten der Dungeons wurden in dieser Version aktualisiert. Möchtest du deine aktuellen Dungeon-Routen auf die neuen Standardwerte zurücksetzen?"
L["RESET_ALL"] = "Alle zurücksetzen"
L["RESET_CHANGED_ONLY"] = "Nur geänderte zurücksetzen"
L["CHANGED_ROUTES_DUNGEONS_LIST"] = "Folgende Dungeons haben aktualisierte Routen:"-- Export/Import
L["BOSS"] = "Boss"
L["BOSS_ORDER"] = "Boss Order"
L["SHOW_COMPARTMENT_ICON"] = "Compartment icon"
L["SHOW_MINIMAP_ICON"] = "Minimap icon"
L["NEW_ROUTES_ALL_SEASON_PROMPT"] = "All dungeon routes for the current season have been updated. Do you want to reset all values to the new defaults?" -- TODO: To Translate

-- Commands / Help
L["COMMANDS_HEADER"] = "Commands"
L["COMMANDS_HELP_DESC"] = "Available slash commands:\n• /kpl or /polaris - Open options\n• /kpl reminder or /polaris reminder - Show last group reminder\n• /kpl help or /polaris help - Show this help"
L["COMMANDS_HELP_OPEN"] = "/kpl or /polaris - Open options"
L["COMMANDS_HELP_CHANGELOG"] = "/kpl changelog or /polaris changelog - Open changelog"
L["COMMANDS_HELP_REMINDER"] = "/kpl reminder or /polaris reminder - Show last group reminder"
L["COMMANDS_HELP_HELP"] = "/kpl help or /polaris help - Show this help"

-- Changelog (TO TRANSLATE)
L["COPY_INSTRUCTIONS"] = "Select All, then Ctrl+C to copy. Optional: DeepL https://www.deepl.com/translator"
L["SELECT_ALL"] = "Select All"
L["TRANSLATE"] = "Translate"
L["TRANSLATE_DESC"] = "Copy this changelog in a popup to paste into your translator."

-- Test Mode (TO TRANSLATE)
L["TEST_MODE"] = "Test Mode"
L["TEST_MODE_OVERLAY"] = "Keystone Polaris: Test Mode"
L["TEST_MODE_OVERLAY_HINT"] = "Preview is simulated. Right-click this hint to exit test mode and reopen settings."
L["TEST_MODE_DESC"] = "Show a live preview of your display configuration without being in a dungeon. This will:\n• Close the settings panel to reveal the preview\n• Show a dim overlay and a hint above the display\n• Simulate combat/out-of-combat every 3s to reveal projected values and pull%\nTip: Right-click the hint to exit Test Mode and reopen settings."
L["TEST_MODE_DISABLED"] = "Test Mode disabled automatically%s"
L["TEST_MODE_REASON_ENTERED_COMBAT"] = "entered combat"
L["TEST_MODE_REASON_STARTED_DUNGEON"] = "started dungeon"
L["TEST_MODE_REASON_CHANGED_ZONE"] = "changed zone"

-- Main Display
L["MAIN_DISPLAY"] = "Main Display"
L["SHOW_REQUIRED_PREFIX"] = "Show required text prefix"
L["SHOW_REQUIRED_PREFIX_DESC"] = "When the base value is numeric (e.g., 12.34%), prefix it with a label (e.g., 'Required:'). No prefix is added for DONE/SECTION/DUNGEON states."
L["LABEL"] = "Prefix"
L["REQUIRED_LABEL_DESC"] = "Label displayed before the numeric required percentage (e.g., 'Required: 12.34%').\n\nClear the field to reset to the default value."
L["SHOW_CURRENT_PERCENT"] = "Show current %"
L["SHOW_CURRENT_PERCENT_DESC"] = "Display the current overall enemy forces percent (from the scenario tracker)."
L["CURRENT_LABEL_DESC"] = "Label displayed before the current percentage value.\n\nClear the field to reset to the default value."
L["SHOW_CURRENT_PULL_PERCENT"] = "Show current pull % (MDT)"
L["SHOW_CURRENT_PULL_PERCENT_DESC"] = "Display the real current pull percent based on engaged mobs using MDT data."
L["PULL_LABEL_DESC"] = "Label displayed before the current pull percentage value.\n\nClear the field to reset to the default value."
L["USE_MULTI_LINE_LAYOUT"] = "Use multi-line layout"
L["USE_MULTI_LINE_LAYOUT_DESC"] = "Show each selected value on a new line."
L["SHOW_PROJECTED"] = "Show projected values"
L["SHOW_PROJECTED_DESC"] = "Append projected values: Current shows (Current + Pull). Required shows (Required - Pull)."
L["SINGLE_LINE_SEPARATOR"] = "Single-line separator"
L["SINGLE_LINE_SEPARATOR_DESC"] = "Separator used between items when not using multi-line layout."
L["FONT_ALIGN"] = "Font align"
L["FONT_ALIGN_DESC"] = "Horizontal alignment for the display text."
L["PREFIX_COLOR"] = "Prefixes color"
L["PREFIX_COLOR_DESC"] = "Color applied to labels/prefixes (Required, Current, Pull)."
L["MAX_WIDTH"] = "Max width (single-line)"
L["MAX_WIDTH_DESC"] = "Maximum width in pixels for single-line layout. 0 = automatic (no wrapping)."
L["REQUIRED_DEFAULT"] = "Required:"
L["SECTION_REQUIRED_DEFAULT"] = "Total required for section:"
L["CURRENT_DEFAULT"] = "Current:"
L["PULL_DEFAULT"] = "Pull:"

-- Section required prefix
L["SHOW_SECTION_REQUIRED_PREFIX"] = "Show section required"
L["SHOW_SECTION_REQUIRED_PREFIX_DESC"] = "Display the current overall enemy forces percent required for the current section without taking into account the progress already done."
L["SECTION_REQUIRED_LABEL_DESC"] = "Label displayed before the section required value.\n\nClear the field to reset to the default value."
L["SECTION_REQUIRED_DEFAULT"] = "Total required for section:"

L["FORMAT_MODE"] = "Text format"
L["FORMAT_MODE_DESC"] = "Select how to display the progress."
L["COUNT"] = "Count"

-- Export/Import
L["EXPORT_DUNGEON"] = "Dungeon exportieren"
L["EXPORT_DUNGEON_DESC"] = "Benutzerdefinierte Prozentsätze für diesen Dungeon exportieren"
L["IMPORT_DUNGEON"] = "Dungeon importieren"
L["IMPORT_DUNGEON_DESC"] = "Benutzerdefinierte Prozentsätze für diesen Dungeon importieren"
L["EXPORT_ALL_DUNGEONS"] = "Alle Dungeons exportieren"
L["EXPORT_ALL_DUNGEONS_DESC"] = "Einstellungen für alle Dungeons exportieren."
L["EXPORT_ALL_DIALOG_TEXT"] = "Kopiere den untenstehenden Text, um deine benutzerdefinierten Prozentsätze für alle Dungeons zu teilen:"
L["IMPORT_ALL_DUNGEONS"] = "Alle Dungeons importieren"
L["IMPORT_ALL_DUNGEONS_DESC"] = "Einstellungen für alle Dungeons importieren."
L["IMPORT_ALL_DIALOG_TEXT"] = "Füge den untenstehenden Text ein, um benutzerdefinierte Prozentsätze für alle Dungeons zu importieren:"
L["EXPORT_SECTION"] = "Abschnitt exportieren"
L["EXPORT_SECTION_DESC"] = "Alle Dungeon-Einstellungen für %s exportieren."
L["EXPORT_SECTION_DIALOG_TEXT"] = "Kopiere den untenstehenden Text, um deine benutzerdefinierten Prozentsätze für %s zu teilen:"
L["IMPORT_SECTION"] = "Abschnitt importieren"
L["IMPORT_SECTION_DESC"] = "Alle Dungeon-Einstellungen für %s importieren."
L["IMPORT_SECTION_DIALOG_TEXT"] = "Füge den untenstehenden Text ein, um benutzerdefinierte Prozentsätze für %s zu importieren:"
L["EXPORT_DIALOG_TEXT"] = "Kopiere den untenstehenden Text, um deine benutzerdefinierten Prozentsätze zu teilen:"
L["IMPORT_DIALOG_TEXT"] = "Füge den exportierten Text unten ein:"
L["IMPORT_SUCCESS"] = "Benutzerdefinierte Route für %s importiert."
L["IMPORT_ALL_SUCCESS"] = "Benutzerdefinierte Routen für alle Dungeons importiert."
L["IMPORT_ERROR"] = "Ungültiger Import-Text"
L["IMPORT_DIFFERENT_DUNGEON"] = "Einstellungen für %s importiert. Optionen für diesen Dungeon werden geöffnet."

-- MDT Integration
L["MDT_INTEGRATION_FEATURES"] = "Mythic Dungeon Tools Integrationsfunktionen"
L["MOB_PERCENTAGES_INFO"] = "• |cff00ff00Gegner-Prozente|r: Zeigt den Beitrag zur Gegnerstärke in Prozent auf den Namensplaketten in M+-Dungeons an."
L["MOB_INDICATOR_INFO"] = "• |cff00ff00Gegner-Indikatoren|r: Markiert Namensplaketten, um anzuzeigen, welche Gegner im aktuellen MDT-Pull enthalten sind."

-- -- Mob-Prozente
L["MOB_PERCENTAGES"] = "Gegner-Prozente"
L["ENABLE_MOB_PERCENTAGES"] = "Gegner-Prozente aktivieren"
L["ENABLE_MOB_PERCENTAGES_DESC"] = "Zeigt den prozentualen Beitrag jedes Mobs in Mythic+-Dungeons an"
L["MOB_PERCENTAGE_FONT_SIZE"] = "Textgröße"
L["MOB_PERCENTAGE_FONT_SIZE_DESC"] = "Legt die Textgröße für die Gegner-Prozente fest"
L["MOB_PERCENTAGE_POSITION"] = "Position"
L["MOB_PERCENTAGE_POSITION_DESC"] = "Legt die Position des Prozenttextes relativ zur Namensplakette fest"
L["RIGHT"] = "Rechts"
L["LEFT"] = "Links"
L["TOP"] = "Oben"
L["BOTTOM"] = "Unten"
L["MDT_WARNING"] = "Für diese Funktion muss das Addon Mythic Dungeon Tools (MDT) installiert sein."
L["MDT_FOUND"] = "Mythic Dungeon Tools gefunden. Gegner-Prozente verwenden nun MDT-Daten."
L["MDT_LOADED"] = "Mythic Dungeon Tools erfolgreich geladen."
L["MDT_NOT_FOUND"] = "Mythic Dungeon Tools nicht gefunden. Gegner-Prozente werden nicht angezeigt. Bitte MDT installieren, damit diese Funktion funktioniert."
L["MDT_INTEGRATION"] = "MDT-Integration"
L["MDT_SECTION_WARNING"] = "Dieser Abschnitt erfordert das Addon Mythic Dungeon Tools (MDT)."
L["DISPLAY_OPTIONS"] = "Anzeigeoptionen"
L["APPEARANCE_OPTIONS"] = "Darstellungsoptionen"
L["SHOW_PERCENTAGE"] = "Prozente anzeigen"
L["SHOW_PERCENTAGE_DESC"] = "Zeigt den Prozentwert für jeden Gegner an"
L["SHOW_COUNT"] = "Zähler anzeigen"
L["SHOW_COUNT_DESC"] = "Zeigt den Zählerwert für jeden Gegner an"
L["SHOW_TOTAL"] = "Gesamtwert anzeigen"
L["SHOW_TOTAL_DESC"] = "Zeigt den Gesamtwert an, der für 100 % benötigt wird"
L["TEXT_COLOR"] = "Textfarbe"
L["TEXT_COLOR_DESC"] = "Legt die Farbe des Namensplakettentextes fest"
L["CUSTOM_FORMAT"] = "Textformat"
L["CUSTOM_FORMAT_DESC"] = "Gib ein benutzerdefiniertes Format ein. Verwende %s für Prozente, %c für Zähler und %t für Gesamtwert. Beispiele: (%s), %s | %c/%t, %c, usw."
L["RESET_TO_DEFAULT"] = "Zurücksetzen"
L["RESET_FORMAT_DESC"] = "Setzt das Textformat auf den Standardwert (Klammern) zurück"

-- Group Reminder (Popup labels)
L["KPL_GR_HEADER"] = "Group Reminder"
L["KPL_GR_TELEPORT_UNKNOWN"] = "Teleport spell not known"
L["KPL_GR_OPEN_REMINDER"] = "Open reminder"
L["KPL_GR_INVITED"] = "You have been invited to"
L["KPL_GR_AS_ROLE"] = "as a %s"
L["KPL_GR_SHOW_POPUP_WHEN_FULL"] = "Show popup again when the group is full" -- TODO: To Translate
L["KPL_GR_SHOW_POPUP_WHEN_FULL_DESC"] = "Reopen the reminder window when your Mythic+ group reaches 5 players." -- TODO: To Translate
L["KPL_GR_CHAT_COMMAND_INFO"] = "Tip: use |cffffd100/kpl reminder|r to show the last group reminder again." -- TODO: To Translate

-- Group Reminder (Options)
L["KPL_GR_DESC_LONG"] = "Displays a reminder popup and/or chat message when you are accepted into a Mythic+ group, with a button to teleport to the dungeon."
L["KPL_GR_NOTIFICATIONS"] = "Notifications"
L["KPL_GR_SUPPRESS_TOAST"] = "Suppress Blizzard quick-join toast"
L["KPL_GR_SUPPRESS_TOAST_DESC"] = "Hide the default Blizzard popup that appears at the bottom of the screen when invited."
L["KPL_GR_SHOW_POPUP"] = "Show popup"
L["KPL_GR_SHOW_POPUP_DESC"] = "Display the reminder window in the center of the screen."
L["KPL_GR_SHOW_CHAT"] = "Show chat message"
L["KPL_GR_SHOW_CHAT_DESC"] = "Print the reminder details in the chat window."
L["KPL_GR_TEST_CURRENT_SEASON"] = "Simulate current season acceptance"
L["KPL_GR_TEST_CURRENT_SEASON_DESC"] = "Show the group reminder using a dungeon from the current season."
L["KPL_GR_CONTENT"] = "Content"
L["KPL_GR_SHOW_DUNGEON"] = "Show dungeon name"
L["KPL_GR_SHOW_GROUP"] = "Show group name"
L["KPL_GR_SHOW_DESC"] = "Show group description"
L["KPL_GR_SHOW_ROLE"] = "Show applied role"
L["KPL_GR_SHOW_PLAYSTYLE"] = "Show group playstyle" -- TODO: To Translate
