# DBM - Core

## [12.0.52](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.52) (2026-05-27)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.51...12.0.52) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep new tag  
- Update translation (#2110)  
- Improve option version validation  
- Fix regression causing salad bar timers to all be missing. eventState isn't sent by ADDED payload anymore so a recent filter I added didn't quite work  
- Update translation (#2107)  
- Tighten timer variances to eliminate more false collisions on dragons mythic  
- Fix regressed lua error from no nil check. status == 3 was both a number check AND a nil check, but status >= 2 is only a numeric check that lost the nil check. Lua semantics 🤣  
- handle light and dark feather custom sounds differently so they always play  
- Update Translations / Sort CL keys alphabetical order (#2105)  
- Update koKR (#2103)  
- Update RU locales (#2104)  
- make threat check more likley to succeed on retail  
- modify skipped globals  
- Improve keystone slash register so it waits for other addons to load after DBM before checking if /key commands have been registered by someone else.  
    In addition, also added an option that's off by default if user wants to intentionally overrite another addons slash commands (especially ones that do not give user an opt out of overriding)  
- use more robust caching of boss HP to try and fix https://github.com/DeadlyBossMods/DeadlyBossMods/issues/2102  
- Some rename tweaks  
- Switch light/void dive back to private aura. trying to use the blizz warning text isn't clean because they happen at same time (therefor cannot cleanly be disambiguated)  
- Begin next phase of rename api rollout. (#2100)  
- Fix checkout misbehaving  
- Fix extra space in version messages  
- bump alpha  
