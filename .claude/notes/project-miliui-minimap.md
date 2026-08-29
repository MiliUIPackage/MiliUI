---
name: project-miliui-minimap
description: MiliUI_Minimap 方形小地圖＋公會/好友資訊列——架構決定、接管暴雪小地圖的規則、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 580e7fa6-2fb6-4fbd-8d8b-3858879778a6
  modified: 2026-08-29T07:00:19.442Z
---

**2026-08-29 新建的獨立插件**（第十一支自製插件、MiliUIWidgets 的第十一個消費者，
NAMESPACE `MiliUIMap`）。兩件事：方形小地圖套 HUD 皮、地圖下方一條
「左公會在線／右好友在線」的資訊列。設計語言見 [[project-miliui-hud-skin]]。

參考來源：`tmp/EllesmereUI-v9.0.7/EllesmereUIMinimap`（接管小地圖的手法）、
`tmp/Elv/ElvUI/Game/Shared/Modules/DataTexts/{Guild,Friends}.lua`（資訊列的資料面）。
**兩邊都只抄結論不抄結構** —— Ellesmere 那支是 5489 行的單檔。

## 接管暴雪小地圖的規則（Ellesmere 註解裡記著它踩過的，照抄）

1. **`MinimapCluster` 只做 `SetAlpha(0)` ＋ `EnableMouse(false)`。**
   不 `Hide()`、不 `SetPoint()`、不 `SetSize()` —— 它是編輯模式管的系統框，
   碰那三樣會在登入跑版面時中獎（見 [[project-miliui-hide-blizzard-taint]]）。
2. **接管動作全部延後一幀**（`C_Timer.After(0)`）。同步做會在 ShowUIPanel／開世界地圖
   的流程中途動到 secure frame 環境，症狀是**稍後地城圖釘的資料提供者**呼叫受保護的
   `SetPropagateMouseClicks` 時噴 ADDON_ACTION_BLOCKED —— 錯誤指向地圖圖釘，
   完全看不出跟小地圖有關。
3. **Minimap 會被搶走**（住宅轉場等），`hooksecurefunc(Minimap, "SetParent", …)` 要
   搶回來，但**只能排程**、不能在 hook 裡同步做。
4. alpha 是**相乘**的 ⇒ cluster 一歸零，它底下的追蹤／郵件／日曆全部看不見。
   要留的按鈕必須 **reparent 出來**。

## 這支的三個自己的決定

- **多一層 `holder`**（普通 frame 掛 UIParent），Minimap reparent 進去。位置與尺寸的
  唯一權威在 holder 上。Ellesmere 是「Minimap 直接掛 UIParent ＋ 另建 layoutFrame」，
  同一個問題的另一種解法；holder 的好處是被搶走時只要把 Minimap 錨回來，不必重算位置。
- **暴雪的功能按鈕重新錨位，不重畫一套。** Ellesmere 自己畫了一整組 atlas 按鈕再把
  暴雪的藏起來 —— 造型能完全統一，代價是每顆按鈕的點擊行為（追蹤選單、日曆開關…）
  都要自己重接，暴雪改一次就要跟一次。我們要的只是「不要散在圓形外圍」，
  搬位置就夠了＝零 taint、零維護。
- **插件按鈕自己收**（2026-08-29 第二輪加的，同時把 **MBB 從套組移除**）。
  原本的判斷是「MBB 已經在做，別搶」，但兩個插件各管一半的結果是地圖旁邊
  永遠有兩套視覺語言。詳見下面「插件按鈕收納」。

## 12.x 的實際框架結構（Blizzard_Minimap/Mainline/Minimap.xml 查過）

```
Minimap
  ├ ZoomHitArea / ZoomIn / ZoomOut
  └ MinimapBackdrop                          ← 圓環畫在這裡面
       ├ MinimapCompassTexture               （四箭頭羅盤環）
       ├ StaticOverlayTexture                （金邊）
       └ ExpansionLandingPageMinimapButton   ← ⚠ 功能按鈕，不是裝飾
MinimapCluster
  ├ BorderTop / ZoneTextButton / Tracking / IndicatorFrame
  ├ MinimapContainer                         ← Minimap 實際掛在這裡
  └ InstanceDifficulty
```

⚠⚠ **不要整個 `MinimapBackdrop` alpha 歸零。** 資料片戰役／龍騎那顆
`ExpansionLandingPageMinimapButton` 是它的小孩，alpha 相乘 ⇒ 連功能按鈕一起弄不見，
而且是靜默的：玩家只會發現「戰役按鈕不見了」，完全不會聯想到小地圖美化。
要關的只有 `MinimapCompassTexture` 與 `MinimapBackdrop.StaticOverlayTexture` 兩張貼圖。

`MinimapBorder` / `MinimapBorderTop` / `MinimapNorthTag` 是**舊版全域名**，12.x 多半
已經不存在 —— 照著別人的清單抄會抄到一堆 nil（無害，但別以為那就是在關圓環）。

## 方形小地圖的兩個必知

- `Minimap:SetMaskTexture(130937)` = 方形，`186178` = 圓形。
  另外要把 `SetArchBlobRingScalar(0)` / `SetQuestBlobRingScalar(0)` 關掉，
  不然那圈圓形的任務／考古範圍環會突出到角落外面。
- ⚠ **Minimap 自己的滑鼠判定區永遠是圓的，跟遮罩無關。** 兩個後果：
  ① 方形的四個角落是「滾輪死角」，滾上去會去縮放攝影機；
  ② 從角落進入地圖時 OnEnter 不觸發，mouseover 的元素長不出來。
  解法是蓋一層覆蓋整個方形的 blocker frame，`SetPassThroughButtons` 放行左右鍵、
  `SetPropagateMouseMotion(true)` 讓動作照常傳下去，自己只吃滾輪與 enter/leave。

## 插件按鈕收納（取代 MBB）

兩個容器，每顆按鈕擇一：

| 容器 | 什麼時候看得到 | 給誰 |
|---|---|---|
| 收納袋 `bag` | 按九宮格鈕才展開 | 絕大多數 |
| 常駐排 `pin` | 永遠 | 玩家自己釘的那幾顆 |

**「單獨留在地圖上」是必要功能，不是裝飾**（使用者指出的）：有些按鈕**本身就是讀數**
—— 收件匣有沒有信、大秘境計時、拍賣掃描進度。把那種東西收進「要點一下才看得到」
的袋子，等於把那顆按鈕廢掉。

- 釘選狀態存 `db.pinned[frameName] = true`。⚠ **鍵一定是 frame 的名字**，
  不能是排序後的索引 —— 索引會隨「今天載了哪些插件」變動，存索引等於每次登入
  釘到不同的按鈕。
- 常駐排**預設貼下方**：收納袋鈕搬進資訊列之後，整組由上而下就是
  「地圖 → 資訊列 → 常駐排」一條軸線；選 top 會讓它跑到地圖上面、跟其他東西斷開。
  （bottom 會自動避開資訊列，接在它下緣。）
- 常駐排**單排不折行**是刻意的：它永遠佔畫面，讓它長兩行等於默許把二十顆都釘出來，
  那就回到我們要解決的問題本身。釘太多會超出地圖邊界，那個難看正是訊號。
- 釘選 UI 在設定頁而不是右鍵選單：清單長度＝裝了幾個帶小地圖按鈕的插件，
  二三十列是常態，而選單超過一螢幕就沒人點得動。

**架構選擇：永久 reparent，不做「借過去再還」。**
Ellesmere 是「按鈕留在小地圖上、alpha 歸零、開面板時再借」，代價是要跟 LibDBIcon
搶 Show/Hide（掛勾＋記錄插件本來想不想顯示＋面板開著時凍結那份紀錄，三段狀態機，
每段都有例外）。我們搬進自己的容器就不還了 —— 一旦不是 Minimap 的子框，插件再怎麼
Show 都只是「在我們的容器裡顯示」。而「留在地圖上」也不必走回頭路，換個容器而已。
代價：沒有還原路徑，關掉功能要 /reload 才會把按鈕還給小地圖。

踩到／想清楚的：
- **收下的當場就要 `SetParent` 進容器**，不能等 Layout。Layout 只排「顯示中」的，
  插件自己關掉的按鈕會留在 Minimap 底下而且**已經被 ClearAllPoints**，
  一旦被 Show 回來就出現在畫面原點。
- 圓框裝飾用**貼圖本體**認（fileID ＋ 路徑兩種都比），不要認欄位名 ——
  各家把那張圖放在 `.border` / `.Border` / 匿名 region 都有。
- 常駐排貼「下方」會**撞到資訊列**（兩者都錨 holder 的 BOTTOMLEFT）。有資訊列時
  改接在它下面。
- `hooksecurefunc(btn, "Show"/"Hide")` 只用來**排程重排**，不做別的 —— 插件關掉
  自己的圖示時格子要收合，但 Show/Hide 在戰鬥中也會被呼叫、一次設定變更可能連打十幾發。

⚠ **收納袋的提示與收納袋面板從同一個錨點往下長 ⇒ 完全重疊。** 提示在 `TOOLTIP`
strata、面板在 `HIGH`，提示永遠壓在上面，使用者回報的症狀是「圖示好像被上了一個
遮罩」。修法：袋子開著時那一格不彈提示（`SOURCES.bag.suppress`），開袋子當下也
主動 `Tip.Close()`。通則寫進 [[project-miliui-hud-skin]]。

⚠ **收納袋面板要用提示皮（不透明），不是 HUD 面板皮（半透明 0.8）。**
它是「彈出來給人看內容」的表面，判準跟滑過去的名單同一條。半透明的實測後果：
小地圖的地形從面板底下透上來，斜斜一道亮痕橫過整排圖示，看起來像每顆圖示都被
蓋了一層紗 —— 使用者連續回報兩次「還是有遮罩感覺」，兩次的成因都不是圖示本身。

⚠⚠ **真正的元兇（`/framestack` 查到）：`SetParent()` 不會把 strata 帶過去。**
LibDBIcon 把每顆按鈕明確釘在 `MEDIUM`，搬進 `HIGH` 的收納袋之後按鈕還在 MEDIUM，
於是**面板自己的底色貼圖**整片畫在圖示上面 —— 那層「遮罩」就是我們的面板底。
同一個袋子裡沒被蓋到的，剛好是自己就設 HIGH 的按鈕（`MiliUIUF_MinimapButton`）。
修法見 [[wow-frame-vs-texture-layering]]（那份筆記原本的規則也因此修正了）。

⚠ **`GetNormalTexture()` 不能無條件當成圖示。** 有一類按鈕的 normal texture 就是
那圈暴雪圓框本身、圖示是另一張子貼圖；把圓框拉滿整格再裁 8%，就是一張灰環蓋在
整顆按鈕上（而且我們還把它提到 OVERLAY）。退回它之前要先 `IsJunk` 過一次。
「像被上了遮罩」總共查到**四個**不同的成因（提示框重疊、面板半透明、圖示壓在
ARTWORK、圓框被當成圖示），最後才發現主因是 strata。**別在第一個找到的原因就收手，
而且症狀重複出現三次以上就該直接開 `/framestack`，不要再用推理的。**

⚠ 收下來的按鈕圖示要 `SetDrawLayer("OVERLAY")` 往**上**提，不要壓到 ARTWORK：
我們只拆得掉認得出來的暴雪圓框，自帶造型的插件會留一張我們不認識的裝飾貼圖在
ARTWORK，把圖示壓下去等於讓那張貼圖蓋在圖示上面 —— 同樣是「像被上了遮罩」。

## ⚠⚠ 記憶體：四輪才抓到的 855 KB／次（2026-08-30）

**結論先講：`BNGetNumFriends()` 只取第一個回傳值，導致每次數人數都把整份
（含離線）好友名單配置一遍，單次 855 KB。**

追查過程值得留著，因為前三輪的推理**每一輪都是對的、也都真的修掉了東西，
但都不是主因** —— 那正是「用讀程式碼找配置點」的失敗模式。
最後是靠 `/mmap prof`（Core/Profile.lua）的取樣曲線定案：

```
每 5 秒累計 KB：0 → 883 → 1735 → 1736 → 2588 → 3440 → 4292 → 5143 → …
```

**階梯狀、每階 ~852 KB**，而且階數對得上 `FriendsOnline!walk` 的次數
（三輪各 6／6／10 次，總量 5146／5146／8555 KB，除下來都是 855）。
曲線是決定性的證據 —— 線性爬升代表「持續配置」，階梯代表「單次很貴」。



使用者回報這支 **26 分鐘吃掉 96 MB、佔全部插件記憶體 31%**。根因是一條每幀觸發的鏈：

```
被收納的插件 btn:Show()      ← LibDBIcon 系每個事件甚至每幀都叫一次
  → 我們的 Show 掛勾
  → QueueLayout → Buttons.Layout
  → Fire("BagCountChanged") → Bar.Update → 三格 UpdateSlot
  → D.FriendsOnline()
```

`C_BattleNet.GetFriendAccountInfo(i)` **每次呼叫都配一張新表**，裡面還巢著一張
`gameAccountInfo`。40 個戰網好友 ＝ 每幀 80 張表的垃圾。

**教訓一：把「別人會怎麼呼叫我的掛勾」當成每幀。** `hooksecurefunc(btn, "Show")`
看起來是事件驅動，實際上取決於**別人**的呼叫頻率 —— 而 `Show()` 對已顯示的框
是常見的無害重複呼叫，沒人會覺得那需要節制。掛勾裡一定要先問「狀態真的變了嗎」。

**教訓二：鏈上每一環都要補守衛，不要只堵最貴的那個。** 各自獨立：
- Show/Hide 掛勾：`_miliShown` 沒變就不排程
- `Buttons.Layout`：顆數沒變就不廣播
- 事件合流：連發事件只排一次 `Bar.Update`（慢 5 秒／快 0.5 秒）
- `D.FriendsOnline`：2 秒 TTL 當地板（人數是**讀數**不是狀態機，差幾秒無影響）
- 提示重畫：秒級節流（重建 30 列要走一遍 761 人的名冊）
- `UpdateSlot` / `UpdateClock`：內容沒變就不 `SetFormattedText`
  （時鐘只到分鐘，0.5 秒 ticker 一分鐘有 119 次在重寫同一串字）

**真兇（第四輪才抓到，用剖析器）：`BNGetNumFriends()` 回傳兩個值
`numTotal, numOnline`，而我只取了第一個** ⇒ 連**離線**好友也一筆一筆走過。
`C_BattleNet.GetFriendAccountInfo(i)` 每次都配一張巢狀表，所以「為了數出 13 個
在線的人，把整份幾百人的名單全配了一遍」。**單次 855 KB。**
戰網清單是**在線優先排序**的（暴雪的 `FriendsList_Update` 就靠這個前提），
走 `1..numOnline` 就夠。

**收在哪裡（2026-08-30 定案）：1300 → 110 → 21 → 4 → ~4 KB/秒，對照整個 Lua 堆
的 300+ KB/秒 已經進到雜訊裡。** 剩下的成本結構很單純：**每 60 秒一次 244 KB 的
好友掃描，其餘為零**（曲線是「一路平 → 一階 → 一路平」）。

244 KB 是這個語意的**地板**：`GetFriendAccountInfo` 每個在線好友回一張約 18 KB
的巢狀表。想再降只有兩條路，兩條都有代價：

| 做法 | 省下 | 代價 |
|---|---|---|
| 改用 `select(2, BNGetNumFriends())` 當數字 | 全部（零配置） | 數字變成「戰網在線」而不是「在玩 WoW」，跟提示清單的長度對不上 |
| 用 `BN_FRIEND_INFO_CHANGED` 的 friendIndex 只重查那一個人 | 理論上 13× | ⚠ **實際更糟**：那個事件一分鐘發幾十次，18 KB × 幾十次 > 244 KB × 1 次。要合流的話又回到全掃 |

**所以「每 N 秒全掃一次」就是這個語意下的最佳形狀，只剩 N 可以調。**
N 是**雜訊路徑的兜底週期，不是更新延遲** —— 真的有人上／下線走精準事件，那條即時。

**教訓三：先問「一次吃多少」，再問「被叫幾次」。** 前三輪全部在追頻率
（每幀掃 → 每秒掃 → 事件合流），每一輪都真的修掉了東西，但都不是主因 ——
因為那支的呼叫次數只有 **0.1/秒**，在報告上看起來完全無辜。
`成本 = 單次 × 次數`，而我連續三輪只看右邊那一項。

**教訓四：量測工具本身不能是配置點。** 兩次差點犯：`ns.Count("Fire:" .. event)`
的字串串接放在旗標外面、`ns.Meter(key, function() ... end)` 的 closure 每次呼叫
都會配置 —— 兩者都是「剖析關著也照樣配置」。旗標要包住**參數的求值**，
而不只是包住函式本體。

**教訓五：TTL 是地板，不是節流。** 第一輪只加了 1 秒 TTL，把「每幀掃一遍」壓成
「每秒掃一遍」—— 而 `BN_FRIEND_INFO_CHANGED` 是消防水管（好友換區、改狀態、改廣播
都發，三十個人在打副本時一秒好幾十發），只要事件不停就**永遠**每秒一次，一小時
還是好幾 MB。TTL 只擋得住「同一波事件裡的重複呼叫」；要壓下**持續**的事件流，
得讓事件本身合流（一連串只排一次更新），而且分急迫度：好友名單的雜訊給 5 秒，
真的上下線給 0.5 秒。

**教訓六：回傳 table 的 C API 是配置點。** `GetFriendAccountInfo`、
`C_Map.GetPlayerMapPosition`、`GetMouseFoci` 這類每次都給新物件，放進任何
「可能被高頻呼叫」的路徑之前先想清楚誰會叫它。
相關：[[wow-addon-profiler-cost]]。

## 尺寸

- 預設 172 **太小**（暴雪原本約 198），使用者第一時間就反映了。改 200 起跳。
- 左下角有拉把手（解鎖時才出現）。⚠ **不用 `StartSizing`**：那支會讓寬高各自跑，
  而 **Minimap 的地形投影與玩家箭頭要求畫布是正方形**。自己讀游標算邊長更短、
  而且保證正方。錨 TOPRIGHT ＋ 拉左下角＝右上角釘住不動，是唯一不會邊改邊漂的角落。
- **長方形做不到（不是偷懶）**：要裁成長方形得另外做一張**固定比例**的裁切遮罩貼圖
  （Ellesmere 就帶了一張 4:3 的 tga），而遮罩是被拉伸的 ⇒ 一張遮罩只能對應一個比例，
  「自由拖曳寬高」需要在遊戲裡即時生成貼圖，做不到。要整體變小用 scale。

## 資訊列：三格，可客製

```
┌──────────────┬────┬──────────────┐
│     公會 12  │ ▦  │    好友 4    │
└──────────────┴────┴──────────────┘
```

三格各自可選 **公會／好友／插件收納袋／無**。收納袋原本是地圖上方外側一顆孤鈕，
2026-08-29 收進資訊列 —— 版面理由：那樣地圖上下各長一條東西（上面一顆孤零零的鈕、
下面一條資訊列），收進來之後只剩下方一條，而那條本來就是「地圖旁邊一排小東西」
該待的地方。

**寬度規則：收納袋那格固定寬（正方形），其餘平分剩下的；選「無」的格子完全不佔位置。**
- 收納袋格裡只有一顆 3×3 圖示，給它三分之一條寬只會讓圖示孤零零飄在空白中間。
- 「無」不佔位置 ⇒「只留公會」是一條整寬的公會列，不是一格公會加兩格空白。
- 三格都選「無」就整條收起來，不要留一條空的深色橫槓。

⚠ **標籤與數字必須是同一個 FontString**（數字用 `|cff` 色碼上色），不能拆兩個。
兩個 FontString 各自置中會分別以自己的中心對齊，中間那道縫會隨數字位數變動而左右晃
—— 從 9 跳到 10 的時候整組字會抖一下。為此在 Style 加了 `S.AccentHex()`。

⚠ 三格都沒選收納袋的話袋子就沒有入口，逃生口是 `/mmap bag`。
**刻意不做「沒入口就自動長一顆鈕回來」** —— 同一顆鈕有兩個可能的位置，玩家更找不到。

## 資訊列的資料面

- **零背景工作**：人數走現成 API（`GetNumGuildMembers()` 的第二回傳、
  `C_FriendList.GetNumOnlineFriends()`），名單只在提示打開的那一刻才掃。
  反過來做（登入建表、每個事件維護增量）在 500 人公會是每次 GUILD_ROSTER_UPDATE
  掃五百筆，換來提示早 3ms 出現。
- ⚠ `GetNumGuildMembers()` 在**沒有請求過**的情況下可能是 0，要主動叫
  `C_GuildInfo.GuildRoster()`（伺服器端約 10 秒節流，叫太密它自己會忽略）。
- ⚠ **戰網好友的 `game.className` 是在地化顯示名**（中文客戶端拿到「聖騎士」），
  拿去查 `RAID_CLASS_COLORS` 永遠是 nil。要走 `game.classID` →
  `C_CreatureInfo.GetClassInfo(id).classFile`。
  `C_FriendList` 的角色好友**根本沒有 classFile**，拿不到就不上色 ——
  不要猜一個 token 去查表（[[wow-unitclassbase-npc-returns-rogue]]）。
- ⚠⚠ **「在玩 WoW」不等於「有角色名可用」。** 剛登入停在選角畫面、或還在讀取的
  戰網好友，`clientProgram` 已經是 `"WoW"` 了但 `characterName` 是**空字串**、
  `characterLevel` 是 **0**。照單全收的後果是名單與右鍵選單裡出現一排「0 」開頭的
  空白列，那幾筆既點不了密語也邀不到人（使用者擷圖回報）。
  **空字串不是 nil**，`charName or tag` 擋不住它（空字串是真值）；0 同理。
  另外 `wowProjectID ~= WOW_PROJECT_ID` 是跨版本好友（經典服／PTR），
  邀請對他們無效 —— 標出來、而且不進邀請清單，但密語照樣可以走戰網暱稱。
- 12.1：名字／區域／備註在受限內容中可能是秘密字串，每個欄位進 `Data.lua` 就先過
  `Secret.PlainText`；洗不出明文的整筆丟掉。密語／邀請的目標名字必須是明文
  （[[wow-121-chat-reply-secret-taint]]）。
- **提示框走不透明底，不跟 HUD 面板的半透明走。** HUD 面板要透是因為它常駐、擋住
  世界會礙事；提示框相反 —— 它是臨時跳出來讓人**讀字**的，而且多半蓋在任務追蹤框
  上面，0.8 的底會讓追蹤框的字整片透上來，三十行的公會名單當場變成兩層字疊在一起
  （使用者擷圖）。判準：**底色承載「讓字讀得出來」的就不能透。**
- 提示用**自己開的 GameTooltip**（`GameTooltipTemplate` ＋ NineSlice alpha 0 ＋
  自己的皮墊在底下，手法同 [[project-miliui-tooltip]] 的 Skin 引擎）。不借全域
  `GameTooltip`：外觀已被別的插件接管，而且長名單會把它的行數池撐大、之後每個
  物品提示都帶著那些行走（行回收不掉，見 [[wow-frame-lifecycle-costs]]）。

## 五個已修的坑（別再寫回去）

- `ns.Fire` 的派送順序是 `pairs()`。資訊列原本也註冊 `Init` 並在裡面 `Apply()`，
  Skin 的 Init 若晚跑，`ns.holder` 還是 nil ⇒「貼在地圖下緣」走不到、資訊列會用
  絕對座標貼出去。改成由 `Skin.Apply` 結尾的 `SkinApplied` 驅動，順序由呼叫鏈保證。
- 位置的 SetPoint 位移單位是**被錨的框自己的 effective scale**。holder 有自己的
  `SetScale`，存位置時要換算成螢幕像素再除回 holder 的 scale，否則縮放不是 1 的人
  每存一次就往角落漂一點（[[wow-setscale-offset-units]]）。

- **「開設定就自動解鎖」不能走會寫檔的那支。** 第一版的 `Skin.SetLocked(false)` 同時
  寫進 DB，於是設定視窗一 OnHide、讀回來的 `db.locked` 已經是 false ——
  鎖定狀態每開一次設定就被洗掉一次。拆成 `SetLocked`（寫檔）與 `RefreshDrag`
  （只算「現在該不該顯示遮罩」＝`ns._optionsOpen or not db.locked`）。
  **通則：暫時性的 UI 覆寫不要經過持久化的那條路。**
- **FontString 沒給字型就 `SetText` 是硬錯，而且會中斷整支 `Build()`。**
  拖曳遮罩的標籤踩到，症狀是**小地圖完全沒被接管**（`Apply()` 從來沒跑到），
  跟字型看起來毫無關係。現在模組裡不留裸的 `CreateFontString`，一律走
  `MakeText()`（建完馬上給字型）。完整說明：[[wow-fontstring-font-before-settext]]。
  ⚠ 同一批也發現資訊列的兩個 FontString「只是剛好安全」（靠 Apply 的字型迴圈排在
  Update 前面），一併改掉 —— 靠順序的安全不算安全。
- `GameTooltip:AddDoubleLine(l, r, rL,gL,bL, rR,gR,bR)` **不能直接接 `S.Accent()`** ——
  它回四個值（含 alpha），alpha 會被當成右欄的紅色分量，右欄變成半紅的字。
  `AddLine` 同理（第四個參數是 wrapText）。一律先解成三個變數。

## 待驗證（**遊戲裡沒跑過**，2026-08-29 只做到靜態檢查全過）

- [ ] 登入時接管有沒有成功、有沒有跳封鎖彈窗（`/mmap debug` 看）
- [ ] 追蹤／郵件／日曆／副本難度四顆 reparent 之後點得動嗎、位置對嗎
- [ ] `AddonCompartmentFrame` 搬到地圖上方會不會被暴雪搶回去（Ellesmere 說它會，
      而且掛了持續性的 hook 才守得住 —— 我們目前只在 Apply 時擺一次）
- [ ] 進出副本／住宅轉場之後 Minimap 有沒有被搶走
- [ ] 編輯模式開關一次，cluster 的 alpha 有沒有被還原（有掛
      `EDIT_MODE_LAYOUTS_UPDATED` 重跑，但沒實測）
- [ ] 資訊列的提示在 500 人公會會不會太長／太慢
- [ ] 跟 Mapster、Leatrix_Plus 的小地圖選項有沒有打架
- [ ] 插件按鈕收得乾不乾淨（有沒有漏收、有沒有誤收圖釘）
- [ ] 釘選勾起來之後按鈕有沒有真的跑到常駐排、/reload 之後還在不在
- [ ] LoadOnDemand 的插件（拍賣、背包）開過之後有沒有被補收進來
- [ ] 拉把手調尺寸：資訊列與常駐排有沒有跟著對齊
