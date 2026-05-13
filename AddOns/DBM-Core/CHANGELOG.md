# DBM - Core

## [12.0.47](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.47) (2026-05-13)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.46...12.0.47) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- couple minor fixes before that tag  
- Prep new tag with fixes for unicode issues and additional protections against breaking from 3rd party addons  
- De-unicode file names to resolve issues with curseforge and onedrive (#2061)  
    * De-unicode file names to resolve issues with curseforge and onedrive  
- disalbe instanceinfo debug for now. it was mostly used for DBM offline, which has been dead for months.  
    While at it, micro optimize difficulty checks to not spam during raid formation and instead only update player count after 3.5 seconds of idle.  
- Added more robust validation against values that have a "none" value to now accept any case variation of it, especially with 3rd party mods modifying DBM settings and using a case variation DBM was NOT utilizing  
    Added more robust font checks that now more strictly validate font sizes and styles in SetFont and not just the font itself, since 3rd party actors can send up actually setting in valid settings such as a string for a font size instead of a number or a case mismatched style.  
- improve gear comm robustness for guild  
- handle class coloring in guild gear check  
- bump alpha  
