# [5.2.0](https://github.com/WeakAuras/WeakAuras2/tree/5.2.0) (2022-11-15)

[Full Changelog](https://github.com/WeakAuras/WeakAuras2/compare/5.1.1...5.2.0)

## Highlights

 - Replace Sliders in options with new SpinBox widget
- Add Blizzard Atlas textures to the picker
- Bug Fixes 

## Commits

InfusOnWoW (5):

- Add some nil check for Private.regions[id].region
- Fix diff algorithm to correctly allow for ignoring nested values
- Options: Make dragEnd run the trigger functions again
- Fix Conditions with paused states
- Make IsSpellKnown* checks check the base spell more correctly

Jesse Manelius (1):

- Use SetClampedToScreen on title instead of using complicated code

Stanzilla (1):

- Bump retail TOC for Patch 10.0.2

Tharre (2):

- Crowd Controlled: enable for classic era
- Spell Cooldown: enable LOC option for classic

mrbuds (5):

- Texture picker: keep aspect ratio for atlas in preview
- fix broken zoom on icons
- Texture Picker: add "Blizzard Atlas" category with all atlas (#3966)
- Add "blizzard alert" textures for evoker
- SpinBox Widget (#3981)

