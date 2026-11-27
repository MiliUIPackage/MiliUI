---
name: wow-ping-unit-detection
description: 插件要知道「哪個單位被 ping」的唯一可靠做法是鏡射暴雪精簡團隊框上的 pingIconFrame（hooksecurefunc ShowPing／ClearPing）；事件收不到、聊天文字沒意義
metadata:
  type: reference
---

**結論（2026-11-28）**：鏡射暴雪自己的圖示。EllesmereUI 團隊框與 DandersFrames 都這樣做。

- `UNIT_PING_PIN_ADDED(guid, kit)`／`_REMOVED` 對插件是受限事件：RegisterEvent 不報錯但**一次都收不到**（實機探針，12.1.5）。唯一的消費者 `UnitPingIconFrameTemplate` 是 forbidden，插件建不出來。
- 暴雪每一格精簡框（`CompactRaidFrameN`、`CompactRaidGroupXMemberY`、`CompactPartyFrameMemberN`）上的 `cuf.pingIconFrame` 是普通物件。暴雪收到事件 → 對到那一格 → 檢查 CVar `showPingsOnRaidFrames` → 呼叫 `icon:ShowPing(kit)`／`icon:ClearPing()`。
  `hooksecurefunc(icon, "ShowPing", …)` 拿到 kit（字串，如 Attack／Warning）與 `icon:GetParent().unit`；圖用 `Ping_Frame_BG_<kit>`＋`Ping_Frame_<kit>`（先 `C_Texture.GetAtlasInfo` 查，技能類 ping 沒有框用圖）。掛勾時機：`hooksecurefunc("CompactUnitFrame_SetUpFrame", …)`＋登入／名冊變動掃一遍；跳過 `NamePlate*`；`icon:IsForbidden()` 為真就放棄。
- **前提是暴雪精簡框在背景活著**（名冊變動照樣排版、每格有正確單位）。EUI 的做法：容器解事件＋搬到隱藏父層，但 **`CompactRaidFrameManager` 只搬不解事件**，由它帶著容器排版。Cell 原本連 manager 一起解，所以收不到。
- 被 ping 的人在 pin 消失前換格，暴雪那顆收不到清除 ⇒ 鏡射要自己逾時（兩家都取 20 秒）。
- 聊天那條 `CHAT_MSG_PING`：`|A:ping_chat_<種類>:…|a`＋「名字」或「前綴：名字」，沒有 GUID、聊天受限時是秘密值。試過拿文字對名字，使用者定案「沒有意義」，已移除，別再做。

**我們的實作**（2026-11-29 使用者實機確認：五人隊伍、Cell 與單位框架都正常，**首領戰中照常顯示**；團隊尚未測）：
- `MiliUI_UnitFrames/Core/PingMark.lua`：`global.pingFlash`（預設開）、`pingFlashSeconds`（預設 3，最多閃幾秒）。開著時 `Core/HideBlizzard.lua` 不解 `CompactPartyFrame` 的事件。診斷 `/dump MiliUIUF.PingMark.stats`。
- `Cell/RaidFrames/PingMarker.lua`（直接寫進 Cell，本地分支修改）：`CellDB.general.pingMarker`（nil＝開），一般 → 可見性多一顆勾選框。開著時 `Cell/HideBlizzard.lua` 對 manager／`CompactPartyFrame` 只 Park（搬到隱藏父層＋SetParent 掛勾補搬），不解事件；關掉回到原本整組停掉。診斷 `/dump Cell.pingStats`。
- 兩邊對暴雪框只讀不寫（弱鍵表記帳）、hook 裡只排程到下一幀。開關都要重載才生效（解事件是單向的）。
- Cell 的標記框層級要在 `indicatorFrame`（按鈕 +220）之上，現用 +240；放 +120 會被名字遮住。
- 待驗證（團隊）：manager 活著時暴雪會不會把容器／管理員面板弄回畫面上；大團多跑一套暴雪框的效能；傳奇鑰石。
