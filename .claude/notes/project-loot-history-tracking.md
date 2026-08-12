---
name: project-loot-history-tracking
description: WoW 戰利品「擲骰/取得」記錄沒有 Blizzard 歷史 API，要自己用事件記錄
metadata: 
  node_type: memory
  type: project
  originSessionId: d3094719-cea3-46b2-8613-c150d3706fae
---

WoW 沒有任何 API 可讀取「歷史擲骰/取得了哪些裝備」。KeystoneLoot 也是自己用事件 + SavedVariables 記錄（`BONUS_ROLL_RESULT` → `Voidcore:SetUsed`，單一布林、不分難度天賦，只針對額外擲骰）。

關鍵事件都不含難度/天賦：
- `ENCOUNTER_LOOT_RECEIVED` → `encounterID, itemID, itemLink, quantity, playerName, classFileName`
- `BONUS_ROLL_RESULT` → `rewardType, rewardLink, ...`
- `C_EncounterJournal.GetLootInfoByIndex` 也沒有 collected/難度/天賦 欄位

要分難度/天賦必須在掉落當下自己抓：難度 `select(3, GetInstanceInfo())`；拾取專精 `GetLootSpecialization()`（0 = 跟隨當前專精，再用 `GetSpecialization`/`GetSpecializationInfo`）。只能記錄安裝後實際掉落，無法回溯歷史。

**How to apply（MiliUI_AdventureGuideSpecCompare looted.lua）：** v1.2 起【完全只讀 KeystoneLoot】，本插件不自行偵測/記錄。讀 `KeystoneLootCharDB.voidcore`（扁平布林、僅額外擲骰、無難度天賦、read-only）→ EJ loot row 與差異面板加「已取得」勾勾、tooltip 標「來自 KeystoneLoot（額外擲骰）」。沒裝/停用 KeystoneLoot 就沒資料、不顯示勾勾。指令 `/agsc looted`（開關）、`/agsc lootinfo`（看來源/件數）。

v1.1 曾自行用事件記錄含難度/天賦（`AGSCDB.looted[guid][itemID][diff][spec]`），但使用者決定移除、純靠 KeystoneLoot，下賽季若 KeystoneLoot 不再提供再自行實作（做法見 git 歷史 v1.1 looted.lua）。相關 [[project-itemupgrade-preview-icon]]。
