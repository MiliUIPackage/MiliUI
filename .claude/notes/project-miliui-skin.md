---
name: project-miliui-skin
description: 米利的介面外觀 MiliUI_Skin —— 暴雪原生視窗換成設定視窗皮（47 份配方＋6 支第三方、2026-09-24 起預設啟用）；只重畫不重排的契約與 lint 現況、各輪抓到的坑、仍開著的待辦與待驗證
metadata: 
  node_type: memory
  type: project
  originSessionId: 3d3da2d2-d8a9-4944-8afe-aebf91167c1f
  modified: 2026-09-21T03:47:31.585Z
---

**2026-09-20 建立**，`AddOns/MiliUI_Skin/`：`Core/{Engine,Primitives,Tokens,External,DB,Init}.lua`、`Skins/*.lua` **47 份**、
`ThirdParty/{Postal,Auctionator,PremadeGroupsFilter,RaiderIO,Mapster,AppearanceTooltip}.lua`（AppearanceTooltip 的模型預覽框 2026-10-18 加，`Adopt(tip, { keepScale = true })`，未實機）。TOC **預設啟用**（2026-09-24 `7aef1b308` 拿掉
`## DefaultState: disabled`；⚠ 那個指令只影響從沒見過這支插件的角色，之前被預設關掉的人要自己去插件清單打開）。
`/mskin` 開設定、`/mskin debug` 印每份配方的狀態＋找不到的區域＋三張保護框清單＋ `RegionBackdrop` 退回清單；
`MiliUI_Skin_DB.lastReport` 登出時存同一份（400 行上限，直接讀 WTF 不用等使用者貼）。
規範全文在 `AddOns/MiliUI_Skin/STYLE.md`（① 三套皮判準／② Tokens／③ 契約／④ 元件規格／⑤ 模板配方表／⑥ 新增視窗 checklist／⑦ 範圍分級）。
⚠ **STYLE ⑤ 配方表的「實測狀態」欄從 09-20 之後沒再維護**（八十幾個「未實測」），實測紀錄要看 git log（下面「實機狀態」）。

## 核心：只重畫、不重排

傳統 skin 做法（遞迴清貼圖＋在暴雪框寫欄位＋SetPoint 重排）在 12.1 整條死路。
這裡是把 [[project-miliui-tooltip]] 的 overlay 架構推廣：
- 中和暴雪美術**一律 `SetAlpha(0)`**（alpha 與 atlas 獨立，暴雪重設 atlas 也不會打回來）。
  ⚠ **但擋不住對方的 `SetVertexColor(r,g,b,1)`**：第四個參數就是貼圖的 alpha、跟 `SetAlpha` 同一個值
  （2026-09-24 實機 `77339ea55`，拍賣插件的品質框每次 SetItemInfo 都打回不透明）⇒ 對方會 SetVertexColor 的區域，中和要放在它更新之後重下（reapply）。
- 外觀畫在自建 overlay（純 Frame＋1 底＋4 邊貼圖，level＝目標−1，SetAllPoints）；第六輪起 Panel／Inset／StatusBar 的底改成
  `Engine.RegionBackdrop` 直接 `CreateTexture` 在目標框上（見 [[wow-blizzard-window-skin-strategies]]），四種情況自動退回子框。
- 狀態放弱鍵 side table，暴雪物件零欄位寫入；不讀暴雪物件的文字／尺寸／錨點（讀取例外表在 STYLE ③）。
- 內容底材（羊皮紙、模型場景、地圖）保留只 skin chrome —— 但不是鐵律：要換就得連同上面所有文字顏色一起接管（成就、冒險指南、信紙都換了）。
- 視窗皮＝設定視窗皮（0.115 不透明＋黑邊），依 [[project-miliui-hud-skin]]；彈窗／ESC 選單／右鍵選單＝提示皮（`T.tipFill`＋職業色邊，只有最外圈）；職業色只給選中與主按鈕。
- Tokens 在 `Core/Tokens.lua`，**還沒升格進共用層**（[[project-miliui-widgets-vendor]]，待辦）。

## 契約與 lint 現況（`.claude/scripts/check_skin.py`，接在 check-all）

掃 `Core/Primitives.lua`＋`Core/External.lua`＋`Skins/*.lua`＋`ThirdParty/*.lua`；**`Core/Engine.lua` 不掃**（唯一可以對自己 overlay 做定位類呼叫的地方）。
- lint 真的擋的：`Hide/Show/SetShown/SetParent/ClearAllPoints/SetPoint/SetSize/SetWidth/SetHeight/SetScale/SetScript/SetFrameLevel/SetFrameStrata/EnableMouse/SetAtlas/SetTexture(nil)`、
  四張狀態貼圖的 setter（`SetNormal/Pushed/Highlight/CheckedTexture`）、`SetStatusBarTexture`（只准 `Engine.BarTexture`）、`SetStatusBarColor`、
  `GetVertexColor`（只准 `Engine.PassBorderColor`）、`SetChecked`、`SetDesaturated`（只准 `Engine.Desaturate`）、`IsEnabled`（只准 `TrackButtonHover`）、
  `Lock/UnlockHighlight/SetHighlightLocked`、`SetEnabled/Enable/Disable`、`SetDisabledFontObject/SetHighlightFontObject`、`AddAcquiredFrameCallback`、
  `CreateTexture`（只准 `Engine.RegionBackdrop`）、`PanelTemplates_*(`、`ShowUIPanel/HideUIPanel`、`StripTextures`、`BackdropTemplate`、`securecall`、`seterrorhandler`。
- **lint 沒擋、只靠 STYLE ③ 與 review 的**：`SetTextColor`（只准非按鈕 FontString／EditBox／SimpleHTML）、`SetColorTexture`（只准 C 端自己顯隱的 Highlight／Pushed／Checked／DisabledChecked／Disabled 貼圖）、
  `SetVertexColor`、`SetAlpha`、`SetTexCoord`、`SetDisabledTexture`（`Engine.ScriptlessButton` 補一張）、`RemoveMaskTexture`（`Engine.UnmaskIcon`）、`hooksecurefunc`／`HookScript`（**前置替換 `X.Init = function` 也沒規則抓**）。
- 放行：`-- skin-lint: own-frame`（任何檔、計數印出）；`-- skin-lint: readycheck-allowlist` **只在 `Skins/ReadyCheck.lua` 有效**。
  ⚠ `own-frame` 實際上也被拿來放行「對暴雪貼圖的重錨」（`Skins/Menu.lua` 的選單底，見下），名字跟用途已經不完全對得上。
- 另外檢查 Baganator 轉接層（[[project-baganator-miliui-skin]]）。
- 契約例外都收在 Engine、配方只能呼叫：`ShiftRoot`（重錨版面根框一次，專業技能書）、`Reanchor`（反接一小段錨定鏈，好友狀態列）、`Resize`（改小按鈕尺寸，公會／社群側邊分頁）、
  `UnmaskIcon`、`CenterTabText`；全部脫戰、`MiliUI_Skin_DB.relayout = false` 整批關。

## 四個陷阱（STYLE ③）

1. **overlay 不准用 BackdropTemplate、不准掛 OnShow/OnHide/OnSizeChanged/OnUpdate**：BackdropTemplate 自帶
   OnSizeChanged 的 Lua，暴雪改視窗大小時會跑在暴雪堆疊裡（[[wow-121-addon-code-in-secure-stack]] 同型）。
2. **overlay 不准 parent 到 LayoutFrame／ScrollBox／物件池容器**：它們走訪 children 讀 layoutIndex。`Engine.SafeParent` 爬到最近的非 layout 祖先。
   ⚠ **爬上去的祖先不會跟著目標一起隱藏** ⇒ 目標 Hide 了底還留在畫面上（2026-09-24 實機：拍賣賣出頁 `ItemSellFrame` 是 VerticalLayoutFrame、
   爬到 `AuctionHouseFrame`，拍賣插件把暴雪子頁藏掉後左上角留一塊）。目標是排版框而父框比它活得久的，`opts.parent` 指定一個「同顯同隱、又不是排版框」的兄弟。
3. **狀態優先交給引擎**：Highlight／Pushed 貼圖 `SetColorTexture` 讓 C 端自己畫 hover；分頁做不到只能 hook。
4. **池化列 `Engine.HookRows`**：只能掛在暴雪每次重用列時一定會跑的那支（`hooksecurefunc(XxxMixin, "Init", …)`）。
   ⚠ **mixin hook 只對之後建立的 frame 生效**（建立時複製函式）⇒ hook 要在登記／ADDON_LOADED 當下就裝、不過戰鬥閘；先建好的列用 `ScrollBox:ForEachFrame` 補掃。
   ⚠ `CreateFromMixins` 是同一條規則往上一層：勾父 mixin 追不上，要勾子 mixin；XML 載入期就建完的（好友分頁）哪層都追不上 ⇒ 另掛該視窗的全域刷新函式後面重讀狀態。
   hook 內分 apply（一次）／reapply（暴雪每次重設的：文字顏色、被打回的 alpha、**`SetTexture` 會把 texCoord 打回 0,1** 所以裁邊放 reapply）；不讀 elementData；出錯一次就停用該 hook。

## 保護框：顯式跳過、隱式照做（第五輪定案）

`IsProtected()` 回兩值 `(isProtected, isExplicit)`。**只有顯式才不掛 overlay**；隱式（身上掛了／錨了 secure 框，沿 parent／anchor 鏈往上傳染）照樣掛，
但戰鬥中不做也不標記、下次重試。只看第一個值的後果：18 顆 secure 玩具格把 `ToyBox → CollectionsJournal` 整條染成隱式，收藏視窗變透明（分頁／搜尋框不在鏈上所以有皮 —— 這個對比是指紋）。
⚠ **物品格這條路（`External.lua` 的 ItemButton）連顯式都不跳**（2026-09-23 `9be4a1f29`）：顯式跳過是為 overlay 子框定的，物品格只做貼圖層的事（alpha 中和、CreateTexture 建在格子上、全域後置勾），沒有子框；背包格模板是顯式保護，照規矩跳的話整顆不換皮。戰鬥中仍延到脫戰。

## 實作／驗收時抓到的坑（依主題）

**按鈕／文字**
- 捲軸拇指不能 `SetColorTexture`：`MinimalScrollBarThumbScriptsMixin:OnSizeChanged` 讀 `GetAtlasInfo(self.Middle:GetAtlas())`，換純色就每次捲動報錯。
- 按鈕文字 `SetTextColor` 撐不過一次滑過（文字顏色屬於狀態字型物件）⇒ `SetNormalFontObject(GameFontHighlight)` 三態交給引擎。
- Pushed 貼圖「中和」與「上色」二選一（SetColorTexture 的 a 與 SetAlpha 相乘）。`UIPanelButtonTemplate` 沒有 PushedTexture ⇒ 按下沒視覺。
- 按鈕 hover＝底提亮＋1px 職業色邊，走 `Engine.TrackButtonHover`（HookScript OnEnter/OnLeave）；停用的不給 hover。**確認彈窗／ESC 選單／通往受保護請求的按鈕（出價／直購／上架／製作／接單…）是「零按鈕 HookScript」特許**，走 `Engine.ScriptlessButton`：
  Highlight（ADD）塗職業色、DisabledTexture `SetColorTexture`；模板沒有 DisabledTexture 的就**替它 `SetDisabledTexture` 一張**（C 端狀態貼圖 setter，2026-09-22 `77e77573a`）⇒ 特許按鈕平時也職業色、停用時引擎自己蓋中性底。
- 主／次變體（第九輪，升格成全套組規則 [[project-miliui-button-variants]]）：對比保護 `k = min(1, T.buttonTextLum / lum)`、門檻 0.40；一塊最多一顆 primary；ESC 選單整排 secondary（同池同模板認不出「返回遊戲」）。
- 烤了顏色的 atlas（下拉箭頭、紅金 ＋／− 鈕、暴雪的勾）：乘法染不出中性灰，要先 `SetDesaturated(true)` 再染。
- 篩選下拉的文字接得住：`OnEnable/OnDisable` 是 frame script、`OnLoad` 只有設過 `baseFontObject` 才動文字；下拉這個 intrinsic 沒有 HighlightTexture。
- **SimpleHTML**：`SetTextColor("P", r,g,b)` 要帶文字類型，不帶管不到純文字；而且顏色在 `SetText` 那一刻才烘進去 ⇒ 換色後用暴雪剛寫的同一段文字再 SetText 一次（`Engine.HTMLTextColor`／`RepaintHTML`，2026-09-22 實機修的兩筆）。**「接不住」要逐條列路徑，別整塊放棄**（冒險指南三塊內文第九輪放棄、第十輪逐條接住）。
- ⚠ **`EditBox:GetRegions()` 會回傳輸入框自己的文字 FontString**（2026-10-09 實機 `844644678`，第七輪註解寫「掃不到」是錯的）：`Engine.RecolorRegions(textDim)` 掃標籤時把玩家打的收件人／主旨一起染灰。不是陷阱 4，是「掃 region 的函式會撈到 EditBox 內文」這條。
  - ⚠ **染上去就補不回來**（2026-10-18 實機）：2026-10-09 的「掃完再 `EditBox:SetTextColor(text)`」沒有用，收件人名字照樣整串灰 —— 那條 FontString 自己的顏色已被蓋掉，EditBox 層的 setter 管不到它。正解是**一開始就不染到它**：`RecolorRegions(…, { fontObject = GameFontNormal })` 用字型物件篩（標籤 `GameFontNormal`、內文 `ChatFontNormal`，XML 本來就分開），內文一行不碰。`GetFontObject` 進了 STYLE.md ③ 的讀取例外表（身分查詢，問不到就跳過不染）。
- 信件內文自帶的 `|cff…|r` 色碼接不住（GM／活動信可能出現深色字）。

**分頁**
- 分頁是唯一走 hook 的原語：`PanelTemplates_SelectTab/DeselectTab/SetDisabledTabState` 後置勾＋建立時讀一次 `LeftActive:IsShown()`。
- `Skin.TabGroup`：每顆 overlay 右緣錨到**下一顆分頁的左緣**、最後一顆不畫右邊線 ⇒ 共用一條線。`T.tabStyle="underline"`：未選字 `textDim`、選中＝`fillSelected`＋朝外 2px 職業色線；**分頁不用 hover 邊框**（共用邊線下永遠只亮三邊）。
- ⚠ **XML 的分頁重疊（`x=-16`）在遊戲裡從沒生效**：`PanelTemplates_SetNumTabs → AnchorTabs` 重錨成 `+3` ⇒ PanelTab 系 `pad` 一律 0（收藏、冒險指南都踩過；查 XML 要連 OnLoad 有沒有 `SetNumTabs` 一起看）。
- 契約例外 `Engine.CenterTabText`：暴雪在 Select/Deselect 把 `tab.Text` 設成 −3／+2，同三支後置勾裡重設 `CENTER 0,0`；成就的 `AchievementFrame_UpdateTabs` 在 OnClick 之後又設 −5／−3 ⇒ 另勾；新式 TabSystem 也要接到同步點（2026-09-24 `4d0d38639`）。
- TabSystem（好友、專業、天賦、法術書）：mixin 勾＋全域刷新函式後重讀；owner 的 `TabSystemOwnerMixin.SetTab` 後置勾收在 `Engine.TabSystemOwnerHooks`（冪等）。

**底、層級、選單**
- 進度條的邊不能畫前景（橫切文字）：畫在下層、矩形往外推 `pad`。
- `useParentLevel` 的 sublevel 平手：inset 跟視窗本體同 frame level，大家都在 −8 就被本體蓋掉 ⇒ 冒險指南內嵌底墊到 −4（邊 −3）；其他視窗的 `Skin.Inset` 可能同病，未逐一比對。
- **右鍵／下拉選單**（2026-09-24 實機 `8d82ea497`、`18d783f49`）：選單框池化、每次開都 `SetToDefaults`＋重設層級，列是 `menuFrame +20` ⇒ 我們建立時算一次的子框層級換手幾次就漂到列上面、整片底把內容蓋掉。**實心底不能是子框**，只能畫在選單框自己那張 `common-dropdown-bg` 貼圖上（compositor 每次 Generate 重新 Attach、關選單就收回，所以准重錨）；邊走子框、內部透明、層級每次重算 +4。
  而且**選單框沒有 parent** ⇒ `opts.parent` 一定要給選單框本身，交給 SafeParent 會退回 UIParent（MEDIUM）、邊跑到拍賣場後面。
- 收件匣列底的 parent 設成會被暴雪 Hide 的那顆信件鈕、錨點仍錨在列上 ⇒ 空列自動沒底，零讀取零 hook。商人每格底框同招（空格暴雪 Hide 的是 `ItemButton`）。
- 收藏清單的圖示方框改成**列自己的 ARTWORK 貼圖**而不是子框（2026-09-24 `04f432bd9`）：子框永遠在列的所有貼圖之上，會壓住 OVERLAY 層的我的最愛星號。
- 物品格：`IconBorder` alpha 0、自己畫 1px 方框、顏色轉交 `Engine.PassBorderColor`（`GetVertexColor` → `SetVertexColor`，不比較不算術）；全域 `SetItemButtonQuality/SetItemButtonTexture` 後置勾、`SetItemButtonBorder`（Baganator 呼叫格子方法）；商人視窗品質更新走方法 ⇒ 另勾 `MerchantFrame_UpdateMerchantInfo/_UpdateBuybackInfo`（第一行 `MerchantFrame:IsShown()`）。
- 大類按鈕圖示方形化：`Engine.UnmaskIcon`（`RemoveMaskTexture` 只准純裝飾遮罩、脫戰、失敗退回壓深環）；`T.categoryIconStyle="ring"` 切回。
- 勾選框：置中固定 18 小框＋`Engine.CheckedGlyph`（自帶 64×64 白勾黑框貼圖、染職業色，與共用層同一張；`T.checkStyle` 預設 `"outline"`、`"flat"` 無框）；`checkmark-minimal` 不是正方形、塞 setAllPoints 會拉扁。
- 保留暴雪 CVar 的做法：**任務／對話深色化走 `questTextContrast = 4`**（0~4），記住原值、關掉還原，還原邏輯放配方自己的事件框（關掉 quest 開關後 apply 不再跑）；⚠ 整支插件在插件清單被停用的話 CVar 會停在 4。

**不是 Skin 的鍋、但症狀像**（都修在 `MiliUI/Fix/`）
- 好友狀態下拉顯示「...」：暴雪寫死 51 寬，換字型就放不下 ⇒ `Blizzard_FriendsStatusDropdown.lua` 設 63。
- 好友名單底下「新增好友／傳送訊息」有時失去底、清單壓在按鈕後面：`RaidFrame_Update` 在團隊中無條件 `ButtonFrameTemplate_HideButtonBar(FriendsFrame)` ⇒ `Blizzard_FriendsButtonBar.lua` 在它之後、非團隊頁就放回來。
- 團隊列表職責人數兩位數「…」：`RoleCountNoScriptsTemplate` 寫死 17 寬 ⇒ `Blizzard_LFGListRoleCountWidth.lua`（總量只能 +8）。

## 一律不碰／撤掉的（理由見 STYLE ⑦ C 級與 [[wow-blizzard-window-skin-strategies]]）

通貨清單的列（第六輪撤掉 5 支 mixin 勾 —— 跟戰隊通貨轉移同一條執行流）；公會名冊列寬；`ColumnDisplay`（連 HookScript 都不行）；
拍賣結果清單的列（唯一出口 `TableBuilderMixin:AddRow` 跟出價／直購同流）；預組隊伍的 per-result 資料；就位確認以外的 LFG 彈窗；
secure 格子（玩具／傳家寶／技能鈕只裁圖示）；天賦樹與法術格內容；`ProfessionsRankBar`（不是 StatusBar）；征服條（每次 SetAtlas）。
照 EllesmereUI 查出的 taint 雷（[[feedback-skin-copy-ellesmereui]]）：就位確認 OnShow 緊接著用秘密的發起人名字 ⇒ 改聽 `READY_CHECK` 延一幀；
戰利品擲骰視窗從插件 `Hide()` 會讓 OnHide 在髒執行裡寫清單資料 ⇒ 功能放 `MiliUI_QoL/Modules/GroupLootHistory_AutoClose.lua`（secure snippet 關窗）。

## 第三方（伴隨元件）

**一律住 `ThirdParty/`、一支一檔**，TOC 排在所有 `Skins\` 之後；`Engine.AddCompanion(hostKey, {event|atLogin, addonKey, apply})`、額外分頁 `Engine.AddCompanionTabs`
（必須跟暴雪分頁**同一次**交給 `Skin.TabGroup`：接縫錨點只在建立時定一次）。零 hook、不呼叫對方函式、只照全域名字拿框；開關 `db.thirdparty[addonKey]` 跟 host 開關是「而且」。
對方自建的 tooltip 走 `MiliUITip_API.Adopt(tip)`（MiliUI_Tooltip 提供）。**以後任何第三方換皮都放這裡，不要塞回 MiliUI_Tooltip 或本體 Enhance。**
Auctionator 是唯一掛了兩支 frame script 的（背包清單容器 OnSizeChanged、物品格 OnShow —— 它每次更新「全部 Release → SetItemInfo → SetShown」，OnShow 是唯一排在換圖示之後的掛點）。

## 平行開發的分工規則（多個代理同時做視窗時有效）

一個代理擁有 `Core/**`＋既有配方且不准改現有 API 簽章；其餘只新增 `Skins/*.lua`，缺的功能寫配方內 local 小函式標 `TODO(升格)`；
共用檔（TOC／DB `windows`／Tab_General／Locales／STYLE 表尾）由主控合併時統一加。代理額度中斷後 `SendMessage` 續跑可行，但原本的 isolation worktree 會被清掉。
⚠ 選用參數：每支原語開頭 `opts = opts or {}`（`Skin.TabSystemAll(x)` 沒傳 opts 當場報錯過），驗收時逐一對照呼叫端與簽章。

## 實機狀態（2026-10-14 依 git log 核對）

- **taint 線**：PoC（09-20）與第二輪（09-20）各一次 `taint.log` 紀錄：0 blocked、點名 MiliUI_Skin 的只有 slash 全域與 UISpecialFrames；戰鬥中按 C 開角色面板正常。
  ⇒ 「alpha 中和＋純貼圖 overlay＋side table＋hooksecurefunc 後置勾」在 12.1 是實證安全的。
  **第三輪之後（45 份新配方、`RegionBackdrop`、ShiftRoot／Reanchor／Resize 三個重排例外）沒有任何 taint.log 紀錄** —— 要補一次 `/console taintLog 2` 走一輪拍賣／專業／通貨轉移。
- **外觀線**：09-24～25 使用者依實機擷圖逐項回報、三十幾筆 fix（公會與社群、宏偉寶庫、就位確認、交易、PvP、收藏、插件列表、右鍵選單、Auctionator 四頁、好友、信箱、世界地圖／任務日誌側邊分頁、戰利品視窗），
  10-06 設定面板分頁、10-09 寄信頁 ⇒ 第十二／十三輪的視窗絕大多數已經實機看過。沒有回報紀錄的：巨集、訓練師、行事曆、觀察、插槽、催化器、探究隨從、塑形、顧客訂單、玩家選擇、天賦／法術書、探究難度、BNToast、拾取記錄／通知。
- 舊「還沒實機確認」清單的下落：`CharacterFrame:IsProtected()` 整份跳過 → 第五輪改成只跳顯式；Inset `useParentLevel` → 第六輪改建在框上、第十輪 sublevel 平手只修了冒險指南；
  分頁文字位移 → `CenterTabText`（實機看過）；捲軸箭頭染灰 → 第七輪改線條圖記；分頁相連邊線 → `TabGroup` 共用線（實機「好很多」）；
  `SetNormalFontObject` 吃掉最後一個字、GossipFrame 換主題重設 alpha —— 三週沒人回報，但也沒人特地看。

## 仍開著的待辦

- `MiliUI/Options/Roster.lua` 插件總覽名冊**還是沒登記 MiliUI_Skin**（2026-10-14 核對）。
- `MiliUI_Merchant` 的齒輪鈕／補白格／已收藏勾是匿名框，伴隨元件碰不到（要在那支給全域名，[[project-miliui-merchant]]）。
- `Core/Tokens.lua` 升格共用層。
- STYLE ③ 待補的規則文字（STYLE 檔頭有列）：訓練師 `selectedTex:IsShown()` 讀取例外、`PassBorderColor` 來源擴充、vertex alpha 中和動畫區域。
- 聲望分類列／插件列表分類列的 ＋／−（展開狀態沒有零讀取來源）；插件列表三態勾分不出「部分啟用」。
- 下一步候選：住宅總覽（只做 chrome）；HandyNotes 地圖按鈕刻意不做（整顆被不透明圖示蓋滿）。
- 技能 `miliui-skin-blizzard` 還沒寫（`.claude/skills/` 沒有 skin 相關技能）。
