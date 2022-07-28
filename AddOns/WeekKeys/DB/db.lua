local DB = {}
WeekKeys.DB = DB
DB.__index = DB

-- create new db object
function DB:New()
    return setmetatable({},self)
end

-- add character to db
function DB:Add(newchar)
    if not self.db then return end
    if (not newchar.name) or (not newchar.realm) then return end
    -- search if char exist in db
    local i
    for i, char in pairs(self.db) do
        if char.name == newchar.name and char.realm == newchar.realm then
            for key, val in pairs(newchar) do
                char[key] = val
            end
        end
    end
    -- create new char if not exist
    self.db[#self.db + 1] = newchar
end

-- delete character from db
function DB:Delete(...)
    if not self.db then return end
    -- reference to char_table
    if select('#',...) == 1 then
        local delete = ...
        for i, char in pairs(self.db) do
            if char == delete then
                return table.remove(self.db,i)
            end
        end
    -- name, realm
    elseif select('#',...) == 2 then
        local name, realm = ...
        for i, char in pairs(self.db) do
            if (char.name == name) and (char.realm == realm) then
                return table.remove(self.db,i)
            end
        end
    end
end

function DB:validate(char)
    if not char.classID then
        return
    end

    if not char.name then
        return
    end

    if not char.realm then
        return
    end
    
    if not char.faction then
        return
    end

    return true
end

-- expand player
function DB:Expand(sender)

end

-- s
function DB:SaveCharString(str)
    if not self.db then return end

end
