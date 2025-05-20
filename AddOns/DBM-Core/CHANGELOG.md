# DBM - Core

## [11.1.19](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.1.19) (2025-05-20)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.1.18...11.1.19) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- make expected balls a recoverable variable  
- Prep new tag and set as mandatory update due to new media required by visions mod tomorrow and stix bugfix  
- Fix bug with stix countdown yell causing it to use wrong object and spam nonsense  
- Fix bug causing auto gossip options to still check invalid option key  
- Update localization.es.lua (#1661)  
- Fix ruRU TIMER\_FORMAT (#1662)  
- Aggregrate marked for recycling  
    Change TTS for sorted to be less directive since about half players doing fight on mythic choose to ignore DBM/BW built in icon features and use conflicting weak auras instead  
- Fix feral druid tank detectoin in cata classic  
- Fix and close https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1660  
- Fix gobfather not functioning  
- add debug  
- slow down stix icon marking to 1000ms (1 sec) instead of 500ms so zone combat lag is less prone to breaking icons. however, it'll also speed up marking once it reaches expected number of targets now such as 4 on mythic and 5 on 30 man heroic  
- Update zhCN (#1659)  
    * Update localization.cn.lua  
    * Update localization.cn.lua  
- Undermine Update:  
     - Alert taunt on additional stacks of vexie debuff, if off tank missed first swap  
     - No longer zone combat scan for trash since we won't be collecting nameplate timers for trash in this raid.  
     - Cleanup out of date comments and updated additional notes  
- bump alpha  
