------------------------------------------------------------
-- 配方：暴雪通知（`BNToastFrame`：好友上線／下線、廣播、好友與社群邀請）
--
-- 跟拾取通知一樣由 AlertFrame 顯示，但它是**單一的靜態框**（不是物件池）⇒ 登入時套一次。
-- 做法照「成熟同類實作」的 BNet toast 段落；外觀是**提示皮**（`T.tipFill` ＋ 1px 職業色邊）：
-- 浮在世界上方、彈出來讀一眼（STYLE.md ①）。STYLE.md ⑦ 原本把它列在 C 級，理由正是
-- 「判準落在提示皮那一邊」—— 這一份就是用提示皮做。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_BNet/BNet.xml:3-81  `BNToastFrame` ← `SocialToastTemplate`（mixin BNToastMixin）：
--     `IconTexture`（$parentIconTexture，UI-Toast-ToastIcons 圖集、**每次依通知種類 SetTexCoord 挑格子**）／
--     `TopLine`／`MiddleLine`／`BottomLine`／`DoubleLine`（FriendsFont_Normal，XML 與 Lua 各自上色）／
--     `TooltipFrame`（TOOLTIP strata，← TooltipBackdropTemplate，`Text`；OnUpdate 自己 SetHeight）
--   Blizzard_SocialToast/SocialToast.xml:44-70  `SocialToastTemplate` ← **BackdropTemplate**
--     （`backdropInfo = BACKDROP_TOAST_12_12`：九片 backdrop 貼圖 `TopLeftCorner`…`Center`，
--      由 `BackdropTemplateMixin` 在 OnLoad 建在**框自己身上**）／`glow`（$parentGlowFrame，
--      ← SocialToastGlowTemplate :15-27，ADD，**自帶 alpha 動畫**）／`CloseButton`
--      （SocialToastCloseButtonTemplate :29-42，三張 UI-Toast-CloseButton-* 檔案貼圖）
--   Blizzard_SharedXML/Backdrop.lua:79-87  `BACKDROP_TOAST_12_12`；:195-256 backdrop 只在
--     尺寸改變時重算 texCoord（`SetupTextureCoordinates`），**不碰 alpha**
--   Blizzard_BNet/Mainline/BNet.lua:193-303  `BNToastMixin:ShowToast`：只改四行字的文字／顏色／
--     顯示、`IconTexture:SetTexCoord`、`bottomLine:SetPoint`、`self:SetHeight(50 或 63)`，
--     然後 `AlertFrame_ShowNewAlert(self)` —— **不重設任何 backdrop 或 glow 的 vertex color**
--     ⇒ 登入時套一次就永久有效，不需要任何 hook
--   Blizzard_SharedXML/SharedTooltipTemplates.xml:111-121  `TooltipBackdropTemplate`（`NineSlice`，useParentLevel）
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `BNToastFrame` 自己的 backdrop 貼圖（九片，無 parentKey 以外的指名方式 ⇒ `GetRegions` 掃貼圖，保留 `IconTexture`／`glow`） | `SetAlpha(0)`（`Engine.NeutralizeRegions`） |
-- | `glow` | `SetVertexColor(1,1,1,0)`（它的 alpha 由動畫驅動，`SetAlpha(0)` 撐不住；vertex alpha 是另一個乘數） |
-- | `BNToastFrame` | `Engine.RegionBackdrop`（提示皮底＋職業色邊，建成它自己的貼圖；高度 50↔63 自動跟著） |
-- | `CloseButton` | Normal／Disabled `SetAlpha(0)`；Highlight／Pushed `SetColorTexture`；× 圖記（`Skin.CloseButton`） |
-- | `TooltipFrame.NineSlice` | `SetAlpha(0)`；`TooltipFrame` 換成提示皮（`Engine.RegionBackdrop`） |
--
-- **讀了什麼**：parentKey、`GetRegions()`（讀結構，只挑出貼圖）。**不讀** `toastType`／`toastData`／
-- 任何文字（點通知會開戰網密語、對象是秘密字串 —— 那個實作也特別強調「這個框上不寫任何 Lua 欄位」）。
--
-- **hook**：`hooksecurefunc`：**0 支**。只有 `Skin.CloseButton` 內建的
-- `HookScript("OnEnter"/"OnLeave")`（關閉鈕的滑過色，只碰我們自己的 overlay）。
-- **`BNToastFrame` 本體上的 HookScript：0 支。**
--
-- ## 刻意不碰
-- * 四行字的顏色（暴雪依通知種類每次重上：帳號名藍、狀態灰，部分是內嵌色碼）、字型。
-- * `IconTexture`（圖集挑格子靠 texCoord ⇒ 不能裁邊）、`TooltipFrame.Text`。
-- * `TimeAlertFrame`（同模板的另一個框，不在這一輪）。
--
-- ## 照抄不了的地方
-- * `HookShow(BNToastFrame)` 每次顯示重跑一次（那個實作自己也說是「保險」）⇒ 契約不准在暴雪框上
--   HookScript OnShow；原始碼查證過 ShowToast 不重設我們動過的任何屬性，登入一次就夠。
-- * `glow` 的 `SetAtlas("")`／`SetTexture("")` ⇒ 改成 vertex alpha 中和。
-- * 換字型（`WSkin.Font`）⇒ 不做（只重畫不重排；字型不在白名單）。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local KEY = "BNToastFrame"
local VERTEX_HIDDEN = { 1, 1, 1, 0 }

local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

local function Apply()
    local f = _G.BNToastFrame
    if not f then
        E.Missing(KEY)
        return
    end
    if not E.Usable(f, KEY) then return end

    -- backdrop 的九片沒有穩定的指名方式（鍵名是 Backdrop.lua 的內部表），掃貼圖、留下圖示與閃光
    E.NeutralizeRegions(f, KEY, E.KeepSet(f, { "IconTexture", "glow" }))

    local glow = Optional(f, "glow")
    if glow then E.VertexColor(glow, VERTEX_HIDDEN, KEY .. ".glow") else E.Missing(KEY .. ".glow") end

    local bg = E.RegionBackdrop(f, { key = KEY })
    E.Paint(bg, T.tipFill, { T.Accent() })

    local close = Optional(f, "CloseButton")
    if close then Skin.CloseButton(close, KEY .. ".CloseButton") else E.Missing(KEY .. ".CloseButton") end

    local tip = Optional(f, "TooltipFrame")
    if tip and E.Usable(tip, KEY .. ".TooltipFrame") then
        E.NeutralizeKeys(tip, { "NineSlice" }, KEY .. ".TooltipFrame")
        local tbg = E.RegionBackdrop(tip, { key = KEY .. ".TooltipFrame" })
        E.Paint(tbg, T.tipFill, { T.Accent() })
    end
end

E.Register{
    key   = "bntoast",
    addon = "Blizzard_BNet",
    title = L["Battle.net Toasts"],
    apply = Apply,
}
