
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local YOU = YOU
local NONE = NONE
local EMPTY = EMPTY
local TARGET = TARGET
local TOOLTIP_UPDATE_TIME = TOOLTIP_UPDATE_TIME or 0.2

local addon = TinyTooltip

local function GetUnitSettings()
    local db = addon.db
    if (not db or not db.unit) then
        return
    end
    return db.unit.player, db.unit.npc
end

local function SafeBool(fn, ...)
    local ok, value = pcall(fn, ...)
    if (not ok) then
        return false
    end
    local okEval, result = pcall(function()
        return value == true
    end)
    if (okEval) then
        return result
    end
    return false
end

local unpack = table.unpack or unpack

local function SafeBoolEval(fn, ...)
    return SafeBool(fn, ...)
end

local function SafeIsUnit(unit, other)
    return SafeBoolEval(UnitIsUnit, unit, other)
end

local function SafeIsPlayer(unit)
    return SafeBoolEval(UnitIsPlayer, unit)
end

local function IsTargetToken(unit)
    if (type(unit) ~= "string") then
        return false
    end
    local ok, res = pcall(function()
        return unit:match("target$")
    end)
    return ok and res ~= nil
end

local function GetTargetString(unit)
    if (IsTargetToken(unit)) then
        local okName, name = pcall(UnitName, unit)
        if (not okName or type(name) ~= "string") then return end
        local icon = addon:GetRaidIcon(unit) or ""
        local r, g, b = GameTooltip_UnitColor(unit)
        if SafeIsUnit(unit, "player") then
            return format("|cffff3333>>%s<<|r", strupper(YOU))
        end
        if SafeIsPlayer(unit) then
            local class = select(2, UnitClass(unit))
            local colorCode = select(4, GetClassColor(class))
            return format("%s|c%s%s|r", icon, colorCode or "ffffffff", name)
        end
        if (r and g and b) then
            return format("%s|cff%s[%s]|r", icon, addon:GetHexColor(r, g, b), name)
        end
        return format("%s[%s]", icon, name)
    end
    if (type(unit) ~= "string") then return end
    if (not SafeBool(UnitExists, unit)) then return end
    local name = UnitName(unit)
    local icon = addon:GetRaidIcon(unit) or ""
    if SafeIsUnit(unit, "player") then
        return format("|cffff3333>>%s<<|r", strupper(YOU))
    elseif SafeIsPlayer(unit) then
        local class = select(2, UnitClass(unit))
        local colorCode = select(4, GetClassColor(class))
        return format("%s|c%s%s|r", icon, colorCode, name)
    elseif SafeBool(UnitIsOtherPlayersPet, unit) then
        return format("%s|cff%s<%s>|r", icon, addon:GetHexColor(GameTooltip_UnitColor(unit)), name)
    else
        return format("%s|cff%s[%s]|r", icon, addon:GetHexColor(GameTooltip_UnitColor(unit)), name)
    end
end

local function UpdateTargetLine(tip, targetUnit)
    local text = GetTargetString(targetUnit)
    local line = tip.ttTargetLine
    if (not text) then
        if (line) then
            line:SetText(nil)
            tip.ttTargetLine = nil
            if (addon.AutoSetTooltipWidth) then
                addon:AutoSetTooltipWidth(tip)
            end
        end
        return
    end
    local formatted = format("%s: %s", TARGET, text)
    if (not line) then
        tip:AddLine(formatted)
        line = _G[tip:GetName() .. "TextLeft" .. tip:NumLines()]
        tip.ttTargetLine = line
    else
        line:SetText(formatted)
    end
    if (addon.AutoSetTooltipWidth) then
        addon:AutoSetTooltipWidth(tip)
    end
    -- tip:Show()
    if (addon and addon.HideLine) then
        if (FACTION_ALLIANCE) then addon:HideLine(tip, "^" .. FACTION_ALLIANCE) end
        if (FACTION_HORDE) then addon:HideLine(tip, "^" .. FACTION_HORDE) end
        if (UNIT_POPUP_RIGHT_CLICK) then addon:HideLine(tip, UNIT_POPUP_RIGHT_CLICK) end
    end
    if (addon and addon.db and addon.db.general and addon.db.general.hideUnitFrameHint) then
        for i = 2, tip:NumLines() do
            local line = _G[tip:GetName() .. "TextLeft" .. i]
            local text
            if (line and line.GetText) then
                local ok, value = pcall(line.GetText, line)
                if (ok) then
                    text = value
                end
            end
            if (type(text) == "string") then
                if (issecretvalue and issecretvalue(text)) then
                    -- can't safely read/strip secret text
                else
                    local ok, stripped = pcall(function()
                        local s = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                        return s:gsub("^%s+", ""):gsub("%s+$", "")
                    end)
                    if (ok and type(stripped) == "string") then
                        if (UNIT_POPUP_RIGHT_CLICK and stripped == UNIT_POPUP_RIGHT_CLICK) then
                            line:SetText(nil)

                        end
                    end
                end
            end
        end
    end
    -- tip:Show()
end

LibEvent:attachTrigger("tooltip:unit", function(self, tip, unit)
    tip.ttIsUnit = true
    local player, npc = GetUnitSettings()
    if (not player or not npc) then return end
    if SafeIsUnit(unit, "player") then
        if (player.showTarget) then
            UpdateTargetLine(tip, "playertarget")
        else
            UpdateTargetLine(tip)
        end
    elseif SafeIsUnit(unit, "mouseover") then
        local isPlayer = SafeBool(UnitIsPlayer, "mouseover")
        if ((isPlayer and player.showTarget)
            or (not isPlayer and npc.showTarget)) then
            UpdateTargetLine(tip, "mouseovertarget")
        else
            UpdateTargetLine(tip)
        end
    else
        if (type(unit) ~= "string") then return end
        local isPlayer = SafeBool(UnitIsPlayer, unit)
        if ((isPlayer and not player.showTarget)
            or (not isPlayer and not npc.showTarget)) then
            UpdateTargetLine(tip)
            return
        end
        local okConcat, targetUnit = pcall(function() return unit .. "target" end)
        if (not okConcat or type(targetUnit) ~= "string") then return end
        if (SafeBool(UnitExists, targetUnit)) then
            UpdateTargetLine(tip, targetUnit)
        end
    end
end)

LibEvent:attachTrigger("tooltip:item, tooltip:spell", function(self, tip)
    tip.ttIsUnit = false
    if (tip.ttTargetLine) then
        tip.ttTargetLine:SetText(nil)
        tip.ttTargetLine = nil
    end
end)

LibEvent:attachTrigger("tooltip:cleared, tooltip:hide", function(self, tip)
    if (tip) then
        tip.ttTargetLine = nil
        tip.ttIsUnit = nil
    end
end)

GameTooltip:HookScript("OnUpdate", function(self, elapsed)
    self.updateElapsed = (self.updateElapsed or 0) + elapsed
    if (self.updateElapsed >= TOOLTIP_UPDATE_TIME) then
        self.updateElapsed = 0
        local owner = self:GetOwner()
        if (owner and (owner.unit or (owner.GetAttribute and owner:GetAttribute("unit")))) then
            return
        end
        if (not self.ttIsUnit) then return end
        if (not SafeBool(UnitExists, "mouseover")) then return end
        local isPlayer = SafeBool(UnitIsPlayer, "mouseover")
        local player, npc = GetUnitSettings()
        if (not player or not npc) then return end
        if (player.showTarget and isPlayer)
            or (npc.showTarget and not isPlayer) then
            UpdateTargetLine(self, "mouseovertarget")
        end
    end
end)


-- Targeted By

local function GetTargetByString(mouseover, num, tip)
    local count, prefix = 0, IsInRaid() and "raid" or "party"
    local roleIcon, colorCode, name
    local first = true
    local isPlayer = SafeBool(UnitIsPlayer, mouseover)
    for i = 1, num do
        if SafeBool(UnitIsUnit, mouseover, prefix..i.."target") and not SafeBool(UnitIsUnit, prefix..i, "player") then
            count = count + 1
            if (isPlayer or prefix == "party") then
                if (first) then
                    tip:AddLine(format("%s:", addon.L and addon.L.TargetBy or "Targeted By"))
                    first = false
                end
                roleIcon  = addon:GetRoleIcon(prefix..i) or ""
                colorCode = select(4,GetClassColor(select(2,UnitClass(prefix..i))))
                name      = UnitName(prefix..i)
                tip:AddLine("   " .. roleIcon .. " |c" .. colorCode .. name .. "|r")
            end
        end
    end
    if (count > 0 and not isPlayer and prefix ~= "party") then
        return format("|cff33ffff%s|r", count)
    end
end

LibEvent:attachTrigger("tooltip:unit", function(self, tip, unit)
    if (not UnitExists("mouseover")) then return end
    local num = GetNumGroupMembers()
    if (num >= 1) then
        local player, npc = GetUnitSettings()
        if (not player or not npc) then return end
        local isPlayer = SafeBool(UnitIsPlayer, "mouseover")
        if (player.showTargetBy and isPlayer)
          or (npc.showTargetBy and not isPlayer) then
            local text = GetTargetByString("mouseover", num, tip)
            if (text) then
                tip:AddLine(format("%s: %s", addon.L and addon.L.TargetBy or "Targeted By", text), nil, nil, nil, true)
            end
        end
    end
end)
