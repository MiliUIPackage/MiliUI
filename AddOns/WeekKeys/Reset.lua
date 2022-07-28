WeekKeys.ResetFunc = {} -- functions to reset db

---Resets db (delete records, keystones, torghast)
function WeekKeys.ResetDB()
    if GetCurrentRegion() == 3 then -- if in EU region
        WeekKeysDB.ResetTime = GetServerTime()- (GetServerTime() - 1500447600)%604800
    else -- if not EU region
        WeekKeysDB.ResetTime = GetServerTime()- (GetServerTime() - 1500390000)%604800
    end
    for _,v in pairs(WeekKeysDB.Characters) do
        if v.record ~= 0 then
            v.record = nil
            v.reward = true
        end
        v.keyID = nil
        v.keyLevel = nil
        v.torghast1 = nil
        v.torghast2 = nil
    end
    WeekKeysDB.Guild = nil
	WeekKeysDB.Friends = nil
end

---Return bool value to need reset db or not
---@return boolean needreset
function WeekKeys.NeedReset()
    if GetCurrentRegion() == 3 then -- EU region
        return (WeekKeysDB.ResetTime or 0) < GetServerTime()- (GetServerTime() - 1500447600)%604800
    else
        return (WeekKeysDB.ResetTime or 0) < GetServerTime()- (GetServerTime() - 1500390000)%604800
    end
end
