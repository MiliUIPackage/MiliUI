------------------------------------------------------------
-- 配方：地城與團隊搜尋器（PVEFrame ＋ 地城搜尋／團隊搜尋／預組隊伍）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_GroupFinder/Blizzard_GroupFinder_Mainline.toc:3
--       `## DefaultState: enabled`、**沒有** LoadOnDemand ⇒ `addon = nil`
--   Blizzard_GroupFinder/Mainline/PVEFrame.xml:67    PVEFrame（PortraitFrameTemplate）
--   Blizzard_GroupFinder/Mainline/PVEFrame.xml:74-154
--       $parentBlueBg／TLCorner／TRCorner／BRCorner／BLCorner／LLVert／RLVert／
--       BottomLine／TopLine／TopFiligree／BottomFiligree
--       —— 十一張 `Interface\Common\bluemenu-*`，**只有全域名字、沒有 parentKey**
--   Blizzard_GroupFinder/Mainline/PVEFrame.xml:158   $parentLeftInset（InsetFrameTemplate）
--   Blizzard_GroupFinder/Mainline/PVEFrame.xml:165,175,183  PVEFrameTab1..3（PanelTabButtonTemplate）
--   Blizzard_GroupFinder/Mainline/PVEFrame.xml:197   GroupFinderFrame
--   Blizzard_GroupFinder/Mainline/PVEFrame.xml:3     GroupFinderGroupButtonTemplate
--       bg（bluemenu-main 切片）／$parentRing（parentKey ring）／$parentIcon（icon，
--       被 CircleMask 遮成圓形）／$parentName（name，GameFontNormalLarge）
--       ＋ HighlightTexture（224x80，**比按鈕矩形 203x60 大一圈**）
--   Blizzard_GroupFinder/Mainline/PVEFrame.xml:234   PVEFrame.shadows（三張無名貼圖）
--   Blizzard_GroupFinder/Mainline/PVEFrame.lua:382   GroupFinderFrame_SelectGroupButton(index)
--       選中態＝`button.bg:SetTexCoord(...)`，**全域函式** ⇒ 後置勾拿得到 index
--   Blizzard_GroupFinder/Mainline/PVEFrame.lua:291   GroupFinderFrameButton_SetEnabled
--       停用時 `button.name:SetFontObject("GameFontDisableLarge")`（只在狀態**改變**時跑）
--   Blizzard_GroupFinder/Mainline/PVEFrame.lua:149   PVEFrame_HideLeftInset（Hide 那十一張）
--
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:134   LFDParentFrame
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:141   $parentRoleBackground（UI-LFG-BlueBG）
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:149   TopTileStreaks
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:158   $parentInset（InsetFrameTemplate）
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:167   $parentBackground（UI-LFG-BACKGROUND-QUESTPAPER）
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:176-218  四顆角色鈕
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:219   $parentTypeDropdown（WowStyle1DropdownTemplate）
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:236,265,284  三條捲軸
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:319   $parentFindGroupButton（MagicButtonTemplate）
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:343,354,371  兩塊遮罩 ＋ NoLFDWhileLFR
--   Blizzard_GroupFinder/Mainline/LFDFrame.lua:33    ButtonFrameTemplate_HideAttic(self)
--       ⇒ **TopTileStreaks 暴雪自己就藏了**，我們的中和只是保險
--   Blizzard_GroupFinder/Shared/LFGFrame.xml:3       LFGRoleButtonTemplate
--       checkButton（checkbox-minimal／checkmark-minimal，**沒有 HighlightTexture**）、
--       lockedIndicator、alert、NormalTexture＝角色圖示（GetIconForRole）
--   Blizzard_GroupFinder/Shared/LFGFrame.xml:164     LFGRoleButtonWithBackgroundTemplate
--       $parentBackground（parentKey `background`，GetBackgroundForRole 的 80x80 圓底）
--   Blizzard_GroupFinder/Shared/LFGFrame.lua:401,414,434  background 被 Show/Hide（**不是** alpha）
--   Blizzard_GroupFinder/Shared/LFGFrame.lua:1254    background:SetTexture(backgroundTexture)
--       —— 隨地城換的羊皮紙，第五輪起**中和**（理由見下面第 6 點）
--   Blizzard_GroupFinder/Shared/LFGFrame.xml:979,1101  LFGCooldownCoverTemplate／LFGBackfillCoverTemplate
--
--   Blizzard_GroupFinder/Mainline/LFGFrame.xml:227   LFGSpecificChoiceTemplate
--       （＝指定地城清單的列）heroicIcon／level／instanceName／lockedIndicator
--       ＋ $parentEnableButton（parentKey `enableButton`，UI-CheckBox-* 那一組）
--       ＋ $parentExpandOrCollapseButton（UI-Plus/MinusButton-UP ＋ 同一張 Hilight）
--       ⚠ 列本身是 `<Frame>`，**一張底圖都沒有**（也沒有 HighlightTexture）
--   Blizzard_GroupFinder/Mainline/LFDFrame.xml:21    LFDFrameDungeonChoiceTemplate
--   Blizzard_GroupFinder/Mainline/LFDFrame.lua:296,312
--       LFDQueueFrameSpecificList_InitButton／LFDQueueFrameFollowerList_InitButton
--       —— 兩支都是**全域函式**，`SetElementInitializer` 的匿名閉包只是轉呼叫它們
--   Blizzard_GroupFinder/Shared/LFGFrame.lua:1676,1737-1742
--       LFGDungeonListButton_SetDungeon —— **每次**都 `enableButton:SetCheckedTexture(路徑)`
--       （多選 UI-MultiCheck／單選 UI-CheckBox-Check 兩組）⇒ 我們的顏色要放 reapply；
--       ＋ 展開鈕每次 `SetNormalTexture(UI-Plus/MinusButton-UP)`（同檔 :1692,1694）
--   Blizzard_GroupFinder/Mainline/LFGFrame.xml:753   LFGRewardFrameTemplate
--       $parentTitle（**QuestTitleFontBlackShadow**）／$parentDescription（QuestFont）／
--       $parentRewardsLabel（同 Title）／$parentRewardsDescription／$parentXPLabel／
--       $parentXPAmount（NumberFontNormalLarge）／$parentItem1／$parentMoneyReward
--   Blizzard_GroupFinder/Mainline/LFGFrame.xml:685   LFGRewardsLootTemplate ← LargeItemButtonTemplate
--   Blizzard_ItemButton/Mainline/ItemButtonTemplate.xml:167,174,180,188
--       LargeItemButtonTemplate：Icon（39x39，TOPLEFT）／NameFrame（UI-QuestItemNameFrame
--       的雕花名牌，128x64）／Name（GameFontHighlight，白）／IconBorder
--   Blizzard_GroupFinder/Shared/LFGFrame.lua:1224-1228  LFGRewardsFrame_OnLoad
--       description／rewardsDescription／xpLabel **在 OnLoad 就被設成白 (1,1,1)**
--   Blizzard_GroupFinder/Shared/LFGFrame.lua:1416,1479-1485  LFGRewardsFrame_SetItemButton
--       —— **全域函式**；`_G[parentName.."Item"..index]` 動態建立，並呼叫
--       `SetItemButtonQuality` ＋ `frame.IconBorder:Show()/Hide()`
--   Blizzard_Fonts_Shared/Shared/GameFontStyles.xml:225  QuestTitleFontBlackShadow
--       ＝ **金色 (1, .82, 0) ＋ 黑色陰影**（名字裡的 Black 指的是陰影，不是字）
--   Blizzard_FrameXMLBase/Constants.lua:210-218  QuestDifficultyColors
--       —— 指定地城清單的字色全部是亮色（紅／橘／金／綠／灰）
--
--   Blizzard_GroupFinder/Shared/RaidFinder.xml:15    RaidFinderFrame
--   Blizzard_GroupFinder/Shared/RaidFinder.xml:22    $parentRoleBackground（橘色漸層貼圖）
--   Blizzard_GroupFinder/Shared/RaidFinder.xml:57,63 $parentRoleInset／$parentBottomInset
--   Blizzard_GroupFinder/Shared/RaidFinder.xml:77    $parentBackground（QUESTPAPER）
--   Blizzard_GroupFinder/Shared/RaidFinder.xml:86-128  四顆角色鈕
--   Blizzard_GroupFinder/Shared/RaidFinder.xml:129   $parentSelectionDropdown
--   Blizzard_GroupFinder/Shared/RaidFinder.xml:144   $parentScrollFrame（ScrollFrameTemplate）
--   Blizzard_GroupFinder/Shared/RaidFinder.xml:194,215  IneligibleFrame ＋ LeaveQueueButton
--   Blizzard_GroupFinder/Shared/RaidFinder.xml:239   $parentFindRaidButton（MagicButtonTemplate）
--
--   Blizzard_GroupFinder/Mainline/LFGList.xml:921    LFGListFrame
--   Blizzard_GroupFinder/Mainline/LFGList.xml:927,993,1043,1259,1559  五個 LFGListPanelTemplate
--   Blizzard_GroupFinder/Mainline/LFGList.xml:955,1005,1594  Inset.CustomBG（groupfinder-background）
--   Blizzard_GroupFinder/Mainline/LFGList.xml:1062   SearchPanel.FilterButton（WowStyle1FilterDropdownTemplate）
--   Blizzard_GroupFinder/Mainline/LFGList.xml:1067   SearchPanel.SearchBox（SearchBoxTemplate，secureReferenceKey）
--   Blizzard_GroupFinder/Mainline/LFGList.xml:1083   SearchPanel.AutoCompleteFrame（五張框線）
--   Blizzard_GroupFinder/Mainline/LFGList.xml:1130,1411  兩顆 RefreshButton（UI-SquareButton-*）
--   Blizzard_GroupFinder/Mainline/LFGList.xml:1167,1368,1587  三個 InsetFrameTemplate
--   Blizzard_GroupFinder/Mainline/LFGList.xml:1196,1466,1686  三條 MinimalScrollBar
--   Blizzard_GroupFinder/Mainline/LFGList.xml:800   LFGListSearchEntryTemplate
--       Highlight（**HIGHLIGHT 層**，groupfinder-highlightbar-blue）
--   Blizzard_GroupFinder/Mainline/LFGList.xml:300   LFGListApplicantTemplate
--       DeclineButton／InviteButton／InviteButtonSmall（UIMenuButtonStretchTemplate）
--   Blizzard_GroupFinder/Mainline/LFGList.xml:753   LFGListColumnHeaderTemplate（Left/Right/Middle）
--   Blizzard_GroupFinder/Mainline/LFGList.xml:575,639  LFGListOptionCheckButtonTemplate／RequirementTemplate
--   Blizzard_GroupFinder/Mainline/LFGList.xml:1644  EntryCreation.ActivityFinder.Dialog
--   Blizzard_GroupFinder/Mainline/LFGList.lua:2866  LFGListSearchPanel_InitButton(button, elementData)
--   Blizzard_GroupFinder/Mainline/LFGList.lua:1888  LFGListApplicationViewer_InitButton(button, elementData)
--       —— 兩支都是**全域函式**，`SetElementInitializer` 的匿名閉包只是轉呼叫它們
--   Blizzard_GroupFinder/Mainline/LFGList.lua:3523,3530  搜尋結果列的 Highlight 由暴雪 Show/Hide
--
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:544,597,631
--       PortraitFrameTemplate ← PortraitFrameTexturedBaseTemplate ← PortraitFrameBaseTemplate
--       ⇒ PVEFrame 有 NineSlice／Bg／TopTileStreaks／PortraitContainer／TitleContainer
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:722  MagicButtonTemplate ← UIPanelButtonTemplate
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:745  UIMenuButtonStretchTemplate（九片）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:820,832,850,855
--       UIMenuButtonStretchMixin:SetTextures —— 只 `SetTexture`，**不碰 alpha**
--       ⇒ 九片用 alpha 中和撐得過按下／顯示／啟用
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:372,481,486
--       PanelTemplates_UpdateTabs → SelectTab／DeselectTab／SetDisabledTabState
--       ⇒ Engine 的三個全域後置勾涵蓋 PVEFrame 的三顆分頁
--   Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:72
--       InputScrollFrameTemplate ← ScrollFrameTemplate，九張 `*Tex` 切片
--
-- 查證後跟計畫假設不一樣的五件事：
--   1. **`Blizzard_GroupFinder` 不是隨需載入的**（TOC 是 DefaultState: enabled）⇒
--      外框、地城搜尋、團隊搜尋、預組隊伍全部住在同一個 `addon = nil` 的單元裡。
--      隨需載入的只有 PvP（Blizzard_PVPUI）與傳奇鑰石（Blizzard_ChallengesUI），
--      那兩塊各自一份配方檔，但**共用 `pve` 這一個設定開關**（玩家看到的是一個視窗）。
--   2. **左側大類按鈕的選中態不是 Show/Hide，是 `bg:SetTexCoord`**
--      （PVEFrame.lua:382）。引擎驅動不了，只能勾那一支全域函式；而它的
--      HighlightTexture 是 224x80、比按鈕矩形 203x60 大一圈（跟成就分類列同型），
--      所以滑過也不能交給引擎 ⇒ `Skin.Row` 的 `opts.ownHover`。
--   3. ~~地城／團隊搜尋的羊皮紙是內容底材，留著~~ —— **第五輪推翻**，見第 6 點。
--   4. **角色鈕的圖示是 `NormalTexture` 本身**（`SetNormalAtlas(GetIconForRole(...))`，
--      LFGFrame.lua:2236），不是獨立的 Icon 貼圖 ⇒ **不能中和**，只能中和它背後的
--      `background` 圓底。勾選框（`checkButton`）才是我們接管的部分。
--   5. **搜尋結果列幾乎不用做。** `ResultBG` 本來就是白 4% 的平面矩形、
--      `BackgroundTexture` 是申請狀態的紅／綠／黃（資訊），兩張都不該動；
--      唯一格格不入的是 HIGHLIGHT 層那條藍色滑過帶 ⇒ 只換它的長相。
--
-- 第五輪查證後推翻的三件事：
--   6. **地城／團隊搜尋的羊皮紙可以換掉 —— 上面一條深色字都沒有。**
--      第四輪的「留著」是照內容底材規則的預設值走的，沒有真的去查字色。查完是：
--        * `LFGRewardsFrame_OnLoad`（LFGFrame.lua:1224-1228）在 OnLoad 就把
--          `description`／`rewardsDescription`／`xpLabel` 設成 **白 (1,1,1)**，
--          而且那一支**只跑一次**、之後沒有任何路徑重設 ⇒ 沒有東西要接管。
--        * `title` 與 `rewardsLabel` 是 `QuestTitleFontBlackShadow`
--          （GameFontStyles.xml:225）—— 那個名字指的是**陰影**是黑的，字本身是
--          **金色 (1, .82, 0)**。
--        * `xpAmount` 是 `NumberFontNormalLarge`（白）、物品名是 `GameFontHighlight`
--          （白）、數量是 `HIGHLIGHT_FONT_COLOR` 或貨幣色。
--        * 隨從頁的 `$parentTitle` 同樣是金的、`$parentDescription` 在 XML 直接寫
--          `<Color color="WHITE_FONT_COLOR"/>`（LFDFrame.xml:298-309）。
--        * 指定地城清單的字全部走 `QuestDifficultyColors`（Constants.lua:210-218），
--          最暗的一格是 `header` 的 0.7 灰 —— 在 `fillInset`（0.08）上照樣讀得到。
--      ⇒ 換底**零**文字接管，內容底材規則的前提（「把底拿掉之後字還讀得出來嗎」）
--        成立。羊皮紙一中和，第四輪連帶不做的兩樣（清單列、獎勵格）也跟著解禁。
--   7. **獎勵格不是 `ItemButton` intrinsic，是 `LargeItemButtonTemplate`**
--      （ItemButtonTemplate.xml:167）：圖示只佔左邊 39x39、右邊是一張
--      `UI-QuestItemNameFrame` 的雕花名牌。`Skin.ItemButton` 直接套會把品質方框
--      畫成整顆 147x41 的長方形 ⇒ 配方自己的 local 小函式，方框用 `anchorTo`
--      錨在 `Icon` 上。重畫仍然走 Engine 既有的兩個全域後置勾
--      （`LFGRewardsFrame_SetItemButton` 裡呼叫 `SetItemButtonQuality`）。
--   8. **指定地城清單的列一張底圖都沒有**（`LFGSpecificChoiceTemplate` 是裸
--      `<Frame>`，LFGFrame.xml:227）⇒ 沒有「列」要畫，只有勾選框與展開鈕要接管。
--
------------------------------------------------------------
-- ## taint 接觸面清單（暴雪物件）
--
-- | 物件 | 動作 |
-- |---|---|
-- | PVEFrame 的 NineSlice / Bg / TopTileStreaks / PortraitContainer | SetAlpha(0) |
-- | PVEFrame.TitleContainer.TitleText | SetTextColor |
-- | PVEFrameBlueBg 等十一張 bluemenu 貼圖 | SetAlpha(0) |
-- | PVEFrame.shadows 的三張無名貼圖 | SetAlpha(0)（走 GetRegions） |
-- | PVEFrame.Inset 的 Bg / NineSlice | SetAlpha(0) |
-- | PVEFrame.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | PVEFrame.CloseButton 的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | PVEFrameTab1..3 的 TabTextures（九張） | SetAlpha(0) |
-- | PVEFrameTab1..3 | SetNormalFontObject(GameFontHighlightSmall) |
-- | GroupFinderFrame.groupButton1..4 的 bg | SetAlpha(0) |
-- | 同四顆的 ring | SetDesaturated(true)（Engine.Desaturate）＋ SetVertexColor |
-- | 同四顆的 HighlightTexture | SetAlpha(0)（改由 overlay 自己畫滑過） |
-- | 同四顆的 name | SetTextColor |
-- | LFDParentFrameRoleBackground、LFDParentFrame.TopTileStreaks | SetAlpha(0) |
-- | RaidFinderFrameRoleBackground | SetAlpha(0) |
-- | **LFDQueueFrameBackground、RaidFinderQueueFrameBackground**（羊皮紙） | SetAlpha(0) |
-- | 七個 InsetFrameTemplate 的 Bg / NineSlice | SetAlpha(0) |
-- | 八顆角色鈕的 background | SetAlpha(0) |
-- | 八顆角色鈕的 checkButton 的 Normal/Pushed/Disabled 貼圖 | SetAlpha(0) |
-- | 同八顆的 Checked / DisabledChecked 貼圖 | **SetVertexColor**（職業色，**保留勾的形狀**） |
-- | 兩個獎勵框的 MoneyReward、動態建立的 Item1..N 的 NameFrame / IconBorder | SetAlpha(0) |
-- | 同上的 Icon | SetTexCoord（裁邊）；品質色 | Engine.PassBorderColor（轉交） |
-- | 指定／隨從地城清單列的 enableButton 的 Normal/Pushed/Disabled | SetAlpha(0) |
-- | 同上的 Checked / DisabledChecked | SetColorTexture（職業色，**每次 Init 重下**） |
-- | 同上的 expandOrCollapseButton 的 NormalTexture | SetDesaturated ＋ SetVertexColor |
-- | 三顆 WowStyle1Dropdown 的 Background | SetAlpha(0)；Arrow | SetVertexColor |
-- | LFGListFrame.SearchPanel.FilterButton 的 Background | SetAlpha(0) |
-- | 下拉左邊的說明字（…DropdownName） | SetTextColor |
-- | 十九顆 UIPanelButton 系的 Left/Right/Middle | SetAlpha(0) ＋ SetNormalFontObject |
-- | 四顆欄位表頭的 Left/Middle/Right | SetAlpha(0)（`keepFont`，字型物件不換） |
-- | 兩顆 RefreshButton 的 Normal/Pushed/Disabled | SetAlpha(0)；Icon | SetVertexColor |
-- | SearchBox / EntryBox / 五個需求欄 EditBox 的 Left/Right/Middle | SetAlpha(0) |
-- | 同上的 searchIcon / clearButton.Icon / Instructions | SetVertexColor / SetTextColor |
-- | 八顆 UICheckButton 系的 Normal/Pushed/Disabled | SetAlpha(0)；Checked | SetColorTexture |
-- | LFGListFrame 五個面板的 Inset.CustomBG | SetAlpha(0) |
-- | ApplicationViewer.InfoBackground | SetAlpha(0) |
-- | AutoCompleteFrame 的五張框線 | SetAlpha(0) |
-- | ActivityFinder.Dialog 的 Bg ＋ Border 九片 ＋ BorderFrame.NineSlice | SetAlpha(0) |
-- | Description（InputScrollFrameTemplate）的九張 *Tex | SetAlpha(0) |
-- | 七條 MinimalScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | 同七條的 Back/Forward.Texture | SetVertexColor |
-- | 搜尋結果列的 Highlight（HIGHLIGHT 層） | SetAlpha(1) ＋ SetColorTexture |
-- | 申請者列三顆按鈕的九片 UI-Silver-Button | SetAlpha(0) ＋ SetNormalFontObject |
-- | 以上各框 | CreateFrame 掛自己的 overlay（不吃滑鼠、零腳本） |
--
-- hook（這一輪新增的，逐支列在下面）：
--   1. `hooksecurefunc("GroupFinderFrame_SelectGroupButton", fn)`
--      —— 左側大類按鈕的選中態。hook 裡只做兩件事：型別檢查傳進來的 `index`
--         （純數字參數，不是 elementData 的欄位），然後對**我們自己的** overlay
--         呼叫 `Engine.SetSelected`。不讀暴雪的任何欄位、不寫任何欄位。
--   2. `Engine.HookRows{ mixin = _G, method = "LFGListSearchPanel_InitButton" }`
--      —— 搜尋結果列。`apply` 只做一件事：把列自己的 `Highlight`（HIGHLIGHT 層那張
--         藍色帶）換成白 8%。**沒有 reapply**（暴雪只 Show/Hide 它，不重設材質），
--         所以第二次之後 hook 第一行查完弱鍵表就返回。
--         ⚠ 傳進來的第二個參數 `elementData` **一次都沒有被讀**（沒有 reapply ⇒
--            Engine 根本不會把它交出來）。resultID、隊長名字、活動名稱碰都沒碰。
--   3. `Engine.HookRows{ mixin = _G, method = "LFGListApplicationViewer_InitButton" }`
--      —— 申請者列。`apply` 只做一件事：把列上的三顆 `UIMenuButtonStretchTemplate`
--         （邀請／拒絕／小邀請）的九片銀色貼圖中和掉並補 overlay。
--         同樣**沒有 reapply**、同樣不讀 `elementData`、不讀 applicantID。
--         列底本身（`Background`，暴雪自己在 InitButton 裡做隔行明暗）不碰。
--   4. `Engine.HookRows{ mixin = _G, method = "LFDQueueFrameSpecificList_InitButton" }`
--      ＋ 同一組 apply/reapply 的 `…FollowerList_InitButton`（第五輪新增）
--      —— 指定／隨從地城清單的池化列。兩支都是**全域函式**（LFDFrame.lua:296,312），
--         傳進來的第二個參數 `elementData` **一次都沒有被讀**（apply／reapply 的
--         簽章只收 row）。apply＝勾選框套皮、reapply＝重下勾選框的顏色與展開鈕的
--         染色（`LFGDungeonListButton_SetDungeon` 每次都 `SetCheckedTexture`／
--         `SetNormalTexture`）。
--   5. `hooksecurefunc("LFGRewardsFrame_SetItemButton", fn)`（第五輪新增）
--      —— 獎勵物品格是**動態建立**的（`_G[parentName.."Item"..index]`，
--         LFGFrame.lua:1418-1426）。hook 裡只做三件事：把 `index` 過
--         `Secret.PlainNumber`、用 `parentFrame:GetName()`（讀取例外表）拼出格子的
--         全域名字、對那顆格子跑我們自己的 `SkinLargeItemButton`。
--         **不讀 dungeonID、不讀 quality、不讀任何暴雪欄位。**
--   ＋ Engine 既有的三個 `PanelTemplates_*` 全域後置勾（分頁選中態，裝在
--     Core/Engine.lua，全套組共用一組）與分頁的 HookScript("OnEnter"/"OnLeave")。
--   ＋ `Skin.Row` 的 `opts.ownHover` ⇒ 四顆大類按鈕各一組
--     HookScript("OnEnter"/"OnLeave")（`Engine.TrackSelectable`，只碰自己的 overlay）。
--
-- 寫入暴雪欄位：無。
-- 讀暴雪物件：只有 `GetRegions`（PVEFrame.shadows 的三張無名貼圖）、
--   `GetName`（獎勵格的 hook 拼全域名字）、`IconBorder:IsShown()` 與
--   `IconBorder:GetVertexColor()`（`Engine.PassBorderColor`，傳遞者規則）與
--   `GetFrameLevel`（Engine.Overlay 內部）—— 都在 STYLE.md ③ 的讀取例外表上。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`LFGListFrame` 上所有 `EditBox` 一律只做視覺**：中和切片、掛一個不吃滑鼠的
--   overlay，**沒有 SetScript、沒有 HookScript、沒有欄位寫入、沒有 SetText**。
--   `SearchPanel.SearchBox` 與 `EntryCreation.Name` 還帶著
--   `secureReferenceKey` / `securityDisableSetText`（LFGList.xml:1067,1730），
--   那些輸入框有暴雪自己的輸入限制邏輯，碰腳本等於把自己接進那條線。
-- * **報名／建立隊伍的按鈕只做視覺。** `SignUpButton`、`ListGroupButton`、
--   `InviteButton` 的 OnClick 走 `C_LFGList.*`，我們對它們只做
--   「中和貼圖 ＋ 換 NormalFont 字型物件 ＋ 掛 overlay」，點下去的那次執行
--   從頭到尾是暴雪的。
-- * **獎勵格上的 `shortageBorder`（Talent-GoldMedal-Border）與兩顆 `roleIcon`**
--   —— 那是「這個獎勵只有補缺的職責拿得到」的資訊（LFGFrame.lua:1436-1470）。
-- * **獎勵框的 `randomList` / `encounterList` / `spacer`** —— 小圖示列與排版用的空框。
-- * **指定地城清單的 `heroicIcon` / `lockedIndicator` / 難度字色** —— 全部是資訊；
--   列本身沒有底圖也沒有 HighlightTexture ⇒ 沒有「列」可以畫，也不做隔行明暗
--   （那要讀 `elementData` 的索引，契約禁止）。
-- * **展開鈕的 `$parentHighlight`** —— 它就是同一張 ＋／− 箭頭
--   （LFGFrame.xml:288），`SetColorTexture` 會把它變成一塊白方塊（同插件列表那條）。
-- * **角色鈕的圖示／`lockedIndicator`／`alert`／`shortageBorder`／`incentiveIcon`**
--   —— 全部是資訊（能不能當這個角色、有沒有獎勵加成）。
-- * **左側大類按鈕的 `icon`**：被 `CircleMask` 遮成圓形（PVEFrame.xml:38），
--   圓圖配方角邊框只會更難看，而且遮罩不在白名單裡。不裁邊、不加邊。
--   ⚠ `ring` 第五輪起**不中和**了（改成壓深），理由寫在 `SkinCategoryRing`。
-- * **`LFGListCategoryTemplate` 的五顆分類按鈕**（LFGList.xml:466）：整顆就是一張
--   `groupfinder-button-*` 的美術圖 ＋ 一張 `SelectedTexture`，中和掉等於變成空方塊；
--   而且它們是 `LFGListCategorySelection_AddButton` **動態建立**的，要接管就得再加
--   一支 hook。這一輪不做。
-- * **`LFGListApplicationDialog`／`LFGListInviteDialog`／`LFDRoleCheckPopup`** ——
--   都是 `frameStrata="DIALOG"` 的彈出視窗，離 StaticPopup 太近（STYLE.md ⑦ C 級）。
-- * **`ChallengesFrame` 與 `PVPUIFrame`** —— 各自在 `Skins/Challenges.lua` 與
--   `Skins/PVP.lua`，走同一個 `pve` 開關的 `parts`。
-- * **遮罩層本身**（`LFGCooldownCoverTemplate` 的 93% 黑、`NoRaidsCover`、
--   `UnempoweredCover`、`WorkingCover`）—— 本來就是深色，只 skin 上面的按鈕。
-- * **`UsePGFButton` 與 `PremadeGroupsFilterDialog`**（套組內建的預組隊伍過濾插件）
--   —— 第八輪起走「伴隨元件」那條窄路（STYLE.md ③），實作在
--   `Skins/PVECompanions.lua`，時機是下面 `companions` 的 `atLogin`。
--   這一份對它們一行都不做。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret
local L = ns.L

------------------------------------------------------------
-- 三份配方的交接桌
--
-- 玩家對玩家（`Skins/PVP.lua`）與傳奇鑰石（`Skins/Challenges.lua`）是同一個視窗的
-- 另外兩個分頁，各自住在一個**隨需載入**的暴雪插件裡 ⇒ 走 `Engine.Register` 的
-- `parts`、共用 `pve` 這一個設定開關（STYLE.md ⑥ 第 5 步：玩家看到的是一個視窗）。
--
-- 那兩支的實作留在各自的檔案裡（原始碼出處與 taint 接觸面清單也各自寫在自己的
-- 檔頭），透過這張表交出來。這裡先放兩個空函式當預設值：萬一哪一支被語法錯誤
-- 擋掉沒載入，`parts` 也只是什麼都不做，不會整份配方掛掉。
------------------------------------------------------------
ns.PVESkin = ns.PVESkin or {}
ns.PVESkin.ApplyPVP = ns.PVESkin.ApplyPVP or function() end
ns.PVESkin.ApplyChallenges = ns.PVESkin.ApplyChallenges or function() end
-- 傳奇鑰石的地城圖示是 mixin 後置勾（`ChallengesDungeonIconMixin:SetUp`）⇒ 要排在
-- `parts` 的 `hooks` 裡，也就是**戰鬥閘前面**（STYLE.md ③ 的陷阱 4）。
ns.PVESkin.HookChallenges = ns.PVESkin.HookChallenges or function() end
-- 伴隨元件（套組內建的預組隊伍過濾插件）住在 `Skins/PVECompanions.lua`，
-- 走下面 `companions` 的 `atLogin`。沒載到就是什麼都不做。
ns.PVESkin.ApplyCompanions = ns.PVESkin.ApplyCompanions or function() end

------------------------------------------------------------
-- 小工具
------------------------------------------------------------

-- 安全取一個欄位（暴雪物件上的 __index 可能拋錯，而且可能根本不存在）
local function Field(owner, key)
    if type(owner) ~= "table" then return nil end
    local v
    if pcall(function() v = owner[key] end) then return v end
    return nil
end

-- 一路取下去：Field(a, "b", "c") ≡ a.b.c
local function Path(owner, ...)
    local node = owner
    for i = 1, select("#", ...) do
        if node == nil then return nil end
        node = Field(node, (select(i, ...)))
    end
    return node
end

-- ⚠ 第六輪：三支 local（`SkinStretchButton`／`SkinSquareIconButton`／
--   `SkinInputScroll`）的 `TODO(升格)` 結案了 —— 第五輪已經把對應的原語做好
--   （`Skin.StretchButton`／`Skin.SquareIconButton`／`Skin.InputScroll`），
--   這一份改成直接呼叫原語。模板名從此就是函式名，配方裡看得出「這是哪個暴雪模板」。
--
--   三支的行為差異（升格之後跟著原語走，是刻意的）：
--     * `Skin.StretchButton` 的滑過走 `ownHover`（底提亮 ＋ 職業色邊，
--       `Engine.TrackButtonHover`），local 那版還停在第四輪的「白 8%」。
--       改成跟整包其他按鈕同一套。
--     * `Skin.SquareIconButton` 同上，而且用的是 `opts.stripFrame`
--       （殼整組中和、改染 `Icon`）—— 跟 local 那版做的事一模一樣。

-- 透明底（只要一圈邊的 overlay 用）
local CLEAR = { 0, 0, 0, 0 }

------------------------------------------------------------
-- 大類按鈕圖示外面那一圈金屬環（`ring` / `Ring`，atlas `bluemenu-Ring`）
--
-- 第四輪把它**中和**了，實機的結果是：`CircleMask` 把 66x66 的 icon 切成圓形之後
-- 留下的毛邊與一圈殘光直接露在底色上，壓在選中的職業色底上特別明顯
-- （使用者擷圖：「icon 和背景交接的地方有點瑕疵」）。
--
-- 環本來就畫在 icon **之上**（ARTWORK `textureSubLevel="2"` 對 icon 的預設 0，
-- PVEFrame.xml:15,23 ／ Blizzard_PVPUI.xml:603,611），所以留著它就正好蓋住那一圈
-- 毛邊 —— 這是唯一「不動遮罩也能收掉」的辦法（`RemoveMaskTexture` 是結構性修改）。
--
-- 做法：**先去飽和再壓暗**。`SetVertexColor` 是乘法，金屬環的暗金乘上 `fillInset`
-- 只會變成暗金；先 `SetDesaturated(true)` 壓成灰階再乘才是中性的深灰
-- （同 `Engine.Desaturate` 的註解）。乘完是 0.08 那一階 —— 在 `fill`（0.115）的
-- 閒置底上幾乎看不見，在選中的職業色底上就是一圈乾淨的深色圓框。
--
-- ⚠ 去飽和撐不過「停用↔啟用」切換：`GroupFinderFrameButton_SetEnabled`
--   （PVEFrame.lua:304）與 `PVPQueueFrame_SetCategoryButtonState`
--   （Blizzard_PVPUI.lua:477）都會 `ring:SetDesaturated(not enabled)`。
--   **不補勾**：乘上 0.08 之後彩度差在肉眼下不存在（最大通道差 < 0.06），
--   去飽和只是讓那一步更準，不是結果本身。多一支 hook 換不到任何看得見的東西。
-- ⚠ `SetVertexColor` 沒有人重設（兩支 `SetEnabled` 只動 Desaturated 與 TexCoord）。
------------------------------------------------------------
local function SkinCategoryRing(ring, key)
    if not ring then
        E.Missing(key)
        return
    end
    E.Desaturate(ring, key)
    E.VertexColor(ring, T.fillInset, key)
end

-- 大類按鈕的列 overlay 範圍（PvE／PvP 共用；兩邊的按鈕都是 203x60、圖示 66x66）
local CATEGORY_ROW_POINTS = {
    { "TOPLEFT", "TOPLEFT", 0, 3 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, -3 },
}

-- 大類按鈕的圖示（PvE 四顆＋PvP 五顆共用）。
--
-- 第五輪的做法是「保留圓形、把外圈金屬環壓深」，實機看起來是一圈模糊的暗暈，
-- 使用者不喜歡。第七輪改成整包一致的語彙：**方形圖示＋裁邊＋1px 黑硬邊**。
--   * 圖示素材本來就是方形的（`Interface\Icons\…`），圓形只是 XML 掛的 `CircleMask`。
--   * 環整個中和；遮罩用 `Engine.UnmaskIcon` 拿掉（契約例外，理由寫在那一支）。
--   * 方框錨在**圖示**上（66x66），不是按鈕矩形（203x60）。
--   * 拿不掉遮罩（戰鬥中、API 不在、暴雪改了 parentKey）就**自動退回**壓深環的做法 ——
--     不然會變成「方框裡一顆圓圖」。
-- `T.categoryIconStyle = "ring"` 一行切回第五輪。
local function SkinCategoryIcon(btn, key, iconKey, ringKey, maskKey)
    local icon, ring, mask = Field(btn, iconKey), Field(btn, ringKey), Field(btn, maskKey)
    if T.categoryIconStyle == "square" and icon
        and E.UnmaskIcon(icon, mask, key .. "." .. iconKey) then
        if ring then E.Neutralize(ring, key .. "." .. ringKey) end
        E.CropIcon(icon, key .. "." .. iconKey)
        local ov = E.Overlay(btn, {
            key = key .. "." .. iconKey .. ".border",
            slot = "iconBorder",
            anchorTo = icon,
            levelOffset = 1,
        })
        E.Paint(ov, { 0, 0, 0, 0 }, T.border)
        return
    end
    SkinCategoryRing(ring, key .. "." .. ringKey)
end

------------------------------------------------------------
-- 職責鈕角落那顆勾選框（`LFGRoleButtonTemplate` 的 `checkButton`）
--
-- 第四輪走 `Skin.CheckBox`，也就是「已勾＝整格填滿職業色」。那條規則是為
-- **表單裡的** 14~16 像素勾選框定的（寄信頁的「寄送金錢」實測看不見細勾），
-- 但這一顆不在表單裡 —— 它疊在一顆 48x48 的職責圖示的左下角，而且它自己是
-- 30x29 `scale=0.7` ⇒ 21x20 框架單位（LFGFrame.xml:6-8），差不多是圖示的一半寬。
-- 整格填滿的結果就是使用者看到的「一個大方塊壓在圖示上」。
--
-- ⚠ **矩形縮不掉。** `CheckedTexture` 沒有 Size 也沒有 Anchors ⇒ setAllPoints，
--   它的矩形永遠等於按鈕矩形，而對暴雪區域 `SetPoint`／`SetSize` 是契約禁止的。
--   所以「做小」只有一條路：**別把那張貼圖塗成實心**。
--
-- 改成：`SetColorTexture`（會把整張圖換成一塊純色）換成 **`SetVertexColor`** ——
-- `checkmark-minimal` 那個勾的**形狀留著**，只是被染成職業色。底色同時從
-- `fillCheck`（0.28 中灰，正好跟圖示的亮度打架）換成 `fillInset`（0.08），
-- 讓那一格讀起來是「圖示角落的一個凹槽」而不是「疊上去的一塊灰板」。
-- 兩態還是只換明暗：暗格 → 暗格裡一個亮色的勾。
--
-- ⚠ `checkbox-minimal` / `checkmark-minimal` 這一組**不會**被 `SetCheckButtonIsRadio`
--   換掉：那一支（UIPanelTemplatesShared.lua:145）只用在 `LFGInvitePopup`
--   （LFGFrame.lua:1625-1627），是我們不碰的彈窗。
-- ⚠ 暴雪對 checkButton 只做 Show/Hide/Enable/Disable/SetChecked
--   （LFGFrame.lua:397-432），**沒有**任何路徑重設貼圖的 vertex color ⇒ 不必 reapply。
--
-- ⚠ **第六輪：整包的勾選框都改成這一套了**（`Skin.CheckBox` 的方框收成置中的
--   18，勾保留形狀只染職業色）—— 也就是說這一顆當初被迫走的窄路，現在是通則。
--   這裡仍然保留自己一支，差別只剩兩個，兩個都是「它不是表單裡的勾選框」：
--     * 底色用 `fillInset` 不是 `fillCheck`（它疊在一顆亮的職責圖示上）；
--     * 方框更小（`ROLE_BOX_SIZE`），因為按鈕本身 scale 0.7 之後只有 21x20。
--   染色改走 `Engine.CheckedGlyph`（多了一道去飽和：`SetVertexColor` 是乘法，
--   素材本身不是純白就乘不出職業色）。
------------------------------------------------------------
local CHECK_STATE_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }

-- 按鈕是 30x29 再 scale 0.7（LFGFrame.xml:6-8）⇒ 在它自己的座標系裡方框畫 14
-- 大約等於畫面上的 10，剛好是那顆 48x48 職責圖示角落的一個凹槽。
local ROLE_BOX_SIZE = 14

local function SkinRoleCheckBox(cb, key)
    if not E.Usable(cb, key) then return end

    for _, getter in ipairs(CHECK_STATE_GETTERS) do
        if type(cb[getter]) == "function" then
            local ok, tex = pcall(cb[getter], cb)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    E.ButtonStates(cb, key)

    -- 已勾／停用又已勾：保留勾的形狀，只去飽和＋染色（不塗滿）
    E.CheckedGlyph(cb, { T.AccentCheck(1) }, { T.AccentCheckDisabled(1) }, key)

    local ov = E.Overlay(cb, {
        key = key,
        points = { { "CENTER", "CENTER", 0, 0 } },
        width = ROLE_BOX_SIZE, height = ROLE_BOX_SIZE,
    })
    E.Paint(ov, T.fillInset, T.border)
    return ov
end

------------------------------------------------------------
-- `LargeItemButtonTemplate`（獎勵物品格：桶型寶箱、金錢那兩格）
--
-- 跟 `ItemButton` intrinsic 不同的地方只有一個，但那一個很要命：
-- **圖示只佔左邊 39x39，按鈕本身是 147x41**（ItemButtonTemplate.xml:171,174），
-- 右邊那半是一張 `UI-QuestItemNameFrame` 的雕花名牌。`Skin.ItemButton` 會把品質
-- 方框畫成整顆 147x41 的長方形，所以這裡自己畫一份，方框用 `anchorTo` 錨在
-- `Icon` 上。
--
-- 重畫仍然交給 Engine 既有的兩個全域後置勾：`LFGRewardsFrame_SetItemButton`
-- （LFGFrame.lua:1479-1483）呼叫的就是全域的 `SetItemButtonQuality`，
-- 而 `Skin.ItemButtonRefresh` 拿的正是 `slot = "front"` 那一層 —— 也就是下面這個
-- 品質方框（`levelOffset = 1` 預設就是 front）。圖示欄位叫 `Icon`（大寫），
-- `Skin.ItemButtonRefresh` 兩種大小寫都找。
--
-- TODO(升格): 「圖示只佔按鈕一角」的物品格不只這一種（任務獎勵格也是），
--   之後給 `Skin.ItemButton` 加一個 `opts.iconOnly`。
------------------------------------------------------------
local function SkinLargeItemButton(btn, key)
    if not E.Usable(btn, key) then return end

    -- 名牌雕花中和。名字是 `GameFontHighlight`（白）或暴雪寫上去的品質色，不碰。
    E.NeutralizeKeys(btn, { "NameFrame" }, key)

    local border
    if pcall(function() border = btn.IconBorder end) and border then
        E.Neutralize(border, key .. ".IconBorder")
    else
        E.Missing(key .. ".IconBorder")
    end

    E.ButtonStates(btn, key)

    local icon = Field(btn, "Icon")
    if icon then E.CropIcon(icon, key .. ".Icon") end

    -- 整顆一塊平面底（名牌那一半拿掉之後要有東西接住文字）
    local bg = E.Overlay(btn, { key = key, noBorder = true })
    E.Paint(bg, T.fill)

    if not icon then return end

    local ov = E.Overlay(btn, {
        key = key .. ".quality",
        anchorTo = icon,
        levelOffset = 1,
        borderSize = T.itemBorderSize,
    })
    E.Paint(ov, CLEAR, T.border)
    E.PassBorderColor(ov, border)
    E.TrackItemButton(btn, key)
    return ov
end

-- 一條掛在某個 parentKey 底下的 MinimalScrollBar（這一整家族的標準形狀）
local function SkinOwnedScrollBar(owner, key)
    local bar = Field(owner, "ScrollBar")
    if bar then
        Skin.ScrollBar(bar, key)
    else
        E.Missing(key)
    end
end

-- 一顆 `LFGRoleButtonTemplate` 系的角色鈕。
--
-- 做兩件事：把 `background`（GetBackgroundForRole 的 80x80 圓底）中和，
-- 把 `checkButton` 交給 `Skin.CheckBox`。
--
-- ⚠ **角色圖示不碰**：它是按鈕自己的 `NormalTexture`
--   （`SetNormalAtlas(GetIconForRole(...))`，LFGFrame.lua:2236），中和掉整顆就空了。
-- ⚠ `background` 用 alpha 中和：暴雪在 `LFG_EnableRoleButton` / `LFG_DisableRoleButton`
--   （LFGFrame.lua:401,414,434）對它 Show/Hide，alpha 是另一個屬性，撐得住。
local function SkinRoleButton(btn, key)
    if not E.Usable(btn, key) then return end

    -- ⚠ 只有 `LFGRoleButtonWithBackgroundTemplate` 那一支有 `background`
    --   （LFGFrame.xml:164）；PvP 那一排走的是 `LFGRoleButtonWithShortageRewardTemplate`
    --   （同檔 :77），沒有這張圖。所以先問再中和，不然「找不到的區域」會被
    --   三顆一組的假陽性洗版。
    if Field(btn, "background") then
        E.NeutralizeKeys(btn, { "background" }, key)
    end

    local cb = Field(btn, "checkButton")
    if cb then
        SkinRoleCheckBox(cb, key .. ".checkButton")
    else
        E.Missing(key .. ".checkButton")
    end
end

-- 一整排角色鈕（Tank / Healer / DPS / Leader），名字規則四個視窗都一樣
local ROLE_SUFFIXES = { "Tank", "Healer", "DPS", "Leader" }

local function SkinRoleButtonRow(prefix)
    for _, suffix in ipairs(ROLE_SUFFIXES) do
        local name = prefix .. suffix
        local btn = _G[name]
        if btn then
            SkinRoleButton(btn, name)
        else
            E.Missing(name)
        end
    end
end

-- 一票用全域名字取得的 UIPanelButton
local function SkinGlobalButtons(names)
    for _, name in ipairs(names) do
        local btn = _G[name]
        if btn then
            Skin.Button(btn, name)
        else
            E.Missing(name)
        end
    end
end

-- 一票掛在某個框底下的 parentKey 按鈕
local function SkinKeyedButtons(owner, prefix, keys, opts)
    for _, key in ipairs(keys) do
        local btn = Field(owner, key)
        if btn then
            Skin.Button(btn, prefix .. "." .. key, opts)
        else
            E.Missing(prefix .. "." .. key)
        end
    end
end

------------------------------------------------------------
-- PVEFrame 外框
--
-- 左側那一整片是十一張**只有全域名字**的 `bluemenu-*` 切片（PVEFrame.xml:74-154），
-- 加上 `PVEFrame.shadows` 底下三張**連名字都沒有**的陰影貼圖（同檔 :234）。
-- 兩組都只中和、不重排 —— 暴雪自己在 `PVEFrame_HideLeftInset` / `_ShowLeftInset`
-- （PVEFrame.lua:149,165）會對前十一張 Show/Hide，alpha 是獨立屬性，撐得過去。
------------------------------------------------------------
local PVE_BLUE_ART = {
    "PVEFrameBlueBg",
    "PVEFrameTLCorner", "PVEFrameTRCorner", "PVEFrameBRCorner", "PVEFrameBLCorner",
    "PVEFrameLLVert", "PVEFrameRLVert",
    "PVEFrameBottomLine", "PVEFrameTopLine",
    "PVEFrameTopFiligree", "PVEFrameBottomFiligree",
}

local function ApplyChrome()
    local f = _G.PVEFrame
    if not f then
        E.Missing("PVEFrame")
        return
    end

    Skin.PortraitChrome(f, "PVEFrame")
    E.NeutralizeGlobals(PVE_BLUE_ART)

    local shadows = Field(f, "shadows")
    if shadows then
        -- 三張貼圖都沒有名字也沒有 parentKey ⇒ 只剩 GetRegions 一條路
        E.NeutralizeRegions(shadows, "PVEFrame.shadows")
    else
        E.Missing("PVEFrame.shadows")
    end

    Skin.Panel(f, "PVEFrame")

    local inset = Field(f, "Inset")
    if inset then
        Skin.Inset(inset, "PVEFrame.Inset")
    else
        E.Missing("PVEFrame.Inset")
    end

    local close = Field(f, "CloseButton")
    if close then
        Skin.CloseButton(close, "PVEFrame.CloseButton")
    else
        E.Missing("PVEFrame.CloseButton")
    end

    -- 底部三顆分頁（地城與團隊搜尋器／玩家對玩家／傳奇鑰石）。
    -- 停用態（沒開 M+ 的賽季）走 `PanelTemplates_SetDisabledTabState`
    -- （SharedUIPanelTemplates.lua:372,481），Engine 的三個後置勾已經接住。
    -- 走 `Skin.TabGroup`：相鄰兩顆共用一條線、選中那顆的字置中（第五輪）。
    local tabs = {}
    for i = 1, 3 do
        local key = "PVEFrameTab" .. i
        local tab = _G[key]
        if tab then
            tabs[#tabs + 1] = { tab = tab, key = key }
        else
            E.Missing(key)
        end
    end
    Skin.TabGroup(tabs, { kind = "panel" })
end

------------------------------------------------------------
-- 左側四顆大類按鈕（地城與團隊／情境／團隊搜尋／預組隊伍）
--
-- 兩態都自己畫（`Skin.Row` 的 `opts.ownHover`）。理由跟成就分類列同型：
-- `GroupFinderGroupButtonTemplate` 的 HighlightTexture 是 **224x80 置中**
-- （PVEFrame.xml:49-55），而按鈕矩形是 203x60 —— 上下各多出 10、左右各多出 10。
-- 交給引擎畫就會在按鈕外圍多出一圈白 8% 的光暈。
--
-- 選中態是 `bg:SetTexCoord`（PVEFrame.lua:387），既不是 Show/Hide 也不是
-- `PanelTemplates_*` ⇒ 只能勾那一支全域函式。
------------------------------------------------------------
local groupButtons = {}          -- [1..4] = 暴雪的按鈕（順序＝ groupFrames 的 index）
local groupHookInstalled = false

local function InstallGroupButtonHook()
    if groupHookInstalled then return end
    if type(_G.GroupFinderFrame_SelectGroupButton) ~= "function" then
        E.Missing("GroupFinderFrame_SelectGroupButton")
        return
    end
    groupHookInstalled = true

    -- ⚠ hook 裡做的事只有兩件：型別檢查參數、對**我們自己的** overlay 換底色。
    --   `index` 是後置勾的**參數**（暴雪自己的迴圈索引），不是 elementData 的欄位；
    --   一律過 `Secret.PlainNumber`，問不到就整批畫成閒置（失敗方向安全）。
    hooksecurefunc("GroupFinderFrame_SelectGroupButton", function(index)
        local n = S.PlainNumber(index)
        -- ⚠ 走 1..4 的**固定索引**，不是 `#groupButtons` —— `index` 是暴雪自己的
        --   `groupFrames` 序號，中間有一顆沒接管成功（保護框）的話，用「陣列長度」
        --   會讓後面每一顆都對錯位置。沒接管的那一格是 nil，`SetSelected` 自己會
        --   在查不到 side table 的時候直接返回。
        for i = 1, 4 do
            E.SetSelected(groupButtons[i], n ~= nil and i == n)
        end
    end)
end

local function ApplyGroupButtons()
    local gf = _G.GroupFinderFrame
    if not gf then
        E.Missing("GroupFinderFrame")
        return
    end

    wipe(groupButtons)
    for i = 1, 4 do
        local key = "GroupFinderFrame.groupButton" .. i
        local btn = Field(gf, "groupButton" .. i)
        if btn then
            -- `bg` 是藍色選單切片（裝飾，中和）。
            -- ⚠ `icon` 不碰：它被 `CircleMask` 遮成圓形（PVEFrame.xml:38），
            --   而且是這顆按鈕的身分。
            -- ⚠ `ring` 不中和，壓深當「蓋住遮罩毛邊的一圈深色框」用，見 SkinCategoryRing。
            -- 列的 overlay 上下各多 3：圖示是 66 高、按鈕只有 60 高（PVEFrame.xml:4,25），
            -- 方形圖示會上下各凸出 3；列與列之間隔 23（同檔 :206），多 3 不會碰到鄰居。
            Skin.Row(btn, key, { keys = { "bg" }, ownHover = true, points = CATEGORY_ROW_POINTS })
            SkinCategoryIcon(btn, key, "icon", "ring", "CircleMask")
            groupButtons[i] = btn

            -- 標題文字改白。
            -- ⚠ 這裡**不能**走 `SetNormalFontObject`：這個模板沒有 `<ButtonText>`，
            --   `name` 是 Layer 裡一條獨立的 FontString（PVEFrame.xml:30），
            --   不是按鈕自己的 fontString ⇒ 只能 SetTextColor。
            -- ⚠ 撐不過「停用↔啟用切換」：`GroupFinderFrameButton_SetEnabled`
            --   （PVEFrame.lua:298,301）會 `SetFontObject` 重設顏色。那一支只在狀態
            --   **改變**時才跑（同檔 :292 的提早返回），實務上是「視窗開著時升等
            --   解鎖了某一類」才會發生，而那時換回暴雪的金／灰也正好是對的明暗語彙。
            E.TextColor(Field(btn, "name"), T.text, key .. ".name")
        else
            E.Missing(key)
        end
    end
end

------------------------------------------------------------
-- 獎勵框（`LFGRewardFrameTemplate`）：地城搜尋與團隊搜尋各一個
--
-- 文字一條都不接管 —— 檔頭第 6 點查過了，這一整塊的字本來就是白／金／品質色。
-- 這裡只處理「靜態就存在」的 `MoneyReward`；`Item1..N` 是動態建立的，
-- 走 `LFGRewardsFrame_SetItemButton` 的後置勾。
------------------------------------------------------------
local function ApplyRewardFrame(frameName)
    local frame = _G[frameName]
    if not frame then
        E.Missing(frameName)
        return
    end
    SkinLargeItemButton(Field(frame, "MoneyReward"), frameName .. ".MoneyReward")
end

------------------------------------------------------------
-- 地城搜尋（LFDParentFrame / LFDQueueFrame）
------------------------------------------------------------
local function ApplyLFD()
    local parent = _G.LFDParentFrame
    if not parent then
        E.Missing("LFDParentFrame")
        return
    end

    -- 角色列背後那張藍底（UI-LFG-BlueBG）是**框架美術**不是內容底材：
    -- 它上面只有角色圖示與一條下拉說明字，沒有「為它設計的深色內文」。
    E.NeutralizeGlobals({ "LFDParentFrameRoleBackground" })
    -- `ButtonFrameTemplate_HideAttic`（LFDFrame.lua:33）已經把它藏起來了，
    -- 這一行只是保險（暴雪哪天不呼叫那一支的時候不會突然冒出一條條紋）。
    E.NeutralizeKeys(parent, { "TopTileStreaks" }, "LFDParentFrame")

    local inset = Field(parent, "Inset")
    if inset then
        Skin.Inset(inset, "LFDParentFrame.Inset")
    else
        E.Missing("LFDParentFrame.Inset")
    end

    local queue = _G.LFDQueueFrame
    if not queue then
        E.Missing("LFDQueueFrame")
        return
    end

    -- 羊皮紙（UI-LFG-BACKGROUND-QUESTPAPER）。第五輪起中和 —— 上面一條深色字都沒有
    -- （檔頭第 6 點）。⚠ 一定要 alpha：`LFGRewardsFrame_UpdateFrame`（LFGFrame.lua:1252）
    --   每次更新都 `background:SetTexture(...)` 換成該地城的那一張。
    E.NeutralizeGlobals({ "LFDQueueFrameBackground" })

    SkinRoleButtonRow("LFDQueueFrameRoleButton")

    local dropdown = _G.LFDQueueFrameTypeDropdown
    if dropdown then
        Skin.Dropdown(dropdown, "LFDQueueFrameTypeDropdown", "style1")
        -- 下拉左邊那條「選擇你的地城」是 GameFontNormal（暗金），深底上偏灰
        E.TextColor(_G.LFDQueueFrameTypeDropdownName, T.text, "LFDQueueFrameTypeDropdownName")
    else
        E.Missing("LFDQueueFrameTypeDropdown")
    end

    SkinGlobalButtons({
        "LFDQueueFrameFindGroupButton",
        -- 兩塊遮罩上的按鈕（隊伍回填／同時排 LFR 時的提示）
        "LFDQueueFramePartyBackfillBackfillButton",
        "LFDQueueFramePartyBackfillNoBackfillButton",
        "LFDQueueFrameNoLFDWhileLFRLeaveQueueButton",
    })

    -- 三條捲軸：隨機頁的舊式 ScrollFrame（ScrollFrame_OnLoad 生出來的
    -- `.ScrollBar` 模板就是 MinimalScrollBar），指定頁與隨從頁各一條。
    SkinOwnedScrollBar(_G.LFDQueueFrameRandomScrollFrame, "LFDQueueFrameRandomScrollFrame.ScrollBar")
    SkinOwnedScrollBar(Field(queue, "Specific"), "LFDQueueFrame.Specific.ScrollBar")
    SkinOwnedScrollBar(Field(queue, "Follower"), "LFDQueueFrame.Follower.ScrollBar")

    ApplyRewardFrame("LFDQueueFrameRandomScrollFrameChildFrame")
end

------------------------------------------------------------
-- 團隊搜尋（RaidFinderFrame / RaidFinderQueueFrame）
------------------------------------------------------------
local function ApplyRaidFinder()
    local frame = _G.RaidFinderFrame
    if not frame then
        E.Missing("RaidFinderFrame")
        return
    end

    -- 角色列背後那張橘色漸層（RaidFinder.xml:22，只有 Gradient 沒有檔案）
    -- ＋ 下半的羊皮紙（RaidFinder.xml:77，同 LFD 那一張，理由見檔頭第 6 點）
    E.NeutralizeGlobals({ "RaidFinderFrameRoleBackground", "RaidFinderQueueFrameBackground" })

    local roleInset = Field(frame, "Inset")
    if roleInset then
        Skin.Inset(roleInset, "RaidFinderFrame.Inset")
    else
        E.Missing("RaidFinderFrame.Inset")
    end

    local bottomInset = _G.RaidFinderFrameBottomInset
    if bottomInset then
        Skin.Inset(bottomInset, "RaidFinderFrameBottomInset")
    else
        E.Missing("RaidFinderFrameBottomInset")
    end

    SkinRoleButtonRow("RaidFinderQueueFrameRoleButton")

    local dropdown = _G.RaidFinderQueueFrameSelectionDropdown
    if dropdown then
        Skin.Dropdown(dropdown, "RaidFinderQueueFrameSelectionDropdown", "style1")
        E.TextColor(_G.RaidFinderQueueFrameSelectionDropdownName, T.text,
            "RaidFinderQueueFrameSelectionDropdownName")
    else
        E.Missing("RaidFinderQueueFrameSelectionDropdown")
    end

    SkinGlobalButtons({
        "RaidFinderFrameFindRaidButton",
        "RaidFinderQueueFramePartyBackfillBackfillButton",
        "RaidFinderQueueFramePartyBackfillNoBackfillButton",
        "RaidFinderQueueFrameIneligibleFrameLeaveQueueButton",
    })

    SkinOwnedScrollBar(_G.RaidFinderQueueFrameScrollFrame, "RaidFinderQueueFrameScrollFrame.ScrollBar")

    ApplyRewardFrame("RaidFinderQueueFrameScrollFrameChildFrame")
end

------------------------------------------------------------
-- 預組隊伍（LFGListFrame）—— **這一輪只做純視覺**
--
-- 這是全遊戲 taint 投訴最多的視窗之一：報名、建立隊伍的路徑上有需要硬體事件的
-- 呼叫，輸入框還帶著 `secureReferenceKey`。所以這一段的紀律比別處更硬：
--   * 一個 `SetScript` / `HookScript` 都沒有（滑過態全部交給 `Engine.ButtonStates`）。
--   * 一個暴雪欄位都不寫。
--   * 池化列的兩支 hook 只拿 frame 參照，**完全不讀 `elementData`**。
------------------------------------------------------------

-- 五個面板共用的 `Inset` ＋ 它底下那張 `groupfinder-background` 裝飾底圖
local function SkinPanelInset(panel, key, insetKey)
    local inset = Field(panel, insetKey or "Inset")
    if not inset then
        E.Missing(key)
        return
    end
    -- CustomBG 是 Inset 自己 Layer 裡的一張 atlas（LFGList.xml:955），
    -- 中和掉才看得見我們的 fillInset
    E.NeutralizeKeys(inset, { "CustomBG" }, key)
    Skin.Inset(inset, key)
end

local function ApplyCategorySelection(lfg)
    local panel = Field(lfg, "CategorySelection")
    if not panel then
        E.Missing("LFGListFrame.CategorySelection")
        return
    end
    SkinPanelInset(panel, "LFGListFrame.CategorySelection.Inset")
    E.TextColor(Field(panel, "Label"), T.text, "LFGListFrame.CategorySelection.Label")
    SkinKeyedButtons(panel, "LFGListFrame.CategorySelection",
        { "FindGroupButton", "StartGroupButton" })
end

local function ApplyNothingAvailable(lfg)
    local panel = Field(lfg, "NothingAvailable")
    if not panel then
        E.Missing("LFGListFrame.NothingAvailable")
        return
    end
    SkinPanelInset(panel, "LFGListFrame.NothingAvailable.Inset")
    E.TextColor(Field(panel, "Label"), T.text, "LFGListFrame.NothingAvailable.Label")
end

-- 搜尋框底下那個自動完成清單的外框：五張 `UI-Frame-*` 切片（LFGList.xml:1091-1118）
local AUTOCOMPLETE_BORDERS = {
    "BottomLeftBorder", "BottomRightBorder", "BottomBorder", "LeftBorder", "RightBorder",
}

local function ApplySearchPanel(lfg)
    local panel = Field(lfg, "SearchPanel")
    if not panel then
        E.Missing("LFGListFrame.SearchPanel")
        return
    end

    E.TextColor(Field(panel, "CategoryName"), T.text, "LFGListFrame.SearchPanel.CategoryName")

    local filter = Field(panel, "FilterButton")
    if filter then
        Skin.Dropdown(filter, "LFGListFrame.SearchPanel.FilterButton", "filter")
    else
        E.Missing("LFGListFrame.SearchPanel.FilterButton")
    end

    -- ⚠ 只做視覺。這顆帶 `secureReferenceKey="LFGListSearchBox"` 與
    --   `securityDisableSetText`（LFGList.xml:1067）—— 腳本一個都不掛。
    local search = Field(panel, "SearchBox")
    if search then
        Skin.EditBox(search, "LFGListFrame.SearchPanel.SearchBox")
    else
        E.Missing("LFGListFrame.SearchPanel.SearchBox")
    end

    local auto = Field(panel, "AutoCompleteFrame")
    if auto then
        E.NeutralizeKeys(auto, AUTOCOMPLETE_BORDERS, "LFGListFrame.SearchPanel.AutoCompleteFrame")
        local ov = E.Overlay(auto, { key = "LFGListFrame.SearchPanel.AutoCompleteFrame" })
        E.Paint(ov, T.fillInset, T.border)
    else
        E.Missing("LFGListFrame.SearchPanel.AutoCompleteFrame")
    end

    local refresh = Field(panel, "RefreshButton")
    if refresh then
        Skin.SquareIconButton(refresh, "LFGListFrame.SearchPanel.RefreshButton")
    else
        E.Missing("LFGListFrame.SearchPanel.RefreshButton")
    end

    local inset = Field(panel, "ResultsInset")
    if inset then
        Skin.Inset(inset, "LFGListFrame.SearchPanel.ResultsInset")
    else
        E.Missing("LFGListFrame.SearchPanel.ResultsInset")
    end

    SkinOwnedScrollBar(panel, "LFGListFrame.SearchPanel.ScrollBar")

    SkinKeyedButtons(panel, "LFGListFrame.SearchPanel",
        { "BackButton", "BackToGroupButton", "SignUpButton" })

    -- 「沒有結果」時出現的那顆自己開隊伍（LFGList.xml:1189）
    local startGroup = Path(panel, "ScrollBox", "StartGroupButton")
    if startGroup then
        Skin.Button(startGroup, "LFGListFrame.SearchPanel.ScrollBox.StartGroupButton")
    else
        E.Missing("LFGListFrame.SearchPanel.ScrollBox.StartGroupButton")
    end
end

local APPLICATION_COLUMN_HEADERS = {
    "NameColumnHeader", "RoleColumnHeader", "ItemLevelColumnHeader", "RatingColumnHeader",
}

local function ApplyApplicationViewer(lfg)
    local panel = Field(lfg, "ApplicationViewer")
    if not panel then
        E.Missing("LFGListFrame.ApplicationViewer")
        return
    end

    -- 上半部的資訊區底圖（groupfinder-background-dungeons）
    E.NeutralizeKeys(panel, { "InfoBackground" }, "LFGListFrame.ApplicationViewer")

    local inset = Field(panel, "Inset")
    if inset then
        Skin.Inset(inset, "LFGListFrame.ApplicationViewer.Inset")
    else
        E.Missing("LFGListFrame.ApplicationViewer.Inset")
    end

    -- ⚠ `keepFont`：欄位表頭的 NormalFont 是 `GameFontHighlightSmall`
    --   （LFGList.xml:787），而且它們在 OnLoad 就 `self:Disable()` 了（同檔 :796）
    --   —— 換 NormalFont 對停用的按鈕沒有意義，只會多一次寫入。
    SkinKeyedButtons(panel, "LFGListFrame.ApplicationViewer",
        APPLICATION_COLUMN_HEADERS, { keepFont = true })

    local refresh = Field(panel, "RefreshButton")
    if refresh then
        Skin.SquareIconButton(refresh, "LFGListFrame.ApplicationViewer.RefreshButton")
    else
        E.Missing("LFGListFrame.ApplicationViewer.RefreshButton")
    end

    SkinOwnedScrollBar(panel, "LFGListFrame.ApplicationViewer.ScrollBar")

    SkinKeyedButtons(panel, "LFGListFrame.ApplicationViewer",
        { "RemoveEntryButton", "EditButton", "BrowseGroupsButton" })

    local auto = Field(panel, "AutoAcceptButton")
    if auto then
        Skin.CheckBox(auto, "LFGListFrame.ApplicationViewer.AutoAcceptButton")
    else
        E.Missing("LFGListFrame.ApplicationViewer.AutoAcceptButton")
    end
end

-- `DialogBorderNoCenterTemplate` ／ `NineSlicePanelTemplate` 的九片
-- （Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:381，掛在框自己身上）
local NINE_SLICE_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

-- 五個需求欄（裝等／PvP 裝等／PvP 分數／M+ 分數／語音）與兩個選項勾選框
local REQUIREMENT_KEYS = { "ItemLevel", "PvpItemLevel", "PVPRating", "MythicPlusRating", "VoiceChat" }
local OPTION_KEYS = { "CrossFactionGroup", "PrivateGroup" }

local function ApplyEntryCreation(lfg)
    local panel = Field(lfg, "EntryCreation")
    if not panel then
        E.Missing("LFGListFrame.EntryCreation")
        return
    end

    SkinPanelInset(panel, "LFGListFrame.EntryCreation.Inset")
    E.TextColor(Field(panel, "Label"), T.text, "LFGListFrame.EntryCreation.Label")

    -- ⚠ 只做視覺：這顆帶 `secureReferenceKey="LFGListCreationName"`（LFGList.xml:1730）
    local name = Field(panel, "Name")
    if name then
        Skin.EditBox(name, "LFGListFrame.EntryCreation.Name")
    else
        E.Missing("LFGListFrame.EntryCreation.Name")
    end

    for _, key in ipairs({ "GroupDropdown", "ActivityDropdown", "PlayStyleDropdown" }) do
        local dd = Field(panel, key)
        if dd then
            Skin.Dropdown(dd, "LFGListFrame.EntryCreation." .. key, "style1")
        else
            E.Missing("LFGListFrame.EntryCreation." .. key)
        end
    end

    Skin.InputScroll(Field(panel, "Description"), "LFGListFrame.EntryCreation.Description")

    for _, key in ipairs(REQUIREMENT_KEYS) do
        local req = Field(panel, key)
        if req then
            local cb = Field(req, "CheckButton")
            if cb then Skin.CheckBox(cb, "LFGListFrame.EntryCreation." .. key .. ".CheckButton") end
            local eb = Field(req, "EditBox")
            if eb then Skin.EditBox(eb, "LFGListFrame.EntryCreation." .. key .. ".EditBox") end
        else
            E.Missing("LFGListFrame.EntryCreation." .. key)
        end
    end

    for _, key in ipairs(OPTION_KEYS) do
        local cb = Path(panel, key, "CheckButton")
        if cb then
            Skin.CheckBox(cb, "LFGListFrame.EntryCreation." .. key .. ".CheckButton")
        else
            E.Missing("LFGListFrame.EntryCreation." .. key .. ".CheckButton")
        end
    end

    SkinKeyedButtons(panel, "LFGListFrame.EntryCreation", { "ListGroupButton", "CancelButton" })

    -- 「找活動」那個蓋在上面的小對話框（LFGList.xml:1644）
    local dialog = Path(panel, "ActivityFinder", "Dialog")
    if dialog then
        local key = "LFGListFrame.EntryCreation.ActivityFinder.Dialog"
        E.NeutralizeKeys(dialog, { "Bg" }, key)
        E.NeutralizeKeys(Field(dialog, "Border"), NINE_SLICE_PIECES, key .. ".Border")
        -- BorderFrame 是 TooltipBackdropTemplate，九片掛在它的 NineSlice 上
        E.NeutralizeKeys(Path(dialog, "BorderFrame", "NineSlice"), NINE_SLICE_PIECES,
            key .. ".BorderFrame.NineSlice")
        Skin.Panel(dialog, key)

        local eb = Field(dialog, "EntryBox")
        if eb then Skin.EditBox(eb, key .. ".EntryBox") end

        SkinOwnedScrollBar(dialog, key .. ".ScrollBar")
        SkinKeyedButtons(dialog, key, { "SelectButton", "CancelButton" })
    else
        E.Missing("LFGListFrame.EntryCreation.ActivityFinder.Dialog")
    end
end

local function ApplyLFGList()
    local lfg = _G.LFGListFrame
    if not lfg then
        E.Missing("LFGListFrame")
        return
    end
    ApplyCategorySelection(lfg)
    ApplyNothingAvailable(lfg)
    ApplySearchPanel(lfg)
    ApplyApplicationViewer(lfg)
    ApplyEntryCreation(lfg)
end

------------------------------------------------------------
-- 池化列（兩支，都只拿 frame 參照）
------------------------------------------------------------
local searchEntrySweep, applicantSweep, dungeonRowSweep

------------------------------------------------------------
-- 指定／隨從地城清單的列（`LFGSpecificChoiceTemplate`）
--
-- 列本身是裸 `<Frame>`（LFGFrame.xml:227）—— 沒有底圖、沒有 HighlightTexture，
-- 所以沒有「列」要畫。要接管的只有兩顆按鈕：
--   * `enableButton`（UI-CheckBox-* 那一組）→ 一般的 `Skin.CheckBox`
--   * `expandOrCollapseButton`（＋／−）→ 圖形是資訊，只去飽和 ＋ 染 `textDim`
------------------------------------------------------------
local DUNGEON_ROW_KEY = "LFDDungeonChoice"

local function ApplyDungeonRow(row)
    local cb = Field(row, "enableButton")
    if cb then
        Skin.CheckBox(cb, DUNGEON_ROW_KEY .. ".enableButton")
    else
        E.Missing(DUNGEON_ROW_KEY .. ".enableButton")
    end
end

local function ReapplyDungeonRow(row)
    -- ⚠ `LFGDungeonListButton_SetDungeon`（LFGFrame.lua:1737-1742）**每次**都
    --   `enableButton:SetCheckedTexture(路徑)`（多選 UI-MultiCheck／單選
    --   UI-CheckBox-Check 兩組）—— 換材質會把我們的去飽和與染色一起打回。
    --   ⚠ 第六輪改走 `E.CheckedGlyph`（保留勾的形狀、只去飽和＋染職業色），
    --     跟 `Skin.CheckBox` 同一套；`SetCheckedTexture` 換掉的是**材質**，
    --     而去飽和與 vertex color 是貼圖自己的獨立屬性 —— 所以這裡一樣要重下。
    local cb = Field(row, "enableButton")
    if cb then
        E.CheckedGlyph(cb, { T.AccentCheck(1) }, { T.AccentCheckDisabled(1) },
            DUNGEON_ROW_KEY .. ".enableButton")
    end

    -- ⚠ 同一支每次都 `expandOrCollapseButton:SetNormalTexture(UI-Plus/MinusButton-UP)`
    --   （同檔 :1692,1694）。＋／− 是「展開了沒」，不中和；素材是烤了顏色的金屬鈕
    --   ⇒ 先去飽和再乘 `textDim`（同 Engine.Desaturate 的理由）。
    -- ⚠ Highlight 不碰：那是同一張箭頭圖（LFGFrame.xml:288），
    --   `SetColorTexture` 會把它變成一塊白方塊。
    local expand = Field(row, "expandOrCollapseButton")
    if expand and type(expand.GetNormalTexture) == "function" then
        local ok, tex = pcall(expand.GetNormalTexture, expand)
        if ok and tex then
            local key = DUNGEON_ROW_KEY .. ".expandOrCollapseButton"
            E.Desaturate(tex, key)
            E.VertexColor(tex, T.textDim, key)
        end
    end
end

local function MatchDungeonRow(row)
    return type(row) == "table" and row.enableButton ~= nil
end

------------------------------------------------------------
-- 獎勵物品格：`LFGRewardsFrame_SetItemButton`（全域）的後置勾
--
-- 格子是動態建立的（`_G[parentName.."Item"..index]`，LFGFrame.lua:1418-1426），
-- 所以不能在 apply 裡掃一次。hook 裡只做三件事：
--   1. `index` 過 `Secret.PlainNumber`（後置勾的**參數**，不是 elementData 的欄位）
--   2. `parentFrame:GetName()`（讀取例外表）拼出格子的全域名字
--   3. 對那顆格子跑 `SkinLargeItemButton`（冪等）
-- dungeonID、quality、rewardID 一個都沒有讀。
------------------------------------------------------------
local rewardHookInstalled = false
-- 已經套過皮的獎勵格（弱鍵 side table，不在暴雪的框上寫欄位）。
-- 之後每次更新的重畫（品質色、重裁圖示）由 Engine 的兩個全域物品格後置勾負責，
-- 這一支只負責「第一次見到這顆格子」。
local rewardSkinned = setmetatable({}, { __mode = "k" })

local function InstallRewardItemHook()
    if rewardHookInstalled then return end
    if type(_G.LFGRewardsFrame_SetItemButton) ~= "function" then
        E.Missing("LFGRewardsFrame_SetItemButton")
        return
    end
    rewardHookInstalled = true

    -- 跟 `Engine.HookRows` 同一套紀律：第一行查弱鍵表、整段 pcall、
    -- 出錯一次就把這支標成壞掉（切一次地城會進來好幾發，洗版比少一塊皮嚴重）。
    local broken = false

    local function Handle(parentFrame, index)
        local n = S.PlainNumber(index)
        if not n or type(parentFrame) ~= "table" then return end
        local name
        if not (pcall(function() name = parentFrame:GetName() end) and type(name) == "string") then
            return
        end
        local btn = _G[name .. "Item" .. n]
        if not btn or rewardSkinned[btn] then return end
        rewardSkinned[btn] = true
        SkinLargeItemButton(btn, "LFGRewardsLoot")
    end

    hooksecurefunc("LFGRewardsFrame_SetItemButton", function(parentFrame, _, index)
        if broken then return end
        local ok, err = pcall(Handle, parentFrame, index)
        if not ok then
            broken = true
            E.NoteBrokenHook("LFGRewardsFrame_SetItemButton")
            ns.ReportError(err)
        end
    end)
end

local function InstallRowHooks()
    -- 搜尋結果列：只把 HIGHLIGHT 層那條藍色滑過帶換成白 8%。
    --
    -- ⚠ 列底本身**不碰**：`ResultBG` 是白 4% 的平面矩形（LFGList.xml:804），
    --   放在我們的 fillInset 上正好就是隔行明暗；`BackgroundTexture` 是申請狀態的
    --   紅／綠／黃（LFGList.lua:3374-3382），那是**資訊**。
    -- ⚠ 沒有 reapply：暴雪只在 OnEnter／OnLeave 對 `Highlight` 做 Show/Hide
    --   （LFGList.lua:3523,3530），不重設材質 ⇒ `SetColorTexture` 撐得過去。
    --   沒有 reapply 也表示 Engine 不會把 `elementData` 交給我們。
    searchEntrySweep = E.HookRows{
        key    = "LFGListSearchEntry",
        mixin  = _G,
        method = "LFGListSearchPanel_InitButton",
        match  = function(row) return type(row) == "table" and row.Highlight ~= nil end,
        apply  = function(row)
            local hl = Field(row, "Highlight")
            if hl then
                E.HighlightTexture(hl, "LFGListSearchEntry.Highlight")
            else
                E.Missing("LFGListSearchEntry.Highlight")
            end
        end,
    }

    -- 申請者列：只 skin 列上那三顆 `UIMenuButtonStretchTemplate`。
    --
    -- ⚠ 列底 `Background` 不碰：`LFGListApplicationViewer_InitButton`
    --   （LFGList.lua:1895）自己在做隔行明暗（alpha 0.1 / 0.05），
    --   我們一中和就把那個層次抹掉了。
    applicantSweep = E.HookRows{
        key    = "LFGListApplicant",
        mixin  = _G,
        method = "LFGListApplicationViewer_InitButton",
        match  = function(row) return type(row) == "table" and row.DeclineButton ~= nil end,
        apply  = function(row)
            for _, key in ipairs({ "DeclineButton", "InviteButton", "InviteButtonSmall" }) do
                local btn = Field(row, key)
                if btn then Skin.StretchButton(btn, "LFGListApplicant." .. key) end
            end
        end,
    }

    -- 指定地城清單與隨從地城清單：**兩支全域初始化函式共用同一組 apply/reapply**。
    -- 兩邊是不同的 ScrollBox，但列的模板是同一個（LFDFrameDungeonChoiceTemplate），
    -- 而 `Engine.RowState` 是跨 hook 共用的弱鍵表 ⇒ 同一顆列被哪一支先碰到都一樣。
    dungeonRowSweep = E.HookRows{
        key    = DUNGEON_ROW_KEY,
        mixin  = _G,
        method = "LFDQueueFrameSpecificList_InitButton",
        match  = MatchDungeonRow,
        apply  = ApplyDungeonRow,
        reapply = ReapplyDungeonRow,
    }
    E.HookRows{
        key    = DUNGEON_ROW_KEY,
        mixin  = _G,
        method = "LFDQueueFrameFollowerList_InitButton",
        match  = MatchDungeonRow,
        apply  = ApplyDungeonRow,
        reapply = ReapplyDungeonRow,
    }

    InstallRewardItemHook()
end

local function SweepRowsNow()
    local lfg = _G.LFGListFrame
    if lfg then
        E.SweepRows(Path(lfg, "SearchPanel", "ScrollBox"), "LFGListSearchEntry", searchEntrySweep)
        E.SweepRows(Path(lfg, "ApplicationViewer", "ScrollBox"), "LFGListApplicant", applicantSweep)
    end

    local queue = _G.LFDQueueFrame
    if queue then
        E.SweepRows(Path(queue, "Specific", "ScrollBox"), DUNGEON_ROW_KEY, dungeonRowSweep)
        E.SweepRows(Path(queue, "Follower", "ScrollBox"), DUNGEON_ROW_KEY, dungeonRowSweep)
    end
end

------------------------------------------------------------
local function InstallHooks()
    InstallGroupButtonHook()
    InstallRowHooks()
end

local function Apply()
    ApplyChrome()
    ApplyGroupButtons()
    ApplyLFD()
    ApplyRaidFinder()
    ApplyLFGList()
    SweepRowsNow()
end

-- 另外兩支配方要用的小工具（同一家族的形狀完全一樣，複製三份沒有意義）
ns.PVESkin.Field = Field
ns.PVESkin.Path = Path
ns.PVESkin.SkinRoleButton = SkinRoleButton
ns.PVESkin.SkinOwnedScrollBar = SkinOwnedScrollBar
ns.PVESkin.SkinKeyedButtons = SkinKeyedButtons
ns.PVESkin.SkinCategoryRing = SkinCategoryRing
ns.PVESkin.SkinCategoryIcon = SkinCategoryIcon
ns.PVESkin.CATEGORY_ROW_POINTS = CATEGORY_ROW_POINTS

E.Register{
    key   = "pve",
    addon = nil,                       -- Blizzard_GroupFinder 的 TOC 是 DefaultState: enabled、非 LoD
    -- 標題用暴雪自己的 `GROUP_FINDER`（zhTW「地城與團隊」/ zhCN「地下城和团队副本」），
    -- 那就是這個視窗的標題與第一顆分頁的字
    title = L["Group Finder"],
    hooks = InstallHooks,
    apply = Apply,
    parts = {
        -- 兩塊住在隨需載入的暴雪插件裡，實作在 Skins/PVP.lua 與 Skins/Challenges.lua
        { addon = "Blizzard_PVPUI",        apply = function() ns.PVESkin.ApplyPVP() end },
        {
            addon = "Blizzard_ChallengesUI",
            -- ⚠ `hooks` 在戰鬥閘**前面**跑：地城圖示是 `ChallengesFrameMixin:Update`
            --   動態建立的，戰鬥中切到這一頁一樣會建，晚裝就整排漏掉（陷阱 4）。
            hooks = function() ns.PVESkin.HookChallenges() end,
            apply = function() ns.PVESkin.ApplyChallenges() end,
        },
    },
    companions = {
        -- 套組內建的預組隊伍過濾插件（`UsePGFButton` ＋ `PremadeGroupsFilterDialog`
        -- 與它的七個面板），實作在 `Skins/PVECompanions.lua`。
        -- ⚠ `atLogin` 不是 `event`：那支插件的視窗、面板與每一個控件都是**檔案層／
        --   XML 一次建完**的（查證出處寫在那一份的檔頭），沒有「第一次顯示才建」
        --   這個掛點 ⇒ 沒有一個暴雪事件擺在對的時間點上。走同一條路（延一幀、
        --   戰鬥閘、脫戰補跑），觸發點改成「配方套完之後」。
        { atLogin = true, apply = function() ns.PVESkin.ApplyCompanions() end },
    },
}
