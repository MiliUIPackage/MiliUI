---
name: wow-ui-source-lookup
description: Look up Blizzard's stock WoW UI source code (mixins, frame templates, XML, function bodies) and API struct/function signatures from the public Gethe/wow-ui-source mirror and warcraft.wiki.gg. Use this skill whenever you need to hook, override, or understand a Blizzard frame in a WoW addon — e.g. "what fields does CraftingOrderInfo have", "where is ProfessionsCrafterOrderListElementMixin:Init defined", "show me the XML for QuestLogFrame", "what does C_CraftingOrders.GetCrafterOrders return". Trigger on phrases like "Blizzard 源碼", "Blizzard source", "wow-ui-source", "frame template", "mixin", "hooksecurefunc 哪個函式", "C_XXX 的回傳", "struct 的欄位", or whenever you see a Blizzard frame / mixin / `C_*` API name and need its definition.
---

# WoW UI Source Lookup

When writing or modifying a WoW addon that hooks Blizzard's stock UI, you need three kinds of info that the local game install does **not** contain:

1. **Lua mixin / function bodies** — `ProfessionsCrafterOrderListElementMixin:Init`, etc.
2. **XML frame templates** — child frame names like `ItemName`, `MinQuality`
3. **API struct fields & return values** — `CraftingOrderInfo.npcOrderRewards`, `C_CraftingOrders.GetCrafterOrders` signature

This skill encapsulates the working approach using `WebFetch` against two upstream sources.

## Sources

### Gethe/wow-ui-source — Blizzard source mirror

The canonical public mirror of Blizzard's shipped UI Lua/XML. Updated each patch.

- **Directory listing** (use to find filenames first when unsure):
  `https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_<AddonName>`
- **Raw file** (use to fetch actual source):
  `https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_<AddonName>/<FileName>.lua`

Common addon names: `Blizzard_Professions`, `Blizzard_ProfessionsCustomerOrders`, `Blizzard_AuctionHouseUI`, `Blizzard_ChallengesUI`, `Blizzard_Communities`, `Blizzard_GuildUI`, `Blizzard_TradeSkillUI`, `Blizzard_QuestLog`, `Blizzard_Collections`. For non-LoD core UI use `FrameXML/` instead of `Interface/AddOns/`.

Branches: `live` (current retail), `classic`, `classic_era`. Default to `live` for retail addons.

### warcraft.wiki.gg — API reference

For struct fields and C_API signatures:

- **Function**: `https://warcraft.wiki.gg/wiki/API_<FunctionName>` — e.g. `API_C_CraftingOrders.GetCrafterOrders`
- **Struct**:   `https://warcraft.wiki.gg/wiki/Struct_<StructName>` — e.g. `Struct_CraftingOrderInfo`
- **Event**:   `https://warcraft.wiki.gg/wiki/<EVENT_NAME>` — e.g. `CRAFTINGORDERS_UPDATE_ORDER_COUNT`

Wowpedia (`wowpedia.fandom.com`) is a legacy mirror — prefer warcraft.wiki.gg, it's the actively maintained one.

## How to use

### 1. When you know the filename

Fetch raw source directly. **Always include a specific `prompt`** — without it you'll get a generic summary instead of the code you need:

```
WebFetch:
  url: https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_Professions/Blizzard_ProfessionsCrafterOrderPage.lua
  prompt: "Return the full source of ProfessionsCrafterOrderListElementMixin including
           its Init function. List every reference to npcOrderRewards / Rewards /
           RewardsFrame with 5 lines of surrounding context."
```

Prompt patterns that work:

- `Return the full source of <Mixin>` (mixin / function body)
- `List every reference to <symbol>` (cross-reference)
- `What fields are set on self in <Mixin>:Init` (frame children)
- `Show the XML template for <FrameName>` (works for `.xml` files too)

### 2. When you don't know the filename

A direct raw URL returns 404 if the filename is wrong. Browse the tree first:

```
WebFetch:
  url: https://github.com/Gethe/wow-ui-source/tree/live/Interface/AddOns/Blizzard_Professions
  prompt: "List all files whose names contain 'Order' or 'List'."
```

Then fetch the specific file from the returned list.

### 3. When you only know the mixin / template name

Search GitHub for the symbol:

```
WebFetch:
  url: https://github.com/search?q=repo%3AGethe%2Fwow-ui-source+ProfessionsCrafterOrderListElementMixin&type=code
  prompt: "Which file in the repo defines this mixin?"
```

(URL-encode the `:` to `%3A` and spaces to `+`.) Or fall back to `WebSearch` with `wow-ui-source <symbol>`.

### 4. Looking up an API struct or function

```
WebFetch:
  url: https://warcraft.wiki.gg/wiki/Struct_CraftingOrderInfo
  prompt: "List every field of this struct with its type, and call out which fields
           were added recently (e.g. 11.0.0+)."
```

For C_API:

```
WebFetch:
  url: https://warcraft.wiki.gg/wiki/API_C_CraftingOrders.GetCrafterOrders
  prompt: "Show the function signature, parameters, return values, and any usage example."
```

## Pitfalls

1. **Raw URL 404** — usually means wrong path. Don't guess; fetch the `tree/` listing first. Common renames after major patches: a Lua file may get split (e.g. `…Page.lua` + `…ListElement.lua`) or merged.

2. **Vague prompts return summaries, not code.** `WebFetch`'s LLM compression will paraphrase by default. If you need verbatim Lua, say "Return the full source of X" or "Return the code verbatim with no paraphrasing."

3. **`live` vs `mainline` branches** — both exist on the mirror. `live` is current retail; `mainline` may exist as an older alias. Use `live` unless the user is on PTR/Beta.

4. **Don't conflate Crafter vs Customer views.** Two separate UIs with similar names:
   - `Blizzard_Professions/...CrafterOrder*` — the crafter (player fulfilling orders)
   - `Blizzard_ProfessionsCustomerOrders/...` — the customer (player placing orders)
   Pick the one matching the user's screenshot.

5. **XML child names live in `.xml`, not `.lua`.** If you need `self.SomeFrame` references, the `.xml` template defines them. Fetch the matching `.xml` file alongside the `.lua`.

6. **GitHub `tree/` URL may render the file listing in summary form.** If a file is missing from the listing, follow up with a `WebSearch` for `Gethe wow-ui-source <filename>`.

## Worked example

User asks: *"I want to show NPC reward icons on each row of the crafting orders list."*

Step 1 — find the row mixin (don't know the filename):

```
WebFetch tree → list files containing "Order" in Blizzard_Professions
→ returns Blizzard_ProfessionsCrafterOrderPage.lua, ...OrderView.lua, ...
```

Step 2 — fetch the file and extract the mixin:

```
WebFetch raw URL → "Return the full source of ProfessionsCrafterOrderListElementMixin
                    and every reference to Rewards / npcOrderRewards"
→ returns Init(elementData) body showing self.option = elementData.option
```

Step 3 — confirm `npcOrderRewards` is a real field on the option:

```
WebFetch https://warcraft.wiki.gg/wiki/Struct_CraftingOrderInfo
  → "List all fields, especially reward-related ones"
→ confirms npcOrderRewards is CraftingOrderRewardInfo[] with .itemLink / .currencyType / .count
```

Now you have everything needed to write the hook with `hooksecurefunc(ProfessionsCrafterOrderListElementMixin, "Init", ...)` and pull rewards from `self.option.npcOrderRewards`.
