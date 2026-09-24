------------------------------------------------------------
-- 配方：傳奇鑰石（Blizzard_ChallengesUI）—— PVEFrame 的第三個分頁
--
-- 這一份**不是獨立的配方**：它是 `Skins/PVE.lua` 那一筆 `Engine.Register` 的
-- 一個 `part`（`addon = "Blizzard_ChallengesUI"`），共用 `pve` 設定開關。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_ChallengesUI/Blizzard_ChallengesUI_Mainline.toc:2  `## LoadOnDemand: 1`
--   Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.xml:779
--       ChallengesFrame（setAllPoints，parent PVEFrame）
--   同檔 :781   $parentInset ＝ ChallengesFrameInset（InsetFrameTemplate）
--   同檔 :787   ChallengesFrame.WeeklyInfo（ScrollFrame，**沒有** ScrollFrameTemplate
--               ⇒ 沒有 ScrollBar 可以 skin）
--   同檔 :832-858  RuneBG／RunesLarge／RunesSmall／LargeRuneGlow／SmallRuneGlow
--               —— 符文底圖，內容底材
--   同檔 :744   ChallengesDungeonIconFrameTemplate（parentArray DungeonIcons、
--               `mixin="ChallengesDungeonIconMixin"`、frameStrata HIGH、52x52）
--               :747  BORDER 層一張**無名無 parentKey** 的 `ChallengeMode-DungeonIconFrame`
--                     （setAllPoints，就是那圈圓角雕花框）
--               :750  BACKGROUND 層 `Icon`（50x50，置中）
--               :756  BORDER subLevel 2 的 `HighestLevel`（SystemFont_Huge1_Outline，白）
--   Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.lua:201
--               `CreateFrames(self, "DungeonIcons", num, "ChallengesDungeonIconFrameTemplate")`
--               —— 在 `ChallengesFrameMixin:Update` 裡，**第一次需要時才建**
--   同檔 :478   `ChallengesDungeonIconMixin:SetUp(mapInfo, isFirst)`
--               :487 `Icon:SetTexture(texture)` ⇒ **每次都把 texCoord 打回 0,1,0,1**
--               :488 `Icon:SetDesaturated(mapInfo.level == 0)` ⇒ 「沒打過」是資訊
--               :498-504 `HighestLevel` 的文字與顏色（`GetSpecificDungeonOverallScoreRarityColor`）
--   同檔 :218   ChallengesKeystoneFrame（frameStrata HIGH、parent UIParent）
--   同檔 :225   整片 `ChallengeMode-KeystoneFrame` 的 atlas（**就是這個視窗的形狀**）
--   同檔 :420   CloseButton（UIPanelCloseButton）
--   同檔 :430   StartButton（UIPanelButtonTemplate）
--   同檔 :444   KeystoneSlot（物品互動：OnReceiveDrag／OnDragStart／OnClick）
--   Blizzard_GroupFinder/Mainline/PVEFrame.lua:10
--       `hideLeftInset = true` ⇒ 切到這一頁時暴雪自己把 PVEFrame 左半邊整組 Hide
--
-- 查證後跟計畫假設不一樣的三件事：
--   1. **鑰石插槽視窗沒有「chrome」可以換。** `ChallengesKeystoneFrame` 的整片背景
--      就是一張 `ChallengeMode-KeystoneFrame` 的 atlas（.xml:225）—— 它不是矩形邊框，
--      是這個視窗的**形狀本身**，上面的符文、鑰石孔、說明字全部貼著它排。
--      中和掉會剩下一堆浮在空中的字。⇒ 內容底材規則：保留，只做關閉鈕與開始鈕。
--   2. ~~地城圖示格這一輪不做~~ —— **第五輪推翻，見下面第 4 點。**
--   3. **`WeeklyInfo` 不是 `ScrollFrameTemplate`**（.xml:787 沒有 inherits）
--      ⇒ 沒有 `.ScrollBar`，這一頁一條捲軸都沒有。
--
-- 第五輪查證後推翻的一件事：
--   4. **地城圖示格勾得到，而且勾的是「列」不是「容器」。**
--      第四輪的結論（「要勾 `ChallengesFrame` 實例的 `Update`，不然追不上」）
--      搞錯了掛點：要接管的是**每一格**，而每一格都有自己的 mixin
--      `ChallengesDungeonIconMixin:SetUp`（.lua:478）。陷阱 4 的規則是
--      「mixin 後置勾只對**之後建立**的 frame 生效」——
--      而這些格子是 `ChallengesFrameMixin:Update` 裡的 `CreateFrames`（.lua:201）
--      在**頁面第一次需要時**才建的，那比 `Blizzard_ChallengesUI` 的 `ADDON_LOADED`
--      晚。⇒ 只要 hook 裝在 `parts` 的 `hooks`（戰鬥閘**前面**）就一定追得上，
--      跟池化列是完全一樣的形狀 ⇒ 直接走 `Engine.HookRows`。
--      `ChallengeMode-DungeonIconFrame` 那圈圓角雕花因此可以中和掉，換成
--      「裁邊的方形地城圖 ＋ 1px 純黑邊」。
--      ⚠ 保險用的補掃走 `ChallengesFrame:GetChildren()`（讀取例外表的「讀結構」）
--        而**不是** `ChallengesFrame.DungeonIcons` —— 那是暴雪的欄位。
--
------------------------------------------------------------
-- ## taint 接觸面清單（暴雪物件）
--
-- | 物件 | 動作 |
-- |---|---|
-- | ChallengesFrameInset 的 Bg / NineSlice | SetAlpha(0) |
-- | ChallengesKeystoneFrame.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | ChallengesKeystoneFrame.CloseButton 的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | ChallengesKeystoneFrame.StartButton 的 Left/Right/Middle | SetAlpha(0) |
-- | 同上 | SetNormalFontObject(GameFontHighlight) |
-- | 每一格地城圖示裡那張無名的 ChallengeMode-DungeonIconFrame | SetAlpha(0)（走 GetRegions） |
-- | 同每一格的 Icon | SetTexCoord（裁邊，放 reapply） |
-- | 以上各框 | CreateFrame 掛自己的 overlay（不吃滑鼠、零腳本） |
--
-- hook（第五輪新增，一支）：
--   `Engine.HookRows{ mixin = ChallengesDungeonIconMixin, method = "SetUp" }`
--     —— apply：中和那圈圓角雕花（`GetRegions()`，`Icon` 留著、`HighestLevel`
--        是 FontString 本來就不在掃描範圍）＋ 補一塊 `fillInset` ＋ 1px 黑邊的 overlay。
--        reapply：只重裁圖示（`SetUp` 每次 `Icon:SetTexture` 會把 texCoord 打回去）。
--     ⚠ 傳進來的 `mapInfo` / `isFirst` **一個都沒有讀**（apply／reapply 只收 row）。
--
-- 寫入暴雪欄位：無。
-- 讀暴雪物件：`GetRegions`（那張無名的雕花框）、`GetChildren`（補掃認格子）、
--   以及 `Engine.Overlay` 內部的 `GetFrameLevel` —— 都在讀取例外表上。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`ChallengesKeystoneFrame` 的背景 atlas 與全部符文層** —— 見上面第 1 點。
-- * **`ChallengesKeystoneFrame.KeystoneSlot`** —— 物品互動（拖放鑰石），
--   腳本一個都不掛，貼圖也不碰。
-- * **`ChallengesFrame` 的符文底圖（RuneBG／RunesLarge／RunesSmall／兩張 Glow）
--   與 `Background`（`ChallengesFrameMixin:Update` 每次 `SetTexture` 換成當前賽季
--   排名第一那座地城的大圖，.lua:216）** —— 內容底材，而且「本週」「賽季最佳」
--   那幾條字本來就是白色，深底讀得到。
-- * **上方「本週」那一排詞綴圓圖示（`ChallengesKeystoneFrameAffixTemplate`）**
--   —— 圓形是詞綴的識別語彙（跟法術圖示同一套），改成方塊反而跟「地城＝方塊」
--   混在一起。這一輪刻意不動。
-- * **每一格的 `HighestLevel`** —— 數字是資訊，顏色是
--   `C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor` 給的（.lua:497-501）。
-- * **每一格的 `Icon:SetDesaturated(level == 0)`** —— 「這座還沒打過」是狀態，
--   我們只裁邊、不碰飽和度。
-- * **「本週最佳那顆的金色高亮」** —— 查證結果是**沒有這個東西**：`SetUp` 的
--   `isFirst` 參數整支函式沒有用到，模板也沒有 HighlightTexture／SelectedTexture。
--   使用者擷圖裡那格看起來有金框，是那座地城的美術本身就是亮黃色。
-- * **`WeeklyChest`／`DungeonScoreInfo`** —— 寶箱與分數，是內容。
-- * **`ChallengesFrame.SeasonChangeNoticeFrame`**（`frameStrata="DIALOG"`）
--   —— 換季公告，一個賽季看一次。
-- * **套組掛在這個視窗上的四個自製功能** —— 鑰石視窗下方的就位確認／倒數列與
--   自動放鑰石（2026-09-24 起在 `MiliUI_MythicPlus/UI/Keystone.lua`，走 MiliUIWidgets）、
--   本體的 `ChallengesUI_LootTable`（右側裝等對照表）、`PartyKeystone`（右下隊友鑰石）。
--   原本三個有 UI 的各自帶一套「深色半透明底 ＋ 金色邊框」的自畫樣式 —— **第五輪改成走
--   本體 `MiliUI/Style.lua` 的設定視窗皮（`S.ApplyDarkPanel`／`S.ApplyDarkButton`），
--   改在它們自己的檔案裡**，這包一行都沒有碰它們。
-- * **`MplusAdventureGuide` 掛在每一格地城圖示上的東西**（傳送門按鈕、地城縮寫
--   標籤）—— 只讀過它們的原始碼確認層級不會打架，程式碼一行都沒有碰：
--     * 傳送門按鈕是**圖示的子框**（`portal-buttons.lua:327-330`，錨在圖示的
--       `TOP` 之上），子框永遠畫在父框的區域之上，而我們的 overlay 是
--       `levelOffset = -1` 的**兄弟**框 ⇒ 壓不到它。
--     * 縮寫標籤是掛在圖示自己身上、BORDER 層的 FontString
--       （`acronyms.lua:65-68`），同樣錨在圖示之上，而且我們的 overlay 在
--       圖示框之下 ⇒ 壓不到。
--     * `Engine.NeutralizeRegions` 只掃 `GetObjectType() == "Texture"`，
--       那條 FontString 不會被中和。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens

local X = ns.PVESkin
local Field = X.Field

------------------------------------------------------------
-- 「賽季最佳」那一排地城圖示（`ChallengesDungeonIconFrameTemplate`）
--
-- 52x52 的框，裡面一張 50x50 的 `Icon` 置中、外面一圈**無名無 parentKey** 的
-- `ChallengeMode-DungeonIconFrame`（setAllPoints，圓角雕花）。
-- 中和那一圈之後補一個 `fillInset` ＋ 1px 黑邊的 overlay：框 52、圖 50，
-- 左右上下正好各露 1 ⇒ 看起來就是「方形地城圖 ＋ 1px 黑邊」。
--
-- ⚠ 圖示的裁邊放 **reapply**：`ChallengesDungeonIconMixin:SetUp`（.lua:487）
--   每次都 `Icon:SetTexture(texture)`，而 `SetTexture` 會把 texCoord 打回 0,1,0,1。
-- ⚠ overlay 的層級是 `目標層級 − 1`，而這個模板是 `frameStrata="HIGH"`、
--   我們的 overlay 跟著 parent（ChallengesFrame）的 strata 走 ⇒ **實機要確認**
--   那 1px 的邊沒有被 ChallengesFrame 自己的背景大圖蓋掉（待驗證清單）。
------------------------------------------------------------
local DUNGEON_ICON_KEY = "ChallengesDungeonIcon"

local function ApplyDungeonIcon(frame)
    local icon = Field(frame, "Icon")
    -- 那圈雕花沒有名字也沒有 parentKey ⇒ 只剩 GetRegions 一條路。
    -- keep-set 只留 `Icon`；`HighestLevel` 是 FontString，NeutralizeRegions 本來就跳過。
    E.NeutralizeRegions(frame, DUNGEON_ICON_KEY, icon and { [icon] = true } or nil)

    local ov = E.Overlay(frame, { key = DUNGEON_ICON_KEY })
    E.Paint(ov, T.fillInset, T.border)
end

local function ReapplyDungeonIcon(frame)
    local icon = Field(frame, "Icon")
    if icon then E.CropIcon(icon, DUNGEON_ICON_KEY .. ".Icon") end
end

local function MatchDungeonIcon(frame)
    return type(frame) == "table" and frame.HighestLevel ~= nil and frame.Icon ~= nil
end

local dungeonIconSweep

local function HookChallenges()
    local mixin = _G.ChallengesDungeonIconMixin
    if type(mixin) ~= "table" then
        E.Missing("ChallengesDungeonIconMixin")
        return
    end
    dungeonIconSweep = E.HookRows{
        key     = DUNGEON_ICON_KEY,
        mixin   = mixin,
        method  = "SetUp",
        match   = MatchDungeonIcon,
        apply   = ApplyDungeonIcon,
        reapply = ReapplyDungeonIcon,
    }
end

-- 保險用的補掃：萬一有格子在我們裝 hook 之前就建好了（戰鬥中第一次點開這一頁
-- 之類）。`Engine.SweepRows` 要的是 ScrollBox，這裡不是 ⇒ 自己走一遍 children。
-- ⚠ 走 `GetChildren()`（讀取例外表的「讀結構」）而不是 `ChallengesFrame.DungeonIcons`
--   —— 後者是暴雪的欄位，不在例外表上。
local function SweepDungeonIcons()
    if type(dungeonIconSweep) ~= "function" then return end
    local frame = _G.ChallengesFrame
    if not frame or type(frame.GetChildren) ~= "function" then return end
    local ok, children = pcall(function() return { frame:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(children) do
        dungeonIconSweep(child)
    end
end

local function ApplyChallenges()
    local inset = _G.ChallengesFrameInset
    if inset then
        Skin.Inset(inset, "ChallengesFrameInset")
    else
        E.Missing("ChallengesFrameInset")
    end

    SweepDungeonIcons()

    -- 鑰石插槽視窗：只換 chrome 上那兩顆按鈕，背景那張 atlas 就是視窗本身。
    local keystone = _G.ChallengesKeystoneFrame
    if not keystone then
        E.Missing("ChallengesKeystoneFrame")
        return
    end

    local close = Field(keystone, "CloseButton")
    if close then
        Skin.CloseButton(close, "ChallengesKeystoneFrame.CloseButton")
    else
        E.Missing("ChallengesKeystoneFrame.CloseButton")
    end

    X.SkinKeyedButtons(keystone, "ChallengesKeystoneFrame", { "StartButton" })
end

ns.PVESkin.HookChallenges = HookChallenges
ns.PVESkin.ApplyChallenges = ApplyChallenges
