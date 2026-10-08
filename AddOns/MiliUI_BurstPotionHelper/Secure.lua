local addonName, ns = ...

----------------------------------------------------------------------
-- The single hidden secure button. The burst macro is just:
--     /click MiliUIBurstButton
-- We configure its "item" attribute out of combat; clicking it in combat
-- uses the selected potion. Nothing protected is ever touched in combat.
----------------------------------------------------------------------
function ns.CreateSecureButton()
    if ns.button then
        return ns.button
    end
    local b = CreateFrame("Button", ns.BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    b:SetAlpha(0.01)
    b:EnableMouse(true)
    b:RegisterForClicks("AnyDown", "AnyUp")
    -- A macro /click fires only the "up" edge; with ActionButtonUseKeyDown on
    -- that misses the normal click action, so we mark it press-and-hold and set
    -- *release* attributes (matching the proven BurstPotionSwitcher recipe).
    b:SetAttribute("pressAndHoldAction", true)
    b:Show()                        -- shown so /click resolves it
    ns.button = b
    return b
end

-- "item:ID" names the potion by identity, not by where it sits. Every quality
-- tier is its own itemID, so this is exactly as precise as a bag slot.
--
-- Not "bag slot": the attribute is written out of combat and locked in combat.
-- Drain that stack mid-fight and the ref points at an empty slot until combat
-- ends — Blizzard's item handler then resolves the name from the empty slot
-- (nil) and C_Item.IsEquippableItem(nil) throws, so the press does nothing even
-- when another stack of the same potion is still in the bags.
function ns.GetItemRef(itemID)
    return "item:" .. itemID
end

----------------------------------------------------------------------
-- Raid boss-only gate.
--
-- Every write to the use button goes through one secure frame (ns.gate):
--   state-sel   the selected potion's ref ("" = no potion). Written out of
--               combat by ApplySecure, and in combat by the selector snippet.
--   bossonly    true while "raid: boss fights only" applies (option on AND the
--               current context is raid). Written out of combat only.
--   state-boss  a macro-condition state driver, so Blizzard flips it from the
--               secure side even in combat: "nocombat" (pre-pull potions still
--               work), "boss" while any boss unit exists, else "trash".
--   seenboss    latched by GATE_APPLY on "boss", cleared on "nocombat": once a
--               boss showed up in this combat the gate stays open until combat
--               ends, so phases where the boss units vanish (intermissions,
--               boss swaps) don't count as a trash fight. There's no secure
--               "encounter in progress" signal: no macro conditional exists,
--               and ENCOUNTER_START / IsEncounterInProgress are insecure-only,
--               which can't write the gate in combat.
-- GATE_APPLY points the use button at state-sel, or clears it when bossonly is
-- on and the gate is closed. The selection itself is never touched, so the
-- chosen potion comes back by itself the moment a boss is engaged.
----------------------------------------------------------------------
local GATE_DRIVER = "[nocombat] nocombat; "
    .. "[@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists][@boss5,exists] boss; "
    .. "trash"

local GATE_APPLY = [[
    local use = self:GetFrameRef("use")
    if not use then return end
    local state = self:GetAttribute("state-boss")
    if state == "boss" then
        self:SetAttribute("seenboss", true)
    elseif state == "nocombat" then
        self:SetAttribute("seenboss", nil)
    end
    local ref = self:GetAttribute("state-sel")
    if self:GetAttribute("bossonly") and state == "trash"
        and not self:GetAttribute("seenboss") then
        ref = nil
    end
    if ref and ref ~= "" then
        use:SetAttribute("pressAndHoldAction", true)
        use:SetAttribute("type", "item")
        use:SetAttribute("item", ref)
        use:SetAttribute("typerelease", "item")  -- /click up-edge release path
        use:SetAttribute("itemrelease", ref)
        use:SetAttribute("type1", "item")         -- left-down click path
        use:SetAttribute("item1", ref)
    else
        use:SetAttribute("type", nil)
        use:SetAttribute("item", nil)
        use:SetAttribute("typerelease", nil)
        use:SetAttribute("itemrelease", nil)
        use:SetAttribute("type1", nil)
        use:SetAttribute("item1", nil)
    end
]]

function ns.CreateGate()
    if ns.gate then return ns.gate end
    local gate = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
    SecureHandlerSetFrameRef(gate, "use", ns.button or ns.CreateSecureButton())
    gate:SetAttribute("_onstate-sel", GATE_APPLY)
    gate:SetAttribute("_onstate-boss", GATE_APPLY)
    RegisterStateDriver(gate, "boss", GATE_DRIVER)
    ns.gate = gate
    return gate
end

-- "Raid: boss fights only" is in force for the current environment.
function ns.BossOnlyActive()
    return ns.GetDB().raidBossOnly
        and (ns.currentContext or ns.ComputeContext()) == "raid"
end

local function BossPresent()
    for i = 1, 5 do
        local exists = UnitExists("boss" .. i)
        -- A secret answer can't be tested; treat it as "boss here" so the bar
        -- never shows a pause that may not be real.
        if issecretvalue and issecretvalue(exists) then return true end
        if exists then return true end
    end
    return false
end

-- Insecure copy of the gate's seenboss latch, for the dimming below. Called on
-- combat start and every boss-unit / encounter event; cleared on combat end.
function ns.UpdateBossSeen()
    if not ns.inCombat then
        ns.bossSeen = false
    elseif BossPresent() then
        ns.bossSeen = true
    end
end

-- Visual mirror of the secure gate (the bar dims while paused). Insecure and
-- event-driven; the real decision is made by the state driver above.
function ns.IsGatePaused()
    return ns.BossOnlyActive() and ns.inCombat and not ns.bossSeen
        and not BossPresent() or false
end

-- Points the use button at the current selection (via the gate). Used for
-- non-click updates (login, bag changes, leaving combat, option changes).
-- In-combat selector clicks go through the selector snippet instead.
function ns.ApplySecure()
    if InCombatLockdown() then
        ns.pendingApply = true
        return
    end
    local gate = ns.gate or ns.CreateGate()
    local ref = ""
    if not ns.SelStore().disabled then
        local id = ns.GetSelected()
        if id then ref = ns.GetItemRef(id) end
    end
    gate:SetAttribute("bossonly", ns.BossOnlyActive() and true or false)
    gate:SetAttribute("state-sel", ref)
    -- Re-apply even when neither value changed (no OnAttributeChanged then).
    SecureHandlerExecute(gate, GATE_APPLY)
end

-- (The addon intentionally never edits your macro's #showtooltip line or icon.)
