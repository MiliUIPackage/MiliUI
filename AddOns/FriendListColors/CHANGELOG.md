# FriendListColors

## [v9.0.1.201018](https://github.com/Vladinator89/wow-addon-friendlistcolors/tree/v9.0.1.201018) (2020-10-18)
[Full Changelog](https://github.com/Vladinator89/wow-addon-friendlistcolors/compare/v9.0.0.201004b...v9.0.1.201018) [Previous Releases](https://github.com/Vladinator89/wow-addon-friendlistcolors/releases)

- Forgot to bump the version before releasing this update.  
- - Adjusted some of the friends data for SL so we shouldn't show the wrong information at the wrong places anymore.  
    - Added inverse logic blocks like `[if~=noteText]Person has no note text[/if]` and the contents would only show if `noteText` tag was empty.  
    - Added the tag `battleTagName` that only shows the first part of the battle tag so "Ola#1234" becomes "Ola".  
    - Added limited support for `race` for your character friends, it's not originally a variable from the API, but figured I could try add it in case someone was missing that information.  
- Correct TOC bump for SL pre-patch.  
