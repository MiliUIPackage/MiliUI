------------------------------------------------------------
-- 配方：玩家對玩家（Blizzard_PVPUI）—— PVEFrame 的第二個分頁
--
-- 這一份**不是獨立的配方**：它是 `Skins/PVE.lua` 那一筆 `Engine.Register` 的
-- 一個 `part`（`addon = "Blizzard_PVPUI"`），共用 `pve` 設定開關。
-- 玩家看到的是一個視窗，設定裡就不該多一個勾選框（STYLE.md ⑥ 第 5 步）。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_PVPUI/Blizzard_PVPUI_Mainline.toc:4     `## LoadOnDemand: 1`
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:901   PVPUIFrame（setAllPoints，parent PVEFrame）
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:907   PVPQueueFrame
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:591   PVPQueueFrameButtonTemplate
--       Background（bluemenu-main 切片）／Ring（bluemenu-Ring）／Icon（被 CircleMask 遮圓）
--       ＋ HighlightTexture（**224x80，比按鈕矩形 203x60 大一圈**）
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:1091-1166  CategoryButton1..5
--       （每顆各自在 Layer 裡補一條 `Name` FontString，GameFontNormalLarge）
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:1682  PVPQueueFrame.HonorInset（InsetFrameTemplate）
--       ＋ Background（atlas pvpqueue-sidebar-background）
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:466   PVPConquestBarTemplate
--       Border（pvpqueue-conquestbar-frame）／Background（pvpqueue-conquestbar-background）
--       ＋ `<BarTexture parentKey="FillTexture">`
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:865   PVPRoleButtonTemplate
--       ← LFGRoleButtonWithShortageRewardTemplate（LFGFrame.xml:77）
--       ⇒ 有 `checkButton`，**沒有** `background`
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:871   PVPRoleListTemplate（TankIcon/HealerIcon/DPSIcon）
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:1167  HonorFrame
--       :1173 ConquestBar／:1178 Inset／:1184 RoleList／:1189 $parentTypeDropdown／
--       :1205 SpecificScrollBar／:1291 $parentQueueButton（MagicButtonTemplate）
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:1319  ConquestFrame
--       :1334 ConquestBar／:1339 Inset／:1345 RoleList／:1398 ConquestJoinButton
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:1475  TrainingGroundsFrame
--       :1481 ConquestBar／:1486 Inset／:1492 RoleList／:1497 $parentTypeDropdown／
--       :1514 SpecificTrainingGroundList.ScrollBar／:1581 QueueButton
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:1602  PlunderstormFrame（:1617 Inset／:1629 StartQueue）
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:564   PVPQueueFrame_SelectButton(index)
--       選中態＝`button.Background:SetTexCoord(...)`，**全域函式**
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:468   PVPQueueFrame_SetCategoryButtonState
--       停用時 `button.Ring:SetDesaturated(true)` ＋ 換 Background 的 TexCoord
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:340-353  CategoryButtonN.Icon/Name 的內容
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:2141,2158-2163
--       `PVPConquestBarMixin:Update` **每次**都 `self.FillTexture:SetAtlas(...)`
--       （黃／藍／停用三種）⇒ 換填充材質撐不過一次更新，而且那個顏色是**狀態**
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:2186-2196
--       `PVPConquestBarMixin:SetDisabled` —— **對 `Border` 與 `Background` 下
--       `SetAlpha(0.6 或 1)`**，也就是會把我們的中和整個打回來
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:519-522
--       征服條的 `<OnShow method="OnShow"/>` / `<OnEvent method="OnEvent"/>`
--       —— 是 **frame script**，`HookScript` 接得到（mixin 勾不到）
--   Blizzard_PVPUI/Mainline/Blizzard_PVPUI.lua:415-419
--       開了掠奪風暴的時候 `CategoryButtons` 的 `Icon`／`Ring` 會被 `SetSize`／
--       `SetPoint` 縮小（66→46 / 95→67）⇒ 我們對 `Ring` 只染色，不量尺寸
--
-- 查證後跟計畫假設不一樣的三件事：
--   1. **征服點數條的填充材質不能換。** `PVPConquestBarMixin:Update`（.lua:2158）
--      每次更新都重設 `FillTexture` 的 atlas，而且黃／藍／灰三種正好是
--      「本週進度／已達上限／停用」三種狀態 —— 那是資訊不是裝飾。
--      ⇒ `Skin.StatusBar` 傳 `texture = false`、不傳 `color`，只換框與底。
--   2. **PvP 的角色鈕沒有 `background`。** 它走的是 `WithShortageReward` 那一支，
--      圓底是 `LFGRoleButtonWithBackgroundTemplate` 才有的。共用的
--      `SkinRoleButton` 因此先問再中和。
--   3. **快速對戰／評級的活動列不做。** `PVPCasualActivityButton`（.xml:645）與
--      `PVPRatedActivityButtonTemplate`（:730）整顆就是一張
--      `pvpqueue-button-casual-*` 的美術圖 ＋ 一張 `SelectedTexture`，
--      中和掉會變成空方塊；那是「內容」不是「框」。保留。
--
-- 第五輪查證後多出來的一件事：
--   4. **征服條的中和撐不過第一次 `Update`。** `PVPConquestBarMixin:SetDisabled`
--      （.lua:2186-2196）對 `Border`／`Background` 下 `SetAlpha(0.6 或 1)` ——
--      `self.disabled` 一開始是 `nil`，所以視窗第一次顯示時那一支一定會跑一遍，
--      我們的 `SetAlpha(0)` 當場被打回 1（使用者擷圖裡那條「深色面板上的棕色
--      雕花長條」就是這個）。
--      mixin 勾不到（XML 的 frame 在 `ADDON_LOADED` 之前就建好，陷阱 4 第三層），
--      但 `OnShow`／`OnEvent` 在模板裡是 **frame script**（.xml:519-522）
--      ⇒ `HookScript` 接得到，而且只碰指名的那三條。
--
------------------------------------------------------------
-- ## taint 接觸面清單（暴雪物件）
--
-- | 物件 | 動作 |
-- |---|---|
-- | PVPQueueFrame.CategoryButton1..5 的 Background | SetAlpha(0) |
-- | 同五顆的 Ring | SetDesaturated(true)（Engine.Desaturate）＋ SetVertexColor |
-- | 同五顆的 HighlightTexture | SetAlpha(0)（改由 overlay 自己畫滑過） |
-- | 同五顆的 Name | SetTextColor |
-- | PVPQueueFrame.HonorInset 的 Bg / NineSlice / Background | SetAlpha(0) |
-- | 四個 InsetFrameTemplate（HonorInset ＋ 三頁的 Inset ＋ 鬥陣頁） | SetAlpha(0) |
-- | 三條征服條的 Border / Background | SetAlpha(0)（**填充材質與顏色不碰**） |
-- | 同三條 | HookScript("OnShow"/"OnEvent") 重申上面那一行的中和 |
-- | 九顆角色鈕的 checkButton 的 Normal/Pushed/Disabled 貼圖 | SetAlpha(0) |
-- | 同九顆的 Checked / DisabledChecked 貼圖 | SetVertexColor（職業色，保留勾的形狀） |
-- | 兩顆 WowStyle1Dropdown 的 Background | SetAlpha(0)；Arrow | SetVertexColor |
-- | 四顆 MagicButtonTemplate 的 Left/Right/Middle | SetAlpha(0) ＋ SetNormalFontObject |
-- | 兩條 MinimalScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | 同兩條的 Back/Forward.Texture | SetVertexColor |
-- | 以上各框 | CreateFrame 掛自己的 overlay（不吃滑鼠、零腳本） |
--
-- hook（這一輪新增的）：
--   1. `hooksecurefunc("PVPQueueFrame_SelectButton", fn)`
--      —— 左側五顆大類按鈕的選中態。hook 裡只做兩件事：型別檢查傳進來的 `index`
--         （純數字參數），然後對**我們自己的** overlay 呼叫 `Engine.SetSelected`。
--         不讀暴雪的任何欄位、不寫任何欄位。
--   2. 三條征服條各一組 `HookScript("OnShow", fn)` ＋ `HookScript("OnEvent", fn)`
--      （第五輪新增）—— hook 裡只做一件事：對 `Border`／`Background` 兩張**暴雪
--         自己會把 alpha 設回來的**貼圖重下 `SetAlpha(0)`。不讀任何東西、不寫欄位、
--         不呼叫暴雪的函式。理由見上面第 4 點。
--   ＋ `Skin.Row` 的 `opts.ownHover` ⇒ 五顆按鈕各一組
--     HookScript("OnEnter"/"OnLeave")（`Engine.TrackSelectable`，只碰自己的 overlay）。
--
-- 寫入暴雪欄位：無。讀暴雪物件：只有 `Engine.Overlay` 內部的 `GetFrameLevel`。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **快速對戰／評級／鬥陣的活動列**（`PVPCasualActivityButton`、
--   `PVPRatedActivityButtonTemplate`、`PVPTrainingGroundActivityButtonTemplate`）
--   與它們的 `Reward` 子框 —— 整顆是美術圖，見上面第 3 點。
-- * **賽季獎勵框 `SeasonRewardFrameTemplate`（.xml:3）、`PVPRatedTierTemplate`、
--   榮譽等級盤 `HonorLevelDisplayTemplate`（.xml:804，是一個 Cooldown）** ——
--   裝飾與 3D／大圖，STYLE.md ③ 的內容底材規則。
-- * **`PVPQueueFrame.PrestigePortrait`、`PVPTalentPrestigeLevelDialog`** ——
--   前者是頭像美術，後者是 `frameStrata="DIALOG"` 的升階彈窗。
-- * **`ConquestFrame.NoSeason` / `.Disabled`（GlowBoxTemplate）** ——
--   提示框，出現機會極低，不花接觸面。
-- * **`LFGListPVPStub`** —— 那只是個容器，真正的框是 `LFGListFrame`，
--   已經在 `Skins/PVE.lua` 裡接管了（PvE／PvP 兩邊共用同一個 `LFGListFrame`）。
-- * **`PvPObjectiveBannerFrame`、`ConquestTooltip`** —— 不在這個視窗裡。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret

local X = ns.PVESkin
local Field = X.Field

------------------------------------------------------------
-- 左側五顆大類按鈕
--
-- 跟 `GroupFinderGroupButtonTemplate` 同一套（連 TexCoord 都一樣），只是 parentKey
-- 大寫。兩態都自己畫的理由也一樣：HighlightTexture 是 224x80 置中、按鈕矩形是
-- 203x60，交給引擎畫會在按鈕外圍多出一圈白 8% 的光暈。
------------------------------------------------------------
local categoryButtons = {}
local categoryHookInstalled = false

local function InstallCategoryHook()
    if categoryHookInstalled then return end
    if type(_G.PVPQueueFrame_SelectButton) ~= "function" then
        E.Missing("PVPQueueFrame_SelectButton")
        return
    end
    categoryHookInstalled = true

    -- ⚠ 跟 PVE.lua 的大類按鈕同型：只讀後置勾的**參數**，只碰自己的 overlay。
    hooksecurefunc("PVPQueueFrame_SelectButton", function(index)
        local n = S.PlainNumber(index)
        -- ⚠ 固定 1..5，理由同 PVE.lua：`index` 是暴雪的 `pvpFrames` 序號，
        --   用陣列長度會在「中間有一顆沒接管成功」時整排錯位。
        for i = 1, 5 do
            E.SetSelected(categoryButtons[i], n ~= nil and i == n)
        end
    end)
end

local function ApplyCategoryButtons(queue)
    wipe(categoryButtons)
    for i = 1, 5 do
        local key = "PVPQueueFrame.CategoryButton" .. i
        local btn = Field(queue, "CategoryButton" .. i)
        if btn then
            -- `Icon` 不碰：被 CircleMask 遮成圓形，而且那是這一類的身分
            -- `Ring` 不中和、壓深當一圈蓋住遮罩毛邊的深色框（同 PVE.lua 的大類鈕）
            Skin.Row(btn, key, { keys = { "Background" }, ownHover = true })
            X.SkinCategoryRing(Field(btn, "Ring"), key .. ".Ring")
            categoryButtons[i] = btn
            -- 這個模板一樣沒有 `<ButtonText>`，`Name` 是 Layer 裡的獨立 FontString
            -- （.xml:1097）⇒ 只能 SetTextColor，不能換 NormalFont
            E.TextColor(Field(btn, "Name"), T.text, key .. ".Name")
        else
            E.Missing(key)
        end
    end
end

------------------------------------------------------------
-- 三頁共用的零件：征服點數條 ＋ 內嵌框 ＋ 三顆角色鈕
------------------------------------------------------------
local ROLE_ICON_KEYS = { "TankIcon", "HealerIcon", "DPSIcon" }

-- 征服條上兩張「暴雪會把 alpha 設回來」的裝飾（見檔頭第 4 點）
local CONQUEST_ART = { "Border", "Background" }

-- 已經掛過重申勾的條（弱鍵，不在暴雪的框上寫欄位）
local conquestHooked = setmetatable({}, { __mode = "k" })

-- ⚠ hook 內只做白名單動作（對兩張貼圖 `SetAlpha(0)`），不讀任何東西、
--   不呼叫暴雪的函式、不寫欄位。`Engine.Neutralize` 的計數器只算第一次，
--   所以每次事件重跑不會把 `/mskin debug` 的數字灌大。
local function TrackConquestBar(bar, key)
    if conquestHooked[bar] then return end
    if type(bar.HookScript) ~= "function" then return end
    conquestHooked[bar] = true

    local function Reassert()
        E.NeutralizeKeys(bar, CONQUEST_ART, key)
    end
    pcall(bar.HookScript, bar, "OnShow", Reassert)
    pcall(bar.HookScript, bar, "OnEvent", Reassert)
end

local function ApplyPage(frame, key)
    if not frame then
        E.Missing(key)
        return
    end

    local bar = Field(frame, "ConquestBar")
    if bar then
        -- ⚠ `texture = false`：`PVPConquestBarMixin:Update`（.lua:2158-2163）每次都
        --   重設 `FillTexture` 的 atlas，而且黃／藍／灰三種是**狀態**不是裝飾。
        -- ⚠ 不傳 `color`：同一個理由。
        Skin.StatusBar(bar, key .. ".ConquestBar", {
            texture = false,
            keys = CONQUEST_ART,
        })
        -- ⚠ 一定要接著掛重申勾：`SetDisabled` 會把那兩張的 alpha 設回 0.6／1。
        TrackConquestBar(bar, key .. ".ConquestBar")
    else
        E.Missing(key .. ".ConquestBar")
    end

    local inset = Field(frame, "Inset")
    if inset then
        Skin.Inset(inset, key .. ".Inset")
    else
        E.Missing(key .. ".Inset")
    end

    local roles = Field(frame, "RoleList")
    if roles then
        for _, roleKey in ipairs(ROLE_ICON_KEYS) do
            local btn = Field(roles, roleKey)
            if btn then
                X.SkinRoleButton(btn, key .. ".RoleList." .. roleKey)
            else
                E.Missing(key .. ".RoleList." .. roleKey)
            end
        end
    else
        E.Missing(key .. ".RoleList")
    end
end

------------------------------------------------------------
local function ApplyPVP()
    local queue = _G.PVPQueueFrame
    if not queue then
        E.Missing("PVPQueueFrame")
        return
    end

    ApplyCategoryButtons(queue)

    -- 右側那條常駐的榮譽側欄
    local honorInset = Field(queue, "HonorInset")
    if honorInset then
        E.NeutralizeKeys(honorInset, { "Background" }, "PVPQueueFrame.HonorInset")
        Skin.Inset(honorInset, "PVPQueueFrame.HonorInset")
    else
        E.Missing("PVPQueueFrame.HonorInset")
    end

    -- 快速對戰
    local honor = _G.HonorFrame
    ApplyPage(honor, "HonorFrame")
    if honor then
        local dd = _G.HonorFrameTypeDropdown
        if dd then
            Skin.Dropdown(dd, "HonorFrameTypeDropdown", "style1")
        else
            E.Missing("HonorFrameTypeDropdown")
        end

        local bar = Field(honor, "SpecificScrollBar")
        if bar then
            Skin.ScrollBar(bar, "HonorFrame.SpecificScrollBar")
        else
            E.Missing("HonorFrame.SpecificScrollBar")
        end

        X.SkinKeyedButtons(honor, "HonorFrame", { "QueueButton" })
    end

    -- 評級
    local conquest = _G.ConquestFrame
    ApplyPage(conquest, "ConquestFrame")
    if conquest then
        X.SkinKeyedButtons(conquest, "ConquestFrame", { "JoinButton" })
    end

    -- 鬥陣練習場
    local training = _G.TrainingGroundsFrame
    ApplyPage(training, "TrainingGroundsFrame")
    if training then
        local dd = _G.TrainingGroundsFrameTypeDropdown
        if dd then
            Skin.Dropdown(dd, "TrainingGroundsFrameTypeDropdown", "style1")
        else
            E.Missing("TrainingGroundsFrameTypeDropdown")
        end

        X.SkinOwnedScrollBar(Field(training, "SpecificTrainingGroundList"),
            "TrainingGroundsFrame.SpecificTrainingGroundList.ScrollBar")
        X.SkinKeyedButtons(training, "TrainingGroundsFrame", { "QueueButton" })
    end

    -- 掠奪風暴（沒開活動的時候整個分類是隱藏的，找不到就靜默降級成一筆紀錄）
    local plunder = _G.PlunderstormFrame
    if plunder then
        local inset = Field(plunder, "Inset")
        if inset then Skin.Inset(inset, "PlunderstormFrame.Inset") end
        X.SkinKeyedButtons(plunder, "PlunderstormFrame", { "StartQueue" })
    end
end

-- hook 要在戰鬥閘前面裝，但 `Engine.Register` 的 `parts` 只有 `addon/hooks/apply`
-- 三個欄位可用，而這一支的 hook 只跟「已經存在的全域函式」有關（不是 mixin 拷貝
-- 的競賽）⇒ 放在 apply 的第一行就夠，而且保證 `Blizzard_PVPUI` 已經載入。
ns.PVESkin.ApplyPVP = function()
    InstallCategoryHook()
    ApplyPVP()
end
