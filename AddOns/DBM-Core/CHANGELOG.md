# Deadly Boss Mods Core

## [9.1.1-30-g415248c](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/415248c24406725485f86a604455b30a64e6175a) (2021-07-10)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/9.1.1...415248c24406725485f86a604455b30a64e6175a) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- rename zhTW to localization.tw (#609)  
    Sorry, I made a mistake.  
- Creat zhTW.lua (#608)  
- Redid the heroic sylvanas timers for P3, post July 9th hotfixes. Although something tells me, I will be redoing these timers again since I don't think some of these changes were intentional, just side effects of fight enrage/length tweaks that resulted in two mechanics virtually vanishing from the phase.  
- Hide infoframe in stage 2 sylvanas since it doesn't do anything there ATM, but then reshow it in stage 3 to track bane stacks  
    Improved bane warning to announce all stacks not just initial application  
- Fixed minor bug with source name missing in ruin interrupt warning  
- Updated spiked balls to use CLEU event on raznal and updated first timer now that locks are easier to read. 👍  
    Updated heroic P3 timers for sylvanas to include further data  
- extend P3 data on heroic sylvanas just a bit longer from latest public logs, before heading to bed  
- Fulfil 2x request to use icons for traps, including yells/etc on raznal. while at it, fixed a bug where target warning never actually fired and showed who traps were on (other than personal warning)  
- fix typo  
- First KT update  
    Update initial KT timers, and updated timers for KT at a 100/0 mana phase change.  
    Disabled timers for other mana phase changes since they won't be applicable anymore. Those need verified logs phasing at those values  
    Fixed frost blast detection in phase 3 and updated P3 initial timers  
- Begin populating P1 and P3 heroic timer data from public sylvanas wipes  
- Update BW version check, which I might have neglected for a while, oops  
- Good catch luacheck!  
- Populated timer tables for normal sylvanas, heroic still needs work, but no public logs yet.  
    Also added timers for the heartseekers  
- copy/paste is hard  
- Small tweaks to guardian, ultimately though the timers on this fight are going to suck really bad. the only way to map them out correctly is to do the impossible, get a long pull where boss has infinite energy and doesn't have timers screwed with by phasing. Since that won't happen, there is insufficient data to determine how to properly handle phasing interaction on timers.. Can't solve for C if A or B are missing.  
- Fixed suffering warning not working and timer not working after first.  
    Unfortunately blizzard left the fight as it was on PTR which means almost none of timers are useful anyways. It is what it is.  
- Fixed annoying announce on frost blast root debuff on KT, it should only announce initial target.  
    Raznal Update:  
     - Updated all timers for live data  
     - Added missing switch warning for spiked balls  
     - Upgraded all timers to count timers  
- stray end in copy/paste  
- Rohkalo Update:  
     - Finished timer sequencing and enabled more accurate timers on normal and heroic difficulties  
     - Fixed phase change detection with new spellId  
- Fix transition scaling working in reverse (#606)  
    * Fix transition scaling working in reverse  
    When going from a higher scale (large) to a lower scale (small), the logic was actually working inverse and growing in side.  
- Soulrender updates  
- Updated timers for the nine with live data  
-  - Updated timers for Terragrue on live  
     - Updated timers for Eye of the jailer on live  
     - Fixed a bug on guardian where icons were never removed  
     - Fixed a bug on raznal where icons were never removed  
     - Fixed a bug on eye of jailer where spreading misery got double announced instead of aggregated. timers don't aggregate though because they can desync  
     - Sylvanas Changes:  
    *Improved wailing arrow and black arrow announces and added icons for the arrow mechanics  
    *Added short names to a few ability timers/alerts  
    *Disabled knives icons by default, it's a bad default and should only be used if not using arrows icons  
- A bit of mythic prep for sylvanas  
- Fire stage callback on variable recovery  
- antispam wasn't multiple events firing it was combat start and emerge. when boss is engaged emerged can also follow (but not always sometimes it's before the IEEU)  
- Add antispam to submerge as these events fire multiple times (#605)  
- Opportunity Strikes seems to be back based on latest journal updates  
- prep next cycle  
