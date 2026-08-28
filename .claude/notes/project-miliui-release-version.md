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

## 登入訊息（2026-08-28 改寫）

`MiliUI/Core.lua` 原本每次登入都印一行歡迎訊息，只有 zhTW 看得到、沒有開關，
而且網址寫成 Markdown 連結 `[奇樂-...](https://addons.miliui.com)` ——
**聊天視窗不解析 Markdown**，玩家看到的是原樣的中括號加括號，而且點不了
（WoW 的聊天也不會自動把裸網址變成連結）。

現在：
- **只在 `## Version` 變動之後的第一次登入印一次**（SV 記 `lastSeenVersion`）。
  套組版本是 `YYYYMMDD`、每次發佈都會變，那正是這則訊息唯一有意義的時機。
- 純文字網址（圈起來可以複製）。
- 第一次安裝與更新兩種措辭分開；非中文客戶端有英文版本。
- 開關 `MiliUI_DB.welcomeMessage`，在 `/miliui` →「插件強化」。
- 等 `PLAYER_LOGIN` 才排 timer（舊版在檔案載入期就排，那時 SV 還不存在）。

搭配 repo 根目錄新增的 `CHANGELOG.md`：玩家看到「已更新到 X」之後有地方查改了什麼。
