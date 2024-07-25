# DBM - Core

## [11.0.0](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.0.0) (2024-07-23)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/10.2.54...11.0.0) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Prep new DBM core with version bump and Delve tier detection support for statistics.  
- Push delve tier fix  
- Begin work on supporting delve tiers in stats recording and GUI. This way it records highest delves as priority over shortest time, similar to Mythic + behavior  
    Fixed bug where story raid returned "delves" type  
    Queen Ansurek will now store/show story kills in GUI  
- Make sure LuaLS recognizes "self" in all local functions used by mods, to avoid missing any errors (none found, but just good convention to practice now)  
- Add some nil error protection on Rashanan that i missed on normal  
- fix counts in initial timers on each movement  
- another fix  
- Fixes to Rashanan  
- Update koKR (#1151)  
- Fix and close https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1152  
- disable two warnings inconsiquential in LFR. Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1153  
- Redo how timers and phases are handled on Rashanan to be accurate to way it's coded.  
- Fix a bug where tank combo and shroud timer on biurna could fully start new timers on phase 2 start because the previous timer had already expired. Now if previous timer has expired, no replacement timer is created as the abilities remain off CD on stage 2 start (intended behavior)  
    Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1149  
- Update DBM-Raids-WarWithin\_Mainline.toc (#1147)  
- Create localization.tw.lua (#1146)  
- Update koKR (#1145)  
- Update localization.ru.lua (#1144)  
- Update commonlocal.ru.lua (#1143)  
- Core/Timers: add missing timerTypes to options constructor (#1148)  
- Add icontarget yell type that just shows 5 icons (#1142)  
- Make IsTanking object more robust by validating both enemy and player UIDs. Now test I did in video would fail ;)  
    Ironically scanning entirety of DBMs history found 0 occurances that was ever typoed, but now it can't be.  
- Tests: update filters and fix bug when parsing logs with source flags  
- Tests: reconstruct unit targets without boss unit IDs (for classic)  
- Fix and close https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1136  
- Update localization.ru.lua (#1141)  
- Add a common local for an idea i'm thinking about  
- Update koKR (#1140)  
- prune some deprecated stuff and cleanup  
- Special warning objects now have more robust LuaLS checking  
    Fixed a bug on Magmorax where Blazing Breath alert gave no count  
    Fixed a bug on Raszageth where Ball lighting gave no count  
    Fixed a bug on Sennarth where Gossamer burst gave no count  
- scope last  
- Fix DBM not reporting new dungeon in SoD as having dungeon mods available.  
- bump alpha  
- Update localization.ru.lua (#1139)  
