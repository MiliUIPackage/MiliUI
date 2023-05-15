# <DBM> Dungeons (Dragonflight)

## [r79](https://github.com/DeadlyBossMods/DBM-Dungeons/tree/r79) (2023-05-11)
[Full Changelog](https://github.com/DeadlyBossMods/DBM-Dungeons/compare/r78...r79) [Previous Releases](https://github.com/DeadlyBossMods/DBM-Dungeons/releases)

- Freehold  
     - Fixed a bug where shattering Bellow had an interrupt warning. it can no longer be interrupted  
     - Changed warning aggregation for Brutal Backhand and Blade barrage from 3 seconds to 2 seconds. 3 seconds is too big of a window and can result in a tank missing a critical avoid warning if pulling large groups of these mobs  
     - Fixed bug where Harlan would report bad debug information on timers. It didn't cause any actual timer issues but it created invalid debug logs  
    Underrot  
     - Fixed bug where underrot trash gave a CC warning for Dark omen. This mob is now immune to CCs  
     - Removed void spit CD timer. the recast time of it seems to now be much much lower  
    Vortex Pinnacle  
     - Updated Asaad timers with new timers fight is showing on live. It seems this fight was changed after latest PTR round of testing.  
    Halls of Infusion  
     - tweaked Belly Slam and Croak timers on Goliath to be 1 second shorter  
     - Tweaked Dazzle and Whirling Fury timers to be slightly shorter  
    Uldaman  
     - Updated Chrono Lord Deios timers back to their pre nerf state. At some point on PTR the boss was nerfed to have faster phases so you got more timer eversals. on live it seems this nerf was reversed and he once again has his longer and more difficult phases  
     - Fixed bug where Lost dwarves mod gave invalid target scans for SKullcracker and heavy arrow. These abilities have no target scan and are now generic alerts to watch your surroundings  
     - Fixed a bug on Emberon where he wasn't showing nameplate timers on Plater nameplates when feature in Plater was enabled.  
     - Fixed a bug where Jagged Bite and Bulwark Slam would show invalid CD timers if the cast didn't finish. These abiliteis don't go on cooldown until cast finishes and this is now how timers will behave in DBM and on Plater nameplates  
