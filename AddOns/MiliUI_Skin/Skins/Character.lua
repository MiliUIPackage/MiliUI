------------------------------------------------------------
-- 配方：角色面板（CharacterFrame）—— 這份是 taint 壓力測試
--
-- 暴雪原始碼出處（12.1.0.69875）：
--   Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml / .lua
--   Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml / .lua
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
-- | CharacterStatsPane.ClassBackground | SetAlpha(0) |
-- | PaperDollSidebarTabs.DecorLeft / .DecorRight | SetAlpha(0) |
-- | PaperDollSidebarTab1..3 的 TabBg / Hider | SetAlpha(0) |
-- | PaperDollSidebarTab1..3 的 Highlight | SetColorTexture |
-- | 以上各框 | CreateFrame 掛自己的 overlay |
--
-- hook（全部是後置勾，不換函式）：
--   * `hooksecurefunc(CharacterFrame, "SetTitleColor", …)` —— `UpdateDisplay` 每次
--     都會重設標題色（CharacterFrame.lua:119），不掛勾的話白字撐不過一次切分頁。
--   * Engine 的 `PanelTemplates_SelectTab / DeselectTab / SetDisabledTabState`
--     三個全域後置勾（裝在 Core/Engine.lua，全套組共用一組）。
--   * 分頁的 `HookScript("OnEnter"/"OnLeave")`（滑過態；模板自己的 OnEnter 保留）。
--
-- 寫入暴雪欄位：無。
--
------------------------------------------------------------
-- ## 刻意不碰的東西（計畫明列的額外限制）
--
-- * **裝備格按鈕**（`PaperDollItemSlotButton` 系）—— 點擊會走保護函式。
-- * **模型場景**（`CharacterModelScene`）以及它的旋轉／縮放控制。
-- * **任何 IsProtected() 為真的框** —— Engine.Overlay 會自己擋掉並記進
--   `/mskin debug` 的「因保護框跳過」清單。
-- * 聲望／貨幣兩個分頁的**內容**（那是清單，不是 chrome）。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
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
            -- ⚠ 暴雪的 `PaperDollFrame_UpdateSidebarTabs`（PaperDollFrame.lua:2673）
            --   會對**選中的**那顆 `Highlight:Hide()`，所以滑過效果自動只出現在
            --   未選中的分頁上 —— 這是引擎驅動的、不必我們判斷。
            local hl
            if pcall(function() hl = tab.Highlight end) and hl
                and type(hl.SetColorTexture) == "function" then
                pcall(hl.SetColorTexture, hl, 1, 1, 1, T.highlightAlpha)
            else
                E.Missing(key .. ".Highlight")
            end

            local ov = E.Overlay(tab, { key = key })
            E.Paint(ov, T.fill, T.border)
        else
            E.Missing(key)
        end
    end
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

    -- 右側屬性欄的職業底圖（UI-Character-Info-<CLASS>-BG）
    local pane = _G.CharacterStatsPane
    if pane then
        E.NeutralizeKeys(pane, { "ClassBackground" }, "CharacterStatsPane")
    else
        E.Missing("CharacterStatsPane")
    end

    SkinSidebarTabs()
end

E.Register{
    key   = "character",
    addon = nil,                       -- Blizzard_UIPanels_Game 是 LoadFirst，永遠在
    title = L["Character Info"],
    apply = Apply,
}
