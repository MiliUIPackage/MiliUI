---
name: project-miliui-voidcore-currency
description: MiliUI 分身列表的虛無之核欄位改成從貨幣面板動態解析代碼，S3 只要補一個 ID
metadata: 
  node_type: memory
  type: project
  originSessionId: d9b96204-83cb-454f-942a-8fbc815e61e2
  modified: 2026-08-12T12:11:53.211Z
---

`MiliUI/Enhance/CharacterKeystones.lua` 的「虛無之核」欄位（分身列表，資料來自 Syndicator）不再寫死貨幣代碼。

- 候選清單 `SPARK_CURRENCY_IDS = { 3418 (Midnight S1), 3513 (S2) }`
- `ScanCurrencyListForSpark()` 走一遍角色貨幣面板，取第一個落在候選裡的 ID，快取在 `resolvedSparkID`
- 掃不到（分類收合／資料未載入）走 `FallbackSparkID()`，且不快取，下次刷新重掃
- 新賽季只要在候選清單補一個 ID 就好，不用改邏輯

2026-08 當下的實測：3418 出現在貨幣面板（數量 0），3513 沒出現但查得到數量 4；Wowhead PTR 把 3513 當正式貨幣。S2 正式開打後要回頭確認一次到底切到哪個。

**Why:** 每季換代碼、名字都一樣，寫死就每季要改一次而且容易挑錯那個。

**How to apply:** 動這個欄位前先跑 [[wow-find-season-currency-id]] 的兩行巨集確認現況。
