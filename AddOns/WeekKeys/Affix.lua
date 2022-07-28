WeekKeys.Affixes = {}
local curr_rotation = nil
local sesionalID = 120
local steps = 0
local AFFIXES = {
    {9,7,13},
    {10,11,124},
    {9,6,3},
    {10,122,12},
    {9,123,4},
    {10,7,14},
    {9,8,124},
    {10,6,13},
    {9,11,3},
    {10,123,4},
    {9,122,14},
    {10,8,12},
}

function WeekKeys.Affixes.init()
    local affixes = C_MythicPlus.GetCurrentAffixes()
    if not affixes then
        return
    end
    for index,value in pairs(AFFIXES) do
        if value[1] == affixes[1].id and value[2] == affixes[2].id and value[3] == affixes[3].id then
            curr_rotation = index
            sesionalID = affixes[4].id
        end
    end
    affixes = nil
end
function WeekKeys.Affixes.GetAffixes()
    if curr_rotation == nil and C_MythicPlus.GetCurrentAffixes() then
        local affixes = C_MythicPlus.GetCurrentAffixes()
        return affixes[1].id, affixes[2].id, affixes[3].id, affixes[4].id
    elseif curr_rotation == nil then
        return
    end
    if curr_rotation + steps > 12 then
        return AFFIXES[(curr_rotation + steps) % #AFFIXES][1],AFFIXES[(curr_rotation + steps) % #AFFIXES][2],AFFIXES[(curr_rotation + steps) % #AFFIXES][3],sesionalID
    else
        return AFFIXES[curr_rotation + steps][1],AFFIXES[curr_rotation + steps][2],AFFIXES[curr_rotation + steps][3],sesionalID
    end
end

function WeekKeys.Affixes.Next()
    if steps > 11 or curr_rotation == nil then
        return
    else
        steps = steps + 1
    end
end

function WeekKeys.Affixes.Previous()
    if steps < 1 or curr_rotation == nil then
        return
    else
        steps = steps - 1
    end
end

function WeekKeys.Affixes.GetSteps()
    return steps
end
