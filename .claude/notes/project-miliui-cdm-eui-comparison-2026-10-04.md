---
name: project-miliui-cdm-eui-comparison-2026-10-04
description: 2026-10-04 三方冷卻管理器對照（我們 × EllesmereUI 9.3.4 × Ayije 3.92）——報告與 plan 位置、推薦清單的下場（F1～F8 當天全做完、「不做」清單後來翻了兩項）、效能結論與 E0～E3、對外怎麼講（兩邊都還沒實機數字）
metadata:
  type: project
---

2026-10-04 六個子代理通讀三支冷卻管理器後的對照報告在 `~/.claude/plans/miliui-cdm-analysis-2026-10-04.md`
（EUI 功能全清單含我們現況標記、Ayije 補充、推薦清單、效能對照與修法、對外說法）。

**推薦清單的下場**：報告推薦的八項當天全部做完——F1 格數上限＋溢出、F2 按鍵鏡射、F3 長條層數三件（層數當填充／刻度／五段換色）、
F4 層數門檻比較子、F5 休息中／載具中隱藏、F6 挑選器掃背包、F7 逐法術「缺少時顯示占位」（2026-10-06 併進「增益不在時」三態）、
F8 漸層／充能分段／垂直；plan 在 `~/.claude/plans/miliui-cdm-eui-features-2.md`。
上一輪拍板「不做」的六項（圖示形狀、快捷列發光、名條斷法、FakeActive、Shift 補位、同步到全部條）**後來翻了兩項**：
圖示形狀 2026-10-10 做成內建方／圓角／圓（H2，[[project-miliui-cdm-halo-borrow]]），光環格補位做成「只有光環格的條引擎補位」（H1）；其餘四項仍不做。
新功能提案先對報告第三節，別重提 🚫 的項目。

**效能結論**：兩家同路線（暴雪管狀態、閒置零 OnUpdate、計時交引擎）。EUI 在「不重算沒變的」成熟（世代計數、memo、
AnimationGroup ticker、`_cdmAny*` 單布林閘）；我們「有事才做」乾淨但單次成本高、垃圾多：Flush 每次全域工作、
RequestSource 無去重（增益 RefreshLayout ⇒ 2N+2 次）、Reapply 每顆 item 一次 Snapshot、Decorate 簽章每顆每次幾百 byte、
OverrideTable 每次回閉包、pandemic 掛勾每顆每幀 xpcall、征戰鏡射每幀永遠跑、whileReady 發光 alpha 0 仍 60fps。
十六條修法照報告第四節順序做成 plan `~/.claude/plans/miliui-cdm-perf.md`，**當天全部進 master**：
E0 `/mcdm perf` 計數（模組層級整數 +1；`reset` 記基準相減不歸零，因為 `Bars.flushes` 兼排版世代）→ E1 訊號重排（RequestSource 目標快取、Snapshot 一輪一次、
SpellIndex 只在認領變了才重建、重新取出只補做 `Viewers.CHEAP_REACQUIRE`）→ E2 設定簽章（`DB.overrideGen／customGen` 世代、EffectiveCustom 等三個 memo、`Decorate.Apply` 前置鍵；
**AfterCooldown 只去重倒數色＋formatter，轉圈色與邊緣暴雪每次刷新都重寫、不能去重**）→ E3 事件常駐（`SPELL_UPDATE_COOLDOWN` 只有 SpellIndex 一支處理器、
`D.cdWork` 清單、事件依紀錄動態註冊、征戰鏡射來源不可見時卸 OnUpdate）。細節在 README《設定讀取的 memo 與前置鍵》《效能計數》與《待實機驗證》的 E1～E3 段。

**E0～E3、F1～F8 全部未實機驗證、效能基準還沒量**（README《效能基準》仍是空的）：先 `/mcdm perf reset` → 一場首領戰 → `/mcdm perf`，
同角色同場景量 CPU／記憶體（`/miliui` 效能分頁）再跟 EUI 比。

**Why:** 使用者想對外主張「我們的 CDM 比 EUI 好」；沒有量測與對照表只會失信。
**How to apply:** 動 CDM 效能先讀報告第四節，先看 `/mcdm perf` 與 `/mcdm debug` 的 `B.flushes`／`SI.full`／`Catalog.builds`。
相關：[[project-miliui-cooldownmanager]]、[[feedback-skin-copy-ellesmereui]]。
