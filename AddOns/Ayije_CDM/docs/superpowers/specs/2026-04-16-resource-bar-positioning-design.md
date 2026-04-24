# Resource Bar Positioning — Design Spec

## Problem

The alpha branch's per-bar anchor system models resource bar positioning as an N-bar chain (e.g., 5 Druid bars linked Rage→Energy→ComboPoints→LunarPower→Ironfur). This is over-engineered — at most 2 non-mana bars are ever active simultaneously. The chain causes:

- **Fresh installs**: all bars default to the same screen position (0, -200). Multi-bar specs overlap.
- **Migrated profiles**: only the first `CLASS_BARS` entry holds the user's old position. Specs where that bar isn't active (e.g., Feral Druid → Energy is first, not Rage) fall back to default position.

## Design

Replace the chain-walking anchor system with runtime stacking that replicates master's behavior: first bar at screen position, second bar stacked above it, Mana at the base when present.

### Runtime Stacking

In `UpdateBarPositions`, after `GetActiveBarKeys` returns the active bar list:

1. Collect active bars in order: Mana first (if active), then class bars from `GetActiveBarKeys`
2. First active bar → screen position using its own `offsetX`/`offsetY`
3. Each subsequent bar → anchored BOTTOM to TOP of the previous bar, with the subsequent bar's `barSpacing` as Y offset
4. If a bar has an explicit custom anchor (`anchorTo` set to `"playerFrame"`, `"essential"`, or a specific bar key), use that instead of auto-stacking

This handles all form transitions naturally. Druid shifts from cat (Mana → Energy → ComboPoints) to bear (Mana → Rage) without any anchor reconfiguration — the stack is rebuilt from the active bar list each time.

### Max Active Bars Per Spec

Every spec has at most 2 non-mana bars active simultaneously:

| Class | Always-first bars | Always-second bars |
|---|---|---|
| Druid | Rage, Energy, LunarPower | ComboPoints, Ironfur |
| Warrior | Rage | IgnorePain |
| Rogue | Energy | ComboPoints |
| DK | RunicPower | Runes |
| Monk | Energy | Chi, Stagger |
| DH | Fury | SoulFragments, DevourerSoulFragments |
| Hunter | Focus | TipOfTheSpear |
| Single-bar classes | the bar | — |

### Fresh Install Defaults

No changes to `RESOURCE_BAR_COMMON` or `RESOURCE_BAR_PER_KEY` needed. All bars default to:

- `anchorTo`: nil (screen)
- `offsetX`: 0
- `offsetY`: -200

Runtime stacking handles multi-bar specs automatically. First bar at (0, -200), subsequent bars stack above with `barSpacing`.

### Migration Changes

#### Screen offsets

In `BuildBarEntry`, write the user's old `offsetX`/`offsetY` to all bars that can be "first active" for the class. In the old system these offsets were shared (one container), so all first-candidate bars get the same values.

Bars that are always "second" don't need screen offsets — they always stack above the first bar at runtime. Their `offsetX`/`offsetY` remain at defaults (0, -200) as a fallback if the user later changes their anchor to screen.

The per-class first/second classification comes from `SPEC_POWER_MAP`: a bar is "always second" if it only ever appears as the second entry in any spec's power list, never as the first or only entry.

Mana (`General` class) is always a first-candidate — it gets the user's old offsets.

#### Remove bar-to-bar chain from migration

`BuildBarEntry` currently sets `anchorTo = prevBarKey` for non-first bars. Remove this — all bars default to `anchorTo = nil` (screen). The runtime stacking replaces the chain.

This also eliminates the `isFirst` / `prevBarKey` tracking in the migration loop.

#### isBar2 for height/tag settings

The `isBar2` logic (selecting bar1 vs bar2 height/tag settings) is unchanged. The `LEGACY_BAR2_BY_SPEC` table still determines which bar gets secondary settings.

Fix the two missing entries identified in the review:
- `[263] = false` — Enhancement Shaman (MaelstromWeapon is bar1, no bar2)
- `[1480] = "DevourerSoulFragments"` — Devourer DH

### Mana Integration

Mana participates in the runtime stack as the first bar when active. No special migration logic needed beyond giving it the user's old offsets (already done in current migration).

Stack examples for Restoration Druid:

- Caster form: Mana at screen position (only bar)
- Cat form: Mana at screen → Energy stacked above → ComboPoints stacked above Energy
- Bear form: Mana at screen → Rage stacked above

When Mana is not active (e.g., Feral spec), the first class bar takes the screen position directly.

The Mana load conditions migration (v10) is already correct — it preserves the user's per-spec enabled/disabled state from `resourcesManaSettings`, falling back to `MANA_SPECS` defaults.

### ResolveAnchorTarget Simplification

The current `ResolveAnchorTarget` function walks a bar-to-bar chain with cycle detection. This can be simplified:

- If `anchorTo` is nil or `"screen"` → return UIParent with the bar's offsets
- If `anchorTo` is `"playerFrame"` → return playerFrame anchor
- If `anchorTo` is `"essential"` → return essential viewer anchor
- If `anchorTo` is a specific bar key → resolve that single bar (no chain walking)
- Remove the visited-set chain walking loop

The chain walking was only needed because the default configuration chained bars through intermediates. With runtime stacking as the default, explicit bar-to-bar anchors only need single-hop resolution.

### What's Preserved

- Per-bar `anchorTo` options (screen, playerFrame, essential, specific bar) for user customization
- Per-bar `offsetX`/`offsetY` for independent positioning when the user opts into it
- Per-bar `barSpacing` used by runtime stacking
- Anchor cycle prevention in Options UI (still needed for explicit bar-to-bar anchors)
- All non-positioning per-bar settings (height, width, color, tag, smoothBars, loadMode, conditions)

### What's Removed

- Bar-to-bar chain as default configuration (migration no longer writes `anchorTo = prevBarKey`)
- Chain-walking loop in `ResolveAnchorTarget` (replaced by single-hop lookup)
- `isFirst` / `prevBarKey` tracking in migration
