# DBM - Core

## [12.0.29](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.29) (2026-03-06)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.28...12.0.29) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep new tag  
- Update translations (#1946)  
    Co-authored-by: anon1231823 <anon1231823@users.noreply.github.com>  
-  - Improve matches phrasing for single search results  
     - reordered all localization keys across all of GUI to have matched ordering  
     - Added placeholder untranslated strings in all non english localizations that were missing (they need translating)  
     - Unified tabbed whitespacing  
- hide a missed UI option that doesn't do anything on retail  
- use end color rather than start color  
- Localize "matches"  
- Update localization.ru.lua (#1940)  
- Update translations (#1941)  
    * Update Core translation strings  
- Add GUI search (#1943)  
    * Added ability to search DBM GUI for specific text/options.  
- Cleaner fix.  
- Define tools tabl like this, so it can be exposed easier.  
- move tab more  
- fix rest of name  
- fix name  
- prep scenario tab  
- Change core to always set bar color even if bar is "disabled" since the disable toggle doesnt actually work with current api yet (it will work with hard coded timers though but most dungeon bosses don't need those atm)  
- fix bug with version 19 voice pack sounds not playing  
- don't fire an unessesary callback on classic  
- fix eyesore  
- add callbacks for when DBM is gonna ignore blizzard api  
- update VP sounds  
- bump alpha  
