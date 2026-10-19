---
name: wow-hairline-p-pixel-not-p-scale
description: 1px 邊框／細線在 1440p 以上畫成 2px 的成因——P.Scale(n) 是「n 個 UI 單位貼整數像素」，實體像素量要走 P.Pixel(n)；兩支的算式、哪些量該用哪支、CreateLine 圖記線粗留 P.Scale（5K 上 P.Pixel(1) 看不見）、全套組已套用清單
metadata:
  type: reference
---

> 這篇只講成因 ①（P.Scale vs P.Pixel）。畫 1px 邊框的完整規則（另外三個成因、`P.NoSnap`、檢查清單）在 [[wow-1px-border-rules]]。

**症狀**：1px 邊框、髮絲線、小節標題底線在高解析度（1440p 以上、或 UI 縮放偏大）畫成 2px；
在 Retina／縮放 > 1 的機器上 1px 反而變 0 或露縫。2026-10-14 全套組一次修掉
（`219331e92` MCDM、`2c5abec7d` 共用層、`454abf9bd` 其餘十一支）。

## 兩支函式管的不是同一件事

共用層 `Libs/MiliUIWidgets/PixelPerfect.lua`（各插件 vendor 複製，見 [[project-miliui-widgets-vendor]]）：

| | `P.Scale(n)` | `P.Pixel(n)` |
|---|---|---|
| 算式 | `PixelUtil.GetNearestPixelSize(n, UIParent:GetEffectiveScale())` | `n × PixelUtil.GetPixelToUIUnitFactor() ÷ UIParent:GetEffectiveScale()` |
| 語意 | **n 個 UI 單位**貼到最近的整數實體像素 | **剛好 n 個實體像素**換算成 UI 單位 |
| 1 UI 單位 ≥ 1.5 實體像素時 `(1)` | 2（以上） | 1 個實體像素 |
| 1 UI 單位 < 0.5 實體像素時 `(1)` | 0 | 1 個實體像素 |
| 該用在 | 尺寸、間距、座標（本來就以 UI 單位設計的量） | 邊框粗細、`edgeSize`、細線、分段格距、「2px 強調條」、半像素補正——**以實體像素計的量** |

`P.Pixel` 把 n 四捨五入成整數、≤ 0 回 0。兩支都以 UIParent 的有效縮放為基準；框本身
`SetScale` ≠ 1 時基準要換成框自己的（[[wow-setscale-offset-units]]）。

**判準一句話：設計稿上寫「1px」的東西用 `P.Pixel`，寫「10 單位寬」的用 `P.Scale`。**
以前全套組把兩種量都丟給 `P.Scale`，低解析度看不出差別（1 UI 單位 ≈ 1 像素），是高解析度玩家回報才露餡。

## 圖記的線不是髮絲線（2026-10-15 翻車一次）

`CreateLine` 畫的 ×／＋／chevron 這種**圖記**，線粗要走 `P.Scale(thickness)`，不是 `P.Pixel`：
它是跟按鈕一起縮放的形狀（像字），不是「貼著邊框的 1px」。10-14 那波把
AdventureGuideSpecCompare 關閉鈕 × 的 `SetThickness` 一起換成 `P.Pixel(1)`，在使用者的
5K（2764 列、UI 縮放 1）上是真的 1 個實體像素，斜線直接看不見（10-15 改回）。
MiliUI_Skin 引擎 `BuildGlyph` 本來就是 `P.Scale(g.thickness or 1)`，STYLE.md 註 ⓖ 也寫明。
**判準：線的粗細要不要跟著按鈕變大？要 → P.Scale；永遠就是 1 像素 → P.Pixel。**

## 內縮也要跟邊框同一支

邊框 `edgeSize = P.Pixel(1)` 而內容內縮寫死 1（UI 單位）的話，縮放 > 1 時 `P.Pixel(1) < 1`，
邊框內緣與內容外緣對不上，露出一圈次像素縫——MiliUI_UnitFrames 的 `Media.BorderInset(size)`
現在就是 `P.Pixel(size)`，內縮量一律拿它，細節在 [[project-miliui-pixel-snapping]]。

## 怎麼找漏網的

`git grep -n "P.Scale(1)\|P.Scale(2)" AddOns` —— 常數 1／2 幾乎都是像素語意；變數的要看那個量是不是「邊框／線／內縮」。
**同一個視覺關係的兩邊要用同一支**：backdrop 邊框走 `P.Pixel(1)`，內容內縮也要 `P.Pixel(1)`，混用就露縫。
1080p 上兩支算出來幾乎一樣，所以這個 bug 撐了很久都沒人看到——驗證要拿 1440p／4K 或 UI 縮放偏大的機器。

## 已套用（2026-10-14；之後以 `grep -rl 'P\.Pixel' AddOns --include='*.lua'` 為準）

共用層 `W.Stylize` 的 edgeSize、分頁卡片四邊與打通條、小節標題底線；MiliUI 本體、
AdventureGuideSpecCompare、BossTimeline、CharacterNotes、CooldownManager、InfoBar、Minimap、
MythicPlus、QuestTracker、ShoppingList、Tooltip、UnitFrames（含 `Media.BorderInset`）；Cell 自己那份
`Libs/PixelPerfect.lua` 另有同名函式。目前 21 份 vendor 全帶共用層的 PixelPerfect；README 說那支「可略、
把 `Env.P` 指向自己的」——**真要這樣做，自己那份得先有 `P.Pixel`**，`W.Stylize` 一載入就會呼叫它。

相關：[[project-miliui-widgets-vendor]]、[[project-miliui-pixel-snapping]]、[[project-miliui-hud-skin]]、[[wow-setscale-offset-units]]
