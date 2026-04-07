# Premade Groups Filter

## [7.3.3](https://github.com/0xbs/premade-groups-filter/tree/7.3.3) (2026-04-06)
[Full Changelog](https://github.com/0xbs/premade-groups-filter/compare/7.2.0...7.3.3) [Previous Releases](https://github.com/0xbs/premade-groups-filter/releases)

- Remove restriction overlay for now  
- Fix classic/MoP edition  
- Allow compactListEntries even while restricted  
- Adjust warnings in options  
- Remove tooltip from PR  
- Rename i18n keys  
- Automatically reload when compactListEntries is changed  
- Replace reload popup with a chat message which is not as annoying  
- Merge pull request #370 from Agithos/playStyle-fix  
    Fix playstyle search expressions  
- Merge pull request #371 from mdepolli/fix/add-isle-of-queldanas-delve-zone  
    Add Isle of Quel'Danas to delve zone maps for bountiful detection  
- Add Isle of Quel'Danas to delve zone maps for bountiful detection  
    Parhelion Plaza was not being detected as bountiful because its  
    zone map (2424, Isle of Quel'Danas) was missing from DELVE\_ZONE\_MAPS.  
- Fix playstyle search expressions  
- Add warnings for settings that taint  
- Enable or disable compact list entries only after a reload (still missing player message)  
- Add AGENTS.md  
- Cleanup architecture  
- Redesign persist sign up note and prevent feature from tainting while restricted.  
- Improve text of reload popup  
- Hide reload popup when restrictions are no longer active  
- Make reload popup moveable  
- Improve reasoning in reload popup  
- Fix check  
- Check if taint is from PGF  
- Check for more taints  
- Do not show overlay if just combat restriction is active  
- Add a popup that tells to reload if tainted and player joined a raid  
- Remove pointless setter  
- Add taint warning to 'Persist sign up note' option and disable it by default  
- Copy results of C\_LFGList functions returning a table to avoid tainting (see #365)  
- Make restriction overlay dependent on restriction API  
- Fix unknown event in non-retail version (fixes #367)  
- Fix overlay not reacting on state change  
- Automatically react on restriction changes  
- Improve overlay warning  
- Improve overlay  
- Fix error and prevent possible tainting when disabled  
- Improve warning in settings dialog  
- Fix unintended global  
- Remove unused functions  
- Show overlay only on retail  
- Add an overlay that warns before using PGF in a restricted env  
- Add a warning to the signUpDeclined option that it can cause Lua errors  
- Fix two potential taint sources  
