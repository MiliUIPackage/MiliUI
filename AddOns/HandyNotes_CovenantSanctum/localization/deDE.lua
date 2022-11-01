local L = LibStub("AceLocale-3.0"):NewLocale("HandyNotes_CovenantSanctum", "deDE", false, true)

if not L then return end
-- German Translation by Dathwada EU-Eredar
if L then
----------------------------------------------------------------------------------------------------
-----------------------------------------------CONFIG-----------------------------------------------
----------------------------------------------------------------------------------------------------

L["config_plugin_name"] = "Covenant Sanctum"
L["config_plugin_desc"] = "Zeigt die Positionen von NPCs und anderer POIs im Paktsanktum auf der Weltkarte und Minimap an."

L["config_tab_general"] = "Allgemein"
L["config_tab_scale_alpha"] = "Größe / Transparenz"
--L["config_scale_alpha_desc"] = "PH"
L["config_icon_scale"] = "Symbolgröße"
L["config_icon_scale_desc"] = "Die größe der Symbole"
L["config_icon_alpha"] = "Symboltransparenz"
L["config_icon_alpha_desc"] = "Die Transparenz der Symbole"
L["config_what_to_display"] = "Was soll angezeigt werden?"
L["config_what_to_display_desc"] = "Diese Einstellungen legen fest welche Symbole auf der Welt- und Minimap angezeigt werden sollen."

L["config_innkeeper"] = "Gastwirte"
L["config_innkeeper_desc"] = "Zeigt die Positionen der Gastwirte an."

L["config_mail"] = "Briefkästen"
L["config_mail_desc"] = "Zeigt die Positionen der Briefkästen an."

L["config_portal"] = "Portale"
L["config_portal_desc"] = "Zeigt die Positionen der Portal an."

L["config_travelguide_note"] = "|cFFFF0000*Bereits durch HandyNotes: TravelGuide aktiv.|r"

L["config_reforge"] = "Rüstungsverbesserer"
L["config_reforge_desc"] = "Zeigt die Position des Rüstungsverbesserers an."

L["config_renown"] = "Hüter/in des Ruhms"
L["config_renown_desc"] = "Zeigt die Positionen der Hüter/in des Ruhms an."

L["config_stablemaster"] = "Stallmeister"
L["config_stablemaster_desc"] = "Zeigt die Positionen der Stallmeister an."

L["config_vendor"] = "Händler"
L["config_vendor_desc"] = "Zeigt die Position von Händlern an."

L["config_weaponsmith"] = "Waffenschmiede"
L["config_weaponsmith_desc"] = "Zeigt die Positionen von Waffenschmieden an."

L["config_easy_waypoints"] = "Vereinfachte Wegpunkte"
L["config_easy_waypoints_desc"] = "Aktiviert die vereinfachte Wegpunkterstellung. \nErlaubt es per Rechtsklick einen Wegpunkt zu setzen und per STRG + Rechtsklick mehr Optionen aufzurufen."
L["config_waypoint_dropdown"] = "Wähle aus"
L["config_waypoint_dropdown_desc"] = "Wähle aus, wie der Wegpunkt erstellt werden soll."
L["Blizzard"] = true
L["TomTom"] = true
L["Both"] = "Beide"

L["config_others"] = "Anderes"
L["config_others_desc"] = "Zeige alle anderen POIs."

L["config_restore_nodes"] = "Versteckte Punkte wiederherstellen"
L["config_restore_nodes_desc"] = "Stellt alle Punkte wieder her, die über das Kontextmenü versteckt wurden."
L["config_restore_nodes_print"] = "Alle versteckten Punkte wurden wiederhergestellt."

----------------------------------------------------------------------------------------------------
-------------------------------------------------DEV------------------------------------------------
----------------------------------------------------------------------------------------------------

L["dev_config_tab"] = "DEV"

L["dev_config_force_nodes"] = "Erzwinge Punkte"
L["dev_config_force_nodes_desc"] = "Erzwingt die Anzeige aller Punkte unabhängig von Klasse, Fraktion oder Pakt."

L["dev_config_show_prints"] = "Zeige print()"
L["dev_config_show_prints_desc"] = "Zeigt print() Nachrichten im Chatfenster an."

----------------------------------------------------------------------------------------------------
-----------------------------------------------HANDLER----------------------------------------------
----------------------------------------------------------------------------------------------------

--==========================================CONTEXT_MENU==========================================--

L["handler_context_menu_addon_name"] = "HandyNotes: Covenant Sanctum"
L["handler_context_menu_add_tomtom"] = "Zu TomTom hinzufügen"
L["handler_context_menu_add_map_pin"] = "Kartenmarkierung setzen"
L["handler_context_menu_hide_node"] = "Verstecke diesen Punkt"

--============================================TOOLTIPS============================================--

L["handler_tooltip_requires"] = "Benötigt"
L["handler_tooltip_sanctum_feature"] = "eine Sanktumaufwertung"
L["handler_tooltip_TNTIER"] = "Stufe %s des Reisenetzwerks."

----------------------------------------------------------------------------------------------------
----------------------------------------------DATABASE----------------------------------------------
----------------------------------------------------------------------------------------------------

L["Portal to Oribos"] = "Portal nach Oribos"
L["Mailbox"] = "Briefkasten"

end