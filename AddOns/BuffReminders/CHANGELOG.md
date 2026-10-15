# BuffReminders

## [v6.8.7](https://github.com/zerbiniandrea/BuffReminders/tree/v6.8.7) (2026-10-14)
[Full Changelog](https://github.com/zerbiniandrea/BuffReminders/compare/v6.8.6...v6.8.7) [Previous Releases](https://github.com/zerbiniandrea/BuffReminders/releases)

### Bug Fixes 🐛

- **Custom-buffs:** check item ownership separately for equipped and bag modes
- **Custom-buffs:** stop saving the icon cache of custom buffs into SavedVariables
- **Glow:** keep built-in glow detection when a custom buff shares its spell ID
- **Loadouts:** report a failed gear equip or talent window open
- **Loadouts:** retry loading Talent Loadout Ex after a failure
- **Pet:** refresh pet summon actions when a loading screen switches the spec
- **Pet:** make pet name labels translatable
- **Profiles:** carry buff sounds, ready-check overrides and custom anchors in profile exports
- Update reminders as soon as delayed spells finish loading
- Stop the settings panel from keeping controls of closed dialogs and rebuilt rows
- Update buff counts as soon as a group member changes spec
- Retry spell icons and names that failed to load at login
- Refresh buff icons after a missed spell texture loads
- Show the saved state on toggles when a dialog opens
- Stop override rows from piling up refresh hooks

### Performance ⚡️

- Read delve state, talents and spell icons from caches

### Other Changes 🔧

- **Display:** free top-level local slots in Display.lua
- Map game events to cache invalidations in one GameContext table
- Move combat, rest, level and vehicle flags into GameContext
- Move ready-check, entry windows and PvP prep into GameContext
- Move glow tracking into GameContext and build its registry after the profile loads
- Move dismount pause into GameContext and hide-all checks into State
- Fix outdated file and event references in code comments
- Remove dead code and pass-through aliases
- Document swallowed errors and reuse shared helpers
- Use one color for the addon's chat prefix

