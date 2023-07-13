local myname, ns = ...

local HandyNotes = LibStub("AceAddon-3.0"):GetAddon("HandyNotes")
local HL = LibStub("AceAddon-3.0"):NewAddon(myname, "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(myname, false)
local HN = HandyNotes:GetModule("HandyNotes")

ns.HL = HL

local next = next
local GameTooltip = GameTooltip
local HandyNotes = HandyNotes

------------------ 
-- Tooltip handling
local function handle_tooltip(tooltip, point)
    if point then
        tooltip:SetText(point.title)
        tooltip:AddLine(point.desc)
    else
        tooltip:SetText(UNKNOWN)
    end
    tooltip:Show()
end
local handle_tooltip_by_coord = function(tooltip, uiMapId, coord)
    return handle_tooltip(tooltip, ns.points[uiMapId] and ns.points[uiMapId][coord])
end


-----
-- Handler
local HLHandler = {}

function HLHandler:OnEnter(uiMapId, coord)
    local tooltip = GameTooltip
    if ( self:GetCenter() > UIParent:GetCenter() ) then -- compare X coordinate
        tooltip:SetOwner(self, "ANCHOR_LEFT")
    else
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
    end
    handle_tooltip_by_coord(tooltip, uiMapId, coord)
end

function HLHandler:OnLeave(uiMapId, coord)
    GameTooltip:Hide()
end

do
    -- This is a custom iterator we use to iterate over every node in a given zone
    local function iter(t, prestate)
        if not t then return nil end
        local state, value = next(t, prestate)
        while state do -- Have we reached the end of this zone?
            if value then
                return state, nil, HN.icons[value.icon], ns.db.icon_scale, ns.db.icon_alpha
            end
            state, value = next(t, state) -- Get next data
        end
        return nil, nil, nil, nil
    end
    function HLHandler:GetNodes2(uiMapId, minimap)
        return iter, ns.points[uiMapId], nil
    end
end


---------------------------------------------------------
-- Addon initialization, enabling and disabling

function HL:OnInitialize()
    -- Set up our database
    self.db = LibStub("AceDB-3.0"):New(myname.."DB", ns.defaults)
    ns.db = self.db.profile
    ns.hidden = self.db.char.hidden
    -- Initialize our database with HandyNotes
    HandyNotes:RegisterPluginDB(myname:gsub("HandyNotes_", ""), HLHandler, ns.options)

    -- watch for LOOT_CLOSED
    self:RegisterEvent("LOOT_CLOSED")
end

function HL:Refresh()
    self:SendMessage("HandyNotes_NotifyUpdate", myname:gsub("HandyNotes_", ""))
end

function HL:LOOT_CLOSED()
    self:Refresh()
end
