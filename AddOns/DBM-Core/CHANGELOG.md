# DBM - Core

## [11.0.22](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.0.22) (2024-10-20)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.0.20...11.0.22) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Update commonlocal.ru.lua (#1334)  
- Set better defaults for nameplate offset for blizzard nameplates. force reset settings for all users this one time.  
    I apologize to users who set their x/y offsets custom to where they wanted em. You'll have to do this again just once. The setting won't reset again.  
    But this reset was needed to improve experience for a lot of users since old defaults caused overlap with player buffs/debuffs when not using 3rd party nameplates.  
- prep new tag  
- do last more efficiently  
- Fix test mode (which still relies on test mode timer objects)  
- Optmize memory usage by a few bytes using smarter mod caching  
- Split nameplate callbacks from timer callbacks since existing weak auras are unable to split them on their own (due to WAs addon not supporting DBMs type arg)  
    this is probably better practice in long term anyways cause it'll make knowing difference between timer and namplate timer far more clear anyways (and easier to support) externally.  
    in short term though this is gonna utterly break some 3rd party mods and weak auras that were parsing timer callbacks for nameplate timers  
- affixes mod still needs special handling so it can run concurrently to any zone based mod  
- Fix handling of cached mods when more than 2 register at once (at least 9 are gonna register at once when done). Still needs cleaner way of handling toi avoid caching so many mods at once. but doesn't harm cpu usage, just wastes few extra bytes of table memory.  
- remove obsolete note, already fixed that  
- fix one more glaring bug  
- Bugfixes. fully functional now  
- timing tweak  
- further scope for more performance savage  
- makes sure affixes mod actually triggers full unregister when UnregisterZoneCombat is called  
- which affixes to new event handlers only and further optimize usage to avoid unnessesary registering (ie if no xaleteth affixes detected)  
- fix event registers  
    more performance optimizing  
- Performance pass on zone combat scanner  
- Allow registering multiple zones at once for combat  
    have mythic+ affixes mod use the new object if in debug mode (and old one built into mod if it's off)  
- couple tweaks  
- Initial work on the zone combat scanner which will be able to cancel nameplate timers to mobs we wiped to, and start initial nameplate timers for mobs we pull  
    in addition, the the existing combat checks of M+ affixes module will be able to migrate to new zone scanner soon to eliminate redundancy  
- Code cleanup of old DF seasonal dungeons still being in seasonal check  
    Seasonal check code more streamlined for reuse in more places  
    Seasonal dungeon check now performed in trivial check, fixing some alerts being deprioritized in non M+ versions of current season dungeons and fixing auto logger not auto logging M0 or heroic dungeons that are scaled up (ie not TWW dungeons).  
- shorten heroic null detonatoin timer too  
- Update koKR (#1331)  
- validate "findclearvent"  
- Fix missing nil check  
- Enable the M+ Affix timers for everyone. At least the two added on beta, since preliminary testing seems ok  
    Update combat detection to also scan nameplate units, improving combat detection against dungeon bosses in classic that no one is targetting when they are pulled  
- Update localization.fr.lua (#1322)  
- Mini dragon patch 1 (#1325)  
- possibly fix https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1320 without using localization  
- Fix bug causing timer and count not updating for soak on first boss. at some point the event changed and I missed it  
- Update commonlocal.ru.lua (#1315)  
- move waves to spell cast success  
- Update localization.es.lua (#1312)  
- Update commonlocal.ru.lua (#1308)  
- Update localization.fr.lua (#1313)  
- Update koKR (#1314)  
- Update commonlocal.fr.lua (#1311)  
- Update commonlocal.br.lua (#1310)  
- Update commonlocal.es.lua (#1309)  
- ansurek timer tweaks  
- Tests: Update Mythic tests for Nerub-ar Palace  
- Tests: Fix bug in anonymizing synced RAID\_BOSS\_WHISPER events  
- Tests: Fix some errors in report generation when using unusually configured warning objects  
- Tests: Support updating GetInstanceInfo() dynamically during tests  
- Common locale: Add "and" and "or"  
- fix timer error (bad copy paste?)  
- Increment alpha  
- Prepare 11.0.21 tag  
- Core: Fix BWL difficulty detection (#1304)  
- bump alpha  
