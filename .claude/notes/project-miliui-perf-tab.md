---
name: project-miliui-perf-tab
description: MiliUI 設定視窗的「效能監控」分頁——插件 CPU/記憶體儀表板，Options/Tab_Perf.lua
metadata: 
  node_type: memory
  type: project
  originSessionId: 8a177b40-d970-4e2b-ae79-44e9ec6dde68
  modified: 2026-08-26T14:14:59.025Z
---

`AddOns/MiliUI/Options/Tab_Perf.lua`（2026-08-26 新增，08-29 拆成子分頁）。設定視窗
第三個分頁，`/miliui perf` 或 `/miliui cpu` 直接開。SV 存在 `MiliUI_DB.perf`
（`metric` / `sort` / `desc` / `autoMem` / `page` / `lagWatch` / `lagMs`）。

版面（2026-08-29 定稿）：**CPU／記憶體兩個子分頁**（W.CreateButton + CreateButtonGroup，
跟視窗頂端分頁同視覺）。設計判準：CPU 講時間、記憶體講空間，兩個主題沒有互相解釋的
關係——之前記憶體散在卡片/表格欄/底部圖三處、控制按鈕又在別的角落，「零散」的根因是
主題被 widget 切散，不是空間不夠。
- **CPU 頁**：幀時間面板全寬（大數字＋插件佔比條＋FPS；右上角標當前指標，**單位跟著
  指標走**——尖峰指標下寫「最差的一幀」不是「每幀」，否則是在騙人）＋指標下拉＋
  卡頓記錄器勾選框＋原本的可排序清單（名稱/CPU 毫秒/佔遊戲/記憶體 MB，未動）。
- **記憶體頁**：總量面板（大數字＋**構成條**：亮段=插件歸戶、暗段=暴雪與未歸戶＋
  歸戶時間戳）→ 放大的趨勢圖（56px，標籤列左範圍右判決）→ 測量按鈕與自動測量 →
  記憶體清單：MB／長條／**變化欄**（跟上一次測量的差；持續＋=配置快的嫌疑犯、
  大筆−=GC 剛收走；快照在覆寫前**抄值不存參照**，否則差值永遠 0）／佔插件％。
  固定 MB 由大到小——記憶體只在測量時變，不需要動態排序，表頭是靜態標籤。
- 每個子頁只付自己的更新成本；面板骨架四列（標題+前提/大數字/圖形/註腳）共用
  `CreatePanel`。「已載入 63/68 資料夾」是靜態環境資訊，收在標題列右緣。
- 列工具提示：多資料夾明細、單幀尖峰、超過 10/50/100 毫秒的次數。

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
