# <DBM Mod> Raids (DF)

## [10.2.4](https://github.com/DeadlyBossMods/DBM-Retail/tree/10.2.4) (2023-11-16)
[Full Changelog](https://github.com/DeadlyBossMods/DBM-Retail/compare/10.2.3...10.2.4) [Previous Releases](https://github.com/DeadlyBossMods/DBM-Retail/releases)

- Bump Classic Era client to 1.15.0 and switch classic era to Spellid parsing instead of spellname. Also prep retail tag  
- further scope spear timer to only start 1 20 second timer before first weapon  
- fix variable name  
- Rework the Igira rework  
    Added more larodar timers  
- update Gnarlroot mythic from public live logs  
-  - Preliminary Igira fixes to at least patch it up more, but need better sample size of data and it's hard with WCLs parses of fight being utterly useless until weapon activations are added to combat log.  
     - Some larodar fixes as well for heroic  
     - Updated both heroic and normal Fyrak timers  
- Remove the deleted alert  
- Council Update  
     - Tank warning is now dynamic, it'll change sound and emphasis when charge needs to be aimed at other boss  
    Fyrak  
     - There is now a taunt warning in stage 1 for swapping boss correctly  
    Gnarlroot  
     - Fixed spam with tank stacks and taunt warning.  
    Smolderonn  
     - Improved tank warning to swap at brand instead of aftermath  
     - Brand now has a red applied and countdown yell indicating it's a soak mechanic  
    Volcoross  
     - Cataclysm jaws now has a smarter taunt warning that has the non tanking tank taunt on cast START so that the tank with minimum Molten Venom takes the hit.  
- Tweak one smolderon timer which was changed on all difficulties  
- Try to fix false debug on council  
    timer adjustment on larodar and nymue based on debug  
- missed a comment dash  
- Completely reworked tindral timers for both normal and heroic. Should be way more accurate now since they are synced up to live and using correct stage trigger now.  
- Gnarlroot  
     - Updated timers on lfr, normal, and heroic  
- Few small updates (lot more to come)  
    Council:  
     - removed spammy polymorph messages  
    Larodar  
     - Fixed lua error  
    Nymue  
     - Remove double message for tanks  
    Smolderon  
     - Fixed missing count in gyser messages  
- Fix larodar timers on normal  
    Fix lua error on council  
    Some hacky half fixes for igira until i get transcriptor logs, since blizzard still hasn't added phase changes to combat log  
- Initial Fyrakk mod update  
- bump alpha  
