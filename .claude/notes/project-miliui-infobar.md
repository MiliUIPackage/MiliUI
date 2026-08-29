---
name: project-miliui-infobar
description: MiliUI_InfoBar 資訊列——取代微型選單的自製條；secure 點擊轉發／暴雪列 hider／戰鬥紀律／待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: c0d1056b-afe5-4f0b-a0d1-24a0f3f4c05d
  modified: 2026-08-29T15:13:50.147Z
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
  3. **⚠⚠ 換完 `relativeRegion` 再叫 `frame:AnchorAndRotate()` 實機上沒有用。**
     欄位確實變了（`/mib debug` 印得出來），泡泡卻留在原地——連 `autoHorizontalSlide`
     那個**每幀**都會 `AnchorAndRotate` 的 OnUpdate 也沒把它拉過來（推測是拋錯被
     BugSack 吞掉）。所以不能信任那條路：呼叫要包 `pcall`，然後**量泡泡的中心 x
     有沒有真的靠近方塊**，沒有就自己 `ClearAllPoints` + `SetPoint` 接手，並把
     `OnUpdate` 設成 nil（不然每幀重錨會跟我們搶）。
     **教訓：欄位對了不等於畫面對了。** 這一輪浪費了三次 /reload 才發現——診斷
     只印狀態欄位是不夠的，一定要連**實際座標**一起印（方塊的 x 對泡泡的 x），
     差距一眼就看得出來。
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
