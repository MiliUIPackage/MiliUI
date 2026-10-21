---
name: feedback-let-user-pick
description: 「給我拍板」「給我選」＝列選項讓使用者挑，不要自己決定就動手
metadata:
  node_type: memory
  type: feedback
  originSessionId: 50aa68db-5d36-4bc2-b8ed-547a8cdf927f
  modified: 2026-10-21T15:22:21.992Z
---

使用者說「給我拍板」「給我選」時，意思是**把選項交給他決定**，不是叫我替他拍板。要用 AskUserQuestion 列出候選（附推薦與預覽），等他選完才改。

**Why:** 2026-10-21 改 MiliUI_Tooltip「誰在打他」的用詞時，使用者說「再想其他詞 給我拍板」，我讀成「你決定」就直接改了語系，被糾正「我說給『我』選」。

**How to apply:** 用詞、命名、樣式這類偏好題，只要使用者要「選項」或語意模糊，就先問、別先改；推薦的那個放第一個並標 (Recommended)。相關：[[feedback-zhtw-blizzard-terms]]
