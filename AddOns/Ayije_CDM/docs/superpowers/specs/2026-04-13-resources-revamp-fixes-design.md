# Resources Revamp Fixes — Design Spec

## Scope

Bug fixes, migration completeness, and targeted optimizations for the alpha branch resources revamp. No new features beyond `smoothBars` per-bar option.

## 1. Migration Completeness

### 1.1 Per-Spec Visibility Settings

Three old per-spec settings were silently dropped by the v9 migration. All three map to the new load conditions system.

**`resourcesManaSettings[specID]`**
- Old: `true/false` per spec — overrides `MANA_SPECS` defaults for which specs show the mana bar.
- New: `resourceBarSettings["General"]["Mana"].loadMode = "conditional"` + `load.spec[specID] = value`.
- Migration: Read `resourcesManaSettings` from the profile. Start from `MANA_SPECS` defaults. For each specID where the user's value differs from the default, write the user's value into `load.spec`. Set `loadMode = "conditional"`. If the user never touched `resourcesManaSettings`, do nothing — v10 already sets up defaults from `MANA_SPECS`.

**`resourcesPrimaryResourceSettings[specID]`**
- Old: `false` per spec — hides the primary (first non-mana) resource bar for that spec.
- New: `resourceBarSettings[classKey][barKey].loadMode = "conditional"` + `load.spec[specID] = false`.
- Migration: Build a spec-to-barKey mapping from `SPEC_POWER_MAP` (first non-mana entry per spec). For each specID with `false`, set that bar's `loadMode = "conditional"` and `load.spec[specID] = false`. If ALL specs for a bar have `false`, set `loadMode = "never"` instead.

**`resourcesSecondaryResourceSettings[specID]`**
- Old: `false` per spec — hides the secondary (second non-mana) resource bar for that spec.
- New: Same approach as primary, using second non-mana entry from `SPEC_POWER_MAP`.
- Migration: Same algorithm as primary settings, targeting the second bar key.

**Edge case — multi-spec classes:** A single bar key (e.g. Energy) may be primary for one spec and not present for another. The migration only writes `load.spec` entries for specs where the setting was explicitly `false`. Specs where the bar doesn't exist naturally won't show it regardless.

### 1.2 Tag Settings

**`resourcesTagSettings[specID] = {bar1Enabled, bar2Enabled}`**
- Old: Per-spec, per-slot (bar1/bar2) tag enabled state.
- New: `resourceBarSettings[classKey][barKey].tagEnabled` — flat per-bar boolean, no per-spec dimension.
- Migration: For each bar slot (1/2), if tag was disabled (`false`) on ANY spec, set `tagEnabled = false` for the corresponding bar key. Uses the same spec-to-barKey mapping as visibility settings (bar1 = primary, bar2 = secondary per spec). Per-spec granularity is lost; future work can add `tagEnabled` to load conditions.

### 1.3 Smooth Bars

**`resourcesSmoothBars`**
- Old: Global boolean (default `true`). Applied `ExponentialEaseOut` interpolation to primary resource bars.
- New: Per-bar `smoothBars` boolean on continuous non-pip bars.
- Eligible bars: Rage, Energy, Focus, RunicPower, LunarPower, Maelstrom, Insanity, Fury, Mana.
- Excluded bars (no toggle, hardcoded behavior): Stagger (`ExponentialEaseOut` always), Ironfur (`Immediate` always), IgnorePain (`Immediate` always).
- Default: `true` for eligible bars (matching master default).
- Migration: If user had `resourcesSmoothBars = false`, write `smoothBars = false` to all eligible bars. Otherwise do nothing (defaults handle it).
- Options UI: Checkbox per eligible continuous bar.

### 1.4 Anchor Chain After Migration

After migration, bars should replicate master's visual layout:
- **Primary bar**: `anchorTo = nil` (screen mode), with migrated `offsetX`/`offsetY`.
- **Secondary bar**: `anchorTo = <primaryBarKey>`, `anchorPoint = "BOTTOM"`, `anchorTargetPoint = "TOP"`. The secondary bar sits above the primary with `barSpacing` as the Y offset.
- **Mana** (when present on master): Was always slot 1 (bottom bar). In the new system, mana is independently positioned under "General" class. Migration sets mana to screen mode with `offsetX`/`offsetY` from the old profile. The primary non-mana bar anchors to screen (not to mana), and the secondary anchors to the primary. This means the mana bar and the primary bar are independently positioned after migration — the old unified vertical stack (mana at bottom, primary above, secondary on top) is preserved only if the user's offsets happen to align. This is an acceptable trade-off: the old offsets placed everything relative to one shared container, so the primary bar's screen position will be close to correct. Users can fine-tune in Options.

The spec-to-barKey mapping from `SPEC_POWER_MAP` determines which bar is primary and which is secondary for each class. Since the migration runs per-class (current character's class), the chain is set up for the active class only.

### 1.5 Bar Spacing

`resourcesBarSpacing` is already migrated in v9 to `resourceBarSettings[classKey][barKey].barSpacing`. Verify it lands on the correct bar (the secondary bar in the chain, since spacing is the gap between the secondary and the bar it anchors to).

### 1.6 Deferred / Intentional Drops

- `resourcesUnifiedBorder`: Preserved in profile, not migrated. Will be addressed after the revamp is complete.
- `resourcesMoveBuffsDown`: Intentionally removed. No migration needed.
- `resourcesEnabled`: Stays as module-level toggle. Not part of per-bar migration.

### 1.7 Old Key Cleanup

After migration, nil out all migrated flat keys so they don't persist as dead data in the saved profile.

## 2. Bug Fixes

### 2.1 Pip Color Revert (Plain Pip Bars)

**Problem:** When a condition stops matching on plain pip bars (HolyPower, ArcaneCharges, Chi, etc.), the `else` branch of `ApplyPipConditions` resets bg, alpha, and tag but not per-pip bar color. The base color path in `UpdateBarValue` Path D doesn't write per-pip colors for non-charged bars, so condition overrides persist.

**Fix:** In the `else` branch of `ApplyPipConditions` (~line 535), when a prior condition had set per-pip colors (tracked via a `condState` flag), loop over `bar.pips` and call `SetStatusBarColorIfChanged(pip, bar.color)` to restore base color. Add a `condState.pipColors` boolean to track whether per-pip condition colors were applied.

**Not affected:** Runes, Essence, SoulShards (base colors written every cycle), Rogue/Feral combo points (base colors written via charge overlay path).

### 2.2 Essential-Anchored Bars Flash on Login

**Problem:** Between `PLAYER_ENTERING_WORLD` (which wipes `anchorContainers`) and `LOADING_SCREEN_DISABLED` (which recreates them via `ForceReanchorAll`), essential-anchored resource bars resolve to UIParent fallback and are shown at the wrong position.

**Fix:** In `UpdateBarPositions`, when an essential-anchored or playerFrame-anchored bar can't resolve its target (`ResolveExternalAnchorFrame` returns nil), hide the bar instead of showing at UIParent. Matches the buff group pattern in `GroupContainerUtils.AnchorToTarget` which hides the container on target miss. Screen-anchored and bar-to-bar-anchored bars are unaffected — they show immediately.

When `ForceReanchorAll` triggers `UpdateResources` after `LOADING_SCREEN_DISABLED`, the target resolves and bars show at the correct position.

### 2.3 Vehicle Events Not Unit-Filtered

**Problem:** `UNIT_ENTERED_VEHICLE` and `UNIT_EXITED_VEHICLE` at Resources.lua:1583-1584 are registered with `RegisterResEvent` (plain `RegisterEvent`), causing handlers to fire for all units.

**Fix:** Change to `RegisterResUnitEvent("UNIT_ENTERED_VEHICLE", "player", OnVehicleStateChanged)` and same for `UNIT_EXITED_VEHICLE`. The `RegisterResUnitEvent` helper already exists (line 37).

## 3. Design Improvements

### 3.1 Anchor Cycle Prevention (UI)

**Problem:** The Options UI dropdown for bar-to-bar anchoring only checks one hop (`otherAnchor ~= barKey`). Cycles of 3+ bars are creatable. Runtime handles them safely (visited set, UIParent fallback) but silently.

**Fix:** Replace the one-hop filter with a full chain walk. For each candidate bar, follow its anchor chain via `GetBarSetting(candidateKey, "anchorTo")` with a visited set. If the chain reaches the current bar being configured, exclude the candidate. Same `visited` approach as runtime `ResolveAnchorTarget`.

## 4. Performance Optimizations

### 4.1 Pip Conditions Cache

**Problem:** `ApplyPipConditions` has no rule-collection cache. Every power update tick iterates all conditions linearly for every pip — O(pips x conditions).

**Fix:** Add a version/conditions/spec cache matching the `ApplyBarConditions` pattern. On cache miss: pre-filter valid rules (those with overrides and checks), store count and rule list. On cache hit: reuse the filtered list. Reduces per-tick work to O(pips x validRules) with fast-path skip when settings haven't changed.

### 4.2 powerMax Cache Key

**Problem:** The `ApplyBarConditions` cache key includes `powerMax` unconditionally. When only `powerPercent`/`powerFull` conditions exist, max-mana changes trigger a full 13-curve rebuild that produces identical output.

**Fix:** During `CollectValidRules`, track whether any rule uses `powerValue` (set a boolean flag). Only include `powerMax` in the cache equality check when that flag is true. When false, `powerMax` changes don't invalidate the cache.

## 5. Default Anchor Direction

The default `anchorPoint`/`anchorTargetPoint` for bar-to-bar anchoring must produce **upward stacking** (secondary above primary), matching master behavior:
- Secondary bar's `anchorPoint = "BOTTOM"`, `anchorTargetPoint = "TOP"`.
- Y offset = `barSpacing`.
- This means the secondary bar's bottom edge attaches to the primary bar's top edge, offset upward by `barSpacing`.

Update `RESOURCE_BAR_COMMON` defaults if the current values don't produce this behavior. The migration explicitly writes these values for migrated secondary bars.
