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
