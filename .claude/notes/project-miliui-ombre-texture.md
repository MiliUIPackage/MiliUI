---
name: project-miliui-ombre-texture
description: 套組長條材質 MiliUI Ombre（漸染）是四張貼圖疊出來的，不是算顏色；疊層在共用 MiliUIMedia，MOD＋遮罩已實測
metadata:
  type: project
---

「MiliUI Ombre／米利UI: 漸染」（2026-11-13）＝長條左端更濃、右端原色。跟 [[project-miliui-satin-texture]] 同一個技能（miliui-satin-texture 的 ombre.py）。

- 一張圖乘顏色只能變暗、做不出變濃 ⇒ 四張貼圖疊：底原色 → 兩層純白 `SetBlendMode("MOD")`（三次方）→ 頂層 alpha 漸層圖蓋回原色。
  全掛在 StatusBar 自己身上、用錨在填充貼圖上的 MaskTexture 切掉空的那段。實作在 `MiliUI/Libs/MiliUIMedia/MiliUIMedia.lua` 檔尾（`MM.OmbrePaint`／`MM.OmbreClear`），五支插件各有一個薄入口。
- 探針實測（使用者確認）：MOD 混合吃遮罩、不漏色；在條上蓋裁切子框會蓋住條自己身上的文字。

**Why:** 使用者明講「不要用運算的，要實際材質」——先做的 SetGradient 雙色版被退（扣血時漸層跟著擠、下拉預覽看不到橫向漸層）。
**How to apply:** 之後再有「材質做不出來的效果」，先想怎麼畫、怎麼疊（混合模式＋遮罩），不要退回程式算顏色；沒把握的混合行為先用探針插件給使用者看，別直接鋪到五支插件。相關：[[project-miliui-media-naming]]、[[feedback-probe-addon-place-directly]]。
