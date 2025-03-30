# DBM - Core

## [11.1.12](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.1.12) (2025-03-29)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.1.11...11.1.12) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep new tag  
- Add rolling rubbish alerts and TTS to help improve player awareness on stix  
- Revert "Core: Implement countdown timers using DBT callbacks"  
- backup LFR stage trigger for gallywix. it's not a true trigger but it'll do for now.  
- missed one line in last  
- more LFR tweaks to stix and one armed  
- Gallywix  
    Don't break if you fail to interrupt on start of stage 3 or stage 1 mythic. This is usually a wipe anyways, but at least it won't wipe with lua errors with backup stage trigger  
- Update lockenstock for LFR  
- fix bug causing crawler auto marking not to work correctly on mugzee  
- work around race condition that can cause the soak TTS on mugzee to be inverted (saying group 2 first then group 1).  
- small future proofing stage tweak  
- Try to fix impossible stage desyncs (can't reproeduce so don't know actual cause so taking blind shots)  
- Fix and close https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1594  
- Improve tank code for double whammy  
     - It'll now alert to soak much much earlier as intended  
     - Timer will now be for when hidden debuff goes out (red line) and not for when cast starts.  
- Fix burning blast spam  
- scrap surging arc alert/yell. it's not entirely reliable and not that important either.  
- only start bars for 3 static charges  
- CI: Use same dir setup for both LuaLS checks  
- fix another typo and satisfy new nil check condition  
- fix typo in last  
- LuaLS: Use enum for VPSound  
- Fix incorrect wire transfer timer on normal lock. Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1585  
    Fix win firing early vexie. Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1586  
    Fix tank soak yells on mugzee to be more clear and use correct text color  
- DBT: add variance texture dropdown (#1591)  
- DBT: fix texture not updating when selecting (#1590)  
- bump alpha  
