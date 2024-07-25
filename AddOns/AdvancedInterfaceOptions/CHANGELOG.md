# Advanced Interface Options

## [1.9.0-3-gc90c107](https://github.com/Stanzilla/AdvancedInterfaceOptions/tree/c90c107b16d79dbafb031a95a087cb287e77c915) (2024-06-11)
[Full Changelog](https://github.com/Stanzilla/AdvancedInterfaceOptions/compare/1.9.0...c90c107b16d79dbafb031a95a087cb287e77c915) [Previous Releases](https://github.com/Stanzilla/AdvancedInterfaceOptions/releases)

- Add TWW TOC  
- Switch to new Settings API  
- Fix CvarUtil pattern matching  
    Seems like all the different clients have slightly different SharedXML/CvarUtil now.  
    This should catch anything SharedXML/CvarUtil.lua or SharedXML/ClassicCvarUtil.lua (SoD)  
    or Blizzard\_SharedXML/CvarUtil.lua  (Cata Classic) now.  
    Fixes #80  
