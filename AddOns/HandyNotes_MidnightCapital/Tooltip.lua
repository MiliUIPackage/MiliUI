local addonName, ns = ...
local L = ns.L

local CATEGORY_NAMES = {
    services = L.CATEGORY_SERVICES,
    professions = L.CATEGORY_PROFESSIONS,
    activities = L.CATEGORY_ACTIVITIES,
    travel = L.CATEGORY_TRAVEL,
    portals = L.CATEGORY_PORTALS,
}

function ns.PrepareTooltip(tooltip, node)
    tooltip:SetText(node.title, 1, 1, 1)

    local categoryName = CATEGORY_NAMES[node.category] or node.category
    tooltip:AddLine(categoryName, 0.6, 0.6, 0.6)

    if node.desc then
        tooltip:AddLine(node.desc, 1, 0.82, 0, true)
    end

    if node.npc then
        tooltip:AddLine(node.npc, 0.1, 1, 0.1)
    end

    tooltip:AddLine(L.CLICK_TO_SET_WAYPOINT, 0.7, 0.7, 0.7)

    tooltip:Show()
end
