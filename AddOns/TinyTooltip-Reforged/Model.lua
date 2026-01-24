
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltipReforged

LibEvent:attachTrigger("tooltip:init", function(self, tip)
    if (tip ~= GameTooltip) then return end
    if (not GameTooltip.model) then
        GameTooltip.model = CreateFrame("PlayerModel", nil, tip)
        GameTooltip.model:SetSize(100, 100)
        GameTooltip.model:SetFacing(-0.25)
        GameTooltip.model:SetPoint("BOTTOMRIGHT", tip, "TOPRIGHT", 8, -16)
        GameTooltip.model:Hide()
        GameTooltip.model:SetScript("OnUpdate", function(self, elapsed)
            if (IsControlKeyDown() or IsAltKeyDown()) then
                self:SetFacing(self:GetFacing() + math.pi * elapsed)
            end
        end)
    end
end)

LibEvent:attachTrigger("tooltip:unit", function(self, tip, unit)
    if (tip ~= GameTooltip) then return end
    if (not UnitIsVisible(unit)) then return end
    if (addon.db.unit.player.showModel and UnitIsPlayer(unit)) then
        if (tip.model) then
            tip.model:SetUnit(unit)
            tip.model:SetFacing(-0.25)
            tip.model:Show()
        end
    elseif (addon.db.unit.npc.showModel and not UnitIsPlayer(unit)) then
        if (tip.model) then
            tip.model:SetUnit(unit)
            tip.model:SetFacing(-0.25)
            tip.model:Show()
        end
    else
        if (tip.model) then
            tip.model:ClearModel()
            tip.model:Hide()
        end
    end
end)

LibEvent:attachTrigger("tooltip:cleared", function(self, tip)
    if (tip ~= GameTooltip) then return end
    if (tip.model) then
        tip.model:ClearModel()
        tip.model:Hide()
    end
end)
