---
name: miliui-cdm-shape-masks
description: 重新產生 MiliUI_CooldownManager「圖示形狀與陰影」的貼圖（Media/shape-rounded.png、shape-circle.png 兩張形狀遮罩，shadow-square／rounded／circle.png 三張模糊陰影）。當使用者說「圓角太圓／不夠圓」「圓形邊緣有鋸齒」「陰影太大／太淡」「圖示陰影重畫」「多一種形狀」，或要動 Core/Shape.lua 的 SH.SHADOW_PAD、SH.MASK／SH.SHADOW 時使用。圖是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 圖示形狀的遮罩與陰影貼圖

`AddOns/MiliUI_CooldownManager/Media/shape-*.png`、`shadow-*.png` **不是素材，是 `scripts/shapes.py` 畫出來的**。
要改圓角半徑、陰影的外擴或模糊程度就改腳本常數再跑一次。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI_CooldownManager/Media" && python3 "../../../.claude/skills/miliui-cdm-shape-masks/scripts/shapes.py"
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py AddOns/MiliUI_CooldownManager/Media/shape-rounded.png AddOns/MiliUI_CooldownManager/Media/shape-circle.png AddOns/MiliUI_CooldownManager/Media/shadow-square.png AddOns/MiliUI_CooldownManager/Media/shadow-rounded.png AddOns/MiliUI_CooldownManager/Media/shadow-circle.png --apply
```

**一定要 `cd` 到 `Media/`**（腳本用相對檔名存檔）。需要 Pillow。沒有亂數，同一份腳本跑出來的圖一模一樣；
第二行是 `wow-png-shrink` 的無損壓縮（只動編碼、像素不變，約省兩成）。壓之前新圖先 `git add`。

## 格式（跟 Lua 那邊的常數綁在一起）

- 五張都是 128×128，純白、只有透明度有內容。遊戲裡 `SetVertexColor` 上色（邊框襯底＝邊框色、陰影＝黑＋透明度）。
- **遮罩**（`shape-rounded`、`shape-circle`）：MaskTexture 的貼圖，也直接拿去 `Cooldown:SetSwipeTexture`（轉圈跟著形狀）。
  圓角半徑＝邊長 × `ROUND_RATIO`（0.18 ⇒ 23.04px／128）；只在腳本裡，Lua 不需要知道。
  直邊貼齊貼圖邊（整片不透明到邊），圓形外緣留半個像素。
- **陰影**（`shadow-square／rounded／circle`）：圖示（含邊框襯底）本身佔中間 `1 / (1 + 2 × SHADOW_PAD)`，四邊各外擴
  `SHADOW_PAD` 倍邊長。`SHADOW_PAD` 跟 `Core/Shape.lua` 的 `SH.SHADOW_PAD` 是同一個數（0.25），**改一邊另一邊一起改**；
  `Tests/Shape_test.lua` 有測幾何換算。模糊用高斯 `SHADOW_SIGMA × 圖示邊長`，貼圖外緣的 alpha 要是 0（腳本會印出來檢查）。
- 檔名寫死在 `Core/Shape.lua` 的 `SH.MASK`／`SH.SHADOW`。加形狀要三處一起加：腳本、那兩張表、`SH.SHAPES` 與設定頁的下拉。

## 為什麼是遮罩不是整張圖示換底

暴雪的 item 是別人的框：我們只能對它的貼圖呼叫方法（`AddMaskTexture`／`RemoveMaskTexture`、Cooldown 的 `SetSwipeTexture`），
不能寫欄位、不能換它的圖示。遮罩物件建在我們自己的框上，對應存弱鍵表，切回方形時整套拿掉。
圖示不是正方形（`icon.aspect`）時遮罩會被拉伸：圓角變橢圓角、圓變橢圓——這是已知限制，不另外產非正方形的圖。
