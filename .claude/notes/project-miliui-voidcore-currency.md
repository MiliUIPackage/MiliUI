---
name: project-miliui-voidcore-currency
description: MiliUI 分身列表的虛無之核欄位改成從貨幣面板動態解析代碼，S3 只要補一個 ID
metadata: 
  node_type: memory
  type: project
  originSessionId: d9b96204-83cb-454f-942a-8fbc815e61e2
  modified: 2026-08-12T12:11:53.211Z
---

`MiliUI_InfoBar/Core/Warband.lua` 的「虛無之核」欄位（戰隊資訊表格，資料來自 Syndicator；2026-09-05 從 MiliUI/Enhance/CharacterKeystones.lua 搬進資訊列）不再寫死貨幣代碼。

- 候選清單 `SPARK_CURRENCY_IDS = { 3418 }`
- `ScanCurrencyListForSpark()` 走一遍角色貨幣面板，取第一個落在候選裡的 ID，快取在 `resolvedSparkID`
- 掃不到（分類收合／資料未載入）走 `FallbackSparkID()`，且不快取，下次刷新重掃
- 新賽季只要在候選清單補一個 ID 就好，不用改邏輯

**2026-08-13 S2 開賽週實測結案：貨幣面板列出的是 3418 —— S2 沿用 S1 的代碼，沒有換新的。** 3513 是 PTR 期間從 Wowhead 抄來的（Wowhead 把 PTR 的追蹤用代碼當成正式貨幣），正式服不存在，已從候選清單移除：留著會讓 `FallbackSparkID()` 在它被標成 discovered 時挑錯，顯示錯誤的餘額。

教訓：**PTR 抄來的貨幣代碼一律當成「待確認」，賽季一開就要用兩行巨集回頭驗一次**，不要因為「Wowhead 有寫」就當定案。「每季一個新代碼」也不是鐵律 —— Midnight S2 就直接沿用了。

**Why:** 每季換代碼、名字都一樣，寫死就每季要改一次而且容易挑錯那個。

**How to apply:** 動這個欄位前先跑 [[wow-find-season-currency-id]] 的兩行巨集確認現況。
