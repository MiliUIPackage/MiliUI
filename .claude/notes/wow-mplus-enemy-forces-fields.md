---
name: wow-mplus-enemy-forces-fields
description: M+ 敵軍進度的 criteria 欄位語意是反直覺的——quantity 已經是百分比、quantityString 才是絕對數量（還帶假的 % 號）
metadata: 
  node_type: memory
  type: reference
  originSessionId: a88008ec-3103-49f6-be1c-e722fd941f67
  modified: 2026-09-05T14:10:48.976Z
---

`C_ScenarioInfo.GetCriteriaInfo(i)` 在 `isWeightedProgress`（M+ 敵方部隊）那一條上，
三個欄位的語意跟名字對不起來：

| 欄位 | 實際內容 | 例 |
|---|---|---|
| `totalQuantity` | **絕對總量** | `686` |
| `quantityString` | **目前的絕對數量**，但後面帶一個**假的百分比符號** | `"686%"` |
| `quantity` | **已經是百分比**（0–100） | `100` |

所以 `quantity / totalQuantity` 是「百分比 ÷ 絕對總量」，算出來沒有意義。
指紋：**敵軍滿了顯示 14.58%**（= 100/686），而且完成判定 `cur >= total` 永遠碰不到，
所以條也不會轉綠、不會有完成時間。曾經在 MiliUI_QuestTracker 的鑰石面板上踩過
（2026-09-05 修，[[project-miliui-questtracker]]）。

**正確的兩種算法**（不要混用）：

- 兩個都用絕對值：`tonumber(quantityString:match("%d+")) / totalQuantity`
  —— 有小數點兩位的精度，玩家習慣看的就是這種。
- 或直接用 `quantity` 當百分比 —— 只有整數精度。暴雪自己的追蹤器走這條：
  `ScenarioTrackerProgressBarMixin:SetValue(criteriaInfo.quantity)` 直接把它
  丟進 `PERCENTAGE_STRING` 格式化（見 `Blizzard_ScenarioObjectiveTracker.lua`）。

**完成判定看 `completed` 旗標**，別靠數量比大小 —— 暴雪自己也是用它決定要不要
把進度條收成打勾（`if criteriaInfo.isWeightedProgress and not criteriaInfo.completed then
AddProgressBar(...)`）。數量比對留著當 12.1 秘密值下的備援就好，見 [[wow-121-secret-values]]。

⚠ 讀 `quantityString` 要先過 `IsSecret`；`quantity` 要過 `Num()`。兩條都拿不到時
才把原字串丟給 `SetText`（傳遞者不是讀取者）。
