# DBM - Core

## [11.1.0](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.1.0) (2025-01-09)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.0.39...11.1.0) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Bump version.  
- based on more data, zone combat scanner should be quite a bit better with these tweaks  
- More tweaks to zone combat scanner  
- forgot to push this  
- Update localization.br.lua (#1478)  
- Update localization.ru.lua (#1474)  
- Update koKR (#1475)  
    Co-authored-by: Adam <MysticalOS@users.noreply.github.com>  
- Update localization.fr.lua (#1477)  
- Update localization.es.lua (#1476)  
- Add additional zone combat debug  
- Push all raid creature IDs now that we have them  
- Add cataclysm PTR toc  
- Blizzard code is ass, so partial revert of last  
- Assign groups and categories for new addon manager in 11.1  
- apparently I didn't hit save  
- tweaks to delay code of zone combat scanner  
- Fix type annotations for new dropdown (#1473)  
- Update localization.tw.lua (#1472)  
- Update zhCN (#1471)  
- New dropdown code (#1470)  
- Update localization.tw.lua (#1468)  
- Update localization.es.lua (#1469)  
- revert one change that'd cause a regression. can't actually indefinitely extend delay due to nature of how you pull mythic+ so it does NOT solve dawnbreaker problem, but it still should solve other stuff.  
- Reduce chance of failed zone combat detection by adding a secondary delayed check in event combat api is slow and fails on first check.  
    Added code to compensate for delayed combat by automatically subtracking delay amount from all initial timers. Even if combat is detected super slowly like dawnbreaker, timers should get auto corrected now.  
- Attempt to solve a problem with intiial nameplate timers for units who are so tall, their nameplate might actually be off screen (ie big dudes in siege of boralus). This fix also attempts to monitor softenemy and mouseover.  
- Add Sprocketmonger Lockenstock drycode  
- fix bug/oversight in last  
- add zone combat syncing for power users, off by default and only enabling by power users aware of risk of throttled syncs  
    disable annoying new LuaLS warnings  
- Fixed bug that caused variable timers not to run correct debug path on count timers  
    fixed another bug where variable timers kept old count timer when starting a new one, if debug mode was enabled (related to same bug as above)  
- Stix drycode  
- Update koKR (#1466)  
    Co-authored-by: Adam <MysticalOS@users.noreply.github.com>  
- Update localization.ru.lua (#1467)  
- Full rik Reverb drycode  
    Fixed improper TTS on aggregation of horrors world boss  
- Fix missing UI option  
- throw a throttle protection in there  
- Add full Cauldron of Carnage drycode  
- correctly label mythic only mechanic as mythic only  
- Push drycode for 11.1 world boss Gobfather  
    Push drycdoe for 11.1 first boss of Undermine, Vexie  
- Update voice pack sounds and bump alpha  
