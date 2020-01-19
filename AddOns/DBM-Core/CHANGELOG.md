# Deadly Boss Mods Core

## [8.3.0](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/8.3.0) (2020-01-14)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/8.2.31...8.3.0)

- Bump version and TOC for 8.3 release  
- Fix some items that got swapped and fixed range input fixer for range 23  
- Fixed canceling of pull timers so it works again (ie /pull 0 is once again allowed)  
- Fix error in last  
- Finally refactored range check to be more efficient with api usage. It was never refactored before because I never expected blizzard to let it even exist this long. but it still exists/works so it was time to make it cleaner.  
- Added trash warnings for Rain of Blood and Sanguine Fountain, both of which utterly delete all the melee in any difficulty (including LFR) :D  
- Fixed loading/detection of Sekzara world boss  
    Fixed phase change detection on Ilgynoth that was caused by blizzard disabling "Il'gynoth's Morass" ability from showing in combat log  
    Fixed fixate timer not showing in LFR Shadhar do to LFR using a different spellID than other difficulties  
    Fixed a bug that caused Mutterings of Insanity special warning not to have a sound when using a voice pack  
    Fixed a bug that caused Mind Flay interrupt warning for Eye of Drest'agath's to spam like crazy do to fact blizzard changed all Eyes of Drest'agath to now have same GUID in combat log (seriously blizzard?)  
- Added Visions staging area to mod available notification  
- Added drycodes for all 3 world bosses added in 8.3  
- Changed target scanning method on tonks in mechagon to be compatible with 8.3 changes  
    Finished trash module for mechagon  
    Added a print to mechagon tonks about mine timer being wrong until new 8.3 timer can be acquired  
- Post tier cleanup. Removed all unused commented code from Eternal Palace that will likely never be used now that we're moving into 8.3  
- DBM-Core will now notify that PVP mods are again available, upon entering first BG. Same way it does with timewalking dungeons/etc.  
    Added more trash warnings for Mechagon dungeon, this time for bosses 5 and 6.  
- tweak arrow nil check  
- Improve timer patch  
- Add check for negative numbers in /pull (#101)  
- Updated luacheck to ignore less, so brace for travis errors (but project is fine if travis does fail)  
- Fix heavily armed warning so it doesn't show from units you aren't in combat with. Why does no one report bugs like this? I have to see them on a twitch stream months later :\  
- Tweaked Upheavel on sporecaller to combine multiple targets as well as filter additional nearby warnings from occuring if you're one of affected players.  
- KR Update (#99)  
    * KR Update  
- Detect when a user has DBM-Lootreminder installed and warn them that it'll break DBM-Core  
- Remove Extra Space  
- Fixed personal fake syncs, restoring break/pull/etc functions when doing outside of groups, or soloing raids that use syncing to pass boss messages  
- Adjust arrow protection against nil errors from slow/nil UnitPosition returns to prevent errors in in situations where the remote target is another player.  
