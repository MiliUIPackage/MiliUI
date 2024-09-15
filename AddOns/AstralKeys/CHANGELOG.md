# Astral Keys

## [4.14](https://github.com/astralguild/AstralKeys/tree/4.14) (2024-09-12)
[Full Changelog](https://github.com/astralguild/AstralKeys/compare/4.13...4.14) [Previous Releases](https://github.com/astralguild/AstralKeys/releases)

- Update AstralKeys.toc  
- Revert unwanted commit to Lists/Guild.lua  
- Speculative fix for https://github.com/astralguild/AstralKeys/issues/122  
    Delay the call to load Blizzard\_WeeklyRewards until the Great Vault button is actually pressed. I think calling it too early now messes up interface.  
