---
name: wow-121-chat-reply-secret-taint
description: 12.1 密語回覆在秘密名字下的死路：SetAttribute/SendChatMessage 只收未污染的秘密值，聊天狀態一髒就到 /reload
metadata: 
  node_type: memory
  type: reference
  originSessionId: 2975a2fc-396d-4e73-9da2-295e55bee8db
  modified: 2026-08-28T09:22:00.858Z
---

按 REPLY（預設 R）回覆密語，噴 `Lua Taint: <插件>` + `ChatFrameEditBox.lua:49 SetTellTarget`
（或更早的 `GetLastTellTarget` 比較秘密字串）。三件事湊起來，**這條路救不回來**：

1. 最後一個密語對象的名字可能是**秘密字串**（跨服、戰網、不在隊伍裡的玩家）。
2. `Frame:SetAttribute` 與 `C_ChatInfo.SendChatMessage` 在 API 標記上都是
   **AllowedWhenUntainted** —— 秘密值只有在執行**未被污染**時收得下去。
   `editBox:SetTellTarget(name)` 就是 `SetAttribute("tellTarget", name)`，所以
   被污染的程式既不能把秘密名字填進輸入框，也不能直接發訊息給它。換寫法沒有用。
3. `LAST_ACTIVE_CHAT_EDIT_BOX` 是全域，而 `ChatFrameUtil.ChooseBoxForSend` 每次
   **先讀它**、`ActivateChat` 之後才寫回去 → 讀髒值把執行染髒 → 寫回去照樣是髒的。
   **任何插件替玩家開過一次聊天輸入框，它就一路髒到 `/reload`。**
   查驗：`/dump issecurevariable("LAST_ACTIVE_CHAT_EDIT_BOX")`

REPLY 走 `ChooseBoxForSend`，所以 3 一成立就必死；`ChatFrameUtil.SendTell`（點聊天視窗裡
的名字）也走同一支，一起完蛋。

## ⚠ 不要覆寫回覆路徑上的任何暴雪函式

覆寫 `ChatFrameUtil.GetLastTellTarget`（或 `ReplyTell`）等於把那個 **table 欄位永久染髒**，
之後每次按 R 都是髒的 —— 連原本乾淨的情況也一起壞掉。MiliUI_ChatBar 2026-08 這樣做過，
結果只是把錯誤從 `GetLastTellTarget` 的比較挪到 `SetTellTarget` 的 `SetAttribute`，
而且順便砍掉玩家自己打 `/r 訊息` 這條**唯一還活著**的路（`ProcessChatType` 也讀那個欄位，
但它只碰輸入框自己的屬性、不讀 `LAST_ACTIVE_CHAT_EDIT_BOX`，本來是乾淨的）。

要記住最後一個密語對象，用 `hooksecurefunc(ChatFrameUtil, "SetLastTellTarget", ...)` —
hooksecurefunc 不會污染欄位，而且新的一定放在 `[1]`，一個變數就等價於
`GetLastTellTarget()` 的回傳。名字只拿去問 `issecretvalue`，不要讀。

## 能做的降級：幫玩家把 `/r` 填進輸入框

**結尾不能有空格。** `ChatEdit_ParseText` 只要看到空白就當場解析 REPLY，那次解析跑在插件
自己的髒堆疊上，一樣撞 `SetAttribute`。填 `/r`（無空格）→ ParseText 提早 return；玩家自己
打空格＋訊息那一下是引擎發動的**乾淨執行**，暴雪就填得進秘密名字了。

同理，`GetUnitName("target", true)` 對非隊友是秘密字串，插件不能代填 `/w 名字 `，
只能開 `/w ` 讓玩家自己打（Tab 補完還在）。

⚠⚠ **上面那段是「應該怎麼做」，不是現況。**（2026-08-28 體檢核對）
`MiliUI_ChatBar/Fix_ReplyTell.lua` 目前仍是 2026-08-24 `ea465fefb` 那一版：
**在檔案載入期無條件覆寫 `ChatFrameUtil.GetLastTellTarget`**，也就是這一節警告的那種做法。
`git log --follow` 這支檔案只有那一個 commit，設計改了但沒落地。

要嘛照這裡寫的改（預設完全不覆寫，只在 `issecurevariable("LAST_ACTIVE_CHAT_EDIT_BOX")`
回報已髒時才接手 `ReplyTell`，並提供「幫玩家填 `/r`、結尾不加空格」的降級），
要嘛實測確認鏡射法其實可行、回頭改這則筆記。**兩邊互相矛盾的狀態不要留著** ——
下次遇到密語問題會先花半小時在「到底哪個算數」。

同一次體檢一併修掉的是另一半：`ChatBar.lua` 的密語按鈕原本會代填 `/w 名字 `
（正是本節結尾禁止的那件事），已改成名字是秘密值就退回空的 `/w `。

相關：[[wow-121-secret-values]]、[[wow-121-unit-api-secrets]]、[[project-miliui-chatbar-snap]]
