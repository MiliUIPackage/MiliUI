---
name: wow-addon-profiler-cost
description: 插件效能數據的官方來源——C_AddOnProfiler 讀值免費，UpdateAddOnMemoryUsage 是全堆掃描；兩者的成本差了好幾個數量級
metadata: 
  node_type: memory
  type: reference
  originSessionId: 8a177b40-d970-4e2b-ae79-44e9ec6dde68
  modified: 2026-08-26T14:14:29.174Z
---

要做「哪個插件在拖慢遊戲」這種顯示時，CPU 與記憶體的成本天差地遠，不能用同一種
更新節奏。

## CPU：完全免費，隨便讀

`C_AddOnProfiler.*` 是 11.0.5 起的內建分析器。**測量本來就一直在跑**，不需要
`scriptProfile` CVar（那個舊 CVar 才是要重載又拖慢遊戲的那個），讀值只是查表：

| 函式 | 回傳 |
|---|---|
| `GetAddOnMetric(folderName, metric)` | 單一資料夾，毫秒 |
| `GetOverallMetric(metric)` | 所有插件加總 |
| `GetApplicationMetric(metric)` | **整個遊戲**（含原生 UI、繪圖），所以 `addon / application` 就是「佔幾成」 |
| `GetTopKAddOnsForMetric(metric, k)` | `{ addOnName, metricValue }`，引擎直接排好 |
| `IsEnabled()` | 分析器有沒有開 |

`Enum.AddOnProfilerMetric`（數值順序實測 = 文件順序，但一律用鍵名別寫死數字）：
`SessionAverageTime`（登入以來平均）、`RecentAverageTime`（最近 60 幀）、
`EncounterAverageTime`（首領戰期間）、`LastTime`（上一幀）、`PeakTime`（單幀最高）、
`CountTimeOver1Ms` … `CountTimeOver1000Ms`（超過 N 毫秒的幀數，卡頓次數就看這排）。

指標在 `/reload` 時歸零。多資料夾的插件要自己加總 —— 但 **`PeakTime` 不能相加**，
各資料夾的尖峰發生在不同幀，要取最大值。

## 記憶體：分兩種，成本差很多

- `collectgarbage("count")` → 整個 Lua 堆的 KB。**純讀計數器，免費**，可以每秒讀。
- `UpdateAddOnMemoryUsage()` → **全堆掃描做歸戶**，之後才能用
  `GetAddOnMemoryUsage(folder)` 拿到分插件的 KB。這一下是看得見的頓格
  （Cell 的 `Modules/OptionsFrame.lua` 把它註解掉，旁邊寫 "stuck like hell"）。

所以正確的節奏是：總量即時、分插件按需。開視窗時量一次（丟 `RunNextFrame`，
讓畫面先畫出來再卡那一下），之後靠按鈕手動或使用者自己勾自動，戰鬥中不要量。
官方 UI 的參考實作 NumyAddon/AddonProfiler 也是這樣做的（`OnShow` 才
`RunNextFrame(UpdateAddOnMemoryUsage)`）。

`GetAddOnMemoryUsage` 從 10.1.0 起查暴雪內部插件會**直接報錯**，逐筆 `pcall`，
或先過濾掉 `Blizzard_` 開頭的資料夾。

## 讀出來的數字要過濾

分析器可能整組不存在（舊客戶端）或被關掉，回傳也可能是 nan／inf。混進排序的比較
函式會讓 `table.sort` 行為無法預測（不是回傳錯結果，是可能直接爆
"invalid order function"）。一律 `pcall` ＋ `v ~= v`（nan）／`v == math.huge` 檢查
再用。

## ⚠ 數字算在誰頭上，取決於 frame 是「誰建的」

引擎把一個 script handler 的**整棵呼叫樹**，算在「當初呼叫 `CreateFrame` 建出那個
frame 的執行脈絡」所屬的插件頭上。**closure 寫在哪個檔案不算數，誰呼叫 `SetScript`
也不算數**——而且那個脈絡是像 taint 一樣從當下的引擎進入點繼承來的。

實務後果：在 `OnInitialize` / `OnEnable` 裡建的 frame，跑的是母插件的生命週期派送，
所以整個 session 都會算在**母插件**頭上。EUI 為此做了一個 90 個 frame 的池子在主
chunk 先建好，之後所有事件宿主都用 `TakeShell()` 領走而不是 `CreateFrame`
（`EUIStandaloneRaidFrames.lua` 的 shell pool，與 `_Ticker.lua` 的 `NewDriver`）。
出處是他們 2026-07-26 的實測註解。

兩個用途：(a) 自己的多資料夾插件要讓數字落在對的那個；(b) **看別人的數字時要知道
這件事**——母子拆包的套組，子模組看起來很省有可能只是成本記到母插件身上了。

實作在 [[project-miliui-perf-tab]]。相關：[[wow-frame-lifecycle-costs]]、
[[wow-unitframe-event-dispatch-cost]]。
