local _, Cell = ...
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs

local orientation, speed

-------------------------------------------------
-- events
-------------------------------------------------
-- Audited for Midnight 12.0.0+ compatibility: no changes required.
-- CLEU (COMBAT_LOG_EVENT_UNFILTERED) is not used — it is fully commented out below.
-- The active handler listens to UNIT_SPELLCAST_SUCCEEDED for group members only.
-- spellID from UNIT_SPELLCAST_SUCCEEDED for allied units is non-secret.
-- Cell.vars.actions[spellID] table key usage is safe because the spellID comes
-- from your own group's spellcasts, which are never restricted by GetRestrictedActionStatus.

-- CLEU: subevent, source, target, spellId, spellName
-- [15:10] SPELL_HEAL 秋静葉 秋静葉 6262 治疗石
-- [15:10] SPELL_CAST_SUCCESS 秋静葉 nil 6262 治疗石
-- [15:13] SPELL_HEAL 秋静葉 秋静葉 307192 灵魂治疗药水
-- [15:13] SPELL_CAST_SUCCESS 秋静葉 nil 307192 灵魂治疗药水

-- UNIT_SPELLCAST_SUCCEEDED
-- unit, castGUID, spellID

local function Display(b, ...)
    b.indicators.actions:Display(...)
end

-- Debug Mode has to report WHICH gate dropped an event. A single print placed after the gates
-- makes "no line appeared" cover three unrelated faults at once -- the event never fired for
-- that unit, the group filter rejected it, or the id arrived secret -- and they need opposite
-- fixes. Each gate below therefore says so on the way out.
--
-- The token test is pure string matching on purpose: it never calls a unit API, so it can
-- never itself trip over a secret value. It exists only to keep the drop messages down to your
-- own group instead of every nameplate in the room.
local function IsGroupToken(unit)
    return unit and (unit == "player" or unit == "pet"
        or strfind(unit, "^party") or strfind(unit, "^raid"))
end

local function DebugPrint(unit, msg)
    print("|cFFFF3030[Cell]|r", tostring(unit), msg)
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
    -- Report every group token, and ALSO any other token (target, focus, nameplateN...) whose
    -- id is in the list. If a teammate's potion shows up as "target" but never as "party1",
    -- the event fires and the group tokens are what's missing -- a very different fault from
    -- the event not firing at all. The secret check has to come first: an enemy nameplate's
    -- id can be secret, and a secret key would error on the table lookup.
    local debugging = Cell.vars.actionsDebugModeEnabled
        and (IsGroupToken(unit) or (F.IsValueNonSecret(spellID) and Cell.vars.actions[spellID] ~= nil))

    -- filter out players not in your group
    -- 12.1: UnitInRaid returns a secret boolean for identity-restricted units, and `not (...)`
    -- on a secret boolean is a hard Lua error
    if not (F.ToBool(UnitInRaid(unit)) or UnitInParty(unit) or unit == "player" or unit == "pet") then
        if debugging then
            DebugPrint(unit, "|cFFFF7F00dropped: UnitInRaid and UnitInParty both say this unit is not in your group|r")
        end
        return
    end

    -- Midnight 12.0.0+: spellID from UNIT_SPELLCAST_SUCCEEDED may be secret
    -- during restricted contexts; skip if so since we can't use it as a table key
    if not F.IsValueNonSecret(spellID) then
        if debugging then
            DebugPrint(unit, "|cFFFF7F00dropped: spell id arrived as a secret value|r")
        end
        return
    end

    local action = Cell.vars.actions[spellID]

    if action then
        -- HandleUnitButton reports whether any visible button actually matched the unit, which
        -- separates "we never saw the cast" from "we saw it and had nowhere to draw it"
        local handled = F.HandleUnitButton("unit", unit, Display, unpack(action))
        if debugging then
            DebugPrint(unit, "|cFF00FF00" .. tostring(spellID) .. "|r " .. (F.GetSpellInfo(spellID) or "?")
                .. (handled and " |cFF00FF00-> animation played|r"
                             or " |cFFFF7F00-> in the list, but no Cell button is currently showing this unit|r"))
        end
    elseif debugging then
        DebugPrint(unit, "|cFFB2B2B2" .. tostring(spellID) .. " " .. (F.GetSpellInfo(spellID) or "?")
            .. " -- reached the indicator, but this id is not in the list|r")
    end
end)

-- local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
-- eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
-- eventFrame:SetScript("OnEvent", function()
--     local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName = CombatLogGetCurrentEventInfo()
--     print(subevent, sourceName, destName, spellId, spellName)
-- end)

-------------------------------------------------
-- pool
-------------------------------------------------
local animationPool = {}

local function ResetterFunc(_, canvas)
    canvas:Hide()
end

-------------------------------------------------
-- animation: A
-------------------------------------------------
local function CreateAnimationGroup_TypeA()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexture(Cell.vars.whiteTexture)

    -- mask
    local mask = canvas:CreateMaskTexture()
    mask:SetTexture(Cell.vars.whiteTexture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(canvas)
    -- mask:SetSnapToPixelGrid(true)
    tex:AddMaskTexture(mask)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.6
    a1:SetFromAlpha(0)
    a1:SetToAlpha(1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local t1 = ag:CreateAnimation("Translation")
    t1.duration = 0.6
    t1:SetOrder(1)
    t1:SetSmoothing("OUT")
    t1:SetDuration(t1.duration)

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    a2:SetFromAlpha(1)
    a2:SetToAlpha(0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    -- a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.A:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        if parent.orientation == "horizontal" then
            f:SetPoint("TOPRIGHT", canvas, "TOPLEFT")
            f:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT")
            f:SetWidth(15)

            t1:SetOffset(canvas:GetWidth(), 0)
            tex:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
        else
            f:SetPoint("TOPLEFT", canvas, "BOTTOMLEFT")
            f:SetPoint("TOPRIGHT", canvas, "BOTTOMRIGHT")
            f:SetHeight(15)

            t1:SetOffset(0, canvas:GetHeight())
            tex:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
        end

        a1:SetDuration(a1.duration / parent.speed)
        t1:SetDuration(t1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        if ag:IsPlaying() then
            ag:Restart()
        else
            ag:Play()
        end
    end

    return canvas
end

animationPool.A = CreateObjectPool(CreateAnimationGroup_TypeA, ResetterFunc)

-------------------------------------------------
-- animation: B
-------------------------------------------------
local function CreateAnimationGroup_TypeB()
    local WIDTH = 20

    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetPoint("TOPRIGHT", canvas, "TOPLEFT")
    f:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT")
    f:SetWidth(WIDTH)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("BOTTOMRIGHT")
    tex:SetWidth(WIDTH)
    tex:SetRotation(45 * math.pi / 180, CreateVector2D(1, 0))

    -- mask
    local mask = canvas:CreateMaskTexture()
    mask:SetTexture(Cell.vars.whiteTexture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(canvas)
    -- mask:SetSnapToPixelGrid(true)
    tex:AddMaskTexture(mask)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.35
    a1:SetFromAlpha(0)
    a1:SetToAlpha(0.7)
    a1:SetDuration(a1.duration)
    -- a1:SetSmoothing("IN")

    local t1 = ag:CreateAnimation("Translation")
    t1.duration = 0.7
    t1:SetSmoothing("IN_OUT")
    t1:SetDuration(t1.duration)

    -- local a2 = ag:CreateAnimation("Alpha")
    -- a2.duration = 0.3
    -- a2:SetFromAlpha(0.7)
    -- a2:SetToAlpha(0)
    -- a2:SetDuration(a2.duration)
    -- a2:SetStartDelay(t1.duration - a2.duration)

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.B:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        a1:SetDuration(a1.duration / parent.speed)
        t1:SetDuration(t1.duration / parent.speed)

        t1:SetOffset(canvas:GetWidth() + math.tan(math.pi / 4) * canvas:GetHeight() + WIDTH / math.cos(math.pi / 4), 0)
        tex:SetHeight(canvas:GetHeight() / math.sin(math.pi / 4) + WIDTH)
        tex:SetColorTexture(r, g, b)

        if ag:IsPlaying() then
            ag:Restart()
        else
            ag:Play()
        end
    end

    return canvas
end

animationPool.B = CreateObjectPool(CreateAnimationGroup_TypeB, ResetterFunc)

-------------------------------------------------
-- animation: C
-------------------------------------------------
local function CreateAnimationGroup_TypeC()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\upgrade.tga")

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.5
    a1:SetFromAlpha(0)
    a1:SetToAlpha(1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local t1 = ag:CreateAnimation("Translation")
    t1.duration = 0.5
    t1:SetOrder(1)
    t1:SetSmoothing("OUT")
    t1:SetDuration(t1.duration)

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    a2:SetFromAlpha(1)
    a2:SetToAlpha(0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.C:Release(canvas)
    end)

    function ag:Display(parent, subType, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        f:ClearAllPoints()
        if subType == "1" then
            f:SetPoint("BOTTOMLEFT")
            f:SetPoint("TOPLEFT", canvas, "LEFT")
        elseif subType == "2" then
            f:SetPoint("BOTTOM")
            f:SetPoint("TOP", canvas, "CENTER")
        else
            f:SetPoint("BOTTOMRIGHT")
            f:SetPoint("TOPRIGHT", canvas, "RIGHT")
        end

        a1:SetDuration(a1.duration / parent.speed)
        t1:SetDuration(t1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        f:SetWidth(canvas:GetHeight() / 2)
        t1:SetOffset(0, canvas:GetHeight() / 2)
        tex:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))

        if ag:IsPlaying() then
            ag:Restart()
        else
            ag:Play()
        end
    end

    return canvas
end

animationPool.C = CreateObjectPool(CreateAnimationGroup_TypeC, ResetterFunc)

-------------------------------------------------
-- animation: D
-------------------------------------------------
local function CreateAnimationGroup_TypeD()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetAllPoints(canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("CENTER")

    -- mask1
    local mask1 = f:CreateMaskTexture()
    mask1:SetAllPoints(tex)
    mask1:SetTexture("Interface/AddOns/Cell/Media/Shapes/circle_filled_256", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    tex:AddMaskTexture(mask1)

    -- mask2
    local mask2 = canvas:CreateMaskTexture()
    mask2:SetTexture(Cell.vars.whiteTexture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask2:SetAllPoints(canvas)
    tex:AddMaskTexture(mask2)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.3
    a1:SetFromAlpha(0)
    a1:SetToAlpha(1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local s1 = ag:CreateAnimation("Scale")
    s1.duration = 0.5
    s1:SetScaleFrom(0, 0)
    s1:SetScaleTo(1, 1)
    s1:SetOrder(1)
    s1:SetDuration(s1.duration)

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    a2:SetFromAlpha(1)
    a2:SetToAlpha(0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.D:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        a1:SetDuration(a1.duration / parent.speed)
        s1:SetDuration(s1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        local l = math.sqrt((parent:GetParent():GetHeight() / 2) ^ 2 + (parent:GetParent():GetWidth() / 2) ^ 2) * 2
        tex:SetSize(l, l)
        tex:SetColorTexture(r, g, b, 0.6)

        if ag:IsPlaying() then
            ag:Restart()
        else
            ag:Play()
        end
    end

    return canvas
end

animationPool.D = CreateObjectPool(CreateAnimationGroup_TypeD, ResetterFunc)

-------------------------------------------------
-- animation: E
-------------------------------------------------
local function CreateAnimationGroup_TypeE()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetPoint("TOPRIGHT", canvas, "TOPLEFT")
    f:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMLEFT")

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexture("Interface/AddOns/Cell/Media/Icons/arrow.tga")

    -- mask
    local mask = canvas:CreateMaskTexture()
    mask:SetTexture(Cell.vars.whiteTexture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(canvas)
    -- frame:SetSnapToPixelGrid(false)
    -- frame:SetTexelSnappingBias(0)
    tex:AddMaskTexture(mask)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    -- local a1 = ag:CreateAnimation("Alpha")
    -- a1:SetFromAlpha(0)
    -- a1:SetToAlpha(0.7)
    -- a1:SetDuration(0.3)
    -- a1:SetSmoothing("OUT")

    local t1 = ag:CreateAnimation("Translation")
    t1.duration = 0.8
    t1:SetSmoothing("IN_OUT")
    t1:SetDuration(t1.duration)

    -- local a2 = ag:CreateAnimation("Alpha")
    -- a2:SetFromAlpha(0.7)
    -- a2:SetToAlpha(0)
    -- a2:SetDuration(0.3)
    -- a2:SetStartDelay(0.5)
    -- a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.E:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        t1:SetDuration(t1.duration / parent.speed)

        local l = canvas:GetHeight() * 2
        f:SetWidth(l)
        t1:SetOffset(l + canvas:GetWidth(), 0)

        tex:SetVertexColor(r, g, b, 0.6)

        if ag:IsPlaying() then
            ag:Restart()
        else
            ag:Play()
        end
    end

    return canvas
end

animationPool.E = CreateObjectPool(CreateAnimationGroup_TypeE, ResetterFunc)

-------------------------------------------------
-- animation: F
-------------------------------------------------
local function CreateAnimationGroup_TypeF()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetAllPoints(canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("CENTER")

    -- mask1
    local mask1 = f:CreateMaskTexture()
    mask1:SetAllPoints(tex)
    mask1:SetTexture("Interface/AddOns/Cell/Media/Shapes/heart_filled_256", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    tex:AddMaskTexture(mask1)

    -- mask2
    local mask2 = canvas:CreateMaskTexture()
    mask2:SetTexture(Cell.vars.whiteTexture, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask2:SetAllPoints(canvas)
    tex:AddMaskTexture(mask2)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.3
    a1:SetFromAlpha(0)
    a1:SetToAlpha(1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local s1 = ag:CreateAnimation("Scale")
    s1.duration = 0.5
    s1:SetScaleFrom(0, 0)
    s1:SetScaleTo(1, 1)
    s1:SetOrder(1)
    s1:SetDuration(s1.duration)

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    a2:SetFromAlpha(1)
    a2:SetToAlpha(0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.F:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        a1:SetDuration(a1.duration / parent.speed)
        s1:SetDuration(s1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        local l = max(parent:GetParent():GetWidth(), parent:GetParent():GetHeight()) * 2
        tex:SetSize(l, l)
        tex:SetColorTexture(r, g, b, 0.6)

        if ag:IsPlaying() then
            ag:Restart()
        else
            ag:Play()
        end
    end

    return canvas
end

animationPool.F = CreateObjectPool(CreateAnimationGroup_TypeF, ResetterFunc)

-------------------------------------------------
-- animation: G
-------------------------------------------------
local function CreateAnimationGroup_TypeG()
    local canvas = CreateFrame("Frame")

    -- frame
    local f = CreateFrame("Frame", nil, canvas)
    f:SetPoint("TOPLEFT", canvas)
    f:SetPoint("TOPRIGHT", canvas)

    -- texture
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(f)
    tex:SetTexture(Cell.vars.whiteTexture)

    -- animation
    local ag = f:CreateAnimationGroup()
    canvas.ag = ag

    local a1 = ag:CreateAnimation("Alpha")
    a1.duration = 0.5
    a1:SetFromAlpha(0)
    a1:SetToAlpha(1)
    a1:SetOrder(1)
    a1:SetDuration(a1.duration)
    a1:SetSmoothing("OUT")

    local a2 = ag:CreateAnimation("Alpha")
    a2.duration = 0.5
    a2:SetFromAlpha(1)
    a2:SetToAlpha(0)
    a2:SetDuration(a2.duration)
    a2:SetOrder(2)
    a2:SetSmoothing("IN")

    ag:SetScript("OnPlay", function()
        canvas:Show()
    end)

    ag:SetScript("OnFinished", function()
        animationPool.G:Release(canvas)
    end)

    function ag:Display(parent, r, g, b)
        canvas:SetParent(parent)
        canvas:SetAllPoints(parent)

        f:SetHeight(canvas:GetHeight() / 2)

        tex:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))

        a1:SetDuration(a1.duration / parent.speed)
        a2:SetDuration(a2.duration / parent.speed)

        if ag:IsPlaying() then
            ag:Restart()
        else
            ag:Play()
        end
    end

    return canvas
end

animationPool.G = CreateObjectPool(CreateAnimationGroup_TypeG, ResetterFunc)

-------------------------------------------------
-- indicator
-------------------------------------------------
local previews = {}
local previewOrientation

local function Actions_SetSpeed(self, speed)
    self.speed = speed
end

local function Actions_Display(self, animationType, color)
    -- animations[animationType]:Display(unpack(color))
    if strfind(animationType, "^C") then
        local subType = strmatch(animationType, "%d")
        local canvas = animationPool.C:Acquire()
        canvas.ag:Display(self, subType, color[1], color[2], color[3])
    else
        local canvas = animationPool[animationType]:Acquire()
        canvas.ag:Display(self, color[1], color[2], color[3])
    end
end

function I.CreateActions(parent, isPreview)
    local actions = CreateFrame("Frame", parent:GetName() .. "ActionsParent", isPreview and parent or parent.widgets.indicatorFrame)

    if isPreview then
        parent.actions = actions
        tinsert(previews, parent)
        actions:SetPoint("TOPLEFT", 1, -1)
        actions:SetPoint("BOTTOMRIGHT", -1, 1)
        actions.orientation = previewOrientation
    else
        parent.indicators.actions = actions
        actions:SetAllPoints(parent.widgets.healthBar)
    end

    actions.speed = 1
    actions.SetSpeed = Actions_SetSpeed
    actions.Display = Actions_Display
end

function I.UpdateActionsOrientation(button, barOrientation)
    button.indicators.actions.orientation = barOrientation

    if previewOrientation ~= barOrientation then
        previewOrientation = barOrientation
        for _, p in pairs(previews) do
            p.actions.orientation = barOrientation
        end
    end
end

function I.EnableActions(enabled)
    if enabled then
        eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    else
        eventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    end
end

-- Printed when Debug Mode is switched on, so "no line appeared" can never mean "the event was
-- never registered" (indicator disabled in this layout) or "debug was not actually on".
function I.PrintActionsDebugStatus(enabled)
    local registered = eventFrame:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED") and true or false
    print("|cFFFF3030[Cell]|r Actions debug " .. (enabled and "|cFF00FF00ON|r" or "|cFFFF7F00OFF|r")
        .. "  event registered: " .. (registered and "|cFF00FF00yes|r" or "|cFFFF3030NO -- indicator disabled in this layout?|r")
        .. "  group: " .. tostring(Cell.vars.groupType))
end