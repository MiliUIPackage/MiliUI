---
name: wow-121-duration-objects
description: 12.1 秘密值倒數的通解 —— C_DurationUtil.CreateDuration + SetTimeFromStart 寫入，交給 StatusBar/Cooldown 由引擎驅動；絕不讀回
metadata: 
  node_type: memory
  type: reference
  originSessionId: de450f90-cdd7-4e1f-8c62-1e9716828626
  modified: 2026-08-17T19:56:28.063Z
---

**任何「起始時間＋持續時間」在 12.1 變成秘密值之後，倒數的通解是 duration 物件。**
插件全程只寫不讀，顯示由引擎負責。

```lua
local duo = C_DurationUtil.CreateDuration()          -- 建一顆，重複使用
duo:SetTimeFromStart(startTime, duration, modRate)   -- C 端 setter，吃秘密值
statusBar:SetTimerDuration(duo, nil, Enum.StatusBarTimerDirection.RemainingTime)
cooldown:SetCooldownFromDurationObject(duo)          -- 扇形＋原生倒數數字
cooldown:SetHideCountdownNumbers(false)              -- 讓引擎畫數字
```

過期不必自己算：`cooldown:SetScript("OnCooldownDone", …)`。**輪詢的 ticker 可以整個拿掉。**

## ⚠ 絕對不要讀回來

`duo:IsZero()`、`duo:GetTotalDuration()` 這類 getter 回的是**秘密值**，一做布林測試或
算術就炸。Plumber 的 `Modules/Shared/CooldownUtil.lua` 把整段 CreateDuration 註解掉並
標「Unusable in combat」—— 踩到的是 `IsZero()`，**不是** `SetTimeFromStart`。
分清楚這件事才知道這條路其實可以走。

## 從哪裡拿 duration 物件

- 有現成的就用現成的：`UnitCastingDuration` / `UnitChannelDuration` /
  `UnitEmpoweredChannelDuration`（施法條）、`C_Spell.GetSpellCooldownDuration`（法術冷卻）
- 沒有現成的就自己建：圖騰／召喚物（`GetTotemInfo` 沒有 duration 物件版本）、
  飾品冷卻（`GetInventoryItemCooldown`）—— 本機 Ayije_CDM 的 Trinkets／CustomBuffs 就是這樣

## 別忘了 modRate

`GetTotemInfo` 第 6 個回傳、`GetSpellCooldown` 的 `.modRate` 都是計時速率。
`SetTimeFromStart(start, duration, modRate)` 第三個參數就是它，漏掉的話被加速的
倒數會跟實際走鐘。

2026-08-18 用這招修好 MiliUI_UnitFrames「戰鬥中召喚物沒有倒數」。
暴雪自己的 TotemFrame 是在 Lua 算的（`math.ceil(GetTotemTimeLeft(slot))`），
那是 untainted 程式讀得到秘密值，插件不能照抄 —— 見 [[wow-121-secret-values]]。

相關：[[project-focuser-castbar]]、[[project-miliui-unit-frame]]
