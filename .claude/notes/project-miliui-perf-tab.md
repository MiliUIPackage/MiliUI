---
name: project-miliui-perf-tab
description: MiliUI 設定視窗的「效能監控」分頁——插件 CPU/記憶體儀表板，Options/Tab_Perf.lua
metadata: 
  node_type: memory
  type: project
  originSessionId: 8a177b40-d970-4e2b-ae79-44e9ec6dde68
  modified: 2026-08-26T14:14:59.025Z
---

`AddOns/MiliUI/Options/Tab_Perf.lua`（2026-08-26 新增）。設定視窗第三個分頁，
`/miliui perf` 或 `/miliui cpu` 直接開。SV 存在 `MiliUI_DB.perf`
（`metric` / `sort` / `desc` / `autoMem`）。

版面：上排四張數字卡（插件 CPU＋佔遊戲％／FPS＋每幀毫秒／Lua 記憶體＋插件合計／
已載入資料夾數）、控制列（CPU 指標下拉、自動測量勾選、重新測量按鈕、上次測量時間）、
可點欄名排序的表頭、下面是一列一個插件的清單（圖示・名稱・CPU 毫秒・長條・佔遊戲％・
記憶體 MB・長條）。滑鼠移上去有工具提示：多資料夾的明細、單幀尖峰、超過 10/50/100
毫秒的次數。

## 幾個刻意的決定

- **成本紀律**：CPU 走 `C_AddOnProfiler`（讀值免費），記憶體總量走
  `collectgarbage("count")`，只有分插件歸戶才叫昂貴的 `UpdateAddOnMemoryUsage()`
  —— 開分頁時一次、按鈕、或自己勾自動（預設關，戰鬥中不量）。細節見
  [[wow-addon-profiler-cost]]。
- **分頁一關就完全停擺**：`OnUpdate` 掛在分頁 frame 上，`Hide` 之後引擎不派送；
  沒打開過連 frame 都不建。
- **數字每秒重讀、順序每 5 秒才重排**。每秒重排的話列會一直上下跳，玩家根本
  認不出自己剛剛在看哪一行。順序沒動的那幾秒直接改欄位文字，不走 `list:Update`
  （那支每列都 `ClearAllPoints` ＋兩次 `SetPoint`，六十列每秒重錨是白花的）。
- **條目沿用「插件總覽」的名冊**：helper 從 `Tab_Addons.lua` 匯出成 `ns.AddonInfo`
  （`GetInstalled` / `EntryMeta` / `EntryTitle` / `StripCodes`），HandyNotes 的九個
  資料夾算成一列。只列**這次真的載入了**的（停用的一律 0，列出來是雜訊）。
- **排序比較函式一定要有名稱決勝條件**：條目有一部分來自 `pairs(installed)` 走訪，
  順序本來就不固定，沒有決勝的話同為 0 的那一大票每次重排都換位置。
- **戰鬥遮罩不蓋這一頁**。`Options/Panel.lua` 多了 `READ_ONLY_TABS`，`ShowTab` 會
  重跑 `SetCombatLocked`。這頁是唯讀的，而且「首領戰平均」那個指標本來就是要在
  戰鬥中看的 —— 蓋住等於那個指標白做。
- **警語要住在自己的 frame 裡**。分析器被關掉時的紅字如果掛在分頁上，會被清單的
  列（子 frame）蓋掉，見 [[wow-frame-vs-texture-layering]]。
- **欄位幾何全用原始單位**（`SetWidth`/`SetSize`），因為 `SetPoint` 位移是原始單位。
  `P.Scale` 只留給 1px 細線與圖示。兩種單位混在同一排，非像素完美縮放下會互相疊到。

## 還沒實測

寫完當下沒進遊戲驗過，要看的是：欄位在不同 UI 縮放下有沒有疊到、表頭跟資料列
對不對得齊、`GetApplicationMetric` 算出來的「佔遊戲％」數量級對不對
（`每幀毫秒` 那格應該要 ≈ 1000 ÷ FPS，對不上就是那個指標的語意跟預期不同）。

相關：[[project-miliui-widgets-vendor]]、[[feedback-ui-visual-style]]。
