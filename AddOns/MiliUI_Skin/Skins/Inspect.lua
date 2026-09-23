------------------------------------------------------------
-- 配方：觀察視窗（`InspectFrame`，隨需載入 `Blizzard_InspectUI`）
--
-- 長相跟角色面板（`Skins/Character.lua`）同一套：外框、底部三顆分頁、裝備格走
-- `Skin.ItemButton`、模型後面的場景底圖與雕花內框中和、模型本體保留。
-- 另外兩頁（PvP、公會）只換底圖與字色。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_InspectUI/Mainline/Blizzard_InspectUI.xml:4
--     `InspectFrame` ← `ButtonFrameTemplate`（toplevel）⇒ `InspectFrameInset`（parentKey `Inset`）、
--     `InspectFrameCloseButton`（Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:680,686）
--   同檔 :6,18,30  `InspectFrameTab1..3`（PanelTabButtonTemplate，錨在視窗下緣）
--   Blizzard_InspectUI.lua:33  `OnLoad` → `GetTitleText():SetFontObject("GameFontHighlight")`；
--     之後只有 `SetTitle`（純文字），**沒有 `SetTitleColor`** ⇒ 標題白字一次就永久有效
--     （跟角色面板不同，不需要任何標題勾）
--   同檔 :128-143  `InspectFrame_UpdateTabs` → 公會分頁 `PanelTemplates_Enable/DisableTab`
--     ⇒ 停用態交給引擎那三支 `PanelTemplates_*` 全域後置勾
--   Blizzard_InspectUI/Mainline/InspectPaperDollFrame.xml
--     :3-80  `InspectPaperDollItemSlotButton{Left,Right,Bottom}Template`（ItemButton intrinsic；
--            `$parentFrame` ＝ `Char-LeftSlot`／`Char-RightSlot`／`Char-BottomSlot` 雕花；
--            `SocketDisplay` ← PaperDollItemSocketDisplay*Template（LayoutFrame））
--     :83   `LevelTextWrapper`（ResizeLayoutFrame）裡的 `InspectLevelText`（GameFontNormalSmall）
--     :102  `ViewButton`（UIPanelButtonTemplate，「在試衣間檢視」）
--     :112-214 `InspectModelFrame`（ModelWithControlsTemplate）：
--            `InspectModelFrameBackground{TopLeft,TopRight,BotLeft,BotRight}`（場景底圖四塊）、
--            `InspectModelFrameBackgroundOverlay`（純黑遮罩）、
--            `InspectModelFrameBorder{TopLeft,TopRight,BottomLeft,BottomRight,Left,Right,Top,Bottom,Bottom2}`
--     :216-327 `InspectPaperDollItemsFrame` 的 18 顆 `Inspect<Slot>Slot` ＋ `InspectTalents`
--            （UIPanelButtonTemplate，mixin `InspectPaperDollFrameTalentsButtonMixin`）
--     :298-311 `InspectMainHandSlot` 左側那張**無名**的 `Char-Slot-Bottom-Left`
--   InspectPaperDollFrame.lua:104  `InspectPaperDollFrame_OnShow` → 全域 `SetPaperDollBackground`
--     （Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:2640-2664：四塊底圖只 `SetTexture`，
--      **`BackgroundOverlay:SetAlpha(0.3~0.8)` 每次都重設** ⇒ 要在那支全域的後置勾裡重申）
--   同檔 :161-189  全域 `InspectPaperDollItemSlotButton_Update`：有裝備走 `SetItemButtonTexture`＋
--     `SetItemButtonQuality`；**空格**只 `SetItemButtonTexture` 然後直接 `button.IconBorder:Hide()`
--     ⇒ 引擎那兩支全域勾在 `IconBorder` 還亮著時就跑完了，換觀察另一個人時空格會留著上一個人的
--       品質色 ⇒ 在這支全域的後置勾裡再刷新一次
--   Blizzard_InspectUI/Mainline/InspectPVPFrame.xml:46-150
--     `InspectPVPFrame.BG`（PVP-Conquest-Misc 底圖）、`HKs`、`HonorLevel`、五個
--     `InspectPvpStatTemplate`（`RatingLabel`／`RecordLabel` 是 GameFontNormal 暗金標籤）、
--     三顆 PvP 天賦格（`InspectPvpTalentSlotTemplate`）
--     InspectPVPFrame.lua:69-117 只 `SetText`／`Show`／`Hide`，**零 `SetTextColor`**
--   Blizzard_InspectUI/Mainline/InspectGuildFrame.xml:24-146
--     `InspectGuildFrameBG`（GuildInspect-Parts 羊皮紙）、`InspectGuildFrameBanner`／
--     `BannerBorder`／`TabardLeftIcon`／`TabardRightIcon`（公會徽章）、四行字、`Points`
--     InspectGuildFrame.lua:17-35 只 `SetText`／`SetFormattedText`，**零 `SetTextColor`**
--
------------------------------------------------------------
-- ## 做法對照成熟同類實作（第十三輪：範圍照抄、外觀用我們的）
--
-- 它做的、我們照做：外框換皮、頭像拿掉、Inset 內框中和、模型後面四塊場景底圖與雕花內框
-- 全部拿掉、**連 `BackgroundOverlay` 那張黑遮罩也拿掉**、裝備格外框（`$parentFrame`）與
-- 無名雕花拿掉、裝備格換成直角 1px 品質邊、關閉鈕、三顆分頁、天賦鈕與試衣間鈕「原地換長相」
-- （它的註解：讓玩家點到的仍是暴雪自己那顆按鈕，secure 處理照原樣跑）、PvP 頁與公會頁的底圖拿掉。
--
-- **照抄不了的地方（契約）：**
-- * 它把整個視窗重排成兩欄、換自己的背景圖、把兩顆按鈕重錨＋改尺寸＋自畫標籤、把標題置中
--   （`ClearAllPoints`／`SetPoint`／`SetSize`／`SetFrameLevel`）—— 一律不做，**只重畫不重排**。
-- * 它把模型控制列的按鈕 `SetAlpha(0)`＋`EnableMouse(false)` —— 我們不碰（那是功能，不是美術）。
-- * 它對 PvP 頁、公會頁的「無名子框」一律 `Hide()`（連公會成就點數 `Points` 一起藏）——
--   禁止 `Hide`，而且 `Points` 是資訊 ⇒ 只中和兩頁的底圖。
-- * 它在 `InspectFrame` 上 `HookScript("OnShow"/"OnHide"/"OnSizeChanged")`、
--   `hooksecurefunc(InspectFrame, "SetPoint")`、`hooksecurefunc(tab, "SetText")` ——
--   全部改成：只在 apply 做一次 ＋ 兩支**全域函式**後置勾（見下）。
-- * 裝等／升級軌道／附魔文字：那是它自己的功能，不是換皮；套組另有插件畫。
--
------------------------------------------------------------
-- ## 秘密值
--
-- 12.1 觀察的 `InspectFrame.unit`／GUID 可能是秘密值（`MiliUI/Fix/InspectTaintFix.lua` 就是
-- 在處理 `UnitGUID(InspectFrame.unit) == unit` 比對炸掉的情況）。
-- ⇒ **這份配方不讀任何單位資料**：不讀 `InspectFrame.unit`、不呼叫 `UnitGUID`／`UnitClass`／
--   `GetInventoryItem*`、不讀 `INSPECTED_UNIT`。兩支後置勾都只用參數裡的**框參照**。
-- ⚠ 觀察天賦的「複製」鈕：`MiliUI_UnitFrames/Elements/Inspect.lua` 的註解記錄過 ——
--   `InspectFrame.unit` 只要帶上插件的 taint，天賦頁交給 `PlayerSpellsFrame` 之後
--   `CopyToClipboard`（保護函式）就被封鎖。我們**不寫 `InspectFrame` 的任何欄位**，而那條路
--   的入口 `InspectTalents` 一律**零腳本**（`Engine.ScriptlessButton`），點擊堆疊裡沒有我們的 Lua。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `InspectFrame` 的 NineSlice／Bg／TopTileStreaks／PortraitContainer | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `InspectFrame` 本身 | `Engine.RegionBackdrop`（底＋邊＋標題帶，建成它自己的 BACKGROUND 貼圖） |
-- | `InspectFrame.TitleContainer.TitleText` | `SetTextColor` |
-- | `InspectFrameInset` 的 Bg／NineSlice | `SetAlpha(0)` ＋ 它自己的 `fillInset` 貼圖（`Skin.Inset`） |
-- | `InspectFrameCloseButton` | Normal／Disabled `SetAlpha(0)`；Highlight／Pushed `SetColorTexture`（`Skin.CloseButton`） |
-- | `InspectFrameTab1..3` 的九張分頁貼圖 | `SetAlpha(0)` ＋ `SetNormalFontObject`（`Skin.TabGroup`） |
-- | 18 個 `Inspect<Slot>SlotFrame` | `SetAlpha(0)` |
-- | 18 顆 `Inspect<Slot>Slot` | IconBorder／NormalTexture `SetAlpha(0)`、icon `SetTexCoord`、Highlight `SetColorTexture`、IconBorder `IsShown()`／`GetVertexColor()`（**只轉交**）（`Skin.ItemButton`） |
-- | 主手格上那張無名 `Char-Slot-Bottom-Left` | `SetAlpha(0)`（`GetRegions` ＋ keep-set） |
-- | `InspectModelFrameBackground*` 四塊、`InspectModelFrameBorder*` 九條、`InspectModelFrameBackgroundOverlay` | `SetAlpha(0)`（Overlay 在 `SetPaperDollBackground` 後置勾裡重申） |
-- | `InspectLevelText` | `SetTextColor` |
-- | **零腳本按鈕**：`InspectTalents`（primary）、`ViewButton`（secondary） | Left／Right／Middle `SetAlpha(0)` ＋ `SetNormalFontObject(GameFontHighlight)` ＋ Highlight／Disabled 的 `SetColorTexture`（primary 另 `SetDisabledTexture` 一張白貼圖）。**零 HookScript** |
-- | `InspectPVPFrame.BG` | `SetAlpha(0)` |
-- | `InspectPVPFrame.HonorLevel`；五個統計框的 `RatingLabel`／`RecordLabel` | `SetTextColor` |
-- | `InspectGuildFrameBG` | `SetAlpha(0)` |
-- | `InspectGuildFrame` 的 `guildName`／`guildRealmName`／`guildLevel`／`guildNumMembers` | `SetTextColor` |
--
-- ### 讀了什麼
--
-- 只有結構（parentKey、全域名稱、`GetRegions`）與物品格 `IconBorder` 的 `IsShown()`／
-- `GetVertexColor()`（`Engine.PassBorderColor`，傳遞者規則）。**零單位資料。**
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc("InspectPaperDollItemSlotButton_Update", …)` | **全域函式**後置勾 | 第一行查弱鍵表（不是我們接管的格子立刻返回）；`Skin.ItemButtonRefresh`：重下 IconBorder 的 alpha、轉交品質色、重裁圖示 |
-- | `hooksecurefunc("SetPaperDollBackground", …)` | **全域函式**後置勾 | 第一行比對參數是不是 `InspectModelFrame`（框參照比對，不是單位資料）；是才對 `BackgroundOverlay` `SetAlpha(0)` |
-- | 引擎的 `SetItemButtonQuality`／`SetItemButtonTexture` 全域後置勾 | 既有 | 第一行查弱鍵表 |
-- | 引擎的 `PanelTemplates_SelectTab／DeselectTab／SetDisabledTabState` 全域後置勾 | 既有 | 分頁三態 |
-- | 分頁、關閉鈕的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛（原語內建） | 只換我們自己 overlay 的顏色 |
--
-- **`hooksecurefunc` 在 `InspectFrame` 或它任何子框上：0 支。`HookScript("OnShow"/"OnHide")`：0 支。
-- 零腳本按鈕上的 `HookScript`：0 支。寫入暴雪欄位：無。**
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * 模型本體 `InspectModelFrame`（含旋轉／縮放控制列）與陣營圖示 `InspectFaction`（模型拉不到時的替代圖）。
-- * 裝備格的 `SocketDisplay`（寶石孔，LayoutFrame）、`IconOverlay`／`IconOverlay2`（資訊）、所有腳本。
-- * PvP 天賦格（`InspectPvpTalentSlotTemplate`，天賦內容）、`SmallWreath`。
-- * 公會徽章（Banner／BannerBorder／TabardLeftIcon／TabardRightIcon）與成就點數 `Points` —— 身分與值。
-- * 套組裡掛在同一個視窗上的插件：`TinyInspect-Remake`（裝等、直角邊框 —— 它的直角邊預設關閉，
--   兩邊都開會有兩圈邊，同角色面板的已知衝突）、`KeystoneLoot`（最愛圖示）、`MplusAdventureGuide`
--   （裝等字）都掛在全域 `InspectPaperDollItemSlotButton_Update` 或自己建的字上，跟我們各畫各的；
--   `MiliUI/Fix/InspectTaintFix.lua` 包的是 OnEvent／OnShow 腳本，我們不碰腳本。
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

------------------------------------------------------------
-- 零腳本按鈕（同 `Skins/PlayerSpells.lua` 的 local `ScriptlessButton`）
-- TODO(升格): 第四份配方用到了 —— 收成 `Skin.ScriptlessButton`。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })       -- 先建 overlay 再中和（顯式保護框回 nil）
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)
    return ov
end

------------------------------------------------------------
-- 角色頁
------------------------------------------------------------
-- 模型四周的雕花與場景底圖（InspectPaperDollFrame.xml:119-207，全部是全域具名貼圖）
local MODEL_ART_GLOBALS = {
    "InspectModelFrameBackgroundTopLeft",
    "InspectModelFrameBackgroundTopRight",
    "InspectModelFrameBackgroundBotLeft",
    "InspectModelFrameBackgroundBotRight",
    "InspectModelFrameBackgroundOverlay",
    "InspectModelFrameBorderTopLeft",
    "InspectModelFrameBorderTopRight",
    "InspectModelFrameBorderBottomLeft",
    "InspectModelFrameBorderBottomRight",
    "InspectModelFrameBorderLeft",
    "InspectModelFrameBorderRight",
    "InspectModelFrameBorderTop",
    "InspectModelFrameBorderBottom",
    "InspectModelFrameBorderBottom2",
}

local EQUIP_SLOTS = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
    "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
    "MainHand", "SecondaryHand",
}

-- 主手格上那張無名的 `Char-Slot-Bottom-Left`（InspectPaperDollFrame.xml:302-309）只能走
-- `GetRegions()`；要留下的全部列出來（ItemButton intrinsic 的區域，
-- Blizzard_ItemButton/Shared/ItemButtonTemplate.xml:18-77）。
-- ⚠ Highlight／Pushed 也要留：中和過的貼圖再也上不了色（區域 alpha × 顏色 alpha）。
local WEAPON_SLOT_KEEP = {
    "icon", "IconBorder", "IconOverlay", "IconOverlay2",
    "searchOverlay", "ItemContextOverlay",
}
local WEAPON_SLOT_KEEP_GETTERS = { "GetHighlightTexture", "GetPushedTexture" }

local function ApplyPaperDoll()
    E.NeutralizeGlobals(MODEL_ART_GLOBALS)

    for _, slot in ipairs(EQUIP_SLOTS) do
        local name = "Inspect" .. slot .. "Slot"
        E.Neutralize(_G[name .. "Frame"], name .. "Frame")
        local btn = _G[name]
        if btn then
            Skin.ItemButton(btn, name)
        else
            E.Missing(name)
        end
    end

    local main = _G.InspectMainHandSlot
    if main then
        E.NeutralizeRegions(main, "InspectMainHandSlot",
            E.KeepSet(main, WEAPON_SLOT_KEEP, WEAPON_SLOT_KEEP_GETTERS))
    end

    -- 等級／專精／職業那一行：XML 的 GameFontNormalSmall（暗金），Lua 只 `SetFormattedText`
    -- （職業名的顏色是字串裡的色碼，不受影響）
    local lvl = _G.InspectLevelText
    if lvl then E.TextColor(lvl, T.text, "InspectLevelText") else E.Missing("InspectLevelText") end

    local pd = _G.InspectPaperDollFrame
    if not pd then
        E.Missing("InspectPaperDollFrame")
        return
    end

    -- 「在試衣間檢視」：開試衣間，跟天賦鈕並列、不是這一頁的主動作 ⇒ secondary。
    -- 零腳本是為了整個視窗的按鈕都不掛腳本（它排在天賦鈕同一個視窗裡，規則一致比較好查）。
    local view = Required(pd, "ViewButton", "InspectPaperDollFrame.ViewButton")
    if view then ScriptlessButton(view, "InspectPaperDollFrame.ViewButton", "secondary") end

    -- 「天賦」：通往 `PlayerSpellsUtil.OpenToClassTalentsTab(InspectFrame.unit)` 與之後的
    -- 「複製」（`CopyToClipboard` 保護函式）⇒ 零腳本。這一頁唯一的「做事」按鈕 ⇒ primary。
    -- 暴雪會依 `C_Traits.HasValidInspectData()` 停用它 ⇒ 靠 `ScriptlessButton` 補的 DisabledTexture
    -- 蓋上中性底，停用時不會看起來像能按。
    local items = _G.InspectPaperDollItemsFrame
    local talents = items and Required(items, "InspectTalents", "InspectPaperDollItemsFrame.InspectTalents")
    if talents then ScriptlessButton(talents, "InspectPaperDollItemsFrame.InspectTalents", "primary") end
end

------------------------------------------------------------
-- PvP 頁
------------------------------------------------------------
local PVP_STATS = { "RatedBG", "Arena2v2", "Arena3v3", "RatedSoloShuffle", "RatedBGBlitz" }

local function ApplyPVP()
    local f = _G.InspectPVPFrame
    if not f then
        E.Missing("InspectPVPFrame")
        return
    end
    local key = "InspectPVPFrame"
    E.NeutralizeKeys(f, { "BG" }, key)

    local honor = Optional(f, "HonorLevel")
    if honor then E.TextColor(honor, T.text, key .. ".HonorLevel") end

    -- 「評分：」「紀錄：」是欄位標籤 ⇒ textDim；右邊的值本來就是白字（GameFontHighlight）
    for _, k in ipairs(PVP_STATS) do
        local stat = Optional(f, k)
        if stat then
            for _, lk in ipairs({ "RatingLabel", "RecordLabel" }) do
                local fs = Optional(stat, lk)
                if fs then E.TextColor(fs, T.textDim, key .. "." .. k .. "." .. lk) end
            end
        else
            E.Missing(key .. "." .. k)
        end
    end
end

------------------------------------------------------------
-- 公會頁
------------------------------------------------------------
local GUILD_TEXT = {
    { key = "guildName",       color = "text" },
    { key = "guildRealmName",  color = "textDim" },
    { key = "guildLevel",      color = "textDim" },
    { key = "guildNumMembers", color = "textDim" },
}

local function ApplyGuild()
    local f = _G.InspectGuildFrame
    if not f then
        E.Missing("InspectGuildFrame")
        return
    end
    E.Neutralize(_G.InspectGuildFrameBG, "InspectGuildFrameBG")
    for _, t in ipairs(GUILD_TEXT) do
        local fs = Optional(f, t.key)
        if fs then E.TextColor(fs, T[t.color], "InspectGuildFrame." .. t.key) end
    end
end

------------------------------------------------------------
-- 兩支全域函式後置勾
------------------------------------------------------------
local slotHookBroken, bgHookBroken = false, false

-- 空格那條路（見檔頭）：暴雪最後才 `IconBorder:Hide()`，引擎的全域勾追不到 ⇒ 這裡補刷新一次。
local function AfterSlotUpdate(button)
    if slotHookBroken or type(button) ~= "table" then return end
    local key = E.itemButtons[button]
    if not key then return end            -- 不是我們接管的格子（或還沒套皮）
    local ok, err = pcall(Skin.ItemButtonRefresh, button, key)
    if not ok then
        slotHookBroken = true
        E.NoteBrokenHook("InspectPaperDollItemSlotButton_Update")
        ns.ReportError(err)
    end
end

-- `SetPaperDollBackground` 每次都把 `BackgroundOverlay` 設回 0.3~0.8 ⇒ 重申中和。
-- 角色面板也走這一支：參數不是觀察的模型框就立刻返回（只比對框參照）。
local function AfterPaperDollBackground(model)
    if bgHookBroken or model == nil or model ~= _G.InspectModelFrame then return end
    local ok, err = pcall(E.Neutralize, _G.InspectModelFrameBackgroundOverlay,
        "InspectModelFrameBackgroundOverlay")
    if not ok then
        bgHookBroken = true
        E.NoteBrokenHook("SetPaperDollBackground")
        ns.ReportError(err)
    end
end

local hooked = false
local function InstallHooks()
    if hooked then return end
    hooked = true
    if type(_G.InspectPaperDollItemSlotButton_Update) == "function" then
        hooksecurefunc("InspectPaperDollItemSlotButton_Update", AfterSlotUpdate)
    else
        E.Missing("InspectPaperDollItemSlotButton_Update")
    end
    if type(_G.SetPaperDollBackground) == "function" then
        hooksecurefunc("SetPaperDollBackground", AfterPaperDollBackground)
    else
        E.Missing("SetPaperDollBackground")
    end
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function Apply()
    local f = _G.InspectFrame
    if not f then
        E.Missing("InspectFrame")
        return
    end

    Skin.PortraitChrome(f, "InspectFrame")
    Skin.Panel(f, "InspectFrame")

    local inset = Required(f, "Inset", "InspectFrame.Inset")
    if inset then Skin.Inset(inset, "InspectFrame.Inset") end

    local close = _G.InspectFrameCloseButton
    if close then Skin.CloseButton(close, "InspectFrameCloseButton") else E.Missing("InspectFrameCloseButton") end

    -- 底部三顆分頁（角色／PvP／公會）。第三顆會被停用（沒有公會），但排在最後 ⇒ 不用 hideable。
    local tabs = {}
    for i = 1, 3 do
        local key = "InspectFrameTab" .. i
        local tab = _G[key]
        if tab then
            tabs[#tabs + 1] = { tab = tab, key = key }
        else
            E.Missing(key)
        end
    end
    Skin.TabGroup(tabs, { kind = "panel", joined = "TOP" })

    ApplyPaperDoll()
    ApplyPVP()
    ApplyGuild()
end

E.Register{
    key   = "inspect",
    addon = "Blizzard_InspectUI",
    title = L["Inspect"],
    hooks = InstallHooks,
    apply = Apply,
}
