---
name: wow-uispecialframes-login-closed
description: 登記在 UISpecialFrames 的彈窗在 PLAYER_LOGIN 開會被暴雪的 CloseAllWindows 收掉，玩家看不到也不會再出現
metadata:
  node_type: memory
  type: reference
  originSessionId: 2937557c-3060-4cda-9dce-d5911a832548
  modified: 2026-10-01T04:44:09.276Z
---

登記進 `UISpecialFrames`（按 ESC 關；共用層 `W.CloseOnEscape`、`W.CreateChoicePopup`、`W.CreateConfirmPopup` 都會登記）的框，會被暴雪的 `CloseAllWindows` → `CloseSpecialWindows` 一次 Hide 掉。這個函式在登入過程中不只一個觸發點：`UIParent` 的 OnShow（`UI.TopLevelParentShown`）、`PLAYER_CONTROL_LOST`（`CloseAllWindows_WithExceptions`）、開全螢幕面板。

症狀：`PLAYER_LOGIN` 開的彈窗玩家從沒看過，用指令手動再開卻正常。2026-10-01 MiliUI_CooldownManager 的「Ayije_CDM 衝突二選一」就是這樣，兩支同時開著卻沒有任何提示。

**How to apply:** 登入時就要給玩家看、而且一定要做決定的彈窗，不要登記進 UISpecialFrames（自己建，不用共用層的 popup），也就不給 ESC 關。一般的設定視窗彈窗照用共用層沒問題。

## 開暴雪面板也會收掉（2026-10-01）

`ShowUIPanel` 開 area＝center／full 的面板（天賦／法術書 PlayerSpellsFrame、全螢幕地圖）時會走 `CloseWindows` → `CloseSpecialWindows`，跟 ESC 同一支 —— 所以登記在表裡的設定視窗「一開天賦就被關」。共用層 `W.CloseOnEscape(frame)` 現在預設**換面板不關**：子框 OnHide 記時間、後掛勾 `CloseSpecialWindows` 標記同一幀被收掉的、後掛勾 `ShowUIPanel` 同一幀叫回；ESC 不經過 ShowUIPanel 照常關。選單類傳 `closeWithPanels=true` 維持舊行為。別改成自己 EnableKeyboard 抓 ESC（見 [[wow-keyboard-capture-blocks-bindings]]），也別用 `RegisterGameMenuEscHandler`：Blizzard_GameMenuEsc 讀 handlers 表沒包 securecall，插件登記會污染 ToggleGameMenu。寫這段時只有 MiliUI_CooldownManager 的主視窗改走（（2026-10-09 體檢）已 8 支插件 17 處走 `W.CloseOnEscape`，直接 `tinsert(UISpecialFrames` 仍有 39 處） W.CloseOnEscape，其他十幾支設定視窗還是直接 `tinsert(UISpecialFrames, …)`。
