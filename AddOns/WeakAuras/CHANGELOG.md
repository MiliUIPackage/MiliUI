# [5.17.3](https://github.com/WeakAuras/WeakAuras2/tree/5.17.3) (2024-10-22)

[Full Changelog](https://github.com/WeakAuras/WeakAuras2/compare/5.17.2...5.17.3)

## Highlights

- 🚨 🚨 🚨 Custom Triggers which listen to COMBAT_LOG_EVENT_UNFILTERED without..ahem..*filtering* now generate a deprecation warning, and will cease functioning in a future update
- WeakAurasTemplates: Updated for 11.0.5. If we missed any, or got anything wrong, please let us know!
- Rogue: Charged Combo Points no longer have any special interpretation in Player/Unit Info - Power - Combo Points trigger. The associated overlay should continue to work as expected.
- WeakAurasArchive should be more conservative about when it loads, in the hopes of improving resiliency against SavedVariables loss

## Commits

Boneshock (1):

- Add chat command for WA profiling window

InfusOnWoW (10):

- Charged ComboPoints: Update trigger to new design
- Fix Lua error on new Weapon Type trigger
- Templates 10.0.5 update
- Stagger: Workaround UNIT_ABSORB_AMOUNT_CHANGED not firing for the last tick
- Druid Templates: Add Apex Predator buff and overlayglow
- Discord Updater: Allow Cyrillic in names
- Combo Points: Remove treat charged as seven feature
- Update Discord List
- Deprecate unfiltered CLEU events
- DG: Fix Centered Grow if 0 auras are visible

Stanzilla (2):

- Update WeakAurasModelPaths from wago.tools
- fix(ci): downgrade github workflows that depend on svn to the ubuntu-22.04 image

emptyrivers (4):

- delete a couple nits in the geberated changelog
- bump toc
- fix archive clean schedule
- finally remove LibDeflate hard commit

mrbuds (2):

- BuffTrigger2 Multi Handler: make profiling more granular
- Power Trigger: fix max combo points on Cataclysm

