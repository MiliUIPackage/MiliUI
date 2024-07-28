# DBM - Core

## [11.0.1](https://github.com/DeadlyBossMods/DeadlyBossMods/tree/11.0.1) (2024-07-27)
[Full Changelog](https://github.com/DeadlyBossMods/DeadlyBossMods/compare/11.0.0...11.0.1) [Previous Releases](https://github.com/DeadlyBossMods/DeadlyBossMods/releases)

- Prep new tag for improved difficulty detection and stats storing for molten core difficulty tiers  
- Tests: support UNIT\_HEALTH and improve target detection  
    Uses UNIT\_SPELLCAST_* transcriptor events to update targets and unit  
    health/power values.  
    This makes health-based phase pre-warnings (e.g., Onyxia) work in tests.  
- Return heat level text in combat messages  
- Try this  
- just disable GetSpellInfo from global checks  
- correctly record wipe modifier in classic era if not inside raid on wipe  
- fix copy paste mistake  
- Add support for molten core heat levels in SoD. Will support showing heat level in pull kill and wipe messages, and boss stats  
- Fix wrath mod message showing on zone in to vanilla onyxia  
    Fix vanilla mod message NOT showing loading into vanilla onyxia  
- cleanup tank code, the way it is is perfect already, just needed a minor antispam to prevent double warnings from appearing.  
- Ulgrax Update:  
     - Improve message clarity on Digestive Venom  
     - Removed swallowing darkness count as it's only cast once  
- fix all dungeons showing key level when they should only show on mythic+  
    changed delve stat storage to "challenge" to make it cleaner to avoid above.  
- Add support for remaining two world bosses  
- Update koKR (#1156)  
- Update localization.ru.lua (#1155)  
- Remove extra pkgmeta  
- bundle dev tools in all versions, not just alphas  
- bump alpha  
