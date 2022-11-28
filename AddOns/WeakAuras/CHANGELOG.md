# [5.2.1](https://github.com/WeakAuras/WeakAuras2/tree/5.2.1) (2022-11-26)

[Full Changelog](https://github.com/WeakAuras/WeakAuras2/compare/5.2.0...5.2.1)

## Highlights

 - Dynamic Groups: Introduce options for aura order for centered
- Bug fixes 

## Commits

InfusOnWoW (20):

- Fix lua error if there's no tooltip
- Fix background framelevel setting for AuraBar
- Cooldown Tracking: Don't react within 2s of PLAYER_ENTERING_WORLD
- Add an additional sanity check to custom duration return values
- Improve error message if color animations return odd values
- Fix Exact Spell ID for Charges Changed
- Bump version
- Correct LibUiDropDownMenu name in OptionalDeps
- Use LibUIDropDownMenu for UIDropDownMenus
- Add Evoker to CalculateGCDDuration
- Disable snapping to pixel grids for Ticks too
- Texture/Progress Texture: Improve atlas compatibility
- Use C_TooltipInfo instead of a hidden tooltip on DF
- Icon: Add some helpful text to Icon that hints at other addons
- Dynamic Groups: Introduce options for aura order for centered
- Make lua checkers a bit happier
- AuraBar: Ensure that Scale does always call Reorient
- Bug report template: Ask for verifyable steps in the Reproduction Steps
- Don't try to reanachor frames that are dragged into a dynamic group
- Forward arguments of PLAYER_ENTERING_WORLD to WA_DELAYERD_PEW

Lars Kunert (1):

- Update "Talent Known" trigger on spec changes

Stanzilla (4):

- Lua LSP: Add more globals to the list
- Lua LSP: Disable the checks that currently cause the LSP to crash
- Add a Lua LSP config file and update some types
- Ignore WeakAurasModelPaths and Type* files for Code Spell Checker

mrbuds (4):

- Cast trigger: fix empowered cache for target on target change
- Talent load condition: fix talents for overriden spells
- Update talents
- Aura trigger: fix tooltip filters

