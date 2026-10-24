---
name: wow-repopme-release-suppressed
description: RepopMe（釋放靈魂）在遭遇壓制釋放／禁止釋放光環／墜落中是空操作，自動釋放要照暴雪 DEATH 彈窗的三個條件重試，不能固定延遲單發；自我復活選項要看 canUse
metadata:
  node_type: memory
  type: reference
  originSessionId: 706cc04c-088c-485a-a708-ce1a3ded388d
  modified: 2026-10-24T10:21:38.850Z
---

**`RepopMe()` 不保證釋放。** 暴雪自己的死亡彈窗（`Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua` 的
`StaticPopupDialogs["DEATH"]` OnUpdate）在三種情況下會把「釋放靈魂」按鈕停用，這時呼叫 `RepopMe()` 什麼都不會發生、也沒有錯誤：

1. `C_InstanceEncounter.IsEncounterSuppressingRelease()`（12.0 新 API）為真 —— 彈窗文字變「戰鬥中無法釋放」。
   ENCOUNTER_END 送到客戶端跟伺服器解除壓制不是同一刻，`C_Timer.After(0.5, RepopMe)` 這種固定延遲單發常常打在縫裡。
2. `HasNoReleaseAura()` 為真 —— 回 `hasCannotReleaseEffect, longestDuration, hasUntilCancelledDuration`，按鈕變倒數秒數。
3. `IsFalling() and not IsOutOfBounds()`。

**正解是重試不是猜延遲**：事件當下就開始、每 0.1 秒一拍、`UnitIsGhost("player")` 為真就停、撞到上面三個條件就下一拍再試、
送出一發後等 0.5 秒再送、設一個上限（10 秒）。實作見 `MiliUI_QoL/Modules/Encounter_AutoRelease.lua`（烏拉特克 3492，
2026-10-24 改）。這類「原地復活」機制時間窗很短，釋放慢了就落到墓地，所以第一拍不等。

**自我復活選項要看 `canUse`。** `C_DeathInfo.GetSelfResurrectOptions()` 回 `SelfResurrectOption[]`
（`name`／`optionType`／`id`／`canUse`／`isLimited`／`priority`），冷卻中的靈魂石／復生**也會列出來**，只是 `canUse=false`；
暴雪用 `GameDialogDefsUtil.GetSelfResurrectDialogOptions` 依 canUse 排序再 `SetEnabled(option.canUse)`。
用 `#opts > 0` 當「有自我復活」會害這些人永遠不被自動釋放。

12.1 文件：`UnitIsDead`／`UnitIsGhost`／`UnitIsDeadOrGhost`／`HasNoReleaseAura`／`IsEncounterSuppressingRelease`／
`GetSelfResurrectOptions` 都只有 `SecretArguments = "AllowedWhenUntainted"`，回傳沒有秘密旗標，可以直接放 `if`。

參考：DreamForgeTools 的 UlatekAutoRelease（`Interface/tmp/DreamForgeTools/modules/UlatekAutoRelease/init.lua`）也是 0.5 秒單發，
同樣不穩，別當範本。相關：[[wow-121-unit-api-secrets]]、[[project-miliui-qol]]
