---
name: project-miliui-uf-visibility-gate
description: MiliUI_UnitFrames 的顯示條件走「閘框」而不是 RegisterStateDriver；⚠ 藏父層在戰鬥中會被擋（隱式保護往上傳），2026-09-06 實測推翻原假設
metadata: 
  node_type: memory
  type: project
  originSessionId: de450f90-cdd7-4e1f-8c62-1e9716828626
  modified: 2026-09-06T00:00:00.000Z
---

**MiliUI_UnitFrames 的顯示條件（`Core/Visibility.lua`，2026-08-17 加）走「閘框」架構**：
每個單位框上面插一層我們自己建的**普通 Frame**（`uf.visGate`），單位框當它的子物件。

**Why**：單位框是 SecureUnitButton，顯示權已經給 `RegisterUnitWatch`（從安全端 Show/Hide）。
再自己 Show/Hide 就是搶同一個開關。`RegisterStateDriver(frame,"visibility",…)` 也是搶——
要把兩者 AND 起來得寫 secure snippet。閘框天然就是 AND：
**看得到 ＝ 閘框顯示 AND 單位存在**，不需要任何 secure 程式碼。

**How to apply**：
- ⚠⚠ **`gate:SetShown()` 在戰鬥中會被擋 —— 2026-09-06 由 taint.log 實測推翻原本的假設。**
  原本推論是「保護只管對受保護物件**本身**做 Show/Hide/移動/換父層」，藏我們自己建的
  普通父層不在清單裡。錯了：**隱式保護會往上傳**，閘框底下掛著 SecureUnitButton，
  藏父層就等於藏那顆受保護的子物件。證據：
  `An action was blocked in combat because of taint from MiliUI_UnitFrames - Frame:SetShown()`
  × 11（一次戰鬥中的 `PLAYER_ENTERING_WORLD` × 11 個框）。同一條規則在
  [[wow-combat-drag-release]] 的拖曳那邊也踩過，那時就該推廣過來。
- 現在的寫法（`V.Apply`）是兩段：**狀態沒變就一個 API 都不叫**（`SetShown` 對已經是
  那個狀態的框仍然算一次保護動作，那 11 筆全是這種空轉），戰鬥中真要改就記
  `uf.visPending`、`V.FlushPending()` 在 `PLAYER_REGEN_ENABLED` 補做。
- ⚠ **代價：戰鬥中條件不生效。** `inCombat` 模式因此形同「戰鬥結束才出現」。要在戰鬥中
  換顯示狀態，唯一的路是把判斷交給安全端（巨集條件 ＋ `RegisterStateDriver`）——
  污染過的 Lua 沒有任何寫法做得到，那正是保護機制要擋的事。可行的架構是**兩層閘框**：
  外層由 state driver 驅動（`[combat]`／`[nocombat]`／`[group]`／`[group:party]`／
  `[group:raid]`／`[nogroup]`／`[@target,exists]`／`[@target,harm]` 都表達得出來），
  內層留給表達不出來的那幾個（副本類型、德魯伊旅行型態），巢狀天然就是 AND。
  尚未實作。
- ⚠ 閘框藏起來時子物件 `IsVisible()` 是 false ⇒ `ns.Refresh` 的閘門擋掉更新（**這是額外的效能收益**，
  條件生效期間零成本）。但**父層重新顯示時子物件的 OnShow 不會觸發**（它一路都是 Shown），
  所以閘框自己的 OnShow 要補一次全量重畫，否則顯示上一場的舊資料。
- `SetParent` 對 secure 框在戰鬥中不合法 → 只在 spawn 做，且要排在 `ApplyFramePosition` 之前。
- 整框 alpha 收成單一出口 `V.ApplyAlpha`：超出距離淡出（輪詢）與脫戰淡出（吃事件）
  **不可以各自 SetAlpha**，後設的會蓋掉前設的。取兩者最低。

相關：[[project-miliui-unit-frame]]、[[project-miliui-hide-blizzard-taint]]
