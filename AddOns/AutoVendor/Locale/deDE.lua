local L = LibStub("AceLocale-3.0"):NewLocale("AutoVendor", "deDE")
if not L then return end

-- Put the language in this locale here
L["Loaded language"] = "Deutsch"

---------------------------------------------------------------------------
-- Texts                                                                 --
--                                                                       --
-- Any placeholders (%s, %d, et cetera) should remain in the same order! --
---------------------------------------------------------------------------

-- Configuration screen
L['Autovendor enabled'] = 'Aktiviert'
L['Autovendor enabled description'] = 'Dieses Addon ein- bzw. ausschalten.'
L['Sales header'] = 'Verkäufe'
L['Sell unusable'] = 'Verkaufe unbrauchbare, seelengebundene Ausrüstung.'
L['Sell unusable description'] = 'Verkaufe Rüstungen und Waffen, die seelengebunden, aber von deiner Klasse nicht verwendbar sind.'
L['Sell unusable confirmation'] = 'Möchtest du deine seelengebunden Rüstungen und Waffen automatisch verkaufen, die du nicht verwenden kannst?'
L['Sell non-optimal'] = 'Verkaufe nicht optimale seelengebundene Rüstung'
L['Sell non-optimal description'] = 'Verkaufe Rüstungen, die unter deiner optimalen Rüstung liegt (Stoff/Leder/Kette für Plattenträger, Stoff/Leder für Kettenträger, Stoff für Lederträger).'
L['Sell non-optimal confirmation'] = 'Möchtest du alle seelengebundenen Rüstungen automatisch verkaufen, die nicht optimal für dich sind?'
L['Sell Legion artifact relics'] = 'Sell Legion artifact relics'
L['Sell legion artifact relics description'] = 'Sell artifact relics from the Legion expansion'
L['Sell cheap fortune cards'] = 'Verkaufe billige Glückskarten'
L['Sell cheap fortune cards description'] = 'Verkaufe Glückskarten (durch Umdrehen mysteriöser Glückskarten oder Verzehr von Glückskeksen erhalten), die billig sind (z.B. alle außer den 1000g bzw. 5000g Karten).'
L['Sell low level'] = 'Verkaufe niedrig stufige Gegenstände'
L['Sell low level description'] = 'Verkaufe seelengebundene Gegenstände, die unter einen bestimmten Gegenstandsstufe liegen. Funktioniert nur, wenn die vorhergehende Einstellung aktiviert ist.'
L['Sell low level confirmation'] = 'WARNUNG: Diese Funktion ist experimentell.\n\nEinige niederstufige Gegenstände könnten dennoch gewünscht sein (wie kosmetische Gegenstände).\n\nWir haben versucht, nützliche Gegenstände nicht zu verkaufen, aber können dies nicht garantieren.'
L['Sell items below'] = 'Verkaufe Gegenstände unterhalb dieser Gegenstandsstufe'
L['Sell items below description'] = 'Verkaufe selengebundene Gegenstände unterhalb der angegebenen Gegenstandsstufe. Funktioniert nur, wenn die vorherige Einstellung aktiviert ist.'
L['Verbosity'] = 'Textdetails'
L['Verbosity description'] = 'Wie detailiert sollen die Informationen sein, bei Zugriff auf einen Händler.'
L['Verbosity none'] = 'Keine'
L['Verbosity summary'] = 'Zusammenfassung'
L['Verbosity all'] = 'Alle'
L['Auto repair'] = 'Automatisch reparieren'
L['Auto repair description'] = 'Repariert automatisch bei Besuch eines Händlers.'
L['Auto repair guild bank'] = 'Benutze Gildenbank'
L['Auto repair guild bank description'] = 'Benutze die Gildenbank zur automatischen Reparatur, falls vorhanden'
L['Toggle junk'] = 'Abfall festlegen'
L['Toggle junk description'] = 'Legt fest, ob ein Gegenstand auf die Abfallliste gesetzt wird (black list)'
L['Toggle NotJunk'] = 'Nicht-Abfall festlegen'
L['Toggle NotJunk description'] = 'Legt fest, ob ein Gegenstand auf die Nicht-Abfallliste gesetzt wird (white list)'
L['Debug'] = 'Fehlersuche'
L['Debug description'] = 'Gibt eine Fehlersuche-Informationen aus. Optional einen Gegenstands-Link hinzufügen. Nützlich für die Lokalisierung.'

-- Output messages
L['Added to list'] = 'Füge %s zu %s hinzufügen.'
L['Removed from list'] = 'Entferne %s von %s.'

L['Junk list empty'] = 'Die Abfallliste ist leer.'
L['Items in junk list'] = 'Gegenstände auf der Abfallliste:'
L['Not-junk list empty'] = 'Die Nicht-Abfallliste ist leer.'
L['Items in not-junk list'] = 'Gegenstände auf der Nicht-Abfallliste:'

L['Throwing away'] = 'Werfe %s weg.'
L['No junk to throw away'] = 'Du trägst gerade keinen Abfall!'

L['No item link'] = 'Kein Gegenstands-Link verfügbar!'

-- Output when selling stuff
L['Selling x of y for z'] = 'Verkaufe %sx%d für %s.'
L['Item has no vendor worth'] = '%s hat keinen Verkaufswert, du möchtest es vielleicht selbst zerstören.'
L['Single item'] = 'Gegenstand'
L['Multiple items'] = 'Gegenstände'
L['Summary sold x item(s) for z'] = 'Verkaufe automatisch %d %s für %s.'
L['Repaired all items for x from guild bank'] = 'Alle Gegenstände repariert für %s (von Gildenbank).'
L['Repaired all items for x'] = 'Alle Gegenstände repariert für %s.'
L['12 items sold'] = '12 Gegenstände verkauft, aber es gibt noch mehr in deinem Inventar. Bitte schließe das Händlerfenster und öffne es erneut, um den Rest ebenfalls zu verkaufen.'


-------------------------------------------------------------------------------------------------------------------------------------------------
-- Strings                                                                                                                                     --
-- Put the exact wording used in the game here. If you're unsure what to put for a certain item or class, use /av debug [itemlink] to find out --
--                                                                                                                                             --
-- For languages other than English: replace 'true' with the actual value between single quotes ('')                                           --
-------------------------------------------------------------------------------------------------------------------------------------------------

-- Misc
L['Equip:'] = 'Anlegen:'
