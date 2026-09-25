---
name: feedback-cell-retail-only
description: 我們的 Cell fork 只支援正式服（TOC 只有 1200xx），不要為經典版加保護或保留經典版路徑
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3b6926fb-c4d1-4f3d-883e-fc0a48eeda68
  modified: 2026-09-25T06:46:26.914Z
---

MiliUI 裡的 Cell 只支援正式服（現代版），`Cell.toc` 只有 `## Interface: 1200xx`，沒有經典版的 TOC。
不要替經典版加保護（例如 `issecretvalue or function() ... end`），plan 裡也不要寫「保留經典版路徑」。

**Why:** 2026-09-25 我在 `/cab probe` 替 `issecretvalue` 加了經典版保護，理由是「Cell 也支援經典版」，
使用者糾正說「我的 Cell 只支援現代版」，那一段已經拿掉。上游程式裡的 `Cell.isRetail`／`isMidnight` 分支
是原版留下來的，不代表我們要照顧經典版。

**How to apply:** 新寫的程式可以直接假設正式服 12.x 的 API 都存在（`issecretvalue`、`C_Secrets`、
`SetAlphaFromBoolean`…）。上游原本就有的經典版分支不用特地刪，但新程式碼不要再加。
相關：[[project-local-addon-forks]]
