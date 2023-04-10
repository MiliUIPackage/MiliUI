local folder = "Exlist/"

local files = {
    "Config",
    "Exlist",
    "Init",
    "Modules/Character",
    "Modules/Coins",
    "Modules/Currency",
    "Modules/Dungeons",
    "Modules/Emissaries",
    "Modules/Mail",
    "Modules/Missions",
    "Modules/MythicKey",
    "Modules/MythicPlus",
    "Modules/Note",
    "Modules/Quests",
    "Modules/Raids",
    "Modules/Reputation",
    "Modules/WorldBosses",
    "Modules/Worldquests",
    "Modules/WeeklyRewards"
}

local function parseFile(filename)
    local strings = {}
    local file = assert(io.open(string.format("%s%s.lua", folder or "", filename), "r"), "Could not open " .. filename)
    local text = file:read("*all")
    file:close()

    for match in string.gmatch(text, 'L%["(.-)"%]') do
        strings[match] = true
    end
    return strings
end

local ns_file = assert(io.open("Exlist_Translations.lua", "w"), "Error opening file")
for _, file in ipairs(files) do
    local strings = parseFile(file)

    local sorted = {}
    for k in next, strings do
        table.insert(sorted, k)
    end
    table.sort(sorted)
    if #sorted > 0 then
        for _, v in ipairs(sorted) do
            ns_file:write(string.format('L["%s"] = true\n', v))
        end
    end
    print("  (" .. #sorted .. ") " .. file)
end
ns_file:close()
