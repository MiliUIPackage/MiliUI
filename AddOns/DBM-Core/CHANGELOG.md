# Deadly Boss Mods Core

## [9.0.28](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/9.0.28) (2021-05-13)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/9.0.27...9.0.28) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Slight tweak to mythic eye and tag new release  
- Fixes  
- Post testing KT update, which fixes some bugs but not all, more work is needed, especially after blizz fixes couple bugs with fight.  
    Full painsmith Raznal drycode for tomorrows testing  
    Full Nine update from PTR LFR testing, but some things may not match it on heroic, some heroic stuff should use more reliable ai timers though with phasing fixed  
- Hate this luacheck sometime, it couldn't bother to report that in last run :\  
- Fix stupid  
- Changed mythic add icon method (for sire) to be one that's faster but has risk of being less consistent with other boss mods since it doesn't use combat log/GUID order matching. It should mark BEFORE first cast though which is intent of change.  
    Preliminary fixes to fatescribe, remannt, eye, and soulrender  
- Attempt to fix rare cases of missing spec info from api by using exiles reach templates as fallbacks. This will have a quirk of creatig a different className mod profile when it happens but it'll avoid errors.  
- Core will no longer perform ilvl check on ptrs/betas, disabling the warning about gear on pulls  
    Few KT fixes that could be done quickly  
- Fixed missing spellid for normal/LFR version of Eye of the jailer  
- Bump alpha  
