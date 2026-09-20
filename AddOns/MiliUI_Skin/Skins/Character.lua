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
--
-- ### 兌換通貨頁（TokenFrame，`Blizzard_TokenUI`）
--
-- | 物件 | 動作 |
-- |---|---|
-- | TokenFrame.filterDropdown | 同聲望頁 |
-- | TokenFrame.ScrollBar | 同聲望頁 |
-- | TokenFrame.CurrencyTransferLogToggleButton 的 Normal/Pushed 貼圖 | SetVertexColor |
-- | 同上的 Highlight 貼圖 | SetColorTexture |
-- | 分類列（池化） | 同聲望頁的分類列 |
-- | 通貨列（池化）的 Content.CurrencyIcon | SetTexCoord |
--
-- 以上各框：`CreateFrame` 掛自己的 overlay（SetAllPoints／錨在目標上，不吃滑鼠）。
--
-- hook（全部是後置勾，不換函式）：
--   * `hooksecurefunc(CharacterFrame, "SetTitleColor", …)` —— `UpdateDisplay` 每次
--     都會重設標題色（CharacterFrame.lua:119），不掛勾的話白字撐不過一次切分頁。
--   * `hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", …)` —— 側邊欄分頁的選中底色。
--   * `Engine.HookRows` 四支 mixin 後置勾（聲望分類列／聲望列／通貨分類列／通貨列）
--     ＋ 一支 `ListHeaderThreeSliceMixin:CheckHighlightTitle`（只重申文字顏色）。
--   * Engine 的 `PanelTemplates_SelectTab / DeselectTab / SetDisabledTabState`
--     三個全域後置勾（裝在 Core/Engine.lua，全套組共用一組）。
--   * 分頁的 `HookScript("OnEnter"/"OnLeave")`（滑過態；模板自己的 OnEnter 保留）。
--
-- 寫入暴雪欄位：無。
--
-- 讀暴雪物件（契約的讀取例外，全部是純 C 端布林／結構查詢）：
--   * `PaperDollSidebarTabN.Hider:IsShown()` —— 暴雪自己判斷選中態的**同一個**依據
--     （PaperDollFrame.lua:2678 對選中的那顆 `Hider:Hide()`），在它的後置勾裡讀。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **裝備格按鈕本身**（`PaperDollItemSlotButton` 系）—— 只對它旁邊那張純裝飾的
--   `Character<Slot>SlotFrame` 貼圖 SetAlpha(0)，**不在按鈕上掛 overlay、不掛任何
--   腳本、不碰它的 Normal/Highlight**。那顆按鈕會走拾取／裝備流程，而且這個套組裡
--   有別的插件在上面畫裝等與耐久文字 —— 少碰一樣東西就少一條互相蓋掉的路。
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
-- * `ReputationDetailFrame` / `TokenFramePopup` / `CurrencyTransferLog` ——
--   彈出小視窗，STYLE.md ⑦ 的 B 級，另外一輪再做。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret
local L = ns.L

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

    -- 裝備格：**只動那張純裝飾的外框貼圖**，按鈕本身一個字都不碰。
    for _, slot in ipairs(EQUIP_SLOTS) do
        E.Neutralize(_G["Character" .. slot .. "SlotFrame"], "Character" .. slot .. "SlotFrame")
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
                --   （`ReputationBarMixin:UpdateBarColor`，ReputationFrame.lua:619）。
                Skin.StatusBar(bar, "ReputationEntry.ReputationBar", {
                    keys = { "Background", "LeftTexture", "RightTexture" },
                })
            end
        end,
    }
end

local function ApplyReputation()
    local f = _G.ReputationFrame
    if not f then
        E.Missing("ReputationFrame")
        return
    end

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
local tokenHeaderSweep, tokenEntrySweep

local function HookTokenRows()
    tokenHeaderSweep = E.HookRows{
        key    = "TokenHeader",
        mixin  = _G.TokenHeaderMixin,
        method = "Initialize",
        match  = IsThreeSliceHeader,
        apply  = ApplyListHeader("TokenHeader"),
    }

    -- ⚠ 通貨分類列的標題顏色跟聲望的不一樣：它走共用層的
    --   `ListHeaderVisualMixin:CheckHighlightTitle`（ListTemplates.lua:48），
    --   每次滑鼠進出都 `SetTextColor(self:GetTitleColor(isMouseOver))`，而
    --   `TokenHeaderMixin:OnLoad_TokenHeaderTemplate`（Blizzard_TokenUI.lua:12）
    --   把兩態都設成 NORMAL_FONT_COLOR（暗金）。要它變白就只能在後置勾裡重申。
    --
    -- ⚠ hook 的對象是 **ListHeaderThreeSliceMixin**，不是 ListHeaderVisualMixin：
    --   `ListHeaderThreeSliceMixin = CreateFromMixins(ListHeaderVisualMixin)`
    --   （ListTemplates.lua:150）在**檔案載入時**就把函式拷貝過去了，之後再 hook
    --   來源那張表已經追不上。這是陷阱 4 的同一條規則往上一層：
    --   mixin 的拷貝發生在「被拷貝的那一刻」，不是呼叫的那一刻。
    --
    -- requireKnown：這支是共用模板，全遊戲的三片式分類列都會進來。
    -- 只對我們 apply 過的列做事，其餘第一行就返回。
    E.HookRows{
        key          = "TokenHeader.CheckHighlightTitle",
        mixin        = _G.ListHeaderThreeSliceMixin,
        method       = "CheckHighlightTitle",
        requireKnown = true,
        reapply      = function(row)
            local name
            if pcall(function() name = row.Name end) and name then
                E.TextColor(name, T.text, "TokenHeader.Name")
            end
        end,
    }

    tokenEntrySweep = E.HookRows{
        key    = "TokenEntry",
        mixin  = _G.TokenEntryMixin,
        method = "Initialize",
        match  = function(row)
            return type(row) == "table" and type(row.Content) == "table"
                and row.Content.CurrencyIcon ~= nil
        end,
        apply  = function(row)
            local icon
            if pcall(function() icon = row.Content.CurrencyIcon end) and icon then
                Skin.Icon(icon, "TokenEntry.CurrencyIcon")
            end
        end,
        -- ⚠ `TokenEntryMixin:Initialize`（Blizzard_TokenUI.lua:52）每次都
        --   `CurrencyIcon:SetTexture(elementData.iconFileID)`，而 SetTexture 會把
        --   texCoord 打回 0,1,0,1 ⇒ 裁邊每一次都要重下。
        reapply = function(row)
            local icon
            if pcall(function() icon = row.Content.CurrencyIcon end) and icon then
                E.CropIcon(icon, "TokenEntry.CurrencyIcon")
            end
        end,
    }
end

local function ApplyToken()
    local f = _G.TokenFrame
    if not f then
        E.Missing("TokenFrame")
        return
    end

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

    local box
    if pcall(function() box = f.ScrollBox end) and box then
        E.SweepRows(box, "TokenFrame.ScrollBox", tokenHeaderSweep, tokenEntrySweep)
    end
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
    for i = 1, 3 do
        local key = "CharacterFrameTab" .. i
        local tab = _G[key]
        if tab then
            Skin.Tab(tab, key, "panel")
        else
            E.Missing(key)
        end
    end

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
