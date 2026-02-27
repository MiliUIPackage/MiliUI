local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local YOU = YOU
local NONE = NONE
local EMPTY = EMPTY
local TARGET = TARGET
local TOOLTIP_UPDATE_TIME = TOOLTIP_UPDATE_TIME or 0.1

local addon = TinyTooltipReforged

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

local function IsTargetToken(unit)
    if (type(unit) ~= "string") then
        return false
    end
    local ok, res = pcall(function()
        return unit:match("target$")
    end)
    return ok and res ~= nil
end

local function SafeBoolEval(fn, ...)
    return SafeBool(fn, ...)
end

local function GetUnitSettings()
    local db = addon.db
    if (not db or not db.unit) then
        return
    end
    return db.unit.player, db.unit.npc
end

local function SafeIsUnit(unit, other)
    return SafeBoolEval(UnitIsUnit, unit, other)
end

local function GetTargetString(unit)
    if (not UnitExists(unit)) then return end
    local name = UnitName(unit)
    local icon = addon:GetRaidIcon(unit) or ""
    if SafeBool(UnitIsUnit, unit, "player") then
        return format("|cffff3333>>%s<<|r", strupper(YOU))
    elseif SafeBool(UnitIsPlayer, unit) then
        local class = select(2, UnitClass(unit))
        local colorCode = select(4, GetClassColor(class))
        return format("|c%s%s|r", colorCode or "ffffffff", name)
    elseif SafeBool(UnitIsOtherPlayersPet, unit) then
        return format("|cff%s<%s>|r (Pet)", addon:GetHexColor(GameTooltip_UnitColor(unit)), name)
    else
        return format("|cff%s[%s]|r", addon:GetHexColor(GameTooltip_UnitColor(unit)), name)
    end
    return format("[%s]", name)
end

GameTooltip:HookScript("OnUpdate", function(tip, elapsed)
    if (not SafeBool(UnitExists, "mouseover")) then return end
    local isPlayer = SafeBool(UnitIsPlayer, "mouseover")
    if (addon.db.unit.player.showTarget and isPlayer)
        or (addon.db.unit.npc.showTarget and not isPlayer) then
        local line = addon:FindLine(tip, "^"..TARGET..":")
        local text = GetTargetString("mouseovertarget")
        if (line and not text) then
            addon:HideLine(tip, "^"..TARGET..":") 
        elseif (not line and text) then
            tip:AddLine(format("%s: %s", TARGET, text))
            tip:AddLine(" ")
	    tip:Show() 
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
                tip:Show()
            end
        end
    end
    if (count > 0 and not isPlayer and prefix ~= "party") then
        return format("|cff33ffff%s|r", count)
    end
end

LibEvent:attachTrigger("tooltip:unit", function(self, tip, unit)
    if (unit and SafeIsUnit(unit, "mouseover")) then
        local num = GetNumGroupMembers()
        if (num >= 1) then
          local player, npc = GetUnitSettings()
          if (not player or not npc) then return end
          local isPlayer = SafeBool(UnitIsPlayer, "mouseover")
          if ((addon.db.unit.player.showTargetBy and isPlayer)
          or (addon.db.unit.npc.showTargetBy and not isPlayer)) then
            local text = GetTargetByString("mouseover", num, tip)
            if (text) then
                tip:AddLine(format("%s: %s", addon.L and addon.L.TargetBy or "Targeted By", text), nil, nil, nil, true)
                tip:Show()
            end 
          end
        end
    end
end)

