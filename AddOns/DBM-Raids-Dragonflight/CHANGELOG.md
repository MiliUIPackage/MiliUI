# <DBM Mod> Raids (DF)

## [10.2.19](https://github.com/DeadlyBossMods/DBM-Retail/tree/10.2.19) (2024-01-24)
[Full Changelog](https://github.com/DeadlyBossMods/DBM-Retail/compare/10.2.18...10.2.19) [Previous Releases](https://github.com/DeadlyBossMods/DBM-Retail/releases)

- bump the version check before tag  
- fix some of lua in last  
- Update localization.ru.lua (#391)  
- begin work on a work in progress CC checking api function. My class knowledge is limited so hopefully I can get more feedback besides MANUALLY browsing every class ability in game (several thousand). this work so far took about 2 hours. Druids alone had 500 spells to manually check  
- Update koKR (#394)  
- Update localization.tw.lua (#393)  
- Update localization.br.lua (#392)  
- clarify and update some option text a bit  
- Fix DoesAddOnExist cache for WotLK (#390)  
- Update commonlocal.ru.lua (#389)  
- always check current dungeons in classic for good measure on missing dungeon mods  
- Add spell key note to Larodar to clarify why there are two different Coalescence keys  
- Merge branch 'master' of https://github.com/DeadlyBossMods/DBM-Retail  
- option layout tweak  
- Update commonlocal.es.lua (#387)  
- Update commonlocal.es.lua (#386)  
- Update commonlocal.es.lua (#385)  
- Locale tweaks; - Fix common commonlocale (es, ru, tw) - Support optional in localizations.  
- Update koKR (#378)  
- Update localization.ru.lua (#384)  
- update text for FilterTrashWarnings to signify follower dungeons are included in that filter  
- Update localization.ru.lua (#383)  
- Fix minor math error  
- tweak initial timers  
- Remove unused  
- Aurostor Update:  
     - Added cranky tantrum counter  
     - Changed recombat time from 20 to 30 to avoid false engages that could occur  
    -Council of Dreams Update:  
     - Special warning for Barreling charge now always shows, instead of only if you have debuff  
     - In addition, special warning for barreling charge will now announce which soak group it is via spoken alerts (ie "group 1 share", "group 2 share") if you do not have debuff. It'll continue to say "charge move" if you do.  
     - Song of the Dragon "take damage" alert will now wait until absorb effect is up instead of saying it immediately on song being cast, so it's not telling you to take damage too early  
     - In addition, Song of the Dragon take damage alert will repeat a 2nd time if you have not yet cleared the full absorb after 6 seconds.  
     - Then finally, a new alert will show that song of the dragon has successfully faded.  
     - GTFO warning will no longer alert you are afflicted with song of the dragon absorb  
- rename roar from pushback to, well, roar. It's the more consistent call for the spell  
- bump alpha  
