---
name: project-miliui-pixel-snapping
description: MiliUI_UnitFrames 的像素對齊規則——backdrop edgeSize 走 P.Scale，內容內縮也必須走同一個值
metadata:
  type: project
---

**症狀**:血條／圖騰圖示四周有一條若隱若現的細縫,透出後面的場景。

**成因**:backdrop 的 `edgeSize` 用 `P.Scale(1)`(把 1 個實體像素換算回版面單位),但內容
(clip 框、背景框、圖示)卻內縮**原始的 1**。Mac Retina 上 UIParent 有效縮放 > 1,
`P.Scale(1)` 其實**小於 1** → 邊框畫 0.75、內容退 1.0,中間 0.25 沒人畫。

**規則**:內縮量一律用 `Media.BorderInset()`(= `P.Scale(borderSize)`),跟 `ApplyBorder` 畫出來
的厚度同一個值。已套:Health / Power / Castbar / Totems。

**延伸(不是縫,是銳利度)**:1 版面單位在 Retina 上不是整數實體像素,細線會忽粗忽細。
所有尺寸/位移都過 `ns.P.Scale`:`ApplyElementBase`、`ApplyFramePosition`(單位框本身沒對齊的話
底下元件再對齊也白搭)、Texts、Icons、ClassPower 分段(除出來的小數格寬最明顯)、
光環按鈕外框、施法條圖示。

**殘留**:單位框是 CENTER 對 UIParent CENTER,寬度是奇數個實體像素時邊緣仍會落在半像素上。
要根治得改成 TOPLEFT 錨定,會動到存檔座標語意,目前判定不值得。

相關:[[project-miliui-unit-frame]]
