---
name: project-miliui-minimap
description: MiliUI_Minimap 方形小地圖＋社交列＋插件按鈕收納（取代 MBB）——接管暴雪小地圖的四條規則、方形遮罩的滑鼠死角、按鈕收納的掃描隔離與拆遮罩、「像被上了遮罩」四個成因（主因 SetParent 不帶 strata）、好友人數的語意換掉成本歸零、名單走聊天超連結、登入不夾位置、待驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 580e7fa6-2fb6-4fbd-8d8b-3858879778a6
  modified: 2026-10-14T00:00:00.000Z
---

**2026-08-29 新建的獨立插件**（MiliUIWidgets 的消費者之一，NAMESPACE `MiliUIMap`，`/mmap`）。
檔案：`Map/{Skin,Buttons,Difficulty}.lua`、`Panel/{Bar,Data,Tip}.lua`＋`Panel/LinkSink.xml`、`Core/{DB,Init,Profile,Style}.lua`。
三件事：方形小地圖套 HUD 皮、地圖下方一條「左公會在線／右好友在線」的**社交列**、插件按鈕收納。
設計語言見 [[project-miliui-hud-skin]]。接管手法學自 EllesmereUIMinimap、社交列的資料面學自 ElvUI DataTexts（原始碼都已不在本機），
**只抄結論不抄結構**。

## 接管暴雪小地圖的規則

1. **`MinimapCluster` 只做 `SetAlpha(0)` ＋ `EnableMouse(false)`。** 不 `Hide()`、不 `SetPoint()`、不 `SetSize()` ——
   它是編輯模式管的系統框（[[project-miliui-hide-blizzard-taint]]）。
2. **接管動作全部延後一幀**（`C_Timer.After(0)`）。同步做會在 ShowUIPanel／開世界地圖的流程中途動到 secure frame 環境，
   症狀是**稍後地城圖釘的資料提供者**呼叫 `SetPropagateMouseClicks` 時噴 ADDON_ACTION_BLOCKED —— 錯誤指向地圖圖釘，看不出跟小地圖有關。
3. **Minimap 會被搶走**（住宅轉場等），`hooksecurefunc(Minimap, "SetParent", …)` 要搶回來，但**只能排程**。
4. alpha 是**相乘**的 ⇒ cluster 一歸零，它底下的追蹤／郵件／日曆全部看不見。要留的按鈕必須 **reparent 出來**。

**三個自己的決定**：多一層 `holder`（普通 frame 掛 UIParent，位置與尺寸的唯一權威，被搶走時只要把 Minimap 錨回來）；
暴雪的功能按鈕**重新錨位、不重畫一套**（零 taint、零維護）；插件按鈕自己收（同時把 **MBB 從套組移除**，兩個插件各管一半＝兩套視覺語言）。

### 12.x 的框架結構（Blizzard_Minimap/Mainline/Minimap.xml）

```
Minimap
  ├ ZoomHitArea / ZoomIn / ZoomOut
  └ MinimapBackdrop                          ← 圓環畫在這裡面
       ├ MinimapCompassTexture / StaticOverlayTexture
       └ ExpansionLandingPageMinimapButton   ← ⚠ 功能按鈕，不是裝飾
MinimapCluster
  ├ BorderTop / ZoneTextButton / Tracking / IndicatorFrame
  ├ MinimapContainer                         ← Minimap 實際掛在這裡
  └ InstanceDifficulty
```

⚠⚠ **不要整個 `MinimapBackdrop` alpha 歸零**：資料片戰役那顆 `ExpansionLandingPageMinimapButton` 是它的小孩，會靜默消失。
要關的只有 `MinimapCompassTexture` 與 `StaticOverlayTexture` 兩張貼圖。`MinimapBorder` / `MinimapBorderTop` / `MinimapNorthTag` 是舊版全域名，12.x 已不存在。

### 方形小地圖的兩個必知

- `Minimap:SetMaskTexture(130937)` = 方形，`186178` = 圓形；另關 `SetArchBlobRingScalar(0)` / `SetQuestBlobRingScalar(0)`。
- ⚠ **Minimap 自己的滑鼠判定區永遠是圓的，跟遮罩無關**：四個角落是滾輪死角（滾上去縮放攝影機）、從角落進入 OnEnter 不觸發。
  解法是蓋一層覆蓋整個方形的 blocker frame，`SetPassThroughButtons` 放行左右鍵、`SetPropagateMouseMotion(true)`，自己只吃滾輪與 enter/leave。

### 尺寸

預設 200（172 太小，暴雪原本約 198）。拉把手在左下角（解鎖時才出現）。⚠ **不用 `StartSizing`**：那支會讓寬高各自跑，
而 **Minimap 的地形投影與玩家箭頭要求畫布是正方形**；自己讀游標算邊長。錨 TOPRIGHT ＋ 拉左下角＝右上角釘住不動。
**長方形做不到**：裁切遮罩是被拉伸的，一張遮罩只對應一個比例。要整體變小用 scale。
位置的 SetPoint 位移單位是 holder 自己的 effective scale，存位置時換算成螢幕像素再除回（[[wow-setscale-offset-units]]）。
**登入時位置只檢查型別、不照螢幕尺寸夾**（2026-10-12 `7fbb8a9d1`）：PLAYER_LOGIN 當下 UIParent 縮放可能還不是最終值，
正常座標被誤判成畫面外、每次登入打回預設；飄出畫面交給 `SetClampedToScreen`＋右鍵叫回（[[wow-login-screen-size-not-final]]）。

## 插件按鈕收納（`Map/Buttons.lua`，取代 MBB）

兩個容器，每顆按鈕擇一：收納袋 `bag`（按九宮格鈕／滑過才展開）給絕大多數；常駐排 `pin` 給玩家自己釘的。
**「單獨留在地圖上」是必要功能**：有些按鈕本身就是讀數（收件匣、拍賣掃描進度），收進袋子等於廢掉。

- 釘選狀態存 `db.pinned[frameName] = true`。⚠ **鍵一定是 frame 的名字**，索引會隨「今天載了哪些插件」變動。
- 常駐排預設貼下方（地圖 → 社交列 → 常駐排一條軸線；有社交列時接在它下緣）、**單排不折行**（釘太多超出邊界，那個難看正是訊號）。
- 釘選 UI 在設定頁不在右鍵選單（清單二三十列是常態）。釘選欄的文案走 `ns.Buttons.PinLabel()`，依 `pinSide` 回「釘選按鈕到社交列下方／小地圖上方／左側／右側」
  ——**文案裡寫了方位，就得跟著那個方位的設定走**。

**架構：永久 reparent，不做「借過去再還」**。Ellesmere 是「按鈕留在小地圖上、alpha 歸零、開面板時再借」，要跟 LibDBIcon 搶 Show/Hide（三段狀態機）。
我們搬進自己的容器就不還了——一旦不是 Minimap 的子框，插件再怎麼 Show 都只是在我們的容器裡顯示。代價：關掉功能要 /reload。

踩到的：
- **收下的當場就要 `SetParent` 進容器**，不能等 Layout。插件自己關掉的按鈕已被 ClearAllPoints，一旦被 Show 回來就出現在畫面原點。
- 圓框裝飾用**貼圖本體**認（fileID ＋ 路徑兩種都比），不要認欄位名。
- `hooksecurefunc(btn, "Show"/"Hide")` 只用來**排程重排**，而且 `_miliShown` 沒變就不排——Show 對已顯示的框是常見的無害重複呼叫，LibDBIcon 系每個事件甚至每幀都叫。
- **掃描逐顆隔離**（2026-09-30 `39d273355`）：`Scan` 對每個子框 `xpcall(Collect, ns.ReportError, child)`。一顆拋錯＝整輪中斷（後面的沒收、不排版、拋錯那顆搬進來卻沒掛勾）。
  兩個順序是契約：① `Collect` 裡 **登記 → 搬進容器 → 掛勾 → 整形**，會拋的整形擺最後；② `Normalize` 裡 **`StripMask` → `SetTexCoord` 是最後兩行**。
  「這輪有沒有收到新的」看 `#collected` 有沒有變長。錯誤不吞。`LayoutInto` 的逐顆迴圈**還沒隔離**（只碰 SetParent／SetPoint／strata）。
- **裁切前先拆遮罩**（同日 `b249b3c7d`，治本）：圖示貼圖帶遮罩的按鈕，`SetTexCoord` 拋「Cannot set tex coords when texture has mask」。
  `StripMask(icon)` 兩種都拆——MaskTexture 物件走 `GetNumMaskTextures`／`RemoveMaskTexture`；舊式 `Texture:SetMask(檔案)` **沒有 getter、數量那支也看不到，但 `SetMask("")` 清得掉**
  （nil 不行：參數是非 nilable 字串）。⚠ 第一輪的結論「拆不掉」是錯的，只試想了 nil。認不出來所以無條件清。
  選「拆」不選「有遮罩就跳過裁切」：圓形遮罩跟金色圓框是同一套造型，跳過會在方格裡留一顆圓的。
- ⚠ `GetNormalTexture()` 不能無條件當成圖示：有一類按鈕的 normal texture 就是暴雪圓框本身，退回它之前要先 `IsJunk` 過。
- 收下來的圖示要 `SetDrawLayer("OVERLAY")` 往上提：自帶造型的插件會留一張我們不認識的裝飾貼圖在 ARTWORK。

### 「像被上了遮罩」查到四個成因，主因是 strata

使用者連續回報「圖示好像被上了一個遮罩」。四個成因依序找到：提示框與收納袋從同一錨點往下長完全重疊（修成**二選一**：袋子有東西滑過直接開袋、空的才彈提示）；
收納袋面板用了 HUD 半透明皮（改用**提示皮不透明**——它是「彈出來給人看內容」的表面，地形從底下透上來就是一道亮痕）；圖示壓在 ARTWORK；圓框被當成圖示。
⚠⚠ **真正的元兇（`/framestack`）：`SetParent()` 不會把 strata 帶過去。** LibDBIcon 把每顆按鈕釘在 `MEDIUM`，搬進 `HIGH` 的袋子之後還在 MEDIUM，
**面板自己的底色貼圖**整片畫在圖示上面。沒被蓋到的剛好是自己設 HIGH 的按鈕。規則見 [[wow-frame-vs-texture-layering]]。
**別在第一個找到的原因就收手；症狀重複三次以上就直接開 `/framestack`，不要再用推理的。**

收納袋是 hover 開的（使用者要求）。左鍵只剩「開著就收」，右鍵設定選單前先收袋。`/mmap bag` 仍是開關式（沒有格子可以滑時的唯一入口）。

## 社交列：三格，可客製

三格各自可選 **公會／好友／插件收納袋／無**。收納袋收進社交列是版面理由（地圖上下各長一條東西 → 只剩下方一條）。
**寬度規則：收納袋那格固定寬（正方形），其餘平分剩下的；「無」完全不佔位置；三格都「無」整條收起來。**
⚠ **標籤與數字必須是同一個 FontString**（數字用色碼上色，`S.AccentHex()`）：兩個各自置中的 FontString 在 9→10 時整組字會抖一下。
三格都沒選收納袋的話袋子沒有入口，逃生口 `/mmap bag`；**刻意不做「沒入口就自動長一顆鈕回來」**。

那條列叫「社交列」不叫「資訊列」（2026-09-06 改名，跟 [[project-miliui-infobar]] 撞名）。**只改人看的字，識別字一個都沒動**：
`db.infoBar*`、`ns.infoBar`、MiliUISnap 的 key `"infoBar"` 是存檔內容（[[project-miliui-snap-bars]]）；`Libs/MiliUISnap.lua` 的註解除外（vendor 複製，它說的正是 InfoBar）。

### 資料面：零背景工作

- 人數走現成 API（`GetNumGuildMembers()` 的第二回傳、`C_FriendList.GetNumOnlineFriends()` + `select(2, BNGetNumFriends())`），名單只在面板打開那一刻掃。
  ⚠ `GetNumGuildMembers()` 沒請求過可能是 0，要主動 `C_GuildInfo.GuildRoster()`（伺服器端約 10 秒節流）。
- ⚠ 戰網好友的 `game.className` 是在地化顯示名，查 `RAID_CLASS_COLORS` 永遠 nil；走 `game.classID` → `C_CreatureInfo.GetClassInfo(id).classFile`。
  `C_FriendList` 的角色好友沒有 classFile，拿不到就不上色（[[wow-unitclassbase-npc-returns-rogue]]）。
- ⚠⚠ **「在玩 WoW」不等於「有角色名可用」**：停在選角畫面的戰網好友 `clientProgram` 已是 `"WoW"` 但 `characterName` 是**空字串**、`characterLevel` 是 0（`charName or tag` 擋不住空字串）。
  `wowProjectID ~= WOW_PROJECT_ID` 是跨版本好友，標出來、不進邀請清單，密語照樣可走戰網暱稱。
- 12.1：名字／區域／備註可能是秘密字串，每個欄位進 `Data.lua` 就先過 `Secret.PlainText`，洗不出明文的整筆丟掉。

### ⚠⚠ 記憶體：四輪才抓到的 855 KB／次（2026-08-30）

使用者回報 26 分鐘吃掉 96 MB。前三輪都在追**頻率**（每幀掃 → TTL → 事件合流），每一輪都真的修掉了東西但都不是主因；
第四輪靠 `/mmap prof`（`Core/Profile.lua`）的取樣曲線定案——**階梯狀、每階 ~852 KB**（線性爬升＝持續配置，階梯＝單次很貴）。
**真兇：`BNGetNumFriends()` 回 `numTotal, numOnline`，只取了第一個** ⇒ 連離線好友也逐筆走 `C_BattleNet.GetFriendAccountInfo(i)`（每次配一張巢狀表）。
戰網清單是在線優先排序的，走 `1..numOnline` 就夠。

**最後的答案：語意換掉，成本歸零。** 數字從「正在玩 WoW 的好友」改成「在線好友」（ElvUI／Ellesmere 都是這個答案），常駐數字免費，
逐人查詢只在面板打開時。補一件兩邊都沒做的：**名單也一起收非 WoW 的人**（灰字＋右欄 `richPresence`），否則「數字 13、底下只列 5 列」會被當成 bug。
為此加的四層快取機制全部刪掉。

教訓（都是通則）：
- **語意的代價要在選語意的時候就算清楚**：一個定義若需要常駐輪詢才維持得住，它就不是更好的定義，只是更貴的定義。問「能不能用免費的 API 算出來」，不能就換定義不要換快取。
- **先問「一次吃多少」，再問「被叫幾次」**：那支呼叫次數只有 0.1/秒，在報告上完全無辜；`成本 = 單次 × 次數`，三輪只看右邊那一項。
- **把「別人會怎麼呼叫我的掛勾」當成每幀**；鏈上每一環都要補守衛，不只堵最貴的那個（Show 掛勾比狀態、Layout 顆數沒變不廣播、事件合流 5s／0.5s、內容沒變不 SetFormattedText）。
- **TTL 是地板不是節流**：`BN_FRIEND_INFO_CHANGED` 是消防水管，只要事件不停就永遠每 TTL 一次；要壓持續的事件流得讓事件本身合流。
- **量測工具本身不能是配置點**：`ns.Count("Fire:" .. event)` 的字串串接、`ns.Meter(key, function() end)` 的 closure 都是「剖析關著也照樣配置」，旗標要包住**參數的求值**。
- **回傳 table 的 C API 是配置點**（`GetFriendAccountInfo`、`C_Map.GetPlayerMapPosition`、`GetMouseFoci`）。
相關 [[wow-addon-profiler-cost]]。

### 名單是自己畫的可互動列表（`Panel/Tip.lua`），密語走聊天超連結

第一版是 `GameTooltipTemplate` 換皮，人名只能看不能點；現在是一個面板＋一池 Button 列，人名列**左鍵密語／右鍵邀請**，最底下「公會名冊／好友清單」按鈕（`Tip.AddButton`）。
⚠ 開面板第一版綁中鍵，回饋不直覺。⚠⚠ 那顆按鈕**不能呼叫 ToggleGuildFrame/ToggleFriendsFrame**（12.1 封鎖），是兩顆掛 UIParent 的 secure 鈕做點擊轉發
（[[wow-121-other-api-changes]]）。字級走 `db.tipFontSize`。邀請完名單留著、密語與開面板才收。
**提示框／名單走不透明底**：它是臨時跳出來讓人讀字的，多半蓋在任務追蹤框上，0.8 的底會兩層字疊在一起。判準：**底色承載「讓字讀得出來」的就不能透。**

**密語改走聊天超連結（2026-09-16）**：從插件的 OnClick 呼叫 `ChatFrame_SendTell` 會在自己的堆疊上寫 `LAST_ACTIVE_CHAT_EDIT_BOX`，之後按 R 回覆秘密名字就炸
（[[wow-121-chat-reply-secret-taint]]）。跟 MiliUI_ChatBar 同一套：
- `Panel/LinkSink.xml`：一顆 `ChatFrameTemplate`（`hyperlinksEnabled`），名單面板掛在它底下。⚠ 模板是 toplevel，名單畫在 **Sink 的** strata ——
  `frameStrata="TOOLTIP"` 要設在 LinkSink.xml 上，面板自己的 SetFrameStrata 在繪製上沒用（[[wow-toplevel-flattens-child-strata]]）。
  Sink 要補 `editBox = DEFAULT_CHAT_FRAME.editBox`（`chatStyle = "im"` 時 `ChooseBoxForSend` 直接讀這個欄位、沒 nil 備援，2026-09-20）。
- 每一列的字放在子框 `row.link`，名字包成 `|Hplayer:名字|h`／`|HBNplayer:暱稱:帳號ID|h`，左鍵由暴雪的 `SetItemRef → SendTell` 開密語；右鍵 `SetPassThroughButtons` 穿透回列本身做邀請。
  ⚠⚠ **propagate 是一層一層交的**：`row.link → row → panel → Sink` 每一層都要 `SetHyperlinkPropagateToParent(true)`。09-17 第一版漏了中間的 row，
  左鍵密語沒反應、名單也不收，**零錯誤、taint.log 乾淨**（09-21 `891d6122f`）。判別法：點名字後名單收不收——afterOpen 掛在 Sink 的 OnHyperlinkClick 上。
- ⚠ `SetPassThroughButtons` 戰鬥中對任何框都封（[[wow-hasrestrictions-mouse-apis]]）⇒ 列池不能懶建：`Tip.Reserve(上限＋LIST_CHROME_ROWS)` 由 Bar 在 Init／ConfigChanged 叫，
  戰鬥外長滿；戰鬥中被迫新建的列先不穿透、出戰鬥補。`LIST_CHROME_ROWS = 11` 是人名以外的列數，改版面要跟著改。
- 亮塊：連結字框是另一個滑鼠焦點（[[wow-hyperlink-region-steals-hover]]），Sink 的 `OnHyperlinkEnter/Leave` 用 `region:GetParent().row` 補。
- 右鍵選單只剩「邀請」：選單項目是插件的 OnClick，放密語又會髒。

**「跟著游標活著」的關閉機制在 `Panel/Bar.lua` 的 Hover 段**，名單與收納袋共用：滑入格子停 **0.5 秒**才開（`OPEN_DELAY`，2026-10-03，路過時不擋下方；已有面板開著時格子間移動仍立即切換）、
游標在格子或面板上就留著、離開兩者超過 0.35 秒才關（`GRACE`）。⚠ 不能掛格子的 OnLeave 立刻關（游標跨縫那一瞬間兩邊都不在）；
用 OnUpdate 輪詢而不是事件（面板的 OnLeave 在游標移到子列上時也會觸發）。格子上開著選單（`W.Menu.IsOpenFor`）也算「還在」。
格子本身任一鍵都是密語／邀請選單；**不綁開面板**——塞 secure 子框會讓整條社交列變保護框。

## 已修的坑（別再寫回去）

- `ns.Fire` 的派送順序是 `pairs()`。社交列改由 `Skin.Apply` 結尾的 `SkinApplied` 驅動，順序由呼叫鏈保證。
- **「開設定就自動解鎖」不能走會寫檔的那支**：拆成 `SetLocked`（寫檔）與 `RefreshDrag`（只算 `_optionsOpen or not db.locked or InEditMode()`）。**暫時性的 UI 覆寫不要經過持久化的那條路。**
- **FontString 沒給字型就 `SetText` 是硬錯，會中斷整支 `Build()`**，症狀是小地圖完全沒被接管。模組裡一律走 `MakeText()`（[[wow-fontstring-font-before-settext]]）。
- `GameTooltip:AddDoubleLine` 不能直接接 `S.Accent()`——它回四個值，alpha 被當成右欄紅色分量。先解成三個變數。
- 設定頁欄頭要對齊欄位不是對齊標題線：佔滿一行的東西用 `Options.CONTENT_W`，`FORM_W` 只給滑桿類；欄頭中心對齊勾選框中心，三個數字抽成常數（`SCROLLBAR_W = 20` 是共用層 `CreateScrollFrame` 給捲軸留的）。

## 編輯模式拖曳（2026-09-06）

**進編輯模式＝暫時解鎖**，顯示的還是自己那層拖曳遮罩（比藍框多了拉把手與右鍵歸位，跟開設定視窗同一層）。不註冊真的 Edit Mode 系統（[[wow-editmode-draggable]]）。
⚠ **進出編輯模式都要補一次 `Skin.Apply()`（延一幀）**：編輯模式跑版面會把 `MinimapCluster` 的 alpha 與暴雪按鈕位置還原。`EDIT_MODE_LAYOUTS_UPDATED` 只在版面真的被改存時才發。

## 副本難度文字（2026-10-13，未實機驗證）

`Map/Difficulty.lua`：左下角一小塊白字（「英雄 5人」「M+12」「探究 8」），開啟時暴雪旗子 reparent 到 `ns.hiddenParent`（沿用 Skin.Apply 的戰鬥閘），關掉搬回。
難度對照表在檔頭，沒列到的退回暴雪在地化名稱。刻意白字不按難度上色。開關 `difficultyText` 預設開。

## 待驗證

09-06～10-03 多輪實機回報（遮罩感、記憶體、名單左鍵、戰鬥中列池都是實機修的），登入接管／按鈕收納／釘選顯然跑過。剩下沒被覆蓋的：
- [ ] `AddonCompartmentFrame` 搬到地圖上方會不會被暴雪搶回去（Ellesmere 掛了持續性 hook；我們只在 Apply 時擺一次）
- [ ] LoadOnDemand 的插件（拍賣、背包）開過之後有沒有被補收進來
- [ ] 社交列的名單在 500 人公會會不會太長／太慢
- [ ] `SetMask("")` 對「本來沒遮罩」的貼圖應是空動作，收納袋開起來看圖示有沒有異狀
- [ ] 編輯模式裡拖得動嗎：暴雪 `MinimapCluster` 的選取框 alpha 是 0 但**滑鼠判定還在**，預設位置又跟我們重疊在右上角。**開 `/framestack` 看是誰吃到點擊。**
- [ ] 副本難度文字
