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

## 卡頓記錄器（2026-08-29 新增，Options/LagWatch.lua）

儀表板回答「誰平常吃最多」，記錄器回答「**剛剛那一下是誰**」。常駐（預設開）：
每幀一次 `collectgarbage("count")` 讀取＋一次門檻比較（等於零成本）；某幀超過門檻
（預設 250ms）才掃全部已載入資料夾各讀一次 `LastTime`（**上一幀的逐插件毫秒帳單**，
這是 C_AddOnProfiler 唯一能做到「事件當幀歸因」的指標）。記錄 15 筆、聊天提示 30 秒
冷卻、讀取畫面/過場後 5 秒靜默。開關與門檻在 `MiliUI_DB.perf.lagWatch/lagMs`，
入口：分頁勾選框與 `/miliui lag`（on/off/<毫秒>/clear）共用 `ns.LagWatch.SetEnabled`。

**判決三分法與帳單形狀（實測 2026-08-29）**：
- 插件合計佔幀一半以上 → 點名榜首。**單一插件獨大＝它自己的鍋**。
- 記憶體單幀掉 ≥10MB → GC 大回收。**GC 步伐記在「正在配置的插件」頭上**，所以
  GC 幀的帳單長相是「一大群插件雨露均霑」（手動 full collect 5309ms 那幀：
  Platynator 500／Cell 233／百寶箱 217…）——別把攤派誤讀成集體發瘋。
- 兩者皆無 → 引擎側（讀圖/串流/shader），Lua 看不到。實測案例：1788ms 的幀
  插件合計只有 8ms —— 插件無罪的大頓真的存在。
- ⚠ GC 偵測要**往回多看一幀**取較深的下跌：回收若落在凍結幀採樣點之前，
  一幀差值跨錯邊界（實測漏掛過 100MB 的標籤）。用完歸零，免得餘震幀重複記帳。

相關背景：644MB 堆 = 544 活資料 + 100 浮動垃圾（2026-08-29 實測）；
「每 5 秒自動測量」的 UpdateAddOnMemoryUsage 全堆掃描在這種堆上是數十 ms 級，
打勾時聊天提醒一次＋工具提示橘字警告，帳會記在 MiliUI 頭上（判讀時要認得）。

## 還沒實測

寫完當下沒進遊戲驗過，要看的是：欄位在不同 UI 縮放下有沒有疊到、表頭跟資料列
對不對得齊、`GetApplicationMetric` 算出來的「佔遊戲％」數量級對不對
（`每幀毫秒` 那格應該要 ≈ 1000 ÷ FPS，對不上就是那個指標的語意跟預期不同）。

相關：[[project-miliui-widgets-vendor]]、[[feedback-ui-visual-style]]。
