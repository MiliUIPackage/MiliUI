------------------------------------------------------------
-- 配方：角色面板（CharacterFrame）—— 這份是 taint 壓力測試
--
-- 三個分頁都在這一份裡：角色（PaperDollFrame）／聲望（ReputationFrame）／
-- 兌換通貨（TokenFrame）。前兩個住在 Blizzard_UIPanels_Game（常駐），
-- 第三個住在隨需載入的 `Blizzard_TokenUI` ⇒ 走 Engine.Register 的 `parts`。
-- 玩家看到的是一個視窗，所以設定裡也只有一個勾選框。
--
-- 暴雪原始碼出處（12.1.0.69875）：
--   Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml / .lua
--   Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml / .lua
--   Blizzard_UIPanels_Game/Mainline/ReputationFrame.xml / .lua
--   Blizzard_TokenUI/Blizzard_TokenUI.xml / .lua
--   Blizzard_TokenUI/Blizzard_CurrencyTransfer.xml（CurrencyTransferLogToggleButtonTemplate）
--   Blizzard_SharedXML/ListTemplates.xml / .lua（ListHeaderThreeSliceTemplate）
--   Blizzard_Menu/Mainline/MenuTemplates.xml / Blizzard_Menu/MenuTemplates.lua（下拉）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml（ButtonFrameTemplate、
--     PanelTabButtonTemplate、PanelTemplates_SelectTab/DeselectTab）
--   Blizzard_SharedXML/PortraitFrame.lua（TitledPanelMixin:SetTitleColor）
--
-- 為什麼這個視窗是壓力測試：`ToggleCharacter`（按 C）的順序是
-- **先 PanelTemplates_SetTab(CharacterFrame, …) → 後 ShowUIPanel**。只要有任何一顆
-- 原生分頁被插件「寫過」，戰鬥中按 C 就會因為 taint 擴散到 ShowUIPanel 而打不開。
-- 所以這份配方對分頁**只中和貼圖、不寫任何欄位**，選中態一律走
-- hooksecurefunc（後置勾，taint 不會漏回呼叫端）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 視窗本體
--
-- | 物件 | 動作 |
-- |---|---|
-- | CharacterFrame.NineSlice / .Bg / .TopTileStreaks / .PortraitContainer | SetAlpha(0) |
-- | CharacterFrame.Background（atlas character-panel-background） | SetAlpha(0) |
-- | CharacterFrame.TitleContainer.TitleText | SetTextColor |
-- | CharacterFrame.Inset / .InsetRight 的 Bg 與 NineSlice | SetAlpha(0) |
-- | CharacterFrameCloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | CharacterFrameCloseButton 的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | CharacterFrameTab1..3 的 TabTextures（九張） | SetAlpha(0) |
-- | CharacterFrameTab1..3 | SetNormalFontObject(GameFontHighlightSmall) |
--
-- ### 角色頁（PaperDollFrame）
--
-- | 物件 | 動作 |
-- |---|---|
-- | CharacterStatsPane.ClassBackground | SetAlpha(0) |
-- | CharacterStatsPane 的 ItemLevelCategory / AttributesCategory / EnhancementsCategory 的 Background | SetAlpha(0) |
-- | 同上三個的 Title | SetTextColor（分類色 `T.statCategory`；物品等級那塊轉交 `GetItemLevelColor()`） |
-- | 屬性列（`statsFramePool` 池化的 `CharacterStatFrameTemplate`）的 Background | SetAlpha(0) |
-- | 同上的 Label / Value | SetTextColor（`textDim`／分類色，在 14 支 `PaperDollFrame_Set*` 的後置勾裡） |
-- | CharacterStatsPane.ItemLevelFrame.Background | SetAlpha(0) |
-- | CharacterModelFrameBackground{TopLeft,TopRight,BotLeft,BotRight} | SetAlpha(0) |
-- | PaperDollInnerBorder{TopLeft,TopRight,BottomLeft,BottomRight,Left,Right,Top,Bottom,Bottom2} | SetAlpha(0) |
-- | 18 個 `Character<Slot>SlotFrame` 貼圖（裝備格的雕花外框） | SetAlpha(0) |
-- | 18 個 `Character<Slot>Slot` 的 IconBorder / NormalTexture | SetAlpha(0) |
-- | 同 18 顆的 icon | SetTexCoord |
-- | 同 18 顆的 Highlight 貼圖 | SetColorTexture |
-- | 同 18 顆的 IconBorder | IsShown() / GetVertexColor()（**只轉交**，見 STYLE.md ③） |
-- | 武器欄兩側無名的 `Char-Slot-Bottom-Left/Right` | SetAlpha(0)（GetRegions ＋ keep-set） |
-- | PaperDollSidebarTabs.DecorLeft / .DecorRight | SetAlpha(0) |
-- | PaperDollSidebarTab1..3 的 TabBg / Hider | SetAlpha(0) |
-- | PaperDollSidebarTab1..3 的 Icon / Highlight（**文字分頁模式**，第十輪） | SetAlpha(0)；字是我們自己 overlay 上的 FontString |
-- | PaperDollSidebarTab1..3 的 Highlight（圖示模式：字放不進 33 寬時的退路） | SetColorTexture |
-- | PaperDollSidebarTab1..3 | HookScript OnEnter / OnLeave / OnEnable / OnDisable（文字的三態） |
--
-- ### 稱號頁（PaperDollFrame.TitleManagerPane，第十輪）
--
-- | 物件 | 動作 |
-- |---|---|
-- | TitleManagerPane.ScrollBar | 同 chrome 的捲軸 |
-- | 稱號列（池化 `PlayerTitleButtonTemplate`）的 BgTop / BgMiddle / BgBottom | SetAlpha(0) |
-- | 同上的 Stripe | SetAlpha(0)（**reapply**：暴雪每次 Init 都 SetAlpha(0.1)） |
-- | 同上的 Normal / Pushed 貼圖 | SetAlpha(0)；Highlight | SetColorTexture |
-- | 同上 | SetNormalFontObject(GameFontHighlightSmallLeft)（金字改白） |
-- | 同上的 SelectedBar / Check | SetDesaturated ＋ SetVertexColor（職業色；顯隱仍由暴雪的 SetButtonSelected 決定） |
--
-- ### 裝備頁（PaperDollFrame.EquipmentManagerPane，第十輪）
--
-- | 物件 | 動作 |
-- |---|---|
-- | EquipmentManagerPane.EquipSet / .SaveSet（UIPanelButtonTemplate） | 同 Button（裝備＝primary、儲存＝secondary） |
-- | EquipmentManagerPane.ScrollBar | 同 chrome 的捲軸 |
-- | 裝備組列（池化 `GearSetButtonTemplate`）的 BgTop / BgMiddle / BgBottom | SetAlpha(0) |
-- | 同上的 Stripe | SetAlpha(0)（reapply） |
-- | 同上的 HighlightBar | SetDesaturated ＋ SetVertexColor（白）＋ SetAlpha（顯隱由暴雪的 OnUpdate 決定） |
-- | 同上的 SelectedBar / Check | 同稱號列 |
-- | 同上的 icon（NormalTexture） | SetTexCoord（reapply：每次 Init 都 SetTexture）＋ 自己的 1px 方框 |
--
-- ### 聲望頁（ReputationFrame）
--
-- | 物件 | 動作 |
-- |---|---|
-- | ReputationFrame.filterDropdown.Background | SetAlpha(0) |
-- | ReputationFrame.filterDropdown.Arrow | SetVertexColor |
-- | ReputationFrame.ScrollBar 的 Track/Thumb 六張 | SetAlpha(0) |
-- | ReputationFrame.ScrollBar 的 Back/Forward.Texture | SetVertexColor |
-- | 分類列（池化）的 Left / Middle / HighlightRight | SetAlpha(0) |
-- | 分類列的 Right | SetVertexColor（＋／− 記號烤在這張圖裡，不能中和） |
-- | 分類列的 HighlightLeft / HighlightMiddle | SetAlpha(1) ＋ SetColorTexture |
-- | 分類列的 Name | SetTextColor |
-- | 聲望列（池化）的 ReputationBar 的 Background / LeftTexture / RightTexture | SetAlpha(0) |
-- | 同上的填充貼圖 | SetStatusBarTexture（材質；**顏色不碰**） |
-- | 子分類列（池化）的 ToggleCollapseButton 的 Normal/Pushed/Disabled | SetDesaturated ＋ SetVertexColor（reapply） |
-- | ReputationDetailFrame 的無名底圖 / Divider / Border 九片 | SetAlpha(0) |
-- | ReputationDetailFrame 的 Title、三顆勾選框的 Label/Text | SetTextColor |
-- | 同三顆勾選框的 Normal/Pushed/Disabled | SetAlpha(0)；Checked/DisabledChecked | SetColorTexture |
-- | ReputationDetailFrame 的 CloseButton / ScrollBar | 同 chrome |
--
-- ### 兌換通貨頁（TokenFrame，`Blizzard_TokenUI`）
--
-- | 物件 | 動作 |
-- |---|---|
-- | TokenFrame.filterDropdown | 同聲望頁 |
-- | TokenFrame.ScrollBar | 同聲望頁 |
-- | TokenFrame.CurrencyTransferLogToggleButton 的 Normal/Pushed 貼圖 | SetVertexColor |
-- | 同上的 Highlight 貼圖 | SetColorTexture |
-- | TokenFramePopup 的 Border 九片 ＋ Bg | SetAlpha(0) |
-- | TokenFramePopup 的 Title、兩顆勾選框的 Text | SetTextColor |
-- | 同兩顆勾選框 | 同 ReputationDetailFrame 的勾選框 |
-- | TokenFramePopup 的 CloseButton | 同 chrome |
-- | CurrencyTransferLog 的整組 chrome ＋ Background（transfer-log-background） | SetAlpha(0) / SetTextColor / SetColorTexture |
--
-- ⚠ **這一頁的「列」與轉移相關的按鈕一條都不碰**（第六輪改的，理由寫在
--   `HookTokenRows` 上面那一段）：分類列、子分類列、通貨列、轉移紀錄列，
--   以及 `TokenFramePopup.CurrencyTransferToggleButton`。
--   它們跟戰隊通貨轉移那個受保護請求走的是同一條執行流。
--
-- 以上各框：`CreateFrame` 掛自己的 overlay（SetAllPoints／錨在目標上，不吃滑鼠）。
--
-- hook（全部是後置勾，不換函式）：
--   * `hooksecurefunc(CharacterFrame, "SetTitleColor", …)` —— `UpdateDisplay` 每次
--     都會重設標題色（CharacterFrame.lua:119），不掛勾的話白字撐不過一次切分頁。
--   * `hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", …)` —— 側邊欄分頁的選中底色。
--   * **第十輪**：14 支全域 `PaperDollFrame_Set*`（`STAT_SETTERS`）的後置勾 —— 池化屬性列
--     的上色。`PaperDollFrame_UpdateStats` 走 `PAPERDOLL_STATINFO[stat].updateFunc`，而那些
--     閉包全是**按名字呼叫全域**（PaperDollFrame.lua:159-235）⇒ 勾全域就接得到，
--     還順便知道這一列屬於哪個分類（同一支 setter 只出現在一個分類裡）。
--     第一行先認 `GetParent() == CharacterStatsPane`：這幾支是全遊戲的屬性框共用的。
--   * `hooksecurefunc("PaperDollFrame_UpdateStats", …)` —— 「物品等級」那塊標題轉交
--     `GetItemLevelColor()`（暴雪自己在同一支裡拿它給數字上色，PaperDollFrame.lua:1907）。
--   * ⚠ 上面這兩組（14 支 setter ＋ UpdateStats）在**自建屬性清單開著時不裝**
--     （`db.extras.statsPanel`，Extras/CharacterStats.lua）：那時整個 `CharacterStatsPane`
--     是 alpha 0，替看不見的列上色只是白跑。分類標題牌與屬性列的中和照做（無害）。
--   * **第十輪**：`Engine.HookRows` 再加兩支**全域**後置勾（mixin 傳 `_G`）：
--     `PaperDollTitlesPane_InitButton`（PaperDollFrame.lua:2534）、
--     `PaperDollEquipmentManagerPane_InitButton`（:2380）—— 稱號列與裝備組列。
--     兩支都在同一個 if 裡對 Stripe `SetColorTexture`＋`SetAlpha(0.1)`＋`Show()`，
--     所以 Stripe 的中和放 reapply；裝備組的 icon 每次 `SetTexture` ⇒ 裁邊也放 reapply。
--   * `Engine.HookRows` **三**支 mixin 後置勾，全部在**聲望頁**：
--     `ReputationHeaderMixin:Initialize`／`ReputationEntryMixin:Initialize`／
--     `ReputationSubHeaderMixin:Initialize`。
--     ⚠ 第六輪**移除**了五支（全部是兌換通貨那一頁）：`TokenHeaderMixin:Initialize`、
--       `TokenSubHeaderMixin:Initialize`、`TokenEntryMixin:Initialize`、
--       `ListHeaderThreeSliceMixin:CheckHighlightTitle`、
--       `CurrencyTransferLogEntryMixin:Initialize`。理由見那一段。
--   * Engine 的 `SetItemButtonQuality` / `SetItemButtonTexture` 兩個全域後置勾
--     （裝備格的品質方框與裁邊，裝在 Core/Engine.lua，第一行查弱鍵表）。
--   * Engine 的 `PanelTemplates_SelectTab / DeselectTab / SetDisabledTabState`
--     三個全域後置勾（裝在 Core/Engine.lua，全套組共用一組）。
--   * 分頁的 `HookScript("OnEnter"/"OnLeave")`（滑過態；模板自己的 OnEnter 保留）。
--
-- 寫入暴雪欄位：無。
--
-- 讀暴雪物件（契約的讀取例外）：
--   * `PaperDollSidebarTabN.Hider:IsShown()` —— 暴雪自己判斷選中態的**同一個**依據
--     （PaperDollFrame.lua:2678 對選中的那顆 `Hider:Hide()`），在它的後置勾裡讀。
--     純 C 端布林查詢。
--   * 裝備格 `IconBorder` 的 `IsShown()` / `GetVertexColor()` ——
--     **當傳遞者不當讀取者**：四個顏色分量只被原封不動餵進我們自己邊框的
--     `SetColorTexture`，不存、不比較、不做算術（STYLE.md ③ 的傳遞者規則）。
--   * 屬性列的 `GetParent()` —— 只拿來認「這一列是不是 `CharacterStatsPane` 的」
--     （結構查詢；14 支全域 setter 是全遊戲的屬性框共用的，不認就會畫到別人）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **裝備格按鈕的腳本與流程** —— 第三輪對按鈕本身做了視覺（`Skin.ItemButton`：
--   中和圓角品質框與空格雕花、掛自己的 overlay、轉交品質色），但**一個腳本都沒掛**、
--   拾取／裝備流程一個字都沒碰。
--   ⚠ 套組裡有別的插件在這些格子上畫裝等與耐久文字（它的框設在層級 110／111），
--     我們的品質方框是 `target + 1`，壓在它之下；另外那支也 hook 了
--     `SetItemButtonQuality` 並且**可以選擇**畫自己的直角品質邊框（預設關閉）——
--     兩邊都開就會有兩圈幾乎重疊的邊，實機要確認。
-- * **`PaperDollItemSlotButton` 的 `popoutButton`** —— 裝備切換的彈出箭頭，是功能。
-- * 稱號頁的**搜尋框**、裝備頁的**縮放與搬位** —— EllesmereUI 自己重建了稱號清單
--   （加搜尋）、把裝備管理面板 `SetScale(0.85)` 搬到它的欄位裡；前者是功能、
--   後者是重排，都不是皮。稱號搜尋做在 `Extras/CharacterTitles.lua`（自建功能）；
--   裝備頁的搬位不做（它搬是因為把文字分頁移到欄位頂端，我們的字直接放在暴雪分頁上）。
--   這裡兩頁的列照樣換皮（自建稱號清單關掉時看到的就是這一份）。
-- * 裝備組列的 `text` 顏色 —— 暴雪每次 Init 都 `SetTextColor`（金／缺件紅／新增綠，
--   PaperDollFrame.lua:2384-2402），紅與綠是資訊；要只把金改白得讀 setID 去問
--   `C_EquipmentSet`，不值得為它開一條讀取例外。
-- * 裝備組列的 `SpecRing` / `SpecIcon`、`DeleteButton` / `EditButton` —— 專精自動
--   切換的標記與兩顆功能鈕。
-- * 側邊欄分頁的 **tooltip**（`PaperDollFrame_SidebarTab_OnEnter`）—— 文字分頁兩個字
--   說不完的（「裝備管理員」、停用原因）靠它。
-- * **模型場景**（`CharacterModelScene`）本體、它的旋轉／縮放控制、以及
--   `CharacterModelFrameBackgroundOverlay`（那是一張純黑遮罩，留著正好讓模型區
--   比面板再暗一階；而且 `SetPaperDollBackground`（PaperDollFrame.lua:2650）每次
--   都會重設它的 alpha，中和不住）。
-- * 屬性欄的**分類結構** —— 暴雪只有兩塊（屬性／強化）。EllesmereUI 那種次要／第三／
--   攻擊／防禦分開、每塊可收合可排序的清單是它**自己重建**的（自己讀 API、自己畫列），
--   不是皮 ⇒ 做在 `Extras/CharacterStats.lua`（自建功能，2026-10-15）。這裡只做
--   「同一塊同一個顏色」（第十輪），自建清單關掉時看到的就是這一份。
--   （屬性列的 `Background` 隔行底第十輪起**中和**：顏色已經把分類分出來了，
--   隔行條跟分類色線疊在一起反而花。）
-- * 聲望列的 `Content.BackgroundHighlight` —— 滑過／選中／**交戰中**（紅）三種狀態
--   全是暴雪自己在 `RefreshBackgroundHighlightOpacity`（ReputationFrame.lua:436）
--   驅動的，而且紅色那一態是**資訊**。我們自己畫只會蓋掉它。
-- * 聲望條的**填充色** —— `FACTION_BAR_COLORS[reaction]`，中立／友善／崇敬靠它分。
--   （**材質**第三輪換掉了，顏色照樣不碰。）
-- * 子分類列 ＋／− 鈕的**圖形** —— 那是「這一節收起來了沒有」，是資訊不是裝飾，
--   所以只去飽和＋染色，不中和。
-- * 比較視窗的頭像／通貨圖示／幣值圖 —— 身分與值。
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

-- 標題色守門：暴雪在 UpdateDisplay 裡 SetTitleColor(displayInfo.titleColor)，
-- 我們只要在它之後再塗一次白。後置勾不會把 taint 帶回暴雪那條執行流。
local titleHooked = false
local function KeepTitleWhite(frame)
    if titleHooked then return end
    if type(frame.SetTitleColor) ~= "function" then
        E.Missing("CharacterFrame:SetTitleColor")
        return
    end
    titleHooked = true
    hooksecurefunc(frame, "SetTitleColor", function(self)
        local title, fs
        if pcall(function() title = self.TitleContainer end) and title
            and pcall(function() fs = title.TitleText end) and fs then
            E.TextColor(fs, T.text, "CharacterFrame.TitleContainer.TitleText")
        end
    end)
end

------------------------------------------------------------
-- 側邊欄分頁（角色頁右上三顆：角色／稱號／裝備）
--
-- 出處：Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:393
--   `PaperDollSidebarTabTemplate` 33×35：TabBg（底板）、Icon（圖示）、Hider（沒選中時
--   蓋住下緣的那條）、Highlight；三顆從右往左排、間距 4（:499-513）。
--   PaperDollFrame.lua:2673 `PaperDollFrame_UpdateSidebarTabs`：選中的那顆
--   `Hider:Hide()`＋`Highlight:Hide()`，其餘 `Hider:Show()`＋`Highlight:Show()`，
--   並依 `PAPERDOLL_SIDEBARS[i].IsActive()` 對未選中的 `Enable()`／`Disable()`。
--
-- **第十輪改成文字分頁**（照 EllesmereUI 的角色面板：三個字「Character／Titles／
-- Equipment」排在屬性欄上方，選中＝強調色、閒置＝暗、滑過＝白、停用＝更暗）。
-- 它的做法是把暴雪的三顆分頁**搬到**它的文字上面當點擊區（SetAllPoints）——
-- 重排，我們不做；我們反過來把字**放到分頁上**：分頁不動，圖示中和，字是我們自己
-- overlay 上的 FontString。點擊還是暴雪的分頁自己收，跟它一樣「不從程式點分頁」。
--
-- ⚠ 分頁只有 33 寬：中文兩個字剛好，英文「Character」放不下。三段字都先量自己
--   的寬度（`Engine.OverlayText` 的 `maxWidth`），**只要有一段放不下就三顆一起退回
--   圖示模式**（第九輪的樣子：方框 ＋ 圖示 ＋ 選中底色）—— 一排兩種長相比全圖示糟。
-- ⚠ 文字的三態不能靠引擎的 Highlight 貼圖（那是給底色提亮用的），所以對分頁
--   `HookScript` OnEnter／OnLeave／OnEnable／OnDisable 四支（白名單的後掛），狀態
--   記在自己的弱鍵表。初始「能不能按」不讀 `IsEnabled()`：當成可以按，暴雪每次
--   `UpdateSidebarTabs` 都會對未選中的分頁重新 Enable／Disable，第一次刷新就對了。
------------------------------------------------------------
local accentFill = {}
local accentText = {}

-- 文字分頁的狀態（tab → { fs, hover, disabled }）。空表＝圖示模式。
local sidebarLabel = setmetatable({}, { __mode = "k" })
local sidebarLabelMode = false

-- 分頁 33 寬，字最多 31（PaperDollFrame.xml:394）
local SIDEBAR_LABEL_MAX_W = 31

local function SidebarLabelTexts()
    return { L["Character"], L["Titles"], L["Equipment"] }
end

-- 選中態。
--
-- ⚠ 這裡讀了 `tab.Hider:IsShown()`。`PaperDollFrame_UpdateSidebarTabs`
--   （PaperDollFrame.lua:2672-2690）對**選中的**那顆做 `Hider:Hide()`、對其餘做
--   `Hider:Show()` —— 那是暴雪自己判斷選中態的同一個依據，而且 IsShown 是純 C 端
--   的布林查詢：不是文字、不是尺寸、不是錨點，也不會回秘密值。
--   照樣過 `Secret.ToBool`：問不到就當成「沒選中」，畫成閒置比畫成三顆都選中好。
local function PaintSidebarTabs()
    local r, g, b, a = T.AccentFill(1)
    accentFill[1], accentFill[2], accentFill[3], accentFill[4] = r, g, b, a
    accentText[1], accentText[2], accentText[3] = T.Accent()

    for i = 1, 3 do
        local tab = _G["PaperDollSidebarTab" .. i]
        local ov = tab and E.GetOverlay(tab)
        if ov then
            local hider
            pcall(function() hider = tab.Hider end)
            local hidden
            if hider and type(hider.IsShown) == "function" then
                local ok, v = pcall(hider.IsShown, hider)
                if ok then hidden = S.ToBool(v) end
            end
            local selected = hidden == false
            local rec = sidebarLabelMode and sidebarLabel[tab]
            if rec then
                -- 文字分頁：選中＞停用＞滑過＞閒置
                local color
                if selected then
                    color = accentText
                elseif rec.disabled then
                    color = T.textDisabled
                elseif rec.hover then
                    color = T.text
                else
                    color = T.textDim
                end
                rec.fs:SetTextColor(color[1], color[2], color[3], 1)
            else
                E.Fill(ov, selected and accentFill or T.fill)
            end
        end
    end
end

local TRANSPARENT = { 0, 0, 0, 0 }

local function SkinSidebarTabs()
    local host = _G.PaperDollSidebarTabs
    if not host then
        E.Missing("PaperDollSidebarTabs")
        return
    end
    E.NeutralizeKeys(host, { "DecorLeft", "DecorRight" }, "PaperDollSidebarTabs")

    -- 第一輪：建 overlay、放字、量寬。
    local texts = SidebarLabelTexts()
    local tabs, labels = {}, {}
    local allFit = true
    for i = 1, 3 do
        local key = "PaperDollSidebarTab" .. i
        local tab = _G[key]
        if tab then
            -- TabBg 是底板、Hider 是「沒選中時蓋住下緣」的那條。兩張都是裝飾。
            E.NeutralizeKeys(tab, { "TabBg", "Hider" }, key)
            local ov = E.Overlay(tab, { key = key })
            if ov then
                tabs[i] = tab
                labels[i] = E.OverlayText(ov, texts[i], { size = 11, maxWidth = SIDEBAR_LABEL_MAX_W })
                if not labels[i] then allFit = false end
            end
        else
            E.Missing(key)
        end
    end
    sidebarLabelMode = allFit

    -- 第二輪：依模式上皮。
    for i = 1, 3 do
        local tab = tabs[i]
        if tab then
            local key = "PaperDollSidebarTab" .. i
            local ov = E.GetOverlay(tab)
            local hl
            if not (pcall(function() hl = tab.Highlight end) and hl) then
                E.Missing(key .. ".Highlight")
            end
            if sidebarLabelMode then
                -- 文字分頁：沒有框、沒有底，圖示與引擎的滑過貼圖都中和，只剩字。
                E.Paint(ov, TRANSPARENT, false)
                E.NeutralizeKeys(tab, { "Icon" }, key)
                if hl then E.Neutralize(hl, key .. ".Highlight") end
                if not sidebarLabel[tab] then
                    local rec = { fs = labels[i], hover = false, disabled = false }
                    sidebarLabel[tab] = rec
                    tab:HookScript("OnEnter", function() rec.hover = true; PaintSidebarTabs() end)
                    tab:HookScript("OnLeave", function() rec.hover = false; PaintSidebarTabs() end)
                    tab:HookScript("OnEnable", function() rec.disabled = false; PaintSidebarTabs() end)
                    tab:HookScript("OnDisable", function() rec.disabled = true; PaintSidebarTabs() end)
                else
                    sidebarLabel[tab].fs = labels[i]
                end
            else
                -- 圖示模式（第九輪的樣子）。字放不下 ⇒ 全部藏起來。
                E.HideOverlayText(ov)
                -- Highlight 在 HIGHLIGHT 層 ⇒ 引擎自己在滑過時顯示，我們只換長相。
                -- ⚠ 暴雪的 `PaperDollFrame_UpdateSidebarTabs`（PaperDollFrame.lua:2679）
                --   會對**選中的**那顆 `Highlight:Hide()`，所以滑過效果自動只出現在
                --   未選中的分頁上 —— 這是引擎驅動的、不必我們判斷。
                if hl then E.HighlightTexture(hl, key .. ".Highlight") end
                E.Paint(ov, T.fill, T.border)
            end
        end
    end

    PaintSidebarTabs()
end

------------------------------------------------------------
-- 稱號頁與裝備頁（側邊欄第二、三頁，第十輪）
--
-- 出處：Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml
--   :540 `PaperDollFrame.TitleManagerPane`：ScrollBox（WowScrollBoxList）＋
--        ScrollBar（MinimalScrollBar）
--   :137 `PlayerTitleButtonTemplate` 169×22：BgTop／BgBottom（Char-Stat-Top）、
--        BgMiddle（Char-Stat-Middle 直向平鋪）、Stripe、Check（UI-CheckBox-Check，
--        選中才顯示）、SelectedBar（UI-FriendsFrame-HighlightBar，ADD 0.4，選中才顯示）、
--        text（ButtonText，GameFontNormalSmallLeft ＝ 金字）、HighlightTexture（藍條 ADD）
--   :571 `PaperDollFrame.EquipmentManagerPane`：EquipSet／SaveSet 兩顆
--        UIPanelButtonTemplate ＋ ScrollBox ＋ ScrollBar
--   :203 `GearSetButtonTemplate` 169×44：同樣的三片底圖與 Stripe；icon 是
--        **NormalTexture**（36×36）；HighlightBar（藍條 ADD，OnUpdate 依 IsMouseOver
--        顯隱，PaperDollFrame.lua:2293-2307）；SelectedBar／Check 同稱號列；
--        SpecRing／SpecIcon、DeleteButton／EditButton 不碰
--   PaperDollFrame.lua:2534 `PaperDollTitlesPane_InitButton`、:2380
--        `PaperDollEquipmentManagerPane_InitButton`：兩支都是**具名全域**，每次 Init
--        對 Stripe `SetColorTexture`＋`SetAlpha(0.1)`＋`Show()`（偶數列）；
--        裝備組那支每次 `icon:SetTexture`（texCoord 被打回）。
--
-- 樣式照 EllesmereUI（它對暴雪原生的這兩頁做的事）：三片雕花底圖拿掉、每列一塊
-- 同色的淡底、滑過白 8%、選中換強調色、金字改白。它搬了裝備面板的位置與縮放，
-- 我們不搬（見檔頭「刻意不碰」）。
--
-- ⚠ SelectedBar／Check／HighlightBar 的**顯隱**全部是暴雪在管（`SetButtonSelected`、
--   `OnUpdate`），我們只換長相：去飽和（它們是金／藍的素材，`SetVertexColor` 是乘法）
--   再染色。alpha 是區域的，跟顏色的 alpha 相乘，所以只動一種。
-- ⚠ 稱號列的字是 **ButtonText** ⇒ 顏色跟著 NormalFontObject 走，換成
--   `GameFontHighlightSmallLeft`（同字級、白）而不是 SetTextColor（註 ⓔ）。
------------------------------------------------------------
local TITLE_ROW_KEY = "TitleManagerPane.row"
local GEAR_ROW_KEY = "EquipmentManagerPane.row"
local titleSweep, gearSweep

local function TintSelection(row, key)
    accentText[1], accentText[2], accentText[3] = T.Accent()
    for _, name in ipairs({ "SelectedBar", "Check" }) do
        local tex
        if pcall(function() tex = row[name] end) and tex then
            E.Desaturate(tex, key .. "." .. name)
            E.VertexColor(tex, accentText, key .. "." .. name)
        end
    end
end

local function NeutralizeStripe(row, key)
    local stripe
    if pcall(function() stripe = row.Stripe end) and stripe then
        E.Neutralize(stripe, key .. ".Stripe")
    end
end

local function IsTitleRow(row)
    return type(row) == "table" and row.BgMiddle ~= nil and row.SelectedBar ~= nil and row.icon == nil
end

local function IsGearRow(row)
    return type(row) == "table" and row.BgMiddle ~= nil and row.SelectedBar ~= nil and row.icon ~= nil
end

local function ApplyTitleRow(row)
    Skin.Row(row, TITLE_ROW_KEY, { keys = { "BgTop", "BgMiddle", "BgBottom" } })
    E.ButtonFonts(row, GameFontHighlightSmallLeft, TITLE_ROW_KEY)
    TintSelection(row, TITLE_ROW_KEY)
end

local function ReapplyTitleRow(row)
    NeutralizeStripe(row, TITLE_ROW_KEY)
end

local function ApplyGearRow(row)
    E.NeutralizeKeys(row, { "BgTop", "BgMiddle", "BgBottom" }, GEAR_ROW_KEY)
    local ov = E.Overlay(row, { key = GEAR_ROW_KEY, noBorder = true })
    E.Paint(ov, T.fill, false)
    -- 滑過條：暴雪的 OnUpdate 依 IsMouseOver 顯隱，我們把藍條壓成白、alpha 降到提亮一階。
    local hl
    if pcall(function() hl = row.HighlightBar end) and hl then
        E.Desaturate(hl, GEAR_ROW_KEY .. ".HighlightBar")
        E.VertexColor(hl, T.text, GEAR_ROW_KEY .. ".HighlightBar")
        pcall(hl.SetAlpha, hl, T.highlightAlpha * 3)
    end
    TintSelection(row, GEAR_ROW_KEY)
    local icon
    if pcall(function() icon = row.icon end) and icon then
        Skin.Icon(icon, GEAR_ROW_KEY .. ".icon")
    end
end

local function ReapplyGearRow(row)
    NeutralizeStripe(row, GEAR_ROW_KEY)
    local icon
    if pcall(function() icon = row.icon end) and icon then
        E.CropIcon(icon, GEAR_ROW_KEY .. ".icon")
    end
end

local function HookSidebarPaneRows()
    titleSweep = E.HookRows{
        key     = TITLE_ROW_KEY,
        mixin   = _G,
        method  = "PaperDollTitlesPane_InitButton",
        match   = IsTitleRow,
        apply   = ApplyTitleRow,
        reapply = ReapplyTitleRow,
    }
    gearSweep = E.HookRows{
        key     = GEAR_ROW_KEY,
        mixin   = _G,
        method  = "PaperDollEquipmentManagerPane_InitButton",
        match   = IsGearRow,
        apply   = ApplyGearRow,
        reapply = ReapplyGearRow,
    }
end

local function ApplySidebarPanes()
    local doll = _G.PaperDollFrame
    if not doll then
        E.Missing("PaperDollFrame")
        return
    end

    local titles
    if pcall(function() titles = doll.TitleManagerPane end) and titles then
        local bar, box
        if pcall(function() bar = titles.ScrollBar; box = titles.ScrollBox end) then
            if bar then Skin.ScrollBar(bar, "TitleManagerPane.ScrollBar") else E.Missing("TitleManagerPane.ScrollBar") end
            if box then E.SweepRows(box, "TitleManagerPane.ScrollBox", titleSweep) end
        end
    else
        E.Missing("PaperDollFrame.TitleManagerPane")
    end

    local gear
    if pcall(function() gear = doll.EquipmentManagerPane end) and gear then
        local equip, save, bar, box
        if pcall(function()
            equip = gear.EquipSet; save = gear.SaveSet; bar = gear.ScrollBar; box = gear.ScrollBox
        end) then
            -- 「裝備」是這一頁的主動作 ⇒ primary；「儲存」平行選項 ⇒ secondary（按鈕上色規則）
            if equip then Skin.Button(equip, "EquipmentManagerPane.EquipSet", { variant = "primary" }) else E.Missing("EquipmentManagerPane.EquipSet") end
            if save then Skin.Button(save, "EquipmentManagerPane.SaveSet") else E.Missing("EquipmentManagerPane.SaveSet") end
            if bar then Skin.ScrollBar(bar, "EquipmentManagerPane.ScrollBar") else E.Missing("EquipmentManagerPane.ScrollBar") end
            if box then E.SweepRows(box, "EquipmentManagerPane.ScrollBox", gearSweep) end
        end
    else
        E.Missing("PaperDollFrame.EquipmentManagerPane")
    end
end

------------------------------------------------------------
-- 角色頁
------------------------------------------------------------
-- 人物模型四周那圈雕花內框（PaperDollFrame.xml:667-714，全部是全域具名貼圖）
local MODEL_BORDER_GLOBALS = {
    "PaperDollInnerBorderTopLeft",
    "PaperDollInnerBorderTopRight",
    "PaperDollInnerBorderBottomLeft",
    "PaperDollInnerBorderBottomRight",
    "PaperDollInnerBorderLeft",
    "PaperDollInnerBorderRight",
    "PaperDollInnerBorderTop",
    "PaperDollInnerBorderBottom",
    "PaperDollInnerBorderBottom2",
    -- 模型後面那張場景底圖（四塊拼的），中和掉就只剩乾淨的深色
    "CharacterModelFrameBackgroundTopLeft",
    "CharacterModelFrameBackgroundTopRight",
    "CharacterModelFrameBackgroundBotLeft",
    "CharacterModelFrameBackgroundBotRight",
}

-- 裝備格的雕花外框（PaperDollFrame.xml:86/107/128 的 `$parentFrame`）。
-- 名字＝`Character<Slot>Slot` .. "Frame"。
local EQUIP_SLOTS = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
    "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
    "MainHand", "SecondaryHand",
}

local STAT_CATEGORIES = { "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }

-- 分類標題兩側那兩條線的外側要對齊底下屬性列的字（EllesmereUI 的做法：左線齊標籤、
-- 右線齊數值）。分類框 197 寬、屬性列 187 寬置中 ⇒ 列的左緣離分類框 5；
-- 列裡 Label 錨 LEFT x=11、Value 錨 RIGHT x=-8（CharacterFrame.xml:101-121）
-- ⇒ 左 5+11＝16、右 5+8＝13。
local STAT_RULE_PAD_LEFT, STAT_RULE_PAD_RIGHT = 16, 13

------------------------------------------------------------
-- 屬性列（`CharacterStatsPane.statsFramePool` 池化的 `CharacterStatFrameTemplate`）
--
-- 出處（12.1）：
--   Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml:101
--     187×15；Background（atlas UI-Character-Info-Line-Bounce，alpha 0.3，隔行提亮條）、
--     Label（GameFontNormalSmall，錨 LEFT x=11）、Value（GameFontHighlightSmall，錨 RIGHT x=-8）
--   PaperDollFrame.lua:1900 `PaperDollFrame_UpdateStats`
--     每次更新 `ReleaseAll` 之後逐一 `Acquire`、呼叫 `PAPERDOLL_STATINFO[stat].updateFunc`、
--     然後 `Background:SetShown(numStatInCat % 2 == 0)`。
--   PaperDollFrame.lua:159-235 `PAPERDOLL_STATINFO`
--     每個 updateFunc 都是 `function(statFrame, unit) PaperDollFrame_SetXxx(statFrame, unit) end`
--     ⇒ 按名字呼叫全域，`hooksecurefunc("PaperDollFrame_SetXxx")` 接得到，
--     而且哪一支 setter 屬於哪個分類是 `PAPERDOLL_STATCATEGORIES`（:244）寫死的。
--
-- 樣式照 EllesmereUI：標籤 `textDim`、數值染該分類的顏色、隔行底中和、
-- 標籤與數值之間一條白 6% 的引導線（錨在兩個 FontString 的內側，自己跟著字長縮放）。
--
-- ⚠ 列是池化重用的：同一顆 frame 這次是「敏捷」、下次可能是「致命一擊」（分類不同）
--   ⇒ 數值顏色每次後置勾都重上；中和與標籤色只做一次（弱鍵表記住）。
-- ⚠ 暴雪對列的 Value **從不** SetTextColor（grep 過 PaperDollFrame.lua），
--   所以不必另外在 UpdateStats 後面重申。
-- ⚠ 這 14 支是全遊戲的屬性框共用的全域函式，第一行先認 parent。
------------------------------------------------------------
local STAT_SETTERS = {
    -- 屬性（PAPERDOLL_STATCATEGORIES[1]）
    PaperDollFrame_SetStat        = "AttributesCategory",   -- 力量／敏捷／智力／耐力
    PaperDollFrame_SetArmor       = "AttributesCategory",
    PaperDollFrame_SetStagger     = "AttributesCategory",
    PaperDollFrame_SetManaRegen   = "AttributesCategory",
    -- 強化（PAPERDOLL_STATCATEGORIES[2]）
    PaperDollFrame_SetCritChance  = "EnhancementsCategory",
    PaperDollFrame_SetHaste       = "EnhancementsCategory",
    PaperDollFrame_SetMastery     = "EnhancementsCategory",
    PaperDollFrame_SetVersatility = "EnhancementsCategory",
    PaperDollFrame_SetLifesteal   = "EnhancementsCategory",
    PaperDollFrame_SetAvoidance   = "EnhancementsCategory",
    PaperDollFrame_SetSpeed       = "EnhancementsCategory",
    PaperDollFrame_SetDodge       = "EnhancementsCategory",
    PaperDollFrame_SetParry       = "EnhancementsCategory",
    PaperDollFrame_SetBlock       = "EnhancementsCategory",
}

local STAT_ROW_KEY = "CharacterStatsPane.statsFramePool"
local statRows = setmetatable({}, { __mode = "k" })
local statHookBroken = false

local function IsOurStatRow(row)
    if type(row) ~= "table" or type(row.GetParent) ~= "function" then return false end
    local ok, parent = pcall(row.GetParent, row)
    return ok and parent ~= nil and parent == _G.CharacterStatsPane
end

local function PaintStatRow(row, category)
    if not statRows[row] then
        if not E.Usable(row, STAT_ROW_KEY) then return end
        statRows[row] = true
        E.NeutralizeKeys(row, { "Background" }, STAT_ROW_KEY)
        local label, value
        pcall(function() label = row.Label; value = row.Value end)
        if label then
            E.TextColor(label, T.textDim, STAT_ROW_KEY .. ".Label")
        end
        if label and value then
            local ov = E.Overlay(row, {
                key = STAT_ROW_KEY .. ".leader",
                slot = "leader",
                noBorder = true,
                height = 1,
                points = {
                    { "LEFT", "RIGHT", 10, 0, rel = label },
                    { "RIGHT", "LEFT", -10, 0, rel = value },
                },
            })
            E.Paint(ov, T.statLeader)
        end
    end
    local value
    if pcall(function() value = row.Value end) and value then
        E.TextColor(value, T.statCategory[category] or T.text, STAT_ROW_KEY .. ".Value")
    end
end

local function HookStatRows()
    -- 自建屬性清單開著 ⇒ 暴雪的屬性欄整塊 alpha 0，不必替它上色（見檔頭 hook 那段）
    if ns.DB.IsExtraEnabled("statsPanel") then return end
    for name, category in pairs(STAT_SETTERS) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, function(row)
                if statHookBroken or not IsOurStatRow(row) then return end
                local ok, err = pcall(PaintStatRow, row, category)
                if not ok then
                    statHookBroken = true
                    E.NoteBrokenHook(name)
                    ns.ReportError(err)
                end
            end)
        else
            E.Missing(name)
        end
    end
end

-- 「物品等級」那塊標題：轉交暴雪給數字的顏色（`GetItemLevelColor()`，依平均裝等的品質）。
-- 暴雪自己在 `PaperDollFrame_UpdateStats` 裡拿同一支給 `ItemLevelFrame.Value` 上色
-- （PaperDollFrame.lua:1907），我們掛在它後面、對標題與兩條線做同一件事。
-- 分量只往 setter 送，不比較、不算術；萬一拿回來的不是數字（也不是秘密值）就不動。
local function PaintItemLevelTitle()
    local pane = _G.CharacterStatsPane
    local cat
    if not (pane and pcall(function() cat = pane.ItemLevelCategory end) and cat) then return end
    if type(_G.GetItemLevelColor) ~= "function" then return end
    local ok, r, g, b = pcall(_G.GetItemLevelColor)
    if not ok then return end
    if not S.IsSecret(r) and type(r) ~= "number" then return end
    Skin.FlankedTitleColor(cat, "CharacterStatsPane.ItemLevelCategory", { r, g, b })
end

-- 武器欄兩側那兩塊括號形雕花（`Char-Slot-Bottom-Left` / `-Right`，
-- PaperDollFrame.xml:906,920）是**無名也沒有 parentKey** 的貼圖，掛在
-- `CharacterMainHandSlot` / `CharacterSecondaryHandSlot` 自己的 BACKGROUND 層
-- ⇒ 指名不到，只剩 `GetRegions()`。掃的時候要把「不是裝飾」的留下來：
-- 圖示、品質框、兩層額外的圈、搜尋遮罩、物品情境遮罩、忽略標記與數量。
-- （`$parentFrame` 那張 `Char-BottomSlot` **不留** —— 它本來就要中和，
--   而且它有全域名字，另外一條路已經掃過了，重複中和無害。）
local WEAPON_SLOT_KEEP = {
    "icon", "IconBorder", "IconOverlay", "IconOverlay2",
    "searchOverlay", "ItemContextOverlay", "ignoreTexture",
}

local function ApplyPaperDoll()
    -- 右側屬性欄的職業底圖（UI-Character-Info-<CLASS>-BG）
    local pane = _G.CharacterStatsPane
    if not pane then
        E.Missing("CharacterStatsPane")
    else
        E.NeutralizeKeys(pane, { "ClassBackground" }, "CharacterStatsPane")

        -- 三塊分類標題牌（物品等級／屬性／強化）：「—— 標題 ——」，字跟線染分類色。
        -- 物品等級那一塊沒有固定色（`T.statCategory` 沒有它），先白、
        -- 緊接著 `PaintItemLevelTitle` 轉交品質色。
        for _, key in ipairs(STAT_CATEGORIES) do
            local cat
            if pcall(function() cat = pane[key] end) and cat then
                Skin.FlankedTitle(cat, "CharacterStatsPane." .. key, {
                    padLeft = STAT_RULE_PAD_LEFT,
                    padRight = STAT_RULE_PAD_RIGHT,
                    color = T.statCategory[key] or T.text,
                })
            else
                E.Missing("CharacterStatsPane." .. key)
            end
        end
        PaintItemLevelTitle()

        -- 物品等級數字底下那張 UI-Character-Info-ItemLevel-Bounce
        local ilvl
        if pcall(function() ilvl = pane.ItemLevelFrame end) and ilvl then
            E.NeutralizeKeys(ilvl, { "Background" }, "CharacterStatsPane.ItemLevelFrame")
        else
            E.Missing("CharacterStatsPane.ItemLevelFrame")
        end
    end

    E.NeutralizeGlobals(MODEL_BORDER_GLOBALS)

    -- 裝備格。
    --
    -- 第二輪只對那張純裝飾的外框貼圖（`Character<Slot>SlotFrame`）SetAlpha(0)，
    -- 按鈕本身完全不碰 —— 所以擷圖裡剩下的是暴雪那圈**圓角**品質邊框，
    -- 跟這包的直角語彙對不上。第三輪改走 `Skin.ItemButton`：
    -- 圓角框中和、自己畫一圈直角方框、顏色**轉交**暴雪給的品質色。
    --
    -- ⚠ 還是不掛任何腳本、不碰拾取／裝備流程；`Skin.ItemButton` 只做
    --   SetAlpha／SetTexCoord／SetColorTexture ＋ 自己的 overlay。
    -- ⚠ 套組裡有插件在這些格子上畫裝等與耐久文字，它把自己的框做成格子的 child
    --   並且設在很高的層級（110／111），我們這一圈邊是 target+1（個位數），
    --   壓在它之下，兩邊不會互相蓋。
    for _, slot in ipairs(EQUIP_SLOTS) do
        E.Neutralize(_G["Character" .. slot .. "SlotFrame"], "Character" .. slot .. "SlotFrame")
        local name = "Character" .. slot .. "Slot"
        local btn = _G[name]
        if btn then
            Skin.ItemButton(btn, name)
        else
            E.Missing(name)
        end
    end

    -- 武器欄兩側殘留的括號形雕花（見 WEAPON_SLOT_KEEP 上面那段）
    for _, name in ipairs({ "CharacterMainHandSlot", "CharacterSecondaryHandSlot" }) do
        local btn = _G[name]
        if btn then
            E.NeutralizeRegions(btn, name, E.KeepSet(btn, WEAPON_SLOT_KEEP))
        end
    end

    SkinSidebarTabs()
    ApplySidebarPanes()
end

------------------------------------------------------------
-- 清單列（聲望頁／兌換通貨頁共用的兩種列）
--
-- 兩頁的分類列是**同一個模板家族**：聲望用自己那份
-- （ReputationFrame.xml:3 的 `ReputationHeaderTemplate`），通貨用共用層那份
-- （ListTemplates.xml:53 的 `ListHeaderThreeSliceTemplate`），九個 parentKey 一模一樣。
------------------------------------------------------------
local function ApplyListHeader(prefix)
    return function(row)
        Skin.ListHeader(row, prefix)
        local name
        if pcall(function() name = row.Name end) and name then
            E.TextColor(name, T.text, prefix .. ".Name")
        end
    end
end

-- 分類列是不是這個模板（SweepRows 補掃時認人用的，讀結構不讀值）
local function IsThreeSliceHeader(row)
    return type(row) == "table" and row.HighlightMiddle ~= nil and row.Right ~= nil
end

------------------------------------------------------------
-- 子分類列的 ＋／− 小鈕（聲望頁的「銀月城宮廷」、兌換通貨頁的「功能」「區域」…）
--
-- 出處：
--   Blizzard_TokenUI/Blizzard_TokenUI.xml:13
--     `TokenSubHeaderTemplate` 的 `ToggleCollapseButton`（20x20），
--     Normal/Pushed 是 `campaign_headericon_closed` / `_closedpressed` 的 atlas，
--     Highlight 是 `UI-PlusButton-Hilight`
--   Blizzard_TokenUI/Blizzard_TokenUI.lua:200,219   TokenSubHeaderMixin:Initialize → RefreshIcon
--   Blizzard_UIPanels_Game/Mainline/ReputationFrame.lua:581,602-605  聲望頁的同一套
--
-- ⚠ 那張 atlas 是**紅底金框**的，`SetVertexColor` 是乘法，乘不出中性灰
--   ⇒ 先 `SetDesaturated(true)` 壓成灰階再染 `textDim`（見 Engine.Desaturate）。
-- ⚠ `RefreshIcon` 每次收合／展開都重設 atlas（`GetNormalTexture():SetAtlas(...)`）
--   ⇒ 去飽和與染色一律放 **reapply**，不賭「撐不撐得過 SetAtlas」。
-- ⚠ ＋／− 的**圖形本身是資訊**（這一節收起來了沒有），所以不中和、只換顏色。
------------------------------------------------------------
local function SkinCollapseButton(row, prefix)
    local btn
    if not (pcall(function() btn = row.ToggleCollapseButton end) and btn) then return end
    Skin.IconButton(btn, prefix .. ".ToggleCollapseButton", { desaturate = true })
end

local function RefreshCollapseButton(row, prefix)
    local btn
    if not (pcall(function() btn = row.ToggleCollapseButton end) and btn) then return end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then
                E.Desaturate(tex, prefix .. ".ToggleCollapseButton." .. getter)
                E.VertexColor(tex, T.textDim, prefix .. ".ToggleCollapseButton." .. getter)
            end
        end
    end
end

------------------------------------------------------------
-- 聲望頁
------------------------------------------------------------
local repHeaderSweep, repEntrySweep

local function HookReputationRows()
    repHeaderSweep = E.HookRows{
        key    = "ReputationHeader",
        mixin  = _G.ReputationHeaderMixin,
        method = "Initialize",
        match  = IsThreeSliceHeader,
        apply  = ApplyListHeader("ReputationHeader"),
        -- reapply 不需要：`ReputationHeaderMixin:Initialize`（ReputationFrame.lua:205）
        -- 只重設 Right / HighlightRight 的 **atlas**，而 atlas 跟 alpha／vertex color
        -- 是各自獨立的屬性，我們下的中和與染色都撐得過去。
    }

    repEntrySweep = E.HookRows{
        key    = "ReputationEntry",
        mixin  = _G.ReputationEntryMixin,
        method = "Initialize",
        match  = function(row)
            return type(row) == "table" and type(row.Content) == "table"
                and row.Content.ReputationBar ~= nil
        end,
        apply  = function(row)
            local bar
            if pcall(function() bar = row.Content.ReputationBar end) and bar then
                -- ⚠ 不傳 color：填充色是暴雪依聲望等級給的資訊
                --   （`ReputationBarMixin:UpdateBarColor`，ReputationFrame.lua:619），
                --   而且那一支每次 Initialize 都會重設（.lua:502,524,547）。
                -- ⚠ 材質**換成套組的細橫紋**（`Skin.StatusBar` 預設就換）：
                --   `ReputationBarTemplate` 的 `<BarTexture>` 是
                --   `UI-Character-Skills-Bar`（ReputationFrame.xml:126），自帶漸層與
                --   上緣高光。查過 `ReputationBarMixin` 沒有任何 `GetStatusBarTexture()`
                --   的讀回，換材質安全。
                -- ⚠ `pad = 2`：條只有 **13** 高（`ReputationBarTemplate` 的
                --   `<Size x="99" y="13"/>`，ReputationFrame.xml），但上面那條
                --   `BarText`（`GameFontHighlightSmall`）的中文字面高過 13 ——
                --   不留內距的話「名望 3」的上下兩端會壓在邊線上（實機擷圖 16）。
                --   往外推 2 之後框變 17 高，列高 22 仍然放得下（`ReputationEntryTemplate`
                --   的 `y="22"`），列與列之間還留得住 3 的間距。
                Skin.StatusBar(bar, "ReputationEntry.ReputationBar", {
                    keys = { "Background", "LeftTexture", "RightTexture" },
                    pad  = 2,
                })
            end
        end,
    }

    -- 子分類列（帶 ＋／− 鈕的那一種）
    E.HookRows{
        key    = "ReputationSubHeader",
        mixin  = _G.ReputationSubHeaderMixin,
        method = "Initialize",
        apply  = function(row) SkinCollapseButton(row, "ReputationSubHeader") end,
        reapply = function(row) RefreshCollapseButton(row, "ReputationSubHeader") end,
    }
end

------------------------------------------------------------
-- 聲望詳情小視窗（點一列聲望之後彈出來的那個）
--
-- 出處：Blizzard_UIPanels_Game/Mainline/ReputationFrame.xml:270
--   `ReputationFrame.ReputationDetailFrame`（212x203，**不是**隨需載入，
--    跟聲望頁同一個檔就建好了，只是預設 hidden）
--     ARTWORK 一張無名的 `UI-Character-Reputation-DetailBackground`（260x128）
--     OVERLAY `Divider`（UI-DialogBox-Divider）
--     `Border`（DialogBorderTemplate，九片掛在自己身上）
--     `ScrollingDescription`（ScrollingFontTemplate）＋ `…ScrollBar`
--     `CloseButton`（UIPanelCloseButton）
--     三顆勾選框：`AtWarCheckbox`（自己一套美術）、`MakeInactiveCheckbox`、
--       `WatchFactionCheckbox`（後兩顆是 UICheckButtonTemplate）
------------------------------------------------------------
local REP_DETAIL_CHECKBOXES = { "AtWarCheckbox", "MakeInactiveCheckbox", "WatchFactionCheckbox" }

local function ApplyReputationDetail(f)
    local d
    if not (pcall(function() d = f.ReputationDetailFrame end) and d) then
        E.Missing("ReputationFrame.ReputationDetailFrame")
        return
    end

    -- 那張底圖與分隔線都**無名無 parentKey** ⇒ GetRegions 掃（只掃 Texture，
    -- `Title` 是 FontString 自動排除）。`Divider` 有 parentKey，一起掃到也無妨。
    E.NeutralizeRegions(d, "ReputationDetailFrame")
    E.NeutralizeChildNineSlices(d, "ReputationDetailFrame")

    local border
    if pcall(function() border = d.Border end) and border then
        E.NeutralizeKeys(border, NINE_SLICE_PIECES, "ReputationDetailFrame.Border")
        E.NeutralizeKeys(border, { "Bg" }, "ReputationDetailFrame.Border")
    end

    local ov = E.Overlay(d, { key = "ReputationDetailFrame" })
    E.Paint(ov, T.fill, T.border)

    local title
    if pcall(function() title = d.Title end) and title then
        E.TextColor(title, T.text, "ReputationDetailFrame.Title")
    end

    local close
    if pcall(function() close = d.CloseButton end) and close then
        Skin.CloseButton(close, "ReputationDetailFrame.CloseButton")
    end

    local bar
    if pcall(function() bar = d.ScrollingDescriptionScrollBar end) and bar then
        Skin.ScrollBar(bar, "ReputationDetailFrame.ScrollBar")
    end

    -- `Skin.CheckBox` 第一次派上用場的地方之一（另一個是寄信頁的單選鈕）
    for _, key in ipairs(REP_DETAIL_CHECKBOXES) do
        local cb
        if pcall(function() cb = d[key] end) and cb then
            Skin.CheckBox(cb, "ReputationDetailFrame." .. key)
            local label
            if pcall(function() label = cb.Label end) and label then
                E.TextColor(label, T.text, "ReputationDetailFrame." .. key .. ".Label")
            end
            local text
            if pcall(function() text = cb.Text end) and text then
                E.TextColor(text, T.text, "ReputationDetailFrame." .. key .. ".Text")
            end
        end
    end
end

local function ApplyReputation()
    local f = _G.ReputationFrame
    if not f then
        E.Missing("ReputationFrame")
        return
    end

    ApplyReputationDetail(f)

    local dd
    if pcall(function() dd = f.filterDropdown end) and dd then
        Skin.Dropdown(dd, "ReputationFrame.filterDropdown", "style1")
    else
        E.Missing("ReputationFrame.filterDropdown")
    end

    local bar
    if pcall(function() bar = f.ScrollBar end) and bar then
        Skin.ScrollBar(bar, "ReputationFrame.ScrollBar")
    else
        E.Missing("ReputationFrame.ScrollBar")
    end

    -- 補掃：正常情況下 PLAYER_LOGIN 時一列都還沒建立（ScrollBox 是開視窗才長列的），
    -- 但「戰鬥中第一次點開聲望頁」會讓列先於 apply 出現（hook 在戰鬥閘前面裝好了，
    -- 所以那些列其實已經處理過；這一掃是給 hook 也沒趕上的情況留的保險）。
    local box
    if pcall(function() box = f.ScrollBox end) and box then
        E.SweepRows(box, "ReputationFrame.ScrollBox", repHeaderSweep, repEntrySweep)
    end
end

------------------------------------------------------------
-- 兌換通貨頁（Blizzard_TokenUI，隨需載入）
------------------------------------------------------------
--
-- ⚠⚠ **第六輪把兌換通貨頁的「列級」東西全部拿掉了。**
--
--   這一頁（`TokenFrame`）跟別的清單不一樣：那條列的更新路徑，跟**戰隊通貨轉移**
--   （`RequestCurrencyFromAccountCharacter`）這個受保護請求走的是同一條執行流。
--   也就是說我們掛在列上的任何東西 —— 連「把底帶淡化」這種純視覺的動作 ——
--   都可能讓那個轉移在玩家真的要用的時候被封鎖，而且錯誤不會指向這裡。
--   代價與收益完全不對等：收益是幾條列上的圖示有沒有 1px 邊，
--   代價是一個「只在玩家要轉通貨的那一刻才發作」的功能性故障。
--
--   ⇒ 拿掉的是：`TokenHeaderMixin:Initialize`、`TokenSubHeaderMixin:Initialize`、
--     `TokenEntryMixin:Initialize`、`ListHeaderThreeSliceMixin:CheckHighlightTitle`
--     （這一支只為通貨掛的，聲望頁走自己的 `ReputationHeaderMixin`，不受影響）、
--     以及 `CurrencyTransferLogEntryMixin:Initialize`。
--   ⇒ 留下的是**外框級**的東西：Inset、捲軸、篩選下拉、右上的紀錄鈕，
--     以及兩個彈出視窗的 chrome 與關閉鈕。那些都不在那條執行流上。
--   ⇒ **聲望頁的列維持現狀**：它沒有轉移動作，`ReputationEntryMixin` 那一條
--     是一般的清單列。
--
--   這一頁因此看起來會是「外框有皮、列是暴雪原樣」。那是刻意的。
local function HookTokenRows()
    -- 目前一支都沒有，而且**刻意**沒有（理由見上面那段）。
    -- 留著這支空函式是為了讓 `E.Register` 的 part 形狀不變，也為了下次有人想
    -- 「順手把通貨列也上皮」的時候先讀到上面那段字。
end

------------------------------------------------------------
-- 兌換通貨頁的兩個彈出小視窗
--
-- 出處：
--   Blizzard_TokenUI/Blizzard_TokenUI.xml:185  `TokenFramePopup`（197x100，
--     `Border` 是 SecureDialogBorderTemplate，兩顆 UICheckButtonTemplate、
--     一顆 `CurrencyTransferToggleButton`、一顆 UIPanelCloseButton）
--   Blizzard_TokenUI/Blizzard_TokenUI.xml:179  `CurrencyTransferLog`
--     ← `CurrencyTransferLogTemplate`（Blizzard_CurrencyTransfer.xml:384，
--        **ButtonFrameTemplate**：有 Inset、有 CloseButton、有 ScrollBox/ScrollBar，
--        外加一張 `Background`（atlas transfer-log-background）鋪滿 Inset）
--   Blizzard_TokenUI/Blizzard_CurrencyTransfer.xml:299  `CurrencyTransferLogEntryTemplate`
--     （`CurrencyIcon` / `CurrencyQuantity` / `SourceName` / `Arrow` / `DestinationName`
--      ＋ 一個 alpha 0 的 `BackgroundHighlight` 框）
--
-- ⚠ 兩個都跟 TokenFrame 住在同一個隨需載入插件裡 ⇒ 走同一個 part，
--   **不另開設定開關**（玩家看到的是同一個視窗）。
------------------------------------------------------------
local TOKEN_POPUP_CHECKBOXES = { "InactiveCheckbox", "BackpackCheckbox" }

local function ApplyTokenPopup()
    local p = _G.TokenFramePopup
    if not p then
        E.Missing("TokenFramePopup")
        return
    end

    local border
    if pcall(function() border = p.Border end) and border then
        E.NeutralizeKeys(border, NINE_SLICE_PIECES, "TokenFramePopup.Border")
        E.NeutralizeKeys(border, { "Bg" }, "TokenFramePopup.Border")
    end
    E.NeutralizeChildNineSlices(p, "TokenFramePopup")

    local ov = E.Overlay(p, { key = "TokenFramePopup" })
    E.Paint(ov, T.fill, T.border)

    local title
    if pcall(function() title = p.Title end) and title then
        E.TextColor(title, T.text, "TokenFramePopup.Title")
    end

    for _, key in ipairs(TOKEN_POPUP_CHECKBOXES) do
        local cb
        if pcall(function() cb = p[key] end) and cb then
            Skin.CheckBox(cb, "TokenFramePopup." .. key)
            local text
            if pcall(function() text = cb.Text end) and text then
                E.TextColor(text, T.text, "TokenFramePopup." .. key .. ".Text")
            end
        end
    end

    -- ⚠ `CurrencyTransferToggleButton`（「轉移通貨」那顆）**第六輪起不碰**：
    --   它是通往 `RequestCurrencyFromAccountCharacter` 那條受保護請求的入口，
    --   跟通貨列同一條執行流（見上面 `HookTokenRows` 那段）。
    --   `Skin.Button` 會中和它的三片、換字型物件、還掛兩個 OnEnter/OnLeave ——
    --   收益是一顆按鈕的長相，代價是踩在功能性故障的正上方。
    --   結果是這個小視窗裡留著一顆原生按鈕，刻意的。

    -- ⚠ 這顆關閉鈕的 parentKey 在 XML 裡寫成 `$parent.CloseButton`
    --   （Blizzard_TokenUI.xml:231）—— 那是一個**字面上的 key**，不是
    --   `p.CloseButton`。所以兩種都試，找不到才記進 debug 清單。
    local close
    pcall(function() close = p.CloseButton or p["$parent.CloseButton"] end)
    if close then
        Skin.CloseButton(close, "TokenFramePopup.CloseButton")
    else
        E.Missing("TokenFramePopup.CloseButton")
    end
end

local function ApplyCurrencyTransferLog()
    local log = _G.CurrencyTransferLog
    if not log then
        E.Missing("CurrencyTransferLog")
        return
    end

    Skin.PortraitChrome(log, "CurrencyTransferLog")
    Skin.Panel(log, "CurrencyTransferLog")

    -- `transfer-log-background`：鋪滿 Inset 的那張底圖
    E.NeutralizeKeys(log, { "Background" }, "CurrencyTransferLog")

    local inset
    if pcall(function() inset = log.Inset end) and inset then
        Skin.Inset(inset, "CurrencyTransferLog.Inset")
    end

    local close
    if pcall(function() close = log.CloseButton end) and close then
        Skin.CloseButton(close, "CurrencyTransferLog.CloseButton")
    end

    local bar
    if pcall(function() bar = log.ScrollBar end) and bar then
        Skin.ScrollBar(bar, "CurrencyTransferLog.ScrollBar")
    end

    local empty
    if pcall(function() empty = log.EmptyLogMessage end) and empty then
        E.TextColor(empty, T.textDim, "CurrencyTransferLog.EmptyLogMessage")
    end
end

-- ⚠ 轉移紀錄的**列**第六輪拿掉了（`CurrencyTransferLogEntryMixin:Initialize`
--   的後置勾、圖示裁邊、`SourceName`／`DestinationName` 改白、`Arrow` 染色）。
--   那個視窗整個存在的理由就是通貨轉移，它的列跟轉移請求是同一條執行流；
--   紀錄列上那幾個字是暗金色不好看，但「不好看」跟「轉移被封鎖」不是同一個量級。
--   視窗本身的 chrome（外框、Inset、關閉鈕、捲軸、空清單提示）留著。

local function ApplyToken()
    local f = _G.TokenFrame
    if not f then
        E.Missing("TokenFrame")
        return
    end

    ApplyTokenPopup()
    ApplyCurrencyTransferLog()

    local dd
    if pcall(function() dd = f.filterDropdown end) and dd then
        Skin.Dropdown(dd, "TokenFrame.filterDropdown", "style1")
    else
        E.Missing("TokenFrame.filterDropdown")
    end

    local bar
    if pcall(function() bar = f.ScrollBar end) and bar then
        Skin.ScrollBar(bar, "TokenFrame.ScrollBar")
    else
        E.Missing("TokenFrame.ScrollBar")
    end

    local logBtn
    if pcall(function() logBtn = f.CurrencyTransferLogToggleButton end) and logBtn then
        Skin.IconButton(logBtn, "TokenFrame.CurrencyTransferLogToggleButton")
    else
        E.Missing("TokenFrame.CurrencyTransferLogToggleButton")
    end

    -- ⚠ 這裡**沒有** `E.SweepRows` —— 通貨列一條都不掃（見 `HookTokenRows`）。
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function InstallHooks()
    -- ⚠ 這一段**不過戰鬥閘**（Engine 的 RunUnit 在戰鬥閘之前跑它）。
    --   mixin hook 裝晚了，先建好的列永遠不會進來 —— 見 STYLE.md ③ 的陷阱 4。
    --   `hooksecurefunc` 本身不寫任何暴雪欄位，戰鬥中完全安全。
    if type(_G.PaperDollFrame_UpdateSidebarTabs) == "function" then
        hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", PaintSidebarTabs)
    else
        E.Missing("PaperDollFrame_UpdateSidebarTabs")
    end
    if ns.DB.IsExtraEnabled("statsPanel") then
        -- 自建屬性清單開著：暴雪的屬性欄看不見，物品等級標題不必轉交顏色（見 HookStatRows）
    elseif type(_G.PaperDollFrame_UpdateStats) == "function" then
        hooksecurefunc("PaperDollFrame_UpdateStats", PaintItemLevelTitle)
    else
        E.Missing("PaperDollFrame_UpdateStats")
    end
    HookStatRows()
    HookSidebarPaneRows()
    HookReputationRows()
end

local function Apply()
    local f = CharacterFrame
    if not f then
        E.Missing("CharacterFrame")
        return
    end

    Skin.PortraitChrome(f, "CharacterFrame")
    KeepTitleWhite(f)

    -- character-panel-background：鋪滿 Inset 的整塊底圖。它在 CharacterFrame 自己的
    -- BACKGROUND 層，而我們的 overlay 壓在 CharacterFrame 之下 ⇒ 不中和就看不到皮。
    -- 這張不是「文字為它設計的」內容底材（人物模型畫在它上面，模型自帶不透明像素），
    -- 所以照中和。
    local bg
    if pcall(function() bg = f.Background end) and bg then
        E.Neutralize(bg, "CharacterFrame.Background")
    else
        E.Missing("CharacterFrame.Background")
    end

    Skin.Panel(f, "CharacterFrame")

    for _, key in ipairs({ "Inset", "InsetRight" }) do
        local inset
        if pcall(function() inset = f[key] end) and inset then
            Skin.Inset(inset, "CharacterFrame." .. key)
        else
            E.Missing("CharacterFrame." .. key)
        end
    end

    local close = _G.CharacterFrameCloseButton
    if close then
        Skin.CloseButton(close, "CharacterFrameCloseButton")
    else
        E.Missing("CharacterFrameCloseButton")
    end

    -- 底部三顆分頁（角色資訊／聲望／貨幣）。第三顆平常是隱藏的，照樣要套 ——
    -- 它顯示出來的時候不會再跑一次配方。
    --
    -- ⚠ 走 `Skin.TabGroup`：接縫由「下一顆分頁的左緣」決定，相鄰兩顆共用一條
    --   1px 黑線（第四輪的「往右多畫 7」會在選中的分頁右邊畫出兩條，實機擷圖 15）。
    -- ⚠ 第三顆會被藏起來，但它排在**最後**，所以不用標 `hideable`：藏起來的框
    --   照樣有位置，第二顆的右緣錨在它的左緣上不會留洞（`hideable` 是給
    --   「中間那一顆會消失」的情況用的，見收藏視窗的傳家寶分頁）。
    local tabs = {}
    for i = 1, 3 do
        local key = "CharacterFrameTab" .. i
        local tab = _G[key]
        if tab then
            tabs[#tabs + 1] = { tab = tab, key = key }
        else
            E.Missing(key)
        end
    end
    Skin.TabGroup(tabs, { kind = "panel", joined = "TOP" })

    ApplyPaperDoll()
    ApplyReputation()
end

E.Register{
    key   = "character",
    addon = nil,                       -- Blizzard_UIPanels_Game 是 LoadFirst，永遠在
    title = L["Character Info"],
    hooks = InstallHooks,
    apply = Apply,
    parts = {
        -- 兌換通貨頁是獨立的隨需載入插件，但對玩家來說是同一個視窗 ⇒ 不另開設定開關
        { addon = "Blizzard_TokenUI", hooks = HookTokenRows, apply = ApplyToken },
    },
}
