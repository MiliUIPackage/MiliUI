local addonName, ns = ...
local L = ns.L

local ICON_SIZE   = 34
local ICON_SPACE  = 5
local PADDING     = 6
local GRIP_WIDTH  = 12
local BADGE_SCALE = 1     -- quality star drawn at its native atlas size
local NONE_ICON   = "Interface\\RaidFrame\\ReadyCheck-NotReady"  -- red prohibition mark
local SEL_R, SEL_G, SEL_B = 1, 0.82, 0                            -- yellow selected border

-- MiliUI house "borderless" look: 1px pixel border + dark translucent fill.
local MILIUI_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

-- Secure pre-click snippet wrapped onto every selector's OnClick. On LEFT click
-- it points the shared use button at this selector's pre-stored "potionref"
-- (empty = clear = no potion). It runs in the restricted environment, so it is
-- legal in combat. RIGHT click falls through to the button's own type2 "item"
-- action (direct use), which is configured per the rightClickUse option.
local SELECT_PREBODY = [[
    if button == "LeftButton" then
        local use = self:GetFrameRef("use")
        if use then
            local ref = self:GetAttribute("potionref")
            if ref and ref ~= "" then
                use:SetAttribute("pressAndHoldAction", true)
                use:SetAttribute("type", "item")
                use:SetAttribute("item", ref)
                use:SetAttribute("typerelease", "item")
                use:SetAttribute("itemrelease", ref)
                use:SetAttribute("type1", "item")
                use:SetAttribute("item1", ref)
            else
                use:SetAttribute("type", nil)
                use:SetAttribute("item", nil)
                use:SetAttribute("typerelease", nil)
                use:SetAttribute("itemrelease", nil)
                use:SetAttribute("type1", nil)
                use:SetAttribute("item1", nil)
            end
        end
    end
]]

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
-- The quality star, taken from the SAME source Blizzard uses on bag item
-- buttons (C_TradeSkillUI.GetItemReagentQualityInfo().iconInventory), so it
-- always matches the in-game icon instead of guessing a tier from rank.
-- Returns the atlas name and its native width/height (nil if no quality).
-- An item's quality atlas never changes, so cache fully-resolved results
-- (leaving unresolved items to retry once their data loads).
local qualityAtlasCache = {}
local function GetQualityAtlas(itemID)
    local c = qualityAtlasCache[itemID]
    if c then return c[1], c[2], c[3] end
    if not (C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityInfo) then
        return nil
    end
    local info = C_TradeSkillUI.GetItemReagentQualityInfo(itemID)
    local atlas = info and info.iconInventory
    if not atlas then return nil end
    local atlasInfo = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if not atlasInfo then return nil end
    qualityAtlasCache[itemID] = { atlas, atlasInfo.width, atlasInfo.height }
    return atlas, atlasInfo.width, atlasInfo.height
end

local function SetIcon(tex, itemID)
    local icon = (C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID))
        or (GetItemIcon and GetItemIcon(itemID))
        or ns.FALLBACK_ICON
    tex:SetTexture(icon)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function GetItemCD(itemID)
    if C_Item and C_Item.GetItemCooldown then
        return C_Item.GetItemCooldown(itemID)
    elseif GetItemCooldown then
        return GetItemCooldown(itemID)
    end
    return 0, 0, 0
end

-- The bar's full (expanded) width, regardless of current collapse state — used
-- to center the bar so collapse always shrinks within the same footprint.
local function ExpandedWidth()
    local n = #(ns.available or {}) + 1  -- all variants + the "no potion" cell
    local iconsWidth = n * ICON_SIZE + (n - 1) * ICON_SPACE
    return PADDING * 2 + GRIP_WIDTH + 4 + iconsWidth
end

-- Anchor the bar by its LEFT edge. x/y = nil auto-places once (centered using
-- the full expanded width, ~18% up from the bottom). Because the anchor is the
-- left edge, every width change grows/shrinks to the RIGHT and the selected cell
-- stays put on the left. Auto-place waits until items are scanned (so the
-- centering uses the real expanded width).
local DEFAULT_Y_FRACTION = 0.10
local function PositionBar()
    if not ns.bar then return end
    local db = ns.GetDB()
    if #(ns.available or {}) > 0 then
        if not db.bar.x then
            db.bar.x = math.max(0, math.floor((UIParent:GetWidth() - ExpandedWidth()) / 2))
        end
        if not db.bar.y then
            db.bar.y = math.floor(UIParent:GetHeight() * DEFAULT_Y_FRACTION)
        end
    end
    ns.bar:ClearAllPoints()
    ns.bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.bar.x or 0, db.bar.y or 220)
end
ns.Bar_Position = PositionBar

-- Save the dragged position as the bar's actual left/bottom edge (geometry),
-- then re-anchor by that edge so it stays left-aligned.
local function SavePosition(bar)
    local x, y = bar:GetLeft(), bar:GetBottom()
    if not (x and y) then return end
    local db = ns.GetDB()
    db.bar.x, db.bar.y = x, y
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

-- Grip triangle direction: ▶ (right) when collapsed → click to expand;
-- ◀ (left) when expanded → click to collapse. The base texture points right,
-- so the left direction is just a horizontal flip.
function ns.Bar_UpdateGripArrow()
    local tex = ns.gripArrow
    if not tex then return end
    if ns.GetDB().collapsed then
        tex:SetTexCoord(0, 1, 0, 1)   -- ▶
    else
        tex:SetTexCoord(1, 0, 0, 1)   -- ◀ (flipped)
    end
end

----------------------------------------------------------------------
-- A selector button (secure). The macro is fired separately; clicking a
-- selector only points the shared use button at this item (in or out of
-- combat) via the secure snippet, then the insecure hook updates saved-vars
-- and visuals.  isNone = the red "don't use a potion" selector.
----------------------------------------------------------------------
local function CreateSelector(parent, isNone)
    local btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    -- Register both edges: the OnClick is wrapped, which drops the secure-action
    -- flag, so the type2 "use" resolves like a keypress (fire-on-down with the
    -- default cvar). Registering both edges makes it fire exactly once either way.
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn.isNone = isNone

    -- Secure wiring (only ever done out of combat: at creation / OOC layout).
    -- Left-click select runs in the restricted environment via the wrapped
    -- pre-snippet; right-click "use this item" is the button's own type2 action,
    -- enabled per-variant in the layout pass when rightClickUse is on.
    SecureHandlerSetFrameRef(btn, "use", ns.button)
    SecureHandlerWrapScript(btn, "OnClick", btn, SELECT_PREBODY)
    if isNone then
        btn:SetAttribute("potionref", "")  -- empty = clear the use button
    end

    btn.border = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
    btn.border:SetPoint("TOPLEFT", -2, 2)
    btn.border:SetPoint("BOTTOMRIGHT", 2, -2)
    btn.border:SetColorTexture(SEL_R, SEL_G, SEL_B, 1)
    btn.border:Hide()

    -- Opaque dark fill for the "no potion" cell. Drawn ABOVE the selected border
    -- (and inset 1px like a potion icon) so a selected X shows only a yellow
    -- frame over a black slot, not a solid yellow block.
    btn.slotBg = btn:CreateTexture(nil, "BACKGROUND", nil, 2)
    btn.slotBg:SetPoint("TOPLEFT", 1, -1)
    btn.slotBg:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.slotBg:SetColorTexture(0.05, 0.05, 0.07, 1)
    btn.slotBg:Hide()

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)

    -- Cooldown swirl (like the built-in action bar). Insecure child frame, so
    -- updating it is safe in combat. Driven by ns.Bar_UpdateCooldowns.
    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.icon)
    btn.cooldown:SetDrawEdge(false)
    btn.cooldown:Hide()

    -- Count + quality badge live on an overlay above the cooldown, so they stay
    -- readable while the cooldown swirl is drawn.
    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(btn.cooldown:GetFrameLevel() + 5)

    btn.count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    btn.count:SetPoint("BOTTOMRIGHT", -1, 2)

    btn.badge = overlay:CreateTexture(nil, "OVERLAY")
    btn.badge:SetPoint("TOPLEFT", -3, 3)
    btn.badge:Hide()

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetPoint("TOPLEFT", 1, -1)
    btn.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.highlight:SetColorTexture(1, 1, 1, 0.15)

    if isNone then
        btn.slotBg:Show()
        btn.icon:SetTexture(NONE_ICON)
        btn.icon:SetTexCoord(0, 1, 0, 1)
        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("TOPLEFT", 4, -4)
        btn.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    end

    -- Insecure half of a LEFT click (runs after the secure snippet; combat-safe).
    -- Both click edges fire OnClick, so act once on the up edge. Right click only
    -- performs the secure item use; no saved-var change.
    btn:HookScript("OnClick", function(self, mouseButton, down)
        if down then return end
        if mouseButton ~= "LeftButton" then return end
        if self.isNone then
            ns.OnSelectNone()
        elseif self.itemID then
            ns.OnSelect(self.itemID)
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local db = ns.GetDB()
        if self.isNone then
            GameTooltip:SetText(L.TIP_NONE)
        elseif db.showItemTooltip and self.itemID then
            -- Full item tooltip, then the action hints underneath.
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.TIP_SELECT, 0.7, 0.7, 0.7)
            if db.rightClickUse then
                GameTooltip:AddLine(L.TIP_USE, 0.7, 0.7, 0.7)
            end
        else
            GameTooltip:SetText(L.TIP_SELECT)
            if db.rightClickUse then
                GameTooltip:AddLine(L.TIP_USE)
            end
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    return btn
end

----------------------------------------------------------------------
-- Bar
----------------------------------------------------------------------
function ns.CreateBar()
    if ns.bar then
        return ns.bar
    end
    local db = ns.GetDB()

    local bar = CreateFrame("Frame", "MiliUI_BurstPotionHelperBar", UIParent, "BackdropTemplate")
    ns.bar = bar
    bar:SetSize(120, PADDING * 2 + ICON_SIZE)
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.bar.x or 0, db.bar.y or 220)
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:SetBackdrop(MILIUI_BACKDROP)
    bar:SetBackdropColor(0.06, 0.06, 0.10, 0.92)
    bar:SetBackdropBorderColor(0, 0, 0, 1)

    -- Drag grip (left). Left-drag to move, right-click for settings.
    local grip = CreateFrame("Frame", nil, bar)
    grip:SetPoint("TOPLEFT", 4, -4)
    grip:SetPoint("BOTTOMLEFT", 4, 4)
    grip:SetWidth(GRIP_WIDTH)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    ns.grip = grip

    -- Directional triangle: points right (▶) when collapsed, left (◀) when
    -- expanded. Filled triangle texture, tinted to the grip's usual color.
    local gripTex = grip:CreateTexture(nil, "ARTWORK")
    gripTex:SetPoint("CENTER")
    gripTex:SetSize(9, 14)
    gripTex:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    gripTex:SetVertexColor(0.6, 0.65, 0.75, 0.8)
    ns.gripArrow = gripTex
    ns.Bar_UpdateGripArrow()

    -- Left = collapse/expand (a click), or move (a drag); right = settings.
    -- _moved distinguishes a drag from a click so a move doesn't also toggle.
    grip:SetScript("OnMouseDown", function(_, mouseButton)
        if mouseButton == "LeftButton" then grip._moved = false end
    end)
    grip:SetScript("OnDragStart", function()
        if not ns.GetDB().lockBar then
            grip._moved = true
            bar:StartMoving()
        end
    end)
    grip:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        SavePosition(bar)
    end)
    grip:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "RightButton" then
            ns.OpenSettings()
        elseif mouseButton == "LeftButton" and not grip._moved then
            ns.Bar_ToggleCollapse()
        end
    end)
    grip:SetScript("OnEnter", function()
        GameTooltip:SetOwner(grip, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.SETTINGS_TITLE)
        GameTooltip:AddLine(L.TIP_COLLAPSE, 0.8, 0.8, 0.8)
        if ns.GetDB().lockBar then
            GameTooltip:AddLine(L.TIP_LOCKED, 1, 0.5, 0.5)
        else
            GameTooltip:AddLine(L.TIP_DRAG, 0.8, 0.8, 0.8)
        end
        GameTooltip:AddLine(L.TIP_SETTINGS, 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", GameTooltip_Hide)

    local iconRow = CreateFrame("Frame", nil, bar)
    iconRow:SetPoint("LEFT", grip, "RIGHT", 4, 0)
    iconRow:SetHeight(ICON_SIZE)
    ns.iconRow = iconRow
    ns.buttons = {}

    -- Persistent "no potion" selector.
    ns.noneButton = CreateSelector(iconRow, true)

    ns.Bar_Refresh()
    return bar
end

-- True when the bar should be visible: enabled + at least one potion to pick.
local function ShouldShow()
    return ns.GetDB().showBar and (#(ns.available or {}) > 0)
end

-- Visibility is only changed out of combat (the bar hosts protected children).
local function ApplyVisible()
    if ns.bar then ns.bar:SetShown(ShouldShow()) end
end

-- Border-only update. Safe in combat (only touches textures).
-- The selected-highlight frame is hidden while collapsed (only one cell shows,
-- so it is redundant) and shown only when expanded. Keys off ns.appliedCollapsed
-- (the actually-displayed state) rather than db.collapsed, so a collapse toggle
-- deferred during combat doesn't desync the border from what's on screen.
function ns.Bar_UpdateSelection()
    if not ns.bar then return end
    local db = ns.GetDB()
    local showBorder = not ns.appliedCollapsed
    local selected = (not db.disabled) and ns.GetSelected() or nil
    for _, btn in ipairs(ns.buttons) do
        btn.border:SetShown(showBorder and selected ~= nil and btn.itemID == selected)
    end
    if ns.noneButton then
        ns.noneButton.border:SetShown(showBorder and db.disabled == true)
    end
end

-- Cooldown swirls (like the built-in action bar). Reads each item's (category)
-- cooldown by itemID and feeds its Cooldown frame. Touches only insecure
-- cooldown widgets, so it is safe to call in combat (when you drink mid-fight).
function ns.Bar_UpdateCooldowns()
    if not ns.bar then return end
    local show = ns.GetDB().showCooldown
    if not show then
        -- Clear the swirls once when turned off, then ignore later cooldown
        -- events entirely (fresh/pooled buttons start with no swirl anyway).
        if ns.cooldownsShown then
            for _, btn in ipairs(ns.buttons or {}) do
                if btn.cooldown then CooldownFrame_Set(btn.cooldown, 0, 0, 0) end
            end
            ns.cooldownsShown = false
        end
        return
    end
    for _, btn in ipairs(ns.buttons or {}) do
        if btn.cooldown then
            if btn.itemID and btn:IsShown() then
                local start, duration, enable = GetItemCD(btn.itemID)
                CooldownFrame_Set(btn.cooldown, start or 0, duration or 0, enable or 0)
            else
                CooldownFrame_Set(btn.cooldown, 0, 0, 0)
            end
        end
    end
    ns.cooldownsShown = true
end

-- Full layout: positions buttons, refreshes icons, and (re)writes the secure
-- attributes. All of this is protected, so it runs OUT OF COMBAT only. In
-- combat we fall back to a texture-only selection refresh.
function ns.Bar_Refresh()
    if not ns.bar then return end
    if InCombatLockdown() then
        ns.Bar_UpdateSelection()
        return
    end

    local db = ns.GetDB()
    local available = ns.available or {}
    ns.buttons = ns.buttons or {}

    -- When collapsed, only the currently-selected cell stays visible.
    local collapsed = db.collapsed
    local selected = (not db.disabled) and ns.GetSelected() or nil

    -- Configure + show/hide each variant button; collect the ones to display.
    local cells = {}
    for index, entry in ipairs(available) do
        local btn = ns.buttons[index]
        if not btn then
            btn = CreateSelector(ns.iconRow, false)
            ns.buttons[index] = btn
        end

        local itemID = entry.id
        btn.itemID = itemID
        btn.isNone = false

        local ref = ns.GetItemRef(itemID)
        btn:SetAttribute("potionref", ref)           -- left-click select target
        if db.rightClickUse then
            btn:SetAttribute("type2", "item")        -- right-click = drink this one
            btn:SetAttribute("item2", ref)
        else
            btn:SetAttribute("type2", nil)
            btn:SetAttribute("item2", nil)
        end

        SetIcon(btn.icon, itemID)

        -- Quality star: the item's real quality icon, scaled by BADGE_SCALE.
        local atlas, aw, ah = GetQualityAtlas(itemID)
        if atlas then
            btn.badge:SetAtlas(atlas)
            btn.badge:SetSize(aw * BADGE_SCALE, ah * BADGE_SCALE)
            btn.badge:Show()
        else
            btn.badge:Hide()
        end

        btn.count:SetText(entry.count > 999 and "*" or tostring(entry.count))
        btn.count:Show()

        if (not collapsed) or (itemID == selected) then
            cells[#cells + 1] = btn
            btn:Show()
        else
            btn:Hide()
        end
    end

    for index = #available + 1, #ns.buttons do
        ns.buttons[index]:Hide()
    end

    -- "No potion" selector: always shown when expanded; when collapsed only if
    -- it is the current selection (disabled). Fallback: if collapse somehow left
    -- nothing visible, show it so the bar isn't an empty stub.
    if (not collapsed) or db.disabled or #cells == 0 then
        cells[#cells + 1] = ns.noneButton
        ns.noneButton:Show()
    else
        ns.noneButton:Hide()
    end

    -- Pack visible cells left-to-right.
    for i, cell in ipairs(cells) do
        cell:ClearAllPoints()
        cell:SetPoint("LEFT", ns.iconRow, "LEFT", (i - 1) * (ICON_SIZE + ICON_SPACE), 0)
    end

    local n = #cells
    local iconsWidth = (n > 0) and (n * ICON_SIZE + (n - 1) * ICON_SPACE) or 1
    ns.iconRow:SetWidth(iconsWidth)
    ns.bar:SetWidth(PADDING * 2 + GRIP_WIDTH + 4 + iconsWidth)

    ns.appliedCollapsed = collapsed  -- the collapse state now actually on screen
    PositionBar()  -- auto-place once items are scanned (login bag cache may be cold)
    ApplyVisible()
    ns.Bar_UpdateSelection()
    ns.Bar_UpdateCooldowns()
    ns.Bar_UpdateGripArrow()
end

-- Collapse to just the selected cell / expand back. Hiding the protected
-- selectors is combat-blocked, so a combat-time toggle is deferred to regen.
function ns.Bar_ToggleCollapse()
    local db = ns.GetDB()
    db.collapsed = not db.collapsed
    if InCombatLockdown() then
        ns.pendingApply = true
        ns.Print(ns.L.MSG_COLLAPSE_COMBAT)
    else
        ns.Bar_Refresh()
    end
end

function ns.Bar_SetShown(show)
    ns.GetDB().showBar = show and true or false
    if InCombatLockdown() then
        ns.pendingApply = true  -- visibility re-applied on leaving combat
    else
        ns.Bar_Refresh()
    end
end

-- Toggling right-click-use rewrites each selector's type2 (protected), so it
-- relayouts out of combat or defers to leaving combat.
function ns.SetRightClickUse(enabled)
    ns.GetDB().rightClickUse = enabled and true or false
    if InCombatLockdown() then
        ns.pendingApply = true
    else
        ns.Bar_Refresh()
    end
end

function ns.Bar_ResetPosition()
    local db = ns.GetDB()
    db.bar = { x = nil, y = nil, v = ns.BAR_POS_VERSION }  -- nil → PositionBar re-places at default
    PositionBar()
end
