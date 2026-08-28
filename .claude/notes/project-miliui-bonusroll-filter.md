---
name: project-miliui-bonusroll-filter
description: 星雲之核骰裝提示過濾（MiliUI/Enhance/BonusRoll_Filter.lua）——12.1 骰裝介面就是舊 BonusRollFrame、事件自帶 difficultyID/treasureContextLevel、+8 傳奇軌道門檻每季要驗
metadata: 
  node_type: memory
  type: project
  originSessionId: b9efe430-d012-44f1-bf6e-a8dbad34deee
  modified: 2026-08-27T13:12:01.350Z
---

MiliUI/Enhance/BonusRoll_Filter.lua（2026-08-27）：依內容類型隱藏星雲之核
（Nebulous Voidcore）骰裝提示。設定在 Tab_Enhance「星雲之核骰裝提示」區段，
DB 在 `MiliUI_DB.bonusRollFilter`。

**12.1 的骰裝介面就是 MoP 的 `BonusRollFrame`**，程式在
`Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua`（非 LoD，比玩家插件早載）。
流程：`SPELL_CONFIRMATION_PROMPT` → `GameEvent.HandleSpellConfirmationPrompt`
（Blizzard_Game/Mainline/EventImplementation.lua）→ confirmType 為
`Enum.ConfirmationPromptUIType.BonusRoll` 時呼叫全域
`BonusRollFrame_StartBonusRoll(spellID, text, duration, currencyID, currencyCost,
difficultyID, displayItemID, itemContext, treasureContextLevel)`。

- **事件自帶 difficultyID**，不用去猜玩家在哪：8=M+、15/16/233=英雄/傳奇/傳奇彈性團本、
  14/17/220=普通/隨機/故事團本、208=探究、0=開放世界（儀式地點）、250=世界團本。
  未知 ID 落入 hideWorld 桶（fail-hide，跟身分閘的 fail-open 是反向：這裡漏藏比多藏煩）。
- **treasureContextLevel** 是 12.x 新參數，給 `SetItemByID` 當 loot 預覽的層數
  （M+ 層數／探究層級）。M+ 層數三層備援：`C_ChallengeMode.GetChallengeCompletionInfo().level`
  → `GetActiveKeystoneInfo()` 第一個回傳 → treasureContextLevel；全拿不到 fail-open 顯示。
- 隱藏走暴雪自己的取消路徑 `BonusRollFrame_CloseBonusRoll()`（自帶 state=="prompt"
  檢查，多叫無害），hooksecurefunc 同步執行所以同幀移除、不閃。不代替玩家做決定。

**每季要驗**：`MPLUS_SHOW_MIN = 8`（+8 以上完賽獎勵是傳奇 Myth 軌道，2026-08 Midnight
S2 的規則，使用者口述）。新賽季軌道門檻若變就改這個常數。團本難度 ID 若再加新的
（如 233 傳奇彈性）記得補 RAID_ALWAYS_SHOW／RAID_NORMAL_BELOW。

相關：[[project-miliui-voidcore-currency]]（同一顆核心的貨幣代碼）、
[[wow-delve-detection]]（不靠 difficultyID 的探究偵測備援）
