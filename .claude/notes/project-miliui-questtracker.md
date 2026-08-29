---
name: project-miliui-questtracker
description: 米利的任務追蹤器 MiliUI_QuestTracker —— 掛勾暴雪 ObjectiveTracker 的獨立插件；六條 taint 規矩、摺疊機制走 IsProtected 分流、Leatrix 衝突偵測、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 115994b3-d41f-4e67-b636-6c325885e05b
  modified: 2026-08-29T07:28:27.382Z
---

2026-08-29 開的獨立插件（`AddOns/MiliUI_QuestTracker/`），骨架照
[[project-miliui-auraenhance]]：MiliUIWidgets vendor 一份、`Core/Init+Media+DB`、
自製設定視窗、`/mquest`。NAMESPACE = `MiliUIQuest`（第十一份 copy）。

**核心決定：不自己畫追蹤器。** 暴雪的 `ObjectiveTrackerFrame` 仍然是唯一的渲染引擎，
我們只換外觀、加自己的框、決定什麼時候收起來。理由是追蹤器有一半的內容是從暴雪的
**共用 widget pool** 借出來畫的（場景、UI widget），而那個池子同時服務工具提示與
地圖圖釘 —— 自己重畫等於要複製那整套資料流。

## 六條規矩集中在 `Core/Tracker.lua`

**所有碰得到追蹤器的動作只能從那支出去**，別的模組不准自己摸 `ObjectiveTrackerFrame`。
每一條背後都是「不會當場報錯、但會在別的地方炸」的失敗，散在各模組裡遲早被繞過去：

1. **不要呼叫 `ObjectiveTrackerFrame:Update()`**，任何形式都不行。`C_Timer` 延後**沒有用**
   —— taint 記的是「誰的執行環境」不是「誰呼叫的」。代價（改字級後行高暫時錯位）要接受。
2. 自己的旗標不准寫在暴雪的 frame／table 上（它會 `pairs()` 走 `usedBlocks` 決定哪些
   區塊還在用）。走 `T.Flags()` 弱鍵表。
3. **`ScenarioObjectiveTracker` / `UIWidgetObjectiveTracker` 的子區塊連 `GetBottom()` 都不能叫。**
   它們的 Header 安全（不從池子來），可以照樣美化。`T.EachBlock` 把這道閘擋在裡面。
4. 藏貼圖只准 `SetTexture("")`；`SetTexture(nil)` 與 `SetAlpha(0)` 都會沾到暴雪的貼圖。
5. `block.poiButton` 不准 `Hide()` 也不准掛它的 `Show()` —— 那顆的 OnShow/OnHide 會動
   `EventRegistry` 上 `"Supertracking.OnChanged"` 的共用訂閱表。要藏走 alpha ＋ `EnableMouse(false)`。
   ⚠ 池化的按鈕拿回來時 alpha 不會被重設，但出場動畫結尾會把 alpha 拉回 1，所以要排一次補刀。
6. **不要做「覆蓋層轉發點擊」。** 點整條標題收合走原生按鈕的 `SetHitRectInsets`，
   讓玩家的滑鼠直接落在暴雪自己的 OnClick 上。

## 摺疊機制：用 `IsProtected()` 分流，不要猜

**`ObjectiveTrackerFrame` 在編輯模式被錨到快捷列時才會變成受保護框**，那時候戰鬥中的
`Show`／`Hide`／`SetParent` 全部靜默被封鎖；沒被錨的時候戰鬥中照樣動得了。所以走哪條路是
**問出來的**（`otf:IsProtected()`），不是「戰鬥中一律 alpha」：

- 動得了 parent → `SetParent(hiddenParent)`。子框連滑鼠都收不到，最乾淨。
- 動不了 → `SetAlpha(0)` ＋ **自己蓋一塊擋滑鼠的板子**。alpha 0 的框滑鼠還在，
  滑過去照樣跳工具提示、照樣點得到；而 `EnableMouse(false)` 只作用在最上層，
  子區塊不會跟著關（要關就得遞迴，那是規矩 2/3 禁的）。
- `PLAYER_REGEN_ENABLED` 再收斂回 parent 路線。
- ⚠ **已經 parent 藏起來之後，戰鬥中就是展不開**（父層是隱藏的，alpha 救不回來）。
  這是客觀限制，設定頁有寫出來，不要疊補救措施。

`hiddenParent` 要 `SetAllPoints(UIParent)`：追蹤器的錨點如果是相對「父層」而不是具名
UIParent，換父層會連位置一起跑掉，我們錨在它身上的標題列與背景會跟著飛。

**暴雪原生的收合（`Header:SetCollapsed`）不能拿來做自動摺疊** —— 那要跑它整串收合程式碼。
所以「自動縮起」是我們自己藏，配一條自畫的標題列當把手（`Modules/Chrome.lua`）。

## ⚠ 不要盲掃 FontString 重設字型

**症狀：進度條的百分比顯示成 `□%`。** 那個方塊是秘密值的佔位控制字元（`\001N`）
原樣被畫出來 —— 進度條的數字是引擎在算繪時才回填的，我們對那個 FontString
呼叫 `SetFont` 就把回填弄掉了，剩下控制字元自己顯示成方塊
（同一個症狀 [[wow-unitclass-npc-returns-name]] 記過）。

肇因是「走訪子框、把掃到的每個 FontString 都重設字型」這種寫法。**通則：只動
具名認得的那幾個**（區塊標題、`block.lines` 的 `Text`／`Dash`、`itemButton.Count`），
其餘一律當作可能帶秘密值。代價是進度條與計時條的數字保留暴雪原本的字型 ——
那本來就是它們該有的樣子。（2026-08-29 拿掉三處盲掃：`ProcessChildren`、
`SkinHeader` 的 region 掃描、`SkinBlock` 的 region 掃描。）

## 外觀：底色跟傷害統計共用，但份量不一樣

底色 `0x1A`（0.102）跟 `MiliUI_DamageMeters` 的視窗底同一組（那邊的常數叫
`DARK_BG`）。要改配色就兩支一起改，不然兩個視窗擺在一起看得出色差。

**但「標題列實心、內容半透」那套不能照抄。** 試過之後使用者的回饋是「標題好重」：
傷害統計的標題列是**視窗的一部分**，這裡的標題列是**浮在地形上的一條**，份量不能一樣。
現在標題列的底跟清單同一階，關掉背景時它也沒有底、只留 1px 線。
滑過給一個不透明度下限（0.45）再往白色插值提亮 —— 插值不是加常數，
非灰階底色才不會偏色相。

**背景預設關**（使用者要求）。

## 右鍵選單與搬家遮罩

`Modules/Menu.lua` 只有內容，引擎在共用層。**`Menu.Show` 不要傳 anchor** ——
傳了會把選單掛在標題列右下角，而標題列跟追蹤器一樣寬，在左邊按右鍵選單卻從
最右邊掉出來。不傳就是貼著游標開（聊天列與資訊列也是這樣）。

**搬家遮罩＝左鍵拖、右鍵放手**（`Modules/Position.lua`）。跟資訊列／小地圖同一套視覺，
但底下的事情完全不同：那兩支拖的是自己的框，這裡拖的是**暴雪的編輯模式系統**。

⚠ **這是這支插件唯一一處故意跟暴雪搶的地方，而且是使用者指定的**（2026-08-29；
我先提過「走編輯模式比較乾淨」，他明確要獨立拖曳，「編輯模式歸編輯模式」）。
代價要記著：編輯模式會在**套用版面／進出編輯模式／重載**時把追蹤器貼回它記的座標，
所以 `Position.lua` 是盯著那幾個事件**再貼一次**——持續的拉鋸，不是一次性設定。
降低拉鋸的三個設計：
  * 沒拖過就完全不介入（`position.set` 是 false ⇒ 那支等於不存在）
  * 編輯模式開著的時候不貼，玩家還是能用原生拖曳
  * 右鍵遮罩＝放手，把位置整個交還給編輯模式（要能還，就得在**第一次覆蓋之前**
    把暴雪原本的錨點抄進記憶體 —— `ClearAllPoints` 之後那組就沒了）

座標存 **TOPLEFT 相對 UIParent TOPLEFT**（y 為負），不是編輯模式技能推薦的 CENTER 位移：
追蹤器的內容往下長，用 CENTER 的話任務一多整條就自己往上飄。
事件觸發後**貼兩次**（0.1s ＋ 0.6s）：編輯模式套用版面的時機不保證在我們之前。

⚠ 遮罩會吃滑鼠，所以編輯模式一開就要讓開，否則玩家在編輯模式裡拖不動追蹤器。
判斷編輯模式開沒開走**輪詢**（只在設定視窗開著時跑）：掛 `HookScript` 會把我們塞進
`EditModeManagerFrame` 的執行路徑，`EventRegistry` 回呼要寫共用訂閱表，兩樣都是規矩 5 在擋的。

`Modules/Menu.lua` **刻意不放**三樣東西，理由寫在檔頭：
「顯示標題列」是自殺選項（關掉就沒東西可以右鍵）、「在編輯模式中移動」等於在
管著追蹤器保護狀態的系統上開污染入口、自動摺疊的七個條件在共用層的子選單裡
沒辦法原地重畫（多選型勾選按下去會整個關掉）。

## 跟別的插件的關係

- **Leatrix Plus**：`LeaPlusLC` 是檔案內 local，**遙控不了也同步不了**。只能讀
  `_G.LeaPlusDB`（他的 SavedVariable，是登入當下的值），偵測到就在設定頁與聊天視窗警告。
  文案要講清楚「這是登入時的狀態，改完要 /reload 才會重判」，不然看起來像壞掉。
  使用者的 Leatrix 自動任務目前是**全開**的。
- **WarpDeplete** 在 M+ 已經把追蹤器 alpha 0（那個 alpha 隱藏就是我們幫它改的）。
  我們的 `visibility.mythicPlus` 預設關，設定頁偵測到它就標注是誰的地盤。
- 我們的自動交任務比 Elles 完整：他缺 `QUEST_PROGRESS → CompleteQuest()`（中間的「繼續」
  要手點）、`QUEST_GREETING`、`QUEST_ACCEPT_CONFIRM`。**但 `QUEST_AUTOCOMPLETE → ShowQuestComplete()`
  要跟他一樣刻意不做** —— 那會跑暴雪的完成面板流程（`ShowUIPanel` ＋ 往世界地圖寫
  UIPanel 屬性），之後每次開地圖都讀到，戰鬥中地圖圖釘就開始被封鎖。
- 不用 `UnitGUID` 記 NPC（12.1 之後可能是秘密值，當 table key 直接炸）。
  「同一個 NPC 有多個任務就別亂挑」用「可接任務不只一個就不挑」表達即可。

## ⚠ EllesmereUI 的授權

`tmp/EllesmereUI-v9.0.7/EllesmereUI/license.txt` 是 **All rights reserved**，沒有任何複製授權。
**程式碼一行都不能貼，連註解都不行。** 可以學的是事實（哪個 API 會污染、事件流程、
`Crosshair_*` 這種暴雪資產名），那些不受著作權保護。他的 M+ 計時器也拿不走 ——
`## Dependencies: EllesmereUI`，而本體是 22MB 的半套 UI。

## 待驗證（還沒進遊戲看過）

- ~~標題列的垂直位置~~ —— 已驗證，「藏掉『所有目標』之後版面高度還是保留著」成立，
  22px 的標題列擺進那個洞不會蓋到第一個任務。
- `PAD_LEFT` / `PAD_RIGHT`（現在 -4 / +4）—— 追蹤器的區塊本來就從框緣往內縮，要看實際的縮排調。
- 任務類型圖示擺 TOPRIGHT ＋ 壓掉 POI 按鈕：要確認 12.1.5 的 POI 按鈕真的在那個位置。
- 背景高度的跨縮放算式（編輯模式可以單獨縮放追蹤器，所以座標一律換成螢幕像素再比較）。
- ~~`ui-questtrackerbutton-secondary-collapse/expand`~~ —— 已驗證存在。
- `□%` 的修法（拿掉三處盲掃）還沒回報驗證過。
- 位置接管跟編輯模式的拉鋸：兩次 defer 夠不夠、右鍵放手還得回不回得去，都還沒實測。
- 追蹤器**沒有捲動**：可見高度是編輯模式的「高度」設定，超出就截掉。
  Elles 也沒做（整包沒有任何 scroll/mousewheel）。要自己加就得每幀搬
  暴雪的 ContentsFrame 跟它的排版對打 —— 不做。

相關：[[project-miliui-widgets-vendor]]、[[project-miliui-hide-blizzard-taint]]、
[[wow-121-secret-values]]、[[project-local-addon-forks]]、[[feedback-ui-visual-style]]
