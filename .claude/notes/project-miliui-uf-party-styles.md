---
name: project-miliui-uf-party-styles
description: MiliUI_UnitFrames 隊伍框架（party1-4，預設關）與樣式快速選擇（經典頭像／精簡條／頭像卡）的架構要點與待驗證
metadata:
  type: project
---

2026-11-27 加進 [[project-miliui-unit-frame]]：

**隊伍框架**（`7b0cbbe50`，使用者實機測過 OK 並已發佈）
- unitKey `party`、token party1-4、框名 `MiliUIUF_Party1..4`，不含自己、不做團隊（團隊交給 Cell）。`enabled = false`，新鍵靠 MergeDefaults 補，沒有遷移。
- **`uf.stackIndex` 是版面用的疊排索引**（所有 `MULTI_UNIT_KEYS` 的框都有）；`uf.bossIndex` 只剩 bossN 本身有，語意是「第幾隻首領」（Portrait 拿它對地城手冊 displayID）。新的多格單位一律讀 stackIndex。
- 顯示條件 `visGroup = "party"`：進團隊 party token 仍存在，靠閘框藏。被閘框藏住的框 IsShown 為真 ⇒ 距離與文字輪詢改看 `IsVisible`。
- 換人只靠 `GROUP_ROSTER_UPDATE` 比 GUID（`Core/Events.lua` 的 `RefreshPartyMembers`），換了才推 unitchanged 並 `Fire("PartyUnitChanged")` 重戳光環。
- 藏暴雪隊伍框：`PartyFrame` reparent、成員框與 `CompactPartyFrame` 只解事件；不 SetScript。
- 職責圖示 `icons.role`（只有 party 預設值有這個鍵），`UnitGroupRolesAssigned` 先 Desecret。
- 預覽：停用的單位不建孿生，勾起來時由 `Preview.Rebuild` 補建；party 四格固定假資料（`PARTY_SLOTS`）。

- 2026-11-27 使用者調整：光環比照目標框「上減益（開）、下增益（關）」，兩排 8×20＋7＝167 對齊框緣；格距 70。使用者說隊伍框「還沒發佈、不需要遷移」，改預設值直接改（自己的存檔用「恢復預設」或套「經典頭像」樣式吃到新值）。
- **隊伍的目標** `partytarget`（party1-4target，預設關）：90×22 短條、沒有頭像與光環，**錨定在對應的隊伍框上**（`frame.anchor = { on, to, side, x, y }`，永遠是表、不錨定是 `on = false`；第 n 格貼第 n 格；找不到宿主退回 frame.x/y；拖曳寫 anchor 的位移，見 `ns.AnchorHost`／`ns.DragDB`）。2026-11-28 起目標的目標／目標的目標的目標／專注的目標／寵物的目標／首領的目標也預設錨定在主框上：**DB v23 換算遷移**（`DB.ComputeAnchor`，預設值與遷移同一支；從兩框的座標、尺寸、縮放換算等價的 side＋位移，畫面位置不變；空隙超過 160 或首領兩排排法不同 ⇒ `on = false`；frame.x/y 不動當退路）。隊伍格距已改成容得下上下兩排光環（經典 93／精簡條 76／頭像卡 88）。隊友的 `UNIT_TARGET` 只在這種框生出來時才註冊（`ns.Events.WatchPartyTargets`），不進 `SCOPED` 的無條件名單。

**樣式快速選擇**（`c58d2c127`，合進本機 master，**版面數字未實機看過**）
- 樣式＝一包設定值，不是活的底層。`Core/Styles.lua`：`Build`（classic 就是 BuildDefaults）、`PRESERVE` 保留清單（唯一一張表）、`Compose`、`ApplyMany`／`Undo`（快照一層、只在記憶體）。支援 player／target／focus／party。
- 試穿：`Preview.SetOverride(unitKey, tbl, tag)` 讓孿生的 `uf.db` 指到臨時表；重指 uf.db 一律走 `TwinDB`。試穿中拖曳寫回存檔。
- 套用後寫 `udb.style`（不進預設值）。`BuildElements` 多一條：設定表裡沒有、框上卻建過的元件要收掉（專注目標的頭像卡借了頭像元件）。
- 使用者定案：樣式不改顏色方式；頭像卡在玩家與目標鏡像。我的決定（使用者未確認）：專注目標精簡條維持 120 寬、頭像卡 200×44；套用範圍只有「這個單位／四個支援的單位」。
- 設定頁按鈕用自己的 key `Apply style`（共用層的 `Apply` 在 zhTW 是「執行」）。

**設定視窗寬 728**（2026-11-28，原 700）：單位分頁左欄加寬 28 讓「目標的目標的目標」一行放得下，表單區 520 不變。

**隊伍框直排步距自動算**（2026-11-28，使用者指定）：`frame.autoSpacing`＋`ns.AutoStackStep`＝框與血條／能量條的範圍＋**有開的**增益／減益列＋`frame.stackGap`（設定頁的「間距」，預設 4，代表剩下的空隙）。`frame.spacing` 對隊伍框只剩備用。預設 Y 180。

**「某某的目標」不提供驅散類型邊框**（2026-11-28，使用者定案，DB v24）：戰鬥中不能對光環容器 Hide/Show ⇒ 換目標後重掃不了、邊框停在上一個目標。`ns.INDIRECT_UNIT_KEYS` 六個單位在 `DispelHighlight` 的 `IsOn` 一律回 false、設定頁不出那一節、v24 把存檔寫成關。同一個限制也影響這些框的增益／減益列（未處理）。
**Ping 標記**見 [[wow-ping-unit-detection]]（`global.pingFlash`，一般分頁）。

**玩家框底下那一疊跟隨與遞補**（2026-11-29，DB v25，使用者定案；未實機）：魔力小條／資源條／召喚物各有 `follow`＝`mpbar`（預設）｜`hpbar`｜`frame`｜`none`。左緣與寬度由 `ns.FollowSpan(udb, follow)` 從目標算（目標停用依序退回能量條→血條→框）；`none` 才用元件自己的 x／寬度（數字一直留著——使用者提過「0 代表 auto」，我建議不用魔術值、改用明確選項，他同意）。召喚物只對齊左緣、圖示大小不跟，編輯模式拖過就改成 `none`。遞補 `ns.StackShift`：上面那樣沒顯示就往上補它的 y，只有 follow 不是 none 而且「被補的位置在自己上面」才補；觸發點是魔力小條顯示切換、資源條列數變動、`ApplySettings("player")`（`ns.RestackBelow`，資源條受保護時延到脫戰）。v25：x＝8 且寬 200（召喚物只看 x）→ `mpbar`，改過的 → `none`。**同日使用者改定：沒有魔力小條時資源條與召喚物都不動**（多數職業平常就沒有魔力小條，補位等於把資源條往上搬 8）。遞補只剩一種：資源條不在時召喚物補到資源條的位置；`StackShift` 對 classpower 一律 0。
