------------------------------------------------------------
-- 配方：設定面板（`SettingsPanel`，ESC →「選項」）
--
-- 範圍照成熟同類實作的同一段：**只換框** —— 外框、關閉鈕、搜尋框、底部按鈕、上方兩顆分頁、
-- 左側分類欄、右側清單的框與捲軸。**每一個設定項（勾選框、滑桿、下拉、按鍵綁定鈕）一律不碰**：
-- 那一面又大又貼著 taint（值寫進 CVar／按鍵綁定、`SaveBindings` 在 `OnHide` 裡跑）。
-- 套組裡很多插件把自己的設定頁註冊成 Canvas 面板 —— 那些面板的內容也一律不碰。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_Settings_Shared/Blizzard_Settings_Shared.toc   非 LoD（遊戲與登入畫面都載入）
--   Blizzard_Settings_Shared/Blizzard_SettingsPanel.xml:4-113
--     `SettingsPanel` ← `SettingsFrameTemplate`（toplevel、HIGH strata）；
--     :11 一張**無名** OVERLAY 貼圖 `Options_InnerFrame`（兩欄外圍的雕花內框）；
--     :26,36 `GameTab`／`AddOnsTab`（`MinimalTabTemplate`）；
--     :46 `CloseButton`（**底部的文字鈕「關閉」**，不是 ×）、:52 `ApplyButton`（`UIPanelButtonTemplate`）；
--     :58 `CategoryList`（`SettingsCategoryListTemplate`）；:65 `Container`（`SettingsCanvas` ＋ `SettingsList`）；
--     :76 `SearchBox`（`SearchBoxTemplate`）；:82 `InputBlocker`（不碰）
--   Blizzard_Settings_Shared/Mainline/Blizzard_SettingsPanelTemplates.xml:4
--     `SettingsFrameTemplate`：`Bg`（`FlatPanelBackgroundTemplate` 子框）／`NineSlice`（**裡面還有標題
--     `Text` 這個 FontString** ⇒ 不能框級 alpha，只能掃它的貼圖）／`ClosePanelButton`（右上 ×）
--   Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua:49-104 `OnLoad`：`NineSlice.Text:SetText`、
--     `CloseButton`／`ApplyButton`／`DefaultsButton` 的 `SetScript("OnClick")`（**只 SetText，不設字色**）
--   同檔 :153-190 `OnShow`、:204-221 `OnHide`（`SaveBindings`）、:224-268 `Commit`／`Close`／`ExitWithCommit`
--     ⇒ 關閉（× 與底部「關閉」）、套用都走 commit：寫 CVar、存按鍵綁定
--   同檔 :545-548 `SetApplyButtonEnabled` → `ApplyButton:SetEnabled`＋`SetShown`
--   Blizzard_SharedXML/Shared/Tabs/MinimalTab.xml:3、MinimalTab.lua:23-56
--     `Left`／`Right`／`Middle` 每次狀態改變都 `SetAtlas`（alpha 不動 ⇒ alpha 中和撐得住）；
--     文字是 FontString `Text`，選中／滑過 `SetFontObject("GameFontHighlightSmall")`（白）、閒置
--     `GameFontNormalSmall`（金）—— **直接對 FontString 換字型物件，不是按鈕的 NormalFont**
--   Blizzard_Settings_Shared/Blizzard_CategoryList.xml:9 `SettingsCategoryListTemplate`（`ScrollBox`＋`ScrollBar`
--     ＝MinimalScrollBar）；:30 `SettingsCategoryListHeaderTemplate`（`Background` ＋ 白字 `Label`）；
--     Blizzard_CategoryList.lua:30-34 `SettingsCategoryListHeaderMixin:Init` → `Background:SetAtlas(...)`
--   Blizzard_Settings_Shared/Blizzard_SettingsList.xml:5 `SettingsListTemplate`：`Header`（`Title` 白字、
--     一張**無名** `Options_HorizontalDivider`、`DefaultsButton`（UIPanelButtonTemplate）、`TutorialButton`）／
--     `ScrollBox`／`ScrollBar`（MinimalScrollBar）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:153 `UIPanelCloseButtonDefaultAnchors`；
--     SharedUIPanelTemplates.lua:144 `UIPanelCloseButton_OnClick` → `parent.onCloseCallback` ＝ `Close()`
--
------------------------------------------------------------
-- ## 做了什麼
--
-- * 外框：`Bg` 子框、`NineSlice` 的貼圖、`Options_InnerFrame` 中和；面板底 ＋ 標題帶 ＋ 標題白字。
-- * 右上 ×：自己畫的 ×，**零腳本**（它按下去就是 `Close()` → commit）。
-- * 底部「套用」（primary）、「關閉」（secondary）、清單頂端「預設值」（secondary）：**零腳本**
--   （`Engine.ScriptlessButton`）—— 三顆都會寫 CVar／按鍵綁定（預設值是先開確認彈窗，但同一條路）。
-- * 上方「遊戲／插件」兩顆分頁：原本的三片美術中和、改畫平面分頁；滑過自己畫（職業色邊）。
-- * 左側分類欄、右側清單：各一塊 `fillInset` 內嵌底；分類欄的**群組標題列**底圖中和（池化列，
--   勾 `SettingsCategoryListHeaderMixin:Init` 的 mixin 表）；清單頂端的分隔線換成髮絲線；兩條捲軸。
-- * 搜尋框。
--
-- ## 刻意不碰
--
-- * 每一個設定項的控件、分類列本身的選中／滑過底（`Options_List_Active`／`_Hover`，那是暴雪的語彙，
--   成熟同類實作也留著）、分類列的展開鈕、`NewFeature` 標籤、`TutorialButton`、`InputBlocker`、`OutputText`。
-- * 插件註冊進來的 Canvas 面板內容（`Container.SettingsCanvas` 底下的一切）。
-- * 分頁的**選中態**：成熟同類實作是 `hooksecurefunc(SettingsPanel, "SetCurrentCategory")`（在暴雪框實例上
--   寫欄位）＋ 讀 `tab.isSelected`／`categorySet`（暴雪欄位）＋ 在分頁每一張貼圖上勾 `SetAtlas`／`Show`
--   —— 全部在禁止清單上。`SelectableButtonMixin:SetSelected` 是建立時就拷貝走的 mixin 方法、
--   沒有全域函式出口 ⇒ 我們**畫不出選中態**，選中與否只剩暴雪自己的字色（選中白、閒置金）。
--   （見回報的「照抄不了的地方」。）
-- * 分頁文字：暴雪直接對 FontString `SetFontObject`（不是按鈕的 NormalFont），`Engine.ButtonFonts`
--   接不到、每次滑過都會被蓋回 ⇒ 不碰。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事
--
-- | 對象 | 動作 |
-- |---|---|
-- | `SettingsPanel.Bg`（子框） | `SetAlpha(0)` |
-- | `SettingsPanel.NineSlice` 的貼圖、`SettingsPanel` 自己的無名 `Options_InnerFrame` | `SetAlpha(0)`（`GetRegions()` 走訪，FontString 不動） |
-- | `SettingsPanel` | `Engine.RegionBackdrop`（面板底＋邊＋標題帶） |
-- | `NineSlice.Text`（標題） | `SetTextColor` |
-- | `ClosePanelButton`（×） | Normal／Disabled `SetAlpha(0)`；Highlight／Pushed `SetColorTexture`；× 圖記 overlay。**零 HookScript** |
-- | **零腳本按鈕**：`ApplyButton`（primary）、`CloseButton`、`Container.SettingsList.Header.DefaultsButton`（secondary） | Left/Right/Middle `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled `SetColorTexture`（primary 另 `SetDisabledTexture`，`Engine.ScriptlessButton`） |
-- | `GameTab`／`AddOnsTab` | `Left`／`Right`／`Middle` `SetAlpha(0)`；overlay |
-- | `SearchBox` | `Skin.EditBox` |
-- | `CategoryList`、`Container` | `Engine.RegionBackdrop`（`fillInset` 內嵌底） |
-- | 分類欄群組標題列（`SettingsCategoryListHeaderTemplate`）的 `Background` | `SetAlpha(0)` |
-- | `SettingsList.Header` 的無名分隔線 | `SetAlpha(0)`；髮絲線 `Engine.RegionBackdrop` |
-- | `CategoryList.ScrollBar`、`SettingsList.ScrollBar` | `Skin.ScrollBar` |
--
-- ### 讀了什麼
--
-- 只有結構：parentKey、`GetRegions()`（找無名貼圖）、`ScrollBox:ForEachFrame`（補掃已建立的標題列）。
-- **不讀** 分類、設定值、`categorySet`、`isSelected`、`tabsGroup`、elementData。
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc(SettingsCategoryListHeaderMixin, "Init", …)` | mixin 表後置勾（`Engine.HookRows`） | 第一次見到那一列才中和 `Background`（alpha 0 撐得過之後的 `SetAtlas`，不需要 reapply） |
-- | `Engine.TrackButtonHover` 的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛 | **只對**兩顆分頁、搜尋框的清除鈕、兩條捲軸；內容只換我們自己 overlay 的顏色 |
--
-- **`hooksecurefunc` 在 `SettingsPanel` 實例或任何 `SettingsPanelMixin`／`SettingsListMixin` 上：0 支。**
-- **`HookScript("OnShow"/"OnHide")`：0 支。** × 與三顆底部按鈕上的 HookScript：**0 支**。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local function Sub(owner, key, label)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then
        return child
    end
    E.Missing(label)
    return nil
end

local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

------------------------------------------------------------
-- 零腳本按鈕（同 `Skins/PlayerSpells.lua`）
-- TODO(升格): 收成 `Skin.ScriptlessButton`。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "secondary", key)   -- **不掛腳本**
    return ov
end

------------------------------------------------------------
-- 零腳本的 ×：`Skin.CloseButton` 減掉 `TrackButtonHover`。
-- 這顆按下去是 `Close()` → commit（寫 CVar、`SaveBindings`）⇒ 跟底部按鈕同一條判準。
-- 滑過交給引擎（Highlight 白 8%）、按下黑 18%（模板三張都是 XML 寫死的 atlas，換色撐得住）。
-- TODO(升格): `Skin.CloseButton` 可以加一個 `opts.noHover`。
------------------------------------------------------------
local function ScriptlessClose(btn, key)
    if not E.Usable(btn, key) then return end
    local ov = E.Overlay(btn, {
        key = key,
        inset = 2,
        glyph = { kind = "cross", size = 9, thickness = 1, color = T.text },
    })
    if not ov then return end
    for _, getter in ipairs({ "GetNormalTexture", "GetDisabledTexture" }) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    E.ButtonStates(btn, key, true)
    E.Paint(ov, T.fill, T.border)
end

------------------------------------------------------------
-- 上方分頁（`MinimalTabTemplate`）
--
-- 三片美術每次狀態改變都 `SetAtlas`（MinimalTab.lua:23-28），alpha 撐得住。
-- 兩顆分頁與下方內容之間隔著 12（分頁底 y=-64、分類欄頂 y=-76）⇒ 不是「相連」的分頁，四邊都畫。
-- 選中態畫不出來（檔頭）；滑過自己畫（這兩顆只是切換分類組，不在 commit 路徑上）。
------------------------------------------------------------
local function SkinMinimalTab(tab, key)
    if not E.Usable(tab, key) then return end
    E.NeutralizeKeys(tab, { "Left", "Right", "Middle" }, key)
    local ov = E.Overlay(tab, { key = key })
    E.Paint(ov, T.fill, T.border)
    E.TrackButtonHover(tab, ov, T.fill)
end

------------------------------------------------------------
-- 分類欄的群組標題列（池化）
------------------------------------------------------------
local headerSweeper

local function InstallHooks()
    local mixin = _G.SettingsCategoryListHeaderMixin
    headerSweeper = E.HookRows{
        key    = "settings.CategoryHeader",
        mixin  = mixin,
        method = "Init",
        match  = function(row)
            return type(row) == "table" and Optional(row, "Background") ~= nil
                and Optional(row, "Label") ~= nil and Optional(row, "Toggle") == nil
        end,
        apply  = function(row)
            E.NeutralizeKeys(row, { "Background" }, "settings.CategoryHeader")
        end,
    }
end

------------------------------------------------------------
-- 外框
------------------------------------------------------------
local LIST_HEADER_HEIGHT = 50      -- Blizzard_SettingsList.xml:8 `Header` 的 <Size y="50"/>

local function Apply()
    local f = _G.SettingsPanel
    if not f then
        E.Missing("SettingsPanel")
        return
    end
    local key = "SettingsPanel"
    if not E.Usable(f, key) then return end

    -- 外框美術：`Bg` 是子框 ⇒ 框級 alpha；`NineSlice` 裡有標題字 ⇒ 只掃它的貼圖；
    -- 本體自己只有一張無名的 `Options_InnerFrame`（FontString `OutputText` 不會被掃到）。
    E.NeutralizeKeys(f, { "Bg" }, key)
    E.NeutralizeRegions(f, key)
    local nine = Sub(f, "NineSlice", key .. ".NineSlice")
    if nine then
        E.NeutralizeRegions(nine, key .. ".NineSlice")
        local title = Optional(nine, "Text")
        if title then E.TextColor(title, T.text, key .. ".NineSlice.Text") else E.Missing(key .. ".NineSlice.Text") end
    end
    Skin.Panel(f, key)
    Skin.TitleBar(f, key)

    local x = Sub(f, "ClosePanelButton", key .. ".ClosePanelButton")
    if x then ScriptlessClose(x, key .. ".ClosePanelButton") end

    -- 底部兩顆：套用＝確認（primary），關閉＝secondary（判準第 1 條）
    local apply = Sub(f, "ApplyButton", key .. ".ApplyButton")
    if apply then ScriptlessButton(apply, key .. ".ApplyButton", "primary") end
    local close = Sub(f, "CloseButton", key .. ".CloseButton")
    if close then ScriptlessButton(close, key .. ".CloseButton", "secondary") end

    for _, k in ipairs({ "GameTab", "AddOnsTab" }) do
        local tab = Sub(f, k, key .. "." .. k)
        if tab then SkinMinimalTab(tab, key .. "." .. k) end
    end

    local sb = Sub(f, "SearchBox", key .. ".SearchBox")
    if sb then Skin.EditBox(sb, key .. ".SearchBox") end

    -- 左側分類欄
    local cl = Sub(f, "CategoryList", key .. ".CategoryList")
    if cl and E.Usable(cl, key .. ".CategoryList") then
        local ov = E.RegionBackdrop(cl, { key = key .. ".CategoryList" })
        E.Paint(ov, T.fillInset, T.border)
        local bar = Optional(cl, "ScrollBar")
        if bar then Skin.ScrollBar(bar, key .. ".CategoryList.ScrollBar") end
        local box = Optional(cl, "ScrollBox")
        if box and headerSweeper then E.SweepRows(box, key .. ".CategoryList.ScrollBox", headerSweeper) end
    end

    -- 右側清單（Canvas 面板共用同一個 Container；內容不碰）
    local ct = Sub(f, "Container", key .. ".Container")
    if ct and E.Usable(ct, key .. ".Container") then
        local ov = E.RegionBackdrop(ct, { key = key .. ".Container" })
        E.Paint(ov, T.fillInset, T.border)

        local sl = Optional(ct, "SettingsList")
        if sl then
            local bar = Optional(sl, "ScrollBar")
            if bar then Skin.ScrollBar(bar, key .. ".SettingsList.ScrollBar") end

            local hdr = Optional(sl, "Header")
            if hdr and E.Usable(hdr, key .. ".SettingsList.Header") then
                -- 無名的 `Options_HorizontalDivider`（錨 TOP y=-50）→ 換成 1px 髮絲線，同一個高度
                E.NeutralizeRegions(hdr, key .. ".SettingsList.Header")
                local rule = E.RegionBackdrop(hdr, {
                    key = key .. ".SettingsList.Header.rule",
                    slot = "rule",
                    noBorder = true,
                    points = {
                        { "TOPLEFT", "TOPLEFT", 0, -LIST_HEADER_HEIGHT },
                        { "TOPRIGHT", "TOPRIGHT", 0, -LIST_HEADER_HEIGHT },
                    },
                    height = 1,
                })
                E.Paint(rule, T.fillHover)

                local def = Optional(hdr, "DefaultsButton")
                -- 預設值：會把整頁設定改回預設（先開確認彈窗）⇒ 零腳本；它不是這一區的主動作 ⇒ secondary
                if def then ScriptlessButton(def, key .. ".SettingsList.Header.DefaultsButton", "secondary") end
            end
        else
            E.Missing(key .. ".Container.SettingsList")
        end
    end
end

E.Register{
    key   = "settings",
    addon = nil,                          -- Blizzard_Settings_Shared 非 LoD，而且是一大票暴雪插件的 Dep，登入前一定在
    title = L["Options"],
    hooks = InstallHooks,
    apply = Apply,
}
