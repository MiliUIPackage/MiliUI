---
name: project-cell-vehicle-secret
description: Cell 載具名稱位置在 Midnight 秘密值下報錯的就地修補，Cell 更新後要重套
metadata: 
  node_type: memory
  type: project
  originSessionId: 5ee50ba9-ecdf-4703-b8a2-6c8497ecf5c3
---

Cell `Indicators/Built-in.lua` 的 `nameText:SetPoint` override（約 1147 行）會 `nameText.vehicle:GetPoint(1)` 取回錨點字串 `vp`，再 `string.find(vp,"TOP")`／字串相接做載具名稱的上下翻轉。Midnight 12.0 下 `GetPoint` 可能回傳**秘密字串**，對它做字串操作就炸（`attempt to perform string conversion on a secret string value, tainted by 'Cell'`，CellNPCFrameButton 處）。

**修法**：在那個 `if vp and vrp and vy then` 加上 `and F.IsValueNonSecret(vp) and F.IsValueNonSecret(vrp)`，秘密時直接跳過翻轉（純美觀、只有載具狀態才會跑到）。這正是 Cell 自己在同檔 1223 行擋 `SetSize` 用的同一個 helper（`F.IsValueNonSecret`，定義在 `Utils.lua:2604`，底層是 `issecretvalue`）。

**Why**：Cell r276-beta 已在做秘密值適配但漏了這一處。**How to apply**：Cell 更新覆蓋後若上游沒修要重套。相關秘密值/污染概念見 [[project-tinytooltip-perf]]、[[project-charframe-taint]]。
