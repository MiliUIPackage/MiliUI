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

**單位框本身已根治**(舊筆記說的「CENTER 對 CENTER 落在半像素」殘留已經修掉):改成從
`UIParent` 的 **BOTTOMLEFT**(螢幕原點,保證在像素邊界)起算,把左下角座標對齊、寬高又都是
整數像素 ⇒ 四邊全部落在邊界。**存檔語意沒變**,`frame.x/y` 仍是「框中心相對畫面中心的偏移」,
只是換算後再錨定。

**新殘留:整框縮放 ≠ 100% 時框內對不齊。**`frame.scale`(百分比)走 `SetScale`,框內一單位長度
不再等於 UIParent 一單位,而元件那些 `ns.P.Scale` 仍以 UIParent 的縮放湊整數像素 ⇒ 1px 細線會
變成 scale 個實體像素、邊緣偏半格。單位框自己的尺寸與位置有另外處理(`ApplyFramePosition`
用框自己的 effective scale 湊、位移再除回去,見 [[wow-setscale-offset-units]]),框內元件沒有——
要根治得把框的 effective scale 一路傳進所有元件的 P.Scale 呼叫點(約 30 處),判定不值得。
100% 是預設值,行為與改動前逐位元相同。

相關:[[project-miliui-unit-frame]]、[[wow-setscale-offset-units]]
