# DBM - Core

## [12.0.50-2-gd61e8a2](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/d61e8a2911f16f1433e43572bc0cdd59ddc1b238) (2026-05-18)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.50...d61e8a2911f16f1433e43572bc0cdd59ddc1b238) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Allow DBM to enhance blizzard timeline bar colors even if DBM bars are visible (#2083)  
     - Old behavior. If a user had both dbm bars and timeline bars enabled (not sure why but I see it a lot). DBM wouldn't recolor timeline bars. DBM only did this if DBM were were explicitely turned off  
     - New behavior. DBM will always enhance timeline bar colors using DBM settings (unless user explicitely disables this in DBM feature disables section)  
    Countdowns are handled the same as before. If using DBM bars, countdowns are handled through DBM bars object, but if DBM bars are disabled, countdowns are registered to blizzard bar object (with limitation that it can only be a 5 count or 3 count)  
- bump alpha  
