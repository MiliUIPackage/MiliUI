---
name: project-miliui-cdm-comparison-2026-10-19
description: 2026-10-19 三方冷卻管理器對照（MCDM 1.6.10 × EUI Cooldown Manager Standalone 9.6 × Halo 監控台 halo-108）——推翻上兩輪三個判斷（EUI 逐法術層其實是繼承、Halo 對暴雪 item 是就地認領、EUI 9.6 的 16.7 萬行是打包不是成長）、九項小功能建議、三件真正落後（沒實機數字／排版不跳過沒變的／沒設定搜尋）、對外說法修訂
metadata:
  node_type: memory
  type: project
  originSessionId: bc2b74ce-a481-48b8-a771-1e8eb5f9ed9a
  modified: 2026-10-19T05:35:33.865Z
---

報告在 `~/.claude/plans/miliui-cdm-analysis-2026-10-19.md`（六個子代理：EUI 一個、Halo 五個；只讀原始碼、未實機）。
上兩輪：[[project-miliui-cdm-eui-comparison-2026-10-04]]（EUI 9.3.4）、[[project-miliui-cdm-halo-borrow]]（Halo 2026-10-10）。

**三個被推翻的判斷（對外說法要跟著改）**：
1. EUI 的**逐法術**設定是 metatable 繼承（spell → 條（此專精）→ 條（全專精）→ defaults，`EUI_CDM_Store.lua` 393-419），不是複製；只有**條層**的「同步到全部條」才是複製。我們的差異是多一層主題、而且條層也繼承。
2. Halo 對四條暴雪檢視器的 item 是**就地認領**（ClearAllPoints＋SetPoint 到自己格位、不 reparent、不藏，`View/Bridges/Native.lua`），增益收合讀 item `IsShown`（秘密當不在）後重排；AuraContainer 只用在暴雪清單外的額外光環（FilteredAuras）與資源格；沒有 SetLayoutData、沒有刪版面。「三項只能拿兩項」仍成立，Halo 拿的是暴雪 item 版的「混排＋收合」，丟的是點擊與一般時間的 Edit Mode 拖曳。
3. EUI standalone 9.6 的 16.7 萬行是套組 parent＋選項層整包改名塞進單一 addon：引擎 35.6k → 38.8k 只多 3.3k，約一半是死碼。還發現建置改名漏洞：Migration／FirstInstall 用 `addonName ~= "EUICoreStandaloneCooldownManager"` 閘 ADDON_LOADED，真名是 `EUIStandaloneCooldownManager`（程式碼層面成立、實機未確認）。

**EUI 9.6 真正新的**：Also Show Below N 秒（隱藏常駐增益最後 N 秒浮出，每顆一個 NewTimer）、cdState 拆 hide／glow 道（形態外隱藏、就緒發光透明度、不管資源）、Bar Glows AND＋英雄天賦閘、Empty Slot 天賦條件、FramePool 選項頁框池、Unified Visibility Row。
**Halo 我們沒有的**：低等級隱藏、快捷鍵解析巨集、匯入預覽（列出會改到什麼＋只保存不分配）、Draft 交易（取消整批修改）、StorageBudget（節點數三級＋匯出字串上限）、音效規則的層數門檻／剩餘 N 秒、語音包註冊 API、扁平圖示比例、小隊框當錨點、CPUWatchdog 自動抓剖析。

**建議的九項小功能（報告第四節 B）**：巨集解析快捷鍵、「只在最後 N 秒浮出」、匯入預覽＋另存不切換、形態外隱藏、英雄天賦樹條件、層數門檻音效、低等級隱藏、設定視窗「還原到開啟前」、存檔預算。引擎可借：認領集合沒變就跳過排版（EUI `_prevIconRefs`）、AnimationGroup ticker、設定搜尋。
**不借**：Halo 的秘密值洗明文探針與 `SetCooldownToCategory`＋`SaveCurrentLayout` 改暴雪分類存檔；EUI 的 Edit Mode 鎖死、`UIParent:SetScale`、改全域字型。

**三家秘密值風險對照**：EUI 三處 `auraInstanceID ~= nil` 無守衛（9.6 未修）；Halo 留了 alpha／CheckButton 探針（無生產呼叫者）；MCDM `grep auraInstanceID ~= nil` 為 0。

**Why:** 使用者要知道 EUI 9.6 與 Halo 跟 MCDM 的功能差異、架構優缺點、MCDM 還能做什麼；上兩輪有三個判斷在這次通讀後站不住。
**How to apply:** 新功能提案先對這份報告第二、四節；對外講「我們比較好」照第五節，別再講 EUI 是複製、Halo 丟掉暴雪 item。效能相關仍以 [[project-miliui-cdm-eui-comparison-2026-10-04]] 的「先量」為前提，基準數字 2026-10-19 仍是空的。相關：[[project-miliui-cooldownmanager]]。
