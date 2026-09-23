------------------------------------------------------------
-- 配方：好友名單（FriendsFrame）
--
-- 涵蓋七塊：聯絡人／查詢／忽略名單（第三輪）＋ 頂部分頁、三種池化列、三個下拉、
-- 團隊／快速加入／近期盟友／招募好友四個子頁（第四輪）。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--
-- ### Blizzard_FriendsFrame
--   Blizzard_FriendsFrame.toc:3                          ## DefaultState: enabled（**非 LoD**）
--   Mainline/FriendsFrame.xml:3     FriendsTabTemplate ← TabSystemButtonTemplate，
--                                   **isTabOnTop = true**（:6）、Size y=24（:4）、
--                                   子框 `New`（NewFeatureLabelNoAnimateTemplate，:9）
--   Mainline/FriendsFrame.xml:21,34,42   FriendsFrameHeaderTemplate 與兩個衍生模板
--   Mainline/FriendsFrame.xml:50    FriendsFrameFriendDividerTemplate（一張**無名**的
--                                   UI-FriendsFrame-OnlineDivider，:54）
--   Mainline/FriendsFrame.xml:59    FriendsFrameFriendInviteTemplate
--                                   （Background 硬寫 `0, 0.694, 0.941, **0.05**`，:68）
--   Mainline/FriendsFrame.xml:82,98 邀請列的 DeclineButton／AcceptButton
--                                   （都是 UIMenuButtonStretchTemplate）
--   Mainline/FriendsFrame.xml:123,127,133  FriendsFrameButtonTemplate ← UIPanelButtonTemplate
--   Mainline/FriendsFrame.xml:139   FriendsPendingInviteHeaderButtonTemplate
--                                   （← UIMenuButtonStretchTemplate ＋ BG :145、
--                                    RightArrow :153、DownArrow :158、Flash :165）
--   Mainline/FriendsFrame.xml:196   FriendsFrameFriendPartyInviteTemplate（同上，:205 同色）
--   Mainline/FriendsFrame.xml:260   FriendsListButtonTemplate
--                                   （background :264、status :272、gameIcon :278、
--                                    name :284、info :291、Favorite :298、
--                                    travelPassButton :304、summonButton :335、
--                                    **highlight** :358 ＝ UI-QuestLogTitleHighlight）
--   Mainline/FriendsFrame.xml:366   IgnoreListButtonTemplate（name :370、HighlightTexture :381）
--   Mainline/FriendsFrame.xml:384   WhoListButtonTemplate（Name/Variable/Level/Class :388-414、
--                                    HighlightTexture :422）
--   Mainline/FriendsFrame.xml:425   WhoFrameColumnHeaderTemplate（Left/Middle/Right parentKey）
--   Mainline/FriendsFrame.xml:472   FriendsFrameTabTemplate ← PanelTabButtonTemplate
--   Mainline/FriendsFrame.xml:478   FriendsFrame（ButtonFrameTemplate）
--   Mainline/FriendsFrame.xml:482   $parentIcon ＝ FriendsFrameIcon
--   Mainline/FriendsFrame.xml:490   FriendsFrameTitleText
--   Mainline/FriendsFrame.xml:499   FriendsTabHeader（TabSystemOwnerTemplate）
--   Mainline/FriendsFrame.xml:501   FriendsTabHeader.TabSystem（TabSystemTemplate，
--                                   tabTemplate = FriendsTabTemplate :505）
--   Mainline/FriendsFrame.xml:512   FriendsFrameBattlenetFrame
--   Mainline/FriendsFrame.xml:545   BattlenetFrame.ContactsMenuButton
--                                   （**SquareIconButtonTemplate**，不是下拉美術）
--   Mainline/FriendsFrame.xml:581   BroadcastFrame（戰網廣播）
--   Mainline/FriendsFrame.xml:746   FriendsFrameStatusDropdown（WowStyle1DropdownTemplate）
--   Mainline/FriendsFrame.xml:845,889,1063  三個 WowScrollBoxList
--   Mainline/FriendsFrame.xml:863   **RecentAlliesFrame**（住在這裡，不是 Blizzard_RecentAllies）
--   Mainline/FriendsFrame.xml:873   FriendsFrame.IgnoreListWindow（ButtonFrameTemplate）
--   Mainline/FriendsFrame.xml:911,941,960-1050,1071  查詢頁
--   Mainline/FriendsFrame.xml:976   WhoFrameDropdown（WowStyle1DropdownTemplate）
--   Mainline/FriendsFrame.xml:1098-1105  FriendsFrameTab1..4
--   Mainline/FriendsFrame.lua:60    FRIENDSFRAME_SUBFRAMES 六個子頁的名字
--   Mainline/FriendsFrame.lua:340-391  三個 ScrollBox 的 view 設定（見下面「可勾的入口」）
--   Mainline/FriendsFrame.lua:450   FriendsFrame_Update（全域，**每次切頁都跑**）
--   Mainline/FriendsFrame.lua:462,487,494,500  FriendsFrameIcon 每次切頁重設材質
--   Mainline/FriendsFrame.lua:554   FriendsTabHeaderMixin:OnLoad → GenerateHeaderTabs
--   Mainline/FriendsFrame.lua:690   **FriendsTabMixin = CreateFromMixins(TabSystemButtonMixin)**
--   Mainline/FriendsFrame.lua:800   FriendsList_Update（全域）
--   Mainline/FriendsFrame.lua:932   IgnoreList_InitButton（全域）
--   Mainline/FriendsFrame.lua:965   IgnoreList_SetButtonSelected(button, selected)（全域）
--   Mainline/FriendsFrame.lua:1009  WhoList_InitButton（全域）
--   Mainline/FriendsFrame.lua:1050  WhoListButton_SetSelected(button, selected)（全域）
--   Mainline/FriendsFrame.lua:1889,1905,1916,1922  四支邀請列更新函式（全域）
--   Mainline/FriendsFrame.lua:1935  FriendsFrame_FriendButtonSetSelection(button, selected)（全域）
--   Mainline/FriendsFrame.lua:1943  FriendsFrame_UpdateFriendButton（全域）
--   Mainline/FriendsFrame.lua:1956,1968,1990,2021  button.background:SetColorTexture(...)
--
-- ### 共用模板
--   Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.xml:3,27-72,85-86,110,125
--   Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.lua:4,41,117,209,234
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:745,839  UIMenuButtonStretchTemplate
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:820,832,841,850,855  SetTextures
--   Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml:4,25,40,53-56  SquareIconButtonTemplate
--   Blizzard_SharedXML/Shared/Button/IconButtonTemplate.lua:2,30-38  IconButtonMixin
--   Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml:111  DialogBorderOpaqueTemplate
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:381  NineSlicePanelTemplate
--   Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:206  SearchBoxTemplate
--
-- ### 四個子頁
--   Blizzard_RaidFrame/Blizzard_RaidFrame_Mainline.toc:3      ## DefaultState: enabled（非 LoD）
--   Blizzard_RaidFrame/Mainline/RaidFrame.xml:138   **RaidFrame**（裸 Frame，自己零美術）
--   同檔 :145,182,205,217,235,242,249,259,260,265,276,287,292,303,309,321
--   同檔 :39,43-68,88   RaidInfoInstanceTemplate（列，HighlightTexture **無名**）
--   Blizzard_RaidFrame/Mainline/RaidFrame.lua:140  RaidInfoFrame_InitButton（全域）
--   Blizzard_RaidFrame/Mainline/RaidFrame.lua:171  RaidInfoFrame_SetButtonSelected（全域）
--   Blizzard_QuickJoin/Blizzard_QuickJoin.toc:3     ## DefaultState: enabled（非 LoD）
--   Blizzard_QuickJoin/QuickJoin.xml:11,15,42,48,68,70,76,82
--   Blizzard_QuickJoin/QuickJoin.lua:225,240,248   QuickJoinButtonMixin（**純表，不是 CreateFromMixins**）
--   Blizzard_RecentAllies/Blizzard_RecentAllies.toc:2          ## AllowLoad: both（非 LoD）
--   Blizzard_RecentAllies/Blizzard_RecentAlliesTemplates.xml:4,13,35,39,86,90,187,193
--   Blizzard_RecentAllies/Blizzard_RecentAlliesTemplates.lua:119,130,294,342
--   Blizzard_RecruitAFriend/Blizzard_RecruitAFriend.toc:3      ## DefaultState: enabled（非 LoD）
--   Blizzard_RecruitAFriend/RecruitAFriendFrame.xml:497,504,512-536,666,667,680,686,
--                                   709,717,740,746,753,761
--   Blizzard_RecruitAFriend/RecruitAFriendFrame.xml:434,441,449,457,494  RecruitListButtonTemplate
--   Blizzard_RecruitAFriend/RecruitAFriendFrame.lua:654,656,792,796,799,1610,1637
--
------------------------------------------------------------
-- ## 查證後跟計畫假設不一樣的六件事
--
-- 1. **好友名單不是隨需載入的**（TOC:3 `DefaultState: enabled`，沒有 LoadOnDemand）
--    ⇒ `addon = nil`。第三輪就確認過，這一輪重查一致。
-- 2. **頂部分頁跟 `Skin.Tab` 不是同一套。** 底部四顆（好友／查詢／團隊／快速加入）
--    是 `PanelTabButtonTemplate` 系，走 `Skin.Tab(..., "panel")`。
--    `FriendsTabHeader` 裡那排（聯絡人／近期盟友／招募好友）是 `TabSystemButtonTemplate`
--    系 ⇒ 第四輪新做的通用原語 `Skin.TabSystem`。
--    ⚠ 而且 **mixin 後置勾對它們沒有用**：`FriendsTabHeaderMixin:OnLoad`（.lua:554）
--      就呼叫 `GenerateHeaderTabs`（.lua:642），那比我們的 `PLAYER_LOGIN` 早太多。
--      所以選中態走第二條路 —— 把 `Engine.SyncTabSystemAll` 掛在全域
--      `FriendsFrame_Update`（.lua:450）後面，重讀 `LeftActive:IsShown()`。
--      完整機制寫在 `Core/Engine.lua` 的 `Engine.TrackTabSystem` 那一段。
-- 3. **三個「下拉」裡只有兩個是下拉。** `FriendsFrameStatusDropdown`（.xml:746）與
--    `WhoFrameDropdown`（.xml:976）是 `WowStyle1DropdownTemplate` ⇒ `Skin.Dropdown` 適用；
--    `BattlenetFrame.ContactsMenuButton`（.xml:545）是
--    **`SquareIconButtonTemplate`**（`DropdownButton` 的殼 ＋ 方鈕美術），
--    它的 Normal/Pushed/Disabled 是「按鈕的殼」而不是「按鈕的圖」
--    ⇒ 走 `Skin.IconButton` 的 `stripFrame`。
-- 4. **三種列的「選中」與「滑過」在暴雪那邊是同一張貼圖**
--    （`FriendsFrame_FriendButtonSetSelection` .lua:1935、`IgnoreList_SetButtonSelected`
--     .lua:965、`WhoListButton_SetSelected` .lua:1050，三支都是 `LockHighlight()`）。
--    跟成就分類列同一個問題 ⇒ 三種都走 `Skin.Row` 的 `ownHover`，選中態從
--    **後置勾的 `selected` 參數**（過 `Secret.ToBool`）來。
-- 5. **好友列的背景色帶是 5% 的淡色，不是可讀的資訊。**
--    `FriendsFrame_UpdateFriendButton` 每次更新都 `background:SetColorTexture(...)`
--    （.lua:1956/1968/1990/2021，三種：WOW 線上／BNET 線上／離線）——
--    也就是說**染色撐不過一次更新，只能 alpha**。而那個顏色有多淡，XML 裡的
--    邀請列硬寫了同一個值可以直接讀到：`0, 0.694, 0.941, **0.05**`（.xml:68,205）。
--    線上／離線的真正訊號留在**沒有被我們碰的**兩個地方：`status` 圖示
--    （.lua:1958-1963 四種狀態圖）與名字顏色（.lua:2039，離線是 `FRIENDS_GRAY_COLOR`）。
--    ⇒ 色帶一律 alpha 0，列底交給我們自己的 overlay。
-- 6. **`RecentAlliesFrame` 住在 `Blizzard_FriendsFrame` 裡**（.xml:863），
--    `Blizzard_RecentAllies` 整包只有虛擬模板。四個子頁的插件**全部不是 LoD**
--    （只有 `Blizzard_RaidUI` 是，而那一包我們不碰，見下面），所以不需要 `parts`。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 主框與 chrome
--
-- | 物件 | 動作 |
-- |---|---|
-- | FriendsFrame.NineSlice / .Bg / .TopTileStreaks / .PortraitContainer | SetAlpha(0) |
-- | FriendsFrame.TitleContainer.TitleText、FriendsFrameTitleText | SetTextColor |
-- | FriendsFrameIcon | （2026-09-24 起保留，不中和） |
-- | FriendsFrame.Inset 的 Bg / NineSlice | SetAlpha(0) |
-- | FriendsFrame.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | FriendsFrame.CloseButton 的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | FriendsFrameTab1..4 的 TabTextures（九張） | SetAlpha(0) |
-- | FriendsFrameTab1..4 | SetNormalFontObject(GameFontHighlightSmall) |
-- | **FriendsTabHeader.TabSystem 的三顆分頁：RotatedTextures（九張）** | SetAlpha(0) |
-- | **同三顆** | SetNormalFontObject(GameFontHighlightSmall)、HookScript("OnEnter"/"OnLeave") |
-- | 八顆 UIPanelButtonTemplate 的 Left/Right/Middle | SetAlpha(0) |
-- | 同八顆 | SetNormalFontObject(GameFontHighlight) |
-- | WhoFrameColumnHeader1..4 的 Left/Middle/Right | SetAlpha(0) |
-- | WhoFrameColumnHeader1..4 的 Highlight 貼圖 | SetColorTexture |
-- | WhoFrameEditBox 的 Left/Right/Middle / Backdrop | SetAlpha(0) |
-- | WhoFrameEditBox 的 searchIcon / clearButton.Icon / Instructions | SetVertexColor / SetTextColor |
-- | WhoFrameListInset 的 Bg / NineSlice | SetAlpha(0) |
-- | BroadcastFrame.Border 的九片 ＋ Bg | SetAlpha(0) |
-- | BroadcastFrame.EditBox 的九張 *Border | SetAlpha(0) |
-- | IgnoreListWindow 的整組 chrome（同 FriendsFrame） | SetAlpha(0) / SetTextColor / SetColorTexture |
-- | **FriendsFrameStatusDropdown / WhoFrameDropdown 的 Background** | SetAlpha(0) |
-- | **同兩顆的 Arrow** | SetVertexColor |
-- | **BattlenetFrame.ContactsMenuButton 的 Normal/Pushed/Disabled** | SetAlpha(0) |
-- | **同一顆的 Icon** | SetVertexColor |
-- | 七條 MinimalScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | 七條 MinimalScrollBar 的 Back/Forward.Texture | SetVertexColor |
--
-- ### 池化列（全部走 Engine.HookRows，只拿 frame 參照，不讀 elementData）
--
-- | 物件 | 動作 |
-- |---|---|
-- | 好友列的 background | SetAlpha(0) |
-- | 好友列的 highlight（GetHighlightTexture） | SetAlpha(0)（兩態都自己畫） |
-- | 好友列 | HookScript("OnEnter"/"OnLeave") |
-- | 邀請列 / 隊伍邀請列的 Background | SetAlpha(0) |
-- | 邀請列兩顆 UIMenuButtonStretch 的九張切片 | SetAlpha(0)；Highlight | SetColorTexture |
-- | 邀請標題列的 BG ＋ 九張切片 | SetAlpha(0)；RightArrow/DownArrow | SetVertexColor |
-- | 忽略列的 name | SetTextColor；GetHighlightTexture | SetAlpha(0) |
-- | 查詢結果列的 Name | SetTextColor；GetHighlightTexture | SetAlpha(0) |
-- | 好友列分隔線的無名貼圖 | SetVertexColor（**不中和**，GetRegions 掃） |
-- | 招募列的 DividerTexture | SetVertexColor（同上） |
-- | 團隊資訊列 / 快速加入列 / 近期盟友列 / 招募列 | 同上（各自的 parentKey 見下） |
--
-- hook（全部是後置勾，不換函式）：
--   * Engine 的三個 `PanelTemplates_*` 全域後置勾（底部分頁選中態）。
--   * `Engine.TabSystemHooks()` —— `TabSystemButtonArtMixin:SetTabSelected`
--     （對好友名單這三顆來不及，但對之後開的新視窗有用，理由見 Engine）。
--   * 全域後置勾 ×10：`FriendsFrame_Update`、`FriendsList_Update`、
--     `FriendsFrame_UpdateFriendButton`、`FriendsFrame_FriendButtonSetSelection`、
--     `FriendsFrame_UpdateFriendInviteButton`、`FriendsFrame_UpdatePartyInviteButton`、
--     `FriendsFrame_UpdateFriendInviteHeaderButton`、`FriendsFrame_UpdatePartyInviteHeaderButton`、
--     `IgnoreList_InitButton`＋`IgnoreList_SetButtonSelected`、
--     `WhoList_InitButton`＋`WhoListButton_SetSelected`、
--     `RaidInfoFrame_InitButton`＋`RaidInfoFrame_SetButtonSelected`。
--   * mixin 後置勾 ×7：`QuickJoinButtonMixin:Init` / `:SetSelected`、
--     `RecentAlliesEntryMixin:Initialize` / `:UpdateBackgroundForOnlineStatus` / `:SetSelected`、
--     `RecruitListButtonMixin:Init` / `:UpdateBackground`、
--     `RewardClaimingMixin:UpdateNextReward`。
--   * 池化列與分頁的 `HookScript("OnEnter"/"OnLeave")`（兩態都自己畫的那幾種）。
--
-- 寫入暴雪欄位：無。
-- 讀暴雪物件（契約的讀取例外）：
--   * 分頁的 `LeftActive:IsShown()`（`Engine.SyncTabSystem`，純 C 端布林）。
--   * 後置勾拿到的 `selected` / `online` 參數（過 `Secret.ToBool`）。
--   * `GetRegions()` / `GetChildren()` 找無名美術與認分頁（讀結構不讀值）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- ⚠ **跟「開聊天輸入框／密語／邀請入隊」有關的按鈕一律只做視覺，腳本一個都不掛。**
--   `FriendsFrameSendMessageButton` 的 OnClick 是 `ChatFrameUtil.SendTell` /
--   `SendBNetTell`（FriendsFrame.lua:1370-1380），那條路上只要有插件的 Lua，
--   `LAST_ACTIVE_CHAT_EDIT_BOX` 就髒到 /reload
--   （`.claude/notes/wow-121-chat-reply-secret-taint.md`）。同一條線上的還有：
--     好友列的 `OnClick`（FriendsFrame.lua:2391）、
--     快速加入列的 `OnHyperlinkClick`（QuickJoin.lua:288）與右鍵選單（:297）、
--     近期盟友的 `PartyButton`（→ `C_PartyInfo.InviteUnit`，
--       Blizzard_RecentAlliesTemplates.lua:122-127）與 `OpenMenu`（:346）、
--     招募列的右鍵 `UnitPopup_OpenMenu("RAF_RECRUIT", …)`（RecruitAFriendFrame.lua:706）、
--     團隊資訊列 Shift＋左鍵的 `ChatFrameUtil.InsertLink`（RaidFrame.lua:204-206）。
--   我們對它們只做「中和貼圖 ＋ 換字型物件 ＋ 掛一個不吃滑鼠的 overlay」。
--
-- * **`Blizzard_RaidUI` 整包**（團隊名冊那 40 顆格子、8 組框、16 顆職業鈕、拉出視窗）
--   —— `RaidGroupButtonTemplate` 繼承 `SecureUnitButtonTemplate`
--   （Blizzard_RaidUI.xml:76），是 STYLE.md ⑦ 的 C 級（單位框）。
--   而且它是唯一一個 `LoadOnDemand: 1`（Blizzard_RaidUI_Mainline.toc:2）、
--   只有進過團隊才載入的包。⇒ 團隊頁我們只做 `Blizzard_RaidFrame` 那一半
--   （空團隊提示、轉換團隊／團隊資訊兩顆鈕、勾選框、團隊資訊視窗）。
-- * **戰網頭像／遊戲圖示／線上狀態圖示**（`FriendsFrameBattlenetFrame` 的底圖、
--   好友列的 `gameIcon` 與 `status`、近期盟友的 `OnlineStatusIcon`）—— 身分與狀態，
--   不是裝飾。好友列的 `name` 顏色（離線灰／戰網藍）同理。
-- * **好友列的 `travelPassButton` / `summonButton`**、近期盟友的 `PartyButton`
--   —— 那三顆是「邀請／召喚」動作鈕，自帶一整套 atlas；只要一中和就分不出能不能按。
-- * **`FriendsFrameFriendDividerTemplate` 以外的兩個標題列模板**
--   （`FriendsFrameIgnoredHeaderTemplate` / `FriendsFrameBlockedInviteHeaderTemplate`，
--   .xml:34,42）—— 它們只有一條 `GameFontHighlightLeft` 的白字（.xml:25），沒有底材，
--   本來就不用動；而且 `factory(elementData.header)` 沒有 initializer（.lua:368），
--   勾不到。
-- * **`FriendsListFrame.RIDWarning`**（.xml:782）—— 自己是一層 85% 黑遮罩。
-- * **`BattlenetFrame.UnavailableInfoFrame`** —— 離線提示框，極少出現。
-- * **招募好友的 3D 場景與動畫**：`NextRewardButton.ModelScene`
--   （RecruitAFriendFrame.xml:636）、`RecruitActivityButtonTemplate.Model`（:394）、
--   `NextRewardButton.CircleMask`（:607，MaskTexture，動它會破圖）、
--   四組 `ClaimGlow*` 動畫（:643-661）。⇒ 內容底材規則與「3D 模型不碰」。
-- * **招募好友的兩個彈出視窗**（`RecruitAFriendRewardsFrame`、
--   `RecruitAFriendRecruitmentFrame`）—— `parent="UIParent"`，是另外兩個視窗，
--   不屬於好友名單這一頁。
-- * **近期盟友的分隔列**（`RecentAlliesDividerTemplate`，
--   Blizzard_RecentAlliesTemplates.xml:35）—— `SetElementFactory` 對它**沒有給
--   initializer**（同檔 .lua:17），勾不到；而 `RecentAlliesListMixin` 是在 XML 載入時
--   就被拷到框上的（陷阱 4），也追不上。好友列的分隔線有 `FriendsList_Update`
--   這支全域可以補掃，近期盟友沒有對應的全域 ⇒ 這一條留著，記在待驗證清單。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret
local L = ns.L

-- NineSliceUtil.ApplyLayout 建出來的九片，直接掛在框自己身上
-- （Blizzard_SharedXML/NineSlice.lua；同 Skins/Achievement.lua 的 BACKDROP_PIECES）
local NINE_SLICE_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

-- 戰網廣播輸入框自己的九張 Common-Input-Border-*（FriendsFrame.xml:604-658）
local BROADCAST_EDIT_BORDERS = {
    "TopLeftBorder", "TopRightBorder", "TopBorder",
    "BottomLeftBorder", "BottomRightBorder", "BottomBorder",
    "LeftBorder", "RightBorder", "MiddleBorder",
}

-- 好友列／邀請列的美術矩形：`background` 與 `highlight` 都是
-- `TOPLEFT 0,-1` → `BOTTOMRIGHT 0,+1`（FriendsFrame.xml:266-267, 360-361）。
-- overlay 照抄那個矩形，列與列之間就自然留下 1 點縫 ——「隔行靠底色分，不畫格線」。
local LIST_ROW_POINTS = {
    { "TOPLEFT", "TOPLEFT", 0, -1 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 1 },
}

-- 一條 MinimalScrollBar 掛在某個 parentKey 底下（好友／忽略／查詢三頁都是這個形狀）
local function SkinOwnedScrollBar(owner, key)
    local bar
    if owner and pcall(function() bar = owner.ScrollBar end) and bar then
        Skin.ScrollBar(bar, key)
    else
        E.Missing(key)
    end
end

------------------------------------------------------------
-- 池化列：共用的兩塊
------------------------------------------------------------
-- 「選中與滑過是同一張貼圖」的列一律走這一支。
-- ⚠ `selected` 是**後置勾的參數**，不是 elementData 的欄位（讀取例外表）。
local function RowSelection(row, selected)
    E.SetSelected(row, S.ToBool(selected) == true)
end

-- 一條「只有字、沒有底材」的列（忽略名單、查詢結果、團隊資訊）
local function ApplyPlainRow(row, key, fields)
    Skin.Row(row, key, { ownHover = true, points = LIST_ROW_POINTS })
    for _, f in ipairs(fields) do
        local fs
        if pcall(function() fs = row[f] end) and fs then
            E.TextColor(fs, T.text, key .. "." .. f)
        end
    end
end

------------------------------------------------------------
-- 聯絡人頁：好友列
------------------------------------------------------------
local function ApplyFriendRow(row)
    -- 背景色帶：只能 alpha（每次更新都 SetColorTexture，見檔頭第 5 點）
    E.NeutralizeKeys(row, { "background" }, "FriendsListButton")
    Skin.Row(row, "FriendsListButton", { ownHover = true, points = LIST_ROW_POINTS })
end

-- 邀請列與隊伍邀請列（`Background` 是 XML 寫死的 5% 淡藍，沒有任何 Lua 會重設）
local function ApplyInviteRow(row)
    E.NeutralizeKeys(row, { "Background" }, "FriendsFrameFriendInvite")
    local ov = E.Overlay(row, { key = "FriendsFrameFriendInvite", points = LIST_ROW_POINTS,
        noBorder = true })
    E.Paint(ov, T.fillInset)

    for _, k in ipairs({ "AcceptButton", "DeclineButton" }) do
        local btn
        if pcall(function() btn = row[k] end) and btn then
            -- 第九輪：接受 primary、拒絕 secondary
            Skin.StretchButton(btn, "FriendsFrameFriendInvite." .. k, {
                variant = k == "DeclineButton" and "secondary" or nil,
            })
        end
    end
end

-- 邀請標題列（`FriendsPendingInviteHeaderButtonTemplate`）
local function ApplyInviteHeaderRow(row)
    -- BG 是一張 UI-Background-Rock（.xml:145），跟九張銀色切片一起中和
    E.NeutralizeKeys(row, { "BG" }, "FriendsPendingInviteHeader")
    -- 第九輪：這是一條可收合的清單標題，不是動作按鈕 ⇒ secondary
    Skin.StretchButton(row, "FriendsPendingInviteHeader", { variant = "secondary" })

    -- ▶／▼ 是「展開了沒」的訊號，不中和、只染暗一階
    for _, k in ipairs({ "RightArrow", "DownArrow" }) do
        local tex
        if pcall(function() tex = row[k] end) and tex then
            E.VertexColor(tex, T.textDim, "FriendsPendingInviteHeader." .. k)
        end
    end
end

-- 分隔線（線上／離線之間那一條）。
--
-- ⚠ 它沒有 initializer（`factory("FriendsFrameFriendDividerTemplate")`，.lua:346）
--   ⇒ 沒有 mixin 可以勾。唯一的路是從全域 `FriendsList_Update`（.lua:800）之後
--   掃一次 ScrollBox。認人只看結構：這是名單裡唯一「一個 parentKey 都沒有」的列。
local function MatchDividerRow(row)
    if type(row) ~= "table" then return false end
    local hit
    local ok = pcall(function()
        hit = row.background == nil and row.name == nil and row.Name == nil
            and row.Text == nil and row.BG == nil and row.Background == nil
    end)
    return ok and hit
end

-- ⚠ **染暗一階，不中和。** 這一條線就是「以下是離線的好友」那個分界，是資訊不是裝飾；
--   中和掉之後名單上只剩「名字突然變灰」一個線索。它是一張**無名**貼圖
--   （.xml:54），指名不到 ⇒ 走 `Engine.TintRegions`。
local function ApplyDividerRow(row)
    E.TintRegions(row, T.textDim, "FriendsFrameFriendDivider")
end

------------------------------------------------------------
-- 聯絡人頁：其餘
------------------------------------------------------------
local function SkinFriendsList()
    local frame = _G.FriendsListFrame
    if not frame then
        E.Missing("FriendsListFrame")
        return
    end

    for _, name in ipairs({ "FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton" }) do
        local btn = _G[name]
        if btn then
            -- ⚠ 傳送訊息那顆會開聊天輸入框 —— 只做視覺，腳本一個都不掛（見檔頭）。
            -- 第九輪：新增好友 primary（這一頁的主動作）、傳送訊息 secondary
            Skin.Button(btn, name, {
                variant = name == "FriendsFrameSendMessageButton" and "secondary" or nil,
            })
        else
            E.Missing(name)
        end
    end

    SkinOwnedScrollBar(frame, "FriendsListFrame.ScrollBar")
end

------------------------------------------------------------
-- 頂部分頁（聯絡人／近期盟友／招募好友）
--
-- `FriendsTabTemplate` 的 `isTabOnTop = true`（FriendsFrame.xml:6）⇒ 分頁掛在內容
-- **上方**，與內容相連的是**下邊**，那一邊不畫。
------------------------------------------------------------
local function SkinHeaderTabs(f)
    local header
    if not (pcall(function() header = f.FriendsTabHeader end) and header) then
        E.Missing("FriendsFrame.FriendsTabHeader")
        return
    end

    local system
    if not (pcall(function() system = header.TabSystem end) and system) then
        E.Missing("FriendsFrame.FriendsTabHeader.TabSystem")
        return
    end
    Skin.TabSystemAll(system, "FriendsTabHeader.Tab", { onTop = true })

    -- 狀態下拉就住在 FriendsTabHeader 上（FriendsFrame.xml:746，
    -- 同時有全域名 `FriendsFrameStatusDropdown`）。文字是暴雪塞的一張狀態小圖
    -- （`SetSelectionTranslator`，.lua:612），不是文字顏色的問題 ⇒ 不給 textColor。
    --
    -- ⚠ **這一顆的寬度歸套組本體管，不歸這一份管。**
    --   暴雪把它 `SetWidth(51)`（`FriendsFrame.lua:589`），而 `Text` 的可用寬度是
    --   `51 + 1 − Arrow 的 atlas 寬 − 8`（`MenuTemplates.xml:14-24`：`Arrow` 是
    --   `useAtlasSize` 錨 `RIGHT x=1`，`Text` 從 `TOPLEFT x=8` 接到 `Arrow` 的 LEFT，
    --   `wordwrap="false"`）—— 內容是固定 16 寬的 `|T…tga:16:16:0:0|t`
    --   （同檔 `.lua:612`），餘裕只有一兩點，放不下就被截成「...」。
    --   那是**換皮之前就存在**的緊繃版面：這一份對這顆按鈕只做
    --   `Background:SetAlpha(0)`、`Arrow` 去飽和 ＋ `SetVertexColor`、自己的 overlay、
    --   以及 `HookScript("OnEnter"/"OnLeave")`（只碰 overlay）——
    --   `style1` 連 `Engine.DropdownText` 都不呼叫，字型物件與顏色一個字都沒動。
    --   ⇒ 加寬那件事住在 `MiliUI/Fix/Blizzard_FriendsStatusDropdown.lua`。
    --   **這一份不為它 `SetWidth`／`SetPoint`**（那是重排不是重畫），
    --   而且不必跟進：overlay 是錨點跟隨的，那顆變成幾寬都自動對上。
    local dd
    if pcall(function() dd = header.StatusDropdown end) and dd then
        Skin.Dropdown(dd, "FriendsFrameStatusDropdown", "style1")
    else
        E.Missing("FriendsFrameStatusDropdown")
    end
end

------------------------------------------------------------
-- 戰網廣播
------------------------------------------------------------
local function SkinBroadcast(battlenet)
    local broadcast
    if not (pcall(function() broadcast = battlenet.BroadcastFrame end) and broadcast) then
        E.Missing("FriendsFrameBattlenetFrame.BroadcastFrame")
        return
    end

    local border
    if pcall(function() border = broadcast.Border end) and border then
        -- DialogBorderOpaqueTemplate ＝ NineSlicePanelTemplate（九片）＋ 一張全黑的 Bg。
        -- Bg 也要中和：它在 BACKGROUND −5，我們的 overlay 在 −1 層，不中和就被它蓋住。
        E.NeutralizeKeys(border, NINE_SLICE_PIECES, "FriendsFrame.BroadcastFrame.Border")
        E.NeutralizeKeys(border, { "Bg" }, "FriendsFrame.BroadcastFrame.Border")
    else
        E.Missing("FriendsFrame.BroadcastFrame.Border")
    end
    Skin.Panel(broadcast, "FriendsFrame.BroadcastFrame")

    local eb
    if pcall(function() eb = broadcast.EditBox end) and eb then
        E.NeutralizeKeys(eb, BROADCAST_EDIT_BORDERS, "FriendsFrame.BroadcastFrame.EditBox")
        local ov = E.Overlay(eb, { key = "FriendsFrame.BroadcastFrame.EditBox" })
        E.Paint(ov, T.fillInset, T.border)

        local prompt
        if pcall(function() prompt = eb.PromptText end) and prompt then
            E.TextColor(prompt, T.textDisabled, "FriendsFrame.BroadcastFrame.EditBox.PromptText")
        end
    else
        E.Missing("FriendsFrame.BroadcastFrame.EditBox")
    end

    for _, key in ipairs({ "UpdateButton", "CancelButton" }) do
        local btn
        if pcall(function() btn = broadcast[key] end) and btn then
            -- 第九輪：更新 primary、取消 secondary
            Skin.Button(btn, "FriendsFrame.BroadcastFrame." .. key, {
                variant = key == "CancelButton" and "secondary" or nil,
            })
        else
            E.Missing("FriendsFrame.BroadcastFrame." .. key)
        end
    end
end

------------------------------------------------------------
-- 查詢頁
------------------------------------------------------------
local WHO_BUTTONS = {
    "WhoFrameWhoButton",
    "WhoFrameAddFriendButton",
    "WhoFrameGroupInviteButton",
}

local function SkinWhoFrame()
    local frame = _G.WhoFrame
    if not frame then
        E.Missing("WhoFrame")
        return
    end

    local eb = _G.WhoFrameEditBox
    if eb then
        -- SearchBoxTemplate 的三張切片 ＋ 搜尋圖示 ＋ 提示字，交給原語。
        Skin.EditBox(eb, "WhoFrameEditBox")
        -- 這一顆另外多一張 glues-characterSelect-searchbar 當底（FriendsFrame.xml:923）。
        E.NeutralizeKeys(eb, { "Backdrop" }, "WhoFrameEditBox")
    else
        E.Missing("WhoFrameEditBox")
    end

    local inset = _G.WhoFrameListInset
    if inset then
        Skin.Inset(inset, "WhoFrameListInset")
    else
        E.Missing("WhoFrameListInset")
    end

    for i = 1, 4 do
        local key = "WhoFrameColumnHeader" .. i
        local header = _G[key]
        if header then
            -- ⚠ `keepFont`：欄位表頭的 NormalFont 是
            --   `UserScaledFontGameHighlightSmall`（跟著玩家的文字大小設定縮放），
            --   換成固定字級的 `GameFontHighlight` 等於把那個縮放弄掉。
            -- 第九輪：欄位表頭不是動作按鈕 ⇒ secondary
            Skin.Button(header, key, { keepFont = true, variant = "secondary" })
        else
            E.Missing(key)
        end
    end

    for _, name in ipairs(WHO_BUTTONS) do
        local btn = _G[name]
        if btn then
            -- 第九輪：查詢 primary；加為好友／邀請入隊（對選中那一列的平行操作）secondary
            Skin.Button(btn, name, {
                variant = name ~= "WhoFrameWhoButton" and "secondary" or nil,
            })
        else
            E.Missing(name)
        end
    end

    -- 查詢條件下拉（地區／公會／種族），FriendsFrame.xml:976
    local dd = _G.WhoFrameDropdown
    if dd then
        Skin.Dropdown(dd, "WhoFrameDropdown", "style1")
    else
        E.Missing("WhoFrameDropdown")
    end

    SkinOwnedScrollBar(frame, "WhoFrame.ScrollBar")
end

------------------------------------------------------------
-- 忽略名單（FriendsFrame 右邊彈出來的那個小 ButtonFrameTemplate）
------------------------------------------------------------
local function SkinIgnoreList(parent)
    local win
    if not (pcall(function() win = parent.IgnoreListWindow end) and win) then
        E.Missing("FriendsFrame.IgnoreListWindow")
        return
    end

    Skin.PortraitChrome(win, "FriendsFrame.IgnoreListWindow")
    Skin.Panel(win, "FriendsFrame.IgnoreListWindow")

    local inset
    if pcall(function() inset = win.Inset end) and inset then
        Skin.Inset(inset, "FriendsFrame.IgnoreListWindow.Inset")
    else
        E.Missing("FriendsFrame.IgnoreListWindow.Inset")
    end

    local close
    if pcall(function() close = win.CloseButton end) and close then
        Skin.CloseButton(close, "FriendsFrame.IgnoreListWindow.CloseButton")
    else
        E.Missing("FriendsFrame.IgnoreListWindow.CloseButton")
    end

    local unignore
    if pcall(function() unignore = win.UnignorePlayerButton end) and unignore then
        Skin.Button(unignore, "FriendsFrame.IgnoreListWindow.UnignorePlayerButton")
    else
        E.Missing("FriendsFrame.IgnoreListWindow.UnignorePlayerButton")
    end

    SkinOwnedScrollBar(win, "FriendsFrame.IgnoreListWindow.ScrollBar")
end

------------------------------------------------------------
-- 子頁一：團隊（`Blizzard_RaidFrame` 那一半）
--
-- ⚠ `RaidFrame` 自己**零美術**（RaidFrame.xml:138 是一個裸 `<Frame>`，
--   連 `<Layers>` 都沒有）—— 這一頁的面板底來自 `FriendsFrame` 與 `FriendsFrameInset`，
--   所以主框什麼都不用做。要處理的只有它底下的幾個子框。
-- ⚠ `Blizzard_RaidUI`（團隊名冊那 40 顆格子）不碰，理由見檔頭。
------------------------------------------------------------
local RAID_INFO_LABEL_SLICES = { "Left", "Middle", "Right" }

local function ApplyRaidInfoRow(row)
    ApplyPlainRow(row, "RaidInfoInstance", { "name", "difficulty", "reset", "extended" })
end

local function SkinRaidFrame()
    local f = _G.RaidFrame
    if not f then
        E.Missing("RaidFrame")
        return
    end

    -- 「你不在團隊裡」那塊說明文字的捲軸（ScrollingFontTemplate 自己建的）
    local notIn = _G.RaidFrameNotInRaid
    if notIn then
        local bar
        if pcall(function() bar = notIn.ScrollingDescriptionScrollBar end) and bar then
            Skin.ScrollBar(bar, "RaidFrameNotInRaid.ScrollBar")
        end
    end

    for _, name in ipairs({ "RaidFrameConvertToRaidButton", "RaidFrameRaidInfoButton" }) do
        local btn = _G[name]
        if btn then
            -- ⚠ `keepFont`：這兩顆在 XML 裡自己指定了 `GameFontNormalSmall`
            --   （RaidFrame.xml:213-215, 231-233），換成 `GameFontHighlight` 會變大一級。
            -- 第九輪：轉換成團隊 primary、團隊資訊（開另一個小視窗）secondary
            Skin.Button(btn, name, {
                keepFont = true,
                variant = name == "RaidFrameRaidInfoButton" and "secondary" or nil,
            })
        else
            E.Missing(name)
        end
    end

    local check = _G.RaidFrameAllAssistCheckButton
    if check then
        Skin.CheckBox(check, "RaidFrameAllAssistCheckButton")
    else
        E.Missing("RaidFrameAllAssistCheckButton")
    end

    -- 團隊資訊視窗（按「團隊資訊」開的那個小視窗）
    local info = _G.RaidInfoFrame
    if not info then
        E.Missing("RaidInfoFrame")
        return
    end

    E.NeutralizeGlobals({ "RaidInfoDetailHeader", "RaidInfoDetailFooter" })

    local border
    if pcall(function() border = info.Border end) and border then
        E.NeutralizeKeys(border, NINE_SLICE_PIECES, "RaidInfoFrame.Border")
        E.NeutralizeKeys(border, { "Bg" }, "RaidInfoFrame.Border")
    end
    Skin.Panel(info, "RaidInfoFrame")

    -- 兩個欄位表頭跟查詢頁的 `WhoFrameColumnHeaderTemplate` 同一套三片切法，
    -- 但切片**只有全域名字**（`$parentLeft`…，RaidInfoHeaderTemplate，RaidFrame.xml:3）。
    for _, name in ipairs({ "RaidInfoInstanceLabel", "RaidInfoIDLabel" }) do
        local label = _G[name]
        if label then
            for _, slice in ipairs(RAID_INFO_LABEL_SLICES) do
                E.Neutralize(_G[name .. slice], name .. slice)
            end
            local ov = E.Overlay(label, { key = name })
            E.Paint(ov, T.fill, T.border)
        else
            E.Missing(name)
        end
    end

    for _, name in ipairs({ "RaidInfoExtendButton", "RaidInfoCancelButton" }) do
        local btn = _G[name]
        if btn then
            -- 第九輪：延長進度 primary、關閉 secondary
            Skin.Button(btn, name, {
                keepFont = true,
                variant = name == "RaidInfoCancelButton" and "secondary" or nil,
            })
        else
            E.Missing(name)
        end
    end

    local close = _G.RaidInfoCloseButton
    if close then
        Skin.CloseButton(close, "RaidInfoCloseButton")
    else
        E.Missing("RaidInfoCloseButton")
    end

    SkinOwnedScrollBar(info, "RaidInfoFrame.ScrollBar")
end

------------------------------------------------------------
-- 子頁二：快速加入
--
-- ⚠ 列的滑過與選中是 BORDER 層的兩張 atlas（`Highlight` / `Selected`，
--   QuickJoin.xml:42,48），由 Lua Show/Hide；而且 `QuickJoinButtonMixin:SetSelected`
--   （QuickJoin.lua:248-251）**每次都重設 `Highlight` 的 alpha**（0.5 或 0）
--   ⇒ 中和一定要放 reapply。`Background`（:15）反過來，全檔沒有任何一處重設，
--   apply 一次就夠。
------------------------------------------------------------
local function ApplyQuickJoinRow(row)
    E.NeutralizeKeys(row, { "Background" }, "QuickJoinButton")
    Skin.Row(row, "QuickJoinButton", { ownHover = true, points = LIST_ROW_POINTS })
end

local function ReapplyQuickJoinRow(row)
    E.NeutralizeKeys(row, { "Highlight", "Selected" }, "QuickJoinButton")
end

local function QuickJoinSelection(row, selected)
    ReapplyQuickJoinRow(row)
    RowSelection(row, selected)
end

local function SkinQuickJoin()
    local f = _G.QuickJoinFrame
    if not f then
        E.Missing("QuickJoinFrame")
        return
    end

    local btn
    if pcall(function() btn = f.JoinQueueButton end) and btn then
        -- MagicButtonTemplate ← UIPanelButtonTemplate（SharedUIPanelTemplates.xml:722）
        Skin.Button(btn, "QuickJoinFrame.JoinQueueButton")
    else
        E.Missing("QuickJoinFrame.JoinQueueButton")
    end

    SkinOwnedScrollBar(f, "QuickJoinFrame.ScrollBar")
end

------------------------------------------------------------
-- 子頁三：近期盟友
--
-- ⚠ 列的背景色帶是 `NormalTexture`（Blizzard_RecentAlliesTemplates.xml:187），
--   而 `RecentAlliesEntryMixin:UpdateBackgroundForOnlineStatus`（同檔 .lua:294-297）
--   每次都 `SetColorTexture` ⇒ 中和放 reapply，而且那一支自己也勾一份
--   （它會被 `InitializeStateDisplay` 單獨呼叫，不一定經過 `Initialize`）。
------------------------------------------------------------
local function ApplyRecentAllyRow(row)
    Skin.Row(row, "RecentAlliesEntry", { ownHover = true, points = LIST_ROW_POINTS })
end

-- `Skin.Row` 的 `ownHover` 已經把 `GetHighlightTexture()` 中和掉了；
-- 這裡只要重申色帶（`GetNormalTexture()` 每次被重新上色）。
local function ReapplyRecentAllyRow(row)
    if type(row.GetNormalTexture) ~= "function" then return end
    local ok, tex = pcall(row.GetNormalTexture, row)
    if ok and tex then E.Neutralize(tex, "RecentAlliesEntry.NormalTexture") end
end

local function SkinRecentAllies()
    local f = _G.RecentAlliesFrame
    if not f then
        E.Missing("RecentAlliesFrame")
        return
    end
    local list
    if pcall(function() list = f.List end) and list then
        SkinOwnedScrollBar(list, "RecentAlliesFrame.List.ScrollBar")
    else
        E.Missing("RecentAlliesFrame.List")
    end
end

------------------------------------------------------------
-- 子頁四：招募好友
--
-- ⚠ **`RewardClaiming.Background` 是羊皮紙，而且每次獎勵更新都 `SetAtlas`**
--   （`RewardClaimingMixin:UpdateNextReward`，RecruitAFriendFrame.lua:1638）
--   ⇒ 中和只能 alpha，而且要勾那一支重申。
-- ⚠ 列的色帶同理：`RecruitListButtonMixin:UpdateBackground`（同檔 :792-799）
--   每次 `SetColorTexture`。
-- ⚠ 3D 場景／模型／遮罩／動畫一律不碰（見檔頭）。
------------------------------------------------------------
local RAF_CLAIM_ART = {
    "Background", "Watermark",
    "Bracket_TopLeft", "Bracket_TopRight", "Bracket_BottomRight", "Bracket_BottomLeft",
}

-- ⚠ `DividerTexture`（.xml:457）跟好友名單那條分隔線是同一張圖、同一個語意
--   ⇒ 同樣染暗一階不中和。這個模板一人分飾兩角（招募者列／分隔列，
--   `RecruitListButtonMixin:Init` 的 :657-661 依 `elementData.isDivider` 分流），
--   我們不去讀那個旗標 —— 兩種長相各自成立就好。
local function ApplyRecruitRow(row)
    local divider
    if pcall(function() divider = row.DividerTexture end) and divider then
        E.VertexColor(divider, T.textDim, "RecruitListButton.DividerTexture")
    end
    Skin.Row(row, "RecruitListButton", { points = LIST_ROW_POINTS })
end

local function ReapplyRecruitRow(row)
    E.NeutralizeKeys(row, { "Background" }, "RecruitListButton")
end

local function SkinRecruitAFriend()
    local f = _G.RecruitAFriendFrame
    if not f then
        E.Missing("RecruitAFriendFrame")
        return
    end

    local claim
    if pcall(function() claim = f.RewardClaiming end) and claim then
        E.NeutralizeKeys(claim, RAF_CLAIM_ART, "RecruitAFriendFrame.RewardClaiming")

        local inset
        if pcall(function() inset = claim.Inset end) and inset then
            Skin.Inset(inset, "RecruitAFriendFrame.RewardClaiming.Inset")
        end

        local earn
        if pcall(function() earn = claim.EarnInfo end) and earn then
            E.TextColor(earn, T.text, "RecruitAFriendFrame.RewardClaiming.EarnInfo")
        end

        local btn
        if pcall(function() btn = claim.ClaimOrViewRewardButton end) and btn then
            Skin.Button(btn, "RecruitAFriendFrame.RewardClaiming.ClaimOrViewRewardButton")
        end

        -- 獎勵圖示外那圈棕環。圖示本身與 ModelScene 不碰。
        local next_
        if pcall(function() next_ = claim.NextRewardButton end) and next_ then
            E.NeutralizeKeys(next_, { "IconBorder" },
                "RecruitAFriendFrame.RewardClaiming.NextRewardButton")
        end
    else
        E.Missing("RecruitAFriendFrame.RewardClaiming")
    end

    local list
    if pcall(function() list = f.RecruitList end) and list then
        local header
        if pcall(function() header = list.Header end) and header then
            -- 那條石頭橫幅（atlas RecruitAFriend_Frame_StoneDivider，.xml:717）
            E.NeutralizeKeys(header, { "Background" }, "RecruitAFriendFrame.RecruitList.Header")
            local ov = E.Overlay(header, { key = "RecruitAFriendFrame.RecruitList.Header" })
            E.Paint(ov, T.fill, T.border)
            local fs
            if pcall(function() fs = header.RecruitedFriends end) and fs then
                E.TextColor(fs, T.text, "RecruitAFriendFrame.RecruitList.Header.RecruitedFriends")
            end
        end

        local inset
        if pcall(function() inset = list.ScrollFrameInset end) and inset then
            Skin.Inset(inset, "RecruitAFriendFrame.RecruitList.ScrollFrameInset")
        end

        SkinOwnedScrollBar(list, "RecruitAFriendFrame.RecruitList.ScrollBar")
    else
        E.Missing("RecruitAFriendFrame.RecruitList")
    end

    local recruit
    if pcall(function() recruit = f.RecruitmentButton end) and recruit then
        Skin.Button(recruit, "RecruitAFriendFrame.RecruitmentButton")
    else
        E.Missing("RecruitAFriendFrame.RecruitmentButton")
    end
end

------------------------------------------------------------
-- hook 安裝（**不過戰鬥閘**，理由見 STYLE.md ③ 的陷阱 4）
------------------------------------------------------------
local friendSweep, dividerSweep, ignoreSweep, whoSweep
local quickJoinSweep, recentAllySweep, recruitSweep, raidInfoSweep

-- 全域函式的後置勾：`Engine.HookRows` 的 `mixin = _G` 那條路
local function HookGlobalRows(spec)
    spec.mixin = _G
    return E.HookRows(spec)
end

local function InstallHooks()
    ------------------------------------------------------------
    -- 頂部分頁
    ------------------------------------------------------------
    -- 對好友名單這三顆來不及（OnLoad 就建好了），但裝著沒有壞處，
    -- 而且之後接別的新式視窗時它才是主力。
    E.TabSystemHooks()

    -- 真正讓選中態動起來的是這一支：`FriendsFrame_Update`（.lua:450）在
    -- `FriendsTabHeaderMixin:SelectTab`（.lua:680）與 `FriendsTabMixin:OnClick`
    -- （.lua:698）之後都會跑，我們在它後面重讀一次 `LeftActive:IsShown()`。
    if type(_G.FriendsFrame_Update) == "function" then
        hooksecurefunc("FriendsFrame_Update", function()
            E.SyncTabSystemAll()
        end)
    else
        E.Missing("FriendsFrame_Update")
    end

    ------------------------------------------------------------
    -- 聯絡人頁的四種列
    ------------------------------------------------------------
    friendSweep = HookGlobalRows{
        key    = "FriendsListButton",
        method = "FriendsFrame_UpdateFriendButton",
        match  = function(row) return type(row) == "table" and row.background ~= nil end,
        apply  = ApplyFriendRow,
    }
    HookGlobalRows{
        key     = "FriendsListButton.Selection",
        method  = "FriendsFrame_FriendButtonSetSelection",
        apply   = ApplyFriendRow,
        reapply = RowSelection,
    }

    for _, method in ipairs({ "FriendsFrame_UpdateFriendInviteButton",
                             "FriendsFrame_UpdatePartyInviteButton" }) do
        HookGlobalRows{
            key    = "FriendsFrameFriendInvite",
            method = method,
            apply  = ApplyInviteRow,
        }
    end
    for _, method in ipairs({ "FriendsFrame_UpdateFriendInviteHeaderButton",
                             "FriendsFrame_UpdatePartyInviteHeaderButton" }) do
        HookGlobalRows{
            key    = "FriendsPendingInviteHeader",
            method = method,
            apply  = ApplyInviteHeaderRow,
        }
    end

    -- 分隔線只能靠補掃（沒有 initializer 可以勾，見上面那一段）。
    -- `FriendsList_Update`（.lua:800）在每次名單重建之後跑，那時分隔列已經被
    -- `SetDataProvider`（.lua:895）借出來了。
    dividerSweep = function(row)
        if not MatchDividerRow(row) then return end
        if E.RowState[row] then return end
        E.RowState[row] = true
        pcall(ApplyDividerRow, row)
    end
    if type(_G.FriendsList_Update) == "function" then
        hooksecurefunc("FriendsList_Update", function()
            local box
            if pcall(function() box = _G.FriendsListFrame.ScrollBox end) and box then
                E.SweepRows(box, "FriendsListFrame.ScrollBox", dividerSweep)
            end
        end)
    else
        E.Missing("FriendsList_Update")
    end

    ------------------------------------------------------------
    -- 忽略名單／查詢結果
    ------------------------------------------------------------
    ignoreSweep = HookGlobalRows{
        key    = "IgnoreListButton",
        method = "IgnoreList_InitButton",
        match  = function(row) return type(row) == "table" and row.name ~= nil end,
        apply  = function(row) ApplyPlainRow(row, "IgnoreListButton", { "name" }) end,
    }
    HookGlobalRows{
        key     = "IgnoreListButton.Selection",
        method  = "IgnoreList_SetButtonSelected",
        apply   = function(row) ApplyPlainRow(row, "IgnoreListButton", { "name" }) end,
        reapply = RowSelection,
    }

    whoSweep = HookGlobalRows{
        key    = "WhoListButton",
        method = "WhoList_InitButton",
        match  = function(row) return type(row) == "table" and row.Variable ~= nil end,
        -- ⚠ 只把 `Name` 塗白：`Variable`/`Level` 本來就是 HIGHLIGHT_FONT_COLOR
        --   （FriendsFrame.xml:399,406），`Class` 的顏色是**職業色**
        --   （.lua:1017，資訊，不碰）。
        apply  = function(row) ApplyPlainRow(row, "WhoListButton", { "Name" }) end,
    }
    HookGlobalRows{
        key     = "WhoListButton.Selection",
        method  = "WhoListButton_SetSelected",
        apply   = function(row) ApplyPlainRow(row, "WhoListButton", { "Name" }) end,
        reapply = RowSelection,
    }

    ------------------------------------------------------------
    -- 四個子頁的列
    ------------------------------------------------------------
    raidInfoSweep = HookGlobalRows{
        key    = "RaidInfoInstance",
        method = "RaidInfoFrame_InitButton",
        match  = function(row) return type(row) == "table" and row.difficulty ~= nil end,
        apply  = ApplyRaidInfoRow,
    }
    HookGlobalRows{
        key     = "RaidInfoInstance.Selection",
        method  = "RaidInfoFrame_SetButtonSelected",
        apply   = ApplyRaidInfoRow,
        reapply = RowSelection,
    }

    quickJoinSweep = E.HookRows{
        key     = "QuickJoinButton",
        mixin   = _G.QuickJoinButtonMixin,
        method  = "Init",
        match   = function(row) return type(row) == "table" and row.Queues ~= nil end,
        apply   = ApplyQuickJoinRow,
        reapply = ReapplyQuickJoinRow,
    }
    E.HookRows{
        key     = "QuickJoinButton.Selection",
        mixin   = _G.QuickJoinButtonMixin,
        method  = "SetSelected",
        apply   = ApplyQuickJoinRow,
        reapply = QuickJoinSelection,
    }

    recentAllySweep = E.HookRows{
        key     = "RecentAlliesEntry",
        mixin   = _G.RecentAlliesEntryMixin,
        method  = "Initialize",
        match   = function(row) return type(row) == "table" and row.CharacterData ~= nil end,
        apply   = ApplyRecentAllyRow,
        reapply = ReapplyRecentAllyRow,
    }
    -- 色帶每次被 `SetColorTexture`（.lua:296）；那一支也會被單獨呼叫，所以各勾一份。
    E.HookRows{
        key          = "RecentAlliesEntry.Background",
        mixin        = _G.RecentAlliesEntryMixin,
        method       = "UpdateBackgroundForOnlineStatus",
        requireKnown = true,
        reapply      = ReapplyRecentAllyRow,
    }
    E.HookRows{
        key          = "RecentAlliesEntry.Selection",
        mixin        = _G.RecentAlliesEntryMixin,
        method       = "SetSelected",
        requireKnown = true,
        reapply      = RowSelection,
    }

    recruitSweep = E.HookRows{
        key     = "RecruitListButton",
        mixin   = _G.RecruitListButtonMixin,
        method  = "Init",
        match   = function(row) return type(row) == "table" and row.DividerTexture ~= nil end,
        apply   = ApplyRecruitRow,
        reapply = ReapplyRecruitRow,
    }
    E.HookRows{
        key          = "RecruitListButton.Background",
        mixin        = _G.RecruitListButtonMixin,
        method       = "UpdateBackground",
        requireKnown = true,
        reapply      = ReapplyRecruitRow,
    }

    -- 招募頁上半的羊皮紙每次換獎勵都 `SetAtlas`（.lua:1638）⇒ 重申中和。
    -- 這一支的第一個參數是 `RewardClaiming` 那個框本身，剛好符合 HookRows 的形狀。
    -- ⚠ 這裡**不能**用 `requireKnown`：`RewardClaiming` 不是池化列，沒有別的 hook
    --   會先把它登記進弱鍵表 —— 加了那個旗標就永遠不會跑。
    local function NeutralizeClaimArt(claim)
        E.NeutralizeKeys(claim, RAF_CLAIM_ART, "RecruitAFriendFrame.RewardClaiming")
    end
    E.HookRows{
        key     = "RecruitAFriendFrame.RewardClaiming",
        mixin   = _G.RewardClaimingMixin,
        method  = "UpdateNextReward",
        apply   = NeutralizeClaimArt,
        reapply = NeutralizeClaimArt,
    }
end

------------------------------------------------------------
-- 套用
------------------------------------------------------------
local function Apply()
    local f = FriendsFrame
    if not f then
        E.Missing("FriendsFrame")
        return
    end

    Skin.PortraitChrome(f, "FriendsFrame")

    -- 左上那張 60x60 的戰網／團隊圖示。
    -- ⚠ 一定要用 alpha：`FriendsFrame_Update` 每次切頁都 `SetTexture` 重設
    --   （FriendsFrame.lua:462,487,494,500），換材質撐不過一次切頁。
    -- 2026-09-24 使用者要求：先還原看效果（它是視窗的識別圖，跟寶庫的 TopDecor 同一類）。
    --   要再拿掉就把下面這一行的註解打開。
    -- E.NeutralizeGlobals({ "FriendsFrameIcon" })

    -- 查詢／團隊／快速加入頁的標題走的是這個 FontString，不是 TitleContainer.TitleText
    -- （FriendsFrame.lua:488,495,501）。兩個都要塗白，不然切頁就變回暗金色。
    E.TextColor(_G.FriendsFrameTitleText, T.text, "FriendsFrameTitleText")

    Skin.Panel(f, "FriendsFrame")

    local inset
    if pcall(function() inset = f.Inset end) and inset then
        Skin.Inset(inset, "FriendsFrame.Inset")
    else
        E.Missing("FriendsFrame.Inset")
    end

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "FriendsFrame.CloseButton")
    else
        E.Missing("FriendsFrame.CloseButton")
    end

    -- 底部四顆分頁（好友／查詢／團隊／快速加入）。第三、四顆平常是隱藏的，照樣要套。
    -- ⚠ 走 `Skin.TabGroup`：接縫錨在下一顆的左緣，相鄰兩顆共用一條 1px 黑線
    --   （第四輪的「往右多畫 7」會在選中的那一顆右邊留兩條平行線）。
    --   三、四兩顆排在**最後**，所以不必標 `hideable`：藏起來的框照樣有位置，
    --   前一顆的右緣錨在它的左緣上不會留洞。
    local tabs = {}
    for i = 1, 4 do
        local key = "FriendsFrameTab" .. i
        local tab = _G[key]
        if tab then
            tabs[#tabs + 1] = { tab = tab, key = key }
        else
            E.Missing(key)
        end
    end
    Skin.TabGroup(tabs, { kind = "panel", joined = "TOP" })

    SkinHeaderTabs(f)

    local battlenet = _G.FriendsFrameBattlenetFrame
    if battlenet then
        SkinBroadcast(battlenet)

        -- 聯絡人選單鈕（加好友／封鎖名單）。
        -- ⚠ 它是 `SquareIconButtonTemplate` 不是 `WowStyle1DropdownTemplate`
        --   （FriendsFrame.xml:545）：Normal/Pushed/Disabled 是「按鈕的殼」，
        --   圖在 OVERLAY 層的 `Icon`（同檔 :553）⇒ `stripFrame`。
        local menuBtn
        if pcall(function() menuBtn = battlenet.ContactsMenuButton end) and menuBtn then
            Skin.IconButton(menuBtn, "FriendsFrameBattlenetFrame.ContactsMenuButton",
                { stripFrame = true })
        else
            E.Missing("FriendsFrameBattlenetFrame.ContactsMenuButton")
        end
    else
        E.Missing("FriendsFrameBattlenetFrame")
    end

    SkinFriendsList()
    SkinWhoFrame()
    SkinIgnoreList(f)

    SkinRaidFrame()
    SkinQuickJoin()
    SkinRecentAllies()
    SkinRecruitAFriend()

    ------------------------------------------------------------
    -- 補掃已經建好的列（戰鬥中第一次開視窗、或 hook 裝好之前就借出去的那些）
    ------------------------------------------------------------
    local box
    if pcall(function() box = _G.FriendsListFrame.ScrollBox end) and box then
        E.SweepRows(box, "FriendsListFrame.ScrollBox", friendSweep, dividerSweep)
    end
    box = nil
    if pcall(function() box = f.IgnoreListWindow.ScrollBox end) and box then
        E.SweepRows(box, "FriendsFrame.IgnoreListWindow.ScrollBox", ignoreSweep)
    end
    box = nil
    if pcall(function() box = _G.WhoFrame.ScrollBox end) and box then
        E.SweepRows(box, "WhoFrame.ScrollBox", whoSweep)
    end
    box = nil
    if pcall(function() box = _G.RaidInfoFrame.ScrollBox end) and box then
        E.SweepRows(box, "RaidInfoFrame.ScrollBox", raidInfoSweep)
    end
    box = nil
    if pcall(function() box = _G.QuickJoinFrame.ScrollBox end) and box then
        E.SweepRows(box, "QuickJoinFrame.ScrollBox", quickJoinSweep)
    end
    box = nil
    if pcall(function() box = _G.RecentAlliesFrame.List.ScrollBox end) and box then
        E.SweepRows(box, "RecentAlliesFrame.List.ScrollBox", recentAllySweep)
    end
    box = nil
    if pcall(function() box = _G.RecruitAFriendFrame.RecruitList.ScrollBox end) and box then
        E.SweepRows(box, "RecruitAFriendFrame.RecruitList.ScrollBox", recruitSweep)
    end
end

E.Register{
    key   = "friends",
    addon = nil,                       -- Blizzard_FriendsFrame 的 TOC 是 DefaultState: enabled、非 LoD
    title = L["Friends List"],
    hooks = InstallHooks,
    apply = Apply,
}
