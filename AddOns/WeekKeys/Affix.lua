WeekKeys.Affixes = {}
local curr_rotation = nil
local sesionalID = 120
local steps = 0
local AFFIXES = {
    [1] =  {[1]=10,[2]=11,[3]=3,[4]=121},
    [2] =  {[1]=9,[2]=7,[3]=124,[4]=121},
    [3] =  {[1]=10,[2]=123,[3]=12,[4]=121},
    [4] =  {[1]=9,[2]=122,[3]=4,[4]=121},
    [5] =  {[1]=10,[2]=8,[3]=14,[4]=121},
    [6] =  {[1]=9,[2]=6,[3]=13,[4]=121},
    [7] =  {[1]=10,[2]=123,[3]=3,[4]=121},
    [8] =  {[1]=9,[2]=7,[3]=4,[4]=121},
    [9] =  {[1]=10,[2]=122,[3]=124,[4]=121},
    [10] = {[1]=9,[2]=11,[3]=13,[4]=121},
    [11] = {[1]=10,[2]=8,[3]=12,[4]=121},
    [12] = {[1]=9,[2]=6,[3]=14,[4]=121}
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
