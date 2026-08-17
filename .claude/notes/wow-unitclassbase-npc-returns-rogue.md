---
name: wow-unitclassbase-npc-returns-rogue
description: UnitClassBase 對非玩家回一個合法但無意義的職業 token（術士惡魔僕從回 ROGUE），會讓職業色查表命中錯的顏色
metadata: 
  node_type: memory
  type: reference
  originSessionId: de450f90-cdd7-4e1f-8c62-1e9716828626
  modified: 2026-08-17T19:27:51.395Z
---

`UnitClassBase(unit)` 對**非玩家**（寵物、載具、NPC）不會回 nil，而是回一個
**看起來完全合法、實際上沒有意義**的職業 token。實測：術士的惡魔僕從回 `"ROGUE"`。

危險在於它是合法的 key：`RAID_CLASS_COLORS["ROGUE"]` = rgb 255,244,104，所以
「查得到就用」的職業色寫法會靜默塗上盜賊黃，看起來像「顏色調錯了」而不是「資料錯了」。

```lua
-- 錯：非玩家會命中一個假的職業色
local c = RAID_CLASS_COLORS[UnitClassBase(unit)]

-- 對：先用 UnitIsPlayer 閘掉
local classFile = ToBool(UnitIsPlayer(unit)) and UnitClassBase(unit) or nil
```

同一家族的兄弟（見 [[wow-unitclass-npc-returns-name]]）：**`UnitClass` 對非玩家回的是
單位的名字**。所以「職業／種族」這一整組欄位都只對真玩家有意義，消毒層就要閘掉，
不要留給每個使用點各自處理 —— 漏一個就是一個靜默的錯顏色。

**寵物要顯示什麼顏色**：主人的職業色（Cell 同法）。owner 沒有 API 可查，只認得
「主人一定是玩家自己」的情況：`baseUnit == "pet"`、unit 是 `pet`/`vehicle`、
或明文確定 `UnitIsUnit(unit, "pet")`。別人的寵物查不到主人，不要瞎猜。

⚠ 補上 owner 備援還不夠 —— 如果 `classFile` 那條分支排在前面而且會 `return`，
備援永遠走不到。這個 bug 就是這樣多花一輪才修對的。

2026-08-18 在 MiliUI_UnitFrames 抓到（`Core/Cache.lua` 的 UpdateNameFields）。
相關：[[project-miliui-unit-frame]]
