# DBM - Core

## [12.0.36](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.36) (2026-04-05)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.35...12.0.36) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Prep new core, that's a mandatory update for last nights dungeons update.  
- Update role (#2010)  
- tweak that while at it  
- make IEEU debug 12.0.5 safe  
- Fix seat naming consistency  
- simplify  
- Tighten unit identity checks against compound unit token restrictions that C\_Secrets.ShouldUnitIdentnityBeSecret does NOT cover.  
    Should fix and close https://github.com/DeadlyBossMods/DeadlyBossMods/issues/2012  
- Tighten search box to avoid strange secret taints  
- Fix load race condition where private aura voice pack sounds are ignored (and defaulted to generic special warning noises) when reloading UI inside an instance.  
    Update herioc Crown with far more hardcoded timer data  
- Update localization.ru.lua (#2005)  
- Role correction (#2007)  
    Co-authored-by: Adam <MysticalOS@users.noreply.github.com>  
    Co-authored-by: Artemis <QartemisT@gmail.com>  
    Co-authored-by: MysticalOS <mysticalosx@gmail.com>  
    Co-authored-by: Valdemar <54585769+Hollicsh@users.noreply.github.com>  
    Co-authored-by: Elnarfim <37562642+Elnarfim@users.noreply.github.com>  
- Improvements to fallback switching and code duplication cleanup  
- Fix missed audio change  
    force reset consume bar color  
- Fix double dragon hardcode routing firing heroic timers on mythic. instead it'll route to the now added mythic timers (for stage 1) and correctly switch to fallback for the NYI stages  
- Add mythic Salhadar hardcode  
- satisfy LuaLS  
- Handle rare niche case dive situation where the initial dive timer cancels with a state 3 without a 1 second state 2 ending bar to replace it if you manage to time early push at same time as natural push.  
- Add support for mythic chimaerus hardcode  
- missed one string  
- Remove built in Ora3 checks. addon is not well maintained anymore since it's being phased out. Will be replaced with our own checks in future  
- add stage 1 berserk timer to crown  
- Added Phase 1 heroic crown hardcode.  
- Add heroic Lightblined Vanguard hardcode  
- extend P3 heroic hardcode for double dragons  
-  - Fixed a race condition that caused the blizzard bug work around for first bosses soak to not be fully complete at filtering duplicate soak warning. This should work correctly now  
     - Fixed bug where disabled timers didn't still forward timeline apis in fallback mode (since fallback mode cannot actually disable timers yet with shortfalls in blizzard api, we should at least register custom colors to them when they can't be hidden).  
     - Fixed bug where debuglogs perfect page scroll wasn't so perfectand would clip 1 line from previous page.  
     - Fixed bug where starting count on all timers/warnings for Lightblinded Vanguard were always off by -1 count.  
     - Added work around to normal crown hardcode that now autocorrects 3 blizzard timers that are actually flat wrong.  
- fix typos taht can lead to confusion  
- bump alpha  
