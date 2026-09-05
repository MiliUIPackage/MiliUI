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

## 2026-08-28：對過暴雪原始碼，並改成條件式接手

原始碼在 `Blizzard_ChatFrameBase/Shared/`（`ChatFrameUtil.lua` ＋ `ChatFrameEditBox.lua`），
逐字核對後的三件事：

1. **兩條路徑不一樣，這是整件事的關鍵。**
   - 按 R → `ReplyTell`：① `ChooseBoxForSend` →`GetLastActiveWindow()`→**讀 `LAST_ACTIVE_CHAT_EDIT_BOX`**
     ② `GetLastTellTarget()` 的 `value ~= ""` ③ `SetTellTarget` → `SetAttribute`
   - 打 `/r 訊息` → `ProcessChatType(msg,"REPLY",send)`：**只有 ②③，沒有 ①**
   ⇒ 全域髒掉之後 `/r` 仍然乾淨，那是唯一還活著的路。**不要碰它。**
2. `chatEditLastTell` 開檔就被 `""` 填滿 `MaxRememberedWhisperTargets` 格，所以 ② 的比較
   **每次都會跑**，不是「有紀錄才跑」。
3. 鏡射要掛 **`SetLastTellTarget`**，不是 `SetLastToldTarget` —— `GetLastTellTarget` 只讀
   `chatEditLastTell`，而那張表只有前者會寫；後者是另一組單格變數（記「我剛剛密語了誰」）。

**染髒路徑實測**（使用者 2026-08-28）：登入後
`/dump issecurevariable("LAST_ACTIVE_CHAT_EDIT_BOX")` → `true`；點一顆聊天列按鈕後 →
`false, "MiliUI_ChatBar"`。也就是說「這次登入還沒點過按鈕」是真的能達成的乾淨狀態。

⚠ **繞不過去**：`ActivateChat` 有 `editBox.disableActivate` 早退旗標（設了就不寫那個全域），
但設了輸入框根本不會啟用 —— 對聊天列毫無意義。**任何會替玩家開輸入框的插件都必然沾上。**

### 現行實作（改掉了 `ea465fefb` 那一版）

`ea465fefb`（2026-08-24）在檔案載入期**無條件覆寫 `GetLastTellTarget`**。那是在幫倒忙，
四種情境沒有一種比「什麼都不做」好，而且弄壞了三種原本會動的：

| 情境（對象名字是秘密值） | 無條件覆寫 | 什麼都不做 | 條件式接手 |
|---|---|---|---|
| 沒點過按鈕 → 按 R | ✗ 炸在 ③ | ✓ | ✓ |
| 沒點過按鈕 → `/r 訊息` | ✗ 炸在 ③ | ✓ | ✓ |
| 點過按鈕 → 按 R | ✗ 炸在 ③ | ✗ 炸在 ② | ◐ 填 `/r` 降級 |
| 點過按鈕 → `/r 訊息` | ✗ 炸在 ③ | ✓ | ✓ |

現在的做法：
- **預設什麼都不覆寫**，只用 `hooksecurefunc` 鏡射 `SetLastTellTarget`（不污染欄位）。
- `hooksecurefunc(ChatFrameUtil, "SetLastActiveWindow", …)` 在暴雪寫那個全域的當下檢查
  `issecurevariable`，**確定已髒才**接手 `ReplyTell`（那時候已經沒有可失去的東西）。
- 接手後仍然**只對秘密名字改行為**：污染的執行只對秘密值有意見，明文名字照樣讓暴雪跑完
  （`return original(chatFrame)`）。
- 秘密名字就填 `/r` 降級。⚠ `ParseText` 的早退條件已逐字確認：
  `if ( send ~= 1 and not parseIfNoSpaces and not strfind(text, "%s") ) then return end`
  —— 所以**結尾不能有空格**。
- **完全不再覆寫 `GetLastTellTarget`。**（接手之後 `ReplyTell` 根本走不到它；
  明文那條由原函式處理，比較安全。）

⚠ 還沒實測的一項：「呼叫被染髒的 table 函式欄位會不會染整段執行」——上表前兩列與末列
靠它。標準 taint 模型與這個 repo 的舊觀察（錯誤從 ② 移到 ③）都支持，但沒有現場重現過。
就算它是錯的，條件式接手在兩種答案下都不比舊版差，所以沒有等它的必要。

同一次體檢一併修掉的是另一半：`ChatBar.lua` 的密語按鈕原本會代填 `/w 名字 `
（正是本節結尾禁止的那件事），已改成名字是秘密值就退回空的 `/w `。

## 2026-08-29：另一條路 —— ChatThrottleLib 的流量統計掛勾

**跟回覆無關，玩家自己打 `/w 跨服玩家 訊息` 也會炸。** 症狀：

```
attempt to perform string conversion on a secret string value (execution tainted by 'Cell')
[Cell/Libs/AceComm-3.0/ChatThrottleLib.lua]:286
[C]: in function 'SendChatMessage'
```

`ChatThrottleLib.Hook_SendChatMessage`（`hooksecurefunc` 掛在 `SendChatMessage` 上，
純粹為了統計「不經過函式庫的流量」）做 `strlen(tostring(destination or ""))` ——
密語對象是秘密字串就當場報錯。**訊息其實已經送出去了**（post-hook），只是每次密語噴一行錯。

- 怪罪對象是「載入了那份 ChatThrottleLib 的插件」，不是它做錯什麼；錯誤訊息裡的插件名會誤導。
- 修法：`SafeStrLen()` 包一層 `issecretvalue`，秘密值回固定長度估值。
- **每一份 v31 副本都要一起改**（目前三份：MiliUI／Cell／BugSack；WarpDeplete 那份隨插件在 2026-09-05 移出套組），誰先載入誰贏。
- **不要改成從 MiliUI 覆寫 `ChatThrottleLib.Hook_SendChatMessage`**：那只是把污染來源從
  Cell 換成 MiliUI，而且污染會落在「玩家按 Enter 送出訊息」這條執行路徑上，得不償失。
  這種在函式庫內部、後面沒有保護呼叫的地方，就地補 guard 比掛勾乾淨。

相關：[[project-local-addon-forks]]

## 2026-08-29：第三條路 —— 輸入框上「留著的」秘密密語對象

**跟回覆也無關，按聊天列上隨便哪一顆按鈕都會炸。** 症狀：

```
ChatFrameEditBox.lua:679: attempt to perform arithmetic on a secret number value
                          (execution tainted by 'MiliUI_ChatBar')
[C]: in function 'UpdateHeader'   ← ActivateChat → SetFocus → ActivateChat
[MiliUI_ChatBar/ChatBar.lua]:354  ← ChatFrame_OpenChat("/i ", chatFrame)
locals: type="WHISPER", tellTarget=<secret string>
```

**新的通則：把秘密字串寫進 FontString，那個 FontString 的幾何也變成秘密。**
`ChatFrameEditBoxMixin:UpdateHeader` 的順序是

```lua
header:SetFormattedText(CHAT_WHISPER_SEND, tellTarget)          -- 標頭字串 → 秘密
local headerWidth = (header:GetRight() or 0) - (header:GetLeft() or 0)   -- 679：秘密數字相減
```

—— 量出來的 `GetRight()/GetLeft()` 是秘密數字，減法在髒堆疊上當場崩。
（暴雪自己跑這一段是乾淨的，所以只有插件開輸入框時才炸。）

三件事湊起來才會踩到：

1. 輸入框的 `chatType`／`tellTarget` **關掉之後仍然留著**（`OnShow` 的 `ResetChatType`
   只把 PARTY／RAID／GUILD／INSTANCE 退回 SAY，**不動 WHISPER**）。
2. `ChatFrame_OpenChat` → `ActivateChat` **一定**會呼叫 `UpdateHeader`，繞不過去。
3. 而我們給的文字（`/i `）要到**下一幀**的 `OnUpdate`（`editBox.setText = 1`）才被
   `ParseText` 解析成新頻道 —— 那是乾淨的執行，但輪不到它救，崩在前面。

⇒ 只要上一次密語的對象是秘密字串，**下一次按聊天列任何一顆按鈕都炸**，
錯誤行號指向暴雪的減法，跟被按的那顆是什麼頻道完全無關。

修法（`ChatBar.lua` 的 `ClearSecretTellTarget`）：開之前先洗輸入框 ——
`SetAttribute("tellTarget", nil)` ＋ `SetAttribute("chatType", "SAY")`。
- 清 `nil` 不受 AllowedWhenUntainted 影響（那條只擋**秘密值**寫入）。
- 退回 SAY 讓第一次 `UpdateHeader` 就走明文分支（`header:SetText(CHAT_SAY_SEND)`），
  不必賭「FontString 換成明文之後幾何會不會跟著乾淨」。
- 只在 `issecretvalue(tellTarget)` 時動手：明文名字照樣讓暴雪跑完，不必弄丟玩家狀態。
- 洗的要是 `ChatFrameUtil.ChooseBoxForSend(chatFrame)` 挑出來的那一個 ——
  classic 聊天樣式一律用預設視窗的輸入框，跟 `chatFrame.editBox` 不見得同一個。
- 輸入框**已經開著**的那條分支不必洗：`ParseText` 會先 `SetChatType` 才 `UpdateHeader`。

⚠ 順手發現的：`_G.ChatFrame_ReplyTell` 是載入期就抓好的**同一個函式物件**，
換掉 `ChatFrameUtil.ReplyTell` 這個 table 欄位對它沒有效果 —— 插件要呼叫回覆，
一律走 `ChatFrameUtil.ReplyTell`，不然自己裝的降級會被繞過去。
（同理 `ChatFrame_OpenChat` ≡ `ChatFrameUtil.OpenChat`：traceback 印的是全域名字，
函式本體卻在 `ChatFrameUtil.lua`，這就是直接別名的指紋。）

### 「已髒才接手」的閘只對按鍵 R 成立，插件自己呼叫要一律降級

上面那道 `issecurevariable("LAST_ACTIVE_CHAT_EDIT_BOX")` 閘的前提是「**乾淨的執行**下
暴雪自己跑得完」—— 那只適用於引擎發動的按鍵 R。**插件自己呼叫回覆**（聊天列的密語鍵右鍵）
從第一行就是髒的，全域乾不乾淨完全不影響結果，秘密名字照樣撞 ③ 的 `SetAttribute`。
所以自家入口（`ns.ReplyTell`）**不看 installed**，一律走條件式降級。
沒有這一層的話，「這次登入的第一個聊天列動作就是右鍵密語鍵」那一下必炸。

判準只要看**最後一個**對象：`GetLastTellTarget` 是

```lua
for i = 1, #chatEditLastTell do
    local value = chatEditLastTell[i]
    if ( value ~= "" ) then return value, chatEditLastTellType[i] end
end
```

`[1]` 非空就直接 return，後面幾格根本比不到（空格一律被 `SetLastTellTarget` 的搬移
擠到尾巴）。⇒ **只有 `[1]` 的秘密性會害人**，跟鏡射的 `target[1]` 一對一，不必掃整張表。

相關：[[wow-121-secret-values]]、[[wow-121-unit-api-secrets]]、[[project-miliui-chatbar-snap]]
