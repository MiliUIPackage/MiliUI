---
name: project-miliui-infobar
description: MiliUI_InfoBar 資訊列——取代微型選單的自製條；secure 點擊轉發／暴雪列 hider／戰鬥紀律／待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: c0d1056b-afe5-4f0b-a0d1-24a0f3f4c05d
  modified: 2026-08-29T15:28:31.411Z
---

`AddOns/MiliUI_InfoBar/`（2026-08-29 新增）。純色方底一長條：資訊區塊（裝等／耐久／
天賦／擲骰／金幣／時鐘／FPS／延遲／CPU／記憶體／地區）＋微型選單按鈕混排，視覺
沿用 Chattynator 按鈕那套（0.115 底、1px 0.30 邊、滑過職業色）。架構照
`tmp/EllesmereUI-v9.0.7` 的 DataBars 研究成果，模板抄 [[project-miliui-esc-menu-window-migration]]
的 BloodlustMusic（Panel／Tab／BlizzOptions／AceLocale），共用層 NAMESPACE=`MiliUIInfo`。

## 三個承重機制（改動前要懂）

1. **微型按鈕＝secure 點擊轉發**：每顆是 `SecureActionButtonTemplate`，
   `*clickbutton1` 指暴雪 MicroButton、`*type1="click"`、`useOnKeyDown=false`
   （少這行 ActionButtonUseKeyDown CVar 會把 AnyUp 點擊丟掉）。12.1 起天賦／法術書
   **必須**走 secure 點擊——addon Lua 直開會污染，之後 SpellBookItem 的 SetCooldown
   吃到秘密值就崩。**刻意不掛戰鬥鎖**（EUI 有掛）：戰鬥中能點開天賦、換擲骰正是需求。
2. **藏暴雪那排只能走 secure hider**，而且要藏 **`MicroMenu`（按鈕格）不是
   `MicroMenuContainer`（容器）**：`QueueStatusButton`（排隊中的綠色眼睛）的父層
   就是容器，跟按鈕格是兄弟。藏容器會把眼睛一起帶走，而那顆眼睛不只顯示排隊狀態
   ——**「有人申請入隊」的音效是掛在它的 `EyeHighlightAnim` 迴圈 `OnLoop` 上**
   （Blizzard_QueueStatusFrame/Mainline/QueueStatusFrame.xml），動畫不跑連聲音都
   沒了。EUI 的結論一樣：排隊眼睛只管位置、`noManagedVisibility` 不碰顯示。
   其餘關於 hider 本身：MicroMenuContainer 是 Edit Mode 管理框，
   insecure `:Hide()` 會污染 managed frame system（症狀：離開載具時
   ActionBarController_UpdateAll 被封鎖）。`SecureHandlerStateTemplate` 的
   `_onstate-vis` ＋ RegisterStateDriver **常數狀態**——snippet 只跑一次，外力
   （載入畫面、編輯模式）Show 回來要靠 force 重推（進世界、EditMode OnHide 兩處）。
3. **bar 是隱式保護框**：裝了 secure 子按鈕後整條連祖先都被保護，戰鬥中
   Show/Hide/SetPoint/SetSize 全被封鎖，只有 SetText/SetVertexColor/SetAlpha 合法。
   所以 ApplyAll 與 Layout 進戰鬥一律整包 `ns.Defer` 到脫戰；寵物對戰只降 alpha。
   編輯模式選取框掛在 bar 上；它連坐被保護，所以隱藏路徑走 `ns.Defer`——
   戰鬥強制關閉編輯模式那條路的 Hide 不能直接執行。
   **拖曳不用 StartMoving**：掛 UIParent 的獨立框版本與掛 bar 的版本實測都
   拖不動（懷疑是保護框＋StartMoving 的組合），改照 MiliUI_DamageMeters
   `Meter/Move.lua` 的手動機制——記按下時的游標與框位、拖曳中每幀用游標
   差值 ClearAllPoints/SetPoint（OOC 對保護框合法），driver 只在拖曳中有
   OnUpdate。

## 踩到的雷（已解）

- **遊戲選單那顆不能走 secure 轉發**：12.1 的 `MainMenuMicroButtonMixin:OnClick`
  第一行是 `if ( self:IsMouseOver() ) then`（Blizzard_MicroMenu/Mainline/
  MainMenuBarMicroButtons.lua）——轉發點擊時滑鼠在我們的按鈕上、不在被藏起來的
  原鈕上，整個 handler 空轉。這就是 EUI 把 menu 做成 plain button 的原因。
  其餘 12 顆的 mixin 沒有這個閘，secure 轉發實測正常（戰鬥中含天賦都能開）。
- **預設位置跟隨官方那排**：沒拖過（db.x/y=nil）就讀 `MicroMenuContainer:GetCenter()`
  換算成 UIParent 座標（乘有效縮放比），被 hider 藏著也讀得到（錨點都在）；
  登入那刻 rect 不一定就緒，PLAYER_ENTERING_WORLD 再算一次。DB_DEFAULTS 刻意
  不放 x/y——CopyDefaults 會把「沒拖過」這個 nil 狀態蓋掉。

- **EditModeSystemSelectionTemplate 的 XML 綁了 OnMouseDown →
  EditModeManagerFrame:SelectSystem(self.parent)**。借用模板的自訂框不是真系統，
  點一下不拖就把 UIParent 塞進暴雪選取流程（報錯＋污染）。必須
  `SetScript("OnMouseDown", function() end)` 中和。套組其他七處同病（已開 task 修）。
- 區域變數不要叫 `MicroMenu`——暴雪 DF 起有全域框就叫這名字，而 hider 現在就是
  拿它當目標，遮蔽掉會直接壞掉。
- **教學提示（HelpTip）要重錨**：暴雪把黃色泡泡錨在**原鈕**上
  （`HelpTip:Show(UIParent, info, microButton)`，MainMenuBarMicroButtons.lua 的
  `MainMenuMicroButton_ShowAlert`），原鈕藏起來但位置還在右下角，提示就飛過去。
  **不要搬暴雪的按鈕**去對位置——它們是 GridLayoutFrame 的子物件，容器一重排就
  蓋掉，而且顆數／尺寸會變。正解是 `hooksecurefunc(HelpTip, "Show", ...)`，從
  `HelpTip.framePool:EnumerateActive()` 用 `frame.info == info`（同一張表的參照）
  找出那個提示框，把 `frame.relativeRegion` 換成對應方塊。查表走 refToTile，
  顆數尺寸怎麼變都自動對得上。
  ⚠ 這裡有三個各自都足以讓它整組失效的坑，三個都是實測踩出來的：
  1. **比對要用 `frame.relativeRegion`，不能用 `frame.info`。**
     `MainMenuMicroButton_ShowAlert` 每次呼叫都新建一張 helpTipInfo，而
     `HelpTip:Show` 在「同樣的文字已經在顯示中」時會**提前 return、不重建 frame**
     （HelpTip.lua:181）——舊 frame 的 info 跟這次傳進來的不是同一張表。
  2. **要主動補掃一次現役提示。** 掛勾只接得到之後的 Show；登入當下就掛著、
     而且會一直留到玩家按叉叉的那種（PvP 天賦欄位）在掛勾前就顯示完了，
     之後不會再有 Show 呼叫。ApplyAll 之後延一幀掃 `EnumerateActive()`。
  3. **⚠⚠ 只換 `relativeRegion` 再叫 `AnchorAndRotate()` 不會有任何反應，也不報錯。**
     那支開頭有一道快取閘（HelpTip.lua:552）：
     `if targetPoint == self.appliedTargetPoint and alignment == self.appliedAlignment then return`。
     我們動的是錨定**對象**，targetPoint／alignment 都沒變 ⇒ 直接 return，連每幀跑的
     OnUpdate 也被同一道閘擋掉。**要先把 `appliedTargetPoint` / `appliedAlignment`
     設成 nil**，它才會真的重算。
     箭頭方向也在同一支裡處理（RotateArrow ＋ AnchorArrow），所以讓它重算就位置與
     箭頭一起對；要決定的只有泡泡在哪一側：方塊在畫面下半 → `TopEdgeCenter`
     （泡泡在上、箭頭朝下），上半 → `BottomEdgeCenter`。**寫進 `info.targetPoint`，
     不要用 AnchorAndRotate 的 override 參數**——OnUpdate 每幀拿 `info.targetPoint`
     重算，只傳 override 下一幀就被翻回去。
     **教訓：欄位對了不等於畫面對了。** 這一輪繞了三次 /reload 才逼出真因——診斷
     只印狀態欄位是不夠的，一定要連**實際座標**一起印（方塊的 x 對泡泡的 x）；
     而「改了沒反應又不報錯」的第一嫌疑犯是**早退快取**，不是拋錯。
- **原鈕的閃爍要鏡射**：原鈕藏起來後，暴雪畫在它身上的提示（有人申請、法術書有
  新東西）就看不到了。掛全域 `MicroButtonPulse` / `MicroButtonPulseStop`
  （MainMenuBarMicroButtons.lua）把閃爍轉到我們的方塊上——**不要去列舉「哪些情境
  會閃」**，那份清單散在十幾支暴雪檔案裡，列舉一定會漏而且改版就過期。
  聲音不用管：`PlaySound` 跟框的顯示狀態無關（唯一例外是上面那顆眼睛）。
- 圖示不自備圖檔：執行期讀暴雪按鈕 `GetNormalTexture():GetAtlas()`，單色風格
  SetDesaturated＋上色、彩色風格原圖直出；atlas 是直式（約 32x41），要按
  C_Texture.GetAtlasInfo 的比例縮，塞正方形會壓扁。角色鈕用 SetPortraitTexture。
- 效能紀律：事件能通知的全走事件；輪詢集中一支 Metro（沒有輪詢區塊時 ticker 不存在）；
  CPU 讀 C_AddOnProfiler、記憶體讀 collectgarbage("count")，**絕不**輪詢
  UpdateAddOnMemoryUsage（[[wow-addon-profiler-cost]]）；SetTileText 文字沒變短路、
  寬沒變不重排。
- 天賦名的事件坑（EUI 實測）：TRAIT_CONFIG_UPDATED 時 last-selected 指標還是舊的，
  要等 SPELLS_CHANGED 收尾；兩個都註冊、處理冪等。擲骰 SetLootSpecialization 是
  非保護偏好呼叫，戰鬥中合法，選單不掛戰鬥閘。
- 編輯模式訊號走**三重保險**：EditModeManagerFrame 的 OnShow/OnHide 掛勾＋
  `hooksecurefunc(EditModeManagerFrame, "EnterEditMode"/"ExitEditMode")`（方法本體，
  編輯模式真的啟動就必然執行）＋ `EventRegistry` 的 `"EditMode.Enter"/"EditMode.Exit"`
  （官方在 EnterEditMode／ExitEditMode 內部發的）。全部冪等。
  選取框**開檔就建**——進了編輯模式才在暴雪的 OnShow 路徑裡建框是沒驗證過的
  時序；建立包 pcall（DamageMeters 同款防禦），失敗就自畫藍框頂著。
  完整步驟已整編進 wow-editmode-draggable 技能（2026-08-29 重寫）。
- 設定視窗開著＝職業色「拖曳移動」遮罩蓋整條（照 MiliUI_Minimap 的慣例：
  開設定多半就是要搬家；右鍵回預設位置）。遮罩是保護框子層，Show/Hide 走
  ns.Defer。編輯模式的藍框跟這套遮罩是**兩套視覺**。
- CPU／記憶體方塊點擊直達 MiliUI 本體效能監控的對應子分頁：本體在
  `Api.lua` 出全域 `MiliUI.OpenPerf("cpu"/"ram")`（內部走 Tab_Perf 的
  `ns.OpenPerfPage`——先寫 `DB().page` 再開窗，讓 ShowOptionsTab 自己選頁）。
  資訊列在建立時檢查入口在不在，沒裝本體就退回純顯示不吃滑鼠。
- **排一列東西不要用「累加游標」定位，要鏈式錨定。** 間距設 0 卻在某兩塊之間
  露出一條縫的成因：`P.Size` 把每塊寬度捨到像素格，而游標是用未捨入的
  `desiredW` 推進的，誤差一路累積，跨過一個像素就露縫——所以**只有某幾個**
  邊界有縫、其他正常（這就是它的指紋，看起來像隨機）。修法是每塊
  `SetPoint("LEFT", 前一塊, "RIGHT", gap, 0)`，貼齊交給引擎保證；總寬要用
  `GetWidth()`（已捨入）加總，外框才會剛好包住。附帶好處：某塊文字變寬時
  後面的會即時跟著滑，不必等重排。相關 [[project-miliui-pixel-snapping]]。
- 區塊分頁是方塊拖曳看板（照 MiliUI_Tooltip 的 Options/Tab_Unit.lua：拖曳換位、
  拖進「不顯示」或點一下開關、滑過看說明）。DB 仍是 blocks[key]={enabled,order}，
  看板只是視圖，拖放後整條序列重編成 10/20/30 寫回 order。

## 待驗證清單（還沒進過遊戲）

- secure 轉發在戰鬥中實點（天賦、角色、收藏）；ActionButtonUseKeyDown 兩種設定各試。
- hider 開關與編輯模式進出後暴雪列的狀態；載入畫面後的 force 重推有沒有生效。
- 編輯模式拖曳＋選取框標籤；戰鬥中被強制關閉編輯模式那條路。
- 單色圖示的去飽和效果與職業色滑過；彩色 atlas 的比例；角色頭像更新（換裝）。
- 字寬變化（fps 兩位↔三位）會不會抖動；戰鬥中凍結版面、脫戰補齊。
- MENU（右鍵配置／擲骰選單）在戰鬥中的行為。

相關：[[project-miliui-widgets-vendor]]、[[wow-121-secret-values]]、[[project-agent-dir-convention]]

## 戰隊資訊區塊（2026-09-05）

把本體 `MiliUI/Enhance/CharacterKeystones.lua`（掛在 KeystoneLoot 視窗旁的
「角色鑰石記錄」面板）整組搬進資訊列並從本體刪除：`Core/Warband.lua`（資料層：
鑰石／寶庫快照／懸賞圖／儲物箱追蹤、隊伍回報、「分身key」關鍵字）＋
`Core/WarbandPopup.lua`（表格面板、寶庫提示、列選單）＋ Blocks.lua 的 `warband` 方塊
（字讀即時 `GetOwnedKeystone*`，左鍵開關面板、右鍵選單）。行為逐條照搬，相關判準
仍在 [[project-miliui-vault-tracking]]、[[project-miliui-bounty-map-column]]、
[[project-miliui-voidcore-currency]]（路徑已更新）。

- **記錄存 `MiliUI_InfoBar_DB.warband.characters`**（key「角色名-伺服器」，結構同舊的
  `MiliUI_DB.characterKeystones`）。它是資料不是設定：`ns.ResetDB` 整包留著，
  遷移印記 `warband.migration`（nil／"migrated"／"none"）也在裡面 —— 清了下次登入
  又會從 MiliUI_DB 搬一次舊記錄回來。遷移照 [[project-miliui-focus-addon]] 的規矩：
  PLAYER_LOGIN 才跑、唯讀 MiliUI_DB、沒東西可搬也蓋印記、只搬 key 不存在的。
- **追蹤永遠在跑，不看方塊有沒有啟用**：要看的是其他角色的資料，只能在登入那隻時記。
  全部走 `ns.Events`（有 pcall，`ACTIVE_DELVE_DATA_UPDATE` 那種可能不存在的事件名不會炸）。
- **面板掛 UIParent 不掛 bar**：bar 是隱式保護框，掛底下戰鬥中開不了。皮走提示皮
  （0.133 不透明＋1px 職業色邊，[[project-miliui-hud-skin]]）；strata DIALOG，
  寶庫提示 TOOLTIP，列選單走共用層 W.Menu（FULLSCREEN_DIALOG）。
- **定位＝先翻面再平移**（使用者點名：bar 在最上面時面板往上會撞，要往下）。
  預設往下長、下緣塞不下才翻成往上；水平貼齊方塊離畫面中線近的那一邊；翻完還出界
  才 `W.PlaceClamped` 推回。寶庫提示同理（預設右邊、右緣撞到翻左邊）。
  資料變了（listener）重畫後要**再定位一次**——高度變了翻面結果可能不同。
- 表頭欄寬取「最小寬」與「表頭字寬＋6」的大者，語系換了不會擠爆。
  Syndicator 那欄在第一次 Build 時決定要不要有（非 LoD 插件都在 PLAYER_LOGIN 前載完）。
- 方塊 OnEnter 在面板開著時**不彈提示**（同錨點會疊，hud-skin 那條）。
- 秘密值：`UnitGUID("npc") or UnitGUID("target")` 那種「對原始回傳做真值判斷」改成
  兩邊先 `S.PlainText` 再 or；widget tooltip、地城名也都過 PlainText。
- 指令：`/mib keydebug` 開追蹤輸出、`/mib stash` 探測儲物箱 widget（取代舊的 `/milikeydbg`）。

待驗證（沒進過遊戲）：遷移訊息與筆數、面板在 bar 貼頂／貼底／靠右三種位置的翻面、
右鍵寶庫格會不會經 `SetPropagateMouseClicks` 傳到列、ESC 關面板後 OnHide 的清理、
戰鬥中點方塊開面板、「分身key」關鍵字在 zhTW／enUS 客戶端各自的觸發。


## 停靠模式（2026-09-05）

`db.dock` = none|top|bottom、`db.dockPush`。停靠＝兩角錨在 UIParent 那個邊（Layout 只設高、不 SetSize），
拖曳關掉（`BeginBarDrag` 早退、搬家遮罩改顯示「已停靠」）。「推開」走 [[wow-uiparent-inset-dock]]：
`ApplyInset` 把 UIParent 往內縮一條（只在需要改變時才動它），資訊列錨在縮出來的那條上；
關掉資訊列或停靠都會把 UIParent 放回去。UI_SCALE_CHANGED／DISPLAY_SIZE_CHANGED 再貼一次。
左右停靠沒做：tile 是橫向鏈式錨定，直向要另寫排版。填滿後區塊全部靠左，分左中右三組是下一步。
