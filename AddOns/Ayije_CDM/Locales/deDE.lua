local CDM = _G["Ayije_CDM"]
local L = CDM:NewLocale("deDE")
if not L then return end

-----------------------------------------------------------------------
-- Init.lua
-----------------------------------------------------------------------

L["Callback error in '%s':"] = "Callback-Fehler in '%s':"

-----------------------------------------------------------------------
-- Config/Core.lua
-----------------------------------------------------------------------

L["Cannot open config while in combat"] = "Konfiguration kann nicht im Kampf geöffnet werden"
L["Could not load options: %s"] = "Optionen konnten nicht geladen werden: %s"
L["Enabled Blizzard Cooldown Manager."] = "Blizzard-Abklingzeitenmanager aktiviert."
-- L["Config open queued until combat ends."] = ""
-- L["Config open queued until login setup finishes."] = ""

-----------------------------------------------------------------------
-- Core/EditMode.lua
-----------------------------------------------------------------------

L["Edit Mode locked"] = "Bearbeitungsmodus gesperrt"
L["use /cdm"] = "benutze /cdm"
L["Edit Mode locked - use /cdm"] = "Bearbeitungsmodus gesperrt – benutze /cdm"
L["Cooldown Viewer settings are managed by /cdm. Edit Mode changes are disabled to avoid taint."] = "Abklingzeitenanzeige-Einstellungen werden durch /cdm verwaltet. Bearbeitungsmodusänderungen sind deaktiviert, um Taint zu vermeiden."

-----------------------------------------------------------------------
-- Core/Layout/Containers.lua
-----------------------------------------------------------------------

L["Click and drag to move - /cdm > Positions to lock"] = "Klicken und ziehen zum Bewegen – /cdm > Positionen zum Sperren"

-----------------------------------------------------------------------
-- Modules/PlayerCastBar.lua
-----------------------------------------------------------------------

L["Preview Cast"] = "Zaubervorschau"
L["Click and drag to move - /cdm > Cast Bar to lock"] = "Klicken und ziehen zum Bewegen – /cdm > Zauberleiste zum Sperren"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Init.lua
-----------------------------------------------------------------------

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

L["Layout Settings"] = "Layout-Einstellungen"
L["Icon Spacing"] = "Symbolabstand"
L["Max Icons Per Row"] = "Max. Symbole pro Reihe"
L["Utility Y Offset"] = "Unterstützung Y-Versatz"
L["Wrap Utility Bar"] = "Unterstützungsleiste umbrechen"
L["Utility Max Icons Per Row"] = "Unterstützung Max. Symbole pro Reihe"
L["Unlock Utility Bar"] = "Unterstützungleiste entsperren"
L["Utility X Offset"] = "Unterstützung X-Versatz"
L["Display Vertical"] = "Vertikal anzeigen"
L["Layout"] = "Layout"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Positions.lua
-----------------------------------------------------------------------

L["Lock Container"] = "Container sperren"
L["Unlock to drag the container freely.\nUse sliders below for precise positioning."] = "Entsperren, um den Container frei zu verschieben.\nRegler unten für genaue Positionierung verwenden."
L["Current: %s (%d, %d)"] = "Aktuell: %s (%d, %d)"
L["X Position"] = "X-Position"
L["Y Position"] = "Y-Position"
L["X Offset"] = "X-Versatz"
L["Y Offset"] = "Y-Versatz"
L["Essential Container Position"] = "Essential-Container-Position"
L["Main Buff Container Position"] = "Haupt-Buff-Container-Position"
L["Buff Bar Container Position"] = "Buff-Leisten-Container-Position"
L["Positions"] = "Positionen"

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
L["Zoom Icons (Remove Borders & Overlay)"] = "Symbole zoomen (Rahmen und Overlay entfernen)"
L["Visual Elements"] = "Visuelle Elemente"
L["Hide Debuff Border (red outline on harmful effects)"] = "Debuff-Rahmen ausblenden (roter Umriss bei schädlichen Effekten)"
L["Hide Pandemic Indicator (animated refresh window border)"] = "Pandemie-Indikator ausblenden (animierter Erneuerungsfensterrahmen)"
L["Hide Cooldown Bling (flash animation on cooldown completion)"] = "Aufleuchten nach Abklingzeit ausblenden (Leuchtanimation bei Abklingzeitende)"
L["* These options require /reload to take effect"] = "* Diese Optionen erfordern /reload zur Aktivierung"
L["Borders"] = "Rahmen"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Text.lua
-----------------------------------------------------------------------

L["Global Settings"] = "Globale Einstellungen"
L["Font"] = "Schriftart"
L["Font Outline"] = "Schriftkontur"
L["None"] = "Keine"
L["Outline"] = "Kontur"
L["Thick Outline"] = "Dicke Kontur"
L["Cooldown Timer"] = "Abklingzeit-Timer"
L["Font Size"] = "Schriftgröße"
L["Color"] = "Farbe"
L["Cooldown Stacks (Charges)"] = "Abklingzeit-Stapel (Aufladungen)"
L["Position"] = "Position"
L["Anchor"] = "Ankerpunkt"
L["Buff Bars - Name Text"] = "Buff-Leisten-Namenstext"
L["Buff Bars - Duration Text"] = "Buff-Leisten-Dauertext"
L["Buff Bars - Stack Count Text"] = "Buff-Leisten-Stapelanzahltext"
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
L["Fade Trigger"] = "Verblassen Auslöser"
L["Fade when no target"] = "Verblassen ohne Ziel"
L["Fade out of combat"] = "Verblassen außerhalb des Kampfes"
L["Faded Opacity"] = "Verblassen Stärke"
L["Apply Fading To"] = "Verblassen anwenden auf"
L["Buff Bars"] = "Buff-Leisten"
L["Racials"] = "Volksfertigkeiten"
L["Defensives"] = "Defensivfähigkeiten"
L["Trinkets"] = "Schmuckstücke"
L["Resources"] = "Ressourcen"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Assist.lua
-----------------------------------------------------------------------

L["Assist"] = "Assist"
L["Rotation Assist"] = "Rotationshelfer"
L["Enable Rotation Assist"] = "Rotationshelfer aktivieren"
L["Highlight Size"] = "Größe der Hervorhebung"
L["Keybindings"] = "Tastenbelegung"
L["Enable Keybind Text"] = "Beschriftung für Tastenbelegung aktivieren"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/BuffGroups.lua & Shared
-----------------------------------------------------------------------

L["Unknown"] = "Unbekannt"
L["Add"] = "Hinzufügen"
L["Border:"] = "Rahmen:"
L["Enable Glow"] = "Leuchten aktivieren"
L["Glow Color:"] = "Leuchtfarbe:"
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
L["Buff Groups"] = "Buff-Gruppen"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/ImportExport.lua
-----------------------------------------------------------------------

L["Serialization failed: %s"] = "Serialisierung fehlgeschlagen: %s"
L["Compression failed: %s"] = "Komprimierung fehlgeschlagen: %s"
L["Base64 encoding failed: %s"] = "Base64-Kodierung fehlgeschlagen: %s"
L["No import string provided"] = "Keine Import-Zeichenkette angegeben"
L["Invalid Base64 encoding"] = "Ungültige Base64-Kodierung"
L["Decompression failed"] = "Dekomprimierung fehlgeschlagen"
L["Invalid profile data"] = "Ungültige Profildaten"
L["Missing profile metadata"] = "Fehlende Profil-Metadaten"
L["Profile is for a different addon: %s"] = "Profil gehört zu einem anderen Addon: %s"
L["Invalid profile version"] = "Ungültige Profilversion"
L["Failed to import profile"] = "Profil konnte nicht importiert werden"
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
-- L["Select at least one category to export."] = ""
-- L["Profile is for a different addon"] = ""
-- L["Type mismatch on key '%s': expected %s, got %s"] = ""
L["Import/Export"] = "Import/Export"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Profiles.lua
-----------------------------------------------------------------------

L["Current Profile"] = "Aktuelles Profil"
L["New Profile"] = "Neues Profil"
L["Create"] = "Erstellen"
L["Enter a name"] = "Namen eingeben"
L["Already exists"] = "Bereits vorhanden"
L["Copy From"] = "Kopieren von"
L["Copy all settings from another profile into the current one."] = "Alle Einstellungen aus einem anderen Profil in das aktuelle kopieren."
L["Select Source..."] = "Quelle auswählen..."
L["Manage"] = "Verwalten"
L["Rename"] = "Umbenennen"
L["Reset Profile"] = "Profil zurücksetzen"
L["Delete Profile..."] = "Profil löschen..."
L["Default Profile for New Characters"] = "Standardprofil für neue Charaktere"
L["Specialization Profiles"] = "Spezialisierungsprofile"
L["Auto-switch profile per specialization"] = "Profil automatisch je Spezialisierung wechseln"
L["Spec %d"] = "Spezialisierung %d"
-- L["Failed to apply profile"] = ""
-- L["Profile not found"] = ""
-- L["Cannot copy active profile"] = ""
-- L["Cannot delete active profile"] = ""
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
-- L["Show Items at 0 Stacks"] = ""
L["Tracked Spells"] = "Verfolgte Zauber"
L["Manage Spells"] = "Zauber verwalten"
L["Icon Size"] = "Symbolgröße"
L["Icon Width"] = "Symbolbreite"
L["Icon Height"] = "Symbolhöhe"
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

L["Current Spec"] = "Aktuelle Spezialisierung"
L["Add Custom Spell"] = "Benutzerdefinierten Zauber hinzufügen"
L["Spell ID"] = "Zauber-ID"
L["Enter a valid spell ID"] = "Gültige Zauber-ID eingeben"
L["Not available for spec"] = "Nicht für diese Spezialisierung verfügbar"
L["Enable Defensives"] = "Defensivfähigkeiten aktivieren"
L["Hide tracked defensives from Essential/Utility viewers"] = "Verfolgte Defensivfähigkeiten aus Essential/Unterstützung-Anzeigen ausblenden"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Trinkets.lua
-----------------------------------------------------------------------

L["Independent"] = "Unabhängig"
L["Append to Defensives"] = "An Defensivfähigkeiten anhängen"
L["Append to Spells"] = "An Zauber anhängen"
L["Row 1"] = "Reihe 1"
L["Row 2"] = "Reihe 2"
L["Start"] = "Anfang"
L["End"] = "Ende"
L["Enable Trinkets"] = "Schmuckstücke aktivieren"
L["Layout Mode"] = "Layout-Modus"
L["Display Mode"] = "Anzeigemodus"
L["Row"] = "Reihe"
L["Position in Row"] = "Position in der Reihe"
L["Show Passive Trinkets"] = "Passive Schmuckstücke anzeigen"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Resources.lua
-----------------------------------------------------------------------

L["Background"] = "Hintergrund"
L["Rage"] = "Wut"
L["Energy"] = "Energie"
L["Focus"] = "Fokus"
L["Astral Power"] = "Astralenergie"
L["Maelstrom"] = "Mahlstrom"
L["Insanity"] = "Wahnsinn"
L["Fury"] = "Furor"
L["Mana"] = "Mana"
L["Essence"] = "Essenz"
L["Essence Recharging"] = "Essenz lädt auf"
L["Combo Points"] = "Kombinationspunkte"
L["Charged"] = "Charged"
L["Charged Empty"] = "Charged Empty"
L["Holy Power"] = "Heilige Kraft"
L["Soul Shards"] = "Seelensplitter"
L["Soul Shards Partial"] = "Seelensplitter (teilweise)"
L["Arcane Charges"] = "Arkanladungen"
L["Chi"] = "Chi"
L["Runic Power"] = "Runenmacht"
L["Runes Ready"] = "Runen bereit"
L["Runes Recharging"] = "Runen laden auf"
L["Soul Fragments"] = "Seelenfragmente"
-- L["Devourer Souls"] = ""
L["Light (<30%)"] = "Leicht (<30%)"
L["Moderate (30-60%)"] = "Mäßig (30–60%)"
L["Heavy (>60%)"] = "Schwer (>60%)"
L["Enable Resources"] = "Ressourcen aktivieren"
L["Bar Dimensions"] = "Leistenmaße"
L["Bar 1 Height"] = "Leiste 1 Höhe"
L["Bar 2 Height"] = "Leiste 2 Höhe"
L["Bar Width (0 = Auto)"] = "Leistenbreite (0 = Auto)"
L["Bar Spacing (Vertical)"] = "Leistenabstand (vertikal)"
L["Unified Border (wrap all bars)"] = "Einheitlicher Rahmen (alle Leisten umfassen)"
L["Move buffs down dynamically"] = "Buffs dynamisch nach unten verschieben"
L["Show Mana Bar"] = "Manaleiste anzeigen"
L["Display Mana as %"] = "Mana als % anzeigen"
L["Bar Texture:"] = "Leisten-Textur:"
L["Select Texture..."] = "Textur auswählen..."
L["Background Texture:"] = "Hintergrund-Textur:"
L["Position Offsets"] = "Positionsversätze"
L["Power Type Colors"] = "Energietyp-Farben"
L["Show All Colors"] = "Alle Farben anzeigen"
L["Stagger uses threshold colors: "] = "Staffelung verwendet Schwellenfarben: "
L["Light"] = "Leicht"
L["Moderate"] = "Mäßig"
L["Heavy"] = "Schwer"
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
L["Tags (Power Value Text)"] = "Markierungen (Energiewert-Text)"
L["Left"] = "Links"
L["Center"] = "Mitte"
L["Right"] = "Rechts"
L["Bar %s"] = "Leiste %s"
L["Enable %s Tag (current value)"] = "%s-Markierung aktivieren (aktueller Wert)"
L["%s Font Size"] = "%s Schriftgröße"
L["%s Anchor:"] = "%s Ankerpunkt:"
L["%s Offset X"] = "%s Versatz X"
L["%s Offset Y"] = "%s Versatz Y"
L["%s Text Color"] = "%s Textfarbe"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/CustomBuffs.lua
-----------------------------------------------------------------------

L["ID: %s  |  Duration: %ss"] = "ID: %s  |  Dauer: %ss"
L["Remove"] = "Entfernen"
L["Custom Timers"] = "Benutzerdefinierte Timer"
L["Track spell casts and display custom buff icons alongside native buffs. Icons appear in the main buff container."] = "Zauberwirken verfolgen und benutzerdefinierte Buff-Symbole neben nativen Buffs anzeigen. Symbole erscheinen im Haupt-Buff-Container."
L["Add Tracked Spell"] = "Verfolgten Zauber hinzufügen"
L["Spell ID:"] = "Zauber-ID:"
L["Duration (sec):"] = "Dauer (Sek.):"
L["Add Spell"] = "Zauber hinzufügen"
L["Invalid spell ID"] = "Ungültige Zauber-ID"
L["Enter a valid duration"] = "Gültige Dauer eingeben"
L["Limit reached (9 max)"] = "Limit erreicht (max. 9)"
L["Added!"] = "Hinzugefügt!"
L["Failed - invalid spell ID"] = "Fehlgeschlagen – ungültige Zauber-ID"

-----------------------------------------------------------------------
-- Ayije_CDM_Options/Bars.lua
-----------------------------------------------------------------------

L["Dimensions"] = "Abmessungen"
L["Bar Height"] = "Leistenhöhe"
L["Bar Spacing"] = "Leistenabstand"
L["Appearance"] = "Erscheinungsbild"
L["Bar Color"] = "Leistenfarbe"
L["Background Color"] = "Hintergrundfarbe"
L["Growth Direction:"] = "Wachstumsrichtung:"
L["Down"] = "Unten"
L["Up"] = "Oben"
L["Icon Position:"] = "Symbolposition:"
L["Hidden"] = "Ausgeblendet"
L["Icon-Bar Gap"] = "Symbol-Leisten-Abstand"
L["Dual Bar Mode (2 bars per row)"] = "Doppelleisten-Modus (2 Leisten pro Reihe)"
L["Show Buff Name"] = "Buff-Namen anzeigen"
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
L["Width (0 = Auto)"] = "Breite (0 = Auto)"
L["Spell Icon"] = "Zaubersymbol"
L["Show Spell Icon"] = "Zaubersymbol anzeigen"
L["Bar Texture"] = "Leisten-Textur"
L["Use Blizzard Atlas Textures"] = "Blizzard-Atlas-Texturen verwenden"
L["Cast Color"] = "Zauberfarbe"
L["Channel Color"] = "Kanalfarbe"
L["Uninterruptible Color"] = "Farbe wenn nicht unterbrechbar"
L["Anchor to Resource Bars"] = "An Ressourcenleisten verankern"
L["Y Spacing"] = "Y-Abstand"
L["Lock Position"] = "Position sperren"
L["Show Spell Name"] = "Zaubernamen anzeigen"
L["Name X Offset"] = "Name X-Versatz"
L["Name Y Offset"] = "Name Y-Versatz"
L["Show Timer"] = "Zauberzeit anzeigen"
L["Timer X Offset"] = "Timer X-Versatz"
L["Timer Y Offset"] = "Timer Y-Versatz"
L["Show Spark"] = "Funkeln anzeigen"
L["Empowered Stages"] = "Ermächtigungsphasen"
L["Wind Up Color"] = "Anlauf-Farbe"
L["Stage 1 Color"] = "Phase 1 Farbe"
L["Stage 2 Color"] = "Phase 2 Farbe"
L["Stage 3 Color"] = "Phase 3 Farbe"
L["Stage 4 Color"] = "Phase 4 Farbe"
-- L["Class Color"] = ""
L["Cast Bar"] = "Zauberleiste"

-----------------------------------------------------------------------
