local CDM = _G["Ayije_CDM"]
local L = CDM:NewLocale("deDE")
if not L then return end

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Enabled Blizzard Cooldown Manager."] = "Blizzard-Abklingzeitenmanager aktiviert."
--L["Config open queued until combat ends."] = "Config open queued until combat ends."
--L["Config open queued until login setup finishes."] = "Config open queued until login setup finishes."
L["Could not load options: %s"] = "Optionen konnten nicht geladen werden: %s"

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "Bearbeitungsmodus gesperrt"
L["use /acdm"] = "benutze /acdm"
L["Edit Mode locked - use /acdm"] = "Bearbeitungsmodus gesperrt – benutze /acdm"
L["Cooldown Viewer settings are managed by /acdm."] = "Abklingzeitenanzeige-Einstellungen werden durch /acdm verwaltet."

-----------------------------------------------------------------------
-- Modules/BuffGroupOverlays.lua
-----------------------------------------------------------------------

--L["Ungrouped"] = "Ungrouped"

-----------------------------------------------------------------------
-- Modules/PlayerCastBar.lua
-----------------------------------------------------------------------

L["Preview Cast"] = "Zaubervorschau"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Init.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "Konfiguration kann nicht im Kampf geöffnet werden"
L["Invalid profile data"] = "Ungültige Profildaten"
L["Copy this URL:"] = "Diese URL kopieren:"
L["Close"] = "Schließen"
L["Reset the current profile to default settings?"] = "Das aktuelle Profil auf Standardeinstellungen zurücksetzen?"
L["Reset"] = "Zurücksetzen"
L["Cancel"] = "Abbrechen"
L["Copy"] = "Kopieren"
L["Delete"] = "Löschen"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ConfigFrame.lua
-----------------------------------------------------------------------

L["Cannot %s while in combat"] = "Kann %s nicht im Kampf"
L["open CDM config"] = "CDM-Konfiguration öffnen"
L["Display"] = "Anzeige"
L["Styling"] = "Gestaltung"
L["Buffs"] = "Buffs"
L["Features"] = "Funktionen"
L["Utility"] = "Unterstützung"
L["Cooldown Manager"] = "Abklingzeitenmanager"
L["Settings"] = "Einstellungen"
--L["Edit Mode Settings"] = "Edit Mode Settings"
L["rebuild CDM config"] = "CDM-Konfiguration neu aufbauen"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Sizes.lua
-----------------------------------------------------------------------

L["Essential"] = "Essential"
L["Row 1 Width"] = "Reihe 1 Breite"
L["Row 1 Height"] = "Reihe 1 Höhe"
L["Row 2 Width"] = "Reihe 2 Breite"
L["Row 2 Height"] = "Reihe 2 Höhe"
L["Width"] = "Breite"
L["Height"] = "Höhe"
L["Buff"] = "Buff"
L["Icon Sizes"] = "Symbolgröße"

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
L["Layout Settings"] = "Layout-Einstellungen"
L["Icon Spacing"] = "Symbolabstand"
L["Max Icons Per Row"] = "Max. Symbole pro Reihe"
L["Wrap Utility Bar"] = "Unterstützungsleiste umbrechen"
L["Utility Max Icons Per Row"] = "Unterstützung Max. Symbole pro Reihe"
L["Unlock Utility Bar"] = "Unterstützungleiste entsperren"
L["Utility X Offset"] = "Unterstützung X-Versatz"
L["Display Vertical"] = "Vertikal anzeigen"
L["Layout"] = "Layout"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Positions.lua
-----------------------------------------------------------------------

L["Current: %s (%d, %d)"] = "Aktuell: %s (%d, %d)"
L["X Position"] = "X-Position"
L["Y Position"] = "Y-Position"
L["Essential Container Position"] = "Essential-Container-Position"
L["Utility Y Offset"] = "Unterstützung Y-Versatz"
L["Main Buff Container Position"] = "Haupt-Buff-Container-Position"
L["Buff Bar Container Position"] = "Buff-Leisten-Container-Position"
L["Positions"] = "Positionen"
--L["Buffs are currently anchored to resources"] = "Buffs are currently anchored to resources"
--L["Resources tab > Global"] = "Resources tab > Global"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Border.lua
-----------------------------------------------------------------------

L["Border Settings"] = "Rahmen-Einstellungen"
L["Border Texture"] = "Rahmen-Textur"
L["Select Border..."] = "Rahmen auswählen..."
L["Border Color"] = "Rahmenfarbe"
L["Border Size"] = "Rahmengröße"
L["Border Offset X"] = "Rahmen X-Versatz"
L["Border Offset Y"] = "Rahmen Y-Versatz"
L["Zoom Icons"] = "Symbole zoomen"
--L["Zoom Amount"] = "Zoom Amount"
--L["Remove Shadow Overlay"] = "Remove Shadow Overlay"
--L["Remove Default Icon Mask"] = "Remove Default Icon Mask"
L["Visual Elements"] = "Visuelle Elemente"
L["* These options require /reload to take effect"] = "* Diese Optionen erfordern /reload zur Aktivierung"
L["Hide Debuff Border (red outline on harmful effects)"] = "Debuff-Rahmen ausblenden (roter Umriss bei schädlichen Effekten)"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "Aufleuchten nach Abklingzeit ausblenden (Leuchtanimation bei Abklingzeitende)"
--L["Pandemic Display"] = "Pandemic Display"
L["Hide Blizzard's Pandemic Indicator (animated refresh window border)"] = "Blizzards Pandemie-Indikator ausblenden (animierter Erneuerungsfensterrahmen)"
--L["Enable Pandemic Customization"] = "Enable Pandemic Customization"
--L["Custom Pandemic Border"] = "Custom Pandemic Border"
L["Color"] = "Farbe"
--L["Pandemic Glow"] = "Pandemic Glow"
--L["Charge Cooldowns"] = "Charge Cooldowns"
--L["Show Edge"] = "Show Edge"
--L["Hide Swipe"] = "Hide Swipe"
L["Borders"] = "Rahmen"
--L["Look"] = "Look"
--L["Borders & Look"] = "Borders & Look"
--L["Hide Buff Swipe"] = "Hide Buff Swipe"
--L["Don't desaturate on cooldown"] = "Don't desaturate on cooldown"
--L["Hide recharge timer"] = "Hide recharge timer"
--L["Color Buff Bars Borders"] = "Color Buff Bars Borders"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Text.lua
-----------------------------------------------------------------------

L["None"] = "Keine"
L["Outline"] = "Kontur"
L["Thick Outline"] = "Dicke Kontur"
L["Slug"] = "Slug"
L["Font"] = "Schriftart"
L["Font Outline"] = "Schriftkontur"
L["Cooldown Timer"] = "Abklingzeit-Timer"
--L["Cooldown Countdown Format"] = "Cooldown Countdown Format"
--L["Show decimals below (seconds, 0 = off)"] = "Show decimals below (seconds, 0 = off)"
--L["Threshold Color"] = "Threshold Color"
--L["Color countdown below threshold"] = "Color countdown below threshold"
--L["Threshold (seconds)"] = "Threshold (seconds)"
--L["Row 1 Font Size"] = "Row 1 Font Size"
--L["Row 2 Font Size"] = "Row 2 Font Size"
--L["Row 1 - Stacks (Charges)"] = "Row 1 - Stacks (Charges)"
L["Font Size"] = "Schriftgröße"
L["Position"] = "Position"
L["X Offset"] = "X-Versatz"
L["Y Offset"] = "Y-Versatz"
--L["Row 2 - Stacks (Charges)"] = "Row 2 - Stacks (Charges)"
--L["Stacks (Charges)"] = "Stacks (Charges)"
--L["Name Text"] = "Name Text"
L["Anchor"] = "Ankerpunkt"
--L["Duration Text"] = "Duration Text"
--L["Stack Count Text"] = "Stack Count Text"
--L["Global"] = "Global"
--L["Buff Icons"] = "Buff Icons"
L["Buff Bars"] = "Buff-Leisten"
L["Text"] = "Text"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Glow.lua
-----------------------------------------------------------------------

L["Pixel Glow"] = "Pixel-Leuchten"
L["Autocast Glow"] = "Leuchten bei automatischem Wirken"
L["Button Glow"] = "Schaltflächen-Leuchten"
L["Proc Glow"] = "Proc-Leuchten"
L["Glow Settings"] = "Leucht-Einstellungen"
L["Glow Type"] = "Leuchttyp"
L["Use Custom Color"] = "Benutzerdefinierte Farbe verwenden"
L["Glow Color"] = "Leuchtfarbe"
L["Pixel Glow Settings"] = "Pixel-Leucht-Einstellungen"
L["Lines"] = "Linien"
L["Frequency"] = "Frequenz"
L["Length (0=auto)"] = "Länge (0=auto)"
L["Thickness"] = "Stärke"
--L["Border"] = "Border"
L["Autocast Glow Settings"] = "Automatischer-Zauber-Leucht-Einstellungen"
L["Particles"] = "Partikel"
L["Scale"] = "Skalierung"
L["Button Glow Settings"] = "Schaltflächen-Leucht-Einstellungen"
L["Frequency (0=default)"] = "Frequenz (0=Standard)"
L["Proc Glow Settings"] = "Proc-Leucht-Einstellungen"
L["Duration (x10)"] = "Dauer (x10)"
L["Glow"] = "Leuchten"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Fading.lua
-----------------------------------------------------------------------

L["Fading"] = "Verblassen"
L["Enable Fading"] = "Verblassen aktivieren"
L["Fade Triggers"] = "Verblassen Auslöser"
L["Fade when no target"] = "Verblassen ohne Ziel"
L["Fade out of combat"] = "Verblassen außerhalb des Kampfes"
L["Fade when mounted"] = "Verblassen wenn aufgestiegen"
L["Faded Opacity"] = "Verblassen Stärke"
L["Apply Fading To"] = "Verblassen anwenden auf"
L["Racials"] = "Volksfertigkeiten"
L["Defensives"] = "Defensivfähigkeiten"
L["Trinkets"] = "Schmuckstücke"
L["Resources"] = "Ressourcen"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Assist.lua
-----------------------------------------------------------------------

--L["Press Overlay"] = "Press Overlay"
--L["Enable Press Overlay"] = "Enable Press Overlay"
--L["Color Tint"] = "Color Tint"
--L["Tint Color"] = "Tint Color"
--L["Highlight"] = "Highlight"
L["Rotation Assist"] = "Rotationshelfer"
L["Enable Rotation Assist"] = "Rotationshelfer aktivieren"
L["Highlight Size"] = "Größe der Hervorhebung"
L["Keybindings"] = "Tastenbelegung"
L["Enable Keybind Text"] = "Beschriftung für Tastenbelegung aktivieren"
L["Assist"] = "Assist"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/GroupEditorShared.lua
-----------------------------------------------------------------------

--L["Text Overrides"] = "Text Overrides"
--L["Override Text Settings"] = "Override Text Settings"
--L["Cooldown Size"] = "Cooldown Size"
--L["Cooldown Color"] = "Cooldown Color"
--L["Charge Size"] = "Charge Size"
--L["Charge Color"] = "Charge Color"
L["Current Spec"] = "Aktuelle Spezialisierung"
--L["Grow Direction"] = "Grow Direction"
--L["Spacing"] = "Spacing"
L["Icon Width"] = "Symbolbreite"
L["Icon Height"] = "Symbolhöhe"
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
L["Unknown"] = "Unbekannt"
L["Border:"] = "Rahmen:"
--L["Right-click icon to reset border color"] = "Right-click icon to reset border color"
L["Enable Glow"] = "Leuchten aktivieren"
L["Glow Color:"] = "Leuchtfarbe:"
L["Spell ID:"] = "Zauber-ID:"
L["Duration (sec):"] = "Dauer (Sek.):"
--L["Save"] = "Save"
L["Invalid spell ID"] = "Ungültige Zauber-ID"
L["Enter a valid duration"] = "Gültige Dauer eingeben"
--L["Ungrouped Buffs"] = "Ungrouped Buffs"
--L["Add Spell to:"] = "Add Spell to:"
--L["Log %s to build spell list"] = "Log %s to build spell list"
--L["No untracked buff icons available for this spec"] = "No untracked buff icons available for this spec"
--L["All available icons are assigned to groups"] = "All available icons are assigned to groups"
--L["Add Custom Buff to:"] = "Add Custom Buff to:"
--L["Add Custom Buff"] = "Add Custom Buff"
--L["Quick Add"] = "Quick Add"
L["Add"] = "Hinzufügen"
--L["Custom Spell"] = "Custom Spell"
L["Add Spell"] = "Zauber hinzufügen"
L["Failed - invalid spell ID"] = "Fehlgeschlagen – ungültige Zauber-ID"
L["Added!"] = "Hinzugefügt!"
--L["Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"] = "Custom buffs are triggered from your own spellcasts. You CAN'T track random auras"
--L["Back"] = "Back"
--L["Add Group"] = "Add Group"
--L["Add Icon"] = "Add Icon"
--L["No ungrouped buffs"] = "No ungrouped buffs"
L["Rename"] = "Umbenennen"
--L["Duplicate"] = "Duplicate"
--L["Copy to"] = "Copy to"
--L["Delete group with %d spell(s)?"] = "Delete group with %d spell(s)?"
--L["Drag spells here"] = "Drag spells here"
L["Buff Groups"] = "Buff-Gruppen"

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

L["Invalid Base64 encoding"] = "Ungültige Base64-Kodierung"
L["Decompression failed"] = "Dekomprimierung fehlgeschlagen"
L["Invalid profile version"] = "Ungültige Profilversion"
L["Missing profile metadata"] = "Fehlende Profil-Metadaten"
--L["Profile is for a different addon"] = "Profile is for a different addon"
L["No import string provided"] = "Keine Import-Zeichenkette angegeben"
L["Failed to import profile"] = "Profil konnte nicht importiert werden"
--L["Select at least one category to export."] = "Select at least one category to export."
L["Profile is for a different addon: %s"] = "Profil gehört zu einem anderen Addon: %s"
L["Imported %d settings as '%s'"] = "%d Einstellungen als '%s' importiert"
L["Export Profile"] = "Profil exportieren"
L["Select categories to include, then click Export."] = "Kategorien auswählen und dann auf Exportieren klicken."
L["Export"] = "Exportieren"
L["Export String (Ctrl+C to copy):"] = "Export-Zeichenkette (Ctrl+C zum Kopieren):"
L["Profile exported! Copy the string above."] = "Profil exportiert! Die obige Zeichenkette kopieren."
L["Export failed."] = "Export fehlgeschlagen."
L["Import Profile"] = "Profil importieren"
L["Paste an export string below and click Import."] = "Eine Export-Zeichenkette unten einfügen und auf Importieren klicken."
L["Import"] = "Importieren"
L["Clear"] = "Leeren"
L["Import/Export"] = "Import/Export"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Profiles.lua
-----------------------------------------------------------------------

L["Already exists"] = "Bereits vorhanden"
L["Enter a name"] = "Namen eingeben"
--L["Failed to apply profile"] = "Failed to apply profile"
--L["Profile not found"] = "Profile not found"
--L["Cannot copy active profile"] = "Cannot copy active profile"
--L["Cannot delete active profile"] = "Cannot delete active profile"
L["Current Profile"] = "Aktuelles Profil"
L["New Profile"] = "Neues Profil"
L["Create"] = "Erstellen"
L["Copy From"] = "Kopieren von"
L["Copy all settings from another profile into the current one."] = "Alle Einstellungen aus einem anderen Profil in das aktuelle kopieren."
L["Select Source..."] = "Quelle auswählen..."
L["Manage"] = "Verwalten"
L["Reset Profile"] = "Profil zurücksetzen"
L["Delete Profile..."] = "Profil löschen..."
L["Default Profile for New Characters"] = "Standardprofil für neue Charaktere"
L["Specialization Profiles"] = "Spezialisierungsprofile"
L["Auto-switch profile per specialization"] = "Profil automatisch je Spezialisierung wechseln"
L["Spec %d"] = "Spezialisierung %d"
L["Profiles"] = "Profile"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Racials.lua
-----------------------------------------------------------------------

L["Add Custom Spell or Item"] = "Benutzerdefinierten Zauber oder Gegenstand hinzufügen"
L["Spell"] = "Zauber"
L["Item"] = "Gegenstand"
L["Enter a valid ID"] = "Gültige ID eingeben"
L["Loading item data, try again"] = "Gegenstandsdaten werden geladen, erneut versuchen"
L["Unknown spell ID"] = "Unbekannte Zauber-ID"
L["Added: %s"] = "Hinzugefügt: %s"
L["Already tracked"] = "Wird bereits verfolgt"
L["Enable Racials"] = "Volksfertigkeiten aktivieren"
--L["Show Items at 0 Stacks"] = "Show Items at 0 Stacks"
L["Tracked Spells"] = "Verfolgte Zauber"
L["Manage Spells"] = "Zauber verwalten"
L["Icon Size"] = "Symbolgröße"
L["Party Frame Anchoring"] = "Gruppenrahmen-Verankerung"
L["Anchor to Party Frame"] = "Am Gruppenrahmen verankern"
L["Side (relative to Party Frame)"] = "Seite (relativ zum Gruppenrahmen)"
L["Party Frame X Offset"] = "Gruppenrahmen X-Versatz"
L["Party Frame Y Offset"] = "Gruppenrahmen Y-Versatz"
L["Anchor Position (relative to Player Frame)"] = "Ankerposition (relativ zum Spielerportrait)"
L["Cooldown"] = "Abklingzeit"
L["Stacks"] = "Stapel"
L["Text Position"] = "Textposition"
L["Text X Offset"] = "Text X-Versatz"
L["Text Y Offset"] = "Text Y-Versatz"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Defensives.lua
-----------------------------------------------------------------------

L["Add Custom Spell"] = "Benutzerdefinierten Zauber hinzufügen"
L["Spell ID"] = "Zauber-ID"
L["Enter a valid spell ID"] = "Gültige Zauber-ID eingeben"
L["Not available for spec"] = "Nicht für diese Spezialisierung verfügbar"
L["Enable Defensives"] = "Defensivfähigkeiten aktivieren"

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
L["Independent"] = "Unabhängig"
L["Append to Defensives"] = "An Defensivfähigkeiten anhängen"
L["Append to Spells"] = "An Zauber anhängen"
L["Row 1"] = "Reihe 1"
L["Row 2"] = "Reihe 2"
L["Start"] = "Anfang"
L["End"] = "Ende"
L["Enable Trinkets"] = "Schmuckstücke aktivieren"
--L["Manage Blacklist"] = "Manage Blacklist"
L["Layout Mode"] = "Layout-Modus"
L["Display Mode"] = "Anzeigemodus"
L["Row"] = "Reihe"
L["Position in Row"] = "Position in der Reihe"
L["Show Passive Trinkets"] = "Passive Schmuckstücke anzeigen"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources_Conditions.lua
-----------------------------------------------------------------------

L["Mana"] = "Mana"
L["Rage"] = "Wut"
L["Energy"] = "Energie"
L["Focus"] = "Fokus"
L["Combo Points"] = "Kombinationspunkte"
--L["Runes"] = "Runes"
L["Runic Power"] = "Runenmacht"
L["Soul Shards"] = "Seelensplitter"
L["Astral Power"] = "Astralenergie"
L["Holy Power"] = "Heilige Kraft"
L["Maelstrom"] = "Mahlstrom"
L["Chi"] = "Chi"
L["Insanity"] = "Wahnsinn"
L["Arcane Charges"] = "Arkanladungen"
L["Fury"] = "Furor"
L["Essence"] = "Essenz"
L["Soul Fragments"] = "Seelenfragmente"
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
L["Bar Color"] = "Leistenfarbe"
L["Background"] = "Hintergrund"
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

L["Warrior"] = "Krieger"
L["Paladin"] = "Paladin"
L["Hunter"] = "Jäger"
L["Rogue"] = "Schurke"
L["Priest"] = "Priester"
L["Death Knight"] = "Todesritter"
L["Shaman"] = "Schamane"
L["Mage"] = "Magier"
L["Warlock"] = "Hexenmeister"
L["Monk"] = "Mönch"
L["Druid"] = "Druide"
L["Demon Hunter"] = "Dämonenjäger"
L["Evoker"] = "Rufer"
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
L["Enable Resources"] = "Ressourcen aktivieren"
--L["Conditions"] = "Conditions"
--L["Load"] = "Load"
--L["Select a resource bar to configure"] = "Select a resource bar to configure"
--L["Copy settings from..."] = "Copy settings from..."
L["Width (0 = Auto)"] = "Breite (0 = Auto)"
--L["Colors"] = "Colors"
--L["Base Color"] = "Base Color"
--L["Bar Ceiling (% HP)"] = "Bar Ceiling (% HP)"
--L["Tier %d"] = "Tier %d"
--L["Enabled"] = "Enabled"
--L["Threshold (% HP)"] = "Threshold (% HP)"
--L["Textures"] = "Textures"
L["Bar Texture:"] = "Leisten-Textur:"
L["Background Texture:"] = "Hintergrund-Textur:"
--L["Smooth Fill"] = "Smooth Fill"
--L["Anchor To:"] = "Anchor To:"
L["Bar Spacing"] = "Leistenabstand"
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
L["Left"] = "Links"
L["Center"] = "Mitte"
L["Right"] = "Rechts"
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

L["Dimensions"] = "Abmessungen"
L["Bar Width (0 = Auto)"] = "Leistenbreite (0 = Auto)"
L["Bar Height"] = "Leistenhöhe"
L["Appearance"] = "Erscheinungsbild"
L["Background Color"] = "Hintergrundfarbe"
L["Growth Direction:"] = "Wachstumsrichtung:"
L["Down"] = "Unten"
L["Up"] = "Oben"
L["Icon Position:"] = "Symbolposition:"
L["Hidden"] = "Ausgeblendet"
L["Icon-Bar Gap"] = "Symbol-Leisten-Abstand"
L["Dual Bar Mode (2 bars per row)"] = "Doppelleisten-Modus (2 Leisten pro Reihe)"
L["Show Buff Name"] = "Buff-Namen anzeigen"
--L["Max Name Length (0 = Full)"] = "Max Name Length (0 = Full)"
L["Show Duration Text"] = "Dauertext anzeigen"
L["Show Stack Count"] = "Stapelanzahl anzeigen"
L["Notes"] = "Hinweise"
L["Border settings: see Borders tab"] = "Rahmen-Einstellungen: siehe Reiter Rahmen"
L["Text styling (font size, color, offsets): see Text tab"] = "Textgestaltung (Schriftgröße, Farbe, Versätze): siehe Reiter Text"
L["Position lock and X/Y controls: see Positions tab"] = "Positionssperre und X/Y-Steuerung: siehe Reiter Positionen"
L["Bars"] = "Leisten"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CastBar.lua
-----------------------------------------------------------------------

L["Enable Cast Bar"] = "Zauberleiste aktivieren"
L["Hide Blizzard Cast Bar"] = "Blizzard-Zauberleiste ausblenden"
--L["Match Utility Width"] = "Match Utility Width"
L["Spell Icon"] = "Zaubersymbol"
L["Show Spell Icon"] = "Zaubersymbol anzeigen"
L["Bar Texture"] = "Leisten-Textur"
L["Use Blizzard Atlas Textures"] = "Blizzard-Atlas-Texturen verwenden"
L["Cast Color"] = "Zauberfarbe"
--L["Class Color"] = "Class Color"
L["Channel Color"] = "Kanalfarbe"
L["Uninterruptible Color"] = "Farbe wenn nicht unterbrechbar"
--L["Top Left"] = "Top Left"
--L["Top"] = "Top"
--L["Top Right"] = "Top Right"
--L["Bottom Left"] = "Bottom Left"
--L["Bottom"] = "Bottom"
--L["Bottom Right"] = "Bottom Right"
--L["Anchor Point:"] = "Anchor Point:"
--L["Show Preview"] = "Show Preview"
L["Show Spell Name"] = "Zaubernamen anzeigen"
L["Name X Offset"] = "Name X-Versatz"
L["Name Y Offset"] = "Name Y-Versatz"
L["Show Timer"] = "Zauberzeit anzeigen"
--L["Show Total Duration (e.g. 0.5/1.5)"] = "Show Total Duration (e.g. 0.5/1.5)"
L["Timer X Offset"] = "Timer X-Versatz"
L["Timer Y Offset"] = "Timer Y-Versatz"
L["Show Spark"] = "Funkeln anzeigen"
L["Empowered Stages"] = "Ermächtigungsphasen"
L["Wind Up Color"] = "Anlauf-Farbe"
L["Stage 1 Color"] = "Phase 1 Farbe"
L["Stage 2 Color"] = "Phase 2 Farbe"
L["Stage 3 Color"] = "Phase 3 Farbe"
--L["Hold At Max Color"] = "Hold At Max Color"
L["Cast Bar"] = "Zauberleiste"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Externals.lua
-----------------------------------------------------------------------

--L["Enable Externals"] = "Enable Externals"
--L["Disable Blink"] = "Disable Blink"

