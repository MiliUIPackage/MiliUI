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
-- 「任務文字對比」那一條（第五輪新增，出處全部查證過）：
--   Blizzard_AccessibilityTemplates/QuestTextContrast.lua:1-64
--       CVar 名字 **`questTextContrast`**（`C_CVar.GetCVar(cvarName)`，
--       Blizzard_SettingsDefinitions_Shared/Mainline/Text.lua:19）。取值 0~4：
--         0 = QUEST_BG_DEFAULT（羊皮紙原樣）
--         1~3 = 逐級加亮的無障礙羊皮紙（**字仍然是深色的**）
--         4 = QUEST_BG_DARK ⇒ `QuestTextContrast.UseLightText()` 為真
--       底圖走 `questBackgroundAtlas[值]`（`QuestBG-Parchment-Accessibility4`），
--       任務日誌那一張走 `defaultQuestMapBackgroundTexture[值]`。
--   Blizzard_SettingsDefinitions_Shared/Mainline/Text.lua:18-53
--       暴雪自己的設定就是 `SetCVar("questTextContrast", value)`，
--       外面包一層 `PROXY_QUEST_TEXT_CONTRAST` 的 proxy setting。
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.lua:599,603-607,612-623
--       `QuestFrame_SetMaterial` → `frame.Bg:SetAtlas(QuestTextContrast.GetDefaultBackgroundAtlas())`；
--       `QuestFrame_GetMaterial` 在開了對比之後一律回 `"Parchment", false`
--       ⇒ **四張 `Material*` 角花直接不顯示**；
--       `QuestFrame_SetTitleTextColor` / `_SetTextColor` 在 `UseLightText()` 為真時
--       改讀 `GetMaterialTextColors("Stone")`（亮字）。
--   Blizzard_UIPanels_Game/Mainline/QuestInfo.lua:29,64-80,166,218,238,245
--       獎勵頁整組（標題／說明／目標／獎勵標題／獎勵說明）都在同一個 if 裡換色；
--       `:29` 連 `SealMaterialBG`（蠟封的底）都一起 Hide。
--   Blizzard_UIPanels_Game/Mainline/QuestFrame.lua:338,386
--       對話列表（可接／可交的任務）的字色也一起換成 Stone。
--   Blizzard_UIPanels_Game/Mainline/GossipFrame.lua:54-57
--       `GossipFrameMixin:OnLoad` 把 `PROXY_QUEST_TEXT_CONTRAST` 的變更callback
--       接去 `UpdateScrollBox()` ⇒ **在暴雪的設定面板裡改才會即時重排**；
--       我們是直接 `SetCVar`，所以只在登入時（視窗都還沒開過）動它。
--   Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua:920,2370
--       任務日誌的細節頁與彈出的細節視窗也跟著同一個值走。
--
-- 第四輪重查的結論：**這個視窗不用跟進任何一項引擎改動。**
--   * 沒有 `WowStyle1DropdownTemplate` 系的下拉（整份 QuestFrame.xml 一個 `Dropdown` 都沒有）。
--   * 沒有 `WowScrollBoxList` 池化列（獎勵格與對話選項是靜態的，而且我們本來就不碰）。
--   * 六顆面板按鈕在 XML 裡**沒有**自訂字型物件（`:67,90,99,193,202,225` 都只有
--     `inherits="UIPanelButtonTemplate"`）⇒ `Skin.Button` 的預設路徑正確，不需要 `keepFont`。
--   * 沒有分頁 ⇒ 第三輪的「分頁縫」修正與這裡無關。
--
-- 第五輪改掉的一件事：**羊皮紙改成由暴雪自己換掉。**
--   第四輪的結論是「羊皮紙留著，想要深底就自己去開那個無障礙設定」。
--   使用者實機看到的是「深色外框包一張亮羊皮紙」，跟成就視窗當時同一個問題。
--   我們**還是不自己接管任務文字**（`QuestInfo` 那一整套的字色路徑太多，
--   而且 `QuestFrame_SetTextColor` 每次 OnShow 都重來），改成：
--   **把暴雪內建的「任務文字對比」設成深色那一檔（`questTextContrast = 4`）。**
--   那一檔是暴雪成對設計的 —— 底圖、四張角花、標題、內文、目標、獎勵標題、
--   對話列表的字色全部一起換，一條都不用我們接。
--
--   這一段刻意**不放在配方的 `apply` 裡**，而是這個檔案自己的事件框：
--     * 它跟「`quest` 這個視窗要不要上皮」是兩件事（對話視窗也吃同一個 CVar）；
--     * 更要緊的是**還原**：玩家把 `quest` 關掉之後 `apply` 就再也不跑，
--       CVar 會永遠卡在我們設的值。事件框獨立於視窗開關，關掉時才有人把它還原。
--   總開關（`db.enabled`）關掉一樣視為「不要」，會還原成記住的原值。
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
-- ## 這一輪多出來的接觸面（不是暴雪**物件**，是一個 CVar）
--
-- | 對象 | 動作 |
-- |---|---|
-- | CVar `questTextContrast` | GetCVar（記住原值）／SetCVar（設成 4 或還原） |
-- | 自己的一個事件框 | PLAYER_LOGIN ＋ PLAYER_REGEN_ENABLED |
--
-- ⚠ 一個暴雪 frame 都沒有碰，也沒有呼叫 `Settings.*`。時機一律是「登入之後、
--   任務／對話視窗還沒開過」那一刻，所以不需要叫任何東西重排。
-- ⚠ 戰鬥中不動：`SetCVar` 對部分 CVar 在戰鬥中會被擋，這一個沒查到限制，
--   但延到 `PLAYER_REGEN_ENABLED` 的成本是零，沒有理由去賭。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`QuestFramePanelTemplate` 的 `Bg`（QuestBG-Parchment）** —— 任務正文的羊皮紙。
--   我們**一根手指都不碰它**：字色是 `QuestFrame_SetTitleTextColor` / `_SetTextColor`
--   依 `GetMaterialTextColors(material)` 算出來的（QuestFrame.lua:612,620），
--   底與字是成對的。要深色就讓**暴雪自己**換成對的那一組（`questTextContrast = 4`，
--   見上面那一段），我們只負責把那個開關打開。
-- * **四張 `Material*` 與 `SealMaterialBG`**（QuestFrameTemplates.xml:17-46）——
--   同上。開了對比之後 `QuestFrame_GetMaterial`（QuestFrame.lua:603-607）回的
--   `hasMaterial` 是 `false`，那四張暴雪自己就不顯示了；`SealMaterialBG` 由
--   `QuestInfo_Display`（QuestInfo.lua:29）Hide。**我們一樣不碰。**
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

------------------------------------------------------------
-- 任務／對話的深色底：把暴雪的「任務文字對比」設成深色那一檔
--
-- 為什麼不自己接管字色：見檔頭。為什麼不放在配方的 `apply` 裡：也見檔頭
-- （還原路徑不能綁在「這個視窗有沒有上皮」上）。
--
-- ⚠ **記住原值**存在自己的 SavedVariables（`db.questContrastSaved`）：
--   `false` ＝ 還沒記過。只在「第一次把它改掉」那一刻記，之後不再覆寫 ——
--   不然關掉再開一次就會把我們自己設的 4 記成「原值」，永遠還原不回去。
-- ⚠ 玩家自己在暴雪選項裡改了值，下次登入我們會再蓋回去（設定頁的說明文字有寫）。
--   不做「偵測到玩家改過就放棄」的邏輯：那要比較值，而「值不一樣」同時也可能是
--   暴雪改了預設值，兩種情況分不開。
------------------------------------------------------------
local CVAR = "questTextContrast"
local DARK = 4

-- 暴雪自己兩種都用：`C_CVar.GetCVar`（Text.lua:19）與全域 `SetCVar`（同檔 :28）。
-- 兩邊都先問再用，CVar 被移除的時候 `GetCVar` 會回 nil，那就整段放棄。
local function CurrentContrast()
    local getter = (C_CVar and C_CVar.GetCVar) or GetCVar
    if type(getter) ~= "function" then return nil end
    local ok, value = pcall(getter, CVAR)
    if not ok then return nil end
    return tonumber(value)
end

local function SetContrast(value)
    local setter = (C_CVar and C_CVar.SetCVar) or SetCVar
    if type(setter) ~= "function" then return end
    pcall(setter, CVAR, value)
end

local function ApplyContrast()
    local db = ns.db
    if not db then return end

    -- 這個 CVar 在 12.1 不存在（或被改名）就整段放棄，不報錯
    if CurrentContrast() == nil then
        E.Missing("CVar:" .. CVAR)
        return false
    end

    local want = (db.enabled ~= false) and (db.questDarkText ~= false)

    if want then
        if db.questContrastSaved == false or db.questContrastSaved == nil then
            db.questContrastSaved = CurrentContrast() or 0
        end
        SetContrast(DARK)
    elseif type(db.questContrastSaved) == "number" then
        SetContrast(db.questContrastSaved)
        db.questContrastSaved = false
    end
    return true
end

-- ⚠ 自己的事件框，不是伴隨元件（那一套走 `Engine.Register` 的 `companions`）。
--   `PLAYER_LOGIN` 延一幀是因為 `ns.db` 是在 `Core/Init.lua` 的 `PLAYER_LOGIN`
--   handler 裡才建的，兩個 handler 的先後順序不保證。
local contrastFrame = CreateFrame("Frame")
local contrastPending = false

local function RunContrast()
    if InCombatLockdown() then
        contrastPending = true
        return
    end
    contrastPending = false
    xpcall(ApplyContrast, ns.ReportError)
end

contrastFrame:RegisterEvent("PLAYER_LOGIN")
contrastFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- 下面那一行的放行理由：`contrastFrame` 是我們自己 CreateFrame 出來的空事件框，
-- 不是暴雪的物件，也沒有別人在上面掛過腳本。
contrastFrame:SetScript("OnEvent", function(_, event)   -- skin-lint: own-frame
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0, RunContrast)
    elseif contrastPending then
        RunContrast()
    end
end)
