---
name: project-miliui-infobar
description: MiliUI_InfoBar 資訊列——取代微型選單的自製條；secure 點擊轉發／暴雪列 hider／戰鬥紀律／待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: c0d1056b-afe5-4f0b-a0d1-24a0f3f4c05d
  modified: 2026-08-29T07:59:39.917Z
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
2. **藏暴雪那排只能走 secure hider**：MicroMenuContainer 是 Edit Mode 管理框，
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
- 區域變數不要叫 `MicroMenu`——暴雪 DF 起有全域框就叫這名字，遮蔽掉 hider 會拿錯目標。
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
- 編輯模式訊號走雙保險：EditModeManagerFrame 的 OnShow/OnHide 掛勾＋
  `EventRegistry` 的 `"EditMode.Enter"/"EditMode.Exit"`（官方在 EnterEditMode／
  ExitEditMode 內部發的，Blizzard_EditMode/Shared/EditModeManager.lua）。
  選取框**開檔就建**——進了編輯模式才在暴雪的 OnShow 路徑裡建框是沒驗證過的
  時序；建立包 pcall（DamageMeters 同款防禦），失敗就自畫藍框頂著。
- 設定視窗開著＝職業色「拖曳移動」遮罩蓋整條（照 MiliUI_Minimap 的慣例：
  開設定多半就是要搬家；右鍵回預設位置）。遮罩是保護框子層，Show/Hide 走
  ns.Defer。編輯模式的藍框跟這套遮罩是**兩套視覺**。
- CPU／記憶體方塊點擊直達 MiliUI 本體效能監控的對應子分頁：本體在
  `Api.lua` 出全域 `MiliUI.OpenPerf("cpu"/"ram")`（內部走 Tab_Perf 的
  `ns.OpenPerfPage`——先寫 `DB().page` 再開窗，讓 ShowOptionsTab 自己選頁）。
  資訊列在建立時檢查入口在不在，沒裝本體就退回純顯示不吃滑鼠。
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
