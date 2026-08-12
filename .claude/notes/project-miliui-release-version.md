---
name: project-miliui-release-version
description: "MiliUI.toc 的 ## Version 是 YYYYMMDD，發佈新版時要手動改成當天日期"
metadata: 
  node_type: memory
  type: project
  originSessionId: 234790cb-b07c-4327-9f5f-2c34e643bef3
  modified: 2026-08-12T15:28:29.483Z
---

`AddOns/MiliUI/MiliUI.toc` 的 `## Version:` 是 **`YYYYMMDD` 格式的純整數**（例：`20260812`），**發佈新版給玩家時要手動改成當天日期**。

這個欄位從 2026-08-11 起變成有作用的東西，不只是標記：

- `MiliUI/Enhance/VersionCheck.lua` 仿 DBM，用 addon message 在公會／隊伍／團隊間廣播這個數字，收到比自己大的就提示一次（整場 session 只提示一次）。**純整數比較，所以格式不能亂改。**
- `MiliUI/Enhance/GameMenu_MiliUIButton.lua` 的 ESC 選單版本標籤直接讀它。
- 對外介面是 `MiliUI.Version = { my, myText, newest, newestText }`。

**Why:** 忘記改的話，所有玩家互相廣播的都是舊數字，版本提示等於沒作用，而且不會有任何錯誤——跟沒裝一樣安靜。

**How to apply:**
- 12.1 起遊戲會在**首領戰／M+／PvP 進行中封鎖插件通訊**，所以 VersionCheck 有一份抄自 Cell `Comm/Comm.lua` 的 `IsCommRestricted()`（`IsEncounterInProgress` / `C_MythicPlus.IsRunActive` / `C_PvP.IsActiveBattlefield`）。**任何新寫的 `SendAddonMessage` 都要照這個擋一次**，不要去賭受限時是回傳失敗碼還是直接報錯。
- Cell 自己的版本檢查已經在本地停用（[[project-cell-no-update-notice]]），套組的版本提示只走 MiliUI 這一套。
