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
-- | 同上三個的 Title | SetTextColor |
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
-- | PaperDollSidebarTab1..3 的 Highlight | SetColorTexture |
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
-- * **模型場景**（`CharacterModelScene`）本體、它的旋轉／縮放控制、以及
--   `CharacterModelFrameBackgroundOverlay`（那是一張純黑遮罩，留著正好讓模型區
--   比面板再暗一階；而且 `SetPaperDollBackground`（PaperDollFrame.lua:2650）每次
--   都會重設它的 alpha，中和不住）。
-- * **屬性列**（`CharacterStatFrameTemplate`）的 `Background` —— 那是 alpha 0.3 的
--   細長提亮條，等於隔行底色，留著。
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
-- 側邊欄分頁（角色頁右上三顆圖示）
------------------------------------------------------------
local accentFill = {}

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
            E.Fill(ov, hidden == false and accentFill or T.fill)
        end
    end
end

local function SkinSidebarTabs()
    local host = _G.PaperDollSidebarTabs
    if not host then
        E.Missing("PaperDollSidebarTabs")
        return
    end
    E.NeutralizeKeys(host, { "DecorLeft", "DecorRight" }, "PaperDollSidebarTabs")

    for i = 1, 3 do
        local key = "PaperDollSidebarTab" .. i
        local tab = _G[key]
        if tab then
            -- TabBg 是底板、Hider 是「沒選中時蓋住下緣」的那條。兩張都是裝飾。
            E.NeutralizeKeys(tab, { "TabBg", "Hider" }, key)

            -- Highlight 在 HIGHLIGHT 層 ⇒ 引擎自己在滑過時顯示，我們只換長相。
            -- ⚠ 暴雪的 `PaperDollFrame_UpdateSidebarTabs`（PaperDollFrame.lua:2679）
            --   會對**選中的**那顆 `Highlight:Hide()`，所以滑過效果自動只出現在
            --   未選中的分頁上 —— 這是引擎驅動的、不必我們判斷。
            local hl
            if pcall(function() hl = tab.Highlight end) and hl then
                E.HighlightTexture(hl, key .. ".Highlight")
            else
                E.Missing(key .. ".Highlight")
            end

            local ov = E.Overlay(tab, { key = key })
            E.Paint(ov, T.fill, T.border)
        else
            E.Missing(key)
        end
    end

    PaintSidebarTabs()
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

        -- 三塊分類標題牌（物品等級／屬性／強化）
        for _, key in ipairs(STAT_CATEGORIES) do
            local cat
            if pcall(function() cat = pane[key] end) and cat then
                Skin.SectionTitle(cat, "CharacterStatsPane." .. key, { pad = 10, y = 2 })
            else
                E.Missing("CharacterStatsPane." .. key)
            end
        end

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
