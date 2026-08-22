---
name: wow-setscale-offset-units
description: SetScale 之後 SetPoint 的位移量會被縮放乘一次——「框放大了順便跑掉位置」的成因
metadata: 
  node_type: memory
  type: reference
  originSessionId: c82821f1-fc5d-44c1-8d71-aa342016e872
  modified: 2026-08-22T03:52:35.356Z
---

**規則**：`SetPoint(point, rel, relPoint, x, y)` 的 `x/y` 是**被錨定的那個框自己的**座標單位，
螢幕位置 = `x × 框的 effective scale`。`GetCenter()`／`GetWidth()` 同理，回的是框自己的單位。

所以對一個框 `SetScale(1.5)` 之後：

- **位置會跟著跑掉**：原本 `SetPoint("CENTER", UIParent, "CENTER", 300, 0)` 變成畫面上偏移 450。
  想維持「畫面上偏移 300」就要傳 `300 / 1.5`。
- **拖曳會加速**：游標差值是螢幕座標，除以 `UIParent:GetEffectiveScale()` 得到畫面單位後，
  還要再除框自己的 scale 才能餵給 SetPoint。不除的話框跑在游標前面（放手才彈回正確位置）。
- **像素對齊要換基準**：`P.Scale`／`PixelUtil.GetNearestPixelSize(v, s)` 的第二個參數是
  「v 用的是誰的單位」，框內的長度要傳**框自己的** effective scale（`UIParent:GetEffectiveScale() × 縮放`），
  傳 UIParent 的等於用錯格線去湊整數像素，湊完照樣糊。
- 子物件全部跟著縮放（含錨在框下方的資源列），但**從外面錨過來**的框不會
  （它有自己的 scale，只是錨點跟著移動）。

**保護**：`SetScale` 對 protected frame 在戰鬥中不合法，跟 SetPoint/SetSize 一樣要 `InCombatLockdown()` 閘。

MiliUI_UnitFrames 的整框縮放就是照這幾條寫的：`Core/UnitFrame.lua` 的 `ApplyFramePosition`
算好畫面座標再 `/ s`、`EditMode.lua` 的 `Place` 與 `Elements/Totems.lua` 的 `AnchorTo` 同樣除回去。
w/h 與所有元件座標維持「未縮放」語意，調縮放不動任何既有數字。

**兩層縮放要用相乘，不要用改寫**（`ns.FrameScale(fdb)` = `global.scale% × frame.scale%`）：
全域＝整套放大多少，個別＝這個框相對其他框的修正。若讓全域滑桿去**改寫**每個框的值，
使用者刻意調過的差異第一次拉全域就全滅、拉回 100 也救不回來，而且兩個控制項搶同一個欄位
（誰後寫誰贏）最難解釋。代價只有一個：個別滑桿仍顯示 100 而畫面已經放大，說明文字要寫清楚
「最終 = 全域 × 個別」。召喚物框（不是單位框）也走同一支。

相關：[[project-miliui-pixel-snapping]]、[[wow-setpoint-nil-relativeto]]、[[project-miliui-unit-frame]]
