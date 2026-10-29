---
name: wow-staticpopup-addon-show-taint
description: 插件 StaticPopup_Show 的彈窗開著時，暴雪任何 StaticPopup_Hide 呼叫端都被染髒（MDM 進副本重置提示 → 公會控制 C_Discord FORBIDDEN）
metadata:
  node_type: memory
  type: reference
  originSessionId: 3c12d57b-b320-42fe-aaed-240842578b28
  modified: 2026-10-20T13:56:21.406Z
---

12.1.5 的 `StaticPopup_Hide(which)` **沒包 securecall**，直接 `ipairs_reverse(shownDialogFrames)` 讀每個顯示中彈窗的 `dialog.which`。
插件呼叫 `StaticPopup_Show` 時，`dialog.which`／`dialog.data` 與 `shownDialogFrames` 的槽位（tInsertUnique＋table.sort）都在插件的 taint 下寫入。
⇒ **插件的彈窗還開著的期間，暴雪任何呼叫 StaticPopup_Hide 的程式都被染成那支插件**，之後碰到保護 API 就 ADDON_ACTION_FORBIDDEN 點名該插件。
（暴雪自己知道：`StaticPopup_Visible` 有包 `securecallfunction`，Hide 沒包。）

實例（2026-10-20，玩家回報）：`[米利的伤害统计] FORBIDDEN: IsUserOAuthed() / GetGuildLinkStatus() / UpdateDiscordServers() / UpdateGuildLobby()`，緊接「專精拾取已設置為」。
路徑：`Blizzard_Communities` RequiredDep `Blizzard_GuildControlUI`（所以開機就載入）→ 非會長收到 `GUILD_RANKS_UPDATE_ACTIVE_PLAYER` →
`GuildControlUI_Setup` → `SetupSelected(4)` → 先 `StaticPopup_Hide("CONFIRM_RANK_AUTHENTICATOR_REMOVE")`（染髒）→ `GuildControlUI_Discord_Update`（IsUserOAuthed、GetGuildLinkStatus）→ `ResetDiscordSettings`（UpdateDiscordServers、UpdateGuildLobby）。
髒源是 `MiliUI_DamageMeters/Meter/AutoReset.lua` 進新副本跳的原生 StaticPopup（timeout 0，一直掛著），進副本那一刻剛好撞上公會階級事件。四支名稱照 SetSelected(4) 的順序出現就是這條路。
**2026-10-29 已修**（1.3.6 之後）：AutoReset 改成自建框（提示皮＋W.CloseOnEscape，不掛 StaticPopupDialogs），同日另一位玩家的 `/mdm debug` 又報了 5 對 IsUserOAuthed／GetGuildLinkStatus，就是這條沒修的結果。

**How to apply:** 「憑空跳出來」、會掛在畫面上等人回答的提示（進副本、登入、事件觸發）不要用 StaticPopup，改自建框（共用層 `W.CreateConfirmPopup` 有整片滑鼠遮罩，不適合遊戲中途跳的提示）。
玩家自己按按鈕才開的確認框風險低，但同理。查 FORBIDDEN 時先把報出來的函式名丟去 wow-ui-source grep，用呼叫順序反推暴雪路徑。
相關：[[wow-121-addon-code-in-secure-stack]]、[[project-miliui-damagemeters]]
