---
name: miliui-cdm-ring-textures
description: 重新產生 MiliUI_CooldownManager「圓環顯示」的環形貼圖（Media/ring-01.png ～ ring-20.png：軌道與進度共用的白色抗鋸齒圓環，每張環寬比例不同）。當使用者說「圓環邊緣有鋸齒」「環的粗細不準」「同心圓每圈粗細不一樣」「圓環貼圖重畫」「多加幾階粗細」，或要動 Core/Layout.lua 的 RING_STEPS／RING_MIN／RING_MAX、Layout.RingTexture 時使用。圖是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 圓環顯示的環形貼圖

`AddOns/MiliUI_CooldownManager/Media/ring-NN.png` **不是素材，是 `scripts/rings.py` 畫出來的**。
要改粗細的階數或邊緣的樣子就改腳本再跑一次。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI_CooldownManager/Media" && python3 "../../../.claude/skills/miliui-cdm-ring-textures/scripts/rings.py"
```

**一定要 `cd` 到 `Media/`**（腳本用相對檔名存檔）。需要 Pillow。沒有亂數，同一份腳本跑出來的圖一模一樣；
產出不要再跑 `wow-png-shrink`（跑一次腳本、git 就乾淨這條不變式比幾 KB 重要）。

## 格式（跟 Lua 那邊的常數綁在一起）

- 20 張、每張 256×256，純白、只有透明度有內容。遊戲裡同一張圖兩種用途：
  軌道（我們自己框上的貼圖，`SetVertexColor` 染軌道色）與進度（暴雪 Cooldown 的 `SetSwipeTexture`，`SetSwipeColor` 染填色）。
- 第 j 張的**環寬比例**（環寬 ÷ 直徑）＝ `0.02 × 15 ^ ((j − 1) / 19)`，0.02 到 0.30 的等比級數。
  `Core/Layout.lua` 的 `RING_STEPS`／`RING_MIN`／`RING_MAX` 是同一組數，**改一邊另一邊一起改**；
  `Layout.RingTexture(環寬, 直徑)` 依比例挑最接近的那張（對數距離），`Tests/Layout_test.lua` 有測。
- 檔名 `ring-%02d.png`，`Layout.RingFile(j)` 組路徑。改張數要連檔名的位數一起看。

## 為什麼要一組而不是一張

`SetSwipeTexture` 會把貼圖拉滿整個 Cooldown ⇒ 環的粗細跟直徑成正比。同心圓每圈直徑不同，
用同一張圖外圈會比內圈粗；每圈換一張「環寬比例 ＝ 環寬 / 這圈直徑」的圖，像素粗細才一樣。
20 階等比的相鄰比例差約 15%，8px 環寬的誤差在 1px 以內。

另一條路是「實心圓＋內圓遮罩、SetTexCoord 縮放遮罩挖洞」做連續粗細，但那要對暴雪 Cooldown 內部的 swipe
貼圖呼叫 `AddMaskTexture`（得翻 `GetRegions` 找它），侵入性高，目前不走。

## 畫法要點

- 外緣半徑留半個像素（127.5）：外緣剛好貼齊貼圖邊的話，雙線性取樣在邊上會被切平。
- 4 倍超取樣、LANCZOS 縮回；透明的地方 RGB 也是白（濾波時邊緣不會滲出黑邊）。
