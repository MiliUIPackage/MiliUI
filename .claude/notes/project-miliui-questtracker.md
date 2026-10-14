---
name: project-miliui-questtracker
description: 米利的任務追蹤器 MiliUI_QuestTracker —— 掛勾暴雪 ObjectiveTracker 的獨立插件；六條 taint 規矩、摺疊走 IsProtected 分流（摺著時標題列改錨存檔座標）、**位置接管的正確模型（右側容器列管＋編輯模式指紋，10-12 三連修）**、內建 M+ 計時面板、/mquest debug 三段判定、目標行字級同池、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 115994b3-d41f-4e67-b636-6c325885e05b
  modified: 2026-10-14T00:00:00.000Z
---

2026-08-29 開的獨立插件（`AddOns/MiliUI_QuestTracker/`，2026-10-12 TOC 1.0.9），骨架照
[[project-miliui-auraenhance]]：MiliUIWidgets vendor 一份、`Core/Init+Media+DB+Tracker+Diag`、
`Modules/{Chrome,Skin,Visibility,Position,Menu,MythicPlus,AutoQuest}`、自製設定視窗、`/mquest`。
NAMESPACE = `MiliUIQuest`，`ns.DB_VERSION = 2`。自動接任務的時序問題獨立成 [[wow-autoaccept-quest-delay]]。

**核心決定：不自己畫追蹤器。** 暴雪的 `ObjectiveTrackerFrame`（下稱 OTF）仍然是唯一的渲染引擎，
我們只換外觀、加自己的框、決定什麼時候收起來。追蹤器有一半的內容是從暴雪的**共用 widget pool**
借出來畫的（場景、UI widget），那個池子同時服務工具提示與地圖圖釘 —— 自己重畫等於要複製整套資料流。

## 六條規矩集中在 `Core/Tracker.lua`

**所有碰得到追蹤器的動作只能從那支出去**，別的模組不准自己摸 OTF。每一條背後都是
「不會當場報錯、但會在別的地方炸」：

1. **不要呼叫 `ObjectiveTrackerFrame:Update()`**，任何形式都不行。`C_Timer` 延後**沒有用**
   —— taint 記的是「誰的執行環境」不是「誰呼叫的」。代價（改字級後行高暫時錯位）要接受。
   同理 **`OTF:SetHeight()` 等於呼叫 Update**（`OnSizeChanged → MarkDirty`，而且 `dirty` 欄位從此是髒的到 /reload）。
2. 自己的旗標不准寫在暴雪的 frame／table 上（它會 `pairs()` 走 `usedBlocks`）。走 `T.Flags()` 弱鍵表。
3. **`ScenarioObjectiveTracker` / `UIWidgetObjectiveTracker` 的子區塊連 `GetBottom()` 都不能叫。**
   Header 安全（不從池子來）。`T.EachBlock` 把這道閘擋在裡面。
   兩個例外：場景 `ObjectivesBlock.usedLines` 的目標行（`T.EachScenarioLine`，理由見「目標行字級」）、
   XML 固定子框 `StageBlock`（`T.StageArt`，見「場景階段框」）。
4. 藏貼圖只准 `SetTexture("")`；`SetTexture(nil)` 與 `SetAlpha(0)` 都會沾到暴雪的貼圖。
5. `block.poiButton` 不准 `Hide()` 也不准掛它的 `Show()` —— 那顆的 OnShow/OnHide 會動
   `EventRegistry` 上 `"Supertracking.OnChanged"` 的共用訂閱表。要藏走 alpha ＋ `EnableMouse(false)`。
   ⚠ 池化的按鈕拿回來時 alpha 不會被重設，但出場動畫結尾會把 alpha 拉回 1，所以要排一次補刀。
6. **不要做「覆蓋層轉發點擊」。** 點整條標題收合走原生按鈕的 `SetHitRectInsets`，
   讓玩家的滑鼠直接落在暴雪自己的 OnClick 上。

對過的暴雪事實：`DirtiableMixin` 的 `self.dirty = nil` 寫在 `method(self)` 之後 —— Update 拋錯一次，
追蹤器到 /reload 前不再更新；容器的 Update 派送迴圈沒有 pcall，一個模組拋錯、後面的全部跳過。
原始碼：`Blizzard_ManagedFrameSystem/Shared/ManagedFrameSystem.lua`、`Blizzard_EditMode/Shared/EditModeSystemTemplates.lua`
＋`EditModeUtil.lua`＋`Mainline/EditModePresetLayouts.lua`、`Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua`。

## 摺疊機制：用 `IsProtected()` 分流，不要猜

**OTF 在編輯模式被錨到快捷列時才會變成受保護框**，那時候戰鬥中的 `Show`／`Hide`／`SetParent`
全部靜默被封鎖；沒被錨的時候戰鬥中照樣動得了。所以走哪條路是**問出來的**（`otf:IsProtected()`）：

- 動得了 parent → `SetParent(hiddenParent)`（`MiliUIQuestTrackerHidden`，`SetAllPoints(UIParent)`）。子框連滑鼠都收不到。
- 動不了 → `SetAlpha(0)` ＋ 自己蓋一塊擋滑鼠的板子（`mouseBlocker`）。
- `PLAYER_REGEN_ENABLED` 再收斂回 parent 路線（`T.Reconcile`）。已經 parent 藏起來之後，戰鬥中就是展不開（設定頁有寫）。

**暴雪原生的收合（`Header:SetCollapsed`）不能拿來做自動摺疊** —— 那要跑它整串收合程式碼。
所以「自動縮起」是我們自己藏，配一條自畫的標題列當把手（`Modules/Chrome.lua`）。
自動摺疊的條件在 `Modules/Visibility.lua`（`visibility.*`，2026-10-13 第八個是 `vehicle`：只認 `UnitHasVehicleUI`、
乘客座不算、進出載具事件 0.3s 後再評估一次）。手動摺疊 `db.folded` 點標題列就寫入，誤點一次永久摺著——這個 UX 沒處理；
救急指令 `/mquest fold`。

⚠ **parent 不是我們一個人的。** 暴雪有三處直接寫它、都不看現在掛在誰底下：
`ManagedFrameContainerMixin:UpdateFrame`（`SetParent(RightManagedFrameContainer)`）、`EditModeSystemMixin:ApplySystemAnchor`
（`AddManagedFrame` 的閘是 **`IsShown` 不是 `IsVisible`**）、`BreakFromFrameManager`（`SetParent(UIParent)`）。
每次編輯模式套用版面都會把摺著的清單拉回畫面 ⇒ `hooksecurefunc(otf, "SetParent")` 只排下一幀的 `Reconcile`
（不在 hook 裡直接 SetParent，會重入 AddManagedFrame）。實測一個 session 收回 23 次，報告印 `parentReclaimed=N`。

### 摺著的時候標題列不能錨在追蹤器上（2026-09-22，「進探究整個消失」的根因）

症狀：沒有錯誤、整份清單連標題列一起不見。報告指紋：`folded=true parentedAway=true`、`OTF topleft=(1505, 1013) of screen 1820x1024`。
預設位置的追蹤器錨在 `RightManagedFrameContainer`；SetParent 把它抽離版面之後位置解到**螢幕最頂端**、高度變成整個螢幕
（`UpdateHeight` 讀 `GetParent():GetHeight()`）。標題列原本無條件錨在追蹤器上 ⇒ 跟著飛進小地圖那一區。
用搬家遮罩拖過的人錨點是絕對座標所以沒事——只有預設位置的玩家中。

修法（`Chrome.lua` 的 `RememberTrackerRect`／`FoldedAnchor`）：追蹤器看得見的時候每次 Layout 記下左／右／上緣，
存成**相對 UIParent 右上角**的位移，放 `db.barSnapshot["名字-伺服器"]`（分角色，編輯模式版面可以分角色）。
摺著時標題列改錨 UIParent 到那組座標；背景／搬家遮罩／鑰石面板都錨在標題列上。從來沒量過的人用
`EditModeUtil:GetRightContainerAnchor()` 推。`FoldChanged` 改成整個 `Chrome.Layout()`。
代價：摺著期間暴雪版面變了標題列不會跟，展開一次才更新——刻意的。
否決的兩條：只走 alpha＋擋滑鼠板（摺著時那塊區域點不到地面、起不了滑鼠轉視角）；`SetScale(0.001)`（沒依據）。

## 位置接管（`Modules/Position.lua`）：正確模型

搬家遮罩＝左鍵拖、右鍵放手。**這是這支插件唯一一處故意跟暴雪搶的地方，而且是使用者指定的**
（「編輯模式歸編輯模式」，要獨立拖曳）。沒拖過（`position.set` 為 false）就完全不介入。

**2026-10-12 同一天同症狀「位置跑掉、被往左頂」修了三次（`e263e62bd`→`50de9777d`→`8dc7d0241`），
前兩次都修到真實存在但不是主因的東西。** 把整個模型寫下來，下次先對這張表：

| 會動 OTF 位置的力 | 什麼時候 | 對策 |
|---|---|---|
| **右側容器 `RightManagedFrameContainer` 的 Layout** | 預設位置的 OTF 是容器的小孩、還在它的 `showingFrames` 裡；首領框／競技場框出現、UIParent 重新顯示、OTF 自己 OnShow→`AddManagedFrame`→`UpdateFrame`（`ClearAllPoints`＋`SetParent(容器)`）都會重排 | **只貼 SetPoint 擋不住**。`Pos.Apply` 把 parent 從容器換成 UIParent（容器的 Layout 就不碰它）；掛 OTF 的 `SetParent`，暴雪收回容器時**下一幀**再搬（hook 裡當場動會重入 UpdateFrame）。`Pos.Reset` 放手時原本錨在容器上就放回去 |
| **編輯模式套用版面**（進出編輯模式、`EDIT_MODE_LAYOUTS_UPDATED`、重載） | 把 OTF 貼回它記的座標 | 盯那幾個事件（PEW／EDIT_MODE_LAYOUTS_UPDATED／UI_SCALE_CHANGED／DISPLAY_SIZE_CHANGED／REGEN_ENABLED）**延後貼兩次**（0.1s＋0.6s，套用版面的時機不保證在我們之前）；編輯模式開著不貼 |
| **玩家用編輯模式拖過**（或換了一套版面） | 離開編輯模式／重載 | 接管時記 `position.editModeSig`（`otf.systemInfo` 的 `isInDefaultPosition`＋`anchorInfo` 唯讀指紋）；指紋變了＝編輯模式有新主意 ⇒ **自動放手**。舊存檔沒指紋時編輯模式已有自訂位置就直接放手。沒有這條，08-30 用遮罩拖過一次留下的 `position.set=true` 會在每次離開編輯模式／重載把剛拖好的位置蓋回舊座標 |
| UIParent 寬度（UI 縮放、視窗大小、角色不同） | 存「距左緣 x」的框靠右放時右邊多出一截 | 存**上緣＋離得近的那一邊**（`position.point`＝TOPLEFT／TOPRIGHT，舊格式在 Apply 時就地換算）。垂直錨上緣：內容往下長，CENTER 的話任務一多整條往上飄 |

指紋：存檔的右緣 −5／−101 ＝ 無／有右側快捷列的預設位置（容器錨在右側快捷列左邊，偏的量就是一排快捷列寬）。
**教訓：「位置跑掉」先問玩家是用哪條路拖的（遮罩 vs 編輯模式），再看存檔有沒有殘留的接管旗標**；
第一輪誤判成「UIParent 寬度因角色而異」就是沒問。

- 要能右鍵放手回得去，得在**第一次覆蓋之前**把暴雪原本的錨點抄進記憶體（`ClearAllPoints` 之後就沒了）。
- 拖曳自己算游標位移，不用 `StartMoving`；位移要換成追蹤器自己的座標單位（編輯模式可單獨縮放它，[[wow-setscale-offset-units]]）。
- 遮罩會吃滑鼠，所以編輯模式一開就要讓開。判斷編輯模式開沒開走**輪詢**（只在設定視窗開著時跑）：
  掛 `HookScript` 會把我們塞進 `EditModeManagerFrame` 的執行路徑，`EventRegistry` 回呼要寫共用訂閱表，規矩 5 在擋。
- 套組磁吸（`Libs/MiliUISnap.lua`）註冊的是 OTF 本身，key `questTracker`（[[project-miliui-snap-bars]]）。
- **`8dc7d0241` 帶進過一個會炸的順序錯誤（2026-10-14 體檢抓到、同日修）**：`Save()` 裡呼叫的 `EditModeSig` 在它的
  `local function` 宣告**之後**才出現 ⇒ 編譯成全域讀取（`luac -l` 看到 `GETTABUP _ENV "EditModeSig"`），
  遮罩放手（`EndDrag→Save`）與舊格式換算會 `attempt to call a nil value`。check_lua 只掃全域寫入抓不到
  （[[wow-luac-global-scan]]）。已把 `EditModeSig` 移到 `Save` 前面；教訓：**local function 的呼叫端排在宣告後面**，新檔用 `luac -l` 掃一次 `GETTABUP`。

`Modules/Menu.lua` 只有內容，引擎在共用層。**`Menu.Show` 不要傳 anchor**（傳了會掛在標題列右下角，標題列跟追蹤器一樣寬）。
檔頭寫明**刻意不放**三樣：「顯示標題列」是自殺選項、「在編輯模式中移動」等於在管著追蹤器保護狀態的系統上開污染入口、
自動摺疊的多選條件在共用層子選單裡沒辦法原地重畫。

## 標題列的標籤叫「目標」，讀數是括號灰字

**叫「任務」是錯的**：那條是**整個追蹤器**的標題，底下同時裝著戰役、任務、成就、專業。讀數是 `T.CountBlocks()`
（清單裡實際有幾筆），不是 `GetNumQuestWatches()`（只數任務）。排版 `目標 (17)`：括號＋灰＋小一級，
讀數是**獨立的 FontString**（色碼做不到字級）。

⚠ **跟 `MiliUI_InfoBar` 的 `Dim()` 相反，是刻意的**：資訊列壓的是標籤（你要掃的是數字），這裡「目標」是清單的名字，
壓灰會讓標題變成最弱的元素。程式碼裡有註記「不要為了統一把它改回去」。

標題列右側的開關 chip（自動交／自動接）擠不下時**逐級讓位：完整 → 短字 → 只剩方框（滑過看完整名）**，
標題與讀數不縮（`Chrome.FitChips`，2026-10-07）——英文 `Objectives (14)`＋兩顆 chip 在預設寬一定疊，中文剛好塞得下所以沒被發現。

⚠ 語系 key 撞過：`Objectives` 同時被顏色設定的「目標文字」用掉，改成 `Objective text`。
**同一個英文字在兩個地方是不同意思，就是 key 要更精確的訊號。**

## ⚠ 目標行是 `block.usedLines`，不是 `block.lines`

**寫錯不會報錯**，那圈迴圈只是永遠空的 —— 症狀是「目標文字大小拉了完全沒反應」。
`ObjectiveTrackerBlockMixin:GetLine()`：`self.usedLines[objectiveKey] = line`，行上的 FontString 是 `line.Text` / `line.Dash`。
收在 `T.EachLine()`。另一支同類插件也寫成 `lines`，但它另有盲掃 FontString 的程式碼順手蓋到了——
**別人怎麼寫不能當根據，要去對原始碼。** `ObjectiveTrackerLineMixin` 本身不碰字型，我們設上去的不會被下一次排版蓋掉。

## ⚠ 不要盲掃 FontString 重設字型

**症狀：進度條的百分比顯示成 `□%`。** 秘密值的佔位控制字元原樣被畫出來 —— 進度條的數字是引擎在算繪時才回填的，
對那個 FontString `SetFont` 就把回填弄掉了。**通則：只動具名認得的那幾個**（區塊標題、行的 `Text`／`Dash`、`itemButton.Count`），
其餘一律當作可能帶秘密值。代價是進度條與計時條的數字保留暴雪字型。

## 外觀

底色 `0x1A`（0.102）＋0.8 跟 `MiliUI_DamageMeters` 的視窗底同一組（那邊 `Core/DB.lua` 的常數 `DARK_BG`），要改兩支一起改。
**但「標題列實心、內容半透」那套不能照抄**（回饋「標題好重」）：傷害統計的標題列是視窗的一部分，這裡是浮在地形上的一條。
標題列的底跟清單同一階，關掉背景時只留 1px 線。滑過給不透明度下限 0.45 再往白色插值。**背景預設關**。
描邊五選一（無／描邊／粗描邊／單色描邊／單色粗描邊，2026-10-03 跟 CDM 同一套，舊布林在 Normalize 就地換成 flags）。
`PAD_LEFT`／`PAD_RIGHT`（`Chrome.lua`）＝ −10／+10。

## 傳奇鑰石計時面板（`Modules/MythicPlus.lua`）

鑰石中清單摺起來（`visibility.mythicPlus`，預設開，DB v2 遷移），面板錨在標題列底下補進原位；
三個條件都成立才顯示：選項開、`MP.IsInChallenge()`、`T.IsHidden()`（玩家偷看展開就讓位）。
版面：死亡／計時／[等級] 詞綴／三段計時條 +3|+2|+1／敵軍條／首領；文字預設靠右、可選靠左（`c.align`，2026-10-04）；
計時條／敵軍條顏色可自訂（2026-10-08）；設定分頁「傳奇鑰石」。

**不碰暴雪追蹤器**：暴雪自己的 M+ 區塊在共用池的場景模組裡（規矩 3），我們讀同一組 API 畫自己的框。
在不在鑰石用 `GetInstanceInfo` 難度 8＋party（打完到出副本都算，`IsChallengeModeActive` 打完就 false）。
所有數字先過 `Num()`／`Bool()` 秘密閘，秘密就退化（敵軍字串原樣 SetText）。
**敵軍百分比**：`quantity` 已經是百分比、`quantityString` 才是絕對數量，見 [[wow-mplus-enemy-forces-fields]]。

**每季要看**：`PLUS_FRACTIONS = {1.0, 0.8, 0.6}`、挑戰者的危機 `PERIL_AFFIX_ID = 152`／`PERIL_BONUS_SEC = 90` 的扣法。
**刻意不做**：拉怪預估（戰鬥記錄 12.x 已死）、EJ 首領名（開面板會污染，criteria description 就是名字）、分段紀錄、
自動放鑰石（在 [[project-miliui-mythicplus]]）。死亡名單 2026-10-07 借 AdvancedMythicTracker 做了（`deathList`：
UNIT_DIED 的 GUID 對開場隊伍快照，滑過死亡數顯示；死亡數以 `GetDeathCount` 為準，名單可能比較少）。

已實機驗證：版面、秘密值路徑、敵軍百分比（2026-09-15）、面板在標題列關掉時的錨點（09-16）。死亡名單未驗。

## `/mquest debug` 診斷報告（`Core/Diag.lua`）

起因：玩家回報「詛咒浪潮沒顯示任務進度和開始前倒數，重新登入就好」。三種病因畫面一模一樣，報告分三段對照再給一句判定：

- **A. API 端**：`C_Scenario.IsInScenario`、`C_ScenarioInfo.*`、`C_UIWidgetManager.GetObjectiveTrackerWidgetSetID`＋`GetAllWidgetsBySetID`、
  `GetWorldElapsedTimers`。API 說不在場景裡 ⇒ 暴雪端。措辭要分「人在事件裡」與「不在」——不在事件裡打報告本來就是 A。
- **B. 模組端**：每個子追蹤器的 `state`（`ObjectiveTrackerModuleState`）、`hasContents`、`contentsHeight`、`isCollapsed`、`hasSkippedBlocks`、
  Update 次數（Skin 的 hook 往 `Diag.NoteUpdate` 報到）。
- **C. 我們這端**：`T.DiagState()`、位置換算成 UIParent 座標比螢幕、Position 接管、Chrome.Diagnose、標題列座標（不在螢幕內標 `!!`）、vehicle 現況。

另外：**taint** 走 `issecurevariable(tbl, key)`（直接點名弄髒的插件）；**錯誤** 合併 `ns.errors`、其他插件的 ADDON_ACTION_BLOCKED/FORBIDDEN、
BugGrabber 本 session 相關錯誤；被動記錄 SCENARIO_*／WORLD_STATE_TIMER_*／PEW 的時間戳。
報告開在 `W.CreateScrollEditBox` 視窗（**不用 `CreateCopyBox`**，那支藏了捲軸）；所有值過 `Str()`（秘密值印 `<secret>`），每段各自 pcall。

三個實測事實與一個改掉的假設：
- **開始前的倒數是 step 的 widgetSetID 裡的 `ScenarioHeaderTimer` widget**，不是 world timer；`GetWorldElapsedTimers()` 沒計時器時回一個空佔位，只認正整數 ID。
- **`GetAllWidgetsBySetID` 連 `shownState = Hidden` 的 widget 也一起回**（指紋：`setID=1 widgets=33`）。`shownState` 要走各型別自己的
  visualization info getter，名字有兩種拼法（`Get<Type>VisualizationInfo` / `Get<Type>WidgetVisualizationInfo`），照 `Enum.UIWidgetVisualizationType` 兩種都試。
  widget 狀態四態：`shown`／`hidden`／`noinfo`（getter 有、問不到＝畫不出來；`SpellDisplay`、`IconAndText` 實測落這裡）／`?`（沒 getter，**不能當成沒顯示**）。
  **場景與 widget 是兩條獨立的路**（widget set 由伺服器指派），判定 A 之前先問「有 widget 顯示中但 UIWidget 模組是空的嗎」。
- **「重新登入就好」不是 taint 的指紋**：用戶端資料庫跟伺服器失去同步也只有重登會好（`/reload` 不重新要場景狀態）。
  叫玩家 `/reload`：好了＝Lua 端，非得重登＝同步問題。**2026-09-08 症狀當下的報告判定就是同步**：`IsInScenario=false`（明值）、
  widget `shown=0`、**`SCENARIO_UPDATE` 只有登入時 2 次、`SCENARIO_CRITERIA_UPDATE` 從來沒有**、taint 0 髒——用戶端連通知都沒收到，插件無能為力。
  判定 A 現在印「上一次收到場景事件是 %s」。
- 報告缺段（例如沒有「objective line fonts」）⇒ **先懷疑遊戲讀的是舊程式**（改動在 worktree 沒部署），別先懷疑修法。

下次玩家再遇到就叫他**在症狀出現的當下**打 `/mquest debug` 把視窗內容貼過來。

## 目標行字級不一致：場景行跟戰役行同一個行池（2026-09-14）

症狀：探究底下一行是我們的字，其他行是暴雪原樣；`/reload` 之後變成全部沒套到（池子被重置）。
**根因：行池的鍵只看模板名稱**（`Pools.lua` 的 `GetPoolKey(template, specialization)`，父層不算）。場景用 `ObjectiveTrackerAnimLineTemplate`，
**戰役、世界任務、成就、冒險、每月活動、倡議、專業配方都是同一個模板**（只有一般任務是 `QuestObjectiveLineTemplate`）。
所以「場景的行不美化」從來不成立——我們 SetFont 過的戰役行被回收給場景就帶著我們的字型。
**修法：把場景的目標行也納入美化**（`T.EachScenarioLine`：只讀 `ObjectivesBlock.usedLines`、不呼叫區塊方法、行文字是秘密值就跳過）。
掛在場景 Update hook 的 `T.Defer("scenarioLines")` —— **不能跟 `"poolHeader"` 共用 key**，Defer 先到先贏。
否決：釋放時還原字型（要 hook FreeLine，真正的禁區）；直接改 `ObjectiveTrackerLineFont`（編輯模式 `SetTextSize` 會拉鋸）。

機制：目標行 `Text` 繼承 `ObjectiveTrackerLineFont`，編輯模式「文字大小」改的是字型物件（繁中 12 實際 15）；行池是**每個區塊一個**；
顏色是第二個指紋：暴雪一般色 0.80、完成色 0.60，`SetStringText` **只在色系換掉時才 SetTextColor**，我們預設 0.72——完成那行印 0.60 代表完成後 SkinLine 沒再跑。
報告的「objective line fonts」段逐行印字級／描邊／字型檔／role／顏色／動畫狀態，對不上標 `!!`。
**2026-09-14 已在遊戲內驗證**（探究「納爾多島」）。

### 2026-10-13 目標進度上色／百分比（未實機驗證）
`Skin.lua` 的「目標進度」段：進度從**行文字**解析（全形數字／「／」先轉半形、貼圖跳脫碼先拿掉），紅→黃→綠漸層；
完成照 `line.Text.colorStyle`（**滑過時存的是 `Complete.reverse`，兩個都要認**）或動畫 state。補色掛在 AddBlock post-hook＋標題 OnEnter/OnLeave HookScript
（順帶修掉「滑過離開後目標行回 0.8 灰」）。百分比用 SetText 接在原文後，接完比 `GetNumLines`／`IsTruncated`，多一行或被截就退回原文；原文記在 `T.Flags()`。
預設：上色開、百分比關。

## 場景階段框 StageBlock：規矩 3 的第二個例外（2026-09-21）

- `ScenarioObjectiveTracker.StageBlock` 是 **XML 寫死的固定子框**（`parentArray="FixedBlocks"`），不是池子來的；region `NormalBG`／`ThemeOverlay`／`FinalBG`／
  `GlowTexture`／`Stage`／`Name`／`CompleteLabel`，暴雪對這些 **只寫不讀**。
- **`UpdateStageBlock` 只在 `currentStage`／`scenarioID` 換掉時才呼叫**，挪錨點幾乎不用拉鋸。它重設 `NormalBG`／`FinalBG`／`Stage` 的 TOPLEFT（不 ClearAllPoints）。
- 底圖位移表 `textureKitOffsets`：evergreen 0、delves -2、**midnight-scenario -6**。有 `widgetSetID` 的場景（探究、詛咒浪潮）會把 NormalBG／Stage／Name 藏掉——碰不了。
- **高度縮不了**（`height=83` KeyValue），間距只能靠把 region 在格子裡往下挪。

做法：`T.StageArt`／`T.RegionBase`／`T.NudgeRegion`＋ `AlignStageArt`（`T.Defer("stageArt")`）。水平是量出來置中在標題底線上。
⚠ `STAGE_GAP_Y` **不能是 8**：Stage 的兩種 y（-10／-18）差剛好 8，會讓基準偵測撞值（現在 7）。
**目標行跟著對齊框左緣**：行本身每次排版都被重新錨定，但第一行錨的 `ObjectivesBlock.HeaderText` 暴雪只在 `AdjustSlideAnchor` 才重設 ⇒
**挪 HeaderText 一次整串跟著走**（`T.ScenarioObjectivesAnchor`）。`block.offsetX = 32` 是排版在讀的 KeyValue，不能寫。
`STAGE_BG_PAD = 3`／`BULLET_LEFT = 5` 是從截圖量的、`OBJECTIVES_INSET = 3`。
靜態位置使用者已在一般地城（evergreen）驗收；三個左緣各差約 2 的階梯是接受的，不要為了切齊去改。

## 跟別的插件的關係

- **Leatrix Plus**（已不在套組）：`LeaPlusLC` 是檔案內 local，只能讀 `_G.LeaPlusDB`（登入當下的值），玩家自己裝回來才會存在；偵測到就在設定頁與聊天視窗警告，
  文案要講清楚「改完要 /reload 才會重判」。
- **WarpDeplete**（2026-09-05 整支移出套組）：M+ 藏清單改由我們負責。`MiliUI/Enhance/LegacyAddons.lua` 的 `REMOVED` 有一筆讓還留著資料夾的玩家收到刪除提醒（不自動停用）。
  **改預設值的遷移範本**：`ns.DB_VERSION` 1→2，`DB.lua` 的 `Migrate(db)` 在 `MergeDefaults` **之前**看 `schemaVersion`（merge 之後會被補成最新；全新存檔沒版本號直接跳過）。
- 自動交任務比 Elles 完整（`QUEST_PROGRESS → CompleteQuest()`、`QUEST_GREETING`、`QUEST_ACCEPT_CONFIRM`）。**但 `QUEST_AUTOCOMPLETE → ShowQuestComplete()` 刻意不做**——
  那會跑暴雪的完成面板流程（`ShowUIPanel` ＋ 往世界地圖寫 UIPanel 屬性），之後戰鬥中地圖圖釘被封鎖。
- 不用 `UnitGUID` 記 NPC（可能是秘密值，當 table key 直接炸）。「同一個 NPC 有多個任務就別亂挑」用「可接任務不只一個就不挑」表達。
- **EllesmereUI 的授權是 All rights reserved**（原始碼已不在本機）：程式碼一行都不能貼，連註解都不行；可以學的是事實（哪個 API 會污染、事件流程、暴雪資產名）。

## 跟本體基本型自動交接任務的分工（2026-09-25）
本體 `MiliUI/Enhance/Quest_Automation.lua` 是基本型（Shift 暫停、特殊對話選項不動、多獎勵／收金幣不交、多個可接不挑、秒接不學習）。
判準是全域表 `MiliUI_QuestAutomation`（QT 的 `Api.lua`）在不在：在 ⇒ 本體不註冊任何任務事件，設定頁開關改讀寫 QT 的 `ns.db.automation`，`MiliUI_DB.quest` 只是鏡像；
QT 的 ns.db 要等它自己的 PLAYER_LOGIN，同步延一幀。`MiliUI_DB.quest.dirty`：QT 不在時改過開關 ⇒ QT 回來時推過去，否則以 QT 為準抄回。
**`MiliUI_QuestAutomation` 改名＝兩邊各接一次。** 待實機驗證。

## 待驗證（還沒進遊戲看過）

- 摺著時標題列錨存檔座標（09-22）：預設位置的玩家進探究／鑰石。
- 位置接管三連修（10-12）＋順序錯誤修正（10-14）：驗「遮罩放手後位置存得住」「右側容器重排不再拉回」「編輯模式拖過自動放手」「右鍵放手回得去」。
- 目標進度上色／百分比、載具摺疊（10-13）。
- 場景階段框：換階段那一幀會不會跳、滑入動畫、有進度條的場景、長目標換行後右緣、midnight-scenario 主題。
- 任務類型圖示擺 TOPRIGHT ＋ 壓掉 POI 按鈕：要確認 12.1.5 的 POI 按鈕真的在那個位置。
- 背景高度的跨縮放算式（座標一律換成螢幕像素再比較）。
- `□%` 的修法（拿掉三處盲掃）沒回報驗證過。
- M+ 計時面板死亡名單、文字靠左、自訂顏色。
- 追蹤器**沒有捲動**是既定限制，**不做**（09-19 玩家許願，對過原始碼結論不變）：截斷發生在排版階段（`CanFitBlock`，排不進去的區塊根本沒建出來）⇒ 沒有「藏在下面的內容」可捲；
  `OTF:SetHeight()` 等於 Update（規矩 1）；裁切要 `SetClipsChildren` 的祖先 ⇒ OTF 得常駐掛我們底下，parent 拉鋸變全時段。
  可做的替代：標題列讀模組的 `hasSkippedBlocks` 標出「有被截掉」。編輯模式的「高度」滑桿是 400–1000。

相關：[[project-miliui-widgets-vendor]]、[[project-miliui-hide-blizzard-taint]]、[[wow-121-secret-values]]、
[[wow-editmode-setpoint-hook-saves-our-name]]、[[feedback-ui-visual-style]]、[[wow-autoaccept-quest-delay]]
