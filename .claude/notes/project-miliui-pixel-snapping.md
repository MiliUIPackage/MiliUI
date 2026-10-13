---
name: project-miliui-pixel-snapping
description: MiliUI_UnitFrames 的像素對齊規則——邊框／內縮走 P.Pixel（實體像素）、尺寸／座標走 P.Scale（UI 單位貼整數像素）；單位框從 UIParent 左下角起算、UIParent 內縮要重新定位；分段列整列先換整數像素再切格
metadata:
  type: project
---

通則（`P.Scale` 與 `P.Pixel` 的差別、什麼量該用哪個）在 [[wow-hairline-p-pixel-not-p-scale]]，這裡只記單位框自己的做法。

**症狀一：血條／圖騰圖示四周有一條若隱若現的細縫**，透出後面的場景。
成因：backdrop 的 `edgeSize` 換算過實體像素，但內容（clip 框、背景框、圖示）卻內縮**原始的 1**，
兩個數在 Retina／UI 縮放 ≠ 1 的機器上不相等，中間那圈沒人畫。
**規則**：內縮量一律用 `Media.BorderInset()`（＝ `P.Pixel(borderSize)`），跟 `ApplyBorder` 畫出來
的 `edgeSize` 同一個值。已套：Health / Power / Castbar / Totems / Icons / Inspect / DispelHighlight。

**症狀二：1px 邊框與細線在 1440p 以上畫成 2px**（`454abf9bd`，全套組一起修）。
成因：邊框、髮絲線、圖示內縮、分段列的像素單位原本走 `P.Scale(1)`——那是「1 個 UI 單位貼到最近的
整數像素」，1 UI 單位 ≥ 1.5 實體像素時就是 2px。改走 `P.Pixel(1)`（剛好 1 實體像素）。
單位框內用到的地方：`Media.BorderInset`、施法條圖示框的 `edgeSize` 與內縮、ClassPower 的 `px`、
血條損失段的分隔線與最小保留寬、設定頁的分隔線。

**延伸（不是縫，是銳利度）**：1 版面單位在 Retina 上不是整數實體像素，細線會忽粗忽細。
所有尺寸／位移都過 `ns.P.Scale`：`ApplyElementBase`、`ApplyFramePosition`（單位框本身沒對齊的話
底下元件再對齊也白搭）、Texts、Icons、ClassPower、光環按鈕外框、施法條圖示。

**單位框本身**：改成從 `UIParent` 的 **BOTTOMLEFT**（螢幕原點，保證在像素邊界）起算，把左下角座標
對齊、寬高又都是整數像素 ⇒ 四邊全部落在邊界。**存檔語意沒變**（`frame.x/y` 仍是「框中心相對畫面中心
的偏移」），只是換算後再錨定。
- ⚠ 代價：「當下的 UIParent 寬高 / 2」被烘進錨點。**有人改了 UIParent 的錨點**（資訊列停靠內縮一條、
  暴雪自己的 Mac 瀏海／除錯列）時沒有任何事件，內縮之前定位的框就停在舊的中心上（上緣縮 26 ⇒ 比預覽孿生
  高 13；症狀「開 /muf 預覽整排往下偏，關掉後只有改過設定的那一格停在預覽的位置」，`981c16945`）。
  `Units.lua` 掛 `UIParent:HookScript("OnSizeChanged")` 下一幀 `RepositionAll`（同步做會跑在資訊列的 secure
  snippet 裡，[[wow-121-addon-code-in-secure-stack]] 入口 6；一次內縮連發好幾次要併成一次）。
  背景見 [[wow-uiparent-inset-dock]]。

**分段列（點數型資源）的同寬排版**（`f0fd61824`）：「每格先對齊像素、再一格接一格串」會累積捨入誤差，
335px 六格的符文列比同寬長條多 2px。正解：**整列先換成整數實體像素（含格距），每格的左右邊界各自
`floor(i * span / n + 0.5)`**，最後一格右緣一定落在總寬上，零頭平均分到各格。每格直接錨 row 的
TOPLEFT／TOPRIGHT 加 `x0 * px`，不再錨前一格。

**殘留：整框縮放 ≠ 100% 時框內對不齊。**`frame.scale`（百分比）走 `SetScale`，框內一單位長度
不再等於 UIParent 一單位，而元件那些 `ns.P.Scale` 仍以 UIParent 的縮放湊整數像素 ⇒ 1px 細線會
變成 scale 個實體像素、邊緣偏半格。單位框自己的尺寸與位置有另外處理（`ApplyFramePosition`
用框自己的 effective scale 湊、位移再除回去，見 [[wow-setscale-offset-units]]），框內元件沒有——
要根治得把框的 effective scale 一路傳進所有元件的 P.Scale／P.Pixel 呼叫點（約 30 處），判定不值得。
100% 是預設值，行為與改動前逐位元相同。

相關:[[project-miliui-unit-frame]]、[[project-miliui-uf-visual-bounds]]、[[wow-setscale-offset-units]]、[[wow-hairline-p-pixel-not-p-scale]]
