---
name: wow-securegroupheader-refresh-snippet
description: 給 SecureGroupHeader 的格子掛額外的次要按鈕（寵物、目標）時，unit 只能在 refreshUnitChange snippet 裡派；Lua 端唯一的開關是「動 header 的任一個屬性」
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9a86fa22-8fc6-4603-9fa1-ecbc80f5596f
  modified: 2026-09-08T11:30:07.761Z
---

在 `SecureGroupHeaderTemplate` 的每一格旁邊掛一顆次要單位按鈕（寵物、該隊員的目標…），
機制只有一條路，Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua 讀出來的：

- `configureChildren` 對**每一個有顯示的**子框做 `SetAttribute("unit", ...)`，然後把子框身上
  `refreshUnitChange` 這個屬性當 snippet 跑（`CallRestrictedClosure`，`self` ＝ 那顆按鈕）。
  所以 snippet 裡 `unit` **永遠不是 nil**；用不到的格子是走另一段 `SetAttribute("unit", nil)`
  ＋ `Hide()`，**不會**跑 snippet —— 次要按鈕是它的子框，跟著被藏起來，不用自己清。
- snippet 的內容是 header 的 `_initialAttribute-refreshUnitChange`，在**子框建立當下**複製過去，
  所以要在 `header:Show()` 之前設好。次要按鈕用 `SecureHandlerSetFrameRef(playerButton, "x", b)`
  遞進去，snippet 裡 `self:GetFrameRef("x")`。

**Lua 端沒有等效路徑**，兩個理由：戰鬥中不能對保護框 `SetAttribute`，而換人正好在戰鬥中發生；
而且要從 Lua 讀回哪一格是誰，就得拿可能是秘密字串的 unit token 去比 `"player"`
（見 [[wow-121-unit-api-secrets]]）。

開關怎麼下：**`SecureGroupHeader_OnAttributeChanged` 對 header 的任何屬性改動都會呼叫
`SecureGroupHeader_Update`**（條件只有 `self:IsVisible()`）。所以 `header:SetAttribute("showXXX", ...)`
就足以讓整排 snippet 重跑一次、把 unit 重新派下去 —— 這是唯一的「立刻生效」手段。
header 隱藏時（單人、團隊）那次設定不會生效，但模板的 `OnShow` 也綁著 `SecureGroupHeader_Update`，
而且 `GROUP_ROSTER_UPDATE` 本來就會重跑，所以組起隊來自然補上，不用自己補呼叫。
⚠ 反過來說，值沒變就別重設：那是一次完整的 header 重排（每顆按鈕重新 SetPoint ＋ snippet 跑五次），
拖滑桿的時候一步一次會很痛。

順手的兩個坑：

- **`b.isSpotlight = true`**（Cell）名字看起來跟 Spotlight 綁死，實際語意是「這顆按鈕不擁有它顯示的
  單位」—— 只有它在擋 `Cell.vars.guids` / `Cell.vars.names` 的寫入。次要按鈕沒設這個旗標，
  隊友一選到隊員，`guids[隊員GUID]` 就會被改指到 `party2target`，所有走 GUID 路由的更新跟著跑錯地方。
- `partyNtarget` 這種複合 token **沒有事件**。Cell 的做法是 `refreshOnUpdate` 屬性掛上共用 tick
  driver（0.25 秒一次 `UnitButton_UpdateAll`）；自己那格用 `target` ＋ `updateOnTargetChanged`
  走 `PLAYER_TARGET_CHANGED` 就好。
