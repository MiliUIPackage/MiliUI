# DBM - Core

## [11.1.1](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.1.1) (2025-01-17)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.1.0...11.1.1) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Update koKR (#1487)  
    Co-authored-by: Adam <MysticalOS@users.noreply.github.com>  
- Update localization.tw.lua (#1486)  
- prep new tag  
- Preliminary Mugzee drycode  
- Restructuring and renaming for SProcketmonger with latest PTR build  
- Update localization.ru.lua (#1485)  
- placeholder localizations  
- Push full one armed bandit drycode  
- Upload test results to DeadlyBossMods/DBM-Test-Results  
- Tests: Add fallback sorting order for otherwise identical objects to fix determinism issues  
- Hackfix for SimpleHTML not sizing properly on initial load  
- Add DBM-Offline workflow  
- Tests: Add test data for Stix Bunkjunker  
- Tests: Add new 11.1 zones  
- Tests: Chat-related anonymizer fixes  
    Fun fact: CHAT\_MSG\_MONSTER\_EMOTE can come from players.  
- Zone Combat Scanner Fixes:  
     - Fixed a bug that could cause combat check to counter intuitively unschedle checks when events spam and actually increase time to detect combat instead of decrease it.  
     - Add redundant zone checks after registering zones to mak sure they always run when a new zone added to hopefully fix race condition where zone checks failed to register.  
- mod passed local test but needed one antispam tweak  
- Push preliminary post testing Stix  
- Core: Add tool to auto-generate localization for mod names from encounter info  
- Core: Add API to add auto-generated name locales from encounter info  
- Core: Fix default name for mods missing a name (should never happen anyways)  
- bump alpha  
