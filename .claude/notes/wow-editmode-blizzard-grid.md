---
name: wow-editmode-blizzard-grid
description: 暴雪的編輯模式本來就有格線與吸附；插件不要自己畫，讀它的設定就好
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

**Why:** 2026-08-18 在 MiliUI_UnitFrames 自己畫了一套白格線，跟暴雪的疊在一起，
畫面變成兩套交錯的線 —— 使用者第一眼就看出「格線好亂」。做之前沒查暴雪有沒有。

**How to apply:**
- 格線顯示：**什麼都不用做**，暴雪的面板已經有勾選框與間距滑桿。
- 吸附：`EditModeMagnetismManager` **只服務暴雪自己註冊的系統**。自訂框如果是自己
  用游標差值算拖曳（見 `wow-editmode-draggable` 技能），它管不到，吸附要自己做 ——
  但參數一律讀暴雪的，不要另開一組設定：

```lua
local on = EditModeManagerFrame:IsSnapEnabled()
local step = EditModeManagerFrame:GetAccountSettingValue(
                 Enum.EditModeAccountSetting.GridSpacing)   -- 退路 .Grid.gridSpacing
if IsShiftKeyDown() then on = not on end                    -- 暫時反轉，微調時好用
```

通則：**動編輯模式相關功能之前先查暴雪做了沒。** 這一塊 Blizzard 補得比想像中完整。

相關：[[project-miliui-unit-frame]]
