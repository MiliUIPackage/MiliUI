---
name: wow-icon-row-anchor-facing-edge
description: 依附在框架旁邊的圖示排，錨點必須選「面向框架的那一邊」，否則顆數一變間距就跑掉
metadata:
  type: reference
---

**規則：一排圖示掛在某個框架旁邊時，錨點要用面向那個框架的那一邊。**

排的寬度（或高度）＝實際顯示幾顆 × (圖示 + 間距)，而顆數會隨**職業／專精／角色**變。
用背向框架的那一邊當錨點，面向框架的那一側就等於「錨點 ± 整排寬度」——顆數少一顆，
間距就多一顆的距離。症狀是「換角色之後距離變超遠」，而且**不會有任何錯誤訊息**。

- 掛在框架**左側** → 用自己的 `RIGHT` / `TOPRIGHT` 對到框架的 `LEFT` / `TOPLEFT`
- 掛在框架**右側** → 用自己的 `LEFT` / `TOPLEFT`
- 掛在**上／下** → 同理用 `BOTTOM*` / `TOP*`

⚠ **不要用大偏移量硬湊。** 直覺做法是維持左對左、把 x 調成 `-(整排寬度 + 間隙)`；
那個數字只對「當下這個角色的顆數」成立，換角色就錯，而且錯的量剛好是你看到的位移。

2026-08-24 一天內同一個病踩到三次，全部都是這條：
1. Cell 內建的左側冷卻排（`defensiveCooldowns` / `allCooldowns`）—— 預設值與存檔都改；
2. 滑鼠施法提示列（`Utilities/ClickCastingHints.lua`）—— 為此開了「我的錨點」設定，預設右上；
3. 使用者自訂的 17×17 光環排 —— 在指示器面板把「自己的」改成右上就解決。

排查順序：先看錨點的**第一個點**（那是「我們自己的哪一角」），不要一開始就懷疑
flow layout。Cell 的 `/cab inspect <unit>` 會印 `set{axis/growth/anchor/maxline}`，
四個都 `ok` 就表示排版 API 有生效，問題在錨點語意而不是 API。

相關：[[project-cell-auracontainer-rewrite]]、[[project-miliui-uf-visual-bounds]]
