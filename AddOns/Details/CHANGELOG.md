# Details! Damage Meter

## [Details.20240519.12755.156](https://github.com/Tercioo/Details-Damage-Meter/tree/Details.20240519.12755.156) (2024-05-19)
[Full Changelog](https://github.com/Tercioo/Details-Damage-Meter/compare/Details.20240508.12717.156...Details.20240519.12755.156) 

- Change Logs  
- Added rallied to victory to track when this buff is placed on someone.  
- Stop resetting tooltip color each login  
- Avoid the options panel going out of screen with SetClampedToScreen()  
- Fix for the old time type '3' being deprecated and causing errors for returning players  
- backend changes  
- Added season setting to ignore the bookmark  
    /run Details.no\_bookmark = true: won't open the bookmark.  
    /run Details.no\_bookmark\_on\_combat = true: won't open the bookmark while in combat.  
- Merge pull request #729 from Flamanis/Add-all-totem-damages  
    Add all damage from All-Totem of the Master.  
- Update spellcache.lua  
- Update spellcache.lua  
- Merge pull request #728 from Flamanis/update-era-toc  
    Update Details\_Classic.toc  
- Update Details\_Classic.toc  
- Fix for death recap  
- framework updates  
- Transliterate pet names on damage tooltip  
