# Deadly Boss Mods Core

## [8.3.25](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/8.3.25) (2020-06-05)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/8.3.24...8.3.25)

- Fixed missed line  
- Cleanup unused locales  
- Update KR (#244)  
    * KR Update  
- Apply custom stripping to custom ra-den frame  
- Fix typo  
- Fixed bugs in GetShortServerName function and eliminated redundant option checks by moving the option check directly into GetShortServerName function  
- Fixed inconsistency across infoframes that weren't using realm name when they should  
    Changed way realm name is stripped to still have indicator that it is a different realm player.  
- Revert "Revert "Apply strip name option to rangecheck and infoframe as well""  
- Revert "Apply strip name option to rangecheck and infoframe as well"  
- Apply strip name option to rangecheck and infoframe as well  
- Per user request, added Vicious Mauling warning to Jes Howlis encounter  
- Fixed yell text regression on Nzoth and Council of Blood. I changed wrong thing. Yells now have new OPTION text, not new yell text  
- Fixed reverse logic bug, and fixed a bug where tables wouldn't get wiped while text was disabled  
- That's about as much patience I have for syncing other locales  
- Update KR (#243)  
    * KR Update  
- fix  
- Updated special warning global disble options to allow greater control over what parts of special warning object is disabled. It is now possible to disable only text alerts, only sound alerts, or only flash alerts, or any combination of them. Technically some of this was possible before through various options in other place but it made sense to make sure the global options presented it better.  if you want to disable special warnings completely, you just disable all 3.  
- add back issue templates  
- fix issue templates  
- Removed a disable/filter option that's obsolete since 1.13.3, nameplate lines are dead.  
    Added new disable/filter categories to help users find what they desire more quickly  
- Classic sync (#241)  
    * Classic sync  
    * Derp  
- Add a classic link in new issues (Myst requested) (#240)  
    * Add a classic link in new issues (Myst requested)  
    * Make link point to creating a new issue  
- Last of the GUI problems (#239)  
    Fix option spacer  
    Fixed points for dynamic resizing becoming too wide  
    Added max resize  
    Made editboxes prettier, and saved 3 frames per (memory improvements ftw)  
- Rename one dungeon boss that was renamed  
- Fix error  
- Create auto localized options for icon and playername yell repeaters  
    Began construction of a :Repeat() function within yell prototype so the repeater code doesn't have to be duplicated in every mod. This needs review so it's not yet deployed  
- Comment out SpellTimers while its currently disbled. (#235)  
    * Comment out SpellTimers while its currently disbled.  
    * Comment them at the end to prevent breaking list  
- Attempt to fix long standing bug with jaina where nameplate icons still don't get removed, since calling without spellId still bugs out with some nameplate addons that don't have properly implimented "remove all if no texture/ID given"  
- Properly fix wings mod  
- Update KR (#234)  
    * KR Update  
- Patch2 (#233)  
    * Fix spacing between checkboxes on resize.  
    * Found the underlying issue >.>  
    If its resized once, it doesn't like doing it a 2nd time due to our previous "SetPoint" hack  
    * A lot of the options overhauled.  
    * Don't run auto resize on stats, as that code is FAR too complex to math  
    * Fix mod options having incorrect height assigned  
    * Remove debug print code  
    * Add update for sizes on drag in General Options  
    * Remove unused variable  
    * Might as well remove redundant initialization in core too  
    * And fix unused in other stuff too  
    * Even more unused variables cleanup  
    * Luacheck entry is provided by *  
    * Don't whitelist all DBM globals, since there's a lot less of them now. (Also fix build)  
    * Fixes  
    * Dropdowns now move according to editboxes above them.  
    * Fix size options not updating properly  
- Update zhTW (#232)  
- Update zhTW (#231)  
- Patch2 (#230)  
    * Fix spacing between checkboxes on resize.  
    * Found the underlying issue >.>  
    If its resized once, it doesn't like doing it a 2nd time due to our previous "SetPoint" hack  
- Fix spacing between checkboxes on resize. (#229)  
- Fixed a bug that could cause event sounds to throw errors if User has no media installed and selects "Random" option  
- Update zhTW (#226)  
- CPU Improvements (#225)  
    Fix stats panel having extra space at the bottom  
    Checkboxes now resize properly  
    CPU/memory improvements by localising global functions and variables  
    Added editbox for GUI width and height for pixel perfectionists  
    Fixed capitsalisation in a dropdown menu's entries  
    Checkboxes have better positioning.  
- Revert "Patch1 (#224)"  
- Patch1 (#224)  
    * Prevent editbox autofocus by default  
    * GUI Fixes  
- Fixed bug where neck tracking didn't work correctly on non mythic difficulty  
- Fix last  
- Fix hide dead logic, and make it on by default  
- KR Update (#218)  
    * KR Update  
- Prevent dead players from appearing on the sanity table. (#219)  
    Added option to hide dead players from infoframe on non mythic difficulties of nzoth.  
- Updated messaging that SpellTimers and RaidLeadTools are no more and have to be uninstalled.  
- And for absolute certainty, add this too  
- Fix spellTimers version check, for alpha versions of spelltimers that add the git hash  
- Set alpha version  
- Prevent editbox autofocus by default (#217)  
