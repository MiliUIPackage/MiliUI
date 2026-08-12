---
name: wow-cell-fork-comm
description: MiliUI 版 Cell 為什麼不廣播 CELL_VERSION，以及哪些 comm 前綴刻意保持互通
metadata: 
  node_type: memory
  type: project
  originSessionId: 705c6fea-a269-43d9-903d-fa81ed5a3e1b
  modified: 2026-08-11T01:13:33.479Z
---

本機的 Cell 是改版(`## Version: rNNN-MiliUI`),而版本號會**因為要開 Revise 遷移閘而在本機自行遞增**(這輪就從 r280 → r281 → r282),所以它**不是上游發布線上的點**。

**問題**:`Comm/Comm.lua` 原本會在入隊(`GROUP_ROSTER_UPDATE`)與登入(`PLAYER_LOGIN`,公會)各廣播一次 `CELL_VERSION` = `Cell.version`。原版 Cell 的接收端只做 `tonumber(string.match(message, "%d+"))` 比大小,所以會把 `r282-MiliUI` 讀成 282 → 每個同公會/同隊的原版使用者都被通知「有新版 r282-MiliUI,去 CurseForge 下載」——**那個版本在上游不存在**。而且這個改版早就把自己**收到**通知的 `F.Print` 註解掉了,等於「自己安靜、吵別人」,方向剛好相反。

**修法(2026-08-11)**:移除兩處 `SendCommMessage("CELL_VERSION", ...)`,**接收端保留**(通知仍是關的)。⚠ `GROUP_ROSTER_UPDATE` 的 handler **不能整個刪掉** —— 它是 `UpdateSendChannel()` 的初始化點,`CELL_MARKS` / `CELL_CPRIO` / `CELL_PRIO` 都靠 `sendChannel` 送。

**刻意保持互通、沒有改的**:`CELL_MARKS`(標記鎖定通知)、`CELL_CPRIO`/`CELL_PRIO`(標記指派優先權協商)、`CELL_REQ`/`CELL_SEND`/`CELL_SEND_PROG`(版面與副本減益的匯入匯出)。這些是功能協作不是版本噪音。

**版面互傳的相容性(查過,雙向都安全)**:
- 原版收到本改版的版面:`raidDebuffs["filters"]` 不會撞到 —— `ResetIndicators` 那行有 `if t["indicatorName"] == "dispels"` 守衛(UnitButton.lua:201),不是無條件吃 `filters`。`debuffs["excludeImportant"]` 原版沒人讀。`["name"] = "Important Debuffs"` 在原版沒有該語系 key,會 fallthrough 印英文,純外觀。
- 本改版收到原版的版面:沒有 `filters` → 「不存在 = 全開」的規則接住;沒有 `excludeImportant` → falsy → 關,對匯入資料而言正確。

相關:[[project-cell-auracontainer-rewrite]]
