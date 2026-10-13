---
name: project-miliui-chatbar-snap
description: MiliUI_ChatBar 的磁吸／自適應寬度／右鍵選單：位置從 SetUserPlaced 收回自己存、吸附基準是內容底、下面放不下就翻到上面；設定頁「整組重套」害磁吸亂跳的成因；戰鬥中 taint 的兩條教訓連到通則
metadata: 
  node_type: memory
  type: project
  originSessionId: 9fef98ea-6774-4d27-8c9f-b9d323b656fa
  modified: 2026-10-14T00:00:00.000Z
---

快捷聊天列的位置與磁吸在 `Anchor.lua`，右鍵選單 `Menu.lua` 只剩 63 行的項目清單（引擎是共用層 `W.Menu`，[[project-miliui-widgets-vendor]]）；跨插件的磁吸走 `Libs/MiliUISnap.lua`（[[project-miliui-snap-bars]]）。

**位置從暴雪手上收回來。** 以前靠 `SetUserPlaced(true)` 讓暴雪存位置。要「錨在聊天視窗上」就不能這樣——暴雪只記絕對座標，兩邊都想管會互相蓋。
改成 `cb.Position = { attached, point, relPoint, x, y }` 存在 SavedVariables。`ChatBar.lua` 開頭那句 `SetUserPlaced(true)` **留著不是因為還在用**，而是要讓暴雪在載入時把舊玩家的位置擺回來，
`Anchor.Init` 在 `PLAYER_LOGIN` 抄一份進 DB（抄到的若剛好是程式寫死的初始值就當作「沒搬過」），抄完才 `SetUserPlaced(false)`。
「全部重置」的 `SetUserPlaced(false)` 一定要在 `ReloadUI()` 之前，否則暴雪會把舊位置寫回去。

**「跟著聊天視窗走」不需要 OnUpdate。** 直接 `SetPoint` 在聊天視窗那顆框上，錨點是引擎維護的。找那顆框見 [[wow-chattynator-chat-window-frame]]。

**磁吸只在放開的那一刻判定**：先上下（我方上緣 vs 它的下緣，或反過來），再水平（左對左／右對右，都不近就維持原本的水平位置）。比較一律先乘 `GetEffectiveScale()` 拉到螢幕座標，
寫回 SetPoint 的偏移再除回聊天列自己的 scale。按住 Shift 放開＝不吸。沒吸到聊天視窗才走 MiliUISnap 對齊其他框。

- **吸附基準是「內容底」不是框底**：Chattynator 把 `ChatFrame1EditBox` 錨在視窗框下緣、往下伸出框外一截。`ContentBottom(chat)` 取框下緣與輸入列下緣較低者；`ComputeSnap` 與 `Apply` 都用它。
- **下面放不下就改吸上面**：資訊列停靠推開 UIParent 之後，錨在 UIParent 底的聊天視窗下面沒空間，`SetClampedToScreen` 會把聊天列推回來蓋在聊天上。Apply 算「吸在下方的 bar 底 < UIParent 底」就 TOP↔BOTTOM 翻面，
  **只在套用時判斷、不寫回 DB**；視窗 `OnDragStop`、`UIParent` 的 `OnSizeChanged` 都掛勾重套。夾限也跟著 UIParent（`SetClampRectInsets`，[[wow-uiparent-inset-dock]]）。
- `/mcb debug` 印 bar／chat／輸入列的螢幕矩形、UIParent 邊界、Position 與現行錨點——吸錯先看這個。

⚠ **設定頁的 `Apply()` 是「整組重套一次」**，動任何一個滑桿都會走到 `Anchor.OnSettingsChanged()`。所以那支要自己記上一次的 `GroupWithChat`，**只在開關真的翻面時才動位置**——
否則玩家按 Shift 拖開的聊天列會在調下一格時莫名其妙又吸回去。

**自適應寬度**是兩段獨立開關：`MatchChatWidth`（總寬＝聊天視窗寬）、`AutoButtonWidth`（再由按鈕顆數平分）。只在橫向生效，兩個**預設都開**（沒做遷移——手動的 `ButtonWidth` 只是先不生效）。
整排靠 `startOffset = (barWidth - totalButtonWidth) / 2` 置中，順便把平分不盡的餘數吃掉；沒對齊聊天視窗時這個算式剛好等於原本的 `endPadding`。

**底色 `0x1A/255` @ 0.8**（`DARK_BG`），跟 DamageMeters、資訊列同一個值（[[project-miliui-hud-skin]]）。聊天列、聊天視窗、統計視窗會並排，三個灰必須一模一樣。這個值**沒有進 SavedVariables**，改了不需要遷移。

**「灰掉不能動」的那兩列走 `custom` spec，沒有動共用層**：`Controls.lua` 沒有 disabled 的概念，為了一支插件的兩條規則去動它等於全部消費者一起改。自畫標籤才灰得掉整列；
停用＝**變灰 ＋ 關掉滑鼠**，只變灰不關滑鼠是最糟的一種（看起來停用、拉下去卻真的會改到 DB）。（共用層後來加的 `requires` 只管 toggle。）

## 戰鬥中的兩條教訓（都已寫成通則，這裡只留指紋）

- **按鈕排成錨點鏈，尾巴的骰／開怪／重置是 secure 鈕 ⇒ 前面整排超連結鈕連坐成保護框**，戰鬥中頻道事件重畫時 `SetHitRectInsets` 被擋、跳「介面功能因插件而失效」（2026-09-21）。
  解法：每顆按鈕直接錨聊天列、偏移自己算；點擊矩形與右鍵穿透收進 `SyncMouseRect`，值沒變就不寫；戰鬥中寫不了的留給脫戰重排。細節與指紋在 [[wow-combat-drag-release]]。
- **即時通訊（im）聊天樣式下點按鈕報 `editBox nil`**：超連結收件框 Sink 一定要補 `editBox = DEFAULT_CHAT_FRAME.editBox`（2026-09-20 玩家回報）。見 [[wow-121-chat-reply-secret-taint]]。

相關：[[project-miliui-esc-menu-window-migration]]
