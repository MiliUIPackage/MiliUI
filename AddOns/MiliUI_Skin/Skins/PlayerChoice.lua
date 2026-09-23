------------------------------------------------------------
-- 配方：玩家選擇（`PlayerChoiceFrame`，隨需載入 `Blizzard_PlayerChoice`）
--
-- 每週「你要怎麼幫忙」、豐收採集之類「幾張選項卡片擇一」的視窗。同一個框依每次選擇的
-- `uiTextureKit` 換一整套美術（neutral／alliance／horde／thewarwithin／midnight…），選項卡片
-- 則由物件池依 kit 用不同模板建。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_PlayerChoice/Blizzard_PlayerChoice.toc  LoadOnDemand；RequiredDeps `Blizzard_UIWidgets`
--   Blizzard_PlayerChoice/Blizzard_PlayerChoice_Bootstrap.lua:20-24
--     `PlayerChoiceFrame_TryShow` → `LoadAddOnWithErrorHandling` → `PlayerChoiceFrame:TryShow()`
--   Blizzard_PlayerChoice/Blizzard_PlayerChoice.xml:4
--     `PlayerChoiceFrame` ← **`HorizontalLayoutFrame`**（HIGH strata、toplevel；選項卡片是它的
--      layout children）⇒ **本體是 layout host**：不能在它身上建貼圖或子框（陷阱 2／RegionBackdrop 第 2 條）
--   同檔 :16,22  `BorderOverlay`（OVERLAY 貼圖）／`GridDivider`（playerchoice-gold-divider）
--   同檔 :59-65  `NineSlice`（NineSlicePanelTemplate）
--   同檔 :66-74  `BlackBackground`（frameLevel 450，選中後的遮罩）
--   同檔 :75-86  `Header`（**ResizeLayoutFrame**，`Texture` = 陣營橫幅）
--   同檔 :87-97  `Background`（**一般 Frame**，useParentLevel、clipChildren；`BackgroundTile` 平鋪貼圖）
--   同檔 :98-128  `Title`（`Left`／`Right`／`Middle` ＋ `Text`）
--   同檔 :129-133  `CloseButton`（UIPanelCloseButton，frameLevel 510）
--   同檔 :134  `BorderLayerModelScene`（ScriptAnimatedModelSceneTemplate）
--   同檔 :137-141  `PagingControls`（PagingControlsHorizontalTemplate，格狀版面才顯示）
--   同檔 :142-150  `WidgetContainer`（**UIWidgetContainerTemplate**）
--   同檔 :151-155  `OptionButtonsContainer`（格狀版面的按鈕區）
--   Blizzard_PlayerChoice.lua:357-397  `PlayerChoiceFrameMixin:SetupFrame` —— 每次開窗依 kit：
--     `CloseButton`／`Header`／`Title`／`Background` 的 `SetShown`；`NineSlice`／`BorderOverlay`
--     的 `SetShown` ＋ 重錨；`NineSliceUtil.Apply*Layout(self.NineSlice, kit)`；
--     `BorderOverlay:SetAtlas`；**`UIPanelCloseButton_SetBorderAtlas(self.CloseButton, …)`**（全域函式）；
--     `CloseButton:SetPoint`；`SetupTextureKits(Title／Background／Header)`（`SetAtlas` ＋ `SetShown`）
--     ⇒ 全是 atlas／顯隱／錨點，**沒有一處設 alpha** ⇒ 我們的 `SetAlpha(0)` 一次就撐得住。
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:162-174
--     `UIPanelCloseButton_SetBorderAtlas` —— `self.Border` **第一次呼叫才 `CreateTexture`**（OVERLAY 7）
--     ⇒ 我們 ADDON_LOADED 套皮時它還不存在，只能在這支全域函式的後置勾裡中和。
--   Blizzard_PlayerChoiceOptionBase.xml:11-24
--     `PlayerChoiceBaseOptionButtonTemplate` ← **UIPanelButtonTemplate**（`PlayerChoiceBaseSmaller…` 繼承它）
--   同檔 :30-47  `PlayerChoiceBaseOptionButtonFrameTemplate` ← HorizontalLayoutFrame（按鈕的外包框）
--   Blizzard_PlayerChoiceOptionBase.lua:365-367  外包框 `OnLoad` → `CreateFrame("Button", nil, self, buttonTemplate)`
--     （**池子第一次 Acquire 才建** ⇒ mixin 後置勾裝在 `hooks` 來得及）
--   同檔 :408-448  `PlayerChoiceBaseOptionButtonTemplateMixin:Setup` —— 每次重用都跑：`SetText`、
--     `SetAlpha(0/1)`（hideButtonShowText）、`SetWidth`、`SetEnabled`、`SetPushed`
--   同檔 :456-531  `OnConfirm` → **`C_PlayerChoice.SendPlayerChoiceResponse`**（送出選擇）
--   同檔 :569-578  `SetPushed` → 對 `Left`／`Middle`／`Right` `SetTexture`（**不碰 alpha**）＋ `SetEnabled(false)`
--   Blizzard_PlayerChoiceNormalOptionTemplate.lua:17-64,92-94,214-218
--     卡片 `Background` = `UI-Frame-%s-CardParchment`（**羊皮紙**），字色依 kit 是黑／深藍／深紅
--     （`defaultOptionFontInfo.titleColor = BLACK_FONT_COLOR`），`SetupTextFonts` 每次 Setup 重設；
--     卡片內文 `OptionText` 可能是 **SimpleHTML**（OptionBase.xml:72-78，顏色在 SetText 當下烘進去）
--
------------------------------------------------------------
-- ## 評估結論：做「框」與「按鈕」，卡片內容與小工具整棵不碰
--
-- 照成熟同類實作的「Player choice windows」那一段比對過：它對這個視窗做了外框、關閉鈕、
-- 卡片羊皮紙淡掉＋文字改白、選項按鈕、獎勵圖示方框；**小工具（聲望條那些）一律不在原地碰**，
-- 交給它自己另一套「覆蓋」系統畫在上面。我們的範圍：
--
-- **做的：**
-- * 外框：`NineSlice`（整個子框）、`BorderOverlay`、`GridDivider` alpha 0；在 `Background` 這個
--   **一般子框**上掛一圈 1px 職業色邊（提示皮：浮在世界上方、彈出來選一下就關）。
--   **`BackgroundTile` 保留**（同探究難度選擇保留場景圖）—— 卡片的深色字是對著 kit 的底與羊皮紙設計的。
-- * 關閉鈕：`Skin.CloseButton` ＋ 暴雪每次依 kit 建／換的那圈 `Border` 中和（全域函式後置勾）。
-- * 選項按鈕（「我要幫忙」「選擇」那一排）：**零腳本 primary** —— 按下去就是
--   `SendPlayerChoiceResponse`。每張卡片各自一顆、卡片之間不是成組 ⇒ primary（同天賦視窗的專精卡啟用鈕）。
--   `SetPushed`（已選過的那一顆）＝ 暴雪 `SetEnabled(false)` ＋ 停用字換成一般字 ⇒ 我們的停用底
--   （`fillInset`）＋ 白字：「做過的動作＝停用」，跟套組的按鈕規則一致。
-- * 格狀版面的翻頁鈕（‹ ›）。
--
-- **不碰的（與理由）：**
-- * **所有 `UIWidgetContainerTemplate`**（視窗的 `WidgetContainer`、每張卡片的 `WidgetContainer`）
--   整棵子樹：秘密值 ＋ LayoutFrame（同 `Skins/DelvesPicker.lua`）。零個 region、零個子框、零次 SetAlpha。
-- * **卡片本身**（羊皮紙 `Background`、`ArtworkBorder`、`Artwork`、`Header.Ribbon`、`SubHeader`、獎勵列）：
--   內容底材規則 —— 字色依 kit 是黑／深藍／深紅（`SetupTextFonts` 每次 Setup 重設），內文還可能是
--   SimpleHTML（顏色在 `SetText` 那一刻烘進去，後置勾改色只影響下一次）。要換羊皮紙就得連
--   標題、內文、獎勵名稱（`Setup(fontColor)` 各自下色）、`ListText` 全部接管，而且 HTML 那一條
--   要 `RepaintHTML` 重寫暴雪剛寫的內容 —— 那是「少查一條就整段字消失」的那一類。
-- * 本體（HorizontalLayoutFrame）上的任何貼圖或子框；`Header`（ResizeLayoutFrame，陣營橫幅是 kit 身分）；
--   `Title` 的三片底（標題字是 `SystemFont_Shadow_Large`，壓在那條帶子上設計的）；`BlackBackground`；
--   `BorderLayerModelScene`；Torghast／Cypher／Covenant／GenericPowerChoice 那幾種卡片模板
--   （`showOptionsOnly`：沒有外框，`Background` 本身就藏著 ⇒ 我們的邊也跟著藏）。
--
-- ## 照抄不了的地方（同類實作有、我們契約不准）
--
-- * 它在 `PlayerChoiceFrame` 本體上建整套底圖與邊框 —— 本體是 HorizontalLayoutFrame，我們的
--   `RegionBackdrop` 對 layout host 一律退回子框，而子框會變成它的 layout child ⇒ 改掛在 `Background` 上
--   （矩形只差右邊 2，`showOptionsOnly` 的 kit 沒有邊）。
-- * 它每次都把關閉鈕 `ClearAllPoints`／`SetPoint` 到固定內縮 —— 不准重排，× 維持暴雪依 kit 給的位置。
-- * 它對關閉鈕的 `Border` 與按鈕的 `Left/Middle/Right` 用 `SetAtlas("")`／`SetTexture("")` —— 我們只 alpha 0。
-- * 它 `hooksecurefunc(PlayerChoiceFrame, "SetupOptions"／"SetupOptionsAsGrid"／"SetupFrame", …)` 與
--   `HookScript("OnShow")` 重跑整份 —— 在暴雪框上寫欄位＋在 ShowUIPanel 流程裡跑我們的 Lua。改成：
--   外框一次就撐得住（上面查證：SetupFrame 不碰 alpha）；按鈕走 mixin 後置勾；關閉鈕的圈走全域函式後置勾。
-- * 它讀 `f.optionPools`（暴雪欄位）列舉卡片、把卡片羊皮紙淡掉並把文字改白 —— 見「不碰」。
-- * 它把小工具交給自己的覆蓋系統畫 —— 我們沒有那套，小工具維持原樣。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `NineSlice`（子框）、`BorderOverlay`、`GridDivider` | `SetAlpha(0)` |
-- | `Background`（一般子框） | 以它為 parent 建我們的邊框子框（`Skin.BorderOnly`，不吃滑鼠、零腳本） |
-- | `CloseButton` | Normal／Disabled `SetAlpha(0)`；Highlight／Pushed `SetColorTexture`；`Border`（暴雪建的圈）`SetAlpha(0)` |
-- | 選項按鈕（每顆） | `Left`／`Right`／`Middle` `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 的 `SetColorTexture`（＋ `SetDisabledTexture` 一張白貼圖）。**零 HookScript** |
-- | `PagingControls` 兩顆翻頁鈕 | 三張狀態圖 `SetAlpha(0)` ＋ ‹ › 圖記（`Skin.IconButton`） |
--
-- **讀取**：parentKey，與關閉鈕的 `Border`（暴雪自己建的 region 參照，只拿來 `SetAlpha(0)`）。
-- **不讀** `choiceInfo`、`optionInfo`、`buttonInfo`、`optionPools`、任何小工具。
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc("UIPanelCloseButton_SetBorderAtlas", …)` | 全域函式後置勾 | 第一行查本檔的弱鍵表：不是我們接管的那顆關閉鈕立刻返回；是的話中和它的 `Border`。**不讀其他參數** |
-- | `PlayerChoiceBaseOptionButtonTemplateMixin:Setup` | mixin 後置勾（`Engine.HookRows`） | apply：零腳本 primary。**不讀參數** |
-- | 原語內建的 `HookScript("OnEnter"/"OnLeave")`（＋翻頁鈕的 `OnEnable`/`OnDisable`） | frame script 後掛 | 只對關閉鈕與翻頁鈕；內容只換我們自己 overlay 的顏色 |
--
-- **`hooksecurefunc` 在 `PlayerChoiceFrame` 或它任何子框上：0 支。`HookScript("OnShow")`：0 支。**
-- **選項按鈕上的 `HookScript`：0 支。`C_PlayerChoice` 上的 hook：0 支。**
--
-- ### 套組裡別人掛在這個框上的東西
--
-- 一支第三方工具插件在這個框上加代幣數與自己的替代介面、團隊工具插件加一顆說明鈕（都是它們自己的框）。
-- 我們只點名具名 parentKey、不遞迴掃，碰不到它們。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local KEY = "PlayerChoiceFrame"

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

------------------------------------------------------------
-- 關閉鈕的那一圈（`UIPanelCloseButton_SetBorderAtlas` 懶建的 `Border`）
------------------------------------------------------------
local ownClose = setmetatable({}, { __mode = "k" })

local function NeutralizeCloseBorder(btn)
    local border = Optional(btn, "Border")
    if border then E.Neutralize(border, KEY .. ".CloseButton.Border") end
end

------------------------------------------------------------
-- 選項按鈕：零腳本 primary（同 `Skins/PlayerSpells.lua` 的 `ScriptlessButton`）
-- TODO(升格): 零腳本按鈕第六份了 —— 收成 `Skin.ScriptlessButton`。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }
local BUTTON_KEY = "PlayerChoiceBaseOptionButton"

local function ApplyOptionButton(btn)
    if not E.Usable(btn, BUTTON_KEY) then return end
    -- ⚠ 先建 overlay 再中和（顯式保護框回 nil，倒過來寫會做出一顆隱形的選項鈕）
    local ov = E.Overlay(btn, { key = BUTTON_KEY })
    if not ov then return end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, BUTTON_KEY)
    E.ButtonFonts(btn, GameFontHighlight, BUTTON_KEY)
    E.ScriptlessButton(btn, ov, "primary", BUTTON_KEY)   -- **不掛腳本**
end

local closeHooked = false

local function InstallHooks()
    -- 按鈕是池子第一次 Acquire 外包框時才 `CreateFrame` 的 ⇒ mixin 後置勾在 ADDON_LOADED 裝得上。
    -- ⚠ `Setup` 裡暴雪會 `SetAlpha(0/1)` 按鈕本身、`SetPushed` 會對 Left/Middle/Right `SetTexture`
    --   —— 都不碰我們中和用的區域 alpha ⇒ 不需要 reapply。
    E.HookRows{
        key    = BUTTON_KEY,
        mixin  = _G.PlayerChoiceBaseOptionButtonTemplateMixin,
        method = "Setup",
        apply  = ApplyOptionButton,
    }

    if not closeHooked and type(_G.UIPanelCloseButton_SetBorderAtlas) == "function" then
        closeHooked = true
        local broken = false
        hooksecurefunc("UIPanelCloseButton_SetBorderAtlas", function(btn)
            if broken or not ownClose[btn] then return end
            local ok, err = pcall(NeutralizeCloseBorder, btn)
            if not ok then
                broken = true
                E.NoteBrokenHook("UIPanelCloseButton_SetBorderAtlas")
                ns.ReportError(err)
            end
        end)
    end
end

local PAGING_GLYPH = { PrevPageButton = "chevronLeft", NextPageButton = "chevronRight" }

local function Apply()
    local f = _G.PlayerChoiceFrame
    if not f then
        E.Missing(KEY)
        return
    end
    if not E.Usable(f, KEY) then return end

    -- 外框：只 alpha，SetupFrame 每次換 atlas／顯隱都不會打回來（檔頭查證）
    E.NeutralizeKeys(f, { "NineSlice", "BorderOverlay", "GridDivider" }, KEY)

    -- 邊：掛在 `Background`（一般子框）上 —— 本體是 HorizontalLayoutFrame，碰不得。
    -- 不畫底：`BackgroundTile` 是 kit 的底，卡片的深色字是對著它設計的。
    local bg = Required(f, "Background", KEY .. ".Background")
    if bg then Skin.BorderOnly(bg, KEY .. ".Background", { border = { T.Accent() } }) end

    local close = Required(f, "CloseButton", KEY .. ".CloseButton")
    if close then
        Skin.CloseButton(close, KEY .. ".CloseButton")
        ownClose[close] = true
        NeutralizeCloseBorder(close)   -- 已經開過一次的話 Border 已經在了
    end

    -- 格狀版面的翻頁鈕
    local pc = Optional(f, "PagingControls")
    if pc then
        for k, glyph in pairs(PAGING_GLYPH) do
            local btn = Optional(pc, k)
            if btn then
                Skin.IconButton(btn, KEY .. ".PagingControls." .. k, {
                    inset = 4,
                    glyph = glyph,
                    glyphColor = T.textDim,
                    trackEnabled = true,
                })
            end
        end
    end
end

E.Register{
    key   = "playerchoice",
    addon = "Blizzard_PlayerChoice",
    title = L["Player Choice"],
    hooks = InstallHooks,
    apply = Apply,
}
