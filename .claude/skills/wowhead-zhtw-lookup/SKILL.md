---
name: wowhead-zhtw-lookup
description: Fetch official Traditional Chinese (zhTW) names of World of Warcraft quests, items, NPCs, spells, and zones from wowhead.com. Use this skill whenever you are translating a WoW addon (Lua files under AddOns/), need to verify official zhTW names for WoW content, or want to convert English quest/item/NPC names to their official Taiwanese localization. Trigger on phrases like "繁中化", "翻譯成中文", "translate addon", "zhTW name", "official Chinese name", or whenever quest IDs or English WoW content names appear and the user wants Chinese equivalents.
---

# Wowhead zhTW Lookup

Wowhead has the only reliable mapping of World of Warcraft entity IDs to official Traditional Chinese names. This skill encapsulates the working approach — including all the pitfalls discovered the hard way (CloudFront WAF, header requirements, throttling).

## When to use

- Translating WoW addon Lua files (objective text, quest names, NPC names) to Traditional Chinese
- Converting English quest/item/NPC IDs to their official zhTW names
- Verifying that a guessed Chinese translation matches Blizzard's official Taiwan localization
- Batch lookups across hundreds of IDs (e.g. an entire addon)

## The mechanism

Wowhead's English page contains `<link rel="alternate" hreflang="zh-TW" ...>` in the HTML head. The `href` attribute encodes the official zhTW name as URL-encoded UTF-8:

```html
<link rel="alternate" hreflang="zh-TW" href="https://www.wowhead.com/tw/quest=86837/太陽之井的會面">
```

So fetching the English `/quest=ID` page and grepping for that tag yields the official Taiwanese name.

URL formats by entity type:
- `https://www.wowhead.com/quest=<ID>`
- `https://www.wowhead.com/item=<ID>`
- `https://www.wowhead.com/spell=<ID>`
- `https://www.wowhead.com/npc=<ID>`
- `https://www.wowhead.com/zone=<ID>` (note: WoW addon `mapID` ≠ wowhead `zone` ID, this often fails)

## Critical: avoiding CloudFront 403

Wowhead is fronted by CloudFront with aggressive bot protection. Cutting corners gets the IP blacklisted for hours.

**What gets blocked:**
- Plain `curl` with default User-Agent → 403
- Parallel `xargs -P 25` → 403 after ~80 requests, IP blocked for hours
- Even just `curl -A "Mozilla/5.0"` (short UA) → eventually 403

**What works:**
- Full browser headers (User-Agent, sec-ch-ua, Sec-Fetch-*, Accept-Language)
- Serial requests with ~2 second sleep between each
- ~12 minutes for 373 quests at this rate (acceptable cost)

If you see a 403, **stop immediately**. The IP is blacklisted; further requests just deepen the block. Wait at least 30 minutes, ideally hours, before retrying. Tell the user the situation honestly rather than thrashing.

## How to use

### Single lookup

Use the bundled fetch script:

```bash
.claude/skills/wowhead-zhtw-lookup/scripts/fetch_one.sh quest 86837
# Output: 86837	Meet at the Sunwell	太陽之井的會面
```

Entity types: `quest`, `item`, `spell`, `npc`.

### Batch lookup (entire addon)

For translating a whole addon, extract all unique IDs first, then run the slow batch script:

```bash
# Extract quest IDs from a Lua data file
grep -oh 'questIDs = {[^}]*}' AddOns/MyAddon/Data/*.lua \
  | grep -oE '[0-9]+' | sort -u > /tmp/qids.txt

# Run batch fetcher (slow, ~2 sec each — leaves a TSV with id|en|zhtw)
.claude/skills/wowhead-zhtw-lookup/scripts/fetch_batch.sh \
  quest /tmp/qids.txt /tmp/results.tsv
```

For a 300-quest addon this takes ~10 minutes. **Run this in the background** (`run_in_background: true` on the Bash tool) and let it complete on its own — do not poll. While it runs, you can translate other text by hand using your best WoW Chinese knowledge; the batch fixup pass at the end will replace your guesses with the official names where they differ.

### Applying batch results

After batch lookup, write a Python script that:
1. Reads the TSV mapping (`questID → zhTW name`)
2. Walks the Lua source, finds `questName = "..."` next to `questIDs = {ID}` on the same line
3. Replaces the `questName` value with the official zhTW name from the mapping

Anchor the replacement on `questIDs`, not on the existing `questName`, since the existing name may already be a guessed Chinese translation. The pattern is reliable because Lua data tables typically keep questName and questIDs adjacent.

See `scripts/apply_zhtw_names.py` for a working example.

### Step titles need the original English as ground truth

Step `title = "..."` is **not** a quest name field — it's an author-written label. The author may pick any quest in the step (often the *main action* quest, which may not be the first listed) or use a thematic/place name (e.g. `"The Shadow Enclave"` for the delve location, not the quest done inside it).

Do **not** auto-replace step titles using the first questID in the step — that's how you end up turning "面對太陽" (the main quest) into "暫時得救" (a quick prerequisite that happens to come first).

The safe approach requires the original English source:

1. Get the original English Lua file (from upstream git, the addon author's repo, etc.)
2. For each step, read the original English title
3. Find which questID in that step has `questName == englishTitle` — that's the quest the author meant
4. Look up that specific questID in the wowhead mapping → that's the correct zhTW title
5. If the English title doesn't match any questName in the step, it's a thematic/place label — leave the existing zh title alone

See `scripts/correct_titles_from_english.py` for a working example. Without the original English, you cannot reliably correct step titles in multi-quest steps; in that case, leave them as-is and only fix the ones the user explicitly flags after seeing them in-game.

### Place names that aren't quest titles

`hreflang="zh-TW"` only gives you each quest's *title*. Place names, NPC names, and zone descriptors don't appear in the title — they appear in the quest *description body* and *objectives*, which are shown on the zhTW page but not in the hreflang tag.

To find official zhTW place/NPC names:

1. Use `scripts/fetch_zhpages.sh` to slow-fetch all `/tw/quest=ID` pages as full HTML (~12 min for 300 quests, same throttle rules as `fetch_batch.sh`)
2. Use `scripts/build_zhtw_corpus.py` to extract Chinese phrases from each cached page
3. Grep the corpus for candidate names — for example, "Amani Pass" → search for `阿曼尼` to find the official `阿曼尼小徑`

This works because every quest description in zhTW mentions the places/NPCs involved. A 300-quest addon yields ~30,000 Chinese phrase fragments, more than enough to triangulate any zone or NPC name that appears in the addon's content.

Use `scripts/audit_place_names.py` to find step titles whose place names don't appear in the corpus — these are likely subagent guesses that need verification. Real official names will almost always have multiple matches in the corpus (the same place is referenced by many quests).

Common patterns of subagent translation errors caught by this method:
- Extra/missing characters: `哈蘭達` should be `哈朗達`; `哈拉諾爾` should be `哈拉諾`
- Wrong character choice: `虛空風暴` should be `虛無風暴`
- Synonyms: `神殿` vs `神廟` (check which is canonical in the corpus)
- Made-up place name where the agent invented a translation: e.g. `阿曼尼隘口` for "Amani Pass" when the official is `阿曼尼小徑`

## Common pitfalls

1. **Map IDs ≠ wowhead zone IDs.** WoW C_Map UI map IDs (the `mapID` field in Lua data) usually do not match wowhead's `zone=` parameter. Don't waste time trying to look up zone names this way; either translate them by hand from a known glossary or accept manual translation.

2. **Some Midnight (12.x) quests aren't in zhTW yet.** A small fraction (1-2%) of brand-new content may have an empty `hreflang="zh-TW"` href. Handle this gracefully — fall back to the English name or keep the existing translation.

3. **The hreflang link can be missing entirely if the page returns 403.** Always check the HTTP status code first before parsing. A 919-byte response is the CloudFront error page.

4. **Quest names are not unique** — two different quest IDs can have the same English name. Always anchor your replacement on the ID, never on the name.

## Glossary of key terms

For the wider Midnight expansion content (which spans many addons), keep these standard Taiwan-localized terms even if not every quest gets looked up individually:

- Midnight → 至暗之夜（資料片名）
- Alt (角色) → 分身（不是「小號」）
- Delve / Delver's Call → 探究 / 探究者之喚
- Sojourner → 漫遊者
- War Mode → 戰爭模式
- Warband → 軍團
- Hearthstone → 爐石
- Disenchant → 分解
- First Craft Bonus → 初次製作獎勵
- yds → 碼

When in doubt about a place or NPC name, check wowhead first; if it has a zhTW page for that entity, use that name verbatim.
