---
name: wow-font-weight-ink-matching
description: 換中文字型時用「墨水量」對齊粗細；微軟雅黑 Bold 約等於思源黑體 Black(900) 而不是 Bold(700)
metadata:
  type: reference
---

換字型時光看 `usWeightClass` 會判斷錯粗細 —— 不同字型家族的 700 差很多。用**墨水量**量：
同字級渲染同一個字，數暗像素。

以微軟雅黑 Bold 為 100% 的實測（數字 `8` / 漢字 `國`）：

| 字型 | 墨水量 |
|---|---|
| Microsoft YaHei Bold | 100% |
| 思源黑體 TC Black (900) | **~100%** |
| 思源黑體 TC Bold (700) | 87% |
| 思源黑體 TC Medium (500) | 71% |
| 芫荽 Iansui Regular | 50% |

**How to apply:** 要無痛取代雅黑粗體就選 **Black(900)**，選 Bold(700) 會被抱怨「變細了」。
量測腳本：Pillow 把字畫到灰階圖上，`sum(1 for p in im.getdata() if p>128)`。

順帶一提，字重越重 glyph 的 bbox 會往外長（`國` 高從 0.938em 變 0.950em），那是筆畫變粗的
自然結果，不是縮放沒對準 —— 版面是看 advance（1.000em），不用去補償。
相關：[[wow-zhtw-font-slots]]、[[wow-font-metrics-dropin]]
