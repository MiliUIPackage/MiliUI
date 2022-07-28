WeekKeys.DB = {}
function WeekKeys.DB.RemoveReward()
    local player = UnitName("player")
    for _,v in pairs(WeekKeysDB.Characters) do
        if v.name == player then
            v.reward = nil
        end
    end
end
-- /dump WeekKeys.DB.OldGetAllByFaction(WeekKeysDB.Characters)
function WeekKeys.DB.OldGetAllByFaction(DB)
    local faction = UnitFactionGroup("player"):sub(1,1)
    local str = ""
    for _,playerdata in pairs(DB) do
        if playerdata.faction == faction then
            str = str .. "_" .. WeekKeys.Convert.OldTableToString(playerdata)
        end
    end
    return select(2,strsplit("_",str))
end

function WeekKeys.DB.GetAllByFaction(DB)
    local faction = UnitFactionGroup("player"):sub(1,1)
    local str = ""
    for _,playerdata in pairs(DB) do
        if playerdata.faction == faction then
            str = str .. "_" .. WeekKeys.Convert.TableToString(playerdata)
        end
    end
    return str
end

function WeekKeys.DB.GetAll(DB)
    if not DB then
        return
    end
    local str = ""
    for _,playerdata in pairs(DB) do
        str = str .. "_" .. WeekKeys.Convert.TableToString(playerdata)
    end
    return str
end
function WeekKeys.DB.GetAllCovenant(DB)
    if not DB then
        return
    end
    local str = ""
    for _,playerdata in pairs(DB) do
        str = str .. "_" .. WeekKeys.Convert.NewTableToString(playerdata)
    end
    return str
end

function WeekKeys.DB.SaveCovenantChar(DB,covenantID, name, realm, classID, ilvl, record, keyid, keylevel, faction, sender)
    if (not name) or (not realm) or (name == "") or (realm == "") or (not tonumber(classID)) then
        return
    end
    for k,v in pairs(DB) do
        if v.name == name and v.realm == realm then
            if v.covenant then
                v.covenant = covenantID
            end
            if record then
                v.record = record
            end
            if ilvl then
                v.ilvl = tonumber(ilvl)
            end
            if classID then
                v.classID = tonumber(classID)
            end
            
            v.keyID = tonumber(keyid)
            
            if keylevel then
                v.keyLevel = tonumber(keylevel)
            end
            if faction then
                v.faction = faction
            end
            if sender then
                v.sender = sender
            end
            return
        end
    end
    tinsert(DB,{
        ["covenant"] = covenantID,
        ["name"] = name,
        ["realm"] = realm,
        ["classID"] = tonumber(classID),
        ["record"] = tonumber(record),
        ["ilvl"] = tonumber(ilvl),
        ["keyLevel"] = tonumber(keylevel),
        ["keyID"] = tonumber(keyid),
        ["faction"] = faction,
        ["sender"] = sender,
    })
end

function WeekKeys.DB.SaveVars(DB, name, realm, classID, ilvl, record, keyid, keylevel, faction, sender)
    if (not name) or (not realm) or (name == "") or (realm == "") or (not tonumber(classID)) then
        return
    end
    for k,v in pairs(DB) do
        if v.name == name and v.realm == realm then
            if record then
                v.record = record
            end
            if ilvl then
                v.ilvl = tonumber(ilvl)
            end
            if classID then
                v.classID = tonumber(classID)
            end
            
            v.keyID = tonumber(keyid)
            
            if keylevel then
                v.keyLevel = tonumber(keylevel)
            end
            if faction then
                v.faction = faction
            end
            if sender then
                v.sender = sender
            end
            return
        end
    end
    tinsert(DB,{
        ["name"] = name,
        ["realm"] = realm,
        ["classID"] = tonumber(classID),
        ["record"] = tonumber(record),
        ["ilvl"] = tonumber(ilvl),
        ["keyLevel"] = tonumber(keylevel),
        ["keyID"] = tonumber(keyid),
        ["faction"] = faction,
        ["sender"] = sender,
    })
end

function WeekKeys.DB.GetFactionCovenant(DB, tbl)
    if not DB then
        return
    end
    local realmname = string.lower(GetNormalizedRealmName())
    tbl = tbl or {}

    tbl[1] = wipe(tbl[1] or {})  -- фракция
    tbl[2] = wipe(tbl[2] or {})  -- ник, покрашеный
    tbl[3] = wipe(tbl[3] or {}) -- realm
    tbl[4] = wipe(tbl[4] or {}) -- илвл
    tbl[5] = wipe(tbl[5] or {}) -- рекорд
    tbl[6] = wipe(tbl[6] or {}) -- ключ
    tbl[7] = wipe(tbl[7] or {}) -- недельный сундук
    tbl[8] = wipe(tbl[8] or {}) -- covenant

    for index,char in pairs(DB) do
        tbl[1][index] = char.faction
        local _, classFile, _ = GetClassInfo(char.classID)
        local _, _, _, argbHex = GetClassColor(classFile)
        tbl[2][index] = "|c"..argbHex..char.name.."|r"
        if string.lower(char.realm or "") ~= realmname then
            tbl[2][index] = tbl[2][index] .. " (*)"
        end
        tbl[3][index] = char.realm
        tbl[4][index] = char.ilvl
        tbl[5][index] = char.record
        if char.keyID then
            tbl[6][index] = string.format("%s (%d)",C_ChallengeMode.GetMapUIInfo(char.keyID), char.keyLevel)

            if char.keyID == 375 or char.keyID == 377 then
                tbl[6][index] = "|Tinterface/icons/ui_sigil_nightfae.blp:20:20|t" .. tbl[6][index] 
            elseif char.keyID == 376 or char.keyID == 381 then
                tbl[6][index] = "|Tinterface/icons/ui_sigil_kyrian.blp:20:20|t" .. tbl[6][index]
            elseif char.keyID == 378 or char.keyID == 380 then
                tbl[6][index] =  "|Tinterface/icons/ui_sigil_venthyr.blp:20:20|t" .. tbl[6][index] 
            elseif char.keyID == 379 or char.keyID == 382 then
                tbl[6][index] =  "|Tinterface/icons/ui_sigil_necrolord.blp:20:20|t" .. tbl[6][index]
            end
        
        else
            tbl[6][index] = ""
        end
        tbl[7][index] = char.reward
        tbl[8][index] = char.covenant
    end

    return tbl
end

function WeekKeys.DB.SaveVars2(DB, name, realm, classID, ilvl, record, keyid, keylevel, faction, covenant)
    if (not name) or (not realm) or (name == "") or (realm == "") or (not tonumber(classID)) then
        return
    end

    for k,v in pairs(DB) do
        if v.name == name and v.realm == realm then
            if record then
                v.record = record
            end
            if ilvl then
                v.ilvl = tonumber(ilvl)
            end
            if classID then
                v.classID = tonumber(classID)
            end
            if keyid then
                v.keyID = tonumber(keyid)
            end
            if keylevel then
                v.keyLevel = tonumber(keylevel)
            end
            if faction then
                v.faction = faction
            end
            if covenant then
                v.covenant = covenant
            end
            return
        end
    end
    tinsert(DB,{
        ["name"] = name,
        ["realm"] = realm,
        ["classID"] = tonumber(classID),
        ["record"] = tonumber(record),
        ["ilvl"] = tonumber(ilvl),
        ["keyLevel"] = tonumber(keylevel),
        ["keyID"] = tonumber(keyid),
        ["faction"] = faction,
        ["covenant"] = covenant
    })
end

function WeekKeys.DB.SaveTable(DB,tbl)
    for _,v in pairs(DB) do
        if v.name == tbl.name and v.realm == tbl.realm then
            for index,value in pairs(tbl) do
                v[index] = value
            end
            return
        end
    end
    if tbl.name and tbl.realm then
        tinsert(DB,tbl)
    end
end

function WeekKeys.DB.GetCharsByNameRealm(DB,name,realm,tbl)
    if not DB then
        return
    end
    tbl = tbl or {}

    tbl[1] = wipe(tbl[1] or {})  -- фракция
    tbl[2] = wipe(tbl[2] or {})  -- ник, покрашеный
    tbl[3] = wipe(tbl[3] or {}) -- илвл
    tbl[4] = wipe(tbl[4] or {}) -- рекорд
    tbl[5] = wipe(tbl[5] or {}) -- ключ
    tbl[6] = wipe(tbl[6] or {}) -- недельный сундук
    for index,char in pairs(DB) do

    end
    
end
-- /dump WeekKeys.DB.GetFormattedData(WeekKeysDB.Characters)
function WeekKeys.DB.GetFormattedData(DB, tbl)
    if not DB then
        return
    end
    local realmname = string.lower(GetNormalizedRealmName())
    tbl = tbl or {}

    tbl[1] = wipe(tbl[1] or {})  -- фракция
    tbl[2] = wipe(tbl[2] or {})  -- ник, покрашеный
    tbl[3] = wipe(tbl[3] or {}) -- илвл
    tbl[4] = wipe(tbl[4] or {}) -- рекорд
    tbl[5] = wipe(tbl[5] or {}) -- ключ
    tbl[6] = wipe(tbl[6] or {}) -- недельный сундук

    for index,char in pairs(DB) do
        tbl[1][index] = tonumber(char.covenant)
        local _, classFile, _ = GetClassInfo(char.classID)
        local _, _, _, argbHex = GetClassColor(classFile)
        tbl[2][index] = "|c"..argbHex..char.name.."|r"
        if string.lower(char.realm) ~= realmname then
            tbl[2][index] = tbl[2][index] .. " (*)"
        end
        tbl[3][index] = char.ilvl
        tbl[4][index] = char.record
        if char.keyID and C_ChallengeMode.GetMapUIInfo(char.keyID) then
            tbl[5][index] = string.format("%s (%d)",C_ChallengeMode.GetMapUIInfo(char.keyID), char.keyLevel)
            if char.keyID == 375 or char.keyID == 377 then
                tbl[5][index] = "|Tinterface/icons/ui_sigil_nightfae.blp:20:20|t" .. tbl[5][index] 
            elseif char.keyID == 376 or char.keyID == 381 then
                tbl[5][index] = "|Tinterface/icons/ui_sigil_kyrian.blp:20:20|t" .. tbl[5][index]
            elseif char.keyID == 378 or char.keyID == 380 then
                tbl[5][index] =  "|Tinterface/icons/ui_sigil_venthyr.blp:20:20|t" .. tbl[5][index] 
            elseif char.keyID == 379 or char.keyID == 382 then
                tbl[5][index] =  "|Tinterface/icons/ui_sigil_necrolord.blp:20:20|t" .. tbl[5][index]
            end
        else
            tbl[5][index] = ""
        end
        tbl[6][index] = char.reward
    end

    return tbl
end

function WeekKeys.DB.GetChar(DB, name, realm)
    if not DB then return end
    for _,char in pairs(DB) do
        if char.name == name and char.realm == realm then
            local _, classFile, _ = GetClassInfo(char.classID)
            local _, _, _, argbHex = GetClassColor(classFile)
            local str = ""
            --string.format("%s (%d)",C_ChallengeMode.GetMapUIInfo(char.keyID), char.keyLevel)
            if char.keyID then
                str = string.format("%s (%d)",C_ChallengeMode.GetMapUIInfo(char.keyID), char.keyLevel)
                if char.keyID == 375 or char.keyID == 377 then
                    str = "|Tinterface/icons/ui_sigil_nightfae.blp:20:20|t" .. str
                elseif char.keyID == 376 or char.keyID == 381 then
                    str = "|Tinterface/icons/ui_sigil_kyrian.blp:20:20|t" .. str
                elseif char.keyID == 378 or char.keyID == 380 then
                    str =  "|Tinterface/icons/ui_sigil_venthyr.blp:20:20|t" .. str
                elseif char.keyID == 379 or char.keyID == 382 then
                    str =  "|Tinterface/icons/ui_sigil_necrolord.blp:20:20|t" .. str
                end
            else
                str = ""
            end
            return  "|c"..argbHex..char.name.."|r", char.ilvl, char.record, str, char.covenant
        end
    end
end
function WeekKeys.DB.Remove(DB, name, realm)
    if not DB then return end
    for index,char in pairs(DB) do
        if char.name == name and char.realm == realm then
            return table.remove(DB, index)
        end
    end
    return
    -- to do
end
function WeekKeys.DB.InsertTorghast(DB,name,realm,thorgast_number,record)
    if name == "" or realm == "" then
        return
    end
    for k,v in pairs(DB) do
        if v.name == name and v.realm == realm then
            v[thorgast_number] = tonumber(record)
            return
        end
    end
    tinsert(DB,{
        ["name"] = name,
        ["realm"] = realm,
        [thorgast_number] = tonumber(record),
    })
end
function WeekKeys.DB.GetTorghast(DB, tbl)
    if not DB then
        return
    end
    local realmname = string.lower(GetNormalizedRealmName())
    tbl = tbl or {}

    tbl[1] = wipe(tbl[1] or {})  -- faction
    tbl[2] = wipe(tbl[2] or {})  -- name
    tbl[3] = wipe(tbl[3] or {}) -- torghast1
    tbl[4] = wipe(tbl[4] or {}) -- torghast2


    for index,char in pairs(DB) do
        tbl[1][index] = char.faction
        local _, classFile, _ = GetClassInfo(char.classID)
        local _, _, _, argbHex = GetClassColor(classFile)
        tbl[2][index] = "|c"..argbHex..char.name.."|r"
        if string.lower(char.realm or "") ~= realmname then
            tbl[2][index] = tbl[2][index] .. " (*)"
        end
        tbl[3][index] = char.torghast1
        tbl[4][index] = char.torghast2
    end

    return tbl

end

function WeekKeys.DB.GetGuildFormatted(DB, tbl)
    if not DB then
        return
    end
    tbl = tbl or {}
    local index = 1
    tbl[1] = wipe(tbl[1] or {})  -- covenant
    tbl[2] = wipe(tbl[2] or {})  -- ник, покрашеный
    tbl[3] = wipe(tbl[3] or {}) -- илвл
    tbl[4] = wipe(tbl[4] or {}) -- рекорд
    tbl[5] = wipe(tbl[5] or {}) -- ключ
    tbl[6] = wipe(tbl[6] or {}) -- недельный сундук
    
    for i = 1, GetNumGuildMembers() do
        local nameRealm, _, _, level, _, _, _, _, online, _, _, _, _, isMobile, _, _ = GetGuildRosterInfo(i);
        local name,realm = strsplit("-",nameRealm)
        if level >= 60 and online == true and isMobile == false then
            for _,char in pairs(DB) do
                if char.name == name and char.realm == realm then
                    tbl[1][index] = tonumber(char.covenant)
                    local _, classFile, _ = GetClassInfo(char.classID)
                    local _, _, _, argbHex = GetClassColor(classFile)
                    tbl[2][index] = "|c"..argbHex..char.name.."|r"
                    tbl[3][index] = char.ilvl
                    tbl[4][index] = char.record
                    if char.keyID and C_ChallengeMode.GetMapUIInfo(char.keyID) and char.keyLevel > 1 then
                        tbl[5][index] = string.format("%s (%d)",C_ChallengeMode.GetMapUIInfo(char.keyID), char.keyLevel)
                        
                        if char.keyID == 375 or char.keyID == 377 then
                            tbl[5][index] = "|Tinterface/icons/ui_sigil_nightfae.blp:20:20|t" .. tbl[5][index] 
                        elseif char.keyID == 376 or char.keyID == 381 then
                            tbl[5][index] = "|Tinterface/icons/ui_sigil_kyrian.blp:20:20|t" .. tbl[5][index]
                        elseif char.keyID == 378 or char.keyID == 380 then
                            tbl[5][index] =  "|Tinterface/icons/ui_sigil_venthyr.blp:20:20|t" .. tbl[5][index] 
                        elseif char.keyID == 379 or char.keyID == 382 then
                            tbl[5][index] =  "|Tinterface/icons/ui_sigil_necrolord.blp:20:20|t" .. tbl[5][index]
                        end
                        
                    else
                        tbl[5][index] = ""
                    end
                    tbl[6][index] = char.reward
                    index = index + 1
                end
            end
        end
    end

    return tbl
end


function WeekKeys.DB.GetFriends(DB, tbl, detailed)
    if not DB then
        return
    end
    tbl = tbl or {}
    local index = 1
    tbl[1] = wipe(tbl[1] or {}) -- faction
    tbl[2] = wipe(tbl[2] or {}) -- name
    tbl[3] = wipe(tbl[3] or {}) -- realm
    tbl[4] = wipe(tbl[4] or {}) -- 
    tbl[5] = wipe(tbl[5] or {})
    tbl[6] = wipe(tbl[6] or {})
    tbl[7] = wipe(tbl[7] or {})

    for tag,_ in pairs(DB) do
        if detailed[tag] then
            for _, player in pairs(DB[tag]) do
                tbl[1][index] = player.faction
                tbl[2][index] = player.covenant
                local _, classFile, _ = GetClassInfo(player.classID)
                local _, _, _, argbHex = GetClassColor(classFile)
                tbl[3][index] = "|c"..argbHex..player.name.."|r"
                tbl[4][index] = player.ilvl
                tbl[5][index] = player.record
                if player.keyID then
                    tbl[6][index] = string.format("%s (%d)",C_ChallengeMode.GetMapUIInfo(player.keyID), player.keyLevel)
                    if player.keyID == 375 or player.keyID == 377 then
                        tbl[6][index] = "|Tinterface/icons/ui_sigil_nightfae.blp:20:20|t" .. tbl[6][index]
                    elseif player.keyID == 376 or player.keyID == 381 then
                        tbl[6][index] = "|Tinterface/icons/ui_sigil_kyrian.blp:20:20|t" .. tbl[6][index]
                    elseif player.keyID == 378 or player.keyID == 380 then
                        tbl[6][index] =  "|Tinterface/icons/ui_sigil_venthyr.blp:20:20|t" .. tbl[6][index]
                    elseif player.keyID == 379 or player.keyID == 382 then
                        tbl[6][index] =  "|Tinterface/icons/ui_sigil_necrolord.blp:20:20|t" .. tbl[6][index]
                    end
                else
                    tbl[6][index] = ""
                end
                tbl[7][index] = tag
                index = index + 1
            end
        else
            tbl[3][index] = tag
            tbl[7][index] = tag
            index = index + 1
        end
    end
    return tbl
end

function WeekKeys.DB.GetCharsByFriend(DB, tbl, battletag)
    if not DB or not DB[battletag] then
        return
    end
    tbl = tbl or {}

    tbl[1] = wipe(tbl[1] or {}) -- faction
    tbl[2] = wipe(tbl[2] or {})
    tbl[3] = wipe(tbl[3] or {}) -- name
    tbl[4] = wipe(tbl[4] or {}) -- ilvl
    tbl[5] = wipe(tbl[5] or {}) -- record
    tbl[6] = wipe(tbl[6] or {}) -- keystone

    for index,player in ipairs(DB[battletag]) do
        tbl[1][index] = player.faction
        tbl[2][index] = player.covenant
        local _, classFile, _ = GetClassInfo(player.classID)
        local _, _, _, argbHex = GetClassColor(classFile)
        tbl[3][index] = "|c"..argbHex..player.name.."|r"
        tbl[4][index] = player.ilvl
        tbl[5][index] = player.record
        if player.keyID then

            tbl[6][index] = string.format("%s (%d)",C_ChallengeMode.GetMapUIInfo(player.keyID), player.keyLevel)
            if player.keyID == 375 or player.keyID == 377 then
                tbl[6][index] = "|Tinterface/icons/ui_sigil_nightfae.blp:20:20|t" .. tbl[6][index] 
            elseif player.keyID == 376 or player.keyID == 381 then
                tbl[6][index] = "|Tinterface/icons/ui_sigil_kyrian.blp:20:20|t" .. tbl[6][index]
            elseif player.keyID == 378 or player.keyID == 380 then
                tbl[6][index] =  "|Tinterface/icons/ui_sigil_venthyr.blp:20:20|t" .. tbl[6][index] 
            elseif player.keyID == 379 or player.keyID == 382 then
                tbl[6][index] =  "|Tinterface/icons/ui_sigil_necrolord.blp:20:20|t" .. tbl[6][index]
            end
        else
            tbl[6][index] = ""
        end
        index = index + 1
    end

    return tbl
end
