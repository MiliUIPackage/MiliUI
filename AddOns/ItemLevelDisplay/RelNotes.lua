local me,ns=...
local L=LibStub("AceLocale-3.0"):GetLocale(me,true)
local hlp=LibStub("AceAddon-3.0"):GetAddon(me)
function hlp:loadHelp()
self:HF_Title("Quick Item Level Display","RELNOTES")
self:HF_Paragraph("Description")
self:HF_Pre([[
ItemLevelDisplay adds a tiny layer on each equipment slot in your paperdoll frame showing:

 * ItemLevel
 * Socket Status
 * Enchant Status

It also enriches your flyout equipment buttons

]])
self:RelNotes(1,7,1,[[
Fix: Message: ...temLevelDisplay\libs\LibItemUpgradeInfo-1.0\Core.lua:69: attempt to index local 'itemString' (a number value)
]])
self:RelNotes(1,7,0,[[
Feature: Heirloom current level is now displayed
]])
self:RelNotes(1,6,2,[[
Fixed: An error occurs when login: 1x ...terface\ItemLevelDisplay\ItemLevelDisplay-1.6.1.lua:310: bad argument #1 to 'gmatch' (string expected, got nil)
]])
self:RelNotes(1,6,1,[[
Feature: You can disable itemlevel for shirt and tabard
Feature: Dropped buckle reference
Fixed: Error "Message: ...terface\AddOns\ItemLevelDisplay\ItemLevelDisplay.lua:452 attempt to index field '?' (a nil value)" when opening a flyout at Trasmogrifier
]])
self:RelNotes(1,6,0,[[
Feature: No longer shows old enchant requiremente for item 600+
]])
self:RelNotes(1,5,5,[[
Fixed: Removes debug spam from chat
Update: Will remove old enchant/buckles info in 1.6.0
]])
self:RelNotes(1,5,4,[[
Fixed: Error when opening equipmentset flyout with nore than one equipment set
]])
self:RelNotes(1,5,3,[[
Fixed: Opening a flyout in trasmogrification panel, when no flyout was ever open in the standard paperdoll raised: ItemLevelDisplay-1.5.2.lua:422 attempt to index upvalue 'slots' (a boolean value)
]])
self:RelNotes(1,5,2,[[
Fixed: In some cases, opening the flyout caused error spamming (signaled by Phosphoros)
]])
self:RelNotes(1,5,1,[[
Fixed: No longer gives error when opening tabard or shirt flyout.
]])
self:RelNotes(1,5,0,[[
Feature: Equipment in flyout equipment manager buttons are now taken in consideration and ilevel added to them.
]])
self:RelNotes(1,4,5,[[
Fixed: now accounts for bonus level due to difficulty in raid dropped items. With this release upgrade for Wod should be now complete
]])
self:RelNotes(1,4,4,[[
Fixed: when you install ItemLevelDisplay for tha absolute first time, it raises an error if you choose "Common profile for all characters" at the one time profile type request.
]])
self:RelNotes(1,4,3,[[
Fixed: For level based coloring, upgrade value was not taken in account.
Thanks to Mergele for sending the fix
]])
self:RelNotes(1,4,2,[[
Fixed: Upgraded items are back!!
]])

self:RelNotes(1,4,1,[[
Upgrade: libItemUpgradeInfo upgraded to 1.0.7
]])
self:RelNotes(1,3,2,[[
Feature: Configuration can now be global.(i.e. all characters share the same settings)
Fixed: Best green and best red were swapped
]])
self:RelNotes(1,3,1,[[
Feature: Refined configuration panel
Feature: Added enchantable rings for enchanter
Fixed: gem mini panel is now always updated
]])
self:RelNotes(1,3,0,[[
Feature: Refactored appearance with now 4 color schemes:
 * Quality: based on item quality from poor to Heirloom
 * Plain: no color at all
 * Level green: based on relative level (green are best)
 * Level red: based on relative level (red are best)
Thanks to KVLtv for donating the code
]])
self:RelNotes(1,2,7,[[
Upgrade: Accounts for 5.4.8 item upgrades
]])
self:RelNotes(1,2,6,[[
Upgrade: Accounts for 5.4 item upgrades
]])
self:RelNotes(1,2,4,[[
Feature: More localization
]])
self:RelNotes(1,1,2,[[
Fixed: Gem count was inaccurate
Fixed: Gem layer was appearing even when on different Character Frame tab
Fixed: Upgraded item was displayed incorrectly
Fixed: /ild showinfo was giving an error
]])
self:RelNotes(1,1,2,[[
Upgrade: Accounts for 5.3 item upgrades
]])
self:RelNotes(1,1,0,[[
Upgrade: Accounts for 5.1 item upgrades
Feature: Level text can now be moved via /ild gui
]])
self:RelNotes(1,0,8,[[
Fixed: Head slot is no longer enchantable
]])
self:RelNotes(1,0,5,[[
Feature: Now you can reverse color (red itemes are better)
]])
self:RelNotes(1,0,3,[[
Fixed: Removed chat spam  18 [Name of item in slot 18] item type
Feature: Config menu via blizzard menu or /ild gui
]])
self:RelNotes(1,0,2,[[
Fixed: Waist slot no longer display -1 when you have a belt buckle filled
Fixed: Now only guns/bows/crossbows should check for enchants
]])
self:RelNotes(1,0,1,[[
Fixed: Waist slot was ignored
]])
self:RelNotes(1,0,0,[[
Initial release
]])

end

