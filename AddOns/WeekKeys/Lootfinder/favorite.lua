
function LF:IsFavorite(item, db)

    db = _G[db] or _G[self.db]

    if not db then return end
    if not db.FavLoot then return end

    if self.spec > 0 and db.FavLoot[self.spec] then
        for index, favitem in ipairs(db.FavLoot[self.spec]) do
            if GetItemInfoInstant(favitem.itemlink) == GetItemInfoInstant(item) then
                return true
            end
        end
    elseif self.class > 0 and db.FavLoot[self.class] then
        for index, favitem in ipairs(WeekKeysDB.FavLoot[self.class]) do
            if GetItemInfoInstant(favitem.itemlink) == GetItemInfoInstant(item) then
                return true
            end
        end
        for index, specID in pairs(self.tables.class_spec[self.class]) do
            if db.FavLoot[specID] then
                for index, favitem in pairs(db.FavLoot[specID]) do
                    if GetItemInfoInstant(favitem.itemlink) == GetItemInfoInstant(item) then
                        return true
                    end
                end
            end
        end
    end
end

function LF:Favorite(item)
    if self.class == 0 then return end
    _G[self.db].FavLoot = _G[self.db].FavLoot or {}

    local index = 0
    if self.spec > 0 then
        index = self.spec
    else
        index = self.class
    end
    _G[self.db].FavLoot[index] = _G[self.db].FavLoot[index] or {}
    -- unset favorite
    for i = 1, #_G[self.db].FavLoot[index] do
        if GetItemInfoInstant(_G[self.db].FavLoot[index][i].itemlink) == GetItemInfoInstant(item.itemlink) then
            return table.remove(_G[self.db].FavLoot[index],i)
        end
    end

    --set favorite
    _G[self.db].FavLoot[index][#_G[self.db].FavLoot[index] + 1] = item
end
