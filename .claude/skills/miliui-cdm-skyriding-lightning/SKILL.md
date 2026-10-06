---
name: miliui-cdm-skyriding-lightning
description: 重新產生 MiliUI_CooldownManager 天空騎術面板「旋轉急衝」長條滿的時候的閃電序列圖（FlipBook，Media/skyriding-lightning.png）。當使用者說「閃電不夠像」「電光再粗／再亂一點」「閃電動畫重畫」「換閃電的樣子」，或要動 Modules/Skyriding.lua 的 BOLT_TEX／BOLT_ROWS／BOLT_COLS／BOLT_FRAMES 時使用。圖是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# 天空騎術的閃電序列圖

`AddOns/MiliUI_CooldownManager/Media/skyriding-lightning.png` **不是素材，是 `scripts/lightning.py` 畫出來的**。
要改造型就改腳本再跑一次。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI_CooldownManager/Media" && python3 "../../../.claude/skills/miliui-cdm-skyriding-lightning/scripts/lightning.py"
```

**一定要 `cd` 到 `Media/`**（腳本用相對檔名存檔）。需要 Pillow。亂數種子固定，同一份腳本跑出來的圖一模一樣；
產出不要再跑 `wow-png-shrink`（跑一次腳本、git 就乾淨這條不變式比幾 KB 重要）。

## 格式（跟 Lua 那邊的常數綁在一起）

- 1024×128，**2 欄 × 4 列 ＝ 8 格**，每格 512×32，由左而右、由上而下播放。
  改格數或排列，`Modules/Skyriding.lua` 的 `BOLT_ROWS`／`BOLT_COLS`／`BOLT_FRAMES` 一起改。
- 每格的長寬比 16:1：長條實際大約 24:1（寬兩三百、高 6～16），比例差太多的話垂直的鋸齒會被壓成一條細線
  （第一版 512×64 就是這樣）。
- 圖案純白、只有透明度有內容：遊戲裡 `SetVertexColor`（長條色往白靠 `BOLT_WHITEN`）＋ ADD 混色。
- 前六格是六道不同的閃電，最後兩格是第六道的餘暉（同一道調暗，不是新的一道）；Lua 那邊播完接一段看不見的停頓
  （`BOLT_TIME`／`BOLT_PAUSE`），看起來是「啪一下、消散、再啪一下」。

## 畫法要點

- 中點位移法，`decay` 0.62（比一般地形雜訊大：閃電要尖）＋偶爾放大的折角；分岔從主幹斜岔出去、短而細。
- 主幹＋分岔整組**等比縮進**格子上下的邊距（`fit_y`），不要硬夾——硬夾會在邊上壓出一段直線。
- 三層疊：模糊的大光暈、微模糊的中層、銳利的細芯，4 倍超取樣後 LANCZOS 縮回。

## 為什麼不用暴雪的

暴雪天空騎術介面有閃電序列圖（`dragonriding_sgvigor_filled_flipbook`、`..._decor_flipbook_left/right`、
`..._burst_flipbook`），但都是給直立寶石用的直式畫面（例如每格 68×100），放進扁長的橫條會被壓扁；
而且 atlas 改名或消失是靜默的。
