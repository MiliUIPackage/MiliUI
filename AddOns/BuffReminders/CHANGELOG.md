# BuffReminders

## [v6.5.1](https://github.com/zerbiniandrea/BuffReminders/tree/v6.5.1) (2026-08-15)
[Full Changelog](https://github.com/zerbiniandrea/BuffReminders/compare/v6.5.0...v6.5.1) [Previous Releases](https://github.com/zerbiniandrea/BuffReminders/releases)

### New Features ✨

- **Consumables:** track the CN-exclusive Tidesworn Augment Rune
- **Consumables:** track the new 12.1 foods and feasts
- **Externals:** track Guardian of the Forgotten Queen
- **Layout:** tabbed Layout page with a custom anchor frame editor

### Bug Fixes 🐛

- **Externals:** avoid Blizzard's bug showing random buffs after cinematics
- Stop huge reminder text on first login after a client start
- Retry setting font when the client silently ignores SetFont
- Keep reminder fonts correct after login, reload and font changes

### Performance ⚡️

- **Events:** stop listening to group aura events in combat and solo
- **Events:** make group buff updates use the fast refresh path again
- **Events:** avoid constant polling out of combat, refresh on schedule instead

### Localization 🌐

- Updated translations: zhCN, zhTW

### Other Changes 🔧

- Move display font handling into Display/FontCache.lua
- Size reminder text with real font sizes, not text scale

