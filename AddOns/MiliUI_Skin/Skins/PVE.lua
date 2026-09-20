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
--       —— 隨地城換的羊皮紙，內容底材，**不碰**
--   Blizzard_GroupFinder/Shared/LFGFrame.xml:979,1101  LFGCooldownCoverTemplate／LFGBackfillCoverTemplate
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
--   3. **地城／團隊搜尋的羊皮紙是內容底材，留著**（STYLE.md ③ 的內容底材規則）：
--      獎勵說明、地城清單的字都是為它設計的深色字，換底就得接管十幾條文字顏色，
--      而暴雪在 `LFGRewardsFrame_UpdateFrame` 每次都重設。所以這兩頁只換 chrome。
--      連帶的決定：**羊皮紙上的東西一律不碰** —— 指定地城清單的列
--      （`LFDFrameDungeonChoiceTemplate`）、獎勵物品格（`LFGRewardsLootTemplate`）
--      如果套上深色皮，會變成「亮羊皮紙上一排黑方塊」，比不套還糟。
--   4. **角色鈕的圖示是 `NormalTexture` 本身**（`SetNormalAtlas(GetIconForRole(...))`，
--      LFGFrame.lua:2236），不是獨立的 Icon 貼圖 ⇒ **不能中和**，只能中和它背後的
--      `background` 圓底。勾選框（`checkButton`）才是我們接管的部分。
--   5. **搜尋結果列幾乎不用做。** `ResultBG` 本來就是白 4% 的平面矩形、
--      `BackgroundTexture` 是申請狀態的紅／綠／黃（資訊），兩張都不該動；
--      唯一格格不入的是 HIGHLIGHT 層那條藍色滑過帶 ⇒ 只換它的長相。
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
-- | GroupFinderFrame.groupButton1..4 的 bg / ring | SetAlpha(0) |
-- | 同四顆的 HighlightTexture | SetAlpha(0)（改由 overlay 自己畫滑過） |
-- | 同四顆的 name | SetTextColor |
-- | LFDParentFrameRoleBackground、LFDParentFrame.TopTileStreaks | SetAlpha(0) |
-- | RaidFinderFrameRoleBackground | SetAlpha(0) |
-- | 七個 InsetFrameTemplate 的 Bg / NineSlice | SetAlpha(0) |
-- | 八顆角色鈕的 background | SetAlpha(0) |
-- | 八顆角色鈕的 checkButton 的 Normal/Pushed/Disabled 貼圖 | SetAlpha(0) |
-- | 同八顆的 Checked / DisabledChecked 貼圖 | SetColorTexture（職業色） |
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
--   ＋ Engine 既有的三個 `PanelTemplates_*` 全域後置勾（分頁選中態，裝在
--     Core/Engine.lua，全套組共用一組）與分頁的 HookScript("OnEnter"/"OnLeave")。
--   ＋ `Skin.Row` 的 `opts.ownHover` ⇒ 四顆大類按鈕各一組
--     HookScript("OnEnter"/"OnLeave")（`Engine.TrackSelectable`，只碰自己的 overlay）。
--
-- 寫入暴雪欄位：無。
-- 讀暴雪物件：只有 `GetRegions`（PVEFrame.shadows 的三張無名貼圖）與
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
-- * **兩頁的羊皮紙與其上的一切**：`LFDQueueFrameBackground`、
--   `RaidFinderQueueFrameBackground`（內容底材規則）、指定地城清單的池化列
--   （`LFDFrameDungeonChoiceTemplate`，初始化走全域
--    `LFDQueueFrameSpecificList_InitButton`／`LFDQueueFrameFollowerList_InitButton`，
--    勾得到但**刻意不勾**）、獎勵框 `LFGRewardFrameTemplate` 與獎勵物品格。
-- * **角色鈕的圖示／`lockedIndicator`／`alert`／`shortageBorder`／`incentiveIcon`**
--   —— 全部是資訊（能不能當這個角色、有沒有獎勵加成）。
-- * **左側大類按鈕的 `icon`**：被 `CircleMask` 遮成圓形（PVEFrame.xml:38），
--   圓圖配方角邊框只會更難看，而且遮罩不在白名單裡。不裁邊、不加邊。
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
-- * **`PremadeGroupsFilter` 的 `UsePGFButton` 與 `PremadeGroupsFilterDialog`** ——
--   第三方掛在 `LFGListFrame.SearchPanel` / `PVEFrame` 上的元件，各自有自己的皮，
--   這一輪不處理（見回報 ⑤）。
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

-- `UIMenuButtonStretchTemplate`（申請者列的邀請／拒絕鈕）的九片銀色貼圖。
--
-- TODO(升格): 這一組跟 `Skin.Button` 只差「區域名單」，如果之後別的視窗也用到
--   這個模板，就把它升格成 `Skin.Button` 的一個 `opts.keys` 變體。
--
-- ⚠ 一定要 alpha：`UIMenuButtonStretchMixin:SetTextures`
--   （SharedUIPanelTemplates.lua:820）在 OnMouseDown／OnMouseUp／OnShow／OnEnable
--   四個地方把九張的**材質**換掉，但完全不碰 alpha ⇒ 中和撐得住。
local STRETCH_PIECES = {
    "TopLeft", "TopRight", "BottomLeft", "BottomRight",
    "TopMiddle", "MiddleLeft", "MiddleRight", "BottomMiddle", "MiddleMiddle",
}

local function SkinStretchButton(btn, key)
    if not E.Usable(btn, key) then return end
    E.NeutralizeKeys(btn, STRETCH_PIECES, key)
    E.ButtonStates(btn, key)
    E.ButtonFonts(btn, GameFontHighlightSmall, key)
    local ov = E.Overlay(btn, { key = key })
    E.Paint(ov, T.fill, T.border)
    return ov
end

-- 「方形小鈕 ＋ 一張獨立的圖記」：搜尋／申請者頁的重新整理鈕。
--
-- TODO(升格): `Skin.IconButton` 是「圖就是 NormalTexture」的那一種，會把狀態貼圖
--   染色而不是中和。這裡的圖記是另一張 `btn.Icon`，底下的 `UI-SquareButton-*`
--   才是要中和的美術 ⇒ 之後給 `Skin.IconButton` 加一個 `opts.iconKey` 模式。
local function SkinSquareIconButton(btn, key)
    if not E.Usable(btn, key) then return end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    E.ButtonStates(btn, key)
    E.VertexColor(Field(btn, "Icon"), T.textDim, key .. ".Icon")
    local ov = E.Overlay(btn, { key = key })
    E.Paint(ov, T.fill, T.border)
    return ov
end

-- `InputScrollFrameTemplate`（建立隊伍的「詳細說明」多行輸入框）。
--
-- TODO(升格): 九張 `*Tex` 切片是這個模板專屬的命名，跟 `Skin.EditBox` 的
--   Left/Right/Middle 不同一組 ⇒ 之後併成 `Skin.EditBox` 的一個 kind。
local INPUT_SCROLL_TEX = {
    "TopLeftTex", "TopRightTex", "TopTex",
    "BottomLeftTex", "BottomRightTex", "BottomTex",
    "LeftTex", "RightTex", "MiddleTex",
}

local function SkinInputScroll(frame, key)
    if not E.Usable(frame, key) then return end
    E.NeutralizeKeys(frame, INPUT_SCROLL_TEX, key)
    local ov = E.Overlay(frame, { key = key })
    E.Paint(ov, T.fillInset, T.border)

    local bar = Field(frame, "ScrollBar")
    if bar then Skin.ScrollBar(bar, key .. ".ScrollBar") end
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
        Skin.CheckBox(cb, key .. ".checkButton")
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
    for i = 1, 3 do
        local key = "PVEFrameTab" .. i
        local tab = _G[key]
        if tab then
            Skin.Tab(tab, key, "panel")
        else
            E.Missing(key)
        end
    end
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
            -- `bg` 是藍色選單切片、`ring` 是圖示外面那圈鐵環：兩張都是裝飾。
            -- ⚠ `icon` 不碰：它被 `CircleMask` 遮成圓形（PVEFrame.xml:38），
            --   而且是這顆按鈕的身分。
            Skin.Row(btn, key, { keys = { "bg", "ring" }, ownHover = true })
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
    E.NeutralizeGlobals({ "RaidFinderFrameRoleBackground" })

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
        SkinSquareIconButton(refresh, "LFGListFrame.SearchPanel.RefreshButton")
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
        SkinSquareIconButton(refresh, "LFGListFrame.ApplicationViewer.RefreshButton")
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

    SkinInputScroll(Field(panel, "Description"), "LFGListFrame.EntryCreation.Description")

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
local searchEntrySweep, applicantSweep

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
                if btn then SkinStretchButton(btn, "LFGListApplicant." .. key) end
            end
        end,
    }
end

local function SweepRowsNow()
    local lfg = _G.LFGListFrame
    if not lfg then return end
    E.SweepRows(Path(lfg, "SearchPanel", "ScrollBox"), "LFGListSearchEntry", searchEntrySweep)
    E.SweepRows(Path(lfg, "ApplicationViewer", "ScrollBox"), "LFGListApplicant", applicantSweep)
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
        { addon = "Blizzard_ChallengesUI", apply = function() ns.PVESkin.ApplyChallenges() end },
    },
}
