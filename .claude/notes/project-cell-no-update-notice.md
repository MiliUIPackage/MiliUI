---
name: project-cell-no-update-notice
description: Cell 的更新提示現況——不對原版廣播、改走 MiliUI 私有前綴互相提醒；更新日誌換成維護者公告
metadata: 
  node_type: memory
  type: project
  originSessionId: 370815d0-9f01-4f66-b973-db047100add7
  modified: 2026-08-17T13:49:11.832Z
---

⚠ 2026-08-17 大改，這份筆記先前的內容（「使用者不想看到任何更新提示」）已經**不成立**。

## 現況：三件事分開

**1. 永遠不往 `CELL_VERSION` 廣播。**
原版 Cell 從那個前綴收到訊息後只抓數字來比。我們的版本是 `rNNN_MiliUI`，已經**不在上游的釋出線上**（見 [[project-local-addon-forks]]：我們自己就是上游），廣播過去等於告訴每個用原版的隊友「有一個 CurseForge 上不存在的版本」，還把他們指去下載頁。

**2. `CELL_VERSION` 的接收保持靜音**（`Comm/Comm.lua` 的 handler 裡那行 `F.Print` 維持註解掉）。
理由不是「不想看到提示」，而是拿他們的 r 號跟我們的比只會一直誤報。

**3. MiliUI 版本之間互相提醒（2026-08-17 新增）。**
`Comm/Comm.lua` 尾端，私有前綴 **`CELL_MILIUI_VER`**（15 字元，上限 16）：
- **完全獨立於 MiliUI 套組**——版本號直接讀 Cell 自己的 TOC metadata，不碰 `MiliUI` 全域，單獨拉出 Cell 也能運作。
- ⚠ **讀 TOC 不要讀 `Cell.version`**：後者要等 `Core.lua` 的 `ADDON_LOADED` 才有值，而這段在檔案被解析時就執行，會讀到 nil 然後整個功能靜靜不安裝。
- 進場／名單變動觸發，5 秒延遲 + 30 秒節流，走 `IsCommRestricted()`，整場 session 只提示一次。
- 沿用既有的 `L["New version found (%s). Please visit %s to get the latest version."]`，11 個語系都有翻譯，不用新增字串。
- 下載網址：**https://addons.miliui.com/wow/cell**（不是 GitHub repo——玩家要的是插件本身）。

⚠ **`Cell.toc` 的 `## Version: rNNN_MiliUI` 現在同時是釋出訊號**，不再只是 Revise 遷移的閘。出貨時忘了 bump，提醒會安靜失效、沒有任何錯誤。**但 bump 是使用者自己做的動作，agent 不要主動加**——見 [[feedback-no-cell-version-bump]]。分隔符是**底線**（2026-08-17 從連字號改過來），不過所有解析都是 `string.match(v, "%d+")` 只抓數字，格式改動不影響相容。

## 更新日誌 → 維護者公告

`Modules/About/Changelogs.lua` 早期的「開頭加 return」修補**已經不存在**。現在是一套公告系統：`F.CheckWhatsNew(show)` 走 `Cell.HasNotice()` / `Cell.HasUnreadNotice()` / `Cell.MarkNoticesRead()`，內容在 `Modules/About/Notice.lua`（標題就寫著 MAINTAINER NOTICES）。要對玩家講話就寫在那裡。

**How to apply:** Cell 已不追上游，這些不會被覆蓋，不需要「更新後重套」。
