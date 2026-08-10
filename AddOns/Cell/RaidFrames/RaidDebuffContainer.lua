local _, Cell = ...

-- ============================================================
-- RAID DEBUFF CONTAINER  (Cell, 12.1 "Route A")
--
-- Blizzard-driven AuraContainer / AuraButton backing for Cell's central
-- "Raid Debuffs" indicator. Replaces the old spell-ID / curated-list matching:
-- in 12.1 an aura's spellId/name/duration on a teammate DEBUFF are secret, so
-- classification MUST be done Blizzard-side. We register one AuraGroup per
-- category (boss/role, priority, crowd-control, raid, dispellable) with a
-- filter string + candidateFilters; Blizzard fills + drives the buttons and
-- calls our initializeFrame to style each one. We never read spellId /
-- expirationTime / dispelName / presence -- membership IS the predicate.
--
-- Mirrors the mechanism validated in-game by Coolinator and DandersFrames v5.
-- Everything here is gated behind IsSupported(); when unsupported (Classic, or
-- the widget missing) the caller keeps Cell's existing 3-icon path. Every
-- state change is pcall-wrapped and OOC-only so a raid frame is never broken.
-- ============================================================

local RDC = {}
Cell.RaidDebuffContainer = RDC

local pcall, ipairs, pairs, next, tinsert = pcall, ipairs, pairs, next, tinsert
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local issecretvalue = issecretvalue or function() return false end

-- Blizzard filter tokens (defensive: names differ slightly across PTR builds).
local TOKEN_CC   = "CROWD_CONTROL"
local TOKEN_DISP = "RAID_PLAYER_DISPELLABLE"

-- ============================================================
-- SUPPORT GATE
-- IsSupported() == "does an AuraContainer expose AddAuraGroup". Never probe in
-- combat -- creating a live AuraContainer hard-errors uncatchably in lockdown,
-- so a cold-cache combat call returns false WITHOUT caching (re-check later).
-- ============================================================

local _supported
local function ProbeSupported()
    if not Cell.isMidnight then return false end
    local toc = select(4, GetBuildInfo())
    if type(toc) ~= "number" or toc < 120100 then return false end
    if not (AuraUtil and AuraUtil.IsValidFilterString) then return false end
    local ok, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    if not ok or not frame then return false end
    local hasGroups = type(frame.AddAuraGroup) == "function"
    pcall(function() frame:Hide() end)
    return hasGroups
end

function RDC.IsSupported()
    if _supported == nil then
        if InCombatLockdown() then return false end -- never cache a combat false
        local ok, res = pcall(ProbeSupported)
        _supported = (ok and res) and true or false
    end
    return _supported
end

-- Warm the cache once, out of combat, at login.
do
    local warm = CreateFrame("Frame")
    warm:RegisterEvent("PLAYER_LOGIN")
    warm:SetScript("OnEvent", function(self)
        if InCombatLockdown() then
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        self:UnregisterAllEvents()
        RDC.IsSupported()
    end)
end

-- ============================================================
-- CATEGORY RECORDS
-- One record -> one AuraGroup. Order = display priority (groups render in
-- declaration order and do NOT dedupe against each other, so records must be
-- mutually exclusive to avoid showing an aura twice). "Important-first": the
-- boss/role and priority records claim their auras first with NO negation, and
-- the token records (cc, raid, dispel) subtract them via candidateFilter false
-- flags. This matches DandersFrames v5's IMPORTANT-FIRST precedence.
--
-- opts (from Cell layout table) -- all boolean, default true:
--   filterBoss, filterRole, filterPriority, filterCrowdControl,
--   filterRaid, filterDispellable
-- ============================================================

-- all dispel schools, named explicitly so Blizzard never consults the player's spec
-- (DandersFrames Features/Dispel.lua: "All Dispellable must NOT depend on what the
-- player can dispel" -- processedAuraType is secretly player-relative, includeDispelTypes
-- is not).
local ALL_DISPEL_TYPES = { Magic = true, Curse = true, Disease = true, Poison = true, Bleed = true }

local function BuildRecords(opts)
    opts = opts or {}

    -- Dispel indicator mode: a single slot/record. dispelByMe (Cell's dispellableByMe):
    --   true  -> only debuffs THIS character can dispel  -> HARMFUL|RAID_PLAYER_DISPELLABLE
    --   false -> ALL dispellable debuffs                 -> HARMFUL + includeDispelTypes
    -- "overlay" = the health-bar highlight, same filter, rendered as a tint (see StyleButton).
    if opts.mode == "dispel" or opts.mode == "overlay" then
        local rec
        if opts.dispelByMe then
            rec = { key = "dispel", filter = "HARMFUL|" .. TOKEN_DISP }
        else
            rec = { key = "dispel", filter = "HARMFUL",
                    candidateFilters = { includeDispelTypes = opts.dispelTypes or ALL_DISPEL_TYPES } }
        end
        if AuraUtil.IsValidFilterString(rec.filter) then return { rec } end
        return {}
    end

    -- Buff indicator mode (defensives / externals / custom buff indicators). Friendly-unit
    -- BUFFS may be filtered by spell ID -- the 12.1 ban applies only to debuffs on friendly
    -- units -- so Cell's curated + custom spell lists carry straight over.
    --   onlyMine -> restrict to auras cast by the player ("HELPFUL|PLAYER")
    if opts.mode == "buff" then
        local ids = opts.spellIDs
        -- empty list = match nothing. A bare HELPFUL record would show EVERY buff.
        if type(ids) ~= "table" or next(ids) == nil then return {} end
        local f = opts.onlyMine and "HELPFUL|PLAYER" or "HELPFUL"
        if not AuraUtil.IsValidFilterString(f) then return {} end
        return { { key = "buff", filter = f, candidateFilters = { includeSpellIDs = ids } } }
    end

    local function on(k) local v = opts[k]; return v == nil or v end -- default true

    local boss = on("filterBoss")
    local role = on("filterRole")
    local priority = on("filterPriority")
    local cc   = on("filterCrowdControl")
    local raid = on("filterRaid")
    local disp = on("filterDispellable")

    local records = {}

    -- which important flag the boss/role record was declared with, so the
    -- lower records can subtract exactly that flag.
    local importantFlag
    if boss or role then
        importantFlag = (boss and role) and "isBossOrRoleAura"
            or (boss and "isBossAura" or "isRoleAura")
        records[#records + 1] = {
            key = "bossrole", filter = "HARMFUL",
            candidateFilters = { [importantFlag] = true },
        }
    end

    local priorityDeclared = false
    if priority then
        priorityDeclared = true
        local cf = { isPriorityAura = true }
        if importantFlag then cf[importantFlag] = false end
        records[#records + 1] = { key = "priority", filter = "HARMFUL", candidateFilters = cf }
    end

    -- subtract whichever important records were declared (fresh table each call)
    local function notImportant(extra)
        extra = extra or {}
        if importantFlag then extra[importantFlag] = false end
        if priorityDeclared then extra.isPriorityAura = false end
        return extra
    end

    if cc then
        records[#records + 1] = {
            key = "cc", filter = "HARMFUL|" .. TOKEN_CC,
            candidateFilters = notImportant(),
        }
    end
    if raid then
        -- exclude cc so a CC that also carries RAID stays in the cc record
        local f = "HARMFUL|RAID" .. (cc and ("|!" .. TOKEN_CC) or "")
        records[#records + 1] = { key = "raid", filter = f, candidateFilters = notImportant() }
    end
    if disp then
        local f = "HARMFUL|" .. TOKEN_DISP
            .. (cc and ("|!" .. TOKEN_CC) or "")
            .. (raid and "|!RAID" or "")
        records[#records + 1] = { key = "dispel", filter = f, candidateFilters = notImportant() }
    end

    -- prune records whose filter string the client rejects (unknown token)
    local out = {}
    for _, rec in ipairs(records) do
        if AuraUtil.IsValidFilterString(rec.filter) then
            out[#out + 1] = rec
        end
    end
    return out
end
RDC.BuildRecords = BuildRecords

-- ============================================================
-- BUTTON STYLING  (initializeFrame)
-- Build FRESH regions as children of the button (never reparent an existing
-- scripted widget -- forbidden-aspect inheritance blocks it). Then hand each
-- region to Blizzard's inbound setters. Never read spellId/duration/count.
-- ============================================================

-- One shared duration formatter per container: bare number countdown "45" -> "2m" -> "1h".
-- Copied verbatim from DandersFrames' proven NUMBER formatter (Features/Auras.lua
-- BuildDurationFormatter): a NumericRuleFormatter with rounding, because
-- AbbreviatedNumberFormatter renders the RAW fractional seconds (27.4, 27.3...) and
-- jitters, and SecondsFormatter has no suffix-less mode (always prints a unit; in
-- zh locales all three abbreviations print "秒").
-- Thresholds are Blizzard's promote points 91 / 5401 (NOT 60 / 3600): 61-90s still
-- prints whole seconds, matching the game's own frames. Quotient rounds UP (2m32s ->
-- "3m") because Blizzard's formatter sets SetCanRoundUpLastUnit(true).
-- Honors Cell's showDuration setting (config.showDuration):
--   true      -> always show ("45" -> "2m" -> "1h")
--   false/nil-> no duration text (fontstring never bound)
--   number N  -> only show when remaining < N seconds -- implemented secret-safe as a
--                BLANK band at threshold N (the engine evaluates the secret remaining
--                time against the breakpoints; we never read it). Bands at/above the
--                blank threshold are omitted (they would shadow it).
local function GetDurationFormatter(handle)
    if handle._durFmt ~= nil then return handle._durFmt end
    handle._durFmt = false
    local show = handle.config.showDuration
    if show == false or show == nil then return false end
    local hideAbove = type(show) == "number" and show or nil
    if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter
        and Enum and Enum.NumericRuleFormatRounding then
        local ok, f = pcall(function()
            local down = Enum.NumericRuleFormatRounding.Down
            local up = Enum.NumericRuleFormatRounding.Up
            local fmt = C_StringUtil.CreateNumericRuleFormatter()
            -- seconds band truncates: 45.6s remaining renders "45"
            fmt:AddBreakpoint({ threshold = 0, step = 1, rounding = down, min = 1, format = "%d" })
            if not hideAbove or hideAbove > 91 then
                fmt:AddBreakpoint({ threshold = 91, step = 1, rounding = down, min = 1, format = "%dm",
                                    components = { { div = 60, rounding = up } } })
            end
            if not hideAbove or hideAbove > 5401 then
                fmt:AddBreakpoint({ threshold = 5401, step = 1, rounding = down, min = 1, format = "%dh",
                                    components = { { div = 3600, rounding = up } } })
            end
            if hideAbove then
                fmt:AddBreakpoint({ threshold = hideAbove, step = 1, rounding = down, format = "" })
            end
            return fmt
        end)
        if ok and f then handle._durFmt = f end
    end
    return handle._durFmt
end

-- ============================================================
-- SHARED: dispel-type rendering
-- The dispel school is SECRET, so we never pick the colour/art ourselves -- we hand
-- Blizzard one of OUR textures plus (for colour mode) a name->colour map, and it tints
-- and shows it blind. Cell's own configurable palette (CellDB.debuffTypeColor, the
-- 減益類型顏色 panel) is what feeds customDispelColorMap, so the container matches the
-- rest of Cell. Used by: central raid-debuff border, bottom-right dispel icons.
--   style "Color" -> vertex-tint OUR texture by school (PreserveAsset)
--   style "Icon"  -> Blizzard's own dispel-type icon art (Icon)
-- ============================================================

local DISPEL_NAMES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }

local function GetCellDispelColorMap()
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

local function BindDispelTexture(button, texture, styleName)
    if not (button.AddDispelTypeTexture or button.SetAuraBorder) then return end
    local E = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    local opts = { showWhenHarmful = true, showWhenHelpful = false }
    if styleName == "Icon" then
        opts.style = (E and E.Icon) or 2
    else
        opts.style = (E and E.PreserveAsset) or 3
        opts.showIcon = false
        opts.customDispelColorMap = GetCellDispelColorMap()
    end
    if button.AddDispelTypeTexture then
        -- APPENDS -- clear once per button so a re-bind replaces rather than stacks
        if not button._dispelCleared then
            button._dispelCleared = true
            if button.ClearDispelTypeTextures then button:ClearDispelTypeTextures() end
        end
        button:AddDispelTypeTexture(texture, opts)
    else
        button:SetAuraBorder(texture, opts) -- deprecated single-region alias
    end
end

-- font tables are Cell's {face, size, outline, shadow, anchor, xOffset, yOffset, color}
local function ApplyFont(fs, anchorTo, f, forceCenter)
    if not (fs and f) then return end
    local SetFont = Cell.iFuncs and Cell.iFuncs.SetFont
    if not SetFont then return end
    if forceCenter then
        -- Midnight centers countdown text on the icon (see Base.lua ApplyCountdownFont);
        -- that is why the duration font option has no offset controls.
        SetFont(fs, anchorTo, f[1], f[2], f[3], f[4], "CENTER", 0, 0, f[8])
    else
        SetFont(fs, anchorTo, f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8])
    end
end

local function StyleButton(handle, button)
    local cfg = handle.config
    local size = cfg.size or 22
    local sizeH = cfg.sizeH or size -- cooldown indicators are 12x20, not square
    local border = cfg.border or 1

    -- click-through; tooltip opt-in
    if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
    if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
    if button.SetCollapsesLayout then button:SetCollapsesLayout(true) end
    button:SetSize(size, sizeH)

    -- BISECT: minimal styling (icon bind only, Coolinator-proven). Isolates "does the
    -- container render at this anchor at all" from the full styling/bind path.
    if handle._testMinimal then
        if not button.dfIcon then
            button.dfIcon = button:CreateTexture(nil, "ARTWORK")
            button.dfIcon:SetAllPoints(button)
        end
        if button.SetIcon and not button._boundIcon then
            button._boundIcon = true
            button:SetIcon(button.dfIcon)
        end
        tinsert(handle.buttons, button)
        return
    end

    -- OVERLAY MODE: a tint texture covering the button (positioned over the health bar),
    -- vertex-tinted by dispel type BLIND ("Color"/PreserveAsset style). This is Cell's
    -- dispel HIGHLIGHT, done the DandersFrames way -- our art, Blizzard's colour. The
    -- gradient shape comes from the texture's own alpha (SetGradient would fight the
    -- vertex tint), so a gradient look needs a gradient texture file; v1 uses a flat tint.
    if cfg.mode == "overlay" then
        local style = cfg.highlightStyle or "gradient"
        -- Cell/Media/gradient.tga = white RGB + vertical alpha ramp (opaque bottom -> fade
        -- up). Blizzard vertex-tints the RGB by school; the file's alpha is the gradient,
        -- so we never SetGradient (which would fight the tint). Solid styles use WHITE8x8.
        local isSolid = (style == "entire" or style == "current" or style == "current+")
        local tex = isSolid and "Interface\\Buttons\\WHITE8x8" or "Interface\\AddOns\\Cell\\Media\\gradient"
        if not button.dfTint then
            button.dfTint = button:CreateTexture(nil, "ARTWORK")
        end
        button.dfTint:SetTexture(tex)
        button.dfTint:SetAlpha(cfg.tintAlpha or 0.5)
        button.dfTint:ClearAllPoints()
        if style == "gradient-half" then
            -- bottom half of the bar, matching Cell's original gradient-half geometry
            button.dfTint:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT")
            button.dfTint:SetPoint("TOPRIGHT", button, "RIGHT")
        else
            button.dfTint:SetAllPoints(button)
        end
        if not button._boundTint then
            button._boundTint = true
            BindDispelTexture(button, button.dfTint, "Color")
        end
        tinsert(handle.buttons, button)
        return
    end

    -- DISPEL-ICON MODE: show ONLY the Blizzard dispel-type icon (Magic/Curse/Disease/
    -- Poison/Bleed art -- the same RaidFrame-Icon-Debuff* set Cell's "blizzard" style uses),
    -- rendered BLIND via the "Icon" texture style. No debuff spell icon / cooldown / stack.
    if cfg.dispelIcon then
        if not button.dfDispelIcon then
            button.dfDispelIcon = button:CreateTexture(nil, "ARTWORK")
            button.dfDispelIcon:SetAllPoints(button)
        end
        if not button._boundDispelIcon then
            button._boundDispelIcon = true
            BindDispelTexture(button, button.dfDispelIcon, "Icon")
        end
        tinsert(handle.buttons, button)
        return
    end

    -- icon (inset by border) -- match Cell's texcoord crop
    if not button.dfIcon then
        button.dfIcon = button:CreateTexture(nil, "ARTWORK")
        button.dfIcon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    end
    button.dfIcon:ClearAllPoints()
    button.dfIcon:SetPoint("TOPLEFT", border, -border)
    button.dfIcon:SetPoint("BOTTOMRIGHT", -border, border)

    -- 1px black border underneath the icon (BACKGROUND, drawn behind inset icon)
    if not button.dfBG then
        button.dfBG = button:CreateTexture(nil, "BACKGROUND")
        button.dfBG:SetColorTexture(0, 0, 0, 1)
        button.dfBG:SetAllPoints(button)
    end

    -- dispel-type coloured border: a WHITE texture over the whole button on the BORDER
    -- layer (above dfBG, below the inset icon), so only the border edge shows. Blizzard
    -- tints AND shows/hides it by school, blind, using Cell's 減益類型顏色 palette --
    -- non-dispellable debuffs leave it hidden and the black dfBG edge remains.
    if not button.dfDispelBorder then
        button.dfDispelBorder = button:CreateTexture(nil, "BORDER")
        button.dfDispelBorder:SetColorTexture(1, 1, 1, 1)
    end
    button.dfDispelBorder:SetAllPoints(button)
    if not button._boundDispelBorder then
        button._boundDispelBorder = true
        BindDispelTexture(button, button.dfDispelBorder, "Color")
    end

    -- cooldown swipe over the icon
    if not button.dfCD then
        button.dfCD = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        button.dfCD:SetSwipeColor(0, 0, 0, 0.8)
        button.dfCD:SetHideCountdownNumbers(true)
        button.dfCD:SetDrawEdge(false)
        button.dfCD:SetDrawBling(false)
    end
    button.dfCD:ClearAllPoints()
    button.dfCD:SetAllPoints(button.dfIcon)

    -- duration text (holder above the swipe). ⚠ The holder MUST be anchored: a frame
    -- with no points/size is rect-less, and a fontstring anchored to a rect-less frame
    -- never renders (same failure class as the rect-less raidDebuffs anchor bug).
    if not button.dfDur then
        button.dfDurHolder = CreateFrame("Frame", nil, button)
        button.dfDurHolder:SetAllPoints(button)
        button.dfDurHolder:SetFrameLevel(button:GetFrameLevel() + 6)
        button.dfDur = button.dfDurHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
        button.dfDur:SetPoint("CENTER")
    end
    -- re-applied every pass (not create-once) so font sliders are live
    ApplyFont(button.dfDur, button.dfDurHolder, cfg.durationFont, true)

    -- stack/count text
    if not button.dfStack then
        button.dfStackHolder = CreateFrame("Frame", nil, button)
        button.dfStackHolder:SetAllPoints(button)
        button.dfStackHolder:SetFrameLevel(button:GetFrameLevel() + 7)
        button.dfStack = button.dfStackHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
        button.dfStack:SetPoint("BOTTOMRIGHT", 2, -1)
    end
    ApplyFont(button.dfStack, button.dfStackHolder, cfg.stackFont)

    -- NOTE: dispel-type colored border deferred to in-game iteration -- SetAuraBorder /
    -- AddDispelTypeTexture only RECOLORS a texture you supply (it doesn't carve a ring),
    -- so a naive full-cover texture blocks the icon. Needs the border-behind-icon trick.

    -- ---- native binds (bind-once via flags) ----
    -- Direct calls, NOT pcall'd: StyleButton's caller captures errors into
    -- handle._errors so RDC.Debug()/RDC_Test() can surface the real failure
    -- instead of silently swallowing it.
    if button.dfIcon and button.SetIcon and not button._boundIcon then
        button._boundIcon = true
        button:SetIcon(button.dfIcon)
    end
    if button.dfCD and button.SetDurationCooldown and not button._boundCD then
        button._boundCD = true
        button:SetDurationCooldown(button.dfCD)
    end
    if button.dfStack and button.SetApplicationCount and not button._boundStack then
        button._boundStack = true
        -- ⚠ EMPTY opts, NEVER a formatter: Blizzard runs formatter:FormatNumber in
        -- Lua on the SECRET stack count -> throws inside ProcessDirtyFlags and
        -- bricks the container for the session.
        button:SetApplicationCount(button.dfStack, {})
    end
    if button.dfDur and button.SetDurationText and not button._boundDur then
        button._boundDur = true
        local fmt = GetDurationFormatter(handle)
        if fmt then -- false = duration text disabled (showDuration off) -> never bound
            button:SetDurationText(button.dfDur, { textFormatter = fmt })
        end
    end

    -- dispel-type COLOR border (config-driven). Blizzard vertex-tints our white texture
    -- by dispel school ("Color"/PreserveAsset style) -- blind, we never read the type.
    -- With the icon inset on top, only the edge shows = a coloured border; non-dispellable
    -- debuffs leave it unshown so the black dfBG edge remains.
    if cfg.showDispelColor and (button.AddDispelTypeTexture or button.SetAuraBorder)
        and not button._boundDispelColor then
        button._boundDispelColor = true
        if not button.dfDispelColor then
            button.dfDispelColor = button:CreateTexture(nil, "BORDER")
            button.dfDispelColor:SetColorTexture(1, 1, 1, 1)
            button.dfDispelColor:SetAllPoints(button)
        end
        local styleEnum = (Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
            and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset) or 3
        local dopts = { style = styleEnum, showWhenHarmful = true, showWhenHelpful = false, showIcon = false }
        if button.AddDispelTypeTexture then
            if button.ClearDispelTypeTextures then pcall(button.ClearDispelTypeTextures, button) end
            pcall(button.AddDispelTypeTexture, button, button.dfDispelColor, dopts)
        else
            pcall(button.SetAuraBorder, button, button.dfDispelColor, dopts)
        end
    end

    -- dispel-type SYMBOL letter (config-driven). Blizzard writes the school glyph into
    -- our fontstring, blind.
    if cfg.showDispelSymbol and (button.SetDispelTypeText or button.SetAuraSymbol)
        and not button._boundDispelSym then
        button._boundDispelSym = true
        if not button.dfSymbol then
            button.dfSymbolHolder = CreateFrame("Frame", nil, button)
            button.dfSymbolHolder:SetAllPoints(button) -- rect-less holder = invisible text
            button.dfSymbolHolder:SetFrameLevel(button:GetFrameLevel() + 8)
            button.dfSymbol = button.dfSymbolHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
            button.dfSymbol:SetPoint("CENTER")
        end
        local sopts = { showWhenHarmful = true, showWhenHelpful = false }
        if button.SetDispelTypeText then
            pcall(button.SetDispelTypeText, button, button.dfSymbol, sopts)
        else
            pcall(button.SetAuraSymbol, button, button.dfSymbol, sopts)
        end
    end

    tinsert(handle.buttons, button)
end

-- ============================================================
-- FLOW LAYOUT
-- ============================================================

local function ApplyLayout(handle)
    local c = handle.container
    if not c then return end
    local cfg = handle.config
    local size = cfg.size or 22
    local spacing = cfg.spacing or 2
    local num = cfg.num or 3

    -- centered row growing right; maximum line = num icons (pixel budget, not count)
    pcall(function()
        if c.SetFlowLayoutAnchorPoint then c:SetFlowLayoutAnchorPoint("LEFT") end
        if c.SetFlowLayoutMaximumLineSize then
            c:SetFlowLayoutMaximumLineSize(num * size + (num - 1) * spacing + size * 0.5)
        end
        if c.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
            c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
        end
    end)
    -- pin container center to our anchor frame
    pcall(function()
        c:ClearAllPoints()
        c:SetPoint("CENTER", handle.frame, "CENTER", 0, 0)
    end)
end

-- per-group cell size passed to AddAuraGroup
local function GroupLayout(cfg)
    local size = cfg.size or 22
    local spacing = cfg.spacing or 2
    return {
        elementWidth = size, elementHeight = cfg.sizeH or size,
        elementSpacing = spacing, lineSpacing = spacing, groupSpacing = 0,
    }
end

-- ============================================================
-- BUILD  (create -> SetUnit -> AddAuraGroup* -> SetEnabled LAST)
-- ============================================================

local function Build(handle)
    if handle._destroyed then return end
    if InCombatLockdown() then
        handle._pendingBuild = true
        if RDC._defer then RDC._defer(handle) end
        return
    end
    handle._pendingBuild = nil

    -- Tear down the previous native container (add-only topology -> recreate on change).
    -- ⚠ The AuraContainer carries Forbidden Aspects, so Hide()/SetParent() ON IT can be
    -- refused for a tainted caller -- and the pcall then swallows the refusal, leaving the
    -- old container rendering *underneath* the new one (the duplicated stack counts that
    -- only /reload cleared). So every build gets its own plain host frame that WE own:
    -- hiding and orphaning that is never forbidden, and it takes the container with it.
    if handle.container then
        pcall(function() handle.container:SetEnabled(false) end)
        pcall(function() handle.container:Hide() end)
        handle.container = nil
    end
    if handle.host then
        local old = handle.host
        old:Hide()
        old:SetParent(nil)
        -- verify the disposal actually took. If this ever trips, the ghost icons are NOT a
        -- teardown-order problem and RDC.Ghosts() will say so instead of us guessing.
        if old:IsShown() or old:GetParent() then
            handle._disposeFailed = (handle._disposeFailed or 0) + 1
        end
        handle.host = nil
    end
    wipe(handle.buttons)
    handle._groupKeys = nil

    if not handle.enabled or not handle.unit then return end

    local host = CreateFrame("Frame", nil, handle.frame)
    host:SetAllPoints(handle.frame)

    local ok, c = pcall(CreateFrame, "AuraContainer", nil, host, "CustomAuraContainerTemplate")
    if not ok or not c then
        host:Hide()
        host:SetParent(nil)
        return
    end
    handle.host = host
    handle.container = c
    handle._groupKeys = {}
    handle._errors = {}          -- diagnostics: per-step failures (see RDC.Debug)
    handle._initCount = 0        -- how many buttons Blizzard asked us to style
    handle._groupsAdded = 0
    handle._enabledWhileVisible = false
    handle._durFmt = nil         -- rebuild reflects current showDuration setting

    local overlay = handle.config.mode == "overlay"
    if overlay then
        -- overlay covers its anchor frame (the health bar); no flow layout
        pcall(function() c:SetAllPoints(handle.frame) end)
    else
        ApplyLayout(handle)
    end

    -- SetUnit BEFORE groups/slots
    local okU, errU = pcall(function() c:SetUnit(handle.unit) end)
    if not okU then handle._errors[#handle._errors + 1] = "SetUnit: " .. tostring(errU) end

    local records = handle.records or BuildRecords(handle.config)
    local groupLayout = GroupLayout(handle.config)
    local maxCount = handle.config.num or 3

    -- diagnostics: what filters/cf this container actually built with
    handle._recordInfo = {}
    for _, rec in ipairs(records) do
        local cfDesc = ""
        if rec.candidateFilters then
            local keys = {}
            for k in pairs(rec.candidateFilters) do keys[#keys + 1] = k end
            cfDesc = " +cf{" .. table.concat(keys, ",") .. "}"
        end
        handle._recordInfo[#handle._recordInfo + 1] = rec.key .. "=" .. rec.filter .. cfDesc
    end
    handle._modeDbg = handle.config.mode or "important"

    for _, rec in ipairs(records) do
        local initFn = function(button)
            handle._initCount = (handle._initCount or 0) + 1
            if overlay then pcall(function() button:SetAllPoints(c) end) end
            local okS, errS = pcall(StyleButton, handle, button)
            if not okS and #handle._errors < 6 then -- cap: 50 identical lines helps nobody
                handle._errors[#handle._errors + 1] = "style: " .. tostring(errS)
            end
        end
        local okG, errG
        if overlay then
            -- single slot covering the frame (AddAuraGroup eagerly batches; AddAuraSlot
            -- is the genuine single-icon/overlay primitive)
            okG, errG = pcall(c.AddAuraSlot, c, rec.key, rec.filter, {
                initializeFrame = initFn,
                candidateFilters = rec.candidateFilters,
            })
        else
            okG, errG = pcall(c.AddAuraGroup, c, rec.key, rec.filter, {
                maxFrameCount = maxCount,
                initializeFrame = initFn,
                layout = groupLayout,
                candidateFilters = rec.candidateFilters,
            })
        end
        if okG then
            handle._groupsAdded = handle._groupsAdded + 1
            -- remembered so SetNum can drive maxFrameCount live (slots are always 1)
            if not overlay then handle._groupKeys[#handle._groupKeys + 1] = rec.key end
        else
            handle._errors[#handle._errors + 1] = "Add[" .. rec.key .. "] (" .. rec.filter .. "): " .. tostring(errG)
        end
    end

    -- SetEnabled LAST (gates aura-event registration). Only "counts" if the frame is
    -- visible right now; otherwise ReassertEnable() re-runs it when the button shows.
    local okE, errE = pcall(function() c:SetEnabled(true) end)
    if not okE then handle._errors[#handle._errors + 1] = "SetEnabled: " .. tostring(errE) end
    pcall(function() c:SetShown(handle.shown ~= false) end)
    if handle.frame:IsVisible() then handle._enabledWhileVisible = true end
end

-- regen flush
do
    local regen = CreateFrame("Frame")
    regen:RegisterEvent("PLAYER_REGEN_ENABLED")
    RDC._pending = {}
    regen:SetScript("OnEvent", function()
        for h in pairs(RDC._pending) do
            RDC._pending[h] = nil
            if h._pendingBuild then Build(h) end
        end
    end)
    function RDC._defer(h) RDC._pending[h] = true end
end

-- ============================================================
-- PUBLIC HANDLE
-- ============================================================

local Handle = {}
Handle.__index = Handle

function Handle:GetFrame() return self.frame end
function Handle:SetPoint(...) self.frame:ClearAllPoints(); self.frame:SetPoint(...) end
function Handle:ClearAllPoints() self.frame:ClearAllPoints() end

function Handle:SetSize(w, h)
    self.config.size = w or self.config.size
    self.frame:SetSize(w or self.config.size, h or w or self.config.size)
end

function Handle:SetNum(n)
    if self.config.num == n then return end
    self.config.num = n

    -- maxFrameCount is a LIVE setter, so the icon count never needs a rebuild -- and a
    -- rebuild is exactly what left the old icons stacked under the new ones. Layout depends
    -- on num too (the flow line budget is a pixel budget derived from it).
    local c = self.container
    if c and c.SetAuraGroupMaxFrameCount and self._groupKeys and #self._groupKeys > 0 then
        local allOK = true
        for _, key in ipairs(self._groupKeys) do
            if not pcall(c.SetAuraGroupMaxFrameCount, c, key, n) then allOK = false end
        end
        if allOK then
            ApplyLayout(self)
            return
        end
    end

    self.records = nil
    self:Rebuild()
end

-- keys that only affect per-button cosmetics: restyle the cached buttons instead of
-- recreating the container (a rebuild re-creates ~10 buttons per group -- far too heavy
-- for a font slider drag)
local COSMETIC_KEYS = { stackFont = true, durationFont = true }

-- geometry keys: 12.1 has SetAuraGroupLayout as a LIVE setter and StyleButton already
-- re-applies per-button size/border, so these never need a rebuild either. Keeping them
-- off the rebuild path is what stops a size/border tweak from leaving a stale container.
local LAYOUT_KEYS = { size = true, sizeH = true, border = true, spacing = true }

function Handle:Restyle()
    if InCombatLockdown() then return end
    for _, b in ipairs(self.buttons) do
        pcall(StyleButton, self, b)
    end
end

-- Table-valued options (dispelTypes, font tables) arrive as a FRESH table every call, so a
-- reference compare would rebuild on every option touch. Compare contents instead --
-- keys AND values: font tables are arrays whose keys never change, so a keys-only
-- signature reports "identical" no matter what the user drags.
local function TableSig(t)
    if type(t) ~= "table" then return nil end
    local parts = {}
    for k, v in pairs(t) do
        parts[#parts + 1] = tostring(k) .. "=" .. (type(v) == "table" and TableSig(v) or tostring(v))
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

-- push the current geometry onto the live container; false = caller must rebuild
function Handle:ApplyLiveLayout()
    local c = self.container
    if not c then return true end -- nothing built yet; Build will read the new config
    if not c.SetAuraGroupLayout or not self._groupKeys or #self._groupKeys == 0 then
        return false -- overlay/slot mode has no groups to relayout
    end
    local gl = GroupLayout(self.config)
    for _, key in ipairs(self._groupKeys) do
        if not pcall(c.SetAuraGroupLayout, c, key, gl) then return false end
    end
    ApplyLayout(self)
    return true
end

function Handle:SetOptions(opts)
    if not opts then return end
    -- `num` is handled by SetNum, which drives maxFrameCount live instead of rebuilding
    local newNum = opts.num
    local structural, cosmetic, layout = false, false, false
    for k, v in pairs(opts) do
        if k ~= "num" then
            local old = self.config[k]
            local changed
            if type(v) == "table" or type(old) == "table" then
                changed = TableSig(v) ~= TableSig(old)
            else
                changed = old ~= v
            end
            if changed then
                if COSMETIC_KEYS[k] then
                    cosmetic = true
                elseif LAYOUT_KEYS[k] then
                    layout = true
                else
                    structural = true
                end
            end
            self.config[k] = v
        end
    end
    -- ConfigureContainer re-sends the WHOLE option set on every panel touch, so most calls
    -- carry no change at all (dragging a position slider, say). Restyling regardless walked
    -- every cached AuraButton on every unit button per drag tick -- that was the freeze.
    if structural then
        if newNum ~= nil then self.config.num = newNum end -- fold into the rebuild
        self.records = nil
        self:Rebuild()
        return
    end
    if newNum ~= nil then self:SetNum(newNum) end
    if layout and not self:ApplyLiveLayout() then
        self.records = nil
        self:Rebuild()
        return
    end
    if cosmetic or layout then self:Restyle() end
end

function Handle:SetUnit(unit)
    if issecretvalue(unit) then return end
    if self.unit == unit then return end
    self.unit = unit
    self:Rebuild()
end

function Handle:SetShown(shown)
    self.shown = shown and true or false
    self.frame:SetShown(self.shown)
    if self.container then pcall(function() self.container:SetShown(self.shown) end) end
end

function Handle:SetEnabled(enabled)
    enabled = enabled and true or false
    -- ConfigureContainer calls this on EVERY option touch. A blind Rebuild tore down and
    -- recreated the entire AuraContainer (CreateFrame + SetUnit + N AddAuraGroup + ~10
    -- AuraButtons) per unit button per slider tick. `container` is nil until the first
    -- Build, so the initial creation still goes through.
    if self.enabled == enabled and self.container then return end
    self.enabled = enabled
    self:Rebuild()
end

function Handle:Rebuild()
    if InCombatLockdown() then
        self._pendingBuild = true
        RDC._defer(self)
        return
    end
    Build(self)
end

-- Re-assert enable while the frame is actually VISIBLE. SetEnabled gates aura-event
-- registration on IsVisible(); if Build ran while the button was hidden, the container
-- enabled-but-never-registered and stays empty. Call this when the button becomes shown.
function Handle:ReassertEnable()
    if InCombatLockdown() then return end
    local c = self.container
    if not c then return end
    if not self.frame:IsVisible() then return end
    if self._enabledWhileVisible then return end
    self._enabledWhileVisible = true
    pcall(function() c:SetEnabled(true) end)
    pcall(function() c:Hide(); c:Show() end) -- partition kick -> force a fresh scan
end

function Handle:Destroy()
    self._destroyed = true -- Build/Rebuild must not resurrect it
    self._pendingBuild = nil
    RDC._pending[self] = nil
    if RDC._instances then RDC._instances[self] = nil end
    if self.container then
        pcall(function() self.container:SetEnabled(false) end)
        pcall(function() self.container:Hide() end)
        self.container = nil
    end
    -- orphan the host we own: Hide() on the container itself may be refused (see Build)
    if self.host then
        self.host:Hide()
        self.host:SetParent(nil)
        self.host = nil
    end
    self.frame:Hide()
end

-- ============================================================
-- FACTORY
-- config: { size, border, spacing, num, filterBoss, filterRole, filterPriority,
--           filterCrowdControl, filterRaid, filterDispellable }
-- returns a handle, or nil when unsupported (caller keeps its fallback path).
-- ============================================================

function RDC.Create(parent, config)
    if not RDC.IsSupported() then return nil end
    config = config or {}
    config.num = config.num or 3
    config.size = config.size or 22
    config.border = config.border or 1
    config.spacing = config.spacing or 2

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(config.size, config.size)

    local handle = setmetatable({
        frame = frame,
        config = config,
        buttons = {},
        enabled = true,
        shown = true,
    }, Handle)

    RDC._instances = RDC._instances or {}
    RDC._instances[handle] = true

    return handle
end

-- ============================================================
-- FILTER BISECT TOOL  ->  /run Cell.RaidDebuffContainer.Test("HARMFUL")
--
-- Whether an aura MATCHES a group is secret -- only eyes can judge -- so this
-- swaps every CENTRAL (important-mode) container onto ONE test record live,
-- letting the user bisect which filter/candidateFilter combination actually
-- matches in the current build. Out of combat only (rebuild defers otherwise).
--   Test("HARMFUL")                          -> every debuff should show (rendering check)
--   Test("HARMFUL|RAID_PLAYER_DISPELLABLE")  -> dispellable-by-me only
--   Test("HARMFUL", {isBossOrRoleAura=false}) -> tests boolean-false cf mechanics
--   Test(nil)                                -> restore the normal 5 records
-- ============================================================

function RDC.Test(filter, cf, minimal)
    if filter and AuraUtil and AuraUtil.IsValidFilterString and not AuraUtil.IsValidFilterString(filter) then
        print("|cff33ff99[RDC]|r invalid filter string:", filter)
        return
    end
    local n = 0
    for h in pairs(RDC._instances or {}) do
        if not h.config.mode then -- central/important containers only
            h._testMinimal = (filter and minimal) or nil
            if filter then
                h.records = { { key = "test", filter = filter, candidateFilters = cf } }
            else
                h.records = nil -- restore: BuildRecords runs again on rebuild
            end
            h:Rebuild()
            n = n + 1
        end
    end
    local cfDesc = ""
    if cf then
        local keys = {}
        for k, v in pairs(cf) do keys[#keys + 1] = k .. "=" .. tostring(v) end
        cfDesc = " cf{" .. table.concat(keys, ",") .. "}"
    end
    print("|cff33ff99[RDC]|r central containers -> " .. (filter and (filter .. cfDesc) or "(restored to normal records)") .. " (" .. n .. " rebuilt; OOC only)")
end

-- One-button macro stepper: /run RDC_Test()
-- Each press advances to the next bisect case and prints what to look for.
local TEST_STEPS = {
    { f = "HARMFUL", minimal = true,                desc = "第1步 最小渲染(只綁icon):任何減益都該亮" },
    { f = "HARMFUL",                                desc = "第2步 完整樣式:第1亮這步不亮=樣式綁定壞" },
    { f = "HARMFUL|RAID_PLAYER_DISPELLABLE",        desc = "第3步 可驅散token:可驅散減益該亮" },
    { f = "HARMFUL", cf = { isBossOrRoleAura = false },
                                                    desc = "第4步 布林false旗標:跟第2步同,不亮=布林false壞" },
    { f = "HARMFUL|RAID_PLAYER_DISPELLABLE|!RAID",  desc = "第5步 !RAID抵銷:第3步亮這步不亮=RAID抵銷確認" },
    { f = nil,                                      desc = "已恢復正常5組filter(再按一次回到第1步)" },
}
local testStep = 0
function RDC_Test()
    testStep = testStep % #TEST_STEPS + 1
    local s = TEST_STEPS[testStep]
    RDC.Test(s.f, s.cf, s.minimal)
    print("|cffffcc00[RDC 測試 " .. testStep .. "/" .. #TEST_STEPS .. "]|r " .. s.desc)
    -- auto-surface any styling/bind errors captured during the rebuild
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function()
            for h in pairs(RDC._instances or {}) do
                if not h.config.mode and h._errors and #h._errors > 0 then
                    for _, e in ipairs(h._errors) do print("|cffff5555[RDC ERR]|r " .. e) end
                    return -- one instance's errors are representative
                end
            end
        end)
    end
end

-- ============================================================
-- DIAGNOSTICS  ->  /run Cell.RaidDebuffContainer.Debug()
-- ============================================================

local function p(...) print("|cff33ff99[RDC]|r", ...) end

function RDC.Debug()
    p("Cell.isMidnight =", tostring(Cell.isMidnight))
    p("IsSupported() =", tostring(RDC.IsSupported()))

    -- raw probe detail
    local toc = select(4, GetBuildInfo())
    p("TOC build =", tostring(toc))
    p("AuraUtil.IsValidFilterString =", tostring(AuraUtil and AuraUtil.IsValidFilterString ~= nil))
    local okF, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    p("CreateFrame(AuraContainer, CustomAuraContainerTemplate) ok =", tostring(okF),
        "AddAuraGroup fn =", tostring(okF and frame and type(frame.AddAuraGroup) == "function"))

    -- filter string validity for each category record
    if AuraUtil and AuraUtil.IsValidFilterString then
        for _, rec in ipairs(BuildRecords({})) do
            p("filter valid?", rec.key, rec.filter, "->", tostring(AuraUtil.IsValidFilterString(rec.filter)))
        end
    end

    -- live instances (the actual per-button containers) -- prioritise VISIBLE ones,
    -- those are the units actually on screen with debuffs.
    local total, built, visible, shown = 0, 0, 0, 0
    local samples = 0
    for h in pairs(RDC._instances or {}) do
        total = total + 1
        if h.container then built = built + 1 end
        local vis = h.frame:IsVisible()
        if vis then visible = visible + 1 end
        if h.container and h.container:IsVisible() then shown = shown + 1 end
        -- detail the first few VISIBLE, container-backed instances
        if vis and h.container and samples < 5 then
            samples = samples + 1
            -- NOTE: AuraButton IsShown/geometry are SECRET (branching on them errors), so we
            -- CANNOT read whether a button is rendering -- only the user's eyes can confirm that.
            p(("VISIBLE unit=%s mode=%s enabled=%s groupsAdded=%s initCount=%s ewv=%s buttons=%d")
                :format(tostring(h.unit), tostring(h._modeDbg), tostring(h.enabled), tostring(h._groupsAdded),
                    tostring(h._initCount), tostring(h._enabledWhileVisible), #h.buttons))
            -- our own anchor frame: rect is readable (not secret). A 0x0/nil rect means
            -- children can't resolve -> container renders nothing despite being visible.
            local fw, fh = h.frame:GetSize()
            local fx, fy = h.frame:GetCenter()
            p(("   anchorFrame size=%.1fx%.1f center=%s,%s")
                :format(tonumber(fw) or -1, tonumber(fh) or -1,
                    fx and string.format("%.0f", fx) or "nil", fy and string.format("%.0f", fy) or "nil"))
            if h._recordInfo then
                for _, ri in ipairs(h._recordInfo) do p("   filter:", ri) end
            end
            if h._errors and #h._errors > 0 then
                for _, e in ipairs(h._errors) do p("   ERR:", e) end
            end
        end
    end
    p(("totals: instances=%d built=%d frameVisible=%d containerVisible=%d"):format(total, built, visible, shown))
    if samples == 0 then p("!! no VISIBLE container-backed instance found -- stand in a group with debuffs and retry") end
end

-- ============================================================
-- GHOST CHECK  ->  /run Cell.RaidDebuffContainer.Ghosts()
--
-- Answers "is this icon rendered twice?". Every live handle should still be owned by an
-- indicator registered on its button. One that isn't is an orphan: its frame is parented
-- to the button and its container is still bound to the unit, so it keeps drawing an icon
-- at whatever position it last had -- on top of whatever legitimately replaced it.
-- AuraButton IsShown/geometry are SECRET, so this is the only readable way to detect it.
-- ============================================================

function RDC.Ghosts()
    local total, orphans, disposeFails = 0, 0, 0
    for h in pairs(RDC._instances or {}) do
        total = total + 1
        if h._disposeFailed then
            disposeFails = disposeFails + 1
            p(("DISPOSE-FAILED x%d unit=%s mode=%s -- host survived Hide()/SetParent(nil)")
                :format(h._disposeFailed, tostring(h.unit), tostring(h.config and h.config.mode or "important")))
        end
        if h._pendingBuild then
            p(("PENDING-BUILD unit=%s mode=%s -- config change is queued until combat ends")
                :format(tostring(h.unit), tostring(h.config and h.config.mode or "important")))
        end
        local btn = h.frame:GetParent()
        local owned = false
        for _, ind in ipairs((btn and btn._containerIndicators) or {}) do
            if ind.container == h then owned = true break end
        end
        if not owned then
            orphans = orphans + 1
            p(("ORPHAN unit=%s mode=%s shown=%s built=%s button=%s")
                :format(tostring(h.unit), tostring(h.config and h.config.mode or "important"),
                    tostring(h.frame:IsShown()), tostring(h.container ~= nil),
                    tostring(btn and btn:GetName() or "?")))
        end
    end
    p(("|cff33ff99[RDC]|r ghost check: %d/%d orphaned, %d dispose-failed"):format(orphans, total, disposeFails))
end

return RDC
