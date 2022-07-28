WeekKeys.Convert = {}
local convert = WeekKeys.Convert
function WeekKeys.Convert.StringToVars(str,sender) -- tabl -> [optional] table where to write information
    return strsplit(":",str..":"..sender:gsub(" ",""))
end

function WeekKeys.Convert.OldStringToVars(str,sender)
    str = str:gsub("Alliance","A"):gsub("Horde","H") .. ":" .. sender:gsub(" ","")
    for i = 1, 12 do
        local _, classFile, _ = GetClassInfo(i)
        local _, _, _, argbHex = GetClassColor(classFile)
        if str:find(argbHex) then
            str = str:gsub("|cff.+|r",i)
        end
    end
    return strsplit(":",str)
end

function WeekKeys.Convert.TableToString(tabl)
    return string.format("%s:%s:%s:%d:%s:%s:%s:%s",tabl.name or "", tabl.realm or "", tostring(tabl.classID or ""), tabl.ilvl or 0,
    tostring(tabl.record or ""), tostring(tabl.keyID or ""),tostring(tabl.keyLevel or ""), tabl.faction)
end

function WeekKeys.Convert.NewTableToString(tabl)
    return string.format("%d:%s:%s:%s:%d:%s:%s:%s:%s",tabl.covenant or 0,tabl.name or "", tabl.realm or "", tostring(tabl.classID or ""), tabl.ilvl or 0,
    tostring(tabl.record or ""), tostring(tabl.keyID or ""),tostring(tabl.keyLevel or ""), tabl.faction or "")
end

function WeekKeys.Convert.OldTableToString(tabl)
    local _, classFile, _ = GetClassInfo(tabl.classID)
    local _, _, _, argbHex = GetClassColor(classFile)
    local colored = "|c"..argbHex..tabl.name.."|r"
    local faction
    if tabl.faction == "A" then
        faction = "Alliance"
    else
        faction = "Horde"
    end
    return format("%s:%s:%s:%d:%s:%s:%s:%s",tabl.name, tabl.realm, colored, tabl.ilvl,
    (tabl.record or ""), (tabl.keyID or ""),(tabl.keyLevel or ""), faction)
end

---Convert string to table
---@param update_type string "update"..version
---@param data string formatted data
---@param tbl table table to save results
---@return table DataTable table with sorted data
function convert.StrToTbl(update_type,data,tbl)

    if not update_type then return end
    if not data or data == "" then return end
    if not WeekKeys.Patterns[update_type] then return end

    tbl = tbl or {}
    local pattern = WeekKeys.Patterns[update_type]
    local index = 1
    --/run for word in string.gmatch("a;b;c;d;e;;;;f;", "([^;]*);") do print("->"..word.."<-") end
    --/run for word in string.gmatch("a;b;c;d;e;;f;", '([^;]*);') do print(word) end
    for word in string.gmatch(data..":", '([^:]*):') do
        local key = pattern[index]

        if tonumber(word) then -- if string is number "123" => 123
            tbl[key] = tonumber(word)
        elseif word ~= "" then
            tbl[key] = word
        end

        index = index + 1
    end

    return tbl
end

---Convert table to string
---@param update_type string "update"..version
---@param data table data stored in table
---@return string fdata formatted data by update type
function convert.TblToStr(update_type,data)

    if not update_type then return end
    if not data then return end
    if not WeekKeys.Patterns[update_type] then return end

    local str = ""
    local pattern = WeekKeys.Patterns[update_type]

    for _,key in pairs(pattern) do
        if data[key] == nil then
            str = str .. ":"
        else
            str = str .. tostring(data[key]) .. ":"
        end
    end

    return str:sub(1,-2)
end


function convert.Player(player)

    local tbl = {}

    local _, classFile = GetClassInfo(player.classID)
    local _, _, _, argbHex = GetClassColor(classFile)
    tbl.colored = "|c"..argbHex..player.name.."|r"

    if player.realm ~= GetRealmName():gsub(' ','') then
        tbl.colored = tbl.colored .. " (*)"
    end

    local keystone = ""
    if player.keyID then
        keystone = string.format("%s (%d)",C_ChallengeMode.GetMapUIInfo(player.keyID), player.keyLevel)
        -- add icon if instance have covenant bonuss
        if player.keyID == 375 or player.keyID == 377 then
            keystone = "|Tinterface/icons/ui_sigil_nightfae.blp:20:20|t" .. keystone
        elseif player.keyID == 376 or player.keyID == 381 then
            keystone = "|Tinterface/icons/ui_sigil_kyrian.blp:20:20|t" .. keystone
        elseif player.keyID == 378 or player.keyID == 380 then
            keystone =  "|Tinterface/icons/ui_sigil_venthyr.blp:20:20|t" .. keystone
        elseif player.keyID == 379 or player.keyID == 382 then
            keystone =  "|Tinterface/icons/ui_sigil_necrolord.blp:20:20|t" .. keystone
        end
    end
    tbl.keystone = keystone

    tbl.realm = player.realm
    tbl.ilvl = player.ilvl
    tbl.record = player.record
    tbl.faction = player.faction
    tbl.covenant = player.covenant
    tbl.reward = player.reward
    tbl.mscore = player.mscore
    tbl.recordtable = player.recordtable
    tbl.ref = player

    return tbl
end
