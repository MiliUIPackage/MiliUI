# [5.4.4](https://github.com/WeakAuras/WeakAuras2/tree/5.4.4) (2023-03-29)

[Full Changelog](https://github.com/WeakAuras/WeakAuras2/compare/5.4.3...5.4.4)

## Highlights

 - Bug fixes 

## Commits

InfusOnWoW (5):

- Bufftrigger2: Explicitly scan boss units on INSTANCE_ENCOUNTER_ENGAGE_UNIT
- Fix state.spec for various triggers
- BuffTrigger2: Check that matchDataByTrigger contains what we expect
- Fix updating edge case
- Templates: Fix Rupture

mrbuds (7):

- Spell Cast Succeeded trigger: fix "Delay" option, fixes #4382
- update talents for 10.0.7
- Dbm & BW triggers: make count field use cron-like pattern fixes #4368
- Aura trigger: fix tooltip on mouseover, fixes #4372
- Dbm & BW triggers: fix count parsing from message
- Aura trigger: Fix Lua error in WeakAuras.GetAuraInstanceTooltipInfo for 10.1.0
- re-add WeakAuras.IsClassic as an alias to WeakAuras.IsClassicEra

