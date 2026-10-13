---
name: project-miliui-glow-vendor
description: MiliUIGlow —— 取代 LibCustomGlow 的自製發光引擎，走 vendor 複製不走 LibStub，唯一 source 在 MiliUI 本體；共用 driver 的三個要點、Attach API（引擎光環按鈕子樹用，宣告式動畫組）、秘密 alpha 不能讀回做算術
metadata:
  node_type: memory
  type: project
---

**自製插件要發光就複製 `AddOns/MiliUI/Libs/MiliUIGlow/` 整包過去，不要再 `LibStub("LibCustomGlow-1.0")`。**
唯一 source 在 MiliUI 本體，包內 `README.md` 是完整契約；消費者以 `ls -d AddOns/*/Libs/MiliUIGlow` 為準
（2026-10-14 是 MiliUI／Cell／MiliUI_CooldownManager／MiliUI_Focus，md5 全同）。改本體那份再跑
`python3 .claude/scripts/sync-widgets.py`（`VENDOR_FILES` 含這支）。

跟 [[project-miliui-widgets-vendor]] 同一套 vendor 哲學，外加一個 **LibStub 專屬的理由**：

> **LibStub 只留版本號最高的那一份，而且先到先贏**（`oldminor >= minor` 就退回 nil）。
> 套組裡光 LibCustomGlow 就有多份、同版本的誰贏取決於載入順序——**「改自己內附的那一份」很可能改到根本不在跑的那份**。
> 這種不確定性沒辦法除錯，而單體發佈更禁不起前置條件。

## 內容與差異

從 LibCustomGlow-1.0 **v25 fork**，**Start 系列 API 完全相同**，既有呼叫端只換綁定那一行
（`LibStub("LibCustomGlow-1.0")` → `ns.MiliUIGlow`，Cell 是 `Cell.MiliUIGlow`）。沒有 `Env.lua` 那種宿主接點——
掛在哪個表上靠 addon 的第二個 vararg 自動決定，**整包逐字複製、零修改**。

跟上游只有三處差別，其餘逐字不動（動畫長相因此必然一致）：

1. 不註冊 LibStub，改掛插件私有表。
2. 三個各自的 OnUpdate（`pUpdate` / `acUpdate` / `bgUpdate`）收成**一支共用 driver，閘在 60fps**（`GATE = 1/60`）。
   上游對每一個發光各掛一個沒有節流的 OnUpdate，成本跟玩家幀數成正比。`ProcGlow` 是 AnimationGroup 驅動的，本來就不經過這裡。
3. **Attach API**（2026-09-29，給 12.1 引擎光環按鈕子樹用），見下。

## driver 的三個要點（改的時候不要弄丟）

- **累積的 dt 整份往下傳**，累積器歸零而不是減掉 GATE——傳出去的 dt 總和等於真實經過時間，動畫速度才會跟逐幀版一致。
- **可見度閘是「還原上游行為」不是新增的最佳化。** 原本一個發光各掛一個 OnUpdate，祖先被隱藏時就自動不跑；共用 driver 要自己補。
- **可見度探測包 pcall，而且 `issecretvalue` 問在最前面。** 引擎光環按鈕子樹裡的 frame 可見度是秘密值（秘密布林進 `if` 是硬錯誤）；
  **一個會拋錯的訂閱者會讓整輪派送中斷，排在它後面的發光全部凍住**，所以拋錯就永久踢掉。

## ⚠ 不要讀回貼圖的 GetAlpha 做算術（2026-10-10，Cell 光環圖示實機崩潰）

`ButtonGlow_Start` 換色重啟原本 `f[texture]:GetAlpha() / 舊 alpha × 新 alpha`——宿主祖先鏈上有秘密 alpha 時
（Cell 的光環圖示在引擎子樹裡），**讀回來的 alpha 是秘密值，一做算術就炸**。各貼圖在那個時間點的 alpha 本來就是已知的
（OnFinished／OnPlay 照 `f.color` 寫死），正確做法是先換 `f.color` 再讓它們重寫一次，不回讀。
通則：**發光引擎對宿主子樹只寫不讀**，尺寸由 caller 給、alpha 自己記。

## Attach API（引擎光環按鈕子樹專用；2026-09-29，已實機）

Start 系列全靠池化框 reparent ＋ driver 推座標，在 12.1 光環秘密時子樹 forbidden，一條都過不了
（第一次寫入被拒、pcall 踢掉就停在最後一格——副本裡發光凍住的成因）。Attach 系列反過來：
- caller 在 initializeFrame 視窗內自備乾淨子框，引擎只在底下建全新貼圖（不用池、不 reparent），尺寸由 caller 給（子樹的 GetSize 可能是秘密值）。
- **宣告式 AnimationGroup，不是腳本**（照 DandersFrames）：在視窗內建好、Play 一次、不再碰，引擎在 C 端一直播。
  像素＝每條線一橫一直兩顆貼圖各一組（Translation 分段繞周長＋Alpha 保持換向，`BuildLegLoop`；兩個 `SetClipsChildren` 子框切 L 形）、
  閃耀＝每顆粒子一組繞周長、一般螞蟻線＝REPEAT FlipBook（5×5、22 格、48px）、**Proc 循環也自己播**
  （原本交 `AddAuraShownAnimation`，引擎一 Stop 就 alpha 1＋第一格＝整張圖集攤成一排小點，實機 09-29 中招）；只剩一般的入場閃光（一次性）交引擎。
- 重複 Attach 只改色；週期變了 Stop→改 Duration→Play；幾何變了重建（舊組 Stop 留著，動畫組刪不掉）。`Glow_Suspend`／`Resume` 對 Attach 型是 no-op。
- `lib.Glow_Regions(f)` 回 f 上所有會畫東西的貼圖（MaskTexture 不算），給 caller 交 `AuraButton:AddPandemicRegion`；
  無損刷新時機優先交整個 f（Frame 過得了 Region 檢查），退路才逐顆。caller 在 Attach **之前**設 `f._glowEngineShown = true`：
  交出去的貼圖 Shown 是 secret aspect，lib 從此不再 Show／Hide 它們、改寫 alpha。
- driver 裡的 `_glowBlind` 分支與 `pUpdate`／`acUpdate` 的 `fixedW` 分支是死碼（Start 系列一行不動的代價），留著。
- 第一個消費者是 Cell `RaidFrames/AuraDisplay.lua` 的 `StyleGlow`（走 AttachBuffContainer 的指示器）。
  Proc 小點那次已實機驗證；像素／閃耀／螞蟻線三種在副本內會動、FlipBook 切格、隱藏再顯示後接著播——沒有針對性回饋，視為上線中。

## 兩個閘要一起改

`MiliUI/Enhance/LibCustomGlow_FpsGate.lua` 管的是**別人的** LibCustomGlow（Ayije_CDM、BuffReminders、MRT 還在用），
掛勾版、只有閘沒有共用 driver。**兩邊的 GATE 值要一起改。**

## 上游更新

LibCustomGlow 出新版**不要直接覆蓋**：對 v25 做 diff，把實質改動搬進來，上面三處差別保持不變，再跑同步腳本、`md5` 對過。

相關：[[project-miliui-widgets-vendor]]、[[wow-unitframe-event-dispatch-cost]]、[[project-local-addon-forks]]、[[project-cell-auracontainer-rewrite]]
