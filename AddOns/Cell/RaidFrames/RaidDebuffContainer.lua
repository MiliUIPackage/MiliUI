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

-- one shared secret-safe duration binding per container (built lazily, OOC)
local function GetDurationBinding(handle)
    if handle._durBind ~= nil then return handle._durBind end
    handle._durBind = false
    if C_DurationUtil and C_DurationUtil.CreateDurationTextBinding then
        local ok, b = pcall(C_DurationUtil.CreateDurationTextBinding)
        if ok and b then
            -- default formatter = engine's aura duration formatter (no unit leak)
            pcall(function()
                if AuraContainerInbound and AuraContainerInbound.GetDefaultAuraDurationFormatter then
                    b:SetFormatter(AuraContainerInbound.GetDefaultAuraDurationFormatter())
                end
                if b.SetZeroDurationText then b:SetZeroDurationText("") end -- permanent auras: blank
                if b.SetEnabled then b:SetEnabled(true) end
            end)
            handle._durBind = b
        end
    end
    return handle._durBind
end

local function StyleButton(handle, button)
    local cfg = handle.config
    local size = cfg.size or 22
    local border = cfg.border or 1

    -- click-through; tooltip opt-in
    if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
    if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
    if button.SetCollapsesLayout then button:SetCollapsesLayout(true) end
    button:SetSize(size, size)

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
        if (button.AddDispelTypeTexture or button.SetAuraBorder) and not button._boundTint then
            button._boundTint = true
            local styleEnum = (Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
                and Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset) or 3
            local dopts = { style = styleEnum, showWhenHarmful = true, showWhenHelpful = false, showIcon = false }
            if button.AddDispelTypeTexture then
                if button.ClearDispelTypeTextures then pcall(button.ClearDispelTypeTextures, button) end
                pcall(button.AddDispelTypeTexture, button, button.dfTint, dopts)
            else
                pcall(button.SetAuraBorder, button, button.dfTint, dopts)
            end
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
        if (button.AddDispelTypeTexture or button.SetAuraBorder) and not button._boundDispelIcon then
            button._boundDispelIcon = true
            local iconStyle = (Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
                and Enum.CustomAuraButtonDispelTypeTextureStyle.Icon) or 2
            local dopts = { style = iconStyle, showWhenHarmful = true, showWhenHelpful = false }
            if button.AddDispelTypeTexture then
                if button.ClearDispelTypeTextures then pcall(button.ClearDispelTypeTextures, button) end
                pcall(button.AddDispelTypeTexture, button, button.dfDispelIcon, dopts)
            else
                pcall(button.SetAuraBorder, button, button.dfDispelIcon, dopts)
            end
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

    -- duration text (holder above the swipe)
    if not button.dfDur then
        button.dfDurHolder = CreateFrame("Frame", nil, button)
        button.dfDurHolder:SetFrameLevel(button:GetFrameLevel() + 6)
        button.dfDur = button.dfDurHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
        button.dfDur:SetPoint("CENTER")
    end

    -- stack/count text
    if not button.dfStack then
        button.dfStackHolder = CreateFrame("Frame", nil, button)
        button.dfStackHolder:SetFrameLevel(button:GetFrameLevel() + 7)
        button.dfStack = button.dfStackHolder:CreateFontString(nil, "OVERLAY", "CELL_FONT_STATUS")
        button.dfStack:SetPoint("BOTTOMRIGHT", 2, -1)
    end

    -- NOTE: dispel-type colored border deferred to in-game iteration -- SetAuraBorder /
    -- AddDispelTypeTexture only RECOLORS a texture you supply (it doesn't carve a ring),
    -- so a naive full-cover texture blocks the icon. Needs the border-behind-icon trick.

    -- ---- native binds (bind-once via flags; duration is re-bindable) ----
    if button.dfIcon and button.SetIcon and not button._boundIcon then
        button._boundIcon = true
        pcall(button.SetIcon, button, button.dfIcon)
    end
    if button.dfCD and button.SetDurationCooldown and not button._boundCD then
        button._boundCD = true
        pcall(button.SetDurationCooldown, button, button.dfCD)
    end
    if button.dfStack and button.SetApplicationCount and not button._boundStack then
        button._boundStack = true
        -- ⚠ EMPTY opts, NEVER a formatter: Blizzard runs formatter:FormatNumber in
        -- Lua on the SECRET stack count -> throws inside ProcessDirtyFlags and
        -- bricks the container for the session.
        pcall(button.SetApplicationCount, button, button.dfStack, {})
    end
    if button.dfDur and button.SetDurationText then
        local opts = {}
        local bind = GetDurationBinding(handle)
        if bind then opts.binding = bind end
        pcall(button.SetDurationText, button, button.dfDur, opts)
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
        elementWidth = size, elementHeight = size,
        elementSpacing = spacing, lineSpacing = spacing, groupSpacing = 0,
    }
end

-- ============================================================
-- BUILD  (create -> SetUnit -> AddAuraGroup* -> SetEnabled LAST)
-- ============================================================

local function Build(handle)
    if InCombatLockdown() then
        handle._pendingBuild = true
        if RDC._defer then RDC._defer(handle) end
        return
    end
    handle._pendingBuild = nil

    -- tear down previous native container (add-only topology -> recreate on change)
    if handle.container then
        pcall(function() handle.container:SetEnabled(false) end)
        pcall(function() handle.container:Hide() end)
        pcall(function() handle.container:SetParent(nil) end)
        handle.container = nil
    end
    wipe(handle.buttons)

    if not handle.enabled or not handle.unit then return end

    local ok, c = pcall(CreateFrame, "AuraContainer", nil, handle.frame, "CustomAuraContainerTemplate")
    if not ok or not c then return end
    handle.container = c
    handle._errors = {}          -- diagnostics: per-step failures (see RDC.Debug)
    handle._initCount = 0        -- how many buttons Blizzard asked us to style
    handle._groupsAdded = 0
    handle._enabledWhileVisible = false

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
            pcall(StyleButton, handle, button)
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
    self.records = nil
    self:Rebuild()
end

function Handle:SetOptions(opts)
    if opts then for k, v in pairs(opts) do self.config[k] = v end end
    self.records = nil
    self:Rebuild()
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
    self.enabled = enabled and true or false
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
    self._pendingBuild = nil
    RDC._pending[self] = nil
    if self.container then
        pcall(function() self.container:SetEnabled(false) end)
        pcall(function() self.container:Hide() end)
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

return RDC
