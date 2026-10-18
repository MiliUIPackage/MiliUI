---
name: miliui-cdm-shape-masks
description: 重新產生 MiliUI_CooldownManager「圖示形狀與陰影」的貼圖（Media/shape-rounded.png、shape-circle.png 兩張形狀遮罩，shadow-square／rounded／circle.png 三張模糊陰影），以及長條類的邊緣陰影 Media/shadow-edge.png（backdrop 八格）。當使用者說「圓角太圓／不夠圓」「圓形邊緣有鋸齒」「陰影太大／太淡」「圖示陰影重畫」「多一種形狀」「長條陰影太硬／太軟」「陰影角落有接縫」，或要動 Core/Shape.lua 的 SH.SHADOW_PAD、SH.MASK／SH.SHADOW、SH.EDGE_SHADOW／EDGE_UV 時使用。圖是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 圖示形狀的遮罩與陰影貼圖

`AddOns/MiliUI_CooldownManager/Media/shape-*.png`、`shadow-*.png`（含長條用的 `shadow-edge.png`）**不是素材，是 `scripts/shapes.py` 畫出來的**。
要改圓角半徑、陰影的外擴或模糊程度就改腳本常數再跑一次。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI_CooldownManager/Media" && python3 "../../../.claude/skills/miliui-cdm-shape-masks/scripts/shapes.py"
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py AddOns/MiliUI_CooldownManager/Media/shape-rounded.png AddOns/MiliUI_CooldownManager/Media/shape-circle.png AddOns/MiliUI_CooldownManager/Media/shadow-square.png AddOns/MiliUI_CooldownManager/Media/shadow-rounded.png AddOns/MiliUI_CooldownManager/Media/shadow-circle.png AddOns/MiliUI_CooldownManager/Media/shadow-edge.png --apply
```

**一定要 `cd` 到 `Media/`**（腳本用相對檔名存檔）。需要 Pillow。沒有亂數，同一份腳本跑出來的圖一模一樣；
第二行是 `wow-png-shrink` 的無損壓縮（只動編碼、像素不變，約省兩成）。壓之前新圖先 `git add`。
只改了其中一張時，其他幾張重跑出來像素一樣、只是編碼不同（還沒壓過）——`git checkout` 回去就好，不必整批重壓。

驗朝向：`python3 …/shapes.py --debug` 另外輸出 `shadow-edge-debug.png`（八格各一色、外緣也有底色）。
暫時把 `Core/Shape.lua` 的 `SH.EDGE_SHADOW` 指到這張、`/reload` 看一條開了陰影的資源條：左紅、右綠、上藍、下黃、
左上洋紅、右上青、左下橘、右下白，而且每一格都是**貼著條身那側最濃**。看完改回來、刪掉 debug 圖（不進版控）。

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

## 長條的邊緣陰影（`shadow-edge.png`）

長條類（資源條、施法條、自訂計時條、自訂格子、增益長條、觸發牌堆列、天空騎術列）的陰影**不能用上面那三張**：
那三張是整張拉伸到格子大小、四邊外擴「邊長 × 0.25」，長條 300×20 拉上去橫邊只剩 5px、兩端卻 75px，形狀全歪。
長條改走 backdrop 的「八格邊緣」：角落固定一格大、直邊沿長度拉長，任何長寬比都對，粗細用實體像素指定。

- **格式**：128×16，八格各 16×16，純白、只有透明度有內容。順序與每格的朝向照暴雪 `SharedXML/Backdrop.lua` 的
  `textureUVs`（左、右、上、下、左上、右上、左下、右下；**上下兩格是旋轉過的**：螢幕的上→下＝貼圖的左→右），
  腳本 `EDGE_INNER` 那張表寫著每格的內緣在哪一側。格內取樣範圍內縮 1 貼圖像素（`EDGE_INSET`，同暴雪的 texcoord），
  所以它也是一張合法的 `edgeFile`。
- **衰減**：內緣（貼著條身）alpha 1、外緣 0，`exp(−k·t²)` 正規化（`EDGE_FALLOFF`）；角是以內角為圓心的放射衰減，
  跟兩條直邊在接縫處同值。粗細（幾個實體像素）由遊戲裡拉伸決定，貼圖不必跟著改。
- **Lua 端**（`Core/Shape.lua` 的 `SH.EdgeShadow`）：不套 `BackdropTemplate`，自己建八張貼圖、texcoord 抄同一張表
  （`SH.EDGE_UV`；直邊因為沿長度是同一個值，拉伸＝重複，不必 repeat）。理由：引擎列「只在生效時顯示」的裝飾建在
  AuraButton 的 `initializeFrame` 裡，那裡不能掛 script，而 BackdropTemplate 自帶 OnSizeChanged。
  改了八格的排法，腳本的 `EDGE_INNER` 與 Lua 的 `SH.EDGE_UV` 要一起改。
