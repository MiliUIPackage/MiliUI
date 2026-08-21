---
name: wow-121-identity-gate-failopen
description: 12.1 AuraContainer 的 includeSpellIDs 白名單在 UnitCanAssist 失敗時整組跳過（fail-open），顯示全部增益且不會自己恢復
metadata: 
  node_type: memory
  type: reference
  originSessionId: ecf43e09-8c1d-426c-b1ad-ffcf37466b77
  modified: 2026-08-15T15:55:09.064Z
---

12.1 的 `candidateFilters.include/excludeSpellIDs` 只在 `CanApplyIdentityCandidateFilters` 內
被採用，HELPFUL 那條要求 `UnitCanAssist("player", unit)`。**檢查沒過 = 整組跳過 ID 過濾（fail-open）**，
於是「白名單 buff 列」顯示**全部增益**——不報錯、filter 字串正確、診斷仍印 `+cf{includeSpellIDs}`。

assist 變 false 的場合：跨陣營隊友（副本外）、決鬥對手、**過場動畫期間**（會發 `UNIT_FACTION`，
12.1 首次登入強制播一段 → 「PTR 正常、上線就壞」的真正原因）。`HELPFUL|PLAYER` 沒有豁免。

**⚠ assist 恢復後引擎不會重新解析**（只有光環變動才重讀），fail-open 結果會一直留著 ——
所以只有 `/reload` 有效。要恢復必須自己踢：OOC `container:Hide(); container:Show()`，
戰鬥中只能 `UpdateAllAuras()` 標記、離開戰鬥補踢。

第二條 fail-open：來源相關 pool（`HELPFUL|PLAYER`、`isFromPlayerOrPlayerPet`）對不在可見世界的
單位（不同副本/分流）無法歸屬施法者 → 「我的」放行所有人，assist 仍是 true，訊號改看 `UnitIsVisible`。

**第三條：離線**（2026-08-21，使用者實測回報）。隊友一斷線，`UnitCanAssist` **仍然是 true**
（陣營沒變），所以第一條的閘完全不會動，但引擎已經解析不出這個單位，`includeSpellIDs`
照樣被整組跳過 → 那個人的白名單列填滿他掉線當下身上的所有 buff。這是實際最常撞到的一條
（副本打到一半有人掉線）。訊號是 `UnitIsConnected`。
⚠ **事件跟檢查一樣重要**：掉線瞬間只有 `UNIT_CONNECTION` 會發，`GROUP_ROSTER_UPDATE`
不一定跟著來 —— 沒監看它的話，那列會一直錯到某個不相干的事件剛好掃到為止
（使用者原話：「離線的玩家一開始光環的過濾也會失效」，「一開始」就是這個時間差）。
Cell 的三個檢查都在 `Handle:ApplyIdentityGate`，順序是 connected → assist → visible。

機制由 DandersFrames v5 找出（`Frames/AuraContainer.lua:662` `filterVulnerableToIdentityGate`）。
Cell 的對應實作與 `/cab gate` 解卡指令見 [[project-cell-auracontainer-rewrite]]，
API 細節見 [[wow-121-aura-containers]]。

## 失效方向開關 GATE_FAIL_CLOSED（2026-08-15，使用者要求）

`AuraDisplay.lua` 頂端模組常數，控制 fail-open 抓到 vulnerable 列時的方向：
- **SHOW（false，原設計）**：有疑慮就顯示，自己的列刻意保持顯示、過場 3 秒後 fallback
  `UnlatchAll(false)` 把還鎖著的全放出來。→ 過場久了/傳送後白名單列全顯（使用者嫌煩）。
- **HIDE（true，現值）**：確定 fail-open 就一顆都不畫。動兩處：`ApplyIdentityGate` 的兩個
  `if not can/vis and (not isOwn or GATE_FAIL_CLOSED)`（自己的列也藏）、過場 fallback 改成
  `C_Timer.After(3, Sweep)` 重探而非強制顯示。

⚠ **只翻「確定 fail-open」**（非 secret 的確定 false + 過場 latch）。真正不確定（secret value、
pcall 失敗、無單位）**仍走 SHOW** —— 否則正常戰鬥中光環變 secret 時會把整列誤藏。恢復路徑
不變（assist/visible 回來的邊緣觸發 `GateRefresh` bounce），所以 HIDE 會自己好，代價只是誤判
那一瞬間列會閃一下不見。`/cab inspect` 身分閘行尾印「失效方向」可確認目前模式。翻回舊行為改
常數為 false。
