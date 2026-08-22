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
local mode = "player"
local highlightChip

local PREVIEW_ITEM_ID = 19019   -- 雷霆之怒（橙裝，看得出品質邊框）

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
    ns.Bar.Deactivate(tip)
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
    if tip.SetItemByID then
        pcall(tip.SetItemByID, tip, PREVIEW_ITEM_ID)
    else
        pcall(tip.SetHyperlink, tip, "item:" .. PREVIEW_ITEM_ID)
    end
end

------------------------------------------------------------
-- 開關與重繪
------------------------------------------------------------
local function Position()
    local panel = ns.Options and ns.Options.panel
    if not panel then return end
    tip:ClearAllPoints()
    tip:SetPoint("TOPRIGHT", panel, "TOPLEFT", -14, -30)
    chipHolder:ClearAllPoints()
    chipHolder:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", -14, -2)
end

function Preview.Refresh()
    if not tip or not ns.db then return end
    -- SetOwner 會清空內容，所以每次重繪都重新 SetOwner 再填
    local panel = ns.Options and ns.Options.panel
    if not panel then return end
    pcall(tip.SetOwner, tip, panel, "ANCHOR_NONE")
    if mode == "npc" then
        RenderNpc()
    elseif mode == "item" then
        RenderItem()
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
    tip = CreateFrame("GameTooltip", "MiliUITip_Preview", UIParent, "GameTooltipTemplate")
    tip:SetFrameStrata("DIALOG")
    ns.TrackTip(tip)

    chipHolder = CreateFrame("Frame", nil, UIParent)
    chipHolder:SetFrameStrata("DIALOG")
    chipHolder:SetSize(190, 22)
    local chips = {}
    local defs = {
        { id = "player", label = L["Player"] },
        { id = "npc",    label = "NPC" },
        { id = "item",   label = L["Item"] },
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
    highlightChip(chips[1])
    chipHolder:Hide()
end

function Preview.Open()
    Ensure()
    chipHolder:Show()
    Preview.Refresh()
end

function Preview.Close()
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
