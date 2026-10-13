---
name: project-miliui-bonusroll-filter
description: 星雲之核骰裝提示的兩支強化（MiliUI/Enhance/BonusRoll_Filter.lua 過濾、BonusRoll_Confirm.lua 確認框）——12.1 骰裝介面就是舊 BonusRollFrame、事件自帶 difficultyID/treasureContextLevel、+8 傳奇軌道門檻每季要驗；確認框不走 StaticPopup、要高過 DIALOG+toplevel 的貪需視窗
metadata: 
  node_type: memory
  type: project
  originSessionId: b9efe430-d012-44f1-bf6e-a8dbad34deee
  modified: 2026-10-14T00:00:00.000Z
---

## 過濾：`MiliUI/Enhance/BonusRoll_Filter.lua`（2026-08-27）

依內容類型隱藏星雲之核（Nebulous Voidcore）骰裝提示。設定在 Tab_Enhance「星雲之核骰裝提示」區段，DB 在 `MiliUI_DB.bonusRollFilter`。

**12.1 的骰裝介面就是 MoP 的 `BonusRollFrame`**，程式在 `Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua`（非 LoD，比玩家插件早載）。
流程：`SPELL_CONFIRMATION_PROMPT` → `GameEvent.HandleSpellConfirmationPrompt`（Blizzard_Game/Mainline/EventImplementation.lua）→ confirmType 為
`Enum.ConfirmationPromptUIType.BonusRoll` 時呼叫全域 `BonusRollFrame_StartBonusRoll(spellID, text, duration, currencyID, currencyCost, difficultyID, displayItemID, itemContext, treasureContextLevel)`。

- **事件自帶 difficultyID**，不用去猜玩家在哪：8=M+、15/16/233=英雄/傳奇/傳奇彈性團本、14/17/220=普通/隨機/故事團本、208=探究、0=開放世界（儀式地點）、250=世界團本。
  未知 ID 落入 hideWorld 桶（fail-hide，跟身分閘的 fail-open 是反向：這裡漏藏比多藏煩）。
- **treasureContextLevel** 是 12.x 新參數，給 `SetItemByID` 當 loot 預覽的層數。M+ 層數三層備援：`C_ChallengeMode.GetChallengeCompletionInfo().level` → `GetActiveKeystoneInfo()` 第一個回傳 → treasureContextLevel；全拿不到 fail-open 顯示。
- 隱藏走暴雪自己的取消路徑 `BonusRollFrame_CloseBonusRoll()`（自帶 state=="prompt" 檢查，多叫無害），hooksecurefunc 同步執行所以同幀移除、不閃。不代替玩家做決定。

**每季要驗**：`MPLUS_SHOW_MIN = 8`（+8 以上完賽獎勵是傳奇 Myth 軌道，Midnight S2 的規則，使用者口述）。新賽季軌道門檻若變就改這個常數。
團本難度 ID 若再加新的記得補 `RAID_ALWAYS_SHOW`／`RAID_NORMAL_BELOW`。

## 確認：`MiliUI/Enhance/BonusRoll_Confirm.lua`（2026-09-24，預設開，`MiliUI_DB.bonusRollConfirm`）

按骰子鈕之前先問一聲並顯示目前的拾取專精——手滑或忘了切拾取專精就花掉核心，事後救不回來。只攔「擲骰」，放棄鈕不動。
`PromptFrame.RollButton` 是普通按鈕（OnClick＝`AcceptSpellConfirmationPrompt(spellID)`，不受保護），所以把它的 OnClick 包一層，按確定才跑原本那段。

- **確認框自己畫，不走 StaticPopup**：從插件 Lua 開 StaticPopup 會把共用的彈窗框寫髒，首領剛倒時暴雪自己的彈窗（拾取綁定確認之類）就得背這個污染。
- **strata 要 `FULLSCREEN_DIALOG`**（09-24 當天修）：貪需視窗（GroupLootFrameTemplate）與骰裝框都是 DIALOG＋toplevel，在 GroupLootContainer 裡往上疊、正好疊在確認框錨的位置；
  同層會被 toplevel 的點擊抬升蓋過去，所以要高一層。
- 高度依字高算（固定高會跟按鈕疊在一起）；可拖曳、位置存 `db.pos`（相對 UIParent 中心），沒存過就貼在骰裝框正上方；設定頁的「預覽」開的是**同一個框**（`pending.demo`），長相與位置跟實際一模一樣。
  一律 `SetClampedToScreen`（[[wow-login-screen-size-not-final]]）。
- 按確定時再核一次提示還在、而且還是同一個 spellID，逾時或換了一次提示就不送。

相關：[[project-miliui-voidcore-currency]]（同一顆核心的貨幣代碼）、[[wow-delve-detection]]（不靠 difficultyID 的探究偵測備援）、[[project-miliui-button-variants]]（確認框按鈕配色）
