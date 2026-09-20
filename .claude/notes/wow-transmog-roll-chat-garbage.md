---
name: wow-transmog-roll-chat-garbage
description: 團隊骰裝按「塑形」聊天印出 u、] 之類怪字元的成因——GlobalStrings 缺 _SELF 字串，客戶端把首領編號的原始位元組當訊息；含診斷時走過的四條錯路
metadata:
  type: reference
---

**症狀**：新團本骰裝之後聊天多一行 `u`、`]`、`\`，原文是兩個位元組（`75 0D`、`5D 0D`…），
事件是 `CHAT_MSG_LOOT`、顏色是戰利品綠。同一隻王永遠是同一個字。

**成因**：暴雪的缺陷，所有語系都有。骰裝的「你選擇了…」每一種都有全域格式字串
（`LOOT_ROLL_NEED_SELF`／`GREED_SELF`／`DISENCHANT_SELF`／`PASSED_SELF`／`NEED_SELF_OFF_SPEC`），
**唯獨 10.1 加的塑形沒有 `_SELF`**（只有 `LOOT_ROLL_YOU_WON_NO_SPAM_TRANSMOG` 與
`LOOT_ROLL_WON_NO_SPAM_TRANSMOGRIFICATION`）。客戶端找不到格式字串，就把第一個參數
（`lootHistory` 的首領編號）原樣當 C 字串丟出來：3445 = 0x0D75 → `"u\r"`。
**把那幾個位元組當 little-endian 整數解回來＝當場的 `|HlootHistory:N|h` 編號**，這是指紋。

**修法**：`MiliUI/Fix/Blizzard_TransmogRollChat.lua`——`CHAT_MSG_LOOT` 過濾器把 ≤4 位元組的
訊息重組成「你選擇了塑形：[物品]」，連結由 `RollOnLoot`／`ConfirmLootRoll` 後置掛勾排隊配對
（`rollType == 4` 是塑形；拾綁要等確認框那一下才算數）。治標，暴雪補字串後整支拿掉。

**Why:** 查了五輪才到位，錯路都很像真的：
1. 以為是「你放棄了」壞了——只因為怪訊息出現在需求／貪婪之後。**是 `RollOnLoot` 的 type 才說了實話。**
2. 「關掉全部插件就正常」是假陰性：那次沒按到塑形。
3. 「只有新副本」「同一天有時好有時壞」都不是環境差異：舊本外觀收齊了根本沒有塑形鈕；好的那幾場按的是放棄。
4. 懷疑骰裝隱藏（從 Lua 呼叫 `GroupLootContainer_RemoveFrame`）污染了 `rollID`——`issecurevariable(frame,"rollID")` 實測全乾淨。

**How to apply:**
- 聊天裡出現無意義的一兩個字元、又是暴雪事件管道進來的：先把位元組當整數解一次，對不對得上附近訊息裡的某個 ID。
- 懷疑某條客戶端訊息的格式字串：GlobalStrings 是 DB2，`https://wago.tools/db2/GlobalStrings/csv?locale=zhTW`（`enUS` 等同理）可以整張抓下來 grep，比在遊戲裡 `/dump` 猜鍵名快；**要同時對英文版，才分得出是在地化漏翻還是根本沒這條**。
- 12.1 的聊天過濾器註冊在 `ChatFrameUtil.AddMessageEventFilter`，回傳慣例不變（`false, newArg1, ...`），登錄表自己用 `canaccessvalue` 擋秘密值。
- 診斷聊天內容時 Chattynator 的 SavedVariables 是現成的黑盒子：每則訊息的原文、事件、顏色、角色都在，JSON 字串包在 `["data"]` 裡；**存的是修飾器套用前的原文**（修飾器跑在 `CopyTable` 上）。
- 使用者回報「關掉 X 就正常」時，先確認兩次測試按的是不是同一顆鈕。
