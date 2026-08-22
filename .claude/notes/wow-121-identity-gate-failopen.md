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

⚠⚠ **離線這條的守備範圍比前兩條大**（2026-08-21 第二次回報才發現）：前兩條只影響
**HELPFUL** pool，離線是**整包 candidateFilters 都不套用**，所以 HARMFUL 的列一樣中招 ——
- 減益排的黑名單走 `excludeSpellIDs` → 鬼魂／正在復活／疲勞全冒出來
  （離線的人通常是死的，第一個看到的就是鬼魂）；
- 「上面那列已經認領」的減法是 candidateFilter 布林（`isBossOrRoleAura=false`、
  `isPriorityAura=false`）→ 同一顆減益同時畫在中央重要減益和減益排。
Cell 因此有第三個旗標 `_gateCFDependent`（`RecordUsesCandidateFilters`：只要 record 帶
任何 candidateFilters 就算），**只餵給 connected 這條訊號**。純 filter 字串的列
（驅散圖示、血條 overlay）不帶 cf，離線時照常運作。
判斷「哪一列出問題」的現場依據：**紅圈＝HARMFUL、綠圈＝HELPFUL**，配 `/cab inspect <unit>`
的身分閘行（有印 `cf依賴=` 與 `connected=`）。

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


## 跨陣營隊友（2026-08-22，使用者回報 → 待實測確認）

隊友是聯盟、自己是部落，也會 filter 失效。處理方向跟離線一致：**凡是依賴 candidateFilters
的列一律不顯示**（使用者拍板：寧可空的也不要錯的）。`ApplyIdentityGate` 動兩處：

- **第 (2) 條 assist 的守備範圍擴大**：`_gateVulnerable` → `_gateVulnerable or _gateCFDependent`。
  理由跟離線同一條 —— 引擎解不出身分就整包 candidateFilters 不套用，HARMFUL 的列
  （減益排的 `excludeSpellIDs` 黑名單、「上面那列已認領」的布林減法）一樣中招。
- **新增第 (2b) 條：陣營不同**（`UnitFactionGroup("player")` vs 單位）當獨立訊號。
  理由是 `UnitCanAssist` 對「補得到血的隊友」很可能回 **true**（跨陣營組隊本來就能互補），
  那 (2) 就永遠不會動 —— 陣營不同是確定、不會 secret 的答案，直接當訊號比較穩。
  - ⚠ **副本內豁免**（`IsInInstance()`）：跨陣營鑰石/團隊是官方支援的玩法，為了這個把
    整場的白名單列都藏掉會比原本的 bug 更糟。**只管開放世界。**
  - ⚠ **恢復邊緣要含「變成無法回答」**：走進副本 → 這條分支整個跳過，但容器裡還留著
    開放世界那次 fail-open 的解析，而進副本不是光環變動、沒有任何東西會踢它。
    所以 `was == false and same ~= false`（不是 `and same`）才算恢復。
  - Neutral（未選陣營的熊貓人）算「沒答案」，不是不同陣營。

`/cab inspect <unit>` 身分閘那行多印 `同陣營=`（nil＝這條沒答案，副本內/中立/secret 都是）。
**還沒現場驗證的是哪一條真正生效**：若 inspect 印 `assist=false` 就是 (2) 抓到，
印 `assist=true 同陣營=false` 就是 (2b) 抓到 —— 後者代表「跨陣營＝assist 仍為 true」，
那上面「跨陣營隊友（副本外）assist 會 false」的舊說法要改。
