---
name: wow-unitclass-npc-returns-name
description: UnitRace 對非玩家單位回 nil、UnitClass 回的是「單位名字」，種族/職業欄要先用 UnitIsPlayer 閘掉
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1c4053d2-0bf5-47a0-b612-8c4a21559dcf
  modified: 2026-08-16T20:39:58.672Z
---

**`UnitIsPlayer` 為 false 的單位（寵物、載具、被控生物、圖騰）：**

- `UnitRace(unit)` → `nil`
- `UnitClass(unit)` → 第一個回傳值是**該單位的名字**，不是職業

所以「種族＋職業」這種文字欄位不能只判斷 `UnitPlayerControlled`（寵物是 true），
會在職業欄印出寵物名字。要用 `UnitIsPlayer` 分流，非玩家改走 `UnitCreatureType`。

MiliUI_UnitFrames 的作法：`cache.isPlayer`（真玩家，tag 條件 `pc`/`npc` 用）
與 `cache.pc`（player-controlled，染色用）拆成兩個欄位。

**連帶教訓**：秘密值管線用 `\001N` 佔位符時，取值可能是 `nil`。回填階段若沒把
「登記過但值是 nil」的索引整組吃掉，控制字元會原樣進 FontString，畫面上顯示成
`□1` 這種內部編號。見 [[wow-121-secret-values]]、[[wow-121-unit-api-secrets]]。
