------------------------------------------------------------
-- 配方：任務視窗（QuestFrame）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.xml:36            QuestFrame（ButtonFrameTemplate）
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.xml:40            QuestFramePortrait（ARTWORK 的 NPC 頭像）
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.xml:65,88,190,223 四個面板（Reward／Progress／Detail／Greeting）
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.xml:67,90,99,193,202,225  六顆 UIPanelButtonTemplate
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.xml:76,108,211,236        四條 QuestScrollFrameTemplate
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.xml:290           QuestModelScene（NPC 立繪）
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.xml:351,367,400,408       ModelTextFrame／文字捲軸／Border／TopBarBg
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.lua:111           QuestFrame_SetPortrait（SetTitle ＋ 頭像）
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.lua:586           QuestFrame_SetMaterial（每次 OnShow 重設 Bg 與 Material*）
--   Blizzard_UIPanels_Game/Mainline/QuestFrameTemplates.xml:3    QuestFramePanelTemplate（Bg ＝ 羊皮紙、四張 Material*）
--   Blizzard_UIPanels_Game/Mainline/QuestFrameTemplates.xml:158  QuestScrollFrameTemplate ← ScrollFrameTemplate
--   Blizzard_SharedXML/SecureUIPanelTemplates.xml:24             ScrollFrameTemplate（OnLoad → ScrollFrame_OnLoad）
--   Blizzard_SharedXML/SecureUIPanelTemplates.lua:1              ScrollFrame_OnLoad → self.ScrollBar
--   Blizzard_SharedXML/Mainline/ScrollDefine.lua:1               SCROLL_FRAME_SCROLL_BAR_TEMPLATE = "MinimalScrollBar"
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:660   ButtonFrameBaseTemplate（Bg／TopTileStreaks／CloseButton）
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:684   ButtonFrameTemplate（$parentInset）
--
-- 查證後跟計畫假設不一樣的兩件事：
--   1. **QuestFrame 不是 `UIThemeContainerFrame`**（對話視窗才是），所以沒有
--      `UIThemeContainerMixin:UpdateBackground` 那條「換主題時重設背景」的行為。
--      會重設背景的是各面板自己的 `QuestFrame_SetMaterial`（QuestFrame.lua:586）與
--      `QuestFrameProgressPanel_SetupBG`（同檔 :182），而它們動的是羊皮紙 `Bg` ——
--      我們本來就不碰，所以不必掛勾。
--   2. 四條捲軸走的是**舊的** `ScrollFrameTemplate`，不是直接寫 MinimalScrollBar；
--      但 `ScrollFrame_OnLoad` 建出來的 `self.ScrollBar` 用的模板就是 `MinimalScrollBar`
--      （ScrollDefine.lua:1），所以 `Skin.ScrollBar` 直接適用。
--
------------------------------------------------------------
-- ## taint 接觸面清單（這份配方碰了哪些暴雪物件、各用了哪個白名單動作）
--
-- | 物件 | 動作 |
-- |---|---|
-- | QuestFrame.NineSlice / .Bg / .TopTileStreaks / .PortraitContainer | SetAlpha(0) |
-- | QuestFrame.TitleContainer.TitleText | SetTextColor |
-- | QuestFramePortrait（全域貼圖） | SetAlpha(0) |
-- | QuestFrame.Inset 的 Bg / NineSlice | SetAlpha(0) |
-- | QuestFrame.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | QuestFrame.CloseButton 的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | 六顆面板按鈕的 Left/Right/Middle | SetAlpha(0) |
-- | 六顆面板按鈕 | SetNormalFontObject(GameFontHighlight) |
-- | 五條 MinimalScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | 五條 MinimalScrollBar 的 Back/Forward.Texture | SetVertexColor |
-- | QuestModelScene 的 Border / TopBarBg / ModelNameDivider / ModelNameBackground | SetAlpha(0) |
-- | QuestModelScene.ModelTextFrame.TextBackground | SetAlpha(0) |
-- | QuestNPCModelNameText | SetTextColor |
-- | 以上各框 | CreateFrame 掛自己的 overlay（SetAllPoints，不吃滑鼠） |
--
-- hook：無。
-- 寫入暴雪欄位：無。讀暴雪欄位：只讀 parentKey／全域名字找區域，以及 GetFrameLevel（有守衛）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`QuestFramePanelTemplate` 的 `Bg`（QuestBG-Parchment）** —— 任務正文的羊皮紙。
--   任務內文與標題的字色是 `QuestFrame_SetTitleTextColor` / `_SetTextColor` 依
--   `GetMaterialTextColors(material)` 算出來的（QuestFrame.lua:612, 620），整組都是
--   為那張底設計的。中和掉＝暗字壓暗底（內容底材保留規則）。
-- * **四張 `Material*` 與 `SealMaterialBG`**（QuestFrameTemplates.xml:17-46）——
--   同上。這幾張在「石板／青銅／大理石」材質的任務上才顯示（QuestFrame.lua:586），
--   而那些任務的字色也是跟著材質換的，拿掉一樣讀不出來。
-- * **`QuestGreetingFrameHorizontalBreak`**（QuestFrame.xml:254）—— 畫在羊皮紙上的分隔線，
--   屬於內容不是 chrome。
-- * **獎勵／需求物品格**（`QuestItemTemplate`、`QuestProgressItem1..6`、
--   `QuestRewardItemHighlight`）、`QuestSpellTemplate`、對話選項列
--   （`QuestTitleButtonTemplate`）—— 那是內容與物品品質色，不是 chrome。
-- * **`QuestFrame.FriendshipStatusBar`**（QuestFrame.xml:277）—— NPC 友誼條，
--   內容不是 chrome；而且它是 `NPCFriendshipStatusBarTemplate`，另有一套美術。
-- * **`QuestModelScene` 的 `ModelBackground` 與 `ShadowOverlay`** —— 3D 立繪就畫在
--   那張底上，中和掉模型會浮在空中（「只做外框不碰模型」）。
-- * **`QuestFrame.AccountCompletedNotice`**、`QuestNpcNameFrame` —— 只有文字，沒有底材。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

-- 四個面板各一顆到兩顆按鈕，全部是 UIPanelButtonTemplate（QuestFrame.xml:67,90,99,193,202,225）
local PANEL_BUTTONS = {
    "QuestFrameAcceptButton",
    "QuestFrameDeclineButton",
    "QuestFrameCompleteQuestButton",
    "QuestFrameCompleteButton",
    "QuestFrameGoodbyeButton",
    "QuestFrameGreetingGoodbyeButton",
}

-- 四個面板各一條 QuestScrollFrameTemplate（← ScrollFrameTemplate，ScrollBar 是 MinimalScrollBar）
local SCROLL_FRAMES = {
    "QuestDetailScrollFrame",
    "QuestProgressScrollFrame",
    "QuestRewardScrollFrame",
    "QuestGreetingScrollFrame",
}

------------------------------------------------------------
-- NPC 立繪（QuestModelScene）
--
-- 「只做外框不碰模型」：拿掉暴雪那圈 boss 立繪金框（Border 是一張 9-slice 貼圖，
-- 從 ModelBackground 的左上一路跨到底下 ModelTextFrame 的右下），改成兩個方框 ——
-- 上面一個框住模型、下面一個框住說明文字。模型自己的底（ModelBackground）與
-- 邊緣陰影（ShadowOverlay）不碰。
--
-- ⚠ `ModelTextFrame.TextBackground` 有中和：它不是「文字為它設計的」內容底材 ——
--   那段文字是 `QuestNPCModelText`（GameFontHighlight 改成米色），在我們的深灰底上
--   照樣讀得出來。判準是「把它拿掉之後，上面那些字還讀得出來嗎」，答案是可以。
------------------------------------------------------------
local function SkinModelScene()
    local scene = _G.QuestModelScene
    if not scene then
        E.Missing("QuestModelScene")
        return
    end

    E.NeutralizeKeys(scene, { "Border", "TopBarBg", "ModelNameDivider", "ModelNameBackground" },
        "QuestModelScene")
    Skin.Panel(scene, "QuestModelScene")

    E.TextColor(_G.QuestNPCModelNameText, T.text, "QuestNPCModelNameText")

    local textFrame
    if pcall(function() textFrame = scene.ModelTextFrame end) and textFrame then
        E.NeutralizeKeys(textFrame, { "TextBackground" }, "QuestModelScene.ModelTextFrame")
        Skin.Panel(textFrame, "QuestModelScene.ModelTextFrame")
    else
        E.Missing("QuestModelScene.ModelTextFrame")
    end

    local scroll = _G.QuestNPCModelTextScrollFrame
    local bar
    if scroll and pcall(function() bar = scroll.ScrollBar end) and bar then
        Skin.ScrollBar(bar, "QuestNPCModelTextScrollFrame.ScrollBar")
    else
        E.Missing("QuestNPCModelTextScrollFrame.ScrollBar")
    end
end

local function Apply()
    local f = QuestFrame
    if not f then
        E.Missing("QuestFrame")
        return
    end

    Skin.PortraitChrome(f, "QuestFrame")

    -- QuestFrame 自己在 ARTWORK 層另外放了一張 60x60 的 NPC 頭像（QuestFrame.xml:40），
    -- 跟模板的 PortraitContainer 疊在同一個位置。兩張都要中和，不然圓頭像還在。
    -- ⚠ 一定要用 alpha：`QuestFrame_SetPortrait`（QuestFrame.lua:111）每次開視窗都
    --   `SetPortraitTexture` 重設材質，換材質撐不過一次對話。
    E.NeutralizeGlobals({ "QuestFramePortrait" })

    Skin.Panel(f, "QuestFrame")

    local inset
    if pcall(function() inset = f.Inset end) and inset then
        Skin.Inset(inset, "QuestFrame.Inset")
    else
        E.Missing("QuestFrame.Inset")
    end

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "QuestFrame.CloseButton")
    else
        E.Missing("QuestFrame.CloseButton")
    end

    -- 六顆面板按鈕。平常只有一兩顆顯示著，但全部都要套 ——
    -- 它們顯示出來的時候不會再跑一次配方。
    for _, name in ipairs(PANEL_BUTTONS) do
        local btn = _G[name]
        if btn then
            Skin.Button(btn, name)
        else
            E.Missing(name)
        end
    end

    for _, name in ipairs(SCROLL_FRAMES) do
        local scroll = _G[name]
        local bar
        if scroll and pcall(function() bar = scroll.ScrollBar end) and bar then
            Skin.ScrollBar(bar, name .. ".ScrollBar")
        else
            E.Missing(name .. ".ScrollBar")
        end
    end

    SkinModelScene()
end

E.Register{
    key   = "quest",
    addon = nil,                       -- Blizzard_UIPanels_Game 是 LoadFirst，永遠在
    title = L["Quest"],
    apply = Apply,
}
