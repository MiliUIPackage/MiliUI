# DBM - Core

## [12.0.27](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.27) (2026-03-01)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.26...12.0.27) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Prep new tag  
- Move TWW out of main repo  
- Fix buildTargetList  
    This should be checking if it IS a creature, not if it isn't.  
- Fix a var type check.  
- Update translation (#1935)  
    * Update translations  
- fix: guard DBM.Test nil access in Playground Mode (#1254) (#1936)  
    Opening Playground Mode with the DBM Tests addon disabled causes a  
    Lua error because DBM.Test is nil:  
      attempt to call method 'GetTestsForMod' (a nil value)  
      attempt to call method 'RunTest' (a nil value)  
    Guard both call sites so Playground Mode degrades gracefully when  
    DBM Tests is not loaded — the dropdown will show "No test data  
    available" instead of throwing an error.  
    Co-authored-by: PGray <PGrayCS@users.noreply.github.com>  
- oh I thought this was pushed. fix world boss loading  
- bump alpha  
