---
name: wow-editmode-custom-setting-row
description: 在暴雪編輯模式的設定視窗裡多掛一條自己的設定列；三個非做不可的細節
metadata:
  type: reference
---

暴雪的系統設定是 C 端列舉（`Enum.EditMode<系統>Setting`），版面又是它自己存的
（`C_EditMode.SaveLayouts`）—— **塞一個它不認得的 setting id 進去只會被丟掉或弄壞整份
版面**。要加設定就是「介面借它的、值自己存」：把一個自己的框掛進
`EditModeSystemSettingsDialog.Settings`。

**How to apply（`MiliUI/Enhance/EditMode_BagsAlpha.lua` 是現成範例）：**

1. `Settings` 是 `VerticalLayoutFrame`：自己的列給 `layoutIndex`（暴雪那幾條是 1..N，
   取 100 就排在後面），Show/Hide 決定參不參與排版，**不用自己 SetPoint**
   （`VerticalLayoutMixin:LayoutChildren` 會 `ClearAllPoints` 再錨）。
   ⚠ layoutIndex 撞號會被 `LayoutIndexComparator` 拋 GMError。
2. `hooksecurefunc(EditModeSystemSettingsDialog, "UpdateSettings", ...)`，先擋
   `systemFrame ~= dialog.attachedToSystem`，再依 `systemFrame == 目標系統` 決定
   Show/Hide，**最後補一次 `dialog.Settings:Layout()`** —— 暴雪在 UpdateSettings
   中段就 Layout 過了，那時我們的列還沒 Show、它自己那幾條的高度也還沒定
   （高度在後面的 `SetupSetting` 才設），不補這一下視窗會少一列的高度。
3. **不要重用 `EditModeSettingSliderTemplate`**：那個 mixin 在 OnLoad 就把值變更
   接到 `EditModeSystemSettingsDialog:OnSettingValueChanged`（→ 存一個不存在的
   setting），而回呼是 OnLoad 當下綁死的，事後覆寫方法攔不掉。自己拼一份同外觀的：
   `GameFontHighlightMedium` 標籤（100x32）＋ `MinimalSliderWithSteppersTemplate`
   （200 寬），整列 343x32，寬度就跟暴雪那幾條一致。
   `slider:Init(value, min, max, steps, formatters)`，`steps = (max-min)/級距`；
   `formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = fn }`。
   CallbackRegistry 的 function 型回呼叫成 `func(owner, value)`。
   ⚠ `Init` 裡的 `SetValue` 跑在舊的 OnValueChanged 腳本還掛著的時候，要學暴雪
   用 `initInProgress` 擋一下，不然會把上一次的值寫回 DB。

**用透明度藏東西的兩個要點：**

- `SetAlpha` 不是保護函式，戰鬥中對保護框照樣能改，而且 alpha 0 的框仍然吃滑鼠
  （看不見但按得到）—— 這是 `Hide()` 做不到的（保護框戰鬥中 Hide 會被擋）。
- ⚠ **選取框要 `Selection:SetIgnoreParentAlpha(true)`**。`EditModeSystemMixin` 的
  `self.Selection` 是子框，會跟著父層一起透明；alpha 調到 0 之後下次進編輯模式
  就看不到那條列，點不到＝再也叫不出設定，等於把設定鎖死。

相關：[[wow-editmode-blizzard-grid]]、[[project-miliui-perf-tab]]
