# DBM - Core

## [11.1.7](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.1.7) (2025-03-07)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.1.6...11.1.7) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Prep new tag  
- Add user request to auto mark gaol targets. Should be combat with BW users  
- add heroic gallywix timer data  
- Mythic timer tweaks for carnage  
- Add a lot more gallywix normal data and fixed up taunt warnings on fight a little bit  
    Updated rik heroic timers with some mid weak changes from blizzard.  
    tweaked tank warnings on rik again to be further aggressive at minimizing stacks  
- nearly perfect now in structure and functionality, just needs some data fill in now.  
- Because DBT can't get it's shit together, all 77 (and counting) mods that do this just need to work around core bug  
- gallywix mod restructure work. needs data population but it's quite a bit more ready now  
    Fix infoframe not hiding on combat end iwth carnage for real this time  
- add some nil error filler timers though  
- preliminary gallywix stuff, but only stage 1 timers. there is a gross lacking of sufficient stage 2 and stage 3 data on any difficulty due to normal being radically undertuned and phase 2 lasting like 30 seconds, and heroic parses being scarce (only kills are again those that just overgear it and steamroll it too fast).  
- Fix and close https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1556  
- Attempt to fix random vexie timer error. Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1557  
- rework mugzee timers for normal and heroic on live  
- fix cauldron lua error  
- Update RU locale (#1552)  
    * Update commonlocal.ru.lua  
    * Update localization.ru.lua  
- Update commonlocal.tw.lua (#1553)  
- Update koKR (#1551)  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Revert  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR stings in tocs  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    * Update koKR  
    ---------  
    Co-authored-by: Adam <MysticalOS@users.noreply.github.com>  
- Update lockenstock normal and heroic timers from live  
    Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1555  
- Rework one armed bandit timers with the changes on live.  
- Micro adjust some heroic timrs on Cauldron.  
    Fixed bug on caudron that caused Salvo timer not to start after first  
    Fixed a bug on mugzee causing surging arc to give unknown target  
    Fixed some minor timer incorrectness on Rik Reverb normal'  
    Fixed initial timers on Vexie and scrapped Bomb voyage timer  
    Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1554  
- local luacheck doesn't error on that :D  
- Fix 3 bad tank swaps  
     - Tweak rik taunt behavior to be more often  
     - Fix bad taunt behavior on lockenstock. this boss does NOT permit swapping targets mid cast.  
     - remove bad taunt warning from stix for demolish, you only swap for balls  
- posisbly fix lua error? taht value shouldn't be nil though...  
- Timer fixes to rik reverb and cauldron for LFR difficulty at least  
- bump alpha  
