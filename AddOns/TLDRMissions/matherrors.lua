-- some combatlogs have integer * percentage math outputs that are not consistent
-- have not been able to explain the discrepancy any other way
-- some of them round in ways that cannot even be explained by a floating point binary math rounding error

local addonName = "TLDRMissions"
local addon = _G[addonName]

local knownErrors = {
  {input = {175, -60}, output = -105.5},
  {input = {195, -60}, output = -117.5, restrictTo = {"Bone Shield (shield)"}},
  {input = {180, 130}, output = 233},
  {input = {360, 70}, output = 251},
  {input = {350, 130}, output = 454},
  {input = {120, 80}, output = 95, restrictTo = {"Shield Bash"}},
  {input = {230, 40}, output = 91, restrictTo = {"Shield of Tomorrow (Main)"}},
  {input = {240, 40}, output = 95, restrictTo = {"Shield of Tomorrow (Main)"}},
  {input = {145, 40}, output = 57, restrictTo = {"Shield of Tomorrow (Main)"}},
  {input = {180, -60}, output = -109},
  {input = {205, -60}, output = -123.2},
  {input = {210, -60}, output = -126.2},
  {input = {190, -60}, output = -114.8},
  {input = {200, -60}, output = -120.2},
  {input = {66.8, 125}, output = 82},
  {input = {35, 125}, output = 44},
  {input = {165, -60}, output = -99.5},
  
  -- mission 2303: enemies buff each other by 25.2 each tick, and a log with no other buffs confirms this .2 never gets rounded until the final step
  -- there is a conflict with the .2 against other buffs, seen with "hold the line" reducing taken by 10%
  {input = {151.2, 90}, output = 135}, -- log 20
  {input = {201.6, 90}, output = 180}, -- log 20 and conflict with log 24
  {input = {226.8, 90}, output = 203}, -- log 20
  
  {input = {276.18, 90}, output = 249},
  {input = {135, 40}, output = 53, restrictTo = {"Shield of Tomorrow (Main)"}},
  {input = {220, 40}, output = 87, restrictTo = {"Shield of Tomorrow (Main)"}},
  {input = {140, 40}, output = 55, restrictTo = {"Shield of Tomorrow (Main)"}},
  {input = {37, 90}, output = 32, restrictTo = {"Shield of Tomorrow (Main)", "Shield of Tomorrow (Alt)"}},
  {input = {37, 140}, output = 50},
  {input = {330, 40}, output = 131, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {360, 80}, output = 287, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {210, 80}, output = 167, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {230, 80}, output = 183, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {70, 40}, output = 27, restrictTo = {"Shield of Tomorrow (Alt)", "Shield of Tomorrow (Main)"}},
  {input = {105, 40}, output = 41, restrictTo = {"Shield of Tomorrow (Alt)", "Shield of Tomorrow (Main)"}},
  {input = {200, 70}, output = 139, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {200, 80}, output = 159, restrictTo = {"Shield of Tomorrow (Alt)", "Shield of Tomorrow (Main)"}},
  {input = {140, 70}, output = 97, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {140, 80}, output = 111, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {150, 60}, output = 89, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {150, 80}, output = 119, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {105, 80}, output = 83, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {230, 60}, output = 137, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {230, 70}, output = 160, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {100, 80}, output = 79, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {120, 80}, output = 95, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {155, 80}, output = 123, restrictTo = {"Shield of Tomorrow (Alt)"}},
  {input = {220, 80}, output = 175, restrictTo = {"Shield of Tomorrow (Main)"}},
  {input = {330, 30}, output = 98, restrictTo = {"Shield of Tomorrow (Main)"}},
}

function addon:multiplyPercentageWithErrors(a, b, buffs)
    for _, data in pairs(knownErrors) do
        local continue = true
        if data.restrictTo then
            continue = false
            for _, r in pairs(data.restrictTo) do
                if buffs[1] and (buffs[1] == r) then continue = true end
                --for _, buff in pairs(buffs) do
                --    if buff == r then
                --        continue = true
                --    end
                --end
            end
        end
        if continue then
            if (data.input[1] == a) and (data.input[2] == b) then
                return data.output
            end
        end
    end
    return (a*b)/100
end

local knownAdditionErrors = {
    {input = {99, -63}, output = 35},
    {input = {97, -63}, output = 33},
    {input = {122, -63}, output = 58},
    {input = {73, -63}, output = 9},
    {input = {161, -99}, output = 61},
    {input = {188.8, -100.8}, output = 87},
}

function addon:additionWithErrors(a, b)
    for _, data in pairs(knownAdditionErrors) do
        if (data.input[1] == a) and (data.input[2] == b) then
            return data.output
        end
    end
    return a + b
end