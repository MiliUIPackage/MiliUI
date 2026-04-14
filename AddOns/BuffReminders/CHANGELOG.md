# BuffReminders

## [v5.3.0](https://github.com/zerbiniandrea/BuffReminders/tree/v5.3.0) (2026-04-12)
[Full Changelog](https://github.com/zerbiniandrea/BuffReminders/compare/v5.2.1...v5.3.0) [Previous Releases](https://github.com/zerbiniandrea/BuffReminders/releases)

- fix: 🐛 gate wrong pet warning on Felguard known and default summon to Felhunter  
- fix: 🐛 dismiss soulwell reminder on cast start to prevent GCD flicker  
- feat: ✨ add customizable chat request messages  
- refactor: 🚚 rename CombatSafeSpells to AuraWhitelist for clarity  
- fix: 🐛 disable click-to-cast on Burning Rush and use AnyDown for secure buttons  
- fix: 🐛 defer spell texture cache to fix warlock green fire on login  
- i18n: 🌐 update zhTW localization  
- perf: ⚡️ cache session-constant values and optimize unit cache pruning  
- fix: 🐛 rebuild chat request macro in PreClick to track group type changes  
- fix: 🐛 use macro instead of SendChatMessage for chat requests to avoid taint  
- feat: ✨ show chat message when dismissing consumable reminders  
- feat: ✨ add click-to-request missing buffs in chat  
- feat: ✨ add option to hide Blessing of the Bronze in combat  
- i18n: 🌐 update zhTW localization  
- fix: 🐛 suppress targeted buff reminder when all beneficiaries are dead  
- style: 💄 reorder hide-when checkboxes by logical grouping  
