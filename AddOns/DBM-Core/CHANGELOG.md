# Deadly Boss Mods Core

## [9.1.1-18-g79af9bc](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/79af9bc8a0c40c8c87dafbfb2988e439fbb1b094) (2021-07-08)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/9.1.1...79af9bc8a0c40c8c87dafbfb2988e439fbb1b094) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

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
