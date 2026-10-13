---
name: wow-editmode-blizzard-grid
description: 暴雪的編輯模式本來就有格線與吸附；插件不要自己畫，讀它的設定就好；判斷暴雪格線「看得到」要問 Grid:IsVisible() 不是 IsShown()（旗標在編輯模式外也是 true）
metadata:
  type: reference
---

**編輯模式的格線是暴雪內建的，不要自己畫。**
`Blizzard_EditMode/Shared/EditModeManager.lua`：

| 東西 | 位置 |
|---|---|
| 格線本體 | `EditModeGridMixin`（`EditModeGridLineTemplate` 線池，從螢幕中心往外畫） |
| 顯示開關 | `EditModeManagerFrame:SetGridShown()` ← `Enum.EditModeAccountSetting.ShowGrid` |
| 間距滑桿 | `EditModeGridSpacingSliderMixin` ← `Enum.EditModeAccountSetting.GridSpacing` |
| 吸附開關 | `EditModeManagerFrame:IsSnapEnabled()` ← `Enum.EditModeAccountSetting.EnableSnap` |
| 吸附引擎 | `EditModeMagnetismManager:RegisterGrid(grid:GetCenter())` |

**Why:** 2026-08-18 在 MiliUI_UnitFrames 自己畫了一套白格線，跟暴雪的疊在一起，畫面變成兩套交錯的線——使用者第一眼就看出「格線好亂」。做之前沒查暴雪有沒有。

**How to apply:**
- 編輯模式裡的格線顯示：**什麼都不用做**，暴雪的面板已經有勾選框與間距滑桿。
- 吸附：`EditModeMagnetismManager` **只服務暴雪自己註冊的系統**。自訂框如果是自己用游標差值算拖曳（見 `wow-editmode-draggable` 技能），它管不到，吸附要自己做——但參數一律讀暴雪的，不要另開一組設定：

```lua
local on = EditModeManagerFrame:IsSnapEnabled()
local step = EditModeManagerFrame:GetAccountSettingValue(
                 Enum.EditModeAccountSetting.GridSpacing)   -- 退路 .Grid.gridSpacing
if IsShiftKeyDown() then on = not on end                    -- 暫時反轉，微調時好用
```

通則：**動編輯模式相關功能之前先查暴雪做了沒。** 這一塊 Blizzard 補得比想像中完整。

## 設定視窗開著（不在編輯模式）就能拖的插件：共用層格線開關

這種情境暴雪的格線不會出現（它只在編輯模式畫），所以 2026-10-05 共用層加了 `W.CreateGridToggle`（[[project-miliui-widgets-vendor]]）：
畫法照暴雪（畫面中心往外、中心兩條職業色），**全套組共用一張 `_G.MiliUIWidgetsGridOverlay1`**（兩支插件同時開不會疊兩套線），
暴雪編輯模式的格線看得到時整張讓位（0.2 秒輪詢一次）。吸附原點用 `UIParent:GetCenter()` 就對得上暴雪的。

⚠ **判斷暴雪格線「看得到」要問 `Grid:IsVisible()`，不是 `IsShown()`。** 玩家勾過「顯示格線」，暴雪載入設定時就 `Grid:SetShown(true)`，
沒進編輯模式時旗標照樣是 true（只是父框藏著）。第一版拿 IsShown 判「暴雪格線在 ⇒ 讓位」，結果永遠讓位、一條線都不畫（症狀：按鈕有、格線沒有）。
通則：「某個暴雪框現在畫在畫面上嗎」一律問 `IsVisible`，`IsShown` 只是它自己的旗標。

相關：[[project-miliui-unit-frame]]、[[wow-editmode-setpoint-hook-saves-our-name]]
