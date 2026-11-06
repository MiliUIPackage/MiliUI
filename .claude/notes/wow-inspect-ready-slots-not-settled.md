---
name: wow-inspect-ready-slots-not-settled
description: INSPECT_READY 當下觀察對象的裝備格不可靠——物品還沒進客戶端快取的格子，GetInventoryItemLink 與 GetInventoryItemID 一起回 nil、跟真的空格分不開；第一次算齊的平均裝等不能直接信，要等值穩定並跟暴雪整數對帳
metadata:
  node_type: memory
  type: project
  originSessionId: ad889fc5-0a66-47fc-a54b-a83f5d79a818
  modified: 2026-11-04T05:26:50.464Z
---

**INSPECT_READY 當下讀觀察對象的 16 格裝備，物品資料還沒進客戶端快取的那幾格，`GetInventoryItemLink` 跟 `GetInventoryItemID` 會一起回 nil**，
跟「真的空格」在 Lua 端完全分不開。那一刻算出來的平均裝等就少掉那幾格，看起來卻是「每一格都讀到了」的完整答案。

**Why:** 2026-11-04 玩家回報 MiliUI_Tooltip 提示寫 237.9、觀察視窗（TinyInspect）寫 318，差距剛好是四格 0。
我們原本的流程是「有格子讀到 ID 沒 link 就重試、全部讀齊就當場存快取 15 分鐘」，所以第一次就錯的值會卡 15 分鐘。
別家早就踩過同一個坑：TinyInspect 原版 `InspectCore.lua` 的 `repeats = 3`（連續三次算出同一個值才收，本地 fork 改成 1 之後跟我們一樣會中），
MRT 的 `Inspect.lua` 在 INSPECT_READY 先把每一格的 link 摸一遍、再等 0.65～1.3 秒才真的讀。

**How to apply:**（`MiliUI_Tooltip/Modules/UnitInfo.lua` 的 `JudgePrecise`／`FinalizePrecise`）
- 算齊的小數先當**候選值**：同一個人、同一個值要連續 `PRECISE_SETTLE`（0.5 秒）沒變才收，每 0.25 秒看一次（值一變就重新計時）。
- 收之前跟 `C_PaperDollInfo.GetInspectItemLevel` 的整數對帳：差 ≥ 1 就不收（四捨五入最多差 0.5）；
  等到 5 秒還對不上就信暴雪的整數——「寧可少一位小數也不要算錯」。
- 別家插件觀察過、我們順手讀的那條路（`GetUnitItemLevel` 的 opportunistic 分支）**同樣要過候選期**，它的資料一樣可能還在到貨中；
  沒穩之前畫「??」、排一次重畫再看。
- 代價是別人的裝等晚 0.5 秒出現，不先畫整數（會先跳整數再跳小數，看起來在抖）。
- 相關：[[project-miliui-tooltip]]、[[project-tinyinspect-secret-guid]]
