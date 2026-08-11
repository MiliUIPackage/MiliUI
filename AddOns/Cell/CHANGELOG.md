# r282-MiliUI: WoW 12.1 Aura Containers ("Route A")

Interface bumped to 120100. Two days of work, `79 files changed, +2899 / −69730`.

In 12.1 an aura's `spellId`, `name`, `duration`, `applications` and `dispelName` on a teammate are all secret, and `GetAuraSlots` / `GetAuraDataBySlot` **Lua-error outright** while auras are secret and the caller is tainted — which Cell always is. Every icon display that worked by scanning auras and matching a curated spell-ID list was therefore dead in exactly the content it exists for: encounters, M+, PvP.

The fix is not to read auras better. It is to stop reading them: register Blizzard's `AuraContainer` with a filter string plus `candidateFilters`, hand it our widgets, and let the engine fill, sort and drive them. Membership *is* the predicate — we never see a spell ID or a remaining time. This is the mechanism Coolinator and DandersFrames v5 validated in-game.

## One renderer for every aura icon

- **New `RaidFrames/AuraContainerCore.lua`** (`Cell.AuraContainerCore`) — the stateless adapter over Blizzard's API: capability probe, duration formatter, flow layout, dispel-texture/text binding, font application, dispel palette.
- **`RaidFrames/RaidDebuffContainer.lua` → `RaidFrames/AuraDisplay.lua`** (`Cell.RaidDebuffContainer` → `Cell.AuraDisplay`) — Cell policy and container lifecycle. Renamed once it stopped being about raid debuffs; `indicatorName` keys are untouched.

Backed by containers now: the central Important Debuffs display, the debuff row, the dispel icons, the dispel health-bar highlight, all three cooldown rows, and custom buff-icon indicators. Each one is configured by pushing its **whole layout entry** through `ConfigureContainer`.

### The bridge, and its removal

An independent second implementation (`RaidFrames/AuraContainerBridge.lua`, ported from MiliUI) briefly owned the debuff row, the cooldown rows and custom buff icons. It was **pull-based** — polling every unit button on eight events, scraping config off the indicator frames' `GetPoint`, rebuilding on a signature change — while `AuraDisplay` is **push-based** from the layout table. Two copies of the same plumbing had already drifted: two different countdown formats on the same frame, and a dispel palette that only half the icons honoured.

Folded into `AuraDisplay` and deleted (−1466 lines). Its config scraping is gone entirely; the layout table is the only source of truth.

## Classic support removed

This fork is retail-only. Removed the Cata/Mists/TBC/Vanilla/Wrath TOCs, `Core_*.lua`, `UnitButton_*.lua` variants, Classic defaults and indicators, `BuffTracker_Classic`, and the localized `ExpansionData` raid-debuff tables — roughly 69,000 lines. The Classic branches remaining in `Modules/Indicators/Indicators.lua` are unreachable and were deliberately left untouched.

## Important Debuffs

The central indicator is renamed from **Raid Debuffs** to **Important Debuffs** (`L["Important Debuffs"]`, translated in all 11 locales). It no longer matches a curated spell-ID list — it asks Blizzard for five categories, each its own `AuraGroup`, and the old name described the wrong thing. "Raid Debuffs" now refers only to the curated-list tab, which still drives the glow.

New `raidDebuffFilters` options widget — five toggles, all on by default:

| Toggle | Implementation |
|---|---|
| Boss/Role Debuffs | `candidateFilters = {isBossOrRoleAura = true}` |
| Priority Debuffs | `candidateFilters = {isPriorityAura = true}` |
| Crowd Controls | `HARMFUL\|CROWD_CONTROL` |
| Raid-wide Debuffs | `HARMFUL\|RAID` |
| Dispellable | `HARMFUL\|RAID_PLAYER_DISPELLABLE` |

Records are mutually exclusive: the important-first records claim their auras with no negation, and the token records subtract them via `false` candidate-filter flags. Boss and Role are one toggle — `isBossOrRoleAura` covers both and no UI ever split them.

## Debuff row

- New **Hide debuffs already shown as important** option (`excludeImportant`), **on by default**. It reads the Important Debuffs display's five toggles live and subtracts exactly what that display is claiming, so no aura is ever drawn in both places. All five inverses were already load-bearing inside `BuildRecords`: `|!CROWD_CONTROL`, `|!RAID`, `|!RAID_PLAYER_DISPELLABLE`, `isBossOrRoleAura = false`, `isPriorityAura = false`. They compose into a single record.
  - Gated on the Important Debuffs indicator being **enabled** — if it claims nothing, subtracting would make those debuffs vanish from the frame entirely.
  - `dispellableByMe` wins over the Dispellable subtraction. "Only what I can dispel" plus "none of what I can dispel" composes to a filter that matches nothing, silently.
- The blacklist rides on `candidateFilters.excludeSpellIDs`. The client only honours ID filtering for spells flagged NeverSecret — which still covers what the blacklist is for (Exhaustion/Sated and friends). Encounter debuffs cannot be excluded by ID at all.
- `size-normal-big` became a plain `size`: a container group has one element size. `bigDebuffs` is gone with the spell-ID ban, and `showAnimation` / `showTooltip` / `enableBlacklistShortcut` were dropped because the container cannot honour them.

## Icon rendering

Every icon display uses one look — Cell's `I.CreateAura_BorderIcon` shape, where the Cooldown covers the whole button and the icon sits in an inset child frame above it, so the countdown reads as a border draining clockwise. The `swipe` and `bar` variants are gone.

**The colour is on the static ring and the swipe is what eats it**, not the reverse. That inversion is forced, not stylistic: `SetSwipeColor` takes a literal RGB and an `AuraButton` never tells us the dispel school, so a coloured swipe could never be school-coloured. A static texture can — Blizzard vertex-tints it for us, blind.

Ring colour:

- dispel school present → the user's own palette (`CellDB.debuffTypeColor`)
- no school, HARMFUL → debuff red, also from the palette (`"none"`, default `0.8/0/0`)
- no school, HELPFUL → green `{0, 0.55, 0.15}`
- `borderColor` overrides the last two (custom indicators with their own colour setting)

The two ring layers must **not** both carry the fallback colour: Blizzard's school tint arrives as a vertex colour, and a red tint over a dark-green base multiplies to near-black. `dfBG` carries our colour and is always drawn; `dfDispelBorder` is plain white, handed to Blizzard, shown and tinted only when the aura has a school.

## Bugs fixed

- **Client freeze on any option change that restyles.** `StyleButton` appended to `handle.buttons`, and `Restyle` iterated that same table with `ipairs` while calling `StyleButton` on each entry — index and length advanced together, so the loop never terminated. Tracking moved to `Build`'s `initFn` (the only place a new button arrives) and `Restyle` now uses a snapshotted numeric bound. Buttons are also tracked *before* styling, so one that throws mid-pass can still be repaired later.
- **Newly created indicators rendered nothing until `/reload`.** The generic `ConfigureContainer` push ran *before* the setting dispatch, but `setting == "create"` builds the indicator *inside* that dispatch — so a fresh indicator was skipped, its container kept the `Create()` defaults, `spellIDs` stayed empty, `BuildRecords` returned no records and nothing was drawn. This is what the first-run "create a Healers indicator?" prompt hit. The push now runs after the dispatch.
- **Font and colour sliders did nothing.** `SetOptions` stored table options *by reference*, but Cell's options panel mutates `indicatorTable["font"][n]` **in place** and fires with the same table — so the stored "old" value moved with the new one and no comparison could ever detect a change. Other options (`spellIDs`) arrive as a fresh table every call, where a reference compare reports "changed" every time and rebuilds the container on every touch. Both are fixed by snapshotting a content signature at the moment a value is accepted.
- **Options changed inside an instance were never applied.** `Restyle` deferred to `PLAYER_REGEN_ENABLED` while auras were secret — but auras stay secret for a whole dungeon or encounter, not just during combat, so the change waited for a combat-end that might never come. It now rebuilds instead, which is legal (fresh buttons are styled from `initializeFrame`). A restyle refused during combat now also sets its pending flag instead of being dropped outright.
- **A new `OnShow` hook per layout apply, forever.** Custom indicators are destroyed and rebuilt on every `HandleIndicators`, and `HookScript` cannot unhook — so hooking from the attach path stacked a closure holding a dead indicator on every apply. One hook per button now, walking the `_containerIndicators` registry.
- **A rejected filter string silently emptied a display.** `BuildRecords` returned no records, `Build` created no container, and nothing rendered — no error, no log. Rejections now fall back toward *less* filtering (never an empty row) and are recorded in `AD.rejectedFilters` for `/cab` to name.
- Per-aura `IsAuraFilteredOutByInstanceID` calls for the central indicator are skipped when a container backs it; the unused `secretIsDispellable` computation is gone.
- Bare `HELPFUL` with an empty include list would have shown *every* buff; buff mode now builds no record instead.

## Defaults and migration

| | |
|---|---|
| Important Debuffs | 18×18, stack font 9, all five categories on |
| Debuff row | 15×15, stack font 8, exclude-important on |
| Healers template (`F.FirstRun`) | 17×17, duration font 11, stack font 8 |
| Dispels | "only what I can dispel" **on** (reverses `5f360d321`) |

Existing SavedVariables are migrated by two **revision-gated** blocks in `Revise.lua` (`dbRevision < 281` and `< 282`). Gating matters: the 12.1 block above them is ungated and must stay idempotent, whereas anything that rewrites sizes or font sizes would otherwise stomp the user's own adjustments on every login.

For layouts saved before an option existed, "key absent" is interpreted as whatever preserves the old display — categories default on because the old display showed everything, while `excludeImportant` is switched on by an explicit one-time migration rather than by reinterpreting absence, because absence there meant the opposite.

## Addon communication

This build no longer broadcasts `CELL_VERSION`. The handshake exists to tell other Cell users a newer release is out; a fork cannot make that claim honestly, because the number in `rNNN-MiliUI` is bumped locally just to gate migrations and is not a point on upstream's release line. Stock Cell receivers parse only the digits, so every guildmate and party member would have been told to update to a version that does not exist.

Receiving stays on, so stock Cell's own version checks are untouched. `CELL_MARKS`, `CELL_CPRIO`/`CELL_PRIO` and `CELL_REQ`/`CELL_SEND`/`CELL_SEND_PROG` are functional cooperation rather than version noise and remain fully interoperable — layout exchange was checked in both directions and is safe.

## Diagnostics

`/cab` — capability report, per-record filter validity, rejected filters, and every visible container-backed handle. Sub-commands: `list`, `ghosts`, `inspect [unit]`, `overdraw [unit]`, `spell <id>`, `test` (a six-step filter bisect). The former `RDC_Test()` global is folded into `/cab test`.

Whether an `AuraButton` is actually rendering is **secret** — branching on its `IsShown` or geometry throws — so the diagnostics report everything readable around it (records, allocated button counts, anchor-frame rects, bind errors) and leave the final judgement to the eye. Filter strings are pipe-escaped in output; unescaped, the chat frame eats `|R` as a colour reset and prints `HARMFUL|RAID` as `HARMFULAID`.

## Unverified

Not confirmed in-game at time of writing:

- The `candidateFilters` boolean-`false` subtraction (`isBossOrRoleAura = false`, `isPriorityAura = false`). Its failure mode is benign — those debuffs would show in both places rather than neither.
- Per-icon visual confirmation of the central Important Debuffs display against real encounter debuffs.
- Custom `bar` / `bars` / `block` / `blocks` / `rect` buff indicators stay on the manual path and freeze while auras are secret. The bridge appeared to handle them only by drawing icons in their place, which is not what those types are.

# r276-beta: WoW 12.0.5 Compatibility

Interface bumped to 120005. Without these fixes Cell showed static white health bars, missing health/power text, and taint errors in PvP/M+.

## API Updates

- Added required `isContainer = false` to `C_UnitAuras.AddPrivateAuraAnchor` args (new in 12.0.5).

## Secret-Value Guards

12.0.5 decoupled Secret Value restrictions from the aura-restriction context flag, so `F.IsAuraRestricted()` context-guards miss real secrets. Replaced with per-value `F.IsSecretValue` / `issecretvalue` checks at the use site:

- `Indicators/Custom.lua`: `auraInfo.sourceUnit` comparison for the cast-by-me filter.
- `Indicators/TargetedSpells.lua`: `UnitCastingInfo` / `UnitChannelInfo` returns (`spellId`, timestamps, `texture`).
- `RaidFrames/UnitButton.lua`: `UnitGUID` comparisons in `UnitButton_OnTick`; `powerMax` in `UnitButton_UpdatePowerStates`.
- `Utilities/BuffTracker.lua`: LGI cache lookup by GUID.
- `Utilities/DeathReport.lua`: `reportedDead[guid]` table key.

## Text Indicators on Secret Values

`UnitHealPredictionCalculator` returns secret-flagged numbers even in normal gameplay. Lua arithmetic and comparisons throw, but C-implemented formatters (`string.format`, `AbbreviateNumbers`, `BreakUpLargeNumbers`) pass secrets through to non-secret strings. Percentages come from calculator curve methods.

- **Health Text**: new `midnightFormatter` table backed by calculator methods, plus `GetMidnightCurves` factory (two reusable `C_CurveUtil` curves for positive and negative percentage scales). `HealthText_SetFormat` stashes format names for lookup; `HealthText_SetValue` takes a new `calc` arg and routes each slot when values are secret. Caller in `RaidFrames/UnitButton.lua` passes the unit's `healthCalculator`.
- **Power Text**: `SetPower_Percentage` calls `UnitPowerPercent(unit, nil, true, CurveConstants.ScaleTo100)` (wrapped in `pcall`) to get a plain 0-100 value when Cell's context would otherwise return a secret `UnitPower`. Caller at `UnitButton_UpdatePowerText` passes `self.states.displayedUnit` so the formatter has a unit to query. `SetPower_Number` uses `string.format("%d", current)`, `SetPower_Number_Short` uses `AbbreviateNumbers`. Non-secret paths moved to `SafeTextWidth` because `GetStringWidth` stays tainted after the FontString held secret text.
- **Power bar**: `UnitButton_UpdatePowerMax` and `UnitButton_UpdatePower` now use native `SetMinMaxValues` and `SetValue` on Midnight unconditionally, bypassing `SmoothStatusBarMixin`. The mixin caches min/max and its per-frame `Clamp()` throws every tick if either value was ever secret, even after the current value is plain. Matches what the health bar already does on Midnight.
- **`SafeTextWidth` helper**: font-proportional fallback when `GetStringWidth` returns a secret-flagged width. Used by both text indicators' secret paths and their `SetFont` paths.
- **QuickAssist**: no change; `StatusBar:SetValue` / `:SetMinMaxValues` accept secrets natively.

### Supported formats on secret values

Health Text: `health`, `health_short`, `health_percent`, `deficit`, `deficit_short`, `deficit_percent`, `shields`, `shields_short`, `healabsorbs`, `healabsorbs_short`. `effective_*` degrades to matching `health_*` (no `GetEffectiveHealth` method). `*_percent` on shields/healabsorbs degrades to short absolute (no matching curve method).

Power Text: `number`, `number-short`, `percentage`. Percent uses `UnitPowerPercent` with `CurveConstants.ScaleTo100` and renders correctly even when raw `UnitPower` is secret. Falls back to `AbbreviateNumbers` only if `UnitPowerPercent` is unavailable or the pcall fails.

### Limitations

- `hideIfEmptyOrFull` is a no-op on secret values (needs comparisons).
- `effective`-format on health diverges from true effective only when shields or heal absorbs are active.

## Aura Classification

12.0.5 un-secreted `isHelpful`, `isHarmful`, `isRaid`, `isNameplateOnly`, `isFromPlayerOrPlayerPet`. Removed the `issecretvalue(auraInfo.isHelpful)` early-return in `Indicators/Custom.lua` and the classification-secret fallback in `RaidFrames/UnitButton.lua`'s incremental aura fast path.

# r275.5 Added Midnight Raid Debuffs

## Raid Debuffs

- Added initial Midnight expansion raid debuffs for all 12 instances (6 raids, 6 dungeons) and 41 bosses.
- Boss ability spell IDs sourced from the Encounter Journal via wago.tools DB2 tables.
- General (trash mob) debuffs still need to be collected in-game and added in a future update.
- Spells may need further in-game curation to filter out non-debuff abilities.

# r275-release — WoW 12.0.0 (Midnight) Compatibility

Comprehensive compatibility update for WoW Patch 12.0.0 (Midnight), addressing the removal of `COMBAT_LOG_EVENT_UNFILTERED`, the introduction of Secret Values, blocked addon communications during restricted contexts, and spell/API removals. Interface bumped to 120001.

## Secret Values (12.0.0+)

- Add `Cell.isMidnight` detection flag and `F.IsSecretValue()`, `F.IsAuraRestricted()`, `F.IsCooldownRestricted()` utility functions
- Add per-aura `F.IsAuraNonSecret()`, `F.IsSpellAuraNonSecret()`, `F.IsValueNonSecret()` helpers — non-secret (whitelisted) auras now get real countdown timers, source detection, and duration display; secret auras gracefully degrade
- UnitButton: major dual-path refactor — Midnight uses `UnitHealPredictionCalculator`, `C_CurveUtil.CreateCurve()`, and StatusBar overlays for health/prediction/shields; pre-Midnight retains arithmetic-based paths
- Appearance: IncomingHeal widget uses `SetStatusBarTexture` on Midnight (StatusBar) vs `SetTexture` pre-Midnight (Texture)
- Indicator_Defaults: local `DebuffTypeColor` fallback for when the WoW global is removed
- Per-field `F.IsValueNonSecret()` guards before every arithmetic operation on temporal aura fields (`expirationTime`, `duration`, `applications`, and cached `old*` variants)

## CLEU Removal

- AoEHealing: disabled on Midnight (CLEU unavailable); frame still exists for potential future non-CLEU API
- StatusIcon: soulstone/resurrection tracking switches to `UNIT_AURA` + `UNIT_HEALTH` on Midnight
- NPCFrame: boss6-8 health/aura tracking switches to unit events on Midnight
- DeathReport: full refactor — Midnight uses `UNIT_HEALTH` + `UnitIsDeadOrGhost()` for death detection
- UnitButton: removed `CombatLogGetCurrentEventInfo` dependency and `CheckCLEURequired`
- General: removed `useCleuHealthUpdater` checkbox (CLEU health updater obsolete)
- Revise: r275 migration removes `useCleuHealthUpdater` from saved variables

## Comm Restrictions

- Comm: `IsCommRestricted()` detects encounters/M+/PvP; all `SendCommMessage` calls guarded; pending queue with flush on `ENCOUNTER_END`
- Nicknames: all nickname sync sends guarded with `F.IsCommRestricted()`

## Heal Prediction & Health Bar Fixes

- Created a dedicated `healPredictionCalculator` separate from the shared `healthCalculator` — the heal prediction function's `SetIncomingHealClampMode(0)` and `SetIncomingHealOverflowPercent(1.0)` were persisting on the shared calculator and corrupting health/absorb reads
- Incoming heal bar is now a StatusBar (instead of Texture) anchored to the health fill texture edge
- Fixed health bar loss color stuck on white/full-health — `self.states.healthPercent` was never set on the Midnight path; now populated from `calculator:GetCurrentHealthPercent()` with a secret-safe fallback
- Dispels now show correctly because `HandleDebuff` completes to the dispel detection code (string/boolean fields, not temporal arithmetic)

## Spell & Default Updates

- Removed: Engulf, Renew, Power Word: Life, Void Shift, Shadow Covenant, Divine Star, Cloudburst Totem, Minor Cenarion Ward, Premonition of Solace
- Added: Plea (200829, Disc Priest)
- Added missing healing spells to default indicator list (Evoker, Monk, Paladin, Priest)
- Moved: Prayer of Mending from class-wide to Holy spec only
- Fixed: Shaman Poison dispel node IDs (103609 -> 103599)

## Defensive Nil Guards & Fixes

- MainFrame: nil guards for `currentLayoutTable` and `tooltipPoint`
- HideBlizzard: guards for `PartyMemberFramePool`, `CompactPartyFrame`, `PartyMemberBackground`
- RaidDebuffs: nil guard for encounter journal expansion data
- TargetedSpells: skip enemy spell tracking during restricted periods
- BuffTracker: guard `GetAuraDataBySpellName` when auras are restricted; per-aura `sourceUnit` check
- QuickCast: skip only secret auras in `ForEachAura`
- Custom indicators: per-aura secret check for duration/start
- Appearance: ticker nil guard in preview `OnHide`

## Infrastructure

- All 22 XML files updated from `FrameXML/UI_shared.xsd` -> `Blizzard_SharedXML/UI.xsd`
- Core: version constants bumped to 275, `GetBattlegroundInfo` guard added

---

# r274-release

[View Full Changelog](https://github.com/enderneko/Cell/compare/r273-release...c376c32494926a90b93cc63bfc564234fb6e5cd6)

- Update Molten Core debuffs
- Fix boss unit button mapping
