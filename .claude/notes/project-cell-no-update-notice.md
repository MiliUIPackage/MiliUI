---
name: project-cell-no-update-notice
description: Cell 停用新版本聊天通知的就地修補，Cell 更新後要重套
metadata: 
  node_type: memory
  type: project
  originSessionId: fb8eaa82-fbf4-4596-a018-71ba1432351f
---

MiliUI 停用 Cell 的兩種更新通知（都加 `-- MiliUI:` 標記）：

1. 「已有新版本」聊天通知：`AddOns/Cell/Comm/Comm.lua` 的 `CELL_VERSION` comm handler（約 line 108-116），保留版本比對與 `CellDB["lastVersionCheck"]` 更新，只註解掉 `F.Print(L["New version found ..."])` 那行。
2. 更新後自動彈出的更新日誌：`AddOns/Cell/Modules/About/Changelogs.lua` 的 `F.CheckWhatsNew(show)` 開頭加 `if not show then CellDB["changelogsViewed"] = Cell.version; return end`，About 頁手動開啟（show=true）不受影響。

**Why:** 使用者不想看到任何更新提示，但版本比對邏輯要照常運作。

**How to apply:** Cell 從上游更新後兩處修補都會被覆蓋，需重套。相關修補參見 [[project-cell-vehicle-secret]]。
