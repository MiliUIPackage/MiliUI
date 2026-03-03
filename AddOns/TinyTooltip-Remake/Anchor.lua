
local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")

local GetMouseFocus = GetMouseFocus or GetMouseFoci

local addon = TinyTooltip

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
        AnchorDefaultPosition(tip, parent, addon.db.general.anchor, true)
    else
        LibEvent:trigger("tooltip.anchor.static", tip, parent, anchor.x, anchor.y, anchor.p)
    end
end

local function AnchorFrame(tip, parent, anchor, isUnitFrame, finally)
    if (not anchor) then return end
    if (anchor.hiddenInCombat and InCombatLockdown()) then
        return LibEvent:trigger("tooltip.anchor.none", tip, parent)
    end
    if (anchor.returnInCombat and InCombatLockdown()) then return AnchorDefaultPosition(tip, parent, anchor, finally) end
    if (anchor.returnOnUnitFrame and isUnitFrame) then return AnchorDefaultPosition(tip, parent, anchor, finally) end
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
        AnchorFrame(tip, parent, addon.db.general.anchor, isUnitFrame, true)
    elseif (anchor.position == "static") then
        LibEvent:trigger("tooltip.anchor.static", tip, parent, anchor.x, anchor.y, anchor.p)
    end
end

LibEvent:attachTrigger("tooltip:anchor", function(self, tip, parent)
    if (tip ~= GameTooltip) then return end
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
    if (UnitIsPlayer(unit)) then
        AnchorFrame(tip, parent, addon.db.unit.player.anchor, isUnitFrame)
    elseif (UnitExists(unit)) then
        AnchorFrame(tip, parent, addon.db.unit.npc.anchor, isUnitFrame)
    else
        AnchorFrame(tip, parent, addon.db.general.anchor, isUnitFrame)
    end
end)
