---
name: project-miliui-uf-visual-bounds
description: MiliUI_UnitFrames 的「視覺框體」不等於框架矩形——魔力條露出去的那截才是對齊基準；露出框外的元件各自要有自己的 ping 接收器與暗色遮罩
metadata:
  type: project
---

**單位框的視覺邊界是 hpbar/mpbar 疊出來的，不是 `uf` 那個矩形。** 貼在框邊的元素
（光環、圖示）要對齊的是前者。

目標框實例（frame h=50，`Core/DB.lua`）：`hpbar x=0 y=0 h=50`、`mpbar x=-8 y=-8 h=50`
→ 魔力條往**左**露 8、往**下**露 8，視覺 bottom 是 **-58** 不是 -50，左緣是 **-8** 不是 0。
玩家框是鏡像（`mpbar x=8`，往右露）。

由此推出的兩條，都反直覺：

- **同一個框、上下兩排光環的對齊基準不同**。減益在框上方，那裡只有血條 → `x = 0`；
  增益在框下方、上緣挨著魔力條 → `x = -8`。兩排 x 不一樣才是對齊，設成同一個數字反而歪。
- **間距要拿視覺邊界算**。增益 `y = -62` 的實際間距是 `62 - 58 = 4`，不是 62 - 50 = 12。
  減益 `y = 8` 就真的是 8 —— 所以「上下等距」在數字上長得不對稱（4 對 4 = `y=-62` 對 `y=4`）。
  目標的目標／寵物框等小框的魔力條都是 `x=0`、貼在血條下方不露出（以 `Core/DB.lua` 為準）。

**別憑截圖目測補正 x。** 光環容器是 `SetPoint("TOPLEFT", uf, "TOPLEFT", x, y)`，`x = 0`
就是精確貼齊框架左緣，沒有次像素誤差可補。使用者說「差一點點」時先問對齊基準是哪條邊，
不要直接加 1 —— 我加過，是錯的，真正的差來自魔力條那 8。

**露出 `uf` 矩形之外的元件，frame stack 裡根本沒有 uf** —— 所以每個元件要各自有：
- ping 接收器（`ns.ArmPingReceiver(uf, host, …)` 對 hpbar／mpbar／classpower／manabar／portrait 各一顆）；
- 超出距離的暗色遮罩（每個元件各遮各的，不鋪聯集大矩形）。
細節見 [[project-miliui-unit-frame]]、[[project-miliui-uf-visibility-gate]]。

相關:[[project-miliui-pixel-snapping]]
