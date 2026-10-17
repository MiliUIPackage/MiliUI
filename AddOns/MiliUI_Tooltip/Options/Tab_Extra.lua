------------------------------------------------------------
-- 「錨點」與「物品與ID」兩個分頁
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Controls = ns.Controls
local Specs = ns.Specs

------------------------------------------------------------
-- 錨點
------------------------------------------------------------
local anchorTab, anchorRefreshers

-- 跟隨游標的九宮格：中間那格是游標本身（不能點，畫一個白點），周圍八格是 tooltip 擺在游標的哪一側。
-- 存的是 tooltip 自己貼在游標上的那一點（「右下」＝TOPLEFT 貼游標），引擎直接拿去 SetPoint。
-- 畫法照 MCDM 的錨點九宮格（Options/Specs.lua 的 PointGridTS）：深底直角、選中塗職業色、滑過變亮。
local CURSOR_GRID = {
    { point = "BOTTOMRIGHT", text = L["Upper left of cursor"] },
    { point = "BOTTOM",      text = L["Above cursor"] },
    { point = "BOTTOMLEFT",  text = L["Upper right of cursor"] },
    { point = "RIGHT",       text = L["Left of cursor"] },
    false,  -- 游標
    { point = "LEFT",        text = L["Right of cursor"] },
    { point = "TOPRIGHT",    text = L["Lower left of cursor"] },
    { point = "TOP",         text = L["Below cursor"] },
    { point = "TOPLEFT",     text = L["Lower right of cursor"] },
}
local GRID_CELL, GRID_GAP, GRID_PAD = 14, 2, 4
local GRID_IDLE, GRID_HOVER = { 0.28, 0.28, 0.28, 1 }, { 0.45, 0.45, 0.45, 1 }
local GRID_CURSOR = { 0.12, 0.12, 0.12, 1 }

local function CursorGridSpec()
    local side = GRID_CELL * 3 + GRID_GAP * 2
    local spec = { type = "custom", root = "anchor", key = "cp", label = L["Cursor position"], h = side + GRID_PAD * 2 }
    spec.build = function(parent, x, y, _, ctx)
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetSize(side, side)
        holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - GRID_PAD)
        local name = parent:CreateFontString(nil, "OVERLAY")
        name:SetFontObject(W.fontSmall)
        name:SetTextColor(0.65, 0.65, 0.65)
        name:SetPoint("LEFT", holder, "RIGHT", 8, 0)
        local cells, cur = {}, nil
        local function Paint()
            local label = ""
            for _, b in ipairs(cells) do
                if b.point == cur then
                    b:SetBackdropColor(W.Accent(1))
                    label = b.text
                else
                    b:SetBackdropColor(unpack(b.hover and GRID_HOVER or GRID_IDLE))
                end
            end
            name:SetText(label)
        end
        for i, it in ipairs(CURSOR_GRID) do
            local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
            local ox, oy = col * (GRID_CELL + GRID_GAP), -row * (GRID_CELL + GRID_GAP)
            if it then
                local b = CreateFrame("Button", nil, holder, "BackdropTemplate")
                b:SetSize(GRID_CELL, GRID_CELL)
                b:SetPoint("TOPLEFT", ox, oy)
                W.Stylize(b, GRID_IDLE, { 0, 0, 0, 1 })
                b.point, b.text = it.point, it.text
                b:SetScript("OnEnter", function() b.hover = true; Paint() end)
                b:SetScript("OnLeave", function() b.hover = false; Paint() end)
                b:SetScript("OnClick", function()
                    if cur == it.point then return end
                    cur = it.point
                    ctx.set(spec, cur)
                    ctx.apply()
                    Paint()
                end)
                cells[#cells + 1] = b
            else
                local c = CreateFrame("Frame", nil, holder, "BackdropTemplate")
                c:SetSize(GRID_CELL, GRID_CELL)
                c:SetPoint("TOPLEFT", ox, oy)
                W.Stylize(c, GRID_CURSOR, { 0, 0, 0, 1 })
                local dot = c:CreateTexture(nil, "OVERLAY")
                dot:SetColorTexture(1, 1, 1, 1)
                dot:SetSize(4, 4)
                dot:SetPoint("CENTER")
            end
        end
        return spec.h, function()
            cur = ctx.get(spec) or "BOTTOM"
            Paint()
        end
    end
    return spec
end

local ANCHOR_CONTROLS = {
    { type = "header", label = L["Position"] },
    { type = "dropdown", root = "anchor", key = "position", label = L["Anchor mode"], items = Specs.ANCHOR_POSITION_ITEMS },
    CursorGridSpec(),
    { type = "numbers", root = "anchor", label = L["Cursor offset"],
      fields = { { key = "cx", label = "X" }, { key = "cy", label = "Y" } } },
    { type = "dropdown", root = "anchor", key = "p", label = L["Fixed corner"], items = Specs.STATIC_POINT_ITEMS },
    { type = "numbers", root = "anchor", label = L["Fixed offset"],
      fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
    { type = "text", label = L["Cursor position and offset only apply to \"Follow cursor\"; corner and offset only apply to \"Fixed position\", measured from that screen corner."] },

    { type = "header", label = L["In combat"] },
    { type = "toggle", root = "anchor", key = "hiddenInCombat", label = L["Hide tooltips in combat"] },
    { type = "dropdown", root = "anchor", key = "modifierShowInCombatKey", label = L["Hold to show anyway"], items = Specs.MOD_KEY_ITEMS },
    { type = "toggle", root = "anchor", key = "returnInCombat", label = L["Use fixed position in combat"] },
    { type = "toggle", root = "anchor", key = "returnOnUnitFrame", label = L["Use fixed position over unit frames"] },

    { type = "header", label = L["Behavior"] },
    { type = "toggle", root = "general", key = "hideUnitFrameHint", label = L["Hide the right-click hint line"] },
    { type = "toggle", root = "general", key = "chatHover", label = L["Show tooltips when hovering chat links"] },
}

local function InitAnchor()
    if anchorTab then return end
    local scroll
    anchorTab, scroll = ns.Options.MakeFormTab(L["Anchor"])
    local ctx = Controls.MakeCtx(function(spec)
        if spec.root == "general" then return ns.db.general end
        return ns.db.anchor
    end, ns.ApplyAll)
    local _
    _, anchorRefreshers = ns.Options.BuildScrollBody(scroll, ANCHOR_CONTROLS, ctx, 600)
end

ns.RegisterCallback("ShowOptionsTab", "anchorTab", function(id)
    if id ~= "anchor" then
        if anchorTab then anchorTab:Hide() end
        return
    end
    InitAnchor()
    for _, fn in ipairs(anchorRefreshers) do fn() end
    anchorTab:Show()
end)

------------------------------------------------------------
-- 物品與 ID
------------------------------------------------------------
local extraTab, extraRefreshers

local EXTRA_CONTROLS = {
    { type = "header", label = L["Item"] },
    { type = "toggle", root = "item", key = "coloredItemBorder", label = L["Border by item quality"] },
    { type = "toggle", root = "item", key = "showItemIcon", label = L["Item icon before the name"] },
    { type = "toggle", root = "item", key = "showItemExpansion", label = L["Expansion line"] },
    { type = "toggle", root = "item", key = "showItemMaxStack", label = L["Max stack size"] },
    { type = "toggle", root = "item", key = "showItemId", label = L["Item ID"] },
    { type = "toggle", root = "item", key = "showItemBonusId", label = L["Bonus IDs"] },
    { type = "toggle", root = "item", key = "showItemEnhancementId", label = L["Enhancement ID"] },
    { type = "toggle", root = "item", key = "showItemGemId", label = L["Gem IDs"] },
    { type = "toggle", root = "item", key = "showItemIconId", label = L["Icon ID"] },
    { type = "toggle", root = "item", key = "modifierShowAll", label = L["Modifier key reveals everything"] },
    { type = "text", label = L["With the last option on, holding Shift / Ctrl / Alt shows every item line regardless of the toggles above."] },

    { type = "header", label = L["Spell"] },
    { type = "toggle", root = "spell", key = "showIcon", label = L["Spell icon before the name"] },
    { type = "toggle", root = "spell", key = "showSpellId", label = L["Spell ID"] },
    { type = "toggle", root = "spell", key = "showSpellIconId", label = L["Icon ID"] },
    { type = "toggle", root = "spell", key = "showMountSource", label = L["Mount source on mount auras"] },
    { type = "toggle", root = "spell", key = "modifierShowAll", label = L["Modifier key reveals everything"] },

    { type = "header", label = L["Quest"] },
    { type = "toggle", root = "quest", key = "coloredQuestBorder", label = L["Border by quest difficulty"] },
    { type = "toggle", root = "quest", key = "showQuestId", label = L["Quest ID in the quest log"] },
}

local function InitExtra()
    if extraTab then return end
    local scroll
    extraTab, scroll = ns.Options.MakeFormTab(L["Item & spells"])
    local ctx = Controls.MakeCtx(function(spec)
        return ns.db[spec.root or "item"]
    end, ns.ApplyAll)
    local _
    _, extraRefreshers = ns.Options.BuildScrollBody(scroll, EXTRA_CONTROLS, ctx, 600)
end

ns.RegisterCallback("ShowOptionsTab", "extraTab", function(id)
    if id ~= "extra" then
        if extraTab then extraTab:Hide() end
        return
    end
    InitExtra()
    for _, fn in ipairs(extraRefreshers) do fn() end
    extraTab:Show()
end)
