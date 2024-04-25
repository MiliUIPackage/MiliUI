# <DBM Mod> Raids (DF)

## [10.2.35](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/10.2.35) (2024-04-15)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/10.2.34...10.2.35) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep new tag to fix cataclysm and retail errors with a new object introduced in cataclysm mod revamps  
- Clear up some LuaLS errors on globals in Core  
- Remove DontShowPTCountdownText since in 10.2.7 and 4.4.0, disabling that text no longer will be possible since we'll use blizzards own countdown timer. To do so would require tainting blizzards countdown function, which we no longer want to do.  
- Update koKR (#1031)  
- Update localization.es.lua (#1033)  
- Update localization.es.lua (#1032)  
- Add enum for role/spec-based option defaults  
- All shamy specs are MagicDispeller  
- Update README.md  
- Update README.md  
- OptionName can also be false  
- rename cleave to soaks on fyrakk  
- make DBM:GetRaidSubgroup easier to call on player unit  
- only play sound for missing dungeon mods on retail and cata (where dungeons are more difficult)  
- fix last  
- Add yet another object needed for cata classic  
- Better handle blizzard auto canceling timer on early pulls  
- small bugfix to zone filter  
- Use blizzard countdown in cataclysm and 10.2.7  
- Update localization.ru.lua (#1028)  
- Update koKR (#1029)  
- Fix HasInterrupt for Shaman roles in classic (#1030)  
- Resolve https://github.com/DeadlyBossMods/DeadlyBossMods/issues/950  
