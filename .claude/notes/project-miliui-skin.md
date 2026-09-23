---
name: project-miliui-skin
description: 米利的介面外觀 MiliUI_Skin —— 暴雪原生視窗換成設定視窗皮的 PoC（對話／角色面板／成就）；只重畫不重排的契約、驗收時抓到的三個坑、待實機驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 3d3da2d2-d8a9-4944-8afe-aebf91167c1f
  modified: 2026-09-21T03:47:31.585Z
---

**2026-09-20 建立；PoC 三視窗已通過實機 taint 驗收；第二輪（六個視窗）實機看過、taint.log 零 blocked；第四輪（12 個視窗）使用者實機看過、taint.log 零 blocked；第五輪使用者實機看過（收藏有底、條不壓字、分頁「好很多」）；第六輪使用者看過分頁（提出置中問題、已修）；第七輪（精緻化＋寶庫／冒險指南／拍賣場／專業，共 18 個視窗開關）已合併、尚未實測。** `AddOns/MiliUI_Skin/`，TOC **預設啟用**（2026-09-24 拿掉
`## DefaultState: disabled`；⚠ 那個指令只影響從沒見過這支插件的角色，之前被預設關掉的人要自己去插件清單打開），`/mskin` 開設定、
`/mskin debug` 印每份配方的狀態＋找不到的區域＋因保護框跳過的清單。
規範全文在 `AddOns/MiliUI_Skin/STYLE.md`（Tokens／契約／模板配方表／新增視窗 checklist／範圍分級），
配方表每列的「實測狀態」目前全是未實測。契約 lint：`.claude/scripts/check_skin.py`（已接進 check-all）。

## 核心：只重畫、不重排

傳統 skin 做法（遞迴清貼圖＋在暴雪框寫欄位＋SetPoint 重排）在 12.1 整條死路。
這裡是把 [[project-miliui-tooltip]] 的 overlay 架構推廣：
- 中和暴雪美術**一律 `SetAlpha(0)`**（alpha 與 atlas 獨立，暴雪重設 atlas 也不會打回來）。
- 外觀畫在自建 overlay（純 Frame＋1 底＋4 邊貼圖，level＝目標−1，SetAllPoints）。
- 狀態放弱鍵 side table，暴雪物件零欄位寫入；不讀暴雪物件的文字／尺寸／錨點。
- 內容底材（羊皮紙、模型場景、地圖）保留，只 skin chrome —— 內文字色是針對那張底設計的。
- 視窗皮＝設定視窗皮（0.115 不透明＋黑邊），依 [[project-miliui-hud-skin]] 的判準；職業色只給選中。
- Tokens 暫時照抄在 `Core/Tokens.lua`，**PoC 過了再升格進共用層**（[[project-miliui-widgets-vendor]]）。

## 三個陷阱（寫進 STYLE.md ③）

1. **overlay 不准用 BackdropTemplate、不准掛 OnShow/OnSizeChanged**：BackdropTemplate 自帶
   OnSizeChanged 的 Lua，暴雪改視窗大小時會跑在暴雪堆疊裡（[[wow-121-addon-code-in-secure-stack]] 同型）。
2. **overlay 不准 parent 到 LayoutFrame／ScrollBox／物件池容器**：它們走訪 children 讀 layoutIndex，
   讀到我們的表就污染；ResizeLayoutFrame 還會把 overlay 算進尺寸。改掛最近的非 layout 祖先。
3. **狀態優先交給引擎**：Highlight 貼圖 `SetColorTexture(1,1,1,0.08)` 讓 C 端自己畫 hover。

## 實作／驗收時抓到的坑

- **捲軸拇指不能 SetColorTexture**：`MinimalScrollBarThumbScriptsMixin:OnSizeChanged` 會
  `GetAtlasInfo(self.Middle:GetAtlas())` 讀 `info.height`，換純色 → GetAtlas 回 nil → 每次捲動報錯掛我們名下。
- **按鈕文字 SetTextColor 撐不過一次滑過**：文字顏色屬於狀態字型物件，C 端滑過／離開各換一次。
  改 `btn:SetNormalFontObject(GameFontHighlight)`（只傳暴雪自己的字型物件），三態全交給引擎。
- **Pushed 貼圖「中和」與「上色」二選一**：SetColorTexture 的 a 與 SetAlpha 相乘，中和過再上色看不見。
  只有關閉鈕（模板寫死 atlas）走上色，其餘中和。
- 分頁「交給引擎畫」走不通（Active 貼圖 useAtlasSize 且超出分頁矩形，要修得 SetPoint）⇒
  分頁是唯一走 hook 的原語：`PanelTemplates_SelectTab/DeselectTab/SetDisabledTabState` 後置勾＋
  建立時讀一次 `LeftActive:IsShown()` 做初始同步（成就視窗 OnLoad 就選了分頁 1，比 ADDON_LOADED 早）。
- `UIPanelButtonTemplate` 沒有 PushedTexture ⇒ 按下沒視覺，PoC 接受。
- 成就視窗是 BackdropTemplate（九片直接掛在 frame 上）不是 PortraitFrame；分頁模板沒有 `TabTextures` parentArray。

## 實機驗收結果（2026-09-20，使用者實測＋taint.log）

**PoC 的 taint 線通過**：戰鬥中按 C 開角色面板正常；`taint.log`（載入 Skin 之後的 session）
**0 筆 blocked、0 行提到 MiliUI_Skin**。成就視窗那批污染點名的是別的插件、既有狀況。
⇒ 「alpha 中和＋純貼圖 overlay＋side table＋hooksecurefunc（含掛在 CharacterFrame 實例方法上的
`SetTitleColor` 後置勾、全域 `PanelTemplates_*` 後置勾）」這一組在 12.1 是實證安全的。

外觀面使用者看過擷圖後的結論（第二輪打磨的來源）：
- 關閉鈕 × 用 `UI-StopButton` 會是暗金色 —— 那張貼圖本身有色，vertex color 染不白 ⇒ 改用 Line 自己畫。
- **成就視窗「外框深、內容亮橘羊皮紙」是全套最不協調的** ⇒ 「內容底材保留」不是鐵律：
  要換可以，但必須連同上面所有文字顏色一起接管（暴雪在 Saturate/Desaturate 類路徑會重設）。
- 角色面板殘留的雕花（屬性欄標題牌、模型內框、裝備格外框）、聲望／通貨頁的下拉與分類標題列要補。

## 第二輪（2026-09-20 同日合併，未實測）

**池化列機制 `Engine.HookRows`（STYLE.md 陷阱 4）**：ScrollBox 的列只能掛在暴雪每次重用列時一定會跑的
那支上（`hooksecurefunc(XxxMixin, "Init", …)`）。
- ⚠ **mixin hook 只對之後建立的 frame 生效**（mixin 在 frame 建立時複製函式）⇒ hook 要在
  登記／ADDON_LOADED 當下就裝、**不過戰鬥閘**；先建好的列用 `ScrollBox:ForEachFrame` 補掃。
- ⚠ **`CreateFromMixins` 是同一條規則往上一層**：`ListHeaderThreeSliceMixin = CreateFromMixins(ListHeaderVisualMixin)`
  在檔案載入時就拷貝了，勾父 mixin 追不上，要勾子 mixin。
- hook 內：弱鍵表分 apply（一次）／reapply（暴雪每次重設的：文字顏色、被打回的 alpha、**`SetTexture` 會把
  texCoord 打回 0,1** 所以圖示裁邊要放 reapply）；不讀 elementData；出錯一次就停用該 hook。
- 不用 `ScrollUtil.AddAcquiredFrameCallback`（那是往暴雪的 callback 表寫東西）。
- 隨需載入的子頁（兌換通貨住在 `Blizzard_TokenUI`）用 `Register` 的 `parts`，共用外層的設定開關。

**下拉 `Skin.Dropdown`**：只 skin 按鈕本體、不碰彈出選單。下拉這個 intrinsic **沒有 HighlightTexture**，
滑過回饋靠暴雪自己換 Arrow 的 atlas；filter 版的文字顏色由 `baseFontObject` **欄位**驅動 ⇒ 接管不了，維持暗金。

**成就視窗深色化**：重設文字顏色的路徑有四條（`Saturate` 設純黑、`Desaturate`、`Init` 只在 saturatedStyle
變了才呼叫 Saturate ⇒ 三支都要勾、`AchievementObjectives_DisplayCriteria`）。完成／未完成＝「暴雪呼叫了哪一支」
決定底色明暗，不讀欄位。分類列的選中與滑過在暴雪是同一張貼圖（LockHighlight）⇒ 選中另走 overlay 底色。

**聲望／通貨分類列的 ＋／− 是烤在右端帽 atlas 裡的**，`Right` 不能中和只能染色。
**裝備格**：只對獨立裝飾貼圖 `Character<Slot>SlotFrame` SetAlpha(0)，按鈕本體完全不碰。

**任務／郵件／好友**（只做 chrome／按鈕／分頁／捲軸／輸入框，零 hook）：
- 好友名單頂部分頁是 `TabSystemButtonTemplate`，**不經過 `PanelTemplates_*`** 而且是池化的 ⇒ `Skin.Tab` 不適用，沒做。
- 郵件的舊式輸入框／ThinGoldEdge 的切片**只有全域名字沒有 parentKey**；金額欄是三個獨立小框（parentKey 小寫 `left`/`right`）。
  這批 local 小函式標了 `TODO(升格)`。信件列格子美術無名 ⇒ 收件匣目前是深底＋暴雪棕色格線。
- 套組裡 Postal 掛了一票按鈕在郵件視窗（這一輪不碰），而且會把暴雪的 `OpenAllMail` 藏起來。
- ⚠ 待測重點：好友名單「傳送訊息」（`ChatFrameUtil.SendTell`）之後 R 鍵回覆還能不能用（[[wow-121-chat-reply-secret-taint]]）。

## 第二輪實測＋第三輪（2026-09-20 晚）

第二輪 taint.log：0 blocked；點名 MiliUI_Skin 的只有 slash 全域與 `UISpecialFrames` 的設定視窗名（所有 MiliUI 設定視窗共通、
開過設定視窗才有），**17 支 mixin／全域後置勾零筆**。使用者回饋：信箱要重做、bar 材質要換、裝備格要 1~2px 方框、
成就標題浮在框外。

第三輪做法與新坑：
- **`Skin.ItemButton`（物品格方框）**：勾**全域** `SetItemButtonQuality`＋`SetItemButtonTexture`（不勾 `ItemButtonMixin` ——
  intrinsic 的 mixin 建立時就拷貝走，裝備欄是 LoadFirst 建的追不上）。全遊戲物品格都會進來 ⇒ 第一行查弱鍵表。
  圓角 `IconBorder` alpha 0（每次被 SetShown(true)＋重設材質 ⇒ reapply），自己畫 `T.itemBorderSize`（預設 1）方框，
  **顏色轉交**：`IconBorder:GetVertexColor()` → 自己貼圖的 **SetVertexColor**（貼圖鋪白；不做任何比較／算術），顯示與否跟 `IsShown()`。
  收件匣「沒有附件」那條路直接 `IconBorder:Hide()` 不經過全域函式 ⇒ 要另勾 `InboxFrame_Update`。
  破損裝備的紅框訊號隨 NormalTexture 中和沒了（圖示染紅還在）。
- **進度條換 `Media/tuktex.tga`**（自帶一份；`SetStatusBarTexture` 明文路徑，先查證沒人 `GetAtlas` 讀回）。
  聲望條「框比條短」其實是**層級**：overlay 在 target−1，填充從左緣畫起蓋住黑邊 ⇒ 邊走前景 slot。
- **分頁之間的「殘片」不是漏中和的貼圖，是按鈕間 3~4px 的縫**（原本靠端帽超出矩形去補）⇒ overlay 往右延伸。
- 成就分類列：暴雪 Highlight 比按鈕往下多 7px、列間無間距 ⇒ 選中／滑過兩態都自己畫、中和 Highlight。
- 成就 `Init` 每次 `TitleBar:SetAlpha(1|0.8)` ⇒ reapply；總結頁要另勾 `AchievementFrameSummary_Refresh`。圖示金框時有時無的根因沒找到，靠每次重申硬蓋。
- **成就標題帽**：`Header` 本來就凸出視窗上緣（Points 正好跨在上邊線）；不能 SetPoint 暴雪的框 ⇒ 以 `Header.PointBorder`
  為錨畫一塊下邊不畫的平面（上下鏡射的分頁語彙），level 在 Header−1 ⇒ 蓋過視窗上邊線、在文字之下。
- 紅金 ＋／− 鈕烤了顏色、乘法染不灰 ⇒ `SetDesaturated(true)` 再染（`RefreshIcon` 每次重設 atlas ⇒ reapply）。
- 勾選／單選：`GetCheckedTexture()`／`GetDisabledCheckedTexture()` 換成滿格職業色（引擎驅動）。
- **伴隨元件規則**（STYLE.md ③）：套組內建、固定掛在暴雪視窗上的別家元件（郵件增強插件的按鈕）有就 skin、沒有靜默跳過；
  不呼叫／不 hook 它的函式、不寫它的欄位；時機＝自己的事件框收 `MAIL_SHOW` 後延一幀、冪等。
- 信紙深色化（內文字色全接管）；**信件內文自帶的 `|cff…|r` 色碼接不住**（GM／活動信可能出現深色字），發票算式線直接中和。
- 白名單這一輪擴充：進度條材質、`SetDesaturated`、EditBox/SimpleHTML 的 `SetTextColor`、Checked／DisabledChecked 的 `SetColorTexture`；
  lint 同步收緊（這幾個 setter 與 `GetVertexColor` 只准走 Engine）。

## 第四輪（2026-09-20 深夜，四個 Opus 平行：A 打磨＋引擎、B/C/D 各加新視窗且不准改 Core）

平行模式的分工規則（有效，下次照用）：一個代理擁有 `Core/**`＋既有配方且**不准改現有 API 簽章**；其餘代理只新增 `Skins/*.lua`，
缺的功能寫成配方內 local 小函式標 `TODO(升格)`；共用檔（TOC／DB `windows`／Tab_General／Locales／STYLE ⑤表尾與⑦）各自只加行，
合併衝突用「兩邊都留」解（scratchpad 的 keepboth.py），STYLE.md 的表要人工看一眼有沒有被段落切斷。

新坑與結論：
- **陷阱 4 的第三層**：`TabSystemButtonArtMixin:SetTabSelected` 的 mixin 後置勾對好友名單無效 —— 分頁在 XML 載入期就建完，
  而且 `FriendsTabMixin = CreateFromMixins(TabSystemButtonMixin)`，勾哪一層都追不上 ⇒ `Skin.TabSystem` 走兩條路：mixin 勾（之後才建的）＋
  掛在該視窗的全域刷新函式後面**重讀** `LeftActive:IsShown()`。
- 篩選下拉的文字顏色其實接得住：`OnEnable/OnDisable` 是 frame script（`HookScript` 接得到）、`OnLoad` 只有設過 `baseFontObject` 才動文字。
- 成就圖示金框根因：只有 `AchievementIcon_Desaturate/_Saturate` 碰 `Icon.frame`（SetVertexColor），未完成列每次 Init 無條件 Desaturate、
  已完成列被 `saturatedStyle` 守衛擋掉 ⇒ 症狀 1:1 對上；保留每次重申一發 SetAlpha。
- 好友名單三種列的 view 都是匿名閉包轉呼叫**全域函式** ⇒ `HookRows{ mixin = _G }`；`row.name` 這種只是拿 FontString 子鍵認模板，不是讀資料。
- **收藏**：分頁是 `PanelTabButtonTemplate` 但矩形彼此**重疊 16**（`Skin.Tab` 的右延伸會壓到鄰居）⇒ 配方內 `SkinPanelTab` 左右各內縮 8；
  玩具／傳家寶格是 `SecureFrameTemplate`，長相全在格框貼圖上，中和了沒東西補 ⇒ 完全不動；坐騎／寵物列的初始化是全域函式。
- **地城與團隊**：`Blizzard_GroupFinder` 非 LoD（PvP、M+ 才是，走 `parts`）；左側大類鈕的選中靠 `bg:SetTexCoord`、Highlight 比按鈕大 ⇒ 勾
  `GroupFinderFrame_SelectGroupButton`＋ownHover；**預組隊伍只做純視覺**（搜尋列只換滑過帶、申請者列只 skin 三顆按鈕，不讀 resultID／applicantID）；
  羊皮紙上的地城清單不做；征服條每次 SetAtlas ⇒ 不換材質；`LFGListPVEStub_OnShow` 每次對 `LFGListFrame` SetFrameLevel（overlay 層級是建立時算的，待測）。
  本體 `Enhance/ChallengesUI_Buttons`／`PartyKeystone`／`ChallengesUI_LootTable` 是各自手寫的「深半透明底＋金邊」，要一致得在本體改。
- **商人**：品質更新走的是物品鈕的**方法**不是全域函式，而全域 `SetItemButtonTexture` 又跑在品質更新之前 ⇒ 方框會慢一件商品 ⇒
  配方自己勾 `MerchantFrame_UpdateMerchantInfo/_UpdateBuybackInfo`，第一行 `MerchantFrame:IsShown()`（已列入讀取例外；暴雪視窗沒開也狂跑更新）。
  `MiliUI_Merchant` 自己加的齒輪鈕／右側補白格／已收藏勾都是**匿名框**，伴隨元件規則碰不到 ⇒ 要在那支插件裡給全域名稱；
  補白格的純黑在底部雕花中和後會對不上。
- 物品升級：全檔零 SetTextColor ⇒ 整個深色化零接管成本。`SideDressUpFrame` 是 `flattenRenderLayers`（[[wow-toplevel-flattens-child-strata]]），overlay 可能蓋到模型，待測。
- 插件列表：分類列的 Init 是 local 函式掛不上 ⇒ 借全域 `AddonList_Update` 補掃。最大化／最小化鈕沒有自己的圖記（Engine glyph 只有 cross）。
- lint 這一輪再收緊：`SetEnabled/Enable/Disable`、`SetHighlightLocked`、`SetDisabledFontObject/SetHighlightFontObject`、`AddAcquiredFrameCallback`。

## 第五輪（2026-09-21，依第四輪實機擷圖）

- **保護會沿 parent／anchor 鏈往上傳染（隱式保護）**：收藏視窗整個透明的根因 —— 18 顆 `SecureFrameTemplate` 玩具格把
  `ToyBox.iconsFrame → ToyBox → CollectionsJournal` 一路染成隱式保護，舊規則「IsProtected 就跳過」把外框底整份跳掉
  （分頁／搜尋框不在那條鏈上所以有皮 —— 這個對比是指紋）。`IsProtected()` 回兩個值 `(isProtected, isExplicit)`：
  **只有顯式才跳過**；隱式照樣掛 overlay，但戰鬥中不做也不標記、下次重試。`/mskin debug` 分三張清單。
- **分頁組 `Skin.TabGroup`**：每顆 overlay 右緣直接錨到**下一顆分頁的左緣**（自己的 overlay 同時錨兩個暴雪框是允許的）、
  除最後一顆不畫右邊線 ⇒ 共用一條線，間距 +1／+3／重疊 16 都自動對上。`PanelTemplates_AnchorTabs` 不跳過隱藏分頁，
  只有「排在中間會消失」的才要標 `hideable`（目前只有收藏的傳家寶）。TabSystem 是 HorizontalLayoutFrame，隱藏的分頁位置不保證 ⇒ 不錨下一顆。
- **契約例外：分頁文字置中**。暴雪在 Select/Deselect 裡把 `tab.Text` 設成 CENTER −3／+2（選中那顆原本垂得比較低）；
  在同三支後置勾裡對已接管分頁的 `tab.Text` 重設 `CENTER 0,0`（`Engine.CenterTabText`，lint 仍禁止配方直接 SetPoint）。
- **進度條的邊不能畫前景**：會橫切過條上的文字。改成畫在下層、矩形往外推（`pad`），填充在條內碰不到邊。
  聲望條只有 13 高、成就總結條的標籤比中心高 3~4 ⇒ 都給 pad 2。
- **按鈕 hover＝底提亮＋1px 職業色邊**（對齊 `W.CreateButton`／`S.ApplyDarkButton`），走 `Engine.TrackButtonHover`
  （HookScript OnEnter/OnLeave，只在滑鼠進出時跑）；原本引擎的白 8% 要 alpha 0 避免疊兩層；停用的不給 hover（讀 `IsEnabled()`，已列例外）。
  清單列維持低調提亮。**確認彈窗／ESC 選單是「零按鈕 HookScript」特許**，那裡的下拉用 `opts.noHover`。
- 收件匣列底的 **parent 設成會被暴雪 Hide 的那顆信件鈕**、錨點仍錨在列上 ⇒ 空列自動沒有底，零讀取零 hook。
- 下拉箭頭／紅金小鈕這類烤了顏色的 atlas：乘法染不出中性灰，要先 `SetDesaturated`。
- **任務／對話深色化走暴雪內建 CVar `questTextContrast = 4`**（0~4，`Blizzard_AccessibilityTemplates/QuestTextContrast.lua`）：
  暴雪自己換底圖與全部字色，我們不碰任務框。設定開關預設開、記住原值、關掉還原；邏輯放配方自己的事件框而不是 apply
  （否則關掉 quest 視窗後沒人還原）。⚠ 整支插件被停用的話 CVar 會停在 4。
- 地城／團隊搜尋的「羊皮紙」上其實全是白字與金字（`QuestTitleFontBlackShadow` 的 Black 指陰影）⇒ 零接管就能深色化。
  鑰石頁地城圖示：要勾的是每格的 `ChallengesDungeonIconMixin:SetUp`（LoD＋格子晚建 ⇒ 追得上），第四輪說勾不到是掛點找錯。
  PvP 征服條的中和撐不過第一次 Update（`SetDisabled` 下 SetAlpha）⇒ 靠條的 OnShow/OnEvent frame script 後掛重申。
  職責勾選框的 CheckedTexture 是 setAllPoints 縮不了 ⇒ 改成保留勾的形狀只染職業色、底用 fillInset。
- **確認彈窗＋ESC 選單（純視覺特許）**：`StaticPopup1..4` 是 XML 靜態框 ⇒ 零 hook 套一次；ESC 選單按鈕是池化且每次 `SetScript`
  OnEnter/OnLeave（HookScript 會靜默失效）⇒ 只有一支 `GameMenuFrame:HookScript("OnShow")`，內容是延一幀＋戰鬥閘的掃描。
  兩者本體都是 layout host 且在 DIALOG strata ⇒ overlay 必須明確 parent 到 `dialog.BG`／`GameMenuFrame.Border`，否則 SafeParent 爬到 UIParent、皮掉到視窗後面。
  關閉鈕每次 Init 被重設貼圖 ⇒ 不能沿用 `Skin.CloseButton`（Pushed 要中和）。就位確認／地城就緒／職責確認刻意不做。
  待決：這兩個視窗照三套皮判準其實落在「提示皮」（職業色邊），目前用黑邊。
- 本體 `Enhance/ChallengesUI_Buttons`／`PartyKeystone`／`ChallengesUI_LootTable` 已改走 `S.ApplyDarkPanel`／`S.ApplyDarkButton`。
- 還沒收：`PVE.lua`／`PVP.lua`／`Challenges.lua` 的三支 local（StretchButton／SquareIconButton／InputScroll）正式原語已備好、尚未切換。

## 第六輪（2026-09-21 凌晨；依 [[wow-blizzard-window-skin-strategies]] 調整，無人能實測 ⇒ 每項都留退路）

- **`Engine.RegionBackdrop`**：Panel／Inset／StatusBar 的底與邊改成直接 `CreateTexture` 建在目標暴雪框上（BACKGROUND −8／−7），
  回傳與 overlay 同形狀的表；四種情況自動退回子框（`db.regionBackdrop=false`、不是 Frame、layout host、pcall 不過），
  `/mskin debug` 有一節列出哪些退回了。`opts.parent` 有給（彈窗／ESC 選單）一律走子框。`Engine.ownRegions` 弱鍵表讓
  `NeutralizeRegions` 不會把自己畫的底中和掉。**整批關掉：`MiliUI_Skin_DB.regionBackdrop = false`＋/reload。**
- **分頁**：`hideable` 跳過邏輯整個拿掉（它造成「玩具箱與傳家寶一起亮／hover 橫跨／傳家寶選中不亮」三個症狀）；
  每顆永遠接緊鄰的下一顆、overlay 彼此零重疊。新語彙 `T.tabStyle="underline"`：未選字 `textDim`（`Engine.DimFont`＝繼承暴雪字型只改色的自有字型物件）、
  hover 只提亮、選中＝`fillSelected`(0.16)＋朝外那邊 2px 職業色線；**分頁不用 hover 邊框**（共用邊線下永遠只亮三邊）。`"fill"` 可一行切回。
- **商人每格底框**：`fillInset`＋1px 邊、內縮 2；空格暴雪 Hide 的是 `ItemButton` ⇒ 底的 parent 設成它（零讀取）；底部買回格反過來（Hide 的是格子）。
- **撤掉通貨清單列的全部 hook**（5 支 mixin 勾＋SweepRows＋轉移鈕換皮）—— 那條列的更新路徑跟戰隊通貨轉移的受保護請求是同一條執行流。只留外框級。聲望頁不受影響。
- **勾選框**：置中固定 18 的小方框（`T.checkBoxSize`，不再照按鈕矩形）＋`Engine.CheckedGlyph`（保留暴雪勾的形狀、去飽和＋染職業色；勾比框大自然外溢）。
  `checkmark-minimal` 不是正方形、塞進 setAllPoints 的 Checked 貼圖會被拉扁 ⇒ 沒用 SetAtlas。插件列表的三態勾由 **local** 函式設定、分不出「部分啟用」⇒ `keepCheck`（只收小框、勾留暴雪的白色）。黑描邊做不到。
- 標題帶（`PortraitChrome` 系，`fillInset` 高 22＋髮絲線，`opts.titleBar=false` 可關）、捲軸收成 6px 細條＋拇指 hover。
- **`MiliUI_Skin_DB.lastReport`**：登出時存 `/mskin debug` 的內容（400 行上限）—— 之後直接讀 WTF 的 SavedVariables，不用等使用者貼。
- 同日另修：好友狀態下拉顯示「...」不是 Skin 的鍋（暴雪寫死 51 寬 ≈ 8＋16＋箭頭 28，換字型後零頭放不下）⇒ `MiliUI/Fix/Blizzard_FriendsStatusDropdown.lua` 加寬到 63。

## 第七輪（2026-09-21）

- **線條圖記**：下拉 ⌄、翻頁 ‹ ›、捲軸 ∧ ∨ 都改成 `CreateLine` 畫在自己 overlay 上（暴雪的立體小圖 alpha 0）；停用態走 `HookScript OnEnable/OnDisable`
  （DisabledTexture 的矩形是暴雪給的、比我們內縮過的 overlay 大，塗暗會露一圈光暈）。`T.scrollStepper="hide"` 可純中和。
  套組設定視窗的捲軸其實也是暴雪 `MinimalScrollBar`（只是沒換皮），不是「沒有箭頭」。
- **清單列語彙**統一在 `Skin.Row`：滑過提亮；選中＝`AccentFill` 底＋左緣 2px 職業色直條（`opts.noAccentLine` 可關）。
  做不到的：聲望分類列／插件列表分類列的 ＋／−（展開狀態沒有零讀取來源）。
- **分頁的兩個坑（使用者擷圖抓到）**：
  1. **XML 寫的分頁重疊（`LEFT → 前一顆 RIGHT x=-16`）在遊戲裡從來沒生效** —— `PanelTemplates_SetNumTabs` → `PanelTemplates_AnchorTabs`
     把每顆重錨成 `TOPLEFT → 前一顆 TOPRIGHT +3`。照 XML 給 `pad` 會讓 overlay 偏移、字看起來不置中。⇒ **PanelTab 系的 `pad` 一律 0**
     （收藏、冒險指南都踩過；查 XML 時要連 OnLoad 有沒有 `SetNumTabs` 一起看）。
  2. 成就視窗的 `AchievementFrame_UpdateTabs` 在 `PanelTemplates_Tab_OnClick` **之後**又把三顆分頁的字設成 −5／−3 ⇒ 要另勾它再置中一次。
- **大類按鈕圖示改方形**：使用者不喜歡「圓形＋壓深環」的模糊邊。圖示素材本來就是方形、圓形只是 `CircleMask` ⇒ 新契約例外
  `Engine.UnmaskIcon`（`RemoveMaskTexture`，只准純裝飾遮罩、脫戰、失敗自動退回壓深環）＋裁邊＋錨在圖示上的 1px 黑框；
  列 overlay 上下各加 3（圖示 66 高、按鈕 60 高）。`T.categoryIconStyle="ring"` 切回。
- **寶庫**：純視覺特許、零 hook；活動格無名且 OnLoad 就建好 ⇒ 用 `GetChildren`＋四個 parentKey 的組合認；圖示裁邊靠自己事件框收
  `WEEKLY_REWARDS_UPDATE` 延一幀補；解鎖／未解鎖是同一張貼圖換 atlas ⇒ 做不出明暗差；領獎確認面板不碰。
- **冒險指南**：戰利品列／首領列勾 mixin `Init`；戰利品列是 345 寬的「按鈕」⇒ 方框要錨在 icon 貼圖上而不是用 `Skin.ItemButton`；
  技能說明區羊皮紙保留（十幾處字色＋SimpleHTML 每次重設）；副本卡片的初始化是 local 函式，接不到。
- **拍賣場／專業：特許的第二種粒度（按鈕級）** —— 只有會送出受保護請求的按鈕（出價／直購／上架／取消拍賣／製作／接單／完成訂單／套用專精…）走配方內的
  `CommerceButton`（中和＋引擎 hover＋字型物件＋overlay，零 HookScript），其餘照一般原語。拍賣結果清單的「列」一顆都不碰
  （唯一出口是全遊戲共用的 `TableBuilderMixin:AddRow`，而且跟出價／直購同一條執行流）；`ProfessionsRankBar` 不是 StatusBar（遮罩＋FlipBook）不碰；
  製作訂單的四顆範圍分頁是 XML 建的、選中態只能從暴雪框實例方法得知 ⇒ 不碰；專業視窗的分頁同步勾的是**全域** `TabSystemOwnerMixin.SetTab`
  （`ProfessionsMixin:SetTab` 最後用明碼表查詢呼叫它），只在裡面呼叫 `Engine.SyncTabSystemAll()`。Auctionator 的四顆分頁照伴隨元件規則一起進 `Skin.TabGroup`
  （必須跟暴雪三顆**同一次**畫完：接縫錨點只在 overlay 建立時定一次）。
- 撞到過一次用量上限（三個 Opus 同時）：被中斷的代理用 SendMessage 續跑即可，worktree 還在。

## 第八輪（2026-09-21，依實機擷圖逐項修）

- **第三方樣式一律住 `ThirdParty/`**（使用者定的）：一支插件一個檔（Postal／Auctionator／PremadeGroupsFilter／RaiderIO），TOC 排在所有 `Skins\` 之後。
  掛法：`Engine.AddCompanion(hostKey, {event|atLogin, addonKey, apply})`（hostKey=nil ＝不長在任何暴雪視窗上，例如對方自建的 tooltip）；
  **額外分頁**走 `Engine.AddCompanionTabs(hostKey, names, addonKey)`，host 配方用 `E.CompanionTabs(hostKey)` 取出跟暴雪分頁同一次交給 `Skin.TabGroup`。
  開關在 `db.thirdparty[addonKey]`（設定頁「其他插件」一節），跟 host 視窗開關是「而且」。ThirdParty 檔**零 hook、不呼叫對方函式**，只照全域名字拿框、沒有就靜默跳過；`check_skin.py` 已把這個資料夾納入。
  對方自建的 tooltip 走 `MiliUITip_API.Adopt(tip)`（MiliUI_Tooltip 提供；沒裝就退回 `T.tipFill`＋職業色邊自己畫）。⇒ **以後任何第三方換皮都放這裡，不要再塞回 MiliUI_Tooltip 或本體 Enhance。**
- **平面勾**：`Engine.CheckedGlyph` —— Checked 貼圖置中、`SetColorTexture` 純色、用 `checkmark-minimal` atlas 當**遮罩**切出勾形（同套組設定視窗的勾）；單選鈕是實心小方塊；任一步失敗退回染色。
  勾選框的邊線要跟底同一層（放前景會蓋住勾）。`T.checkStyle`／`T.checkGlyphHeight`。
- **`Engine.ShiftRoot`**（新契約例外）：整條錨定鏈只重錨**根框**一次，後面的自己跟著走；脫戰、`db.relayout=false` 可關。專業書用它收左邊留白。
- **專業技能書**：等級條換平面材質後要自己給顏色（原色烤在材質裡）；技能鈕方框要用 `RegionBackdrop` 建在**按鈕本身**（掛外層容器 ⇒ 按鈕隱藏後留空框）；
  只有一顆技能鈕時上移置中（讀 `SpellButtonTop:IsShown()`，已列讀取例外）；`FormatProfession` 後置勾重裁圖示。
- **選用參數的坑**：`Skin.TabSystemAll(x)` 沒傳 opts 當場報錯 ⇒ 每支原語開頭 `opts = opts or {}`，**驗收時逐一對照呼叫端與簽章**。
- PGF 自畫的難度下拉：overlay 要內縮到可見欄位（22／18），照它 145x32 的外框畫會凸出視窗。
- 不是 skin 但一起修的（都在 `MiliUI/`）：`Fix/Blizzard_FriendsStatusDropdown.lua`（51 寬剛好等於狀態圖寬，換字型就「...」⇒ 設成常數 63）、
  `Fix/PremadeGroupsFilter_ShortLabel.lua`、`Enhance/ChallengesUI_LootTable.lua`（M+ 檔案提示會被對方自己 SetPoint 挪回來 ⇒ 勾它 anchor 的 `SetPoint` 重套、有重入保護；面板底不透明）。
- **彈窗／ESC 選單外框＝提示皮**（使用者定）：`T.tipFill`＋`T.Accent()` 邊，**只有最外圈**；裡面的按鈕／輸入框照舊 fill＋黑邊（職業色一個視窗只給一處）。
- 地城搜尋器的職責勾選框：原本 `fillInset`(0.08)＋黑邊壓在 0.115 視窗底上等於隱形 ⇒ 改 `fillCheck`、`ROLE_BOX_SIZE` 14→22（按鈕 scale 0.7，上限 29）、加滑過。
- `MiliUI/Fix/Blizzard_LFGListRoleCountWidth.lua`：團隊列表職責人數兩位數顯示「…」—— `RoleCountNoScriptsTemplate` 三個人數欄寫死 17 寬；
  後置勾 `LFGListGroupDataDisplayRoleCount_Update`、每框一次把輸出／治療 `SetWidth` 22／20（右往左的錨定鏈自己讓位）。
  **總量只能 +8 左右**：列寬 312、名稱最寬到 186、這組左緣 187，零餘裕。暴雪不讀這三個寬度、我們不碰 displayData（秘密值）。

## 第九輪（2026-09-22，兩個 Opus 平行；未實測）

- **按鈕主／次變體**（使用者定）：`Skin.Button`／`ThreeSliceButton`／`StretchButton` 的 `opts.variant`，預設 primary ＝ 平時 `T.AccentButton()`（accent×0.30）＋邊 accent×0.60、滑過 `T.AccentHover()`＋邊全亮、停用退回 `fill`＋黑邊；secondary ＝原樣。
  **對比保護**：`k = min(1, T.buttonTextLum / lum)`，門檻 0.40（WCAG 算過，0.50 時十個職業不及格，武僧最差）。
  停用態：三個按鈕模板都沒有 DisabledTexture ⇒ 走 `TrackButtonHover` 第 6 參數 opts 掛 `OnEnable/OnDisable`（與翻頁鈕共用 `InstallEnableScripts`）。
  零腳本特許按鈕走 `Engine.ScriptlessButton`：Highlight（ADD 模式）塗職業色 ×0.70、DisabledTexture `SetAlpha(1)`＋`SetColorTexture`（**白名單新增，只准 ScriptlessButton**）；UIPanelButtonTemplate 沒 DisabledTexture ⇒ 拍賣／專業／寶庫主按鈕**平時中性、只有滑過職業色**（寧可少「平時」一態，也不讓停用的「製作」看起來能按）。
  判準：成對時確認那顆 primary、取消／返回／拒絕／再見 secondary；一塊最多一顆 primary；平行選項整排 secondary。ESC 選單「返回遊戲」認不出（同池同模板，只剩 layoutIndex／文字可分）⇒ 整排 secondary。
  **2026-09-22 升格成全套組規則**：共用層 `W.CreateButton(…, "primary")` 用同一條公式（數字兩邊各寫一份，改要一起改），規則與判準見 [[project-miliui-button-variants]]。
- **冒險指南重做**：戰利品列沒上皮的推論根因＝套組多支插件登入就載入冒險指南，`EJ_LOOT_DATA_RECIEVED` → `EncounterJournal_LootUpdate` → `SetDataProvider` 在視窗沒開時就建列、早於 mixin 勾 ⇒ 新增 `EncounterJournal_LootUpdate` 全域後置勾唯讀補掃＋列登記進 `SetItemButtonQuality` 全域勾；
  `/mskin debug` 出現 `EncounterItem:Init (hook bypassed…)` 就證實。書頁深色化，**綜覽／技能／副本簡介三塊內文接不住（SimpleHTML 每次重設、PAPER_FRAME 色切換、Lore OnLoad 設暗棕）⇒ 用原本的 UI-EJ-JournalBG 做羊皮紙內嵌**。
  麵包屑：`NavBar_AddButton` 後置勾＋身分比對只處理冒險指南那條；下拉鈕 Normal/Pushed 用 `SetVertexColor(1,1,1,0)` 中和（它自己的 OnEnter 會 SetAlpha(1)，alpha 中和撐不住；已核准）。頁籤選中線走 `EncounterJournal_SetTab` 後置勾讀參數 tabType。
  擷圖「教學說明」後的青色小方塊不是冒險指南的東西（像視窗後面的單位框），待使用者 /framestack。

## 第十輪（2026-09-22，未實測）

- 冒險指南綜覽／技能／簡介**整頁深色、羊皮紙拿掉**：第九輪「接不住」重查後都接得住 —— SimpleHTML 只有 `EncounterJournal_SetBullets` 寫字、標題色只在 `EncounterJournal_UpdateButtonState` 設（三條呼叫路徑：XML `function=` 綁定的 OnShow ⇒ HookScript、`EncounterJournal_OnClick` 用 GetScript 呼叫 ⇒ HookScript OnClick、綜覽直呼全域）、`ToggleHeaders` 的 SetFontObject 會蓋色 ⇒ 也勾。**教訓：「接不住」要逐條列路徑，別整塊放棄。**
- **`useParentLevel` 的 sublevel 平手**：inset／info 跟視窗本體同 frame level，貼圖跨框按 sublevel 交錯，大家都在 −8 就被本體蓋掉（書頁一直是 fill 不是 fillInset、捲軸軌道像粗黑柱）⇒ 內嵌底墊到 −4（邊 −3）。其他視窗的 `Skin.Inset` 可能同病，待實機比對後決定要不要改原語。
- 成就列金光帶是 `Glow`（Lua 只動 texCoord／vertex color）；`Top/BottomTsunami1` 那四筆 Missing 是總結頁列（ComparisonPlayerTemplate）沒有那兩張的假警報。
- 實機報告已證實：戰利品列早於 mixin 勾建立（`EncounterItem:Init (hook bypassed…)`）。

## 第十一輪（2026-09-23，未實測）

- **天賦與法術書**（`Skins/PlayerSpells.lua`，key `playerspells`，原本 C 級、使用者點名要做）：只換框 —— 外框、底部分頁、天賦頁 `BottomBar`（1612x82，atlas 尺寸查 wago.tools UiTextureAtlasMember）換 footer 帶、法術書書頁（`TopBar`／`BookBG*`）換 `fillInset`、搜尋／下拉／翻頁、三個載入方案彈窗（提示皮）。
  天賦樹、專精美術、法術格、專精卡美術、英雄天賦、PvP 天賦一律不碰；套用變更／複製方案字串／啟用專精／彈窗按鈕零腳本。**這個視窗 hooksecurefunc 0 支、HookScript OnShow 0 支**。
  成熟同類實作在法術格勾 `SpellBookItemMixin:UpdateVisuals` 改字色 —— 我們不勾（字本來就是淺色 `SPELLBOOK_FONT_COLOR`）。
- `TabSystemOwnerMixin.SetTab` 後置勾升格成 `Engine.TabSystemOwnerHooks`（冪等；專業、天賦、法術書三個 owner 共用）。
- **探究／世界副本難度選擇**（`Skins/DelvesPicker.lua`，key `delvespicker`）：探究與世界副本（`TieredEntranceType.Lairs`）是同一個 `DelvesDifficultyPickerFrame`。使用者要**保留場景底圖**（那是 `DelveBackgroundWidgetContainer`，BACKGROUND strata 的 UIWidget）⇒ 外框只畫 1px 職業色邊不畫底；兩個 UIWidget 容器與挑戰詞綴 trait 樹整棵不碰。
- 第十二輪（同日開工）：公會／行事曆／巨集／訓練師／交易／觀察／插槽／催化器／拾取／探究隨從／塑形／顧客訂單／玩家選擇，四個 Opus 平行；共用檔（TOC／DB／語系／設定頁／STYLE）改由主控合併時統一加，代理只新增 `Skins/*.lua`。

## 第十二＋十三輪（2026-09-23，未實測）

- 使用者定規則：做法照抄 EllesmereUI、樣式套我們的，見 [[feedback-skin-copy-ellesmereui]]。新增 20 份配方（清單在 STYLE.md 摘要與 ⑦）。
- **代理從 EllesmereUI 查出、我們照做的 taint 雷**：公會名冊列寬讀回污染（改註記／階級 FORBIDDEN）；`ColumnDisplay` 連 HookScript 都不行；
  就位確認的 OnShow 緊接著用秘密的發起人名字（`UnitIsUnit`／`SetPortraitTexture` 是 AllowedWhenUntainted）⇒ 改聽 `READY_CHECK` 延一幀；
  戰利品擲骰視窗從插件 `Hide()` 會讓 OnHide 在髒執行裡寫清單資料 ⇒ 改解 `LOOT_HISTORY_GO_TO_ENCOUNTER` ＋ secure snippet 關窗。
- lint：`skin-lint: readycheck-allowlist` 只在 `Skins/ReadyCheck.lua` 有效。
- 代理 API 額度中斷後 `SendMessage` 續跑可行，但**原本的 isolation worktree 會被清掉**，續跑的代理改在主控 worktree 直接 commit —— 共用檔要等全部回來再加，避免互踩。
- 待補進 STYLE ③ 的規則文字：訓練師 `selectedTex:IsShown()` 讀取例外、`PassBorderColor` 來源擴充、vertex alpha 中和動畫區域。
- 下一步候選：住宅總覽（只做 chrome，key `housing`）；Mapster／HandyNotes 的地圖按鈕走 ThirdParty。

## 還沒實機確認的

三條驗收線：`/console taintLog 2` 操作後 taint.log 零 blocked、**戰鬥中按 C 開得了角色面板**
（[[project-charframe-taint]] 的壓力測試）、首領戰中不報錯。
外觀面：`CharacterFrame:IsProtected()` 若為真整份會被跳過（變透明視窗，看 /mskin debug）；
Inset `useParentLevel` 時 overlay level−1 壓不壓得住；GossipFrame 換主題會不會重設 alpha；
分頁選中／未選中文字位移 5px（暴雪 SetPoint 的，改不了）在平面皮上會不會跳；
SetNormalFontObject 會不會觸發「吃掉最後一個字」；捲軸箭頭染灰後看不看得清；分頁相連那一邊的邊線。

## 還沒做

- `MiliUI/Options/Roster.lua` 插件總覽名冊沒登記這支（當時使用者正在改那個檔）。
- 側邊欄分頁的選中底色、成就列／分類列／篩選下拉、Primitives 的 CheckBox/Row/Icon/StatusBar 零覆蓋。
- 技能 `miliui-skin-blizzard` 等 PoC 過了再寫。
- 範圍分級：A 郵件／任務／收藏／冒險指南／拍賣／專業／行事曆…；B 角色面板／LFG／世界地圖／ESC／Settings；
  **C 不碰**：法術書天賦的**內容**（框第十一輪做了）、快捷列、單位框、名條、團隊框、編輯模式、StaticPopup、UnitPopup、商城、聊天輸入框。
