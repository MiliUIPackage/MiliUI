---
name: project_cell_libgroupinfo_secret_guid
description: Cell LibGroupInfo 秘密 GUID 當 table key 報錯的就地修補，Cell 更新後要重套
metadata: 
  node_type: memory
  type: project
  originSessionId: 34c1f959-c41c-4970-8f33-d14dce684914
---

Cell `Libs/LibGroupInfo.lua` 在 Midnight 12.0+ 會遇到**秘密 GUID**：競技場/敵對單位（如 `arena1`）的 `UnitGUID()` 回傳秘密字串，拿去當 `cache[guid]`／`queueGUIDs[guid]` 的 key 就炸（`attempted to index a table that cannot be indexed with secret keys`）。

**修法**：檔案頂部（約 30 行）已有 file-scope 的 `IsValueSecret(val)` helper（cache 住 `issecretvalue`，維持函式庫獨立性，不依賴 Cell 的 `F.IsValueNonSecret`）。在以下入口各加 `if not guid or IsValueSecret(guid) then return end`：

- `frame:PLAYER_SPECIALIZATION_CHANGED`（約 585 行，`UNIT_NAME_UPDATE` 也走這裡）— 2026-07 arena1 觸發的那次
- `frame:UNIT_LEVEL`（約 611 行）— 之前修 nameplate GUID
- 公開 API `lib:GetCachedInfo` / `lib:GuidToUnit`（約 63-71 行）— 防外部傳入秘密 GUID

其他 `UnitGUID` 呼叫點（`IterateAllUnits`、`BuildAndNotify`）只跑 party/raid 友方單位，GUID 不會是秘密值，不用擋。

**Why**：上游還沒把秘密值適配補到這個 lib。**How to apply**：Cell 更新覆蓋後若上游沒修要重套，helper + 各 guard 都要。同類修補見 [[project_cell_vehicle_secret]]。
