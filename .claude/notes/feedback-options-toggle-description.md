---
name: feedback-options-toggle-description
description: "設定介面守則——勾選框（及任何控件）的說明一律放在下一行的灰色小字（Controls 的 type=\"text\"），不要接在勾選框右邊（toggle 的 hint）"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c673872b-1b32-4b21-a0ef-df6779792e87
  modified: 2026-09-24T02:17:38.505Z
---

**設定表單裡，控件的說明一律換行、用灰色小字顯示**：在控件那一列後面接一列
`{ type = "text", label = L["…"] }`（`Libs/MiliUIWidgets/Controls.lua` 的 text 型別，
字型 W.fontSmall、從控件那一欄的 x 開始）。**不要用 toggle 的 `hint`**——那會把說明用白色大字
接在勾選框右邊，看起來像勾選框的標籤。勾選框右邊留空，左欄標籤就是它的名字。

**Why:** 2026-09-24 使用者看 MiliUI_MythicPlus 設定頁時指定（附擷圖，箭頭指著滑桿下方那行灰字：「使用箭頭的樣式，
並換行顯示，不要直接在後面」），接著說「這種說明都以那種格式，放進設定介面設計的守則」。
同一輪也砍掉兩句純說明（「戰鬥中跳出來沒有任何風險」「資訊列也有一顆方塊」）——說明要是玩家做決定用得到的，
講實作細節或推銷別的插件的句子不要放。

**How to apply:**
- 新寫的設定頁：toggle 不帶 `hint`，需要說明就下一列 `type = "text"`。滑桿、按鈕、下拉同理。
- 自己手刻的勾選框（直接 `W.CreateCheckButton(parent, text, …)`）第二個參數也不要塞說明句。
- 改既有插件時順手遷移。2026-09-24 盤點還用 toggle `hint` 的：MiliUI_UnitFrames 9、MiliUI_CharacterNotes 9、
  MiliUI_ShoppingList 7、MiliUI_Merchant 3（MiliUI_MythicPlus 已改完）。機械轉換：
  `{ type = "toggle", …, label = X,\n hint = H },` → `{ type = "toggle", …, label = X },\n{ type = "text", label = H },`。
- 相關：[[project-miliui-options-label-width]]（左欄標籤換行）、[[feedback-ui-visual-style]]、[[project-miliui-widgets-vendor]]。
