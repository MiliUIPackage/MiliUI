# DBM - Core

## [12.0.32](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.32) (2026-03-24)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.31...12.0.32) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- helps if you actually bump version first  
- Update translations (#1982)  
    * Update translations  
- Update koKR (#1976)  
    * Update koKR  
- Update localization.ru.lua (#1979)  
- Updated some voice audios across raid to be much clearer with intent  
    Fixed some alerts that were scoped incorrectly (assigned tank only but were tank mechanics that affect whole raid)  
    Updated more hardcoded shortnames  
    Tightened intermission 1 detection on crown  
- fix backwards timers  
- Fix bug causing double sounds when using crown hardcode in stage 1. Caveat, the firs cast by each of the 3 blueberries will have no sound (due to fact they all have an initial cooldown of 6 seconds therefor we can't actually tell them apart)  
    Enable hardcode for heroic salad bar, its same as normal  
- Add more spell renames to Averzian  
    work around a blizzard bug that causes 2 umbral timer never to show (since blizzard auto cancels it by mistake)  
    Fix a DBM bug that causes shadow advance 2 timer not to show  
- fix one missed mistake  
- Make luaLS happy  
    add more robust guards to crown breaking  
- Stage 2 and 3 fixes for crown hardcode  
- Fix some debuglog log spammy events that aren't required most of the time.  
    More aggressively unregister private aura anchor any time it's adjusted to try and resolve regression where duplicate anchors got left behind.  
- Fix scope. Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1981  
- tweak defaults again, with more robust fallback tech  
- fixed a bug where variance window calculations were ran when variance was disabled, causing it to perform calculations only on min time with no max time, incorrectly calculating window  
- fix nil error  
- no idea how this got lost again  
- Refactor Private Aura Features for new restrictions (#1980)  
     - Refactor Private Aura Sounds to register on entering zone and unregister on leaving zone. If in combat when this happens, delay until leaving combat. The dropdown for changing a private aura sound will attempt to hot swap the registered PA sound but if in combat will warn user that it failed and to change sound out of combat.  
     - Refactor Private Aura Anchor frame to also register on entering and unregister on leaving zone. In addition, this will also trigger a fresh update on roster changes (throttled) to make sure we don't miss any newly added (or removed) units.  
- resolve LuaLS  
- refactor some count logic for hardcodes  
- Some chim fixes  
- Fix debug lua error  
    Possibly Fix another timeline hardcoded race condition cancel issue  
    Have hardcoded mods not aborb to fallback if debugmode is enabled.  
    Fix a logic bug with CHimaerius hardcode if group has slow dps and doesn't trigger the 10 second phase reset bar.  
- Fix arg name  
- further improve hardcoded debugging  
- Improve some debug.  
    Add some common locales  
- fixed bug where devouring cosmos was lacking count  
- Improve Debug  
    Added some renames to crown hardcode  
    Removed some unused options from crown module  
- blizzard hotfixed this out because healers were mad  
- change option defaults  
- ^  
- fix luaLS  
- fix bad copy and pate indentation  
- Improve Debug by logging hardcoded stage change events  
    Throttle ENCOUNTER\_WARNING events on a global level since blizzard still can't figure out how to use their own api correctly to avoid spam.  
    Fix count discrepencies with hardcodes  
    Added support for a 2nd co tank in private aura anchor  
    Added preliminary crown hardcodes  
- Fix Seat keys.  
- tweak  
- More robust timer logic to solve race condition cancelation of timers before they even begin.  
- Fix debug quirk that made it falsey report hardcoded terminating that wasn't actually hardcoded  
- reduce log size somewhat  
- work around blizzard bug with dive timer where they start a 30 second timer, when they should start a 10 second one.  
    enable heroic mode for hardcoded Averzian timers  
- Alleria update:  
     - Fixed some timers and warnings not playing sounds as intended or setting color as intended  
     - Changed some sounds to ones that make more sense  
     - Got rid of spammy sound during intermission  
    Improved debug in hardcoded mods  
- improve debuff, eliminate redundant event  
    fix bad spellid in alleria  
- fix bug where private auras were unregistered if you died in combat  
- fix debug so it always fires, even during hardcoded timers or disabld timers  
- Maybe fix https://github.com/DeadlyBossMods/DBM-Dungeons/issues/592 for real this time, but doesn't explain how player class is valid but color is not?  
    Update private aura sounds and anchor to avoid registering or unregistering in combat.  
- debug fixes  
- Further debuglog improvements  
- Use berserk object on chimaerus instead of rift cataclysm timer  
- Improve LuaLS annotations  
- Double dragons hardcode  
- fix option key location  
- Add toggle for hardcoded timers so they can be disabled globally as needed  
- actually, use 3.5 instead. so it acts as a 1.5 prewarn  
- missed one hardcoded warning, which fires on 5 second delay  
- King Shalhadaar hardcode  
- Refactor hardcode for Chimaerus and Vorasisu to fix bug where warnings would fire on phase changes eroniously  
    Add Imperator averzian hardcode  
- Improve debug to capture both original and rounded duration, in event we can sometimes use decimal to detect differences that we can't with rounded (ie situation where one timer is 12.7 and one is 13.2, but both have a rounded value of 13)  
- Vorasius hardcode  
    fix regression in chimaerus with private auras  
- Update translations (#1974)  
    * Update translations  
- Chimaerus normal hardcode  
- oops, missed a line  
- Lets do this a different way. Fix and close https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1975  
- Improve debuglog with more coloring  
- clean up some debuglog spam  
- Encounter Warning approach didn't work for fixate, use private aura instead  
- fix hole in debug where it wasn't logging event ID on timer start  
- couple event type tweaks  
- Some sound and event tweaks  
- Fix debug frame so it doesn't block scrollwheel or pinging when "invisible" by having it move off screen instead of becoming transparent and clickthrough.  
- fix some debug errors  
- Fixed bug where void breath played no sound  
    changed some sounds for clarity on Shalhadaar  
    Improved debuglog  
- Fix bug that causes debuglog button to not be click through  
    changed default size of debuglog  
- Update koKR (#1972)  
    * Update koKR  
- bump alpha  
