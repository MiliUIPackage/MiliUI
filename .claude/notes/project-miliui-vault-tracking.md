---
name: project-miliui-vault-tracking
description: MiliUI 分身寶庫記錄的判準——解鎖只看 progress/threshold，M0 的 keystone level 是 0
metadata:
  node_type: memory
  type: project
---

`MiliUI_InfoBar/Core/WarbandPopup.lua` 的分身寶庫欄位（2026-09-05 從 MiliUI/Enhance/CharacterKeystones.lua 搬進資訊列）。2026-08-13 修掉「打了 8 場 M0、寶庫三格卻整排暗著」。

**根因不是 API 變動。** `C_WeeklyRewards.GetActivities` 一切正常，回的是 `progress=8 / threshold=1,4,8 / level=0`——M0 場次照樣計入寶庫，但**沒有鑰石等級，所以 level 是 0**。面板兩處判斷都寫成 `level > 0 and progress >= threshold`，於是整排判定成未解鎖。

- **解鎖判準只能是 `progress >= threshold`**（Blizzard 自己的判準），另外擋一下 `threshold > 0` 避免空軌道誤判。統一走 `IsVaultSlotUnlocked(slot)`。
- M+ 格子 level 0 顯示 `M0`、勇士軌道藍（`ITEM_QUALITY_COLORS[3]`），不要顯示 `+0`。
- **`C_MythicPlus.GetRunHistory` 不含 M0 場次**（它只回傳有鑰石的），所以「本週 M+ 紀錄 X/8」的 X 一定要取自寶庫 progress（`VaultMythicProgress`），清單行數則可能是 0 行。tooltip 的區塊顯示條件因此是 `count > 0` 而不是 `nRuns > 0`。

`Enum.WeeklyRewardChestThresholdType` 在 12.1 **沒有改**：`None=0 / Activities=1 / RankedPvP=2 / Raid=3 / AlsoReceive=4 / Concession=5 / World=6`，檔案裡的 `VAULT_TYPES = {mplus=1, pvp=2, raid=3, world=6}` 仍然正確。

**How to apply:** 玩家回報「寶庫沒亮燈」時，先去 `WTF/Account/<帳號>/SavedVariables/MiliUI.lua` 把 `MiliUI_DB.characterKeystones[*].vault` 撈出來看 progress/threshold/level 三個值——這比在遊戲裡試快得多，而且能直接分辨「API 沒資料」還是「顯示邏輯擋掉」。

相關：[[project-miliui-voidcore-currency]]、[[wow-find-season-currency-id]]
