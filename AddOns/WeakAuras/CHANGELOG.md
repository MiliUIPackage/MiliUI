# [5.8.4](https://github.com/WeakAuras/WeakAuras2/tree/5.8.4) (2023-11-07)

[Full Changelog](https://github.com/WeakAuras/WeakAuras2/compare/5.8.3...5.8.4)

## Highlights

 - Template updates for 10.2.0
- More options for Buff Triggers
- Improvements to profiling UI
- Bug fixes 

## Commits

InfusOnWoW (8):

- Template updates for 10.2
- Dynamic Group: Fix frame strata setting
- Totem Trigger: Add a tooltip that a spell id can be entered
- IconPicker: Fix error for spells that don't have an icon
- Work around UnitInRange being wonky
- Model: Remove HasAnimation check
- BT2: Allow for multiple npcIds in npcId check
- IconPicker: If a spell id is entered, show the icon for that spell id

Stanzilla (2):

- Update TOC for Retail Patch 10.2.0
- Update PayPal link in README.md

mrbuds (8):

- Profiling: improve system profiling readability by regrouping multiUnits
- Theat Situation trigger: add nam/realm and npcId filters
- Colorize "Class and Specialization" options fixes #4657
- FontInstance:SetFont flags seems to break with "None"
- BT2: add affectedUnits and unaffectedUnits tables when Fetch affected names option is toggle
- Add "Not Item Equipped" load option, and make both Item Equipped option take multiple inputs
- Workaround fonts not loading correctly on first login
- Fix keybinding display

