---
name: raidtarget-secure-action
description: Midnight(12.0) 起 SetRaidTarget 是戰鬥保護函式，插件標記要走 SECURE_ACTIONS.raidtarget 安全按鈕
metadata: 
  node_type: memory
  type: project
  originSessionId: cc16e63c-9253-4afc-a569-a9fbb5334038
---

12.0 Midnight 把 `SetRaidTarget` 變成（戰鬥）保護函式，插件程式在戰鬥中直接呼叫會被擋（Cell 的 Utilities/Marks.lua 有註解 "SetRaidTarget is protected on Midnight; skip in combat"）。

**Why:** MiliUI FocuserBar 的標記選單原本用 insecure `SetRaidTarget("focus", n)`，玩家點了沒反應。

**How to apply:** 用 `SecureActionButtonTemplate` + 屬性 `type1="raidtarget"`、`marker=1~8`、`action1="set"`（另有 toggle/clear/clear-all/set-unmarked，見 Blizzard_FrameXML/SecureTemplates.lua 的 SECURE_ACTIONS.raidtarget）、`unit="focus"`。含保護按鈕的彈出選單，開關要用 SecureHandlerClickTemplate 的 `_onclick` 快照 + `SecureHandlerWrapScript` postbody 收合（戰鬥中一般程式不能 Show/Hide 保護框架），母框架的 Show/Hide/拖曳要 InCombatLockdown guard + 延後到 PLAYER_REGEN_ENABLED。實作見 MiliUI/Enhance/FocuserBar.lua。

另外兩條相關規則（Focuser 重構時踩到）：
1. **11.0.2 起巨集/macrotext 裡的 `/click` 不能觸發「另一個巨集按鈕」**。要讓多個框架共用一份可熱更新的巨集，改用 `type="click"` + `clickbutton=<按鈕物件>` 委派（不受此限）。
2. `SECURE_ACTIONS.click` 的 `delegate:Click(button)` 不帶 down 參數＝只送「放開」邊緣；被委派的按鈕要照 BurstPotionHelper 配方：`pressAndHoldAction=true` + 同時設 `type`/`typerelease`/`type1`（macro 型對應 `macrotext`/`macrotextrelease`/`macrotext1`）才會恰好執行一次。鍵綁（會送下+上兩邊緣）不要直接綁在 pressAndHold 按鈕上（會跑兩次），綁到一顆 `type="click"` 中繼按鈕讓 cvar 門檻挑一個邊緣。
3. 受限安全環境（wrap snippet）可以在戰鬥中改保護按鈕的屬性（含 macrotext）——戰鬥中熱切換巨集就靠這個，把每種變體的巨集文字預存成格子屬性再 `fb:SetAttribute()`。

相關：[[project-focuser-castbar]]
