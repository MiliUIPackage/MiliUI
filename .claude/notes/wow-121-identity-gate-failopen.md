---
name: wow-121-identity-gate-failopen
description: 12.1 AuraContainer 的 includeSpellIDs 白名單在 UnitCanAssist 失敗時整組跳過（fail-open），顯示全部增益且不會自己恢復
metadata: 
  node_type: memory
  type: reference
  originSessionId: ecf43e09-8c1d-426c-b1ad-ffcf37466b77
  modified: 2026-08-13T05:39:02.971Z
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

機制由 DandersFrames v5 找出（`Frames/AuraContainer.lua:662` `filterVulnerableToIdentityGate`）。
Cell 的對應實作與 `/cab gate` 解卡指令見 [[project-cell-auracontainer-rewrite]]，
API 細節見 [[wow-121-aura-containers]]。
