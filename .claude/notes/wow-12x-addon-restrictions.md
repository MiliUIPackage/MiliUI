---
name: wow-12x-addon-restrictions
description: 12.x 的插件限制系統：AddOnRestrictionType 六型別、聊天封鎖整趟 M+ 都算、連填聊天輸入框都被擋
metadata: 
  node_type: memory
  type: reference
  originSessionId: 25839858-5b5b-401d-ba97-e9fb21a52f66
  modified: 2026-09-07T18:07:40.986Z
---

Midnight 起遊戲有一套「情境式插件限制」，跟 taint／秘密值是**兩回事**：這是暴雪主動
把某些 API 在某些情境整組關掉，程式寫得再乾淨也一樣被擋。

## 型別與查法

`C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.X)`：

| 值 | 型別 | 生效期間 |
|---|---|---|
| 0 | `Combat` | 玩家正在參與戰鬥 |
| 1 | `Encounter` | 副本首領戰進行中 |
| 2 | `ChallengeMode` | **整趟未完成的鑰石**（不是只有戰鬥中） |
| 3 | `PvPMatch` | 未結束的 PvP 對戰 |
| 4 | `Map` | 該地圖本身套用插件限制 |
| 5 | `Chat` | 插件聊天通訊受限（12.0.5 新增） |

事件 `ADDON_RESTRICTION_STATE_CHANGED(type, state)`，`Enum.AddOnRestrictionState`
= Inactive / Activating / Active。時機跟 `PLAYER_REGEN_DISABLED/ENABLED` 一樣：
限制生效前一刻、解除後一刻。

⚠ **派送當下 `IsAddOnRestrictionActive` 對「正在變的那個型別」一律回 false**（官方文件
明寫）。要在事件裡重算 UI 狀態就得 `C_Timer.After(0, ...)` 延一幀，不然永遠讀到舊值。

## 聊天：`C_ChatInfo.InChatMessagingLockdown()`

問「插件現在能不能送聊天訊息」的正解就是它（MRT／Chattynator／Auctionator／
Baganator 全部只問這一個）。`SendChatMessage` 在 API 文件上是
`HasRestrictions = true` ＋ `RestrictedForMacroChatMessages = true` ——
**巨集也一樣被擋**，換寫法沒有用。
（12.0.5 把第二個回傳值 `lockdownReason` 拿掉了，只剩 boolean。）

⚠⚠ **封鎖期間連「把字填進聊天輸入框」都不准。** `ChatFrameUtil.InsertLink`、
對 `ChatFrame1EditBox` 的 `SetText` 都被擋 —— Auctionator `Utilities/InsertLink.lua`、
Baganator `Core/Utilities.lua`、Chattynator `Display/Buttons.lua` ＋
`Core/CommandHistory.lua` 每一處都先問 `InChatMessagingLockdown()` 才動手。
⇒ **沒有「幫玩家填好、他自己按 Enter」這條降級路**（那條在秘密名字的密語情境是可行的，
見 [[wow-121-chat-reply-secret-taint]]，但在聊天封鎖下不成立）。唯一能做的是把原文
`print` 在本地讓玩家自己打。

## 症狀長什麼樣

不會回傳失敗碼，是**直接彈紅字封鎖對話框**（ADDON_ACTION_FORBIDDEN 那個），訊息還附上
一份限制狀態（`combat = true` 之類的欄位）。所以任何 `SendChatMessage` /
`SendAddonMessage` 之前都要**先問過再送**，不要賭。

在地實作：`MiliUI_Focus/Core/Init.lua` 的 `ns.IsChatRestricted()`（聊天）與
`ns.IsCommRestricted()`（addon message）兩個閘，宣告鈕被封鎖時壓暗＋tooltip 說明，
按下去改成把原文印在本地。

相關：[[wow-121-other-api-changes]]、[[project-miliui-focus-addon]]
