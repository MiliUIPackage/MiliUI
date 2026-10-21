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
-- 1px 是實體像素（P.Pixel；寫死 1 在 1440p 以上是 2px），而且要在排版時才換算：
-- 條在 ADDON_LOADED 建，那時 UI 縮放還沒定。跟上次一樣就不重設；九張貼圖關像素貼齊。
-- 規則全文：.claude/notes/wow-1px-border-rules.md
local barEdgePx
local function ApplyBarBackdrop()
    local bar = ns.bar
    if not bar then return end
    local px = ns.P.Pixel(1)
    if barEdgePx == px then return end
    barEdgePx = px
    bar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = px,
    })
    ns.P.NoSnapBackdrop(bar)
    bar:SetBackdropColor(0.06, 0.06, 0.10, 0.92)
    bar:SetBackdropBorderColor(0, 0, 0, 1)
end

-- Secure pre-click snippet wrapped onto every selector's OnClick. On LEFT click
-- it hands this selector's pre-stored "potionref" (empty = no potion) to the
-- gate (Secure.lua), which points the shared use button at it — or holds it
-- back while "raid: boss fights only" is pausing trash fights. It runs in the
-- restricted environment, so it is legal in combat. RIGHT click falls through
-- to the button's own type2 "item" action (direct use, never gated), which is
-- configured per the rightClickUse option.
local SELECT_PREBODY = [[
    if button == "LeftButton" then
        local gate = self:GetFrameRef("gate")
        if gate then
            gate:SetAttribute("state-sel", self:GetAttribute("potionref") or "")
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
    local icon = C_Item.GetItemIconByID(itemID) or ns.FALLBACK_ICON
    tex:SetTexture(icon)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function GetItemCD(itemID)
    if C_Item and C_Item.GetItemCooldown then
        return C_Item.GetItemCooldown(itemID)
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

-- 磁吸註冊表裡的名字（Libs/MiliUISnap.lua）。別條插件的 db.snapTo.target 記的就是它
local SNAP_KEY = "burstPotionBar"
local function SnapDB() return ns.GetDB().bar end

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
    -- 吸在別條上的話改錨到它身上（Libs/MiliUISnap.lua）；目標不在就維持絕對座標
    if ns.Snap then ns.Snap.Restore(SNAP_KEY) end
end
ns.Bar_Position = PositionBar

-- Save the dragged position as the bar's actual left/bottom edge (geometry),
-- then re-anchor by that edge so it stays left-aligned.
local function SavePosition(bar)
    local x, y = bar:GetLeft(), bar:GetBottom()
    if not (x and y) then return end
    local db = ns.GetDB()
    db.bar.x, db.bar.y = x, y
    -- 吸著的時候錨點在別條身上，不能改回 UIParent；x/y 照存當退路
    if ns.Snap and ns.Snap.IsAttached(SNAP_KEY) then return end
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
    SecureHandlerSetFrameRef(btn, "gate", ns.gate or ns.CreateGate())
    SecureHandlerWrapScript(btn, "OnClick", btn, SELECT_PREBODY)
    if isNone then
        btn:SetAttribute("potionref", "")  -- empty = clear the use button
    end

    -- 選取框／底／圖示／滑過層彼此相接：一起關像素貼齊（P.NoSnap），不然捨入方向不同會差一格
    btn.border = ns.P.NoSnap(btn:CreateTexture(nil, "BACKGROUND", nil, 1))
    btn.border:SetPoint("TOPLEFT", -2, 2)
    btn.border:SetPoint("BOTTOMRIGHT", 2, -2)
    btn.border:SetColorTexture(SEL_R, SEL_G, SEL_B, 1)
    btn.border:Hide()

    -- Opaque dark fill for the "no potion" cell. Drawn ABOVE the selected border
    -- (and inset 1px like a potion icon) so a selected X shows only a yellow
    -- frame over a black slot, not a solid yellow block.
    btn.slotBg = ns.P.NoSnap(btn:CreateTexture(nil, "BACKGROUND", nil, 2))
    btn.slotBg:SetPoint("TOPLEFT", 1, -1)
    btn.slotBg:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.slotBg:SetColorTexture(0.05, 0.05, 0.07, 1)
    btn.slotBg:Hide()

    btn.icon = ns.P.NoSnap(btn:CreateTexture(nil, "ARTWORK"))
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

    btn.highlight = ns.P.NoSnap(btn:CreateTexture(nil, "HIGHLIGHT"))
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
            ns.AddGateTooltip(GameTooltip)
        else
            GameTooltip:SetText(L.TIP_SELECT)
            if db.rightClickUse then
                GameTooltip:AddLine(L.TIP_USE)
            end
            ns.AddGateTooltip(GameTooltip)
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
    ApplyBarBackdrop()
    if ns.Snap then
        ns.Snap.Register(SNAP_KEY, bar, {
            db = SnapDB, attach = true, label = L.BAR_NAME,
            -- Mouseover fade reads the top-level db (see DEFAULTS in Core.lua).
            fade = { db = function() return ns.GetDB() end },
        })
    end

    -- 暴雪編輯模式裡也能拖（Libs/MiliUIEditMode.lua）：選取框、手動拖曳、格線吸附、戰鬥閘在共用層。
    -- 條是保護框（secure 子按鈕）：進出編輯模式的 Show／Hide 走共用層的戰鬥閘，戰鬥中記到脫戰。
    -- 鎖定只管平常的把手，編輯模式是明確的「我要調位置」。沒有藥水時條平常藏著，進編輯模式先秀出來
    -- 讓玩家瞄得到位置，離開重跑一次 Bar_Refresh 照 ShouldShow 收回。
    if ns.MiliUIEditMode then
        local EM = ns.MiliUIEditMode
        EM.Attach(bar, {
            name        = L.BAR_NAME,
            enabled     = function() return ns.GetDB().showBar end,
            snapKey     = SNAP_KEY,
            anchorPoint = "BOTTOMLEFT",
            save        = SavePosition,
            restore     = PositionBar,
            onChange    = function(editing)
                if not ns.GetDB().showBar then return end
                EM.Write(bar, function()
                    if editing then bar:Show() else ns.Bar_Refresh() end
                end)
            end,
        })
    end

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
            if ns.Snap then ns.Snap.OnDragStart(SNAP_KEY) end   -- 拖自己＝先脫離
            bar:StartMoving()
        end
    end)
    grip:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        if ns.Snap then ns.Snap.OnDragStop(SNAP_KEY) end        -- 放手離得近就吸上去
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
        if ns.GetDB().splitByContext then
            GameTooltip:AddLine(L.TIP_CONTEXT:format(ns.ContextLabel()), 0.8, 0.8, 0.8)
        end
        ns.AddGateTooltip(GameTooltip)
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

-- "Raid: boss fights only" lines: shown only where it applies (raid), plus the
-- live "paused" state so a macro press that does nothing on trash is explained.
function ns.AddGateTooltip(tt)
    if not ns.BossOnlyActive() then return end
    tt:AddLine(L.TIP_RAID_BOSS_ONLY, 0.8, 0.8, 0.8)
    if ns.IsGatePaused() then
        tt:AddLine(L.TIP_RAID_PAUSED, 1, 0.5, 0.5)
    end
end

-- Border-only update. Safe in combat (only touches textures).
-- The selected-highlight frame is hidden while collapsed (only one cell shows,
-- so it is redundant) and shown only when expanded. Keys off ns.appliedCollapsed
-- (the actually-displayed state) rather than db.collapsed, so a collapse toggle
-- deferred during combat doesn't desync the border from what's on screen.
function ns.Bar_UpdateSelection()
    if not ns.bar then return end
    local store = ns.SelStore()
    local showBorder = not ns.appliedCollapsed
    local selected = (not store.disabled) and ns.GetSelected() or nil
    -- Paused by "raid: boss fights only" (trash in combat): the selection is
    -- kept, the potions just dim — brightness only, the colors stay the same.
    local paused = ns.IsGatePaused()
    for _, btn in ipairs(ns.buttons) do
        btn.border:SetShown(showBorder and selected ~= nil and btn.itemID == selected)
        btn.border:SetAlpha(paused and 0.4 or 1)
        btn.icon:SetDesaturated(paused)
        btn.icon:SetAlpha(paused and 0.4 or 1)
    end
    if ns.noneButton then
        ns.noneButton.border:SetShown(showBorder and store.disabled == true)
    end
end

-- Countdown time format (db.cooldownTimeFormat) for the Cooldown's built-in
-- numbers, which only show while the game's "Show Numbers for Cooldowns" is on:
--   "mmss"     (default) 2:00 and under prints m:ss (1:59), under a minute plain
--              seconds; from 2:01 whole minutes rounded up (3m), past 90 min hours
--   "minutes"  seconds up to 90, then whole minutes rounded up (2m), past 90 min hours
-- Same rules as MiliUI_CooldownManager (Core/Text.lua BuildFormatter), no decimals:
-- whole seconds round up like Blizzard's own countdown. The format switches on the
-- DISPLAYED second, but the rule thresholds compare the raw remaining time, so with
-- round-up a display of n starts at x > n - 1 (Edge); a literal n would flash the
-- old format for that last second (e.g. "2:01" between "3m" and "2:00").
local TIME_FORMATS = { minutes = true, mmss = true }
function ns.CooldownTimeFormat()
    local v = ns.GetDB().cooldownTimeFormat
    return TIME_FORMATS[v] and v or "mmss"
end

-- Minute/hour suffix follows the client: Blizzard's own cooldown countdown strings
-- (enUS "%dm"/"%dh", zhTW "%d分"/"%d小時"...). A rule feeds one number, so only a
-- string with exactly one format specifier, and that one %d, is accepted.
local function UnitFormat(name, fallback)
    local s = _G[name]
    if type(s) ~= "string" then return fallback end
    s = s:gsub("%s+", " ")
    local _, n = s:gsub("%%", "")
    if n ~= 1 or not s:find("%%d") then return fallback end
    return s
end
ns.CooldownUnitFormat = UnitFormat

local function Edge(n) return n - 1 + 0.0001 end

local function BuildCdFormatter(timeFormat)
    local SU = C_StringUtil
    local R = Enum and Enum.NumericRuleFormatRounding
    if not (SU and SU.CreateNumericRuleFormatter and R) then return nil end
    local up, down = R.Up, R.Down
    local mmss = timeFormat == "mmss"
    local minFmt = UnitFormat("COOLDOWN_DURATION_MIN", "%dm")
    local hourFmt = UnitFormat("COOLDOWN_DURATION_HOURS", "%dh")
    local rules = { { threshold = 0, step = 1, rounding = up, format = "%d" } }
    if mmss then
        -- whole seconds first (rounded up), then split into minutes (floor) and seconds
        rules[#rules + 1] = { threshold = Edge(60), step = 1, rounding = up, format = "%d:%02d",
            components = { { div = 60, step = 1, rounding = down }, { mod = 60, step = 1, rounding = down } } }
    end
    -- Round up on the RULE (step 60/3600), then a bare div: a component's rounding
    -- only applies to its own step, so { div = 60, rounding = up } alone truncated 1:59 to 1m
    rules[#rules + 1] = { threshold = Edge(mmss and 121 or 91), step = 60, rounding = up,
        format = minFmt, components = { { div = 60 } } }
    -- hours once the rounded-up minutes would pass 90 (a literal 5401 printed "91m" for a second)
    rules[#rules + 1] = { threshold = 5400 + 0.0001, step = 3600, rounding = up,
        format = hourFmt, components = { { div = 3600 } } }
    local ok, fmt = pcall(SU.CreateNumericRuleFormatter)
    if not ok or not fmt then return nil end
    for _, rule in ipairs(rules) do
        -- a half-built formatter cannot be undone: drop it and keep Blizzard's format
        if not pcall(fmt.AddBreakpoint, fmt, rule) then return nil end
    end
    return fmt
end

local cdFormatters = {}    -- [timeFormat] = formatter, or false when it couldn't be built
local function CdFormatter()
    local tf = ns.CooldownTimeFormat()
    local f = cdFormatters[tf]
    if f == nil then
        f = BuildCdFormatter(tf) or false
        cdFormatters[tf] = f
    end
    return f or nil
end

local function ApplyCdFormat(cd, fmt)
    if fmt and cd.SetCountdownFormatter and cd._timeFmt ~= fmt
        and pcall(cd.SetCountdownFormatter, cd, fmt) then
        cd._timeFmt = fmt
    end
end

-- Cooldown swirls (like the built-in action bar). Reads each item's (category)
-- cooldown by itemID and feeds its Cooldown frame. Touches only insecure
-- cooldown widgets, so it is safe to call in combat (when you drink mid-fight).
-- Also (re)applies the countdown time format; new pooled buttons get it here too
-- (Bar_Refresh ends with this call).
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
    local fmt = CdFormatter()
    for _, btn in ipairs(ns.buttons or {}) do
        if btn.cooldown then
            ApplyCdFormat(btn.cooldown, fmt)
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

    ApplyBarBackdrop()   -- 1px 邊在排版時重算（沒變就不動）

    local db = ns.GetDB()
    local available = ns.available or {}
    ns.buttons = ns.buttons or {}

    -- When collapsed, only the currently-selected cell stays visible.
    local store = ns.SelStore()
    local collapsed = db.collapsed
    local selected = (not store.disabled) and ns.GetSelected() or nil

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
    if (not collapsed) or store.disabled or #cells == 0 then
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

-- Fade settings changed: recompute now instead of waiting for the next poll.
function ns.Bar_ApplyFade()
    if ns.Snap and ns.Snap.RefreshFade then ns.Snap.RefreshFade() end
end

function ns.Bar_ResetPosition()
    local db = ns.GetDB()
    db.bar = { x = nil, y = nil, v = ns.BAR_POS_VERSION }  -- nil → PositionBar re-places at default
    PositionBar()
end

-- UI 縮放／解析度改了：1px 邊重算。條有 secure 子按鈕，戰鬥中保守不動，下一次 Bar_Refresh 會補
local scaleWatcher = CreateFrame("Frame")
scaleWatcher:RegisterEvent("UI_SCALE_CHANGED")
scaleWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
scaleWatcher:SetScript("OnEvent", function()
    if not InCombatLockdown() then ApplyBarBackdrop() end
end)
