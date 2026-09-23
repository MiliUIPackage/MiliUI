---
name: project-miliui-infobar
description: MiliUI_InfoBar 資訊列——取代微型選單的自製條；secure 點擊轉發／暴雪列 hider／戰鬥紀律／**外部方塊接口 MiliUI_InfoBarPlugins**／待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: c0d1056b-afe5-4f0b-a0d1-24a0f3f4c05d
  modified: 2026-09-22T00:00:00.000Z
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
   戰鬥中離開編輯模式那條路的 Hide 不能直接執行（暴雪**不會**因為進戰鬥就關掉編輯模式，
   戰鬥中照樣進得去也出得來，2026-09-18 taint.log 查證）。
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
  **現況（2026-09-21，四版才定案）**：那顆是 `SecureHandlerClickTemplate`，`_onclick` snippet 對
  frame ref 直接 `Show(true)`／`Hide(true)`，**戰鬥內外同一條路**。restricted 環境的執行是乾淨的
  ⇒ OnShow → InitButtons 建的選單按鈕（編輯模式、選項…）不帶我們的 taint。
  restricted 環境戰鬥中只拿得到**保護框**（`GetHandleFrame`：非保護框＋InCombatLockdown ⇒
  Invalid frame handle），GameMenuFrame 原廠不是 ⇒ **掛一個 1×1 的 `SecureFrameTemplate` 空框在
  它底下**，父框底下有保護框＝隱式保護框，從登入起就確定。
  **⚠ 那顆空框上一個欄位都不能寫，`ignoreInLayout` 也不行**：GameMenuFrame 是 layout frame，
  `Layout()` 逐一讀每個子框的 `ignoreInLayout`／`layoutIndex`（LayoutFrame.lua AddLayoutChildren），
  讀到我們寫的值整趟就染髒 ⇒ 接下來 `GameMenuFrame:SetSize()` 戰鬥中被擋，**連 ESC 開的也中**
  （taint.log：`LayoutFrame.lua:37 AddLayoutChildren()` 緊接 `blocked … GameMenuFrame:SetSize()`）。
  不寫就是乾淨的 nil，沒有 `layoutIndex` 的子框本來就不進版面。
  通則：**掛在暴雪 layout frame 底下的自製子框，別寫暴雪版面程式會讀的欄位名。**
  （TeleportMenu 的傳送按鈕本來就會讓它變保護框，但要第一次開選單才建。）
  走過的死路：
  - **「點擊 → 觸發 ESC」做不到**：沒有任何 secure 動作能執行按鍵綁定；插件呼叫
    `RunBinding`／`ToggleGameMenu()` 是髒的，戰鬥中還會被下一條擋。
  - **插件端戰鬥中不能用 `ToggleFrame`／`ShowUIPanel`／`HideUIPanel`**：UIParentPanelManager 的
    `CheckProtectedFunctionsAllowed` 寫死「戰鬥中不准插件開關 UI 面板」，直接 return 並印一次
    「介面功能因插件而失效」，**taint.log 完全不記**（每個 session 只印第一次，之後連訊息都沒有
    ⇒ 症狀是「點了沒反應」）。前兩版都栽在這，還誤判成保護框被靜默擋。
  - 插件端直接 `GameMenuFrame:SetShown()`：開得起來，但那一趟選單的按鈕全是髒的，
    而且 **TeleportMenu 的傳送按鈕不出現** —— 上游掛的是 `hooksecurefunc("ToggleGameMenu")`，
    只有 ESC 會觸發（暴雪原廠的選單圖示也一樣沒有）。套組裡已把它改成聽
    `GameMenuFrame` 的 OnShow（見 [[project-local-addon-forks]]），`MiliUI/Enhance/TeleportMenu_Spacing.lua`
    兩個都掛（冪等），上游洗回去也不會壞間距，只會回到「從圖示開沒有傳送」。
  **通則：判斷暴雪框是不是保護框不能只看暴雪原始碼，要看套組裡有沒有人往它底下掛 secure 子框。**
  snippet 的 Show 不經過面板系統（不會 CloseAllWindows、不佔 center 區），ESC 照樣關得掉。
  戰鬥中**第一次**開選單不會有傳送按鈕（TeleportMenu 戰鬥中建不了 secure 按鈕，ESC 開也一樣）。
  待實機驗證：戰鬥外／戰鬥中各點一次、傳送按鈕與間距、右鍵選單、ESC 關。
  其餘 12 顆的 mixin 沒有這個閘，secure 轉發實測正常（戰鬥中含天賦都能開）。
- **預設位置跟隨官方那排**：沒拖過（db.x/y=nil）就讀 `MicroMenuContainer:GetCenter()`
  換算成 UIParent 座標（乘有效縮放比），被 hider 藏著也讀得到（錨點都在）；
  登入那刻 rect 不一定就緒，PLAYER_ENTERING_WORLD 再算一次。DB_DEFAULTS 刻意
  不放 x/y——CopyDefaults 會把「沒拖過」這個 nil 狀態蓋掉。

- **EditModeSystemSelectionTemplate 的 XML 綁了 OnMouseDown →
  EditModeManagerFrame:SelectSystem(self.parent)**。借用模板的自訂框不是真系統，
  點一下不拖就把 UIParent 塞進暴雪選取流程（報錯＋污染）。必須
  `SetScript("OnMouseDown", function() end)` 中和。套組其他六處同病，2026-09-17 全部補上（後果見 [[wow-121-addon-code-in-secure-stack]] 入口 8）。
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
- 編輯模式拖曳＋選取框標籤；戰鬥中進／出編輯模式那條路。
- 單色圖示的去飽和效果與職業色滑過；彩色 atlas 的比例；角色頭像更新（換裝）。
- 字寬變化（fps 兩位↔三位）會不會抖動；戰鬥中凍結版面、脫戰補齊。
- MENU（右鍵配置／擲骰選單）在戰鬥中的行為。

相關：[[project-miliui-widgets-vendor]]、[[wow-121-secret-values]]、[[project-agent-dir-convention]]

## 戰隊資訊區塊（2026-09-05）

把本體 `MiliUI/Enhance/CharacterKeystones.lua`（掛在 KeystoneLoot 視窗旁的
「角色鑰石記錄」面板）整組搬進資訊列並從本體刪除：`Core/Warband.lua`（資料層：
鑰石／寶庫快照／懸賞圖／儲物箱追蹤、隊伍回報、「分身key」關鍵字）＋
`Core/WarbandPopup.lua`（表格面板、寶庫提示、列選單）＋ Blocks.lua 的 `warband` 方塊
（字讀即時 `GetOwnedKeystone*`，**滑過開面板**（2026-09-19 起，原本是左鍵開關）、右鍵選單）。行為逐條照搬，相關判準
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
- **鑰石追蹤聽包包，不猜活動**（2026-09-06）：觸發點只有 `BAG_UPDATE_DELAYED`／`ITEM_CHANGED`
  → `ScheduleKeystoneCheck`。舊版（本體時期就這樣，搬過來時一條沒漏）掛在
  CHALLENGE_MODE_COMPLETED／鑰石 NPC 的 GOSSIP_CLOSED／WEEKLY_REWARDS_UPDATE，寶庫那條
  抓不到：WEEKLY_REWARDS_UPDATE 是「開寶庫」時發，挑獎勵超過 7 秒重試窗口才按領取，
  鑰石進包包時已經沒人在看。鑰石不管哪裡來最後都是一件物品進包包／原地改寫，
  聽這個就是超集（LibOpenRaid／LibKeystone 也都這樣做）。KEYSTONE_NPC_IDS 表已刪。
  下次領寶庫可開 `/mib keydebug` 看 `KeyCheck#n` 那行確認 API 有跟上物品。

待驗證（沒進過遊戲）：遷移訊息與筆數、面板在 bar 貼頂／貼底／靠右三種位置的翻面、
右鍵寶庫格會不會落到列（寶庫格只吃移動，見下）、ESC 關面板後 OnHide 的清理、
戰鬥中點方塊開面板、「分身key」關鍵字在 zhTW／enUS 客戶端各自的觸發。


## 停靠模式（2026-09-05）

`db.dock` = none|top|bottom、`db.dockPush`。停靠＝兩角錨在 UIParent 那個邊（Layout 只設高、不 SetSize），
拖曳關掉（`BeginBarDrag` 早退、搬家遮罩改顯示「已停靠」）。「推開」走 [[wow-uiparent-inset-dock]]：
`ApplyInset` 把 UIParent 往內縮一條，資訊列錨在縮出來的那條上。**碰 UIParent 之前先用
`InsetMatches` 比對它現在的錨點**（2026-09-06：之前每次換區都強制重貼，一次就是 100 毫秒以上的尖峰）；
關掉資訊列或停靠都會把 UIParent 放回去。UI_SCALE_CHANGED／DISPLAY_SIZE_CHANGED 再貼一次。
停靠時底與框線由**整條 bar** 畫（`bar.bg`／`bar.edges`，`ApplyBarChrome`），tile 自己的底與框線 alpha 歸零——兩層半透明疊在一起 tile 區會比空白區深一階；滑過的職業色框線照舊。`db.dockAlign` = center（預設）|left|right：先量總寬再定第一顆的起點，捨到像素格；bar 寬由兩角錨定算出、第一次可能是 0，`OnSizeChanged` 寬一變就 RequestLayout。左右停靠沒做：tile 是橫向鏈式錨定，直向要另寫排版。

## 效能帳怎麼看（2026-09-06）

效能監控分頁把資訊列標紅（近期平均 1.7 ms、佔遊戲 9%）時，**先用 `/mib perf` 對帳再動手**：
`Core/Perf.lua` 常駐把所有 Lua 入口（事件派送、脫戰佇列、版面、計時器、UIParent 重貼、
掛勾、按鈕 PreClick→PostClick）各記最大一次／次數／≥10ms 次數；`/mib perf watch` 再逐幀
拿官方 LastTime 跟自己量到的對帳，量到≈0 才是沒包到的入口。

實測結論：資訊列自己的程式碼整場只跑十幾毫秒（登入初始化 ~11 ms 一次）。紅的是
**secure 轉發的點擊**——點天賦方塊 68 ms、那是暴雪開天賦視窗的成本，因為跑在我們按鈕的
OnClick 裡，分析器整段算給資訊列；「近期平均（最近 60 幀）」= 那一下 ÷ 60，所以會紅一陣子。
不是資訊列的問題，點官方那排一樣要花。另一個真的修掉的：停靠中每次換區強制重貼 UIParent
（見 [[wow-uiparent-inset-dock]]）。

第三個（最大宗、每 5 秒 90 ms）：CPU／記憶體方塊點開本體的效能分頁，分頁的 frame 在資訊列的
點擊裡建出來，之後它 OnUpdate 裡的 UpdateAddOnMemoryUsage 整場記給資訊列。修在本體那邊
（MiliUI/Api.lua 的 perfRelay 中繼框），規則見 [[wow-addon-profiler-cost]]。

## taint 紀律（2026-09-07 破案，整包快捷列 SetCooldown 秘密值的根）

四條入口全部收掉，改任何一條之前先看 [[wow-121-addon-code-in-secure-stack]]：

- **教學提示改鏡射不改錨**（`Core/MicroMenu.lua`）：暴雪 HelpTip 框的欄位一個都不寫、
  HelpTip 的 API 一個都不叫。文字讀出來畫自己的泡泡（每顆方塊一顆），暴雪那顆
  `SetAlpha(0)`＋關滑鼠隱形、`Release` 後置勾還原，叉叉走 `SetCVarBitfield`。方塊被
  使用者藏掉的那顆不動。第一版改 `relativeRegion` 的寫法就是根因：天賦視窗一開
  `EvaluateAlertVisibility` 收提示、`HelpTip OnHide` 讀回我們寫的欄位，整條開窗流程
  染成資訊列的——戰鬥中天賦打不開、ESC 關窗把所有快捷列格子收起來、每顆按鈕永久髒。
- **UIParent 內縮從 secure 端動**：`SecureHandlerExecute` snippet 裡 `SetPoint("$screen")`；
  延一幀沒用。戰鬥中 snippet 動不了 UIParent（不是保護框），照舊只在脫戰貼。
- **點擊派送裡 OnClick 前面沒有任何 Lua**：PreClick 耗時計拆掉、按下底色改引擎的
  `PushedTexture`；轉發用 `*macrotext1 = "/click <名字>"` 不用 `*clickbutton1 = 框`；
  右鍵選單走 `ns.SecureRightClick`（`SecureHandlerWrapScript` ＋ `control:CallMethod`）。
- **編輯模式進出、`UpdateUIParentPosition` 掛勾只改旗標／只讀**，工作丟 `ns.NextFrame`
  （跟脫戰延遲的 `ns.Defer` 是兩回事，那個沒在戰鬥就當場執行、擋不住這種）。

診斷靠 `_CDProbe`（隨套組發佈中）：`/cdprobe` 看引擎點名的封鎖、`/cdprobe scan` 掃
變數污染、`/cdprobe ui` 倒跨場次記錄。EUI 的對照：同樣的 clickbutton 轉發但戰鬥中用
state driver 把點擊拔掉、完全不碰 HelpTip——它沒踩坑是因為沒做這兩個功能。


## 坐騎區塊（2026-09-14）

`Core/Mounts.lua`（資料層）＋ `Core/MountPopup.lua`（滑過面板）＋ `Options/Tab_Mounts.lua`（設定分頁）
＋ Blocks.lua 的 `mounts` 圖示方塊（order 25，預設開，在微型選單左邊）。左鍵／右鍵各召喚一隻快捷坐騎，
滑過列出各分類（修裝／塑形／拍賣／信箱）已收藏的功能型坐騎，分類旁有「隨機」。

- **沒有 API 能判斷功能型坐騎**（GetMountInfoByID／Extra 只有取得方式、陸飛水、isSelfMount），
  清單只能硬編 ＋ 讓玩家自己加。硬編用 **spellID**，執行期 `GetMountFromSpell` 換 mountID
  （**只快取查到的**，登入那刻收藏冊不一定就緒）。種子：雷龍 264058、鍍金雷龍 465235、犛牛 122708、
  馱獸 457485、猛獁象 61425／61447（猛獁象修裝待遊戲內確認）。
- `C_MountJournal.SummonByID` 的 `SecretArguments = AllowedWhenUntainted` 是「秘密值參數只有未污染
  程式能傳」，傳明文 mountID 從插件 Lua 直呼合法 ⇒ 方塊是普通 Button，**不需要 secure 轉發**。
- **種子的 categories 陣列不能放進 DB_DEFAULTS**：CopyDefaults 遞迴合併會按索引補洞，玩家刪掉的分類
  每次登入又冒出來。DB_DEFAULTS 只有 `mounts = { shared = {}, chars = {} }`，種子用 `profile.version`
  印記在 Mounts.lua 種。角色專屬＝`chars[角色key]` 深拷貝 shared 一份、`enabled` 開關（關掉資料留著）。
- **收藏了不等於能騎**：陣營限定坐騎（猛獁象聯盟／部落版）兩隻 isCollected 都 true，修裝分類會出現兩次。
  判準是 `info.available = collected and factionOK and not shouldHideOnChar`（faction 0 部落／1 聯盟對
  UnitFactionGroup；中立或讀不到＝不過濾）。面板／自動挑選／隨機／選擇器／下拉全看 available，
  設定編輯器照列、灰標「其他陣營」。PLAYER_ENTERING_WORLD 作廢快取（換角色陣營不同）。
- 面板尺寸刻意不跟共用層右鍵選單（22/21/7）：列 28、圖 22、字級 +2、最小寬 260，最底固定一列「設定分類與坐騎…」入口。
- 左右鍵預設 nil＝自動（左：修裝優先序、右：拍賣優先序，每次點擊現算不存 DB）。
- 滑過開面板有 0.15 秒意圖延遲（游標橫掃資訊列會路過它）、離開 0.35 秒寬限（世代 token，判斷放到期時）。
  面板掛 UIParent、戰鬥中不開、PLAYER_REGEN_DISABLED 直接 Hide。
- 圖示 tile 的貼圖／單色上色抽成 `ns.ApplyTileIcon`／`ns.TintTileIcon`（Bar.lua），微型選單改用同一支；
  角色 key 抽成 `ns.CharKey()`，Warband 與坐騎共用。
- 收藏冊上千筆的掃描只在選擇器打開時做一次並快取（NEW_MOUNT_ADDED 作廢）。拖放：`GetCursorInfo()`
  回 `"mount", mountID`，換得回 mountID 才收。

待驗證（沒進過遊戲）：猛獁象修裝、GetCursorInfo 的 mount 格式、isCollected 會不會是秘密布林（現在
fail-open 當已收藏）、面板翻面（停靠上／下緣）、編輯器高度變動後的捲軸範圍、五顆分頁鈕在 zhTW 的寬度。


## 修裝按鈕（2026-09-14）

耐久方塊滑過的 GameTooltip 改成自製面板：`Core/Repair.lua`（資料層）＋
`Core/RepairPopup.lua`（面板）＋ `Options/Tab_Repair.lua`（「修裝」分頁）。
內容是逐部位耐久 ＋ 三排方形圖示按鈕（道具／玩具／坐騎），只列**擁有且沒被關掉**的。
開關節奏、提示皮、先翻面再平移整套照 MountPopup，那邊的註解不重抄。

- **⚠ 這張面板是保護框，坐騎面板不是。** 道具與玩具只能由 secure 按鈕的硬體點擊
  觸發（`UseToy` 是 `#protected`），所以裡面有 `SecureActionButtonTemplate` 的按鈕，
  整張面板連祖先都被保護 ⇒ 戰鬥中 Show/Hide/SetPoint/SetSize 全部被封鎖。
  收面板**不能**靠 `ns.Events` 的 PLAYER_REGEN_DISABLED（延一幀派送，輪到我們時已經
  鎖了）。走 `SecureHandlerStateTemplate` ＋ `RegisterStateDriver(f,"combat","[combat] 1; 0")`
  ＋ `_onstate-combat` snippet 裡 `self:Hide()` —— snippet 跑在引擎那一側，不受封鎖。
  Lua 這邊每個會動到框的入口（Hide／Place／Populate／ScheduleClose 的到期）都要先問
  `InCombatLockdown()`。方塊的 OnEnter 在戰鬥中退回**原本的 GameTooltip**（純顯示，
  任何時候都合法；少的只有那幾顆按鈕，戰鬥中本來也用不了）。
- **⚠⚠ 面板的 OnHide 要把工作丟到 `ns.NextFrame`。** 它可能是上面那個 secure snippet
  在戰鬥開始那一刻叫出來的，整條執行流程是暴雪的 —— 在裡面碰 GameTooltip、退訂事件
  就等於把 taint 注進去。跟 RegisterUnitWatch 的 Show() 觸發我們 OnShow 是同一類入口
  （[[wow-121-addon-code-in-secure-stack]]）。
- secure 按鈕上**只有** `*type1`／`*item1`／`*toy1`／`useOnKeyDown=false`，
  以及 OnEnter／OnLeave。**不掛** PreClick／OnMouseDown／OnMouseUp／OnClick 的 Lua，
  也不用 `*clickbutton1`（理由同 Core/Bar.lua 的 CreateTile）。道具用 `"item:ID"`
  不用包包格。屬性**值沒變就不重寫**。按鈕池化，每個 kind 一個池。
- **硬編 ID 每次大改版要重驗**，跟坐騎的功能型清單同一個維護點。2026-09-14 逐一對過
  wowhead 的效果文字：道具 18232／34113／40769／49040／132514／221957／221956
  （⚠ 11590 **不是** 74A，它是修機械寵物的「機械修理包」，repo 裡有插件標錯，別照抄；
  132514 自動鐵錘是唯一沒有工程學需求的）。**玩具一個都沒有** —— 布靈登系列只發禮物、
  沃特只賣爛食物、劫福斯要另裝維修模組（沒 API 問得出裝了哪個模組）⇒ `R.TOYS` 是空表，
  而且那是查證結論不是待填。排除清單寫在 Repair.lua 的註解裡。
- 坐騎**不硬編**：讀坐騎分頁裡 id == "repair" 的分類，玩家在那邊加的自動出現；
  分類被刪掉就退回 `ns.Mounts.FUNCTIONAL` 的種子，設定頁加一行灰字說明。
- **沒有「回 duration 物件」的物品冷卻 API**（查過 wiki 的 DurationObject 清單、
  ItemDocumentation／ContainerDocumentation、12.0／12.1 的 API changes：duration 系列
  只加了 Spell／SpellBook／ActionBar）。暴雪自己的 ActionButton 畫物品冷卻走的也還是
  `C_ActionBar.GetActionCooldown` ＋ `SetCooldown`。唯一的 duration 路徑
  `C_ActionBar.GetActionCooldownDuration` 吃的是快捷列**格子**，我們只有 itemID。
  所以照舊讀 `C_Item.GetItemCooldown`（文件上沒有 SecretReturns，回傳是明文；
  ⚠ 第三個回傳在 C_Item 這一支是 **bool**，C_Container 的同名函式才是 number —— 
  用 PlainNumber 洗會把 false 洗成 nil 變成「一直在冷卻」）。
- `C_ToyBox.IsToyUsable` 是**未文件化**的函式（不在 ToyBoxInfoDocumentation、wiki 沒頁面、
  暴雪自己的玩具箱也沒用），秘密值旗標查不到 ⇒ SafeCall ＋ ToBool，問不到就當可用。
- DB：`repair = { hidden = {} }`，key `"kind:id"`、值恆為 true。**存「關掉哪些」不存
  「顯示哪些」** —— 反過來的話新增一個修裝道具不會自己出現。
- 事件（BAG_UPDATE_DELAYED／BAG_UPDATE_COOLDOWN／TOYS_UPDATED／NEW_MOUNT_ADDED／
  MOUNT_JOURNAL_USABILITY_CHANGED）**只在面板或設定頁開著時**註冊，`R.Watch(key, on)`
  兩個消費者各自開關。
- 逐部位耐久的表（`R.SLOTS`／`SlotDurability`／`DurabilityColor`／`Lowest`）從 Blocks.lua
  搬進 Repair.lua —— 方塊與面板都要用，兩邊各留一份只會改到一邊。

待驗證（沒進過遊戲）：戰鬥中面板有沒有被 state driver 準時收掉（以及脫戰後不會自己冒出來）、
secure 按鈕實點道具與玩具（ActionButtonUseKeyDown 兩種設定各試）、圖示排換行的寬度、
冷卻扇形、提示錨在面板上下會不會擋到、`Item:ContinueOnItemLoad` 把沒看過的道具名字補上的時機。


## 確認倒數區塊（2026-09-14）

`Core/ReadyCheck.lua`（資料層）＋ `Core/ReadyCheckPopup.lua`（滑過面板）＋ `Options/Tab_ReadyCheck.lua`
＋ Blocks.lua 的 `readycheck` 圖示方塊（order 57，預設開，圖 `Interface\RaidFrame\ReadyCheck-Ready`）。
設定 `db.readycheck = { onlyInGroup = true, left/middle/right = { action, seconds } }`，
action = none｜readycheck｜countdown｜cancel；預設照快捷聊天列開怪鈕（左確認、中 5 秒、右 10 秒）。

- **動作走 secure 巨集跑暴雪原生指令**：`/readycheck`、`/cd N`、`/cd 0`（取消）。方塊是
  SecureActionButton，`*typeN`／`*macrotextN`（左 1、右 2、中 3）＋ `useOnKeyDown=false`。
  理由見 [[wow-12x-addon-restrictions]] 的 PartyInfo 那段：DoReadyCheck／DoCountdown 是
  HasRestrictions，插件端直呼會在首領戰／鑰石被擋。快捷聊天列那顆的倒數是自訂斜線指令再從 Lua
  呼叫 DoCountdown，**這半不要抄**。
- 「在隊伍／團隊內啟用」＝不在 `IsInGroup()` 時 `_blockHidden`，GROUP_ROSTER_UPDATE 只在可見度
  真的變了才 RequestLayout（戰鬥中 Layout 延到脫戰）。
- 滑過面板照 MountPopup 那套（提示皮、0.15 開／0.35 關、先翻面再平移），戰鬥中不開、改彈
  GameTooltip。內容：三顆鍵 → 沒反應的原因（不在隊伍／沒隊長助理權限，暴雪指令這兩種都安靜失敗）→
  Cell 標記工具列開關 → 設定入口。
- **Cell 標記工具列開關不另存值**：讀寫 `CellDB.tools.marks[1]`（Cell 勾選框背後的欄位）＋
  `Cell.Fire("UpdateTools", "marks")`；Cell 的 `frames.utilitiesTab` 可見時再
  `Cell.Fire("ShowOptionsTab", "utilities")` 讓它重讀勾選框（其他分頁的 ShowTab 非自己時只 Hide，
  重發無副作用）。`C_AddOns.IsAddOnLoaded("Cell")` 否或結構對不上就不顯示那列；戰鬥中不切。

待驗證（沒進過遊戲）：`/cd` 在 zhTW 客戶端的巨集裡有效（同路線的先例在繁中客戶端可用）、中鍵實點、
Cell 設定視窗開著時勾選框是否即時同步、面板在停靠上／下緣的翻面。


## 滑過面板共用層 HoverPanel（2026-09-14）

`Core/HoverPanel.lua`（`ns.HoverPanel`）：坐騎／修裝／確認倒數三張滑過面板共用的**唯一**皮與節奏來源；
戰隊表格 2026-09-19 起也走控制器（節奏），但**不走列層**（多欄表格不是一列一個選項）。面板檔只剩「有哪些列」（BuildModel）＋自己私有的東西
（修裝的 secure 圖示按鈕）。**版面數字不准搬回面板檔**——三張面板長得一樣是需求，複製一份就是下次分岔的起點。

- 常數：G=6（所有「反白 ↔ 線／邊」距離）、PAD_X 10、ROW_H 28、TITLE_H 26（線後再空 G）、SEP_H 2G+1、
  ICON 22、GUTTER 30（每列都留）、MIN_W 220、MAX_W 380；字級相對 db.fontSize：內容 +2、標題／說明／右側標 +1；
  開啟意圖延遲 0.15、離開寬限 0.35（世代 token，判斷放到期時）。
- 列層 `rows:Render(model)` 兩趟排版（先量寬再擺），kind：title（可帶右側扁平鈕 action）／item（icon 或 check、
  text、suffix、tag＋tagColor、dim、onClick／onRightClick、data）／sep／note／settings（tab）／custom（measure＋layout，
  給修裝的 secure 圖示排）。列池化。
- 控制器 `HP.New{ name, secure, build, populate, onOpen, onHide }`：`secure=true`（修裝）＝ SecureHandlerStateTemplate
  ＋ `_onstate-combat` 收面板、每個入口先問 InCombatLockdown、onHide 延一幀；非 secure 走 PLAYER_REGEN_DISABLED。
  列層的列是普通 Button；secure 按鈕由面板在 custom.layout 裡自建自池，控制器碰不到（不掛 PreClick／OnClick Lua）。
- **模型裡 `sep` 後面不可以直接接 `title`**（2026-09-19 使用者點名）：標題底下已有髮絲線，前面再一條收尾線
  就是兩條線夾一行灰字。小節靠標題＋留白分隔，sep 只給沒有標題的段落（底部說明、設定入口）。
  規則在 [[feedback-ui-visual-style]] 與 miliui-menu-design 技能。
- 對外名字（`ns.XxxPopup.Hide/ScheduleOpen/ScheduleClose/CancelOpen/…`）保留，Blocks.lua 不用改。
- 確認倒數的三顆鍵列改成跟坐騎快捷列同款：主文字＝動作、右側灰標＝鍵名（原本鍵名在左）。

待遊戲驗證：修裝面板進戰鬥由 state driver 收、secure 按鈕實點、三張面板同字級下一致、確認倒數打勾欄對齊、
修裝圖示排換行、四張面板貼頂／貼底翻面一致。


## 自動修裝改成兩邊都有、設定一份（2026-09-23，取代下面 9/19 那節的「本體只剩賣垃圾」）

- 起因：9/19 搬走後**沒開資訊列的玩家就沒修裝**。現在本體 `Merchant_Automation.lua` 把修裝加回來
  （`MiliUI_DB.merchant.autoRepair` 預設開、`guildRepair` 預設關，GetDB 又補預設了），便利功能分頁有兩個開關。
- 判準＝`MiliUI_MerchantAutomation.IsAutoRepair` 在不在（呼叫當下問）：在 ⇒ 本體修、資訊列不修，
  `ns.AutoRepair` 的 getter/setter 轉讀寫本體那份（setter 順手寫自己的 `db.repair` 當鏡像）；
  不在 ⇒ 資訊列用自己的 `db.repair` 修。「修裝」分頁的兩列改走 spec get/set（不能用 key 直讀 db）。
- 同步印記 `db.repair.coreSync`＝上次登入本體在不在：本體在＋nil ⇒ 資訊列值**推給本體**（9/23 升級的遷移
  也走這條）；本體在＋true ⇒ 本體值**抄回資訊列**；本體不在 ⇒ 清掉。排在 MigrateFromMiliUI 之後。
  `ns.ResetDB` 要保留 coreSync，不然還原的預設會在下次登入推回本體。
- Leatrix 撞車提醒：本體在時只由本體印。

## 自動修裝搬進資訊列／戰隊改滑過／寶庫欄切換（2026-09-19）

- **自動修裝從本體搬到 `Core/AutoRepair.lua`**（`ns.AutoRepair`）。設定 `db.repair.auto`（預設開）／
  `db.repair.guild`（預設關）；入口兩處：耐久面板**最上面**兩列勾選（按下原地重畫）＋「修裝」設定分頁最上面一節
  （方塊被收掉時的唯一入口）。耐久方塊右鍵從 W.Menu 選單改成直接開「修裝」分頁。
  事件永遠註冊、不看方塊啟用與否。`ns.Events` 的 MERCHANT_SHOW 延一幀派送，對 Shift 閘與修裝都沒影響。
  本體 `Enhance/Merchant_Automation.lua` 只剩自動賣垃圾，Tab_QoL **不留指路文字**（使用者點名不要）。
- **遷移**：印記 `db.repair.migration`，PLAYER_LOGIN 唯讀 `MiliUI_DB.merchant`，只搬「跟預設不同」的布林
  （autoRepair==false、guildRepair==true）。本體的 GetDB **不再補這兩格預設、也不刪舊值**。
  `ns.ResetDB` 會 wipe 掉印記 ⇒ 還原後補 `migration = "reset"`，不然下次登入舊值又搬回來。
- **舊版本體保險**：`MiliUI_MerchantAutomation.IsAutoRepair` 還在＝本體是舊版、自己會修 ⇒ 資訊列整組讓給它
  （不做雙向同步）。**本體不要為了相容補空殼 API 回來**，補了兩邊都不修。
- 加了 check 列之後整張修裝面板（含逐部位耐久）一起縮排 30px —— 那是列層 gutter 規則生效，不是跑版。
- **控制器新增三個 spec 選項**：`allowCombat`（戰鬥中照開、不自動收；戰隊表格）、`beforeOpen`（Build 之後
  Populate 之前跑一次；戰隊在這裡 RefreshOwn —— 放 populate 會跟 listener 繞成一圈）、`keepOpen`（回 true
  就**續排**下一輪關閉而不是只跳過：列選單開著時游標在面板外，選單關掉後不會再有 OnLeave 來叫我們）。
- **表格上每個吃滑鼠的子框都要接 CancelClose／ScheduleClose**（列、寶庫欄、全部發送、寶庫表頭鈕），
  見 [[wow-child-frame-steals-mouse-focus]]；寫在原本的 SetScript 裡，不要 HookScript。
  方塊左鍵**只開不關**（習慣性點一下的人不該在 0.15 秒後把它點掉）；右鍵開選單前先 CancelOpen＋Hide
  （選單與面板同錨點會疊）。滑過就開之後方塊不再彈 GameTooltip。
- **寶庫欄表頭是 Button**，左鍵循環 total → raid → mplus → world，存 `db.warbandVaultMode`（預設 total；
  刻意不放 `db.warband`——那張是資料、ResetDB 會留）。標題：總計＝「寶庫」，其餘 `WARBAND_COL_VAULT_FMT`
  拼「寶庫(M+)」。**欄寬在建框時用四種標題的最大值定死**（欄的 x 是建框時算的）。
  總計＝整欄一個 `已解鎖/總格數`（分母是有資料的軌道格數加總，不寫死 9；world／pvp 擇一），
  顏色三階（使用者定案）：**0～1 橘紅、2 黃、≥3 綠**——三格可以換骰裝幣，3 才是玩家在看的線；沒資料仍是灰點。滑過的寶庫提示四種模式都一樣。

待驗證（沒進過遊戲）：遷移後兩個開關的值、面板勾選原地重畫、keepOpen 續排（列選單關掉後面板有沒有收）、
戰鬥中滑過方塊長出表格會不會太擋、enUS 下寶庫欄變寬的量、修裝分頁多一節之後清單的捲軸範圍。

**戰鬥中會第一次建框的面板，不能呼叫 `SetPropagateMouseClicks`／`SetPropagateMouseMotion`。**
這兩支戰鬥中對插件是保護函式（跟框是不是保護框無關）。戰隊表格是 `allowCombat`、列又是
第一次開面板才建，結果戰鬥中第一次滑開就**每列**噴一次「介面功能因插件而失效」
（taint.log：`blocked in combat because of taint from MiliUI_InfoBar - Frame:SetPropagateMouseClicks()`，
2026-09-21）。玩家的體感是「點了資訊列的圖示就跳錯」，跟點的那顆圖示無關。
治本＝不需要 propagate：子框 `SetMouseClickEnabled(false)`＋`SetMouseMotionEnabled(true)`
只吃移動，點擊本來就會落到底下的列。


## 外部方塊接口 MiliUI_InfoBarPlugins（2026-09-22）

`Core/Plugins.lua`。之前**沒有**第三方接口（BLOCK_DEFS 寫死），為了傳奇鑰石的「M+結算」鈕才開。
形狀照 `MiliUI_MenuEntries`：註冊方在自己的入口檔**檔案層**往全域表塞
`{ key, text, label?, desc?, order?, enabled?, OnClick(tile, button)?, OnTooltip(tooltip)? }`，
沒裝那支插件＝沒人塞＝沒有方塊（「有安裝才顯示」自然成立，不用 IsAddOnLoaded）。

- `ns.Plugins.Sync()` 在 **ApplyAll 開頭每次都跑**：新 key 接到 BLOCK_DEFS 尾巴＋`ns.Blocks[key]` 工廠；
  存檔缺格補預設。⚠ 補存檔那段不能只在第一次見到 key 時跑 —— `ns.ResetDB` 會把 db.blocks 整張清掉。
- 存檔 key 一律 `ext_<key>`，跟內建不撞名；插件停用後那格留著不讀，重新啟用順序與開關都還在。
- 隨選載入的註冊方：ADDON_LOADED（`IsLoggedIn()` 之後）再 Sync，有新的才 ApplyAll。
- 看板（Tab_Blocks）的名字／說明走 `ns.Plugins.Label/Desc`，**不能**照內建規則查 `L["BLOCK_EXT_…"]`
  （AceLocale 缺鍵警告）；說明尾巴自動加「由其他插件提供」。
- **刻意只給普通按鈕**：第三方 Lua 掛在 secure 方塊上就是 CreateTile 那段的污染問題，資訊列沒辦法替別人把關。
  文字是靜態的（沒有 refresh API，現在沒有使用者）。
- `.claude/scripts/check_lua.py` 的 ALLOWED_GLOBAL_WRITES 已放行 `MiliUI_InfoBarPlugins`。


## 團本提示（2026-09-24）

滑過戰隊表格某一列 → 面板旁開「團隊副本進度」（`WarbandPopup.lua` 的 ShowRaidTip，一層：每組「副本 …… 難度 x/y」底下兩欄攤首領）。
資料 `rec.raids = { timestamp, list }`，來源 GetSavedInstanceInfo／GetSavedInstanceEncounterInfo，只收團本＋鎖定中。團搜另走 GetRFDungeonInfo（第 20 值副本名、23 值 mapID）＋GetLFGDungeonEncounterInfo，按副本併組、首領去重取 OR、只收本週有擊殺的；等 LFG_LOCK_INFO_RECEIVED 才存（lfrInfoReady），兩份來源沒準備好的那份沿用上次。
- **登出不存團本**：PLAYER_LOGOUT 當下副本名還在、首領快取已清，存了全變 0/0（實機踩過：術士線上正確、換角色後被蓋掉）。
- 讀到「有鎖定、沒首領」沿用同一鎖定（同名同難度、reset 未到）上次的首領清單；首領數回 0 時逐一問到沒回應。
- 只在 UPDATE_INSTANCE_INFO 之後存（raidInfoReady），冷快取 GetNumSavedInstances 回 0。
