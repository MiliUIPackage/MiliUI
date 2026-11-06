---
name: feedback-preview-shares-real-paint-code
description: 設定頁的預覽／樣本要呼叫畫面上那個元件用的同一批繪製函式，不另寫一份——使用者要拿預覽順便檢查樣式與上色有沒有錯
metadata:
  type: feedback
---

設定頁裡的預覽（樣本條、樣本圖示之類）**上色、發光、文字、狀態畫面要走實際元件的同一批函式**，樣本只負責餵明文的假狀態；不要在預覽裡照著重寫一份。

**Why:** 2026-11-06 做 MCDM 專注目標施法條的內嵌預覽時，使用者中途補一句：「留意這些樣式的套用方式和實際要一樣，這樣我順便能看樣式或上色有無錯誤。」——預覽對他來說同時是檢查工具，重寫一份的預覽永遠是對的、看不出實際那條有沒有套錯。

**How to apply:** 把實際元件的繪製函式改成收目標物件（`PaintXxxOn(h, …)`，原函式變一行包裝 `PaintXxxOn(f, S…)`），預覽建自己的一份零件再叫同一批；版面能共用就共用（MCDM 專注目標施法條的 `BuildParts／LayoutParts`）。連帶的後果要接受並寫進說明：設定關著的效果預覽也不畫（我的判斷：預覽按鈕壓暗提示，而不是強制顯示）。實作見 [[project-miliui-cooldownmanager]] 的 `CB.CreateSample`／`FC.CreateSample` 與 `Tests/CastbarSample_test.lua`（假的框把樣本建出來跑一輪——進不了遊戲時抓改寫錯誤很有用）。
