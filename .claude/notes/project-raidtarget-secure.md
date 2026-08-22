---
name: project-raidtarget-secure
description: Midnight(12.0) 起 SetRaidTarget 是戰鬥保護函式，插件標記要走 SECURE_ACTIONS.raidtarget 安全按鈕
metadata: 
  node_type: memory
  type: project
  originSessionId: cc16e63c-9253-4afc-a569-a9fbb5334038
---

12.0 Midnight 把 `SetRaidTarget` 變成（戰鬥）保護函式，插件程式在戰鬥中直接呼叫會被擋（Cell 的 Utilities/Marks.lua 有註解 "SetRaidTarget is protected on Midnight; skip in combat"）。

**Why:** 焦點標記選單原本用 insecure `SetRaidTarget("focus", n)`，玩家點了沒反應。

**How to apply:** 用 `SecureActionButtonTemplate` + 屬性 `type1="raidtarget"`、`marker=1~8`、`action1="set"`（另有 toggle/clear/clear-all/set-unmarked，見 Blizzard_FrameXML/SecureTemplates.lua 的 SECURE_ACTIONS.raidtarget）、`unit="focus"`。含保護按鈕的彈出選單，開關要用 SecureHandlerClickTemplate 的 `_onclick` 快照 + `SecureHandlerWrapScript` postbody 收合（戰鬥中一般程式不能 Show/Hide 保護框架），母框架的 Show/Hide/拖曳要 InCombatLockdown guard + 延後到 PLAYER_REGEN_ENABLED。實作見 AddOns/MiliUI_Focus/Modules/MarkBar.lua（2026-08-22 前在 MiliUI/Enhance/FocuserBar.lua）。

另外兩條相關規則（Focuser 重構時踩到）：
1. **11.0.2 起巨集/macrotext 裡的 `/click` 不能觸發「另一個巨集按鈕」**。要讓多個框架共用一份可熱更新的巨集，改用 `type="click"` + `clickbutton=<按鈕物件>` 委派（不受此限）。
2. `SECURE_ACTIONS.click` 的 `delegate:Click(button)` 不帶 down 參數＝只送「放開」邊緣；被委派的按鈕要照 BurstPotionHelper 配方：`pressAndHoldAction=true` + 同時設 `type`/`typerelease`/`type1`（macro 型對應 `macrotext`/`macrotextrelease`/`macrotext1`）才會恰好執行一次。鍵綁（會送下+上兩邊緣）不要直接綁在 pressAndHold 按鈕上（會跑兩次），綁到一顆 `type="click"` 中繼按鈕讓 cvar 門檻挑一個邊緣。
3. 受限安全環境（wrap snippet）可以在戰鬥中改保護按鈕的屬性（含 macrotext）——戰鬥中熱切換巨集就靠這個，把每種變體的巨集文字預存成格子屬性再 `fb:SetAttribute()`。

**標記巨集「不覆蓋既有標記」**：巨集條件式沒有「已被標記」這種判斷，但暴雪的 `/tm`
自己吃前綴（Blizzard_ChatFrameBase/Shared/SlashCommands.lua 的 TARGET_MARKER）：

- `/tm [@mouseover,exists] ~5` —— `~` ＝目標身上**已經有任何標記**就整行跳過
- `/tm [@mouseover,exists] !5` —— `!` ＝**已經是同一個標記**就跳過（避免 toggle 掉）

安全動作那邊的對應是 `action="set-unmarked"`（SECURE_ACTIONS.raidtarget）。
兩條都是引擎端判斷，戰鬥中成立、也不必讀 GetRaidTargetIndex。

**沒有「等於 N 才清」這種動作**（前綴只有 `!`/`~`，安全動作只有 set / set-unmarked /
clear / clear-all / toggle，巨集條件式也沒有團隊標記相關判斷），加上 12.1 的
`GetRaidTargetIndex` 回傳秘密值、Lua 端比不了編號 → **「換焦點時清掉舊焦點標記」
在戰鬥中無解**，只能無條件清（會清掉隊長標的）。焦點功能的這個選項因此整個移除：
被標的怪死掉標記就跟著消失，硬做不划算。不要再嘗試重做。

相關：[[project-focuser-castbar]]、[[project-miliui-focus-addon]]
