# DBM - Core

## [11.0.6](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.0.6) (2024-09-10)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.0.5...11.0.6) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep new tag  
- Update koKR (#1226)  
- Update localization.ru.lua (#1225)  
- Update localization.tw.lua (#1224)  
- Fixed bug where test bars didn't show glow in demo mode due to demo mode version of aura table not including that arg.  
    Fixed bug with glow check where it basically never actually check the values of cast glow options at all.  
- Only call glow cancel if it's a glowing nameplate icon, avoids unneeded calls to for clearing auras that aren't glowing. This bug was mixed cause my personal setting has ALL glowing when I was testing. This fixes nil error spam  
    Also add extra protection against nil errors for good measure in actual glow stop function by verifying frame exists first.  
    Closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1228 and closes https://github.com/DeadlyBossMods/DeadlyBossMods/issues/1227  
- oops fix nil error  
- fix a bug where glows could get stuck in a glow state  
- Fix nil error  
- additional glow options  
- Update koKR (#1223)  
- Push new UI option to split private auras if users want  
- Add full General ANgerforge drycode to BRD Raid  
- Mark DBM as compatible/up to date on 11.0.5 PTR  
    Correct stats on BRD Raid module  
    Don't load BRD Raid Modules on live  
- fix bad option key  
- Push finished Seven mod for BRD raid  
- Update localization.cn.lua (#1221)  
- Push first 3 bosses of Blackrock Depths raid aniversery event  
- Push preliminary Blackrock Raid mod stubs  
- Push some preliminarly 11.0.5 stuff  
- Update localization.ru.lua (#1220)  
- update voice pack sounds  
- Bump nameplate max len slider from 25 -> 40  
- add fallback cleanup  
- Update localization.tw.lua (#1219)  
- Update koKR (#1218)  
- Imliment proc glow support  
- text tweak  
- massively improve layout code for nameplate panel  
    fixed some bugs  
- fix error in last luaLS missed  
- rework glow options to be a separate section with even more options  
    clarify english namplate disables to be a lot clearer and expanded them to include cast types  
- Update localization.fr.lua (#1216)  
    * Update localization.fr.lua  
    * Update localization.fr.lua  
- bump alpha  
