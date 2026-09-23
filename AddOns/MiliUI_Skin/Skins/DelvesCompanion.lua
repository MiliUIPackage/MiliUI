------------------------------------------------------------
-- 配方：探究夥伴（`DelvesCompanionConfigurationFrame` ＋ `DelvesCompanionAbilityListFrame`，
--       隨需載入 `Blizzard_DelvesCompanionConfiguration`）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_DelvesCompanionConfiguration/Blizzard_DelvesCompanionConfiguration.xml
--     :199  `DelvesCompanionConfigurationFrame` ← `InsetFrameTemplate`（toplevel，385x495）：
--           視窗自己的 region：`Background`（`delves-companion-background`）＋ Inset 的 `Bg`；
--           `NineSlice`；子框 `Border`（**DialogBorderTemplate**，錨在視窗外 -8/+9）、
--           `CloseButton`（UIPanelCloseButton，錨在 Border 的右上）、`CompanionPortraitFrame`、
--           `CompanionExperienceRingFrame`、`CompanionLevelFrame`、`CompanionInfoFrame`、
--           `CompanionSlots`（**VerticalLayoutFrame**，四顆 `CompanionConfigSlotTemplate` ＋ 各自的
--           `OptionsList` 彈出清單）、`CompanionConfigShowAbilitiesButton`（UIPanelButtonTemplate，
--           文字是按鈕上一條**無名**的 GameFontNormalSmall2 FontString，:366）
--   Blizzard_DelvesCompanionConfiguration.lua:83-95  `OnLoad` → `RegisterUIPanel`（area left）
--   同檔 :745-753  「瀏覽技能」只 `ShowUIPanel`／`HideUIPanel` 能力清單視窗
--   Blizzard_DelvesCompanionConfiguration/Blizzard_DelvesCompanionAbilityList.xml
--     :47   `DelvesCompanionAbilityListFrame` ← `PortraitFrameTemplate, TalentFrameBaseTemplate`：
--           視窗自己的 region：`CompanionAbilityListBackground`（`character-panel-background`）、
--           Bg／TopTileStreaks、`BackgroundFlash`（TalentFrameBase，alpha 0 的閃光）；
--           `DelvesCompanionRoleDropdown`（WowStyle1DropdownTemplate）、
--           `DelvesCompanionAbilityListPagingControls`（PagingControlsHorizontalTemplate ←
--           HorizontalLayoutFrame：`PrevPageButton`／`NextPageButton`／`PageText`，
--           Blizzard_PagedContent/Blizzard_PagingControls.xml:54）
--   Blizzard_DelvesCompanionAbilityList.lua
--     :46-60  `OnLoad` → `RegisterUIPanel`、`SetTitle`（純文字）
--     :417-454 翻頁鈕的 OnClick 是暴雪 `SetScript` 的；`Refresh` 對兩顆 `SetEnabled`、整條列 Show／Hide
--     :364-415 角色下拉：選項的 `SetSelected` → `SetSelection` ＋ `RollbackConfig`（**trait 設定**）
--
------------------------------------------------------------
-- ## 範圍：只做外框、下拉、按鈕、翻頁 —— trait 相關的格子一律不碰
--
-- 隨從的角色／飾品選擇就是 trait 設定：`CompanionConfigSlotTemplate` 點下去開 `OptionsList`，
-- 清單列（`CompanionConfigListButtonTemplate`）點下去 `TrySelectTrait` ＝ 提交設定；
-- 能力清單的每一格是 `TalentFrameBase` 的天賦鈕。這些**一顆都不碰**（同天賦視窗的 C 級內容）。
--
------------------------------------------------------------
-- ## 做法對照成熟同類實作（第十三輪：範圍照抄、外觀用我們的）
--
-- 它做的、我們照做：
-- * 設定視窗：殼（**視窗自己的 region 全部淡掉，連 `Background` 場景圖一起**）、NineSlice、
--   `Bg`、`Border` 子框 alpha 0、關閉鈕、「瀏覽技能」鈕換長相＋字改白。
-- * 能力清單：殼（`CompanionAbilityListBackground` 一起淡掉）、頭像拿掉、NineSlice、標題白、
--   角色下拉、兩顆翻頁鈕換成我們的 ‹ ›。
-- * 它的四個 `OptionsList` 彈出清單那一段（面板＋捲軸＋列）實際上**不會生效**：它找的是
--   `f.CompanionCombatRoleSlot`，但那幾顆格子住在 `f.CompanionSlots` 底下 ⇒ 永遠 nil。
--   連同任務要求「選項格不碰」，我們也不做。
--
-- **照抄不了的地方（契約）：**
-- * 它把頭像框與經驗環 `SetFrameLevel` 墊高（讓它們蓋過邊框）、把關閉鈕重錨到視窗右上角 ——
--   不重排、不改層級。改用「邊框建成視窗**自己的 region**（OVERLAY 層）」：region 永遠在所有
--   子框之下 ⇒ 頭像與經驗環本來就蓋在邊框上面，不必墊層級（見 `Apply` 裡的註解）。
--   關閉鈕維持錨在（已中和的）`Border` 右上，會比視窗角落往外 8／9 —— 那是暴雪的位置。
-- * 能力格的圖示改方形：它 `hooksecurefunc(al, "UpdatePaginatedButtonDisplay")`（勾實例＝寫欄位）；
--   mixin 表在建框時已拷貝走、勾不到 ⇒ 不做（而且那是天賦鈕，任務要求不碰）。
-- * 它每次顯示都 `HookScript("OnShow")` 重掃 —— 我們全是 alpha 中和，套一次就夠，**零 hook**。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `DelvesCompanionConfigurationFrame` 自己的 region（`Background`、`Bg`） | `SetAlpha(0)`（`GetRegions`） |
-- | 同上的 `NineSlice`、`Border`（兩個純美術子框） | 框 `SetAlpha(0)` |
-- | 同上本身 | `Engine.RegionBackdrop`：`fill` 底（BACKGROUND）＋ 1px 黑邊（**OVERLAY 7**，見 `Apply`） |
-- | 同上的 `CloseButton` | 同 `Skin.CloseButton` |
-- | **零腳本**：`CompanionConfigShowAbilitiesButton`（secondary） | Left／Right／Middle `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight 的 `SetColorTexture`；按鈕上那條無名 FontString `SetTextColor`（`Engine.RecolorRegions`）。**零 HookScript** |
-- | `DelvesCompanionAbilityListFrame` 的 NineSlice／Bg／TopTileStreaks／PortraitContainer | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | 同上自己的 region（`CompanionAbilityListBackground` 等） | `SetAlpha(0)`（`GetRegions`） |
-- | 同上本身 | `Engine.RegionBackdrop`（底＋邊＋標題帶） |
-- | 同上的 `TitleContainer.TitleText` | `SetTextColor` |
-- | 同上的 `CloseButton` | 同 `Skin.CloseButton` |
-- | `DelvesCompanionRoleDropdown` | `Background`／`Arrow` `SetAlpha(0)` ＋ ⌄ 圖記（`Skin.Dropdown`） |
-- | 兩顆翻頁鈕 | 三張狀態圖 `SetAlpha(0)` ＋ ‹ › 圖記（`Skin.IconButton`，overlay 掛在按鈕自己身上 ⇒ 整條翻頁列被藏起來時一起消失） |
--
-- **hook：0 支 `hooksecurefunc`、0 支 `HookScript("OnShow")`。** 只有原語內建的
-- `HookScript("OnEnter"/"OnLeave")`（關閉鈕、下拉）與翻頁鈕的 `OnEnable`／`OnDisable`（圖記明暗），
-- 內容只換我們自己 overlay 的顏色。**讀取：只有 parentKey 與 `GetRegions`。寫入暴雪欄位：無。**
--
-- ## 刻意不碰的東西
-- * 四顆設定格（`CompanionConfigSlotTemplate`）、它們的 `OptionsList` 與清單列、`CompanionSlots` 這個 LayoutFrame。
-- * 頭像、經驗環、等級、`CompanionInfoFrame`（名字、描述、陰影、分隔線）、能力清單的每一格、`PageText`。
-- * 角色下拉的彈出選單（C 級）。
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

local TRANSPARENT = { 0, 0, 0, 0 }

-- TODO(升格): 同 `Skins/PlayerSpells.lua` 的 local `ScriptlessButton`
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)
    return ov
end

------------------------------------------------------------
-- 隨從設定視窗
------------------------------------------------------------
local function ApplyConfig()
    local f = _G.DelvesCompanionConfigurationFrame
    if not f then
        E.Missing("DelvesCompanionConfigurationFrame")
        return
    end
    local key = "DelvesCompanionConfigurationFrame"
    if not E.Usable(f, key) then return end

    E.NeutralizeKeys(f, { "NineSlice", "Border" }, key)
    E.NeutralizeRegions(f, key)          -- `Background` 場景圖 ＋ Inset 的 `Bg`

    -- 底：一般的 `fill`（BACKGROUND −8）。
    local bg = E.RegionBackdrop(f, { key = key, noBorder = true })
    E.Paint(bg, T.fill)

    -- 邊：另建一組**只有邊**的 region，畫在 OVERLAY 7。
    -- 為什麼：頭像框與經驗環往上突出視窗頂邊（XML :228 `TOP y=45`），它們是子框 ⇒
    -- 永遠畫在父框所有 region 之上 ⇒ 邊線自然從它們後面穿過去，不用 `SetFrameLevel`
    -- （成熟同類實作是把那兩個子框墊高）。放在 OVERLAY 是為了壓過視窗自己其餘的 region。
    local edge = E.RegionBackdrop(f, {
        key = key .. ".edge",
        slot = "edge",
        layer = "OVERLAY", sublevel = 6,
        edgeLayer = "OVERLAY", edgeSublevel = 7,
    })
    E.Paint(edge, TRANSPARENT, T.border)

    local close = Required(f, "CloseButton", key .. ".CloseButton")
    if close then Skin.CloseButton(close, key .. ".CloseButton") end

    -- 「瀏覽技能」：開能力清單視窗，是導覽不是動作 ⇒ secondary（STYLE.md ④ 判準 5）。
    -- 零腳本：它貼著 trait 設定的視窗，按鈕一律不掛腳本。
    local ab = Required(f, "CompanionConfigShowAbilitiesButton", key .. ".CompanionConfigShowAbilitiesButton")
    if ab then
        local bkey = key .. ".CompanionConfigShowAbilitiesButton"
        ScriptlessButton(ab, bkey, "secondary")
        -- 文字不是按鈕自己的 ButtonText，而是按鈕上一條無名的 FontString（XML :366，暗金、
        -- Lua 從不重設）⇒ 一次 `SetTextColor` 永久有效。按鈕自己的 ButtonText 是空字串，一起被塗也無妨。
        E.RecolorRegions(ab, T.text, bkey)
    end
end

------------------------------------------------------------
-- 能力清單視窗
------------------------------------------------------------
local function ApplyAbilityList()
    local al = _G.DelvesCompanionAbilityListFrame
    if not al then
        E.Missing("DelvesCompanionAbilityListFrame")
        return
    end
    local key = "DelvesCompanionAbilityListFrame"
    if not E.Usable(al, key) then return end

    Skin.PortraitChrome(al, key)
    E.NeutralizeRegions(al, key)          -- `CompanionAbilityListBackground` 等視窗自己的 region
    Skin.Panel(al, key)

    local close = Required(al, "CloseButton", key .. ".CloseButton")
    if close then Skin.CloseButton(close, key .. ".CloseButton") end

    local dd = Required(al, "DelvesCompanionRoleDropdown", key .. ".DelvesCompanionRoleDropdown")
    if dd then Skin.Dropdown(dd, key .. ".DelvesCompanionRoleDropdown", "style1") end

    -- 翻頁鈕（同法術書的 `PagingControls`）。翻頁列是 HorizontalLayoutFrame ⇒ overlay 由
    -- `SafeParent` 掛在按鈕自己身上，不掛在列上；列被 `Hide()` 時圖記跟著消失。
    local pc = Required(al, "DelvesCompanionAbilityListPagingControls", key .. ".PagingControls")
    if pc then
        for i, k in ipairs({ "PrevPageButton", "NextPageButton" }) do
            local pkey = key .. ".PagingControls." .. k
            local btn = Required(pc, k, pkey)
            if btn then
                Skin.IconButton(btn, pkey, {
                    inset = 4,
                    glyph = (i == 1) and "chevronLeft" or "chevronRight",
                    glyphColor = T.textDim,
                    trackEnabled = true,
                })
            end
        end
    end
end

local function Apply()
    ApplyConfig()
    ApplyAbilityList()
end

E.Register{
    key   = "delvescompanion",
    addon = "Blizzard_DelvesCompanionConfiguration",
    title = L["Delve Companion"],
    apply = Apply,
}
