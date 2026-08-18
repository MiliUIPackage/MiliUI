---
name: project-miliui-uf-comment-attribution
description: MiliUI_UnitFrames 的註解不點名 Cell/Stuf/Danders，但複製來的檔案與致謝區塊的出處要保留
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0667fdac-ad7b-4957-92aa-1465a01c4c3c
  modified: 2026-08-16T18:48:40.669Z
---

在 `AddOns/MiliUI_UnitFrames/` 寫註解時**不要點名第三方插件**（Cell、Stuf、DandersFrames）。
2026-08-17 已把 63 處「照 Cell 的手法」「Stuf 語意」「移植自 Stuf/text.lua」之類的字樣清掉，
技術內容照留、只拿掉插件名。新寫的註解不要再加回去。

**兩個例外（使用者定案要保留）**：
1. **實際複製過來的檔案**要留出處註解 —— `Libs/PixelPerfect.lua`（取自 Cell/Libs/PixelPerfect.lua）、
   `Core/Media.lua` 與 `Elements/Health.lua` 提到的四張疊加層貼圖（原封不動從 Cell/Media 複製）。
2. **`Options/Panel.lua` 關於頁的「致謝」區塊**（點名 Cell / Stuf 與作者 enderneko、Kato）。

**Why**：`Cell/LICENSE.txt` 是 all rights reserved，只授權私人使用的修改、沒有再散布的權利，
而 MiliUI repo 是公開的、玩家整包 clone。那些檔案已經在 repo 裡了，把出處註解拿掉不會讓檔案消失，
只會讓「這是複製的」變成沒揭露 —— 所以刪註解的方向反而更糟。要根治只能換掉檔案本身
（貼圖重畫或改用暴雪內建、PixelPerfect 自己寫一份），使用者目前選擇維持現狀。

**How to apply**：清理或新寫註解時，把「參考誰的手法」改寫成單純描述做法；碰到上面那兩類
就原封不動。`Platynator` 不在移除名單內（使用者只指名 Cell / Stuf / Danders）。

相關：[[project-miliui-unit-frame]]、[[project-local-addon-forks]]
