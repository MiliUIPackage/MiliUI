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

local function BuildRecords(opts)
    opts = opts or {}
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

    ApplyLayout(handle)

    -- SetUnit BEFORE groups
    pcall(function() c:SetUnit(handle.unit) end)

    local records = handle.records or BuildRecords(handle.config)
    local groupLayout = GroupLayout(handle.config)
    local maxCount = handle.config.num or 3

    for _, rec in ipairs(records) do
        pcall(c.AddAuraGroup, c, rec.key, rec.filter, {
            maxFrameCount = maxCount,
            initializeFrame = function(button)
                pcall(StyleButton, handle, button)
            end,
            layout = groupLayout,
            candidateFilters = rec.candidateFilters,
        })
    end

    -- SetEnabled LAST (gates aura-event registration)
    pcall(function() c:SetEnabled(true) end)
    pcall(function() c:SetShown(handle.shown ~= false) end)
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

    return handle
end

return RDC
