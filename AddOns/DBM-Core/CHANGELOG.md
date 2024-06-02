# DBM - Core

## [10.2.43](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/10.2.43) (2024-05-27)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/10.2.42...10.2.43) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep new tag  
- use that check here too  
- code cleanup and option clarification  
    also fix a bug where remix stuff wasn't auto logged  
- Rework specrole to use specID in cataclysm since blizzard created an API for it in classic finally (era still doesn't have it yet, hopefully in next sod phase?)  
    As a result, also enable LibSpec on cata classic as well since we can actually identify unique spec IDs and use them. This enables more accurate checks  
- Some fixes to internal spec info table  
     - Priests can't interrupt in classic (silence doesn't work that way til legion-ish)  
     - Not all druids are healers/tanks in cataclysm. Missed this when cleaning up the hybrid stuff that was common in vanilla  
- Update voicepacksounds  
- Fix some docs  
- Improve more api docs of common DBM extra feature options  
- Fix bug  
- Update GameVersion.lua  
    Force value inside wrapper, for potential weird case?  
- allow even stricter filtering for valid warning check  
- preliminary code to support story mode raids and quest dungeons  
- Update .pkgmeta  