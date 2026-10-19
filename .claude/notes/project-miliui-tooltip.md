---
name: project-miliui-tooltip
description: MiliUI_Tooltip — 取代 TinyTooltip 的自製滑鼠提示重寫版（物品／法術／單位走重繪面板）：taint 接觸面清單、架構決策、接管名單（含 FriendsTooltip 與 MiliUITip_API.Adopt）、v1 刻意捨棄的功能、戰鬥中秘密值與 Leatrix 殘留兩次破案的規則
metadata: 
  node_type: memory
  type: project
  originSessionId: 629d19ba-309f-41f7-aa47-258c1bee5d39
  modified: 2026-10-18T15:46:55.984Z
---

**MiliUI_Tooltip**（2026-08-22 一次寫完，`c01f3fde0`）：取代 `TinyTooltip-Remake` 的全新滑鼠提示插件，只支援 12.1+。
`AddOns/MiliUI_Tooltip/`，SV `MiliUI_Tooltip_DB`，namespace `_G.MiliUITip`，指令 `/mtip`（`reset`／`debug`／`log`／`logdump`）。
已發佈多版、玩家回報兩輪破案（見下），寫完當下列的八項「待遊戲內驗證」已不再有意義——沒有針對性回饋的只剩比價風暴下的實測 CPU 與 forbidden 情境（UIWidget 光環行）。

**Taint 圍堵設計**（核心賣點，接觸面清單維護在 `Core/Hooks.lua` 檔頭，要碰暴雪物件的新程式碼必須先過那張表）：
- 裝飾全在自己的 skin frame（tip 的 child、frameLevel = tip−1、SetAllPoints）：背景 1 貼圖＋邊框 4 貼圖＋漸層 mask＋大陣營圖＋血條＋3D 模型全掛這上面。
  **純貼圖零 SetBackdrop** ⇒ 沒有跟暴雪 SetBackdropStyle 的攻防戰（TinyTooltip ~195ms 效能地板的根源直接消失）；上色一律 SetVertexColor（吃秘密分量）。
- 暴雪物件上**零欄位寫入**：per-tip 狀態在 `Skin.State[tip]`（frame 當 key）。
- 入口只有 TooltipDataProcessor post-call（Unit/Item/Spell/UnitAura/Macro）＋ hooksecurefunc（SetDefaultAnchor、AddInstructionLine、SetAction/SetMacro、
  ItemRefTooltip.SetHyperlink、InspectUnit）＋ HookScript(OnTooltipCleared)。不換函式、不 SetScript 暴雪物件；每個入口先 `IsForbidden()` 閘，失敗方向＝該次顯示原味樣式。
- **不碰 EmbeddedItemTooltip**（UIWidget 會借走變 forbidden 的大宗）。接管清單 `TRACKED`：GameTooltip、ShoppingTooltip1/2、ItemRefTooltip、ItemRefShoppingTooltip1/2、NamePlateTooltip、
  **FriendsTooltip**（2026-09-26；它不是 GameTooltip，是繼承 TooltipBackdropTemplate 的普通 Frame，只換外觀、內容不經過 post-call）。
- **`MiliUITip_API.Adopt(tip)`**（`Api.lua`，2026-09-21）：給套組裡其他插件自建的 tooltip「交給我接管」套同一套提示皮（[[project-miliui-hud-skin]]）。
  只有提示插件 ⇒ 沒人叫 Adopt、那些框維持暴雪原樣；只有外觀插件 ⇒ API 不存在、MiliUI_Skin 退回自己畫一層（[[project-miliui-skin]]「特例二」）。
  2026-10-18 加第二參數 `opts.keepScale`：Adopt 預設會 `SetScale(general.scale)`，對「自己 SetParent 到 GameTooltip 底下」的框（AppearanceTooltip 的預覽）會變成平方倍 ⇒ 那種要帶 keepScale，旗標存 state、`ApplyBase` 重跑也跳過。同一天 `NeutralizeTemplateBar` 補了秘密名字閘（`GetName` 在秘密錨點鏈上回秘密字串，查 `_G` 會炸）。
- 一次性視覺中和：`NineSlice:SetAlpha(0)`（skin OnShow 重申）、`GameTooltipStatusBar:SetAlpha(0)`（載入時壓一次不夠，單位提示流程會弄回來 → `Bar.Activate` 每次重申）。
- 血條／模型層級要明寫 tip+1（skin 是 tip−1，child 放著會被 tooltip 背景蓋掉文字半截）。血條是自己的：`UnitHealthPercent(unit, true, ScaleTo100)` → SetValue(秘密)。
- **post-call 時序紅利**：行加在暴雪排版之前 ⇒ 不需要自我 Show()，比價重建風暴只剩重上色。Show() 只在 ProcessInfo 之外（目標行輪詢、非同步觀察刷新）呼叫。
- 輪詢走 `Skin.Poll`（`ns.Metro.New(0.05, ns.ReportError)`，共用層）並掛在「有沒有 tooltip 顯示中」上——沒有提示的時候 ticker 根本不存在。
  可見度判斷用**自己的 skin frame 的 OnShow/OnHide**（父層一藏子層就跟著發，零接觸面）。`Core/Secret.lua` 已刪，`ns.Secret` 由共用層提供（[[project-miliui-widgets-vendor]]）。

**設定介面**：MiliUIWidgets vendor，Panel 1000×520、左欄 340 固定放**即時預覽**、右欄捲動；分頁：樣式／玩家／NPC／物品與法術／錨點／設定檔（`fullWidth`，無預覽）／關於。
預覽＝自建 `CreateFrame("GameTooltip","MiliUITip_Preview",…,"GameTooltipTemplate")` 走 ns.TrackTip 進同一條管線（玩家預覽 SetUnit("player")、物品預覽 SetItemByID(19019)，NPC 預覽餵假 raw）；
設定改動 → ns.ApplyAll → Fire("SettingsApplied") → 重繪。顯示元素是**可拖曳方塊看板**（Tab_Unit.lua：列內排序／跨列搬移／拖到「不顯示」隱藏／點一下快速開關；列版面直接寫回 DB elements，DB 端 EnsureElementRows 健檢）。
法術的「按住修飾鍵顯示全部」要靠 MODIFIER_STATE_CHANGED 監聽補行＋Show——法術提示不像物品會被比價系統一直重建。
**成就點數不是秘密值**（先過 PlainNumber），colorfunc "achievement" 設為預設。**遷移鏈整個拔掉**（`DB_VERSION = 1`、`PROFILE_MIGRATIONS = {}`），預設值變動要使用者 `/mtip reset` 才吃到。
描邊 2026-10-03 起全套組統一五選一。

**v1 刻意捨棄**（要加回去時知道去哪找）：elements 的顏色/wildcard/filter 編輯 UI（DB 有、UI 只給 enable+icon 開關）、per-unit 錨點 UI（DB 有 inherit 結構、UI 只出全域）、
skinMoreFrames 大清單、BattlePetTooltip、LSM border、SavedVariablesPerCharacter、announcement、QuickFocus（使用者不要）、AutoSetTooltipWidth（賭 post-call 時序下引擎自己會量，實測沒出問題）。
設定介面說明不提 TinyTooltip（關於頁致謝除外，原作者 55510696）。

**切換**：TinyTooltip-Remake 整包從套組移除，`MiliUI/Enhance/LegacyAddons.lua` 的 REPLACED 加了 TinyTooltip-Remake → MiliUI_Tooltip（自動停用玩家殘留資料夾）。
**從套組移除插件時要同步列進 LegacyAddons**，不然解壓縮覆蓋的玩家永遠留著（Leatrix_Plus 與 MBB 就是漏列，2026-09-15 補上）。

## 戰鬥中敵方顯示成上一個友方（2026-08-23 log 破案，兩層）

① `tip:Show()` 會讓 tooltip **重新處理「儲存的上一份內容」**——目標行輪詢的 Show 把舊的 `unit="target"` 內容翻回來、重跑又把 `isUnitTip` 設回 true ⇒ 自我延續的舊資料迴圈。
規則：**任何會 Show 的輪詢都要先確認「目前內容是自己要更新的那個 token」**（`SafeValue(state.unit)=="mouseover"` 明文比對）。
② 世界游標的秘密 token 連 `UnitExists` 都回**秘密布林**（不能 truth-test）⇒ SafeBool 當 false 早退，敵方整個套不到文法。**存在性判斷要 fail-open**：只有明文 false 才退、秘密照畫。
診斷靠 `/mtip log`／`/mtip logdump`（Init.lua 的 ns.Log 記錄器，秘密值只標型別）。

**戰鬥中光環顯示法術 ID**：12.1 光環 tooltip 資料**不帶 `args`**（TinyTooltip 讀 `args[2].intVal` 是舊制）、`lines[1].tooltipID` 也是 nil，**spellId 在 `tooltipData.id`，戰鬥中是秘密數字**。
顯示走 format 傳遞（不可 tostring）；要明文的（坐騎查表、圖示 ID 解析）下游各自把關。`UnitInfo.JoinRow` 不可用 `table.concat`（秘密字串進去整列回 ""），已改逐段 format。

## 玩家回報「職業欄有時候不見」（2026-09-08～15，玩家 log 破案）

**成因在玩家端：殘留的 Leatrix_Plus（「Manage tooltip」）在我們寫完之後按固定行號就地覆寫第 1–3 行。** 本機重現不了。
現場指紋（`/mtip log` 的 pre/post 行掃描）：每行尾巴的 `|cffffffff|r` 是它的簽名；目標行有兩條——`選取目標: [名字]` 是**我們的**（暴雪 zhTW 的 `TARGET` 全域就是「選取目標」），`目標: 名字` 是 Leatrix 的。
⚠ 別把「選取目標」當成外來插件的指紋，一開始就判反過。第一輪 post 之後 0.06–0.15s 就被改、中間沒有 OnUnit/Apply（暴雪 ProcessInfo 一定先 ClearLines 再觸發 post-call，所以不是暴雪重建）；
只有觀察／成就資料到貨的 relayout 會把我們的行寫回去 ⇒ **快取過的玩家永遠壞**（玩家描述的「只出現一次」）。

**順帶修掉的自家 bug**：relayout 時行已經是自己寫的，`GetOriginalSpecLine` 找「含職業名的最短一行」會抓到自己的職業列 ⇒ 整列塞回職業欄、畫面重複一次。
規則：**relayout 不可從 FontString 文字推斷任何東西**，只吃第一輪（post-call）存下的快取。

**被否證的假設**：secret aspect（`SetText(秘密)` 讓行的 GetText 永久回秘密）——玩家 log 全行 `aspect=false`，脫戰同陣營時 name/class/guid 全明文。`HasSecretAspect("Text")`／`HasSecretValues()` 在 FontString 上回明文布林，探針可用。

## 重繪面板（2026-10-18，`Panel/`，commit 289a46807；plan `~/.claude/plans/miliui-tooltip-panel.md`）

**物品／法術／配方三型改走「重繪面板」，單位／光環／巨集維持就地改寫一行未動。** 參考對象是 WoW Forever 的 PrettyTooltip（MIT，本機 `Interface/tmp/PrettyTooltip/`）：
它鎖 enUS、資料表全是永恆版所以不能直接用，但它是照 12.x 引擎寫的、排版骨架可搬；法術係數／DPM／分解／剝皮那些是客戶端資料表硬編，正式服沒 API，**不搬**。

- **做法**：原生 tooltip 留著當替身——`SetAlpha(0)`、`SetPadding(right, bottom, left, top)` 撐到跟 panel 一樣大（暴雪的比價定位、夾邊、游標跟隨全照原生框算，一行定位都不用重寫），
  旁邊畫自有 panel（parent UIParent、strata 讀 tip 的、level = tip+5 並在輪詢裡跟著抬——ItemRefTooltip 是 toplevel，點了會抬層，不跟的話 alpha 0 的原生框會吃掉 panel 上 × 的點擊）。
  接觸面 #10（SetAlpha／SetPadding）、#11（`ItemRefCloseButton:Click()`）；**P0～P3 零 hooksecurefunc**，尺寸貼合走 `C_Timer.After(0)`＋`Skin.Poll` 0.1 秒。
- **退路＝退回現有樣式**：任何一行文字／型別／顏色／lineIndex 是秘密、GetPoint／GetLeft／GetWidth／GetPadding 回秘密、讀不出名字、render 出錯、內嵌物品框或 BottomFontString 顯示中（暴雪自己在用 padding）
  → 不藏原生、不顯示 panel。開關關掉時對 tooltip 零寫入。
- **同一件物品的重建當幀不重畫、延一幀 Reconcile**（實機第一輪抓到的閃爍，commit 98a430937）：比價框每次重建是 `ClearLines → ProcessInfo（我們的 post-call 在這裡）→ 同一幀再 AddLine 補「若你更換此裝備…」`
  （TooltipComparisonManager:SetItemTooltip 第 236～290 行），別家插件的 post-call 也排在我們後面同一幀加行 ⇒ post-call 當下畫一定少行；每秒二十幾次重建兩版交替＝閃爍。
  規則：key（型別＋明文 id）相同且 panel 顯示中 → 只重壓 alpha／Fit、排 `C_Timer.After(0)` 對帳；對帳重讀行比指紋；**行數比看過的最多還少＝部分版不准蓋完整版**，連續 0.3 秒才接受（修飾鍵放開、冷卻行消失要能變少）。
- **抖動的結構性規則**（實機第二、三輪，commit c96e0a5c1）：同一次停留裡內容本來就會變好幾次（暴雪第一版還沒載法術說明行、別家插件的「x1」、按 Shift 的 ID 行），背包每 0.2 秒重設讓它們輪流出現 ⇒
  個案修不完，改規則：**同一件停留期間 panel 寬與原生替身高只長不縮**（換一件歸零）；**行數變多立刻補齊，行數變少或同行數內容變了要連續 0.3 秒才採用**（A／B 輪流永遠到不了）；
  **panel 貼原生被錨定的那一角**（跟隨游標與固定右下都是下錨，原生高度暫時不對時下緣不動）；**padding 被 SetOwner／ClearLines／OnShow 清掉當幀補回上次的值不重算**（那一幀 GetHeight 是舊的）；
  暴雪的 `Show()`／`SetShown` 會把 alpha 改回 1 且在 post-call 之後 ⇒ `hooksecurefunc(tip,"Show"/"SetShown")` 後掛勾當幀壓回（接觸面 #12，只做 SetAlpha／SetPadding）。
  **比價面板不貼自己的原生、鏡射貼主提示的面板**（原生 `TOP→GameTooltip:TOP`／`RIGHT→GameTooltip:LEFT` 照同樣的點換成對方 panel）：主提示自然寬高每次重設短暫變動（別家插件的行晚一幀補回）
  會讓比價框原生跟著動，貼原生的面板就上下左右抖；主面板只長不縮、貼被錨定側，穩定性沿鏡射傳下去。**接管期間原生 `SetClampedToScreen(false)`、面板自己夾**（暴雪夾邊依原生總高切換會整組跳 16px；接觸面 #13）。
  掛在 GameTooltip 底下的別家框（AppearanceTooltip 預覽）會跟著原生 alpha 0 透明、只剩模型（模型不吃父層 alpha）⇒ `Adopt(..., { ignoreParentAlpha = true })`。
  聊天連結的 ×：**不可在自己的 OnClick 裡 `ItemRefCloseButton:Click()`**（HideUIPanel 整串在我們的執行裡跑會擴散 taint）；改成把原生鈕 SetPoint 疊到 × 上讓玩家點到原生鈕本人。`/mtip panel` 印錨點／尺寸／padding 診斷。
- **比價框第四輪（2026-10-19，J／K 批）**：
  **原生沒有點時不改錨**——比價框重建時 `TooltipComparisonManager` 先 `SetOwner(ANCHOR_NONE)` 清點、我們的 post-call 落在「已清、未重貼」那一刻；以前退到 `TOPLEFT 0,0`、下一幀又鏡射 ⇒ 兩個位置交替。現在沿用上次的錨點（`panel.anchorArgs`），第一次才放暫時錨點；`RenderView` 只 `Detach(panel, true)` 保留記憶。
  **對齊遲滯**：同一角、同一顆 tip，原生位置移動 ≤ 半像素就沿用上次的取整位移（`gridDX/DY`），四捨五入邊界上來回跳不再 1px 抖。
  **原生自然寬高也只長不縮**（`state.nativeMaxW/H`，換一件歸零）：暴雪 `AnchorShoppingTooltips` 的 slideAmount 用兩顆比價框原生的寬算，寬一變主提示就被推，鏈尾那顆比價面板抖最兇。
  **比價標籤照抄原生 `CompareHeader.Label` 的字**（zhTW「已裝備」／第二顆「同時裝備」），讀不到退 `EQUIPPED`、沒 header 就不畫；以前寫死 `CURRENTLY_EQUIPPED`「目前裝備」是錯的。標籤字進指紋。
  位置遲滯（J2(b)）**沒做**：跟隨游標每幀合法移動，位置遲滯會讓面板落後游標；等實機用 `/mtip log` 證明是滑動造成的再說（`/mtip panel watch` 取樣器 2026-10-19 已拔：這類抖動發生在取樣之後、繪製之前，取樣看不到）。
- **夾邊與鏡射（2026-10-19，L1／L2）**：鏡射在別的面板上的面板**自己不夾**（`SetMirror` 關 clamp、改回貼自己原生時開回），由鏈的根替依附者預留（`Panel.UpdateClampInsets`：上緣／下緣取整條鏈 clampOwnTop／clampOwnBottom 的最大值，鏈可以串兩層）。
  實機成因：主面板沒標籤 inset 0、比價面板有標籤多留一份，原生錨在螢幕外時兩邊被夾到不同高度，身體錯開一個標籤高。
  四邊再多一圈 `LOOK.EDGE_MARGIN = 4`（換算後存 `panel.clampMargin`）：貼死螢幕邊時 1px 邊框看不見。方向：`SetClampRectInsets(-M, M, top+M, -(bottom+M))`＝範圍比面板大。
  **別家貼在原生旁的框改貼面板（L3）**：外觀預覽每 0.2 秒 `SetPoint(點, 原生 tooltip, 對方點)`，原生上緣隨自然高度變 ⇒ 預覽上下跳。`Adopt(..., { followPanel = true })` → `Panel.Follow`：後掛勾**它自己的框**的 SetPoint（接觸面 #14），對象有面板顯示中就同一幀改貼面板；面板退回時 `Panel.ReturnFollowers` 當場貼回原生。
  **O1（2026-10-19）：跟隨框不照它的點、由我們定位。** L3 只換對象、點照它的，但 AppearanceTooltip 的 positioner 是照**原生**幾何決定貼哪邊、放不放得下（`ComputeTooltipAnchors`：owner 的 GetCenter／GetLeft／GetRight 比游標與螢幕）；接管期間原生不夾邊（#13）又被 padding 撐大 ⇒ 原生超出螢幕（實機 dump 三顆 top 1280、螢幕 1175），它每 0.2 秒換邊（抖）、選「貼上方」時整個框在螢幕外（沒出現）。
  現在 `Place`：貼整條鏈（根＋`mirrorOf` 到根的、顯示中的面板）最外側那顆的外側、上緣對齊根、留縫；換邊遲滯＝這邊放得下就不換，另一邊要多 `LOOK.FOLLOW_HYST = 24` 餘裕且離上次換邊 ≥ `FOLLOW_DWELL = 0.3` 秒，兩邊都放不下選寬的；跟隨期間 `SetClampedToScreen(true)`（原值記 `rec.clamped`、放手還原）。
  `Panel.Align` 成功後叫 `Panel.PlaceFollowers(RootOf(panel))`（比價面板出現當幀跟上，不等它 0.2 秒）；`ReturnFollowers(gone)` 根還在就重貼到鏈上。它的 `anchor = "vertical"` 設定在面板顯示時不被尊重（一律左右）。
  **O1 第二輪（實機「左右閃」）**：第一版在掛勾裡幾何讀不到（剛重錨定、rect 未排版時 GetLeft 回 nil）就退回「點照它的」，這幀它的右側、下幀我們的左側＝每 0.2 秒閃。規則：**掛勾裡算不出位置就沿用 `rec.lastArgs` 再 `C_Timer.After(0)` 重算，絕不退回它的點**（`PlaceOrKeep`）；它要貼的是接管中的 tooltip 但此刻沒面板（比價框重建）也不放手、繼續跟 `rec.root`，只有對象根本沒接管才 Drop。
  配合它的偏好：從它的點讀出想貼左或右（`rec.want`），**只在第一次選邊、而且那邊放得下時**採用；之後它每 0.2 秒變的偏好不跟（它是照超出螢幕的原生算的）。`/mtip panel` 的「跟隨框」行多印幾何讀不到的次數與原因（鏈／框尺寸／螢幕）。
  **O1 第三輪（貼在比價面板右側時抖）**：貼著的比價面板每次重建被 Restore → `ReturnFollowers(sp)` 當場重算 → 縮到根的右緣 → 下一幀 sp 回來再貼回去＝每 0.2 秒左右抖一個比價面板寬。規則：**交棒不動位置**——`Place` 每次同時算好 `rec.rootArgs`（同一個螢幕位置改用「相對於根」表示），`ReturnFollowers` 根還在就 Reanchor 到 rootArgs、`holdUntil = now + FOLLOW_DWELL`；保留期內 `Place` 算出目標是根（鏈縮回）就不往內縮，sp 回來則照常貼回（位置一樣）。dump 多印「交棒 N 次」。
  **O1 第四輪（還是抖；兩份 dump 一份沒「跟隨框」行、一份「0.1 秒前剛掛勾」）**：跟隨狀態在交替。拍賣場刷新列表時 GameTooltip 先 Hide 再 Show ⇒ skin OnHide 立刻 Restore 主面板 ⇒ `ReturnFollowers(root)` 以前立刻把框還給它（貼回原生 ShoppingTooltip1 的右上，原生 top 在螢幕外）⇒ 它下一個 0.2 秒 tick 才又跟上 ⇒ 每次刷新上下跳一大截；面板本身 hide＋show 在同一幀、逐幀取樣看不出來。
  規則：**根退了先 Park**——讀跟隨框現在的 GetLeft／GetTop 改貼 `UIParent` BOTTOMLEFT（同一個螢幕位置）、夾邊不還、記 `parkedRoot`；`PlaceFollowers(root)` 看到 `parkedRoot == root` 就重新 Hold＋Place；它 tick 進來、對象是接管中的 tooltip 但沒面板 ⇒ 停著不放手；`Parked()` 超過 FOLLOW_DWELL 才 Drop。**Try.lua 的 Restore 要先叫 `ReturnFollowers` 再 `Native.Restore`**（Detach 之後面板沒點、跟隨框的位置就讀不到）。`Hold` 只在 `rec.clamped == nil` 時記原夾邊（停著再接回來不重記）、`Drop` 還原後清掉。dump：「停在原地等根回來（N 秒前停的，停過 M 次）」。
- **重複售價行（2026-10-19，M1）**：附屬框裡金額＝SellPrice price 的行藏掉（`Panel.IsDuplicatePrice`，設定 `panel.hideDuplicatePrice`）。語系無關：幣別圖示（|T…GoldIcon…|t、|A:coin-gold…|a 的英文檔名）換成**不含數字的記號**再加總；**一個幣別圖示都沒有一律不算**（售價 1 銅時「總計：1」「背包：1」的非零段也是 {1}，實機誤殺過），部分帶圖示才比非零段；`x%d+` 堆疊數先剝。
  真實資料：**SellPrice 的 price 是整疊的**（背包 16 瓶藥劑 → 46 80），別家的「商人」是單價 ⇒ M2 之後總價與單價都比，兩行都藏；fixture 全部只命中這兩種行。
  **M2 頁尾「單價 ×數量 = 總價」**：單價＝`C_Item.GetItemInfo` 第 11 回傳（`Game.itemSellPrice`）；數量＝`C_Item.GetStackCount(C_Item.GetItemLocation(data.guid))`（`Game.stackCount`），拿不到才總價÷單價整除；單價 ≥ 總價、0、nil ⇒ 只畫總價（`Panel.PriceText`）。
- **框間距與基底邊色（2026-10-19，N1／N2）**：`LOOK.FRAME_GAP = 6`（取代 EXTRAS_GAP 4）；鏡射與 followPanel 換成面板的點、而且點對是相鄰邊時用 `Panel.GapOffset` 往外推（右貼左 x−、左貼右 x+、底貼頂 y+、頂貼底 y−；同邊不動）。
  原生框照暴雪緊貼，只有面板之間有縫——夾邊與比價左右判斷照原生算，多出來的縫沒有進原生寬。
  三屬性（速度／汲取／迴避／不滅）跟次屬性同用 `LOOK.EFFECT` 綠、STAT_SHADE 同級（N3；原生也是同一個綠，以前畫成灰）。
  `Panel.BaseBorderColor()`：`general.borderClassColor`（預設開）＝玩家職業色（CUSTOM_CLASS_COLORS → RAID_CLASS_COLORS），a 照 general.borderColor；`Skin.ResetColors`、面板退路、附屬框都走它，品質／單位色由 SetBorderColor 蓋過。
- **真實 zhTW 行結構**（fixture `Tests/fixtures/real_zhTW.lua`、`real_zhTW_2.lua`（天賦面板：名字與「等級1/1」是後加行、data 從 lineIndex 3／4 起；雕紋段在描述後的 Blank 之後），17 筆，角色／伺服器／公會名已假名化；工具 `Tests/tools/export_real_fixture.lua`）：名字之後、ItemBinding／EquipSlot 之前的無型別行是**標題補充行**（難度「|cFF 0FF 0英雄難度|r」——暴雪自己的壞色碼夾空白、虛無鍛造、「已塑形為：」）；
  **DisabledLine 是灰字不是需求未達成**（其他專精的主屬性、套裝未擁有件）；SellPrice 行文字是空的（錢幣另外畫）、要在「空行＝分段」之前認走；同 lineIndex 會有重複空行；盾牌格擋 `SHIELD_BLOCK_TEMPLATE`、武器油 `ITEM_ENCHANT_TIME_LEFT_*`、寶石行帶 `gemIcon` 檔案編號（**SetTexture 要餵數字**）。
  配方／被動／天賦／充能法術仍沒有真實資料。
- **OnTooltipCleared（Release）與 skin OnHide（OnSkinHide，2026-10-19 起）都先不拆、下一幀沒被新 post-call 認領才 Restore**。不然比價風暴「清空再填同一件」每秒拆重畫二十幾次，指紋白做。
  OnHide 延一幀的原因：ScrollBox 類清單（Auctionator 購物結果 `UpdateTable → ScrollBox:SetDataProvider`、背包、任務）每次刷新都重新配置列，游標那一列先藏（GameTooltip:Hide）、**下一幀**引擎重判滑鼠焦點才 OnEnter 重設同一件 ⇒ 原生本來就閃一幀；面板當場拆再重畫＝跟著閃（實機：拍賣場滑過結果列整組框閃）。延一幀後同一件回來走「同一件的重建」認領，零重畫；這也讓跟隨框的 Park 幾乎用不到。`/mtip log` 開著時 OnSkinHide 記 `debugstack`（是誰藏的）。
  padding 只在「tooltip 還顯示、而且還是我們設的值」才寫回（`GameTooltip_OnHide` 第 419 行自己 `ClearPadding`、OnShow 走 CalculatePadding 沒內嵌框也清——wow-ui-source live 核過）。
- **先比指紋再解析**：指紋＝CollectLines 的原始行（文字＋顏色＋price）＋設定版本＋行數；相同連 reader 都不跑。
- **像素基準用 panel 自己的有效縮放**（panel 跟著 `general.scale` SetScale，拿 UIParent 基準整組偏）。量測與排版只讀自己記的 width／height，不讀 `panel:GetWidth()`（錨在 tooltip 上會沿鏈染到秘密幾何）。
- **語系 pattern 全部從 `_G` 的 GlobalStrings 反轉產生**（`Panel/Patterns.lua`），不寫任何語言字面；12.1.5 的 `TooltipDataLineType` 很多行有型別（ItemName／ItemBinding／EquipSlot／ItemLevel／FlavorText／ItemSpellTriggerOnUse…／SpellName／SpellPassive／SpellDescription／UsageRequirement／NestedBlock），
  **能用型別就用型別**，文字只留耗能（`_G` 掃 `*_COST`／`_COST_PER_TIME`／`_COST_LARGE`／`_COST_PCT` 族，排除 TRAINER_／REPAIR_／POWER_DISPLAY_ 等）、施法、冷卻、距離、屬性（`ITEM_MOD_*_SHORT`）、護甲、傷害、耐久、套裝、需求。
  數字型 conversion（%d／%.2g）只吃數字——用 `(.-)` 的話 zhTW「冷卻時間%.2g秒」會吞掉「冷卻時間尚有：12秒」。`|4a:b;` 展開單數／複數／原碼三條。三語 GlobalStrings CSV 在 `Interface/tmp/GlobalStrings/`（gitignored，wago.tools `db2/GlobalStrings/csv?locale=zhTW`）。
- **`lineIndex` 確實由 `TooltipDataHandlerMixin:ProcessLineData` 第 330 行寫回 lineData**；不在 data 裡的 `TextLeftN` 就是別人（含我們的 ID 行）`AddLine` 加的，全收進「其他」區，**一行不丟**。
- **描述數字只能上色不能加粗**（FontString 不能局部換字型）。zhTW 描述不切句、整段畫。
- **`/mtip record on|off|clear` 記錄模式**（使用者要求「滑的時候記錄，不要滑一次 dump 一次」）：post-call 自動記 data 整張＋當下 FontString 文字顏色＋語系，同 id＋型別＋行數去重、上限 60，存帳號層 `MiliUI_Tooltip_DB.dumps`，/reload 才落地。
  真實行結構（尤其配方「製造／材料」、屬性行形狀）**全部還是推定**，等 record 資料進來對 fixture；README 待實機驗證 1～14。
- 設定：`item.panel`／`spell.panel`（預設開）、`panel.{separators,strip,numberColor,numberCustom,statMarkers,levelBadge}`，靠 MergeDefaults 補，沒遷移。離線測試 `Tests/*_test.lua` 六支。

## 轉向：原生幾何真實化（2026-10-19 深夜，取代 #13 關夾邊、L1／L2 面板自夾、O1 整套）

四輪「外觀預覽抖」補到最後發現都是在補**下游症狀**：原生被 padding 撐大又關了夾邊 ⇒ 原生超出螢幕 ⇒ 所有讀原生幾何的東西（AppearanceTooltip 的 `ComputeTooltipAnchors`、暴雪的比價定位與夾邊）都被誤導。使用者點出「這樣修不是正確的」，改成：

- **原生照暴雪的夾邊**（`Native.Hide` 不再 `SetClampedToScreen(false)`）。當初關掉是因為原生高度一抖夾邊就切換；原生寬高「只長不縮」之後這個前提不在。
- **夾邊範圍設在原生上**（`Native.UpdateClamp`，每次 Fit；接觸面 #13 改成 `SetClampRectInsets`／`GetClampRectInsets` 記原值、Restore 寫回）：四邊呼吸 `EDGE_MARGIN`、上緣多留比價標籤（`Panel.ClampReserve`：自己的 `clampOwnTop` 加上鏡射在自己身上的面板的、沿鏈收到根）。附屬框已在原生撐高的總高裡，底邊不另留。面板本身不夾（`Create` 不再 `SetClampedToScreen`；`UpdateClampInsets`／`clampable`／`SetMirror` 的夾邊切換全拿掉）。
- **跟隨框退回 L3**：對象換成面板、點與位移原樣、相鄰邊留縫；`Place`／`Park`／交棒／換邊遲滯／`PlaceFollowers`／`FOLLOW_HYST`／`FOLLOW_DWELL` 全部刪除。它照真實的原生幾何做的判斷照單全收。
- 保留：鏡射（I1）、J3、半像素遲滯、原生寬高只長不縮、OnHide 延一幀（那是另一個獨立成因：ScrollBox 刷新）。
- 教訓：**替身的幾何必須是真的**。要騙暴雪的定位系統，就要騙到底（尺寸、位置、夾邊都跟真的一樣），只騙一半的話每個讀它的人都要另外修。
- **夾邊打開後暴露的時序問題（同晚，log 破案）**：提示頂到螢幕上緣時面板每 0.2 秒往下掉一幀，逐幀取樣 600 幀全穩。log：同一件重設的 post-call 當下 `Fit` 量到自然高 306.7（別家的行還沒加）→ padding 125.3 撐到 432；同一幀稍後行加進來（396.8）⇒ 原生總高 522 直到下一幀對帳改回 35.1。沒夾邊時多的往上長、面板貼下緣不動；**夾在上緣時上緣被釘住，多的變成下緣掉 90**。取樣看不到：對帳走 `C_Timer.After(0)`，在 OnUpdate 取樣之前就修回（取樣器 2026-10-19 已拔）。
  規則：**post-call 當下的內容已知不完整，padding 用上次對帳量到的自然尺寸算**（`Native.Fit(tip, state, partial)`：partial 取 `nativeSettledW/H` 與當下的大者；對帳／輪詢才記 settled）。效果：padding 每循環一個數字都不變、連 SetPadding 都省；真的變少頂多矮一幀。
  診斷工具教訓：**每幀取樣抓不到「計時器在取樣前修回」的一幀抖動**，要在寫入點記 log（`/mtip log` 現在記 SetPadding／補回／夾邊／alpha／重貼／對帳／重畫）。

## 單位也改走重繪面板（2026-10-20，worktree prettytooltip-new-layout；`Panel/ReadUnit.lua`、`ViewUnit.lua`）

使用者拿 PrettyTooltip 的六張單位截圖要「比照物品做法也做成新版面」，附帶三條要求：**關掉不吃效能、注意 taint、注意效能**，以及「間距要等距、要有質感」。
推翻了 10-18 plan 裡「單位一行都不要動」那條——做法是**面板接手時根本不改寫暴雪的行**（舊樣式那條只在退回時跑），反而比舊樣式少碰暴雪物件。

- 入口 `Panel.TryUnit`（Hooks 的 OnUnit 先問 `Panel.UnitWanted()`＝兩個開關一次查表，都關就零成本）：GetUnit 的 token 可能秘密／過期 ⇒ 用 data.guid 驗證、`UnitTokenFromGUID` 反查明文 token；
  `C_Secrets.ShouldUnitIdentityBeSecret` 為真（或秘密布林）就不接。成功時 OnUnit 只設 state.unit／isUnitTip、跑模型與血條，**不跑 UnitLines／Target**。
- 跟物品共用 Try.lua：key＝`unit:<guid>`；指紋多一段**動態簽章**（目標 GUID、死亡、離開、PvP、觀察快取、修飾鍵），輪詢比到變了就排對帳，**行指紋一樣只差動態＝立刻重畫**（換目標不等 SETTLE）。
- 面板路徑的 Restore 若不在 post-call 裡（對帳讀到秘密、設定改了）⇒ 原生是暴雪原樣的行 ⇒ `Panel.UnitFallback` 用 `tip:Show()` 讓暴雪重跑內容；對帳退回的同一 key 封鎖 1 秒（不然來回），`RestoreAll`（設定改了）不封鎖。
  `inUnitPostCall` 旗標擋「post-call 裡的退回又 Show」——**xpcall 失敗的 Fail 也要在旗標還在時叫**。
- 目標輪詢（Target.lua）與 RefreshUnitTip 看到 `state.native` 就讓開（不然 AddLine＋Show 會讓暴雪重跑內容）；觀察資料到貨改 `Panel.Poke`。
- 血條（Bar.SetHost：reparent 到面板，有附屬框貼附屬框下）、3D 模型（Model.SetHost：改錨點，模型不吃父層 alpha）跟著面板；RaiseAccents 貼面板時抬到 tip+6。
- 新接觸面 #15 `hooksecurefunc(tip,"FadeOut")`：世界單位滑開的 C 端淡出只淡原生（已在 alpha 0）⇒ 面板自己的 AnimationGroup 淡；#16＝單位面板不改寫行。
- `Eligible` 加 `tip.insertedFrames`（GameTooltip_InsertFrame 的 UIWidget／進度條）有顯示中的就不接，對帳時再查一次（物品也受惠）。
- 秘密的目標名字（單位明文、它的目標受限）是唯一畫秘密值的地方：自訂段落不量不讀、`SetText(秘密)`、輪詢重交；那顆池 FontString 每次 RenderView 放掉（`state.panelTargetFS`）。
- 版面數值（照 PrettyTooltip、色照提示皮）：頭像 40、等級底板在頭像**下方**（徽章其他型別在上方，`view.badgeBelow`）、底板難度色（邊×0.8／底×0.14／字往白收 0.55）；名字 title+3；標題區各行 `UNIT_HEADER_GAP = 3` 等距；最小寬 250；
  浮水印（`panel.unitWatermark`）＝PrettyTooltip 的陣營徽記 PNG（MIT，`Media/LICENSE-PrettyTooltip.txt`，關於頁致謝已改寫）＋暴雪目標框龍 atlas，裁在面板內。
- 標籤一律用暴雪全域：`STATUS_TEXT_TARGET`「目標」（`TARGET` 是「選取目標」）、`AFK`「離開」、`MAP_LEGEND_RARE(ELITE)`「稀有（精英）」。
- `Tests/Unit_test.lua` 連間距一起驗（標題等距、◆ 上下等距、四邊內距）；scratchpad 有過一支把假框幾何畫成 PNG 的 mock 腳本，看版面很有用（Lua 5.3 的 `%02x` 不收小數，測試裡 `Colors.Hex` 要墊取整版）。
- 未實機：README 待驗 30～36（尤其哪些戰鬥情境身分受限、專精行認法、FadeOut 秒數 0.3 是猜的）。

相關：[[project-miliui-unit-frame]]、[[wow-121-secret-values]]、[[project-121-addon-migration]]、[[project-tinytooltip-perf]]、[[project-local-addon-forks]]、[[project-miliui-hud-skin]]
