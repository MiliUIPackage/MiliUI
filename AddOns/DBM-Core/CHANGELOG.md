# Deadly Boss Mods Core

## [8.3.23](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/8.3.23) (2020-05-28)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/8.3.22...8.3.23)

- Prep New tag with fix to build syncs and spelltimers block to prevent users experiencing errors.  
- Remove no longer used upvalue  
- Add protections against being guildless, or the guild API returning nil or < 1 players online Also changed logic of math.random too for good measure to absolutely ensure that a whole number is being used.  
- Fixed a bug where the right click silent mode feature of LDB didn't get fully merged in  
