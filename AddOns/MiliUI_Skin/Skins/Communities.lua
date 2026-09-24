------------------------------------------------------------
-- 配方：公會與社群（`CommunitiesFrame`，隨需載入 `Blizzard_Communities`）
--
-- ⚠⚠ 這個視窗裡有**公會聊天**與**公會名冊**，兩條都是 taint 的重災區：
--   * 名冊的列在同一個 pass 裡讀回名冊寬度 ⇒ 被插件寫過的值一讀回就整個 session 帶 taint，
--     改註記／改階級／密語被 ADDON_ACTION_FORBIDDEN，列提示還會在秘密欄位上炸。
--   * 聊天輸入框：開框／送出的執行流裡**不能有插件的 Lua**
--     （`.claude/notes/wow-121-chat-reply-secret-taint.md`）。
--   範圍、掛點與「哪裡不碰」照成熟同類實作的公會視窗那一段搬過來（第十三輪使用者指示），
--   外觀換成本包的 Tokens／原語；它用到契約禁止的動作時改成白名單內的等價做法，
--   做不到的就少做那一塊（見最下面「照抄不了的地方」）。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source；路徑省略 `Blizzard_Communities/`）：
--   CommunitiesFrame.xml:304   `CommunitiesFrame` ← `ButtonFrameTemplateMinimizable`（toplevel）
--     :310  `PortraitOverlay`（frameLevel 300，公會徽章／社群頭像；Lua 只 Show/Hide 與換材質，
--            CommunitiesFrame.lua:1295-1310、:1676、:1700）
--     :355  `MaximizeMinimizeFrame`（MaximizeMinimizeButtonFrameTemplate）
--     :363  `CommunitiesList`（全域 `CommunitiesFrameCommunitiesList`，useParentLevel）
--     :369,383,409,419  右側四顆 `ChatTab`／`RosterTab`／`GuildBenefitsTab`／`GuildInfoTab`
--            ← `CommunitiesFrameTabTemplate`（CommunitiesTabs.xml:5-44：一張**無名**的
--            BORDER 貼圖 `SpellBook-SkillLineTab`、`Icon`、`IconOverlay`、空的 NormalTexture、
--            Highlight `ButtonHilight-Square` ADD、Checked `CheckButtonHilight` ADD）。
--            ⚠ 選中態是 **CheckButton 的 Checked**：`UpdateCommunitiesTabs` 逐顆 `SetChecked`
--            （CommunitiesFrame.lua:1070-1081）⇒ 顯示與否全由 C 端決定，換長相就好，零 hook。
--     :429  `StreamDropdown`（StreamDropdownTemplate ← WowStyle1DropdownTemplate，CommunitiesStreams.xml:304）
--     :434,439  `GuildMemberListDropdown`／`CommunityMemberListDropdown`（WowStyle1DropdownTemplate 系，
--               CommunitiesMemberList.xml:375,408,409）
--     :444  `CommunitiesListDropdown`（最小化時取代左側清單，CommunitiesList.xml:264）
--     :458  `MemberList`（CommunitiesMemberListFrameTemplate，CommunitiesMemberList.xml:244）
--     :475,486  `GuildFinderFrame`／`CommunityFinderFrame`（ClubFinder.xml:1172）
--     :492  `Chat`（CommunitiesChatTemplate，CommunitiesChatFrame.xml:5）
--     :498  `ChatEditBox`（CommunitiesChatEditBoxTemplate，CommunitiesChatFrame.xml:58-94：
--            BACKGROUND 三張 `Left`／`Right`／**`Mid`**，錨點在程式裡設：CommunitiesFrame.lua:1669-1671、:1693-1695）
--     :502,508,521  `InvitationFrame`／`ClubFinderInvitationFrame`／`TicketFrame`
--     :527,533  `GuildBenefitsFrame`／`GuildDetailsFrame`（全域 `CommunitiesFrameGuildDetailsFrame`；
--               兩個模板在同檔 :5-107、:162-231，外圍九張 `InsetBorder*` 是 OVERLAY 雕花）
--     :545,551,557  `EditStreamDialog`／`NotificationSettingsDialog`／`RecruitmentDialog`
--     :562  `AddToChatButton`（WowStyle1ArrowDropdownTemplate，CommunitiesStreams.xml:289；
--            Blizzard_Menu/Mainline/MenuTemplates.lua:41-49 對 `Arrow` 只 `SetAtlas` ⇒ alpha 撐得住）
--     :567  `InviteButton`（UIPanelDynamicResizeButtonTemplate ← UIPanelButtonTemplate）
--     :583  `CommunitiesControlFrame`（:241-302：`CommunitiesSettingsButton`、`GuildControlButton`、
--            `GuildRecruitmentButton`）
--     :589  `GuildLogButton`
--     :598  `GuildMemberDetailFrame`（CommunitiesGuildMemberDetailFrameTemplate，GuildRoster.xml:5）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:684-701
--     `ButtonFrameTemplate` 的 `Inset`（全域 `CommunitiesFrameInset`）是 **useParentLevel**；
--     CommunitiesFrame.lua:693-695 在尋找公會／社群模式對它 Hide/Show。
--   CommunitiesList.xml:5-129  `CommunitiesListEntryTemplate`（mixin `CommunitiesListEntryMixin`，
--     `Background`／`Selection`／`NewCommunityFlash` 與 Highlight 都是 **80 高**、比 68 高的列溢出）
--   CommunitiesList.xml:131-262  清單本體：`Bg`、`TopFiligree`、`BottomFiligree`（ARTWORK）、
--     `FilligreeOverlay`（frameLevel 100 的純美術框）、`InsetFrame`（**frameLevel 200**、Bg 在 OnLoad 就 Hide）
--   CommunitiesList.lua:264-273  `SetElementInitializer(..., button:Init(elementData))`
--     ⇒ **每次重用都跑 `Init`**；`SetGuildFinder`／`SetFindCommunity`／`SetAddCommunity` 都是從 Init 分派的
--     （:525-531）⇒ 勾 `CommunitiesListEntryMixin.Init` 一支就接得住全部。
--     Init 每次對 `Background`／`Selection` `SetTexture`／`SetAtlas`（:455-463、:493-501、:590-593、:676-679）、
--     對 `IconRing` `SetShown`／`SetAtlas`（:521-522），**沒有一行 SetAlpha** ⇒ alpha 中和撐得住。
--   CommunitiesMemberList.xml:244-373  名冊：`MemberCount`（BORDER 字）、`ShowOfflineButton`（UICheckButtonTemplate）、
--     `ColumnDisplay`、`ScrollBox`、`ScrollBar`（MinimalScrollBar ＋ 一張 `Background` 大理石）、
--     `InsetFrame`（OnLoad `Bg:Hide()`＋`SetFrameLevel(100)` ⇒ **疊在列上面**的一圈框）
--   CommunitiesMemberList.lua:1339  列 `self:SetWidth(self:GetMemberList():GetWidth())` ← 這一支就是雷 1
--   CommunitiesChatFrame.xml:39-49  `Chat.InsetFrame`（Bg 在 OnLoad Hide，跟訊息框同層）
--   GuildRoster.lua:8  `RankDropdown:SetWidth(169 - RankLabel:GetWidth())`
--   GuildPerks.xml:4-113、GuildPerks.lua:4-14  福利列（mixin `CommunitiesGuildPerksButtonMixin`，Init 每次 `Icon:SetTexture`）
--   GuildRewards.xml:137-211、GuildRewards.lua:7-55  獎勵列（mixin `CommunitiesGuildRewardsButtonMixin`；
--     Name 的字型物件、Icon 去飽和／紅色、`DisabledBG`、`Lock` 全是「解鎖了沒」的資訊）
--   GuildRewards.xml:68-135  `CommunitiesGuildProgressBarTemplate`（聲望條：Left/Right 18x18 貼底、
--     `BG`／`Progress` 14 高、垂直中心在底往上 9 ⇒ 槽是底往上 2～16；GuildRewards.lua:235-249 只改 Progress 寬度）
--   GuildInfo.xml:60  `CommunitiesGuildInfoFrameTemplate`；:385-445 `CommunitiesGuildLogFrame`
--     （TranslucentFrameTemplate、兩顆同名的 `$parentCloseButton`：一顆 × 一顆「關閉」文字鈕）
--   GuildNews.xml:255  新聞頁；:385-437 `CommunitiesGuildNewsFiltersFrame`（七顆 CommunitiesGuildNewsCheckButtonTemplate，
--     :9-28 是標準勾選框材質）
--   CommunitiesStreams.xml:82-178  `CommunitiesEditStreamDialogTemplate`（`BG` ← DialogBorderDarkTemplate）
--   CommunitiesStreams.xml:179-288 `CommunitiesNotificationSettingsDialogTemplate`（`BG` 貼圖、`Selector` ←
--     SelectionFrameTemplate：Blizzard_SharedXML/SecureUIPanelTemplates.xml:97，NineSlice 片直接掛在它身上
--     ＋ `OkayButton`／`CancelButton`）
--   CommunitiesSettings.xml:5-369  `CommunitiesSettingsDialog`（全域、parent UIParent）
--   ClubFinder.xml:16,801,807,813  三種篩選下拉都 ← WowStyle1DropdownTemplate；:819-828 `ClubFinderCheckboxTemplate`
--     （標準勾選框材質）；:847-876 卡片翻頁鈕；:1043-1171 `ClubFinderOptionsTemplate`；
--     :247 起 `ClubsRecruitmentDialogTemplate`；:556 起 `ClubFinderRequestToJoinTemplate`
--   CommunitiesInvitationFrame.xml:5-130  邀請／門票頁（Accept／Decline、`InsetFrame`）
--   Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:984-1042  `TranslucentFrameTemplate`（`Bg` ＋ 八片 Dialog-Border）
--
------------------------------------------------------------
-- ## 做了什麼／刻意不碰什麼
--
-- 做了（依成熟同類實作的範圍）：
--   * 外框：標題帶、關閉鈕、最大化最小化（＋／− 圖記）、**公會徽章頭像整塊收掉**（`PortraitOverlay` alpha 0，
--     同它的做法）、主內嵌框 `Inset`（fillInset，useParentLevel ⇒ 墊 sublevel −4）。
--   * 左側社群清單：藍色選單美術（Bg／兩條 Filigree／`FilligreeOverlay`）中和、清單底 fillInset、
--     框線改畫在它自己那個 level 200 的 `InsetFrame` 上（**只有邊、底透明**，不然會蓋住列）、捲軸；
--     **池化列**（`CommunitiesListEntryMixin.Init` 後置勾）：卡片底 `Background` 與頭像金環 `IconRing` 中和、
--     改成上下各縮 2 的平面卡片（fill ＋ 黑邊）、滑過自己畫；選中態讀 `Selection:IsShown()` 走 `Skin.Row` 的標準選中（`Selection` 本身中和，2026-09-24）。
--   * 右側四顆側邊分頁與尋找公會的兩顆：只留圖示（裁邊）＋一圈方框；滑過＝引擎的 Highlight 白 8%、
--     選中＝引擎的 Checked 換成右緣職業色直條（`Engine.CheckedTextureFile`）（C 端依 `SetChecked` 顯示，**零 hook**）。
--   * 五顆下拉、「加入聊天」小箭頭鈕（中和箭頭、畫 ⌄、字改白）。
--   * 聊天：`Chat.InsetFrame` 只畫邊、聊天捲軸；**輸入框只中和三張美術 ＋ 建一張底與四條邊**（見下）。
--   * 名冊：`InsetFrame` 只畫邊、捲軸（**零腳本版**）、「在線人數」字改白、「顯示離線」勾選框。
--   * 底部按鈕列（邀請、社群設定、公會控制、公會招募、查看紀錄）與所有對話框裡的按鈕：**全部零腳本**。
--   * 公會福利頁：九張 InsetBorder 雕花、福利／獎勵兩欄的底圖中和、標題白字、兩條捲軸、
--     **福利列與獎勵列**（mixin `Init` 後置勾：平面卡片 ＋ 圖示方框；獎勵的鎖／灰字／紅圖示照留）、
--     公會聲望條（槽換 fillInset ＋ 黑邊，填充色不碰）。
--   * 公會資訊頁：雕花與兩欄底圖中和、標題白字、三條捲軸、兩條分隔髮絲線（固定幾何）。
--   * 尋找公會／社群：內嵌框、停用頁的內嵌框、搜尋框、搜尋鈕（零腳本）、三顆下拉、三顆職責勾選、
--     卡片翻頁鈕、社群卡片捲軸、申請加入的小視窗。
--   * 邀請／門票頁：內嵌框、接受／拒絕（零腳本）。
--   * 彈窗（提示皮：`T.tipFill` ＋ 1px 職業色邊）：成員詳情、建立／編輯頻道、通知設定、公會招募、
--     社群設定、公會紀錄、新聞篩選、申請加入 —— 外框、關閉鈕、按鈕（零腳本）、輸入框、勾選框、下拉、捲軸、
--     欄位標籤降成 `textDim`。
--
-- 刻意不碰（有理由的）：
--   * **名冊的列與名冊本身的尺寸／錨點**（雷 1）：列一顆都不碰、不 HookRows、不畫底；名冊框本身也不建任何貼圖。
--   * **`ColumnDisplay`（可排序欄位表頭）**（雷 2）：連 HookScript 都不行；成熟實作的重掃掛在
--     `hooksecurefunc(MemberList, "RefreshListDisplay")`＝寫暴雪框欄位，我們禁止；而它是 XML 載入期建的，
--     勾 mixin 表追不上 ⇒ 整塊不做。
--   * **聊天訊息框（ScrollingMessageFrame）內容**、`JumpToUnreadButton`（成熟實作也沒做）。
--   * 名冊捲軸與排序下拉不掛任何腳本：它們的狀態（捲軸箭頭 Enable/Disable）是在名冊刷新的執行流裡切的，
--     一支 `OnEnable` 的 HookScript 就會讓我們的 Lua 跑在那條流裡。
--   * 成員詳情的兩塊註記底（點下去就是改註記）、`RankDropdown` 只換長相不掛腳本（`noHover`）。
--   * 右上角語音耳機、行事曆鈕、`StreamDropdown` 上的未讀通知點（資訊）、公會福利頁的成就點數與說明鈕。
--   * `GuildControlUI`（公會控制）、`CommunitiesGuildTextEditFrame`（改公告／公會資訊）、申請者清單、
--     頭像選擇、`CommunitiesAddDialog`／`CommunitiesCreateCommunityDialog` —— 見最下面「沒做的視窗」。
--
------------------------------------------------------------
-- ## 聊天輸入框的做法（雷 3，使用者特別交代）
--
-- `ChatEditBox` 是這一份裡唯一在「開框／送出」路徑上的物件。對它只有兩件事，**都在套用當下做完**：
--   1. `Left`／`Right`／`Mid` 三張 BACKGROUND 貼圖 `SetAlpha(0)`（Lua 全檔沒有對它們 SetAlpha／換圖）；
--   2. `Engine.RegionBackdrop`：在它**自己身上**建一張底＋四條邊（不建子框、不寫欄位）。
-- **零 HookScript（OnEditFocusGained／OnEnterPressed／OnShow／OnHide 一支都沒有）、零 hooksecurefunc、
-- 零重排**（成熟實作在最小化時勾它的 SetPoint 往上抬 7，我們不做；錨點由暴雪在
-- `CommunitiesFrameMaximizeMinimizeButton_OnLoad` 那兩支裡照常重設，我們的底錨在它身上自然跟著走）。
-- ⇒ 玩家按 Enter 開框／送出的整條執行流裡，一行我們的 Lua 都沒有。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `CommunitiesFrame` 的 NineSlice／Bg／TopTileStreaks／PortraitContainer、`PortraitOverlay`（純美術框） | `SetAlpha(0)` |
-- | `CommunitiesFrame`、`Inset`、`CommunitiesList`、各 `InsetFrame`、`ChatEditBox`、聲望條、資訊頁、各彈窗 | `Engine.RegionBackdrop`（建在它們**自己身上**的 BACKGROUND 貼圖） |
-- | `TitleText`、`MemberCount`、各頁 `TitleText`、彈窗標題與欄位標籤 | `SetTextColor` |
-- | 關閉鈕、最大化最小化、翻頁鈕 | 狀態圖 `SetAlpha(0)`＋我們的圖記（`Skin.CloseButton`／`Skin.IconButton`） |
-- | 六顆側邊分頁 | 無名 BORDER 貼圖與 NormalTexture `SetAlpha(0)`、`Icon` 裁邊、Highlight／Checked `SetColorTexture`（**零腳本**） |
-- | 下拉 | `Background`／`Arrow` `SetAlpha(0)` ＋ ⌄ 圖記（名冊兩顆與階級下拉 `noHover` ＝零腳本） |
-- | 所有文字按鈕（含彈窗） | 美術 `SetAlpha(0)` ＋ `SetNormalFontObject` ＋ Highlight／Disabled 的 `SetColorTexture`（`Engine.ScriptlessButton`，**零 HookScript**） |
-- | 社群清單列 | `Background`／`IconRing`／`Selection` `SetAlpha(0)`、Highlight `SetAlpha(0)`、我們的子框 overlay |
-- | 福利列／獎勵列 | 美術 `SetAlpha(0)`（獎勵只中和 NormalTexture）、Highlight `SetColorTexture`、圖示裁邊、我們的子框 overlay |
-- | 捲軸 | `Track`／`Thumb` 三片與 `Background` `SetAlpha(0)`、我們的細條 overlay（名冊那一條零腳本） |
-- | 輸入框／多行輸入框／勾選框 | `Skin.EditBox`／`Skin.InputScroll`／`Skin.CheckBox` |
--
-- ### 讀了什麼
--
-- 只有結構：parentKey、全域名字、`GetChildren()`（認彈窗裡的捲軸、認公會紀錄的兩顆關閉鈕 ——
-- 有 `Left` 這個 parentKey 的是「關閉」文字鈕、沒有的是 ×，**不讀按鈕文字**）、`GetRegions()`（找無名美術）。
-- **不讀任何 club／member／stream 資料、不讀 elementData、不讀尺寸／錨點／文字。**
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `CommunitiesListEntryMixin.Init` | mixin 後置勾（`Engine.HookRows`，裝在 `hooks`） | 第一次：中和（含 `Selection`）＋建 overlay（`Skin.Row` ⇒ 列上 `HookScript("OnEnter"/"OnLeave")` 換我們自己的底色）；每次：讀 `Selection:IsShown()` → `Engine.SetSelected` |
-- | `CommunitiesGuildPerksButtonMixin.Init` | mixin 後置勾 | 第一次：中和＋建 overlay；每次：圖示裁邊 |
-- | `CommunitiesGuildRewardsButtonMixin.Init` | mixin 後置勾 | 同上 |
-- | 原語內建的 `HookScript("OnEnter"/"OnLeave")`（＋翻頁鈕的 `OnEnable`/`OnDisable`） | frame script 後掛 | **只對**關閉鈕、最大化最小化、清單兩顆下拉、「加入聊天」、清單捲軸／聊天捲軸／福利與資訊頁捲軸、彈窗的捲軸／勾選框／下拉、尋找公會的翻頁鈕與勾選框、「顯示離線」勾選框；內容只換我們自己 overlay 的顏色 |
--
-- **`hooksecurefunc` 在 `CommunitiesFrame` 或它任何子框的實例上：0 支。**
-- **`HookScript("OnShow"/"OnHide")` 在任何暴雪框上：0 支。**
-- **任何按鈕（文字按鈕）上的 `HookScript`：0 支**（全部零腳本）。
-- **`ChatEditBox`、`MemberList`、名冊的列、`ColumnDisplay`、名冊捲軸上的任何 hook：0 支。**
--
------------------------------------------------------------
-- ## 照抄不了的地方（成熟同類實作做了、我們沒照做）＋ 原因
--
--   1. 列卡片改成「對話框底圖 atlas、半透明」並在貼圖實例上勾 SetAtlas/SetTexture/SetAlpha 自我修復
--      ⇒ `SetAtlas` 與實例勾都禁止；改成中和 `Background` ＋ 我們自己的平面卡片（overlay 用 points 縮 2）。
--      選中與滑過的洗白也是把暴雪貼圖 `ClearAllPoints`/`SetPoint` 裁進卡片 ⇒ 禁止；
--      滑過改成自己畫（`Skin.Row` ownHover）、選中那張 80 高的 `Selection` 原本去飽和染色（溢出列 6 點），2026-09-24 改成中和、讀它的 IsShown 畫我們自己的選中態。
--   2. 側邊分頁的間距收緊 10、第一顆重錨貼齊視窗邊 ⇒ `ClearAllPoints`/`SetPoint` 禁止，不做。
--      依 `IsEnabled()` 做半透明 ⇒ 配方不准讀 IsEnabled、也不准對按鈕框 SetAlpha，不做（停用的分頁暴雪自己會去飽和圖示）。
--   3. 公會招募視窗重錨到視窗右側 ⇒ 重排，不做。彈窗輸入框的左內距 6（讀錨點再 `SetPoint`／`SetWidth`）⇒ 不做。
--   4. 串流下拉縮 0.9 並左移、名冊下拉縮 0.85 並下移 8、輸入框縮高 12、尋找公會搜尋框與搜尋鈕改尺寸並用
--      `SetPoint` 實例勾釘位置 ⇒ `SetScale`／`SetHeight`／`SetSize`／實例勾全禁止，不做。
--   5. 最小化時把輸入框抬高 7（勾它的 SetPoint）⇒ 禁止（而且就是雷 3），不做。
--   6. 「區帶」（標題下的第二條帶、底部帶、側欄洗色與分隔線）要在最小化時藏起來，它靠 max/min 兩顆鈕的
--      HookScript OnClick 切 ⇒ 簡報第 9 條「不做依最小化狀態切換的 Lua」；固定幾何的帶子在最小化時會橫在
--      錯的位置 ⇒ 不做。同樣的層次由我們的標題帶 ＋ 主內嵌框 ＋ 清單底色提供。
--   7. 名冊欄位表頭（`ColumnDisplay`）的重掃掛 `hooksecurefunc(ml, "RefreshListDisplay")` ⇒ 寫暴雪框欄位，禁止；
--      mixin 表追不上（XML 載入期建）⇒ 整塊不做（雷 2）。
--   8. 聲望條量 `GetTop`/`GetBottom` 決定槽的位置、`HookScript("OnShow")` 重試、把 `Progress` 換成白材質
--      ⇒ 讀尺寸與 OnShow 勾都禁止；改成從 XML 常數抄幾何（槽＝底往上 2～16），填充材質與顏色不碰。
--   9. 資訊頁那條水平分隔線的 y=−194 是它的常數；我們照抄（沒有量測），實機要看有沒有對到。
--  10. 按鈕字縮 1～2 級（`SetFont`）⇒ 不在白名單，不做；字型物件換成暴雪自己的白字那一級。
--  11. `GuildNewsButton_SetNews` 後置勾（藏新聞列的日期標頭）⇒ 12.1 live 已經沒有這支全域函式，
--      而 `CommunitiesGuildNewsButtonMixin:Init` 自己就 `header:Hide()`（GuildNews.lua:7-11）⇒ 不需要。
--  12. 公會紀錄視窗靠**讀按鈕文字**分辨兩顆同名的關閉鈕 ⇒ 改成讀結構（有沒有 `Left` 這個 parentKey）。
--  13. `StaticPopupSpecial_Show` 全域後置勾去接 `CommunitiesAddDialog`／`CommunitiesCreateCommunityDialog`
--      ⇒ 那兩個對話框的本體在 `Blizzard_CommunitiesSecure`（安全環境，本 repo 的原始碼鏡像裡查不到結構），
--      而那支全域函式是所有「特殊彈窗」共用的 ⇒ 不為兩個查不到結構的框在共用路徑上多掛一支，不做。
--  14. 它把彈窗上**所有** FontString 染白；我們只染標題與欄位標籤（標籤降成 textDim），
--      其餘文字的顏色多半是資訊（職業色名字、綠色社群名、灰色停用字）。
--  15. 它把「串流下拉」上的未讀通知點（`NotificationOverlay`）一起淡掉 ⇒ 那是資訊，保留。
--
-- ## 沒做的視窗
--   * `GuildControlUI`（`Blizzard_GuildControlUI`）：成熟實作也沒做；每一個控件都在寫公會權限／階級順序
--     （STYLE.md 的「設定面板的每一項控制項只做外框」），而且階級列是 Lua 動態建的 ⇒ 不值得。
--   * `CommunitiesGuildTextEditFrame`（改公告／公會資訊，按下接受就是寫公會資料）：成熟實作沒做，不做。
--   * `ApplicantList`（申請者清單，池化列 ＋ 接受／拒絕申請）、`CommunitiesAvatarPickerDialog`：成熟實作沒做，不做。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local TRANSPARENT = { 0, 0, 0, 0 }

------------------------------------------------------------
-- 小工具（跟 `Skins/PlayerSpells.lua` 同一組寫法）
------------------------------------------------------------
local function Sub(owner, key, label)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then
        return child
    end
    E.Missing(label)
    return nil
end

local function WithSub(owner, key, label, fn)
    local child = Sub(owner, key, label)
    if child then fn(child, label) end
    return child
end

-- 「有就做、沒有就靜默跳過」（依情境才有的框、模板間名字不一的美術）
local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

-- 只中和「真的存在」的 parentKey（`NeutralizeKeys` 找不到會記進 Missing，
-- 這裡的清單是跨模板的聯集，缺幾張是正常的）
local function NeutralizePresent(owner, keys, prefix)
    for _, k in ipairs(keys) do
        local r = Optional(owner, k)
        if r then E.Neutralize(r, prefix .. "." .. k) end
    end
end

local function TextColorKeys(owner, keys, color, prefix)
    for _, k in ipairs(keys) do
        local fs = Optional(owner, k)
        if fs then E.TextColor(fs, color, prefix .. "." .. k) end
    end
end

------------------------------------------------------------
-- 零腳本文字按鈕（STYLE.md ⑦「特許的第二種用法」）
--
-- 這個視窗的文字按鈕**全部**走這一支：邀請、移除、組隊邀請、接受／拒絕邀請、申請加入、
-- 公會控制、公會招募、社群設定、查看紀錄、對話框的確定／取消／刪除……
-- 簡報第 4 條：通往受保護／受限請求的一律零腳本；純導覽的拿不準 ⇒ 也零腳本。
--
-- 先建 overlay 再中和（`Engine.Overlay` 對顯式保護框回 nil，倒過來會做出隱形按鈕）。
-- 美術清單是三種模板的聯集：`UIPanelButtonTemplate`（Left/Right/Middle）、
-- `ThreeSliceButtonTemplate`（Center）、`UIMenuButtonStretchTemplate`（九片，SharedUIPanelTemplates.xml:745）。
-- TODO(升格): 第四份配方用到了（專業／拍賣場／天賦／這裡）—— 收成 `Skin.ScriptlessButton`。
------------------------------------------------------------
local BUTTON_ART = {
    "Left", "Right", "Middle", "Center",
    "TopLeft", "TopRight", "BottomLeft", "BottomRight",
    "TopMiddle", "MiddleLeft", "MiddleRight", "BottomMiddle", "MiddleMiddle",
}

local function ScriptlessButton(btn, key, variant, font)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end
    NeutralizePresent(btn, BUTTON_ART, key)
    E.ButtonFonts(btn, font or GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "secondary", key)   -- **不掛腳本**
    return ov
end

-- 一個容器上「有就做」的一排按鈕：{ key, variant, font }
local function ButtonsOn(host, list, prefix)
    for _, b in ipairs(list) do
        local btn = Optional(host, b[1])
        if btn then ScriptlessButton(btn, prefix .. "." .. b[1], b[2], b[3]) end
    end
end

------------------------------------------------------------
-- 捲軸
--
-- `ScrollBar` ＝ `Skin.ScrollBar` ＋ 把模板額外帶的那張 `Background`（大理石，
-- CommunitiesMemberList.xml:349、GuildPerks.xml:141、GuildNews.xml:363）一起中和。
--
-- `QuietScrollBar` ＝ **零腳本版**，只給名冊那一條用：
--   `Skin.ScrollBar` 會在拇指上掛 OnEnter/OnLeave、在上下箭頭上掛 OnEnable/OnDisable
--   （`Engine.TrackGlyph{ trackEnabled }`）。箭頭的啟用狀態是捲軸更新時切的，而名冊的捲軸更新
--   跑在名冊刷新的執行流裡（改註記／改階級之後的那一次）⇒ OnEnable 的 HookScript 會讓我們的 Lua
--   出現在那條流裡。成熟實作的註解明寫「在名冊刷新裡觸發的腳本 ⇒ ADDON_ACTION_FORBIDDEN」，
--   所以這一條只換長相、一支腳本都不掛：箭頭是靜態的 textDim 圖記（捲到頭不會變暗）、拇指沒有滑過提亮。
--   TODO(升格): `Skin.ScrollBar` 開一個 `opts.quiet`。
------------------------------------------------------------
local function ScrollBar(bar, key)
    if not bar then return end
    local bg = Optional(bar, "Background")
    if bg then E.Neutralize(bg, key .. ".Background") end
    Skin.ScrollBar(bar, key)
end

local THIN_POINTS = { { "TOP", "TOP", 0, 0 }, { "BOTTOM", "BOTTOM", 0, 0 } }

local function QuietScrollBar(bar, key)
    if not E.Usable(bar, key) then return end
    local bg = Optional(bar, "Background")
    if bg then E.Neutralize(bg, key .. ".Background") end

    local track = Sub(bar, "Track", key .. ".Track")
    if not track then return end
    E.NeutralizeKeys(track, { "Begin", "Middle", "End" }, key .. ".Track")
    local trackOv = E.Overlay(track, {
        key = key .. ".Track", noBorder = true, points = THIN_POINTS, width = T.scrollThumbSize,
    })
    E.Paint(trackOv, T.scrollTrack)

    local thumb = Optional(track, "Thumb")
    if thumb then
        E.NeutralizeKeys(thumb, { "Begin", "Middle", "End" }, key .. ".Thumb")
        local thumbOv = E.Overlay(thumb, {
            key = key .. ".Thumb", noBorder = true, points = THIN_POINTS, width = T.scrollThumbSize,
        })
        E.Paint(thumbOv, T.scrollThumb)
    end

    for _, side in ipairs({ "Back", "Forward" }) do
        local stepper = Optional(bar, side)
        if stepper then
            E.Neutralize(Optional(stepper, "Texture"), key .. "." .. side .. ".Texture")
            local stepOv = E.Overlay(stepper, {
                key = key .. "." .. side,
                noBorder = true,
                glyph = {
                    kind = (side == "Back") and "chevronUp" or "chevronDown",
                    size = T.glyphSize, thickness = 1, color = T.textDim,
                },
            })
            E.Paint(stepOv, TRANSPARENT)
        end
    end
end

-- 彈窗裡的捲軸：結構走訪（`GetChildren` ＋「有 `Track` 也有 `Back`」＝ MinimalScrollBar 的形狀）。
-- 深度上限 5，只用在彈窗上（**絕對不對名冊或主視窗用**）。
local function ScrollBarsIn(root, key, depth)
    depth = depth or 0
    if depth > 5 or type(root) ~= "table" or type(root.GetChildren) ~= "function" then return end
    local ok, kids = pcall(function() return { root:GetChildren() } end)
    if not ok then return end
    for i, child in ipairs(kids) do
        if Optional(child, "Track") and Optional(child, "Back") then
            ScrollBar(child, key .. ".ScrollBar" .. depth .. "_" .. i)
        else
            ScrollBarsIn(child, key, depth + 1)
        end
    end
end

------------------------------------------------------------
-- 內嵌框的三種畫法
--
-- MainInset：`ButtonFrameTemplate` 的 `Inset` 是 **useParentLevel**（跟視窗同一層），
--   region 跨框按 sublevel 交錯 ⇒ 預設 −8 會跟視窗自己的面板底平手（STYLE.md 第十輪摘要②），
--   墊到 −4／−3。
-- BorderInset：`InsetFrame` 被暴雪放在**列的上面**（名冊 SetFrameLevel(100)、社群清單 frameLevel 200）
--   或跟內容同層（聊天），而且暴雪自己在 OnLoad 就把它的 `Bg` 藏了 —— 它原本就只是一圈框。
--   ⇒ 只畫邊、底透明；畫了底就會蓋住名冊／聊天訊息。
------------------------------------------------------------
local function MainInset(inset, key)
    if not E.Usable(inset, key) then return end
    E.NeutralizeKeys(inset, { "Bg", "NineSlice" }, key)
    local ov = E.RegionBackdrop(inset, { key = key, sublevel = -4, edgeSublevel = -3 })
    E.Paint(ov, T.fillInset, T.border)
end

local function BorderInset(inset, key, points)
    if not E.Usable(inset, key) then return end
    NeutralizePresent(inset, { "Bg", "NineSlice" }, key)
    local ov = E.RegionBackdrop(inset, { key = key, points = points })
    E.Paint(ov, TRANSPARENT, T.border)
end

------------------------------------------------------------
-- 提示皮彈窗（浮在世界上方、彈出來填一下就關 ⇒ STYLE.md ① 的第二題）
--
-- `artKeys`：暴雪那一圈美術的 parentKey —— `BG`／`Border` 是 `DialogBorderDarkTemplate` 的**子框**
-- （純美術容器，整框 SetAlpha(0)），`NotificationSettingsDialog.BG` 是一張貼圖，
-- `TranslucentFrameTemplate` 是九張具名貼圖。本體都不是 layout host ⇒ `RegionBackdrop`
-- 直接建在彈窗自己身上，DIALOG strata／toplevel 都不必另外想。
------------------------------------------------------------
local TRANSLUCENT_ART = {
    "Bg", "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopBorder", "BottomBorder", "LeftBorder", "RightBorder",
}

local function TipDialog(d, key, artKeys, inset)
    if not E.Usable(d, key) then return false end
    NeutralizePresent(d, artKeys or { "BG", "Border" }, key)
    local ov = E.RegionBackdrop(d, { key = key, inset = inset })
    E.Paint(ov, T.tipFill, { T.Accent() })
    local close = Optional(d, "CloseButton")
    if close then Skin.CloseButton(close, key .. ".CloseButton") end
    return true
end

-- 常見的一格：`Common-Input-Border-*` 九片框（招募訊息、申請留言）＋ 裡面的多行輸入框
local COMMON_INPUT_BORDER = {
    "TopLeft", "TopRight", "Top", "BottomLeft", "BottomRight", "Bottom", "Left", "Right", "Middle",
}

local function MessageBox(frame, inputKey, key)
    if not frame then return end
    NeutralizePresent(frame, COMMON_INPUT_BORDER, key)
    local label = Optional(frame, "Label")
    if label then E.TextColor(label, T.textDim, key .. ".Label") end
    local input = Optional(frame, inputKey)
    if input then Skin.InputScroll(input, key .. "." .. inputKey) end
end

-- 「一個框裡一顆勾選框 ＋ 一條標籤」（ClubFinder／社群設定的那幾列）
local function CheckRow(row, key, cbKey)
    if not row then return end
    local cb = Optional(row, cbKey or "Button")
    if cb then Skin.CheckBox(cb, key .. "." .. (cbKey or "Button")) end
    local eb = Optional(row, "EditBox")
    if eb then Skin.EditBox(eb, key .. ".EditBox") end
end

local function Dropdowns(host, keys, prefix, opts)
    for _, k in ipairs(keys) do
        local dd = Optional(host, k)
        if dd then Skin.Dropdown(dd, prefix .. "." .. k, "style1", opts) end
    end
end

------------------------------------------------------------
-- 側邊分頁（`CommunitiesFrameTabTemplate`，CommunitiesTabs.xml:5-44）
--
-- 做法照成熟實作：圖示方形化、其餘美術全收、一塊方框墊在**圖示周圍**（錨在圖示上，
-- 不碰分頁的尺寸與錨點）。狀態全交給 C 端：
--   * 滑過：`HighlightTexture`（ButtonHilight-Square，ADD，鋪滿 32x32）→ 白 8%（`Engine.ButtonStates`）
--   * 選中：`CheckedTexture`（CheckButtonHilight，ADD，鋪滿）→ 右緣職業色直條（2026-09-24 起；原本是職業色 × 0.35 的 ADD 疊加）
--     （`Engine.CheckedTextureFile`）。暴雪 `SetChecked` 決定顯示與否，我們一行 Lua 都不跑。
-- 那張 64x64 的 `SpellBook-SkillLineTab` 是**無名**的 ⇒ `NeutralizeRegions` ＋ keep-set
-- （`Icon`／`IconOverlay`／Highlight／Checked 留下；`IconOverlay` 是「聊天被家長控制停用」的 50% 黑罩，資訊）。
------------------------------------------------------------
-- 側邊分頁貼著視窗（2026-09-24）：暴雪的 ChatTab 錨 `TOPLEFT → TOPRIGHT x=0 y=-36`
-- （CommunitiesFrame.xml:376）⇒ 分頁的黑邊跟視窗的黑邊並排成 2 條。往左推一個邊寬，
-- 兩條疊成一條、分頁看起來是從視窗長出來的（同底部分頁）。其餘三顆一顆接一顆錨在它
-- 下面，只挪第一顆整排就跟著走。暴雪 Lua 只重錨 GuildInfoTab（錨在 RosterTab 上，:1057）。

local function SideTab(tab, key)
    if not E.Usable(tab, key) then return end
    local icon = Optional(tab, "Icon")

    E.NeutralizeRegions(tab, key, E.KeepSet(tab, { "Icon", "IconOverlay" },
        { "GetHighlightTexture", "GetCheckedTexture" }))
    E.ButtonStates(tab, key)
    -- 選中：朝外那一邊（右緣）一條職業色直條 —— 跟底部分頁（`T.tabStyle = "underline"`，
    -- 線畫在朝外的下緣）同一套語言（2026-09-24；原本是整格 ADD 職業色 ×0.35，像一層霧）
    local r, g, b = T.Accent()
    E.CheckedTextureFile(tab, T.tabAccentRightTexture, { r, g, b, 1 }, key)

    if icon then
        E.CropIcon(icon, key .. ".Icon")
        local ov = E.Overlay(tab, {
            key = key,
            anchorTo = icon,
            points = {
                { "TOPLEFT", "TOPLEFT", -1, 1 },
                { "BOTTOMRIGHT", "BOTTOMRIGHT", 1, -1 },
            },
        })
        E.Paint(ov, T.fill, T.border)
    else
        E.Missing(key .. ".Icon")
    end
end

------------------------------------------------------------
-- 左側社群清單的池化列（`CommunitiesListEntryTemplate`）
--
-- apply（第一次見到這一列）：
--   * `Background`（藍色／綠色選單卡片）與 `IconRing`（頭像金環）中和 —— 同成熟實作。
--     Init 每次對它們 SetTexture／SetAtlas／SetShown，但**沒有 SetAlpha** ⇒ 一次就撐得住。
--   * 平面卡片：`Skin.Row`（fill ＋ 黑邊，上下各縮 2 讓相鄰兩張之間留縫）、滑過自己畫
--     （暴雪的 Highlight 是 80 高、溢出列 6 點的藍卡，對不齊 ⇒ `ownHover` 把它中和）。
-- reapply（每次 Init）：
--   * 選中態：讀 `Selection:IsShown()`（見下面 ApplyListEntry 上方的說明）。
--   名字顏色（綠＝公會、藍＝戰網、金＝一般、灰＝停用）是資訊，不碰；公會徽章、頭像、
--   未讀點、我的最愛星號、新社群閃光都不碰。
------------------------------------------------------------
local LIST_ROW_POINTS = {
    { "TOPLEFT", "TOPLEFT", 0, -2 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 2 },
}

-- 選中態（2026-09-24 改）：原本把暴雪的 `Selection` 去飽和染職業色，但它是 **80 高**、
-- 比 68 高的列溢出 6 —— 染出來是一塊溢出卡片、壓到鄰列的暗紅光暈。改成中和它，
-- 選中改走 `Skin.Row` 的標準選中態（壓暗職業色底 ＋ 左緣職業色條），來源是
-- **`Selection:IsShown()`**（C 端布林、過 `Secret.ToBool`）：暴雪每次 Init 都
-- `Selection:SetShown(...)`（CommunitiesList.lua:471,510,588,626,674），而換選取會走
-- `OnClubSelected → Update → SetDataProvider` 讓每一列重跑 Init ⇒ reapply 一定跟得上。
local function ApplyListEntry(row)
    NeutralizePresent(row, { "Background", "IconRing", "Selection" }, "CommunitiesListEntry")
    Skin.Row(row, "CommunitiesListEntry", {
        ownHover = true,
        border = true,
        points = LIST_ROW_POINTS,
    })
end

local function ReapplyListEntry(row)
    local sel = Optional(row, "Selection")
    if not sel then return end
    local ok, shown = pcall(sel.IsShown, sel)
    E.SetSelected(row, ok and ns.Secret.ToBool(shown) == true)
end

------------------------------------------------------------
-- 公會福利頁的兩種池化列
--
-- 福利列（GuildPerks.xml:4-113）：Left/Right/中段 ＋ 一張 BORDER 全框，後兩張**無名** ⇒
--   `NeutralizeRegions` ＋ keep `Icon`；`NormalBorder`／`DisabledBorder` 是預設隱藏的子框，不碰。
-- 獎勵列（GuildRewards.xml:137-211）：只有 `NormalTexture`（訓練師卡片）要中和；
--   `DisabledBG`（MOD 壓暗）、`Lock`、金錢、名字的灰／金字型物件、圖示的去飽和與紅色都是
--   「解鎖了沒／買不買得起」的資訊 ⇒ 全留（成熟實作連它們一起淡掉，我們不跟）。
-- 兩種列的 Init 都 `Icon:SetTexture` ⇒ 裁邊放 reapply。
------------------------------------------------------------
local ROW_INSET_POINTS = {
    { "TOPLEFT", "TOPLEFT", 1, -1 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", -1, 1 },
}

local function ApplyPerkRow(row)
    E.NeutralizeRegions(row, "GuildPerksRow", E.KeepSet(row, { "Icon" }))
    local ov = E.Overlay(row, { key = "GuildPerksRow", points = ROW_INSET_POINTS })
    E.Paint(ov, T.fill, T.border)
    local icon = Optional(row, "Icon")
    if icon then Skin.Icon(icon, "GuildPerksRow.Icon") end
end

local function ApplyRewardRow(row)
    if type(row.GetNormalTexture) == "function" then
        local ok, tex = pcall(row.GetNormalTexture, row)
        if ok and tex then E.Neutralize(tex, "GuildRewardsRow.NormalTexture") end
    end
    E.ButtonStates(row, "GuildRewardsRow")
    local ov = E.Overlay(row, { key = "GuildRewardsRow", points = ROW_INSET_POINTS })
    E.Paint(ov, T.fill, T.border)
    local icon = Optional(row, "Icon")
    if icon then Skin.Icon(icon, "GuildRewardsRow.Icon") end
end

local function ReapplyRowIcon(row)
    local icon = Optional(row, "Icon")
    if icon then E.CropIcon(icon, "GuildBenefitsRow.Icon") end
end

------------------------------------------------------------
-- hooks：三支 mixin 後置勾（`hooks` 在戰鬥閘前面裝，池化列第一次顯示才建 ⇒ 來得及）
------------------------------------------------------------
local listSweep, perkSweep, rewardSweep

local function InstallHooks()
    listSweep = E.HookRows{
        key     = "CommunitiesListEntry",
        mixin   = _G.CommunitiesListEntryMixin,
        method  = "Init",
        apply   = ApplyListEntry,
        reapply = ReapplyListEntry,
    }
    perkSweep = E.HookRows{
        key     = "CommunitiesGuildPerksButton",
        mixin   = _G.CommunitiesGuildPerksButtonMixin,
        method  = "Init",
        apply   = ApplyPerkRow,
        reapply = ReapplyRowIcon,
    }
    rewardSweep = E.HookRows{
        key     = "CommunitiesGuildRewardsButton",
        mixin   = _G.CommunitiesGuildRewardsButtonMixin,
        method  = "Init",
        apply   = ApplyRewardRow,
        reapply = ReapplyRowIcon,
    }
end

------------------------------------------------------------
-- (a) 外框
------------------------------------------------------------
local MAXMIN_GLYPH = { MaximizeButton = "expand", MinimizeButton = "collapse" }
local SIDE_TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" }

local function SkinChrome(f)
    Skin.PortraitChrome(f, "CommunitiesFrame")
    Skin.Panel(f, "CommunitiesFrame")

    -- 公會徽章／社群頭像：成熟實作整塊收掉（它跟方形外框的語彙對不上，而且凸出視窗左上角）。
    -- `PortraitOverlay` 是 frameLevel 300 的純美術框，Lua 只 Show/Hide 它與換裡面的材質，沒有 SetAlpha。
    local po = Optional(f, "PortraitOverlay")
    if po then E.Neutralize(po, "CommunitiesFrame.PortraitOverlay") end

    WithSub(f, "CloseButton", "CommunitiesFrame.CloseButton", function(btn, label)
        Skin.CloseButton(btn, label)
    end)

    WithSub(f, "MaximizeMinimizeFrame", "CommunitiesFrame.MaximizeMinimizeFrame", function(frame, key)
        for name, glyph in pairs(MAXMIN_GLYPH) do
            local btn = Sub(frame, name, key .. "." .. name)
            if btn then Skin.IconButton(btn, key .. "." .. name, { glyph = glyph }) end
        end
    end)

    WithSub(f, "Inset", "CommunitiesFrame.Inset", MainInset)

    for _, k in ipairs(SIDE_TABS) do
        WithSub(f, k, "CommunitiesFrame." .. k, SideTab)
    end
    local chatTab = Optional(f, "ChatTab")
    if chatTab then
        E.ShiftRoot(chatTab, "TOPLEFT", f, "TOPRIGHT", -T.BorderSize(), -36, "CommunitiesFrame.ChatTab")
    end
end

------------------------------------------------------------
-- (b) 左側社群清單
------------------------------------------------------------
local LIST_ART = { "Bg", "TopFiligree", "BottomFiligree" }
-- InsetFrame 上緣（清單上緣 +1，CommunitiesList.xml:247）往下這麼多 ⇒ 框頂在清單上緣 −38，
-- 第一張卡片（上內距 40 ＋ 卡片內縮 2）上方留 4。
local LIST_BOX_TOP = 39

local function SkinCommunitiesList(list, key)
    if not E.Usable(list, key) then return end
    NeutralizePresent(list, LIST_ART, key)
    -- 四角與金邊的那一整層（frameLevel 100 的純美術框）
    local fo = Optional(list, "FilligreeOverlay")
    if fo then E.Neutralize(fo, key .. ".FilligreeOverlay") end

    -- 清單底：畫在**清單自己身上**（useParentLevel ⇒ 墊 sublevel −4），範圍照 InsetFrame 的矩形。
    -- 邊畫在 InsetFrame 上（它在 level 200、疊在列上面，就像暴雪原本那一圈 NineSlice）。
    --
    -- 2026-09-24：框的上緣往下收 LIST_BOX_TOP，跟聊天框／名冊框的上緣切齊。
    -- 暴雪的清單從標題帶正下方就開始（CommunitiesFrame.xml:365 `TOPLEFT y=-23`），但列表
    -- 自己留了 40 的上內距（CommunitiesList.lua:271 `view:SetPadding(40,…)`，原本墊藍色花邊）
    -- ⇒ 深色框頂到標題帶、右邊那一排卻是面板色，接縫處看起來是一個斷點。
    local inset = Optional(list, "InsetFrame")
    local fill = E.RegionBackdrop(list, {
        key = key .. ".fill", slot = "fill", noBorder = true, sublevel = -4,
        points = inset and {
            { "TOPLEFT", "TOPLEFT", 0, -LIST_BOX_TOP, rel = inset },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, rel = inset },
        } or nil,
    })
    E.Paint(fill, T.fillInset)
    if inset then
        BorderInset(inset, key .. ".InsetFrame", {
            { "TOPLEFT", "TOPLEFT", 0, -LIST_BOX_TOP },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
        })
    end

    WithSub(list, "ScrollBar", key .. ".ScrollBar", ScrollBar)
    local box = Optional(list, "ScrollBox")
    if box then E.SweepRows(box, key .. ".ScrollBox", listSweep) end
end

------------------------------------------------------------
-- (c) 聊天：外框、捲軸、輸入框（雷 3，見檔頭）
------------------------------------------------------------
local CHAT_EDIT_ART = { "Left", "Right", "Mid" }

local function SkinChat(f)
    WithSub(f, "Chat", "CommunitiesFrame.Chat", function(chat, key)
        local inset = Optional(chat, "InsetFrame")
        if inset then BorderInset(inset, key .. ".InsetFrame") end
        WithSub(chat, "ScrollBar", key .. ".ScrollBar", ScrollBar)
        -- MessageFrame（ScrollingMessageFrame）一根手指都不碰。
    end)

    -- ⚠ 輸入框：只中和三張美術 ＋ 在它自己身上建底與邊。**零 hook、零重排、不建子框**。
    --   幾何照原本那組美術：`Left` 錨 LEFT x=−10、`Right` 錨 RIGHT x=+10（32 高的材質、
    --   可見的框線在中間那一段）⇒ 左右各外擴 6、高 24、垂直置中（跟著輸入框的矩形走，
    --   最小化時暴雪重錨它，我們的貼圖自然跟著）。
    WithSub(f, "ChatEditBox", "CommunitiesFrame.ChatEditBox", function(eb, key)
        if not E.Usable(eb, key) then return end
        NeutralizePresent(eb, CHAT_EDIT_ART, key)
        local ov = E.RegionBackdrop(eb, {
            key = key,
            points = { { "LEFT", "LEFT", -6, 0 }, { "RIGHT", "RIGHT", 6, 0 } },
            height = 24,
        })
        E.Paint(ov, T.fillInset, T.border)
    end)
end

------------------------------------------------------------
-- (d) 名冊（雷 1：只准外框與捲軸 —— 列、名冊框本身、ColumnDisplay 一律不碰）
--
-- 名冊外面那幾顆（「在線人數」字、「顯示離線」勾選框、兩顆排序下拉）是成熟實作也做的：
--   * `MemberCount`：`UpdateMemberCount` 只 SetText（CommunitiesMemberList.lua:396-406）⇒ 染一次就夠。
--   * `ShowOfflineButton`：`Skin.CheckBox`（只有 OnEnter/OnLeave，點擊路徑上沒有我們的 Lua）。
--   * 兩顆下拉：`noHover` ⇒ 零腳本（選項改的是名冊的顯示方式，會觸發名冊刷新）。
------------------------------------------------------------
-- 23.5 是耳機鈕框的中線；CJK 字的筆畫重心比字框中線偏上，實機看起來高了約 2
-- （2026-09-24 擷圖 14）⇒ 再往下 2，對的是耳機圖示的視覺中心。
local MEMBER_COUNT_DY = 21.5

local function SkinMemberList(f)
    WithSub(f, "MemberList", "CommunitiesFrame.MemberList", function(ml, key)
        local inset = Optional(ml, "InsetFrame")
        if inset then BorderInset(inset, key .. ".InsetFrame") end
        WithSub(ml, "ScrollBar", key .. ".ScrollBar", QuietScrollBar)
        local count = Optional(ml, "MemberCount")
        if count then
            E.TextColor(count, T.text, key .. ".MemberCount")
            -- 「N/M 線上」跟左邊的語音耳機鈕垂直置中（2026-09-24）。原本 `BOTTOMLEFT` 錨名冊上緣
            -- ＋17（CommunitiesMemberList.xml:249）⇒ 字越大越往上長。改錨 `LEFT`（字的中線）：
            -- 耳機鈕 `TOPRIGHT y=-26`、高 27（CommunitiesFrame.lua:1677、.xml:450）⇒ 中線在視窗
            -- 上緣 −39.5；名冊上緣 −63（.xml:460）⇒ 名冊上緣往上 23.5。跟字型大小無關。
            -- 暴雪 Lua 對名冊的 MemberCount 只 SetText（:396-406），零處重錨。
            E.Reanchor({ { count, { { "LEFT", "TOPLEFT", 0, MEMBER_COUNT_DY, rel = ml } } } },
                key .. ".MemberCount")
        end
        local offline = Optional(ml, "ShowOfflineButton")
        if offline then
            Skin.CheckBox(offline, key .. ".ShowOfflineButton")
            local text = Optional(offline, "Text")
            if text then E.TextColor(text, T.text, key .. ".ShowOfflineButton.Text") end
        end
    end)
    Dropdowns(f, { "GuildMemberListDropdown", "CommunityMemberListDropdown" }, "CommunitiesFrame",
        { noHover = true })
end

------------------------------------------------------------
-- (e) 上方與底部的控件
------------------------------------------------------------
local CONTROL_BUTTONS = {
    { "CommunitiesSettingsButton", "secondary" },
    { "GuildControlButton", "secondary" },
    { "GuildRecruitmentButton", "secondary" },
}

-- 「加入聊天」小箭頭鈕（WowStyle1ArrowDropdownTemplate，只有 `Arrow` ＋ 左邊一條 `Label`）
local function SkinAddToChat(btn, key)
    if not E.Usable(btn, key) then return end
    E.Neutralize(Optional(btn, "Arrow"), key .. ".Arrow")
    local ov = E.Overlay(btn, {
        key = key,
        inset = 4,
        glyph = { kind = "chevronDown", size = T.glyphSize, thickness = 1, color = T.textDim },
    })
    E.Paint(ov, T.fillInset, T.border)
    E.TrackButtonHover(btn, ov, T.fillInset)
    E.TrackGlyph(btn, ov)
    local label = Optional(btn, "Label")
    if label then E.TextColor(label, T.text, key .. ".Label") end
end

local function SkinControls(f)
    Dropdowns(f, { "StreamDropdown", "CommunitiesListDropdown" }, "CommunitiesFrame")

    local atc = Optional(f, "AddToChatButton")
    if atc then SkinAddToChat(atc, "CommunitiesFrame.AddToChatButton") end

    -- 底部那一排是平行的選項（邀請／設定／公會控制／招募／紀錄），判準第 3 條 ⇒ 全部 secondary
    ButtonsOn(f, { { "InviteButton", "secondary" }, { "GuildLogButton", "secondary" } }, "CommunitiesFrame")
    local cf = Optional(f, "CommunitiesControlFrame")
    if cf then ButtonsOn(cf, CONTROL_BUTTONS, "CommunitiesFrame.CommunitiesControlFrame") end
end

------------------------------------------------------------
-- (f) 公會福利頁
------------------------------------------------------------
local INSET_BORDER_ART = {
    "InsetBorderLeft", "InsetBorderRight", "InsetBorderBottomRight", "InsetBorderBottomLeft",
    "InsetBorderTopRight", "InsetBorderTopLeft", "InsetBorderLeft2", "InsetBorderBottomLeft2",
    "InsetBorderTopLeft2",
}

-- 聲望條的槽（GuildRewards.xml:68-135 抄的幾何，沒有量測）：
--   `Left`/`Right` 18x18 貼著底 ⇒ 中線在底往上 9；`BG`／`Progress` 14 高 ⇒ 槽是底往上 2～16。
--   往外推 1 讓填充碰不到邊 ⇒ 底往上 1～17，左右各外擴 1。
local REP_TROUGH_Y = 1
local REP_TROUGH_H = 16

local function SkinRepBar(ff, key)
    local label = Optional(ff, "Label")
    if label then E.TextColor(label, T.textDim, key .. ".Label") end
    local bar = Optional(ff, "Bar")
    if not bar or not E.Usable(bar, key .. ".Bar") then return end
    NeutralizePresent(bar, { "Left", "Right", "Middle", "BG", "Shadow" }, key .. ".Bar")
    local ov = E.RegionBackdrop(bar, {
        key = key .. ".Bar",
        points = {
            { "BOTTOMLEFT", "BOTTOMLEFT", -1, REP_TROUGH_Y },
            { "BOTTOMRIGHT", "BOTTOMRIGHT", 1, REP_TROUGH_Y },
        },
        height = REP_TROUGH_H,
    })
    E.Paint(ov, T.fillInset, T.border)
end

local function SkinBenefits(f)
    WithSub(f, "GuildBenefitsFrame", "CommunitiesFrame.GuildBenefitsFrame", function(gb, key)
        NeutralizePresent(gb, INSET_BORDER_ART, key)
        for _, k in ipairs({ "Perks", "Rewards" }) do
            WithSub(gb, k, key .. "." .. k, function(sec, skey)
                E.NeutralizeRegions(sec, skey)          -- 兩欄的底圖（Perks 那張無名、Rewards 的 `Bg`）
                local title = Optional(sec, "TitleText")
                if title then E.TextColor(title, T.text, skey .. ".TitleText") end
                WithSub(sec, "ScrollBar", skey .. ".ScrollBar", ScrollBar)
            end)
        end
        local ff = Optional(gb, "FactionFrame")
        if ff then SkinRepBar(ff, key .. ".FactionFrame") end

        local perks, rewards = Optional(gb, "Perks"), Optional(gb, "Rewards")
        local pbox = perks and Optional(perks, "ScrollBox")
        if pbox then E.SweepRows(pbox, key .. ".Perks.ScrollBox", perkSweep) end
        local rbox = rewards and Optional(rewards, "ScrollBox")
        if rbox then E.SweepRows(rbox, key .. ".Rewards.ScrollBox", rewardSweep) end
    end)
end

------------------------------------------------------------
-- (g) 公會資訊頁
--
-- 兩欄（Info／News）自己的美術全收（標題條、橫條、挑戰底圖、新聞頁的底與標頭），
-- 標題白字、三條捲軸，再補兩條分隔髮絲線（成熟實作的幾何：兩欄之間一條直線，
-- 在新聞欄左緣外 7、上下各縮 4；資訊欄 y=−194 一條橫線，左 14 右 7）。
-- 挑戰列（Challenge1～4）、公告與詳情的字、編輯鈕都不碰。
------------------------------------------------------------
local INFO_DIVIDER_Y = -194

local function SkinDetails(f)
    WithSub(f, "GuildDetailsFrame", "CommunitiesFrame.GuildDetailsFrame", function(gd, key)
        NeutralizePresent(gd, INSET_BORDER_ART, key)
        local info, news = Optional(gd, "Info"), Optional(gd, "News")

        for name, sub in pairs({ Info = info, News = news }) do
            local skey = key .. "." .. name
            if E.Usable(sub, skey) then
                E.NeutralizeRegions(sub, skey)
                local title = Optional(sub, "TitleText")
                if title then E.TextColor(title, T.text, skey .. ".TitleText") end
                local bar = Optional(sub, "ScrollBar")
                if bar then ScrollBar(bar, skey .. ".ScrollBar") end
                for _, sf in ipairs({ "DetailsFrame", "MOTDScrollFrame" }) do
                    local frame = Optional(sub, sf)
                    local sbar = frame and Optional(frame, "ScrollBar")
                    if sbar then ScrollBar(sbar, skey .. "." .. sf .. ".ScrollBar") end
                end
            end
        end

        if news then
            local v = E.RegionBackdrop(gd, {
                key = key .. ".divider", slot = "divider", noBorder = true, width = 1,
                points = {
                    { "TOP", "TOPLEFT", -7, -4, rel = news },
                    { "BOTTOM", "BOTTOMLEFT", -7, 4, rel = news },
                },
            })
            E.Paint(v, T.fillHover)
        end
        if info then
            local h = E.RegionBackdrop(info, {
                key = key .. ".Info.divider", slot = "divider", noBorder = true, height = 1,
                points = {
                    { "TOPLEFT", "TOPLEFT", 14, INFO_DIVIDER_Y },
                    { "TOPRIGHT", "TOPRIGHT", -7, INFO_DIVIDER_Y },
                },
            })
            E.Paint(h, T.fillHover)
        end
    end)
end

------------------------------------------------------------
-- (h) 尋找公會／社群、邀請與門票頁
------------------------------------------------------------
local FINDER_DROPDOWNS = { "ClubFilterDropdown", "ClubSizeDropdown", "SortByDropdown" }
local ROLE_FRAMES = { "TankRoleFrame", "HealerRoleFrame", "DpsRoleFrame" }
local CARD_PAGERS = { "GuildCards", "PendingGuildCards" }
local CARD_LISTS = { "CommunityCards", "PendingCommunityCards" }
local FINDER_TABS = { "ClubFinderSearchTab", "ClubFinderPendingTab" }

-- 申請加入（ClubFinder.xml:556）：提示皮 ＋ 留言框 ＋ 申請（primary）／取消
local function SkinRequestToJoin(d, key)
    if not d or not TipDialog(d, key) then return end
    MessageBox(Optional(d, "MessageFrame"), "MessageScroll", key .. ".MessageFrame")
    ButtonsOn(d, { { "Apply", "primary" }, { "Cancel", "secondary" } }, key)
end

local function SkinFinder(finder, key)
    if not E.Usable(finder, key) then return end
    for _, k in ipairs({ "InsetFrame", "DisabledFrame" }) do
        local inset = Optional(finder, k)
        if inset then Skin.Inset(inset, key .. "." .. k) end
    end

    local ol = Optional(finder, "OptionsList")
    if ol then
        local okey = key .. ".OptionsList"
        Dropdowns(ol, FINDER_DROPDOWNS, okey)
        for _, rk in ipairs(ROLE_FRAMES) do
            local rf = Optional(ol, rk)
            if rf then CheckRow(rf, okey .. "." .. rk, "Checkbox") end
        end
        local sb = Optional(ol, "SearchBox")
        if sb then Skin.EditBox(sb, okey .. ".SearchBox") end
        -- 搜尋：這一塊唯一的動作 ⇒ primary（零腳本）
        ButtonsOn(ol, { { "Search", "primary" } }, okey)
    end

    for i, ck in ipairs(CARD_PAGERS) do
        local cards = Optional(finder, ck)
        if cards then
            for j, pk in ipairs({ "PreviousPage", "NextPage" }) do
                local btn = Optional(cards, pk)
                if btn then
                    Skin.IconButton(btn, key .. "." .. ck .. "." .. pk, {
                        inset = 4,
                        glyph = (j == 1) and "chevronLeft" or "chevronRight",
                        glyphColor = T.textDim,
                        trackEnabled = true,
                    })
                end
            end
        end
    end
    for _, ck in ipairs(CARD_LISTS) do
        local cards = Optional(finder, ck)
        local bar = cards and Optional(cards, "ScrollBar")
        if bar then ScrollBar(bar, key .. "." .. ck .. ".ScrollBar") end
    end

    for _, tk in ipairs(FINDER_TABS) do
        local tab = Optional(finder, tk)
        if tab then SideTab(tab, key .. "." .. tk) end
    end

    SkinRequestToJoin(Optional(finder, "RequestToJoinFrame"), key .. ".RequestToJoinFrame")
end

-- 邀請／門票／尋找公會的邀請頁：接受＝primary、拒絕＝secondary、申請＝primary
local INVITE_BUTTONS = {
    { "AcceptButton", "primary" },
    { "DeclineButton", "secondary" },
    { "ApplyButton", "primary" },
}

local function SkinInvitationHosts(f)
    for _, hk in ipairs({ "InvitationFrame", "ClubFinderInvitationFrame", "TicketFrame" }) do
        local host = Optional(f, hk)
        if host then
            local key = "CommunitiesFrame." .. hk
            ButtonsOn(host, INVITE_BUTTONS, key)
            local inset = Optional(host, "InsetFrame")
            if inset then Skin.Inset(inset, key .. ".InsetFrame") end
            SkinRequestToJoin(Optional(host, "RequestToJoinFrame"), key .. ".RequestToJoinFrame")
        end
    end
end

------------------------------------------------------------
-- (i) 彈窗
------------------------------------------------------------

-- 成員詳情（GuildRoster.xml:5）：外框 ＋ 關閉 ＋ 移除／組隊邀請（零腳本，兩顆平行 ⇒ secondary，
-- 模板字是 GameFontNormalSmall ⇒ 換成同一級的白字）＋ 階級下拉只換長相（`noHover`）。
-- 五條欄位標籤降成 textDim（SetTextColor 不改寬度；`RankLabel:GetWidth()` 讀的是寬度）。
-- 兩塊註記底（點下去就是改註記）不碰；名字與內文不碰。
local DETAIL_LABELS = { "ZoneLabel", "RankLabel", "OnlineLabel", "NoteLabel", "OfficerNoteLabel" }

local function SkinMemberDetail(d, key)
    if not TipDialog(d, key, { "Border" }) then return end
    ButtonsOn(d, {
        { "RemoveButton", "secondary", GameFontHighlightSmall },
        { "GroupInviteButton", "secondary", GameFontHighlightSmall },
    }, key)
    local rank = Optional(d, "RankDropdown")
    if rank then Skin.Dropdown(rank, key .. ".RankDropdown", "style1", { noHover = true }) end
    TextColorKeys(d, DETAIL_LABELS, T.textDim, key)
end

-- 建立／編輯頻道（CommunitiesStreams.xml:82-178）
local function SkinEditStream(d, key)
    if not TipDialog(d, key) then return end
    ButtonsOn(d, { { "Accept", "primary" }, { "Delete", "secondary" }, { "Cancel", "secondary" } }, key)
    local name = Optional(d, "NameEdit")
    if name then Skin.EditBox(name, key .. ".NameEdit") end
    local desc = Optional(d, "Description")
    if desc then Skin.InputScroll(desc, key .. ".Description") end
    local cb = Optional(d, "TypeCheckbox")
    if cb then Skin.CheckBox(cb, key .. ".TypeCheckbox") end
    TextColorKeys(d, { "NameLabel", "DescriptionLabel" }, T.textDim, key)
end

-- 通知設定（CommunitiesStreams.xml:179-288）：`BG` 是貼圖、`Selector` 身上直接掛著 NineSlice 片
local function SkinNotificationSettings(d, key)
    if not TipDialog(d, key, { "BG" }) then return end
    local sel = Optional(d, "Selector")
    if sel then
        E.NeutralizeRegions(sel, key .. ".Selector")
        ButtonsOn(sel, { { "OkayButton", "primary" }, { "CancelButton", "secondary" } }, key .. ".Selector")
    end
    local dd = Optional(d, "CommunitiesListDropdown")
    if dd then Skin.Dropdown(dd, key .. ".CommunitiesListDropdown", "style1") end
    local sf = Optional(d, "ScrollFrame")
    local child = sf and Optional(sf, "Child")
    if child then
        local qj = Optional(child, "QuickJoinButton")
        if qj then Skin.CheckBox(qj, key .. ".QuickJoinButton") end
        -- 「全部」「無」是 UIMenuButtonStretchTemplate，字本來就是 GameFontHighlightSmall
        ButtonsOn(child, {
            { "AllButton", "secondary", GameFontHighlightSmall },
            { "NoneButton", "secondary", GameFontHighlightSmall },
        }, key)
    end
    ScrollBarsIn(d, key)
end

-- 公會招募（ClubFinder.xml:247 起）
local RECRUIT_CHECK_ROWS = { "ShouldListClub", "MaxLevelOnly", "MinIlvlOnly", "AutoAcceptApplications" }
local RECRUIT_DROPDOWNS = { "ClubFocusDropdown", "LookingForDropdown", "LanguageDropdown" }

local function SkinRecruitment(d, key)
    if not TipDialog(d, key) then return end
    ButtonsOn(d, { { "Accept", "primary" }, { "Cancel", "secondary" } }, key)
    Dropdowns(d, RECRUIT_DROPDOWNS, key)
    for _, rk in ipairs(RECRUIT_CHECK_ROWS) do CheckRow(Optional(d, rk), key .. "." .. rk) end
    MessageBox(Optional(d, "RecruitmentMessageFrame"), "RecruitmentMessageInput", key .. ".RecruitmentMessageFrame")
    ScrollBarsIn(d, key)
end

-- 社群設定（CommunitiesSettings.xml:5，全域）
local function SkinCommunitySettings(d, key)
    if not TipDialog(d, key) then return end
    ButtonsOn(d, {
        { "Accept", "primary" }, { "Delete", "secondary" }, { "Cancel", "secondary" },
        { "ChangeAvatarButton", "secondary" },
    }, key)
    for _, ek in ipairs({ "NameEdit", "ShortNameEdit" }) do
        local eb = Optional(d, ek)
        if eb then Skin.EditBox(eb, key .. "." .. ek) end
    end
    for _, sk in ipairs({ "MessageOfTheDay", "Description" }) do
        local sf = Optional(d, sk)
        if sf then Skin.InputScroll(sf, key .. "." .. sk) end
    end
    CheckRow(Optional(d, "CrossFactionToggle"), key .. ".CrossFactionToggle", "CheckButton")
    for _, rk in ipairs(RECRUIT_CHECK_ROWS) do CheckRow(Optional(d, rk), key .. "." .. rk) end
    Dropdowns(d, RECRUIT_DROPDOWNS, key)
    TextColorKeys(d, { "NameLabel", "ShortNameLabel", "DescriptionLabel", "MessageOfTheDayLabel" }, T.textDim, key)
    ScrollBarsIn(d, key)
end

-- 公會紀錄（GuildInfo.xml:385-445，TranslucentFrameTemplate）
--   兩顆同名 `$parentCloseButton`：× 是 `UIPanelCloseButton`（沒有 Left）、「關閉」是 `UIPanelButtonTemplate`
--   （有 Left）⇒ `GetChildren` 走一遍、**看結構**分：有 `Left` 的走零腳本 secondary，沒有的走關閉鈕。
--   `Container`（TooltipBackdropTemplate）的九片全收、換 fillInset ＋ 黑邊；捲軸在它裡面（ScrollFrameTemplate
--   在 OnLoad 才建 `ScrollBar`）⇒ `ScrollBarsIn`。
local LOG_INSET = 4

local function SkinGuildLog(key)
    local gl = _G.CommunitiesGuildLogFrame
    if not gl then
        E.Missing(key)
        return
    end
    if not E.Usable(gl, key) then return end
    NeutralizePresent(gl, TRANSLUCENT_ART, key)
    local ov = E.RegionBackdrop(gl, { key = key, inset = LOG_INSET })
    E.Paint(ov, T.tipFill, { T.Accent() })

    local ok, kids = pcall(function() return { gl:GetChildren() } end)
    if ok then
        for i, child in ipairs(kids) do
            local isButton = false
            if type(child.GetObjectType) == "function" then
                local ok2, kind = pcall(child.GetObjectType, child)
                isButton = ok2 and kind == "Button"
            end
            if isButton then
                if Optional(child, "Left") then
                    ScriptlessButton(child, key .. ".CloseTextButton" .. i, "secondary")
                else
                    Skin.CloseButton(child, key .. ".CloseButton" .. i)
                end
            end
        end
    end

    local cont = Optional(gl, "Container")
    if cont then
        E.NeutralizeRegions(cont, key .. ".Container")
        local cov = E.RegionBackdrop(cont, { key = key .. ".Container" })
        E.Paint(cov, T.fillInset, T.border)
    end
    local title = _G.CommunitiesGuildLogFrameTitle
    if title then E.TextColor(title, T.text, key .. ".Title") end
    ScrollBarsIn(gl, key)
end

-- 新聞篩選（GuildNews.xml:385-437，TranslucentFrameTemplate）
local NEWS_FILTERS = {
    "GuildAchievement", "Achievement", "DungeonEncounter", "EpicItemLooted",
    "EpicItemPurchased", "EpicItemCrafted", "LegendaryItemLooted",
}

local function SkinNewsFilters(key)
    local nf = _G.CommunitiesGuildNewsFiltersFrame
    if not nf then
        E.Missing(key)
        return
    end
    if not TipDialog(nf, key, TRANSLUCENT_ART, LOG_INSET) then return end
    local title = Optional(nf, "Title")
    if title then E.TextColor(title, T.text, key .. ".Title") end
    for _, k in ipairs(NEWS_FILTERS) do
        local cb = Optional(nf, k)
        if cb then Skin.CheckBox(cb, key .. "." .. k) end
    end
end

local function SkinDialogs(f)
    local d = Optional(f, "GuildMemberDetailFrame")
    if d then SkinMemberDetail(d, "CommunitiesFrame.GuildMemberDetailFrame") end
    d = Optional(f, "EditStreamDialog")
    if d then SkinEditStream(d, "CommunitiesFrame.EditStreamDialog") end
    d = Optional(f, "NotificationSettingsDialog")
    if d then SkinNotificationSettings(d, "CommunitiesFrame.NotificationSettingsDialog") end
    d = Optional(f, "RecruitmentDialog")
    if d then SkinRecruitment(d, "CommunitiesFrame.RecruitmentDialog") end

    if _G.CommunitiesSettingsDialog then
        SkinCommunitySettings(_G.CommunitiesSettingsDialog, "CommunitiesSettingsDialog")
    else
        E.Missing("CommunitiesSettingsDialog")
    end
    SkinGuildLog("CommunitiesGuildLogFrame")
    SkinNewsFilters("CommunitiesGuildNewsFiltersFrame")
end

------------------------------------------------------------
-- apply
------------------------------------------------------------
------------------------------------------------------------
-- 底部按鈕列留呼吸（2026-09-24）
--
-- 暴雪的按鈕 20 高、錨 `y=5`（CommunitiesFrame.xml:570,586,592），上面那一整排框的下緣在
-- 26～30 ⇒ 按鈕頂著框、底下貼著視窗邊。把**所有**錨在視窗下緣的內容框一起往上抬 FOOTER_DY，
-- 按鈕抬 FOOTER_BTN_DY ⇒ 上下各留約 6。每一種顯示模式（聊天／名冊／福利／資訊／尋找／邀請）
-- 的框都在清單裡，否則換頁時下緣會跟左邊清單差一截。
-- 全部走 `Engine.ShiftRoot`（同名錨點覆寫：**只改 BOTTOM 那一個**，暴雪 Lua 另外設的 TOPLEFT
-- 不受影響；脫戰；`db.relayout = false` 可關）。暴雪 Lua 對這些框的 BOTTOMRIGHT／BOTTOMLEFT
-- 零處重設（grep 過 Blizzard_Communities 全部 .lua；`MemberList:RefreshLayout` 只設 TOPLEFT、
-- 聊天框錨在名冊上自己跟著走、`CommunitiesSettingsButton` 是錨在 InviteButton 上）。
-- 最小化模式另有自己的一套錨點（聊天框錨視窗下緣 y=36），不在範圍內。
------------------------------------------------------------
local FOOTER_DY = 6
local FOOTER_BTN_DY = 2
local FOOTER_SHIFTS = {
    -- { parentKey, 錨點, 相對點, x, XML 原本的 y }
    { "Inset", "BOTTOMRIGHT", "BOTTOMRIGHT", -6, 26 },                   -- SharedUIPanelTemplates.xml:689
    { "CommunitiesList", "BOTTOMRIGHT", "BOTTOMLEFT", 170, 29 },         -- CommunitiesFrame.xml:366
    { "MemberList", "BOTTOMRIGHT", "BOTTOMRIGHT", -26, 28 },             -- :461
    { "ApplicantList", "BOTTOMRIGHT", "BOTTOMRIGHT", -9, 29 },           -- :467
    { "GuildFinderFrame", "BOTTOMRIGHT", "BOTTOMRIGHT", -9, 29 },        -- :478
    { "CommunityFinderFrame", "BOTTOMRIGHT", "BOTTOMRIGHT", -9, 29 },    -- :489
    { "InvitationFrame", "BOTTOMRIGHT", "BOTTOMRIGHT", -9, 29 },         -- :505
    { "ClubFinderInvitationFrame", "BOTTOMRIGHT", "BOTTOMRIGHT", -9, 29 }, -- :511
    { "TicketFrame", "BOTTOMRIGHT", "BOTTOMRIGHT", -12, 30 },            -- :524
    { "GuildBenefitsFrame", "BOTTOMRIGHT", "BOTTOMRIGHT", -12, 30 },     -- :530
    { "GuildDetailsFrame", "BOTTOMRIGHT", "BOTTOMRIGHT", -12, 30 },      -- :536
}
local FOOTER_BUTTONS = {
    { "InviteButton", "BOTTOMRIGHT", "BOTTOMRIGHT", -5, 5 },             -- :570
    { "CommunitiesControlFrame", "BOTTOMRIGHT", "BOTTOMRIGHT", -5, 5 },  -- :586
    { "GuildLogButton", "BOTTOMLEFT", "BOTTOMLEFT", 190, 5 },            -- :592
}

local function LayoutFooter(f)
    for _, it in ipairs(FOOTER_SHIFTS) do
        local fr = Optional(f, it[1])
        if fr then
            E.ShiftRoot(fr, it[2], f, it[3], it[4], it[5] + FOOTER_DY, "CommunitiesFrame." .. it[1])
        end
    end
    for _, it in ipairs(FOOTER_BUTTONS) do
        local fr = Optional(f, it[1])
        if fr then
            E.ShiftRoot(fr, it[2], f, it[3], it[4], it[5] + FOOTER_BTN_DY, "CommunitiesFrame." .. it[1])
        end
    end
end

local function Apply()
    local f = _G.CommunitiesFrame
    if not f then
        E.Missing("CommunitiesFrame")
        return
    end

    SkinChrome(f)
    WithSub(f, "CommunitiesList", "CommunitiesFrame.CommunitiesList", SkinCommunitiesList)
    SkinChat(f)
    SkinMemberList(f)
    SkinControls(f)
    SkinBenefits(f)
    SkinDetails(f)

    for _, fk in ipairs({ "GuildFinderFrame", "CommunityFinderFrame" }) do
        local finder = Optional(f, fk)
        if finder then SkinFinder(finder, "CommunitiesFrame." .. fk) end
    end
    SkinInvitationHosts(f)
    SkinDialogs(f)
    LayoutFooter(f)
end

E.Register{
    key   = "communities",
    addon = "Blizzard_Communities",
    title = L["Guild & Communities"],
    hooks = InstallHooks,
    apply = Apply,
}
