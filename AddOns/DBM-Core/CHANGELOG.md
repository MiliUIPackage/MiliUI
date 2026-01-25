# DBM - Core

## [12.0.14](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.14) (2026-01-24)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.13...12.0.14) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- fix quick bug with hiding  
- Support up to 2 icons instead of capping at 1.  
    Next update will focus on more configuration options like choosing number of icons, or whether they are large or small and stacked like timeline.  
- prep new tag  
- Support journal icons next to timers in midnight  
- auto expand options by default in midnight  
- Sometimes blizzard uses State to cancel bars instead of the actual cancel event. support this as well to fix bars not hiding in some cases (like exiting edit mode) when blizzard cancels them  
- honor new viewtype setting and set it to correct type on show  
- Add proper defines and now first fix should work  
- Last should have been valid,b ut just fix it this way to appease LS  
- Fix errors in last  
- Fix timeline code for 12.0.1 beta 7  
- Fix bug that caused "your next" brawlers alert not to fire  
- make brawlers update classic compatible  
- Add a way for event handlers to bypass the restricted events in midnight when mods wish to call them in a safe manor  
    Restore even more brawlers guild functionality as a result such as fight berserk timers for OTHER fighters  
- Add DBM-Affixes to banned mods and remove custom GUI code for it  
- Delete DBM-Affixes . It's retired in midnight.  
- add protection against new beta 7 secrets  
- bump alpha  
