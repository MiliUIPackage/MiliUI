# DBM - Core

## [11.1.5](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.1.5) (2025-02-28)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.1.4...11.1.5) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep new tag  
- Full undermine pass:  
     - Improved weak aura pack compatability  
     - Fixed a few test mode bugs  
     - Tweaked some warning clarity  
     - Added some misc stuff  
     - Pruned some deleted stuff  
- Delete "C'Thun: You will Die" sound from dbm options. at some point blizzard deleted it from game so it's just no longer available.  
- decouble beam alerts on ansurek and just use distance check instead. Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1544  
- Fix something that shouldn't have slipped through  
- send unitID with start engage timers  
- Fix resets  
- temporarly remove luaLS workflow for now. will be restored when it can be fixed, but right now I don't want to be spammed emails for failed builds for next two weeks.  
- latest cata patch is now tainting when trying to hide quest frame, just like retail does, so scrap feature there as well.  
- Update localization.br.lua (#1542)  
- Update localization.fr.lua (#1543)  
- Update localization.es.lua (#1541)  
- New fancy color selector (#1545)  
    * New fancy color selector  
    * Fix warning  
- block encounter music in scenarios entirely, it's extremely problematic with existing code and too much time and effort to fix  
- Update koKR (#1539)  
- Update localization.ru.lua (#1540)  
- Add color option to variance bars  
- Core: Fix tracking of started timers for keep-style timers that are being canceled (#1538)  
- fix some incorrectly set spellids  
- Update localization.es.lua (#1537)  
- Tests: Be more resilient to unknown spells  
- Core: Throw error on bad string timer spec  
- Core: Fix Naxx normal difficulty detection  
- Push preliminarly Gallywix drycode  
- Change stating and counts to synergize better  
- Fix bug with screw up timer on normal and LFR difficulty sprocketmonger  
- Fixup mugzee and one armed bandit from extensive test moding  
- apparently it wasn't removed, just match sensitive now  
- Apparently blizzard decided to remove support for using group and category together, it's one or other, or neither.  
- Variance: fix var to non-var timers not showing while on Debug and timer<0 (#1535)  
- Update localization.cn.lua (#1534)  
- mod cleanup  
- bump alpha  
