# <DBM> World Bosses (Dragonflight)

## [10.1.9](https://github.com/DeadlyBossMods/DBM-Retail/tree/10.1.9) (2023-05-18)
[Full Changelog](https://github.com/DeadlyBossMods/DBM-Retail/compare/10.1.8...10.1.9) [Previous Releases](https://github.com/DeadlyBossMods/DBM-Retail/releases)

- Fix a bug that caused cast announcements to use wrong cast time to appear if alert was using short text name (alternate spellID)  
- adjust sunder reality to just always use the 29.1 timer, since it can be that short on any cast, it's just ALWAYS that short on first cast (and rest are usually 30.4). However, it's clear it's not accurate to ASSUME the rest are always 30.4, cause I've gotten evidence that sometimes they can be 29.1 as well  
- Don't nag about motes if you're getting hit by them on purpose with void fracture  
- Rashok Update:  
     - Fixed bug causing tank taunt logic not to work correctly  
     - Fixed bug causing tank timer not to start correctly after first cast each rotation  
     - Fixed bug that caused searing slam timer not to work after first cast each rotation  
- Merge branch 'master' of https://github.com/DeadlyBossMods/DBM-Retail  
- Fix even more places that can fail maybe?  
- Change this function. it expects a string, so it should just explicitely refuse anything that's not one.  
- Fix possible error on rashok?  
- Echo of Neltharian Update:  
     - De-emphasize ebon destructoin initial warning since the move warnings are already empahsized. resolves what feels like double alert on cast start.  
     - Changed how adds left warning work to say how many left alive as opposed to how many left hidden, and fixed count  
- Merge branch 'master' of https://github.com/DeadlyBossMods/DBM-Retail  
- Filter non tank specs getting hit by cudgel  
- bump alpha  
