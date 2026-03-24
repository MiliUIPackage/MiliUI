
local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")

local GetMouseFocus = GetMouseFocus or GetMouseFoci

local addon = TinyTooltip
local modifierStateOverrideKey
local modifierStateOverrideDown
local dbGeneralAnchor
local dbPlayerAnchor
local dbNpcAnchor

local function CacheAnchorSetting()
    local db = addon and addon.db
    if (not db) then
        dbGeneralAnchor = nil
        dbPlayerAnchor = nil
        dbNpcAnchor = nil
        return
    end
    local general = db.general
    local unit = db.unit
    dbGeneralAnchor = general and general.anchor
    local player = unit and unit.player
    local npc = unit and unit.npc
    dbPlayerAnchor = player and player.anchor
    dbNpcAnchor = npc and npc.anchor
end

local function IsConfiguredModifierDown(modifierKey)
    if (modifierKey and modifierKey == modifierStateOverrideKey and modifierStateOverrideDown ~= nil) then
        return modifierStateOverrideDown
    end
    if (modifierKey == "alt") then
        return IsAltKeyDown()
    elseif (modifierKey == "ctrl") then
        return IsControlKeyDown()
    elseif (modifierKey == "shift") then
        return IsShiftKeyDown()
    end
    return false
end

local function GetAnchorModifierKey(anchor)
    local modifierKey = anchor and anchor.modifierShowInCombatKey
    if (modifierKey == "global") then
        modifierKey = dbGeneralAnchor and dbGeneralAnchor.modifierShowInCombatKey
    end
    if (modifierKey == "alt" or modifierKey == "ctrl" or modifierKey == "shift") then
        return modifierKey
    end
    return "none"
end

local function ShouldHideInCombat(anchor)
    if (not anchor or not anchor.hiddenInCombat or not InCombatLockdown()) then
        return false
    end
    local modifierKey = GetAnchorModifierKey(anchor)
    if (modifierKey ~= "none" and IsConfiguredModifierDown(modifierKey)) then
        return false
    end
    return true
end

local function SafeSetOwner(frame, parent, anchor, ...)
    if (not parent or type(parent) ~= "table") then
        parent = UIParent
    end
    pcall(frame.SetOwner, frame, parent, anchor, ...)
end

local function AnchorCursorOnExecute(self)
    if (not self.tip:IsShown()) then return true end
    local anchorType = self.tip:GetAnchorType()
    if (anchorType ~= "ANCHOR_CURSOR" and anchorType ~= "ANCHOR_NONE") then return true end
    local x, y = GetCursorPosition()
    self.tip:ClearAllPoints()
    self.tip:SetPoint(self.cp, UIParent, "BOTTOMLEFT", floor(x/self.scale+self.cx), floor(y/self.scale+self.cy))
end

local function AnchorCursor(tip, parent, cp, cx, cy)
    local x, y = GetCursorPosition()
    local scale = tip:GetEffectiveScale()
    cp, cx, cy = cp or "BOTTOM", cx or 0, cy or 20
    tip:ClearAllPoints()
    tip:SetPoint(cp, UIParent, "BOTTOMLEFT", floor(x/scale+cx), floor(y/scale+cy))
    LibSchedule:AddTask({
        identity = tostring(tip),
        elasped  = 0.01,
        expired  = GetTime() + 300,
        override = true,
        tip      = tip,
        cp       = cp,
        cx       = cx,
        cy       = cy,
        scale    = scale,
        onExecute = AnchorCursorOnExecute,
    })
end

local function AnchorDefaultPosition(tip, parent, anchor, finally)
    if (finally) then
        LibEvent:trigger("tooltip.anchor.static", tip, parent, anchor.x, anchor.y)
    elseif (anchor.position == "inherit") then
        AnchorDefaultPosition(tip, parent, dbGeneralAnchor, true)
    else
        LibEvent:trigger("tooltip.anchor.static", tip, parent, anchor.x, anchor.y, anchor.p)
    end
end

local function AnchorFrame(tip, parent, anchor, isUnitFrame, finally, combatAnchor)
    local hideAnchor = combatAnchor or anchor
    if (hideAnchor and hideAnchor ~= dbGeneralAnchor and not hideAnchor.hiddenInCombat and not hideAnchor.returnInCombat and not hideAnchor.returnOnUnitFrame) then
        hideAnchor = dbGeneralAnchor
    end
    if (ShouldHideInCombat(hideAnchor)) then
        return LibEvent:trigger("tooltip.anchor.none", tip, parent)
    end
    if (not anchor) then return end
    if (hideAnchor and hideAnchor.returnInCombat and InCombatLockdown()) then return AnchorDefaultPosition(tip, parent, hideAnchor, finally) end
    if (hideAnchor and hideAnchor.returnOnUnitFrame and isUnitFrame) then return AnchorDefaultPosition(tip, parent, hideAnchor, finally) end
    if (anchor.position == "cursorRight") then
        LibEvent:trigger("tooltip.anchor.cursor.right", tip, parent)
    elseif (anchor.position == "cursor") then
        local offsetX = tonumber(anchor.cx) or 0
        local offsetY = tonumber(anchor.cy) or 0
        local point = anchor.cp
        if (offsetX == 0 and offsetY == 0 and (not point or point == "BOTTOM")) then
            LibEvent:trigger("tooltip.anchor.cursor", tip, parent)
        else
            SafeSetOwner(tip, parent, "ANCHOR_CURSOR")
            AnchorCursor(tip, parent, point, offsetX, offsetY)
        end
    elseif (anchor.position == "inherit" and not finally) then
        AnchorFrame(tip, parent, dbGeneralAnchor, isUnitFrame, true, hideAnchor)
    elseif (anchor.position == "static") then
        LibEvent:trigger("tooltip.anchor.static", tip, parent, anchor.x, anchor.y, anchor.p)
    end
end

local function GetMouseoverContext()
    local unit
    local focus = GetMouseFocus()
    local isUnitFrame = false
    if (focus and focus.unit) then
        unit = focus.unit
        isUnitFrame = true
    end
    if (not unit and focus and focus.GetAttribute) then
        unit = focus:GetAttribute("unit")
    end
    if (not unit) then
        unit = "mouseover"
    end

    local anchor
    if (UnitIsPlayer(unit)) then
        anchor = dbPlayerAnchor
    elseif (UnitExists(unit)) then
        anchor = dbNpcAnchor
    else
        anchor = dbGeneralAnchor
    end
    local combatAnchor = anchor
    if (anchor and anchor.position == "inherit") then
        anchor = dbGeneralAnchor
    end
    if (not combatAnchor) then
        combatAnchor = anchor
    end
    return unit, isUnitFrame, anchor, combatAnchor
end

LibEvent:attachTrigger("tooltip:anchor", function(self, tip, parent)
    if (tip ~= GameTooltip) then return end
    if (tip._tinySkipCustomAnchor) then
        tip._tinySkipCustomAnchor = nil
        return
    end
    local _, isUnitFrame, anchor, combatAnchor = GetMouseoverContext()
    AnchorFrame(tip, parent, anchor, isUnitFrame, nil, combatAnchor)
end)

local modifierWatcher = CreateFrame("Frame")
modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierWatcher:SetScript("OnEvent", function(_, _, key, state)
    if (not InCombatLockdown()) then return end
    local unit, isUnitFrame, anchor, combatAnchor = GetMouseoverContext()
    local ruleAnchor = combatAnchor
    if (ruleAnchor and ruleAnchor ~= dbGeneralAnchor and not ruleAnchor.hiddenInCombat and not ruleAnchor.returnInCombat and not ruleAnchor.returnOnUnitFrame) then
        ruleAnchor = dbGeneralAnchor
    end
    if (not UnitExists(unit) or not ruleAnchor or not ruleAnchor.hiddenInCombat) then return end
    local modifierKey = GetAnchorModifierKey(ruleAnchor)
    if (modifierKey == "none") then return end

    local isDown = tonumber(state) == 1
    key = key and strupper(key)
    if (modifierKey == "alt") then
        if (key ~= "LALT" and key ~= "RALT" and key ~= "ALT") then return end
    elseif (modifierKey == "ctrl") then
        if (key ~= "LCTRL" and key ~= "RCTRL" and key ~= "CTRL") then return end
    elseif (modifierKey == "shift") then
        if (key ~= "LSHIFT" and key ~= "RSHIFT" and key ~= "SHIFT") then return end
    else
        return
    end

    modifierStateOverrideKey = modifierKey
    modifierStateOverrideDown = isDown
    AnchorFrame(GameTooltip, GameTooltip:GetOwner() or UIParent, anchor, isUnitFrame, nil, ruleAnchor)
    local shouldHide = ShouldHideInCombat(ruleAnchor)
    if (isDown) then
        if (unit == "mouseover" and GameTooltip.SetMouseoverUnit) then
            pcall(GameTooltip.SetMouseoverUnit, GameTooltip)
        else
            pcall(GameTooltip.SetUnit, GameTooltip, unit)
        end
    end
    if (not shouldHide and not GameTooltip:IsShown()) then
        GameTooltip:Show()
    end
    modifierStateOverrideKey = nil
    modifierStateOverrideDown = nil
end)

CacheAnchorSetting()
LibEvent:attachTrigger("tooltip:variables:loaded, tooltip:variable:changed", function()
    CacheAnchorSetting()
end)

