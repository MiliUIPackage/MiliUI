---
name: wow-cdm-equipslot-stale-cache
description: 暴雪冷卻管理器的飾品格「有時變灰、沒給框」＝設定資料提供者的 isKnown 快取過期（API 已是 true）；不能從插件標髒
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
- 增益格（EquipSlotTracked）的 `linkedSpellIDs` 會帶出現在裝備的增益法術、`buffSlot` 標第幾個，即使暴雪沒給框也讀得到。

**How to apply:** 遇到「清單有、暴雪沒給框」的裝備欄項目，先看探針兩個值；修法走「我們自己畫」（飾品欄 kind=slot／光環格），不要想辦法讓暴雪重建。相關 [[project-miliui-cooldownmanager]]。
