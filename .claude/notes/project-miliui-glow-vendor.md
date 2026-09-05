---
name: project-miliui-glow-vendor
description: MiliUIGlow —— 取代 LibCustomGlow 的自製發光引擎，走 vendor 複製不走 LibStub，唯一 source 在 MiliUI 本體
metadata:
  node_type: memory
  type: project
---

**自製插件要發光就複製 `AddOns/MiliUI/Libs/MiliUIGlow/` 整包過去，不要再 `LibStub("LibCustomGlow-1.0")`。**
唯一 source 在 MiliUI 本體，包內 `README.md` 是完整契約。（2026-08-27 建立，第一個消費者是 Cell。）

跟 [[project-miliui-widgets-vendor]] 同一套 vendor 哲學，外加一個 **LibStub 專屬的理由**：

> **LibStub 只留版本號最高的那一份，而且先到先贏**（`oldminor >= minor` 就退回 nil）。
> 套組裡光 LibCustomGlow 就有五份、其中三份同為 v25（Cell / BuffReminders / Ayije_CDM），
> 誰贏取決於載入順序 —— 也就是說**「改自己內附的那一份」很可能改到根本不在跑的那份**。
> 這種不確定性沒辦法除錯，而單體發佈更禁不起前置條件。

## 內容與差異

從 LibCustomGlow-1.0 **v25 fork**，**API 完全相同**，所以既有呼叫端一行都不用改，
只換綁定那一行（Cell 那次是十五個檔案各一行）：

```lua
-local LCG = LibStub("LibCustomGlow-1.0")
+local LCG = Cell.MiliUIGlow          -- 一般插件是 ns.MiliUIGlow
```

沒有 `Env.lua` 那種宿主接點 —— 掛在哪個表上是靠 addon 的第二個 vararg 自動決定的，
所以**整包逐字複製、零修改**。

跟上游只有兩處差別，其餘逐字不動（動畫長相因此必然一致）：

1. 不註冊 LibStub，改掛插件私有表。
2. 三個各自的 OnUpdate（`pUpdate` / `acUpdate` / `bgUpdate`）收成**一支共用 driver，閘在 60fps**。
   上游對每一個發光各掛一個沒有節流的 OnUpdate，成本跟玩家幀數成正比 —— 144fps 的機器
   付 60fps 機器的 2.4 倍，畫面一模一樣。`ProcGlow` 是 AnimationGroup 驅動的，本來就不經過這裡。

## driver 的三個要點（改的時候不要弄丟）

- **累積的 dt 整份往下傳**，累積器歸零而不是減掉 GATE —— 傳出去的 dt 總和等於真實經過
  時間，動畫速度才會跟逐幀版一致。
- **可見度閘是「還原上游行為」不是新增的最佳化。** 原本一個發光各掛一個 OnUpdate，frame
  或任何一層祖先被隱藏時就自動不跑；共用 driver 沒有這個性質，要自己補。註冊留著不動，
  所以重新顯示會自己接回去。
- **可見度探測包 pcall，而且 `issecretvalue` 問在最前面。** 12.1 之後位於引擎光環按鈕子樹
  裡的 frame 可見度是秘密值（把秘密布林放進 `if` 是硬錯誤），更新的 build 上則是呼叫本身
  就拋錯 —— **一個會拋錯的訂閱者會讓整輪派送中斷，排在它後面的發光全部凍住**，所以拋錯
  就永久踢掉。

## 兩個閘要一起改

`MiliUI/Enhance/LibCustomGlow_FpsGate.lua` 還留著，管的是**別人的** LibCustomGlow ——
套組裡還在用它的是 Ayije_CDM、BuffReminders、MRT。那支是掛勾版（在 `*_Start`
之後 `GetScript("OnUpdate")` 拿到更新函式再包一層），只有閘沒有共用 driver。
**兩邊的 GATE 值要一起改。**

## 上游更新

LibCustomGlow 出新版**不要直接覆蓋**：拿新版對 v25 做 diff，把實質改動搬進來，上面兩處差別
保持不變，然後 `ls -d AddOns/*/Libs/MiliUIGlow` 同步全部 copy，`md5` 對過。

相關：[[project-miliui-widgets-vendor]]、[[wow-unitframe-event-dispatch-cost]]、[[project-local-addon-forks]]


2026-09-05：`sync-widgets.py` 現在也同步這個單檔 vendor（`VENDOR_FILES`），改本體那份再跑腳本即可，不必手抄到 Cell。
