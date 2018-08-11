local L = LibStub("AceLocale-3.0"):NewLocale("AutoVendor", "enUS", true, false)

-- Put the language in this locale here
L["Loaded language"] = "English"

---------------------------------------------------------------------------
-- Texts                                                                 --
--                                                                       --
-- Any placeholders (%s, %d, et cetera) should remain in the same order! --
---------------------------------------------------------------------------

-- Configuration screen
L['Autovendor enabled'] = 'Enabled'
L['Autovendor enabled description'] = 'Enable or disable this addon.'
L['Sales header'] = 'Sales'
L['Sell unusable'] = 'Sell unusable soulbound gear'
L['Sell unusable description'] = 'Sell armor and weapons that are soulbound and cannot be used by your class.'
L['Sell unusable confirmation'] = 'Are you sure you want to automatically sell all soulbound weapons and armor that you can not use?'
L['Sell non-optimal'] = 'Sell non-optimal soulbound armor'
L['Sell non-optimal description'] = 'Sell armor that is below your optimal armor (cloth/leather/mail for plate users, cloth/leather for mail users, cloth for leather users).'
L['Sell non-optimal confirmation'] = 'Are you sure you want to automatically sell all soulbound armor that is not optimal for you?'
L['Sell cheap fortune cards'] = 'Sell cheap fortune cards'
L['Sell cheap fortune cards description'] = 'Sell fortune cards (gained by flipping Mysterious Fortune Cards or eating Fortune Cookies) that are cheap (i.e. all except the 1000g and 5000g ones).'
L['Sell low level'] = 'Sell low level soulbound items'
L['Sell low level description'] = 'Sell soulbound items below a certain level (see below). Useful when farming old content.'
L['Sell low level confirmation'] = 'WARNING: This feature is experimental.\n\nSome low level items could still be wanted (like vanity items).\n\nWe tried to make sure we do not sell useful items, but this is not guaranteed.'
L['Sell items below'] = 'Sell items below this level'
L['Sell items below description'] = 'Sell soulbound items below the given certain level. Only works if the previous option is enabled.'
L['Verbosity'] = 'Verbosity'
L['Verbosity description'] = 'How much information is displayed when accessing a vendor.'
L['Verbosity none'] = 'None'
L['Verbosity summary'] = 'Summary'
L['Verbosity all'] = 'All'
L['Auto repair'] = 'Automatically repair'
L['Auto repair description'] = 'Automatically repair when visiting a vendor.'
L['Auto repair guild bank'] = 'Use guild bank'
L['Auto repair guild bank description'] = 'Use the guild bank for auto-repair if available'
L['Toggle junk'] = 'Toggle Junk'
L['Toggle junk description'] = 'Toggles whether an item is on the "junk" list'
L['Toggle NotJunk'] = 'Toggle NotJunk'
L['Toggle NotJunk description'] = 'Toggles whether an item is on the "not junk" list'
L['Debug'] = 'Debug'
L['Debug description'] = 'Print out some debug information. Optionally add an item link. Useful for localization.'

-- Output messages
L['Added to list'] = 'Added %s to %s.'
L['Removed from list'] = 'Removed %s from %s.'

L['Junk list empty'] = 'The junk list is empty.'
L['Items in junk list'] = 'Items in the junk list:'
L['Not-junk list empty'] = 'The not-junk list is empty.'
L['Items in not-junk list'] = 'Items in the not junk list:'

L['Throwing away'] = 'Throwing away %s.'
L['No junk to throw away'] = 'You are not carrying any junk!'

L['No item link'] = 'No item (link) supplied!'

-- Output when selling stuff
L['Selling x of y for z'] = 'Selling %sx%d for %s.'
L['Item has no vendor worth'] = '%s has no vendor worth, so you might want to destroy it yourself.'
L['Single item'] = 'item'
L['Multiple items'] = 'items'
L['Summary sold x item(s) for z'] = 'Automatically sold %d %s for %s.'
L['Repaired all items for x from guild bank'] = 'Repaired all items for %s (from Guild Bank).'
L['Repaired all items for x'] = 'Repaired all items for %s.'
L['12 items sold'] = '12 items sold but there is more junk in your inventory. Please close and reopen the vendor to sell the rest.'


-------------------------------------------------------------------------------------------------------------------------------------------------
-- Strings                                                                                                                                     --
-- Put the exact wording used in the game here. If you're unsure what to put for a certain item or class, use /av debug [itemlink] to find out --
--                                                                                                                                             --
-- For languages other than English: replace 'true' with the actual value between single quotes ('')                                           --
-------------------------------------------------------------------------------------------------------------------------------------------------

-- General
L['Armor'] = true
L['Weapon'] = true

-- Armor types
L['Cloth'] = true
L['Leather'] = true
L['Mail'] = true
L['Plate'] = true
L['Shields'] = true

-- Weapon types
L['Bows'] = true
L['Crossbows'] = true
L['Daggers'] = true
L['Fist Weapons'] = true
L['Guns'] = true
L['One-Handed Axes'] = true
L['One-Handed Maces'] = true
L['One-Handed Swords'] = true
L['Polearms'] = true
L['Staves'] = true
L['Thrown'] = true
L['Two-Handed Axes'] = true
L['Two-Handed Maces'] = true
L['Two-Handed Swords'] = true
L['Wands'] = true
L['Warglaives'] = true

-- Misc
L['Use:'] = true
L['Equip:'] = true
