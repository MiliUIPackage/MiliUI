---
name: wow-12x-addon-restrictions
description: 12.x 的插件限制系統：AddOnRestrictionType 六型別、聊天封鎖整趟 M+ 都算、連填聊天輸入框都被擋；巨集書裡的具名巨集是唯一能在 M+ 送聊天的路
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
`HasRestrictions = true` ＋ `RestrictedForMacroChatMessages = true`。
（12.0.5 把第二個回傳值 `lockdownReason` 拿掉了，只剩 boolean。）

### 巨集書裡的巨集是例外（2026-09-29 更正）

這條筆記以前寫「巨集也一樣被擋」，那是從 `RestrictedForMacroChatMessages` 旗標推的，
**錯了**。被擋的是插件 Lua 直呼 `SendChatMessage` 與安全按鈕的 `macrotext` 屬性；
**玩家巨集書裡的巨集**照暴雪 2026-03-01 的巨集規則走：遭遇戰中仍可送**隊伍專屬頻道**
（`/p`、`/raid`、`/i`），只是短時間連送會被擋、全隊都要在副本內；被禁的是公會、
自訂頻道等非隊伍頻道，`/say`／`/yell` 公告沒提。M+ 非首領時段是否套遭遇規則待實測，
但玩家的 `/p` 斷法巨集在 M+ 裡一直都能用。

⇒ 插件要「在 M+ 送聊天訊息」的唯一正路：**`CreateMacro`／`EditMacro` 把那行寫進巨集書
一顆具名巨集，SecureActionButton `type="macro", macro="<名字>"` 去跑它**（不是 macrotext）。
YUI_NovaToolbox 的 FocusHelper（保留巨集 `YUIQFocus`）、Midnight Groundmarker 都是這招。
代價：佔一格巨集、玩家看得到、`EditMacro` 戰鬥中不能呼叫（內容變動要脫戰才寫得進去）、
255 位元組上限、沒組隊時 `/p` 會噴系統錯誤。MiliUI_Focus 的宣告鈕已改成這條
（`Modules/AnnounceMacro.lua`），見 [[project-miliui-focus-addon]]。

⚠⚠ **封鎖期間連「把字填進聊天輸入框」都不准。** `ChatFrameUtil.InsertLink`、
對 `ChatFrame1EditBox` 的 `SetText` 都被擋 —— Auctionator `Utilities/InsertLink.lua`、
Baganator `Core/Utilities.lua`、Chattynator `Display/Buttons.lua` ＋
`Core/CommandHistory.lua` 每一處都先問 `InChatMessagingLockdown()` 才動手。
⇒ **沒有「幫玩家填好、他自己按 Enter」這條降級路**（那條在秘密名字的密語情境是可行的，
見 [[wow-121-chat-reply-secret-taint]]，但在聊天封鎖下不成立）。唯一能做的是把原文
`print` 在本地讓玩家自己打。

## 就位確認／開怪倒數：走巨集，不要直呼

`C_PartyInfo.DoReadyCheck`、`C_PartyInfo.DoCountdown` 在 API 文件上都是 `HasRestrictions = true`
（DoCountdown 另有 `SecretArguments = AllowedWhenUntainted`）。按鈕要在首領戰前、鑰石裡照樣能用，
就讓 SecureActionButton 跑暴雪自己的斜線指令：`/readycheck`、`/cd N`（`/cd 0` 取消）——巨集處理器
是暴雪的碼，從 secure 按鈕點下去是乾淨執行。自訂斜線指令再從 Lua 呼叫 DoCountdown 仍是插件端執行，
等於沒繞過。暴雪 `/readycheck` 本身還有一道閘：不是隊長或助理就安靜地什麼都不做。
實作：[[project-miliui-infobar]] 的確認倒數區塊。

## 症狀長什麼樣

不會回傳失敗碼，是**直接彈紅字封鎖對話框**（ADDON_ACTION_FORBIDDEN 那個），訊息還附上
一份限制狀態（`combat = true` 之類的欄位）。所以任何 `SendChatMessage` /
`SendAddonMessage` 之前都要**先問過再送**，不要賭。

在地實作：`MiliUI_Focus/Core/Init.lua` 的 `ns.IsChatRestricted()`（聊天）與
`ns.IsCommRestricted()`（addon message）兩個閘，宣告鈕被封鎖時壓暗＋tooltip 說明，
按下去改成把原文印在本地。

相關：[[wow-121-other-api-changes]]、[[project-miliui-focus-addon]]
