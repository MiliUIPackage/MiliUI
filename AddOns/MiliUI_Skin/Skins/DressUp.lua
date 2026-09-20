------------------------------------------------------------
-- 配方：試衣間（DressUpFrame ＋ SideDressUpFrame）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_UIPanels_Game/Mainline/DressUpFrames.xml:3    DressUpCustomSetSlotFrameTemplate
--     （`Icon` / `IconBorder` / `Name` / `HiddenIcon`；`slotPool` 借還，.lua:475）
--   同檔 :44   SideDressUpFrame（**flattenRenderLayers="true"**）
--     :51  `$parentTop`（AuctionHouseDressUpFrame-Top，**只有全域名字**）
--     :57  一張**無名無 parentKey** 的 AuctionHouseDressUpFrame-Bottom
--     :65,72 `BGTopLeft` / `BGBottomLeft`（模型背後那張底圖，`.lua:306-313` 每次
--            `SetTexture(texture..1/3)`）
--     :100 `ResetButton`（UIPanelButtonTemplate）
--     :110 `$parentCloseButton`（UIPanelCloseButton）＋ 它自己 BACKGROUND 層裡一張
--            **無名**的 AuctionHouseDressUpFrame-Corner
--   同檔 :136  TransmogAndMountDressupFrame（`ShowMountCheckButton`，UICheckButtonTemplate）
--   同檔 :174  DressUpFrameTransmogSetTemplate（`BlackBackground` / `Border`
--            atlas dressingroom-sideframe / `SetName` / `ScrollBox` / `ScrollBar`）
--   同檔 :228  DressUpFrameTransmogSetButtonTemplate（**mixin 不在這個檔裡**，見下面第 3 點）
--   同檔 :272  DressUpFrame（**ButtonFrameTemplateMinimizable**，450x545）
--     :285  `CustomSetDropdown`（DropdownButton，WardrobeCustomSetDropdownTemplate）
--     :296  `MaximizeMinimizeFrame`（**MaximizeMinimizeButtonFrameTemplate**）
--     :304  DressUpFrameCancelButton（UIPanelButtonTemplate）
--     :313  `ModelScene` ＋ `ControlFrame`
--     :335  `ToggleCustomSetDetailsButton`（Normal/Pushed 是 atlas
--            dressingroom-button-appearancelist-up/down）
--     :361  `SetSelectionPanel`（← DressUpFrameTransmogSetTemplate）
--     :367  `CustomSetDetailsPanel`（`BlackBackground` / `ClassBackground` ＋
--            一張**無名**的 dressingroom-sideframe）
--     :404  `ResetButton`（名字是 DressUpFrameResetButton）
--     :414  `LinkButton`（DropdownButton，但 inherits **UIPanelButtonTemplate**）
--     :432  `ModelBackground`（atlas dressingroom-background-<職業>，鋪滿 ModelScene）
--   Blizzard_UIPanels_Game/Mainline/DressUpFrames.lua:319  ModelBackground:SetAtlas(...)
--   同檔 :475-482  DressUpCustomSetDetailsPanelMixin:OnLoad —— `ClassBackground` 的
--     `SetAtlas` / `SetDesaturation` / **`SetAlpha`** 全部只在 **OnLoad 跑一次**
--     ⇒ 我們的 alpha 中和撐得住
--   同檔 :896  DressUpCustomSetDetailsSlotMixin:SetDetails（`IconBorder:SetAtlas(
--     "dressingroom-itemborder-"..borderType)` —— 品質／未收藏／錯誤都烤在 atlas 名字裡）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:660,684,704
--     ButtonFrameBaseTemplate / ButtonFrameTemplate（`Inset`）/ ButtonFrameTemplateMinimizable
--   同檔 :1032  MaximizeMinimizeButtonFrameTemplate
--     （`MaximizeButton` / `MinimizeButton`，兩顆都是 RedButton-Expand / -Condense 系，
--      跟 UIPanelCloseButton 的 RedButton-Exit 同一族）
--
------------------------------------------------------------
-- ## 查證後跟計畫假設不一樣的三件事
--
-- 1. **最大化／最小化是兩顆獨立的按鈕**（`MaximizeButton` / `MinimizeButton`，
--    同一個 24x24 的矩形上疊著、一次只顯示一顆），素材是 `RedButton-Expand`／
--    `RedButton-Condense` —— 跟關閉鈕的 `RedButton-Exit` 是同一族「紅底按鈕連符號」
--    的合成圖。但**不能照關閉鈕的辦法處理**：關閉鈕的 × 我們畫得出來（兩條線），
--    「展開／收合」的箭頭畫不出來，而 `Engine.Overlay` 的 `glyph` 只有
--    `kind = "cross"` 與「一張貼圖」兩種。
--    ⇒ 照 `Skin.IconButton` 的既有作法：圖不中和、先去飽和再染 `textDim`
--    （紅色烤在素材裡，乘法染不出中性灰），底與邊由 overlay 畫，滑過交給引擎。
--    TODO(升格): `Engine.Overlay` 的 `glyph` 需要第三種 kind（v 形），有了之後這兩顆
--    就能跟關閉鈕一樣變成「平面方塊 ＋ 白色圖記」。
--
-- 2. **`ClassBackground` 的 alpha 是 OnLoad 設一次的**（.lua:481，依職業 0.21~0.65），
--    不是每次 Refresh 都重設 ⇒ 中和放 apply 就夠，不必 reapply。
--
-- 3. **套裝選擇面板的列碰不到。** `DressUpFrameTransmogSetButtonMixin` 與
--    `DressUpFrameTransmogSetMixin` 都**不在** `DressUpFrames.lua` 裡（整個檔沒有
--    一行定義它們），這一輪查不到可以掛的 Init ⇒ 那一片只做面板本身的底與邊 ＋
--    捲軸，列維持暴雪原樣（回報 ⑦）。
--    外觀明細面板（`CustomSetDetailsPanel`）的列**刻意不碰**：`IconBorder` 的
--    atlas 名字就是品質／未收藏／錯誤三種狀態（.lua:896-953），那是資訊；
--    而且那一排本來就沒有要中和的雕花，只有圖示與文字。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### DressUpFrame
--
-- | 物件 | 動作 |
-- |---|---|
-- | DressUpFrame 的 NineSlice / Bg / TopTileStreaks / PortraitContainer | SetAlpha(0) |
-- | DressUpFrame.TitleContainer.TitleText | SetTextColor |
-- | DressUpFrame.Inset 的 Bg 與 NineSlice | SetAlpha(0) |
-- | DressUpFrameCloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | 同上的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | MaximizeMinimizeFrame 的 Maximize/MinimizeButton 的 Normal/Pushed/Disabled | SetDesaturated ＋ SetVertexColor |
-- | 同兩顆的 Highlight 貼圖 | SetColorTexture |
-- | DressUpFrame.CustomSetDropdown 的 Background | SetAlpha(0)；Arrow | SetVertexColor |
-- | ToggleCustomSetDetailsButton 的 Normal/Pushed | SetDesaturated ＋ SetVertexColor |
-- | DressUpFrameResetButton / DressUpFrameCancelButton / LinkButton 的 Left/Right/Middle | SetAlpha(0) |
-- | 同三顆 | SetNormalFontObject(GameFontHighlight)；Highlight | SetColorTexture |
-- | CustomSetDetailsPanel 的 BlackBackground / ClassBackground / 無名 sideframe | SetAlpha(0)（GetRegions） |
-- | SetSelectionPanel 的 BlackBackground / Border | SetAlpha(0)（GetRegions） |
-- | SetSelectionPanel.ScrollBar 的 Track/Thumb 六張 | SetAlpha(0)；Back/Forward.Texture | SetVertexColor |
-- | TransmogAndMountDressupFrame.ShowMountCheckButton | 同勾選框 |
--
-- ### SideDressUpFrame
--
-- | 物件 | 動作 |
-- |---|---|
-- | SideDressUpFrameTop ＋ 一張無名的 -Bottom | SetAlpha(0)（GetRegions ＋ keep-set） |
-- | SideDressUpFrameCloseButton 的無名 -Corner | SetAlpha(0)（GetRegions ＋ keep-set） |
-- | 同上的 Normal/Disabled | SetAlpha(0)；Highlight/Pushed | SetColorTexture |
-- | SideDressUpFrame.ResetButton 的 Left/Right/Middle | SetAlpha(0) |
--
-- 以上各框：`CreateFrame` 掛自己的 overlay（錨在目標上、不吃滑鼠、零腳本）。
--
-- hook：**無**。這一份一個 hook 都沒有掛。
-- 寫入暴雪欄位：無。讀暴雪物件：無（一條讀取例外都沒用到）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`ModelScene` 本體、`ControlFrame`（旋轉／縮放控制）、`ModelBackground`
--   （atlas dressingroom-background-<職業>）與 `SideDressUpFrame` 的
--   `BGTopLeft`/`BGBottomLeft`** —— 那是模型場景與它的背景，內容底材規則的原意。
--   只中和模型區**外圍**的雕花框。
-- * **外觀明細面板的每一列** —— `Icon`/`IconBorder`/`Name` 全部是資訊
--   （品質色、未收藏、錯誤），而且沒有雕花可中和（見上面第 3 點）。
-- * **`HiddenIcon`（transmog-icon-hidden）** —— 「這一格是隱藏外觀」，是資訊。
-- * **套裝選擇面板的列** —— 查不到可以掛的 Init（見上面第 3 點）。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- `Engine.NeutralizeRegions` 的「要留下的」set
--
-- 這個視窗要中和的雕花（`$parentTop`、關閉鈕角落那張、明細面板上的
-- dressingroom-sideframe）有一半是**無名無 parentKey** 的，指名不到；
-- 反過來「要留下的」全部有 parentKey 或 getter。
--
-- ⚠ 狀態貼圖（Normal／Pushed／Disabled／Highlight）也是 `GetRegions()` 掃得到的
--   region ⇒ 要留就一定要放進 keep-set。
-- TODO(升格): 跟 Skins/Merchant.lua 的同名函式是同一支，兩份都在了就該升格。
------------------------------------------------------------
local function KeepSet(owner, keys, getters)
    local set = {}
    for _, k in ipairs(keys or {}) do
        local region
        if pcall(function() region = owner[k] end) and type(region) == "table" then
            set[region] = true
        end
    end
    for _, getter in ipairs(getters or {}) do
        if type(owner[getter]) == "function" then
            local ok, tex = pcall(owner[getter], owner)
            if ok and type(tex) == "table" then set[tex] = true end
        end
    end
    return set
end

local BUTTON_STATE_GETTERS = {
    "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture",
}

------------------------------------------------------------
-- 右側兩片面板（套裝選擇／外觀明細）
--
-- 兩片都是「一張黑底 ＋ 一張 dressingroom-sideframe 的雕花外框」，差別只在
-- 明細面板多一張職業底圖、而且它的雕花是**無名**的。
-- 兩片都走 `GetRegions()` 掃（只掃 Texture，`SetName` 那條 FontString 自動排除），
-- 然後補一層跟視窗同一套的底與邊。
------------------------------------------------------------
local function SkinSidePanel(panel, key)
    if not E.Usable(panel, key) then return end
    E.NeutralizeRegions(panel, key)
    local ov = E.Overlay(panel, { key = key })
    E.Paint(ov, T.fill, T.border)
end

------------------------------------------------------------
-- 最大化／最小化的兩顆小鈕
--
-- 理由見檔頭第 1 點：圖記畫不出來，所以圖不中和、去飽和＋染暗，底與邊自己畫。
------------------------------------------------------------
local function SkinMaxMinFrame(frame, key)
    if not E.Usable(frame, key) then return end
    for _, k in ipairs({ "MaximizeButton", "MinimizeButton" }) do
        local btn
        if pcall(function() btn = frame[k] end) and btn then
            Skin.IconButton(btn, key .. "." .. k, { desaturate = true })
        else
            E.Missing(key .. "." .. k)
        end
    end
end

------------------------------------------------------------
-- 主試衣間
------------------------------------------------------------
local function ApplyDressUp()
    local f = _G.DressUpFrame
    if not f then
        E.Missing("DressUpFrame")
        return
    end

    Skin.PortraitChrome(f, "DressUpFrame")
    Skin.Panel(f, "DressUpFrame")

    local inset
    if pcall(function() inset = f.Inset end) and inset then
        Skin.Inset(inset, "DressUpFrame.Inset")
    else
        E.Missing("DressUpFrame.Inset")
    end

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "DressUpFrame.CloseButton")
    else
        E.Missing("DressUpFrame.CloseButton")
    end

    local maxmin
    if pcall(function() maxmin = f.MaximizeMinimizeFrame end) and maxmin then
        SkinMaxMinFrame(maxmin, "DressUpFrame.MaximizeMinimizeFrame")
    else
        E.Missing("DressUpFrame.MaximizeMinimizeFrame")
    end

    -- 外觀套裝下拉。⚠ 模板是 `WardrobeCustomSetDropdownTemplate`，在這一輪查到的
    --   暴雪原始碼鏡像裡找不到它的定義（回報 ③）；它至少是一個 `DropdownButton`
    --   intrinsic，所以先照 style1 套 —— `Skin.Dropdown` 找不到 `Background`／`Arrow`
    --   只會多一筆 debug 紀錄，不會壞。
    local dd
    if pcall(function() dd = f.CustomSetDropdown end) and dd then
        Skin.Dropdown(dd, "DressUpFrame.CustomSetDropdown", "style1")
    else
        E.Missing("DressUpFrame.CustomSetDropdown")
    end

    -- 右上角那顆「外觀清單」開關：atlas 是一顆烤了顏色的石頭鈕
    -- ⇒ 先去飽和再染 `textDim`（同子分類列的 ＋／− 鈕，見 Engine.Desaturate）。
    local toggle
    if pcall(function() toggle = f.ToggleCustomSetDetailsButton end) and toggle then
        Skin.IconButton(toggle, "DressUpFrame.ToggleCustomSetDetailsButton", { desaturate = true })
    else
        E.Missing("DressUpFrame.ToggleCustomSetDetailsButton")
    end

    -- 底部三顆：重設／關閉是 UIPanelButtonTemplate；「連結」是一顆 DropdownButton，
    -- 但它 inherits 的也是 UIPanelButtonTemplate（Left/Right/Middle 都在）
    -- ⇒ 三顆都走 `Skin.Button`，彈出的選單不碰（STYLE.md ⑦ 的 C 級）。
    for _, name in ipairs({ "DressUpFrameResetButton", "DressUpFrameCancelButton" }) do
        local btn = _G[name]
        if btn then
            Skin.Button(btn, name)
        else
            E.Missing(name)
        end
    end
    local link
    if pcall(function() link = f.LinkButton end) and link then
        Skin.Button(link, "DressUpFrame.LinkButton")
    else
        E.Missing("DressUpFrame.LinkButton")
    end

    -- 右側兩片面板
    local details
    if pcall(function() details = f.CustomSetDetailsPanel end) and details then
        SkinSidePanel(details, "DressUpFrame.CustomSetDetailsPanel")
    else
        E.Missing("DressUpFrame.CustomSetDetailsPanel")
    end

    local sets
    if pcall(function() sets = f.SetSelectionPanel end) and sets then
        SkinSidePanel(sets, "DressUpFrame.SetSelectionPanel")
        local bar
        if pcall(function() bar = sets.ScrollBar end) and bar then
            Skin.ScrollBar(bar, "DressUpFrame.SetSelectionPanel.ScrollBar")
        else
            E.Missing("DressUpFrame.SetSelectionPanel.ScrollBar")
        end
    else
        E.Missing("DressUpFrame.SetSelectionPanel")
    end
end

------------------------------------------------------------
-- 旁邊那個小試衣間（拍賣場／商人的預覽）
--
-- ⚠ 這個框是 `flattenRenderLayers="true"`（DressUpFrames.xml:44）—— 子孫的 render
--   layer 會被壓平到它這一層（見 .claude/notes/wow-toplevel-flattens-child-strata.md
--   的同一個機制）。我們的 overlay 底色畫在 BACKGROUND 層、四條邊在 BORDER 層，
--   理論上仍然排在模型與按鈕之下，但這是這一輪唯一一個「壓平」的框，
--   **列進實機待確認清單**。
------------------------------------------------------------
local function ApplySideDressUp()
    local f = _G.SideDressUpFrame
    if not f then
        E.Missing("SideDressUpFrame")
        return
    end

    -- `$parentTop` 有全域名字、`-Bottom` 那張**無名無 parentKey** ⇒ 一起走 GetRegions。
    -- `BGTopLeft` / `BGBottomLeft` 是模型背後那張底圖（模型場景的背景）⇒ 留下。
    E.NeutralizeRegions(f, "SideDressUpFrame",
        KeepSet(f, { "BGTopLeft", "BGBottomLeft" }))

    local ov = E.Overlay(f, { key = "SideDressUpFrame" })
    E.Paint(ov, T.fill, T.border)

    local close = _G.SideDressUpFrameCloseButton
    if close then
        -- 關閉鈕自己的 BACKGROUND 層裡還有一張**無名**的 -Corner 雕花（:116）
        E.NeutralizeRegions(close, "SideDressUpFrameCloseButton",
            KeepSet(close, nil, BUTTON_STATE_GETTERS))
        Skin.CloseButton(close, "SideDressUpFrameCloseButton")
    else
        E.Missing("SideDressUpFrameCloseButton")
    end

    local reset
    if pcall(function() reset = f.ResetButton end) and reset then
        Skin.Button(reset, "SideDressUpFrame.ResetButton")
    else
        E.Missing("SideDressUpFrame.ResetButton")
    end
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function Apply()
    ApplyDressUp()
    ApplySideDressUp()

    -- 「同時顯示坐騎」的勾選框（TransmogAndMountDressupFrame，:141）。
    -- 那個框自己沒有任何美術，只有這一顆鈕值得換皮。
    local tm = _G.TransmogAndMountDressupFrame
    if tm then
        local cb
        if pcall(function() cb = tm.ShowMountCheckButton end) and cb then
            Skin.CheckBox(cb, "TransmogAndMountDressupFrame.ShowMountCheckButton")
        end
    end
end

E.Register{
    key   = "dressup",
    addon = nil,                       -- DressUpFrames 住在 Blizzard_UIPanels_Game（LoadFirst）
    title = L["Dressing Room"],
    apply = Apply,
}
