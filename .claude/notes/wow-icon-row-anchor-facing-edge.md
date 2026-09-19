---
name: wow-icon-row-anchor-facing-edge
description: 依附在框架旁邊的圖示排，錨點必須選「面向框架的那一邊」，否則顆數一變間距就跑掉
metadata: 
  node_type: memory
  type: reference
  originSessionId: 91373b36-1520-4633-8f9a-936dc086b42a
  modified: 2026-09-14T18:45:00.724Z
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

⚠ **套用前先確認排是在框「外面」還是「裡面」。** 貼著框內緣往內長的排，面向框邊的
就是同側 —— 靠左內側是 `LEFT` 對 `LEFT`，本來就穩。對它套這條規則會把整排翻到框外。

2026-08-24 一天內踩到三次（第 1 條是誤判）：
1. ~~Cell 內建的左側冷卻排~~ —— **誤判，2026-09-15 已還原**。`defensiveCooldowns` /
   `allCooldowns` 原版是 `LEFT/button/LEFT -2`、由左到右，x=-2 代表左緣只凸出框外 2px，
   整排在**框內**（跟右側外部冷卻 `RIGHT/RIGHT +2` 對稱）。當成框外排改成 `RIGHT/LEFT`
   之後，所有預設玩家的排都被推到框外、壓到左邊那一格，x 小於 -2 的還被夾成 -2。
   玩家回報的症狀是「位置怎麼變成 -2」—— 數字沒變，變的是「自己的」那一格。
   還原用一次性旗標 `miliuiLeftCooldownAnchorReverted`，只翻「右／button／左、x == -2」這種
   完全等於誤遷移產物的存檔；
2. 滑鼠施法提示列（`Utilities/ClickCastingHints.lua`）—— 先是開了「我的錨點」設定（預設右上）；2026-09-20 整個位置模型改成「附著在哪一邊」之後這個設定拿掉了，釘哪一角由程式從 side＋版面 anchor 推（永遠釘面向框架的那一邊＋版面生長的那一頭），見 [[project-local-addon-forks]] 的 Cell 列；
3. 使用者自訂的 17×17 光環排 —— 在指示器面板把「自己的」改成右上就解決。

排查順序：先看錨點的**第一個點**（那是「我們自己的哪一角」），不要一開始就懷疑
flow layout。Cell 的 `/cab inspect <unit>` 會印 `set{axis/growth/anchor/maxline}`，
四個都 `ok` 就表示排版 API 有生效，問題在錨點語意而不是 API。

相關：[[project-cell-auracontainer-rewrite]]、[[project-miliui-uf-visual-bounds]]
