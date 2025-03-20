# DBM - Core

## [11.1.10](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.1.10) (2025-03-17)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.1.9...11.1.10) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep tag  
- Fix typo  
- Add a mugzee mythic test  
- Push gallywix mythic mod and test  
- Fix bug where timers could restart on a wipe for Sprocketmonger Lockenstock  
- Core: Implement countdown timers using DBT callbacks  
- DBT: Add callback support  
- mugzee  
     - Don't reset counts til stage 2  
     - Add timer for electro shocker spawn in stage 2  
- MugZee Update:  
     - Updated all timers for Mythic  
     - Added optional off by default icon marking for crawling mines  
     - Spray and Pray target warning is now faster  
     - Finger Gun now has improved target warning  
     - Double whammy now have improved target warnings  
- Stix:  
     - Added personal timer for tracking ball duration with countdown enabled by default.  
- One armed Bandit update:  
     - Rework a ton of timers to account for more variances caused by spell queues and delays as well as differences between heroic and normal and mythic all accounted for much better  
- Cauldron of Carnage Update:  
     - Fix beam alert/yell not working since blizzard removed target debuff from combat log (even though it's target scanable and has a whisper)  
- Fix and close https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1582  
- refix https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1581 since the actual problem is blizzard finally disabled the script bunny event I was using. fortunately they seem to have added another event at original script bunny time stamp so this should fix the stage 1 restarts on sprocket to be cleaner.  
- fix gallywix header not showing used icon  
- bump alpha  
