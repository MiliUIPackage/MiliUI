
function WeekKeys:OnCommReceived(prefix, message, chat, sender)
    if sender == UnitName("player") then
        return
    end
    if WeekKeys[prefix] and WeekKeys[prefix][chat] then
        WeekKeys[prefix][chat](message,sender)
    end
end

WeekKeys:RegisterComm("AstralKeys")
WeekKeys:RegisterComm("WeekKeys")
-- /run WeekKeys:SendCommMessage("WeekKeys","request","GUILD")

WeekKeys.AstralKeys = {}
WeekKeys.WeekKeys = {}
function WeekKeys.AstralKeys.GUILD(msg, sender)
    local guildName = GetGuildInfo("player");
    WeekKeysDB.Guild = WeekKeysDB.Guild or {}
    WeekKeysDB.Guild[guildName] = WeekKeysDB.Guild[guildName] or {}

    local cmd, text = strsplit(" ",msg,2)
    if cmd == "updateV8" then
        local char, classname, keyid, keylevel, record, week = strsplit(":",text) -- split AstralKeys data
        local name, realm = strsplit("-",char) -- split name and realm
        local classnum
        for i=1, GetNumClasses() do
            className, classFile, classID = GetClassInfo(i)
            if classFile == classname then
                classnum = i
            end
        end

        local myname, myrealm = UnitFullName("player")
        if not (name == myname and myrealm == realm) then
            WeekKeys.DB.SaveVars(WeekKeysDB.Guild[guildName], name, realm, classnum, nil, record, keyid, keylevel, faction, nil)
        end
    elseif cmd == "sync5" then
        local char
        while text and text:len() > 0 do
            local classnum
            char, text = strsplit("_",text,2)
            local name_realm, classname, keyid, keylevel, record, week, time = strsplit(":",char) -- split AstralKeys data
            local name, realm = strsplit("-",name_realm) -- split name and realm
            
            for i=1, GetNumClasses() do
                className, classFile, classID = GetClassInfo(i)
                if classFile == classname then
                    classnum = i
                end
            end

            if not (name == myname and myrealm == realm) then
                WeekKeys.DB.SaveVars(WeekKeysDB.Guild[guildName], name, realm, classnum, nil, record, keyid, keylevel, nil, nil)
            end
        end
    elseif cmd == "updateWeekly" then
        local name,realm = strsplit("-",sender)
        if not (name == myname and myrealm == realm) then
            WeekKeys.DB.SaveVars(WeekKeysDB.Guild[guildName], name, realm, nil, nil, text, nil, nil, nil, nil)
        end
    end
    
end
--/run WeekKeys.WeekKeys.PARTY("update3 " .. WeekKeys.DB.GetAllCovenant(WeekKeysDB.Characters),"sss")
function WeekKeys.WeekKeys.PARTY(msg,sender)
    local command, text = strsplit(" ",msg,2)

    if command == "request" then
        local str = "update4 "
        for _,b in pairs(WeekKeysDB.Characters) do
            str = str .. "_" .. WeekKeys.Convert.TblToStr("update4",b)
        end

        WeekKeys:SendCommMessage("WeekKeys",str,"PARTY")
    elseif command:find("update%d+") then
        local char
        local tbl = {}
        while text and text:len() > 0 do

            char, text = strsplit("_",text,2)
            WeekKeys.Convert.StrToTbl(command, char, tbl)
            tbl.sender = sender
            WeekKeys.DB.SaveTable(WeekKeys.PartyDB, tbl)
            table.wipe(tbl)
        end
    end
end

function WeekKeys.WeekKeys.GUILD(msg,sender)
    local command, text = strsplit(" ",msg,2)
    if msg == "request" then

        local str = "update4 "
        for _,b in pairs(WeekKeysDB.Characters) do
            str = str .. "_" .. WeekKeys.Convert.TblToStr("update4",b)
        end

        --WeekKeys:SendCommMessage("WeekKeys","update3 " .. WeekKeys.DB.GetAllCovenant(WeekKeysDB.Characters),"GUILD")
        WeekKeys:SendCommMessage("WeekKeys",str,"GUILD")
    elseif command:find("update%d+") then
        local char
        while text and text:len() > 0 do
            local tbl = {}
            local guildName = GetGuildInfo("player");
            WeekKeysDB.Guild = WeekKeysDB.Guild or {}
            WeekKeysDB.Guild[guildName] = WeekKeysDB.Guild[guildName] or {}

            char, text = strsplit("_",text,2)
            WeekKeys.Convert.StrToTbl(command, char, tbl)
            tbl.sender = sender
            WeekKeys.DB.SaveTable(WeekKeysDB.Guild[guildName], tbl)
            --WeekKeys.DB.SaveCovenantChar(WeekKeysDB.Guild[guildName],WeekKeys.Convert.StringToVars(char,sender))
        end
    end
end

function WeekKeys.WeekKeys.Friend(msg,sender)
    local command, text = strsplit(" ",msg,2)
    --print(command, text)
    if msg == "request" then
        for _,b in pairs(WeekKeysDB.Characters) do
            WeekKeys.BNAddMsg("WeekKeys","update4 "..WeekKeys.Convert.TblToStr("update4",b),sender)
        end
       
    elseif command == "update%d+" then
        local char
       -- print("upadte")
        if not WeekKeys.FriendBattleTag[sender] then
            local i = 1
            while C_BattleNet.GetFriendAccountInfo(i) do
                local friend = C_BattleNet.GetFriendAccountInfo(i)
                local id = friend.gameAccountInfo.gameAccountID
                local battleTag = friend.battleTag
                if id and friend.gameAccountInfo.clientProgram == "WoW" then
                    WeekKeys.FriendBattleTag[id] = battleTag
                    WeekKeys.BNAddMsg("WeekKeys","request",id)
                end
                i = i + 1
            end
        end
        WeekKeysDB.Friends[WeekKeys.FriendBattleTag[sender]] = WeekKeysDB.Friends[WeekKeys.FriendBattleTag[sender]] or {}
        while text and text:len() > 0 do
            local tbl = {}
            char, text = strsplit("_",text,2)
            WeekKeys.Convert.StrToTbl(command, char, tbl)
            WeekKeys.DB.SaveTable(WeekKeysDB.Friends[WeekKeys.FriendBattleTag[sender]], tbl)
        end
    end
end


function WeekKeys.AstralKeys.Friend(msg,sender)
    local command, text = strsplit(" ",msg,2)
    if command == "sync4" then
        local char
        local i = 1
        while C_BattleNet.GetFriendAccountInfo(i) do
            local friend = C_BattleNet.GetFriendAccountInfo(i)
            local id = friend.gameAccountInfo.gameAccountID
            local battleTag = friend.battleTag
            if id then
                WeekKeys.FriendBattleTag[id] = battleTag
            end
            i = i + 1
        end
        while text and text:len() > 0 do
            local classnum
            char, text = strsplit("_",text,2)
            local name_realm, classname, keyid, keylevel,_,_, faction, record = strsplit(":",char) -- split AstralKeys data
            local name, realm = strsplit("-",name_realm) -- split name and realm
            
            for i=1, GetNumClasses() do
                className, classFile, classID = GetClassInfo(i)
                if classFile == classname then
                    classnum = i
                end
            end
            if tonumber(faction) == 0 then
                faction = "A"
            else
                faction = "H"
            end
            
            WeekKeysDB.Friends[WeekKeys.FriendBattleTag[sender]] = WeekKeysDB.Friends[WeekKeys.FriendBattleTag[sender]] or {}
            WeekKeys.DB.SaveVars( WeekKeysDB.Friends[WeekKeys.FriendBattleTag[sender]], name, realm, classnum, nil, record, keyid, keylevel, faction, nil)
        end
    elseif msg == "BNet_query ping" then
        local astralweeks
        local time
        if GetCurrentRegion() == 3 then -- if in EU region
            astralweeks = math.floor((GetServerTime() - 1500447600) / 604800) 
            time = math.floor((GetServerTime() - 1500447600) % 604800) 
        else -- if not EU region
            astralweeks = math.floor((GetServerTime() - 1500390000) / 604800)
            time = math.floor((GetServerTime() - 1500390000) % 604800)
        end
        WeekKeys.BNAddMsg("AstralKeys","BNet_query response",sender)
        local name, realm, classID, _, record, keyID, keyLevel, faction, _ = WeekKeys.PlayerData()
        record = strsplit("/",record or "")
        faction = (faction == "A") and 0 or 1
      --  print("AstralKeys",string.format("sync4 %s-%s:%s:%d:%d:%d:%d:%d:%d_",name,realm,GetClassInfo(classID),keyID,keyLevel,astralweeks,0,faction,record),sender)
        if keyID then  
            WeekKeys.BNAddMsg("AstralKeys",string.format("sync4 %s-%s:%s:%d:%d:%d:%d:%d:%d_",name,realm,select(2,GetClassInfo(classID)),keyID,keyLevel,astralweeks,0,faction,record),sender)
        end  -- name-server:class:mapID:keyLevel: week#:weekTime:faction:weekly
    --WeekKeys.PlayerData()
         end
end
WeekKeys.frame = CreateFrame("frame")
WeekKeys.frame:RegisterEvent("BN_CHAT_MSG_ADDON")
WeekKeys.frame:SetScript("OnEvent",function(self, event, prefix, text, channel ,id)
    if WeekKeys[prefix] and WeekKeys[prefix].Friend then
        WeekKeys[prefix].Friend(text,id)
    end
end)
local prefix = {}
local message = {}
local target = {}
function WeekKeys.BNAddMsg(pref,msg,tar)
    if not prefix or not msg or not target or msg == "" then
        return
    end
    prefix[#prefix+1] = pref
    message[#message+1] = msg
    target[#target+1] = tar
end
function WeekKeys.BNSend()
    if #prefix == 0 then
        return
    end
 --  print(target[1],prefix[1],message[1])
    BNSendGameData(target[1],prefix[1],message[1])
    tremove(prefix,1)
    tremove(message,1)
    tremove(target,1)
end

local hand = C_Timer.NewTicker(0.2, WeekKeys.BNSend)
