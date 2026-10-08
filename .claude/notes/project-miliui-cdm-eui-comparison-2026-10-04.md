---
name: project-miliui-cdm-eui-comparison-2026-10-04
description: 2026-10-04 三方冷卻管理器對照（我們 × EllesmereUI 9.3.4 × Ayije 3.92）——報告位置、推薦功能、效能稽核的十六條修法、對外怎麼講
metadata:
  type: project
---

2026-10-04 六個子代理通讀三支冷卻管理器後的對照報告在 `~/.claude/plans/miliui-cdm-analysis-2026-10-04.md`
（EUI 功能全清單含我們現況標記、Ayije 補充、推薦清單、效能對照與修法、對外說法）。

**推薦新做（未拍板）**：格數上限＋溢出到別條、按鍵鏡射（EUI／Ayije 都有）、長條三件（層數當填充／層數刻度／多段門檻色）、
層數門檻比較子、顯示條件補休息中／載具中、挑選器掃背包可用物品、逐法術「缺少時顯示占位」。
上一輪已拍板不做的（圖示形狀、快捷列發光、名條斷法、FakeActive、Shift 補位、同步到全部條）沒再推薦。

**效能結論**：兩家同路線（暴雪管狀態、閒置零 OnUpdate、計時交引擎）。EUI 在「不重算沒變的」成熟（世代計數、memo、
AnimationGroup ticker、`_cdmAny*` 單布林閘）；我們「有事才做」乾淨但單次成本高、垃圾多：Flush 每次全域工作、
RequestSource 無去重（增益 RefreshLayout ⇒ 2N+2 次）、Reapply 每顆 item 一次 Snapshot、Decorate 簽章每顆每次幾百 byte、
OverrideTable 每次回閉包、pandemic 掛勾每顆每幀 xpcall、征戰鏡射每幀永遠跑、whileReady 發光 alpha 0 仍 60fps。
十六條修法照報告第四節順序；**實作 plan 在 `~/.claude/plans/miliui-cdm-perf.md`（E0 量測 `/mcdm perf` → E1 訊號重排 → E2 設定簽章 → E3 事件常駐）**，八組功能的 plan 在 `~/.claude/plans/miliui-cdm-eui-features-2.md`（F1 溢出、F2 按鍵鏡射、F3 長條層數三件、F4 比較子、F5 休息／載具、F6 背包清單、F7 逐法術占位、F8 漸層／充能分段／垂直）；**2026-10-04 十二個階段（E0～E3、F1～F8）全部由 Opus 做完、Fable 驗收後 commit＋merge 進 master（已 push，tag 20261009 內）；全部未實機驗證，清單在 README 待實機驗證 262～317，先打 `/mcdm perf reset` → 一場首領戰 → `/mcdm perf` 量基準（263、277）。****兩邊都沒實機數字**，先用效能分頁同角色同首領戰量 CPU／記憶體再講。

**Why:** 使用者想對外主張「我們的 CDM 比 EUI 好」；沒有量測與對照表只會失信。
**How to apply:** 動 CDM 效能先讀報告第四節並先量 `/mcdm debug` 的 B.flushes／SI.full／Catalog.builds；
新功能提案先對第三節，別重提 🚫 的項目。相關：[[project-miliui-cooldownmanager]]、[[feedback-skin-copy-ellesmereui]]。
