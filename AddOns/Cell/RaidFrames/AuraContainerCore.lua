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

-- warnSec/warnHex (optional): redden the countdown's last `warnSec` seconds. SetTextColorCurve
-- is addon-UNREACHABLE on 12.1 -- SetDurationText forwards the curve without the required
-- `property` and DurationTextBinding is private (DandersFrames live-tested @ 68569). So colour-
-- by-time rides |c escapes baked into the seconds-band format string instead, which Blizzard
-- renders blind like any other format. Only the seconds band (< 91s) can carry it.
function ACC.GetDurationFormatter(showDuration, warnSec, warnHex)
    if showDuration == false or showDuration == nil then return false end

    -- coloured and plain formatters must not share a cache slot
    local key = tostring(showDuration) .. ((warnSec and warnHex) and ("|" .. warnSec .. "|" .. warnHex) or "")
    local cached = formatterCache[key]
    if cached ~= nil then return cached end

    formatterCache[key] = false

    local c = ACC.GetCaps()
    if not (c and c.numericFormatter) then return false end

    local hideAbove = type(showDuration) == "number" and showDuration or nil
    -- valid only inside the seconds band, and never past a hide-above cutoff
    local warn = (warnSec and warnHex and warnSec > 0 and warnSec < 91
        and (not hideAbove or warnSec < hideAbove)) and warnSec or nil

    local ok, fmt = pcall(function()
        local down = Enum.NumericRuleFormatRounding.Down
        local up = Enum.NumericRuleFormatRounding.Up
        local f = C_StringUtil.CreateNumericRuleFormatter()
        -- seconds band truncates: 45.6s remaining renders "45"
        if warn then
            -- [0, warn): coloured number ; [warn, 91): plain (fontString's own colour shows)
            f:AddBreakpoint({ threshold = 0,    step = 1, rounding = down, min = 1, format = "|cff" .. warnHex .. "%d|r" })
            f:AddBreakpoint({ threshold = warn, step = 1, rounding = down, min = 1, format = "%d" })
        else
            f:AddBreakpoint({ threshold = 0, step = 1, rounding = down, min = 1, format = "%d" })
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
    end)

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
-- ============================================================

local ORIENTATIONS = {
    ["left-to-right"] = { point = "LEFT",   axis = "Horizontal", h = "Right", v = "Down" },
    ["right-to-left"] = { point = "RIGHT",  axis = "Horizontal", h = "Left",  v = "Down" },
    ["top-to-bottom"] = { point = "TOP",    axis = "Vertical",   h = "Right", v = "Down" },
    ["bottom-to-top"] = { point = "BOTTOM", axis = "Vertical",   h = "Right", v = "Up" },
}

function ACC.ApplyFlowLayout(container, opts)
    local o = ORIENTATIONS[opts.orientation or ""] or ORIENTATIONS["left-to-right"]
    local num = opts.num or 3
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
    local dbg = { orientation = opts.orientation, point = o.point, budget = budget }
    local function try(name, present, fn)
        if not present then dbg[name] = "no-api"; return end
        local ok, err = pcall(fn)
        dbg[name] = ok and "ok" or ("ERR:" .. tostring(err))
    end

    try("axis",   AX and container.SetFlowLayoutAxis,            function() container:SetFlowLayoutAxis(AX[o.axis]) end)
    try("growth", FD and container.SetFlowLayoutGrowthDirection, function() container:SetFlowLayoutGrowthDirection(FD[o.h], FD[o.v]) end)
    try("anchor", container.SetFlowLayoutAnchorPoint,            function() container:SetFlowLayoutAnchorPoint(o.point) end)
    try("maxline",container.SetFlowLayoutMaximumLineSize,        function() container:SetFlowLayoutMaximumLineSize(budget) end)

    container._acFlowDbg = dbg
    return o.point
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

    if button.AddDispelTypeTexture then
        -- APPENDS -- clear once per button so a re-bind replaces rather than stacks
        if not button._dispelCleared then
            button._dispelCleared = true
            if button.ClearDispelTypeTextures then pcall(button.ClearDispelTypeTextures, button) end
        end
        pcall(button.AddDispelTypeTexture, button, texture, opts)
    else
        pcall(button.SetAuraBorder, button, texture, opts) -- deprecated single-region alias
    end
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
        SetFont(fs, anchorTo, f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8])
    end
end

return ACC
