# DBM - Core

## [12.0.33](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.33) (2026-03-25)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.32...12.0.33) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- quick fix bad merge from RU update  
- Update koKR (#1983)  
    * Update koKR  
- Update translations (#1985)  
- Upd RU locale (#1984)  
    * Create localization.ru.lua  
    * Update DBM-Raids-Midnight\_Mainline.toc  
    * Update commonlocal.ru.lua  
- prep new tag  
- Preliminary hardcode for vanguard (sorry this wasn't done last week, i actually forgot to log it last week)  
    Added a few renames and better option defaults too and pruned one alert that never came to fruition  
- Fix double soak warning protection not resetting after each cycle, causing the fix to only work for first time bug occurs, not each additional time.  
- Use precise passthrough on rest too  
- reapply some fixes that got lost due to merge conflicts being resolved incorrectly to crown (such as wrong spellname for hand and some sound updates that got lost)  
    Change crown to no longer pass through unknown timers when they occur and instead just full fallback to non hardcoded api if unexpected results occur so it doesn't end up in a state where it just starts resolving entirely wrong once any context becomes desynced.  
    Also changed overly complicated stage 2 logic to be more direct simple count/event order logic.  
    always use exact timer for crown and vaelgor instead of rounded timer for start. rounded should only be used for context logic.  
- Further update Double dragon hardcode with routing updates based on greater data  
- fix last  
- improve debug so shortnames don't have to be disabled when doing timeline debugging and spellname matching  
- Redo logic on Vorasius to better handle alternating slam timer spellids  
- Refactor double dragons to account for ~1 second drift and rakfang and Vaelwing now always being cast in stage 1 and 2 rather than only being cast by one of dragons.  
- Fix work around for timer bug on Averzian  
    Add timer workaround for Vorasius  
    Of course, it'd be nice if blizzard knew what they were doing and could actually start valid timers for their bosses instead.  
- NA vs british english  
- bump alpha  
