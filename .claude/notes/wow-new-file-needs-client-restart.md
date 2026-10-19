---
name: wow-new-file-needs-client-restart
description: TOC 新增的 .lua 檔、新放的媒體檔，/reload 不會載入，要整個重開遊戲；交件時要提醒使用者
metadata:
  node_type: memory
  type: reference
  originSessionId: 03ae2035-09be-451e-b285-f40abd7cc111
  modified: 2026-10-19T20:09:21.459Z
---

遊戲只在**啟動時**讀 TOC 的載入清單與檔案清單：
- TOC 新增一支 `.lua`（新模組）→ `/reload` 不載入，那支檔案整個不存在（`ns.XXX` 是 nil，有守衛的呼叫端就靜默什麼都不做）。
- 新放的音檔／貼圖同理（`C_UIFileAsset.IsKnownFile` 不認，LSM 靜默不註冊；見 [[project-miliui-cooldownmanager]]、[[project-miliui-satin-texture]]）。
- 只改既有檔案的內容：`/reload` 就夠。

**實例**：2026-10-20 MCDM 戰鬥藥水代畫新增 `Modules/PotionWindow.lua`，使用者 `/reload` 後回報「失敗，還是沒出現」；整個重開遊戲後 `/mcdm debug` 才出現「戰鬥藥水視窗」那一行、代畫正常。

**How to apply:** commit 裡有**新增檔案**（TOC 多一行、Media 多一張）時，回報合進 master 的那段話直接寫「這次要整個重開遊戲，`/reload` 不夠」。使用者回報「沒生效」時，先問有沒有重開、或看 debug 有沒有新模組的痕跡，別先去改程式。
