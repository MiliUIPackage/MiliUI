local stats = {}

local function tsize(tbl)
    local count = 0
    for _, _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function LF:FilterCheck(itemlink)
    if not itemlink then return end

    table.wipe(stats)

    GetItemStats(itemlink, stats)

    if tsize(stats) == 0 then return end

    if tsize(self.selectedstats) > 1 then
        local selected_count = 0

        for key, _ in pairs(self.selectedstats) do
            if stats[key] then
                selected_count = selected_count + 1
            end
        end

        if selected_count < 2 then
            return false
        end
    elseif tsize(self.selectedstats) == 1 then
        local found = false

        for key, _ in pairs(self.selectedstats) do
            if stats[key] then
                found = true
            end
        end

        if not found then
            return false
        end
    end

    local _, _, _, _, _, _, _, _, itemEquipLoc, _, _, classID, subclassID = GetItemInfo(itemlink)

    if classID == 4 and self.class > 0 and self:GetArmorTypeID() ~= subclassID then
        return false
    end

    if not self[itemEquipLoc](self,subclassID) and self.slotid < 15 then
        return false
    end
--asdasd

    return true
end
