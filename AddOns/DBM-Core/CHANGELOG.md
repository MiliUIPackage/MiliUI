# DBM - Core

## [12.0.45](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.45) (2026-05-08)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.44...12.0.45) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- prep new tag  
- fix wipe messages saying kill on midnight for guild group comm messages, a regression from fixing same bug on tbc.  
- Update translations (#2057)  
- prioritize comms over inspect for gearcheck, allowing more precise ilvls for all units and bypassing inspect throttles. inspect will be used as backup for people who don't reply to comms (such as users not running DBM)  
- allow pull/break count threshold to live update without requiring reload anymore  
- Allow built in countdowns to go to 10 for hardcoded objects like pull timers and hardcoded modules. the 5 second cap only needs to apply for blizz api timeline objects  
- update mythic check to auto pass as heroic if game version is Mists of pandaria classic. This allows modern siege of org mods to be cleanly backwards compatible  
- actually handle it this way instead, since i think the announce needs to inherit the newID  
- it's cleaner to ignore the 2 second breath timers on chimaerus since it's just blizzard resending the remaining time on previous 12  
- Update koKR (#2055)  
- tweak  
- science something  
- change luacheck  
- Add rotmire mod  
- fix lua error on UI reload in M+  
- fix small timer bug  
- Update localization.de.lua (#2047)  
- Update localization.de.lua (#2048)  
- Update localization.fr.lua (#2053)  
- Update localization.es.lua (#2052)  
- Update localization.br.lua (#2051)  
- Update localization.ru.lua (#2050)  
- Update localization.tw.lua (#2049)  
- Update koKR (#2046)  
- Update localization.fr.lua (#2045)  
- Update localization.es.lua (#2044)  
- Update localization.br.lua (#2043)  
- Add new countdown voices for every language (#2026)  
- Add flex mythic raid difficulty  
    Update Beloren ahead of next weeks tuning hotfixes  
- update language  
- Don't hide spell keys from UI on retail anymore. they're actually useful to MRT and weakauras forks that still use DBM callbacks  
- fix variable conflict in last  
- if on patch 12.0.7  
     - Once again report wipe HP on boss wipes using new blizzard api  
     - Support mid state bar color changes when using blizz api (actual configuration for it not done yet)  
- bump alpha  
