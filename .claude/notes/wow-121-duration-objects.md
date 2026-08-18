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

## ⚠ 「取得」可以，「測試」不行

`duo:IsZero()`、`duo:GetTotalDuration()` 這類 getter 回的是**秘密值**。關鍵分界是：

```lua
local zero = dur:IsZero()      -- ✅ 取得，沒問題
if dur:IsZero() then ... end   -- ❌ 布林測試，當場炸
```

Plumber 的 `Modules/Shared/CooldownUtil.lua` 把整段 CreateDuration 註解掉並標
「Unusable in combat」—— 踩到的是 `IsZero()` 的**測試**，**不是** `SetTimeFromStart`。
分清楚這件事才知道這條路其實可以走。

取得之後照 [[wow-121-secret-values]] 的「當傳遞者，不當讀取者」用掉就好：

```lua
local dur = C_Spell.GetSpellCooldownDuration(spellID)   -- 引擎給的物件
Eval(dur:IsZero(), 就緒色, 原色)                          -- 秘密布林直接餵曲線
```

Platynator 的 `Display/Utilities.lua` 用同一套做 CastBar 的打斷標記；
MiliUI_UnitFrames 的 `Core/Interrupt.lua`（斷法就緒染色）跟著抄。

### 回秘密布林的函式要多回一個**明文**旗標

自己包一層 `IsReady()` 之類的函式時，呼叫端一定會想知道「這次到底有沒有拿到值」。
如果只回一個值、讓呼叫端寫 `if ready == nil then`，那是拿秘密布林做**比較** —— 秘密布林
連布林測試都不准，比較更不用說，等於把炸點推給呼叫端。

慣例：`return ready, has` —— `ready` 可能是秘密布林（只准往下餵曲線），
`has` 由函式內部用明文算好（`pcall` 成不成功、spellID 有沒有），呼叫端只判斷 `has`。

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

## ⚠ 但「拿不到值」≠「不能有倒數」

這是最容易下錯的結論（2026-08-18 我下錯過一次）。**arm 成功之後倒數是引擎在跑的，
進戰鬥照樣繼續** —— 值在 arm 的那一刻就交出去了，之後不必再讀來源 API。

所以自己建的那條路仍然可用，只是要顧兩件事：

1. **已經 arm 好的不要重 arm。** 更新函式通常會整批重跑，戰鬥中重 arm 會失敗並把
   原本跑得好好的計時器清掉 —— 這才是「戰鬥中沒有倒數」的直接原因，不是 API 限制。
2. **戰鬥中沒 arm 到的，脫戰時補一次。** 那時來源值又變明文，而目標還在跑，
   補 arm 之後剩下的壽命就有正確倒數。

結果：戰鬥前開始的全程正確，戰鬥中開始的只是晚幾秒才出現倒數。

Stuf 用的是等價的手法（`b.endtime = GetTime() + safeRemain`，把秘密值 pcall 換算成
明文時間戳存一次，之後自己算）。⚠ 但它捕捉失敗時退回 `i * 20` 的**假倒數** ——
數字是編的，看起來卻很正常。不要抄那一段。

## ⚠ 「自己記秒數表倒數」也不行 —— 鑰匙拿不到

很自然會想：既然算不出來，那就記一張 spellID→duration 的表，自己從
`GetTime()` 倒數。**行不通**，而且理由不是精度問題：

`GetTotemInfo` 在戰鬥中**七個回傳全部是秘密值**（2026-08-18 逐一實測，包含
`icon`、`totemName`、`spellID`）。查表需要知道「是哪一個」，而秘密值不能當 table 的
key、也比不出相等。連「戰鬥外先學好 duration、戰鬥中查表」都不行 —— 查表的鑰匙本身
就是秘密值。

通則：**秘密值下不只讀不到「數量」，連「身分」也讀不到。** 任何「用身分查我方資料」
的設計都要先確認那個身分在受限情境下拿不拿得到。

## 秘密計時的第三條路：讓暴雪的框自己畫

如果連 arm 都做不到（來源值在需要的那一刻就是秘密），還有一招：**不要自己畫，
改造暴雪已經在畫的那個框**。暴雪的程式是 untainted，讀得到秘密值。

實例：官方冷卻管理員（CDM）的「追蹤的量條」在戰鬥中有正確的圖騰倒數
（`治療之泉圖騰` 等）。本機 `Ayije_CDM` 做的就是這件事 —— 它不自己算，
而是對暴雪的四個 viewer 改外觀與位置：

```lua
VIEWERS = {  -- Ayije_CDM/Core/Constants.lua
    ESSENTIAL = "EssentialCooldownViewer",
    UTILITY   = "UtilityCooldownViewer",
    BUFF      = "BuffIconCooldownViewer",
    BUFF_BAR  = "BuffBarCooldownViewer",   -- 追蹤的量條
}
```

判斷準則：**要「精確的秘密計時」就得寄生暴雪的框；要「自己排版的顯示」就只能接受
arm 不到時沒有數字。** 兩者不可兼得，別花時間找第三種。

而 `C_UnitAuras.GetAuraDuration(unit, auraInstanceID)` 回的是**引擎給的** DurationObject
（Cell/Indicators/Base.lua 用它 → `SetCooldownFromDurationObject`），所以**光環**類的
秘密計時是可以自己畫的 —— 受限的是「沒有 duration 物件 API 的東西」，例如圖騰槽。

## 別忘了 modRate

`GetTotemInfo` 第 6 個回傳、`GetSpellCooldown` 的 `.modRate` 都是計時速率。
`SetTimeFromStart(start, duration, modRate)` 第三個參數就是它，漏掉的話被加速的
倒數會跟實際走鐘。

2026-08-18 用這招修好 MiliUI_UnitFrames「戰鬥中召喚物沒有倒數」。
暴雪自己的 TotemFrame 是在 Lua 算的（`math.ceil(GetTotemTimeLeft(slot))`），
那是 untainted 程式讀得到秘密值，插件不能照抄 —— 見 [[wow-121-secret-values]]。

相關：[[project-focuser-castbar]]、[[project-miliui-unit-frame]]
