---
name: wow-font-metrics-dropin
description: 換 WoW 中文字型要先對齊行高與字面，否則字會整體變小、位置全跑掉
metadata:
  type: reference
---

直接把新字型改名丟進 `_retail_/Fonts/` 會位移，因為各家的垂直度量與字面率不同：

| | 行高 | `國` 字面 |
|---|---|---|
| Microsoft YaHei（zhTW 常見替換來源） | 1.320 em | 0.924 em |
| Noto Sans TC 原廠 | 1.448 em | 0.846 em |
| 芫荽 Iansui 原廠 | 1.120 em | 0.793 em |

**做法**（fontTools，不動輪廓）：
1. `head.unitsPerEm` 改成 `舊值 ÷ 想放大的倍率` —— 輪廓座標不變，em 變小＝視覺變大。
   要縮小就反過來調大（原始 `2.ttf` 就是 2048→2300 把傷害數字縮成 89%）。
2. 用新的 upm 重算 `hhea.ascent/descent/lineGap`、`OS/2.usWinAscent/Descent`、
   `sTypoAscender/Descender/LineGap`，比例照抄要取代的那支字型。
3. `OS/2.fsSelection &= ~128` 關掉 USE_TYPO_METRICS（雅黑是關的，芫荽預設是開的）。

YaHei 的比例：hhea 2167/-536、win 同、typo 1663/-519/9，全部 ÷2048。

**前提**：這招安全是因為這些字型幾乎沒 hinting（Noto 只有 gasp+prep、芫荽只有 gasp）。
如果目標字型有完整 hinting（雅黑有 fpgm/prep/cvt/hdmx/LTSH/VDMX），改 upm 會讓 CVT 值對不上 ——
原始 `bKAI00M.ttf` 就是這樣被改壞的，還順手掉了 hdmx/LTSH/VDMX 三張 GDI 小字表。

**WoW 只吃 glyf 輪廓的 .ttf**，思源黑體官方是 OTF/CFF，要用 Google Fonts 的 Noto Sans TC
可變字型再 `varLib.instancer` 抽靜態，抽出來是 glyf。
相關：[[wow-zhtw-font-slots]]、[[wow-font-weight-ink-matching]]
