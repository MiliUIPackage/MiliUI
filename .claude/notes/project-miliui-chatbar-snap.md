---
name: project-miliui-chatbar-snap
description: MiliUI_ChatBar 的磁吸／自適應寬度／套組樣式右鍵選單（2026-08-25）：位置改自己存、SetUserPlaced 只留給搬家
metadata: 
  node_type: memory
  type: project
  originSessionId: 9fef98ea-6774-4d27-8c9f-b9d323b656fa
  modified: 2026-08-25T12:23:55.986Z
---

2026-08-25 給快捷聊天列加的三件事，檔案：`Anchor.lua`（位置／磁吸）、`Menu.lua`
（右鍵選單，引擎照 `MiliUI_DamageMeters/Meter/Menu.lua` 移植）。

**位置從暴雪手上收回來。** 以前靠 `SetUserPlaced(true)` 讓暴雪存位置。要「錨在聊天
視窗上」就不能這樣了 —— 暴雪只記絕對座標，兩邊都想管會互相蓋。改成
`cb.Position = { attached, point, relPoint, x, y }` 存在 SavedVariables。
`ChatBar.lua` 開頭那句 `SetUserPlaced(true)` **留著不是因為還在用**，而是要讓暴雪
在載入時把舊玩家的位置擺回來，`Anchor.Init` 在 `PLAYER_LOGIN` 抄一份進 DB
（抄到的若剛好是程式寫死的初始值就當作「沒搬過」，留 nil 走預設吸附），抄完才
`SetUserPlaced(false)`。

**「跟著聊天視窗走」不需要 OnUpdate。** 直接 `SetPoint` 在聊天視窗那顆框上，錨點是
引擎維護的，它被拖、被拉大就自動跟。找那顆框見 [[wow-chattynator-chat-window-frame]]。

**磁吸只在放開的那一刻判定**：先上下（我方上緣 vs 它的下緣，或反過來），再水平
（左對左／右對右，都不近就維持原本的水平位置）。比較一律先乘 `GetEffectiveScale()`
拉到螢幕座標，寫回 SetPoint 的偏移再除回聊天列自己的 scale。按住 Shift 放開＝不吸。

⚠ **設定頁的 `Apply()` 是「整組重套一次」**，動任何一個滑桿都會走到
`Anchor.OnSettingsChanged()`。所以那支要自己記上一次的 `GroupWithChat`，
**只在開關真的翻面時才動位置** —— 否則玩家按 Shift 拖開的聊天列會在調下一格時
莫名其妙又吸回去。

**自適應寬度**是兩段獨立開關：`MatchChatWidth`（總寬＝聊天視窗寬）、`AutoButtonWidth`
（再由按鈕顆數平分）。只在橫向生效，兩個**預設都開**（舊玩家一起，沒做遷移 —— 手動
的 `ButtonWidth` 只是先不生效，取消勾選就回得去）。整排靠
`startOffset = (barWidth - totalButtonWidth) / 2` 置中，順便把平分不盡的餘數吃掉，
右邊不會單獨留一條縫；沒對齊聊天視窗時這個算式剛好等於原本的 `endPadding`。

**底色 `#1A1A1A` @ 0.8**，跟 `MiliUI_DamageMeters/Core/DB.lua` 的 `DARK_BG` 同一個值
（源頭是 Chattynator Dark 樣式的預設）。聊天列、聊天視窗、統計視窗會並排，三個灰必須
一模一樣 ⇒ 改一邊要同步另一邊。這個值**沒有進 SavedVariables**（一直是寫死的），
所以改了不需要遷移。

**「灰掉不能動」的那兩列走 `custom` spec，沒有動共用層。** `Libs/MiliUIWidgets/Controls.lua`
沒有 disabled 的概念，而那包是逐字複製到七個插件的 vendor（見
[[project-miliui-widgets-vendor]]），為了一支插件的兩條規則去動它等於七個插件一起改。
自畫標籤才灰得掉整列；停用＝**變灰 ＋ 關掉滑鼠**，只變灰不關滑鼠是最糟的一種
（看起來停用、拉下去卻真的會改到 DB）。

相關：[[project-miliui-esc-menu-window-migration]]
