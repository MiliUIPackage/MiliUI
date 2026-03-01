# DBM - Core

## [12.0.26](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.26) (2026-02-26)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.25...12.0.26) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Update Translations (#1933)  
    * Update translations  
- prep new tag, since testing found no further bugs. Hybrid objects work perfectly now  
- Fixed incorrect args  
- - Update announce, special announce, and timer objects to support using hardcoded timers in a more seemless way with encounter api  
       - existing objects can easily be upgraded to hybrid objects (where they're both hard coded AND can fallback to internal timer/announce apis as needed)  
       - Updated dimensius to be first example of some of these practices  
    - Updated regular timeline only object to be more consistent with alert only object.  
- debug text tweak  
-  - Fixed a bug where DBM core didn't register safe CHAT\_MSG events in core that would result in some world bosses not engaging (or detecting victories based on those chat messages).  
     - Properly fix remaining bugs with UNIT\_HEALTH combat detection on retail. It can still be used for engaging bosses in situations where unitidentity isn't secret (like outdoors) even if health is secret. It'll now always treat engaging a world boss as "in progress" though and invalidate record kill times at all times. There is just no way around that if we can't check if boss was at full health when engaging.  
     - Fixed several bugs in classic where GetBossHP could fail to return boss HP due to several obsolete checks that were preventing nameplates, focus, and boss unitIds from being checked at all.  
