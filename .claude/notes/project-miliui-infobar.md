---
name: project-miliui-infobar
description: MiliUI_InfoBar 資訊列——取代微型選單的自製條；secure 點擊轉發（macrotext）／暴雪列 hider／隱式保護框的戰鬥紀律／09-07 taint 紀律四條入口／遊戲選單鈕的 secure snippet／戰隊資訊（**角色記錄多來源只能就地更新**、寶庫欄切換、團本提示）／停靠／坐騎・修裝・確認倒數三張滑過面板共用 HoverPanel／自動修裝與本體連動／外部方塊接口 MiliUI_InfoBarPlugins／待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: c0d1056b-afe5-4f0b-a0d1-24a0f3f4c05d
  modified: 2026-10-14T00:00:00.000Z
---

`AddOns/MiliUI_InfoBar/`（2026-08-29 新增，`/mib`）。純色方底一長條：資訊區塊（裝等／耐久／天賦／擲骰／金幣／時鐘／FPS／延遲／CPU／記憶體／地區／
戰隊／坐騎／確認倒數）＋微型選單按鈕混排，視覺沿用 Chattynator 按鈕那套（0.115 底、1px 0.30 邊、滑過職業色）。
模板抄 [[project-miliui-esc-menu-window-migration]]，共用層 NAMESPACE=`MiliUIInfo`。
`Core/`：Bar／Blocks／MicroMenu／Warband＋WarbandPopup／Mounts＋MountPopup／Repair＋RepairPopup／AutoRepair／ReadyCheck＋ReadyCheckPopup／HoverPanel／Plugins／Perf。
字型（含 LibSharedMedia）與描邊五選一 2026-10-03 加上。

## 三個承重機制（改動前要懂）

1. **微型按鈕＝secure 點擊轉發**：每顆是 `SecureActionButtonTemplate`，`*type1="macro"`＋`*macrotext1 = "/click <暴雪MicroButton名字>"`、
   `useOnKeyDown=false`（少這行 ActionButtonUseKeyDown CVar 會把 AnyUp 點擊丟掉）。12.1 起天賦／法術書**必須**走 secure 點擊。
   **刻意不掛戰鬥鎖**（EUI 有掛）：戰鬥中能點開天賦、換擲骰正是需求。第一版用 `*clickbutton1 = 框`，09-07 改掉（見「taint 紀律」）。
2. **藏暴雪那排只能走 secure hider**，而且要藏 **`MicroMenu`（按鈕格）不是 `MicroMenuContainer`（容器）**：`QueueStatusButton`（排隊的綠眼睛）的父層是容器，
   而**「有人申請入隊」的音效掛在它的 `EyeHighlightAnim` 迴圈 `OnLoop` 上**——藏容器連聲音都沒了。
   MicroMenuContainer 是 Edit Mode 管理框，insecure `:Hide()` 會污染 managed frame system（症狀：離開載具時 ActionBarController_UpdateAll 被封鎖）。
   `SecureHandlerStateTemplate` 的 `_onstate-vis` ＋ RegisterStateDriver **常數狀態**——snippet 只跑一次，外力（載入畫面、編輯模式）Show 回來要靠 force 重推。
   ⚠ 區域變數不要叫 `MicroMenu`——暴雪 DF 起有全域框就叫這名字。
3. **bar 是隱式保護框**：裝了 secure 子按鈕後整條連祖先都被保護，戰鬥中 Show/Hide/SetPoint/SetSize 全被封鎖，只有 SetText/SetVertexColor/SetAlpha 合法。
   ApplyAll 與 Layout 進戰鬥一律整包 `ns.Defer` 到脫戰；寵物對戰只降 alpha。編輯模式選取框掛在 bar 上，連坐被保護；
   暴雪**不會**因為進戰鬥就關掉編輯模式（2026-09-18 taint.log 查證）。
   **拖曳不用 StartMoving**（保護框＋StartMoving 實測拖不動），照 MiliUI_DamageMeters `Meter/Move.lua` 的手動機制。

## 遊戲選單那顆不能走 secure 轉發（2026-09-21 四版定案，當天 taint.log 系列實機修的）

12.1 的 `MainMenuMicroButtonMixin:OnClick` 第一行是 `if ( self:IsMouseOver() ) then`——轉發點擊時滑鼠在我們的按鈕上，handler 空轉（EUI 把 menu 做成 plain button 的原因）。
**現況**：那顆是 `SecureHandlerClickTemplate`，`_onclick` snippet 對 frame ref 直接 `Show(true)`／`Hide(true)`，**戰鬥內外同一條路**；restricted 環境的執行乾淨 ⇒ 選單按鈕不帶我們的 taint。
- restricted 環境戰鬥中只拿得到**保護框**（`GetHandleFrame`：非保護框＋InCombatLockdown ⇒ Invalid frame handle），GameMenuFrame 原廠不是 ⇒
  **掛一個 1×1 的 `SecureFrameTemplate` 空框在它底下**，從登入起就是隱式保護框。
- **⚠ 那顆空框上一個欄位都不能寫，`ignoreInLayout` 也不行**：GameMenuFrame 是 layout frame，`Layout()` 逐一讀子框的 `ignoreInLayout`／`layoutIndex`，讀到我們寫的值整趟染髒 ⇒
  `GameMenuFrame:SetSize()` 戰鬥中被擋，**連 ESC 開的也中**（`303e81599`）。通則：**掛在暴雪 layout frame 底下的自製子框，別寫暴雪版面程式會讀的欄位名。**
- 走過的死路：「點擊 → 觸發 ESC」做不到（沒有 secure 動作能執行按鍵綁定）；**插件端戰鬥中不能用 `ToggleFrame`／`ShowUIPanel`／`HideUIPanel`**
  （`CheckProtectedFunctionsAllowed` 寫死拒絕，每 session 只印一次「介面功能因插件而失效」、**taint.log 完全不記** ⇒ 症狀「點了沒反應」，前兩版栽在這）；
  插件端直接 `GameMenuFrame:SetShown()` 開得起來但按鈕全髒、而且 TeleportMenu 的傳送按鈕不出現（上游掛 `hooksecurefunc("ToggleGameMenu")`，套組已改成聽 OnShow，[[project-local-addon-forks]]）。
- **通則：判斷暴雪框是不是保護框不能只看暴雪原始碼，要看套組裡有沒有人往它底下掛 secure 子框**（TeleportMenu 第一次開選單才建，所以第一次開在戰鬥中沒有傳送按鈕）。
- 其餘 12 顆的 mixin 沒有這個閘，secure 轉發實測正常（戰鬥中含天賦都能開）。

## 踩到的雷（已解）

- **預設位置跟隨官方那排**：沒拖過（db.x/y=nil）就讀 `MicroMenuContainer:GetCenter()` 換算成 UIParent 座標，被 hider 藏著也讀得到；PLAYER_ENTERING_WORLD 再算一次。
  DB_DEFAULTS 刻意不放 x/y——CopyDefaults 會把「沒拖過」這個 nil 蓋掉。
- **EditModeSystemSelectionTemplate 的 XML 綁了 OnMouseDown → SelectSystem**，借用模板的自訂框要 `SetScript("OnMouseDown", function() end)` 中和（[[wow-121-addon-code-in-secure-stack]] 入口 8）。
- **教學提示（HelpTip）**：暴雪把黃色泡泡錨在**原鈕**上，原鈕藏起來提示就飛過去。第一版改 `frame.relativeRegion` 重錨——那正是 09-07 taint 的根因（見下），現況改鏡射。
  第一版留下一條通用教訓：**「改了沒反應又不報錯」的第一嫌疑犯是早退快取**（`AnchorAndRotate` 開頭 `appliedTargetPoint == targetPoint` 就 return），診斷要連實際座標一起印，不只印狀態欄位。
- **原鈕的閃爍要鏡射**：掛全域 `MicroButtonPulse` / `MicroButtonPulseStop`——**不要列舉「哪些情境會閃」**，那份清單散在十幾支暴雪檔案裡。聲音不用管（唯一例外是排隊眼睛）。
- 圖示不自備圖檔：讀暴雪按鈕 `GetNormalTexture():GetAtlas()`，atlas 是直式（約 32x41）要按 `C_Texture.GetAtlasInfo` 比例縮。角色鈕用 SetPortraitTexture。
- 效能紀律：事件能通知的全走事件；輪詢集中一支 Metro；CPU 讀 C_AddOnProfiler、記憶體讀 `collectgarbage("count")`，**絕不**輪詢 UpdateAddOnMemoryUsage（[[wow-addon-profiler-cost]]）。
- 天賦名：TRAIT_CONFIG_UPDATED 時 last-selected 指標還是舊的，要等 SPELLS_CHANGED 收尾。擲骰 SetLootSpecialization 戰鬥中合法。
- 編輯模式訊號三重保險：OnShow/OnHide 掛勾＋`hooksecurefunc(EditModeManagerFrame, "EnterEditMode"/"ExitEditMode")`＋`EventRegistry` 的 `"EditMode.Enter"/"EditMode.Exit"`，全部冪等。選取框開檔就建（wow-editmode-draggable 技能）。
- 設定視窗開著＝職業色「拖曳移動」遮罩蓋整條（右鍵回預設）。遮罩是保護框子層，Show/Hide 走 ns.Defer。
- CPU／記憶體方塊點擊直達本體效能監控：本體 `Api.lua` 出 `MiliUI.OpenPerf("cpu"/"ram")`；沒裝本體就退回純顯示。
- **排一列東西不要用「累加游標」定位，要鏈式錨定**：`P.Size` 把每塊寬度捨到像素格而游標用未捨入的值推進，誤差累積、**只有某幾個**邊界露縫（看起來像隨機）。
  每塊 `SetPoint("LEFT", 前一塊, "RIGHT", gap, 0)`，總寬用 `GetWidth()` 加總（[[project-miliui-pixel-snapping]]）。
- 區塊分頁是方塊拖曳看板（照 MiliUI_Tooltip 的 Tab_Unit），DB 仍是 blocks[key]={enabled,order}，拖放後重編成 10/20/30。

## taint 紀律（2026-09-07 破案，整包快捷列 SetCooldown 秘密值的根）

四條入口全部收掉，改任何一條之前先看 [[wow-121-addon-code-in-secure-stack]]：
- **教學提示改鏡射不改錨**（`Core/MicroMenu.lua`）：暴雪 HelpTip 框的欄位一個都不寫、HelpTip 的 API 一個都不叫。文字讀出來畫自己的泡泡，暴雪那顆 `SetAlpha(0)`＋關滑鼠，
  `Release` 後置勾還原，叉叉走 `SetCVarBitfield`。根因：天賦視窗一開 `EvaluateAlertVisibility` 收提示、`HelpTip OnHide` 讀回我們寫的 `relativeRegion`，整條開窗流程染成資訊列的。
- **UIParent 內縮從 secure 端動**：`SecureHandlerExecute` snippet 裡 `SetPoint("$screen")`；延一幀沒用。戰鬥中 snippet 動不了 UIParent（不是保護框），照舊只在脫戰貼（[[wow-uiparent-inset-dock]]）。
- **點擊派送裡 OnClick 前面沒有任何 Lua**：PreClick 耗時計拆掉、按下底色改引擎的 `PushedTexture`；轉發用 `*macrotext1` 不用 `*clickbutton1`；
  右鍵選單走 `ns.SecureRightClick`（`SecureHandlerWrapScript` ＋ `control:CallMethod`）。
- **編輯模式進出、`UpdateUIParentPosition` 掛勾只改旗標／只讀**，工作丟 `ns.NextFrame`（跟脫戰延遲的 `ns.Defer` 是兩回事，那個沒在戰鬥就當場執行、擋不住這種）。
診斷工具 `_CDProbe` 2026-09-10 已從套組移除。

**戰鬥中會第一次建框的面板，不能呼叫 `SetPropagateMouseClicks`／`SetPropagateMouseMotion`**（[[wow-hasrestrictions-mouse-apis]]）：戰隊表格 `allowCombat`、列第一次開才建，
戰鬥中第一次滑開就**每列**噴一次（`93f30c434`）。治本＝不需要 propagate：子框 `SetMouseClickEnabled(false)`＋`SetMouseMotionEnabled(true)`。

## 效能帳怎麼看（2026-09-06）

效能監控把資訊列標紅時，**先用 `/mib perf` 對帳再動手**（`Core/Perf.lua` 記每個 Lua 入口的最大一次／次數／≥10ms；`/mib perf watch` 逐幀對帳官方 LastTime）。
實測：資訊列自己整場只跑十幾毫秒。紅的是 **secure 轉發的點擊**（點天賦 68 ms 是暴雪開天賦視窗的成本，跑在我們按鈕的 OnClick 裡就算給我們；「近期平均」= 那一下 ÷ 60）；
另一個真的修掉的是停靠中每次換區強制重貼 UIParent；第三個是 CPU／記憶體方塊點開本體效能分頁，分頁的 frame 在我們的點擊裡建出來，OnUpdate 整場記給資訊列（修在本體 perfRelay 中繼框）。

## 停靠模式（2026-09-05）

`db.dock` = none|top|bottom、`db.dockPush`、`db.dockAlign` = center|left|right。停靠＝兩角錨在 UIParent 那個邊，拖曳關掉。
「推開」走 [[wow-uiparent-inset-dock]]（`ApplyInset`／`InsetMatches`／secure snippet 都在 `Core/Bar.lua`）。
停靠時底與框線由**整條 bar** 畫（`ApplyBarChrome`），tile 自己的底與框線 alpha 歸零（兩層半透明疊在一起 tile 區會深一階）。
bar 寬由兩角錨定算出、第一次可能是 0，`OnSizeChanged` 寬一變就 RequestLayout。左右停靠沒做（tile 是橫向鏈式錨定）。

## 戰隊資訊區塊（2026-09-05 從本體搬來）

`Core/Warband.lua`（資料層：鑰石／寶庫快照／懸賞圖／儲物箱追蹤、隊伍回報、「分身key」關鍵字）＋`Core/WarbandPopup.lua`（表格面板、寶庫提示、團本提示、列選單）
＋Blocks.lua 的 `warband` 方塊（滑過開面板、右鍵選單）。判準在 [[project-miliui-vault-tracking]]、[[project-miliui-bounty-map-column]]、[[project-miliui-voidcore-currency]]。

- **記錄存 `MiliUI_InfoBar_DB.warband.characters`**（key「角色名-伺服器」）。它是資料不是設定：`ns.ResetDB` 整包留著，遷移印記 `warband.migration` 也在裡面。
  遷移照 [[project-miliui-focus-addon]]：PLAYER_LOGIN 才跑、唯讀 MiliUI_DB、沒東西可搬也蓋印記、只搬 key 不存在的。
- **追蹤永遠在跑，不看方塊有沒有啟用**。全部走 `ns.Events`（有 pcall）。
- ⚠⚠ **角色記錄是好幾支函式各存各的欄位（鑰石／vault／raids／mplusRuns），任何一支存檔時只能就地更新自己那幾欄，不能整筆重建**
  （2026-10-01 `cbbf7212f`：`SaveKeystoneRecord` 整筆重建、只帶走 vault，raids 被丟掉 ⇒ 換鑰石後團本進度變「尚無記錄」；現在 `EnsureOwnRecord` 取既有那筆就地改）。
  同類：**登出不存團本**（PLAYER_LOGOUT 當下副本名還在、首領快取已清，存了全變 0/0，`bc1273bc0`）；只在 UPDATE_INSTANCE_INFO 之後存（冷快取 `GetNumSavedInstances` 回 0）。
- **鑰石追蹤聽包包，不猜活動**：觸發點只有 `BAG_UPDATE_DELAYED`／`ITEM_CHANGED` → `ScheduleKeystoneCheck`。舊版掛 CHALLENGE_MODE_COMPLETED／GOSSIP_CLOSED／WEEKLY_REWARDS_UPDATE，
  寶庫那條抓不到（WEEKLY_REWARDS_UPDATE 是「開寶庫」時發，領取時早沒人在看）。鑰石不管哪裡來最後都是一件物品進包包。`/mib keydebug` 看 `KeyCheck#n`。
- **面板掛 UIParent 不掛 bar**（bar 是隱式保護框）；皮走提示皮；strata DIALOG、寶庫提示 TOOLTIP、列選單 W.Menu。**定位＝先翻面再平移**（預設往下長、塞不下才翻上；水平貼齊方塊離畫面中線近的那一邊；
  翻完還出界才 `W.PlaceClamped`）。資料變了重畫後要**再定位一次**。
- 方塊 OnEnter 在面板開著時不彈提示。秘密值：`UnitGUID("npc") or UnitGUID("target")` 那種先 `S.PlainText` 再 or；widget tooltip、地城名也過 PlainText。
- **寶庫欄表頭是 Button**，左鍵循環 total → raid → mplus → world，存 `db.warbandVaultMode`（是設定不是資料，刻意不放 `db.warband`）。欄寬在建框時用四種標題的最大值定死。
  總計＝整欄一個 `已解鎖/總格數`，顏色三階：**0～1 橘紅、2 黃、≥3 綠**。
- **團本提示**（`ShowRaidTip`）：滑過列在面板旁開「團隊副本進度」。來源 GetSavedInstanceInfo／GetSavedInstanceEncounterInfo（只收團本＋鎖定中）＋團搜 GetRFDungeonInfo／GetLFGDungeonEncounterInfo
  （按副本併組、首領去重取 OR、等 LFG_LOCK_INFO_RECEIVED）。讀到「有鎖定、沒首領」沿用上次的首領清單。2026-10-12 團本進度下方疊出本週 M+ 紀錄（`vault.mplusRuns`）。
- 表格上每個吃滑鼠的子框都要接 CancelClose／ScheduleClose（[[wow-child-frame-steals-mouse-focus]]），寫在原本的 SetScript 裡不要 HookScript。方塊左鍵**只開不關**。
- 指令：`/mib keydebug`、`/mib stash`（探測儲物箱 widget）。

## 坐騎區塊（2026-09-14）

`Core/Mounts.lua`＋`Core/MountPopup.lua`＋`Options/Tab_Mounts.lua`＋Blocks.lua 的 `mounts` 方塊。左鍵／右鍵各召喚一隻快捷坐騎，滑過列出各分類（修裝／塑形／拍賣／信箱）。
- **沒有 API 能判斷功能型坐騎**，清單只能硬編＋讓玩家自己加。硬編用 **spellID**，執行期 `GetMountFromSpell` 換 mountID（只快取查到的）。
  種子：雷龍 264058、鍍金雷龍 465235、犛牛 122708、馱獸 457485、猛獁象 61425／61447。
- `C_MountJournal.SummonByID` 的 `SecretArguments = AllowedWhenUntainted`，傳明文 mountID 從插件 Lua 直呼合法 ⇒ 方塊是普通 Button，**不需要 secure 轉發**。
- **種子的 categories 陣列不能放進 DB_DEFAULTS**（CopyDefaults 按索引補洞，玩家刪掉的分類每次登入又冒出來），用 `profile.version` 印記種。
- **收藏了不等於能騎**：陣營限定坐騎兩隻 isCollected 都 true。判準 `info.available = collected and factionOK and not shouldHideOnChar`。
- 滑過開面板 0.15 秒意圖延遲、離開 0.35 秒寬限；面板掛 UIParent、戰鬥中不開。拖放 `GetCursorInfo()` 回 `"mount", mountID`。

## 修裝按鈕與自動修裝

**耐久方塊滑過面板**（`Core/Repair.lua`＋`RepairPopup.lua`＋`Tab_Repair.lua`）：逐部位耐久＋三排方形圖示按鈕（道具／玩具／坐騎），只列擁有且沒被關掉的。
- **⚠ 這張面板是保護框，坐騎面板不是**：道具與玩具只能由 secure 按鈕的硬體點擊觸發（`UseToy` 是 `#protected`）。收面板走 `SecureHandlerStateTemplate` ＋ `RegisterStateDriver(f,"combat","[combat] 1; 0")`
  ＋`_onstate-combat` snippet `self:Hide()`（`ns.Events` 的 PLAYER_REGEN_DISABLED 延一幀派送，輪到我們時已經鎖了）。方塊的 OnEnter 在戰鬥中退回 GameTooltip。
- **⚠⚠ 面板的 OnHide 要把工作丟到 `ns.NextFrame`**：它可能是 secure snippet 在戰鬥開始那一刻叫出來的，整條執行流程是暴雪的。
- secure 按鈕上**只有** `*type1`／`*item1`／`*toy1`／`useOnKeyDown=false`＋OnEnter／OnLeave，不掛 PreClick／OnClick Lua；屬性值沒變就不重寫。
- **硬編 ID 每次大改版要重驗**：道具 18232／34113／40769／49040／132514／221957／221956（⚠ 11590 **不是** 74A，它是修機械寵物的「機械修理包」，repo 裡有插件標錯）。
  **玩具一個都沒有**（`R.TOYS` 是查證結論不是待填）。坐騎不硬編：讀坐騎分頁 id == "repair" 的分類。
- **沒有「回 duration 物件」的物品冷卻 API**，照舊讀 `C_Item.GetItemCooldown`（⚠ 第三個回傳在 C_Item 是 **bool**，C_Container 的同名函式才是 number——用 PlainNumber 洗會把 false 洗成 nil）。
  `C_ToyBox.IsToyUsable` 未文件化，SafeCall＋ToBool，問不到就當可用。
- DB：`repair = { hidden = {} }`，**存「關掉哪些」不存「顯示哪些」**（新增道具才會自己出現）。事件只在面板或設定頁開著時註冊（`R.Watch(key, on)`）。

**自動修裝：兩邊都有、設定一份**（`Core/AutoRepair.lua`，2026-09-19 從本體搬來、09-23 本體加回——9/19 搬走後**沒開資訊列的玩家就沒修裝**）。
- 判準＝`MiliUI_MerchantAutomation.IsAutoRepair` 在不在（呼叫當下問）：在 ⇒ 本體修（`MiliUI_DB.merchant.autoRepair` 預設開、`guildRepair` 預設關），資訊列的 getter/setter 轉讀寫本體那份並鏡像到自己的 `db.repair`；
  不在 ⇒ 資訊列用 `db.repair` 修。**本體不要為了相容補空殼 API**，補了兩邊都不修。
- 同步印記 `db.repair.coreSync`＝上次登入本體在不在：本體在＋nil ⇒ 資訊列值**推給本體**；本體在＋true ⇒ 本體值**抄回資訊列**；本體不在 ⇒ 清掉。
  `ns.ResetDB` 要保留 coreSync（與 `migration`），不然還原的預設下次登入推回本體。Leatrix 撞車提醒本體在時只由本體印。
- 入口：耐久面板最上面兩列勾選＋「修裝」分頁最上面一節（方塊被收掉時的唯一入口）；本體 Tab_QoL **不留指路文字**。加 check 列後整張面板縮排 30px 是列層 gutter 規則，不是跑版。

## 確認倒數區塊（2026-09-14）

`Core/ReadyCheck.lua`＋`ReadyCheckPopup.lua`＋`Tab_ReadyCheck.lua`。`db.readycheck = { onlyInGroup, left/middle/right = { action, seconds } }`，action = none｜readycheck｜countdown｜cancel。
- **動作走 secure 巨集跑暴雪原生指令**：`/readycheck`、`/cd N`、`/cd 0`。方塊是 SecureActionButton，`*typeN`／`*macrotextN`（左 1、右 2、中 3）。
  DoReadyCheck／DoCountdown 是 HasRestrictions，插件端直呼在首領戰／鑰石被擋（[[wow-12x-addon-restrictions]]）；快捷聊天列那顆從 Lua 呼叫 DoCountdown 的那半**不要抄**。
- 「在隊伍／團隊內啟用」＝不在 `IsInGroup()` 時 `_blockHidden`。
- 面板內容：三顆鍵 → 沒反應的原因（不在隊伍／沒權限，暴雪指令安靜失敗）→ Cell 標記工具列開關 → 設定入口。
  **Cell 開關不另存值**：讀寫 `CellDB.tools.marks[1]`＋`Cell.Fire("UpdateTools", "marks")`；戰鬥中不切。

## 滑過面板共用層 HoverPanel（`Core/HoverPanel.lua`）

坐騎／修裝／確認倒數三張面板共用的**唯一**皮與節奏來源；戰隊表格走控制器（節奏）但**不走列層**。**版面數字不准搬回面板檔**。
- 常數：G=6、PAD_X 10、ROW_H 28、TITLE_H 26、ICON 22、GUTTER 30、MIN_W 220、MAX_W 380；開啟 0.15、離開 0.35（世代 token）。
- 列層 `rows:Render(model)` 兩趟排版，kind：title／item／sep／note／settings／custom。列池化。
- 控制器 `HP.New{ name, secure, build, populate, onOpen, onHide, allowCombat, beforeOpen, keepOpen }`：`secure=true`（修裝）走 state driver 收面板；
  `allowCombat`（戰鬥中照開、不自動收）；`beforeOpen`（Build 後 Populate 前跑一次，戰隊在這裡 RefreshOwn）；`keepOpen`（回 true 就**續排**下一輪關閉：列選單開著時游標在面板外，選單關掉後不會再有 OnLeave）。
- **模型裡 `sep` 後面不可以直接接 `title`**（兩條線夾一行灰字），規則在 [[feedback-ui-visual-style]] 與 miliui-menu-design 技能。

## 外部方塊接口 MiliUI_InfoBarPlugins（2026-09-22）

`Core/Plugins.lua`。形狀照 `MiliUI_MenuEntries`：註冊方在自己的入口檔**檔案層**往全域表塞 `{ key, text, label?, desc?, order?, enabled?, OnClick(tile, button)?, OnTooltip(tooltip)? }`，
沒裝那支插件＝沒人塞＝沒有方塊。
- `ns.Plugins.Sync()` 在 **ApplyAll 開頭每次都跑**；存檔缺格補預設——⚠ 不能只在第一次見到 key 時跑，`ns.ResetDB` 會把 db.blocks 清掉。
- 存檔 key 一律 `ext_<key>`。隨選載入的註冊方：ADDON_LOADED（`IsLoggedIn()` 之後）再 Sync。
- 看板的名字／說明走 `ns.Plugins.Label/Desc`，**不能**照內建規則查 `L["BLOCK_EXT_…"]`（AceLocale 缺鍵警告）。
- **刻意只給普通按鈕**：第三方 Lua 掛在 secure 方塊上就是 CreateTile 那段的污染問題。沒有 refresh API。
- `check_lua.py` 的 ALLOWED_GLOBAL_WRITES 已放行。使用者：[[project-miliui-mythicplus]] 的「M+結算」。

## 待驗證（沒進過遊戲）

09-06 效能對帳、09-07 taint 破案、09-21 taint.log 系列都是實機——secure 轉發／hider／編輯模式／遊戲選單鈕／戰隊表格戰鬥中滑開顯然跑過。剩下：
- 戰隊：遷移訊息與筆數、面板在 bar 貼頂／貼底／靠右三種位置的翻面、「分身key」關鍵字在 zhTW／enUS 各自的觸發、enUS 下寶庫欄變寬的量。
- 坐騎：猛獁象修裝、`GetCursorInfo` 的 mount 格式、isCollected 會不會是秘密布林（現在 fail-open 當已收藏）、面板翻面。
- 修裝：戰鬥中面板有沒有被 state driver 準時收掉（以及脫戰後不會自己冒出來）、secure 按鈕實點道具與玩具（ActionButtonUseKeyDown 兩種各試）、冷卻扇形、
  `Item:ContinueOnItemLoad` 補道具名的時機、自動修裝遷移後兩個開關的值。
- 確認倒數：`/cd` 在 zhTW 客戶端的巨集裡有效（同路線先例在繁中可用）、中鍵實點、Cell 設定視窗開著時勾選框是否即時同步。
- HoverPanel：三張面板同字級下一致、四張面板貼頂／貼底翻面一致、keepOpen 續排。

相關：[[project-miliui-widgets-vendor]]、[[wow-121-secret-values]]、[[project-miliui-hud-skin]]
