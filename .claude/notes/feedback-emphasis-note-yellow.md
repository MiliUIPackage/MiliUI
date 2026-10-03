---
name: feedback-emphasis-note-yellow
description: 使用者說「黃字說明」＝共用層 W.fontEmphasis（1, 0.82, 0）；整列寬、放在底部灰字說明正上方
metadata:
  type: feedback
---

「黃字說明」是全套組的強調說明（適用範圍、注意事項）：一律用 MiliUIWidgets 的 `W.fontEmphasis`
（色值 `W.EMPHASIS_COLOR` = 1, 0.82, 0，字級同 fontSmall），不要自己挑黃色、不要 SetTextColor 硬寫。
版面：寬度跟底部灰字說明一樣（整列寬，不縮在控件欄），放在那段灰字的正上方。

**Why:** 2026-10-03 冷卻管理器法術小窗：先做成控件欄寬、夾在列中間的黃字，使用者要求移到灰字上方、同寬，並把顏色寫進共用層全套組通用。
**How to apply:** 使用者說「加黃字說明」時直接用 W.fontEmphasis；一般補充說明仍是灰字（見 [[feedback-options-toggle-description]]）。
