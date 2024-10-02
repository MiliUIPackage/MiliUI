# DBM - Core

## [11.0.19](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.0.19) (2024-09-28)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.0.17...11.0.19) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Update koKR (#1286)  
- make luacheck happy  
- Core Update:  
     - Fix lua errors with GetSpellCooldown on Classic era  
    Silken Court Update:  
     - Support longer LFR Silken Court pulls  
    Ansurek Update:  
     - Added gloom touch fades countodwn  
     - Abyssial infusion will now give cast count in target announce  
     - Abyssial Infusion Icons will now prioritize melee > ranged  
     - Better staging for platforms  
     - Fixed some false debug. Fixes and closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1285  
- Update commonlocal.es.lua  
- Update commonlocal.es.lua  
- Update commonlocal.fr.lua  
- Update commonlocal.br.lua  
- CI: Fix LuaCheck  
- Tests: Ignore encounters that lasted for less than a second  
    Vaelastrasz triggers ENCOUNTER\_START/END for every single raid member  
- Tests: Support BWL trials  
- Core: Map BWL Trials to Heroic/Mythic  
    The mapping is the same as Warcraft Logs uses: Mythic is 3+ including Black, 3-4 without black is Heroic, 1-2 with black is also Heroic  
- GUI: Add polyfill for missing slider template  
- Fixed infoframe not tracking shield percent for 2nd intermission on court  
    Fixed rare lua error  
- bump alpha  
