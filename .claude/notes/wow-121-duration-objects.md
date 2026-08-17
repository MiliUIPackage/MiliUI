---
name: wow-121-duration-objects
description: 12.1 秘密值倒數的通解 —— C_DurationUtil.CreateDuration + SetTimeFromStart 寫入，交給 StatusBar/Cooldown 由引擎驅動；絕不讀回
metadata: 
  node_type: memory
  type: reference
  originSessionId: de450f90-cdd7-4e1f-8c62-1e9716828626
  modified: 2026-08-17T20:11:57.231Z
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

## ⚠⚠ 自己建的那顆**餵不進秘密值**（2026-08-18 實測）

`SetTimeFromStart(secretStart, secretDur, secretModRate)` 會**失敗**（pcall 回 false）。
`Cooldown:SetCooldown` 也一樣，而且訊息講得很白：

```
Usage: self:SetCooldown(start, duration [, modRate]).
Secret values are only allowed during untainted execution for this argument.
```

**這不是 API 沒想到，是刻意擋的。** duration 物件撐得住秘密計時，但那是**引擎在自己
那邊用明文建的**；從 Lua 餵秘密值進去建一顆是被禁止的。看到這句話就不用再找路了。

所以這條路分兩種情況，差別很大：

| 來源 | 秘密值下 |
|---|---|
| 引擎給的現成物件（`UnitCastingDuration` / `UnitChannelDuration` / `C_Spell.GetSpellCooldownDuration`） | **可用** |
| 自己 `CreateDuration` + `SetTimeFromStart` | **不可用**，只在明文（戰鬥外）成立 |

也就是說：**沒有現成 duration 物件 API 的東西，秘密值下就沒有倒數可做。**
圖騰／召喚物就是這種（`GetTotemInfo` 沒有 duration 物件版本），只能退回
「滿條、無數字」。飾品冷卻（Ayije_CDM 的用法）在戰鬥外正常，戰鬥中同樣受限。

值得留著自己建的那條路：戰鬥外仍然有好處 —— 不必自己輪詢、過期吃 `OnCooldownDone`。

## 別忘了 modRate

`GetTotemInfo` 第 6 個回傳、`GetSpellCooldown` 的 `.modRate` 都是計時速率。
`SetTimeFromStart(start, duration, modRate)` 第三個參數就是它，漏掉的話被加速的
倒數會跟實際走鐘。

2026-08-18 用這招修好 MiliUI_UnitFrames「戰鬥中召喚物沒有倒數」。
暴雪自己的 TotemFrame 是在 Lua 算的（`math.ceil(GetTotemTimeLeft(slot))`），
那是 untainted 程式讀得到秘密值，插件不能照抄 —— 見 [[wow-121-secret-values]]。

相關：[[project-focuser-castbar]]、[[project-miliui-unit-frame]]
