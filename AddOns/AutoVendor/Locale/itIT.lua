local L = LibStub("AceLocale-3.0"):NewLocale("AutoVendor", "itIT")
if not L then return end

-- Put the language in this locale here
L["Loaded language"] = "Italian"

---------------------------------------------------------------------------
-- Texts --
-- --
-- Any placeholders (%s, %d, et cetera) should remain in the same order! --
---------------------------------------------------------------------------

-- Configuration screen
L['Autovendor enabled'] = 'Attivato'
L['Autovendor enabled description'] = 'Attiva o disattiva questo Addon.'
L['Sales header'] = 'Vendite'
L['Sell unusable'] = 'Vendi equipaggiamento vincolato inutilizzabile'
L['Sell unusable description'] = 'Vendi armi e armature vincolate che non sono utilizzabili dalla tua classe.'
L['Sell unusable confirmation'] = 'Sei sicuro di voler vendere automaticamente tutte le armi e le armature che non possono essere utilizzate dalla tua classe?'
L['Sell non-optimal'] = 'Vendi armature non indicate'
L['Sell non-optimal description'] = 'Vendi armature di categoria inferiore a quelle indicate per la tua classe (stoffa/cuoio/maglia se usi piastre, stoffa/cuoio se usi maglia, stoffa se usi cuoio).'
L['Sell non-optimal confirmation'] = 'Sei sicuro di voler vendere automaticamente tutte le armature che non sono indicate per la tua classe?'
L['Sell Legion artifact relics'] = 'Sell Legion artifact relics'
L['Sell legion artifact relics description'] = 'Sell artifact relics from the Legion expansion'
L['Sell cheap fortune cards'] = 'Vendi le carte di poco valore'
L['Sell cheap fortune cards description'] = 'Vendi le carte della fortuna di poco valore(ottenute girando le Carte della Fortuna Misteriosa o mangiando Biscotti della Fortuna). Es. tutte tranne quelle che valgono 1000g o 5000g.).'
L['Sell low level'] = 'Vendi oggetti vincolati di basso livello'
L['Sell low level description'] = 'Vendi oggetti vincolati sotto un certo livello (vedi sotto). Utile quando si farmano vecchi contenuti.'
L['Sell low level confirmation'] = 'ATTENZIONE: Questa funzione è sperimentale.\n\nAlcuni oggetti di basso livello potrebbero essere utili (come accessori estecici o pet, ecc.).\n\nAbbiamo cercato di assicurarci che nessun oggetto utile fosse venduto, ma ciò non è garantito.'
L['Sell items below'] = 'Vendi oggetti sotto questo livello'
L['Sell items below description'] = 'Vende oggetti vincolati sotto il livello indicato (iLvl). Funziona solo se l\'opzione precedente è attivata.'
L['Verbosity'] = 'Verbosità'
L['Verbosity description'] = 'Quante informazioni vengono visualizzate quando si parla con un mercante.'
L['Verbosity none'] = 'Nessuna'
L['Verbosity summary'] = 'Sommario'
L['Verbosity all'] = 'Tutte'
L['Auto repair'] = 'Ripara automaticamente'
L['Auto repair description'] = 'Ripara automaticamente quando si parla con un mercante.'
L['Auto repair guild bank'] = 'Usa la banca di gilda'
L['Auto repair guild bank description'] = 'Usa la banca di gilda per le riparazioni automatiche quando disponibile.'
L['Toggle junk'] = 'Marchia come Spazzatura'
L['Toggle junk description'] = 'Inserisce o rimuove un oggetto dalla lista "Spazzatura"'
L['Toggle NotJunk'] = 'Marchia come Non-Spazzatura'
L['Toggle NotJunk description'] = 'Inserisce o rimuove un oggetto dalla lista "Non-Spazzatura'
L['Debug'] = 'Debug'
L['Debug description'] = 'Mostra alcune informazioni di debug. Aggiunge anche un link all\'oggetto. Utile in fase di localizzazione.'

-- Output messages
L['Added to list'] = 'Aggiunto %s a %s.'
L['Removed from list'] = 'Rimosso %s da %s.'
L['Junk list empty'] = 'La lista spazzatura è vuota.'
L['Items in junk list'] = 'Oggetti nella lista spazzatura:' 
L['Not-junk list empty'] = 'La lista Non-Spazzatura è vuota.'
L['Items in not-junk list'] = 'Oggetti nella lista Non-Spazzatura:'
L['Throwing away'] = 'Sto gettando %s.'
L['No junk to throw away'] = 'Non hai nessuna spazzatura!'
L['No item link'] = 'Nessun oggetti (link) fornito!'

-- Output when selling stuff
L['Selling x of y for z'] = 'Vendo %sx%d per %s.'
L['Item has no vendor worth'] = '%s non vale nulla per il mercante, quindi potresti volerlo distruggere.'
L['Single item'] = 'oggetto'
L['Multiple items'] = 'oggetti'
L['Summary sold x item(s) for z'] = 'Venduto automaticamente %d %s per %s.'
L['Repaired all items for x from guild bank'] = 'Riparati tutti gli equipaggiamenti per %s (dalla Banca di Gilda).'
L['Repaired all items for x'] = 'Riparati tutti gli equipaggiamento per %s.'
L['12 items sold'] = 'Venduti 12 oggetti ma ne restano altri nel tuo inventario. Perfavore chiudi e riapri la finestra mercante per continuare.'

-------------------------------------------------------------------------------------------------------------------------------------------------
-- Strings --
-- Put the exact wording used in the game here. If you're unsure what to put for a certain item or class, use /av debug [itemlink] to find out --
-- --
-- For languages other than English: replace 'true' with the actual value between single quotes ('') --
-------------------------------------------------------------------------------------------------------------------------------------------------

-- Misc
L['Equip:'] = 'Equipaggia:'
