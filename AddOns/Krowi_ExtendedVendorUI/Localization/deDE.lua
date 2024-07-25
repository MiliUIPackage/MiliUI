local addonName, addon = ...;
local L = LibStub(addon.Libs.AceLocale):NewLocale(addonName, "deDE");
if not L then return end
addon.L = L;

addon.Plugins:LoadLocalization(L);

-- [[ https://legacy.curseforge.com/wow/addons/krowi-extended-vendor-ui/localization ]] --
-- [[ Everything after this line is automatically generated from CurseForge and is not meant for manual edit - SOURCETOKEN - AUTOGENTOKEN ]] --

-- [[ Exported at 2023-11-20 23-09-37 ]] --
L["Are you sure you want to hide the options button?"] = "Bist du sicher, dass du die Schaltfläche \"Optionen\" ausblenden möchtest? Die Schaltfläche \"Optionen\" kann wieder eingeblendet werden über {gameMenu} {arrow} {interface} {arrow} {addOns} {arrow} {addonName} {arrow} {general} {arrow} {options} "
L["Author"] = "Autor "
L["Build"] = "Version "
L["Checked"] = "Aktivert "
L["Columns"] = "Spalten"
L["Columns first"] = "Spalten zuerst"
L["CurseForge"] = "CurseForge "
L["CurseForge Desc"] = "Öffnet ein Popup-Fenster mit einem Link zur Seite {addonName} {curseForge}. "
L["Default value"] = "Vorgabewert (Standard) "
L["Discord"] = "Discord "
L["Discord Desc"] = "Öffnet ein Popup-Fenster mit einem Link zum {serverName} Discord-Server. Hier können Sie Kommentare, Berichte, Bemerkungen, Ideen und alles andere posten. "
L["Hide"] = "Ausblenden"
L["Icon Left click"] = "für schnelle Layout-Optionen."
L["Icon Right click"] = "für die Optionen. "
L["Options button"] = "Optionen-Schaltfäche "
L["Options Desc"] = "Öffnen Sie die Optionen, die auch über die Optionen-Schaltfläche im Händlerfenster verfügbar sind."
L["Right click"] = "Rechts-Klick "
L["Rows"] = "Reihen"
L["Rows first"] = "Reihen zuerst"
L["Show minimap icon"] = "Zeige Minimap Icon "
L["Show minimap icon Desc"] = "Zeige / Verstecke das Minimap Icon. "
L["Show options button"] = "Zeige Optionen Schaltfläche "
L["Show options button Desc"] = "Ein-/Ausblenden der Optionen-Schaltfläche im Händlerfenster."
L["Unchecked"] = "Nicht aktiviert "
L["Wago"] = "Wago "
L["Wago Desc"] = "Öffnet ein Popup-Fenster mit einem Link zur Seite {addonName} {wago}. "
L["WoWInterface"] = "WoWInterface "
L["WoWInterface Desc"] = "Öffnet ein Popup-Fenster mit einem Link zur Seite {addonName} {woWInterface}. "