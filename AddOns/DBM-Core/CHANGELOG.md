# DBM - Core

## [12.0.51](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/12.0.51) (2026-05-23)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/12.0.50...12.0.51) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Prep new tag with updated forced version since it's a mandatory update for module compat  
- Add voiceFile path to all specialwaring constructors  
- Fix legacy module still using a bool value  
- Backport the good changes from special warning refactor:  
     - Objects can now define voiceFile for playback when using test button in GUI  
     - Cleaned up redundant backwards compact code from years ago for runSound and hasVoice where they were still booleans  
     - Removed all handholding remapping code. No one really used this feature and it bloated up objects and GUI with UI option bloat.  
- Update localization.cn.lua (#2097)  
- Update localization.ru.lua (#2095)  
- Update translations (#2096)  
- LuaLS: Annotate magic localization tables as table<string, string> (#2099)  
- Fix GTFO special grouping and test button  
- Reduce test duration for rename tests from 10 seconds to 5 seconds  
    Fixed bug where clearing renames didn't clear cached renames on certain timer objects and certain special warning objects  
- Add Infoframe Strata Option (#2094)  
- Update koKR (#2092)  
- Update translations (#2091)  
- Rename Update (#2093)  
    * Allow users to actually clear a rename for abilities that have default renames.  
- Also work around another bug where blizzard over cancels bars and prevents Entropic Untraveling from ever actually having a cooldown bar after the first one. Sorry it took me like 11 weeks to notice blizzards bug here. As a tank i'm often focused on orbs and not bars. I also still give blizzard too much benefit of the doubt I guess when it comes to avoiding such ridiculous bugs.  
- Work around blizzard bug where they resend existing timers for no reason, with a stage of 3 (canceled).  
    Should resolve Shalhadaar hardcode having a chance to fail and revert to blizz api module.  
- Update translation (#2090)  
- give voice packs ability to specify nunber of counts available. espeically for niche cases like VEM (which actually is only voice pack that goes to 11)  
- tweak  
- Improve last with more deliberate and accurate checking  
- Fix some issues causing voice pack counts not to fully register all of their counts. of course this will generate lua errors with any voice packs taht don't actually support all 10 but those errors wll be redirected to those authors  
- Update koKR (#2089)  
- update translations (#2088)  
- Update localization.ru.lua (#2086)  
- GUI Optimizations (#2087)  
- Adjust default size again (lower) due to some users using windows 150 rescale and it making addon windows obnoxiously ignore pixel sizes.  
    Make 1000 pixels min width to avoid layout issues with new option layouts  
    Fixed search so it can once again find spells using their ORIGINAL names for abilities that have been renamed. This also means original names appear on ability titles again (along with rename and ability ID if enabled)  
- Update translation (#2084)  
- Update RU locales (#2085)  
- Hacky way to make GTFO generic alerts renamable  
- param update  
- Allow DBM to enhance blizzard timeline bar colors even if DBM bars are visible (#2083)  
     - Old behavior. If a user had both dbm bars and timeline bars enabled (not sure why but I see it a lot). DBM wouldn't recolor timeline bars. DBM only did this if DBM were were explicitely turned off  
     - New behavior. DBM will always enhance timeline bar colors using DBM settings (unless user explicitely disables this in DBM feature disables section)  
    Countdowns are handled the same as before. If using DBM bars, countdowns are handled through DBM bars object, but if DBM bars are disabled, countdowns are registered to blizzard bar object (with limitation that it can only be a 5 count or 3 count)  
- bump alpha  
