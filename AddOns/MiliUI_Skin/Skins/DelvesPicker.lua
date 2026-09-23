------------------------------------------------------------
-- 配方：探究／世界副本的難度選擇視窗（`DelvesDifficultyPickerFrame`，
--       隨需載入 `Blizzard_DelvesDifficultyPicker`）
--
-- 走進探究入口、或世界副本（`Enum.TieredEntranceType.Lairs`）入口時跳出來的那一個：
-- 左邊是地點名稱＋難度下拉＋「進入」，右邊是說明與可能獲得的獎勵，**整片背景是
-- 那個地點的場景圖**。兩種入口是**同一個框**（`DelvesDifficultyPickerFrameMixin:OnLoad`
-- 裡 `tieredEntranceStaticData` 同時登記 Delve 與 Lairs 兩份資料）。
--
-- 使用者的要求：**保留那張底圖**，其餘換成套組的樣子。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_DelvesDifficultyPicker/Blizzard_DelvesDifficultyPicker.xml
--     `DelvesDifficultyPickerFrame` ← `CustomGossipFrameBaseTemplate, InsetFrameTemplate`（584x384）
--     `Title`（GameFontHighlightHuge2，白）／`ScenarioLabel`（GameFontNormal，暗金）／
--     `EntranceErrorText`（ERROR_COLOR）／`DividingLine`／`Description`（GameFontNormalMed1，暗金）
--     子框：`Border`（**DialogBorderTemplate**，錨在視窗外 -8/+9）／`CloseButton`（UIPanelCloseButton）／
--     `Dropdown`（WowStyle1DropdownTemplate）／`DelveModifiersWidgetContainer`（**UIWidgetContainerTemplate**）／
--     `TieredEntranceViewRewardsButton`（lair-button-reward 三張 atlas）／
--     `DelveBackgroundWidgetContainer`（**UIWidgetContainerTemplate**，frameStrata BACKGROUND —— 場景圖就是它）／
--     `EnterDelveButton`（UIPanelButtonTemplate）／`DelveRewardsContainerFrame`（`RewardText` ＋
--     `ScrollBox` ＋ `ScrollBar` ← MinimalScrollBar）／
--     `ChallengesContainerFrame`（**TalentFrameGridTemplate** —— 挑戰詞綴是一棵天賦樹）
--   Blizzard_DelvesDifficultyPicker.lua
--     `OnLoad` → `self.Border.Bg:Hide()`（DialogBorder 的羊皮紙底本來就藏著）
--     `UpdateWidgets` → 有場景圖時 `self.Bg:Hide()`、沒有時 `self.Bg:Show()`
--       （`Bg` 是 InsetFrameTemplate 的底）
--     `TryShow` → 三行字只 `SetText`，**沒有任何 `SetTextColor`**（全檔零處對這三條下色）
--     `CheckAndSetDisplayMode` → 暴雪自己 `ClearAllPoints`／`SetPoint` 重排進入鈕、獎勵區、
--       詞綴列（兩種版面）⇒ 我們的 overlay 全部錨在目標上，跟著走
--     `DelvesDifficultyPickerEnterDelveButtonMixin:OnClick` → `C_DelvesUI.SelectDelveEntranceTier`
--
------------------------------------------------------------
-- ## 範圍：只換「框」，場景圖、詞綴、挑戰樹一律不碰
--
-- **不碰的（也是這一份最重要的一段）：**
-- * **兩個 `UIWidgetContainerTemplate`（場景圖、地圖詞綴列）整棵子樹。** 小工具的值在
--   副本內是秘密值，而那兩棵樹由 `LayoutFrame` 排版 —— 在裡面寫任何東西、甚至多掛一個
--   子框，都會在之後某次重排時以「attempt to compare a secret number」從暴雪的
--   LayoutFrame 炸出來，錯誤指向跟我們隔了兩個系統的檔案。**我們在那兩棵樹裡：
--   零個 region、零個子框、零次 SetAlpha。** 連 `ModifiersLabel` 那行字都不碰。
-- * **`ChallengesContainerFrame`**：它是 `TalentFrameGridTemplate`，選挑戰＝提交一份 trait 設定
--   （`AttemptConfigOperation` → `CommitConfig`）—— 跟天賦視窗的樹是同一條執行流。
-- * `InsetFrameTemplate` 的 `Bg`：暴雪依「有沒有場景圖」切它的顯示；我們不跟它搶。
-- * `TieredEntranceViewRewardsButton`（世界副本的「查看獎勵」大圓鈕）、`DividingLine`、
--   獎勵清單的每一列（`LargeItemButtonTemplate`：圖示＋羊皮紙名牌＋品質色字 —— 名牌壓在
--   場景圖上正好是讓字讀得出來的那一層）、難度下拉的彈出選單。
--
-- **換掉的：**
-- * 外框：`Border`（DialogBorder 的雕花九宮格）與 `NineSlice`（Inset 的內框）alpha 0，
--   改成**一圈 1px 職業色邊、不畫底**。浮在世界上方、彈出來選一下就關 ⇒ 判準是**提示皮**
--   （STYLE.md ①，同確認彈窗／ESC 選單的外框），只是底**刻意留空**讓場景圖露出來。
--   邊畫在前景（`Skin.BorderOnly`，level +1）：場景圖的 frame 在 BACKGROUND strata、
--   而我們的邊是這個視窗的子框，永遠在它之上。
-- * 關閉鈕、難度下拉、捲軸：一般原語。
-- * 「進入」：零腳本 primary（`Engine.ScriptlessButton`）—— 按下去是傳送進副本。
-- * 字：`Description`（說明）暗金→白；`ScenarioLabel`（「探究」這一行小標）→ `textDim`；
--   `RewardText`（「可能獲得：」）→ `textDim`（它是欄位標籤）。三條都只在 XML 設過色、
--   Lua 從不重設 ⇒ 一次 `SetTextColor` 就永久有效。`Title` 本來就是白的。
--   `EntranceErrorText` 是錯誤紅＝資訊，不碰。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `Border`（整個子框）、`NineSlice` | `SetAlpha(0)` |
-- | `CloseButton` | Normal／Disabled `SetAlpha(0)`；Highlight／Pushed `SetColorTexture`（`Skin.CloseButton`） |
-- | `Dropdown` | `Background`／`Arrow` `SetAlpha(0)` ＋ ⌄ 圖記（`Skin.Dropdown`） |
-- | `EnterDelveButton` | `Left`／`Right`／`Middle` `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 的 `SetColorTexture`。**零 HookScript** |
-- | `DelveRewardsContainerFrame.ScrollBar` | Track／Thumb／Back／Forward `SetAlpha(0)`／`SetVertexColor`（`Skin.ScrollBar`） |
-- | `Description`／`ScenarioLabel`／`DelveRewardsContainerFrame.RewardText` | `SetTextColor` |
-- | 視窗本身 | 以它為 parent 建我們自己的邊框子框（不吃滑鼠） |
--
-- **hook：0 支 `hooksecurefunc`。** 只有原語內建的 `HookScript("OnEnter"/"OnLeave")`
-- （關閉鈕、下拉、捲軸箭頭），內容只換我們自己 overlay 的顏色。
-- **讀取：只有 parentKey。**
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

local function Required(owner, key, label)
    local child = Optional(owner, key)
    if not child then E.Missing(label) end
    return child
end

local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function Apply()
    local f = _G.DelvesDifficultyPickerFrame
    if not f then
        E.Missing("DelvesDifficultyPickerFrame")
        return
    end
    local key = "DelvesDifficultyPickerFrame"
    if not E.Usable(f, key) then return end

    -- 外框：雕花九宮格與內框中和，換一圈 1px 職業色邊（不畫底 ⇒ 場景圖整片露出來）
    E.NeutralizeKeys(f, { "Border", "NineSlice" }, key)
    Skin.BorderOnly(f, key, { border = { T.Accent() } })

    local close = Required(f, "CloseButton", key .. ".CloseButton")
    if close then Skin.CloseButton(close, key .. ".CloseButton") end

    local dd = Required(f, "Dropdown", key .. ".Dropdown")
    if dd then Skin.Dropdown(dd, key .. ".Dropdown", "style1") end

    -- 「進入」：零腳本 primary（先建 overlay 再中和，同 Professions.lua 的 CommerceButton）
    local enter = Required(f, "EnterDelveButton", key .. ".EnterDelveButton")
    if enter then
        local bkey = key .. ".EnterDelveButton"
        local ov = E.Overlay(enter, { key = bkey })
        if ov then
            E.NeutralizeKeys(enter, PANEL_BUTTON_ART, bkey)
            E.ButtonFonts(enter, GameFontHighlight, bkey)
            E.ScriptlessButton(enter, ov, "primary", bkey)
        end
    end

    local rc = Required(f, "DelveRewardsContainerFrame", key .. ".DelveRewardsContainerFrame")
    if rc then
        local bar = Optional(rc, "ScrollBar")
        if bar then Skin.ScrollBar(bar, key .. ".DelveRewardsContainerFrame.ScrollBar") end
        local rt = Optional(rc, "RewardText")
        if rt then E.TextColor(rt, T.textDim, key .. ".RewardText") end
    end

    local desc = Optional(f, "Description")
    if desc then E.TextColor(desc, T.text, key .. ".Description") end
    local label = Optional(f, "ScenarioLabel")
    if label then E.TextColor(label, T.textDim, key .. ".ScenarioLabel") end
end

E.Register{
    key   = "delvespicker",
    addon = "Blizzard_DelvesDifficultyPicker",
    title = L["Delve Difficulty Picker"],
    apply = Apply,
}
