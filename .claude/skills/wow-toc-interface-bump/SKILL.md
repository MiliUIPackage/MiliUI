---
name: wow-toc-interface-bump
description: Bump the "## Interface:" version in every WoW addon .toc across an AddOns folder so the whole pack supports a new patch (整包插件 toc 支援新版本號 / 更新 Interface 版本 / 插件顯示過期). Use this whenever the user wants addons to stop showing as out of date, mentions a patch number like 12.1 / 120100 / 12.1.5, says "整包 toc 都改成 X", "支援 120100", "bump the toc versions", or asks how a patch number maps to an interface number. Always run the bundled script rather than hand-editing TOCs or writing a new one-off script — the retail/classic digit rule below is easy to get wrong and silently breaks multi-flavor addons.
---

# WoW TOC Interface Version Bump

Run `scripts/bump_toc.py` against an `AddOns` folder to add a new interface version to every
retail TOC in one pass. It is a dry run unless you pass `--apply`, so it is safe to run first and
show the user what would change.

## Interface number format

`X YY ZZ` — expansion, then two digits each for the major and minor patch, zero-padded:

| Patch | Interface |
|---|---|
| 12.0.7 | `120007` |
| 12.1.0 | `120100` |
| 12.1.5 | `120105` |
| 11.5.8 (retail) | `110508` |

If the user says "12.1", they mean `120100`. When they give an ambiguous number, restate the
mapping before running — `120150` is a common mistake for 12.1.5 (that would read as 12.1.50).

## Usage

```bash
python3 scripts/bump_toc.py --target 120100 --dir "/Applications/World of Warcraft/_ptr_/Interface/AddOns"
```

Read the dry-run output with the user, then re-run the identical command with `--apply`.

| Flag | Meaning |
|---|---|
| `--target` | 6-digit interface number to add (required) |
| `--dir` | the `AddOns` folder itself, not the `Interface` folder |
| `--mode add` | default; keeps existing retail versions, e.g. `120007` → `120007, 120100` |
| `--mode replace` | collapses every retail version into the target, e.g. `120005, 120007` → `120100` |
| `--apply` | write the files (otherwise dry run) |

Default to `add`. It lets one copy of the addon run on both live and PTR, which is usually what
someone bumping a whole pack wants. Reach for `replace` only when the user explicitly wants to
drop support for the old patch or clean up an interface list that has accumulated stale entries.

## The rule that matters: 6 digits is retail, 5 digits is classic

Many TOCs list several flavors at once:

```
## Interface: 11508, 40402, 120007, 50503, 20505, 38001
```

`11508` is **Classic Era 1.15.8**, not retail 11.5.8. Deciding "is this a retail version?" by
numeric comparison instead of digit count will misread classic entries and insert the new retail
number in the wrong place — or worse, into a classic-only TOC, which makes the addon unloadable on
that client. The script keys on `\d{6}`, which is why you should use it instead of a fresh
one-liner each time.

The script also leaves alone, and reports separately:

- TOCs whose filename carries a non-retail flavor suffix (`_Vanilla`, `_TBC`, `_Wrath`, `_Cata`,
  `_Mists`, `-Classic`, …)
- `## Interface-<flavor>:` directives for non-retail clients
- TOCs with no retail version at all, and TOCs with no `Interface` line

Every file it sees lands in exactly one bucket and the counts are printed, so an unexpected
"skipped" entry is visible rather than silent. If the totals don't add up to the number of TOCs
you expected, investigate before applying — an addon folder with no TOC at all (extracted Blizzard
first-party addons, for example) simply won't appear.

## Formatting is preserved

Only the values on the `Interface` line are rewritten. UTF-8 BOMs and CRLF line endings survive,
so the diff stays to one line per file. Verify after applying:

```bash
git diff --shortstat -- '*.toc'
```

You should see `N files changed, N insertions(+), N deletions(-)` — the same N three times. Any
mismatch means something other than the Interface line moved, and is worth looking at before
committing.

## After bumping

A TOC bump only stops the "out of date" label. It says nothing about whether the addon's code
still works on the new patch — API removals, taint changes, and secret-value restrictions are
separate problems. Say so plainly rather than implying the pack is now patch-ready.
