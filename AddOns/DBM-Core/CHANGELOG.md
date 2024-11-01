# DBM - Core

## [11.0.25](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.0.25) (2024-10-30)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.0.24...11.0.25) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep new tag for ansurek hotfixes  
- final tweaks with real data  
- tweak  
- quick push updated P1 timers for queen  
- Add Masque optional dependancy to ensure it always loads before DBM. This will protect Masque's ability to customize icons before DBM loads libCustomGlow. Fixes and closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1340  
- better fix  
- Update commonlocal.cn.lua (#1347)  
- Update commonlocal.tw.lua (#1345)  
- attempt to fix https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1349 by adding a nil check to something that shouldn't ever be nil 🤷‍♂️  
- fix luaLS  
- Improve timer debug  
    Fix parse transcriptor error  
- Add soak beam  
- small tweaks  
- Implemented a prototype in Zone Combat Scanner that can be used for many dungeon and even raid bosses that are councel type fights to start nameplate timers on engage without duplicating same ugly code across many modules. This simplifies process  
    Optimized target list building in DBM core by eliminating redundant unit scans caused by leftover idea (that eventually became zone combat scanner). This function is now more optimized but still better than original. Should fix and close https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1343  
- update voice pack audo list  
- Bump alpha  
    Add backup event to combat zone detection in event you don't detect Unit flags due to wipes  
