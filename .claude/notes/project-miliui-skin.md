---
name: project-miliui-skin
description: 米利的介面外觀 MiliUI_Skin —— 暴雪原生視窗換成設定視窗皮的 PoC（對話／角色面板／成就）；只重畫不重排的契約、驗收時抓到的三個坑、待實機驗證清單
metadata:
  type: project
---

**2026-09-20 建立；PoC 三視窗已通過實機 taint 驗收；第二輪（六個視窗）實機看過、taint.log 零 blocked；第三輪打磨（2026-09-20 晚）已合併、尚未實測。** `AddOns/MiliUI_Skin/`，TOC 是
`## DefaultState: disabled`（PoC 期間 push 也不會讓整包玩家預設吃到），`/mskin` 開設定、
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
  **C 不碰**：法術書天賦、快捷列、單位框、名條、團隊框、編輯模式、StaticPopup、UnitPopup、商城、聊天輸入框。
