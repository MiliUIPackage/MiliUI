---
name: project-miliui-uf-visibility-gate
description: MiliUI_UnitFrames 的顯示條件走「閘框」而不是 RegisterStateDriver；藏父層等於藏 secure 子框，戰鬥中合法
metadata: 
  node_type: memory
  type: project
  originSessionId: de450f90-cdd7-4e1f-8c62-1e9716828626
  modified: 2026-08-17T09:42:05.296Z
---

**MiliUI_UnitFrames 的顯示條件（`Core/Visibility.lua`，2026-08-17 加）走「閘框」架構**：
每個單位框上面插一層我們自己建的**普通 Frame**（`uf.visGate`），單位框當它的子物件。

**Why**：單位框是 SecureUnitButton，顯示權已經給 `RegisterUnitWatch`（從安全端 Show/Hide）。
再自己 Show/Hide 就是搶同一個開關。`RegisterStateDriver(frame,"visibility",…)` 也是搶——
要把兩者 AND 起來得寫 secure snippet。閘框天然就是 AND：
**看得到 ＝ 閘框顯示 AND 單位存在**，不需要任何 secure 程式碼。

**How to apply**：
- `gate:SetShown()` 在戰鬥中跑。依據是「保護只管對受保護物件**本身**做 Show/Hide/移動/換父層」，
  藏我們自己建的普通父層不在清單裡。**尚未實測**；萬一錯了，`Core/Init.lua` 的
  `ADDON_ACTION_FORBIDDEN` 攔截器會印出來，不會靜默壞掉。
- ⚠ 閘框藏起來時子物件 `IsVisible()` 是 false ⇒ `ns.Refresh` 的閘門擋掉更新（**這是額外的效能收益**，
  條件生效期間零成本）。但**父層重新顯示時子物件的 OnShow 不會觸發**（它一路都是 Shown），
  所以閘框自己的 OnShow 要補一次全量重畫，否則顯示上一場的舊資料。
- `SetParent` 對 secure 框在戰鬥中不合法 → 只在 spawn 做，且要排在 `ApplyFramePosition` 之前。
- 整框 alpha 收成單一出口 `V.ApplyAlpha`：超出距離淡出（輪詢）與脫戰淡出（吃事件）
  **不可以各自 SetAlpha**，後設的會蓋掉前設的。取兩者最低。

相關：[[project-miliui-unit-frame]]、[[project-miliui-hide-blizzard-taint]]
