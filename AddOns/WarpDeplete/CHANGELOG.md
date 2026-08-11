# WarpDeplete

## [v5.4.2](https://github.com/happenslol/WarpDeplete/tree/v5.4.2) (2026-06-22)
[Full Changelog](https://github.com/happenslol/WarpDeplete/commits/v5.4.2) [Previous Releases](https://github.com/happenslol/WarpDeplete/releases)

- chore: Bump version  
- fix: Avoid comparing secret value UnitHealth (#156)  
    UnitHealth can be secret, which causes a lua error. Previously, feign death caused UnitIsDead to return 'true', but this seems to no longer be the case.  
- chore: Bump version  
- chore: Update ruRU.lua (#155)  
- chore: Bump version  
- feat: Add bar backdrop customization and slug font option (#154)  
    * Add OUTLINE SLUG  
    * add Backdrop Colour Options  
    * Rename `OUTLINE SLUG` to `OUTLINE, SLUG`  
- chore: Update ruRU.lua (#153)  
- chore: Bump version  
- feat: Add UI option to clear recorded splits per dungeon and level (#152)  
    * feat: add UI option to clear recorded splits per dungeon and level  
    - Added a new 'Clear Splits' section in the Options menu (under the Splits tab).  
    - Added a dropdown to select a specific dungeon, dynamically populated from the database.  
    - Added a secondary dropdown to select a specific keystone level or 'All Levels' for the chosen dungeon.  
    - Implemented deletion logic to accurately clean up `WarpDeplete.db.global.splits` based on the selected map ID and level.  
    - Added a confirmation prompt to prevent accidental data loss.  
    * Updated locales  
    - Updated English and French localization files (`enUS.lua`, `frFR.lua`) with new UI strings.  
    * Allow deleting specific key level across all dungeons  
- chore: Update ruRU.lua (#151)  
- chore: update French translations (#150)  
- chore: Bump version  
- feat: Add fallback split levels and permanent split visibility (#147)  
    * Add split fallback and always show option  
    * Add split fallback and always show option  
    * add closest proximity fallback behaviors and optimize loop logic  
    * Translated in french  
    * Removed translations for PR  
    * Correction Mise en page windows  
    * Correction Problemes espaces  
    * Doubles espaces  
    * Refine split records UI and visibility settings  
    * added translations  
    * removed icon and brackets  
    * Added missing translations  
    * fix: fallback split diffs not displaying during runs  
    * fix: display fallback source key level on split references  
    * added comments to split fallback logic  
    * Removed french translations  
    * Removed badges  
    Removed all mentions of the badges system for the splits, since they added too much complexity and not so much gain   
    Went back to the older method  
    Kept color picker for splits  
    * Moved splits color picker  
    - Moved splits color picker from Display to General  
    - Renamed "Split Reference Color" to "Split Records Color"  
    - And changed "splitReferenceColor" key to "splitRecordsColor"  
    * Added missing translations  
- chore: Bump version  
- feat: Show forces count in tooltips for midnight (#149)  
    Adds back the forces count as a fixed string in mob tooltips. Custom formatting is removed for now, since it would involve wrangling with secret values which is very error-prone.  
- chore: Bump version  
- fix: Add missing fonts and textures  
- chore: Bump version  
- fix: Check for secret values in UNIT\_DIED event (#141)  
- chore: Bump version  
