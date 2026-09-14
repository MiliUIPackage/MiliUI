---
name: project-miliui-options-label-width
description: 自製設定介面的左欄標籤只有 128px／13 字級一行——繁中約 9 字、歐語約 17 字；超過就被截成「…」，新增標籤前先量
metadata: 
  node_type: memory
  type: project
  originSessionId: addcc014-9fae-4a81-850b-5817cce9d912
  modified: 2026-09-14T19:11:48.076Z
---

`Libs/MiliUIWidgets/Controls.lua` 的表單左欄 `LABEL_W = 128`、字級 13，toggle／color 列高 26
**只容一行**，超過就截成「…」（slider／dropdown 列高 30，也別指望換行）。
2026-09-15 使用者截圖：「溢盾光暈改放條的起點那端」（12 字、156px）被截成「溢盾光暈改放條的…」。

**量法**（Pillow，腳本很短，別憑感覺數字數）：
- 中韓：`Fonts/bLEI00D.ttf` 13px `getlength`（面板字型就是 `Media.Font` 的在地化預設，套組把這個檔換成思源黑體）。
  實測 9 個中文字 117px 放得下。
- 歐語：用 macOS 的 `Arial Unicode.ttf` 13px ×1.12 估 FRIZQT（本機沒有 Friz 字型檔，這是保守估計），目標 ≤124。

**寫法**：
- 標籤只放短名詞片語，說明丟到下一列的 text 或勾選框的 hint。
- 小節標題已經給了脈絡時標籤可以很短：「減益類型高亮」底下的開關叫「依類型上色」；
  「溢盾光暈」那組底下叫「光暈換到另一端」（德文直接「Am anderen Ende」）。
- 下拉的選項本身寫得出意思時，標籤縮成單字（法／俄／西／葡／義的「填充方向」＝ Direction 一字）。
- 改 key 文字＝九個語系檔原地替換那一行，不要留舊 key。

**Why**：歐語譯文平均比英文長三到五成，英文剛好塞得下的標籤翻完幾乎都會爆；中文看起來短，
但一個字 13px，十個字就滿了。

**How to apply**：新增或改動 toggle／slider／dropdown／color 的 label 時，九語系一起量過再交件。
既有的超長標籤（估計歐語的「吸收盾反向填充」等好幾條）還沒整理，碰到再修。

相關：[[project-miliui-unit-frame]]、[[project-miliui-widgets-vendor]]
