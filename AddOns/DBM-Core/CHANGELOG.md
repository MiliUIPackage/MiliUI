# DBM - Core

## [11.1.11](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.1.11) (2025-03-21)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.1.10...11.1.11) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Tag new release for wrath client compat updates  
- one armed bandit update:  
     - Added emphasized alerts for picking up coins with specialized TTS  
     - Added emphasized "run to edge" tank alert to make it clearer where to drop zone.  
     - Micro timer adjustments  
- Mugzee Update:  
    Fixed bug where gaol yell didn't use red color that's usually used for group soak mechanics.  
    Fixed bug where several of timers had incorrect values, especially on heroic.  
- Bump Wrath TOC  
    Remove old wrath client compat checks and assume that it's using modern functions now based on initial reports. kinda hard to verify though since wrath client is region specific.  
- Updated spec info to work with wrath client update in China  
    Updated profiles to actually check right arg for talent points, which has been broken in vanilla since the beginning of SoD. Now DBM should correctly load profile related to actual talent point choices instead of being broken.  
- increase cast times for rolling rubbish and recycle on mythic stix  
- Revert last, that doesn't fix problem  
    Fix it at mod level for now  
- Fix setstage so it doesn't break if using incrementor right on engage.  
- Fix a bug causing bad initials stage numbers  
- adjust stix icons used to remove compat issues  
- bump alpha  
