---
name: wow-cdm-equipslot-stale-cache
description: 暴雪冷卻管理器的飾品格「有時變灰、沒給框」＝設定資料提供者的 isKnown 快取過期（API 已是 true）；不能從插件標髒。MCDM 的出路：代畫缺框的格、增益法術從 linkedSpellIDs 解（暴雪沒給框照樣讀得到）、觸發增益＝全部扣掉使用效果（SlotUseBuffIDs 沒使用效果時會退回第 1 個增益，先判有沒有使用效果）
metadata:
  node_type: memory
  type: project
  originSessionId: e5eaa241-30c3-4f34-becc-d3208c949022
  modified: 2026-10-05T02:40:45.177Z
---

2026-10-05 實測（MiliUI_CooldownManager `/mcdm debug` 的「裝備欄」探針，`ns.Catalog.KnownProbe`）：
飾品使用效果格 198603（EquipSlotEssential，槽 13）`API=true 暴雪快取=false（髒=false）`，/reload 後 2 秒就這樣。

- 檢視器排版與面板灰不灰都讀 `CooldownViewerSettings.dataProvider.displayData.cooldownInfoByID[id].isKnown`，
  只在 SPELLS_CHANGED／PLAYER_EQUIPMENT_CHANGED／天賦專精變更／TABLE_HOTFIXED 時重建。登入建快取那刻 C 層判
  false，之後轉 true 卻沒有任何會讓它標髒的事件 ⇒ 一直缺框到換裝／改天賦。
- **不能從插件呼叫 MarkDirty 或寫 displayDataDirty**（暴雪會讀的欄位，污染整份 displayData）；連
  `GetCooldownInfoForID` 都不能叫（標髒時會就地重建）。探針只用 rawget 讀。
- 被動觸發型飾品（例：270173）的 EquipSlotEssential／Tracked 都是 isKnown=false、linkedSpellIDs 空：暴雪本來就不追，不是這個 bug。
- 增益格（EquipSlotTracked）的 `linkedSpellIDs` 會帶出現在裝備的增益法術、`buffSlot` 標第幾個，**即使暴雪沒給框也讀得到**
  （`C_CooldownViewer.GetCooldownViewerCooldownInfo(id)` 現讀）。

**How to apply:** 遇到「清單有、暴雪沒給框」的裝備欄項目，先看探針兩個值；修法走「我們自己畫」，不要想辦法讓暴雪重建。MCDM 已走的路（README 各小節）：
- **代畫**（《飾品格自己畫》）：清單上有、暴雪沒給框的裝備欄冷卻格由 `Custom.Proxy` 照飾品欄畫在原位置（diag `[proxy]` 不是 `[missing]`），暴雪恢復給框就換回去。
- **增益持續時間**疊在冷卻格上：一律 AuraContainer＋`includeSpellIDs`（`Catalog.SlotBuffIDs(slot, N)` ＝ EquipSlotTracked 那筆的 `linkedSpellIDs`），插件端零讀取
  （`GetAuraDuration` 首領戰／M+ 會拋錯）。「飾品欄增益」`kind = "slotbuff"` 也從這裡解。
- **觸發發光**（《飾品欄的觸發發光》，2026-10-12）：飾品沒有 OVERLAY_GLOW 事件，「觸發」＝這一格全部增益扣掉使用效果那幾個（`Catalog.SlotProcIDs`）。
  ⚠ `SlotUseBuffIDs` 在沒有使用效果時會**退回第 1 個增益**，純被動飾品的第 1 個增益就是觸發 ⇒ 先判「有沒有使用效果」（`C_Item.GetItemSpell`，資料沒到就空、不快取），有才扣。
- **被動飾品不顯示**（預設開）：判準同上（物品資料已載入、`GetItemSpell` 明文沒有使用效果）；空格不算、飾品欄增益不受影響。

實機狀態：探針結果是實測；代畫／增益疊層／觸發發光之後有多次玩家回報的修正（被動飾品也管飾品欄增益、固定格位上的暗圖示…）⇒ 已上實機，但 README 待驗小節沒有逐項勾。
相關 [[project-miliui-cooldownmanager]]；同類「暴雪快取過期插件標不了髒」見 [[wow-cooldownviewer-charge-cache-stale]]。
