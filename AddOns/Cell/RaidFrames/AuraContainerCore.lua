local _, Cell = ...

-- ============================================================
-- AURA CONTAINER CORE  (Cell, 12.1)
--
-- Shared plumbing for every Blizzard-driven AuraContainer in Cell. Before this
-- existed the same five things were implemented twice -- once in
-- AuraDisplay.lua and once in the (now removed) AuraContainerBridge --
-- and they had already drifted apart: two different countdown formats on the
-- same frame, and a dispel palette that only half the icons honoured.
--
-- Everything here is pure helper: no state per unit button, no events beyond the
-- one-shot capability warm-up. AuraDisplay.lua owns the containers.
-- ============================================================

local ACC = {}
Cell.AuraContainerCore = ACC

local MIN_BUILD = 120100

-- Cell paints its swipes with a plain white texture; reuse it so a container icon
-- and a legacy Cell icon can never disagree about the swipe's edge.
ACC.WHITE = "Interface\\Buttons\\WHITE8X8"

-- ============================================================
-- CAPABILITY PROBE
-- AuraContainer / AuraButton were renamed and re-cut across the 12.1 PTR builds,
-- so nothing is assumed to exist. Probing means CREATING a container, and that
-- hard-errors uncatchably in lockdown -- so a cold-cache combat call answers
-- "unsupported" WITHOUT caching, and the real probe runs at login.
-- ============================================================

local caps

local function Probe()
    local c = {
        build = select(4, GetBuildInfo()) or 0,
        auraContainer = false,
        addAuraGroup = false,
        addAuraSlot = false,
        groupLayout = false,
        maxFrameCount = false,
        flowAnchor = false,
        flowAxis = false,
        flowGrowth = false,
        dispelTexture = false,
        dispelText = false,
        filterStrings = type(AuraUtil) == "table" and type(AuraUtil.IsValidFilterString) == "function",
        shouldAurasBeSecret = type(C_Secrets) == "table" and type(C_Secrets.ShouldAurasBeSecret) == "function",
        numericFormatter = type(C_StringUtil) == "table"
            and type(C_StringUtil.CreateNumericRuleFormatter) == "function"
            and type(Enum) == "table" and type(Enum.NumericRuleFormatRounding) == "table",
    }

    if not Cell.isMidnight then return c end
    if c.build < MIN_BUILD then return c end
    if not c.filterStrings then return c end

    -- CreateFrame errors outright on an unknown intrinsic, hence the pcall
    local ok, f = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not f then return c end

    c.auraContainer = true
    c.addAuraGroup = type(f.AddAuraGroup) == "function"
    c.addAuraSlot = type(f.AddAuraSlot) == "function"
    c.groupLayout = type(f.SetAuraGroupLayout) == "function"
    c.maxFrameCount = type(f.SetAuraGroupMaxFrameCount) == "function"
    c.flowAnchor = type(f.SetFlowLayoutAnchorPoint) == "function"
        and type(f.SetFlowLayoutMaximumLineSize) == "function"
    c.flowAxis = type(f.SetFlowLayoutAxis) == "function"
        and type(AnchorUtil) == "table" and type(AnchorUtil.FlowLayoutAxis) == "table"
    c.flowGrowth = type(f.SetFlowLayoutGrowthDirection) == "function"
        and type(AnchorUtil) == "table" and type(AnchorUtil.FlowDirection) == "table"
    pcall(f.Hide, f)

    return c
end

-- nil until a probe outside combat succeeds
function ACC.GetCaps()
    if caps == nil then
        if InCombatLockdown() then return nil end
        local ok, c = pcall(Probe)
        caps = (ok and c) or {}
    end
    return caps
end

function ACC.IsSupported()
    local c = ACC.GetCaps()
    return (c and c.auraContainer and c.addAuraGroup) and true or false
end

-- one human-readable line explaining an unsupported verdict, or nil when supported
function ACC.Failure()
    local c = ACC.GetCaps()
    if not c then return "戰鬥中無法偵測（AuraContainer 只能在非戰鬥時建立）" end
    if not Cell.isMidnight then return "非 Midnight 客戶端" end
    if (c.build or 0) < MIN_BUILD then
        return ("需要 build %d 以上（目前 %d）"):format(MIN_BUILD, c.build or 0)
    end
    if not c.filterStrings then return "AuraUtil.IsValidFilterString 不存在" end
    if not c.auraContainer then return "CreateFrame(\"AuraContainer\", ...) 失敗 —— intrinsic 不存在" end
    if not c.addAuraGroup then return "AuraContainer:AddAuraGroup 不存在 —— group API 已改名或移除" end
    return nil
end

do
    local warm = CreateFrame("Frame")
    warm:RegisterEvent("PLAYER_LOGIN")
    warm:SetScript("OnEvent", function(self)
        if InCombatLockdown() then
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        self:UnregisterAllEvents()
        ACC.GetCaps()
    end)
end

-- ============================================================
-- DURATION FORMATTER
--
-- The remaining time is SECRET: we never read it, we hand Blizzard a formatter
-- and it renders the number itself. Two dead ends worth not re-walking:
--   * AbbreviatedNumberFormatter prints the RAW fractional seconds (27.4, 27.3)
--     and jitters.
--   * SecondsFormatter has no suffix-less mode; all three abbreviation levels
--     print a unit, and in zh locales all three print 「秒」.
-- NumericRuleFormatter is the only one with rounding AND a bare "%d".
--
-- Sub-second remaining renders as tenths ("0.4"); see the breakpoint comment below.
-- Thresholds are Blizzard's own promote points 91 / 5401 (NOT 60 / 3600), so
-- 61-90s still prints whole seconds exactly like the default frames do. The
-- quotient rounds UP because Blizzard's formatter sets SetCanRoundUpLastUnit.
--
-- showDuration mirrors Cell's setting:
--   true     -> always show ("45" -> "2m" -> "1h")
--   false/nil-> no text at all (caller must not bind the fontstring)
--   number N -> only under N seconds, done secret-safe as a BLANK band at N.
--               The engine samples the secret remaining time against the
--               breakpoints; we never see it. Bands at or above the blank
--               threshold are omitted -- they would shadow it.
-- ============================================================

local formatterCache = {}

function ACC.GetDurationFormatter(showDuration)
    if showDuration == false or showDuration == nil then return false end

    local key = tostring(showDuration)
    local cached = formatterCache[key]
    if cached ~= nil then return cached end

    formatterCache[key] = false

    local c = ACC.GetCaps()
    if not (c and c.numericFormatter) then return false end

    local hideAbove = type(showDuration) == "number" and showDuration or nil

    -- tenths = add the sub-second band; the seconds band then starts at 1 instead of 0.
    -- Built as one function so the whole thing can be re-attempted WITHOUT the sub-second
    -- band: a formatter that already took some breakpoints cannot be un-taken, so a retry
    -- needs a fresh one.
    local function Build(tenths)
        local down = Enum.NumericRuleFormatRounding.Down
        local up = Enum.NumericRuleFormatRounding.Up
        local f = C_StringUtil.CreateNumericRuleFormatter()
        local base = 0
        if tenths then
            -- Under a second: tenths. Without this band the seconds band's min = 1 pins the
            -- text at "1" for the whole last second -- the remaining time is secret, so
            -- nothing downstream can tell 0.9 from 0.1. Shape taken from two shipping addons
            -- that do the same (Platynator's cast text, Ayije_CDM's cooldown text): step 0.1
            -- with a "%.1f" format at threshold 0. Down-rounding matches the seconds band, so
            -- the last tenth reads "0.0" instead of briefly claiming "1.0".
            f:AddBreakpoint({ threshold = 0, step = 0.1, rounding = down, format = "%.1f" })
            base = 1
        end
        -- seconds band truncates: 45.6s remaining renders "45"
        if not hideAbove or hideAbove > base then
            f:AddBreakpoint({ threshold = base, step = 1, rounding = down, min = 1, format = "%d" })
        end
        if not hideAbove or hideAbove > 91 then
            f:AddBreakpoint({ threshold = 91, step = 1, rounding = down, min = 1, format = "%dm",
                              components = { { div = 60, rounding = up } } })
        end
        if not hideAbove or hideAbove > 5401 then
            f:AddBreakpoint({ threshold = 5401, step = 1, rounding = down, min = 1, format = "%dh",
                              components = { { div = 3600, rounding = up } } })
        end
        if hideAbove then
            f:AddBreakpoint({ threshold = hideAbove, step = 1, rounding = down, format = "" })
        end
        return f
    end

    local ok, fmt = pcall(Build, true)
    -- a client that refuses the fractional step falls back to whole seconds rather than to
    -- no formatter at all (which would hand the text back to Blizzard's own unit-suffixed one)
    if not ok or not fmt then ok, fmt = pcall(Build, false) end

    if ok and fmt then formatterCache[key] = fmt end
    return formatterCache[key]
end

-- ============================================================
-- FLOW LAYOUT
--
-- The row must flow OUT of the anchor point in the configured direction, or a
-- right-to-left indicator spills its icons off the far side of the frame.
-- maximumLineSize is a PIXEL budget along the main axis, NOT an icon count --
-- passing the count made every icon overflow its line, one per row.
--
-- Returns the anchor point the caller should pin the container with, so the
-- container sits on the same side of the anchor frame the row flows from.
--
-- opts.numPerLine wraps before `num` (the icon grid); opts.anchor is the indicator's
-- position point, which decides where the SECOND line goes. Without it every row wrapped
-- down/right, and a BOTTOM-anchored row pushed its extra lines off the frame. With it the
-- rule is the preview's (Indicators/Base.lua Icons_SetOrientation): a horizontal row
-- anchored BOTTOM* stacks upward, a vertical one anchored *RIGHT stacks leftward, and the
-- container is pinned by that corner. For one line the corner pin lands exactly where the
-- edge pin did (the anchor frame is one icon big), so only wrapped rows move.
-- ============================================================

local ORIENTATIONS = {
    ["left-to-right"] = { point = "LEFT",   axis = "Horizontal", h = "Right", v = "Down" },
    ["right-to-left"] = { point = "RIGHT",  axis = "Horizontal", h = "Left",  v = "Down" },
    ["top-to-bottom"] = { point = "TOP",    axis = "Vertical",   h = "Right", v = "Down" },
    ["bottom-to-top"] = { point = "BOTTOM", axis = "Vertical",   h = "Right", v = "Up" },
}

function ACC.ApplyFlowLayout(container, opts)
    local o = ORIENTATIONS[opts.orientation or ""] or ORIENTATIONS["left-to-right"]
    local point, h, v = o.point, o.h, o.v
    local anchor = opts.anchor
    if type(anchor) == "string" then
        if o.axis == "Horizontal" then
            local bottom = anchor:find("^BOTTOM") ~= nil
            v = bottom and "Up" or "Down"
            point = (bottom and "BOTTOM" or "TOP") .. o.point
        else
            local right = anchor:find("RIGHT$") ~= nil
            h = right and "Left" or "Right"
            point = o.point .. (right and "RIGHT" or "LEFT")
        end
    end

    local num = opts.num or 3
    if type(opts.numPerLine) == "number" and opts.numPerLine >= 1 and opts.numPerLine < num then
        num = opts.numPerLine
    end
    local spacing = opts.spacing or 0
    -- the budget is measured along the MAIN axis, so a vertical flow spends height
    local main = (o.axis == "Vertical") and (opts.height or opts.width or 20) or (opts.width or 20)
    -- half an element of slack: the line must not wrap on a rounding error
    local budget = num * main + math.max(0, num - 1) * spacing + main * 0.5

    local FD = AnchorUtil and AnchorUtil.FlowDirection
    local AX = AnchorUtil and AnchorUtil.FlowLayoutAxis

    -- ⚠ Each setter gets its OWN pcall. SetFlowLayoutAxis/GrowthDirection assert
    -- EnumUtil.IsValid internally, so one shared pcall would let a single bad call abort
    -- every setter after it -- e.g. the anchor point would silently never apply. Record
    -- what actually stuck (or "no-api") so /cab inspect can prove whether direction took.
    local dbg = { orientation = opts.orientation, anchor = anchor, point = point, budget = budget }
    local function try(name, present, fn)
        if not present then dbg[name] = "no-api"; return end
        local ok, err = pcall(fn)
        dbg[name] = ok and "ok" or ("ERR:" .. tostring(err))
    end

    try("axis",   AX and container.SetFlowLayoutAxis,            function() container:SetFlowLayoutAxis(AX[o.axis]) end)
    try("growth", FD and container.SetFlowLayoutGrowthDirection, function() container:SetFlowLayoutGrowthDirection(FD[h], FD[v]) end)
    try("anchor", container.SetFlowLayoutAnchorPoint,            function() container:SetFlowLayoutAnchorPoint(point) end)
    try("maxline",container.SetFlowLayoutMaximumLineSize,        function() container:SetFlowLayoutMaximumLineSize(budget) end)

    container._acFlowDbg = dbg
    return point
end

-- ============================================================
-- DISPEL TYPE RENDERING
--
-- The dispel school is SECRET. We never pick the colour or the art: we hand
-- Blizzard one of OUR textures plus (for colour mode) a name->colour map, and it
-- tints and shows it blind. The map comes from CellDB.debuffTypeColor -- the
-- 減益類型顏色 panel -- so every container matches the rest of Cell.
--   "Color" -> vertex-tint our texture by school (PreserveAsset)
--   "Icon"  -> Blizzard's own dispel-type icon art
-- ============================================================

local DISPEL_NAMES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }
ACC.DISPEL_NAMES = DISPEL_NAMES

-- every school named explicitly, so Blizzard never consults the player's spec
-- (processedAuraType is secretly player-relative; includeDispelTypes is not)
ACC.ALL_DISPEL_TYPES = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true }

-- The colour for a HARMFUL aura with no dispel school -- the plain red people read as
-- "debuff". Comes from Cell's own palette ("none" in the 減益類型顏色 panel, default
-- 0.8/0/0) so it tracks the user's setting like every other school does.
-- ⚠ Returns a REUSED table; read it, do not retain it.
local noDispel = { 0.8, 0, 0, 1 }
function ACC.GetNoDispelColor()
    local c = CellDB and CellDB["debuffTypeColor"] and CellDB["debuffTypeColor"]["none"]
    if type(c) == "table" and type(c.r) == "number" then
        noDispel[1], noDispel[2], noDispel[3] = c.r, c.g or 0, c.b or 0
    end
    return noDispel
end

function ACC.GetDispelColorMap()
    if not CreateColor then return nil end
    local src = CellDB and CellDB["debuffTypeColor"]
    if not src then return nil end
    local map
    for _, name in ipairs(DISPEL_NAMES) do
        local c = src[name]
        if type(c) == "table" and c.r then
            map = map or {}
            map[name] = CreateColor(c.r, c.g or 0, c.b or 0, 1)
        end
    end
    return map
end

-- AddDispelTypeTexture APPENDS, so the list is cleared once per button -- a re-bind then
-- replaces rather than stacks. Every dispel texture on a button goes through here (the
-- ring, the icon-only dispel display, the dispel badge), so whichever binds first clears.
local function AddDispelTexture(button, texture, opts)
    if button.AddDispelTypeTexture then
        if not button._dispelCleared then
            button._dispelCleared = true
            if button.ClearDispelTypeTextures then pcall(button.ClearDispelTypeTextures, button) end
        end
        return pcall(button.AddDispelTypeTexture, button, texture, opts)
    elseif button.SetAuraBorder then
        return pcall(button.SetAuraBorder, button, texture, opts) -- deprecated single-region alias
    end
    return false
end

-- The texture is shown ONLY while the aura has a dispel school, and vertex-tinted to it.
-- Callers rely on that: whatever they want an undispellable aura to look like has to be
-- drawn on a layer underneath, because this one simply will not be there.
function ACC.BindDispelTexture(button, texture, styleName)
    if not (button.AddDispelTypeTexture or button.SetAuraBorder) then return end

    local E = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    local opts = { showWhenHarmful = true, showWhenHelpful = false }
    if styleName == "Icon" then
        opts.style = (E and E.Icon) or 2
    else
        opts.style = (E and E.PreserveAsset) or 3
        opts.showIcon = false
        opts.customDispelColorMap = ACC.GetDispelColorMap()
    end

    AddDispelTexture(button, texture, opts)
end

-- The schools the player's CURRENT spec/talents can dispel, as a set -- or nil for none.
-- From Cell's own table (I.CanDispel), the one the right-bottom dispel indicator uses too.
-- It fills in a second after login and on every spec/talent change; Cell fires
-- "DispellableChanged" when it does (Indicator_DefaultSpells.lua).
function ACC.GetMyDispelTypes()
    local I = Cell.iFuncs
    if not (I and I.CanDispel) then return nil end
    local t
    for _, name in ipairs(DISPEL_NAMES) do
        if I.CanDispel(name) then
            t = t or {}
            t[name] = true
        end
    end
    return t
end

function ACC.BindDispelText(button, fontString)
    local opts = { showWhenHarmful = true, showWhenHelpful = false }
    if button.SetDispelTypeText then
        pcall(button.SetDispelTypeText, button, fontString, opts)
    elseif button.SetAuraSymbol then
        pcall(button.SetAuraSymbol, button, fontString, opts)
    end
end

-- ============================================================
-- BOSS BADGE  (Important Debuffs: 首領技能驚嘆號)
--
-- A yellow "!" with a 1px black outline in the top-left corner of the Important Debuffs
-- boss/role group's icons. Nothing here asks "is this a boss aura": the aura's flags are
-- secret. The answer is WHICH GROUP the button was created for -- that group only ever
-- holds isBossOrRoleAura debuffs -- stamped onto the button in Build's initializeFrame, the
-- same way the per-spell effect slots know their colour (see AuraDisplay.lua).
--
-- Flat colour textures sized in whole PHYSICAL pixels rather than an image: at this size a
-- scaled bitmap "!" smears into a blob, while a 2px bar and dot inside a 1px edge stay sharp.
-- The options preview draws through this same function, so the two cannot drift.
-- ============================================================

local BADGE_FILL = { 1, 0.82, 0 } -- the "!" (Blizzard's NORMAL_FONT_COLOR yellow)
local BADGE_INK  = { 0, 0, 0 }    -- its 1px outline

-- The glyph as drawn on a 22px icon, in physical pixels. Every part scales with the icon
-- (never below its minimum), so the options preview -- which zooms the whole button --
-- shows the same shape at the zoomed size instead of a fixed-size speck. The first cut
-- capped the badge at 16 physical pixels, and that is exactly what the zoomed preview showed.
--   inset  gap between the icon's outer corner and the outline
--   edge   outline thickness
--   w      "!" width; the dot is w x w
--   h      bar height
--   gap    the black between the bar and the dot
local GLYPH = { inset = {1, 1}, edge = {1, 1}, w = {2, 2}, h = {6, 4}, gap = {1, 1} } -- {base, min}

-- host      the frame the textures live on. They sit in its ARTWORK layer, so OVERLAY text
--           on the same frame (the countdown) stays readable on top of the badge.
-- anchorTo  the icon's OUTER rect, ring included; the "!" sits in its TOPLEFT corner.
-- iconSize  the icon's size in UI units (the indicator's size setting).
-- scaleRef  a frame WE own in the same scale chain -- never the AuraButton, whose subtree
--           must not be read from.
function ACC.StyleBossBadge(host, anchorTo, iconSize, scaleRef)
    local b = host.cellBossBadge
    if not b then
        b = {
            barEdge = host:CreateTexture(nil, "ARTWORK", nil, 1),
            dotEdge = host:CreateTexture(nil, "ARTWORK", nil, 1),
            bar     = host:CreateTexture(nil, "ARTWORK", nil, 2),
            dot     = host:CreateTexture(nil, "ARTWORK", nil, 2),
        }
        b.barEdge:SetColorTexture(BADGE_INK[1], BADGE_INK[2], BADGE_INK[3], 1)
        b.dotEdge:SetColorTexture(BADGE_INK[1], BADGE_INK[2], BADGE_INK[3], 1)
        b.bar:SetColorTexture(BADGE_FILL[1], BADGE_FILL[2], BADGE_FILL[3], 1)
        b.dot:SetColorTexture(BADGE_FILL[1], BADGE_FILL[2], BADGE_FILL[3], 1)
        host.cellBossBadge = b
    end

    -- one physical pixel, in UI units
    local scale = (scaleRef and scaleRef:GetEffectiveScale()) or 1
    local px = PixelUtil.GetPixelToUIUnitFactor() / scale
    local k = ((iconSize or 22) / px) / 22
    local function P(part) return math.max(part[2], math.floor(part[1] * k + 0.5)) * px end
    local inset, edge, w, h, gap = P(GLYPH.inset), P(GLYPH.edge), P(GLYPH.w), P(GLYPH.h), P(GLYPH.gap)

    b.barEdge:ClearAllPoints()
    b.barEdge:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", inset, -inset)
    b.barEdge:SetSize(w + 2 * edge, h + 2 * edge)
    b.bar:ClearAllPoints()
    b.bar:SetPoint("TOPLEFT", b.barEdge, "TOPLEFT", edge, -edge)
    b.bar:SetSize(w, h)
    -- placed so the two outlines OVERLAP: what separates the yellow bar from the yellow dot
    -- is exactly `gap` of black, not two outlines stacked
    b.dotEdge:ClearAllPoints()
    b.dotEdge:SetPoint("TOPLEFT", b.barEdge, "TOPLEFT", 0, -(h + gap))
    b.dotEdge:SetSize(w + 2 * edge, w + 2 * edge)
    b.dot:ClearAllPoints()
    b.dot:SetPoint("TOPLEFT", b.dotEdge, "TOPLEFT", edge, -edge)
    b.dot:SetSize(w, w)
end

function ACC.SetBossBadgeShown(host, shown)
    local b = host and host.cellBossBadge
    if not b then return end
    for _, tex in pairs(b) do tex:SetShown(shown) end
end

-- ============================================================
-- DISPEL BADGE  (Important Debuffs: 可驅散加號)
--
-- A white "+" with a 1px black outline in the top-right corner, on any icon whose debuff
-- the player's current spec can dispel -- mirrored against the boss "!" on the left.
-- The ring already says WHICH school; the "+" says "you can deal with this", so it is white
-- rather than school-coloured (and stays readable on any ring).
--
-- Unlike the boss badge this needs no group: it is decided per aura, by Blizzard, blind.
-- Every piece is an AddDispelTypeTexture (shown only while the aura has a school), and the
-- colour map paints the pieces white/black for the player's schools and fully TRANSPARENT
-- for the rest. So it works in every category of the display -- a dispellable boss debuff
-- wears both marks. The map is copied into the button at bind time, which is why the
-- school set is part of the container config: a spec change rebuilds.
-- ============================================================

-- The "+" on a 22px icon, in physical pixels, scaled like GLYPH above. arm/thick are forced
-- EVEN so the cross centres on a pixel boundary.
local PLUS = { inset = {1, 1}, edge = {1, 1}, arm = {6, 4}, thick = {2, 2} } -- {base, min}

local function EvenPx(part, k)
    return math.max(part[2], 2 * math.floor(part[1] * k / 2 + 0.5))
end

-- Creates (once) and lays out the four pieces. Plain colours: this is all the options
-- preview needs, and the in-game badge is this plus BindDispelBadge.
function ACC.StyleDispelBadge(host, anchorTo, iconSize, scaleRef)
    local b = host.cellDispelBadge
    if not b then
        b = {
            hEdge = host:CreateTexture(nil, "ARTWORK", nil, 1),
            vEdge = host:CreateTexture(nil, "ARTWORK", nil, 1),
            h     = host:CreateTexture(nil, "ARTWORK", nil, 2),
            v     = host:CreateTexture(nil, "ARTWORK", nil, 2),
        }
        -- WHITE bases: in game Blizzard vertex-tints these through the colour map, and white
        -- times the map colour is exactly the map colour.
        -- Born HIDDEN: once bound, the engine shows them per aura; if a bind is ever refused
        -- they must not sit there as a permanent white "+" on every icon.
        for _, tex in pairs(b) do
            tex:SetColorTexture(1, 1, 1, 1)
            tex:Hide()
        end
        b.hEdge:SetVertexColor(BADGE_INK[1], BADGE_INK[2], BADGE_INK[3], 1)
        b.vEdge:SetVertexColor(BADGE_INK[1], BADGE_INK[2], BADGE_INK[3], 1)
        host.cellDispelBadge = b
    end

    local scale = (scaleRef and scaleRef:GetEffectiveScale()) or 1
    local px = PixelUtil.GetPixelToUIUnitFactor() / scale
    local k = ((iconSize or 22) / px) / 22
    local inset = math.max(PLUS.inset[2], math.floor(PLUS.inset[1] * k + 0.5))
    local edge = math.max(PLUS.edge[2], math.floor(PLUS.edge[1] * k + 0.5))
    local arm, thick = EvenPx(PLUS.arm, k), EvenPx(PLUS.thick, k)
    if thick >= arm then arm = thick + 2 end

    -- every piece is centred on one point, (inset + edge + arm/2) in from the TOPRIGHT corner
    local c = (inset + edge + arm / 2) * px
    local function Place(tex, w, h)
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", anchorTo, "TOPRIGHT", -c, -c)
        tex:SetSize(w * px, h * px)
    end
    Place(b.hEdge, arm + 2 * edge, thick + 2 * edge)
    Place(b.vEdge, thick + 2 * edge, arm + 2 * edge)
    Place(b.h, arm, thick)
    Place(b.v, thick, arm)
end

-- Preview only. In game the engine owns Shown (it is a secret aspect once bound).
function ACC.SetDispelBadgeShown(host, shown)
    local b = host and host.cellDispelBadge
    if not b then return end
    for _, tex in pairs(b) do tex:SetShown(shown) end
end

-- In game: hand the four pieces to Blizzard. Call from initializeFrame only (binds are
-- refused on a live button once auras are secret); true when every piece bound.
-- dispelTypes = the player's school set (ACC.GetMyDispelTypes()).
function ACC.BindDispelBadge(button, host, dispelTypes)
    local b = host and host.cellDispelBadge
    if not (b and button.AddDispelTypeTexture and CreateColor) then return false end

    local E = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    local clear = CreateColor(1, 1, 1, 0)
    local ink = CreateColor(BADGE_INK[1], BADGE_INK[2], BADGE_INK[3], 1)
    local white = CreateColor(1, 1, 1, 1)
    -- EVERY school gets an entry: a school missing from the map keeps the engine's own school
    -- tint (PreserveAsset), which would put a coloured "+" on a debuff you cannot dispel
    local inkMap, whiteMap = {}, {}
    for _, name in ipairs(DISPEL_NAMES) do
        local mine = dispelTypes and dispelTypes[name]
        inkMap[name] = mine and ink or clear
        whiteMap[name] = mine and white or clear
    end
    local function Opts(map)
        return { style = (E and E.PreserveAsset) or 3, showIcon = false,
                 showWhenHarmful = true, showWhenHelpful = false, customDispelColorMap = map }
    end

    local ok = true
    for _, key in ipairs({ "hEdge", "vEdge" }) do
        if not AddDispelTexture(button, b[key], Opts(inkMap)) then ok = false end
    end
    for _, key in ipairs({ "h", "v" }) do
        if not AddDispelTexture(button, b[key], Opts(whiteMap)) then ok = false end
    end
    return ok
end

-- ============================================================
-- FONT
-- Cell's font tables are {face, size, outline, shadow, anchor, xOffset, yOffset,
-- color}. I.SetFont is the canonical applier (pixel-perfect points, justify,
-- colour) -- going around it is how the old bridge ended up with its own
-- LibSharedMedia lookup and a different idea of "centered".
-- ============================================================

function ACC.ApplyFont(fs, anchorTo, f, forceCenter)
    if not (fs and f) then return end
    local SetFont = Cell.iFuncs and Cell.iFuncs.SetFont
    if not SetFont then return end
    if forceCenter then
        -- Midnight centers countdown text on the icon (Base.lua ApplyCountdownFont);
        -- that is why the duration font option has no offset controls.
        SetFont(fs, anchorTo, f[1], f[2], f[3], f[4], "CENTER", 0, 0, f[8])
    else
        -- ⚠ f[5..7] = anchor/x/y. A FLAT font (the text indicator's {name,size,outline,shadow})
        -- has none, and SetFont's internal fs:SetPoint(nil,...) THROWS -- which aborts the whole
        -- StyleButton pass. Default to a corner so a flat font degrades instead of crashing.
        SetFont(fs, anchorTo, f[1], f[2], f[3], f[4], f[5] or "BOTTOMRIGHT", f[6] or 0, f[7] or 0, f[8])
    end
end

return ACC
