------------------------------------------------------------
-- 配方：收藏 —— 寵物日誌（PetJournal）
--
-- 跟 Skins/Collections.lua 共用設定 key `collections`（理由見那一份的檔頭），
-- 共用工具在 `ns.CollectionsSkin`。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:7    CompanionListButtonTemplate（mixin PetJournalListItemMixin）
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:11,14,29,58,130
--        列的 background／icon／iconBorder／selectedTexture／HighlightTexture
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:79   列裡的 dragButton
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:794  PetJournal
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:796  PetCount（InsetFrameTemplate3）
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:852,859,865  LeftInset／PetCardInset／RightInset
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:871  searchBox（SearchBoxTemplate）
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:880  FilterDropdown（WowStyle1FilterDropdownTemplate）
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:889,896  ScrollBox ＋ ScrollBar（MinimalScrollBar）
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:903-1020  loadoutBorder（十四張具名貼圖）
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:1021 Loadout（三個出戰格）
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:1046 PetCard
--   Blizzard_Collections/Shared/Blizzard_PetCollection.xml:1558,1587  FindBattleButton／SummonButton（MagicButtonTemplate）
--   Blizzard_Collections/Shared/Blizzard_PetCollection.lua:104  view:SetElementInitializer → PetJournal_InitPetButton
--   Blizzard_Collections/Shared/Blizzard_PetCollection.lua:766  PetJournal_InitPetButton
--   Blizzard_Collections/Shared/Blizzard_PetCollection.lua:966  PetJournalListItemMixin（只有 OnClick/OnEnter/OnLeave/OnDragStart）
--   Blizzard_Collections/Mainline/Blizzard_CollectionTemplates.lua:130  CollectionItemListButton_SetRedOverlayShown
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:722  MagicButtonTemplate ← UIPanelButtonTemplate
--
-- 查證後跟計畫假設不一樣的三件事：
--   1. **列的 mixin 裡沒有 `Init`。** `PetJournalListItemMixin`（.lua:966）只有
--      滑鼠腳本；真正每次重用都跑的是**全域函式** `PetJournal_InitPetButton`
--      （.lua:766，由 `SetElementInitializer` 呼叫，:104）
--      ⇒ `Engine.HookRows{ mixin = _G, method = "PetJournal_InitPetButton" }`。
--      形狀跟坐騎列一模一樣，所以 apply／reapply 直接用共用的那兩支。
--   2. **出戰隊伍那圈框是十四張「只有全域名字」的貼圖**（`$parentTopLeft` …
--      `$parentSlotHeaderRight`，.xml:910-1012），沒有 parentKey ⇒ 只能
--      `Engine.NeutralizeGlobals` 逐一點名。它自己是一個**純裝飾框**
--      （`PetJournalLoadoutBorder`），中和完再補一圈 `Skin.BorderOnly`。
--   3. **「尋找對戰」「召喚」都是 `MagicButtonTemplate`**（← `UIPanelButtonTemplate`），
--      OnClick 是普通 Lua，不是 secure 按鈕 ⇒ `Skin.Button` 適用。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 物件 | 動作 |
-- |---|---|
-- | PetJournal.LeftInset / .PetCardInset / .RightInset 的 Bg / NineSlice | SetAlpha(0) |
-- | PetJournal.PetCount 的八片邊 ＋ Bg | SetAlpha(0) |
-- | PetJournal.searchBox 的 Left/Right/Middle | SetAlpha(0) |
-- | PetJournal.searchBox 的 searchIcon / clearButton.Icon / Instructions | SetVertexColor / SetTextColor |
-- | PetJournal.FilterDropdown.Background | SetAlpha(0) |
-- | PetJournalLoadoutBorder* 的十二張外框貼圖 ＋ 標題帶四張 | SetAlpha(0) |
-- | PetJournalLoadoutBorderUpperSeparator / LowerSeparator | SetVertexColor(fillHover) |
-- | PetJournal.FindBattleButton / .SummonButton 的 Left/Right/Middle | SetAlpha(0) |
-- | 同兩顆 | SetNormalFontObject(GameFontHighlight) |
-- | PetJournal.ScrollBar 的 Track/Thumb 六張 | SetAlpha(0)；Back/Forward.Texture | SetVertexColor |
-- | 寵物列（池化）的 background | SetAlpha(0) |
-- | 寵物列的 HighlightTexture | SetColorTexture（白 8%） |
-- | 寵物列的 icon | SetTexCoord（裁邊，放 reapply） |
-- | 以上各框 | CreateFrame 掛自己的 overlay |
--
-- hook：`Engine.HookRows{ mixin = _G, method = "PetJournal_InitPetButton" }` ×1。
-- 寫入暴雪欄位：無。讀暴雪物件：只有 `GetRegions` / `GetFrameLevel`。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **所有拖放互動**：列的 `dragButton`（`OnDragStart` → 拖寵物到出戰格）、
--   出戰格的 `dragButton`、技能格。**一個腳本都不掛、一個欄位都不寫**，
--   我們對列只做「中和底圖 ＋ 掛一個不吃滑鼠的 overlay ＋ 裁圖示」。
-- * **`PetJournal.PetCard` 的內部**（血量／速度／品質三塊、六顆技能格、經驗條、
--   `modelScene`）與 **`PetJournal.Loadout` 的三個出戰格**：那一整塊是寵物對戰的
--   資訊面板，顏色（寵物類型色、品質色、血條紅綠）全部是**值**。要做得先把每一條
--   「暴雪在哪裡重設它」查完，接觸面比整個收藏視窗其餘部分加起來還大
--   ⇒ **這一輪不做**，只把它坐的 `PetCardInset`／`RightInset` 換成皮。
-- * **列的 `selectedTexture`／`petTypeIcon`／`isDead`／`new`／`newGlow`／
--   `dragButton` 的 `levelBG`／`level`／`favorite`／`ActiveTexture`**：全部是資訊
--   （理由與坐騎列相同，見 Skins/Collections.lua 的檔頭）。
-- * **`PetJournal.MainHelpButton`（`MainHelpPlateButton`）**：教學泡泡的觸發鈕，
--   `HelpTip` 系統會讀它 —— 12.1 的「暴雪框上的欄位一個都不能寫」在 `HelpTip`
--   上踩過（`.claude/notes/wow-121-addon-code-in-secure-stack.md` 入口 4），不靠近。
-- * **`PetJournal.HealPetSpellFrame`／`SummonRandomPetSpellFrame`**：
--   `UIPanelSpellButtonFrameTemplate`，底下是 secure 的施法按鈕。
-- * **`PetJournal.SpellSelect`**（換技能的小浮層）：只有換技能時才出現，
--   而且它的兩顆是 `PetSpellSelectButtonTemplate`，接觸面沒查完。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local Shared = ns.CollectionsSkin

local PET_ROW_KEY = "CompanionListButton"

-- 出戰隊伍那圈框：**只有全域名字、沒有 parentKey**（.xml:910-1012）
local LOADOUT_BORDER_ART = {
    "PetJournalLoadoutBorderTopLeft",
    "PetJournalLoadoutBorderTopRight",
    "PetJournalLoadoutBorderBottomLeft",
    "PetJournalLoadoutBorderBottomRight",
    "PetJournalLoadoutBorderTop",
    "PetJournalLoadoutBorderBottom",
    "PetJournalLoadoutBorderLeft",
    "PetJournalLoadoutBorderRight",
    "PetJournalLoadoutBorderSlotHeaderBG",
    "PetJournalLoadoutBorderSlotHeaderF",
    "PetJournalLoadoutBorderSlotHeaderLeft",
    "PetJournalLoadoutBorderSlotHeaderRight",
}

-- 兩條分隔線**不中和**：它們把三個出戰格分開，是版面資訊不是雕花。
-- 染成 `fillHover`（0.23）—— 深底上的分隔線要比底亮才看得見（同 SectionTitle 的髮絲線）。
local LOADOUT_SEPARATORS = {
    "PetJournalLoadoutBorderUpperSeparator",
    "PetJournalLoadoutBorderLowerSeparator",
}

local function SkinLoadoutBorder(j)
    local border
    if not (pcall(function() border = j.loadoutBorder end) and border) then
        E.Missing("PetJournal.loadoutBorder")
        return
    end

    E.NeutralizeGlobals(LOADOUT_BORDER_ART)
    for _, name in ipairs(LOADOUT_SEPARATORS) do
        E.VertexColor(_G[name], T.fillHover, name)
    end

    -- 底不畫：底下的 RightInset 已經有一層 fillInset，再鋪一層只會蓋住出戰格。
    Skin.BorderOnly(border, "PetJournal.loadoutBorder")
end

local function Apply()
    local j = _G.PetJournal
    if not j then
        E.Missing("PetJournal")
        return
    end

    for _, k in ipairs({ "LeftInset", "PetCardInset", "RightInset" }) do
        local inset
        if pcall(function() inset = j[k] end) and inset then
            Skin.Inset(inset, "PetJournal." .. k)
        else
            E.Missing("PetJournal." .. k)
        end
    end

    local count
    if pcall(function() count = j.PetCount end) and count then
        Shared.SkinInset3(count, "PetJournal.PetCount")
    else
        E.Missing("PetJournal.PetCount")
    end

    local search
    if pcall(function() search = j.searchBox end) and search then
        Skin.EditBox(search, "PetJournal.searchBox")
    else
        E.Missing("PetJournal.searchBox")
    end

    local filter
    if pcall(function() filter = j.FilterDropdown end) and filter then
        Skin.Dropdown(filter, "PetJournal.FilterDropdown", "filter")
    else
        E.Missing("PetJournal.FilterDropdown")
    end

    for _, k in ipairs({ "FindBattleButton", "SummonButton" }) do
        local btn
        if pcall(function() btn = j[k] end) and btn then
            Skin.Button(btn, "PetJournal." .. k)
        else
            E.Missing("PetJournal." .. k)
        end
    end

    Shared.SkinOwnedScrollBar(j, "PetJournal.ScrollBar")
    SkinLoadoutBorder(j)

    local box
    if pcall(function() box = j.ScrollBox end) and box then
        E.SweepRows(box, "PetJournal.ScrollBox", Shared.petSweep)
    end
end

------------------------------------------------------------
-- hook 安裝（**不過戰鬥閘**，理由見 STYLE.md ③ 的陷阱 4）
------------------------------------------------------------
local function InstallHooks()
    Shared.petSweep = E.HookRows{
        key    = "CompanionListButton",
        mixin  = _G,                          -- 初始化走全域函式，不是 mixin（見檔頭 1.）
        method = "PetJournal_InitPetButton",
        match  = function(row)
            return type(row) == "table" and row.dragButton ~= nil and row.petTypeIcon ~= nil
        end,
        apply   = function(row) Shared.ApplyCompanionRow(row, PET_ROW_KEY) end,
        reapply = function(row) Shared.ReapplyCompanionRow(row, PET_ROW_KEY) end,
    }
end

E.Register{
    key   = "collections",              -- 跟 Skins/Collections.lua 同一個設定開關
    addon = "Blizzard_Collections",
    title = L["Collections: Pets"],
    hooks = InstallHooks,
    apply = Apply,
}
