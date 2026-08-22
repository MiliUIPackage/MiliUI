------------------------------------------------------------
-- 即時預覽：一個**完全自有**的 GameTooltip（GameTooltipTemplate），
-- 走 ns.TrackTip 接管 ⇒ skin / post-call / 血條全部是真管線，零 taint 顧慮。
--
--   玩家：SetUnit("player")——player token 不受 12.1 身分限制，資料全明文。
--   NPC ：沒有穩定存在的 NPC 單位可以 SetUnit，改餵假 raw 走同一套文法。
--   物品：SetItemByID 走真物品管線（品質框、圖示、ID 行）。
--
-- 設定一改（ns.ApplyAll → SettingsApplied）就重繪。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local S = ns.Secret
local UnitInfo = ns.UnitInfo

ns.Preview = {}
local Preview = ns.Preview

local tip            -- 預覽 tooltip
local chipHolder
local chipsById = {}
local mode = "player"
local highlightChip
local enabled = false   -- 只有樣式／玩家／NPC／物品與ID 分頁有預覽

local PREVIEW_ITEM_ID = 19019   -- 雷霆之怒（橙裝，看得出品質邊框）

-- 法術預覽用「玩家自己職業」的代表技能（跟自己最相關；沒對到就退爐石術）
local CLASS_SPELLS = {
    WARRIOR = 100, PALADIN = 853, HUNTER = 56641, ROGUE = 1833,
    PRIEST = 589, DEATHKNIGHT = 49998, SHAMAN = 188196, MAGE = 133,
    WARLOCK = 686, MONK = 100780, DRUID = 8921, DEMONHUNTER = 162794,
    EVOKER = 361469,
}
local PREVIEW_SPELL_ID = CLASS_SPELLS[ns.playerClass] or 8690

------------------------------------------------------------
-- NPC 假資料（全明文）
------------------------------------------------------------
local function FakeNpcRaw()
    return {
        unit = nil,
        name = L["Training Dummy"],
        levelValue = 80,
        level = 80,
        effectiveLevel = 80,
        classif = "elite",
        classifElite = ELITE,
        creature = L["Humanoid"],
        reaction = 4,
        reactionName = _G["FACTION_STANDING_LABEL4"],
        raidIcon = ICON_LIST and ICON_LIST[8] and (ICON_LIST[8] .. "0|t") or nil,
        moveSpeed = 100,
    }
end

local function RenderNpc()
    tip:ClearLines()
    local config = ns.db.unit.npc
    local raw = FakeNpcRaw()
    local data = UnitInfo.GetUnitData(nil, config.elements, raw)
    for _, row in ipairs(data) do
        tip:AddLine(UnitInfo.JoinRow(row, " "), 1, 1, 1)
    end
    if tip:NumLines() == 0 then tip:AddLine(L["Training Dummy"], 1, 1, 1) end
    ns.UnitLines.ColorBorder(tip, config, raw)
    ns.UnitLines.ColorBackground(tip, config, raw)
    ns.Bar.ActivateFake(tip)
end

local function RenderPlayer()
    tip:ClearLines()
    -- 真管線：SetUnit → ProcessInfo → Unit post-call（UnitLines / 邊框 / 背景全套）
    pcall(tip.SetUnit, tip, "player")
    ns.Bar.Activate(tip, "player")
end

local function RenderItem()
    tip:ClearLines()
    ns.Bar.Deactivate(tip)
    -- 物品資料非同步：沒快取時先畫（引擎會顯示讀取中），掛 ContinueOnItemLoad
    -- 到貨重繪。⚠ 只在「未快取」時掛——快取好時 Continue 會立刻執行，
    -- 掛在重繪路徑上會變成自我迴圈。
    if C_Item and C_Item.IsItemDataCachedByID and Item and Item.CreateFromItemID
        and not C_Item.IsItemDataCachedByID(PREVIEW_ITEM_ID) then
        Item:CreateFromItemID(PREVIEW_ITEM_ID):ContinueOnItemLoad(function()
            if enabled and mode == "item" then
                Preview.Refresh()
            end
        end)
    end
    if tip.SetItemByID then
        pcall(tip.SetItemByID, tip, PREVIEW_ITEM_ID)
    else
        pcall(tip.SetHyperlink, tip, "item:" .. PREVIEW_ITEM_ID)
    end
end

local function RenderSpell()
    tip:ClearLines()
    ns.Bar.Deactivate(tip)
    pcall(tip.SetSpellByID, tip, PREVIEW_SPELL_ID)
end

------------------------------------------------------------
-- 開關與重繪。預覽住在設定視窗的左欄（模式 chip 在上、tooltip 在下），
-- 右欄表單捲動時它固定不動。
------------------------------------------------------------
local function Position()
    local panel = ns.Options and ns.Options.panel
    if not panel then return end
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -46)
    chipHolder:ClearAllPoints()
    chipHolder:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
end

function Preview.Refresh()
    if not tip or not ns.db or not enabled then return end
    -- SetOwner 會清空內容，所以每次重繪都重新 SetOwner 再填
    local panel = ns.Options and ns.Options.panel
    if not panel then return end
    pcall(tip.SetOwner, tip, panel, "ANCHOR_NONE")
    if mode == "npc" then
        RenderNpc()
    elseif mode == "item" then
        RenderItem()
    elseif mode == "spell" then
        RenderSpell()
    else
        RenderPlayer()
    end
    tip:Show()
    Position()
end

local function SetMode(newMode, chip)
    mode = newMode
    if highlightChip and chip then highlightChip(chip) end
    Preview.Refresh()
end

local function Ensure()
    if tip then return end
    local panel = ns.Options.panel
    -- 掛在面板底下：跟著開關、層級壓在面板底框之上（skin 會自己排到 tip−1）
    tip = CreateFrame("GameTooltip", "MiliUITip_Preview", panel, "GameTooltipTemplate")
    tip:SetFrameLevel(panel:GetFrameLevel() + 20)
    ns.TrackTip(tip)

    chipHolder = CreateFrame("Frame", nil, panel)
    chipHolder:SetSize(260, 22)
    local chips = {}
    local defs = {
        { id = "player", label = L["Player"] },
        { id = "npc",    label = "NPC" },
        { id = "item",   label = L["Item"] },
        { id = "spell",  label = L["Spell"] },
    }
    local prev
    for i, def in ipairs(defs) do
        local b = W.CreateButton(chipHolder, def.label, "accent-hover", 60, 20)
        b.id = def.id
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 3, 0)
        else
            b:SetPoint("LEFT", chipHolder, "LEFT", 0, 0)
        end
        prev = b
        chips[i] = b
    end
    highlightChip = W.CreateButtonGroup(chips, function(id, chip)
        SetMode(id, chip)
    end)
    for _, chip in ipairs(chips) do
        chipsById[chip.id] = chip
    end
    highlightChip(chips[1])
    chipHolder:Hide()
end

function Preview.Open()
    Ensure()
    -- 可見性交給 SetForTab：Panel.Open 顯示視窗後緊接著 ShowTab 就會進來
end

------------------------------------------------------------
-- 預覽跟著頂層分頁走：玩家／NPC／物品與ID 各鎖定對應模式（不顯示切換鈕），
-- 樣式分頁保留三顆切換鈕自由看，其他分頁整個收起來。
------------------------------------------------------------
local FIXED_MODE = { player = "player", npc = "npc", extra = "item" }

function Preview.SetForTab(tabId)
    if tabId == "general" or FIXED_MODE[tabId] then
        Ensure()
        enabled = true
        if FIXED_MODE[tabId] then
            mode = FIXED_MODE[tabId]
            chipHolder:Hide()
        else
            chipHolder:Show()
        end
        if highlightChip and chipsById[mode] then
            highlightChip(chipsById[mode])
        end
        Preview.Refresh()
    else
        enabled = false
        if tip then
            ns.Bar.Deactivate(tip)
            tip:Hide()
            chipHolder:Hide()
        end
    end
end

ns.RegisterCallback("ShowOptionsTab", "previewTab", function(id)
    Preview.SetForTab(id)
end)

function Preview.Close()
    enabled = false
    if not tip then return end
    ns.Bar.Deactivate(tip)
    tip:Hide()
    chipHolder:Hide()
end

ns.RegisterCallback("SettingsApplied", "preview", function()
    if tip and (ns.Options and ns.Options.panel and ns.Options.panel:IsShown()) then
        Preview.Refresh()
    end
end)
