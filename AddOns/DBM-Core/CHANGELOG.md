# DBM - Core

## [11.0.10-34-g2130048](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/2130048ed80787a9f235bdb5d79d4159ec896c0f) (2024-09-16)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.0.10...2130048ed80787a9f235bdb5d79d4159ec896c0f) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- missed closing bracket  
- more option text  
- Update commonlocal.ru.lua (#1240)  
- luacheck has become a picky whiner  
- Core Update:  
     - Add auto icon stripping from objects if icon isn't passed as an arg. useful for options that need to be dynamic  
    Raid Update:  
     - Bloodtwister Ovinax now has an dropdown menu allow raid leader to override icon and yell behavior for entire raids Egg Breaker settings. Options Include matching bigwigs for mutli mod compat, doing DBMs own way, disabling icons but still having yells, or doing nothing at all so you can use own weak aura solutions.  
- tweaks and make this on by default (but after my nap I am adding a raid leader override option for those using weak auras for this. but for average player, this is better after some discussion with JW)  
- further improve concistency of custom role checks  
    in addition, add print messages if a role check fails because player is missing libspec (IE doesn't have DBM, BW, or Weak auras installed, which ALL embed the lib)  
- Remove ranged classification from mistweaver monks.  
- Core: Add tests for ordering functions, minor fix  
    The only diff to the sorting functions themselves is in SortByRangedRoster() which didn't correctly sort by groupd id  
- fix missing spellId  
- Update koKR (#1237)  
- Remove old event register check (#1239)  
- Tests: Add Mock for IsInScenario()  
    It'll just return true for the entire duration of the test if instance type is scenario  
- Core Update:  
     - Add more ability to inject custom names into announce objects when not using spellIds  
    Raid Updates:  
     - Clarified two warning messages with better text and audio on Bloodbound Horror  
     - Added missing knockup message and timer for queen Ansurek  
     - Improved voice pack audio for some abilities  
     - Made interrupt code for null barrier a bit more intelligence in dealing with dark barrier  
     - Preliminary short text pass  
- Shift icons used to prioritize skull and x caster adds and actually use lower priority mark on tank add for Bloodbound Horror.  
    Upgrade rain of arrows alert on sikran to be a dodge alert and delay alert til actual swirls appear.  
- remove these unused checks  
- cleanup and simplifications  
- cleanup  
- 🤷‍♂️  
- raid roster fallback  
- Change how delve difficulties handled for ? and ?? to just be "normal" and "mythic" since it's basically "easy and hard" difficulties. this language users will understand when reading statistics  
- Short icon say messages no longer include number, globally. a lot of mods still pass it but it'll just be ignored now. often times icon assignments from other addons and weak auras just don't follow sensical sequential ordering so including number no longer makes sense, just the icon.  
    Added ability to define IsMelee checks to return false for healers  
    Added a new sort method that should be considered WIP and not finished.  
    Added WIP icon says and marking changes to Ovinax that was requested to help RWF splits. This setting is OFF by default because I still stand most will use a weak aura for this and this is primiarly so echo or liquid can ask DBM users helping do splits to enable say messages on Ovinax for egg breaking.  
    removed "incomplete module" message from queen ansurek. while mod isn't 100% done (no mythic or LFR data). the print is misleading for the currently enabled modes (normal and heroic)  
- Tests: Call DBM:ScenarioCheck() on start to trigger scenario detection  
    That doesn't make everything work, but it triggers combat detection and the mod works for one fight :)  
- Tests: Handle name scrubbing failures more gracefully  
    Instead let the leak detector handle this for when we care about name leaks  
- Tests: Support negative UnitPower (which is somehow a thing)  
- Tests: Handle server names in targets better  
- Tests: Filter fake PLAYER\_INFO events from test log  
- Revert "add nil checks for names guids and targets, cause they don't always exist. seems to fix parser issues i was having at least."  
- couple more tweaks. only warn for lines on YOUR platform  
    Fix acidic apocalypse timer not canceling on stage 3 start  
- fix some bugs seen in my normal queen kill  
- add nil checks for names guids and targets, cause they don't always exist. seems to fix parser issues i was having at least.  
- Add infesting swarm personal alert and yell to trash module in palace  
    super minor timer tweaks seen in debugging  
- fix bad option key  
- prep new alpha  
