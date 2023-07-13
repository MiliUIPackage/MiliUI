# Details! Damage Meter

## [Details.20230520.11023.151-67-g6f92e05](https://github.com/Tercioo/Details-Damage-Meter/tree/6f92e054d88b9b039555c8c20af909d7e3c5cf4a) (2023-07-11)
[Full Changelog](https://github.com/Tercioo/Details-Damage-Meter/compare/Details.20230520.11023.151...6f92e054d88b9b039555c8c20af909d7e3c5cf4a) 

- Merge pull request #567 from Flamanis/Overall-Clear-Logout-fix  
    Don't populate overall segment on load. and force refresh window on s…  
- Merge pull request #566 from Flamanis/SpecIdsTooltip  
    Add spec detection by tooltip.  
- Don't populate overall segment on load. and force refresh window on segment swap  
- Add spec detection by tooltip.  
- Fix icon things, improvements to class detection by using GetPlayerInfoByGUID()  
- icon updates  
- removed Breath of Eons from spec detection for augmentation evokers  
- When DBM/BW send a callback, check if the current combat in details is valid  
- When the actor is ungroupped players, check if that player has a spec and show the spec icon instead  
- Merge pull request #564 from Flamanis/Don't-swap-to-overall  
    Segments locked don't swap windows to overall.  
- Merge pull request #563 from Flamanis/SetSegmentTooltip  
    Use new SetSegment over TrocaTabela for the segment selector  
- Segments locked don't swap windows to overall.  
- Use new SetSegment over TrocaTabela for the segment selector  
- Framework,  update  
- Merge pull request #560 from Numynum/patch-1  
    Sort damage taken tooltip on damage amount  
- Framework update to version 446  
- Added Details:GetBossEncounterTexture(encounterName); Added combat.bossIcon; Added combat.bossTimers  
- Details:UnpackDeathTable(deathTable) now return the spec of the character as the last parameter returned  
- Added: Details:DoesCombatWithUIDExists(uniqueCombatId); Details:GetCombatByUID(uniqueCombatId); combat:GetCombatUID()  
- classCombat:GetTimeData(chartName) now check if the combat has a TimeData table or return an empty table; Added classCombat:EraseTimeData(chartName)  
- Code for Dispel has been modernized, deathTable now includes the member .spec  
- Libraries Update  
- Sort damage taken tooltip on damage amount  
- Merge branch 'master' of https://github.com/Tercioo/Details-Damage-Meter  
- Added .unixtime into is\_boss to know when the boss was killed  
- Merge pull request #559 from Flamanis/autoruncode  
    Actually save to disk auto run code  
- Move and change run\_code save  
- Merge pull request #558 from Flamanis/Vessel-damage-change  
    Ignore vessel periodic damage  
- Actually save to disk auto run code  
- Ignore vessel periodic damage  
- More fixes for Augmentation Evoker on 10.1.5  
- Code changes, see commit description  
    Combat Objects which has been discarded due to any reason will have the boolean member:  __destroyed set to true. With this change, 3rd party code can see if the data cached is up to date or obsolete.  
    - Removed several deprecated code from March 2023 and earlier.  
    - Large amount of code cleanup and refactoring, some functions got renamed, they are listed below:  
    * TravarTempos renamed to LockActivityTime.  
    * ClearTempTables renamed to ClearCacheTables.  
    * SpellIsDot renamed to SetAsDotSpell.  
    * FlagCurrentCombat remamed to FlagNewCombat\_PVPState.  
    * UpdateContainerCombatentes renamed to UpdatePetCache.  
    * segmentClass:AddCombat(combatObject) renamed to Details222.Combat.AddCombat(combatToBeAdded)  
    - CurrentCombat.verifica\_combate timer is now obsolete.  
    - Details.last\_closed\_combat is now obsolete.  
    - Details.EstaEmCombate is now obsolete.  
    - Details.options is now obsolete.  
    - Added: Details:RemoveSegmentByCombatObject(combatObject)  
    - Spec Guess Timers are now stored within Details222.GuessSpecSchedules.Schedules, all timers are killed at the end of the combat or at a data reset.  
    - Initial time to send startup signal reduced from 5 to 4 seconds.  
    - Fixed some division by zero on ptr 10.1.5.  
    - Fixed DETAILS\_STARTED event not triggering in some cases due to 'event not registered'.  
- Libraries Update  
- Fixed Auto Run Code window not closing by click on the close button  
- fixed a bug on 10.1.5 ptr  
- Merge pull request #555 from Flamanis/StatusbarInit  
    Set up statusbar options instead of using metatable  
- Merge pull request #553 from Flamanis/IgnoreVesselShadow  
    Ignore Vessel of Seared Shadow ticks from starting combats  
- More code cleanup and framework update  
- Set up statusbar options instead of using metatable  
- Merge pull request #554 from Flamanis/UpdateTocsWrath  
    Wrath toc bumps  
- Wrath toc bumps  
- logs changes  
- Overall segment load fix  
- Code cleanup, framework update and bug fixes  
- Ignore Vessel of Seared Shadow ticks from starting combats  
- translated code to English and a few bug fixes from latest alpha  
- More bug fixes for destroyed combats; TimeData code modernizations  
- More fixes for the "Report to Discord" bugs; Implementations to show plugins in the breakdown window;  
- Overhall on the script for Damage Taken by Spell, now it uses modern Details API  
- fixed plugins\_statusbar error  
- Code cleanups, Bug Fixes, Show plugins in the breakdown window, added damage taken and friendly fire tp breakdown  
- Split the window\_playerbreakdown\_spells.lua into three more files  
- Time Machine overhaul  
- When destroying a combat, it'll call DestroyActor to destroy each actor on each actorContainer  
- Fixed activity time not working when the user uses effective time  
- Code Cleanup  
- Code Revamp; Fixed plugins\_statusbar.lua:664: attempt to call method 'GetCombatTime' (a nil value)  
- container\_segments 424 error: now it is ensuring to wipe the combatObject that got removed from containerSegments  
- classic toc rename  
- Merge branch 'master' of https://github.com/Tercioo/Details-Damage-Meter  
- Framework Update and Code improvements  
- Merge pull request #545 from Flamanis/AddIcons  
    Add IconTexture directive to the TOCs  
- Add IconTexture directive to the TOCs  
    Uses the Minimap icon. If a plugin is installed without the base Details it will show a blank icon.  
- Disabled time captures for spellTables, this should be done by a plugin  
- Fixing stuff from latest alpha and more development  
- Replacing table.wipe with Details:Destroy()  
- Renamed variables, code cleanup  
